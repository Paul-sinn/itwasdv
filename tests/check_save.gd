## 4단계 완료 기준 자동 확인: 저장과 꺼둔 동안 수익
## - 껐다 켜도 상태 유지
## - 저장 시각을 3시간 전 / 20시간 전 / 미래로 → 3시간치의 절반 / 8시간치의 절반 / 0
## - 고장이면 0, 깨진 저장 파일이면 새로 시작, F3이면 저장 지움, 30초 자동 저장
## - 복귀 팝업은 작은 화면(480x220) 위에, 그 안에 다 들어감 (v1)
## 진짜 게임 화면(main.tscn)을 작은 화면 크기로 띄워서 확인한다. 진짜 저장 파일은 건드리지 않는다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_save.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const TEST_SAVE := "user://test_town_save.json"
const HOUR := 3600

var fails := PackedStringArray()
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.size = Feel.SMALL_SIZE
	Save.delete_file(TEST_SAVE)

	# 1) 껐다 켜도 상태 유지 (끌 때 저장 → 다시 켬)
	var m := await _launch()
	_check(not m.popup.visible, "저장 없이 처음 켰는데 팝업이 뜸")
	m.state.money = 98765.4
	m.state.star = 19
	m.state.success_count = 5
	m.state.fail_count = 6
	m.state.destroy_count = 1
	m.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)   # 창 닫기 = 저장
	await _close(m)
	m = await _launch()
	_check(m.state.star == 19 and m.state.success_count == 5 and m.state.fail_count == 6 and m.state.destroy_count == 1,
			"다시 켰는데 강수/통계가 다름: ★%d %d/%d/%d" % [m.state.star, m.state.success_count, m.state.fail_count, m.state.destroy_count])
	_check(absf(m.state.money - 98765.4) < 1.0, "다시 켰는데 돈이 다름: %s" % m.state.money)
	_check(not m.popup.visible, "바로 다시 켰는데(1분 미만) 복귀 팝업이 뜸")
	var timer: Timer = m.get_node("Autosave")
	_check(timer.wait_time == 30.0 and timer.ignore_time_scale and not timer.is_stopped(), "30초 자동 저장 타이머가 이상함")
	await _close(m)

	# 2) 저장 시각 바꾸기: 3시간 전 / 20시간 전 / 미래 / 고장
	var hourly := 0.0
	for c in [
		{ "name": "3시간 전", "shift": -3 * HOUR, "broken": false, "hours": 3.0 * 0.5, "note": "최대" },
		{ "name": "20시간 전", "shift": -20 * HOUR, "broken": false, "hours": 8.0 * 0.5, "note": "최대" },
		{ "name": "5시간 뒤(미래)", "shift": 5 * HOUR, "broken": false, "hours": 0.0, "note": "시계" },
		{ "name": "3시간 전 + 고장", "shift": -3 * HOUR, "broken": true, "hours": 0.0, "note": "고장" },
	]:
		var s := GameState.new()
		s.star = 10
		s.money = 1000.0
		s.broken = c["broken"]
		s.star_before_break = 20 if c["broken"] else 0
		Save.write_file(TEST_SAVE, s, int(Time.get_unix_time_from_system()) + c["shift"])
		m = await _launch()
		hourly = Economy.hourly_income(m.balance, 10)
		var expected: float = hourly * c["hours"]
		var got: float = m.state.money - 1000.0
		_check(absf(got - expected) <= maxf(0.01, hourly * 3.0 / HOUR),   # 켜는 데 걸린 몇 초는 봐줌
				"%s: 들어온 돈 %.2f, 기대 %.2f" % [c["name"], got, expected])
		_check(m.popup.visible, "%s: 복귀 팝업이 안 뜸" % c["name"])
		_check(m.screen.mode == 0 and Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()),
				"%s: 복귀 팝업이 작은 화면 480x220 안에 없음: %s" % [c["name"], m.popup.get_rect()])
		_check(m.popup.note_text().contains(c["note"]), "%s: 팝업 설명에 '%s'가 없음: %s" % [c["name"], c["note"], m.popup.note_text()])
		print("  %s → +%.1f원 (기대 %.1f) · 팝업: %s / %s" % [c["name"], got, expected, m.popup.main_text(), m.popup.note_text()])
		await _close(m)
		# 받은 뒤 바로 저장했으니, 또 켜면 두 번 받지 않아야 함
		m = await _launch()
		_check(absf(m.state.money - 1000.0 - got) < 1.0, "%s: 다시 켰더니 또 받음 (%.2f)" % [c["name"], m.state.money - 1000.0])
		await _close(m)

	# 3) 깨진 저장 파일 → 새로 시작 + 알림, .broken 으로 남김
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ 이건 깨진 파일")
	f.close()
	m = await _launch()
	_check(m.state.star == 0 and m.state.money < 1.0, "깨진 저장인데 새로 시작 안 함")
	_check(m.popup.visible and m.popup.main_text().contains("깨져서"), "깨진 저장 알림이 없음")
	_check(Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()), "깨진 저장 알림이 작은 화면 밖: %s" % m.popup.get_rect())
	_check(FileAccess.file_exists(TEST_SAVE + ".broken"), "깨진 파일을 .broken 으로 안 남김")
	DirAccess.remove_absolute(TEST_SAVE + ".broken")

	# 4) F3 → 저장 초기화
	m.state.star = 12
	m._save()
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(m.state.star == 0, "F3 뒤 0강이 아님")
	var r := Save.read_file(TEST_SAVE, m.balance)
	_check(r["status"] == Save.Status.OK and r["state"].star == 0, "F3 뒤 저장 파일이 처음 상태가 아님")
	await _close(m)

	Save.delete_file(TEST_SAVE)
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for x in fails:
		print("  [실패] " + x)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


func _launch() -> Node:
	var m: Node = load(MAIN_SCENE).instantiate()
	m.save_path = TEST_SAVE
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func _close(m: Node) -> void:
	m.queue_free()
	await process_frame


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
