## 게임 숫자(data/balance.json)를 읽고 검사한다.
## 이 시제품은 "income"과 "engine" 두 묶음만 쓴다.
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

# --- income ---
var base_hourly: float          ## 0강 트럭의 시간당 수익
var star_mult: float            ## 1강마다 시간당 수익에 곱하는 수
var offline_cap_hours: float    ## 꺼둔 동안 최대 몇 시간치까지 쌓이나
var offline_rate: float         ## 꺼둔 동안 수익 비율 (0.5 = 절반)

# --- engine ---
var max_star: int               ## 최대 강수
var success: PackedFloat64Array     ## success[강수] = 그 강수에서 강화 성공 확률
var destroy: PackedFloat64Array     ## destroy[강수] = 그 강수에서 퍼질 확률
var cost_hours: PackedFloat64Array  ## cost_hours[강수] = 강화 1번 비용 (그 강수 시간당 수익의 몇 시간치)
var broken_drop_to: int         ## 퍼지면 내려가는 강수
var spare_hours: float          ## 스페어 엔진 = 퍼지기 직전 강수 시간당 수익의 몇 시간치


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
		b.errors.append("JSON 형식이 깨짐 (%d번째 줄: %s)" % [json.get_error_line(), json.get_error_message()])
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
	var income: Dictionary = d["income"]
	var engine: Dictionary = d["engine"]
	b.base_hourly = float(income["base_hourly"])
	b.star_mult = float(income["star_mult"])
	b.offline_cap_hours = float(income["offline_cap_hours"])
	b.offline_rate = float(income["offline_rate"])
	b.max_star = int(engine["max_star"])
	b.success = PackedFloat64Array(engine["success"])
	b.destroy = PackedFloat64Array(engine["destroy"])
	b.cost_hours = PackedFloat64Array(engine["cost_hours"])
	b.broken_drop_to = int(engine["broken_drop_to"])
	b.spare_hours = float(engine["spare_hours"])
	return b


## 숫자 검사. 틀린 곳마다 한 줄씩 돌려준다. 비어 있으면 정상.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()

	var income = d.get("income")
	var engine = d.get("engine")
	if typeof(income) != TYPE_DICTIONARY:
		errs.append("\"income\" 묶음이 없음")
	if typeof(engine) != TYPE_DICTIONARY:
		errs.append("\"engine\" 묶음이 없음")
	if not errs.is_empty():
		return errs

	# --- income ---
	_check_number(income, "income", "base_hourly", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(income, "income", "star_mult", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(income, "income", "offline_cap_hours", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_check_number(income, "income", "offline_rate", errs, "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0)

	# --- engine ---
	_check_number(engine, "engine", "spare_hours", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	var max_ok := _check_number(engine, "engine", "max_star", errs, "1 이상의 정수여야 함",
			func(v): return v >= 1.0 and v == floorf(v))
	if not max_ok:
		return errs  # 최대 강수를 모르면 아래 길이 검사를 할 수 없음
	var max_star := int(engine["max_star"])

	_check_number(engine, "engine", "broken_drop_to", errs, "0 이상 %d 미만의 정수여야 함" % max_star,
			func(v): return v >= 0.0 and v < max_star and v == floorf(v))

	var success_ok := _check_list(engine, "success", max_star, errs, "0~1 사이여야 함",
			func(v): return v >= 0.0 and v <= 1.0)
	var destroy_ok := _check_list(engine, "destroy", max_star, errs, "0~1 사이여야 함",
			func(v): return v >= 0.0 and v <= 1.0)
	_check_list(engine, "cost_hours", max_star, errs, "0보다 커야 함", func(v): return v > 0.0)

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


## 강수별 목록 검사: 길이가 max_star와 같은지, 칸마다 규칙에 맞는지. 맞으면 true.
static func _check_list(engine: Dictionary, key: String, max_star: int,
		errs: PackedStringArray, rule_text: String, rule: Callable) -> bool:
	if not engine.has(key):
		errs.append("engine.%s 이 없음" % key)
		return false
	var list = engine[key]
	if typeof(list) != TYPE_ARRAY:
		errs.append("engine.%s 가 [ ] 목록이 아님" % key)
		return false
	var ok := true
	if list.size() != max_star:
		errs.append("engine.%s 길이가 %d개 (max_star %d와 같아야 함)" % [key, list.size(), max_star])
		ok = false
	for i in list.size():
		var v = list[i]
		if not _is_number(v):
			errs.append("engine.%s[%d] 가 숫자가 아님: %s" % [key, i, v])
			ok = false
		elif not rule.call(float(v)):
			errs.append("engine.%s[%d] = %s (%s)" % [key, i, v, rule_text])
			ok = false
	return ok


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
