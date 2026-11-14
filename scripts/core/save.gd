## 저장 파일 읽고 쓰기 (기본 user://save.json). 화면 없이 돌아가는 코드.
##
## 파일 모양 (JSON, 손으로 고쳐도 됨):
##   saved_at_utc  저장한 시각. 세계 표준시(UTC) "YYYY-MM-DDTHH:MM:SS"
##                 → 꺼둔 동안 수익 확인할 때 이걸 3시간 전 / 20시간 전 / 미래로 고친다
##   money         글자("123456789"). JSON 숫자는 2^53(약 9007조)을 넘으면 끝자리가 틀려져서 글자로 쓴다.
##                 읽을 때는 숫자(손으로 고친 파일)도 받는다
##   spares, spare_drop_carry
##   trucks [ { star, lap_clock, lap_delivered, boost_lap, lap_cargo(형식 6), success_count, fail_count, destroy_count,
##              settings { 부품 id: { grade, lines, counters, pending: null 또는 { grade, lines } } } } ]
##   (형식 5) driver_level, driver_xp, ability_points, reputation, warehouse_level, night_level, quest_index,
##            parcels_total, setting_rolls, spares_bought, parts_rolled { 부품 id: true }, milestones_done [ 단계 ]
##   (형식 7) abilities { 능력치 id: 찍은 포인트 }
##   (형식 8) coupons, weekly_week, weekly_parcels, weekly_done, rush_enabled, rush_next, rush_ring, rush_left
##   (형식 9) master_unlocked, master_day, master_next_day, master_week, master_bonus, master_bonus_week, master_next_bonus,
##            master_notice_week, master_visit_week (active_bonus는 저장 안 함: Master.tick이 채움)
##   (형식 10) company_stage, today_day, today_sales, today_staff, today_tax, rank_first_done
## 모르는 키는 버리고 범위 밖 값은 자른다. 음수 돈·스페어, 빠진 칸, 틀린 모양은 깨진 저장.
## 세팅: 모르는 부품·그 부품에 없는 옵션 id는 버리고, 등급·카운터는 범위로 자르고, 줄은 그 등급 줄 수까지 (앞에서부터).
## 형식 5 칸: 숫자가 아니면 깨진 저장, 숫자는 범위로 자름 (레벨 1~만렙, 경험치 0~다음 레벨 필요량−1, 창고·야간팀 1~표 끝,
##            퀘스트 번호 0~목록 길이, 개수·평판 0 이상). 모르는 부품·보너스 단계가 아닌 값은 버림.
## 형식 7 능력치: 숫자가 아니면 깨진 저장. 모르는 id는 버리고 0~최대로 자르고, 합이 ability_points를 넘으면 전부 0 (포인트는 돌려받음).
## 형식 8 칸: 숫자·참거짓이 아니면 깨진 저장. 쿠폰·주간 진행 0 이상, 급송 남은 건수 0~rush.parcels, 벨 남은 초 0~ring_seconds,
##   다음 벨까지 −1(안 굴림)~max_minutes분으로 자름. 주 번호는 정수면 그대로 (시계 조작 허용).
## 형식 9 칸: 숫자·참거짓·글자가 아니면 깨진 저장. 요일은 −1~6으로 자르고, 모르는 보너스 id는 ""(다음 tick에서 새로 굴림).
## 형식 10 칸: 숫자·참거짓이 아니면 깨진 저장. 회사 단계 0~1(대리점), 오늘 집계 0 이상으로 자름. 날짜 번호는 정수면 그대로.
##   트럭은 1 + company.helper_prices 길이(3대)까지 (넘으면 뒤를 버림).
## 형식 3~9 파일은 그대로 읽는다 (없는 칸은 처음 값: 세팅 없음, 오버부스트 안 걸린 바퀴, 레벨 1, 창고·야간팀 Lv1, 퀘스트 처음부터,
##   lap_cargo 0 = 지금 바퀴 건수를 다음 진행 때 굴림, 능력치 없음, 쿠폰 0, 주간 진행 0·주 모름, 급송 켜짐·벨 시계 새로,
##   명장 안 열림 → 이미 +10을 넘었으면 다음 Master.tick에서 열림, 개인 기사·오늘 집계 0·날짜 모름·1위 알림 안 보냄).
##
## 백업: 쓸 때마다 지금 파일을 path.bak1(가장 최근) → bak2 → bak3 으로 돌린다.
## 본 파일이 깨졌으면 path.broken 으로 옮기고 bak1 → bak2 → bak3 중 읽히는 첫 파일로 살린다.
## 형식 1·2 파일(v2까지)은 변환하지 않고 같은 폴더 save.v2.json 으로 옮겨 남긴 뒤 새 게임.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Ability = preload("res://scripts/core/ability.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 10  ## 1: v0·v1 / 2: 튜닝(v2) / 3: 한 바퀴 경제·트럭 여러 대(v3) / 4: 세팅 돌리기(v4) / 5: 기사 레벨·퀘스트·창고(v5)
                            ## 6: 트럭 lap_cargo (지금 바퀴에 실은 건수, v6-bal) / 7: 기사 능력치 abilities (v5b)
                            ## 8: 쿠폰·주간 배송 목표·급송 전화 (v6b C1) / 9: 명장 방문일 (v6b C2) / 10: 회사·오늘 집계 (v7a)
const OLDEST_READABLE := 3  ## 이보다 옛 형식은 변환하지 않고 옮겨 둔다

enum Status { OK, NONE, BROKEN }   ## 읽음 / 저장 파일 없음(새 게임) / 깨짐(새 게임)

const BACKUPS := 3
const OLD_FILE_NAME := "save.v2.json"   ## 형식 1·2 파일을 옮겨 두는 이름 (본 파일과 같은 폴더)

const TRUCK_COUNTS := ["success_count", "fail_count", "destroy_count"]
## 형식 5에 더한 정수 칸 (GameState 변수 이름 그대로). 범위는 _progress_from에서
const PROGRESS_INTS := ["driver_level", "driver_xp", "ability_points", "reputation", "warehouse_level", "night_level",
		"quest_index", "parcels_total", "setting_rolls", "spares_bought"]
## 형식 9에 더한 명장 칸 (GameState 변수 이름 그대로). 읽기는 _v9_from
const MASTER_FIELDS := ["master_unlocked", "master_day", "master_next_day", "master_week", "master_bonus", "master_bonus_week",
		"master_next_bonus", "master_notice_week", "master_visit_week"]
## 형식 10에 더한 회사 칸 (GameState 변수 이름 그대로). 읽기는 _v10_from
const COMPANY_FIELDS := ["company_stage", "today_day", "today_sales", "today_staff", "today_tax", "rank_first_done"]
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
			"lap_cargo": t.lap_cargo,
			"success_count": t.success_count,
			"fail_count": t.fail_count,
			"destroy_count": t.destroy_count,
			"settings": t.settings.duplicate(true),
		})
	var d := {
		"version": FORMAT_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_unix_time(saved_at_unix),
		"money": str(s.money),
		"spares": s.spares,
		"spare_drop_carry": s.spare_drop_carry,
		"trucks": trucks,
		"parts_rolled": s.parts_rolled.duplicate(),
		"milestones_done": s.milestones_done.duplicate(),
		"abilities": s.abilities.duplicate(),
		"coupons": s.coupons,
		"weekly_week": s.weekly_week,
		"weekly_parcels": s.weekly_parcels,
		"weekly_done": s.weekly_done,
		"rush_enabled": s.rush_enabled,
		"rush_next": s.rush_next,
		"rush_ring": s.rush_ring,
		"rush_left": s.rush_left,
	}
	for key in MASTER_FIELDS + COMPANY_FIELDS:
		d[key] = s.get(key)
	for key in PROGRESS_INTS:
		d[key] = s.get(key)
	return d


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
		var lap_cargo = td.get("lap_cargo", 0)   # 형식 5까지는 없음 → 다음 진행 때 굴림
		if not _is_finite_number(lap_cargo):
			return _broken("trucks[%d].lap_cargo 가 숫자가 아님: %s" % [k, lap_cargo])
		t.lap_cargo = clampi(floori(lap_cargo), 0, 1 << 30)
		var settings = _settings_from(td.get("settings", {}), b)   # 형식 3에는 없음
		if settings == null:
			return _broken("trucks[%d].settings 모양이 틀림" % k)
		t.settings = settings
		s.trucks.append(t)

	var why := _progress_from(d, b, s)
	if why == "":
		why = _abilities_from(d.get("abilities", {}), b, s)   # 형식 6까지는 없음 → 능력치 없음
	if why == "":
		why = _v8_from(d, b, s)   # 형식 7까지는 없음 → 처음 값
	if why == "":
		why = _v9_from(d, b, s)   # 형식 8까지는 없음 → 처음 값
	if why == "":
		why = _v10_from(d, b, s)   # 형식 9까지는 없음 → 처음 값
	if why != "":
		return _broken(why)
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


## 형식 5 칸(레벨·창고·퀘스트 진행) → 상태 s. 없는 칸은 처음 값(형식 3·4), 숫자는 범위로 자름. 틀린 모양이면 그 이유 (없으면 "")
static func _progress_from(d: Dictionary, b: Balance, s: GameState) -> String:
	for key in PROGRESS_INTS:
		var v = d.get(key, s.get(key))
		if not _is_finite_number(v):
			return "%s 가 숫자가 아님: %s" % [key, v]
		s.set(key, clampi(floori(v), 0, MAX_WHOLE))
	s.driver_level = clampi(s.driver_level, 1, Driver.max_level(b))
	s.driver_xp = clampi(s.driver_xp, 0, maxi(0, Driver.xp_need(b, s.driver_level) - 1))
	s.warehouse_level = clampi(s.warehouse_level, 1, Depot.top_level(b, "warehouse"))
	s.night_level = clampi(s.night_level, 1, Depot.top_level(b, "night"))
	s.quest_index = mini(s.quest_index, Quest.count(b))
	var rolled = d.get("parts_rolled", {})
	if typeof(rolled) != TYPE_DICTIONARY:
		return "parts_rolled 가 { } 묶음이 아님"
	for part in rolled:
		if b.setting_parts.has(part) and typeof(rolled[part]) == TYPE_BOOL and rolled[part]:
			s.parts_rolled[part] = true
	var done = d.get("milestones_done", [])
	if typeof(done) != TYPE_ARRAY:
		return "milestones_done 이 [ ] 목록이 아님"
	for m in done:
		if _is_finite_number(m) and m == floorf(m) and b.driver_star_milestones.has(int(m)) and not s.milestones_done.has(int(m)):
			s.milestones_done.append(int(m))
	return ""


## 형식 8 칸 (쿠폰·주간 목표·급송) → s. 없는 칸은 GameState 처음 값. 틀린 모양이면 그 이유 (없으면 "")
static func _v8_from(d: Dictionary, b: Balance, s: GameState) -> String:
	for key in ["coupons", "weekly_week", "weekly_parcels", "rush_left", "rush_next", "rush_ring"]:
		if not _is_finite_number(d.get(key, 0)):
			return "%s 가 숫자가 아님: %s" % [key, d.get(key)]
	for key in ["weekly_done", "rush_enabled"]:
		if typeof(d.get(key, false)) != TYPE_BOOL:
			return "%s 가 true/false가 아님: %s" % [key, d.get(key)]
	s.coupons = clampi(floori(d.get("coupons", 0)), 0, MAX_WHOLE)
	s.weekly_week = floori(d.get("weekly_week", s.weekly_week))
	s.weekly_parcels = clampi(floori(d.get("weekly_parcels", 0)), 0, MAX_WHOLE)
	s.weekly_done = d.get("weekly_done", false)
	s.rush_enabled = d.get("rush_enabled", true)
	s.rush_next = clampf(float(d.get("rush_next", -1.0)), -1.0, b.rush_max_minutes * 60.0)
	s.rush_ring = clampf(float(d.get("rush_ring", 0.0)), 0.0, b.rush_ring_seconds)
	s.rush_left = clampi(floori(d.get("rush_left", 0)), 0, b.rush_parcels)
	return ""


## 형식 9 명장 칸 → s. 없는 칸은 GameState 처음 값. 틀린 모양이면 그 이유 (없으면 "")
static func _v9_from(d: Dictionary, b: Balance, s: GameState) -> String:
	for key in MASTER_FIELDS:
		var v = d.get(key, s.get(key))
		var want := typeof(s.get(key))
		var ok := (want == TYPE_BOOL and typeof(v) == TYPE_BOOL) or (want == TYPE_STRING and typeof(v) == TYPE_STRING) \
				or (want == TYPE_INT and _is_finite_number(v))
		if not ok:
			return "%s 모양이 틀림: %s" % [key, v]
		if want == TYPE_INT:
			v = floori(v)
			if key == "master_day" or key == "master_next_day":
				v = clampi(v, -1, 6)
		elif want == TYPE_STRING and v != "" and not b.master_bonuses.has(v):
			v = ""   # 모르는 보너스 → 다음 tick에서 새로
		s.set(key, v)
	return ""


## 형식 10 회사 칸 → s. 없는 칸은 GameState 처음 값. 틀린 모양이면 그 이유 (없으면 ""). 트럭이 너무 많으면 뒤를 버림
static func _v10_from(d: Dictionary, b: Balance, s: GameState) -> String:
	for key in COMPANY_FIELDS:
		var v = d.get(key, s.get(key))
		if key == "rank_first_done":
			if typeof(v) != TYPE_BOOL:
				return "%s 가 true/false가 아님: %s" % [key, v]
			s.rank_first_done = v
			continue
		if not _is_finite_number(v):
			return "%s 가 숫자가 아님: %s" % [key, v]
		s.set(key, floori(v) if key == "today_day" else clampi(floori(v), 0, MAX_WHOLE))
	s.company_stage = mini(s.company_stage, GameState.AGENCY)
	s.trucks = s.trucks.slice(0, 1 + b.helper_prices.size())
	return ""


## 형식 7 능력치 → s.abilities (ability_points를 먼저 읽은 뒤에). 틀린 모양이면 그 이유 (없으면 "")
## 모르는 id는 버리고, 0~최대로 자르고(소수는 버림), 찍은 합이 받은 포인트를 넘으면 전부 0
static func _abilities_from(v, b: Balance, s: GameState) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "abilities 가 { } 묶음이 아님"
	for id in v:
		if not b.abilities.has(id):
			continue
		if not _is_finite_number(v[id]):
			return "abilities.%s 가 숫자가 아님: %s" % [id, v[id]]
		var p := clampi(floori(v[id]), 0, Ability.max_points(b, id))
		if p > 0:
			s.abilities[id] = p
	if Ability.points_left(s) < 0:
		Ability.reset(s)
	return ""


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
