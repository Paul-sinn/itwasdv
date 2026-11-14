## v7a C1: 대리점 창업, 보조 트럭 + 직원 몫, 세금, 타이어·휠, 순위표, 오늘 집계, 퀘스트 3개, 저장 형식 10 (company.gd, trip.gd, save.gd)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

## 현지 시각 2026-11-16 월요일 0시 (1970-01-01 0시 현지부터 초)
const MON_1116 := 1794787200
const DAY := 86400
const RICH := 1_000_000_000_000

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 트럭 단계 목록대로 (첫 번째 = 내 트럭), 퀘스트는 다 끝냄 (보상 돈·경험치가 안 섞이게). agency면 대리점
func _game(stars: Array, agency: bool) -> GameState:
	var s := GameState.new_game()
	s.quest_index = Quest.count(b)
	if agency:
		s.company_stage = GameState.AGENCY
	s.truck(0).star = stars[0]
	for k in range(1, stars.size()):
		var t := TruckState.new()
		t.star = stars[k]
		s.trucks.append(t)
	return s


func _events(s: GameState, type: String) -> Array:
	return s.take_events().filter(func(e): return e["type"] == type)


func _total_xp(s: GameState) -> int:
	var sum := s.driver_xp
	for lv in range(1, s.driver_level):
		sum += Driver.xp_need(b, lv)
	return sum


## 트럭 i를 hours시간(1시간씩) 돌린 parcel·tip 이벤트
func _run(s: GameState, i: int, hours: int, rng: RandomNumberGenerator) -> Array:
	var out := []
	for h in hours:
		out.append_array(Trip.advance(s, b, i, 3600.0, rng).filter(func(e): return e["type"] == "parcel" or e["type"] == "tip"))
	return out


## json 값 = 지시서 "옮길 숫자"
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.company_stages, PackedStringArray(["solo", "agency", "regional", "national", "global"]), "회사 단계")
	check_eq(b.tax_rates, PackedFloat64Array([0.0, 0.03, 0.05, 0.07, 0.10]), "세율표")
	check_eq([b.agency_price, b.staff_share, b.city_xp_per_parcel], [300000000, 0.3, 15], "창업 3억 (v7-bal), 직원 몫 30%, 시내 경험치 15")
	check_eq(b.helper_prices, PackedInt64Array([5000000, 8000000]), "보조 트럭 500만·800만 (v7-bal)")
	check_eq(b.rivals, PackedFloat64Array([6000000, 7000000, 7700000, 8500000, 9400000, 10400000, 11500000, 12700000, 14000000, 15500000]),
			"라이벌 10곳 (v7-bal)")
	check_eq([Setting.unlock_star(b, "tire"), Setting.unlock_stage(b, "tire"), Setting.unlock_stage(b, "ecu")], [0, 1, 0], "타이어 = 대리점에 열림")
	check_eq(b.setting_parts["tire"]["options"], PackedStringArray(["speed", "fuel_cut", "maint_cut", "junk_ride", "junk_scent",
			"junk_cupholder", "junk_radio", "junk_gloss"]), "타이어 옵션")
	check_eq([b.setting_options["maint_cut"]["kind"], b.setting_options["maint_cut"]["weight"], b.setting_options["maint_cut"]["values"]],
			["own", 10.0, PackedFloat64Array([0.15, 0.30, 0.45, 0.55, 0.60])], "정비비 감소 (v7-bal 임시)")
	var tail := []
	for q in b.quests.slice(-3):
		tail.append([q["id"], q["kind"], q["target"], q["part"], q["xp"], q["money"]])
	check_eq(tail, [["found_agency", "agency", 1, "", 1000, 5000000], ["first_helper", "helpers", 1, "", 800, 3000000],
			["tire_first", "part_rolled", 1, "tire", 600, 2000000]], "퀘스트 끝 3개")


## company 숫자 검사: 틀리면 시작할 때 막힘
func test_bad_numbers() -> void:
	var cases := [
		[func(d): d.erase("company"), "\"company\" 묶음이 없음"],
		[func(d): d["company"]["stages"] = ["agency", "solo"], "company.stages"],
		[func(d): d["company"]["tax_rates"] = [0.0, 0.03, 0.05, 0.07], "company.tax_rates 길이가 4개"],
		[func(d): d["company"]["tax_rates"] = [0.0, 0.05, 0.03, 0.07, 0.1], "company.tax_rates[2]"],
		[func(d): d["company"]["staff_share"] = 0.95, "staff_share + 가장 큰 세율"],
		[func(d): d["company"]["agency_price"] = -1, "company.agency_price = -1"],
		[func(d): d["company"]["helper_prices"] = [20000000, 5000000], "company.helper_prices[1]"],
		[func(d): d["company"]["rivals"] = [], "company.rivals 가 없거나 빈 목록"],
		[func(d): d["company"]["rivals"] = [9000000, 8000000], "company.rivals[1]"],
		[func(d): d["company"]["city_xp_per_parcel"] = 1.5, "company.city_xp_per_parcel = 1.5"],
		[func(d): d["setting"]["parts"]["tire"]["unlock"] = "boss", "setting.parts.tire.unlock = boss"],
		[func(d): d["quests"][23]["target"] = 3, "quests[23].target = 3"],
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


## ① 돈이 모자라면 창업 못 함, 창업하면 돈 −3억·단계 1·이벤트 한 번, 두 번 못 함
func test_found_agency() -> void:
	var s := _game([0], false)
	var price := Company.agency_price(b)
	check_eq(price, 300000000, "창업 가격")
	s.money = price - 1
	check(not Company.can_found(b, s), "1원 모자란데 창업 가능")
	check(not Company.found(b, s), "1원 모자란데 창업됨")
	check_eq([s.money, Company.stage(s), s.take_events()], [price - 1, 0, []], "못 했으면 그대로")
	s.money = price + 7
	check(Company.can_found(b, s), "돈이 되는데 창업 불가")
	check(Company.found(b, s), "창업 안 됨")
	check_eq([s.money, Company.stage(s)], [7, 1], "돈 −3억, 단계 1")
	check_eq(s.take_events(), [{ "type": "agency_founded" }], "이벤트 한 번")
	s.money = price * 2
	check(not Company.can_found(b, s), "두 번째 창업 가능")
	check(not Company.found(b, s), "두 번째 창업됨")
	check_eq([s.money, Company.stage(s), s.take_events()], [price * 2, 1, []], "두 번째: 그대로")


## ② 창업 전에는 보조 트럭·타이어·창고 Lv4 잠김, 뒤에는 열림
func test_locked_before_agency() -> void:
	var s := _game([30], false)
	s.money = RICH
	s.warehouse_level = 3
	check_eq(Company.helper_price(b, s), -1, "창업 전 보조 트럭 값")
	check(not Company.can_buy_helper(b, s) and not Company.buy_helper(b, s), "창업 전 보조 트럭 사짐")
	check_eq(s.trucks.size(), 1, "창업 전 트럭 수")
	check(not Setting.unlocked(b, s, 0, "tire"), "창업 전 타이어 열림 (+30이어도)")
	check_eq(Setting.block_reason(s, b, 0, "tire"), Setting.Block.LOCKED, "창업 전 타이어")
	check_eq(Setting.try_roll(s, b, 0, "tire", _rng(1)), { "ok": false }, "창업 전 타이어 돌려짐")
	check_eq([Depot.buyable_level(b, s, "warehouse"), Depot.price(b, s, "warehouse"), Depot.can_upgrade(b, s, "warehouse")], [3, 0, false],
			"창업 전 창고 Lv3까지")
	s.money = RICH + b.agency_price
	check(Company.found(b, s), "창업 안 됨")
	check_eq(Company.helper_price(b, s), 5000000, "창업 뒤 보조 트럭 값")
	check(Setting.unlocked(b, s, 0, "tire"), "창업 뒤 타이어 잠김")
	check_eq(Setting.block_reason(s, b, 0, "tire"), Setting.Block.NONE, "창업 뒤 타이어")
	check_eq([Depot.buyable_level(b, s, "warehouse"), Depot.price(b, s, "warehouse")], [4, 40000000], "창업 뒤 창고 Lv4 4,000만")
	check(Depot.upgrade(b, s, "warehouse"), "창고 Lv4 안 사짐")
	check_eq([s.warehouse_level, Depot.cap_hours(b, s)], [4, 12.0], "창고 Lv4 = 12시간")


## ③ 보조 트럭 2대까지, 값 500만·2,000만, 3대째 −1, 새 트럭은 +0·세팅 없음
func test_buy_helpers() -> void:
	var s := _game([12], true)
	s.money = 4999999
	check(not Company.can_buy_helper(b, s) and not Company.buy_helper(b, s), "1원 모자란데 사짐")
	s.money = 13000000
	check(Company.buy_helper(b, s), "첫 보조 트럭 안 사짐")
	check_eq([s.money, s.trucks.size(), Company.helper_count(s), Company.helper_price(b, s)], [8000000, 2, 1, 8000000], "1대 뒤")
	check(Company.buy_helper(b, s), "둘째 보조 트럭 안 사짐")
	check_eq([s.money, s.trucks.size(), Company.helper_count(s), Company.helper_price(b, s)], [0, 3, 2, -1], "2대 뒤 (3대째 −1)")
	s.money = RICH
	check(not Company.can_buy_helper(b, s) and not Company.buy_helper(b, s), "3대째 사짐")
	check_eq([s.money, s.trucks.size()], [RICH, 3], "3대째: 그대로")
	check_eq(_events(s, "helper_bought"), [{ "type": "helper_bought", "truck": 1 }, { "type": "helper_bought", "truck": 2 }], "이벤트")
	for k in [1, 2]:
		var t := s.truck(k)
		check_eq([t.star, t.settings, t.lap_cargo, t.success_count], [0, {}, 0, 0], "%d호차: +0·세팅 없음" % (k + 1))
	var rng := _rng(3)
	var paid := Trip.advance(s, b, 2, 3600.0, rng).filter(func(e): return e["type"] == "parcel")
	check(not paid.is_empty(), "새 트럭이 바로 안 달림")


## ④ 개인 기사: 세금 0, 내 돈 = 번 돈
func test_solo_no_tax() -> void:
	var s := _game([18], false)
	check_eq(Company.tax_rate(b, s), 0.0, "개인 기사 세율")
	var ev := _run(s, 0, 20, _rng(4))
	var gross := 0
	var bad := 0
	for e in ev:
		gross += e["gross"]
		if e["pay"] != e["gross"]:
			bad += 1
	check_eq(bad, 0, "개인 기사 pay ≠ gross 인 이벤트 수")
	check_eq([s.money, s.today_sales, s.today_staff, s.today_tax], [gross, gross, 0, 0], "내 돈 = 번 돈, 직원 몫·세금 0")


## ⑤ 대리점 내 트럭: 내 돈 = 번 돈 − 3% (반올림한 세금)
func test_agency_my_truck_tax() -> void:
	var s := _game([18], true)
	s.rush_left = 20   # 급송 ×2 배송도 섞음
	check_eq(Company.tax_rate(b, s), 0.03, "대리점 세율")
	var ev := _run(s, 0, 20, _rng(5))
	var gross := 0
	var bad := 0
	for e in ev:
		gross += e["gross"]
		if e["pay"] != e["gross"] - roundi(e["gross"] * 0.03):
			bad += 1
	check_eq(bad, 0, "내 트럭 pay = 번 돈 − round(번 돈 × 3%%) 아닌 이벤트 수")
	check_eq([s.today_sales, s.today_staff, s.today_tax + s.money], [gross, 0, gross], "직원 몫 0, 세금 + 내 돈 = 번 돈")
	note("내 트럭 +18 20시간: 번 돈 %d, 세금 %d (%.4f), 이벤트 %d개" % [gross, s.today_tax, float(s.today_tax) / gross, ev.size()])


## ⑥ 보조 트럭: 내 돈 = 번 돈 − 30% − 3%, 직원 몫·세금·내 돈의 합 = 번 돈 (1원도 안 틀림, 많이 돌려서)
func test_helper_staff_and_tax() -> void:
	var s := _game([0, 18, 15], true)
	s.weekly_done = true   # 시내에서 20시간 × 2대면 주간 목표(6만 건)를 넘어 보상 돈이 섞여서 (v7-bal C2)
	var ev := _run(s, 1, 20, _rng(6)) + _run(s, 2, 20, _rng(7))
	var gross := 0
	var bad := 0
	for e in ev:
		var g: int = e["gross"]
		gross += g
		if e["pay"] != g - roundi(g * 0.3) - roundi(g * 0.03):
			bad += 1
	check_eq(bad, 0, "보조 트럭 pay = 번 돈 − round(30%%) − round(3%%) 아닌 이벤트 수")
	check_eq(s.today_sales, gross, "오늘 매출 = 번 돈 합")
	check_eq(s.today_staff + s.today_tax + s.money, gross, "직원 몫 + 세금 + 내 돈 = 번 돈")
	check_near(float(s.today_staff) / gross, 0.3, 0.001, "직원 몫 비율")
	check_near(float(s.today_tax) / gross, 0.03, 0.001, "세금 비율")
	# 번 돈 0~20만원 전부, 단계 0~4 세율, 내 트럭·보조 트럭: 합 = 번 돈, 음수 없음
	var wrong := 0
	for stage in b.tax_rates.size():
		s.company_stage = stage
		for g in range(0, 200001, 7):
			for i in [0, 1]:
				var parts: Array = Trip._split(b, s, i, g)
				var staff := roundi(g * 0.3) if i > 0 else 0
				if parts[0] + parts[1] + parts[2] != g or parts[2] < 0 or parts[0] != staff or parts[1] != roundi(g * b.tax_rates[stage]):
					wrong += 1
	check_eq(wrong, 0, "번 돈 0~20만 × 단계 5 × 트럭 2: 틀린 나누기 수")
	note("보조 트럭 2대 20시간: 번 돈 %d, 직원 몫 %d, 세금 %d, 내 돈 %d" % [gross, s.today_staff, s.today_tax, s.money])


## ⑦ 꺼둔 동안도 같은 비율, 결과에 staff·tax
func test_offline_split() -> void:
	var s := _game([10, 15, 18], true)
	var rate := Depot.rate(b, s)
	var gs := []
	for i in 3:
		gs.append(floori(Trip.hourly_income(b, s, i) * 3.0 * rate))
	var r := Trip.apply_offline(s, b, 3 * 3600.0)
	var staff: int = roundi(gs[1] * 0.3) + roundi(gs[2] * 0.3)
	var tax: int = roundi(gs[0] * 0.03) + roundi(gs[1] * 0.03) + roundi(gs[2] * 0.03)
	var sales: int = gs[0] + gs[1] + gs[2]
	check_eq([r["staff"], r["tax"], r["money"]], [staff, tax, sales - staff - tax], "꺼둔 동안 직원 몫·세금·내 돈")
	check_eq(s.money, r["money"], "상태 돈 = 결과 money (떼고 난 내 돈)")
	check_eq([s.today_sales, s.today_staff, s.today_tax], [sales, staff, tax], "오늘 집계에 들어감")
	check_near(float(r["staff"]) / (gs[1] + gs[2]), 0.3, 0.001, "꺼둔 동안 직원 몫 비율")
	check_near(float(r["tax"]) / sales, 0.03, 0.001, "꺼둔 동안 세금 비율")
	var solo := _game([10, 15], false)   # 개인 기사(세금 0)여도 보조 트럭 몫은 뗌
	var r2 := Trip.apply_offline(solo, b, 3 * 3600.0)
	check_eq(r2["tax"], 0, "개인 기사 꺼둔 동안 세금 0")
	note("대리점 3대 3시간: 번 돈 %d → 직원 몫 %d, 세금 %d, 내 돈 %d" % [sales, staff, tax, r["money"]])


## ⑧ hourly_net = 오래 돌린 내 돈 1% 안 (트럭 3대). hourly_sales = 모든 트럭 hourly_income 합
func test_hourly_net() -> void:
	var s := _game([5, 12, 18], true)
	s.weekly_done = true   # 100시간이면 주간 목표 보상 돈(하루치)이 섞여서 (v7-bal)
	var rng := _rng(8)
	var hours := 100
	var sales := 0.0
	for i in 3:
		var before := s.money
		_run(s, i, hours, rng)
		var per_hour := float(s.money - before) / hours
		var net := Trip.hourly_net(b, s, i)
		check_near(per_hour, net, net * 0.01, "트럭 %d (+%d) %d시간 내 돈 / 시간 vs hourly_net" % [i, s.truck(i).star, hours])
		check(net < Trip.hourly_income(b, s, i), "트럭 %d: hourly_net이 hourly_income보다 작지 않음" % i)
		note("트럭 %d +%d: 시간당 번 돈 %.0f, hourly_net %.0f, 돌린 내 돈 %.0f" % [i, s.truck(i).star, Trip.hourly_income(b, s, i), net, per_hour])
		sales += Trip.hourly_income(b, s, i)
	check_near(Company.hourly_sales(b, s), sales, 1e-6, "hourly_sales = hourly_income 합 (떼기 전)")
	var solo := _game([12], false)
	check_near(Trip.hourly_net(b, solo, 0), Trip.hourly_income(b, solo, 0), 1e-9, "개인 기사 hourly_net = hourly_income")


## C3: Company.hourly_net = 모든 트럭 hourly_net 합 (개인 기사면 트럭 0 것), 오래 돌린 내 돈과 1% 안
func test_company_hourly_net() -> void:
	var solo := _game([12], false)
	check_eq(Company.hourly_net(b, solo), Trip.hourly_net(b, solo, 0), "개인 기사 = 트럭 0 hourly_net")
	var s := _game([5, 12, 18], true)
	var sum := Trip.hourly_net(b, s, 0) + Trip.hourly_net(b, s, 1) + Trip.hourly_net(b, s, 2)
	check_near(Company.hourly_net(b, s), sum, 1e-6, "대리점 3대 = 세 값의 합")
	s.weekly_done = true   # 주간 목표 보상 돈이 안 섞이게 (v7-bal)
	var hours := 100
	var rng := _rng(15)
	for i in 3:
		_run(s, i, hours, rng)
	var per_hour := float(s.money) / hours
	check_near(per_hour, sum, sum * 0.01, "3대 %d시간 내 돈 / 시간 vs Company.hourly_net" % hours)
	note("대리점 3대 [+5, +12, +18]: Company.hourly_net %.0f, 돌린 내 돈 %.0f" % [sum, per_hour])


## ⑨ 오늘 집계: 켜 둔·꺼둔 돈이 들어가고 날짜가 바뀌면 0
func test_today() -> void:
	var s := _game([9, 9], true)
	var rng := _rng(9)
	Master.tick(s, b, MON_1116 + 3600, rng)
	check_eq(Company.today(s), { "sales": 0, "staff": 0, "tax": 0, "profit": 0 }, "처음 0")
	var ev := _run(s, 0, 1, rng) + _run(s, 1, 1, rng)
	var gross := 0
	for e in ev:
		gross += e["gross"]
	var t := Company.today(s)
	check_eq([t["sales"], t["profit"]], [gross, s.money], "켜 둔 동안: 매출 = 번 돈, 순이익 = 들어온 내 돈")
	check_eq(t["sales"] - t["staff"] - t["tax"], t["profit"], "순이익 = 매출 − 직원 몫 − 세금")
	check(t["staff"] > 0 and t["tax"] > 0, "직원 몫·세금이 0: %s" % [t])
	var r := Trip.apply_offline(s, b, 2 * 3600.0)
	var t2 := Company.today(s)
	check_eq([t2["sales"], t2["staff"], t2["tax"], t2["profit"]],
			[t["sales"] + r["money"] + r["staff"] + r["tax"], t["staff"] + r["staff"], t["tax"] + r["tax"], t["profit"] + r["money"]],
			"꺼둔 동안 번 것이 더해짐")
	Master.tick(s, b, MON_1116 + DAY - 1, rng)
	check_eq(Company.today(s), t2, "같은 날 23:59:59: 그대로")
	Master.tick(s, b, MON_1116 + DAY, rng)
	check_eq(Company.today(s), { "sales": 0, "staff": 0, "tax": 0, "profit": 0 }, "다음 날 0시: 0")
	# 새 게임·옛 저장(날짜 모름): 첫 tick 전에 번 것은 그날 것으로 남음
	var fresh := _game([0], false)
	_run(fresh, 0, 1, rng)
	var before := Company.today(fresh)
	Master.tick(fresh, b, MON_1116, rng)
	check(before["sales"] > 0 and Company.today(fresh) == before, "날짜 모름 → 첫 tick에서 0이 됨")


## ⑩ 순위: 매출이 라이벌 사이면 그 순위, next_gap 맞음, 전부 넘으면 1위·이벤트 한 번
func test_rank() -> void:
	var solo := _game([10], false)
	check_eq([Company.rank(b, solo), Company.next_gap(b, solo)], [0, 0.0], "대리점 전: 순위 0, gap 0")
	var s := _game([10], true)
	var mine := Company.hourly_sales(b, s)
	check_eq([Company.rank(b, s), Company.next_gap(b, s)], [11, b.rivals[0] - mine], "진짜 json +10 1대: 11위, 첫 라이벌까지")
	var d := real_balance_dict()
	d["company"]["rivals"] = [mine * 0.5, mine * 0.9, mine, mine * 1.1, mine * 2.0, mine * 3.0]
	var b2: Balance = Balance.from_dict(d)
	check(b2.is_ok(), "시험 json: %s" % [b2.errors])
	check_eq(Company.rank(b2, s), 4, "라이벌 셋이 위 (같은 매출은 내가 앞)")
	check_near(Company.next_gap(b2, s), mine * 0.1, 1e-6, "다음 순위까지 = 1.1배 라이벌 − 나")
	Trip.advance(s, b2, 0, 1.0, _rng(10))
	check(not s.rank_first_done and _events(s, "rank_first").is_empty(), "4위인데 1위 이벤트")
	d["company"]["rivals"] = [mine * 0.5, mine * 0.99]
	var b3: Balance = Balance.from_dict(d)
	check_eq([Company.rank(b3, s), Company.next_gap(b3, s)], [1, 0.0], "전부 넘으면 1위, gap 0")
	var solo3 := _game([10], false)
	Trip.advance(solo3, b3, 0, 1.0, _rng(10))
	check(_events(solo3, "rank_first").is_empty(), "대리점 전에 1위 이벤트")
	Trip.advance(s, b3, 0, 1.0, _rng(11))
	check_eq([_events(s, "rank_first").size(), s.rank_first_done], [1, true], "1위 이벤트 한 번")
	Trip.advance(s, b3, 0, 1.0, _rng(12))
	check(_events(s, "rank_first").is_empty(), "1위 이벤트 두 번")


## ⑪ 타이어 정비비 감소가 1건 돈에 반영, 기름값 절감과 합쳐 60% 상한
func test_tire_maint_cut() -> void:
	var s := _game([0], true)
	var u := roundi(2500 * b.routes["city"]["price_mult"])   # 대리점 = 시내 단가 (v7-bal C2)
	var fuel := roundi(u * 0.2)
	check_eq(Trip.parcel_pay(b, s, 0), u - fuel - roundi(u * 0.05), "세팅 없음 1건 돈")
	var tire := s.truck(0).part("tire")
	tire["lines"] = ["maint_cut"]
	check_eq(Trip.parcel_pay(b, s, 0), u - fuel - roundi(u * 0.05 * (1.0 - 0.15)), "순정 정비비 감소 15% (v7-bal 임시)")
	tire["grade"] = 4
	check_eq(Trip.parcel_pay(b, s, 0), u - fuel - roundi(u * 0.05 * (1.0 - 0.6)), "프로토타입 정비비 감소 60%")
	var box := s.truck(0).part("cargo_box")
	box["grade"] = 4
	box["lines"] = ["fuel_cut", "fuel_cut", "fuel_cut"]   # 기름값 절감 135%
	tire["lines"] = ["maint_cut", "maint_cut", "maint_cut"]   # 정비비 감소 180%
	check_eq(Trip.parcel_pay(b, s, 0), u - roundi(u * 0.2 * 0.4) - roundi(u * 0.05 * 0.4), "각자 60%에서 자름 (v7-bal: 합쳐서 자르지 않음)")
	check(Setting.option_chances(b, "tire", 0).has("maint_cut"), "타이어에서 정비비 감소가 안 뜸")
	check(not Setting.option_chances(b, "cargo_box", 4).has("maint_cut"), "적재함에서 정비비 감소가 뜸")
	# 진짜로 돌려서 정비비 감소 줄이 나옴 (가중치 10 / 합 90)
	var rs := _game([0], true)
	rs.money = RICH
	var rng := _rng(11)
	var hits := 0
	for k in 2000:
		Setting.try_roll(rs, b, 0, "tire", rng)
		var lines: Array = rs.truck(0).part("tire")["pending"]["lines"]
		hits += lines.count("maint_cut")
		Setting.choose(rs, 0, "tire", false)
	check(hits > 0, "타이어 2000번 돌려도 정비비 감소 없음")
	note("타이어 2000번: 정비비 감소 줄 %d개" % hits)


## ⑫ 시내 경험치 15(내 트럭), 보조 트럭 배송 경험치 0, 능력치·급송은 내 트럭만
func test_xp_abilities_rush_my_truck_only() -> void:
	var rng := _rng(12)
	for agency in [false, true]:
		var s := _game([0, 0], agency)
		var xp0 := _total_xp(s)
		var n0 := _run(s, 0, 1, rng).filter(func(e): return e["type"] == "parcel").size()
		check_eq(_total_xp(s) - xp0, n0 * (15 if agency else 10), "%s 내 트럭 배송 경험치" % ("대리점" if agency else "개인 기사"))
		var xp1 := _total_xp(s)
		var n1 := _run(s, 1, 1, rng).filter(func(e): return e["type"] == "parcel").size()
		check(n1 > 0, "보조 트럭이 안 달림")
		check_eq(_total_xp(s), xp1, "보조 트럭 배송 경험치 0")
	# 꺼둔 동안 경험치(노하우)도 시내 경험치
	var off := _game([0], true)
	off.ability_points = 59
	off.abilities = { "knowhow": 20 }
	var r := Trip.apply_offline(off, b, 3 * 3600.0)
	check_eq(r["xp"], floori(r["parcels"] * 15 * 0.5 + 1e-9), "꺼둔 동안 경험치 = 배송 × 15 × 노하우 50%")
	# 능력치: 보조 트럭에는 안 들어감
	var s2 := _game([10, 10], true)
	var plain := _game([10, 10], true)
	s2.ability_points = 59
	s2.abilities = { "nego": 20, "kind": 30, "unload": 9 }
	check_eq([Trip.parcel_pay(b, s2, 1), Trip.tip_chance(b, s2, 1)], [Trip.parcel_pay(b, plain, 1), b.tip_base_chance], "보조 트럭 협상·친절 없음")
	check_near(Trip.hourly_income(b, s2, 1), Trip.hourly_income(b, plain, 1), 1e-9, "보조 트럭 시간당 = 능력치 없는 트럭")
	check(Trip.parcel_pay(b, s2, 0) > Trip.parcel_pay(b, plain, 0), "내 트럭에 협상이 안 들어감")
	# 급송: 보조 트럭 배송은 급송 아님, 건수 안 줄어듦
	s2.rush_left = 20
	var e1 := _run(s2, 1, 1, rng).filter(func(e): return e["type"] == "parcel")
	check(e1.all(func(e): return not e["rush"]) and s2.rush_left == 20, "보조 트럭 배송이 급송이 됨")
	var e0 := Trip.advance(s2, b, 0, 3600.0, rng).filter(func(e): return e["type"] == "parcel" and e["rush"])
	check_eq([e0.size(), s2.rush_left], [20, 0], "내 트럭이 급송 20건")


## ⑬ 보조 트럭도 강화·세팅·보험·대형·VIP 됨
func test_helper_enhance_setting_insure_kinds() -> void:
	var s := _game([3, 0], true)
	s.money = RICH
	var rng := _rng(13)
	var tries := 0
	while s.truck(1).star < 3 and tries < 200:
		var out := Enhance.try_enhance(s, b, 1, rng)
		check(out["result"] != Enhance.Result.BLOCKED, "2호차 강화가 막힘")
		tries += 1
	check_eq([s.truck(1).star, s.truck(0).star], [3, 3], "2호차 +3까지, 내 트럭은 그대로")
	check_eq(s.truck(1).success_count + s.truck(1).fail_count, tries, "2호차 통계")
	for part in ["cargo_box", "tire"]:
		check_eq(Setting.try_roll(s, b, 1, part, rng)["ok"], true, "2호차 %s 돌리기" % part)
		Setting.choose(s, 1, part, true)
		check(not s.truck(1).part(part)["lines"].is_empty(), "2호차 %s 줄이 없음" % part)
	check(not s.truck(0).settings.has("tire"), "2호차 세팅이 내 트럭에 들어감")
	# 보험: +20 2호차, 스페어 없이 (보험사가 온 날 가입)
	s.truck(1).star = 20
	s.spares = 0
	check_eq(Enhance.block_reason(s, b, 1), Enhance.Block.NO_SPARE, "보험 없이: 스페어 필요")
	s.visitor_today = "insurer"   # 보험사가 온 날 (Visitor.tick이 채우는 칸)
	s.visitor_day = 20408
	s.insured_day = 20408
	check_eq(Enhance.block_reason(s, b, 1), Enhance.Block.NONE, "보험이면 누를 수 있음")
	var m0 := s.money
	var out := Enhance.try_enhance(s, b, 1, rng)
	check(out["result"] != Enhance.Result.DESTROY and out["result"] != Enhance.Result.BLOCKED, "보험인데 퍼지거나 막힘: %s" % [out])
	check_eq(m0 - s.money, Economy.enhance_cost(b, 20, s) + Economy.insure_fee(b, 20, s), "강화 비용 + 보험료")
	# 대형·VIP: +18 2호차
	s.truck(1).star = 18
	var kinds := {}
	for e in _run(s, 1, 10, rng):
		if e["type"] == "parcel":
			kinds[e["kind"]] = kinds.get(e["kind"], 0) + 1
	check(kinds.get("large", 0) > 0 and kinds.get("vip", 0) > 0, "+18 2호차에 대형·VIP 없음: %s" % [kinds])
	note("+18 2호차 10시간 배송 종류: %s" % [kinds])


## ⑭ 퀘스트 3개: 대리점 창업, 보조 트럭 1대 사기, 타이어·휠 처음 돌리기
func test_quests() -> void:
	var s := GameState.new_game()
	s.quest_index = Quest.count(b) - 3
	s.money = b.agency_price
	check_eq([Quest.current(b, s)["id"], Quest.progress(b, s)], ["found_agency", [0, 1]], "창업 전")
	check(not Quest.check(s, b), "창업 전에 끝남")
	Company.found(b, s)
	check(Quest.check(s, b), "창업했는데 안 끝남")
	check_eq(s.money, 5000000, "창업 퀘스트 보상 500만")
	check_eq([Quest.current(b, s)["id"], Quest.progress(b, s)], ["first_helper", [0, 1]], "보조 트럭 전")
	check(not Quest.check(s, b), "보조 트럭 전에 끝남")
	Company.buy_helper(b, s)
	check(Quest.check(s, b), "보조 트럭 샀는데 안 끝남")
	check_eq(s.money, 3000000, "보조 트럭 퀘스트 보상 300만")
	check_eq([Quest.current(b, s)["id"], Quest.progress(b, s)], ["tire_first", [0, 1]], "타이어 전")
	Setting.try_roll(s, b, 1, "cargo_box", _rng(14))
	check(not Quest.check(s, b), "적재함 돌렸는데 타이어 퀘스트가 끝남")
	check(Setting.try_roll(s, b, 0, "tire", _rng(14))["ok"], "타이어 안 돌려짐")
	check(Quest.check(s, b), "타이어 돌렸는데 안 끝남")
	check_eq(Quest.current(b, s), {}, "다 끝남")
	var done := _events(s, "quest_done").map(func(e): return [e["id"], e["xp"], e["money"]])
	check_eq(done, [["found_agency", 1000, 5000000], ["first_helper", 800, 3000000], ["tire_first", 600, 2000000]], "알림")


## ⑮ 저장 (트럭 3대·회사·오늘 집계), 옛 형식 읽힘, 범위 밖은 자름
func test_save() -> void:
	var s := _game([18, 5, 0], true)
	s.truck(1).part("tire")["lines"] = ["maint_cut"]
	s.truck(1).part("tire")["grade"] = 0
	s.today_day = 20408
	s.today_sales = 123456
	s.today_staff = 30000
	s.today_tax = 3700
	s.rank_first_done = true
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000)))   # 파일처럼 글자로 한 번
	check_eq(d["version"], 11, "저장 형식 11")
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽힘 (%s)" % r["error"])
	var got: GameState = r["state"]
	check_eq([got.company_stage, got.today_day, got.today_sales, got.today_staff, got.today_tax, got.rank_first_done],
			[1, 20408, 123456, 30000, 3700, true], "회사·오늘 집계·1위")
	check_eq(got.trucks.map(func(t): return t.star), [18, 5, 0], "트럭 3대")
	check_eq(got.truck(1).part("tire")["lines"], ["maint_cut"], "2호차 타이어 줄")
	check_eq(Company.today(got), Company.today(s), "today 같음")
	# 형식 9 (회사 칸 없음) → 개인 기사·0·날짜 모름
	var d9 := d.duplicate(true)
	for key in Save.COMPANY_FIELDS:
		d9.erase(key)
	d9["version"] = 9
	var r9 := Save.from_dict(d9, b)
	check_eq(r9["status"], Save.Status.OK, "형식 9 읽힘 (%s)" % r9["error"])
	var g9: GameState = r9["state"]
	check_eq([g9.company_stage, g9.today_day, g9.today_sales, g9.rank_first_done, g9.trucks.size()], [0, -1, 0, false, 3], "형식 9: 처음 값")
	# 범위 밖은 자름
	var dc := d.duplicate(true)
	dc["company_stage"] = 7
	dc["today_sales"] = -5
	dc["trucks"] = dc["trucks"] + dc["trucks"]
	var rc := Save.from_dict(dc, b)
	var gc: GameState = rc["state"]
	check_eq([gc.company_stage, gc.today_sales, gc.trucks.size()], [1, 0, 3], "단계 7 → 1, 음수 → 0, 트럭 6 → 3")
	dc["company_stage"] = -2
	check_eq(Save.from_dict(dc, b)["state"].company_stage, 0, "단계 −2 → 0")
	for bad in [["company_stage", "agency"], ["today_tax", null], ["rank_first_done", 1]]:
		var db := d.duplicate(true)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)
