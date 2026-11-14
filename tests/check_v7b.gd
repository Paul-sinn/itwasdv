## v7b U1 (틀: 계산 C1 전) 자동 확인. 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 본다.
## 노선 값은 C1 전이라 RouteStub(지시서 Trip 함수와 같은 이름의 껍데기)에 준비로 넣는다. C1을 합치면 준비를 진짜 상태(대리점 + 단계 +10,
## Trip.set_route, 바퀴가 끝나기를 기다림)로 바꾼다. 돈·단계·보조 트럭을 미리 넣는 것도 준비로만 한다.
## ① 사무실 [트럭]: 트럭마다 [시내 · 시간당 N원] [장거리 · 시간당 N원] (= hourly_income_on), 고른 쪽 눌림, 잠겼으면 꺼짐 + "장거리는 엔진 +10부터",
##    [장거리] 클릭 → set_route → "다음 바퀴부터 장거리", 바퀴가 바뀌면 안내 사라짐, [시내] → "다음 바퀴부터 시내", 잠긴 트럭은 눌러도 그대로
## ② 띠 장거리: 장거리 바퀴인 트럭이 물류센터에서 왼쪽 화면 밖으로 나감 (보이는 곳에서 빠짐), 구석 "장거리 배송 중 · N분 N초"
##    (= lap_seconds_left), 두 대면 "2대 · 가장 빨리 돌아오는 시간", 그 트럭 "+금액"은 나간 쪽 가장자리, 바퀴 끝에 물류센터로 돌아옴
## ③ 작은 화면 3가지 + 큰 화면: 구석 줄이 동네 안·보이는 곳 안, 건물·집·구석 줄과 안 겹침, 사각형 30개 이하
## ④ 튜닝숍 [세팅] 네 번째 부품(터보) 자리: 터보를 balance에 넣어(준비, C1 json 흉내) 창업 전 "터보 · 대리점 + 엔진 +10에 열려요",
##    창업 뒤 +0 트럭(ECU·터보 잠김 버튼 글)·+10 트럭(터보 열림, "장거리 노선에서만", 고르는 화면) ko·en 큰 화면 5가지에서 창 안
## ⑤ 사무실 [트럭] 트럭 3대 + 안내 줄 ko·en 큰 화면 5가지에서 창 안   ⑥ en 글자에 한글·키 없음
## 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v7b.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const RouteStub = preload("res://scripts/ui/route_stub.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const Town = preload("res://scripts/ui/town.gd")
const TEST_SAVE := "user://test_v7b.json"
const TEST_SETTINGS := "user://test_v7b_settings.cfg"
const SMALL_SIZES := [Vector2i(480, 220), Vector2i(720, 330), Vector2i(960, 440)]
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]

var fails := PackedStringArray()
var checks := 0
var now := 0   ## 고정 현지 시각 (2026-11-18 수요일 12:00)
var _hangul := RegEx.create_from_string("[가-힣ㄱ-ㅎㅏ-ㅣ]")


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	now = Time.get_unix_time_from_datetime_dict({ "year": 2026, "month": 11, "day": 18, "hour": 12, "minute": 0, "second": 0 })
	var b := Balance.load_file()

	await _office_switch(b)
	await _strip_long(b)
	await _turbo_slot(b)
	var en := []
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		var r := await _office_fit(b)
		if loc == "en":
			en = r[1]
		_report(r[0].is_empty(), "⑤ %s 사무실 [트럭] 트럭 3대 (스위치 + 잠김·다음 바퀴 안내) 큰 화면 %d가지에서 창 안, 동네·[작게]·[설정]과 안 겹침 %s" % [loc, FIT_SIZES.size(), r[0]])
	TranslationServer.set_locale("ko")
	var bad := en.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and en.size() >= 8, "⑥ en 사무실 스위치·안내·장거리 구석 줄·터보 잠김 글 %d개에 한글·키 없음 %s" % [en.size(), bad])
	print("    en: %s" % [en])

	Engine.time_scale = 1.0
	_reset_stub()
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


# ---------------- ① 사무실 [트럭] 스위치 ----------------

func _office_switch(b: Balance) -> void:
	_reset_stub()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	_agency_with_helpers(b, s, 2)
	s.truck(1).star = 12
	RouteStub.open = { 1: true }   # 준비: 2호차만 장거리 열림 (C1 뒤에는 대리점 + +10)
	await _frames(3)
	_click(m.town.building_rects()[Town.OFFICE].get_center())
	await _frames(3)
	var o = m.panel.office
	_click(o.page_buttons[o.Page.TRUCKS].get_global_rect().get_center())
	await _frames(2)
	var texts_ok: bool = o.route_buttons.size() == 3 and o.mine_line.is_visible_in_tree() \
			and o.mine_line.text == "내 트럭  +0 · 시간당 %s원" % Fmt.money(int(Trip.hourly_income(b, s, 0)))
	var shown := []
	for i in 3:
		for id in ["city", "long"]:
			var btn: Button = o.route_buttons[i][id]
			var want := "%s · 시간당 %s원" % ["시내" if id == "city" else "장거리", Fmt.money(int(RouteStub.hourly_income_on(b, s, i, id)))]
			texts_ok = texts_ok and btn.is_visible_in_tree() and btn.text == want and btn.button_pressed == (id == "city")
			shown.append(btn.text)
	var lock_text: String = o.route_notes[0].text
	var lock_ok: bool = o.route_buttons[0]["long"].disabled and o.route_buttons[2]["long"].disabled and not o.route_buttons[1]["long"].disabled \
			and lock_text == "장거리는 엔진 +%d부터" % RouteStub.long_star(b) and o.route_notes[0].is_visible_in_tree() \
			and o.route_notes[2].is_visible_in_tree() and not o.route_notes[1].visible
	_click(o.route_buttons[1]["long"].get_global_rect().get_center())
	await _frames(2)
	var next_text: String = o.route_notes[1].text
	var pick_ok: bool = RouteStub.route_choice(s, 1) == "long" and o.route_buttons[1]["long"].button_pressed and not o.route_buttons[1]["city"].button_pressed \
			and o.route_notes[1].is_visible_in_tree() and next_text == "다음 바퀴부터 장거리"
	_click(o.route_buttons[2]["long"].get_global_rect().get_center())   # 잠김
	await _frames(2)
	var locked_click_ok: bool = RouteStub.route_choice(s, 2) == "city" and o.route_buttons[2]["city"].button_pressed and not o.route_buttons[2]["long"].button_pressed
	RouteStub.lap[1] = "long"   # 준비: 다음 바퀴가 시작됨 (C1 뒤에는 바퀴가 끝나기를 기다림)
	await _frames(2)
	var applied_ok: bool = not o.route_notes[1].visible
	_click(o.route_buttons[1]["city"].get_global_rect().get_center())
	await _frames(2)
	var back_text: String = o.route_notes[1].text
	var back_ok: bool = RouteStub.route_choice(s, 1) == "city" and o.route_buttons[1]["city"].button_pressed and back_text == "다음 바퀴부터 시내" \
			and o.route_notes[1].is_visible_in_tree()
	_report(texts_ok and lock_ok and pick_ok and locked_click_ok and applied_ok and back_ok,
			"① 사무실 [트럭] 트럭 3대: '%s', 버튼 %s (시간당 = hourly_income_on, 시내 눌림) / 잠긴 트럭 [장거리] 꺼짐 + '%s', 눌러도 그대로 / [장거리] → '%s', 바퀴가 바뀌면 안내 사라짐, [시내] → '%s'" % [
			o.mine_line.text, shown, lock_text, next_text, back_text])
	await _close(m)
	_reset_stub()


# ---------------- ② 띠: 장거리 트럭이 나갔다 돌아옴 · 구석 줄 · 가장자리 "+금액" ----------------

func _strip_long(b: Balance) -> void:
	_reset_stub()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	var town = m.town
	_agency_with_helpers(b, s, 2)
	s.quest_index = Quest.count(b)   # 할 일 보상이 안 끼게
	await _frames(3)
	var area: Rect2 = town.area()
	var depot_ok: bool = town.trucks[1].distance() == 0.0 and not town.trucks[1].away()   # 아직 시내 (물류센터 앞)
	RouteStub.lap = { 1: "long" }   # 준비: 2호차가 장거리 바퀴 (C1 뒤에는 스위치 + 바퀴 끝)
	s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) * 0.5   # 준비: 바퀴 가운데 (그 앞 배송은 첫 프레임에 몰아서 나옴)
	var log_before: int = town.payout_log.size()
	Engine.time_scale = 1.0
	var out_ok := await _until(func(): return town.trucks[1].away(), 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	var t1 = town.trucks[1]
	var r1: Rect2 = t1.click_rect()
	var rects: Array = m.visible_rects()
	var gone_ok: bool = out_ok and t1.self_modulate.a == 0.0 and r1.grow(-Feel.TRUCK_CLICK_PADDING).end.x <= area.position.x \
			and not town.trucks[0].away() and not town.trucks[2].away()
	for r: Rect2 in rects:
		gone_ok = gone_ok and not r.intersects(Rect2(r1.position + town.global_position, r1.size))
	var left := ceili(RouteStub.lap_seconds_left(b, s, 1))
	var line: Label = town._long_label
	var one_text: String = line.text
	var one_ok: bool = line.is_visible_in_tree() and one_text == "장거리 배송 중 · %d분 %d초" % [left / 60, left % 60] \
			and _enclosed(rects, line.get_global_rect()) and area.encloses(Rect2(line.position, line.size))
	var edge := []
	var edge_ok := true
	for e: Array in town.payout_log.slice(log_before):
		if e[0] == 1:
			edge.append(e[2])
			edge_ok = edge_ok and e[2] == Town.EDGE
	var at_edge := false
	for p: Label in town.payouts():
		at_edge = at_edge or (is_equal_approx(p.position.x, area.position.x) and _enclosed(rects, p.get_global_rect()))
	edge_ok = edge_ok and edge.size() > 0 and at_edge
	_report(depot_ok and gone_ok and one_ok and edge_ok,
			"② 띠 2호차 장거리 바퀴: 물류센터 → 왼쪽 화면 밖 (트럭 %s, 동네 왼쪽 끝 %.0f, 흐림 %.1f, 보이는 곳에서 빠짐), 구석 '%s' (남은 %d초 = lap_seconds_left), 2호차 '+금액' %d개 집 번호 %s → 나간 쪽 가장자리" % [
			r1, area.position.x, t1.self_modulate.a, one_text, left, edge.size(), edge.slice(0, 3)])

	# 두 대: 3호차도 장거리 (남은 시간이 더 짧게) → "2대 · 가장 빨리 돌아오는 시간"
	RouteStub.lap[2] = "long"
	s.truck(2).lap_clock = Trip.lap_seconds(b, s, 2) * 0.8
	Engine.time_scale = 1.0
	var both_ok := await _until(func(): return town.trucks[2].away(), 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	var soon := ceili(minf(RouteStub.lap_seconds_left(b, s, 1), RouteStub.lap_seconds_left(b, s, 2)))
	var two_text: String = line.text
	both_ok = both_ok and two_text == "장거리 배송 중 2대 · %d분 %d초" % [soon / 60, soon % 60] and line.is_visible_in_tree()
	_report(both_ok, "② 두 대 나가 있음: '%s' (가장 빨리 돌아오는 %d초)" % [two_text, soon])

	# 바퀴 끝: 2호차 남은 시간이 거의 0 → 물류센터로 돌아옴, 다시 보이는 곳
	s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) - 0.05
	Engine.time_scale = 1.0
	var back_ok := await _until(func(): return t1.distance() >= -0.5 and t1.self_modulate.a == 1.0, 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	rects = m.visible_rects()
	var rb: Rect2 = t1.click_rect()
	back_ok = back_ok and not t1.away() and _enclosed(rects, Rect2(rb.position + town.global_position, rb.size).intersection(Rect2(Vector2.ZERO, Vector2(root.size))))
	RouteStub.lap = {}
	await _frames(2)
	var hidden_ok: bool = not line.visible
	_report(back_ok and hidden_ok, "② 바퀴 끝: 2호차가 물류센터 앞(길 위 %.1f)으로 돌아와 보이는 곳 안 / 장거리 바퀴가 없으면 구석 줄 숨김" % t1.distance())

	# ③ 작은 화면 3가지 + 큰 화면: 구석 줄 자리
	var bad := []
	RouteStub.lap = { 1: "long", 2: "long" }
	Engine.time_scale = 1.0
	await _until(func(): return town.trucks[1].away() and town.trucks[2].away(), 5.0)
	Engine.time_scale = 0.0
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		for i in 10:
			town.show_payout([Town.EDGE, i % Feel.TOWN_HOUSES][i % 2], 1875 * (i + 1), ["normal", "large", "vip"][i % 3], i % 2 == 0, i % 3)
		await _frames(1)
		rects = m.visible_rects()
		var lr := Rect2(line.position, line.size)
		if not line.is_visible_in_tree() or not town.area().encloses(lr) or not _enclosed(rects, line.get_global_rect()):
			bad.append("%s 구석 줄 %s 동네 밖이거나 보이는 곳 밖" % [size, lr])
		var others := [["구석 줄", Rect2(town._hud.position, town._hud.size).merge(Rect2(town._quest_label.position, town._quest_label.size))]]
		for id: String in town.building_rects():
			others.append([id, town.building_rects()[id]])
		for h in town._houses:
			others.append(["집", town.view_rect(town._house_rect(h))])
		for x in others:
			if lr.intersects(x[1]):
				bad.append("%s 장거리 줄 ↔ %s" % [size, x[0]])
		if rects.size() > 30:
			bad.append("%s 보이는 곳 사각형 %d개 (30개 이하)" % [size, rects.size()])
	m.screen.enter_full()
	await _frames(3)
	if not line.is_visible_in_tree() or not town.area().encloses(Rect2(line.position, line.size)):
		bad.append("큰 화면 구석 줄 %s 동네 %s 밖" % [Rect2(line.position, line.size), town.area()])
	_report(bad.is_empty(), "③ 작은 화면 %d가지 + 큰 화면: 장거리 구석 줄이 동네 안·보이는 곳 안, 건물·집·구석 줄과 안 겹침, 트럭 3대(2대 나감) + 글자 10개에도 사각형 30개 이하 %s" % [
			SMALL_SIZES.size(), bad])
	await _close(m)
	_reset_stub()


# ---------------- ④ 튜닝숍 [세팅] 네 번째 부품 (터보) ----------------

func _turbo_slot(b: Balance) -> void:
	var fit := {}
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		Save.delete_file(TEST_SAVE)
		var m := await _launch(b)
		var bb: Balance = m.balance
		var s: GameState = m.state
		var p = m.panel
		var st = p.setting
		_add_turbo(bb)   # 준비: C1 json의 터보·장거리 속도를 흉내 (배치만 봄. 숫자는 지시서 값)
		var bad := []
		# 창업 전: 터보·타이어 잠김 글 두 줄, ECU 잠김 버튼 글 (+0)
		_click(m.town.building_rects()["tuning"].get_center())
		await _frames(3)
		_click(p.setting_tab_button.get_global_rect().get_center())
		await _frames(2)
		var note: String = st._lock_note.text
		var turbo: Button = st.part_buttons.get("turbo")
		var solo_ok: bool = turbo != null and turbo.disabled and turbo.is_visible_in_tree() and st.part_buttons.size() == 4
		if loc == "ko":
			solo_ok = solo_ok and turbo.text == "터보" and note == "타이어·휠 · 대리점을 차리면 열려요\n터보 · 대리점 + 엔진 +10에 열려요"
			_report(solo_ok, "④ 터보 (balance에 넣어 봄): 창업 전 부품 버튼 4개, [터보] 꺼짐 + '%s'" % note.replace("\n", " / "))
		else:
			en_texts.append_array(note.split("\n"))
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "창업 전 +0 [세팅]", size, st._lock_note.is_visible_in_tree() and turbo.is_visible_in_tree())
		# 창업 뒤: 3호차 +0 (ECU·터보 잠김 버튼 글이 가장 김) / 내 트럭 +10 (터보 열림 + 장거리 속도 설명 + 고르는 화면)
		_agency_with_helpers(bb, s, 2)
		s.money = 0
		s.truck(0).star = 10
		var tp: Dictionary = s.truck(0).part("turbo")
		tp["grade"] = 3
		tp["lines"] = ["long_speed", "long_speed", "junk_cupholder"]
		await _frames(2)
		m._want_day_picker = false   # +10 = 명장이 열림 → 요일 고르기 창 (여기서는 안 봄)
		m.day_picker.visible = false
		_click(p.setting_tab_button.get_global_rect().get_center())
		await _frames(2)
		_click(p.truck_buttons[2].get_global_rect().get_center())
		await _frames(2)
		var helper_text: String = turbo.text
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "3호차 +0 [세팅] (ECU·터보 잠김 버튼)", size, turbo.is_visible_in_tree() and turbo.disabled and st.part_buttons["ecu"].disabled)
		_click(p.truck_buttons[0].get_global_rect().get_center())
		await _frames(2)
		_click(turbo.get_global_rect().get_center())
		await _frames(2)
		var effect: String = st._effect.text
		var open_ok: bool = not turbo.disabled and st.selected == "turbo" and st._effect.is_visible_in_tree()
		if loc == "ko":
			open_ok = open_ok and helper_text == "터보 · 엔진 +10에 열림" and effect.contains("장거리 속도: 장거리 노선에서만 빨라져요") \
					and st._grade.text.begins_with("터보 · ")
			_report(open_ok, "④ 창업 뒤: 3호차 +0 버튼 '%s' / 내 트럭 +10 [터보] 켜짐 → '%s', 설명 '%s'" % [helper_text, st._grade.text, effect])
		else:
			en_texts.append_array([helper_text, effect])
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "내 트럭 +10 [세팅] 터보", size, st.selected == "turbo" and st._effect.is_visible_in_tree())
		tp["pending"] = { "grade": 4, "lines": ["long_speed", "junk_cupholder", "long_speed"] }
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "터보 고르는 화면", size, st._choose.is_visible_in_tree())
		fit[loc] = bad
		await _close(m)
	TranslationServer.set_locale("ko")
	_report(fit["ko"].is_empty() and fit["en"].is_empty(),
			"④ ko·en 부품 4개 [세팅] (창업 전 잠김 두 줄, 3호차 +0 잠김 버튼 글, 터보 설명, 터보 고르는 화면) 큰 화면 %d가지에서 창 안, 동네·[작게]·[설정]과 안 겹침 %s %s" % [
			FIT_SIZES.size(), fit["ko"], fit["en"]])


var en_texts := []   ## ④에서 모은 en 글자 (⑥)


## 준비: 지시서 "옮길 숫자"의 터보·장거리 속도를 balance에 (C1 json이 오기 전, 배치 확인용)
func _add_turbo(bb: Balance) -> void:
	bb.setting_options["long_speed"] = { "kind": "own", "weight": 10.0, "values": PackedFloat64Array([0.05, 0.08, 0.12, 0.2, 0.3]) }
	bb.setting_parts["turbo"] = { "unlock_star": 10, "unlock_stage": 1, "options": PackedStringArray(
			["speed", "fuel_cut", "long_speed", "junk_ride", "junk_scent", "junk_cupholder", "junk_radio", "junk_gloss"]) }


# ---------------- ⑤ 사무실 [트럭] 창 크기 ----------------

## [문제 목록, en이면 보이는 글자들]
func _office_fit(b: Balance) -> Array:
	_reset_stub()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	_agency_with_helpers(b, s, 2)
	s.money = 0
	RouteStub.open = { 1: true }
	RouteStub.choice = { 1: "long" }   # 준비: 2호차 "다음 바퀴부터", 나머지 잠김 안내 (안내 줄이 다 보일 때)
	await _frames(2)
	_click(m.town.building_rects()[Town.OFFICE].get_center())
	await _frames(3)
	var o = m.panel.office
	var bad := []
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(o.page_buttons[o.Page.TRUCKS].get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "사무실 [트럭]", size, o.route_notes.size() == 3 and o.route_notes[0].is_visible_in_tree() and o.route_notes[1].is_visible_in_tree() \
				and o.route_notes[2].is_visible_in_tree() and o._buy_note.is_visible_in_tree())
	var texts := [o.mine_line.text]
	for i in 3:
		texts.append_array([o.route_buttons[i]["city"].text, o.route_buttons[i]["long"].text, o.route_notes[i].text])
	# en 구석 줄 (2호차 장거리로 나감)
	RouteStub.lap = { 1: "long" }
	m.screen.enter_small()
	s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) * 0.5
	Engine.time_scale = 1.0
	await _until(func(): return m.town.trucks[1].away(), 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	texts.append(m.town._long_label.text)
	texts.append_array(en_texts)
	await _close(m)
	_reset_stub()
	return [bad, texts]


# ---------------- 도우미 ----------------

func _reset_stub() -> void:
	RouteStub.choice = {}
	RouteStub.lap = {}
	RouteStub.open = {}


## 큰 화면 한 칸이 창 안이고 동네·[작게]·[설정]과 안 겹치나. shown = 그 칸에서 꼭 보여야 하는 것들이 보이나
func _fit(m: Node, bad: Array, what: String, size: Vector2i, shown: bool) -> void:
	var pr: Rect2 = m.panel.get_global_rect()
	if not shown or not Rect2(Vector2.ZERO, Vector2(size)).encloses(pr) or pr.intersects(m.town.area()) \
			or pr.intersects(m.small_button.get_global_rect()) or pr.intersects(m.settings_button.get_global_rect()):
		bad.append("%s %dx%d %s%s" % [what, size.x, size.y, pr, "" if shown else " (보여야 할 줄이 안 보임)"])


## 준비: 창업 + 보조 트럭 n대 (돈은 계산 쪽 함수로 내고 그대로 둠)
func _agency_with_helpers(b: Balance, s: GameState, n: int) -> void:
	if Company.stage(s) == 0:
		s.money += Company.agency_price(b)
		Company.found(b, s)
	while Company.helper_count(s) < n:
		s.money += Company.helper_price(b, s)
		Company.buy_helper(b, s)


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["ROUTE_", "OFFICE_", "TOWN_", "SETTING_", "TRUCK_"]:
		if x.contains(prefix):
			return true
	return _hangul.search(x) != null


func _enclosed(rects: Array, r: Rect2) -> bool:
	for v: Rect2 in rects:
		if v.encloses(r):
			return true
	return false


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤, 급송 벨 끔)
func _launch(b: Balance) -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	m.now_local_override = now
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	m.state.rush_enabled = false   # 벨이 난수·아이콘을 끼우지 않게
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


## cond가 참이 될 때까지 프레임을 돌림 (진짜 시간 seconds까지). 됐으면 true
func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await process_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _report(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails.append(text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])
