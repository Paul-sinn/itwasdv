## 가격 계산 (강화 비용, 스페어 가격). 숫자는 전부 Balance(data/balance.json)에서 온다.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 버는 돈은 trip.gd에 있다.
##
## 돈은 정수(원). 화면에 보이는 가격과 실제로 빠지는 돈이 같아야 하기 때문.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")

const SECONDS_PER_HOUR := 3600.0


## 강화 1번 비용 = round(cost_base × cost_mult ^ 단계). 수입과 상관없는 고정표.
## 단계는 0 이상 max_star 미만이어야 한다 (max_star에서는 더 강화할 수 없음).
static func enhance_cost(b: Balance, star: int) -> int:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 단계: %d" % star)
	return roundi(b.cost_base * pow(b.cost_mult, star))


## 스페어 엔진 가격: 단계와 상관없는 고정 금액 (balance.json engine.spare_price)
static func spare_price(b: Balance) -> int:
	return b.spare_price


## 지금 돈으로 price를 사려면 몇 초 더 벌어야 하나.
## 이미 살 수 있으면 0. 버는 돈이 0이면 INF(영원히 못 모음).
static func seconds_to_afford(price: int, money: int, hourly: float) -> float:
	if money >= price:
		return 0.0
	if hourly <= 0.0:
		return INF
	return (price - money) / hourly * SECONDS_PER_HOUR
