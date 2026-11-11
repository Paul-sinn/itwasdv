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

PowerShell (사용자 터미널): 어느 폴더에서든 그대로 복사해서 붙여 넣기
```powershell
# 테스트 (전부 통과면 마지막 줄 "테스트 N개 중 N개 통과")
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe" --headless --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" -s tests/run_tests.gd

# 편집기 열기
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv" --editor

# 게임 실행 (메인 씬은 2단계에서 정함)
& "C:\Users\PAUL SHIN\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64.exe" --path "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv"

# 시뮬
python "C:\Users\PAUL SHIN\OneDrive\바탕 화면\itwasdeliverd\itwasdv\tools\delivery_sim.py"
```

그 밖에:
- 설치된 버전 문서 뽑기 (규칙 7): `<GODOT_CONSOLE> --headless --doctool <빈 폴더>`
  → `<빈 폴더>/doc/classes/클래스이름.xml` 에서 함수·설정 이름 확인
- Git Bash에서는 `&` 없이 경로를 따옴표로 감싸서 실행

## 현재 작업
`docs/PROTOTYPE_V0.md`를 순서대로. 1단계(계산 코드) 끝남 → 다음은 2단계(띠 화면).
