## v8a U1 틀 완료 기준 자동 확인. 진짜 게임 화면(main.tscn)에 진짜 클릭을 넣어서 본다.
## C1·C2 전이라 업그레이드·랩핑·통계·도감·업적 값은 껍데기(scripts/ui/stub_*.gd: 지시서 약속과 같은 이름·인자)에 준비로 넣는다.
## C1·C2를 합치면 준비를 진짜 상태(GameState.depot_upgrades · wraps · stats · junk_seen · achievements_done, TruckState.wrap)로 바꾼다.
## ① 랩핑 그림: Truck.body_shapes 5가지(랩핑 없음 + 4개)가 서로 다르고, 점이 전부 트럭 몸통 안 (보이는 곳 그대로), 양쪽 방향, 반창고는 원래 색 위에
## ② 튜닝숍 [랩핑]: 카드 4개 (미리 보기·이름), 구매용 [값] 클릭 → Wrap.buy (모자라면 꺼짐·눌러도 그대로), 보상용 "업적 '…' 달성하면 받아요"(버튼 없음),
##    [입히기] → 띠 트럭 랩핑 (큰 화면·작은 화면 같은 트럭), "입는 중" + [벗기기] → 랩핑 없음, 2호차 탭 → 보조 트럭에만
## ③ 물류센터 [기록]: 통계 12줄 값, 도감 25칸 ("?"·본 횟수·3줄 별·채운 칸 수), 업적 20줄 (달성·진행·랩핑 보상·목표 수 설명), 휠로 스크롤
## ④ 물류센터 [창고·할 일] 업그레이드 3줄: "이름 Lv.N / 5", 지금 → 다음 효과, [값] 클릭 → Upgrade.buy·알림, 모자라면 꺼짐,
##    다 사면 "(최고 단계)", 대리점이면 버튼 대신 "동네에서만 살 수 있어요 (효과는 유지)", Upgrade.enabled 거짓이면 숨김
## ⑤ ko·en 큰 화면 5가지에서 [랩핑]·[창고·할 일](개인 기사·대리점)·[기록]이 창 안, 동네·[작게]·[설정]과 안 겹침   ⑥ en 글자에 한글·키 없음
## 진짜 저장·설정 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_v8a.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄
const MAIN_SCENE := "res://scenes/main.tscn"
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Save = preload("res://scripts/core/save.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const Town = preload("res://scripts/ui/town.gd")
const Truck = preload("res://scripts/ui/truck.gd")
## shortcut: C1·C2 전 껍데기. 합치면 준비를 진짜 상태로 (위 머리글)
const Upgrade = preload("res://scripts/ui/stub_upgrade.gd")
const Wrap = preload("res://scripts/ui/stub_wrap.gd")
const Stats = preload("res://scripts/ui/stub_stats.gd")
const Achievement = preload("res://scripts/ui/stub_achievement.gd")
const TEST_SAVE := "user://test_v8a.json"
const TEST_SETTINGS := "user://test_v8a_settings.cfg"
const FIT_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(3440, 1440), Vector2i(1280, 1300), Vector2i(2200, 800)]
const WRAPS := ["", "stripe", "flame", "gold18", "bandage"]

var fails := PackedStringArray()
var checks := 0
var now := 0   ## 고정 현지 시각 (2026-11-18 수요일 12:00)
var en_texts := []   ## en 화면에서 모은 글자 (⑥)
var _hangul := RegEx.create_from_string("[가-힣ㄱ-ㅎㅏ-ㅣ]")


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	now = Time.get_unix_time_from_datetime_dict({ "year": 2026, "month": 11, "day": 18, "hour": 12, "minute": 0, "second": 0 })
	var b := Balance.load_file()

	_shapes()
	await _wrap_tab(b)
	await _record_tab(b)
	await _upgrades(b)
	for loc in ["ko", "en"]:
		TranslationServer.set_locale(loc)
		var bad := await _fit_all(b, loc == "en")
		_report(bad.is_empty(), "⑤ %s [랩핑](트럭 3대)·[창고·할 일](개인 기사·대리점)·[기록] 큰 화면 %d가지에서 창 안, 동네·[작게]·[설정]과 안 겹침 %s" % [loc, FIT_SIZES.size(), bad])
	TranslationServer.set_locale("ko")
	var bad := en_texts.filter(func(x): return _untranslated(String(x)))
	_report(bad.is_empty() and en_texts.size() >= 80, "⑥ en 랩핑 카드·[기록] 통계·도감·업적·업그레이드 줄·알림 글자 %d개에 한글·키 없음 %s" % [en_texts.size(), bad])
	print("    en: %s" % [en_texts.slice(0, 40)])

	_reset_stubs()
	Engine.time_scale = 1.0
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


# ---------------- ① 랩핑 도형 ----------------

func _shapes() -> void:
	var body := Rect2(Vector2.ZERO, Feel.TRUCK_SIZE).grow(0.01)
	var inside := true
	var sigs := {}
	var counts := []
	for face in [1, -1]:
		for id: String in WRAPS:
			var shapes: Array = Truck.body_shapes(face, Feel.COLOR_TRUCK_BOX, id)
			var sig := []
			for sh: Array in shapes:
				sig.append(sh[1])
				for pt: Vector2 in sh[0]:
					inside = inside and body.has_point(pt)
			sigs["%d %s" % [face, id]] = str(sig)
			if face == 1:
				counts.append("%s %d" % [id if id != "" else "없음", shapes.size()])
	var uniq := {}
	for id: String in WRAPS:
		uniq[sigs["1 " + id]] = true
	var helper := Truck.base_color(1)
	var keep_ok: bool = Truck.body_shapes(1, helper, "bandage")[0][1] == helper and Truck.body_shapes(1, helper, "")[0][1] == helper \
			and Truck.body_shapes(1, helper, "stripe")[0][1] == Feel.WRAP_BODY["stripe"][0]
	_report(inside and uniq.size() == WRAPS.size() and keep_ok,
			"① 랩핑 도형 5가지 (%s)가 서로 다른 색·무늬, 양쪽 방향 모두 점이 트럭 몸통 %s 안 (보이는 곳 그대로), 반창고는 2호차 원래 색 위에·줄무늬는 자기 색" % [
			", ".join(counts), Feel.TRUCK_SIZE])


# ---------------- ② 튜닝숍 [랩핑] ----------------

func _wrap_tab(b: Balance) -> void:
	_reset_stubs()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	var town = m.town
	s.money = Wrap.price(b, "stripe") + Wrap.price(b, "flame") / 2   # 준비: 줄무늬는 살 수 있고 불꽃은 모자람
	await _frames(2)
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	var p = m.panel
	_click(p.wrap_tab_button.get_global_rect().get_center())
	await _frames(2)
	var w = p.wrap
	var names := []
	var cards_ok: bool = w.is_visible_in_tree() and w.buttons.size() == 4 and p.current_tab() == p.Tab.WRAP
	for id: String in Wrap.ids(b):
		names.append(w.names[id].text)
		var pv: Control = w.previews[id]
		cards_ok = cards_ok and pv.is_visible_in_tree() and pv.size.x > 0.0 and pv.size.y > 0.0
	cards_ok = cards_ok and names == ["레이싱 줄무늬", "불꽃 무늬", "골드 +18", "반창고"]
	var stripe: Button = w.buttons["stripe"]
	var flame: Button = w.buttons["flame"]
	var gold_note: String = w.notes["gold18"].text
	var band_note: String = w.notes["bandage"].text
	var price_ok: bool = stripe.is_visible_in_tree() and not stripe.disabled and stripe.text == "%s원" % Fmt.money(Wrap.price(b, "stripe")) \
			and flame.is_visible_in_tree() and flame.disabled and flame.text == "%s원" % Fmt.money(Wrap.price(b, "flame")) \
			and not w.buttons["gold18"].visible and not w.buttons["bandage"].visible \
			and w.notes["gold18"].is_visible_in_tree() and gold_note == "업적 '꿈의 +18' 달성하면 받아요" \
			and band_note == "업적 '괜찮아, 다시 하면 돼' 달성하면 받아요" and not w.notes["stripe"].visible
	var money0 := s.money
	_click(flame.get_global_rect().get_center())   # 꺼진 버튼
	await _frames(2)
	var short_ok: bool = not Wrap.owned(s, "flame") and s.money == money0
	_click(stripe.get_global_rect().get_center())
	await _frames(2)
	var buy_ok: bool = Wrap.owned(s, "stripe") and s.money == money0 - Wrap.price(b, "stripe") and stripe.text == "입히기" and not w.notes["stripe"].visible
	_report(cards_ok and price_ok and short_ok and buy_ok,
			"② [랩핑] 카드 4개 %s (미리 보기), [%s] [%s 꺼짐 → 눌러도 그대로], 보상용 '%s' / '%s' 버튼 없음, [값] 클릭 → Wrap.buy·돈 −%s → [%s]" % [
			names, "%s원" % Fmt.money(Wrap.price(b, "stripe")), flame.text, gold_note, band_note, Fmt.money(Wrap.price(b, "stripe")), stripe.text])

	# [입히기] → 띠 트럭 (큰 화면 · 작은 화면), "입는 중" + [벗기기] → 없음
	_click(stripe.get_global_rect().get_center())
	await _frames(2)
	var worn_note: String = w.notes["stripe"].text
	var worn_wrap: String = town.trucks[0].wrap
	var wear_ok: bool = Wrap.worn(s, 0) == "stripe" and town.trucks[0].wrap == "stripe" and w.notes["stripe"].is_visible_in_tree() \
			and worn_note == "입는 중" and stripe.text == "벗기기"
	m.screen.enter_small()
	await _frames(3)
	var small_ok: bool = not m.is_full() and town.trucks[0].wrap == "stripe"
	_click(town.building_rects()["tuning"].get_center())
	await _frames(3)
	var back_ok: bool = m.is_full() and w.is_visible_in_tree()   # 튜닝숍은 마지막에 보던 칸으로
	_click(stripe.get_global_rect().get_center())
	await _frames(2)
	var off_ok: bool = Wrap.worn(s, 0) == "" and town.trucks[0].wrap == "" and stripe.text == "입히기" and not w.notes["stripe"].visible
	_report(wear_ok and small_ok and back_ok and off_ok,
			"② [입히기] → 내 트럭 랩핑 '%s' (큰 화면·띠 같은 트럭), '%s' + [벗기기] → 랩핑 없음 → [%s]" % [worn_wrap, worn_note, stripe.text])

	# 2호차 탭 → 보조 트럭에만
	_agency_with_helpers(b, s, 1)
	await _frames(3)
	_click(p.truck_buttons[1].get_global_rect().get_center())
	await _frames(2)
	_click(stripe.get_global_rect().get_center())
	await _frames(2)
	var helper_ok: bool = p.truck == 1 and w._truck == 1 and Wrap.worn(s, 1) == "stripe" and Wrap.worn(s, 0) == "" \
			and town.trucks.size() == 2 and town.trucks[1].wrap == "stripe" and town.trucks[0].wrap == "" and stripe.text == "벗기기"
	_report(helper_ok, "② 트럭 탭 [2호차] → [입히기] → 2호차만 랩핑 (띠 2호차 '%s', 내 트럭 '%s'), 미리 보기는 2호차 색" % [
			town.trucks[1].wrap if town.trucks.size() > 1 else "?", town.trucks[0].wrap])
	await _close(m)


# ---------------- ③ 물류센터 [기록] ----------------

func _record_tab(b: Balance) -> void:
	_reset_stubs()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	# 준비: 통계·도감·업적 값 (C2 뒤에는 진짜 상태)
	var vals := { "parcels": 12345, "money_earned": 123456789, "seconds_on": 3725.0, "best_star": 18, "tries": 40, "successes": 25,
			"fails": 12, "destroys": 3, "insured_saves": 1, "setting_rolls": 77, "tips": 9, "master_visits": 2 }
	Stats.values.merge(vals, true)   # 켤 때 Stats.tick이 seconds_on을 이미 넣었음
	Stats.seen.merge({ "junk_cupholder:0": 3, "junk_cupholder:2": 1, "junk_ride:4": 12 }, true)
	Stats.triples["junk_cupholder:0"] = true
	Achievement.done.append_array(["first_parcel", "star_10", "star_15", "star_18"])
	Achievement.now.merge({ "parcels_10k": 3210, "master_10": 2 }, true)
	await _frames(2)
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	_click(d.record_page_button.get_global_rect().get_center())
	await _frames(3)
	var r = d.record
	var want_stats := {
		"parcels": "12,345건", "money_earned": "%s원" % Fmt.money(123456789), "seconds_on": Fmt.away(3725.0), "best_star": "+18", "tries": "40번",
		"successes": "25번", "fails": "12번", "destroys": "3번", "insured_saves": "1번", "setting_rolls": "77번", "tips": "9번", "master_visits": "2번",
	}
	var got := {}
	var stats_ok: bool = r.is_visible_in_tree() and r.stat_values.size() == 12 and not d._depot_box.is_visible_in_tree()
	for k: String in want_stats:
		got[k] = r.stat_values[k].text
		stats_ok = stats_ok and r.stat_values[k].is_visible_in_tree() and got[k] == want_stats[k]
	_report(stats_ok, "③ [기록] 통계 12줄: %s" % [got.values()])

	var book := Stats.junk_book(b, s)
	var cells: Array = r.cells
	var cup0 := _cell(cells, "junk_cupholder", 0)
	var cup2 := _cell(cells, "junk_cupholder", 2)
	var ride4 := _cell(cells, "junk_ride", 4)
	var blank := _cell(cells, "junk_radio", 1)
	var unseen := cells.filter(func(c): return c["label"].text == "?").size()
	var head: String = r._book_head.text
	var book_ok: bool = book.size() == 25 and cells.size() == 25 and head == "잡옵 도감 · 3 / 25칸" and unseen == 22 \
			and cup0["label"].text == "3번" and cup0["star"].is_visible_in_tree() and cup0["star"].size.x > 0.0 \
			and cup2["label"].text == "1번" and not cup2["star"].visible and ride4["label"].text == "12번" \
			and blank["label"].text == "?" and not blank["star"].visible and blank["style"].bg_color == Feel.COLOR_BOOK_EMPTY \
			and is_equal_approx(ride4["style"].bg_color.a, Feel.BOOK_CELL_ALPHA) and ride4["style"].bg_color.r == Feel.SETTING_GRADE_COLORS[4].r
	_report(book_ok, "③ [기록] '%s' 칸 25개 (안 본 칸 '?' %d개), 컵홀더 순정 '%s' + 3줄 별, 스포츠 '%s' 별 없음, 승차감 프로토타입 '%s' 등급 색 바탕" % [
			head, unseen, cup0["label"].text, cup2["label"].text, ride4["label"].text])

	var ach_head: String = r._ach_head.text
	var notes := {}
	for id in ["parcels_10k", "star_18", "first_destroy", "setting_racing", "level_max"]:
		notes[id] = r.ach_notes[id].text
	var ach_ok: bool = r.ach_names.size() == 20 and ach_head == "업적 · 4 / 20" and r.ach_names["first_parcel"].text == "첫 배달" \
			and r.ach_rights["star_18"].text == "달성" and r.ach_rights["parcels_10k"].text == "3,210 / 10,000" \
			and r.ach_rights["master_10"].text == "2 / 10" and r.ach_rights["first_destroy"].text == "0 / 1" \
			and notes["parcels_10k"] == "택배 10,000건 배달" and notes["star_18"] == "엔진 +18 첫 성공 · 보상: 랩핑 '골드 +18'" \
			and notes["first_destroy"] == "엔진이 처음 퍼짐 · 보상: 랩핑 '반창고'" and notes["setting_racing"] == "세팅 등급 레이싱 달성" \
			and notes["level_max"] == "기사 Lv.50 달성"
	for id: String in r.ach_names:
		ach_ok = ach_ok and r.ach_names[id].text != "" and not r.ach_names[id].text.begins_with("ACH_")
	_report(ach_ok, "③ [기록] '%s' 20줄: 달성 '%s', 진행 '%s', 설명·보상 %s" % [ach_head, r.ach_rights["star_18"].text, r.ach_rights["parcels_10k"].text, notes.values()])

	# 휠로 스크롤 (진짜 휠 입력)
	var sc: ScrollContainer = r.scroll
	var before := sc.scroll_vertical
	var bar_max := sc.get_v_scroll_bar().max_value
	_wheel(sc.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, 3)
	await _frames(3)
	var after := sc.scroll_vertical
	_report(before == 0 and bar_max > sc.size.y and after > 0,
			"③ [기록] 휠 아래로 → 스크롤 %d → %d (내용 %.0f > 칸 %.0f)" % [before, after, bar_max, sc.size.y])
	await _close(m)


# ---------------- ④ 물류센터 업그레이드 3줄 ----------------

func _upgrades(b: Balance) -> void:
	_reset_stubs()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	s.money = Upgrade.price(b, s, "zone") * 3 / 2   # 준비: 첫 레벨만 살 수 있게
	await _frames(2)
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	var d = m.panel.driver
	_click(d.depot_page_button.get_global_rect().get_center())
	await _frames(3)
	var hidden_first: bool = not _shown_in(d._depot_scroll, d.center_buttons["box"]) and _shown_in(d._depot_scroll, d.found_button)
	var scrolled := await _scroll_to(d._depot_scroll, d.center_buttons["box"])   # 진짜 휠로 맨 아래 업그레이드 줄까지
	_report(hidden_first and scrolled, "④ [창고·할 일]은 스크롤 칸: 처음엔 창업 줄이 보이고 맨 아래 업그레이드 줄은 휠로 내려서 보임 (스크롤 %d)" % d._depot_scroll.scroll_vertical)
	var rows := []
	var first_ok := true
	var want := {
		"zone": ["배송 구역 확장 Lv.0 / 5", "배송 단가 +0% → +2%"],
		"sort": ["분류 속도 Lv.0 / 5", "물류센터에서 싣는 시간 −0% → −6%"],
		"box": ["기본 적재함 Lv.0 / 5", "한 바퀴 기본 적재량 +0건 → +1건"],
	}
	for id: String in want:
		var btn: Button = d.center_buttons[id]
		rows.append("%s / %s [%s]" % [d.center_titles[id].text, d.center_values[id].text, btn.text])
		first_ok = first_ok and d.center_titles[id].is_visible_in_tree() and d.center_titles[id].text == want[id][0] \
				and d.center_values[id].text == want[id][1] and btn.is_visible_in_tree() and not btn.disabled \
				and btn.text == "올리기 (%s원)" % Fmt.money(Upgrade.price(b, s, id)) and not d.center_notes[id].visible
	_report(first_ok, "④ [창고·할 일] 업그레이드 3줄 %s" % [rows])

	var money0 := s.money
	var zone: Button = d.center_buttons["zone"]
	var price1 := Upgrade.price(b, s, "zone")
	_click(zone.get_global_rect().get_center())
	await _frames(2)
	var notice := "물류센터 업그레이드! 배송 구역 확장 Lv.1"
	var bought_ok: bool = Upgrade.level(s, "zone") == 1 and s.money == money0 - price1 and d.center_titles["zone"].text == "배송 구역 확장 Lv.1 / 5" \
			and d.center_values["zone"].text == "배송 단가 +2% → +4%" and _count_notice(m.town, notice) == 1 \
			and zone.disabled and zone.text == "올리기 (%s원)" % Fmt.money(Upgrade.price(b, s, "zone"))
	var money1 := s.money
	_click(zone.get_global_rect().get_center())   # 꺼짐 (돈 모자람)
	await _frames(2)
	var short_ok: bool = Upgrade.level(s, "zone") == 1 and s.money == money1
	Upgrade.levels["sort"] = Upgrade.max_level(b, "sort")   # 준비: 다 삼
	await _frames(2)
	var top_text: String = d.center_values["sort"].text
	var top_ok: bool = top_text == "물류센터에서 싣는 시간 −30% (최고 단계)" and not d.center_buttons["sort"].visible and not d.center_notes["sort"].visible \
			and d.center_titles["sort"].text == "분류 속도 Lv.5 / 5"
	_report(bought_ok and short_ok and top_ok,
			"④ [값] 클릭 → Upgrade.buy (돈 −%s, Lv.1, '%s' → 알림 '%s'), 모자라면 꺼짐·눌러도 그대로, 다 사면 '%s' 버튼 없음" % [
			Fmt.money(price1), d.center_values["zone"].text, notice, top_text])

	_agency_with_helpers(b, s, 0)
	await _frames(3)
	var solo_text: String = d.center_notes["zone"].text
	var agency_ok: bool = Company.stage(s) == GameState.AGENCY and not zone.visible and not d.center_buttons["box"].visible \
			and d.center_notes["zone"].is_visible_in_tree() and solo_text == "동네에서만 살 수 있어요 (효과는 유지)" \
			and d.center_notes["box"].is_visible_in_tree() and not d.center_notes["sort"].visible \
			and d.center_values["zone"].text == "배송 단가 +2%" and d.center_values["box"].text == "한 바퀴 기본 적재량 +0건"
	_report(agency_ok, "④ 대리점: 버튼 대신 '%s', 효과는 지금 값 '%s' (다 산 줄은 '최고 단계' 그대로)" % [solo_text, d.center_values["zone"].text])

	Upgrade.on = false   # 준비: json에 depot_upgrades 묶음이 없음
	await _frames(2)
	var hidden_ok := true
	for id: String in want:
		hidden_ok = hidden_ok and not d.center_titles[id].is_visible_in_tree() and not d.center_values[id].is_visible_in_tree() \
				and not d.center_buttons[id].is_visible_in_tree() and not d.center_notes[id].is_visible_in_tree()
	_report(hidden_ok and d._weekly.is_visible_in_tree(), "④ Upgrade.enabled 거짓 → 업그레이드 3줄 숨김 (다른 줄은 그대로)")
	await _close(m)


# ---------------- ⑤ 창 크기 ----------------

## 문제 목록. en이면 보이는 글자를 en_texts에 모음
func _fit_all(b: Balance, en: bool) -> Array:
	_reset_stubs()
	Save.delete_file(TEST_SAVE)
	var m := await _launch(b)
	var s: GameState = m.state
	var p = m.panel
	var d = p.driver
	var w = p.wrap
	var bad := []
	s.money = 0   # 모자란 금액 줄까지 다 보일 때
	Wrap.owned_ids.append("flame")
	Stats.seen["junk_gloss:3"] = 2
	Stats.triples["junk_gloss:3"] = true
	await _frames(2)
	_click(m.town.building_rects()["depot"].get_center())
	await _frames(3)
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(d.depot_page_button.get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "[창고·할 일] 개인 기사", size, d.center_buttons["box"].is_visible_in_tree() and d.center_values["box"].is_visible_in_tree())
		_click(d.record_page_button.get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "[기록]", size, d.record.scroll.is_visible_in_tree())
	if en:
		for id: String in Upgrade.IDS:
			en_texts.append_array([d.center_titles[id].text, d.center_values[id].text, d.center_buttons[id].text])
		var r = d.record
		en_texts.append_array([r._stats_head.text, r._book_head.text, r._ach_head.text])
		for k: String in r.stat_values:
			en_texts.append(r.stat_values[k].text)
		for c: Dictionary in r.cells.slice(0, 5):
			en_texts.append(c["label"].text)
		for id: String in r.ach_names:
			en_texts.append_array([r.ach_names[id].text, r.ach_rights[id].text, r.ach_notes[id].text])
		_collect_labels(r, en_texts)
		s.money = Upgrade.price(b, s, "zone")
		await _frames(2)
		_click(d.depot_page_button.get_global_rect().get_center())
		await _frames(2)
		await _scroll_to(d._depot_scroll, d.center_buttons["zone"])
		_click(d.center_buttons["zone"].get_global_rect().get_center())
		await _frames(2)
		en_texts.append_array(m.town.notices_shown + m.town._notice_queue)

	# 대리점 + 보조 트럭 2대: [창고·할 일] 버튼 대신 안내, 튜닝숍 [랩핑] (트럭 탭, 입는 중 · 가짐 · 값 · 업적 보상 카드)
	_agency_with_helpers(b, s, 2)
	s.money = 0
	Wrap.worn_by[0] = "flame"
	await _frames(3)
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(d.depot_page_button.get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "[창고·할 일] 대리점", size, d.center_notes["zone"].is_visible_in_tree())
	if en:
		for id: String in Upgrade.IDS:
			en_texts.append(d.center_notes[id].text)
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(3)
	for size: Vector2i in FIT_SIZES:
		root.size = size
		await _frames(3)
		_click(p.wrap_tab_button.get_global_rect().get_center())
		await _frames(3)
		_fit(m, bad, "[랩핑]", size, w.is_visible_in_tree() and p.truck_buttons[2].is_visible_in_tree() and w.notes["flame"].is_visible_in_tree() \
				and w.notes["gold18"].is_visible_in_tree() and w.buttons["stripe"].is_visible_in_tree())
	if en:
		en_texts.append_array([p.wrap_tab_button.text, d.record_page_button.text, w._note.text])
		for id: String in w.buttons:
			en_texts.append_array([w.names[id].text, w.buttons[id].text, w.notes[id].text])
	await _close(m)
	return bad


# ---------------- 도우미 ----------------

## 껍데기 값 비우기 (확인 사이에 남지 않게)
func _reset_stubs() -> void:
	Upgrade.on = true
	Upgrade.levels.clear()
	Wrap.owned_ids.clear()
	Wrap.worn_by.clear()
	Stats.values.clear()
	Stats.seen.clear()
	Stats.triples.clear()
	Achievement.done.clear()
	Achievement.now.clear()


## c가 스크롤 칸 sc의 보이는 곳 안에 다 들어와 있나
func _shown_in(sc: ScrollContainer, c: Control) -> bool:
	return c.is_visible_in_tree() and sc.get_global_rect().encloses(c.get_global_rect())


## 스크롤 칸 위에서 휠을 한 칸씩 내려 c가 보일 때까지 (최대 40칸). 보이면 true
func _scroll_to(sc: ScrollContainer, c: Control) -> bool:
	for i in 40:
		if _shown_in(sc, c):
			return true
		_wheel(sc.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_DOWN, 1)
		await _frames(2)
	return _shown_in(sc, c)


## 도감 칸 (잡옵 id, 등급)
func _cell(cells: Array, option: String, grade: int) -> Dictionary:
	for c: Dictionary in cells:
		if c["option"] == option and c["grade"] == grade:
			return c
	return { "label": Label.new(), "star": Control.new(), "style": StyleBoxFlat.new() }


## node 아래 보이는 Label 글자 전부
func _collect_labels(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label and c.is_visible_in_tree() and c.text != "":
			out.append(c.text)
		_collect_labels(c, out)


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


## 동네 알림에 text가 뜬 수 + 차례를 기다리는 수
func _count_notice(town: Node, text: String) -> int:
	return town.notices_shown.count(text) + town._notice_queue.count(text)


## en 화면에 한글이나 번역 키가 그대로 보이나
func _untranslated(x: String) -> bool:
	for prefix in ["WRAP_", "RECORD_", "STAT_", "ACH_", "UPGRADE_", "DRIVER_", "NOTICE_", "SETTING_", "DEPOT_", "GARAGE_"]:
		if x.contains(prefix):
			return true
	return _hangul.search(x) != null


## 작은 화면 크기로 띄움 (현지 시각 고정, 게임 시간은 멈춤, 급송 벨 끔)
func _launch(b: Balance) -> Node:
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


## 마우스 휠 n칸
func _wheel(pos: Vector2, button: MouseButton, n: int) -> void:
	for i in n:
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


func _report(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		fails.append(text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])
