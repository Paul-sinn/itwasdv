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
	check_eq([b.fuel_rate, b.maint_rate], [0.2, 0.05], "기름값·정비비 비율 (v6-bal: 기름값 20%)")
	check_eq([b.cost_base, b.cost_mult, b.spare_drop_chance], [35000.0, 1.5, 0.00005], "강화 비용·스페어 드랍 (v4에서 고침)")
	check_eq(b.spare_price, 5000000, "spare_price (v4에서 고침)")
	# v5: 꺼둔 동안 시간·비율은 depot 표로 (test_v5_numbers_match_spec)
	check_eq(b.offline_ignore_under_seconds, 180.0, "꺼둔 동안 3분 미만 무시")
	check_eq(typeof(b.spare_price), TYPE_INT, "spare_price는 정수")


## 지운 묶음(income, tune 등)이 다시 생기지 않게: v5 json은 trip / engine / offline / setting / driver / depot / quests + version
func test_real_file_shape() -> void:
	var d := real_balance_dict()
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["abilities", "depot", "driver", "engine", "offline", "quests", "setting", "trip", "version"], "json 묶음 (v5b: abilities)")
	check_eq(d["version"], "0.10", "version")
	check(not d["engine"].has("cost_hours"), "engine.cost_hours 가 남아 있음")
	check_eq(d["offline"].keys(), ["ignore_under_seconds"], "offline 묶음에는 ignore_under_seconds만 (cap_hours·rate는 depot 표로)")


func test_missing_section_is_reported() -> void:
	for section in ["trip", "engine", "offline", "setting", "driver", "depot"]:
		var d := real_balance_dict()
		d.erase(section)
		var b: Balance = Balance.from_dict(d)
		check(_has_error(b, "\"%s\" 묶음이 없음" % section), "%s 묶음이 빠진 걸 못 찾음: %s" % [section, ", ".join(b.errors)])
	var dq := real_balance_dict()
	dq.erase("quests")
	check(_has_error(Balance.from_dict(dq), "\"quests\" 목록이 없거나 비어 있음"), "quests 목록이 빠진 걸 못 찾음")


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
		["engine", "spare_drop_chance", 2.0],
	]
	for c in cases:
		var d := real_balance_dict()
		d[c[0]][c[1]] = c[2]
		var b: Balance = Balance.from_dict(d)
		check(_has_error(b, "%s.%s = %s (0~1 사이여야 함)" % c), "%s.%s = %s 를 못 찾음: %s" % [c[0], c[1], c[2], ", ".join(b.errors)])
	for c in [["trip", "fuel_rate", 0.0], ["engine", "spare_drop_chance", 0.0]]:
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
	d["offline"]["ignore_under_seconds"] = -1
	var b: Balance = Balance.from_dict(d)
	for part in ["trip.unit_price 이 없음", "trip.base_cargo = 0", "trip.road_length = 0", "trip.stop_seconds = -1",
			"engine.base_power = 0", "engine.cost_base = 0", "engine.spare_price = 100.5",
			"engine.success[5] 가 숫자가 아님", "offline.ignore_under_seconds = -1"]:
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
	d["engine"]["destroy"][18] = 0.9   # 성공 0.3 + 퍼짐 0.9 = 1.2
	var b: Balance = Balance.from_dict(d)
	check(not b.is_ok(), "성공+퍼짐이 1 넘는데 통과됨")
	check(_has_error(b, "engine.success[18] + engine.destroy[18]"), "어디가 틀렸는지 안 알려줌: %s" % ", ".join(b.errors))


func test_sum_exactly_one_is_ok() -> void:
	var d := real_balance_dict()
	d["engine"]["destroy"][18] = 0.7   # 0.3 + 0.7 = 1 (딱 1은 괜찮음)
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


## v5 C1 ①: driver·depot·offline·quests 값이 지시서 "옮길 숫자"와 같음 (값을 찍음)
func test_v5_numbers_match_spec() -> void:
	var b: Balance = Balance.load_file()
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq([b.driver_xp_per_parcel, b.driver_star_milestone_xp], [10, 500], "경험치 얻는 법 B2, B7")
	check_eq([b.driver_base_xp, b.driver_exponent, b.driver_points_per_level, b.driver_bonus_points_every_10],
			[100.0, 1.33, 1, 2], "레벨 곡선 B1:B4 (v6-bal: 지수 1.33)")
	check_eq(b.warehouse_hours, PackedFloat64Array([4, 6, 8, 12]), "오프라인 C2:C5 창고 시간")
	check_eq(b.night_rates, PackedFloat64Array([0.5, 0.6, 0.7, 0.8]), "오프라인 C6:C9 야간팀 비율")
	check_eq([b.driver_max_level, b.offline_ignore_under_seconds, b.warehouse_max_level_solo], [50, 180.0, 3], "기획서에서 온 값")
	check_eq(b.driver_star_milestones, PackedInt64Array([10, 15, 18, 20, 22, 25, 28, 30]), "강화 첫 달성 단계")
	check_eq(b.warehouse_prices, PackedInt64Array([2000000, 3000000, 40000000]), "창고 가격 (v6-bal B2: 본전 3~5시간)")
	check_eq(b.night_prices, PackedInt64Array([1500000, 2200000, 2500000]), "야간팀 가격 (v6-bal B2: 본전 3~5시간)")
	var want := [
		["first_parcel", "parcels", 1, "", 200, 10000], ["parcels_20", "parcels", 20, "", 200, 20000],
		["first_enhance", "star", 1, "", 200, 30000], ["first_setting", "setting_rolls", 1, "", 200, 40000],
		["star_3", "star", 3, "", 200, 50000], ["setting_street", "setting_grade", 1, "", 300, 100000],
		["star_5", "star", 5, "", 300, 150000], ["ecu_first", "part_rolled", 1, "ecu", 300, 150000],
		["warehouse_2", "warehouse", 2, "", 300, 200000], ["level_5", "level", 5, "", 300, 200000],
		["star_8", "star", 8, "", 400, 300000], ["setting_sport", "setting_grade", 2, "", 400, 400000],
		["night_2", "night", 2, "", 400, 400000], ["star_10", "star", 10, "", 500, 600000],
		["level_10", "level", 10, "", 500, 600000], ["warehouse_3", "warehouse", 3, "", 500, 800000],
		["star_12", "star", 12, "", 600, 1000000],
		["star_15", "star", 15, "", 800, 1000000], ["level_20", "level", 20, "", 800, 1000000],   # v6-bal: 보상 돈 줄임
		["setting_racing", "setting_grade", 3, "", 1000, 1000000], ["first_spare", "spares_bought", 1, "", 600, 1000000],
		["star_18", "star", 18, "", 1000, 1500000],
	]
	var got := []
	for q in b.quests:
		got.append([q["id"], q["kind"], q["target"], q["part"], q["xp"], q["money"]])
	check_eq(got, want, "퀘스트 22개")
	note("driver: 배송 %d, 첫 달성 %d (단계 %s), base %s, 지수 %s, 포인트 %d (+%d), 만렙 %d"
			% [b.driver_xp_per_parcel, b.driver_star_milestone_xp, b.driver_star_milestones, b.driver_base_xp,
			b.driver_exponent, b.driver_points_per_level, b.driver_bonus_points_every_10, b.driver_max_level])
	note("depot: 창고 %s 가격 %s (대리점 전 Lv%d), 야간팀 %s 가격 %s, 3분 미만 무시 %s초"
			% [b.warehouse_hours, b.warehouse_prices, b.warehouse_max_level_solo, b.night_rates, b.night_prices, b.offline_ignore_under_seconds])
	var rows := PackedStringArray()
	for q in got:
		rows.append("%s(%s %d, %d xp, %d원)" % [q[0], q[1], q[2], q[4], q[5]])
	note("quests %d개: %s" % [got.size(), ", ".join(rows)])


## v6-bal B1 ①: 지시서 "옮길 숫자" (스냅샷 1번·5번, Q1·Q7·Q14)와 같고, 단계마다 성공 + 퍼짐 ≤ 1 (값을 찍음)
func test_v6bal_numbers_match_spec() -> void:
	var b: Balance = Balance.load_file()
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	var success := PackedFloat64Array([0.95, 0.91, 0.87, 0.83, 0.79, 0.75, 0.71, 0.67, 0.63, 0.59, 0.50, 0.46, 0.42, 0.39, 0.35,
			0.33, 0.32, 0.30, 0.30, 0.30, 0.30, 0.30, 0.10, 0.06, 0.03, 0.03, 0.025, 0.02, 0.015, 0.01])
	var destroy := PackedFloat64Array()
	destroy.resize(18)   # +0~+17은 0
	destroy.append_array([0.02, 0.03, 0.04, 0.05, 0.08, 0.11, 0.15, 0.15, 0.16, 0.17, 0.18, 0.20])
	check_eq(b.success, success, "engine.success (스냅샷 1번)")
	check_eq(b.destroy, destroy, "engine.destroy (스냅샷 1번)")
	var worst := 0.0
	for s in b.max_star:
		check(b.success[s] + b.destroy[s] <= 1.0 + Balance.SUM_EPSILON, "+%d 성공 + 퍼짐 > 1" % s)
		worst = maxf(worst, b.success[s] + b.destroy[s])
	var cumulative := [b.base_power]
	for s in b.max_star:
		cumulative.append(cumulative.back() + b.power_gain[s])
	check_eq([cumulative[1], cumulative[10], cumulative[15], cumulative[18], cumulative[20], cumulative[25], cumulative[30]],
			[105, 150, 200, 260, 300, 475, 775], "누적 출력 (스냅샷 1번)")
	check_eq(b.fuel_rate, 0.2, "trip.fuel_rate (Q7-3)")
	check_eq(b.roll_cost, PackedInt64Array([20000, 80000, 1600000, 6000000, 10000000]), "setting.roll_cost (Q7-1)")
	check_eq(b.setting_options["speed"]["weight"], 10.0, "이동 속도 가중치 (Q7-3)")
	check_eq(b.setting_options["fuel_cut"]["values"], PackedFloat64Array([0.10, 0.20, 0.30, 0.45, 0.60]), "기름값 절감 (스냅샷 5번)")
	check_eq(b.setting_options["overboost"]["values"], PackedFloat64Array([0.03, 0.06, 0.09, 0.15, 0.24]), "오버부스트 (스냅샷 5번)")
	check(not real_balance_dict()["setting"].has("overboost_seconds"), "setting.overboost_seconds 가 남아 있음 (규칙 1에서 지움)")
	check_eq(b.overboost_mult, 2.0, "오버부스트 걸린 바퀴 운전 속도 2배")
	check_eq(b.driver_exponent, 1.33, "driver.exponent (Q14-1)")
	note("성공 + 퍼짐 최대 %.3f, 기름값 %s, 돌리기 비용 %s, 기름값 절감 %s, 오버부스트 %s" % [worst, b.fuel_rate, b.roll_cost,
			b.setting_options["fuel_cut"]["values"], b.setting_options["overboost"]["values"]])


## v5: driver·depot·quests의 틀린 숫자를 찾음 (끝낼 수 없는 퀘스트 포함)
func test_v5_bad_values_are_reported() -> void:
	var d := real_balance_dict()
	d["driver"]["max_level"] = 1
	d["driver"]["exponent"] = -1
	d["driver"]["star_milestones"] = [10, 10]
	d["depot"]["warehouse_hours"] = [4, 3, 8, 12]
	d["depot"]["night_rates"] = [0.5, 1.5, 0.7, 0.8]
	d["depot"]["night_prices"] = [1, 2]
	d["depot"]["warehouse_max_level_solo"] = 5
	d["offline"]["ignore_under_seconds"] = -1
	d["quests"][1]["id"] = "first_parcel"
	d["quests"][2]["kind"] = "dance"
	d["quests"][3]["target"] = 0
	d["quests"][4]["money"] = -5
	d["quests"][5]["target"] = 5      # 세팅 등급 5는 없음
	d["quests"][7]["part"] = "wing"
	var b: Balance = Balance.from_dict(d)
	for part in ["driver.max_level = 1", "driver.exponent = -1", "driver.star_milestones[1] = 10 (앞 값 10보다 커야 함)",
			"depot.warehouse_hours[1] = 3", "depot.night_rates[1] = 1.5", "depot.night_prices 길이가 2개",
			"depot.warehouse_max_level_solo = 5", "offline.ignore_under_seconds = -1",
			"quests[1].id = first_parcel", "quests[2].kind = dance", "quests[3].target = 0", "quests[4].money = -5",
			"quests[5].target = 5", "quests[7].part = wing"]:
		check(_has_error(b, part), "못 찾음: %s" % part)
	note("찾은 문제: " + " / ".join(b.errors))
	var d2 := real_balance_dict()
	d2["driver"]["star_milestones"] = [10, 31]
	d2["quests"][15]["target"] = 4     # 창고 Lv4는 대리점부터라 못 끝냄
	var b2: Balance = Balance.from_dict(d2)
	check(_has_error(b2, "driver.star_milestones[1] = 31"), "max_star 넘는 보너스 단계를 못 찾음")
	check(_has_error(b2, "quests[15].target = 4"), "대리점 전에 못 사는 창고 Lv4 퀘스트를 못 찾음")


func _has_error(b: Balance, part: String) -> bool:
	for e in b.errors:
		if e.contains(part):
			return true
	return false
