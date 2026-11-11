## balance.gd: balance.json 읽기와 검사
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")


func test_real_file_is_ok() -> void:
	var b: Balance = Balance.load_file()
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.max_star, 30, "max_star")
	check_eq(b.success.size(), b.max_star, "success 길이")
	check_eq(b.destroy.size(), b.max_star, "destroy 길이")
	check_eq(b.cost_hours.size(), b.max_star, "cost_hours 길이")
	check_eq(b.broken_drop_to, 15, "broken_drop_to")


func test_wrong_length_is_reported() -> void:
	var d := real_balance_dict()
	d["engine"]["success"].pop_back()
	var b: Balance = Balance.from_dict(d)
	check(not b.is_ok(), "success가 29개인데 통과됨")
	check(_has_error(b, "engine.success 길이가 29개"), "어디가 틀렸는지 안 알려줌: %s" % ", ".join(b.errors))


func test_sum_over_one_is_reported() -> void:
	var d := real_balance_dict()
	d["engine"]["destroy"][18] = 0.9   # 성공 0.2 + 퍼짐 0.9 = 1.1
	var b: Balance = Balance.from_dict(d)
	check(not b.is_ok(), "성공+퍼짐이 1 넘는데 통과됨")
	check(_has_error(b, "engine.success[18] + engine.destroy[18]"), "어디가 틀렸는지 안 알려줌: %s" % ", ".join(b.errors))


func test_sum_exactly_one_is_ok() -> void:
	var d := real_balance_dict()
	d["engine"]["destroy"][18] = 0.8   # 0.2 + 0.8 = 1 (딱 1은 괜찮음)
	var b: Balance = Balance.from_dict(d)
	check(b.is_ok(), "성공+퍼짐이 딱 1인데 막힘: %s" % ", ".join(b.errors))


func test_bad_values_are_reported() -> void:
	var d := real_balance_dict()
	d["income"].erase("base_hourly")
	d["income"]["offline_rate"] = 1.5
	d["engine"]["cost_hours"][3] = 0
	d["engine"]["success"][5] = "많이"
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "income.base_hourly 이 없음"), "빠진 숫자를 못 찾음")
	check(_has_error(b, "income.offline_rate"), "0~1 밖의 비율을 못 찾음")
	check(_has_error(b, "engine.cost_hours[3]"), "0원 비용을 못 찾음")
	check(_has_error(b, "engine.success[5] 가 숫자가 아님"), "숫자 아닌 칸을 못 찾음")
	note("찾은 문제: " + " / ".join(b.errors))


func test_bad_max_star_is_reported() -> void:
	var d := real_balance_dict()
	d["engine"]["max_star"] = 30.5
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "engine.max_star"), "정수가 아닌 max_star를 못 찾음")


func test_broken_json_is_reported() -> void:
	var b: Balance = Balance.from_text("{ \"income\": { \"base_hourly\": 1000, }")
	check(not b.is_ok(), "깨진 JSON이 통과됨")
	check(_has_error(b, "JSON 형식이 깨짐"), "JSON이 깨졌다고 안 알려줌: %s" % ", ".join(b.errors))


func test_missing_file_is_reported() -> void:
	var b: Balance = Balance.load_file("res://data/없는파일.json")
	check(_has_error(b, "파일이 없음"), "없는 파일이라고 안 알려줌: %s" % ", ".join(b.errors))


func _has_error(b: Balance, part: String) -> bool:
	for e in b.errors:
		if e.contains(part):
			return true
	return false
