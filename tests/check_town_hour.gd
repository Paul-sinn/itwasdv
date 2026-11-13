## v3 U2 완료 기준 ①④ 자동 확인: 동네를 게임 시간 1시간 돌렸을 때
## ① 번 돈이 Trip.hourly_income과 한 바퀴치(Trip.lap_income) 안쪽인가 (+0/+10/+20/+30, 화면을 오가도)
##    "+돈" 글자 수 = 계산 쪽 배송 이벤트 수 = 번 돈 ÷ 배송 1건 돈, "+돈"이 뜰 때 트럭이 그 집 앞에 서 있나
## ④ 화면 트럭 속도가 +30에서도(순간 가속 중에도) feel.gd 상한을 안 넘나
## 진짜 게임 화면(main.tscn)을 작은 화면 크기로 띄우고, F2와 같은 60배속 측정을 켠 뒤 1시간치를 돌린다.
##
## 실행 (--fixed-fps 60 + 60배속 = 한 프레임에 게임 1초 → 몇 초 만에 끝남):
##   <GODOT_CONSOLE> --headless --path <프로젝트> --fixed-fps 60 -s tests/check_town_hour.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const TEST_SAVE := "user://test_town_hour.json"
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SETTINGS := "user://test_town_settings.cfg"   ## 진짜 설정 파일 말고 (읽기만 하지만 따로)
## switch = 몇 프레임마다 작은 ↔ 큰 화면을 오가나 (0 = 안 오감), boost = 시작할 때 강화 성공 순간 가속을 켬
const CASES := [
	{ "star": 0, "switch": 0 },
	{ "star": 10, "switch": 0 },
	{ "star": 20, "switch": 0 },
	{ "star": 30, "switch": 0, "boost": true },
	{ "star": 20, "switch": 97 },
]

const MAX_FRAMES := 200000      # 무슨 일이 있어도 이 프레임 수가 지나면 실패로 끝냄 (멈춤 방지)

var _main: Node
var _case := 0
var _all_ok := true
var _frames := 0
var _case_frames := 0
var _switches := 0
var _max_speed_ratio := 0.0   ## 화면 트럭 속도 ÷ 상한 중 가장 큰 값
var _start_counts := {}


func _initialize() -> void:
	process_frame.connect(_on_frame)
	# 트리가 돌기 시작한 뒤에 띄워야 main의 _ready가 바로 불린다
	_start.call_deferred()


func _start() -> void:
	# 화면 없이(--headless) 띄우면 창이 64x64 → 작은 화면 크기로 맞춘다
	root.size = Feel.SMALL_SIZE
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)   # screen_mode.gd에 settings_path가 없으면 아무 일 없음
	_main = load(MAIN_SCENE).instantiate()
	Save.delete_file(TEST_SAVE)
	_main.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(_main)
	if _main.state == null:
		print("[실패] main을 띄웠는데 상태가 없음 (balance.json 문제?)")
		quit(1)
		return
	# 화면 없는 실행에서는 창 크기가 안 바뀌므로 창 담당 대신 바꿔 준다
	_main.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == 0 else Feel.WINDOWED_FULL_SIZE)
	var c: Dictionary = CASES[_case]
	_main.state.truck(0).star = c["star"]
	_main.rng.seed = 20261113 + _case
	if c.get("boost", false):
		_main.town.truck.boost(Feel.BOOST_MULT, Feel.BOOST_DURATION)
	_switches = 0
	_case_frames = 0
	_max_speed_ratio = 0.0
	var town = _main.town
	_start_counts = { "shown": town.payouts_shown, "at_truck": town.payouts_at_truck, "parcels": _main.parcels_total }
	_main._toggle_fast_time()   # F2 누른 것과 같음: 60배속 + 측정 시작


func _on_frame() -> void:
	_frames += 1
	if _frames > MAX_FRAMES:
		print("[실패] %d프레임 안에 끝나지 않음" % MAX_FRAMES)
		quit(1)
		return
	if _main == null:
		return
	_case_frames += 1
	var truck = _main.town.truck
	_max_speed_ratio = maxf(_max_speed_ratio, truck.speed() / truck.speed_cap())
	var every: int = CASES[_case]["switch"]
	if every > 0 and _case_frames % every == 0:
		if _main.is_full():
			_main.screen.enter_small()
		else:
			_main.screen.enter_full()
		_switches += 1
	if _main._measure_seconds < 3600.0:
		return

	var b = _main.balance
	var t = _main.state.truck(0)
	var town = _main.town
	var what := "+%d%s" % [t.star, " (화면 %d번 오감)" % _switches if _switches > 0 else ""]
	var hourly := Trip.hourly_income(b, t)
	var seconds: float = _main._measure_seconds
	var earned: int = _main._measure_earned
	var expected := hourly * seconds / 3600.0
	var lap := Trip.lap_income(b, t)
	_report(absf(_main._measure_hourly - hourly) < 1e-9, "%s: 측정에 쓴 시간당 수입 = Trip.hourly_income %.1f" % [what, hourly])
	_report(absf(earned - expected) <= lap,
			"%s: ① 게임 %.0f초 동안 번 돈 %d / Trip.hourly_income으로 계산한 값 %.1f → 차이 %.1f (한 바퀴치 %d 안쪽)" % [
			what, seconds, earned, expected, absf(earned - expected), lap])
	var shown: int = town.payouts_shown - _start_counts["shown"]
	var events: int = _main.parcels_total - _start_counts["parcels"]
	var pay := Trip.parcel_pay(b)
	# 측정을 켜기 전 프레임에 배송이 났을 수 있어서, 번 돈은 측정 뒤 것만 나눔
	_report(shown == events and events > 0 and earned % pay == 0,
			"%s: ① '+돈' 글자 %d개 = 배송 이벤트 %d번 (측정 뒤 번 돈 ÷ 배송 1건 %d원 = %d건)" % [what, shown, events, pay, earned / pay])
	var at_truck: int = town.payouts_at_truck - _start_counts["at_truck"]
	_report(at_truck == shown, "%s: '+돈'이 뜰 때 트럭이 그 집 앞에 서 있었음 %d / %d번" % [what, at_truck, shown])
	if t.star == b.max_star:
		_report(_max_speed_ratio <= 1.0 + 1e-6 and _max_speed_ratio > 0.0,
				"%s: ④ 화면 트럭 속도가 상한(feel.gd TOWN_DRIVE_SECONDS_MIN)을 안 넘음 (순간 가속 포함, 최대 %.2f배)" % [what, _max_speed_ratio])

	_main._toggle_fast_time()   # 배속 끄기
	root.remove_child(_main)    # 바로 빼야 이번 프레임에 옛 트럭이 또 움직이지 않음
	_main.queue_free()
	_main = null
	_case += 1
	if _case < CASES.size():
		_start.call_deferred()
	else:
		Save.delete_file(TEST_SAVE)
		print("전부 통과" if _all_ok else "실패 있음")
		quit(0 if _all_ok else 1)


func _report(ok: bool, text: String) -> void:
	_all_ok = _all_ok and ok
	print("%s %s" % ["[통과]" if ok else "[실패]", text])
