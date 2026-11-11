## 복귀 팝업: 게임을 켰을 때 "자리 비운 N시간 동안 +금액". [확인]을 누르면 닫힘.
## 보여주기만 한다. 금액 계산은 main.gd → economy.gd
extends PanelContainer

const Feel = preload("res://scripts/ui/feel.gd")

var _main_label: Label
var _note_label: Label


func _ready() -> void:
	custom_minimum_size.x = Feel.POPUP_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = Feel.COLOR_PANEL_BG
	style.border_color = Feel.COLOR_PAYOUT
	style.set_border_width_all(Feel.PANEL_BORDER)
	style.set_corner_radius_all(Feel.PANEL_RADIUS)
	style.set_content_margin_all(Feel.PANEL_PADDING)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_main_label = Label.new()
	_main_label.add_theme_font_size_override("font_size", Feel.POPUP_MAIN_SIZE)
	_main_label.add_theme_color_override("font_color", Feel.COLOR_TEXT)
	_main_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_main_label)

	_note_label = Label.new()
	_note_label.add_theme_font_size_override("font_size", Feel.POPUP_NOTE_SIZE)
	_note_label.add_theme_color_override("font_color", Feel.COLOR_DIM)
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note_label)

	var ok := Button.new()
	ok.text = "확인"
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", Feel.PANEL_BUTTON_SIZE)
	ok.pressed.connect(func(): visible = false)
	box.add_child(ok)


func open(main_text: String, note: String) -> void:
	_main_label.text = main_text
	_note_label.text = note
	_note_label.visible = note != ""
	visible = true
	reset_size()


func main_text() -> String:
	return _main_label.text


func note_text() -> String:
	return _note_label.text
