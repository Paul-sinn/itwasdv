## v1: 화면 두 개 (작은 화면 / 전체 화면) 오가기.
## 창 크기·위치·투명·항상 위·클릭 통과·알림 영역 아이콘은 전부 여기(와 desktop_window.gd, tray_icon.gd)서 한다.
## 화면 내용(동네, 차고)은 main.gd가 mode_changed를 받아서 창 크기에 맞게 다시 배치한다.
##
## 약속 (docs/PROTOTYPE_V1.md "나눠 맡기"). 아래 이름과 뜻은 바꾸지 않는다:
##   enum Mode { SMALL, FULL } / var mode / signal mode_changed(mode)
##   enter_full() / enter_small() / is_transparent() / rects_provider
## 더한 것 (창 담당):
##   quit_game(): 저장하고 끝내기 (알림 영역 메뉴 "끝내기")
##
## 창 세 가지:
##   투명 창 (보통 실행): 작은 화면 = 오른쪽 아래 구석 투명 창, 전체 화면 = 주 모니터 꽉 (desktop_window.gd)
##   평범한 창 (-- --windowed, 개발용): 테두리 있는 창. 크기만 SMALL_SIZE ↔ WINDOWED_FULL_SIZE
##   화면 없음 (headless 테스트): 창은 안 건드리고 mode와 신호만
## Esc → 작은 화면, 알림 영역 아이콘 → 전체 화면 (이미 전체 화면이면 앞으로 가져오기)
extends Node

const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const TrayIcon = preload("res://scripts/ui/tray_icon.gd")
const Feel = preload("res://scripts/ui/feel.gd")

enum Mode { SMALL, FULL }

## 화면이 바뀐 뒤에 보냄 (창 크기가 이미 바뀐 상태)
signal mode_changed(mode: Mode)

var mode: Mode = Mode.SMALL

## 작은 화면(투명)에서 클릭 받을 사각형 목록(창 좌표)을 돌려주는 함수. main.gd가 넣어준다.
var rects_provider: Callable:
	set(value):
		rects_provider = value
		if _desktop != null:
			_desktop.rects_provider = value
			if mode == Mode.SMALL:
				_desktop.refresh_region()

var tray: TrayIcon             ## 알림 영역 아이콘 (화면 없는 테스트에서는 null)

var _desktop: DesktopWindow   ## 투명 창일 때만 있음
var _plain := false            ## --windowed 평범한 창


func _ready() -> void:
	# 게임을 멈춰도(get_tree().paused) 창 다루기·Esc·아이콘은 계속 동작
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	if DesktopWindow.wanted():
		_desktop = DesktopWindow.new()
		_desktop.rects_provider = rects_provider
		add_child(_desktop)
	else:
		_plain = true
		DesktopWindow.make_plain_window(get_window(), Feel.SMALL_SIZE)
	if TrayIcon.supported():
		tray = TrayIcon.new()
		tray.full_pressed.connect(_on_tray_full)
		tray.small_pressed.connect(enter_small)
		tray.quit_pressed.connect(quit_game)
		add_child(tray)


## 지금 창이 투명(바탕화면 위)인가. 화면 배경을 칠할지 정할 때 쓴다.
func is_transparent() -> bool:
	return _desktop != null and mode == Mode.SMALL


func enter_full() -> void:
	if mode == Mode.FULL:
		return
	mode = Mode.FULL
	if _desktop != null:
		_desktop.apply_full()
	elif _plain:
		get_window().size = Feel.WINDOWED_FULL_SIZE
	mode_changed.emit(mode)


func enter_small() -> void:
	if mode == Mode.SMALL:
		return
	mode = Mode.SMALL
	if _desktop != null:
		_desktop.apply_small()
	elif _plain:
		get_window().size = Feel.SMALL_SIZE
	mode_changed.emit(mode)
	# 화면 내용이 작은 화면에 맞게 다시 놓인 뒤의 사각형으로 클릭 영역을 바로 만든다
	# (안 그러면 다음 갱신 전까지 한순간 창 전체가 보이고 클릭을 받음)
	if _desktop != null:
		_desktop.refresh_region()


## 저장하고 끝내기. main.gd가 WM_CLOSE_REQUEST에서 저장한다.
func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


## 알림 영역 아이콘 클릭: 전체 화면으로. 이미 전체 화면이면 앞으로 가져오기
func _on_tray_full() -> void:
	if mode == Mode.FULL and _desktop != null:
		_desktop.apply_full()   # 최소화됐거나 다른 창 뒤에 있어도 다시 꽉 채우고 앞으로
		return
	enter_full()
	if _plain:
		if get_window().mode == Window.MODE_MINIMIZED:
			get_window().mode = Window.MODE_WINDOWED
		get_window().grab_focus()


## Esc → 작은 화면
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and mode == Mode.FULL:
		enter_small()
		get_viewport().set_input_as_handled()
