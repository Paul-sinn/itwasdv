## v6b U1 완료 기준 자동 확인: 대형·VIP·급송 "+금액", 급송 전화 말풍선, [설정] 급송 끄기, 주간 배송 목표.
## (U2 명장·보험 확인은 C2를 합친 뒤 이 파일에 더한다)
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 단계·벨 시계·주간 진행을 미리 넣는 것은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 Rush.tick → Trip.advance → take_events)으로 한다.
## ① 대형·VIP·급송 "+금액"의 색·글자가 보통과 다름
## ② 벨 → 말풍선이 작은 화면 visible_rects() 안, [받기] 클릭 → 사라지고 구석 줄 "급송 N건 남음", 건수가 줄다 0이면 사라짐
## ③ 안 받으면 벨 시간(30초) 뒤 사라짐 (남은 시간 막대가 줄어듦, 급송 0건)   ④ [설정]에서 끄면 저장되고 다시 켜도 꺼져 있음 (벨 안 울림)
## ⑤ 물류센터 [창고·할 일] 주간 목표 줄이 진행·달성을 보여 줌, 달성 알림, 주가 바뀌면 0   ⑥ en에 한글·키 없음
## ⑦ 창 크기: 작은 화면 3가지에서 말풍선·"급송 N건 남음"이 동네 안·보이는 곳 안·건물·집과 안 겹침 (글자 10개 떠도 사각형 30개 이하),
##    큰 화면 5가지에서 물류센터 화면·[설정]이 창 안
## 현지 시각은 main.now_local_override로 고정 (수요일 낮 12시: 확인 도중 주가 안 바뀌게). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v6b.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Weekly = preload("res://scripts/core/weekly.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_v6b.json"
const TEST_SETTINGS := "user://test_v6b_settings.cfg"
const DAY := 86400
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
	TranslationServer.set_locale("ko")   # 아래에서 한국어 글자를 비교함 (OS 언어와 상관없이)
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Save.delete_file(TEST_SAVE)
	now = Time.get_unix_time_from_datetime_dict({ "year": 2026, "month": 11, "day": 18, "hour": 12, "minute": 0, "second": 0 })
	var b := Balance.load_file()

	# ① +18에서 급송을 받고 빨리 돌림: 급송·대형·VIP·보통 "+금액"의 글자·색
	var m := await _launch()
	var town = m.town
	m.state.truck(0).star = 18
	m.state.quest_index = Quest.count(b)
	await _ring(m)
	_click(town.rush_button.get_global_rect().get_center())
	await _frames(2)
	var seen := {}   ## 종류 → [글자, 색]
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	var t0 := Time.get_ticks_msec()
	while seen.size() < 4 and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		for pay: Label in town.payouts():
			var kind := _kind_of(pay.text)
			if kind != "" and not seen.has(kind):
				seen[kind] = [pay.text, pay.get_theme_color("font_color")]
	Engine.time_scale = 0.0
	var colors := {}
	for k in seen:
		colors[seen[k][1]] = true
	var pay_ok: bool = seen.size() == 4 and colors.size() == 4 and seen["normal"][1] == Feel.COLOR_PAYOUT \
			and seen["large"][1] == Feel.COLOR_PAYOUT_LARGE and seen["vip"][1] == Feel.COLOR_PAYOUT_VIP and seen["rush"][1] == Feel.COLOR_PAYOUT_RUSH \
			and seen["rush"][0] == "급송 +" + Fmt.money(int(Trip.parcel_pay(b, m.state, 0) * b.rush_pay_mult))
	_report(pay_ok, "① +18 '+금액': 보통 %s, 대형 %s, VIP %s, 급송 %s (색 %d가지)" % [
			seen.get("normal", ["없음"])[0], seen.get("large", ["없음"])[0], seen.get("vip", ["없음"])[0], seen.get("rush", ["없음"])[0], colors.size()])
	await _close(m)

	# ② 벨 → 말풍선 (작은 화면 보이는 곳 안) → [받기] → "급송 20건 남음" → 줄어 0이면 사라짐
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	town = m.town
	m.state.quest_index = Quest.count(b)
	await _ring(m)
	var bubble: Rect2 = town.rush_bubble.get_global_rect()
	var ring_ok: bool = town.rush_bubble.is_visible_in_tree() and _enclosed(m.visible_rects(), bubble) \
			and bubble.encloses(town.rush_button.get_global_rect()) and town._rush_text.text == "급송 요청!" and town.rush_button.text == "받기"
	_click(town.rush_button.get_global_rect().get_center())
	var saved = _saved_state(b)
	await _frames(2)
	var left_rect: Rect2 = town._rush_left.get_global_rect()
	var accept_ok: bool = not town.rush_bubble.visible and Rush.parcels_left(m.state) == b.rush_parcels \
			and town._rush_left.is_visible_in_tree() and town._rush_left.text == "급송 %d건 남음" % b.rush_parcels \
			and _enclosed(m.visible_rects(), left_rect) and saved != null and saved.rush_left == b.rush_parcels and not m.is_full()
	var first_text: String = town._rush_left.text
	var counts := []
	var count_ok := true
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	t0 = Time.get_ticks_msec()
	while Rush.parcels_left(m.state) > 0 and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		var left := Rush.parcels_left(m.state)
		if left > 0:
			count_ok = count_ok and town._rush_left.visible and town._rush_left.text == "급송 %d건 남음" % left
			if counts.is_empty() or counts.back() != left:
				counts.append(left)
	await _frames(2)
	Engine.time_scale = 0.0
	_report(ring_ok and accept_ok and count_ok and counts.size() > 2 and Rush.parcels_left(m.state) == 0 and not town._rush_left.visible,
			"② 벨 → 말풍선 '%s [%s]' (작은 화면 보이는 곳 안), [받기] → 말풍선 사라짐·'%s'·저장, 남은 건수 %s… → 0이면 사라짐" % [
			town._rush_text.text, town.rush_button.text, first_text, counts.slice(0, 5)])

	# ③ 안 받으면: 남은 시간 막대가 줄고, 벨 시간이 끝나면 말풍선 사라짐, 급송 0건
	await _ring(m)
	var bar0: float = town._rush_bar.value
	var ring0: float = m.state.rush_ring
	Engine.time_scale = 10.0
	var bar_mid := -1.0
	var shown_while := true
	t0 = Time.get_ticks_msec()
	while Rush.is_ringing(m.state) and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		if Rush.is_ringing(m.state):
			shown_while = shown_while and town.rush_bubble.visible
			if bar_mid < 0.0 and m.state.rush_ring < b.rush_ring_seconds / 2.0:
				bar_mid = town._rush_bar.value
	await _frames(2)
	Engine.time_scale = 0.0
	_report(ring0 > b.rush_ring_seconds - 1.0 and ring0 <= b.rush_ring_seconds and bar0 > 0.95 and bar_mid > 0.0 and bar_mid < 0.55 and shown_while and not Rush.is_ringing(m.state)
			and not town.rush_bubble.visible and Rush.parcels_left(m.state) == 0 and not town._rush_left.visible,
			"③ 안 받으면: 벨 %s초 동안 말풍선, 막대 %.2f → %.2f → 끝나면 사라짐, 급송 0건" % [Fmt.num(ring0), bar0, bar_mid])
	await _close(m)

	# ④ [설정] 급송 요청 전화 끄기 → 저장 → 다시 켜도 꺼짐, 벨 안 울림
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	var st = m.settings
	var on_shown: bool = st.visible and st.rush_on_button.button_pressed and not st.rush_off_button.button_pressed
	_click(st.rush_off_button.get_global_rect().get_center())
	var saved_off = _saved_state(b)
	await _frames(2)
	var off_ok: bool = on_shown and not m.state.rush_enabled and st.rush_off_button.button_pressed and saved_off != null and not saved_off.rush_enabled
	await _close(m)
	m = await _launch()
	m.state.rush_next = 0.2   # 준비: 켜져 있으면 곧 울릴 시계
	Engine.time_scale = 1.0
	await _frames(30)
	await _wait(0.5)
	Engine.time_scale = 0.0
	var quiet: bool = not m.state.rush_enabled and not Rush.is_ringing(m.state) and not m.town.rush_bubble.visible
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	_report(off_ok and quiet and m.settings.rush_off_button.button_pressed and not m.settings.rush_on_button.button_pressed,
			"④ [설정] '%s' [%s] → 꺼짐·저장, 다시 켜도 [%s] 눌림, 벨 안 울림" % [
			tr("SETTINGS_RUSH"), m.settings.rush_off_button.text, m.settings.rush_off_button.text])
	await _close(m)

	# ⑤ 주간 목표 줄: 진행 → 목표 1건 앞에서 배송 → 달성 알림·쿠폰 +1·"이번 주 달성!", 다음 주가 되면 0
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	town = m.town
	m.state.quest_index = Quest.count(b)
	m.state.weekly_parcels = 12340   # 준비
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(2)
	var line0: String = d._weekly.text
	var want0 := "이번 주 배송 12,340 / %s건 → 보험 쿠폰 %d장 + 경험치 %s" % [Fmt.count(Weekly.target(b)), b.weekly_coupons, Fmt.count(b.weekly_xp)]
	m.state.weekly_parcels = Weekly.target(b) - 1   # 준비: 한 건 남음
	var coupons0: int = m.state.coupons
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	await _until(func(): return Weekly.is_done(m.state), 30.0)
	Engine.time_scale = 0.0
	var want_notice := "주간 배송 목표 달성! 보험 쿠폰 +%d장 · 경험치 +%s" % [b.weekly_coupons, Fmt.count(b.weekly_xp)]
	await _until(func(): return town.notices_shown.any(func(x): return String(x).begins_with(want_notice)), 3.0)
	await _frames(2)
	var line1: String = d._weekly.text
	var done_ok: bool = m.state.coupons == coupons0 + b.weekly_coupons and line1 == "이번 주 달성! (배송 %s건)" % Fmt.count(Weekly.progress(m.state)) \
			and d._weekly.is_visible_in_tree() and town.notices_shown.any(func(x): return String(x).begins_with(want_notice))
	m.now_local_override = now + 7 * DAY   # 다음 주
	await _frames(3)
	var line2: String = d._weekly.text
	_report(line0 == want0 and done_ok and line2.begins_with("이번 주 배송 0 / ") and Weekly.progress(m.state) == 0,
			"⑤ 주간 목표 '%s' → 달성 알림 '%s'·쿠폰 %d → %d, '%s' → 다음 주 '%s'" % [line0, want_notice, coupons0, m.state.coupons, line1, line2])
	await _close(m)

	# ⑦ ko: 작은 화면 3가지 (벨 울릴 때 / 받은 뒤) + 큰 화면 5가지 (물류센터 [창고·할 일], [설정])
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))   # 처음 말풍선도 같이 떠 있게
	m = await _launch()
	var fit_ko: Array = await _check_fits(m, b)
	await _close(m)

	# ⑥ en: "+금액" 앞 글자, 말풍선, "급송 N건 남음", [설정] 한 줄, 주간 목표 줄·알림에 한글·키 없음  ⑦ en도 창 크기
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	town = m.town
	m.state.quest_index = Quest.count(b)
	await _ring(m)
	var texts := [town._rush_text.text, town.rush_button.text]
	_click(town.rush_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(town._rush_left.text)
	for key in ["TOWN_PAY_LARGE", "TOWN_PAY_VIP", "TOWN_PAY_RUSH"]:
		texts.append(tr(key))
	texts.append(tr("NOTICE_WEEKLY") % [1, "2,000"])
	texts.append(tr("DEPOT_WEEKLY_DONE") % "30,000")
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	_click(m.panel.driver.depot_page_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(m.panel.driver._weekly.text)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	texts.append_array(_visible_texts(m.settings))
	var bad := texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and town.rush_button.text == "Accept",
			"⑥ en 급송·대형·VIP·[설정]·주간 목표 글자 %d개에 한글·키 없음 %s" % [texts.size(), bad])
	print("    en: %s" % [texts])
	await _close(m)
	# ⑦ en: 새로 켜서 (위에서 건물을 눌러 처음 말풍선이 사라졌으므로)
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = await _launch()
	var fit_en: Array = await _check_fits(m, b)
	await _close(m)
	_report(fit_ko.is_empty() and fit_en.is_empty(),
			"⑦ ko·en 작은 화면 %d가지: 말풍선·'급송 N건 남음'이 동네 안·보이는 곳 안, 건물·집·할 일 줄과 안 겹침, 글자 10개 + 말풍선 + 처음 말풍선에도 사각형 30개 이하 / 큰 화면 %d가지: 물류센터 [창고·할 일]·[설정]이 창 안, [작게]·[설정] 버튼과 안 겹침 %s %s" % [
			SMALL_SIZES.size(), FIT_SIZES.size(), fit_ko, fit_en])

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## "+금액" 글자 → 종류 ("normal" / "large" / "vip" / "rush"). 급송이면서 대형·VIP인 것은 ""(따로 안 셈)
func _kind_of(text: String) -> String:
	if text.begins_with("+"):
		return "normal"
	if text.begins_with("대형 +"):
		return "large"
	if text.begins_with("VIP +"):
		return "vip"
	if text.begins_with("급송 +"):
		return "rush"
	return ""


## 준비: 벨 시계를 거의 다 돌려 두고 진짜 프레임으로 벨이 울릴 때까지 (그 뒤 게임 시간 멈춤)
func _ring(m: Node) -> void:
	m.state.rush_next = 0.2
	Engine.time_scale = 1.0
	await _until(func(): return Rush.is_ringing(m.state) and m.town.rush_bubble.visible, 5.0)
	Engine.time_scale = 0.0
	await _frames(2)


## ⑦: 작은 화면 3가지 (벨 / 글자 10개 / 받은 뒤 "급송 N건 남음") + 큰 화면 5가지 (물류센터 [창고·할 일], [설정]). 문제 목록
func _check_fits(m: Node, b: Balance) -> Array:
	var town = m.town
	var bad := []
	m.state.quest_index = 0   # 할 일 줄이 보이게
	m.state.weekly_parcels = 12345
	m.state.rush_left = 0     # 받아 둔 급송이 남아 있으면 다음 벨이 안 울림
	await _ring(m)
	for size: Vector2i in SMALL_SIZES:
		m.screen.enter_small()
		root.size = size
		await _frames(3)
		var r := Rect2(town.rush_bubble.position, town.rush_bubble.size)
		var others: Array = [["할 일 줄", Rect2(town._quest_label.position, town._quest_label.size)], ["구석 줄", Rect2(town._hud.position, town._hud.size)]]
		for id: String in Town.BUILDINGS:
			others.append([id, town.building_rects()[id]])
		for spot in town._houses:
			others.append(["집", town.view_rect(town._house_rect(spot))])
		if not town.hint.visible:
			bad.append("%s 처음 말풍선이 안 떠 있음 (확인 준비)" % size)
		if not town.rush_bubble.visible or not town.area().encloses(r) or not _enclosed(m.visible_rects(), Rect2(r.position + town.global_position, r.size)):
			bad.append("%s 말풍선 %s 동네 밖이거나 보이는 곳 밖" % [size, r])
		for o in others:
			if r.intersects(o[1]):
				bad.append("%s 말풍선 ↔ %s" % [size, o[0]])
		for i in 10:   # 글자가 가장 많이 떴을 때도 사각형 30개 이하
			town.show_payout(i % Feel.TOWN_HOUSES, 1875 * (i + 1), ["normal", "large", "vip"][i % 3], i % 2 == 0)
		await _frames(1)
		if m.visible_rects().size() > 30:
			bad.append("%s 말풍선 + 글자 10개: 보이는 곳 사각형 %d개 (30개 이하)" % [size, m.visible_rects().size()])
	_click(town.rush_button.get_global_rect().get_center())
	await _frames(2)
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		var hud := Rect2(town._hud.position, town._hud.size)
		var lr: Rect2 = town._rush_left.get_global_rect()
		if not town._rush_left.visible or not town.area().encloses(hud) or not _enclosed(m.visible_rects(), lr):
			bad.append("%s '급송 N건 남음' %s 동네 밖이거나 보이는 곳 밖" % [size, lr])
		for spot in town._houses:
			if hud.intersects(town.view_rect(town._house_rect(spot))):
				bad.append("%s 구석 줄 ↔ 집" % size)
	root.size = Feel.SMALL_SIZE
	await _frames(2)
	# 큰 화면: 물류센터 [창고·할 일] (주간 목표 줄), [설정] (급송 줄)
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(d.depot_page_button.get_global_rect().get_center())
		await _frames(3)
		var pr: Rect2 = m.panel.get_global_rect()
		if not d._weekly.is_visible_in_tree() or not Rect2(Vector2.ZERO, Vector2(size)).encloses(pr) or pr.intersects(town.area()) \
				or pr.intersects(m.small_button.get_global_rect()) or pr.intersects(m.settings_button.get_global_rect()):
			bad.append("물류센터 %dx%d %s" % [size.x, size.y, pr])
		_click(m.settings_button.get_global_rect().get_center())
		await _frames(3)
		var sr: Rect2 = m.settings.get_global_rect()
		if not m.settings.visible or not Rect2(Vector2.ZERO, Vector2(size)).encloses(sr):
			bad.append("[설정] %dx%d %s" % [size.x, size.y, sr])
		_click(m.settings.close_button.get_global_rect().get_center())
		await _frames(2)
	root.size = Vector2i(1600, 900)
	await _frames(2)
	return bad


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["TOWN_", "SETTINGS_", "DEPOT_", "NOTICE_"]:
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


## node 아래 보이는 Label·Button 글자 전부
func _visible_texts(node: Node) -> Array:
	var out := []
	for n in node.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "":
			out.append(n.text)
	return out


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤)
func _launch() -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	m.now_local_override = now
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
