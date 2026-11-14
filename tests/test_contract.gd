## v7b C2: 기업 계약 (contract.gd) — 평판 기준마다 자동 체결 (최대 3), 맺을 때 금액 고정, 협상, 켜 둔 동안 쌓기 (세금 뗌),
## 순위 매출엔 안 넣고 hourly_net엔 넣음, 오늘 집계·장부, 꺼둔 동안, 날짜 바뀌면 0, 퀘스트 3개, 저장
extends "res://tests/test_base.gd"

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Contract = preload("res://scripts/core/contract.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

const MON_1116 := 1794787200   # 2026-11-16 월 0시 (현지 시각으로 넘김)
const DAY := 86400

var b: Balance = Balance.load_file()


## 트럭들 (단계 목록), 대리점이면 agency, 퀘스트·주간 목표 끝 (보상 돈이 안 섞이게)
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


func _events(s: GameState) -> Array:
	return s.take_events().filter(func(e): return e["type"] == "contract")


## json "contracts" = 시작값 (평판 기준은 v7b C4 시뮬), 틀린 숫자는 막힘
func test_json_contracts() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.contract_reputation, PackedInt64Array([200000, 1700000, 3600000]), "평판 기준 (v7b C4: 가볍게 만렙 뒤 1 / 3 / 6주)")
	check_eq(b.contract_shares, PackedFloat64Array([0.05, 0.07, 0.10]), "매출의 5 / 7 / 10%")
	for c in [
		[func(d): d.erase("contracts"), "\"contracts\" 묶음이 없음"],
		[func(d): d["contracts"]["reputation"] = [], "contracts.reputation 이 없거나 빈 목록"],
		[func(d): d["contracts"]["reputation"] = [150000, 100000, 900000], "contracts.reputation[1] = 100000"],
		[func(d): d["contracts"]["reputation"] = [150000, 4.5, 900000], "contracts.reputation[1] = 4.5"],
		[func(d): d["contracts"]["sales_share"] = [0.05, 0.07], "contracts.sales_share 길이"],
		[func(d): d["contracts"]["sales_share"] = [0.05, 1.5, 0.1], "contracts.sales_share[1] = 1.5"],
		[func(d): d["quests"].back()["target"] = 4, "quests[%d].target = 4" % (b.quests.size() - 1)],
	]:
		var d := real_balance_dict()
		c[0].call(d)
		var bad: Balance = Balance.from_dict(d)
		check(not bad.is_ok() and ", ".join(bad.errors).contains(c[1]), "%s 를 못 잡음: %s" % [c[1], bad.errors])


## 체결: 대리점에서만, 평판 기준에 닿을 때마다 한 번에 하나, 최대 3. 금액 = 그 순간 순위 매출 × 비율 (버림), 그 뒤 그대로
func test_sign() -> void:
	var solo := _game([20], false)
	solo.reputation = 1_000_000_000
	Contract.tick(solo, b, 1.0)
	check_eq([Contract.count(solo), _events(solo).size()], [0, 0], "개인 기사는 평판이 넘쳐도 계약 없음")
	var s := _game([10], true)
	s.reputation = 199_999
	Contract.tick(s, b, 1.0)
	check_eq([Contract.count(s), Contract.next_reputation(b, s)], [0, 200000], "평판 199,999: 아직")
	var sales := Company.hourly_sales(b, s)
	s.reputation = 200_000
	Contract.tick(s, b, 0.0)
	var want0 := floori(sales * 0.05)
	check_eq([Contract.count(s), s.contracts, Contract.next_reputation(b, s)], [1, [want0], 1700000], "평판 20만: 1개 = 시간당 매출 × 5%")
	check_eq(_events(s), [{ "type": "contract", "index": 0, "hourly": want0 }], "체결 알림")
	Contract.tick(s, b, 0.0)
	check_eq(Contract.count(s), 1, "다음 기준 전에는 더 안 맺음")
	s.reputation = 1_000_000_000
	Contract.tick(s, b, 0.0)
	check_eq(Contract.count(s), 2, "평판이 한꺼번에 넘어도 tick 한 번에 하나")
	Contract.tick(s, b, 0.0)
	Contract.tick(s, b, 0.0)
	check_eq([Contract.count(s), Contract.next_reputation(b, s)], [3, -1], "최대 3, 다음 기준 없음")
	check_eq(s.contracts, [want0, floori(sales * 0.07), floori(sales * 0.10)], "5 / 7 / 10%")
	check_eq(_events(s).map(func(e): return e["index"]), [1, 2], "알림 2개 더")
	s.truck(0).star = 25   # 매출이 올라도 맺은 금액은 그대로
	check(Company.hourly_sales(b, s) > sales * 1.5, "준비: 매출이 오름")
	check_eq(s.contracts, [want0, floori(sales * 0.07), floori(sales * 0.10)], "맺은 금액 그대로")
	check_near(Contract.hourly(b, s), want0 + floori(sales * 0.07) + floori(sales * 0.10), 1e-6, "시간당 합")
	note("+10 시내 트럭 1대: 시간당 매출 %d → 계약 %s" % [floori(sales), s.contracts])


## 협상: 지금 찍은 값으로 그때그때 (계약 금액 × (1 + 협상))
func test_nego() -> void:
	var s := _game([10], true)
	s.contracts = [200000, 300000]
	check_near(Contract.hourly_of(b, s, 1), 300000.0, 1e-9, "협상 0")
	s.ability_points = 20
	for k in 10:
		Ability.add(b, s, "nego")
	check_near(Contract.hourly_of(b, s, 0), 220000.0, 1e-6, "협상 10% → × 1.1")
	check_near(Contract.hourly(b, s), 550000.0, 1e-6, "합 × 1.1")
	Ability.reset(s)
	check_near(Contract.hourly(b, s), 500000.0, 1e-6, "초기화하면 바로 원래대로")


## 켜 둔 동안: 1시간을 1/60초씩 → 시간당 금액이 정수로 쌓임, 세금 3% (조금씩 들어와도 빠짐), 직원 몫 없음, 오늘 집계에
func test_tick_money() -> void:
	var s := _game([10], true)
	s.contracts = [100000]
	for k in 3600 * 60:
		Contract.tick(s, b, 1.0 / 60.0)
	var got := s.today_contract
	check(got >= 99999 and got <= 100000, "1시간 계약 번 돈 %d ≈ 100,000 (소수 이월 오차 1원 안쪽)" % got)
	check(s.contract_carry >= 0.0 and s.contract_carry < 1.0, "이월 0~1: %s" % s.contract_carry)
	check_eq(s.today_tax, roundi(got * 0.03), "세금 = 계약 번 돈 × 3% (반올림)")
	check_eq(s.money, got - s.today_tax, "내 돈 = 번 돈 − 세금")
	check_eq(Company.today(s), { "sales": got, "staff": 0, "tax": s.today_tax, "profit": s.money, "contract": got }, "오늘 장부: 매출에 계약 포함")
	var none := _game([10], true)
	Contract.tick(none, b, 3600.0)
	check_eq([none.money, none.today_sales, none.contract_carry], [0, 0, 0.0], "계약 없으면 0")


## 순위 매출(hourly_sales)엔 안 넣고, 켜 둔 동안 내 돈(hourly_net, "약 N분 뒤")엔 세금 뗀 값으로
func test_rank_and_net() -> void:
	var s := _game([18, 10], true)
	var trucks_sales := Trip.hourly_income(b, s, 0) + Trip.hourly_income(b, s, 1)
	var trucks_net := Trip.hourly_net(b, s, 0) + Trip.hourly_net(b, s, 1)
	var rank := Company.rank(b, s)
	s.contracts = [5_000_000_000]
	check_near(Company.hourly_sales(b, s), trucks_sales, 1e-6, "순위 매출 = 트럭만")
	check_eq(Company.rank(b, s), rank, "계약이 커도 순위 그대로")
	check_near(Company.hourly_net(b, s), trucks_net + 5_000_000_000 * 0.97, 1e-3, "hourly_net = 트럭 + 계약 × (1 − 세금 3%)")


## 꺼둔 동안: 계약 시간당 × 시간(창고 상한까지) × 야간팀 %. "contract" = 계약 번 돈, 세금은 "tax"·내 돈은 "money"에 포함
func test_offline() -> void:
	var s := _game([10], true)
	var twin := _game([10], true)
	s.contracts = [100000]
	var r := Trip.apply_offline(s, b, 3 * 3600.0)   # 창고 4시간, 야간팀 50%
	var r0 := Trip.apply_offline(twin, b, 3 * 3600.0)
	check_eq([r["contract"], r0["contract"]], [150000, 0], "계약 = 10만 × 3시간 × 0.5")
	check_eq([r["tax"] - r0["tax"], r["money"] - r0["money"], r["staff"] - r0["staff"]], [4500, 145500, 0], "세금 3% 떼고 내 돈, 직원 몫 없음")
	check_eq(Company.today(s)["contract"], 150000, "오늘 계약 몫")
	check_eq(Company.today(s)["sales"] - Company.today(twin)["sales"], 150000, "오늘 매출에 포함")
	var long := _game([10], true)
	long.contracts = [100000]
	check_eq(Trip.apply_offline(long, b, 20 * 3600.0)["contract"], 200000, "창고 4시간까지만 (× 0.5)")
	var quick := _game([10], true)
	quick.contracts = [100000]
	var rq := Trip.apply_offline(quick, b, 60.0)
	check_eq([rq["ignored"], rq["contract"], quick.money], [true, 0, 0], "3분 안이면 없음")


## 날짜가 바뀌면 오늘 계약 몫도 0
func test_today_rolls() -> void:
	var s := _game([10], true)
	var rng := RandomNumberGenerator.new()
	Master.tick(s, b, MON_1116 + 3600, rng)
	s.contracts = [360000]
	Contract.tick(s, b, 10.0)
	check_eq(Company.today(s)["contract"], 1000, "10초 = 1,000원")
	Master.tick(s, b, MON_1116 + DAY - 1, rng)
	check_eq(Company.today(s)["contract"], 1000, "같은 날 그대로")
	Master.tick(s, b, MON_1116 + DAY, rng)
	check_eq(Company.today(s), { "sales": 0, "staff": 0, "tax": 0, "profit": 0, "contract": 0 }, "다음 날 0")


## 퀘스트 3개 (목록 끝): 장거리 처음 보내기 → 터보 처음 돌리기 → 기업 계약 1개
func test_quests() -> void:
	var n := Quest.count(b)
	var tail := b.quests.slice(n - 3)
	check_eq(tail.map(func(q): return [q["id"], q["kind"], q["target"], q["part"], q["xp"], q["money"]]), [
		["long_first", "long_laps", 1, "", 800, 3000000],
		["turbo_first", "part_rolled", 1, "turbo", 600, 2000000],
		["contract_first", "contracts", 1, "", 1000, 5000000]], "끝 3개 (보상 = 창업 뒤 3개와 같은 크기)")
	var s := _game([10], true)
	s.quest_index = n - 3
	check(not Quest.check(s, b), "장거리 안 갔는데 끝남")
	s.truck(0).route = "long"
	Trip.advance(s, b, 0, 1.0, RandomNumberGenerator.new())   # 첫 바퀴가 장거리로 출발 → long_laps 1 → 그 안에서 Quest.check
	check_eq(s.quest_index, n - 2, "장거리 첫 바퀴 → 끝")
	check(not Quest.check(s, b), "터보 안 돌렸는데 끝남")
	s.parts_rolled["turbo"] = true
	check(Quest.check(s, b), "터보 돌림 → 끝")
	check(not Quest.check(s, b), "계약 없는데 끝남")
	s.contracts = [1]
	check(Quest.check(s, b), "계약 1개 → 끝")
	check(Quest.current(b, s).is_empty(), "다 끝남")


## 저장 형식 12: 계약 칸 왕복, 형식 11은 처음 값, 범위 밖은 자름, 틀린 모양은 깨진 저장
func test_save() -> void:
	var s := _game([10], true)
	s.contracts = [231000, 323400]
	s.contract_carry = 0.25
	s.today_contract = 777
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000)))
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽힘 (%s)" % r["error"])
	var got: GameState = r["state"]
	check_eq([got.contracts, got.contract_carry, got.today_contract], [[231000, 323400], 0.25, 777], "계약 칸")
	check_eq(typeof(got.contracts[0]), TYPE_INT, "계약 금액은 정수")
	var d11 := d.duplicate(true)
	d11["version"] = 11
	for key in ["contracts", "contract_carry", "today_contract"]:
		d11.erase(key)
	var g11: GameState = Save.from_dict(d11, b)["state"]
	check_eq([g11.contracts, g11.contract_carry, g11.today_contract], [[], 0.0, 0], "형식 11: 처음 값")
	var dc := d.duplicate(true)
	dc["contracts"] = [5, -7, 9.9, 11, 12]
	dc["contract_carry"] = 3.5
	dc["today_contract"] = -1
	var gc: GameState = Save.from_dict(dc, b)["state"]
	check_eq([gc.contracts, gc.contract_carry, gc.today_contract], [[5, 0, 9], 0.999999, 0], "기준 수 3개까지, 음수 0, 소수 버림, 이월 1 미만")
	for bad in [["contracts", "x"], ["contracts", ["a"]], ["contract_carry", null], ["today_contract", "1"]]:
		var db := d.duplicate(true)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)
