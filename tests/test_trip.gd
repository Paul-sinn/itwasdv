## trip.gd: 출력·한 바퀴·배송 돈·시간당 수입, 트럭 진행(advance), 스페어 드랍, 꺼둔 동안, 세팅 효과(v4)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")

const STARS := [0, 10, 18, 30]

var b: Balance = Balance.load_file()
## v3 숫자(단가 100, 적재량 5, 정차 2초, 스페어 드랍 0.0002): 집마다 시각이 딱 떨어져서, 시각·배송 수를 손으로 계산한 테스트에 씀
var bv3: Balance = _v3_balance()


func _v3_balance() -> Balance:
	var d := real_balance_dict()
	d["trip"]["unit_price"] = 100
	d["trip"]["base_cargo"] = 5
	d["trip"]["stop_seconds"] = 2
	d["engine"]["spare_drop_chance"] = 0.0002
	return Balance.from_dict(d)


## 지시서 계산식을 손으로 옮긴 값 (trip.gd를 거치지 않음). v4 숫자: 단가 2500, 적재량 20, 정차 0.5초
func _expected(star: int) -> Dictionary:
	var gain := [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 10, 10, 10, 10, 10, 20, 20, 20, 20, 20, 35, 35, 35, 35, 35, 60, 60, 60, 60, 60]
	var power := 100
	for s in star:
		power += gain[s]
	var lap := 10.0 + 12000.0 / power + 20 * 0.5
	var pay := 2500 - 250 - 125
	var v3_hourly := 5 * 85 * 3600.0 / (10.0 + 12000.0 / power + 5 * 2.0)
	return { "power": power, "lap": lap, "pay": pay, "lap_income": 20 * pay, "hourly": 20 * pay * 3600.0 / lap, "v3_hourly": v3_hourly }


## 퀘스트는 다 끝낸 상태로 (v5): 여기서는 배송 돈만 본다. 퀘스트 보상은 test_quest.gd
func _game(star: int) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.quest_index = Quest.count(b)
	return s


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## v4 C1 ⑫ (v3 C1 ①): +0/+10/+18/+30의 출력·한 바퀴 초·시간당 수입이 식과 같음, v3의 100배 (C2 시뮬 --table과 맞춰 볼 값)
func test_lap_numbers_match_formula() -> void:
	var t0 := _game(0).truck(0)
	check_eq(Trip.parcel_pay(b, t0), 2125, "배송 1건 돈 = 2500 − 250 − 125")
	check_eq(typeof(Trip.parcel_pay(b, t0)), TYPE_INT, "배송 1건 돈이 정수가 아님")
	for star in STARS:
		var e := _expected(star)
		var t := _game(star).truck(0)
		check_eq(Trip.power(b, star), e["power"], "+%d 출력" % star)
		check_eq(Trip.speed(b, t), float(e["power"]), "+%d 속도" % star)
		check_eq(Trip.cargo(b, t), 20, "+%d 적재량" % star)
		check_near(Trip.lap_seconds(b, t), e["lap"], 1e-9, "+%d 한 바퀴 초" % star)
		check_near(Trip.avg_lap_seconds(b, t), e["lap"], 1e-9, "+%d 평균 한 바퀴 초 (오버부스트 없음)" % star)
		check_eq(Trip.lap_income(b, t), e["lap_income"], "+%d 한 바퀴 수입" % star)
		check_near(Trip.hourly_income(b, t), e["hourly"], 1e-6, "+%d 시간당 수입" % star)
		check_near(Trip.hourly_income(b, t), e["v3_hourly"] * 100.0, 1e-6, "+%d 시간당 수입 = v3의 100배" % star)
		note("+%d: 출력 %d, 한 바퀴 %.4f초, 한 바퀴 수입 %d원, 시간당 %.4f원"
				% [star, Trip.power(b, star), Trip.lap_seconds(b, t), Trip.lap_income(b, t), Trip.hourly_income(b, t)])
	# 지시서 "한 바퀴 140초도 그대로"
	check_near(Trip.lap_seconds(b, t0), 140.0, 1e-9, "+0 한 바퀴 140초")
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


## 한 바퀴 안의 배송 시각: i번째 집 = 싣기 + (도로 ÷ 속도) × i ÷ (N+1) + i × 정차, 집 번호 0~N-1 (v3 숫자)
func test_house_times_in_one_lap() -> void:
	var s := _game(0)   # 속도 100: 도로 120초. 집 i = 10 + 20i + 2i
	var rng := _rng(3)
	var want := [32.0, 54.0, 76.0, 98.0, 120.0]
	# 0.5초 단위로 움직여서 시각이 2진수로 정확히 떨어지게 함
	for i in 5:
		var before := Trip.advance(s, bv3, 0, want[i] - 0.5 - s.truck(0).lap_clock, rng)
		check_eq(_count(before, "parcel"), 0, "%d번째 집: 시각 전에 배송됨" % (i + 1))
		var at := Trip.advance(s, bv3, 0, 0.5, rng)
		check_eq(_count(at, "parcel"), 1, "%d번째 집: %s초에 배송 안 됨" % [i + 1, want[i]])
		if not at.is_empty():
			check_eq(at[0]["house"], i, "%d번째 집 번호" % (i + 1))
			check_eq(at[0]["pay"], 85, "%d번째 집 돈" % (i + 1))
	# 마지막 집 뒤 남은 길 20초 → 140초에 새 바퀴
	Trip.advance(s, bv3, 0, 139.5 - s.truck(0).lap_clock, rng)
	check_eq(s.truck(0).lap_delivered, 5, "140초 전: 아직 이번 바퀴")
	Trip.advance(s, bv3, 0, 1.0, rng)
	check_eq(s.truck(0).lap_delivered, 0, "140초: 새 바퀴")
	check_eq(s.truck(0).lap_clock, 0.5, "새 바퀴 시각 (140.5 − 140)")
	check_eq(s.money, 5 * 85, "한 바퀴 돈")
	check_eq(Trip.advance(s, bv3, 0, 0.0, rng), [], "0초 진행 → 이벤트 없음")
	check_eq(Trip.advance(s, bv3, 0, -5.0, rng), [], "음수 진행 → 이벤트 없음")
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
	for lap in 5000:   # 한 바퀴씩 진행 = 20건씩 → 10만 건
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
	Trip.advance(s, bv3, 0, 60.0, rng)   # +0: 32, 54초 두 집
	check_eq(s.truck(0).lap_delivered, 2, "60초에 두 집")
	s.truck(0).star = 10   # 출력 150 → 도로 80초: 집 i = 10 + 13.33i + 2i → 3번째 집 56초는 이미 지남, 4번째 71.3초
	var ev := Trip.advance(s, bv3, 0, 0.5, rng)
	check_eq(_count(ev, "parcel"), 1, "빨라진 뒤 지난 3번째 집이 바로 배송")
	check_eq(s.truck(0).lap_delivered, 3, "4번째 집은 아직")
	check_eq(_count(Trip.advance(s, bv3, 0, 11.0, rng), "parcel"), 1, "71.5초에 4번째 집")


## 트럭 i만 진행
func test_advance_moves_only_truck_i() -> void:
	var s := _game(0)
	s.trucks.append(TruckState.new())
	Trip.advance(s, bv3, 1, 100.0, _rng(1))
	check_eq(s.truck(0).lap_clock, 0.0, "트럭 0이 움직임")
	check_eq(s.truck(1).lap_delivered, 4, "트럭 1: 100초에 네 집")


## 지시서 C1 ⑦: 꺼둔 동안. 3분 미만(음수 포함)은 무시, 상한(창고 Lv1 4시간) 넘으면 상한까지, 스페어 소수 나머지가 이어짐
func test_offline() -> void:
	var hour := 3600.0
	for away in [0.0, -3 * hour]:
		var s := _game(10)
		var r := Trip.apply_offline(s, bv3, away)
		check_eq(r, { "money": 0, "parcels": 0, "spares": 0, "hours": 0.0, "xp": 0, "full": false, "ignored": true }, "%s초 꺼둠 → 무시" % away)
		check_eq([s.money, s.spares, s.spare_drop_carry, s.parcels_total], [0, 0, 0.0, 0], "%s초 꺼둠: 상태가 바뀜" % away)

	# (v3 숫자) +0, 3시간: 시간당 425 × 3600 ÷ 140 = 10928.57 → × 3 × 0.5 = 16392.86 → 16392
	#            배송 5 × 3600 ÷ 140 × 3 × 0.5 = 192.86 → 192
	var s3 := _game(0)
	var r3 := Trip.apply_offline(s3, bv3, 3 * hour)
	check_eq(r3["hours"], 3.0, "3시간 꺼둠 → 3시간")
	check_eq(r3["money"], 16392, "3시간 꺼둠 돈")
	check_eq(r3["parcels"], 192, "3시간 꺼둠 배송")
	check_eq(typeof(r3["money"]), TYPE_INT, "꺼둔 동안 돈이 정수가 아님")
	check_eq(s3.money, 16392, "상태에 돈이 더해짐")
	check_eq(s3.parcels_total, 192, "꺼둔 동안 배송이 parcels_total에 더해짐")
	check_eq([r3["xp"], r3["full"], r3["ignored"]], [0, false, false], "3시간: 경험치 0, 창고 안 참, 무시 아님")

	# 20시간 → 상한 (창고 Lv1 4시간)
	var s20 := _game(0)
	var r20 := Trip.apply_offline(s20, bv3, 20 * hour)
	check_eq(r20["hours"], 4.0, "20시간 꺼둠 → 상한 4시간")
	check_eq(r20["money"], floori(5 * 85 * 3600.0 / 140.0 * 4.0 * 0.5), "20시간 꺼둠 돈 = 4시간치의 절반")
	check_eq(r20["money"], Trip.apply_offline(_game(0), bv3, 4 * hour)["money"], "20시간 = 4시간")
	check(r20["full"], "20시간인데 창고가 안 참")

	# 트럭마다 floor해서 더함
	var s2 := _game(0)
	s2.trucks.append(TruckState.new())
	s2.truck(1).star = 10
	var r2 := Trip.apply_offline(s2, bv3, 3 * hour)
	var want := floori(Trip.hourly_income(bv3, s2.truck(0)) * 3.0 * 0.5) + floori(Trip.hourly_income(bv3, s2.truck(1)) * 3.0 * 0.5)
	check_eq(r2["money"], want, "트럭 2대 돈 = 트럭마다 더함")


## 꺼둔 동안 스페어: 배송 × 확률을 소수 나머지에 쌓고 정수만큼 +
func test_offline_spare_carry() -> void:
	# (v3 숫자) 확률 0.0002: +0 8시간(창고 Lv3) 배송 514건 → 0.1028씩. 10번이면 1.028 → 스페어 1, 나머지 0.028
	var s := _game(0)
	s.warehouse_level = 3
	var got := 0
	for k in 10:
		var r := Trip.apply_offline(s, bv3, 20 * 3600.0)
		check_eq(r["parcels"], 514, "%d번째 배송 수" % (k + 1))
		got += r["spares"]
		if k < 9:
			check_eq(s.spares, 0, "%d번째: 1이 안 됐는데 스페어 +" % (k + 1))
	check_eq(got, 1, "10번 꺼둔 동안 스페어 합")
	check_eq(s.spares, 1, "10번 뒤 스페어")
	check_near(s.spare_drop_carry, 0.028, 1e-9, "10번 뒤 소수 나머지")

	# 확률 0.01: 514 × 0.01 = 5.14 → 5개, 나머지 0.14 → 다음에 10.28 → 5개, 나머지 0.28
	var d := real_balance_dict()
	d["trip"]["unit_price"] = 100
	d["trip"]["base_cargo"] = 5
	d["trip"]["stop_seconds"] = 2
	d["engine"]["spare_drop_chance"] = 0.01
	var b1: Balance = Balance.from_dict(d)
	var s1 := _game(0)
	s1.warehouse_level = 3
	check_eq(Trip.apply_offline(s1, b1, 20 * 3600.0)["spares"], 5, "첫 번째 스페어")
	check_near(s1.spare_drop_carry, 0.14, 1e-9, "첫 번째 나머지")
	check_eq(Trip.apply_offline(s1, b1, 20 * 3600.0)["spares"], 5, "두 번째 스페어")
	check_near(s1.spare_drop_carry, 0.28, 1e-9, "두 번째 나머지 (이어짐)")
	check_eq(s1.spares, 10, "스페어 합")


## 부품에 등급·줄을 바로 넣는다 (세팅 효과 확인용)
func _put(t: TruckState, part: String, grade: int, lines: Array) -> void:
	var p := t.part(part)
	p["grade"] = grade
	p["lines"] = lines


## v4 C1 ⑨: 이동 속도 줄 → 속도·한 바퀴 초 (부품 둘의 줄을 다 더함)
func test_setting_speed() -> void:
	var t := _game(10).truck(0)   # 출력 150
	_put(t, "cargo_box", 2, ["speed", "junk_cupholder", "cargo"])   # 스포츠 이동 속도 8%
	check_near(Trip.speed(b, t), 150.0 * 1.08, 1e-9, "속도 = 150 × 1.08")
	_put(t, "ecu", 1, ["speed", "speed"])                           # + 스트리트 5% × 2
	check_near(Trip.speed(b, t), 150.0 * (1.0 + 0.08 + 0.05 + 0.05), 1e-9, "속도 = 150 × 1.18 (두 부품 합)")
	check_near(Trip.lap_seconds(b, t), 10.0 + 12000.0 / (150.0 * 1.18) + Trip.cargo(b, t) * 0.5, 1e-9, "한 바퀴 초")
	check_near(Trip.hourly_income_at(b, t, 11), Trip.lap_income(b, t) * 3600.0 / (10.0 + 12000.0 / (160.0 * 1.18) + Trip.cargo(b, t) * 0.5),
			1e-6, "성공하면 시간당도 세팅 반영")


## v4 C1 ⑨: 적재량 5% 한 줄 → N 21. N = floor(20 × (1 + 합))
func test_setting_cargo() -> void:
	var t := _game(0).truck(0)
	_put(t, "cargo_box", 0, ["cargo"])
	check_eq(Trip.cargo(b, t), 21, "적재량 5% 한 줄 → 21")
	check_eq(Trip.lap_income(b, t), 21 * 2125, "한 바퀴 수입 = 21건")
	_put(t, "cargo_box", 1, ["cargo", "junk_radio"])
	check_eq(Trip.cargo(b, t), 21, "8% 한 줄 → floor(21.6) = 21")
	_put(t, "cargo_box", 3, ["cargo", "cargo"])
	check_eq(Trip.cargo(b, t), 28, "20% 두 줄 → 28 (27.999… 로 1건 모자라지 않음)")
	_put(t, "cargo_box", 4, ["cargo", "cargo", "cargo"])
	check_eq(Trip.cargo(b, t), 38, "30% 세 줄 → 38")
	check_near(Trip.lap_seconds(b, t), 10.0 + 120.0 + 38 * 0.5, 1e-9, "정차가 38집")


## v4 C1 ⑨: 기름값 절감 → 배송 1건 돈, 절감 합 상한 0.6
func test_setting_fuel_cut() -> void:
	var t := _game(0).truck(0)
	_put(t, "cargo_box", 0, ["fuel_cut"])                     # 순정 2%
	check_eq(Trip.parcel_pay(b, t), 2500 - 245 - 125, "기름값 2% 절감: 250 → 245")
	_put(t, "cargo_box", 1, ["fuel_cut", "fuel_cut"])         # 스트리트 4% × 2 = 8%
	check_eq(Trip.parcel_pay(b, t), 2500 - 230 - 125, "기름값 8% 절감: 250 → 230")
	_put(t, "cargo_box", 3, ["fuel_cut"])                     # 레이싱 9%
	check_eq(Trip.parcel_pay(b, t), 2500 - 228 - 125, "9%: 250 × 0.91 = 227.5 → 228 (0.5는 위로)")
	_put(t, "cargo_box", 4, ["fuel_cut", "fuel_cut", "fuel_cut"])   # 프로토타입 12% × 3 = 36%
	_put(t, "ecu", 3, ["fuel_cut", "fuel_cut"])                     # + 레이싱 9% × 2 = 54%
	check_eq(Trip.parcel_pay(b, t), 2500 - 115 - 125, "54% (상한 안쪽): 250 × 0.46 = 115")
	_put(t, "ecu", 4, ["fuel_cut", "fuel_cut", "fuel_cut"])         # 36% + 36% = 72% → 상한 60%
	check_near(Setting.total(b, t, "fuel_cut"), 0.72, 1e-9, "절감 합 (상한 전)")
	check_eq(Trip.parcel_pay(b, t), 2500 - 100 - 125, "72% → 상한 60%: 250 × 0.4 = 100")


## v4 C1 ⑨: 엔진 보호 3줄(프로토타입 10% × 3 = 30%) → 퍼짐 × 0.7, 줄어든 만큼 실패
func test_setting_engine_guard() -> void:
	var t := _game(20).truck(0)
	check_eq(Enhance.chances_for(b, t), Enhance.chances(b, 20), "세팅 없으면 chances와 같음")
	_put(t, "ecu", 4, ["engine_guard", "engine_guard", "engine_guard"])
	var c := Enhance.chances_for(b, t)
	check_near(c["destroy"], 0.07 * 0.7, 1e-12, "+20 퍼짐 7% × 0.7")
	check_near(c["success"], 0.3, 1e-12, "성공은 그대로")
	check_near(c["fail"], 1.0 - 0.3 - 0.07 * 0.7, 1e-12, "줄어든 만큼 실패")
	note("+20 엔진 보호 30%%: 성공 %.4f / 실패 %.4f / 퍼짐 %.4f" % [c["success"], c["fail"], c["destroy"]])
	# 상한 0.3: 수치를 키운 balance에서 합이 0.6이어도 × 0.7
	var d := real_balance_dict()
	d["setting"]["options"]["engine_guard"]["values"] = [0, 0, 0.04, 0.06, 0.2]
	var b2: Balance = Balance.from_dict(d)
	check(b2.is_ok(), "엔진 보호 0.2 balance가 막힘: %s" % ", ".join(b2.errors))
	check_near(Enhance.chances_for(b2, t)["destroy"], 0.07 * 0.7, 1e-12, "합 60%여도 상한 30%")
	# try_enhance도 이 확률로 굴림: 보호 100%면 1000번 눌러도 안 퍼짐
	var d3 := real_balance_dict()
	d3["setting"]["engine_guard_cap"] = 1.0
	d3["setting"]["options"]["engine_guard"]["values"] = [0, 0, 0.04, 0.06, 0.34]
	var b3: Balance = Balance.from_dict(d3)
	var s := _game(20)
	_put(s.truck(0), "ecu", 4, ["engine_guard", "engine_guard", "engine_guard"])
	s.money = 10 ** 15
	s.spares = 1
	var rng := _rng(5)
	for k in 1000:
		s.truck(0).star = 20
		Enhance.try_enhance(s, b3, 0, rng)
	check_eq(s.truck(0).destroy_count, 0, "보호 100%인데 퍼짐")
	check(s.truck(0).success_count > 0, "1000번에 성공이 없음")


## v4 C1 ⑨: 오버부스트 걸린 바퀴 초와 평균 한 바퀴 초가 식과 같음
func test_setting_overboost_lap() -> void:
	for star in [0, 30]:
		var t := _game(star).truck(0)
		_put(t, "ecu", 4, ["overboost", "overboost", "overboost"])   # 8% × 3 = 24%
		var drive := 12000.0 / Trip.power(b, star)
		var boosted := drive - minf(10.0, drive / 2.0)
		var plain_lap := 10.0 + drive + 20 * 0.5
		var boost_lap := 10.0 + boosted + 20 * 0.5
		check_near(Trip.lap_seconds(b, t), plain_lap, 1e-9, "+%d 안 걸린 바퀴" % star)
		t.boost_lap = true
		check_near(Trip.lap_seconds(b, t), boost_lap, 1e-9, "+%d 걸린 바퀴" % star)
		var avg := plain_lap * 0.76 + boost_lap * 0.24
		check_near(Trip.avg_lap_seconds(b, t), avg, 1e-9, "+%d 평균 한 바퀴 (걸린 바퀴인지와 상관없음)" % star)
		check_near(Trip.hourly_income(b, t), 20 * 2125 * 3600.0 / avg, 1e-6, "+%d 시간당 = 평균 한 바퀴로" % star)
		note("+%d 오버부스트 24%%: 안 걸린 바퀴 %.4f초, 걸린 바퀴 %.4f초, 평균 %.4f초" % [star, plain_lap, boost_lap, avg])
	# 꺼둔 동안도 평균
	var s := _game(0)
	_put(s.truck(0), "ecu", 4, ["overboost", "overboost", "overboost"])
	var r := Trip.apply_offline(s, b, 3 * 3600.0)
	check_eq(r["money"], floori(Trip.hourly_income(b, s.truck(0)) * 3.0 * 0.5), "꺼둔 동안 돈 = 평균 시간당")
	check_eq(r["parcels"], floori(20 * 3600.0 / Trip.avg_lap_seconds(b, s.truck(0)) * 3.0 * 0.5), "꺼둔 동안 배송 = 평균 한 바퀴")


## v4 C1 ⑩: 오버부스트 24%로 advance 1시간 돈이 hourly_income(평균)과 2% 안쪽, 걸린 바퀴 비율 ≈ 24%
func test_overboost_advance_hour() -> void:
	for star in STARS:
		var s := _game(star)
		var t := s.truck(0)
		_put(t, "ecu", 4, ["overboost", "overboost", "overboost"])
		var events := Trip.advance(s, b, 0, 3600.0, _rng(11))
		var hourly := Trip.hourly_income(b, t)
		var gap := absf(s.money - hourly) / hourly
		check(gap <= 0.02, "+%d: 1시간 돈 %d, 평균 시간당 %.1f, 차이 %.2f%%" % [star, s.money, hourly, gap * 100.0])
		note("+%d 오버부스트 24%%: advance 1시간 %d원 / 평균 시간당 %.1f원 (차이 %.2f%%, 걸린 바퀴 %d번)"
				% [star, s.money, hourly, gap * 100.0, _count(events, "boost")])
	# 길게 돌려 걸린 바퀴 비율
	var s2 := _game(30)
	_put(s2.truck(0), "ecu", 4, ["overboost", "overboost", "overboost"])
	var rng := _rng(12)
	var boosts := 0
	for k in 20000:
		boosts += _count(Trip.advance(s2, b, 0, Trip.lap_seconds(b, s2.truck(0)), rng), "boost")
	check_near(boosts / 20000.0, 0.24, 0.01, "걸린 바퀴 비율 (20000바퀴 중 %d)" % boosts)
	# 걸린 바퀴는 boost_lap이 켜지고, 이벤트는 새 바퀴 출발 때(그 진행의 마지막)
	var s3 := _game(0)
	_put(s3.truck(0), "ecu", 4, ["overboost", "overboost", "overboost"])
	var rng3 := _rng(13)
	var found := false
	for k in 200:
		var ev := Trip.advance(s3, b, 0, Trip.lap_seconds(b, s3.truck(0)), rng3)
		if _count(ev, "boost") > 0:
			found = true
			check(s3.truck(0).boost_lap, "boost 이벤트인데 boost_lap이 꺼짐")
			check_eq(ev.back()["type"], "boost", "boost 이벤트가 새 바퀴 출발(마지막)이 아님")
			break
	check(found, "200바퀴 동안 오버부스트가 한 번도 안 걸림")
	# 오버부스트가 없으면 걸리지 않음
	check_eq(_count(Trip.advance(_game(0), b, 0, 3600.0, _rng(1)), "boost"), 0, "오버부스트 없는데 걸림")


func _count(events: Array, type: String) -> int:
	var n := 0
	for ev in events:
		if ev["type"] == type:
			n += 1
	return n
