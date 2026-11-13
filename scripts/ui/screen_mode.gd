## v1: 화면 두 개 (작은 화면 / 큰 화면) 오가기.
## 창 크기·위치·투명·항상 위·클릭 통과·알림 영역 아이콘은 전부 여기(와 desktop_window.gd, tray_icon.gd)서 한다.
## 화면 내용(동네, 차고)은 main.gd가 mode_changed를 받아서 창 크기에 맞게 다시 배치한다.
##
## 약속 (docs/PROTOTYPE_V1.md "나눠 맡기"). 아래 이름과 뜻은 바꾸지 않는다:
##   enum Mode { SMALL, FULL } / var mode / signal mode_changed(mode)
##   enter_full() / enter_small() / is_transparent() / rects_provider
##   enum FullStyle { FULLSCREEN, WINDOWED } / var full_style / signal full_style_changed(style) / set_full_style()
## 더한 것 (창 담당):
##   quit_game(): 저장하고 끝내기 (알림 영역 메뉴 "끝내기")
##   static var settings_path: 설정 파일 위치. 확인 스크립트는 main을 만들기 전에 바꾼다 (진짜 설정을 안 건드리게)
##   open_menu_at_mouse() / signal menu_asked: 작은 동네 오른쪽 클릭 → 알림 영역 아이콘과 같은 메뉴 (2026-11-12)
##
## 창 세 가지:
##   투명 창 (보통 실행): 작은 화면 = 오른쪽 아래 구석 투명 창,
##       큰 화면 = 주 모니터 꽉(FULLSCREEN) 또는 테두리 있는 보통 창(WINDOWED) (desktop_window.gd)
##   평범한 창 (-- --windowed, 개발용): 테두리 있는 창. 크기만 SMALL_SIZE ↔ WINDOWED_FULL_SIZE (full_style은 값만)
##   화면 없음 (headless 테스트): 창은 안 건드리고 mode·full_style 값과 신호만 (설정 저장은 함)
## Esc → 작은 화면, 알림 영역 아이콘 → 큰 화면 (이미 큰 화면이면 앞으로 가져오기)
extends Node

const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const TrayIcon = preload("res://scripts/ui/tray_icon.gd")
const Feel = preload("res://scripts/ui/feel.gd")

const SETTINGS_SECTION := "screen"
const SETTINGS_KEY := "full_style"
const STYLE_NAMES := ["fullscreen", "windowed"]   ## 설정 파일에 쓰는 이름 (FullStyle 순서)

enum Mode { SMALL, FULL }

## 큰 화면(Mode.FULL)을 어떻게 띄우나. 사용자가 설정에서 고른다 (저장됨).
##   FULLSCREEN: 모니터를 꽉 채우는 테두리 없는 전체 화면 (기본)
##   WINDOWED:   테두리 있는 보통 창 (크기 조절 가능)
enum FullStyle { FULLSCREEN, WINDOWED }

## 화면이 바뀐 뒤에 보냄 (창 크기가 이미 바뀐 상태)
signal mode_changed(mode: Mode)
## 큰 화면 띄우는 방식이 바뀐 뒤에 보냄 (큰 화면에 있었으면 창도 이미 바뀐 상태)
signal full_style_changed(style: FullStyle)
## open_menu_at_mouse()가 불림 (메뉴를 띄우기 전에 보냄. 화면 없는 테스트에서는 아이콘이 없어 이것만)
signal menu_asked

## 설정 파일 위치 (고른 full_style을 저장). 확인 스크립트는 main을 만들기 전에 바꾼다.
static var settings_path := "user://settings.cfg"

var mode: Mode = Mode.SMALL
var full_style: FullStyle = FullStyle.FULLSCREEN

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
	full_style = load_full_style()
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
		_sync_menu()


## 지금 창이 투명(바탕화면 위)인가. 화면 배경을 칠할지 정할 때 쓴다.
func is_transparent() -> bool:
	return _desktop != null and mode == Mode.SMALL


func enter_full() -> void:
	if mode == Mode.FULL:
		return
	mode = Mode.FULL
	if _desktop != null:
		_desktop.apply_full(full_style == FullStyle.WINDOWED)
	elif _plain:
		get_window().size = Feel.WINDOWED_FULL_SIZE
	_sync_menu()
	mode_changed.emit(mode)


func enter_small() -> void:
	if mode == Mode.SMALL:
		return
	mode = Mode.SMALL
	if _desktop != null:
		_desktop.apply_small()
	elif _plain:
		get_window().size = Feel.SMALL_SIZE
	_sync_menu()
	mode_changed.emit(mode)
	# 화면 내용이 작은 화면에 맞게 다시 놓인 뒤의 사각형으로 클릭 영역을 바로 만든다
	# (안 그러면 다음 갱신 전까지 한순간 창 전체가 보이고 클릭을 받음)
	if _desktop != null:
		_desktop.refresh_region()


## 큰 화면 띄우는 방식 바꾸기 (설정 화면에서 부름). 저장하고, 큰 화면에 있으면 바로 바꾼다.
func set_full_style(style: FullStyle) -> void:
	if style == full_style:
		return
	full_style = style
	save_full_style(style)
	if mode == Mode.FULL and _desktop != null:
		_desktop.apply_full(style == FullStyle.WINDOWED)
	full_style_changed.emit(full_style)


## 설정 파일에서 full_style 읽기. 없거나 이상하면 기본(FULLSCREEN)
static func load_full_style() -> FullStyle:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return FullStyle.FULLSCREEN
	var i := STYLE_NAMES.find(str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, "")))
	return FullStyle.WINDOWED if i == FullStyle.WINDOWED else FullStyle.FULLSCREEN


## 설정 파일에 full_style 쓰기 (파일의 다른 설정은 그대로 둠)
static func save_full_style(style: FullStyle) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)   # 없으면 빈 채로
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, STYLE_NAMES[style])
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("설정 저장 실패 (오류 %d): %s" % [err, settings_path])


## 저장하고 끝내기. main.gd가 WM_CLOSE_REQUEST에서 저장한다.
func quit_game() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()


## 작은 동네를 오른쪽 클릭했을 때 (main.gd가 버튼을 뗄 때 부름): 알림 영역 아이콘과 같은 메뉴를 마우스 자리에.
## 2026-11-12 사용자: 움직이는 트럭을 맞히기 어려움 → 아이콘을 찾지 않아도 동네에서 바로 메뉴.
## 메뉴가 닫힐 때까지 여기서 멈춘다. 아이콘이 없으면(화면 없는 테스트) menu_asked만 보냄
func open_menu_at_mouse() -> void:
	menu_asked.emit()
	if tray != null:
		tray.open_menu_at_mouse()


## 메뉴 "작게"는 큰 화면에서만 누를 수 있게
func _sync_menu() -> void:
	if tray != null:
		tray.small_enabled = mode == Mode.FULL


## 알림 영역 아이콘 클릭: 큰 화면으로. 이미 큰 화면이면 앞으로 가져오기
func _on_tray_full() -> void:
	if mode == Mode.FULL and _desktop != null:
		_desktop.bring_front(full_style == FullStyle.WINDOWED)   # 최소화됐거나 다른 창 뒤에 있어도 다시 앞으로
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
