## 게임 상태: 돈, 스페어 엔진, 트럭들, 기사 레벨·창고·야간팀·퀘스트 진행, 화면에 띄울 알림.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙)
## 한 바퀴·배송·꺼둔 동안은 trip.gd, 강화 굴리기는 enhance.gd, 레벨은 driver.gd, 능력치는 ability.gd, 창고·야간팀은 depot.gd,
## 퀘스트는 quest.gd, 회사(대리점·보조 트럭·세금·순위)는 company.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")
const GameState = preload("res://scripts/core/game_state.gd")   # new_game()의 돌려주는 모양 표시용 (자기 자신)

## company_stage 값 (balance.json company.stages 순서). 2~는 업데이트용
const SOLO := 0
const AGENCY := 1

var money: int = 0
var spares: int = 0                  ## 들고 있는 스페어 엔진
var spare_drop_carry: float = 0.0    ## 꺼둔 동안 스페어 평균값의 소수 나머지 (0 이상 1 미만)
var trucks: Array = []               ## TruckState들. 새 게임은 1대. 0 = 내 트럭, 1~ = 보조 트럭 (company.gd)

# --- v7a 회사 (company.gd). 전부 저장 ---
var company_stage: int = SOLO     ## 0 개인 기사, 1 대리점
var today_day: int = -1           ## 오늘 집계가 어느 날 것인가 (현지 날짜 번호, Master.tick). -1 = 아직 모름 → 첫 tick에서 그날로
var today_sales: int = 0          ## 오늘 번 돈 (모든 트럭, 직원 몫·세금 떼기 전, 꺼둔 동안 포함)
var today_staff: int = 0          ## 오늘 직원 몫
var today_tax: int = 0            ## 오늘 세금
var rank_first_done: bool = false ## 시내 1위 알림을 보냈나 (한 번만)

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

# --- v6b 명장 방문일 (master.gd). active_bonus만 저장 안 함 ---
var active_bonus: String = ""     ## 방문 중일 때 그 주 보너스 id, 아니면 "". 저장 안 함 (Master.tick이 채움)
var master_unlocked: bool = false ## +10 첫 달성으로 열림
var master_day: int = -1          ## 이번 주에 적용되는 요일 (0 월 … 6 일). -1 = 안 고름
var master_next_day: int = -1     ## 다음 주부터 바뀔 요일. -1 = 없음
var master_week: int = -1         ## master_day를 맞춘 주 (Master.week_index). 주가 바뀌면 master_next_day를 적용
var master_bonus: String = ""     ## master_bonus_week 주의 보너스 id
var master_bonus_week: int = -1   ## master_bonus가 어느 주 것인가
var master_next_bonus: String = ""   ## 다음 주 보너스 (월요일 방문을 일요일에 예고할 때 미리 굴림). "" = 아직
var master_notice_week: int = -1  ## 예고를 보낸 방문의 주 (한 주에 한 번)
var master_visit_week: int = -1   ## 방문 알림을 보낸 주 (한 주에 한 번)

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
	return money >= b.spare_price   # = Economy.spare_price (economy.gd가 이 파일을 불러서 여기서는 안 부름)


## 돈을 내고 스페어 +1. 돈이 모자라면 아무것도 안 하고 false.
func buy_spare(b: Balance) -> bool:
	if not can_buy_spare(b):
		return false
	money -= b.spare_price
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
##   { "type": "master_unlocked" } / { "type": "master_notice", "bonus": String } / { "type": "master_visit", "bonus": String } (v6b)
##   { "type": "agency_founded" } / { "type": "helper_bought", "truck": int } / { "type": "rank_first" } (v7a)
func take_events() -> Array:
	var out := _events
	_events = []
	return out
