## 트럭: 꼬불길을 따라 물류센터 → 집1 → … → 마지막 집 → (돌아서) 물류센터 → 반복.
## 집 앞에 닿을 때마다 delivered 신호를 보내고 TOWN_STOP_SECONDS 동안 선다.
## 돈 계산은 여기서 하지 않는다. "지난번 받은 뒤 몇 초 흘렀나(선 시간 포함)"만 알려준다.
## 고장(running = false)이면 그 자리에 멈추고 연기가 난다. 멈춘 동안은 시간을 세지 않는다 (수익 0).
##
## 움직임은 동네 설계 좌표(길 위 거리)로 하고, 그릴 때만 view_origin + 점 × view_zoom 으로 옮긴다.
## 그래서 작은 화면 ↔ 전체 화면을 오가도 트럭은 길 위 같은 자리에서 계속 간다.
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Route = preload("res://scripts/ui/route.gd")

## 집 앞에 도착. house = 몇 번째 집(0부터), seconds = 지난번 delivered 뒤로 흐른 게임 초 (선 시간 포함)
signal delivered(house: int, seconds: float)

const CAB_RATIO := 0.32      ## 운전석 폭 / 트럭 폭
const SMOKE_SPREAD := 10.0   ## 퍼짐 연기가 처음 옆으로 흩어지는 폭 (트럭 자기 좌표)

var star := 0          ## 강수 (빠르기에만 씀)
var running := true    ## false면 그 자리에 멈춤 (고장)
var tune_grade := 0    ## 7부위 중 가장 높은 튜닝 등급 → 짐칸 옆면에 그 등급 색 점 (0 = 일반이면 점 없음)

var view_origin := Vector2.ZERO   ## 동네 설계 좌표 (0,0)이 동네 노드 안에서 어디에 오나
var view_zoom := 1.0              ## 동네 확대 배수

var _route: Route
var _stops := PackedFloat64Array()   ## 집마다 길 위 거리 (물류센터에서 가까운 순)
var _s := 0.0          ## 지금 길 위 거리 (0 = 물류센터 앞)
var _dir := 1          ## 1 = 집 쪽으로, -1 = 물류센터로 돌아가는 중
var _next_house := 0   ## 다음에 들를 집
var _pause := 0.0      ## 서 있는 남은 초
var _since_pay := 0.0  ## 지난번 delivered 뒤로 흐른 게임 초
var _face := 1         ## 그림이 보는 쪽: 1 = 오른쪽, -1 = 왼쪽

var _smoke: Array[Vector2] = []   ## 연기 덩이들: (x 흔들림, 나온 뒤 지난 초)
var _smoke_timer := 0.0

# 강화 연출 (진짜 시간 기준)
var _shake_left := 0.0
var _shake_total := 0.0
var _shake_px := 0.0
var _shake_offset := Vector2.ZERO
var _boost_mult := 1.0
var _boost_left := 0.0
var _boost_total := 0.0


## 달릴 길과 집 자리를 정한다 (처음 한 번). 트럭은 물류센터 앞에서 출발.
func set_route(route: Route, stops: PackedFloat64Array) -> void:
	_route = route
	_stops = stops
	_s = 0.0
	_dir = 1
	_next_house = 0
	_pause = 0.0
	_since_pay = 0.0
	place()


## 동네 확대·위치가 바뀌면 불림 (길 위 자리는 그대로)
func set_view(origin: Vector2, zoom: float) -> void:
	view_origin = origin
	view_zoom = zoom
	place()


## 길 위 거리 → 화면 자리. 트럭 그림의 (0,0)은 바퀴 바닥 가운데.
func place() -> void:
	if _route == null:
		return
	position = view_origin + (_route.point_at(_s) + Vector2(0, Feel.TOWN_TRUCK_LIFT)) * view_zoom
	scale = Vector2.ONE * view_zoom * Feel.TOWN_TRUCK_SCALE


## 엔진 떨림: seconds 동안 px 세기로 (끝으로 갈수록 ENGINE_SHAKE_GROW배까지 세짐). 트럭 자기 좌표 픽셀
func shake(seconds: float, px: float) -> void:
	_shake_left = seconds
	_shake_total = seconds
	_shake_px = px


## 순간 가속: mult배 빨라졌다가 seconds 동안 원래대로 (보이는 것만. 수익은 시간 기준이라 그대로)
func boost(mult: float, seconds: float) -> void:
	_boost_mult = mult
	_boost_left = seconds
	_boost_total = seconds


## 번쩍임: 하얗게 빛났다가 돌아옴
func flash(seconds: float) -> void:
	modulate = Color(2.5, 2.5, 2.5)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate", Color.WHITE, seconds)


## 퍼짐 순간 연기 한꺼번에
func smoke_burst(count: int) -> void:
	for i in count:
		_smoke.append(Vector2(randf_range(-SMOKE_SPREAD, SMOKE_SPREAD), randf_range(0.0, 0.5)))


func _boost_factor() -> float:
	if _boost_left <= 0.0:
		return 1.0
	return lerpf(1.0, _boost_mult, _boost_left / _boost_total)


## 한 바퀴 길이 (물류센터 → 마지막 집 → 물류센터)
func _loop_length() -> float:
	return 2.0 * _stops[_stops.size() - 1] if _stops.size() > 0 else 0.0


## 설계 좌표 기준 속도 (픽셀/초, 배속 곱하기 전)
func _drive_speed() -> float:
	return _loop_length() / Feel.town_drive_seconds(star) * _boost_factor()


## 지금 화면에서 움직이는 속도 (픽셀/초, 배속 곱하기 전). 서 있거나 고장이면 0
func speed() -> float:
	if not running or _route == null or _loop_length() < 1.0:
		return 0.0
	return _drive_speed() * view_zoom


## 트럭 그림이 차지하는 사각형 (동네 노드 좌표). 떨림·여유 포함
func click_rect() -> Rect2:
	var k := view_zoom * Feel.TOWN_TRUCK_SCALE
	var w := Feel.TRUCK_SIZE.x * k
	var h := _height() * k
	var shake_room := _shake_px * Feel.ENGINE_SHAKE_GROW * k if _shake_left > 0.0 else 0.0
	return Rect2(position.x - w / 2.0, position.y - h, w, h).grow(Feel.TRUCK_CLICK_PADDING + shake_room)


## 연기가 퍼지는 사각형 (동네 노드 좌표). 연기가 없으면 크기 0
func smoke_rect() -> Rect2:
	if _smoke.is_empty() and running:
		return Rect2()
	var k := view_zoom * Feel.TOWN_TRUCK_SCALE
	var o := _smoke_origin()
	var side := SMOKE_SPREAD * 4.0 + Feel.SMOKE_SIZE.y   # 옆으로 퍼지는 폭 (_draw 참고)
	var up := Feel.SMOKE_RISE + Feel.SMOKE_SIZE.y
	var local := Rect2(o.x - side, o.y - up, side * 2.0, up + Feel.SMOKE_SIZE.y)
	local.position += Vector2(-Feel.TRUCK_SIZE.x / 2.0, -_height())
	return Rect2(position + local.position * k, local.size * k).grow(Feel.TRUCK_CLICK_PADDING)


## 바퀴 바닥부터 짐칸 위까지 높이 (트럭 자기 좌표)
func _height() -> float:
	return Feel.TRUCK_SIZE.y + Feel.WHEEL_RADIUS * 1.6


## 연기가 나오는 곳: 엔진(운전석) 위 (트럭 그림 왼쪽 위 기준)
func _smoke_origin() -> Vector2:
	var w := Feel.TRUCK_SIZE.x
	var cab_w := w * CAB_RATIO
	var cab_x := w - cab_w if _face > 0 else 0.0
	return Vector2(cab_x + cab_w * 0.5, Feel.TRUCK_SIZE.y * 0.3)


## 길 위 거리 (확인용)
func distance() -> float:
	return _s


func _process(delta: float) -> void:
	# 연출은 진짜 시간으로 (F2 배속이어도 같은 빠르기), 이동은 게임 시간으로
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	_update_effects(real)
	_update_smoke(real)
	if running:
		_move(delta)
	place()
	queue_redraw()


func _update_effects(real: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - real)
		var k := 1.0 - _shake_left / _shake_total   # 0 → 1
		var px := _shake_px * lerpf(1.0, Feel.ENGINE_SHAKE_GROW, k)
		_shake_offset = Vector2(randf_range(-px, px), randf_range(-px, px) * 0.5)
	else:
		_shake_offset = Vector2.ZERO
	if _boost_left > 0.0:
		_boost_left = maxf(0.0, _boost_left - real)


func _move(delta: float) -> void:
	if _route == null or _loop_length() < 1.0:
		return
	var speed := _drive_speed()
	var t := delta
	# 한 프레임이 길어도(배속 등) 남은 시간을 끝까지 써서 정확히 움직인다
	while t > 0.0:
		if _pause > 0.0:
			var wait := minf(_pause, t)
			_pause -= wait
			t -= wait
			_since_pay += wait
			continue
		var target := _stops[_next_house] if _dir > 0 else 0.0
		var need := absf(target - _s) / speed
		if need <= t:
			_s = target
			t -= need
			_since_pay += need
			_arrive()
		else:
			_s += speed * t * _dir
			_since_pay += t
			t = 0.0
	var d := _route.direction_at(_s) * _dir
	if absf(d.x) > 0.3:
		_face = 1 if d.x > 0.0 else -1


func _arrive() -> void:
	if _dir > 0:
		# 집 앞: 돈 받고 서기. 마지막 집이면 돌아서 물류센터로
		var house := _next_house
		var seconds := _since_pay
		_since_pay = 0.0
		_pause = Feel.TOWN_STOP_SECONDS
		_next_house += 1
		if _next_house >= _stops.size():
			_dir = -1
		delivered.emit(house, seconds)
	else:
		# 물류센터: 짐 싣고 다시 집1로 (돈은 안 받음. 다음 집에서 합쳐서 받음)
		_pause = Feel.TOWN_DEPOT_STOP_SECONDS
		_dir = 1
		_next_house = 0


## 고장 중이면 연기 덩이를 새로 만들고, 있는 덩이는 나이를 먹이고 다 된 건 지운다
func _update_smoke(delta: float) -> void:
	if not running:
		_smoke_timer -= delta
		while _smoke_timer <= 0.0:
			_smoke_timer += Feel.SMOKE_INTERVAL
			_smoke.append(Vector2(randf_range(-3.0, 3.0), 0.0))
	for i in range(_smoke.size() - 1, -1, -1):
		_smoke[i].y += delta
		if _smoke[i].y >= Feel.SMOKE_LIFE:
			_smoke.remove_at(i)


## 트럭 자기 좌표: (0,0) = 바퀴 바닥 가운데. 크기는 TRUCK_SIZE (scale로 키움)
func _draw() -> void:
	var w := Feel.TRUCK_SIZE.x
	var h := Feel.TRUCK_SIZE.y
	var wr := Feel.WHEEL_RADIUS
	draw_set_transform(_shake_offset + Vector2(-w / 2.0, -_height()))
	var box_color := Feel.COLOR_TRUCK_BOX if running else Feel.COLOR_TRUCK_STOPPED
	var cab_w := w * CAB_RATIO
	# 앞(운전석)은 보는 쪽
	var cab_x := w - cab_w if _face > 0 else 0.0
	var box_x := 0.0 if _face > 0 else cab_w
	draw_rect(Rect2(box_x, 0, w - cab_w, h), box_color)
	draw_rect(Rect2(cab_x, h * 0.3, cab_w, h * 0.7), Feel.COLOR_TRUCK_CAB if running else Feel.COLOR_TRUCK_STOPPED)
	draw_circle(Vector2(w * 0.22, h + wr * 0.6), wr, Feel.COLOR_WHEEL)
	draw_circle(Vector2(w * 0.78, h + wr * 0.6), wr, Feel.COLOR_WHEEL)

	# 튜닝 등급 점: 짐칸 옆면 가운데 (트럭 그림 안이라 작은 화면에서도 보이는 곳 안)
	if tune_grade > 0:
		var dot := Vector2(box_x + (w - cab_w) / 2.0, h * 0.45)
		var dot_color: Color = Feel.TUNE_GRADE_COLORS[mini(tune_grade, Feel.TUNE_GRADE_COLORS.size() - 1)]
		draw_circle(dot, Feel.TUNE_DOT_RADIUS + Feel.TUNE_DOT_OUTLINE, Feel.COLOR_TEXT_OUTLINE)
		draw_circle(dot, Feel.TUNE_DOT_RADIUS, dot_color)

	# 연기: 엔진(운전석) 위에서 올라가며 커지고 흐려짐
	var origin := _smoke_origin()
	for puff in _smoke:
		var k := puff.y / Feel.SMOKE_LIFE
		var color := Feel.COLOR_SMOKE
		color.a *= 1.0 - k
		var radius := lerpf(Feel.SMOKE_SIZE.x, Feel.SMOKE_SIZE.y, k)
		draw_circle(origin + Vector2(puff.x * (1.0 + k * 3.0), -Feel.SMOKE_RISE * k), radius, color)
