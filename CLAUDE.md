# 택배 방치형 (가제)

스팀용 데스크톱 방치형 게임. 작업표시줄 바로 위 얇은 띠에서 택배 트럭이 알아서 배송하고,
번 돈으로 엔진을 강화한다 (메이플 스타포스식: 성공 / 실패(유지) / 퍼짐).
게임 안 결제 없음. 한 번 사면 끝나는 유료 게임.

## 기술
- Godot 4 (GDScript). 타깃은 Windows 10/11.
- 그림은 아직 없음. 색 사각형 같은 임시 그림으로 진행.

## 규칙
1. 게임 숫자(확률, 가격, 수익)는 `data/balance.json`에만 둔다. 코드에 직접 쓰지 않는다.
   - 예외: 연출용 숫자(이동 시간, 흔들림 세기 등)는 `scripts/ui/feel.gd`에 상수로 모은다.
2. 강화 판정(성공/실패/퍼짐 굴리기)은 `scripts/core/enhance.gd` 한 파일에만 둔다.
   화면 코드에서 확률 계산 금지. (나중에 서버로 옮길 수 있게)
3. `scripts/core/`는 화면(노드) 없이 돌아가는 순수 계산 코드로 유지한다. 테스트할 수 있게.
4. 지시서에 없는 기능은 만들지 않는다. 떠오른 아이디어는 `docs/IDEAS.md`에 한 줄 적고 넘어간다.
5. 한 단계가 끝나면 멈추고 알려준다: 뭘 만들었나 / 어떻게 실행하나 / 뭘 확인하면 되나.
6. 설명은 쉬운 한국어로. 전문용어는 풀어서 말한다.
7. Godot 설정 이름과 함수는 기억에 의존하지 말고, 설치된 버전의 문서로 확인하고 쓴다.
8. 단계마다 git 커밋.

## 폴더
```
data/balance.json        게임 숫자 전부 (게임과 시뮬이 같이 읽음)
docs/PROTOTYPE_V1.md     지금 할 일 (시제품 v1 지시서)
docs/PROTOTYPE_V2.md     지금 할 일 (튜닝·큐브: 트럭 8칸, 에이전트 둘이 나눠 만듦)
docs/PROTOTYPE_V0.md     끝난 시제품 v0 지시서
docs/IDEAS.md            나중에 할 것 / 이미 정한 것
tools/delivery_sim.py    경제 시뮬레이터 (파이썬, 가상 유저 1만 명)
scripts/core/            계산 코드 (balance, economy, enhance, tune 튜닝, game_state, save)
scripts/ui/              화면 코드 (main, town 동네, route 꼬불길 계산, truck, garage_panel 차고,
                         settings_panel 설정, screen_mode 두 화면 오가기, desktop_window 창, tray_icon 알림 영역)
scenes/                  Godot 씬
tests/                   테스트·확인 스크립트 (soak_logs/ = 오래 켜두기 기록)
```

## 명령
**Godot 4.6.3 사용.** 함수·설정 이름은 반드시 4.6.3 기준으로 찾는다 (다른 4.x 버전 문서·기억 말고).
버전을 바꾸려면 사용자와 먼저 정하고 여기를 고친다.

winget으로 설치됨. 실행 파일 폴더:
`C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\`
- `Godot_v4.6.3-stable_win64.exe`: 보통 실행용 (아래 `<GODOT>`)
- `Godot_v4.6.3-stable_win64_console.exe`: 출력이 터미널에 찍히는 실행용 (아래 `<GODOT_CONSOLE>`)
- 렌더러: Compatibility (OpenGL). 2D만 쓰고, 하루 종일 켜두는 게임이라 가벼운 쪽

**PowerShell에서는 경로 앞에 `&`를 꼭 붙인다.** (안 붙이면 "Unexpected token" 오류)
**`--path` 뒤에는 프로젝트 폴더 전체 경로를 쓴다.** `--path .`은 터미널이 지금 있는 폴더라서,
바깥 폴더(`itwasdeliverd`)에서 실행하면 "File not found" 오류가 난다.
**`.ps1` 파일은 `powershell -ExecutionPolicy Bypass -File "<경로>"`로 실행한다.** 이 PC는 기본 설정이
스크립트 파일 실행을 막아서 `& "<경로>.ps1"`로는 "스크립트를 실행할 수 없으므로" 오류가 난다.
(Bypass는 그 한 번만 허용. PC 설정은 안 바뀜)

PowerShell (사용자 터미널): 어느 폴더에서든 그대로 복사해서 붙여 넣기

**화면 없이 도는 확인** (창이 안 뜸. 언제 돌려도 됨)
```powershell
# 테스트 (전부 통과면 마지막 줄 "테스트 N개 중 N개 통과")
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/run_tests.gd

# 동네 1시간 수익 (0/10/20/30강 + 화면 오가기. 게임 1시간을 몇 초 만에)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" --fixed-fps 60 -s tests/check_town_hour.gd

# 차고 (작은 화면 클릭 → 큰 화면, 0~30강, 퍼짐 → 수리, 여러 창 크기, [설정], [작게])
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/check_garage.gd

# 저장·꺼둔 동안 수익 (진짜 저장 파일은 안 건드림)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/check_save.gd

# 작은 화면 ↔ 큰 화면 오가기 (창은 안 건드림. 마지막 줄 "확인 N개 중 N개 통과")
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/check_switch.gd
```

**진짜 창이 뜨는 확인** (화면이 깜빡이거나 덮임. 사용자에게 먼저 묻고 한 번에 몰아서. 마우스·키보드는 안 건드림)
```powershell
# 작은 화면 ↔ 큰 화면 진짜 창으로 오가기 (전체 화면 100번 + 창 모드 100번 + 방식 바꾸기 20번. 약 1분 깜빡임)
powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\check_switch.ps1"

# 투명 창 클릭 통과 (작은 화면 + 큰 화면 두 방식. 몇 초 동안 큰 화면이 주 모니터를 덮음)
powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\check_desktop.ps1"

# 오래 켜두기 (기본 2시간, 작은 화면, 시험용 저장. 10분마다 큰 화면 3초: 끝에 -switchEvery 10. 기록은 tests\soak_logs)
powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\soak_desktop.ps1"

# 화면 사진 찍기 (평범한 창이 몇 초 떴다 꺼짐. 1280x720~3440x1440, 강화 연출, 설정 화면)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/shot_screens.gd -- --windowed "--out=<사진 폴더>"
```

**실행**
```powershell
# 게임 (작은 화면 = 주 모니터 오른쪽 아래 구석. 디버그 실행이라 F1~F5 치트 키가 켜져 있음)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv"

# 게임: 평범한 창 (개발용. 작은 화면 480x220 ↔ 큰 화면 1600x900)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -- --windowed

# 편집기 열기
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" --editor

# 시뮬 (-X utf8: 결과를 파일로 돌리면 막대그래프 글자(█) 때문에 cp949 오류가 나서)
python -X utf8 "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tools\delivery_sim.py"
```

그 밖에:
- 저장 파일: `C:\Users\PAUL SHIN\AppData\Roaming\Godot\app_userdata\택배 방치형\save.json`
  (`saved_at_utc`는 세계 표준시. 손으로 3시간 전으로 바꾸면 꺼둔 동안 수익 확인 가능)
- 설정 파일: 같은 폴더 `settings.cfg` (`[screen] full_style = "fullscreen"` 또는 `"windowed"`).
  확인 스크립트는 main을 만들기 전에 `ScreenMode.settings_path`를 시험용으로 바꾼다
- 설치된 버전 문서 뽑기 (규칙 7): `<GODOT_CONSOLE> --headless --doctool <빈 폴더>`
  → `<빈 폴더>/doc/classes/클래스이름.xml` 에서 함수·설정 이름 확인
- Git Bash에서는 `&` 없이 경로를 따옴표로 감싸서 실행
- 투명 창에서 알아둘 것 (Godot 4.6.3 + Windows에서 직접 확인):
  - 창 전체 클릭 통과(`Window.mouse_passthrough`)는 다른 프로그램으로 클릭이 안 넘어간다.
    `mouse_passthrough_polygon`만 되는데, 다각형 밖은 그려지지도 않는다 → "보이는 것 = 클릭 받는 곳".
    작은 화면에 새로 그리는 것이 생기면 `visible_rects()`(main.gd / town.gd)에 넣어야 보인다.
  - 클릭 통과 다각형을 빈 배열로 주면 창 전체가 클릭을 받는다 (큰 화면).
  - 창의 `transparent`는 켜 둔 채 `transparent_bg`만 껐다 켜면 투명 ↔ 불투명이 깨지지 않는다.
  - 큰 화면 전체 화면은 `Window.MODE_FULLSCREEN`을 안 쓴다: 그건 창을 2픽셀 크게 만들고 그림은 아래쪽부터
    모니터 크기만큼만 그려서 맨 위 2줄로 바탕화면이 보인다. 창 크기를 모니터와 똑같이 맞추면 Godot이
    독점 전체 화면으로 바꿔서 다시 작아지지 않는다 → 테두리 없는 보통 창을 모니터보다 위아래 1픽셀씩 크게
    (`DesktopWindow.full_window_rect()`). `check_switch.ps1`이 모니터 맨 위 2줄까지 확인함.
  - 전체 화면 → 창 모드로 바로 가면 안쪽이 4픽셀씩 줄어든다 → 작은 화면 처리를 거쳐 간다 (`desktop_window.gd`).
  - PowerShell 5.1: `Start-Process -PassThru`로 띄우고 `HasExited`로만 기다리면 `ExitCode`가 빈다
    → 띄우자마자 `$null = $p.Handle`.
  - 새 알림 영역 아이콘은 Windows 11이 ^ 숨김 칸에 넣는다 (앱에서 못 바꿈).
- Godot 좌표와 Windows 좌표는 원점이 다르다 (주 모니터 왼쪽 위가 Windows 0,0)
- `_console.exe`는 진짜 게임을 자식 프로세스로 띄운다 → 그 PID로 GDI를 재면 0. 게임이 찍은 PID로 잰다
- 프로젝트 안의 `.csv`는 Godot가 번역 파일로 가져간다 → 기록 파일은 `.gdignore`가 있는 폴더(`tests/soak_logs`)에

## 현재 작업
`docs/PROTOTYPE_V0.md` 끝 (플레이 테스트 "아니오" 1개, 결과는 `docs/IDEAS.md`).
`docs/PROTOTYPE_V1.md` (작은 화면 + 큰 화면): 창 담당 / 동네 담당 두 에이전트가 병렬로 만들고 `prototype-v1`에 합침.
화면 없는 확인은 전부 통과. 남은 것:
- 진짜 창 확인: 2026-11-10 사용자 자리 비운 동안 돌림. `check_switch.ps1` 전부 통과 (Windows 20/20, Godot 10750/10750,
  220번 오가도 메모리 +2.2MB·GDI 0), `check_desktop.ps1` 44/44. 그때 전체 화면 맨 위 2줄 빈틈을 찾아 고침
- 오래 켜두기: 따로 안 함. 사용자가 2026-11-10에 2시간 넘게 켜 두고 화면 어두워짐·작업표시줄 깨짐 없음을 확인
  (v0 기록 1시간 44분: GDI·USER·핸들 그대로, 작업 메모리만 98~472MB 오르내림. 원인 모름 → 평소 쓸 때 지켜보기)
- 사용자가 손으로: 알림 영역 아이콘 왼쪽 클릭(다른 프로그램을 쓰던 중에도 큰 화면이 앞으로 오나), 오른쪽 클릭 메뉴
- v1 플레이 테스트 (지시서 맨 아래 5문항)
- 튜닝(큐브): `docs/PROTOTYPE_V2.md` 1~3단계 끝 (2026-11-12, 추천안). 계산 담당(window 에이전트, 가지 `v2-core`) /
  화면 담당(town 에이전트, 가지 `v2-ui`)이 병렬로 만들고 `prototype-v2`에 합침. 화면 없는 확인 전부 통과.
  시뮬 `python -I -X utf8 tools/tune_sim.py`: 튜닝 있으면 20강 1.7배·25강 4배 빨라짐 (너무 세면 `tune` 숫자부터)
  남은 것: 튜닝 화면을 눈으로 확인(스크린샷은 `tests/shot_screens.gd`, 창이 뜨니 사용자에게 먼저 물어봄), v2 플레이 테스트
