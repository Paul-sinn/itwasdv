## 급송 요청 전화 (v6b): 켜 둔 동안 30~60분(고르게)에 한 번 벨 → ring_seconds 안에 받으면 내 트럭(트럭 0)의 다음 N건이 단가 ×2.
## 안 받으면 사라짐 (손해 없음). 끄면(state.rush_enabled = false) 안 울림. 급송이 남아 있는 동안은 다음 벨 시계가 안 감.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 벨 간격 굴리기는 이 파일에만. 급송 배송의 돈은 trip.gd.
## 꺼둔 동안(Trip.apply_offline)에는 tick을 안 부르므로 시계가 안 감.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")


## 켜 둔 동안 프레임마다. 벨이 울리기 시작하면 알림 { "type": "rush_call" }, 안 받고 끝나면 { "type": "rush_missed" } (state.take_events)
## dt가 길어도(빨리 감기) 그사이 일을 차례로 처리한다
static func tick(state: GameState, b: Balance, dt: float, rng: RandomNumberGenerator) -> void:
	if not state.rush_enabled:
		state.rush_ring = 0.0   # 울리던 중에 끄면 조용히 끝 (알림 없음). 다음 벨까지 남은 시간은 그대로 둠
		return
	if state.rush_next < 0.0:
		state.rush_next = _interval(b, rng)
	var left := dt
	while left > 0.0:
		if state.rush_ring > 0.0:
			var used := minf(left, state.rush_ring)
			state.rush_ring -= used
			left -= used
			if state.rush_ring <= 0.0:
				state.rush_ring = 0.0
				state.rush_next = _interval(b, rng)
				state.add_event({ "type": "rush_missed" })
		elif state.rush_left > 0:
			return   # 급송이 남아 있는 동안은 다음 벨 시계가 안 감
		else:
			var used := minf(left, state.rush_next)
			state.rush_next -= used
			left -= used
			if state.rush_next <= 0.0:
				state.rush_ring = b.rush_ring_seconds
				state.add_event({ "type": "rush_call" })


static func is_ringing(state: GameState) -> bool:
	return state.rush_ring > 0.0


## 벨이 울리는 동안 받기: 급송 N건을 남기고 벨 끝, 다음 벨 간격을 새로 굴려 둠 (급송이 끝난 뒤부터 흐름). 안 울리면 false
static func accept(state: GameState, b: Balance) -> bool:
	if not is_ringing(state):
		return false
	state.rush_ring = 0.0
	state.rush_left = b.rush_parcels
	state.rush_next = -1.0   # 다음 tick에서 굴림
	return true


## 남은 급송 건수 (트럭 0 배송마다 1씩 줄어듦: trip.gd)
static func parcels_left(state: GameState) -> int:
	return state.rush_left


## 다음 벨까지 초 = min_minutes ~ max_minutes 사이 고르게
static func _interval(b: Balance, rng: RandomNumberGenerator) -> float:
	return (b.rush_min_minutes + Enhance.random01(rng) * (b.rush_max_minutes - b.rush_min_minutes)) * 60.0
