## 알림 영역(시계 옆) 아이콘. screen_mode.gd가 만든다 (화면 없는 테스트에서는 안 만듦).
##   왼쪽 클릭 → full_pressed
##   오른쪽 클릭 → 메뉴: 전체 화면 / 작게 / 끝내기
##
## Godot 4.6.3 + Windows에서 직접 확인한 것 (v1 0단계):
##   - StatusIndicator 노드로 아이콘이 뜨고, 왼쪽 클릭이 pressed 신호로 들어온다.
##   - menu에 PopupMenu를 이어 주면 오른쪽 클릭에 Windows 기본 메뉴가 뜨고(pressed는 안 옴),
##     고른 항목은 PopupMenu의 id_pressed로 들어온다.
##   - 새 아이콘은 Windows가 ^ 숨김 칸에 넣을 수 있다 (정상. 사용자가 끌어내면 됨).
## 아이콘 그림은 임시: 코드에서 만든 작은 트럭.
extends Node

const Feel = preload("res://scripts/ui/feel.gd")

signal full_pressed
signal small_pressed
signal quit_pressed

enum Item { FULL = 1, SMALL = 2, QUIT = 3 }

var indicator: StatusIndicator
var menu: PopupMenu


static func supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)


func _ready() -> void:
	menu = PopupMenu.new()
	menu.name = "TrayMenu"
	menu.add_item("전체 화면", Item.FULL)
	menu.add_item("작게", Item.SMALL)
	menu.add_separator()
	menu.add_item("끝내기", Item.QUIT)
	menu.id_pressed.connect(_on_menu)
	add_child(menu)

	indicator = StatusIndicator.new()
	indicator.icon = make_icon()
	indicator.tooltip = str(ProjectSettings.get_setting("application/config/name"))
	indicator.pressed.connect(_on_pressed)
	add_child(indicator)
	indicator.menu = indicator.get_path_to(menu)


func _on_pressed(button: int, _pos: Vector2i) -> void:
	if button == MOUSE_BUTTON_LEFT:
		full_pressed.emit()


func _on_menu(id: int) -> void:
	match id:
		Item.FULL: full_pressed.emit()
		Item.SMALL: small_pressed.emit()
		Item.QUIT: quit_pressed.emit()


## 임시 아이콘: 투명 바탕에 짐칸(흰색) + 운전석(노랑) + 바퀴(검정)
static func make_icon() -> ImageTexture:
	var n := Feel.TRAY_ICON_SIZE
	var u := n / 16.0   # 16칸 격자 한 칸
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(Vector2i(Vector2(0, 3) * u), Vector2i(Vector2(10, 9) * u)), Feel.COLOR_TRUCK_BOX)
	img.fill_rect(Rect2i(Vector2i(Vector2(10, 6) * u), Vector2i(Vector2(6, 6) * u)), Feel.COLOR_TRUCK_CAB)
	img.fill_rect(Rect2i(Vector2i(Vector2(2, 11) * u), Vector2i(Vector2(4, 4) * u)), Feel.COLOR_WHEEL)
	img.fill_rect(Rect2i(Vector2i(Vector2(11, 11) * u), Vector2i(Vector2(4, 4) * u)), Feel.COLOR_WHEEL)
	return ImageTexture.create_from_image(img)
