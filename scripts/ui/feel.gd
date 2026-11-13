## 연출용 숫자 모음 (크기, 시간, 색, 속도).
## 게임 숫자(확률, 가격, 수익)는 여기 두지 않는다 → data/balance.json
## 여기 숫자는 바꿔도 돈 계산에는 영향이 없다.
extends RefCounted

# --- 트럭 그림 (트럭 자기 좌표. 동네에서는 TOWN_TRUCK_SCALE 배, 동네를 확대하면 같이 커짐) ---
const TRUCK_SIZE := Vector2(44, 22)
const WHEEL_RADIUS := 4.5

# --- 트럭 불꽃 (강화 성공 순간, 오버부스트 걸린 바퀴 동안. 트럭 자기 좌표) ---
const FLAME_LENGTH := 16.0        ## 짐칸 뒤로 뻗는 불꽃 길이
const FLAME_WIDTH := 7.0
const FLAME_FLICKER_MIN := 0.8    ## 깜빡일 때 길이 배수 (가장 짧을 때)
const FLAME_FLICKER_MAX := 1.1    ## 깜빡일 때 길이 배수 (가장 길 때. 보이는 곳 여유도 이걸로)
const FLAME_Y := 0.7              ## 불꽃 높이 (짐칸 위에서부터 짐칸 높이의 몇 배)
const FLAME_CORE_LENGTH := 0.55   ## 안쪽 밝은 불꽃 길이 (바깥 불꽃의 몇 배)
const FLAME_CORE_WIDTH := 0.5     ## 안쪽 밝은 불꽃 굵기 (바깥 불꽃의 몇 배)
const COLOR_FLAME := Color(1.0, 0.55, 0.15, 0.9)
const COLOR_FLAME_CORE := Color(1.0, 0.92, 0.45, 0.95)

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
const BIG_WINDOW_SIZE := Vector2i(1600, 900)      ## 큰 화면 "창 모드"의 처음 크기 (사용자 결정 2026-11-10)
const BIG_WINDOW_MIN_SIZE := Vector2i(1280, 720)  ## 큰 화면 "창 모드"에서 이보다 작게 못 줄임 (사용자 결정 2026-11-10)
const WINDOWED_FULL_SIZE := BIG_WINDOW_SIZE       ## --windowed 개발용 창에서 큰 화면 대신 쓰는 크기
const TRAY_ICON_SIZE := 32                    ## 알림 영역 아이콘 그림 크기 (픽셀. Windows가 알아서 줄여 그림)
const TRAY_MENU_DELAY := 0.3                  ## 아이콘 오른쪽 클릭 뒤 메뉴를 띄우기까지 초 (버튼을 뗀 뒤에 뜨게)

# --- 글자 크기 (작은 화면 기준) ---
const HUD_FONT_SIZE := 13        ## 구석 "+N"·돈
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
const COLOR_WHEEL := Color(0.10, 0.10, 0.10)
const COLOR_TEXT := Color(0.95, 0.95, 0.95)
const COLOR_STAR := Color(1.0, 0.85, 0.30)
const COLOR_PAYOUT := Color(0.55, 0.95, 0.55)
const COLOR_DIM := Color(0.65, 0.68, 0.72)
const COLOR_DEBUG := Color(0.60, 0.80, 1.00)
const COLOR_ERROR := Color(1.0, 0.45, 0.45)

# --- 퍼짐 연기 (트럭 자기 좌표) ---
const SMOKE_LIFE := 1.6          ## 한 덩이가 사라지기까지 (초)
const SMOKE_RISE := 34.0         ## 사라질 때까지 올라가는 거리 (픽셀)
const SMOKE_SIZE := Vector2(5.0, 12.0)  ## 처음 반지름 → 마지막 반지름
const COLOR_SMOKE := Color(0.40, 0.40, 0.43, 0.85)  ## 작은 화면에서도 보이게 진하게

# --- 차고 (v0 패널 크기. 전체 화면에서는 GARAGE_SCALE × 화면 배수로 키움) ---
const TRUCK_CLICK_PADDING := 4.0 ## 트럭 둘레 "보이는 곳" 여유 (픽셀)
const PANEL_WIDTH := 360.0
const PANEL_PADDING := 14.0
const PANEL_GAP := 8.0           ## 차고 줄 사이 간격
const PANEL_GAP_SMALL := 6.0     ## 칸 안 줄 사이·[엔진 강화] [세팅] 칸 버튼 사이·부품 버튼 사이 간격
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
const STAR_POP_SCALE := 1.7           ## 성공 시 "+N" 숫자가 커지는 배수
const STAR_POP_DURATION := 0.45       ## 커졌다 돌아오는 시간
const POP_PIVOT_LEFT := Vector2(0.0, 0.5)  ## 차고 글자가 커질 때 기준점: 왼쪽 끝 (패널 밖으로 안 삐져나감)
const BOOST_DURATION := 0.9           ## 성공 시 트럭 뒤 불꽃이 나오는 시간

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
const TOWN_HOUSES := 5            ## 꼬불길 가의 집 수 (사용자 결정 2026-11-10). 배송 N건은 이 집들에 나눠 대응
## 화면 트럭은 계산 쪽 한 바퀴 진행을 따라 물류센터 → 마지막 집 → 물류센터를 돈다 (짐 싣는 동안은 물류센터).
## 그래서 강화·세팅으로 빨라지면 같이 빨라지고, 한 바퀴를 이 초보다 빨리 돌지는 않는다 (= 화면 트럭 속도 상한)
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
const TOWN_HUD_POS := Vector2(8, 4)   ## 구석 "+N"·돈

# --- v1: 전체 화면 (동네 담당) ---
const FULL_REF_SIZE := Vector2(1600, 900)  ## 글자·간격은 이 창 크기 기준. 창이 크면 비례해서 키움 (높이·폭 중 덜 큰 쪽)
const FULL_UI_SCALE_MIN := 0.75
const FULL_UI_SCALE_MAX := 2.0
const FULL_MARGIN := 28.0         ## 창 가장자리·동네·차고 사이 간격 (높이 900 기준)
const GARAGE_SCALE := 1.5         ## 전체 화면 차고 = v0 패널의 몇 배 (높이 900 기준)
const SETTINGS_WIDTH := 300.0     ## [설정] 화면 폭 (v0 패널 크기 기준, 차고와 같은 배수로 키움)
const FULL_TOWN_TEXT_MAX := 2.5   ## 동네를 확대해도 동네 글자("+N"·돈·+금액)는 이 배수(× 화면 배수)까지만


# --- v3: 스페어 엔진 ---
const SPARE_FONT_SIZE := 15       ## 배송 중 스페어 엔진을 받았을 때 "스페어 엔진 +1" 글자 (작은 화면 기준)
const SPARE_RISE := 34.0
const SPARE_DURATION := 2.2
const COLOR_SPARE := Color(1.0, 0.80, 0.15)
const BOOST_FONT_SIZE := 15       ## 오버부스트가 걸린 바퀴를 출발할 때 "오버부스트!" 글자
const BOOST_RISE := 30.0
const BOOST_DURATION_TEXT := 1.6

# --- v4: 세팅 돌리기 (차고 [세팅] 칸. 크기는 v0 패널 기준) ---
## 등급 색: 순정 회색 / 스트리트 초록 / 스포츠 파랑 / 레이싱 보라 / 프로토타입 금색
const SETTING_GRADE_COLORS: Array[Color] = [
	Color(0.70, 0.72, 0.76), Color(0.45, 0.85, 0.45), Color(0.35, 0.62, 1.00), Color(0.74, 0.45, 1.00), Color(1.00, 0.78, 0.20),
]
const COLOR_SETTING_JUNK := Color(0.52, 0.54, 0.58)   ## 잡옵 줄 (효과 없음)
const COLOR_SETTING_NEW := Color(0.55, 0.95, 0.55)    ## "새로 나온 것" 칸 제목
const SETTING_TAB_SIZE := 16          ## [엔진 강화] [세팅] 칸 글자
const SETTING_LINE_SIZE := 14         ## 옵션 한 줄
const SETTING_SUSPENSE := 0.35        ## 돌리기 결과 나오기 전 뜸 (초, 진짜 시간)
const SETTING_FLASH_ALPHA := 0.45     ## 등급업 번쩍임 처음 밝기 (등급 색)
const SETTING_FLASH_DURATION := 0.5
const SETTING_COLUMN_GAP := 10        ## 고르는 화면 두 칸 사이

# --- v5: 기사 레벨·다음 할 일·물류센터 ---
const TOWN_QUEST_POS := Vector2(8, 22)   ## 작은 화면 "다음 할 일" 한 줄 왼쪽 위 (구석 "+N"·돈 아래)
const QUEST_FONT_SIZE := 10              ## 그 줄 글자 (작은 화면 기준)
const COLOR_LEVEL := Color(0.55, 0.80, 1.0)   ## "Lv.N"
const COLOR_QUEST := Color(0.85, 0.88, 0.92)  ## "다음 할 일" 줄
## 알림 (할 일 끝·레벨업·만렙·강화 첫 달성): 동네 오른쪽 위에 작게, 하나씩 차례로 (기획서: 방해되지 않게)
const NOTICE_RIGHT_TOP := Vector2(472, 4)     ## 알림 오른쪽 위 끝 (동네 설계 좌표. 오른쪽에 맞춤)
const NOTICE_FONT_SIZE := 11
const NOTICE_SECONDS := 2.5       ## 알림 하나가 떠 있는 시간 (진짜 시간)
const NOTICE_FADE := 0.25         ## 나타나기·사라지기 시간
const NOTICE_BUSY_QUEUE := 3      ## 밀린 알림이 이만큼 넘으면 (예전 저장으로 켜서 할 일이 줄줄이 끝날 때) …
const NOTICE_SECONDS_BUSY := 0.8  ## … 하나당 이 시간만 띄움
const COLOR_NOTICE := Color(1.0, 0.85, 0.30)
## 차고 [기사·물류센터] 칸 (크기는 v0 패널 기준)
const XP_BAR_HEIGHT := 10.0
const COLOR_XP_BAR := Color(0.35, 0.62, 1.0)
const COLOR_XP_BAR_BG := Color(0.22, 0.24, 0.28)
