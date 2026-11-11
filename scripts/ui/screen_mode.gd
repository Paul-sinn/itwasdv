## v1: 화면 두 개 (작은 화면 / 전체 화면) 오가기.
## 창 크기·위치·투명·항상 위·클릭 통과·알림 영역 아이콘은 전부 여기(와 desktop_window.gd)서 한다.
## 화면 내용(동네, 차고)은 main.gd가 mode_changed를 받아서 창 크기에 맞게 다시 배치한다.
##
## 약속 (docs/PROTOTYPE_V1.md "나눠 맡기"). 아래 이름과 뜻은 바꾸지 않는다:
##   enum Mode { SMALL, FULL } / var mode / signal mode_changed(mode)
##   enter_full() / enter_small() / is_transparent() / rects_provider
##
## 지금은 껍데기: v0 동작(투명 띠 / --windowed 평범한 창)을 그대로 두고,
## --windowed에서만 창 크기를 SMALL_SIZE ↔ WINDOWED_FULL_SIZE 로 바꾼다. 속은 창 담당이 채운다.
extends Node

const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
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

var _desktop: DesktopWindow   ## 투명 창일 때만 있음
var _plain := false            ## --windowed 평범한 창


func _ready() -> void:
	if DesktopWindow.wanted():
		_desktop = DesktopWindow.new()
		_desktop.rects_provider = rects_provider
		add_child(_desktop)
	elif DisplayServer.get_name() != "headless":
		_plain = true
		DesktopWindow.make_plain_window(get_window())
		get_window().size = Feel.SMALL_SIZE


## 지금 창이 투명(바탕화면 위)인가. 화면 배경을 칠할지 정할 때 쓴다.
func is_transparent() -> bool:
	return _desktop != null and mode == Mode.SMALL


func enter_full() -> void:
	if mode == Mode.FULL:
		return
	mode = Mode.FULL
	if _plain:
		get_window().size = Feel.WINDOWED_FULL_SIZE
	mode_changed.emit(mode)


func enter_small() -> void:
	if mode == Mode.SMALL:
		return
	mode = Mode.SMALL
	if _plain:
		get_window().size = Feel.SMALL_SIZE
	mode_changed.emit(mode)


## Esc → 작은 화면
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and mode == Mode.FULL:
		enter_small()
		get_viewport().set_input_as_handled()
