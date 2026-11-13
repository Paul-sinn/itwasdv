## 차고 [튜닝] 칸: 7부위 목록 (이름, 등급 색 글자, 지금 효과) → 하나 고르면 자세히:
## 하는 일 한 줄, 지금 효과 → 다음 등급 효과, 등급업 확률·비용, 돈 모자라면 "약 N분 뒤 가능",
## [튜닝] 버튼, 결과 한 줄. 맨 아래 튜닝 통계. 전설이면 "최고 등급" + 버튼 숨김.
## 보여주기만 한다. 버튼을 누르면 tune_pressed 신호만 보내고, 굴리기는 main.gd → Tune.try_tune.
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Tune = preload("res://scripts/core/tune.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const TuneText = preload("res://scripts/ui/tune_text.gd")
const Town = preload("res://scripts/ui/town.gd")

## [튜닝] 버튼을 누름 (part = 지금 고른 부위)
signal tune_pressed(part: String)

var selected: String = Tune.PARTS[0]   ## 자세히 보고 있는 부위
var tune_button: Button
## 부위 id → { "row": PanelContainer, "name": Label, "grade": Label, "effect": Label }
var rows := {}

var _list: VBoxContainer
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _hover := ""
var _detail_name: Label
var _detail_grade: Label
var _info: Label
var _effect: Label
var _chance: Label
var _warn: Label
var _max_label: Label
var _wait: Label
var _result: Label
var _stats: Label
var _busy := false     ## 튜닝 뜸 중
var _scale := 1.0
var _font_sizes := {}  ## 글자 → 배수 곱하기 전 크기
var _grade_names: Array[String] = []   ## 등급 이름 (열 폭 재기용)


func _ready() -> void:
	_style_normal = _row_style(Feel.COLOR_TUNE_ROW, Feel.COLOR_TUNE_ROW)
	_style_hover = _row_style(Feel.COLOR_TUNE_ROW_HOVER, Feel.COLOR_TUNE_ROW_HOVER)
	_style_selected = _row_style(Feel.COLOR_TUNE_ROW_HOVER, Feel.COLOR_STAR)

	_list = VBoxContainer.new()
	add_child(_list)
	for part in Tune.PARTS:
		_make_row(part)

	add_child(HSeparator.new())
	var head := HBoxContainer.new()
	add_child(head)
	_detail_name = _label(head, Feel.PANEL_TEXT_SIZE + 2, Feel.COLOR_TEXT)
	_detail_grade = _label(head, Feel.PANEL_TEXT_SIZE + 2, Feel.TUNE_GRADE_COLORS[0])
	_info = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chance = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_WARN)
	_warn.text = TuneText.NO_JACKPOT_WARNING
	_max_label = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_max_label.text = "최고 등급이에요"
	_wait = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	tune_button = Button.new()
	tune_button.text = "튜닝"
	tune_button.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	_font_sizes[tune_button] = Feel.PANEL_BUTTON_SIZE
	tune_button.pressed.connect(func(): tune_pressed.emit(selected))
	add_child(tune_button)

	_result = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result.visible = false
	_stats = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	set_ui_scale(_scale)
	_style_rows()


## 크기 배수 (1 = v0 패널). 차고(garage_panel.gd)가 부른다
func set_ui_scale(s: float) -> void:
	_scale = s
	if _list == null:
		return
	add_theme_constant_override("separation", _px(5.0))
	_list.add_theme_constant_override("separation", _px(Feel.TUNE_ROW_GAP))
	for st: StyleBoxFlat in [_style_normal, _style_hover, _style_selected]:
		st.set_content_margin_all(Feel.TUNE_ROW_PAD * s)
		st.content_margin_left = Feel.TUNE_ROW_PAD * 2.0 * s
		st.content_margin_right = Feel.TUNE_ROW_PAD * 2.0 * s
		st.set_border_width_all(_px(Feel.TUNE_ROW_BORDER))
		st.set_corner_radius_all(_px(4.0))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))
	_fit_columns()


## 지금 고른 부위 바꾸기 (목록 줄을 클릭해도 이걸 부름)
func select(part: String) -> void:
	if not rows.has(part):
		return
	if part != selected:
		clear_result()
	selected = part
	_style_rows()


## 상태에 맞게 글자와 버튼을 고친다 (보이는 동안 매 프레임). locked = 엔진 강화 뜸 중
func refresh(b: Balance, s: GameState, locked: bool) -> void:
	if _grade_names.is_empty():
		for g in Tune.max_grade(b) + 1:
			_grade_names.append(Tune.grade_name(b, g))
		_fit_columns()
	var no_jackpot := s.jackpot_chance(b) <= 0.0
	for part in Tune.PARTS:
		var r: Dictionary = rows[part]
		var g := s.grade(part)
		r["grade"].text = Tune.grade_name(b, g)
		_set_color(r["grade"], grade_color(g))
		r["effect"].text = TuneText.effect_text(part, Tune.effect(b, part, g))
		# 짐칸: 타이어가 일반이면 효과가 없으니 흐리게
		var dim: bool = part == "cargo" and no_jackpot
		_set_color(r["effect"], Feel.COLOR_DIM if dim else Feel.COLOR_TEXT)

	var part := selected
	var g := s.grade(part)
	var at_max := g >= Tune.max_grade(b)
	_detail_name.text = TuneText.part_name(part)
	_detail_grade.text = Tune.grade_name(b, g)
	_set_color(_detail_grade, grade_color(g))
	_info.text = TuneText.info(part)
	var now := TuneText.effect_text(part, Tune.effect(b, part, g))
	if at_max:
		_effect.text = "지금 %s" % now
	else:
		_effect.text = "지금 %s  →  %s: %s" % [now, Tune.grade_name(b, g + 1),
				TuneText.effect_text(part, Tune.effect(b, part, g + 1))]
	_warn.visible = part == "cargo" and no_jackpot
	_max_label.visible = at_max
	_chance.visible = not at_max
	tune_button.visible = not at_max
	var block := Tune.block_reason(s, b, part)
	_wait.visible = block == Tune.Block.NO_MONEY
	if not at_max:
		var cost := Tune.cost(b, g)
		_chance.text = "등급업 확률 %s · 비용 %s원 · 실패하면 그대로" % [
			Fmt.percent(Tune.up_chance(b, g)), Fmt.money(cost)]
		tune_button.disabled = block != Tune.Block.NONE or _busy or locked
		if _wait.visible:
			_wait.text = Fmt.wait_text(Economy.seconds_to_afford(cost, s.money, s.current_hourly(b)))
	_stats.text = "튜닝 누른 횟수 %d · 등급업 %d · 대박 배송 %d" % [
		s.tune_press_count, s.tune_up_count, s.jackpot_count]


# ---------------- 튜닝 연출 ----------------

## 뜸 시작: 버튼 잠그고 "튜닝 중…"
func begin_suspense() -> void:
	_busy = true
	tune_button.disabled = true
	tune_button.text = "튜닝 중…"
	clear_result()


func end_suspense() -> void:
	_busy = false
	tune_button.text = "튜닝"


func is_busy() -> bool:
	return _busy


## 등급업: 그 부위 등급 글자가 커졌다 돌아옴 (번쩍임은 차고가)
func celebrate(part: String) -> void:
	if rows.has(part):
		Town.pop(rows[part]["grade"], Vector2(0.0, 0.5), Feel.TUNE_POP_SCALE, Feel.TUNE_POP_DURATION)
	if part == selected:
		Town.pop(_detail_grade, Vector2(0.0, 0.5), Feel.TUNE_POP_SCALE, Feel.TUNE_POP_DURATION)


func show_result(text: String, color: Color) -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", color)
	_result.visible = true


func clear_result() -> void:
	_result.text = ""
	_result.visible = false


func result_text() -> String:
	return _result.text if _result.visible else ""


static func grade_color(g: int) -> Color:
	return Feel.TUNE_GRADE_COLORS[clampi(g, 0, Feel.TUNE_GRADE_COLORS.size() - 1)]


# ---------------- 만들기 ----------------

func _make_row(part: String) -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_list.add_child(row)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var name_label := _label(h, Feel.TUNE_ROW_SIZE, Feel.COLOR_TEXT)
	name_label.text = TuneText.part_name(part)
	var grade := _label(h, Feel.TUNE_ROW_SIZE, grade_color(0))
	var effect := _label(h, Feel.TUNE_ROW_SIZE, Feel.COLOR_TEXT)
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # 길어도 차고가 넓어지지 않게
	rows[part] = { "row": row, "name": name_label, "grade": grade, "effect": effect }
	row.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select(part)
			row.accept_event())
	row.mouse_entered.connect(func() -> void:
		_hover = part
		_style_rows())
	row.mouse_exited.connect(func() -> void:
		if _hover == part:
			_hover = ""
		_style_rows())


## 고른 줄은 금색 테두리, 마우스 올린 줄은 조금 밝게
func _style_rows() -> void:
	for part in rows:
		var st := _style_normal
		if part == selected:
			st = _style_selected
		elif part == _hover:
			st = _style_hover
		rows[part]["row"].add_theme_stylebox_override("panel", st)


## 이름·등급 칸 폭을 가장 긴 글자에 맞춤 (줄마다 효과 글자가 같은 자리에서 시작하게)
func _fit_columns() -> void:
	var name_w := 0.0
	var grade_w := 0.0
	for part in rows:
		var name_label: Label = rows[part]["name"]
		name_w = maxf(name_w, _text_width(name_label, name_label.text))
		var grade_label: Label = rows[part]["grade"]
		for gn in _grade_names:
			grade_w = maxf(grade_w, _text_width(grade_label, gn))
	var gap := float(_px(10.0))
	for part in rows:
		rows[part]["name"].custom_minimum_size.x = name_w + gap
		rows[part]["grade"].custom_minimum_size.x = grade_w + gap


func _text_width(l: Label, text: String) -> float:
	var font := l.get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


func _row_style(bg: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	return st


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 글자 색 바꾸기 (같은 색이면 안 건드림: 매 프레임 불려서 쓸데없이 다시 그리지 않게)
func _set_color(l: Label, c: Color) -> void:
	if l.get_theme_color("font_color") != c:
		l.add_theme_color_override("font_color", c)
