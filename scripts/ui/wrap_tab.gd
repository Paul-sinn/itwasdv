## 튜닝숍 [랩핑] 칸 (v8a). 네 번째 칸: [엔진 강화] [세팅 돌리기] [명장] [랩핑]
##   맨 위 한 줄 설명 (차체 색·무늬만, 성능 그대로), 랩핑 카드 (Wrap.ids 순서):
##   [미리 보기 (Truck.draw_body)] [이름 / 아래 작은 줄] [버튼]
##     안 가짐 + 구매용: [값] (돈이 모자라면 꺼짐)   안 가짐 + 보상용: 아래 줄 "업적 '…' 달성하면 받아요", 버튼 없음
##     가짐: [입히기]   고른 트럭이 입는 중: 아래 줄 "입는 중" + [벗기기] (기본 = 랩핑 없음으로)
##   트럭은 튜닝숍 트럭 탭에서 고른 트럭 (garage_panel.truck). 미리 보기 바탕색도 그 트럭 원래 색
## 버튼은 신호만 → main.gd → Wrap.buy / Wrap.wear. 값·가진 것·보상 업적은 Wrap 그대로
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
## shortcut: C2 전 껍데기 (약속과 같은 이름·인자). 합치면 scripts/core/wrap.gd, Wrap.worn(s, i) → s.truck(i).wrap
const Wrap = preload("res://scripts/ui/stub_wrap.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Truck = preload("res://scripts/ui/truck.gd")

signal buy_pressed(id: String)    ## [값]
signal wear_pressed(id: String)   ## [입히기] (id) / [벗기기] ("")

var buttons := {}    ## 랩핑 id → 오른쪽 버튼 ([값] / [입히기] / [벗기기])
var notes := {}      ## 랩핑 id → 이름 아래 작은 줄 ("업적 … 달성하면 받아요" / "입는 중")
var names := {}      ## 랩핑 id → 이름
var previews := {}   ## 랩핑 id → 미리 보기

var _note: Label
var _actions := {}   ## 랩핑 id → 버튼을 누르면 할 일: "buy" / "wear" / "off"
var _truck := 0      ## 미리 보기 바탕색을 정한 트럭
var _scale := 1.0
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	_note = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_note.text = tr("WRAP_NOTE")
	set_ui_scale(_scale)


func set_ui_scale(s: float) -> void:
	_scale = s
	add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for id: String in previews:
		previews[id].custom_minimum_size = Feel.WRAP_PREVIEW_SIZE * s
		previews[id].get_parent().add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))


## 지금 상태대로 카드 (보이는 동안 매 프레임). i = 튜닝숍 트럭 탭에서 고른 트럭
func refresh(b: Balance, s: GameState, i: int) -> void:
	if buttons.is_empty():
		_build(b)
	if _truck != i:
		_truck = i
		for id: String in previews:
			previews[id].queue_redraw()
	var worn := Wrap.worn(s, i)
	for id: String in buttons:
		var btn: Button = buttons[id]
		var note: Label = notes[id]
		var have := Wrap.owned(s, id)
		var price := Wrap.price(b, id)
		btn.visible = have or price > 0
		note.visible = id == worn or (not have and price <= 0)
		note.add_theme_color_override("font_color", Feel.COLOR_WRAP_WORN if id == worn else Feel.COLOR_DIM)
		btn.disabled = false
		if id == worn:
			note.text = tr("WRAP_WORN")
			btn.text = tr("WRAP_TAKE_OFF")
			_actions[id] = "off"
		elif have:
			btn.text = tr("WRAP_WEAR")
			_actions[id] = "wear"
		elif price > 0:
			btn.text = tr("WRAP_BUY") % Fmt.money(price)
			btn.disabled = not Wrap.can_buy(b, s, id)
			_actions[id] = "buy"
		else:
			note.text = tr("WRAP_FROM_ACH") % tr("ACH_" + Wrap.reward_of(b, id).to_upper())


## 카드 만들기 (Wrap.ids 순서): [미리 보기] [이름 / 작은 줄] [버튼]
func _build(b: Balance) -> void:
	for id: String in Wrap.ids(b):
		var row := HBoxContainer.new()
		add_child(row)
		var pv := Control.new()
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pv.draw.connect(_draw_preview.bind(pv, id))
		row.add_child(pv)
		previews[id] = pv
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		names[id] = _label(words, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		names[id].text = tr("WRAP_" + id.to_upper())
		notes[id] = _label(words, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		var btn := Button.new()
		_font_sizes[btn] = Feel.PANEL_TEXT_SIZE
		btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(_on_button.bind(id))
		row.add_child(btn)
		buttons[id] = btn
	set_ui_scale(_scale)


## 오른쪽 버튼: 입는 중이면 벗기기, 가졌으면 입히기, 아니면 사기 (보상용은 버튼이 안 보임)
func _on_button(id: String) -> void:
	match _actions.get(id, ""):
		"off":
			wear_pressed.emit("")
		"wear":
			wear_pressed.emit(id)
		"buy":
			buy_pressed.emit(id)


## 미리 보기: 오른쪽을 보는 트럭 한 대를 칸 가운데에 칸 높이에 맞춰 (고른 트럭 원래 색 + 그 랩핑)
func _draw_preview(pv: Control, id: String) -> void:
	var k := minf(pv.size.y / Truck.body_height(), pv.size.x / Feel.TRUCK_SIZE.x)
	var at := (pv.size - Vector2(Feel.TRUCK_SIZE.x, Truck.body_height()) * k) / 2.0
	pv.draw_set_transform(at, 0.0, Vector2(k, k))
	Truck.draw_body(pv, 1, Truck.base_color(_truck), id)


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l
