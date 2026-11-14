## 회사 (v7a): 대리점 창업, 보조 트럭 사기, 세금 비율, 순위표, 오늘 집계.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 배송마다 직원 몫·세금을 떼는 것과 오늘 집계에 더하는 것은 trip.gd (_split), 날짜가 바뀌면 0으로는 master.gd tick.
## 회사 단계: GameState.company_stage (0 개인 기사, 1 대리점). 트럭 0 = 내 트럭, 1~ = 보조 트럭.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Contract = preload("res://scripts/core/contract.gd")   # company ↔ contract 고리 (trip ↔ company처럼)
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Trip = preload("res://scripts/core/trip.gd")


## 0 = 개인 기사, 1 = 대리점
static func stage(state: GameState) -> int:
	return state.company_stage


## 지금 단계 세율 (개인 기사 0, 대리점 0.03)
static func tax_rate(b: Balance, state: GameState) -> float:
	return b.tax_rates[state.company_stage]


static func agency_price(b: Balance) -> int:
	return b.agency_price


## 개인 기사이고 창업할 돈이 있나
static func can_found(b: Balance, state: GameState) -> bool:
	return state.company_stage == GameState.SOLO and state.money >= b.agency_price


## 돈을 내고 대리점으로. 알림 { "type": "agency_founded" }. 못 하면 아무것도 안 하고 false
static func found(b: Balance, state: GameState) -> bool:
	if not can_found(b, state):
		return false
	state.money -= b.agency_price
	state.company_stage = GameState.AGENCY
	state.add_event({ "type": "agency_founded" })
	return true


## 보조 트럭 수 (트럭 0은 내 트럭)
static func helper_count(state: GameState) -> int:
	return state.trucks.size() - 1


## 다음 보조 트럭 값. 대리점 전이거나 다 샀으면 −1
static func helper_price(b: Balance, state: GameState) -> int:
	var n := helper_count(state)
	if state.company_stage < GameState.AGENCY or n >= b.helper_prices.size():
		return -1
	return b.helper_prices[n]


static func can_buy_helper(b: Balance, state: GameState) -> bool:
	var price := helper_price(b, state)
	return price >= 0 and state.money >= price


## 돈을 내고 보조 트럭 1대 (+0, 세팅 없음, 바로 달림). 알림 { "type": "helper_bought", "truck": 번호 }. 못 사면 false
static func buy_helper(b: Balance, state: GameState) -> bool:
	if not can_buy_helper(b, state):
		return false
	state.money -= helper_price(b, state)
	state.trucks.append(TruckState.new())
	state.add_event({ "type": "helper_bought", "truck": state.trucks.size() - 1 })
	return true


## 순위 기준 시간당 매출: 모든 트럭 Trip.hourly_income 합 (직원 몫·세금 떼기 전). 기업 계약은 안 넣음 (트럭 배송 매출로만 경쟁, v7b)
static func hourly_sales(b: Balance, state: GameState) -> float:
	var sum := 0.0
	for i in state.trucks.size():
		sum += Trip.hourly_income(b, state, i)
	return sum


## 켜 둔 동안 시간당 내 돈: 모든 트럭 Trip.hourly_net 합 (직원 몫·세금 뗀 뒤, 급송 뺌) + 기업 계약 × (1 − 세율) (v7b).
## "N원 모자람 · 약 N분 뒤"는 이 값을 Economy.seconds_to_afford(price, money, hourly)에 넘긴다. 주간 목표 돈 보상(24시간치)도 이 값
static func hourly_net(b: Balance, state: GameState) -> float:
	var sum := Contract.hourly(b, state) * (1.0 - tax_rate(b, state))
	for i in state.trucks.size():
		sum += Trip.hourly_net(b, state, i)
	return sum


## 순위 1~(라이벌 수 + 1). 나보다 매출이 큰 라이벌 수 + 1 (같으면 내가 앞). 대리점 전이면 0
static func rank(b: Balance, state: GameState) -> int:
	if state.company_stage < GameState.AGENCY:
		return 0
	var mine := hourly_sales(b, state)
	var ahead := 0
	for r in b.rivals:
		if r > mine:
			ahead += 1
	return ahead + 1


## 바로 위 순위까지 모자란 시간당 매출. 1위거나 대리점 전이면 0
static func next_gap(b: Balance, state: GameState) -> float:
	if state.company_stage < GameState.AGENCY:
		return 0.0
	var mine := hourly_sales(b, state)
	for r in b.rivals:   # 오름차순 (balance.gd가 검사)
		if r > mine:
			return r - mine
	return 0.0


## 오늘(현지 날짜) 집계 { "sales": 번 돈, "staff": 직원 몫, "tax": 세금, "profit": 순이익 = 내 돈으로 들어온 것,
##   "contract": 매출 중 기업 계약 몫 (v7b. sales에 이미 들어 있음, 그 세금도 tax에) }
static func today(state: GameState) -> Dictionary:
	return { "sales": state.today_sales, "staff": state.today_staff, "tax": state.today_tax,
			"profit": state.today_sales - state.today_staff - state.today_tax, "contract": state.today_contract }


## 처음 1위가 되면 알림 { "type": "rank_first" } 한 번 (rank_first_done 저장). Trip.advance가 부를 때마다 부름
static func check_first(state: GameState, b: Balance) -> void:
	if not state.rank_first_done and rank(b, state) == 1:
		state.rank_first_done = true
		state.add_event({ "type": "rank_first" })
