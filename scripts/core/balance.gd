## 게임 숫자(data/balance.json)를 읽고 검사한다.
## 묶음은 "trip"(한 바퀴·팁), "engine"(강화·스페어), "offline"(꺼둔 동안), "setting"(세팅 돌리기),
## "driver"(기사 레벨), "abilities"(기사 능력치), "depot"(창고·야간팀), "quests"(다음 할 일 목록),
## "special"(대형·VIP), "rush"(급송 전화), "weekly"(주간 배송 목표), "master"(명장 방문일·보험·보너스),
## "company"(회사 단계·세금·대리점·보조 트럭·순위 v7a).
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
const QUEST_KINDS := ["parcels", "star", "setting_rolls", "setting_grade", "part_rolled", "spares_bought", "warehouse", "night", "level",
		"agency", "helpers"]
## 회사 단계 앞 두 개 (코드가 번호로 씀: GameState.company_stage 0 = 개인 기사, 1 = 대리점). 그 뒤 단계는 세율표 공개용
const STAGES_START := ["solo", "agency"]
## 기사 능력치 id (v5b). trip.gd가 이 id로 효과를 읽어서 json에 다 있어야 하고, 모르는 id는 막는다 (효과 없이 포인트만 먹지 않게)
const ABILITY_IDS := ["unload", "kind", "nego", "knowhow", "mech"]
## 출력 제한 배송 종류 (v6b). trip.gd가 이 id로 읽음
const SPECIAL_IDS := ["large", "vip"]
## 명장 보너스 (v6b). enhance·economy·setting·trip이 이 id로 효과를 읽어서 다 있어야 하고, 모르는 id는 막는다
const MASTER_BONUS_IDS := ["destroy_cut", "enhance_discount", "setting_up_mult", "success_mult", "spare_mult", "setting_discount", "double_step"]

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
var tip_base_chance: float      ## 배송 1건마다 팁이 나올 기본 확률 (친절 포인트가 더해짐)
var tip_rate: float             ## 팁 = (협상이 적용된) 단가 × tip_rate. 기름값·정비비 안 뗌

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

# --- offline (꺼둔 동안). 쌓이는 시간·비율은 depot (창고·야간팀 레벨) ---
var offline_ignore_under_seconds: float   ## 이보다 짧게 꺼 뒀으면 꺼둔 동안 계산을 안 함

# --- driver (기사 레벨) ---
var driver_max_level: int
var driver_base_xp: float               ## 다음 레벨까지 = round(base_xp × 레벨 ^ exponent)
var driver_exponent: float
var driver_points_per_level: int        ## 레벨업마다 포인트
var driver_bonus_points_every_10: int   ## 오른 레벨이 10의 배수면 더 주는 포인트
var driver_xp_per_parcel: int           ## 켜 둔 동안 배송 1건 경험치
var driver_star_milestones: PackedInt64Array   ## 처음 닿으면 보너스 경험치를 주는 강화 단계들 (오름차순)
var driver_star_milestone_xp: int

# --- abilities (기사 능력치 v5b) ---
var ability_ids: Array[String] = []   ## json 순서
var abilities: Dictionary = {}        ## id → { "per_point": float, "max_points": int }

# --- special (출력 제한 배송 v6b): "large" / "vip" → { "unlock_star": int, "pay_mult": float, "share": float } ---
var special: Dictionary = {}

# --- rush (급송 요청 전화 v6b) ---
var rush_min_minutes: float     ## 벨 간격 최소 (분)
var rush_max_minutes: float     ## 벨 간격 최대 (분)
var rush_ring_seconds: float    ## 벨이 울리는 시간 (초). 이 안에 받아야 함
var rush_parcels: int           ## 받으면 트럭 0의 다음 몇 건
var rush_pay_mult: float        ## 그 배송 단가 몇 배

# --- weekly (주간 배송 목표 v6b) ---
var weekly_target: int          ## 한 주 배송 목표 (모든 트럭, 꺼둔 동안 포함)
var weekly_xp: int              ## 달성 보상 경험치
var weekly_coupons: int         ## 달성 보상 보험 쿠폰

# --- master (명장 방문일 v6b) ---
var master_unlock_star: int             ## 이 단계를 처음 달성하면 열림
var master_insure_fee_mult: float       ## 방문 중 보험 추가 요금 = 그 회 강화 비용 × 이것
var master_bonuses: Dictionary = {}     ## 보너스 id → 수치 (destroy_cut 0.3 = 퍼짐 × 0.7, enhance_discount 0.2 = 비용 × 0.8,
                                        ## setting_up_mult 1.5배, success_mult 1.2배, spare_mult 2배, setting_discount 0.2, double_step 10%)
var master_bonus_ids: Array[String] = []   ## json 순서 (그 주 보너스를 고르게 뽑을 때)

# --- company (회사 단계 v7a). [단계] 0 개인 기사 / 1 대리점 / 2~ 업데이트용 (세율표 공개만) ---
var company_stages: PackedStringArray     ## 단계 id ("solo", "agency", …)
var tax_rates: PackedFloat64Array         ## [단계] = 번 돈에서 떼는 세금 비율
var agency_price: int                     ## 대리점 창업 가격
var staff_share: float                    ## 보조 트럭이 번 돈에서 떼는 직원 몫 비율
var helper_prices: PackedInt64Array       ## [이미 산 보조 트럭 수] = 다음 보조 트럭 값 (길이 = 살 수 있는 보조 트럭 수)
var city_xp_per_parcel: int               ## 대리점(시내) 뒤 내 트럭 배송 1건 경험치
var rivals: PackedFloat64Array            ## 순위표 라이벌 시간당 매출 (오름차순)

# --- depot (창고 확장·야간 배송팀). [레벨-1] ---
var warehouse_hours: PackedFloat64Array   ## 꺼둔 동안 쌓이는 최대 시간
var warehouse_prices: PackedInt64Array    ## [지금 레벨-1] = 다음 레벨 가격 (길이 = 레벨 수 − 1)
var warehouse_max_level_solo: int         ## 대리점 전에 살 수 있는 최고 창고 레벨
var night_rates: PackedFloat64Array       ## 꺼둔 동안 버는 비율 (켜 둔 때의 몇 배)
var night_prices: PackedInt64Array

# --- quests (다음 할 일. 순서대로 하나씩) ---
var quests: Array = []   ## { "id": String, "kind": String, "target": int, "part": String("" = 없음), "xp": int, "money": int }

# --- setting (세팅 돌리기). [등급]은 0 순정 ~ 4 프로토타입 ---
var lines_by_grade: PackedInt64Array    ## [등급] = 줄 수
var up_chance: PackedFloat64Array       ## [등급] = 한 등급 오를 확률 (최고 등급 칸은 없음)
var ceiling: PackedInt64Array           ## [등급] = 천장. 이 횟수째 돌리기는 무조건 등급업 (최고 등급 칸은 없음)
var roll_cost: PackedInt64Array         ## [등급] = 돌리기 1번 비용 (원)
var cost_cut_cap: float                 ## 기름값 + 정비비 절감 합의 상한
var engine_guard_cap: float             ## 엔진 보호 합의 상한
var overboost_mult: float               ## 오버부스트: 걸린 바퀴 내내 운전 속도 몇 배
var setting_parts: Dictionary = {}      ## 부품 id → { "unlock_star": int, "unlock_stage": int, "options": PackedStringArray } (json 순서)
                                        ## json "unlock": 회사 단계 id (없으면 처음부터 = 0), "unlock_star" 없으면 0
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
	b.tip_base_chance = float(trip["tip_base_chance"])
	b.tip_rate = float(trip["tip_rate"])
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
	b.offline_ignore_under_seconds = float(offline["ignore_under_seconds"])
	var driver: Dictionary = d["driver"]
	b.driver_max_level = int(driver["max_level"])
	b.driver_base_xp = float(driver["base_xp"])
	b.driver_exponent = float(driver["exponent"])
	b.driver_points_per_level = int(driver["points_per_level"])
	b.driver_bonus_points_every_10 = int(driver["bonus_points_every_10"])
	b.driver_xp_per_parcel = int(driver["xp_per_parcel"])
	b.driver_star_milestones = PackedInt64Array(driver["star_milestones"])
	b.driver_star_milestone_xp = int(driver["star_milestone_xp"])
	for id in d["abilities"]:
		var ab: Dictionary = d["abilities"][id]
		b.ability_ids.append(id)
		b.abilities[id] = { "per_point": float(ab["per_point"]), "max_points": int(ab["max_points"]) }
	for k in SPECIAL_IDS:
		var sp: Dictionary = d["special"][k]
		b.special[k] = { "unlock_star": int(sp["unlock_star"]), "pay_mult": float(sp["pay_mult"]), "share": float(sp["share"]) }
	var rush: Dictionary = d["rush"]
	b.rush_min_minutes = float(rush["min_minutes"])
	b.rush_max_minutes = float(rush["max_minutes"])
	b.rush_ring_seconds = float(rush["ring_seconds"])
	b.rush_parcels = int(rush["parcels"])
	b.rush_pay_mult = float(rush["pay_mult"])
	var weekly: Dictionary = d["weekly"]
	b.weekly_target = int(weekly["target_parcels"])
	b.weekly_xp = int(weekly["xp"])
	b.weekly_coupons = int(weekly["coupons"])
	var master: Dictionary = d["master"]
	b.master_unlock_star = int(master["unlock_star"])
	b.master_insure_fee_mult = float(master["insure_fee_mult"])
	for id in master["bonuses"]:
		b.master_bonus_ids.append(id)
		b.master_bonuses[id] = float(master["bonuses"][id])
	var company: Dictionary = d["company"]
	b.company_stages = PackedStringArray(company["stages"])
	b.tax_rates = PackedFloat64Array(company["tax_rates"])
	b.agency_price = int(company["agency_price"])
	b.staff_share = float(company["staff_share"])
	b.helper_prices = PackedInt64Array(company["helper_prices"])
	b.city_xp_per_parcel = int(company["city_xp_per_parcel"])
	b.rivals = PackedFloat64Array(company["rivals"])
	var depot: Dictionary = d["depot"]
	b.warehouse_hours = PackedFloat64Array(depot["warehouse_hours"])
	b.warehouse_prices = PackedInt64Array(depot["warehouse_prices"])
	b.warehouse_max_level_solo = int(depot["warehouse_max_level_solo"])
	b.night_rates = PackedFloat64Array(depot["night_rates"])
	b.night_prices = PackedInt64Array(depot["night_prices"])
	for q in d["quests"]:
		b.quests.append({ "id": q["id"], "kind": q["kind"], "target": int(q["target"]), "part": q.get("part", ""),
				"xp": int(q["xp"]), "money": int(q["money"]) })
	var setting: Dictionary = d["setting"]
	b.lines_by_grade = PackedInt64Array(setting["lines_by_grade"])
	b.up_chance = PackedFloat64Array(setting["up_chance"])
	b.ceiling = PackedInt64Array(setting["ceiling"])
	b.roll_cost = PackedInt64Array(setting["roll_cost"])
	b.cost_cut_cap = float(setting["cost_cut_cap"])
	b.engine_guard_cap = float(setting["engine_guard_cap"])
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
		b.setting_parts[id] = { "unlock_star": int(pt.get("unlock_star", 0)), "unlock_stage": b.company_stages.find(pt.get("unlock", "solo")),
				"options": PackedStringArray(pt["options"]) }
	return b


## 숫자 검사. 틀린 곳마다 한 줄씩 돌려준다. 비어 있으면 정상.
static func validate(d: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()

	var trip = d.get("trip")
	var engine = d.get("engine")
	var offline = d.get("offline")
	var setting = d.get("setting")
	var driver = d.get("driver")
	var depot = d.get("depot")
	var abilities = d.get("abilities")
	for pair in [["trip", trip], ["engine", engine], ["offline", offline], ["setting", setting], ["driver", driver], ["depot", depot],
			["abilities", abilities], ["special", d.get("special")], ["rush", d.get("rush")], ["weekly", d.get("weekly")],
			["master", d.get("master")], ["company", d.get("company")]]:
		if typeof(pair[1]) != TYPE_DICTIONARY:
			errs.append("\"%s\" 묶음이 없음" % pair[0])
	if typeof(d.get("quests")) != TYPE_ARRAY or d["quests"].is_empty():
		errs.append("\"quests\" 목록이 없거나 비어 있음")
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
	var tip_ok := _check_number(trip, "trip", "tip_base_chance", errs, "0~1 사이여야 함", rate)
	_check_number(trip, "trip", "tip_rate", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_validate_abilities(abilities, float(trip["tip_base_chance"]) if tip_ok else 0.0, errs)

	# --- offline ---
	_check_number(offline, "offline", "ignore_under_seconds", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	_validate_depot(depot, errs)

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

	var stages_ok := _validate_company(d["company"], errs)
	_validate_setting(setting, max_star, d["company"]["stages"] if stages_ok else [], errs)
	_validate_v6b(d, max_star, errs)
	var max_level := _validate_driver(driver, max_star, errs)
	_validate_quests(d["quests"], max_star, max_level, setting, depot, d["company"], errs)
	return errs


## "driver" 묶음 검사 (기사 레벨 v5). 만렙을 돌려준다 (틀렸으면 0)
static func _validate_driver(driver: Dictionary, max_star: int, errs: PackedStringArray) -> int:
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var level_ok := _check_number(driver, "driver", "max_level", errs, "2 이상의 정수여야 함", func(v): return v >= 2.0 and v == floorf(v))
	_check_number(driver, "driver", "base_xp", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(driver, "driver", "exponent", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	for key in ["points_per_level", "bonus_points_every_10", "xp_per_parcel", "star_milestone_xp"]:
		_check_number(driver, "driver", key, errs, "0 이상의 정수여야 함", whole)
	var list = driver.get("star_milestones")
	if typeof(list) != TYPE_ARRAY:
		errs.append("driver.star_milestones 가 [ ] 목록이 아님")
	elif _check_list(driver, "driver", "star_milestones", list.size(), "", errs, "1~%d 정수여야 함" % max_star,
			func(v): return v >= 1.0 and v <= max_star and v == floorf(v)):
		for i in range(1, list.size()):
			if float(list[i]) <= float(list[i - 1]):
				errs.append("driver.star_milestones[%d] = %s (앞 값 %s보다 커야 함)" % [i, list[i], list[i - 1]])
	return int(driver["max_level"]) if level_ok else 0


## "special"·"rush"·"weekly" 묶음 검사 (v6b)
static func _validate_v6b(d: Dictionary, max_star: int, errs: PackedStringArray) -> void:
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var special: Dictionary = d["special"]
	for k in special:
		if not SPECIAL_IDS.has(k):
			errs.append("special 에 모르는 배송: %s (%s 중 하나여야 함)" % [k, "/".join(SPECIAL_IDS)])
	for k in SPECIAL_IDS:
		var where := "special.%s" % k
		var sp = special.get(k)
		if typeof(sp) != TYPE_DICTIONARY:
			errs.append("%s 이 없거나 { } 묶음이 아님" % where)
			continue
		_check_number(sp, where, "unlock_star", errs, "0~%d 정수여야 함" % max_star,
				func(v): return v >= 0.0 and v <= max_star and v == floorf(v))
		_check_number(sp, where, "pay_mult", errs, "1 이상이어야 함", func(v): return v >= 1.0)
		_check_number(sp, where, "share", errs, "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0)
	var rush: Dictionary = d["rush"]
	var min_ok := _check_number(rush, "rush", "min_minutes", errs, "0보다 커야 함", func(v): return v > 0.0)
	if _check_number(rush, "rush", "max_minutes", errs, "0보다 커야 함", func(v): return v > 0.0) and min_ok \
			and float(rush["max_minutes"]) < float(rush["min_minutes"]):
		errs.append("rush.max_minutes = %s (min_minutes %s 이상이어야 함)" % [rush["max_minutes"], rush["min_minutes"]])
	_check_number(rush, "rush", "ring_seconds", errs, "0보다 커야 함", func(v): return v > 0.0)
	_check_number(rush, "rush", "parcels", errs, "1 이상의 정수여야 함", func(v): return v >= 1.0 and v == floorf(v))
	_check_number(rush, "rush", "pay_mult", errs, "1 이상이어야 함", func(v): return v >= 1.0)
	var weekly: Dictionary = d["weekly"]
	_check_number(weekly, "weekly", "target_parcels", errs, "1 이상의 정수여야 함", func(v): return v >= 1.0 and v == floorf(v))
	_check_number(weekly, "weekly", "xp", errs, "0 이상의 정수여야 함", whole)
	_check_number(weekly, "weekly", "coupons", errs, "0 이상의 정수여야 함", whole)
	var master: Dictionary = d["master"]
	_check_number(master, "master", "unlock_star", errs, "0~%d 정수여야 함" % max_star,
			func(v): return v >= 0.0 and v <= max_star and v == floorf(v))
	_check_number(master, "master", "insure_fee_mult", errs, "0 이상이어야 함", func(v): return v >= 0.0)
	var bonuses = master.get("bonuses")
	if typeof(bonuses) != TYPE_DICTIONARY:
		errs.append("master.bonuses 가 없거나 { } 묶음이 아님")
		return
	for id in bonuses:
		if not MASTER_BONUS_IDS.has(id):
			errs.append("master.bonuses 에 모르는 보너스: %s (%s 중 하나여야 함)" % [id, "/".join(MASTER_BONUS_IDS)])
	var cut := func(v): return v >= 0.0 and v < 1.0   # 할인·감소: 1이면 0원·0%라 막음
	var mult := func(v): return v >= 1.0
	var rules := { "destroy_cut": [cut, "0 이상 1 미만이어야 함"], "enhance_discount": [cut, "0 이상 1 미만이어야 함"],
			"setting_discount": [cut, "0 이상 1 미만이어야 함"], "setting_up_mult": [mult, "1 이상이어야 함"],
			"success_mult": [mult, "1 이상이어야 함"], "spare_mult": [mult, "1 이상이어야 함"],
			"double_step": [func(v): return v >= 0.0 and v <= 1.0, "0~1 사이여야 함"] }
	for id in MASTER_BONUS_IDS:
		_check_number(bonuses, "master.bonuses", id, errs, rules[id][1], rules[id][0])


## "company" 묶음 검사 (v7a). stages가 맞으면 true (세팅 부품 "unlock" 검사에 씀)
## 단계 = 글자 목록, 앞 두 개는 solo·agency. 세율은 단계마다 0~1, 오를수록 줄지 않음. 직원 몫 + 가장 큰 세율 ≤ 1 (내 돈이 음수가 안 되게).
## 보조 트럭 값은 정수, 줄지 않음. 라이벌 매출은 0보다 크고 오름차순 (순위 계산이 이 순서를 씀)
static func _validate_company(c: Dictionary, errs: PackedStringArray) -> bool:
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var stages = c.get("stages")
	var stages_ok: bool = typeof(stages) == TYPE_ARRAY and stages.size() >= STAGES_START.size() 			and stages.all(func(x): return typeof(x) == TYPE_STRING) and stages.slice(0, STAGES_START.size()) == STAGES_START
	if not stages_ok:
		errs.append("company.stages = %s (글자 목록, 앞은 %s 이어야 함)" % [stages, STAGES_START])
	var n: int = stages.size() if stages_ok else 0
	var tax_ok: bool = stages_ok and _check_list(c, "company", "tax_rates", n, "company.stages %d개와 같아야 함" % n, errs, "0~1 사이여야 함",
			func(v): return v >= 0.0 and v <= 1.0)
	if tax_ok:
		_check_not_decreasing(c["tax_rates"], "company.tax_rates", errs)
	_check_number(c, "company", "agency_price", errs, "0 이상의 정수여야 함", whole)
	if _check_number(c, "company", "staff_share", errs, "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0) and tax_ok:
		var top := float(c["staff_share"]) + float(c["tax_rates"].max())
		if top > 1.0 + SUM_EPSILON:
			errs.append("company: staff_share + 가장 큰 세율 = %s (1 이하여야 함. 내 돈이 음수가 됨)" % top)
	var helpers = c.get("helper_prices")
	if typeof(helpers) != TYPE_ARRAY:
		errs.append("company.helper_prices 가 [ ] 목록이 아님")
	elif _check_list(c, "company", "helper_prices", helpers.size(), "", errs, "0 이상의 정수여야 함", whole):
		_check_not_decreasing(helpers, "company.helper_prices", errs)
	_check_number(c, "company", "city_xp_per_parcel", errs, "0 이상의 정수여야 함", whole)
	var rivals = c.get("rivals")
	if typeof(rivals) != TYPE_ARRAY or rivals.is_empty():
		errs.append("company.rivals 가 없거나 빈 목록")
	elif _check_list(c, "company", "rivals", rivals.size(), "", errs, "0보다 커야 함", func(v): return v > 0.0):
		_check_not_decreasing(rivals, "company.rivals", errs)
	return stages_ok


## "abilities" 묶음 검사 (기사 능력치 v5b): ABILITY_IDS가 다 있고 그 밖은 없음, per_point ≥ 0, max_points 0 이상 정수.
## 최대로 찍어도 말이 되게: 상하차 per_point × max ≤ 1 (정차 시간이 0 아래로 안 감), 팁 기본 확률 + 친절 최대 ≤ 1
static func _validate_abilities(abilities: Dictionary, tip_base: float, errs: PackedStringArray) -> void:
	for id in abilities:
		if not ABILITY_IDS.has(id):
			errs.append("abilities 에 모르는 능력치: %s (%s 중 하나여야 함)" % [id, "/".join(ABILITY_IDS)])
	for id in ABILITY_IDS:
		var where := "abilities.%s" % id
		var ab = abilities.get(id)
		if typeof(ab) != TYPE_DICTIONARY:
			errs.append("%s 이 없거나 { } 묶음이 아님" % where)
			continue
		var per_ok := _check_number(ab, where, "per_point", errs, "0 이상이어야 함", func(v): return v >= 0.0)
		var max_ok := _check_number(ab, where, "max_points", errs, "0 이상의 정수여야 함", func(v): return v >= 0.0 and v == floorf(v))
		if not (per_ok and max_ok):
			continue
		var top := float(ab["per_point"]) * float(ab["max_points"])
		if id == "unload" and top > 1.0 + SUM_EPSILON:
			errs.append("%s: per_point × max_points = %s (1 이하여야 함. 정차 시간이 0 아래로 감)" % [where, top])
		if id == "kind" and tip_base + top > 1.0 + SUM_EPSILON:
			errs.append("%s: trip.tip_base_chance + per_point × max_points = %s (팁 확률이라 1 이하여야 함)" % [where, tip_base + top])


## "depot" 묶음 검사 (창고 확장·야간 배송팀 v5). 레벨 수 = 시간·비율 목록 길이, 가격은 그보다 1개 적음
static func _validate_depot(depot: Dictionary, errs: PackedStringArray) -> void:
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	for pair in [["warehouse_hours", "warehouse_prices", "0보다 커야 함", func(v): return v > 0.0],
			["night_rates", "night_prices", "0~1 사이여야 함", func(v): return v >= 0.0 and v <= 1.0]]:
		var list = depot.get(pair[0])
		if typeof(list) != TYPE_ARRAY or list.is_empty():
			errs.append("depot.%s 가 없거나 빈 목록" % pair[0])
			continue
		if _check_list(depot, "depot", pair[0], list.size(), "", errs, pair[2], pair[3]):
			_check_not_decreasing(list, "depot." + pair[0], errs)
		_check_list(depot, "depot", pair[1], list.size() - 1, "depot.%s 길이 − 1 = %d개여야 함" % [pair[0], list.size() - 1],
				errs, "0 이상의 정수여야 함", whole)
	var hours = depot.get("warehouse_hours")
	var top: int = hours.size() if typeof(hours) == TYPE_ARRAY else 0
	_check_number(depot, "depot", "warehouse_max_level_solo", errs, "1~%d 정수여야 함" % top,
			func(v): return v >= 1.0 and v <= top and v == floorf(v))


## "quests" 목록 검사 (다음 할 일 v5). 끝낼 수 없는 퀘스트가 있으면 그 뒤가 영영 막히므로 target이 닿을 수 있는 값인지도 본다
static func _validate_quests(list: Array, max_star: int, max_level: int, setting: Dictionary, depot: Dictionary, company: Dictionary,
		errs: PackedStringArray) -> void:
	var whole := func(v): return v >= 0.0 and v == floorf(v)
	var parts = setting.get("parts")
	var nights = depot.get("night_rates")
	var solo = depot.get("warehouse_max_level_solo")
	var reach := {   # kind → target 최댓값 (-1 = 상한 없음)
		"parcels": -1, "setting_rolls": -1, "spares_bought": -1, "part_rolled": 1, "star": max_star,
		"setting_grade": SETTING_GRADES - 1, "level": max_level,
		"warehouse": int(solo) if _is_number(solo) else 0,
		"night": nights.size() if typeof(nights) == TYPE_ARRAY else 0,
		"agency": 1,
		"helpers": company["helper_prices"].size() if typeof(company.get("helper_prices")) == TYPE_ARRAY else 0,
	}
	var seen := {}
	for i in list.size():
		var q = list[i]
		var where := "quests[%d]" % i
		if typeof(q) != TYPE_DICTIONARY:
			errs.append("%s 가 { } 묶음이 아님" % where)
			continue
		var id = q.get("id")
		if typeof(id) != TYPE_STRING or id == "":
			errs.append("%s.id 가 빈 글자이거나 글자가 아님" % where)
		elif seen.has(id):
			errs.append("%s.id = %s (앞에 같은 id가 있음)" % [where, id])
		else:
			seen[id] = true
		var kind = q.get("kind")
		if not QUEST_KINDS.has(kind):
			errs.append("%s.kind = %s (%s 중 하나여야 함)" % [where, kind, "/".join(QUEST_KINDS)])
			continue
		var top: int = reach[kind]
		_check_number(q, where, "target", errs, "1 이상%s의 정수여야 함" % ("" if top < 0 else " %d 이하" % top),
				func(v): return v >= 1.0 and (top < 0 or v <= top) and v == floorf(v))
		_check_number(q, where, "xp", errs, "0 이상의 정수여야 함", whole)
		_check_number(q, where, "money", errs, "0 이상의 정수여야 함", whole)
		if kind == "part_rolled" and not (typeof(parts) == TYPE_DICTIONARY and parts.has(q.get("part"))):
			errs.append("%s.part = %s (setting.parts 에 있는 부품이어야 함)" % [where, q.get("part")])


## "setting" 묶음 검사 (세팅 돌리기 v4)
static func _validate_setting(setting: Dictionary, max_star: int, stages: Array, errs: PackedStringArray) -> void:
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
		if pt.has("unlock_star"):   # 없으면 0
			_check_number(pt, where, "unlock_star", errs, "0~%d 정수여야 함" % max_star,
					func(v): return v >= 0.0 and v <= max_star and v == floorf(v))
		if pt.has("unlock") and not stages.has(pt["unlock"]):   # 없으면 처음부터
			errs.append("%s.unlock = %s (company.stages 중 하나여야 함)" % [where, pt["unlock"]])
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
