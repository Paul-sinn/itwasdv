## 차고 [세팅] 칸: 부품(적재함·ECU·타이어·휠)을 골라 세팅 돌리기 (v7a: 튜닝숍 트럭 탭에서 고른 트럭 = truck).
##   위: 부품 버튼 (잠긴 부품은 "엔진 +5에 열림"), 타이어·휠은 창업 전 꺼진 버튼 + 그 아래 작은 줄 "타이어·휠 · 대리점을 차리면 열려요"
##       (버튼 안에 긴 글을 넣으면 1280x720 영어에서 차고가 창 밖으로 나가서)
##   가운데: 고른 부품의 지금 상태 (등급 이름 + 줄들), 옵션 효과 (v6-bal: 적재함 → 한 바퀴 적재량 "21.6건",
##           ECU → 오버부스트 설명), 등급업 확률 · 천장 n/N, 한 줄에 나올 확률, 비용, [돌리기]
##   고르는 중(pending)이면: 지금 쓰는 것 / 새로 나온 것을 나란히 + 버튼 두 개
## 확률·비용은 scripts/core/setting.gd 값을 그대로 보여 준다. 버튼은 신호만 → main.gd → Setting.try_roll / choose
## 부품·옵션·등급 이름은 번역 파일 키 SETTING_PART_<ID>, SETTING_OPT_<ID>, SETTING_GRADE_<등급> (id는 balance.json)
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Visitor = preload("res://scripts/core/visitor.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")

signal roll_pressed(part: String)
signal choose_pressed(part: String, take_new: bool)

var truck := 0   ## 고른 트럭 번호 (garage_panel.gd 트럭 탭이 넣음. 0 = 내 트럭)

var selected := ""          ## 고른 부품 id (처음 refresh 때 첫 부품)
var part_buttons := {}      ## 부품 id → Button
var roll_button: Button
var keep_button: Button     ## 예전 것 쓰기
var take_button: Button     ## 새 것 쓰기

var _parts_row: HBoxContainer
var _lock_note: Label       ## 부품 버튼 아래 "타이어·휠 · 대리점을 차리면 열려요" (대리점 전에만)
var _grade: Label           ## "적재함 · 스트리트" (등급 색)
var _lines: VBoxContainer   ## 지금 쓰는 줄
var _effect: Label          ## 이 부품에서 나오는 옵션의 효과: "한 바퀴 적재량 21.6건" / 오버부스트 설명 (고르는 중엔 숨김)
var _up: Label              ## "등급업 확률 8% · 천장 3/20"
var _chances: Label         ## "한 줄에 나올 확률: …"
var _cost: Label
var _wait: Label            ## 못 돌리는 이유 (돈 모자람 / 고르는 중)
var _choose: HBoxContainer  ## 고르는 화면 (두 칸)
var _old_grade: Label
var _old_lines: VBoxContainer
var _new_title: Label
var _new_grade: Label
var _new_lines: VBoxContainer
var _result: Label
var _busy := false          ## 돌리기 뜸 중
var _scale := 1.0
var _font_sizes := {}       ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	_parts_row = HBoxContainer.new()
	add_child(_parts_row)
	_lock_note = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_grade = _label(self, Feel.PANEL_TITLE_SIZE, Feel.COLOR_TEXT)
	_grade.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_grade.autowrap_mode = TextServer.AUTOWRAP_OFF   # 글자 폭만큼이라 줄바꿈하면 한 글자씩 꺾임
	_lines = _box(self)
	_effect = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_up = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_cost = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_wait = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	roll_button = _button(self, tr("SETTING_ROLL"))
	roll_button.pressed.connect(func(): roll_pressed.emit(selected))

	# 고르는 화면: 왼쪽 = 지금 쓰는 것, 오른쪽 = 새로 나온 것
	_choose = HBoxContainer.new()
	add_child(_choose)
	var old_col := _box(_choose)
	var new_col := _box(_choose)
	for col in [old_col, new_col]:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_stretch_ratio = 1.0
	_label(old_col, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM).text = tr("SETTING_OLD")
	_new_title = _label(new_col, Feel.PANEL_SMALL_SIZE, Feel.COLOR_SETTING_NEW)
	_old_grade = _label(old_col, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_new_grade = _label(new_col, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_new_grade.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 등급업 때 커졌다 돌아올 기준점
	_new_grade.autowrap_mode = TextServer.AUTOWRAP_OFF
	_old_lines = _box(old_col)
	_new_lines = _box(new_col)
	keep_button = _button(old_col, tr("SETTING_KEEP"))
	take_button = _button(new_col, tr("SETTING_TAKE"))
	keep_button.pressed.connect(func(): choose_pressed.emit(selected, false))
	take_button.pressed.connect(func(): choose_pressed.emit(selected, true))
	_choose.visible = false

	_result = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	clear_result()
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). garage_panel.gd가 같이 부른다
func set_ui_scale(s: float) -> void:
	_scale = s
	if _choose == null:
		return
	add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_parts_row.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_choose.add_theme_constant_override("separation", int(roundf(Feel.SETTING_COLUMN_GAP * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))


func is_busy() -> bool:
	return _busy


## 부품 고르기 (버튼 클릭 또는 main.gd가 고르다 만 부품을 열 때)
func select(part: String) -> void:
	selected = part
	clear_result()


# ---------------- 이름 (번역 파일) ----------------

func part_name(part: String) -> String:
	return tr("SETTING_PART_" + part.to_upper())


func grade_name(grade: int) -> String:
	return tr("SETTING_GRADE_%d" % grade)


func option_name(option: String) -> String:
	return tr("SETTING_OPT_" + option.to_upper())


## 옵션 한 줄: "이동 속도 +8%". 잡옵은 이름만
func line_text(b: Balance, option: String, grade: int) -> String:
	if Setting.option_kind(b, option) == "junk":
		return option_name(option)
	return "%s +%s" % [option_name(option), Fmt.percent(Setting.option_value(b, option, grade))]


# ---------------- 연출 ----------------

func begin_suspense() -> void:
	_busy = true
	roll_button.disabled = true
	roll_button.text = tr("SETTING_ROLLING")
	clear_result()


func end_suspense() -> void:
	_busy = false
	roll_button.text = tr("SETTING_ROLL")


## 돌린 결과 한 줄. 등급업이면 등급 색 + 새 등급 글자가 커졌다 돌아옴, 천장으로 올랐으면 그것도 알림
func show_roll_result(_part: String, before: int, after: int, pity: bool) -> void:
	if after > before:
		_result.text = tr("SETTING_RESULT_PITY" if pity else "SETTING_RESULT_UP") % [grade_name(before), grade_name(after)]
		_result.add_theme_color_override("font_color", Feel.SETTING_GRADE_COLORS[after])
		Town.pop(_new_grade, Feel.POP_PIVOT_LEFT)
	else:
		_result.text = tr("SETTING_RESULT_SAME")
		_result.add_theme_color_override("font_color", Feel.COLOR_TEXT)
	_result.visible = true


func show_choice(take_new: bool) -> void:
	_result.text = tr("SETTING_TOOK_NEW" if take_new else "SETTING_KEPT_OLD")
	_result.add_theme_color_override("font_color", Feel.COLOR_DIM)
	_result.visible = true


func clear_result() -> void:
	if _result == null:
		return
	_result.text = ""
	_result.visible = false


## 결과 한 줄 (확인용)
func result_text() -> String:
	return _result.text


# ---------------- 보여 주기 ----------------

## 상태에 맞게 글자와 버튼을 고친다 (보이는 동안 매 프레임). locked = 엔진 강화 뜸 중
func refresh(b: Balance, s: GameState, locked: bool) -> void:
	var t := s.truck(truck)
	if part_buttons.is_empty():
		_build_part_buttons(b)
	if selected == "" or not Setting.unlocked(b, s, truck, selected):
		selected = Setting.part_ids(b)[0]
	var locks := PackedStringArray()   # 대리점 전이라 잠긴 부품 줄
	for id: String in part_buttons:
		var btn: Button = part_buttons[id]
		var open := Setting.unlocked(b, s, truck, id)
		if open:
			btn.text = part_name(id)
		elif Setting.unlock_stage(b, id) > Company.stage(s):   # 타이어·휠: 창업 전
			btn.text = part_name(id)
			locks.append(tr("SETTING_LOCKED_AGENCY") % part_name(id))
		else:
			btn.text = tr("SETTING_LOCKED") % [part_name(id), Setting.unlock_star(b, id)]
		btn.disabled = not open
		btn.set_pressed_no_signal(id == selected)
	_lock_note.text = "\n".join(locks)
	_lock_note.visible = not locks.is_empty()

	var p := t.part(selected)
	var grade: int = p["grade"]
	_grade.text = "%s · %s" % [part_name(selected), grade_name(grade)]
	_grade.add_theme_color_override("font_color", Feel.SETTING_GRADE_COLORS[grade])
	_show_lines(_lines, b, grade, p["lines"])
	if grade < Setting.max_grade(b):
		var up := tr("SETTING_UP_CHANCE") % Fmt.percent(Setting.up_chance(b, grade, s))
		if Visitor.today(s) == "magician":   # 마술사 날 (위 확률에 이미 곱해져 있음)
			up += " " + tr("SETTING_MAGICIAN") % Fmt.num(b.magician_up_mult)
		_up.text = up + " · " + tr("SETTING_CEILING") % [p["counters"][grade], Setting.ceiling(b, grade)]
	else:
		_up.text = tr("SETTING_MAX_GRADE")
	var parts := PackedStringArray()
	var chances := Setting.option_chances(b, selected, grade)
	for op: String in chances:
		parts.append("%s %s" % [option_name(op), Fmt.percent(chances[op])])
	_chances.text = tr("SETTING_CHANCES") % " · ".join(parts)
	# 이 부품에서 나오는 옵션의 효과 (적재량 = 지금 평균 적재량, 소수점 한 자리까지 / 오버부스트 = 걸리면 어떻게 되나)
	var notes := PackedStringArray()
	if chances.has("cargo"):
		notes.append(tr("SETTING_CARGO_NOW") % Fmt.num(Trip.cargo(b, s, truck), 1))
	if chances.has("overboost"):
		notes.append(tr("SETTING_OVERBOOST_NOTE") % Fmt.num(b.overboost_mult))
	_effect.text = "\n".join(notes)

	var cost := Setting.roll_cost(b, grade, s)
	_cost.text = tr("GARAGE_COST") % Fmt.money(cost)
	var block := Setting.block_reason(s, b, truck, selected)
	match block:
		Setting.Block.NO_MONEY:
			_wait.text = tr("SETTING_SHORT") % [Fmt.money(cost - s.money), Fmt.wait_text(Economy.seconds_to_afford(cost, s.money, Company.hourly_net(b, s)))]
		Setting.Block.PENDING:
			_wait.text = tr("SETTING_PENDING")
	_wait.visible = block == Setting.Block.NO_MONEY or block == Setting.Block.PENDING
	roll_button.disabled = block != Setting.Block.NONE or locked or _busy

	# 고르는 화면: 예전 상태가 "줄 없음"(처음)이어도 같은 모양
	var pending = p["pending"]
	_choose.visible = pending != null
	_chances.visible = pending == null   # 고르는 동안은 자리를 아낌
	_effect.visible = pending == null and _effect.text != ""
	_cost.visible = pending == null
	if pending != null:
		var new_grade: int = pending["grade"]
		_old_grade.text = grade_name(grade)
		_old_grade.add_theme_color_override("font_color", Feel.SETTING_GRADE_COLORS[grade])
		_show_lines(_old_lines, b, grade, p["lines"])
		_new_title.text = tr("SETTING_NEW") + ("  " + tr("SETTING_GRADE_UP") if new_grade > grade else "")
		_new_grade.text = grade_name(new_grade)
		_new_grade.add_theme_color_override("font_color", Feel.SETTING_GRADE_COLORS[new_grade])
		_show_lines(_new_lines, b, new_grade, pending["lines"])
		keep_button.disabled = locked or _busy
		take_button.disabled = locked or _busy


## 줄 글자들을 box에 (모자라면 글자를 더 만들고, 남으면 숨김). 줄이 없으면 "줄 없음"
func _show_lines(box: VBoxContainer, b: Balance, grade: int, lines: Array) -> void:
	var n := maxi(lines.size(), 1)
	while box.get_child_count() < n:
		_label(box, Feel.SETTING_LINE_SIZE, Feel.COLOR_TEXT)
	for i in box.get_child_count():
		var l: Label = box.get_child(i)
		l.visible = i < n
		if i >= n:
			continue
		if lines.is_empty():
			l.text = tr("SETTING_NO_LINES")
			l.add_theme_color_override("font_color", Feel.COLOR_DIM)
			continue
		var op: String = lines[i]
		l.text = line_text(b, op, grade)
		var junk := Setting.option_kind(b, op) == "junk"
		l.add_theme_color_override("font_color", Feel.COLOR_SETTING_JUNK if junk else Feel.COLOR_TEXT)


func _build_part_buttons(b: Balance) -> void:
	var group := ButtonGroup.new()
	for id: String in Setting.part_ids(b):
		var btn := _button(_parts_row, part_name(id), Feel.SETTING_TAB_SIZE)
		btn.toggle_mode = true
		btn.button_group = group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		btn.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
		btn.pressed.connect(func(): select(id))
		part_buttons[id] = btn


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


func _box(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	parent.add_child(v)
	return v


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
