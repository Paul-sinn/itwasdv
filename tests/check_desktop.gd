## 5단계 확인용 (tests/check_desktop.ps1 이 실행함. 혼자 실행하지 말 것)
## 진짜 투명 창으로 main을 띄우고, 확인할 점들의 화면 좌표(Windows 기준)를 찍는다.
##   PT <이름> <x> <y> <기대: game|behind>
## 1단계: 패널 닫힘 → PHASE1, 2단계: 패널 열림 → PHASE2
extends SceneTree

const Save = preload("res://scripts/core/save.gd")
const TEST_SAVE := "user://test_check_save.json"

var m: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	Save.delete_file(TEST_SAVE)
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	root.add_child(m)
	for i in 90:
		await process_frame
	m.set_process(false)          # 트럭을 세워서 좌표를 고정 (main이 매 프레임 되돌리지 않게)
	m.band.truck.running = false
	for i in 10:
		await process_frame

	var bp: Vector2 = m.band.position
	var tr: Rect2 = m.band.truck.click_rect()
	_pt("트럭", bp + tr.get_center(), "game")
	_pt("집", bp + Vector2(m.band.width - 36, 80), "game")
	_pt("돈_글자", bp + Vector2(110, 14), "game")
	_pt("띠_빈곳", bp + Vector2((tr.end.x + m.band.width) / 2.0 - 100, 50), "behind")
	_pt("띠_위_빈곳", Vector2(m.band.width / 2.0, 100), "behind")
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	print("WIN ", root.position.x - off.x, " ", root.position.y - off.y, " ", root.size.x, " ", root.size.y)
	print("PHASE1")
	for i in 90:
		await process_frame

	m._open_panel()
	for i in 10:
		await process_frame
	var pr: Rect2 = m.panel.get_rect()
	_pt("패널", pr.get_center(), "game")
	_pt("강화_버튼", m.panel._enhance_button.get_global_rect().get_center(), "game")
	_pt("패널_옆_빈곳", Vector2(pr.end.x + 300, 100), "behind")
	print("PHASE2")
	for i in 90:
		await process_frame
	Save.delete_file(TEST_SAVE)
	quit()


func _pt(tag: String, local: Vector2, expect: String) -> void:
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	var g := Vector2(root.position) + local - Vector2(off)
	print("PT %s %d %d %s" % [tag, int(g.x), int(g.y), expect])
