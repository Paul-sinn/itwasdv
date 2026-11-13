## 큰 화면 차고 자동 확인 (v1 3단계 → v3 U2 ②): 진짜 게임 화면(main.tscn)에 진짜 키·마우스 입력을 넣어서 확인한다.
## - 작은 화면: 차고 안 보임, 보이는 곳 사각형 30개 이하, 치트 F1~F6, 복귀 팝업·"스페어 엔진 +1" 글자가 480x220 안
## - 작은 화면 클릭 → 큰 화면 (차고 + [설정] + [작게])
## - ② +0~+29 강화 비용이 Economy.enhance_cost와 같음, 스페어 개수 표시,
##   +18에서 스페어 0이면 강화 버튼 꺼짐 + 이유 글, 스페어를 사면(진짜 클릭) 켜짐,
##   퍼지면 스페어 −1·+15·통계 +1·트럭 계속 달림, 강화 직후 저장
## - 강화 뜸·결과·통계, 창 크기 1280x720 / 1600x900 / 1920x1080 / 3440x1440 + 창 모드에서 아무렇게나 바꾼 크기에서
##   차고·동네·버튼이 창 안에 다 들어오고 서로 안 겹치나
## - [설정] → 전체 화면 / 창 모드 고르기, [작게] → 작은 화면
## 화면 없는 실행에서는 창 크기가 안 바뀌므로, 화면이 바뀔 때 이 스크립트가 창 크기를 대신 바꿔 준다.
##
## 실행:
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_garage.gd
extends SceneTree

const ErrorWatch = preload("res://tests/error_watch.gd")   ## 실행 중 스크립트 오류가 나면 실패로 끝냄

const MAIN_SCENE := "res://scenes/main.tscn"
const Save = preload("res://scripts/core/save.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Trip = preload("res://scripts/core/trip.gd")
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
	OS.add_logger(ErrorWatch.new(self))
	_run.call_deferred()


func _run() -> void:
	await process_frame
	TranslationServer.set_locale("ko")   # 아래에서 한국어 글자를 비교함 (OS 언어와 상관없이)
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
	var t = m.state.truck(0)

	# 1) 작은 화면: 동네만, 차고 안 보임
	_check(m.screen.mode == ScreenMode.Mode.SMALL, "처음 화면이 작은 화면이 아님")
	_check(not p.visible, "작은 화면인데 차고가 보임")
	_check(not m.small_button.visible and not m.settings_button.visible, "작은 화면인데 [작게]/[설정]이 보임")
	_check_small_rects("처음")

	# 1-2) 작은 화면에서도 치트 F1~F6
	_key(KEY_F4)
	await _frames(1)
	_check(t.star == 1, "작은 화면 F4: 단계 %d" % t.star)
	var money0: int = m.state.money
	_key(KEY_F1)
	await _frames(1)
	_check(m.state.money - money0 >= int(Trip.hourly_income(b, m.state, 0)), "작은 화면 F1: 돈 %d → %d" % [money0, m.state.money])
	_key(KEY_F6)
	await _frames(1)
	_check(m.state.spares == 1, "작은 화면 F6: 스페어 %d개 (기대 1)" % m.state.spares)
	_key(KEY_F5)
	await _frames(2)
	_check(m.state.spares == 0 and t.star == 1, "작은 화면 F5(+1): 스페어 %d개, 단계 %d (기대 0개, +1 그대로)" % [m.state.spares, t.star])
	var d0: float = m.town.truck.distance()
	await _frames(20)
	_check(not m.town.truck._smoke.is_empty(), "작은 화면 F5: 퍼짐 연기가 안 남")
	var smoke: Rect2 = m.town.truck.smoke_rect()
	_check(smoke.has_area() and _covered(m.visible_rects(), smoke.get_center()), "작은 화면 연기 자리가 보이는 곳에 없음")
	_check_small_rects("퍼짐 연기")
	_key(KEY_F2)
	await _frames(1)
	_check(Engine.time_scale == Feel.CHEAT_TIME_SCALE, "작은 화면 F2: 배속이 안 켜짐")
	await create_timer(0.5, true, false, true).timeout   # 진짜 0.5초 = 게임 30초
	_check(m.town.truck.distance() != d0, "작은 화면 F5 뒤에도 트럭이 계속 달려야 함")
	_key(KEY_F2)
	await _frames(1)
	_check(Engine.time_scale == 1.0, "작은 화면 F2 두 번: 배속이 안 꺼짐")
	_key(KEY_F3)
	await _frames(1)
	t = m.state.truck(0)
	_check(t.star == 0 and m.state.spares == 0 and m.state.money < Trip.parcel_pay(b, m.state, 0) * 2, "작은 화면 F3: 처음 상태가 아님")
	m.state.master_unlocked = true   # 준비: F3 뒤 새 상태. F4로 +10을 넘겨도 명장 요일 고르기 창(v6b)이 안 뜨게 (이 확인과 상관없음, 창이 버튼을 가림)
	_check(m.screen.mode == ScreenMode.Mode.SMALL and not p.visible, "치트 키를 눌렀더니 작은 화면이 아니게 됨")

	# 1-3) 복귀 팝업: 작은 화면 위, 480x220 안. [확인]은 팝업만 닫음 (큰 화면으로 안 감)
	m.popup.open("자리 비운 7시간 59분 동안 +123.4만원", "배송 1,234건 · 스페어 엔진 +1개\n꺼둔 동안은 50%만, 최대 8시간치까지 쌓입니다.")
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

	# 1-4) "+금액"·"스페어 엔진 +1" 글자: 모든 집(오른쪽 끝·왼쪽 위 포함)에서 작은 화면 480x220 안, 보이는 곳 안
	for house in Feel.TOWN_HOUSES:
		m.town.show_spare(house)
		m.town.show_payout(house, 85)
	await _frames(1)
	var rects: Array = m.visible_rects()
	_check(rects.size() <= MAX_RECTS, "글자 %d개 떴을 때 보이는 곳 사각형 %d개 (%d개 이하)" % [Feel.TOWN_HOUSES * 2, rects.size(), MAX_RECTS])
	for l: Label in m.town.payouts():
		var r := Rect2(l.position + m.town.position, l.get_combined_minimum_size())
		_check(small_win.encloses(r) and r.position.y - float(l.get_meta(&"rise")) >= -0.5, "작은 화면 '%s' 글자가 창 밖으로 나감: %s" % [l.text, r])
		_check(_covered(rects, r.get_center()), "'%s' 글자가 보이는 곳 밖" % l.text)

	# 2) 작은 화면의 튜닝숍 건물 클릭 → 큰 화면 튜닝숍 (v6a: 건물만 반응)
	_click(m.town.building_rects()["tuning"].get_center())
	await _frames(3)
	_check(m.screen.mode == ScreenMode.Mode.FULL, "작은 화면 튜닝숍을 클릭했는데 큰 화면이 아님")
	_check(p.visible and p.building == "tuning" and m.small_button.visible and m.settings_button.visible, "큰 화면인데 튜닝숍/[작게]/[설정]이 안 보임")
	m.state.money = 0
	await _frames(1)
	_check(p._enhance_button.visible and p._enhance_button.disabled, "0원인데 강화 버튼이 눌림 상태")
	_check(p._wait.visible and p._wait.text.begins_with("강화 비용 부족 · 약 "), "돈 모자랄 때 '강화 비용 부족 · 약 N분 뒤 가능'이 없음: '%s'" % p._wait.text)
	# 스페어 사기 버튼은 카센터 화면에 (v6a)
	_click(p.building_buttons["car_center"].get_global_rect().get_center())
	await _frames(2)
	_check(p._spare_button.is_visible_in_tree() and p._spare_button.disabled, "0원인데 카센터 스페어 사기 버튼이 눌림 상태")
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	_check(m.visible_rects().size() == 1 and m.visible_rects()[0] == Rect2(Vector2.ZERO, Vector2(full_size)),
			"큰 화면의 보이는 곳이 창 전체가 아님")
	# 큰 화면에서 동네 길을 클릭해도 아무 일 없음 (작은 화면으로 안 감, 건물 화면도 그대로)
	_click(m.town.to_view(m.town.route.point_at(m.town.route.total() * 0.5)) + m.town.global_position)
	await _frames(2)
	_check(m.screen.mode == ScreenMode.Mode.FULL and p.building == "tuning", "큰 화면에서 길을 클릭했더니 화면이 바뀜")
	_check_layout("큰 화면 처음")

	# 3) F4로 +0 → +30. 단계마다 비용 = Economy.enhance_cost, 퍼질 수 있으면 스페어 없을 때 이유 글
	var cost_ok := true
	var spare_rule_ok := true
	for star in range(0, b.max_star):
		_check(t.star == star, "F4 %d번째: 단계 %d (기대 %d)" % [star, t.star, star])
		var want_cost := tr("GARAGE_COST") % Fmt.money(Economy.enhance_cost(b, star, m.state))
		if p._cost.text != want_cost:
			cost_ok = false
			print("    +%d 비용 글자 '%s' (기대 '%s')" % [star, p._cost.text, want_cost])
		var danger: bool = b.destroy[star] > 0.0
		_check(p._danger.visible == danger and p._danger_note.visible == danger,
				"+%d: '퍼질 확률'·'퍼지면 스페어로 +15' 표시가 %s여야 함" % [star, "보임" if danger else "숨김"])
		if danger != (p._wait.visible and p._wait.text == tr("GARAGE_NEED_SPARE") and p._enhance_button.disabled):
			spare_rule_ok = false
			print("    +%d 스페어 0개: 버튼 꺼짐 %s, 이유 글 '%s'" % [star, p._enhance_button.disabled, p._wait.text])
		_check(p._chances.text.contains("성공"), "+%d: 확률 줄이 비어 있음" % star)
		_check(_win().encloses(p.get_global_rect()), "+%d: 차고가 창 밖으로 나감 %s" % [star, p.get_global_rect()])
		_key(KEY_F4)
		await _frames(1)
	_report(cost_ok, "② +0~+%d 강화 비용 글자 = Economy.enhance_cost" % (b.max_star - 1))
	_report(spare_rule_ok, "② 퍼질 수 있는 단계(+18~)에서만 스페어 0개면 강화 버튼 꺼짐 + 이유 글 '%s'" % tr("GARAGE_NEED_SPARE"))
	_check(t.star == b.max_star, "F4를 30번 눌렀는데 +30이 아님: %d" % t.star)
	_check(not p._enhance_button.visible and p._title.text.contains("최대"), "+30인데 강화 버튼이 보이거나 '(최대)'가 없음")
	_key(KEY_F4)
	await _frames(1)
	_check(t.star == b.max_star, "+30에서 F4를 더 눌렀더니 넘어감: %d" % t.star)

	# 4) +18: 돈은 넉넉, 스페어 0 → 버튼 꺼짐 + 이유 글. 눌러도 아무 일 없음
	t.star = 18
	m.state.spares = 0
	m.state.money = Economy.enhance_cost(b, 18, m.state) + Economy.spare_price(b)
	await _frames(1)
	var blocked: bool = p._enhance_button.disabled and p._wait.visible and p._wait.text == tr("GARAGE_NEED_SPARE")
	var before_block: int = t.success_count + t.fail_count + t.destroy_count
	_click(p._enhance_button.get_global_rect().get_center())
	await _frames(2)
	blocked = blocked and not m.enhancing and t.success_count + t.fail_count + t.destroy_count == before_block
	_report(blocked and p._spares.text == "스페어 엔진 0개",
			"② +18 스페어 0개: 강화 버튼 꺼짐 + 이유 글 '%s', 눌러도 강화 안 됨, 개수 표시 '%s'" % [p._wait.text, p._spares.text])

	# 5) 카센터에서 스페어 사기 버튼을 진짜로 클릭 → 스페어 1개, 튜닝숍 강화 버튼 켜짐
	_click(p.building_buttons["car_center"].get_global_rect().get_center())
	await _frames(2)
	_check(not p._spare_button.disabled, "+18: 스페어값이 있는데 카센터 사기 버튼이 꺼짐")
	_click(p._spare_button.get_global_rect().get_center())
	await _frames(2)
	var car_result: String = p._car_result.text
	_click(p.building_buttons["tuning"].get_global_rect().get_center())
	await _frames(2)
	var cost18 := Economy.enhance_cost(b, 18, m.state)
	_report(m.state.spares == 1 and m.state.money >= cost18 and m.state.money < cost18 + Economy.spare_price(b) and p._spares.text == "스페어 엔진 1개"
			and not p._enhance_button.disabled and not p._wait.visible and car_result.contains("스페어"),
			"② 카센터 스페어 사기 클릭 → 스페어 %d개 ('%s'), 돈 −%s, 튜닝숍 강화 버튼 켜짐, 결과 '%s'" % [
			m.state.spares, p._spares.text, Fmt.money(Economy.spare_price(b)), car_result])
	_check(Save.read_file(TEST_SAVE, b)["state"].spares == 1, "스페어를 산 뒤 바로 저장이 안 됨")

	# 6) 퍼짐: 다음 굴리기가 퍼짐이 나오게 씨앗을 골라 진짜로 클릭 → 스페어 −1, +15, 통계 +1, 트럭 계속 달림
	# 뜸 동안 배송이 나면 같은 난수 생성기(스페어 드랍)를 써서 결과가 바뀜 → 그동안 게임 시간을 멈춤 (뜸은 진짜 시간)
	m.suspense_scale = 0.05
	Engine.time_scale = 0.0
	_seed_for(Enhance.Result.DESTROY, 18)
	_click(p._enhance_button.get_global_rect().get_center())
	await _until_done()
	Engine.time_scale = 1.0
	await _frames(1)
	var saved = Save.read_file(TEST_SAVE, b)["state"]
	_report(m.state.spares == 0 and t.star == b.broken_drop_to and t.destroy_count == 1 and p._spares.text == "스페어 엔진 0개"
			and p._result.text == tr("RESULT_DESTROY") and p._result_note.text == tr("RESULT_DESTROY_NOTE") % [b.broken_drop_to, 0],
			"② 퍼짐 → 스페어 %d개, +%d, 퍼짐 %d번, 결과 '%s' / '%s'" % [m.state.spares, t.star, t.destroy_count, p._result.text, p._result_note.text])
	_report(saved.truck(0).star == b.broken_drop_to and saved.spares == 0, "강화 직후 저장 (저장 파일: +%d, 스페어 %d개)" % [saved.truck(0).star, saved.spares])
	var d1: float = m.town.truck.distance()
	var parcels1: int = m.parcels_total
	Engine.time_scale = Feel.CHEAT_TIME_SCALE
	await create_timer(0.5, true, false, true).timeout   # 진짜 0.5초 = 게임 30초
	Engine.time_scale = 1.0
	_report(m.town.truck.distance() != d1 and m.parcels_total > parcels1,
			"② 퍼진 뒤에도 트럭이 계속 달리고 배송함 (고장 상태 없음): 게임 30초 동안 배송 %d건" % (m.parcels_total - parcels1))
	_check(not m.town.truck._smoke.is_empty(), "퍼졌는데 연기가 안 남")

	# 7) 강화 버튼을 진짜로 클릭 → 뜸 → 결과 반영, 통계. 결과 글자는 v0 패널보다 크게
	await create_timer(Feel.DESTROY_SHAKE_DURATION, true, false, true).timeout   # 퍼짐 흔들림이 끝나야 버튼 자리가 맞음
	m.suspense_scale = 1.0
	m.state.money = 1000000000000
	m.state.spares = 10
	await _frames(3)   # 이유 줄이 사라져 버튼 자리가 바뀜 → 다시 배치된 뒤에 누름
	for i in 5:
		var before: int = t.success_count + t.fail_count + t.destroy_count
		_click(p._enhance_button.get_global_rect().get_center())
		await _frames(1)
		_check(m.enhancing and p._enhance_button.disabled, "%d번째: 누른 뒤 뜸(버튼 잠김)이 없음" % i)
		_check(t.success_count + t.fail_count + t.destroy_count == before, "%d번째: 뜸이 끝나기 전에 결과가 나옴" % i)
		_click(p._enhance_button.get_global_rect().get_center())   # 뜸 중에 또 눌러도 무시돼야 함
		await _until_done()
		var after: int = t.success_count + t.fail_count + t.destroy_count
		_check(after == before + 1, "%d번째: 한 번 눌렀는데 횟수가 %d 늘어남" % [i, after - before])
	_check(p._result.text != "", "강화 결과가 안 보임")
	_check(p._result.get_theme_font_size("font_size") > Feel.PANEL_TEXT_SIZE, "결과 글자가 v0 패널보다 크지 않음")
	_check(p._title.get_theme_font_size("font_size") > Feel.PANEL_TITLE_SIZE, "차고 제목이 v0 패널보다 크지 않음")
	_check(p._stats.text.contains("누른 횟수 %d" % (t.success_count + t.fail_count + t.destroy_count)), "통계 줄이 안 맞음: '%s'" % p._stats.text)
	# 흔들림 연출(진짜 시간)이 끝날 때까지 기다림. 흔들리는 동안은 화면 전체가 조금씩 밀려 있음
	await create_timer(maxf(Feel.DESTROY_SHAKE_DURATION, Feel.FAIL_SHAKE_DURATION) + 0.1, true, false, true).timeout
	await _frames(2)
	_check(m.position == Vector2.ZERO and m._panel_shake == Vector2.ZERO, "흔들림이 끝났는데 제자리로 안 돌아옴")

	# 8) 여러 창 크기에서 차고가 가장 길 때 / +30일 때 다 들어오나
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

	# 10) [작게] → 작은 화면. 돈·단계는 그대로, 트럭은 길 위 같은 자리 근처에서 계속
	var star_before: int = t.star
	var money_before: int = m.state.money
	var dist_before: float = m.town.truck.distance()
	_click(m.small_button.get_global_rect().get_center())
	await _frames(2)
	_check(m.screen.mode == ScreenMode.Mode.SMALL, "[작게]를 눌렀는데 작은 화면이 아님")
	_check(not p.visible and not m.settings.visible and not m.small_button.visible, "작은 화면인데 차고/설정/[작게]가 보임")
	_check(t.star == star_before and m.state.money >= money_before, "화면을 바꿨더니 단계/돈이 바뀜")
	_check(absf(m.town.truck.distance() - dist_before) < 60.0, "화면을 바꿨더니 트럭이 다른 자리로 감 (%.0f → %.0f)" % [dist_before, m.town.truck.distance()])
	_check(is_equal_approx(m.town.zoom, 1.0), "작은 화면 동네 배수가 1이 아님: %.2f" % m.town.zoom)
	_check_small_rects("[작게] 뒤")

	# 11) F3 → 처음부터
	_key(KEY_F3)
	await _frames(1)
	t = m.state.truck(0)
	# 돈: 그 한 프레임 사이에 배송이 끝나 몇 원 받았을 수 있음
	_check(t.star == 0 and m.state.money < Trip.parcel_pay(b, m.state, 0) * 2 and m.state.spares == 0 and t.success_count + t.fail_count + t.destroy_count == 0,
			"F3 뒤 처음 상태가 아님: +%d %d원 스페어 %d개" % [t.star, m.state.money, m.state.spares])

	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("확인 %d개 중 %d개 통과" % [checks, checks - fails.size()])
	for f in fails:
		print("  [실패] " + f)
	print("전부 통과" if fails.is_empty() else "실패 있음")
	quit(0 if fails.is_empty() else 1)


## 이 창 크기에서 차고가 가장 길 때(퍼질 수 있는 단계 + 스페어 없음 + "엔진 퍼짐!" 결과 두 줄), +30일 때 다 들어오나
func _check_states_at(size: Vector2i, tag: String) -> void:
	full_size = size
	root.size = size
	var b = m.balance
	var t = m.state.truck(0)
	t.star = 18
	m.state.spares = 0
	m.state.money = 0
	m.panel.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, tr("RESULT_DESTROY_NOTE") % [b.broken_drop_to, 0])
	await _frames(3)
	_check_layout(tag + " +18 스페어 없음·돈 모자람·퍼짐 결과")
	t.star = b.max_star
	await _frames(3)
	_check_layout(tag + " +30")
	m.panel.clear_result()


## 이 단계에서 다음 굴리기가 want가 나오게 m.rng 씨앗을 고른다
func _seed_for(want: int, star: int) -> void:
	var probe := RandomNumberGenerator.new()
	for s in 100000:
		probe.seed = s
		if Enhance.roll(m.balance, star, probe) == want:
			m.rng.seed = s
			return


## 강화 뜸이 끝날 때까지 (최대 600프레임)
func _until_done() -> void:
	var waited := 0
	while m.enhancing and waited < 600:
		await process_frame
		waited += 1


func _report(ok: bool, text: String) -> void:
	_check(ok, text)
	print("%s %s" % ["[통과]" if ok else "[실패]", text])


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


## 작은 화면 보이는 곳: 사각형 30개 이하, 창(480x220) 근처 안 ("+N" 커질 자리 등 조금 넘는 건 봐줌)
func _check_small_rects(tag: String) -> void:
	var rects: Array = m.visible_rects()
	_check(rects.size() <= MAX_RECTS, "%s: 작은 화면 사각형 %d개 (%d개 이하여야 함)" % [tag, rects.size(), MAX_RECTS])
	# 트럭 사각형은 다음 갱신까지 움직일 거리만큼 넓힘 (main.visible_rects) → 그만큼 더 봐줌
	var truck_pad: float = m.town.truck.speed() * Engine.time_scale * Feel.CLICK_REGION_INTERVAL * 2.0 + 4.0
	var near := Rect2(Vector2.ZERO, Vector2(Feel.SMALL_SIZE)).grow(20.0 + truck_pad)
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
