## v8b 완료 기준 자동 확인 (설정). 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 본다.
## U1: ① [설정] 세 묶음(게임·띠·큰 화면)과 버튼 전부가 ko·en 큰 화면 5가지 크기에서 창 안, [닫기]로 닫힘
##     ② [설정] 언어를 누르면 열려 있는 화면(설정 창, 동네 구석 줄, 튜닝숍, 이미 한 번 연 물류센터 [능력치]·[기록])이
##        그 자리에서 새 언어 (한글·키 없음), 다시 켜도 유지, 다시 한국어로
##     ③ 숫자 표기 3가지 × 언어 2가지: 언어 따라 / 만·억 / K·M ("1.2만" / "12K"), 다시 켜도 유지
##     ④ 알림 끄기: 물류센터 업그레이드 알림 글이 안 뜸, 급송 전화 아이콘·"+금액"은 뜸, 다시 켜도 꺼짐
##     ⑧ 틀린 설정값(손으로 고친 파일) → 기본값, 맞는 값은 그대로 읽힘 (0.85·1.25 같은 소수도)
##     ⑨ [기본값으로]: 설정 파일의 [ui]·[strip] 값이 지워지고 기본값이 눌린 모양, 언어 = PC 언어, 큰 화면 = 전체 화면,
##        게임 저장(급송 전화·돈)과 처음 말풍선 기록은 그대로
## U2: ⑤ 띠 사각형 순수 함수(DesktopWindow.strip_rect): 크기 3 × 자리 2 × 배치가 다른 가짜 모니터 2개에서
##        크기 = 480x220 × 배율, 쓸 수 있는 영역 안, 아래 끝 = 작업표시줄 위, 고른 구석에 붙음
##     ⑥ [설정] 띠 크기 3가지 → [작게]: 동네가 창에 맞게 커지고 visible_rects()가 창 안, 건물·구석 줄이 보이는 곳(클릭 받는 다각형) 안,
##        건물 클릭 자리 = 그림 자리(설계 좌표 × 배율), 건물을 누르면 그 건물 화면·빈 곳은 그대로. 투명도 4가지 = 띠만 (큰 화면 100%)
##     ⑦ 뽑힌 모니터 번호 → 주 모니터 (DesktopWindow.pick_screen), 설정값은 남고 [설정]에는 [주 모니터]가 눌린 모양
##     ⑩ 기본값이면 띠 자리·크기가 v8a와 같음 (옛 식), 투명도 100%, 항상 위 켜기 (기존 확인 전부는 따로 돌림)
## 진짜 저장·설정 파일은 건드리지 않는다. 진짜 창(항상 위·투명도·두 번째 모니터)은 사람이 본다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v8b.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const ClickRegion = preload("res://scripts/ui/click_region.gd")
const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Save = preload("res://scripts/core/save.gd")
const Upgrade = preload("res://scripts/core/upgrade.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Prefs = preload("res://scripts/ui/prefs.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_v8b.json"
const TEST_SETTINGS := "user://test_v8b_settings.cfg"
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]

var fails := PackedStringArray()
var checks := 0
var now := 0   ## 고정 현지 시각 (2026-11-18 수요일 12:00)
var _hangul := RegEx.create_from_string("[가-힣ㄱ-ㅎㅏ-ㅣ]")
var _csv_keys := {}   ## strings.csv 키 (화면에 키가 그대로 나왔나 보려고)


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	now = Time.get_unix_time_from_datetime_dict({ "year": 2026, "month": 11, "day": 18, "hour": 12, "minute": 0, "second": 0 })
	_read_csv_keys()
	var b := Balance.load_file()

	await _fit()
	await _language()
	await _numbers()
	await _notices(b)
	await _bad_values()
	await _defaults()
	_strip_rects()
	await _strip_sizes()
	await _unplugged()

	Engine.time_scale = 1.0
	TranslationServer.set_locale("ko")
	_clean()
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


# ---------------- ① 세 묶음이 창 안 ----------------

func _fit() -> void:
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		_clean()
		var m := await _launch()
		await _go_full(m)
		var st = m.settings
		var bad := []
		var count := 0
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_click(m.settings_button.get_global_rect().get_center())
			await _frames(3)
			var view := Rect2(Vector2.ZERO, Vector2(size))
			var sr: Rect2 = st.get_global_rect()
			if not st.visible or not view.encloses(sr):
				bad.append("창 %s %s" % [size, sr])
			var buttons: Array = st.find_children("*", "Button", true, false)
			count = buttons.size()
			for btn: Button in buttons:
				if not btn.is_visible_in_tree() or not sr.encloses(btn.get_global_rect()) or btn.text == "":
					bad.append("%s [%s] %s" % [size, btn.text, btn.get_global_rect()])
			_click(st.close_button.get_global_rect().get_center())
			await _frames(2)
			if st.visible:
				bad.append("%s [닫기] 뒤에도 열림" % size)
		root.size = Vector2i(1600, 900)
		await _frames(2)
		_click(m.settings_button.get_global_rect().get_center())
		await _frames(2)
		var texts := _visible_texts(st)
		var heads := ["SETTINGS_GROUP_GAME", "SETTINGS_GROUP_STRIP", "SETTINGS_GROUP_BIG"].map(func(k): return tr(k))
		var rows := ["SETTINGS_LANGUAGE", "SETTINGS_NUMBERS", "SETTINGS_NOTICES", "SETTINGS_RUSH", "SETTINGS_ON_TOP", "SETTINGS_OPACITY",
				"SETTINGS_STRIP_SIZE", "SETTINGS_CORNER", "SETTINGS_MONITOR", "SETTINGS_SCREEN"].map(func(k): return tr(k))
		var all_there: bool = (heads + rows + [tr("SETTINGS_DEFAULTS"), tr("SETTINGS_CLOSE")]).all(func(t): return texts.has(t))
		var odd := texts.filter(func(t): return _untranslated(t, loc == "en"))
		_report(bad.is_empty() and all_there and odd.is_empty() and count >= 25,
				"① %s [설정] 세 묶음 %s, 줄 %d개, 버튼 %d개가 큰 화면 %d가지에서 창 안·[닫기]로 닫힘 %s %s" % [
				loc, heads, rows.size(), count, FIT_SIZES.size(), bad, odd])
		await _close(m)
	TranslationServer.set_locale("ko")


# ---------------- ② 언어 바꾸기 ----------------

func _language() -> void:
	_clean()
	var m := await _launch()
	m.state.money = 12000
	# 물류센터 [기록]·[능력치]를 한국어로 한 번 만들어 둔 뒤 튜닝숍으로
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var p = m.panel
	var d = p.driver
	_click(d.record_page_button.get_global_rect().get_center())
	await _frames(3)
	_click(d.ability_page_button.get_global_rect().get_center())
	await _frames(3)
	var ko_built: bool = not d.record.stat_values.is_empty() and not d._ability_descs.is_empty() and _hangul.search(d._builds.text) != null
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(3)
	var ko_shop: String = p.engine_tab_button.text
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	_click(m.settings.pref_buttons["ui/locale"]["en"].get_global_rect().get_center())
	await _frames(2)

	# 열린 채로: 설정 창, 동네 구석 줄, 튜닝숍 (설정 창 뒤)
	var st = m.settings
	var set_texts := _visible_texts(st)
	var corner := [m.town._star_label.text, m.town._money_label.text, m.town._level_label.text, m.town._quest_label.text, m.town.tuning_button.text]
	var shop := _visible_texts(p)
	var now_ok: bool = TranslationServer.get_locale() == "en" and st.visible and st.pref_buttons["ui/locale"]["en"].button_pressed \
			and st.close_button.text == "Close" and m.settings_button.text == "Settings" and m.town._money_label.text == "₩12K" \
			and p.engine_tab_button.text != ko_shop and p.engine_tab_button.text == tr("GARAGE_TAB_ENGINE")
	var bad := (set_texts + corner + shop).filter(func(t): return _untranslated(t, true))
	_report(ko_built and now_ok and bad.is_empty() and set_texts.size() > 20 and shop.size() > 8,
			"② [설정] [%s] → 그 자리에서 영어: 설정 창 %d개, 동네 구석 줄 %s, 튜닝숍 %d개 글자에 한글·키 없음 %s" % [
			st.pref_buttons["ui/locale"]["en"].text, set_texts.size(), corner, shop.size(), bad])

	# 한국어로 만들어 둔 물류센터 [능력치]·[기록]도 영어로
	_click(st.close_button.get_global_rect().get_center())
	await _frames(2)
	_click(p.building_buttons["depot"].get_global_rect().get_center())
	await _frames(3)
	var depot := _visible_texts(p)
	_click(d.record_page_button.get_global_rect().get_center())
	await _frames(3)
	var record := _visible_texts(p)
	bad = (depot + record).filter(func(t): return _untranslated(t, true))
	_report(bad.is_empty() and depot.size() > 10 and record.size() > 30 and d.ability_page_button.text == tr("DRIVER_PAGE_ABILITY")
			and _hangul.search(d._builds.text) == null,
			"② 한국어로 한 번 연 물류센터 [능력치] %d개·[기록] %d개 글자(통계·도감·업적 줄 다시 만듦)도 영어, 한글·키 없음 %s" % [
			depot.size(), record.size(), bad])
	await _close(m)

	# 다시 켜도 영어 (PC 언어 = 한국어인 것처럼 시작)
	TranslationServer.set_locale("ko")
	m = await _launch()
	m.state.money = 12000
	await _frames(2)
	var kept: bool = TranslationServer.get_locale() == "en" and Prefs.get_value("ui/locale") == "en" and m.town._money_label.text == "₩12K" \
			and _hangul.search(m.town._quest_label.text) == null
	await _go_full(m)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	kept = kept and m.settings_button.text == "Settings" and m.settings.pref_buttons["ui/locale"]["en"].button_pressed
	_click(m.settings.pref_buttons["ui/locale"]["ko"].get_global_rect().get_center())
	await _frames(2)
	var back: bool = TranslationServer.get_locale() == "ko" and m.settings_button.text == "설정" and m.town._money_label.text == "1.2만원" \
			and m.settings.close_button.text == "닫기" and m.panel.engine_tab_button.text == ko_shop
	_report(kept and back, "② 다시 켜도 영어 (구석 '%s'), [%s] → 다시 한국어 ('%s', 튜닝숍 '%s')" % [
			"₩12K" if kept else "?", m.settings.pref_buttons["ui/locale"]["ko"].text, m.settings_button.text, m.panel.engine_tab_button.text])
	await _close(m)


# ---------------- ③ 숫자 표기 ----------------

func _numbers() -> void:
	TranslationServer.set_locale("ko")
	_clean()
	var m := await _launch()
	m.state.money = 12000
	await _go_full(m)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	var st = m.settings
	var want := {
		"ko": { "auto": "1.2만원", "ko": "1.2만원", "en": "12K원" },
		"en": { "auto": "₩12K", "ko": "₩1.2만", "en": "₩12K" },
	}
	var got := []
	var ok: bool = st.pref_buttons["ui/number_style"]["auto"].button_pressed
	for loc: String in want:
		_click(st.pref_buttons["ui/locale"][loc].get_global_rect().get_center())
		await _frames(2)
		for style: String in want[loc]:
			_click(st.pref_buttons["ui/number_style"][style].get_global_rect().get_center())
			await _frames(2)
			var text: String = m.town._money_label.text
			got.append("%s/%s '%s'" % [loc, st.pref_buttons["ui/number_style"][style].text, text])
			ok = ok and text == want[loc][style] and Prefs.get_value("ui/number_style") == style and st.pref_buttons["ui/number_style"][style].button_pressed
	_click(st.pref_buttons["ui/locale"]["ko"].get_global_rect().get_center())
	_click(st.pref_buttons["ui/number_style"]["en"].get_global_rect().get_center())
	await _frames(2)
	await _close(m)
	m = await _launch()
	m.state.money = 12000
	await _frames(2)
	var kept: bool = m.town._money_label.text == "12K원" and Fmt.money(340000000) == "340M"
	_report(ok and kept, "③ 숫자 표기 언어 2 × 3가지 %s, 다시 켜도 K·M ('%s')" % [got, m.town._money_label.text])
	await _close(m)


# ---------------- ④ 알림 끄기 ----------------

func _notices(b: Balance) -> void:
	TranslationServer.set_locale("ko")
	_clean()
	var m := await _launch()
	var s: GameState = m.state
	s.money = Upgrade.price(b, s, "zone") * 2   # 준비: 첫 레벨을 살 수 있게
	var d = await _open_zone(m)
	var before: int = _notice_count(m)
	_click(d.center_buttons["zone"].get_global_rect().get_center())
	await _frames(2)
	var on_shown: bool = _notice_count(m) == before + 1
	# [설정] 알림 [끄기]
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	_click(m.settings.pref_buttons["ui/notices"][false].get_global_rect().get_center())
	await _frames(2)
	_click(m.settings.close_button.get_global_rect().get_center())
	await _frames(2)
	var off_pressed: bool = m.settings.pref_buttons["ui/notices"][false].button_pressed and Prefs.get_value("ui/notices") == false
	var lv: int = Upgrade.level(s, "zone")
	s.money = Upgrade.price(b, s, "zone") * 2   # 준비: 다음 레벨도 살 수 있게
	await _frames(2)
	before = _notice_count(m)
	_click(d.center_buttons["zone"].get_global_rect().get_center())
	await _frames(2)
	var quiet: bool = Upgrade.level(s, "zone") == lv + 1 and _notice_count(m) == before
	await _close(m)

	# 다시 켜도 꺼짐. 작은 화면에서 급송 전화 아이콘·"+금액"은 그대로
	m = await _launch()
	s = m.state
	var kept: bool = Prefs.get_value("ui/notices") == false
	before = _notice_count(m)
	var pays: int = m.town.payouts_shown
	s.rush_enabled = true
	s.rush_next = 0.2
	Engine.time_scale = 1.0
	var rang := false
	for i in 120:
		await process_frame
		if Rush.is_ringing(s) and m.town.rush_button.visible:
			rang = true
			break
	Engine.time_scale = 30.0
	await _wait(2.0)
	Engine.time_scale = 0.0
	var paid: int = m.town.payouts_shown - pays
	m.town.notify("확인용 알림")   # 알림 글을 띄우는 단 한 곳 (main의 모든 알림이 여기로)
	var still_quiet: bool = _notice_count(m) == before and not m.town._notice.visible
	_report(on_shown and off_pressed and quiet and kept and rang and paid > 0 and still_quiet,
			"④ 알림 켜기면 업그레이드 알림 %s → [%s] 뒤 업그레이드해도 알림 글 없음 %s, 다시 켜도 꺼짐 %s, 전화 아이콘 %s·\"+금액\" %d번은 뜸, notify도 안 띄움 %s" % [
			on_shown, m.settings.pref_buttons["ui/notices"][false].text, quiet, kept, rang, paid, still_quiet])
	await _close(m)


func _notice_count(m: Node) -> int:
	return m.town.notices_shown.size() + m.town._notice_queue.size()


## 물류센터 [창고·할 일]에서 업그레이드 "배송 구역 확장" 줄이 보이게 (휠)
func _open_zone(m: Node):
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(3)
	var sc: ScrollContainer = d._depot_scroll
	for i in 40:
		if sc.get_global_rect().encloses(d.center_buttons["zone"].get_global_rect()):
			break
		_wheel(sc.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN)
		await _frames(2)
	return d


# ---------------- ⑧ 틀린 값 ----------------

func _bad_values() -> void:
	_clean()
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "full_style", "windowed")   # 다른 값은 그대로 읽혀야 함
	var bad := { "ui/locale": "fr", "ui/number_style": "xyz", "ui/notices": "yes", "strip/always_on_top": 3, "strip/opacity": 0.33,
			"strip/scale": "big", "strip/corner": "top", "strip/screen": -5 }
	for key: String in bad:
		cfg.set_value(key.get_slice("/", 0), key.get_slice("/", 1), bad[key])
	cfg.save(TEST_SETTINGS)
	Prefs.read_file()
	var wrong := []
	for key: String in Prefs.DEFAULTS:
		if Prefs.get_value(key) != Prefs.DEFAULTS[key] or typeof(Prefs.get_value(key)) != typeof(Prefs.DEFAULTS[key]):
			wrong.append("%s=%s" % [key, Prefs.get_value(key)])
	var refused: bool = not Prefs.set_value("strip/opacity", 0.6) and not Prefs.set_value("ui/locale", "ja") and Prefs.get_value("strip/opacity") == 1.0
	TranslationServer.set_locale("ko")
	var m := await _launch()
	m.state.money = 12000
	await _frames(2)
	var game_ok: bool = TranslationServer.get_locale() == "ko" and m.town._money_label.text == "1.2만원" and m.screen.full_style == ScreenMode.FullStyle.WINDOWED
	await _close(m)

	# 맞는 값은 그대로 (소수 0.85·1.25, 모니터 3)
	_clean()
	var good := { "ui/locale": "en", "ui/number_style": "ko", "ui/notices": false, "strip/always_on_top": false, "strip/opacity": 0.85,
			"strip/scale": 1.25, "strip/corner": "left", "strip/screen": 3 }
	for key: String in good:
		Prefs.set_value(key, good[key])
	Prefs.read_file()
	var lost := []
	for key: String in good:
		if Prefs.get_value(key) != good[key]:
			lost.append("%s=%s" % [key, Prefs.get_value(key)])
	_report(wrong.is_empty() and refused and game_ok and lost.is_empty(),
			"⑧ 손으로 고친 틀린 값 %d개 → 전부 기본값 %s, 고를 수 없는 값은 안 들어감, 게임은 기본값으로 뜸 (큰 화면 방식은 그대로), 맞는 값 %d개는 다시 읽어도 같음 %s" % [
			bad.size(), wrong, good.size(), lost])
	_clean()


# ---------------- ⑨ [기본값으로] ----------------

func _defaults() -> void:
	TranslationServer.set_locale("ko")
	_clean()
	var m := await _launch()
	var s: GameState = m.state
	s.money = 12345
	await _go_full(m)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	var st = m.settings
	var picks := [["ui/locale", "en"], ["ui/number_style", "en"], ["ui/notices", false], ["strip/always_on_top", false], ["strip/opacity", 0.7],
			["strip/scale", 1.5], ["strip/corner", "left"], ["strip/screen", 0]]
	for pk: Array in picks:
		if not st.pref_buttons[pk[0]].has(pk[1]):   # 화면 없는 실행은 모니터가 0개라 [1] 버튼이 없음 → 값만
			Prefs.set_value(pk[0], pk[1])
			continue
		_click(st.pref_buttons[pk[0]][pk[1]].get_global_rect().get_center())
		await _frames(2)
	_click(st.windowed_button.get_global_rect().get_center())
	await _frames(2)
	_click(st.rush_off_button.get_global_rect().get_center())
	await _frames(2)
	var changed := []
	for pk: Array in picks:
		if Prefs.get_value(pk[0]) != pk[1]:
			changed.append(pk[0])
	var set_ok: bool = changed.is_empty() and TranslationServer.get_locale() == "en" and m.screen.full_style == ScreenMode.FullStyle.WINDOWED and not s.rush_enabled

	_click(st.defaults_button.get_global_rect().get_center())
	await _frames(3)
	var cfg := ConfigFile.new()
	cfg.load(TEST_SETTINGS)
	var left_in_file := []
	var not_default := []
	for key: String in Prefs.DEFAULTS:
		if cfg.has_section_key(key.get_slice("/", 0), key.get_slice("/", 1)):
			left_in_file.append(key)
		if Prefs.get_value(key) != Prefs.DEFAULTS[key]:
			not_default.append(key)
	var shown := []
	for key: String in st.pref_buttons:
		var want: Variant = Prefs.DEFAULTS[key]
		if key == "ui/locale":
			want = Prefs.locale()
		for v: Variant in st.pref_buttons[key]:
			if st.pref_buttons[key][v].button_pressed != (v == want):
				shown.append("%s %s" % [key, v])
	var others: bool = TranslationServer.get_locale() == Prefs.locale() and m.screen.full_style == ScreenMode.FullStyle.FULLSCREEN \
			and st.fullscreen_button.button_pressed and st.visible and not s.rush_enabled and st.rush_off_button.button_pressed and s.money == 12345 \
			and ScreenMode.load_value("first_run", "building_hint_seen", false) == true and m.settings_button.text == tr("SETTINGS")
	_report(set_ok and left_in_file.is_empty() and not_default.is_empty() and shown.is_empty() and others,
			"⑨ 8가지 + 창 모드를 바꾼 뒤 [%s] → 설정 파일 [ui]·[strip] 비움 %s, 전부 기본값 %s·눌린 모양 %s, 언어 = PC 언어(%s), 전체 화면, 급송 전화 꺼짐·돈·처음 말풍선 기록은 그대로" % [
			st.defaults_button.text, left_in_file, not_default, shown, Prefs.locale()])
	await _close(m)


# ---------------- ⑤⑩ 띠 사각형 (순수 함수) ----------------

func _strip_rects() -> void:
	# 가짜 모니터 두 개: 주 모니터(아래 작업표시줄 40) + 왼쪽 위로 비켜 놓인 큰 모니터(아래 작업표시줄 48)
	var screens := [
		[Rect2i(0, 0, 1920, 1080), Rect2i(0, 0, 1920, 1040)],
		[Rect2i(-2560, -300, 2560, 1440), Rect2i(-2560, -300, 2560, 1392)],
	]
	var bad := []
	var n := 0
	for sc: Array in screens:
		var usable: Rect2i = sc[1]
		for scale: float in Prefs.CHOICES["strip/scale"]:
			for corner: String in Prefs.CHOICES["strip/corner"]:
				n += 1
				var r := DesktopWindow.strip_rect(sc[0], usable, scale, corner)
				var size := Vector2i((Vector2(Feel.SMALL_SIZE) * scale).round())
				var at_corner := r.position.x == usable.position.x if corner == "left" else r.end.x == usable.end.x
				if r.size != size or not usable.encloses(r) or r.end.y != usable.end.y or not at_corner:
					bad.append("%s ×%s %s → %s" % [usable, scale, corner, r])
	var a: Array = screens[0]
	var old := Rect2i(a[1].end - Feel.SMALL_SIZE, Feel.SMALL_SIZE)   # v8a small_rect 식
	var same: bool = DesktopWindow.strip_rect(a[0], a[1], Prefs.DEFAULTS["strip/scale"], Prefs.DEFAULTS["strip/corner"]) == old
	# 쓸 수 있는 영역이 모니터 밖으로 오면 모니터 안에
	var odd := DesktopWindow.strip_rect(Rect2i(0, 0, 1920, 1080), Rect2i(5000, 0, 100, 100), 1.0, "right")
	_report(bad.is_empty() and n == 12 and odd == Rect2i(1440, 860, 480, 220),
			"⑤ 띠 사각형 %d가지 (크기 3 × 자리 2 × 모니터 2): 크기 = 480x220 × 배율, 쓸 수 있는 영역 안, 아래 끝 = 작업표시줄 위, 고른 구석 %s" % [n, bad])
	_clean()
	_report(same and DesktopWindow.strip_size(Prefs.get_value("strip/scale")) == Feel.SMALL_SIZE and Prefs.get_value("strip/always_on_top") == true
			and Prefs.get_value("strip/opacity") == 1.0,
			"⑩ 기본값: 띠 자리 = v8a 식 %s (주 모니터 오른쪽 아래 480x220), 항상 위 켜기, 투명도 100%%" % old)


# ---------------- ⑥ 띠 크기·투명도 ----------------

func _strip_sizes() -> void:
	TranslationServer.set_locale("ko")
	_clean()
	var m := await _launch_strip()
	var lines := []
	var bad := []
	for scale: float in Prefs.CHOICES["strip/scale"]:
		await _go_full(m)
		_click(m.settings_button.get_global_rect().get_center())
		await _frames(2)
		_click(m.settings.pref_buttons["strip/scale"][scale].get_global_rect().get_center())
		await _frames(2)
		_click(m.small_button.get_global_rect().get_center())
		await _frames(3)
		var view: Vector2 = m.get_viewport_rect().size
		var win := Rect2(Vector2.ZERO, view)
		var rects: Array = m.visible_rects()
		var poly := ClickRegion.build(rects, view.y)
		var outside := rects.filter(func(r: Rect2): return not win.encloses(r))
		var town = m.town
		var zoom_ok: bool = is_equal_approx(town.zoom, scale) and Vector2i(view) == DesktopWindow.strip_size(scale)
		var spots := {}
		for id: String in town.building_rects():
			var spot := _town_spot(id)
			var drawn := Rect2(town.global_position + town.origin + spot.position * scale, spot.size * scale)
			var got: Rect2 = town.building_rects()[id]
			got.position += town.global_position
			spots[id] = got
			if not got.is_equal_approx(drawn) or not _covered(rects, got) or not ClickRegion.contains_even_odd(poly, got.get_center()):
				bad.append("×%s %s 그림 %s / 클릭 %s" % [scale, id, drawn, got])
		var hud := Rect2(town._money_label.global_position, town._money_label.size)
		if not _covered(rects, hud):
			bad.append("×%s 구석 줄 %s" % [scale, hud])
		lines.append("×%s 창 %s 동네 배수 %s 사각형 %d개(창 밖 %d)" % [scale, Vector2i(view), Fmt.num(town.zoom), rects.size(), outside.size()])
		# 빈 곳(동네 위쪽 가운데 하늘)은 눌러도 그대로, 건물은 그 건물 화면
		_click(Vector2(view.x * 0.6, view.y * 0.05))
		await _frames(2)
		var stays: bool = not m.is_full()
		_click(spots["car_center"].get_center())
		await _frames(3)
		var opens: bool = m.is_full() and m.panel.building == "car_center"
		if not (stays and opens):
			bad.append("×%s 빈 곳 그대로 %s / 카센터 클릭 → %s" % [scale, stays, m.panel.building])
		if not zoom_ok or not outside.is_empty():
			bad.append("×%s 창·배수 %s" % [scale, Vector2i(view)])
	_report(bad.is_empty(), "⑥ [설정] 띠 크기 3가지 → [작게]: %s, 건물·구석 줄이 보이는 곳 안, 건물 클릭 자리 = 그림 자리, 빈 곳은 그대로·카센터는 열림 %s" % [lines, bad])

	# 투명도: 띠만 (큰 화면은 100%)
	var got := []
	var ok := true
	for op: float in Prefs.CHOICES["strip/opacity"]:
		_click(m.settings_button.get_global_rect().get_center())
		await _frames(2)
		_click(m.settings.pref_buttons["strip/opacity"][op].get_global_rect().get_center())
		await _frames(2)
		var full_a: float = m.modulate.a
		_click(m.small_button.get_global_rect().get_center())
		await _frames(2)
		got.append("%s → 띠 %s" % [m.settings.pref_buttons["strip/opacity"][op].text, Fmt.num(m.modulate.a)])
		ok = ok and is_equal_approx(m.modulate.a, op) and full_a == 1.0
		await _go_full(m)
	_report(ok, "⑥ [설정] 투명도 %s, 큰 화면은 늘 100%%" % [got])
	await _close(m)


## 동네 설계 좌표의 건물 자리
func _town_spot(id: String) -> Rect2:
	return { "tuning": Feel.TOWN_TUNING_RECT, "depot": Feel.TOWN_DEPOT_RECT, "car_center": Feel.TOWN_CAR_CENTER_RECT, "office": Feel.TOWN_OFFICE_RECT }[id]


## r이 보이는 곳 사각형 하나 안에 다 들어가나 (1픽셀 여유)
func _covered(rects: Array, r: Rect2) -> bool:
	return rects.any(func(v: Rect2): return v.grow(1.0).encloses(r))


# ---------------- ⑦ 뽑힌 모니터 ----------------

func _unplugged() -> void:
	var cases := [[5, 2, 0, 0], [1, 2, 0, 1], [-1, 3, 1, 1], [2, 2, 1, 1], [0, 1, 0, 0], [3, 0, 0, 0]]
	var bad := cases.filter(func(c): return DesktopWindow.pick_screen(c[0], c[1], c[2]) != c[3])
	_clean()
	Prefs.set_value("strip/screen", 5)   # 모니터 6을 골라 둔 채 뽑힘
	Prefs.read_file()
	var kept: bool = Prefs.get_value("strip/screen") == 5 and DesktopWindow.screen_index() == DisplayServer.get_primary_screen()
	TranslationServer.set_locale("ko")
	var m := await _launch()
	await _go_full(m)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	var shown: bool = m.settings.pref_buttons["strip/screen"][-1].button_pressed and Prefs.get_value("strip/screen") == 5
	_report(bad.is_empty() and kept and shown,
			"⑦ 고른 모니터가 없으면 주 모니터 (pick_screen %d가지 %s), 설정값 5는 남고 [설정]에는 [%s]가 눌린 모양" % [
			cases.size(), bad, m.settings.pref_buttons["strip/screen"][-1].text])
	await _close(m)


# ---------------- 도우미 ----------------

## 띠 크기 설정대로 창 크기를 바꾸는 _launch (진짜 창에서 DesktopWindow가 하는 일을 화면 없이 흉내)
func _launch_strip() -> Node:
	var m := await _launch()
	m.screen.mode_changed.connect(func(mode):
		if mode == ScreenMode.Mode.SMALL:
			root.size = DesktopWindow.strip_size(Prefs.get_value("strip/scale")))
	return m



## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤, 급송 벨 끔). 저장·설정은 지금 있는 시험 파일 그대로
func _launch() -> Node:
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


## 띠의 튜닝숍 클릭 → 큰 화면
func _go_full(m: Node) -> void:
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)


func _close(m: Node) -> void:
	root.remove_child(m)
	m.queue_free()
	await process_frame


## 시험 저장·설정 파일 지우고 Prefs도 기본값으로
func _clean() -> void:
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Prefs.read_file()


func _read_csv_keys() -> void:
	var f := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	while f != null and not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() > 0 and row[0] != "":
			_csv_keys[row[0]] = true


## 번역 안 된 글자: 키 그대로, 영어 화면인데 한글
func _untranslated(t: String, en: bool) -> bool:
	return _csv_keys.has(t) or (en and _hangul.search(t) != null)


## n 아래 보이는 Label·Button 글자 전부
func _visible_texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree() and c.text != "":
			out.append(c.text)
	return out


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)


func _wheel(pos: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.factor = 1.0
		e.position = pos
		e.global_position = pos
		root.push_input(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _report(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails.append(text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])
