## 트럭: 물류센터 ↔ 집 왕복. 집에 닿을 때마다 delivered 신호를 보낸다.
## 돈 계산은 여기서 하지 않는다. "이번 배송에 몇 초 걸렸나"만 알려준다.
## 고장(running = false)이면 그 자리에 멈추고 연기가 난다.
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")

## 집에 도착(배송 완료). trip_seconds = 지난 배송 뒤로 트럭이 움직인(멈춘 시간 빼고) 초
signal delivered(trip_seconds: float)

var star := 0          ## 강수 (빠르기에만 씀)
var running := true    ## false면 그 자리에 멈춤 (고장)

var _x_from := 0.0     ## 물류센터 앞
var _x_to := 0.0       ## 집 앞
var _x := 0.0
var _dir := 1          ## 1 = 집 쪽으로, -1 = 물류센터 쪽으로
var _pause := 0.0      ## 건물 앞에서 서 있는 남은 초
var _trip_elapsed := 0.0

var _smoke: Array[Vector2] = []   ## 연기 덩이들: (x 흔들림, 나온 뒤 지난 초)
var _smoke_timer := 0.0


## 왕복 구간 정하기 (창 크기가 바뀔 때마다 불림)
func set_track(x_from: float, x_to: float, y: float) -> void:
	var was_ratio := 0.0
	if _x_to > _x_from:
		was_ratio = (_x - _x_from) / (_x_to - _x_from)
	_x_from = x_from
	_x_to = maxf(x_to, x_from)
	_x = lerpf(_x_from, _x_to, clampf(was_ratio, 0.0, 1.0))
	position = Vector2(_x, y)


## 클릭 판정용 사각형 (트럭의 부모 기준 좌표)
func click_rect() -> Rect2:
	var size := Feel.TRUCK_SIZE + Vector2(0, Feel.WHEEL_RADIUS)
	return Rect2(position, size).grow(Feel.TRUCK_CLICK_PADDING)


func _process(delta: float) -> void:
	_update_smoke(delta)
	if running:
		_move(delta)
	queue_redraw()


func _move(delta: float) -> void:
	var distance := _x_to - _x_from
	if distance < 1.0:
		return
	var speed := distance / Feel.one_way_seconds(star)
	var t := delta
	# 한 프레임이 길어도(배속 등) 남은 시간을 끝까지 써서 정확히 움직인다
	while t > 0.0:
		if _pause > 0.0:
			var wait := minf(_pause, t)
			_pause -= wait
			t -= wait
			_trip_elapsed += wait
			continue
		var target := _x_to if _dir > 0 else _x_from
		var need := absf(target - _x) / speed
		if need <= t:
			_x = target
			t -= need
			_trip_elapsed += need
			_arrive()
		else:
			_x += speed * t * _dir
			_trip_elapsed += t
			t = 0.0
	position.x = _x


func _arrive() -> void:
	_pause = Feel.STOP_AT_END
	if _dir > 0:
		delivered.emit(_trip_elapsed)
		_trip_elapsed = 0.0
	_dir = -_dir


## 고장 중이면 연기 덩이를 새로 만들고, 있는 덩이는 나이를 먹이고 다 된 건 지운다
func _update_smoke(delta: float) -> void:
	if not running:
		_smoke_timer -= delta
		while _smoke_timer <= 0.0:
			_smoke_timer += Feel.SMOKE_INTERVAL
			_smoke.append(Vector2(randf_range(-3.0, 3.0), 0.0))
	for i in _smoke.size():
		_smoke[i].y += delta
	while not _smoke.is_empty() and _smoke[0].y >= Feel.SMOKE_LIFE:
		_smoke.pop_front()


func _draw() -> void:
	var w := Feel.TRUCK_SIZE.x
	var h := Feel.TRUCK_SIZE.y
	var box_color := Feel.COLOR_TRUCK_BOX if running else Feel.COLOR_TRUCK_STOPPED
	var cab_w := w * 0.32
	# 앞(운전석)은 가는 방향 쪽
	var cab_x := w - cab_w if _dir > 0 else 0.0
	var box_x := 0.0 if _dir > 0 else cab_w
	draw_rect(Rect2(box_x, 0, w - cab_w, h), box_color)
	draw_rect(Rect2(cab_x, h * 0.3, cab_w, h * 0.7), Feel.COLOR_TRUCK_CAB if running else Feel.COLOR_TRUCK_STOPPED)
	draw_circle(Vector2(w * 0.22, h), Feel.WHEEL_RADIUS, Feel.COLOR_WHEEL)
	draw_circle(Vector2(w * 0.78, h), Feel.WHEEL_RADIUS, Feel.COLOR_WHEEL)

	# 연기: 엔진(운전석) 위에서 올라가며 커지고 흐려짐
	var origin := Vector2(cab_x + cab_w * 0.5, h * 0.3)
	for puff in _smoke:
		var k := puff.y / Feel.SMOKE_LIFE
		var color := Feel.COLOR_SMOKE
		color.a *= 1.0 - k
		var radius := lerpf(Feel.SMOKE_SIZE.x, Feel.SMOKE_SIZE.y, k)
		draw_circle(origin + Vector2(puff.x * (1.0 + k * 3.0), -Feel.SMOKE_RISE * k), radius, color)
