## 확인 스크립트(check_*.gd)용 오류 감시: 실행 중 스크립트 오류(SCRIPT ERROR)나 엔진 오류(ERROR)가 하나라도 나면
## "[실패] 실행 중 오류 …"를 찍고 종료 코드 1로 끝낸다. 경고(push_warning)는 안 셈 (깨진 저장 파일 시험 등에서 일부러 냄).
## 왜: GDScript는 오류 난 함수만 멈추고 부른 쪽은 계속 가서, 확인이 "전부 통과"·종료 코드 0으로 끝날 수 있다
##     (v5 합칠 때 check_i18n: 복귀 창 글자 하나가 빠진 채 통과). 기다리던 코루틴이 멈춰 끝나지 않고 걸리기도 한다 (check_save).
## 쓰는 법: 확인 스크립트 _initialize() 맨 앞에서  OS.add_logger(ErrorWatch.new(self))
extends Logger

var _tree: SceneTree
var _failed := false


func _init(tree: SceneTree) -> void:
	_tree = tree


## 여러 스레드에서 불릴 수 있어서 여기서는 표시만 하고, 찍기·끝내기는 메인 스레드로 미룬다
func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING or _failed:
		return
	_failed = true
	var what := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function]
	_fail.call_deferred(what)


func _fail(what: String) -> void:
	print("[실패] 실행 중 오류가 나서 이 확인은 믿을 수 없음: " + what)
	_tree.quit(1)
