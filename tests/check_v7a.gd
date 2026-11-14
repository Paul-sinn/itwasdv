## v7a U1 완료 기준 자동 확인: 대리점 창업 줄, 튜닝숍 트럭 탭, 타이어·휠, 띠의 보조 트럭, 꺼둔 동안 직원 몫·세금 줄.
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 돈·단계·보조 트럭을 미리 넣는 것은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 모든 트럭을 Trip.advance)으로 한다.
## ① 창업 줄: 돈이 모자라면 [창업] 꺼짐 + 모자란 금액, 두 번 눌러야 창업 (3초 지나면 다시 처음부터), 창업 뒤 "대리점 (시내)"·알림·저장
## ② 트럭 1대면 탭 없음, 2대면 탭 2개, 탭을 누르면 그 트럭의 단계·세팅이 보이고 [강화]·[돌리기]가 그 트럭에 들어감
## ③ 타이어·휠: 창업 전 꺼짐 + "대리점을 차리면 열려요", 창업 뒤 [돌리기]로 돌려짐
## ④ 띠에 트럭 수만큼 그려지고 visible_rects() 안, 보조 트럭 "+금액" = 이벤트 pay (번 돈 − 직원 몫 − 세금), "+금액"·팁 합 = 늘어난 돈
## ⑤ 꺼둔 동안 요약: 대리점이면 "직원 몫 −N원 · 세금 −N원" (= Trip.apply_offline 결과), 개인 기사면 그 줄 없음, 작은 화면 안
## ⑥ en: 위 글자들에 한글·키 없음
## ⑦ 창 크기: 큰 화면 5가지에서 물류센터 [창고·할 일](창업 전·뒤), 튜닝숍 트럭 탭 + [엔진 강화](가장 길 때)·[세팅](고르는 화면)이
##    창 안, 동네·[작게]·[설정]과 안 겹침 / 작은 화면 3가지에서 트럭 3대가 보이는 곳 안, 글자 10개 떠도 사각형 30개 이하
## 현지 시각은 main.now_local_override로 고정 (2026-11-18 수요일 낮 12시). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v7a.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_v7a.json"
const TEST_SETTINGS := "user://test_v7a_settings.cfg"
const HOUR := 3600
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
	var price := Company.agency_price(b)

	# ① 창업 줄: 돈 모자람 → 꺼짐 + 모자란 금액 / 돈 있음 → 한 번 누르면 "한 번 더", 3초 지나면 처음으로, 두 번 → 창업
	var m := await _launch(b)
	var p = m.panel
	var d = p.driver
	m.state.money = price - 1000
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(2)
	var short_text: String = d._agency.text
	_click(d.found_button.get_global_rect().get_center())
	await _frames(2)
	var short_ok: bool = d._agency.is_visible_in_tree() and d.found_button.is_visible_in_tree() and d.found_button.disabled \
			and short_text == "대리점 창업 %s원 · %s원 모자람" % [Fmt.money(price), Fmt.money(1000)] and Company.stage(m.state) == 0
	m.state.money = price + 12345   # 준비: 돈이 모임
	await _frames(2)
	_click(d.found_button.get_global_rect().get_center())
	await _frames(2)
	var armed_text: String = d.found_button.text
	var armed_ok: bool = not d.found_button.disabled and d.is_found_armed() and armed_text == "한 번 더 누르면 창업" and Company.stage(m.state) == 0
	await _wait(Feel.AGENCY_FOUND_ARM_SECONDS + 0.3)   # 시간이 지나면 처음으로 (한 번 눌러서는 창업 안 됨)
	await _frames(2)
	var expired_ok: bool = not d.is_found_armed() and d.found_button.text == "창업"
	_click(d.found_button.get_global_rect().get_center())
	await _frames(2)
	expired_ok = expired_ok and Company.stage(m.state) == 0
	_click(d.found_button.get_global_rect().get_center())
	await _frames(3)
	var saved = _saved_state(b)
	var founded_ok: bool = Company.stage(m.state) == 1 and m.state.money == 12345 and d._agency.text == "대리점 (시내)" \
			and not d.found_button.is_visible_in_tree() and _noticed(m.town, "대리점을 차렸어요! 보조 트럭·타이어·휠이 열렸어요") \
			and saved != null and saved.company_stage == 1 and saved.money == 12345
	_report(short_ok and armed_ok and expired_ok and founded_ok,
			"① 창업 줄: 모자라면 '%s' [창업] 꺼짐 → 돈이 되면 한 번 누름 '%s', %.0f초 지나면 '창업'으로, 두 번 → 대리점·돈 −%s원, '%s', 알림, 저장(단계 %s)" % [
			short_text, armed_text, Feel.AGENCY_FOUND_ARM_SECONDS, Fmt.money(price), d._agency.text, saved.company_stage if saved != null else "없음"])

	# ② 트럭 탭: 1대면 없음 → 보조 트럭 1대 (준비) → 탭 2개 → [2호차] 누르면 그 트럭 단계·세팅, [강화]·[돌리기]가 그 트럭에
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	_click(p.engine_tab_button.get_global_rect().get_center())
	await _frames(2)
	var one_ok: bool = not p._truck_row.is_visible_in_tree()
	m.state.money = Company.helper_price(b, m.state)
	Company.buy_helper(b, m.state)   # 준비 (사는 화면은 U2)
	var t0 = m.state.truck(0)
	var t1 = m.state.truck(1)
	t0.star = 7
	t1.star = 3
	t0.part("cargo_box")["grade"] = 2
	t0.part("cargo_box")["lines"] = ["speed", "speed"]
	m.state.money = 50000000
	await _frames(3)
	var tabs := _shown_buttons(p.truck_buttons)
	var two_ok: bool = p._truck_row.is_visible_in_tree() and tabs == ["내 트럭", "2호차"] and p.truck_buttons[0].button_pressed \
			and p._title.text == "엔진 +7"
	_click(p.truck_buttons[1].get_global_rect().get_center())
	await _frames(2)
	var title1: String = p._title.text
	var hourly_ok: bool = p._income.text.begins_with("시간당 %s원" % Fmt.money(int(Trip.hourly_income(b, m.state, 1))))
	var money0: int = m.state.money
	var cost1 := Economy.enhance_cost(b, 3, m.state)
	m.suspense_scale = 0.01
	_click(p._enhance_button.get_global_rect().get_center())
	await _until(func(): return not m.enhancing, 5.0)
	await _frames(2)
	var pressed1: int = t1.success_count + t1.fail_count + t1.destroy_count
	var pressed0: int = t0.success_count + t0.fail_count + t0.destroy_count
	var enhance_ok: bool = title1 == "엔진 +3" and pressed1 == 1 and pressed0 == 0 and t0.star == 7 and m.state.money == money0 - cost1
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(2)
	var st = p.setting
	var grade1_text: String = st._grade.text
	_click(st.part_buttons["cargo_box"].get_global_rect().get_center())
	await _frames(1)
	_click(st.roll_button.get_global_rect().get_center())
	await _until(func(): return not m.rolling, 5.0)
	await _frames(2)
	var roll_ok: bool = st.truck == 1 and grade1_text == "적재함 · %s" % st.grade_name(0) and t1.part("cargo_box")["pending"] != null \
			and t0.part("cargo_box")["pending"] == null and st._choose.is_visible_in_tree()
	_click(p.truck_buttons[0].get_global_rect().get_center())
	await _frames(2)
	var back_ok: bool = st._grade.text == "적재함 · %s" % st.grade_name(2) and not st._choose.visible
	_report(one_ok and two_ok and hourly_ok and enhance_ok and roll_ok and back_ok,
			"② 트럭 1대: 탭 없음 / 2대: 탭 %s, [2호차] → '%s'·시간당 그 트럭, [강화] → 2호차만 누른 횟수 1 (내 트럭 0, +7 그대로)·돈 −%s원, [세팅] '%s' [돌리기] → 2호차만 고르는 화면, [내 트럭] → '%s'" % [
			tabs, title1, Fmt.money(cost1), grade1_text, st._grade.text])
	await _close(m)

	# ③ 타이어·휠: 창업 전 꺼짐 + 잠김 글 → 창업(준비) 뒤 켜지고 [돌리기]로 돌려짐
	Save.delete_file(TEST_SAVE)
	m = await _launch(b)
	p = m.panel
	st = p.setting
	m.state.money = price + 50000000
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(2)
	var tire: Button = st.part_buttons["tire"]
	var lock_text: String = st._lock_note.text
	var locked_ok: bool = tire.disabled and tire.text == "타이어·휠" and st._lock_note.is_visible_in_tree() \
			and lock_text == "타이어·휠 · 대리점을 차리면 열려요"
	Company.found(b, m.state)   # 준비 (창업 클릭은 ①)
	await _frames(2)
	var open_ok: bool = not tire.disabled and not st._lock_note.visible
	_click(tire.get_global_rect().get_center())
	await _frames(1)
	var tire_grade: String = st._grade.text
	_click(st.roll_button.get_global_rect().get_center())
	await _until(func(): return not m.rolling, 5.0)
	await _frames(2)
	var tp = m.state.truck(0).part("tire")
	var rolled_ok: bool = st.selected == "tire" and tire_grade.begins_with("타이어·휠 · ") and tp["pending"] != null \
			and _saved_state(b) != null and _saved_state(b).truck(0).part("tire")["pending"] != null
	_report(locked_ok and open_ok and rolled_ok,
			"③ 타이어·휠: 창업 전 버튼 '%s' 꺼짐 + '%s' / 창업 뒤 켜짐, '%s' [돌리기] → 고르는 화면 (새 등급 %s), 저장" % [
			tire.text, lock_text, tire_grade, st.grade_name(tp["pending"]["grade"]) if tp["pending"] != null else "없음"])
	await _close(m)

	# ④ 띠: 트럭 3대 (준비: 창업 + 보조 트럭 2대) → 3대 그려짐, 보이는 곳 안. 빨리 돌려서 보조 트럭 "+금액" = 떼고 난 금액
	Save.delete_file(TEST_SAVE)
	m = await _launch(b)
	var town = m.town
	_agency_with_helpers(b, m.state, 2)
	m.state.quest_index = Quest.count(b)   # 할 일 보상 돈이 안 끼게
	m.state.rush_enabled = false
	await _frames(3)
	var drawn_ok: bool = town.trucks.size() == 3 and m.state.trucks.size() == 3
	var colors := {}
	for tk in town.trucks:
		drawn_ok = drawn_ok and tk.is_visible_in_tree() and tk.get_parent() == town
		colors[tk.box_color] = true
	var money_before: int = m.state.money
	var tips_before: int = m.tips_total
	var log_before: int = town.payout_log.size()
	var inside_ok := true
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 6000:
		await process_frame
		var rects: Array = m.visible_rects()
		for tk in town.trucks:
			var r: Rect2 = tk.click_rect()
			inside_ok = inside_ok and _enclosed(rects, Rect2(r.position + town.global_position, r.size).intersection(Rect2(Vector2.ZERO, Vector2(root.size))))
	Engine.time_scale = 0.0
	await _frames(1)
	var got := 0
	var per_truck := [0, 0, 0]
	var helper_ok := true
	var helper_amounts := {}
	for e: Array in town.payout_log.slice(log_before):
		got += e[1]
		per_truck[e[0]] += 1
		if e[0] > 0:   # 보조 트럭 +0: 보통 배송만 (대형·VIP는 +15부터), 팁 없음 (능력치는 내 트럭만)
			var gross := Trip.parcel_pay(b, m.state, e[0])
			var net: int = Trip._split(b, m.state, e[0], gross)[2]
			helper_ok = helper_ok and e[1] == net and net < gross
			helper_amounts[e[1]] = true
	var money_ok: bool = m.state.money - money_before == got + (m.tips_total - tips_before)
	_report(drawn_ok and colors.size() == 3 and inside_ok and helper_ok and money_ok and per_truck[1] > 0 and per_truck[2] > 0,
			"④ 띠에 트럭 %d대 (짐칸 색 %d가지), 달리는 동안 전부 작은 화면 보이는 곳 안, '+금액' 트럭별 %s건, 보조 트럭 '+금액' %s = 번 돈 %s − 직원 몫 − 세금, '+금액'·팁 합 %s = 늘어난 돈 %s" % [
			town.trucks.size(), colors.size(), per_truck, helper_amounts.keys(), Fmt.money(Trip.parcel_pay(b, m.state, 1)),
			Fmt.money(got + m.tips_total - tips_before), Fmt.money(m.state.money - money_before)])
	await _close(m)

	# ⑤ 꺼둔 동안 요약: 대리점(보조 트럭 2대, 노하우 경험치 줄도 있는 가장 긴 때) → 직원 몫·세금 줄 / 개인 기사 → 그 줄 없음
	var away_lines := []
	var fails_before := fails.size()
	for agency in [true, false]:
		var s := GameState.new_game()
		if agency:
			_agency_with_helpers(b, s, 2)
		s.abilities["knowhow"] = 3   # 노하우 경험치 줄도 나오게 (가장 긴 요약)
		s.ability_points = 3
		s.quest_index = Quest.count(b)
		Save.write_file(TEST_SAVE, s, int(Time.get_unix_time_from_system()) - 20 * HOUR)
		m = await _launch(b, false)
		var r: Dictionary = m.offline_report
		var note: String = m.popup.note_text()
		var line := "직원 몫 −%s원 · 세금 −%s원" % [Fmt.money(r.get("staff", -1)), Fmt.money(r.get("tax", -1))]
		var fits: bool = m.popup.visible and Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()) \
				and _enclosed(m.visible_rects(), m.popup.get_global_rect())
		if agency:
			away_lines.append(note.split("\n"))
			_check(fits and note.contains(line) and r["staff"] > 0 and r["tax"] > 0 and r["xp"] > 0, "대리점 요약 '%s' (기대 '%s')" % [note, line])
		else:
			_check(fits and not note.contains("직원 몫") and not note.contains("세금"), "개인 기사 요약에 직원 몫·세금 줄: '%s'" % note)
		await _close(m)
	_report(fails.size() == fails_before,
			"⑤ 꺼둔 동안 요약: 대리점(보조 트럭 2대) '%s' = apply_offline staff·tax, 작은 화면 안 / 개인 기사는 그 줄 없음" % [away_lines])

	# ⑥ en: 창업 줄(모자람·한 번 더·창업 뒤), 트럭 탭, 타이어 잠김 글, 창업 알림, 꺼둔 동안 줄
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	m = await _launch(b)
	p = m.panel
	d = p.driver
	var texts := []
	m.state.money = price - 1000
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(d._agency.text)
	m.state.money = price + 50000000
	await _frames(2)
	_click(d.found_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(d.found_button.text)
	_click(d.found_button.get_global_rect().get_center())
	await _frames(3)
	texts.append(d._agency.text)
	texts.append_array(m.town.notices_shown + m.town._notice_queue)
	m.state.company_stage = 0   # 준비: 잠김 글을 보려고 잠깐 개인 기사로
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(2)
	texts.append(p.setting._lock_note.text)
	texts.append(p.setting.part_buttons["tire"].text)
	m.state.company_stage = 1
	Company.buy_helper(b, m.state)
	Company.buy_helper(b, m.state)
	await _frames(3)
	texts.append_array(_shown_buttons(p.truck_buttons))
	await _close(m)
	var s_en := GameState.new_game()
	_agency_with_helpers(b, s_en, 1)
	Save.write_file(TEST_SAVE, s_en, int(Time.get_unix_time_from_system()) - 3 * HOUR)
	m = await _launch(b, false)
	var en_note: String = m.popup.note_text()
	texts.append_array(en_note.split("\n"))
	await _close(m)
	var bad := texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and texts.has("Agency (City)") and texts.has("Truck 2") and texts.has("Truck 3") and en_note.contains("Staff share"),
			"⑥ en 창업 줄·트럭 탭·타이어 잠김·알림·꺼둔 동안 줄 %d개에 한글·키 없음 %s" % [texts.size(), bad])
	print("    en: %s" % [texts])

	# ⑦ 창 크기: ko·en
	var fit := {}
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		Save.delete_file(TEST_SAVE)
		m = await _launch(b)
		fit[loc] = await _check_fits(m, b)
		await _close(m)
	TranslationServer.set_locale("ko")
	_report(fit["ko"].is_empty() and fit["en"].is_empty(),
			"⑦ ko·en 큰 화면 %d가지: 물류센터 [창고·할 일](창업 전 모자람·뒤), 튜닝숍 트럭 탭 3개 + [엔진 강화](명장 방문·퍼짐·스페어 없음·결과 두 줄)·[세팅](고르는 화면)이 창 안, 동네·[작게]·[설정]과 안 겹침 / 작은 화면 %d가지: 트럭 3대가 동네 안·보이는 곳 안, 글자 10개에도 사각형 30개 이하 %s %s" % [
			FIT_SIZES.size(), SMALL_SIZES.size(), fit["ko"], fit["en"]])

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## ⑦: 큰 화면 5가지 (물류센터 창업 전·뒤, 튜닝숍 트럭 탭 + [엔진 강화]·[세팅]) + 작은 화면 3가지 (트럭 3대). 문제 목록
func _check_fits(m: Node, b: Balance) -> Array:
	var p = m.panel
	var d = p.driver
	var town = m.town
	var s: GameState = m.state
	var bad := []
	s.quest_index = 0
	s.money = Company.agency_price(b) / 3   # 창업 줄 모자란 금액, 창고·야간팀도 모자람 (가장 길 때)
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	for phase in ["창업 전", "창업 뒤"]:
		if phase == "창업 뒤":
			_agency_with_helpers(b, s, 2)
			s.money = 0
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			_click(d.depot_page_button.get_global_rect().get_center())
			await _frames(3)
			_fit(m, bad, "물류센터 %s" % phase, size, d._agency.is_visible_in_tree() and d._weekly.is_visible_in_tree())
	# 튜닝숍: 3호차 +18 스페어 없음, 명장 방문 중, 결과 두 줄 / [세팅] 3호차 타이어 고르는 화면 (가장 긴 줄)
	s.truck(0).star = b.master_unlock_star
	await _frames(2)
	Master.set_day(s, Master.weekday(now), now)
	m._want_day_picker = false
	m.day_picker.visible = false
	var t2 = s.truck(2)
	t2.star = 18
	s.spares = 0
	s.money = Economy.enhance_cost(b, 18, s) * 3
	var tp: Dictionary = t2.part("tire")
	tp["grade"] = 3
	tp["lines"] = ["junk_scent", "junk_radio", "maint_cut"]
	tp["pending"] = { "grade": 4, "lines": ["junk_scent", "junk_radio", "junk_cupholder"] }
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	_click(p.truck_buttons[2].get_global_rect().get_center())
	await _frames(2)
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(p.engine_tab_button.get_global_rect().get_center())
		p.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, tr("RESULT_DESTROY_NOTE") % [b.broken_drop_to, 0])   # 준비: 결과 두 줄
		await _frames(3)
		_fit(m, bad, "강화 칸", size, p._truck_row.is_visible_in_tree() and p._master_line.is_visible_in_tree() and p._danger_note.visible \
				and p._wait.visible and p.to_car_button.visible and p._title.text == tr("GARAGE_TITLE") % 18)
		_click(p.setting_tab_button.get_global_rect().get_center())
		await _frames(1)
		_click(p.setting.part_buttons["tire"].get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "세팅 칸", size, p._truck_row.is_visible_in_tree() and p.setting._choose.is_visible_in_tree())
	# 작은 화면: 트럭 3대 + 글자 10개
	m.screen.enter_small()
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		for i in 10:
			town.show_payout(i % Feel.TOWN_HOUSES, 1875 * (i + 1), ["normal", "large", "vip"][i % 3], i % 2 == 0, i % 3)
		await _frames(1)
		var rects: Array = m.visible_rects()
		for tk in town.trucks:
			var r: Rect2 = tk.click_rect()
			if not town.area().grow(Feel.TRUCK_CLICK_PADDING + 1.0).encloses(r) or not _enclosed(rects, Rect2(r.position + town.global_position, r.size).intersection(Rect2(Vector2.ZERO, Vector2(size)))):
				bad.append("%s 트럭 %s 동네 밖이거나 보이는 곳 밖" % [size, r])
		if town.trucks.size() != 3:
			bad.append("%s 트럭 %d대" % [size, town.trucks.size()])
		if rects.size() > 30:
			bad.append("%s 트럭 3대 + 글자 10개: 보이는 곳 사각형 %d개 (30개 이하)" % [size, rects.size()])
	root.size = Vector2i(1600, 900)
	await _frames(2)
	return bad


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


## 보이는 버튼 글자들
func _shown_buttons(buttons: Array) -> Array:
	var out := []
	for btn: Button in buttons:
		if btn.is_visible_in_tree():
			out.append(btn.text)
	return out


## 동네 알림에 text가 떴거나 차례를 기다리나
func _noticed(town: Node, text: String) -> bool:
	return town.notices_shown.has(text) or town._notice_queue.has(text)


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["AGENCY_", "TRUCK_", "SETTING_", "NOTICE_", "RETURN_", "DEPOT_", "QUEST_", "GARAGE_"]:
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


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤). fresh = 새 게임이라 급송 벨을 끔 (저장을 읽어 켤 때는 false)
func _launch(b: Balance, fresh := true) -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	m.now_local_override = now
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	if fresh:
		m.state.rush_enabled = false   # 벨이 난수·말풍선을 끼우지 않게
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
