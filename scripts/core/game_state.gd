## 게임 상태: 돈, 강수, 고장 여부, 퍼지기 직전 강수, 통계.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 강화 굴리기와 퍼짐 처리는 여기 말고 enhance.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")

var money: float = 0.0
var star: int = 0
var broken: bool = false          ## 고장 엔진: 트럭 멈춤, 수익 0, 강화 불가
var star_before_break: int = 0    ## 퍼지기 직전 강수 (스페어 가격 계산용)

# 통계 (강화 버튼을 눌러서 나온 결과만 센다)
var success_count: int = 0
var fail_count: int = 0
var destroy_count: int = 0


## 지금까지 강화 버튼을 누른 횟수
func press_count() -> int:
	return success_count + fail_count + destroy_count


## 지금 실제로 버는 시간당 수익. 고장이면 0.
func current_hourly(b: Balance) -> float:
	if broken:
		return 0.0
	return Economy.hourly_income(b, star)


## 지금 스페어 엔진 가격 (퍼지기 직전 강수 기준)
func spare_price(b: Balance) -> float:
	return Economy.spare_price(b, star_before_break)


func can_buy_spare(b: Balance) -> bool:
	return broken and money >= spare_price(b)


## 스페어 엔진을 사서 고장을 푼다. 강수는 그대로 (퍼질 때 이미 내려가 있음).
## 고장이 아니거나 돈이 모자라면 아무것도 안 하고 false.
func buy_spare(b: Balance) -> bool:
	if not can_buy_spare(b):
		return false
	money -= spare_price(b)
	broken = false
	return true
