## v7-bal 화면 완료 기준 자동 확인 (U1 강화·세팅·물류센터 + U2 편지봉투·NPC 대화 창·급송 전화 아이콘).
## 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 확인한다. 방문일·단계·돈·벨 시계를 미리 넣는 것은 준비로만 하고,
## 확인하는 동작은 진짜 클릭이나 진짜 프레임(main이 Master.tick → Visitor.tick → take_events)으로 한다.
## ① 편지봉투: NPC 없으면 없음, 명장 날 작은 화면 오른쪽 위에 봉투 + 느낌표 (보이는 곳 안) → 누르면 큰 화면 + 대화 창,
##    느낌표만 꺼지고 봉투는 남음 (작게 해도), [닫기], 큰 화면에서도 봉투 → 대화 창
## ② 보험사(제휴 할인): 방문 알림, 대화 창 이름·대사·이벤트·보험료 규칙·[예] [아니오] → [아니오] 닫힘·가입 안 됨 → 다시 열어 [예] → "가입됨"·저장(insured_day)
##    강화 칸: +17은 할인 비용만 (보험료 줄 없음), +18은 "보험 가입 중 · 보험료 +N · 합계"·"보험: 퍼져도 단계 유지"·N번 시도 = Economy.tries,
##    스페어 0개로 누름, 퍼짐 → "보험 덕분에 살았어요!", 빠진 돈 = 할인 비용 + 보험료
## ③ 보험사(복구 보험, 가입 안 함): 대화 창 이벤트 글, 강화 칸 "+17로"(Enhance.drop_to) + 복구 보험 설명 줄, 퍼짐 → "복구 보험 덕분에 +17에서 다시"
## ④ 중고 부품상: 선물 알림·고급 스페어 +1 (봉투를 안 눌러도), 대화 창, 강화 칸 "고급 N개"·[고급 스페어 쓰기] → state.use_premium·저장,
##    퍼짐 → "고급 스페어 엔진 1개 사용 → +17에서 다시"
## ⑤ 마술사: 방문 알림, 대화 창, 세팅 칸 등급업 확률 옆 "(마술사 ×2)" (다음 날 없음)
## ⑥ 새 날 새 NPC면 느낌표 다시, NPC가 떠나면(다음 날) 봉투·대화 창 사라짐
## ⑦ 급송 전화 아이콘: 작은 화면 오른쪽 위 (보이는 곳 안), 봉투와 나란히 안 겹침·알림과 안 겹침,
##    누르면 큰 화면 없이 받음 (급송 N건), 큰 화면에서도 아이콘 → 받음 (건물 화면 그대로), 아이콘 + 봉투 + 글자 10개에도 사각형 30개 이하
## ⑧ 주간 보상: 물류센터 줄 "지금 N원 + 경험치" (Weekly.reward_money = 지금 받으면), 달성 알림 "+N원 · 경험치" = 들어온 돈
## ⑨ 번역·창 크기: en 대화 창 4명·강화 칸·결과·알림 글자에 한글·키 없음, 번역 파일에 "큐브" 없음,
##    큰 화면 5가지에서 보험사 대화 창, 강화 칸 (보험료 줄 + [고급 스페어 쓰기] / 복구 보험 줄 + 스페어 없음)이 창 안
## ⑩ 시내 그림 (U3): 창업 전에는 동네 그대로 (집 TOWN_HOUSES채, 빌딩 실루엣 없음)
## ⑪ 창업 뒤 (계산 노선 "city"): 시내 그림, 정차할 곳 수 = Trip.lap_cargo (세팅 없음 40), 회사 건물이 섞임, 집끼리·길·건물·구석 줄과 안 겹침, 큰 화면에서도
## ⑫ 시내 첫 바퀴 (진짜 프레임, 트럭 자리 = Trip.lap_stop_progress): "+돈" 수 = 계산 배송 수 = lap_cargo, 0번 집부터 차례로 한 번씩,
##    배송 때 트럭이 그 집 앞, 집마다 섬
## ⑬ 띠 보이는 곳 (세팅 없음 40곳 / 적재량 3줄 최고 등급 = ceil(Trip.cargo)곳): 빌딩 실루엣·집이 visible_rects() 안, 집끼리·길·건물과 안 겹침,
##    전화 아이콘과 안 겹침, 아이콘 + 글자 10개에도 사각형 30개 이하
## 현지 시각은 main.now_local_override로 고정 (2026-11-18 수요일 12:00부터 하루씩). 결과를 정해야 하는 강화는 main의 난수 씨앗을 미리 골라 둔다.
## 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v7bal.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const CSV_PATH := "res://locale/strings.csv"
const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Master = preload("res://scripts/core/master.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Visitor = preload("res://scripts/core/visitor.gd")
const Weekly = preload("res://scripts/core/weekly.gd")
const Company = preload("res://scripts/core/company.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_v7bal.json"
const TEST_SETTINGS := "user://test_v7bal_settings.cfg"
const DAY := 86400
const SMALL_SIZES := [Vector2i(480, 220), Vector2i(720, 330), Vector2i(960, 440)]
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]

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
	await _visitors(b)
	await _phone(b)
	await _weekly(b)
	await _city(b)
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
	_report(none_before and bad_small.is_empty() and Master.is_visiting(m.state, now) and Visitor.today(m.state) == "",
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


## ②~⑥: 보험사(제휴 할인 → 다음 날 복구 보험) → 부품상 → 마술사 → 떠남. 한 판에서 하루씩
func _visitors(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var letter = town.letter_button
	var d = m.npc_dialog
	var p = m.panel
	var t = m.state.truck(0)
	var day := _day_of(m)

	# ② 보험사 (제휴 할인): 알림 → 봉투 → [아니오] → 다시 [예] → 가입됨·저장
	await _visit(m, "insurer", "partner_discount")
	var noticed: bool = _noticed_prefix(town, "보험사 직원이 왔어요 · 오늘 이벤트: ")
	var alert0: bool = letter.is_visible_in_tree() and letter.alert
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var ins_ok: bool = m.is_full() and d.is_visible_in_tree() and d._name.text == "보험사 직원" and d._line.text == "오늘 보험 가입하시겠어요?" \
			and d._effect.text == "오늘 이벤트 · 제휴 할인: 가입하면 오늘 강화 비용 %s 할인" % Fmt.percent(b.partner_discount) \
			and d._rule.is_visible_in_tree() and d._rule.text.begins_with("보험료 = 강화 비용 × 퍼짐 확률 × %s." % Fmt.num(b.insure_fee_mult)) \
			and d.yes_button.is_visible_in_tree() and d.no_button.is_visible_in_tree() and d.yes_button.text == "예" and d.no_button.text == "아니오" \
			and not d.close_button.is_visible_in_tree() and not d._status.visible
	var texts := [d._name.text, d._line.text, d._effect.text, d._rule.text]
	_click(d.no_button.get_global_rect().get_center())
	await _frames(2)
	var no_ok: bool = not d.visible and not Visitor.is_insured(m.state)
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var again: bool = d.is_visible_in_tree() and d.yes_button.is_visible_in_tree()
	_click(d.yes_button.get_global_rect().get_center())
	var saved = _saved_state(b)
	await _frames(3)
	var yes_ok: bool = Visitor.is_insured(m.state) and saved != null and saved.insured_day == day and d.is_visible_in_tree() \
			and d._status.is_visible_in_tree() and d._status.text == "가입됨 · 오늘 퍼질 수 있는 강화마다 보험료가 같이 나가요" \
			and not d.yes_button.is_visible_in_tree() and not d.no_button.is_visible_in_tree() and d.close_button.is_visible_in_tree()
	_click(d.close_button.get_global_rect().get_center())
	await _frames(2)
	_report(noticed and alert0 and ins_ok and no_ok and again and yes_ok and not d.visible,
			"② 보험사 알림·봉투: %s → [아니오] 닫힘·가입 안 됨 → 다시 열어 [예] → '%s' + [닫기], 저장 insured_day = 오늘" % [texts, d._status.text])

	# ② 가입한 날 강화 칸: +17 할인 비용만 → +18 보험료 줄·합계·N번 → 스페어 0개로 눌러 퍼짐 → "보험 덕분에"
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	_click(p.engine_tab_button.get_global_rect().get_center())
	t.star = 17
	m.state.spares = 0
	var cost17 := Economy.enhance_cost(b, 17, m.state)
	m.state.money = cost17 * 10
	await _frames(2)
	var line17: String = p._cost.text
	var ok17: bool = cost17 == roundi(Economy.base_enhance_cost(b, 17) * (1.0 - b.partner_discount)) and not p._insure.visible \
			and line17 == "비용 %s원 (제휴 할인 %s)" % [Fmt.money(cost17), Fmt.percent(b.partner_discount)] and Enhance.insure_fee(m.state, b, 0) == 0
	t.star = 18
	var cost := Economy.enhance_cost(b, 18, m.state)
	var fee := Enhance.insure_fee(m.state, b, 0)
	m.state.money = (cost + fee) * 2 + 1
	await _frames(2)
	var line18: String = p._insure.text
	var ok18: bool = fee > 0 and fee == roundi(Economy.base_enhance_cost(b, 18) * b.destroy[18] * b.insure_fee_mult) and p._insure.is_visible_in_tree() \
			and line18 == "보험 가입 중 · 보험료 +%s원 · 합계 %s원" % [Fmt.money(fee), Fmt.money(cost + fee)] \
			and p._cost.text == "비용 %s원 (제휴 할인 %s)" % [Fmt.money(cost), Fmt.percent(b.partner_discount)] \
			and p._danger.text == "보험: 퍼져도 단계 유지" and Economy.tries(m.state, b, 0) == 2 and p._tries.text == "지금 돈이면 2번 시도 가능" \
			and not p._enhance_button.disabled and not p._danger_note.visible
	var c18 := Enhance.chances(b, 18)   # 새 트럭 (세팅·명장 없음) = 굴리는 확률
	var lo: float = c18["success"]
	var hi: float = lo + c18["destroy"]
	m.rng.seed = _seed_for(func(r1: float, _r2: float): return r1 >= lo and r1 < hi)   # 퍼짐이 뜨는 씨앗
	var money0: int = m.state.money
	await _press_enhance(m)
	var saved_text: String = p._result.text
	_report(ok17 and ok18 and saved_text == "보험 덕분에 살았어요! (+18 그대로)" and t.star == 18 and m.state.spares == 0 and money0 - m.state.money == cost + fee,
			"② 가입한 날 강화 칸: +17 '%s' (보험료 줄 없음) / +18 '%s' · '%s' · '%s', 스페어 0개로 눌러 퍼짐 → '%s', 빠진 돈 %s원 = 할인 비용 + 보험료" % [
			line17, p._cost.text, line18, p._tries.text, saved_text, Fmt.money(money0 - m.state.money)])

	# ③ 다음 날 보험사 (복구 보험, 가입 안 함): 이벤트 글 → 강화 칸 설명 줄 → 퍼짐 → "+17에서 다시"
	m.now_local_override = now + DAY
	await _visit(m, "insurer", "recovery")
	var rec_alert: bool = letter.alert and not Visitor.is_insured(m.state)
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var want_rec := "오늘 이벤트 · 복구 보험: 가입 안 해도 오늘 퍼지면 +%d 대신 +%d에서 다시" % [b.broken_drop_to, b.recovery_star]
	var rec_dialog: bool = d.is_visible_in_tree() and d._effect.text == want_rec and d.yes_button.is_visible_in_tree()
	_click(d.no_button.get_global_rect().get_center())
	t.star = 18
	m.state.spares = 1
	cost = Economy.enhance_cost(b, 18, m.state)
	m.state.money = cost * 3
	await _frames(2)
	var rec_note: String = p._danger_note.text
	var rec_panel: bool = not p._insure.visible and p._cost.text == "비용 %s원" % Fmt.money(cost) \
			and rec_note == "퍼지면 스페어 엔진 1개를 자동으로 써서 +%d로 (트럭은 계속 달림)\n오늘은 복구 보험: 가입 안 해도 퍼지면 +%d에서 다시" % [
				Enhance.drop_to(m.state, b, 0), b.recovery_star] and Enhance.drop_to(m.state, b, 0) == b.recovery_star \
			and p._danger.text.begins_with("퍼질 확률")
	m.rng.seed = _seed_for(func(r1: float, _r2: float): return r1 >= lo and r1 < hi)
	await _press_enhance(m)
	var rec_result: String = p._result_note.text
	_report(rec_alert and rec_dialog and rec_panel and rec_result == "복구 보험 덕분에 +%d에서 다시 (남은 스페어 0개)" % b.recovery_star
			and t.star == b.recovery_star and m.state.spares == 0,
			"③ 복구 보험: 대화 창 '%s', 강화 칸 '%s', 퍼짐 → '%s' (+%d)" % [d._effect.text, rec_note.replace("\n", " / "), rec_result, t.star])

	# ④ 다음 날 중고 부품상: 선물 알림·고급 스페어 +1 → 대화 창 → 강화 칸 [고급 스페어 쓰기] → 퍼짐 → "+17에서 다시"
	m.now_local_override = now + 2 * DAY
	t.star = 18
	m.state.spares = 0
	m.state.premium_spares = 0
	m.state.use_premium = false
	await _visit(m, "dealer")
	var gift_ok: bool = m.state.premium_spares == b.dealer_premium_spares and _noticed(town, "중고 부품상이 왔어요 · 고급 스페어 엔진 +%d" % b.dealer_premium_spares) \
			and letter.alert
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var want_gift := "선물: 고급 스페어 엔진 %d개 (퍼지면 +%d 대신 +%d에서 다시, 보관 가능)" % [b.dealer_premium_spares, b.broken_drop_to, b.premium_drop_to]
	var dealer_dialog: bool = d.is_visible_in_tree() and d._name.text == "중고 부품상" and d._line.text == "좋은 물건 하나 들고 왔어. 선물이야." \
			and d._effect.text == want_gift and d.close_button.is_visible_in_tree() and not d.yes_button.is_visible_in_tree()
	_click(d.close_button.get_global_rect().get_center())
	cost = Economy.enhance_cost(b, 18, m.state)
	m.state.money = cost * 3
	await _frames(2)
	var pb = p.premium_button
	var before_ok: bool = p._spares.text == "스페어 엔진 0개 · 고급 1개" and pb.is_visible_in_tree() and not pb.button_pressed \
			and p._enhance_button.disabled and p._wait.text == tr("GARAGE_NEED_SPARE")
	_click(pb.get_global_rect().get_center())
	var saved_p = _saved_state(b)
	await _frames(2)
	var on_ok: bool = m.state.use_premium and pb.button_pressed and saved_p != null and saved_p.use_premium and not p._enhance_button.disabled \
			and p._danger_note.text == "퍼지면 고급 스페어 엔진(1개 있음)을 먼저 써서 +%d로 (트럭은 계속 달림)" % b.premium_drop_to
	m.rng.seed = _seed_for(func(r1: float, _r2: float): return r1 >= lo and r1 < hi)
	await _press_enhance(m)
	var prem_result: String = p._result_note.text
	_report(gift_ok and dealer_dialog and before_ok and on_ok and prem_result == "고급 스페어 엔진 1개 사용 → +%d에서 다시 (남은 고급 0개)" % b.premium_drop_to
			and t.star == b.premium_drop_to and m.state.premium_spares == 0 and not pb.visible,
			"④ 부품상: 알림·고급 스페어 +%d, 대화 창 '%s', 강화 칸 '%s' [%s] → 켬·저장, 퍼짐 → '%s'" % [
			b.dealer_premium_spares, d._effect.text, "스페어 엔진 0개 · 고급 1개", pb.text, prem_result])

	# ⑤ 다음 날 마술사: 알림 → 대화 창 → 세팅 칸 "(마술사 ×2)" → 다음 날 없음
	m.now_local_override = now + 3 * DAY
	await _visit(m, "magician")
	var mag_notice := "마술사가 왔어요 · 오늘 세팅 돌리기 등급업 확률 ×%s" % Fmt.num(b.magician_up_mult)
	var mag_alert: bool = letter.alert and _noticed(town, mag_notice)
	_click(letter.get_global_rect().get_center())
	await _frames(3)
	var mag_dialog: bool = d.is_visible_in_tree() and d._name.text == "마술사" and d._line.text == "오늘 하루, 세팅에 마법을 걸어 드리죠." \
			and d._effect.text == "오늘 효과: 세팅 돌리기 등급업 확률 ×%s" % Fmt.num(b.magician_up_mult) and d.close_button.is_visible_in_tree() \
			and not d._rule.visible
	_click(d.close_button.get_global_rect().get_center())
	_click(p.setting_tab_button.get_global_rect().get_center())
	await _frames(3)
	var st = p.setting
	var up_mag: String = st._up.text
	var want_up := "등급업 확률 %s (마술사 ×%s)" % [Fmt.percent(Setting.up_chance(b, 0, m.state)), Fmt.num(b.magician_up_mult)]
	var mag_up: bool = up_mag.begins_with(want_up) and is_equal_approx(Setting.up_chance(b, 0, m.state), minf(1.0, b.up_chance[0] * b.magician_up_mult))

	# ⑥ 다음 날: 마술사가 떠남 → 봉투·세팅 칸 "마술사" 없음. 대화 창을 열어 둔 채로 날이 바뀌면 창도 닫힘
	_click(letter.get_global_rect().get_center())
	await _frames(2)
	var open_before: bool = d.visible
	m.now_local_override = now + 4 * DAY
	m.state.visitor_next["insurer"] = day + 30   # 준비: 다음 날 아무도 안 오게
	m.state.visitor_next["magician"] = day + 30
	m.state.visitor_next["dealer"] = day + 30
	await _frames(3)
	var up_next: String = st._up.text
	_report(mag_alert and mag_dialog and mag_up and not up_next.contains("마술사"),
			"⑤ 마술사: 알림 '%s', 대화 창 '%s', 세팅 칸 '%s' → 다음 날 '%s'" % [mag_notice, d._effect.text, up_mag, up_next])
	_report(alert0 and rec_alert and gift_ok and mag_alert and open_before and not d.visible and not letter.visible and Visitor.today(m.state) == "",
			"⑥ 새 날 새 NPC마다 느낌표 다시 (보험사 → 보험사 → 부품상 → 마술사), 다음 날 NPC가 떠나면 봉투·열려 있던 대화 창 사라짐")
	await _close(m)


## ⑦: 급송 전화 아이콘
func _phone(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var phone = town.rush_button
	var letter = town.letter_button
	m.state.rush_enabled = true
	await _visit(m, "magician")
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
	_report(bad.is_empty(), "⑦ 작은 화면 3가지: 전화 아이콘·봉투가 오른쪽 위 (보이는 곳 안), 나란히 안 겹침, 알림은 그 왼쪽, 글자 10개에도 사각형 30개 이하 %s" % [bad])

	_click(phone.get_global_rect().get_center())
	await _frames(2)
	_report(not m.is_full() and not phone.visible and Rush.parcels_left(m.state) == b.rush_parcels and town._rush_left.is_visible_in_tree()
			and town._rush_left.text == "급송 %d건 남음" % b.rush_parcels,
			"⑦ 작은 화면 전화 아이콘 클릭 → 큰 화면 안 열림, 받음 (%s)" % town._rush_left.text)

	m.state.rush_left = 0
	_click(town.building_rects()["car_center"].get_center())
	await _frames(3)
	await _ring(m)
	var big_seen: bool = m.is_full() and phone.is_visible_in_tree()
	_click(phone.get_global_rect().get_center())
	await _frames(2)
	_report(big_seen and m.is_full() and m.panel.building == "car_center" and not phone.visible and Rush.parcels_left(m.state) == b.rush_parcels
			and not m.npc_dialog.visible,
			"⑦ 큰 화면 전화 아이콘 클릭 → 받음 (급송 %d건), 건물 화면 '%s' 그대로" % [Rush.parcels_left(m.state), m.panel.building])
	await _close(m)


## ⑧: 주간 보상 글 (물류센터 [창고·할 일] 줄 → 달성 알림·들어온 돈)
func _weekly(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	m.state.truck(0).star = 12   # 준비: 하루치 돈이 0이 아니게
	m.state.weekly_parcels = Weekly.target(b) - 1
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(2)
	var reward := Weekly.reward_money(b, m.state)
	var line: String = d._weekly.text
	var want := "이번 주 %s / %s건 → 지금 %s원 + 경험치 %s" % [Fmt.count(Weekly.target(b) - 1), Fmt.count(Weekly.target(b)), Fmt.money(reward), Fmt.count(b.weekly_xp)]
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	await _until(func(): return Weekly.is_done(m.state), 30.0)
	Engine.time_scale = 0.0
	var want_notice := "주간 배송 목표 달성! +%s원 · 경험치 +%s" % [Fmt.money(reward), Fmt.count(b.weekly_xp)]
	await _until(func(): return _noticed_prefix(town, want_notice), 3.0)
	_report(reward > 0 and line == want and _noticed_prefix(town, want_notice),
			"⑧ 주간 목표 '%s' → 달성 알림 '%s'" % [line, want_notice])
	await _close(m)


## ⑩~⑬: 시내 그림 (창업 전 동네 → 창업 뒤 도시 배경·회사 건물·정차할 곳 = lap_cargo, 집마다 서며 "+돈" = 배송, 띠 보이는 곳)
func _city(b: Balance) -> void:
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var town = m.town
	var s = m.state
	s.truck(0).star = b.max_star   # 준비: 가장 빠른 단계 (집 사이가 먼 곳에서도 트럭이 배송 전에 닿나)
	var houses_before: Array = town._houses.duplicate()
	_report(not town.city and Trip.route_id(s, 0) == "town" and houses_before == Feel.TOWN_HOUSE_SPOTS.slice(0, Feel.TOWN_HOUSES)
			and not _enclosed(m.visible_rects(), _global(town, town.skyline_rect())),
			"⑩ 창업 전: 동네 그림 그대로 (집 %d채 = TOWN_HOUSES, 빌딩 실루엣 없음)" % houses_before.size())

	s.money = b.agency_price
	Company.found(b, s)   # 준비 (창업 클릭은 check_v7a ①). 게임 시간이 멈춰 있어서 첫 바퀴부터 시내
	await _frames(3)
	var n := Trip.lap_cargo(b, s, 0)
	var companies := 0
	for i in town._houses.size():
		companies += 1 if town.is_company(i) else 0
	var bad := []
	_city_overlaps(m, bad, "작은 화면")
	_click(town.building_rects()["depot"].get_center())
	await _frames(3)
	var full_ok: bool = m.is_full() and town.city and town.show_ground and town._houses.size() == n
	_city_overlaps(m, bad, "큰 화면")
	_click(m.small_button.get_global_rect().get_center())
	await _frames(3)
	_report(town.city and Trip.route_id(s, 0) == "city" and n == roundi(b.base_cargo * b.routes["city"]["stops_mult"]) and town._houses.size() == n
			and companies > 0 and companies < n and full_ok and bad.is_empty(),
			"⑪ 창업 뒤: 시내 그림, 정차할 곳 %d곳 = lap_cargo %d (회사 건물 %d곳), 큰 화면에서도, 겹침 없음 %s" % [town._houses.size(), n, companies, bad])

	# ⑫ 첫 바퀴 (창업 뒤 아직 게임 시간이 안 흘러서 트럭은 물류센터 앞, 바퀴 처음)
	var tk = town.trucks[0]
	var start_ok: bool = s.truck(0).lap_clock == 0.0 and tk.distance() == 0.0
	Engine.time_scale = 10.0
	var log0: int = town.payout_log.size()
	var parcels0: int = s.parcels_total
	var seen := log0
	var houses := []
	var at_house := 0
	var stood := {}
	var lap_parcels := -1
	var prev_dist := 0.0   # 지난 프레임 끝 트럭 자리 (배송과 다음 집으로 떠나기가 한 프레임에 같이 나면, 배송 때 자리는 이것)
	var t0 := Time.get_ticks_msec()
	while houses.size() < n and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		for e: Array in town.payout_log.slice(seen):
			houses.append(e[2])
			at_house += 1 if e[2] in [_nearest(town._stops, prev_dist), _nearest(town._stops, tk.distance())] else 0
		seen = town.payout_log.size()
		prev_dist = tk.distance()
		if houses.size() == n:
			lap_parcels = s.parcels_total - parcels0
		var k := _nearest(town._stops, tk.distance())
		if tk.speed() == 0.0 and absf(town._stops[k] - tk.distance()) < 0.5:
			stood[k] = true
	Engine.time_scale = 0.0
	var order := []
	for i in n:
		order.append(i)
	_report(start_ok and houses == order and lap_parcels == n and at_house == n and stood.size() >= n - 1,
			"⑫ 시내 첫 바퀴: '+돈' %d번 = 계산 배송 %d건 = lap_cargo %d, 집 0번부터 차례로 (%s), 배송 때 트럭이 그 집 앞 %d번, 선 집 %d곳" % [
			houses.size(), lap_parcels, n, houses == order, at_house, stood.size()])

	# ⑬ 띠 보이는 곳 (작은 화면 3가지 × 세팅 없음 / 적재량 3줄 최고 등급): 빌딩 실루엣·집 안, 안 겹침, 아이콘 + 글자 10개에도 사각형 30개 이하
	m.state.rush_left = 0
	await _ring(m)
	var bad_rects := []
	var spot_counts := []
	var cargo_was: Dictionary = s.truck(0).part("cargo_box").duplicate(true)
	for full_cargo in [false, true]:
		if full_cargo:   # 준비: 적재함 최고 등급 + 적재량 3줄 → 정차할 곳이 가장 많을 때
			s.truck(0).part("cargo_box")["grade"] = b.lines_by_grade.size() - 1
			s.truck(0).part("cargo_box")["lines"] = ["cargo", "cargo", "cargo"]
			await _frames(2)
		spot_counts.append([town._houses.size(), ceili(Trip.cargo(b, s, 0))])
		for size: Vector2i in SMALL_SIZES:
			root.size = size
			await _frames(3)
			_city_overlaps(m, bad_rects, "%s곳 %s" % [town._houses.size(), size])
			var rects: Array = m.visible_rects()
			if not _enclosed(rects, _global(town, town.skyline_rect())):
				bad_rects.append("%s 빌딩 실루엣" % size)
			for spot in town._houses:
				if not _enclosed(rects, _global(town, town._house_rect(spot))):
					bad_rects.append("%s 집 %s" % [size, spot])
			var icon := Rect2(town.rush_button.position, town.rush_button.size)
			for spot in town._houses:
				if icon.intersects(town.view_rect(town._house_rect(spot))):
					bad_rects.append("%s 전화 아이콘 ↔ 집" % size)
			for i in 10:
				town.show_payout(i * 4, 2250 * (i + 1), ["normal", "large", "vip"][i % 3], i % 2 == 0)
			await _frames(1)
			if m.visible_rects().size() > 30:
				bad_rects.append("%s 전화 아이콘 + 글자 10개: 사각형 %d개" % [size, m.visible_rects().size()])
	s.truck(0).part("cargo_box").merge(cargo_was, true)
	root.size = Feel.SMALL_SIZE
	await _frames(2)
	_report(bad_rects.is_empty() and spot_counts[0][0] == n and spot_counts[1][0] == spot_counts[1][1] and spot_counts[1][0] > n,
			"⑬ 시내 띠: 정차할 곳 [그린 곳, ceil(평균 적재량)] %s 둘 다 빌딩 실루엣·집이 보이는 곳 안, 안 겹침, 아이콘 + 글자 10개에도 사각형 30개 이하 %s" % [
			spot_counts, bad_rects])
	await _close(m)


## 시내 집·회사 건물이 동네 안이고 서로·길·건물(빛남 포함)·구석 줄과 안 겹치나 (어긋나면 bad에)
func _city_overlaps(m: Node, bad: Array, where: String) -> void:
	var town = m.town
	var others := [["구석 줄", Rect2(town._hud.position, town._hud.size).merge(Rect2(town._quest_label.position, town._quest_label.size))]]
	for id: String in town.building_rects():
		others.append([id, town.building_rects()[id].grow(Feel.BUILDING_GLOW_PX * town.zoom)])
	for piece: Rect2 in town.route.pieces:
		others.append(["길", town.view_rect(piece.grow(Feel.TOWN_ROAD_WIDTH / 2.0))])
	var prev := Rect2()
	for spot in town._houses:
		var r: Rect2 = town.view_rect(town._house_rect(spot))
		if not town.area().encloses(r) or r.intersects(prev):
			bad.append("%s 집 %s 동네 밖이거나 옆집과 겹침" % [where, spot])
		for o in others:
			if r.intersects(o[1]):
				bad.append("%s 집 %s ↔ %s" % [where, spot, o[0]])
		prev = r


## 동네 설계 좌표 사각형 → 창 좌표
func _global(town: Node, r: Rect2) -> Rect2:
	var v: Rect2 = town.view_rect(r)
	return Rect2(v.position + town.global_position, v.size)


## 길 위 거리 d에서 가장 가까운 서는 곳 번호
func _nearest(stops: PackedFloat64Array, d: float) -> int:
	var best := 0
	for i in stops.size():
		if absf(stops[i] - d) < absf(stops[best] - d):
			best = i
	return best


## ⑨: en 글자, "큐브" 없음, 큰 화면 5가지에서 대화 창·강화 칸이 창 안 (ko·en)
func _lang_and_fit(b: Balance) -> void:
	var fit := {}
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		Save.delete_file(TEST_SAVE)
		var m := await _launch(b)
		var d = m.npc_dialog
		var p = m.panel
		var town = m.town
		var letter = town.letter_button
		var t = m.state.truck(0)
		var texts := []
		fit[locale] = []
		var day_i := 0
		for who in ["insurer", "magician", "dealer", "master"]:
			m.now_local_override = now + day_i * DAY
			day_i += 1
			if who == "master":
				m.state.visitor_next = { "insurer": _day_of(m) + 20, "magician": _day_of(m) + 20, "dealer": _day_of(m) + 20 }
				Master.set_day(m.state, Master.weekday(m.now_local()), m.now_local())
				await _frames(3)
			else:
				await _visit(m, who, "recovery" if who == "insurer" else "")
			_click(letter.get_global_rect().get_center())
			await _frames(3)
			texts.append_array(_visible_texts(d))
			if who == "insurer":
				# 복구 보험 글 → [예] → 가입됨 → 강화 칸 (보험료 줄) / 다음은 제휴 할인 글
				_click(d.yes_button.get_global_rect().get_center())
				await _frames(2)
				texts.append(d._status.text)
				_click(d.close_button.get_global_rect().get_center())
				_click(town.building_rects()["tuning"].get_center())
				await _frames(3)
				_click(p.engine_tab_button.get_global_rect().get_center())
				t.star = 18
				m.state.premium_spares = 1   # 준비: [고급 스페어 쓰기]가 보이게
				m.state.money = 1
				await _frames(2)
				texts.append_array(_visible_texts(p))
				texts.append(tr("NPC_EVENT_PARTNER_DISCOUNT") % Fmt.percent(b.partner_discount))
				await _fit_engine(m, b, fit[locale], "보험료 줄")
			_click(m.small_button.get_global_rect().get_center())
			await _frames(2)
		# 보험사 대화 창 (가입 전, 가장 긴 창: 이벤트 + 규칙 + [예] [아니오]) + 복구 보험 날 강화 칸 (설명 두 줄 + 스페어 없음)
		m.now_local_override = now + day_i * DAY
		await _visit(m, "insurer", "recovery")
		_click(letter.get_global_rect().get_center())
		await _frames(3)
		for size: Vector2i in FIT_SIZES:
			root.size = size
			await _frames(3)
			if not _in_window(d) or not d.yes_button.is_visible_in_tree():
				fit[locale].append("%s 보험사 창 %s" % [size, d.get_global_rect()])
		root.size = Vector2i(1600, 900)
		await _frames(2)
		_click(d.no_button.get_global_rect().get_center())
		_click(town.building_rects()["tuning"].get_center())
		await _frames(2)
		_click(p.engine_tab_button.get_global_rect().get_center())
		t.star = 18
		m.state.spares = 0
		m.state.premium_spares = 1
		m.state.use_premium = false
		m.state.money = 1
		await _frames(2)
		texts.append_array(_visible_texts(p))
		await _fit_engine(m, b, fit[locale], "복구 보험 + 스페어 없음")
		_click(p.setting_tab_button.get_global_rect().get_center())
		await _frames(2)
		texts.append(tr("SETTING_MAGICIAN") % "2")
		for key in ["RESULT_DESTROY_PREMIUM", "RESULT_DESTROY_RECOVERY"]:
			texts.append(tr(key) % [17, 0])
		texts.append(tr("RESULT_INSURED") % 18)
		texts.append(tr("DEPOT_WEEKLY") % ["1", "60,000", Fmt.money(123456789), "2,000"])
		texts.append(tr("NOTICE_WEEKLY") % [Fmt.money(123456789), "2,000"])
		texts.append_array(town.notices_shown)
		texts.append_array(town._notice_queue)
		if locale == "en":
			var bad := texts.filter(func(x): return _untranslated(String(x)))
			_report(bad.is_empty() and texts.size() >= 40, "⑨ en 대화 창 4명·강화 칸·결과·알림·주간 줄 글자 %d개에 한글·키 없음 %s" % [texts.size(), bad])
			print("    en: %s" % [texts])
		await _close(m)
	TranslationServer.set_locale("ko")
	var cube := []
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line := f.get_line()
		if line.contains("큐브") or line.to_lower().contains("cube"):
			cube.append(line.get_slice(",", 0))
	_report(cube.is_empty(), "⑨ 번역 파일(ko·en)에 '큐브'·'cube' 없음 (화면은 '세팅 돌리기') %s" % [cube])
	_report(fit["ko"].is_empty() and fit["en"].is_empty(),
			"⑨ ko·en 큰 화면 %d가지: 보험사 대화 창, 강화 칸 (보험료 줄 + [고급 스페어 쓰기] + 결과 두 줄 / 복구 보험 설명 + 스페어 없음 + [카센터로])이 창 안, 동네·[작게]·[설정]과 안 겹침 %s %s" % [
			FIT_SIZES.size(), fit["ko"], fit["en"]])


## 강화 칸이 큰 화면 5가지에서 창 안이고 동네·[작게]·[설정]과 안 겹치나 (결과 두 줄을 띄워 둔 채). 문제는 bad에
func _fit_engine(m: Node, b: Balance, bad: Array, what: String) -> void:
	var p = m.panel
	p.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, tr("RESULT_DESTROY_PREMIUM") % [b.premium_drop_to, 0])   # 준비: 결과 두 줄
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		var pr: Rect2 = p.get_global_rect()
		var shown: bool = p.premium_button.is_visible_in_tree() and (p._insure.is_visible_in_tree() if what == "보험료 줄" else p.to_car_button.is_visible_in_tree())
		if not shown or not Rect2(Vector2.ZERO, Vector2(size)).encloses(pr) or pr.intersects(Rect2(m.town.global_position + m.town.area().position, m.town.area().size)) \
				or pr.intersects(m.small_button.get_global_rect()) or pr.intersects(m.settings_button.get_global_rect()):
			bad.append("강화 칸 %s %s %s" % [what, size, pr])
	root.size = Vector2i(1600, 900)
	await _frames(2)


## 준비: 오늘(main.now_local) 특별 NPC id가 오게 (명장 요일은 안 고름, 다른 NPC는 먼 날) → 진짜 프레임으로 Visitor.tick.
## event를 주면 굴린 보험사 이벤트를 그것으로 고정
func _visit(m: Node, id: String, event := "") -> void:
	var day := _day_of(m)
	m.state.master_unlocked = true
	for v: String in Visitor.IDS:
		m.state.visitor_next[v] = day if v == id else day + 20
	await _frames(2)
	if event != "":
		m.state.insurer_event = event
	await _frames(1)


func _day_of(m: Node) -> int:
	return floori(float(m.now_local()) / DAY)


## 아이콘이 작은 화면 동네 오른쪽 위(오른쪽 1/4, 위 1/4)이고 동네 안·보이는 곳 안인가
func _top_right(m: Node, icon: Control) -> bool:
	var town = m.town
	var r: Rect2 = icon.get_global_rect()
	var area := Rect2(town.global_position + town.area().position, town.area().size)
	return icon.is_visible_in_tree() and area.encloses(r) and _enclosed(m.visible_rects(), r) \
			and r.position.x > area.position.x + area.size.x * 0.75 and r.end.y < area.position.y + area.size.y * 0.25


func _in_window(c: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.size)).encloses(c.get_global_rect())


## 동네 알림에 text가 떴거나 차례를 기다리나
func _noticed(town: Node, text: String) -> bool:
	return town.notices_shown.has(text) or town._notice_queue.has(text)


func _noticed_prefix(town: Node, prefix: String) -> bool:
	for x in town.notices_shown + town._notice_queue:
		if String(x).begins_with(prefix):
			return true
	return false


## 준비: 벨 시계를 거의 다 돌려 두고 진짜 프레임으로 벨이 울릴 때까지 (그 뒤 게임 시간 멈춤)
func _ring(m: Node) -> void:
	m.state.rush_next = 0.2
	Engine.time_scale = 1.0
	await _until(func(): return Rush.is_ringing(m.state) and m.town.rush_button.visible, 5.0)
	Engine.time_scale = 0.0
	await _frames(2)


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


## 저장 파일의 상태 (없으면 null)
func _saved_state(b: Balance):
	var r := Save.read_file(TEST_SAVE, b)
	return r["state"] if r["status"] == Save.Status.OK else null


func _untranslated(x: String) -> bool:
	for prefix in ["NPC_", "SETTINGS_", "MASTER_", "GARAGE_", "RESULT_", "NOTICE_", "DEPOT_", "SETTING_"]:
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


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤, 할 일 다 끝냄·급송 벨 끔: 알림·난수가 덜 끼게, 뜸은 짧게)
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
	m.state.rush_enabled = false
	m.suspense_scale = 0.01
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
