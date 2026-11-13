## 튜닝 부위의 화면 글자: 이름, 한 줄 설명, 효과 숫자 → 글자.
## 숫자(효과 크기·확률·비용)는 balance.json → Tune.* 에서 받아서 글자로만 바꾼다.
extends RefCounted

const Fmt = preload("res://scripts/ui/fmt.gd")

## 부위 id → 화면 이름 (순서는 Tune.PARTS)
const NAMES := {
	"turbo": "터보",
	"tire": "타이어",
	"cargo": "짐칸",
	"suspension": "서스펜션",
	"fuel_tank": "연료 탱크",
	"navigation": "내비게이션",
	"engine_oil": "엔진오일",
}

## 부위 id → 하는 일 한 줄 (docs/PROTOTYPE_V2.md 표의 "뭐냐면" + "효과"를 쉬운 말로)
const INFO := {
	"turbo": "엔진에 공기를 더 밀어 넣어 힘을 키워요. 시간당 수익이 올라요.",
	"tire": "바퀴 고무. 집에 들를 때 가끔 '대박 배송'이 나와 그 집 돈을 몇 배로 받아요.",
	"cargo": "택배 싣는 뒷부분. 대박 배송 때 몇 배로 받을지 정해요. 타이어를 올려야 대박이 나와요.",
	"suspension": "덜컹거림을 잡는 스프링(쇼바). 강화할 때 퍼질 확률이 줄어요 (줄어든 만큼은 '실패').",
	"fuel_tank": "기름통. 게임을 꺼 둔 동안 돈이 쌓이는 최대 시간이 늘어요.",
	"navigation": "길 안내 기계. 게임을 꺼 둔 동안 받는 돈의 비율이 올라요.",
	"engine_oil": "엔진 속 윤활유. 강화 비용이 싸져요 (스페어값은 그대로).",
}

const NO_JACKPOT_WARNING := "타이어를 올려야 대박이 나와요"


static func part_name(part: String) -> String:
	return NAMES.get(part, part)


static func info(part: String) -> String:
	return INFO.get(part, "")


## 효과 숫자(Tune.effect 그대로) → 짧은 글자. 예: turbo 0.1 → "수익 +10%"
## 효과가 0이면 "효과 없음" (짐칸은 배수라 0이 없음)
static func effect_text(part: String, v: float) -> String:
	if v == 0.0 and part != "cargo":
		return "효과 없음"
	match part:
		"turbo":
			return "수익 +%s" % Fmt.percent(v)
		"tire":
			return "대박 확률 %s" % Fmt.percent(v)
		"cargo":
			return "대박 ×%s" % Fmt.num(v)
		"suspension":
			return "퍼짐 −%s" % Fmt.percent(v)
		"fuel_tank":
			return "꺼둔 동안 +%s시간" % Fmt.num(v)
		"navigation":
			return "꺼둔 동안 수익 +%sp" % Fmt.percent(v)
		"engine_oil":
			return "강화 비용 −%s" % Fmt.percent(v)
	return Fmt.num(v)
