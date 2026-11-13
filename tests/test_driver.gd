## driver.gd: 다음 레벨 경험치, 레벨업·포인트, 만렙 뒤 평판, 강화 첫 달성 보너스, 배송 경험치, 알림 (v5)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

var b: Balance = Balance.load_file()


## 레벨 1에서 to 레벨까지 필요한 경험치 합
func _xp_to(level: int) -> int:
	var sum := 0
	for lv in range(1, level):
		sum += Driver.xp_need(b, lv)
	return sum


## 지금까지 받은 경험치 합 (레벨에 쓴 것 + 지금 레벨에서 쌓인 것 + 평판)
func _xp_total(s: GameState) -> int:
	return _xp_to(s.driver_level) + s.driver_xp + s.reputation


func _of_type(events: Array, type: String) -> Array:
	return events.filter(func(ev): return ev["type"] == type)


## v5 C1 ②: 레벨 1~6 필요량이 시트 값, 만렙 0
func test_xp_need() -> void:
	var want := [100, 230, 374, 528, 690, 859]
	var got := []
	for lv in range(1, 7):
		got.append(Driver.xp_need(b, lv))
	check_eq(got, want, "레벨 1~6 다음 레벨까지")
	check_eq(Driver.max_level(b), 50, "만렙")
	check_eq(Driver.xp_need(b, 50), 0, "만렙 필요량")
	check_eq(Driver.xp_need(b, 49), roundi(100.0 * pow(49.0, 1.2)), "레벨 49 필요량 = round(100 × 49^1.2)")
	note("다음 레벨까지 (레벨 1~6): %s, 레벨 49: %d, 레벨 1→50 합 %d" % [got, Driver.xp_need(b, 49), _xp_to(50)])


## v5 C1 ③: 한 번에 많이 줘도 여러 레벨이 오르고 남는 경험치가 이어짐. 포인트 레벨 10까지 11, 50까지 59
func test_many_levels_at_once() -> void:
	var s := GameState.new_game()
	Driver.add_xp(s, b, _xp_to(10) + 37)
	check_eq([s.driver_level, s.driver_xp], [10, 37], "레벨 10 + 남은 37")
	check_eq(s.ability_points, 11, "레벨 10까지 포인트 9 + 2")
	var ups := _of_type(s.take_events(), "level_up")
	check_eq(ups.size(), 9, "레벨업 알림 수")
	if ups.size() == 9:
		check_eq([ups[0]["level"], ups[0]["points"]], [2, 1], "첫 레벨업 알림")
		check_eq([ups[8]["level"], ups[8]["points"]], [10, 3], "레벨 10 알림 (포인트 1 + 2)")

	# 조금씩 줘도 같은 곳에 도착
	var s2 := GameState.new_game()
	for k in (_xp_to(10) + 37) / 7:
		Driver.add_xp(s2, b, 7)
	Driver.add_xp(s2, b, (_xp_to(10) + 37) % 7)
	check_eq([s2.driver_level, s2.driver_xp, s2.ability_points], [10, 37, 11], "7씩 나눠 줘도 같음")

	var s3 := GameState.new_game()
	Driver.add_xp(s3, b, _xp_to(50))
	check_eq([s3.driver_level, s3.driver_xp, s3.reputation], [50, 0, 0], "딱 만렙")
	check_eq(s3.ability_points, 59, "레벨 50까지 포인트 49 + 2 × 5")
	note("포인트: 레벨 10까지 %d, 레벨 50까지 %d" % [s.ability_points, s3.ability_points])


## v5 C1 ④: 만렙 뒤 경험치는 평판으로, 만렙 알림은 한 번
func test_max_level_goes_to_reputation() -> void:
	var s := GameState.new_game()
	Driver.add_xp(s, b, _xp_to(50) + 123)
	check_eq([s.driver_level, s.driver_xp, s.reputation], [50, 0, 123], "만렙이 되는 순간 남은 경험치 → 평판")
	Driver.add_xp(s, b, 1000)
	Driver.add_xp(s, b, 0)
	Driver.add_xp(s, b, -5)
	check_eq([s.driver_level, s.driver_xp, s.reputation], [50, 0, 1123], "만렙 뒤 경험치 → 평판 (0·음수는 무시)")
	var events := s.take_events()
	check_eq(_of_type(events, "max_level").size(), 1, "만렙 알림 수")
	check_eq(events.back(), { "type": "max_level" }, "만렙 알림이 마지막 레벨업 뒤")
	check_eq(_of_type(events, "level_up").size(), 49, "레벨업 알림 수 (2~50)")


## v5 C1 ⑤: advance 배송 n건 → 경험치 10n, parcels_total n (퀘스트는 다 끝낸 상태로 보상 경험치를 뺌)
func test_advance_gives_parcel_xp() -> void:
	for star in [0, 30]:
		var s := GameState.new_game()
		s.truck(0).star = star
		s.quest_index = Quest.count(b)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var n := 0
		for k in 600:   # 1초씩 10분
			for ev in Trip.advance(s, b, 0, 1.0, rng):
				if ev["type"] == "parcel":
					n += 1
		check(n > 0, "+%d: 10분 동안 배송이 없음" % star)
		check_eq(s.parcels_total, n, "+%d: parcels_total = 배송 수" % star)
		check_eq(_xp_total(s), 10 * n, "+%d: 경험치 = 10 × 배송 %d건" % [star, n])
		note("+%d 10분: 배송 %d건 → 경험치 %d, 레벨 %d" % [star, n, _xp_total(s), s.driver_level])


## v5 C1 ⑥: 강화 첫 달성 보너스는 단계마다 한 번 (퍼져서 다시 올라가도, 다른 트럭이 올라가도 안 줌)
func test_star_milestones_once() -> void:
	var s := GameState.new_game()
	for star in range(1, 21):
		Driver.on_star_reached(s, b, star)
	check_eq(s.milestones_done, [10, 15, 18, 20], "+20까지 받은 보너스 단계")
	check_eq(_xp_total(s), 4 * 500, "보너스 경험치 4 × 500")
	var ms := _of_type(s.take_events(), "milestone")
	check_eq(ms.map(func(ev): return [ev["star"], ev["xp"]]), [[10, 500], [15, 500], [18, 500], [20, 500]], "보너스 알림")
	# 퍼져서 +15 → 다시 +20
	for star in range(16, 21):
		Driver.on_star_reached(s, b, star)
	s.trucks.append(TruckState.new())
	Driver.on_star_reached(s, b, 18)   # 다른 트럭
	check_eq(_of_type(s.take_events(), "milestone").size(), 0, "다시 올라가도 보너스 없음")
	check_eq(_xp_total(s), 2000, "다시 올라간 뒤 경험치 그대로")
	# 보너스 단계를 건너뛴 상태(형식 4 저장의 +20)에서 성공하면 아래 단계도 한 번씩
	var s2 := GameState.new_game()
	Driver.on_star_reached(s2, b, 21)
	check_eq(s2.milestones_done, [10, 15, 18, 20], "+21 첫 성공에 건너뛴 보너스 단계")


## v5 C1 ⑥: 강화 성공이 보너스를 부름 (Enhance.try_enhance → Driver.on_star_reached). 실패·퍼짐은 안 부름
func test_enhance_success_calls_milestone() -> void:
	var d := real_balance_dict()
	for i in d["engine"]["success"].size():
		d["engine"]["success"][i] = 1.0
		d["engine"]["destroy"][i] = 0.0
	var b1: Balance = Balance.from_dict(d)
	var s := GameState.new_game()
	s.truck(0).star = 9
	s.money = 1_000_000_000
	var rng := RandomNumberGenerator.new()
	check_eq(Enhance.try_enhance(s, b1, 0, rng), Enhance.Result.SUCCESS, "+9 성공")
	check_eq(s.milestones_done, [10], "+10 성공 → 보너스")
	check_eq(_of_type(s.take_events(), "milestone").size(), 1, "보너스 알림 1번")
	check_eq(Enhance.try_enhance(s, b1, 0, rng), Enhance.Result.SUCCESS, "+10 성공")
	check_eq(s.milestones_done, [10], "+11은 보너스 단계 아님")
	# 늘 실패하는 balance: 보너스 없음
	for i in d["engine"]["success"].size():
		d["engine"]["success"][i] = 0.0
	var b0: Balance = Balance.from_dict(d)
	var s0 := GameState.new_game()
	s0.truck(0).star = 9
	s0.money = 1_000_000_000
	check_eq(Enhance.try_enhance(s0, b0, 0, rng), Enhance.Result.FAIL, "+9 실패")
	check_eq([s0.milestones_done, s0.take_events()], [[], []], "실패하면 보너스·알림 없음")


## v5 C1 ⑩: take_events는 쌓인 순서대로 주고 비운다
func test_take_events_in_order() -> void:
	var s := GameState.new_game()
	check_eq(s.take_events(), [], "처음엔 알림 없음")
	Driver.add_xp(s, b, 330)   # 100 + 230 → 레벨 3
	Driver.on_star_reached(s, b, 10)   # 보너스 500 → 374 넘김 → 레벨 4
	var events := s.take_events()
	check_eq(events, [
		{ "type": "level_up", "level": 2, "points": 1 },
		{ "type": "level_up", "level": 3, "points": 1 },
		{ "type": "milestone", "star": 10, "xp": 500 },
		{ "type": "level_up", "level": 4, "points": 1 },
	], "알림 순서")
	check_eq(s.take_events(), [], "꺼낸 뒤에는 비어 있음")
	check_eq([s.driver_level, s.driver_xp], [4, 126], "레벨 4 + 남은 126")
