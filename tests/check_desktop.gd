## 투명 창 클릭 통과 확인용 (tests/check_desktop.ps1 이 실행함. 진짜 창으로 혼자 실행하지 말 것)
## 진짜 투명 창으로 main을 띄우고, 확인할 점들의 화면 좌표(Windows 기준)를 찍는다.
##   PT <이름> <x> <y> <기대: game|behind|info>   (info: 통과/실패 없이 받은 창만 보여줌)
## 화면 내용(동네·차고)에 기대지 않는다. 약속인 main.visible_rects()와 창에 실제로 들어간
## 클릭 통과 다각형으로만 점을 고른다 → 동네 담당이 화면 내용을 바꿔도 그대로 돌아간다.
##   작은 화면: 보이는 사각형 가운데 = game, 어느 사각형에도 안 들어가고 다각형 밖인 창 안의 점 = behind
##   큰 화면: 창 안 아무 점 = game (창 모드면 창 밖 점 하나 = behind)
## 순서: 1 작은 화면 → PHASE1, 2 큰 화면(전체 화면) → PHASE2, 3 큰 화면(창 모드) → PHASE3, 4 다시 작은 화면 → PHASE4
## 점을 고르는 동안 게임을 멈춘다(get_tree().paused). 창 다루기(screen_mode)는 멈춰도 계속 돈다.
##
## 화면 없이(headless) 돌리면: 창 대신 다각형을 직접 만들어 점 고르기만 확인한다 (Windows에 묻는 건 없음)
##   <GODOT_CONSOLE> --headless --path <프로젝트> -s tests/check_desktop.gd
extends SceneTree

const Save = preload("res://scripts/core/save.gd")
const ScreenMode = preload("res://scripts/ui/screen_mode.gd")
const ClickRegion = preload("res://scripts/ui/click_region.gd")

const TEST_SAVE := "user://test_window_desktop.json"
const TEST_SETTINGS := "user://test_window_desktop.cfg"
const PHASE_WAIT_MS := 1500      ## PHASE 줄을 찍고 PowerShell이 Windows에 물어볼 동안 기다리는 시간
const MAX_GAME_POINTS := 10      ## 작은 화면에서 game 점 최대 개수 (큰 사각형부터)
const MAX_BEHIND_POINTS := 6     ## 작은 화면에서 behind 점 최대 개수
const BEHIND_MARGIN := 6.0       ## behind 점은 보이는 사각형에서 이만큼 떨어진 곳만
const BEHIND_SPACING := 40.0     ## behind 점끼리 이만큼 떨어지게
const GRID_STEP := 8             ## behind 후보를 찾는 격자 간격 (픽셀)

var m: Node
var screen: ScreenMode
var headless := false
var problems := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	headless = DisplayServer.get_name() == "headless"
	await process_frame
	Save.delete_file(TEST_SAVE)
	ScreenMode.settings_path = TEST_SETTINGS
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	root.add_child(m)
	for i in 90:
		await process_frame
	screen = m.screen
	paused = true   # 트럭 등 화면 내용을 세워서 좌표를 고정 (창 다루기는 계속 돎)

	await _settle()
	_small_points("작은")
	await _phase("PHASE1")

	screen.set_full_style(ScreenMode.FullStyle.FULLSCREEN)
	screen.enter_full()
	await _settle()
	_big_points("전체")
	await _phase("PHASE2")

	screen.set_full_style(ScreenMode.FullStyle.WINDOWED)
	await _settle()
	_big_points("창모드")
	await _phase("PHASE3")

	screen.set_full_style(ScreenMode.FullStyle.FULLSCREEN)
	screen.enter_small()
	await _settle()
	_small_points("다시작은")
	await _phase("PHASE4")

	paused = false
	Save.delete_file(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("점 고르기 문제 %d개" % problems)
	quit(1 if problems > 0 else 0)


func _settle() -> void:
	for i in 12:
		await process_frame


func _phase(tag: String) -> void:
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	print("WIN %s (%d,%d) %dx%d mode=%d" % [tag, root.position.x - off.x, root.position.y - off.y, root.size.x, root.size.y, screen.mode])
	print(tag)
	if headless:
		return
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < PHASE_WAIT_MS:
		await process_frame


## 작은 화면: 보이는 사각형 가운데 = game, 빈 곳 = behind
func _small_points(prefix: String) -> void:
	var win_rect := Rect2(Vector2.ZERO, Vector2(root.size))
	var rects: Array = m.visible_rects()
	var poly := root.mouse_passthrough_polygon
	if headless or poly.is_empty():
		poly = ClickRegion.build(rects, root.size.y)
	if poly.size() < 4:
		print("[문제] 클릭 통과 다각형이 없음 (창 전체가 클릭을 받는 상태)")
		problems += 1

	# game: 보이는 사각형(창 안으로 자른 것)의 가운데. 큰 것부터
	var clipped := []
	for r: Rect2 in rects:
		var c := r.intersection(win_rect)
		if c.size.x >= 2.0 and c.size.y >= 2.0:
			clipped.append(c)
	clipped.sort_custom(func(a: Rect2, b: Rect2): return a.get_area() > b.get_area())
	var n := 0
	for c: Rect2 in clipped.slice(0, MAX_GAME_POINTS):
		var pt := c.get_center().floor()
		if not ClickRegion.contains_even_odd(poly, pt + Vector2(0.5, 0.5)):
			print("[문제] 보이는 사각형 %s 가운데가 클릭 영역 밖" % c)
			problems += 1
			continue
		n += 1
		_pt("%s_보임%d" % [prefix, n], pt, "game")
	if n == 0:
		print("[문제] 보이는 사각형이 하나도 없음")
		problems += 1

	# behind: 어느 사각형에서도 BEHIND_MARGIN 넘게 떨어지고 다각형 밖인 점. 사각형에서 먼 것부터, 서로 떨어지게
	var cands := []
	for y in range(GRID_STEP / 2, root.size.y - 2, GRID_STEP):
		for x in range(GRID_STEP / 2, root.size.x - 2, GRID_STEP):
			var pt := Vector2(x, y)
			var d := _dist_to_rects(pt, rects)
			if d > BEHIND_MARGIN and not ClickRegion.contains_even_odd(poly, pt + Vector2(0.5, 0.5)):
				cands.append({ "pt": pt, "d": d })
	cands.sort_custom(func(a, b): return a["d"] > b["d"])
	var picked: Array[Vector2] = []
	for cnd in cands:
		if picked.size() >= MAX_BEHIND_POINTS:
			break
		var ok := true
		for q in picked:
			if q.distance_to(cnd["pt"]) < BEHIND_SPACING:
				ok = false
				break
		if ok:
			picked.append(cnd["pt"])
	for i in picked.size():
		_pt("%s_빈곳%d" % [prefix, i + 1], picked[i], "behind")
	if picked.is_empty():
		print("[문제] 창 안에 빈 곳이 없음 (작은 화면 전체가 클릭을 받음)")
		problems += 1


## 큰 화면: 창 안 아무 점 = game. 창 모드면 창 밖 한 점 = behind
func _big_points(prefix: String) -> void:
	var s := Vector2(root.size)
	var spots := { "가운데": Vector2(0.5, 0.5), "왼위": Vector2(0.1, 0.1), "오위": Vector2(0.9, 0.1),
			"왼아래": Vector2(0.1, 0.9), "오아래": Vector2(0.9, 0.9), "아래끝": Vector2(0.5, 1.0) }
	for k in spots:
		var pt: Vector2 = (s * spots[k]).floor()
		pt.y = minf(pt.y, s.y - 3.0)
		# 전체 화면의 맨 아래(작업표시줄 자리)는 게임이 앞에 있을 때만 게임 것 → 참고만
		var expect := "info" if k == "아래끝" and screen.full_style == ScreenMode.FullStyle.FULLSCREEN else "game"
		_pt("%s_%s" % [prefix, k], pt, expect)
	if screen.full_style == ScreenMode.FullStyle.WINDOWED and not headless:
		# 창 왼쪽 바깥 (테두리보다 더 바깥). 주 모니터 안일 때만
		var out := Vector2(-60, s.y / 2.0)
		var g := Vector2(root.position) + out
		var prim := Rect2(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()))
		if prim.has_point(g):
			_pt("%s_창밖" % prefix, out, "behind")


static func _dist_to_rects(pt: Vector2, rects: Array) -> float:
	var best := INF
	for r: Rect2 in rects:
		var dx := maxf(maxf(r.position.x - pt.x, 0.0), pt.x - r.end.x)
		var dy := maxf(maxf(r.position.y - pt.y, 0.0), pt.y - r.end.y)
		best = minf(best, Vector2(dx, dy).length())
	return best


func _pt(tag: String, local: Vector2, expect: String) -> void:
	var off := DisplayServer.screen_get_position(DisplayServer.get_primary_screen())
	var g := Vector2(root.position) + local - Vector2(off)
	print("PT %s %d %d %s" % [tag, int(g.x), int(g.y), expect])
