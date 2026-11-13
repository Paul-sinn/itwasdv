## 튜닝(큐브) 판정. 튜닝 굴리기와 대박 배송 굴리기는 이 파일에만 둔다 (강화의 enhance.gd처럼).
## 화면 코드에서는 확률 계산을 하지 말고 여기 함수를 부른다.
##
## !! 껍데기 (2026-11-12 조정자) !!
## docs/PROTOTYPE_V2.md "코드 약속"의 함수 이름만 맞춰 둔 임시 파일. 화면 담당이 먼저 화면을 만들 수 있게.
## 숫자를 코드에 직접 쓴 곳이 있는데, 계산 담당(1단계)이 balance.json에서 읽게 바꾸고 진짜로 만든다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

## 화면에 보여 줄 순서
const PARTS := ["turbo", "tire", "cargo", "suspension", "fuel_tank", "navigation", "engine_oil"]

enum Result { BLOCKED = -1, UP, SAME }
enum Block { NONE, MAX_GRADE, NO_MONEY }


static func max_grade(_b: Balance) -> int:
	return 3   # 껍데기


static func grade_name(_b: Balance, grade: int) -> String:
	return ["일반", "레어", "에픽", "전설"][clampi(grade, 0, 3)]   # 껍데기


## 그 등급에서 1번 굴리는 비용 (원)
static func cost(_b: Balance, grade: int) -> float:
	return [100.0, 1500.0, 20000.0][clampi(grade, 0, 2)]   # 껍데기


static func up_chance(_b: Balance, grade: int) -> float:
	return [0.15, 0.05, 0.015][clampi(grade, 0, 2)]   # 껍데기


## 부위의 그 등급 효과 숫자 (balance.json 그대로. 예: turbo 레어 → 0.1)
static func effect(_b: Balance, _part: String, _grade: int) -> float:
	return 0.0   # 껍데기


static func block_reason(state: GameState, b: Balance, part: String) -> Block:
	var g := state.grade(part)
	if g >= max_grade(b):
		return Block.MAX_GRADE
	if state.money < cost(b, g):
		return Block.NO_MONEY
	return Block.NONE


## 튜닝 버튼 1번: 돈 빼고, 굴리고, 등급·통계 반영
static func try_tune(_state: GameState, _b: Balance, _part: String, _rng: RandomNumberGenerator) -> Result:
	return Result.BLOCKED   # 껍데기


## 배송 1번이 대박인가. 맞으면 state.jackpot_count += 1
static func roll_jackpot(_state: GameState, _b: Balance, _rng: RandomNumberGenerator) -> bool:
	return false   # 껍데기
