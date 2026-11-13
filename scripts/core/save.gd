## 저장 파일 읽고 쓰기 (기본 user://save.json). 화면 없이 돌아가는 코드.
##
## 파일 모양 (JSON, 손으로 고쳐도 됨):
##   saved_at_utc  저장한 시각. 세계 표준시(UTC) "YYYY-MM-DDTHH:MM:SS"
##                 → 꺼둔 동안 수익 확인할 때 이걸 3시간 전 / 20시간 전 / 미래로 고친다
##   money, spares, spare_drop_carry
##   trucks [ { star, lap_clock, lap_delivered, success_count, fail_count, destroy_count } ]
## 모르는 키는 버리고 범위 밖 값은 자른다. 음수 돈·스페어, 빠진 칸, 틀린 모양은 깨진 저장.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 3   ## 1: v0·v1 / 2: 튜닝(v2) / 3: 한 바퀴 경제·트럭 여러 대(v3)

enum Status { OK, NONE, BROKEN }   ## 읽음 / 저장 파일 없음(새 게임) / 깨짐(새 게임)

const TRUCK_COUNTS := ["success_count", "fail_count", "destroy_count"]
const MAX_WHOLE := 1 << 53   # JSON 숫자가 정확한 정수로 왕복하는 한계


## 상태 → 저장할 묶음
static func to_dict(s: GameState, saved_at_unix: int) -> Dictionary:
	var trucks := []
	for t: TruckState in s.trucks:
		trucks.append({
			"star": t.star,
			"lap_clock": t.lap_clock,
			"lap_delivered": t.lap_delivered,
			"success_count": t.success_count,
			"fail_count": t.fail_count,
			"destroy_count": t.destroy_count,
		})
	return {
		"version": FORMAT_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_unix_time(saved_at_unix),
		"money": s.money,
		"spares": s.spares,
		"spare_drop_carry": s.spare_drop_carry,
		"trucks": trucks,
	}


## 저장 묶음 → 상태. 결과: { status, state, saved_at, error }
static func from_dict(d, b: Balance) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return _broken("맨 바깥이 { } 묶음이 아님")

	var when = d.get("saved_at_utc")
	if typeof(when) != TYPE_STRING:
		return _broken("saved_at_utc 가 없음")
	var saved_at := _parse_utc(when)
	if saved_at < 0:
		return _broken("saved_at_utc 모양이 틀림: %s (예: 2026-11-10T09:30:00)" % when)

	var s := GameState.new()
	for key in ["money", "spares"]:
		var n = _whole(d.get(key), 0, MAX_WHOLE)
		if n == null:
			return _broken("%s 가 0 이상 정수가 아님: %s" % [key, d.get(key)])
		s.set(key, n)
	var carry = d.get("spare_drop_carry")
	if not _is_finite_number(carry):
		return _broken("spare_drop_carry 가 숫자가 아님: %s" % [carry])
	s.spare_drop_carry = clampf(float(carry), 0.0, 0.999999)

	var trucks = d.get("trucks")
	if typeof(trucks) != TYPE_ARRAY or trucks.is_empty():
		return _broken("trucks 가 트럭 1대 이상의 [ ] 목록이 아님: %s" % [trucks])
	for k in trucks.size():
		var td = trucks[k]
		if typeof(td) != TYPE_DICTIONARY:
			return _broken("trucks[%d] 가 { } 묶음이 아님" % k)
		var t := TruckState.new()
		for key in ["star", "lap_clock", "lap_delivered"] + TRUCK_COUNTS:
			if not _is_finite_number(td.get(key)):
				return _broken("trucks[%d].%s 가 숫자가 아님: %s" % [k, key, td.get(key)])
		t.star = clampi(floori(td["star"]), 0, b.max_star)
		t.lap_clock = maxf(0.0, td["lap_clock"])
		t.lap_delivered = clampi(floori(td["lap_delivered"]), 0, 1 << 30)
		for key in TRUCK_COUNTS:
			t.set(key, clampi(floori(td[key]), 0, MAX_WHOLE))
		s.trucks.append(t)

	return { "status": Status.OK, "state": s, "saved_at": saved_at, "error": "" }


## 파일에 쓴다. 다 쓴 다음에 바꿔 끼워서, 쓰다가 꺼져도 원래 파일이 깨지지 않게.
static func write_file(path: String, s: GameState, saved_at_unix: int) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(s, saved_at_unix), "  ", false, true))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## 파일에서 읽는다. 결과: { status, state, saved_at, error }
## 깨진 파일은 path + ".broken" 으로 옮겨 둔다 (원인 볼 수 있게).
static func read_file(path: String, b: Balance) -> Dictionary:
	if not FileAccess.file_exists(path):
		# 바꿔 끼우는 순간 꺼졌으면 .tmp 만 남아 있을 수 있음
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.rename_absolute(path + ".tmp", path)
		else:
			return { "status": Status.NONE, "state": null, "saved_at": 0, "error": "" }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _keep_broken(path, _broken("파일을 열 수 없음 (오류 %d)" % FileAccess.get_open_error()))
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _keep_broken(path, _broken("JSON 형식이 깨짐 (%d번째 줄: %s)" % [json.get_error_line() + 1, json.get_error_message()]))
	var result := from_dict(json.data, b)
	if result["status"] == Status.BROKEN:
		return _keep_broken(path, result)
	return result


static func delete_file(path: String) -> void:
	for p in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _keep_broken(path: String, result: Dictionary) -> Dictionary:
	var keep := path + ".broken"
	if FileAccess.file_exists(keep):
		DirAccess.remove_absolute(keep)
	DirAccess.rename_absolute(path, keep)
	return result


static func _broken(why: String) -> Dictionary:
	return { "status": Status.BROKEN, "state": null, "saved_at": 0, "error": why }


## "YYYY-MM-DDTHH:MM:SS" → 유닉스 시각(초). 틀린 모양이면 -1.
## (Godot 함수에 틀린 글자를 바로 넣으면 빨간 오류를 찍어서, 모양부터 본다)
static func _parse_utc(text: String) -> int:
	var re := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})$")
	var m := re.search(text)
	if m == null:
		return -1
	var year := int(m.get_string(1))
	var month := int(m.get_string(2))
	var day := int(m.get_string(3))
	if month < 1 or month > 12 or int(m.get_string(4)) > 23 \
			or int(m.get_string(5)) > 59 or int(m.get_string(6)) > 59:
		return -1
	var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
	var days_in_month := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if day < 1 or day > days_in_month[month - 1]:
		return -1
	return Time.get_unix_time_from_datetime_string(text)


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


static func _is_finite_number(v) -> bool:
	return _is_number(v) and is_finite(float(v))


## lo~hi 사이 정수면 int, 아니면 null
static func _whole(v, lo: int, hi: int):
	if not _is_number(v):
		return null
	var x := float(v)
	if not is_finite(x) or x != floorf(x) or x < lo or x > hi:
		return null
	return int(x)
