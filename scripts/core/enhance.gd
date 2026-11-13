## 엔진 강화 판정. 성공 / 실패(유지) / 퍼짐 굴리기는 이 파일에만 둔다.
## 화면 코드에서는 확률 계산을 하지 말고 여기 함수를 부른다. (나중에 서버로 옮길 수 있게)
##
## 난수 생성기(RandomNumberGenerator)는 밖에서 넣어준다.
## 테스트에서는 seed를 고정한 생성기를 넣어 매번 같은 결과가 나오게 한다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

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


## 트럭의 확률 세 개: 엔진 보호를 반영. 퍼짐 = destroy[단계] × (1 − min(엔진 보호 합, engine_guard_cap)),
## 줄어든 만큼 실패(유지). 화면에 보여 줄 확률이자 try_enhance가 굴리는 확률. 최고 단계에서는 부르지 않는다.
static func chances_for(b: Balance, t: TruckState) -> Dictionary:
	var s := b.success[t.star]
	var d := b.destroy[t.star] * (1.0 - minf(t.option_total(b, "engine_guard"), b.engine_guard_cap))
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }


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
## 둘 다 모자라면 스페어부터 알려 준다 (스페어를 사는 데도 돈이 들어서, 모을 목표를 먼저 보여 줌)
static func block_reason(state: GameState, b: Balance, i: int) -> Block:
	var star := state.truck(i).star
	if star >= b.max_star:
		return Block.MAX_STAR
	if needs_spare(b, star) and state.spares < 1:
		return Block.NO_SPARE
	if state.money < Economy.enhance_cost(b, star):
		return Block.NO_MONEY
	return Block.NONE


## 트럭 i 강화 버튼 1번: 비용을 내고, 굴리고, 결과를 상태에 반영하고, 통계를 센다.
## 퍼지면 스페어 1개를 자동으로 써서 broken_drop_to로. 트럭은 안 멈춘다.
## 강화할 수 없는 상태면 아무것도 안 하고 BLOCKED.
static func try_enhance(state: GameState, b: Balance, i: int, rng: RandomNumberGenerator) -> Result:
	if block_reason(state, b, i) != Block.NONE:
		return Result.BLOCKED
	var t := state.truck(i)
	state.money -= Economy.enhance_cost(b, t.star)
	var result := decide_chances(chances_for(b, t), random01(rng))
	match result:
		Result.SUCCESS:
			t.star += 1
			t.success_count += 1
		Result.FAIL:
			t.fail_count += 1
		Result.DESTROY:
			force_destroy(state, b, i)
			t.destroy_count += 1
	return result


## 퍼짐 처리: 스페어가 있으면 1개 쓰고, 단계를 broken_drop_to로 내린다 (그보다 낮으면 그대로).
## 강화에서 퍼졌을 때와 치트 F5 "강제로 퍼지게 하기"에서 같이 쓴다. 통계는 안 센다 (강화 버튼 결과만 셈).
static func force_destroy(state: GameState, b: Balance, i: int) -> void:
	var t := state.truck(i)
	state.spares = maxi(0, state.spares - 1)
	t.star = mini(t.star, b.broken_drop_to)
