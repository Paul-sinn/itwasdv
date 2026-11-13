## 2단계 완료 기준 (창 쪽): 작은 화면 ↔ 큰 화면을 오가기.
##   큰 화면 "전체 화면" 방식으로 100번 + "창 모드" 방식으로 100번 + 큰 화면에 있는 동안 방식 바꾸기 20번.
## 매번 창 크기·위치·모드·투명·항상 위·테두리·클릭 통과가 기대대로인지, 강수·돈이 이어지는지 확인한다.
## 고른 방식이 설정 파일에 저장되고 다시 읽히는지, 창 모드 크기 기억·최소 크기도 확인한다.
## 진짜 저장·설정 파일은 안 건드린다 (따로 쓰고 끝나면 지움).
##
## 세 가지로 돌릴 수 있다:
##   화면 없이 (창은 안 건드림. mode·full_style·신호·설정 저장만):
##     <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_switch.gd
##   진짜 투명 창 (메모리·GDI, Windows 쪽 창 크기도 재려면 tests/check_switch.ps1 로):
##     powershell -ExecutionPolicy Bypass -File "<프로젝트>\tests\check_switch.ps1"
##   평범한 창 (--windowed):
##     <GODOT_CONSOLE> --path <프로젝트> -s tests/check_switch.gd -- --windowed
## 출력: 실패한 확인마다 "[실패] ...", 마지막 줄 "확인 N개 중 M개 통과"
## check_switch.ps1 용 줄: "PID n", "SAMPLE 이름 ...", "WIN 이름 hwnd 종류 x y w h"(Windows 좌표)
extends SceneTree

const Save = preload("res://scripts/core/save.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const TrayIcon = preload("res://scripts/ui/tray_icon.gd")
const Feel = preload("res://scripts/ui/feel.gd")

const TEST_SAVE := "user://test_window_switch.json"
const TEST_SETTINGS := "user://test_window_settings.cfg"
const ROUNDS := 100              ## 방식마다 몇 번 오가나
const STYLE_SWAPS := 20          ## 큰 화면에 있는 동안 방식 바꾸기 몇 번
const WARMUP_ROUNDS := 5         ## 처음 한 번만 생기는 것(글꼴 캐시 등)을 빼려고 먼저 몇 번 돌림
const SETTLE_FRAMES := 4         ## 바꾼 뒤 몇 프레임 지나서 한 번 더 확인
const WIN_EVERY := 25            ## 몇 번째마다 Windows 쪽 진짜 창 크기를 재게 하나 (check_switch.ps1)
const SAMPLE_WAIT_MS := 1200     ## SAMPLE 줄을 찍고 PowerShell이 잴 동안 기다리는 시간
const WIN_WAIT_MS := 400         ## WIN 줄을 찍고 기다리는 시간

enum Kind { HEADLESS, DESKTOP, PLAIN }

var m: Node
var screen: ScreenMode
var kind := Kind.HEADLESS
var checks := 0
var fails := 0
var signals: Array = []
var style_signals: Array = []
var start_window_size := Vector2i()
var big_expected := Rect2i()     ## 창 모드 큰 화면이 있어야 할 자리 (Godot 화면 좌표, 안쪽 크기)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		kind = Kind.HEADLESS
	elif DesktopWindow.wanted():
		kind = Kind.DESKTOP
	else:
		kind = Kind.PLAIN
	print("창 종류: ", ["화면 없음", "투명 창", "평범한 창"][kind])
	print("PID ", OS.get_process_id())
	await process_frame
	Save.delete_file(TEST_SAVE)
	ScreenMode.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	start_window_size = root.size
	root.add_child(m)
	for i in 60:
		await process_frame
	screen = m.screen
	if screen.tray != null:
		screen.tray.popup_enabled = false   # 진짜 메뉴를 띄우면 닫힐 때까지 멈춤 → 띄우려는지(menu_requested)만 본다
	screen.mode_changed.connect(func(md): signals.append(md))
	screen.full_style_changed.connect(func(st): style_signals.append(st))
	big_expected = DesktopWindow.big_window_first_rect()

	_check(screen.full_style == ScreenMode.FullStyle.FULLSCREEN, "설정 파일이 없으면 기본은 FULLSCREEN")
	_check_small("시작", true)

	# 이미 그 화면이면 아무 일 없음 (신호 안 보냄)
	signals.clear()
	screen.enter_small()
	_check(signals.is_empty(), "작은 화면에서 enter_small() → 신호가 오면 안 됨: %s" % [signals])
	screen.enter_full()
	screen.enter_full()
	_check(signals == [ScreenMode.Mode.FULL], "enter_full() 두 번 → 신호는 FULL 한 번: %s" % [signals])
	await _settle()
	screen.enter_small()
	await _settle()

	# 몸풀기: 두 방식 다 한 번씩 써 봐야 처음 한 번만 생기는 것(테두리 그림 등)이 "늘어남"으로 안 잡힌다.
	# 전체 화면으로 끝내서 끝(end)과 같은 상태에서 잰다 (그래픽 드라이버 메모리가 마지막 창 크기에 따라 달라서)
	print("--- 몸풀기 (두 방식 %d번씩)" % WARMUP_ROUNDS)
	_set_style(ScreenMode.FullStyle.WINDOWED, "몸풀기")
	for i in WARMUP_ROUNDS:
		await _round(i + 1, false)
	_set_style(ScreenMode.FullStyle.FULLSCREEN, "몸풀기")
	for i in WARMUP_ROUNDS:
		await _round(i + 1, false)
	# 창 모드 크기 바꾸기·최대화·최소화·아이콘 메뉴도 몸풀기에서 한 번 해 둔다.
	# 처음 보는 창 크기에서 글자를 그리면 그 크기의 글꼴 캐시가 한 번 생겨서(진짜 창 1회차 실측: Godot 메모리 +12MB,
	# 오브젝트 +96) 이걸 빼고 재면 새는 것처럼 보임. 뒤에서 한 번 더 하고 그때는 안 늘어나야 한다.
	await _check_window_memory()
	await _check_tray()
	if screen.full_style != ScreenMode.FullStyle.FULLSCREEN:
		_set_style(ScreenMode.FullStyle.FULLSCREEN, "몸풀기 끝")
	for i in WARMUP_ROUNDS:
		await _round(i + 1, false)
	await _sample("warm")

	print("--- 큰 화면 = 전체 화면 방식 %d번" % ROUNDS)
	for i in ROUNDS:
		await _round(i + 1, (i + 1) % WIN_EVERY == 0)
	await _sample("fullscreen_done")

	print("--- 큰 화면 = 창 모드 방식 %d번" % ROUNDS)
	_set_style(ScreenMode.FullStyle.WINDOWED, "작은 화면에서")
	for i in ROUNDS:
		await _round(i + 1, (i + 1) % WIN_EVERY == 0)
	await _sample("windowed_done")

	print("--- 큰 화면에 있는 동안 방식 바꾸기 %d번" % STYLE_SWAPS)
	for i in STYLE_SWAPS:
		await _style_swap_round(i + 1)
	print("--- 창 모드 크기 기억·최소 크기·최대화·최소화, 알림 영역 아이콘")
	await _check_window_memory()
	await _check_tray()
	await _sample("extras_done")

	print("--- 마무리 (전체 화면 %d번)" % WARMUP_ROUNDS)
	# 바로 앞 확인이 이미 전체 화면 방식으로 끝났을 수 있음 (그때 또 고르면 신호가 안 오는 게 맞음)
	if screen.full_style != ScreenMode.FullStyle.FULLSCREEN:
		_set_style(ScreenMode.FullStyle.FULLSCREEN, "마무리")
	for i in WARMUP_ROUNDS:
		await _round(i + 1, false)
	await _sample("end")
	_check_small("끝", true)
	if kind == Kind.HEADLESS:
		_check(root.size == start_window_size, "화면 없을 때 창 크기를 건드리면 안 됨: %s → %s" % [start_window_size, root.size])

	# 끝내기 (알림 영역 메뉴 "끝내기"와 같은 길): 저장하고 끝나나
	Save.delete_file(TEST_SAVE)
	if screen.tray != null:
		screen.tray.choose(TrayIcon.Item.QUIT)
	else:
		screen.quit_game()
	_check(FileAccess.file_exists(TEST_SAVE), "끝내기: 저장 파일이 안 생김 (main.gd가 WM_CLOSE_REQUEST에서 저장해야 함)")
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails])
	quit(1 if fails > 0 else 0)   # quit_game()이 부른 quit()보다 나중이라 이 종료 코드가 남음


## 한 번 오가기: 큰 화면 → 작은 화면
func _round(n: int, measure_window: bool) -> void:
	signals.clear()
	var star_before: int = m.state.star
	var money_before: float = m.state.money
	screen.enter_full()
	_check_full("%d번째 큰 화면 (바로)" % n)
	await _settle()
	_check_full("%d번째 큰 화면 (%d프레임 뒤)" % [n, SETTLE_FRAMES])
	if measure_window:
		await _win_full("big%d" % n)
	screen.enter_small()
	_check_small("%d번째 작은 화면 (바로)" % n, false)
	await _settle()
	_check_small("%d번째 작은 화면 (%d프레임 뒤)" % [n, SETTLE_FRAMES], true)
	if measure_window:
		await _win("small%d" % n, "small", DesktopWindow.small_rect())
	_check(signals == [ScreenMode.Mode.FULL, ScreenMode.Mode.SMALL], "%d번째: 신호는 FULL, SMALL 한 번씩: %s" % [n, signals])
	_check(m.state.star == star_before, "%d번째: 강수가 바뀜 %d → %d" % [n, star_before, m.state.star])
	_check(m.state.money >= money_before, "%d번째: 돈이 줄어듦 %s → %s" % [n, money_before, m.state.money])


## 큰 화면에 들어가서 방식 바꾸기 (전체 화면 ↔ 창 모드) → 바로 바뀌나 → 작은 화면으로
func _style_swap_round(n: int) -> void:
	signals.clear()
	screen.enter_full()
	await _settle()
	var other := ScreenMode.FullStyle.FULLSCREEN if screen.full_style == ScreenMode.FullStyle.WINDOWED else ScreenMode.FullStyle.WINDOWED
	_set_style(other, "%d번째 큰 화면에서" % n)
	_check(screen.mode == ScreenMode.Mode.FULL, "%d번째: 방식을 바꿨더니 큰 화면에서 나가짐" % n)
	_check_full("%d번째 방식 바꾼 뒤 (바로)" % n)
	await _settle()
	_check_full("%d번째 방식 바꾼 뒤 (%d프레임 뒤)" % [n, SETTLE_FRAMES])
	if n <= 2:
		await _win_full("swap%d" % n)
	screen.enter_small()
	await _settle()
	_check_small("%d번째 방식 바꾸고 작은 화면" % n, true)
	_check(signals == [ScreenMode.Mode.FULL, ScreenMode.Mode.SMALL], "%d번째: 방식 바꾸기는 mode_changed를 안 보냄: %s" % [n, signals])


## 방식 바꾸기 + 신호 + 설정 파일 확인
func _set_style(style: ScreenMode.FullStyle, tag: String) -> void:
	style_signals.clear()
	screen.set_full_style(style)
	_check(screen.full_style == style, tag + ": full_style이 안 바뀜")
	_check(style_signals == [style], tag + ": full_style_changed 신호가 한 번 와야 함: %s" % [style_signals])
	_check(ScreenMode.load_full_style() == style, tag + ": 설정 파일에서 다시 읽은 값이 다름")
	style_signals.clear()
	screen.set_full_style(style)
	_check(style_signals.is_empty(), tag + ": 같은 방식으로 또 바꾸면 신호가 오면 안 됨")


## 창 모드 큰 화면: 사용자가 크기·위치를 바꾸면 다음에 그대로 / 최소 크기보다 작게 안 됨 (진짜 투명 창만)
func _check_window_memory() -> void:
	if kind != Kind.DESKTOP:
		return
	if screen.full_style != ScreenMode.FullStyle.WINDOWED:
		_set_style(ScreenMode.FullStyle.WINDOWED, "크기 기억 확인 전")
	screen.enter_full()
	await _settle()
	var win := root
	win.size = Feel.BIG_WINDOW_MIN_SIZE - Vector2i(200, 100)
	await _settle()
	_check(win.size == Feel.BIG_WINDOW_MIN_SIZE, "창 모드 최소 크기: 기대 %s, 실제 %s" % [Feel.BIG_WINDOW_MIN_SIZE, win.size])
	var moved := Rect2i(big_expected.position + Vector2i(40, 30), Vector2i(1400, 800))
	win.size = moved.size
	win.position = moved.position
	await _settle()
	big_expected = Rect2i(win.position, win.size)
	_check(big_expected == moved, "창 모드 크기 바꾸기: 기대 %s, 실제 %s" % [moved, big_expected])
	screen.enter_small()
	await _settle()
	screen.enter_full()
	await _settle()
	_check_full("크기 바꾼 뒤 다시 큰 화면")
	await _win_full("remember")

	# 최대화 → 작은 화면 → 다시 큰 화면은 최대화된 채로 → 최대화를 풀면 기억한 크기
	win.mode = Window.MODE_MAXIMIZED
	await _settle()
	screen.enter_small()
	await _settle()
	_check_small("최대화에서 작은 화면", true)
	screen.enter_full()
	await _settle()
	_check(win.mode == Window.MODE_MAXIMIZED, "최대화해 두고 나갔다 오면 최대화된 채로: 창 모드 %d" % win.mode)
	win.mode = Window.MODE_WINDOWED
	await _settle()
	_check_full("최대화 풀기")

	# 최소화 → 알림 영역 아이콘 클릭 → 다시 앞으로 (최대화 아니었으면 최대화 안 됨)
	win.mode = Window.MODE_MINIMIZED
	await _settle()
	_tray_click()
	await _settle()
	_check_full("창 모드 최소화 → 아이콘 클릭")
	screen.enter_small()
	await _settle()

	# 전체 화면 최소화 → 아이콘 클릭 → 다시 꽉
	_set_style(ScreenMode.FullStyle.FULLSCREEN, "최소화 확인")
	screen.enter_full()
	await _settle()
	win.mode = Window.MODE_MINIMIZED
	await _settle()
	_tray_click()
	await _settle()
	_check_full("전체 화면 최소화 → 아이콘 클릭")
	screen.enter_small()
	await _settle()
	_check_small("최소화 확인 끝", true)


## 알림 영역 아이콘·메뉴, Esc (아이콘은 화면 있을 때만)
func _check_tray() -> void:
	signals.clear()
	screen.enter_full()
	await _settle()
	_press_esc()
	await _settle()
	_check_small("Esc", true)
	_check(signals == [ScreenMode.Mode.FULL, ScreenMode.Mode.SMALL], "Esc: 신호 %s" % [signals])
	_press_esc()
	await _settle()
	_check_small("작은 화면에서 Esc (그대로)", true)
	await _check_town_menu()
	if screen.tray == null:
		return
	signals.clear()
	_tray_click()
	await _settle()
	_check_full("아이콘 클릭")
	_tray_click()
	await _settle()
	_check_full("큰 화면에서 아이콘 또 클릭 (그대로)")
	# 오른쪽은 메뉴: 버튼을 뗄 시간(TRAY_MENU_DELAY) 뒤에 한 번만 띄우려 함. 그 밖엔 아무 일 없음
	var menu_asks := [0]
	screen.tray.menu_requested.connect(func(): menu_asks[0] += 1)
	screen.tray.indicator.pressed.emit(MOUSE_BUTTON_RIGHT, Vector2i.ZERO)
	screen.tray.indicator.pressed.emit(MOUSE_BUTTON_RIGHT, Vector2i.ZERO)   # 빨리 두 번 눌러도 메뉴는 한 번
	_check(menu_asks[0] == 0, "오른쪽 클릭: 버튼을 떼기 전(바로)에는 메뉴를 띄우면 안 됨")
	await _wait_ms(int(Feel.TRAY_MENU_DELAY * 1000.0) + 300)
	_check(menu_asks[0] == 1, "오른쪽 클릭: 메뉴를 한 번 띄우려 해야 함 (%d번)" % menu_asks[0])
	if screen.tray.indicator.get_rect().has_area():   # 아이콘이 ^ 숨김 칸에 있으면 자리를 모름 (그땐 마우스 자리)
		var mp: Vector2i = screen.tray.menu_position()
		var prim := DisplayServer.screen_get_size(DisplayServer.get_primary_screen())
		_check(Rect2i(Vector2i.ZERO, prim).has_point(mp), "메뉴 자리가 주 모니터 밖 (Windows 좌표 %s)" % mp)
	_check_full("오른쪽 클릭 (그대로)")
	_check(signals == [ScreenMode.Mode.FULL], "아이콘 클릭: 신호는 FULL 한 번: %s" % [signals])
	screen.tray.choose(TrayIcon.Item.SMALL)
	await _settle()
	_check_small("메뉴 \"작게\"", true)
	screen.tray.choose(TrayIcon.Item.FULL)
	await _settle()
	_check_full("메뉴 \"전체 화면\"")
	screen.enter_small()
	await _settle()


## 작은 동네 오른쪽 클릭 → 알림 영역과 같은 메뉴 (2026-11-12). 버튼을 뗄 때 한 번, 큰 화면에서는 안 뜸, 화면은 그대로
func _check_town_menu() -> void:
	var asks := [0]
	var on_ask := func(): asks[0] += 1
	screen.menu_asked.connect(on_ask)
	if screen.tray != null:
		_check(not screen.tray.small_enabled, "작은 화면인데 메뉴 \"작게\"가 눌리게 되어 있음")
	var spot: Vector2 = m.visible_rects()[0].get_center()
	_mouse(MOUSE_BUTTON_RIGHT, spot, true)
	_check(asks[0] == 0, "동네 오른쪽 버튼을 누르기만 했는데 메뉴를 띄우려 함")
	_mouse(MOUSE_BUTTON_RIGHT, spot, false)
	_check(asks[0] == 1, "동네 오른쪽 클릭: 메뉴를 한 번 띄우려 해야 함 (%d번)" % asks[0])
	await _settle()
	_check_small("동네 오른쪽 클릭 (그대로)", true)
	screen.enter_full()
	await _settle()
	if screen.tray != null:
		_check(screen.tray.small_enabled, "큰 화면인데 메뉴 \"작게\"가 흐림")
	_mouse(MOUSE_BUTTON_RIGHT, spot, true)
	_mouse(MOUSE_BUTTON_RIGHT, spot, false)
	_check(asks[0] == 1, "큰 화면 오른쪽 클릭: 메뉴를 띄우면 안 됨 (%d번)" % asks[0])
	screen.enter_small()
	await _settle()
	screen.menu_asked.disconnect(on_ask)


func _mouse(button: MouseButton, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	root.push_input(e)


## 아이콘 왼쪽 클릭 (Windows가 알려 주면 StatusIndicator가 보내는 신호와 같은 것)
func _tray_click() -> void:
	if screen.tray != null:
		screen.tray.indicator.pressed.emit(MOUSE_BUTTON_LEFT, Vector2i.ZERO)


func _press_esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _check_full(tag: String) -> void:
	_check(screen.mode == ScreenMode.Mode.FULL, tag + ": mode가 FULL이 아님")
	_check(not screen.is_transparent(), tag + ": 큰 화면인데 is_transparent()가 참")
	var win := root
	match kind:
		Kind.DESKTOP:
			var windowed := screen.full_style == ScreenMode.FullStyle.WINDOWED
			var r := big_expected if windowed else DesktopWindow.full_window_rect()
			if windowed:
				_check(win.mode == Window.MODE_WINDOWED, tag + ": 창 모드인데 창 모드가 MODE_WINDOWED가 아님 (%d)" % win.mode)
				_check(not win.borderless, tag + ": 창 모드인데 테두리가 없음")
				_check(not win.unresizable, tag + ": 창 모드인데 크기 조절이 막힘")
				_check(win.min_size == Feel.BIG_WINDOW_MIN_SIZE, tag + ": 최소 크기 기대 %s, 실제 %s" % [Feel.BIG_WINDOW_MIN_SIZE, win.min_size])
			else:
				# 전체 화면 = 테두리 없는 보통 창, 모니터보다 위아래 1픽셀씩 큼 (desktop_window.gd 맨 위 설명)
				_check(win.mode == Window.MODE_WINDOWED, tag + ": 전체 화면인데 창 모드가 MODE_WINDOWED가 아님 (%d)" % win.mode)
				_check(win.borderless, tag + ": 전체 화면인데 테두리가 있음")
			_check(win.size == r.size and DisplayServer.window_get_size() == r.size,
					tag + ": 창 크기 기대 %s, 실제 %s / %s" % [r.size, win.size, DisplayServer.window_get_size()])
			_check(win.position == r.position and DisplayServer.window_get_position() == r.position,
					tag + ": 창 위치 기대 %s, 실제 %s / %s" % [r.position, win.position, DisplayServer.window_get_position()])
			_check(Vector2i(m.get_viewport_rect().size) == r.size, tag + ": 화면 크기가 창과 다름 %s" % m.get_viewport_rect().size)
			_check(not win.transparent_bg, tag + ": 배경이 투명함")
			_check(not win.always_on_top, tag + ": 항상 위가 켜져 있음")
			_check(win.mouse_passthrough_polygon.is_empty(), tag + ": 클릭 통과 다각형이 남아 있음 (점 %d개)" % win.mouse_passthrough_polygon.size())
		Kind.PLAIN:
			_check(win.size == Feel.WINDOWED_FULL_SIZE, tag + ": 창 크기 기대 %s, 실제 %s" % [Feel.WINDOWED_FULL_SIZE, win.size])


## settled: 몇 프레임 지난 뒤면 클릭 통과 다각형까지 확인
func _check_small(tag: String, settled: bool) -> void:
	_check(screen.mode == ScreenMode.Mode.SMALL, tag + ": mode가 SMALL이 아님")
	_check(screen.is_transparent() == (kind == Kind.DESKTOP), tag + ": is_transparent()가 %s" % screen.is_transparent())
	var win := root
	match kind:
		Kind.DESKTOP:
			var r := DesktopWindow.small_rect()
			_check(win.mode == Window.MODE_WINDOWED, tag + ": 창 모드가 MODE_WINDOWED가 아님 (%d)" % win.mode)
			_check(win.size == r.size and DisplayServer.window_get_size() == r.size,
					tag + ": 창 크기 기대 %s, 실제 %s / %s" % [r.size, win.size, DisplayServer.window_get_size()])
			_check(win.position == r.position and DisplayServer.window_get_position() == r.position,
					tag + ": 창 위치 기대 %s, 실제 %s / %s" % [r.position, win.position, DisplayServer.window_get_position()])
			_check(Vector2i(m.get_viewport_rect().size) == r.size, tag + ": 화면 크기가 창과 다름 %s" % m.get_viewport_rect().size)
			_check(win.transparent and win.transparent_bg, tag + ": 투명이 아님 (창 %s, 배경 %s)" % [win.transparent, win.transparent_bg])
			_check(win.always_on_top, tag + ": 항상 위가 꺼져 있음")
			_check(win.borderless, tag + ": 테두리가 있음")
			if settled:
				_check(win.mouse_passthrough_polygon.size() >= 4, tag + ": 클릭 통과 다각형이 없음 (창 전체가 클릭을 받음)")
		Kind.PLAIN:
			_check(win.size == Feel.SMALL_SIZE, tag + ": 창 크기 기대 %s, 실제 %s" % [Feel.SMALL_SIZE, win.size])


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("[실패] ", what)


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


func _wait_ms(ms: int) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < ms:
		await process_frame


## check_switch.ps1이 메모리·GDI를 재는 순간
func _sample(tag: String) -> void:
	print("SAMPLE %s static_mem_mb=%.1f objects=%d nodes=%d orphans=%d" % [tag,
			OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	await _wait_ms(SAMPLE_WAIT_MS)


func _win_full(tag: String) -> void:
	if screen.full_style == ScreenMode.FullStyle.WINDOWED:
		await _win(tag, "window", big_expected)
	else:
		await _win(tag, "full", DesktopWindow.full_window_rect())


## check_switch.ps1이 Windows 쪽 진짜 창 크기를 재는 순간 (Windows 좌표: 주 모니터 왼쪽 위가 0,0)
## what: small(구석 투명 창) / full(전체 화면) / window(창 모드. 안쪽 크기)
func _win(tag: String, what: String, r: Rect2i) -> void:
	if kind != Kind.DESKTOP:
		return
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	print("WIN %s %d %s %d %d %d %d" % [tag, DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), what,
			r.position.x - off.x, r.position.y - off.y, r.size.x, r.size.y])
	await _wait_ms(WIN_WAIT_MS)
