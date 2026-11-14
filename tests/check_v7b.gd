## v7b U1 완료 기준 자동 확인. 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 본다.
## 돈·단계·보조 트럭·기사 레벨을 미리 넣는 것과 바퀴를 끝내는 것(_roll: 계산 쪽 Trip.advance)은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 모든 트럭을 Trip.advance)으로 한다.
## ① 사무실 [트럭]: 트럭마다 [시내 · 시간당 N원] [장거리 · 시간당 N원] (= Trip.hourly_income_on), 고른 쪽 눌림,
##    잠겼으면(Trip.can_long) 꺼짐 + "장거리는 엔진 +10부터", [장거리] 클릭 → Trip.set_route·저장 → "다음 바퀴부터 장거리",
##    바퀴가 바뀌면(Trip.route_id = long) 안내 사라짐, [시내] → "다음 바퀴부터 시내", 잠긴 트럭은 눌러도 그대로
## ② 띠 장거리: 장거리 바퀴인 트럭이 물류센터에서 왼쪽 화면 밖으로 나감 (보이는 곳에서 빠짐), 구석 "장거리 배송 중 · N분 N초"
##    (= Trip.lap_seconds_left), 두 대면 "2대 · 가장 빨리 돌아오는 시간", 그 트럭 "+금액"은 나간 쪽 가장자리, 바퀴 끝에 물류센터로 돌아옴
##    + 장거리 "+금액"·팁 합 = 늘어난 돈, 경험치 = routes.long.xp_per_parcel × 배송 (물류센터 경험치 줄), 알림 "장거리 노선이 열렸어요" 한 번
## ③ 작은 화면 3가지 + 큰 화면: 구석 줄이 동네 안·보이는 곳 안, 건물·집·구석 줄과 안 겹침, 사각형 30개 이하
## ④ 튜닝숍 [세팅] 터보: 창업 전·창업 뒤 +10 전 모두 "터보 · 대리점 + 엔진 +10에 열려요", +10 트럭은 켜짐 + "장거리 노선에서만",
##    ko·en 큰 화면 5가지에서 (창업 전, 3호차 +0, 터보, 터보 고르는 화면) 창 안
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
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const Town = preload("res://scripts/ui/town.gd")
const TEST_SAVE := "user://test_v7b.json"
const TEST_SETTINGS := "user://test_v7b_settings.cfg"
const SMALL_SIZES := [Vector2i(480, 220), Vector2i(720, 330), Vector2i(960, 440)]
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]
const LONG_NOTICE := "장거리 노선이 열렸어요"
const TURBO_LOCK := "터보 · 대리점 + 엔진 +10에 열려요"

var fails := PackedStringArray()
var checks := 0
var now := 0   ## 고정 현지 시각 (2026-11-18 수요일 12:00)
var en_texts := []   ## en 화면에서 모은 글자 (⑥)
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
	await _long_money_xp(b)
	await _turbo_slot(b)
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		var bad := await _office_fit(b, loc == "en")
		_report(bad.is_empty(), "⑤ %s 사무실 [트럭] 트럭 3대 (스위치 + 잠김·다음 바퀴 안내) 큰 화면 %d가지에서 창 안, 동네·[작게]·[설정]과 안 겹침 %s" % [loc, FIT_SIZES.size(), bad])
	TranslationServer.set_locale("ko")
	var bad := en_texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and en_texts.size() >= 15 and en_texts.has("The long-haul route is open"),
			"⑥ en 사무실 스위치·안내·장거리 구석 줄·알림·터보 잠김 글·장거리 속도 줄 %d개에 한글·키 없음 %s" % [en_texts.size(), bad])
	print("    en: %s" % [en_texts])

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


# ---------------- ① 사무실 [트럭] 스위치 ----------------

func _office_switch(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	_agency_with_helpers(b, s, 2)
	s.truck(1).star = 12   # 준비: 2호차만 장거리 열림 (대리점 + +10)
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
			var want := "%s · 시간당 %s원" % ["시내" if id == "city" else "장거리", Fmt.money(int(Trip.hourly_income_on(b, s, i, id)))]
			texts_ok = texts_ok and btn.is_visible_in_tree() and btn.text == want and btn.button_pressed == (id == "city")
			shown.append(btn.text)
	var lock_text: String = o.route_notes[0].text
	var lock_ok: bool = not Trip.can_long(b, s, 0) and not Trip.can_long(b, s, 2) and Trip.can_long(b, s, 1) \
			and o.route_buttons[0]["long"].disabled and o.route_buttons[2]["long"].disabled and not o.route_buttons[1]["long"].disabled \
			and lock_text == "장거리는 엔진 +%d부터" % b.routes["long"]["unlock_star"] and o.route_notes[0].is_visible_in_tree() \
			and o.route_notes[2].is_visible_in_tree() and not o.route_notes[1].visible
	_click(o.route_buttons[1]["long"].get_global_rect().get_center())
	await _frames(2)
	var next_text: String = o.route_notes[1].text
	var saved = _saved_state(b)
	var pick_ok: bool = Trip.route_choice(s, 1) == "long" and Trip.route_id(s, 1) == "city" and o.route_buttons[1]["long"].button_pressed \
			and not o.route_buttons[1]["city"].button_pressed and o.route_notes[1].is_visible_in_tree() and next_text == "다음 바퀴부터 장거리" \
			and saved != null and Trip.route_choice(saved, 1) == "long"
	_click(o.route_buttons[2]["long"].get_global_rect().get_center())   # 잠김
	await _frames(2)
	var locked_click_ok: bool = Trip.route_choice(s, 2) == "city" and o.route_buttons[2]["city"].button_pressed and not o.route_buttons[2]["long"].button_pressed
	_roll(m, b, 1)   # 준비: 이번 바퀴를 끝냄 → 다음 바퀴가 장거리로 출발
	await _frames(2)
	var applied_ok: bool = Trip.route_id(s, 1) == "long" and not o.route_notes[1].visible
	_click(o.route_buttons[1]["city"].get_global_rect().get_center())
	await _frames(2)
	var back_text: String = o.route_notes[1].text
	var back_ok: bool = Trip.route_choice(s, 1) == "city" and Trip.route_id(s, 1) == "long" and o.route_buttons[1]["city"].button_pressed \
			and back_text == "다음 바퀴부터 시내" and o.route_notes[1].is_visible_in_tree()
	_report(texts_ok and lock_ok and pick_ok and locked_click_ok and applied_ok and back_ok,
			"① 사무실 [트럭] 트럭 3대: '%s', 버튼 %s (= Trip.hourly_income_on, 시내 눌림) / 잠긴 트럭 [장거리] 꺼짐 + '%s', 눌러도 그대로 / [장거리] → set_route·저장, '%s', 다음 바퀴가 장거리면 안내 사라짐, [시내] → '%s'" % [
			o.mine_line.text, shown, lock_text, next_text, back_text])
	await _close(m)


# ---------------- ② 띠: 장거리 트럭이 나갔다 돌아옴 · 구석 줄 · 가장자리 "+금액" ----------------

func _strip_long(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	var town = m.town
	_agency_with_helpers(b, s, 2)
	s.quest_index = Quest.count(b)   # 할 일 보상이 안 끼게
	s.truck(1).star = 12
	s.truck(2).star = 12
	await _frames(3)
	var area: Rect2 = town.area()
	var depot_ok: bool = town.trucks[1].distance() == 0.0 and not town.trucks[1].away()   # 아직 시내 (물류센터 앞)
	Trip.set_route(b, s, 1, "long")   # 준비: 스위치 (클릭은 ①)
	_roll(m, b, 1)
	s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) * 0.5   # 준비: 장거리 바퀴 가운데 (그 앞 배송은 첫 프레임에 몰아서 나옴)
	var log_before: int = town.payout_log.size()
	Engine.time_scale = 1.0
	var out_ok := await _until(func(): return town.trucks[1].away(), 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	var t1 = town.trucks[1]
	var r1: Rect2 = t1.click_rect()
	var rects: Array = m.visible_rects()
	var gone_ok: bool = out_ok and Trip.route_id(s, 1) == "long" and t1.self_modulate.a == 0.0 \
			and r1.grow(-Feel.TRUCK_CLICK_PADDING).end.x <= area.position.x and not town.trucks[0].away() and not town.trucks[2].away()
	for r: Rect2 in rects:
		gone_ok = gone_ok and not r.intersects(Rect2(r1.position + town.global_position, r1.size))
	var left := ceili(Trip.lap_seconds_left(b, s, 1))
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
			"② 띠 2호차 장거리 바퀴: 물류센터 → 왼쪽 화면 밖 (트럭 %s, 동네 왼쪽 끝 %.0f, 흐림 %.1f, 보이는 곳에서 빠짐), 구석 '%s' (남은 %d초 = Trip.lap_seconds_left), 2호차 '+금액' %d개 집 번호 %s → 나간 쪽 가장자리" % [
			r1, area.position.x, t1.self_modulate.a, one_text, left, edge.size(), edge.slice(0, 3)])

	# 두 대: 3호차도 장거리 (남은 시간이 더 짧게) → "2대 · 가장 빨리 돌아오는 시간"
	Trip.set_route(b, s, 2, "long")
	_roll(m, b, 2)
	s.truck(2).lap_clock = Trip.lap_seconds(b, s, 2) * 0.8
	Engine.time_scale = 1.0
	var both_ok := await _until(func(): return town.trucks[2].away(), 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	var soon := ceili(minf(Trip.lap_seconds_left(b, s, 1), Trip.lap_seconds_left(b, s, 2)))
	var two_text: String = line.text
	both_ok = both_ok and two_text == "장거리 배송 중 2대 · %d분 %d초" % [soon / 60, soon % 60] and line.is_visible_in_tree()
	_report(both_ok, "② 두 대 나가 있음: '%s' (가장 빨리 돌아오는 %d초)" % [two_text, soon])

	# 바퀴 끝: 2호차 남은 시간이 거의 0 → 물류센터로 돌아옴 (다음 장거리 바퀴는 싣는 동안 물류센터 앞), 다시 보이는 곳
	s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) - 0.05
	Engine.time_scale = 1.0
	var back_ok := await _until(func(): return t1.distance() >= -0.5 and t1.self_modulate.a == 1.0, 5.0)
	Engine.time_scale = 0.0
	await _frames(2)
	rects = m.visible_rects()
	var rb: Rect2 = t1.click_rect()
	back_ok = back_ok and not t1.away() and _enclosed(rects, Rect2(rb.position + town.global_position, rb.size).intersection(Rect2(Vector2.ZERO, Vector2(root.size))))
	for i in [1, 2]:   # 준비: 둘 다 시내로 → 바퀴가 끝나면 장거리 바퀴 없음
		Trip.set_route(b, s, i, "city")
		_roll(m, b, i)
	await _frames(2)
	var hidden_ok: bool = Trip.route_id(s, 1) == "city" and Trip.route_id(s, 2) == "city" and not line.visible
	_report(back_ok and hidden_ok, "② 바퀴 끝: 2호차가 물류센터 앞(길 위 %.1f)으로 돌아와 보이는 곳 안 / 장거리 바퀴가 없으면 구석 줄 숨김" % t1.distance())

	# ③ 작은 화면 3가지 + 큰 화면: 구석 줄 자리 (2대 나감)
	var bad := []
	for i in [1, 2]:
		Trip.set_route(b, s, i, "long")
		_roll(m, b, i)
		s.truck(i).lap_clock = Trip.lap_seconds(b, s, i) * 0.5
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


## ② 장거리 "+금액"·경험치·알림: 내 트럭 한 대 (만렙이라 경험치 = 회사 평판으로, 물류센터 줄에 그대로 보임)
func _long_money_xp(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	var town = m.town
	_agency_with_helpers(b, s, 0)
	s.quest_index = Quest.count(b)
	s.driver_level = Driver.max_level(b)   # 준비: 경험치가 레벨업 없이 평판으로 그대로 쌓임
	s.driver_xp = 0
	s.reputation = 0
	s.truck(0).star = 10   # 준비: 장거리 열림 → 다음 프레임에 계산 쪽 알림
	await _frames(3)
	m._want_day_picker = false   # +10 = 명장이 열림 → 요일 고르기 창 (여기서는 안 봄)
	var noticed_once: bool = _count_notice(town, LONG_NOTICE) == 1 and s.long_unlocked
	Trip.set_route(b, s, 0, "long")
	_roll(m, b, 0)
	s.truck(0).lap_clock = Trip.lap_seconds(b, s, 0) * 0.5
	await _frames(1)
	var money0: int = s.money
	var rep0: int = s.reputation
	var tips0: int = m.tips_total
	var log0: int = town.payout_log.size()
	Engine.time_scale = 1.0
	await _frames(2)
	Engine.time_scale = 0.0
	await _frames(2)
	var entries: Array = town.payout_log.slice(log0)
	var shown: int = m.tips_total - tips0
	var edge_ok := entries.size() > 0
	for e: Array in entries:
		shown += e[1]
		edge_ok = edge_ok and e[0] == 0 and e[2] == Town.EDGE
	var xp_each: int = b.routes["long"]["xp_per_parcel"]
	var money_ok: bool = s.money - money0 == shown
	var xp_ok: bool = s.reputation - rep0 == xp_each * entries.size()
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	var xp_text: String = d._xp.text
	xp_ok = xp_ok and d._xp.is_visible_in_tree() and xp_text == "만렙이라 경험치는 회사 평판으로: %d" % s.reputation
	for i in 30:   # 알림은 한 번만 (프레임이 더 돌아도)
		await process_frame
	noticed_once = noticed_once and _count_notice(town, LONG_NOTICE) == 1
	_report(noticed_once and edge_ok and money_ok and xp_ok,
			"② 장거리 내 트럭: 알림 '%s' 한 번 / 배송 %d건 '+금액'이 가장자리에, '+금액'·팁 합 %s원 = 늘어난 돈 %s원 / 경험치 %d × %d건 = 평판 +%d, 물류센터 '%s'" % [
			LONG_NOTICE, entries.size(), Fmt.money(shown), Fmt.money(s.money - money0), xp_each, entries.size(), s.reputation - rep0, xp_text])
	await _close(m)


# ---------------- ④ 튜닝숍 [세팅] 터보 ----------------

func _turbo_slot(b: Balance) -> void:
	var fit := {}
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		Save.delete_file(TEST_SAVE)
		var m := await _launch(b)
		var s: GameState = m.state
		var p = m.panel
		var st = p.setting
		var bad := []
		# 창업 전: 타이어·터보 잠김 줄 두 개, ECU 잠김 버튼 글 (+0)
		_click(m.town.building_rects()["tuning"].get_center())
		await _frames(3)
		_click(p.setting_tab_button.get_global_rect().get_center())
		await _frames(2)
		var note: String = st._lock_note.text
		var turbo: Button = st.part_buttons.get("turbo")
		var solo_ok: bool = turbo != null and turbo.disabled and turbo.is_visible_in_tree() and st.part_buttons.size() == 4
		if loc == "ko":
			solo_ok = solo_ok and turbo.text == "터보" and note == "타이어·휠 · 대리점을 차리면 열려요\n" + TURBO_LOCK
		else:
			en_texts.append_array(note.split("\n"))
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "창업 전 +0 [세팅]", size, st._lock_note.is_visible_in_tree() and turbo.is_visible_in_tree())
		# 창업 뒤: 3호차 +0 (ECU 잠김 버튼 글 + 터보 줄) / 내 트럭 +10 (터보 열림 + 장거리 속도 설명 + 고르는 화면)
		_agency_with_helpers(b, s, 2)
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
		var helper_note: String = st._lock_note.text
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_fit(m, bad, "3호차 +0 [세팅] (ECU 잠김 버튼 + 터보 줄)", size, turbo.is_visible_in_tree() and turbo.disabled and st.part_buttons["ecu"].disabled \
					and st._lock_note.is_visible_in_tree())
		_click(p.truck_buttons[0].get_global_rect().get_center())
		await _frames(2)
		_click(turbo.get_global_rect().get_center())
		await _frames(2)
		var effect: String = st._effect.text
		var lines := []
		for l: Label in st._lines.get_children():
			if l.visible:
				lines.append(l.text)
		var open_ok: bool = not turbo.disabled and st.selected == "turbo" and st._effect.is_visible_in_tree() and not st._lock_note.visible
		if loc == "ko":
			open_ok = open_ok and helper_text == "터보" and helper_note == TURBO_LOCK and effect.contains("장거리 속도: 장거리 노선에서만 빨라져요") \
					and st._grade.text.begins_with("터보 · ") and lines[0].begins_with("장거리 속도 +")
			_report(solo_ok and open_ok, "④ 터보: 창업 전 부품 4개, [터보] 꺼짐 + '%s' / 창업 뒤 3호차 +0 버튼 '%s' + '%s' / 내 트럭 +10 [터보] 켜짐 → '%s', 줄 %s, 설명 '%s'" % [
					note.replace("\n", " / "), helper_text, helper_note, st._grade.text, lines, effect.replace("\n", " / ")])
		else:
			en_texts.append_array([helper_note, effect] + lines)
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
			"④ ko·en 부품 4개 [세팅] (창업 전 잠김 두 줄, 3호차 +0 잠김, 터보 설명, 터보 고르는 화면) 큰 화면 %d가지에서 창 안, 동네·[작게]·[설정]과 안 겹침 %s %s" % [
			FIT_SIZES.size(), fit["ko"], fit["en"]])


# ---------------- ⑤ 사무실 [트럭] 창 크기 ----------------

## 문제 목록. en이면 보이는 글자를 en_texts에 모음
func _office_fit(b: Balance, en: bool) -> Array:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	_agency_with_helpers(b, s, 2)
	s.money = 0
	s.truck(1).star = 12
	Trip.set_route(b, s, 1, "long")   # 준비: 2호차 "다음 바퀴부터", 나머지 잠김 안내 (안내 줄이 다 보일 때)
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
	if en:
		en_texts.append(o.mine_line.text)
		for i in 3:
			en_texts.append_array([o.route_buttons[i]["city"].text, o.route_buttons[i]["long"].text, o.route_notes[i].text])
		# 구석 줄 (2호차 장거리로 나감), 알림
		_roll(m, b, 1)
		s.truck(1).lap_clock = Trip.lap_seconds(b, s, 1) * 0.5
		m.screen.enter_small()
		Engine.time_scale = 1.0
		await _until(func(): return m.town.trucks[1].away(), 5.0)
		Engine.time_scale = 0.0
		await _frames(2)
		en_texts.append(m.town._long_label.text)
		en_texts.append_array(m.town.notices_shown + m.town._notice_queue)   # 알림은 하나씩 차례로 뜸
	await _close(m)
	return bad


# ---------------- 도우미 ----------------

## 준비: 트럭 i의 이번 바퀴를 끝내고 스위치 노선으로 다음 바퀴 출발 (계산 쪽 진행만. 돈·배송은 그대로 들어감)
func _roll(m: Node, b: Balance, i: int) -> void:
	var s: GameState = m.state
	s.truck(i).lap_clock = Trip.lap_seconds(b, s, i)
	Trip.advance(s, b, i, 0.001, m.rng)


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


## 동네 알림에 text가 뜬 수 + 차례를 기다리는 수
func _count_notice(town: Node, text: String) -> int:
	return town.notices_shown.count(text) + town._notice_queue.count(text)


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["ROUTE_", "OFFICE_", "TOWN_", "SETTING_", "TRUCK_", "NOTICE_"]:
		if x.contains(prefix):
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
