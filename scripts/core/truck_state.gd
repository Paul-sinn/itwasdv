## 트럭 1대의 상태: 강화 단계, 지금 바퀴 진행, 강화 통계, 세팅.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 한 바퀴 계산은 trip.gd, 세팅 돌리기는 setting.gd에 있다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")

var star: int = 0              ## 강화 단계 0~max_star
var lap_clock: float = 0.0     ## 지금 바퀴에서 흐른 초
var lap_delivered: int = 0     ## 지금 바퀴에서 배송 끝낸 집 수
var boost_lap: bool = false    ## 지금 바퀴에 오버부스트가 걸렸나
var lap_cargo: int = 0         ## 지금 바퀴에 실은 건수 (바퀴 출발할 때 굴림). 0 = 아직 안 굴림 → 다음 Trip.advance에서 굴림
var route: String = ""         ## 노선 스위치 (v7b): "" = 기본 (개인 기사 동네, 대리점 시내), "long" = 장거리. 다음 바퀴부터 (Trip.set_route)
var lap_route: String = ""     ## 이번 바퀴 노선 (바퀴 출발 때 route에서 정함): "" = 기본, "long". 화면·계산은 Trip.route_id로 읽음
var wrap: String = ""          ## 입힌 랩핑 id (v8a, Wrap.wear). "" = 랩핑 없음

# 통계 (강화 버튼을 눌러서 나온 결과만 센다)
var success_count: int = 0
var fail_count: int = 0
var destroy_count: int = 0

## 부품 id → { "grade": int, "lines": Array(옵션 id), "counters": Array(등급별 int), "pending": null 또는 { "grade": int, "lines": Array } }
var settings: Dictionary = {}


## 부품의 세팅 상태. 없으면 처음 상태(순정, 줄 없음, 카운터 전부 0)를 만들어 돌려줌
func part(part_id: String) -> Dictionary:
	if not settings.has(part_id):
		var counters := []
		counters.resize(Balance.SETTING_GRADES)
		counters.fill(0)
		settings[part_id] = { "grade": 0, "lines": [], "counters": counters, "pending": null }
	return settings[part_id]


## 지금 쓰는 줄 중 그 옵션인 줄마다 values[그 부품 등급]을 더한 값 (상한 적용 전). Setting.total과 같음.
## enhance.gd가 setting.gd를 불러오면 서로 불러오는 고리가 생겨서 여기에 둔다.
func option_total(b: Balance, option: String) -> float:
	if not b.setting_options.has(option):
		return 0.0
	var values: PackedFloat64Array = b.setting_options[option]["values"]
	var sum := 0.0
	for p in settings.values():
		for line in p["lines"]:
			if line == option:
				sum += values[p["grade"]]
	return sum
