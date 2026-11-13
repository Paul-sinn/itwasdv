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
	check_eq(b.tune_grades, PackedStringArray(["일반", "레어", "에픽", "전설"]), "tune_grades")
	check_eq(b.tune_cost_hours.size(), 3, "tune_cost_hours 길이")
	check_eq(b.tune_up_chance.size(), 3, "tune_up_chance 길이")
	check_eq(b.tune_effects.keys(), Balance.TUNE_EFFECT_KEYS.keys(), "튜닝 부위 7개")
	for part in b.tune_effects:
		check_eq(b.tune_effects[part].size(), 4, "%s 효과 길이" % part)
	check_eq(b.tune_effect("turbo", 3), 0.5, "터보 전설 효과")
	check_eq(b.tune_effect("cargo", 0), 2.0, "짐칸 일반 효과")
	check_eq(b.tune_effect("fuel_tank", 9), 8.0, "범위 밖 등급 → 최고 등급 효과")


func test_missing_tune_is_reported() -> void:
	var d := real_balance_dict()
	d.erase("tune")
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "\"tune\" 묶음이 없음"), "tune 묶음이 빠진 걸 못 찾음: %s" % ", ".join(b.errors))


func test_tune_wrong_lengths_are_reported() -> void:
	var d := real_balance_dict()
	d["tune"]["tune_grades"].append("신화")
	d["tune"]["tune_cost_hours"].append(100)
	d["tune"]["tune_up_chance"].pop_back()
	d["tune"]["cargo_jackpot_mult"].pop_back()
	d["tune"].erase("oil_cost_cut")
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "tune.tune_grades 길이가 5개"), "등급 5개를 못 찾음")
	check(_has_error(b, "tune.tune_cost_hours 길이가 4개"), "비용 4개를 못 찾음")
	check(_has_error(b, "tune.tune_up_chance 길이가 2개"), "확률 2개를 못 찾음")
	check(_has_error(b, "tune.cargo_jackpot_mult 길이가 3개"), "짐칸 효과 3개를 못 찾음")
	check(_has_error(b, "tune.oil_cost_cut 이 없음"), "빠진 엔진오일 목록을 못 찾음")
	note("찾은 문제: " + " / ".join(b.errors))


func test_tune_bad_values_are_reported() -> void:
	var d := real_balance_dict()
	var t: Dictionary = d["tune"]
	t["tune_grades"][1] = 7
	t["tune_cost_hours"][0] = 0
	t["tune_up_chance"][2] = 0
	t["tune_up_chance"][1] = 1.2
	t["turbo_income_bonus"][0] = -0.1
	t["tire_jackpot_chance"][3] = 1.5
	t["cargo_jackpot_mult"][0] = 0.5
	t["suspension_destroy_cut"][3] = 1.0
	t["fuel_extra_hours"][2] = "많이"
	t["oil_cost_cut"][3] = 1
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "tune.tune_grades[1] 가 이름(글자)이 아님"), "글자가 아닌 등급 이름을 못 찾음")
	check(_has_error(b, "tune.tune_cost_hours[0]"), "0원 튜닝 비용을 못 찾음")
	check(_has_error(b, "tune.tune_up_chance[2]"), "0% 등급업 확률을 못 찾음")
	check(_has_error(b, "tune.tune_up_chance[1]"), "1 넘는 등급업 확률을 못 찾음")
	check(_has_error(b, "tune.turbo_income_bonus[0]"), "음수 터보를 못 찾음")
	check(_has_error(b, "tune.tire_jackpot_chance[3]"), "1 넘는 대박 확률을 못 찾음")
	check(_has_error(b, "tune.cargo_jackpot_mult[0]"), "1 미만 짐칸 배수를 못 찾음")
	check(_has_error(b, "tune.suspension_destroy_cut[3]"), "서스펜션 1(퍼짐 0%)을 못 찾음")
	check(_has_error(b, "tune.fuel_extra_hours[2] 가 숫자가 아님"), "숫자 아닌 연료 탱크를 못 찾음")
	check(_has_error(b, "tune.oil_cost_cut[3]"), "엔진오일 1(비용 0원)을 못 찾음")
	note("찾은 문제: " + " / ".join(b.errors))


## 효과 목록은 등급이 오를수록 줄면 안 됨
func test_tune_decreasing_list_is_reported() -> void:
	var d := real_balance_dict()
	d["tune"]["turbo_income_bonus"] = [0.0, 0.25, 0.1, 0.5]
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "tune.turbo_income_bonus[2] = 0.1 (앞 등급 0.25보다 작음"), "줄어드는 목록을 못 찾음: %s" % ", ".join(b.errors))
	var d2 := real_balance_dict()
	d2["tune"]["navi_extra_rate"] = [0.0, 0.1, 0.1, 0.3]   # 같은 건 괜찮음
	check(Balance.from_dict(d2).is_ok(), "같은 값이 이어지는데 막힘")


## 꺼둔 동안 비율 + 내비 최고는 1 이하
func test_offline_rate_plus_navi_over_one_is_reported() -> void:
	var d := real_balance_dict()
	d["income"]["offline_rate"] = 0.8   # + 내비 최고 0.3 = 1.1
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "income.offline_rate + tune.navi_extra_rate 최고"), "1 넘는 꺼둔 동안 비율을 못 찾음: %s" % ", ".join(b.errors))
	var d2 := real_balance_dict()
	d2["income"]["offline_rate"] = 0.7   # 0.7 + 0.3 = 1 (딱 1은 괜찮음)
	var b2: Balance = Balance.from_dict(d2)
	check(b2.is_ok(), "꺼둔 동안 비율이 딱 1인데 막힘: %s" % ", ".join(b2.errors))


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

	var d2 := real_balance_dict()
	d2["income"]["high_from_star"] = 20.5
	d2["engine"].erase("spare_price")
	var b2: Balance = Balance.from_dict(d2)
	check(_has_error(b2, "income.high_from_star"), "정수가 아닌 high_from_star를 못 찾음")
	check(_has_error(b2, "engine.spare_price 이 없음"), "빠진 spare_price를 못 찾음")


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
