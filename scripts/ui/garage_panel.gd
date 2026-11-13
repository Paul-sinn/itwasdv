## 차고: 전체 화면 오른쪽에 크게 보인다 (작은 화면에서는 안 보임).
## 크기는 set_ui_scale()로 정한다 (1 = v0 패널 크기).
## v3: 트럭 0의 엔진 강화 + 스페어 엔진(들고 있는 개수, 언제든 구매). 고장 상태는 없음 (퍼지면 스페어를 써서 +15)
## v4: 위쪽 [엔진 강화] / [세팅] 두 칸 (처음엔 [엔진 강화]). [세팅] 칸은 setting_tab.gd
## v5: [기사·물류센터] 칸 더함 (driver_tab.gd: 기사 레벨·다음 할 일·창고 확장·야간 배송팀)
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

enum Tab { ENGINE, SETTING, DRIVER }

var engine_tab_button: Button    ## 위쪽 [엔진 강화]
var setting_tab_button: Button   ## 위쪽 [세팅]
var driver_tab_button: Button    ## 위쪽 [기사·물류센터]
var setting: SettingTab          ## [세팅] 칸
var driver: DriverTab            ## [기사·물류센터] 칸

var _style: StyleBoxFlat
var _tabs: HBoxContainer
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

	# 위쪽 두 칸 고르기
	_tabs = HBoxContainer.new()
	_box.add_child(_tabs)
	var group := ButtonGroup.new()
	engine_tab_button = _button(_tabs, tr("GARAGE_TAB_ENGINE"), Feel.SETTING_TAB_SIZE)
	setting_tab_button = _button(_tabs, tr("GARAGE_TAB_SETTING"), Feel.SETTING_TAB_SIZE)
	driver_tab_button = _button(_tabs, tr("GARAGE_TAB_DRIVER"), Feel.SETTING_TAB_SIZE)
	for b in [engine_tab_button, setting_tab_button, driver_tab_button]:
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	engine_tab_button.pressed.connect(func(): show_tab(Tab.ENGINE))
	setting_tab_button.pressed.connect(func(): show_tab(Tab.SETTING))
	driver_tab_button.pressed.connect(func(): show_tab(Tab.DRIVER))

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

	_enhance_button = _button(e, tr("GARAGE_ENHANCE"))
	_enhance_button.pressed.connect(func(): enhance_pressed.emit())
	_spare_button = _button(e, "")
	_spare_button.pressed.connect(func(): spare_pressed.emit())

	_result = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	clear_result()
	_stats = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	setting = SettingTab.new()
	_box.add_child(setting)
	driver = DriverTab.new()
	_box.add_child(driver)

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
	_tabs.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
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


## [엔진 강화] / [세팅] / [기사·물류센터] 칸 바꾸기
func show_tab(t: Tab) -> void:
	_tab = t
	_engine_box.visible = t == Tab.ENGINE
	setting.visible = t == Tab.SETTING
	driver.visible = t == Tab.DRIVER
	engine_tab_button.set_pressed_no_signal(t == Tab.ENGINE)
	setting_tab_button.set_pressed_no_signal(t == Tab.SETTING)
	driver_tab_button.set_pressed_no_signal(t == Tab.DRIVER)


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
	_spare_button.text = tr("GARAGE_BUY_SPARE") % Fmt.money(Economy.spare_price(b))
	_spare_button.disabled = not s.can_buy_spare(b)
	var now := Trip.hourly_income(b, t)
	if at_max:
		_income.text = tr("GARAGE_HOURLY") % Fmt.money(int(now))
		_set_visible([_income], [_chances, _danger, _danger_note, _cost, _wait, _enhance_button])
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
		_set_visible([_income, _chances, _cost, _enhance_button], [])
		_danger.visible = danger
		_danger_note.visible = danger
		_wait.visible = block != Enhance.Block.NONE

	# 퍼질 수 있는 단계면 빨간 테두리 ([엔진 강화] 칸을 볼 때만. 세팅하다가 놀라지 않게)
	danger = danger and _tab == Tab.ENGINE
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


func clear_result() -> void:
	_result.text = ""
	_result.visible = false
	_result_note.text = ""
	_result_note.visible = false


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
