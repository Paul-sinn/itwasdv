## 게임 시작점. 숫자(balance)와 상태(game_state)를 들고, 동네와 차고에 보여주고,
## 매 프레임 Trip.advance로 트럭 0을 진행시켜 배송 이벤트("+돈", 스페어 엔진)를 동네에 띄우고,
## 버튼·치트 키를 scripts/core 함수로 연결한다.
## 확률·가격·돈 계산은 하지 않는다 → scripts/core/
##
## v1 화면 두 개 (창 다루기는 screen_mode.gd):
##   작은 화면: 동네만. 보이는 곳 아무 데나 클릭 → 전체 화면. 차고는 안 열림
##   큰 화면: 왼쪽에 같은 동네를 크게 + 오른쪽에 차고 + [설정] [작게] 버튼
##     큰 화면은 전체 화면 또는 창 모드(사용자가 [설정]에서 고름). 창 모드는 창 크기가 수시로 바뀜
##     → 창 크기가 바뀔 때마다 _layout() (최소 1280x720에서도 안 깨지게)
## v3: 돈은 정수. 화면 트럭은 연출이고, 갈 곳만 계산 쪽 바퀴 진행(TruckState)에서 정한다 (_truck_target)
extends Control

const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const GaragePanel = preload("res://scripts/ui/garage_panel.gd")
const ReturnPopup = preload("res://scripts/ui/return_popup.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

const AUTOSAVE_SECONDS := 30.0        ## 30초마다 저장 (배속과 상관없이 진짜 30초)
const RETURN_POPUP_MIN_AWAY := 60.0   ## 이보다 짧게 껐다 켜면 복귀 팝업 안 띄움 (돈은 넣음)
const TRUCK := 0   ## 지금은 트럭 1대 (번호 0). 사는 화면·고르는 탭은 v7

## 저장 파일 위치. 확인 스크립트는 진짜 저장을 건드리지 않게 add_child 전에 바꾼다.
var save_path := Save.DEFAULT_PATH

var balance: Balance
var state: GameState
var town: Town
var panel: GaragePanel       ## 차고 (전체 화면에서만 보임)
var popup: ReturnPopup
var screen: ScreenMode       ## 작은 화면 / 전체 화면 오가기 (창 다루기는 전부 여기)
var small_button: Button     ## 큰 화면 [작게]
var settings_button: Button  ## 큰 화면 [설정]
var settings: SettingsPanel  ## [설정]을 누르면 가운데 뜨는 "화면: 전체 화면 / 창 모드"
var rng := RandomNumberGenerator.new()

## 켰을 때 넣은 꺼둔 동안 (Trip.apply_offline 결과 + away_seconds): { money, parcels, spares, hours, away_seconds }.
## 저장이 없었으면 빈 묶음
var offline_report := {}

## 켠 뒤로 배송 이벤트로 번 돈 · 배송 수 · 받은 스페어 수 (확인용)
var earned_total := 0
var parcels_total := 0
var spares_found := 0

# F2 배속 측정: 배속을 켠 순간부터 게임 시간과 번 돈을 잰다
var _measuring := false
var _measure_seconds := 0.0
var _measure_earned := 0
var _measure_hourly := 0.0
var _debug_label: Label
var _last_cheat := ""
var _bg: ColorRect
var _ui_scale := 1.0               ## 전체 화면 글자·간격 배수 (창 높이 900 = 1)
var _panel_spot := Vector2.ZERO    ## 차고 오른쪽 위 모서리 (흔들림 빼고)
var _panel_shake := Vector2.ZERO   ## 실패 연출: 차고 흔들림

## 강화 뜸 중 (결과 기다리는 중). 이때는 강화 버튼을 또 눌러도 무시
var enhancing := false
## 뜸(강화 결과 나오기 전 기다림) 길이 배수. 확인 스크립트가 여러 번 누를 때만 줄임 (1 = 그대로)
var suspense_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 빈 곳 클릭은 _unhandled_input에서 처리
	rng.randomize()
	balance = Balance.load_file()
	if not balance.is_ok():
		_show_fatal(balance.errors)
		return

	state = GameState.new_game()
	var load_notice := _load_save()

	# 창: 투명 창 / 평범한 창(--windowed) / 화면 없음(테스트). 작은 화면 ↔ 전체 화면
	screen = ScreenMode.new()
	add_child(screen)
	screen.mode_changed.connect(func(_mode): _layout())

	# 배경: 투명 창(바탕화면 위)이 아닐 때만 칠함
	_bg = ColorRect.new()
	_bg.color = Feel.COLOR_BG
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	town = Town.new()
	add_child(town)

	panel = GaragePanel.new()
	add_child(panel)
	panel.enhance_pressed.connect(_on_enhance_pressed)
	panel.spare_pressed.connect(_on_spare_pressed)

	small_button = Button.new()
	small_button.text = tr("SMALL_ESC")
	small_button.focus_mode = Control.FOCUS_NONE
	small_button.pressed.connect(func(): screen.enter_small())
	add_child(small_button)

	settings_button = Button.new()
	settings_button.text = tr("SETTINGS")
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func(): close_settings() if settings.visible else open_settings())
	add_child(settings_button)

	_debug_label = Town.make_label(Feel.DEBUG_FONT_SIZE, Feel.COLOR_DEBUG)
	add_child(_debug_label)

	settings = SettingsPanel.new()
	settings.visible = false
	add_child(settings)
	settings.style_picked.connect(_on_style_picked)
	settings.close_pressed.connect(close_settings)
	screen.full_style_changed.connect(func(style): settings.show_style(style))

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

	_open_return_popup(load_notice)
	_save()   # 꺼둔 동안 수익을 넣었으면 바로 저장 (다시 켰을 때 두 번 받지 않게)


func is_full() -> bool:
	return screen.mode == ScreenMode.Mode.FULL


## 창 크기·화면이 바뀌면 다시 배치 (mode_changed, size_changed)
func _layout() -> void:
	if not is_inside_tree():
		return   # 트리에서 빠진 뒤 창 크기 신호가 늦게 와도 (확인 스크립트가 main을 바꿔 끼울 때)
	var view := get_viewport_rect().size
	_bg.visible = not screen.is_transparent()
	var full := is_full()
	panel.visible = full
	small_button.visible = full
	settings_button.visible = full
	if not full:
		settings.visible = false
	_debug_label.visible = full and OS.is_debug_build()
	town.show_ground = full

	if not full:
		# 작은 화면: 동네를 창에 꽉 차게 (창 = 동네 설계 크기면 1배)
		_ui_scale = 1.0
		var z := minf(view.x / Feel.TOWN_SIZE.x, view.y / Feel.TOWN_SIZE.y)
		town.layout((view - Feel.TOWN_SIZE * z) / 2.0, z, z)
		return

	# 전체 화면: 위쪽 줄에 [작게], 왼쪽에 동네(크게), 오른쪽에 차고
	# 창 높이 900(폭 1600) 기준. 좁고 긴 창(창 모드)에서 차고가 너무 넓어지지 않게 폭도 본다
	var by_size := minf(view.y / Feel.FULL_REF_SIZE.y, view.x / Feel.FULL_REF_SIZE.x)
	_ui_scale = clampf(by_size, Feel.FULL_UI_SCALE_MIN, Feel.FULL_UI_SCALE_MAX)
	var m := Feel.FULL_MARGIN * _ui_scale
	for b in [small_button, settings_button]:
		b.add_theme_font_size_override("font_size", int(roundf(Feel.PANEL_BUTTON_SIZE * _ui_scale)))
		b.reset_size()
	small_button.position = Vector2(view.x - m - small_button.size.x, m * 0.5)
	settings_button.position = small_button.position - Vector2(settings_button.size.x + m * 0.5, 0)
	settings.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	_debug_label.add_theme_font_size_override("font_size", int(roundf(Feel.DEBUG_FONT_SIZE * _ui_scale)))

	panel.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	var top := small_button.position.y + small_button.size.y + m * 0.5
	# 동네 자리: 차고 폭은 정해진 폭(PANEL_WIDTH × 배수)으로 잡는다
	# (글자 크기를 바꾼 직후에는 차고의 실제 크기가 다음 프레임에야 바뀌어서 믿을 수 없음)
	var garage_w := Feel.PANEL_WIDTH * panel.ui_scale()
	var debug_h := _debug_label.get_combined_minimum_size().y if _debug_label.visible else 0.0
	var area := Rect2(m, top, view.x - garage_w - m * 3.0, view.y - top - m - debug_h)
	var z := maxf(0.1, minf(area.size.x / Feel.TOWN_SIZE.x, area.size.y / Feel.TOWN_SIZE.y))
	var town_pos := Vector2(area.position.x, area.get_center().y - Feel.TOWN_SIZE.y * z / 2.0)
	town.layout(town_pos, z, minf(z, Feel.FULL_TOWN_TEXT_MAX * _ui_scale))
	# 차고: 오른쪽, 위쪽을 동네 위쪽에 맞춤
	_panel_spot = Vector2(view.x - m, town_pos.y)
	_place_panel()
	_debug_label.position = Vector2(m, view.y - m * 0.5 - debug_h)


## 차고: 오른쪽에 붙여서 (내용에 따라 폭이 바뀌어도 오른쪽 끝은 그대로). 아래가 창 밖으로 나가면 올림
func _place_panel() -> void:
	panel.reset_size()
	var view := get_viewport_rect().size
	var m := Feel.FULL_MARGIN * _ui_scale
	var y := minf(_panel_spot.y, view.y - m - panel.size.y)
	panel.position = Vector2(_panel_spot.x - panel.size.x, maxf(m * 0.5, y)) + _panel_shake


func _process(delta: float) -> void:
	var t := state.truck(TRUCK)
	var house := 0
	for e in Trip.advance(state, balance, TRUCK, delta, rng):
		if e["type"] == "parcel":
			house = town.house_for(e["house"], Trip.cargo(balance, t))
			town.show_payout(house, e["pay"])
			earned_total += e["pay"]
			parcels_total += 1
			if _measuring:
				_measure_earned += e["pay"]
		else:   # "spare": 바로 앞 배송에서 나옴 → 같은 집에
			town.show_spare(house)
			spares_found += 1
	town.truck.star = t.star
	town.truck.target = _truck_target(t)
	town.set_hud(state.money, t.star)
	if panel.visible:
		panel.refresh(balance, state)
		_place_panel()
	if popup.visible:
		_place_popup()
	if settings.visible:
		settings.reset_size()
		settings.position = ((get_viewport_rect().size - settings.size) / 2.0).max(Vector2.ZERO)
	if _measuring:
		_measure_seconds += delta
	if _debug_label.visible:
		_update_debug_label()


## 화면 트럭이 갈 곳: 짐 싣는 중이거나 다 돌고 돌아가는 중이면 물류센터(-1), 아니면 다음 배송 집.
## 트럭은 거기 먼저 가서 기다리고, "+돈"은 계산 쪽 배송 이벤트가 올 때 뜬다
func _truck_target(t) -> int:
	var n := Trip.cargo(balance, t)
	if t.lap_delivered >= n or (t.lap_delivered == 0 and t.lap_clock < balance.load_seconds):
		return -1
	return town.house_for(t.lap_delivered, n)


# ---------------- 저장 · 꺼둔 동안 수익 ----------------

## 저장 파일을 읽어 상태를 되살리고 꺼둔 동안을 넣는다 (Trip.apply_offline).
## 알려줄 일(백업에서 살림 / 옛 형식 파일을 남김 / 깨져서 새로 시작)이 있으면 그 글자를 돌려준다.
func _load_save() -> String:
	var r := Save.read_file(save_path, balance)
	var broken_name := save_path.get_file() + ".broken"
	match r["status"]:
		Save.Status.OK:
			state = r["state"]
			var away := Time.get_unix_time_from_system() - float(r["saved_at"])
			offline_report = Trip.apply_offline(state, balance, away)
			offline_report["away_seconds"] = away
			if r["recovered"]:
				push_warning("저장 파일이 깨져서 백업에서 살림: " + r["error"])
				return tr("LOAD_RECOVERED") % broken_name
		Save.Status.NONE:
			if r["old_kept"] != "":
				return tr("LOAD_OLD_KEPT") % r["old_kept"].get_file()
		Save.Status.BROKEN:
			push_warning("저장 파일이 깨져서 새로 시작: " + r["error"])
			return tr("LOAD_BROKEN") % broken_name
	return ""


## 복귀 팝업: 알릴 일(notice)이 있으면 그게 큰 글자, 꺼둔 동안 요약은 아래 작은 글자로
func _open_return_popup(notice: String) -> void:
	var away_lines := _offline_lines()
	if notice != "":
		popup.open(notice, "\n".join(away_lines))
	elif not away_lines.is_empty():
		popup.open(away_lines[0], away_lines[1])


## 꺼둔 동안 요약 두 줄 [큰 글자, 작은 글자]. 저장이 없었거나 1분 안에 다시 켰으면 빈 목록
func _offline_lines() -> PackedStringArray:
	if offline_report.is_empty():
		return PackedStringArray()
	var away: float = offline_report["away_seconds"]
	if away >= 0.0 and away < RETURN_POPUP_MIN_AWAY:
		return PackedStringArray()
	if away < 0.0:
		return PackedStringArray([tr("RETURN_MAIN_ZERO"), tr("RETURN_CLOCK_BACK") % Fmt.away(away)])
	var main_text := tr("RETURN_MAIN") % [Fmt.away(away), Fmt.money(offline_report["money"])]
	var note := tr("RETURN_DETAIL") % [offline_report["parcels"], offline_report["spares"]] + "\n" \
			+ tr("RETURN_NOTE") % [Fmt.percent(balance.offline_rate), Fmt.num(balance.offline_cap_hours)]
	return PackedStringArray([main_text, note])


## 복귀 팝업: 창 가운데 (작은 화면이면 480x220 안에)
func _place_popup() -> void:
	popup.reset_size()
	var view := get_viewport_rect().size
	popup.position = ((view - popup.size) / 2.0).max(Vector2.ZERO)


func _save() -> void:
	if state == null:
		return
	var err := Save.write_file(save_path, state, int(Time.get_unix_time_from_system()))
	if err != OK:
		push_warning("저장 실패 (오류 %d): %s" % [err, save_path])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


## 지금 보이는 것들의 사각형 (창 좌표). 투명 창에서는 이것만 그려지고 클릭을 받는다.
## 전체 화면은 창 전체가 보이는 곳.
func visible_rects() -> Array:
	var view := get_viewport_rect().size
	if is_full():
		return [Rect2(Vector2.ZERO, view)]
	var pad := town.truck.speed() * Engine.time_scale * Feel.CLICK_REGION_INTERVAL * 2.0 + 4.0
	# 흔들림 연출 중이면 흔들리는 만큼 넉넉하게 (잘려 보이지 않게)
	var shake := position.length()
	var rects := town.visible_rects(pad)
	if popup.visible:
		rects.append(popup.get_rect())
	var out := []
	for r: Rect2 in rects:
		out.append(Rect2(r.position + town.position + position, r.size).grow(shake))
	return out


# ---------------- 설정 (큰 화면) ----------------

func open_settings() -> void:
	if not is_full():
		return
	settings.show_style(screen.full_style)
	settings.visible = true


func close_settings() -> void:
	settings.visible = false


## 전체 화면 / 창 모드 고름 → 창 바꾸기·저장은 screen_mode.gd. 실제로 바뀐 값을 다시 표시
func _on_style_picked(style: ScreenMode.FullStyle) -> void:
	screen.set_full_style(style)
	settings.show_style(screen.full_style)


# ---------------- 강화 · 스페어 ----------------

## 강화 버튼: 뜸 → 굴리기(enhance.gd) → 결과 연출 → 저장
## 굴리기는 뜸이 끝난 뒤에 한다 (뜸 동안 꺼도 돈이 안 빠짐)
func _on_enhance_pressed() -> void:
	if enhancing or Enhance.block_reason(state, balance, TRUCK) != Enhance.Block.NONE:
		return
	enhancing = true
	var danger := Enhance.needs_spare(balance, state.truck(TRUCK).star)
	panel.begin_suspense()
	var wait := (Feel.SUSPENSE_DANGER if danger else Feel.SUSPENSE_SAFE) * suspense_scale
	if danger:
		town.truck.shake(wait, Feel.ENGINE_SHAKE_PX)   # 트럭 자기 좌표라 동네가 커지면 같이 커짐
	await get_tree().create_timer(wait, true, false, true).timeout   # 배속과 상관없이 진짜 시간

	var t := state.truck(TRUCK)   # 뜸 동안 F3(처음부터)이면 상태가 바뀌어서 다시 읽음
	var star_before := t.star
	var result := Enhance.try_enhance(state, balance, TRUCK, rng)
	panel.end_suspense()
	var fx := panel.ui_scale()   # 흔들림 세기: 차고 크기에 맞춰
	match result:
		Enhance.Result.SUCCESS:
			panel.show_result(tr("RESULT_SUCCESS") % [star_before, t.star], Feel.COLOR_SUCCESS)
			panel.celebrate()
			town.pop_star()
			town.truck.flash(Feel.FLASH_DURATION)
			town.truck.boost(Feel.BOOST_MULT, Feel.BOOST_DURATION)
		Enhance.Result.FAIL:
			panel.show_result(tr("RESULT_FAIL"), Feel.COLOR_FAIL)
			_shake(func(o): _panel_shake = o, Feel.FAIL_SHAKE_PX * fx, Feel.FAIL_SHAKE_DURATION)
		Enhance.Result.DESTROY:
			# 스페어 엔진을 자동으로 써서 broken_drop_to로. 트럭은 계속 달림
			panel.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE,
					tr("RESULT_DESTROY_NOTE") % [t.star, state.spares])
			town.truck.smoke_burst(Feel.DESTROY_SMOKE_BURST)
			_shake(func(o): position = o, Feel.DESTROY_SHAKE_PX * fx, Feel.DESTROY_SHAKE_DURATION)
		Enhance.Result.BLOCKED:
			panel.clear_result()
	_save()   # 기획서 15.5: 강화 버튼 직후 저장
	panel.refresh(balance, state)
	enhancing = false


## 흔들기: seconds 동안 px 세기로 시작해 0으로 줄어드는 떨림을 setter에 넣는다 (진짜 시간)
func _shake(setter: Callable, px: float, seconds: float) -> void:
	var jitter := func(t: float) -> void:
		setter.call(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px * (1.0 - t))
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(jitter, 0.0, 1.0, seconds)
	tw.tween_callback(func(): setter.call(Vector2.ZERO))


## 스페어 엔진 구매 (언제든, 돈이 있으면)
func _on_spare_pressed() -> void:
	if state.buy_spare(balance):
		panel.show_result(tr("RESULT_SPARE_BOUGHT") % state.spares, Feel.COLOR_SUCCESS)
		_save()
	panel.refresh(balance, state)


# ---------------- 클릭 · 치트 키 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_on_click(mouse.position)
		return
	# 작은 화면 오른쪽 클릭 → 메뉴 (전체 화면 / 작게 / 끝내기). 누를 때 말고 뗄 때 띄운다
	# (누르자마자 띄우면 떼는 순간 마우스 밑 메뉴 항목이 눌릴 수 있음)
	if mouse != null and not mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT and not is_full():
		get_viewport().set_input_as_handled()
		screen.open_menu_at_mouse()
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
		KEY_F6: _cheat_spare()
		_: return
	get_viewport().set_input_as_handled()


## 버튼·팝업 위 클릭은 그쪽이 먼저 가져가서 여기로 오지 않는다.
## 작은 화면: 아무 데나 클릭 → 전체 화면 (투명 창에서는 보이는 곳만 클릭이 들어옴)
func _on_click(_pos: Vector2) -> void:
	if not is_full():
		screen.enter_full()
		get_viewport().set_input_as_handled()


## F1: 돈 + 지금 단계 1시간치
func _cheat_money() -> void:
	var amount := int(Trip.hourly_income(balance, state.truck(TRUCK)))
	state.money += amount
	_last_cheat = tr("CHEAT_MONEY") % Fmt.money(amount)


## F2: 시간 60배속 켜기/끄기. 켜는 순간부터 "측정"을 새로 시작한다.
func _toggle_fast_time() -> void:
	if Engine.time_scale == 1.0:
		Engine.time_scale = Feel.CHEAT_TIME_SCALE
		_measuring = true
		_measure_seconds = 0.0
		_measure_earned = 0
		_measure_hourly = Trip.hourly_income(balance, state.truck(TRUCK))
	else:
		Engine.time_scale = 1.0
		_measuring = false   # 측정 결과는 화면에 그대로 남겨 둔다


## F3: 저장 초기화 → 처음부터 (돈 0, +0, 스페어 0, 통계 0)
func _cheat_reset() -> void:
	Save.delete_file(save_path)
	state = GameState.new_game()
	earned_total = 0
	parcels_total = 0
	spares_found = 0
	panel.clear_result()
	popup.visible = false
	_save()
	_last_cheat = tr("CHEAT_RESET")


## F4: 강화 단계 +1 (최대 단계까지)
func _cheat_star_up() -> void:
	var t := state.truck(TRUCK)
	t.star = mini(t.star + 1, balance.max_star)
	_last_cheat = "F4 +%d" % t.star


## F5: 강제로 퍼지게 하기 (스페어가 있으면 1개 씀. 통계에는 안 셈)
func _cheat_break() -> void:
	Enhance.force_destroy(state, balance, TRUCK)
	town.truck.smoke_burst(Feel.DESTROY_SMOKE_BURST)
	_last_cheat = tr("CHEAT_BREAK") % [state.truck(TRUCK).star, state.spares]


## F6: 스페어 엔진 +1
func _cheat_spare() -> void:
	state.spares += 1
	_last_cheat = tr("CHEAT_SPARE") % state.spares


func _update_debug_label() -> void:
	var text := tr("DEBUG_KEYS") % [
		Fmt.num(Feel.CHEAT_TIME_SCALE), tr("DEBUG_ON") if Engine.time_scale != 1.0 else tr("DEBUG_OFF")]
	if _last_cheat != "":
		text += "   ▶ " + _last_cheat
	if _measure_seconds > 0.0:
		var expected := _measure_hourly * _measure_seconds / 3600.0
		var ratio := _measure_earned / expected * 100.0 if expected > 0.0 else 0.0
		text += "   " + tr("DEBUG_MEASURE") % [
			Fmt.duration(_measure_seconds), Fmt.money(_measure_earned), Fmt.money(int(expected)), ratio]
	_debug_label.text = text


## balance.json이 틀렸을 때: 어디가 틀렸는지 보여주고 게임을 시작하지 않는다.
func _show_fatal(errors: PackedStringArray) -> void:
	for e in errors:
		push_error(e)
	var bg := ColorRect.new()
	bg.color = Feel.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Feel.COLOR_ERROR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr("FATAL_BALANCE") + "\n" + "\n".join(errors)
	add_child(label)
	set_process(false)
