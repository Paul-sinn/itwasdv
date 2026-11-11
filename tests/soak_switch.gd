## 4단계 오래 켜두기용 (tests/soak_desktop.ps1 이 실행함)
## 진짜 게임(main)을 작은 화면으로 띄워 두고, 원하면 N분마다 큰 화면에 잠깐 들어갔다 나온다.
## 큰 화면 방식은 번갈아 (전체 화면 → 창 모드 → 전체 화면 …).
## 진짜 저장·설정 파일은 안 건드린다 (따로 쓰고, 지우는 건 soak_desktop.ps1이 끝나고 함).
##
## 인자 (-- 뒤에): --switch-every <분>  0이면 안 오감 (소수도 됨)
##                 --minutes <분>       이만큼 + 2분 지나면 저절로 끝 (PowerShell이 먼저 죽었을 때 대비)
## 출력: "PID n", 오갈 때마다 "SWITCH 번호 방식"
extends SceneTree

const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

const TEST_SAVE := "user://test_window_soak.json"
const TEST_SETTINGS := "user://test_window_soak.cfg"
const FULL_SECONDS := 3.0        ## 큰 화면에 머무는 초

var m: Node
var switches := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var every := _arg("--switch-every", 0.0)
	var minutes := _arg("--minutes", 120.0)
	print("PID ", OS.get_process_id())
	ScreenMode.settings_path = TEST_SETTINGS
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	root.add_child(m)
	# 진짜 시간 기준 (F2 배속과 상관없이)
	create_timer((minutes + 2.0) * 60.0, true, false, true).timeout.connect(_finish)
	if every <= 0.0:
		return
	_every = every * 60.0
	_timer = Timer.new()
	_timer.ignore_time_scale = true
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_on_timer)
	root.add_child(_timer)
	_timer.start(_every)


var _timer: Timer
var _every := 0.0


## 작은 화면이면 큰 화면으로 (FULL_SECONDS 뒤 돌아옴), 큰 화면이면 작은 화면으로 (_every 뒤 다시)
func _on_timer() -> void:
	if m.screen.mode == ScreenMode.Mode.SMALL:
		var style := ScreenMode.FullStyle.FULLSCREEN if switches % 2 == 0 else ScreenMode.FullStyle.WINDOWED
		m.screen.set_full_style(style)
		m.screen.enter_full()
		_timer.start(FULL_SECONDS)
	else:
		m.screen.enter_small()
		switches += 1
		print("SWITCH %d %s" % [switches, ScreenMode.STYLE_NAMES[m.screen.full_style]])
		_timer.start(_every)


## 끝내기 (알림 영역 메뉴 "끝내기"와 같은 길: 저장하고 끝)
func _finish() -> void:
	print("저절로 끝 (시간 다 됨)")
	m.screen.quit_game()


func _arg(name: String, fallback: float) -> float:
	var a := OS.get_cmdline_user_args()
	var i := a.find(name)
	return float(a[i + 1]) if i >= 0 and i + 1 < a.size() else fallback
