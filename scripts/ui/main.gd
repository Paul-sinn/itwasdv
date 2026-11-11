## 게임 시작점. 숫자(balance)와 상태(game_state)를 들고, 띠에 보여주고, 배송마다 돈을 넣는다.
## 확률·가격 계산은 하지 않는다 → scripts/core/
extends Control

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Band = preload("res://scripts/ui/band.gd")

var balance: Balance
var state: GameState
var band: Band

## 켠 뒤로 배송으로 번 돈 합계 (확인용)
var earned_total := 0.0

# F2 배속 측정: 배속을 켠 순간부터 게임 시간과 번 돈을 잰다
var _measuring := false
var _measure_seconds := 0.0
var _measure_earned := 0.0
var _measure_hourly := 0.0
var _debug_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	balance = Balance.load_file()
	if not balance.is_ok():
		_show_fatal(balance.errors)
		return

	state = GameState.new()
	band = Band.new()
	add_child(band)
	band.truck.delivered.connect(_on_delivered)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", Feel.DEBUG_FONT_SIZE)
	_debug_label.add_theme_color_override("font_color", Feel.COLOR_DEBUG)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.visible = OS.is_debug_build()
	band.add_child(_debug_label)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var view := get_viewport_rect().size
	band.position = Vector2(0, view.y - Feel.BAND_HEIGHT)
	band.layout(view.x)
	_debug_label.position = Vector2(Feel.DEPOT_X + Feel.DEPOT_SIZE.x + 16, Feel.GROUND_Y + 3)


func _process(delta: float) -> void:
	band.truck.star = state.star
	band.truck.running = not state.broken
	band.set_hud(state.money, state.current_hourly(balance), state.star)
	if _measuring:
		_measure_seconds += delta
	if _debug_label.visible:
		_update_debug_label()


func _on_delivered(trip_seconds: float) -> void:
	var pay := Economy.delivery_pay(balance, state.star, trip_seconds)
	state.money += pay
	earned_total += pay
	if _measuring:
		_measure_earned += pay
	band.show_payout(pay)


# ---------------- 치트 키 (디버그 실행일 때만) ----------------

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or state == null:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F2:
			_toggle_fast_time()
		_:
			return
	get_viewport().set_input_as_handled()


## F2: 시간 60배속 켜기/끄기. 켜는 순간부터 "측정"을 새로 시작한다.
func _toggle_fast_time() -> void:
	if Engine.time_scale == 1.0:
		Engine.time_scale = Feel.CHEAT_TIME_SCALE
		_measuring = true
		_measure_seconds = 0.0
		_measure_earned = 0.0
		_measure_hourly = state.current_hourly(balance)
	else:
		Engine.time_scale = 1.0
		_measuring = false   # 측정 결과는 화면에 그대로 남겨 둔다


func _update_debug_label() -> void:
	var text := "[디버그] F2 %s배속: %s" % [Fmt.money(Feel.CHEAT_TIME_SCALE), "켜짐" if Engine.time_scale != 1.0 else "꺼짐"]
	if _measure_seconds > 0.0:
		var expected := _measure_hourly * _measure_seconds / 3600.0
		var ratio := _measure_earned / expected * 100.0 if expected > 0.0 else 0.0
		text += "   측정: 게임 시간 %s · 번 돈 %s원 · 시간당 수익으로 계산한 값 %s원 (%.1f%%)" % [
			Fmt.duration(_measure_seconds), Fmt.money(_measure_earned), Fmt.money(expected), ratio]
	_debug_label.text = text


## balance.json이 틀렸을 때: 어디가 틀렸는지 보여주고 게임을 시작하지 않는다.
func _show_fatal(errors: PackedStringArray) -> void:
	for e in errors:
		push_error(e)
	var bg := ColorRect.new()
	bg.color = Feel.COLOR_BAND_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Feel.COLOR_ERROR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "게임 숫자 파일에 문제가 있어서 시작하지 않았습니다. 고친 뒤 다시 실행하세요.\n" + "\n".join(errors)
	add_child(label)
	set_process(false)
