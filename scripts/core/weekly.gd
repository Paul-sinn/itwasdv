## 주간 배송 목표 (v6b): 그 주에 배송 N건 (모든 트럭, 꺼둔 동안 포함) → 돈(하루치 수입, v7-bal) + 경험치, 한 주에 한 번.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 배송을 세는 곳: trip.gd (켜 둔 동안 배송마다, 꺼둔 동안 합). 주가 바뀌는 것: master.gd tick → roll_week (현지 시각 기준)
## 켤 때는 Master.tick(지금)을 Trip.apply_offline보다 먼저 불러야 꺼둔 동안 배송이 새 주에 들어간다
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")   # company → trip → weekly 고리 (Godot 4.6.3에서 됨, trip ↔ company도 이미 고리)
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")

## GameState.weekly_week의 "아직 모름" (새 게임·형식 7까지 저장). 첫 tick에서 0으로 돌리지 않고 그 주로 정함
const NO_WEEK := -1


## 이번 주 배송 수
static func progress(state: GameState) -> int:
	return state.weekly_parcels


static func target(b: Balance) -> int:
	return b.weekly_target


## 이번 주 보상을 받았나
static func is_done(state: GameState) -> bool:
	return state.weekly_done


## 지금 달성하면 받을 돈 = floor(켜 둔 동안 시간당 내 돈(Company.hourly_net) × weekly.reward_hours(24)). 화면 표시용이자 실제 보상
static func reward_money(b: Balance, state: GameState) -> int:
	return floori(Company.hourly_net(b, state) * b.weekly_reward_hours)


## 배송 n건을 이번 주에 더한다 (trip.gd가 부름). 목표에 처음 닿으면 돈(reward_money) + 경험치 + 알림 { "type": "weekly_done", "money", "xp" }
static func add_parcels(state: GameState, b: Balance, n: int) -> void:
	if n <= 0:
		return
	state.weekly_parcels += n
	if not state.weekly_done and state.weekly_parcels >= b.weekly_target:
		state.weekly_done = true
		var money := reward_money(b, state)
		state.money += money
		state.add_event({ "type": "weekly_done", "money": money, "xp": b.weekly_xp })
		Driver.add_xp(state, b, b.weekly_xp)


## 주 번호가 바뀌었으면 진행 0, 보상 다시 받을 수 있게 (master.gd tick이 부름). 처음(NO_WEEK)이면 지금 진행 그대로 그 주로.
## 시계가 거꾸로 가서 주 번호가 줄어도 "바뀜"으로 본다 (멈추지 않게. 시계 조작은 허용: 기획서 4.7)
static func roll_week(state: GameState, week: int) -> void:
	if state.weekly_week == week:
		return
	if state.weekly_week != NO_WEEK:
		state.weekly_parcels = 0
		state.weekly_done = false
	state.weekly_week = week
