## v8a C2: 랩핑 (wrap.gd), 통계·잡옵 도감 (stats.gd), 업적 20개 + 랩핑 보상 (achievement.gd), 숫자 검사, 저장 형식 13 왕복
extends "res://tests/test_base.gd"

const Achievement = preload("res://scripts/core/achievement.gd")
const Balance = preload("res://scripts/core/balance.gd")
const Contract = preload("res://scripts/core/contract.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Master = preload("res://scripts/core/master.gd")
const Save = preload("res://scripts/core/save.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Trip = preload("res://scripts/core/trip.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const Wrap = preload("res://scripts/core/wrap.gd")

const DAY := 86400
const MON_1116 := 1794787200
const WED_1118 := MON_1116 + 2 * DAY

var b: Balance = Balance.load_file()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _events(s: GameState, type: String) -> Array:
	return s.take_events().filter(func(e): return e["type"] == type)


## 강화 확률 두 칸을 바꾼 숫자: success[star], destroy[star]
func _engine(changes: Array) -> Balance:
	var d := real_balance_dict()
	for c in changes:
		d["engine"]["success"][c[0]] = c[1]
		d["engine"]["destroy"][c[0]] = c[2]
	var bal: Balance = Balance.from_dict(d)
	assert(bal.is_ok(), ", ".join(bal.errors))
	return bal


## 업적 kind의 지금 값을 n으로 맞춤 (진짜 칸에)
func _reach(s: GameState, kind: String, n: int) -> void:
	match kind:
		"parcels":
			s.parcels_total = n
		"best_star", "insured_saves", "master_visits":
			s.stats[kind] = n
		"destroys":
			s.truck(0).destroy_count = n
		"setting_grade":
			s.truck(0).part("cargo_box")["grade"] = n
		"junk_triples", "junk_book":
			var cells := Stats.junk_book(b, s).slice(0, n).map(func(c): return Stats.cell(c["option"], c["grade"]))
			for c in cells:
				if kind == "junk_triples":
					s.junk_triples.append(c)
				else:
					s.junk_seen[c] = 1
		"level":
			s.driver_level = n
		"agency":
			s.company_stage = n
		"helpers":
			for k in n:
				s.trucks.append(TruckState.new())
		"contracts":
			for k in n:
				s.contracts.append(1000)
		"rank_first":
			s.rank_first_done = n > 0


## 랩핑: json 순서, 값·보상, 사기(돈·한 번만·보상용은 못 삼), 입히기(가진 것만, "" = 벗김, 없는 트럭)
func test_wraps() -> void:
	check_eq(Wrap.ids(b), ["stripe", "flame", "gold18", "bandage"], "랩핑 4개 (json 순서)")
	check_eq(Wrap.ids(b).map(func(id): return Wrap.price(b, id)), [1000000, 10000000, -1, -1], "값 (보상용 −1)")
	check_eq(Wrap.ids(b).map(func(id): return Wrap.reward_of(b, id)), ["", "", "star_18", "first_destroy"], "보상 업적")
	check_eq([Wrap.price(b, "nope"), Wrap.reward_of(b, "nope")], [-1, ""], "모르는 id")
	var s := GameState.new_game()
	s.money = 999999
	check(not Wrap.can_buy(b, s, "stripe") and not Wrap.buy(b, s, "stripe"), "1원 모자란데 삼")
	s.money = 1000000
	check(Wrap.buy(b, s, "stripe"), "딱 맞는 돈으로 못 삼")
	check_eq([s.money, s.wraps, Wrap.owned(s, "stripe")], [0, ["stripe"], true], "산 뒤 돈·가진 랩핑")
	s.money = 10 ** 9
	check(not Wrap.buy(b, s, "stripe"), "같은 랩핑을 두 번 삼")
	check(not Wrap.can_buy(b, s, "gold18") and not Wrap.buy(b, s, "gold18"), "보상용을 돈으로 삼")
	check_eq([s.money, s.wraps], [10 ** 9, ["stripe"]], "못 샀는데 상태가 바뀜")
	s.company_stage = GameState.AGENCY   # 대리점이어도 삼
	check(Wrap.buy(b, s, "flame"), "대리점에서 못 삼")
	s.trucks.append(TruckState.new())
	check_eq([Wrap.wear(s, 0, "flame"), Wrap.wear(s, 1, "stripe"), s.truck(0).wrap, s.truck(1).wrap], [true, true, "flame", "stripe"], "트럭마다 입힘")
	check_eq([Wrap.wear(s, 0, "gold18"), s.truck(0).wrap], [false, "flame"], "안 가진 랩핑은 못 입힘")
	check_eq([Wrap.wear(s, 5, "flame"), Wrap.wear(s, -1, "")], [false, false], "없는 트럭")
	check_eq([Wrap.wear(s, 0, ""), s.truck(0).wrap], [true, ""], "\"\" = 벗김")
	check_eq(TruckState.new().wrap, "", "새 트럭은 랩핑 없음")


## 업적 20개 조건마다: 목표 −1이면 안 됨, 목표면 달성 + 알림 { achievement, id, wrap }. 한 번만
func test_each_achievement() -> void:
	check_eq(Achievement.all(b).size(), 20, "업적 20개")
	var kinds := {}
	for a in Achievement.all(b):
		kinds[a["kind"]] = true
		var s := GameState.new_game()
		_reach(s, a["kind"], a["target"] - 1)
		Achievement.check(s, b)
		s.take_events()
		check(not Achievement.is_done(s, a["id"]), "%s: 목표 −1 (%d)인데 달성" % [a["id"], a["target"] - 1])
		check_eq(Achievement.progress(b, s, a["id"]), [a["target"] - 1, a["target"]], "%s: 진행" % a["id"])
		var s2 := GameState.new_game()
		_reach(s2, a["kind"], a["target"])
		Achievement.check(s2, b)
		var mine := _events(s2, "achievement").filter(func(e): return e["id"] == a["id"])
		check_eq(mine, [{ "type": "achievement", "id": a["id"], "wrap": Wrap.for_achievement(b, a["id"]) }], "%s: 목표에서 알림" % a["id"])
		check(Achievement.is_done(s2, a["id"]), "%s: 목표인데 달성 안 함" % a["id"])
		Achievement.check(s2, b)
		check_eq(_events(s2, "achievement").size(), 0, "%s: 두 번째 check에 또 알림" % a["id"])
	check_eq(kinds.size(), Balance.ACHIEVEMENT_KINDS.size(), "kind 13개 다 씀")
	check_eq(Achievement.progress(b, GameState.new_game(), "nope"), [0, 0], "모르는 id 진행")


## 랩핑 보상: +18 → gold18, 첫 퍼짐 → bandage (가진 랩핑에 들어가고 입을 수 있음). 이미 가졌으면 겹치지 않음. 나머지 업적은 보상 없음
func test_wrap_rewards() -> void:
	var s := GameState.new_game()
	s.stats["best_star"] = 18
	s.truck(0).destroy_count = 1
	Achievement.check(s, b)
	var ev := _events(s, "achievement")
	var with_wrap := ev.filter(func(e): return e["wrap"] != "")
	check_eq(with_wrap.map(func(e): return [e["id"], e["wrap"]]), [["star_18", "gold18"], ["first_destroy", "bandage"]], "보상 랩핑 알림")
	check_eq(ev.map(func(e): return e["id"]), ["star_10", "star_15", "star_18", "first_destroy"], "달성 순서 = json 순서")
	check_eq(s.wraps, ["gold18", "bandage"], "보상 랩핑을 가짐")
	check(Wrap.wear(s, 0, "gold18"), "받은 랩핑을 못 입힘")
	var t := GameState.new_game()
	t.wraps = ["bandage"]
	t.truck(0).destroy_count = 1
	Achievement.check(t, b)
	check_eq(t.wraps, ["bandage"], "이미 가진 보상 랩핑은 겹치지 않음")


## 통계 세기 (계산 코드 안): 배송·번 돈·팁 (Trip), 꺼둔 동안·기업 계약 번 돈, 강화 시도·성공·실패·퍼짐·최고 단계·보험 (Enhance),
## 세팅 돌린 수 (Setting), 명장 방문 (Master), 켜 둔 시간 (tick)
func test_stats_counting() -> void:
	var s := GameState.new_game()
	check_eq(Stats.get_all(s), { "parcels": 0, "money_earned": 0, "seconds_on": 0.0, "best_star": 0, "tries": 0, "successes": 0, "fails": 0,
			"destroys": 0, "insured_saves": 0, "setting_rolls": 0, "tips": 0, "master_visits": 0 }, "새 게임 통계 12개")
	# 배송·번 돈·팁: 1시간 (보조 트럭 몫·세금 없는 개인 기사라 번 돈 = 내 돈)
	var events := Trip.advance(s, b, 0, 3600.0, _rng(5))
	var gross := 0
	var tips := 0
	for e in events:
		if e["type"] == "parcel" or e["type"] == "tip":
			gross += e["gross"]
		if e["type"] == "tip":
			tips += 1
	var st := Stats.get_all(s)
	check_eq([st["parcels"], st["money_earned"], st["tips"]], [s.parcels_total, gross, tips], "배송 수·번 돈(배송 + 팁)·팁 수")
	check(tips > 0 and st["parcels"] > 400, "1시간에 팁 %d번, 배송 %d건" % [tips, st["parcels"]])
	# 꺼둔 동안 번 돈 (직원 몫·세금 떼기 전): 대리점 + 보조 트럭
	var o := GameState.new_game()
	o.company_stage = GameState.AGENCY
	o.trucks.append(TruckState.new())
	o.contracts = [100000]
	var r := Trip.apply_offline(o, b, 3 * 3600.0)
	check_eq(Stats.get_all(o)["money_earned"], r["money"] + r["staff"] + r["tax"], "꺼둔 동안 번 돈 = 내 돈 + 직원 몫 + 세금")
	check(r["contract"] > 0, "꺼둔 동안 계약 수입 0")
	var before: int = Stats.get_all(o)["money_earned"]
	Contract.tick(o, b, 3600.0)
	check_eq(Stats.get_all(o)["money_earned"] - before, 100000, "켜 둔 1시간 계약 = 10만")
	# 강화: +17 → +18 성공, +18 퍼짐 (스페어로 +15), 보험이 막은 퍼짐
	var be := _engine([[17, 1.0, 0.0], [18, 0.0, 1.0]])
	var e := GameState.new_game()
	e.money = 10 ** 15
	e.spares = 1
	e.truck(0).star = 17
	check_eq(Enhance.try_enhance(e, be, 0, _rng(1))["result"], Enhance.Result.SUCCESS, "+17 성공")
	check_eq(Enhance.try_enhance(e, be, 0, _rng(1))["result"], Enhance.Result.DESTROY, "+18 퍼짐")
	e.visitor_today = "insurer"
	e.visitor_day = 7
	e.insured_day = 7
	e.truck(0).star = 18
	check(Enhance.try_enhance(e, be, 0, _rng(1))["insured"], "보험이 퍼짐을 안 막음")
	e.truck(0).star = 15
	var es := Stats.get_all(e)
	check_eq([es["tries"], es["successes"], es["fails"], es["destroys"], es["best_star"], es["insured_saves"]], [3, 1, 1, 1, 18, 1],
			"강화 시도 3 = 성공 1 + 실패 1(보험) + 퍼짐 1, 최고 +18 (지금 +15), 보험이 막은 퍼짐 1")
	# 세팅 돌린 수
	e.visitor_today = ""
	for k in 3:
		Setting.try_roll(e, b, 0, "cargo_box", _rng(k))
		Setting.choose(e, 0, "cargo_box", false)
	check_eq(Stats.get_all(e)["setting_rolls"], 3, "세팅 돌린 수")
	# 명장 방문: 방문일 처음 tick마다 1 (같은 날 두 번 안 셈), 다음 주 방문 2
	var m := GameState.new_game()
	m.truck(0).star = 10
	Master.tick(m, b, MON_1116 + 60, _rng(8))
	Master.set_day(m, 2, MON_1116 + 60)
	Master.tick(m, b, WED_1118 + 1800, _rng(8))
	Master.tick(m, b, WED_1118 + 7200, _rng(8))
	check_eq(Stats.get_all(m)["master_visits"], 1, "명장 방문 1 (같은 날 두 번 안 셈)")
	Master.tick(m, b, WED_1118 + 7 * DAY + 60, _rng(8))
	check_eq(Stats.get_all(m)["master_visits"], 2, "다음 주 방문 2")
	# 켜 둔 시간
	Stats.tick(m, 0.25)
	Stats.tick(m, 0.5)
	Stats.tick(m, -1.0)
	check_eq(Stats.get_all(m)["seconds_on"], 0.75, "켜 둔 시간 (음수 dt는 안 셈)")
	note("1시간: 배송 %d, 번 돈 %d, 팁 %d / 꺼둔 3시간 번 돈 %d" % [st["parcels"], st["money_earned"], st["tips"], r["money"] + r["staff"] + r["tax"]])


## 잡옵 도감: 25칸 모양, 세팅 결과에 나온 순간(고르기 전) 본 횟수 + 줄 수, 같은 잡옵 3줄이면 별. 채운 칸 수
func test_junk_book() -> void:
	var s := GameState.new_game()
	var book := Stats.junk_book(b, s)
	check_eq(book.size(), 25, "25칸")
	check_eq(book[0], { "option": "junk_ride", "grade": 0, "seen": 0, "triple": false }, "첫 칸 (json 순서 첫 잡옵, 순정)")
	check_eq([book[24]["option"], book[24]["grade"]], ["junk_gloss", 4], "마지막 칸")
	Stats.see_lines(b, s, 1, ["junk_scent", "speed"])
	Stats.see_lines(b, s, 2, ["junk_radio", "junk_radio", "junk_radio"])
	Stats.see_lines(b, s, 2, ["junk_radio", "junk_radio", "cargo"])
	check_eq(s.junk_seen, { "junk_scent/1": 1, "junk_radio/2": 5 }, "본 횟수 = 나온 줄 수 (잡옵만)")
	check_eq(s.junk_triples, ["junk_radio/2"], "3줄 → 별 (2줄은 아님, 한 번만)")
	check_eq(Stats.junk_book_count(s), 2, "채운 칸 2")
	var cell: Dictionary = Stats.junk_book(b, s).filter(func(c): return c["option"] == "junk_radio" and c["grade"] == 2)[0]
	check_eq([cell["seen"], cell["triple"]], [5, true], "도감 칸: 본 횟수·별")
	# 진짜 돌리기: 적재함 옵션을 junk_cupholder만 남기고 레이싱(3줄)에서 → 고르기 전에 칸이 참, 예전 것을 골라도 그대로
	var d := real_balance_dict()
	for op in d["setting"]["options"]:
		if op != "junk_cupholder":
			d["setting"]["options"][op]["weight"] = 0
	var bj: Balance = Balance.from_dict(d)
	check(bj.is_ok(), "잡옵 하나만 남긴 숫자: %s" % ", ".join(bj.errors))
	var r := GameState.new_game()
	r.money = 10 ** 12
	r.truck(0).part("cargo_box")["grade"] = 3
	check(Setting.try_roll(r, bj, 0, "cargo_box", _rng(2))["ok"], "돌리기 실패")
	var g: int = r.truck(0).part("cargo_box")["pending"]["grade"]
	var key := Stats.cell("junk_cupholder", g)
	check_eq([r.junk_seen, r.junk_triples], [{ key: 3 }, [key]], "결과 3줄 junk_cupholder → 본 3, 별 (고르기 전)")
	Setting.choose(r, 0, "cargo_box", false)
	check_eq(Stats.junk_book_count(r), 1, "예전 것을 골라도 칸은 그대로")
	# 업적: 별 1개 → junk_triple, 15칸 → junk_book_15
	Achievement.check(r, b)
	check(Achievement.is_done(r, "junk_triple"), "3줄 업적 안 됨")


## 진짜 흐름 끝까지: 첫 배송 → check → first_parcel 알림, 옛 저장의 지난 기록으로 첫 프레임에 한꺼번에 달성
func test_flow_and_old_progress() -> void:
	var s := GameState.new_game()
	Achievement.check(s, b)
	check_eq(_events(s, "achievement").size(), 0, "새 게임: 업적 없음")
	Trip.advance(s, b, 0, 30.0, _rng(1))
	s.take_events()
	Achievement.check(s, b)
	check_eq(_events(s, "achievement").map(func(e): return e["id"]), ["first_parcel"], "첫 배송 뒤 check → first_parcel")
	var old := GameState.new_game()
	old.parcels_total = 20000
	old.truck(0).star = 20
	old.driver_level = 50
	Achievement.check(old, b)
	check_eq(_events(old, "achievement").map(func(e): return e["id"]),
			["first_parcel", "parcels_10k", "star_10", "star_15", "star_18", "star_20", "level_max"], "지난 기록으로 한꺼번에")
	check_eq(old.wraps, ["gold18"], "+20 트럭: +18 랩핑")


## 숫자 검사: 랩핑·업적 목록
func test_validation() -> void:
	var cases := [
		[func(d): d["wraps"].append({ "id": "stripe", "price": 5 }), "wraps[4].id = stripe"],
		[func(d): d["wraps"][0]["achievement"] = "star_18", "wraps[0]: price(구매용)와 achievement(보상용) 중 하나만"],
		[func(d): d["wraps"][1].erase("price"), "wraps[1]: price(구매용)와 achievement(보상용) 중 하나만"],
		[func(d): d["wraps"][2]["achievement"] = "star_99", "wraps[2].achievement = star_99"],
		[func(d): d["wraps"][0]["price"] = -1, "wraps[0].price = -1"],
		[func(d): d["achievements"][1]["id"] = "first_parcel", "achievements[1].id = first_parcel"],
		[func(d): d["achievements"][0]["kind"] = "dance", "achievements[0].kind = dance"],
		[func(d): d["achievements"][0]["target"] = 0, "achievements[0].target = 0"],
		[func(d): d.erase("wraps"), "\"wraps\" 목록이 없음"],
		[func(d): d["achievements"] = {}, "\"achievements\" 목록이 없음"],
	]
	for c in cases:
		var d := real_balance_dict()
		c[0].call(d)
		var errs: PackedStringArray = Balance.from_dict(d).errors
		check(Array(errs).any(func(e): return e.contains(c[1])), "'%s' 오류가 안 나옴: %s" % [c[1], errs])
	var empty := real_balance_dict()
	empty["wraps"] = []
	check(Balance.from_dict(empty).is_ok(), "랩핑 빈 목록은 됨")


## 저장 형식 13: 랩핑·입힌 랩핑·통계·도감·업적 왕복, 형식 12는 처음 값 (최고 단계는 첫 달성 보너스에서), 자르기·버리기, 틀린 모양은 깨진 저장
func test_save() -> void:
	var s := GameState.new_game()
	s.trucks.append(TruckState.new())
	s.wraps = ["stripe", "gold18"]
	s.truck(0).wrap = "gold18"
	s.truck(1).wrap = "stripe"
	s.stats = { "money_earned": 123456789012, "seconds_on": 3600.5, "best_star": 22, "insured_saves": 2, "tips": 7, "master_visits": 3 }
	s.junk_seen = { "junk_ride/2": 5, "junk_gloss/0": 1 }
	s.junk_triples = ["junk_ride/2"]
	s.achievements_done = ["first_parcel", "star_18"]
	var d: Dictionary = JSON.parse_string(JSON.stringify(Save.to_dict(s, 1794000000)))
	var r := Save.from_dict(d, b)
	check_eq(r["status"], Save.Status.OK, "읽힘 (%s)" % r["error"])
	var g: GameState = r["state"]
	check_eq([g.wraps, g.truck(0).wrap, g.truck(1).wrap], [["stripe", "gold18"], "gold18", "stripe"], "랩핑 왕복")
	check_eq(g.stats, s.stats, "통계 왕복")
	check_eq(typeof(g.stats["money_earned"]), TYPE_INT, "번 돈은 정수")
	check_eq([g.junk_seen, g.junk_triples, g.achievements_done], [s.junk_seen, s.junk_triples, s.achievements_done], "도감·업적 왕복")
	check_eq(Stats.get_all(g), Stats.get_all(s), "통계 12개 왕복")
	# 형식 12: 새 칸 없음
	var d12 := d.duplicate(true)
	d12["version"] = 12
	for key in ["wraps", "stats", "junk_seen", "junk_triples", "achievements_done"]:
		d12.erase(key)
	for td in d12["trucks"]:
		td.erase("wrap")
	d12["milestones_done"] = [10, 15, 18]
	d12["trucks"][0]["star"] = 15
	var g12: GameState = Save.from_dict(d12, b)["state"]
	check_eq([g12.wraps, g12.truck(0).wrap, g12.junk_seen, g12.junk_triples, g12.achievements_done], [[], "", {}, [], []], "형식 12: 처음 값")
	check_eq([g12.stats, Stats.get_all(g12)["best_star"]], [{ "best_star": 18 }, 18], "형식 12: 최고 단계 = 받은 보너스 +18 (지금 +15)")
	# 자르기·버리기
	var dx := d.duplicate(true)
	dx["wraps"] = ["stripe", "stripe", "nope", 3]
	dx["trucks"][0]["wrap"] = "flame"   # 안 가진 랩핑
	dx["achievements_done"] = ["first_parcel", "x", "first_parcel"]
	dx["junk_seen"] = { "junk_ride/9": 3, "speed/1": 2, "junk_scent/1": 2.7, "junk_radio/0": 0 }
	dx["junk_triples"] = ["junk_ride/2", "speed/0", 5]
	dx["stats"] = { "tips": -5, "best_star": 99, "seconds_on": -1, "dance": 3 }
	var gx: GameState = Save.from_dict(dx, b)["state"]
	check_eq([gx.wraps, gx.truck(0).wrap, gx.truck(1).wrap, gx.achievements_done], [["stripe"], "", "stripe", ["first_parcel"]], "랩핑·업적: 모르는 것·겹친 것 버림, 안 가진 랩핑은 벗김")
	check_eq([gx.junk_seen, gx.junk_triples], [{ "junk_scent/1": 2 }, ["junk_ride/2"]], "도감: 모르는 칸 버림, 2.7 → 2, 0 버림")
	check_eq(gx.stats, { "tips": 0, "best_star": 30, "seconds_on": 0.0 }, "통계: 음수 → 0, 99 → +30, 모르는 칸 버림")
	for bad in [["wraps", "x"], ["stats", []], ["stats", { "tips": "x" }], ["junk_seen", []], ["junk_seen", { "junk_ride/1": "x" }],
			["junk_triples", {}], ["achievements_done", 1]]:
		var db := d.duplicate(true)
		db[bad[0]] = bad[1]
		check_eq(Save.from_dict(db, b)["status"], Save.Status.BROKEN, "%s = %s 를 못 걸러냄" % bad)
	var dw := d.duplicate(true)
	dw["trucks"][0]["wrap"] = 3
	check_eq(Save.from_dict(dw, b)["status"], Save.Status.BROKEN, "trucks[0].wrap = 3 을 못 걸러냄")
