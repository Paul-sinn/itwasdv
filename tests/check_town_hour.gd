## v1 1단계 완료 기준 자동 확인: 동네를 게임 시간 1시간 돌렸을 때 번 돈이 "시간당 수익"과 1% 안쪽인가?
## 진짜 게임 화면(main.tscn)을 작은 화면 크기로 띄우고, F2와 같은 60배속 측정을 켠 뒤 1시간치를 돌린다.
## 같이 보는 것: 집을 1 → 2 → … → 5 → (물류센터) → 1 순서로 들르나, 집 앞에서 서는 시간이 들어갔나,
## 화면을 오가도(작은 ↔ 큰) 돈이 그대로 맞나.
## v2 3단계: 튜닝
##   - 대박 없음(타이어 일반) + 터보 등급마다: 1시간 수익이 "엔진 수익 × (1 + 터보)"와 1% 안쪽
##   - 대박 있음(타이어·짐칸 전설, 난수 seed 고정, 10시간): 평균이 "평균 시간당 수익"과 5% 안쪽,
##     대박 비율이 타이어 확률 근처, 대박마다 "대박!" 글자
##
## 실행 (--fixed-fps 60 + 60배속 = 한 프레임에 게임 1초 → 몇 초 만에 끝남):
##   <GODOT_CONSOLE> --headless --path <프로젝트> --fixed-fps 60 -s tests/check_town_hour.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Tune = preload("res://scripts/core/tune.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const TEST_SAVE := "user://test_town_hour.json"
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SETTINGS := "user://test_town_settings.cfg"   ## 진짜 설정 파일 말고 (읽기만 하지만 따로)
## 강수가 오르면 트럭이 빨라져도 수익은 같아야 함. switch = 몇 프레임마다 작은 ↔ 큰 화면을 오가나 (0 = 안 오감)
## tune = 부위 → 등급 (없으면 전부 일반), hours = 게임 몇 시간, tol = 허용 오차, seed = 난수 고정 (대박)
const CASES := [
	{ "star": 0, "switch": 0 },
	{ "star": 10, "switch": 0 },
	{ "star": 20, "switch": 0 },
	{ "star": 30, "switch": 0 },
	{ "star": 20, "switch": 97 },
	{ "star": 10, "switch": 0, "tune": { "turbo": 1 } },
	{ "star": 10, "switch": 0, "tune": { "turbo": 2 } },
	{ "star": 10, "switch": 0, "tune": { "turbo": 3 } },
	{ "star": 10, "switch": 0, "tune": { "tire": 3, "cargo": 3 }, "hours": 10, "tol": 0.05, "seed": 20261112 },
]
const TOLERANCE := 0.01

const MAX_FRAMES := 200000      # 무슨 일이 있어도 이 프레임 수가 지나면 실패로 끝냄 (멈춤 방지)

var _main: Node
var _case := 0
var _all_ok := true
var _frames := 0
var _case_frames := 0
var _visits: Array[int] = []
var _max_payouts := 0
var _switches := 0
var _jackpot_labels0 := 0


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
	_main.state.star = c["star"]
	var tune: Dictionary = c.get("tune", {})
	for part in tune:
		_main.state.set_grade(_main.balance, part, tune[part])
	if c.has("seed"):
		_main.rng.seed = c["seed"]
	_jackpot_labels0 = _main.town.jackpots_shown
	_visits.clear()
	_max_payouts = 0
	_switches = 0
	_case_frames = 0
	_main.town.truck.delivered.connect(func(house: int, _s: float): _visits.append(house))
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
	_max_payouts = maxi(_max_payouts, _main.town.payout_count())
	var every: int = CASES[_case]["switch"]
	if every > 0 and _case_frames % every == 0:
		if _main.is_full():
			_main.screen.enter_small()
		else:
			_main.screen.enter_full()
		_switches += 1
	var c: Dictionary = CASES[_case]
	if _main._measure_seconds < 3600.0 * c.get("hours", 1.0):
		return

	var b = _main.balance
	var st = _main.state
	var star: int = st.star
	var hourly: float = _main._measure_hourly
	var earned: float = _main._measure_earned
	var seconds: float = _main._measure_seconds
	var tol: float = c.get("tol", TOLERANCE)
	var tune: Dictionary = c.get("tune", {})
	var tune_text := ""
	for part in tune:
		tune_text += " %s %s" % [part, Tune.grade_name(b, tune[part])]
	var what := "%2d강%s%s" % [star, tune_text, " (화면 %d번 오감)" % _switches if _switches > 0 else ""]
	# 기대 시간당 수익: 대박이 없으면 "엔진 수익 × (1 + 터보)"를 여기서 따로 계산해서 비교,
	# 대박이 있으면 "평균 시간당 수익"(state.current_hourly)
	var turbo := Tune.effect(b, "turbo", st.grade("turbo"))
	var steady := Economy.hourly_income(b, star) * (1.0 + turbo)
	var chance: float = st.jackpot_chance(b)
	var want_hourly := steady
	if chance > 0.0:
		want_hourly = steady * (1.0 + chance * (st.jackpot_mult(b) - 1.0))
		_report(absf(st.current_hourly(b) - want_hourly) <= want_hourly * 1e-9,
				"%s: 평균 시간당 수익 %.1f = 엔진 × (1 + 터보) × (1 + 타이어 × (짐칸 − 1)) %.1f" % [what, st.current_hourly(b), want_hourly])
	_report(absf(hourly - want_hourly) <= want_hourly * 1e-9,
			"%s: 측정에 쓴 시간당 수익 %.1f = 기대 %.1f" % [what, hourly, want_hourly])
	var expected := want_hourly * seconds / 3600.0
	var diff := absf(earned - expected) / expected
	_report(diff <= tol, "%s: 게임 %.0f초 동안 번 돈 %.1f / 시간당 수익으로 계산한 값 %.1f → 차이 %.2f%% (허용 %s%%)" % [
		what, seconds, earned, expected, diff * 100.0, str(tol * 100.0)])
	if chance > 0.0:
		var jackpots: int = st.jackpot_count
		var ratio := float(jackpots) / maxf(1.0, _visits.size())
		_report(absf(ratio - chance) <= 0.02, "%s: 대박 %d번 / 배송 %d번 = %.1f%% (타이어 확률 %.0f%%)" % [
			what, jackpots, _visits.size(), ratio * 100.0, chance * 100.0])
		_report(_main.town.jackpots_shown - _jackpot_labels0 == jackpots,
				"%s: 대박 %d번마다 '대박!' 글자 (%d번)" % [what, jackpots, _main.town.jackpots_shown - _jackpot_labels0])
	else:
		_report(st.jackpot_count == 0 and _main.town.jackpots_shown == _jackpot_labels0, "%s: 타이어 일반인데 대박이 나옴" % what)

	# 집 순서: 0,1,2,3,4,0,1,... (물류센터에서는 안 받음)
	var order_ok := not _visits.is_empty()
	for i in _visits.size():
		if _visits[i] != i % Feel.TOWN_HOUSES:
			if order_ok: print("  순서 어긋남 %d번째: %s" % [i, _visits.slice(maxi(0, i - 7), i + 4)])
			order_ok = false
	_report(order_ok, "%s: 집 들른 순서 1→%d 반복 (%d번 들름)" % [what, Feel.TOWN_HOUSES, _visits.size()])

	# 한 바퀴 = 달리는 시간 + 집마다 TOWN_STOP_SECONDS + 물류센터. 서는 시간이 빠지면 들른 횟수가 많아짐
	var loop := Feel.town_drive_seconds(star) + Feel.TOWN_HOUSES * Feel.TOWN_STOP_SECONDS + Feel.TOWN_DEPOT_STOP_SECONDS
	var want := seconds / loop * Feel.TOWN_HOUSES
	_report(absf(_visits.size() - want) <= Feel.TOWN_HOUSES + 1,
			"%s: 1시간에 집 %d번 들름 (한 바퀴 %.1f초로 계산하면 약 %.0f번)" % [what, _visits.size(), loop, want])
	_report(_max_payouts > 0, "%s: '+금액'이 떴음" % what)

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
