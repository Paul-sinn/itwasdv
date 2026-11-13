---
name: qa-check
description: "택배 게임(itwasdv) 합친 가지를 확인하는 순서와 보고 형식. 화면 없는 테스트·확인 전부, 계산↔화면 약속 대조, 프로젝트 규칙 위반 찾기, 메이플 용어 노출, 지시서 완료 기준 체크. qa-checker 에이전트가 쓰고, '전부 확인해줘', 'QA 돌려줘', '합친 거 검사' 요청에 사용한다. 버그 원인 찾기(diagnosing-bugs)나 코드 품질 리뷰(code-review)와는 다르다."
---

# 확인 순서

확인할 폴더 `P`(보통 `itwasdv`), 지시서 `docs/PROTOTYPE_Vn.md`, 이전 버전 가지 `prototype-v(N-1)`을 조정자에게서 받는다.

## 1. 화면 없는 테스트·확인

출력은 자르지 말고 파일로 남긴다. 완료 기준을 확인할 줄이 끝부분에 있다는 보장이 없다.

```bash
G="/c/Users/PAUL SHIN/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.3-stable_win64_console.exe"
P="C:/Users/PAUL SHIN/OneDrive/바탕 화면/itwasdeliverd/itwasdv"
L=$(mktemp -d)   # 기록 폴더. 프로젝트 안에 두지 않는다 (Godot가 가져감)
run() { timeout 600 "$G" --headless --path "$P" "$@" > "$L/$(basename "${@: -1}" .gd).log" 2>&1; echo "$(basename "${@: -1}") exit=$?"; }
run -s tests/run_tests.gd
run --fixed-fps 60 -s tests/check_town_hour.gd   # 게임 시간을 빨리 돌리는 확인만 --fixed-fps 60
run -s tests/check_garage.gd                      # 나머지 check_*.gd도 같은 방식
grep -nE '\[실패\]|실패:|SCRIPT ERROR|Parse Error' "$L"/*.log   # 실패 줄 찾기
```

- 돌릴 것: `tests/run_tests.gd`와 `tests/check_*.gd` 전부(화면 없이 돌고 창을 안 건드림. 새 버전이 더한 것 포함).
  뺄 것: `check_desktop.gd`(진짜 창용 `.ps1`이 부름), `*.ps1`, `shot_screens.gd`, `soak_*` → "눈으로 볼 것"에 적는다.
- **통과 = 종료 코드 0 + 실패 줄 grep 0줄.** 마지막 요약 문구는 스크립트마다 다르다("테스트 N개 중", "확인 N개 중", "전부 통과").
  근거로 그 요약 줄을 옮긴다.
- 일부러 깨진 입력을 넣는 확인(예: `check_save`의 깨진 저장 파일)은 `WARNING`과 스택 줄을 찍는다. 종료 코드가 0이고 실패 줄이 없으면 정상이다.
- 시간 초과(종료 코드 124)면 한 번 더 돌리고, 또 그러면 "확인 못 함"으로 적는다.
- 실패하면 그 로그에서 실패 줄 앞뒤 10줄을 보고에 붙인다.

## 2. 약속 대조

1. **약속 → 코드**: 지시서 "코드 약속"의 함수·변수·상수마다 `scripts/core/`에 같은 이름·인자 개수로 있는지 본다.
2. **코드 → 약속**: 화면이 어떤 변수 이름으로 부르는지는 제각각이라, 함수 이름 쪽에서 거꾸로 찾는다.
   ```bash
   cd "$P"
   # 이번 버전에 core에 새로 생긴 함수 이름
   git diff prototype-v(N-1) -- scripts/core | grep -oE '^\+\s*(static )?func [a-z_0-9]+' | awk '{print $NF}' | sort -u
   ```
   그중 약속에 없는 이름마다 `grep -rn "\.<이름>(" scripts/ui scenes`. 화면이 부르면 실패다.
   책임은 **지시서**로 적는다: 코드는 맞게 돌 수 있지만 약속에 없어서 다른 쪽이 모르고 바꿀 수 있다. 조정자가 약속에 올릴지 정한다.
   화면에서만 쓰지 않는 새 함수(테스트용 등)는 보고만 한다.

## 3. 규칙 위반

```bash
cd "$P"
# 결과를 가르는 굴리기는 enhance.gd / tune.gd(또는 지시서가 정한 파일)에만
grep -rnE '\brandi\(|\brandf\(\)|random01\(' scripts | grep -vE 'scripts/core/(enhance|tune)\.gd'
# 계산 코드는 노드 없이
grep -rnE 'extends (Node|Control|Node2D|CanvasItem)|get_node|get_tree|preload\("res://scripts/ui' scripts/core
```

- 출력이 있으면 위반 후보다. 화면의 연출용 `randf_range`는 위반이 아니다.
- 숫자 직접 쓰기(규칙 1)는 기계로 가를 수 없어서 통과/실패 대신 **후보 목록**으로 보고한다.
  ```bash
  # 새로 생긴 줄에서 주석·글자를 지우고 0·1·2가 아닌 숫자만 (feel.gd는 연출 숫자 모음이라 뺌)
  git diff -U0 prototype-v(N-1) -- scripts/core scripts/ui ':!scripts/ui/feel.gd' | grep -E '^\+[^+]' \
    | sed -E 's/#.*$//; s/"[^"]*"//g' | grep -E '(^|[^a-zA-Z_0-9.])([0-9]*\.[0-9]*[1-9][0-9]*|[3-9]|[1-9][0-9]+)([^a-zA-Z_0-9]|$)'
  ```
  나온 줄 가운데 화면 간격·크기·위치(연출), 개수 상수, 비트 연산은 빼고, 확률·가격·수익·시간 배수로 보이는 것만 `파일:줄 값`으로 적는다.

## 4. 메이플 용어 노출

```bash
grep -rnE '스타포스|메이플|큐브|찬스타임|레전드리|유니크|썬데이|★' scripts/ui data scenes
```

화면에 보이는 글자에 나오면 "용어" 항목으로 보고한다(`docs/GAME_PLAN.md` 5장). 주석·변수 이름은 보고만 하고 실패로 세지 않는다.
지시서가 아직 바꾸지 않기로 정한 용어는 "알려진 것"으로 적는다.

## 5. 지시서 완료 기준

지시서 "작업 순서와 담당"의 완료 기준을 한 줄씩 표로 옮기고, 근거 줄을 1의 로그에서 grep으로 찾아 붙인다
(예: 기준이 "터보 등급마다 1% 안쪽"이면 `grep -n '터보' "$L"/check_town_hour.log`).
근거 줄을 못 찾으면 "확인 못 함"으로 적는다. 스크립트 전체가 통과했다는 것만으로 개별 기준을 통과라고 쓰지 않는다.

## 보고 형식

```
## QA 결과: prototype-vN @ <커밋 해시>
요약: 통과 a / 실패 b / 확인 못 함 c

| 항목 | 결과 | 근거 | 책임 | 다시 돌릴 명령 |
|---|---|---|---|---|
| run_tests | 통과 | "테스트 72개 중 72개 통과" exit=0 | - | ... |
| 약속: Tune.cost | 실패 | 약속은 (b, grade), 코드는 (b) | 계산 | ... |

눈으로 볼 것: (명령과 무엇을 볼지)
용어: (파일:줄 글자)
```
