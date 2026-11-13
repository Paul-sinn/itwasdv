## save.gd: 저장 파일 쓰고 읽기, 깨진 파일 (형식 3 모양. 백업·옛 형식 옮기기는 C2)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Save = preload("res://scripts/core/save.gd")

const PATH := "user://test_unit_save.json"

var b: Balance = Balance.load_file()


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
	var t2 := TruckState.new()
	t2.star = 5
	t2.lap_clock = 0.1
	s.trucks.append(t2)
	return s


func test_write_then_read_same() -> void:
	Save.delete_file(PATH)
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
	check(not FileAccess.file_exists(PATH + ".tmp"), "임시 파일이 남음")
	Save.delete_file(PATH)


func test_format_3_dict() -> void:
	var d := Save.to_dict(_sample_state(), 1794000000)
	check_eq(d["version"], 3, "저장 형식")
	var keys := d.keys()
	keys.sort()
	check_eq(keys, ["money", "saved_at_utc", "spare_drop_carry", "spares", "trucks", "version"], "저장 칸")
	var tk: Array = d["trucks"][0].keys()
	tk.sort()
	check_eq(tk, ["destroy_count", "fail_count", "lap_clock", "lap_delivered", "star", "success_count"], "트럭 칸")


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
	# 바꿔 끼우는 순간 꺼져서 .tmp 만 남은 경우
	Save.delete_file(PATH)
	Save.write_file(PATH, _sample_state(), 1794000000)
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	var r := Save.read_file(PATH, b)
	check_eq(r["status"], Save.Status.OK, ".tmp 에서 못 살림")
	Save.delete_file(PATH)
