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


## 3725초 → "1:02:05", 65초 → "1:05"
static func duration(seconds: float) -> String:
	var total := int(floorf(maxf(seconds, 0.0)))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]
