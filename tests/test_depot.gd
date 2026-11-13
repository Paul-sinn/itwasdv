## depot.gd: 창고 확장·야간 배송팀 (레벨별 값, 가격, 사기), 꺼둔 동안 계산에 반영, 3분 미만 무시 (v5)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Depot = preload("res://scripts/core/depot.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

var b: Balance = Balance.load_file()


## v5 C1 ⑦: 레벨별 시간·비율, 살 수 있는 최고 레벨, 가격 (창고 Lv3에서 0, 야간팀 Lv4에서 0)
func test_levels_and_prices() -> void:
	check_eq([Depot.top_level(b, "warehouse"), Depot.top_level(b, "night")], [4, 4], "표의 마지막 레벨")
	var s := GameState.new_game()
	check_eq([Depot.level(s, "warehouse"), Depot.level(s, "night")], [1, 1], "처음 레벨")
	check_eq([Depot.buyable_level(b, s, "warehouse"), Depot.buyable_level(b, s, "night")], [3, 4], "살 수 있는 최고 레벨 (창고는 대리점 전 3)")
	var hours := []
	var rates := []
	for lv in range(1, 5):
		hours.append(Depot.value_at(b, "warehouse", lv))
		rates.append(Depot.value_at(b, "night", lv))
	check_eq(hours, [4.0, 6.0, 8.0, 12.0], "창고 레벨별 시간")
	check_eq(rates, [0.5, 0.6, 0.7, 0.8], "야간팀 레벨별 비율")
	var wp := []
	var np := []
	for lv in range(1, 5):
		s.warehouse_level = lv
		s.night_level = lv
		wp.append(Depot.price(b, s, "warehouse"))
		np.append(Depot.price(b, s, "night"))
		check_eq([Depot.cap_hours(b, s), Depot.rate(b, s)], [hours[lv - 1], rates[lv - 1]], "Lv%d 지금 시간·비율" % lv)
	check_eq(wp, [2000000, 3000000, 0, 0], "창고 다음 레벨 가격 (Lv3부터 대리점 전이라 0)")
	check_eq(np, [1500000, 2200000, 2500000, 0], "야간팀 다음 레벨 가격 (Lv4는 끝)")
	note("창고 시간 %s / 가격 %s, 야간팀 비율 %s / 가격 %s" % [hours, wp, rates, np])


## v5 C1 ⑦: 사면 돈이 가격만큼 줄고 레벨 +1, 돈이 모자라거나 더 못 사면 아무 일 없음
func test_upgrade() -> void:
	for kind in ["warehouse", "night"]:
		var s := GameState.new_game()
		var price := Depot.price(b, s, kind)
		s.money = price - 1
		check(not Depot.can_upgrade(b, s, kind), "%s: 1원 모자란데 살 수 있음" % kind)
		check(not Depot.upgrade(b, s, kind), "%s: 1원 모자란데 삼" % kind)
		check_eq([s.money, Depot.level(s, kind)], [price - 1, 1], "%s: 못 샀는데 상태가 바뀜" % kind)
		s.money = price
		check(Depot.upgrade(b, s, kind), "%s: 딱 맞는 돈으로 못 삼" % kind)
		check_eq([s.money, Depot.level(s, kind)], [0, 2], "%s: 산 뒤 돈·레벨" % kind)
	# 창고는 Lv3까지, 야간팀은 Lv4까지
	var rich := GameState.new_game()
	rich.money = 1_000_000_000
	var bought := { "warehouse": 0, "night": 0 }
	for kind in bought:
		while Depot.upgrade(b, rich, kind):
			bought[kind] += 1
	check_eq([rich.warehouse_level, rich.night_level], [3, 4], "끝까지 산 레벨")
	check_eq(bought, { "warehouse": 2, "night": 3 }, "산 횟수")
	check_eq(rich.money, 1_000_000_000 - 2000000 - 3000000 - 1500000 - 2200000 - 2500000, "쓴 돈")
	check(not Depot.can_upgrade(b, rich, "warehouse"), "창고 Lv3인데 살 수 있음")


## v5 C1 ⑦: 꺼둔 동안 계산에 창고 시간·야간팀 비율이 들어감
func test_offline_uses_depot() -> void:
	var hour := 3600.0
	var s := GameState.new_game()
	s.warehouse_level = 2   # 6시간
	s.night_level = 3       # 0.7
	var hourly := Trip.hourly_income(b, s.truck(0))
	var r := Trip.apply_offline(s, b, 20 * hour)
	check_eq(r["hours"], 6.0, "창고 Lv2: 20시간 → 6시간")
	check_eq(r["money"], floori(hourly * 6.0 * 0.7), "야간팀 Lv3: 6시간 × 0.7")
	check_eq(r["parcels"], floori(20 * 3600.0 / Trip.avg_lap_seconds(b, s.truck(0)) * 6.0 * 0.7), "배송 = 6시간 × 0.7")
	check(r["full"], "6시간 넘게 꺼 뒀는데 창고가 안 참")
	var s1 := GameState.new_game()
	var r1 := Trip.apply_offline(s1, b, 20 * hour)
	check_eq([r1["hours"], r1["money"]], [4.0, floori(hourly * 4.0 * 0.5)], "Lv1: 4시간 × 0.5")
	note("+0 20시간 꺼둠: Lv1 창고·야간팀 %d원 (4시간 × 50%%), 창고 Lv2·야간팀 Lv3 %d원 (6시간 × 70%%)" % [r1["money"], r["money"]])


## v5 C1 ⑧: 179초 → 무시(상태 그대로), 180초 → 계산, 상한에 닿으면 full
func test_ignore_under_3_minutes() -> void:
	var s := GameState.new_game()
	s.truck(0).star = 30
	s.spare_drop_carry = 0.5
	var r := Trip.apply_offline(s, b, 179.0)
	check(r["ignored"], "179초인데 무시 안 함")
	check_eq([r["money"], r["parcels"], r["spares"], r["hours"], r["full"]], [0, 0, 0, 0.0, false], "179초 결과")
	check_eq([s.money, s.spares, s.spare_drop_carry, s.parcels_total], [0, 0, 0.5, 0], "179초: 상태 그대로")
	var r2 := Trip.apply_offline(s, b, 180.0)
	check(not r2["ignored"], "180초인데 무시함")
	check_eq(r2["hours"], 0.05, "180초 = 0.05시간")
	check(r2["money"] > 0 and s.money == r2["money"], "180초: 돈이 들어옴 (%d)" % r2["money"])
	check(not r2["full"], "180초인데 창고가 참")
	# 상한 바로 앞 / 딱 / 넘음
	for c in [[4 * 3600.0 - 1.0, false], [4 * 3600.0, true], [4 * 3600.0 + 1.0, true]]:
		check_eq(Trip.apply_offline(GameState.new_game(), b, c[0])["full"], c[1], "%s초 꺼둠: 창고 꽉 참" % c[0])
	note("+30 180초 꺼둠: %d원, 배송 %d건" % [r2["money"], r2["parcels"]])
