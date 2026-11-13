## v1 동네: 꼬불꼬불한 길 하나, 길가에 집 TOWN_HOUSES채, 길 끝(시작점)에 물류센터, 트럭,
## 구석 ★·돈, 집 앞 "+금액".
## 동네 설계 좌표(feel.gd TOWN_SIZE = 작은 화면 크기)로 만들고, 전체 화면에서는 같은 동네를 통째로 확대한다.
## 길·집·트럭은 확대해서 그리고(선명함), 글자는 확대 배수에 맞춘 글자 크기로 따로 놓는다.
## 그리기만 한다. 돈 계산은 main.gd → economy.gd
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Truck = preload("res://scripts/ui/truck.gd")
const Route = preload("res://scripts/ui/route.gd")

var truck: Truck
var route: Route
var zoom := 1.0              ## 동네 설계 좌표 → 화면 배수
var origin := Vector2.ZERO   ## 동네 설계 좌표 (0,0)이 이 노드 안 어디에 오나
var text_scale := 1.0        ## 동네 글자 배수 (작은 화면 1, 전체 화면은 확대 배수를 따르되 상한 있음)
var show_ground := false     ## 동네 바닥을 칠할까 (전체 화면에서만. 투명 작은 화면은 바탕화면이 보여야 함)
var jackpots_shown := 0      ## 지금까지 띄운 "대박!" 글자 수 (확인용)

var _houses: Array[Vector2] = []     ## 집 자리 (길 가운데 선 위, 설계 좌표)
var _hud: HBoxContainer
var _star_label: Label
var _money_label: Label
var _depot_label: Label
var _payouts: Array[Label] = []   ## 떠오르는 중인 "+금액"들


func _ready() -> void:
	route = Route.build(PackedVector2Array(Feel.TOWN_ROAD), Feel.TOWN_ROAD_CORNER)
	var stops := PackedFloat64Array()
	for i in mini(Feel.TOWN_HOUSES, Feel.TOWN_HOUSE_SPOTS.size()):
		_houses.append(Feel.TOWN_HOUSE_SPOTS[i])
		stops.append(route.distance_of(Feel.TOWN_HOUSE_SPOTS[i]))
	if _houses.size() < Feel.TOWN_HOUSES:
		push_error("feel.gd: TOWN_HOUSE_SPOTS가 %d개뿐 (TOWN_HOUSES = %d)" % [_houses.size(), Feel.TOWN_HOUSES])

	truck = Truck.new()
	add_child(truck)
	truck.set_route(route, stops)

	_hud = HBoxContainer.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_star_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_STAR)
	_money_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_TEXT)
	_hud.add_child(_star_label)
	_hud.add_child(_money_label)

	_depot_label = make_label(Feel.LABEL_FONT_SIZE, Feel.COLOR_TEXT)
	_depot_label.text = "물류센터"
	add_child(_depot_label)
	layout(Vector2.ZERO, 1.0, 1.0)


## 동네를 어디에 얼마나 크게 놓을지. top_left = 동네 왼쪽 위 (이 노드 좌표), z = 확대 배수
func layout(top_left: Vector2, z: float, text_k: float) -> void:
	origin = top_left
	zoom = z
	text_scale = text_k
	truck.set_view(origin, zoom)

	_hud.add_theme_constant_override("separation", int(roundf(10.0 * text_scale)))
	for l in [_star_label, _money_label]:
		_set_font(l, Feel.HUD_FONT_SIZE)
	_hud.reset_size()
	_hud.position = to_view(Feel.TOWN_HUD_POS)

	_set_font(_depot_label, Feel.LABEL_FONT_SIZE)
	_depot_label.reset_size()
	var depot := view_rect(Feel.TOWN_DEPOT_RECT)
	_depot_label.position = Vector2(depot.get_center().x - _depot_label.size.x / 2.0, depot.position.y + 4.0 * zoom)

	# 떠오르던 "+금액"은 자리가 안 맞게 되니 지운다
	for p in _payouts:
		if is_instance_valid(p):
			p.queue_free()
	_payouts.clear()
	queue_redraw()


## 동네 설계 좌표 → 이 노드 좌표
func to_view(p: Vector2) -> Vector2:
	return origin + p * zoom


func view_rect(r: Rect2) -> Rect2:
	return Rect2(to_view(r.position), r.size * zoom)


## 동네 전체가 차지하는 사각형 (이 노드 좌표)
func area() -> Rect2:
	return view_rect(Rect2(Vector2.ZERO, Feel.TOWN_SIZE))


func set_hud(money: float, star: int) -> void:
	_star_label.text = "★%d" % star
	_money_label.text = "%s원" % Fmt.money(money)


## 성공 연출: ★ 숫자가 커졌다 돌아옴
func pop_star() -> void:
	pop(_star_label)


## 집 앞: "+금액"이 트럭 위로 떠올랐다가 사라짐.
## jackpot_mult > 0 이면 대박 배송: "대박! ×3 +1,234원" (더 크게, 금색, 더 오래)
func show_payout(house: int, amount: float, jackpot_mult := 0.0) -> void:
	var jackpot := jackpot_mult > 0.0
	var font_size := Feel.JACKPOT_FONT_SIZE if jackpot else Feel.PAYOUT_FONT_SIZE
	var label := make_label(font_size, Feel.COLOR_JACKPOT if jackpot else Feel.COLOR_PAYOUT)
	_set_font(label, font_size)
	if jackpot:
		label.text = "대박! ×%s +%s원" % [Fmt.num(jackpot_mult), Fmt.payout(amount)]
		jackpots_shown += 1
	else:
		label.text = "+%s" % Fmt.payout(amount)
	add_child(label)   # 트리에 넣은 뒤에 크기를 재야 글자 폭이 맞음
	label.reset_size()
	var rise := (Feel.JACKPOT_RISE if jackpot else Feel.PAYOUT_RISE) * text_scale
	var seconds := Feel.JACKPOT_DURATION if jackpot else Feel.PAYOUT_DURATION
	var spot := _houses[clampi(house, 0, _houses.size() - 1)]
	var top := to_view(spot) - Vector2(0, Feel.TOWN_HOUSE_SIZE.y + Feel.TOWN_ROOF_HEIGHT) * zoom
	# 동네 밖으로 안 나가게 (작은 화면은 창 = 동네라 밖은 안 보임): 옆으로는 안쪽에, 다 올라가도 위쪽 안에
	var box := area()
	var x := clampf(top.x - label.size.x / 2.0, box.position.x, maxf(box.position.x, box.end.x - label.size.x))
	var y := maxf(top.y - label.size.y, box.position.y + rise)
	label.position = Vector2(x, y)
	_payouts.append(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - rise, seconds)
	tw.tween_property(label, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_payouts.erase(label)
		label.queue_free())


## 떠오르는 중인 "+금액" 수 (확인용)
func payout_count() -> int:
	return _payouts.size()


## 떠오르는 중인 글자들 (확인용)
func payouts() -> Array[Label]:
	return _payouts


## 지금 화면에 보이는 것들의 사각형 (이 노드 좌표). 투명 창에서는 이것만 그려지고 클릭을 받는다.
## truck_pad: 다음 갱신까지 트럭이 움직일 수 있는 거리만큼 넉넉하게
func visible_rects(truck_pad: float) -> Array:
	var out := []
	var o := float(Feel.TEXT_OUTLINE_SIZE) * text_scale
	# 길: 조각(곧은 길·모서리)마다 사각형 하나
	var half := Feel.TOWN_ROAD_WIDTH / 2.0 + 1.0
	for piece in route.pieces:
		out.append(view_rect(piece.grow(half)))
	out.append(view_rect(Feel.TOWN_DEPOT_RECT).grow(1.0))
	out.append(Rect2(_depot_label.position, _depot_label.size).grow(o))
	for spot in _houses:
		out.append(view_rect(_house_rect(spot)).grow(1.0))
	# ★ 숫자가 커졌다 돌아올 때 잘리지 않게 넉넉하게
	var pop_room := Feel.HUD_FONT_SIZE * text_scale * (Feel.STAR_POP_SCALE - 1.0)
	out.append(Rect2(_hud.position, _hud.get_combined_minimum_size()).grow(o + pop_room))
	out.append(truck.click_rect().grow(truck_pad))
	var smoke := truck.smoke_rect()
	if smoke.has_area():
		out.append(smoke.grow(truck_pad))
	for p in _payouts:
		if is_instance_valid(p):
			out.append(Rect2(p.position, p.get_combined_minimum_size()).grow(o))
	return out


## 집 하나가 차지하는 사각형 (설계 좌표): 벽 + 지붕
func _house_rect(spot: Vector2) -> Rect2:
	var s := Feel.TOWN_HOUSE_SIZE
	var bottom := spot.y - Feel.TOWN_ROAD_WIDTH / 2.0 - 1.0
	var ov := Feel.TOWN_ROOF_OVERHANG
	return Rect2(spot.x - s.x / 2.0 - ov, bottom - s.y - Feel.TOWN_ROOF_HEIGHT, s.x + ov * 2.0, s.y + Feel.TOWN_ROOF_HEIGHT)


func _draw() -> void:
	# 동네 설계 좌표로 그린다 (확대는 변환으로. 도형이라 확대해도 선명함)
	draw_set_transform(origin, 0.0, Vector2.ONE * zoom)
	if show_ground:
		draw_rect(Rect2(Vector2.ZERO, Feel.TOWN_SIZE), Feel.COLOR_TOWN_GROUND)

	# 물류센터 (길 시작점 뒤)
	var d := Feel.TOWN_DEPOT_RECT
	draw_rect(d, Feel.COLOR_DEPOT)
	draw_rect(Rect2(d.end.x - d.size.x * 0.45, d.end.y - d.size.y * 0.45, d.size.x * 0.35, d.size.y * 0.45), Feel.COLOR_ROAD_EDGE)

	# 집 (벽 + 지붕 + 문). 길보다 먼저 그려서 길 뒤에 선 것처럼
	var hs := Feel.TOWN_HOUSE_SIZE
	for spot in _houses:
		var r := _house_rect(spot)
		var ov := Feel.TOWN_ROOF_OVERHANG
		var wall := Rect2(r.position.x + ov, r.end.y - hs.y, hs.x, hs.y)
		draw_rect(wall, Feel.COLOR_HOUSE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x, wall.position.y),
			Vector2(r.get_center().x, r.position.y),
			Vector2(r.end.x, wall.position.y),
		]), Feel.COLOR_HOUSE_ROOF)
		draw_rect(Rect2(wall.get_center().x - hs.x * 0.15, wall.end.y - hs.y * 0.55, hs.x * 0.3, hs.y * 0.55), Feel.COLOR_DOOR)

	# 꼬불길: 테두리(어두운 색) 위에 길(밝은 색). 끝은 둥글게
	var w := Feel.TOWN_ROAD_WIDTH
	var pts := route.points
	draw_polyline(pts, Feel.COLOR_ROAD_EDGE, w, true)
	draw_circle(pts[pts.size() - 1], w / 2.0, Feel.COLOR_ROAD_EDGE, true, -1.0, true)
	draw_polyline(pts, Feel.COLOR_ROAD, w - 3.0, true)
	draw_circle(pts[pts.size() - 1], (w - 3.0) / 2.0, Feel.COLOR_ROAD, true, -1.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _set_font(l: Label, base: int) -> void:
	l.add_theme_font_size_override("font_size", maxi(1, int(roundf(base * text_scale))))
	l.add_theme_constant_override("outline_size", maxi(1, int(roundf(Feel.TEXT_OUTLINE_SIZE * text_scale))))


## 글자를 커졌다 돌아오게 (garage_panel.gd 제목, 튜닝 등급 글자에도 씀)
## pivot: 어디를 기준으로 커지나 (0.5, 0.5 = 가운데, 0, 0.5 = 왼쪽 끝에서 오른쪽으로)
static func pop(c: Control, pivot := Vector2(0.5, 0.5), k := Feel.STAR_POP_SCALE,
		seconds := Feel.STAR_POP_DURATION) -> void:
	c.pivot_offset_ratio = pivot
	c.scale = Vector2.ONE * k
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, seconds) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 글자 (바탕화면 위에서도 읽히게 테두리를 두름)
static func make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", Feel.TEXT_OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", Feel.COLOR_TEXT_OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
