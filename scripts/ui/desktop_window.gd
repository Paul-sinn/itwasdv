## 바탕화면 위 진짜 창 다루기 (v1: 작은 화면 / 전체 화면). screen_mode.gd가 부른다.
##
## 작은 화면: 주 모니터 쓸 수 있는 영역(작업표시줄 뺀 곳)의 오른쪽 아래 구석, 크기 Feel.SMALL_SIZE.
##   테두리 없음 / 항상 위 / 배경 투명 / 보이는 것만 클릭 받음 (click_region.gd 설명 참고).
##   작업표시줄 위치·해상도가 바뀌면 다시 붙인다.
## 큰 화면 (어떻게 띄울지는 사용자가 고름. screen_mode.gd의 FullStyle):
##   전체 화면: 주 모니터를 꽉 채움 (Godot의 MODE_FULLSCREEN). 테두리 없음
##   창 모드: 테두리 있는 보통 창. 크기 조절 가능. 처음엔 주 모니터 가운데 Feel.BIG_WINDOW_SIZE,
##            최소 Feel.BIG_WINDOW_MIN_SIZE. 게임을 켜 둔 동안은 마지막 크기·위치(최대화 여부)를 기억
##   둘 다: 배경 칠함 / 클릭 통과 없음 / 항상 위 아님 / 앞으로 가져오기
##
## Godot 4.6.3 + Windows에서 직접 확인한 것 (v1 0단계):
##   - 창 크기를 모니터 크기와 똑같이 직접 맞추면 Godot이 "독점 전체 화면"(MODE_EXCLUSIVE_FULLSCREEN)으로
##     바꿔버리고, 그 뒤로는 크기를 바꿔도 작아지지 않는다 → 직접 맞추지 말고 MODE_FULLSCREEN을 쓴다.
##     (MODE_FULLSCREEN은 창을 모니터보다 2픽셀 크게 만들고 넘친 곳을 잘라서 이 문제를 피한다)
##   - 창의 투명 설정(transparent)은 켜 둔 채로 두고, 배경 투명(transparent_bg)만 껐다 켜도 깨지지 않는다.
##   - 클릭 통과 다각형을 빈 배열로 주면 창 전체가 클릭을 받는다.
##
## 평범한 창으로 띄우려면(개발용): 실행 명령 끝에 -- --windowed
extends Node

const ClickRegion = preload("res://scripts/ui/click_region.gd")
const Feel = preload("res://scripts/ui/feel.gd")

## 클릭 받을 사각형 목록(창 좌표)을 돌려주는 함수. main.gd가 넣어준다.
var rects_provider: Callable

var _full := false
var _big_window := false               ## 큰 화면을 창 모드로 띄운 중
var _big_rect := Rect2i()              ## 창 모드 큰 화면의 마지막 자리 (없으면 크기 0)
var _big_maximized := false            ## 창 모드 큰 화면을 최대화해 둔 채 나갔나
var _last_polygon := PackedVector2Array()
var _next_region_usec := 0
var _next_recheck_usec := 0
var _placed_for := Rect2i()


## 투명 창으로 띄울까? (화면 없는 테스트 실행이거나 --windowed면 아님)
static func wanted() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--windowed")


## 평범한 창으로 되돌리기 (--windowed 개발용). 안쪽 크기를 size로.
static func make_plain_window(win: Window, size: Vector2i) -> void:
	win.borderless = false
	win.always_on_top = false
	win.transparent = false
	win.transparent_bg = false
	# 테두리가 생기면 그만큼 안쪽이 줄어든다 (1280x460 → 1264x421, 4.6.3 Windows에서 확인).
	# 안쪽 크기를 다시 맞춘다.
	win.size = size


## 작은 화면이 놓일 자리 (Godot 화면 좌표): 주 모니터 쓸 수 있는 영역의 오른쪽 아래 구석
static func small_rect() -> Rect2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	return Rect2i(usable.end - Feel.SMALL_SIZE, Feel.SMALL_SIZE)


## 전체 화면이 덮을 곳 (Godot 화면 좌표): 주 모니터 전체
static func full_rect() -> Rect2i:
	var s := DisplayServer.get_primary_screen()
	return Rect2i(DisplayServer.screen_get_position(s), DisplayServer.screen_get_size(s))


func _ready() -> void:
	apply_small()


## 작은 화면으로: 투명, 항상 위, 구석에 붙이기. 클릭 영역은 refresh_region()에서.
func apply_small() -> void:
	_remember_big_window()
	_full = false
	_big_window = false
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
	win.borderless = true          # 크기를 맞추기 전에 (테두리가 있으면 안쪽 크기가 달라짐)
	win.min_size = Vector2i.ZERO   # 창 모드 큰 화면의 최소 크기가 남아 있으면 작아지지 않음
	win.always_on_top = true
	win.transparent_bg = true
	place_window()


## 큰 화면으로. windowed: 창 모드(테두리 있는 보통 창), 아니면 주 모니터 꽉 채우는 전체 화면.
## 배경 칠함, 창 전체가 클릭 받음, 앞으로 가져오기. 이미 큰 화면이어도 불러도 된다 (방식 바꾸기).
func apply_full(windowed: bool) -> void:
	var win := get_window()
	if windowed and win.mode == Window.MODE_FULLSCREEN:
		# 전체 화면에서 바로 테두리 있는 창으로 바꾸면 안쪽 높이가 4픽셀씩 모자라게 되고,
		# 그 뒤 작은 화면도 480x216이 된다 (4.6.3 Windows에서 확인).
		# 작은 화면 상태를 한 번 거쳐 가면 괜찮다 (같은 프레임 안이라 작은 화면이 보이지는 않음).
		apply_small()
	_remember_big_window()
	_full = true
	_big_window = windowed
	win.mouse_passthrough_polygon = PackedVector2Array()   # 빈 배열 = 창 전체가 클릭 받음
	_last_polygon = PackedVector2Array()
	win.transparent_bg = false
	# 항상 위는 끈다: 켜 두면 Alt+Tab으로 다른 창을 골라도 그 창이 이 화면 뒤로 숨는다
	win.always_on_top = false
	if windowed:
		if win.mode != Window.MODE_WINDOWED:
			win.mode = Window.MODE_WINDOWED
		win.borderless = false
		win.unresizable = false
		win.min_size = Feel.BIG_WINDOW_MIN_SIZE
		var r := _big_rect if _big_rect.has_area() and _on_some_screen(_big_rect) else big_window_first_rect()
		win.size = r.size
		win.position = r.position
		if _big_maximized:
			win.mode = Window.MODE_MAXIMIZED
	else:
		win.min_size = Vector2i.ZERO
		win.borderless = true
		win.current_screen = DisplayServer.get_primary_screen()
		win.mode = Window.MODE_FULLSCREEN
	win.grab_focus()


## 큰 화면인데 최소화됐거나 다른 창 뒤에 있을 때 (알림 영역 아이콘): 다시 앞으로
func bring_front(windowed: bool) -> void:
	var win := get_window()
	if windowed:
		if win.mode == Window.MODE_MINIMIZED:
			win.mode = Window.MODE_MAXIMIZED if _big_maximized else Window.MODE_WINDOWED
		win.grab_focus()
	else:
		apply_full(false)


## 창 모드 큰 화면이 처음 놓일 자리 (Godot 화면 좌표): 주 모니터 쓸 수 있는 영역 가운데
static func big_window_first_rect() -> Rect2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var size := Feel.BIG_WINDOW_SIZE.min(usable.size)
	return Rect2i(usable.position + (usable.size - size) / 2, size)


## 창 모드 큰 화면에서 나갈 때 지금 크기·위치를 기억 (다음에 그대로 띄우게)
func _remember_big_window() -> void:
	if not (_full and _big_window):
		return
	var win := get_window()
	_big_maximized = win.mode == Window.MODE_MAXIMIZED
	if win.mode == Window.MODE_WINDOWED:
		_big_rect = Rect2i(win.position, win.size)


## 기억한 자리가 아직 어느 화면 위에 있나 (모니터를 뺐으면 처음 자리로)
static func _on_some_screen(r: Rect2i) -> bool:
	for s in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(s).has_point(r.get_center()):
			return true
	return false


## 주 모니터 작업표시줄 바로 위, 오른쪽 구석에 붙이기 (작은 화면일 때만)
func place_window() -> void:
	_placed_for = DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
	var r := small_rect()
	var win := get_window()
	win.size = r.size
	win.position = r.position


## 클릭 받는 영역(=보이는 영역)을 지금 바로 다시 만든다 (작은 화면일 때만)
func refresh_region() -> void:
	_next_region_usec = 0
	_update_region(Time.get_ticks_usec())


func _process(_delta: float) -> void:
	if _full:
		# 창 모드 큰 화면: 최대화해 뒀나 기억 (최소화했다가 알림 영역 아이콘으로 되살릴 때 그대로)
		var md := get_window().mode
		if _big_window and (md == Window.MODE_WINDOWED or md == Window.MODE_MAXIMIZED):
			_big_maximized = md == Window.MODE_MAXIMIZED
		return
	var now := Time.get_ticks_usec()   # 배속(F2)과 상관없는 진짜 시간
	if now >= _next_recheck_usec:
		_next_recheck_usec = now + int(Feel.WINDOW_RECHECK_SECONDS * 1e6)
		if DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()) != _placed_for:
			place_window()
	_update_region(now)


func _update_region(now: int) -> void:
	if _full or now < _next_region_usec or not rects_provider.is_valid():
		return
	_next_region_usec = now + int(Feel.CLICK_REGION_INTERVAL * 1e6)
	var poly := ClickRegion.build(rects_provider.call(), get_window().size.y)
	if poly != _last_polygon:
		_last_polygon = poly
		get_window().mouse_passthrough_polygon = poly
