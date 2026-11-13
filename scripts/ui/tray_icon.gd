## 알림 영역(시계 옆) 아이콘. screen_mode.gd가 만든다 (화면 없는 테스트에서는 안 만듦).
##   왼쪽 클릭 → full_pressed
##   오른쪽 클릭 → (버튼을 뗀 뒤) 메뉴: 전체 화면 / 작게 / 끝내기
##   작은 동네를 오른쪽 클릭해도 같은 메뉴 (screen_mode.open_menu_at_mouse → open_menu_at_mouse)
##
## Godot 4.6.3 + Windows에서 직접 확인한 것:
##   - StatusIndicator 노드로 아이콘이 뜨고, 왼쪽 클릭이 pressed 신호로 들어온다.
##   - StatusIndicator.menu에 PopupMenu를 이어 주는 Godot 기본 방식은 오른쪽 버튼을 "누르는 순간" 메뉴를 띄운다.
##     Windows가 보내는 클릭 메시지를 흉내 내면 메뉴가 뜨는데, 사용자가 진짜로 오른쪽 클릭하면 안 떴다 (2026-11-10).
##     (Godot 이슈 #106626: 모니터마다 배율이 다르면 트레이 메뉴가 안 뜸. 이 PC가 그 경우)
##   → menu를 잇지 않고, 오른쪽 클릭을 pressed로 직접 받아서 TRAY_MENU_DELAY 뒤(버튼을 뗀 뒤)
##     Windows 기본 메뉴(NativeMenu)를 아이콘 자리에 띄운다.
##   - 새 아이콘은 Windows가 ^ 숨김 칸에 넣을 수 있다 (정상. 사용자가 끌어내면 됨).
## 아이콘 그림은 임시: 코드에서 만든 작은 트럭.
extends Node

const Feel = preload("res://scripts/ui/feel.gd")

signal full_pressed
signal small_pressed
signal quit_pressed
## 오른쪽 클릭으로 메뉴를 띄우려고 함 (확인 스크립트용)
signal menu_requested

enum Item { FULL = 1, SMALL = 2, QUIT = 3 }

var indicator: StatusIndicator
## false면 메뉴를 진짜로 띄우지 않고 menu_requested만 보낸다 (확인 스크립트가 끔. 띄우면 메뉴가 닫힐 때까지 멈춤)
var popup_enabled := true
## false면 메뉴의 "작게"를 흐리게 (이미 작은 화면일 때. screen_mode.gd가 바꿈)
var small_enabled := true

var _menu_rid := RID()
var _menu_pending := false


static func supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)


func _ready() -> void:
	if NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		_menu_rid = NativeMenu.create_menu()
		NativeMenu.add_item(_menu_rid, "전체 화면", choose, Callable(), Item.FULL)
		NativeMenu.add_item(_menu_rid, "작게", choose, Callable(), Item.SMALL)
		NativeMenu.add_separator(_menu_rid)
		NativeMenu.add_item(_menu_rid, "끝내기", choose, Callable(), Item.QUIT)

	indicator = StatusIndicator.new()
	indicator.icon = make_icon()
	indicator.tooltip = str(ProjectSettings.get_setting("application/config/name"))
	indicator.pressed.connect(_on_pressed)
	add_child(indicator)


func _exit_tree() -> void:
	if _menu_rid.is_valid():
		NativeMenu.free_menu(_menu_rid)
		_menu_rid = RID()


## 메뉴 항목 고르기 (메뉴에서 고르면 불림. 확인 스크립트도 이걸로)
func choose(id: Variant) -> void:
	match int(id):
		Item.FULL: full_pressed.emit()
		Item.SMALL: small_pressed.emit()
		Item.QUIT: quit_pressed.emit()


func _on_pressed(button: int, _pos: Vector2i) -> void:
	if button == MOUSE_BUTTON_LEFT:
		full_pressed.emit()
	elif button == MOUSE_BUTTON_RIGHT:
		_open_menu_later()


## 오른쪽 버튼을 뗄 시간을 준 뒤 메뉴를 띄운다 (진짜 시간 기준. F2 배속과 상관없이)
func _open_menu_later() -> void:
	if _menu_pending:
		return
	_menu_pending = true
	await get_tree().create_timer(Feel.TRAY_MENU_DELAY, true, false, true).timeout
	_menu_pending = false
	open_menu(menu_position())


## 메뉴를 마우스 자리에 (작은 동네 오른쪽 클릭. 부르는 쪽이 버튼을 뗀 뒤에 부른다)
func open_menu_at_mouse() -> void:
	open_menu(to_windows(DisplayServer.mouse_get_position()))


## 메뉴 띄우기 (at = Windows 화면 좌표). 메뉴가 닫힐 때까지 여기서 기다림
func open_menu(at: Vector2i) -> void:
	menu_requested.emit()
	if not popup_enabled or not _menu_rid.is_valid():
		return
	var small := NativeMenu.find_item_index_with_tag(_menu_rid, Item.SMALL)
	if small >= 0:
		NativeMenu.set_item_disabled(_menu_rid, small, not small_enabled)
	NativeMenu.popup(_menu_rid, at)


## 메뉴를 띄울 자리 (Windows 화면 좌표): 아이콘 가운데, 모르면 마우스 자리.
func menu_position() -> Vector2i:
	var r := indicator.get_rect()
	return to_windows(Vector2i(r.get_center()) if r.has_area() else DisplayServer.mouse_get_position())


## Godot 화면 좌표 → Windows 화면 좌표.
## NativeMenu.popup은 Windows 좌표를 그대로 쓴다 (Godot 좌표 = Windows 좌표 - 모든 화면의 왼쪽 위 끝).
## Windows 좌표의 (0,0)은 주 모니터 왼쪽 위라서, Godot 좌표에서 주 모니터 위치를 빼면 된다.
static func to_windows(godot_pos: Vector2i) -> Vector2i:
	return godot_pos - DisplayServer.screen_get_position(DisplayServer.get_primary_screen())


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
