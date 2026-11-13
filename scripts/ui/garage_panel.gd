## 건물 화면: 큰 화면 오른쪽에 크게 보인다 (작은 화면에서는 안 보임).
## 크기는 set_ui_scale()로 정한다 (1 = v0 패널 크기).
## v3: 트럭 0의 엔진 강화 + 스페어 엔진(들고 있는 개수, 언제든 구매). 고장 상태는 없음 (퍼지면 스페어를 써서 +15)
## v4: [엔진 강화] / [세팅] 두 칸. [세팅] 칸은 setting_tab.gd
## v5: 기사 레벨·다음 할 일·창고 확장·야간 배송팀 (driver_tab.gd)
## v6a: 위쪽 줄에서 건물을 고름 (튜닝숍 / 물류센터 / 카센터). 건물마다 NPC 한 줄.
##      튜닝숍 = [엔진 강화] [세팅 돌리기] 두 칸, 물류센터 = driver_tab.gd, 카센터 = 스페어 엔진 사기
## 보여주기만 한다. 버튼을 누르면 신호만 보내고, 실제 강화·구매·돌리기는 main.gd → scripts/core 가 한다.
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const SettingTab = preload("res://scripts/ui/setting_tab.gd")
const DriverTab = preload("res://scripts/ui/driver_tab.gd")

signal enhance_pressed
signal spare_pressed

const TRUCK := 0   ## 지금은 트럭 1대 (고르는 탭은 v7)

enum Tab { ENGINE, SETTING }   ## 튜닝숍 안 두 칸
## 건물마다 NPC 이름·인사말 번역 키 (건물 이름은 Town.BUILDING_NAMES)
const NPC_KEYS := {
	"tuning": ["NPC_TUNING", "NPC_TUNING_HELLO"],
	"depot": ["NPC_DEPOT", "NPC_DEPOT_HELLO"],
	"car_center": ["NPC_CAR_CENTER", "NPC_CAR_CENTER_HELLO"],
}

var building := "tuning"         ## 지금 보는 건물 (Town.BUILDINGS 중 하나)
var building_buttons := {}       ## 건물 id → 위쪽 줄 버튼
var engine_tab_button: Button    ## 튜닝숍 [엔진 강화]
var setting_tab_button: Button   ## 튜닝숍 [세팅]
var to_car_button: Button        ## 스페어가 없어 강화가 막혔을 때 [카센터로]
var setting: SettingTab          ## 튜닝숍 [세팅] 칸
var driver: DriverTab            ## 물류센터 화면

var _style: StyleBoxFlat
var _building_row: HBoxContainer
var _npc_row: HBoxContainer
var _npc_face: ColorRect
var _npc_name: Label
var _npc_hello: Label
var _car_box: VBoxContainer      ## 카센터 화면
var _car_spares: Label
var _car_note: Label             ## "+18부터 강화하려면 1개가 있어야 해요…"
var _car_wait: Label             ## 모자란 금액
var _car_result: Label
var _tabs: HBoxContainer
var _enhance_row: HBoxContainer   ## [강화] [카센터로]
var _engine_box: VBoxContainer   ## [엔진 강화] 칸
var _tab := Tab.ENGINE
var _title: Label
var _spares: Label    ## "스페어 엔진 N개"
var _income: Label
var _chances: Label
var _danger: Label
var _danger_note: Label   ## "퍼지면 스페어 엔진 1개를 써서 +15로"
var _cost: Label
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
	for id: String in Town.BUILDINGS:
		var bb := _toggle(_building_row, tr(Town.BUILDING_NAMES[id]), bgroup)
		bb.pressed.connect(func(): show_building(id))
		building_buttons[id] = bb

	# NPC 한 줄: 임시 사각형 얼굴 + 이름 + 인사말
	_npc_row = HBoxContainer.new()
	_box.add_child(_npc_row)
	_npc_face = ColorRect.new()
	_npc_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_npc_row.add_child(_npc_face)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_npc_row.add_child(words)
	_npc_name = _label(words, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_npc_hello = _label(words, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)

	# 튜닝숍 안 두 칸 고르기
	_tabs = HBoxContainer.new()
	_box.add_child(_tabs)
	var group := ButtonGroup.new()
	engine_tab_button = _toggle(_tabs, tr("GARAGE_TAB_ENGINE"), group)
	setting_tab_button = _toggle(_tabs, tr("GARAGE_TAB_SETTING"), group)
	engine_tab_button.pressed.connect(func(): show_tab(Tab.ENGINE))
	setting_tab_button.pressed.connect(func(): show_tab(Tab.SETTING))

	var e := VBoxContainer.new()
	_engine_box = e
	_box.add_child(e)
	_title = _label(e, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_spares = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_income = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_danger = _label(e, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_danger_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_cost = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_wait = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	# [강화] 옆에 [카센터로] (스페어가 없어 막혔을 때만. 한 줄에 둬서 칸이 길어지지 않게)
	_enhance_row = HBoxContainer.new()
	e.add_child(_enhance_row)
	_enhance_button = _button(_enhance_row, tr("GARAGE_ENHANCE"))
	_enhance_button.pressed.connect(func(): enhance_pressed.emit())
	to_car_button = _button(_enhance_row, tr("GARAGE_TO_CAR"))
	to_car_button.pressed.connect(func(): show_building("car_center"))
	for btn in [_enhance_button, to_car_button]:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_result = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	clear_result()
	_stats = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	setting = SettingTab.new()
	_box.add_child(setting)
	driver = DriverTab.new()
	_box.add_child(driver)

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
	for row: Control in [_tabs, _building_row, _npc_row, _car_box, _enhance_row]:
		row.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_npc_face.custom_minimum_size = Vector2.ONE * Feel.NPC_FACE_SIZE * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))
	_result.add_theme_font_size_override("font_size", _px(_result_size))
	setting.set_ui_scale(s)
	driver.set_ui_scale(s)
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


## 튜닝숍 [엔진 강화] / [세팅] 칸 바꾸기 (튜닝숍 화면으로)
func show_tab(t: Tab) -> void:
	_tab = t
	show_building("tuning")


func _show_parts() -> void:
	var tuning := building == "tuning"
	_tabs.visible = tuning
	_engine_box.visible = tuning and _tab == Tab.ENGINE
	setting.visible = tuning and _tab == Tab.SETTING
	driver.visible = building == "depot"
	_car_box.visible = building == "car_center"
	for id: String in building_buttons:
		building_buttons[id].set_pressed_no_signal(id == building)
	engine_tab_button.set_pressed_no_signal(_tab == Tab.ENGINE)
	setting_tab_button.set_pressed_no_signal(_tab == Tab.SETTING)


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
	var t := s.truck(TRUCK)
	var at_max := t.star >= b.max_star
	var danger := false

	_title.text = tr("GARAGE_TITLE_MAX" if at_max else "GARAGE_TITLE") % t.star
	_spares.text = tr("GARAGE_SPARES") % s.spares
	var now := Trip.hourly_income(b, t)
	if at_max:
		_income.text = tr("GARAGE_HOURLY") % Fmt.money(int(now))
		_set_visible([_income], [_chances, _danger, _danger_note, _cost, _wait, _enhance_row, _enhance_button, to_car_button])
	else:
		var c := Enhance.chances_for(b, t)
		var cost := Economy.enhance_cost(b, t.star)
		var block := Enhance.block_reason(s, b, TRUCK)
		_income.text = tr("GARAGE_HOURLY_NEXT") % [Fmt.money(int(now)), Fmt.money(int(Trip.hourly_income_at(b, t, t.star + 1)))]
		_chances.text = tr("GARAGE_CHANCES") % [
			Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
		danger = c["destroy"] > 0.0
		_danger.text = tr("GARAGE_DANGER") % Fmt.percent(c["destroy"])
		_danger_note.text = tr("GARAGE_DANGER_NOTE") % b.broken_drop_to
		_cost.text = tr("GARAGE_COST") % Fmt.money(cost)
		match block:
			Enhance.Block.NO_SPARE:
				_wait.text = tr("GARAGE_NEED_SPARE")
			Enhance.Block.NO_MONEY:
				_wait.text = tr("GARAGE_SHORT_WAIT") % Fmt.wait_text(Economy.seconds_to_afford(cost, s.money, now))
		_enhance_button.disabled = block != Enhance.Block.NONE or is_busy()
		_set_visible([_income, _chances, _cost, _enhance_row, _enhance_button], [])
		_danger.visible = danger
		_danger_note.visible = danger
		_wait.visible = block != Enhance.Block.NONE
		to_car_button.visible = block == Enhance.Block.NO_SPARE

	# 카센터: 스페어 엔진
	var price := Economy.spare_price(b)
	_car_spares.text = tr("GARAGE_SPARES") % s.spares
	_car_note.text = tr("CAR_NOTE") % _first_spare_star(b)
	_spare_button.text = tr("GARAGE_BUY_SPARE") % Fmt.money(price)
	_spare_button.disabled = not s.can_buy_spare(b)
	_car_wait.visible = _spare_button.disabled
	if _car_wait.visible:
		_car_wait.text = tr("CAR_SHORT") % [Fmt.money(price - s.money), Fmt.wait_text(Economy.seconds_to_afford(price, s.money, now))]

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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, font_size: int = Feel.PANEL_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = font_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
