## economy.gd: 강화 비용, 스페어 가격, 모으는 데 걸리는 시간
extends "res://tests/test_base.gd"

const Balance = preload("res://scripts/core/balance.gd")
const Economy = preload("res://scripts/core/economy.gd")

var b: Balance = Balance.load_file()


## 지시서 C1 ⑥: 강화 비용 = round(cost_base × cost_mult ^ 단계), 정수
func test_enhance_cost_formula() -> void:
	for star in b.max_star:
		var cost = Economy.enhance_cost(b, star)
		check_eq(typeof(cost), TYPE_INT, "+%d 비용이 정수가 아님" % star)
		check_eq(cost, roundi(35000.0 * pow(1.5, star)), "+%d 비용" % star)
	# 손으로 계산한 값 (0.5는 0에서 먼 쪽으로 올림)
	check_eq(Economy.enhance_cost(b, 0), 35000, "+0 비용")
	check_eq(Economy.enhance_cost(b, 1), 52500, "+1 비용")
	check_eq(Economy.enhance_cost(b, 3), 118125, "+3 비용")
	check_eq(Economy.enhance_cost(b, 4), 177188, "+4 비용 (177187.5 → 177188)")
	check_eq(Economy.enhance_cost(b, 5), 265781, "+5 비용 (265781.25 → 265781)")
	for star in [0, 10, 17, 18, 29]:
		note("+%d 강화 비용 %d원" % [star, Economy.enhance_cost(b, star)])


func test_spare_price() -> void:
	check_eq(Economy.spare_price(b), 5000000, "스페어 (고정 금액)")
	check_eq(typeof(Economy.spare_price(b)), TYPE_INT, "스페어 가격이 정수가 아님")


func test_seconds_to_afford() -> void:
	check_eq(Economy.seconds_to_afford(100, 100, 1000.0), 0.0, "딱 맞으면 0초")
	check_eq(Economy.seconds_to_afford(100, 500, 1000.0), 0.0, "돈이 많으면 0초")
	check_near(Economy.seconds_to_afford(1000, 500, 1000.0), 1800.0, 1e-9, "500원 모자람, 시간당 1000 → 30분")
	check(is_inf(Economy.seconds_to_afford(1000, 0, 0.0)), "수익 0이면 영원히(INF)")
