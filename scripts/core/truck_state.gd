## 트럭 1대의 상태: 강화 단계, 지금 바퀴 진행, 강화 통계.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 한 바퀴 계산은 trip.gd에 있다.
extends RefCounted

var star: int = 0              ## 강화 단계 0~max_star
var lap_clock: float = 0.0     ## 지금 바퀴에서 흐른 초
var lap_delivered: int = 0     ## 지금 바퀴에서 배송 끝낸 집 수

# 통계 (강화 버튼을 눌러서 나온 결과만 센다)
var success_count: int = 0
var fail_count: int = 0
var destroy_count: int = 0
