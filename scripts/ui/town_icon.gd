## 띠 오른쪽 위 작은 아이콘 (v7-bal): 편지봉투(NPC가 온 날. 느낌표 = 아직 안 열어 봄) / 전화(급송 벨. 아래 남은 시간 막대).
## 임시 그림 (코드로 그리는 도형, 글자 없음). 누르면 pressed. 크기·자리는 town.gd가 동네 글자 배수에 맞춰 정함.
## 그림은 설계 크기(Feel.TOWN_ICON_SIZE) 좌표로 그리고 지금 크기만큼 늘림
extends Control

const Feel = preload("res://scripts/ui/feel.gd")

signal pressed

var kind := "letter"   ## "letter" / "phone"
var alert := false     ## 편지봉투 느낌표 (set_alert)
var ratio := 1.0       ## 전화 벨 남은 시간 비율 1 → 0 (set_ratio)


func _init(k: String) -> void:
	kind = k
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func set_alert(on: bool) -> void:
	if alert != on:
		alert = on
		queue_redraw()


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	if not is_equal_approx(ratio, r):
		ratio = r
		queue_redraw()


func _draw() -> void:
	var s := Feel.TOWN_ICON_SIZE
	draw_set_transform(Vector2.ZERO, 0.0, size / s)
	if kind == "phone":
		# 바탕 + 수화기(위가 둥근 굵은 호, 양 끝 귀·입 대는 곳) + 아래 남은 시간 막대
		draw_rect(Rect2(Vector2.ZERO, s), Feel.COLOR_RUSH_BUTTON)
		var c := Vector2(s.x / 2.0, s.y * 0.62)
		var rad := s.x * 0.28
		draw_arc(c, rad, PI, TAU, 12, Feel.COLOR_TEXT, s.y * 0.16, true)
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(c.x + side * rad - s.x * 0.1, c.y - s.y * 0.04, s.x * 0.2, s.y * 0.2), Feel.COLOR_TEXT)
		var bar := s.y * Feel.TOWN_ICON_BAR
		draw_rect(Rect2(0, s.y - bar, s.x, bar), Feel.COLOR_RUSH_BAR_BG)
		draw_rect(Rect2(0, s.y - bar, s.x * ratio, bar), Feel.COLOR_RUSH_BG)
	else:
		# 봉투 (오른쪽 위에 느낌표 자리를 남김): 종이 + 테두리 + 접힌 덮개 V
		var body := Rect2(0, s.y * 0.22, s.x * 0.84, s.y * 0.78)
		draw_rect(body, Feel.COLOR_LETTER)
		draw_rect(body, Feel.COLOR_LETTER_LINE, false, 1.0)
		draw_polyline(PackedVector2Array([body.position, Vector2(body.get_center().x, body.position.y + body.size.y * 0.55),
				Vector2(body.end.x, body.position.y)]), Feel.COLOR_LETTER_LINE, 1.2, true)
		if alert:   # 빨간 동그라미 + 흰 "!" (막대 + 점)
			var at := Vector2(s.x - s.y * 0.26, s.y * 0.26)
			var r := s.y * 0.26
			draw_circle(at, r, Feel.COLOR_ALERT, true, -1.0, true)
			draw_rect(Rect2(at.x - r * 0.14, at.y - r * 0.62, r * 0.28, r * 0.78), Feel.COLOR_TEXT)
			draw_rect(Rect2(at.x - r * 0.14, at.y + r * 0.32, r * 0.28, r * 0.28), Feel.COLOR_TEXT)
