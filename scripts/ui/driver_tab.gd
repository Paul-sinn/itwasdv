## 차고 [기사·물류센터] 칸 (물류센터 화면은 v6이라 v5는 여기서 산다).
##   위: 기사 레벨, 경험치 막대(driver_xp / xp_need), 받은 포인트 (만렙이면 회사 평판)
##   가운데: 다음 할 일 (끝낸 수 n/22, 이름·설명·진행·보상)
##   아래: 창고 확장·야간 배송팀 (지금 값 → 다음 값, 가격, [올리기], 모자란 금액)
## 숫자는 scripts/core 의 Driver·Quest·Depot 값을 그대로 보여 준다. 버튼은 신호만 → main.gd → Depot.upgrade
## 다음 할 일 이름·설명은 번역 파일 QUEST_<ID>, QUEST_<ID>_DESC (Fmt.quest_name / quest_desc)
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")

signal upgrade_pressed(kind: String)

const TRUCK := 0   ## "모자란 금액 · 약 N분 뒤"를 셀 때 쓰는 시간당 수입 (트럭 1대)
const KINDS := ["warehouse", "night"]
## 종류별 번역 키: 이름("창고 확장 Lv.N"), 값("꺼둔 동안 쌓이는 시간 …")
const KIND_KEYS := {
	"warehouse": { "title": "DEPOT_WAREHOUSE", "value": "DEPOT_WAREHOUSE_VALUE" },
	"night": { "title": "DEPOT_NIGHT", "value": "DEPOT_NIGHT_VALUE" },
}

var buy_buttons := {}   ## kind → [올리기] 버튼

var _level: Label
var _xp_bar: ProgressBar
var _xp: Label           ## "경험치 120 / 230" (만렙이면 회사 평판)
var _points: Label
var _quest_head: Label   ## "다음 할 일 · 끝낸 것 3/22"
var _quest_name: Label
var _quest_desc: Label
var _quest_progress: Label   ## "진행 3/20 · 보상 +2만원 · 경험치 +200"
var _titles := {}        ## kind → "창고 확장 Lv.1"
var _values := {}        ## kind → "꺼둔 동안 쌓이는 시간 4시간 → 6시간"
var _waits := {}         ## kind → "1,234원 모자람 · 약 3분 뒤 가능"
var _bar_bg: StyleBoxFlat
var _bar_fill: StyleBoxFlat
var _scale := 1.0
var _font_sizes := {}    ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	_level = _label(self, Feel.PANEL_TITLE_SIZE, Feel.COLOR_LEVEL)
	_level.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (레벨업 때 커질 기준점)
	_level.autowrap_mode = TextServer.AUTOWRAP_OFF
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_bar_bg = StyleBoxFlat.new()
	_bar_bg.bg_color = Feel.COLOR_XP_BAR_BG
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Feel.COLOR_XP_BAR
	_xp_bar.add_theme_stylebox_override("background", _bar_bg)
	_xp_bar.add_theme_stylebox_override("fill", _bar_fill)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar)
	_xp = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_points = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	_quest_head = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_quest_name = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_STAR)
	_quest_desc = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	_quest_progress = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	for kind: String in KINDS:
		_titles[kind] = _label(self, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		_titles[kind].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 산 순간 커질 기준점
		_titles[kind].autowrap_mode = TextServer.AUTOWRAP_OFF
		_values[kind] = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		var btn := _button(self, "")
		btn.pressed.connect(func(): upgrade_pressed.emit(kind))
		buy_buttons[kind] = btn
		_waits[kind] = _label(self, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). garage_panel.gd가 같이 부른다
func set_ui_scale(s: float) -> void:
	_scale = s
	if _xp_bar == null:
		return
	add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	_xp_bar.custom_minimum_size.y = Feel.XP_BAR_HEIGHT * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))


## 올린 직후: 그 줄 "Lv.N"이 커졌다 돌아옴
func show_bought(kind: String) -> void:
	Town.pop(_titles[kind], Feel.POP_PIVOT_LEFT)


## 상태에 맞게 글자와 버튼을 고친다 (보이는 동안 매 프레임)
func refresh(b: Balance, s: GameState) -> void:
	var at_max := s.driver_level >= Driver.max_level(b)
	_level.text = tr("DRIVER_LEVEL_MAX" if at_max else "DRIVER_LEVEL") % s.driver_level
	var need := Driver.xp_need(b, s.driver_level)
	_xp_bar.max_value = maxi(need, 1)
	_xp_bar.value = _xp_bar.max_value if at_max else s.driver_xp
	_xp.text = tr("DRIVER_REPUTATION") % s.reputation if at_max else tr("DRIVER_XP") % [s.driver_xp, need]
	_points.text = tr("DRIVER_POINTS") % s.ability_points

	_quest_head.text = tr("DRIVER_QUEST_HEAD") % [s.quest_index, Quest.count(b)]
	var q := Quest.current(b, s)
	if q.is_empty():
		_quest_name.text = tr("QUEST_NONE")
	else:
		var pr := Quest.progress(b, s)
		_quest_name.text = Fmt.quest_name(q["id"])
		_quest_desc.text = Fmt.quest_desc(q["id"])
		_quest_progress.text = tr("DRIVER_QUEST_PROGRESS") % [mini(pr[0], pr[1]), pr[1], Fmt.money(q["money"]), q["xp"]]
	_quest_desc.visible = not q.is_empty()
	_quest_progress.visible = not q.is_empty()

	for kind: String in KINDS:
		var lv := Depot.level(s, kind)
		var price := Depot.price(b, s, kind)
		var now := _value_text(b, kind, lv)
		var value: String
		if price > 0:
			value = tr("DEPOT_NEXT") % [now, _value_text(b, kind, lv + 1)]
		elif lv < Depot.top_level(b, kind):   # 다음 레벨은 있는데 대리점 전이라 못 삼
			value = tr("DEPOT_AGENCY") % [now, _value_text(b, kind, lv + 1)]
		else:
			value = tr("DEPOT_TOP") % now
		_titles[kind].text = tr(KIND_KEYS[kind]["title"]) % lv
		_values[kind].text = tr(KIND_KEYS[kind]["value"]) % value
		var btn: Button = buy_buttons[kind]
		btn.visible = price > 0
		btn.text = tr("DEPOT_BUY") % Fmt.money(price)
		btn.disabled = not Depot.can_upgrade(b, s, kind)
		var short := price > 0 and s.money < price
		_waits[kind].visible = short
		if short:
			var hourly := Trip.hourly_income(b, s.truck(TRUCK))
			_waits[kind].text = tr("DEPOT_SHORT") % [Fmt.money(price - s.money), Fmt.wait_text(Economy.seconds_to_afford(price, s.money, hourly))]


## 그 레벨의 값: 창고 "4시간", 야간팀 "50%"
func _value_text(b: Balance, kind: String, lv: int) -> String:
	var v := Depot.value_at(b, kind, lv)
	return tr("DEPOT_HOURS") % Fmt.num(v) if kind == "warehouse" else Fmt.percent(v)


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


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
