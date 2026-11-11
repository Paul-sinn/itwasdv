## 게임 시작점. 숫자(balance)와 상태(game_state)를 들고, 띠와 차고 패널에 보여주고,
## 배송마다 돈을 넣고, 버튼·치트 키를 scripts/core 함수로 연결한다.
## 확률·가격 계산은 하지 않는다 → scripts/core/
extends Control

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Band = preload("res://scripts/ui/band.gd")
const GaragePanel = preload("res://scripts/ui/garage_panel.gd")

var balance: Balance
var state: GameState
var band: Band
var panel: GaragePanel
var rng := RandomNumberGenerator.new()

## 켠 뒤로 배송으로 번 돈 합계 (확인용)
var earned_total := 0.0

# F2 배속 측정: 배속을 켠 순간부터 게임 시간과 번 돈을 잰다
var _measuring := false
var _measure_seconds := 0.0
var _measure_earned := 0.0
var _measure_hourly := 0.0
var _debug_label: Label
var _last_cheat := ""
var _panel_center_x := 0.0   ## 패널을 연 순간 트럭 가운데 x


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 빈 곳 클릭은 _unhandled_input에서 처리
	rng.randomize()
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

	panel = GaragePanel.new()
	panel.visible = false
	add_child(panel)
	panel.enhance_pressed.connect(_on_enhance_pressed)
	panel.spare_pressed.connect(_on_spare_pressed)

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
	if panel.visible:
		panel.refresh(balance, state)
		_place_panel()
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


# ---------------- 차고 패널 ----------------

func _open_panel() -> void:
	var r := band.truck.click_rect()
	_panel_center_x = band.position.x + r.get_center().x
	panel.clear_result()
	panel.visible = true
	panel.refresh(balance, state)
	_place_panel()


func _close_panel() -> void:
	panel.visible = false


## 띠 바로 위, 트럭 위쪽에. 창 밖으로 안 나가게.
func _place_panel() -> void:
	panel.reset_size()
	var view := get_viewport_rect().size
	var w := panel.size.x
	var x := clampf(_panel_center_x - w / 2.0, Feel.PANEL_EDGE, maxf(Feel.PANEL_EDGE, view.x - w - Feel.PANEL_EDGE))
	var y := band.position.y - Feel.PANEL_GAP - panel.size.y
	panel.position = Vector2(x, y)


func _on_enhance_pressed() -> void:
	var star_before := state.star
	match Enhance.try_enhance(state, balance, rng):
		Enhance.Result.SUCCESS:
			panel.show_result("성공!  ★%d → ★%d" % [star_before, state.star], Feel.COLOR_SUCCESS)
		Enhance.Result.FAIL:
			panel.show_result("실패 (★%d 그대로)" % state.star, Feel.COLOR_FAIL)
		Enhance.Result.DESTROY:
			panel.show_result("엔진 퍼짐!  ★%d → ★%d, 운행 정지" % [star_before, state.star], Feel.COLOR_DANGER)
		Enhance.Result.BLOCKED:
			pass
	panel.refresh(balance, state)


func _on_spare_pressed() -> void:
	if state.buy_spare(balance):
		panel.show_result("스페어 엔진 장착. 다시 출발!", Feel.COLOR_SUCCESS)
	panel.refresh(balance, state)


# ---------------- 클릭 · 치트 키 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_on_click(mouse.position)
		return
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1: _cheat_money()
		KEY_F2: _toggle_fast_time()
		KEY_F3: _cheat_reset()
		KEY_F4: _cheat_star_up()
		KEY_F5: _cheat_break()
		_: return
	get_viewport().set_input_as_handled()


## 패널 안 클릭은 패널(버튼)이 먼저 가져가서 여기로 오지 않는다.
## 트럭 클릭 → 열기/닫기, 그 밖의 곳 클릭 → 닫기
func _on_click(pos: Vector2) -> void:
	var truck_rect := band.truck.click_rect()
	truck_rect.position += band.position
	if truck_rect.has_point(pos):
		if panel.visible:
			_close_panel()
		else:
			_open_panel()
	elif panel.visible:
		_close_panel()
	get_viewport().set_input_as_handled()


## F1: 돈 + 1시간치. 고장 중에도 쓸 수 있게 "지금 강수의" 시간당 수익으로 준다.
func _cheat_money() -> void:
	var amount := Economy.hourly_income(balance, state.star)
	state.money += amount
	_last_cheat = "F1 돈 +%s원" % Fmt.money(amount)


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


## F3: 처음부터 (돈 0, 0강, 통계 0)
func _cheat_reset() -> void:
	state = GameState.new()
	earned_total = 0.0
	panel.clear_result()
	_last_cheat = "F3 처음부터"


## F4: 강수 +1 (최대 강수까지)
func _cheat_star_up() -> void:
	state.star = mini(state.star + 1, balance.max_star)
	_last_cheat = "F4 ★%d" % state.star


## F5: 강제로 퍼지게 하기 (통계에는 안 셈)
func _cheat_break() -> void:
	Enhance.break_engine(state, balance)
	_last_cheat = "F5 강제 퍼짐 → ★%d 고장" % state.star


func _update_debug_label() -> void:
	var text := "[디버그] F1 돈 · F2 %s배속(%s) · F3 처음부터 · F4 ★+1 · F5 퍼짐" % [
		Fmt.money(Feel.CHEAT_TIME_SCALE), "켜짐" if Engine.time_scale != 1.0 else "꺼짐"]
	if _last_cheat != "":
		text += "   ▶ " + _last_cheat
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
