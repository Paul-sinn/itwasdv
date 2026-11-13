## v3 U1 완료 기준 자동 확인: 번역 파일 · 돈 표기 · 강화 단계 "+N" 표기
## ① locale/strings.csv와 번역 파일(locale/*.translation)이 같은가 (ko·en 칸이 비지 않음)
## ② 코드가 쓰는 키가 ko·en 모두 번역되나 (키 그대로 나오면 실패). ko·en이 아닌 언어(ja)는 en으로
## ③ scripts/ui/에 한글 화면 글자가 코드에 직접 안 남음 (로그 push_warning/push_error는 뺌)
## ④ Fmt.money 예시가 ko·en 표기 규칙대로
## ⑤ ★와 "N강" 표기가 코드·번역 파일에 없음
## ⑥⑦ 진짜 게임 화면(main.tscn)에 진짜 키·클릭을 넣어서: ko는 "+N" 표기, en은 보이는 글자에 한글·키가 없음
##
## 실행 (번역 파일 *.translation은 git에 들어 있어서 새로 받은 폴더에서도 그대로 돈다):
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_i18n.gd
## strings.csv를 고친 뒤에는 번역 파일을 다시 만들고 같이 커밋한다 (안 하면 ①에서 실패):
##   <GODOT_CONSOLE> --headless --path <프로젝트> --import
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄

const MAIN_SCENE := "res://scenes/main.tscn"
const CSV_PATH := "res://locale/strings.csv"
const UI_DIR := "res://scripts/ui/"
const LOG_CALLS := ["push_warning(", "push_error(", "print("]   ## 화면이 아니라 로그
const Balance = preload("res://scripts/core/balance.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Ability = preload("res://scripts/core/ability.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_i18n_save.json"
const TEST_SETTINGS := "user://test_i18n_settings.cfg"
const MONEY_CASES := [9999, 12000, 123456789, 340000000, 1200000000000]
const MONEY_WANT := {
	"ko": ["9,999", "1.2만", "1.2억", "3.4억", "1.2조"],
	"en": ["9.9K", "12K", "123M", "340M", "1.2T"],
}

var _all_ok := true
var _hangul := RegEx.create_from_string("[가-힣ㄱ-ㅎㅏ-ㅣ]")
var _key_like := RegEx.create_from_string("^[A-Z][A-Z0-9_]+$")
var _n_gang := RegEx.create_from_string("(\\d|%d)강")   ## "18강", "%d강" ("F5 강제"는 괜찮음)
var _csv := {}   ## 키 → { "ko": 글, "en": 글 }


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_csv()
	var code_keys := _check_code()
	# 세팅 이름 키는 balance.json의 id로 만들어 씀 (setting_tab.gd): 부품·옵션·등급마다 있어야 함
	var b := Balance.load_file()
	for g in Setting.max_grade(b) + 1:
		code_keys["SETTING_GRADE_%d" % g] = true
	for part: String in Setting.part_ids(b):
		code_keys["SETTING_PART_" + part.to_upper()] = true
		for op in Setting.option_chances(b, part, Setting.max_grade(b)):
			code_keys["SETTING_OPT_" + String(op).to_upper()] = true
	# 다음 할 일 이름·설명 키도 balance.json의 id로 만들어 씀 (Fmt.quest_name / quest_desc)
	for q: Dictionary in b.quests:
		code_keys["QUEST_" + String(q["id"]).to_upper()] = true
		code_keys["QUEST_" + String(q["id"]).to_upper() + "_DESC"] = true
	# 능력치 이름·설명·효과 키도 balance.json의 id로 만들어 씀 (driver_tab.gd)
	for id: String in Ability.ids(b):
		for suffix in ["", "_DESC", "_EFFECT"]:
			code_keys["ABILITY_" + id.to_upper() + suffix] = true
	# 명장 보너스 키는 balance.json의 id로, 요일 키는 번호로 만들어 씀 (Fmt.master_bonus / day_name)
	for id: String in b.master_bonus_ids:
		code_keys["MASTER_BONUS_" + id.to_upper()] = true
	for d in 7:
		code_keys["DAY_%d" % d] = true
		code_keys["DAY_SHORT_%d" % d] = true
	_check_keys(code_keys)
	_check_money()
	await _check_screen_ko()
	await _check_screen_en()
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("전부 통과" if _all_ok else "실패 있음")
	quit(0 if _all_ok else 1)


## ① strings.csv ↔ 번역 파일
func _check_csv() -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var head := f.get_csv_line()
	_report(head == PackedStringArray(["keys", "ko", "en"]), "strings.csv 첫 줄이 keys,ko,en: %s" % [head])
	var bad := PackedStringArray()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != 3 or row[1] == "" or row[2] == "":
			bad.append("칸이 비었거나 3칸이 아님: %s" % [row])
			continue
		if _csv.has(row[0]):
			bad.append("키가 두 번: " + row[0])
		_csv[row[0]] = { "ko": row[1].c_unescape(), "en": row[2].c_unescape() }
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in _csv:
			var got := String(TranslationServer.translate(key))
			if got != _csv[key][locale]:
				bad.append("%s %s: 번역 파일 '%s' / csv '%s'" % [locale, key, got, _csv[key][locale]])
	for b in bad.slice(0, 10):
		print("    " + b)
	_report(bad.is_empty() and not _csv.is_empty(),
			"strings.csv의 키 %d개가 ko·en 번역 파일과 같음 (다르면 --import로 다시 만들 것)" % _csv.size())


## ③⑤ 코드: 한글 화면 글자, ★, "N강". 코드가 쓰는 키(대문자_밑줄 글자)를 모아 돌려준다
func _check_code() -> Dictionary:
	var keys := {}
	var hangul := PackedStringArray()
	var star := PackedStringArray()
	var files := 0
	for file in DirAccess.get_files_at(UI_DIR):
		if not file.ends_with(".gd"):
			continue
		files += 1
		var lines := FileAccess.get_file_as_string(UI_DIR + file).split("\n")
		for i in lines.size():
			var is_log := LOG_CALLS.any(func(c): return lines[i].contains(c))
			for s in _string_literals(lines[i]):
				if _key_like.search(s) != null and not s.ends_with("_"):   # "SETTING_PART_" 같은 앞부분은 빼고
					keys[s] = true
				if not is_log and _hangul.search(s) != null:
					hangul.append("%s:%d \"%s\"" % [file, i + 1, s])
				if s.contains("★") or _n_gang.search(s) != null:
					star.append("%s:%d \"%s\"" % [file, i + 1, s])
	for x in hangul:
		print("    " + x)
	_report(files > 5 and hangul.is_empty(), "scripts/ui/ 파일 %d개에 한글 화면 글자가 코드에 직접 없음" % files)
	for key: String in _csv:
		for locale in ["ko", "en"]:
			var text: String = _csv[key][locale]
			if text.contains("★") or _n_gang.search(text) != null:
				star.append("strings.csv %s %s: %s" % [key, locale, text])
	for x in star:
		print("    " + x)
	_report(star.is_empty(), "★와 'N강' 표기가 코드·번역 파일에 없음")
	return keys


## ② 코드가 쓰는 키가 ko·en 모두 번역됨. ko·en이 아닌 언어는 en
func _check_keys(keys: Dictionary) -> void:
	var bad := PackedStringArray()
	for key: String in keys:
		if not _csv.has(key):
			bad.append("strings.csv에 없음: " + key)
			continue
		for locale in ["ko", "en", "ja"]:
			TranslationServer.set_locale(locale)
			var got := String(TranslationServer.translate(key))
			var want: String = _csv[key]["ko" if locale == "ko" else "en"]
			if got == key or got != want:
				bad.append("%s %s → '%s'" % [locale, key, got])
	for x in bad:
		print("    " + x)
	_report(bad.is_empty() and keys.size() > 10, "코드가 쓰는 키 %d개(세팅 부품·옵션·등급, 다음 할 일 이름·설명 포함)가 ko·en 모두 번역됨 (ja는 en으로)" % keys.size())
	var unused := PackedStringArray()
	for key: String in _csv:
		if not keys.has(key):
			unused.append(key)
	if not unused.is_empty():
		print("    · 참고: strings.csv에만 있고 코드에 없는 키 %s" % [unused])


## ④ Fmt.money 예시
func _check_money() -> void:
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		var got := []
		for v in MONEY_CASES:
			got.append(Fmt.money(v))
		_report(got == MONEY_WANT[locale], "Fmt.money %s: %s → %s" % [locale, MONEY_CASES, got])


## ⑥ ko 진짜 화면: 동네 "+N", 차고 제목 "엔진 +N", 강화 성공 "+N → +N", 최대 "(최대)"
func _check_screen_ko() -> void:
	TranslationServer.set_locale("ko")
	var m := await _launch()
	var p = m.panel
	_report(m.town._star_label.text == "+0" and m.town._money_label.text == "0원",
			"ko 작은 화면 구석: '%s' '%s' (기대 '+0' '0원')" % [m.town._star_label.text, m.town._money_label.text])
	for i in 3:
		_key(KEY_F4)
	await _frames(1)
	_report(m.town._star_label.text == "+3", "ko F4 세 번 → 동네 구석 '%s' (기대 '+3')" % m.town._star_label.text)
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_report(m.is_full() and p.visible and p._title.text == "엔진 +3",
			"ko 작은 화면 튜닝숍 클릭 → 큰 화면 튜닝숍 제목 '%s' (기대 '엔진 +3')" % p._title.text)

	# 강화 버튼을 진짜로 눌러 성공이 나올 때까지 (낮은 단계라 거의 첫 번에 성공)
	m.suspense_scale = 0.01
	m.state.money = 1000000000000
	var success_text := ""
	for i in 20:
		var before: int = m.state.truck(0).star
		await _frames(1)
		_click(p._enhance_button.get_global_rect().get_center())
		await _frames(1)
		var waited := 0
		while m.enhancing and waited < 600:
			await process_frame
			waited += 1
		await _frames(1)   # 동네 구석 글자는 다음 프레임에 바뀜
		if m.state.truck(0).star == before + 1:
			success_text = p._result.text
			_report(success_text == "성공!  +%d → +%d" % [before, before + 1] and p._title.text == "엔진 +%d" % m.state.truck(0).star
					and m.town._star_label.text == "+%d" % m.state.truck(0).star,
					"ko 강화 성공 결과 '%s', 차고 제목 '%s', 동네 '%s'" % [success_text, p._title.text, m.town._star_label.text])
			break
	_report(success_text != "", "ko 강화 버튼을 눌러 성공이 나옴")
	_report(not _visible_texts(m).any(func(t): return t.contains("★") or _n_gang.search(t) != null),
			"ko 보이는 글자에 ★·'N강' 없음: %s" % [_visible_texts(m)])

	var b = m.balance
	while m.state.truck(0).star < b.max_star:
		_key(KEY_F4)
		await _frames(1)
	await _frames(1)
	_report(p._title.text == "엔진 +%d (최대)" % b.max_star, "ko 최대 단계 차고 제목 '%s'" % p._title.text)
	await _close(m)


## ⑦ en 진짜 화면 (U2 ⑤): 차고가 뜨고 보이는 글자에 한글·키가 없음, 돈은 ₩ + K/M
func _check_screen_en() -> void:
	TranslationServer.set_locale("en")
	var m := await _launch()
	var p = m.panel
	_report(m.town._star_label.text == "+0" and m.town._money_label.text == "₩0",
			"en 작은 화면 구석: '%s' '%s' (기대 '+0' '₩0')" % [m.town._star_label.text, m.town._money_label.text])
	m.state.money = 12345
	await _frames(1)
	_report(m.town._money_label.text == "₩12.3K", "en 돈 표기 '%s' (기대 '₩12.3K')" % m.town._money_label.text)
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_report(m.is_full() and p.visible and p._title.text == "Engine +0" and p._enhance_button.text == "Upgrade",
			"en 큰 화면 차고 제목 '%s', 버튼 '%s'" % [p._title.text, p._enhance_button.text])
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	_report(m.settings.visible, "en [Settings] 클릭 → 설정 창이 뜸")
	var texts := _visible_texts(m)
	_click(m.settings.close_button.get_global_rect().get_center())
	# 차고가 가장 길 때 (+18, 스페어 없음, 돈 모자람) + 퍼짐 결과 + 복귀 창 (백업 복구 안내 + 꺼둔 동안 요약)
	m.state.truck(0).star = 18
	m.state.money = 0
	p.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, tr("RESULT_DESTROY_NOTE") % [15, 0])
	m.offline_report = { "money": 54321, "parcels": 123, "spares": 1, "hours": 3.0, "xp": 0, "full": false, "ignored": false, "away_seconds": 3.0 * 3600.0 }
	m._open_return_popup(tr("LOAD_RECOVERED") % "save.json.broken")
	await _frames(2)
	texts.append_array(_visible_texts(m))
	var bad := texts.filter(func(t): return _hangul.search(t) != null or _csv.has(t))
	_report(bad.is_empty() and texts.size() > 20 and p._wait.text == tr("GARAGE_NEED_SPARE") and m.popup.visible,
			"(U2 ⑤) en 언어로도 차고·설정·복귀 창이 뜨고, 보이는 글자 %d개에 한글·키 없음 %s" % [texts.size(), bad])
	print("    en 보이는 글자: %s" % [texts])
	await _close(m)


## 줄 하나에서 문자열 글자들 (주석 # 뒤는 뺌)
func _string_literals(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var quote := ""
	var cur := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote == "":
			if c == "#":
				break
			if c == "\"" or c == "'":
				quote = c
				cur = ""
		elif c == "\\":
			cur += line.substr(i, 2)
			i += 1
		elif c == quote:
			out.append(cur)
			quote = ""
		else:
			cur += c
		i += 1
	return out


## main 아래 보이는 Label·Button 글자 전부
func _visible_texts(m: Node) -> Array:
	var out := []
	for n in m.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree() and n.text != "":
			out.append(n.text)
	return out


func _launch() -> Node:
	root.size = Feel.SMALL_SIZE
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	Save.delete_file(TEST_SAVE)
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _report(ok: bool, text: String) -> void:
	_all_ok = _all_ok and ok
	print("%s %s" % ["[통과]" if ok else "[실패]", text])
