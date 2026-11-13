## 게임 상태: 돈, 강수, 고장 여부, 퍼지기 직전 강수, 튜닝 등급, 통계.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 강화 굴리기와 퍼짐 처리는 enhance.gd, 튜닝·대박 굴리기는 tune.gd에 있다.
## 튜닝을 반영한 돈 계산(수익, 강화 비용, 퍼짐 확률, 꺼둔 동안)은 여기 있다.
##   Economy의 같은 이름 함수들은 "튜닝 없는 엔진만" 값이다.
## tune.gd가 이 파일을 preload하므로, 여기서는 tune.gd를 preload하지 않는다 (빙글 도는 preload 금지).
## 부위 효과 숫자는 Balance.tune_effect()에서 꺼낸다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")

var money: float = 0.0
var star: int = 0
var broken: bool = false          ## 고장 엔진: 트럭 멈춤, 수익 0, 강화 불가 (튜닝은 됨)
var star_before_break: int = 0    ## 퍼지기 직전 강수 (기록용. 스페어 가격은 이제 고정 금액이라 안 씀)

# 통계 (강화 버튼을 눌러서 나온 결과만 센다)
var success_count: int = 0
var fail_count: int = 0
var destroy_count: int = 0

# 튜닝 (v2). 엔진이 퍼져도 등급은 그대로
var tune: Dictionary = {}       ## 부위 id → 등급 (0 일반 ~ 3 전설). 없으면 0. 새 게임·예전 저장 = 전부 0
var tune_press_count: int = 0   ## 튜닝 버튼 누른 횟수
var tune_up_count: int = 0      ## 그중 등급업
var jackpot_count: int = 0      ## 대박 배송 횟수


## 지금까지 강화 버튼을 누른 횟수
func press_count() -> int:
	return success_count + fail_count + destroy_count


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


# ---------------- 튜닝 등급 ----------------

## 부위의 지금 등급 (0 일반 ~ 3 전설)
func grade(part: String) -> int:
	return int(tune.get(part, 0))


## 7칸 중 가장 높은 등급 (작은 화면 색 점. 전부 일반이면 0)
func best_grade() -> int:
	var best := 0
	for g in tune.values():
		best = maxi(best, int(g))
	return best


## 등급을 바로 정한다 (F6 치트·테스트용). 0~최고 등급으로 자름. 모르는 부위면 아무것도 안 함
func set_grade(b: Balance, part: String, g: int) -> void:
	if not b.tune_effects.has(part):
		push_error("모르는 튜닝 부위: %s" % part)
		return
	tune[part] = clampi(g, 0, b.tune_grades.size() - 1)


## 부위의 지금 등급 효과 숫자 (balance.json 그대로)
func _effect(b: Balance, part: String) -> float:
	return b.tune_effect(part, grade(part))


# ---------------- 수익 (터보, 타이어 + 짐칸 대박) ----------------

## 보통 수익 = 엔진 수익 × (1 + 터보). 대박은 뺌. 고장이면 0
func steady_hourly(b: Balance) -> float:
	if broken:
		return 0.0
	return Economy.hourly_income(b, star) * (1.0 + _effect(b, "turbo"))


## 평균 시간당 수익 = 보통 수익 × 대박 평균. 고장이면 0 (아니면 hourly_at(b, star)와 같음).
## 화면의 "시간당", 모으는 데 걸리는 시간, 꺼둔 동안 수익에 쓴다.
func current_hourly(b: Balance) -> float:
	if broken:
		return 0.0
	return hourly_at(b, star)


## 엔진이 star_value강일 때의 평균 시간당 수익 (지금 튜닝 반영, 고장 여부는 무시)
##   = 엔진 수익(star_value) × (1 + 터보) × 대박 평균
## 차고의 "성공하면 시간당 N원" (hourly_at(b, star + 1))용.
func hourly_at(b: Balance, star_value: int) -> float:
	return Economy.hourly_income(b, star_value) * (1.0 + _effect(b, "turbo")) * _jackpot_average(b)


## 배송 1번이 대박일 확률 (타이어)
func jackpot_chance(b: Balance) -> float:
	return _effect(b, "tire")


## 대박 배송이면 그 집 돈에 곱하는 수 (짐칸)
func jackpot_mult(b: Balance) -> float:
	return _effect(b, "cargo")


## 대박까지 친 평균 배수 = 1 + 타이어 확률 × (짐칸 배수 − 1). 타이어가 일반(0%)이면 1
func _jackpot_average(b: Balance) -> float:
	return 1.0 + jackpot_chance(b) * (jackpot_mult(b) - 1.0)


## 배송 1번 돈 = 보통 수익 ÷ 3600 × 그 배송에 걸린 초 × (대박이면 짐칸 배수). 고장이면 0
## 대박인지는 Tune.roll_jackpot()으로 굴려서 넣는다.
func delivery_pay(b: Balance, seconds: float, jackpot: bool) -> float:
	var pay := steady_hourly(b) / Economy.SECONDS_PER_HOUR * seconds
	return pay * jackpot_mult(b) if jackpot else pay


# ---------------- 강화 (엔진오일, 서스펜션) ----------------

## 강화 1번 비용 = roundf(cost_hours[강수] × 엔진 수익 × (1 − 엔진오일)). 터보·대박은 안 들어감.
## 최고 강수에서는 부르지 않는다.
func enhance_cost(b: Balance) -> float:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 강수: %d" % star)
	return roundf(b.cost_hours[star] * Economy.hourly_income(b, star) * (1.0 - _effect(b, "engine_oil")))


## 강화 버튼을 누르려면 가지고 있어야 하는 돈 = 강화 비용 + 남길 스페어값 (스페어값은 튜닝과 상관없음).
## 최고 강수에서는 부르지 않는다.
func enhance_need(b: Balance) -> float:
	return enhance_cost(b) + Economy.spare_reserve(b, star)


## 화면에 보여 줄 확률 세 개 { success, fail, destroy } (합 = 1). 서스펜션 반영:
##   퍼짐 = destroy[강수] × (1 − 서스펜션). 성공은 그대로, 줄어든 만큼 실패(유지)
## 최고 강수에서는 부르지 않는다.
func enhance_chances(b: Balance) -> Dictionary:
	assert(star >= 0 and star < b.max_star, "강화할 수 없는 강수: %d" % star)
	var s := b.success[star]
	var d := b.destroy[star] * (1.0 - _effect(b, "suspension"))
	return { "success": s, "fail": maxf(0.0, 1.0 - s - d), "destroy": d }


# ---------------- 꺼둔 동안 (연료 탱크, 내비게이션) ----------------

## 꺼둔 동안 최대 몇 시간치까지 쌓이나 = offline_cap_hours + 연료 탱크
func offline_cap_hours(b: Balance) -> float:
	return b.offline_cap_hours + _effect(b, "fuel_tank")


## 꺼둔 동안 수익 비율 = offline_rate + 내비게이션 (0.5 → 최고 0.8)
func offline_rate(b: Balance) -> float:
	return b.offline_rate + _effect(b, "navigation")


## 꺼둔 동안 쌓인 돈 = 평균 시간당 수익 × min(꺼둔 시간, 최대 시간) × 비율
## - 고장 상태였으면 0
## - 꺼둔 시간이 음수(컴퓨터 시계가 거꾸로 감)면 0
func offline_earnings(b: Balance, seconds_away: float) -> float:
	if broken or seconds_away <= 0.0:
		return 0.0
	var hours := minf(seconds_away / Economy.SECONDS_PER_HOUR, offline_cap_hours(b))
	return current_hourly(b) * hours * offline_rate(b)
