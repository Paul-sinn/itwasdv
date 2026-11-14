## v7-bal C2: 노선 틀 + 시내 (trip.gd route_id, balance.json routes). 창업하면 모든 트럭이 시내:
## 단가 × price_mult, 도로 × road_mult, 한 바퀴 싣는 수·싣는 시간 × stops_mult. 한 바퀴·수입·꺼둔 동안·팁·화면용 lap_progress
extends "res://tests/test_base.gd"

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
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


## +star 트럭 0 하나 (보조 트럭은 helpers개), 퀘스트·주간 목표 끝 (보상 돈이 안 섞이게). unload = 상하차 포인트
func _game(star: int, agency: bool, unload: int = 0, helpers: int = 0) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	s.weekly_done = true
	if agency:
		s.company_stage = GameState.AGENCY
	for k in helpers:
		var t := TruckState.new()
		t.star = star
		s.trucks.append(t)
	s.ability_points = unload
	for k in unload:
		Ability.add(b, s, "unload")
	return s


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 손으로 옮긴 한 바퀴 초 (싣기 10초 × stops, 도로 12000칸 × road ÷ 출력, 정차 0.5초 × 20건 × stops, 상하차 u)
func _lap(power: int, route: String, u: float = 0.0) -> float:
	var r: Dictionary = b.routes[route]
	return 10.0 * r["stops_mult"] * (1.0 - u) + 12000.0 * r["road_mult"] / power + 20.0 * r["stops_mult"] * 0.5 * (1.0 - u)


## json "routes" = 지시서 "옮길 숫자" (시내 셋은 임시), 틀린 숫자는 막힘
func test_json_routes() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.routes, { "town": { "price_mult": 1.0, "road_mult": 1.0, "stops_mult": 1.0 },
			"city": { "price_mult": 1.5, "road_mult": 0.5, "stops_mult": 1.5 } }, "동네 1·1·1, 시내 단가 1.5·도로 0.5·집 수 1.5")
	for c in [
		[func(d): d.erase("routes"), "\"routes\" 묶음이 없음"],
		[func(d): d["routes"].erase("city"), "routes.city 가 없거나"],
		[func(d): d["routes"]["town"]["stops_mult"] = 0, "routes.town.stops_mult = 0"],
		[func(d): d["routes"]["city"]["road_mult"] = -0.5, "routes.city.road_mult = -0.5"],
		[func(d): d["routes"]["city"].erase("price_mult"), "routes.city.price_mult 이 없음"],
		[func(d): d["routes"]["city"]["price_mult"] = "1.5", "routes.city.price_mult 가 숫자가 아님"],
	]:
		var d := real_balance_dict()
		c[0].call(d)
		var bad: Balance = Balance.from_dict(d)
		check(not bad.is_ok() and ", ".join(bad.errors).contains(c[1]), "%s 를 못 잡음: %s" % [c[1], bad.errors])


## 노선: 개인 기사 = 동네, 대리점 = 시내 (모든 트럭)
func test_route_id() -> void:
	var solo := _game(0, false, 0, 2)
	var agency := _game(0, true, 0, 2)
	check_eq([Trip.route_id(solo, 0), Trip.route_id(solo, 1), Trip.route_id(solo, 2)], ["town", "town", "town"], "개인 기사: 모두 동네")
	check_eq([Trip.route_id(agency, 0), Trip.route_id(agency, 1), Trip.route_id(agency, 2)], ["city", "city", "city"], "대리점: 모두 시내")


## 창업 전후 한 바퀴 시간·수입 (같은 트럭, 회사 단계만 바꿈). 동네 = 예전 값 그대로
func test_before_after_agency() -> void:
	for star in [0, 10]:   # 대형·VIP 전 (손으로 셈)
		var p := Trip.power(b, star)
		var solo := _game(star, false)
		var city := _game(star, true)
		check_near(Trip.lap_seconds(b, solo, 0), 10.0 + 12000.0 / p + 20 * 0.5, 1e-9, "+%d 동네 한 바퀴 (예전 그대로)" % star)
		check_near(Trip.lap_seconds(b, city, 0), 15.0 + 6000.0 / p + 30 * 0.5, 1e-9, "+%d 시내 한 바퀴 = 싣기 15 + 도로 6000칸 + 30집" % star)
		check_near(Trip.avg_lap_seconds(b, city, 0), 15.0 + 6000.0 / p + 30 * 0.5, 1e-9, "+%d 시내 평균 한 바퀴" % star)
		check_eq([Trip.cargo(b, solo, 0), Trip.lap_cargo(b, solo, 0)], [20.0, 20], "+%d 동네 20집" % star)
		check_eq([Trip.cargo(b, city, 0), Trip.lap_cargo(b, city, 0)], [30.0, 30], "+%d 시내 30집" % star)
		check_eq([Trip.parcel_pay(b, solo, 0), Trip.tip_pay(b, solo, 0)], [2500 - 500 - 125, 2500], "+%d 동네 1건 1875, 팁 2500" % star)
		check_eq([Trip.parcel_pay(b, city, 0), Trip.tip_pay(b, city, 0)], [3750 - 750 - 188, 3750], "+%d 시내 단가 3750: 1건 2812, 팁 3750" % star)
		check_eq(Trip.lap_income(b, city, 0), 30 * 2812, "+%d 시내 한 바퀴 수입" % star)
		var want := 30 * (2812 + 0.02 * 3750) * 3600.0 / (15.0 + 6000.0 / p + 15.0)
		check_near(Trip.hourly_income(b, city, 0), want, 1e-6, "+%d 시내 시간당 = 30 × (2812 + 팁 2%% × 3750) × 3600 ÷ 한 바퀴" % star)
		check_near(Trip.hourly_net(b, city, 0), 30 * ((2812 - 84) + 0.02 * (3750 - 113)) * 3600.0 / (30.0 + 6000.0 / p), 1e-6,
				"+%d 시내 내 돈 (세금 3%% 뗀 1건·팁)" % star)
	for star in [0, 10, 15, 18, 20, 25, 30]:
		var solo := _game(star, false)
		var city := _game(star, true)
		var ls := Trip.avg_lap_seconds(b, solo, 0)
		var lc := Trip.avg_lap_seconds(b, city, 0)
		var hs := Trip.hourly_income(b, solo, 0)
		var hc := Trip.hourly_income(b, city, 0)
		check(hc > hs, "+%d 창업하면 시간당 수입이 오름" % star)
		note("+%d 한 바퀴 동네 %.1f초 → 시내 %.1f초 (×%.2f) / 한 바퀴 수입 %d → %d / 시간당 번 돈 %d → %d (×%.2f), 내 돈 %d → %d" % [star,
				ls, lc, lc / ls, Trip.lap_income(b, solo, 0), Trip.lap_income(b, city, 0), floori(hs), floori(hc), hc / hs,
				floori(Trip.hourly_net(b, solo, 0)), floori(Trip.hourly_net(b, city, 0))])


## 상하차 최대(30포인트 = 30%)의 수입 효과: 동네와 시내. 시내는 도로가 짧고 집이 많아 효과가 큼 (목표 2배 이상은 C3 시뮬)
func test_unload_effect_town_vs_city() -> void:
	check_eq(Ability.value(b, _game(0, false, 30), "unload"), 0.3, "상하차 30포인트 = 30%")
	for star in [0, 10, 15, 18, 20, 25, 30]:
		var p := Trip.power(b, star)
		var effect := {}
		for route in ["town", "city"]:
			var agency: bool = route == "city"
			var plain := _game(star, agency)
			var full := _game(star, agency, 30)
			check_near(Trip.lap_seconds(b, full, 0), _lap(p, route, 0.3), 1e-9, "+%d %s 상하차 30%%: 싣기·정차 × 0.7" % [star, route])
			effect[route] = Trip.hourly_income(b, full, 0) / Trip.hourly_income(b, plain, 0) - 1.0
			check_near(effect[route], _lap(p, route) / _lap(p, route, 0.3) - 1.0, 1e-9, "+%d %s 효과 = 한 바퀴가 줄어든 만큼" % [star, route])
		check(effect["city"] > effect["town"], "+%d 시내 효과가 동네보다 큼" % star)
		note("+%d 상하차 30%% 시간당 수입 효과: 동네 +%.2f%%, 시내 +%.2f%% (시내 ÷ 동네 = %.2f배)" % [star,
				effect["town"] * 100.0, effect["city"] * 100.0, effect["city"] / effect["town"]])


## 켜 둔 동안: 시내 한 바퀴 30집 (집 번호 0~29), 1시간 배송 수·돈이 평균과 맞음. 바퀴 중간에 창업하면 실은 건수는 다음 바퀴부터
func test_city_advance() -> void:
	var s := _game(10, false)
	var rng := _rng(1)
	var houses_before := {}
	for e in Trip.advance(s, bn, 0, 50.0, rng):   # 동네 첫 바퀴 중간까지
		if e["type"] == "parcel":
			houses_before[e["house"]] = true
	s.company_stage = GameState.AGENCY   # 창업
	var first_lap_max := -1
	var houses := {}
	var parcels := 0
	var gross := 0
	var laps := 0
	var t := s.truck(0)
	for k in 3600 * 10:   # 1시간을 0.1초씩
		for e in Trip.advance(s, bn, 0, 0.1, rng):
			if e["type"] != "parcel":
				continue
			if laps == 0:
				first_lap_max = maxi(first_lap_max, e["house"])
			else:
				houses[e["house"]] = true
				parcels += 1
				gross += e["gross"]
			if e["house"] == t.lap_cargo - 1:
				laps += 1
	check_eq(first_lap_max, 19, "창업한 바퀴: 이미 실은 20건까지 (동네에서 %d건 배송)" % houses_before.size())
	check_eq([houses.keys().min(), houses.keys().max(), houses.size()], [0, 29, 30], "그 뒤 바퀴: 집 번호 0~29 (30집)")
	check_eq(Trip.lap_cargo(bn, s, 0), 30, "lap_cargo = 이번 바퀴 집 수 30")
	check_eq(gross, parcels * Trip.parcel_pay(bn, s, 0), "배송 돈 = 건수 × 시내 1건 2812")
	var per_hour := 30.0 * 3600.0 / Trip.avg_lap_seconds(bn, s, 0)
	check(absf(parcels - per_hour) <= 30.0 + 30.0, "1시간 배송 %d건 ≈ 평균 %.1f건 (창업한 바퀴 몫 + 한 바퀴 안쪽)" % [parcels, per_hour])
	note("시내 +10: 창업 뒤 1시간 배송 %d건 (평균 %.1f건/시간), 배송 돈 %d원" % [parcels, per_hour, gross])


## 소수 적재량도 시내에서 stops_mult를 곱한 평균으로 확률 굴림 (21.6 × 1.5 = 32.4 → 32 또는 33)
func test_city_cargo_fraction() -> void:
	var s := _game(0, true)
	var box := s.truck(0).part("cargo_box")
	box["lines"] = ["cargo"]
	box["grade"] = 1
	var c := Trip.cargo(b, s, 0)
	var town := _game(0, false)
	town.trucks[0] = s.truck(0)
	check_near(c, Trip.cargo(b, town, 0) * 1.5, 1e-9, "시내 평균 = 동네 평균 × 1.5")
	check(c != floorf(c), "소수 평균: %s" % c)
	var rng := _rng(2)
	var sum := 0
	var bad := 0
	for k in 4000:
		Trip.advance(s, bn, 0, Trip.lap_seconds(bn, s, 0), rng)
		var n := s.truck(0).lap_cargo
		sum += n
		bad += 0 if n == floori(c) or n == ceili(c) else 1
	check_eq(bad, 0, "실은 건수가 내림·올림 둘 중 하나가 아닌 바퀴")
	check_near(sum / 4000.0, c, 0.03, "4000바퀴 평균 실은 건수")
	note("시내 적재량 1줄(%s): 평균 %.3f건, 4000바퀴 실은 건수 평균 %.3f" % [b.setting_options["cargo"]["values"][1], c, sum / 4000.0])


## 꺼둔 동안: 시내 숫자(단가·도로·집 수)로 배송·돈. 보조 트럭도 시내
func test_city_offline() -> void:
	for agency in [false, true]:
		var s := _game(10, agency, 0, 1)
		var r := Trip.apply_offline(s, b, 3 * 3600.0)   # 창고 Lv1 4시간 안, 야간팀 50%
		var lap := 70.0 if agency else 100.0   # +10 출력 150: 시내 15 + 40 + 15, 동네 10 + 80 + 10
		var n := 30 if agency else 20
		var pay := 2812 if agency else 1875
		var tip := 3750 if agency else 2500
		var per_truck := floori(n * 3600.0 / lap * 3.0 * 0.5)
		check_eq(r["parcels"], per_truck * 2, "%s 꺼둔 3시간 배송 = 트럭마다 %d건/시간 × 3 × 0.5" % [Trip.route_id(s, 0), floori(n * 3600.0 / lap)])
		var gross := floori(n * (pay + 0.02 * tip) * 3600.0 / lap * 3.0 * 0.5)
		check_eq(s.today_sales, gross * 2, "%s 꺼둔 동안 번 돈 = 시간당 × 3 × 0.5 (트럭 2대)" % Trip.route_id(s, 0))
		note("+10 트럭 2대 꺼둔 3시간 (%s): 배송 %d건, 번 돈 %d, 내 돈 %d" % [Trip.route_id(s, 0), r["parcels"], s.today_sales, r["money"]])


## 화면용 lap_progress: 싣는 동안 0, 그 뒤 바퀴 끝까지 고르게 1까지 (싣는 시간은 노선·상하차 반영)
func test_lap_progress() -> void:
	for c in [[false, 0, 10.0], [true, 0, 15.0], [true, 30, 10.5]]:
		var s := _game(10, c[0], c[1])
		var load_s: float = c[2]
		var lap := Trip.lap_seconds(b, s, 0)
		var t := s.truck(0)
		var clocks := [0.0, load_s, (load_s + lap) / 2.0, lap, lap + 5.0]
		var want := [0.0, 0.0, 0.5, 1.0, 1.0]
		for k in clocks.size():
			t.lap_clock = clocks[k]
			check_near(Trip.lap_progress(b, s, 0), want[k], 1e-9, "%s 상하차 %d: %.2f초 → %s (출발 0, 싣고 0, 가운데 0.5, 끝 1)"
					% [Trip.route_id(s, 0), c[1], clocks[k], want[k]])
