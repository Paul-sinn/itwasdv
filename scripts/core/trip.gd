## 한 바퀴 계산: 출력 → 속도 → 한 바퀴 초 → 배송 돈 → 시간당 수입, 트럭 진행, 꺼둔 동안.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 스페어 드랍·오버부스트 굴리기는 이 파일에만 둔다.
##
## 한 바퀴: 물류센터에서 N개 싣고(load_seconds) → 도로를 돌며 N집에 배송(집마다 stop_seconds) → 복귀.
## 속도 단위: 출력 1 = 1초에 도로 1칸. 세팅(이동 속도·적재량·기름값 절감·오버부스트)은 Setting.total로 더한다.
## i번째 집(1~N) 배송 완료 시각 = load_seconds + (그 바퀴 달리는 초) × i ÷ (N+1) + i × stop_seconds
## 오버부스트: 바퀴를 출발할 때 (확률 합)으로 굴려서, 걸린 바퀴는 달리는 초 − min(overboost_seconds, 달리는 초 ÷ overboost_mult)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Depot = preload("res://scripts/core/depot.gd")
const Driver = preload("res://scripts/core/driver.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Setting = preload("res://scripts/core/setting.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")


## 엔진 출력 = base_power + power_gain[0] + … + power_gain[단계-1]
static func power(b: Balance, star: int) -> int:
	assert(star >= 0 and star <= b.max_star, "없는 단계: %d" % star)
	var p := b.base_power
	for s in star:
		p += b.power_gain[s]
	return p


## 속도 = 출력 × (1 + 이동 속도 % 합)
static func speed(b: Balance, t: TruckState) -> float:
	return _speed_at(b, t, t.star)


## 한 바퀴에 싣는 개수 N = floor(기본 적재량 × (1 + 적재량 % 합))
static func cargo(b: Balance, t: TruckState) -> int:
	# 1e-9: 20 × 1.4처럼 딱 떨어져야 할 곱이 27.999…로 나와 1건 모자라지 않게 (실수 찌꺼기만 막음)
	return floori(b.base_cargo * (1.0 + Setting.total(b, t, "cargo")) + 1e-9)


## 지금 바퀴의 초 (오버부스트가 걸린 바퀴면 짧음)
static func lap_seconds(b: Balance, t: TruckState) -> float:
	return _lap_at(b, t, t.star, t.boost_lap)


## 평균 한 바퀴 초 = 안 걸린 바퀴 × (1 − p) + 걸린 바퀴 × p,  p = min(오버부스트 합, 1)
static func avg_lap_seconds(b: Balance, t: TruckState) -> float:
	return _avg_lap_at(b, t, t.star)


## 배송 1건 돈 = 단가 − round(단가 × fuel_rate × (1 − f)) − round(단가 × maint_rate × (1 − m))
##   f, m = 기름값·정비비 절감 합. f + m 이 cost_cut_cap을 넘으면 둘 다 같은 비율로 줄여 합 = cap
static func parcel_pay(b: Balance, t: TruckState) -> int:
	var f := Setting.total(b, t, "fuel_cut")
	var m := Setting.total(b, t, "maint_cut")   # 정비비 감소(타이어)는 v7. 지금은 늘 0
	var sum := f + m
	if sum > b.cost_cut_cap:
		f = f * b.cost_cut_cap / sum
		m = m * b.cost_cut_cap / sum
	return b.unit_price - roundi(b.unit_price * b.fuel_rate * (1.0 - f)) - roundi(b.unit_price * b.maint_rate * (1.0 - m))


static func lap_income(b: Balance, t: TruckState) -> int:
	return cargo(b, t) * parcel_pay(b, t)


## 시간당 수입 = 한 바퀴 수입 × 3600 ÷ 평균 한 바퀴 초 (소수. 화면에는 버림)
static func hourly_income(b: Balance, t: TruckState) -> float:
	return hourly_income_at(b, t, t.star)


## 단계만 star로 바꿨을 때의 시간당 수입 ("성공하면 시간당"). 세팅은 그 트럭 그대로
static func hourly_income_at(b: Balance, t: TruckState, star: int) -> float:
	return lap_income(b, t) * Economy.SECONDS_PER_HOUR / _avg_lap_at(b, t, star)


## 트럭 i를 dt초 진행. 그사이 끝난 배송마다 돈을 더하고 이벤트를 돌려준다 (dt가 길면 여러 바퀴).
##   { "type": "parcel", "pay": int, "house": int(0~N-1) } / { "type": "spare" } (바로 앞 배송에서 나옴)
##   { "type": "boost" } (새 바퀴를 출발할 때 오버부스트가 걸림)
## 바퀴 중간에 단계·세팅이 바뀌면 남은 집은 새 속도로 계산한다 (이미 지난 집은 바로 배송).
## 배송마다 parcels_total +1, 기사 경험치. 부를 때마다 끝에 Quest.check 한 번 (레벨·퀘스트 알림은 state.take_events)
static func advance(state: GameState, b: Balance, i: int, dt: float, rng: RandomNumberGenerator) -> Array:
	var events := []
	if dt > 0.0:
		_drive(state, b, i, dt, rng, events)
	Quest.check(state, b)
	return events


static func _drive(state: GameState, b: Balance, i: int, dt: float, rng: RandomNumberGenerator, events: Array) -> void:
	var t := state.truck(i)
	t.lap_clock += dt
	var n := cargo(b, t)
	var pay := parcel_pay(b, t)
	var boost_chance := minf(Setting.total(b, t, "overboost"), 1.0)
	var drive := _drive_at(b, t, t.star, t.boost_lap)
	while true:
		if t.lap_delivered < n:
			var k := t.lap_delivered + 1
			if t.lap_clock < b.load_seconds + drive * k / (n + 1) + k * b.stop_seconds:
				break
			state.money += pay
			state.parcels_total += 1
			Driver.add_xp(state, b, b.driver_xp_per_parcel)
			events.append({ "type": "parcel", "pay": pay, "house": t.lap_delivered })
			t.lap_delivered = k
			if Enhance.random01(rng) < b.spare_drop_chance:
				state.spares += 1
				events.append({ "type": "spare" })
		elif t.lap_clock >= _lap_from_drive(b, n, drive):
			t.lap_clock -= _lap_from_drive(b, n, drive)
			t.lap_delivered = 0
			t.boost_lap = boost_chance > 0.0 and Enhance.random01(rng) < boost_chance
			if t.boost_lap:
				events.append({ "type": "boost" })
			drive = _drive_at(b, t, t.star, t.boost_lap)
		else:
			break


## 꺼둔 동안을 상태에 반영(모든 트럭)하고 돌려준다:
##   { "money": int, "parcels": int, "spares": int, "hours": float, "xp": int, "full": bool, "ignored": bool }
##   꺼둔 초 < offline.ignore_under_seconds(3분)면 아무것도 안 함: ignored = true, 나머지 0 (시계가 거꾸로 간 음수도)
##   시간 = min(꺼둔 초 ÷ 3600, 창고 시간). full = 창고 시간에 닿음
##   돈 = 트럭마다 floor(시간당 수입 × 시간 × 야간팀 비율)의 합 (시간당 수입은 오버부스트 평균)
##   배송 = 트럭마다 floor(N × 3600 ÷ 평균 한 바퀴 초 × 시간 × 야간팀 비율)의 합 → parcels_total에도 더함
##   스페어 = 배송 × 드랍 확률을 spare_drop_carry에 더하고 정수 부분만큼 (나머지는 다음에 이어짐)
##   경험치 = 0 (꺼둔 동안 경험치는 v5b 노하우)
## 트럭의 바퀴 진행(lap_clock)은 그대로 둔다.
static func apply_offline(state: GameState, b: Balance, seconds_away: float) -> Dictionary:
	if seconds_away < b.offline_ignore_under_seconds:
		return { "money": 0, "parcels": 0, "spares": 0, "hours": 0.0, "xp": 0, "full": false, "ignored": true }
	var cap := Depot.cap_hours(b, state)
	var rate := Depot.rate(b, state)
	var hours := minf(seconds_away / Economy.SECONDS_PER_HOUR, cap)
	var money := 0
	var parcels := 0
	for t: TruckState in state.trucks:
		money += floori(hourly_income(b, t) * hours * rate)
		parcels += floori(cargo(b, t) * Economy.SECONDS_PER_HOUR / avg_lap_seconds(b, t) * hours * rate)
	state.spare_drop_carry += parcels * b.spare_drop_chance
	var spares := floori(state.spare_drop_carry)
	state.spare_drop_carry -= spares
	state.money += money
	state.spares += spares
	state.parcels_total += parcels
	return { "money": money, "parcels": parcels, "spares": spares, "hours": hours, "xp": 0, "full": hours >= cap, "ignored": false }


static func _speed_at(b: Balance, t: TruckState, star: int) -> float:
	return power(b, star) * (1.0 + Setting.total(b, t, "speed"))


## 달리는 초 = 도로 ÷ 속도. 오버부스트가 걸린 바퀴는 − min(overboost_seconds, 달리는 초 ÷ overboost_mult)
static func _drive_at(b: Balance, t: TruckState, star: int, boosted: bool) -> float:
	var drive := b.road_length / _speed_at(b, t, star)
	if boosted:
		drive -= minf(b.overboost_seconds, drive / b.overboost_mult)
	return drive


static func _lap_from_drive(b: Balance, n: int, drive: float) -> float:
	return b.load_seconds + drive + n * b.stop_seconds


static func _lap_at(b: Balance, t: TruckState, star: int, boosted: bool) -> float:
	return _lap_from_drive(b, cargo(b, t), _drive_at(b, t, star, boosted))


static func _avg_lap_at(b: Balance, t: TruckState, star: int) -> float:
	var p := minf(Setting.total(b, t, "overboost"), 1.0)
	return _lap_at(b, t, star, false) * (1.0 - p) + _lap_at(b, t, star, true) * p
