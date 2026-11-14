## 기업 계약 (v7b): 대리점에서 회사 평판(만렙 뒤 경험치)이 기준에 닿을 때마다 1개 자동 체결 (최대 = 기준 수 3). 고르기·관리 없음.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 계약 1개 = 시간당 고정 금액: 맺는 순간 floor(Company.hourly_sales × sales_share[k])로 정해 저장 (GameState.contracts). 트럭 시간 안 씀.
## 받는 돈 = 그 금액 × (1 + 협상) (지금 찍은 값으로 그때그때).
## 켜 둔 동안: tick이 쌓아 정수만 들어옴 (소수는 contract_carry로 이월). 세금은 뗌(번 돈), 직원 몫 없음.
##   오늘 집계: today_sales·today_tax에 더하고, 매출 중 계약 몫을 today_contract에 (Company.today "contract")
## 꺼둔 동안: Trip.apply_offline이 offline()을 부름 (시간당 × 야간팀 % × 창고 상한 시간까지)
## 순위 매출(Company.hourly_sales)에는 안 넣음. "약 N분 뒤"(Company.hourly_net)에는 세금 뗀 값으로 넣음
extends RefCounted

const Ability = preload("res://scripts/core/ability.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")   # company ↔ contract 고리 (trip ↔ company처럼 Godot 4.6.3에서 됨)
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")


## 맺은 계약 수 0~3
static func count(state: GameState) -> int:
	return state.contracts.size()


## 다음 계약 평판 기준 (다 맺었으면 -1)
static func next_reputation(b: Balance, state: GameState) -> int:
	var k := count(state)
	return b.contract_reputation[k] if k < b.contract_reputation.size() else -1


## k번째 계약 시간당 수입 = 맺을 때 정한 금액 × (1 + 협상). 세금 떼기 전
static func hourly_of(b: Balance, state: GameState, k: int) -> float:
	return state.contracts[k] * (1.0 + Ability.value(b, state, "nego"))


## 계약 시간당 수입 합 (협상 반영, 세금 떼기 전)
static func hourly(b: Balance, state: GameState) -> float:
	var sum := 0.0
	for k in count(state):
		sum += hourly_of(b, state, k)
	return sum


## 프레임마다 (화면이 부름). ① 대리점이고 평판 ≥ 다음 기준이면 1개 체결 (한 번에 하나: 알림이 하나씩 뜨게)
##   알림 { "type": "contract", "index": k, "hourly": 그 계약 시간당 (협상 반영, 정수 버림) }
## ② 계약 수입 dt초치를 쌓아 정수만 내 돈으로 (세금 뗌)
static func tick(state: GameState, b: Balance, dt: float) -> void:
	var need := next_reputation(b, state)
	if state.company_stage >= GameState.AGENCY and need >= 0 and state.reputation >= need:
		var k := count(state)
		state.contracts.append(floori(Company.hourly_sales(b, state) * b.contract_shares[k]))
		state.add_event({ "type": "contract", "index": k, "hourly": floori(hourly_of(b, state, k)) })
	if dt <= 0.0 or count(state) == 0:
		return
	state.contract_carry += hourly(b, state) * dt / Economy.SECONDS_PER_HOUR
	var whole := floori(state.contract_carry)
	state.contract_carry -= whole
	_earn(b, state, whole)


## 꺼둔 동안 hours시간 × rate(야간팀 비율): 번 돈 = floor(시간당 × hours × rate)를 내 돈·오늘 집계에 (세금 뗌). [번 돈, 세금]
static func offline(b: Balance, state: GameState, hours: float, rate: float) -> Array:
	var gross := floori(hourly(b, state) * hours * rate)
	return [gross, _earn(b, state, gross)]


## 계약 번 돈 gross를 상태에: 세금을 떼고 내 돈, 오늘 매출·세금·계약 몫에 더함. 뗀 세금을 돌려줌.
## 세금 = 오늘 계약 몫 누계로 반올림한 차이 (프레임마다 1~2원씩 들어와도 round(1 × 3%) = 0으로 세금이 안 빠지지 않게)
static func _earn(b: Balance, state: GameState, gross: int) -> int:
	if gross <= 0:
		return 0
	var r := Company.tax_rate(b, state)
	var tax := roundi((state.today_contract + gross) * r) - roundi(state.today_contract * r)
	state.money += gross - tax
	state.today_sales += gross
	state.today_tax += tax
	state.today_contract += gross
	return tax
