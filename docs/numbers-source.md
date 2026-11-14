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
| 2026-11-13 | 경험치 얻는 법 (B2, B7) | `driver.xp_per_parcel`, `driver.star_milestone_xp` | PROTOTYPE_V5 | 시내·장거리·주간 목표 경험치는 v6~v7 |
| 2026-11-13 | 레벨 곡선 (B1:B4) | `driver.base_xp`, `driver.exponent`, `driver.points_per_level`, `driver.bonus_points_every_10` | PROTOTYPE_V5 | |
| 2026-11-13 | 오프라인 (C2:C9) | `depot.warehouse_hours`, `depot.night_rates` | PROTOTYPE_V5 | `offline.cap_hours` 8, `offline.rate` 0.5를 대신함 (시작 4시간·50%). 가격은 시트에 없어 임시값 |
| 2026-11-13 | 강화 단계 (스냅샷 1번, 시트 버전 22) | `engine.success`, `engine.destroy` | PROTOTYPE_V6_BAL | Q1. `engine.power_gain`은 이미 같음 (확인만). 실패 = 모든 단계 단계 유지 |
| 2026-11-13 | 세팅 옵션 수치 (스냅샷 5번) | `setting.options.fuel_cut.values`, `setting.options.overboost.values`, `trip.fuel_rate` | PROTOTYPE_V6_BAL | Q7-3. 기름값 10% → 20%. `setting.overboost_seconds` 지움 (오버부스트 = 걸린 바퀴 내내 운전 속도 2배) |
| 2026-11-13 | 세팅 규칙 (스냅샷 3번) | `setting.options.speed.weight` | PROTOTYPE_V6_BAL | Q7-3 (다). 6 → 10 |
| 2026-11-13 | 시트에 없음 (사용자 답 Q7-1) | `setting.roll_cost` | PROTOTYPE_V6_BAL | 스포츠 160만, 레이싱 600만 |
| 2026-11-13 | 레벨 곡선 (스냅샷 7번) | `driver.exponent` | PROTOTYPE_V6_BAL | Q14-1. 1.2 → 1.33 |
| 2026-11-13 | 시트에 없음 (사용자 답 Q14-3) | `quests` star_15·level_20·setting_racing·star_18의 `money` | PROTOTYPE_V6_BAL | 100만·100만·100만·150만 |
| 2026-11-13 | 시트에 없음 (시뮬로 정함, Q14-2 (다) 기준) | `depot.warehouse_prices` Lv2·Lv3, `depot.night_prices` | PROTOTYPE_V6_BAL | 창고 200만·300만 (Lv4 4000만 그대로), 야간팀 150만·220만·250만. tune_sim 가볍게: 본전(켜 둔 시간) 3.5~4.8시간, 2~4일째에 다 삼 |
| 2026-11-13 | 기사 능력치 출시 5개 (스냅샷 6번) | `abilities.unload/kind/nego/knowhow/mech` 의 `per_point`, `max_points` | PROTOTYPE_V5B | 1%×30, 0.5%×30, 1%×20, 2.5%×20, 5%×20 |
| 2026-11-13 | 시트에 없음 (임시 시작값, 조율자 → QUESTIONS Q18) | `trip.tip_base_chance`, `trip.tip_rate` | PROTOTYPE_V5B | 2%, 팁 = 단가 × 1.0 |
| 2026-11-13 | 수입원 (스냅샷 11번), 강화 단계 열리는 배송 (1번) | `special.large/vip` 의 `unlock_star`, `pay_mult` | PROTOTYPE_V6B | 대형 +15 ×3, VIP +18 ×5 (초안) |
| 2026-11-13 | 시트에 없음 (임시 시작값, 조율자 → QUESTIONS Q20) | `special.large.share`, `special.vip.share`, `rush.ring_seconds`, `rush.parcels`, `weekly.target_parcels` | PROTOTYPE_V6B | 10%, 5%, 30초, 20건, 30000건 |
| 2026-11-13 | 기획서 16.6 / 4.12 (Q15 답) | `rush.min_minutes`, `rush.max_minutes`, `rush.pay_mult` | PROTOTYPE_V6B | 30~60분, ×2 |
| 2026-11-13 | 경험치 얻는 법 (스냅샷 7번), 명장 보험 쿠폰 (9번) | `weekly.xp`, `weekly.coupons` | PROTOTYPE_V6B | 2000, 1장 |
| 2026-11-13 | 명장 방문일 (스냅샷 9번), 기획서 2장·16.1 (Q15 답) | `master.unlock_star`, `master.insure_fee_mult`, `master.bonuses.*` | PROTOTYPE_V6B | +10에 열림, 보험 = 비용 × 2, 보너스 7개 (퍼짐 −30%, 강화 비용 −20%, 세팅 등급업 ×1.5, 성공 ×1.2, 드랍 ×2, 세팅 비용 −20%, 2단계 10%. 초안) |
| 2026-11-13 | 회사 단계 & 세금 (스냅샷 10번), 지출 (12번), 경험치 얻는 법 (7번) | `company.stages`, `company.tax_rates`, `company.staff_share`, `company.city_xp_per_parcel` | PROTOTYPE_V7A | 세율 0/3/5/7/10%, 직원 몫 30%, 시내 배송 경험치 15 |
| 2026-11-13 | 세팅 옵션 수치 (스냅샷 5번), 출시 세팅 부품 (2번) | `setting.options.maint_cut.values`, `setting.parts.tire` | PROTOTYPE_V7A | 정비비 감소 3/6/9/13/18%, 타이어·휠 = 대리점에 열림 (`"unlock": "agency"`) |
| 2026-11-13 | 시트에 없음 (임시 시작값, 조율자 → QUESTIONS Q23) | `company.agency_price`, `company.helper_prices`, `company.rivals`, `setting.options.maint_cut.weight`, `quests` found_agency·first_helper·tire_first | PROTOTYPE_V7A | 5억, 500만·2,000만, 800만 × 약 1.16배씩 10곳(→ 3,040만), 가중치 10, 보상 1000·500만 / 800·300만 / 600·200만 |
| 2026-11-14 | 사용자 허락 (QUESTIONS Q17·Q21·Q25 답), 세팅 옵션 수치 (스냅샷 5번) | `engine.cost_base`, `engine.spare_drop_chance`, `setting.options.fuel_cut.values`, `setting.options.cargo.values`, `weekly.target_parcels`, `company.agency_price`, `company.helper_prices`, `company.rivals` | PROTOTYPE_V7_BAL | 65,000, 0.000006, 기름값 절감 7/12/20/30/45%, 적재량 3.5/5.5/8.5/14/21% (시작값, 시뮬로 다시), 주간 6만 건, 창업 3억, 보조 트럭 500만·800만, 라이벌 600만~1,550만 (시내 단가 뒤 시뮬로 다시) |
| 2026-11-14 | 세팅 옵션 수치 (스냅샷 5번, Q25-5) | `setting.fuel_cut_cap`, `setting.maint_cut_cap` (`setting.cost_cut_cap` 지움), `setting.options.maint_cut.values` | PROTOTYPE_V7_BAL | 기름값·정비비 상한 각자 60%. 정비비 감소 15/30/45/55/60% (임시: 시뮬 제안 → 허락 뒤 바꿈) |
| 2026-11-14 | 이벤트 (스냅샷 9번, 답 3) | `master.bonuses` (3개만, `master.insure_fee_mult` 지움), `visitors.*`, `rush.ring_seconds`, `rush.parcels`, `weekly.reward_hours` (`weekly.coupons` 지움) | PROTOTYPE_V7_BAL | 명장 퍼짐 −30%·성공 ×1.2·2단계 10%, 특별 NPC 21~28일, 보험료 = 비용 × 퍼짐 × 10, 제휴 할인 50%, 복구 보험·고급 스페어 +17, 마술사 ×2, 부품상 1개, 급송 300초·50건, 주간 보상 = 하루치(24시간) 수입 |
| 2026-11-14 | 시트에 없음 (지시서 "옮길 숫자" 임시값, 사용자: "배수는 밸런스 담당이 제안") | `routes.town`, `routes.city` | PROTOTYPE_V7_BAL | 동네 1·1·1, 시내 단가 ×1.5·도로 ×0.5·한 바퀴 집 수(싣는 시간도) ×1.5 (임시: C3 시뮬 제안 → 허락 뒤 바꿈) |
| 2026-11-14 | 시트에 없음 (C3 시뮬 제안 중 조율자가 고른 것, `_reports/balance_v7bal.md`) | `routes.city`, `setting.options.maint_cut.values`, `company.rivals` | PROTOTYPE_V7_BAL | 시내 단가 ×1.2·도로 ×0.4·집 수(싣는 시간도) ×2, 정비비 감소 순정 15 → 18% (나머지 30/45/55/60%), 라이벌 2,300만 ~ 3,600만 (×1.051씩. 10위 = 가볍게 창업한 날 매출, 1위 = 창업 자금 50% 가볍게 유저 80.8%가 90일 안). 보조 트럭·주간 보상·오버부스트·기름값·정비비 비율은 그대로 (Q27) |
| 2026-11-14 | 출시 세팅 부품 (스냅샷 2번), 세팅 옵션 수치 (5번), 경험치 얻는 법 (7번), 사용자 답 Q24-1 | `routes.long`, `setting.parts.turbo`, `setting.options.long_speed` | PROTOTYPE_V7B | 장거리 도로 ×5·집 수 ×1·경험치 30·+10, 단가 ×4는 **임시** (C3 시뮬 제안 → 허락 뒤 바꿈). 터보 = 대리점 + +10, 장거리 속도 5/8/12/20/30% (가중치 10) |
| 2026-11-14 | 기업 계약 (스냅샷 11번), 사용자 답 Q24-2 | `contracts.reputation`, `contracts.sales_share`, `quests` long_first·turbo_first·contract_first | PROTOTYPE_V7B | 계약 = 맺을 때 순위 매출 × 5 / 7 / 10%, 평판 기준 15만·45만·90만은 **임시** (C3 시뮬 제안 → 허락 뒤 바꿈). 퀘스트 보상은 창업 뒤 3개와 같은 크기 (계산 담당): 장거리 800·300만, 터보 600·200만, 계약 1000·500만 |
| 2026-11-14 | 시트에 없음 (C3 시뮬 제안 중 조율자가 고른 것, `_reports/balance_v7b.md`) | `routes.long.price_mult`, `contracts.reputation`, `company.rivals` | PROTOTYPE_V7B | 장거리 단가 ×4 → ×7 (+20~+22에 속도·터보 세팅 트럭부터 장거리), 평판 기준 20만·170만·360만 (가볍게 만렙 뒤 1 / 3 / 6주), 라이벌 2,300만 ~ 4,000만 (×1.063씩. 1위 = 가볍게 창업 유저 80%가 90일 안). `setting.options.long_speed.values`는 시트 5/8/12/20/30% 그대로 (제안 4/6.5/10.5/17/26%는 사용자 답 기다림) |
