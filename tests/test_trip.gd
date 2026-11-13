## trip.gd: 출력·한 바퀴·배송 돈·시간당 수입, 트럭 진행(advance), 스페어 드랍, 꺼둔 동안
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

const STARS := [0, 10, 18, 30]

var b: Balance = Balance.load_file()


## 지시서 계산식을 손으로 옮긴 값 (trip.gd를 거치지 않음)
func _expected(star: int) -> Dictionary:
	var gain := [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 10, 10, 10, 10, 10, 20, 20, 20, 20, 20, 35, 35, 35, 35, 35, 60, 60, 60, 60, 60]
	var power := 100
	for s in star:
		power += gain[s]
	var lap := 10.0 + 12000.0 / power + 5 * 2.0
	var pay := 100 - 10 - 5
	return { "power": power, "lap": lap, "pay": pay, "lap_income": 5 * pay, "hourly": 5 * pay * 3600.0 / lap }


func _game(star: int) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	return s


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 지시서 C1 ①: +0/+10/+18/+30의 출력·한 바퀴 초·시간당 수입이 식과 같음 (C3 시뮬 --table과 맞춰 볼 값)
func test_lap_numbers_match_formula() -> void:
	check_eq(Trip.parcel_pay(b), 85, "배송 1건 돈 = 100 − 10 − 5")
	check_eq(typeof(Trip.parcel_pay(b)), TYPE_INT, "배송 1건 돈이 정수가 아님")
	for star in STARS:
		var e := _expected(star)
		var t := _game(star).truck(0)
		check_eq(Trip.power(b, star), e["power"], "+%d 출력" % star)
		check_eq(Trip.speed(b, t), float(e["power"]), "+%d 속도" % star)
		check_eq(Trip.cargo(b, t), 5, "+%d 적재량" % star)
		check_near(Trip.lap_seconds(b, t), e["lap"], 1e-9, "+%d 한 바퀴 초" % star)
		check_eq(Trip.lap_income(b, t), e["lap_income"], "+%d 한 바퀴 수입" % star)
		check_near(Trip.hourly_income(b, t), e["hourly"], 1e-6, "+%d 시간당 수입" % star)
		note("+%d: 출력 %d, 한 바퀴 %.4f초, 한 바퀴 수입 %d원, 시간당 %.4f원"
				% [star, Trip.power(b, star), Trip.lap_seconds(b, t), Trip.lap_income(b, t), Trip.hourly_income(b, t)])
	# 지시서 "이 값이면 +0 시간당 약 1만 900원(한 바퀴 140초)"
	check_near(Trip.lap_seconds(b, _game(0).truck(0)), 140.0, 1e-9, "+0 한 바퀴 140초")
	check_eq(Trip.power(b, 30), 775, "+30 출력 = 100 + 675")


## 단계만 바꿔 본 시간당 수입 ("성공하면 시간당")
func test_hourly_income_at() -> void:
	var t := _game(10).truck(0)
	check_near(Trip.hourly_income_at(b, t, 11), Trip.hourly_income(b, _game(11).truck(0)), 1e-9, "+10 트럭의 +11 시간당")
	check_eq(t.star, 10, "hourly_income_at이 트럭 단계를 바꿈")
	for star in range(1, b.max_star + 1):
		check(Trip.hourly_income_at(b, t, star) > Trip.hourly_income_at(b, t, star - 1), "+%d 시간당이 +%d보다 안 큼" % [star, star - 1])


## 지시서 C1 ②: advance로 3600초 돌린 돈이 시간당 수입과 한 바퀴 수입 1번치 안쪽
func test_hour_of_advance_matches_hourly() -> void:
	for star in STARS:
		var s := _game(star)
		var t := s.truck(0)
		var events := Trip.advance(s, b, 0, 3600.0, _rng(1))
		var hourly := Trip.hourly_income(b, t)
		var gap := absf(s.money - hourly)
		check(gap <= Trip.lap_income(b, t), "+%d: 1시간 돈 %d, 시간당 %.1f, 차이 %.1f > 한 바퀴 %d"
				% [star, s.money, hourly, gap, Trip.lap_income(b, t)])
		var paid := 0
		for ev in events:
			if ev["type"] == "parcel":
				paid += ev["pay"]
		check_eq(paid, s.money, "+%d: 이벤트 돈 합 = 늘어난 돈" % star)
		note("+%d: advance 1시간 %d원 / 시간당 %.1f원 (차이 %.1f, 허용 %d)" % [star, s.money, hourly, gap, Trip.lap_income(b, t)])


## 지시서 C1 ③: 0.1초씩 나눠 돌려도 한 번에 돌린 것과 돈·배송 수가 같음
func test_small_steps_equal_one_step() -> void:
	for star in STARS:
		var one := _game(star)
		var one_events := Trip.advance(one, b, 0, 3600.0, _rng(7))
		var many := _game(star)
		var rng := _rng(7)
		var many_events := []
		for k in 36000:
			many_events.append_array(Trip.advance(many, b, 0, 0.1, rng))
		check_eq(many.money, one.money, "+%d: 0.1초씩 돈" % star)
		check_eq(_count(many_events, "parcel"), _count(one_events, "parcel"), "+%d: 0.1초씩 배송 수" % star)
		check_eq(many.spares, one.spares, "+%d: 0.1초씩 스페어" % star)
		note("+%d: 1시간 한 번에 %d원·배송 %d건 / 0.1초씩 %d원·배송 %d건"
				% [star, one.money, _count(one_events, "parcel"), many.money, _count(many_events, "parcel")])


## 한 바퀴 안의 배송 시각: i번째 집 = 싣기 + (도로 ÷ 속도) × i ÷ (N+1) + i × 정차, 집 번호 0~N-1
func test_house_times_in_one_lap() -> void:
	var s := _game(0)   # 속도 100: 도로 120초. 집 i = 10 + 20i + 2i
	var rng := _rng(3)
	var want := [32.0, 54.0, 76.0, 98.0, 120.0]
	# 0.5초 단위로 움직여서 시각이 2진수로 정확히 떨어지게 함
	for i in 5:
		var before := Trip.advance(s, b, 0, want[i] - 0.5 - s.truck(0).lap_clock, rng)
		check_eq(_count(before, "parcel"), 0, "%d번째 집: 시각 전에 배송됨" % (i + 1))
		var at := Trip.advance(s, b, 0, 0.5, rng)
		check_eq(_count(at, "parcel"), 1, "%d번째 집: %s초에 배송 안 됨" % [i + 1, want[i]])
		if not at.is_empty():
			check_eq(at[0]["house"], i, "%d번째 집 번호" % (i + 1))
			check_eq(at[0]["pay"], 85, "%d번째 집 돈" % (i + 1))
	# 마지막 집 뒤 남은 길 20초 → 140초에 새 바퀴
	Trip.advance(s, b, 0, 139.5 - s.truck(0).lap_clock, rng)
	check_eq(s.truck(0).lap_delivered, 5, "140초 전: 아직 이번 바퀴")
	Trip.advance(s, b, 0, 1.0, rng)
	check_eq(s.truck(0).lap_delivered, 0, "140초: 새 바퀴")
	check_eq(s.truck(0).lap_clock, 0.5, "새 바퀴 시각 (140.5 − 140)")
	check_eq(s.money, 5 * 85, "한 바퀴 돈")
	check_eq(Trip.advance(s, b, 0, 0.0, rng), [], "0초 진행 → 이벤트 없음")
	check_eq(Trip.advance(s, b, 0, -5.0, rng), [], "음수 진행 → 이벤트 없음")
	check_eq(s.truck(0).lap_clock, 0.5, "0·음수 진행에 시각이 바뀜")


## 지시서 C1 ④: 스페어 드랍 seed 고정 10만 건, 확률 0.05로 바꾼 balance로 1%p 안쪽
func test_spare_drop_rate() -> void:
	var d := real_balance_dict()
	d["engine"]["spare_drop_chance"] = 0.05
	var b5: Balance = Balance.from_dict(d)
	check(b5.is_ok(), "확률 0.05 balance가 막힘")
	var s := _game(30)
	var t := s.truck(0)
	var events := []
	var rng := _rng(4242)
	for lap in 20000:   # 한 바퀴씩 진행 = 5건씩 → 10만 건
		events.append_array(Trip.advance(s, b5, 0, Trip.lap_seconds(b5, t), rng))
	var parcels := _count(events, "parcel")
	var spares := _count(events, "spare")
	check_eq(parcels, 100000, "배송 수")
	var rate := spares / float(parcels)
	check_near(rate, 0.05, 0.01, "스페어 드랍률 (배송 %d건 중 %d개)" % [parcels, spares])
	check_eq(s.spares, spares, "스페어 이벤트 수 = 늘어난 스페어")
	note("스페어 드랍: 배송 %d건 중 %d개 = %.3f%% (목표 5%%, 허용 1%%p)" % [parcels, spares, rate * 100.0])
	# 스페어 이벤트는 배송 바로 뒤에만 나옴
	for k in events.size():
		if events[k]["type"] == "spare":
			check(k > 0 and events[k - 1]["type"] == "parcel", "스페어 이벤트 앞이 배송이 아님 (%d번째)" % k)
			break


## 바퀴 중간에 강화돼서 빨라지면 남은 집은 새 속도로 (지난 집은 바로 배송)
func test_star_change_mid_lap() -> void:
	var s := _game(0)
	var rng := _rng(1)
	Trip.advance(s, b, 0, 60.0, rng)   # +0: 32, 54초 두 집
	check_eq(s.truck(0).lap_delivered, 2, "60초에 두 집")
	s.truck(0).star = 10   # 출력 150 → 도로 80초: 집 i = 10 + 13.33i + 2i → 3번째 집 56초는 이미 지남, 4번째 71.3초
	var ev := Trip.advance(s, b, 0, 0.5, rng)
	check_eq(_count(ev, "parcel"), 1, "빨라진 뒤 지난 3번째 집이 바로 배송")
	check_eq(s.truck(0).lap_delivered, 3, "4번째 집은 아직")
	check_eq(_count(Trip.advance(s, b, 0, 11.0, rng), "parcel"), 1, "71.5초에 4번째 집")


## 트럭 i만 진행
func test_advance_moves_only_truck_i() -> void:
	var s := _game(0)
	s.trucks.append(TruckState.new())
	Trip.advance(s, b, 1, 100.0, _rng(1))
	check_eq(s.truck(0).lap_clock, 0.0, "트럭 0이 움직임")
	check_eq(s.truck(1).lap_delivered, 4, "트럭 1: 100초에 네 집")


## 지시서 C1 ⑦: 꺼둔 동안. 0초 이하 0, 상한 넘으면 상한까지, 스페어 소수 나머지가 이어짐
func test_offline() -> void:
	var hour := 3600.0
	for away in [0.0, -3 * hour]:
		var s := _game(10)
		var r := Trip.apply_offline(s, b, away)
		check_eq(r, { "money": 0, "parcels": 0, "spares": 0, "hours": 0.0 }, "%s초 꺼둠 → 전부 0" % away)
		check_eq([s.money, s.spares, s.spare_drop_carry], [0, 0, 0.0], "%s초 꺼둠: 상태가 바뀜" % away)

	# +0, 3시간: 시간당 425 × 3600 ÷ 140 = 10928.57 → × 3 × 0.5 = 16392.86 → 16392
	#            배송 5 × 3600 ÷ 140 × 3 × 0.5 = 192.86 → 192
	var s3 := _game(0)
	var r3 := Trip.apply_offline(s3, b, 3 * hour)
	check_eq(r3["hours"], 3.0, "3시간 꺼둠 → 3시간")
	check_eq(r3["money"], 16392, "3시간 꺼둠 돈")
	check_eq(r3["parcels"], 192, "3시간 꺼둠 배송")
	check_eq(typeof(r3["money"]), TYPE_INT, "꺼둔 동안 돈이 정수가 아님")
	check_eq(s3.money, 16392, "상태에 돈이 더해짐")

	# 20시간 → 상한 8시간
	var s20 := _game(0)
	var r20 := Trip.apply_offline(s20, b, 20 * hour)
	check_eq(r20["hours"], 8.0, "20시간 꺼둠 → 상한 8시간")
	check_eq(r20["money"], floori(5 * 85 * 3600.0 / 140.0 * 8.0 * 0.5), "20시간 꺼둠 돈 = 8시간치의 절반")
	check_eq(r20["money"], Trip.apply_offline(_game(0), b, 8 * hour)["money"], "20시간 = 8시간")

	# 트럭마다 floor해서 더함
	var s2 := _game(0)
	s2.trucks.append(TruckState.new())
	s2.truck(1).star = 10
	var r2 := Trip.apply_offline(s2, b, 3 * hour)
	var want := floori(Trip.hourly_income(b, s2.truck(0)) * 3.0 * 0.5) + floori(Trip.hourly_income(b, s2.truck(1)) * 3.0 * 0.5)
	check_eq(r2["money"], want, "트럭 2대 돈 = 트럭마다 더함")


## 꺼둔 동안 스페어: 배송 × 확률을 소수 나머지에 쌓고 정수만큼 +
func test_offline_spare_carry() -> void:
	# 진짜 확률 0.0002: +0 8시간 배송 514건 → 0.1028씩. 10번이면 1.028 → 스페어 1, 나머지 0.028
	var s := _game(0)
	var got := 0
	for k in 10:
		var r := Trip.apply_offline(s, b, 20 * 3600.0)
		check_eq(r["parcels"], 514, "%d번째 배송 수" % (k + 1))
		got += r["spares"]
		if k < 9:
			check_eq(s.spares, 0, "%d번째: 1이 안 됐는데 스페어 +" % (k + 1))
	check_eq(got, 1, "10번 꺼둔 동안 스페어 합")
	check_eq(s.spares, 1, "10번 뒤 스페어")
	check_near(s.spare_drop_carry, 0.028, 1e-9, "10번 뒤 소수 나머지")

	# 확률 0.01: 514 × 0.01 = 5.14 → 5개, 나머지 0.14 → 다음에 10.28 → 5개, 나머지 0.28
	var d := real_balance_dict()
	d["engine"]["spare_drop_chance"] = 0.01
	var b1: Balance = Balance.from_dict(d)
	var s1 := _game(0)
	check_eq(Trip.apply_offline(s1, b1, 20 * 3600.0)["spares"], 5, "첫 번째 스페어")
	check_near(s1.spare_drop_carry, 0.14, 1e-9, "첫 번째 나머지")
	check_eq(Trip.apply_offline(s1, b1, 20 * 3600.0)["spares"], 5, "두 번째 스페어")
	check_near(s1.spare_drop_carry, 0.28, 1e-9, "두 번째 나머지 (이어짐)")
	check_eq(s1.spares, 10, "스페어 합")


func _count(events: Array, type: String) -> int:
	var n := 0
	for ev in events:
		if ev["type"] == type:
			n += 1
	return n
