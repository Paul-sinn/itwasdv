## 게임 시작점. 숫자(balance)와 상태(game_state)를 들고, 띠와 차고 패널에 보여주고,
## 배송마다 돈을 넣고, 버튼·치트 키를 scripts/core 함수로 연결한다.
## 확률·가격 계산은 하지 않는다 → scripts/core/
extends Control

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Save = preload("res://scripts/core/save.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Band = preload("res://scripts/ui/band.gd")
const GaragePanel = preload("res://scripts/ui/garage_panel.gd")
const ReturnPopup = preload("res://scripts/ui/return_popup.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

const AUTOSAVE_SECONDS := 30.0        ## 30초마다 저장 (배속과 상관없이 진짜 30초)
const RETURN_POPUP_MIN_AWAY := 60.0   ## 이보다 짧게 껐다 켜면 복귀 팝업 안 띄움 (돈은 넣음)

## 저장 파일 위치. 확인 스크립트는 진짜 저장을 건드리지 않게 add_child 전에 바꾼다.
var save_path := Save.DEFAULT_PATH

var balance: Balance
var state: GameState
var band: Band
var panel: GaragePanel
var popup: ReturnPopup
var screen: ScreenMode       ## 작은 화면 / 전체 화면 오가기 (창 다루기는 전부 여기)
var rng := RandomNumberGenerator.new()

## 켰을 때 계산한 꺼둔 동안 수익 (확인용): { away_seconds, earned }. 저장이 없었으면 빈 묶음
var offline_report := {}

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
var _panel_shake := Vector2.ZERO   ## 실패 연출: 패널 흔들림

## 강화 뜸 중 (결과 기다리는 중). 이때는 강화 버튼을 또 눌러도 무시
var enhancing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 빈 곳 클릭은 _unhandled_input에서 처리
	rng.randomize()
	balance = Balance.load_file()
	if not balance.is_ok():
		_show_fatal(balance.errors)
		return

	state = GameState.new()
	var load_notice := _load_save()

	# 창: 투명 창 / 평범한 창(--windowed) / 화면 없음(테스트). 작은 화면 ↔ 전체 화면
	screen = ScreenMode.new()
	add_child(screen)
	screen.mode_changed.connect(func(_mode): _layout())

	band = Band.new()
	band.show_background = not screen.is_transparent()
	add_child(band)
	band.truck.delivered.connect(_on_delivered)

	_debug_label = Band.make_label(Feel.DEBUG_FONT_SIZE, Feel.COLOR_DEBUG)
	_debug_label.visible = OS.is_debug_build()
	band.add_child(_debug_label)

	panel = GaragePanel.new()
	panel.visible = false
	add_child(panel)
	panel.enhance_pressed.connect(_on_enhance_pressed)
	panel.spare_pressed.connect(_on_spare_pressed)

	popup = ReturnPopup.new()
	popup.visible = false
	add_child(popup)

	var autosave := Timer.new()
	autosave.name = "Autosave"
	autosave.wait_time = AUTOSAVE_SECONDS
	autosave.ignore_time_scale = true
	autosave.autostart = true
	autosave.timeout.connect(_save)
	add_child(autosave)

	get_viewport().size_changed.connect(_layout)
	_layout()
	screen.rects_provider = visible_rects

	if load_notice != "":
		popup.open(load_notice, "")
	elif not offline_report.is_empty():
		_open_return_popup()
	_save()   # 꺼둔 동안 수익을 넣었으면 바로 저장 (다시 켰을 때 두 번 받지 않게)


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
	if popup.visible:
		_place_popup()
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


# ---------------- 저장 · 꺼둔 동안 수익 ----------------

## 저장 파일을 읽어 상태를 되살리고 꺼둔 동안 수익을 넣는다.
## 저장이 깨졌으면 새로 시작하고, 알려줄 글자를 돌려준다.
func _load_save() -> String:
	var r := Save.read_file(save_path, balance)
	match r["status"]:
		Save.Status.OK:
			state = r["state"]
			var away := Time.get_unix_time_from_system() - float(r["saved_at"])
			var earned := Economy.offline_earnings(balance, state.star, state.broken, away)
			state.money += earned
			offline_report = { "away_seconds": away, "earned": earned }
		Save.Status.BROKEN:
			push_warning("저장 파일이 깨져서 새로 시작: " + r["error"])
			return "저장 파일이 깨져서 새로 시작합니다.\n(깨진 파일은 %s 로 남겨 둠)" % (save_path.get_file() + ".broken")
	return ""


func _open_return_popup() -> void:
	var away: float = offline_report["away_seconds"]
	var earned: float = offline_report["earned"]
	if away >= 0.0 and away < RETURN_POPUP_MIN_AWAY:
		return
	var note := "꺼둔 동안은 %s만, 최대 %s시간치까지 쌓입니다." % [
		Fmt.percent(balance.offline_rate), Fmt.num(balance.offline_cap_hours)]
	if away < 0.0:
		note = "컴퓨터 시계가 저장했을 때보다 %s 이전이라 0원입니다." % Fmt.away(away)
	elif state.broken:
		note = "엔진 고장 중이라 꺼둔 동안 번 돈이 없습니다."
	var main_text := "자리 비운 %s 동안 +%s원" % [Fmt.away(maxf(away, 0.0)), Fmt.money(earned)]
	if away < 0.0:
		main_text = "자리 비운 동안 +0원"
	popup.open(main_text, note)


func _place_popup() -> void:
	popup.reset_size()
	var view := get_viewport_rect().size
	popup.position = Vector2((view.x - popup.size.x) / 2.0, band.position.y - Feel.PANEL_GAP - popup.size.y)


func _save() -> void:
	if state == null:
		return
	var err := Save.write_file(save_path, state, int(Time.get_unix_time_from_system()))
	if err != OK:
		push_warning("저장 실패 (오류 %d): %s" % [err, save_path])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and panel != null:
		# 투명 창에서는 바깥 클릭이 다른 프로그램으로 가므로, 다른 프로그램을 누른 순간 패널을 닫는다
		_close_panel()


## 지금 보이는 것들의 사각형 (창 좌표). 투명 창에서는 이것만 그려지고 클릭을 받는다.
func visible_rects() -> Array:
	var pad := band.truck.speed() * Engine.time_scale * Feel.CLICK_REGION_INTERVAL * 2.0 + 4.0
	# 흔들림 연출 중이면 흔들리는 만큼 넉넉하게 (잘려 보이지 않게)
	var shake := position.length() + _panel_shake.length()
	var rects := []
	for r: Rect2 in band.visible_rects(pad):
		rects.append(Rect2(r.position + band.position, r.size))
	if _debug_label.visible:
		rects.append(Rect2(band.position + _debug_label.position, _debug_label.get_combined_minimum_size()).grow(Feel.TEXT_OUTLINE_SIZE))
	if panel.visible:
		rects.append(panel.get_rect())
	if popup.visible:
		rects.append(popup.get_rect())
	var out := []
	for r: Rect2 in rects:
		out.append(Rect2(r.position + position, r.size).grow(shake))
	return out


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
	panel.position = Vector2(x, y) + _panel_shake


## 강화 버튼: 뜸 → 굴리기(enhance.gd) → 결과 연출
## 굴리기는 뜸이 끝난 뒤에 한다 (뜸 동안 꺼도 돈이 안 빠짐)
func _on_enhance_pressed() -> void:
	if enhancing or Enhance.block_reason(state, balance) != Enhance.Block.NONE:
		return
	enhancing = true
	var danger: bool = Enhance.chances(balance, state.star)["destroy"] > 0.0
	panel.begin_suspense()
	var wait := Feel.SUSPENSE_DANGER if danger else Feel.SUSPENSE_SAFE
	if danger:
		band.truck.shake(wait, Feel.ENGINE_SHAKE_PX)
	await get_tree().create_timer(wait, true, false, true).timeout   # 배속과 상관없이 진짜 시간

	var star_before := state.star
	var result := Enhance.try_enhance(state, balance, rng)
	panel.end_suspense()
	match result:
		Enhance.Result.SUCCESS:
			panel.show_result("성공!  ★%d → ★%d" % [star_before, state.star], Feel.COLOR_SUCCESS)
			panel.celebrate()
			band.pop_star()
			band.truck.flash(Feel.FLASH_DURATION)
			band.truck.boost(Feel.BOOST_MULT, Feel.BOOST_DURATION)
		Enhance.Result.FAIL:
			panel.show_result("실패", Feel.COLOR_FAIL)
			_shake(func(o): _panel_shake = o, Feel.FAIL_SHAKE_PX, Feel.FAIL_SHAKE_DURATION)
		Enhance.Result.DESTROY:
			panel.show_result("엔진 퍼짐!", Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE)
			band.truck.running = false
			band.truck.smoke_burst(Feel.DESTROY_SMOKE_BURST)
			_shake(func(o): position = o, Feel.DESTROY_SHAKE_PX, Feel.DESTROY_SHAKE_DURATION)
	panel.refresh(balance, state)
	enhancing = false


## 흔들기: seconds 동안 px 세기로 시작해 0으로 줄어드는 떨림을 setter에 넣는다 (진짜 시간)
func _shake(setter: Callable, px: float, seconds: float) -> void:
	var jitter := func(t: float) -> void:
		setter.call(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px * (1.0 - t))
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(jitter, 0.0, 1.0, seconds)
	tw.tween_callback(func(): setter.call(Vector2.ZERO))


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


## F3: 저장 초기화 → 처음부터 (돈 0, 0강, 통계 0)
func _cheat_reset() -> void:
	Save.delete_file(save_path)
	state = GameState.new()
	earned_total = 0.0
	panel.clear_result()
	popup.visible = false
	_save()
	_last_cheat = "F3 저장 초기화"


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
