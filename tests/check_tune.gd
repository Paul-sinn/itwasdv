## v2 2단계 완료 기준 자동 확인: 큰 화면 차고의 [튜닝] 칸을 진짜 키·마우스 입력으로 눌러 본다.
## - 처음엔 [엔진 강화] 칸, [튜닝] ↔ [엔진 강화] 오가기
## - 7부위 목록 (순서·이름·등급 색 글자·지금 효과), 줄을 클릭하면 자세히
## - 돈 부족: [튜닝] 잠김 + "약 N분 뒤 가능". 뜸 0.3초 동안은 결과가 안 나옴
## - 7부위 각각 일반 → 전설 (진짜 클릭. 등급은 한 번에 1씩, 비용만큼 돈이 빠짐, 통계)
## - 전설: "최고 등급" + 버튼 숨김. 짐칸: 타이어가 일반이면 "타이어를 올려야 대박이 나와요"
## - 고장 중에도 튜닝 됨, [엔진 강화] 칸 숫자가 튜닝 반영 값 (엔진오일·서스펜션 표시)
## - 창 크기 1280x720 ~ 3440x1440 + 창 모드 아무 크기에서 [튜닝] 칸이 창 안에, 동네·버튼과 안 겹침
## - F6 (작은 화면·큰 화면), 작은 화면 트럭 색 점, "대박!" 글자 (작은 화면 480x220 안, 보이는 곳 안)
## 진짜 저장·설정 파일은 안 건드린다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_tune.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Tune = preload("res://scripts/core/tune.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TuneText = preload("res://scripts/ui/tune_text.gd")
const TuneTab = preload("res://scripts/ui/tune_tab.gd")
const TEST_SAVE := "user://test_town_tune.json"
const TEST_SETTINGS := "user://test_town_settings.cfg"
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(3440, 1440),
		Vector2i(1366, 768), Vector2i(2200, 800), Vector2i(1280, 1300)]
const MAX_RECTS := 30
const MAX_CLICKS_PER_PART := 3000   ## 1.5% 등급업이라도 이만큼 누르면 거의 확실히 전설 (멈춤 방지)
const SEED := 20261112

var m: Node
var fails := PackedStringArray()
var checks := 0
var full_size := Vector2i(1600, 900)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.size = Feel.SMALL_SIZE
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = load(MAIN_SCENE).instantiate()
	Save.delete_file(TEST_SAVE)
	m.save_path = TEST_SAVE
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else full_size)
	m.rng.seed = SEED   # 매번 같은 결과
	await _frames(3)
	var b = m.balance
	var p = m.panel
	var t = p.tune

	# 1) 작은 화면 클릭 → 큰 화면. 처음엔 [엔진 강화] 칸
	_click(m.town.view_rect(Feel.TOWN_DEPOT_RECT).get_center())
	await _frames(3)
	_check(m.is_full() and p.visible, "작은 화면을 클릭했는데 큰 화면 차고가 아님")
	_check(p.current_tab() == p.Tab.ENGINE and p._engine_box.visible and not t.visible, "처음 칸이 [엔진 강화]가 아님")
	_check(p.engine_tab_button.button_pressed and not p.tune_tab_button.button_pressed, "[엔진 강화] 칸 버튼이 고른 상태가 아님")

	# 2) [튜닝] 칸으로
	_click(p.tune_tab_button.get_global_rect().get_center())
	await _frames(2)
	_check(p.current_tab() == p.Tab.TUNE and t.visible and not p._engine_box.visible, "[튜닝]을 눌렀는데 튜닝 칸이 아님")
	_check(p.tune_tab_button.button_pressed and not p.engine_tab_button.button_pressed, "[튜닝] 칸 버튼이 고른 상태가 아님")

	# 3) 7부위 목록: 순서, 이름, 등급(일반·회색), 효과 글자
	_check(Tune.PARTS.size() == 7, "부위가 7개가 아님: %d" % Tune.PARTS.size())
	for i in Tune.PARTS.size():
		var part: String = Tune.PARTS[i]
		var r: Dictionary = t.rows[part]
		_check(t._list.get_child(i) == r["row"], "%d번째 줄이 %s가 아님" % [i, part])
		_check(r["name"].text == TuneText.part_name(part) and TuneText.NAMES.has(part), "%s 이름이 이상함: '%s'" % [part, r["name"].text])
		_check(r["grade"].text == Tune.grade_name(b, 0), "%s 처음 등급이 '%s'" % [part, r["grade"].text])
		_check(r["grade"].get_theme_color("font_color") == Feel.TUNE_GRADE_COLORS[0], "%s 일반 등급 색이 회색이 아님" % part)
		_check(r["effect"].text == TuneText.effect_text(part, Tune.effect(b, part, 0)), "%s 효과 글자가 이상함: '%s'" % [part, r["effect"].text])
		_check(TuneText.info(part) != "", "%s 설명이 없음" % part)
	_check(TuneText.info("cargo").contains(TuneText.NO_JACKPOT_WARNING), "짐칸 설명에 '타이어를 올려야 대박이 나와요'가 없음")
	_check_tune_inside("목록")

	# 4) 돈 0: 첫 부위(터보) 자세히, 버튼 잠김 + "약 N분 뒤 가능"
	_check(t.selected == Tune.PARTS[0], "처음 고른 부위가 %s가 아님: %s" % [Tune.PARTS[0], t.selected])
	_check(t.tune_button.visible and t.tune_button.disabled, "돈 0원인데 [튜닝]이 눌림 상태")
	_check(t._wait.visible and t._wait.text.begins_with("약 "), "돈 모자랄 때 '약 N분 뒤 가능'이 없음: '%s'" % t._wait.text)
	_check(t._chance.text.contains(Fmt.money(Tune.cost(b, 0)) + "원") and t._chance.text.contains(Fmt.percent(Tune.up_chance(b, 0))),
			"비용·확률 줄이 이상함: '%s'" % t._chance.text)
	_check(t._effect.text.contains("→") and t._effect.text.contains(Tune.grade_name(b, 1)), "지금 → 다음 효과 줄이 이상함: '%s'" % t._effect.text)
	_check(not t._max_label.visible, "일반인데 '최고 등급'이 보임")

	# 5) 줄 클릭 → 짐칸 자세히. 타이어가 일반이면 경고
	_click(t.rows["cargo"]["row"].get_global_rect().get_center())
	await _frames(2)
	_check(t.selected == "cargo" and t._detail_name.text == TuneText.part_name("cargo"), "짐칸 줄을 눌렀는데 짐칸이 아님: %s" % t.selected)
	_check(t._warn.visible and t._warn.text == TuneText.NO_JACKPOT_WARNING, "타이어 일반인데 짐칸 경고가 없음")
	_click(t.rows["turbo"]["row"].get_global_rect().get_center())
	await _frames(2)
	_check(t.selected == "turbo" and not t._warn.visible, "터보를 골랐는데 짐칸 경고가 보임")

	# 6) 돈이 딱 비용만큼 → 버튼 눌림. 누르면 뜸(0.3초) 동안 결과 없음 → 결과 한 줄
	m.state.money = Tune.cost(b, 0)
	await _frames(1)
	_check(not t.tune_button.disabled and not t._wait.visible, "비용만큼 있는데 [튜닝]이 막힘")
	var presses0: int = m.state.tune_press_count
	var earned0: float = m.earned_total   # 뜸 동안 배송으로 들어온 돈은 빼고 봄
	_click(t.tune_button.get_global_rect().get_center())
	await _frames(2)
	_check(m.tuning and t.tune_button.disabled and t.tune_button.text.contains("중"), "누른 뒤 뜸(버튼 잠김)이 없음")
	_check(m.state.tune_press_count == presses0, "뜸이 끝나기 전에 결과가 나옴")
	_check(p._enhance_button.disabled, "튜닝 뜸 중인데 강화 버튼이 눌림 상태")
	_click(t.tune_button.get_global_rect().get_center())   # 뜸 중에 또 눌러도 무시
	var started := Time.get_ticks_msec()
	await _wait_tune()
	var waited := (Time.get_ticks_msec() - started) / 1000.0
	_check(waited >= Feel.TUNE_SUSPENSE * 0.8 and waited < Feel.TUNE_SUSPENSE + 0.5, "튜닝 뜸이 %.2f초 (기대 %.1f초)" % [waited, Feel.TUNE_SUSPENSE])
	_check(m.state.tune_press_count == presses0 + 1, "한 번 눌렀는데 튜닝 횟수가 %d 늘어남" % (m.state.tune_press_count - presses0))
	_check(absf(m.state.money - (m.earned_total - earned0)) < 0.001, "튜닝 비용이 안 빠짐: %.1f원 남음" % m.state.money)
	_check(t.result_text() != "", "튜닝 결과 한 줄이 없음")
	_check(t._stats.text.contains("튜닝 누른 횟수 %d" % m.state.tune_press_count), "튜닝 통계 줄이 안 맞음: '%s'" % t._stats.text)

	# 7) 7부위 각각 일반 → 전설 (진짜 클릭). 여기부터는 뜸을 없애고 빨리
	m.suspense_scale = 0.0
	var total_presses: int = m.state.tune_press_count
	var total_ups: int = m.state.tune_up_count
	for part in Tune.PARTS:
		_click(t.rows[part]["row"].get_global_rect().get_center())
		await _frames(1)
		_check(t.selected == part, "%s 줄을 눌렀는데 안 골라짐" % part)
		if part == "cargo":
			_check(not t._warn.visible, "타이어를 올렸는데 짐칸 경고가 그대로")
		var clicks := 0
		var ups := 0
		var bad_step := 0
		var bad_money := 0
		var bad_text := 0
		var bad_pop := 0
		while m.state.grade(part) < Tune.max_grade(b) and clicks < MAX_CLICKS_PER_PART:
			m.state.money = 1e9
			await _frames(1)
			var before: int = m.state.grade(part)
			var money_before: float = m.state.money
			var earned_before: float = m.earned_total
			_click(t.tune_button.get_global_rect().get_center())
			await _wait_tune()
			clicks += 1
			var after: int = m.state.grade(part)
			if after != before and after != before + 1:
				bad_step += 1
			var paid: float = money_before + (m.earned_total - earned_before) - m.state.money   # 그 사이 배송 돈은 빼고
			if absf(paid - Tune.cost(b, before)) > 0.001:
				bad_money += 1
			if after == before + 1:
				ups += 1
				if not (t.result_text().contains("등급업") and t.result_text().contains(Tune.grade_name(b, after))):
					bad_text += 1
				if t.rows[part]["grade"].scale.x <= 1.0 or t._detail_grade.scale.x <= 1.0:
					bad_pop += 1
			elif not t.result_text().contains("그대로"):
				bad_text += 1
		total_presses += clicks
		total_ups += ups
		var r: Dictionary = t.rows[part]
		_check(m.state.grade(part) == Tune.max_grade(b), "%s: %d번 눌렀는데 전설이 아님 (등급 %d)" % [part, clicks, m.state.grade(part)])
		_check(ups == Tune.max_grade(b), "%s: 등급업 %d번 (기대 %d번)" % [part, ups, Tune.max_grade(b)])
		_check(bad_step == 0, "%s: 등급이 1보다 많이 바뀐 적 %d번" % [part, bad_step])
		_check(bad_money == 0, "%s: 비용과 다르게 돈이 빠진 적 %d번" % [part, bad_money])
		_check(bad_text == 0, "%s: 결과 한 줄이 이상했던 적 %d번 (마지막 '%s')" % [part, bad_text, t.result_text()])
		_check(bad_pop == 0, "%s: 등급업인데 등급 글자가 안 커진 적 %d번" % [part, bad_pop])
		await _frames(1)
		_check(r["grade"].text == Tune.grade_name(b, Tune.max_grade(b)), "%s: 목록 등급 글자 '%s'" % [part, r["grade"].text])
		_check(r["grade"].get_theme_color("font_color") == Feel.TUNE_GRADE_COLORS[3], "%s: 전설 색이 금색이 아님" % part)
		_check(t._max_label.visible and not t.tune_button.visible and not t._chance.visible, "%s: 전설인데 '최고 등급'/버튼 숨김이 아님" % part)
		_check(r["effect"].text == TuneText.effect_text(part, Tune.effect(b, part, Tune.max_grade(b))), "%s: 전설 효과 글자 '%s'" % [part, r["effect"].text])
		print("  %s: %d번 눌러 전설" % [TuneText.part_name(part), clicks])
	_check(m.state.tune_press_count == total_presses and m.state.tune_up_count == total_ups,
			"통계가 안 맞음: 누름 %d/%d, 등급업 %d/%d" % [m.state.tune_press_count, total_presses, m.state.tune_up_count, total_ups])
	_check(t._stats.text.contains("튜닝 누른 횟수 %d · 등급업 %d" % [total_presses, total_ups]), "튜닝 통계 줄: '%s'" % t._stats.text)
	_check(m.state.best_grade() == Tune.max_grade(b) and m.town.truck.tune_grade == Tune.max_grade(b), "가장 높은 등급 점이 전설이 아님")
	_check(not p._style.border_color.is_equal_approx(Feel.COLOR_DANGER) or p.current_tab() == p.Tab.ENGINE, "[튜닝] 칸인데 빨간 테두리")

	# 8) 고장 중에도 튜닝 됨 (이미 있는 돈으로). 전설이 아닌 부위가 있어야 하니 터보를 레어로
	m.state.set_grade(b, "turbo", 1)
	_click(t.rows["turbo"]["row"].get_global_rect().get_center())
	m.state.broken = true
	m.state.money = 1e9
	await _frames(2)
	var broken_presses: int = m.state.tune_press_count
	_click(t.tune_button.get_global_rect().get_center())
	await _wait_tune()
	_check(m.state.tune_press_count == broken_presses + 1, "고장 중인데 튜닝이 안 됨")
	_check(not p._style.border_color.is_equal_approx(Feel.COLOR_DANGER), "[튜닝] 칸인데 고장 빨간 테두리가 보임")
	m.state.broken = false
	m.state.set_grade(b, "turbo", Tune.max_grade(b))

	# 9) [엔진 강화] 칸: 튜닝 반영 값 (전부 전설, 18강)
	_click(p.engine_tab_button.get_global_rect().get_center())
	await _frames(1)
	_check(p.current_tab() == p.Tab.ENGINE and p._engine_box.visible and not t.visible, "[엔진 강화]를 눌렀는데 엔진 칸이 아님")
	m.state.star = 18
	m.state.money = 0.0
	await _frames(2)
	var s = m.state
	var oil: float = Tune.effect(b, "engine_oil", s.grade("engine_oil"))
	var susp: float = Tune.effect(b, "suspension", s.grade("suspension"))
	var c: Dictionary = s.enhance_chances(b)
	_check(p._income.text.begins_with("시간당 %s원" % Fmt.money(s.current_hourly(b))), "시간당 수익이 튜닝 반영 값이 아님: '%s' (기대 %s)" % [p._income.text, Fmt.money(s.current_hourly(b))])
	_check(p._income.text.ends_with("성공하면 %s원" % Fmt.money(s.hourly_at(b, 19))), "성공하면 수익이 hourly_at(19강)이 아님: '%s'" % p._income.text)
	_check(p._cost.text.contains(Fmt.money(s.enhance_cost(b)) + "원"), "강화 비용이 튜닝 반영 값이 아님: '%s'" % p._cost.text)
	_check(p._cost.text.contains("엔진오일 −%s" % Fmt.percent(oil)), "엔진오일 깎은 표시가 없음: '%s'" % p._cost.text)
	_check(p._danger.text.contains(Fmt.percent(c["destroy"])), "퍼질 확률이 튜닝 반영 값이 아님: '%s'" % p._danger.text)
	_check(p._chances.text.contains("퍼짐 " + Fmt.percent(c["destroy"])) and p._chances.text.contains("실패(유지) " + Fmt.percent(c["fail"])),
			"확률 줄이 튜닝 반영 값이 아님: '%s'" % p._chances.text)
	_check(p._danger_note.visible and p._danger_note.text.contains("서스펜션") and p._danger_note.text.contains(Fmt.percent(susp)),
			"서스펜션 깎은 표시가 없음: '%s'" % p._danger_note.text)
	_check(oil > 0.0 and s.enhance_cost(b) < Economy.enhance_cost(b, 18), "엔진오일 전설인데 강화 비용이 엔진만 값보다 안 쌈")
	_check(susp > 0.0 and c["destroy"] < b.destroy[18], "서스펜션 전설인데 퍼짐 확률이 안 줄어듦")
	_check(s.current_hourly(b) > Economy.hourly_income(b, 18), "터보·대박 전설인데 시간당 수익이 엔진만 값보다 안 큼")
	_check(p._wait.visible and p._wait.text.begins_with("강화 비용 부족 · 약 "), "돈 모자람 안내: '%s'" % p._wait.text)
	m.state.money = s.enhance_need(b)
	await _frames(1)
	_check(not p._enhance_button.disabled, "튜닝 반영 '강화 누를 수 있는 돈'이 있는데 버튼이 막힘")
	m.state.money = s.enhance_need(b) - 1.0
	await _frames(1)
	_check(p._enhance_button.disabled, "튜닝 반영 '강화 누를 수 있는 돈'보다 1원 적은데 버튼이 눌림")

	# 10) 여러 창 크기에서 가장 긴 [튜닝] 칸 / 가장 긴 [엔진 강화] 칸이 창 안에, 동네·버튼과 안 겹침
	for size in SIZES:
		await _check_sizes(size)
	full_size = Vector2i(1600, 900)
	root.size = full_size
	await _frames(2)

	# 11) F6: 처음부터(F3) → 전부 레어 → … → 전설에서 멈춤. 큰 화면
	_key(KEY_F3)
	await _frames(1)
	_check(m.state.best_grade() == 0 and m.state.tune_press_count == 0, "F3 뒤 튜닝이 처음 상태가 아님")
	for k in Tune.max_grade(b) + 2:
		_key(KEY_F6)
		await _frames(1)
		var want := mini(k + 1, Tune.max_grade(b))
		var all_ok := true
		for part in Tune.PARTS:
			all_ok = all_ok and m.state.grade(part) == want
		_check(all_ok, "F6 %d번: 전부 %d등급이 아님 (%s)" % [k + 1, want, m.state.tune])
	_check(m.state.tune_press_count == 0, "F6이 튜닝 통계에 들어감")

	# 12) 작은 화면: F6, 트럭 색 점, "대박!" 글자
	_click(m.small_button.get_global_rect().get_center())
	await _frames(2)
	_check(not m.is_full(), "[작게]를 눌렀는데 작은 화면이 아님")
	_key(KEY_F3)
	await _frames(1)
	_check(m.town.truck.tune_grade == 0, "튜닝 전부 일반인데 트럭 색 점이 있음 (%d)" % m.town.truck.tune_grade)
	_key(KEY_F6)
	await _frames(1)
	_check(m.state.best_grade() == 1 and m.town.truck.tune_grade == 1, "작은 화면 F6: 레어 점이 아님 (%d)" % m.town.truck.tune_grade)
	m.state.set_grade(b, "navigation", 2)
	await _frames(1)
	_check(m.town.truck.tune_grade == 2, "한 부위만 에픽인데 점이 에픽이 아님 (%d)" % m.town.truck.tune_grade)
	# 대박 글자: 오른쪽 끝 집(마지막 집)·왼쪽 위 집에서도 작은 화면 480x220 안, 보이는 곳 안
	var town = m.town
	var before_shown: int = town.jackpots_shown
	for house in Feel.TOWN_HOUSES:
		town.show_payout(house, 1234567.0, 5.0)
	town.show_payout(Feel.TOWN_HOUSES - 1, 3.0)
	await _frames(1)
	_check(town.jackpots_shown == before_shown + Feel.TOWN_HOUSES, "대박 글자 수가 안 맞음")
	var win := Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE))
	var rects: Array = m.visible_rects()
	_check(rects.size() <= MAX_RECTS, "대박 글자 6개 떴을 때 보이는 곳 사각형 %d개 (%d개 이하)" % [rects.size(), MAX_RECTS])
	var jp_labels := 0
	for l: Label in town.payouts():
		var r := Rect2(l.position + town.position, l.get_combined_minimum_size())
		var rise: float = (Feel.JACKPOT_RISE if l.text.begins_with("대박") else Feel.PAYOUT_RISE) * town.text_scale
		_check(win.encloses(r) and r.position.y - rise >= -0.5, "작은 화면 '%s' 글자가 창 밖으로 나감: %s" % [l.text, r])
		_check(_covered(rects, r.get_center()), "'%s' 글자가 보이는 곳 밖" % l.text)
		if l.text.begins_with("대박"):
			jp_labels += 1
			_check(l.text == "대박! ×5 +1,234,567원", "대박 글자가 이상함: '%s'" % l.text)
			_check(l.get_theme_color("font_color") == Feel.COLOR_JACKPOT, "대박 글자가 금색이 아님")
			_check(l.get_theme_font_size("font_size") > Feel.PAYOUT_FONT_SIZE, "대박 글자가 보통 '+금액'보다 안 큼")
	_check(jp_labels == Feel.TOWN_HOUSES, "대박 글자 %d개 (기대 %d개)" % [jp_labels, Feel.TOWN_HOUSES])

	# 13) 진짜 배송에서 대박: 타이어·짐칸 전설로 60배속 → 대박이 나오고, 그때마다 "대박!" 글자
	m.state.set_grade(b, "tire", Tune.max_grade(b))
	m.state.set_grade(b, "cargo", Tune.max_grade(b))
	var jc0: int = m.state.jackpot_count
	var shown0: int = town.jackpots_shown
	_key(KEY_F2)
	var frames := 0
	while m.state.jackpot_count < jc0 + 3 and frames < 3000:
		await process_frame
		frames += 1
	_key(KEY_F2)
	await _frames(1)
	var got: int = m.state.jackpot_count - jc0
	_check(got >= 3, "60배속 %d프레임 동안 대박 배송이 %d번뿐" % [frames, got])
	_check(town.jackpots_shown - shown0 == got, "대박 %d번인데 '대박!' 글자 %d번" % [got, town.jackpots_shown - shown0])
	_check(m.town.truck.tune_grade == Tune.max_grade(b), "타이어·짐칸 전설인데 점이 전설이 아님")

	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## 이 창 크기에서 가장 긴 [튜닝] 칸, 가장 긴 [엔진 강화] 칸이 창 안에 들어오나
func _check_sizes(size: Vector2i) -> void:
	var tag := "%dx%d" % [size.x, size.y]
	full_size = size
	root.size = size
	var b = m.balance
	var p = m.panel
	var t = p.tune
	# [튜닝]: 짐칸 레어 + 타이어 일반(경고) + 돈 모자람 + 결과 한 줄
	m.state.broken = false
	m.state.star = 18
	m.state.money = 0.0
	for part in Tune.PARTS:
		m.state.set_grade(b, part, Tune.max_grade(b))
	m.state.set_grade(b, "tire", 0)
	m.state.set_grade(b, "cargo", 1)
	p.show_tab(p.Tab.TUNE)
	t.select("cargo")
	t.show_result("짐칸 등급업!  레어 → 에픽", TuneTab.grade_color(2))
	await _frames(3)
	_check(t._warn.visible and t._wait.visible and t.tune_button.visible and t.result_text() != "",
			"%s: 가장 긴 [튜닝] 칸 상태가 아님" % tag)
	_check_layout(tag + " [튜닝]")
	# 줄마다 효과 글자가 줄 안에 들어오나 (잘려도 줄 밖으로는 안 나감)
	for part in Tune.PARTS:
		var row: Rect2 = t.rows[part]["row"].get_global_rect()
		_check(row.grow(0.5).encloses(t.rows[part]["effect"].get_global_rect()), "%s: %s 줄 효과 글자가 줄 밖" % [tag, part])
		var el: Label = t.rows[part]["effect"]
		var need: float = el.get_theme_font("font").get_string_size(el.text, HORIZONTAL_ALIGNMENT_LEFT, -1, el.get_theme_font_size("font_size")).x
		_check(need <= el.size.x + 0.5, "%s: %s 효과 글자가 잘림 '%s' (%.0f > %.0f)" % [tag, part, el.text, need, el.size.x])
	# [엔진 강화]: 전부 전설(서스펜션 표시) + 18강 돈 모자람 + "엔진 퍼짐!" 결과
	m.state.set_grade(b, "tire", Tune.max_grade(b))
	m.state.set_grade(b, "cargo", Tune.max_grade(b))
	p.show_tab(p.Tab.ENGINE)
	p.show_result("엔진 퍼짐!", Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE)
	await _frames(3)
	_check_layout(tag + " [엔진 강화]")
	p.clear_result()
	t.clear_result()


## 큰 화면 배치: 차고·동네·버튼이 창 안에 다 들어오고 서로 안 겹치나 (check_garage.gd와 같음)
func _check_layout(tag: String) -> void:
	var win := _win()
	var pr: Rect2 = m.panel.get_global_rect()
	var town: Rect2 = m.town.area()
	var sb: Rect2 = m.small_button.get_global_rect()
	var gb: Rect2 = m.settings_button.get_global_rect()
	_check(win.encloses(pr), "%s: 차고가 창 밖으로 나감 %s (창 %s)" % [tag, pr, win.size])
	_check(win.encloses(town), "%s: 동네가 창 밖으로 나감 %s" % [tag, town])
	_check(not pr.intersects(town), "%s: 차고와 동네가 겹침 %s / %s" % [tag, pr, town])
	_check(not pr.intersects(sb) and not pr.intersects(gb), "%s: 차고가 [작게]/[설정]과 겹침 %s" % [tag, pr])
	_check(m.town.zoom > 1.0, "%s: 큰 화면 동네가 작은 화면보다 작음 (배수 %.2f)" % [tag, m.town.zoom])


func _check_tune_inside(tag: String) -> void:
	_check(_win().encloses(m.panel.get_global_rect()), "%s: 차고가 창 밖 %s" % [tag, m.panel.get_global_rect()])


## 튜닝 뜸이 끝날 때까지 (진짜 시간)
func _wait_tune() -> void:
	var n := 0
	while m.tuning and n < 2000:
		await process_frame
		n += 1


func _covered(rects: Array, pt: Vector2) -> bool:
	for r: Rect2 in rects:
		if r.has_point(pt):
			return true
	return false


func _win() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(root.size))


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = pressed
		root.push_input(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
