## 연출용 숫자 모음 (크기, 시간, 색, 속도).
## 게임 숫자(확률, 가격, 수익)는 여기 두지 않는다 → data/balance.json
## 여기 숫자는 바꿔도 돈 계산에는 영향이 없다.
extends RefCounted

# --- 트럭 그림 (트럭 자기 좌표. 동네에서는 TOWN_TRUCK_SCALE 배, 동네를 확대하면 같이 커짐) ---
const TRUCK_SIZE := Vector2(44, 22)
const WHEEL_RADIUS := 4.5

# --- 트럭 속도 (눈에 보이는 연출일 뿐. 시간당 수익과 무관) ---
const TRIP_SPEEDUP_PER_STAR := 0.95  ## 1강마다 달리는 시간에 곱하는 수 (작을수록 빨라짐)

# --- "+금액" 떠오르기 (작은 화면 기준. 전체 화면에서는 동네 글자 배수만큼 커짐) ---
const PAYOUT_RISE := 24.0        ## 위로 올라가는 거리 (픽셀)
const PAYOUT_DURATION := 1.2     ## 사라지기까지 초
const PAYOUT_FONT_SIZE := 13

# --- 투명 창 (5단계) ---
const CLICK_REGION_INTERVAL := 1.0 / 30.0  ## 클릭 받는 영역(=보이는 영역)을 몇 초마다 고치나
const WINDOW_RECHECK_SECONDS := 2.0        ## 작업표시줄 위치·화면 크기가 바뀌었나 몇 초마다 보나
const TEXT_OUTLINE_SIZE := 4               ## 바탕화면 위에서도 글자가 읽히게 두르는 테두리
const COLOR_TEXT_OUTLINE := Color(0.05, 0.06, 0.08, 0.9)

# --- v1: 화면 두 개 (창 담당. 이 칸만 고친다) ---
const SMALL_SIZE := Vector2i(480, 220)        ## 작은 화면 크기 (사용자 결정 2026-11-10)
const WINDOWED_FULL_SIZE := Vector2i(1600, 900)  ## --windowed 개발용 창에서 "전체 화면" 대신 쓰는 크기

# --- 글자 크기 (작은 화면 기준) ---
const HUD_FONT_SIZE := 13        ## 구석 ★·돈
const LABEL_FONT_SIZE := 10      ## "물류센터"
const DEBUG_FONT_SIZE := 11      ## 디버그 줄 (전체 화면에서만, 높이 900 기준)

# --- 색 (임시 그림) ---
const COLOR_BG := Color(0.13, 0.15, 0.19)          ## 창 배경 (투명 창이 아닐 때)
const COLOR_TOWN_GROUND := Color(0.16, 0.20, 0.18) ## 전체 화면에서 동네 바닥
const COLOR_ROAD := Color(0.50, 0.53, 0.58)
const COLOR_ROAD_EDGE := Color(0.22, 0.24, 0.27)   ## 길 테두리 (바탕화면 위에서도 길이 보이게)
const COLOR_DEPOT := Color(0.30, 0.45, 0.70)
const COLOR_HOUSE := Color(0.75, 0.52, 0.30)
const COLOR_HOUSE_ROOF := Color(0.60, 0.25, 0.20)
const COLOR_DOOR := Color(0.36, 0.22, 0.14)
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

# --- 고장 연기 (트럭 자기 좌표) ---
const SMOKE_INTERVAL := 0.22     ## 연기 한 덩이 나오는 간격 (초)
const SMOKE_LIFE := 1.6          ## 한 덩이가 사라지기까지 (초)
const SMOKE_RISE := 34.0         ## 사라질 때까지 올라가는 거리 (픽셀)
const SMOKE_SIZE := Vector2(5.0, 12.0)  ## 처음 반지름 → 마지막 반지름
const COLOR_SMOKE := Color(0.40, 0.40, 0.43, 0.85)  ## 작은 화면에서도 보이게 진하게

# --- 차고 (v0 패널 크기. 전체 화면에서는 GARAGE_SCALE × 화면 배수로 키움) ---
const TRUCK_CLICK_PADDING := 4.0 ## 트럭 둘레 "보이는 곳" 여유 (픽셀)
const PANEL_WIDTH := 360.0
const PANEL_PADDING := 14.0
const PANEL_BORDER := 2
const PANEL_BORDER_DANGER := 4   ## 퍼질 수 있을 때 테두리 두께
const PANEL_RADIUS := 8
const PANEL_TITLE_SIZE := 20
const PANEL_TEXT_SIZE := 14
const PANEL_DANGER_SIZE := 22    ## "퍼질 확률 N%" 크게
const PANEL_SMALL_SIZE := 11     ## 맨 아래 통계
const PANEL_BUTTON_SIZE := 18
const COLOR_PANEL_BG := Color(0.10, 0.11, 0.14, 0.97)
const COLOR_PANEL_BORDER := Color(0.40, 0.44, 0.52)
const COLOR_DANGER := Color(1.0, 0.30, 0.25)
const COLOR_SUCCESS := Color(0.45, 0.95, 0.55)
const COLOR_FAIL := Color(0.62, 0.62, 0.62)

# --- 강화 연출 (시제품의 핵심. 숫자만 바꿔서 손맛 조절) ---
# 모든 연출은 진짜 시간 기준 (F2 배속을 켜도 같은 빠르기)
# 픽셀 숫자는 v0 패널 크기 기준. 전체 화면에서는 차고 배수(GARAGE_SCALE × 화면 배수)를 곱한다.
# 엔진 떨림은 트럭 자기 좌표라 트럭이 커지면 같이 커진다.
const SUSPENSE_SAFE := 0.4            ## 결과 나오기 전 뜸: 퍼짐 확률 0인 강수 (초)
const SUSPENSE_DANGER := 1.0          ## 결과 나오기 전 뜸: 퍼질 수 있는 강수 (초)
const ENGINE_SHAKE_PX := 2.5          ## 퍼짐 구간 뜸 동안 트럭(엔진) 떨림 세기 (픽셀)
const ENGINE_SHAKE_GROW := 2.0        ## 떨림이 뜸 끝으로 갈수록 몇 배까지 세지나

const FLASH_DURATION := 0.35          ## 성공 번쩍임이 사라지는 시간
const FLASH_ALPHA := 0.75             ## 번쩍임 처음 밝기 (0~1)
const STAR_POP_SCALE := 1.7           ## 성공 시 ★ 숫자가 커지는 배수
const STAR_POP_DURATION := 0.45       ## 커졌다 돌아오는 시간
const BOOST_MULT := 3.5               ## 성공 시 트럭 순간 가속 배수
const BOOST_DURATION := 0.9           ## 가속이 원래대로 줄어드는 시간

const FAIL_SHAKE_PX := 6.0            ## 실패 시 차고 흔들림
const FAIL_SHAKE_DURATION := 0.3

const DESTROY_SHAKE_PX := 12.0        ## 퍼짐 시 화면 흔들림
const DESTROY_SHAKE_DURATION := 0.7
const DESTROY_SMOKE_BURST := 14       ## 퍼짐 순간 한 번에 나오는 연기 덩이 수
const DESTROY_TEXT_SIZE := 30         ## 빨간 "엔진 퍼짐!" 글자 크기

# --- 복귀 팝업 (작은 화면 480x220 안에 들어가는 크기) ---
const POPUP_WIDTH := 380.0
const POPUP_MAIN_SIZE := 18      ## "자리 비운 N시간 동안 +금액"
const POPUP_NOTE_SIZE := 12      ## 아래 설명 한 줄

# --- 치트 (디버그 실행일 때만) ---
const CHEAT_TIME_SCALE := 60.0   ## F2: 시간 몇 배속

# --- v1: 작은 화면 동네 (동네 담당. 이 칸과 위쪽 기존 칸을 고친다) ---
const TOWN_HOUSES := 5            ## 꼬불길 가의 집 수 (사용자 결정 2026-11-10)
const TOWN_STOP_SECONDS := 1.5    ## 집 앞에서 멈추는 초 (사용자 결정 2026-11-10)
const TOWN_DEPOT_STOP_SECONDS := 1.0  ## 물류센터에서 짐 싣느라 서 있는 초

## 0강일 때 물류센터 → 마지막 집 → 물류센터 한 바퀴를 달리는 초 (멈춘 시간 빼고).
## 강수마다 TRIP_SPEEDUP_PER_STAR 배씩 빨라지고, TOWN_DRIVE_SECONDS_MIN보다 빨라지지는 않음 (하한)
const TOWN_DRIVE_SECONDS_BASE := 32.0
const TOWN_DRIVE_SECONDS_MIN := 8.0

## 동네 설계 크기 = 작은 화면 크기. 아래 좌표는 전부 이 안 (왼쪽 위가 0,0).
## 전체 화면에서는 이 동네를 통째로 확대해서 보여준다.
const TOWN_SIZE := Vector2(480, 220)
## 꼬불길: 물류센터 앞에서 시작해 가로·세로로 꺾이는 점들 (마지막 점 = 막다른 길 끝)
const TOWN_ROAD: Array[Vector2] = [
	Vector2(62, 200), Vector2(458, 200), Vector2(458, 134),
	Vector2(38, 134), Vector2(38, 68), Vector2(446, 68),
]
const TOWN_ROAD_CORNER := 22.0    ## 모서리 둥글게 깎는 반지름
const TOWN_ROAD_WIDTH := 9.0
## 집 자리: 길 가운데 선 위의 점 (트럭이 서는 곳). 집은 그 뒤(위)에 선다. 물류센터에서 가까운 순서
const TOWN_HOUSE_SPOTS: Array[Vector2] = [
	Vector2(200, 200), Vector2(360, 200), Vector2(250, 134), Vector2(240, 68), Vector2(430, 68),
]
const TOWN_HOUSE_SIZE := Vector2(30, 22)   ## 벽
const TOWN_ROOF_HEIGHT := 12.0
const TOWN_ROOF_OVERHANG := 3.0
const TOWN_DEPOT_RECT := Rect2(8, 150, 58, 46)
const TOWN_TRUCK_SCALE := 0.6     ## 트럭 그림(TRUCK_SIZE) 배수
const TOWN_TRUCK_LIFT := 3.0      ## 바퀴 바닥이 길 가운데 선보다 얼마나 아래 (길 위에 올라탄 느낌)
const TOWN_HUD_POS := Vector2(8, 4)   ## 구석 ★·돈

# --- v1: 전체 화면 (동네 담당) ---
const FULL_REF_SIZE := Vector2(1600, 900)  ## 글자·간격은 이 창 크기 기준. 창이 크면 비례해서 키움 (높이·폭 중 덜 큰 쪽)
const FULL_UI_SCALE_MIN := 0.75
const FULL_UI_SCALE_MAX := 2.0
const FULL_MARGIN := 28.0         ## 창 가장자리·동네·차고 사이 간격 (높이 900 기준)
const GARAGE_SCALE := 1.5         ## 전체 화면 차고 = v0 패널의 몇 배 (높이 900 기준)
const SETTINGS_WIDTH := 300.0     ## [설정] 화면 폭 (v0 패널 크기 기준, 차고와 같은 배수로 키움)
const FULL_TOWN_TEXT_MAX := 2.5   ## 동네를 확대해도 동네 글자(★·돈·+금액)는 이 배수(× 화면 배수)까지만


## 지금 강수에서 한 바퀴(물류센터 → 마지막 집 → 물류센터) 달리는 초 (멈춘 시간 빼고)
static func town_drive_seconds(star: int) -> float:
	return maxf(TOWN_DRIVE_SECONDS_MIN, TOWN_DRIVE_SECONDS_BASE * pow(TRIP_SPEEDUP_PER_STAR, star))
