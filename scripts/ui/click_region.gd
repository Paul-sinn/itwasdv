## 투명 창의 "클릭 받는 영역" 만들기.
##
## Godot 4.6.3 + Windows에서 직접 확인한 것:
##   - 창 전체 클릭 통과(Window.mouse_passthrough)는 다른 프로그램으로 클릭이 안 넘어감
##   - 다각형 하나(mouse_passthrough_polygon)를 주면 그 안만 클릭을 받고 밖은 뒤 창으로 넘어감
##   - 대신 다각형 밖은 그려지지도 않음 → "보이는 것 = 클릭 받는 곳"
## 그래서 보이는 것들의 사각형을 모아 다각형 "하나"로 이어 붙인다.
##
## 이어 붙이는 법: 겹치는 사각형은 먼저 합치고(겹친 채 두면 Windows가 겹친 곳을 구멍으로 침),
## 각 덩어리를 창 맨 아래에서 폭 0짜리 통로로 올라갔다 내려오며 한 붓 그리기로 잇는다.
extends RefCounted

const GROW := 1.0   ## 딱 붙어 있는 사각형도 합쳐지게 살짝 키움


## rects(창 좌표)를 모두 덮는 다각형 하나. bottom = 창 아래 끝 y
static func build(rects: Array, bottom: float) -> PackedVector2Array:
	var shapes: Array[PackedVector2Array] = []
	for r: Rect2 in rects:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var g := r.grow(GROW)
		shapes.append(PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]))
	shapes = _union_all(shapes)
	if shapes.is_empty():
		# 빈 다각형을 주면 Godot이 "창 전체가 클릭 받음"으로 처리함 → 1픽셀만
		return PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])

	# 덩어리마다 가장 아래 점에서 창 바닥으로 통로를 낸다. 통로 x 순서대로 잇는다.
	var entries := []
	for s in shapes:
		var k := _lowest_index(s)
		entries.append({ "shape": s, "start": k, "x": s[k].x })
	entries.sort_custom(func(a, b): return a["x"] < b["x"])

	var out := PackedVector2Array()
	for e in entries:
		var s: PackedVector2Array = e["shape"]
		var k: int = e["start"]
		out.append(Vector2(s[k].x, bottom))
		for i in s.size() + 1:
			out.append(s[(k + i) % s.size()])
		out.append(Vector2(s[k].x, bottom))
	return out


## 겹치는 덩어리끼리 합친다 (합친 결과에 구멍이 생기면 메워서 바깥 테두리만 남김)
static func _union_all(shapes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var merged := true
	while merged:
		merged = false
		for i in shapes.size():
			for j in range(i + 1, shapes.size()):
				if Geometry2D.intersect_polygons(shapes[i], shapes[j]).is_empty():
					continue
				var outer := _largest(Geometry2D.merge_polygons(shapes[i], shapes[j]))
				shapes.remove_at(j)
				shapes[i] = outer
				merged = true
				break
			if merged:
				break
	return shapes


static func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for p: PackedVector2Array in polys:
		var a := absf(_area(p))
		if a > best_area:
			best_area = a
			best = p
	return best


static func _area(p: PackedVector2Array) -> float:
	var sum := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## 가장 아래(y가 가장 큰) 점. 같으면 왼쪽
static func _lowest_index(p: PackedVector2Array) -> int:
	var k := 0
	for i in p.size():
		if p[i].y > p[k].y or (p[i].y == p[k].y and p[i].x < p[k].x):
			k = i
	return k


## Windows(ALTERNATE)와 같은 규칙으로 점이 안에 있나: 오른쪽으로 반직선을 그어 변을 몇 번 넘나 (홀수면 안)
static func contains_even_odd(poly: PackedVector2Array, pt: Vector2) -> bool:
	var inside := false
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if (a.y > pt.y) != (b.y > pt.y):
			var x := a.x + (pt.y - a.y) / (b.y - a.y) * (b.x - a.x)
			if pt.x < x:
				inside = not inside
	return inside
