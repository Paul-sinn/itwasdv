## 명장 방문일 (v6b). C1에는 주 번호·요일과 주가 바뀔 때 주간 목표 0으로 돌리기만 있다 (명장·보험·보너스는 C2).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 시계를 직접 읽지 않는다: 현지 시각 now_local을 화면이 넘겨 준다.
## now_local = 현지 시각을 1970-01-01 0시(현지)부터 센 초 (화면: Time.get_unix_time_from_system() + 시간대 차이(초))
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
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


## 프레임마다(또는 켤 때) 부름. C1: 주가 바뀌면 주간 목표 진행 0 (Weekly.roll_week).
## C2에서 요일 적용·보너스 굴리기·예고·active_bonus 갱신을 더한다 (그래서 b·rng를 이미 받음)
static func tick(state: GameState, _b: Balance, now_local: int, _rng: RandomNumberGenerator) -> void:
	Weekly.roll_week(state, week_index(now_local))


## 1970-01-01 0시(현지)부터 며칠째 (그 전이면 음수)
static func _day(now_local: int) -> int:
	return floori(now_local / float(SECONDS_PER_DAY))
