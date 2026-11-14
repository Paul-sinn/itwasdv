## 가격 계산 (강화 비용, 보험료, 스페어 가격). 숫자는 전부 Balance(data/balance.json)에서 온다.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 버는 돈은 trip.gd에 있다.
##
## 돈은 정수(원). 화면에 보이는 가격과 실제로 빠지는 돈이 같아야 하기 때문.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Visitor = preload("res://scripts/core/visitor.gd")

const SECONDS_PER_HOUR := 3600.0


## 강화 1번 기본 비용 = round(cost_base × cost_mult ^ 단계). 수입과 상관없는 고정표 (보너스 없음. 시뮬·표용).
## 단계는 0 이상 max_star 미만이어야 한다 (max_star에서는 더 강화할 수 없음).
static func base_enhance_cost(b: Balance, star: int) -> int:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 단계: %d" % star)
	return roundi(b.cost_base * pow(b.cost_mult, star))


## 지금 강화 1번 비용 = 기본 비용. 보험사 "제휴 할인" 날 가입했으면 round(기본 × (1 − partner_discount)) (모든 단계).
## 화면이 보여 주는 비용 = 실제로 빠지는 돈 (Enhance.block_reason·try_enhance도 이것). 보험료는 따로 (insure_fee)
static func enhance_cost(b: Balance, star: int, s: GameState) -> int:
	var cost := base_enhance_cost(b, star)
	if Visitor.is_insured(s) and Visitor.insurer_event(s) == "partner_discount":
		cost = roundi(cost * (1.0 - b.partner_discount))
	return cost


## 이 단계 강화를 보험이 덮나: 오늘 보험 가입(Visitor.is_insured)이고 그 단계 퍼짐 확률(표 값) > 0 (+18 이상)
static func insured_at(b: Balance, star: int, s: GameState) -> bool:
	return Visitor.is_insured(s) and star >= 0 and star < b.max_star and b.destroy[star] > 0.0


## 이 단계 강화 1번에 같이 나가는 보험료 = round(기본 비용(할인 전) × 퍼짐 확률(표 값, 엔진 보호·명장 반영 전) × insure_fee_mult).
## 보험이 안 덮으면(가입 안 함, +17 이하) 0
static func insure_fee(b: Balance, star: int, s: GameState) -> int:
	if not insured_at(b, star, s):
		return 0
	return roundi(base_enhance_cost(b, star) * b.destroy[star] * b.insure_fee_mult)


## 트럭 i를 지금 돈으로 몇 번 강화할 수 있나 ("지금 돈이면 N번 시도 가능"). 지금 단계 비용이 계속 같다고 보고 센다.
##   1번 = 강화 비용 + 보험료. 퍼질 수 있는 단계인데 보험이 안 덮고 쓸 스페어(보통 + 켜 둔 고급)가 없으면 0
##   (퍼질 때 쓸 스페어는 안 셈). 최고 단계면 0
static func tries(s: GameState, b: Balance, i: int) -> int:
	var t = s.truck(i)
	if t.star >= b.max_star:
		return 0
	if b.destroy[t.star] > 0.0 and not insured_at(b, t.star, s) and s.usable_spares() < 1:
		return 0
	return floori(float(s.money) / (enhance_cost(b, t.star, s) + insure_fee(b, t.star, s)))


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
