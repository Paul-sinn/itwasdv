## 게임 상태: 돈, 강수, 고장 여부, 퍼지기 직전 강수, 통계.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 강화 굴리기와 퍼짐 처리는 여기 말고 enhance.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")

var money: float = 0.0
var star: int = 0
var broken: bool = false          ## 고장 엔진: 트럭 멈춤, 수익 0, 강화 불가
var star_before_break: int = 0    ## 퍼지기 직전 강수 (기록용. 스페어 가격은 이제 고정 금액이라 안 씀)

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


## 지금 스페어 엔진 가격 (고정 금액)
func spare_price(b: Balance) -> float:
	return Economy.spare_price(b)


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


# ---------------- 튜닝 (v2) ----------------
# !! 껍데기 (2026-11-12 조정자) !!
# docs/PROTOTYPE_V2.md "코드 약속"의 이름만 맞춰 둔 것. 지금은 "튜닝 없음"과 같은 값을 돌려준다.
# 계산 담당(1단계)이 튜닝 효과를 넣어 진짜로 만든다.

var tune: Dictionary = {}       ## 부위 id → 등급 (0 일반 ~ 3 전설). 없으면 0
var tune_press_count: int = 0   ## 튜닝 버튼 누른 횟수
var tune_up_count: int = 0      ## 그중 등급업
var jackpot_count: int = 0      ## 대박 배송 횟수


func grade(part: String) -> int:
	return int(tune.get(part, 0))


## 7칸 중 가장 높은 등급 (작은 화면 색 점)
func best_grade() -> int:
	var best := 0
	for g in tune.values():
		best = maxi(best, int(g))
	return best


## F6 치트·테스트용
func set_grade(_b: Balance, part: String, g: int) -> void:
	tune[part] = clampi(g, 0, 3)   # 껍데기


## 보통 수익 (대박 뺌). 고장이면 0
func steady_hourly(b: Balance) -> float:
	return current_hourly(b)   # 껍데기


func jackpot_chance(_b: Balance) -> float:
	return 0.0   # 껍데기


func jackpot_mult(_b: Balance) -> float:
	return 2.0   # 껍데기


func delivery_pay(b: Balance, seconds: float, jackpot: bool) -> float:
	var pay := Economy.delivery_pay(b, star, seconds) if not broken else 0.0
	return pay * (jackpot_mult(b) if jackpot else 1.0)


## 엔진오일 반영 강화 비용 (최고 강수에서는 부르지 않음)
func enhance_cost(b: Balance) -> float:
	return Economy.enhance_cost(b, star)   # 껍데기


## 강화 비용 + 남길 스페어값
func enhance_need(b: Balance) -> float:
	return Economy.enhance_need(b, star)   # 껍데기


## { success, fail, destroy } 서스펜션 반영
func enhance_chances(b: Balance) -> Dictionary:
	var s := b.success[star]
	var d := b.destroy[star]
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }   # 껍데기


func offline_cap_hours(b: Balance) -> float:
	return b.offline_cap_hours   # 껍데기


func offline_rate(b: Balance) -> float:
	return b.offline_rate   # 껍데기


func offline_earnings(b: Balance, seconds_away: float) -> float:
	return Economy.offline_earnings(b, star, broken, seconds_away)   # 껍데기
