## click_region.gd: 여러 사각형 → 클릭 받는 다각형 하나
## Windows와 같은 규칙(변을 넘은 횟수가 홀수면 안)으로 안/밖을 확인한다.
extends "res://tests/test_base.gd"

const ClickRegion = preload("res://scripts/ui/click_region.gd")

const H := 400.0


func _inside(poly: PackedVector2Array, pt: Vector2) -> bool:
	return ClickRegion.contains_even_odd(poly, pt)


func test_separate_rects() -> void:
	var rects := [Rect2(10, 300, 60, 50), Rect2(500, 340, 40, 20), Rect2(100, 280, 200, 20)]
	var poly := ClickRegion.build(rects, H)
	for r: Rect2 in rects:
		check(_inside(poly, r.get_center()), "사각형 %s 가운데가 밖으로 나옴" % r)
	for pt in [Vector2(5, 100), Vector2(400, 300), Vector2(90, 330), Vector2(800, 390), Vector2(320, 290)]:
		check(not _inside(poly, pt), "빈 곳 %s 가 클릭 영역에 들어감" % pt)


func test_overlapping_rects_stay_filled() -> void:
	# 겹친 곳이 구멍으로 빠지면 안 됨 (트럭이 집 앞에 섰을 때, +금액이 트럭과 겹칠 때)
	var rects := [Rect2(100, 300, 100, 60), Rect2(150, 320, 100, 60), Rect2(160, 330, 20, 20)]
	var poly := ClickRegion.build(rects, H)
	for pt in [Vector2(120, 310), Vector2(170, 340), Vector2(230, 370), Vector2(175, 345)]:
		check(_inside(poly, pt), "겹친 사각형 안 %s 가 밖으로 나옴" % pt)
	check(not _inside(poly, Vector2(230, 305)), "두 사각형 사이 빈 모서리가 들어감")


func test_rect_above_another_corridor_is_thin() -> void:
	# 위 사각형의 통로가 아래 사각형을 지나가도 아래 사각형은 그대로 차 있어야 함
	var rects := [Rect2(100, 100, 50, 30), Rect2(80, 300, 120, 40)]
	var poly := ClickRegion.build(rects, H)
	check(_inside(poly, Vector2(125, 115)), "위 사각형 안이 밖으로 나옴")
	for x in [85.0, 99.0, 101.0, 120.0, 195.0]:
		check(_inside(poly, Vector2(x, 320)), "아래 사각형 안 (%s, 320) 이 밖으로 나옴" % x)
	check(not _inside(poly, Vector2(101, 200)), "통로 옆 빈 곳이 들어감")


func test_empty_gives_one_pixel() -> void:
	var poly := ClickRegion.build([], H)
	check_eq(poly.size(), 4, "빈 목록이면 1픽셀 사각형")
	check(not _inside(poly, Vector2(200, 200)), "빈 목록인데 창 가운데가 들어감")
