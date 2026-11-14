## v7-bal 화면 완료 기준 자동 확인 (U2 틀: 계산 C1 전이라 특별 NPC 3명은 main.visitor_stub로 띄움. 명장은 진짜 Master).
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 방문일·벨 시계를 미리 넣는 것은 준비로만 한다.
## ① 편지봉투: NPC 없으면 없음, 명장 날 작은 화면 오른쪽 위에 봉투 + 느낌표 (보이는 곳 안) → 누르면 큰 화면 + 대화 창,
##    느낌표만 꺼지고 봉투는 남음 (작게 해도), [닫기], 큰 화면에서도 봉투 → 대화 창
## ② NPC 대화 창: 보험사(제휴 할인) 이름·대사·이벤트·보험료 규칙·[예] [아니오] → [아니오] 닫힘 → 다시 열어 [예] → "가입됨"·[닫기],
##    복구 보험 글, 마술사·부품상 효과 한 줄 + [닫기], 다른 NPC·다음 날이면 느낌표가 다시, NPC가 떠나면 봉투·창 사라짐
## ③ 급송 전화 아이콘: 작은 화면 오른쪽 위 (보이는 곳 안), 봉투와 나란히 안 겹침·알림과 안 겹침,
##    누르면 큰 화면 없이 받음 (급송 N건), 큰 화면에서도 아이콘 → 받음 (건물 화면 그대로), 아이콘 + 봉투 + 글자 10개에도 사각형 30개 이하
## ④ 번역: en 대화 창 4명·이벤트 2개 글자에 한글·키 없음, 번역 파일에 "큐브" 없음, 큰 화면 5가지에서 대화 창이 창 안
## 현지 시각은 main.now_local_override로 고정 (2026-11-18 수요일 12:00). 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v7bal.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const CSV_PATH := "res://locale/strings.csv"
const Balance = preload("res://scripts/core/balance.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Save = preload("res://scripts/core/save.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_v7bal.json"
const TEST_SETTINGS := "user://test_v7bal_settings.cfg"
const DAY := 86400
const SMALL_SIZES := [Vector2i(480, 220), Vector2i(720, 330), Vector2i(960, 440)]
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]
## 임시 칸에 넣는 특별 NPC (효과 숫자는 지시서 "새로 넣는 것" 시작값. C1 뒤에는 balance 숫자로 바뀜)
const INSURER := { "who": "insurer", "event": "partner_discount", "insured": false, "fee_mult": 10, "discount": 0.5, "recovery_star": 17 }
const MAGICIAN := { "who": "magician", "up_mult": 2 }
const DEALER := { "who": "dealer", "gift": 1, "drop_to": 17 }

var fails := PackedStringArray()
var checks := 0
var now := 0
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

	await _letter_master(b)
	await _dialogs(b)
	await _phone(b)
	await _lang_and_fit(b)

	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## ①: 명장 날 편지봉투 (진짜 Master.is_visiting)
func _letter_master(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var letter = town.letter_button
	var none_before: bool = not letter.visible
	m.state.master_unlocked = true
	Master.set_day(m.state, Master.weekday(now), now)   # 준비: 오늘이 명장 요일
	await _frames(3)
	var bad_small := []
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		if not _top_right(m, letter) or not letter.alert:
			bad_small.append("%s 봉투 %s 느낌표 %s" % [size, letter.get_global_rect(), letter.alert])
	root.size = Feel.SMALL_SIZE
	await _frames(2)
	_report(none_before and bad_small.is_empty() and Master.is_visiting(m.state, now),
			"① NPC 없으면 봉투 없음 → 명장 날 작은 화면 3가지에서 오른쪽 위 봉투 + 느낌표 (동네 안·보이는 곳 안) %s" % [bad_small])

	var d = m.npc_dialog
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var want_effect := "오늘 효과: " + Fmt.master_bonus(b.master_bonuses, m.state.active_bonus)
	var open_ok: bool = m.is_full() and d.is_visible_in_tree() and d.who == "master" and d._name.text == "명장" \
			and d._line.text == "오늘 하루, 엔진은 내가 봐 주지." and d._effect.text == want_effect and m.state.active_bonus != "" \
			and d.close_button.is_visible_in_tree() and not d.yes_button.is_visible_in_tree() and not d._rule.visible \
			and letter.is_visible_in_tree() and not letter.alert and _in_window(d)
	_click(d.close_button.get_global_rect().get_center())
	await _frames(2)
	var closed: bool = not d.visible and m.is_full()
	_click(m.small_button.get_global_rect().get_center())
	await _frames(3)
	var small_after: bool = not m.is_full() and letter.is_visible_in_tree() and not letter.alert and not d.visible
	_report(open_ok and closed and small_after,
			"① 봉투 클릭 → 큰 화면 + 대화 창 '%s' / '%s' / '%s' [닫기], 느낌표만 꺼짐 → [닫기] → [작게] 해도 봉투는 남고 느낌표 꺼짐" % [
			d._name.text, d._line.text, d._effect.text])

	# 큰 화면에서 봉투 (동네 오른쪽 위) → 대화 창
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var big_rect: Rect2 = letter.get_global_rect()
	var area: Rect2 = Rect2(town.global_position + town.area().position, town.area().size)
	var big_place: bool = m.is_full() and letter.is_visible_in_tree() and area.encloses(big_rect) and big_rect.end.y < area.position.y + area.size.y * 0.25 \
			and big_rect.position.x > area.get_center().x
	_click(big_rect.get_center())
	await _frames(3)
	_report(big_place and d.is_visible_in_tree() and d.who == "master" and m.panel.building == "depot" and _in_window(d),
			"① 큰 화면: 동네 오른쪽 위 봉투 %s → 대화 창 (건물 화면 '%s' 그대로)" % [big_rect, m.panel.building])
	await _close(m)


## ②: 보험사·마술사·부품상 대화 창 (임시 칸 visitor_stub)
func _dialogs(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var letter = town.letter_button
	var d = m.npc_dialog
	m.visitor_stub = INSURER.duplicate()
	await _frames(2)
	var alert0: bool = letter.is_visible_in_tree() and letter.alert
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var ins_ok: bool = m.is_full() and d.is_visible_in_tree() and d._name.text == "보험사 직원" and d._line.text == "오늘 보험 가입하시겠어요?" \
			and d._effect.text == "오늘 이벤트 · 제휴 할인: 가입하면 오늘 강화 비용 50% 할인" \
			and d._rule.is_visible_in_tree() and d._rule.text.begins_with("보험료 = 강화 비용 × 퍼짐 확률 × 10.") \
			and d.yes_button.is_visible_in_tree() and d.no_button.is_visible_in_tree() and d.yes_button.text == "예" and d.no_button.text == "아니오" \
			and not d.close_button.is_visible_in_tree() and not d._status.visible
	var texts := [d._name.text, d._line.text, d._effect.text, d._rule.text]
	_click(d.no_button.get_global_rect().get_center())
	await _frames(2)
	var no_ok: bool = not d.visible and not m.visitor_stub["insured"]
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var again: bool = d.is_visible_in_tree() and d.yes_button.is_visible_in_tree()
	_click(d.yes_button.get_global_rect().get_center())
	await _frames(3)
	var yes_ok: bool = m.visitor_stub["insured"] and d.is_visible_in_tree() and d._status.is_visible_in_tree() \
			and d._status.text == "가입됨 · 오늘 퍼질 수 있는 강화마다 보험료가 같이 나가요" \
			and not d.yes_button.is_visible_in_tree() and not d.no_button.is_visible_in_tree() and d.close_button.is_visible_in_tree()
	_click(d.close_button.get_global_rect().get_center())
	await _frames(2)
	_report(alert0 and ins_ok and no_ok and again and yes_ok and not d.visible,
			"② 보험사: %s → [아니오] 닫힘·가입 안 됨 → 다시 열어 [예] → '%s' + [닫기]" % [texts, d._status.text])

	m.visitor_stub = INSURER.duplicate()
	m.visitor_stub["event"] = "recovery"
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var want_rec := "오늘 이벤트 · 복구 보험: 가입 안 해도 오늘 퍼지면 +%d 대신 +17에서 다시" % b.broken_drop_to
	_report(d.is_visible_in_tree() and d._effect.text == want_rec and d.yes_button.is_visible_in_tree(),
			"② 보험사 복구 보험 '%s' + [예] [아니오]" % d._effect.text)

	# 마술사 (다른 NPC가 오면 느낌표가 다시, 열려 있던 창은 닫힘) → 부품상
	m.visitor_stub = MAGICIAN.duplicate()
	await _frames(2)
	var mag_alert: bool = letter.alert and not d.visible
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var mag_ok: bool = mag_alert and d.is_visible_in_tree() and d._name.text == "마술사" and d._line.text == "오늘 하루, 세팅에 마법을 걸어 드리죠." \
			and d._effect.text == "오늘 효과: 세팅 돌리기 등급업 확률 ×2" and d.close_button.is_visible_in_tree() \
			and not d.yes_button.is_visible_in_tree() and not d._rule.visible and not d._status.visible and not letter.alert
	var mag_texts := [d._name.text, d._effect.text]
	m.visitor_stub = DEALER.duplicate()
	await _frames(2)
	var dealer_alert: bool = letter.alert and not d.visible
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var want_gift := "선물: 고급 스페어 엔진 1개 (퍼지면 +%d 대신 +17에서 다시, 보관 가능)" % b.broken_drop_to
	var dealer_ok: bool = dealer_alert and d.is_visible_in_tree() and d._name.text == "중고 부품상" and d._effect.text == want_gift \
			and d.close_button.is_visible_in_tree() and not d.yes_button.is_visible_in_tree()
	_report(mag_ok and dealer_ok, "② 마술사 %s [닫기] → 부품상 '%s' [닫기] (새 NPC마다 느낌표 다시)" % [mag_texts, d._effect.text])

	# 다음 날 같은 NPC면 느낌표 다시 → NPC가 떠나면 봉투·창 사라짐
	m.now_local_override = now + DAY
	await _frames(2)
	var next_day: bool = letter.visible and letter.alert
	m.visitor_stub = {}
	await _frames(2)
	_report(next_day and not letter.visible and not d.visible, "② 다음 날이면 느낌표 다시, NPC가 떠나면 봉투·대화 창 사라짐")
	await _close(m)


## ③: 급송 전화 아이콘
func _phone(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var phone = town.rush_button
	var letter = town.letter_button
	m.visitor_stub = MAGICIAN.duplicate()
	await _ring(m)
	var bad := []
	for size: Vector2i in SMALL_SIZES:
		root.size = size
		await _frames(3)
		town.notify("알림 확인용 한 줄입니다 길게 길게")
		await _frames(2)
		var pr: Rect2 = phone.get_global_rect()
		var lr: Rect2 = letter.get_global_rect()
		if not _top_right(m, phone) or not _top_right(m, letter):
			bad.append("%s 전화 %s / 봉투 %s 오른쪽 위·보이는 곳 밖" % [size, pr, lr])
		if pr.intersects(lr) or pr.position.x > lr.position.x:
			bad.append("%s 전화 %s ↔ 봉투 %s" % [size, pr, lr])
		var nr: Rect2 = town._notice.get_global_rect()
		if town._notice.visible and (nr.intersects(pr) or nr.intersects(lr)):
			bad.append("%s 알림 %s ↔ 아이콘" % [size, nr])
		for i in 10:
			town.show_payout(i % Feel.TOWN_HOUSES, 1875 * (i + 1), ["normal", "large", "vip"][i % 3], i % 2 == 0)
		await _frames(1)
		if m.visible_rects().size() > 30:
			bad.append("%s 아이콘 + 글자 10개: 사각형 %d개" % [size, m.visible_rects().size()])
	root.size = Feel.SMALL_SIZE
	await _frames(3)
	_report(bad.is_empty(), "③ 작은 화면 3가지: 전화 아이콘·봉투가 오른쪽 위 (보이는 곳 안), 나란히 안 겹침, 알림은 그 왼쪽, 글자 10개에도 사각형 30개 이하 %s" % [bad])

	_click(phone.get_global_rect().get_center())
	await _frames(2)
	_report(not m.is_full() and not phone.visible and Rush.parcels_left(m.state) == b.rush_parcels and town._rush_left.is_visible_in_tree(),
			"③ 작은 화면 전화 아이콘 클릭 → 큰 화면 안 열림, 받음 (%s)" % town._rush_left.text)

	m.state.rush_left = 0
	_click(town.building_rects()["car_center"].get_center())
	await _frames(3)
	await _ring(m)
	var big_seen: bool = m.is_full() and phone.is_visible_in_tree()
	_click(phone.get_global_rect().get_center())
	await _frames(2)
	_report(big_seen and m.is_full() and m.panel.building == "car_center" and not phone.visible and Rush.parcels_left(m.state) == b.rush_parcels
			and not m.npc_dialog.visible,
			"③ 큰 화면 전화 아이콘 클릭 → 받음 (급송 %d건), 건물 화면 '%s' 그대로" % [Rush.parcels_left(m.state), m.panel.building])
	await _close(m)


## ④: en 글자, "큐브" 없음, 큰 화면 5가지에서 대화 창이 창 안 (ko·en)
func _lang_and_fit(b: Balance) -> void:
	var fit := {}
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		Save.delete_file(TEST_SAVE)
		var m := await _launch(b)
		var d = m.npc_dialog
		var texts := []
		fit[locale] = []
		var letter = m.town.letter_button
		for who in ["insurer", "magician", "dealer", "master"]:
			match who:
				"insurer": m.visitor_stub = INSURER.duplicate()
				"magician": m.visitor_stub = MAGICIAN.duplicate()
				"dealer": m.visitor_stub = DEALER.duplicate()
				"master":
					m.visitor_stub = {}
					m.state.master_unlocked = true
					Master.set_day(m.state, Master.weekday(now), now)
			await _frames(2)
			_click(letter.get_global_rect().get_center())
			await _frames(3)
			texts.append_array(_visible_texts(d))
			if who == "insurer":
				# 복구 보험 → [예] → 가입됨 글 → 다시 가입 전으로 (가장 긴 창: 이벤트 + 규칙 + [예] [아니오])
				_click(d.no_button.get_global_rect().get_center())
				m.visitor_stub["event"] = "recovery"
				await _frames(2)
				_click(letter.get_global_rect().get_center())
				await _frames(3)
				texts.append(d._effect.text)
				_click(d.yes_button.get_global_rect().get_center())
				await _frames(2)
				texts.append(d._status.text)
				_click(d.close_button.get_global_rect().get_center())
				m.visitor_stub["insured"] = false
				await _frames(2)
				_click(letter.get_global_rect().get_center())
				await _frames(3)
				for size: Vector2i in FIT_SIZES:
					root.size = size
					await _frames(3)
					if not _in_window(d) or not d.yes_button.is_visible_in_tree():
						fit[locale].append("%s 보험사 창 %s" % [size, d.get_global_rect()])
				root.size = Vector2i(1600, 900)
				await _frames(2)
			_click(m.small_button.get_global_rect().get_center())
			await _frames(2)
		if locale == "en":
			var bad := texts.filter(func(x): return _untranslated(String(x)))
			_report(bad.is_empty() and texts.size() >= 16, "④ en 대화 창 4명·이벤트 2개 글자 %d개에 한글·키 없음 %s" % [texts.size(), bad])
			print("    en: %s" % [texts])
		await _close(m)
	TranslationServer.set_locale("ko")
	var cube := []
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.contains("큐브") or line.to_lower().contains("cube"):
			cube.append(line.get_slice(",", 0))
	_report(cube.is_empty(), "④ 번역 파일(ko·en)에 '큐브'·'cube' 없음 (화면은 '세팅 돌리기') %s" % [cube])
	_report(fit["ko"].is_empty() and fit["en"].is_empty(), "④ ko·en 큰 화면 %d가지: 보험사 대화 창이 창 안 %s %s" % [FIT_SIZES.size(), fit["ko"], fit["en"]])


## 아이콘이 작은 화면 동네 오른쪽 위(오른쪽 1/4, 위 1/4)이고 동네 안·보이는 곳 안인가
func _top_right(m: Node, icon: Control) -> bool:
	var town = m.town
	var r: Rect2 = icon.get_global_rect()
	var area := Rect2(town.global_position + town.area().position, town.area().size)
	return icon.is_visible_in_tree() and area.encloses(r) and _enclosed(m.visible_rects(), r) \
			and r.position.x > area.position.x + area.size.x * 0.75 and r.end.y < area.position.y + area.size.y * 0.25


func _in_window(c: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(c.get_global_rect())


## 준비: 벨 시계를 거의 다 돌려 두고 진짜 프레임으로 벨이 울릴 때까지 (그 뒤 게임 시간 멈춤)
func _ring(m: Node) -> void:
	m.state.rush_next = 0.2
	Engine.time_scale = 1.0
	await _until(func(): return Rush.is_ringing(m.state) and m.town.rush_button.visible, 5.0)
	Engine.time_scale = 0.0
	await _frames(2)


func _untranslated(x: String) -> bool:
	for prefix in ["NPC_", "SETTINGS_", "MASTER_"]:
		if x.begins_with(prefix):
			return true
	return _hangul.search(x) != null


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


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤, 할 일 다 끝냄: 알림이 덜 뜨게)
func _launch(b: Balance) -> Node:
	Engine.time_scale = 1.0
	root.size = Feel.SMALL_SIZE
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	m.now_local_override = now
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else Vector2i(1600, 900))
	m.state.quest_index = Quest.count(b)
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
