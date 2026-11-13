## 엔진 강화 판정. 성공 / 실패(유지) / 퍼짐 굴리기는 이 파일에만 둔다.
## 화면 코드에서는 확률 계산을 하지 말고 여기 함수를 부른다. (나중에 서버로 옮길 수 있게)
##
## 난수 생성기(RandomNumberGenerator)는 밖에서 넣어준다.
## 테스트에서는 seed를 고정한 생성기를 넣어 매번 같은 결과가 나오게 한다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

## 강화 결과. BLOCKED = 강화할 수 없는 상태라 아무 일도 안 일어남.
enum Result { BLOCKED = -1, SUCCESS, FAIL, DESTROY }

## 강화할 수 없는 이유. NONE이면 강화 가능.
## NO_INSURE = 보험을 켰는데 걸 수 없음 (명장 방문 중도 아니고 쿠폰도 없음)
enum Block { NONE, MAX_STAR, NO_MONEY, NO_SPARE, NO_INSURE }

const RANDI_RANGE := 4294967296.0  # randi()는 0 ~ 4294967295 를 낸다 (4.6.3에서 직접 확인함)


## 0 이상 1 미만 난수 하나.
static func random01(rng: RandomNumberGenerator) -> float:
	return rng.randi() / RANDI_RANGE


## 그 단계의 확률 세 개: { "success", "fail", "destroy" } (합 = 1). 세팅 없는 엔진만의 확률 (트럭 확률은 chances_for)
## 실패(유지) = 1 - 성공 - 퍼짐
static func chances(b: Balance, star: int) -> Dictionary:
	var s := b.success[star]
	var d := b.destroy[star]
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }


## 트럭 i의 확률 세 개 (화면에 보여 줄 확률이자 try_enhance가 굴리는 확률). 최고 단계에서는 부르지 않는다.
##   퍼짐 = destroy[단계] × (1 − min(엔진 보호 합, engine_guard_cap)) × (명장 "퍼짐 감소" 중이면 1 − destroy_cut)
##   성공 = success[단계] × (명장 "성공 확률 상승" 중이면 success_mult). 성공 + 퍼짐이 1을 넘으면 성공을 자름
##   insure = 보험을 걸면 퍼짐 → 실패(유지)로: 퍼짐 0, 그만큼 실패
##   줄어든 만큼 실패(유지). 명장 보너스는 state.active_bonus (Master.tick이 방문 중에만 채움)
static func chances_for(b: Balance, state: GameState, i: int, insure: bool = false) -> Dictionary:
	var t := state.truck(i)
	var s := b.success[t.star]
	var d := b.destroy[t.star] * (1.0 - minf(t.option_total(b, "engine_guard"), b.engine_guard_cap))
	if state.active_bonus == "destroy_cut":
		d *= 1.0 - b.master_bonuses["destroy_cut"]
	if state.active_bonus == "success_mult":
		s = minf(s * b.master_bonuses["success_mult"], 1.0 - d)
	if insure:
		d = 0.0
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }


## 보험을 걸 수 있나: 명장 방문 중이거나 쿠폰이 1장 이상
static func can_insure(state: GameState, now_local: int) -> bool:
	return Master.is_visiting(state, now_local) or state.coupons > 0


## 보험 추가 요금: 방문 중이면 그 회 강화 비용(할인 주에는 할인된 비용) × insure_fee_mult, 아니면 0 (쿠폰 1장을 씀)
static func insure_fee(state: GameState, b: Balance, i: int, now_local: int) -> int:
	if not Master.is_visiting(state, now_local):
		return 0
	return roundi(Economy.enhance_cost(b, state.truck(i).star, state) * b.master_insure_fee_mult)


## 확률 세 개(chances 모양)와 난수 r(0 이상 1 미만) 하나로 결과를 정한다.
##   r < success                → 성공
##   r < success + destroy      → 퍼짐
##   그 외                      → 실패 (단계 그대로)
static func decide_chances(c: Dictionary, r: float) -> Result:
	var p_success: float = c["success"]
	if r < p_success:
		return Result.SUCCESS
	if r < p_success + c["destroy"]:
		return Result.DESTROY
	return Result.FAIL


## 그 단계의 확률로 결과를 정한다 (위와 같은 규칙)
static func decide(b: Balance, star: int, r: float) -> Result:
	return decide_chances(chances(b, star), r)


## 생성기로 난수를 뽑아 결과를 정한다. 상태는 바꾸지 않는다.
static func roll(b: Balance, star: int, rng: RandomNumberGenerator) -> Result:
	return decide(b, star, random01(rng))


## 퍼질 수 있는 단계(destroy[단계] > 0)라서 스페어를 1개 이상 들고 있어야 누를 수 있나
static func needs_spare(b: Balance, star: int) -> bool:
	return star >= 0 and star < b.max_star and b.destroy[star] > 0.0


## 트럭 i를 지금 강화할 수 있나? 못 하면 그 이유. insure = 보험을 켰을 때 (now_local은 명장 방문 중인지 볼 때만 씀)
##   보험: 걸 수 없으면 NO_INSURE. 걸면 +18 이상에서도 스페어 없이 누를 수 있고, 돈은 비용 + 보험 추가 요금이 있어야 함
##   보험 없이: 둘 다 모자라면 스페어부터 알려 준다 (스페어를 사는 데도 돈이 들어서, 모을 목표를 먼저 보여 줌)
static func block_reason(state: GameState, b: Balance, i: int, insure: bool = false, now_local: int = 0) -> Block:
	var star := state.truck(i).star
	if star >= b.max_star:
		return Block.MAX_STAR
	if insure and not can_insure(state, now_local):
		return Block.NO_INSURE
	if not insure and needs_spare(b, star) and state.spares < 1:
		return Block.NO_SPARE
	var need := Economy.enhance_cost(b, star, state) + (insure_fee(state, b, i, now_local) if insure else 0)
	if state.money < need:
		return Block.NO_MONEY
	return Block.NONE


## 트럭 i 강화 버튼 1번: 비용을 내고, 굴리고, 결과를 상태에 반영하고, 통계를 센다. 성공하면 강화 첫 달성 보너스(driver.gd),
## 명장 열림(master.gd). 퍼지면 스페어 1개를 자동으로 써서 broken_drop_to로. 트럭은 안 멈춘다.
##   insure = 보험: 방문 중이면 보험 추가 요금을 같이 내고(쿠폰 안 씀), 아니면 쿠폰 1장. 이 회에 퍼짐이 뜨면 실패(단계 유지)로 바뀜
##   명장 "확률로 2단계 상승" 중이면 성공 때 double_step 확률로 한 단계 더 (+30은 안 넘음)
## 결과: { "result": Result, "insured": bool (보험이 퍼짐을 막았나), "double": bool (2단계 올랐나) }
## 강화할 수 없는 상태면 아무것도 안 하고 result = BLOCKED.
static func try_enhance(state: GameState, b: Balance, i: int, rng: RandomNumberGenerator, insure: bool = false,
		now_local: int = 0) -> Dictionary:
	var out := { "result": Result.BLOCKED, "insured": false, "double": false }
	if block_reason(state, b, i, insure, now_local) != Block.NONE:
		return out
	var t := state.truck(i)
	var pay := Economy.enhance_cost(b, t.star, state)
	if insure:
		if Master.is_visiting(state, now_local):
			pay += insure_fee(state, b, i, now_local)
		else:
			state.coupons -= 1
	state.money -= pay
	var result := decide_chances(chances_for(b, state, i), random01(rng))
	match result:
		Result.SUCCESS:
			t.star += 1
			t.success_count += 1
			Driver.on_star_reached(state, b, t.star)
			if state.active_bonus == "double_step" and t.star < b.max_star and random01(rng) < b.master_bonuses["double_step"]:
				t.star += 1
				out["double"] = true
				Driver.on_star_reached(state, b, t.star)
			Master.check_unlock(state, b)
		Result.FAIL:
			t.fail_count += 1
		Result.DESTROY:
			if insure:
				result = Result.FAIL
				out["insured"] = true
				t.fail_count += 1
			else:
				force_destroy(state, b, i)
				t.destroy_count += 1
	out["result"] = result
	return out


## 퍼짐 처리: 스페어가 있으면 1개 쓰고, 단계를 broken_drop_to로 내린다 (그보다 낮으면 그대로).
## 강화에서 퍼졌을 때와 치트 F5 "강제로 퍼지게 하기"에서 같이 쓴다. 통계는 안 센다 (강화 버튼 결과만 셈).
static func force_destroy(state: GameState, b: Balance, i: int) -> void:
	var t := state.truck(i)
	state.spares = maxi(0, state.spares - 1)
	t.star = mini(t.star, b.broken_drop_to)
