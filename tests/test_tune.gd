## tune.gd + game_state.gd 튜닝 부분: 등급업 굴리기, 대박 배송, 부위 효과가 수익·비용·퍼짐·꺼둔 동안에 반영
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Tune = preload("res://scripts/core/tune.gd")

const ROLLS := 100000
const RATE_TOLERANCE := 0.01   # 1%p
const HOUR := 3600.0

var b: Balance = Balance.load_file()


## 7부위가 다 같은 등급인 상태
func _state_all(g: int) -> GameState:
	var s := GameState.new()
	for part in Tune.PARTS:
		s.set_grade(b, part, g)
	return s


## 화면 순서(Tune.PARTS)와 balance.json 효과 목록 부위가 같음
func test_parts_match_balance() -> void:
	check_eq(Tune.PARTS, Balance.TUNE_EFFECT_KEYS.keys(), "Tune.PARTS와 Balance.TUNE_EFFECT_KEYS 부위·순서")
	check_eq(Tune.PARTS.size(), 7, "튜닝 부위 수")


## 지시서 숫자: 비용 100 / 1,500 / 20,000원, 확률 15% / 5% / 1.5%, 등급 이름, 효과 숫자
func test_answer_values() -> void:
	check_eq(Tune.max_grade(b), 3, "최고 등급")
	check_eq([Tune.grade_name(b, 0), Tune.grade_name(b, 1), Tune.grade_name(b, 2), Tune.grade_name(b, 3)],
			["일반", "레어", "에픽", "전설"], "등급 이름")
	check_eq(Tune.grade_name(b, 9), "전설", "범위 밖 등급 이름 → 끝 등급")
	check_eq(Tune.cost(b, 0), 100.0, "일반→레어 비용")
	check_eq(Tune.cost(b, 1), 1500.0, "레어→에픽 비용")
	check_eq(Tune.cost(b, 2), 20000.0, "에픽→전설 비용")
	check_eq(Tune.cost(b, 3), 0.0, "전설은 더 못 굴림 → 비용 0")
	check_near(Tune.up_chance(b, 0), 0.15, 1e-12, "일반→레어 확률")
	check_near(Tune.up_chance(b, 1), 0.05, 1e-12, "레어→에픽 확률")
	check_near(Tune.up_chance(b, 2), 0.015, 1e-12, "에픽→전설 확률")
	check_eq(Tune.up_chance(b, 3), 0.0, "전설 → 등급업 확률 0")
	# 비용은 강수와 상관없음 (0강 시간당 수익 기준 고정 금액)
	var s := GameState.new()
	s.star = 25
	check_eq(Tune.cost(b, s.grade("turbo")), 100.0, "25강이어도 일반→레어 100원")
	# 효과 숫자 = json 그대로
	var expected := {
		"turbo": [0.0, 0.1, 0.25, 0.5], "tire": [0.0, 0.05, 0.1, 0.15], "cargo": [2.0, 3.0, 4.0, 5.0],
		"suspension": [0.0, 0.1, 0.2, 0.3], "fuel_tank": [0.0, 2.0, 4.0, 8.0],
		"navigation": [0.0, 0.1, 0.2, 0.3], "engine_oil": [0.0, 0.05, 0.1, 0.2],
	}
	for part in expected:
		for g in 4:
			check_near(Tune.effect(b, part, g), expected[part][g], 1e-12, "%s %s 효과" % [part, Tune.grade_name(b, g)])


## 경계값: 일반 (등급업 0.15)
func test_decide_boundaries() -> void:
	check_eq(Tune.decide(b, 0, 0.0), Tune.Result.UP, "r=0")
	check_eq(Tune.decide(b, 0, 0.1499), Tune.Result.UP, "r=0.1499")
	check_eq(Tune.decide(b, 0, 0.15), Tune.Result.SAME, "r=0.15 (확률과 같음 → 그대로)")
	check_eq(Tune.decide(b, 2, 0.0149), Tune.Result.UP, "에픽 r=0.0149")
	check_eq(Tune.decide(b, 2, 0.015), Tune.Result.SAME, "에픽 r=0.015")
	check_eq(Tune.decide(b, 3, 0.0), Tune.Result.SAME, "전설은 r=0이어도 그대로")


## 등급마다 10만 번 굴려서 등급업 확률이 표와 1%p 안쪽
func test_up_rates_match_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for g in Tune.max_grade(b):
		var s := GameState.new()
		var ups := 0
		for i in ROLLS:
			s.set_grade(b, "turbo", g)
			s.money = 1e9
			if Tune.try_tune(s, b, "turbo", rng) == Tune.Result.UP:
				ups += 1
		var rate := ups / float(ROLLS)
		check_near(rate, Tune.up_chance(b, g), RATE_TOLERANCE, "%s 등급업 확률" % Tune.grade_name(b, g))
		check_eq(s.tune_press_count, ROLLS, "%s: 누른 횟수" % Tune.grade_name(b, g))
		check_eq(s.tune_up_count, ups, "%s: 등급업 횟수" % Tune.grade_name(b, g))
		note("%s→%s: 10만 번 중 %d번 (%.3f%%, 표 %.1f%%)" % [Tune.grade_name(b, g), Tune.grade_name(b, g + 1),
				ups, rate * 100.0, Tune.up_chance(b, g) * 100.0])


## 튜닝 1번마다: 그 등급 비용이 빠지고, 오르면 딱 한 등급, 실패면 그대로 (안 내려감), 통계가 맞게 쌓임
func test_each_press_updates_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var s := GameState.new()
	s.money = 1e12
	var presses := 0
	var ups := 0
	for part in Tune.PARTS:
		var tries := 0
		while s.grade(part) < Tune.max_grade(b) and tries < 5000:
			tries += 1
			var g0 := s.grade(part)
			var money0 := s.money
			var result := Tune.try_tune(s, b, part, rng)
			presses += 1
			check_near(s.money, money0 - Tune.cost(b, g0), 1e-6, "%s %d번째: 비용이 정확히 안 빠짐" % [part, tries])
			match result:
				Tune.Result.UP:
					ups += 1
					check_eq(s.grade(part), g0 + 1, "%s %d번째 등급업인데 등급" % [part, tries])
				Tune.Result.SAME:
					check_eq(s.grade(part), g0, "%s %d번째 실패인데 등급이 바뀜" % [part, tries])
				_:
					check(false, "%s %d번째: 튜닝이 막힘" % [part, tries])
		check_eq(s.grade(part), 3, "%s: 5000번 안에 전설이 안 됨" % part)
	check_eq(s.tune_press_count, presses, "누른 횟수")
	check_eq(s.tune_up_count, ups, "등급업 횟수")
	check_eq(ups, 7 * 3, "7부위 × 3등급 = 등급업 21번")
	check_eq(s.best_grade(), 3, "가장 높은 등급")
	note("7부위 전부 전설까지 %d번 누름" % presses)


func test_blocked_when_no_money_or_max() -> void:
	var rng := RandomNumberGenerator.new()
	var s := GameState.new()
	s.money = 99.0
	check_eq(Tune.block_reason(s, b, "tire"), Tune.Block.NO_MONEY, "99원으로 튜닝 가능으로 나옴")
	check_eq(Tune.try_tune(s, b, "tire", rng), Tune.Result.BLOCKED, "돈이 모자란데 튜닝이 됨")
	check_eq(s.money, 99.0, "막혔는데 돈이 빠짐")
	check_eq(s.tune_press_count, 0, "막혔는데 횟수가 셈")
	s.money = 100.0
	check_eq(Tune.block_reason(s, b, "tire"), Tune.Block.NONE, "100원 딱 맞는데 막힘")

	s.set_grade(b, "tire", 3)
	s.money = 1e12
	check_eq(Tune.block_reason(s, b, "tire"), Tune.Block.MAX_GRADE, "전설인데 튜닝 가능으로 나옴")
	check_eq(Tune.try_tune(s, b, "tire", rng), Tune.Result.BLOCKED, "전설인데 튜닝이 됨")
	check_eq(s.money, 1e12, "전설에서 돈이 빠짐")
	check_eq(s.grade("tire"), 3, "전설 등급이 바뀜")

	# 에픽: 20,000원
	s.set_grade(b, "cargo", 2)
	s.money = 19999.0
	check_eq(Tune.block_reason(s, b, "cargo"), Tune.Block.NO_MONEY, "에픽 19,999원으로 가능으로 나옴")
	s.money = 20000.0
	check_eq(Tune.block_reason(s, b, "cargo"), Tune.Block.NONE, "에픽 20,000원 딱 맞는데 막힘")


## 고장 중: 튜닝은 됨 (있는 돈으로), 수익은 0, 대박도 없음
func test_tune_while_broken() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var s := _state_all(3)
	s.set_grade(b, "turbo", 0)
	s.star = 15
	s.broken = true
	s.money = 1000.0
	check_eq(Tune.block_reason(s, b, "turbo"), Tune.Block.NONE, "고장인데 튜닝이 막힘")
	var r := Tune.try_tune(s, b, "turbo", rng)
	check(r != Tune.Result.BLOCKED, "고장인데 튜닝이 안 됨")
	check_eq(s.money, 900.0, "고장 중 튜닝 비용")
	check_eq(s.steady_hourly(b), 0.0, "고장인데 보통 수익이 있음")
	check_eq(s.current_hourly(b), 0.0, "고장인데 평균 수익이 있음")
	check_eq(s.delivery_pay(b, 10.0, false), 0.0, "고장인데 배송 돈")
	check_eq(s.delivery_pay(b, 10.0, true), 0.0, "고장인데 대박 배송 돈")
	check_eq(s.offline_earnings(b, 3 * HOUR), 0.0, "고장인데 꺼둔 동안 수익")
	var state0 := rng.state
	check(not Tune.roll_jackpot(s, b, rng), "고장인데 대박이 남")
	check_eq(rng.state, state0, "고장일 때 대박 굴리기가 난수를 씀")
	check_eq(s.jackpot_count, 0, "고장인데 대박 횟수가 셈")


## 엔진이 퍼져도 튜닝 등급은 그대로 (스페어 사도 그대로)
func test_grades_survive_destroy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := GameState.new()
	var grades := { "turbo": 3, "tire": 2, "cargo": 1, "suspension": 2, "fuel_tank": 3, "navigation": 1, "engine_oil": 2 }
	for part in grades:
		s.set_grade(b, part, grades[part])
	var result := Enhance.Result.FAIL
	var tries := 0
	while result != Enhance.Result.DESTROY and tries < 2000:
		tries += 1
		s.star = 22
		s.money = 1e12
		result = Enhance.try_enhance(s, b, rng)
	check_eq(result, Enhance.Result.DESTROY, "2000번 안에 안 퍼짐")
	check(s.broken and s.star == 15, "퍼졌는데 15강 고장이 아님")
	for part in grades:
		check_eq(s.grade(part), grades[part], "퍼진 뒤 %s 등급" % part)
	check(s.buy_spare(b), "스페어를 못 삼")
	for part in grades:
		check_eq(s.grade(part), grades[part], "스페어 산 뒤 %s 등급" % part)
	Enhance.break_engine(s, b)   # F5도 마찬가지
	for part in grades:
		check_eq(s.grade(part), grades[part], "F5 퍼짐 뒤 %s 등급" % part)


## 대박 배송: 타이어 등급마다 10만 번 → 확률 1%p 안쪽. 맞으면 jackpot_count += 1. 타이어 일반이면 절대 없음
func test_jackpot_rate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	for g in 4:
		var s := GameState.new()
		s.set_grade(b, "tire", g)
		var hits := 0
		for i in ROLLS:
			if Tune.roll_jackpot(s, b, rng):
				hits += 1
		var expected := Tune.effect(b, "tire", g)
		check_near(hits / float(ROLLS), expected, RATE_TOLERANCE, "타이어 %s 대박 확률" % Tune.grade_name(b, g))
		check_eq(s.jackpot_count, hits, "타이어 %s 대박 횟수" % Tune.grade_name(b, g))
		if g == 0:
			check_eq(hits, 0, "타이어 일반인데 대박이 남")
		note("타이어 %s: 10만 번 중 대박 %d번 (%.3f%%, 표 %.0f%%)" % [Tune.grade_name(b, g), hits, hits / float(ROLLS) * 100.0, expected * 100.0])
	# 타이어 일반이면 난수를 안 씀 (예전과 같은 난수 순서)
	var s0 := GameState.new()
	var state0 := rng.state
	Tune.roll_jackpot(s0, b, rng)
	check_eq(rng.state, state0, "타이어 일반인데 대박 굴리기가 난수를 씀")


## 수익: 보통 = 엔진 × (1 + 터보), 평균 = 보통 × (1 + 타이어 × (짐칸 − 1)), 배송 1번 돈
func test_income_effects() -> void:
	for star in [0, 10, 19, 25]:
		var engine := Economy.hourly_income(b, star)
		for turbo in 4:
			for tire in 4:
				for cargo in 4:
					var s := GameState.new()
					s.star = star
					s.set_grade(b, "turbo", turbo)
					s.set_grade(b, "tire", tire)
					s.set_grade(b, "cargo", cargo)
					var steady := engine * (1.0 + Tune.effect(b, "turbo", turbo))
					var chance := Tune.effect(b, "tire", tire)
					var mult := Tune.effect(b, "cargo", cargo)
					var where := "%d강 터보%d 타이어%d 짐칸%d" % [star, turbo, tire, cargo]
					check_near(s.steady_hourly(b), steady, steady * 1e-12, where + " 보통 수익")
					check_near(s.current_hourly(b), steady * (1.0 + chance * (mult - 1.0)), steady * 1e-12, where + " 평균 수익")
					check_eq(s.jackpot_chance(b), chance, where + " 대박 확률")
					check_eq(s.jackpot_mult(b), mult, where + " 대박 배수")
					check_near(s.delivery_pay(b, 7.5, false), steady / HOUR * 7.5, steady * 1e-12, where + " 배송 1번")
					check_near(s.delivery_pay(b, 7.5, true), steady / HOUR * 7.5 * mult, steady * 1e-12, where + " 대박 배송 1번")
	# 지시서: 전설 타이어 + 전설 짐칸 = +60%, 전설 터보 = +50%, 셋 다 = ×2.4
	var s := GameState.new()
	s.star = 10
	var h := Economy.hourly_income(b, 10)
	s.set_grade(b, "tire", 3)
	s.set_grade(b, "cargo", 3)
	check_near(s.current_hourly(b), h * 1.6, 1e-9, "전설 타이어 + 전설 짐칸 = +60%")
	check_near(s.steady_hourly(b), h, 1e-9, "타이어·짐칸은 보통 수익을 안 바꿈")
	s.set_grade(b, "turbo", 3)
	check_near(s.current_hourly(b), h * 1.5 * 1.6, 1e-9, "전설 터보·타이어·짐칸 = ×2.4")
	# 짐칸은 타이어가 일반(대박 0%)이면 효과 없음
	var c := GameState.new()
	c.set_grade(b, "cargo", 3)
	check_eq(c.current_hourly(b), Economy.hourly_income(b, 0), "타이어 일반 + 짐칸 전설: 효과 없음")


## 대박을 굴려 가며 오래 배송하면 평균이 "평균 시간당 수익"과 맞음 (seed 고정, 100시간)
func test_jackpot_average_adds_up() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var s := GameState.new()
	s.star = 12
	s.set_grade(b, "turbo", 2)
	s.set_grade(b, "tire", 3)
	s.set_grade(b, "cargo", 3)
	var earned := 0.0
	var elapsed := 0.0
	var trips := 0
	while elapsed < 100 * HOUR:
		var trip := rng.randf_range(2.0, 15.0)
		earned += s.delivery_pay(b, trip, Tune.roll_jackpot(s, b, rng))
		elapsed += trip
		trips += 1
	var expected := s.current_hourly(b) * elapsed / HOUR
	check_near(earned / expected, 1.0, 0.02, "100시간 배송 합계 / 평균 시간당 수익")
	note("100시간: 배송 %d번, 대박 %d번, 번 돈 / 기대 = %.4f" % [trips, s.jackpot_count, earned / expected])


## 강화 비용: 엔진오일만큼 깎임 (터보·대박은 안 들어감). 스페어값은 그대로
func test_enhance_cost_effects() -> void:
	for star in [0, 10, 17, 18, 22, 29]:
		for oil in 4:
			var s := _state_all(3)   # 터보·타이어 등 다른 부위는 전설이어도 비용과 상관없음
			s.set_grade(b, "engine_oil", oil)
			s.star = star
			var cut := Tune.effect(b, "engine_oil", oil)
			var expected := roundf(b.cost_hours[star] * Economy.hourly_income(b, star) * (1.0 - cut))
			check_eq(s.enhance_cost(b), expected, "%d강 엔진오일 %s 비용" % [star, Tune.grade_name(b, oil)])
			check_eq(s.enhance_need(b), expected + Economy.spare_reserve(b, star), "%d강 엔진오일 %s 필요한 돈" % [star, Tune.grade_name(b, oil)])
	# 정답 값: 18강 비용 77,839 → 엔진오일 전설(−20%) 62,271, 필요한 돈 + 스페어 50,000
	var s := GameState.new()
	s.star = 18
	s.set_grade(b, "engine_oil", 3)
	check_eq(s.enhance_cost(b), 62271.0, "18강 엔진오일 전설 비용")
	check_eq(s.enhance_need(b), 62271.0 + 50000.0, "18강 엔진오일 전설 필요한 돈")
	# 강화 버튼: 깎인 비용만 빠지고, 깎인 "필요한 돈"이면 누를 수 있음
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	s.money = s.enhance_need(b)
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NONE, "엔진오일로 깎인 필요한 돈이 딱 있는데 막힘")
	var r := Enhance.try_enhance(s, b, rng)
	check(r != Enhance.Result.BLOCKED, "엔진오일 전설 18강 강화가 막힘")
	check_near(s.money, 50000.0, 1e-6, "엔진오일 전설: 강화 뒤 남은 돈 (스페어값만 남아야 함)")
	s.star = 18
	s.broken = false
	s.money = s.enhance_need(b) - 1.0
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NO_MONEY, "1원 모자란데 강화 가능으로 나옴")


## 퍼짐 확률: destroy × (1 − 서스펜션), 성공은 그대로, 줄어든 만큼 실패(유지)
func test_destroy_cut_effects() -> void:
	for star in b.max_star:
		for sus in 4:
			var s := GameState.new()
			s.star = star
			s.set_grade(b, "suspension", sus)
			var c := s.enhance_chances(b)
			var d := b.destroy[star] * (1.0 - Tune.effect(b, "suspension", sus))
			var where := "%d강 서스펜션 %s" % [star, Tune.grade_name(b, sus)]
			check_eq(c["success"], b.success[star], where + " 성공")
			check_near(c["destroy"], d, 1e-12, where + " 퍼짐")
			check_near(c["success"] + c["fail"] + c["destroy"], 1.0, 1e-9, where + " 확률 합")
	var s22 := GameState.new()
	s22.star = 22
	s22.set_grade(b, "suspension", 3)
	check_near(s22.enhance_chances(b)["destroy"], 0.07, 1e-12, "22강 퍼짐 10% → 서스펜션 전설 7%")
	check_near(s22.enhance_chances(b)["fail"], 0.78, 1e-12, "22강 실패 75% → 78%")

	# 진짜로 굴려서: 22강 서스펜션 전설 10만 번 → 성공 15%, 퍼짐 7%
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var counts := [0, 0, 0]
	var s := GameState.new()
	s.set_grade(b, "suspension", 3)
	for i in ROLLS:
		s.star = 22
		s.broken = false
		s.money = 1e12
		counts[Enhance.try_enhance(s, b, rng)] += 1
	var succ: float = counts[Enhance.Result.SUCCESS] / float(ROLLS)
	var dest: float = counts[Enhance.Result.DESTROY] / float(ROLLS)
	check_near(succ, 0.15, RATE_TOLERANCE, "22강 서스펜션 전설 성공률")
	check_near(dest, 0.07, RATE_TOLERANCE, "22강 서스펜션 전설 퍼짐률")
	note("22강 서스펜션 전설 10만 번: 성공 %.2f%% / 퍼짐 %.2f%% (표 15%% / 7%%)" % [succ * 100.0, dest * 100.0])
	# 17강 이하는 서스펜션과 상관없이 절대 안 퍼짐
	for star in range(0, 18):
		var t := GameState.new()
		t.star = star
		t.set_grade(b, "suspension", 3)
		check_eq(t.enhance_chances(b)["destroy"], 0.0, "%d강에서 퍼짐 확률이 생김" % star)


## 꺼둔 동안: 평균 시간당 수익 × min(꺼둔 시간, 8 + 연료 탱크) × (0.5 + 내비)
func test_offline_effects() -> void:
	for fuel in 4:
		for navi in 4:
			var s := GameState.new()
			s.star = 10
			s.set_grade(b, "fuel_tank", fuel)
			s.set_grade(b, "navigation", navi)
			var cap := 8.0 + Tune.effect(b, "fuel_tank", fuel)
			var rate := 0.5 + Tune.effect(b, "navigation", navi)
			var h := s.current_hourly(b)
			var where := "연료%d 내비%d" % [fuel, navi]
			check_near(s.offline_cap_hours(b), cap, 1e-12, where + " 최대 시간")
			check_near(s.offline_rate(b), rate, 1e-12, where + " 비율")
			check_near(s.offline_earnings(b, 3 * HOUR), h * 3.0 * rate, 1e-6, where + " 3시간")
			check_near(s.offline_earnings(b, 30 * HOUR), h * cap * rate, 1e-6, where + " 30시간 (최대)")
			check_eq(s.offline_earnings(b, -3 * HOUR), 0.0, where + " 시계 거꾸로")
			check_eq(s.offline_earnings(b, 0.0), 0.0, where + " 0초")
	# 지시서: 연료 전설 16시간, 내비 전설 80%
	var top := _state_all(0)
	top.star = 10
	top.set_grade(b, "fuel_tank", 3)
	top.set_grade(b, "navigation", 3)
	var h10 := Economy.hourly_income(b, 10)
	check_near(top.offline_earnings(b, 20 * HOUR), h10 * 16.0 * 0.8, 1e-6, "연료·내비 전설: 20시간 → 16시간치의 80%")
	check_near(top.offline_earnings(b, 12 * HOUR), h10 * 12.0 * 0.8, 1e-6, "연료·내비 전설: 12시간 → 12시간치의 80%")
	# 터보·대박도 꺼둔 동안에 들어감 (평균 시간당 수익)
	top.set_grade(b, "turbo", 3)
	top.set_grade(b, "tire", 3)
	top.set_grade(b, "cargo", 3)
	check_near(top.offline_earnings(b, 20 * HOUR), h10 * 2.4 * 16.0 * 0.8, 1e-6, "전부 전설: 20시간")


## 튜닝을 올려도 "엔진만" 값(Economy, Enhance.chances)은 그대로. 튜닝이 전부 일반이면 GameState 값 = 엔진만 값
func test_engine_only_values_unchanged() -> void:
	var top := _state_all(3)
	var zero := GameState.new()
	for star in b.max_star + 1:
		top.star = star
		zero.star = star
		var h := b.base_hourly * pow(b.star_mult, mini(star, b.high_from_star - 1)) \
				* pow(b.star_mult_high, maxi(0, star - (b.high_from_star - 1)))
		check_near(Economy.hourly_income(b, star), h, h * 1e-12, "%d강 엔진만 수익" % star)
		check_eq(zero.current_hourly(b), Economy.hourly_income(b, star), "%d강 튜닝 없음: 평균 수익 = 엔진만" % star)
		check_eq(zero.steady_hourly(b), Economy.hourly_income(b, star), "%d강 튜닝 없음: 보통 수익 = 엔진만" % star)
		check_eq(zero.delivery_pay(b, 9.25, false), Economy.delivery_pay(b, star, 9.25), "%d강 튜닝 없음: 배송 1번" % star)
		for secs in [-HOUR, 0.0, 3 * HOUR, 20 * HOUR]:
			check_eq(zero.offline_earnings(b, secs), Economy.offline_earnings(b, star, false, secs),
					"%d강 튜닝 없음: 꺼둔 %s초" % [star, secs])
			check_near(Economy.offline_earnings(b, star, false, secs), h * clampf(secs / HOUR, 0.0, 8.0) * 0.5,
					h * 1e-9, "%d강 엔진만 꺼둔 %s초" % [star, secs])
		if star >= b.max_star:
			continue
		check_eq(Economy.enhance_cost(b, star), roundf(b.cost_hours[star] * h), "%d강 엔진만 비용" % star)
		check_eq(zero.enhance_cost(b), Economy.enhance_cost(b, star), "%d강 튜닝 없음: 비용 = 엔진만" % star)
		check_eq(zero.enhance_need(b), Economy.enhance_need(b, star), "%d강 튜닝 없음: 필요한 돈 = 엔진만" % star)
		check_eq(zero.enhance_chances(b), Enhance.chances(b, star), "%d강 튜닝 없음: 확률 = 엔진만" % star)
		var c := Enhance.chances(b, star)
		check_eq([c["success"], c["destroy"]], [b.success[star], b.destroy[star]], "%d강 엔진만 확률 (전설 튜닝 있어도)" % star)
		check(top.enhance_cost(b) <= Economy.enhance_cost(b, star), "%d강 엔진오일 전설인데 비용이 더 큼" % star)


## set_grade: 0~최고로 자름, best_grade
func test_set_grade_and_best_grade() -> void:
	var s := GameState.new()
	check_eq(s.best_grade(), 0, "새 게임: 가장 높은 등급 0")
	for part in Tune.PARTS:
		check_eq(s.grade(part), 0, "새 게임 %s 등급" % part)
	s.set_grade(b, "navigation", 9)
	check_eq(s.grade("navigation"), 3, "등급 9 → 3으로 자름")
	s.set_grade(b, "turbo", -2)
	check_eq(s.grade("turbo"), 0, "등급 -2 → 0으로 자름")
	check_eq(s.best_grade(), 3, "가장 높은 등급")
	s.set_grade(b, "navigation", 1)
	s.set_grade(b, "tire", 2)
	check_eq(s.best_grade(), 2, "가장 높은 등급 (내비 레어, 타이어 에픽)")
