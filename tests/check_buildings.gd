## v6a U1 완료 기준 자동 확인: 띠의 건물 클릭 + 큰 화면 건물 화면 (튜닝숍·물류센터·카센터).
## 진짜 게임 화면(main.tscn)에 진짜 클릭·마우스 이동·오른쪽 클릭·키를 넣어서 확인한다.
## ① 작은 화면에 건물 세 개 + 작은 버튼, visible_rects() 안, 서로·집·돈 표시와 안 겹침 (창 크기 여러 가지)
## ② 마우스를 올리면 빛남 + 이름표, 벗어나면 꺼짐   ③ 건물을 누르면 큰 화면 그 건물 화면   ④ 작은 버튼 → 튜닝숍
## ⑤ 도로·트럭·집·돈 표시·알림을 눌러도 작은 화면 그대로   ⑥ 큰 화면 위쪽 줄로 세 건물을 오감
## ⑦ 튜닝숍 강화·세팅 두 칸 / 물류센터 레벨·다음 할 일·창고·야간팀 / 카센터 스페어 개수·가격·[사기]
## ⑧ 카센터에서 사면 돈 −Economy.spare_price·개수 +1·직후 저장, 모자라면 버튼 꺼짐 + 모자란 금액
## ⑨ +18 스페어 0개면 강화 칸에 이유 글 + [카센터로] → 카센터   ⑩ 고르다 만 세팅이 있으면 켤 때 튜닝숍 세팅 칸
## ⑪ [작게]·Esc 뒤 다시 건물을 누르면 그 건물 화면 (알림 영역 아이콘은 마지막에 보던 건물, 처음엔 튜닝숍)
## ⑫ en에서도 건물 이름·NPC 인사말에 한글·키 없음 (ko는 "차고"라는 말이 안 보임)   ⑬ 오른쪽 클릭 메뉴는 건물·도로 어디서든
## v6-bal U1 ④ 처음 말풍선: 새 설정이면 작은 화면에 뜸(visible_rects() 안) → 도로 클릭엔 그대로 → 건물 클릭 뒤 사라짐
##   → 다시 켜도 안 뜸 (settings.cfg). 작은 버튼으로도 사라짐. en 글자에 한글 없음
## 확인하는 동안 게임 시간을 멈춘다 (트럭이 건물 앞을 지나가지 않게). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_buildings.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const Main = preload("res://scripts/ui/main.gd")
const TEST_SAVE := "user://test_town_buildings.json"
const TEST_SETTINGS := "user://test_buildings_settings.cfg"
const RICH := 1000000000
const NAMES_KO := { "tuning": "튜닝숍", "depot": "물류센터", "car_center": "카센터" }
const SMALL_SIZES := [Vector2i(480, 220), Vector2i(720, 330), Vector2i(960, 440)]
const FULL_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440)]

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))   # 처음 켠 것처럼 (말풍선이 뜸)
	Save.delete_file(TEST_SAVE)
	var b := Balance.load_file()

	var m := await _launch()
	var town = m.town
	var p = m.panel

	# ① 건물 세 개 + 작은 버튼: 동네 안, 보이는 곳 안(작은 화면), 서로·집·돈 표시와 안 겹침, 간판은 건물 안
	await _check_layout(m, "ko")

	# ② 마우스 올림 → 빛남 + 이름표, 벗어나면 꺼짐, 창 밖으로 나가면 꺼짐
	var hover_ok := true
	var tags := []
	for id: String in Town.BUILDINGS:
		_move(town.building_rects()[id].get_center())
		await _frames(1)
		var tag: Label = town._name_tag
		var tag_rect := Rect2(tag.position + town.global_position, tag.size)
		hover_ok = hover_ok and town.hovered == id and tag.visible and tag.text == NAMES_KO[id] and _enclosed(m.visible_rects(), tag_rect)
		tags.append(tag.text)
		_move(_empty_spot(m))
		await _frames(1)
		hover_ok = hover_ok and town.hovered == "" and not tag.visible
	_move(town.building_rects()["depot"].get_center())
	await _frames(1)
	m.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	await _frames(1)
	hover_ok = hover_ok and town.hovered == "" and not town._name_tag.visible
	_report(hover_ok and not m.is_full(), "② 건물에 마우스를 올리면 빛남 + 이름표 %s (보이는 곳 안), 벗어나거나 창 밖으로 나가면 꺼짐" % [tags])

	# ⑤ 도로·트럭·집·돈 표시·알림·할 일 줄을 눌러도 작은 화면 그대로
	# 트럭은 처음에 물류센터 앞에 서 있음 → 시간을 잠깐 돌려 건물에서 먼 길로 보낸 뒤 멈춤
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	await _until(func(): return town.truck.distance() > Feel.TOWN_ROAD[1].x - Feel.TOWN_ROAD[0].x, 10.0)
	Engine.time_scale = 0.0
	m.state.quest_index = Quest.count(b)   # 아래 돈 비교에 할 일 보상이 섞이지 않게
	town.notify("TEST")
	await _frames(2)
	var spots := {
		"도로": town.to_view(town.route.point_at(town.route.total() * 0.5)),
		"트럭": town.truck.click_rect().get_center(),
		"집": town.view_rect(town._house_rect(town._houses[0])).get_center(),
		"돈 표시": Rect2(town._money_label.global_position, town._money_label.size).get_center(),
		"알림": Rect2(town._notice.global_position, town._notice.size).get_center(),
		"할 일 줄": Rect2(town._quest_label.global_position, town._quest_label.size).get_center(),
	}
	var stayed := []
	var moved := []
	for what: String in spots:
		var at: Vector2 = spots[what] + town.global_position if what in ["도로", "트럭", "집"] else spots[what]
		if town.building_at(at - town.global_position) != "":
			moved.append("%s 자리가 건물 위" % what)
			continue
		_click(at)
		await _frames(2)
		if m.is_full():
			moved.append(what)
			m.screen.enter_small()
			await _frames(2)
		else:
			stayed.append(what)
	_report(moved.is_empty() and not m.is_full(), "⑤ 눌러도 작은 화면 그대로: %s %s" % [stayed, moved])

	# ③ 건물마다 누르면 큰 화면이 그 건물 화면으로
	var opened := []
	var open_ok := true
	for id: String in Town.BUILDINGS:
		_click(town.building_rects()[id].get_center())
		await _frames(3)
		open_ok = open_ok and m.is_full() and p.building == id and _shown(p) == id
		opened.append("%s → %s" % [NAMES_KO[id], p._npc_name.text])
		_key(KEY_ESCAPE)
		await _frames(2)
	_report(open_ok, "③ 건물을 누르면 큰 화면 그 건물 화면 %s" % [opened])

	# ④ 작은 버튼 → 튜닝숍 (마지막에 본 건물이 카센터여도)
	_click(town.tuning_button.get_global_rect().get_center())
	await _frames(3)
	_report(m.is_full() and p.building == "tuning" and _shown(p) == "tuning" and town.tuning_button.text == "강화",
			"④ 작은 버튼 [%s] → 튜닝숍 화면 (NPC '%s')" % [town.tuning_button.text, p._npc_name.text])

	# ⑥ 큰 화면 위쪽 줄로 세 건물을 오감, 고른 건물만 눌린 상태
	var row_ok := true
	var row := []
	for id: String in ["depot", "car_center", "tuning", "car_center"]:
		_click(p.building_buttons[id].get_global_rect().get_center())
		await _frames(2)
		row_ok = row_ok and p.building == id and _shown(p) == id
		for other: String in p.building_buttons:
			row_ok = row_ok and p.building_buttons[other].button_pressed == (other == id)
		row.append(p.building_buttons[id].text)
	_report(row_ok and m.is_full(), "⑥ 큰 화면 위쪽 줄 %s 로 오감, 고른 건물만 눌림" % [row])

	# ⑦ 건물마다 내용
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	var tuning_ok: bool = p.engine_tab_button.is_visible_in_tree() and p.setting_tab_button.is_visible_in_tree() \
			and p._enhance_button.is_visible_in_tree() and not p.setting.is_visible_in_tree()
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(2)
	tuning_ok = tuning_ok and p.setting.is_visible_in_tree() and p.setting.roll_button.is_visible_in_tree() and not p._enhance_button.is_visible_in_tree()
	_click(p.engine_tab_button.get_global_rect().get_center())
	_click(p.building_buttons["depot"].get_global_rect().get_center())
	await _frames(2)
	var d = p.driver
	_click(d.depot_page_button.get_global_rect().get_center())   # v5b: 할 일·창고·야간팀은 [창고·할 일] 칸
	await _frames(2)
	var depot_ok: bool = d._level.is_visible_in_tree() and d._quest_name.is_visible_in_tree() \
			and d._titles["warehouse"].is_visible_in_tree() and d._titles["night"].is_visible_in_tree()
	m.state.spares = 2
	_click(p.building_buttons["car_center"].get_global_rect().get_center())
	await _frames(2)
	var price := Economy.spare_price(b)
	var car_ok: bool = p._car_spares.is_visible_in_tree() and p._car_spares.text == "스페어 엔진 2개" \
			and p._spare_button.is_visible_in_tree() and p._spare_button.text == "스페어 엔진 사기 (%s원)" % Fmt.money(price) \
			and p._car_note.text.begins_with("+")
	_report(tuning_ok and depot_ok and car_ok,
			"⑦ 튜닝숍 [%s] [%s], 물류센터 '%s' · '%s' · '%s' · '%s', 카센터 '%s' [%s] '%s'" % [
			p.engine_tab_button.text, p.setting_tab_button.text, d._level.text, d._quest_name.text, d._titles["warehouse"].text,
			d._titles["night"].text, p._car_spares.text, p._spare_button.text, p._car_note.text])

	# ⑧ 카센터에서 사기: 돈 −spare_price, 개수 +1, 직후 저장 / 모자라면 꺼짐 + 모자란 금액
	m.state.money = price + 777
	await _frames(2)
	_click(p._spare_button.get_global_rect().get_center())
	var bought_ok: bool = m.state.money == 777 and m.state.spares == 3
	var saved = _saved_state(b)
	await _frames(2)
	m.state.money = price - 1234
	await _frames(2)
	var short_ok: bool = p._spare_button.disabled and p._car_wait.visible and p._car_wait.text.begins_with("1,234원 모자람")
	var short_text: String = p._car_wait.text
	_click(p._spare_button.get_global_rect().get_center())
	short_ok = short_ok and m.state.money == price - 1234 and m.state.spares == 3
	_report(bought_ok and saved != null and saved.spares == 3 and p._car_result.text.contains("3") and short_ok,
			"⑧ 카센터 [사기] → 돈 −%s원, 스페어 2 → 3개, 저장 파일 %s개, '%s' / 모자라면 꺼짐 '%s'" % [
			Fmt.money(price), saved.spares if saved != null else -1, p._car_result.text, short_text])

	# ⑨ +18 스페어 0개: 강화 칸에 이유 글 + [카센터로] → 카센터
	m.state.truck(0).star = 18
	m.state.spares = 0
	m.state.money = RICH
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(3)
	var block_ok: bool = p._wait.visible and p._wait.text == tr("GARAGE_NEED_SPARE") and p.to_car_button.is_visible_in_tree() and p._enhance_button.disabled
	var wait_text: String = p._wait.text
	_click(p.to_car_button.get_global_rect().get_center())
	await _frames(2)
	_report(block_ok and p.building == "car_center" and _shown(p) == "car_center",
			"⑨ +18 스페어 0개: '%s' + [%s] → %s 화면" % [wait_text, p.to_car_button.text, p.building_buttons[p.building].text])

	# ⑪ [작게]·Esc 뒤 다시 건물 → 그 건물 화면. 알림 영역 아이콘 = 마지막에 보던 건물
	_click(m.small_button.get_global_rect().get_center())
	await _frames(2)
	var after_small: bool = not m.is_full()
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var depot_again: bool = m.is_full() and p.building == "depot"
	_key(KEY_ESCAPE)
	await _frames(2)
	var after_esc: bool = not m.is_full()
	m.screen._on_tray_full()   # 알림 영역 아이콘 왼쪽 클릭 (화면 없는 실행에는 아이콘이 없어 그 함수를 부름)
	await _frames(2)
	var tray_last: bool = m.is_full() and p.building == "depot"
	_key(KEY_ESCAPE)
	await _frames(2)
	_click(town.building_rects()["car_center"].get_center())
	await _frames(3)
	var car_again: bool = m.is_full() and p.building == "car_center"
	_key(KEY_ESCAPE)
	await _frames(2)
	await _close(m)
	m = await _launch()
	m.screen._on_tray_full()
	await _frames(2)
	var tray_first: bool = m.is_full() and m.panel.building == "tuning"
	_report(after_small and depot_again and after_esc and tray_last and car_again and tray_first,
			"⑪ [작게] 뒤 물류센터 → 물류센터, Esc 뒤 카센터 → 카센터, 알림 영역 아이콘 → 마지막에 본 물류센터 (처음 켰을 땐 튜닝숍)")
	await _close(m)

	# ⑬ 오른쪽 클릭 메뉴는 건물·도로 어디서든 그대로 (화면은 그대로)
	m = await _launch()
	town = m.town
	var asks := [0]
	m.screen.menu_asked.connect(func(): asks[0] += 1)
	var right_spots := [town.to_view(town.route.point_at(town.route.total() * 0.3)) + town.global_position]
	for id: String in Town.BUILDINGS:
		right_spots.append(town.building_rects()[id].get_center() + town.global_position)
	for at: Vector2 in right_spots:
		_mouse(MOUSE_BUTTON_RIGHT, at, true)
		_mouse(MOUSE_BUTTON_RIGHT, at, false)
		await _frames(1)
	_report(asks[0] == right_spots.size() and not m.is_full(),
			"⑬ 오른쪽 클릭 (도로 + 건물 세 개) → 메뉴 %d번 / %d번, 작은 화면 그대로" % [asks[0], right_spots.size()])
	await _close(m)

	# U1 ④ 처음 말풍선: 새 설정 → 작은 화면에 뜸 → 도로·말풍선 클릭엔 그대로 → 건물 클릭 → 사라짐·설정 저장
	#   → 다시 켜도 안 뜸. 새 설정에서 작은 버튼으로도 사라짐
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = await _launch()
	town = m.town
	var hint_bad: Array = await _check_hint(m)
	var hint_first: bool = town.hint.visible
	var hint_text: String = town.hint.text
	var hint_spot: Vector2 = town.hint.get_global_rect().get_center()
	var spot_with: bool = _has_point(m.visible_rects(), hint_spot)
	var road_at: Vector2 = town.to_view(town.route.point_at(town.route.total() * 0.5)) + town.global_position
	for at: Vector2 in [road_at, town.hint.get_global_rect().get_center()]:
		if town.building_at(at - town.global_position) != "":
			hint_bad.append("%s 자리가 건물 위" % at)
		_click(at)
		await _frames(2)
	var after_road: bool = town.hint.visible and not m.is_full()
	_click(town.building_rects()["car_center"].get_center() + town.global_position)
	await _frames(3)
	var gone_full: bool = m.is_full() and not town.hint.visible
	_key(KEY_ESCAPE)
	await _frames(2)
	var gone_small: bool = not m.is_full() and not town.hint.visible
	var spot_without: bool = _has_point(m.visible_rects(), hint_spot)
	var hint_saved: bool = ScreenMode.load_value(Main.HINT_SECTION, Main.HINT_KEY, false) == true
	await _close(m)
	m = await _launch()
	var not_again: bool = not m.is_full() and not m.town.hint.visible
	await _close(m)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = await _launch()
	var fresh_again: bool = m.town.hint.visible
	_click(m.town.tuning_button.get_global_rect().get_center())
	await _frames(3)
	var button_full: bool = m.is_full() and m.panel.building == "tuning"
	_key(KEY_ESCAPE)
	await _frames(2)
	var button_gone: bool = fresh_again and button_full and not m.is_full() and not m.town.hint.visible
	await _close(m)
	_report(hint_first and hint_text == "건물을 눌러보세요" and hint_bad.is_empty() and after_road and gone_full and gone_small
			and spot_with and not spot_without and hint_saved and not_again and button_gone,
			"U1 ④ 말풍선 '%s': 새 설정이면 작은 화면에 뜸 (작은 화면 %d가지 보이는 곳 안, 건물·집·구석 줄·할 일 줄과 안 겹침, 큰 화면엔 없음) %s, 도로·말풍선 클릭엔 그대로, 카센터 클릭 → 사라짐 (말풍선 자리가 보이는 곳 %s → %s)·설정 파일에 저장 %s, 다시 켜도 안 뜸 %s, 새 설정에서 작은 버튼으로도 사라짐 %s" % [
			hint_text, SMALL_SIZES.size(), hint_bad, spot_with, spot_without, hint_saved, not_again, button_gone])

	# ⑩ 고르다 만 세팅이 있는 저장으로 켬 → 튜닝숍 세팅 칸 (건물을 누르면 그 고르는 화면)
	var s := GameState.new_game()
	s.money = RICH
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Setting.try_roll(s, b, 0, "cargo_box", rng)
	Save.delete_file(TEST_SAVE)
	Save.write_file(TEST_SAVE, s, int(Time.get_unix_time_from_system()))
	m = await _launch()
	p = m.panel
	var pending_set: bool = p.building == "tuning" and p.current_tab() == p.Tab.SETTING
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_report(s.truck(0).part("cargo_box")["pending"] != null and pending_set and m.is_full() and p.setting.is_visible_in_tree()
			and p.setting._choose.visible and p.setting.selected == "cargo_box",
			"⑩ 고르다 만 세팅(적재함)이 있으면 켤 때 튜닝숍 [%s] 칸, 튜닝숍을 누르면 고르는 화면" % p.setting_tab_button.text)
	var ko_texts := []
	for id: String in Town.BUILDINGS:
		_click(p.building_buttons[id].get_global_rect().get_center())
		await _frames(2)
		ko_texts.append_array(_visible_texts(m))
	await _close(m)

	# ⑫ en: 건물 간판·이름표·위쪽 줄·NPC 이름·인사말 (+ 작은 버튼), 간판은 건물 안. ko는 "차고"가 안 보임
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))   # en 말풍선도 보이게
	m = await _launch()
	town = m.town
	p = m.panel
	await _check_layout(m, "en")
	var en_hint_bad: Array = await _check_hint(m)
	_report(town.hint.visible and town.hint.text == "Click a building" and not _untranslated(town.hint.text) and en_hint_bad.is_empty(),
			"U1 ④ en 말풍선 '%s' 한글·키 없음, 작은 화면 %d가지 보이는 곳 안·건물·집·구석 줄과 안 겹침 %s" % [town.hint.text, SMALL_SIZES.size(), en_hint_bad])
	var en_texts := [town.tuning_button.text, town.hint.text]
	for id: String in Town.BUILDINGS:
		en_texts.append(town._signs[id].text)
		_move(town.building_rects()[id].get_center())
		await _frames(1)
		en_texts.append(town._name_tag.text)
	_move(_empty_spot(m))
	for id: String in Town.BUILDINGS:
		_click(town.building_rects()[id].get_center())
		await _frames(3)
		en_texts.append_array(_visible_texts(m))
		_key(KEY_ESCAPE)
		await _frames(2)
	var bad := en_texts.filter(_untranslated)
	var garage_ko := ko_texts.filter(func(x): return String(x).contains("차고"))
	_report(bad.is_empty() and garage_ko.is_empty() and p.building_buttons["car_center"].text == "Car Center"
			and town._signs["tuning"].text == "Tuning Shop",
			"⑫ en 건물·NPC·작은 버튼 글자 %d개에 한글·키 없음 %s, ko 보이는 글자 %d개에 '차고' 없음 %s" % [
			en_texts.size(), bad, ko_texts.size(), garage_ko])
	print("    en: %s" % [en_texts.slice(0, 7)])
	await _close(m)

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## ① 작은 화면 크기 3가지 + 큰 화면 3가지: 건물·작은 버튼이 동네 안, 서로·집·돈 표시(구석 줄)·할 일 줄과 안 겹침,
## 간판이 건물 안, 작은 화면이면 건물·작은 버튼이 보이는 곳 사각형 안
func _check_layout(m: Node, tag: String) -> void:
	var town = m.town
	var bad := []
	for size: Vector2i in SMALL_SIZES + FULL_SIZES:
		var small := SMALL_SIZES.has(size)
		if small:
			m.screen.enter_small()
		else:
			m.screen.enter_full()
		root.size = size
		await _frames(3)
		var rects: Dictionary = town.building_rects()
		var hud := Rect2(town._hud.position, town._hud.size)
		var quest := Rect2(town._quest_label.position, town._quest_label.size)
		var button: Rect2 = Rect2(town.tuning_button.global_position - town.global_position, town.tuning_button.size)
		var others: Array = [["구석 줄", hud], ["할 일 줄", quest]]
		for spot in town._houses:
			others.append(["집", town.view_rect(town._house_rect(spot))])
		for id: String in rects:
			var r: Rect2 = rects[id]
			var sign_r := Rect2(town._signs[id].position, town._signs[id].size)
			if not town.area().encloses(r):
				bad.append("%s %s 동네 밖" % [size, id])
			if not r.encloses(sign_r):
				bad.append("%s %s 간판 '%s'이 건물 밖" % [size, id, town._signs[id].text])
			for o in others:
				if r.intersects(o[1]):
					bad.append("%s %s ↔ %s" % [size, id, o[0]])
			for id2: String in rects:
				if id2 > id and r.intersects(rects[id2]):
					bad.append("%s %s ↔ %s" % [size, id, id2])
			if small and not _enclosed(m.visible_rects(), Rect2(r.position + town.global_position, r.size)):
				bad.append("%s %s 보이는 곳 밖" % [size, id])
		if not town.area().encloses(button) or others.slice(2).any(func(o): return button.intersects(o[1])):
			bad.append("%s 작은 버튼 %s 동네 밖이거나 집과 겹침" % [size, button])
		if small and not _enclosed(m.visible_rects(), Rect2(button.position + town.global_position, button.size)):
			bad.append("%s 작은 버튼 보이는 곳 밖" % size)
		if small and m.visible_rects().size() > 30:
			bad.append("%s 보이는 곳 사각형 %d개 (30개 이하)" % [size, m.visible_rects().size()])
	m.screen.enter_small()
	root.size = Feel.SMALL_SIZE
	await _frames(3)
	_report(bad.is_empty(), "① %s 작은 화면 %d가지 + 큰 화면 %d가지: 건물 세 개 + 작은 버튼이 동네 안·보이는 곳 안, 서로·집·돈 표시·할 일 줄과 안 겹침, 간판은 건물 안 %s" % [
			tag, SMALL_SIZES.size(), FULL_SIZES.size(), bad])


## 처음 말풍선 자리: 작은 화면 크기 3가지에서 보이고, 동네 안·보이는 곳 안, 건물·집·구석 줄·할 일 줄과 안 겹침.
## 큰 화면에서는 안 보임. 문제 목록을 돌려줌 (끝나면 작은 화면 기본 크기로)
func _check_hint(m: Node) -> Array:
	var town = m.town
	var bad := []
	for size: Vector2i in SMALL_SIZES:
		m.screen.enter_small()
		root.size = size
		await _frames(3)
		var r := Rect2(town.hint.position, town.hint.size)
		if not town.hint.visible:
			bad.append("%s 안 보임" % size)
		if not town.area().encloses(r):
			bad.append("%s 동네 밖" % size)
		if not _enclosed(m.visible_rects(), Rect2(r.position + town.global_position, r.size)):
			bad.append("%s 보이는 곳 밖" % size)
		var others: Array = [["구석 줄", Rect2(town._hud.position, town._hud.size)], ["할 일 줄", Rect2(town._quest_label.position, town._quest_label.size)]]
		for id: String in Town.BUILDINGS:
			others.append([id, town.building_rects()[id]])
		for spot in town._houses:
			others.append(["집", town.view_rect(town._house_rect(spot))])
		for o in others:
			if r.intersects(o[1]):
				bad.append("%s ↔ %s" % [size, o[0]])
		if m.visible_rects().size() > 30:
			bad.append("%s 보이는 곳 사각형 %d개 (30개 이하)" % [size, m.visible_rects().size()])
	m.screen.enter_full()
	await _frames(3)
	if town.hint.visible:
		bad.append("큰 화면에 보임")
	m.screen.enter_small()
	root.size = Feel.SMALL_SIZE
	await _frames(3)
	return bad


## 지금 보이는 건물 화면 id (위쪽 줄과 상관없이 실제로 보이는 칸으로 판단)
func _shown(p) -> String:
	if p._engine_box.is_visible_in_tree() or p.setting.is_visible_in_tree():
		return "tuning"
	if p.driver.is_visible_in_tree():
		return "depot"
	if p._car_box.is_visible_in_tree():
		return "car_center"
	return ""


## 아무것도 없는 동네 자리 (건물·길·집 밖)
func _empty_spot(m: Node) -> Vector2:
	return m.town.to_view(Vector2(300, 100)) + m.town.global_position


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["BUILDING_", "NPC_", "CAR_", "TOWN_", "GARAGE_"]:
		if x.begins_with(prefix):
			return true
	return _hangul.search(x) != null


## 저장 파일의 상태 (없으면 null)
func _saved_state(b: Balance):
	var r := Save.read_file(TEST_SAVE, b)
	return r["state"] if r["status"] == Save.Status.OK else null


func _has_point(rects: Array, at: Vector2) -> bool:
	return rects.any(func(v: Rect2): return v.has_point(at))


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
	_mouse(MOUSE_BUTTON_LEFT, pos, true)
	_mouse(MOUSE_BUTTON_LEFT, pos, false)


func _mouse(button: MouseButton, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
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
