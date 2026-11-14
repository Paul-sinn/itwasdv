## 튜닝숍 [명장] 칸 (v6b). 세 번째 칸: [엔진 강화] [세팅 돌리기] [명장]
##   잠김: "엔진 +10을 달성하면 명장이 찾아와요"
##   열림: 고른 요일 ("명장 방문일: 매주 수요일"), 바꾼 요일 ("다음 주부터 금요일"), 요일 버튼 7개,
##         이번 방문 보너스 (예고를 받았거나 방문 중일 때만. 아니면 "전날 전화로 알려 줘요"), 방문 중이면 "오늘 명장이 와 있어요!"
## 버튼은 신호만 → main.gd → Master.set_day (처음 고르면 이번 주부터, 바꾸면 다음 주부터는 계산 쪽이 정함)
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")

signal day_pressed(day: int)   ## 요일 버튼 (0 = 월 … 6 = 일)

var day_buttons: Array[Button] = []

var _locked: Label
var _open_box: VBoxContainer
var _day: Label        ## "명장 방문일: 매주 수요일" / "아직 안 골랐어요"
var _next: Label       ## "다음 주부터 금요일"
var _pick_note: Label  ## 처음: "요일을 고르세요…" / 고른 뒤: "바꾸면 다음 주부터"
var _row: HBoxContainer
var _bonus: Label      ## "이번 방문 보너스: …" / "보너스는 방문 전날 전화로 알려 줘요"
var _today: Label      ## "오늘 명장이 와 있어요!"
var _scale := 1.0
var _font_sizes := {}  ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	_locked = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	_open_box = VBoxContainer.new()
	add_child(_open_box)
	_today = _label(_open_box, Feel.PANEL_TITLE_SIZE, Feel.COLOR_MASTER)
	_day = _label(_open_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_next = _label(_open_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_row = HBoxContainer.new()
	_open_box.add_child(_row)
	for d in 7:
		var b := _button(_row, "")
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		b.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
		b.pressed.connect(day_pressed.emit.bind(d))
		day_buttons.append(b)
	_pick_note = _label(_open_box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_bonus = _label(_open_box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_MASTER)
	retranslate()
	set_ui_scale(_scale)


## 한 번만 넣는 글자 (언어를 바꾸면 main.gd가 다시 부름). 바뀌는 글자는 refresh가 매 프레임
func retranslate() -> void:
	for d in day_buttons.size():
		day_buttons[d].text = Fmt.day_name(d, true)


func set_ui_scale(s: float) -> void:
	_scale = s
	if _row == null:
		return
	for box: BoxContainer in [self, _open_box, _row]:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))


## 지금 상태대로 글자·버튼 (보이는 동안 매 프레임). now = 현지 시각 (main.now_local)
func refresh(b: Balance, s: GameState, now: int) -> void:
	var open := Master.is_unlocked(s)
	_locked.visible = not open
	_open_box.visible = open
	if not open:
		_locked.text = tr("MASTER_LOCKED") % b.master_unlock_star
		return
	var day := Master.chosen_day(s)
	var next := Master.pending_day(s)
	_day.text = tr("MASTER_DAY") % Fmt.day_name(day) if day >= 0 else tr("MASTER_DAY_NONE")
	_next.visible = next >= 0
	if _next.visible:
		_next.text = tr("MASTER_NEXT_DAY") % Fmt.day_name(next)
	var shown := next if next >= 0 else day   # 눌린 모양: 앞으로 올 요일
	for d in 7:
		day_buttons[d].set_pressed_no_signal(d == shown)
	_pick_note.text = tr("MASTER_PICK_FIRST" if day < 0 else "MASTER_PICK_CHANGE")
	var visiting := Master.is_visiting(s, now)
	_today.visible = visiting
	_today.text = tr("MASTER_TODAY")
	var bonus := known_bonus(s, now)
	_bonus.text = tr("MASTER_BONUS_LINE") % Fmt.master_bonus(b.master_bonuses, bonus) if bonus != "" \
			else tr("MASTER_BONUS_HIDDEN")


## 유저가 이미 들은 보너스: 방문 중이면 그 보너스, 예고(전날 전화)를 받은 방문이면 그 주 보너스. 아니면 "" (아직 비밀)
## 예고를 보낸 주(master_notice_week)가 이번 주면 이번 주 보너스, 다음 주면(일요일에 월요일 방문 예고) 미리 굴린 다음 주 보너스
static func known_bonus(s: GameState, now: int) -> String:
	if s.active_bonus != "":
		return s.active_bonus
	var week := Master.week_index(now)
	if s.master_notice_week == week and s.master_bonus_week == week:
		return Master.week_bonus(s)
	if s.master_notice_week == week + 1:
		return s.master_next_bonus
	return ""


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = Feel.MASTER_DAY_BUTTON_SIZE
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
