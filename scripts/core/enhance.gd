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
const Stats = preload("res://scripts/core/stats.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Visitor = preload("res://scripts/core/visitor.gd")

## 강화 결과. BLOCKED = 강화할 수 없는 상태라 아무 일도 안 일어남.
enum Result { BLOCKED = -1, SUCCESS, FAIL, DESTROY }

## 강화할 수 없는 이유. NONE이면 강화 가능.
enum Block { NONE, MAX_STAR, NO_MONEY, NO_SPARE }

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


## 트럭 i의 확률 세 개 (화면에 보여 줄 확률). 최고 단계에서는 부르지 않는다.
##   퍼짐·성공은 _rolled (try_enhance가 굴리는 확률). 오늘 보험이 이 강화를 덮으면(Economy.insured_at) 퍼짐 → 실패(유지)로: 퍼짐 0, 그만큼 실패
static func chances_for(b: Balance, state: GameState, i: int) -> Dictionary:
	var c := _rolled(b, state, i)
	if Economy.insured_at(b, state.truck(i).star, state):
		return { "success": c["success"], "fail": c["fail"] + c["destroy"], "destroy": 0.0 }
	return c


## 지금 누르면 강화 비용과 같이 나갈 보험료 (가입 안 했거나 그 단계 퍼짐 확률(표 값)이 0이면 0). Economy.insure_fee
static func insure_fee(state: GameState, b: Balance, i: int) -> int:
	return Economy.insure_fee(b, state.truck(i).star, state)


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


## 트럭 i를 지금 강화할 수 있나? 못 하면 그 이유.
##   스페어: 퍼질 수 있는 단계(+18 이상)면 쓸 스페어(보통 + [고급 스페어 쓰기]가 켜져 있으면 고급)가 1개 이상. 오늘 보험이 덮으면 없어도 됨
##   돈: 강화 비용(제휴 할인 반영) + 보험료
##   둘 다 모자라면 스페어부터 알려 준다 (스페어를 사는 데도 돈이 들어서, 모을 목표를 먼저 보여 줌)
static func block_reason(state: GameState, b: Balance, i: int) -> Block:
	var star := state.truck(i).star
	if star >= b.max_star:
		return Block.MAX_STAR
	if needs_spare(b, star) and not Economy.insured_at(b, star, state) and state.usable_spares() < 1:
		return Block.NO_SPARE
	if state.money < Economy.enhance_cost(b, star, state) + Economy.insure_fee(b, star, state):
		return Block.NO_MONEY
	return Block.NONE


## 트럭 i 강화 버튼 1번: 비용 + 보험료를 내고, 굴리고, 결과를 상태에 반영하고, 통계를 센다. 성공하면 강화 첫 달성 보너스(driver.gd),
## 명장 열림(master.gd). 퍼지면 스페어를 1개 써서 내려감 (force_destroy). 트럭은 안 멈춘다.
##   오늘 보험이 덮는 강화면 퍼짐이 떠도 실패(단계 유지), 스페어 안 씀
##   명장 "확률로 2단계 상승" 중이면 성공 때 double_step 확률로 한 단계 더 (+30은 안 넘음)
## 결과: { "result": Result, "insured": bool (보험이 퍼짐을 막았나), "double": bool (2단계 올랐나),
##         "drop_to": int (퍼졌을 때 내려간 단계, 아니면 −1), "premium": bool (고급 스페어를 썼나) }
## 강화할 수 없는 상태면 아무것도 안 하고 result = BLOCKED.
static func try_enhance(state: GameState, b: Balance, i: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := { "result": Result.BLOCKED, "insured": false, "double": false, "drop_to": -1, "premium": false }
	if block_reason(state, b, i) != Block.NONE:
		return out
	var t := state.truck(i)
	var insured := Economy.insured_at(b, t.star, state)
	state.money -= Economy.enhance_cost(b, t.star, state) + Economy.insure_fee(b, t.star, state)
	var result := decide_chances(_rolled(b, state, i), random01(rng))
	match result:
		Result.SUCCESS:
			t.star += 1
			t.success_count += 1
			Driver.on_star_reached(state, b, t.star)
			if state.active_bonus == "double_step" and t.star < b.max_star and random01(rng) < b.master_bonuses["double_step"]:
				t.star += 1
				out["double"] = true
				Driver.on_star_reached(state, b, t.star)
			Stats.note_star(state, t.star)
			Master.check_unlock(state, b)
		Result.FAIL:
			t.fail_count += 1
		Result.DESTROY:
			if insured:
				result = Result.FAIL
				out["insured"] = true
				t.fail_count += 1
				Stats.add(state, "insured_saves", 1)
			else:
				var d := force_destroy(state, b, i)
				out["drop_to"] = d["drop_to"]
				out["premium"] = d["premium"]
				t.destroy_count += 1
	out["result"] = result
	return out


## 퍼짐 처리: 스페어 1개를 쓰고 단계를 내린다 (그보다 낮으면 그대로). 돌려줌 { "drop_to": 내려간 뒤 단계, "premium": 고급을 썼나 }
##   [고급 스페어 쓰기]가 켜져 있고 고급이 있으면 고급 1개 → premium_drop_to(+17), 아니면 보통 1개(없으면 0 그대로) → broken_drop_to(+15)
##   보험사 "복구 보험" 날이면 recovery_star(+17)보다 아래로 안 내려감 (고급과 겹쳐도 +17)
## 강화에서 퍼졌을 때와 치트 F5 "강제로 퍼지게 하기"에서 같이 쓴다. 통계는 안 센다 (강화 버튼 결과만 셈).
static func force_destroy(state: GameState, b: Balance, i: int) -> Dictionary:
	var premium := _premium_now(state)
	var to := drop_to(state, b, i)
	if premium:
		state.premium_spares -= 1
	else:
		state.spares = maxi(0, state.spares - 1)
	state.truck(i).star = to
	return { "drop_to": to, "premium": premium }


## 트럭 i가 지금 퍼지면 내려갈 단계 (아무것도 안 바꿈. force_destroy와 같은 규칙, 화면 안내 줄용):
##   고급 스페어 켜짐 + 남음 → premium_drop_to(+17), 아니면 broken_drop_to(+15). 복구 보험 날이면 recovery_star 밑으로 안 감. 지금 단계보다 높으면 지금 단계
static func drop_to(state: GameState, b: Balance, i: int) -> int:
	var to := b.premium_drop_to if _premium_now(state) else b.broken_drop_to
	if Visitor.insurer_event(state) == "recovery":
		to = maxi(to, b.recovery_star)
	return mini(state.truck(i).star, to)


static func _premium_now(state: GameState) -> bool:
	return state.use_premium and state.premium_spares > 0


## 굴리는 확률 세 개 (보험 전):
##   퍼짐 = destroy[단계] × (1 − min(엔진 보호 합, engine_guard_cap)) × (명장 "퍼짐 감소" 중이면 1 − destroy_cut)
##   성공 = success[단계] × (명장 "성공 확률 상승" 중이면 success_mult). 성공 + 퍼짐이 1을 넘으면 성공을 자름
##   줄어든 만큼 실패(유지). 명장 보너스는 state.active_bonus (Master.tick이 방문 중에만 채움)
static func _rolled(b: Balance, state: GameState, i: int) -> Dictionary:
	var t := state.truck(i)
	var s := b.success[t.star]
	var d := b.destroy[t.star] * (1.0 - minf(t.option_total(b, "engine_guard"), b.engine_guard_cap))
	if state.active_bonus == "destroy_cut":
		d *= 1.0 - b.master_bonuses["destroy_cut"]
	if state.active_bonus == "success_mult":
		s = minf(s * b.master_bonuses["success_mult"], 1.0 - d)
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }
