## setting.gd: 세팅 돌리기 (등급업·천장·옵션 뽑기·고르기·잠금) + balance.json setting 묶음
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

const JUNK := ["junk_ride", "junk_scent", "junk_cupholder", "junk_radio", "junk_gloss"]
const ROLLS := 100000

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 돈 많은 트럭 1대. star = 강화 단계
func _game(star: int = 10) -> GameState:
	var s := GameState.new_game()
	s.truck(0).star = star
	s.money = 10 ** 15
	return s


## setting 묶음 일부를 바꾼 balance
func _balance_with(changes: Dictionary) -> Balance:
	var d := real_balance_dict()
	for k in changes:
		d["setting"][k] = changes[k]
	var b2: Balance = Balance.from_dict(d)
	check(b2.is_ok(), "바꾼 balance가 막힘: %s" % ", ".join(b2.errors))
	return b2


## 천장 없이 (아주 큰 천장)
func _no_ceiling() -> Balance:
	return _balance_with({ "ceiling": [1000000000, 1000000000, 1000000000, 1000000000] })


## v4 C1 ①: json 값이 지시서 "옮길 숫자" 표와 같음
func test_json_matches_spec() -> void:
	check(b.is_ok(), "진짜 balance.json에 문제가 있음: %s" % ", ".join(b.errors))
	check_eq(b.lines_by_grade, PackedInt64Array([1, 2, 3, 3, 3]), "lines_by_grade")
	check_eq([b.fuel_cut_cap, b.maint_cut_cap, b.engine_guard_cap], [0.6, 0.6, 0.3], "fuel_cut_cap·maint_cut_cap (v7-bal: 각자 60%), engine_guard_cap")
	check_eq(b.up_chance, PackedFloat64Array([0.3, 0.08, 0.02, 0.003]), "up_chance")
	check_eq(b.ceiling, PackedInt64Array([5, 20, 80, 500]), "ceiling")
	check_eq(b.roll_cost, PackedInt64Array([20000, 80000, 1600000, 6000000, 10000000]), "roll_cost (v6-bal Q7-1)")
	check_eq(b.overboost_mult, 2.0, "오버부스트 걸린 바퀴 2배 (v6-bal: 초 제한 없음)")
	var want := {
		"speed": ["common", 10.0, [0.03, 0.05, 0.08, 0.13, 0.20]],
		"fuel_cut": ["common", 10.0, [0.07, 0.12, 0.20, 0.30, 0.45]],   # v7-bal Q17-3
		"cargo": ["own", 10.0, [0.035, 0.055, 0.085, 0.14, 0.21]],   # v7-bal 시작값 (시뮬로 다시)
		"engine_guard": ["own", 10.0, [0.0, 0.0, 0.04, 0.06, 0.10]],
		"overboost": ["own", 10.0, [0.03, 0.06, 0.09, 0.15, 0.24]],
		"maint_cut": ["own", 10.0, [0.18, 0.30, 0.45, 0.55, 0.60]],   # v7-bal C4 시뮬 (순정 15 → 18%)
	}
	for j in JUNK:
		want[j] = ["junk", 12.0, [0.0, 0.0, 0.0, 0.0, 0.0]]
	check_eq(b.setting_options.keys(), want.keys(), "옵션 id")
	for id in want:
		var o: Dictionary = b.setting_options[id]
		check_eq([o["kind"], o["weight"], o["values"]], [want[id][0], want[id][1], PackedFloat64Array(want[id][2])], "옵션 %s" % id)
		check_eq(Setting.option_kind(b, id), want[id][0], "option_kind %s" % id)
		note("%s: %s, 가중치 %s, 수치 %s" % [id, o["kind"], o["weight"], o["values"]])
	check_eq(Setting.part_ids(b), ["cargo_box", "ecu", "tire"], "부품 (json 순서)")
	check_eq([Setting.unlock_star(b, "cargo_box"), Setting.unlock_star(b, "ecu")], [0, 5], "열리는 단계")
	check_eq(b.setting_parts["cargo_box"]["options"], PackedStringArray(["speed", "fuel_cut", "cargo"] + JUNK), "적재함 옵션")
	check_eq(b.setting_parts["ecu"]["options"], PackedStringArray(["speed", "fuel_cut", "engine_guard", "overboost"] + JUNK), "ECU 옵션")
	note("줄 수 %s / 등급업 %s / 천장 %s / 돌리기 비용 %s" % [b.lines_by_grade, b.up_chance, b.ceiling, b.roll_cost])


## 작은 함수들: 최고 등급, 최고 등급에서 등급업 0·천장 0, 잡옵 수치 0
func test_small_functions() -> void:
	check_eq(Setting.max_grade(b), 4, "최고 등급")
	check_eq(Setting.up_chance(b, 4, GameState.new()), 0.0, "프로토타입 등급업 확률")
	check_eq(Setting.ceiling(b, 4), 0, "프로토타입 천장")
	check_eq(Setting.up_chance(b, 3, GameState.new()), 0.003, "레이싱 등급업 확률")
	check_eq(Setting.ceiling(b, 0), 5, "순정 천장")
	check_eq(Setting.roll_cost(b, 4, GameState.new()), 10000000, "프로토타입 돌리기 비용")
	check_eq(Setting.option_value(b, "speed", 4), 0.2, "프로토타입 이동 속도")
	check_eq(Setting.option_value(b, "junk_cupholder", 3), 0.0, "잡옵 수치")
	var t := TruckState.new()
	var p := t.part("cargo_box")
	check_eq([p["grade"], p["lines"], p["counters"], p["pending"]], [0, [], [0, 0, 0, 0, 0], null], "처음 상태")
	check(t.part("cargo_box") == p, "part()가 같은 묶음을 안 돌려줌")


## v4 C1 ②: 등급별 등급업 비율 (천장 없이 10만 번)이 up_chance와 1%p 안쪽 (레이싱→프로토타입 0.3%는 0.1%p)
func test_up_rates() -> void:
	var b2 := _no_ceiling()
	var rng := _rng(2024)
	for grade in 4:
		var s := _game(10)
		var p := s.truck(0).part("ecu")
		var ups := 0
		for k in ROLLS:
			p["grade"] = grade
			var r := Setting.try_roll(s, b2, 0, "ecu", rng)
			if r["grade_up"]:
				ups += 1
				check(not r["pity"], "천장 없이 pity")
			Setting.choose(s, 0, "ecu", false)
		var rate := ups / float(ROLLS)
		var tol := 0.001 if grade == 3 else 0.01
		check_near(rate, b.up_chance[grade], tol, "등급 %d 등급업 비율" % grade)
		note("등급 %d → %d: 10만 번 중 %d번 = %.3f%% (표 %.1f%%, 허용 %.1f%%p)" % [grade, grade + 1, ups, rate * 100.0, b.up_chance[grade] * 100.0, tol * 100.0])


## v4 C1 ③: 천장 — 확률 0인 balance에서 정확히 ceiling번째에 등급업 + pity, 카운터 0
func test_ceiling() -> void:
	var b0 := _balance_with({ "up_chance": [0, 0, 0, 0] })
	var rng := _rng(1)
	for grade in 4:
		var s := _game(10)
		var p := s.truck(0).part("cargo_box")
		p["grade"] = grade
		var need := Setting.ceiling(b0, grade)
		for k in range(1, need):
			var r := Setting.try_roll(s, b0, 0, "cargo_box", rng)
			check(r["ok"] and not r["grade_up"], "등급 %d: %d번째에 등급업" % [grade, k])
			check_eq(p["counters"][grade], k, "등급 %d: %d번째 뒤 카운터" % [grade, k])
			Setting.choose(s, 0, "cargo_box", true)
		var last := Setting.try_roll(s, b0, 0, "cargo_box", rng)
		check(last["grade_up"] and last["pity"], "등급 %d: %d번째(천장)에 등급업 + pity가 아님: %s" % [grade, need, last])
		check_eq(p["counters"][grade], 0, "등급 %d: 천장 뒤 카운터" % grade)
		check_eq(p["pending"]["grade"], grade + 1, "등급 %d: 새 상태 등급" % grade)
		check_eq(p["grade"], grade, "등급 %d: 고르기 전에는 등급 그대로" % grade)
	# 최고 등급은 카운터를 안 셈
	var s4 := _game(10)
	var p4 := s4.truck(0).part("cargo_box")
	p4["grade"] = 4
	var r4 := Setting.try_roll(s4, b0, 0, "cargo_box", rng)
	check(r4["ok"] and not r4["grade_up"], "프로토타입에서 등급업")
	check_eq(p4["counters"], [0, 0, 0, 0, 0], "프로토타입에서 카운터를 셈")
	check_eq(p4["pending"]["lines"].size(), 3, "프로토타입 다시 돌리기 3줄")


## v4 C1 ④: 순정→스트리트 평균 횟수 10만 번 = 2.77 ± 0.05 (30%, 천장 5: 1 + 0.7 + 0.49 + 0.343 + 0.2401)
func test_average_rolls_to_street() -> void:
	var rng := _rng(77)
	var total := 0
	var s := _game(10)
	for k in ROLLS:
		s.truck(0).settings.erase("cargo_box")   # 처음 상태 (카운터 0)
		var n := 0
		while true:
			n += 1
			var r := Setting.try_roll(s, b, 0, "cargo_box", rng)
			Setting.choose(s, 0, "cargo_box", true)
			if r["grade_up"]:
				break
		total += n
	var avg := total / float(ROLLS)
	check_near(avg, 2.7731, 0.05, "순정→스트리트 평균 횟수")
	note("순정→스트리트: 10만 번 평균 %.4f번 (식 2.7731)" % avg)


## v4 C1 ⑤: 옵션 뽑기 10만 줄이 option_chances와 1%p 안쪽, 순정·스트리트 ECU에서 engine_guard 0번
func test_option_draws() -> void:
	var b2 := _balance_with({ "up_chance": [0, 0, 0, 0], "ceiling": [1000000000, 1000000000, 1000000000, 1000000000] })
	var rng := _rng(99)
	for part in ["cargo_box", "ecu"]:
		var chances := Setting.option_chances(b2, part, 2)
		var sum := 0.0
		for op in chances:
			sum += chances[op]
		check_near(sum, 1.0, 1e-12, "%s 확률 합" % part)
		var counts := {}
		var lines := 0
		var s := _game(10)
		s.truck(0).part(part)["grade"] = 2
		while lines < ROLLS:
			Setting.try_roll(s, b2, 0, part, rng)
			for op in s.truck(0).part(part)["pending"]["lines"]:
				counts[op] = counts.get(op, 0) + 1
				lines += 1
			Setting.choose(s, 0, part, false)
		var worst := 0.0
		for op in chances:
			var rate: float = counts.get(op, 0) / float(lines)
			check_near(rate, chances[op], 0.01, "%s 스포츠 %s" % [part, op])
			worst = maxf(worst, absf(rate - chances[op]))
		for op in counts:
			check(chances.has(op), "%s: 뽑히면 안 되는 옵션 %s" % [part, op])
		note("%s 스포츠 %d줄: 표와 가장 큰 차이 %.3f%%p, 확률 %s" % [part, lines, worst * 100.0, chances])
	# 순정·스트리트 ECU: 엔진 보호 수치 0 → 안 뽑힘
	for grade in [0, 1]:
		var chances := Setting.option_chances(b2, "ecu", grade)
		check(not chances.has("engine_guard"), "ECU 등급 %d 확률표에 엔진 보호가 있음" % grade)
		var s := _game(10)
		var guard := 0
		for k in 20000:
			s.truck(0).part("ecu")["grade"] = grade
			Setting.try_roll(s, b2, 0, "ecu", rng)
			guard += s.truck(0).part("ecu")["pending"]["lines"].count("engine_guard")
			Setting.choose(s, 0, "ecu", false)
		check_eq(guard, 0, "ECU 등급 %d에서 엔진 보호가 뽑힘" % grade)
	check(Setting.option_chances(b2, "ecu", 2).has("engine_guard"), "ECU 스포츠부터는 엔진 보호가 뽑혀야 함")
	# 가중치 비율: 적재함 순정 = 이동 속도 10, 기름값 10, 적재량 10, 잡옵 12 × 5 → 합 90
	check_near(Setting.option_chances(b, "cargo_box", 0)["speed"], 10.0 / 90.0, 1e-12, "적재함 이동 속도 확률")
	check_near(Setting.option_chances(b, "cargo_box", 0)["junk_gloss"], 12.0 / 90.0, 1e-12, "적재함 잡옵 하나 확률")


## v4 C1 ⑥: 줄 수 1/2/3/3/3 (새 상태 줄 수도)
func test_line_counts() -> void:
	var b0 := _balance_with({ "up_chance": [0, 0, 0, 0], "ceiling": [1000000000, 1000000000, 1000000000, 1000000000] })
	var want := [1, 2, 3, 3, 3]
	var rng := _rng(3)
	for grade in 5:
		check_eq(Setting.line_count(b, grade), want[grade], "등급 %d 줄 수" % grade)
		var s := _game(10)
		s.truck(0).part("cargo_box")["grade"] = grade
		Setting.try_roll(s, b0, 0, "cargo_box", rng)
		check_eq(s.truck(0).part("cargo_box")["pending"]["lines"].size(), want[grade], "등급 %d 새 상태 줄 수" % grade)


## v4 C1 ⑦: 고르기 — 등급업 뒤 예전 것: 등급·줄 그대로, 카운터 0 / 새 것: 바뀜 / 고르기 전: PENDING
func test_choose() -> void:
	var b1 := _balance_with({ "up_chance": [1, 1, 1, 1] })   # 늘 등급업
	var rng := _rng(8)
	var s := _game(10)
	var p := s.truck(0).part("cargo_box")
	p["grade"] = 1
	p["lines"] = ["speed", "junk_radio"]
	p["counters"][1] = 7
	var money0 := s.money
	var r := Setting.try_roll(s, b1, 0, "cargo_box", rng)
	check(r["ok"] and r["grade_up"] and not r["pity"], "확률 100%%인데 등급업이 아님: %s" % r)
	check_eq(s.money, money0 - 80000, "스트리트 돌리기 비용 8만")
	check_eq(p["counters"][1], 0, "등급업 뒤 카운터 0")
	check_eq(p["pending"]["grade"], 2, "새 상태 등급")
	check_eq(Setting.block_reason(s, b1, 0, "cargo_box"), Setting.Block.PENDING, "고르기 전 막힌 이유")
	check_eq(Setting.try_roll(s, b1, 0, "cargo_box", rng), { "ok": false }, "고르기 전에 또 돌려짐")
	check_eq(s.money, money0 - 80000, "막혔는데 돈이 빠짐")
	Setting.choose(s, 0, "cargo_box", false)
	check_eq([p["grade"], p["lines"], p["pending"]], [1, ["speed", "junk_radio"], null], "예전 것 고름: 그대로")
	check_eq(p["counters"][1], 0, "예전 것 골라도 카운터 0")
	check_eq(Setting.block_reason(s, b1, 0, "cargo_box"), Setting.Block.NONE, "고른 뒤 다시 돌릴 수 있음")
	Setting.try_roll(s, b1, 0, "cargo_box", rng)
	var new_lines: Array = p["pending"]["lines"].duplicate()
	Setting.choose(s, 0, "cargo_box", true)
	check_eq([p["grade"], p["lines"], p["pending"]], [2, new_lines, null], "새 것 고름: 바뀜")
	Setting.choose(s, 0, "cargo_box", true)   # pending 없음 → 아무 일 없음
	check_eq([p["grade"], p["lines"]], [2, new_lines], "pending 없이 choose")
	# 고른 줄이 효과에 들어감 (스포츠 수치로)
	check_near(Setting.total(b, s.truck(0), "speed"), new_lines.count("speed") * 0.08, 1e-12, "고른 줄의 이동 속도 합")


## v4 C1 ⑧: ECU는 +4에서 LOCKED, +5에서 열림. 돈 모자라면 NO_MONEY
func test_lock_and_money() -> void:
	var rng := _rng(4)
	var s := _game(4)
	check(not Setting.unlocked(b, s, 0, "ecu"), "+4에서 ECU가 열림")
	check_eq(Setting.block_reason(s, b, 0, "ecu"), Setting.Block.LOCKED, "+4 ECU")
	check_eq(Setting.try_roll(s, b, 0, "ecu", rng), { "ok": false }, "+4에서 ECU가 돌려짐")
	check_eq(Setting.block_reason(s, b, 0, "cargo_box"), Setting.Block.NONE, "+4 적재함은 열림")
	s.truck(0).star = 5
	check(Setting.unlocked(b, s, 0, "ecu"), "+5에서 ECU가 안 열림")
	check_eq(Setting.block_reason(s, b, 0, "ecu"), Setting.Block.NONE, "+5 ECU")
	var s0 := _game(0)
	s0.money = 19999
	check_eq(Setting.block_reason(s0, b, 0, "cargo_box"), Setting.Block.NO_MONEY, "19999원으로 순정 돌리기")
	check_eq(Setting.try_roll(s0, b, 0, "cargo_box", rng), { "ok": false }, "돈이 모자란데 돌려짐")
	check_eq(s0.money, 19999, "막혔는데 돈이 빠짐")
	s0.money = 20000
	check(Setting.try_roll(s0, b, 0, "cargo_box", rng)["ok"], "2만 원 딱 맞는데 못 돌림")
	check_eq(s0.money, 0, "돌린 뒤 돈")


## total: 그 트럭의 모든 부품, 지금 쓰는 줄만 (pending 줄은 안 셈)
func test_total() -> void:
	var s := _game(10)
	var t := s.truck(0)
	t.part("cargo_box")["grade"] = 2
	t.part("cargo_box")["lines"] = ["speed", "speed", "junk_ride"]
	t.part("ecu")["grade"] = 0
	t.part("ecu")["lines"] = ["speed"]
	t.part("ecu")["pending"] = { "grade": 1, "lines": ["speed", "speed"] }
	check_near(Setting.total(b, t, "speed"), 0.08 + 0.08 + 0.03, 1e-12, "이동 속도 합 (pending 빼고)")
	check_eq(Setting.total(b, t, "cargo"), 0.0, "없는 옵션 0")
	check_eq(Setting.total(b, t, "junk_ride"), 0.0, "잡옵 수치 0")


## balance setting 검사: 길이, 범위, 등급이 오를수록 줄지 않음, 모르는 옵션, 뽑을 옵션 없음
func test_setting_validation() -> void:
	var d := real_balance_dict()
	var st: Dictionary = d["setting"]
	st["lines_by_grade"] = [1, 2, 3, 3]
	st["up_chance"][1] = 1.5
	st["ceiling"][0] = 0
	st["roll_cost"] = [20000, 10000, 400000, 2000000, 10000000]
	st["fuel_cut_cap"] = 1.2
	st.erase("maint_cut_cap")
	st["overboost_mult"] = 0.5
	st["options"]["speed"]["values"] = [0.03, 0.02, 0.08, 0.13, 0.2]
	st["options"]["cargo"]["kind"] = "special"
	st["parts"]["ecu"]["options"].append("wing")
	var b2: Balance = Balance.from_dict(d)
	for part in ["setting.lines_by_grade 길이가 4개", "setting.up_chance[1] = 1.5", "setting.ceiling[0] = 0",
			"setting.roll_cost[1] = 10000 (앞 등급", "setting.fuel_cut_cap = 1.2", "setting.maint_cut_cap 이 없음", "setting.overboost_mult = 0.5",
			"setting.options.speed.values[1] = 0.02 (앞 등급", "setting.options.cargo.kind = special",
			"setting.parts.ecu.options 에 모르는 옵션: wing"]:
		check(_has_error(b2, part), "못 찾음: %s" % part)
	note("찾은 문제: " + " / ".join(b2.errors))
	# 등급 수치가 전부 0이고 잡옵도 없는 부품 → 뽑을 옵션 없음
	var d2 := real_balance_dict()
	d2["setting"]["parts"]["ecu"]["options"] = ["engine_guard"]
	var b3: Balance = Balance.from_dict(d2)
	check(_has_error(b3, "setting.parts.ecu: 등급 0에서 뽑을 수 있는 옵션이 없음"), "뽑을 옵션 없는 등급을 못 찾음: %s" % ", ".join(b3.errors))
	var d3 := real_balance_dict()
	d3["setting"].erase("options")
	check(_has_error(Balance.from_dict(d3), "setting.options 가 없거나"), "옵션 묶음 없음을 못 찾음")


func _has_error(bb: Balance, part: String) -> bool:
	for e in bb.errors:
		if e.contains(part):
			return true
	return false
