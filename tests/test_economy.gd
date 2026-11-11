## economy.gd: 시간당 수익, 강화 비용, 스페어 가격, 배송 수익, 꺼둔 동안 수익
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")

var b: Balance = Balance.load_file()


## 지시서 "확인용 정답 값"
func test_answer_values() -> void:
	check_eq(Economy.enhance_cost(b, 0), 20.0, "0→1강 비용")
	check_eq(Economy.enhance_cost(b, 10), 1037.0, "10→11강 비용")
	check_eq(Economy.enhance_cost(b, 17), 45490.0, "17→18강 비용")
	check_eq(Economy.enhance_cost(b, 19), 122318.0, "19→20강 비용")
	check_eq(Economy.spare_price(b), 50000.0, "스페어 (고정 금액)")
	# 20강부터 수익이 1강마다 1.3배 → 비용도 "그 강수 수익의 N시간치"라 같이 오른다
	check_eq(Economy.enhance_cost(b, 20), roundf(25.0 * 1000.0 * pow(1.1, 19) * 1.3), "20→21강 비용")


## 퍼질 수 있는 강수(18강~)에서는 강화 비용 + 스페어값이 있어야 누를 수 있음
func test_spare_reserve() -> void:
	for star in b.max_star:
		var cost := Economy.enhance_cost(b, star)
		if b.destroy[star] > 0.0:
			check_eq(Economy.spare_reserve(b, star), Economy.spare_price(b), "%d강: 남겨둘 스페어값" % star)
			check_eq(Economy.enhance_need(b, star), cost + Economy.spare_price(b), "%d강: 필요한 돈" % star)
		else:
			check_eq(Economy.spare_reserve(b, star), 0.0, "%d강: 안 퍼지는데 스페어값을 남기라고 함" % star)
			check_eq(Economy.enhance_need(b, star), cost, "%d강: 필요한 돈이 비용과 다름" % star)
	check_eq(Economy.spare_reserve(b, 17), 0.0, "17강은 안 퍼짐")
	check_eq(Economy.enhance_need(b, 18), 77839.0 + 50000.0, "18강: 비용 77,839 + 스페어 50,000")


func test_hourly_income() -> void:
	check_near(Economy.hourly_income(b, 0), 1000.0, 1e-9, "0강 시간당 수익")
	check_near(Economy.hourly_income(b, 1), 1100.0, 1e-9, "1강 시간당 수익")
	check_near(Economy.hourly_income(b, 2), 1210.0, 1e-9, "2강 시간당 수익")
	# 19강까지 1.1배씩, 20강부터 1.3배씩
	var h19 := 1000.0 * pow(1.1, 19)
	check_near(Economy.hourly_income(b, 19), h19, 1e-6, "19강 시간당 수익 (1.1배 구간 끝)")
	check_near(Economy.hourly_income(b, 20), h19 * 1.3, 1e-6, "20강 시간당 수익 (여기부터 1.3배)")
	check_near(Economy.hourly_income(b, 21), h19 * 1.3 * 1.3, 1e-6, "21강 시간당 수익")
	check_near(Economy.hourly_income(b, 30), h19 * pow(1.3, 11), 1e-4, "30강 시간당 수익")
	for star in range(1, b.max_star + 1):
		var ratio := Economy.hourly_income(b, star) / Economy.hourly_income(b, star - 1)
		check_near(ratio, 1.3 if star >= 20 else 1.1, 1e-9, "%d강: 한 강 오를 때 배수" % star)


## 배송 시간이 제각각이어도(트럭이 빨라져도) 1시간 동안 번 돈 = 시간당 수익
func test_delivery_pay_adds_up_to_hourly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for star in [0, 10, 18, 30]:
		var earned := 0.0
		var elapsed := 0.0
		while elapsed < 3600.0:
			var trip := minf(rng.randf_range(2.0, 15.0), 3600.0 - elapsed)
			earned += Economy.delivery_pay(b, star, trip)
			elapsed += trip
		var hourly := Economy.hourly_income(b, star)
		check_near(earned, hourly, hourly * 1e-9, "%d강 1시간 배송 합계" % star)


func test_seconds_to_afford() -> void:
	check_eq(Economy.seconds_to_afford(100.0, 100.0, 1000.0), 0.0, "딱 맞으면 0초")
	check_eq(Economy.seconds_to_afford(100.0, 500.0, 1000.0), 0.0, "돈이 많으면 0초")
	check_near(Economy.seconds_to_afford(1000.0, 500.0, 1000.0), 1800.0, 1e-9, "500원 모자람, 시간당 1000 → 30분")
	check(is_inf(Economy.seconds_to_afford(1000.0, 0.0, 0.0)), "수익 0이면 영원히(INF)")


func test_offline_earnings() -> void:
	var star := 10
	var hourly := Economy.hourly_income(b, star)
	var hour := 3600.0
	check_near(Economy.offline_earnings(b, star, false, 3 * hour), hourly * 3 * 0.5, 1e-6, "3시간 꺼둠 → 3시간치의 절반")
	check_near(Economy.offline_earnings(b, star, false, 8 * hour), hourly * 8 * 0.5, 1e-6, "8시간 꺼둠 → 8시간치의 절반")
	check_near(Economy.offline_earnings(b, star, false, 20 * hour), hourly * 8 * 0.5, 1e-6, "20시간 꺼둠 → 최대 8시간치의 절반")
	check_eq(Economy.offline_earnings(b, star, false, -3 * hour), 0.0, "시계가 거꾸로 감(음수) → 0")
	check_eq(Economy.offline_earnings(b, star, false, 0.0), 0.0, "0초 → 0")
	check_eq(Economy.offline_earnings(b, star, true, 3 * hour), 0.0, "고장 상태 → 0")
