## 큰 화면 [설정]을 누르면 가운데 뜨는 작은 화면: "화면: 전체 화면 / 창 모드".
## 고르면 신호만 보낸다. 실제 창 바꾸기와 설정 저장은 screen_mode.gd (창 담당).
## 지금 고른 값은 main.gd가 screen.full_style을 보고 show_style()로 알려준다.
extends PanelContainer

const Feel = preload("res://scripts/ui/feel.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

signal style_picked(style: ScreenMode.FullStyle)
signal close_pressed

var fullscreen_button: Button
var windowed_button: Button
var close_button: Button

var _style: StyleBoxFlat
var _box: VBoxContainer
var _row: HBoxContainer
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기
var _scale := 1.0


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.border_color = Feel.COLOR_PANEL_BORDER
	add_theme_stylebox_override("panel", _style)

	_box = VBoxContainer.new()
	add_child(_box)
	_label("설정", Feel.PANEL_TITLE_SIZE, Feel.COLOR_TEXT)
	_label("화면", Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	_row = HBoxContainer.new()
	_box.add_child(_row)
	var group := ButtonGroup.new()
	fullscreen_button = _button(_row, "전체 화면")
	windowed_button = _button(_row, "창 모드")
	for b in [fullscreen_button, windowed_button]:
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 고른 쪽은 글자를 노랗게 (눌린 모양만으로는 잘 안 보여서)
		b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	fullscreen_button.pressed.connect(func(): style_picked.emit(ScreenMode.FullStyle.FULLSCREEN))
	windowed_button.pressed.connect(func(): style_picked.emit(ScreenMode.FullStyle.WINDOWED))
	_label("창 모드는 창 크기를 마음대로 바꿀 수 있어요.", Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	close_button = _button(_box, "닫기")
	close_button.pressed.connect(func(): close_pressed.emit())
	set_ui_scale(_scale)


## 지금 값 표시 (누른 상태로). 신호는 안 보냄
func show_style(style: ScreenMode.FullStyle) -> void:
	fullscreen_button.set_pressed_no_signal(style == ScreenMode.FullStyle.FULLSCREEN)
	windowed_button.set_pressed_no_signal(style == ScreenMode.FullStyle.WINDOWED)


## 크기 배수 (1 = v0 패널 크기 기준)
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.SETTINGS_WIDTH * s
	_style.set_border_width_all(maxi(1, int(roundf(Feel.PANEL_BORDER * s))))
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	_row.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))
	reset_size()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_sizes[l] = font_size
	_box.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	_font_sizes[btn] = Feel.PANEL_BUTTON_SIZE
	parent.add_child(btn)
	return btn
