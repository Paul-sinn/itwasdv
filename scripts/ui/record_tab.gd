## 물류센터 [기록] 칸 (v8a). 세 번째 칸: [능력치] [창고·할 일] [기록]
## 높이가 정해진 스크롤 칸(DRIVER_PAGE_HEIGHT. [창고·할 일]과 같은 높이) 안에 세 묶음 (1280x720에서도 물류센터 화면이 창 안):
##   통계 12줄: 이름 … 값 (Stats.get_all. 돈은 Fmt.money, 켜 둔 시간은 Fmt.away, 최고 단계는 "+N")
##   잡옵 도감 25칸 (Stats.junk_book): 등급 이름 머리줄, 잡옵마다 이름 + 등급 5칸.
##     안 본 칸 "?", 본 칸은 등급 색 바탕에 본 횟수, 같은 잡옵 3줄이 나온 칸은 별 그림 (글꼴 글자 대신 도형: 번역 규칙상 별 글자 금지)
##   업적 20줄 (Achievement.all 순서): 이름 + 오른쪽 "달성" / "N / 목표", 아래 작은 줄 설명 (+ 보상 랩핑이 있으면 "보상: 랩핑 '…'")
## 이름·설명은 번역 키 STAT_<키>, SETTING_OPT_<잡옵>, ACH_<ID>, ACH_<ID>_DESC, WRAP_<ID>. 값은 계산 쪽 그대로 (여기서 세지 않음.
## 업적 진행은 목표를 넘을 수 있어 화면에서 목표로 자름, 보상 랩핑은 Wrap.for_achievement)
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Setting = preload("res://scripts/core/setting.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Achievement = preload("res://scripts/core/achievement.gd")
const Wrap = preload("res://scripts/core/wrap.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")

## 통계 줄 순서 (지시서 Stats.get_all 키 순서)와 값 글 번역 키. 없는 키는 RECORD_TIMES ("N번"), 켜 둔 시간은 Fmt.away
const STAT_KEYS := ["parcels", "money_earned", "seconds_on", "best_star", "tries", "successes", "fails", "destroys",
		"insured_saves", "setting_rolls", "tips", "master_visits"]
const STAT_VALUE_KEYS := { "parcels": "RECORD_PARCELS", "money_earned": "RECORD_MONEY", "best_star": "RECORD_STAR" }

var scroll: ScrollContainer
var stat_values := {}    ## 통계 키 → 값 글
var cells: Array = []    ## 도감 칸마다 { "option", "grade", "label": Label, "star": Control, "style": StyleBoxFlat } (junk_book 순서)
var ach_rights := {}     ## 업적 id → 오른쪽 "달성" / "N / 목표"
var ach_names := {}      ## 업적 id → 이름
var ach_notes := {}      ## 업적 id → 설명 (+ 보상)

var _list: VBoxContainer
var _stats_head: Label
var _book_head: Label
var _ach_head: Label
var _boxes: Array[BoxContainer] = []   ## 간격을 배수로 맞출 상자들
var _scale := 1.0
var _font_sizes := {}    ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_boxes.append(_list)
	_stats_head = _label(_list, Feel.RECORD_HEAD_SIZE, Feel.COLOR_STAR)
	_stats_head.text = tr("RECORD_STATS")
	set_ui_scale(_scale)


func set_ui_scale(s: float) -> void:
	_scale = s
	if scroll == null:
		return
	scroll.custom_minimum_size.y = Feel.DRIVER_PAGE_HEIGHT * s
	for box in _boxes:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for c in cells:
		c["label"].get_parent().get_parent().custom_minimum_size.y = Feel.BOOK_CELL_HEIGHT * s
		c["star"].custom_minimum_size = Vector2.ONE * Feel.BOOK_STAR_SIZE * s
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", maxi(1, int(roundf(_font_sizes[c] * s))))


## 지금 상태대로 (보이는 동안 매 프레임)
func refresh(b: Balance, s: GameState) -> void:
	if stat_values.is_empty():
		_build(b, s)
	var stats := Stats.get_all(s)
	for k: String in STAT_KEYS:
		var v = stats.get(k, 0)
		if k == "seconds_on":
			stat_values[k].text = Fmt.away(v)
		elif k == "money_earned":
			stat_values[k].text = tr("RECORD_MONEY") % Fmt.money(v)
		elif k == "best_star":
			stat_values[k].text = tr("RECORD_STAR") % v
		else:
			stat_values[k].text = tr(STAT_VALUE_KEYS.get(k, "RECORD_TIMES")) % Fmt.count(v)

	var book := Stats.junk_book(b, s)
	_book_head.text = tr("RECORD_BOOK") % [Stats.junk_book_count(s), book.size()]
	for j in mini(book.size(), cells.size()):
		var e: Dictionary = book[j]
		var c: Dictionary = cells[j]
		var seen: int = e["seen"]
		c["label"].text = tr("RECORD_BOOK_SEEN") % seen if seen > 0 else "?"
		c["star"].visible = e["triple"]
		var bg: Color = Feel.SETTING_GRADE_COLORS[e["grade"]] if seen > 0 else Feel.COLOR_BOOK_EMPTY
		if seen > 0:
			bg.a = Feel.BOOK_CELL_ALPHA
		c["style"].bg_color = bg

	var done := 0
	for a: Dictionary in Achievement.all(b):
		var id: String = a["id"]
		var ok := Achievement.is_done(s, id)
		done += 1 if ok else 0
		var pr := Achievement.progress(b, s, id)
		ach_rights[id].text = tr("RECORD_ACH_DONE") if ok else tr("RECORD_ACH_PROGRESS") % [Fmt.count(mini(pr[0], pr[1])), Fmt.count(pr[1])]
		ach_rights[id].add_theme_color_override("font_color", Feel.COLOR_ACH_DONE if ok else Feel.COLOR_DIM)
		ach_names[id].add_theme_color_override("font_color", Feel.COLOR_ACH_DONE if ok else Feel.COLOR_TEXT)
	_ach_head.text = tr("RECORD_ACH") % [done, Achievement.all(b).size()]


## 처음 한 번: 통계 줄, 도감 칸 (junk_book 순서 = 잡옵 json 순서 × 등급), 업적 줄 (설명·보상 글은 바뀌지 않아 여기서)
func _build(b: Balance, s: GameState) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	_list.add_child(grid)
	for k: String in STAT_KEYS:
		var nl := _label(grid, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
		nl.text = tr("STAT_" + k.to_upper())
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_values[k] = _label(grid, Feel.PANEL_SMALL_SIZE, Feel.COLOR_STAR)
		stat_values[k].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_values[k].autowrap_mode = TextServer.AUTOWRAP_OFF

	_book_head = _label(_list, Feel.RECORD_HEAD_SIZE, Feel.COLOR_STAR)
	var head := _row(_list)
	for g in Setting.max_grade(b) + 1:
		var gl := _label(head, Feel.PANEL_SMALL_SIZE, Feel.SETTING_GRADE_COLORS[g])
		gl.text = tr("SETTING_GRADE_%d" % g)
		gl.autowrap_mode = TextServer.AUTOWRAP_OFF
		gl.clip_text = true   # 칸 폭이 같게 (긴 등급 이름은 잘림)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = null
	var last := ""
	for e: Dictionary in Stats.junk_book(b, s):
		if e["option"] != last:
			last = e["option"]
			_label(_list, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT).text = tr("SETTING_OPT_" + last.to_upper())
			row = _row(_list)
		cells.append(_cell(row, e))

	_ach_head = _label(_list, Feel.RECORD_HEAD_SIZE, Feel.COLOR_STAR)
	for a: Dictionary in Achievement.all(b):
		var id: String = a["id"]
		var line := _row(_list)
		ach_names[id] = _label(line, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		ach_names[id].text = tr("ACH_" + id.to_upper())
		ach_names[id].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ach_rights[id] = _label(line, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		ach_rights[id].autowrap_mode = TextServer.AUTOWRAP_OFF
		ach_rights[id].size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ach_notes[id] = _label(_list, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
		var desc := tr("ACH_%s_DESC" % id.to_upper())
		if desc.contains("%s"):   # 목표 수가 들어가는 설명 (세팅 등급은 등급 이름)
			desc = desc % (tr("SETTING_GRADE_%d" % a["target"]) if a["kind"] == "setting_grade" else Fmt.count(a["target"]))
		ach_notes[id].text = desc
		var w := Wrap.for_achievement(b, id)
		if w != "":
			ach_notes[id].text += " · " + tr("RECORD_ACH_REWARD") % tr("WRAP_" + w.to_upper())
	set_ui_scale(_scale)


## 도감 한 칸: 바탕(등급 색 / 안 본 칸 색) 위에 본 횟수(또는 "?") + 3줄 별
func _cell(row: HBoxContainer, e: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 휠은 스크롤 칸으로
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	row.add_child(panel)
	var inner := HBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var l := _label(inner, Feel.PANEL_SMALL_SIZE, Feel.COLOR_TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star := Control.new()
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.draw.connect(_draw_star.bind(star))
	star.visible = false
	inner.add_child(star)
	return { "option": e["option"], "grade": e["grade"], "label": l, "star": star, "style": style }


## 별 그림: 꼭짓점 5개 (바깥·안쪽 반지름을 번갈아)
func _draw_star(c: Control) -> void:
	var r := minf(c.size.x, c.size.y) / 2.0
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + PI * k / 5.0
		pts.append(c.size / 2.0 + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, Feel.COLOR_STAR)


func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	parent.add_child(r)
	_boxes.append(r)
	return r


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l
