## upgrade.gd: 물류센터 업그레이드 (v8a C1). 레벨·가격·사기, 대리점이면 못 삼·효과 유지, 한 바퀴 계산(단가·싣는 시간·적재량),
## 꺼둔 동안, json 묶음이 없으면 꺼짐, 숫자 검사, 저장 형식 13
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Upgrade = preload("res://scripts/core/upgrade.gd")

var b: Balance = Balance.load_file()
## depot_upgrades 묶음을 지운 숫자 (기능 꺼짐)
var b_off: Balance = _off_balance()

const PRICES := {
	"zone": [100000, 300000, 800000, 2000000, 5000000],
	"sort": [50000, 150000, 400000, 1000000, 2500000],
	"box": [80000, 250000, 700000, 1800000, 4500000],
}


func _off_balance() -> Balance:
	var d := real_balance_dict()
	d.erase("depot_upgrades")
	return Balance.from_dict(d)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 세 업그레이드를 다 lv로 (돈 안 씀)
func _with_levels(lv: int) -> GameState:
	var s := GameState.new_game()
	for id in Upgrade.IDS:
		s.depot_upgrades[id] = lv
	return s


## 레벨·가격·효과: Lv0~5 가격표, 효과 = per_level × 레벨, 다 사면 -1
func test_levels_prices_values() -> void:
	check_eq(Upgrade.IDS, ["zone", "sort", "box"], "id 3개")
	check(Upgrade.enabled(b), "json에 묶음이 있는데 꺼짐")
	var s := GameState.new_game()
	for id in Upgrade.IDS:
		check_eq([Upgrade.level(s, id), Upgrade.max_level(b, id), Upgrade.value(b, s, id)], [0, 5, 0.0], "%s 처음: Lv0 / 5, 효과 0" % id)
		var prices := []
		for lv in 6:
			s.depot_upgrades[id] = lv
			prices.append(Upgrade.price(b, s, id))
		check_eq(prices, PRICES[id] + [-1], "%s 다음 레벨 값 (Lv5는 -1)" % id)
	var s2 := _with_levels(2)
	check_near(Upgrade.value(b, s2, "zone"), 0.04, 1e-12, "zone Lv2 = 단가 +4%")
	check_near(Upgrade.value(b, s2, "sort"), 0.12, 1e-12, "sort Lv2 = 싣는 시간 −12%")
	check_eq(Upgrade.value(b, s2, "box"), 2.0, "box Lv2 = +2건")
	var s5 := _with_levels(5)
	check_near(Upgrade.value(b, s5, "zone"), 0.10, 1e-12, "zone Lv5 = +10%")
	check_near(Upgrade.value(b, s5, "sort"), 0.30, 1e-12, "sort Lv5 = −30%")
	check_eq(Upgrade.value(b, s5, "box"), 5.0, "box Lv5 = +5건")
	check_near(Upgrade.value_at(b, "zone", 3), 0.06, 1e-12, "value_at: zone Lv3 (다음 효과 표시용)")


## 사기: 1원 모자라면 못 삼, 딱 맞으면 삼 (돈 −값, 레벨 +1), 다섯 번 사면 끝
func test_buy() -> void:
	for id in Upgrade.IDS:
		var s := GameState.new_game()
		s.money = PRICES[id][0] - 1
		check(not Upgrade.can_buy(b, s, id), "%s: 1원 모자란데 살 수 있음" % id)
		check(not Upgrade.buy(b, s, id), "%s: 1원 모자란데 삼" % id)
		check_eq([s.money, Upgrade.level(s, id)], [PRICES[id][0] - 1, 0], "%s: 못 샀는데 상태가 바뀜" % id)
		s.money = PRICES[id][0]
		check(Upgrade.buy(b, s, id), "%s: 딱 맞는 돈으로 못 삼" % id)
		check_eq([s.money, Upgrade.level(s, id)], [0, 1], "%s: 산 뒤 돈·레벨" % id)
		var rich := GameState.new_game()
		rich.money = 100_000_000
		var n := 0
		while Upgrade.buy(b, rich, id):
			n += 1
		var spent := 0
		for p in PRICES[id]:
			spent += p
		check_eq([n, Upgrade.level(rich, id), rich.money, Upgrade.can_buy(b, rich, id)], [5, 5, 100_000_000 - spent, false],
				"%s: 끝까지 사면 5번, Lv5, 쓴 돈 %d, 더 못 삼" % [id, spent])


## 대리점이면 못 삼 (돈이 많아도), 산 효과는 그대로 모든 트럭에
func test_agency_cannot_buy_keeps_effect() -> void:
	var s := _with_levels(2)
	s.money = 1_000_000_000
	s.company_stage = GameState.AGENCY
	for id in Upgrade.IDS:
		check(not Upgrade.can_buy(b, s, id), "%s: 대리점인데 살 수 있음" % id)
		check(not Upgrade.buy(b, s, id), "%s: 대리점인데 삼" % id)
		check_eq(Upgrade.level(s, id), 2, "%s: 대리점 뒤에도 레벨 그대로" % id)
	check_eq(s.money, 1_000_000_000, "대리점: 돈 그대로")
	s.trucks.append(TruckState.new())   # 보조 트럭
	# 시내: 단가 round(2500 × 1.2 × 1.04) = 3120, 적재량 (20 + 2) × 2 = 44, 싣는 시간 10 × 2 × 0.88 = 17.6
	for i in 2:
		check_eq(Trip._unit(b, s, i), 3120, "트럭 %d 시내 단가 (구역 +4%%)" % i)
		check_eq(Trip.cargo(b, s, i), 44.0, "트럭 %d 시내 적재량 (+2건 × 집 2배)" % i)
		check_near(Trip._load(b, s, i), 17.6, 1e-9, "트럭 %d 시내 싣는 시간 (−12%%)" % i)


## 한 바퀴 계산 (+0, 동네, 세 업그레이드 Lv2): 단가 2600 → 배송 1건 2600 − 520 − 130 = 1950, 적재량 22,
## 싣는 시간 8.8초 → 한 바퀴 8.8 + 120 + 22 × 0.5 = 139.8초, 시간당 22 × (1950 + 팁 2% × 2600) × 3600 / 139.8
func test_lap_numbers() -> void:
	var s := _with_levels(2)
	check_eq(Trip._unit(b, s, 0), 2600, "단가")
	check_eq(Trip.parcel_pay(b, s, 0), 1950, "배송 1건 돈")
	check_eq(Trip.cargo(b, s, 0), 22.0, "평균 적재량")
	check_eq(Trip.lap_cargo(b, s, 0), 22, "이번 바퀴 건수")
	check_near(Trip._load(b, s, 0), 8.8, 1e-9, "싣는 시간")
	check_near(Trip.lap_seconds(b, s, 0), 139.8, 1e-9, "한 바퀴 초")
	var hourly := 22 * (1950 + 0.02 * 2600) * 3600.0 / 139.8
	check_near(Trip.hourly_income(b, s, 0), hourly, 1e-6, "시간당 수입")
	# 레벨 0 = 원래 숫자 그대로 (단가 2500, 1건 1875, 20건, 140초)
	var s0 := GameState.new_game()
	check_eq([Trip._unit(b, s0, 0), Trip.parcel_pay(b, s0, 0), Trip.cargo(b, s0, 0)], [2500, 1875, 20.0], "Lv0: 원래 숫자")
	check_near(Trip.lap_seconds(b, s0, 0), 140.0, 1e-9, "Lv0: 한 바퀴 140초")
	# 진짜로 한 바퀴 돌리면 22건, 배송 돈 = 22 × 1950
	var events := Trip.advance(s, b, 0, 139.8 + 1e-6, _rng(3))
	var gross := 0
	var parcels := 0
	for ev in events:
		if ev["type"] == "parcel":
			parcels += 1
			gross += ev["gross"]
	check_eq([parcels, gross, s.parcels_total], [22, 22 * 1950, 22], "한 바퀴: 22건, 배송 돈 22 × 1950")
	note("+0 Lv2×3: 1건 %d원, %d건, 한 바퀴 %.1f초, 시간당 %.0f원 (Lv0 %.0f원)"
			% [Trip.parcel_pay(b, s, 0), Trip.lap_cargo(b, s, 0), Trip.lap_seconds(b, s, 0), Trip.hourly_income(b, s, 0), Trip.hourly_income(b, s0, 0)])


## 꺼둔 동안도 업그레이드 식으로 (시간당 수입 × 시간 × 야간팀 비율, 배송 = 적재량 × 3600 / 한 바퀴 초 × …)
func test_offline_uses_upgrades() -> void:
	var s := _with_levels(5)
	var hourly := Trip.hourly_income(b, s, 0)
	var parcels_per_hour := 25.0 * 3600.0 / (10.0 * 0.7 + 120.0 + 25 * 0.5)
	var r := Trip.apply_offline(s, b, 2 * 3600.0)
	check_eq(r["money"], floori(hourly * 2.0 * 0.5), "꺼둔 2시간 돈 = 시간당 × 2 × 0.5")
	check_eq(r["parcels"], floori(parcels_per_hour * 2.0 * 0.5), "꺼둔 2시간 배송 (25건, 싣기 7초)")
	var r0 := Trip.apply_offline(GameState.new_game(), b, 2 * 3600.0)
	check(r["money"] > r0["money"], "업그레이드가 꺼둔 동안 돈을 안 늘림 (%d ≤ %d)" % [r["money"], r0["money"]])
	note("꺼둔 2시간 (+0): Lv5×3 %d원 / Lv0 %d원" % [r["money"], r0["money"]])


## json 묶음이 없으면 꺼짐: 읽힘, 효과 0 (레벨이 있어도), 못 삼, 저장에서 레벨 버림
func test_disabled_without_group() -> void:
	check(b_off.is_ok(), "묶음 없는 json이 안 읽힘: %s" % ", ".join(b_off.errors))
	check(not Upgrade.enabled(b_off), "묶음이 없는데 켜짐")
	var s := _with_levels(3)
	s.money = 100_000_000
	for id in Upgrade.IDS:
		check_eq([Upgrade.max_level(b_off, id), Upgrade.price(b_off, s, id), Upgrade.can_buy(b_off, s, id), Upgrade.buy(b_off, s, id),
				Upgrade.value(b_off, s, id), Upgrade.value_at(b_off, id, 3)], [0, -1, false, false, 0.0, 0.0], "%s: 꺼짐" % id)
	check_eq(s.money, 100_000_000, "꺼짐: 돈 그대로")
	var s0 := GameState.new_game()
	check_eq([Trip._unit(b_off, s, 0), Trip.cargo(b_off, s, 0), Trip._load(b_off, s, 0)], [Trip._unit(b, s0, 0), Trip.cargo(b, s0, 0), Trip._load(b, s0, 0)],
			"꺼짐: 레벨 3이어도 Lv0 숫자")
	var r := Save.from_dict(JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000))), b_off)
	check_eq(r["status"], Save.Status.OK, "꺼짐: 저장이 읽힘 (%s)" % r["error"])
	check_eq(r["state"].depot_upgrades, {}, "꺼짐: 저장의 레벨은 버림")


## 숫자 검사: 모르는 id, 빠진 id, sort 합 1 넘음, box 소수, 값 줄어듦, 빈 가격, 묶음이 아님
func test_validation() -> void:
	var cases := [
		[func(u): u["turbo"] = { "per_level": 0.1, "prices": [1] }, "모르는 업그레이드"],
		[func(u): u.erase("box"), "depot_upgrades.box 이 없거나"],
		[func(u): u["sort"]["per_level"] = 0.25, "싣는 시간이 0 아래로"],
		[func(u): u["box"]["per_level"] = 1.5, "depot_upgrades.box.per_level"],
		[func(u): u["zone"]["per_level"] = 0, "depot_upgrades.zone.per_level"],
		[func(u): u["zone"]["prices"] = [300000, 100000], "줄면 안 됨"],
		[func(u): u["zone"]["prices"] = [], "빈 목록"],
		[func(u): u["box"]["prices"] = [1.5], "depot_upgrades.box.prices[0]"],
	]
	for c in cases:
		var d := real_balance_dict()
		c[0].call(d["depot_upgrades"])
		var errs: PackedStringArray = Balance.from_dict(d).errors
		check(Array(errs).any(func(e): return e.contains(c[1])), "'%s' 오류가 안 나옴: %s" % [c[1], errs])
	var d2 := real_balance_dict()
	d2["depot_upgrades"] = [1, 2]
	check(Array(Balance.from_dict(d2).errors).any(func(e): return e.contains("depot_upgrades 가 { } 묶음이 아님")), "목록이면 오류")


## 저장 형식 13: 레벨 왕복, 형식 12는 Lv0, 범위 밖은 자름, 모르는 id는 버림, 숫자가 아니면 깨진 저장
func test_save() -> void:
	var s := GameState.new_game()
	s.depot_upgrades = { "zone": 2, "box": 5 }
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000)))
	check_eq(d["version"], 13.0, "저장 형식 13")
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽힘 (%s)" % r["error"])
	check_eq(r["state"].depot_upgrades, { "zone": 2, "box": 5 }, "레벨 왕복")
	var d12 := d.duplicate(true)
	d12["version"] = 12
	d12.erase("depot_upgrades")
	var g12: GameState = Save.from_dict(d12, b)["state"]
	check_eq([g12.depot_upgrades, Upgrade.level(g12, "zone")], [{}, 0], "형식 12: Lv0")
	var dx := d.duplicate(true)
	dx["depot_upgrades"] = { "zone": 9, "sort": -2, "box": 2.7, "turbo": 3 }
	check_eq(Save.from_dict(dx, b)["state"].depot_upgrades, { "zone": 5, "box": 2 }, "9 → 5, −2 → 0(버림), 2.7 → 2, 모르는 id 버림")
	for bad in [{ "zone": "x" }, [1, 2], 3]:
		var db := d.duplicate(true)
		db["depot_upgrades"] = bad
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "depot_upgrades = %s 를 못 걸러냄" % [bad])
