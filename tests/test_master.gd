## v6b C2: 명장 방문일 (master.gd), 보험·보너스 (enhance.gd·economy.gd·setting.gd·trip.gd), 저장 형식 9
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

const DAY := 86400
## 현지 시각: 2026-11-15 일요일, 11-16 월요일 0시, 11-23 월요일 0시
const SUN_1115 := 1794700800
const MON_1116 := 1794787200
const MON_1123 := 1795392000
const WED_1118 := MON_1116 + 2 * DAY

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 명장이 열린 +star 트럭 1대, 퀘스트 끝, 돈 넉넉
func _game(star: int, money: int = 10 ** 15) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	s.money = money
	s.master_unlocked = true
	s.milestones_done = [10]
	return s


## now에 방문 중인 상태 (오늘 요일을 고르고 tick). bonus를 주면 그 주 보너스를 그것으로
func _visiting(star: int, now: int, bonus: String = "", money: int = 10 ** 15) -> GameState:
	var s := _game(star, money)
	Master.set_day(s, Master.weekday(now), now)
	Master.tick(s, b, now, _rng(1))
	if bonus != "":
		s.master_bonus = bonus
		Master.tick(s, b, now, _rng(1))
	s.take_events()
	return s


func _balance_with(engine: Dictionary) -> Balance:
	var d := real_balance_dict()
	for k in engine:
		d["engine"][k] = engine[k]
	var bal: Balance = Balance.from_dict(d)
	assert(bal.is_ok(), ", ".join(bal.errors))
	return bal


## 늘 성공하는 balance (퍼짐 0: 성공 + 퍼짐 ≤ 1 검사를 지키게)
func _always_win() -> Balance:
	var ones := []
	ones.resize(30)
	ones.fill(1.0)
	var zeros := []
	zeros.resize(30)
	zeros.fill(0.0)
	return _balance_with({ "success": ones, "destroy": zeros })


func _events(s: GameState, type: String) -> Array:
	return s.take_events().filter(func(e): return e["type"] == type)


## json "master" = 지시서 "옮길 숫자"
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq([b.master_unlock_star, b.master_insure_fee_mult], [10, 2.0], "열리는 단계 +10, 보험 추가 요금 ×2")
	check_eq(b.master_bonuses, { "destroy_cut": 0.3, "enhance_discount": 0.2, "setting_up_mult": 1.5, "success_mult": 1.2, "spare_mult": 2.0,
			"setting_discount": 0.2, "double_step": 0.1 }, "보너스 7개")
	check_eq(b.master_bonus_ids.size(), 7, "보너스 id 7개 (json 순서)")


## ① 주 번호·요일이 월요일 0시에 바뀜 (현지 시각 몇 개로)
func test_week_and_weekday() -> void:
	var names := []
	for k in 8:
		names.append(Master.weekday(MON_1116 + k * DAY + 3600))
	check_eq(names, [0, 1, 2, 3, 4, 5, 6, 0], "월 1시부터 8일: 월~일, 월")
	check_eq([Master.weekday(MON_1116 - 1), Master.weekday(MON_1116)], [6, 0], "일 23:59:59 → 월 0:00:00")
	check_eq(Master.week_index(MON_1116) - Master.week_index(MON_1116 - 1), 1, "월요일 0시에 주 +1")
	check_eq(Master.week_index(MON_1123 - 1), Master.week_index(MON_1116), "월 0시 ~ 일 24시 같은 주")
	check_eq(Master.week_index(MON_1123 + 7 * DAY) - Master.week_index(MON_1116), 2, "2주 뒤")
	check_eq([Master.weekday(SUN_1115 + 12 * 3600), Master.week_index(SUN_1115 + 12 * 3600)], [6, Master.week_index(MON_1116) - 1], "일요일 정오")


## ② +10 전에는 잠김, 첫 달성 때 master_unlocked 한 번 (강화 성공으로, 옛 저장은 tick으로)
func test_unlock() -> void:
	var s := GameState.new_game()
	s.truck(0).star = 9
	s.money = 10 ** 12
	s.quest_index = Quest.count(b)
	Master.tick(s, b, WED_1118, _rng(2))
	check(not Master.is_unlocked(s), "+9인데 열림")
	Master.set_day(s, 2, WED_1118)
	check_eq([Master.chosen_day(s), Master.is_visiting(s, WED_1118), s.active_bonus, Master.week_bonus(s)], [-1, false, "", ""], "잠겼을 때: 요일 못 고름, 방문 없음")
	check(not Enhance.can_insure(s, WED_1118), "잠겼고 쿠폰 없는데 보험 가능")
	var b1 := _always_win()
	s.take_events()
	var r := Enhance.try_enhance(s, b1, 0, _rng(2))
	check_eq([r["result"], s.truck(0).star], [Enhance.Result.SUCCESS, 10], "+9 → +10")
	check_eq(_events(s, "master_unlocked").size(), 1, "+10 첫 달성: master_unlocked 한 번")
	check(Master.is_unlocked(s), "+10인데 안 열림")
	Enhance.try_enhance(s, b1, 0, _rng(3))
	Master.tick(s, b, WED_1118, _rng(3))
	check_eq(_events(s, "master_unlocked").size(), 0, "두 번째 알림")
	# v6b 전 저장 (+12인데 안 열림) → tick이 열고 한 번 알림
	var old := GameState.new_game()
	old.truck(0).star = 12
	Master.tick(old, b, WED_1118, _rng(4))
	Master.tick(old, b, WED_1118 + 60, _rng(4))
	check_eq([Master.is_unlocked(old), _events(old, "master_unlocked").size()], [true, 1], "옛 저장 +12: tick에서 열림, 알림 한 번")
	# 퍼져서 +15 아래로 내려가도 열림은 그대로 (강화 첫 달성 기록)
	var down := GameState.new_game()
	down.milestones_done = [10, 15]
	Master.tick(down, b, WED_1118, _rng(5))
	check(Master.is_unlocked(down), "+10 달성 기록이 있는데 안 열림")


## ③ 처음 고르면 이번 주부터, 바꾸면 다음 주부터 (지금 요일을 다시 고르면 취소)
func test_choose_day() -> void:
	var s := _game(10)
	Master.tick(s, b, MON_1116 + 3600, _rng(6))
	Master.set_day(s, 2, MON_1116 + 3600)   # 월요일에 수요일을 처음 고름
	check_eq([Master.chosen_day(s), Master.pending_day(s)], [2, -1], "처음: 이번 주부터")
	check(Master.is_visiting(s, WED_1118 + 3600), "이번 주 수요일 방문")
	Master.set_day(s, 4, WED_1118 + 7200)   # 수요일에 금요일로 바꿈
	check_eq([Master.chosen_day(s), Master.pending_day(s)], [2, 4], "바꾸면 다음 주부터 (이번 주는 그대로 수요일)")
	check(Master.is_visiting(s, WED_1118 + 7200), "바꾼 날에도 이번 주 수요일은 그대로 방문")
	check(not Master.is_visiting(s, WED_1118 + 2 * DAY), "이번 주 금요일은 방문 아님")
	check(not Master.is_visiting(s, WED_1118 + 7 * DAY), "다음 주 수요일은 방문 아님")
	check(Master.is_visiting(s, WED_1118 + 9 * DAY), "다음 주 금요일 방문 (tick 전에도)")
	Master.tick(s, b, MON_1123 + 60, _rng(6))
	check_eq([Master.chosen_day(s), Master.pending_day(s)], [4, -1], "다음 주 월요일 tick: 금요일 적용")
	Master.set_day(s, 1, MON_1123 + 120)
	Master.set_day(s, 4, MON_1123 + 180)
	check_eq([Master.chosen_day(s), Master.pending_day(s)], [4, -1], "지금 요일을 다시 고르면 바꾸기 취소")
	# 처음 고른 요일이 이번 주에 이미 지났으면 이번 주는 없음
	var late := _game(10)
	var thu := MON_1116 + 3 * DAY + 3600
	Master.tick(late, b, thu, _rng(7))
	Master.set_day(late, 0, thu)
	check_eq([Master.chosen_day(late), Master.is_visiting(late, thu)], [0, false], "목요일에 월요일을 고름: 이번 주 없음")
	check(Master.is_visiting(late, MON_1123 + 3600), "다음 주 월요일 방문")
	Master.set_day(late, 9, thu)
	check_eq(Master.chosen_day(late), 0, "0~6 밖은 무시")


## ④ 방문일 0~24시만 방문 중, 전날 예고 한 번, 예고 보너스 = 방문일 보너스 (월요일 방문은 일요일 예고: 다음 주 보너스를 미리)
func test_visit_and_notice() -> void:
	var s := _game(10)
	Master.tick(s, b, MON_1116 + 60, _rng(8))
	Master.set_day(s, 2, MON_1116 + 60)
	check_eq([Master.is_visiting(s, WED_1118 - 1), Master.is_visiting(s, WED_1118), Master.is_visiting(s, WED_1118 + DAY - 1),
			Master.is_visiting(s, WED_1118 + DAY)], [false, true, true, false], "화 23:59:59 아님, 수 0:00:00·23:59:59 방문, 목 0시 아님")
	s.take_events()
	Master.tick(s, b, WED_1118 - DAY + 10 * 3600, _rng(8))   # 화요일 10시
	var notice := _events(s, "master_notice")
	check_eq(notice.size(), 1, "전날 예고 한 번")
	Master.tick(s, b, WED_1118 - DAY + 20 * 3600, _rng(8))
	check_eq(_events(s, "master_notice").size(), 0, "같은 날 예고 두 번")
	check_eq(s.active_bonus, "", "화요일: 보너스 적용 안 됨")
	Master.tick(s, b, WED_1118 + 1800, _rng(8))
	var visit := _events(s, "master_visit")
	check_eq(visit.size(), 1, "방문일 처음 tick: 방문 알림")
	if notice.size() == 1 and visit.size() == 1:
		check_eq(visit[0]["bonus"], notice[0]["bonus"], "예고 보너스 = 방문일 보너스")
		check_eq([s.active_bonus, Master.week_bonus(s)], [notice[0]["bonus"], notice[0]["bonus"]], "방문 중 active_bonus = 그 주 보너스")
	Master.tick(s, b, WED_1118 + 12 * 3600, _rng(8))
	check_eq(_events(s, "master_visit").size(), 0, "같은 날 방문 알림 두 번")
	Master.tick(s, b, WED_1118 + DAY + 60, _rng(8))
	check_eq(s.active_bonus, "", "목요일: 보너스 끝")
	# 월요일 방문 (일요일 예고 = 다음 주 보너스) 30개 seed
	var same := 0
	var bonuses := {}
	for seed_value in 30:
		var m := _game(10)
		var rng := _rng(100 + seed_value)
		Master.tick(m, b, MON_1116 + 60, rng)
		Master.set_day(m, 0, MON_1116 + 60)   # 이번 주 월요일(오늘) 방문
		m.take_events()
		Master.tick(m, b, MON_1123 - DAY + 9 * 3600, rng)   # 일요일 9시: 다음 주 월요일 예고
		var n := _events(m, "master_notice")
		Master.tick(m, b, MON_1123 + 8 * 3600, rng)   # 다음 주 월요일: 새 주 + 방문
		var v := _events(m, "master_visit")
		if n.size() == 1 and v.size() == 1 and n[0]["bonus"] == v[0]["bonus"] and m.active_bonus == v[0]["bonus"]:
			same += 1
		if v.size() == 1:
			bonuses[v[0]["bonus"]] = true
	check_eq(same, 30, "월요일 방문: 일요일 예고 보너스 = 월요일 방문 보너스 (30번 중)")
	check(bonuses.size() >= 4, "30주 동안 보너스가 거의 안 바뀜: %s" % [bonuses.keys()])
	# 안 켜면 그 주는 없음: 방문일을 건너뛰고 다음 날 켬 → 방문 알림 없음
	var skip := _game(10)
	Master.tick(skip, b, MON_1116 + 60, _rng(9))
	Master.set_day(skip, 2, MON_1116 + 60)
	skip.take_events()
	Master.tick(skip, b, WED_1118 + DAY + 60, _rng(9))
	check_eq([_events(skip, "master_visit").size(), skip.active_bonus], [0, ""], "방문일에 안 켬: 그 주 방문 없음")
	note("월요일 방문 30주: 예고 = 방문 %d번, 나온 보너스 %s" % [same, bonuses.keys()])


## ⑤ 보너스 7개: 방문 중에만, 수치가 맞음 (많이 굴리는 것은 평균)
func test_bonuses() -> void:
	var now := WED_1118 + 3600
	# 방문 중 아니면 보너스가 있어도 active_bonus ""
	var off := _game(20)
	Master.tick(off, b, MON_1116, _rng(10))
	Master.set_day(off, 4, MON_1116)
	off.master_bonus = "destroy_cut"
	Master.tick(off, b, now, _rng(10))
	check_eq(off.active_bonus, "", "방문일 아님: active_bonus 없음")
	var plain := _game(20)
	# destroy_cut: 퍼짐 × 0.7 (엔진 보호와 곱)
	var dc := _visiting(20, now, "destroy_cut")
	check_eq(dc.active_bonus, "destroy_cut", "방문 중 보너스")
	check_near(Enhance.chances_for(b, dc, 0)["destroy"], 0.04 * 0.7, 1e-12, "퍼짐 감소: +20 4% × 0.7")
	var ecu := dc.truck(0).part("ecu")
	ecu["grade"] = 4
	ecu["lines"] = ["engine_guard", "engine_guard", "engine_guard"]
	check_near(Enhance.chances_for(b, dc, 0)["destroy"], 0.04 * 0.7 * 0.7, 1e-12, "엔진 보호 30%와 곱")
	check_near(Enhance.chances_for(b, plain, 0)["destroy"], 0.04, 1e-12, "보너스 없음 4%")
	# enhance_discount: 비용 × 0.8, 보험 추가 요금도 할인된 비용 × 2
	var ed := _visiting(18, now, "enhance_discount")
	var base18 := Economy.base_enhance_cost(b, 18)
	check_eq(Economy.enhance_cost(b, 18, ed), roundi(base18 * 0.8), "강화 비용 × 0.8")
	check_eq(Enhance.insure_fee(ed, b, 0, now), roundi(base18 * 0.8) * 2, "보험 추가 요금 = 할인된 비용 × 2")
	check_eq(Economy.enhance_cost(b, 18, plain), base18, "보너스 없음: 기본 비용")
	# setting_up_mult: 등급업 × 1.5 (천장 그대로), 10만 번 평균
	var su := _visiting(10, now, "setting_up_mult")
	check_eq([Setting.up_chance(b, 0, su), Setting.up_chance(b, 1, su), Setting.up_chance(b, 3, su), Setting.up_chance(b, 4, su)],
			[0.3 * 1.5, 0.08 * 1.5, 0.003 * 1.5, 0.0], "등급업 × 1.5 (최고 등급 0)")
	check_eq([Setting.ceiling(b, 1), Setting.up_chance(b, 1, plain)], [20, 0.08], "천장 그대로, 보너스 없음 8%")
	var d := real_balance_dict()
	d["setting"]["ceiling"] = [1000000000, 1000000000, 1000000000, 1000000000]
	var bnc: Balance = Balance.from_dict(d)
	var rng := _rng(11)
	var ups := 0
	for k in 100000:
		var p := su.truck(0).part("cargo_box")
		p["grade"] = 1
		p["pending"] = null
		if Setting.try_roll(su, bnc, 0, "cargo_box", rng)["grade_up"]:
			ups += 1
	check_near(ups / 100000.0, 0.12, 0.01, "스트리트 → 스포츠 10만 번 (8% × 1.5)")
	# success_mult: 성공 × 1.2, 성공 + 퍼짐이 1을 넘으면 성공을 자름, 10만 번 평균
	var sm := _visiting(20, now, "success_mult")
	check_near(Enhance.chances_for(b, sm, 0)["success"], 0.36, 1e-12, "+20 성공 30% × 1.2")
	sm.truck(0).star = 0
	check_near(Enhance.chances_for(b, sm, 0)["success"], 1.0, 1e-12, "+0 95% × 1.2 → 1 (퍼짐 0)")
	var succ := b.success.duplicate()
	succ[20] = 0.9
	var b9 := _balance_with({ "success": Array(succ) })
	sm.truck(0).star = 20
	check_near(Enhance.chances_for(b9, sm, 0)["success"], 0.96, 1e-12, "90% × 1.2 = 1.08 → 1 − 퍼짐 4% = 0.96")
	sm.spares = 10 ** 6
	var wins := 0
	var r2 := _rng(12)
	for k in 100000:
		sm.truck(0).star = 20
		if Enhance.try_enhance(sm, b, 0, r2)["result"] == Enhance.Result.SUCCESS:
			wins += 1
	check_near(wins / 100000.0, 0.36, 0.01, "+20 10만 번 성공률 (30% × 1.2)")
	# spare_mult: 드랍 × 2 (정비 지식과 곱, 켜 둔 동안만)
	var sp := _visiting(10, now, "spare_mult")
	check_near(Trip.spare_chance(b, sp, 0), 0.00005 * 2.0, 1e-15, "드랍 × 2")
	sp.abilities["mech"] = 20
	sp.ability_points = 20
	check_near(Trip.spare_chance(b, sp, 0), 0.00005 * 2.0 * 2.0, 1e-15, "정비 지식 20과 곱 (× 4)")
	var carry0 := sp.spare_drop_carry
	var ro := Trip.apply_offline(sp, b, 3 * 3600.0)
	check_near(sp.spare_drop_carry - carry0, ro["parcels"] * 0.00005 * 2.0, 1e-12, "꺼둔 동안은 보너스 없음 (정비 지식만)")
	# setting_discount: 돌리기 비용 × 0.8, 실제로 빠지는 돈도
	var sd := _visiting(10, now, "setting_discount")
	check_eq([Setting.roll_cost(b, 2, sd), Setting.roll_cost(b, 0, sd)], [1280000, 16000], "돌리기 비용 × 0.8")
	var m0 := sd.money
	Setting.try_roll(sd, b, 0, "cargo_box", _rng(13))
	check_eq(m0 - sd.money, 16000, "순정 돌리기에 빠진 돈 = 할인된 비용")
	check_eq(Setting.roll_cost(b, 2, plain), 1600000, "보너스 없음")
	# double_step: 성공의 10%가 한 단계 더 (+30은 안 넘음)
	var bw := _always_win()
	var ds := _visiting(5, now, "double_step")
	var doubles := 0
	var r3 := _rng(14)
	for k in 100000:
		ds.truck(0).star = 5
		var res := Enhance.try_enhance(ds, bw, 0, r3)
		if res["double"]:
			doubles += 1
			if ds.truck(0).star != 7:
				check_eq(ds.truck(0).star, 7, "2단계면 +7")
	check_near(doubles / 100000.0, 0.10, 0.01, "성공 10만 번 중 2단계 비율")
	var top := 0
	for k in 2000:
		ds.truck(0).star = 29
		Enhance.try_enhance(ds, bw, 0, r3)
		top = maxi(top, ds.truck(0).star)
	check_eq(top, 30, "+29에서 2단계여도 +30까지")
	var nd := _game(5)
	var nd_doubles := 0
	for k in 2000:
		nd.truck(0).star = 5
		if Enhance.try_enhance(nd, bw, 0, r3)["double"]:
			nd_doubles += 1
	check_eq(nd_doubles, 0, "보너스 없으면 2단계 없음")
	note("세팅 등급업 1.5배: %d/10만, 성공 1.2배: %d/10만, 2단계: %d/10만" % [ups, wins, doubles])


## ⑥ 보험 추가 요금: 방문 중 = 비용 × 2 (쿠폰 안 줄어듦), 쿠폰이면 0원·쿠폰 −1
func test_insure_fee() -> void:
	var now := WED_1118 + 3600
	var v := _visiting(18, now, "", 10 ** 12)
	v.coupons = 3
	v.active_bonus = ""   # 할인 보너스가 아닌 주로 (그 주 보너스와 상관없이 비용만 봄)
	var cost := Economy.enhance_cost(b, 18, v)
	check_eq(Enhance.insure_fee(v, b, 0, now), cost * 2, "방문 중 추가 요금 = 비용 × 2")
	var m0 := v.money
	Enhance.try_enhance(v, b, 0, _rng(15), true, now)
	check_eq([m0 - v.money, v.coupons], [cost * 3, 3], "방문 중 보험: 비용 + 비용 × 2 빠짐, 쿠폰 그대로")
	var c := _game(18, 10 ** 12)
	c.coupons = 2
	check_eq(Enhance.insure_fee(c, b, 0, now), 0, "방문일 아님: 추가 요금 0 (쿠폰)")
	var c0 := c.money
	Enhance.try_enhance(c, b, 0, _rng(16), true, now)
	check_eq([c0 - c.money, c.coupons], [Economy.enhance_cost(b, 18, c), 1], "쿠폰 보험: 비용만, 쿠폰 −1")


## ⑦ 보험 건 회의 퍼짐 → 실패(단계 유지)·스페어 안 씀·insured true
func test_insured_destroy() -> void:
	var always := real_balance_dict()
	always["engine"]["success"][18] = 0.0
	always["engine"]["destroy"][18] = 1.0
	var bd: Balance = Balance.from_dict(always)
	var s := _game(18, 10 ** 12)
	s.coupons = 1
	s.spares = 2
	var r := Enhance.try_enhance(s, bd, 0, _rng(17), true, WED_1118)
	var t := s.truck(0)
	check_eq([r["result"], r["insured"], t.star, s.spares, t.destroy_count, t.fail_count], [Enhance.Result.FAIL, true, 18, 2, 0, 1],
			"보험: 퍼짐 → 실패, +18 그대로, 스페어 그대로")
	var n := Enhance.try_enhance(s, bd, 0, _rng(17))
	check_eq([n["result"], n["insured"], t.star, s.spares], [Enhance.Result.DESTROY, false, 15, 1], "보험 없으면 퍼짐 → +15, 스페어 −1")
	check_eq(Enhance.chances_for(bd, _game(18), 0, true), { "success": 0.0, "fail": 1.0, "destroy": 0.0 }, "보험 켠 확률: 퍼짐 0, 실패 1")


## ⑧ 보험이면 +18 스페어 0이어도 누를 수 있음, 방문일도 쿠폰도 없으면 보험 못 검
func test_insure_block() -> void:
	var now := WED_1118 + 3600
	var s := _game(18, 10 ** 12)
	s.spares = 0
	s.coupons = 1
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NO_SPARE, "보험 없이 +18 스페어 0")
	check_eq(Enhance.block_reason(s, b, 0, true, now), Enhance.Block.NONE, "쿠폰 보험: 스페어 0이어도 누를 수 있음")
	check_eq(Enhance.try_enhance(s, b, 0, _rng(18), true, now)["result"] != Enhance.Result.BLOCKED, true, "쿠폰 보험으로 눌림")
	var none := _game(18, 10 ** 12)
	none.spares = 0
	var m0 := none.money
	check(not Enhance.can_insure(none, now), "방문도 쿠폰도 없는데 보험 가능")
	check_eq(Enhance.block_reason(none, b, 0, true, now), Enhance.Block.NO_INSURE, "보험 못 검")
	check_eq([Enhance.try_enhance(none, b, 0, _rng(18), true, now)["result"], none.money], [Enhance.Result.BLOCKED, m0], "막혀서 돈 그대로")
	var v := _visiting(18, now, "", 0)
	v.active_bonus = ""
	v.spares = 0
	var cost := Economy.enhance_cost(b, 18, v)
	v.money = cost * 3 - 1
	check_eq(Enhance.block_reason(v, b, 0, true, now), Enhance.Block.NO_MONEY, "방문 중 보험: 비용 × 3에 1원 모자람")
	v.money = cost * 3
	check_eq(Enhance.block_reason(v, b, 0, true, now), Enhance.Block.NONE, "방문 중 보험: 비용 × 3 딱")
	check(Enhance.can_insure(v, now), "방문 중인데 보험 불가")


## ⑨ 화면이 읽는 확률·비용 함수가 보너스·보험을 반영 + "N번 시도 가능" (Economy.tries)이 실제로 누를 수 있는 횟수와 같음
func test_screen_values() -> void:
	var now := WED_1118 + 3600
	var v := _visiting(18, now, "enhance_discount", 0)
	var cost := Economy.enhance_cost(b, 18, v)
	check_eq(cost, roundi(Economy.base_enhance_cost(b, 18) * 0.8), "할인 주 비용")
	v.money = cost - 1
	check_eq(Enhance.block_reason(v, b, 0), Enhance.Block.NO_SPARE, "스페어부터")
	v.spares = 1
	check_eq(Enhance.block_reason(v, b, 0), Enhance.Block.NO_MONEY, "할인된 비용에 1원 모자람")
	v.money = cost
	check_eq(Enhance.block_reason(v, b, 0), Enhance.Block.NONE, "할인된 비용 딱 (기본 비용보다 적음)")
	check_eq(Enhance.chances_for(b, v, 0, true)["destroy"], 0.0, "보험 켠 퍼짐 0")
	# 세팅: 할인된 돈으로 돌릴 수 있음
	var sd := _visiting(10, now, "setting_discount", 16000)
	check_eq(Setting.block_reason(sd, b, 0, "cargo_box"), Setting.Block.NONE, "할인된 돌리기 비용 16000원 딱")
	sd.active_bonus = ""
	check_eq(Setting.block_reason(sd, b, 0, "cargo_box"), Setting.Block.NO_MONEY, "할인 없으면 20000원이라 모자람")
	# tries: 보험 없이 / 방문 중 보험 / 쿠폰 보험 / 둘 다 없음 / 스페어 없음 / +30
	var t := _game(18, 0)
	t.spares = 1
	var c18 := Economy.enhance_cost(b, 18, t)
	t.money = c18 * 7 + 5
	check_eq(Economy.tries(t, b, 0), 7, "보험 없이 7번")
	t.spares = 0
	check_eq(Economy.tries(t, b, 0), 0, "+18 스페어 0 → 0번")
	t.coupons = 3
	check_eq(Economy.tries(t, b, 0, true, now), 3, "쿠폰 보험: 돈은 7번인데 쿠폰 3장")
	t.coupons = 0
	check_eq(Economy.tries(t, b, 0, true, now), 0, "방문·쿠폰 없음 → 0번")
	var tv := _visiting(18, now, "", 0)
	tv.active_bonus = ""
	tv.money = c18 * 3 * 4 + c18 * 2
	check_eq(Economy.tries(tv, b, 0, true, now), 4, "방문 중 보험: 1번 = 비용 × 3")
	tv.truck(0).star = 30
	check_eq(Economy.tries(tv, b, 0, true, now), 0, "+30 → 0번")
	# 실제로 눌러 보기: 늘 실패하는 balance로 BLOCKED까지 → tries와 같음 (방문 중 보험, 할인 주)
	var never := real_balance_dict()
	for k in 30:
		never["engine"]["success"][k] = 0.0
		never["engine"]["destroy"][k] = 0.0
	var bf: Balance = Balance.from_dict(never)
	var p := _visiting(18, now, "enhance_discount", 0)
	p.money = Economy.enhance_cost(bf, 18, p) * 3 * 5 + 777
	var want := Economy.tries(p, bf, 0, true, now)
	var pressed := 0
	while Enhance.try_enhance(p, bf, 0, _rng(19), true, now)["result"] != Enhance.Result.BLOCKED:
		pressed += 1
	check_eq([want, pressed], [5, 5], "N번 시도 가능 = 실제로 누른 횟수 (방문 중 보험·할인 주)")
	var q := _game(12, 0)
	q.money = Economy.enhance_cost(bf, 12, q) * 9
	var want_q := Economy.tries(q, bf, 0)
	var pressed_q := 0
	while Enhance.try_enhance(q, bf, 0, _rng(20))["result"] != Enhance.Result.BLOCKED:
		pressed_q += 1
	check_eq([want_q, pressed_q], [9, 9], "N번 시도 가능 = 실제 (보험 없이)")


## ⑩ 시계가 거꾸로 가도·몇 주를 건너뛰어도 오류 없음 (무작위 시각 2000번, 요일 바꾸기 섞어서)
func test_clock_jumps() -> void:
	var s := _game(10)
	var rng := _rng(21)
	var now := MON_1116
	var bad := 0
	for k in 2000:
		match rng.randi_range(0, 5):
			0: now += rng.randi_range(1, 50) * 7 * DAY        # 몇 주 건너뜀
			1: now -= rng.randi_range(1, 50) * 7 * DAY        # 거꾸로
			2: now += rng.randi_range(0, 3 * DAY)
			3: now -= rng.randi_range(0, 3 * DAY)
			4: Master.set_day(s, rng.randi_range(0, 6), now)
			5: now = int(rng.randf_range(-1.0e9, 4.0e9))   # 1938년 ~ 2096년
		Master.tick(s, b, now, rng)
		s.take_events()
		var ok: bool = s.master_day >= -1 and s.master_day <= 6 and s.master_next_day >= -1 and s.master_next_day <= 6
		ok = ok and (s.active_bonus == "" or b.master_bonuses.has(s.active_bonus)) and b.master_bonuses.has(s.master_bonus)
		ok = ok and (s.active_bonus != "") == Master.is_visiting(s, now) and Master.week_index(now) == s.weekly_week
		if not ok:
			bad += 1
	check_eq(bad, 0, "2000번 중 상태가 이상한 번")


## ⑪ 저장 → 읽기 같음 (active_bonus는 저장 안 함), 옛 형식(8) 읽힘, 범위 밖은 자름, 틀린 모양은 깨짐
func test_save_v9() -> void:
	var s := _game(18)
	Master.tick(s, b, MON_1116, _rng(22))
	Master.set_day(s, 2, MON_1116)
	Master.set_day(s, 5, MON_1116)
	Master.tick(s, b, WED_1118, _rng(22))
	check(s.active_bonus != "", "방문 중인데 보너스 없음")
	var keys := ["master_unlocked", "master_day", "master_next_day", "master_week", "master_bonus", "master_bonus_week",
			"master_next_bonus", "master_notice_week", "master_visit_week"]
	var want := []
	for k in keys:
		want.append(s.get(k))
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	if r["state"] != null:
		var got := []
		for k in keys:
			got.append(r["state"].get(k))
		check_eq(got, want, "형식 9 칸")
		check_eq(r["state"].active_bonus, "", "active_bonus는 저장 안 함")
		Master.tick(r["state"], b, WED_1118 + 60, _rng(23))
		check_eq(r["state"].active_bonus, s.active_bonus, "다시 켜고 tick: 같은 보너스")
	# 형식 8: 칸 없음 → 처음 값 (+18이면 다음 tick에서 열림)
	var d8 := Save.to_dict(_game(18), 1794000000)
	d8["version"] = 8
	for k in keys:
		d8.erase(k)
	var r8 := Save.from_dict(d8, b)
	check_eq(r8["status"], Save.Status.OK, "형식 8 읽기 (%s)" % r8["error"])
	if r8["state"] != null:
		check_eq([r8["state"].master_unlocked, r8["state"].master_day, r8["state"].master_bonus], [false, -1, ""], "형식 8: 명장 처음 값")
		Master.tick(r8["state"], b, WED_1118, _rng(24))
		check(r8["state"].master_unlocked, "형식 8 +18: tick에서 열림")
	# 범위 밖·모르는 보너스
	var dc := Save.to_dict(_game(18), 1794000000)
	dc["master_day"] = 9
	dc["master_next_day"] = -5
	dc["master_bonus"] = "luck"
	var rc := Save.from_dict(dc, b)
	if rc["state"] != null:
		check_eq([rc["state"].master_day, rc["state"].master_next_day, rc["state"].master_bonus], [6, -1, ""], "요일 9 → 6, −5 → −1, 모르는 보너스 → \"\"")
	for bad in [["master_unlocked", 1], ["master_day", "수요일"], ["master_bonus", 3]]:
		var db := Save.to_dict(_game(18), 1794000000)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)


## master 숫자 검사
func test_bad_numbers() -> void:
	var cases := [
		[func(d): d["master"]["bonuses"].erase("double_step"), "master.bonuses.double_step 이 없음"],
		[func(d): d["master"]["bonuses"]["luck"] = 0.5, "모르는 보너스: luck"],
		[func(d): d["master"]["bonuses"]["enhance_discount"] = 1.0, "master.bonuses.enhance_discount = 1"],
		[func(d): d["master"]["bonuses"]["success_mult"] = 0.8, "master.bonuses.success_mult = 0.8"],
		[func(d): d["master"]["bonuses"]["double_step"] = 1.5, "master.bonuses.double_step = 1.5"],
		[func(d): d["master"]["unlock_star"] = 31, "master.unlock_star = 31"],
		[func(d): d["master"]["insure_fee_mult"] = -1, "master.insure_fee_mult = -1"],
		[func(d): d.erase("master"), "\"master\" 묶음이 없음"],
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
