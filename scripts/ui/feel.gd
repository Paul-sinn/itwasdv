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
const SETTINGS_PANEL_WIDTH := 440.0   ## v8b [설정] 세 묶음 화면 폭 (같은 기준. 요일 고르기·NPC 창은 SETTINGS_WIDTH 그대로)
const SETTINGS_ROW_GAP := 3.0          ## v8b [설정] 표 줄 사이 (1280x720에 세 묶음이 다 들어가게 촘촘히)
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

# --- v6a: 띠의 건물 (튜닝숍·물류센터·카센터) + 작은 버튼, 큰 화면 건물 화면 ---
## 건물 자리 (동네 설계 좌표). 물류센터는 TOWN_DEPOT_RECT. 튜닝숍·카센터는 가운데 길(y 134) 위에 나란히
## (맞붙어 있어서 보이는 곳 사각형 하나로 합쳐짐 → 작은 화면 사각형 수를 안 늘림)
const TOWN_TUNING_RECT := Rect2(60, 84, 64, 44)
const TOWN_CAR_CENTER_RECT := Rect2(126, 84, 64, 44)
const COLOR_TUNING := Color(0.62, 0.30, 0.55)
const COLOR_CAR_CENTER := Color(0.28, 0.56, 0.42)
const BUILDING_DOOR_SIZE := Vector2(0.35, 0.45)   ## 문 크기 (건물 폭·높이의 몇 배)
const BUILDING_DOOR_RIGHT := 0.45                 ## 문 왼쪽 끝 = 건물 오른쪽 끝에서 폭의 몇 배 안쪽
const SIGN_TOP := 4.0                ## 간판 글자 위쪽 여백 (설계 좌표)
## 마우스를 올린 건물: 둘레 빛 + 밝게 + 위에 이름표
const BUILDING_GLOW_PX := 2.0        ## 둘레 빛 두께 (설계 좌표)
const COLOR_BUILDING_GLOW := Color(1.0, 0.92, 0.55)
const BUILDING_GLOW_LIGHTEN := 0.25  ## 건물 색을 이만큼 밝게 (작은 버튼에 마우스를 올렸을 때도)
const NAME_TAG_FONT_SIZE := 12
const NAME_TAG_GAP := 2.0            ## 이름표와 건물 사이 (설계 좌표)
const COLOR_NAME_TAG := Color(1.0, 0.95, 0.75)
## 작은 버튼 [강화] (구석 "+N"·돈·Lv 줄 끝 → 튜닝숍)
const TOWN_BUTTON_FONT_SIZE := 11
const TOWN_BUTTON_PAD := Vector2(5, 1)   ## 버튼 안 여백 (좌우, 위아래)
const TOWN_BUTTON_RADIUS := 3
## 큰 화면 건물 화면 NPC (임시 사각형 얼굴. 크기는 v0 패널 기준)
const NPC_FACE_SIZE := 34.0
const NPC_FACE_COLORS := {
	"tuning": Color(0.85, 0.62, 0.45), "depot": Color(0.55, 0.70, 0.90), "car_center": Color(0.75, 0.80, 0.55),
	"office": Color(0.80, 0.70, 0.95),
	"master": Color(0.40, 0.90, 1.0), "insurer": Color(0.55, 0.85, 1.0), "magician": Color(0.74, 0.45, 1.0), "dealer": Color(0.80, 0.62, 0.35),
}

# --- v6-bal: 처음 켰을 때 말풍선 "건물을 눌러보세요" (작은 화면에서만, 건물·작은 버튼을 한 번 누를 때까지) ---
## 튜닝숍·카센터 아래, 가운데 길 밑 빈자리 (왼쪽 물류센터·오른쪽 집 사이). 꼬리는 위로 튜닝숍을 가리킴
const HINT_POS := Vector2(124, 143)        ## 말풍선 위쪽 가운데 (동네 설계 좌표)
const HINT_TAIL_TIP := Vector2(92, 130)    ## 꼬리 끝 (튜닝숍 아래 가운데)
const HINT_TAIL_HALF := 5.0                ## 꼬리 밑변 반 폭
const HINT_FONT_SIZE := 11
const HINT_PAD := Vector2(6, 2)            ## 말풍선 안 여백 (좌우, 위아래)
const HINT_RADIUS := 5
const COLOR_HINT_BG := Color(1.0, 0.96, 0.82)
const COLOR_HINT_TEXT := Color(0.15, 0.13, 0.10)

# --- v5b: 기사 능력치 (물류센터 화면 [능력치] 칸), 동네 팁, 구석 줄 포인트 점 ---
const ABILITY_RESET_ARM_SECONDS := 3.0     ## [초기화]를 한 번 누른 뒤 이 시간 안에 또 눌러야 초기화 (진짜 시간)
const ABILITY_ADD_SIZE := 16               ## [+] 버튼 글자 (v0 패널 기준)
const COLOR_TIP := Color(1.0, 0.62, 0.86)  ## 동네 "팁! +금액" ("+금액" 초록과 다르게)
const TIP_GAP := 4.0                       ## "+금액"과 "팁!" 사이 (설계 좌표)
const POINT_DOT_SIZE := 6.0                ## 구석 줄 레벨 옆 점 지름 (작은 화면 기준). 찍을 포인트가 남았다는 표시
const COLOR_POINT_DOT := Color(1.0, 0.45, 0.35)

# --- v6b: 대형·VIP·급송 "+금액", 급송 전화 말풍선, 구석 줄 "급송 N건 남음" ---
const COLOR_PAYOUT_LARGE := Color(0.45, 0.80, 1.0)   ## "대형 +금액"
const COLOR_PAYOUT_VIP := Color(0.85, 0.60, 1.0)     ## "VIP +금액"
const COLOR_PAYOUT_RUSH := Color(1.0, 0.55, 0.30)    ## "급송 +금액" (보통 배송일 때. 대형·VIP면 그 색)
## 급송 전화 아이콘 (v7-bal: 말풍선 대신. 자리·크기는 아래 v7-bal 칸 TOWN_ICON_*)
const COLOR_RUSH_BG := Color(1.0, 0.93, 0.80)        ## 남은 시간 막대 (남은 쪽)
const COLOR_RUSH_BUTTON := Color(0.90, 0.42, 0.20)   ## 전화 아이콘 바탕
const COLOR_RUSH_BAR_BG := Color(0.55, 0.25, 0.12)   ## 남은 시간 막대 (지나간 쪽)
const COLOR_RUSH_LEFT := Color(1.0, 0.65, 0.40)      ## 구석 줄 "급송 N건 남음"

# --- v6b: 명장 방문일·보험 (튜닝숍 [명장] 칸, 요일 고르기 창, 강화 칸 [보험], 띠의 튜닝숍 표시) ---
const COLOR_MASTER := Color(0.40, 0.90, 1.0)          ## 명장 글자·방문 중 튜닝숍 테두리
const COLOR_INSURED := Color(0.55, 0.85, 1.0)         ## "퍼져도 단계 유지"·"보험 덕분에 살았어요"
## 방문 중 띠의 튜닝숍 테두리 두께 (설계 좌표). 건물 가장자리를 가운데로 그려서 바깥 절반이 빛남 두께(보이는 곳) 안에 들어감
const MASTER_MARK_WIDTH := BUILDING_GLOW_PX * 2.0
const MASTER_DAY_BUTTON_SIZE := 14                    ## 요일 버튼 7개 글자 (v0 패널 크기 기준)

# --- v7a: 대리점 창업 줄, 띠의 보조 트럭 ---
const AGENCY_FOUND_ARM_SECONDS := 3.0      ## [창업]을 한 번 누른 뒤 이 시간 안에 또 눌러야 창업 (진짜 시간)
## 보조 트럭 짐칸 색 (2호차, 3호차 순. 내 트럭은 COLOR_TRUCK_BOX). 그림은 내 트럭과 같고 색만 다름
const HELPER_TRUCK_COLORS := [Color(0.45, 0.75, 0.95), Color(0.95, 0.55, 0.45)]

# --- v7a U2: 대리점 사무실 (띠의 네 번째 건물 + 큰 화면 사무실 화면), 구석 줄 "시내 N위" ---
## 사무실 자리 (동네 설계 좌표): 가운데 길(y 134)과 아래 길(y 200) 사이, 아래 길 집 두 채(x 200·360) 사이. 창업 뒤에만
const TOWN_OFFICE_RECT := Rect2(262, 146, 64, 44)
const COLOR_OFFICE := Color(0.72, 0.56, 0.22)
const COLOR_RANK := Color(1.0, 0.72, 0.45)            ## 구석 줄 "시내 N위"
const COLOR_RANK_FIRST := Color(1.0, 0.55, 0.20)      ## 순위표 내 줄이 1위일 때 (보통 내 줄은 COLOR_STAR)
const COLOR_LOCKED := Color(0.45, 0.47, 0.50)         ## 잠긴 순위표 줄 (지역·전국·세계)
const OFFICE_ROW_SIZE := 12                           ## 순위표·세율표 한 줄 글자 (v0 패널 기준. 11줄이 1280x720에 들어가게)

# --- v7-bal: 띠 오른쪽 위 아이콘 (편지봉투 = NPC가 온 날, 전화 = 급송 벨), NPC 대화 창 ---
## 오른쪽 끝부터 편지봉투 → 전화 순으로 붙여 놓음 (보이는 것만). 알림은 그 왼쪽에 오른쪽 맞춤
const TOWN_ICON_RIGHT_TOP := Vector2(472, 4)   ## 아이콘 줄 오른쪽 위 끝 (동네 설계 좌표)
const TOWN_ICON_SIZE := Vector2(24, 18)        ## 아이콘 하나 (작은 화면 기준. 큰 화면은 동네 글자 배수만큼)
const TOWN_ICON_GAP := 4.0                     ## 아이콘 사이·아이콘과 알림 사이
const TOWN_ICON_BAR := 0.14                    ## 전화 아이콘 아래 남은 시간 막대 높이 (아이콘 높이의 몇 배)
const COLOR_LETTER := Color(0.97, 0.93, 0.82)       ## 편지봉투 종이
const COLOR_LETTER_LINE := Color(0.45, 0.36, 0.25)  ## 봉투 테두리·덮개 선
const COLOR_ALERT := Color(0.92, 0.22, 0.20)        ## 느낌표 동그라미

# --- v7-bal U3: 시내 (창업 뒤 = Trip.route_id "city"). 같은 꼬불길에 작은 집·회사 건물이 촘촘히, 뒤쪽 빌딩 실루엣 ---
## 시내 집 자리를 놓는 길 구간 [길 y, 시작 x, 끝 x] (물류센터에서 가까운 순, 시작 → 끝 = 트럭이 가는 쪽).
## 집 가운데가 이 안에 옴. 물류센터·사무실·튜닝숍·카센터·모서리를 피함. 정차할 곳 수만큼 구간 길이를 이어 붙여 고르게 나눔
const CITY_SPANS := [[200.0, 84.0, 246.0], [200.0, 342.0, 425.0], [134.0, 425.0, 205.0], [68.0, 64.0, 440.0]]
## 시내 집·회사 건물의 가장 큰 크기. 정차할 곳이 많아 간격이 좁으면 폭만 (간격 − CITY_HOUSE_GAP)으로 줄임
## (적재량 옵션 없음 40곳: 간격 약 21 → 집 18, 적재량 3줄 최고 등급 66곳: 간격 약 12.7 → 9.7)
const CITY_HOUSE_SIZE := Vector2(20, 22)     ## 시내 집 (지붕 포함 바깥 크기. 동네 집보다 작게)
const CITY_HOUSE_GAP := 3.0                  ## 이웃한 집 사이 가장 좁은 틈
const CITY_ROOF_HEIGHT := 8.0
const CITY_ROOF_OVERHANG := 2.0
const CITY_COMPANY_SIZE := Vector2(18, 25)   ## 회사 건물 (지붕 없이 높은 상자 + 창문)
const CITY_COMPANY_EVERY := 3                ## 정차할 곳 세 곳마다 하나가 회사 건물 (2, 5, 8, …번째)
const CITY_WINDOW := Vector2(4, 3)           ## 회사 건물 창문 하나 (2줄씩, 위에서부터 CITY_WINDOW_GAP 간격)
const CITY_WINDOW_GAP := 3.0
const COLOR_COMPANY := Color(0.52, 0.60, 0.70)
const COLOR_COMPANY_WINDOW := Color(0.95, 0.88, 0.55)
## 뒤쪽 빌딩 실루엣 (위 길 뒤, 아래 끝 = 위 길 집 바닥). 띠에서도 그림 → 보이는 곳. 위 끝은 구석 줄·알림·아이콘(y 22까지) 아래
const CITY_SKYLINE: Array[Rect2] = [
	Rect2(0, 40, 24, 22), Rect2(24, 30, 18, 32), Rect2(42, 36, 28, 26), Rect2(70, 26, 16, 36), Rect2(86, 34, 30, 28),
	Rect2(116, 42, 20, 20), Rect2(136, 28, 22, 34), Rect2(158, 38, 26, 24), Rect2(184, 25, 18, 37), Rect2(202, 34, 30, 28),
	Rect2(232, 30, 20, 32), Rect2(252, 40, 26, 22), Rect2(278, 26, 22, 36), Rect2(300, 36, 28, 26), Rect2(328, 30, 18, 32),
	Rect2(346, 42, 24, 20), Rect2(370, 28, 26, 34), Rect2(396, 36, 20, 26), Rect2(416, 25, 22, 37), Rect2(438, 34, 24, 28),
	Rect2(462, 40, 18, 22),
]
const COLOR_CITY_SKYLINE := Color(0.20, 0.24, 0.33)
const COLOR_CITY_SKY := Color(0.33, 0.42, 0.60)      ## 큰 화면 시내 하늘 (위 끝 ~ CITY_SKY_BOTTOM)
const COLOR_CITY_GROUND := Color(0.19, 0.19, 0.22)   ## 큰 화면 시내 바닥 (동네는 COLOR_TOWN_GROUND)
const CITY_SKY_BOTTOM := 62.0
## 시내 화면 트럭 속도 상한 (TOWN_DRIVE_SECONDS_MIN 대신): 계산 쪽은 집 사이마다 같은 시간을 줘서, 집 사이가 먼 곳
## (가운데 길 끝 → 위 길 첫 집 약 260px)을 짧게 달려야 함. +30·상하차 30%면 약 0.5초 → 동네 상한(8초)으로는 늦음
const CITY_DRIVE_SECONDS_MIN := 3.0

# --- v7b U1: 장거리 노선 (Trip.route_id "long"). 트럭이 물류센터 앞에서 왼쪽 화면 밖으로 나갔다가 바퀴 끝에 돌아옴 ---
## 물류센터 앞(길 시작점, x 62)에서 왼쪽으로 이만큼 가면 트럭이 동네 밖으로 다 나감 (트럭 반 폭 약 13 + 여유)
const LONG_EXIT_PX := 80.0
## 장거리 한 바퀴를 동네 한 바퀴의 몇 배 길이로 보나 (나가고 들어오는 빠르기가 동네에서 달릴 때와 비슷하게. 계산 쪽 도로 ×5)
const LONG_VIEW_LOOPS := 5.0
## "장거리 배송 중 · N분 N초" 줄 왼쪽 위 (동네 설계 좌표): 아래 길(y 200) 밑, 트럭이 나가는 왼쪽 구석
const TOWN_LONG_POS := Vector2(8, 204)
const COLOR_LONG := Color(0.62, 0.85, 1.0)

# --- v8a: 랩핑 (차체 색·무늬만. 코드로 그리는 임시 도형. 크기는 짐칸 폭·트럭 높이의 몇 배. Truck.draw_body) ---
## 랩핑 id → [짐칸 색, 운전석 색]. 없는 id(랩핑 없음, 반창고)는 트럭 원래 짐칸 색 + COLOR_TRUCK_CAB
const WRAP_BODY := {
	"stripe": [Color(0.16, 0.32, 0.78), Color(0.16, 0.32, 0.78)],
	"flame": [Color(0.13, 0.13, 0.15), Color(0.22, 0.22, 0.25)],
	"gold18": [Color(0.95, 0.76, 0.22), Color(0.84, 0.60, 0.12)],
}
const WRAP_STRIPES := [0.30, 0.58]        ## 줄무늬 두 줄 위쪽 끝 (트럭 높이의 몇 배)
const WRAP_STRIPE_HEIGHT := 0.14
const COLOR_WRAP_STRIPE := Color(0.97, 0.97, 0.97)
const WRAP_FLAME_TOP := 0.3               ## 불꽃 혀가 시작하는 높이 (그 아래를 혀 수만큼 나눔)
const WRAP_FLAME_LENGTHS := [0.7, 0.95, 0.55]   ## 혀마다 길이 (짐칸 폭의 몇 배, 위에서부터)
const COLOR_WRAP_FLAME := Color(1.0, 0.42, 0.10)
const COLOR_WRAP_FLAME_CORE := Color(1.0, 0.85, 0.25)
const WRAP_SHINE_X := 0.15                ## 금색 반짝임 띠 아래쪽 왼쪽 끝 (짐칸 폭의 몇 배)
const WRAP_SHINE_WIDTH := 0.18
const WRAP_SHINE_LEAN := 0.2              ## 위쪽이 오른쪽으로 기우는 정도
const COLOR_WRAP_SHINE := Color(1.0, 0.95, 0.70, 0.85)
const WRAP_BANDAGE_INSET := 0.18          ## 반창고 X를 짐칸 가장자리에서 띄우는 거리 (트럭 높이의 몇 배)
const WRAP_BANDAGE_WIDTH := 0.24          ## 반창고 폭 (트럭 높이의 몇 배)
const COLOR_WRAP_BANDAGE := Color(0.93, 0.78, 0.60)
const COLOR_WRAP_BANDAGE_PAD := Color(0.99, 0.95, 0.88)
## 튜닝숍 [랩핑] 칸 카드 미리 보기 크기 (v0 패널 기준)
const WRAP_PREVIEW_SIZE := Vector2(60, 36)
const COLOR_WRAP_WORN := Color(0.55, 0.95, 0.55)   ## "입는 중"

# --- v8a: 물류센터 [기록] 칸 (통계·잡옵 도감·업적. 크기는 v0 패널 기준) ---
## [창고·할 일]·[기록] 스크롤 칸 높이: 1280x720·2200x800에서도 물류센터 화면이 창 안, [작게]·[설정]과 안 겹치게
## (330이면 1280x720에서 [작게]와 4픽셀 겹침)
const DRIVER_PAGE_HEIGHT := 320.0
const RECORD_HEAD_SIZE := 15              ## 묶음 제목 ("통계", "잡옵 도감 · N / 25칸", "업적 · N / 20")
const BOOK_CELL_HEIGHT := 20.0            ## 도감 칸 높이
const BOOK_CELL_ALPHA := 0.35             ## 본 칸 바탕 = 등급 색을 이만큼 (글자가 읽히게 옅게)
const COLOR_BOOK_EMPTY := Color(0.20, 0.22, 0.26)   ## 안 본 칸 바탕
const BOOK_STAR_SIZE := 9.0               ## 같은 잡옵 3줄이 나온 칸의 별 그림 지름
const COLOR_ACH_DONE := Color(1.0, 0.85, 0.30)
