## 세팅 돌리기: 부품(적재함·ECU)의 등급과 옵션 줄.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 등급업·옵션 뽑기 굴리기는 이 파일에만 둔다. (오버부스트 굴리기는 trip.gd)
##
## 돌리기 1번: ① 비용 ② 그 등급 천장 카운터 +1 ③ 등급업 굴림 (카운터가 천장에 닿으면 무조건) ④ 등급업이면 카운터 0
##            ⑤ 새 등급 줄 수만큼 옵션을 뽑아 pending(새 상태)에 ⑥ choose()로 예전 / 새 상태를 통째로 고름
## 등급 이름·옵션 이름은 번역 파일에 (여기서는 id만 쓴다).
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

## 돌릴 수 없는 이유. NONE이면 돌릴 수 있음.
enum Block { NONE, LOCKED, NO_MONEY, PENDING }


## 부품 id들 (json 순서. ["cargo_box", "ecu"])
static func part_ids(b: Balance) -> Array:
	return b.setting_parts.keys()


## 최고 등급 (4 = 프로토타입)
static func max_grade(b: Balance) -> int:
	return b.lines_by_grade.size() - 1


static func unlock_star(b: Balance, part: String) -> int:
	return b.setting_parts[part]["unlock_star"]


## 그 트럭의 지금 강화 단계로 이 부품이 열렸나
static func unlocked(b: Balance, t: TruckState, part: String) -> bool:
	return t.star >= unlock_star(b, part)


## 돌리기 1번 비용. 명장 "세팅 비용 할인" 보너스 중이면(s.active_bonus) round(비용 × (1 − 할인)). 화면 = 실제
static func roll_cost(b: Balance, grade: int, s: GameState) -> int:
	var cost: int = b.roll_cost[grade]
	if s.active_bonus == "setting_discount":
		cost = roundi(cost * (1.0 - b.master_bonuses["setting_discount"]))
	return cost


## 한 번 돌릴 때 등급업 확률. 최고 등급은 0. 명장 "세팅 등급업 확률 상승" 중이면 × setting_up_mult (최대 1, 천장은 그대로)
static func up_chance(b: Balance, grade: int, s: GameState) -> float:
	if grade >= max_grade(b):
		return 0.0
	var p := b.up_chance[grade]
	if s.active_bonus == "setting_up_mult":
		p = minf(1.0, p * b.master_bonuses["setting_up_mult"])
	return p


## 천장 (이 횟수째는 무조건 등급업). 최고 등급은 0
static func ceiling(b: Balance, grade: int) -> int:
	return b.ceiling[grade] if grade < max_grade(b) else 0


static func line_count(b: Balance, grade: int) -> int:
	return b.lines_by_grade[grade]


## "common" / "own" / "junk"
static func option_kind(b: Balance, option: String) -> String:
	return b.setting_options[option]["kind"]


## 그 등급에서 줄 하나의 수치 (0.05 = 5%). 잡옵은 0
static func option_value(b: Balance, option: String, grade: int) -> float:
	return b.setting_options[option]["values"][grade]


## 옵션 id → 한 줄에 뽑힐 확률 (합 1). 그 등급 수치가 0인 옵션은 빠짐, 잡옵은 늘 포함. 순서 = json 부품 옵션 순서
static func option_chances(b: Balance, part: String, grade: int) -> Dictionary:
	var weights := {}
	var sum := 0.0
	for op in b.setting_parts[part]["options"]:
		var o: Dictionary = b.setting_options[op]
		if o["kind"] == "junk" or o["values"][grade] != 0.0:
			weights[op] = o["weight"]
			sum += o["weight"]
	for op in weights:
		weights[op] = weights[op] / sum
	return weights


## 그 트럭의 지금 쓰는 줄에서 그 옵션 합 (상한 적용 전)
static func total(b: Balance, t: TruckState, option: String) -> float:
	return t.option_total(b, option)


## 트럭 i의 부품을 지금 돌릴 수 있나? 못 하면 그 이유 (잠김 → 고르는 중 → 돈 순서)
static func block_reason(state: GameState, b: Balance, i: int, part: String) -> Block:
	var t := state.truck(i)
	if not unlocked(b, t, part):
		return Block.LOCKED
	var p := t.part(part)
	if p["pending"] != null:
		return Block.PENDING
	if state.money < roll_cost(b, p["grade"], state):
		return Block.NO_MONEY
	return Block.NONE


## 돌리기 1번. 못 돌리면 { "ok": false }.
## 돌렸으면 { "ok": true, "grade_up": bool, "pity": bool(천장으로 오름) } 이고 part의 "pending"에 새 상태가 들어감
static func try_roll(state: GameState, b: Balance, i: int, part: String, rng: RandomNumberGenerator) -> Dictionary:
	if block_reason(state, b, i, part) != Block.NONE:
		return { "ok": false }
	var p := state.truck(i).part(part)
	var grade: int = p["grade"]
	state.money -= roll_cost(b, grade, state)
	var up := false
	var pity := false
	if grade < max_grade(b):   # 최고 등급은 등급업 없음 (카운터 안 셈)
		p["counters"][grade] += 1
		if p["counters"][grade] >= ceiling(b, grade):
			up = true
			pity = true
		elif Enhance.random01(rng) < up_chance(b, grade, state):
			up = true
		if up:
			p["counters"][grade] = 0
	var new_grade := grade + 1 if up else grade
	var chances := option_chances(b, part, new_grade)
	var lines := []
	for k in line_count(b, new_grade):
		lines.append(_draw(chances, rng))
	p["pending"] = { "grade": new_grade, "lines": lines }
	state.setting_rolls += 1
	state.parts_rolled[part] = true
	return { "ok": true, "grade_up": up, "pity": pity }


## 고르기: take_new면 새 상태(등급 + 줄)로, 아니면 예전 그대로. pending을 비운다. pending이 없으면 아무 일 없음.
## 카운터는 등급업 때 이미 0 (예전 것을 골라도 그대로 0)
static func choose(state: GameState, i: int, part: String, take_new: bool) -> void:
	var p := state.truck(i).part(part)
	var pending = p["pending"]
	if pending == null:
		return
	if take_new:
		p["grade"] = pending["grade"]
		p["lines"] = pending["lines"]
	p["pending"] = null


## 줄 하나 뽑기: option_chances 비율로
static func _draw(chances: Dictionary, rng: RandomNumberGenerator) -> String:
	var r := Enhance.random01(rng)
	var last := ""
	for op in chances:
		last = op
		r -= chances[op]
		if r < 0.0:
			return op
	return last   # 실수 찌꺼기로 합이 1에 조금 못 미칠 때
