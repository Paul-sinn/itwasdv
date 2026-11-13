## 게임 숫자(data/balance.json)를 읽고 검사한다.
## 이 시제품은 "income", "engine", "tune" 세 묶음만 쓴다 (나머지 묶음은 시뮬 전용이라 안 읽음).
##
## 쓰는 법:
##   var b := Balance.load_file()
##   if not b.is_ok(): (b.errors에 어디가 틀렸는지 적혀 있음 → 게임을 멈춘다)
extends RefCounted

const DEFAULT_PATH := "res://data/balance.json"

# 실수 계산 찌꺼기(0.1 + 0.2 = 0.30000000000000004 같은 것) 때문에 틀렸다고 하지 않게 두는 여유
const SUM_EPSILON := 1e-9

## 튜닝 등급 수 (일반 / 레어 / 에픽 / 전설). 화면의 등급 색이 4개라 4개로 정해 둠
const TUNE_GRADE_COUNT := 4
## 튜닝 부위 id → balance.json "tune" 묶음의 효과 목록 이름. 순서 = 화면 순서 (tune.gd PARTS와 같음)
const TUNE_EFFECT_KEYS := {
	"turbo": "turbo_income_bonus",          # 시간당 수익 +비율
	"tire": "tire_jackpot_chance",          # 대박 배송 확률
	"cargo": "cargo_jackpot_mult",          # 대박 배송 배수
	"suspension": "suspension_destroy_cut", # 퍼짐 확률을 이 비율만큼 줄임
	"fuel_tank": "fuel_extra_hours",        # 꺼둔 동안 최대 시간 +
	"navigation": "navi_extra_rate",        # 꺼둔 동안 수익 비율 +
	"engine_oil": "oil_cost_cut",           # 강화 비용 -비율
}

## 읽기/검사에서 나온 문제들. 비어 있으면 정상.
var errors: PackedStringArray = PackedStringArray()

# --- income ---
var base_hourly: float          ## 0강 트럭의 시간당 수익
var star_mult: float            ## 1강마다 시간당 수익에 곱하는 수 (high_from_star 전까지)
var star_mult_high: float       ## high_from_star강부터 1강마다 곱하는 수 (수익이 확 오르는 구간)
var high_from_star: int         ## 이 강수가 되는 순간부터 star_mult_high를 곱함 (예: 20 → 19→20강부터)
var offline_cap_hours: float    ## 꺼둔 동안 최대 몇 시간치까지 쌓이나 (튜닝 빼고)
var offline_rate: float         ## 꺼둔 동안 수익 비율 (0.5 = 절반. 튜닝 빼고)

# --- engine ---
var max_star: int               ## 최대 강수
var success: PackedFloat64Array     ## success[강수] = 그 강수에서 강화 성공 확률
var destroy: PackedFloat64Array     ## destroy[강수] = 그 강수에서 퍼질 확률 (튜닝 빼고)
var cost_hours: PackedFloat64Array  ## cost_hours[강수] = 강화 1번 비용 (그 강수 시간당 수익의 몇 시간치)
var broken_drop_to: int         ## 퍼지면 내려가는 강수
var spare_price: float          ## 스페어 엔진 가격 (강수와 상관없는 고정 금액, 원)

# --- tune (튜닝, v2) ---
var tune_grades: PackedStringArray       ## 등급 이름 ["일반", "레어", "에픽", "전설"]
var tune_cost_hours: PackedFloat64Array  ## [등급] = 그 등급에서 1번 굴리는 비용 (0강 시간당 수익의 몇 시간치). 최고 등급 칸은 없음
var tune_up_chance: PackedFloat64Array   ## [등급] = 그 등급에서 한 등급 오를 확률. 최고 등급 칸은 없음
var tune_effects: Dictionary = {}        ## 부위 id → PackedFloat64Array (등급별 효과 숫자, json 그대로)


func is_ok() -> bool:
	return errors.is_empty()


## 부위의 그 등급 효과 숫자 (json 그대로. 예: "turbo", 1 → 0.1). 등급은 0~최고로 자름.
## 모르는 부위면 0 (빨간 오류를 찍음)
func tune_effect(part: String, grade: int) -> float:
	if not tune_effects.has(part):
		push_error("모르는 튜닝 부위: %s" % part)
		return 0.0
	var list: PackedFloat64Array = tune_effects[part]
	return list[clampi(grade, 0, list.size() - 1)]


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
	var income: Dictionary = d["income"]
	var engine: Dictionary = d["engine"]
	var tune: Dictionary = d["tune"]
	b.base_hourly = float(income["base_hourly"])
	b.star_mult = float(income["star_mult"])
	b.star_mult_high = float(income["star_mult_high"])
	b.high_from_star = int(income["high_from_star"])
	b.offline_cap_hours = float(income["offline_cap_hours"])
	b.offline_rate = float(income["offline_rate"])
	b.max_star = int(engine["max_star"])
	b.success = PackedFloat64Array(engine["success"])
	b.destroy = PackedFloat64Array(engine["destroy"])
	b.cost_hours = PackedFloat64Array(engine["cost_hours"])
	b.broken_drop_to = int(engine["broken_drop_to"])
	b.spare_price = float(engine["spare_price"])
	b.tune_grades = PackedStringArray(tune["tune_grades"])
	b.tune_cost_hours = PackedFloat64Array(tune["tune_cost_hours"])
	b.tune_up_chance = PackedFloat64Array(tune["tune_up_chance"])
	for part in TUNE_EFFECT_KEYS:
		b.tune_effects[part] = PackedFloat64Array(tune[TUNE_EFFECT_KEYS[part]])
	return b


## 숫자 검사. 틀린 곳마다 한 줄씩 돌려준다. 비어 있으면 정상.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()

	var income = d.get("income")
	var engine = d.get("engine")
	var tune = d.get("tune")
	if typeof(income) != TYPE_DICTIONARY:
		errs.append("\"income\" 묶음이 없음")
	if typeof(engine) != TYPE_DICTIONARY:
		errs.append("\"engine\" 묶음이 없음")
	if typeof(tune) != TYPE_DICTIONARY:
		errs.append("\"tune\" 묶음이 없음")
	if not errs.is_empty():
		return errs

	# --- income ---
	_check_number(income, "income", "base_hourly", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(income, "income", "star_mult", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(income, "income", "star_mult_high", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(income, "income", "high_from_star", errs, "1 이상의 정수여야 함",
			func(v): return v >= 1.0 and v == floorf(v))
	_check_number(income, "income", "offline_cap_hours", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_check_number(income, "income", "offline_rate", errs, "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0)

	# --- tune ---
	_validate_tune(tune, income, errs)

	# --- engine ---
	_check_number(engine, "engine", "spare_price", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	var max_ok := _check_number(engine, "engine", "max_star", errs, "1 이상의 정수여야 함",
			func(v): return v >= 1.0 and v == floorf(v))
	if not max_ok:
		return errs  # 최대 강수를 모르면 아래 길이 검사를 할 수 없음
	var max_star := int(engine["max_star"])

	_check_number(engine, "engine", "broken_drop_to", errs, "0 이상 %d 미만의 정수여야 함" % max_star,
			func(v): return v >= 0.0 and v < max_star and v == floorf(v))

	var by_star := "max_star %d와 같아야 함" % max_star
	var success_ok := _check_list(engine, "engine", "success", max_star, by_star, errs, "0~1 사이여야 함",
			func(v): return v >= 0.0 and v <= 1.0)
	var destroy_ok := _check_list(engine, "engine", "destroy", max_star, by_star, errs, "0~1 사이여야 함",
			func(v): return v >= 0.0 and v <= 1.0)
	_check_list(engine, "engine", "cost_hours", max_star, by_star, errs, "0보다 커야 함", func(v): return v > 0.0)

	if success_ok and destroy_ok:
		for s in max_star:
			var sum: float = engine["success"][s] + engine["destroy"][s]
			if sum > 1.0 + SUM_EPSILON:
				errs.append("engine.success[%d] + engine.destroy[%d] = %s (1 이하여야 함)" % [s, s, sum])
	return errs


## "tune" 묶음 검사 (튜닝 v2). income은 "offline_rate + 내비 최고 ≤ 1" 검사에 쓴다.
static func _validate_tune(tune: Dictionary, income: Dictionary, errs: PackedStringArray) -> void:
	var n := TUNE_GRADE_COUNT
	var grades = tune.get("tune_grades")
	if typeof(grades) != TYPE_ARRAY:
		errs.append("tune.tune_grades 가 없거나 [ ] 목록이 아님")
	else:
		if grades.size() != n:
			errs.append("tune.tune_grades 길이가 %d개 (등급 %d개여야 함)" % [grades.size(), n])
		for i in grades.size():
			if typeof(grades[i]) != TYPE_STRING or (grades[i] as String).strip_edges().is_empty():
				errs.append("tune.tune_grades[%d] 가 이름(글자)이 아님: %s" % [i, grades[i]])

	var per_step := "등급 %d개 - 1 = %d개여야 함. 최고 등급에서는 안 굴림" % [n, n - 1]
	_check_list(tune, "tune", "tune_cost_hours", n - 1, per_step, errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_list(tune, "tune", "tune_up_chance", n - 1, per_step, errs, "0보다 크고 1 이하여야 함",
			func(v): return v > 0.0 and v <= 1.0)

	# 부위 효과: [json 이름, 규칙 설명, 규칙]. 전부 등급 수만큼, 등급이 오를수록 줄지 않음
	var rules := [
		["turbo_income_bonus", "0 이상이어야 함", func(v): return v >= 0.0],
		["tire_jackpot_chance", "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0],
		["cargo_jackpot_mult", "1 이상이어야 함", func(v): return v >= 1.0],
		["suspension_destroy_cut", "0 이상 1 미만이어야 함", func(v): return v >= 0.0 and v < 1.0],
		["fuel_extra_hours", "0 이상이어야 함", func(v): return v >= 0.0],
		["navi_extra_rate", "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0],
		["oil_cost_cut", "0 이상 1 미만이어야 함", func(v): return v >= 0.0 and v < 1.0],
	]
	var per_grade := "등급 %d개와 같아야 함" % n
	for r in rules:
		var key: String = r[0]
		if not _check_list(tune, "tune", key, n, per_grade, errs, r[1], r[2]):
			continue
		var list: Array = tune[key]
		for i in range(1, list.size()):
			if float(list[i]) < float(list[i - 1]):
				errs.append("tune.%s[%d] = %s (앞 등급 %s보다 작음. 등급이 오를수록 줄면 안 됨)"
						% [key, i, list[i], list[i - 1]])

	# 꺼둔 동안 수익 비율은 내비를 최고로 올려도 1(100%)을 넘으면 안 됨
	var navi = tune.get("navi_extra_rate")
	var rate = income.get("offline_rate")
	if typeof(navi) == TYPE_ARRAY and not navi.is_empty() and _is_number(navi.back()) and _is_number(rate):
		var top := float(rate) + float(navi.back())
		if top > 1.0 + SUM_EPSILON:
			errs.append("income.offline_rate + tune.navi_extra_rate 최고 = %s (1 이하여야 함)" % top)


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
