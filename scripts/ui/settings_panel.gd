## 큰 화면 [설정]을 누르면 가운데 뜨는 화면. v8b: 세 묶음 + [기본값으로] [닫기]
##   게임: 언어, 숫자 표기, 알림, 급송 요청 전화 / 띠: 항상 위, 투명도, 크기, 자리, 모니터 / 큰 화면: 전체 화면·창 모드
## 고르면 신호만 보낸다. 저장·적용은 main.gd (Prefs 값: pref_picked → Prefs.set_value, 급송 전화: 게임 저장,
## 큰 화면 방식: screen_mode.gd). 지금 값은 main.gd가 show_style()·show_rush()·show_prefs()로 알려준다.
extends PanelContainer

const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Prefs = preload("res://scripts/ui/prefs.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

signal style_picked(style: ScreenMode.FullStyle)
signal close_pressed
signal rush_picked(on: bool)   ## 급송 요청 전화 켜기 / 끄기
signal pref_picked(key: String, value: Variant)   ## Prefs 키와 고른 값
signal defaults_pressed

## 묶음별 Prefs 줄 [이름 번역 키, Prefs 키]. 값 버튼은 Prefs.CHOICES 순서 (모니터는 주 모니터 + 연결된 수만큼)
const GAME_ROWS := [["SETTINGS_LANGUAGE", "ui/locale"], ["SETTINGS_NUMBERS", "ui/number_style"], ["SETTINGS_NOTICES", "ui/notices"]]
const STRIP_ROWS := [["SETTINGS_ON_TOP", "strip/always_on_top"], ["SETTINGS_OPACITY", "strip/opacity"],
		["SETTINGS_STRIP_SIZE", "strip/scale"], ["SETTINGS_CORNER", "strip/corner"], ["SETTINGS_MONITOR", "strip/screen"]]
## 값 버튼 글 번역 키 (켜기/끄기·퍼센트·모니터 번호는 _value_text가 만듦)
const VALUE_KEYS := {
	"ui/locale": { "ko": "SETTINGS_LOCALE_KO", "en": "SETTINGS_LOCALE_EN" },
	"ui/number_style": { "auto": "SETTINGS_NUMBERS_AUTO", "ko": "SETTINGS_NUMBERS_KO", "en": "SETTINGS_NUMBERS_EN" },
	"strip/corner": { "right": "SETTINGS_CORNER_RIGHT", "left": "SETTINGS_CORNER_LEFT" },
}

var fullscreen_button: Button
var windowed_button: Button
var close_button: Button
var rush_on_button: Button
var rush_off_button: Button
var defaults_button: Button
var pref_buttons := {}   ## Prefs 키 → { 값: 버튼 }

var _style: StyleBoxFlat
var _box: VBoxContainer
var _rows: Array[BoxContainer] = []      ## 버튼 줄 (간격을 배수로)
var _grids: Array[GridContainer] = []    ## 묶음마다 [이름 | 버튼 줄] 표
var _monitor_row: HBoxContainer
var _keys := {}         ## 글자 → 번역 키 (언어를 바꾸면 retranslate가 다시 씀)
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기
var _scale := 1.0


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.border_color = Feel.COLOR_PANEL_BORDER
	add_theme_stylebox_override("panel", _style)

	_box = VBoxContainer.new()
	add_child(_box)
	_label(_box, "SETTINGS", Feel.PANEL_TITLE_SIZE, Feel.COLOR_TEXT)

	var game := _group("SETTINGS_GROUP_GAME")
	for r: Array in GAME_ROWS:
		_pref_row(game, r[0], r[1])
	var rush := _row(game, "SETTINGS_RUSH")
	rush_on_button = _toggle(rush, "SETTINGS_ON")
	rush_off_button = _toggle(rush, "SETTINGS_OFF")
	rush_on_button.pressed.connect(func(): rush_picked.emit(true))
	rush_off_button.pressed.connect(func(): rush_picked.emit(false))

	var strip := _group("SETTINGS_GROUP_STRIP")
	for r: Array in STRIP_ROWS:
		_pref_row(strip, r[0], r[1])

	var big := _group("SETTINGS_GROUP_BIG")
	var screen := _row(big, "SETTINGS_SCREEN")
	fullscreen_button = _toggle(screen, "SETTINGS_FULLSCREEN")
	windowed_button = _toggle(screen, "SETTINGS_WINDOWED")
	fullscreen_button.pressed.connect(func(): style_picked.emit(ScreenMode.FullStyle.FULLSCREEN))
	windowed_button.pressed.connect(func(): style_picked.emit(ScreenMode.FullStyle.WINDOWED))
	_label(_box, "SETTINGS_WINDOWED_NOTE", Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	var bottom := HBoxContainer.new()
	_box.add_child(bottom)
	_rows.append(bottom)
	defaults_button = _button(bottom, "SETTINGS_DEFAULTS", Feel.PANEL_BUTTON_SIZE)
	close_button = _button(bottom, "SETTINGS_CLOSE", Feel.PANEL_BUTTON_SIZE)
	defaults_button.pressed.connect(func(): defaults_pressed.emit())
	close_button.pressed.connect(func(): close_pressed.emit())
	set_ui_scale(_scale)


## 지금 값 표시 (누른 상태로). 신호는 안 보냄
func show_style(style: ScreenMode.FullStyle) -> void:
	fullscreen_button.set_pressed_no_signal(style == ScreenMode.FullStyle.FULLSCREEN)
	windowed_button.set_pressed_no_signal(style == ScreenMode.FullStyle.WINDOWED)


## 급송 요청 전화 지금 값 표시 (누른 상태로). 신호는 안 보냄
func show_rush(on: bool) -> void:
	rush_on_button.set_pressed_no_signal(on)
	rush_off_button.set_pressed_no_signal(not on)


## Prefs 지금 값 표시 (누른 상태로). 언어는 지금 쓰는 언어, 뽑힌 모니터는 주 모니터로 보임. 신호는 안 보냄
func show_prefs() -> void:
	_monitor_buttons()
	for key: String in pref_buttons:
		var cur: Variant = Prefs.get_value(key)
		if key == "ui/locale":
			cur = "ko" if TranslationServer.get_locale().begins_with("ko") else "en"
		elif key == "strip/screen" and not pref_buttons[key].has(cur):
			cur = -1
		for v: Variant in pref_buttons[key]:
			pref_buttons[key][v].set_pressed_no_signal(v == cur)


## 언어를 바꾸면 main.gd가 부름 (propagate_call)
func retranslate() -> void:
	for c: Control in _keys:
		c.text = tr(_keys[c])
	for key: String in pref_buttons:
		for v: Variant in pref_buttons[key]:
			pref_buttons[key][v].text = _value_text(key, v)


## 크기 배수 (1 = v0 패널 크기 기준)
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.SETTINGS_PANEL_WIDTH * s
	_style.set_border_width_all(maxi(1, int(roundf(Feel.PANEL_BORDER * s))))
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	_box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for row: BoxContainer in _rows:
		row.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for g: GridContainer in _grids:
		g.add_theme_constant_override("h_separation", int(roundf(Feel.PANEL_GAP * s)))
		g.add_theme_constant_override("v_separation", int(roundf(Feel.SETTINGS_ROW_GAP * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))
	reset_size()


## 묶음 제목 + 표 (이름 | 버튼 줄)
func _group(key: String) -> GridContainer:
	_label(_box, key, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	var grid := GridContainer.new()
	grid.columns = 2
	_box.add_child(grid)
	_grids.append(grid)
	return grid


## 표에 한 줄: 이름 + 버튼 줄 (줄 안 버튼은 하나만 눌림)
func _row(grid: GridContainer, key: String) -> HBoxContainer:
	var title := _label(grid, key, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("group", ButtonGroup.new())
	grid.add_child(row)
	_rows.append(row)
	return row


func _pref_row(grid: GridContainer, name_key: String, key: String) -> void:
	var row := _row(grid, name_key)
	pref_buttons[key] = {}
	if key == "strip/screen":
		_monitor_row = row   # 버튼은 연결된 모니터 수만큼 (_monitor_buttons)
		return
	for v: Variant in Prefs.CHOICES[key]:
		_pref_button(row, key, v)


func _pref_button(row: HBoxContainer, key: String, v: Variant) -> void:
	var btn := _toggle(row, "")
	btn.text = _value_text(key, v)
	btn.pressed.connect(func(): pref_picked.emit(key, v))
	pref_buttons[key][v] = btn


## 모니터 버튼: [주 모니터] [1] [2] … (연결된 수가 바뀌었으면 다시 만듦)
func _monitor_buttons() -> void:
	var n := DisplayServer.get_screen_count()
	var have: Dictionary = pref_buttons["strip/screen"]
	if have.size() == n + 1:
		return
	for btn: Button in have.values():
		_font_sizes.erase(btn)
		btn.free()
	have.clear()
	for v in range(-1, n):
		_pref_button(_monitor_row, "strip/screen", v)
	set_ui_scale(_scale)


func _value_text(key: String, v: Variant) -> String:
	match key:
		"ui/notices", "strip/always_on_top":
			return tr("SETTINGS_ON" if v else "SETTINGS_OFF")
		"strip/opacity", "strip/scale":
			return Fmt.percent(v)
		"strip/screen":
			return tr("SETTINGS_MONITOR_PRIMARY") if v < 0 else str(v + 1)
	return tr(VALUE_KEYS[key][v])


func _label(parent: Node, key: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys[l] = key
	_font_sizes[l] = font_size
	parent.add_child(l)
	return l


func _button(parent: Node, key: String, font_size: int) -> Button:
	var btn := Button.new()
	if key != "":
		btn.text = tr(key)
		_keys[btn] = key
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_sizes[btn] = font_size
	parent.add_child(btn)
	return btn


## 줄 안에서 하나만 눌리는 버튼. 고른 쪽은 글자를 노랗게 (눌린 모양만으로는 잘 안 보여서)
func _toggle(row: HBoxContainer, key: String) -> Button:
	var b := _button(row, key, Feel.PANEL_TEXT_SIZE)
	b.toggle_mode = true
	b.button_group = row.get_meta("group")
	b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
	b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	return b
