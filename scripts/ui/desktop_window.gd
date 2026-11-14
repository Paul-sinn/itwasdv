## 바탕화면 위 진짜 창 다루기 (v1: 작은 화면 / 전체 화면). screen_mode.gd가 부른다.
##
## 작은 화면: 주 모니터 쓸 수 있는 영역(작업표시줄 뺀 곳)의 오른쪽 아래 구석, 크기 Feel.SMALL_SIZE.
##   테두리 없음 / 항상 위 / 배경 투명 / 보이는 것만 클릭 받음 (click_region.gd 설명 참고).
##   작업표시줄 위치·해상도가 바뀌면 다시 붙인다.
## 큰 화면 (어떻게 띄울지는 사용자가 고름. screen_mode.gd의 FullStyle):
##   전체 화면: 주 모니터를 꽉 채움. 테두리 없는 보통 창을 모니터보다 위아래 1픽셀씩 크게 (full_window_rect)
##   창 모드: 테두리 있는 보통 창. 크기 조절 가능. 처음엔 주 모니터 가운데 Feel.BIG_WINDOW_SIZE,
##            최소 Feel.BIG_WINDOW_MIN_SIZE. 게임을 켜 둔 동안은 마지막 크기·위치(최대화 여부)를 기억
##   둘 다: 배경 칠함 / 클릭 통과 없음 / 항상 위 아님 / 앞으로 가져오기
##
## Godot 4.6.3 + Windows에서 직접 확인한 것 (v1 0단계):
##   - 창 크기를 모니터 크기와 똑같이 직접 맞추면 Godot이 "독점 전체 화면"(MODE_EXCLUSIVE_FULLSCREEN)으로
##     바꿔버리고, 그 뒤로는 크기를 바꿔도 작아지지 않는다.
##   - Godot의 MODE_FULLSCREEN은 창을 모니터보다 2픽셀 크게 만드는데 그림은 모니터 크기만큼 아래쪽부터 그려서
##     화면 맨 위 2줄이 비고, 그 2줄로 뒤의 바탕화면이 보인다 (창 투명을 꺼도 같음).
##   → 테두리 없는 보통 창을 모니터보다 위아래 1픽셀씩 크게 직접 놓는다. Godot이 창 크기 그대로 다 그려서
##     빈 줄이 없고, 크기가 모니터와 달라서 독점 전체 화면으로 안 바뀌고, 작업표시줄도 덮인다 (3440x1440에서 실측).
##     (주 모니터 바로 위에 다른 모니터가 있으면 그 모니터 맨 아래 1줄에 이 창이 보일 수 있음)
##   - 창의 투명 설정(transparent)은 켜 둔 채로 두고, 배경 투명(transparent_bg)만 껐다 켜도 깨지지 않는다.
##   - 클릭 통과 다각형을 빈 배열로 주면 창 전체가 클릭을 받는다.
##
## 평범한 창으로 띄우려면(개발용): 실행 명령 끝에 -- --windowed
##
## v8b 설정 (Prefs [strip]): 띠 크기(Feel.SMALL_SIZE × 배율)·자리(오른쪽 아래 / 왼쪽 아래)·모니터·항상 위.
##   자리·크기 계산은 화면 없이 시험되는 순수 함수(strip_rect, pick_screen), 진짜 창에 넣는 곳은 small_rect / place_window / apply_small.
##   고른 모니터가 없으면(뽑힘) 주 모니터에 놓고 설정값은 남김. 큰 화면도 그 모니터에. 투명도는 그림 쪽(main.gd)
extends Node

const ClickRegion = preload("res://scripts/ui/click_region.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Prefs = preload("res://scripts/ui/prefs.gd")

## 클릭 받을 사각형 목록(창 좌표)을 돌려주는 함수. main.gd가 넣어준다.
var rects_provider: Callable

var _full := false
var _big_window := false               ## 큰 화면을 창 모드로 띄운 중
var _big_rect := Rect2i()              ## 창 모드 큰 화면의 마지막 자리 (없으면 크기 0)
var _big_maximized := false            ## 창 모드 큰 화면을 최대화해 둔 채 나갔나
var _last_polygon := PackedVector2Array()
var _next_region_usec := 0
var _next_recheck_usec := 0
var _placed_for := Rect2i()   ## 마지막으로 놓은 띠 자리 (small_rect가 달라지면 다시 놓음)


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


## 띠 크기: 작은 화면 크기 × 배율 (1.25 → 600x275)
static func strip_size(scale: float) -> Vector2i:
	return Vector2i((Vector2(Feel.SMALL_SIZE) * scale).round())


## 띠 자리 (순수 함수): 모니터 screen 안의 쓸 수 있는 영역 usable(작업표시줄 뺀 곳) 아래 구석에 붙임.
## corner = "right"(오른쪽 아래) / "left"(왼쪽 아래). 영역보다 크면 영역 크기로 자름
static func strip_rect(screen: Rect2i, usable: Rect2i, scale: float, corner: String) -> Rect2i:
	var area := usable.intersection(screen) if usable.intersects(screen) else screen   # 쓸 수 있는 영역이 이상하게 오면 모니터 전체
	var size := strip_size(scale).min(area.size)
	var x := area.position.x if corner == "left" else area.end.x - size.x
	return Rect2i(Vector2i(x, area.end.y - size.y), size)


## 띠·큰 화면을 놓을 모니터 (순수 함수): 고른 번호가 지금 연결돼 있으면 그것, 아니면(-1 = 주 모니터, 뽑힘) 주 모니터
static func pick_screen(pick: int, count: int, primary: int) -> int:
	return pick if pick >= 0 and pick < count else primary


## 지금 띠·큰 화면을 놓을 모니터 (설정 + 연결된 모니터)
static func screen_index() -> int:
	return pick_screen(Prefs.get_value("strip/screen"), DisplayServer.get_screen_count(), DisplayServer.get_primary_screen())


## 작은 화면이 놓일 자리 (Godot 화면 좌표): 설정 모니터 쓸 수 있는 영역의 구석 (기본 = 주 모니터 오른쪽 아래, 480x220)
static func small_rect() -> Rect2i:
	var s := screen_index()
	return strip_rect(Rect2i(DisplayServer.screen_get_position(s), DisplayServer.screen_get_size(s)),
			DisplayServer.screen_get_usable_rect(s), Prefs.get_value("strip/scale"), Prefs.get_value("strip/corner"))


## 전체 화면이 덮을 곳 (Godot 화면 좌표): 설정 모니터 전체 (기본 = 주 모니터)
static func full_rect() -> Rect2i:
	var s := screen_index()
	return Rect2i(DisplayServer.screen_get_position(s), DisplayServer.screen_get_size(s))


## 전체 화면 창의 실제 자리: 주 모니터보다 위아래 1픽셀씩 큼 (맨 위 설명 참고)
static func full_window_rect() -> Rect2i:
	var r := full_rect()
	return Rect2i(r.position - Vector2i(0, 1), r.size + Vector2i(0, 2))


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
	win.always_on_top = Prefs.get_value("strip/always_on_top")
	win.transparent_bg = true
	place_window()


## 큰 화면으로. windowed: 창 모드(테두리 있는 보통 창), 아니면 주 모니터 꽉 채우는 전체 화면.
## 배경 칠함, 창 전체가 클릭 받음, 앞으로 가져오기. 이미 큰 화면이어도 불러도 된다 (방식 바꾸기).
func apply_full(windowed: bool) -> void:
	var win := get_window()
	if windowed and _full and not _big_window:
		# 전체 화면에서 바로 테두리 있는 창으로 바꾸면 안쪽 높이가 4픽셀씩 모자라게 되고,
		# 그 뒤 작은 화면도 480x216이 된다 (4.6.3 Windows, MODE_FULLSCREEN 쓰던 때 확인).
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
		if win.mode != Window.MODE_WINDOWED:
			win.mode = Window.MODE_WINDOWED
		win.borderless = true
		var r := full_window_rect()
		win.size = r.size
		win.position = r.position
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


## 창 모드 큰 화면이 처음 놓일 자리 (Godot 화면 좌표): 설정 모니터(기본 = 주 모니터) 쓸 수 있는 영역 가운데
static func big_window_first_rect() -> Rect2i:
	var usable := DisplayServer.screen_get_usable_rect(screen_index())
	var size := Feel.BIG_WINDOW_SIZE.min(usable.size)
	return Rect2i(usable.position + (usable.size - size) / 2, size)


## 창 모드 큰 화면에서 나갈 때 지금 크기·위치를 기억 (다음에 그대로 띄우게)
func _remember_big_window() -> void:
	if not (_full and _big_window):
		return
	var win := get_window()
	if win.mode == Window.MODE_WINDOWED or win.mode == Window.MODE_MAXIMIZED:   # 최소화돼 있으면 전에 기억한 대로
		_big_maximized = win.mode == Window.MODE_MAXIMIZED
	if win.mode == Window.MODE_WINDOWED:
		_big_rect = Rect2i(win.position, win.size)


## 기억한 자리가 아직 어느 화면 위에 있나 (모니터를 뺐으면 처음 자리로)
static func _on_some_screen(r: Rect2i) -> bool:
	for s in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(s).has_point(r.get_center()):
			return true
	return false


## 작업표시줄 바로 위 구석에 붙이기 (작은 화면일 때만). 설정 모니터·자리·크기대로
func place_window() -> void:
	var r := small_rect()
	_placed_for = r
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
		if small_rect() != _placed_for:   # 작업표시줄·해상도가 바뀌었거나 고른 모니터를 뽑음
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
