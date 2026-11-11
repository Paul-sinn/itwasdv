## 연출용 숫자 모음 (크기, 시간, 색, 속도).
## 게임 숫자(확률, 가격, 수익)는 여기 두지 않는다 → data/balance.json
## 여기 숫자는 바꿔도 돈 계산에는 영향이 없다.
extends RefCounted

# --- 띠 크기 (픽셀) ---
const BAND_HEIGHT := 120.0
const GROUND_Y := 100.0          ## 띠 위쪽에서 땅까지
const DEPOT_X := 12.0            ## 물류센터 왼쪽 끝
const DEPOT_SIZE := Vector2(72, 56)
const HOUSE_MARGIN_RIGHT := 12.0 ## 집 오른쪽 여백
const HOUSE_SIZE := Vector2(48, 40)
const TRUCK_SIZE := Vector2(44, 22)
const WHEEL_RADIUS := 4.5
const TRUCK_GAP := 6.0           ## 트럭이 건물 앞에 서는 간격

# --- 트럭 속도 (눈에 보이는 연출일 뿐. 시간당 수익과 무관) ---
const TRIP_ONE_WAY_BASE := 6.0       ## 0강일 때 편도 걸리는 초
const TRIP_SPEEDUP_PER_STAR := 0.95  ## 1강마다 편도 시간에 곱하는 수 (작을수록 빨라짐)
const TRIP_ONE_WAY_MIN := 1.5        ## 아무리 강해도 편도는 이 초보다 빠르지 않음 (하한)
const STOP_AT_END := 0.4             ## 물류센터·집 앞에서 잠깐 서는 초

# --- "+금액" 떠오르기 ---
const PAYOUT_RISE := 34.0        ## 위로 올라가는 거리 (픽셀)
const PAYOUT_DURATION := 1.2     ## 사라지기까지 초
const PAYOUT_FONT_SIZE := 15

# --- 글자 크기 ---
const HUD_FONT_SIZE := 16
const LABEL_FONT_SIZE := 11
const DEBUG_FONT_SIZE := 11

# --- 색 (임시 그림) ---
const COLOR_BAND_BG := Color(0.13, 0.15, 0.19)
const COLOR_GROUND := Color(0.42, 0.45, 0.50)
const COLOR_DEPOT := Color(0.30, 0.45, 0.70)
const COLOR_HOUSE := Color(0.75, 0.52, 0.30)
const COLOR_HOUSE_ROOF := Color(0.60, 0.25, 0.20)
const COLOR_TRUCK_BOX := Color(0.92, 0.92, 0.90)
const COLOR_TRUCK_CAB := Color(0.95, 0.75, 0.20)
const COLOR_TRUCK_STOPPED := Color(0.55, 0.55, 0.55)
const COLOR_WHEEL := Color(0.10, 0.10, 0.10)
const COLOR_TEXT := Color(0.95, 0.95, 0.95)
const COLOR_STAR := Color(1.0, 0.85, 0.30)
const COLOR_PAYOUT := Color(0.55, 0.95, 0.55)
const COLOR_DIM := Color(0.65, 0.68, 0.72)
const COLOR_DEBUG := Color(0.60, 0.80, 1.00)
const COLOR_ERROR := Color(1.0, 0.45, 0.45)

# --- 치트 (디버그 실행일 때만) ---
const CHEAT_TIME_SCALE := 60.0   ## F2: 시간 몇 배속


## 지금 강수에서 편도 걸리는 초
static func one_way_seconds(star: int) -> float:
	return maxf(TRIP_ONE_WAY_MIN, TRIP_ONE_WAY_BASE * pow(TRIP_SPEEDUP_PER_STAR, star))
