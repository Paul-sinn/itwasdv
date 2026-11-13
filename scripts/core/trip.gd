## 한 바퀴 계산: 출력 → 속도 → 한 바퀴 초 → 배송 돈 → 시간당 수입, 트럭 진행, 꺼둔 동안.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 스페어 드랍 굴리기는 이 파일에만 둔다.
##
## 한 바퀴: 물류센터에서 N개 싣고(load_seconds) → 도로를 돌며 N집에 배송(집마다 stop_seconds) → 복귀.
## 속도 단위: 출력 1 = 1초에 도로 1칸.
## i번째 집(1~N) 배송 완료 시각 = load_seconds + (도로 ÷ 속도) × i ÷ (N+1) + i × stop_seconds
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")


## 엔진 출력 = base_power + power_gain[0] + … + power_gain[단계-1]
static func power(b: Balance, star: int) -> int:
	assert(star >= 0 and star <= b.max_star, "없는 단계: %d" % star)
	var p := b.base_power
	for s in star:
		p += b.power_gain[s]
	return p


static func speed(b: Balance, t: TruckState) -> float:
	return _speed_at(b, t, t.star)


## 한 바퀴에 싣는 개수 N
static func cargo(b: Balance, _t: TruckState) -> int:
	return b.base_cargo   # v4에서 적재함 세팅


static func lap_seconds(b: Balance, t: TruckState) -> float:
	return _lap_seconds_at(b, t, t.star)


## 배송 1건 돈 = 단가 − 기름값 − 정비비 (각각 원 단위 반올림)
static func parcel_pay(b: Balance) -> int:
	return b.unit_price - roundi(b.unit_price * b.fuel_rate) - roundi(b.unit_price * b.maint_rate)


static func lap_income(b: Balance, t: TruckState) -> int:
	return cargo(b, t) * parcel_pay(b)


## 시간당 수입 = 한 바퀴 수입 × 3600 ÷ 한 바퀴 초 (소수. 화면에는 버림)
static func hourly_income(b: Balance, t: TruckState) -> float:
	return hourly_income_at(b, t, t.star)


## 단계만 star로 바꿨을 때의 시간당 수입 ("성공하면 시간당")
static func hourly_income_at(b: Balance, t: TruckState, star: int) -> float:
	return lap_income(b, t) * Economy.SECONDS_PER_HOUR / _lap_seconds_at(b, t, star)


## 트럭 i를 dt초 진행. 그사이 끝난 배송마다 돈을 더하고 이벤트를 돌려준다 (dt가 길면 여러 바퀴).
##   { "type": "parcel", "pay": int, "house": int(0~N-1) } / { "type": "spare" } (바로 앞 배송에서 나옴)
## 바퀴 중간에 단계가 바뀌면 남은 집은 새 속도로 계산한다 (이미 지난 집은 바로 배송).
static func advance(state: GameState, b: Balance, i: int, dt: float, rng: RandomNumberGenerator) -> Array:
	var events := []
	if dt <= 0.0:
		return events
	var t := state.truck(i)
	t.lap_clock += dt
	var n := cargo(b, t)
	var drive := b.road_length / speed(b, t)
	var lap := lap_seconds(b, t)
	var pay := parcel_pay(b)
	while true:
		if t.lap_delivered < n:
			var k := t.lap_delivered + 1
			if t.lap_clock < b.load_seconds + drive * k / (n + 1) + k * b.stop_seconds:
				break
			state.money += pay
			events.append({ "type": "parcel", "pay": pay, "house": t.lap_delivered })
			t.lap_delivered = k
			if Enhance.random01(rng) < b.spare_drop_chance:
				state.spares += 1
				events.append({ "type": "spare" })
		elif t.lap_clock >= lap:
			t.lap_clock -= lap
			t.lap_delivered = 0
		else:
			break
	return events


## 꺼둔 동안을 상태에 반영(모든 트럭)하고 { "money": int, "parcels": int, "spares": int, "hours": float } 를 돌려준다.
##   시간 = min(꺼둔 초 ÷ 3600, cap_hours). 꺼둔 초가 0 이하(시계가 거꾸로 감)면 전부 0
##   돈 = 트럭마다 floor(시간당 수입 × 시간 × rate)의 합
##   배송 = 트럭마다 floor(N × 3600 ÷ 한 바퀴 초 × 시간 × rate)의 합
##   스페어 = 배송 × 드랍 확률을 spare_drop_carry에 더하고 정수 부분만큼 (나머지는 다음에 이어짐)
## 트럭의 바퀴 진행(lap_clock)은 그대로 둔다.
static func apply_offline(state: GameState, b: Balance, seconds_away: float) -> Dictionary:
	if seconds_away <= 0.0:
		return { "money": 0, "parcels": 0, "spares": 0, "hours": 0.0 }
	var hours := minf(seconds_away / Economy.SECONDS_PER_HOUR, b.offline_cap_hours)
	var money := 0
	var parcels := 0
	for t: TruckState in state.trucks:
		money += floori(hourly_income(b, t) * hours * b.offline_rate)
		parcels += floori(cargo(b, t) * Economy.SECONDS_PER_HOUR / lap_seconds(b, t) * hours * b.offline_rate)
	state.spare_drop_carry += parcels * b.spare_drop_chance
	var spares := floori(state.spare_drop_carry)
	state.spare_drop_carry -= spares
	state.money += money
	state.spares += spares
	return { "money": money, "parcels": parcels, "spares": spares, "hours": hours }


static func _speed_at(b: Balance, _t: TruckState, star: int) -> float:
	return float(power(b, star))   # v4에서 × (1 + 세팅 이동 속도 % 합)


static func _lap_seconds_at(b: Balance, t: TruckState, star: int) -> float:
	return b.load_seconds + b.road_length / _speed_at(b, t, star) + cargo(b, t) * b.stop_seconds
