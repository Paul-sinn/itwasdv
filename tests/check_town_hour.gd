## v3 U2 완료 기준 ①④ 자동 확인: 동네를 게임 시간 1시간 돌렸을 때
## ① 번 돈이 Trip.hourly_income과 한 바퀴치(Trip.lap_income) 안쪽인가 (+0/+10/+20/+30, 화면을 오가도)
##    "+돈" 글자 수 = 계산 쪽 배송 이벤트 수 = 번 돈 ÷ 배송 1건 돈, 화면 트럭이 계산 쪽 바퀴 진행을 따라가나
## ④ 화면 트럭 속도가 +30에서도 feel.gd 상한을 안 넘나
## v4: 오버부스트(ECU 프로토타입 3줄)가 걸린 바퀴마다 "오버부스트!" 글자, 1시간 돈이 평균 시간당 수입과 맞나
## v6-bal U1 ②: 오버부스트가 걸린 바퀴 내내 트럭 뒤 불꽃 (10초가 아니라), 다음 안 걸린 바퀴에서 꺼짐
##     작은 화면 트럭 뒤 불꽃(오버부스트·강화 성공)이 가장 길 때도 보이는 곳(main.visible_rects) 안인가
## 진짜 게임 화면(main.tscn)을 작은 화면 크기로 띄우고, F2와 같은 60배속 측정을 켠 뒤 1시간치를 돌린다.
##
## 실행 (--fixed-fps 60 + 60배속 = 한 프레임에 게임 1초 → 몇 초 만에 끝남):
##   <GODOT_CONSOLE> --headless --path <프로젝트> --fixed-fps 60 -s tests/check_town_hour.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const TEST_SAVE := "user://test_town_hour.json"
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SETTINGS := "user://test_town_settings.cfg"   ## 진짜 설정 파일 말고 (읽기만 하지만 따로)
## switch = 몇 프레임마다 작은 ↔ 큰 화면을 오가나 (0 = 안 오감), flame = 시작할 때 강화 성공 불꽃을 켬,
## overboost = ECU 프로토타입에 오버부스트 3줄 (바퀴마다 굴려서 돈이 흔들림 → 허용 laps 바퀴치)
const CASES := [
	{ "star": 0, "switch": 0 },
	{ "star": 10, "switch": 0 },
	{ "star": 20, "switch": 0 },
	{ "star": 30, "switch": 0, "flame": true },
	{ "star": 20, "switch": 97 },
	{ "star": 10, "switch": 0, "overboost": true, "laps": 2 },
]

const MAX_FRAMES := 200000      # 무슨 일이 있어도 이 프레임 수가 지나면 실패로 끝냄 (멈춤 방지)

var _main: Node
var _case := 0
var _all_ok := true
var _frames := 0
var _case_frames := 0
var _switches := 0
var _max_speed_ratio := 0.0   ## 화면 트럭 속도 ÷ 상한 중 가장 큰 값
var _max_lag := 0.0           ## 화면 트럭이 있어야 할 자리보다 가장 많이 뒤처진 거리 (설계 좌표 픽셀)
var _start_counts := {}
var _flame_frames := 0        ## 작은 화면에서 불꽃이 나온 프레임 수
var _flame_out := 0           ## 그중 가장 긴 불꽃이 보이는 곳 밖으로 나간 프레임 수
## v6-bal U1 ② (오버부스트 경우만): 걸린 바퀴 / 안 걸린 바퀴 동안 불꽃
var _boost_frames := 0        ## 걸린 바퀴 동안 프레임 수
var _boost_dark := 0          ## 그중 불꽃이 없던 프레임 수
var _boost_run := 0.0         ## 지금 걸린 바퀴가 이어진 게임 초
var _boost_run_max := 0.0     ## 가장 길게 이어진 걸린 바퀴 (게임 초)
var _plain_frames := 0        ## 안 걸린 바퀴 동안 프레임 수
var _plain_lit := 0           ## 그중 불꽃이 있던 프레임 수
var _boost_ends := 0          ## 걸린 바퀴 → 안 걸린 바퀴로 바뀐 번 수
var _was_boost := false


func _initialize() -> void:
	OS.add_logger(ErrorWatch.new(self))
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
	if c.get("flame", false):
		_main.town.truck.boost(Feel.BOOST_DURATION)
	if c.get("overboost", false):
		var ecu: Dictionary = _main.state.truck(0).part("ecu")
		ecu["grade"] = 4
		ecu["lines"] = ["overboost", "overboost", "overboost"]
	_switches = 0
	_case_frames = 0
	_max_speed_ratio = 0.0
	_max_lag = 0.0
	_flame_frames = 0
	_flame_out = 0
	_boost_frames = 0
	_boost_dark = 0
	_boost_run = 0.0
	_boost_run_max = 0.0
	_plain_frames = 0
	_plain_lit = 0
	_boost_ends = 0
	_was_boost = false
	var town = _main.town
	_start_counts = { "shown": town.payouts_shown, "boosts": town.boosts_shown, "parcels": _main.parcels_total, "boost_events": _main.boosts_found }
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
	_max_lag = maxf(_max_lag, truck.lag())
	# 작은 화면은 보이는 곳 사각형 밖이 안 그려짐 → 가장 긴 불꽃(창 안쪽 부분)이 사각형 하나 안에 들어가나
	var flame: Rect2 = truck.flame_rect()
	if flame.has_area() and not _main.is_full():
		_flame_frames += 1
		var v := Rect2(flame.position + _main.town.position + _main.position, flame.size).intersection(Rect2(Vector2.ZERO, Vector2(root.size)))
		if v.has_area() and not _main.visible_rects().any(func(r: Rect2): return r.encloses(v)):
			_flame_out += 1
	# 오버부스트: 계산 쪽 바퀴(boost_lap)가 걸린 동안 불꽃이 늘 있고, 안 걸린 바퀴에서는 없나 (main이 지난 프레임에 맞춰 둔 값)
	if CASES[_case].get("overboost", false):
		var on: bool = _main.state.truck(0).boost_lap
		var lit: bool = flame.has_area()
		if on:
			_boost_frames += 1
			_boost_dark += 0 if lit else 1
			_boost_run += Engine.time_scale / 60.0   # --fixed-fps 60: 한 프레임 = 1/60초 × 배속
			_boost_run_max = maxf(_boost_run_max, _boost_run)
		else:
			_plain_frames += 1
			_plain_lit += 1 if lit else 0
			_boost_ends += 1 if _was_boost else 0
			_boost_run = 0.0
		_was_boost = on
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
	var lap: int = Trip.lap_income(b, t) * CASES[_case].get("laps", 1)
	_report(absf(_main._measure_hourly - hourly) < 1e-9, "%s: 측정에 쓴 시간당 수입 = Trip.hourly_income %.1f" % [what, hourly])
	_report(absf(earned - expected) <= lap,
			"%s: ① 게임 %.0f초 동안 번 돈 %d / Trip.hourly_income으로 계산한 값 %.1f → 차이 %.1f (%d 안쪽)" % [
			what, seconds, earned, expected, absf(earned - expected), lap])
	var shown: int = town.payouts_shown - _start_counts["shown"]
	var events: int = _main.parcels_total - _start_counts["parcels"]
	var pay := Trip.parcel_pay(b, t)
	# 측정을 켜기 전 프레임에 배송이 났을 수 있어서, 번 돈은 측정 뒤 것만 나눔
	_report(shown == events and events > 0 and earned % pay == 0,
			"%s: ① '+돈' 글자 %d개 = 배송 이벤트 %d번 (측정 뒤 번 돈 ÷ 배송 1건 %d원 = %d건)" % [what, shown, events, pay, earned / pay])
	_report(_max_lag <= 1.0, "%s: 화면 트럭이 계산 쪽 바퀴 진행을 따라감 (가장 많이 뒤처진 거리 %.1f픽셀)" % [what, _max_lag])
	if CASES[_case].get("overboost", false):
		var boosts: int = town.boosts_shown - _start_counts["boosts"]
		var boost_events: int = _main.boosts_found - _start_counts["boost_events"]
		_report(boosts == boost_events and boosts > 0, "%s 오버부스트 (ECU 프로토타입 3줄): '오버부스트!' 글자 %d개 = 이벤트 %d번" % [what, boosts, boost_events])
		_report(_boost_frames > 0 and _boost_dark == 0 and _boost_run_max > 10.0 and _plain_frames > 0 and _plain_lit == 0 and _boost_ends > 0,
				"%s: v6-bal U1 ② 오버부스트 걸린 바퀴 내내 불꽃 (%d프레임 중 꺼짐 %d, 가장 길게 이어진 불꽃 게임 %.0f초 > 10초), 안 걸린 바퀴에서는 꺼짐 (%d프레임 중 켜짐 %d, 걸린 바퀴 → 안 걸린 바퀴 %d번)" % [
				what, _boost_frames, _boost_dark, _boost_run_max, _plain_frames, _plain_lit, _boost_ends])
	if CASES[_case].get("flame", false) or CASES[_case].get("overboost", false):
		_report(_flame_frames > 0 and _flame_out == 0,
				"%s: 작은 화면 불꽃이 가장 길 때도 보이는 곳 안 (불꽃 %d프레임 확인, 밖으로 나감 %d번)" % [what, _flame_frames, _flame_out])
	if t.star == b.max_star:
		_report(_max_speed_ratio <= 1.0 + 1e-6 and _max_speed_ratio > 0.0,
				"%s: ④ 화면 트럭 속도가 상한(feel.gd TOWN_DRIVE_SECONDS_MIN)을 안 넘음 (상한의 최대 %.2f배)" % [what, _max_speed_ratio])

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
