## v6b C1: 대형·VIP (trip.gd), 급송 전화 (rush.gd), 주간 배송 목표 (weekly.gd, master.gd 주 번호), 저장 형식 8
## v7-bal: 급송 300초·50건, 주간 목표 6만 건·보상은 돈(하루치 수입) + 경험치 (쿠폰 지움)
extends "res://tests/test_base.gd"

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Save = preload("res://scripts/core/save.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Weekly = preload("res://scripts/core/weekly.gd")

## 현지 시각 (1970-01-01 0시 현지부터 초). 2026-11-15 일요일, 2026-11-16 월요일, 2026-11-23 월요일
const SUN_1115 := 1794700800
const MON_1116 := 1794787200
const MON_1123 := 1795392000

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## +star 트럭 1대, 퀘스트는 다 끝냄 (보상 돈·경험치가 안 섞이게), 포인트 59
func _game(star: int) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	s.ability_points = 59
	return s


## 배송 n건이 될 때까지 한 바퀴씩 진행해서 배송 종류를 센다 (세는 것은 그 바퀴 이벤트만: 전체를 매번 다시 세면 느림)
func _kinds(s: GameState, bal: Balance, n: int, rng: RandomNumberGenerator) -> Dictionary:
	var counts := { "normal": 0, "large": 0, "vip": 0 }
	var parcels := 0
	while parcels < n:
		for e in Trip.advance(s, bal, 0, Trip.lap_seconds(bal, s, 0), rng):
			if e["type"] == "parcel":
				counts[e["kind"]] += 1
				parcels += 1
	return counts


func _total_xp(s: GameState) -> int:
	var sum := s.driver_xp
	for lv in range(1, s.driver_level):
		sum += Driver.xp_need(b, lv)
	return sum


func _events(s: GameState, type: String) -> Array:
	return s.take_events().filter(func(e): return e["type"] == type)


## json 값 = 지시서 "옮길 숫자" (C1 몫: special·rush·weekly)
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.special, { "large": { "unlock_star": 15, "pay_mult": 3.0, "share": 0.10 }, "vip": { "unlock_star": 18, "pay_mult": 5.0, "share": 0.05 } },
			"special (대형 +15 ×3 10%, VIP +18 ×5 5%)")
	check_eq([b.rush_min_minutes, b.rush_max_minutes, b.rush_ring_seconds, b.rush_parcels, b.rush_pay_mult], [30.0, 60.0, 300.0, 50, 2.0],
			"rush (v7-bal: 벨 300초, 50건)")
	check_eq([b.weekly_target, b.weekly_xp, b.weekly_reward_hours], [60000, 2000, 24.0], "weekly (v7-bal: 6만 건, 보상 하루치 24시간)")


## ① +14 전부 보통, +15 대형 약 10%, +18 VIP 약 5%·대형 약 9.5%, 퍼져서 +15면 VIP 0 (10만 건씩, 1%p 안)
func test_kind_shares() -> void:
	var c14 := _kinds(_game(14), b, 20000, _rng(1))
	check_eq([c14["large"], c14["vip"]], [0, 0], "+14: 대형·VIP 없음 (%s)" % [c14])
	var c15 := _kinds(_game(15), b, 100000, _rng(2))
	check_near(c15["large"] / 100000.0, 0.10, 0.01, "+15 대형 비율")
	check_eq(c15["vip"], 0, "+15 VIP")
	var c18 := _kinds(_game(18), b, 100000, _rng(3))
	check_near(c18["vip"] / 100000.0, 0.05, 0.01, "+18 VIP 비율")
	check_near(c18["large"] / 100000.0, 0.095, 0.01, "+18 대형 비율 = 0.95 × 0.1")
	var s := _game(18)
	s.spares = 1
	Enhance.force_destroy(s, b, 0)
	check_eq(s.truck(0).star, 15, "퍼져서 +15")
	var cd := _kinds(s, b, 20000, _rng(4))
	check_eq(cd["vip"], 0, "퍼져서 +15: VIP 다시 잠김 (%s)" % [cd])
	check(cd["large"] > 0, "퍼져서 +15: 대형은 그대로")
	note("+15: %s / +18: %s (VIP %.3f%%, 대형 %.3f%%) / 퍼진 +15: %s" % [c15, c18, c18["vip"] / 1000.0, c18["large"] / 1000.0, cd])


## ② 대형 1건 돈 = 단가 ×3 기준 계산, VIP ×5. 협상·팁·기름값 절감도 그 단가 기준
func test_special_pay() -> void:
	for c in [[{}, 0, { "normal": [1875, 2500], "large": [5625, 7500], "vip": [9375, 12500] }],
			[{ "nego": 20 }, 0, { "normal": [2250, 3000], "large": [6750, 9000], "vip": [11250, 15000] }],
			[{}, 4, { "normal": [2175, 2500], "large": [6525, 7500], "vip": [10875, 12500] }]]:
		var s := _game(18)
		for id in c[0]:
			s.abilities[id] = c[0][id]
		if c[1] == 4:   # 적재함 프로토타입 기름값 절감 45% × 2줄 → 상한 60%: 단가의 20% × 0.4
			var box := s.truck(0).part("cargo_box")
			box["grade"] = 4
			box["lines"] = ["fuel_cut", "fuel_cut", "junk_gloss"]
		var want: Dictionary = c[2]
		var rng := _rng(5)
		var seen := {}
		var bad := []
		var last_kind := ""
		var parcels := 0
		while parcels < 30000:
			for e in Trip.advance(s, b, 0, Trip.lap_seconds(b, s, 0), rng):
				if e["type"] == "parcel":
					parcels += 1
					last_kind = e["kind"]
					seen[last_kind] = true
					if e["pay"] != want[last_kind][0]:
						bad.append([last_kind, e["pay"]])
				elif e["type"] == "tip" and e["pay"] != want[last_kind][1]:
					bad.append([last_kind, "팁", e["pay"]])
		check_eq(seen.keys().size(), 3, "%s: 보통·대형·VIP 다 나옴" % [c[0]])
		check(bad.is_empty(), "%s 세팅%d: 기대 %s, 다른 돈 %s" % [c[0], c[1], want, bad.slice(0, 5)])
		check_eq(Trip.parcel_pay(b, s, 0), want["normal"][0], "%s: parcel_pay는 보통 배송" % [c[0]])
		note("%s 세팅%d: 보통·대형·VIP 1건 / 팁 = %s" % [c[0], c[1], want])


## ③ 시간당 수입(평균) = advance 50시간 돈과 1% 안 (+15, +18. 협상·친절도 함께)
func test_hourly_matches_long_run() -> void:
	for picks in [{}, { "nego": 20, "kind": 30 }]:
		for star in [15, 18]:
			var s := _game(star)
			for id in picks:
				s.abilities[id] = picks[id]
			var hourly := Trip.hourly_income(b, s, 0)
			Trip.advance(s, b, 0, 50 * 3600.0, _rng(6))
			var gap := absf(s.money / 50.0 - hourly) / hourly
			check(gap <= 0.01, "%s +%d: 50시간의 시간당 %.1f / hourly_income %.1f (차이 %.2f%%)" % [picks, star, s.money / 50.0, hourly, gap * 100.0])
			var plain := _game(14)
			note("%s +%d: hourly_income %.1f원 (대형·VIP 없는 +14 %.1f), advance 50시간의 시간당 %.1f원 (차이 %.2f%%)"
					% [picks, star, hourly, Trip.hourly_income(b, plain, 0), s.money / 50.0, gap * 100.0])
	# "성공하면 시간당": +14 → +15에서 대형 몫이 들어감 (평균 배수 1.2), +18이면 1.39. 대형·VIP를 끈 balance와 비교
	var d := real_balance_dict()
	d["special"]["large"]["share"] = 0.0
	d["special"]["vip"]["share"] = 0.0
	var bn: Balance = Balance.from_dict(d)
	var s14 := _game(14)
	check_near(Trip.hourly_income_at(b, s14, 0, 15) / Trip.hourly_income_at(bn, s14, 0, 15), 1.2, 1e-9, "hourly_income_at(+15)은 대형 몫 포함 (×1.2)")
	check_near(Trip.hourly_income_at(b, s14, 0, 18) / Trip.hourly_income_at(bn, s14, 0, 18), 1.39, 1e-9, "hourly_income_at(+18)은 VIP·대형 몫 포함 (×1.39)")
	check_near(Trip.hourly_income(b, s14, 0), Trip.hourly_income(bn, s14, 0), 1e-9, "+14는 대형·VIP 없음")


## ④ 급송: 30~60분 사이에만 울림, 받으면 트럭 0 다음 50건만 ×2, 안 받으면 300초 뒤 사라지고 돈 그대로, 꺼 두면 안 울림,
##    꺼둔 동안·급송이 남은 동안 시계가 안 감
func test_rush() -> void:
	# 간격 1만 번: 최소·최대·평균
	var lo := INF
	var hi := -INF
	var sum := 0.0
	var rng := _rng(7)
	for k in 10000:
		var s := GameState.new_game()
		Rush.tick(s, b, 0.0, rng)
		lo = minf(lo, s.rush_next)
		hi = maxf(hi, s.rush_next)
		sum += s.rush_next
	check(lo >= 1800.0 and hi <= 3600.0, "벨 간격이 30~60분 밖: %.1f ~ %.1f초" % [lo, hi])
	check(lo < 1810.0 and hi > 3590.0, "1만 번인데 30분·60분 근처가 안 나옴: %.1f ~ %.1f초" % [lo, hi])
	check_near(sum / 10000.0, 2700.0, 30.0, "평균 45분")
	# 그 시각에 울림 → 받으면 다음 50건 ×2 (트럭 0만)
	var s := _game(0)
	s.trucks.append(TruckState.new())
	var r := _rng(8)
	Rush.tick(s, b, 0.0, r)
	var wait := s.rush_next
	Rush.tick(s, b, wait - 0.5, r)
	check(not Rush.is_ringing(s), "시각 전에 울림")
	check(not Rush.accept(s, b), "안 울리는데 받기가 됨")
	Rush.tick(s, b, 1.0, r)
	check(Rush.is_ringing(s), "시각이 됐는데 안 울림")
	check_eq(_events(s, "rush_call").size(), 1, "rush_call 알림 한 번")
	check(Rush.accept(s, b), "울리는데 받기가 안 됨")
	check_eq([Rush.is_ringing(s), Rush.parcels_left(s)], [false, 50], "받은 뒤 벨 끝, 급송 50건")
	var e1 := Trip.advance(s, b, 1, 600.0, r).filter(func(e): return e["type"] == "parcel")
	check(not e1.is_empty() and e1.all(func(e): return not e["rush"] and e["gross"] == 1875), "트럭 1 배송이 급송이 됨")
	check_eq(Rush.parcels_left(s), 50, "트럭 1 배송에 급송 건수가 줄어듦")
	var p0 := []
	while p0.size() < 55:
		for e in Trip.advance(s, b, 0, 5.0, r):
			if e["type"] == "parcel":
				p0.append(e)
	var first := p0.slice(0, 50)
	var after := p0.slice(50)
	check(first.all(func(e): return e["rush"] and e["pay"] == 3750), "트럭 0 처음 50건이 급송 3750원이 아님: %s" % [first.map(func(e): return e["pay"])])
	check(after.all(func(e): return not e["rush"] and e["pay"] == 1875), "51번째부터 보통이 아님: %s" % [after.map(func(e): return e["pay"])])
	check_eq(Rush.parcels_left(s), 0, "급송 다 씀")
	# 급송이 남은 동안 시계가 안 감
	var g := _game(0)
	Rush.tick(g, b, 0.0, r)
	Rush.tick(g, b, g.rush_next, r)
	Rush.accept(g, b)
	Rush.tick(g, b, 0.0, r)
	var next := g.rush_next
	Rush.tick(g, b, 5 * 3600.0, r)
	check_eq([g.rush_next, Rush.is_ringing(g), _events(g, "rush_call").size()], [next, false, 1], "급송이 남은 동안 다음 벨 시계가 감")
	# 안 받으면 300초 뒤 사라짐, 돈 그대로
	var m := _game(0)
	Rush.tick(m, b, 0.0, r)
	Rush.tick(m, b, m.rush_next, r)
	m.take_events()
	var money := m.money
	Rush.tick(m, b, 299.9, r)
	check(Rush.is_ringing(m), "300초 전에 끝남")
	Rush.tick(m, b, 0.2, r)
	check_eq([Rush.is_ringing(m), Rush.parcels_left(m), m.money], [false, 0, money], "300초 뒤 사라짐, 돈 변화 없음")
	check_eq(_events(m, "rush_missed").size(), 1, "rush_missed 알림 한 번")
	check(m.rush_next >= 1800.0 and m.rush_next <= 3600.0, "놓친 뒤 다음 벨 간격: %s" % m.rush_next)
	# 꺼 두면 안 울림 (울리던 중에 끄면 조용히 끝)
	var off := _game(0)
	off.rush_enabled = false
	Rush.tick(off, b, 10 * 3600.0, r)
	check_eq([Rush.is_ringing(off), off.take_events().size()], [false, 0], "꺼 뒀는데 울림")
	var mid := _game(0)
	Rush.tick(mid, b, 0.0, r)
	Rush.tick(mid, b, mid.rush_next, r)
	mid.rush_enabled = false
	Rush.tick(mid, b, 0.1, r)
	check(not Rush.is_ringing(mid), "울리던 중에 껐는데 계속 울림")
	# 꺼둔 동안(apply_offline)에는 시계가 안 감
	var o := _game(10)
	Rush.tick(o, b, 0.0, r)
	var before := o.rush_next
	Trip.apply_offline(o, b, 3 * 3600.0)
	check_eq([o.rush_next, Rush.is_ringing(o)], [before, false], "꺼둔 동안 벨 시계가 감")
	# 아주 긴 dt (빨리 감기): 울림·놓침이 번갈아 와도 멈추지 않음
	var f := _game(0)
	Rush.tick(f, b, 20 * 3600.0, r)
	var calls := 0
	var misses := 0
	for e in f.take_events():
		calls += 1 if e["type"] == "rush_call" else 0
		misses += 1 if e["type"] == "rush_missed" else 0
	check(calls >= 20 and calls <= 40 and (calls == misses or calls == misses + 1), "20시간 한 번에: 벨 %d번, 놓침 %d번" % [calls, misses])
	note("벨 간격 1만 번: %.1f ~ %.1f초, 평균 %.1f초 / 20시간 한 번에 벨 %d번" % [lo, hi, sum / 10000.0, calls])


## ⑤ 주간: 켜 둔·꺼둔 배송을 다 셈, 목표에 닿으면 돈(하루치 = 시간당 내 돈 × 24) +·경험치 +2000·알림 한 번, 같은 주 두 번 안 줌,
##    주가 바뀌면 0
func test_weekly() -> void:
	# 주 번호·요일: 월요일 0시에 바뀜
	check_eq([Master.weekday(SUN_1115), Master.weekday(MON_1116), Master.weekday(MON_1116 + 86399), Master.weekday(MON_1123 - 1)], [6, 0, 0, 6],
			"요일 (일 6, 월 0)")
	check_eq(Master.week_index(MON_1116 - 1) + 1, Master.week_index(MON_1116), "월요일 0시에 주 번호 +1")
	check_eq(Master.week_index(MON_1123 - 1), Master.week_index(MON_1116), "같은 주 (월 0시 ~ 일 24시)")
	check_eq([Master.weekday(345600), Master.week_index(345600), Master.weekday(345599), Master.week_index(345599)], [0, 1, 6, 0],
			"1970-01-05 월요일 0시")
	check_eq([Master.weekday(-1), Master.week_index(-1)], [2, 0], "1970 전 (1969-12-31 수요일)도 오류 없음")
	# 켜 둔·꺼둔 배송을 다 셈
	var s := _game(10)
	Master.tick(s, b, MON_1116 + 3600, _rng(9))
	check_eq([s.weekly_week, Weekly.progress(s)], [Master.week_index(MON_1116), 0], "첫 tick: 그 주로")
	var p0 := s.parcels_total
	Trip.advance(s, b, 0, 3600.0, _rng(9))
	Trip.apply_offline(s, b, 3 * 3600.0)
	check_eq(Weekly.progress(s), s.parcels_total - p0, "진행 = 켜 둔 배송 + 꺼둔 동안 배송")
	check(Weekly.progress(s) > 0 and not Weekly.is_done(s), "아직 목표 전")
	check_eq(Weekly.target(b), 60000, "목표 60000건")
	# 목표에 닿으면 (목표 100으로 바꾼 balance): 돈 + 하루치, 경험치 +2000, 알림 한 번. 같은 주에는 두 번 안 줌
	var d := real_balance_dict()
	d["weekly"]["target_parcels"] = 100
	var b100: Balance = Balance.from_dict(d)
	var w := _game(0)
	Master.tick(w, b100, MON_1116, _rng(10))
	w.take_events()
	var xp0 := _total_xp(w)
	var reward := floori(Company.hourly_net(b100, w) * 24.0)
	check_eq(Weekly.reward_money(b100, w), reward, "reward_money = floor(시간당 내 돈 × 24)")
	check(reward > 0, "하루치 보상이 0원")
	var money0 := w.money
	var earned := 0
	var parcels := 0
	var done := []
	var r := _rng(10)
	while parcels < 300:
		for e in Trip.advance(w, b100, 0, 10.0, r):
			parcels += 1 if e["type"] == "parcel" else 0
			earned += e["pay"] if e["type"] == "parcel" or e["type"] == "tip" else 0
		done.append_array(w.take_events().filter(func(e): return e["type"] == "weekly_done"))
	check_eq(done, [{ "type": "weekly_done", "money": reward, "xp": 2000 }], "알림 한 번 (돈 = 하루치)")
	check_eq([w.money - money0, Weekly.is_done(w)], [earned + reward, true], "돈 = 배송·팁 + 하루치, 달성")
	check_eq(_total_xp(w) - xp0, parcels * 10 + 2000, "경험치 = 배송 × 10 + 2000")
	# 같은 주 다른 날 tick: 그대로
	Master.tick(w, b100, MON_1123 - 1, _rng(10))
	check_eq([Weekly.progress(w), Weekly.is_done(w)], [parcels, true], "같은 주: 진행 그대로, 다시 안 줌")
	# 주가 바뀌면 0, 다시 채우면 또 받음
	Master.tick(w, b100, MON_1123, _rng(10))
	check_eq([Weekly.progress(w), Weekly.is_done(w)], [0, false], "새 주: 진행 0")
	w.take_events()
	Trip.advance(w, b100, 0, 1800.0, r)   # +0 30분 ≈ 250건
	check_eq([Weekly.is_done(w), _events(w, "weekly_done").size()], [true, 1], "새 주에 다시 달성 → 또 받음")
	# 하루치는 받는 순간 켜 둔 상태 기준: 대리점 보조 트럭이 있으면 그 몫(직원 몫·세금 뗀 내 돈)도 들어감
	var a := _game(10)
	a.company_stage = GameState.AGENCY
	a.trucks.append(TruckState.new())
	check_eq(Weekly.reward_money(b, a), floori((Trip.hourly_net(b, a, 0) + Trip.hourly_net(b, a, 1)) * 24.0), "보조 트럭 포함 하루치")
	# 꺼둔 동안 배송으로도 달성, 주가 바뀐 뒤 켜면 새 주에 (Master.tick을 먼저)
	var o := _game(10)
	Master.tick(o, b100, MON_1116, _rng(11))
	o.weekly_parcels = 90
	Master.tick(o, b100, MON_1123 + 3600, _rng(11))
	var ro := Trip.apply_offline(o, b100, 20 * 3600.0)
	check_eq([Weekly.progress(o), Weekly.is_done(o)], [ro["parcels"], true], "주가 바뀐 뒤 켬: 꺼둔 동안 배송이 새 주에 (지난주 90건은 0으로), 달성")
	# 시계가 거꾸로: 멈추지 않음 (주가 바뀐 것으로 봄)
	Master.tick(o, b100, MON_1116, _rng(11))
	check_eq([o.weekly_week, Weekly.progress(o)], [Master.week_index(MON_1116), 0], "시계가 거꾸로 가도 그 주로")
	# 처음(-1)이면 진행을 0으로 안 돌림 (켜기 전 배송·형식 7 저장)
	var n := _game(0)
	n.weekly_parcels = 50
	Master.tick(n, b, MON_1116, _rng(12))
	check_eq(Weekly.progress(n), 50, "처음 tick은 지금 진행 그대로")


## ⑥ 저장 → 읽기 같음, 옛 형식(7) 읽힘, 범위 밖은 자름, 틀린 모양은 깨짐 (쿠폰은 v7-bal에서 지움: 옛 파일의 coupons는 버림)
func test_save_v8() -> void:
	var s := _game(18)
	s.weekly_week = Master.week_index(MON_1116)
	s.weekly_parcels = 12345
	s.weekly_done = true
	s.rush_enabled = false
	s.rush_next = 1234.5
	s.rush_ring = 12.25
	s.rush_left = 7
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b)
	check_eq(r["status"], Save.Status.OK, "읽기 (%s)" % r["error"])
	var keys := ["weekly_week", "weekly_parcels", "weekly_done", "rush_enabled", "rush_next", "rush_ring", "rush_left"]
	if r["state"] != null:
		var got := []
		for k in keys:
			got.append(r["state"].get(k))
		check_eq(got, [s.weekly_week, 12345, true, false, 1234.5, 12.25, 7], "형식 8 칸")
	# 형식 7 (v5b): 칸 없음 → 처음 값
	var d7 := Save.to_dict(_game(0), 1794000000)
	d7["version"] = 7
	for k in keys:
		d7.erase(k)
	var r7 := Save.from_dict(d7, b)
	check_eq(r7["status"], Save.Status.OK, "형식 7 읽기 (%s)" % r7["error"])
	if r7["state"] != null:
		var got7 := []
		for k in keys:
			got7.append(r7["state"].get(k))
		check_eq(got7, [-1, 0, false, true, -1.0, 0.0, 0], "형식 7: 주 모름, 진행 0, 급송 켜짐, 벨 새로")
	# 범위 밖은 자름
	var dc := Save.to_dict(_game(0), 1794000000)
	dc["coupons"] = "많이"   # 형식 10까지의 쿠폰: 모양과 상관없이 버림
	dc["weekly_parcels"] = -10
	dc["rush_left"] = 99
	dc["rush_ring"] = 1000
	dc["rush_next"] = 1e9
	var rc := Save.from_dict(dc, b)
	check_eq(rc["status"], Save.Status.OK, "범위 밖 읽기 (%s)" % rc["error"])
	if rc["state"] != null:
		check_eq([rc["state"].weekly_parcels, rc["state"].rush_left, rc["state"].rush_ring, rc["state"].rush_next],
				[0, 50, 300.0, 3600.0], "진행 음수 → 0, 급송 99 → 50, 벨 1000초 → 300, 다음 벨 → 60분")
	# 틀린 모양 → 깨짐
	for bad in [["weekly_done", "yes"], ["rush_enabled", 1], ["rush_left", "많이"], ["rush_next", "곧"]]:
		var db := Save.to_dict(_game(0), 1794000000)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)


## special·rush·weekly 숫자 검사
func test_bad_numbers() -> void:
	var cases := [
		[func(d): d["special"].erase("vip"), "special.vip 이 없거나"],
		[func(d): d["special"]["giant"] = { "unlock_star": 20, "pay_mult": 9, "share": 0.1 }, "special 에 모르는 배송: giant"],
		[func(d): d["special"]["large"]["share"] = 1.5, "special.large.share = 1.5"],
		[func(d): d["special"]["vip"]["pay_mult"] = 0.5, "special.vip.pay_mult = 0.5"],
		[func(d): d["special"]["vip"]["unlock_star"] = 31, "special.vip.unlock_star = 31"],
		[func(d): d["rush"]["max_minutes"] = 20, "rush.max_minutes = 20"],
		[func(d): d["rush"]["parcels"] = 0, "rush.parcels = 0"],
		[func(d): d["rush"]["ring_seconds"] = 0, "rush.ring_seconds = 0"],
		[func(d): d["weekly"]["target_parcels"] = 0, "weekly.target_parcels = 0"],
		[func(d): d["weekly"]["reward_hours"] = -1, "weekly.reward_hours = -1"],
		[func(d): d["weekly"].erase("reward_hours"), "weekly.reward_hours 이 없음"],
		[func(d): d.erase("rush"), "\"rush\" 묶음이 없음"],
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
