## 차고: 전체 화면 오른쪽에 크게 보인다 (작은 화면에서는 안 보임).
## 크기는 set_ui_scale()로 정한다 (1 = v0 패널 크기).
## v2: 위쪽 [엔진 강화] / [튜닝] 두 칸 (처음엔 [엔진 강화]). [튜닝] 칸은 tune_tab.gd
## 보여주기만 한다. 버튼을 누르면 신호만 보내고, 실제 강화·튜닝·수리는 main.gd → scripts/core 가 한다.
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Tune = preload("res://scripts/core/tune.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const TuneTab = preload("res://scripts/ui/tune_tab.gd")

signal enhance_pressed
signal spare_pressed
signal tune_pressed(part: String)

enum Tab { ENGINE, TUNE }

var engine_tab_button: Button   ## 위쪽 [엔진 강화]
var tune_tab_button: Button     ## 위쪽 [튜닝]
var tune: TuneTab               ## [튜닝] 칸

var _style: StyleBoxFlat
var _tabs: HBoxContainer
var _engine_box: VBoxContainer  ## [엔진 강화] 칸
var _title: Label
var _broken_label: Label
var _income: Label
var _chances: Label
var _danger: Label
var _danger_note: Label   ## "서스펜션 덕분에 퍼짐 −10%" (작게)
var _cost: Label
var _reserve: Label   ## 퍼질 수 있는 강수: "스페어값 N원은 남겨둬야 누를 수 있음"
var _wait: Label
var _enhance_button: Button
var _spare_button: Button
var _result: Label
var _stats: Label
var _flash: ColorRect
var _box: VBoxContainer
var _tab := Tab.ENGINE
var _busy := false   ## 강화 결과를 기다리는 중 (뜸)
var _scale := 1.0    ## v0 패널의 몇 배 크기
var _result_size := Feel.PANEL_TEXT_SIZE   ## 결과 한 줄 글자 크기 (배수 곱하기 전)
var _font_sizes := {}   ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	custom_minimum_size.x = Feel.PANEL_WIDTH
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.set_corner_radius_all(Feel.PANEL_RADIUS)
	_style.set_content_margin_all(Feel.PANEL_PADDING)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	_box = box
	add_child(box)

	# 위쪽 두 칸 고르기
	_tabs = HBoxContainer.new()
	box.add_child(_tabs)
	var group := ButtonGroup.new()
	engine_tab_button = _button(_tabs, "엔진 강화", Feel.TUNE_TAB_SIZE)
	tune_tab_button = _button(_tabs, "튜닝", Feel.TUNE_TAB_SIZE)
	for t in [engine_tab_button, tune_tab_button]:
		t.toggle_mode = true
		t.button_group = group
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		t.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
	engine_tab_button.pressed.connect(func(): show_tab(Tab.ENGINE))
	tune_tab_button.pressed.connect(func(): show_tab(Tab.TUNE))

	_engine_box = VBoxContainer.new()
	box.add_child(_engine_box)
	var e := _engine_box
	_title = _label(e, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_broken_label = _label(e, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_broken_label.text = "엔진 고장 - 운행 정지"
	_income = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_danger = _label(e, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_danger_note = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_cost = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_reserve = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	_wait = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	_enhance_button = _button(e, "강화")
	_enhance_button.pressed.connect(func(): enhance_pressed.emit())
	_spare_button = _button(e, "")
	_spare_button.pressed.connect(func(): spare_pressed.emit())

	_result = _label(e, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result.visible = false
	_stats = _label(e, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	tune = TuneTab.new()
	box.add_child(tune)
	tune.tune_pressed.connect(func(part): tune_pressed.emit(part))

	# 성공 번쩍임 (패널 위에 겹쳐 놓은 하얀 판, 평소엔 투명)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	show_tab(Tab.ENGINE)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). 글자, 폭, 여백, 테두리를 같이 키운다.
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.PANEL_WIDTH * s
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	_box.add_theme_constant_override("separation", int(roundf(8.0 * s)))
	_engine_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	_tabs.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))
	_result.add_theme_font_size_override("font_size", _px(_result_size))
	tune.set_ui_scale(s)
	reset_size()


func ui_scale() -> float:
	return _scale


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


## [엔진 강화] / [튜닝] 칸 바꾸기
func show_tab(t: Tab) -> void:
	_tab = t
	_engine_box.visible = t == Tab.ENGINE
	tune.visible = t == Tab.TUNE
	engine_tab_button.set_pressed_no_signal(t == Tab.ENGINE)
	tune_tab_button.set_pressed_no_signal(t == Tab.TUNE)


func current_tab() -> Tab:
	return _tab


## 강화나 튜닝 뜸 중 (이때는 두 버튼 다 잠김)
func is_busy() -> bool:
	return _busy or tune.is_busy()


# ---------------- 강화 연출 ----------------

## 뜸 시작: 버튼 잠그고 "강화 중…"
func begin_suspense() -> void:
	_busy = true
	_enhance_button.disabled = true
	_enhance_button.text = "강화 중…"
	clear_result()


func end_suspense() -> void:
	_busy = false
	_enhance_button.text = "강화"


## 성공: 번쩍 + 제목 ★ 숫자 커졌다 돌아옴
func celebrate() -> void:
	flash(Color(1, 1, 1, Feel.FLASH_ALPHA), Feel.FLASH_DURATION)
	Town.pop(_title, Vector2(0.0, 0.5))   # 왼쪽 끝 기준 → 패널 밖으로 안 삐져나감


## 차고 전체가 color로 번쩍였다가 사라짐 (강화 성공 하양, 튜닝 등급업은 등급 색)
func flash(color: Color, seconds: float) -> void:
	_flash.color = color
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_flash, "color:a", 0.0, seconds)


## 튜닝 등급업: 등급 색으로 번쩍 + 등급 글자 커짐
func celebrate_tune(part: String, grade: int) -> void:
	var c := TuneTab.grade_color(grade)
	c.a = Feel.TUNE_FLASH_ALPHA
	flash(c, Feel.TUNE_FLASH_DURATION)
	tune.celebrate(part)


## 상태에 맞게 글자와 버튼을 고친다 (열려 있는 동안 매 프레임)
## 숫자는 전부 튜닝을 반영한 값 (state.current_hourly / enhance_cost / enhance_need / enhance_chances)
func refresh(b: Balance, s: GameState) -> void:
	var at_max := s.star >= b.max_star
	var danger := false

	_title.text = "엔진 ★%d%s" % [s.star, " (최대)" if at_max else ""]
	_broken_label.visible = s.broken

	if s.broken:
		# 고장: "엔진 고장 - 운행 정지" + 스페어 버튼만
		var price := s.spare_price(b)
		_spare_button.text = "스페어 엔진 구매 (%s원)" % Fmt.money(price)
		_spare_button.disabled = not s.can_buy_spare(b)
		_wait.text = "" if s.can_buy_spare(b) else \
				"%s원 모자람 · 고장 중에는 수익 0" % Fmt.money(price - s.money)
		_set_visible([_spare_button, _wait], [_income, _chances, _danger, _danger_note, _cost, _reserve, _enhance_button])
		_wait.visible = not s.can_buy_spare(b)
		danger = true
	elif at_max:
		_income.text = "시간당 %s원" % Fmt.money(s.current_hourly(b))
		_set_visible([_income], [_chances, _danger, _danger_note, _cost, _reserve, _wait, _enhance_button, _spare_button])
	else:
		var now := s.current_hourly(b)
		var next := s.hourly_at(b, s.star + 1)   # 성공하면 (지금 튜닝 그대로)
		var c := s.enhance_chances(b)
		var cost := s.enhance_cost(b)
		var need := s.enhance_need(b)
		var reserve := need - cost
		var can := Enhance.block_reason(s, b) == Enhance.Block.NONE
		_income.text = "시간당 %s원 → 성공하면 %s원" % [Fmt.money(now), Fmt.money(next)]
		_chances.text = "성공 %s · 실패(유지) %s · 퍼짐 %s" % [
			Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
		danger = c["destroy"] > 0.0
		_danger.text = "퍼질 확률 %s" % Fmt.percent(c["destroy"])
		# 튜닝이 깎아 준 만큼 작게 표시
		var susp := Tune.effect(b, "suspension", s.grade("suspension"))
		_danger_note.text = "서스펜션 덕분에 퍼짐 −%s (줄어든 만큼은 실패)" % Fmt.percent(susp)
		var oil := Tune.effect(b, "engine_oil", s.grade("engine_oil"))
		_cost.text = "비용 %s원%s" % [Fmt.money(cost), " (엔진오일 −%s)" % Fmt.percent(oil) if oil > 0.0 else ""]
		_reserve.text = "스페어값 %s원은 남겨둬야 누를 수 있음" % Fmt.money(reserve)
		var wait := Fmt.wait_text(Economy.seconds_to_afford(need, s.money, s.current_hourly(b)))
		_wait.text = ("강화 비용 부족 · " + wait) if reserve > 0.0 else wait
		_enhance_button.disabled = not can or is_busy()
		_set_visible([_income, _chances, _cost, _enhance_button], [_spare_button])
		_danger.visible = danger
		_danger_note.visible = danger and susp > 0.0
		_reserve.visible = reserve > 0.0
		_wait.visible = not can

	# 빨간 테두리는 [엔진 강화] 칸을 볼 때만 (튜닝하다가 놀라지 않게)
	danger = danger and _tab == Tab.ENGINE
	_style.border_color = Feel.COLOR_DANGER if danger else Feel.COLOR_PANEL_BORDER
	_style.set_border_width_all(_px(Feel.PANEL_BORDER_DANGER if danger else Feel.PANEL_BORDER))

	_stats.text = "누른 횟수 %d · 성공 %d / 실패 %d / 퍼짐 %d" % [
		s.press_count(), s.success_count, s.fail_count, s.destroy_count]

	if tune.visible:
		tune.refresh(b, s, _busy)


## 방금 일어난 일을 한 줄로. font_size는 v0 패널 기준 (배수는 여기서 곱함)
func show_result(text: String, color: Color, font_size: int = Feel.PANEL_TEXT_SIZE) -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", color)
	_result_size = font_size
	_result.add_theme_font_size_override("font_size", _px(font_size))
	_result.visible = true


func clear_result() -> void:
	_result.text = ""
	_result.visible = false


func _set_visible(shown: Array, hidden: Array) -> void:
	for c in shown:
		c.visible = true
	for c in hidden:
		c.visible = false


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, font_size: int = Feel.PANEL_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = font_size
	btn.add_theme_font_size_override("font_size", font_size)
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
