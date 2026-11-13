## 게임 숫자(data/balance.json)를 읽고 검사한다.
## 묶음은 "trip"(한 바퀴), "engine"(강화·스페어), "offline"(꺼둔 동안), "setting"(세팅 돌리기) 네 개.
##
## 쓰는 법:
##   var b := Balance.load_file()
##   if not b.is_ok(): (b.errors에 어디가 틀렸는지 적혀 있음 → 게임을 멈춘다)
extends RefCounted

const DEFAULT_PATH := "res://data/balance.json"

# 실수 계산 찌꺼기(0.1 + 0.2 = 0.30000000000000004 같은 것) 때문에 틀렸다고 하지 않게 두는 여유
const SUM_EPSILON := 1e-9

## 세팅 등급 수 (순정·스트리트·스포츠·레이싱·프로토타입). 이름은 번역 파일에 5개라 고정. 줄 수·확률 목록 길이를 이걸로 검사
const SETTING_GRADES := 5
const OPTION_KINDS := ["common", "own", "junk"]

## 읽기/검사에서 나온 문제들. 비어 있으면 정상.
var errors: PackedStringArray = PackedStringArray()

# --- trip (한 바퀴) ---
var unit_price: int             ## 배송 1건 단가 (원)
var base_cargo: int             ## 한 바퀴에 싣는 개수 N
var road_length: float          ## 한 바퀴 도로 길이 (칸). 출력 1 = 1초에 1칸
var load_seconds: float         ## 물류센터에서 싣는 시간 (초)
var stop_seconds: float         ## 집 앞 정차 시간 (초)
var fuel_rate: float            ## 기름값 = 단가의 몇 % (0.1 = 10%)
var maint_rate: float           ## 정비비 = 단가의 몇 %

# --- engine ---
var max_star: int               ## 최대 강화 단계
var base_power: int             ## +0 엔진 출력
var power_gain: PackedInt64Array    ## power_gain[단계] = 그 단계에서 한 단계 오를 때 느는 출력
var success: PackedFloat64Array     ## success[단계] = 그 단계에서 강화 성공 확률
var destroy: PackedFloat64Array     ## destroy[단계] = 그 단계에서 퍼질 확률 (0보다 크면 스페어가 있어야 누름)
var broken_drop_to: int         ## 퍼지면 내려가는 단계
var cost_base: float            ## 강화 비용 기본값 (+0 비용)
var cost_mult: float            ## 강화 비용: 단계마다 곱하는 수
var spare_price: int            ## 스페어 엔진 가격 (고정 금액, 원)
var spare_drop_chance: float    ## 배송 1건마다 스페어 엔진 +1 확률

# --- offline (꺼둔 동안) ---
var offline_cap_hours: float    ## 최대 몇 시간치까지 쌓이나
var offline_rate: float         ## 켜둔 때의 몇 % (0.5 = 절반)

# --- setting (세팅 돌리기). [등급]은 0 순정 ~ 4 프로토타입 ---
var lines_by_grade: PackedInt64Array    ## [등급] = 줄 수
var up_chance: PackedFloat64Array       ## [등급] = 한 등급 오를 확률 (최고 등급 칸은 없음)
var ceiling: PackedInt64Array           ## [등급] = 천장. 이 횟수째 돌리기는 무조건 등급업 (최고 등급 칸은 없음)
var roll_cost: PackedInt64Array         ## [등급] = 돌리기 1번 비용 (원)
var cost_cut_cap: float                 ## 기름값 + 정비비 절감 합의 상한
var engine_guard_cap: float             ## 엔진 보호 합의 상한
var overboost_seconds: float            ## 오버부스트: 몇 초 동안
var overboost_mult: float               ## 오버부스트: 속도 몇 배
var setting_parts: Dictionary = {}      ## 부품 id → { "unlock_star": int, "options": PackedStringArray } (json 순서)
var setting_options: Dictionary = {}    ## 옵션 id → { "kind": String, "weight": float, "values": PackedFloat64Array (잡옵은 전부 0) }


func is_ok() -> bool:
	return errors.is_empty()


## 파일에서 읽는다. 파일이 없거나 JSON이 깨졌거나 숫자가 틀리면 errors에 이유가 들어간다.
static func load_file(path: String = DEFAULT_PATH) -> RefCounted:
	if not FileAccess.file_exists(path):
		var b = new()
		b.errors.append("%s 파일이 없음" % path)
		return b
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		var b = new()
		b.errors.append("%s 파일을 열 수 없음 (오류 %d)" % [path, FileAccess.get_open_error()])
		return b
	var b = from_text(f.get_as_text())
	for i in b.errors.size():
		b.errors[i] = "%s: %s" % [path, b.errors[i]]
	return b


## JSON 글자에서 읽는다.
static func from_text(text: String) -> RefCounted:
	var json := JSON.new()
	if json.parse(text) != OK:
		var b = new()
		b.errors.append("JSON 형식이 깨짐 (%d번째 줄: %s)" % [json.get_error_line() + 1, json.get_error_message()])
		return b
	if typeof(json.data) != TYPE_DICTIONARY:
		var b = new()
		b.errors.append("맨 바깥이 { } 묶음이 아님")
		return b
	return from_dict(json.data)


## 이미 읽은 묶음(Dictionary)에서 읽는다. 테스트에서 일부러 틀린 숫자를 넣어볼 때도 쓴다.
static func from_dict(d: Dictionary) -> RefCounted:
	var b = new()
	b.errors = validate(d)
	if not b.errors.is_empty():
		return b
	var trip: Dictionary = d["trip"]
	var engine: Dictionary = d["engine"]
	var offline: Dictionary = d["offline"]
	b.unit_price = int(trip["unit_price"])
	b.base_cargo = int(trip["base_cargo"])
	b.road_length = float(trip["road_length"])
	b.load_seconds = float(trip["load_seconds"])
	b.stop_seconds = float(trip["stop_seconds"])
	b.fuel_rate = float(trip["fuel_rate"])
	b.maint_rate = float(trip["maint_rate"])
	b.max_star = int(engine["max_star"])
	b.base_power = int(engine["base_power"])
	b.power_gain = PackedInt64Array(engine["power_gain"])
	b.success = PackedFloat64Array(engine["success"])
	b.destroy = PackedFloat64Array(engine["destroy"])
	b.broken_drop_to = int(engine["broken_drop_to"])
	b.cost_base = float(engine["cost_base"])
	b.cost_mult = float(engine["cost_mult"])
	b.spare_price = int(engine["spare_price"])
	b.spare_drop_chance = float(engine["spare_drop_chance"])
	b.offline_cap_hours = float(offline["cap_hours"])
	b.offline_rate = float(offline["rate"])
	var setting: Dictionary = d["setting"]
	b.lines_by_grade = PackedInt64Array(setting["lines_by_grade"])
	b.up_chance = PackedFloat64Array(setting["up_chance"])
	b.ceiling = PackedInt64Array(setting["ceiling"])
	b.roll_cost = PackedInt64Array(setting["roll_cost"])
	b.cost_cut_cap = float(setting["cost_cut_cap"])
	b.engine_guard_cap = float(setting["engine_guard_cap"])
	b.overboost_seconds = float(setting["overboost_seconds"])
	b.overboost_mult = float(setting["overboost_mult"])
	for id in setting["options"]:
		var o: Dictionary = setting["options"][id]
		var values := PackedFloat64Array()
		values.resize(SETTING_GRADES)   # 잡옵은 0
		if o["kind"] != "junk":
			values = PackedFloat64Array(o["values"])
		b.setting_options[id] = { "kind": o["kind"], "weight": float(o["weight"]), "values": values }
	for id in setting["parts"]:
		var pt: Dictionary = setting["parts"][id]
		b.setting_parts[id] = { "unlock_star": int(pt["unlock_star"]), "options": PackedStringArray(pt["options"]) }
	return b


## 숫자 검사. 틀린 곳마다 한 줄씩 돌려준다. 비어 있으면 정상.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()

	var trip = d.get("trip")
	var engine = d.get("engine")
	var offline = d.get("offline")
	var setting = d.get("setting")
	for pair in [["trip", trip], ["engine", engine], ["offline", offline], ["setting", setting]]:
		if typeof(pair[1]) != TYPE_DICTIONARY:
			errs.append("\"%s\" 묶음이 없음" % pair[0])
	if not errs.is_empty():
		return errs

	var whole_pos := func(v): return v >= 1.0 and v == floorf(v)
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var rate := func(v): return v >= 0.0 and v <= 1.0

	# --- trip ---
	var price_ok := _check_number(trip, "trip", "unit_price", errs, "1 이상의 정수여야 함", whole_pos)
	_check_number(trip, "trip", "base_cargo", errs, "1 이상의 정수여야 함", whole_pos)
	_check_number(trip, "trip", "road_length", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(trip, "trip", "load_seconds", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_check_number(trip, "trip", "stop_seconds", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	var fuel_ok := _check_number(trip, "trip", "fuel_rate", errs, "0~1 사이여야 함", rate)
	var maint_ok := _check_number(trip, "trip", "maint_rate", errs, "0~1 사이여야 함", rate)
	if price_ok and fuel_ok and maint_ok:
		# 반올림 때문에 비율 합이 1 이하여도 마이너스가 될 수 있어서 계산식 그대로 본다 (Trip.parcel_pay)
		var u := float(trip["unit_price"])
		var pay := int(u) - roundi(u * float(trip["fuel_rate"])) - roundi(u * float(trip["maint_rate"]))
		if pay < 0:
			errs.append("trip: 배송 1건 돈 = %d (기름값·정비비가 단가보다 큼. 0 이상이어야 함)" % pay)

	# --- offline ---
	_check_number(offline, "offline", "cap_hours", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_check_number(offline, "offline", "rate", errs, "0~1 사이여야 함", rate)

	# --- engine ---
	_check_number(engine, "engine", "base_power", errs, "1 이상의 정수여야 함", whole_pos)
	_check_number(engine, "engine", "cost_base", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(engine, "engine", "cost_mult", errs, "1보다 커야 함", func(v): return v > 1.0)
	_check_number(engine, "engine", "spare_price", errs, "0 이상의 정수여야 함", whole)
	_check_number(engine, "engine", "spare_drop_chance", errs, "0~1 사이여야 함", rate)
	var max_ok := _check_number(engine, "engine", "max_star", errs, "1 이상의 정수여야 함", whole_pos)
	if not max_ok:
		return errs  # 최대 단계를 모르면 아래 길이 검사를 할 수 없음
	var max_star := int(engine["max_star"])

	_check_number(engine, "engine", "broken_drop_to", errs, "0 이상 %d 미만의 정수여야 함" % max_star,
			func(v): return v >= 0.0 and v < max_star and v == floorf(v))

	var by_star := "max_star %d와 같아야 함" % max_star
	# 출력은 오르기만 함 (음수 없음 → 단계가 오를수록 출력이 줄지 않음)
	_check_list(engine, "engine", "power_gain", max_star, by_star, errs, "0 이상의 정수여야 함", whole)
	var success_ok := _check_list(engine, "engine", "success", max_star, by_star, errs, "0~1 사이여야 함", rate)
	var destroy_ok := _check_list(engine, "engine", "destroy", max_star, by_star, errs, "0~1 사이여야 함", rate)

	if success_ok and destroy_ok:
		for s in max_star:
			var sum: float = engine["success"][s] + engine["destroy"][s]
			if sum > 1.0 + SUM_EPSILON:
				errs.append("engine.success[%d] + engine.destroy[%d] = %s (1 이하여야 함)" % [s, s, sum])

	_validate_setting(setting, max_star, errs)
	return errs


## "setting" 묶음 검사 (세팅 돌리기 v4)
static func _validate_setting(setting: Dictionary, max_star: int, errs: PackedStringArray) -> void:
	var g := SETTING_GRADES
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var rate := func(v): return v >= 0.0 and v <= 1.0
	var per_grade := "등급 %d개와 같아야 함" % g
	var per_step := "등급 %d개 − 1 = %d개여야 함. 최고 등급에서는 안 오름" % [g, g - 1]
	if _check_list(setting, "setting", "lines_by_grade", g, per_grade, errs, "1 이상의 정수여야 함",
			func(v): return v >= 1.0 and v == floorf(v)):
		_check_not_decreasing(setting["lines_by_grade"], "setting.lines_by_grade", errs)
	_check_list(setting, "setting", "up_chance", g - 1, per_step, errs, "0~1 사이여야 함", rate)
	_check_list(setting, "setting", "ceiling", g - 1, per_step, errs, "1 이상의 정수여야 함",
			func(v): return v >= 1.0 and v == floorf(v))
	if _check_list(setting, "setting", "roll_cost", g, per_grade, errs, "0 이상의 정수여야 함", whole):
		_check_not_decreasing(setting["roll_cost"], "setting.roll_cost", errs)
	_check_number(setting, "setting", "cost_cut_cap", errs, "0~1 사이여야 함", rate)
	_check_number(setting, "setting", "engine_guard_cap", errs, "0~1 사이여야 함", rate)
	_check_number(setting, "setting", "overboost_seconds", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_check_number(setting, "setting", "overboost_mult", errs, "1 이상이어야 함", func(v): return v >= 1.0)

	var options = setting.get("options")
	if typeof(options) != TYPE_DICTIONARY or options.is_empty():
		errs.append("setting.options 가 없거나 { } 묶음이 아님")
		return
	var options_ok := true
	for id in options:
		var o = options[id]
		var where := "setting.options.%s" % id
		if typeof(o) != TYPE_DICTIONARY:
			errs.append("%s 가 { } 묶음이 아님" % where)
			options_ok = false
			continue
		if not OPTION_KINDS.has(o.get("kind")):
			errs.append("%s.kind = %s (%s 중 하나여야 함)" % [where, o.get("kind"), "/".join(OPTION_KINDS)])
			options_ok = false
			continue
		if not _check_number(o, where, "weight", errs, "0 이상이어야 함", func(v): return v >= 0.0):
			options_ok = false
		if o["kind"] != "junk":
			if _check_list(o, where, "values", g, per_grade, errs, "0 이상이어야 함", func(v): return v >= 0.0):
				_check_not_decreasing(o["values"], where + ".values", errs)
			else:
				options_ok = false

	var parts = setting.get("parts")
	if typeof(parts) != TYPE_DICTIONARY or parts.is_empty():
		errs.append("setting.parts 가 없거나 { } 묶음이 아님")
		return
	for id in parts:
		var pt = parts[id]
		var where := "setting.parts.%s" % id
		if typeof(pt) != TYPE_DICTIONARY:
			errs.append("%s 가 { } 묶음이 아님" % where)
			continue
		_check_number(pt, where, "unlock_star", errs, "0~%d 정수여야 함" % max_star,
				func(v): return v >= 0.0 and v <= max_star and v == floorf(v))
		var list = pt.get("options")
		if typeof(list) != TYPE_ARRAY or list.is_empty():
			errs.append("%s.options 가 없거나 빈 목록" % where)
			continue
		var known := true
		for op in list:
			if typeof(op) != TYPE_STRING or not options.has(op):
				errs.append("%s.options 에 모르는 옵션: %s" % [where, op])
				known = false
		if not (known and options_ok):
			continue
		# 등급마다 뽑을 옵션이 하나는 있어야 함 (수치 0인 옵션은 그 등급에서 안 뽑힘, 잡옵은 늘 포함)
		for grade in g:
			var weight := 0.0
			for op in list:
				var o: Dictionary = options[op]
				if o["kind"] == "junk" or float(o["values"][grade]) != 0.0:
					weight += float(o["weight"])
			if weight <= 0.0:
				errs.append("%s: 등급 %d에서 뽑을 수 있는 옵션이 없음 (가중치 합 0)" % [where, grade])


## 등급이 오를수록 줄면 안 되는 목록
static func _check_not_decreasing(list: Array, where: String, errs: PackedStringArray) -> void:
	for i in range(1, list.size()):
		if float(list[i]) < float(list[i - 1]):
			errs.append("%s[%d] = %s (앞 등급 %s보다 작음. 등급이 오를수록 줄면 안 됨)" % [where, i, list[i], list[i - 1]])


## 숫자 하나 검사. 맞으면 true.
static func _check_number(section: Dictionary, section_name: String, key: String,
		errs: PackedStringArray, rule_text: String, rule: Callable) -> bool:
	if not section.has(key):
		errs.append("%s.%s 이 없음" % [section_name, key])
		return false
	var v = section[key]
	if not _is_number(v):
		errs.append("%s.%s 가 숫자가 아님: %s" % [section_name, key, v])
		return false
	if not rule.call(float(v)):
		errs.append("%s.%s = %s (%s)" % [section_name, key, v, rule_text])
		return false
	return true


## 숫자 목록 검사: 길이가 length와 같은지(length_text = 왜 그 길이인지), 칸마다 규칙에 맞는지. 맞으면 true.
static func _check_list(section: Dictionary, section_name: String, key: String, length: int, length_text: String,
		errs: PackedStringArray, rule_text: String, rule: Callable) -> bool:
	if not section.has(key):
		errs.append("%s.%s 이 없음" % [section_name, key])
		return false
	var list = section[key]
	if typeof(list) != TYPE_ARRAY:
		errs.append("%s.%s 가 [ ] 목록이 아님" % [section_name, key])
		return false
	var ok := true
	if list.size() != length:
		errs.append("%s.%s 길이가 %d개 (%s)" % [section_name, key, list.size(), length_text])
		ok = false
	for i in list.size():
		var v = list[i]
		if not _is_number(v):
			errs.append("%s.%s[%d] 가 숫자가 아님: %s" % [section_name, key, i, v])
			ok = false
		elif not rule.call(float(v)):
			errs.append("%s.%s[%d] = %s (%s)" % [section_name, key, i, v, rule_text])
			ok = false
	return ok


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
