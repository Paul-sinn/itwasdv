## 화면 없이 테스트 실행:
##   <GODOT_CONSOLE> --headless --path . -s tests/run_tests.gd
## 전부 통과하면 종료 코드 0, 하나라도 실패하면 1.
extends SceneTree

const TEST_FILES := [
	"res://tests/test_balance.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_enhance.gd",
	"res://tests/test_fmt.gd",
	"res://tests/test_save.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	var started := Time.get_ticks_msec()

	for path in TEST_FILES:
		print("\n== %s" % path.get_file())
		var script: GDScript = load(path)
		if script == null:
			print("  [실패] 파일을 불러올 수 없음")
			failed += 1
			continue
		for m in script.get_script_method_list():
			var test_name: String = m["name"]
			if not test_name.begins_with("test_"):
				continue
			var suite = script.new()
			var t0 := Time.get_ticks_msec()
			suite.call(test_name)
			var ms := Time.get_ticks_msec() - t0
			total += 1
			# 확인을 한 번도 못 했으면 중간에 스크립트 오류로 멈춘 것
			if suite.check_count == 0:
				suite.failures.append("확인을 하나도 못 함 (위에 스크립트 오류가 있는지 볼 것)")
			if suite.failures.is_empty():
				print("  [통과] %s  (확인 %d개, %dms)" % [test_name, suite.check_count, ms])
			else:
				failed += 1
				print("  [실패] %s" % test_name)
				for f in suite.failures:
					print("      - %s" % f)
			for note in suite.notes:
				print("      · %s" % note)

	print("\n테스트 %d개 중 %d개 통과, %d개 실패  (%.1f초)"
			% [total, total - failed, failed, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed > 0 else 0)
