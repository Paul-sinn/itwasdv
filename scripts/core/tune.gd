## 튜닝(큐브) 판정. 튜닝 굴리기와 대박 배송 굴리기는 이 파일에만 둔다 (강화의 enhance.gd처럼).
## 화면 코드에서는 확률 계산을 하지 말고 여기 함수를 부른다.
##
## 방식 (docs/PROTOTYPE_V2.md "추천안"): 부위마다 일반 → 레어 → 에픽 → 전설. 1번 굴리면 확률로 한 등급 오르고,
## 실패하면 그대로 (안 내려감). 비용은 등급마다 고정 금액 (강수와 상관없음). 숫자는 전부 balance.json "tune".
## 튜닝 효과를 반영한 돈 계산은 GameState(game_state.gd)에 있다.
##
## 난수 생성기(RandomNumberGenerator)는 밖에서 넣어준다. 0~1 난수는 Enhance.random01과 같은 방법.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

## 화면에 보여 줄 순서 (Balance.TUNE_EFFECT_KEYS와 같은 부위)
const PARTS := ["turbo", "tire", "cargo", "suspension", "fuel_tank", "navigation", "engine_oil"]

## 튜닝 결과. BLOCKED = 굴릴 수 없는 상태라 아무 일도 안 일어남. UP = 한 등급 오름. SAME = 그대로
enum Result { BLOCKED = -1, UP, SAME }

## 튜닝할 수 없는 이유. NONE이면 튜닝 가능. (고장 중에도 튜닝은 된다)
enum Block { NONE, MAX_GRADE, NO_MONEY }


## 최고 등급 (3 = 전설)
static func max_grade(b: Balance) -> int:
	return b.tune_grades.size() - 1


## 등급 이름 ("일반" / "레어" / "에픽" / "전설"). 범위 밖이면 가까운 끝 등급
static func grade_name(b: Balance, grade: int) -> String:
	return b.tune_grades[clampi(grade, 0, max_grade(b))]


## 그 등급에서 1번 굴리는 비용 (원) = roundf(tune_cost_hours[등급] × 0강 시간당 수익). 강수와 상관없음.
## 최고 등급이면 0 (더 굴릴 수 없음)
static func cost(b: Balance, grade: int) -> float:
	if grade < 0 or grade >= max_grade(b):
		return 0.0
	return roundf(b.tune_cost_hours[grade] * b.base_hourly)


## 그 등급에서 한 등급 오를 확률. 최고 등급이면 0
static func up_chance(b: Balance, grade: int) -> float:
	if grade < 0 or grade >= max_grade(b):
		return 0.0
	return b.tune_up_chance[grade]


## 부위의 그 등급 효과 숫자 (balance.json 그대로. 예: turbo 레어 → 0.1, cargo 에픽 → 4)
static func effect(b: Balance, part: String, grade: int) -> float:
	return b.tune_effect(part, grade)


## 지금 이 부위를 튜닝할 수 있나? 못 하면 그 이유. 고장이어도 돈만 있으면 된다.
## 모르는 부위 id면 MAX_GRADE처럼 막는다 (빨간 오류를 찍음)
static func block_reason(state: GameState, b: Balance, part: String) -> Block:
	if not PARTS.has(part):
		push_error("모르는 튜닝 부위: %s" % part)
		return Block.MAX_GRADE
	var g := state.grade(part)
	if g >= max_grade(b):
		return Block.MAX_GRADE
	if state.money < cost(b, g):
		return Block.NO_MONEY
	return Block.NONE


## 난수 r(0 이상 1 미만) 하나로 결과를 정한다: r < 등급업 확률 → UP, 그 외 → SAME
static func decide(b: Balance, grade: int, r: float) -> Result:
	return Result.UP if r < up_chance(b, grade) else Result.SAME


## 튜닝 버튼 1번: 비용을 내고, 굴리고, 등급·통계를 반영한다.
## 튜닝할 수 없는 상태면 아무것도 안 하고 BLOCKED.
static func try_tune(state: GameState, b: Balance, part: String, rng: RandomNumberGenerator) -> Result:
	if block_reason(state, b, part) != Block.NONE:
		return Result.BLOCKED
	var g := state.grade(part)
	state.money -= cost(b, g)
	state.tune_press_count += 1
	var result := decide(b, g, Enhance.random01(rng))
	if result == Result.UP:
		state.tune[part] = g + 1
		state.tune_up_count += 1
	return result


## 배송 1번이 대박인가 (타이어 확률). 맞으면 state.jackpot_count += 1.
## 고장이거나 대박 확률이 0(타이어 일반)이면 굴리지 않고 false (난수도 안 씀).
## 돈은 GameState.delivery_pay(b, 초, 이 결과)로 계산한다.
static func roll_jackpot(state: GameState, b: Balance, rng: RandomNumberGenerator) -> bool:
	var chance := state.jackpot_chance(b)
	if state.broken or chance <= 0.0:
		return false
	var hit := Enhance.random01(rng) < chance
	if hit:
		state.jackpot_count += 1
	return hit
