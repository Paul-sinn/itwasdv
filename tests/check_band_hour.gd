## 2단계 완료 기준 자동 확인: 띠를 게임 시간 1시간 돌렸을 때 번 돈이 "시간당 수익"과 1% 안쪽인가?
## 진짜 게임 화면(main.tscn)을 띄우고, F2와 같은 60배속 측정을 켠 뒤 1시간치를 돌린다.
##
## 실행 (--fixed-fps 60 + 60배속 = 한 프레임에 게임 1초 → 몇 초 만에 끝남):
##   <GODOT_CONSOLE> --headless --path <프로젝트> --fixed-fps 60 -s tests/check_band_hour.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const TEST_SAVE := "user://test_check_save.json"
const GAME_SECONDS := 3600.0
const TOLERANCE := 0.01
const STARS_TO_CHECK := [0, 10, 20, 30]   # 강수가 오르면 트럭이 빨라져도 수익은 같아야 함

const MAX_FRAMES := 100000      # 무슨 일이 있어도 이 프레임 수가 지나면 실패로 끝냄 (멈춤 방지)

var _main: Node
var _star_index := 0
var _all_ok := true
var _frames := 0


func _initialize() -> void:
	process_frame.connect(_on_frame)
	# 트리가 돌기 시작한 뒤에 띄워야 main의 _ready가 바로 불린다
	_start.call_deferred(STARS_TO_CHECK[0])


func _start(star: int) -> void:
	# 화면 없이(--headless) 띄우면 창이 64x64라서 트럭 길이가 0 → 진짜 창 크기로 맞춘다
	# (_initialize에서 바꾸면 첫 프레임에 다시 64x64로 돌아가서 여기서 바꿈)
	root.size = Vector2i(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	_main = load(MAIN_SCENE).instantiate()
	Save.delete_file(TEST_SAVE)
	_main.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(_main)
	if _main.state == null:
		print("[실패] main을 띄웠는데 상태가 없음 (balance.json 문제?)")
		quit(1)
		return
	_main.state.star = star
	_main._toggle_fast_time()   # F2 누른 것과 같음: 60배속 + 측정 시작


func _on_frame() -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		print("[실패] %d프레임 안에 끝나지 않음" % MAX_FRAMES)
		quit(1)
		return
	if _main == null or _main._measure_seconds < GAME_SECONDS:
		return
	var star: int = _main.state.star
	var hourly: float = _main._measure_hourly
	var earned: float = _main._measure_earned
	var seconds: float = _main._measure_seconds
	var expected := hourly * seconds / 3600.0
	var diff := absf(earned - expected) / expected
	var ok := diff <= TOLERANCE
	_all_ok = _all_ok and ok
	print("%s %2d강: 게임 %.0f초 동안 번 돈 %.1f / 시간당 수익으로 계산한 값 %.1f → 차이 %.2f%% (허용 1%%)" % [
		"[통과]" if ok else "[실패]", star, seconds, earned, expected, diff * 100.0])

	_main._toggle_fast_time()   # 배속 끄기
	_main.queue_free()
	_main = null
	_star_index += 1
	if _star_index < STARS_TO_CHECK.size():
		_start.call_deferred(STARS_TO_CHECK[_star_index])
	else:
		Save.delete_file(TEST_SAVE)
		print("전부 통과" if _all_ok else "실패 있음")
		quit(0 if _all_ok else 1)
