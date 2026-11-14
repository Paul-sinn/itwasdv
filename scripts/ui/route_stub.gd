## shortcut: v7b C1(계산 쪽 노선 함수) 전 임시 껍데기. 지시서 "코드 약속"의 Trip 함수와 같은 이름·인자.
## C1을 합치면 화면 코드(main.gd, office_tab.gd)의 RouteStub.<함수>를 Trip.<함수>로 바꾸고
## (long_star는 balance의 routes.long.unlock_star) 이 파일을 지운다. 확인 스크립트(check_v7b.gd)가 아래 값을 넣어 화면 길을 시험한다.
## 여기 값은 화면 시험용 가짜 (돈·시간 계산 규칙이 아님)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")

static var choice := {}   ## 트럭 번호 → 스위치 값 "city" / "long" (없으면 "city")
static var lap := {}      ## 트럭 번호 → 이번 바퀴 노선 (없으면 Trip.route_id)
static var open := {}     ## 트럭 번호 → 장거리 열림 (없으면 false)
static var star := 10     ## 장거리가 열리는 단계 (지시서 routes.long.unlock_star)


static func route_id(s: GameState, i: int) -> String:
	return lap.get(i, Trip.route_id(s, i))


static func route_choice(_s: GameState, i: int) -> String:
	return choice.get(i, "city")


static func can_long(_b: Balance, _s: GameState, i: int) -> bool:
	return open.get(i, false)


static func set_route(b: Balance, s: GameState, i: int, id: String) -> bool:
	if id == "long" and not can_long(b, s, i):
		return false
	choice[i] = id
	return true


static func hourly_income_on(b: Balance, s: GameState, i: int, id: String) -> float:
	return Trip.hourly_income(b, s, i) * (2.0 if id == "long" else 1.0)


static func lap_seconds_left(b: Balance, s: GameState, i: int) -> float:
	return maxf(Trip.lap_seconds(b, s, i) - s.truck(i).lap_clock, 0.0)


static func long_star(_b: Balance) -> int:
	return star
