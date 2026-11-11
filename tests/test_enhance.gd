## enhance.gd + game_state.gd: 강화 굴리기, 퍼짐, 스페어
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const ROLLS_PER_STAR := 100000
const RATE_TOLERANCE := 0.01   # 1%p

var b: Balance = Balance.load_file()


func test_random01_is_0_to_under_1() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lo := 1.0
	var hi := 0.0
	for i in 1000000:
		var r := Enhance.random01(rng)
		lo = minf(lo, r)
		hi = maxf(hi, r)
	check(lo >= 0.0, "0보다 작은 값이 나옴: %s" % lo)
	check(hi < 1.0, "1 이상이 나옴: %s" % hi)
	note("100만 번 뽑은 범위: %.8f ~ %.8f" % [lo, hi])


## 화면에 보여줄 확률 세 개: 합이 1, 실패 = 1 - 성공 - 퍼짐
func test_chances_for_display() -> void:
	for star in b.max_star:
		var c := Enhance.chances(b, star)
		check_near(c["success"] + c["fail"] + c["destroy"], 1.0, 1e-9, "%d강 확률 합" % star)
		check_eq(c["success"], b.success[star], "%d강 성공" % star)
		check_eq(c["destroy"], b.destroy[star], "%d강 퍼짐" % star)
	var c18 := Enhance.chances(b, 18)
	check_near(c18["fail"], 0.75, 1e-9, "18강 실패(유지)")


## 경계값: 18강 (성공 0.2, 퍼짐 0.05)
func test_decide_boundaries() -> void:
	var S := Enhance.Result.SUCCESS
	var D := Enhance.Result.DESTROY
	var F := Enhance.Result.FAIL
	check_eq(Enhance.decide(b, 18, 0.0), S, "r=0")
	check_eq(Enhance.decide(b, 18, 0.1999), S, "r=0.1999")
	check_eq(Enhance.decide(b, 18, 0.2), D, "r=0.2 (성공 확률과 같음 → 퍼짐 구간)")
	check_eq(Enhance.decide(b, 18, 0.2499), D, "r=0.2499")
	check_eq(Enhance.decide(b, 18, 0.25), F, "r=0.25 (성공+퍼짐과 같음 → 실패)")
	check_eq(Enhance.decide(b, 18, 0.9999999), F, "r=0.9999999")


## 강수별로 10만 번 굴려서 성공률·퍼짐률이 표와 1%p 안쪽
func test_rates_match_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var worst := 0.0
	var worst_where := ""
	for star in b.max_star:
		var counts := [0, 0, 0]   # SUCCESS, FAIL, DESTROY
		for i in ROLLS_PER_STAR:
			counts[Enhance.roll(b, star, rng)] += 1
		var succ_rate: float = counts[Enhance.Result.SUCCESS] / float(ROLLS_PER_STAR)
		var dest_rate: float = counts[Enhance.Result.DESTROY] / float(ROLLS_PER_STAR)
		check_near(succ_rate, b.success[star], RATE_TOLERANCE, "%d강 성공률" % star)
		check_near(dest_rate, b.destroy[star], RATE_TOLERANCE, "%d강 퍼짐률" % star)
		if star <= 17:
			check_eq(counts[Enhance.Result.DESTROY], 0, "%d강에서 퍼짐 발생" % star)
		for diff in [absf(succ_rate - b.success[star]), absf(dest_rate - b.destroy[star])]:
			if diff > worst:
				worst = diff
				worst_where = "%d강" % star
	note("표와 가장 크게 차이 난 곳: %s, %.3f%%p (허용 1%%p)" % [worst_where, worst * 100.0])


## 17강 이하에서는 어떤 난수가 나와도 절대 안 퍼짐
func test_never_destroys_at_17_or_below() -> void:
	for star in range(0, 18):
		var destroyed := 0
		for i in 10001:
			if Enhance.decide(b, star, i / 10001.0) == Enhance.Result.DESTROY:
				destroyed += 1
		check_eq(destroyed, 0, "%d강에서 퍼지는 난수가 있음" % star)


## 퍼지면 15강 + 고장, 스페어 사면 고장만 풀림
func test_destroy_then_spare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := GameState.new()

	# 20강에서 퍼질 때까지 누른다 (20강 퍼짐 7%)
	var result := Enhance.Result.FAIL
	var tries := 0
	while result != Enhance.Result.DESTROY and tries < 1000:
		tries += 1
		s.star = 20   # 성공해서 21강이 되면 다시 20강으로
		s.money = 1e12
		result = Enhance.try_enhance(s, b, rng)
	check_eq(result, Enhance.Result.DESTROY, "1000번 안에 안 퍼짐")
	check_eq(s.star, 15, "퍼진 뒤 강수")
	check(s.broken, "퍼졌는데 고장 상태가 아님")
	check_eq(s.star_before_break, 20, "퍼지기 직전 강수")
	check_eq(s.destroy_count, 1, "퍼짐 횟수")
	check_eq(s.current_hourly(b), 0.0, "고장인데 수익이 있음")

	# 고장 상태에서는 강화 불가
	s.money = 1e12
	check_eq(Enhance.block_reason(s, b), Enhance.Block.BROKEN, "고장인데 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, rng), Enhance.Result.BLOCKED, "고장인데 강화가 됨")
	check_eq(s.money, 1e12, "고장 상태 강화 시도에서 돈이 빠짐")

	# 돈 모자라면 스페어 못 삼
	var price := s.spare_price(b)
	check_eq(price, Economy.spare_price(b, 20), "스페어 가격이 20강 기준이 아님")
	s.money = price - 1.0
	check(not s.buy_spare(b), "돈이 모자란데 스페어를 삼")
	check(s.broken, "스페어를 못 샀는데 고장이 풀림")

	# 스페어 사면 고장만 풀림 (강수는 15 그대로)
	s.money = price + 500.0
	check(s.buy_spare(b), "돈이 있는데 스페어를 못 삼")
	check(not s.broken, "스페어를 샀는데 아직 고장")
	check_eq(s.star, 15, "스페어 산 뒤 강수")
	check_near(s.money, 500.0, 1e-6, "스페어 산 뒤 남은 돈")
	check(s.current_hourly(b) > 0.0, "수리했는데 수익이 0")
	check(not s.buy_spare(b), "고장이 아닌데 스페어를 또 삼")
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NO_MONEY, "수리 뒤 돈 500으로 15강 강화 가능으로 나옴")


## 강화 1번마다: 비용이 빠지고, 결과대로 강수가 바뀌고, 통계가 맞게 쌓임
func test_each_press_updates_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var s := GameState.new()
	s.money = 1e15
	for i in 2000:
		if s.broken:
			s.buy_spare(b)
		if s.star >= b.max_star:
			s.star = 0
		var star0 := s.star
		var money0 := s.money
		var cost := Economy.enhance_cost(b, star0)
		var result := Enhance.try_enhance(s, b, rng)
		check_near(s.money, money0 - cost, 1e-3, "%d번째: 비용이 정확히 안 빠짐" % i)
		match result:
			Enhance.Result.SUCCESS:
				check_eq(s.star, star0 + 1, "%d번째 성공인데 강수" % i)
			Enhance.Result.FAIL:
				check_eq(s.star, star0, "%d번째 실패인데 강수가 바뀜" % i)
			Enhance.Result.DESTROY:
				check(star0 >= 18, "%d번째: %d강에서 퍼짐" % [i, star0])
				check_eq(s.star, 15, "%d번째 퍼짐인데 강수" % i)
			_:
				check(false, "%d번째: 강화가 막힘" % i)
	check_eq(s.press_count(), 2000, "누른 횟수")
	note("2000번: 성공 %d / 실패 %d / 퍼짐 %d" % [s.success_count, s.fail_count, s.destroy_count])


func test_blocked_when_no_money_or_max() -> void:
	var rng := RandomNumberGenerator.new()
	var s := GameState.new()
	s.money = 19.0   # 0→1강 비용 20
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NO_MONEY, "19원으로 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, rng), Enhance.Result.BLOCKED, "돈이 모자란데 강화가 됨")
	check_eq(s.money, 19.0, "막혔는데 돈이 빠짐")
	check_eq(s.press_count(), 0, "막혔는데 횟수가 셈")
	s.money = 20.0
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NONE, "20원 딱 맞는데 강화 불가로 나옴")

	s.star = b.max_star
	s.money = 1e15
	check_eq(Enhance.block_reason(s, b), Enhance.Block.MAX_STAR, "30강인데 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, rng), Enhance.Result.BLOCKED, "30강인데 강화가 됨")


## 퍼질 수 있는 강수: 강화 비용만 있으면 막힘, 스페어값까지 있어야 누를 수 있음
func test_blocked_without_spare_reserve() -> void:
	var rng := RandomNumberGenerator.new()
	var s := GameState.new()
	s.star = 17   # 안 퍼지는 강수: 비용만 있으면 됨
	s.money = Economy.enhance_cost(b, 17)
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NONE, "17강: 비용이 딱 있는데 막힘")

	s.star = 18
	s.money = Economy.enhance_cost(b, 18)
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NO_MONEY, "18강: 스페어값 없이 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, rng), Enhance.Result.BLOCKED, "18강: 스페어값 없이 강화가 됨")
	check_eq(s.money, Economy.enhance_cost(b, 18), "막혔는데 돈이 빠짐")
	s.money = Economy.enhance_need(b, 18) - 1.0
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NO_MONEY, "18강: 1원 모자란데 강화 가능으로 나옴")
	s.money = Economy.enhance_need(b, 18)
	check_eq(Enhance.block_reason(s, b), Enhance.Block.NONE, "18강: 비용 + 스페어값이 딱 있는데 막힘")


## 이 규칙의 목적: 18~29강 어디서 퍼져도 스페어는 반드시 살 수 있음 (수익 0으로 갇히지 않음)
## 누를 수 있는 가장 적은 돈(비용 + 스페어값 딱 맞게)으로 퍼질 때까지 눌러 본다.
func test_destroy_never_leaves_you_stuck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for star in range(b.max_star):
		if b.destroy[star] <= 0.0:
			continue
		var s := GameState.new()
		var result := Enhance.Result.FAIL
		var tries := 0
		while result != Enhance.Result.DESTROY and tries < 2000:
			tries += 1
			s.star = star
			s.money = Economy.enhance_need(b, star)
			result = Enhance.try_enhance(s, b, rng)
		check_eq(result, Enhance.Result.DESTROY, "%d강: 2000번 안에 안 퍼짐" % star)
		check(s.can_buy_spare(b), "%d강에서 퍼졌는데 스페어를 못 삼 (돈 %s, 스페어 %s)" % [star, s.money, s.spare_price(b)])
		check(s.buy_spare(b), "%d강: 스페어 구매 실패" % star)
		check(s.current_hourly(b) > 0.0, "%d강: 수리 뒤에도 수익 0" % star)


## F5(강제로 퍼지게 하기)에서도 쓰는 퍼짐 처리
func test_break_engine_edge_cases() -> void:
	var s := GameState.new()
	s.star = 5
	Enhance.break_engine(s, b)
	check_eq(s.star, 5, "5강에서 퍼졌는데 강수가 올라감")
	check(s.broken, "퍼졌는데 고장이 아님")

	var s2 := GameState.new()
	s2.star = 22
	Enhance.break_engine(s2, b)
	Enhance.break_engine(s2, b)   # 이미 고장인데 또
	check_eq(s2.star_before_break, 22, "두 번 퍼뜨리면 직전 강수가 덮어써짐")
	check_eq(s2.star, 15, "퍼진 뒤 강수")
