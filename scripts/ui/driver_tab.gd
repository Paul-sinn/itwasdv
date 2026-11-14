## 물류센터 화면 (v5 차고 [기사·물류센터] 칸이 v6a에서 건물 화면이 됨).
##   위: 기사 레벨, 경험치 막대(driver_xp / xp_need) (만렙이면 회사 평판)
##   그 아래 두 칸 고르기 (v5b. 한 화면에 다 넣으면 1280x720에서 창 밖으로 나감):
##     [능력치]: 남은 포인트 + [초기화](두 번 눌러야), 능력치 5줄 (이름 n/최대 · 지금 효과 / 한 줄 설명, [+]), 예시 빌드 4줄
##     [창고·할 일]: 대리점 창업 한 줄 (v7a: "대리점 창업 3억원 · 2.9억원 모자람" [창업] 두 번 눌러야 / 창업 뒤 "대리점 (시내)".
##                   1280x720에 맞게 모자란 금액도 같은 줄, "약 N분 뒤"는 안 붙임: 붙이면 두 줄이 되어 차고가 창 밖),
##                   다음 할 일 (끝낸 수 n/25, 이름·설명·진행·보상), 주간 배송 목표 (v6b),
##                   창고 확장·야간 배송팀 (지금 값 → 다음 값, 가격, [올리기], 모자란 금액),
##                   v8a 물류센터 업그레이드 3줄 (이름 Lv N / 5 + [값] / 대리점이면 버튼 대신 "동네에서만 살 수 있어요 (효과는 유지)",
##                   아래 "지금 효과 → 다음 효과". Upgrade.enabled가 거짓이면 숨김)
##     [기록] (v8a): 통계·잡옵 도감·업적 (record_tab.gd)
##   v8a: [창고·할 일]도 [기록]과 같은 높이(DRIVER_PAGE_HEIGHT)의 스크롤 칸 안에 (업그레이드 3줄을 더하면 1280x720에서 창 밖이라).
##        업그레이드는 맨 아래라 예전 줄들은 스크롤 없이 그 자리에
## 숫자는 scripts/core 의 Driver·Quest·Depot·Ability 값을 그대로 보여 준다 (효과를 여기서 계산하지 않음).
## 버튼은 신호만 → main.gd → Depot.upgrade / Ability.add / Ability.reset / Company.found / Upgrade.buy
## 다음 할 일 이름·설명은 번역 파일 QUEST_<ID>, QUEST_<ID>_DESC (Fmt.quest_name / quest_desc)
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Ability = preload("res://scripts/core/ability.gd")
const Weekly = preload("res://scripts/core/weekly.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const RecordTab = preload("res://scripts/ui/record_tab.gd")
const Upgrade = preload("res://scripts/core/upgrade.gd")

signal upgrade_pressed(kind: String)
signal ability_pressed(id: String)   ## 능력치 [+]
signal reset_pressed                 ## [초기화]를 두 번째 누름 (첫 번째는 여기서 글만 바꿈)
signal found_pressed                 ## [창업]을 두 번째 누름 (첫 번째는 여기서 글만 바꿈)
signal center_upgrade_pressed(id: String)   ## 물류센터 업그레이드 [값] (v8a)

enum Page { ABILITY, DEPOT, RECORD }

const KINDS := ["warehouse", "night"]
## 종류별 번역 키: 이름("창고 확장 Lv.N"), 값("꺼둔 동안 쌓이는 시간 …")
const KIND_KEYS := {
	"warehouse": { "title": "DEPOT_WAREHOUSE", "value": "DEPOT_WAREHOUSE_VALUE" },
	"night": { "title": "DEPOT_NIGHT", "value": "DEPOT_NIGHT_VALUE" },
}
## 예시 빌드 (글만): 번역 키, 주 능력치, 같이 찍는 능력치 (지시서 v5b "화면")
const BUILDS := [
	["ABILITY_BUILD_MONEY", "nego", "kind"],
	["ABILITY_BUILD_SPEED", "unload", "nego"],
	["ABILITY_BUILD_EASY", "knowhow", "nego"],
	["ABILITY_BUILD_ENHANCE", "mech", "nego"],
]

var buy_buttons := {}   ## kind → [올리기] 버튼
var page := Page.ABILITY ## 지금 보이는 칸 (처음엔 능력치. 바꾸면 기억)
var ability_page_button: Button
var depot_page_button: Button
var record_page_button: Button
var record: RecordTab     ## [기록] 칸
var center_buttons := {}  ## 물류센터 업그레이드 id → [값]
var center_notes := {}    ## id → 대리점이면 버튼 대신 "동네에서만 살 수 있어요 (효과는 유지)"
var center_titles := {}   ## id → "배송 구역 확장 Lv.2 / 5"
var center_values := {}   ## id → "단가 +4% → +6%"
var _center_rows: Array[Control] = []   ## 업그레이드 줄들 (Upgrade.enabled가 거짓이면 숨김)
var add_buttons := {}    ## 능력치 id → [+] (처음 refresh 때 balance 순서로 만듦)
var reset_button: Button
var found_button: Button  ## 대리점 [창업] (창업 뒤 숨김)

var _level: Label
var _xp_bar: ProgressBar
var _xp: Label           ## "경험치 120 / 230" (만렙이면 회사 평판)
var _points: Label
var _quest_head: Label   ## "다음 할 일 · 끝낸 것 3/22"
var _quest_name: Label
var _quest_desc: Label
var _quest_progress: Label   ## "진행 3/20 · 보상 +2만원 · 경험치 +200"
var _titles := {}        ## kind → "창고 확장 Lv.1"
var _values := {}        ## kind → "꺼둔 동안 쌓이는 시간 4시간 → 6시간"
var _waits := {}         ## kind → "1,234원 모자람 · 약 3분 뒤 가능"
var _bar_bg: StyleBoxFlat
var _bar_fill: StyleBoxFlat
var _ability_box: VBoxContainer
var _depot_box: VBoxContainer
var _depot_scroll: ScrollContainer   ## [창고·할 일] 스크롤 칸 (_depot_box를 담음)
var _ability_lines := {} ## 능력치 id → "협상  7/20 · 단가 +7%"
var _ability_descs := {} ## 능력치 id → 한 줄 설명
var _builds: Label       ## 예시 빌드 4줄
var _weekly: Label       ## "이번 주 12,340 / 60,000건 → 지금 1.2억원 + 경험치 2,000" (지금 받으면 얼마) / "이번 주 달성!" (1280x720에 한 줄로)
var _agency: Label       ## "대리점 창업 3억원" (+ " · 2.9억원 모자람") / 창업 뒤 "대리점 (시내)"
var _reset_armed_ms := -1   ## [초기화]를 한 번 누른 시각 (진짜 시간 ms). -1 = 안 누름
var _found_armed_ms := -1   ## [창업]을 한 번 누른 시각 (진짜 시간 ms). -1 = 안 누름
var _scale := 1.0
var _font_sizes := {}    ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	_level = _label(self, Feel.PANEL_TITLE_SIZE, Feel.COLOR_LEVEL)
	_level.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (레벨업 때 커질 기준점)
	_level.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_bar_bg = StyleBoxFlat.new()
	_bar_bg.bg_color = Feel.COLOR_XP_BAR_BG
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Feel.COLOR_XP_BAR
	_xp_bar.add_theme_stylebox_override("background", _bar_bg)
	_xp_bar.add_theme_stylebox_override("fill", _bar_fill)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar)
	_xp = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	# 두 칸 고르기: [능력치] [창고·할 일]
	var pages := HBoxContainer.new()
	add_child(pages)
	var group := ButtonGroup.new()
	ability_page_button = _toggle(pages, tr("DRIVER_PAGE_ABILITY"), group)
	depot_page_button = _toggle(pages, tr("DRIVER_PAGE_DEPOT"), group)
	record_page_button = _toggle(pages, tr("DRIVER_PAGE_RECORD"), group)
	ability_page_button.pressed.connect(func(): show_page(Page.ABILITY))
	depot_page_button.pressed.connect(func(): show_page(Page.DEPOT))
	record_page_button.pressed.connect(func(): show_page(Page.RECORD))

	# [능력치]: 남은 포인트 + [초기화], 능력치 줄 (refresh에서 만듦), 예시 빌드
	_ability_box = VBoxContainer.new()
	add_child(_ability_box)
	var head := HBoxContainer.new()
	_ability_box.add_child(head)
	_points = _label(head, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button = _button(head, tr("ABILITY_RESET"), Feel.PANEL_SMALL_SIZE)
	reset_button.pressed.connect(_on_reset_pressed)
	_builds = _label(_ability_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	# [창고·할 일] (스크롤 칸 안)
	_depot_scroll = ScrollContainer.new()
	_depot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_depot_scroll)
	_depot_box = VBoxContainer.new()
	_depot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_depot_scroll.add_child(_depot_box)
	# 맨 위: 대리점 창업 줄 (글자 왼쪽, [창업] 오른쪽 끝)
	var agency_row := HBoxContainer.new()
	_depot_box.add_child(agency_row)
	_agency = _label(agency_row, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_agency.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # 긴 글(영어·모자란 금액)은 [창업] 앞에서 줄바꿈
	_agency.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	found_button = _button(agency_row, tr("AGENCY_FOUND"))
	found_button.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	found_button.pressed.connect(_on_found_pressed)
	_quest_head = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_quest_name = _label(_depot_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_quest_desc = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	_quest_progress = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_weekly = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)

	for kind: String in KINDS:
		# 이름과 [올리기]를 한 줄에 (v6b 주간 목표 줄이 들어갈 자리를 만들려고: 1280x720 높이)
		var row := HBoxContainer.new()
		_depot_box.add_child(row)
		_titles[kind] = _label(row, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		_titles[kind].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 산 순간 커질 기준점
		_titles[kind].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_titles[kind].autowrap_mode = TextServer.AUTOWRAP_OFF
		var btn := _button(row, "")
		btn.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END   # 오른쪽 끝에
		_values[kind] = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		btn.pressed.connect(func(): upgrade_pressed.emit(kind))
		buy_buttons[kind] = btn
		_waits[kind] = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	# 물류센터 업그레이드 3줄: [이름 Lv.N / 5] … [값] 또는 대리점 안내, 아래 효과 줄
	for id: String in Upgrade.IDS:
		var row := HBoxContainer.new()
		_depot_box.add_child(row)
		center_titles[id] = _label(row, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		# 줄바꿈 됨: en 이름 + "Upgrade (₩100K)"가 한 줄이면 1280x720에서 차고가 넓어져 동네와 겹침. 산 순간 왼쪽 기준으로 커짐
		center_titles[id].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_titles[id].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var btn := _button(row, "")
		btn.size_flags_horizontal = Control.SIZE_SHRINK_END   # 오른쪽 끝에
		btn.pressed.connect(func(): center_upgrade_pressed.emit(id))
		center_buttons[id] = btn
		center_notes[id] = _label(row, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		center_notes[id].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center_notes[id].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		center_notes[id].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		center_values[id] = _label(_depot_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		_center_rows.append_array([row, center_values[id]])

	record = RecordTab.new()
	add_child(record)
	show_page(page)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). garage_panel.gd가 같이 부른다
func set_ui_scale(s: float) -> void:
	_scale = s
	if _xp_bar == null:
		return
	for box: BoxContainer in [self, _ability_box, _depot_box]:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_depot_scroll.custom_minimum_size.y = Feel.DRIVER_PAGE_HEIGHT * s
	record.set_ui_scale(s)
	_xp_bar.custom_minimum_size.y = Feel.XP_BAR_HEIGHT * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))


## 올린 직후: 그 줄 "Lv.N"이 커졌다 돌아옴
func show_bought(kind: String) -> void:
	Town.pop(_titles[kind], Feel.POP_PIVOT_LEFT)


## 물류센터 업그레이드를 산 직후: 그 줄 "Lv.N / 5"가 커졌다 돌아옴
func show_upgraded(id: String) -> void:
	Town.pop(center_titles[id], Feel.POP_PIVOT_LEFT)


## 찍은 직후: 그 능력치 줄이 커졌다 돌아옴
func show_added(id: String) -> void:
	if _ability_lines.has(id):
		Town.pop(_ability_lines[id], Feel.POP_PIVOT_LEFT)


## [능력치] / [창고·할 일] / [기록]
func show_page(p: Page) -> void:
	page = p
	_ability_box.visible = p == Page.ABILITY
	_depot_scroll.visible = p == Page.DEPOT
	record.visible = p == Page.RECORD
	ability_page_button.set_pressed_no_signal(p == Page.ABILITY)
	depot_page_button.set_pressed_no_signal(p == Page.DEPOT)
	record_page_button.set_pressed_no_signal(p == Page.RECORD)


## [초기화]: 첫 번째는 "한 번 더 누르면 초기화"로 바꾸기만, ABILITY_RESET_ARM_SECONDS 안에 또 누르면 reset_pressed
func _on_reset_pressed() -> void:
	if _reset_armed_ms >= 0:
		_reset_armed_ms = -1
		reset_pressed.emit()
	else:
		_reset_armed_ms = Time.get_ticks_msec()
	reset_button.text = tr("ABILITY_RESET_CONFIRM" if _reset_armed_ms >= 0 else "ABILITY_RESET")


## [창업]: 첫 번째는 "한 번 더 누르면 창업"으로 바꾸기만, AGENCY_FOUND_ARM_SECONDS 안에 또 누르면 found_pressed
func _on_found_pressed() -> void:
	if _found_armed_ms >= 0:
		_found_armed_ms = -1
		found_pressed.emit()
	else:
		_found_armed_ms = Time.get_ticks_msec()
	found_button.text = tr("AGENCY_CONFIRM" if _found_armed_ms >= 0 else "AGENCY_FOUND")


## 창업 직후: "대리점 (시내)" 글자가 커졌다 돌아옴
func show_founded() -> void:
	Town.pop(_agency, Feel.POP_PIVOT_LEFT)


## [창업]을 한 번 누른 채 기다리는 중인가 (확인용)
func is_found_armed() -> bool:
	return _found_armed_ms >= 0


## [초기화]를 한 번 누른 채 기다리는 중인가 (확인용)
func is_reset_armed() -> bool:
	return _reset_armed_ms >= 0


## 상태에 맞게 글자와 버튼을 고친다 (보이는 동안 매 프레임)
func refresh(b: Balance, s: GameState) -> void:
	var at_max := s.driver_level >= Driver.max_level(b)
	_level.text = tr("DRIVER_LEVEL_MAX" if at_max else "DRIVER_LEVEL") % s.driver_level
	var need := Driver.xp_need(b, s.driver_level)
	_xp_bar.max_value = maxi(need, 1)
	_xp_bar.value = _xp_bar.max_value if at_max else s.driver_xp
	_xp.text = tr("DRIVER_REPUTATION") % s.reputation if at_max else tr("DRIVER_XP") % [s.driver_xp, need]
	_refresh_abilities(b, s)

	_refresh_agency(b, s)
	_quest_head.text = tr("DRIVER_QUEST_HEAD") % [s.quest_index, Quest.count(b)]
	var q := Quest.current(b, s)
	if q.is_empty():
		_quest_name.text = tr("QUEST_NONE")
	else:
		var pr := Quest.progress(b, s)
		_quest_name.text = Fmt.quest_name(q["id"])
		_quest_desc.text = Fmt.quest_desc(q["id"])
		_quest_progress.text = tr("DRIVER_QUEST_PROGRESS") % [mini(pr[0], pr[1]), pr[1], Fmt.money(q["money"]), q["xp"]]
	_quest_desc.visible = not q.is_empty()
	_quest_progress.visible = not q.is_empty()

	# 주간 배송 목표 (보상 돈 = 지금 받으면 얼마인가 Weekly.reward_money, 경험치는 balance 그대로)
	var done := Weekly.is_done(s)
	var target := Weekly.target(b)
	_weekly.text = tr("DEPOT_WEEKLY_DONE") % Fmt.count(Weekly.progress(s)) if done \
			else tr("DEPOT_WEEKLY") % [Fmt.count(mini(Weekly.progress(s), target)), Fmt.count(target), Fmt.money(Weekly.reward_money(b, s)), Fmt.count(b.weekly_xp)]
	_weekly.add_theme_color_override("font_color", Feel.COLOR_STAR if done else Feel.COLOR_TEXT)

	for kind: String in KINDS:
		var lv := Depot.level(s, kind)
		var price := Depot.price(b, s, kind)
		var now := _value_text(b, kind, lv)
		var value: String
		if price > 0:
			value = tr("DEPOT_NEXT") % [now, _value_text(b, kind, lv + 1)]
		elif lv < Depot.top_level(b, kind):   # 다음 레벨은 있는데 대리점 전이라 못 삼
			value = tr("DEPOT_AGENCY") % [now, _value_text(b, kind, lv + 1)]
		else:
			value = tr("DEPOT_TOP") % now
		_titles[kind].text = tr(KIND_KEYS[kind]["title"]) % lv
		_values[kind].text = tr(KIND_KEYS[kind]["value"]) % value
		var btn: Button = buy_buttons[kind]
		btn.visible = price > 0
		btn.text = tr("DEPOT_BUY") % Fmt.money(price)
		btn.disabled = not Depot.can_upgrade(b, s, kind)
		var short := price > 0 and s.money < price
		_waits[kind].visible = short
		if short:
			_waits[kind].text = tr("DEPOT_SHORT") % [Fmt.money(price - s.money), Fmt.wait_text(Economy.seconds_to_afford(price, s.money, Company.hourly_net(b, s)))]
	_refresh_center(b, s)
	if record.visible:
		record.refresh(b, s)


## 물류센터 업그레이드 줄: 개인 기사면 [값] (못 사면 꺼짐) + "지금 → 다음 효과", 대리점이면 버튼 대신 안내 + 지금 효과만,
## 다 샀으면 "(최고 단계)". 효과 글은 Upgrade.value(지금)·value_at(다음 레벨) 그대로
func _refresh_center(b: Balance, s: GameState) -> void:
	var on := Upgrade.enabled(b)
	for c in _center_rows:
		c.visible = on
	if not on:
		return
	var solo := Company.stage(s) < GameState.AGENCY
	for id: String in Upgrade.IDS:
		var lv := Upgrade.level(s, id)
		var top := Upgrade.max_level(b, id)
		var price := Upgrade.price(b, s, id)
		var key := "UPGRADE_" + id.to_upper()
		var now := _center_value(id, Upgrade.value(b, s, id))
		center_titles[id].text = tr("UPGRADE_TITLE") % [tr(key), lv, top]
		var value := now   # 대리점: 지금 효과만 (못 사니 다음은 안 보여 줌)
		if price <= 0:
			value = tr("DEPOT_TOP") % now
		elif solo:
			value = tr("DEPOT_NEXT") % [now, _center_value(id, Upgrade.value_at(b, id, lv + 1))]
		center_values[id].text = tr(key + "_VALUE") % value
		center_buttons[id].visible = solo and price > 0
		center_buttons[id].text = tr("DEPOT_BUY") % Fmt.money(price)
		center_buttons[id].disabled = not Upgrade.can_buy(b, s, id)
		center_notes[id].visible = not solo and price > 0
		center_notes[id].text = tr("UPGRADE_SOLO_ONLY")


## 효과 수치 한 개 (번역 키 UPGRADE_<ID>_UNIT): 단가 "+4%", 싣는 시간 "−12%", 기본 적재량 "+2건"
func _center_value(id: String, v: float) -> String:
	return tr("UPGRADE_%s_UNIT" % id.to_upper()) % (Fmt.num(v) if id == "box" else Fmt.percent(v))


## 대리점 창업 줄: 창업 전 "대리점 창업 3억원" [창업] (돈이 모자라면 꺼짐 + 같은 줄에 모자란 금액), 창업 뒤 "대리점 (시내)"만.
## [창업]을 한 번 누르고 시간이 지나거나 누를 수 없게 되면 원래 글로
func _refresh_agency(b: Balance, s: GameState) -> void:
	var founded := Company.stage(s) >= GameState.AGENCY
	var price := Company.agency_price(b)
	_agency.text = tr("AGENCY_DONE") if founded else tr("AGENCY_ROW") % Fmt.money(price)
	if not founded and s.money < price:
		_agency.text += " · " + tr("AGENCY_SHORT") % Fmt.money(price - s.money)
	found_button.visible = not founded
	found_button.disabled = not Company.can_found(b, s)
	if found_button.disabled or (_found_armed_ms >= 0 and Time.get_ticks_msec() - _found_armed_ms > Feel.AGENCY_FOUND_ARM_SECONDS * 1000.0):
		_found_armed_ms = -1
	found_button.text = tr("AGENCY_CONFIRM" if _found_armed_ms >= 0 else "AGENCY_FOUND")


## [능력치] 칸: 남은 포인트, 능력치 줄마다 "이름  n/최대 · 지금 효과"와 [+] (못 찍으면 꺼짐), [초기화]
func _refresh_abilities(b: Balance, s: GameState) -> void:
	if add_buttons.is_empty():
		_build_abilities(b)
	var left := Ability.points_left(s)
	_points.text = tr("DRIVER_POINTS") % left
	for id: String in add_buttons:
		var key := "ABILITY_" + id.to_upper()
		_ability_lines[id].text = "%s  %d/%d · %s" % [tr(key), Ability.points(s, id), Ability.max_points(b, id),
				tr(key + "_EFFECT") % Fmt.percent(Ability.value(b, s, id))]
		add_buttons[id].disabled = not Ability.can_add(b, s, id)
	# 찍은 게 없으면 [초기화] 꺼짐. 한 번 누르고 시간이 지나면 원래 글로
	var spent := left < s.ability_points
	if not spent or (_reset_armed_ms >= 0 and Time.get_ticks_msec() - _reset_armed_ms > Feel.ABILITY_RESET_ARM_SECONDS * 1000.0):
		_reset_armed_ms = -1
	reset_button.disabled = not spent
	reset_button.text = tr("ABILITY_RESET_CONFIRM" if _reset_armed_ms >= 0 else "ABILITY_RESET")


## 능력치 줄 만들기 (balance 순서): [이름 n/최대 · 효과 / 설명] [+]. 예시 빌드 글도 여기서 (이름을 번역 파일에서)
func _build_abilities(b: Balance) -> void:
	for id: String in Ability.ids(b):
		var row := HBoxContainer.new()
		_ability_box.add_child(row)
		_ability_box.move_child(row, _builds.get_index())   # 예시 빌드 위에
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		_ability_lines[id] = _label(words, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		_ability_lines[id].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 찍은 순간 커질 기준점
		_ability_lines[id].autowrap_mode = TextServer.AUTOWRAP_OFF
		_ability_descs[id] = _label(words, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		_ability_descs[id].text = tr("ABILITY_%s_DESC" % id.to_upper())
		var add := _button(row, "+", Feel.ABILITY_ADD_SIZE)
		add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add.pressed.connect(func(): ability_pressed.emit(id))
		add_buttons[id] = add
	var lines := PackedStringArray()
	for build: Array in BUILDS:
		lines.append(tr(build[0]) % [tr("ABILITY_" + String(build[1]).to_upper()), tr("ABILITY_" + String(build[2]).to_upper())])
	_builds.text = "\n".join(lines)


## 그 레벨의 값: 창고 "4시간", 야간팀 "50%"
func _value_text(b: Balance, kind: String, lv: int) -> String:
	var v := Depot.value_at(b, kind, lv)
	return tr("DEPOT_HOURS") % Fmt.num(v) if kind == "warehouse" else Fmt.percent(v)


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_font_size_override("font_size", _px(font_size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l


## 한 줄에서 하나만 눌린 채로 있는 버튼 ([능력치] [창고·할 일]. garage_panel.gd 건물 줄과 같은 모양)
func _toggle(parent: Node, text: String, group: ButtonGroup) -> Button:
	var b := _button(parent, text, Feel.SETTING_TAB_SIZE)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
	b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	return b


func _button(parent: Node, text: String, font_size: int = Feel.PANEL_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = font_size
	btn.add_theme_font_size_override("font_size", _px(font_size))
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
