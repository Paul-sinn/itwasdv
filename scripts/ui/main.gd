## 게임 시작점. 숫자(balance)와 상태(game_state)를 들고, 동네와 건물 화면에 보여주고,
## 매 프레임 Trip.advance로 트럭 0을 진행시켜 배송 이벤트("+돈", 스페어 엔진)를 동네에 띄우고,
## 버튼·치트 키를 scripts/core 함수로 연결한다.
## 확률·가격·돈 계산은 하지 않는다 → scripts/core/
##
## v1 화면 두 개 (창 다루기는 screen_mode.gd):
##   작은 화면: 동네만. 건물(또는 구석 작은 버튼)을 누르면 큰 화면 그 건물 화면으로 (v6a. 그 밖은 눌러도 그대로)
##   큰 화면: 왼쪽에 같은 동네를 크게 + 오른쪽에 건물 화면(garage_panel.gd) + [설정] [작게] 버튼
##     큰 화면은 전체 화면 또는 창 모드(사용자가 [설정]에서 고름). 창 모드는 창 크기가 수시로 바뀜
##     → 창 크기가 바뀔 때마다 _layout() (최소 1280x720에서도 안 깨지게)
## v3: 돈은 정수. 화면 트럭은 연출이고, 자리만 계산 쪽 바퀴 진행(Trip.lap_progress)에서 정한다
## v4: 차고 [세팅] 칸 → Setting.try_roll / Setting.choose (굴리기·고르기는 scripts/core/setting.gd)
## v5: 계산 쪽 알림(state.take_events: 할 일 끝·레벨업·만렙·강화 첫 달성)을 프레임마다 꺼내 동네에 하나씩,
##     차고 [기사·물류센터] → Depot.upgrade, 강화·세팅·스페어·올리기 직후 Quest.check (바로 반응하게)
## v6-bal: 처음 켰을 때 작은 화면 말풍선 "건물을 눌러보세요". 건물·작은 버튼을 한 번 누르면(open_building) 다시 안 뜸
## v5b: 물류센터 능력치 [+] → Ability.add, [초기화] → Ability.reset (직후 저장). 팁 이벤트 → 동네 "팁!",
##      찍을 포인트가 남으면 구석 줄 점, 꺼둔 동안 노하우 경험치 한 줄
## v6b: 현지 시각(now_local)을 만들어 Master.tick(켤 때는 꺼둔 동안 계산보다 먼저, 그 뒤 프레임마다)·Rush.tick(프레임마다).
##      대형·VIP·급송 "+금액", 급송 전화 말풍선 [받기] → Rush.accept, [설정] 급송 전화 켜기/끄기, 주간 목표 달성 알림
##      명장: +10 첫 달성(master_unlocked)이면 큰 화면 튜닝숍에서 요일 고르기 창(day_picker.gd), 요일 → Master.set_day,
##      예고·방문 알림, 방문 중이면 띠의 튜닝숍 테두리
## v7a: 매 프레임 모든 트럭을 Trip.advance (보조 트럭도 띠에서 달리고 "+금액" = 내 돈으로 들어온 금액).
##      강화·세팅은 튜닝숍 트럭 탭에서 고른 트럭(panel.truck). 능력치·급송·구석 줄 "+N"은 늘 내 트럭(트럭 0).
##      물류센터 [창업] 두 번째 누름 → Company.found → 알림·저장. 꺼둔 동안 요약에 대리점이면 직원 몫·세금 줄
##      U2: 대리점이면 띠에 사무실 건물·구석 줄 "시내 N위"(Company.rank), 사무실 [보조 트럭 사기] → Company.buy_helper → 저장,
##      처음 1위(rank_first 이벤트) → 알림
## v7-bal: NPC가 온 날(명장·보험사·마술사·부품상) 띠·큰 화면 오른쪽 위 편지봉투 + 느낌표 → 누르면 큰 화면 + NPC 대화 창(npc_dialog.gd).
##      한 번 열면 그날은 느낌표만 꺼짐. 보험사 [예] → 가입 → 저장. 급송 전화는 전화 아이콘 → 큰 화면 없이 Rush.accept.
##      누가 왔는지·이벤트·가입은 _visitor_info() 한 곳 (Master.is_visiting, Visitor.today / insurer_event / is_insured).
##      U1: 보험은 state가 정함 (Visitor.join_insurance → Enhance가 알아서 보험료·막음). 강화 칸 [고급 스페어 쓰기] → state.use_premium → 저장,
##      퍼지면 r["drop_to"]·r["premium"]으로 "+17에서 다시"(고급 스페어 / 복구 보험) 구분. 특별 NPC 방문·주간 보상 돈 → 동네 알림
extends Control

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Master = preload("res://scripts/core/master.gd")
const Rush = preload("res://scripts/core/rush.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Visitor = preload("res://scripts/core/visitor.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")
const GaragePanel = preload("res://scripts/ui/garage_panel.gd")
const ReturnPopup = preload("res://scripts/ui/return_popup.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const DayPicker = preload("res://scripts/ui/day_picker.gd")
const NpcDialog = preload("res://scripts/ui/npc_dialog.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

const AUTOSAVE_SECONDS := 30.0        ## 30초마다 저장 (배속과 상관없이 진짜 30초)
const TRUCK := 0   ## 내 트럭 번호 (구석 줄 "+N", 치트 키). 강화·세팅은 panel.truck (튜닝숍 트럭 탭)
## 처음 말풍선을 봤는지 (설정 파일 settings.cfg에. 게임 저장 파일 아님)
const HINT_SECTION := "first_run"
const HINT_KEY := "building_hint_seen"

## 저장 파일 위치. 확인 스크립트는 진짜 저장을 건드리지 않게 add_child 전에 바꾼다.
var save_path := Save.DEFAULT_PATH
## 현지 시각을 바꿔 넣기 (확인 스크립트용. 0 이상이면 now_local()이 이 값). 켤 때부터 쓰려면 add_child 전에
var now_local_override := -1

var balance: Balance
var state: GameState
var town: Town
var panel: GaragePanel       ## 차고 (전체 화면에서만 보임)
var popup: ReturnPopup
var screen: ScreenMode       ## 작은 화면 / 전체 화면 오가기 (창 다루기는 전부 여기)
var small_button: Button     ## 큰 화면 [작게]
var settings_button: Button  ## 큰 화면 [설정]
var settings: SettingsPanel  ## [설정]을 누르면 가운데 뜨는 "화면: 전체 화면 / 창 모드"
var day_picker: DayPicker    ## 명장 요일 고르기 창 (큰 화면 튜닝숍 가운데)
var npc_dialog: NpcDialog    ## NPC 대화 창 (편지봉투를 누르면 큰 화면 가운데)
## 편지봉투를 연 방문 (_letter_key). 같은 방문이면 느낌표를 끔. 저장 안 함 (껐다 켜면 그날 느낌표가 한 번 더 뜸)
var _letter_read := ""
var rng := RandomNumberGenerator.new()
## 처음 말풍선 "건물을 눌러보세요"를 이미 봤나 (건물·작은 버튼을 한 번 누르면 true. 작은 화면에서 false일 때만 뜸)
var hint_seen := false
## 명장이 열렸는데 아직 요일 고르기 창을 안 띄움 (큰 화면 튜닝숍을 볼 때 한 번 띄움)
var _want_day_picker := false

## 켰을 때 넣은 꺼둔 동안 (Trip.apply_offline 결과 + away_seconds):
##   { money, parcels, spares, hours, xp, full, ignored, away_seconds }.
## 저장이 없었으면 빈 묶음
var offline_report := {}

## 켠 뒤로 배송 이벤트로 번 돈(팁 포함) · 배송 수 · 받은 스페어 수 · 팁 수와 팁 돈 (확인용)
var earned_total := 0
var parcels_total := 0
var spares_found := 0
var boosts_found := 0
var tips_found := 0
var tips_total := 0

# F2 배속 측정: 배속을 켠 순간부터 게임 시간과 번 돈을 잰다
var _measuring := false
var _measure_seconds := 0.0
var _measure_earned := 0
var _measure_hourly := 0.0
var _debug_label: Label
var _last_cheat := ""
var _bg: ColorRect
var _ui_scale := 1.0               ## 전체 화면 글자·간격 배수 (창 높이 900 = 1)
var _panel_spot := Vector2.ZERO    ## 차고 오른쪽 위 모서리 (흔들림 빼고)
var _panel_shake := Vector2.ZERO   ## 실패 연출: 차고 흔들림

## 강화 뜸 중 (결과 기다리는 중). 이때는 강화·돌리기 버튼을 또 눌러도 무시
var enhancing := false
## 세팅 돌리기 뜸 중. 이때도 강화·돌리기 버튼을 또 눌러도 무시
var rolling := false
## 뜸(결과 나오기 전 기다림) 길이 배수. 확인 스크립트가 여러 번 누를 때만 줄임 (1 = 그대로)
var suspense_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 빈 곳 클릭은 _unhandled_input에서 처리
	rng.randomize()
	balance = Balance.load_file()
	if not balance.is_ok():
		_show_fatal(balance.errors)
		return

	state = GameState.new_game()
	var load_notice := _load_save()
	hint_seen = ScreenMode.load_value(HINT_SECTION, HINT_KEY, false) == true

	# 창: 투명 창 / 평범한 창(--windowed) / 화면 없음(테스트). 작은 화면 ↔ 전체 화면
	screen = ScreenMode.new()
	add_child(screen)
	screen.mode_changed.connect(func(_mode): _layout())

	# 배경: 투명 창(바탕화면 위)이 아닐 때만 칠함
	_bg = ColorRect.new()
	_bg.color = Feel.COLOR_BG
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	town = Town.new()
	add_child(town)

	panel = GaragePanel.new()
	add_child(panel)
	panel.enhance_pressed.connect(_on_enhance_pressed)
	panel.spare_pressed.connect(_on_spare_pressed)
	panel.premium_toggled.connect(_on_premium_toggled)
	panel.setting.roll_pressed.connect(_on_roll_pressed)
	panel.setting.choose_pressed.connect(_on_choose_pressed)
	panel.driver.upgrade_pressed.connect(_on_upgrade_pressed)
	panel.driver.ability_pressed.connect(_on_ability_pressed)
	panel.driver.reset_pressed.connect(_on_ability_reset)
	panel.driver.found_pressed.connect(_on_found_pressed)
	panel.office.buy_pressed.connect(_on_helper_buy_pressed)
	panel.master.day_pressed.connect(_on_day_picked)
	town.tuning_pressed.connect(func(): open_building("tuning"))
	_open_pending_setting()

	small_button = Button.new()
	small_button.text = tr("SMALL_ESC")
	small_button.focus_mode = Control.FOCUS_NONE
	small_button.pressed.connect(func(): screen.enter_small())
	add_child(small_button)

	settings_button = Button.new()
	settings_button.text = tr("SETTINGS")
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.pressed.connect(func(): close_settings() if settings.visible else open_settings())
	add_child(settings_button)

	_debug_label = Town.make_label(Feel.DEBUG_FONT_SIZE, Feel.COLOR_DEBUG)
	add_child(_debug_label)

	settings = SettingsPanel.new()
	settings.visible = false
	add_child(settings)
	settings.style_picked.connect(_on_style_picked)
	settings.close_pressed.connect(close_settings)
	settings.rush_picked.connect(_on_rush_picked)
	town.rush_accept_pressed.connect(_on_rush_accept)
	screen.full_style_changed.connect(func(style): settings.show_style(style))

	day_picker = DayPicker.new()
	day_picker.visible = false
	add_child(day_picker)
	day_picker.day_picked.connect(_on_day_picked)
	day_picker.close_pressed.connect(func(): day_picker.visible = false)

	npc_dialog = NpcDialog.new()
	npc_dialog.visible = false
	add_child(npc_dialog)
	npc_dialog.yes_pressed.connect(_on_npc_yes)
	npc_dialog.no_pressed.connect(func(): npc_dialog.visible = false)
	npc_dialog.close_pressed.connect(func(): npc_dialog.visible = false)
	town.letter_pressed.connect(_open_letter)

	popup = ReturnPopup.new()
	popup.visible = false
	add_child(popup)

	var autosave := Timer.new()
	autosave.name = "Autosave"
	autosave.wait_time = AUTOSAVE_SECONDS
	autosave.ignore_time_scale = true
	autosave.autostart = true
	autosave.timeout.connect(_save)
	add_child(autosave)

	get_viewport().size_changed.connect(_layout)
	_layout()
	screen.rects_provider = visible_rects

	_open_return_popup(load_notice)
	_save()   # 꺼둔 동안 수익을 넣었으면 바로 저장 (다시 켰을 때 두 번 받지 않게)


func is_full() -> bool:
	return screen.mode == ScreenMode.Mode.FULL


## 창 크기·화면이 바뀌면 다시 배치 (mode_changed, size_changed)
func _layout() -> void:
	if not is_inside_tree():
		return   # 트리에서 빠진 뒤 창 크기 신호가 늦게 와도 (확인 스크립트가 main을 바꿔 끼울 때)
	var view := get_viewport_rect().size
	_bg.visible = not screen.is_transparent()
	var full := is_full()
	panel.visible = full
	small_button.visible = full
	settings_button.visible = full
	if not full:
		settings.visible = false
		day_picker.visible = false   # 작게 하면 닫힘 (요일은 [명장] 칸에서 언제든)
		npc_dialog.visible = false   # 작게 하면 닫힘 (편지봉투는 그날 동안 남음)
	_debug_label.visible = full and OS.is_debug_build()
	town.show_ground = full
	town.set_hint(not full and not hint_seen)

	if not full:
		# 작은 화면: 동네를 창에 꽉 차게 (창 = 동네 설계 크기면 1배)
		_ui_scale = 1.0
		var z := minf(view.x / Feel.TOWN_SIZE.x, view.y / Feel.TOWN_SIZE.y)
		town.layout((view - Feel.TOWN_SIZE * z) / 2.0, z, z)
		return

	# 전체 화면: 위쪽 줄에 [작게], 왼쪽에 동네(크게), 오른쪽에 차고
	# 창 높이 900(폭 1600) 기준. 좁고 긴 창(창 모드)에서 차고가 너무 넓어지지 않게 폭도 본다
	var by_size := minf(view.y / Feel.FULL_REF_SIZE.y, view.x / Feel.FULL_REF_SIZE.x)
	_ui_scale = clampf(by_size, Feel.FULL_UI_SCALE_MIN, Feel.FULL_UI_SCALE_MAX)
	var m := Feel.FULL_MARGIN * _ui_scale
	for b in [small_button, settings_button]:
		b.add_theme_font_size_override("font_size", int(roundf(Feel.PANEL_BUTTON_SIZE * _ui_scale)))
		b.reset_size()
	small_button.position = Vector2(view.x - m - small_button.size.x, m * 0.5)
	settings_button.position = small_button.position - Vector2(settings_button.size.x + m * 0.5, 0)
	settings.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	day_picker.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	npc_dialog.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	_debug_label.add_theme_font_size_override("font_size", int(roundf(Feel.DEBUG_FONT_SIZE * _ui_scale)))

	panel.set_ui_scale(Feel.GARAGE_SCALE * _ui_scale)
	var top := small_button.position.y + small_button.size.y + m * 0.5
	# 동네 자리: 차고 폭은 정해진 폭(PANEL_WIDTH × 배수)으로 잡는다
	# (글자 크기를 바꾼 직후에는 차고의 실제 크기가 다음 프레임에야 바뀌어서 믿을 수 없음)
	var garage_w := Feel.PANEL_WIDTH * panel.ui_scale()
	var debug_h := _debug_label.get_combined_minimum_size().y if _debug_label.visible else 0.0
	var area := Rect2(m, top, view.x - garage_w - m * 3.0, view.y - top - m - debug_h)
	var z := maxf(0.1, minf(area.size.x / Feel.TOWN_SIZE.x, area.size.y / Feel.TOWN_SIZE.y))
	var town_pos := Vector2(area.position.x, area.get_center().y - Feel.TOWN_SIZE.y * z / 2.0)
	town.layout(town_pos, z, minf(z, Feel.FULL_TOWN_TEXT_MAX * _ui_scale))
	# 차고: 오른쪽, 위쪽을 동네 위쪽에 맞춤
	_panel_spot = Vector2(view.x - m, town_pos.y)
	_place_panel()
	_debug_label.position = Vector2(m, view.y - m * 0.5 - debug_h)


## 차고: 오른쪽에 붙여서 (내용에 따라 폭이 바뀌어도 오른쪽 끝은 그대로). 아래가 창 밖으로 나가면 올림
func _place_panel() -> void:
	panel.reset_size()
	var view := get_viewport_rect().size
	var m := Feel.FULL_MARGIN * _ui_scale
	var y := minf(_panel_spot.y, view.y - m - panel.size.y)
	panel.position = Vector2(_panel_spot.x - panel.size.x, maxf(m * 0.5, y)) + _panel_shake


func _process(delta: float) -> void:
	var t := state.truck(TRUCK)
	var now := now_local()
	Master.tick(state, balance, now, rng)
	Rush.tick(state, balance, delta, rng)
	town.set_truck_count(state.trucks.size())
	for i in state.trucks.size():
		_advance_truck(i, delta)
	_show_events(state.take_events())
	town.set_hud(state.money, t.star, state.driver_level)
	town.set_point_dot(Ability.points_left(state) > 0)
	town.set_rush(Rush.is_ringing(state), state.rush_ring / balance.rush_ring_seconds, Rush.parcels_left(state))
	town.set_quest(_quest_line())
	town.set_master_visit(Master.is_visiting(state, now))
	var visitor := _visitor_info()
	town.set_letter(visitor["who"] != "", _letter_key(visitor) != _letter_read)
	if npc_dialog.visible and npc_dialog.who != visitor["who"]:
		npc_dialog.visible = false   # 날이 바뀌어 NPC가 떠남
	town.set_office(Company.stage(state) >= GameState.AGENCY)
	town.set_city(Trip.route_id(state, TRUCK) == "city", _city_spots())
	town.set_rank(Company.rank(balance, state))
	panel.now_local = now
	if _want_day_picker and is_full() and panel.building == "tuning" and not enhancing:
		_want_day_picker = false
		panel.show_tab(panel.Tab.MASTER)
		day_picker.visible = true
	if panel.visible:
		panel.refresh(balance, state)
		_place_panel()
	if popup.visible:
		_place_popup()
	if settings.visible:
		settings.reset_size()
		settings.position = ((get_viewport_rect().size - settings.size) / 2.0).max(Vector2.ZERO)
	if day_picker.visible:
		day_picker.reset_size()
		day_picker.position = ((get_viewport_rect().size - day_picker.size) / 2.0).max(Vector2.ZERO)
	if npc_dialog.visible:
		npc_dialog.reset_size()
		npc_dialog.position = ((get_viewport_rect().size - npc_dialog.size) / 2.0).max(Vector2.ZERO)
	if _measuring:
		_measure_seconds += delta
	if _debug_label.visible:
		_update_debug_label()


## 트럭 i를 delta초 진행 (Trip.advance) → 띠의 그 트럭 자리, 배송 이벤트("+금액" = 내 돈으로 들어온 금액)를 그 트럭 가까운 집에
func _advance_truck(i: int, delta: float) -> void:
	var events := Trip.advance(state, balance, i, delta, rng)
	var sprite: Node2D = town.trucks[i]
	var p := Trip.lap_progress(balance, state, i)
	if town.city:   # 시내: 집마다 서고, "+돈"은 배송된 그 집에 (정차할 곳 = 실을 수 있는 수만큼)
		var n := Trip.lap_cargo(balance, state, i)
		var k: int = state.truck(i).lap_delivered
		if k == n and p > 0.0 and events.any(func(e): return e["type"] == "parcel"):
			sprite.leg = p / n   # 이번 바퀴 마지막 배송 = n × (집 하나 몫)
		sprite.stop_and_go(p, k, n)
	else:
		sprite.follow(p)
	sprite.boosting = state.truck(i).boost_lap
	var house: int = sprite.nearest_house()   # 동네: "+돈"은 트럭(있어야 할 자리)에서 가장 가까운 집에
	for e in events:
		match e["type"]:
			"parcel":
				if town.city:
					house = e["house"]
				town.show_payout(house, e["pay"], e.get("kind", "normal"), e.get("rush", false), i)
				earned_total += e["pay"]
				parcels_total += 1
				if _measuring:
					_measure_earned += e["pay"]
			"spare":   # 바로 앞 배송에서 나옴 → 같은 집에
				town.show_spare(house)
				spares_found += 1
			"boost":   # 이 바퀴는 오버부스트 (트럭 뒤 불꽃은 boosting으로 바퀴 내내)
				town.show_boost(i)
				boosts_found += 1
			"tip":   # 바로 앞 배송에서 팁 (돈은 계산 쪽이 이미 더함) → 같은 집 "+금액" 옆에 "팁!"
				town.show_tip(house, e["pay"])
				earned_total += e["pay"]
				tips_found += 1
				tips_total += e["pay"]
				if _measuring:
					_measure_earned += e["pay"]


## 시내 정차할 곳 수 = 트럭들이 한 바퀴에 실을 수 있는 가장 많은 수 (평균 적재량 올림. 소수 적재량이면 바퀴마다 그 앞쪽 집만 감)
func _city_spots() -> int:
	var n := 0
	for i in state.trucks.size():
		n = maxi(n, ceili(Trip.cargo(balance, state, i)))
	return n


# ---------------- 저장 · 꺼둔 동안 수익 ----------------

## 저장 파일을 읽어 상태를 되살리고 꺼둔 동안을 넣는다 (Trip.apply_offline).
## 알려줄 일(백업에서 살림 / 옛 형식 파일을 남김 / 깨져서 새로 시작)이 있으면 그 글자를 돌려준다.
func _load_save() -> String:
	var r := Save.read_file(save_path, balance)
	var broken_name := save_path.get_file() + ".broken"
	match r["status"]:
		Save.Status.OK:
			state = r["state"]
			var away := Time.get_unix_time_from_system() - float(r["saved_at"])
			Master.tick(state, balance, now_local(), rng)   # 주가 바뀐 뒤 켰으면 꺼둔 동안 배송이 새 주에 들어가게 (먼저)
			offline_report = Trip.apply_offline(state, balance, away)
			offline_report["away_seconds"] = away
			if r["recovered"]:
				push_warning("저장 파일이 깨져서 백업에서 살림: " + r["error"])
				return tr("LOAD_RECOVERED") % broken_name
		Save.Status.NONE:
			if r["old_kept"] != "":
				return tr("LOAD_OLD_KEPT") % r["old_kept"].get_file()
		Save.Status.BROKEN:
			push_warning("저장 파일이 깨져서 새로 시작: " + r["error"])
			return tr("LOAD_BROKEN") % broken_name
	return ""


## 복귀 팝업: 알릴 일(notice)이 있으면 그게 큰 글자, 꺼둔 동안 요약은 아래 작은 글자로
func _open_return_popup(notice: String) -> void:
	var away_lines := _offline_lines()
	if notice != "":
		popup.open(notice, "\n".join(away_lines))
	elif not away_lines.is_empty():
		popup.open(away_lines[0], away_lines[1])


## 돌아왔을 때 요약 두 줄 [큰 글자, 작은 글자]: 번 돈 / 배송·스페어 (+ 노하우 경험치) + 창고가 꽉 찼는지.
## 저장이 없었거나 3분 안에 다시 켰으면(계산 쪽 ignored) 빈 목록. 시계가 거꾸로 갔으면 0원인 이유
func _offline_lines() -> PackedStringArray:
	if offline_report.is_empty():
		return PackedStringArray()
	var away: float = offline_report["away_seconds"]
	if away < 0.0:   # 계산 쪽은 ignored로 주지만, 0원인 이유를 알려 줌
		return PackedStringArray([tr("RETURN_MAIN_ZERO"), tr("RETURN_CLOCK_BACK") % Fmt.away(away)])
	if offline_report["ignored"]:
		return PackedStringArray()
	var main_text := tr("RETURN_MAIN") % [Fmt.away(away), Fmt.money(offline_report["money"])]
	var cap := Fmt.num(Depot.cap_hours(balance, state))
	var rate := Fmt.percent(Depot.rate(balance, state))
	var rule := tr("RETURN_FULL") % [cap, rate] if offline_report["full"] else tr("RETURN_NOTE") % [rate, cap]
	var note := tr("RETURN_DETAIL") % [offline_report["parcels"], offline_report["spares"]]
	if offline_report["xp"] > 0:   # 노하우가 있을 때만 (꺼둔 동안 경험치)
		note += "\n" + tr("RETURN_XP") % offline_report["xp"]
	if Company.stage(state) >= GameState.AGENCY:   # 대리점이면 뗀 것 (위 큰 글자 돈 = 떼고 난 내 돈)
		note += "\n" + tr("RETURN_STAFF_TAX") % [Fmt.money(offline_report["staff"]), Fmt.money(offline_report["tax"])]
	note += "\n" + rule
	return PackedStringArray([main_text, note])


## 작은 화면 "다음 할 일" 한 줄: 이름 + 진행 "3/20". 다 끝났으면 "다음 할 일 없음"
func _quest_line() -> String:
	var q := Quest.current(balance, state)
	if q.is_empty():
		return tr("QUEST_NONE")
	var pr := Quest.progress(balance, state)
	return tr("TOWN_QUEST") % [Fmt.quest_name(q["id"]), mini(pr[0], pr[1]), pr[1]]


## 계산 쪽 알림 → 동네 알림 (동네가 하나씩 차례로 띄움).
## 할 일 끝·강화 첫 달성 바로 뒤에 온 레벨업·만렙은 같은 알림에 줄을 더해 하나로 (한 번에 여러 레벨이면 마지막 레벨, 포인트는 합)
func _show_events(events: Array) -> void:
	var cur := {}
	for e: Dictionary in events:
		match e["type"]:
			"quest_done":
				_notify(cur)
				cur = { "head": tr("NOTICE_QUEST") % [Fmt.quest_name(e["id"]), Fmt.money(e["money"]), e["xp"]] }
			"milestone":
				_notify(cur)
				cur = { "head": tr("NOTICE_MILESTONE") % [e["star"], e["xp"]] }
			"level_up":
				cur["level"] = e["level"]
				cur["points"] = cur.get("points", 0) + e["points"]
			"max_level":
				cur["max"] = true
			"weekly_done":   # 경험치 보상으로 레벨업하면 그 줄이 이 알림에 붙음
				_notify(cur)
				cur = { "head": tr("NOTICE_WEEKLY") % [Fmt.money(e["money"]), Fmt.count(e["xp"])] }
			"visitor":   # 특별 NPC가 옴 (그날 한 번. 부품상은 선물이 이미 들어옴)
				_notify(cur)
				cur = { "head": _visitor_notice(e) }
			"master_notice":
				_notify(cur)
				cur = { "head": tr("NOTICE_MASTER_TOMORROW") % Fmt.master_bonus(balance.master_bonuses, e["bonus"]) }
			"master_visit":
				_notify(cur)
				cur = { "head": tr("NOTICE_MASTER_TODAY") % Fmt.master_bonus(balance.master_bonuses, e["bonus"]) }
			"master_unlocked":   # 큰 화면 튜닝숍을 볼 때 요일 고르기 창 (_process)
				_want_day_picker = true
			"agency_founded":   # 창업 할 일 끝 알림은 다음 Quest.check에서 따로
				_notify(cur)
				cur = { "head": tr("NOTICE_AGENCY") }
			"rank_first":   # 시내 1위 (계산 쪽이 한 번만 보냄)
				_notify(cur)
				cur = { "head": tr("NOTICE_RANK_FIRST") }
	_notify(cur)


func _notify(n: Dictionary) -> void:
	var lines := PackedStringArray()
	if n.has("head"):
		lines.append(n["head"])
	if n.has("level"):
		lines.append(tr("NOTICE_LEVEL") % [n["level"], n["points"]])
	if n.has("max"):
		lines.append(tr("NOTICE_MAX_LEVEL") % Driver.max_level(balance))
	if not lines.is_empty():
		town.notify("\n".join(lines))


## 복귀 팝업: 창 가운데 (작은 화면이면 480x220 안에)
func _place_popup() -> void:
	popup.reset_size()
	var view := get_viewport_rect().size
	popup.position = ((view - popup.size) / 2.0).max(Vector2.ZERO)


func _save() -> void:
	if state == null:
		return
	var err := Save.write_file(save_path, state, int(Time.get_unix_time_from_system()))
	if err != OK:
		push_warning("저장 실패 (오류 %d): %s" % [err, save_path])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_WM_MOUSE_EXIT and town != null:
		town.set_hover("")   # 마우스가 창(작은 화면은 보이는 곳) 밖으로 나가면 빛남·이름표 끔


## 지금 보이는 것들의 사각형 (창 좌표). 투명 창에서는 이것만 그려지고 클릭을 받는다.
## 전체 화면은 창 전체가 보이는 곳.
func visible_rects() -> Array:
	var view := get_viewport_rect().size
	if is_full():
		return [Rect2(Vector2.ZERO, view)]
	var fastest := 0.0
	for t in town.trucks:
		fastest = maxf(fastest, t.speed())
	var pad := fastest * Engine.time_scale * Feel.CLICK_REGION_INTERVAL * 2.0 + 4.0
	# 흔들림 연출 중이면 흔들리는 만큼 넉넉하게 (잘려 보이지 않게)
	var shake := position.length()
	var rects := town.visible_rects(pad)
	if popup.visible:
		rects.append(popup.get_rect())
	var out := []
	var win := Rect2(Vector2.ZERO, view)   # 창 밖은 어차피 안 보임 → 잘라 냄 (연기·트럭 여유가 창 끝에서 넘칠 때)
	for r: Rect2 in rects:
		var v := Rect2(r.position + town.position + position, r.size).grow(shake).intersection(win)
		if v.has_area():
			out.append(v)
	return out


# ---------------- 설정 (큰 화면) ----------------

func open_settings() -> void:
	if not is_full():
		return
	settings.show_style(screen.full_style)
	settings.show_rush(state.rush_enabled)
	settings.visible = true


func close_settings() -> void:
	settings.visible = false


## [설정] 급송 요청 전화 켜기/끄기 → 게임 저장에 (끄면 벨이 안 울림. 울리던 벨도 Rush.tick이 끔)
func _on_rush_picked(on: bool) -> void:
	state.rush_enabled = on
	settings.show_rush(on)
	_save()


## 급송 전화 [받기] → Rush.accept (벨이 울릴 때만) → 저장
func _on_rush_accept() -> void:
	if Rush.accept(state, balance):
		_save()


## 오늘 와 있는 NPC: { who: "master" / "insurer" / "magician" / "dealer" / "", event: 보험사 이벤트 id, insured: 오늘 가입했나,
##   bonus: 명장 보너스 id }. 명장 날엔 특별 NPC가 안 옴 (계산 쪽 규칙). 효과 숫자는 대화 창이 balance에서 읽음
func _visitor_info() -> Dictionary:
	if Master.is_visiting(state, now_local()):
		return { "who": "master", "event": "", "insured": false, "bonus": state.active_bonus }
	return { "who": Visitor.today(state), "event": Visitor.insurer_event(state), "insured": Visitor.is_insured(state) }


## 특별 NPC 방문 알림 한 줄 (계산 쪽 { "type": "visitor", "who", "event", "gift" })
func _visitor_notice(e: Dictionary) -> String:
	match e["who"]:
		"insurer":
			return tr("NOTICE_VISITOR_INSURER") % tr("NPC_EVENT_NAME_RECOVERY" if e["event"] == "recovery" else "NPC_EVENT_NAME_PARTNER_DISCOUNT")
		"magician":
			return tr("NOTICE_VISITOR_MAGICIAN") % Fmt.num(balance.magician_up_mult)
		"dealer":
			return tr("NOTICE_VISITOR_DEALER") % e.get("gift", 0)
	return ""


## 이 방문을 가리키는 글자 (NPC + 현지 날짜 번호). 편지봉투를 열었나 비교용
func _letter_key(info: Dictionary) -> String:
	return "%s:%d" % [info["who"], floori(float(now_local()) / Master.SECONDS_PER_DAY)]


## 편지봉투 → 느낌표 끔 → (작은 화면이면 큰 화면으로) NPC 대화 창
func _open_letter() -> void:
	var info := _visitor_info()
	if info["who"] == "":
		return
	_letter_read = _letter_key(info)
	town.set_letter(true, false)
	npc_dialog.open(balance, info)
	if not is_full():
		screen.enter_full()


## 보험사 [예] → 가입 (보험사가 온 날만) → 저장 → 창에 "가입됨"
func _on_npc_yes() -> void:
	if not Visitor.join_insurance(state, now_local()):
		return
	_save()
	npc_dialog.open(balance, _visitor_info())


## 지금 현지 시각 = 현지 시각을 1970-01-01 0시(현지)부터 센 초 (Master가 요일·주를 셈). 확인 스크립트는 now_local_override
func now_local() -> int:
	if now_local_override >= 0:
		return now_local_override
	return Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())


## 명장 요일 (고르기 창 또는 [명장] 칸) → Master.set_day (처음이면 이번 주부터, 바꾸면 다음 주부터) → 저장.
## 고르기 창에서 골랐으면 창을 닫고 [명장] 칸에서 결과를 보여 줌
func _on_day_picked(day: int) -> void:
	Master.set_day(state, day, now_local())
	if day_picker.visible:
		day_picker.visible = false
		panel.show_tab(panel.Tab.MASTER)
	_save()
	panel.refresh(balance, state)


## 전체 화면 / 창 모드 고름 → 창 바꾸기·저장은 screen_mode.gd. 실제로 바뀐 값을 다시 표시
func _on_style_picked(style: ScreenMode.FullStyle) -> void:
	screen.set_full_style(style)
	settings.show_style(screen.full_style)


# ---------------- 강화 · 스페어 ----------------

## 강화 버튼: 뜸 → 굴리기(enhance.gd) → 결과 연출 → 저장
## 굴리기는 뜸이 끝난 뒤에 한다 (뜸 동안 꺼도 돈이 안 빠짐). 오늘 보험에 가입했으면 보험료·막기는 계산 쪽이 알아서
func _on_enhance_pressed() -> void:
	var i := panel.truck   # 누른 순간 고른 트럭 (뜸 동안 탭을 바꿔도 이 트럭에)
	if enhancing or rolling or Enhance.block_reason(state, balance, i) != Enhance.Block.NONE:
		return
	enhancing = true
	var star := state.truck(i).star
	var danger := Enhance.needs_spare(balance, star) and not Economy.insured_at(balance, star, state)
	panel.begin_suspense()
	var wait := (Feel.SUSPENSE_DANGER if danger else Feel.SUSPENSE_SAFE) * suspense_scale
	if danger:
		town.trucks[i].shake(wait, Feel.ENGINE_SHAKE_PX)   # 트럭 자기 좌표라 동네가 커지면 같이 커짐
	await get_tree().create_timer(wait, true, false, true).timeout   # 배속과 상관없이 진짜 시간

	i = mini(i, state.trucks.size() - 1)   # 뜸 동안 F3(처음부터)이면 트럭이 줄어듦
	var t := state.truck(i)   # 뜸 동안 F3(처음부터)이면 상태가 바뀌어서 다시 읽음
	var star_before := t.star
	var r := Enhance.try_enhance(state, balance, i, rng)
	panel.end_suspense()
	var fx := panel.ui_scale()   # 흔들림 세기: 차고 크기에 맞춰
	match r["result"]:
		Enhance.Result.SUCCESS:
			# 명장 "2단계" 보너스로 두 단계 올랐으면 "+2!"
			panel.show_result(tr("RESULT_DOUBLE" if r["double"] else "RESULT_SUCCESS") % [star_before, t.star], Feel.COLOR_SUCCESS)
			panel.celebrate()
			if i == TRUCK:   # 구석 줄 "+N"은 내 트럭 단계
				town.pop_star()
			town.trucks[i].flash(Feel.FLASH_DURATION)
			town.trucks[i].boost(Feel.BOOST_DURATION)
		Enhance.Result.FAIL when r["insured"]:   # 퍼짐이 떴지만 보험이 막음 (단계 그대로, 스페어 안 씀)
			panel.show_result(tr("RESULT_INSURED") % t.star, Feel.COLOR_INSURED)
		Enhance.Result.FAIL:
			panel.show_result(tr("RESULT_FAIL"), Feel.COLOR_FAIL)
			_shake(func(o): _panel_shake = o, Feel.FAIL_SHAKE_PX * fx, Feel.FAIL_SHAKE_DURATION)
		Enhance.Result.DESTROY:
			# 스페어 엔진을 자동으로 써서 내려감 (보통 +15, 고급 스페어·복구 보험이면 +17). 트럭은 계속 달림
			var note := tr("RESULT_DESTROY_NOTE") % [r["drop_to"], state.spares]
			if r["premium"]:
				note = tr("RESULT_DESTROY_PREMIUM") % [r["drop_to"], state.premium_spares]
			elif r["drop_to"] > balance.broken_drop_to:   # 복구 보험 날 (보통 스페어를 쓰고도 덜 내려감)
				note = tr("RESULT_DESTROY_RECOVERY") % [r["drop_to"], state.spares]
			panel.show_result(tr("RESULT_DESTROY"), Feel.COLOR_DANGER, Feel.DESTROY_TEXT_SIZE, note)
			town.trucks[i].smoke_burst(Feel.DESTROY_SMOKE_BURST)
			_shake(func(o): position = o, Feel.DESTROY_SHAKE_PX * fx, Feel.DESTROY_SHAKE_DURATION)
		Enhance.Result.BLOCKED:
			panel.clear_result()
	Quest.check(state, balance)   # 다음 할 일이 바로 반응하게 (알림은 다음 프레임에 동네로)
	_save()   # 기획서 15.5: 강화 버튼 직후 저장
	panel.refresh(balance, state)
	enhancing = false


## 흔들기: seconds 동안 px 세기로 시작해 0으로 줄어드는 떨림을 setter에 넣는다 (진짜 시간)
func _shake(setter: Callable, px: float, seconds: float) -> void:
	var jitter := func(t: float) -> void:
		setter.call(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px * (1.0 - t))
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_method(jitter, 0.0, 1.0, seconds)
	tw.tween_callback(func(): setter.call(Vector2.ZERO))


## [고급 스페어 쓰기] 켜기/끄기 → state.use_premium (퍼질 때 고급을 먼저 쓸지는 계산 쪽) → 저장
func _on_premium_toggled(on: bool) -> void:
	state.use_premium = on
	_save()


## 스페어 엔진 구매 (언제든, 돈이 있으면)
func _on_spare_pressed() -> void:
	if state.buy_spare(balance):
		panel.show_spare_bought(tr("RESULT_SPARE_BOUGHT") % state.spares)
		Quest.check(state, balance)
		_save()
	panel.refresh(balance, state)


# ---------------- 세팅 돌리기 ----------------

## [돌리기]: 짧은 뜸 → 굴리기(setting.gd) → 예전 것 / 새 것 고르는 화면 → 저장
## 굴리기는 뜸이 끝난 뒤에 한다 (뜸 동안 꺼도 돈이 안 빠짐)
func _on_roll_pressed(part: String) -> void:
	var i := panel.truck   # 누른 순간 고른 트럭
	if enhancing or rolling or Setting.block_reason(state, balance, i, part) != Setting.Block.NONE:
		return
	rolling = true
	panel.setting.begin_suspense()
	await get_tree().create_timer(Feel.SETTING_SUSPENSE * suspense_scale, true, false, true).timeout   # 진짜 시간

	i = mini(i, state.trucks.size() - 1)   # 뜸 동안 F3(처음부터)이면 트럭이 줄어듦
	var before: int = state.truck(i).part(part)["grade"]
	var r := Setting.try_roll(state, balance, i, part, rng)
	panel.setting.end_suspense()
	if r["ok"]:
		var after: int = state.truck(i).part(part)["pending"]["grade"]
		panel.setting.show_roll_result(part, before, after, r["pity"])
		if r["grade_up"]:
			var c: Color = Feel.SETTING_GRADE_COLORS[after]
			c.a = Feel.SETTING_FLASH_ALPHA
			panel.flash(c, Feel.SETTING_FLASH_DURATION)
		Quest.check(state, balance)
		_save()   # 돌린 직후 저장 (고르기 전에 꺼도 다음에 고름)
	panel.refresh(balance, state)
	rolling = false


## 예전 것 / 새 것 고르기 → 저장
func _on_choose_pressed(part: String, take_new: bool) -> void:
	var i := panel.truck
	if rolling or state.truck(i).part(part)["pending"] == null:
		return
	Setting.choose(state, i, part, take_new)
	panel.setting.show_choice(take_new)
	Quest.check(state, balance)   # 새 것을 고르면 등급이 바뀜 (세팅 등급 할 일)
	_save()   # 고른 직후 저장
	panel.refresh(balance, state)


# ---------------- 기사·물류센터 ----------------

## 물류센터 [창업] 두 번째 누름 → Company.found (돈이 모자라면 그대로) → 다음 할 일 바로 확인 → 저장. 알림은 agency_founded 이벤트로
func _on_found_pressed() -> void:
	if Company.found(balance, state):
		panel.driver.show_founded()
		Quest.check(state, balance)
		_save()
	panel.refresh(balance, state)


## 창고 확장 / 야간 배송팀 [올리기] → Depot.upgrade → 다음 할 일 바로 확인 → 저장
func _on_upgrade_pressed(kind: String) -> void:
	if Depot.upgrade(balance, state, kind):
		Quest.check(state, balance)
		panel.driver.show_bought(kind)
		_save()   # 산 직후 저장
	panel.refresh(balance, state)


## 사무실 [보조 트럭 사기] → Company.buy_helper (돈이 모자라거나 다 샀으면 그대로) → 다음 할 일 바로 확인 → 저장.
## 띠의 트럭은 다음 프레임 set_truck_count가 늘림
func _on_helper_buy_pressed() -> void:
	if Company.buy_helper(balance, state):
		panel.office.refresh(balance, state)   # 새 줄을 만든 뒤 커지게
		panel.office.show_bought(Company.helper_count(state))
		Quest.check(state, balance)
		_save()
	panel.refresh(balance, state)


## 능력치 [+] → Ability.add (포인트 없거나 최대면 그대로) → 찍은 직후 저장
func _on_ability_pressed(id: String) -> void:
	if Ability.add(balance, state, id):
		panel.driver.show_added(id)
		_save()
	panel.refresh(balance, state)


## [초기화] 두 번째 누름 → 전부 0 (포인트는 돌려받음) → 저장
func _on_ability_reset() -> void:
	Ability.reset(state)
	_save()
	panel.refresh(balance, state)


## 고르다 만 부품이 있으면 차고를 [세팅] 칸 그 트럭·그 부품으로 열어 둔다 (껐다 켜도 고르는 화면이 다시 뜸)
func _open_pending_setting() -> void:
	for i in state.trucks.size():
		var t := state.truck(i)
		for part in Setting.part_ids(balance):
			if t.settings.has(part) and t.part(part)["pending"] != null:
				panel.show_tab(panel.Tab.SETTING)
				panel.pick_truck(i)
				panel.setting.select(part)
				return


# ---------------- 클릭 · 치트 키 ----------------

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_on_click(mouse.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		town.set_hover(town.building_at(motion.position - town.global_position))
		return
	# 작은 화면 오른쪽 클릭 → 메뉴 (전체 화면 / 작게 / 끝내기). 누를 때 말고 뗄 때 띄운다
	# (누르자마자 띄우면 떼는 순간 마우스 밑 메뉴 항목이 눌릴 수 있음)
	if mouse != null and not mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT and not is_full():
		get_viewport().set_input_as_handled()
		screen.open_menu_at_mouse()
		return
	if not OS.is_debug_build():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1: _cheat_money()
		KEY_F2: _toggle_fast_time()
		KEY_F3: _cheat_reset()
		KEY_F4: _cheat_star_up()
		KEY_F5: _cheat_break()
		KEY_F6: _cheat_spare()
		_: return
	get_viewport().set_input_as_handled()


## 버튼·팝업 위 클릭은 그쪽이 먼저 가져가서 여기로 오지 않는다.
## 건물을 누르면 그 건물 화면 (작은 화면·큰 화면 둘 다). 길·트럭·집·글자는 눌러도 아무 일 없음 (기획서 15.3)
func _on_click(pos: Vector2) -> void:
	var id := town.building_at(pos - town.global_position)
	if id != "":
		open_building(id)
		get_viewport().set_input_as_handled()


## 큰 화면으로 바꾸고 그 건물 화면을 보여 준다 ("tuning" / "depot" / "car_center")
func open_building(id: String) -> void:
	if not hint_seen:   # 처음 말풍선은 건물·작은 버튼을 한 번 누르면 다시 안 뜸
		hint_seen = true
		ScreenMode.save_value(HINT_SECTION, HINT_KEY, true)
		town.set_hint(false)
	panel.show_building(id)
	screen.enter_full()


## F1: 돈 + 지금 단계 1시간치
func _cheat_money() -> void:
	var amount := int(Trip.hourly_income(balance, state, TRUCK))
	state.money += amount
	_last_cheat = tr("CHEAT_MONEY") % Fmt.money(amount)


## F2: 시간 60배속 켜기/끄기. 켜는 순간부터 "측정"을 새로 시작한다.
func _toggle_fast_time() -> void:
	if Engine.time_scale == 1.0:
		Engine.time_scale = Feel.CHEAT_TIME_SCALE
		_measuring = true
		_measure_seconds = 0.0
		_measure_earned = 0
		_measure_hourly = Trip.hourly_income(balance, state, TRUCK)
	else:
		Engine.time_scale = 1.0
		_measuring = false   # 측정 결과는 화면에 그대로 남겨 둔다


## F3: 저장 초기화 → 처음부터 (돈 0, +0, 스페어 0, 통계 0)
func _cheat_reset() -> void:
	Save.delete_file(save_path)
	state = GameState.new_game()
	earned_total = 0
	parcels_total = 0
	spares_found = 0
	panel.clear_result()
	panel.setting.clear_result()
	popup.visible = false
	_save()
	_last_cheat = tr("CHEAT_RESET")


## F4: 강화 단계 +1 (최대 단계까지)
func _cheat_star_up() -> void:
	var t := state.truck(TRUCK)
	t.star = mini(t.star + 1, balance.max_star)
	_last_cheat = "F4 +%d" % t.star


## F5: 강제로 퍼지게 하기 (스페어가 있으면 1개 씀. 통계에는 안 셈)
func _cheat_break() -> void:
	Enhance.force_destroy(state, balance, TRUCK)
	town.truck.smoke_burst(Feel.DESTROY_SMOKE_BURST)
	_last_cheat = tr("CHEAT_BREAK") % [state.truck(TRUCK).star, state.spares]


## F6: 스페어 엔진 +1
func _cheat_spare() -> void:
	state.spares += 1
	_last_cheat = tr("CHEAT_SPARE") % state.spares


func _update_debug_label() -> void:
	var text := tr("DEBUG_KEYS") % [
		Fmt.num(Feel.CHEAT_TIME_SCALE), tr("DEBUG_ON") if Engine.time_scale != 1.0 else tr("DEBUG_OFF")]
	if _last_cheat != "":
		text += "   ▶ " + _last_cheat
	if _measure_seconds > 0.0:
		var expected := _measure_hourly * _measure_seconds / 3600.0
		var ratio := _measure_earned / expected * 100.0 if expected > 0.0 else 0.0
		text += "   " + tr("DEBUG_MEASURE") % [
			Fmt.duration(_measure_seconds), Fmt.money(_measure_earned), Fmt.money(int(expected)), ratio]
	_debug_label.text = text


## balance.json이 틀렸을 때: 어디가 틀렸는지 보여주고 게임을 시작하지 않는다.
func _show_fatal(errors: PackedStringArray) -> void:
	for e in errors:
		push_error(e)
	var bg := ColorRect.new()
	bg.color = Feel.COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Feel.COLOR_ERROR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = tr("FATAL_BALANCE") + "\n" + "\n".join(errors)
	add_child(label)
	set_process(false)
