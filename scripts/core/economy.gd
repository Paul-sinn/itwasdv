## 돈 계산식. 숫자는 전부 Balance(data/balance.json)에서 온다.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
##
## 가격(강화 비용, 스페어)은 원 단위로 반올림한다.
## 화면에 보이는 가격과 실제로 빠지는 돈이 같아야 하기 때문.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")

const SECONDS_PER_HOUR := 3600.0


## 시간당 수익: 1강 오를 때마다 star_mult배, high_from_star강부터는 star_mult_high배.
##   high_from_star = 20이면: 19강까지 = base_hourly × star_mult ^ 강수
##                           20강부터 = (19강 수익) × star_mult_high ^ (강수 - 19)
static func hourly_income(b: Balance, star: int) -> float:
	var low_steps := mini(star, b.high_from_star - 1)
	var high_steps := maxi(0, star - (b.high_from_star - 1))
	return b.base_hourly * pow(b.star_mult, low_steps) * pow(b.star_mult_high, high_steps)


## 강화 1번 비용 = cost_hours[강수] × 시간당 수익(강수). 원 단위 반올림.
## 강수는 0 이상 max_star 미만이어야 한다 (max_star에서는 더 강화할 수 없음).
static func enhance_cost(b: Balance, star: int) -> float:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 강수: %d" % star)
	return roundf(b.cost_hours[star] * hourly_income(b, star))


## 스페어 엔진 가격: 강수와 상관없는 고정 금액 (balance.json engine.spare_price). 원 단위 반올림.
static func spare_price(b: Balance) -> float:
	return roundf(b.spare_price)


## 강화 버튼을 누를 때 남겨둬야 하는 스페어값.
## 퍼질 수 있는 강수(destroy > 0)면 스페어 가격, 아니면 0.
## (퍼져도 스페어는 반드시 살 수 있게 → 수익 0으로 영영 갇히는 일이 없음)
static func spare_reserve(b: Balance, star: int) -> float:
	if b.destroy[star] > 0.0:
		return spare_price(b)
	return 0.0


## 강화 버튼을 누르려면 가지고 있어야 하는 돈 = 강화 비용 + 남겨둘 스페어값.
## 실제로 빠지는 돈은 강화 비용뿐이다.
static func enhance_need(b: Balance, star: int) -> float:
	return enhance_cost(b, star) + spare_reserve(b, star)


## 배송 한 번에 받는 돈 = 시간당 수익 ÷ 3600 × 그 배송에 걸린 초
## 트럭이 빨라 보여도 1시간 동안 번 돈의 합은 시간당 수익과 같다.
static func delivery_pay(b: Balance, star: int, trip_seconds: float) -> float:
	return hourly_income(b, star) / SECONDS_PER_HOUR * trip_seconds


## 지금 돈으로 price를 사려면 몇 초 더 벌어야 하나.
## 이미 살 수 있으면 0. 버는 돈이 0이면(고장 등) INF(영원히 못 모음).
static func seconds_to_afford(price: float, money: float, hourly: float) -> float:
	if money >= price:
		return 0.0
	if hourly <= 0.0:
		return INF
	return (price - money) / hourly * SECONDS_PER_HOUR


## 꺼둔 동안 쌓인 돈 =시간당 수익 × min(꺼둔 시간, offline_cap_hours) × offline_rate
## - 고장 상태였으면 0
## - 꺼둔 시간이 음수(컴퓨터 시계가 거꾸로 감)면 0
static func offline_earnings(b: Balance, star: int, broken: bool, seconds_away: float) -> float:
	if broken or seconds_away <= 0.0:
		return 0.0
	var hours := minf(seconds_away / SECONDS_PER_HOUR, b.offline_cap_hours)
	return hourly_income(b, star) * hours * b.offline_rate
