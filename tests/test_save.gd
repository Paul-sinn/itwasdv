## save.gd: 저장 파일 쓰고 읽기, 깨진 파일
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Save = preload("res://scripts/core/save.gd")

const PATH := "user://test_unit_save.json"

var b: Balance = Balance.load_file()


func _sample_state() -> GameState:
	var s := GameState.new()
	s.money = 123456.789
	s.star = 22
	s.broken = true
	s.star_before_break = 24
	s.success_count = 40
	s.fail_count = 77
	s.destroy_count = 3
	s.set_grade(b, "turbo", 3)
	s.set_grade(b, "tire", 1)
	s.set_grade(b, "navigation", 2)
	s.tune_press_count = 812
	s.tune_up_count = 9
	s.jackpot_count = 4321
	return s


func test_write_then_read_same() -> void:
	Save.delete_file(PATH)
	var s := _sample_state()
	var when := 1794000000
	check_eq(Save.write_file(PATH, s, when), OK, "쓰기")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, "읽기 상태 (%s)" % r["error"])
	var t: GameState = r["state"]
	check_eq(r["saved_at"], when, "저장 시각")
	check_near(t.money, s.money, 1e-9, "돈")
	check_eq(t.star, 22, "강수")
	check_eq(t.broken, true, "고장")
	check_eq(t.star_before_break, 24, "퍼지기 직전 강수")
	check_eq([t.success_count, t.fail_count, t.destroy_count], [40, 77, 3], "통계")
	for part in Balance.TUNE_EFFECT_KEYS:
		check_eq(t.grade(part), s.grade(part), "튜닝 %s 등급" % part)
	check_eq([t.tune_press_count, t.tune_up_count, t.jackpot_count], [812, 9, 4321], "튜닝 통계")
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남음")
	Save.delete_file(PATH)


func test_no_file_is_new_game() -> void:
	Save.delete_file(PATH)
	check_eq(Save.read_file(PATH, b)["status"], Save.Status.NONE, "파일 없음 → 새 게임")


func test_broken_json_is_new_game_and_kept() -> void:
	Save.delete_file(PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ \"money\": 10, ")
	f.close()
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.BROKEN, "깨진 JSON")
	check(FileAccess.file_exists(PATH + ".broken"), "깨진 파일을 .broken으로 안 남김")
	check(not FileAccess.file_exists(PATH), "깨진 파일이 그대로 남음")
	DirAccess.remove_absolute(PATH + ".broken")


func test_bad_values_are_broken() -> void:
	var good := Save.to_dict(_sample_state(), 1794000000)
	var cases := {
		"money": -5,
		"star": 31,
		"broken": "yes",
		"star_before_break": 2.5,
		"fail_count": -1,
		"saved_at_utc": "어제 저녁",
	}
	for bad_time in ["2026-13-01T00:00:00", "2026-02-31T00:00:00", "2026-11-10 09:30:00", "2026-11-10T24:00:00"]:
		var d := good.duplicate()
		d["saved_at_utc"] = bad_time
		check_eq(Save.from_dict(d, b)["status"], Save.Status.BROKEN, "saved_at_utc = %s 를 못 걸러냄" % bad_time)
	for key in cases:
		var d := good.duplicate()
		d[key] = cases[key]
		var r := Save.from_dict(d, b)
		check_eq(r["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % [key, cases[key]])
	var missing := good.duplicate()
	missing.erase("star")
	check_eq(Save.from_dict(missing, b)["status"], Save.Status.BROKEN, "star 빠진 걸 못 걸러냄")
	check_eq(Save.from_dict(good, b)["status"], Save.Status.OK, "멀쩡한 묶음이 깨졌다고 나옴")


## 형식 2: version 2, tune에 7부위 전부
func test_format_2_dict() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	check_eq(d["version"], 2, "저장 형식")
	check_eq(d["tune"].keys(), Balance.TUNE_EFFECT_KEYS.keys(), "tune에 7부위 전부")
	check_eq(d["tune"]["turbo"], 3, "터보 등급")
	check_eq(d["tune"]["cargo"], 0, "짐칸 등급 (안 올린 부위도 0으로 적음)")


## 형식 1 파일 (튜닝 전, v0·v1): 튜닝 칸이 없으면 전부 일반·0으로 읽음
func test_format_1_reads_as_no_tuning() -> void:
	var old := {
		"version": 1,
		"saved_at_utc": "2026-11-10T09:30:00",
		"money": 5000.5,
		"star": 17,
		"broken": false,
		"star_before_break": 0,
		"success_count": 20,
		"fail_count": 30,
		"destroy_count": 0,
	}
	var r := Save.from_dict(old, b)
	check_eq(r["status"], Save.Status.OK, "형식 1 읽기 (%s)" % r["error"])
	var t: GameState = r["state"]
	check_eq(t.star, 17, "형식 1 강수")
	check_eq(t.best_grade(), 0, "형식 1: 튜닝 전부 일반")
	for part in Balance.TUNE_EFFECT_KEYS:
		check_eq(t.grade(part), 0, "형식 1: %s 일반" % part)
	check_eq([t.tune_press_count, t.tune_up_count, t.jackpot_count], [0, 0, 0], "형식 1: 튜닝 통계 0")
	check_eq(t.current_hourly(b), Economy.hourly_income(b, 17), "형식 1: 수익이 튜닝 없는 값")


## 모르는 부위 id는 버리고, 등급은 0~3으로 자름
func test_tune_unknown_part_and_clamp() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	d["tune"] = { "turbo": 7, "tire": -2, "cargo": 2.7, "wing": 3, "suspension": 1 }
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	var t: GameState = r["state"]
	check_eq(t.grade("turbo"), 3, "등급 7 → 3")
	check_eq(t.grade("tire"), 0, "등급 -2 → 0")
	check_eq(t.grade("cargo"), 2, "등급 2.7 → 2")
	check_eq(t.grade("suspension"), 1, "서스펜션")
	check_eq(t.grade("engine_oil"), 0, "빠진 부위 → 일반")
	check(not t.tune.has("wing"), "모르는 부위(wing)를 안 버림")


## 튜닝 칸 모양이 틀리면 깨진 저장
func test_tune_bad_values_are_broken() -> void:
	var good := Save.to_dict(_sample_state(), 1794000000)
	var cases := [
		["tune", [1, 2, 3]],
		["tune", "전부 전설"],
		["tune", { "turbo": "전설" }],
		["tune_press_count", -1],
		["tune_up_count", 1.5],
		["jackpot_count", "많이"],
		# 목록([ ])이 들어와도 스크립트 오류로 멈추지 않고 깨진 저장으로
		["money", [5]],
		["broken", [true]],
	]
	for c in cases:
		var d := good.duplicate(true)
		d[c[0]] = c[1]
		check_eq(Save.from_dict(d, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % [c[0], c[1]])


func test_tmp_left_over_is_recovered() -> void:
	# 바꿔 끼우는 순간 꺼져서 .tmp 만 남은 경우
	Save.delete_file(PATH)
	Save.write_file(PATH, _sample_state(), 1794000000)
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, ".tmp 에서 못 살림")
	Save.delete_file(PATH)
