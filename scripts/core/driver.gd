## 기사 레벨: 경험치 → 레벨업 → 포인트, 만렙 뒤에는 회사 평판. 강화 단계 첫 달성 보너스.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 경험치를 주는 곳: 배송 1건(trip.gd advance), 퀘스트 보상(quest.gd), 강화 첫 달성(enhance.gd → on_star_reached)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")


static func max_level(b: Balance) -> int:
	return b.driver_max_level


## 그 레벨에서 다음 레벨까지 경험치 = round(base_xp × 레벨 ^ exponent). 만렙이면 0
static func xp_need(b: Balance, level: int) -> int:
	if level >= max_level(b):
		return 0
	return roundi(b.driver_base_xp * pow(level, b.driver_exponent))


## 경험치를 받는다: 필요량을 넘는 동안 레벨 +1 (남는 경험치는 이어 감), 레벨마다 포인트.
## 만렙이면 받은 만큼 평판으로 (만렙이 되는 순간 남은 경험치도). 알림을 쌓는다
static func add_xp(state: GameState, b: Balance, amount: int) -> void:
	if amount <= 0:
		return
	if state.driver_level >= max_level(b):
		state.reputation += amount
		return
	state.driver_xp += amount
	while state.driver_level < max_level(b) and state.driver_xp >= xp_need(b, state.driver_level):
		state.driver_xp -= xp_need(b, state.driver_level)
		state.driver_level += 1
		var points := b.driver_points_per_level
		if state.driver_level % 10 == 0:
			points += b.driver_bonus_points_every_10
		state.ability_points += points
		state.add_event({ "type": "level_up", "level": state.driver_level, "points": points })
	if state.driver_level >= max_level(b):
		state.reputation += state.driver_xp
		state.driver_xp = 0
		state.add_event({ "type": "max_level" })


## 강화 성공 뒤에 Enhance가 부른다: 그 단계 이하의 보너스 단계 중 아직 안 받은 것마다 보너스 경험치 (단계마다 한 번, 어느 트럭이든)
## "이하"로 보는 이유: 보너스 단계를 건너뛴 상태(형식 4 저장에서 +20으로 시작 등)여도 다음 성공 때 받게
static func on_star_reached(state: GameState, b: Balance, star: int) -> void:
	for m in b.driver_star_milestones:
		if star >= m and not state.milestones_done.has(m):
			state.milestones_done.append(m)
			state.add_event({ "type": "milestone", "star": m, "xp": b.driver_star_milestone_xp })
			add_xp(state, b, b.driver_star_milestone_xp)
