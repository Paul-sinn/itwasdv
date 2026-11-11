## 차고: 전체 화면 오른쪽에 크게 보인다 (작은 화면에서는 안 보임).
## 크기는 set_ui_scale()로 정한다 (1 = v0 패널 크기).
## 보여주기만 한다. 버튼을 누르면 신호만 보내고, 실제 강화·수리는 main.gd → scripts/core 가 한다.
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")

signal enhance_pressed
signal spare_pressed

var _style: StyleBoxFlat
var _title: Label
var _broken_label: Label
var _income: Label
var _chances: Label
var _danger: Label
var _cost: Label
var _reserve: Label   ## 퍼질 수 있는 강수: "스페어값 N원은 남겨둬야 누를 수 있음"
var _wait: Label
var _enhance_button: Button
var _spare_button: Button
var _result: Label
var _stats: Label
var _flash: ColorRect
var _box: VBoxContainer
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

	_title = _label(box, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_broken_label = _label(box, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_broken_label.text = "엔진 고장 - 운행 정지"
	_income = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_danger = _label(box, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_cost = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_reserve = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	_wait = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)

	_enhance_button = _button(box, "강화")
	_enhance_button.pressed.connect(func(): enhance_pressed.emit())
	_spare_button = _button(box, "")
	_spare_button.pressed.connect(func(): spare_pressed.emit())

	_result = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_result.visible = false
	_stats = _label(box, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	# 성공 번쩍임 (패널 위에 겹쳐 놓은 하얀 판, 평소엔 투명)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). 글자, 폭, 여백, 테두리를 같이 키운다.
func set_ui_scale(s: float) -> void:
	_scale = s
	if _box == null:
		return
	custom_minimum_size.x = Feel.PANEL_WIDTH * s
	_style.set_corner_radius_all(int(roundf(Feel.PANEL_RADIUS * s)))
	_style.set_content_margin_all(Feel.PANEL_PADDING * s)
	_box.add_theme_constant_override("separation", int(roundf(6.0 * s)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))
	_result.add_theme_font_size_override("font_size", _px(_result_size))
	reset_size()


func ui_scale() -> float:
	return _scale


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


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
	_flash.color = Color(1, 1, 1, Feel.FLASH_ALPHA)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_flash, "color:a", 0.0, Feel.FLASH_DURATION)
	Town.pop(_title, Vector2(0.0, 0.5))   # 왼쪽 끝 기준 → 패널 밖으로 안 삐져나감


## 상태에 맞게 글자와 버튼을 고친다 (열려 있는 동안 매 프레임)
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
		_set_visible([_spare_button, _wait], [_income, _chances, _danger, _cost, _reserve, _enhance_button])
		_wait.visible = not s.can_buy_spare(b)
		danger = true
	elif at_max:
		_income.text = "시간당 %s원" % Fmt.money(Economy.hourly_income(b, s.star))
		_set_visible([_income], [_chances, _danger, _cost, _reserve, _wait, _enhance_button, _spare_button])
	else:
		var now := Economy.hourly_income(b, s.star)
		var next := Economy.hourly_income(b, s.star + 1)
		var c := Enhance.chances(b, s.star)
		var cost := Economy.enhance_cost(b, s.star)
		var reserve := Economy.spare_reserve(b, s.star)
		var need := Economy.enhance_need(b, s.star)
		var can := Enhance.block_reason(s, b) == Enhance.Block.NONE
		_income.text = "시간당 %s원 → 성공하면 %s원" % [Fmt.money(now), Fmt.money(next)]
		_chances.text = "성공 %s · 실패(유지) %s · 퍼짐 %s" % [
			Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
		danger = c["destroy"] > 0.0
		_danger.text = "퍼질 확률 %s" % Fmt.percent(c["destroy"])
		_cost.text = "비용 %s원" % Fmt.money(cost)
		_reserve.text = "스페어값 %s원은 남겨둬야 누를 수 있음" % Fmt.money(reserve)
		var wait := Fmt.wait_text(Economy.seconds_to_afford(need, s.money, s.current_hourly(b)))
		_wait.text = ("강화 비용 부족 · " + wait) if reserve > 0.0 else wait
		_enhance_button.disabled = not can or _busy
		_set_visible([_income, _chances, _cost, _enhance_button], [_spare_button])
		_danger.visible = danger
		_reserve.visible = reserve > 0.0
		_wait.visible = not can

	_style.border_color = Feel.COLOR_DANGER if danger else Feel.COLOR_PANEL_BORDER
	_style.set_border_width_all(_px(Feel.PANEL_BORDER_DANGER if danger else Feel.PANEL_BORDER))

	_stats.text = "누른 횟수 %d · 성공 %d / 실패 %d / 퍼짐 %d" % [
		s.press_count(), s.success_count, s.fail_count, s.destroy_count]


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


func _button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = Feel.PANEL_BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", Feel.PANEL_BUTTON_SIZE)
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
