## v7b C1: 장거리 노선 (routes.long), 트럭마다 노선 스위치 (다음 바퀴부터), 잠금 (대리점 + 그 트럭 +10),
## 터보 "장거리 속도" (장거리 바퀴만), 장거리 경험치 30, 꺼둔 동안 (스위치 노선), 저장 형식 12
extends "res://tests/test_base.gd"

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

var b: Balance = Balance.load_file()
## 대형·VIP 끔 (배송 1건 돈이 늘 같아서 손으로 셈)
var bn: Balance = _no_special()


func _no_special() -> Balance:
	var d := real_balance_dict()
	d["special"]["large"]["share"] = 0.0
	d["special"]["vip"]["share"] = 0.0
	var bal: Balance = Balance.from_dict(d)
	assert(bal.is_ok(), ", ".join(bal.errors))
	return bal


## 트럭들 (단계 목록), 대리점이면 agency, 퀘스트·주간 목표 끝 (보상 돈·경험치가 안 섞이게)
func _game(stars: Array, agency: bool) -> GameState:
	var s := GameState.new_game()
	s.trucks.clear()
	for star in stars:
		var t := TruckState.new()
		t.star = star
		s.trucks.append(t)
	s.quest_index = Quest.count(b)
	s.weekly_done = true
	if agency:
		s.company_stage = GameState.AGENCY
	return s


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## json: 장거리 숫자, 터보 부품·장거리 속도 옵션, 틀린 숫자는 막힘
func test_json_long() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.routes["long"], { "price_mult": 7.0, "road_mult": 5.0, "stops_mult": 1.0, "xp_per_parcel": 30, "unlock_star": 10 },
			"장거리: 단가 ×7 (v7b C4), 도로 ×5, 집 수 ×1, 경험치 30, +10")
	check_eq([Setting.unlock_stage(b, "turbo"), Setting.unlock_star(b, "turbo")], [GameState.AGENCY, 10], "터보 = 대리점 + +10")
	check_eq(b.setting_parts["turbo"]["options"], PackedStringArray(["speed", "fuel_cut", "long_speed", "junk_ride", "junk_scent",
			"junk_cupholder", "junk_radio", "junk_gloss"]), "터보 옵션")
	check_eq(b.setting_options["long_speed"]["values"], PackedFloat64Array([0.05, 0.08, 0.12, 0.2, 0.3]), "장거리 속도 5/8/12/20/30%")
	check(Setting.option_chances(b, "turbo", 0).has("long_speed"), "순정 터보에서 장거리 속도가 안 뜸")
	for c in [
		[func(d): d["routes"].erase("long"), "routes.long 가 없거나"],
		[func(d): d["routes"]["long"]["xp_per_parcel"] = 1.5, "routes.long.xp_per_parcel = 1.5"],
		[func(d): d["routes"]["long"]["unlock_star"] = 31, "routes.long.unlock_star = 31"],
		[func(d): d["routes"]["long"]["price_mult"] = 0, "routes.long.price_mult = 0"],
		[func(d): d["setting"]["options"]["long_speed"]["values"] = [0.05, 0.08, 0.12, 0.2], "setting.options.long_speed.values 길이"],
	]:
		var d := real_balance_dict()
		c[0].call(d)
		var bad: Balance = Balance.from_dict(d)
		check(not bad.is_ok() and ", ".join(bad.errors).contains(c[1]), "%s 를 못 잡음: %s" % [c[1], bad.errors])


## 잠금: 대리점 + 그 트럭 +10. 터보도 같은 조건. 잠긴 트럭은 스위치가 안 바뀜
func test_lock() -> void:
	var solo := _game([30], false)
	check(not Trip.can_long(b, solo, 0), "개인 기사 +30인데 장거리가 열림")
	check(not Setting.unlocked(b, solo, 0, "turbo"), "개인 기사 +30인데 터보가 열림")
	check(not Trip.set_route(b, solo, 0, "long") and not Trip.set_route(b, solo, 0, "city"), "개인 기사가 스위치를 바꿈")
	var s := _game([10, 9], true)
	check_eq([Trip.can_long(b, s, 0), Trip.can_long(b, s, 1)], [true, false], "대리점: +10 트럭만 장거리")
	check_eq([Setting.unlocked(b, s, 0, "turbo"), Setting.unlocked(b, s, 1, "turbo")], [true, false], "대리점: +10 트럭만 터보")
	check(not Trip.set_route(b, s, 1, "long"), "+9 트럭이 장거리로 바뀜")
	check_eq(Trip.route_choice(s, 1), "city", "+9 트럭 스위치 그대로 시내")
	check(Trip.set_route(b, s, 1, "city"), "+9 트럭도 시내는 고를 수 있음")
	check(not Trip.set_route(b, s, 0, "town") and not Trip.set_route(b, s, 0, "moon"), "모르는 노선을 받음")
	check(Trip.set_route(b, s, 0, "long"), "+10 트럭이 장거리로 안 바뀜")
	check_eq([Trip.route_choice(s, 0), s.truck(0).route], ["long", "long"], "스위치 = 장거리")
	check(Trip.set_route(b, s, 0, "city"), "장거리 → 시내가 안 됨")
	check_eq([Trip.route_choice(s, 0), s.truck(0).route], ["city", ""], "스위치 = 시내 (저장 값 \"\")")


## 바꾸면 다음 바퀴부터: 이번 바퀴(시내 40집)는 실은 대로 끝내고, 다음 바퀴가 장거리 20집. 같은 진행 호출 안에서 바퀴가 바뀌어도 돈이 노선을 따름
func test_switch_next_lap() -> void:
	var s := _game([10], true)
	var rng := _rng(1)
	Trip.advance(s, bn, 0, 30.0, rng)   # 시내 첫 바퀴 중간 (싣기 20초 + 10초)
	check(Trip.set_route(bn, s, 0, "long"), "장거리로 바꾸기")
	check_eq([Trip.route_id(s, 0), Trip.route_choice(s, 0), Trip.lap_cargo(bn, s, 0)], ["city", "long", 40], "바꾼 바퀴: 아직 시내 40집")
	var left := Trip.lap_seconds_left(bn, s, 0)
	check_near(left, 72.0 - 30.0, 1e-9, "+10 시내 한 바퀴 72초 중 남은 42초")
	var city_pay := Trip.parcel_pay(bn, s, 0)
	var houses := { "city": [], "long": [] }
	var pays := { "city": {}, "long": {} }
	for e in Trip.advance(s, bn, 0, left + 300.0, rng):   # 시내 바퀴 끝 + 장거리 바퀴 300초 (한 호출)
		if e["type"] == "parcel":
			var r := "city" if houses["long"].is_empty() and (houses["city"].is_empty() or e["house"] > houses["city"].back()) else "long"
			houses[r].append(e["house"])
			pays[r][e["gross"]] = true
	check_eq([Trip.route_id(s, 0), s.truck(0).lap_route, Trip.lap_cargo(bn, s, 0), s.long_laps], ["long", "long", 20, 1], "다음 바퀴: 장거리 20집, 장거리 1바퀴")
	check_eq(pays["city"].keys(), [city_pay], "시내 바퀴 배송 돈 2250")
	check_eq(pays["long"].keys(), [Trip.parcel_pay(bn, s, 0)], "장거리 바퀴 배송 돈 = 장거리 단가")
	check_eq(Trip.parcel_pay(bn, s, 0), 17500 - 3500 - 875, "장거리 단가 17500 → 1건 13125")
	check_eq(houses["city"].back(), 39, "시내 바퀴는 40집까지")
	# 장거리 300초: 집 k 끝 = 10 + 400 × k/21 + 0.5k → 14집 (k=14: 10 + 266.7 + 7 = 283.7, k=15: 303.2)
	check_eq(houses["long"], range(14), "장거리 바퀴 300초에 14집 (집 사이가 김)")
	# 다시 시내로: 이번 장거리 바퀴는 끝까지
	check(Trip.set_route(bn, s, 0, "city"), "시내로 바꾸기")
	check_eq(Trip.route_id(s, 0), "long", "바꾼 바퀴: 아직 장거리")
	Trip.advance(s, bn, 0, Trip.lap_seconds_left(bn, s, 0) + 1.0, rng)
	check_eq([Trip.route_id(s, 0), Trip.lap_cargo(bn, s, 0), s.long_laps], ["city", 40, 1], "다음 바퀴: 시내 40집")


## 장거리 한 바퀴 시간·수입·경험치: +10 = 싣기 10 + 도로 60000칸 ÷ 150 + 20집 × 0.5 = 420초. 경험치 30/건 (내 트럭만)
func test_long_lap_numbers() -> void:
	var s := _game([10, 10], true)
	for i in 2:
		s.truck(i).route = "long"   # 스위치도 장거리 (첫 진행에서 바퀴를 새로 출발해도 장거리)
		s.truck(i).lap_route = "long"
	check_eq(Trip.route_id(s, 0), "long", "route_id")
	check_near(Trip.lap_seconds(b, s, 0), 10.0 + 400.0 + 10.0, 1e-9, "+10 장거리 한 바퀴 420초")
	check_near(Trip.avg_lap_seconds(b, s, 0), 420.0, 1e-9, "평균 한 바퀴")
	check_eq([Trip.cargo(b, s, 0), Trip.lap_cargo(b, s, 0)], [20.0, 20], "20집")
	check_eq([Trip.parcel_pay(b, s, 0), Trip.tip_pay(b, s, 0), Trip.lap_income(b, s, 0)], [13125, 17500, 262500], "1건 13125, 팁 17500, 한 바퀴 26.25만")
	check_near(Trip.hourly_income(b, s, 0), 20 * (13125 + 0.02 * 17500) * 3600.0 / 420.0, 1e-6, "시간당 = 20 × 13475 × 3600 ÷ 420 = 231만")
	check_near(Trip.hourly_income(b, s, 1), Trip.hourly_income(b, s, 0), 1e-6, "보조 트럭도 같은 번 돈")
	check_near(Trip.hourly_net(b, s, 1), 20 * ((13125 - 3938 - 394) + 0.02 * (17500 - 5250 - 525)) * 3600.0 / 420.0, 1e-6,
			"보조 트럭 내 돈 = 직원 몫 30%·세금 3% 뗀 1건·팁 (3937.5·393.75는 반올림)")
	# 경험치: 만렙이면 평판으로 그대로 → 한 바퀴 20건 × 30
	s.driver_level = Driver.max_level(b)
	var rng := _rng(2)
	var rep0 := s.reputation
	var n0 := 0
	for e in Trip.advance(s, bn, 0, 420.0 - 0.001, rng):   # 바퀴 끝 직전 (20집 다 배송)
		n0 += 1 if e["type"] == "parcel" else 0
	check_eq([n0, s.reputation - rep0], [20, 600], "내 트럭 장거리 20건 → 경험치 600")
	var rep1 := s.reputation
	Trip.advance(s, bn, 1, 420.0 - 0.001, rng)
	check_eq(s.reputation, rep1, "보조 트럭 장거리 배송은 경험치 0")
	note("+10 장거리 한 바퀴 420초, 시간당 번 돈 %d (시내 %d) — 단가 ×7 (v7b C4)" % [floori(Trip.hourly_income(b, s, 0)),
			floori(Trip.hourly_income_on(b, _game([10], true), 0, "city"))])


## 1시간 켜 둔 장거리: 배송 수·돈이 평균과 맞음
func test_long_hour() -> void:
	var s := _game([20], true)
	Trip.set_route(bn, s, 0, "long")
	var rng := _rng(3)
	var parcels := 0
	var gross := 0
	for k in 3600 * 10:
		for e in Trip.advance(s, bn, 0, 0.1, rng):
			if e["type"] == "parcel":
				parcels += 1
				gross += e["gross"]
	var per_hour := 20.0 * 3600.0 / Trip.avg_lap_seconds(bn, s, 0)
	check(absf(parcels - per_hour) <= 20.0, "1시간 배송 %d건 ≈ 평균 %.1f건 (한 바퀴 안쪽)" % [parcels, per_hour])
	check_eq(gross, parcels * Trip.parcel_pay(bn, s, 0), "배송 돈 = 건수 × 장거리 1건")
	check_eq(s.long_laps, ceili(parcels / 20.0), "장거리로 출발한 바퀴 수")
	note("+20 장거리 1시간: %d건 (평균 %.1f), 번 돈 %d, %d바퀴" % [parcels, per_hour, gross, s.long_laps])


## 터보 장거리 속도는 장거리 바퀴에서만 이동 속도 %에 더함. 터보 이동 속도(공용)는 어디서나
func test_turbo_long_only() -> void:
	var s := _game([10], true)
	var turbo := s.truck(0).part("turbo")
	turbo["grade"] = 4
	turbo["lines"] = ["long_speed"]   # 30%
	var plain := _game([10], true)
	check_near(Trip.lap_seconds(b, s, 0), Trip.lap_seconds(b, plain, 0), 1e-9, "시내: 장거리 속도 효과 없음")
	check_near(Trip.hourly_income(b, s, 0), Trip.hourly_income(b, plain, 0), 1e-6, "시내 시간당 그대로")
	s.truck(0).lap_route = "long"
	check_near(Trip.lap_seconds(b, s, 0), 10.0 + 60000.0 / (150.0 * 1.3) + 10.0, 1e-9, "장거리: 속도 150 × (1 + 0.3)")
	check_near(Trip.hourly_income_on(b, s, 0, "long"), 20 * 13475 * 3600.0 / (20.0 + 60000.0 / 195.0), 1e-6, "장거리 시간당")
	turbo["lines"] = ["long_speed", "speed", "long_speed"]   # 장거리 30 + 30, 이동 속도 20 (+ 다른 부품 이동 속도도 더함)
	s.truck(0).part("ecu")["lines"] = ["speed"]   # 순정 3%
	check_near(Trip.lap_seconds(b, s, 0), 20.0 + 60000.0 / (150.0 * (1.0 + 0.6 + 0.2 + 0.03)), 1e-9, "장거리: %끼리 더함 (1 + 0.6 + 0.2 + 0.03)")
	s.truck(0).lap_route = ""
	check_near(Trip.lap_seconds(b, s, 0), 40.0 + 4800.0 / (150.0 * 1.23), 1e-9, "시내: 이동 속도 20% + 3%만")


## 스위치 옆 비교 표시: hourly_income_on은 상태를 안 바꿈. 이번 바퀴 남은 초
func test_hourly_on_and_left() -> void:
	var s := _game([10], true)
	var city := Trip.hourly_income(b, s, 0)
	check_near(Trip.hourly_income_on(b, s, 0, "city"), city, 1e-6, "시내 바퀴에서 시내 = hourly_income")
	check_near(Trip.hourly_income_on(b, s, 0, "long"), 2310000.0, 1e-6, "장거리 231만 (20 × 13475 × 3600 ÷ 420)")
	check_eq([s.truck(0).lap_route, Trip.route_id(s, 0)], ["", "city"], "물어봐도 이번 바퀴 그대로")
	s.truck(0).lap_route = "long"
	check_near(Trip.hourly_income_on(b, s, 0, "city"), city, 1e-6, "장거리 바퀴에서 물어본 시내")
	check_eq(s.truck(0).lap_route, "long", "장거리 바퀴 그대로")
	s.truck(0).lap_clock = 100.0
	check_near(Trip.lap_seconds_left(b, s, 0), 320.0, 1e-9, "420초 중 100초 → 남은 320초")
	s.truck(0).lap_clock = 500.0
	check_eq(Trip.lap_seconds_left(b, s, 0), 0.0, "넘으면 0")


## 꺼둔 동안: 트럭마다 스위치 노선 숫자로 (이번 바퀴가 시내였어도). 이번 바퀴 노선·진행은 그대로
func test_offline() -> void:
	var s := _game([10, 10], true)
	s.ability_points = 20
	for k in 20:
		Ability.add(b, s, "knowhow")   # 노하우 50% → 꺼둔 동안 경험치
	Trip.set_route(b, s, 0, "long")   # 트럭 0: 장거리 (이번 바퀴는 시내), 트럭 1: 시내
	var want0 := Trip.hourly_income_on(b, s, 0, "long")
	var want1 := Trip.hourly_income(b, s, 1)
	var r := Trip.apply_offline(s, b, 3 * 3600.0)   # 창고 4시간 안, 야간팀 50%
	check_eq(s.today_sales, floori(want0 * 3.0 * 0.5) + floori(want1 * 3.0 * 0.5), "번 돈 = 장거리 시간당 × 3 × 0.5 + 시내 트럭")
	var n0 := floori(20 * 3600.0 / 420.0 * 3.0 * 0.5)
	var n1 := floori(40 * 3600.0 / 72.0 * 3.0 * 0.5)
	check_eq(r["parcels"], n0 + n1, "배송 = 장거리 %d + 시내 %d" % [n0, n1])
	check_eq(r["xp"], floori(n0 * 30 * 0.5), "경험치 = 장거리 배송 × 30 × 노하우 50%")
	check_eq([s.truck(0).lap_route, s.truck(0).route, s.long_laps], ["", "long", 0], "이번 바퀴 노선 그대로, 장거리 바퀴 수는 켜 둔 동안만")
	# +9 트럭은 스위치가 장거리여도(손으로 고친 값) 시내로
	var g := _game([9], true)
	g.truck(0).route = "long"
	var hg := Trip.hourly_income(b, g, 0)
	Trip.apply_offline(g, b, 3 * 3600.0)
	check_eq(g.today_sales, floori(hg * 3.0 * 0.5), "+9 트럭은 시내로 계산")


## 장거리 열림 알림: 대리점 + 어느 트럭이 처음 +10 → 한 번만
func test_long_unlocked_event() -> void:
	var s := _game([10, 5], false)
	var rng := _rng(4)
	Trip.advance(s, b, 0, 1.0, rng)
	check(not s.take_events().any(func(e): return e["type"] == "long_unlocked"), "개인 기사인데 장거리 열림 알림")
	s.company_stage = GameState.AGENCY
	Trip.advance(s, b, 1, 1.0, rng)   # +5 보조 트럭 진행: 아직
	check(not s.long_unlocked, "+5 트럭 진행에서 열림")
	Trip.advance(s, b, 0, 1.0, rng)
	var ev := s.take_events().filter(func(e): return e["type"] == "long_unlocked")
	check_eq([ev.size(), s.long_unlocked], [1, true], "알림 한 번")
	Trip.advance(s, b, 0, 1.0, rng)
	check(not s.take_events().any(func(e): return e["type"] == "long_unlocked"), "알림이 또 뜸")
	var h := _game([5, 12], true)   # 보조 트럭이 먼저 +10
	Trip.advance(h, b, 1, 1.0, rng)
	check(h.long_unlocked, "보조 트럭 +12 진행에서 안 열림")


## 저장 형식 12: 노선·장거리 칸 왕복, 형식 11은 기본, 못 가는 트럭은 기본으로, 틀린 모양은 깨진 저장
func test_save() -> void:
	var s := _game([12, 10, 9], true)
	s.truck(0).route = "long"
	s.truck(0).lap_route = "long"
	s.truck(1).route = "long"
	s.long_laps = 5
	s.long_unlocked = true
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000)))
	check_eq(d["version"], float(Save.FORMAT_VERSION), "지금 저장 형식")
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽힘 (%s)" % r["error"])
	var got: GameState = r["state"]
	check_eq(got.trucks.map(func(t): return [t.route, t.lap_route]), [["long", "long"], ["long", ""], ["", ""]], "트럭 노선")
	check_eq([got.long_laps, got.long_unlocked, Trip.route_id(got, 0), Trip.route_choice(got, 1)], [5, true, "long", "long"], "장거리 칸")
	var d11 := d.duplicate(true)
	d11["version"] = 11
	for key in ["long_laps", "long_unlocked"]:
		d11.erase(key)
	for td in d11["trucks"]:
		td.erase("route")
		td.erase("lap_route")
	var g11: GameState = Save.from_dict(d11, b)["state"]
	check_eq([g11.trucks.map(func(t): return t.route + t.lap_route), g11.long_laps, g11.long_unlocked], [["", "", ""], 0, false], "형식 11: 기본")
	var dx := d.duplicate(true)
	dx["trucks"][2]["route"] = "long"   # +9 (손으로 고침)
	dx["trucks"][2]["lap_route"] = "long"
	dx["trucks"][1]["route"] = "city"   # 저장 값은 ""/"long"
	dx["long_laps"] = -3
	var gx: GameState = Save.from_dict(dx, b)["state"]
	check_eq([gx.truck(2).route, gx.truck(2).lap_route, gx.truck(1).route, gx.long_laps], ["", "", "", 0], "+9 장거리 → 기본, \"city\" → \"\", 음수 → 0")
	var ds := d.duplicate(true)
	ds["company_stage"] = 0   # 개인 기사면 장거리 없음
	var gs: GameState = Save.from_dict(ds, b)["state"]
	check_eq([gs.truck(0).route, gs.truck(0).lap_route, Trip.route_id(gs, 0)], ["", "", "town"], "개인 기사 → 동네")
	for bad in [["route", 1], ["lap_route", null]]:
		var db := d.duplicate(true)
		db["trucks"][0][bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "trucks[0].%s = %s 를 못 걸러냄" % bad)
	for bad in [["long_laps", "x"], ["long_unlocked", 1]]:
		var db := d.duplicate(true)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)
