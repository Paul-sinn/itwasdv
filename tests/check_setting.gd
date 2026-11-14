## v4 U1 완료 기준 자동 확인: 차고 [세팅] 칸 (세팅 돌리기). 진짜 게임 화면(main.tscn)에 진짜 키·클릭을 넣어서 확인한다.
## ① 적재함·ECU, +4에서 ECU 잠김 글("엔진 +5에 열림"), +5에서 열림
## ② 돌리기 → 돈이 roll_cost만큼 줄고 예전 것 / 새 것 고르는 화면, 고르기 전엔 돌리기 버튼 꺼짐
## ③ 새 것 / 예전 것을 고르면 줄·등급 글자가 그대로 반영
## ④ "천장 n/N"이 돌릴 때마다 오르고 등급업 뒤 새 등급 기준으로. 등급업·천장 도달 알림
## ⑤ 등급업 확률·옵션별 확률 글자 = Setting.up_chance·option_chances
## ⑥ 돈이 모자라면 버튼 꺼짐 + 모자란 금액
## ⑦ 고르는 화면에서 껐다 켜도 고르는 화면이 다시 뜸   ⑧ 돌린 직후·고른 직후 저장
## ⑨ 강화 칸의 퍼짐 확률 = Enhance.chances_for, 시간당 수입 = 세팅 반영 값
## ⑩ en에서도 탭이 뜨고 키·한글이 안 보임   ⑪ 잡옵 줄은 수치 없이 이름만, 회색
## v6-bal U1 ① ECU 오버부스트 설명에 "10" 없음 (ko·en)   ③ 적재함 한 바퀴 적재량: 21.6 → "21.6", 20 → "20"
## 돌리는 동안 배송이 나면 돈이 바뀌어서, 확인하는 동안 게임 시간을 멈춘다 (뜸은 진짜 시간이라 그대로 지나감).
## 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_setting.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄

const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_town_setting.json"
const TEST_SETTINGS := "user://test_town_settings.cfg"
const RICH := 1000000000   ## 돌리기에 넉넉한 돈
## 돌리기 결과를 고정 (④가 운에 달리지 않게: 이 seed면 등급업 전에 천장 +1을 2번 넘게 봄)
const SEED := 20261113

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
	var m := await _launch()
	Engine.time_scale = 0.0   # 시간이 멈추면 배송 굴리기도 없음 → 아래 돌리기만 rng를 씀
	m.rng.seed = SEED
	var p = m.panel
	var st = p.setting
	var t = m.state.truck(0)

	# ① [세팅] 칸: 적재함·ECU·타이어·휠(v7a, 창업 전 잠김), +4에서 ECU 잠김, +5에서 열림
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(3)
	_check(p.current_tab() == p.Tab.SETTING and st.visible and not p._engine_box.visible, "[세팅]을 눌렀는데 세팅 칸이 아님")
	for i in 4:
		_key(KEY_F4)
	await _frames(2)
	var cargo_btn: Button = st.part_buttons.get("cargo_box")
	var ecu_btn: Button = st.part_buttons.get("ecu")
	var locked_ok: bool = st.part_buttons.size() == 3 and st.part_buttons["tire"].disabled and t.star == 4 and not cargo_btn.disabled and ecu_btn.disabled \
			and ecu_btn.text.contains("엔진 +5에 열림")
	var locked_text: String = ecu_btn.text
	_key(KEY_F4)
	await _frames(2)
	_report(locked_ok and not ecu_btn.disabled and ecu_btn.text == "ECU",
			"① [세팅] 칸에 '%s'·ECU, +4에서 '%s'(꺼짐), +5에서 '%s'(켜짐)" % [cargo_btn.text, locked_text, ecu_btn.text])

	# ⑤ 등급업 확률·옵션별 확률 (적재함 순정, ECU 순정)
	var prob_ok := true
	for part in ["cargo_box", "ecu"]:
		_click(st.part_buttons[part].get_global_rect().get_center())
		await _frames(3)
		prob_ok = prob_ok and st.selected == part and st._up.text.contains("등급업 확률 " + Fmt.percent(Setting.up_chance(b, 0, m.state)))
		var chances := Setting.option_chances(b, part, 0)
		for op in chances:
			if not st._chances.text.contains("%s %s" % [st.option_name(op), Fmt.percent(chances[op])]):
				prob_ok = false
				print("    %s %s 확률 글자가 없음: %s" % [part, op, st._chances.text])
		prob_ok = prob_ok and not st._chances.text.contains(st.option_name("engine_guard"))   # 순정에서는 안 뽑힘
		print("    %s: %s / %s" % [part, st._up.text, st._chances.text])
	_report(prob_ok, "⑤ 등급업 확률·옵션별 확률 글자 = Setting.up_chance·option_chances (적재함·ECU 순정, 엔진 보호는 순정에서 안 보임)")

	# v6-bal U1 ① ECU: 오버부스트 설명 (줄 3개일 때 큰 화면 여러 크기에서 차고가 창 안)
	var ecu_was: Dictionary = t.part("ecu").duplicate(true)
	_click(ecu_btn.get_global_rect().get_center())
	await _frames(3)
	var boost_note: String = st._effect.text
	_report(st._effect.is_visible_in_tree() and boost_note == "오버부스트: 걸리면 그 바퀴 내내 운전 속도 %s배" % Fmt.num(b.overboost_mult)
			and not boost_note.contains("10"),
			"v6-bal U1 ① ECU 오버부스트 설명 '%s' (\"10\" 없음)" % boost_note)
	t.part("ecu")["grade"] = 4
	t.part("ecu")["lines"] = ["overboost", "engine_guard", "junk_scent"]
	await _check_fits(m, "v6-bal ECU 오버부스트 설명 + 줄 3개")
	t.part("ecu").merge(ecu_was, true)

	# v6-bal U1 ③ 적재함: 한 바퀴 적재량 (소수점 있으면 한 자리, 없으면 정수)
	var cargo_was: Dictionary = t.part("cargo_box").duplicate(true)
	_click(cargo_btn.get_global_rect().get_center())
	await _frames(3)
	var cargo_texts := []
	var cargo_avgs := []
	var want_cargo := 20.0 * (1.0 + Setting.option_value(b, "cargo", 1))   # 스트리트 적재량 한 줄 (v7-bal: 5.5% → 21.1건)
	for setup in [[0, []], [1, ["cargo"]]]:   # 줄 없음 = 20건, 스트리트 적재량 한 줄
		t.part("cargo_box")["grade"] = setup[0]
		t.part("cargo_box")["lines"] = setup[1]
		await _frames(2)
		cargo_texts.append(st._effect.text)
		cargo_avgs.append(Trip.cargo(b, m.state, 0))
	t.part("cargo_box").merge(cargo_was, true)
	await _frames(2)
	_report(st._effect.is_visible_in_tree() and cargo_texts == ["한 바퀴 적재량 20건", "한 바퀴 적재량 %s건" % Fmt.num(want_cargo, 1)]
			and is_equal_approx(cargo_avgs[0], 20.0) and is_equal_approx(cargo_avgs[1], want_cargo),
			"v6-bal U1 ③ 적재함 평균 적재량 %s → %s" % [cargo_avgs, cargo_texts])
	_click(cargo_btn.get_global_rect().get_center())
	await _frames(3)

	# ⑥ 돈 모자람: 버튼 꺼짐 + 모자란 금액, 눌러도 안 돌아감
	var cost0 := Setting.roll_cost(b, 0, m.state)
	m.state.money = cost0 - 1234
	await _frames(3)
	var short_ok: bool = st.roll_button.disabled and st._wait.visible and st._wait.text.begins_with(Fmt.money(1234) + "원 모자람")
	_click(st.roll_button.get_global_rect().get_center())
	await _until_rolled(m)
	_report(short_ok and m.state.money == cost0 - 1234 and t.part("cargo_box")["pending"] == null,
			"⑥ 돈이 %s원 모자라면 돌리기 버튼 꺼짐 + '%s', 눌러도 안 돌아감" % [Fmt.money(1234), st._wait.text])

	# ② 돌리기 → 돈 −roll_cost, 고르는 화면, 돌리기 버튼 꺼짐  ⑧ 돌린 직후 저장
	m.state.money = RICH
	await _frames(3)
	m.suspense_scale = 0.1
	_click(st.roll_button.get_global_rect().get_center())
	await _frames(1)
	var in_suspense: bool = m.rolling and st.roll_button.disabled
	await _until_rolled(m)
	await _frames(3)
	var cp: Dictionary = t.part("cargo_box")
	_report(in_suspense and m.state.money == RICH - cost0 and cp["pending"] != null and st._choose.visible and st.roll_button.disabled
			and st._wait.text == tr("SETTING_PENDING"),
			"② 돌리기 → 돈 −%s원 (roll_cost), 고르는 화면이 뜸, 돌리기 버튼 꺼짐 '%s'" % [Fmt.money(RICH - m.state.money), st._wait.text])
	var saved_roll = _saved_part("cargo_box", b)

	# ③ 새 것 고르기 → 줄·등급 글자 반영. 처음(줄 없음)도 고르는 화면에 "줄 없음"
	var first_old_text: String = st._old_lines.get_child(0).text
	var pending: Dictionary = cp["pending"].duplicate(true)
	_click(st.take_button.get_global_rect().get_center())
	await _frames(3)
	var took_ok: bool = cp["pending"] == null and cp["grade"] == pending["grade"] and cp["lines"] == pending["lines"] \
			and _shown_ok(st, b, pending["grade"], pending["lines"]) and not st._choose.visible
	var saved_choose = _saved_part("cargo_box", b)
	# 예전 것 고르기 → 그대로
	var before_grade: int = cp["grade"]
	var before_lines: Array = cp["lines"].duplicate()
	_click(st.roll_button.get_global_rect().get_center())
	await _until_rolled(m)
	await _frames(3)
	_click(st.keep_button.get_global_rect().get_center())
	await _frames(3)
	var kept_ok: bool = cp["pending"] == null and cp["grade"] == before_grade and cp["lines"] == before_lines \
			and _shown_ok(st, b, before_grade, before_lines)
	_report(first_old_text == tr("SETTING_NO_LINES") and took_ok and kept_ok,
			"③ 처음 고르는 화면 예전 칸 '%s', 새 것 → %s %s, 예전 것 → 그대로 (글자: '%s' / %s)" % [
			first_old_text, st.grade_name(pending["grade"]), pending["lines"], st._grade.text, _line_texts(st._lines)])
	_report(saved_roll != null and saved_roll["pending"] != null and saved_choose != null and saved_choose["pending"] == null
			and saved_choose["lines"] == pending["lines"],
			"⑧ 돌린 직후 저장 파일에 고르기 전 상태(pending), 고른 직후 저장 파일에 고른 줄")

	# ④ 천장: 돌릴 때마다 n+1 (예전 것 고름), 등급업이 나오면 새 것을 골라 새 등급 기준 "천장 0/N"
	var ceil_ok := true
	var steps := 0
	var upgraded := false
	for i in Setting.ceiling(b, cp["grade"]) + 2:
		var g: int = cp["grade"]
		var n: int = cp["counters"][g]
		ceil_ok = ceil_ok and st._up.text.contains("천장 %d/%d" % [n, Setting.ceiling(b, g)])
		_click(st.roll_button.get_global_rect().get_center())
		await _until_rolled(m)
		await _frames(3)
		if cp["pending"]["grade"] > g:
			ceil_ok = ceil_ok and st.result_text().contains("등급업") and st._new_title.text.contains(tr("SETTING_GRADE_UP"))
			_click(st.take_button.get_global_rect().get_center())
			await _frames(3)
			ceil_ok = ceil_ok and st._up.text.contains("천장 0/%d" % Setting.ceiling(b, g + 1))
			upgraded = true
			print("    %d번째에 등급업 → '%s'" % [i + 1, st._up.text])
			break
		ceil_ok = ceil_ok and st._up.text.contains("천장 %d/%d" % [n + 1, Setting.ceiling(b, g)])
		steps += 1
		_click(st.keep_button.get_global_rect().get_center())
		await _frames(3)
	# 천장 도달: ECU 순정 카운터를 천장 바로 앞으로 두고 돌리면 무조건 등급업 + "천장 도달" 알림
	t.part("ecu")["counters"][0] = Setting.ceiling(b, 0) - 1
	_click(ecu_btn.get_global_rect().get_center())
	await _frames(3)
	_click(st.roll_button.get_global_rect().get_center())
	await _until_rolled(m)
	await _frames(3)
	var pity_text: String = st.result_text()
	_report(ceil_ok and steps >= 2 and upgraded and pity_text == tr("SETTING_RESULT_PITY") % [st.grade_name(0), st.grade_name(1)],
			"④ 천장 숫자가 돌릴 때마다 +1 (%d번 확인, 2번 이상이어야 함), 등급업 뒤 새 등급 기준으로, 천장 도달 알림 '%s'" % [steps, pity_text])

	# ⑦ 고르는 화면(ECU)에서 껐다 켜도 다시 뜸
	m.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)   # 창 닫기 = 저장
	await _close(m)
	m = await _launch()
	Engine.time_scale = 0.0
	p = m.panel
	st = p.setting
	t = m.state.truck(0)
	_report(t.part("ecu")["pending"] != null and p.current_tab() == p.Tab.SETTING and st.selected == "ecu" and st._choose.visible,
			"⑦ 고르는 화면에서 껐다 켜도 [세팅] 칸 ECU 고르는 화면이 다시 뜸")
	_click(st.take_button.get_global_rect().get_center())
	await _frames(3)

	# ⑪ 잡옵 줄: 수치 없이 이름만, 회색
	var c2: Dictionary = t.part("cargo_box")
	c2["grade"] = 1
	c2["lines"] = ["junk_cupholder", "speed"]
	c2["pending"] = null
	_click(st.part_buttons["cargo_box"].get_global_rect().get_center())
	await _frames(3)
	var junk: Label = st._lines.get_child(0)
	var speed: Label = st._lines.get_child(1)
	_report(junk.text == tr("SETTING_OPT_JUNK_CUPHOLDER") and junk.get_theme_color("font_color") == Feel.COLOR_SETTING_JUNK
			and speed.text == "이동 속도 +%s" % Fmt.percent(Setting.option_value(b, "speed", 1)) and speed.get_theme_color("font_color") != Feel.COLOR_SETTING_JUNK,
			"⑪ 잡옵 줄은 '%s'(회색), 보통 줄은 '%s'" % [junk.text, speed.text])

	# 고르는 화면이 가장 길 때(레이싱 3줄 → 프로토타입 3줄, 긴 이름) 여러 창 크기에서 차고가 창 안, 동네와 안 겹침
	c2["grade"] = 3
	c2["lines"] = ["junk_scent", "junk_radio", "fuel_cut"]
	c2["pending"] = { "grade": 4, "lines": ["junk_scent", "junk_radio", "junk_scent"] }
	await _check_fits(m, "ko 고르는 화면")

	# ⑨ 강화 칸: 퍼짐 확률 = chances_for (엔진 보호 3줄), 시간당 수입 = 세팅 반영
	var ecu: Dictionary = t.part("ecu")
	ecu["grade"] = 4
	ecu["lines"] = ["engine_guard", "engine_guard", "engine_guard"]
	ecu["pending"] = null
	t.star = 20
	_click(p.engine_tab_button.get_global_rect().get_center())
	await _frames(3)
	var c := Enhance.chances_for(b, m.state, 0)
	var plain := GameState.new_game()   # 같은 단계, 세팅·능력치 없음
	plain.truck(0).star = t.star
	var hourly := Trip.hourly_income(b, m.state, 0)
	_report(p._danger.text == tr("GARAGE_DANGER") % Fmt.percent(c["destroy"]) and c["destroy"] < Enhance.chances(b, 20)["destroy"]
			and p._chances.text == tr("GARAGE_CHANCES") % [Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
			and p._income.text.begins_with(tr("GARAGE_HOURLY") % Fmt.money(int(hourly))) and hourly != Trip.hourly_income(b, plain, 0),
			"⑨ 강화 칸 '%s' / '%s' (엔진만이면 퍼짐 %s), '%s' (세팅 없으면 시간당 %s원)" % [
			p._danger.text, p._chances.text, Fmt.percent(Enhance.chances(b, 20)["destroy"]), p._income.text, Fmt.money(int(Trip.hourly_income(b, plain, 0)))])
	await _close(m)

	# ⑩ en: 탭이 뜨고, 돌리고 고르는 동안 보이는 글자에 한글·키가 없음
	TranslationServer.set_locale("en")
	Save.delete_file(TEST_SAVE)
	m = await _launch()
	Engine.time_scale = 0.0
	p = m.panel
	st = p.setting
	m.state.money = RICH
	m.suspense_scale = 0.1
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(3)
	var texts := _visible_texts(m)
	_click(st.roll_button.get_global_rect().get_center())
	await _until_rolled(m)
	await _frames(3)
	texts.append_array(_visible_texts(m))
	var bad := texts.filter(func(x): return _hangul.search(x) != null or x.begins_with("SETTING_") or x.begins_with("GARAGE_"))
	_report(st.visible and st._choose.visible and bad.is_empty() and p.setting_tab_button.text == "Setups",
			"⑩ en에서도 [%s] 칸이 뜨고 돌린 뒤 보이는 글자 %d개에 한글·키 없음 %s" % [p.setting_tab_button.text, texts.size(), bad])
	print("    en 보이는 글자: %s" % [texts])
	# v6-bal U1 ① en ECU 오버부스트 설명 (ECU는 +5에 열림)
	m.state.truck(0).star = 5
	await _frames(2)
	_click(st.part_buttons["ecu"].get_global_rect().get_center())
	await _frames(3)
	var en_note: String = st._effect.text
	_report(st._effect.is_visible_in_tree() and en_note.begins_with("Overboost") and _hangul.search(en_note) == null and not en_note.contains("10"),
			"v6-bal U1 ① en ECU 오버부스트 설명 '%s' (\"10\"·한글 없음)" % en_note)
	_click(st.part_buttons["cargo_box"].get_global_rect().get_center())
	await _frames(2)
	var c3: Dictionary = m.state.truck(0).part("cargo_box")
	c3["grade"] = 3
	c3["lines"] = ["junk_scent", "junk_radio", "fuel_cut"]
	c3["pending"] = { "grade": 4, "lines": ["junk_scent", "junk_radio", "junk_scent"] }
	await _check_fits(m, "en 고르는 화면")
	await _close(m)

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


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


## 세팅 칸 글자가 그 등급·줄을 보여 주나
func _shown_ok(st, b: Balance, grade: int, lines: Array) -> bool:
	if not st._grade.text.contains(st.grade_name(grade)):
		return false
	for i in lines.size():
		if st._lines.get_child(i).text != st.line_text(b, lines[i], grade):
			return false
	return true


func _line_texts(box: Node) -> Array:
	var out := []
	for l in box.get_children():
		if l.visible:
			out.append(l.text)
	return out


## 저장 파일에 있는 트럭 0의 부품 상태 (없으면 null)
func _saved_part(part: String, b: Balance):
	var r := Save.read_file(TEST_SAVE, b)
	if r["status"] != Save.Status.OK:
		return null
	return r["state"].truck(0).part(part).duplicate(true)


## main 아래 보이는 Label·Button 글자 전부
func _visible_texts(m: Node) -> Array:
	var out := []
	for n in m.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "":
			out.append(n.text)
	return out


## 작은 화면 크기로 띄우고 물류센터를 클릭해 큰 화면으로
func _launch() -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	await _frames(3)
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_check(m.is_full() and m.panel.visible, "큰 화면으로 안 감")
	return m


func _close(m: Node) -> void:
	root.remove_child(m)
	m.queue_free()
	await process_frame


## 돌리기 뜸이 끝날 때까지 (최대 600프레임)
func _until_rolled(m: Node) -> void:
	await process_frame
	var waited := 0
	while m.rolling and waited < 600:
		await process_frame
		waited += 1


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


func _report(ok: bool, text: String) -> void:
	_check(ok, text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
