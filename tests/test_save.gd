## save.gd: 저장 형식 7 쓰고 읽기(세팅, 레벨·창고·퀘스트, 지금 바퀴 건수, 능력치), 형식 3~6 읽기, 깨진 파일, 백업 3개, 옛 형식 남기기
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Ability = preload("res://scripts/core/ability.gd")
const Quest = preload("res://scripts/core/quest.gd")

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
	t.lap_cargo = 22
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
	# 형식 5
	s.driver_level = 12
	s.driver_xp = 345
	s.ability_points = 13
	s.reputation = 0
	s.warehouse_level = 3
	s.night_level = 2
	s.quest_index = 17
	s.parcels_total = 98765
	s.setting_rolls = 44
	s.spares_bought = 2
	s.parts_rolled = { "cargo_box": true, "ecu": true }
	s.milestones_done = [10, 15, 18, 20]
	# 형식 7 (받은 포인트 13 중 10)
	s.abilities = { "nego": 7, "kind": 3 }
	return s


## 형식 5에 더한 칸들의 값 (비교용)
func _progress(s: GameState) -> Array:
	var out := []
	for key in Save.PROGRESS_INTS + ["parts_rolled", "milestones_done"]:
		out.append(s.get(key))
	return out


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
	check_eq([t.lap_cargo, got.truck(1).lap_cargo], [22, 0], "지금 바퀴 건수 (트럭 1은 아직 안 굴림)")
	check_eq(t.settings, s.truck(0).settings, "세팅 (pending 포함)")
	check_eq(t.part("cargo_box")["pending"], { "grade": 3, "lines": ["cargo", "cargo", "fuel_cut"] }, "고르는 중인 새 상태")
	check_eq(t.part("ecu")["pending"], null, "ECU pending 없음")
	check_eq(got.truck(1).settings, {}, "트럭 1 세팅 없음")
	check_eq(_progress(got), _progress(s), "형식 5 칸 (레벨·창고·퀘스트 진행)")
	check_eq(got.abilities, { "nego": 7, "kind": 3 }, "형식 7 능력치")
	check_eq([r["recovered"], r["old_kept"]], [false, ""], "보통 읽기: 복구·옛 형식 아님")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남음")
	_clean()


func test_format_12_dict() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	check_eq(d["version"], 12, "저장 형식")
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["abilities", "ability_points", "company_stage", "driver_level", "driver_xp", "insured_day", "insurer_event", "long_laps", "long_unlocked", "master_bonus",
			"master_bonus_week", "master_day", "master_next_bonus", "master_next_day", "master_notice_week", "master_unlocked", "master_visit_week",
			"master_week", "milestones_done", "money", "night_level", "parcels_total", "parts_rolled", "premium_spares", "quest_index",
			"rank_first_done", "reputation", "rush_enabled", "rush_left", "rush_next", "rush_ring", "saved_at_utc", "setting_rolls",
			"spare_drop_carry", "spares", "spares_bought", "today_day", "today_sales", "today_staff", "today_tax", "trucks", "use_premium", "version",
			"visitor_day", "visitor_next", "warehouse_level", "weekly_done", "weekly_parcels", "weekly_week"],
			"저장 칸 (active_bonus·visitor_today는 저장 안 함, coupons 지움)")
	var tk: Array = d["trucks"][0].keys()
	tk.sort()
	check_eq(tk, ["boost_lap", "destroy_count", "fail_count", "lap_cargo", "lap_clock", "lap_delivered", "lap_route", "route", "settings", "star",
			"success_count"], "트럭 칸")


## v6-bal B1 ⑧: 껐다 켜도 지금 바퀴의 건수가 같음 (적재량 21.6 → 21건 바퀴, 22건 바퀴 둘 다).
## 저장 → JSON 글자 → 읽기 → 남은 집 배송 수가 저장 안 한 쪽과 같음
func test_lap_cargo_survives_restart() -> void:
	var seen := {}
	for seed_value in 40:
		var s := GameState.new_game()
		s.quest_index = 22
		var t := s.truck(0)
		var box := t.part("cargo_box")
		box["grade"] = 1
		box["lines"] = ["cargo", "junk_ride"]   # 8% → 21.6
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		Trip.advance(s, b, 0, 40.0, rng)   # +0: 40초면 바퀴 중간 (몇 집 배송)
		var n := t.lap_cargo
		if seen.has(n):
			continue
		seen[n] = true
		var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)
		check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
		if r["state"] == null:
			continue
		var loaded: GameState = r["state"]
		check_eq(loaded.truck(0).lap_cargo, n, "다시 켠 뒤 지금 바퀴 건수 (%d)" % n)
		var rest := n - t.lap_delivered
		var left := Trip.lap_seconds(b, s, 0) - t.lap_clock - 0.01   # 바퀴 끝 직전까지 (새 바퀴를 굴리기 전)
		var got_a := _parcels(Trip.advance(s, b, 0, left, RandomNumberGenerator.new()))
		var got_b := _parcels(Trip.advance(loaded, b, 0, left, RandomNumberGenerator.new()))
		check_eq([got_a, got_b], [rest, rest], "%d건 바퀴: 남은 집 배송 (안 끈 쪽, 다시 켠 쪽)" % n)
		note("seed %d: %d건 실은 바퀴, 40초에 %d집 배송 → 다시 켠 뒤 남은 %d집도 같음" % [seed_value, n, n - rest, rest])
	check_eq(seen.size(), 2, "21건 바퀴와 22건 바퀴를 둘 다 확인 (%s)" % [seen.keys()])


func _parcels(events: Array) -> int:
	return events.filter(func(e): return e["type"] == "parcel").size()


## v5b C1 ⑩: 능력치 저장 → 읽기 같음, 형식 6 파일(능력치 없음) 읽힘, 0~최대로 자름, 합이 받은 포인트를 넘으면 전부 0, 숫자 아니면 깨짐
func test_abilities_round_trip_and_clamp() -> void:
	var s := _sample_state()
	s.ability_points = 59
	s.abilities = { "unload": 30, "kind": 9, "nego": 20 }
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	if r["state"] != null:
		check_eq([r["state"].abilities, r["state"].ability_points], [{ "unload": 30, "kind": 9, "nego": 20 }, 59], "59포인트 다 찍은 것 그대로")
	# 형식 6 (v6-bal): 능력치 칸 없음 → 없음
	var d6 := Save.to_dict(_sample_state(), 1794000000)
	d6["version"] = 6
	d6.erase("abilities")
	var r6 := Save.from_dict(d6, b)
	check_eq(r6["status"], Save.Status.OK, "형식 6 읽기 (%s)" % r6["error"])
	if r6["state"] != null:
		check_eq([r6["state"].abilities, r6["state"].ability_points], [{}, 13], "형식 6: 능력치 없음, 받은 포인트 그대로")
	# 0~최대로 자름, 소수 버림, 모르는 id 버림 (합 24 ≤ 59)
	var dc := Save.to_dict(_sample_state(), 1794000000)
	dc["ability_points"] = 59
	dc["abilities"] = { "nego": 99, "kind": -3, "unload": 4.7, "luck": 5 }
	var rc := Save.from_dict(dc, b)
	check_eq(rc["status"], Save.Status.OK, "자르기 (%s)" % rc["error"])
	if rc["state"] != null:
		check_eq(rc["state"].abilities, { "nego": 20, "unload": 4 }, "협상 99 → 20, 음수 → 0, 4.7 → 4, luck 버림")
	# 합이 받은 포인트(13)를 넘음 → 전부 0
	var dover := Save.to_dict(_sample_state(), 1794000000)
	dover["abilities"] = { "nego": 10, "kind": 10 }
	var ro := Save.from_dict(dover, b)
	check_eq(ro["status"], Save.Status.OK, "넘는 파일 읽기 (%s)" % ro["error"])
	if ro["state"] != null:
		check_eq([ro["state"].abilities, Ability.points_left(ro["state"])], [{}, 13], "합 20 > 받은 13 → 전부 0, 포인트 돌려받음")
	# 숫자 아님·묶음 아님 → 깨짐
	for bad in [{ "nego": "많이" }, ["nego"], "nego"]:
		var db := Save.to_dict(_sample_state(), 1794000000)
		db["abilities"] = bad
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "abilities = %s 를 못 걸러냄" % [bad])


## 형식 5 파일(v5·v6a, lap_cargo 없음)도 그대로 읽힘 → lap_cargo 0, 다음 진행 때 굴림. 숫자가 아니면 깨짐, 음수는 0
func test_format_5_file_reads() -> void:
	_clean()
	var d := Save.to_dict(_sample_state(), 1794000000)
	d["version"] = 5
	for td in d["trucks"]:
		td.erase("lap_cargo")
	_write_text(PATH, JSON.stringify(d))
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "형식 5 읽기 (%s)" % r["error"])
	check_eq(r["old_kept"], "", "형식 5를 옮겨 둠")
	if r["state"] != null:
		var s: GameState = r["state"]
		check_eq(s.truck(0).lap_cargo, 0, "형식 5: 아직 안 굴림")
		check_eq(Trip.lap_cargo(b, s, 0), ceili(Trip.cargo(b, s, 0)), "안 굴렸을 때 Trip.lap_cargo = ceil(평균)")
		s.quest_index = 22
		Trip.advance(s, b, 0, 0.5, RandomNumberGenerator.new())
		check(s.truck(0).lap_cargo >= 1, "진행했는데 안 굴림: %d" % s.truck(0).lap_cargo)
	_clean()
	var bad := Save.to_dict(_sample_state(), 1794000000)
	bad["trucks"][0]["lap_cargo"] = "많이"
	check_eq(Save.from_dict(bad, b)["status"], Save.Status.BROKEN, "lap_cargo 글자를 못 걸러냄")
	var neg := Save.to_dict(_sample_state(), 1794000000)
	neg["trucks"][0]["lap_cargo"] = -3
	var rn := Save.from_dict(neg, b)
	check_eq(rn["state"].truck(0).lap_cargo if rn["state"] != null else -1, 0, "lap_cargo 음수 → 0")


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


## v5 C1 ⑪: 형식 4 파일(v4, 레벨·창고·퀘스트 칸 없음)도 읽힘. 새 칸은 처음 값
func test_format_4_file_reads() -> void:
	_clean()
	var v4 := Save.to_dict(_sample_state(), 1794000000)
	v4["version"] = 4
	for key in Save.PROGRESS_INTS + ["parts_rolled", "milestones_done"]:
		v4.erase(key)
	_write_text(PATH, JSON.stringify(v4))
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "형식 4 읽기 (%s)" % r["error"])
	check(not FileAccess.file_exists(OLD_KEPT), "형식 4인데 save.v2.json이 생김")
	if r["state"] != null:
		var s: GameState = r["state"]
		check_eq(_progress(s), _progress(GameState.new_game()), "형식 4: 새 칸은 처음 값 (레벨 1, 창고·야간팀 Lv1, 퀘스트 0)")
		check_eq([s.money, s.truck(0).star, s.truck(0).part("cargo_box")["grade"]], [123456789, 22, 2], "형식 4: 원래 값")
	_clean()


## v5 C1 ⑪: 형식 5 칸의 이상한 값 — 범위로 자름, 모르는 부품·보너스 단계가 아닌 값은 버림, 숫자가 아니면 깨짐
func test_progress_clamped() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	d["driver_level"] = 99
	d["driver_xp"] = 10_000_000
	d["ability_points"] = -3
	d["reputation"] = 5.7
	d["warehouse_level"] = 9
	d["night_level"] = 0
	d["quest_index"] = 999
	d["parcels_total"] = -1
	d["parts_rolled"] = { "ecu": true, "wing": true, "cargo_box": "yes" }
	d["milestones_done"] = [10, 11, 10, 30, 18.5, "x"]
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "이상한 값이어도 읽힘 (%s)" % r["error"])
	if r["state"] != null:
		var s: GameState = r["state"]
		check_eq([s.driver_level, s.driver_xp, s.ability_points, s.reputation], [50, 0, 0, 5], "레벨 99 → 50 (만렙 경험치 0), 음수 → 0, 소수 → 버림")
		check_eq([s.warehouse_level, s.night_level, s.quest_index, s.parcels_total], [4, 1, Quest.count(b), 0], "창고 9 → 4, 야간팀 0 → 1, 퀘스트 999 → 목록 길이, 음수 → 0")
		check_eq(s.parts_rolled, { "ecu": true }, "모르는 부품·true가 아닌 값 버림")
		check_eq(s.milestones_done, [10, 30], "보너스 단계가 아닌 값·겹친 값 버림")
	var d2 := Save.to_dict(_sample_state(), 1794000000)
	d2["driver_level"] = 3
	d2["driver_xp"] = 1000
	var r2 := Save.from_dict(d2, b)
	if r2["state"] != null:
		check_eq([r2["state"].driver_level, r2["state"].driver_xp], [3, 430], "레벨 3 경험치 1000 → 필요량 431 − 1")
	for c in [["driver_level", "3"], ["quest_index", null], ["parts_rolled", []], ["milestones_done", {}]]:
		var bad := Save.to_dict(_sample_state(), 1794000000)
		bad[c[0]] = c[1]
		check_eq(Save.from_dict(bad, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % [c[0], c[1]])


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
