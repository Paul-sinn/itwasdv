## 엔진 강화 판정. 성공 / 실패(유지) / 퍼짐 굴리기는 이 파일에만 둔다.
## 화면 코드에서는 확률 계산을 하지 말고 여기 함수를 부른다. (나중에 서버로 옮길 수 있게)
##
## 난수 생성기(RandomNumberGenerator)는 밖에서 넣어준다.
## 테스트에서는 seed를 고정한 생성기를 넣어 매번 같은 결과가 나오게 한다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")

## 강화 결과. BLOCKED = 강화할 수 없는 상태라 아무 일도 안 일어남.
enum Result { BLOCKED = -1, SUCCESS, FAIL, DESTROY }

## 강화할 수 없는 이유. NONE이면 강화 가능.
enum Block { NONE, BROKEN, MAX_STAR, NO_MONEY }

const RANDI_RANGE := 4294967296.0  # randi()는 0 ~ 4294967295 를 낸다 (4.6.3에서 직접 확인함)


## 0 이상 1 미만 난수 하나.
static func random01(rng: RandomNumberGenerator) -> float:
	return rng.randi() / RANDI_RANGE


## 화면에 보여줄 확률 세 개: { "success", "fail", "destroy" } (합 = 1)
## 실패(유지) = 1 - 성공 - 퍼짐
static func chances(b: Balance, star: int) -> Dictionary:
	var s := b.success[star]
	var d := b.destroy[star]
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }


## 난수 r(0 이상 1 미만) 하나로 결과를 정한다.
##   r < success                → 성공
##   r < success + destroy      → 퍼짐
##   그 외                      → 실패 (강수 그대로)
static func decide(b: Balance, star: int, r: float) -> Result:
	var p_success := b.success[star]
	if r < p_success:
		return Result.SUCCESS
	if r < p_success + b.destroy[star]:
		return Result.DESTROY
	return Result.FAIL


## 생성기로 난수를 뽑아 결과를 정한다. 상태는 바꾸지 않는다.
static func roll(b: Balance, star: int, rng: RandomNumberGenerator) -> Result:
	return decide(b, star, random01(rng))


## 지금 강화할 수 있나? 못 하면 그 이유.
## 퍼질 수 있는 강수에서는 강화 비용 + 스페어값이 있어야 한다 (Economy.enhance_need).
static func block_reason(state: GameState, b: Balance) -> Block:
	if state.broken:
		return Block.BROKEN
	if state.star >= b.max_star:
		return Block.MAX_STAR
	if state.money < Economy.enhance_need(b, state.star):
		return Block.NO_MONEY
	return Block.NONE


## 강화 버튼 1번: 비용을 내고, 굴리고, 결과를 상태에 반영하고, 통계를 센다.
## 강화할 수 없는 상태면 아무것도 안 하고 BLOCKED.
static func try_enhance(state: GameState, b: Balance, rng: RandomNumberGenerator) -> Result:
	if block_reason(state, b) != Block.NONE:
		return Result.BLOCKED
	state.money -= Economy.enhance_cost(b, state.star)
	var result := roll(b, state.star, rng)
	match result:
		Result.SUCCESS:
			state.star += 1
			state.success_count += 1
		Result.FAIL:
			state.fail_count += 1
		Result.DESTROY:
			break_engine(state, b)
			state.destroy_count += 1
	return result


## 퍼짐 처리: 직전 강수 기억 → broken_drop_to로 내림 → 고장.
## (강화에서 퍼졌을 때와, 테스트용 F5 "강제로 퍼지게 하기"에서 같이 쓴다)
## 이미 고장이면 아무것도 안 한다. broken_drop_to보다 낮은 강수에서는 강수를 올리지 않는다.
static func break_engine(state: GameState, b: Balance) -> void:
	if state.broken:
		return
	state.star_before_break = state.star
	state.star = mini(state.star, b.broken_drop_to)
	state.broken = true
