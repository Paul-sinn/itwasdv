## 대리점 사무실 화면 (v7a U2. 창업 뒤 띠·큰 화면 건물 줄의 사무실을 누르면). 세 칸 고르기:
##   [트럭]: 보조 트럭 목록 ("2호차  +3 · 시간당 M원") + [보조 트럭 사기 (N원)] (모자라면 꺼짐 + "N원 모자람 · 약 N분 뒤", 다 샀으면 "더 살 수 없어요")
##   [순위표]: 잠긴 줄 3개(세계·전국·지역) + 시내 순위표: "다음 순위까지 시간당 N원", 라이벌 10곳 + 나 (내 줄 강조, 1위면 1위 색)
##   [장부]: 오늘 매출·직원 몫·세금·순이익 + 세율표 5줄 (지금 단계 강조)
##     v7b U2: 매출 아래 "· 그중 기업 계약 N원" (Company.today contract), 순이익 아래 "기업 계약 N / 3 · 시간당 N원"(Contract.hourly) +
##     "다음 계약까지 회사 평판 N" (Contract.next_reputation − 평판. 다 맺으면 "기업 계약을 모두 맺었어요")
## 순위·남은 양·오늘 집계·보조 트럭 값은 Company 값을, 라이벌 매출·세율은 balance 숫자를 그대로 보여 준다 (여기서 계산하지 않음).
## 트럭 시간당은 Trip.hourly_income (번 돈 기준. 튜닝숍 강화 칸과 같음). 버튼은 신호만 → main.gd → Company.buy_helper
## 라이벌 이름은 번역 파일 RIVAL_<번호> (번호 = balance rivals 순서, 0이 가장 작음), 단계 이름은 STAGE_<단계 id>
## v7b: [트럭] 칸에 트럭마다 (내 트럭부터) 줄 + [시내 · 시간당 N원] [장거리 · 시간당 N원] 스위치 (지금 고른 쪽 눌림) + 한 줄 안내:
##      바꾼 뒤 이번 바퀴가 끝나기 전이면 "다음 바퀴부터 장거리", 장거리가 잠겼으면 "장거리는 엔진 +10부터".
##      스위치 → route_pressed → main.gd → Trip.set_route. 값은 Trip.route_choice / can_long / route_id / hourly_income_on, 잠금 단계는 balance routes.long.unlock_star
extends VBoxContainer

const Balance = preload("res://scripts/core/balance.gd")
const Company = preload("res://scripts/core/company.gd")
const Contract = preload("res://scripts/core/contract.gd")
const Economy = preload("res://scripts/core/economy.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Trip = preload("res://scripts/core/trip.gd")
const Feel = preload("res://scripts/ui/feel.gd")
const Fmt = preload("res://scripts/ui/fmt.gd")
const Town = preload("res://scripts/ui/town.gd")

## 스위치 순서와 노선 이름 번역 키
const ROUTES := ["city", "long"]
const ROUTE_NAMES := { "city": "ROUTE_CITY", "long": "ROUTE_LONG" }

signal buy_pressed   ## [보조 트럭 사기]
signal route_pressed(i: int, id: String)   ## [시내] / [장거리] (i = 트럭 번호, 0 = 내 트럭)

enum Page { TRUCKS, RANK, BOOKS }
## 잠긴 순위표 줄 (위가 큰 무대)
const LOCKED_SCOPES := ["RANK_SCOPE_GLOBAL", "RANK_SCOPE_NATIONAL", "RANK_SCOPE_REGIONAL"]

var page := Page.TRUCKS
var page_buttons := {}               ## Page → 칸 고르기 버튼
var buy_button: Button
var truck_lines: Array[Label] = []   ## 보조 트럭 줄 (2호차부터)
var mine_line: Label                 ## 내 트럭 줄 (맨 위)
var route_buttons: Array[Dictionary] = []   ## 트럭 번호 → { "city": Button, "long": Button }
var route_notes: Array[Label] = []   ## 트럭 번호 → "다음 바퀴부터 …" / "장거리는 엔진 +N부터" (없으면 숨김)
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
var _contract: Label        ## "· 그중 기업 계약 N원" (매출 아래)
var _contracts: Label       ## "기업 계약 N / 3 · 시간당 N원"
var _contract_next: Label   ## "다음 계약까지 회사 평판 N" / "기업 계약을 모두 맺었어요"
var _tax_list: VBoxContainer
var _scale := 1.0
var _font_sizes := {}     ## 글자 → 배수 곱하기 전 크기
var _blocks: Array[BoxContainer] = []   ## 트럭 칸·스위치 줄 (간격을 배수에 맞춤)


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
	_contract = _label(books, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
	_staff = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_tax = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_profit = _label(books, Feel.PANEL_TITLE_SIZE, Feel.COLOR_STAR)
	_contracts = _label(books, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	_contract_next = _label(books, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM)
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
	for box: BoxContainer in _blocks:
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
	while route_buttons.size() < n + 1:
		_add_truck_block()
	for i in route_buttons.size():   # 트럭 번호 i (0 = 내 트럭, 보조 트럭 줄 = truck_lines[i − 1], 이름 "(i + 1)호차")
		var shown := i <= n
		route_notes[i].get_parent().visible = shown
		if not shown:
			continue
		var line := mine_line if i == 0 else truck_lines[i - 1]
		line.text = tr("OFFICE_TRUCK_LINE") % [tr("TRUCK_TAB_MINE") if i == 0 else tr("TRUCK_TAB_HELPER") % (i + 1), s.truck(i).star,
				Fmt.money(int(Trip.hourly_income(b, s, i)))]
		_refresh_route(b, s, i)
	_no_helper.visible = n == 0
	var price := Company.helper_price(b, s)
	buy_button.visible = price >= 0
	if price >= 0:
		buy_button.text = tr("OFFICE_BUY_HELPER") % Fmt.money(price)
	buy_button.disabled = not Company.can_buy_helper(b, s)
	if price < 0:
		_buy_note.text = tr("OFFICE_HELPER_FULL")
	elif s.money < price:
		_buy_note.text = tr("DEPOT_SHORT") % [Fmt.money(price - s.money), Fmt.wait_text(Economy.seconds_to_afford(price, s.money, Company.hourly_net(b, s)))]
	_buy_note.visible = price < 0 or s.money < price


## 트럭 i의 스위치: 고른 쪽 눌림, 두 노선 시간당, 장거리 잠김이면 꺼짐 + 안내, 바꾼 노선이 다음 바퀴부터면 안내
func _refresh_route(b: Balance, s: GameState, i: int) -> void:
	var choice := Trip.route_choice(s, i)
	for id: String in ROUTES:
		var btn: Button = route_buttons[i][id]
		btn.text = tr("OFFICE_ROUTE_BUTTON") % [tr(ROUTE_NAMES[id]), Fmt.money(int(Trip.hourly_income_on(b, s, i, id)))]
		btn.set_pressed_no_signal(id == choice)
	var open := Trip.can_long(b, s, i)
	route_buttons[i]["long"].disabled = not open
	var note := route_notes[i]
	var pending := choice != Trip.route_id(s, i)   # 바꿨는데 이번 바퀴는 아직 예전 노선
	if pending:
		note.text = tr("OFFICE_ROUTE_NEXT") % tr(ROUTE_NAMES[choice])
	elif not open:
		note.text = tr("OFFICE_ROUTE_LOCKED") % b.routes["long"].get("unlock_star", 0)
	note.visible = pending or not open


## 트럭 하나의 칸: 줄 + 스위치 두 개 + 안내 한 줄 (트럭 번호 = 만든 순서)
func _add_truck_block() -> void:
	var i := route_buttons.size()
	var block := VBoxContainer.new()
	_truck_list.add_child(block)
	var l := _label(block, Feel.PANEL_TEXT_SIZE, Feel.COLOR_TEXT)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # 산 순간 커질 기준점
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if i == 0:
		mine_line = l
	else:
		truck_lines.append(l)
	var row := HBoxContainer.new()
	block.add_child(row)
	var pair := {}
	for id: String in ROUTES:
		var btn := _button(row, "", Feel.PANEL_TEXT_SIZE)
		btn.toggle_mode = true   # 눌림 = 고른 노선 (refresh가 상태에 맞춤)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_color_override("font_pressed_color", Feel.COLOR_STAR)
		btn.add_theme_color_override("font_hover_pressed_color", Feel.COLOR_STAR)
		btn.pressed.connect(func(): route_pressed.emit(i, id))
		pair[id] = btn
	route_buttons.append(pair)
	route_notes.append(_label(block, Feel.PANEL_SMALL_SIZE, Feel.COLOR_DIM))
	_blocks.append(block)
	_blocks.append(row)
	set_ui_scale(_scale)


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
	_contract.text = tr("BOOKS_CONTRACT") % Fmt.money(d["contract"])
	_contracts.text = tr("BOOKS_CONTRACTS") % [Contract.count(s), b.contract_reputation.size(), Fmt.money(int(Contract.hourly(b, s)))]
	var need := Contract.next_reputation(b, s)
	_contract_next.text = tr("BOOKS_CONTRACT_ALL") if need < 0 else tr("BOOKS_CONTRACT_NEXT") % Fmt.count(maxi(need - s.reputation, 0))
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
