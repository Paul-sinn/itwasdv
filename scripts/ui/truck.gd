## 트럭 그림: 계산 쪽 한 바퀴 진행(follow(0~1))을 따라 물류센터 → 마지막 집 → (돌아서) 물류센터를 돈다.
## 돈·배송은 여기서 하지 않는다 ("+돈"은 계산 쪽 배송 이벤트가 올 때 town.gd가 트럭에서 가까운 집에 띄움).
## 빠르기는 계산 쪽을 따르되(강화·세팅으로 빨라짐) feel.gd TOWN_DRIVE_SECONDS_MIN(상한, 시내는 CITY_DRIVE_SECONDS_MIN)보다 빨리 돌지 않는다.
## v7-bal U3 시내: 물류센터 → 집마다 서며 배송 → 물류센터 (stop_and_go. "+돈"은 배송된 그 집에)
##
## 움직임은 동네 설계 좌표(길 위 거리)로 하고, 그릴 때만 view_origin + 점 × view_zoom 으로 옮긴다.
## 그래서 작은 화면 ↔ 전체 화면을 오가도 트럭은 길 위 같은 자리에서 계속 간다.
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Route = preload("res://scripts/ui/route.gd")

const CAB_RATIO := 0.32      ## 운전석 폭 / 트럭 폭
const SMOKE_SPREAD := 10.0   ## 퍼짐 연기가 처음 옆으로 흩어지는 폭 (트럭 자기 좌표)

var boosting := false  ## 오버부스트가 걸린 바퀴 (트럭 뒤 불꽃)
var box_color := Feel.COLOR_TRUCK_BOX   ## 짐칸 색 (v7a: 보조 트럭은 색만 다름. base_color)
var wrap := ""         ## 입힌 랩핑 id (v8a: "" = 없음, "stripe" / "flame" / "gold18" / "bandage"). 차체 색·무늬만 (draw_body)

var view_origin := Vector2.ZERO   ## 동네 설계 좌표 (0,0)이 동네 노드 안에서 어디에 오나
var view_zoom := 1.0              ## 동네 확대 배수

var _route: Route
var _stops := PackedFloat64Array()   ## 집마다 길 위 거리 (물류센터에서 가까운 순)
var _s := 0.0          ## 지금 길 위 거리 (0 = 물류센터 앞)
var _goal := 0.0       ## 있어야 할 길 위 거리 (follow로 정함)
var _moved_speed := 0.0   ## 지난 프레임에 실제로 움직인 속도 (설계 좌표 픽셀/초, 확인용)
var _face := 1         ## 그림이 보는 쪽: 1 = 오른쪽, -1 = 왼쪽
var _lap_min := Feel.TOWN_DRIVE_SECONDS_MIN   ## 속도 상한: 한 바퀴를 이 초보다 빨리 안 돎 (시내면 CITY_DRIVE_SECONDS_MIN)

var _smoke: Array[Vector2] = []   ## 퍼짐 연기 덩이들: (x 흔들림, 나온 뒤 지난 초)

# 강화 연출 (진짜 시간 기준)
var _shake_left := 0.0
var _shake_total := 0.0
var _shake_px := 0.0
var _shake_offset := Vector2.ZERO
var _flame_left := 0.0   ## 강화 성공 불꽃 남은 초 (진짜 시간)


## 달릴 길과 집 자리를 정한다 (처음 한 번). 트럭은 물류센터 앞에서 출발.
func set_route(route: Route, stops: PackedFloat64Array) -> void:
	_route = route
	_stops = stops
	_s = 0.0
	_goal = 0.0
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
	var p := _route.point_at(maxf(_s, 0.0)) + _route.direction_at(0.0) * minf(_s, 0.0)   # 음수 = 길 시작점 밖 (장거리)
	position = view_origin + (p + Vector2(0, Feel.TOWN_TRUCK_LIFT)) * view_zoom
	scale = Vector2.ONE * view_zoom * Feel.TOWN_TRUCK_SCALE
	# 동네 왼쪽 끝을 넘어가면 넘어간 만큼 흐려짐 (큰 화면은 동네 밖도 그려지는 창이라)
	var half := Feel.TRUCK_SIZE.x * Feel.TOWN_TRUCK_SCALE / 2.0
	self_modulate.a = clampf((p.x + half) / (2.0 * half), 0.0, 1.0)


## 엔진 떨림: seconds 동안 px 세기로 (끝으로 갈수록 ENGINE_SHAKE_GROW배까지 세짐). 트럭 자기 좌표 픽셀
func shake(seconds: float, px: float) -> void:
	_shake_left = seconds
	_shake_total = seconds
	_shake_px = px


## 강화 성공: seconds 동안 트럭 뒤 불꽃 (보이는 것만)
func boost(seconds: float) -> void:
	_flame_left = seconds


## 서는 곳만 바꿈 (시내 ↔ 동네. 길 위 자리는 그대로, 다음 follow·stop_and_go가 갈 곳을 정함)
func set_stops(stops: PackedFloat64Array) -> void:
	_stops = stops


## 시내 (v7-bal U3): 집마다 섬. x = 계산 쪽 집 기준 자리 (Trip.lap_stop_progress: 0 = 물류센터, k = k번째 집 앞에 섬(정수),
## 그 사이 = 다음 집까지 달린 몫, n ~ n+1 = 마지막 집 → 물류센터), n = 이번 바퀴 실은 수 (Trip.lap_cargo)
func stop_and_go(x: float, n: int) -> void:
	_lap_min = Feel.CITY_DRIVE_SECONDS_MIN
	n = mini(n, _stops.size())
	var j := clampi(floori(x), 0, n)
	var from := _stops[j - 1] if j > 0 else 0.0
	var to := _stops[j] if j < n else 0.0
	_goal = lerpf(from, to, clampf(x - j, 0.0, 1.0))


## 한 바퀴 중 어디쯤 있어야 하나: 0 = 물류센터, 0.5 = 마지막 집(돌아서는 곳), 1 = 다시 물류센터
func follow(phase: float) -> void:
	_lap_min = Feel.TOWN_DRIVE_SECONDS_MIN
	var d := clampf(phase, 0.0, 1.0) * _loop_length()
	_goal = d if d <= _loop_length() / 2.0 else _loop_length() - d


## 장거리 (v7b): 물류센터 → 왼쪽 화면 밖 → (먼 길) → 화면 밖에서 돌아와 물류센터. x = 이번 바퀴 진행 (Trip.lap_progress 0 ~ 1).
## 바퀴 = 나가는 길 LONG_EXIT_PX + 먼 길(동네 한 바퀴 × LONG_VIEW_LOOPS) + 들어오는 길로 쳐서, 동네에서 달릴 때 빠르기로 나가고
## 바퀴가 끝날 때 물류센터에 닿게 들어옴. 화면 밖 = 길 위 거리가 음수 (길 시작점에서 길 반대쪽으로 곧게)
func far(x: float) -> void:
	_lap_min = Feel.TOWN_DRIVE_SECONDS_MIN
	var total := 2.0 * Feel.LONG_EXIT_PX + _loop_length() * Feel.LONG_VIEW_LOOPS
	var d := clampf(x, 0.0, 1.0) * total
	_goal = -minf(minf(d, Feel.LONG_EXIT_PX), total - d)


## 화면 밖에 나가 있나 (다 나갔고 돌아오는 중도 아님). 보이는 곳에서 뺌
func away() -> bool:
	return self_modulate.a <= 0.0 and _goal <= _s


## 트럭에서(가야 할 자리에서) 가장 가까운 집 번호
func nearest_house() -> int:
	var best := 0
	for i in _stops.size():
		if absf(_stops[i] - _goal) < absf(_stops[best] - _goal):
			best = i
	return best


## 번쩍임: 하얗게 빛났다가 돌아옴
func flash(seconds: float) -> void:
	modulate = Color(2.5, 2.5, 2.5)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate", Color.WHITE, seconds)


## 퍼짐 순간 연기 한꺼번에
func smoke_burst(count: int) -> void:
	for i in count:
		_smoke.append(Vector2(randf_range(-SMOKE_SPREAD, SMOKE_SPREAD), randf_range(0.0, 0.5)))


## 한 바퀴 길이 (물류센터 → 마지막 집 → 물류센터)
func _loop_length() -> float:
	return 2.0 * _stops[_stops.size() - 1] if _stops.size() > 0 else 0.0


## 지난 프레임에 실제로 움직인 속도 (픽셀/초, 배속 곱하기 전). 보이는 곳 여유 계산에 씀
func speed() -> float:
	return _moved_speed * view_zoom


## 화면 트럭 속도 상한 (픽셀/초, 배속 곱하기 전. 확인용)
func speed_cap() -> float:
	return _loop_length() / _lap_min * view_zoom


## 있어야 할 자리보다 얼마나 뒤처졌나 (설계 좌표 픽셀. 확인용)
func lag() -> float:
	return absf(_goal - _s)


## 트럭 그림이 차지하는 사각형 (동네 노드 좌표). 떨림·여유 포함
func click_rect() -> Rect2:
	var k := view_zoom * Feel.TOWN_TRUCK_SCALE
	var w := Feel.TRUCK_SIZE.x * k
	var h := _height() * k
	var shake_room := _shake_px * Feel.ENGINE_SHAKE_GROW * k if _shake_left > 0.0 else 0.0
	var flame_room := Feel.FLAME_LENGTH * Feel.FLAME_FLICKER_MAX * k if _flaming() else 0.0
	return Rect2(position.x - w / 2.0, position.y - h, w, h).grow(Feel.TRUCK_CLICK_PADDING + shake_room + flame_room)


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


## 불꽃이 가장 길 때 차지하는 사각형 (동네 노드 좌표). 불꽃이 없으면 크기 0 (확인용)
func flame_rect() -> Rect2:
	if not _flaming():
		return Rect2()
	var k := view_zoom * Feel.TOWN_TRUCK_SCALE
	var pts := _flame_points(Feel.FLAME_LENGTH * Feel.FLAME_FLICKER_MAX, Feel.FLAME_WIDTH)
	var local := Rect2(pts[0], Vector2.ZERO).expand(pts[1]).expand(pts[2])
	local.position += _shake_offset + Vector2(-Feel.TRUCK_SIZE.x / 2.0, -_height())
	return Rect2(position + local.position * k, local.size * k)


## 불꽃이 나오나: 오버부스트 바퀴 동안, 강화 성공 순간
func _flaming() -> bool:
	return boosting or _flame_left > 0.0


## 불꽃 세모: 짐칸 뒤(보는 쪽 반대)로 length만큼 뻗음 (트럭 그림 왼쪽 위 기준)
func _flame_points(length: float, width: float) -> PackedVector2Array:
	var back := 0.0 if _face > 0 else Feel.TRUCK_SIZE.x
	var out := -1.0 if _face > 0 else 1.0
	var y := Feel.TRUCK_SIZE.y * Feel.FLAME_Y
	return PackedVector2Array([Vector2(back, y - width / 2.0), Vector2(back + out * length, y), Vector2(back, y + width / 2.0)])


## 바퀴 바닥부터 짐칸 위까지 높이 (트럭 자기 좌표)
func _height() -> float:
	return body_height()


static func body_height() -> float:
	return Feel.TRUCK_SIZE.y + Feel.WHEEL_RADIUS * 1.6


## 트럭 번호의 원래 짐칸 색 (0 = 내 트럭, 1~ = 보조 트럭은 HELPER_TRUCK_COLORS를 돌아가며)
static func base_color(i: int) -> Color:
	return Feel.COLOR_TRUCK_BOX if i == 0 else Feel.HELPER_TRUCK_COLORS[(i - 1) % Feel.HELPER_TRUCK_COLORS.size()]


## 트럭 몸통 (짐칸·운전석 + 랩핑 무늬 = body_shapes, 그리고 바퀴)을 ci에 그림. 왼쪽 위 = (0,0), 폭 TRUCK_SIZE.x, 높이 body_height().
## 띠·큰 화면 트럭(_draw)과 튜닝숍 [랩핑] 미리 보기(wrap_tab.gd)가 같이 씀
static func draw_body(ci: CanvasItem, face: int, box_color: Color, wrap: String) -> void:
	for shape: Array in body_shapes(face, box_color, wrap):
		ci.draw_colored_polygon(shape[0], shape[1])
	var w := Feel.TRUCK_SIZE.x
	var h := Feel.TRUCK_SIZE.y
	var wr := Feel.WHEEL_RADIUS
	ci.draw_circle(Vector2(w * 0.22, h + wr * 0.6), wr, Feel.COLOR_WHEEL)
	ci.draw_circle(Vector2(w * 0.78, h + wr * 0.6), wr, Feel.COLOR_WHEEL)


## 짐칸·운전석 + 랩핑 무늬 도형들 [점들, 색] (그리는 순서). face 1 = 오른쪽을 봄(운전석이 오른쪽).
## 랩핑(v8a)은 차체 색·무늬만 바꾸고 짐칸·운전석 사각형 밖으로 안 나감 (보이는 곳 그대로. check_v8a가 점마다 확인)
static func body_shapes(face: int, box_color: Color, wrap: String) -> Array:
	var w := Feel.TRUCK_SIZE.x
	var h := Feel.TRUCK_SIZE.y
	var cab_w := w * CAB_RATIO
	# 앞(운전석)은 보는 쪽
	var cab := Rect2(w - cab_w if face > 0 else 0.0, h * 0.3, cab_w, h * 0.7)
	var box := Rect2(0.0 if face > 0 else cab_w, 0, w - cab_w, h)
	var colors: Array = Feel.WRAP_BODY.get(wrap, [box_color, Feel.COLOR_TRUCK_CAB])
	var out := [[_quad(box), colors[0]], [_quad(cab), colors[1]]]
	match wrap:
		"stripe":   # 짐칸·운전석을 가로지르는 줄무늬 두 줄
			for top: float in Feel.WRAP_STRIPES:
				var band := Rect2(0, h * top, w, h * Feel.WRAP_STRIPE_HEIGHT)
				for part: Rect2 in [band.intersection(box), band.intersection(cab)]:
					if part.has_area():
						out.append([_quad(part), Feel.COLOR_WRAP_STRIPE])
		"flame":   # 짐칸 앞(운전석 쪽)에서 뒤로 뻗는 불꽃 혀 (위쪽 조금 빼고)
			var front := box.end.x if face > 0 else box.position.x
			var back := -float(face)
			var n: int = Feel.WRAP_FLAME_LENGTHS.size()
			var top := h * Feel.WRAP_FLAME_TOP
			var step := (h - top) / n
			for k in n:
				var reach: float = box.size.x * Feel.WRAP_FLAME_LENGTHS[k]
				var y0 := top + step * k
				out.append([PackedVector2Array([Vector2(front, y0), Vector2(front + back * reach, y0 + step * 0.3), Vector2(front, y0 + step)]),
						Feel.COLOR_WRAP_FLAME])
				out.append([PackedVector2Array([Vector2(front, y0 + step * 0.25), Vector2(front + back * reach * 0.55, y0 + step * 0.4),
						Vector2(front, y0 + step * 0.75)]), Feel.COLOR_WRAP_FLAME_CORE])
		"gold18":   # 금색 차체 + 비스듬한 반짝임 띠
			var x0 := box.position.x + box.size.x * Feel.WRAP_SHINE_X
			var dx := box.size.x * Feel.WRAP_SHINE_WIDTH
			var lean := box.size.x * Feel.WRAP_SHINE_LEAN
			out.append([PackedVector2Array([Vector2(x0 + lean, 0), Vector2(x0 + lean + dx, 0), Vector2(x0 + dx, h), Vector2(x0, h)]),
					Feel.COLOR_WRAP_SHINE])
		"bandage":   # 원래 색 짐칸에 X자로 붙인 반창고 두 장 + 가운데 거즈
			var inset := box.grow(-h * Feel.WRAP_BANDAGE_INSET)
			var half := h * Feel.WRAP_BANDAGE_WIDTH / 2.0
			for d: Array in [[inset.position, inset.end], [Vector2(inset.position.x, inset.end.y), Vector2(inset.end.x, inset.position.y)]]:
				var a: Vector2 = d[0]
				var b: Vector2 = d[1]
				var side := (b - a).normalized().orthogonal() * half
				out.append([PackedVector2Array([a + side, b + side, b - side, a - side]), Feel.COLOR_WRAP_BANDAGE])
			var pad := Vector2.ONE * half * 1.6
			out.append([_quad(Rect2(inset.get_center() - pad / 2.0, pad)), Feel.COLOR_WRAP_BANDAGE_PAD])
	return out


static func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


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
	_flame_left = maxf(0.0, _flame_left - real)


## 있어야 할 자리 쪽으로 (상한 속도까지만). 길은 한 줄이라 앞뒤로만 감
func _move(delta: float) -> void:
	_moved_speed = 0.0
	if _route == null or _loop_length() < 1.0 or _s == _goal or delta <= 0.0:
		return
	var dir := signf(_goal - _s)
	var before := _s
	_s = move_toward(_s, _goal, _loop_length() / _lap_min * delta)
	_moved_speed = absf(_s - before) / delta
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
	draw_set_transform(_shake_offset + Vector2(-w / 2.0, -_height()))
	draw_body(self, _face, box_color, wrap)

	# 불꽃: 짐칸 뒤(보는 쪽 반대)로 뻗는 세모 두 겹 (오버부스트 바퀴 동안, 강화 성공 순간)
	if _flaming():
		var len := Feel.FLAME_LENGTH * randf_range(Feel.FLAME_FLICKER_MIN, Feel.FLAME_FLICKER_MAX)   # 깜빡이는 느낌
		draw_colored_polygon(_flame_points(len, Feel.FLAME_WIDTH), Feel.COLOR_FLAME)
		draw_colored_polygon(_flame_points(len * Feel.FLAME_CORE_LENGTH, Feel.FLAME_WIDTH * Feel.FLAME_CORE_WIDTH), Feel.COLOR_FLAME_CORE)

	# 연기: 엔진(운전석) 위에서 올라가며 커지고 흐려짐
	var origin := _smoke_origin()
	for puff in _smoke:
		var k := puff.y / Feel.SMOKE_LIFE
		var color := Feel.COLOR_SMOKE
		color.a *= 1.0 - k
		var radius := lerpf(Feel.SMOKE_SIZE.x, Feel.SMOKE_SIZE.y, k)
		draw_circle(origin + Vector2(puff.x * (1.0 + k * 3.0), -Feel.SMOKE_RISE * k), radius, color)
