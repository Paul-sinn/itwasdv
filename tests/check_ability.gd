## v5b U1 완료 기준 자동 확인: 기사 능력치 화면 (물류센터 화면 [능력치] 칸, 동네 팁·점, 꺼둔 동안 요약).
## 진짜 게임 화면(main.tscn)에 진짜 클릭·키를 넣어서 확인한다. 받은 포인트·찍은 능력치를 미리 넣는 것은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임으로 한다. 효과 숫자는 Ability.value / Trip.* 값과 맞춰 본다.
## ① 물류센터 화면에 능력치 5줄(이름 n/최대 · 효과, 설명, [+]) + 남은 포인트 + 예시 빌드 4줄
## ② [+] → 남은 포인트 −1, 그 줄 +1, 효과 글 바뀜, 직후 저장   ③ 포인트 0이거나 최대면 [+] 꺼짐 (눌러도 그대로)
## ④ [초기화] 한 번 = 안 바뀜 + 글 바뀜, 두 번 = 전부 0, 3초 지나면 원래 글   ⑤ 협상을 찍으면 강화 칸 "시간당 수입"이 커짐
## ⑥ 팁 이벤트 → 동네 "+금액" 옆에 "팁!" (다른 색, 보이는 곳 안)   ⑦ 포인트가 남으면 작은 화면 레벨 옆 점 (보이는 곳 안), 다 찍으면 없음
## ⑧ 꺼둔 동안 요약에 경험치 줄 (노하우 있을 때만)   ⑨ en에서 한글·키 안 보임   ⑩ 창 크기 5가지에서 물류센터 화면이 창 안
## 확인하는 동안 게임 시간을 멈춘다 (⑥만 빨리 돌림). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_ability.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_ability.json"
const TEST_SETTINGS := "user://test_ability_settings.cfg"
const HOUR := 3600
const NAMES_KO := { "unload": "상하차 속도", "kind": "친절", "nego": "협상", "knowhow": "노하우", "mech": "정비 지식" }
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]

var fails := PackedStringArray()
var checks := 0
var _hangul := RegEx.create_from_string("[가-힣ㄱ-ㅎㅏ-ㅣ]")


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")   # 아래에서 한국어 글자를 비교함 (OS 언어와 상관없이)
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Save.delete_file(TEST_SAVE)
	var b := Balance.load_file()

	# ⑦ (앞): 포인트가 없으면 점 없음 → 포인트를 받으면 작은 화면 레벨 옆에 점 (보이는 곳 안)
	var m := await _launch()
	var town = m.town
	var dot_none: bool = not town.point_dot.visible
	m.state.ability_points = 2
	await _frames(2)
	var dot_rect: Rect2 = town.point_dot.get_global_rect()
	var dot_on: bool = town.point_dot.is_visible_in_tree() and dot_rect.has_area() and _enclosed(m.visible_rects(), dot_rect) \
			and dot_rect.position.x >= town._level_label.get_global_rect().end.x

	# ① 물류센터 건물 클릭 → [능력치] 칸: 5줄 + 남은 포인트 + 예시 빌드
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var p = m.panel
	var d = p.driver
	var rows := []
	var rows_ok: bool = m.is_full() and p.building == "depot" and d.page == d.Page.ABILITY and d.ability_page_button.button_pressed \
			and d._points.is_visible_in_tree() and d._points.text == "남은 포인트 2" and d.add_buttons.size() == 5
	for id: String in Ability.ids(b):
		var line: Label = d._ability_lines[id]
		var want := "%s  %d/%d · " % [NAMES_KO[id], 0, Ability.max_points(b, id)]
		rows_ok = rows_ok and line.is_visible_in_tree() and line.text.begins_with(want) and d._ability_descs[id].is_visible_in_tree() \
				and d._ability_descs[id].text != "" and d.add_buttons[id].is_visible_in_tree() and not d.add_buttons[id].disabled
		rows.append(line.text)
	var builds: String = d._builds.text
	_report(rows_ok and d._builds.is_visible_in_tree() and builds.split("\n").size() == 4 and builds.begins_with("돈벌이 빌드: 협상 + 친절")
			and not d._quest_name.is_visible_in_tree(),
			"① 물류센터 [%s] 칸 '%s', 5줄 %s, 예시 빌드 %s" % [d.ability_page_button.text, d._points.text, rows, builds.split("\n")])

	# ② [+] (협상) → 남은 포인트 −1, 협상 +1, 효과 글 "단가 +1%", 직후 저장
	var nego_before: String = d._ability_lines["nego"].text
	_click(d.add_buttons["nego"].get_global_rect().get_center())
	var saved = _saved_state(b)   # 프레임을 돌리기 전에 (자동 저장이 아니라 누른 직후 저장인지)
	await _frames(2)
	var nego_after: String = d._ability_lines["nego"].text
	_report(Ability.points(m.state, "nego") == 1 and Ability.points_left(m.state) == 1 and d._points.text == "남은 포인트 1"
			and nego_after == "협상  1/%d · 단가 +%s" % [Ability.max_points(b, "nego"), Fmt.percent(Ability.value(b, m.state, "nego"))]
			and nego_after != nego_before and nego_after.ends_with("단가 +1%")
			and saved != null and Ability.points(saved, "nego") == 1 and Ability.points_left(saved) == 1,
			"② [+] 협상 → '%s' → '%s', '%s', 저장 파일 협상 %d" % [nego_before, nego_after, d._points.text, Ability.points(saved, "nego") if saved != null else -1])

	# ③ 남은 포인트 0 → [+] 전부 꺼짐, 눌러도 그대로 / 최대(협상 20)면 그 줄만 꺼짐
	_click(d.add_buttons["kind"].get_global_rect().get_center())
	await _frames(2)
	var all_off := true
	for id: String in d.add_buttons:
		all_off = all_off and d.add_buttons[id].disabled
	_click(d.add_buttons["unload"].get_global_rect().get_center())
	await _frames(2)
	var zero_ok: bool = all_off and Ability.points_left(m.state) == 0 and Ability.points(m.state, "unload") == 0 and d._points.text == "남은 포인트 0"
	m.state.ability_points = 59
	m.state.abilities["nego"] = Ability.max_points(b, "nego")   # 준비: 협상을 최대로
	await _frames(2)
	var max_ok: bool = d.add_buttons["nego"].disabled and not d.add_buttons["unload"].disabled
	_click(d.add_buttons["nego"].get_global_rect().get_center())
	await _frames(2)
	max_ok = max_ok and Ability.points(m.state, "nego") == Ability.max_points(b, "nego")
	_report(zero_ok and max_ok, "③ 남은 포인트 0이면 [+] 5개 꺼짐 (눌러도 그대로), 협상 %d/%d이면 협상 [+]만 꺼짐 '%s'" % [
			Ability.points(m.state, "nego"), Ability.max_points(b, "nego"), d._ability_lines["nego"].text])

	# ④ [초기화]: 한 번 = 안 바뀜 + "한 번 더 누르면 초기화", 두 번 = 전부 0 (저장), 3초 지나면 원래 글
	var spent_before: int = m.state.ability_points - Ability.points_left(m.state)
	_click(d.reset_button.get_global_rect().get_center())
	await _frames(2)
	var armed_text: String = d.reset_button.text
	var once_ok: bool = armed_text == "한 번 더 누르면 초기화" and m.state.ability_points - Ability.points_left(m.state) == spent_before
	_click(d.reset_button.get_global_rect().get_center())
	var saved_reset = _saved_state(b)
	await _frames(2)
	var twice_ok: bool = Ability.points_left(m.state) == m.state.ability_points and d.reset_button.text == "초기화" \
			and saved_reset != null and Ability.points_left(saved_reset) == saved_reset.ability_points
	for id: String in Ability.ids(b):
		twice_ok = twice_ok and Ability.points(m.state, id) == 0 and d._ability_lines[id].text.contains(" 0/")
	_click(d.add_buttons["unload"].get_global_rect().get_center())   # 다시 찍고 한 번만 누른 뒤 3초 기다림
	await _frames(2)
	_click(d.reset_button.get_global_rect().get_center())
	await _frames(2)
	var armed_again: bool = d.reset_button.text == "한 번 더 누르면 초기화"
	await _wait(Feel.ABILITY_RESET_ARM_SECONDS + 0.3)
	await _frames(2)
	var back_ok: bool = armed_again and d.reset_button.text == "초기화" and Ability.points(m.state, "unload") == 1
	_click(d.reset_button.get_global_rect().get_center())   # 3초 뒤 다시 한 번 = 또 첫 번째 누름 (초기화 안 됨)
	await _frames(2)
	back_ok = back_ok and Ability.points(m.state, "unload") == 1 and d.reset_button.text == "한 번 더 누르면 초기화"
	_report(once_ok and twice_ok and back_ok,
			"④ [초기화] 한 번 → '%s' (찍은 %d개 그대로), 두 번 → 전부 0·저장, %s초 지나면 '초기화' (그 뒤 한 번은 다시 첫 번째)" % [
			armed_text, spent_before, Fmt.num(Feel.ABILITY_RESET_ARM_SECONDS)])

	# ⑤ 협상을 찍으면 강화 칸 "시간당 수입"이 커짐 (= Trip.hourly_income)
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	_click(p.engine_tab_button.get_global_rect().get_center())
	await _frames(2)
	var hourly0 := Trip.hourly_income(b, m.state, 0)
	var income0: String = p._income.text
	_click(p.building_buttons["depot"].get_global_rect().get_center())
	await _frames(2)
	for i in 5:
		_click(d.add_buttons["nego"].get_global_rect().get_center())
		await _frames(1)
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	var hourly1 := Trip.hourly_income(b, m.state, 0)
	var income1: String = p._income.text
	_report(Ability.points(m.state, "nego") == 5 and hourly1 > hourly0 and income0.begins_with(tr("GARAGE_HOURLY") % Fmt.money(int(hourly0)))
			and income1.begins_with(tr("GARAGE_HOURLY") % Fmt.money(int(hourly1))) and income1 != income0,
			"⑤ 협상 0 → 5: 강화 칸 '%s' → '%s'" % [income0, income1])

	# ⑦ (뒤): 포인트를 다 찍으면 점 없음
	_key(KEY_ESCAPE)
	await _frames(2)
	var dot_left: bool = town.point_dot.is_visible_in_tree()   # 아직 남음 (59 − 6)
	var spent: int = m.state.ability_points - Ability.points_left(m.state)
	m.state.ability_points = spent + 1   # 준비: 1개만 남게
	await _frames(2)
	var dot_one: bool = town.point_dot.is_visible_in_tree()
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	_click(d.add_buttons["kind"].get_global_rect().get_center())
	await _frames(2)
	_key(KEY_ESCAPE)
	await _frames(2)
	_report(dot_none and dot_on and dot_left and dot_one and Ability.points_left(m.state) == 0 and not town.point_dot.visible and not m.is_full(),
			"⑦ 포인트 없으면 점 없음, 2개 받으면 레벨 옆 점 %s (보이는 곳 안), 마지막 1개를 [+]로 찍으면 점 없음" % dot_rect)
	await _close(m)

	# ⑥ 팁: 친절 최대로 동네를 빨리 돌려 팁 이벤트가 나면 그 "+금액" 옆에 "팁! +금액" (다른 색, 보이는 곳 안)
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	town = m.town
	m.state.truck(0).star = 20   # 바퀴를 짧게
	m.state.quest_index = Quest.count(b)
	m.state.ability_points = 59
	m.state.abilities["kind"] = Ability.max_points(b, "kind")
	var tip_want := tr("TOWN_TIP") % Fmt.money(Trip.tip_pay(b, m.state, 0))
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	var found := {}
	var t0 := Time.get_ticks_msec()
	while found.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
		found = _find_tip(town, tip_want)
	Engine.time_scale = 0.0
	var tip_ok := false
	var tip_desc := "팁이 안 나옴"
	if found.has("tip"):
		var tip: Label = found["tip"]
		var pay: Label = found["pay"]
		var tip_rect := Rect2(tip.global_position, tip.size)
		tip_ok = m.tips_found > 0 and town.tips_shown.has(tip_want) and pay.text.begins_with("+") \
				and tip.get_theme_color("font_color") == Feel.COLOR_TIP and pay.get_theme_color("font_color") != Feel.COLOR_TIP \
				and tip.position.x >= pay.size.x and _enclosed(m.visible_rects(), tip_rect) and town.area().encloses(Rect2(tip_rect.position - town.global_position, tip_rect.size))
		tip_desc = "'%s' 옆에 '%s' (팁 %d번, 보이는 곳 안 %s)" % [pay.text, tip.text, m.tips_found, _enclosed(m.visible_rects(), tip_rect)]
	_report(tip_ok, "⑥ 팁 이벤트 → 동네 %s" % tip_desc)
	await _close(m)

	# ⑧ 꺼둔 동안 요약: 노하우 20이면 "노하우로 경험치 +N" 줄, 노하우 0이면 그 줄 없음
	var summary := []
	var sum_ok := true
	for knowhow in [Ability.max_points(b, "knowhow"), 0]:
		var s := GameState.new_game()
		s.truck(0).star = 10
		s.money = 1000
		s.quest_index = Quest.count(b)
		s.ability_points = 20
		s.abilities["knowhow"] = knowhow
		Save.delete_file(TEST_SAVE)
		Save.write_file(TEST_SAVE, s, int(Time.get_unix_time_from_system()) - 3 * HOUR)
		m = await _launch()
		var r: Dictionary = m.offline_report
		var note: String = m.popup.note_text()
		var fits: bool = m.popup.visible and Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()) \
				and _enclosed(m.visible_rects(), m.popup.get_rect())
		if knowhow > 0:
			sum_ok = sum_ok and fits and r["xp"] > 0 and note.contains("노하우로 경험치 +%d" % r["xp"])
		else:
			sum_ok = sum_ok and fits and r["xp"] == 0 and not note.contains("경험치")
		summary.append("노하우 %d: '%s'" % [knowhow, note.replace("\n", " / ")])
		await _close(m)
	_report(sum_ok, "⑧ 꺼둔 3시간 요약 (작은 화면 안) %s" % [summary])

	# ⑩ ko: 창 크기 5가지 × [능력치]·[창고·할 일] 칸에서 물류센터 화면이 창 안, 동네·[작게]·[설정]과 안 겹침
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	_widest(m, b)
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var fit_ko: Array = await _check_fits(m)
	await _close(m)

	# ⑨ en: [능력치] 칸 (+ 초기화 한 번 누른 글), 동네 팁 글, 요약 경험치 줄에 한글·키 없음  ⑩ en도 창 안
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	_widest(m, b)
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	d = m.panel.driver
	var texts := _visible_texts(m)
	_click(d.reset_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(d.reset_button.text)
	texts.append(tr("TOWN_TIP") % Fmt.money(2500))
	texts.append(tr("RETURN_XP") % 123)
	texts.append(tr("RETURN_DETAIL") % [10, 1])
	var bad := texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and d.ability_page_button.text == "Skills" and d._ability_lines["nego"].text.begins_with("Negotiation"),
			"⑨ en 물류센터 [%s] 칸·팁·요약 글자 %d개에 한글·키 없음 %s" % [d.ability_page_button.text, texts.size(), bad])
	print("    en: %s" % [texts.slice(0, 12)])
	var fit_en: Array = await _check_fits(m)
	await _close(m)
	_report(fit_ko.is_empty() and fit_en.is_empty(),
			"⑩ ko·en 창 크기 %d가지 × [능력치]·[창고·할 일] 칸 (능력치 최대·초기화 글이 가장 길 때): 물류센터 화면이 창 안, 동네·[작게]·[설정]과 안 겹침 %s %s" % [
			FIT_SIZES.size(), fit_ko, fit_en])

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## 글자가 가장 길게: 능력치 전부 최대 (효과 숫자가 가장 큼), 받은 포인트 = 다 찍을 만큼
func _widest(m: Node, b: Balance) -> void:
	var total := 0
	for id: String in Ability.ids(b):
		m.state.abilities[id] = Ability.max_points(b, id)
		total += Ability.max_points(b, id)
	m.state.ability_points = total


## 큰 화면 창 크기 5가지 × 두 칸: 물류센터 화면이 창 안, 동네·[작게]·[설정]과 안 겹침. [초기화]는 한 번 누른 글로
func _check_fits(m: Node) -> Array:
	var d = m.panel.driver
	var bad := []
	for page_button: Button in [d.ability_page_button, d.depot_page_button]:
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_click(page_button.get_global_rect().get_center())
			if page_button == d.ability_page_button and not d.is_reset_armed():
				_click(d.reset_button.get_global_rect().get_center())
			await _frames(4)
			var pr: Rect2 = m.panel.get_global_rect()
			if not Rect2(Vector2.ZERO, Vector2(size)).encloses(pr) or pr.intersects(m.town.area()) \
					or pr.intersects(m.small_button.get_global_rect()) or pr.intersects(m.settings_button.get_global_rect()):
				bad.append("%s %dx%d %s" % [page_button.text, size.x, size.y, pr])
	root.size = Vector2i(1600, 900)
	await _frames(3)
	return bad


## 떠오르는 "+금액" 중 옆에 want("팁! +금액")가 붙은 것: { "pay": "+금액" 글자, "tip": 팁 글자 } (없으면 빈 묶음)
func _find_tip(town: Node, want: String) -> Dictionary:
	for pay: Label in town.payouts():
		for c in pay.get_children():
			if c is Label and c.text == want:
				return { "pay": pay, "tip": c }
	return {}


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["ABILITY_", "DRIVER_", "TOWN_", "RETURN_", "DEPOT_"]:
		if x.begins_with(prefix):
			return true
	return _hangul.search(x) != null


## 저장 파일의 상태 (없으면 null)
func _saved_state(b: Balance):
	var r := Save.read_file(TEST_SAVE, b)
	return r["state"] if r["status"] == Save.Status.OK else null


func _enclosed(rects: Array, r: Rect2) -> bool:
	for v: Rect2 in rects:
		if v.encloses(r):
			return true
	return false


## main 아래 보이는 Label·Button 글자 전부
func _visible_texts(m: Node) -> Array:
	var out := []
	for n in m.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "":
			out.append(n.text)
	return out


## 작은 화면 크기로 띄움 (게임 시간은 멈춤)
func _launch() -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	Engine.time_scale = 0.0
	await _frames(3)
	return m


func _close(m: Node) -> void:
	root.remove_child(m)
	m.queue_free()
	await process_frame


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


## cond가 참이 될 때까지 프레임을 돌림 (진짜 시간 seconds까지). 됐으면 true
func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await process_frame
	return true


## 진짜 시간 seconds 동안 기다림 (게임 시간이 멈춰 있어도)
func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _report(ok: bool, text: String) -> void:
	_check(ok, text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
