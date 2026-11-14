## 대리점 사무실 화면 (v7a U2. 창업 뒤 띠·큰 화면 건물 줄의 사무실을 누르면). 세 칸 고르기:
##   [트럭]: 보조 트럭 목록 ("2호차  +3 · 시간당 M원") + [보조 트럭 사기 (N원)] (모자라면 꺼짐 + 모자란 금액, 다 샀으면 "더 살 수 없어요")
##   [순위표]: 잠긴 줄 3개(세계·전국·지역) + 시내 순위표: "다음 순위까지 시간당 N원", 라이벌 10곳 + 나 (내 줄 강조, 1위면 1위 색)
##   [장부]: 오늘 매출·직원 몫·세금·순이익 + 세율표 5줄 (지금 단계 강조)
## 순위·남은 양·오늘 집계·보조 트럭 값은 Company 값을, 라이벌 매출·세율은 balance 숫자를 그대로 보여 준다 (여기서 계산하지 않음).
## 트럭 시간당은 Trip.hourly_income (번 돈 기준. 튜닝숍 강화 칸과 같음). 버튼은 신호만 → main.gd → Company.buy_helper
## 라이벌 이름은 번역 파일 RIVAL_<번호> (번호 = balance rivals 순서, 0이 가장 작음), 단계 이름은 STAGE_<단계 id>
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")

signal buy_pressed   ## [보조 트럭 사기]

enum Page { TRUCKS, RANK, BOOKS }
## 잠긴 순위표 줄 (위가 큰 무대)
const LOCKED_SCOPES := ["RANK_SCOPE_GLOBAL", "RANK_SCOPE_NATIONAL", "RANK_SCOPE_REGIONAL"]

var page := Page.TRUCKS
var page_buttons := {}               ## Page → 칸 고르기 버튼
var buy_button: Button
var truck_lines: Array[Label] = []   ## 보조 트럭 줄 (2호차부터)
var locked_rows: Array[Label] = []   ## 잠긴 줄 3개
var rank_rows: Array[Label] = []     ## 시내 순위표 줄 (위가 1위. 라이벌 수 + 1)
var tax_rows: Array[Label] = []      ## 세율표 줄 (단계 순서)

var _pages := {}          ## Page → 칸 내용
var _truck_list: VBoxContainer
var _no_helper: Label
var _buy_note: Label      ## "더 살 수 없어요" / "N원 모자람"
var _rank_next: Label     ## "다음 순위까지 시간당 N원" / 1위면 "시내 1위!"
var _rank_list: VBoxContainer
var _sales: Label
var _staff: Label
var _tax: Label
var _profit: Label
var _tax_list: VBoxContainer
var _scale := 1.0
var _font_sizes := {}     ## 글자 → 배수 곱하기 전 크기


func _ready() -> void:
	var tabs := HBoxContainer.new()
	add_child(tabs)
	var group := ButtonGroup.new()
	for pg: Page in [Page.TRUCKS, Page.RANK, Page.BOOKS]:
		var key: String = ["OFFICE_PAGE_TRUCKS", "OFFICE_PAGE_RANK", "OFFICE_PAGE_BOOKS"][pg]
		var btn := _button(tabs, tr(key), Feel.SETTING_TAB_SIZE)
		btn.toggle_mode = true
		btn.button_group = group
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		btn.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
		btn.pressed.connect(func(): show_page(pg))
		page_buttons[pg] = btn
		var box := VBoxContainer.new()
		add_child(box)
		_pages[pg] = box

	# [트럭]
	var trucks: VBoxContainer = _pages[Page.TRUCKS]
	_truck_list = VBoxContainer.new()
	trucks.add_child(_truck_list)
	_no_helper = _label(trucks, Feel.PANEL_TEXT_SIZE, Feel.COLOR_DIM)
	_no_helper.text = tr("OFFICE_NO_HELPER")
	buy_button = _button(trucks, "")
	buy_button.pressed.connect(func(): buy_pressed.emit())
	_buy_note = _label(trucks, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)

	# [순위표]: 잠긴 줄 3개, 제목, 다음 순위까지, 순위 줄들 (refresh에서 만듦)
	var rank: VBoxContainer = _pages[Page.RANK]
	for key: String in LOCKED_SCOPES:
		var l := _label(rank, Feel.OFFICE_ROW_SIZE, Feel.COLOR_LOCKED)
		l.text = tr("RANK_LOCKED") % tr(key)
		locked_rows.append(l)
	_label(rank, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM).text = tr("RANK_HEAD")
	_rank_next = _label(rank, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_rank_list = VBoxContainer.new()
	rank.add_child(_rank_list)

	# [장부]: 오늘 매출·직원 몫·세금·순이익, 세율표 (줄은 refresh에서 만듦)
	var books: VBoxContainer = _pages[Page.BOOKS]
	_label(books, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM).text = tr("BOOKS_HEAD")
	_sales = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_staff = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_tax = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_profit = _label(books, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_label(books, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM).text = tr("TAX_HEAD")
	_tax_list = VBoxContainer.new()
	books.add_child(_tax_list)
	show_page(page)
	set_ui_scale(_scale)


## 크기 배수 (1 = v0 패널). garage_panel.gd가 같이 부른다
func set_ui_scale(s: float) -> void:
	_scale = s
	if _tax_list == null:
		return
	add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for box: BoxContainer in _pages.values():
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s)))
	for box: BoxContainer in [_truck_list, _rank_list, _tax_list]:
		box.add_theme_constant_override("separation", int(roundf(Feel.PANEL_GAP_SMALL * s * 0.5)))
	for c: Control in _font_sizes:
		c.add_theme_font_size_override("font_size", _px(_font_sizes[c]))


## [트럭] / [순위표] / [장부]
func show_page(p: Page) -> void:
	page = p
	for pg: Page in _pages:
		_pages[pg].visible = pg == p
		page_buttons[pg].set_pressed_no_signal(pg == p)


## 산 직후: 새 트럭 줄이 커졌다 돌아옴
func show_bought(count: int) -> void:
	if count >= 1 and count <= truck_lines.size():
		Town.pop(truck_lines[count - 1], Feel.POP_PIVOT_LEFT)


## 상태에 맞게 글자와 버튼을 고친다 (보이는 동안 매 프레임)
func refresh(b: Balance, s: GameState) -> void:
	_refresh_trucks(b, s)
	_refresh_rank(b, s)
	_refresh_books(b, s)


func _refresh_trucks(b: Balance, s: GameState) -> void:
	var n := Company.helper_count(s)
	while truck_lines.size() < n:
		var l := _label(_truck_list, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 산 순간 커질 기준점
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		truck_lines.append(l)
	for i in truck_lines.size():
		truck_lines[i].visible = i < n
		if i < n:   # 보조 트럭 = 트럭 번호 i + 1, 이름 "(i + 2)호차"
			truck_lines[i].text = tr("OFFICE_TRUCK_LINE") % [tr("TRUCK_TAB_HELPER") % (i + 2), s.truck(i + 1).star,
					Fmt.money(int(Trip.hourly_income(b, s, i + 1)))]
	_no_helper.visible = n == 0
	var price := Company.helper_price(b, s)
	buy_button.visible = price >= 0
	if price >= 0:
		buy_button.text = tr("OFFICE_BUY_HELPER") % Fmt.money(price)
	buy_button.disabled = not Company.can_buy_helper(b, s)
	if price < 0:
		_buy_note.text = tr("OFFICE_HELPER_FULL")
	elif s.money < price:
		_buy_note.text = tr("AGENCY_SHORT") % Fmt.money(price - s.money)
	_buy_note.visible = price < 0 or s.money < price


## 순위 줄: 내 자리 = Company.rank (위에서 rank번째). 나머지는 라이벌을 매출이 큰 순서로 (balance rivals는 오름차순)
func _refresh_rank(b: Balance, s: GameState) -> void:
	while rank_rows.size() < b.rivals.size() + 1:
		rank_rows.append(_label(_rank_list, Feel.OFFICE_ROW_SIZE, Feel.COLOR_TEXT))
	var rank := Company.rank(b, s)
	_rank_next.text = tr("RANK_TOP") if rank == 1 else tr("RANK_NEXT") % Fmt.money(ceili(Company.next_gap(b, s)))
	_rank_next.add_theme_color_override("font_color", Feel.COLOR_RANK_FIRST if rank == 1 else Feel.COLOR_TEXT)
	var rival := b.rivals.size() - 1
	for row in rank_rows.size():
		var l := rank_rows[row]
		if row == rank - 1:
			l.text = tr("RANK_ROW") % [row + 1, tr("RANK_ME"), Fmt.money(int(Company.hourly_sales(b, s)))]
			l.add_theme_color_override("font_color", Feel.COLOR_RANK_FIRST if rank == 1 else Feel.COLOR_STAR)
		else:
			l.text = tr("RANK_ROW") % [row + 1, tr("RIVAL_%d" % rival), Fmt.money(int(b.rivals[rival]))]
			l.add_theme_color_override("font_color", Feel.COLOR_TEXT)
			rival -= 1


func _refresh_books(b: Balance, s: GameState) -> void:
	var d := Company.today(s)
	_sales.text = tr("BOOKS_SALES") % Fmt.money(d["sales"])
	_staff.text = tr("BOOKS_STAFF") % Fmt.money(d["staff"])
	_tax.text = tr("BOOKS_TAX") % Fmt.money(d["tax"])
	_profit.text = tr("BOOKS_PROFIT") % Fmt.money(d["profit"])
	while tax_rows.size() < b.tax_rates.size():
		tax_rows.append(_label(_tax_list, Feel.OFFICE_ROW_SIZE, Feel.COLOR_DIM))
	for i in tax_rows.size():
		tax_rows[i].text = tr("TAX_ROW") % [tr("STAGE_" + b.company_stages[i].to_upper()), Fmt.percent(b.tax_rates[i])]
		tax_rows[i].add_theme_color_override("font_color", Feel.COLOR_STAR if i == Company.stage(s) else Feel.COLOR_DIM)


func _px(base: float) -> int:
	return maxi(1, int(roundf(base * _scale)))


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	_font_sizes[l] = font_size
	l.add_theme_font_size_override("font_size", _px(font_size))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # 긴 줄(영어 등)은 차고 폭 안에서 줄바꿈
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, font_size: int = Feel.PANEL_BUTTON_SIZE) -> Button:
	var btn := Button.new()
	btn.text = text
	_font_sizes[btn] = font_size
	btn.add_theme_font_size_override("font_size", _px(font_size))
	btn.focus_mode = Control.FOCUS_NONE   # 스페이스/엔터로 실수로 눌리지 않게
	parent.add_child(btn)
	return btn
