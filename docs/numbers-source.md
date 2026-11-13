# 숫자 출처 기록

숫자 시트: https://claude.ai/artifact/Ho7FwdxNosvznLCEnbHMxV

- `data/balance.json`에 들어간 숫자는 json이 기준. 아직 안 들어간 숫자는 시트가 기준.
- 시트 → json으로 옮길 때마다 아래에 한 줄. 옮긴 뒤로는 json에서만 고치고 시트는 안 고쳐도 된다.
- 지시서를 쓸 때(delivery-dev 1단계) 옮기고, 그 지시서 이름을 같이 적는다.

| 날짜 | 시트 탭 | balance.json 키 | 지시서 | 메모 |
|---|---|---|---|---|
| 2026-11-13 | 강화 단계 (B1, E4:E33) | `engine.base_power`, `engine.power_gain` | PROTOTYPE_V3 | 성공·퍼짐 확률은 이미 json에 있어서 안 옮김 (시트와 다름 → QUESTIONS Q1) |
| 2026-11-13 | 세팅 규칙 (B2, B10, B11) | `setting.lines_by_grade`, `setting.cost_cut_cap`, `setting.engine_guard_cap` | PROTOTYPE_V4 | |
| 2026-11-13 | 세팅 등급업 (B5:C8) | `setting.up_chance`, `setting.ceiling` | PROTOTYPE_V4 | 명장 1.5배(B1)는 v6 |
| 2026-11-13 | 세팅 옵션 수치 (D2:H4, D7:H8, A8) | `setting.options.*.values`, `setting.overboost_seconds`, `setting.overboost_mult` | PROTOTYPE_V4 | 장거리 속도·정비비 감소(터보·타이어)는 v7. 옵션 가중치·돌리기 비용은 시트에 없어 임시값 |
