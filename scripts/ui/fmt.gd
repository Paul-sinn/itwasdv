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


## 0.9975 → "99.75%", 0.05 → "5%", 0.945 → "94.5%"
static func percent(p: float) -> String:
	var v := snappedf(p * 100.0, 0.01)
	if is_equal_approx(v, roundf(v)):
		return "%d%%" % int(roundf(v))
	return "%s%%" % String.num(v, 2)


## 모자란 돈을 모으는 데 걸리는 시간 → "약 N분 뒤 가능" (1시간 넘으면 "약 N시간 M분 뒤 가능")
static func wait_text(seconds: float) -> String:
	if is_inf(seconds):
		return "버는 돈이 없어서 모을 수 없음"
	var minutes := maxi(1, ceili(seconds / 60.0))
	if minutes < 60:
		return "약 %d분 뒤 가능" % minutes
	return "약 %d시간 %d분 뒤 가능" % [minutes / 60, minutes % 60]


## 3725초 → "1:02:05", 65초 → "1:05"
static func duration(seconds: float) -> String:
	var total := int(floorf(maxf(seconds, 0.0)))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]
