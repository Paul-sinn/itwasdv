## 요일 고르기 창 (v6b): 엔진 +10 첫 달성(master_unlocked)에 큰 화면 튜닝숍 가운데 뜬다.
##   "명장이 찾아왔어요!" / "어떤 요일에 명장이 오면 좋겠어요?" / 요일 버튼 7개 / [나중에 고를게요]
## 고르면 신호만 → main.gd → Master.set_day. 안 고르고 닫아도 튜닝숍 [명장] 칸에서 언제든 고를 수 있음
extends PanelContainer

const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")

signal day_picked(day: int)   ## 0 = 월 … 6 = 일
signal close_pressed

var day_buttons: Array[Button] = []
var later_button: Button

var _style: StyleBoxFlat
var _box: VBoxContainer
var _row: HBoxContainer
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기
var _texts: Array[Control] = []   ## TEXT_KEYS 순 글자 (제목, 물음, 안내, [나중에])
const TEXT_KEYS := ["MASTER_PICKER_TITLE", "MASTER_PICKER_ASK", "MASTER_PICK_FIRST", "MASTER_PICKER_LATER"]
var _scale := 1.0


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.border_color = Feel.COLOR_MASTER
	add_theme_stylebox_override("panel", _style)

	_box = VBoxContainer.new()
	add_child(_box)
	_texts.append(_label("", Feel.PANEL_TITLE_SIZE, Feel.COLOR_MASTER))
	_texts.append(_label("", Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT))
	_row = HBoxContainer.new()
	_box.add_child(_row)
	for d in 7:
		var b := _button(_row, "", Feel.MASTER_DAY_BUTTON_SIZE)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(day_picked.emit.bind(d))
		day_buttons.append(b)
	_texts.append(_label("", Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM))
	later_button = _button(_box, "", Feel.PANEL_BUTTON_SIZE)
	later_button.pressed.connect(close_pressed.emit)
	_texts.append(later_button)
	retranslate()
	set_ui_scale(_scale)


## 한 번만 넣는 글자 (언어를 바꾸면 main.gd가 다시 부름)
func retranslate() -> void:
	for i in TEXT_KEYS.size():
		_texts[i].text = tr(TEXT_KEYS[i])
	for d in day_buttons.size():
		day_buttons[d].text = Fmt.day_name(d, true)


## 크기 배수 (1 = v0 패널 크기 기준. [설정] 화면과 같은 폭)
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.SETTINGS_WIDTH * s
	_style.set_border_width_all(maxi(1, int(roundf(Feel.PANEL_BORDER_DANGER * s))))
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	for box: BoxContainer in [_box, _row]:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))
	reset_size()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_font_sizes[l] = font_size
	_box.add_child(l)
	return l


func _button(parent: Node, text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	_font_sizes[btn] = font_size
	parent.add_child(btn)
	return btn
