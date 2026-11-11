## route.gd: 꼬불길 모양 (둥근 모서리, 길 위 거리 ↔ 점, 길을 덮는 사각형)
extends "res://tests/test_base.gd"

const Route = preload("res://scripts/ui/route.gd")
const Feel = preload("res://scripts/ui/feel.gd")


func _town_route() -> Route:
	return Route.build(PackedVector2Array(Feel.TOWN_ROAD), Feel.TOWN_ROAD_CORNER)


## ㄱ자 길 하나: 길이 = 곧은 길 두 개 + 4분의 1 원
func test_l_shape_length() -> void:
	var r := Route.build(PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)]), 20.0)
	var want := 80.0 + 80.0 + PI * 20.0 / 2.0
	check_near(r.total(), want, 0.3, "ㄱ자 길 길이 (모서리를 잘게 나눠서 아주 조금 짧음)")
	check_eq(r.pieces.size(), 3, "조각 수 (곧은 길 2 + 모서리 1)")
	check_eq(r.point_at(0.0), Vector2(0, 0), "처음")
	check(r.point_at(r.total()).distance_to(Vector2(100, 100)) < 0.01, "끝")
	check(r.point_at(-5.0) == Vector2(0, 0) and r.point_at(r.total() + 5.0).distance_to(Vector2(100, 100)) < 0.01, "범위 밖은 양 끝")
	check_eq(r.direction_at(10.0), Vector2.RIGHT, "처음 방향")
	check(r.direction_at(r.total() - 1.0).distance_to(Vector2.DOWN) < 0.01, "끝 방향")


## 길 위 점 → 거리 → 점 이 되돌아오나 (트럭이 집 자리를 찾을 때 씀)
func test_distance_round_trip() -> void:
	var r := _town_route()
	var worst := 0.0
	var s := 0.0
	while s <= r.total():
		worst = maxf(worst, absf(r.distance_of(r.point_at(s)) - s))
		s += 7.3
	check(worst < 0.01, "길 위 거리 되돌리기 오차 %.4f" % worst)


## 동네 길: 집 자리가 길 위에 있고, 물류센터에서 가까운 순서
func test_town_house_spots() -> void:
	var r := _town_route()
	check(Feel.TOWN_HOUSE_SPOTS.size() >= Feel.TOWN_HOUSES, "집 자리 수 %d < 집 수 %d" % [Feel.TOWN_HOUSE_SPOTS.size(), Feel.TOWN_HOUSES])
	var last := 0.0
	for i in Feel.TOWN_HOUSES:
		var spot: Vector2 = Feel.TOWN_HOUSE_SPOTS[i]
		var s := r.distance_of(spot)
		check(r.point_at(s).distance_to(spot) < 0.5, "집%d 자리 %s 가 길 위에 없음" % [i + 1, spot])
		check(s > last, "집%d가 앞 집보다 물류센터에서 가깝지 않음" % (i + 1))
		last = s
	check(last <= r.total(), "마지막 집이 길 끝 너머")
	note("동네 길 길이 %.0f, 마지막 집까지 %.0f, 조각 %d개" % [r.total(), last, r.pieces.size()])


## 길 조각 사각형(길 폭만큼 키움)이 길 전체를 빈틈없이 덮나 (투명 창에서 안 덮인 곳은 안 그려짐)
func test_pieces_cover_road() -> void:
	var r := _town_route()
	var half := Feel.TOWN_ROAD_WIDTH / 2.0
	var missed := 0
	var s := 0.0
	while s <= r.total():
		var p := r.point_at(s)
		var n := r.direction_at(s).orthogonal()
		for off in [-half, 0.0, half]:
			var q: Vector2 = p + n * off
			var inside := false
			for piece: Rect2 in r.pieces:
				if piece.grow(half + 1.0).has_point(q):
					inside = true
					break
			if not inside:
				missed += 1
		s += 1.0
	check_eq(missed, 0, "사각형 밖으로 나간 길 점 수")
	check(r.pieces.size() <= 12, "길 조각이 너무 많음: %d" % r.pieces.size())


## 동네 길이 동네 크기(작은 화면) 안에 다 들어가나
func test_town_road_inside_town() -> void:
	var r := _town_route()
	var area := Rect2(Vector2.ZERO, Feel.TOWN_SIZE)
	for piece: Rect2 in r.pieces:
		var g := piece.grow(Feel.TOWN_ROAD_WIDTH / 2.0)
		check(area.encloses(g), "길 조각 %s 가 동네 밖으로 나감" % g)
	check(area.encloses(Feel.TOWN_DEPOT_RECT), "물류센터가 동네 밖으로 나감")
