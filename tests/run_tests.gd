## 화면 없이 테스트 실행:
##   <GODOT_CONSOLE> --headless --path . -s tests/run_tests.gd
## 전부 통과하면 종료 코드 0, 하나라도 실패하면 1.
## 실행 중 스크립트 오류(SCRIPT ERROR)·엔진 오류(ERROR)가 난 테스트는 확인이 다 맞아도 실패 (경고 push_warning은 안 셈).
extends SceneTree


## 오류 감시: tests/error_watch.gd(확인 스크립트용)와 같은 Logger 방식. 그쪽은 오류가 나면 바로 끝내지만,
## 여기는 테스트마다 그사이 난 오류를 모아 그 테스트의 실패로 적고 다음 테스트로 간다 (어느 테스트에서 났는지 보이게)
class Watch extends Logger:
	var _errors := PackedStringArray()
	var _lock := Mutex.new()   # 여러 스레드에서 불릴 수 있음

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		_errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_lock.unlock()

	## 모인 오류를 꺼내고 비운다
	func take() -> PackedStringArray:
		_lock.lock()
		var out := _errors
		_errors = PackedStringArray()
		_lock.unlock()
		return out

const TEST_FILES := [
	"res://tests/test_balance.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_enhance.gd",
	"res://tests/test_trip.gd",
	"res://tests/test_setting.gd",
	"res://tests/test_driver.gd",
	"res://tests/test_ability.gd",
	"res://tests/test_v6b.gd",
	"res://tests/test_company.gd",
	"res://tests/test_master.gd",
	"res://tests/test_visitor.gd",
	"res://tests/test_city.gd",
	"res://tests/test_long.gd",
	"res://tests/test_contract.gd",
	"res://tests/test_upgrade.gd",
	"res://tests/test_depot.gd",
	"res://tests/test_quest.gd",
	"res://tests/test_fmt.gd",
	"res://tests/test_save.gd",
	"res://tests/test_click_region.gd",
	"res://tests/test_route.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	var watch := Watch.new()
	OS.add_logger(watch)

	for path in TEST_FILES:
		print("\n== %s" % path.get_file())
		watch.take()
		var script: GDScript = load(path)
		var load_errors := watch.take()
		# 문법 오류가 있는 파일도 load는 null이 아닌 걸 돌려줘서, 테스트가 하나도 안 돌고 통과로 보였음
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			print("  [실패] 파일을 불러올 수 없음 (위에 문법 오류가 있는지 볼 것)")
			for e in load_errors:
				print("      - 불러올 때 오류: %s" % e)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var test_name: String = m["name"]
			if not test_name.begins_with("test_"):
				continue
			watch.take()
			var suite = script.new()
			var t0 := Time.get_ticks_msec()
			suite.call(test_name)
			var ms := Time.get_ticks_msec() - t0
			total += 1
			# 확인을 한 번도 못 했으면 중간에 스크립트 오류로 멈춘 것
			if suite.check_count == 0:
				suite.failures.append("확인을 하나도 못 함 (위에 스크립트 오류가 있는지 볼 것)")
			# 오류 난 함수만 멈추고 부른 쪽은 계속 가서, 확인이 다 맞은 채로 끝날 수 있음
			for e in watch.take():
				suite.failures.append("실행 중 오류: %s" % e)
			if suite.failures.is_empty():
				print("  [통과] %s  (확인 %d개, %dms)" % [test_name, suite.check_count, ms])
			else:
				failed += 1
				print("  [실패] %s" % test_name)
				for f in suite.failures:
					print("      - %s" % f)
			for note in suite.notes:
				print("      · %s" % note)

	OS.remove_logger(watch)   # 끝낼 때 엔진이 찍는 정리 메시지는 세지 않음
	print("\n테스트 %d개 중 %d개 통과, %d개 실패  (%.1f초)"
			% [total, total - failed, failed, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed > 0 else 0)
