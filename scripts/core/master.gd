## 명장 방문일 (v6b): 엔진 +10 첫 달성 때 열림 → 유저가 요일을 고름 (처음 고르면 이번 주부터, 바꾸면 다음 주부터).
## 고른 요일 0~24시(현지)에 방문 중 → 그 주 보너스(3개 중 1개, 주마다 굴림)가 적용됨 (enhance.gd). 보험은 없음 (v7-bal: 보험사 날만, visitor.gd).
## 방문 전날 켜져 있으면 예고 알림 한 번 (예고한 보너스 = 방문일 보너스. 월요일 방문이면 일요일에 다음 주 보너스를 미리 굴림).
## 주가 바뀌면 주간 배송 목표 0 (weekly.gd). 날짜(현지 0시)가 바뀌면 오늘 집계 0 (v7a, company.gd today).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 시계를 직접 읽지 않는다: 현지 시각 now_local을 화면이 넘겨 준다.
## now_local = 현지 시각을 1970-01-01 0시(현지)부터 센 초 (화면: Time.get_unix_time_from_system() + 시간대 차이(초))
## 그 주 보너스 굴리기는 이 파일에만. 보너스의 효과는 쓰는 곳에서 state.active_bonus를 본다 (enhance.gd).
## tick 끝에서 특별 NPC(visitor.gd)의 tick도 부른다 (명장 방문 중인지 = active_bonus를 정한 뒤).
## 시계 조작은 허용 (기획서 4.7): 시계가 거꾸로 가거나 몇 주를 건너뛰어도 "주가 바뀜"으로 보고 멈추지 않는다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Visitor = preload("res://scripts/core/visitor.gd")
const Weekly = preload("res://scripts/core/weekly.gd")

const SECONDS_PER_DAY := 86400
## 1970-01-01은 목요일 → 월요일 = 0으로 세면 3
const EPOCH_WEEKDAY := 3


## 0 = 월 … 6 = 일
static func weekday(now_local: int) -> int:
	return posmod(_day(now_local) + EPOCH_WEEKDAY, 7)


## 월요일 0시에 바뀌는 주 번호 (1970-01-05 월요일부터 1. 그 전 날짜는 0 이하)
static func week_index(now_local: int) -> int:
	return floori((_day(now_local) + EPOCH_WEEKDAY) / 7.0)


## 엔진 +10(master.unlock_star)을 처음 달성했나
static func is_unlocked(state: GameState) -> bool:
	return state.master_unlocked


## 이번 주에 적용되는 요일 (0 = 월 … 6 = 일). -1 = 안 고름
static func chosen_day(state: GameState) -> int:
	return state.master_day


## 다음 주부터 바뀔 요일. -1 = 없음
static func pending_day(state: GameState) -> int:
	return state.master_next_day


## 요일 고르기. 처음 고르면 이번 주부터 (그 요일이 이미 지났으면 이번 주는 방문 없음), 이미 골랐으면 다음 주부터.
## 지금 요일을 다시 고르면 바꾸기 취소. 잠겼거나 0~6 밖이면 아무것도 안 함
static func set_day(state: GameState, day: int, now_local: int) -> void:
	if not state.master_unlocked or day < 0 or day > 6:
		return
	_roll_day(state, week_index(now_local))
	if state.master_day < 0:
		state.master_day = day
		state.master_next_day = -1
	elif day == state.master_day:
		state.master_next_day = -1
	else:
		state.master_next_day = day


## 지금 방문 중인가: 열렸고, 이번 주에 적용되는 요일이 오늘 (0~24시 현지)
static func is_visiting(state: GameState, now_local: int) -> bool:
	if not state.master_unlocked:
		return false
	var day := _day_for(state, week_index(now_local))
	return day >= 0 and day == weekday(now_local)


## 이번 주 보너스 id ("" = 아직 없음: 잠김 또는 tick 전). 화면은 예고를 받았거나 방문 중일 때만 보여 준다
static func week_bonus(state: GameState) -> String:
	return state.master_bonus


## 프레임마다(또는 켤 때) 부름. 켤 때는 Trip.apply_offline보다 먼저 (꺼둔 동안 배송이 새 주에 들어가게).
##   날짜가 바뀌면: 오늘 집계(GameState.today_*) 0 (처음이면 지금 집계 그대로 그날로. 켤 때 먼저 불러야 꺼둔 동안 번 것이 켠 날에)
##   주가 바뀌면: 주간 목표 0, 다음 주로 미뤄 둔 요일 적용, 그 주 보너스 굴림
##   +10을 이미 넘었는데 안 열렸으면 (v6b 전 저장) 열고 { "type": "master_unlocked" }
##   내일이 방문일이면 { "type": "master_notice", "bonus": id } (한 주에 한 번)
##   오늘이 방문일이면 처음 한 번 { "type": "master_visit", "bonus": id }
##   state.active_bonus = 방문 중이면 그 주 보너스, 아니면 ""
##   끝에 Visitor.tick (특별 NPC: 방문 날짜·알림·부품상 선물)
static func tick(state: GameState, b: Balance, now_local: int, rng: RandomNumberGenerator) -> void:
	_roll_today(state, _day(now_local))
	var week := week_index(now_local)
	Weekly.roll_week(state, week)
	check_unlock(state, b)
	if not state.master_unlocked:
		state.active_bonus = ""
		Visitor.tick(state, b, now_local, rng)
		return
	_roll_day(state, week)
	_roll_bonus(state, b, week, rng)
	var tomorrow := now_local + SECONDS_PER_DAY
	var tomorrow_week := week_index(tomorrow)
	var tomorrow_day := _day_for(state, tomorrow_week)
	if tomorrow_day >= 0 and tomorrow_day == weekday(tomorrow) and state.master_notice_week != tomorrow_week:
		state.master_notice_week = tomorrow_week
		state.add_event({ "type": "master_notice", "bonus": _bonus_for(state, b, tomorrow_week, rng) })
	if is_visiting(state, now_local):
		if state.master_visit_week != week:
			state.master_visit_week = week
			state.add_event({ "type": "master_visit", "bonus": state.master_bonus })
		state.active_bonus = state.master_bonus
	else:
		state.active_bonus = ""
	Visitor.tick(state, b, now_local, rng)


## +10(master.unlock_star)을 처음 넘었으면 연다: 알림 { "type": "master_unlocked" } (화면이 요일을 물어봄). 한 번만.
## 강화 성공 뒤(enhance.gd)와 tick이 부른다. 트럭 지금 단계나 강화 첫 달성 기록(milestones_done)으로 본다 (퍼져서 내려와도 그대로 열림)
static func check_unlock(state: GameState, b: Balance) -> void:
	if state.master_unlocked:
		return
	var reached := false
	for t in state.trucks:
		reached = reached or t.star >= b.master_unlock_star
	for m in state.milestones_done:
		reached = reached or int(m) >= b.master_unlock_star
	if reached:
		state.master_unlocked = true
		state.add_event({ "type": "master_unlocked" })


## 그 주에 적용되는 요일: 요일을 맞춘 주(master_week)면 master_day, 그 뒤 주면 미뤄 둔 요일(있으면). 없으면 -1
static func _day_for(state: GameState, week: int) -> int:
	if week != state.master_week and state.master_next_day >= 0 and week > state.master_week:
		return state.master_next_day
	return state.master_day


## 주가 바뀌었으면 미뤄 둔 요일을 적용 (시계가 거꾸로 가도 "바뀜"으로 봄)
static func _roll_day(state: GameState, week: int) -> void:
	if state.master_week == week:
		return
	if state.master_next_day >= 0:
		state.master_day = state.master_next_day
		state.master_next_day = -1
	state.master_week = week


## 이번 주 보너스가 없거나 지난 주 것이면 새로 (일요일 예고 때 미리 굴린 다음 주 보너스가 있으면 그것)
static func _roll_bonus(state: GameState, b: Balance, week: int, rng: RandomNumberGenerator) -> void:
	if state.master_bonus_week == week and state.master_bonus != "":
		return
	if week == state.master_bonus_week + 1 and state.master_next_bonus != "":
		state.master_bonus = state.master_next_bonus
	else:
		state.master_bonus = _pick(b, rng)
	state.master_bonus_week = week
	state.master_next_bonus = ""


## 그 주 보너스 (이번 주 또는 다음 주. 다음 주 것은 처음 물을 때 굴려 둠 → 주가 바뀌면 그대로 씀)
static func _bonus_for(state: GameState, b: Balance, week: int, rng: RandomNumberGenerator) -> String:
	if week == state.master_bonus_week:
		return state.master_bonus
	if state.master_next_bonus == "":
		state.master_next_bonus = _pick(b, rng)
	return state.master_next_bonus


## 보너스 3개 중 하나 (고르게)
static func _pick(b: Balance, rng: RandomNumberGenerator) -> String:
	return b.master_bonus_ids[rng.randi_range(0, b.master_bonus_ids.size() - 1)]


## 날짜 번호가 바뀌었으면 오늘 집계 0. 처음(-1: 새 게임·형식 9까지 저장)이면 지금 집계 그대로 그날로 (시계가 거꾸로 가도 "바뀜")
static func _roll_today(state: GameState, day: int) -> void:
	if state.today_day == day:
		return
	if state.today_day != -1:
		state.today_sales = 0
		state.today_staff = 0
		state.today_tax = 0
	state.today_day = day


## 1970-01-01 0시(현지)부터 며칠째 (그 전이면 음수)
static func _day(now_local: int) -> int:
	return floori(now_local / float(SECONDS_PER_DAY))
