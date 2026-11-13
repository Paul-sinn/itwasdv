## save.gd: 저장 형식 4 쓰고 읽기(세팅), 형식 3 읽기, 깨진 파일, 백업 3개, 옛 형식 남기기
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Save = preload("res://scripts/core/save.gd")

# 옛 형식 파일이 "같은 폴더/save.v2.json"으로 가서, 진짜 저장 폴더와 겹치지 않게 시험용 폴더를 씀
const DIR := "user://test_unit_save"
const PATH := DIR + "/save.json"
const OLD_KEPT := DIR + "/save.v2.json"

var b: Balance = Balance.load_file()


## 시험 폴더를 비운다 (본 파일·임시·백업·.broken·옛 형식)
func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	Save.delete_file(PATH)
	for p in [PATH + ".broken", OLD_KEPT]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _save_with_money(money: int) -> void:
	var s := _sample_state()
	s.money = money
	Save.write_file(PATH, s, 1794000000)


## 그 파일에 적힌 돈 (백업 확인용)
func _money_in(path: String):
	if not FileAccess.file_exists(path):
		return null
	var r := Save.from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)), b)
	return r["state"].money if r["status"] == Save.Status.OK else null


func _sample_state() -> GameState:
	var s := GameState.new_game()
	s.money = 123456789
	s.spares = 2
	s.spare_drop_carry = 0.3125
	var t := s.truck(0)
	t.star = 22
	t.lap_clock = 37.25
	t.lap_delivered = 3
	t.success_count = 40
	t.fail_count = 77
	t.destroy_count = 3
	t.boost_lap = true
	var box := t.part("cargo_box")
	box["grade"] = 2
	box["lines"] = ["speed", "cargo", "junk_ride"]
	box["counters"] = [0, 3, 12, 0, 0]
	box["pending"] = { "grade": 3, "lines": ["cargo", "cargo", "fuel_cut"] }
	var ecu := t.part("ecu")
	ecu["lines"] = ["overboost"]
	ecu["counters"] = [4, 0, 0, 0, 0]
	var t2 := TruckState.new()
	t2.star = 5
	t2.lap_clock = 0.1
	s.trucks.append(t2)
	return s


func test_write_then_read_same() -> void:
	_clean()
	var s := _sample_state()
	var when := 1794000000
	check_eq(Save.write_file(PATH, s, when), OK, "쓰기")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "읽기 상태 (%s)" % r["error"])
	var got: GameState = r["state"]
	check_eq(r["saved_at"], when, "저장 시각")
	check_eq(got.money, 123456789, "돈")
	check_eq(typeof(got.money), TYPE_INT, "돈이 정수가 아님")
	check_eq(got.spares, 2, "스페어")
	check_eq(got.spare_drop_carry, 0.3125, "스페어 소수 나머지")
	check_eq(got.trucks.size(), 2, "트럭 수")
	var t := got.truck(0)
	check_eq([t.star, t.lap_clock, t.lap_delivered], [22, 37.25, 3], "트럭 0 단계·바퀴")
	check_eq([t.success_count, t.fail_count, t.destroy_count], [40, 77, 3], "트럭 0 통계")
	check_eq([got.truck(1).star, got.truck(1).lap_clock], [5, 0.1], "트럭 1")
	check_eq(t.boost_lap, true, "오버부스트 바퀴")
	check_eq(t.settings, s.truck(0).settings, "세팅 (pending 포함)")
	check_eq(t.part("cargo_box")["pending"], { "grade": 3, "lines": ["cargo", "cargo", "fuel_cut"] }, "고르는 중인 새 상태")
	check_eq(t.part("ecu")["pending"], null, "ECU pending 없음")
	check_eq(got.truck(1).settings, {}, "트럭 1 세팅 없음")
	check_eq([r["recovered"], r["old_kept"]], [false, ""], "보통 읽기: 복구·옛 형식 아님")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남음")
	_clean()


func test_format_4_dict() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	check_eq(d["version"], 4, "저장 형식")
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["money", "saved_at_utc", "spare_drop_carry", "spares", "trucks", "version"], "저장 칸")
	var tk: Array = d["trucks"][0].keys()
	tk.sort()
	check_eq(tk, ["boost_lap", "destroy_count", "fail_count", "lap_clock", "lap_delivered", "settings", "star", "success_count"], "트럭 칸")


## v4 C1 ⑪: 형식 3 파일(v3, 세팅 칸 없음)도 그대로 읽힘 (옮겨 두지 않음)
func test_format_3_file_reads() -> void:
	_clean()
	var v3 := {
		"version": 3, "saved_at_utc": "2026-11-13T09:30:00", "money": "5000000", "spares": 1, "spare_drop_carry": 0.25,
		"trucks": [{ "star": 18, "lap_clock": 12.5, "lap_delivered": 2, "success_count": 30, "fail_count": 40, "destroy_count": 1 }],
	}
	_write_text(PATH, JSON.stringify(v3))
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "형식 3 읽기 (%s)" % r["error"])
	check_eq(r["old_kept"], "", "형식 3을 옮겨 둠")
	check(not FileAccess.file_exists(OLD_KEPT), "형식 3인데 save.v2.json이 생김")
	if r["state"] != null:
		var t: TruckState = r["state"].truck(0)
		check_eq([r["state"].money, t.star, t.lap_delivered], [5000000, 18, 2], "형식 3 값")
		check_eq([t.settings, t.boost_lap], [{}, false], "형식 3: 세팅 없음, 오버부스트 아님")
	_clean()


## v4 C1 ⑪: 세팅의 이상한 값 — 모르는 부품·옵션은 버리고, 등급·카운터는 범위로, 줄은 그 등급 줄 수까지
func test_settings_clamped() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	d["trucks"][0]["settings"] = {
		"wing": { "grade": 1, "lines": ["speed"], "counters": [0, 0, 0, 0, 0], "pending": null },
		"cargo_box": { "grade": 0, "lines": ["nitro", "engine_guard", "cargo", "speed", 5], "counters": [99, -5, 1000, 9999, 7, 5],
				"pending": { "grade": 7, "lines": ["speed", "speed", "speed", "speed"] } },
		"ecu": { "grade": -1, "lines": [], "counters": [2.7] },
	}
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	if r["state"] == null:
		return
	var st: Dictionary = r["state"].truck(0).settings
	check(not st.has("wing"), "모르는 부품(wing)을 안 버림")
	var box: Dictionary = st["cargo_box"]
	check_eq(box["lines"], ["cargo"], "모르는 옵션·그 부품에 없는 옵션은 버리고 순정 줄 수 1까지 (앞에서부터)")
	check_eq(box["counters"], [4, 0, 79, 499, 0], "카운터는 0 ~ 천장−1, 길이 5")
	check_eq(box["pending"], { "grade": 4, "lines": ["speed", "speed", "speed"] }, "pending 등급 7 → 4, 줄 3까지")
	check_eq([st["ecu"]["grade"], st["ecu"]["counters"], st["ecu"]["pending"]], [0, [2, 0, 0, 0, 0], null], "ECU 등급 −1 → 0, 빠진 pending → null")
	# 모양이 틀리면 깨진 저장
	var bad_cases := [
		["boost_lap", "yes"],
		["settings", "전부 전설"],
		["settings", { "cargo_box": 3 }],
		["settings", { "cargo_box": { "grade": "높음", "lines": [] } }],
		["settings", { "cargo_box": { "grade": 1, "lines": "speed" } }],
		["settings", { "cargo_box": { "grade": 1, "lines": [], "counters": 5 } }],
		["settings", { "cargo_box": { "grade": 1, "lines": [], "counters": ["a"] } }],
		["settings", { "cargo_box": { "grade": 1, "lines": [], "pending": { "grade": 1 } } }],
	]
	for c in bad_cases:
		var d2 := Save.to_dict(_sample_state(), 1794000000)
		d2["trucks"][0][c[0]] = c[1]
		check_eq(Save.from_dict(d2, b)["status"], Save.Status.BROKEN, "trucks[0].%s = %s 를 못 걸러냄" % [c[0], c[1]])


func test_no_file_is_new_game() -> void:
	_clean()
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.NONE, "파일 없음 → 새 게임")
	check_eq([r["recovered"], r["old_kept"]], [false, ""], "파일 없음: 복구·옛 형식 아님")


## 백업이 없을 때 깨진 파일 → BROKEN, .broken으로 남김
func test_broken_json_is_new_game_and_kept() -> void:
	_clean()
	_write_text(PATH, "{ \"money\": 10, ")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.BROKEN, "깨진 JSON")
	check(not r["recovered"], "백업이 없는데 복구됐다고 나옴")
	check(FileAccess.file_exists(PATH + ".broken"), "깨진 파일을 .broken으로 안 남김")
	check(not FileAccess.file_exists(PATH), "깨진 파일이 그대로 남음")
	_clean()


## 돈이 2^53(약 9007조)을 넘어도 정확히 왕복 (JSON 숫자는 끝자리가 틀려져서 글자로 씀)
func test_big_money_round_trip() -> void:
	_clean()
	for money in [9_000_000_000_000_001, 9_100_000_000_000_001, 9_007_199_254_740_993, 0, 1]:
		_save_with_money(money)
		var r := Save.read_file(PATH, b)
		check_eq(r["status"], Save.Status.OK, "돈 %d 읽기 (%s)" % [money, r["error"]])
		if r["state"] != null:
			check_eq(r["state"].money, money, "돈 %d 왕복" % money)
	check_eq(Save.to_dict(_sample_state(), 0)["money"], "123456789", "돈은 글자로 씀")
	_clean()


## 돈 칸: 글자·숫자 둘 다 받음. 음수·소수·이상한 글자는 깨진 저장, 18자리 넘으면 자름
func test_money_text_or_number() -> void:
	var good := Save.to_dict(_sample_state(), 1794000000)
	var ok_cases := [["5000", 5000], [5000, 5000], [5000.0, 5000], ["0", 0], ["0005", 5],
			["9223372036854775808", Save.MAX_MONEY], ["99999999999999999999", Save.MAX_MONEY], [1e30, Save.MAX_MONEY]]
	for c in ok_cases:
		var d := good.duplicate(true)
		d["money"] = c[0]
		var r := Save.from_dict(d, b)
		check_eq(r["status"], Save.Status.OK, "money = %s 읽기 (%s)" % [c[0], r["error"]])
		if r["state"] != null:
			check_eq(r["state"].money, c[1], "money = %s" % [c[0]])
	for bad in ["-5", "+5", "12a", "", "1e3", "5.0", -1, 10.5]:
		var d := good.duplicate(true)
		d["money"] = bad
		check_eq(Save.from_dict(d, b)["status"], Save.Status.BROKEN, "money = %s 를 못 걸러냄" % [bad])


## 4번 저장하면 본 파일 = 4번째, bak1~3 = 3·2·1번째 (가장 최근이 bak1). 5번째에 1번째가 밀려남
func test_backups_keep_last_three() -> void:
	_clean()
	for money in [1, 2, 3, 4]:
		_save_with_money(money)
	check_eq([_money_in(PATH), _money_in(PATH + ".bak1"), _money_in(PATH + ".bak2"), _money_in(PATH + ".bak3")],
			[4, 3, 2, 1], "4번 저장: 본·bak1·bak2·bak3")
	_save_with_money(5)
	check_eq([_money_in(PATH), _money_in(PATH + ".bak1"), _money_in(PATH + ".bak2"), _money_in(PATH + ".bak3")],
			[5, 4, 3, 2], "5번 저장: 가장 오래된 것이 밀려남")
	check(not FileAccess.file_exists(PATH + ".bak4"), "bak4가 생김")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남음")
	_clean()


## 본 파일이 깨지면 .broken으로 옮기고 bak1에서 살림 (recovered)
func test_broken_main_recovers_from_bak1() -> void:
	_clean()
	for money in [1, 2, 3]:
		_save_with_money(money)
	_write_text(PATH, "{ 깨진 파일")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "백업에서 못 살림")
	check(r["recovered"], "recovered 가 안 켜짐")
	check(r["error"].contains("JSON 형식이 깨짐"), "본 파일이 깨진 이유가 error에 없음: %s" % r["error"])
	if r["state"] != null:
		check_eq(r["state"].money, 2, "bak1(바로 전 저장)에서 살림")
	check_eq(FileAccess.get_file_as_string(PATH + ".broken"), "{ 깨진 파일", "깨진 본 파일을 .broken으로 안 남김")
	# 살린 뒤 다음 저장: 본 파일이 없으니 백업은 그대로 (살린 bak1이 밀려나지 않음)
	_save_with_money(10)
	check_eq([_money_in(PATH), _money_in(PATH + ".bak1"), _money_in(PATH + ".bak2")], [10, 2, 1], "살린 뒤 저장")
	_clean()


## bak1도 깨졌으면 다음 백업, 옛 형식 백업은 건너뜀
func test_recovers_from_next_backup() -> void:
	_clean()
	for money in [1, 2, 3, 4]:
		_save_with_money(money)
	_write_text(PATH, "")
	_write_text(PATH + ".bak1", "[1, 2")
	_write_text(PATH + ".bak2", JSON.stringify({ "version": 2, "money": 99.0 }))
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "bak3에서 못 살림")
	check(r["recovered"], "recovered 가 안 켜짐")
	if r["state"] != null:
		check_eq(r["state"].money, 1, "bak1 깨짐, bak2 옛 형식 → bak3에서 살림")
	_clean()


## 본 파일·백업 전부 깨지면 BROKEN (새 게임)
func test_all_broken_is_new_game() -> void:
	_clean()
	for money in [1, 2, 3, 4]:
		_save_with_money(money)
	for p in [PATH, PATH + ".bak1", PATH + ".bak2", PATH + ".bak3"]:
		_write_text(p, "{")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.BROKEN, "전부 깨졌는데 BROKEN이 아님")
	check(not r["recovered"], "전부 깨졌는데 recovered")
	check(r["state"] == null, "전부 깨졌는데 상태가 있음")
	check(FileAccess.file_exists(PATH + ".broken"), "깨진 본 파일을 .broken으로 안 남김")
	_clean()


## 형식 1·2 파일: 변환하지 않고 같은 폴더 save.v2.json으로 옮기고 새 게임(NONE)
func test_old_format_is_kept_aside() -> void:
	for version in [1, 2]:
		_clean()
		var old := JSON.stringify({
			"version": version, "saved_at_utc": "2026-11-10T09:30:00", "money": 5000.5, "star": 17,
			"broken": false, "star_before_break": 0, "success_count": 20, "fail_count": 30, "destroy_count": 0,
		})
		_write_text(PATH, old)
		var r := Save.read_file(PATH, b)
		check_eq(r["status"], Save.Status.NONE, "형식 %d → 새 게임" % version)
		check_eq(r["old_kept"], OLD_KEPT, "형식 %d: 옮긴 경로" % version)
		check(not r["recovered"], "형식 %d: recovered 가 켜짐" % version)
		check(not FileAccess.file_exists(PATH), "형식 %d: 본 파일이 그대로 남음" % version)
		check_eq(FileAccess.get_file_as_string(OLD_KEPT), old, "형식 %d: save.v2.json 내용이 원래 파일과 다름" % version)
		check(not FileAccess.file_exists(PATH + ".broken"), "형식 %d: 깨진 파일로 취급함" % version)
	_clean()


## F3 치트: 백업까지 지움
func test_delete_removes_backups() -> void:
	_clean()
	for money in [1, 2, 3, 4]:
		_save_with_money(money)
	Save.delete_file(PATH)
	for p in [PATH, PATH + ".tmp", PATH + ".bak1", PATH + ".bak2", PATH + ".bak3"]:
		check(not FileAccess.file_exists(p), "%s 가 남음" % p.get_file())
	check_eq(Save.read_file(PATH, b)["status"], Save.Status.NONE, "지운 뒤 새 게임")


func test_bad_values_are_broken() -> void:
	var good := Save.to_dict(_sample_state(), 1794000000)
	var cases := [
		["money", -5],
		["money", 10.5],
		["money", [5]],
		["spares", -1],
		["spares", "많이"],
		["spare_drop_carry", "조금"],
		["trucks", []],
		["trucks", "트럭"],
		["trucks", [5]],
		["saved_at_utc", "어제 저녁"],
	]
	for bad_time in ["2026-13-01T00:00:00", "2026-02-31T00:00:00", "2026-11-10 09:30:00", "2026-11-10T24:00:00"]:
		cases.append(["saved_at_utc", bad_time])
	for c in cases:
		var d := good.duplicate(true)
		d[c[0]] = c[1]
		check_eq(Save.from_dict(d, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % [c[0], c[1]])
	for key in ["star", "lap_clock", "fail_count"]:
		var d := good.duplicate(true)
		d["trucks"][0][key] = "많이"
		check_eq(Save.from_dict(d, b)["status"], Save.Status.BROKEN, "trucks[0].%s 글자를 못 걸러냄" % key)
	var missing := good.duplicate(true)
	missing.erase("money")
	check_eq(Save.from_dict(missing, b)["status"], Save.Status.BROKEN, "money 빠진 걸 못 걸러냄")
	var missing2 := good.duplicate(true)
	missing2["trucks"][0].erase("star")
	check_eq(Save.from_dict(missing2, b)["status"], Save.Status.BROKEN, "trucks[0].star 빠진 걸 못 걸러냄")
	check_eq(Save.from_dict(good, b)["status"], Save.Status.OK, "멀쩡한 묶음이 깨졌다고 나옴")


## 범위 밖 값은 자르고, 모르는 키는 버림
func test_out_of_range_is_clamped() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	d["spare_drop_carry"] = 3.5
	d["wing"] = 7
	d["trucks"][0]["star"] = 31
	d["trucks"][0]["lap_clock"] = -4.0
	d["trucks"][0]["lap_delivered"] = -1
	d["trucks"][0]["fail_count"] = -9
	d["trucks"][0]["turbo"] = 3
	d["trucks"][1]["star"] = -2
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	var s: GameState = r["state"]
	check(s.spare_drop_carry < 1.0, "소수 나머지 3.5가 1 미만으로 안 잘림: %s" % s.spare_drop_carry)
	check_eq(s.truck(0).star, b.max_star, "단계 31 → 30")
	check_eq(s.truck(0).lap_clock, 0.0, "바퀴 시각 -4 → 0")
	check_eq(s.truck(0).lap_delivered, 0, "배송 수 -1 → 0")
	check_eq(s.truck(0).fail_count, 0, "통계 -9 → 0")
	check_eq(s.truck(1).star, 0, "단계 -2 → 0")


func test_tmp_left_over_is_recovered() -> void:
	# 백업으로 돌린 뒤 바꿔 끼우는 순간 꺼져서 본 파일 없이 .tmp 만 남은 경우
	_clean()
	_save_with_money(1)
	_save_with_money(2)
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, ".tmp 에서 못 살림")
	if r["state"] != null:
		check_eq(r["state"].money, 2, ".tmp(가장 최근)를 씀")
	check(not r["recovered"], ".tmp는 백업 복구가 아님")
	_clean()
