## fmt.gd: 화면에 보여줄 숫자 글자. 말이 드는 것은 언어를 정해 놓고 본다 (번역 파일)
extends "res://tests/test_base.gd"

const Fmt = preload("res://scripts/ui/fmt.gd")


## 돈 표기 (지시서 v3 "돈 표기"): 1만 미만 쉼표, 위는 만/억/조. 단위로 나눈 값 100 미만은 소수 첫째 자리 버림
func test_money_ko() -> void:
	TranslationServer.set_locale("ko")
	for c in [[0, "0"], [999, "999"], [9999, "9,999"], [10000, "1만"], [12000, "1.2만"], [19999, "1.9만"],
			[999999, "99.9만"], [1000000, "100만"], [99999999, "9,999만"], [123456789, "1.2억"],
			[340000000, "3.4억"], [1200000000000, "1.2조"], [12345000000000000, "12,345조"],
			[9000000000000000000, "9,000,000조"], [-12000, "-1.2만"]]:
		check_eq(Fmt.money(c[0]), c[1], "ko %d" % c[0])


## en: 1000 미만 그대로, 위는 K/M/B/T. OS가 ko·en이 아니면(ja 등) en과 같음
func test_money_en() -> void:
	for locale in ["en", "ja"]:
		TranslationServer.set_locale(locale)
		for c in [[0, "0"], [999, "999"], [1000, "1K"], [9999, "9.9K"], [12000, "12K"], [123456789, "123M"],
				[340000000, "340M"], [1200000000, "1.2B"], [1200000000000, "1.2T"], [-1500, "-1.5K"]]:
			check_eq(Fmt.money(c[0]), c[1], "%s %d" % [locale, c[0]])
	TranslationServer.set_locale("ko")


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
	TranslationServer.set_locale("ko")
	check_eq(Fmt.wait_text(1.0), "약 1분 뒤 가능", "1초 → 1분")
	check_eq(Fmt.wait_text(61.0), "약 2분 뒤 가능", "61초 → 2분 (올림)")
	check_eq(Fmt.wait_text(3600.0), "약 1시간 0분 뒤 가능", "1시간")
	check_eq(Fmt.wait_text(5400.0), "약 1시간 30분 뒤 가능", "1시간 30분")
	check_eq(Fmt.wait_text(INF), "버는 돈이 없어서 모을 수 없음", "INF")


func test_away() -> void:
	TranslationServer.set_locale("ko")
	check_eq(Fmt.away(30.0), "1분 미만", "30초")
	check_eq(Fmt.away(900.0), "15분", "900초")
	check_eq(Fmt.away(10800.0), "3시간", "3시간")
	check_eq(Fmt.away(11700.0), "3시간 15분", "3시간 15분")
	check_eq(Fmt.away(-18000.0), "5시간", "음수(시계 거꾸로)도 길이만")


func test_duration() -> void:
	check_eq(Fmt.duration(65.0), "1:05", "65초")
	check_eq(Fmt.duration(3725.0), "1:02:05", "3725초")
