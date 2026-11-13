## 저장 파일 읽고 쓰기 (기본 user://save.json). 화면 없이 돌아가는 코드.
##
## 파일 모양 (JSON, 손으로 고쳐도 됨):
##   saved_at_utc  저장한 시각. 세계 표준시(UTC) "YYYY-MM-DDTHH:MM:SS"
##                 → 꺼둔 동안 수익 확인할 때 이걸 3시간 전 / 20시간 전 / 미래로 고친다
##   money         글자("123456789"). JSON 숫자는 2^53(약 9007조)을 넘으면 끝자리가 틀려져서 글자로 쓴다.
##                 읽을 때는 숫자(손으로 고친 파일)도 받는다
##   spares, spare_drop_carry
##   trucks [ { star, lap_clock, lap_delivered, boost_lap, success_count, fail_count, destroy_count,
##              settings { 부품 id: { grade, lines, counters, pending: null 또는 { grade, lines } } } } ]
## 모르는 키는 버리고 범위 밖 값은 자른다. 음수 돈·스페어, 빠진 칸, 틀린 모양은 깨진 저장.
## 세팅: 모르는 부품·그 부품에 없는 옵션 id는 버리고, 등급·카운터는 범위로 자르고, 줄은 그 등급 줄 수까지 (앞에서부터).
## 형식 3 파일(v3)은 그대로 읽는다 (세팅 없음, 오버부스트 안 걸린 바퀴).
##
## 백업: 쓸 때마다 지금 파일을 path.bak1(가장 최근) → bak2 → bak3 으로 돌린다.
## 본 파일이 깨졌으면 path.broken 으로 옮기고 bak1 → bak2 → bak3 중 읽히는 첫 파일로 살린다.
## 형식 1·2 파일(v2까지)은 변환하지 않고 같은 폴더 save.v2.json 으로 옮겨 남긴 뒤 새 게임.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 4   ## 1: v0·v1 / 2: 튜닝(v2) / 3: 한 바퀴 경제·트럭 여러 대(v3) / 4: 세팅 돌리기(v4)
const OLDEST_READABLE := 3  ## 이보다 옛 형식은 변환하지 않고 옮겨 둔다

enum Status { OK, NONE, BROKEN }   ## 읽음 / 저장 파일 없음(새 게임) / 깨짐(새 게임)

const BACKUPS := 3
const OLD_FILE_NAME := "save.v2.json"   ## 형식 1·2 파일을 옮겨 두는 이름 (본 파일과 같은 폴더)

const TRUCK_COUNTS := ["success_count", "fail_count", "destroy_count"]
const MAX_WHOLE := 1 << 53   # JSON 숫자가 정확한 정수로 왕복하는 한계
const MAX_MONEY := 999_999_999_999_999_999   ## 돈 글자 18자리까지. 넘으면 이 값으로 자름 (to_int가 넘치면 음수로 돌아감)


## 상태 → 저장할 묶음
static func to_dict(s: GameState, saved_at_unix: int) -> Dictionary:
	var trucks := []
	for t: TruckState in s.trucks:
		trucks.append({
			"star": t.star,
			"lap_clock": t.lap_clock,
			"lap_delivered": t.lap_delivered,
			"boost_lap": t.boost_lap,
			"success_count": t.success_count,
			"fail_count": t.fail_count,
			"destroy_count": t.destroy_count,
			"settings": t.settings.duplicate(true),
		})
	return {
		"version": FORMAT_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_unix_time(saved_at_unix),
		"money": str(s.money),
		"spares": s.spares,
		"spare_drop_carry": s.spare_drop_carry,
		"trucks": trucks,
	}


## 저장 묶음 → 상태. 결과: { status, state, saved_at, error, recovered, old_kept } (read_file과 같은 모양)
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
	var money = _money(d.get("money"))
	if money == null:
		return _broken("money 가 0 이상 정수(글자)가 아님: %s" % [d.get("money")])
	s.money = money
	var spares = _whole(d.get("spares"), 0, MAX_WHOLE)
	if spares == null:
		return _broken("spares 가 0 이상 정수가 아님: %s" % [d.get("spares")])
	s.spares = spares
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
		var boost = td.get("boost_lap", false)   # 형식 3에는 없음
		if typeof(boost) != TYPE_BOOL:
			return _broken("trucks[%d].boost_lap 이 true/false가 아님: %s" % [k, boost])
		t.boost_lap = boost
		var settings = _settings_from(td.get("settings", {}), b)   # 형식 3에는 없음
		if settings == null:
			return _broken("trucks[%d].settings 모양이 틀림" % k)
		t.settings = settings
		s.trucks.append(t)

	return _result(Status.OK, s, saved_at)


## 파일에 쓴다. 임시 파일에 다 쓴 다음, 지금 파일을 백업으로 돌리고 바꿔 끼운다 (쓰다가 꺼져도 안 깨지게).
static func write_file(path: String, s: GameState, saved_at_unix: int) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var written := f.store_string(JSON.stringify(to_dict(s, saved_at_unix), "  ", false, true))
	f.close()
	if not written:
		DirAccess.remove_absolute(tmp)   # 덜 쓴 파일로 본 파일·백업을 밀어내지 않음
		return ERR_FILE_CANT_WRITE
	# 본 파일이 없으면(깨져서 .broken으로 옮긴 뒤 등) 백업을 그대로 둔다
	if FileAccess.file_exists(path):
		for k in range(BACKUPS, 1, -1):
			if FileAccess.file_exists(_bak(path, k - 1)):
				_move(_bak(path, k - 1), _bak(path, k))
		_move(path, _bak(path, 1))
	return DirAccess.rename_absolute(tmp, path)


## 파일에서 읽는다. 결과: { status, state, saved_at, error, recovered, old_kept }
##   recovered = 본 파일이 깨져서 백업에서 살림 (status OK, error에 본 파일이 깨진 이유)
##   old_kept  = 옛 형식 파일을 옮겨 둔 경로 (status NONE). 없으면 ""
## 백업까지 전부 안 읽히면 BROKEN (새 게임).
static func read_file(path: String, b: Balance) -> Dictionary:
	# 바꿔 끼우는 순간 꺼졌으면 .tmp 만 남아 있을 수 있음
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".tmp"):
		DirAccess.rename_absolute(path + ".tmp", path)
	if not FileAccess.file_exists(path):
		return _result(Status.NONE)
	var main := _read_one(path, b)
	if main["status"] == Status.OK:
		return main
	if main.has("old"):
		var keep := path.get_base_dir().path_join(OLD_FILE_NAME)
		_move(path, keep)
		var r := _result(Status.NONE)
		r["old_kept"] = keep
		return r
	_move(path, path + ".broken")
	for k in range(1, BACKUPS + 1):
		var r := _read_one(_bak(path, k), b)
		if r["status"] == Status.OK:
			r["recovered"] = true
			r["error"] = main["error"]
			return r
	return main


## 본 파일·임시 파일·백업을 지운다 (치트 F3). .broken과 옛 형식 파일은 남긴다.
static func delete_file(path: String) -> void:
	var paths := [path, path + ".tmp"]
	for k in range(1, BACKUPS + 1):
		paths.append(_bak(path, k))
	for p in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## 파일 하나를 읽어 상태로. 옛 형식(version 1·2)이면 status NONE + "old" 칸
static func _read_one(p: String, b: Balance) -> Dictionary:
	if not FileAccess.file_exists(p):
		return _broken("파일이 없음: %s" % p)
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return _broken("파일을 열 수 없음 (오류 %d)" % FileAccess.get_open_error())
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _broken("JSON 형식이 깨짐 (%d번째 줄: %s)" % [json.get_error_line() + 1, json.get_error_message()])
	var d = json.data
	if typeof(d) == TYPE_DICTIONARY and _is_number(d.get("version")) and float(d["version"]) < OLDEST_READABLE:
		var r := _result(Status.NONE)
		r["old"] = true
		return r
	return from_dict(d, b)


static func _bak(path: String, k: int) -> String:
	return "%s.bak%d" % [path, k]


## from에서 to로 옮긴다 (to에 파일이 있으면 지우고)
static func _move(from: String, to: String) -> void:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	DirAccess.rename_absolute(from, to)


static func _result(status: Status, state: GameState = null, saved_at: int = 0, error: String = "") -> Dictionary:
	return { "status": status, "state": state, "saved_at": saved_at, "error": error, "recovered": false, "old_kept": "" }


static func _broken(why: String) -> Dictionary:
	return _result(Status.BROKEN, null, 0, why)


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


## 저장된 세팅 → 깨끗한 세팅 (TruckState.settings 모양). 모양이 틀리면 null
static func _settings_from(v, b: Balance):
	if typeof(v) != TYPE_DICTIONARY:
		return null
	var out := {}
	for part in v:
		if not b.setting_parts.has(part):
			continue   # 모르는 부품은 버림
		var pd = v[part]
		var now = _grade_lines_from(pd, b, part)
		if now == null:
			return null
		var saved = pd.get("counters", [])
		if typeof(saved) != TYPE_ARRAY:
			return null
		var counters := []
		for g in Balance.SETTING_GRADES:
			var x = saved[g] if g < saved.size() else 0
			if not _is_finite_number(x):
				return null
			counters.append(clampi(floori(x), 0, maxi(0, Setting.ceiling(b, g) - 1)))
		var pending = pd.get("pending")
		if pending != null:
			pending = _grade_lines_from(pending, b, part)
			if pending == null:
				return null
		out[part] = { "grade": now["grade"], "lines": now["lines"], "counters": counters, "pending": pending }
	return out


## { grade, lines } → 등급은 0~최고로 자르고, 그 부품에 없는 옵션은 버리고, 줄은 그 등급 줄 수까지 (앞에서부터). 틀리면 null
static func _grade_lines_from(v, b: Balance, part: String):
	if typeof(v) != TYPE_DICTIONARY or not _is_finite_number(v.get("grade")) or typeof(v.get("lines")) != TYPE_ARRAY:
		return null
	var grade := clampi(floori(v["grade"]), 0, Setting.max_grade(b))
	var allowed: PackedStringArray = b.setting_parts[part]["options"]
	var lines := []
	for op in v["lines"]:
		if typeof(op) == TYPE_STRING and allowed.has(op):
			lines.append(op)
	return { "grade": grade, "lines": lines.slice(0, Setting.line_count(b, grade)) }


## 돈: 글자("123", 쓸 때 모양)나 숫자(손으로 고친 파일). 0 이상 정수가 아니면 null. MAX_MONEY 넘으면 자름
static func _money(v):
	if typeof(v) == TYPE_STRING:
		var text: String = v
		if not text.is_valid_int() or text.begins_with("-") or text.begins_with("+"):
			return null
		var digits := text.lstrip("0")
		return MAX_MONEY if digits.length() > 18 else digits.to_int()
	if not _is_finite_number(v) or float(v) < 0.0 or float(v) != floorf(float(v)):
		return null
	return MAX_MONEY if float(v) >= float(MAX_MONEY) else int(v)


## lo~hi 사이 정수면 int, 아니면 null
static func _whole(v, lo: int, hi: int):
	if not _is_number(v):
		return null
	var x := float(v)
	if not is_finite(x) or x != floorf(x) or x < lo or x > hi:
		return null
	return int(x)
