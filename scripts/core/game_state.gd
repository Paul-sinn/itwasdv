## 게임 상태: 돈, 스페어 엔진, 트럭들.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 한 바퀴·배송·꺼둔 동안은 trip.gd, 강화 굴리기는 enhance.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const GameState = preload("res://scripts/core/game_state.gd")   # new_game()의 돌려주는 모양 표시용 (자기 자신)

var money: int = 0
var spares: int = 0                  ## 들고 있는 스페어 엔진
var spare_drop_carry: float = 0.0    ## 꺼둔 동안 스페어 평균값의 소수 나머지 (0 이상 1 미만)
var trucks: Array = []               ## TruckState들. 새 게임은 1대


## 트럭 1대(번호 0)짜리 새 상태
static func new_game() -> GameState:
	var s := GameState.new()
	s.trucks.append(TruckState.new())
	return s


func truck(i: int) -> TruckState:
	return trucks[i]


## 스페어 엔진은 언제든 고정가로 살 수 있다
func can_buy_spare(b: Balance) -> bool:
	return money >= Economy.spare_price(b)


## 돈을 내고 스페어 +1. 돈이 모자라면 아무것도 안 하고 false.
func buy_spare(b: Balance) -> bool:
	if not can_buy_spare(b):
		return false
	money -= Economy.spare_price(b)
	spares += 1
	return true
