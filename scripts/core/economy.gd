## 가격 계산 (강화 비용, 스페어 가격). 숫자는 전부 Balance(data/balance.json)에서 온다.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 버는 돈은 trip.gd에 있다.
##
## 돈은 정수(원). 화면에 보이는 가격과 실제로 빠지는 돈이 같아야 하기 때문.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")

const SECONDS_PER_HOUR := 3600.0


## 강화 1번 기본 비용 = round(cost_base × cost_mult ^ 단계). 수입과 상관없는 고정표 (보너스 없음. 시뮬·표용).
## 단계는 0 이상 max_star 미만이어야 한다 (max_star에서는 더 강화할 수 없음).
static func base_enhance_cost(b: Balance, star: int) -> int:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 단계: %d" % star)
	return roundi(b.cost_base * pow(b.cost_mult, star))


## 지금 강화 1번 비용 = 기본 비용, 명장 "강화 비용 할인" 보너스가 적용 중이면(s.active_bonus) round(기본 × (1 − 할인)).
## 화면이 보여 주는 비용 = 실제로 빠지는 돈 (Enhance.block_reason·try_enhance도 이것). 보험 추가 요금은 따로 (Enhance.insure_fee)
static func enhance_cost(b: Balance, star: int, s: GameState) -> int:
	var cost := base_enhance_cost(b, star)
	if s.active_bonus == "enhance_discount":
		cost = roundi(cost * (1.0 - b.master_bonuses["enhance_discount"]))
	return cost


## 트럭 i를 지금 돈으로 몇 번 강화할 수 있나 ("지금 돈이면 N번 시도 가능"). 지금 단계 비용이 계속 같다고 보고 센다.
##   insure = 보험을 켰을 때: 방문 중이면 1번 = 비용 + 보험 추가 요금(비용 × insure_fee_mult), 아니면 쿠폰 1장씩이라 쿠폰 수까지.
##            방문 중도 아니고 쿠폰도 없으면 0
##   보험 없이: +18 이상인데 스페어가 없으면 0, 아니면 돈 ÷ 비용 (퍼질 때 쓸 스페어는 안 셈)
##   최고 단계면 0. now_local은 방문 중인지 볼 때만 씀
static func tries(s: GameState, b: Balance, i: int, insure: bool = false, now_local: int = 0) -> int:
	var t = s.truck(i)
	if t.star >= b.max_star:
		return 0
	var cost := enhance_cost(b, t.star, s)
	if insure:
		if Master.is_visiting(s, now_local):
			return floori(float(s.money) / (cost + roundi(cost * b.master_insure_fee_mult)))
		return mini(floori(float(s.money) / cost), s.coupons)
	if b.destroy[t.star] > 0.0 and s.spares < 1:
		return 0
	return floori(float(s.money) / cost)


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
