## enhance.gd + game_state.gd: 강화 굴리기, 퍼짐, 스페어 (사기·자동으로 쓰기)
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

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
	check_near(c18["fail"], 0.68, 1e-9, "+18 실패(유지)")


## 경계값: 18강 (성공 0.3, 퍼짐 0.02)
func test_decide_boundaries() -> void:
	var S := Enhance.Result.SUCCESS
	var D := Enhance.Result.DESTROY
	var F := Enhance.Result.FAIL
	check_eq(Enhance.decide(b, 18, 0.0), S, "r=0")
	check_eq(Enhance.decide(b, 18, 0.2999), S, "r=0.2999")
	check_eq(Enhance.decide(b, 18, 0.3), D, "r=0.3 (성공 확률과 같음 → 퍼짐 구간)")
	check_eq(Enhance.decide(b, 18, 0.3199), D, "r=0.3199")
	check_eq(Enhance.decide(b, 18, 0.32), F, "r=0.32 (성공+퍼짐과 같음 → 실패)")
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


## v6-bal B1 ②: +0~+29 어느 단계든 실패하면 단계 유지 (하락 없음). 진짜 강화 버튼(try_enhance)으로 실패가 나올 때까지 누름
func test_fail_keeps_star_at_every_step() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var kept := 0
	for star in b.max_star:
		var s := _game(star, 10 ** 15)
		s.spares = 1000
		var t := s.truck(0)
		var result := Enhance.Result.SUCCESS
		for i in 1000:
			t.star = star
			result = Enhance.try_enhance(s, b, 0, rng)["result"]
			if result == Enhance.Result.FAIL:
				break
		check_eq(result, Enhance.Result.FAIL, "+%d: 1000번 안에 실패가 안 나옴" % star)
		check_eq(t.star, star, "+%d 실패 뒤 단계" % star)
		if result == Enhance.Result.FAIL and t.star == star:
			kept += 1
		check_eq(Enhance.decide(b, star, 0.9999999), Enhance.Result.FAIL, "+%d 맨 끝 난수 = 실패" % star)
	note("+0~+%d 중 %d개 단계에서 실패 뒤 단계 그대로" % [b.max_star - 1, kept])


## 17강 이하에서는 어떤 난수가 나와도 절대 안 퍼짐
func test_never_destroys_at_17_or_below() -> void:
	for star in range(0, 18):
		var destroyed := 0
		for i in 10001:
			if Enhance.decide(b, star, i / 10001.0) == Enhance.Result.DESTROY:
				destroyed += 1
		check_eq(destroyed, 0, "%d강에서 퍼지는 난수가 있음" % star)


## 지시서 C1 ⑤: 퍼지는 단계에서 스페어 0이면 NO_SPARE, 퍼지면 스페어 −1·단계 15·통계 +1
func test_destroy_uses_spare() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var s := _game(18, 10 ** 12)
	check(Enhance.needs_spare(b, 18), "+18은 스페어가 있어야 함")
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NO_SPARE, "+18 스페어 0: 막힌 이유")
	check_eq(Enhance.try_enhance(s, b, 0, rng)["result"], Enhance.Result.BLOCKED, "+18 스페어 0인데 강화가 됨")
	check_eq(s.money, 10 ** 12, "막혔는데 돈이 빠짐")

	# 스페어 2개 들고 +20에서 퍼질 때까지 누른다 (+20 퍼짐 4%)
	s.spares = 2
	var result := Enhance.Result.FAIL
	var tries := 0
	while result != Enhance.Result.DESTROY and tries < 1000:
		tries += 1
		s.truck(0).star = 20   # 성공해서 +21이 되면 다시 +20으로
		result = Enhance.try_enhance(s, b, 0, rng)["result"]
	check_eq(result, Enhance.Result.DESTROY, "1000번 안에 안 퍼짐")
	var t := s.truck(0)
	check_eq(t.star, 15, "퍼진 뒤 단계")
	check_eq(s.spares, 1, "퍼진 뒤 스페어 (2 → 1)")
	check_eq(t.destroy_count, 1, "퍼짐 횟수")
	note("스페어 2개, +20에서 %d번째에 퍼짐 → +%d, 스페어 %d" % [tries, t.star, s.spares])

	# +15는 안 퍼지는 단계 → 스페어 없어도 누름
	s.spares = 0
	check(not Enhance.needs_spare(b, 15), "+15에 스페어가 필요하다고 나옴")
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NONE, "퍼진 뒤 +15: 스페어 없이 강화 가능")


## 스페어는 언제든 고정가로 산다
func test_buy_spare() -> void:
	var s := _game(0, 0)
	var price := Economy.spare_price(b)
	s.money = price - 1
	check(not s.can_buy_spare(b), "1원 모자란데 살 수 있다고 나옴")
	check(not s.buy_spare(b), "돈이 모자란데 스페어를 삼")
	check_eq(s.spares, 0, "못 샀는데 스페어가 늚")
	s.money = price * 2 + 500
	check(s.buy_spare(b) and s.buy_spare(b), "돈이 있는데 스페어를 못 삼")
	check_eq(s.spares, 2, "2개 산 뒤 스페어")
	check_eq(s.money, 500, "2개 산 뒤 남은 돈")
	check(not s.buy_spare(b), "500원으로 스페어를 삼")


## 퍼질 수 있는 단계 = destroy > 0. 그 단계는 스페어 1개 이상 + 비용이 있어야 누름
func test_needs_spare_matches_destroy() -> void:
	for star in b.max_star:
		check_eq(Enhance.needs_spare(b, star), b.destroy[star] > 0.0, "+%d 스페어 필요 여부" % star)
		var s := _game(star, Economy.base_enhance_cost(b, star))
		s.spares = 1
		check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NONE, "+%d: 비용 딱 + 스페어 1개인데 막힘" % star)
		s.money -= 1
		check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NO_MONEY, "+%d: 1원 모자란데 강화 가능" % star)
	check(not Enhance.needs_spare(b, b.max_star), "+30(최고)에서 스페어 필요로 나옴")


## 강화 1번마다: 비용이 빠지고, 결과대로 단계가 바뀌고, 통계가 맞게 쌓임
func test_each_press_updates_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var s := _game(0, 10 ** 15)
	var t := s.truck(0)
	for i in 2000:
		s.spares = 1
		if t.star >= b.max_star:
			t.star = 0
		var star0 := t.star
		var money0 := s.money
		var cost := Economy.base_enhance_cost(b, star0)
		var result: Enhance.Result = Enhance.try_enhance(s, b, 0, rng)["result"]
		check_eq(s.money, money0 - cost, "%d번째: 비용이 정확히 안 빠짐" % i)
		match result:
			Enhance.Result.SUCCESS:
				check_eq(t.star, star0 + 1, "%d번째 성공인데 단계" % i)
			Enhance.Result.FAIL:
				check_eq(t.star, star0, "%d번째 실패인데 단계가 바뀜" % i)
			Enhance.Result.DESTROY:
				check(star0 >= 18, "%d번째: +%d에서 퍼짐" % [i, star0])
				check_eq(t.star, 15, "%d번째 퍼짐인데 단계" % i)
				check_eq(s.spares, 0, "%d번째 퍼짐인데 스페어를 안 씀" % i)
			_:
				check(false, "%d번째: 강화가 막힘" % i)
	check_eq(t.success_count + t.fail_count + t.destroy_count, 2000, "누른 횟수")
	note("2000번: 성공 %d / 실패 %d / 퍼짐 %d" % [t.success_count, t.fail_count, t.destroy_count])


func test_blocked_when_no_money_or_max() -> void:
	var rng := RandomNumberGenerator.new()
	var s := _game(0, 34999)   # +0 비용 35000
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NO_MONEY, "34999원으로 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, 0, rng)["result"], Enhance.Result.BLOCKED, "돈이 모자란데 강화가 됨")
	check_eq(s.money, 34999, "막혔는데 돈이 빠짐")
	check_eq(s.truck(0).fail_count + s.truck(0).success_count, 0, "막혔는데 횟수가 셈")
	s.money = 35000
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.NONE, "35000원 딱 맞는데 강화 불가로 나옴")

	s.truck(0).star = b.max_star
	s.money = 10 ** 15
	s.spares = 5
	check_eq(Enhance.block_reason(s, b, 0), Enhance.Block.MAX_STAR, "+30인데 강화 가능으로 나옴")
	check_eq(Enhance.try_enhance(s, b, 0, rng)["result"], Enhance.Result.BLOCKED, "+30인데 강화가 됨")

	# 돈도 스페어도 없으면 스페어부터 알려 줌
	var s2 := _game(18, 0)
	check_eq(Enhance.block_reason(s2, b, 0), Enhance.Block.NO_SPARE, "+18 돈·스페어 둘 다 없음")


## 트럭 번호(i)대로 그 트럭만 강화됨
func test_enhance_picks_truck_i() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var s := _game(0, 10 ** 9)
	s.spares = 50   # +18 넘어가도 막히지 않게
	s.trucks.append(TruckState.new())
	s.truck(1).star = 3
	for k in 50:
		Enhance.try_enhance(s, b, 1, rng)["result"]
	var t1 := s.truck(1)
	check_eq(s.truck(0).star, 0, "트럭 0이 바뀜")
	check_eq(t1.success_count + t1.fail_count + t1.destroy_count, 50, "트럭 1 누른 횟수")


## 치트 F5 "강제로 퍼지게 하기": 스페어가 있으면 −1, 단계 내림, 통계는 안 셈
func test_force_destroy() -> void:
	var s := _game(5, 0)
	Enhance.force_destroy(s, b, 0)
	check_eq(s.truck(0).star, 5, "+5에서 퍼졌는데 단계가 올라감")
	check_eq(s.spares, 0, "스페어 0인데 음수가 됨")

	var s2 := _game(22, 0)
	s2.spares = 3
	Enhance.force_destroy(s2, b, 0)
	check_eq(s2.truck(0).star, 15, "+22 퍼진 뒤 단계")
	check_eq(s2.spares, 2, "스페어 3 → 2")
	check_eq(s2.truck(0).destroy_count, 0, "치트 퍼짐을 통계에 셈")


func _game(star: int, money: int) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.money = money
	return s
