## 2단계 완료 기준 (창 쪽): 작은 화면 ↔ 전체 화면을 100번 오가기.
## 매번 창 크기·위치·모드·투명·항상 위·클릭 통과가 기대대로인지, 강수·돈이 이어지는지 확인한다.
##
## 세 가지로 돌릴 수 있다:
##   화면 없이 (창은 안 건드림. mode·신호·is_transparent만):
##     <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_switch.gd
##   진짜 투명 창 (메모리·GDI도 재려면 tests/check_switch.ps1 로):
##     powershell -ExecutionPolicy Bypass -File "<프로젝트>\tests\check_switch.ps1"
##   평범한 창 (--windowed):
##     <GODOT_CONSOLE> --path <프로젝트> -s tests/check_switch.gd -- --windowed
## 출력: 실패한 확인마다 "[실패] ...", 마지막 줄 "확인 N개 중 M개 통과"
## check_switch.ps1 용 줄: "PID n", "SAMPLE 이름 ...", "WIN 이름 hwnd x y w h"(Windows 좌표)
extends SceneTree

const Save = preload("res://scripts/core/save.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const Feel = preload("res://scripts/ui/feel.gd")

const TEST_SAVE := "user://test_window_switch.json"
const ROUNDS := 100
const WARMUP_ROUNDS := 5         ## 처음 한 번만 생기는 것(글꼴 캐시 등)을 빼려고 먼저 몇 번 돌림
const SETTLE_FRAMES := 4         ## 바꾼 뒤 몇 프레임 지나서 한 번 더 확인
const WIN_EVERY := 25            ## 몇 번째마다 Windows 쪽 진짜 창 크기를 재게 하나 (check_switch.ps1)
const SAMPLE_WAIT_MS := 1200     ## SAMPLE/WIN 줄을 찍고 PowerShell이 잴 동안 기다리는 시간

enum Kind { HEADLESS, DESKTOP, PLAIN }

var m: Node
var screen: ScreenMode
var kind := Kind.HEADLESS
var checks := 0
var fails := 0
var signals: Array = []
var start_window_size := Vector2i()


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
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	start_window_size = root.size
	root.add_child(m)
	for i in 60:
		await process_frame
	screen = m.screen
	screen.mode_changed.connect(func(md): signals.append(md))

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

	for i in WARMUP_ROUNDS:
		await _round(i, false)
	await _sample("warm")
	for i in ROUNDS:
		await _round(i + 1, (i + 1) % WIN_EVERY == 0)
	await _sample("end")

	_check_small("끝", true)
	if kind == Kind.HEADLESS:
		_check(root.size == start_window_size, "화면 없을 때 창 크기를 건드리면 안 됨: %s → %s" % [start_window_size, root.size])
	Save.delete_file(TEST_SAVE)
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails])
	quit(1 if fails > 0 else 0)


## 한 번 오가기: 전체 화면 → 작은 화면
func _round(n: int, measure_window: bool) -> void:
	signals.clear()
	var star_before: int = m.state.star
	var money_before: float = m.state.money
	screen.enter_full()
	_check_full("%d번째 전체 화면 (바로)" % n)
	await _settle()
	_check_full("%d번째 전체 화면 (%d프레임 뒤)" % [n, SETTLE_FRAMES])
	if measure_window:
		await _win("full%d" % n, DesktopWindow.full_rect())
	screen.enter_small()
	_check_small("%d번째 작은 화면 (바로)" % n, false)
	await _settle()
	_check_small("%d번째 작은 화면 (%d프레임 뒤)" % [n, SETTLE_FRAMES], true)
	if measure_window:
		await _win("small%d" % n, DesktopWindow.small_rect())
	_check(signals == [ScreenMode.Mode.FULL, ScreenMode.Mode.SMALL], "%d번째: 신호는 FULL, SMALL 한 번씩: %s" % [n, signals])
	_check(m.state.star == star_before, "%d번째: 강수가 바뀜 %d → %d" % [n, star_before, m.state.star])
	_check(m.state.money >= money_before, "%d번째: 돈이 줄어듦 %s → %s" % [n, money_before, m.state.money])


func _check_full(tag: String) -> void:
	_check(screen.mode == ScreenMode.Mode.FULL, tag + ": mode가 FULL이 아님")
	_check(not screen.is_transparent(), tag + ": 전체 화면인데 is_transparent()가 참")
	var win := root
	match kind:
		Kind.DESKTOP:
			var r := DesktopWindow.full_rect()
			_check(win.mode == Window.MODE_FULLSCREEN, tag + ": 창 모드가 MODE_FULLSCREEN이 아님 (%d)" % win.mode)
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


## check_switch.ps1이 Windows 쪽 진짜 창 크기를 재는 순간 (Windows 좌표: 주 모니터 왼쪽 위가 0,0)
func _win(tag: String, r: Rect2i) -> void:
	if kind != Kind.DESKTOP:
		return
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	print("WIN %s %d %d %d %d %d" % [tag, DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),
			r.position.x - off.x, r.position.y - off.y, r.size.x, r.size.y])
	await _wait_ms(SAMPLE_WAIT_MS / 3)
