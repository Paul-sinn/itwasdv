## save.gd: 저장 파일 쓰고 읽기, 깨진 파일
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
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


func test_tmp_left_over_is_recovered() -> void:
	# 바꿔 끼우는 순간 꺼져서 .tmp 만 남은 경우
	Save.delete_file(PATH)
	Save.write_file(PATH, _sample_state(), 1794000000)
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, ".tmp 에서 못 살림")
	Save.delete_file(PATH)
