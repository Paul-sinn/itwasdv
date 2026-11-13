## v6b U1·U2 완료 기준 자동 확인. U1: 대형·VIP·급송 "+금액", 급송 전화 말풍선, [설정] 급송 끄기, 주간 배송 목표.
## U2: 명장 요일 고르기·[명장] 칸·예고/방문 알림·강화 칸 [보험]·"+2!"·"N번 시도 가능"·띠의 튜닝숍 표시.
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 단계·벨 시계·주간 진행을 미리 넣는 것은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 Rush.tick → Trip.advance → take_events)으로 한다.
## ① 대형·VIP·급송 "+금액"의 색·글자가 보통과 다름
## ② 벨 → 말풍선이 작은 화면 visible_rects() 안, [받기] 클릭 → 사라지고 구석 줄 "급송 N건 남음", 건수가 줄다 0이면 사라짐
## ③ 안 받으면 벨 시간(30초) 뒤 사라짐 (남은 시간 막대가 줄어듦, 급송 0건)   ④ [설정]에서 끄면 저장되고 다시 켜도 꺼져 있음 (벨 안 울림)
## ⑤ 물류센터 [창고·할 일] 주간 목표 줄이 진행·달성을 보여 줌, 달성 알림, 주가 바뀌면 0   ⑥ en에 한글·키 없음
## ⑦ 창 크기: 작은 화면 3가지에서 말풍선·"급송 N건 남음"이 동네 안·보이는 곳 안·건물·집과 안 겹침 (글자 10개 떠도 사각형 30개 이하),
##    큰 화면 5가지에서 물류센터 화면·[설정]이 창 안
## U2 ① [명장] 칸 잠김 글 → +10 뒤 요일 고르기 창   ② 요일 클릭 → 저장, 바꾸면 "다음 주부터"   ③ 예고·방문 알림
##    ④ 방문 중 강화 칸에 보너스 줄, [보험] 켜면 비용·확률 글이 바뀌고 실제 빠지는 돈 = 비용 + 보험 요금
##    ⑤ 쿠폰만 있을 때 [보험] → 쿠폰 −1   ⑥ 방문일도 쿠폰도 없으면 [보험] 꺼짐   ⑦ 보험이 막은 퍼짐 결과 글, 2단계면 "+2!"
##    ⑧ "지금 돈이면 N번 시도 가능" = 실제로 누른 횟수   ⑨ 방문 중 작은 화면 튜닝숍 테두리 (보이는 곳 안)   ⑩ en, 창 크기 5가지
## 현지 시각은 main.now_local_override로 고정 (수요일 낮 12시: 확인 도중 주가 안 바뀌게. U2는 목·금요일로 옮겨 가며).
## 결과를 정해야 하는 강화(⑦)는 main의 난수 씨앗을 미리 골라 둔다 (같은 씨앗의 난수를 따로 뽑아 보고 고름). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v6b.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Master = preload("res://scripts/core/master.gd")
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

	await _u2(b)

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


# ---------------- U2: 명장·보험 ----------------

func _u2(b: Balance) -> void:
	TranslationServer.set_locale("ko")
	var thu := now + DAY       # 고른 방문일 (목요일)
	var fri := now + 2 * DAY   # 방문일 아님
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	var m := await _launch_u2(b)
	var p = m.panel
	var town = m.town
	var mt = p.master
	var picker = m.day_picker
	var t = m.state.truck(0)
	t.star = b.master_unlock_star - 1
	m.state.money = Economy.enhance_cost(b, t.star, m.state) * 100

	# ① [명장] 칸 잠김 글 → 강화 버튼을 눌러 +10 → 요일 고르기 창 (튜닝숍 [명장] 칸 위)
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(p.master_tab_button.get_global_rect().get_center())
	await _frames(2)
	var locked_text: String = mt._locked.text
	var locked_ok: bool = mt._locked.is_visible_in_tree() and not mt._open_box.visible and not picker.visible \
			and locked_text == "엔진 +%d을 달성하면 명장이 찾아와요" % b.master_unlock_star
	_click(p.engine_tab_button.get_global_rect().get_center())
	await _frames(2)
	var presses := 0
	while t.star < b.master_unlock_star and presses < 40:
		await _press_enhance(m)
		presses += 1
	await _frames(3)
	var picker_texts := _visible_texts(picker)
	var pick_ok: bool = t.star == b.master_unlock_star and m.state.master_unlocked and picker.visible and picker_texts.has("명장이 찾아왔어요!") \
			and picker_texts.has("어떤 요일에 명장이 오면 좋겠어요?") and picker.day_buttons.size() == 7 and p.current_tab() == p.Tab.MASTER \
			and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(picker.get_global_rect())
	var hidden_line: String = mt._bonus.text
	_report(locked_ok and pick_ok, "① [명장] 칸 잠김 '%s' → [강화] %d번 눌러 +%d → 요일 고르기 창 %s, 튜닝숍 [명장] 칸" % [
			locked_text, presses, t.star, picker_texts])

	# ② 창에서 [목] (오늘 수요일 → 이번 주부터) → 저장. [명장] 칸에서 [금]으로 바꿈 → "다음 주부터 금요일"·저장
	_click(picker.day_buttons[3].get_global_rect().get_center())
	var saved1 = _saved_state(b)
	await _frames(2)
	var day_text: String = mt._day.text
	var first_ok: bool = not picker.visible and Master.chosen_day(m.state) == 3 and Master.pending_day(m.state) == -1 \
			and saved1 != null and saved1.master_day == 3 and day_text == "명장 방문일: 매주 목요일" and mt.day_buttons[3].button_pressed \
			and not mt._next.visible and mt._open_box.is_visible_in_tree()
	_click(mt.day_buttons[4].get_global_rect().get_center())
	var saved2 = _saved_state(b)
	await _frames(2)
	var change_ok: bool = Master.chosen_day(m.state) == 3 and Master.pending_day(m.state) == 4 and saved2 != null and saved2.master_next_day == 4 \
			and saved2.master_day == 3 and mt._day.text == day_text and mt._next.is_visible_in_tree() and mt._next.text == "다음 주부터 금요일" \
			and mt.day_buttons[4].button_pressed and not mt.day_buttons[3].button_pressed and mt._pick_note.text == "요일을 바꾸면 다음 주부터 적용돼요"
	_report(first_ok and change_ok, "② 창 [목] 클릭 → '%s'·저장 (창 닫힘), [명장] 칸 [금] 클릭 → '%s'·저장, 이번 주는 목요일 그대로" % [day_text, mt._next.text])

	# ③ 수요일: 내일 방문 예고 알림, [명장] 칸 보너스가 보임 → 목요일: 방문 알림 (같은 보너스), "오늘 명장이 와 있어요!"
	var bonus: String = m.state.master_bonus
	var bonus_text := Fmt.master_bonus(b.master_bonuses, bonus)
	var want_tomorrow := "내일 명장이 와요: " + bonus_text
	var got_tomorrow: bool = await _until(func(): return _noticed(town, want_tomorrow), 3.0)
	await _frames(1)
	var known_line: String = mt._bonus.text
	var not_today: bool = not mt._today.visible and m.state.active_bonus == ""
	m.now_local_override = thu
	var want_today := "오늘 명장이 와 있어요: " + bonus_text
	var got_today: bool = await _until(func(): return _noticed(town, want_today), 3.0)
	await _frames(1)
	_report(got_tomorrow and got_today and bonus != "" and not_today and hidden_line == "보너스는 방문 전날 전화로 알려 줘요"
			and known_line == "이번 방문 보너스: " + bonus_text and mt._today.is_visible_in_tree() and mt._today.text == "오늘 명장이 와 있어요!"
			and m.state.active_bonus == bonus,
			"③ 수요일 알림 '%s' → 목요일 알림 '%s', [명장] 칸 '%s' → '%s', '%s'" % [want_tomorrow, want_today, hidden_line, known_line, mt._today.text])

	# ④ 목요일(방문 중) +18: 보너스 줄, [보험] 클릭 → 비용·확률·퍼짐 글이 바뀜, [강화] → 빠진 돈 = 비용 + 보험 요금 (쿠폰 그대로)
	_click(p.engine_tab_button.get_global_rect().get_center())
	t.star = 18
	m.state.spares = 1
	m.state.coupons = 3
	var cost := Economy.enhance_cost(b, 18, m.state)
	m.state.money = cost * 10
	await _frames(2)
	var line: String = p._master_line.text
	var plain_cost: String = p._cost.text
	var plain_chances: String = p._chances.text
	var plain_danger: String = p._danger.text
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	var fee := Enhance.insure_fee(m.state, b, 0, thu)
	var c: Dictionary = Enhance.chances_for(b, m.state, 0, true)
	var ins_cost: String = p._cost.text
	var ins_ok: bool = p.insure and p.insure_button.button_pressed and fee > 0 and fee == roundi(cost * b.master_insure_fee_mult) \
			and plain_cost == "비용 %s원" % Fmt.money(cost) and ins_cost == "비용 %s원 + 보험 %s원" % [Fmt.money(cost), Fmt.money(fee)] \
			and p._chances.text == tr("GARAGE_CHANCES") % [Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(0.0)] \
			and p._chances.text != plain_chances and plain_danger.begins_with("퍼질 확률") and p._danger.text == "보험: 퍼져도 단계 유지" \
			and p._style.border_color != Feel.COLOR_DANGER and not p._enhance_button.disabled
	var money0: int = m.state.money
	await _press_enhance(m)
	var paid: int = money0 - m.state.money
	_report(line == "명장 방문 중: " + bonus_text and ins_ok and paid == cost + fee and m.state.coupons == 3,
			"④ 방문 중 '%s', [보험] → '%s' → '%s', '%s' → '%s', [강화] 빠진 돈 %s원 = 비용 + 보험 (쿠폰 3장 그대로)" % [
			line, plain_cost, ins_cost, plain_danger, p._danger.text, Fmt.money(paid)])

	# ⑤ 금요일(방문일 아님) +18 스페어 0, 쿠폰 2장: [보험] 끄면 스페어가 없어 못 누름 → 켜면 쿠폰 글, [강화] → 쿠폰 −1, 비용만
	m.now_local_override = fri
	t.star = 18
	m.state.spares = 0
	m.state.coupons = 2
	await _frames(2)
	cost = Economy.enhance_cost(b, 18, m.state)
	m.state.money = cost * 5
	if p.insure:
		_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	var off_ok: bool = not p.insure and not p._master_line.visible and p._enhance_button.disabled and p._wait.text == tr("GARAGE_NEED_SPARE")
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	var coupon_text: String = p._cost.text
	var on_ok: bool = p.insure and coupon_text == "비용 %s원 · 보험 쿠폰 1장 사용 (1장 남음)" % Fmt.money(cost) and not p._enhance_button.disabled
	money0 = m.state.money
	await _press_enhance(m)
	_report(off_ok and on_ok and m.state.coupons == 1 and money0 - m.state.money == cost and m.state.spares == 0,
			"⑤ 금요일 쿠폰 2장 [보험] → '%s', [강화] → 쿠폰 2 → %d장, 빠진 돈 %s원 = 비용 (스페어 0개로도 누름)" % [
			coupon_text, m.state.coupons, Fmt.money(money0 - m.state.money)])

	# ⑥ 방문일도 아니고 쿠폰도 없으면 [보험] 꺼짐 (눌러도 안 켜짐)
	m.state.coupons = 0
	t.star = 18
	await _frames(2)
	var dis_ok: bool = p.insure_button.disabled and not p.insure and not p.insure_button.button_pressed
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	_report(dis_ok and not p.insure and p.insure_button.disabled and p._cost.text == "비용 %s원" % Fmt.money(cost),
			"⑥ 방문일 아님 + 쿠폰 0장: [%s] 꺼짐, 눌러도 안 켜짐 ('%s')" % [p.insure_button.text, p._cost.text])

	# ⑦ 쿠폰 보험 + 퍼짐이 뜨는 씨앗 → "보험 덕분에 살았어요" (+18 그대로, 스페어 안 씀)
	m.state.coupons = 1
	m.state.money = cost * 5
	await _frames(2)
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	var c0: Dictionary = Enhance.chances_for(b, m.state, 0)
	var lo: float = c0["success"]
	var hi: float = lo + c0["destroy"]
	m.rng.seed = _seed_for(func(r1: float, _r2: float): return r1 >= lo and r1 < hi)
	var destroys0: int = t.destroy_count
	await _press_enhance(m)
	var insured_text: String = p._result.text
	var insured_ok: bool = insured_text == "보험 덕분에 살았어요! (+18 그대로)" and t.star == 18 and m.state.spares == 0 and m.state.coupons == 0 \
			and t.destroy_count == destroys0
	# 목요일(방문 중) 보너스 "2단계" + 성공하고 한 번 더 뜨는 씨앗 → "+2!  +18 → +20"
	m.now_local_override = thu
	m.state.master_bonus = "double_step"   # 준비: 이번 주 보너스를 "2단계"로 (그 주 번호는 그대로)
	t.star = 18
	m.state.spares = 1
	m.state.money = cost * 5
	await _frames(2)
	if p.insure:
		_click(p.insure_button.get_global_rect().get_center())
		await _frames(2)
	var c1: Dictionary = Enhance.chances_for(b, m.state, 0)
	var win: float = c1["success"]
	var extra: float = b.master_bonuses["double_step"]
	m.rng.seed = _seed_for(func(r1: float, r2: float): return r1 < win and r2 < extra)
	await _press_enhance(m)
	var double_text: String = p._result.text
	_report(insured_ok and m.state.active_bonus == "double_step" and double_text == "+2!  +18 → +20" and t.star == 20,
			"⑦ 쿠폰 보험 + 퍼짐 → '%s' (+%d, 스페어 0개 그대로), 방문 중 '2단계' 보너스 → '%s'" % [insured_text, 18, double_text])

	# ⑧ 목요일 방문 중 +18: "지금 돈이면 N번 시도 가능" (보험 끔 / 켬) = Economy.tries, 켠 채로 누를 수 있는 만큼 누른 횟수와 같음
	m.state.master_bonus = bonus
	t.star = 18
	m.state.spares = 1
	m.state.coupons = 0
	await _frames(2)
	cost = Economy.enhance_cost(b, 18, m.state)
	fee = Enhance.insure_fee(m.state, b, 0, thu)
	m.state.money = (cost + fee) * 3 + cost
	await _frames(2)
	var tries_off: String = p._tries.text
	var n_off := Economy.tries(m.state, b, 0, false, thu)
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	var tries_on: String = p._tries.text
	var n_on := Economy.tries(m.state, b, 0, true, thu)
	var pressed := 0
	while not p._enhance_button.disabled and pressed < 10:
		await _press_enhance(m)
		pressed += 1
		t.star = 18   # 준비: 단계를 되돌림 (글은 "지금 단계 비용으로 N번")
		await _frames(2)
	_report(tries_off == "지금 돈이면 %d번 시도 가능" % n_off and tries_on == "지금 돈이면 %d번 시도 가능" % n_on and n_on == 3 and n_off == 10
			and pressed == n_on and p.insure and m.state.money == cost,
			"⑧ 보험 끔 '%s' / 켬 '%s' (Economy.tries), [보험] 켠 채로 실제로 %d번 누르고 막힘" % [tries_off, tries_on, pressed])

	# ⑨ 작은 화면 3가지: 방문 중이면 튜닝숍 테두리가 보이는 곳 안, 방문일이 아니면 없음
	m.screen.enter_small()
	await _frames(3)
	var mark_bad := []
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		var r: Rect2 = town.building_rects()["tuning"]
		var mark := Rect2(r.position + town.global_position, r.size).grow(Feel.MASTER_MARK_WIDTH / 2.0 * town.zoom)
		if not town.master_visit or not _enclosed(m.visible_rects(), mark):
			mark_bad.append("%s 테두리 %s" % [size, mark])
	root.size = Feel.SMALL_SIZE
	m.now_local_override = fri
	await _frames(2)
	var off_day: bool = not town.master_visit
	m.now_local_override = thu
	await _frames(2)
	_report(mark_bad.is_empty() and off_day and town.master_visit,
			"⑨ 방문 중 작은 화면 %d가지: 튜닝숍 테두리가 보이는 곳 안, 금요일엔 없음 %s" % [SMALL_SIZES.size(), mark_bad])

	# ⑩ ko 큰 화면 5가지 (강화 칸 가장 긴 때·[보험] 켬, [명장] 칸, 요일 고르기 창)
	var fit_ko: Array = await _check_fits_u2(m, b)
	await _close(m)

	# ⑩ en: 잠김 글·요일 창·[명장] 칸·알림·강화 칸·결과 글·보너스 7개·요일 이름에 한글·키 없음 + 창 크기 5가지
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	m = await _launch_u2(b)
	p = m.panel
	town = m.town
	mt = p.master
	t = m.state.truck(0)
	var texts := []
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(p.master_tab_button.get_global_rect().get_center())
	await _frames(2)
	texts.append_array(_visible_texts(mt))
	t.star = b.master_unlock_star   # 준비: +10 (Master.tick이 열고 요일 창)
	await _frames(3)
	texts.append_array(_visible_texts(m.day_picker))
	var en_picker: bool = m.day_picker.visible
	_click(m.day_picker.day_buttons[3].get_global_rect().get_center())
	await _frames(2)
	_click(mt.day_buttons[4].get_global_rect().get_center())
	await _frames(2)
	texts.append_array(_visible_texts(mt))
	await _until(func(): return town.notices_shown.size() + town._notice_queue.size() > 0, 3.0)
	m.now_local_override = thu
	await _frames(3)
	texts.append_array(_visible_texts(mt))
	texts.append_array(town.notices_shown)
	texts.append_array(town._notice_queue)
	_click(p.engine_tab_button.get_global_rect().get_center())
	t.star = 18
	m.state.money = Economy.enhance_cost(b, 18, m.state) * 10
	m.state.coupons = 1
	await _frames(2)
	texts.append_array(_visible_texts(p))
	_click(p.insure_button.get_global_rect().get_center())
	await _frames(2)
	texts.append_array(_visible_texts(p))
	m.now_local_override = fri
	await _frames(2)
	texts.append_array(_visible_texts(p))
	for key in ["GARAGE_NO_INSURE", "MASTER_BONUS_HIDDEN", "MASTER_LOCKED", "MASTER_PICK_FIRST"]:
		texts.append(tr(key))
	texts.append(tr("RESULT_INSURED") % 18)
	texts.append(tr("RESULT_DOUBLE") % [18, 20])
	for id: String in b.master_bonus_ids:
		texts.append(Fmt.master_bonus(b.master_bonuses, id))
	for d in 7:
		texts.append(Fmt.day_name(d))
		texts.append(Fmt.day_name(d, true))
	var bad := texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and en_picker and p.insure_button.text == "Insurance" and p.master_tab_button.text == "Master",
			"⑩ en [명장]·요일 창·알림·강화 칸·결과·보너스 7개·요일 글자 %d개에 한글·키 없음 %s" % [texts.size(), bad])
	print("    en: %s" % [texts])
	m.now_local_override = thu
	var fit_en: Array = await _check_fits_u2(m, b)
	await _close(m)
	TranslationServer.set_locale("ko")
	_report(fit_ko.is_empty() and fit_en.is_empty(),
			"⑩ ko·en 큰 화면 %d가지: 튜닝숍 [엔진 강화] (방문 줄·퍼짐·스페어 없음·결과, [보험] 켬), [명장] 칸, 요일 고르기 창이 창 안, 동네·[작게]·[설정]과 안 겹침 %s %s" % [
			FIT_SIZES.size(), fit_ko, fit_en])


## ⑩ 큰 화면 5가지: 강화 칸이 가장 긴 때 (방문 줄 + 퍼짐 + 스페어 없음 + [카센터로] + 결과 두 줄) / [보험] 켬, [명장] 칸 (바꾼 요일까지), 요일 고르기 창. 문제 목록
func _check_fits_u2(m: Node, b: Balance) -> Array:
	var p = m.panel
	var town = m.town
	var bad := []
	var t = m.state.truck(0)
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		var view := Rect2(Vector2.ZERO, Vector2(size))
		_click(p.engine_tab_button.get_global_rect().get_center())
		t.star = 18
		m.state.spares = 0
		m.state.coupons = 1
		m.state.money = Economy.enhance_cost(b, 18, m.state) * 3
		if p.insure:
			_click(p.insure_button.get_global_rect().get_center())
		p.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, tr("RESULT_DESTROY_NOTE") % [b.broken_drop_to, 0])   # 준비: 결과 두 줄
		await _frames(3)
		for state_name in ["보험 끔", "보험 켬"]:
			var pr: Rect2 = p.get_global_rect()
			# 보험 끔: 퍼짐 설명 + 스페어 없음 이유 줄 + [카센터로] / 보험 켬: 방문 중 보험 요금 + "N번 시도 가능"
			var shown: bool = p._danger_note.visible and p._wait.visible and p.to_car_button.visible if state_name == "보험 끔" \
					else p._tries.visible and p._cost.text.contains("+")
			if not p._master_line.is_visible_in_tree() or not shown or not view.encloses(pr) or pr.intersects(town.area()) \
					or pr.intersects(m.small_button.get_global_rect()) or pr.intersects(m.settings_button.get_global_rect()):
				bad.append("강화 칸 %s %dx%d %s" % [state_name, size.x, size.y, pr])
			_click(p.insure_button.get_global_rect().get_center())
			await _frames(3)
		_click(p.master_tab_button.get_global_rect().get_center())
		await _frames(3)
		var mr: Rect2 = p.get_global_rect()
		if not p.master._next.is_visible_in_tree() or not view.encloses(mr) or mr.intersects(town.area()) or mr.intersects(m.settings_button.get_global_rect()):
			bad.append("[명장] 칸 %dx%d %s" % [size.x, size.y, mr])
		m.day_picker.visible = true   # 준비: 요일 고르기 창을 다시 띄움
		await _frames(3)
		var dr: Rect2 = m.day_picker.get_global_rect()
		if not view.encloses(dr):
			bad.append("요일 창 %dx%d %s" % [size.x, size.y, dr])
		_click(m.day_picker.later_button.get_global_rect().get_center())
		await _frames(2)
		if m.day_picker.visible:
			bad.append("요일 창 %dx%d [나중에]로 안 닫힘" % [size.x, size.y])
	root.size = Vector2i(1600, 900)
	await _frames(2)
	return bad


## U2용으로 띄움: 급송 벨을 끔 (벨이 난수를 쓰지 않게), 할 일은 다 끝냄 (보상 돈이 안 끼게), 뜸은 짧게
func _launch_u2(b: Balance) -> Node:
	var m := await _launch()
	m.state.rush_enabled = false
	m.state.quest_index = Quest.count(b)
	m.suspense_scale = 0.01
	return m


## 차고 [강화] 진짜 클릭 → 결과가 나올 때까지
func _press_enhance(m: Node) -> void:
	_click(m.panel._enhance_button.get_global_rect().get_center())
	await _until(func(): return not m.enhancing, 5.0)
	await _frames(1)


## 난수 씨앗 고르기: 그 씨앗으로 뽑은 첫 두 난수 (Enhance.random01)가 cond(r1, r2)를 만족하는 첫 씨앗
func _seed_for(cond: Callable) -> int:
	var probe := RandomNumberGenerator.new()
	for seed in range(1, 200000):
		probe.seed = seed
		var r1 := Enhance.random01(probe)
		var r2 := Enhance.random01(probe)
		if cond.call(r1, r2):
			return seed
	push_error("씨앗을 못 찾음")
	return 0


## 동네 알림에 text가 떴거나 차례를 기다리나
func _noticed(town: Node, text: String) -> bool:
	return town.notices_shown.has(text) or town._notice_queue.has(text)


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["TOWN_", "SETTINGS_", "DEPOT_", "NOTICE_", "MASTER_", "GARAGE_", "DAY_", "RESULT_"]:
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
