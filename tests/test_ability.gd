## ability.gd + 능력치 효과(trip.gd): 찍기·초기화, 상하차·협상·친절(팁)·노하우·정비 지식, 보조 트럭, 시간당 수입 (v5b C1 ①~⑨)
extends "res://tests/test_base.gd"

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## +star 트럭 1대, 포인트 59 (만렙까지 받는 수), 퀘스트는 다 끝낸 상태 (보상 돈이 섞이지 않게).
## picks = { 능력치 id: 찍을 포인트 } → Ability.add로 하나씩 찍음
func _game(star: int, picks: Dictionary = {}) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	s.ability_points = 59
	for id in picks:
		for k in picks[id]:
			check(Ability.add(b, s, id), "%s %d번째 찍기가 막힘" % [id, k + 1])
	return s


## 지금까지 받은 경험치 합 (레벨업에 쓴 것 + 지금 레벨에서 쌓은 것)
func _total_xp(s: GameState) -> int:
	var sum := s.driver_xp
	for lv in range(1, s.driver_level):
		sum += Driver.xp_need(b, lv)
	return sum


func _count(events: Array, type: String) -> int:
	return events.filter(func(e): return e["type"] == type).size()


func _sum(events: Array, type: String) -> int:
	var n := 0
	for e in events:
		if e["type"] == type:
			n += e["pay"]
	return n


## json 값 = 지시서 "옮길 숫자" (스냅샷 6번) + 임시 시작값 (팁)
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(Ability.ids(b), ["unload", "kind", "nego", "knowhow", "mech"] as Array[String], "능력치 id (json 순서)")
	var got := []
	for id in Ability.ids(b):
		got.append([id, b.abilities[id]["per_point"], Ability.max_points(b, id)])
	check_eq(got, [["unload", 0.01, 30], ["kind", 0.005, 30], ["nego", 0.01, 20], ["knowhow", 0.025, 20], ["mech", 0.05, 20]],
			"per_point · max_points (스냅샷 6번)")
	check_eq([b.tip_base_chance, b.tip_rate], [0.02, 1.0], "팁 기본 확률 2%, 팁 = 단가 × 1.0 (임시 시작값)")
	note("능력치 %s, 팁 %s / %s" % [got, b.tip_base_chance, b.tip_rate])


## ① 포인트 59로 120은 못 찍음, 최대 넘게·포인트 없이·모르는 능력치는 false
func test_points_limit() -> void:
	var s := GameState.new_game()
	Driver.add_xp(s, b, 1_000_000_000)   # 만렙까지 받는 포인트 = 59
	check_eq([s.driver_level, s.ability_points], [50, 59], "만렙 포인트")
	var all_max := 0
	for id in Ability.ids(b):
		all_max += Ability.max_points(b, id)
	check_eq(all_max, 120, "다 찍으려면 120")
	var placed := 0
	for id in Ability.ids(b):
		while Ability.add(b, s, id):
			placed += 1
	check_eq(placed, 59, "앞에서부터 다 찍어도 59개만")
	check_eq(Ability.points_left(s), 0, "남은 포인트")
	for id in Ability.ids(b):
		check(not Ability.can_add(b, s, id), "%s: 포인트가 없는데 찍을 수 있음" % id)
	var before := s.abilities.duplicate()
	check(not Ability.add(b, s, "mech"), "포인트 없이 찍힘")
	check_eq(s.abilities, before, "못 찍었는데 바뀜")
	check_eq(s.ability_points, 59, "찍어도 받은 포인트(ability_points)는 그대로")
	# 최대
	var r := GameState.new_game()
	r.ability_points = 100
	for k in 20:
		check(Ability.add(b, r, "nego"), "협상 %d번째가 막힘" % (k + 1))
	check(not Ability.can_add(b, r, "nego"), "협상 최대인데 can_add")
	check(not Ability.add(b, r, "nego"), "협상 21번째가 찍힘")
	check_eq([Ability.points(r, "nego"), Ability.points_left(r)], [20, 80], "협상 20, 남은 80")
	check_near(Ability.value(b, r, "nego"), 0.2, 1e-12, "협상 20 효과")
	# 모르는 능력치, 처음 상태
	check(not Ability.add(b, r, "luck"), "모르는 능력치가 찍힘")
	check_eq(Ability.value(b, r, "luck"), 0.0, "모르는 능력치 효과")
	check(not Ability.add(b, GameState.new_game(), "nego"), "새 게임(포인트 0)에서 찍힘")
	var t := _game(0, { "nego": 7 })
	check_near(Ability.value(b, t, "nego"), 0.07, 1e-12, "협상 7 → 0.07")
	note("59포인트를 앞에서부터: %s" % [s.abilities])


## ② reset 뒤 전부 0, 남은 포인트 = 받은 포인트. 다시 찍을 수 있음
func test_reset() -> void:
	var s := _game(0, { "unload": 30, "kind": 29 })
	check_eq(Ability.points_left(s), 0, "다 찍음")
	Ability.reset(s)
	for id in Ability.ids(b):
		check_eq(Ability.points(s, id), 0, "초기화 뒤 %s" % id)
		check_eq(Ability.value(b, s, id), 0.0, "초기화 뒤 %s 효과" % id)
	check_eq(Ability.points_left(s), s.ability_points, "남은 포인트 = 받은 포인트")
	check_eq(s.ability_points, 59, "받은 포인트 그대로")
	check(Ability.add(b, s, "mech"), "초기화 뒤 다시 찍기")
	Ability.reset(s)
	Ability.reset(s)
	check_eq(Ability.points_left(s), 59, "여러 번 초기화 (무료, 횟수 제한 없음)")


## ③ 상하차 30 → 정차 시간 0.7배, 한 바퀴 초가 그만큼 줆 (advance 집 시각도)
func test_unload() -> void:
	var plain := _game(0)
	var s := _game(0, { "unload": 30 })
	check_near(Trip.lap_seconds(b, plain, 0), 10.0 + 120.0 + 20 * 0.5, 1e-9, "+0 능력치 없음 140초")
	check_near(Trip.lap_seconds(b, s, 0), 10.0 + 120.0 + 20 * 0.35, 1e-9, "상하차 30: 정차 0.5 × 0.7 = 0.35초 → 137초")
	check_near(Trip.lap_seconds(b, plain, 0) - Trip.lap_seconds(b, s, 0), 20 * 0.5 * 0.3, 1e-9, "줄어든 초 = 20집 × 0.15초")
	check_near(Trip.avg_lap_seconds(b, s, 0), 137.0, 1e-9, "평균 한 바퀴도")
	check_near(Trip.hourly_income(b, s, 0) / Trip.hourly_income(b, plain, 0), 140.0 / 137.0, 1e-9, "시간당 = 140 ÷ 137배")
	# advance: 1번째 집 = 10 + 120/21 + 0.35, 137초에 새 바퀴
	var rng := _rng(3)
	s.truck(0).lap_cargo = 20
	var first := 10.0 + 120.0 / 21.0 + 0.35
	check_eq(_count(Trip.advance(s, b, 0, first - 0.01, rng), "parcel"), 0, "1번째 집 시각 전")
	check_eq(_count(Trip.advance(s, b, 0, 0.02, rng), "parcel"), 1, "1번째 집 = 10 + 120 ÷ 21 + 0.35초")
	Trip.advance(s, b, 0, 137.0 - 0.01 - s.truck(0).lap_clock, rng)
	check_eq(s.truck(0).lap_delivered, 20, "137초 직전: 20집 다 배송")
	Trip.advance(s, b, 0, 0.02, rng)
	check_eq(s.truck(0).lap_delivered, 0, "137초: 새 바퀴")
	note("상하차 30: 한 바퀴 %.2f → %.2f초, 시간당 ×%.4f" % [Trip.lap_seconds(b, plain, 0), 137.0, 140.0 / 137.0])


## ④ 협상 20 → 배송 1건 돈 1.2배 (협상 0~20 모두 반올림 1원 안), advance 돈도
func test_nego() -> void:
	var worst := 0.0
	for p in 21:
		var s := _game(0, { "nego": p })
		var pay := Trip.parcel_pay(b, s, 0)
		var want := 1875.0 * (1.0 + 0.01 * p)
		check(absf(pay - want) <= 1.0, "협상 %d: 1건 %d원, 1875 × %.2f = %.2f" % [p, pay, 1.0 + 0.01 * p, want])
		worst = maxf(worst, absf(pay - want))
	var s20 := _game(0, { "nego": 20 })
	check_eq(Trip.parcel_pay(b, s20, 0), 2250, "협상 20: 3000 − 600 − 150 = 2250 = 1875 × 1.2")
	check_eq(Trip.tip_pay(b, s20, 0), 3000, "협상 20: 팁도 단가 3000 × 1.0")
	var ev := Trip.advance(s20, b, 0, 200.0, _rng(4))
	var pays := ev.filter(func(e): return e["type"] == "parcel").map(func(e): return e["pay"])
	check(not pays.is_empty() and pays.all(func(x): return x == 2250), "advance 배송 돈이 2250이 아님: %s" % [pays])
	note("협상 0~20: 1건 돈과 1875 × (1 + 협상) 차이 최대 %.2f원" % worst)


## ⑤ 친절 0 → 팁 확률 2%, 30 → 17%. 10만 건 굴려 1%p 안. 팁 = 협상 적용 단가 × 1.0, 돈에 더해짐, 배송 뒤에 나옴
func test_kind_tips() -> void:
	check_near(Trip.tip_chance(b, _game(0), 0), 0.02, 1e-12, "친절 0 → 2%")
	check_near(Trip.tip_chance(b, _game(0, { "kind": 30 }), 0), 0.17, 1e-12, "친절 30 → 17%")
	for c in [[{}, 0.02, 2500], [{ "kind": 30 }, 0.17, 2500], [{ "kind": 30, "nego": 20 }, 0.17, 3000]]:
		var s := _game(30, c[0])
		var rng := _rng(77)
		var events := []
		var money0 := s.money
		var parcels := 0
		while parcels < 100000:   # 한 바퀴씩 (세는 것은 그 바퀴 이벤트만: 전체를 매번 다시 세면 느림)
			var ev := Trip.advance(s, b, 0, Trip.lap_seconds(b, s, 0), rng)
			parcels += _count(ev, "parcel")
			events.append_array(ev)
		var tips := _count(events, "tip")
		var rate := tips / float(parcels)
		check_near(rate, c[1], 0.01, "%s: 팁 비율 (%d건 중 %d번)" % [c[0], parcels, tips])
		var tip_pays := events.filter(func(e): return e["type"] == "tip").map(func(e): return e["pay"])
		check(tip_pays.all(func(x): return x == c[2]), "%s: 팁이 %d원이 아님" % [c[0], c[2]])
		check_eq(s.money - money0, _sum(events, "parcel") + _sum(events, "tip"), "%s: 늘어난 돈 = 배송 + 팁" % [c[0]])
		var bad_order := 0
		for k in events.size():
			if events[k]["type"] == "tip":
				var j := k - 1
				while j >= 0 and events[j]["type"] == "spare":
					j -= 1
				if j < 0 or events[j]["type"] != "parcel":
					bad_order += 1
		check_eq(bad_order, 0, "%s: 팁 앞이 배송(사이에 스페어만)이 아님" % [c[0]])
		note("%s: 배송 %d건 중 팁 %d번 = %.3f%% (표 %.1f%%), 팁 %d원" % [c[0], parcels, tips, rate * 100.0, c[1] * 100.0, c[2]])


## ⑥ 노하우 0 → 꺼둔 동안 경험치 0, 20 → 켜 둔 것(배송 1건 10)의 50%, 창고 상한까지만, 만렙이면 평판으로
func test_knowhow_offline_xp() -> void:
	var s0 := _game(10)
	var r0 := Trip.apply_offline(s0, b, 3 * 3600.0)
	check(r0["parcels"] > 0, "꺼둔 동안 배송이 없음")
	check_eq([r0["xp"], _total_xp(s0)], [0, 0], "노하우 0: 경험치 0")
	var s := _game(10, { "knowhow": 20 })
	var r := Trip.apply_offline(s, b, 3 * 3600.0)
	check_eq(r["xp"], r["parcels"] * 10 * 20 * 25 / 1000, "노하우 20: 배송 × 10 × 50% (정수 계산)")
	check_eq(_total_xp(s), r["xp"], "받은 경험치가 상태에 들어감 (레벨업 포함)")
	check(s.driver_level > 1, "꺼둔 동안 경험치로 레벨업이 안 됨")
	var s7 := _game(10, { "knowhow": 7 })
	var r7 := Trip.apply_offline(s7, b, 3 * 3600.0)
	check_eq(r7["xp"], r7["parcels"] * 10 * 7 * 25 / 1000, "노하우 7: 배송 × 10 × 17.5% (정수 계산. 실수로 1 모자라지 않음)")
	# 창고 상한 (Lv1 4시간): 20시간 꺼 둬도 4시간치
	var s20 := _game(10, { "knowhow": 20 })
	var r20 := Trip.apply_offline(s20, b, 20 * 3600.0)
	var s4 := _game(10, { "knowhow": 20 })
	var r4 := Trip.apply_offline(s4, b, 4 * 3600.0)
	check_eq([r20["hours"], r20["xp"]], [4.0, r4["xp"]], "20시간 = 창고 4시간치 경험치")
	# 만렙이면 평판으로
	var m := _game(10, { "knowhow": 20 })
	Driver.add_xp(m, b, 1_000_000_000)
	var rep0 := m.reputation
	var rm := Trip.apply_offline(m, b, 3 * 3600.0)
	check_eq([m.driver_level, m.driver_xp, m.reputation - rep0], [50, 0, rm["xp"]], "만렙: 경험치는 평판으로")
	note("+10 3시간 꺼둠: 배송 %d건, 노하우 20 경험치 %d (켜 둔 동안이면 %d)" % [r["parcels"], r["xp"], r["parcels"] * 10])


## ⑦ 정비 지식 20 → 드랍 기대값 2배 (켜 둔 동안 10만 건 굴림, 꺼둔 동안 소수 나머지)
func test_mech_drop() -> void:
	check_near(Trip.spare_chance(b, _game(0), 0), 0.00005, 1e-15, "정비 지식 0 = spare_drop_chance")
	check_near(Trip.spare_chance(b, _game(0, { "mech": 20 }), 0), 0.0001, 1e-15, "정비 지식 20 → 2배")
	check_near(Trip.spare_chance(b, _game(0, { "mech": 7 }), 0), 0.00005 * 1.35, 1e-15, "정비 지식 7 → 1.35배")
	# 켜 둔 동안: 확률을 0.01로 키운 balance로 10만 건
	var d := real_balance_dict()
	d["engine"]["spare_drop_chance"] = 0.01
	var b1: Balance = Balance.from_dict(d)
	var rates := []
	for picks in [{}, { "mech": 20 }]:
		var s := _game(30)
		for id in picks:
			s.abilities[id] = picks[id]
		var rng := _rng(5)
		var parcels := 0
		var spares := 0
		while parcels < 100000:
			var ev := Trip.advance(s, b1, 0, Trip.lap_seconds(b1, s, 0), rng)
			parcels += _count(ev, "parcel")
			spares += _count(ev, "spare")
		rates.append(spares / float(parcels))
	check_near(rates[0], 0.01, 0.002, "정비 지식 0: 켜 둔 동안 드랍률")
	check_near(rates[1], 0.02, 0.002, "정비 지식 20: 켜 둔 동안 드랍률")
	check_near(rates[1] / rates[0], 2.0, 0.15, "켜 둔 동안 2배")
	# 꺼둔 동안: 소수 나머지에 배송 × 확률 × 2
	var o0 := _game(10)
	var ro := Trip.apply_offline(o0, b, 3 * 3600.0)
	var o20 := _game(10, { "mech": 20 })
	var r20 := Trip.apply_offline(o20, b, 3 * 3600.0)
	check_eq(r20["parcels"], ro["parcels"], "정비 지식은 배송 수를 안 바꿈")
	check_near(o0.spare_drop_carry, ro["parcels"] * 0.00005, 1e-12, "꺼둔 동안 정비 지식 0")
	check_near(o20.spare_drop_carry, ro["parcels"] * 0.0001, 1e-12, "꺼둔 동안 정비 지식 20 = 2배")
	note("켜 둔 동안 10만 건 드랍률 %.4f → %.4f (×%.3f), 꺼둔 3시간 소수 나머지 %.4f → %.4f"
			% [rates[0], rates[1], rates[1] / rates[0], o0.spare_drop_carry, o20.spare_drop_carry])


## ⑧ 트럭 1(보조)에는 능력치가 안 들어감 (단가·팁·정차·드랍·시간당·꺼둔 동안 경험치)
func test_helper_truck_no_abilities() -> void:
	for picks in [{ "nego": 20, "kind": 30, "unload": 9 }, { "knowhow": 20, "mech": 20, "unload": 19 }]:
		var s := _game(10, picks)
		s.trucks.append(TruckState.new())
		s.truck(1).star = 10
		var plain := _game(10)   # 능력치 없는 같은 트럭
		check_eq(Trip.parcel_pay(b, s, 1), Trip.parcel_pay(b, plain, 0), "%s: 트럭 1 배송 1건" % [picks])
		check_eq([Trip.tip_chance(b, s, 1), Trip.tip_pay(b, s, 1)], [0.02, 2500], "%s: 트럭 1 팁 (기본만)" % [picks])
		check_near(Trip.lap_seconds(b, s, 1), Trip.lap_seconds(b, plain, 0), 1e-9, "%s: 트럭 1 한 바퀴" % [picks])
		check_eq(Trip.spare_chance(b, s, 1), b.spare_drop_chance, "%s: 트럭 1 드랍" % [picks])
		check_near(Trip.hourly_income(b, s, 1), Trip.hourly_income(b, plain, 0), 1e-9, "%s: 트럭 1 시간당" % [picks])
		check(Trip.hourly_income(b, s, 0) > Trip.hourly_income(b, s, 1) or picks.has("knowhow"), "%s: 트럭 0에는 들어가야 함" % [picks])
	# advance 트럭 1: 배송 1875, 팁 2500
	var s2 := _game(10, { "nego": 20, "kind": 30 })
	s2.trucks.append(TruckState.new())
	var ev := Trip.advance(s2, b, 1, 3600.0, _rng(9))
	var pays := ev.filter(func(e): return e["type"] == "parcel").map(func(e): return e["pay"])
	var tips := ev.filter(func(e): return e["type"] == "tip").map(func(e): return e["pay"])
	check(pays.all(func(x): return x == 1875) and tips.all(func(x): return x == 2500), "트럭 1 advance에 협상이 들어감")
	check(_count(ev, "tip") < _count(ev, "parcel") * 0.06, "트럭 1 팁 비율이 친절(17%%)을 따름: %d / %d" % [_count(ev, "tip"), _count(ev, "parcel")])
	# 꺼둔 동안 경험치는 트럭 0 배송만
	var k := _game(10, { "knowhow": 20 })
	k.trucks.append(TruckState.new())
	k.truck(1).star = 10
	var r := Trip.apply_offline(k, b, 3 * 3600.0)
	var p0 := floori(Trip.cargo(b, k.truck(0)) * 3600.0 / Trip.avg_lap_seconds(b, k, 0) * 3.0 * 0.5)
	check_eq(r["xp"], p0 * 5, "트럭 2대: 경험치는 트럭 0 배송(%d건)만, 전체 %d건" % [p0, r["parcels"]])
	check(r["parcels"] > p0, "트럭 1 배송이 꺼둔 동안에 없음")


## ⑨ 시간당 수입(화면이 읽는 Trip.hourly_income)이 능력치 포함 advance 50시간 돈과 1% 안
func test_hourly_matches_long_run() -> void:
	for picks in [{ "nego": 20, "kind": 30, "unload": 9 }, { "unload": 30, "nego": 20, "kind": 9 }, { "knowhow": 20, "mech": 20, "nego": 19 }]:
		for star in [10, 18]:
			var s := _game(star, picks)
			var hourly := Trip.hourly_income(b, s, 0)
			Trip.advance(s, b, 0, 50 * 3600.0, _rng(31))
			var gap := absf(s.money / 50.0 - hourly) / hourly
			check(gap <= 0.01, "%s +%d: 50시간의 시간당 %.1f / hourly_income %.1f (차이 %.2f%%)" % [picks, star, s.money / 50.0, hourly, gap * 100.0])
			note("%s +%d: hourly_income %.1f원 (능력치 없으면 %.1f), advance 50시간의 시간당 %.1f원 (차이 %.2f%%)"
					% [picks, star, hourly, Trip.hourly_income(b, _game(star), 0), s.money / 50.0, gap * 100.0])


## 능력치·팁 숫자 검사: 빠진 능력치, 모르는 능력치, 음수, 정수 아닌 최대, 정차가 0 아래, 팁 확률 1 넘음
func test_bad_ability_numbers() -> void:
	var cases := [
		[func(d): d["abilities"].erase("mech"), "abilities.mech 이 없거나"],
		[func(d): d["abilities"]["luck"] = { "per_point": 0.01, "max_points": 5 }, "모르는 능력치: luck"],
		[func(d): d["abilities"]["nego"]["per_point"] = -0.01, "abilities.nego.per_point = -0.01"],
		[func(d): d["abilities"]["kind"]["max_points"] = 2.5, "abilities.kind.max_points = 2.5"],
		[func(d): d["abilities"]["unload"]["per_point"] = 0.04, "abilities.unload: per_point × max_points"],
		[func(d): d["abilities"]["kind"]["per_point"] = 0.05, "abilities.kind: trip.tip_base_chance + per_point × max_points"],
		[func(d): d["trip"]["tip_base_chance"] = 1.5, "trip.tip_base_chance = 1.5"],
		[func(d): d["trip"]["tip_rate"] = -1, "trip.tip_rate = -1"],
		[func(d): d.erase("abilities"), "\"abilities\" 묶음이 없음"],
	]
	var found := PackedStringArray()
	for c in cases:
		var d := real_balance_dict()
		c[0].call(d)
		var bad: Balance = Balance.from_dict(d)
		var hit := false
		for e in bad.errors:
			if e.contains(c[1]):
				hit = true
				found.append(e)
		check(hit, "못 찾음: %s (찾은 것: %s)" % [c[1], ", ".join(bad.errors)])
	note("찾은 문제: %s" % " / ".join(found))
