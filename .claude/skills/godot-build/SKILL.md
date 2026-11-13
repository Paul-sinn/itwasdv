---
name: godot-build
description: "택배 게임(itwasdv, Godot 4.6.3) 코드를 지시서대로 만드는 방법. 계산 담당(core-dev)과 화면 담당(ui-dev)이 각자 작업 폴더에서 따르는 규칙, 확인 방법, 완료 보고 형식. 지시서(docs/PROTOTYPE_Vn.md)의 단계를 구현할 때 사용한다. 지시서를 새로 쓰는 일은 spec-writing, 숫자 맞추기는 econ-sim이 맡는다."
---

# Godot 구현 방법

`CLAUDE.md`의 규칙 1~8과 "명령"·"투명 창에서 알아둘 것"을 먼저 읽는다. 여기에는 거기 없는 담당별 방법만 적는다.

## 공통

**작업 폴더.** 조정자가 준 폴더(예: `itwasdv-window`, `itwasdv-town`)에서만 일한다. 같은 저장소를 공유하는 git 작업 폴더라서
다른 폴더를 고치면 다른 에이전트의 가지가 바뀐다. git은 `git -C "<작업 폴더>"`로 부른다.

**명령.** `CLAUDE.md`의 Godot 명령에서 `--path` 뒤 폴더만 자기 작업 폴더로 바꾼다. Bash에서는:

```bash
G="/c/Users/PAUL SHIN/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.3-stable_win64_console.exe"
P="C:/Users/PAUL SHIN/OneDrive/바탕 화면/itwasdeliverd/<작업 폴더>"
"$G" --headless --path "$P" -s tests/run_tests.gd        # 마지막 줄 "테스트 N개 중 N개 통과", 종료 코드 0
```

**Godot 함수 이름은 기억으로 쓰지 않는다** (규칙 7). 4.x 버전마다 이름이 바뀐 것이 많다.
`"$G" --headless --doctool <빈 폴더>`로 뽑은 `doc/classes/<클래스>.xml`에서 확인한다. 빈 폴더는 작업 폴더 밖에 만든다.

**단계마다 커밋.** 커밋 메시지는 `vN k단계: <한 일>` 꼴의 쉬운 한국어.

**아이디어는 `docs/IDEAS.md`에 쓰지 않고 완료 보고에 적는다.** 두 담당이 같은 파일을 고치면 합칠 때 충돌한다. 조정자가 모아서 적는다.

**진짜 창이 뜨는 것은 돌리지 않는다**: `tests/*.ps1`, `tests/shot_screens.gd`, `--headless` 없는 실행.
화면이 깜빡이거나 덮여서 사용자를 방해한다. 필요하면 완료 보고의 "눈으로 볼 것"에 명령과 함께 적는다.

## 계산 담당 (`scripts/core/`, `data/balance.json`, `tests/test_*.gd`, `tools/`)

- 모든 파일은 `extends RefCounted`, 노드·씬·`scripts/ui/`를 참조하지 않는다. 화면 없이 테스트하고, 나중에 서버로 옮길 수 있어야 한다.
- 굴리기(성공·실패·퍼짐, 등급업, 대박 등 결과가 확률로 갈리는 것)는 그 시스템 전용 파일 한 곳에만 둔다
  (강화 → `enhance.gd`, 튜닝 → `tune.gd`). 새 시스템이면 지시서가 정한 파일에 둔다.
  난수 생성기는 밖에서 받고, 0~1 난수는 `Enhance.random01(rng)`를 쓴다.
- 새 숫자는 `balance.json`에 넣고 `balance.gd`에서 읽기 + 검사(범위, 길이, 등급이 오를수록 줄지 않음 등)를 같이 만든다.
  잘못된 숫자가 들어오면 게임이 조용히 틀리는 것보다 시작할 때 막히는 편이 찾기 쉽다.
- 저장 형식을 바꾸면 형식 번호를 올리고, 예전 형식 파일도 읽히는지 테스트한다. 모르는 키는 버리고 범위 밖 값은 자른다.
  사용자 저장 파일이 깨지면 되돌릴 방법이 없다.
- 테스트는 `tests/test_<이름>.gd`(`test_base.gd` 상속)에 만들고 `tests/run_tests.gd`의 `TEST_FILES`에 넣는다.
  확률은 seed 고정 10만 번 굴려 1%p 안쪽인지 본다.
- 돈 계산식이 바뀌면 `tools/`의 시뮬도 같은 식으로 고친다. 시뮬과 게임이 다르면 밸런스 결과를 믿을 수 없다.
- 완료 기준: `run_tests.gd` 전부 통과 + 기존 `tests/check_*.gd`(화면 없이) 전부 통과.

## 화면 담당 (`scripts/ui/`, `scenes/`, `tests/check_*.gd`)

- 계산은 지시서 "코드 약속" 함수만 부른다. 약속에 없는 값이 필요하면 직접 계산하지 말고 조정자에게 함수를 요청한다.
- 연출 숫자(시간, 크기, 색, 흔들림)는 `scripts/ui/feel.gd` 상수로. 화면 흔들림처럼 결과와 상관없는 연출용 `randf_range`는 써도 된다.
- 작은 화면에 새로 그리는 것은 `visible_rects()`(main.gd / town.gd)에 넣는다. 안 넣으면 클릭 통과 다각형 밖이라 아예 안 보인다.
- 화면에 보이는 글자는 `docs/GAME_PLAN.md` 5장 용어를 따른다(메이플 이름 금지). 지시서가 다르게 정했으면 지시서를 따른다.
- 확인은 `tests/check_<이름>.gd`로 화면 없이 진짜 클릭(입력 이벤트)을 보내서 한다. 노드 값을 직접 바꾸는 확인은 클릭 경로의 버그를 못 잡는다.
  확인 스크립트는 main을 만들기 전에 `ScreenMode.settings_path`와 저장 경로를 시험용으로 바꾼다(진짜 사용자 파일 보호).
- 계산 담당이 끝나기 전에는 조정자가 넣어 둔 껍데기 함수로 만든다. "vN-core 합쳐라"를 받으면 `git merge vN-core` 후 확인을 다시 돌린다.
- 완료 기준: 새 `check_*.gd` + 기존 `check_garage` / `check_save` / `check_switch` / `check_town_hour`(화면 없이) 전부 통과.

## 완료 보고 형식

```
## vN k단계 완료 (계산 | 화면)
- 만든 것: (파일별 한 줄)
- 커밋: <해시> <메시지>
- 확인: <명령> → <마지막 줄 그대로> (종료 코드)
- 약속과 달라진 점: 없음 | (무엇을 왜)
- 질문: 없음 | (지시서에서 애매했던 것)
- 아이디어: 없음 | (한 줄씩)
- 눈으로 볼 것: 없음 | (무엇을, 어떤 명령으로)
```
