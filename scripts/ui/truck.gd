## 트럭 그림: 꼬불길 위에서 target(집 번호, -1 = 물류센터) 쪽으로 달려가 거기서 기다린다.
## 어디로 갈지는 main.gd가 계산 쪽 바퀴 진행(TruckState)을 보고 정한다 (물류센터 → 집1 → … → 마지막 집 → 물류센터).
## 돈·배송은 여기서 하지 않는다 ("+돈"은 계산 쪽 배송 이벤트에 맞춰 town.gd가 띄움).
## 빠르기는 연출일 뿐: 강화 단계에 따라 빨라지다가 feel.gd TOWN_DRIVE_SECONDS_MIN(상한)에서 멈춘다.
##
## 움직임은 동네 설계 좌표(길 위 거리)로 하고, 그릴 때만 view_origin + 점 × view_zoom 으로 옮긴다.
## 그래서 작은 화면 ↔ 전체 화면을 오가도 트럭은 길 위 같은 자리에서 계속 간다.
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Route = preload("res://scripts/ui/route.gd")

const CAB_RATIO := 0.32      ## 운전석 폭 / 트럭 폭
const SMOKE_SPREAD := 10.0   ## 퍼짐 연기가 처음 옆으로 흩어지는 폭 (트럭 자기 좌표)

var star := 0          ## 강화 단계 (빠르기에만 씀)
var target := -1       ## 갈 곳: 집 번호(0부터), -1 = 물류센터

var view_origin := Vector2.ZERO   ## 동네 설계 좌표 (0,0)이 동네 노드 안에서 어디에 오나
var view_zoom := 1.0              ## 동네 확대 배수

var _route: Route
var _stops := PackedFloat64Array()   ## 집마다 길 위 거리 (물류센터에서 가까운 순)
var _s := 0.0          ## 지금 길 위 거리 (0 = 물류센터 앞)
var _face := 1         ## 그림이 보는 쪽: 1 = 오른쪽, -1 = 왼쪽

var _smoke: Array[Vector2] = []   ## 퍼짐 연기 덩이들: (x 흔들림, 나온 뒤 지난 초)

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


## 순간 가속: mult배 빨라졌다가 seconds 동안 원래대로 (보이는 것만. 상한은 안 넘음)
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


## 설계 좌표 기준 속도 (픽셀/초, 배속 곱하기 전). 순간 가속을 더해도 상한(TOWN_DRIVE_SECONDS_MIN)까지
func _drive_speed() -> float:
	return _loop_length() / maxf(Feel.TOWN_DRIVE_SECONDS_MIN, Feel.town_drive_seconds(star) / _boost_factor())


## 달릴 때 화면에서 움직이는 속도 (픽셀/초, 배속 곱하기 전)
func speed() -> float:
	if _route == null or _loop_length() < 1.0:
		return 0.0
	return _drive_speed() * view_zoom


## 화면 트럭 속도 상한 (픽셀/초, 배속 곱하기 전. 확인용)
func speed_cap() -> float:
	return _loop_length() / Feel.TOWN_DRIVE_SECONDS_MIN * view_zoom


## 집 house 앞(또는 -1 = 물류센터)에 서 있나
func is_at(house: int) -> bool:
	return absf(_s - _spot(house)) < 0.5


## 집 번호(-1 = 물류센터) → 길 위 거리
func _spot(house: int) -> float:
	return _stops[clampi(house, 0, _stops.size() - 1)] if house >= 0 and _stops.size() > 0 else 0.0


## 트럭 그림이 차지하는 사각형 (동네 노드 좌표). 떨림·여유 포함
func click_rect() -> Rect2:
	var k := view_zoom * Feel.TOWN_TRUCK_SCALE
	var w := Feel.TRUCK_SIZE.x * k
	var h := _height() * k
	var shake_room := _shake_px * Feel.ENGINE_SHAKE_GROW * k if _shake_left > 0.0 else 0.0
	return Rect2(position.x - w / 2.0, position.y - h, w, h).grow(Feel.TRUCK_CLICK_PADDING + shake_room)


## 연기가 퍼지는 사각형 (동네 노드 좌표). 연기가 없으면 크기 0
func smoke_rect() -> Rect2:
	if _smoke.is_empty():
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


## target 쪽으로 달리고, 닿으면 거기서 기다린다 (길은 한 줄이라 앞뒤로만 감)
func _move(delta: float) -> void:
	if _route == null or _loop_length() < 1.0:
		return
	var goal := _spot(target)
	if _s == goal:
		return
	var dir := signf(goal - _s)
	_s = move_toward(_s, goal, _drive_speed() * delta)
	var d := _route.direction_at(_s) * dir
	if absf(d.x) > 0.3:
		_face = 1 if d.x > 0.0 else -1


## 연기 덩이 나이를 먹이고 다 된 건 지운다
func _update_smoke(delta: float) -> void:
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
	var cab_w := w * CAB_RATIO
	# 앞(운전석)은 보는 쪽
	var cab_x := w - cab_w if _face > 0 else 0.0
	var box_x := 0.0 if _face > 0 else cab_w
	draw_rect(Rect2(box_x, 0, w - cab_w, h), Feel.COLOR_TRUCK_BOX)
	draw_rect(Rect2(cab_x, h * 0.3, cab_w, h * 0.7), Feel.COLOR_TRUCK_CAB)
	draw_circle(Vector2(w * 0.22, h + wr * 0.6), wr, Feel.COLOR_WHEEL)
	draw_circle(Vector2(w * 0.78, h + wr * 0.6), wr, Feel.COLOR_WHEEL)

	# 연기: 엔진(운전석) 위에서 올라가며 커지고 흐려짐
	var origin := _smoke_origin()
	for puff in _smoke:
		var k := puff.y / Feel.SMOKE_LIFE
		var color := Feel.COLOR_SMOKE
		color.a *= 1.0 - k
		var radius := lerpf(Feel.SMOKE_SIZE.x, Feel.SMOKE_SIZE.y, k)
		draw_circle(origin + Vector2(puff.x * (1.0 + k * 3.0), -Feel.SMOKE_RISE * k), radius, color)
