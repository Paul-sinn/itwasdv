## 5단계: 작업표시줄 바로 위에 붙는 투명 창.
## - 테두리 없음 / 항상 위 / 배경 투명: project.godot 설정
## - 위치: 주 모니터의 작업표시줄 바로 위, 화면 가로 전체 (높이는 project.godot의 viewport_height)
## - 클릭: 보이는 것만 받고 나머지는 뒤 창으로 통과 (click_region.gd 설명 참고)
##
## 평범한 창으로 띄우려면(개발용): 실행 명령 끝에 -- --windowed
extends Node

const ClickRegion = preload("res://scripts/ui/click_region.gd")
const Feel = preload("res://scripts/ui/feel.gd")

## 클릭 받을 사각형 목록(창 좌표)을 돌려주는 함수. main.gd가 넣어준다.
var rects_provider: Callable

var _last_polygon := PackedVector2Array()
var _next_region_usec := 0
var _next_recheck_usec := 0
var _placed_for := Rect2i()


## 투명 창으로 띄울까? (화면 없는 테스트 실행이거나 --windowed면 아님)
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--windowed")


## 평범한 창으로 되돌리기 (--windowed 개발용)
static func make_plain_window(win: Window) -> void:
	win.borderless = false
	win.always_on_top = false
	win.transparent = false
	win.transparent_bg = false
	# 테두리가 생기면 그만큼 안쪽이 줄어든다 (1280x460 → 1264x421, 4.6.3 Windows에서 확인).
	# 안쪽 크기를 설정값대로 다시 맞춘다.
	win.size = Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")))


func _ready() -> void:
	place_window()


## 주 모니터 작업표시줄 바로 위에 붙이기
func place_window() -> void:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	_placed_for = usable
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var win := get_window()
	win.size = Vector2i(usable.size.x, h)
	win.position = Vector2i(usable.position.x, usable.end.y - h)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()   # 배속(F2)과 상관없는 진짜 시간
	if now >= _next_recheck_usec:
		_next_recheck_usec = now + int(Feel.WINDOW_RECHECK_SECONDS * 1e6)
		if DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()) != _placed_for:
			place_window()
	if now >= _next_region_usec and rects_provider.is_valid():
		_next_region_usec = now + int(Feel.CLICK_REGION_INTERVAL * 1e6)
		var poly := ClickRegion.build(rects_provider.call(), get_window().size.y)
		if poly != _last_polygon:
			_last_polygon = poly
			get_window().mouse_passthrough_polygon = poly
