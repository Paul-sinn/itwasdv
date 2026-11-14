## v1 동네: 꼬불꼬불한 길 하나, 길가에 집 TOWN_HOUSES채, 길 끝(시작점)에 물류센터, 트럭,
## 구석 강화 단계("+N")·돈·기사 레벨("Lv.N") + 그 아래 "다음 할 일" 한 줄, 집 앞 "+금액"·"스페어 엔진 +1", 트럭 위 "오버부스트!",
## 오른쪽 위 알림(할 일 끝·레벨업 등. 여러 개면 하나씩 차례로).
## v6a: 건물 세 개(물류센터·튜닝숍·카센터, 임시 사각형 + 간판). 마우스를 올리면 빛남 + 이름표.
##      구석 줄 끝 작은 버튼 [강화] → tuning_pressed. 건물 클릭은 main.gd가 building_at()으로 가른다
## v6-bal: 처음 켰을 때 말풍선 "건물을 눌러보세요" (hint, set_hint. 언제 켜나는 main.gd)
## v5b: 팁이 나오면 "+금액" 옆에 "팁! +금액" (show_tip), 찍을 능력치 포인트가 남으면 레벨 옆 점 (set_point_dot)
## v6b: 대형·VIP·급송 "+금액"은 앞 글자·색이 다름 (show_payout), 급송 전화 말풍선 [받기] + 남은 시간 막대,
##      받은 뒤 구석 줄 "급송 N건 남음" (set_rush. 언제 울리나는 main.gd → Rush)
## v7a: 보조 트럭도 같은 길을 같은 그림(짐칸 색만 다르게)으로 달림 (trucks, set_truck_count. 0 = 내 트럭 = truck)
##      U2: 창업하면 네 번째 건물 사무실 (set_office. 창업 전에는 그리지도, building_rects에 넣지도 않음),
##      구석 줄 "시내 N위" (set_rank. 누르면 아무 일 없음)
## v7-bal: 오른쪽 위 아이콘 (town_icon.gd): 편지봉투 + 느낌표 (NPC가 온 날, set_letter → letter_pressed),
##      급송 전화는 말풍선 대신 전화 아이콘 (누르면 rush_accept_pressed. 아래 남은 시간 막대). 알림은 아이콘 왼쪽에
## 동네 설계 좌표(feel.gd TOWN_SIZE = 작은 화면 크기)로 만들고, 전체 화면에서는 같은 동네를 통째로 확대한다.
## 길·집·트럭은 확대해서 그리고(선명함), 글자는 확대 배수에 맞춘 글자 크기로 따로 놓는다.
## 그리기만 한다. 돈·배송은 main.gd → scripts/core/trip.gd (배송 이벤트가 오면 show_payout)
extends Node2D

const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Truck = preload("res://scripts/ui/truck.gd")
const Route = preload("res://scripts/ui/route.gd")
const TownIcon = preload("res://scripts/ui/town_icon.gd")

## 건물 id (큰 화면 위쪽 줄 순서)와 이름 번역 키. 사무실(OFFICE)은 창업 뒤에만 있어서 BUILDINGS에 안 넣음
const BUILDINGS := ["tuning", "depot", "car_center"]
const OFFICE := "office"
const BUILDING_NAMES := { "tuning": "BUILDING_TUNING", "depot": "TOWN_DEPOT", "car_center": "BUILDING_CAR_CENTER", "office": "BUILDING_OFFICE" }
## 건물 자리 (동네 설계 좌표)와 색. 사무실은 창업 뒤에만
const BUILDING_SPOTS := { "tuning": Feel.TOWN_TUNING_RECT, "depot": Feel.TOWN_DEPOT_RECT, "car_center": Feel.TOWN_CAR_CENTER_RECT, "office": Feel.TOWN_OFFICE_RECT }
const BUILDING_COLORS := { "tuning": Feel.COLOR_TUNING, "depot": Feel.COLOR_DEPOT, "car_center": Feel.COLOR_CAR_CENTER, "office": Feel.COLOR_OFFICE }

signal tuning_pressed   ## 구석 작은 버튼 [강화]
signal rush_accept_pressed   ## 급송 전화 아이콘
signal letter_pressed        ## 편지봉투 아이콘

## 대형·VIP "+금액" 앞 글자 번역 키와 색 (배송 이벤트의 kind. "normal"은 글자 없음)
const PAY_KEYS := { "large": "TOWN_PAY_LARGE", "vip": "TOWN_PAY_VIP" }
const PAY_COLORS := { "large": Feel.COLOR_PAYOUT_LARGE, "vip": Feel.COLOR_PAYOUT_VIP }

var truck: Truck              ## 내 트럭 (= trucks[0])
var trucks: Array[Truck] = []   ## 띠의 트럭들, 계산 쪽 트럭 번호 순 (1~ = 보조 트럭)
var route: Route
var zoom := 1.0              ## 동네 설계 좌표 → 화면 배수
var origin := Vector2.ZERO   ## 동네 설계 좌표 (0,0)이 이 노드 안 어디에 오나
var text_scale := 1.0        ## 동네 글자 배수 (작은 화면 1, 전체 화면은 확대 배수를 따르되 상한 있음)
var show_ground := false     ## 동네 바닥을 칠할까 (전체 화면에서만. 투명 작은 화면은 바탕화면이 보여야 함)
var payouts_shown := 0       ## 지금까지 띄운 "+금액" 수 (확인용)
var spares_shown := 0        ## 지금까지 띄운 "스페어 엔진 +1" 수 (확인용)
var boosts_shown := 0        ## 지금까지 띄운 "오버부스트!" 수 (확인용)
var tips_shown: Array[String] = []   ## 지금까지 띄운 "팁! +금액" 글자 (확인용)
var payout_log: Array = []   ## 지금까지 띄운 "+금액"마다 [트럭 번호, 금액] (확인용)
var point_dot: Panel         ## 구석 줄 레벨 옆 점: 찍을 능력치 포인트가 남음 (set_point_dot)
var rush_button: TownIcon     ## 급송 전화 아이콘 + 남은 시간 막대 (벨이 울리는 동안. 누르면 받음)
var letter_button: TownIcon   ## 편지봉투 + 느낌표 (NPC가 온 날. set_letter)
var notices_shown: Array[String] = []   ## 지금까지 띄운 알림 글자, 띄운 순서대로 (확인용)
var hovered := ""            ## 마우스가 올라가 있는 건물 id ("" = 없음)
var tuning_button: Button    ## 구석 줄 끝 작은 버튼 [강화]
var hint: Label              ## 처음 켰을 때 말풍선 "건물을 눌러보세요" (켜고 끄기는 main.gd → set_hint)
var master_visit := false    ## 명장 방문 중 → 튜닝숍에 색 테두리 (set_master_visit)
var office_open := false     ## 사무실 건물이 있나 (창업 뒤. set_office)

var _houses: Array[Vector2] = []     ## 집 자리 (길 가운데 선 위, 설계 좌표)
var _stops := PackedFloat64Array()   ## 집마다 길 위 거리 (트럭이 서는 곳)
var _hud: HBoxContainer
var _star_label: Label
var _money_label: Label
var _level_label: Label
var _quest_label: Label   ## "다음 할 일: 배송 20건 3/20"
var _notice: Label        ## 지금 떠 있는 알림 (하나만)
var _notice_queue: Array[String] = []   ## 차례를 기다리는 알림
var _signs := {}          ## 건물 id → 간판 글자
var _name_tag: Label      ## 마우스 올린 건물 위 이름표
var _payouts: Array[Label] = []   ## 떠오르는 중인 "+금액"·"스페어 엔진 +1"들
var _last_payout: Label   ## 마지막 "+금액" (팁이 오면 그 옆에 "팁!"을 붙임)
var _dot_style: StyleBoxFlat
var _rush_left: Label     ## 구석 줄 끝 "급송 N건 남음" (받은 급송이 남아 있을 때)
var _rank_label: Label    ## 구석 줄 "시내 N위" (창업 뒤)


func _ready() -> void:
	route = Route.build(PackedVector2Array(Feel.TOWN_ROAD), Feel.TOWN_ROAD_CORNER)
	for i in mini(Feel.TOWN_HOUSES, Feel.TOWN_HOUSE_SPOTS.size()):
		_houses.append(Feel.TOWN_HOUSE_SPOTS[i])
		_stops.append(route.distance_of(Feel.TOWN_HOUSE_SPOTS[i]))
	if _houses.size() < Feel.TOWN_HOUSES:
		push_error("feel.gd: TOWN_HOUSE_SPOTS가 %d개뿐 (TOWN_HOUSES = %d)" % [_houses.size(), Feel.TOWN_HOUSES])

	truck = Truck.new()
	add_child(truck)
	truck.set_route(route, _stops)
	trucks.append(truck)

	_hud = HBoxContainer.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_star_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_STAR)
	_money_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_TEXT)
	_level_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_LEVEL)
	_hud.add_child(_star_label)
	_hud.add_child(_money_label)
	_hud.add_child(_level_label)
	point_dot = Panel.new()   # 둥근 바탕 = 점 (글꼴에 ● 가 없어도 보이게)
	point_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	point_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot_style = StyleBoxFlat.new()
	_dot_style.bg_color = Feel.COLOR_POINT_DOT
	point_dot.add_theme_stylebox_override("panel", _dot_style)
	point_dot.visible = false
	_hud.add_child(point_dot)
	_rank_label = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_RANK)
	_rank_label.visible = false
	_hud.add_child(_rank_label)
	tuning_button = Button.new()
	tuning_button.text = tr("TOWN_TUNING_BUTTON")
	tuning_button.focus_mode = Control.FOCUS_NONE
	tuning_button.add_theme_color_override("font_color", Feel.COLOR_TEXT)
	tuning_button.add_theme_color_override("font_hover_color", Feel.COLOR_TEXT)
	tuning_button.add_theme_color_override("font_pressed_color", Feel.COLOR_TEXT)
	tuning_button.pressed.connect(func(): tuning_pressed.emit())
	_hud.add_child(tuning_button)
	_rush_left = make_label(Feel.HUD_FONT_SIZE, Feel.COLOR_RUSH_LEFT)
	_rush_left.visible = false
	_hud.add_child(_rush_left)
	_quest_label = make_label(Feel.QUEST_FONT_SIZE, Feel.COLOR_QUEST)
	add_child(_quest_label)
	_notice = make_label(Feel.NOTICE_FONT_SIZE, Feel.COLOR_NOTICE)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice.visible = false
	add_child(_notice)

	for id: String in BUILDING_SPOTS:
		var board := make_label(Feel.LABEL_FONT_SIZE, Feel.COLOR_TEXT)
		board.text = tr(BUILDING_NAMES[id])
		board.visible = id != OFFICE
		add_child(board)
		_signs[id] = board
	_name_tag = make_label(Feel.NAME_TAG_FONT_SIZE, Feel.COLOR_NAME_TAG)
	_name_tag.visible = false
	add_child(_name_tag)
	hint = Label.new()
	hint.text = tr("TOWN_HINT_BUILDING")
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 말풍선을 눌러도 아무 일 없음 (건물·작은 버튼만)
	hint.add_theme_color_override("font_color", Feel.COLOR_HINT_TEXT)
	hint.visible = false
	add_child(hint)
	rush_button = TownIcon.new("phone")
	rush_button.pressed.connect(func(): rush_accept_pressed.emit())
	add_child(rush_button)
	letter_button = TownIcon.new("letter")
	letter_button.pressed.connect(func(): letter_pressed.emit())
	add_child(letter_button)
	layout(Vector2.ZERO, 1.0, 1.0)


## 동네를 어디에 얼마나 크게 놓을지. top_left = 동네 왼쪽 위 (이 노드 좌표), z = 확대 배수
func layout(top_left: Vector2, z: float, text_k: float) -> void:
	origin = top_left
	zoom = z
	text_scale = text_k
	for t in trucks:
		t.set_view(origin, zoom)

	_hud.add_theme_constant_override("separation", int(roundf(10.0 * text_scale)))
	for l in [_star_label, _money_label, _level_label, _rush_left, _rank_label]:
		_set_font(l, Feel.HUD_FONT_SIZE)
	_style_button()
	var d := Feel.POINT_DOT_SIZE * text_scale
	point_dot.custom_minimum_size = Vector2(d, d)
	_dot_style.set_corner_radius_all(int(ceilf(d / 2.0)))
	_hud.reset_size()
	_hud.position = to_view(Feel.TOWN_HUD_POS)
	_set_font(_quest_label, Feel.QUEST_FONT_SIZE)
	_quest_label.reset_size()
	_quest_label.position = to_view(Feel.TOWN_QUEST_POS)
	_set_font(_notice, Feel.NOTICE_FONT_SIZE)
	_place_icons()

	# 간판: 건물 위쪽 가운데 (사무실은 창업 전에도 자리만 잡아 둠)
	for id: String in _signs:
		var board: Label = _signs[id]
		_set_font(board, Feel.LABEL_FONT_SIZE)
		board.reset_size()
		var r := view_rect(BUILDING_SPOTS[id])
		board.position = Vector2(r.get_center().x - board.size.x / 2.0, r.position.y + Feel.SIGN_TOP * zoom)
	_set_font(_name_tag, Feel.NAME_TAG_FONT_SIZE)
	_place_name_tag()
	_place_hint()

	# 떠오르던 "+금액"은 자리가 안 맞게 되니 지운다
	for p in _payouts:
		if is_instance_valid(p):
			p.queue_free()
	_payouts.clear()
	queue_redraw()


## 띠의 트럭 수를 계산 쪽 트럭 수에 맞춤 (보조 트럭을 사면 늘고, F3 처음부터면 줄어듦).
## 보조 트럭은 내 트럭 바로 밑에 그림 (글자·내 트럭을 가리지 않게)
func set_truck_count(n: int) -> void:
	while trucks.size() < n:
		var t := Truck.new()
		t.box_color = Feel.HELPER_TRUCK_COLORS[(trucks.size() - 1) % Feel.HELPER_TRUCK_COLORS.size()]
		add_child(t)
		move_child(t, truck.get_index())
		t.set_route(route, _stops)
		t.set_view(origin, zoom)
		trucks.append(t)
	while trucks.size() > maxi(n, 1):
		trucks.pop_back().queue_free()


## 동네 설계 좌표 → 이 노드 좌표
func to_view(p: Vector2) -> Vector2:
	return origin + p * zoom


func view_rect(r: Rect2) -> Rect2:
	return Rect2(to_view(r.position), r.size * zoom)


## 동네 전체가 차지하는 사각형 (이 노드 좌표)
func area() -> Rect2:
	return view_rect(Rect2(Vector2.ZERO, Feel.TOWN_SIZE))


## 건물 id → 건물 사각형 (이 노드 좌표. 작은 화면에서는 창 좌표와 같음). 클릭·마우스 올림·보이는 곳이 같이 씀.
## 사무실은 창업 뒤에만 (office_open)
func building_rects() -> Dictionary:
	var out := {}
	for id: String in BUILDING_SPOTS:
		if id != OFFICE or office_open:
			out[id] = view_rect(BUILDING_SPOTS[id])
	return out


## 사무실 건물 켜고 끄기 (main.gd: 대리점이면 켬. F3 처음부터면 꺼짐)
func set_office(on: bool) -> void:
	if office_open == on:
		return
	office_open = on
	_signs[OFFICE].visible = on
	if not on and hovered == OFFICE:
		set_hover("")
	queue_redraw()


## 구석 줄 "시내 N위" (rank 0 = 대리점 전 → 숨김)
func set_rank(rank: int) -> void:
	_rank_label.visible = rank > 0
	if rank > 0:
		_rank_label.text = tr("TOWN_RANK") % rank


## p(이 노드 좌표)에 있는 건물 id. 없으면 ""
func building_at(p: Vector2) -> String:
	var rects := building_rects()
	for id: String in rects:
		if rects[id].has_point(p):
			return id
	return ""


## 마우스를 올린 건물: 빛남 + 이름표 ("" = 끔)
func set_hover(id: String) -> void:
	if id == hovered:
		return
	hovered = id
	_name_tag.visible = id != ""
	if id != "":
		_name_tag.text = tr(BUILDING_NAMES[id])
		_place_name_tag()
	queue_redraw()


## 이름표: 건물 바로 위 가운데. 동네 밖으로는 안 나감
func _place_name_tag() -> void:
	if hovered == "":
		return
	_name_tag.reset_size()
	var r: Rect2 = building_rects()[hovered]
	var box := area()
	var x := clampf(r.get_center().x - _name_tag.size.x / 2.0, box.position.x, box.end.x - _name_tag.size.x)
	var y := maxf(box.position.y, r.position.y - _name_tag.size.y - Feel.NAME_TAG_GAP * zoom)
	_name_tag.position = Vector2(x, y)


## 처음 말풍선 켜고 끄기 (main.gd: 작은 화면이고 아직 건물을 안 눌렀을 때만 켬)
## 명장 방문 중이면 튜닝숍 둘레에 색 테두리 (빛남 두께 안이라 보이는 곳 사각형은 그대로)
func set_master_visit(on: bool) -> void:
	if master_visit != on:
		master_visit = on
		queue_redraw()


func set_hint(on: bool) -> void:
	if hint.visible != on:
		hint.visible = on
		queue_redraw()   # 꼬리


## 말풍선: 글자 크기·여백·둥글기를 동네 글자 배수에 맞추고, 위쪽 가운데를 HINT_POS에
func _place_hint() -> void:
	hint.add_theme_font_size_override("font_size", maxi(1, int(roundf(Feel.HINT_FONT_SIZE * text_scale))))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Feel.COLOR_HINT_BG
	sb.set_corner_radius_all(int(roundf(Feel.HINT_RADIUS * text_scale)))
	sb.content_margin_left = Feel.HINT_PAD.x * text_scale
	sb.content_margin_right = Feel.HINT_PAD.x * text_scale
	sb.content_margin_top = Feel.HINT_PAD.y * text_scale
	sb.content_margin_bottom = Feel.HINT_PAD.y * text_scale
	hint.add_theme_stylebox_override("normal", sb)
	hint.reset_size()
	hint.position = to_view(Feel.HINT_POS) - Vector2(hint.size.x / 2.0, 0.0)


## 말풍선 꼬리 (설계 좌표): 말풍선 위쪽 1px 안에서 HINT_TAIL_TIP까지
func _hint_tail() -> PackedVector2Array:
	var tip := Feel.HINT_TAIL_TIP
	var base_y := Feel.HINT_POS.y + 1.0
	return PackedVector2Array([Vector2(tip.x - Feel.HINT_TAIL_HALF, base_y), tip, Vector2(tip.x + Feel.HINT_TAIL_HALF, base_y)])


## 작은 버튼 [강화]: 글자 크기·여백을 동네 글자 배수에 맞춤 (평소 / 올림 두 색)
func _style_button() -> void:
	_flat_button(tuning_button, Feel.COLOR_TUNING, Feel.TOWN_BUTTON_FONT_SIZE)


func _flat_button(btn: Button, color: Color, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", maxi(1, int(roundf(font_size * text_scale))))
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.lightened(Feel.BUILDING_GLOW_LIGHTEN) if state != "normal" else color
		sb.set_corner_radius_all(int(roundf(Feel.TOWN_BUTTON_RADIUS * text_scale)))
		sb.content_margin_left = Feel.TOWN_BUTTON_PAD.x * text_scale
		sb.content_margin_right = Feel.TOWN_BUTTON_PAD.x * text_scale
		sb.content_margin_top = Feel.TOWN_BUTTON_PAD.y * text_scale
		sb.content_margin_bottom = Feel.TOWN_BUTTON_PAD.y * text_scale
		btn.add_theme_stylebox_override(state, sb)


## 급송 전화: ringing이면 전화 아이콘 (ratio = 벨 남은 시간 비율 1 → 0, 막대), left > 0이면 구석 줄 "급송 N건 남음"
func set_rush(ringing: bool, ratio: float, left: int) -> void:
	if rush_button.visible != ringing:
		rush_button.visible = ringing
		_place_icons()
	rush_button.set_ratio(ratio)
	_rush_left.visible = left > 0
	if left > 0:
		_rush_left.text = tr("TOWN_RUSH_LEFT") % left


## 편지봉투: on = NPC가 와 있음, alert = 느낌표 (아직 안 열어 봄). 언제 켜나는 main.gd
func set_letter(on: bool, alert: bool) -> void:
	letter_button.set_alert(alert)
	if letter_button.visible != on:
		letter_button.visible = on
		_place_icons()


## 오른쪽 위 아이콘: 오른쪽 끝부터 편지봉투 → 전화 (보이는 것만, 크기는 동네 글자 배수). 알림은 그 왼쪽에
func _place_icons() -> void:
	var right_top := to_view(Feel.TOWN_ICON_RIGHT_TOP)
	var x := right_top.x
	for icon: TownIcon in [letter_button, rush_button]:
		icon.size = Feel.TOWN_ICON_SIZE * text_scale
		if icon.visible:
			x -= icon.size.x
			icon.position = Vector2(x, right_top.y)
			x -= Feel.TOWN_ICON_GAP * text_scale
		icon.queue_redraw()
	_place_notice()


## 아이콘 줄의 왼쪽 끝 (아이콘과 띄울 간격 포함. 보이는 아이콘이 없으면 아이콘 줄 오른쪽 끝)
func _icons_left() -> float:
	var x := to_view(Feel.TOWN_ICON_RIGHT_TOP).x
	for icon: TownIcon in [letter_button, rush_button]:
		if icon.visible:
			x = minf(x, icon.position.x - Feel.TOWN_ICON_GAP * text_scale)
	return x


func set_hud(money: int, star: int, level: int) -> void:
	_star_label.text = "+%d" % star
	_money_label.text = tr("MONEY") % Fmt.money(money)
	_level_label.text = tr("TOWN_LEVEL") % level


## 레벨 옆 점 (찍을 능력치 포인트가 남았으면 켬. 물류센터에 가 보라는 표시)
func set_point_dot(on: bool) -> void:
	point_dot.visible = on


## "다음 할 일" 한 줄 (글자는 main.gd가 만듦)
func set_quest(text: String) -> void:
	if _quest_label.text != text:
		_quest_label.text = text
		_quest_label.reset_size()


## 알림을 줄 세운다. 앞의 알림이 사라진 뒤에 하나씩 뜬다 (진짜 시간)
func notify(text: String) -> void:
	_notice_queue.append(text)
	if not _notice.visible:
		_next_notice()


func _next_notice() -> void:
	if _notice_queue.is_empty():
		_notice.visible = false
		return
	var text: String = _notice_queue.pop_front()
	notices_shown.append(text)
	_notice.text = text
	_notice.modulate.a = 0.0
	_notice.visible = true
	_place_notice()
	var hold := Feel.NOTICE_SECONDS_BUSY if _notice_queue.size() >= Feel.NOTICE_BUSY_QUEUE else Feel.NOTICE_SECONDS
	var tw := _notice.create_tween().set_ignore_time_scale(true)
	tw.tween_property(_notice, "modulate:a", 1.0, Feel.NOTICE_FADE)
	tw.tween_interval(hold)
	tw.tween_property(_notice, "modulate:a", 0.0, Feel.NOTICE_FADE)
	tw.tween_callback(_next_notice)


## 알림: 오른쪽 맞춤 (오른쪽 위 아이콘이 있으면 그 왼쪽), 동네 왼쪽 밖으로는 안 나감
func _place_notice() -> void:
	_notice.reset_size()
	var right_top := to_view(Feel.NOTICE_RIGHT_TOP)
	var right := minf(right_top.x, _icons_left())
	_notice.position = Vector2(maxf(area().position.x, right - _notice.size.x), right_top.y)




## 성공 연출: "+N" 숫자가 커졌다 돌아옴
func pop_star() -> void:
	pop(_star_label)


## 집 앞: "+금액"이 떠올랐다가 사라짐 (계산 쪽 배송 이벤트가 올 때).
## v6b: 대형·VIP·급송 배송은 앞에 글자("대형 +5,625", "급송 VIP +…")를 붙이고 색을 다르게 (대형·VIP 색이 급송 색보다 먼저)
## v7a: which = 어느 트럭의 배송인가 (보조 트럭도 같은 모양. amount는 내 돈으로 들어온 금액)
func show_payout(house: int, amount: int, kind := "normal", rush := false, which := 0) -> void:
	payouts_shown += 1
	payout_log.append([which, amount])
	var words := PackedStringArray()
	if rush:
		words.append(tr("TOWN_PAY_RUSH"))
	if PAY_KEYS.has(kind):
		words.append(tr(PAY_KEYS[kind]))
	words.append("+" + Fmt.money(amount))
	var color: Color = PAY_COLORS.get(kind, Feel.COLOR_PAYOUT_RUSH if rush else Feel.COLOR_PAYOUT)
	_last_payout = _float_text(_house_spot(house), " ".join(words), Feel.PAYOUT_FONT_SIZE, color, Feel.PAYOUT_RISE, Feel.PAYOUT_DURATION)


## 배송에서 팁이 나옴: 바로 앞 "+금액" 옆에 "팁! +금액" (다른 색). "+금액"의 자식이라 같이 떠오르고 같이 사라지고,
## 보이는 곳은 그 "+금액" 사각형을 넓혀서 (visible_rects). "+금액"이 이미 없으면 그 집 위에 따로 띄움
func show_tip(house: int, amount: int) -> void:
	var text := tr("TOWN_TIP") % Fmt.money(amount)
	tips_shown.append(text)
	if _last_payout == null or not is_instance_valid(_last_payout) or not _payouts.has(_last_payout):
		_float_text(_house_spot(house), text, Feel.PAYOUT_FONT_SIZE, Feel.COLOR_TIP, Feel.PAYOUT_RISE, Feel.PAYOUT_DURATION)
		return
	var tip := make_label(Feel.PAYOUT_FONT_SIZE, Feel.COLOR_TIP)
	_set_font(tip, Feel.PAYOUT_FONT_SIZE)
	tip.text = text
	_last_payout.add_child(tip)
	tip.reset_size()
	tip.position = Vector2(_last_payout.size.x + Feel.TIP_GAP * text_scale, 0.0)
	# 동네 오른쪽 밖으로 나가면 "+금액"째 왼쪽으로
	var over := _last_payout.position.x + tip.position.x + tip.size.x - area().end.x
	if over > 0.0:
		_last_payout.position.x = maxf(area().position.x, _last_payout.position.x - over)


## 배송하다 스페어 엔진을 받음: "스페어 엔진 +1" (더 크게, 금색, 더 오래)
func show_spare(house: int) -> void:
	spares_shown += 1
	_float_text(_house_spot(house), tr("TOWN_SPARE"), Feel.SPARE_FONT_SIZE, Feel.COLOR_SPARE, Feel.SPARE_RISE, Feel.SPARE_DURATION)


## 오버부스트가 걸린 바퀴 출발: 그 트럭(which) 위에 "오버부스트!"
func show_boost(which := 0) -> void:
	boosts_shown += 1
	var at := (trucks[which].position - origin) / zoom   # 동네 설계 좌표
	_float_text(at, tr("TOWN_BOOST"), Feel.BOOST_FONT_SIZE, Feel.COLOR_FLAME, Feel.BOOST_RISE, Feel.BOOST_DURATION_TEXT)


func _house_spot(house: int) -> Vector2:
	return _houses[clampi(house, 0, _houses.size() - 1)]


## spot(동네 설계 좌표, 길 가운데 선 위) 위쪽에서 글자가 떠올랐다가 사라짐
func _float_text(spot: Vector2, text: String, font_size: int, color: Color, rise_px: float, seconds: float) -> Label:
	var label := make_label(font_size, color)
	_set_font(label, font_size)
	label.text = text
	add_child(label)   # 트리에 넣은 뒤에 크기를 재야 글자 폭이 맞음
	label.reset_size()
	var rise := rise_px * text_scale
	var top := to_view(spot) - Vector2(0, Feel.TOWN_HOUSE_SIZE.y + Feel.TOWN_ROOF_HEIGHT) * zoom
	# 동네 밖으로 안 나가게 (작은 화면은 창 = 동네라 밖은 안 보임): 옆으로는 안쪽에, 다 올라가도 위쪽 안에
	var box := area()
	var x := clampf(top.x - label.size.x / 2.0, box.position.x, maxf(box.position.x, box.end.x - label.size.x))
	var y := maxf(top.y - label.size.y, box.position.y + rise)
	label.position = Vector2(x, y)
	label.set_meta(&"rise", rise)
	_payouts.append(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - rise, seconds)
	tw.tween_property(label, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		_payouts.erase(label)
		label.queue_free())
	return label


## 떠오르는 중인 글자 수 (확인용)
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
	# 건물: 빛남 두께만큼 넉넉하게 + 간판. 맞붙은 건물(튜닝숍·카센터)은 한 사각형으로 (사각형 수를 늘리지 않게)
	# 처음 말풍선(+ 꼬리)도 꼬리 끝이 튜닝숍에 닿아서 그 사각형에 합쳐짐 (글자가 가장 많이 떴을 때도 30개 이하로)
	var rects := building_rects()
	var pieces: Array[Rect2] = []
	for id: String in rects:
		var r: Rect2 = rects[id].grow(Feel.BUILDING_GLOW_PX * zoom + 1.0)
		pieces.append(r.merge(Rect2(_signs[id].position, _signs[id].size).grow(o)))
	if hint.visible:
		var tail := _hint_tail()
		pieces.append(Rect2(hint.position, hint.size).merge(view_rect(Rect2(tail[0], Vector2.ZERO).expand(tail[1]).expand(tail[2]))).grow(1.0))
	out.append_array(_join(pieces))
	if _name_tag.visible:
		out.append(Rect2(_name_tag.position, _name_tag.size).grow(o))
	for spot in _houses:
		out.append(view_rect(_house_rect(spot)).grow(1.0))
	# 오른쪽 위 아이콘 (편지봉투·전화): 나란히 붙어 있어서 한 사각형으로
	var icons := Rect2()
	for icon: TownIcon in [letter_button, rush_button]:
		if icon.visible:
			var r := Rect2(icon.position, icon.size).grow(1.0)
			icons = icons.merge(r) if icons.has_area() else r
	if icons.has_area():
		out.append(icons)
	# "+N" 숫자가 커졌다 돌아올 때 잘리지 않게 넉넉하게
	var pop_room := Feel.HUD_FONT_SIZE * text_scale * (Feel.STAR_POP_SCALE - 1.0)
	# 바로 아래 "다음 할 일" 줄과 한 사각형으로 (사각형 수를 늘리지 않게. 둘 다 왼쪽 맞춤이라 빈 곳이 거의 안 생김)
	var hud := Rect2(_hud.position, _hud.get_combined_minimum_size()).grow(o + pop_room)
	out.append(hud.merge(Rect2(_quest_label.position, _quest_label.size).grow(o)))
	if _notice.visible:
		out.append(Rect2(_notice.position, _notice.size).grow(o))
	# 트럭·연기·떠오르는 글자: 겹치는 것끼리 한 사각형으로 (v7a: 트럭 3대 + 글자 10개여도 30개 이하로)
	var moving: Array[Rect2] = []
	for t in trucks:
		moving.append(t.click_rect().grow(truck_pad))
		var smoke := t.smoke_rect()
		if smoke.has_area():
			moving.append(smoke.grow(truck_pad))
	for p in _payouts:
		if is_instance_valid(p):
			var r := Rect2(p.position, p.get_combined_minimum_size())
			for c: Control in p.get_children():   # 옆에 붙은 "팁!" (같은 사각형을 넓힘)
				r = r.merge(Rect2(p.position + c.position, c.get_combined_minimum_size()))
			moving.append(r.grow(o))
	out.append_array(_join(moving))
	return out


## 겹치는 사각형은 앞의 것과 합침 (한 번 훑기. 사각형 수를 늘리지 않게. 합친 사각형은 둘을 덮는 가장 작은 사각형)
static func _join(rects: Array[Rect2]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in rects:
		var joined := false
		for i in out.size():
			if out[i].intersects(r):
				out[i] = out[i].merge(r)
				joined = true
				break
		if not joined:
			out.append(r)
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

	# 건물 (물류센터는 길 시작점 뒤): 사각형 + 문. 마우스를 올리면 밝게 + 둘레 빛. 사무실은 창업 뒤에만
	for id: String in BUILDING_SPOTS:
		if id == OFFICE and not office_open:
			continue
		var d: Rect2 = BUILDING_SPOTS[id]
		var color: Color = BUILDING_COLORS[id]
		var lit := id == hovered
		if lit:
			draw_rect(d.grow(Feel.BUILDING_GLOW_PX), Feel.COLOR_BUILDING_GLOW)
		draw_rect(d, color.lightened(Feel.BUILDING_GLOW_LIGHTEN) if lit else color)
		var door := Feel.BUILDING_DOOR_SIZE
		draw_rect(Rect2(d.end.x - d.size.x * Feel.BUILDING_DOOR_RIGHT, d.end.y - d.size.y * door.y, d.size.x * door.x, d.size.y * door.y), Feel.COLOR_ROAD_EDGE)
		if id == "tuning" and master_visit:   # 건물 가장자리를 가운데로: 바깥 절반 = 빛남 두께
			draw_rect(d, Feel.COLOR_MASTER, false, Feel.MASTER_MARK_WIDTH)

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

	# 말풍선 꼬리 (길 위에. 말풍선 글상자는 hint 글자가 그 위에 그림)
	if hint.visible:
		draw_colored_polygon(_hint_tail(), Feel.COLOR_HINT_BG)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _set_font(l: Label, base: int) -> void:
	l.add_theme_font_size_override("font_size", maxi(1, int(roundf(base * text_scale))))
	l.add_theme_constant_override("outline_size", maxi(1, int(roundf(Feel.TEXT_OUTLINE_SIZE * text_scale))))


## 글자를 커졌다 돌아오게 (garage_panel.gd 제목, 튜닝 등급 글자에도 씀)
## pivot: 어디를 기준으로 커지나 (0.5, 0.5 = 가운데, 0, 0.5 = 왼쪽 끝에서 오른쪽으로)
static func pop(c: Control, pivot := Vector2(0.5, 0.5), k := Feel.STAR_POP_SCALE,
		seconds := Feel.STAR_POP_DURATION) -> void:
	c.pivot_offset_ratio = pivot
	# 앞의 커지기가 아직 돌고 있으면 멈춤 (두 개가 같은 크기를 서로 바꾸며 싸우지 않게: 연달아 등급업 등)
	var old: Tween = c.get_meta(&"pop_tween") if c.has_meta(&"pop_tween") else null
	if old != null and old.is_valid():
		old.kill()
	c.scale = Vector2.ONE * k
	var tw := c.create_tween().set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE, seconds) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta(&"pop_tween", tw)


## 글자 (바탕화면 위에서도 읽히게 테두리를 두름)
static func make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", Feel.TEXT_OUTLINE_SIZE)
	l.add_theme_color_override("font_outline_color", Feel.COLOR_TEXT_OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
