## 차고 패널: 트럭을 클릭하면 띠 위쪽에 열린다.
## 보여주기만 한다. 버튼을 누르면 신호만 보내고, 실제 강화·수리는 main.gd → scripts/core 가 한다.
extends PanelContainer

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Band = preload("res://scripts/ui/band.gd")

signal enhance_pressed
signal spare_pressed

var _style: StyleBoxFlat
var _title: Label
var _broken_label: Label
var _income: Label
var _chances: Label
var _danger: Label
var _cost: Label
var _wait: Label
var _enhance_button: Button
var _spare_button: Button
var _result: Label
var _stats: Label
var _flash: ColorRect
var _busy := false   ## 강화 결과를 기다리는 중 (뜸)


func _ready() -> void:
	custom_minimum_size.x = Feel.PANEL_WIDTH
	_style = StyleBoxFlat.new()
	_style.bg_color = Feel.COLOR_PANEL_BG
	_style.set_corner_radius_all(Feel.PANEL_RADIUS)
	_style.set_content_margin_all(Feel.PANEL_PADDING)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_title = _label(box, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 글자 폭만큼만 (커질 때 기준점이 글자에 맞게)
	_broken_label = _label(box, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_broken_label.text = "엔진 고장 - 운행 정지"
	_income = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_chances = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_danger = _label(box, Feel.PANEL_DANGER_SIZE, Feel.COLOR_DANGER)
	_cost = _label(box, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
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
	Band.pop(_title, Vector2(0.0, 0.5))   # 왼쪽 끝 기준 → 패널 밖으로 안 삐져나감


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
		_set_visible([_spare_button, _wait], [_income, _chances, _danger, _cost, _enhance_button])
		_wait.visible = not s.can_buy_spare(b)
		danger = true
	elif at_max:
		_income.text = "시간당 %s원" % Fmt.money(Economy.hourly_income(b, s.star))
		_set_visible([_income], [_chances, _danger, _cost, _wait, _enhance_button, _spare_button])
	else:
		var now := Economy.hourly_income(b, s.star)
		var next := Economy.hourly_income(b, s.star + 1)
		var c := Enhance.chances(b, s.star)
		var cost := Economy.enhance_cost(b, s.star)
		var can := Enhance.block_reason(s, b) == Enhance.Block.NONE
		_income.text = "시간당 %s원 → 성공하면 %s원" % [Fmt.money(now), Fmt.money(next)]
		_chances.text = "성공 %s · 실패(유지) %s · 퍼짐 %s" % [
			Fmt.percent(c["success"]), Fmt.percent(c["fail"]), Fmt.percent(c["destroy"])]
		danger = c["destroy"] > 0.0
		_danger.text = "퍼질 확률 %s" % Fmt.percent(c["destroy"])
		_cost.text = "비용 %s원" % Fmt.money(cost)
		_wait.text = Fmt.wait_text(Economy.seconds_to_afford(cost, s.money, s.current_hourly(b)))
		_enhance_button.disabled = not can or _busy
		_set_visible([_income, _chances, _cost, _enhance_button], [_spare_button])
		_danger.visible = danger
		_wait.visible = not can

	_style.border_color = Feel.COLOR_DANGER if danger else Feel.COLOR_PANEL_BORDER
	_style.set_border_width_all(Feel.PANEL_BORDER_DANGER if danger else Feel.PANEL_BORDER)

	_stats.text = "누른 횟수 %d · 성공 %d / 실패 %d / 퍼짐 %d" % [
		s.press_count(), s.success_count, s.fail_count, s.destroy_count]


## 방금 일어난 일을 한 줄로 (6단계에서 연출을 붙일 자리)
func show_result(text: String, color: Color, font_size: int = Feel.PANEL_TEXT_SIZE) -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", color)
	_result.add_theme_font_size_override("font_size", font_size)
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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", Feel.PANEL_BUTTON_SIZE)
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
