## 테스트 파일들이 같이 쓰는 확인 도구.
extends RefCounted

var failures := PackedStringArray()
var notes := PackedStringArray()   ## 통과/실패와 별개로 보여줄 참고 숫자
var check_count := 0


func check(ok: bool, what: String) -> void:
	check_count += 1
	if not ok:
		failures.append(what)


func check_eq(actual, expected, what: String) -> void:
	check(actual == expected, "%s: 기대 %s, 실제 %s" % [what, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, what: String) -> void:
	check(absf(actual - expected) <= tolerance,
			"%s: 기대 %s (±%s), 실제 %s" % [what, expected, tolerance, actual])


func note(text: String) -> void:
	notes.append(text)


## 진짜 data/balance.json 내용을 Dictionary로 (일부러 틀린 숫자를 넣어볼 때 씀)
func real_balance_dict() -> Dictionary:
	var f := FileAccess.open("res://data/balance.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
