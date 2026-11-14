## 한 바퀴 계산: 출력 → 속도 → 한 바퀴 초 → 배송 돈 → 시간당 수입, 트럭 진행, 꺼둔 동안.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 스페어 드랍·오버부스트·적재량 소수점·팁·배송 종류(대형·VIP) 굴리기는 이 파일에만 둔다.
##
## 한 바퀴: 물류센터에서 N개 싣고(load_seconds × (1 − 상하차)) → 도로를 돌며 N집에 배송(집마다 정차 = stop_seconds × (1 − 상하차)) → 복귀.
## 속도 단위: 출력 1 = 1초에 도로 1칸. 세팅(이동 속도·적재량·기름값 절감·오버부스트)은 Setting.total로 더한다.
## i번째 집(1~N) 배송 완료 시각 = 싣기 + (그 바퀴 달리는 초) × i ÷ (N+1) + i × 정차
## 바퀴를 출발할 때 굴리는 것 (v6-bal):
##   적재량 N: 평균 cargo()의 소수점을 확률로 +1건 (21.6 → 60%로 22건, 40%로 21건). TruckState.lap_cargo에 둠
##   오버부스트: (확률 합, 최대 1)로 걸리면 그 바퀴 내내 운전 속도 overboost_mult배 = 달리는 초 ÷ overboost_mult
## 평균 계산(시간당 수입, 꺼둔 동안)은 소수점 적재량과 오버부스트 확률을 그대로 쓴다.
## 배송마다 굴리는 것: 스페어 드랍, 팁 (v5b. 팁 = 협상이 적용된 단가 × tip_rate, 기름값·정비비 안 뗌)
## 기사 능력치(v5b)는 내 트럭(트럭 0)에만: 상하차 → 싣는 시간·정차 시간 × (1 − 값) (싣는 시간은 v7-bal), 협상 → 단가 × (1 + 값), 친절 → 팁 확률 + 값,
##   노하우 → 꺼둔 동안 배송에도 경험치 × 값, 정비 지식 → 스페어 드랍 확률 × (1 + 값). 그래서 능력치가 드는 함수는 (b, s, i)를 받는다
## v6b 배송 종류 (모든 트럭, 자기 지금 단계로): 배송마다 VIP 몫(+18부터) → 아니면 대형 몫(+15부터) → 아니면 보통.
##   대형 = 단가 × 3, VIP = × 5 (special.*.pay_mult). 협상·기름값·정비비·팁은 그 단가 기준. 평균 계산은 몫 그대로
## v6b 급송: state.rush_left > 0이면 트럭 0의 배송은 단가 × rush.pay_mult (배송 종류 배수에 곱함). 한 건마다 −1 (벨은 rush.gd)
## v6b 주간 배송 목표: 배송마다(꺼둔 동안은 합) Weekly.add_parcels
## v7-bal 노선 (route_id, balance.json routes): 트럭마다 노선 하나. 지금은 회사 단계로만 (개인 기사 = 동네 "town", 대리점 = 시내 "city", 모든 트럭).
##   단가 × price_mult (협상·팁·대형·VIP·급송은 그 단가 기준), 도로 길이 × road_mult,
##   한 바퀴 싣는 수 = 적재량 × stops_mult (소수는 바퀴마다 확률), 싣는 시간 × stops_mult (집이 는 만큼), 정차는 실은 건수만큼
## v7a 회사: 번 돈(배송 1건 돈·팁)마다 직원 몫(보조 트럭만, × staff_share)·세금(× 세율)을 반올림해 떼고 나머지가 내 돈 (_split).
##   오늘 집계(state.today_*)에 번 돈·직원 몫·세금을 더함. 배송 경험치는 내 트럭만 (대리점이면 시내 경험치), 보조 트럭 0
extends RefCounted

const Company = preload("res://scripts/core/company.gd")

const Ability = preload("res://scripts/core/ability.gd")
const Weekly = preload("res://scripts/core/weekly.gd")

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


## 트럭 i가 달리는 노선 id ("town" / "city", v7b에서 "long"). 지금은 회사 단계로만: 개인 기사 = 동네, 대리점 = 시내 (모든 트럭)
static func route_id(s: GameState, _i: int) -> String:
	return "city" if s.company_stage >= GameState.AGENCY else "town"


## 트럭 i의 평균 한 바퀴 싣는 수 = 기본 적재량 × (1 + 적재량 % 합) × 노선 stops_mult. 소수점 그대로 (예: 21.6, 시내 32.4).
## 실제로 싣는 건수(= 그 바퀴 집 수)는 lap_cargo
static func cargo(b: Balance, s: GameState, i: int) -> float:
	var c: float = b.base_cargo * (1.0 + Setting.total(b, s.truck(i), "cargo")) * _route(b, s, i)["stops_mult"]
	# 20 × 1.4처럼 딱 떨어져야 할 곱이 27.999…로 나와 정수가 아니게 되지 않게 (실수 찌꺼기만 막음)
	return float(roundi(c)) if absf(c - roundi(c)) < 1e-9 else c


## 트럭 i가 지금 바퀴에 실은 건수 = 이번 바퀴 집 수 (TruckState.lap_cargo). 아직 안 굴렸으면(새 트럭·옛 저장, 첫 advance 전) ceil(평균)
static func lap_cargo(b: Balance, s: GameState, i: int) -> int:
	var t := s.truck(i)
	return t.lap_cargo if t.lap_cargo > 0 else ceili(cargo(b, s, i))


## 트럭 i의 지금 바퀴 초 (오버부스트가 걸린 바퀴면 짧음, 정차는 실은 건수만큼, 상하차 능력치 반영)
static func lap_seconds(b: Balance, s: GameState, i: int) -> float:
	var t := s.truck(i)
	return _lap_from_drive(_load(b, s, i), lap_cargo(b, s, i), _drive_at(b, s, i, t.star, t.boost_lap), _stop(b, s, i))


## 화면 트럭 자리: 트럭 i가 지금 바퀴의 어디쯤인가 (0 = 물류센터 출발 → 1 = 복귀). 싣는 동안은 0, 그 뒤 바퀴 끝까지 고르게.
## 싣는 시간은 _load (상하차·노선 반영). 이번 바퀴 집 수는 lap_cargo
static func lap_progress(b: Balance, s: GameState, i: int) -> float:
	var load_s := _load(b, s, i)
	return clampf((s.truck(i).lap_clock - load_s) / maxf(lap_seconds(b, s, i) - load_s, 0.001), 0.0, 1.0)


## 트럭 i의 평균 한 바퀴 초 = 안 걸린 바퀴 × (1 − p) + 걸린 바퀴 × p,  p = min(오버부스트 합, 1)
static func avg_lap_seconds(b: Balance, s: GameState, i: int) -> float:
	return _avg_lap_at(b, s, i, s.truck(i).star)


## 트럭 i의 보통 배송 1건 돈 = 단가 − round(단가 × fuel_rate × (1 − f)) − round(단가 × maint_rate × (1 − m))
##   단가 = round(unit_price × 노선 price_mult × (1 + 협상)) (협상은 트럭 0만). f = min(기름값 절감 합, fuel_cut_cap), m = min(정비비 감소 합, maint_cut_cap)
##   (각자 따로 자름, v7-bal). 팁은 따로 (tip_pay). 대형·VIP·급송은 _pay(배수)
static func parcel_pay(b: Balance, s: GameState, i: int) -> int:
	return _pay(b, s, i, 1.0)


## 트럭 i의 팁 확률 (배송 1건마다) = min(1, tip_base_chance + 친절). 친절은 트럭 0만
static func tip_chance(b: Balance, s: GameState, i: int) -> float:
	return minf(1.0, b.tip_base_chance + _ability(b, s, i, "kind"))


## 트럭 i의 보통 배송 팁 1번 = round(협상이 적용된 단가 × tip_rate). 기름값·정비비 안 뗌. 대형·VIP·급송은 그 단가 기준 (_tip)
static func tip_pay(b: Balance, s: GameState, i: int) -> int:
	return _tip(b, s, i, 1.0)


## 트럭 i의 스페어 드랍 확률 (배송 1건마다, 꺼둔 동안도 같음) = spare_drop_chance × (1 + 정비 지식). 정비 지식은 트럭 0만
static func spare_chance(b: Balance, s: GameState, i: int) -> float:
	return b.spare_drop_chance * (1.0 + _ability(b, s, i, "mech"))


## 트럭 i의 지금 바퀴 수입 = 실은 건수 × 배송 1건 돈 (팁 뺌)
static func lap_income(b: Balance, s: GameState, i: int) -> int:
	return lap_cargo(b, s, i) * parcel_pay(b, s, i)


## 트럭 i의 시간당 수입 = 평균 적재량 × 배송 1건 평균 돈 × 3600 ÷ 평균 한 바퀴 초 (소수. 화면에는 버림)
##   배송 1건 평균 돈 = 종류(보통·대형·VIP) 몫마다 (그 종류 1건 돈 + 팁 확률 × 그 종류 팁)의 합. 급송은 안 들어감 (잠깐이라)
##   번 돈 기준 (직원 몫·세금 떼기 전. 순위·강화 칸 표시용). 떼고 난 내 돈은 hourly_net
static func hourly_income(b: Balance, s: GameState, i: int) -> float:
	return _hourly(b, s, i, s.truck(i).star, false)


## 단계만 star로 바꿨을 때의 시간당 수입 ("성공하면 시간당": +15·+18이면 대형·VIP 몫도 그 단계로). 세팅·능력치는 그대로
static func hourly_income_at(b: Balance, s: GameState, i: int, star: int) -> float:
	return _hourly(b, s, i, star, false)


## 트럭 i의 시간당 내 돈 (hourly_income과 같은 식, 배송 1건 돈·팁마다 직원 몫·세금을 뗀 뒤)
static func hourly_net(b: Balance, s: GameState, i: int) -> float:
	return _hourly(b, s, i, s.truck(i).star, true)


## 트럭 i를 dt초 진행. 그사이 끝난 배송마다 돈을 더하고 이벤트를 돌려준다 (dt가 길면 여러 바퀴).
##   { "type": "parcel", "pay": int, "gross": int, "house": int(0~N-1), "kind": "normal"/"large"/"vip", "rush": bool }
##   { "type": "spare" } (바로 앞 배송에서 나옴)
##   { "type": "tip", "pay": int, "gross": int } (바로 앞 배송에서 나옴. 돈은 이미 더해짐. 순서: parcel → spare(있으면) → tip(있으면))
##   pay = 내 돈으로 들어온 금액 (직원 몫·세금 뗀 뒤), gross = 번 돈
##   { "type": "boost" } (새 바퀴를 출발할 때 오버부스트가 걸림)
## 바퀴 중간에 단계·세팅이 바뀌면 남은 집은 새 속도로 계산한다 (이미 지난 집은 바로 배송). 실은 건수는 다음 바퀴부터.
## 배송마다 parcels_total +1, 기사 경험치. 부를 때마다 끝에 Quest.check 한 번, 트럭 0이면 Company.check_first 한 번 (알림은 state.take_events)
static func advance(state: GameState, b: Balance, i: int, dt: float, rng: RandomNumberGenerator) -> Array:
	var events := []
	if dt > 0.0:
		_drive(state, b, i, dt, rng, events)
	Quest.check(state, b)
	if i == 0:   # 순위는 모든 트럭 시간당 매출을 다시 계산해서, 프레임마다 트럭 수만큼 하지 않게 내 트럭 진행 때만
		Company.check_first(state, b)
	return events


static func _drive(state: GameState, b: Balance, i: int, dt: float, rng: RandomNumberGenerator, events: Array) -> void:
	var t := state.truck(i)
	t.lap_clock += dt
	if t.lap_cargo <= 0:
		t.lap_cargo = _roll_cargo(b, state, i, rng)
	var n := t.lap_cargo
	var stop := _stop(b, state, i)
	var load_s := _load(b, state, i)
	var drop := spare_chance(b, state, i)
	var tip_p := tip_chance(b, state, i)
	var vip_p: float = b.special["vip"]["share"] if t.star >= b.special["vip"]["unlock_star"] else 0.0
	var large_p: float = b.special["large"]["share"] if t.star >= b.special["large"]["unlock_star"] else 0.0
	var money_of := {}   # 배수 → [1건 번 돈, 그 _split, 팁 번 돈, 그 _split] (이번 호출 안에서 같은 배수는 한 번만 계산)
	var xp := _xp_per_parcel(b, state, i)
	var boost_chance := minf(Setting.total(b, t, "overboost"), 1.0)
	var drive := _drive_at(b, state, i, t.star, t.boost_lap)
	while true:
		if t.lap_delivered < n:
			var k := t.lap_delivered + 1
			if t.lap_clock < load_s + drive * k / (n + 1) + k * stop:
				break
			var kind := "normal"   # VIP 몫 → 아니면 대형 몫 (열린 것만 굴림)
			if vip_p > 0.0 and Enhance.random01(rng) < vip_p:
				kind = "vip"
			elif large_p > 0.0 and Enhance.random01(rng) < large_p:
				kind = "large"
			var mult := _kind_mult(b, kind)
			var rush := i == 0 and state.rush_left > 0
			if rush:
				mult *= b.rush_pay_mult
				state.rush_left -= 1
			if not money_of.has(mult):
				var pay_g := _pay(b, state, i, mult)
				var tip_g := _tip(b, state, i, mult)
				money_of[mult] = [pay_g, _split(b, state, i, pay_g), tip_g, _split(b, state, i, tip_g)]
			var m: Array = money_of[mult]
			_earn(state, m[0], m[1])
			state.parcels_total += 1
			Driver.add_xp(state, b, xp)
			events.append({ "type": "parcel", "pay": m[1][2], "gross": m[0], "house": t.lap_delivered, "kind": kind, "rush": rush })
			t.lap_delivered = k
			Weekly.add_parcels(state, b, 1)
			if Enhance.random01(rng) < drop:
				state.spares += 1
				events.append({ "type": "spare" })
			if tip_p > 0.0 and Enhance.random01(rng) < tip_p:
				_earn(state, m[2], m[3])
				events.append({ "type": "tip", "pay": m[3][2], "gross": m[2] })
		elif t.lap_clock >= _lap_from_drive(load_s, n, drive, stop):
			t.lap_clock -= _lap_from_drive(load_s, n, drive, stop)
			t.lap_delivered = 0
			t.lap_cargo = _roll_cargo(b, state, i, rng)
			n = t.lap_cargo
			t.boost_lap = boost_chance > 0.0 and Enhance.random01(rng) < boost_chance
			if t.boost_lap:
				events.append({ "type": "boost" })
			drive = _drive_at(b, state, i, t.star, t.boost_lap)
		else:
			break


## 꺼둔 동안을 상태에 반영(모든 트럭)하고 돌려준다:
##   { "money": int, "staff": int, "tax": int, "parcels": int, "spares": int, "hours": float, "xp": int, "full": bool, "ignored": bool }
##   꺼둔 초 < offline.ignore_under_seconds(3분)면 아무것도 안 함: ignored = true, 나머지 0 (시계가 거꾸로 간 음수도)
##   시간 = min(꺼둔 초 ÷ 3600, 창고 시간). full = 창고 시간에 닿음
##   번 돈 = 트럭마다 floor(시간당 수입 × 시간 × 야간팀 비율) (시간당 수입은 오버부스트·팁·대형·VIP 평균, 능력치 포함. 급송 없음)
##   → 트럭마다 직원 몫·세금을 켜 둔 때와 같은 비율로 떼고(_split) 합. money = 내 돈 합, staff·tax = 뗀 합. 오늘 집계에도 더함
##   배송 = 트럭마다 floor(평균 적재량 × 3600 ÷ 평균 한 바퀴 초 × 시간 × 야간팀 비율)의 합 → parcels_total에도 더함
##   스페어 = 트럭마다 배송 × 그 트럭 드랍 확률(spare_chance)을 spare_drop_carry에 더하고 정수 부분만큼 (나머지는 다음에 이어짐)
##   경험치 = floor(트럭 0 배송 × 배송 1건 경험치(대리점이면 시내) × 노하우) → Driver.add_xp (만렙이면 평판으로). 노하우 0이면 0
##   주간 배송 목표에 배송 합을 더함 (Weekly.add_parcels. 주가 바뀐 뒤 켰으면 Master.tick을 먼저 불러 새 주에)
## 트럭의 바퀴 진행(lap_clock)은 그대로 둔다.
static func apply_offline(state: GameState, b: Balance, seconds_away: float) -> Dictionary:
	if seconds_away < b.offline_ignore_under_seconds:
		return { "money": 0, "staff": 0, "tax": 0, "parcels": 0, "spares": 0, "hours": 0.0, "xp": 0, "full": false, "ignored": true }
	var cap := Depot.cap_hours(b, state)
	var rate := Depot.rate(b, state)
	var hours := minf(seconds_away / Economy.SECONDS_PER_HOUR, cap)
	var money := 0
	var staff := 0
	var tax := 0
	var parcels := 0
	var xp := 0
	for i in state.trucks.size():
		var gross := floori(hourly_income(b, state, i) * hours * rate)
		var parts := _split(b, state, i, gross)
		_earn(state, gross, parts)
		staff += parts[0]
		tax += parts[1]
		money += parts[2]
		var n := floori(cargo(b, state, i) * Economy.SECONDS_PER_HOUR / avg_lap_seconds(b, state, i) * hours * rate)
		parcels += n
		state.spare_drop_carry += n * spare_chance(b, state, i)
		if i == 0:   # 1e-9: 1080 × 10 × 0.175처럼 딱 떨어져야 할 곱이 1889.999…로 1 모자라지 않게 (실수 찌꺼기만 막음)
			xp = floori(n * _xp_per_parcel(b, state, 0) * Ability.value(b, state, "knowhow") + 1e-9)
	var spares := floori(state.spare_drop_carry)
	state.spare_drop_carry -= spares
	state.spares += spares
	state.parcels_total += parcels
	Driver.add_xp(state, b, xp)
	Weekly.add_parcels(state, b, parcels)
	return { "money": money, "staff": staff, "tax": tax, "parcels": parcels, "spares": spares, "hours": hours, "xp": xp,
			"full": hours >= cap, "ignored": false }


static func _speed_at(b: Balance, t: TruckState, star: int) -> float:
	return power(b, star) * (1.0 + Setting.total(b, t, "speed"))


## 트럭 i의 달리는 초 = 도로(× 노선 road_mult) ÷ 속도. 오버부스트가 걸린 바퀴는 ÷ overboost_mult (바퀴 내내 운전 속도 overboost_mult배)
static func _drive_at(b: Balance, s: GameState, i: int, star: int, boosted: bool) -> float:
	var drive: float = b.road_length * _route(b, s, i)["road_mult"] / _speed_at(b, s.truck(i), star)
	return drive / b.overboost_mult if boosted else drive


## 한 바퀴 초 = 싣기 + 달리기 + n집 × 정차 (n은 실은 건수, 평균 계산에서는 소수점 평균. 싣기는 _load, 정차는 _stop)
static func _lap_from_drive(load_s: float, n: float, drive: float, stop: float) -> float:
	return load_s + drive + n * stop


## 트럭 i가 물류센터에서 싣는 초 = load_seconds × 노선 stops_mult × (1 − 상하차)
static func _load(b: Balance, s: GameState, i: int) -> float:
	return b.load_seconds * _route(b, s, i)["stops_mult"] * (1.0 - _ability(b, s, i, "unload"))


## 트럭 i가 집 앞에 서는 초 = stop_seconds × (1 − 상하차)
static func _stop(b: Balance, s: GameState, i: int) -> float:
	return b.stop_seconds * (1.0 - _ability(b, s, i, "unload"))


## 트럭 i의 배송 단가 = round(unit_price × 노선 price_mult × (1 + 협상))
static func _unit(b: Balance, s: GameState, i: int) -> int:
	return roundi(b.unit_price * _route(b, s, i)["price_mult"] * (1.0 + _ability(b, s, i, "nego")))


## 트럭 i의 노선 숫자 { price_mult, road_mult, stops_mult }
static func _route(b: Balance, s: GameState, i: int) -> Dictionary:
	return b.routes[route_id(s, i)]


## 단가 × mult(대형·VIP·급송)인 배송 1건 돈. 기름값·정비비는 그 단가의 %
static func _pay(b: Balance, s: GameState, i: int, mult: float) -> int:
	var t := s.truck(i)
	var f := minf(Setting.total(b, t, "fuel_cut"), b.fuel_cut_cap)
	var m := minf(Setting.total(b, t, "maint_cut"), b.maint_cut_cap)   # 정비비 감소 (타이어·휠, v7a)
	var u := roundi(_unit(b, s, i) * mult)
	return u - roundi(u * b.fuel_rate * (1.0 - f)) - roundi(u * b.maint_rate * (1.0 - m))


## 단가 × mult인 배송의 팁 = round(그 단가 × tip_rate)
static func _tip(b: Balance, s: GameState, i: int, mult: float) -> int:
	return roundi(roundi(_unit(b, s, i) * mult) * b.tip_rate)


## 그 단계의 배송 종류 몫 { "normal", "large", "vip" } (합 1). VIP 몫 먼저, 아니면 대형 몫 (열린 것만)
static func _kind_shares(b: Balance, star: int) -> Dictionary:
	var vip: float = b.special["vip"]["share"] if star >= b.special["vip"]["unlock_star"] else 0.0
	var large: float = b.special["large"]["share"] if star >= b.special["large"]["unlock_star"] else 0.0
	return { "normal": (1.0 - vip) * (1.0 - large), "large": (1.0 - vip) * large, "vip": vip }


## 배송 종류의 단가 배수 (보통 1)
static func _kind_mult(b: Balance, kind: String) -> float:
	return 1.0 if kind == "normal" else b.special[kind]["pay_mult"]


## 트럭 i가 번 돈 gross → [직원 몫, 세금, 내 돈]. 직원 몫 = round(gross × staff_share) (보조 트럭만), 세금 = round(gross × 세율).
## 내 돈 = 나머지 (소수는 내 돈 쪽에서 버림). 세금은 직원 몫을 뗀 나머지를 넘지 않음 (내 돈이 음수가 안 되게)
static func _split(b: Balance, s: GameState, i: int, gross: int) -> Array:
	var staff := roundi(gross * b.staff_share) if i > 0 else 0
	var tax := mini(roundi(gross * b.tax_rates[s.company_stage]), gross - staff)
	return [staff, tax, gross - staff - tax]


## 번 돈 gross와 그 _split을 상태에: 내 돈 + 오늘 집계
static func _earn(s: GameState, gross: int, parts: Array) -> void:
	s.money += parts[2]
	s.today_sales += gross
	s.today_staff += parts[0]
	s.today_tax += parts[1]


## 배송 1건 경험치: 내 트럭만 (보조 트럭 0). 대리점이면 시내 경험치
static func _xp_per_parcel(b: Balance, s: GameState, i: int) -> int:
	if i > 0:
		return 0
	return b.city_xp_per_parcel if s.company_stage >= GameState.AGENCY else b.driver_xp_per_parcel


## 시간당 수입 (hourly_income·hourly_net). net = 배송 1건 돈·팁마다 직원 몫·세금을 뗀 내 돈으로
static func _hourly(b: Balance, s: GameState, i: int, star: int, net: bool) -> float:
	var tip_p := tip_chance(b, s, i)
	var shares := _kind_shares(b, star)
	var per_parcel := 0.0
	for kind: String in shares:
		var mult := _kind_mult(b, kind)
		var pay := _pay(b, s, i, mult)
		var tip := _tip(b, s, i, mult)
		if net:
			pay = _split(b, s, i, pay)[2]
			tip = _split(b, s, i, tip)[2]
		per_parcel += shares[kind] * (pay + tip_p * tip)
	return cargo(b, s, i) * per_parcel * Economy.SECONDS_PER_HOUR / _avg_lap_at(b, s, i, star)


## 능력치 효과는 내 트럭(트럭 0)에만 (보조 트럭은 0)
static func _ability(b: Balance, s: GameState, i: int, id: String) -> float:
	return Ability.value(b, s, id) if i == 0 else 0.0


## 이번 바퀴에 실을 건수: floor(평균) + (소수점 확률로 1). 평균이 정수면 난수를 안 씀
static func _roll_cargo(b: Balance, s: GameState, i: int, rng: RandomNumberGenerator) -> int:
	var c := cargo(b, s, i)
	var n := floori(c)
	if c > n and Enhance.random01(rng) < c - n:
		n += 1
	return n


## 평균 한 바퀴 초 = 안 걸린 바퀴 × (1 − p) + 걸린 바퀴 × p,  p = min(오버부스트 합, 1). 정차는 평균 적재량
static func _avg_lap_at(b: Balance, s: GameState, i: int, star: int) -> float:
	var t := s.truck(i)
	var p := minf(Setting.total(b, t, "overboost"), 1.0)
	var drive := _drive_at(b, s, i, star, false) * (1.0 - p) + _drive_at(b, s, i, star, true) * p
	return _lap_from_drive(_load(b, s, i), cargo(b, s, i), drive, _stop(b, s, i))
