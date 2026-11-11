## 화면에 보여줄 글자 만들기 (숫자에 쉼표 등)
extends RefCounted


## 1234567.8 → "1,234,567" (소수점 아래 버림)
static func money(v: float) -> String:
	var n := int(floorf(v))
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## "+금액"용: 10원 미만은 소수 첫째 자리까지 버림 ("0.97" → "0.9"), 그 위는 money와 같음.
## 0강에서는 집 하나에 1원 안팎이라 "+0"으로만 보이지 않게.
static func payout(v: float) -> String:
	if v < 10.0:
		return "%.1f" % (floorf(v * 10.0 + 1e-6) / 10.0)
	return money(v)


## 소수점 둘째 자리까지, 필요 없는 0은 뗌: 8.0 → "8", 94.5 → "94.5", 99.75 → "99.75"
static func num(v: float) -> String:
	var x := snappedf(v, 0.01)
	if is_equal_approx(x, roundf(x)):
		return "%d" % int(roundf(x))
	return String.num(x, 2)


## 0.9975 → "99.75%", 0.05 → "5%", 0.945 → "94.5%"
static func percent(p: float) -> String:
	return "%s%%" % num(p * 100.0)


## 모자란 돈을 모으는 데 걸리는 시간 → "약 N분 뒤 가능" (1시간 넘으면 "약 N시간 M분 뒤 가능")
static func wait_text(seconds: float) -> String:
	if is_inf(seconds):
		return "버는 돈이 없어서 모을 수 없음"
	var minutes := maxi(1, ceili(seconds / 60.0))
	if minutes < 60:
		return "약 %d분 뒤 가능" % minutes
	return "약 %d시간 %d분 뒤 가능" % [minutes / 60, minutes % 60]


## 자리 비운 시간: 10800초 → "3시간", 11700초 → "3시간 15분", 900초 → "15분"
static func away(seconds: float) -> String:
	var minutes := int(floorf(absf(seconds) / 60.0))
	if minutes < 1:
		return "1분 미만"
	if minutes < 60:
		return "%d분" % minutes
	if minutes % 60 == 0:
		return "%d시간" % (minutes / 60)
	return "%d시간 %d분" % [minutes / 60, minutes % 60]


## 3725초 → "1:02:05", 65초 → "1:05"
static func duration(seconds: float) -> String:
	var total := int(floorf(maxf(seconds, 0.0)))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]
