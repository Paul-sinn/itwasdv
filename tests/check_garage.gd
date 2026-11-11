## v1 3단계 완료 기준 자동 확인: 큰 화면 차고에서 0강~30강, 퍼짐 → 수리까지 전부 눌러볼 수 있나?
## 진짜 게임 화면(main.tscn)에 진짜 키·마우스 입력을 넣어서 확인한다.
## - 작은 화면: 차고 안 보임, 보이는 곳 사각형 30개 이하, 치트 F1~F5, 복귀 팝업이 480x220 안
## - 작은 화면 클릭 → 큰 화면 (차고 + [설정] + [작게])
## - 0~30강, 퍼짐 → 수리, 스페어값 남기기 규칙, 강화 뜸·결과·통계
## - 창 크기 1280x720 / 1600x900 / 1920x1080 / 3440x1440 + 창 모드에서 아무렇게나 바꾼 크기에서
##   차고·동네·버튼이 창 안에 다 들어오고 서로 안 겹치나
## - [설정] → 전체 화면 / 창 모드 고르기, [작게] → 작은 화면
## 화면 없는 실행에서는 창 크기가 안 바뀌므로, 화면이 바뀔 때 이 스크립트가 창 크기를 대신 바꿔 준다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_garage.gd
extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const TEST_SAVE := "user://test_town_garage.json"
const TEST_SETTINGS := "user://test_town_settings.cfg"   ## [설정]에서 고른 값이 저장되는 곳 (진짜 설정 말고)
const FULL_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(3440, 1440)]
const WINDOWED_SIZES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1500, 1000), Vector2i(2200, 800), Vector2i(1280, 1300)]
const MAX_RECTS := 30

var m: Node
var fails := PackedStringArray()
var checks := 0
var full_size := Vector2i(1600, 900)   ## 큰 화면일 때 창 크기 (창 담당 대신)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.size = Feel.SMALL_SIZE
	# 진짜 설정 파일(user://settings.cfg)을 안 건드리게 (screen_mode.gd의 settings_path. 없으면 아무 일 없음)
	(ScreenMode as Object).set("settings_path", TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	m = load(MAIN_SCENE).instantiate()
	Save.delete_file(TEST_SAVE)
	m.save_path = TEST_SAVE   # 진짜 저장 파일은 건드리지 않음
	root.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		root.size = Feel.SMALL_SIZE if mode == ScreenMode.Mode.SMALL else full_size)
	await _frames(3)
	var b = m.balance
	var p = m.panel

	# 1) 작은 화면: 동네만, 차고 안 보임
	_check(m.screen.mode == ScreenMode.Mode.SMALL, "처음 화면이 작은 화면이 아님")
	_check(not p.visible, "작은 화면인데 차고가 보임")
	_check(not m.small_button.visible and not m.settings_button.visible, "작은 화면인데 [작게]/[설정]이 보임")
	_check_small_rects("처음")

	# 1-2) 작은 화면에서도 치트 F1~F5
	_key(KEY_F4)
	await _frames(1)
	_check(m.state.star == 1, "작은 화면 F4: 강수 %d" % m.state.star)
	_key(KEY_F1)
	await _frames(1)
	_check(absf(m.state.money - Economy.hourly_income(b, 1)) < 2.0, "작은 화면 F1: 돈 %.1f" % m.state.money)
	_key(KEY_F5)
	await _frames(2)
	var d0: float = m.town.truck.distance()
	await _frames(20)
	_check(m.state.broken, "작은 화면 F5: 고장이 아님")
	_check(m.town.truck.distance() == d0 and not m.town.truck.running, "작은 화면 고장인데 트럭이 움직임")
	_check(not m.town.truck._smoke.is_empty(), "작은 화면 고장인데 연기가 안 남")
	var smoke: Rect2 = m.town.truck.smoke_rect()
	_check(smoke.has_area() and _covered(m.visible_rects(), smoke.get_center()), "작은 화면 연기 자리가 보이는 곳에 없음")
	_check_small_rects("고장")
	_key(KEY_F2)
	await _frames(1)
	_check(Engine.time_scale == Feel.CHEAT_TIME_SCALE, "작은 화면 F2: 배속이 안 켜짐")
	_key(KEY_F2)
	await _frames(1)
	_check(Engine.time_scale == 1.0, "작은 화면 F2 두 번: 배속이 안 꺼짐")
	_key(KEY_F3)
	await _frames(1)
	_check(m.state.star == 0 and not m.state.broken and m.state.money < 1.0, "작은 화면 F3: 처음 상태가 아님")
	_check(m.screen.mode == ScreenMode.Mode.SMALL and not p.visible, "치트 키를 눌렀더니 작은 화면이 아니게 됨")

	# 1-3) 복귀 팝업: 작은 화면 위, 480x220 안. [확인]은 팝업만 닫음 (큰 화면으로 안 감)
	m.popup.open("자리 비운 7시간 59분 동안 +1,234,567원", "꺼둔 동안은 50%만, 최대 8시간치까지 쌓입니다.")
	await _frames(2)
	var small_win := Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE))
	_check(small_win.encloses(m.popup.get_rect()), "복귀 팝업이 작은 화면 밖으로 나감: %s" % m.popup.get_rect())
	_check(_covered(m.visible_rects(), m.popup.get_rect().get_center()), "복귀 팝업이 보이는 곳에 없음")
	_check_small_rects("팝업")
	var ok_button: Button = m.popup.find_children("*", "Button", true, false)[0]
	_click(ok_button.get_global_rect().get_center())
	await _frames(2)
	_check(not m.popup.visible, "팝업 [확인]을 눌렀는데 안 닫힘")
	_check(m.screen.mode == ScreenMode.Mode.SMALL, "팝업 [확인]을 눌렀더니 큰 화면으로 감")

	# 2) 작은 화면의 보이는 곳(물류센터) 클릭 → 큰 화면
	var depot: Rect2 = m.town.view_rect(Feel.TOWN_DEPOT_RECT)
	_click(depot.get_center())
	await _frames(3)
	_check(m.screen.mode == ScreenMode.Mode.FULL, "작은 화면을 클릭했는데 큰 화면이 아님")
	_check(p.visible and m.small_button.visible and m.settings_button.visible, "큰 화면인데 차고/[작게]/[설정]이 안 보임")
	_check(p._enhance_button.visible and p._enhance_button.disabled, "0원인데 강화 버튼이 눌림 상태")
	_check(p._wait.visible and p._wait.text.begins_with("약 "), "돈 모자랄 때 '약 N분 뒤 가능'이 없음: '%s'" % p._wait.text)
	_check(m.visible_rects().size() == 1 and m.visible_rects()[0] == Rect2(Vector2.ZERO, Vector2(full_size)),
			"큰 화면의 보이는 곳이 창 전체가 아님")
	# 큰 화면에서 동네를 클릭해도 아무 일 없음 (작은 화면으로 안 감)
	_click(m.town.view_rect(Feel.TOWN_DEPOT_RECT).get_center())
	await _frames(2)
	_check(m.screen.mode == ScreenMode.Mode.FULL, "큰 화면에서 동네를 클릭했더니 화면이 바뀜")
	_check_layout("큰 화면 처음")

	# 3) F4로 0강 → 30강. 강수마다 차고 내용 확인
	for star in range(0, b.max_star):
		_check(m.state.star == star, "F4 %d번째: 강수 %d (기대 %d)" % [star, m.state.star, star])
		var danger: bool = b.destroy[star] > 0.0
		_check(p._danger.visible == danger, "%d강: '퍼질 확률' 표시가 %s여야 함" % [star, "보임" if danger else "숨김"])
		_check(p._reserve.visible == danger, "%d강: '스페어값 남겨두기' 줄이 %s여야 함" % [star, "보임" if danger else "숨김"])
		_check(p._wait.text.begins_with("강화 비용 부족") == danger, "%d강: 모자람 안내가 이상함: '%s'" % [star, p._wait.text])
		_check(p._chances.text.contains("성공"), "%d강: 확률 줄이 비어 있음" % star)
		_check(_win().encloses(p.get_global_rect()), "%d강: 차고가 창 밖으로 나감 %s" % [star, p.get_global_rect()])
		_key(KEY_F4)
		await _frames(1)
	_check(m.state.star == b.max_star, "F4를 30번 눌렀는데 30강이 아님: %d" % m.state.star)
	_check(not p._enhance_button.visible, "30강인데 강화 버튼이 보임")
	_key(KEY_F4)
	await _frames(1)
	_check(m.state.star == b.max_star, "30강에서 F4를 더 눌렀더니 넘어감: %d" % m.state.star)

	# 4) F5 → 15강 고장. 트럭 멈춤 + 연기, 스페어 버튼만
	_key(KEY_F5)
	await _frames(2)
	var d1: float = m.town.truck.distance()
	await _frames(30)
	_check(m.state.broken and m.state.star == 15, "F5 뒤: 고장 %s, 강수 %d" % [m.state.broken, m.state.star])
	_check(m.town.truck.distance() == d1 and not m.town.truck.running, "고장인데 트럭이 움직임")
	_check(not m.town.truck._smoke.is_empty(), "고장인데 연기가 안 남")
	_check(p._broken_label.visible, "'엔진 고장 - 운행 정지'가 안 보임")
	_check(p._spare_button.visible and not p._enhance_button.visible, "고장인데 스페어 버튼만 보이는 상태가 아님")
	_check(p._spare_button.disabled, "돈이 없는데 스페어 버튼이 눌림 상태")
	_check(m.state.current_hourly(b) == 0.0, "고장인데 수익이 0이 아님")

	# 5) F1로 돈 모으기 → 스페어 구매 (버튼을 진짜로 클릭)
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
	var d2: float = m.town.truck.distance()
	await _frames(10)
	_check(m.town.truck.running and m.town.truck.distance() != d2, "수리했는데 트럭이 안 움직임")

	# 6) 퍼질 수 있는 강수(18강): 강화 비용만 있으면 막힘, 스페어값까지 있어야 눌림
	m.state.star = 18
	m.state.money = Economy.enhance_cost(b, 18)
	await _frames(1)
	_check(p._enhance_button.disabled, "18강: 스페어값 없이 강화 버튼이 눌림 상태")
	_check(p._reserve.visible and p._reserve.text.contains(Fmt.money(Economy.spare_price(b))),
			"18강: 스페어값 줄이 이상함: '%s'" % p._reserve.text)
	_check(p._wait.visible and p._wait.text.begins_with("강화 비용 부족"), "18강: '강화 비용 부족'이 없음: '%s'" % p._wait.text)
	var before_block: int = m.state.press_count()
	_click(p._enhance_button.get_global_rect().get_center())
	await _frames(2)
	_check(not m.enhancing and m.state.press_count() == before_block, "18강: 막힌 버튼을 눌렀더니 강화가 시작됨")
	m.state.money = Economy.enhance_need(b, 18)
	await _frames(1)
	_check(not p._enhance_button.disabled and not p._wait.visible, "18강: 비용 + 스페어값이 있는데 버튼이 막힘")

	# 7) 강화 버튼을 진짜로 클릭 → 뜸 → 결과 반영, 통계. 결과 글자는 v0 패널보다 크게
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
	_check(p._result.get_theme_font_size("font_size") > Feel.PANEL_TEXT_SIZE, "결과 글자가 v0 패널보다 크지 않음")
	_check(p._title.get_theme_font_size("font_size") > Feel.PANEL_TITLE_SIZE, "차고 제목이 v0 패널보다 크지 않음")
	_check(p._stats.text.contains("누른 횟수 %d" % m.state.press_count()), "통계 줄이 안 맞음: '%s'" % p._stats.text)
	# 흔들림 연출(진짜 시간)이 끝날 때까지 기다림. 흔들리는 동안은 화면 전체가 조금씩 밀려 있음
	await create_timer(maxf(Feel.DESTROY_SHAKE_DURATION, Feel.FAIL_SHAKE_DURATION) + 0.1, true, false, true).timeout
	await _frames(2)
	_check(m.position == Vector2.ZERO and m._panel_shake == Vector2.ZERO, "흔들림이 끝났는데 제자리로 안 돌아옴")

	# 8) 여러 창 크기에서 차고가 가장 길 때 / 고장일 때 / 30강일 때 다 들어오나
	for size in FULL_SIZES:
		await _check_states_at(size, "%dx%d" % [size.x, size.y])

	# 9) [설정] → 창 모드 고르기 → 창 크기를 아무렇게나 바꿔도 안 깨짐 → 전체 화면으로 되돌리기
	full_size = Vector2i(1600, 900)
	root.size = full_size
	await _frames(3)
	_click(m.settings_button.get_global_rect().get_center())
	await _frames(2)
	var st = m.settings
	_check(st.visible, "[설정]을 눌렀는데 설정 화면이 안 뜸")
	_check(_win().encloses(st.get_global_rect()), "설정 화면이 창 밖으로 나감: %s" % st.get_global_rect())
	_check(st.fullscreen_button.button_pressed == (m.screen.full_style == ScreenMode.FullStyle.FULLSCREEN),
			"설정 화면이 지금 값을 안 보여줌")
	_click(st.windowed_button.get_global_rect().get_center())
	await _frames(2)
	_check(m.screen.full_style == ScreenMode.FullStyle.WINDOWED, "[창 모드]를 눌렀는데 screen.full_style이 창 모드가 아님")
	_check(st.windowed_button.button_pressed and not st.fullscreen_button.button_pressed, "[창 모드]가 고른 상태로 안 보임")
	for size in WINDOWED_SIZES:
		full_size = size
		root.size = size
		await _frames(3)
		_check_layout("창 모드 %dx%d" % [size.x, size.y])
		_check(_win().encloses(st.get_global_rect()), "창 모드 %dx%d: 설정 화면이 창 밖으로 나감" % [size.x, size.y])
	full_size = Vector2i(1600, 900)
	root.size = full_size
	await _frames(2)
	_click(st.fullscreen_button.get_global_rect().get_center())
	await _frames(2)
	_check(m.screen.full_style == ScreenMode.FullStyle.FULLSCREEN, "[전체 화면]을 눌렀는데 전체 화면이 아님")
	_click(st.close_button.get_global_rect().get_center())
	await _frames(2)
	_check(not st.visible, "[닫기]를 눌렀는데 설정 화면이 안 닫힘")

	# 10) [작게] → 작은 화면. 돈·강수는 그대로, 트럭은 길 위 같은 자리 근처에서 계속
	var star_before: int = m.state.star
	var money_before: float = m.state.money
	var dist_before: float = m.town.truck.distance()
	_click(m.small_button.get_global_rect().get_center())
	await _frames(2)
	_check(m.screen.mode == ScreenMode.Mode.SMALL, "[작게]를 눌렀는데 작은 화면이 아님")
	_check(not p.visible and not m.settings.visible and not m.small_button.visible, "작은 화면인데 차고/설정/[작게]가 보임")
	_check(m.state.star == star_before and m.state.money >= money_before, "화면을 바꿨더니 강수/돈이 바뀜")
	_check(absf(m.town.truck.distance() - dist_before) < 60.0, "화면을 바꿨더니 트럭이 다른 자리로 감 (%.0f → %.0f)" % [dist_before, m.town.truck.distance()])
	_check(is_equal_approx(m.town.zoom, 1.0), "작은 화면 동네 배수가 1이 아님: %.2f" % m.town.zoom)
	_check_small_rects("[작게] 뒤")

	# 11) F3 → 처음부터
	_key(KEY_F3)
	await _frames(1)
	# 돈: 그 한 프레임 사이에 집에 들러 몇 원 받았을 수 있음
	_check(m.state.star == 0 and m.state.money < 5.0 and m.state.press_count() == 0,
			"F3 뒤 처음 상태가 아님: ★%d %.1f원 %d번" % [m.state.star, m.state.money, m.state.press_count()])

	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## 이 창 크기에서 차고가 가장 길 때(퍼질 수 있는 강수 + 돈 모자람 + "엔진 퍼짐!" 결과 줄),
## 고장일 때, 30강일 때 다 들어오나
func _check_states_at(size: Vector2i, tag: String) -> void:
	full_size = size
	root.size = size
	var b = m.balance
	m.state.broken = false
	m.state.star = 18
	m.state.money = Economy.enhance_cost(b, 18)
	m.panel.show_result("엔진 퍼짐!", Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE)
	await _frames(3)
	_check_layout(tag + " 18강 돈 모자람")
	m.state.star_before_break = 29
	m.state.star = 15
	m.state.broken = true
	m.state.money = 0.0
	await _frames(3)
	_check_layout(tag + " 고장")
	m.state.broken = false
	m.state.star = 30
	await _frames(3)
	_check_layout(tag + " 30강")
	m.panel.clear_result()


## 큰 화면 배치: 차고·동네·버튼이 창 안에 다 들어오고 서로 안 겹치나, 동네는 작은 화면보다 크게
func _check_layout(tag: String) -> void:
	var win := _win()
	var pr: Rect2 = m.panel.get_global_rect()
	var town: Rect2 = m.town.area()
	var sb: Rect2 = m.small_button.get_global_rect()
	var gb: Rect2 = m.settings_button.get_global_rect()
	_check(win.encloses(pr), "%s: 차고가 창 밖으로 나감 %s (창 %s)" % [tag, pr, win.size])
	_check(win.encloses(town), "%s: 동네가 창 밖으로 나감 %s" % [tag, town])
	_check(win.encloses(sb) and win.encloses(gb), "%s: [작게]/[설정]이 창 밖으로 나감" % tag)
	_check(not pr.intersects(town), "%s: 차고와 동네가 겹침 %s / %s" % [tag, pr, town])
	_check(not pr.intersects(sb) and not pr.intersects(gb) and not sb.intersects(gb), "%s: 버튼끼리 또는 차고와 겹침" % tag)
	_check(not town.intersects(sb) and not town.intersects(gb), "%s: 버튼이 동네와 겹침" % tag)
	_check(m.town.zoom > 1.0, "%s: 큰 화면 동네가 작은 화면보다 작음 (배수 %.2f)" % [tag, m.town.zoom])
	_check(m.panel.ui_scale() >= Feel.GARAGE_SCALE * Feel.FULL_UI_SCALE_MIN - 0.001, "%s: 차고 배수가 너무 작음 %.2f" % [tag, m.panel.ui_scale()])
	if m._debug_label.visible:
		_check(win.encloses(m._debug_label.get_global_rect()) or m._debug_label.get_global_rect().position.x >= 0.0,
				"%s: 디버그 줄이 창 밖" % tag)


## 작은 화면 보이는 곳: 사각형 30개 이하, 창(480x220) 근처 안 (★ 커질 자리 등 조금 넘는 건 봐줌)
func _check_small_rects(tag: String) -> void:
	var rects: Array = m.visible_rects()
	_check(rects.size() <= MAX_RECTS, "%s: 작은 화면 사각형 %d개 (%d개 이하여야 함)" % [tag, rects.size(), MAX_RECTS])
	var near := Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).grow(20.0)
	for r: Rect2 in rects:
		_check(near.encloses(r), "%s: 보이는 곳 %s 가 작은 화면 밖" % [tag, r])
	# 길·집·물류센터·트럭 가운데가 보이는 곳 안에 있나 (사각형 밖은 안 그려짐)
	var t = m.town
	var spots: Array = [t.view_rect(Feel.TOWN_DEPOT_RECT).get_center(), t.truck.click_rect().get_center()]
	for i in Feel.TOWN_HOUSES:
		spots.append(t.to_view(Feel.TOWN_HOUSE_SPOTS[i]) - Vector2(0, 15))
	var s := 0.0
	while s < t.route.total():
		spots.append(t.to_view(t.route.point_at(s)))
		s += 10.0
	var missed := 0
	for pt in spots:
		if not _covered(rects, pt):
			missed += 1
	_check(missed == 0, "%s: 보여야 할 점 %d개가 보이는 곳 밖" % [tag, missed])


func _covered(rects: Array, pt: Vector2) -> bool:
	for r: Rect2 in rects:
		if r.has_point(pt):
			return true
	return false


func _win() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(root.size))


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
