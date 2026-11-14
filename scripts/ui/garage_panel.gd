## 건물 화면: 큰 화면 오른쪽에 크게 보인다 (작은 화면에서는 안 보임).
## 크기는 set_ui_scale()로 정한다 (1 = v0 패널 크기).
## v3: 트럭 0의 엔진 강화 + 스페어 엔진(들고 있는 개수, 언제든 구매). 고장 상태는 없음 (퍼지면 스페어를 써서 +15)
## v4: [엔진 강화] / [세팅] 두 칸. [세팅] 칸은 setting_tab.gd
## v5: 기사 레벨·다음 할 일·창고 확장·야간 배송팀 (driver_tab.gd)
## v6a: 위쪽 줄에서 건물을 고름 (튜닝숍 / 물류센터 / 카센터). 건물마다 NPC 한 줄.
##      튜닝숍 = [엔진 강화] [세팅 돌리기] 두 칸, 물류센터 = driver_tab.gd, 카센터 = 스페어 엔진 사기
## v6b: 튜닝숍 세 번째 칸 [명장] (master_tab.gd). [엔진 강화] 칸에 "명장 방문 중: 보너스" 줄, [강화] 옆 [보험] 켜기,
##      "지금 돈이면 N번 시도 가능". 확률·비용·보험 요금·횟수는 Enhance·Economy 값을 그대로 (now_local은 main이 매 프레임 넣음)
## v7a: 튜닝숍 위쪽 트럭 탭 ("내 트럭", "2호차", "3호차". 트럭이 1대거나 [명장] 칸이면 숨김). 고른 트럭(truck)의 강화·세팅을 보여 주고
##      (1280x720에 맞게 탭은 NPC 줄 안, 얼굴 옆 이름·인사말 자리에. 탭이 보이는 동안 이름·인사말은 숨김)
##      main이 강화·돌리기·보험을 그 트럭에. "모자란 금액 · 약 N분 뒤"는 모든 트럭 시간당 내 돈(Company.hourly_net) 기준
##      U2: 창업하면 건물 줄에 [사무실] (office_tab.gd: 보조 트럭·순위표·장부). 대리점 전(F3 처음부터 포함)에는 버튼을 숨기고 튜닝숍으로
## v7-bal: [보험] 켜기·쿠폰 지움 (보험은 보험사 날 [예]로 가입 → 계산 쪽 state). 가입한 날 +18 이상은 "보험 가입 중 · 보험료 +N · 합계" 줄,
##      제휴 할인 날은 비용 옆 "(제휴 할인 N%)", 복구 보험 날은 퍼짐 설명에 한 줄. 고급 스페어가 있으면 개수 + [고급 스페어 쓰기] 켜기/끄기
## 보여주기만 한다. 버튼을 누르면 신호만 보내고, 실제 강화·구매·돌리기는 main.gd → scripts/core 가 한다.
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Visitor = preload("res://scripts/core/visitor.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const SettingTab = preload("res://scripts/ui/setting_tab.gd")
const DriverTab = preload("res://scripts/ui/driver_tab.gd")
const MasterTab = preload("res://scripts/ui/master_tab.gd")
const OfficeTab = preload("res://scripts/ui/office_tab.gd")

signal enhance_pressed
signal spare_pressed
signal premium_toggled(on: bool)   ## [고급 스페어 쓰기] (main이 state.use_premium에 넣고 저장)


enum Tab { ENGINE, SETTING, MASTER }   ## 튜닝숍 안 세 칸
## 건물마다 NPC 이름·인사말 번역 키 (건물 이름은 Town.BUILDING_NAMES)
const NPC_KEYS := {
	"tuning": ["NPC_TUNING", "NPC_TUNING_HELLO"],
	"depot": ["NPC_DEPOT", "NPC_DEPOT_HELLO"],
	"car_center": ["NPC_CAR_CENTER", "NPC_CAR_CENTER_HELLO"],
	"office": ["NPC_OFFICE", "NPC_OFFICE_HELLO"],
}

var building := "tuning"         ## 지금 보는 건물 (Town.BUILDINGS 중 하나 또는 Town.OFFICE)
var truck := 0                   ## 튜닝숍 트럭 탭에서 고른 트럭 (0 = 내 트럭). 강화·세팅·보험이 이 트럭에
var truck_buttons: Array[Button] = []   ## 트럭 탭 (계산 쪽 트럭 수만큼 refresh에서 만듦)
var building_buttons := {}       ## 건물 id → 위쪽 줄 버튼
var engine_tab_button: Button    ## 튜닝숍 [엔진 강화]
var setting_tab_button: Button   ## 튜닝숍 [세팅]
var master_tab_button: Button    ## 튜닝숍 [명장]
var premium_button: Button       ## [강화] 옆 [고급 스페어 쓰기] 켜기/끄기 (고급 스페어가 있을 때만 보임. 눌린 모양 = state.use_premium)
var now_local := 0               ## 현지 시각 (main.now_local()을 매 프레임 넣음. [명장] 칸이 방문 중인지 볼 때)
var master: MasterTab            ## 튜닝숍 [명장] 칸
var to_car_button: Button        ## 스페어가 없어 강화가 막혔을 때 [카센터로]
var setting: SettingTab          ## 튜닝숍 [세팅] 칸
var driver: DriverTab            ## 물류센터 화면
var office: OfficeTab            ## 사무실 화면 (창업 뒤)

var _style: StyleBoxFlat
var _building_row: HBoxContainer
var _npc_row: HBoxContainer
var _npc_face: ColorRect
var _npc_name: Label
var _npc_hello: Label
var _npc_words: VBoxContainer    ## NPC 이름 + 인사말 (트럭 탭이 보이면 그 자리를 내줌)
var _truck_row: HBoxContainer    ## 트럭 탭 줄 (NPC 줄 안)
var _truck_group := ButtonGroup.new()
var _car_box: VBoxContainer      ## 카센터 화면
var _car_spares: Label
var _car_note: Label             ## "+18부터 강화하려면 1개가 있어야 해요…"
var _car_wait: Label             ## 모자란 금액
var _car_result: Label
var _tabs: HBoxContainer
var _enhance_row: HBoxContainer   ## [강화] [카센터로]
var _engine_box: VBoxContainer   ## [엔진 강화] 칸
var _tab := Tab.ENGINE
var _title_row: HBoxContainer   ## [엔진 +N] ... [스페어 엔진 N개]
var _title: Label
var _master_line: Label   ## "명장 방문 중: 강화 비용 20% 할인" (방문 중에만)
var _spares: Label    ## "스페어 엔진 N개"
var _income: Label
var _chances: Label
var _danger: Label
var _danger_note: Label   ## "퍼지면 스페어 엔진 1개를 써서 +15로"
var _cost: Label      ## "비용 N원" (제휴 할인 날 가입했으면 "(제휴 할인 50%)")
var _insure: Label    ## 가입한 날 +18 이상: "보험 가입 중 · 보험료 +N원 · 합계 N원"
var _tries: Label     ## "지금 돈이면 N번 시도 가능" (보험료 포함)
var _wait: Label      ## 못 누르는 이유: 스페어 없음 / 돈 모자람 (약 N분 뒤)
var _enhance_button: Button
var _spare_button: Button
var _result: Label
var _result_note: Label   ## 결과 아래 작은 설명 ("스페어 엔진 1개 사용 → +15")
var _stats: Label
var _flash: ColorRect
var _box: VBoxContainer
var _busy := false   ## 강화 결과를 기다리는 중 (뜸)
var _scale := 1.0    ## v0 패널의 몇 배 크기
var _result_size := Feel.PANEL_TEXT_SIZE   ## 결과 한 줄 글자 크기 (배수 곱하기 전)
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	custom_minimum_size.x = Feel.PANEL_WIDTH
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.set_corner_radius_all(Feel.PANEL_RADIUS)
	_style.set_content_margin_all(Feel.PANEL_PADDING)
	add_theme_stylebox_override("panel", _style)

	_box = VBoxContainer.new()
	add_child(_box)

	# 맨 위: 건물 고르기 (튜닝숍 / 물류센터 / 카센터)
	_building_row = HBoxContainer.new()
	_box.add_child(_building_row)
	var bgroup := ButtonGroup.new()
	for id: String in Town.BUILDINGS + [Town.OFFICE]:
		var bb := _toggle(_building_row, tr(Town.BUILDING_NAMES[id]), bgroup)
		bb.pressed.connect(func(): show_building(id))
		building_buttons[id] = bb

	# NPC 한 줄: 임시 사각형 얼굴 + 이름 + 인사말
	_npc_row = HBoxContainer.new()
	_box.add_child(_npc_row)
	_npc_face = ColorRect.new()
	_npc_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_row.add_child(_npc_face)
	_npc_words = VBoxContainer.new()
	_npc_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_row.add_child(_npc_words)
	_npc_name = _label(_npc_words, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_npc_hello = _label(_npc_words, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	# 튜닝숍 트럭 탭 (버튼은 refresh에서 트럭 수만큼)
	_truck_row = HBoxContainer.new()
	_truck_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_truck_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_truck_row.visible = false
	_npc_row.add_child(_truck_row)

	# 튜닝숍 안 두 칸 고르기
	_tabs = HBoxContainer.new()
	_box.add_child(_tabs)
	var group := ButtonGroup.new()
	engine_tab_button = _toggle(_tabs, tr("GARAGE_TAB_ENGINE"), group)
	setting_tab_button = _toggle(_tabs, tr("GARAGE_TAB_SETTING"), group)
	master_tab_button = _toggle(_tabs, tr("GARAGE_TAB_MASTER"), group)
	engine_tab_button.pressed.connect(func(): show_tab(Tab.ENGINE))
	setting_tab_button.pressed.connect(func(): show_tab(Tab.SETTING))
	master_tab_button.pressed.connect(func(): show_tab(Tab.MASTER))

	var e := VBoxContainer.new()
	_engine_box = e
	_box.add_child(e)
	# 제목 줄: "엔진 +18" 왼쪽, "스페어 엔진 N개" 오른쪽 (v6b: 방문 줄·시도 횟수 줄이 늘어서 1280x720에 맞게 한 줄로)
	_title_row = HBoxContainer.new()
	e.add_child(_title_row)
	_title = _label(_title_row, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_spares = _label(_title_row, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_spares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spares.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spares.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spares.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 작은 글자: 가장 긴 보너스(영어 "… chance of one extra level on success")도 한 줄이라 1280x720에서 차고가 [설정]과 안 겹침 (v7a)
	_master_line = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_MASTER)
	_income = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_danger = _label(e, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_danger_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_cost = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_insure = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_INSURED)
	_tries = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_wait = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	# [강화] [고급 스페어 쓰기] [카센터로] 한 줄 (칸이 길어지지 않게). [카센터로]는 스페어가 없어 막혔을 때만
	_enhance_row = HBoxContainer.new()
	e.add_child(_enhance_row)
	_enhance_button = _button(_enhance_row, tr("GARAGE_ENHANCE"))
	_enhance_button.pressed.connect(func(): enhance_pressed.emit())
	premium_button = _button(_enhance_row, tr("GARAGE_USE_PREMIUM"))
	premium_button.toggle_mode = true
	premium_button.add_theme_color_override("font_pressed_color", Feel.COLOR_SPARE)
	premium_button.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_SPARE)
	premium_button.toggled.connect(func(on: bool): premium_toggled.emit(on))
	to_car_button = _button(_enhance_row, tr("GARAGE_TO_CAR"))
	to_car_button.pressed.connect(func(): show_building("car_center"))
	for btn in [_enhance_button, premium_button, to_car_button]:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_result = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	clear_result()
	_stats = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	setting = SettingTab.new()
	_box.add_child(setting)
	driver = DriverTab.new()
	_box.add_child(driver)
	master = MasterTab.new()
	_box.add_child(master)
	office = OfficeTab.new()
	_box.add_child(office)
	building_buttons[Town.OFFICE].visible = false   # 창업 뒤에 refresh가 켬

	# 카센터: 스페어 엔진 (들고 있는 개수, 설명, [사기], 모자란 금액, 산 결과)
	_car_box = VBoxContainer.new()
	_box.add_child(_car_box)
	_car_spares = _label(_car_box, Feel.PANEL_TITLE_SIZE, Feel.COLOR_TEXT)
	_car_note = _label(_car_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_spare_button = _button(_car_box, "")
	_spare_button.pressed.connect(func(): spare_pressed.emit())
	_car_wait = _label(_car_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	_car_result = _label(_car_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_SUCCESS)
	_car_result.visible = false

	# 성공 번쩍임 (패널 위에 겹쳐 놓은 하얀 판, 평소엔 투명)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	show_tab(Tab.ENGINE)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). 글자, 폭, 여백, 테두리를 같이 키운다.
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.PANEL_WIDTH * s
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	_box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP * s)))
	_engine_box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for row: Control in [_tabs, _building_row, _npc_row, _truck_row, _car_box, _enhance_row, _title_row]:
		row.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_npc_face.custom_minimum_size = Vector2.ONE * Feel.NPC_FACE_SIZE * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))
	_result.add_theme_font_size_override("font_size", _px(_result_size))
	setting.set_ui_scale(s)
	driver.set_ui_scale(s)
	master.set_ui_scale(s)
	office.set_ui_scale(s)
	reset_size()


func ui_scale() -> float:
	return _scale


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


## 건물 화면 바꾸기 ("tuning" / "depot" / "car_center"). 튜닝숍은 마지막에 보던 칸으로
func show_building(id: String) -> void:
	building = id
	_npc_face.color = Feel.NPC_FACE_COLORS[id]
	_npc_name.text = tr(NPC_KEYS[id][0])
	_npc_hello.text = tr(NPC_KEYS[id][1])
	_car_result.visible = false
	_show_parts()


## 트럭 탭 고르기: 그 트럭의 강화·세팅을 보여 줌 (지난 결과 줄은 지움)
func pick_truck(i: int) -> void:
	truck = i
	setting.truck = i
	clear_result()
	setting.clear_result()
	for j in truck_buttons.size():
		truck_buttons[j].set_pressed_no_signal(j == i)


## 튜닝숍 [엔진 강화] / [세팅] / [명장] 칸 바꾸기 (튜닝숍 화면으로)
func show_tab(t: Tab) -> void:
	_tab = t
	show_building("tuning")


func _show_parts() -> void:
	var tuning := building == "tuning"
	_tabs.visible = tuning
	_engine_box.visible = tuning and _tab == Tab.ENGINE
	setting.visible = tuning and _tab == Tab.SETTING
	master.visible = tuning and _tab == Tab.MASTER
	driver.visible = building == "depot"
	office.visible = building == Town.OFFICE
	_car_box.visible = building == "car_center"
	for id: String in building_buttons:
		building_buttons[id].set_pressed_no_signal(id == building)
	engine_tab_button.set_pressed_no_signal(_tab == Tab.ENGINE)
	setting_tab_button.set_pressed_no_signal(_tab == Tab.SETTING)
	master_tab_button.set_pressed_no_signal(_tab == Tab.MASTER)


func current_tab() -> Tab:
	return _tab


## 강화나 돌리기 뜸 중 (이때는 강화·돌리기 버튼 둘 다 잠김)
func is_busy() -> bool:
	return _busy or setting.is_busy()


# ---------------- 강화 연출 ----------------

## 뜸 시작: 버튼 잠그고 "강화 중…"
func begin_suspense() -> void:
	_busy = true
	_enhance_button.disabled = true
	_enhance_button.text = tr("GARAGE_ENHANCING")
	clear_result()


func end_suspense() -> void:
	_busy = false
	_enhance_button.text = tr("GARAGE_ENHANCE")


## 성공: 번쩍 + 제목 "+N" 커졌다 돌아옴
func celebrate() -> void:
	flash(Color(1, 1, 1, Feel.FLASH_ALPHA), Feel.FLASH_DURATION)
	Town.pop(_title, Feel.POP_PIVOT_LEFT)


## 차고 전체가 color로 번쩍였다가 사라짐 (강화 성공 하양, 세팅 등급업은 등급 색)
func flash(color: Color, seconds: float) -> void:
	_flash.color = color
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_flash, "color:a", 0.0, seconds)


## 상태에 맞게 글자와 버튼을 고친다 (열려 있는 동안 매 프레임)
func refresh(b: Balance, s: GameState) -> void:
	var agency := Company.stage(s) >= GameState.AGENCY
	building_buttons[Town.OFFICE].visible = agency
	if building == Town.OFFICE and not agency:   # F3 처음부터
		show_building("tuning")
	_refresh_trucks(s)
	var t := s.truck(truck)
	var at_max := t.star >= b.max_star
	var danger := false

	_title.text = tr("GARAGE_TITLE_MAX" if at_max else "GARAGE_TITLE") % t.star
	_master_line.visible = s.active_bonus != ""   # 방문 중에만 (Master.tick이 채움)
	if _master_line.visible:
		_master_line.text = tr("GARAGE_MASTER_VISIT") % Fmt.master_bonus(b.master_bonuses, s.active_bonus)
	_spares.text = tr("GARAGE_SPARES") % s.spares if s.premium_spares == 0 else tr("GARAGE_SPARES_BOTH") % [s.spares, s.premium_spares]
	var now := Trip.hourly_income(b, s, truck)
	var mine := Company.hourly_net(b, s)   # "약 N분 뒤": 모든 트럭 시간당 내 돈 (직원 몫·세금 뗀 뒤)
	var premium := s.use_premium and s.premium_spares > 0   # 퍼지면 고급을 먼저 씀 (Enhance.force_destroy와 같은 조건)
	premium_button.set_pressed_no_signal(s.use_premium)
	premium_button.disabled = is_busy()
	if at_max:
		_income.text = tr("GARAGE_HOURLY") % Fmt.money(int(now))
		_set_visible([_income], [_chances, _danger, _danger_note, _cost, _insure, _tries, _wait, _enhance_row, _enhance_button, to_car_button])
	else:
		var c := Enhance.chances_for(b, s, truck)   # 오늘 보험이 덮으면 퍼짐 0 (그만큼 실패)
		var insured := Economy.insured_at(b, t.star, s)
		var cost := Economy.enhance_cost(b, t.star, s)
		var fee := Enhance.insure_fee(s, b, truck)
		var block := Enhance.block_reason(s, b, truck)
		_income.text = tr("GARAGE_HOURLY_NEXT") % [Fmt.money(int(now)), Fmt.money(int(Trip.hourly_income_at(b, s, truck, t.star + 1)))]
		_chances.text = tr("GARAGE_CHANCES") % [
			Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
		danger = c["destroy"] > 0.0
		if insured:   # 퍼짐 확률 자리에 "보험: 퍼져도 단계 유지"
			_danger.text = tr("GARAGE_INSURED_SAFE")
			_danger.add_theme_color_override("font_color", Feel.COLOR_INSURED)
		else:
			_danger.text = tr("GARAGE_DANGER") % Fmt.percent(c["destroy"])
			_danger.add_theme_color_override("font_color", Feel.COLOR_DANGER)
		var notes := PackedStringArray([tr("GARAGE_DANGER_NOTE_PREMIUM") % [s.premium_spares, b.premium_drop_to] if premium \
				else tr("GARAGE_DANGER_NOTE") % b.broken_drop_to])
		if Visitor.insurer_event(s) == "recovery":   # 오늘 복구 보험 (가입 안 하고 퍼져도 이 단계 밑으로 안 내려감)
			notes.append(tr("GARAGE_RECOVERY_NOTE") % b.recovery_star)
		_danger_note.text = "\n".join(notes)
		var partner := cost < Economy.base_enhance_cost(b, t.star)   # 할인은 제휴 할인뿐 (가입한 날, 계산 쪽 Economy.enhance_cost)
		_cost.text = tr("GARAGE_COST_PARTNER") % [Fmt.money(cost), Fmt.percent(b.partner_discount)] if partner \
				else tr("GARAGE_COST") % Fmt.money(cost)
		_insure.text = tr("GARAGE_INSURE_LINE") % [Fmt.money(fee), Fmt.money(cost + fee)]
		_tries.text = tr("GARAGE_TRIES") % Economy.tries(s, b, truck)
		match block:
			Enhance.Block.NO_SPARE:
				_wait.text = tr("GARAGE_NEED_SPARE")
			Enhance.Block.NO_MONEY:
				_wait.text = tr("GARAGE_SHORT_WAIT") % Fmt.wait_text(Economy.seconds_to_afford(cost + fee, s.money, mine))
		_enhance_button.disabled = block != Enhance.Block.NONE or is_busy()
		_set_visible([_income, _chances, _cost, _enhance_row, _enhance_button], [])
		_insure.visible = fee > 0   # +17 이하·가입 안 함이면 보험료 줄 없음
		_danger.visible = danger or insured
		_danger_note.visible = danger
		_wait.visible = block != Enhance.Block.NONE
		_tries.visible = not _wait.visible   # 못 누르면 이유 줄이 대신 (0번 줄은 안 보여 줌)
		to_car_button.visible = block == Enhance.Block.NO_SPARE
	premium_button.visible = s.premium_spares > 0   # 부품상 선물을 받은 뒤에만

	# 카센터: 스페어 엔진
	var price := Economy.spare_price(b)
	_car_spares.text = tr("GARAGE_SPARES") % s.spares
	_car_note.text = tr("CAR_NOTE") % _first_spare_star(b)
	_spare_button.text = tr("GARAGE_BUY_SPARE") % Fmt.money(price)
	_spare_button.disabled = not s.can_buy_spare(b)
	_car_wait.visible = _spare_button.disabled
	if _car_wait.visible:
		_car_wait.text = tr("CAR_SHORT") % [Fmt.money(price - s.money), Fmt.wait_text(Economy.seconds_to_afford(price, s.money, mine))]

	# 퍼질 수 있는 단계면 빨간 테두리 (튜닝숍 [엔진 강화] 칸을 볼 때만. 세팅하다가 놀라지 않게)
	danger = danger and building == "tuning" and _tab == Tab.ENGINE
	_style.border_color = Feel.COLOR_DANGER if danger else Feel.COLOR_PANEL_BORDER
	_style.set_border_width_all(_px(Feel.PANEL_BORDER_DANGER if danger else Feel.PANEL_BORDER))

	_stats.text = tr("GARAGE_STATS") % [
		t.success_count + t.fail_count + t.destroy_count, t.success_count, t.fail_count, t.destroy_count]

	if setting.visible:
		setting.refresh(b, s, _busy)
	if driver.visible:
		driver.refresh(b, s)
	if master.visible:
		master.refresh(b, s, now_local)
	if office.visible:
		office.refresh(b, s)


## 트럭 탭: 계산 쪽 트럭 수만큼 (모자라면 만들고, F3 처음부터로 줄면 숨김). 1대거나 튜닝숍 [명장] 칸이면 줄째 숨김 (그때는 NPC 이름·인사말)
func _refresh_trucks(s: GameState) -> void:
	if truck >= s.trucks.size():
		pick_truck(0)
	while truck_buttons.size() < s.trucks.size():
		var i := truck_buttons.size()
		var tb := _toggle(_truck_row, tr("TRUCK_TAB_MINE") if i == 0 else tr("TRUCK_TAB_HELPER") % (i + 1), _truck_group)
		tb.pressed.connect(func(): pick_truck(i))
		tb.set_pressed_no_signal(i == truck)
		truck_buttons.append(tb)
	for i in truck_buttons.size():
		truck_buttons[i].visible = i < s.trucks.size()
	_truck_row.visible = building == "tuning" and _tab != Tab.MASTER and s.trucks.size() > 1
	_npc_words.visible = not _truck_row.visible


## 방금 일어난 일을 한 줄로 (+ 아래 작은 설명). font_size는 v0 패널 기준 (배수는 여기서 곱함)
func show_result(text: String, color: Color, font_size: int = Feel.PANEL_TEXT_SIZE, note := "") -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", color)
	_result_size = font_size
	_result.add_theme_font_size_override("font_size", _px(font_size))
	_result.visible = true
	_result_note.text = note
	_result_note.visible = note != ""


## 카센터에서 스페어를 산 결과 한 줄
func show_spare_bought(text: String) -> void:
	_car_result.text = text
	_car_result.visible = true


## 스페어가 있어야 강화할 수 있는 첫 단계 (Enhance.needs_spare를 단계마다 물어봄. 설명 글 "+18부터")
func _first_spare_star(b: Balance) -> int:
	for star in b.max_star:
		if Enhance.needs_spare(b, star):
			return star
	return b.max_star


func clear_result() -> void:
	_result.text = ""
	_result.visible = false
	_result_note.text = ""
	_result_note.visible = false


## 한 줄에서 하나만 눌린 채로 있는 버튼 (건물 줄, 튜닝숍 두 칸)
func _toggle(parent: Node, text: String, group: ButtonGroup) -> Button:
	var b := _button(parent, text, Feel.SETTING_TAB_SIZE)
	b.toggle_mode = true
	b.button_group = group
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
	b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	return b


func _set_visible(shown: Array, hidden: Array) -> void:
	for c in shown:
		c.visible = true
	for c in hidden:
		c.visible = false


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_font_size_override("font_size", _px(font_size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, font_size: int = Feel.PANEL_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = font_size
	btn.add_theme_font_size_override("font_size", _px(font_size))
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
