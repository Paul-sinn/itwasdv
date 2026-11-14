## NPC 대화 창 (v7-bal): 편지봉투를 누르면 큰 화면 가운데 뜬다. 명장·보험사·마술사·중고 부품상 공용.
##   [얼굴(임시 색 사각형) + 이름] / 대사 / 오늘 효과 한 줄 / (보험사) 보험료 규칙 한 줄 / [예] [아니오] 또는 [닫기]
##   보험사: 가입 전이면 [예] [아니오], 가입 뒤에는 "가입됨" 줄 + [닫기]
## 누가 왔는지·이벤트·가입 여부·효과 숫자는 main.gd가 묶음(info)으로 줌. 누르면 신호만 → main.gd
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")

signal yes_pressed
signal no_pressed
signal close_pressed

const NAMES := { "master": "NPC_MASTER", "insurer": "NPC_INSURER", "magician": "NPC_MAGICIAN", "dealer": "NPC_DEALER" }
const HELLOS := { "master": "NPC_MASTER_HELLO", "insurer": "NPC_INSURER_HELLO", "magician": "NPC_MAGICIAN_HELLO", "dealer": "NPC_DEALER_HELLO" }

var who := ""   ## 지금 보여 주는 NPC id
var yes_button: Button
var no_button: Button
var close_button: Button

var _style: StyleBoxFlat
var _box: VBoxContainer
var _head: HBoxContainer
var _row: HBoxContainer
var _face: ColorRect
var _name: Label
var _line: Label     ## 대사
var _effect: Label   ## 오늘 효과 한 줄 (보험사는 오늘 이벤트)
var _rule: Label     ## 보험사: 보험료 규칙 한 줄
var _status: Label   ## 보험사: 가입됨
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기
var _scale := 1.0


func _ready() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	add_theme_stylebox_override("panel", _style)

	_box = VBoxContainer.new()
	add_child(_box)
	_head = HBoxContainer.new()
	_box.add_child(_head)
	_face = ColorRect.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_face)
	_name = _label(_head, Feel.PANEL_TITLE_SIZE, Feel.COLOR_TEXT)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_line = _label(_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_effect = _label(_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_rule = _label(_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_status = _label(_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_INSURED)
	_status.text = tr("NPC_INSURED")
	_row = HBoxContainer.new()
	_box.add_child(_row)
	yes_button = _button(_row, tr("NPC_YES"))
	yes_button.pressed.connect(yes_pressed.emit)
	no_button = _button(_row, tr("NPC_NO"))
	no_button.pressed.connect(no_pressed.emit)
	close_button = _button(_box, tr("SETTINGS_CLOSE"))
	close_button.pressed.connect(close_pressed.emit)
	set_ui_scale(_scale)


## info = main.gd _visitor_info(): { who, event(보험사 이벤트 id), insured, 효과 숫자 (bonus / up_mult / gift·drop_to / fee_mult·discount·recovery_star) }
func open(b: Balance, info: Dictionary) -> void:
	who = info["who"]
	var face: Color = Feel.NPC_FACE_COLORS[who]
	_face.color = face
	_style.border_color = face
	_name.text = tr(NAMES[who])
	_line.text = tr(HELLOS[who])
	var insurer := who == "insurer"
	var insured: bool = insurer and info.get("insured", false)
	match who:
		"master":
			_effect.text = tr("NPC_EFFECT_MASTER") % Fmt.master_bonus(b.master_bonuses, info["bonus"])
		"magician":
			_effect.text = tr("NPC_EFFECT_MAGICIAN") % Fmt.num(info["up_mult"])
		"dealer":
			_effect.text = tr("NPC_EFFECT_DEALER") % [info["gift"], b.broken_drop_to, info["drop_to"]]
		"insurer":
			match info.get("event", ""):
				"partner_discount": _effect.text = tr("NPC_EVENT_PARTNER_DISCOUNT") % Fmt.percent(info["discount"])
				"recovery": _effect.text = tr("NPC_EVENT_RECOVERY") % [b.broken_drop_to, info["recovery_star"]]
				_: _effect.text = ""
			_rule.text = tr("NPC_INSURER_RULE") % Fmt.num(info["fee_mult"])
	_effect.visible = _effect.text != ""
	_rule.visible = insurer
	_status.visible = insured
	_row.visible = insurer and not insured
	close_button.visible = not _row.visible
	visible = true
	reset_size()


## 크기 배수 (1 = v0 패널 크기 기준. [설정] 화면과 같은 폭)
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.SETTINGS_WIDTH * s
	_style.set_border_width_all(maxi(1, int(roundf(Feel.PANEL_BORDER_DANGER * s))))
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	for box: BoxContainer in [_box, _head, _row]:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP * s)))
	_face.custom_minimum_size = Vector2.ONE * Feel.NPC_FACE_SIZE * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))
	reset_size()


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_sizes[l] = font_size
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게 (보험 [예]는 돈이 걸림)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_sizes[btn] = Feel.PANEL_BUTTON_SIZE
	parent.add_child(btn)
	return btn
