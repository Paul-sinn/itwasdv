## 동네 꼬불길 모양 계산. 노드 없이 돌아가서 테스트할 수 있다 (tests/test_route.gd).
## - 가로·세로로 꺾인 점들 → 모서리를 둥글게 깎은 길 (잘게 나눈 점들)
## - 길 위 거리 ↔ 점 (트럭이 길을 따라 움직일 때)
## - 길 조각(곧은 길, 모서리)마다 가운데 선을 덮는 사각형 (투명 창에서 "보이는 곳" 만들 때)
## 좌표는 전부 동네 설계 좌표 (feel.gd TOWN_SIZE 기준)
extends RefCounted

const ARC_STEPS := 8   ## 둥근 모서리 하나를 몇 토막으로 나눠 그리나

var points := PackedVector2Array()    ## 길 가운데 선 (처음 → 끝)
var lengths := PackedFloat64Array()   ## lengths[i] = 처음부터 points[i]까지 길 따라 거리
var pieces: Array[Rect2] = []         ## 길 조각마다 가운데 선을 덮는 사각형 (길 폭은 안 넣음)


## corners: 길이 꺾이는 점들 (처음, 꺾이는 곳들, 끝). 이웃한 두 점은 가로나 세로로 나란해야 한다.
## radius: 모서리를 깎는 반지름 (토막이 짧으면 토막 길이의 절반까지만)
static func build(corners: PackedVector2Array, radius: float) -> RefCounted:
	var r = new()
	if corners.size() < 2:
		r.points = corners.duplicate()
		r._measure()
		return r
	var cur := corners[0]
	r.points.append(cur)
	for i in range(1, corners.size()):
		var c := corners[i]
		if i == corners.size() - 1:
			r.pieces.append(_span(cur, c))
			r.points.append(c)
			break
		var d_in := (c - corners[i - 1]).normalized()
		var d_out := (corners[i + 1] - c).normalized()
		var rad := minf(radius, minf(c.distance_to(corners[i - 1]), c.distance_to(corners[i + 1])) / 2.0)
		var a := c - d_in * rad   # 모서리가 시작하는 곳
		var b := c + d_out * rad  # 모서리가 끝나는 곳
		r.pieces.append(_span(cur, a))
		r.points.append(a)
		# 직각 모서리: 중심 = a에서 나가는 쪽으로 rad만큼. 호는 a와 b가 만드는 사각형 안에 다 들어간다
		var center := a + d_out * rad
		var v0 := a - center
		var sweep := v0.angle_to(b - center)
		for k in range(1, ARC_STEPS + 1):
			r.points.append(center + v0.rotated(sweep * k / ARC_STEPS))
		r.pieces.append(_span(a, b))
		cur = b
	r._measure()
	return r


static func _span(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(a, Vector2.ZERO).expand(b)


func _measure() -> void:
	lengths.resize(points.size())
	var sum := 0.0
	for i in points.size():
		if i > 0:
			sum += points[i - 1].distance_to(points[i])
		lengths[i] = sum


## 길 전체 길이
func total() -> float:
	return lengths[lengths.size() - 1] if lengths.size() > 0 else 0.0


## 처음에서 길 따라 s만큼 간 곳 (0 ~ total 밖이면 양 끝)
func point_at(s: float) -> Vector2:
	var i := _segment_at(s)
	if i < 0:
		return points[0] if points.size() > 0 else Vector2.ZERO
	var seg := lengths[i + 1] - lengths[i]
	var t := 0.0 if seg <= 0.0 else clampf((s - lengths[i]) / seg, 0.0, 1.0)
	return points[i].lerp(points[i + 1], t)


## s 위치에서 길이 나아가는 방향 (처음 → 끝 쪽, 길이 1)
func direction_at(s: float) -> Vector2:
	var i := _segment_at(s)
	if i < 0:
		return Vector2.RIGHT
	# 길이 0인 토막이면 앞뒤로 길이 있는 토막을 찾는다
	for j in range(i, points.size() - 1):
		if points[j + 1] != points[j]:
			return (points[j + 1] - points[j]).normalized()
	for j in range(i, 0, -1):
		if points[j] != points[j - 1]:
			return (points[j] - points[j - 1]).normalized()
	return Vector2.RIGHT


## 점 p에서 가장 가까운 길 위 지점이 처음에서 길 따라 얼마나 떨어져 있나
func distance_of(p: Vector2) -> float:
	var best := INF
	var best_s := 0.0
	for i in points.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		var d := p.distance_squared_to(q)
		if d < best:
			best = d
			best_s = lengths[i] + points[i].distance_to(q)
	return best_s


## s가 들어 있는 토막 번호 (points[i] ~ points[i+1]). 점이 2개보다 적으면 -1
func _segment_at(s: float) -> int:
	var n := points.size()
	if n < 2:
		return -1
	var i := lengths.bsearch(s, false) - 1   # lengths[i] <= s 인 마지막 i
	return clampi(i, 0, n - 2)
