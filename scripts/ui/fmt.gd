## 화면에 보여줄 글자 만들기 (숫자에 쉼표 등). 말은 번역 파일(locale/strings.csv) 키로
extends RefCounted

const Prefs = preload("res://scripts/ui/prefs.gd")


## 번역 (static 함수라 Object.tr()를 못 써서)
static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))


## 돈 표기 (기획서 15.4). 단위는 번역 파일(FMT_MONEY_GROUP 자리마다 FMT_MONEY_UNITS)을 따른다
##   ko: 9999 → "9,999", 12000 → "1.2만", 340000000 → "3.4억", 1200000000000 → "1.2조"
##   en: 999 → "999", 12000 → "12K", 340000000 → "340M", 1200000000000 → "1.2T"
## 단위로 나눈 값이 100 미만이면 소수 첫째 자리까지 버림(".0"은 뗌), 100 이상이면 정수. "원"은 붙이지 않음 (번역 글에)
## v8b: 설정 숫자 표기가 "만·억"(ko) / "K·M"(en)이면 지금 언어와 상관없이 그 언어의 단위로
static func money(v: int) -> String:
	if v < 0:
		return "-" + money(-v)
	var style: String = Prefs.get_value("ui/number_style")
	var group := int(_unit_text(style, "FMT_MONEY_GROUP"))
	var units := _unit_text(style, "FMT_MONEY_UNITS").split(",")
	var i := units.size()
	while i > 0 and v < int(pow(10.0, group * i)):
		i -= 1
	if i == 0:
		return _commas(v)
	var tenths := v / int(pow(10.0, group * i - 1))   # 단위의 1/10로 나눔 (v × 10은 int 끝에서 넘칠 수 있어서)
	if tenths >= 1000:
		return _commas(tenths / 10) + units[i - 1]
	if tenths % 10 == 0:
		return "%d%s" % [tenths / 10, units[i - 1]]
	return "%d.%d%s" % [tenths / 10, tenths % 10, units[i - 1]]


## 돈 단위 번역 글: "auto"면 지금 언어, 아니면 그 언어(ko / en) 번역에서
static func _unit_text(style: String, key: String) -> String:
	if style == "auto":
		return _t(key)
	return String(TranslationServer.get_translation_object(style).get_message(key))


## 건수·경험치처럼 단위를 안 붙이는 수: 12340 → "12,340" (돈은 money: "1.2만")
static func count(n: int) -> String:
	return _commas(n)


## 1234567 → "1,234,567"
static func _commas(n: int) -> String:
	var digits := str(n)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out


## 소수점 digits 자리까지(기본 둘째), 필요 없는 0은 뗌: 8.0 → "8", 94.5 → "94.5", 99.75 → "99.75"
## 적재량 건수는 한 자리: num(21.6, 1) → "21.6", num(20.0, 1) → "20"
static func num(v: float, digits := 2) -> String:
	var x := snappedf(v, pow(10.0, -digits))
	if is_equal_approx(x, roundf(x)):
		return "%d" % int(roundf(x))
	return String.num(x, digits)


## 0.9975 → "99.75%", 0.05 → "5%", 0.945 → "94.5%"
static func percent(p: float) -> String:
	return "%s%%" % num(p * 100.0)


## 모자란 돈을 모으는 데 걸리는 시간 → "약 N분 뒤 가능" (1시간 넘으면 "약 N시간 M분 뒤 가능")
static func wait_text(seconds: float) -> String:
	if is_inf(seconds):
		return _t("FMT_WAIT_NEVER")
	var minutes := maxi(1, ceili(seconds / 60.0))
	if minutes < 60:
		return _t("FMT_WAIT_MIN") % minutes
	return _t("FMT_WAIT_HOUR_MIN") % [minutes / 60, minutes % 60]


## 자리 비운 시간: 10800초 → "3시간", 11700초 → "3시간 15분", 900초 → "15분"
static func away(seconds: float) -> String:
	var minutes := int(floorf(absf(seconds) / 60.0))
	if minutes < 1:
		return _t("FMT_AWAY_UNDER_MIN")
	if minutes < 60:
		return _t("FMT_MIN") % minutes
	if minutes % 60 == 0:
		return _t("FMT_HOUR") % (minutes / 60)
	return _t("FMT_HOUR_MIN") % [minutes / 60, minutes % 60]


## 3725초 → "1:02:05", 65초 → "1:05"
static func duration(seconds: float) -> String:
	var total := int(floorf(maxf(seconds, 0.0)))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]


## 다음 할 일 이름·설명 (번역 키 QUEST_<ID 대문자>, QUEST_<ID 대문자>_DESC. id는 balance.json quests)
static func quest_name(id: String) -> String:
	return _t("QUEST_" + id.to_upper())


static func quest_desc(id: String) -> String:
	return _t("QUEST_" + id.to_upper() + "_DESC")


## 명장 보너스 이름과 효과 (번역 키 MASTER_BONUS_<ID>, 수치는 balance의 master_bonuses).
## 배수(_mult)는 "1.5", 나머지(할인·감소·확률)는 "20%"
static func master_bonus(bonuses: Dictionary, id: String) -> String:
	var v: float = bonuses.get(id, 0.0)
	return _t("MASTER_BONUS_" + id.to_upper()) % (num(v) if id.ends_with("_mult") else percent(v))


## 요일 이름 (0 = 월 … 6 = 일). short면 한 글자 ("월" / "Mon")
static func day_name(day: int, short := false) -> String:
	return _t(("DAY_SHORT_%d" if short else "DAY_%d") % day)
