## quest.gd: 퀘스트 목록 순서·조건·보상, 조건 기록(배송·세팅·스페어), 새 게임 1시간 (v5)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

var b: Balance = Balance.load_file()

const IDS := ["first_parcel", "parcels_20", "first_enhance", "first_setting", "star_3", "setting_street", "star_5",
		"ecu_first", "warehouse_2", "level_5", "star_8", "setting_sport", "night_2", "star_10", "level_10", "warehouse_3",
		"star_12", "star_15", "level_20", "setting_racing", "first_spare", "star_18"]


func _quest_ids(events: Array) -> Array:
	return events.filter(func(ev): return ev["type"] == "quest_done").map(func(ev): return ev["id"])


## v5 C1 ⑨: 목록 22개, 처음 차례·진행, 조건이 안 찼으면 아무 일 없음
func test_list_and_first() -> void:
	check_eq(Quest.count(b), 22, "퀘스트 수")
	var ids := []
	for q in b.quests:
		ids.append(q["id"])
	check_eq(ids, IDS, "순서")
	var s := GameState.new_game()
	check_eq(Quest.current(b, s)["id"], "first_parcel", "처음 차례")
	check_eq(Quest.progress(b, s), [0, 1], "처음 진행")
	check(not Quest.check(s, b), "조건이 안 찼는데 끝남")
	check_eq([s.quest_index, s.money, s.take_events()], [0, 0, []], "안 끝났는데 상태가 바뀜")
	s.parcels_total = 7
	s.quest_index = 1
	check_eq(Quest.progress(b, s), [7, 20], "parcels_20 진행 7/20")


## v5 C1 ⑨: 조건을 미리 넘긴 퀘스트는 check 한 번에 하나씩, 보상(돈·경험치)은 정확히 한 번, 다 끝나면 {}
func test_all_in_order_one_per_check() -> void:
	var s := GameState.new_game()
	# 22개 조건을 전부 미리 채움
	s.parcels_total = 20
	s.truck(0).star = 18
	s.setting_rolls = 1
	s.truck(0).part("cargo_box")["grade"] = 3
	s.parts_rolled["ecu"] = true
	s.warehouse_level = 3
	s.night_level = 2
	s.driver_level = 20
	s.spares_bought = 1
	var money := 0
	var xp := 0
	for k in 22:
		var q := Quest.current(b, s)
		check_eq(q["id"], IDS[k], "%d번째 차례" % (k + 1))
		check(Quest.check(s, b), "%d번째(%s)가 안 끝남" % [k + 1, IDS[k]])
		check_eq(s.quest_index, k + 1, "%d번째 뒤 번호 (한 번에 하나)" % (k + 1))
		money += q["money"]
		xp += q["xp"]
	check_eq(s.money, money, "보상 돈 합")
	var events := s.take_events()
	check_eq(_quest_ids(events), IDS, "끝난 알림 순서")
	var done: Array = events.filter(func(ev): return ev["type"] == "quest_done")
	check_eq(done[0], { "type": "quest_done", "id": "first_parcel", "xp": 200, "money": 10000 }, "첫 알림 모양")
	check_eq(Quest.current(b, s), {}, "다 끝나면 current {}")
	check_eq(Quest.progress(b, s), [0, 0], "다 끝나면 progress [0, 0]")
	check(not Quest.check(s, b), "다 끝났는데 또 끝남")
	check_eq([s.money, s.quest_index], [money, 22], "다 끝난 뒤 check: 상태 그대로")
	note("22개 보상 합: 경험치 %d, 돈 %d원" % [xp, money])


## v5 C1 ⑨: 종류별 조건 — 차례가 왔을 때 지금 값 ≥ target이면 끝남. 세팅 등급은 고른 뒤에만, 단계는 트럭 중 가장 높은 것
func test_conditions_by_kind() -> void:
	var cases := [   # [차례 번호, 상태를 바꾸는 함수, 바꾸기 전 진행, 바꾼 뒤 진행]
		[0, func(s): s.parcels_total = 1, [0, 1], [1, 1]],
		[2, func(s): s.truck(1).star = 1, [0, 1], [1, 1]],   # 트럭 1이 올라도
		[3, func(s): s.setting_rolls = 1, [0, 1], [1, 1]],
		[7, func(s): s.parts_rolled["ecu"] = true, [0, 1], [1, 1]],
		[8, func(s): s.warehouse_level = 2, [1, 2], [2, 2]],
		[9, func(s): s.driver_level = 5, [1, 5], [5, 5]],
		[12, func(s): s.night_level = 2, [1, 2], [2, 2]],
		[20, func(s): s.spares_bought = 1, [0, 1], [1, 1]],
	]
	for c in cases:
		var s := GameState.new_game()
		s.trucks.append(TruckState.new())
		s.quest_index = c[0]
		var id: String = IDS[c[0]]
		check_eq(Quest.progress(b, s), c[2], "%s 바꾸기 전 진행" % id)
		check(not Quest.check(s, b), "%s: 조건 전에 끝남" % id)
		c[1].call(s)
		check_eq(Quest.progress(b, s), c[3], "%s 바꾼 뒤 진행" % id)
		check(Quest.check(s, b), "%s: 조건이 찼는데 안 끝남" % id)
	# 세팅 등급: 돌려서 등급업이 떠도 고르기 전에는 안 셈
	var s2 := GameState.new_game()
	s2.quest_index = 5   # setting_street
	var p := s2.truck(0).part("cargo_box")
	p["pending"] = { "grade": 1, "lines": ["speed", "speed"] }
	check(not Quest.check(s2, b), "고르기 전 새 상태로 끝남")
	Setting.choose(s2, 0, "cargo_box", true)
	check_eq(Quest.progress(b, s2), [1, 1], "고른 뒤 세팅 등급 진행")
	check(Quest.check(s2, b), "새 것을 골랐는데 안 끝남")


## v5 C1 ⑨: 조건 기록 — 세팅 돌리기(횟수·부품), 스페어 사기, 창고 사기가 퀘스트 값을 올림
func test_condition_sources() -> void:
	var s := GameState.new_game()
	s.money = 1_000_000_000
	s.truck(0).star = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	check(Setting.try_roll(s, b, 0, "ecu", rng)["ok"], "ECU 돌리기")
	check_eq([s.setting_rolls, s.parts_rolled], [1, { "ecu": true }], "돌린 뒤 횟수·부품")
	Setting.choose(s, 0, "ecu", false)
	check(Setting.try_roll(s, b, 0, "cargo_box", rng)["ok"], "적재함 돌리기")
	check_eq([s.setting_rolls, s.parts_rolled.size()], [2, 2], "두 번째 돌린 뒤")
	check_eq(Setting.try_roll(s, b, 0, "cargo_box", rng), { "ok": false }, "고르기 전 막힘")
	check_eq(s.setting_rolls, 2, "막힌 돌리기는 안 셈")
	check(s.buy_spare(b), "스페어 사기")
	check_eq(s.spares_bought, 1, "산 스페어 수")
	s.money = 0
	check(not s.buy_spare(b), "돈 없이 스페어를 삼")
	check_eq(s.spares_bought, 1, "못 산 스페어는 안 셈")


## v5 C1 ⑫: +0 새 게임으로 1초씩 1시간 advance → 레벨·끝난 퀘스트 수 (강화를 안 하면 first_enhance에서 멈춤)
func test_new_game_first_hour() -> void:
	var s := GameState.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var parcels := 0
	var tips := 0
	for k in 3600:
		for ev in Trip.advance(s, b, 0, 1.0, rng):
			if ev["type"] == "parcel":
				parcels += 1
			elif ev["type"] == "tip":
				tips += ev["pay"]
	var events := s.take_events()
	check_eq(_quest_ids(events), ["first_parcel", "parcels_20"], "1시간에 끝난 퀘스트")
	check_eq(Quest.current(b, s)["id"], "first_enhance", "다음 차례")
	var spent := 0
	for lv in range(1, s.driver_level):
		spent += Driver.xp_need(b, lv)
	check_eq(spent + s.driver_xp, parcels * 10 + 200 + 200, "경험치 = 배송 × 10 + 퀘스트 2개 보상")
	check_eq(s.money, parcels * 1875 + tips + 10000 + 20000, "돈 = 배송 돈(1건 1875, 기름값 20%) + 팁 + 퀘스트 보상")
	check_eq(s.parcels_total, parcels, "배송 수")
	note("+0 새 게임 1시간: 배송 %d건, 레벨 %d (경험치 %d/%d), 포인트 %d, 끝난 퀘스트 %d개, 돈 %d원"
			% [parcels, s.driver_level, s.driver_xp, Driver.xp_need(b, s.driver_level), s.ability_points, s.quest_index, s.money])
