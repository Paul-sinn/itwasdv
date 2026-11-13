## 게임 숫자(data/balance.json)를 읽고 검사한다.
## 묶음은 "trip"(한 바퀴), "engine"(강화·스페어), "offline"(꺼둔 동안) 세 개.
##
## 쓰는 법:
##   var b := Balance.load_file()
##   if not b.is_ok(): (b.errors에 어디가 틀렸는지 적혀 있음 → 게임을 멈춘다)
extends RefCounted

const DEFAULT_PATH := "res://data/balance.json"

# 실수 계산 찌꺼기(0.1 + 0.2 = 0.30000000000000004 같은 것) 때문에 틀렸다고 하지 않게 두는 여유
const SUM_EPSILON := 1e-9

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
	return b


## 숫자 검사. 틀린 곳마다 한 줄씩 돌려준다. 비어 있으면 정상.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()

	var trip = d.get("trip")
	var engine = d.get("engine")
	var offline = d.get("offline")
	for pair in [["trip", trip], ["engine", engine], ["offline", offline]]:
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
	return errs


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
