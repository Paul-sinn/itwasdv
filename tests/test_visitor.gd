## v7-bal C1: 특별 NPC (visitor.gd: 보험사·마술사·중고 부품상), 보험 (economy.gd·enhance.gd), 고급 스페어, 마술사 ×2 (setting.gd), 저장 형식 11
## 주간 돈 보상은 test_v6b.gd test_weekly, 급송 300초·50건은 test_rush, 싣는 시간은 test_ability.gd test_unload, 상한 따로는 test_trip.gd
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Visitor = preload("res://scripts/core/visitor.gd")

const DAY := 86400
## 현지 시각: 2026-11-18 수요일 1시. 그날 날짜 번호 = D
const NOW := 1794787200 + 2 * DAY + 3600
const D := 20775   # floor(NOW / 86400)

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 명장·특별 NPC가 열린 +star 트럭 1대 (명장 요일 안 고름), 퀘스트 끝, 돈 넉넉
func _game(star: int, money: int = 10 ** 15) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	s.money = money
	s.master_unlocked = true
	s.milestones_done = [10]
	return s


## who가 오늘(D) 와 있는 상태 (다른 NPC는 며칠 뒤). event를 주면 보험사 이벤트를 그것으로. join = 보험 가입
func _day_with(who: String, star: int, event: String = "", join: bool = false, money: int = 10 ** 15) -> GameState:
	var s := _game(star, money)
	s.visitor_next = { "insurer": D + 25, "magician": D + 26, "dealer": D + 27 }
	s.visitor_next[who] = D
	Master.tick(s, b, NOW, _rng(1))
	if event != "":
		s.insurer_event = event
	if join:
		Visitor.join_insurance(s, NOW)
	s.take_events()
	return s


## 성공·퍼짐 확률을 그 단계만 바꾼 balance
func _balance_at(star: int, success: float, destroy: float) -> Balance:
	var d := real_balance_dict()
	d["engine"]["success"][star] = success
	d["engine"]["destroy"][star] = destroy
	var bal: Balance = Balance.from_dict(d)
	assert(bal.is_ok(), ", ".join(bal.errors))
	return bal


func _events(s: GameState, type: String) -> Array:
	return s.take_events().filter(func(e): return e["type"] == type)


## json "visitors" = 지시서 "옮길 숫자"
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq([b.visitor_min_days, b.visitor_max_days], [21, 28], "21~28일")
	check_eq([b.insure_fee_mult, b.partner_discount, b.recovery_star], [10.0, 0.5, 17], "보험료 × 10, 제휴 할인 50%, 복구 보험 +17")
	check_eq([b.magician_up_mult, b.dealer_premium_spares, b.premium_drop_to], [2.0, 1, 17], "마술사 ×2, 고급 스페어 1개 → +17")
	check_eq(D, floori(NOW / 86400.0), "테스트 날짜 번호")


## 방문 일정: 잠겼으면 안 옴, 열린 날 첫 방문 = 1~28일 뒤 (C2: 사용자 답), 3년 매일 켜면 그 뒤 NPC마다 21~28일(+미룬 날)마다 한 번,
## 하루에 한 명, 같은 날 두 번 tick해도 알림 한 번, 명장 요일엔 안 옴
func test_schedule() -> void:
	var locked := GameState.new_game()
	Master.tick(locked, b, NOW, _rng(2))
	check_eq([Visitor.is_unlocked(locked), Visitor.today(locked), locked.visitor_next, Visitor.next_day(locked, "insurer")], [false, "", {}, -1],
			"잠김: 방문 날짜 안 굴림")
	var s := _game(10)
	Master.tick(s, b, NOW, _rng(3))
	for id in Visitor.IDS:
		var n := Visitor.next_day(s, id)
		check(n >= D + 1 and n <= D + 28, "%s 첫 방문 %d일 뒤" % [id, n - D])
	# 첫 방문 날짜 1000번: 1~28일 고르게 (같은 날 열린 1000명. 겹쳐서 미뤄지기 전 값)
	var firsts := {}
	var fr := _rng(31)
	for k in 1000:
		var f := _game(10)
		Master.tick(f, b, NOW - DAY, fr)   # 열린 날 = D − 1 → 방문은 D ~ D + 27 (오늘 tick 안 함: 미루기 전 값)
		var x: int = f.visitor_next["insurer"] - (D - 1)
		firsts[x] = firsts.get(x, 0) + 1
	check(firsts.keys().min() == 1 and firsts.keys().max() == 28 and firsts.size() == 28, "첫 방문 1~28일 모두 나옴: %s" % [firsts.keys()])
	note("첫 방문 1000번: %d~%d일, 날마다 %d~%d번" % [firsts.keys().min(), firsts.keys().max(), firsts.values().min(), firsts.values().max()])
	for master_day in [-1, 2]:   # 명장 요일 없음 / 수요일
		var m := _game(10)
		var rng := _rng(4)
		if master_day >= 0:
			Master.set_day(m, master_day, NOW)
		var last := { "insurer": D, "magician": D, "dealer": D }
		var gaps := { "insurer": [], "magician": [], "dealer": [] }
		var first_gap := { }   # 열린 날 → 첫 방문 (1~28일 + 미룬 날)
		var two_a_day := 0
		var on_master := 0
		var bad_today := 0
		for k in 1095:
			var t := NOW + k * DAY
			Master.tick(m, b, t, rng)
			Master.tick(m, b, t + 18 * 3600, rng)   # 같은 날 두 번째 tick
			var v := _events(m, "visitor")
			two_a_day += 1 if v.size() > 1 else 0
			if v.size() == 1:
				var who: String = v[0]["who"]
				if first_gap.has(who):
					gaps[who].append(D + k - last[who])
				else:
					first_gap[who] = D + k - last[who]
				last[who] = D + k
				on_master += 1 if m.active_bonus != "" else 0
				bad_today += 0 if Visitor.today(m) == who else 1
		check_eq([two_a_day, on_master, bad_today], [0, 0, 0], "명장 요일 %d: 하루 두 번 알림 / 명장 날 방문 / today 다름" % master_day)
		for id in Visitor.IDS:
			var g: Array = gaps[id]
			var lo: int = g.min() if not g.is_empty() else -1
			var hi: int = g.max() if not g.is_empty() else -1
			var mean := 0.0
			for x in g:
				mean += x
			mean /= maxf(1.0, g.size())
			check(g.size() >= 38 and lo >= 21 and hi <= 31, "명장 요일 %d, %s: 3년 %d번, 간격 %d~%d일" % [master_day, id, g.size(), lo, hi])
			check(first_gap.get(id, 0) >= 1 and first_gap.get(id, 0) <= 31, "명장 요일 %d, %s 첫 방문 %d일 뒤" % [master_day, id, first_gap.get(id, 0)])
			check_near(mean, 24.5, 1.5, "명장 요일 %d, %s 평균 간격" % [master_day, id])
			note("명장 요일 %d, %s: 첫 방문 %d일 뒤, 그 뒤 3년 %d번, 간격 %d~%d일 (평균 %.2f)" % [master_day, id, first_gap.get(id, 0), g.size(), lo, hi, mean])


## 같은 날 둘 이상이면 보험사 → 마술사 → 부품상 순서, 나머지는 다음 날로. 명장 방문 중인 날엔 안 오고 다음 날로
func test_one_per_day() -> void:
	var s := _game(10)
	s.visitor_next = { "insurer": D, "magician": D, "dealer": D }
	var order := []
	for k in 3:
		Master.tick(s, b, NOW + k * DAY, _rng(5))
		order.append(Visitor.today(s))
		check_eq(_events(s, "visitor").size(), 1, "%d일째 알림 한 번" % k)
	check_eq(order, ["insurer", "magician", "dealer"], "하루에 한 명, 정해진 순서")
	var m := _game(10)
	Master.set_day(m, Master.weekday(NOW), NOW)   # 오늘(수요일)이 명장 날
	m.visitor_next = { "insurer": D + 20, "magician": D, "dealer": D + 20 }
	Master.tick(m, b, NOW, _rng(6))
	check_eq([m.active_bonus != "", Visitor.today(m), Visitor.next_day(m, "magician"), _events(m, "visitor").size()], [true, "", D + 1, 0],
			"명장 날: 마술사 안 옴, 다음 날로")
	Master.tick(m, b, NOW + DAY, _rng(6))
	check_eq([m.active_bonus, Visitor.today(m)], ["", "magician"], "다음 날 마술사")


## 그날 안 켰으면 그 방문은 지나감, 오래 안 켜도·시계가 거꾸로 가도 다음 방문이 0~28일 안
func test_missed_and_clock() -> void:
	var s := _game(10)
	s.visitor_next = { "insurer": D, "magician": D + 10, "dealer": D + 12 }
	Master.tick(s, b, NOW + DAY, _rng(7))   # 방문일(D)에 안 켜고 다음 날 켬
	var n := Visitor.next_day(s, "insurer")
	check_eq([Visitor.today(s), _events(s, "visitor").size()], ["", 0], "놓친 방문: 안 옴")
	check(n >= D + 21 and n <= D + 28, "놓친 뒤 다음 방문 = 그 날 + 21~28일: %d" % (n - D))
	Master.tick(s, b, NOW + 400 * DAY, _rng(8))   # 400일 뒤
	for id in Visitor.IDS:
		var x := Visitor.next_day(s, id)
		check(x >= D + 400 and x <= D + 400 + 28, "400일 안 켬: %s 다음 방문 %d일 뒤" % [id, x - D - 400])
	Master.tick(s, b, NOW - 300 * DAY, _rng(9))   # 시계를 거꾸로
	for id in Visitor.IDS:
		var y := Visitor.next_day(s, id)
		check(y >= D - 300 and y <= D - 300 + 28, "시계 거꾸로: %s 다음 방문 %d일 뒤" % [id, y - D + 300])
	# 무작위 시각 2000번: 멈추지 않고, today는 늘 오늘 방문 날짜인 NPC
	var r := _rng(10)
	var now := NOW
	var bad := 0
	for k in 2000:
		if k % 50 == 0:
			now = int(r.randf_range(-1.0e9, 4.0e9))   # 1938년 ~ 2096년
		else:
			now += r.randi_range(-40, 40) * DAY + r.randi_range(0, DAY)
		Master.tick(s, b, now, r)
		s.take_events()
		var who := Visitor.today(s)
		var day := floori(now / 86400.0)
		var ok := who == "" or (Visitor.next_day(s, who) == day and s.visitor_day == day)
		for id in Visitor.IDS:
			ok = ok and Visitor.next_day(s, id) >= day and Visitor.next_day(s, id) <= day + 28
		bad += 0 if ok else 1
	check_eq(bad, 0, "무작위 시각 2000번 중 이상한 번")


## [예]: 보험사가 온 날만 가입, 그날만 유효. [아니오]를 눌러도(= 아무 함수도 안 부름) 그날 다시 [예] 가능
func test_join() -> void:
	var m := _day_with("magician", 18)
	check_eq([Visitor.join_insurance(m, NOW), Visitor.is_insured(m), Visitor.insurer_event(m)], [false, false, ""], "마술사 날: 가입 안 됨")
	var s := _day_with("insurer", 18)
	check(Visitor.INSURER_EVENTS.has(Visitor.insurer_event(s)), "보험사 이벤트: %s" % Visitor.insurer_event(s))
	check(not Visitor.is_insured(s), "누르기 전에 가입됨")
	check_eq([Visitor.join_insurance(s, NOW + 3600), Visitor.is_insured(s), s.insured_day], [true, true, D], "[예] → 가입")
	check(Visitor.join_insurance(s, NOW + 7200), "두 번 눌러도 true")
	check(not Visitor.join_insurance(s, NOW + DAY), "다음 날 시각으로는 가입 안 됨")
	Master.tick(s, b, NOW + DAY, _rng(11))
	check_eq([Visitor.today(s), Visitor.is_insured(s), Visitor.insurer_event(s)], ["", false, ""], "다음 날: 보험 끝")
	# 보험사 이벤트는 두 가지가 다 나옴 (많이 굴려 비율)
	var counts := { "partner_discount": 0, "recovery": 0 }
	var r := _rng(12)
	for k in 2000:
		var v := _game(10)
		v.visitor_next = { "insurer": D, "magician": D + 25, "dealer": D + 26 }
		Master.tick(v, b, NOW, r)
		counts[_events(v, "visitor")[0]["event"]] += 1
	check_near(counts["partner_discount"] / 2000.0, 0.5, 0.05, "제휴 할인 비율 (%s)" % [counts])


## 보험료 = round(강화 비용(할인 전) × 퍼짐 확률(표 값) × 10). +17 이하·가입 안 함 → 0. 엔진 보호·명장 감소는 보험료에 안 들어감
func test_insure_fee() -> void:
	var s := _day_with("insurer", 18, "recovery", true)
	for star in [18, 20, 22, 29]:
		s.truck(0).star = star
		var want := roundi(Economy.base_enhance_cost(b, star) * b.destroy[star] * 10.0)
		check_eq([Enhance.insure_fee(s, b, 0), Economy.insure_fee(b, star, s)], [want, want], "+%d 보험료" % star)
		note("+%d: 강화 비용 %d원, 보험료 %d원 (%.2f배)" % [star, Economy.base_enhance_cost(b, star), want, want / float(Economy.base_enhance_cost(b, star))])
	check_eq(Economy.insure_fee(b, 20, s), roundi(Economy.base_enhance_cost(b, 20) * 0.4), "+20 = 비용 × 0.4 (퍼짐 4% × 10)")
	for star in [0, 10, 17]:
		s.truck(0).star = star
		check_eq(Enhance.insure_fee(s, b, 0), 0, "+%d 보험료 0 (퍼짐 0)" % star)
	s.truck(0).star = 30
	check_eq(Enhance.insure_fee(s, b, 0), 0, "+30 보험료 0")
	s.truck(0).star = 20
	var ecu := s.truck(0).part("ecu")
	ecu["grade"] = 4
	ecu["lines"] = ["engine_guard", "engine_guard", "engine_guard"]
	check_eq(Enhance.insure_fee(s, b, 0), roundi(Economy.base_enhance_cost(b, 20) * 0.4), "엔진 보호가 있어도 표 값으로")
	var no := _day_with("insurer", 20, "recovery", false)
	check_eq(Enhance.insure_fee(no, b, 0), 0, "가입 안 함: 0")
	var p := _day_with("insurer", 20, "partner_discount", true)
	check_eq([Enhance.insure_fee(p, b, 0), Economy.enhance_cost(b, 20, p)],
			[roundi(Economy.base_enhance_cost(b, 20) * 0.4), roundi(Economy.base_enhance_cost(b, 20) * 0.5)], "제휴 할인 날: 보험료는 원래 비용 기준")


## 가입한 날 +18 이상: 강화 비용 + 보험료가 나가고, 퍼짐이 떠도 실패(단계 유지), 스페어 안 씀. 스페어 없이도 누름. 확률 표시는 퍼짐 0
func test_insured_enhance() -> void:
	var bd := _balance_at(18, 0.0, 1.0)   # +18 늘 퍼짐
	var s := _day_with("insurer", 18, "recovery", true)
	s.spares = 0
	var t := s.truck(0)
	check_eq(Enhance.block_reason(s, bd, 0), Enhance.Block.NONE, "보험: 스페어 0이어도 누름")
	var pay := Economy.enhance_cost(bd, 18, s) + Economy.insure_fee(bd, 18, s)
	check_eq(pay, Economy.base_enhance_cost(bd, 18) + roundi(Economy.base_enhance_cost(bd, 18) * 10.0), "+18 퍼짐 100%: 비용 + 비용 × 10")
	var m0 := s.money
	var r := Enhance.try_enhance(s, bd, 0, _rng(13))
	check_eq([r["result"], r["insured"], r["drop_to"], t.star, s.spares, m0 - s.money, t.fail_count, t.destroy_count],
			[Enhance.Result.FAIL, true, -1, 18, 0, pay, 1, 0], "보험: 퍼짐 → 실패, +18 그대로, 돈 = 비용 + 보험료")
	check_eq(Enhance.chances_for(bd, s, 0), { "success": 0.0, "fail": 1.0, "destroy": 0.0 }, "보험 확률: 퍼짐 0, 실패 1")
	var c := Enhance.chances_for(b, s, 0)
	check_near(c["fail"], 1.0 - b.success[18], 1e-12, "진짜 +18: 실패 = 1 − 성공")
	s.money = pay - 1
	check_eq(Enhance.block_reason(s, bd, 0), Enhance.Block.NO_MONEY, "비용 + 보험료에 1원 모자람")
	s.money = pay
	check_eq(Enhance.block_reason(s, bd, 0), Enhance.Block.NONE, "딱 맞음")
	# +17: 보험료 0, 확률 그대로, 스페어 필요 없음 (퍼짐 0)
	t.star = 17
	s.money = 10 ** 15
	check_eq([Enhance.insure_fee(s, b, 0), Enhance.chances_for(b, s, 0), Enhance.block_reason(s, b, 0)],
			[0, Enhance.chances(b, 17), Enhance.Block.NONE], "+17: 보험료 0, 확률 그대로")
	# 가입 안 한 날: 퍼짐 → +15, 스페어 −1, 스페어 없으면 못 누름
	var n := _day_with("insurer", 18, "partner_discount", false)
	check_eq(Enhance.block_reason(n, bd, 0), Enhance.Block.NO_SPARE, "가입 안 함: 스페어 필요")
	n.spares = 2
	var rn := Enhance.try_enhance(n, bd, 0, _rng(14))
	check_eq([rn["result"], rn["insured"], rn["drop_to"], n.truck(0).star, n.spares], [Enhance.Result.DESTROY, false, 15, 15, 1], "가입 안 함: +15")
	# 10만 번: 가입한 +20은 퍼짐 0, 성공률 그대로
	var w := _day_with("insurer", 20, "recovery", true)
	var counts := [0, 0, 0]
	var rr := _rng(15)
	for k in 100000:
		w.truck(0).star = 20
		counts[Enhance.try_enhance(w, b, 0, rr)["result"]] += 1
	check_eq(counts[Enhance.Result.DESTROY], 0, "가입한 +20 10만 번: 퍼짐 0")
	check_near(counts[Enhance.Result.SUCCESS] / 100000.0, b.success[20], 0.01, "성공률 그대로")


## 제휴 할인: 그날 가입한 사람만 강화 비용 50% (모든 단계), 가입 안 했거나 복구 보험 날이면 그대로. N번 시도 = 실제로 누른 횟수
func test_partner_discount() -> void:
	var p := _day_with("insurer", 5, "partner_discount", true)
	var no := _day_with("insurer", 5, "partner_discount", false)
	var rec := _day_with("insurer", 5, "recovery", true)
	for star in [0, 5, 17, 18, 25]:
		var base := Economy.base_enhance_cost(b, star)
		check_eq([Economy.enhance_cost(b, star, p), Economy.enhance_cost(b, star, no), Economy.enhance_cost(b, star, rec)],
				[roundi(base * 0.5), base, base], "+%d 비용: 가입 50%% / 안 함 / 복구 보험 날" % star)
	var m0 := p.money
	Enhance.try_enhance(p, b, 0, _rng(16))
	check_eq(m0 - p.money, roundi(Economy.base_enhance_cost(b, 5) * 0.5), "+5 실제로 빠진 돈 = 반값 (보험료 0)")
	# tries: 늘 실패(퍼짐은 보험이 막음)하는 +18로 BLOCKED까지 누른 횟수
	var bf := _balance_at(18, 0.0, 0.05)
	var q := _day_with("insurer", 18, "partner_discount", true, 0)
	var one := Economy.enhance_cost(bf, 18, q) + Economy.insure_fee(bf, 18, q)
	check_eq(one, roundi(Economy.base_enhance_cost(bf, 18) * 0.5) + roundi(Economy.base_enhance_cost(bf, 18) * 0.05 * 10.0), "1번 = 반값 + 보험료")
	q.money = one * 7 + 123
	var want := Economy.tries(q, bf, 0)
	var pressed := 0
	while Enhance.try_enhance(q, bf, 0, _rng(17))["result"] != Enhance.Result.BLOCKED:
		pressed += 1
	check_eq([want, pressed, q.truck(0).star], [7, 7, 18], "N번 시도 가능 = 실제로 누른 횟수 (가입·제휴 할인)")


## 복구 보험: 그날 가입 안 하고 퍼지면 +15 대신 +17 (스페어는 1개 씀). 다른 날·제휴 할인 날은 +15
func test_recovery() -> void:
	var bd := _balance_at(20, 0.0, 1.0)
	for c in [["recovery", 17], ["partner_discount", 15]]:
		var s := _day_with("insurer", 20, c[0], false)
		s.spares = 3
		var r := Enhance.try_enhance(s, bd, 0, _rng(18))
		check_eq([r["result"], r["drop_to"], r["premium"], s.truck(0).star, s.spares], [Enhance.Result.DESTROY, c[1], false, c[1], 2],
				"%s 날 가입 안 하고 퍼짐 → +%d" % c)
	var other := _day_with("magician", 20)
	other.insurer_event = "recovery"   # 지난 보험사 이벤트가 남아 있어도 오늘 보험사가 없으면 안 걸림
	other.spares = 1
	check_eq(Enhance.try_enhance(other, bd, 0, _rng(19))["drop_to"], 15, "보험사 없는 날: +15")
	var cheat := _day_with("insurer", 22, "recovery", false)
	Enhance.force_destroy(cheat, b, 0)
	check_eq(cheat.truck(0).star, 17, "치트 F5도 복구 보험 날이면 +17")


## 중고 부품상: 그날 처음 tick에 고급 스페어 +1 (알림에 gift), 같은 날 다시 켜도 한 번. 고급 스페어는 [고급 스페어 쓰기]가 켜져 있으면 먼저 써서 +17
func test_dealer_and_premium() -> void:
	var s := _game(18)
	s.visitor_next = { "insurer": D + 25, "magician": D + 26, "dealer": D }
	Master.tick(s, b, NOW, _rng(20))
	check_eq(_events(s, "visitor"), [{ "type": "visitor", "who": "dealer", "event": "", "gift": 1 }], "부품상 알림 (gift 1)")
	check_eq(s.premium_spares, 1, "고급 스페어 +1")
	Master.tick(s, b, NOW + 3600, _rng(20))
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)   # 같은 날 껐다 켬
	var again: GameState = r["state"]
	Master.tick(again, b, NOW + 7200, _rng(21))
	check_eq([s.premium_spares, _events(s, "visitor").size(), again.premium_spares, _events(again, "visitor").size(), Visitor.today(again)],
			[1, 0, 1, 0, "dealer"], "같은 날 다시 tick·껐다 켜도 선물 한 번")
	# 퍼짐: 켜짐 + 고급 있음 → 고급 → +17 / 꺼짐 → 보통 → +15 / 켜짐 + 고급 0 → 보통 → +15
	var bd := _balance_at(20, 0.0, 1.0)
	for c in [[true, 1, 1, 17, true, 0, 1], [false, 1, 1, 15, false, 1, 0], [true, 0, 1, 15, false, 0, 0]]:
		var g := _game(20)
		g.use_premium = c[0]
		g.premium_spares = c[1]
		g.spares = c[2]
		var out := Enhance.try_enhance(g, bd, 0, _rng(22))
		check_eq([out["result"], out["drop_to"], out["premium"], g.truck(0).star, g.premium_spares, g.spares],
				[Enhance.Result.DESTROY, c[3], c[4], c[3], c[5], c[6]], "쓰기 %s, 고급 %d, 보통 %d" % [c[0], c[1], c[2]])
	# "+18 이상은 스페어 1개" = 보통 + (켜져 있으면) 고급
	var k := _game(18)
	k.premium_spares = 2
	check_eq([Enhance.block_reason(k, b, 0), Economy.tries(k, b, 0)], [Enhance.Block.NO_SPARE, 0], "꺼져 있고 보통 0: 못 누름")
	k.use_premium = true
	check_eq(Enhance.block_reason(k, b, 0), Enhance.Block.NONE, "켜져 있고 고급 2: 누름")
	check_eq(Economy.tries(k, b, 0), floori(float(k.money) / Economy.enhance_cost(b, 18, k)), "tries도 고급을 셈")
	check_eq(k.usable_spares(), 2, "쓸 수 있는 스페어 = 고급 2")
	# 복구 보험 + 고급 스페어: 둘 다 +17
	var both := _day_with("insurer", 25, "recovery", false)
	both.use_premium = true
	both.premium_spares = 1
	Enhance.force_destroy(both, b, 0)
	check_eq([both.truck(0).star, both.premium_spares], [17, 0], "복구 보험 + 고급: +17")


## 마술사 날: 세팅 등급업 확률 × 2 (최대 1), 천장 카운터는 그대로 쌓임. 다른 날은 그대로
func test_magician() -> void:
	var m := _day_with("magician", 10)
	var plain := _day_with("insurer", 10)
	check_eq([Setting.up_chance(b, 0, m), Setting.up_chance(b, 1, m), Setting.up_chance(b, 2, m), Setting.up_chance(b, 3, m), Setting.up_chance(b, 4, m)],
			[0.6, 0.16, 0.04, 0.006, 0.0], "마술사 날 × 2 (스냅샷 4번 '마술사 날 확률')")
	check_eq(Setting.up_chance(b, 1, plain), 0.08, "보험사 날: 그대로")
	var d := real_balance_dict()
	d["setting"]["up_chance"][0] = 0.7
	check_eq(Setting.up_chance(Balance.from_dict(d), 0, m), 1.0, "70% × 2 → 1")
	d["setting"]["ceiling"] = [1000000000, 1000000000, 1000000000, 1000000000]
	var bnc: Balance = Balance.from_dict(d)
	var rng := _rng(23)
	var ups := 0
	for k in 100000:
		var p := m.truck(0).part("cargo_box")
		p["grade"] = 1
		p["pending"] = null
		if Setting.try_roll(m, bnc, 0, "cargo_box", rng)["grade_up"]:
			ups += 1
	check_near(ups / 100000.0, 0.16, 0.01, "스트리트 → 스포츠 10만 번 (8% × 2)")
	# 천장 카운터: 마술사 날에도 등급업 못 하면 +1
	var c := _day_with("magician", 10)
	var box := c.truck(0).part("cargo_box")
	box["grade"] = 3
	var cr := _rng(24)
	var before: int = box["counters"][3]
	var res := Setting.try_roll(c, b, 0, "cargo_box", cr)
	Setting.choose(c, 0, "cargo_box", false)
	check_eq(box["counters"][3], 0 if res["grade_up"] else before + 1, "천장 카운터 쌓임")
	note("마술사 날 스트리트 → 스포츠 %d/10만" % ups)


## 저장 형식 11: 새 칸 왕복 (visitor_today는 저장 안 함 → tick이 같은 NPC로), 형식 10(쿠폰 있음) 읽힘, 범위·모양
func test_save_v11() -> void:
	var s := _day_with("insurer", 20, "partner_discount", true)
	s.premium_spares = 3
	s.use_premium = true
	var keys := ["premium_spares", "use_premium", "visitor_next", "visitor_day", "insurer_event", "insured_day"]
	var want := []
	for k in keys:
		want.append(s.get(k))
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	if r["state"] != null:
		var g: GameState = r["state"]
		var got := []
		for k in keys:
			got.append(g.get(k))
		check_eq(got, want, "형식 11 칸")
		check_eq([g.visitor_today, Visitor.is_insured(g)], ["", false], "visitor_today는 저장 안 함 (tick 전)")
		Master.tick(g, b, NOW + 3600, _rng(25))
		check_eq([Visitor.today(g), Visitor.is_insured(g), Visitor.insurer_event(g), _events(g, "visitor").size()],
				["insurer", true, "partner_discount", 0], "다시 켜고 tick: 같은 보험사·가입 그대로·이벤트 같음, 알림 없음")
		check_eq(Economy.enhance_cost(b, 20, g), roundi(Economy.base_enhance_cost(b, 20) * 0.5), "다시 켜도 제휴 할인")
	# 형식 10 (쿠폰 있음, 새 칸 없음) → 쿠폰 버리고 처음 값
	var d10 := Save.to_dict(_game(18), 1794000000)
	d10["version"] = 10
	d10["coupons"] = 4
	for k in keys:
		d10.erase(k)
	var r10 := Save.from_dict(d10, b)
	check_eq(r10["status"], Save.Status.OK, "형식 10 읽기 (%s)" % r10["error"])
	if r10["state"] != null:
		var g10: GameState = r10["state"]
		check_eq([g10.premium_spares, g10.use_premium, g10.visitor_next, g10.visitor_day, g10.insurer_event, g10.insured_day],
				[0, false, {}, -1, "", -1], "형식 10: 처음 값")
		Master.tick(g10, b, NOW, _rng(26))
		check(Visitor.next_day(g10, "dealer") >= D + 1 and Visitor.next_day(g10, "dealer") <= D + 28, "형식 10 +18: 첫 tick에서 방문 날짜 굴림 (첫 방문 1~28일)")
	# 범위 밖·모르는 값은 자르거나 버림
	var dc := Save.to_dict(s, 1794000000)
	dc["premium_spares"] = -2
	dc["insurer_event"] = "group_insurance"
	dc["visitor_next"] = { "insurer": 20800.0, "clown": 5, "dealer": 20801.7 }
	var rc := Save.from_dict(dc, b)
	if rc["state"] != null:
		check_eq([rc["state"].premium_spares, rc["state"].insurer_event, rc["state"].visitor_next], [0, "", { "insurer": 20800, "dealer": 20801 }],
				"음수 → 0, 모르는 이벤트 → \"\", 모르는 NPC 버림, 소수 버림")
	for bad in [["premium_spares", "많이"], ["use_premium", 1], ["visitor_next", [1, 2]], ["visitor_day", "어제"], ["insurer_event", 3],
			["insured_day", null]]:
		var db := Save.to_dict(s, 1794000000)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)
	var dn := Save.to_dict(s, 1794000000)
	dn["visitor_next"] = { "insurer": "내일" }
	check_eq(Save.from_dict(dn, b)["status"], Save.Status.BROKEN, "visitor_next 값이 숫자가 아님")


## visitors 숫자 검사
func test_bad_numbers() -> void:
	var cases := [
		[func(d): d.erase("visitors"), "\"visitors\" 묶음이 없음"],
		[func(d): d["visitors"]["min_days"] = 0, "visitors.min_days = 0"],
		[func(d): d["visitors"]["max_days"] = 20, "visitors.max_days = 20 (min_days 21"],
		[func(d): d["visitors"]["max_days"] = 25.5, "visitors.max_days = 25.5"],
		[func(d): d["visitors"]["insurer"]["fee_mult"] = -1, "visitors.insurer.fee_mult = -1"],
		[func(d): d["visitors"]["insurer"]["events"]["partner_discount"] = 1.0, "visitors.insurer.events.partner_discount = 1"],
		[func(d): d["visitors"]["insurer"]["events"]["recovery_star"] = 30, "visitors.insurer.events.recovery_star = 30"],
		[func(d): d["visitors"]["insurer"].erase("events"), "visitors.insurer.events 가 없거나"],
		[func(d): d["visitors"]["magician"]["up_mult"] = 0.5, "visitors.magician.up_mult = 0.5"],
		[func(d): d["visitors"]["dealer"]["premium_spares"] = 1.5, "visitors.dealer.premium_spares = 1.5"],
		[func(d): d["visitors"]["dealer"]["premium_drop_to"] = -1, "visitors.dealer.premium_drop_to = -1"],
		[func(d): d["visitors"].erase("dealer"), "visitors.dealer 가 없거나"],
		[func(d): d["setting"]["maint_cut_cap"] = 1.5, "setting.maint_cut_cap = 1.5"],
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
