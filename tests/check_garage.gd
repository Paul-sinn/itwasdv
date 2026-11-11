## 3단계 완료 기준 자동 확인: F4/F5로 0강~30강, 퍼짐 → 수리까지 전부 눌러볼 수 있나?
## 진짜 게임 화면(main.tscn)에 진짜 키·마우스 입력을 넣어서 확인한다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_garage.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const TEST_SAVE := "user://test_check_save.json"

var m: Node
var fails := PackedStringArray()
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.size = Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	m = load(MAIN_SCENE).instantiate()
	Save.delete_file(TEST_SAVE)
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	await _frames(3)
	var b = m.balance
	var p = m.panel

	# 1) 트럭 클릭 → 패널 열림
	_click(_truck_center())
	await _frames(2)
	_check(p.visible, "트럭을 클릭했는데 패널이 안 열림")
	_check(p._enhance_button.visible and p._enhance_button.disabled, "0원인데 강화 버튼이 눌림 상태")
	_check(p._wait.visible and p._wait.text.begins_with("약 "), "돈 모자랄 때 '약 N분 뒤 가능'이 없음: '%s'" % p._wait.text)

	# 2) F4로 0강 → 30강. 강수마다 패널 내용 확인
	for star in range(0, b.max_star):
		_check(m.state.star == star, "F4 %d번째: 강수 %d (기대 %d)" % [star, m.state.star, star])
		var danger: bool = b.destroy[star] > 0.0
		_check(p._danger.visible == danger, "%d강: '퍼질 확률' 표시가 %s여야 함" % [star, "보임" if danger else "숨김"])
		_check(p._chances.text.contains("성공"), "%d강: 확률 줄이 비어 있음" % star)
		_key(KEY_F4)
		await _frames(1)
	_check(m.state.star == b.max_star, "F4를 30번 눌렀는데 30강이 아님: %d" % m.state.star)
	_check(not p._enhance_button.visible, "30강인데 강화 버튼이 보임")
	_key(KEY_F4)
	await _frames(1)
	_check(m.state.star == b.max_star, "30강에서 F4를 더 눌렀더니 넘어감: %d" % m.state.star)

	# 3) F5 → 15강 고장. 트럭 멈춤, 스페어 버튼만
	var x_before: float = m.band.truck.position.x
	_key(KEY_F5)
	await _frames(30)
	_check(m.state.broken and m.state.star == 15, "F5 뒤: 고장 %s, 강수 %d" % [m.state.broken, m.state.star])
	_check(is_equal_approx(m.band.truck.position.x, x_before) or not m.band.truck.running, "고장인데 트럭이 움직임")
	_check(not m.band.truck._smoke.is_empty(), "고장인데 연기가 안 남")
	_check(p._broken_label.visible, "'엔진 고장 - 운행 정지'가 안 보임")
	_check(p._spare_button.visible and not p._enhance_button.visible, "고장인데 스페어 버튼만 보이는 상태가 아님")
	_check(p._spare_button.disabled, "돈이 없는데 스페어 버튼이 눌림 상태")
	_check(m.state.current_hourly(b) == 0.0, "고장인데 수익이 0이 아님")

	# 4) F1로 돈 모으기 → 스페어 구매 (버튼을 진짜로 클릭)
	var presses := 0
	while not m.state.can_buy_spare(b) and presses < 200:
		_key(KEY_F1)
		presses += 1
	await _frames(1)
	_check(not p._spare_button.disabled, "F1 %d번 뒤에도 스페어를 못 삼" % presses)
	_click(p._spare_button.get_global_rect().get_center())
	await _frames(2)
	_check(not m.state.broken and m.state.star == 15, "스페어 클릭 뒤: 고장 %s, 강수 %d" % [m.state.broken, m.state.star])
	_check(p._result.text.contains("스페어"), "수리 결과가 안 보임: '%s'" % p._result.text)

	# 5) 강화 버튼을 진짜로 클릭 → 뜸 → 결과 반영, 통계
	m.state.money = 1e12
	await _frames(1)
	for i in 5:
		if m.state.broken:
			break
		var before: int = m.state.press_count()
		_click(p._enhance_button.get_global_rect().get_center())
		await _frames(1)
		_check(m.enhancing and p._enhance_button.disabled, "%d번째: 누른 뒤 뜸(버튼 잠김)이 없음" % i)
		_check(m.state.press_count() == before, "%d번째: 뜸이 끝나기 전에 결과가 나옴" % i)
		_click(p._enhance_button.get_global_rect().get_center())   # 뜸 중에 또 눌러도 무시돼야 함
		var waited := 0
		while m.enhancing and waited < 600:
			await process_frame
			waited += 1
		_check(m.state.press_count() == before + 1, "%d번째: 한 번 눌렀는데 횟수가 %d 늘어남" % [i, m.state.press_count() - before])
	_check(m.state.press_count() > 0, "강화 버튼을 눌렀는데 횟수가 0")
	_check(p._result.text != "", "강화 결과가 안 보임")
	_check(p._stats.text.contains("누른 횟수 %d" % m.state.press_count()), "통계 줄이 안 맞음: '%s'" % p._stats.text)

	# 6) 패널 밖 클릭 → 닫힘
	_click(Vector2(5, 5))
	await _frames(2)
	_check(not p.visible, "바깥을 눌렀는데 패널이 안 닫힘")

	# 7) 트럭 다시 클릭 → 열림, 또 클릭 → 닫힘
	_click(_truck_center())
	await _frames(2)
	_check(p.visible, "트럭 다시 클릭 → 안 열림")
	_click(_truck_center())
	await _frames(2)
	_check(not p.visible, "트럭 한 번 더 클릭 → 안 닫힘")

	# 8) F3 → 처음부터
	_key(KEY_F3)
	await _frames(1)
	_check(m.state.star == 0 and m.state.money == 0.0 and m.state.press_count() == 0, "F3 뒤 처음 상태가 아님")

	Save.delete_file(TEST_SAVE)
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


func _truck_center() -> Vector2:
	var r: Rect2 = m.band.truck.click_rect()
	return m.band.position + r.get_center()


func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.pressed = pressed
		root.push_input(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
