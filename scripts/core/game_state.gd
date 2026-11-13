## 게임 상태: 돈, 스페어 엔진, 트럭들, 기사 레벨·창고·야간팀·퀘스트 진행, 화면에 띄울 알림.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 한 바퀴·배송·꺼둔 동안은 trip.gd, 강화 굴리기는 enhance.gd, 레벨은 driver.gd, 능력치는 ability.gd, 창고·야간팀은 depot.gd,
## 퀘스트는 quest.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const GameState = preload("res://scripts/core/game_state.gd")   # new_game()의 돌려주는 모양 표시용 (자기 자신)

var money: int = 0
var spares: int = 0                  ## 들고 있는 스페어 엔진
var spare_drop_carry: float = 0.0    ## 꺼둔 동안 스페어 평균값의 소수 나머지 (0 이상 1 미만)
var trucks: Array = []               ## TruckState들. 새 게임은 1대

# --- 기사 레벨 (driver.gd) ---
var driver_level: int = 1
var driver_xp: int = 0            ## 지금 레벨에서 쌓은 경험치
var ability_points: int = 0       ## 받은 포인트 (v5에서는 쌓이기만)
var reputation: int = 0           ## 만렙 뒤 경험치
var abilities: Dictionary = {}    ## 능력치 id → 찍은 포인트 (없으면 0). ability.gd

# --- v6b: 보험 쿠폰, 주간 배송 목표 (weekly.gd), 급송 전화 (rush.gd). 전부 저장 ---
var coupons: int = 0              ## 보험 쿠폰 (주간 목표 보상. 쓰는 곳은 C2 보험)
var weekly_week: int = -1         ## 지금 진행이 어느 주 것인가 (Master.week_index). -1 = 아직 모름 → 첫 tick에서 그 주로
var weekly_parcels: int = 0       ## 이번 주 배송 수 (모든 트럭, 꺼둔 동안 포함)
var weekly_done: bool = false     ## 이번 주 보상을 받았나
var rush_enabled: bool = true     ## [설정] 급송 요청 전화 켜기/끄기
var rush_next: float = -1.0       ## 다음 벨까지 남은 초 (-1 = 아직 안 굴림 → 다음 tick에서)
var rush_ring: float = 0.0        ## 벨이 울리는 남은 초 (0 = 안 울림)
var rush_left: int = 0            ## 남은 급송 건수 (트럭 0 배송마다 −1)

# --- 물류센터 (depot.gd) ---
var warehouse_level: int = 1
var night_level: int = 1

# --- 퀘스트 (quest.gd)와 그 조건에 쓰는 기록 ---
var quest_index: int = 0          ## 지금 차례인 퀘스트 번호 (목록 길이면 다 끝남)
var parcels_total: int = 0        ## 지금까지 배송한 건수 (켜 둔 동안 + 꺼둔 동안)
var setting_rolls: int = 0        ## 세팅 돌린 횟수
var spares_bought: int = 0        ## 스페어를 산 개수
var parts_rolled: Dictionary = {} ## 부품 id → true (돌린 적 있는 부품)
var milestones_done: Array = []   ## 보너스를 이미 받은 강화 단계들

var _events: Array = []           ## 화면에 띄울 알림 (저장 안 함). add_event로 쌓고 take_events로 꺼냄


## 트럭 1대(번호 0)짜리 새 상태
static func new_game() -> GameState:
	var s := GameState.new()
	s.trucks.append(TruckState.new())
	return s


func truck(i: int) -> TruckState:
	return trucks[i]


## 스페어 엔진은 언제든 고정가로 살 수 있다
func can_buy_spare(b: Balance) -> bool:
	return money >= Economy.spare_price(b)


## 돈을 내고 스페어 +1. 돈이 모자라면 아무것도 안 하고 false.
func buy_spare(b: Balance) -> bool:
	if not can_buy_spare(b):
		return false
	money -= Economy.spare_price(b)
	spares += 1
	spares_bought += 1
	return true


## 알림 하나를 쌓는다 (driver.gd, quest.gd가 부름)
func add_event(event: Dictionary) -> void:
	_events.append(event)


## 쌓아 둔 알림을 순서대로 꺼내고 비운다. 화면이 프레임마다 부른다
##   { "type": "level_up", "level": int, "points": int } / { "type": "max_level" }
##   { "type": "quest_done", "id": String, "xp": int, "money": int } / { "type": "milestone", "star": int, "xp": int }
##   { "type": "weekly_done", "coupons": int, "xp": int } / { "type": "rush_call" } / { "type": "rush_missed" } (v6b)
func take_events() -> Array:
	var out := _events
	_events = []
	return out
