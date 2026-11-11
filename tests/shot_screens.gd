## 화면 사진 찍기 (눈으로 확인용). 투명 창은 안 쓰고, 화면 밖 그림판(SubViewport)에 원하는 크기로 그려서 PNG로 저장.
## 진짜 저장 파일은 건드리지 않는다 (user://test_town_shot.json 을 쓰고 끝나면 지움).
##
## 실행 (창이 잠깐 떴다가 꺼짐. 끝에 --out= 사진 폴더):
##   <GODOT> --path <프로젝트> -s tests/shot_screens.gd -- --windowed --out=<사진 폴더>
extends SceneTree

const Save = preload("res://scripts/core/save.gd")
const Enhance = preload("res://scripts/core/enhance.gd")
const Economy = preload("res://scripts/core/economy.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const DesktopWindow = preload("res://scripts/ui/desktop_window.gd")
const TEST_SAVE := "user://test_town_shot.json"
const FULL_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(3440, 1440)]

var vp: SubViewport
var m: Node
var out_dir := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("[멈춤] 화면 없는 실행(--headless)에서는 사진을 못 찍음")
		quit(1)
		return
	DesktopWindow.make_plain_window(root)   # 투명 창으로 안 띄움
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	if out_dir == "":
		print("[멈춤] --out=<사진 폴더> 가 없음")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	vp = SubViewport.new()
	vp.size = Feel.SMALL_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	Save.delete_file(TEST_SAVE)
	m = load("res://scenes/main.tscn").instantiate()
	m.save_path = TEST_SAVE
	vp.add_child(m)
	m.screen.mode_changed.connect(func(mode):
		vp.size = Feel.SMALL_SIZE if mode == 0 else FULL_SIZES[1])
	var b = m.balance

	# 1) 작은 화면: 12강, "+금액"이 떠 있을 때
	m.state.star = 12
	m.state.money = 123456.0
	await _until(func(): return m.town.payout_count() > 0, 30.0)
	await _wait(0.25)
	await _shot("small_480x220")
	await _shot_rects("small_480x220_visible")

	# 2) 작은 화면: 고장 + 연기
	Enhance.break_engine(m.state, b)
	await _wait(1.5)
	await _shot("small_broken")
	await _shot_rects("small_broken_visible")
	m.state.broken = false

	# 3) 작은 화면 위 복귀 팝업
	m.popup.open("자리 비운 7시간 59분 동안 +1,234,567원", "꺼둔 동안은 50%만, 최대 8시간치까지 쌓입니다.")
	await _wait(0.1)
	await _shot("small_popup")
	m.popup.visible = false

	# 4) 큰 화면: 퍼질 수 있는 강수 + 돈 모자람 (차고가 가장 긴 경우) + 결과 줄
	m.screen.enter_full()
	m.state.star = 18
	m.state.money = Economy.enhance_cost(b, 18)
	m.state.success_count = 31
	m.state.fail_count = 12
	m.state.destroy_count = 1
	for size in FULL_SIZES:
		vp.size = size
		m.panel.show_result("실패", Feel.COLOR_FAIL)
		await _wait(0.3)
		await _shot("full_%dx%d" % [size.x, size.y])

	# 5) 큰 화면 강화 연출 (1600x900): 성공 번쩍 / 퍼짐 (흔들림 + 연기 + 빨간 글자)
	vp.size = FULL_SIZES[1]
	m.state.money = 1e9
	m.state.star = 10
	_seed_for(Enhance.Result.SUCCESS, 10)
	m._on_enhance_pressed()
	await _wait(Feel.SUSPENSE_SAFE * 0.5)
	await _shot("full_fx_suspense")
	await _wait(Feel.SUSPENSE_SAFE * 0.5 + 0.06)
	await _shot("full_fx_success")
	await _until(func(): return not m.enhancing, 3.0)
	await _wait(1.0)
	m.state.star = 19
	_seed_for(Enhance.Result.DESTROY, 19)
	m._on_enhance_pressed()
	await _wait(Feel.SUSPENSE_DANGER * 0.7)
	await _shot("full_fx_danger_suspense")
	await _wait(Feel.SUSPENSE_DANGER * 0.3 + 0.12)
	await _shot("full_fx_destroy")
	await _wait(1.5)
	await _shot("full_broken")

	# 6) 설정 화면 (있으면)
	if m.has_method("open_settings"):
		m.open_settings()
		await _wait(0.2)
		await _shot("full_settings_1600x900")
		vp.size = FULL_SIZES[0]
		await _wait(0.2)
		await _shot("full_settings_1280x720")

	Save.delete_file(TEST_SAVE)
	print("사진 저장: ", out_dir)
	quit(0)


## 이 강수에서 다음 굴리기가 want가 나오게 m.rng 씨앗을 고른다
func _seed_for(want: int, star: int) -> void:
	var probe := RandomNumberGenerator.new()
	for s in 100000:
		probe.seed = s
		if Enhance.roll(m.balance, star, probe) == want:
			m.rng.seed = s
			return


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("  ", name, ".png  ", img.get_size())


## 투명 창처럼: 배경을 안 칠하고, 보일 곳(visible_rects) 밖은 체크무늬(바탕화면 대신)로
func _shot_rects(name: String) -> void:
	m._bg.visible = false
	vp.transparent_bg = true
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var rects: Array = m.visible_rects()
	for y in img.get_height():
		for x in img.get_width():
			var c := 0.85 if ((x / 8) + (y / 8)) % 2 == 0 else 0.7
			var desk := Color(c, c, c)
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := false
			for r: Rect2 in rects:
				if r.has_point(p):
					inside = true
					break
			var px := img.get_pixel(x, y)
			img.set_pixel(x, y, desk.lerp(Color(px.r, px.g, px.b), px.a) if inside else desk)
	img.save_png(out_dir.path_join(name + ".png"))
	print("  ", name, ".png  사각형 ", rects.size(), "개")
	vp.transparent_bg = false
	m._bg.visible = true


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _until(cond: Callable, max_seconds: float) -> void:
	var t := 0.0
	while not cond.call() and t < max_seconds:
		await process_frame
		t += 1.0 / 60.0
