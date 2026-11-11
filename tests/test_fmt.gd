## fmt.gd: 화면에 보여줄 숫자 글자
extends "res://tests/test_base.gd"

const Fmt = preload("res://scripts/ui/fmt.gd")


func test_money() -> void:
	check_eq(Fmt.money(0.0), "0", "0")
	check_eq(Fmt.money(999.9), "999", "999.9 (소수점 버림)")
	check_eq(Fmt.money(1000.0), "1,000", "1000")
	check_eq(Fmt.money(1234567.8), "1,234,567", "1234567.8")
	check_eq(Fmt.money(-1234.0), "-1,234", "-1234")


## "+금액": 10원 미만은 소수 첫째 자리까지 (버림)
func test_payout() -> void:
	check_eq(Fmt.payout(0.97), "0.9", "0.97")
	check_eq(Fmt.payout(0.3), "0.3", "0.3 (실수 찌꺼기로 0.2가 되면 안 됨)")
	check_eq(Fmt.payout(2.0), "2.0", "2")
	check_eq(Fmt.payout(9.99), "9.9", "9.99")
	check_eq(Fmt.payout(10.4), "10", "10.4")
	check_eq(Fmt.payout(1234.5), "1,234", "1234.5")


func test_num() -> void:
	check_eq(Fmt.num(8.0), "8", "8.0")
	check_eq(Fmt.num(94.5), "94.5", "94.5")
	check_eq(Fmt.num(0.5), "0.5", "0.5")


func test_percent() -> void:
	check_eq(Fmt.percent(0.9975), "99.75%", "0.9975")
	check_eq(Fmt.percent(0.945), "94.5%", "0.945")
	check_eq(Fmt.percent(0.8925), "89.25%", "0.8925")
	check_eq(Fmt.percent(0.1075), "10.75%", "0.1075 (1 - 0.8925)")
	check_eq(Fmt.percent(0.05), "5%", "0.05")
	check_eq(Fmt.percent(0.2), "20%", "0.2")
	check_eq(Fmt.percent(0.0), "0%", "0")
	check_eq(Fmt.percent(1.0), "100%", "1")


func test_wait_text() -> void:
	check_eq(Fmt.wait_text(1.0), "약 1분 뒤 가능", "1초 → 1분")
	check_eq(Fmt.wait_text(61.0), "약 2분 뒤 가능", "61초 → 2분 (올림)")
	check_eq(Fmt.wait_text(3600.0), "약 1시간 0분 뒤 가능", "1시간")
	check_eq(Fmt.wait_text(5400.0), "약 1시간 30분 뒤 가능", "1시간 30분")
	check_eq(Fmt.wait_text(INF), "버는 돈이 없어서 모을 수 없음", "INF")


func test_away() -> void:
	check_eq(Fmt.away(30.0), "1분 미만", "30초")
	check_eq(Fmt.away(900.0), "15분", "900초")
	check_eq(Fmt.away(10800.0), "3시간", "3시간")
	check_eq(Fmt.away(11700.0), "3시간 15분", "3시간 15분")
	check_eq(Fmt.away(-18000.0), "5시간", "음수(시계 거꾸로)도 길이만")


func test_duration() -> void:
	check_eq(Fmt.duration(65.0), "1:05", "65초")
	check_eq(Fmt.duration(3725.0), "1:02:05", "3725초")
