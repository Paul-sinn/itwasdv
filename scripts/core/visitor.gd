## 특별 NPC 3명 (v7-bal): 보험사·마술사·중고 부품상. 명장과 같이 엔진 +10 첫 달성 때 열림.
## 각자 visitors.min_days~max_days(21~28)일에 한 번, 현지 날짜 하루(0~24시) 머묾. 그날 안 켰으면 그 방문은 지나감.
## 하루에 NPC 한 명: 명장 방문 중인 날엔 안 옴, 같은 날 둘 이상이면 IDS 순서(보험사 → 마술사 → 부품상)로 앞이 오고 나머지는 다음 날로.
## 효과는 쓰는 곳이 이 파일 함수로 읽는다: 보험·제휴 할인·복구 보험 → economy.gd·enhance.gd, 마술사 → setting.gd.
## 부품상 선물(고급 스페어)은 그날 처음 tick에서 바로 들어감 (봉투를 안 눌러도).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 방문 날짜·보험사 이벤트 굴리기는 이 파일에만.
## master.gd를 불러오지 않는다 (Master.tick이 이 파일을 부름): 명장 방문 중인지는 state.active_bonus로 본다 (Master.tick이 채움).
## 시계 조작은 허용 (기획서 4.7): 시계가 거꾸로 가서 다음 방문이 너무 멀어지면 오늘부터 다시 굴린다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const IDS := ["insurer", "magician", "dealer"]
## 보험사 이벤트 (방문마다 하나 고르게)
const INSURER_EVENTS := ["partner_discount", "recovery"]
const SECONDS_PER_DAY := 86400


## = Master.is_unlocked (엔진 +10 첫 달성)
static func is_unlocked(state: GameState) -> bool:
	return state.master_unlocked


## 오늘 와 있는 특별 NPC id, 없으면 ""
static func today(state: GameState) -> String:
	return state.visitor_today


## 프레임마다(또는 켤 때) Master.tick 뒤에 부름 (Master.tick이 끝에서 부르므로 화면이 따로 안 불러도 됨).
##   다음 방문 날짜가 없으면(처음) 오늘 + 21~28일, 지났으면(왔거나 놓침) 그 날 + 21~28일 (그래도 지났으면 또 더함)
##   오늘 누가 오는지 정함 (명장 방문 중이면 아무도. 겹치면 뒤 NPC는 다음 날로)
##   방문이 그날 처음이면: 알림 { "type": "visitor", "who": id, "event": 보험사 이벤트 id 또는 "" },
##     보험사면 이벤트를 굴려 저장, 부품상이면 고급 스페어 += n 하고 알림에 "gift": n
static func tick(state: GameState, b: Balance, now_local: int, rng: RandomNumberGenerator) -> void:
	if not state.master_unlocked:
		state.visitor_today = ""
		return
	var day := _day(now_local)
	for id in IDS:
		var nxt: int = state.visitor_next.get(id, day + b.visitor_max_days + 1)
		if nxt > day + b.visitor_max_days:   # 처음, 또는 시계가 거꾸로 감
			nxt = day + rng.randi_range(b.visitor_min_days, b.visitor_max_days)
		nxt = maxi(nxt, day - b.visitor_max_days)   # 아주 오래 안 켰어도 아래 반복이 한두 번이면 끝나게
		while nxt < day:
			nxt += rng.randi_range(b.visitor_min_days, b.visitor_max_days)
		state.visitor_next[id] = nxt
	var who := ""
	for id in IDS:
		if state.visitor_next[id] != day:
			continue
		if who == "" and state.active_bonus == "":
			who = id
		else:
			state.visitor_next[id] = day + 1   # 명장 날이거나 이미 한 명 옴 → 다음 날로
	state.visitor_today = who
	if who == "" or state.visitor_day == day:
		return
	state.visitor_day = day
	var event := { "type": "visitor", "who": who, "event": "" }
	if who == "insurer":
		state.insurer_event = INSURER_EVENTS[rng.randi_range(0, INSURER_EVENTS.size() - 1)]
		event["event"] = state.insurer_event
	elif who == "dealer":
		state.premium_spares += b.dealer_premium_spares
		event["gift"] = b.dealer_premium_spares
	state.add_event(event)


## 오늘 보험사 이벤트: "partner_discount"(제휴 할인) / "recovery"(복구 보험) / "" (보험사가 없는 날)
static func insurer_event(state: GameState) -> String:
	return state.insurer_event if state.visitor_today == "insurer" else ""


## [예]: 보험사가 온 날만 가입하고 true (이미 가입했어도 true). 그날은 되돌릴 수 없음. 다른 날은 아무것도 안 하고 false
static func join_insurance(state: GameState, now_local: int) -> bool:
	if state.visitor_today != "insurer" or _day(now_local) != state.visitor_day:
		return false
	state.insured_day = state.visitor_day
	return true


## 오늘 보험에 가입했나 (보험사가 와 있는 날 [예]를 누름)
static func is_insured(state: GameState) -> bool:
	return state.visitor_today == "insurer" and state.insured_day == state.visitor_day


## 다음 방문 날짜 번호 (현지 날짜, 1970-01-01 = 0. 확인·시뮬용). 아직 안 굴렸으면 −1
static func next_day(state: GameState, id: String) -> int:
	return state.visitor_next.get(id, -1)


## 1970-01-01 0시(현지)부터 며칠째 (Master._day와 같음. 서로 불러오지 않게 여기에도)
static func _day(now_local: int) -> int:
	return floori(now_local / float(SECONDS_PER_DAY))
