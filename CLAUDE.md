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
docs/PROTOTYPE_V0.md     지금 할 일 (시제품 지시서)
docs/IDEAS.md            나중에 할 것 / 이미 정한 것
tools/delivery_sim.py    경제 시뮬레이터 (파이썬, 가상 유저 1만 명)
scripts/core/            계산 코드 (balance, economy, enhance, game_state, save)
scripts/ui/              화면 코드
scenes/                  Godot 씬
tests/                   화면 없이 돌리는 테스트
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
```powershell
# 테스트 (전부 통과면 마지막 줄 "테스트 N개 중 N개 통과")
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/run_tests.gd

# 띠 1시간 수익 확인 (2단계 완료 기준. 화면 없이 게임 1시간을 몇 초 만에 돌림)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" --fixed-fps 60 -s tests/check_band_hour.gd

# 차고 패널 확인 (3단계 완료 기준. 진짜 키·클릭으로 0~30강, 퍼짐 → 수리까지)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/check_garage.gd

# 저장·꺼둔 동안 수익 확인 (4단계 완료 기준. 진짜 저장 파일은 안 건드림)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/check_save.gd

# 투명 창 클릭 통과 확인 (5단계. 진짜 창을 몇 초 띄움. 마우스는 안 건드림)
powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\check_desktop.ps1"

# 오래 켜두기 확인 (5단계. 기본 2시간, 1분마다 메모리·GDI 기록. 짧게는 끝에 -minutes 10)
powershell -ExecutionPolicy Bypass -File "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tests\soak_desktop.ps1"

# 편집기 열기
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" --editor

# 게임 실행: 작업표시줄 위 투명 띠 (디버그 실행이라 F1~F5 치트 키가 켜져 있음)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv"

# 게임 실행: 평범한 창 (개발용)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -- --windowed

# 시뮬
python "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tools\delivery_sim.py"
```

그 밖에:
- 저장 파일: `C:\Users\PAUL SHIN\AppData\Roaming\Godot\app_userdata\택배 방치형\save.json`
  (`saved_at_utc`는 세계 표준시. 손으로 3시간 전으로 바꾸면 꺼둔 동안 수익 확인 가능)
- 설치된 버전 문서 뽑기 (규칙 7): `<GODOT_CONSOLE> --headless --doctool <빈 폴더>`
  → `<빈 폴더>/doc/classes/클래스이름.xml` 에서 함수·설정 이름 확인
- Git Bash에서는 `&` 없이 경로를 따옴표로 감싸서 실행
- 투명 창에서 알아둘 것 (Godot 4.6.3 + Windows에서 직접 확인):
  창 전체 클릭 통과(`Window.mouse_passthrough`)는 다른 프로그램으로 클릭이 안 넘어간다.
  `mouse_passthrough_polygon`만 되는데, 다각형 밖은 그려지지도 않는다 → "보이는 것 = 클릭 받는 곳".
  새로 그리는 것이 생기면 `visible_rects()`(main.gd / band.gd)에 넣어야 보인다.
- Godot 좌표와 Windows 좌표는 원점이 다르다 (주 모니터 왼쪽 위가 Windows 0,0)

## 현재 작업
`docs/PROTOTYPE_V0.md` 0~6단계 구현 끝. 플레이 테스트 끝 ("아니오" 1개, 결과는 `docs/IDEAS.md`).
퍼짐 구간 "스페어값 남겨야 강화 가능" 규칙 넣음. 남은 것:
- 5단계 2시간 켜두기 확인 (`tests/soak_desktop.ps1`)
- 플레이 테스트 4번 "거슬림 / 생각한 UI 구조와 다름" → 사용자가 생각한 구조를 듣고 정하기
- 다음 지시서 (사용자는 튜닝(큐브)을 넣고 싶어 함)
