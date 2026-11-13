## v5 U1 완료 기준 자동 확인: 기사 레벨·다음 할 일·창고 확장·야간 배송팀·돌아왔을 때 요약.
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 상태를 미리 만들어 두는 것(할 일 차례, 레벨 등)은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 Trip.advance → Quest.check → take_events)으로 한다.
## ① 작은 화면 "Lv.N" + 다음 할 일 한 줄 (이름 + 진행 "3/20")
## ② 차고 [기사·물류센터]: 레벨, 경험치 막대(driver_xp / xp_need), 포인트, 지금 할 일(이름·설명·진행·보상), 끝낸 수 n/22
## ③ 할 일 끝 → 알림(이름 + 보상), 돈 + 보상, 다음 할 일로   ④ 레벨업 알림("Lv.N" + 포인트), 만렙 알림
## ⑤ 창고·야간팀: 지금 값 → 다음 값, 가격, 사면 돈 −가격·레벨 +1, 돈 모자라면 버튼 꺼짐 + 모자란 금액, 창고 Lv3 "대리점부터"
## ⑥ 올리기·강화·세팅 직후 Quest.check (main의 프레임을 멈춰도 바로 다음 할 일로)
## ⑦ 돌아왔을 때 요약: 3시간 / 20시간(창고 꽉 참) / 179초(창 안 뜸) / 시계가 거꾸로(0원 안내)
## ⑧ 다 끝나면 "다음 할 일 없음"   ⑨ 산 직후 저장   ⑩ en: 칸이 뜨고 키·한글 없음 (할 일 22개 이름·설명 포함)
## ⑪ 알림이 여러 개 겹치면 하나씩 차례로 (작은 화면 보이는 곳 안)
## 확인하는 동안 게임 시간을 멈춘다 (배송 돈이 섞이지 않게. 알림·뜸은 진짜 시간이라 그대로 지나감).
## 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_driver.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_town_driver.json"
const TEST_SETTINGS := "user://test_driver_settings.cfg"
const SEED := 20261113   ## 강화·돌리기 결과 고정 (⑥에서 +0 → +1 성공이 나오게)
const RICH := 1000000000
const HOUR := 3600

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
	Save.delete_file(TEST_SAVE)
	var b := Balance.load_file()

	# ① 작은 화면: "Lv.N" + 다음 할 일 한 줄. 할 일 22개 모두 동네 안, 집과 안 겹침, 보이는 곳 안
	var m := await _launch(false)
	var bad_lines := await _check_quest_lines(m, b)   # 새 게임이라 이미 찬 할 일 없음 (차례만 바꿔 봄)
	m.state.quest_index = _qi(b, "parcels_20")
	m.state.parcels_total = 3
	await _frames(2)
	var town = m.town
	var line_ok: bool = town._level_label.text == "Lv.1" and town._quest_label.text == "다음 할 일: 배송 20건 3/20"
	var first_line: String = town._quest_label.text
	_report(not m.is_full() and line_ok and bad_lines.is_empty(),
			"① 작은 화면 '%s' + '%s', 할 일 22개 줄이 동네 안·집과 안 겹침·보이는 곳 안 %s" % [town._level_label.text, first_line, bad_lines])

	# ② 큰 화면 차고 [기사·물류센터] 칸
	_click(town.view_rect(Feel.TOWN_DEPOT_RECT).get_center())
	await _frames(3)
	var p = m.panel
	var d = p.driver
	m.state.driver_level = 3
	m.state.driver_xp = 120
	m.state.ability_points = 2
	_click(p.driver_tab_button.get_global_rect().get_center())
	await _frames(3)
	var need3 := Driver.xp_need(b, 3)
	var q := Quest.current(b, m.state)
	_report(p.current_tab() == p.Tab.DRIVER and d.visible and not p.setting.visible and not p._engine_box.visible
			and d._level.text == "기사 Lv.3" and d._xp_bar.value == 120 and d._xp_bar.max_value == need3
			and d._xp.text == "경험치 120 / %d" % need3 and d._points.text.contains("포인트 2")
			and d._quest_head.text == "다음 할 일 · 끝낸 것 1/22" and d._quest_name.text == "배송 20건"
			and d._quest_desc.text == Fmt.quest_desc("parcels_20") and d._quest_desc.visible
			and d._quest_progress.text == "진행 3/20 · 보상 +%s원 · 경험치 +%d" % [Fmt.money(q["money"]), q["xp"]],
			"② [%s] 칸: '%s', 막대 %d/%d, '%s', '%s', '%s' / '%s' / '%s' / '%s'" % [
			p.driver_tab_button.text, d._level.text, d._xp_bar.value, d._xp_bar.max_value, d._xp.text, d._points.text,
			d._quest_head.text, d._quest_name.text, d._quest_desc.text, d._quest_progress.text])

	# ③ 할 일 끝 (창고 확장 Lv.2를 진짜 클릭으로 삼) → 돈 −가격 +보상, 알림, 다음 할 일로   ⑨ 산 직후 저장
	Engine.time_scale = 0.0
	m.state.quest_index = _qi(b, "warehouse_2")
	var wq := Quest.current(b, m.state)
	var w_price := Depot.price(b, m.state, "warehouse")
	m.state.money = w_price + 5000
	await _frames(3)
	var w_btn: Button = d.buy_buttons["warehouse"]
	_click(w_btn.get_global_rect().get_center())
	var money_ok: bool = m.state.money == 5000 + wq["money"] and m.state.warehouse_level == 2
	var saved_lv = _saved_state(b)
	var want3 := "할 일 끝! 창고 확장  +%s원 · 경험치 +%d\nLv.4! 포인트 +1" % [Fmt.money(wq["money"]), wq["xp"]]
	var shown3 := await _until(func(): return town.notices_shown.has(want3), 6.0)
	await _frames(2)
	_report(money_ok and shown3 and town._notice.visible and town._notice.text == want3
			and d._quest_name.text == "기사 Lv.5" and town._quest_label.text.begins_with("다음 할 일: 기사 Lv.5"),
			"③ 창고 확장 [올리기] → 돈 %s원 (가격 −%s, 보상 +%s), 알림 '%s', 다음 할 일 '%s' / 작은 줄 '%s'" % [
			Fmt.money(m.state.money), Fmt.money(w_price), Fmt.money(wq["money"]), town._notice.text.replace("\n", " / "),
			d._quest_name.text, town._quest_label.text])

	# ④ 레벨업 알림은 ③에 붙음. 만렙: Lv.49에서 할 일 보상으로 Lv.50 → 레벨업 + 만렙 줄, 남은 경험치는 회사 평판으로
	m.state.driver_level = 49
	m.state.driver_xp = Driver.xp_need(b, 49) - 100
	m.state.quest_index = _qi(b, "level_20")
	var lq := Quest.current(b, m.state)
	var points50: int = b.driver_points_per_level + b.driver_bonus_points_every_10
	var want4 := "할 일 끝! 기사 Lv.20  +%s원 · 경험치 +%d\nLv.50! 포인트 +%d\nLv.50 만렙! 이제 경험치는 회사 평판으로" % [
			Fmt.money(lq["money"]), lq["xp"], points50]
	var shown4 := await _until(func(): return town._notice.visible and town._notice.text == want4, 8.0)
	_report(shown3 and shown4 and d._level.text == "기사 Lv.50 (만렙)" and d._xp_bar.value == d._xp_bar.max_value
			and d._xp.text == "만렙이라 경험치는 회사 평판으로: %d" % (lq["xp"] - 100) and _notice_fits(m).is_empty(),
			"④ 레벨업 알림 'Lv.4! 포인트 +1'(③에 붙음), 만렙 알림 '%s', 차고 '%s' / '%s' %s" % [
			want4.replace("\n", " / "), d._level.text, d._xp.text, _notice_fits(m)])

	# ⑤ 창고·야간팀 (창고는 ③에서 Lv.2)
	var w2_value: String = d._values["warehouse"].text
	var w2_button: String = w_btn.text
	var p2 := Depot.price(b, m.state, "warehouse")
	m.state.money = p2 - 1234
	await _frames(2)
	var short_ok: bool = w_btn.disabled and d._waits["warehouse"].visible and d._waits["warehouse"].text.begins_with("1,234원 모자람")
	var short_text: String = d._waits["warehouse"].text
	_click(w_btn.get_global_rect().get_center())
	short_ok = short_ok and m.state.money == p2 - 1234 and m.state.warehouse_level == 2
	m.state.money = p2 + 777
	await _frames(2)
	_click(w_btn.get_global_rect().get_center())
	var bought_ok: bool = m.state.money == 777 and m.state.warehouse_level == 3
	var saved_lv3 = _saved_state(b)
	await _frames(2)
	var w3_value: String = d._values["warehouse"].text
	# 야간팀 Lv.1 → 4: 살 때마다 돈 −가격, 레벨 +1
	var n_btn: Button = d.buy_buttons["night"]
	var night_steps := []
	var night_ok := true
	for i in Depot.top_level(b, "night") - 1:
		var price := Depot.price(b, m.state, "night")
		var lv: int = m.state.night_level
		var before := _night_value_text(b, lv)
		night_ok = night_ok and d._values["night"].text == before and n_btn.text == "올리기 (%s원)" % Fmt.money(price)
		m.state.money = price
		await _frames(2)
		_click(n_btn.get_global_rect().get_center())
		night_ok = night_ok and m.state.money == 0 and m.state.night_level == lv + 1
		night_steps.append("%s → Lv.%d" % [before, m.state.night_level])
		await _frames(2)
	_report(w2_value == "꺼둔 동안 쌓이는 시간 6시간 → 8시간" and w2_button == "올리기 (%s원)" % Fmt.money(p2) and short_ok and bought_ok
			and not w_btn.visible and w3_value == "꺼둔 동안 쌓이는 시간 8시간 · 다음(12시간)은 대리점부터"
			and night_ok and not n_btn.visible and d._values["night"].text == "꺼둔 동안 버는 비율 80% (최고 단계)",
			"⑤ 창고 '%s' [%s], 돈 1,234원 모자라면 꺼짐 '%s', 사면 돈 −가격·Lv.3 → '%s', 야간팀 %s → '%s'" % [
			w2_value, w2_button, short_text, w3_value, night_steps, d._values["night"].text])
	_report(saved_lv != null and saved_lv.warehouse_level == 2 and saved_lv3 != null and saved_lv3.warehouse_level == 3
			and _saved_state(b).night_level == Depot.top_level(b, "night"),
			"⑨ [올리기]를 누른 직후 저장 파일에 창고 Lv.2 / Lv.3, 야간팀 Lv.%d" % _saved_state(b).night_level)

	# ⑥ main의 프레임을 멈춘 채(advance가 안 돎) 올리기·강화·세팅 → 그 자리에서 다음 할 일로
	m.rng.seed = SEED
	m.state.night_level = 1
	m.state.money = Depot.price(b, m.state, "night")
	m.state.quest_index = _qi(b, "night_2")
	await _frames(2)
	m.set_process(false)
	_click(n_btn.get_global_rect().get_center())
	var after_upgrade: int = m.state.quest_index
	m.set_process(true)
	# 강화 (+0 → +1, 첫 엔진 강화)
	_click(p.engine_tab_button.get_global_rect().get_center())
	m.state.quest_index = _qi(b, "first_enhance")
	m.state.truck(0).star = 0
	m.state.money = RICH
	m.suspense_scale = 0.05
	await _frames(3)
	m.set_process(false)
	_click(p._enhance_button.get_global_rect().get_center())
	await _until(func(): return not m.enhancing, 5.0)
	var after_enhance: int = m.state.quest_index
	var star_after: int = m.state.truck(0).star
	m.set_process(true)
	# 세팅 돌리기 (첫 세팅)
	_click(p.setting_tab_button.get_global_rect().get_center())
	m.state.quest_index = _qi(b, "first_setting")
	await _frames(3)
	m.set_process(false)
	_click(p.setting.roll_button.get_global_rect().get_center())
	await _until(func(): return not m.rolling, 5.0)
	var after_roll: int = m.state.quest_index
	m.set_process(true)
	_report(after_upgrade == _qi(b, "night_2") + 1 and star_after == 1 and after_enhance == _qi(b, "first_enhance") + 1
			and after_roll == _qi(b, "first_setting") + 1,
			"⑥ 프레임을 멈춘 채로도 야간팀 [올리기] → '%s', 강화 +1 → '%s', 돌리기 → '%s' (바로 다음 할 일로)" % [
			Fmt.quest_name(b.quests[after_upgrade]["id"]), Fmt.quest_name(b.quests[after_enhance]["id"]), Fmt.quest_name(b.quests[after_roll]["id"])])
	_click(p.setting.keep_button.get_global_rect().get_center())

	# ⑧ 다 끝나면 "다음 할 일 없음"
	_click(p.driver_tab_button.get_global_rect().get_center())
	m.state.quest_index = Quest.count(b)
	await _frames(3)
	_report(d._quest_name.text == "다음 할 일 없음" and not d._quest_desc.visible and not d._quest_progress.visible
			and d._quest_head.text == "다음 할 일 · 끝낸 것 22/22" and town._quest_label.text == "다음 할 일 없음",
			"⑧ 할 일을 다 끝내면 차고 '%s' '%s', 동네 '%s'" % [d._quest_head.text, d._quest_name.text, town._quest_label.text])

	# 차고가 가장 길 때(돈이 없어 두 줄 다 모자람, 긴 설명) 여러 창 크기에서 창 안, 동네와 안 겹침
	m.state.driver_level = 7
	m.state.warehouse_level = 1
	m.state.night_level = 1
	m.state.quest_index = _qi(b, "warehouse_2")
	m.state.money = 0
	await _check_fits(m, "ko [기사·물류센터]")
	await _close(m)

	# ⑦ 돌아왔을 때 요약 (할 일은 다 끝낸 상태로 저장: 켜자마자 할 일 보상이 섞이지 않게)
	await _check_return(b)

	# ⑪ 알림이 겹치면 하나씩 차례로: 할 일 5개가 이미 찬 상태로 켬 → 프레임마다 하나씩 끝남
	await _check_queue(b)

	# ⑩ en
	await _check_en(b)

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## ⑦ 저장 시각을 바꿔 켬: 3시간 / 20시간 / 179초 / 미래(시계가 거꾸로)
func _check_return(b: Balance) -> void:
	var lines := []
	var ok := true
	for c in [
		{ "name": "3시간", "away": 3 * HOUR },
		{ "name": "20시간", "away": 20 * HOUR },
		{ "name": "179초", "away": 179 },
		{ "name": "시계가 거꾸로", "away": -5 * HOUR },
	]:
		var s := GameState.new_game()
		s.truck(0).star = 10
		s.money = 1000
		s.quest_index = Quest.count(b)
		Save.delete_file(TEST_SAVE)
		# 179초는 올림한 지금 시각 기준 (켜는 데 걸리는 시간 + 소수점 때문에 180초를 넘지 않게),
		# 나머지는 내림 ("3시간"이 "2시간 59분"으로 안 보이게)
		var now := Time.get_unix_time_from_system()
		Save.write_file(TEST_SAVE, s, (ceili(now) if c["away"] == 179 else floori(now)) - int(c["away"]))
		var m := await _launch(false)
		var r: Dictionary = m.offline_report
		var main_text: String = m.popup.main_text()
		var note: String = m.popup.note_text()
		var fits: bool = Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()) \
				and _enclosed(m.visible_rects(), m.popup.get_rect())
		var cap := Depot.cap_hours(b, m.state)
		var this_ok: bool
		match c["name"]:
			"3시간":
				this_ok = m.popup.visible and fits and not r["full"] and main_text == "자리 비운 3시간 동안 +%s원" % Fmt.money(r["money"]) \
						and note == "배송 %d건 · 경험치 +0 · 스페어 엔진 +%d개\n꺼둔 동안은 50%%만, 최대 %s시간치까지 쌓입니다." % [r["parcels"], r["spares"], Fmt.num(cap)] \
						and m.state.money == 1000 + r["money"] and r["money"] > 0
			"20시간":
				this_ok = m.popup.visible and fits and r["full"] and r["hours"] == cap and main_text == "자리 비운 20시간 동안 +%s원" % Fmt.money(r["money"]) \
						and note.ends_with("창고가 꽉 참: %s시간치까지만 쌓였어요 (꺼둔 동안은 50%%만)" % Fmt.num(cap))
			"179초":
				this_ok = not m.popup.visible and r["ignored"] and m.state.money == 1000
			_:
				this_ok = m.popup.visible and fits and main_text == "자리 비운 동안 +0원" and note.contains("시계") and m.state.money == 1000
		ok = ok and this_ok
		lines.append("%s: %s" % [c["name"], ("'%s' / '%s'" % [main_text, note.replace("\n", " / ")]) if m.popup.visible else "창 없음, 돈 그대로"])
		await _close(m)
	_report(ok, "⑦ 돌아왔을 때 요약 %s" % [lines])


## ⑪ 할 일 5개가 이미 찬 상태로 작은 화면을 켬 → 한 프레임에 하나씩 끝나고, 알림은 앞의 것이 사라진 뒤 차례로
func _check_queue(b: Balance) -> void:
	var s := GameState.new_game()
	s.parcels_total = 25
	s.truck(0).star = 3
	s.setting_rolls = 1
	Save.delete_file(TEST_SAVE)
	Save.write_file(TEST_SAVE, s, ceili(Time.get_unix_time_from_system()))
	var m := await _launch(false)
	var town = m.town
	var want := []
	for i in 5:
		want.append(Fmt.quest_name(b.quests[i]["id"]))
	var seen := []          ## 띄운 알림 첫 줄, 띄운 순서
	var started := []       ## 띄운 시각 (ms)
	var max_waiting := 0
	var outside := []
	var last := ""
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		await process_frame
		max_waiting = maxi(max_waiting, town._notice_queue.size())
		if town._notice.visible and town._notice.text != last:
			last = town._notice.text
			seen.append(last.get_slice("\n", 0))
			started.append(Time.get_ticks_msec())
			outside.append_array(_notice_fits(m))
		if seen.size() >= want.size() and not town._notice.visible and town._notice_queue.is_empty():
			break
	var order_ok := seen.size() == want.size()
	for i in mini(seen.size(), want.size()):
		order_ok = order_ok and seen[i].begins_with("할 일 끝! " + want[i] + "  +")
	# 차례로 = 앞 알림이 적어도 (나타나기 + 머무름(바쁠 때) + 사라지기)만큼 떠 있은 뒤에 다음 것
	var min_gap := int((Feel.NOTICE_FADE * 2.0 + Feel.NOTICE_SECONDS_BUSY) * 1000.0) - 50
	var gaps := []
	for i in range(1, started.size()):
		gaps.append(started[i] - started[i - 1])
	_report(order_ok and max_waiting >= 3 and gaps.all(func(g): return g >= min_gap) and outside.is_empty() and m.state.quest_index == 5,
			"⑪ 할 일 5개가 한꺼번에 끝남 → 알림 %d개가 차례로 (가장 많이 기다린 수 %d, 사이 간격 %s ms ≥ %d) %s %s" % [
			seen.size(), max_waiting, gaps, min_gap, seen, outside])
	await _close(m)


## ⑩ en: 작은 화면 할 일 줄, 차고 [Driver & Depot] 칸 (할 일 22개 + 다 끝남), 알림, 차고 크기
func _check_en(b: Balance) -> void:
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	var m := await _launch(false)
	var bad_lines := await _check_quest_lines(m, b)
	var texts := []
	for i in Quest.count(b) + 1:
		m.state.quest_index = i
		await _frames(1)
		texts.append(m.town._quest_label.text)
	_click(m.town.view_rect(Feel.TOWN_DEPOT_RECT).get_center())
	await _frames(3)
	var p = m.panel
	_click(p.driver_tab_button.get_global_rect().get_center())
	m.state.money = 0
	for i in Quest.count(b) + 1:
		m.state.quest_index = i
		await _frames(1)
		texts.append_array(_visible_texts(m))
	# 할 일 끝 + 레벨업 + 만렙 알림
	Engine.time_scale = 0.0
	m.state.driver_level = Driver.max_level(b) - 1
	m.state.driver_xp = Driver.xp_need(b, m.state.driver_level) - 1
	m.state.quest_index = _qi(b, "level_20")
	await _until(func(): return m.town._notice.visible, 3.0)
	texts.append(m.town._notice.text)
	texts.append_array(_visible_texts(m))
	var bad := texts.filter(_untranslated)
	var names_ok := true
	for q: Dictionary in b.quests:
		names_ok = names_ok and texts.has(Fmt.quest_name(q["id"])) and texts.has(Fmt.quest_desc(q["id"]))
	_report(p.driver.visible and p.driver_tab_button.text == "Driver & Depot" and names_ok and bad.is_empty() and bad_lines.is_empty()
			and m.town._notice.text.contains("Max level"),
			"⑩ en에서도 [%s] 칸이 뜨고, 할 일 22개 이름·설명과 알림 포함 보이는 글자 %d개에 한글·키 없음 %s, 작은 줄 %s" % [
			p.driver_tab_button.text, texts.size(), bad, bad_lines])
	print("    en 알림: '%s'" % m.town._notice.text.replace("\n", " / "))
	m.state.driver_level = 7
	m.state.quest_index = _qi(b, "warehouse_2")
	m.state.money = 0
	await _check_fits(m, "en [Driver & Depot]")
	await _close(m)
	TranslationServer.set_locale("ko")


## 할 일 22개마다 작은 화면 한 줄이 동네 안, 집과 안 겹침, 보이는 곳 안인가. 문제 있는 줄을 돌려줌
func _check_quest_lines(m: Node, b: Balance) -> Array:
	var bad := []
	var town = m.town
	var before: int = m.state.quest_index
	for i in Quest.count(b) + 1:
		m.state.quest_index = i
		await _frames(1)
		var l: Label = town._quest_label
		var r := Rect2(l.position, l.size)
		var hits_house := false
		for spot in town._houses:
			hits_house = hits_house or r.intersects(town.view_rect(town._house_rect(spot)))
		var win := Rect2(r.position + town.position + m.position, r.size)
		if not town.area().encloses(r) or hits_house or not _enclosed(m.visible_rects(), win):
			bad.append("'%s' %s" % [l.text, r])
	m.state.quest_index = before
	await _frames(1)
	return bad


## 지금 떠 있는 알림이 동네 안, 왼쪽 위 글자("+N"·돈·Lv·할 일 줄)와 안 겹침, 작은 화면이면 보이는 곳 안인가
func _notice_fits(m: Node) -> Array:
	var town = m.town
	var n: Label = town._notice
	if not n.visible:
		return []
	var r := Rect2(n.position, n.size)
	var hud := Rect2(town._hud.position, town._hud.size).merge(Rect2(town._quest_label.position, town._quest_label.size))
	var win := Rect2(r.position + town.position + m.position, r.size)
	if not town.area().encloses(r) or r.intersects(hud) or (not m.is_full() and not _enclosed(m.visible_rects(), win)):
		return ["알림 '%s' %s (왼쪽 위 글자 %s)" % [n.text.replace("\n", " / "), r, hud]]
	return []


## 창 크기 1280x720 / 1600x900 / 3440x1440 + 좁은 창 모드 크기에서 차고가 창 안에 들어오고 동네와 안 겹치나
func _check_fits(m: Node, tag: String) -> void:
	var bad := []
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]:
		root.size = size
		await _frames(4)
		var pr: Rect2 = m.panel.get_global_rect()
		if not Rect2(Vector2.ZERO, Vector2(size)).encloses(pr) or pr.intersects(m.town.area()):
			bad.append("%dx%d 차고 %s" % [size.x, size.y, pr])
	root.size = Vector2i(1600, 900)
	await _frames(3)
	_report(bad.is_empty(), "%s: 가장 길 때 창 크기 5가지에서 차고가 창 안, 동네와 안 겹침 %s" % [tag, bad])


## 야간팀 값 글자 (다음 레벨을 살 수 있을 때 "지금 → 다음")
func _night_value_text(b: Balance, lv: int) -> String:
	return "꺼둔 동안 버는 비율 %s → %s" % [Fmt.percent(Depot.value_at(b, "night", lv)), Fmt.percent(Depot.value_at(b, "night", lv + 1))]


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["QUEST_", "DRIVER_", "DEPOT_", "NOTICE_", "TOWN_", "RETURN_", "GARAGE_"]:
		if x.begins_with(prefix):
			return true
	return _hangul.search(x) != null


func _qi(b: Balance, id: String) -> int:
	for i in b.quests.size():
		if b.quests[i]["id"] == id:
			return i
	push_error("할 일 id가 없음: " + id)
	return -1


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


## 작은 화면 크기로 띄움. full이면 물류센터를 클릭해 큰 화면으로. 게임 시간은 멈춤
func _launch(full: bool) -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	Engine.time_scale = 0.0
	await _frames(3)
	if full:
		_click(m.town.view_rect(Feel.TOWN_DEPOT_RECT).get_center())
		await _frames(3)
	return m


func _close(m: Node) -> void:
	root.remove_child(m)
	m.queue_free()
	await process_frame


## cond가 참이 될 때까지 프레임을 돌림 (진짜 시간 seconds까지). 됐으면 true
func _until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > seconds * 1000.0:
			return false
		await process_frame
	return true


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)


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
