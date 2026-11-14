## v8b 설정 한 곳: 설정 파일(ScreenMode.settings_path)의 [ui]·[strip] 값을 읽고 쓰고, 기본값·틀린 값을 맡는다.
## 다른 화면 코드는 Prefs.get_value / set_value / reset만 부른다 (ConfigFile을 직접 열지 않는다).
## 켤 때(main._ready) read_file()로 한 번 읽어 들고 있다 (Fmt.money가 매 프레임 여러 번 읽어서).
## 큰 화면 방식([screen] full_style)은 그대로 ScreenMode, 급송 전화는 게임 저장(state.rush_enabled).
extends RefCounted

const ScreenMode = preload("res://scripts/ui/screen_mode.gd")

## "묶음/이름" → 기본값 (기본값이면 지금과 똑같이 보이고 동작함)
const DEFAULTS := {
	"ui/locale": "",             ## "" = 안 골랐음 → PC 언어 (한국어가 아니면 English)
	"ui/number_style": "auto",   ## auto = 언어 따라, ko = 만·억, en = K·M (그 언어 번역의 돈 단위를 씀)
	"ui/notices": true,          ## 끄면 동네 알림 글이 안 뜸 (아이콘·"+돈"은 그대로)
	"strip/always_on_top": true,
	"strip/opacity": 1.0,
	"strip/scale": 1.0,
	"strip/corner": "right",     ## right = 오른쪽 아래, left = 왼쪽 아래
	"strip/screen": -1,          ## -1 = 주 모니터, 0~ = 모니터 번호 (뽑혔으면 주 모니터에 놓고 값은 남김)
}
## 고를 수 있는 값. 여기 없는 값(손으로 고친 파일)은 기본값으로 읽는다. strip/screen은 -1 이상 정수
const CHOICES := {
	"ui/locale": ["ko", "en"],
	"ui/number_style": ["auto", "ko", "en"],
	"ui/notices": [true, false],
	"strip/always_on_top": [true, false],
	"strip/opacity": [1.0, 0.85, 0.7, 0.5],
	"strip/scale": [1.0, 1.25, 1.5],
	"strip/corner": ["right", "left"],
}

static var _values := {}   ## 파일에서 읽은 맞는 값만 (없으면 기본값)


## 설정 파일을 다시 읽음 (main._ready. 확인 스크립트가 settings_path를 바꾼 뒤에도 맞게).
## 이름이 reload면 Godot의 Script.reload()가 불려 스크립트를 다시 읽어 버림 (static 값이 비워짐)
static func read_file() -> void:
	_values.clear()
	var cfg := ConfigFile.new()
	if cfg.load(ScreenMode.settings_path) != OK:
		return
	for key: String in DEFAULTS:
		var section := key.get_slice("/", 0)
		var name := key.get_slice("/", 1)
		if cfg.has_section_key(section, name) and is_valid(key, cfg.get_value(section, name)):   # 기본값 null을 주면 Godot이 오류를 찍어서
			_values[key] = cfg.get_value(section, name)


static func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS[key])


## 값을 바꾸고 파일에 씀 (파일의 다른 값은 그대로). 고를 수 없는 값이면 그대로 두고 false
static func set_value(key: String, v: Variant) -> bool:
	if not is_valid(key, v):
		return false
	_values[key] = v
	ScreenMode.save_value(key.get_slice("/", 0), key.get_slice("/", 1), v)
	return true


## 전부 기본값으로: 파일에서 [ui]·[strip] 값을 지움 (큰 화면 방식은 main이 ScreenMode로, 처음 말풍선·게임 저장은 그대로)
static func reset() -> void:
	_values.clear()
	var cfg := ConfigFile.new()
	if cfg.load(ScreenMode.settings_path) != OK:
		return
	for key: String in DEFAULTS:
		if cfg.has_section_key(key.get_slice("/", 0), key.get_slice("/", 1)):
			cfg.erase_section_key(key.get_slice("/", 0), key.get_slice("/", 1))
	var err := cfg.save(ScreenMode.settings_path)
	if err != OK:
		push_warning("설정 저장 실패 (오류 %d): %s" % [err, ScreenMode.settings_path])


static func is_valid(key: String, v: Variant) -> bool:
	if typeof(v) != typeof(DEFAULTS[key]):
		return false
	if key == "strip/screen":
		return v >= -1
	return CHOICES[key].has(v)


## 쓸 언어: 고른 언어, 안 골랐으면 PC 언어 (한국어가 아니면 en)
static func locale() -> String:
	var v: String = get_value("ui/locale")
	if v != "":
		return v
	return "ko" if OS.get_locale_language() == "ko" else "en"
