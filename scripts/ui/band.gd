## 띠: 땅, 왼쪽 물류센터, 오른쪽 집, 트럭, 구석 표시(★·돈·시간당 수익), "+금액".
## 그리기만 한다. 돈 계산은 main.gd → economy.gd
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Truck = preload("res://scripts/ui/truck.gd")

var truck: Truck
var width := 0.0
## 띠 배경을 칠할까. 투명 창(바탕화면 위)에서는 끈다.
var show_background := true

var _hud: HBoxContainer
var _star_label: Label
var _money_label: Label
var _income_label: Label
var _depot_label: Label
var _house_label: Label
var _payouts: Array[Label] = []   ## 떠오르는 중인 "+금액"들


func _ready() -> void:
	truck = Truck.new()
	add_child(truck)

	_hud = HBoxContainer.new()
	_hud.position = Vector2(Feel.DEPOT_X + Feel.DEPOT_SIZE.x + 16, 6)
	_hud.add_theme_constant_override("separation", 18)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_star_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_STAR)
	_money_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_TEXT)
	_income_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_DIM)
	_hud.add_child(_star_label)
	_hud.add_child(_money_label)
	_hud.add_child(_income_label)

	_depot_label = make_label(Feel.LABEL_FONT_SIZE, Feel.COLOR_TEXT)
	_depot_label.text = "물류센터"
	add_child(_depot_label)
	_house_label = make_label(Feel.LABEL_FONT_SIZE, Feel.COLOR_TEXT)
	_house_label.text = "집"
	add_child(_house_label)


## 띠 가로 길이가 정해지면/바뀌면 불림
func layout(w: float) -> void:
	width = w
	var house_x := _house_x()
	var truck_y := Feel.GROUND_Y - Feel.TRUCK_SIZE.y - Feel.WHEEL_RADIUS
	truck.set_track(Feel.DEPOT_X + Feel.DEPOT_SIZE.x + Feel.TRUCK_GAP,
			house_x - Feel.TRUCK_GAP - Feel.TRUCK_SIZE.x, truck_y)
	_depot_label.position = Vector2(Feel.DEPOT_X + 6, Feel.GROUND_Y - Feel.DEPOT_SIZE.y + 4)
	_house_label.position = Vector2(house_x + 14, Feel.GROUND_Y - Feel.HOUSE_SIZE.y + 10)
	queue_redraw()


func set_hud(money: float, hourly: float, star: int) -> void:
	_star_label.text = "★ %d" % star
	_money_label.text = "%s원" % Fmt.money(money)
	_income_label.text = "시간당 %s원" % Fmt.money(hourly)


## 배송 완료: 트럭 위로 "+금액"이 떠올랐다가 사라짐
func show_payout(amount: float) -> void:
	var label := make_label(Feel.PAYOUT_FONT_SIZE, Feel.COLOR_PAYOUT)
	label.text = "+%s" % Fmt.money(amount)
	label.position = truck.position + Vector2(0, -Feel.PAYOUT_FONT_SIZE - 8)
	add_child(label)
	_payouts.append(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - Feel.PAYOUT_RISE, Feel.PAYOUT_DURATION)
	tw.tween_property(label, "modulate:a", 0.0, Feel.PAYOUT_DURATION).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_payouts.erase(label)
		label.queue_free())


## 지금 화면에 보이는 것들의 사각형 (띠 좌표). 투명 창에서는 이것만 그려지고 클릭을 받는다.
## truck_pad_x: 다음 갱신까지 트럭이 움직일 수 있는 거리만큼 옆으로 넉넉하게
func visible_rects(truck_pad_x: float) -> Array:
	var out := []
	var o := float(Feel.TEXT_OUTLINE_SIZE)
	out.append(Rect2(Feel.DEPOT_X, Feel.GROUND_Y - Feel.DEPOT_SIZE.y, Feel.DEPOT_SIZE.x, Feel.DEPOT_SIZE.y).grow(o))
	var hx := _house_x()
	out.append(Rect2(hx - 5, Feel.GROUND_Y - Feel.HOUSE_SIZE.y - 18, Feel.HOUSE_SIZE.x + 10, Feel.HOUSE_SIZE.y + 18))
	out.append(Rect2(_hud.position, _hud.get_combined_minimum_size()).grow(o))
	out.append(Rect2(0, Feel.GROUND_Y, width, 2))
	# 트럭 + 위로 올라가는 연기 자리
	var smoke_up := Feel.SMOKE_RISE + Feel.SMOKE_SIZE.y
	out.append(truck.click_rect().grow_individual(truck_pad_x, smoke_up, truck_pad_x, 0))
	for p in _payouts:
		if is_instance_valid(p):
			out.append(Rect2(p.position, p.get_combined_minimum_size()).grow(o))
	return out


func _draw() -> void:
	if show_background:
		draw_rect(Rect2(0, 0, width, Feel.BAND_HEIGHT), Feel.COLOR_BAND_BG)
	draw_rect(Rect2(0, Feel.GROUND_Y, width, 2), Feel.COLOR_GROUND)
	# 물류센터
	draw_rect(Rect2(Feel.DEPOT_X, Feel.GROUND_Y - Feel.DEPOT_SIZE.y, Feel.DEPOT_SIZE.x, Feel.DEPOT_SIZE.y), Feel.COLOR_DEPOT)
	# 집 (벽 + 지붕)
	var hx := _house_x()
	var hs := Feel.HOUSE_SIZE
	draw_rect(Rect2(hx, Feel.GROUND_Y - hs.y, hs.x, hs.y), Feel.COLOR_HOUSE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(hx - 5, Feel.GROUND_Y - hs.y),
		Vector2(hx + hs.x / 2, Feel.GROUND_Y - hs.y - 18),
		Vector2(hx + hs.x + 5, Feel.GROUND_Y - hs.y),
	]), Feel.COLOR_HOUSE_ROOF)


func _house_x() -> float:
	return width - Feel.HOUSE_MARGIN_RIGHT - Feel.HOUSE_SIZE.x


## 글자 (바탕화면 위에서도 읽히게 테두리를 두름)
static func make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", Feel.TEXT_OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", Feel.COLOR_TEXT_OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
