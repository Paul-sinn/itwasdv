## balance.gd: balance.json 읽기와 검사
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")


func test_real_file_is_ok() -> void:
	var b: Balance = Balance.load_file()
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.max_star, 30, "max_star")
	check_eq(b.success.size(), b.max_star, "success 길이")
	check_eq(b.destroy.size(), b.max_star, "destroy 길이")
	check_eq(b.broken_drop_to, 15, "broken_drop_to")
	# 지시서 "옮길 숫자": 시트 강화 단계 B1, E4:E33
	check_eq(b.base_power, 100, "base_power")
	var gain := PackedInt64Array()
	for pair in [[5, 10], [10, 5], [20, 5], [35, 5], [60, 5]]:
		for k in pair[1]:
			gain.append(pair[0])
	check_eq(b.power_gain, gain, "power_gain (5×10, 10×5, 20×5, 35×5, 60×5)")
	# 지시서 "임시 시작값"
	check_eq([b.unit_price, b.base_cargo, b.road_length, b.load_seconds, b.stop_seconds],
			[2500, 20, 12000.0, 10.0, 0.5], "trip 숫자 (v4에서 고침)")
	check_eq([b.fuel_rate, b.maint_rate], [0.1, 0.05], "기름값·정비비 비율")
	check_eq([b.cost_base, b.cost_mult, b.spare_drop_chance], [35000.0, 1.5, 0.00005], "강화 비용·스페어 드랍 (v4에서 고침)")
	check_eq(b.spare_price, 5000000, "spare_price (v4에서 고침)")
	# 원래 json에 있던 값 그대로
	check_eq([b.offline_cap_hours, b.offline_rate], [8.0, 0.5], "꺼둔 동안 8시간·0.5")
	check_eq(typeof(b.spare_price), TYPE_INT, "spare_price는 정수")


## 지운 묶음(income, tune 등)이 다시 생기지 않게: v4 json은 trip / engine / offline / setting + version
func test_real_file_shape() -> void:
	var d := real_balance_dict()
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["engine", "offline", "setting", "trip", "version"], "json 묶음")
	check_eq(d["version"], "0.7", "version")
	check(not d["engine"].has("cost_hours"), "engine.cost_hours 가 남아 있음")


func test_missing_section_is_reported() -> void:
	for section in ["trip", "engine", "offline", "setting"]:
		var d := real_balance_dict()
		d.erase(section)
		var b: Balance = Balance.from_dict(d)
		check(_has_error(b, "\"%s\" 묶음이 없음" % section), "%s 묶음이 빠진 걸 못 찾음: %s" % [section, ", ".join(b.errors)])


## 지시서 C1 ⑧: power_gain 길이 30, 음수 없음
func test_power_gain_length_and_negative() -> void:
	var d := real_balance_dict()
	d["engine"]["power_gain"].pop_back()
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "engine.power_gain 길이가 29개"), "power_gain 29개를 못 찾음: %s" % ", ".join(b.errors))

	var d2 := real_balance_dict()
	d2["engine"]["power_gain"][7] = -5
	d2["engine"]["power_gain"][8] = 2.5
	var b2: Balance = Balance.from_dict(d2)
	check(_has_error(b2, "engine.power_gain[7] = -5"), "음수 출력 증가를 못 찾음: %s" % ", ".join(b2.errors))
	check(_has_error(b2, "engine.power_gain[8] = 2.5"), "정수가 아닌 출력 증가를 못 찾음: %s" % ", ".join(b2.errors))

	var d3 := real_balance_dict()
	d3["engine"]["power_gain"][0] = 0   # 0은 괜찮음 (출력이 안 줄기만 하면 됨)
	check(Balance.from_dict(d3).is_ok(), "출력 증가 0인데 막힘")


## 지시서 C1 ⑧: 비율은 0~1
func test_rates_must_be_0_to_1() -> void:
	var cases := [
		["trip", "fuel_rate", 1.2],
		["trip", "maint_rate", -0.1],
		["offline", "rate", 1.5],
		["engine", "spare_drop_chance", 2.0],
	]
	for c in cases:
		var d := real_balance_dict()
		d[c[0]][c[1]] = c[2]
		var b: Balance = Balance.from_dict(d)
		check(_has_error(b, "%s.%s = %s (0~1 사이여야 함)" % c), "%s.%s = %s 를 못 찾음: %s" % [c[0], c[1], c[2], ", ".join(b.errors)])
	for c in [["trip", "fuel_rate", 0.0], ["offline", "rate", 1.0], ["engine", "spare_drop_chance", 0.0]]:
		var d := real_balance_dict()
		d[c[0]][c[1]] = c[2]
		check(Balance.from_dict(d).is_ok(), "%s.%s = %s (경계값)인데 막힘" % c)


## 기름값 + 정비비가 단가를 넘어 배송 1건 돈이 마이너스가 되면 막음
func test_negative_parcel_pay_is_reported() -> void:
	var d := real_balance_dict()
	d["trip"]["fuel_rate"] = 0.7
	d["trip"]["maint_rate"] = 0.4
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "배송 1건 돈 = -250"), "마이너스 배송 돈을 못 찾음: %s" % ", ".join(b.errors))
	# 비율 합이 1 이하여도 반올림으로 넘칠 수 있음: 단가 1, 0.5 + 0.5 → 1 − 1 − 1 = −1
	var d2 := real_balance_dict()
	d2["trip"]["unit_price"] = 1
	d2["trip"]["fuel_rate"] = 0.5
	d2["trip"]["maint_rate"] = 0.5
	check(_has_error(Balance.from_dict(d2), "배송 1건 돈 = -1"), "반올림으로 생긴 마이너스를 못 찾음")


## 지시서 C1 ⑧: cost_mult > 1
func test_cost_mult_over_one() -> void:
	for v in [1, 0.9, 0]:
		var d := real_balance_dict()
		d["engine"]["cost_mult"] = v
		var b: Balance = Balance.from_dict(d)
		check(_has_error(b, "engine.cost_mult = %s (1보다 커야 함)" % v), "cost_mult = %s 를 못 찾음: %s" % [v, ", ".join(b.errors)])
	var d2 := real_balance_dict()
	d2["engine"]["cost_mult"] = 1.0001
	check(Balance.from_dict(d2).is_ok(), "cost_mult 1.0001인데 막힘")


func test_bad_values_are_reported() -> void:
	var d := real_balance_dict()
	d["trip"].erase("unit_price")
	d["trip"]["base_cargo"] = 0
	d["trip"]["road_length"] = 0
	d["trip"]["stop_seconds"] = -1
	d["engine"]["base_power"] = 0
	d["engine"]["cost_base"] = 0
	d["engine"]["spare_price"] = 100.5
	d["engine"]["success"][5] = "많이"
	d["offline"]["cap_hours"] = -1
	var b: Balance = Balance.from_dict(d)
	for part in ["trip.unit_price 이 없음", "trip.base_cargo = 0", "trip.road_length = 0", "trip.stop_seconds = -1",
			"engine.base_power = 0", "engine.cost_base = 0", "engine.spare_price = 100.5",
			"engine.success[5] 가 숫자가 아님", "offline.cap_hours = -1"]:
		check(_has_error(b, part), "못 찾음: %s" % part)
	note("찾은 문제: " + " / ".join(b.errors))


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


func test_bad_max_star_is_reported() -> void:
	var d := real_balance_dict()
	d["engine"]["max_star"] = 30.5
	var b: Balance = Balance.from_dict(d)
	check(_has_error(b, "engine.max_star"), "정수가 아닌 max_star를 못 찾음")


func test_broken_json_is_reported() -> void:
	var b: Balance = Balance.from_text("{ \"trip\": { \"unit_price\": 100, }")
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
