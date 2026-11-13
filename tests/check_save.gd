## 저장과 꺼둔 동안 자동 확인 (4단계 → v3 U2 ③). 진짜 게임 화면(main.tscn)을 작은 화면 크기로 띄워서 확인한다.
## - 껐다 켜도 상태 유지 (돈·단계·스페어·통계), 30초 자동 저장
## - ③ 저장 시각을 3시간 전 / 20시간 전 / 미래로 → 꺼둔 동안 돈·배송·스페어(Trip.apply_offline)가 상태에 들어가고 복귀 창에 보임
##   (v5: 다음 할 일은 다 끝낸 상태로 저장해 둔다. 켜자마자 할 일이 끝나면 보상 돈이 섞여서)
## - ③ 옛 형식(형식 2) 파일 → save.v2.json으로 남기고 새 게임 + 안내, 본 파일이 깨지면 백업에서 살리고 안내,
##   백업까지 깨지면 새로 시작 + 안내
## - F3이면 저장 지움, 복귀 창은 작은 화면(480x220) 안
## 진짜 저장 파일은 건드리지 않는다 (시험용 폴더. 옛 형식 파일을 옮겨 두는 save.v2.json도 그 폴더에).
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_save.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_DIR := "user://test_town_save"
const TEST_SAVE := TEST_DIR + "/save.json"
const OLD_KEPT := TEST_DIR + "/save.v2.json"
const TEST_SETTINGS := "user://test_town_settings.cfg"   ## 진짜 설정 파일 말고 (읽기만 하지만 따로)
const HOUR := 3600

var fails := PackedStringArray()
var checks := 0


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")   # 아래에서 한국어 글자를 비교함 (OS 언어와 상관없이)
	root.size = Feel.SMALL_SIZE
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)   # screen_mode.gd에 settings_path가 없으면 아무 일 없음
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	_clean()
	var b := Balance.load_file()

	# 1) 껐다 켜도 상태 유지 (끌 때 저장 → 다시 켬)
	var m := await _launch()
	_check(not m.popup.visible, "저장 없이 처음 켰는데 팝업이 뜸")
	var t = m.state.truck(0)
	m.state.money = 98765
	m.state.spares = 3
	t.star = 19
	t.success_count = 5
	t.fail_count = 6
	t.destroy_count = 1
	m.state.quest_index = Quest.count(b)
	m.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)   # 창 닫기 = 저장
	await _close(m)
	m = await _launch()
	t = m.state.truck(0)
	_check(t.star == 19 and t.success_count == 5 and t.fail_count == 6 and t.destroy_count == 1 and m.state.spares == 3,
			"다시 켰는데 단계/통계/스페어가 다름: +%d %d/%d/%d 스페어 %d" % [t.star, t.success_count, t.fail_count, t.destroy_count, m.state.spares])
	_check(m.state.money >= 98765 and m.state.money < 98765 + Trip.lap_income(b, m.state, 0), "다시 켰는데 돈이 다름: %s" % m.state.money)
	_check(not m.popup.visible, "바로 다시 켰는데(3분 미만) 복귀 팝업이 뜸")
	var timer: Timer = m.get_node("Autosave")
	_check(timer.wait_time == 30.0 and timer.ignore_time_scale and not timer.is_stopped(), "30초 자동 저장 타이머가 이상함")
	await _close(m)

	# 2) 저장 시각 바꾸기: 3시간 전 / 20시간 전(상한) / 미래(0) / 스페어 소수 나머지가 차서 +1
	for c in [
		{ "name": "3시간 전", "shift": -3 * HOUR, "carry": 0.0 },
		{ "name": "20시간 전", "shift": -20 * HOUR, "carry": 0.0 },
		{ "name": "5시간 뒤(미래)", "shift": 5 * HOUR, "carry": 0.0, "note": "시계" },
		{ "name": "3시간 전 + 스페어 나머지 0.99", "shift": -3 * HOUR, "carry": 0.99 },
	]:
		var s := GameState.new_game()
		s.truck(0).star = 10
		s.money = 1000
		s.spare_drop_carry = c["carry"]
		s.quest_index = Quest.count(b)
		_clean()
		Save.write_file(TEST_SAVE, s, int(Time.get_unix_time_from_system()) + c["shift"])
		# 같은 상태에 Trip.apply_offline을 직접 불러 기대값을 만든다 (켜는 데 걸리는 몇 초는 아래에서 봐줌)
		var want := Trip.apply_offline(s, b, -c["shift"])
		m = await _launch()
		var r: Dictionary = m.offline_report
		var got_money: int = m.state.money - 1000
		var slack: float = Trip.hourly_income(b, m.state, 0) * Depot.rate(b, m.state) * 5.0 / HOUR + 1.0
		var ok: bool = absf(got_money - want["money"]) <= slack and got_money == r["money"] \
				and absi(r["parcels"] - want["parcels"]) <= 1 and r["spares"] == want["spares"] and m.state.spares == want["spares"]
		var main_text: String = m.popup.main_text()
		var note: String = m.popup.note_text()
		var shown: bool = m.popup.visible and Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect())
		if c.has("note"):
			shown = shown and main_text == tr("RETURN_MAIN_ZERO") and note.contains(c["note"])
		else:
			shown = shown and main_text.contains("+" + Fmt.money(r["money"]) + "원") \
					and note.contains(tr("RETURN_DETAIL") % [r["parcels"], r["spares"]]) \
					and note.contains(tr("RETURN_XP") % r["xp"]) == (r["xp"] > 0)   # 노하우 경험치 줄은 있을 때만
		_report(ok and shown, "③ %s: 돈 +%d (Trip.apply_offline %d), 배송 %d건, 스페어 +%d개 → 복귀 창 '%s' / '%s'" % [
				c["name"], got_money, want["money"], r["parcels"], r["spares"], main_text, note.replace("\n", " / ")])
		await _close(m)
		# 받은 뒤 바로 저장했으니, 또 켜면 두 번 받지 않아야 함
		m = await _launch()
		_check(m.state.money - 1000 - got_money < Trip.lap_income(b, m.state, 0), "%s: 다시 켰더니 또 받음 (%d)" % [c["name"], m.state.money - 1000])
		await _close(m)

	# 3) 옛 형식(형식 2) 파일 → save.v2.json으로 남기고 새 게임 + 안내
	_clean()
	var old_text := JSON.stringify({ "version": 2, "saved_at_utc": "2026-11-12T10:00:00", "money": 123.0, "star": 5 })
	_write(TEST_SAVE, old_text)
	m = await _launch()
	var old_ok: bool = m.state.truck(0).star == 0 and m.state.money < Trip.lap_income(b, m.state, 0) \
			and FileAccess.get_file_as_string(OLD_KEPT) == old_text
	_report(old_ok and m.popup.visible and m.popup.main_text() == tr("LOAD_OLD_KEPT") % OLD_KEPT.get_file(),
			"③ 옛 형식 파일 → save.v2.json으로 남기고 새 게임, 복귀 창 '%s'" % m.popup.main_text().replace("\n", " / "))
	await _close(m)

	# 4) 본 파일이 깨짐 → 백업(bak1)에서 살리고 안내 (꺼둔 동안 요약은 아래 작은 글자로)
	_clean()
	var s2 := GameState.new_game()
	s2.truck(0).star = 12
	s2.money = 5000
	s2.quest_index = Quest.count(b)
	var at := int(Time.get_unix_time_from_system()) - 2 * HOUR
	Save.write_file(TEST_SAVE, s2, at)
	s2.truck(0).star = 13
	Save.write_file(TEST_SAVE, s2, at)   # 앞의 것은 bak1으로
	_write(TEST_SAVE, "{ 이건 깨진 파일")
	m = await _launch()
	_report(m.state.truck(0).star == 12 and m.popup.visible and m.popup.main_text() == tr("LOAD_RECOVERED") % "save.json.broken"
			and m.popup.note_text().contains(tr("RETURN_DETAIL") % [m.offline_report["parcels"], m.offline_report["spares"]])
			and FileAccess.file_exists(TEST_SAVE + ".broken"),
			"③ 본 파일이 깨짐 → 백업에서 +%d로 살림, 복귀 창 '%s' / '%s'" % [
			m.state.truck(0).star, m.popup.main_text().replace("\n", " / "), m.popup.note_text().replace("\n", " / ")])
	_check(Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()), "백업 복구 안내가 작은 화면 밖: %s" % m.popup.get_rect())
	await _close(m)

	# 5) 백업까지 전부 깨짐 → 새로 시작 + 알림, .broken 으로 남김
	_clean()
	_write(TEST_SAVE, "{ 이건 깨진 파일")
	m = await _launch()
	_check(m.state.truck(0).star == 0 and m.state.money < Trip.lap_income(b, m.state, 0), "깨진 저장인데 새로 시작 안 함")
	_check(m.popup.visible and m.popup.main_text() == tr("LOAD_BROKEN") % "save.json.broken", "깨진 저장 알림이 없음: '%s'" % m.popup.main_text())
	_check(Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).encloses(m.popup.get_rect()), "깨진 저장 알림이 작은 화면 밖: %s" % m.popup.get_rect())
	_check(FileAccess.file_exists(TEST_SAVE + ".broken"), "깨진 파일을 .broken 으로 안 남김")

	# 6) F3 → 저장 초기화
	m.state.truck(0).star = 12
	m._save()
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(m.state.truck(0).star == 0, "F3 뒤 +0이 아님")
	var r2 := Save.read_file(TEST_SAVE, m.balance)
	_check(r2["status"] == Save.Status.OK and r2["state"].truck(0).star == 0, "F3 뒤 저장 파일이 처음 상태가 아님")
	await _close(m)

	_clean()
	DirAccess.remove_absolute(TEST_DIR)
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for x in fails:
		print("  [실패] " + x)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## 시험용 폴더의 저장·백업·깨진 파일·옛 형식 파일을 전부 지움
func _clean() -> void:
	Save.delete_file(TEST_SAVE)
	for p in [TEST_SAVE + ".broken", OLD_KEPT]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


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


func _report(ok: bool, text: String) -> void:
	_check(ok, text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)
