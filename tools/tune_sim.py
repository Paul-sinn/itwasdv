"""
택배 방치형 - 경제 시뮬레이터 (v5 기사 레벨·퀘스트·창고·야간팀 + v6-bal 규칙 + v5b 능력치·팁 + v6b 대형·VIP·급송·주간 목표·명장
+ v7a 대리점·보조 트럭·직원 몫·세금·타이어·순위까지, 판정용)

흉내 내는 것 (v7a 게임에 있는 것만):
  트럭 1대, 엔진 강화(성공 / 실패=유지 / 퍼짐 → 스페어 1개 쓰고 +15), 강화 비용 고정표,
  스페어 엔진(고정가 구매 + 배송마다 낮은 확률 드랍, 꺼둔 동안은 평균값),
  한 바퀴 수입(출력 → 속도 → 한 바퀴 초), 기름값·정비비,
  꺼둔 동안(창고 레벨 시간 × 야간팀 레벨 비율, 3분 미만 무시),
  세팅 돌리기(적재함·ECU: 등급업·천장·옵션 뽑기·메모리얼 고르기, 이동 속도·적재량·기름값 절감·엔진 보호·오버부스트),
  기사 레벨(켜 둔 동안 배송 경험치 + 강화 첫 달성 보너스 + 퀘스트 보상, 만렙 뒤 평판), 퀘스트 22개(보상 돈·경험치),
  창고 확장·야간 배송팀 사기.
  팁(배송마다 기본 확률 + 친절, 팁 = 협상 단가 × tip_rate), 기사 능력치 5개(상하차·친절·협상·노하우·정비 지식, 트럭 0에만).
  v6b: 대형·VIP 배송(몫·배수 평균), 급송 요청 전화(받는 비율), 주간 배송 목표·보험 쿠폰, 명장 방문일(요일·그 주 보너스 7개)·보험.
  v7a: 대리점 창업(돈을 모아 삼), 보조 트럭 2대(직원 몫 30%), 세금(대리점 3%), 타이어·휠(정비비 감소, 대리점에 열림),
  창고 Lv4(대리점부터), 시내 경험치(내 트럭 배송만), 순위표(모든 트럭 시간당 매출 vs 라이벌).
  장거리·터보·기업 계약은 아직 없음 (v7b).

계산식은 docs/PROTOTYPE_V3~V5.md "계산식" + PROTOTYPE_V6_BAL.md "바뀌는 규칙" + PROTOTYPE_V5B.md "정한 것" =
scripts/core/trip.gd, economy.gd, enhance.gd, setting.gd, driver.gd, ability.gd, depot.gd, quest.gd, company.gd 와 같다.
  반올림은 Godot roundi와 같게 (0.5는 0에서 먼 쪽. 파이썬 round()는 짝수 쪽이라 안 씀)
  적재량은 평균값 그대로 (게임 Trip.cargo: 21.6처럼 소수. 정수에 1e-9 안쪽이면 정수로).
    게임은 바퀴마다 소수점을 굴려 21 또는 22건을 싣지만 평균은 같아서, 시뮬은 평균으로 센다 (게임의 시간당 수입·꺼둔 동안과 같음)
  오버부스트: 걸린 바퀴는 바퀴 내내 운전 속도 overboost_mult배 (= 달리는 초 ÷ overboost_mult). 시뮬은 평균 한 바퀴 초로
    (게임의 "시간당 수입"·꺼둔 동안과 같음)
  팁: 게임은 배송마다 굴리지만 시뮬은 평균값 (배송 1건 돈 + 팁 확률 × 팁). 게임 Trip.hourly_income도 같은 평균
  능력치 (ab = { id: 포인트 × per_point }): 상하차 → 정차 × (1 − 값), 협상 → 단가 = round(단가 × (1 + 값)),
    친절 → 팁 확률 + 값, 노하우 → 꺼둔 동안 경험치 floor(배송 × xp_per_parcel × 값), 정비 지식 → 드랍 확률 × (1 + 값)
  대형·VIP (Trip._kind_shares): VIP 몫(+18부터) → 아니면 대형 몫(+15부터). 단가 × 배수 = round(협상 단가 × 배수) 기준으로 돈·팁.
    게임은 배송마다 굴리지만 시뮬은 평균 (게임 시간당 수입·꺼둔 동안과 같음)
  명장 보너스 (enhance·economy·setting·trip): 퍼짐 × (1 − destroy_cut), 강화 비용 round(× (1 − 할인)), 성공 × success_mult
    (성공 + 퍼짐 ≤ 1로 자름), 세팅 등급업 × setting_up_mult (최대 1), 세팅 비용 round(× (1 − 할인)), 드랍 × spare_mult(켜 둔 동안만),
    성공 때 double_step 확률로 한 단계 더. 보험: 방문 중 추가 요금 = 비용 × insure_fee_mult (쿠폰 안 씀), 아니면 쿠폰 1장. 퍼짐 → 실패
  직원 몫·세금 (Trip._split): 번 돈(배송 1건 돈·팁마다, 꺼둔 동안은 트럭마다 floor한 합) → 직원 몫 round(× 30%, 보조 트럭만),
    세금 round(× 세율), 나머지가 내 돈. 켜 둔 동안은 평균 (종류 몫 × (뗀 1건 돈 + 팁 확률 × 뗀 팁) = 게임 Trip.hourly_net)
게임 숫자는 전부 data/balance.json (게임과 같은 파일)의 trip / engine / offline / setting / driver / abilities / depot / quests / company.

실행:  python -I -X utf8 tools/tune_sim.py                   가볍게(2.5시간)·열심히(8시간) 둘 다, 세팅 있음
                                                             (+ 세팅 없음 비교 줄, v4 숫자 비교 줄)
       python -I -X utf8 tools/tune_sim.py --hours 2.5      그 시간만
       python -I -X utf8 tools/tune_sim.py --no-setting     세팅 안 돌림 (v3와 비교용)
       python -I -X utf8 tools/tune_sim.py --build speed    능력치 빌드 (money 돈벌이(기본) / speed 스피드 / relax 쉬엄쉬엄 /
                                                             enhance 강화 / none 안 찍음). 아래 "능력치 규칙"
       python -I -X utf8 tools/tune_sim.py --style pool     +18부터 강화를 명장 방문일(보험)·쿠폰(보험)에 몰아서 (기본 normal = 안 몰아서,
                                                             보험 안 씀). 아래 "명장 규칙"
       python -I -X utf8 tools/tune_sim.py --rush-accept 0.5   급송 전화를 받는 비율 (기본 0.5)
       python -I -X utf8 tools/tune_sim.py --save 0.5       창업 전 강화 몫 돈 중 창업 자금으로 모으는 비율 (기본 0.5, 0 = 창업 안 함)
       python -I -X utf8 tools/tune_sim.py --table          단계별 출력·한 바퀴·시간당 수입·강화 비용 표 (세팅·능력치 없음)
                                                             + 능력치 하나만 최대일 때 시간당 수입 (+10, +18)
                                                             + v7a: 게임 테스트(test_company) 대조 값, 트럭 3대 +25·전부 최대 매출,
                                                               정비비 감소 한 줄의 가치
       (옵션: --players 1000  --seed 7)
       -X utf8: 막대그래프 글자(█) 때문에 cp949 콘솔에서 필요
판정: "30일" 줄의 지금 단계 중앙값 (기획서 16.7). 최고 도달 단계는 참고만.
v4 숫자 비교: 같은 유저를 꺼둔 동안 V4_OFFLINE(8시간 × 50%) 고정, 창고·야간팀·퀘스트 없이(= v4 게임) 돌린 결과.

플레이어 가정 (시뮬 전용. 게임 숫자 아님):
  - 하루 HOURS시간 켜 둠, 나머지(24 − HOURS)는 꺼 둠 → 다음 날 켤 때 꺼둔 동안 돈·스페어·배송 수를 받는다
    (게임 Trip.apply_offline과 같음: min(꺼둔 시간, 창고 시간) × 야간팀 비율, 스페어는 소수 나머지를 이어 감.
     3분 미만 무시는 하루에 한 번 길게 꺼 두는 이 시뮬에서는 --hours 24 근처가 아니면 영향 없음.
     꺼둔 동안 경험치는 노하우만큼. 만렙 시각은 그날 켜 둔 시간이 끝난 때로 잡음)
  - 켜 둔 동안 돈은 배송 1건마다 들어온다. 배송은 평균 한 바퀴 속도(N ÷ 평균 한 바퀴 초)로 고르게 나온다고 본다
    (게임은 바퀴 안에서 싣는 시간·집마다 시각이 다르고 오버부스트는 바퀴마다 굴림. 1시간 합계 차이는 2% 안쪽 = C1 테스트)
  - 강화 규칙 ("버는 족족 강화"):
      돈이 생기면 CHECK_HOURS(30분) 안에 화면을 보고, 누를 수 있는 동안 계속 강화를 누른다.
      살펴볼 때 순서: 퀘스트 확인 → 퀘스트가 시키는 사기 → 세팅 → 창고·야간팀 → 강화 (끝낸 퀘스트가 생기면 한 번 더)
      퍼질 수 있는 단계(+18~)인데 스페어가 0개면 그때 스페어를 1개 산다 (미리 쌓아 두지 않음). +30이면 그만.
  - 세팅 규칙 (하나):
      번 돈(켜 둔 동안 + 꺼둔 동안)의 SETTING_SHARE(20%)는 세팅 몫으로 따로 모으고, 나머지로 강화·스페어를 산다.
      세팅 몫이 돌리기 비용 이상이면 돌린다. 돌릴 부품 = 열린 부품 중 등급이 가장 낮은 것 (같으면 json 순서: 적재함 먼저).
      고르기: 등급이 올랐으면 새 것 (사람은 등급업을 거의 안 버림). 아니면 새 상태의 값 ≥ 예전 상태의 값이면 새 것.
        값 = 평균 시간당 수입 (이동 속도·적재량·기름값 절감·오버부스트가 다 들어감)
             × (1 + min(엔진 보호 합, 상한))  ← 퍼질 수 있는 단계(+18~)에서만. 엔진 보호 10% = 수입 10%로 친다
      (가진 돈의 몇 %를 그때그때 쓰는 규칙은 강화 비용이 큰 뒤에 켤 때마다 모은 돈을 깎아 먹어서 안 씀)
  - 창고·야간팀 규칙 (하나):
      살펴볼 때 강화보다 먼저, 다음 레벨 가격이 "지금 하루 수입(켜 둔 시간 + 꺼둔 동안, 지금 창고·야간팀 레벨)"의
      DEPOT_DAYS(1)배 이하이고 강화 몫 돈이 가격 이상이면 산다. 창고 → 야간팀 순서로, 살 수 있는 동안 계속.
      창고는 대리점 전 최고 레벨(warehouse_max_level_solo)까지만. 기다릴 시간 계산에도 넣는다(+30이어도 사러 옴)
  - 퀘스트: 게임은 매 프레임 Quest.check(한 번에 하나)라 사실상 바로 끝남 → 시뮬은 살펴볼 때·배송 뒤에 찬 것을 전부 끝낸다.
      보상 돈은 번 돈처럼 세팅 몫·강화 몫으로 나눈다.
      퀘스트가 시키는 사기 (사람은 다음 할 일을 보고 산다): 지금 차례 퀘스트가 사는 퀘스트(spares_bought = 스페어,
      warehouse / night = 창고·야간팀 다음 레벨)이고 강화 몫 돈이 가격 이상이면 강화보다 먼저 그것을 산다.
      기다릴 시간 계산에도 넣는다. 그 밖의 퀘스트(강화 단계·세팅 등급 등)는 일부러 하지 않는다
      (세팅 없음 유저는 first_setting에서 멈춘다)
  - 기사 레벨: 켜 둔 배송마다 xp_per_parcel, 강화 성공으로 star_milestones 이상에 처음 닿으면 보너스, 퀘스트 보상 경험치.
      만렙 시각은 그 구간 안에서 배송 시각으로 나눠 잡는다 (켜 둔 시간도 같이)
  - 능력치 규칙 (v5b, 지시서 "시뮬"): 레벨업으로 포인트를 받으면 바로 찍는다. 빌드마다 순서대로 최대까지
      (BUILDS: 주 능력치 → 협상 → 상하차. 스피드는 주 능력치가 상하차라 남는 9포인트를 친절에). 초기화는 안 함
  - v6b 달력: 1일째 = 월요일. 한 주 = 월~일 (주간 목표 진행 0, 그 주 명장 보너스 새로 굴림)
  - 급송 규칙: 켜 둔 동안 평균값으로 센다. 벨 간격 평균 (min + max) ÷ 2분, 받는 비율 RUSH_ACCEPT, 받으면 다음 rush.parcels건
      단가 × rush.pay_mult (그동안 벨 시계가 안 가서 한 주기 = 평균 간격 + 받은 비율 × 급송 건수 ÷ 시간당 배송). 꺼둔 동안은 없음
  - 주간 목표: 켜 둔·꺼둔 배송을 다 셈, 처음 닿으면 쿠폰 + 경험치 (몇 주차 무슨 요일에 채웠나 기록)
  - 명장 규칙: +10 첫 달성에 열림 → 요일은 MASTER_DAY(토요일)로 고름 (처음 고른 것은 이번 주부터). 그날 켜 둔 동안만 그 주 보너스 적용.
      normal = 보험 안 씀 (쿠폰도 안 씀. 보너스만 그날 받음). pool = POOL_FROM(+18)부터 방문일엔 보험(추가 요금)을 걸고 누르고,
      그 밖의 날엔 쿠폰이 있으면 쿠폰 보험으로만 누르고 없으면 돈을 모은다 (스페어는 안 삼)
  - 퍼진 뒤 회복 비용: 퍼진 순간부터 원래 단계로 다시 올라갈 때까지 (내 트럭) 강화·스페어에 쓴 돈을
    "원래 단계에서의 하루 수입(켜 둔 시간 + 꺼둔 동안)"으로 나눈 값. 퍼질 때 쓴 스페어 1개와 세팅 돈, 보조 트럭에 쓴 돈은 안 셈
  - v7a 창업 규칙: 개인 기사인 동안 강화 몫 돈(번 돈 − 세팅 몫)의 SAVE_SHARE(--save)를 창업 자금으로 따로 모은다 (1일째부터).
      자금이 agency_price 이상이면 살펴볼 때 창업하고 남은 자금은 강화 몫으로. 창업 뒤에는 안 모음
  - v7a 보조 트럭 규칙: 대리점이면 살펴볼 때 강화보다 먼저, 강화 몫 돈이 다음 보조 트럭 값 이상이면 산다 (+0, 세팅 없음)
  - v7a 강화 규칙 (트럭 여러 대): 누를 때마다 단계가 가장 낮은 트럭을 누른다 (같으면 내 트럭 먼저) = 돈을 트럭끼리 나눠 강화.
      스페어는 함께 씀. 명장 보너스·보험(pool)은 누르는 트럭 단계로. 판정("30일 지금 단계")은 내 트럭
  - v7a 세팅 규칙 (트럭 여러 대): 열린 (트럭, 부품) 중 등급이 가장 낮은 것 (같으면 트럭 번호 → json 부품 순서). 타이어는 대리점부터
  - v7a 보조 트럭 배송: 켜 둔 동안은 트럭마다 배송 수를 세고(소수 이어 감) 직원 몫·세금 뗀 평균 돈. 스페어 드랍은 평균값을
      spare_drop_carry에 더함 (꺼둔 동안처럼, 다음 꺼둔 동안에 정수로). 경험치 0. 본전 = 산 뒤 켜 둔 동안 번 내 돈이 값에 닿은 켜 둔 시간
  - v7a 순위: 매일 켜 둔 시간이 끝날 때 모든 트럭 시간당 매출(번 돈, 급송 뺌)을 라이벌과 비교. 같거나 넘으면 그 라이벌 위
"""
import argparse
import bisect
import json
import math
import os
import random
import statistics as st

BALANCE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "balance.json")

# ---------- 시뮬 전용 가정 ----------
PLAYER_TYPES = [("가볍게", 2.5), ("열심히", 8.0)]   # 기획서 16.7 판정 기준 유저
TARGETS = {2.5: 18, 8.0: 20}                         # 기획서 "경제 목표" (30일째 지금 단계 중앙값)
CHECK_HOURS = 0.5         # 켜 둔 동안 몇 시간마다 살펴보나
SETTING_SHARE = 0.2       # 번 돈 중 세팅 몫
DEPOT_DAYS = 1.0          # 창고·야간팀: 가격이 하루 수입의 몇 배 이하면 사나
V4_OFFLINE = (8.0, 0.5)   # v4 숫자 비교용: 꺼둔 동안 시간·비율 (v4 balance.json offline.cap_hours, rate)
SIM_DAYS = 90             # 판정은 30일. 그 뒤는 참고 + 후반 퍼짐 회복 비용용
SNAP_DAYS = [1, 3, 7, 14, 30, 60, 90]
JUDGE_DAY = 30
GRADE_DAYS = [30, 90]     # 부품별 등급 분포를 찍는 날
DEPOT_KINDS = [("warehouse", "창고"), ("night", "야간팀")]   # 사는 순서
TABLE_STARS = [0, 10, 18, 30]   # C1 테스트 ①/⑫가 찍는 단계
GRADE_NAMES = ["순정", "스트리트", "스포츠", "레이싱", "프로토타입"]   # 출력용 (게임 글자는 번역 파일)
EFFECTS = ["speed", "cargo", "fuel_cut", "maint_cut", "engine_guard", "overboost"]
ABILITY_STARS = [10, 18]   # 능력치 효과 표 기준 단계 (지시서 v5b "시뮬" ①)
ABILITY_NAMES = {"unload": "상하차", "kind": "친절", "nego": "협상", "knowhow": "노하우", "mech": "정비 지식"}   # 출력용
## 능력치 빌드 (지시서 v5b "예시 빌드"): 이름, 포인트를 찍는 순서 (앞 능력치가 최대가 되면 다음)
BUILDS = {
    "money": ("돈벌이", ["kind", "nego", "unload"]),
    "speed": ("스피드", ["unload", "nego", "kind"]),
    "relax": ("쉬엄쉬엄", ["knowhow", "nego", "unload"]),
    "enhance": ("강화", ["mech", "nego", "unload"]),
    "none": ("능력치 없음", []),
}
DEFAULT_BUILD = "money"
## v6b 명장 유저 두 가지 (지시서 "시뮬")
STYLES = {"normal": "안 몰아서 (보험 안 씀)", "pool": "+18부터 방문일·쿠폰에 몰아서 (보험)"}
DEFAULT_STYLE = "normal"
POOL_FROM = 18            # pool 유저: 이 단계부터 방문일·쿠폰 보험으로만 강화
MASTER_DAY = 5            # 가상 유저가 고르는 명장 요일 (0 = 월 … 5 = 토)
RUSH_ACCEPT = 0.5         # 급송 전화를 받는 비율 (지시서 기본 50%)
SAVE_SHARE = 0.5          # v7a 창업 전: 강화 몫 돈 중 창업 자금으로 모으는 비율 (--save. 0 = 창업 안 함)
WEEK_DAYS = [7 * w for w in range(1, SIM_DAYS // 7 + 1)]   # 주차별 매출 출력용
BONUS_NAMES = {"destroy_cut": "퍼짐 감소", "enhance_discount": "강화 비용 할인", "setting_up_mult": "세팅 등급업 상승",
               "success_mult": "강화 성공 상승", "spare_mult": "스페어 드랍 2배", "setting_discount": "세팅 비용 할인",
               "double_step": "2단계 상승"}   # 출력용


def roundi(x):
    """Godot roundi와 같게 (0.5는 0에서 먼 쪽으로)"""
    if x < 0:
        return -roundi(-x)
    f = math.floor(x)
    return int(f) + (1 if x - f >= 0.5 else 0)


class Bal:
    """balance.json + 게임 계산식 (trip.gd, economy.gd, enhance.gd, setting.gd).
    tot = 세팅 옵션 합 { 옵션 id: 합 } (Setting.total). 세팅 없음 = {}"""

    def __init__(self, path):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        self.version = d.get("version", "?")
        trip, eng, off, st_ = d["trip"], d["engine"], d["offline"], d["setting"]
        self.unit_price = int(trip["unit_price"])
        self.base_cargo = int(trip["base_cargo"])
        self.road = float(trip["road_length"])
        self.load = float(trip["load_seconds"])
        self.stop = float(trip["stop_seconds"])
        self.fuel_rate = float(trip["fuel_rate"])
        self.maint_rate = float(trip["maint_rate"])
        self.tip_base = float(trip["tip_base_chance"])
        self.tip_rate = float(trip["tip_rate"])
        # --- v6b: 대형·VIP, 급송, 주간 목표, 명장 ---
        sp = d["special"]
        self.special = {k: (int(sp[k]["unlock_star"]), float(sp[k]["pay_mult"]), float(sp[k]["share"])) for k in ("large", "vip")}
        ru = d["rush"]
        self.rush_min, self.rush_max = float(ru["min_minutes"]), float(ru["max_minutes"])
        self.rush_parcels, self.rush_mult = int(ru["parcels"]), float(ru["pay_mult"])
        wk = d["weekly"]
        # shortcut: v7-bal json(0.14)에서 쿠폰·명장 날 보험이 없어짐 → 쿠폰 0, 보험 없음으로만 돔. 보험사·마술사·부품상·주간 돈 보상은 C3에서
        self.weekly_target, self.weekly_xp, self.weekly_coupons = int(wk["target_parcels"]), int(wk["xp"]), int(wk.get("coupons", 0))
        ms = d["master"]
        self.master_unlock, self.insure_fee_mult = int(ms["unlock_star"]), ms.get("insure_fee_mult")
        self.bonuses = {k: float(v) for k, v in ms["bonuses"].items()}
        self.bonus_ids = list(self.bonuses.keys())
        # --- abilities (기사 능력치 v5b): id → (per_point, max_points), json 순서 ---
        self.abilities = {k: (float(v["per_point"]), int(v["max_points"])) for k, v in d["abilities"].items()}
        self.max_star = int(eng["max_star"])
        self.base_power = int(eng["base_power"])
        self.power_gain = [int(g) for g in eng["power_gain"]]
        self.success = [float(x) for x in eng["success"]]
        self.destroy = [float(x) for x in eng["destroy"]]
        self.drop_to = int(eng["broken_drop_to"])
        self.cost_base = float(eng["cost_base"])
        self.cost_mult = float(eng["cost_mult"])
        self.spare_price = int(eng["spare_price"])
        self.spare_chance = float(eng["spare_drop_chance"])
        self.ignore_under = float(off["ignore_under_seconds"])
        # --- depot (창고 확장·야간 배송팀). [레벨-1] ---
        dep = d["depot"]
        self.depot_values = {"warehouse": [float(x) for x in dep["warehouse_hours"]],
                             "night": [float(x) for x in dep["night_rates"]]}
        self.depot_prices = {"warehouse": [int(x) for x in dep["warehouse_prices"]],
                             "night": [int(x) for x in dep["night_prices"]]}
        self.depot_buyable = {"warehouse": min(int(dep["warehouse_max_level_solo"]), len(self.depot_values["warehouse"])),
                              "night": len(self.depot_values["night"])}
        self.depot_top = {k: len(v) for k, v in self.depot_values.items()}   # 대리점이면 여기까지 (Depot.buyable_level)
        # --- company (v7a). 단계 0 개인 기사, 1 대리점 ---
        co = d["company"]
        self.stages = list(co["stages"])
        self.tax_rates = [float(x) for x in co["tax_rates"]]
        self.agency_price = int(co["agency_price"])
        self.staff_share = float(co["staff_share"])
        self.helper_prices = [int(x) for x in co["helper_prices"]]
        self.city_xp = int(co["city_xp_per_parcel"])
        self.rivals = [float(x) for x in co["rivals"]]
        # --- driver (기사 레벨) ---
        drv = d["driver"]
        self.max_level = int(drv["max_level"])
        self.xp_per_parcel = int(drv["xp_per_parcel"])
        self.points_per_level = int(drv["points_per_level"])          # 레벨업마다 능력치 포인트 (Driver.add_xp)
        self.bonus_points = int(drv["bonus_points_every_10"])         # 오른 레벨이 10의 배수면 더
        self.milestones = [int(x) for x in drv["star_milestones"]]
        self.milestone_xp = int(drv["star_milestone_xp"])
        # xp_need[레벨] = 그 레벨에서 다음 레벨까지 (Driver.xp_need). 만렙은 0
        self.xp_need = [0] + [roundi(float(drv["base_xp"]) * L ** float(drv["exponent"])) for L in range(1, self.max_level)] + [0]
        self.xp_to_max = [0] * (self.max_level + 1)   # [레벨] = 그 레벨 0에서 만렙까지
        for L in range(self.max_level - 1, 0, -1):
            self.xp_to_max[L] = self.xp_to_max[L + 1] + self.xp_need[L]
        self.quests = [dict(q) for q in d["quests"]]
        # --- setting ---
        self.lines_by_grade = [int(x) for x in st_["lines_by_grade"]]
        self.max_grade = len(self.lines_by_grade) - 1
        self.up_chance = [float(x) for x in st_["up_chance"]]
        self.ceiling = [int(x) for x in st_["ceiling"]]
        self.roll_cost = [int(x) for x in st_["roll_cost"]]
        self.fuel_cut_cap, self.maint_cut_cap = float(st_["fuel_cut_cap"]), float(st_["maint_cut_cap"])
        self.guard_cap = float(st_["engine_guard_cap"])
        self.ob_mult = float(st_["overboost_mult"])
        self.options = {}
        for oid, o in st_["options"].items():
            values = [0.0] * len(self.lines_by_grade) if o["kind"] == "junk" else [float(v) for v in o["values"]]
            self.options[oid] = {"kind": o["kind"], "weight": float(o["weight"]), "values": values}
        self.parts = list(st_["parts"].keys())   # json 순서
        self.unlock = {p: int(st_["parts"][p].get("unlock_star", 0)) for p in self.parts}
        self.unlock_stage = {p: self.stages.index(st_["parts"][p].get("unlock", "solo")) for p in self.parts}   # 타이어 = 1
        self.part_options = {p: list(st_["parts"][p]["options"]) for p in self.parts}
        # 옵션 뽑기표 (Setting.option_chances): (부품, 등급) → (누적 가중치, 옵션 id)
        self.draw_table = {}
        for p in self.parts:
            for g in range(self.max_grade + 1):
                cum, ids, s = [], [], 0.0
                for op in self.part_options[p]:
                    o = self.options[op]
                    if o["kind"] == "junk" or o["values"][g] != 0.0:
                        s += o["weight"]
                        cum.append(s)
                        ids.append(op)
                self.draw_table[(p, g)] = (cum, ids, s)

    # --- Trip ---
    def power(self, star):
        return self.base_power + sum(self.power_gain[:star])

    def speed(self, star, tot):
        return self.power(star) * (1.0 + tot.get("speed", 0.0))

    def cargo(self, tot):
        """평균 적재량 (Trip.cargo, 소수점 그대로)"""
        c = self.base_cargo * (1.0 + tot.get("cargo", 0.0))
        return float(round(c)) if abs(c - round(c)) < 1e-9 else c

    # --- 능력치 (Trip._ability: 트럭 0만. 시뮬은 트럭 1대). ab = { id: 효과 값 } 또는 None ---
    def ab_values(self, points):
        """Ability.value: { id: 포인트 × per_point }"""
        return {k: p * self.abilities[k][0] for k, p in points.items()}

    def unit(self, ab=None, mult=1.0):
        """Trip._unit × 배수: round(round(단가 × (1 + 협상)) × mult) (대형·VIP·급송 배수. 보통 1)"""
        return roundi(roundi(self.unit_price * (1.0 + (ab or {}).get("nego", 0.0))) * mult)

    def stop_seconds(self, ab=None):
        """Trip._stop: 정차 × (1 − 상하차)"""
        return self.stop * (1.0 - (ab or {}).get("unload", 0.0))

    def tip_chance(self, ab=None):
        return min(1.0, self.tip_base + (ab or {}).get("kind", 0.0))

    def tip_pay(self, ab=None, mult=1.0):
        return roundi(self.unit(ab, mult) * self.tip_rate)

    def drop_chance(self, ab=None, bonus=""):
        """Trip.spare_chance: 드랍 × (1 + 정비 지식) × (명장 "스페어 드랍 2배" 중이면 spare_mult. 켜 둔 동안만 넘김)"""
        p = self.spare_chance * (1.0 + (ab or {}).get("mech", 0.0))
        return p * self.bonuses["spare_mult"] if bonus == "spare_mult" else p

    def kind_shares(self, star):
        """Trip._kind_shares: [(배수, 몫)] 보통·대형·VIP. VIP 몫 먼저, 아니면 대형 (열린 것만)"""
        lu, lm, ls = self.special["large"]
        vu, vm, vs = self.special["vip"]
        vip = vs if star >= vu else 0.0
        large = ls if star >= lu else 0.0
        return [(1.0, (1.0 - vip) * (1.0 - large)), (lm, (1.0 - vip) * large), (vm, vip)]

    def parcel_pay(self, tot, ab=None, mult=1.0):
        """Trip._pay: 단가 × mult인 배송 1건 돈 (보통이면 Trip.parcel_pay). 기름값·정비비 절감은 각자 상한에서 자름 (v7-bal)"""
        f = min(tot.get("fuel_cut", 0.0), self.fuel_cut_cap)
        m = min(tot.get("maint_cut", 0.0), self.maint_cut_cap)
        u = self.unit(ab, mult)
        return u - roundi(u * self.fuel_rate * (1.0 - f)) - roundi(u * self.maint_rate * (1.0 - m))

    def split(self, gross, helper, stage):
        """Trip._split: 번 돈 → (직원 몫, 세금, 내 돈). 직원 몫은 보조 트럭만, 세금은 직원 몫 뗀 나머지를 안 넘음"""
        staff = roundi(gross * self.staff_share) if helper else 0
        tax = min(roundi(gross * self.tax_rates[stage]), gross - staff)
        return staff, tax, gross - staff - tax

    def money_per_parcel(self, star, tot, ab=None, mult=1.0, cut=None):
        """배송 1건 평균 돈 = 종류(보통·대형·VIP) 몫마다 (그 종류 1건 돈 + 팁 확률 × 그 종류 팁)의 합 (Trip.hourly_income_at).
        mult = 급송 배수 (종류 배수에 곱함). cut = (보조 트럭인가, 회사 단계)면 1건 돈·팁마다 직원 몫·세금을 뗀 내 돈 (Trip.hourly_net)"""
        tc = self.tip_chance(ab)
        net = (lambda x: self.split(x, *cut)[2]) if cut else (lambda x: x)
        return sum(share * (net(self.parcel_pay(tot, ab, km * mult)) + tc * net(self.tip_pay(ab, km * mult)))
                   for km, share in self.kind_shares(star))

    def rush_per_hour(self, star, tot, ab=None, accept=RUSH_ACCEPT, cut=None):
        """급송으로 켜 둔 1시간에 더 버는 돈 (평균). 한 주기 = 평균 벨 간격 + 받은 비율 × 급송 건수 ÷ 시간당 배송
        (급송이 남은 동안 벨 시계가 안 감). 한 주기에 더 버는 돈 = 받은 비율 × 급송 건수 × (급송 1건 − 보통 1건)"""
        if accept <= 0.0:
            return 0.0
        pph = self.parcels_per_hour(star, tot, ab)
        extra = self.money_per_parcel(star, tot, ab, self.rush_mult, cut) - self.money_per_parcel(star, tot, ab, cut=cut)
        cycle = (self.rush_min + self.rush_max) / 2.0 / 60.0 + accept * self.rush_parcels / pph
        return accept * self.rush_parcels * extra / cycle

    def lap_seconds(self, star, tot, boosted=False, ab=None):
        """한 바퀴 초 (싣기·정차 둘 다 상하차 반영: Trip._load·_stop, 정차는 평균 적재량). 걸린 바퀴는 달리는 초 ÷ overboost_mult"""
        drive = self.road / self.speed(star, tot)
        if boosted:
            drive /= self.ob_mult
        return self.load * (1.0 - (ab or {}).get("unload", 0.0)) + drive + self.cargo(tot) * self.stop_seconds(ab)

    def avg_lap_seconds(self, star, tot, ab=None):
        p = min(tot.get("overboost", 0.0), 1.0)
        return self.lap_seconds(star, tot, False, ab) * (1.0 - p) + self.lap_seconds(star, tot, True, ab) * p

    def lap_income(self, tot, ab=None):
        """한 바퀴 수입 (팁 뺌, 보통 배송. 게임 Trip.lap_income과 같음)"""
        return self.cargo(tot) * self.parcel_pay(tot, ab)

    def hourly(self, star, tot, ab=None, cut=None):
        """시간당 수입 (팁·대형·VIP 평균 포함, 급송 없음 = 게임 Trip.hourly_income). cut이 있으면 뗀 뒤 (Trip.hourly_net)"""
        return self.cargo(tot) * self.money_per_parcel(star, tot, ab, cut=cut) * 3600.0 / self.avg_lap_seconds(star, tot, ab)

    def parcels_per_hour(self, star, tot, ab=None):
        return self.cargo(tot) * 3600.0 / self.avg_lap_seconds(star, tot, ab)

    # --- Economy / Enhance ---
    def enhance_cost(self, star):
        """Economy.base_enhance_cost (보너스 없음)"""
        return roundi(self.cost_base * self.cost_mult ** star)

    def cost_now(self, star, bonus=""):
        """Economy.enhance_cost: 명장 "강화 비용 할인" 중이면 round(기본 × (1 − 할인))"""
        c = self.enhance_cost(star)
        return roundi(c * (1.0 - self.bonuses["enhance_discount"])) if bonus == "enhance_discount" else c

    def insure_fee(self, star, bonus=""):
        """Enhance.insure_fee (방문 중): 그 회 비용(할인 주에는 할인된 비용) × insure_fee_mult"""
        return roundi(self.cost_now(star, bonus) * self.insure_fee_mult)

    def success_chance(self, star, d, bonus=""):
        """Enhance.chances_for 성공: × success_mult (성공 + 퍼짐 d가 1을 넘으면 자름)"""
        s = self.success[star]
        return min(s * self.bonuses["success_mult"], 1.0 - d) if bonus == "success_mult" else s

    def roll_cost_now(self, grade, bonus=""):
        """Setting.roll_cost: 명장 "세팅 비용 할인" 중이면 round(× (1 − 할인))"""
        c = self.roll_cost[grade]
        return roundi(c * (1.0 - self.bonuses["setting_discount"])) if bonus == "setting_discount" else c

    def up_chance_now(self, grade, bonus=""):
        """Setting.up_chance: 명장 "세팅 등급업 확률 상승" 중이면 × setting_up_mult (최대 1)"""
        p = self.up_chance[grade]
        return min(1.0, p * self.bonuses["setting_up_mult"]) if bonus == "setting_up_mult" else p

    def needs_spare(self, star):
        return 0 <= star < self.max_star and self.destroy[star] > 0.0

    def destroy_chance(self, star, tot, bonus=""):
        """Enhance.chances_for: 퍼짐 × (1 − min(엔진 보호, 상한)) × (명장 "퍼짐 감소" 중이면 1 − destroy_cut)"""
        d = self.destroy[star] * (1.0 - min(tot.get("engine_guard", 0.0), self.guard_cap))
        return d * (1.0 - self.bonuses["destroy_cut"]) if bonus == "destroy_cut" else d

    # --- 꺼둔 동안 (Trip.apply_offline, 트럭 1대). cap·rate = 창고 시간·야간팀 비율 (Depot.cap_hours / rate) ---
    def offline(self, star, tot, hours_away, cap, rate, ab=None):
        """→ (돈, 배송 수). 꺼둔 시간이 3분(ignore_under_seconds) 미만이면 (0, 0)"""
        if hours_away * 3600.0 < self.ignore_under:
            return 0, 0
        hours = min(hours_away, cap)
        money = math.floor(self.hourly(star, tot, ab) * hours * rate)
        parcels = math.floor(self.cargo(tot) * 3600.0 / self.avg_lap_seconds(star, tot, ab) * hours * rate)
        return money, parcels

    def offline_xp(self, parcels, ab=None, xpp=None):
        """꺼둔 동안 경험치 = floor(배송 × 배송 1건 경험치(대리점이면 시내) × 노하우) (Trip.apply_offline, 1e-9는 게임과 같은 실수 찌꺼기 여유)"""
        return math.floor(parcels * (self.xp_per_parcel if xpp is None else xpp) * (ab or {}).get("knowhow", 0.0) + 1e-9)

    def daily_income(self, star, tot, hours_on, cap, rate, ab=None):
        """켜 둔 시간 + 꺼둔 동안 하루 수입 (퍼짐 회복 비용을 며칠치로 바꿀 때, 창고·야간팀 사기 기준)"""
        return self.hourly(star, tot, ab) * hours_on + self.offline(star, tot, 24 - hours_on, cap, rate, ab)[0]

    def lv1_offline(self):
        """창고·야간팀 Lv1 (새 게임)의 (시간, 비율)"""
        return self.depot_values["warehouse"][0], self.depot_values["night"][0]

    # --- Depot ---
    def depot_price(self, kind, level, agency=False):
        """다음 레벨 가격 (Depot.price). 더 못 사면 None. 대리점이면 창고 Lv4까지"""
        if level >= (self.depot_top if agency else self.depot_buyable)[kind]:
            return None
        return self.depot_prices[kind][level - 1]

    # --- Setting ---
    def totals(self, parts):
        """Setting.total: 부품마다 지금 줄의 values[그 부품 등급] 합. parts = { 부품: {"grade", "lines"} }"""
        tot = {}
        for p in parts.values():
            g = p["grade"]
            for op in p["lines"]:
                tot[op] = tot.get(op, 0.0) + self.options[op]["values"][g]
        return tot


class Truck:
    """트럭 1대 (TruckState): 강화 단계, 세팅, 켜 둔 동안 배송 소수 진행. 보조 트럭이면 산 날·값·켜 둔 동안 번 내 돈·본전 시간"""

    def __init__(self, b, helper=False, bought_on=0.0, bought_day=0.0, price=0):
        self.star = 0
        self.parts = {p: {"grade": 0, "lines": [], "counters": [0] * (b.max_grade + 1)} for p in b.parts}
        self.tot = {}
        self.frac = 0.0
        self.helper = helper
        self.bought_on, self.bought_day, self.price = bought_on, bought_day, price
        self.earned = 0.0
        self.payback = None       # 산 뒤 켜 둔 몇 시간에 값만큼 벌었나


class Player:
    # 내 트럭(트럭 0) 칸을 예전 이름 그대로 (v6b까지 트럭 1대 코드)
    star = property(lambda s: s.trucks[0].star, lambda s, v: setattr(s.trucks[0], "star", v))
    tot = property(lambda s: s.trucks[0].tot, lambda s, v: setattr(s.trucks[0], "tot", v))
    parts = property(lambda s: s.trucks[0].parts)
    frac = property(lambda s: s.trucks[0].frac, lambda s, v: setattr(s.trucks[0], "frac", v))

    def __init__(self, b, hours, rng, setting, v4=False, build=DEFAULT_BUILD, style=DEFAULT_STYLE, accept=RUSH_ACCEPT, save=SAVE_SHARE):
        """v4 = v4 숫자 비교용: 꺼둔 동안 V4_OFFLINE 고정, 창고·야간팀·퀘스트·능력치·v6b(급송·주간·명장)·v7a(창업) 없음"""
        self.b, self.H, self.rng, self.setting, self.v4 = b, hours, rng, setting, v4
        # v7a: 회사 단계, 창업 자금, 보조 트럭, 순위
        self.trucks = [Truck(b)]
        self.stage = 0
        self.save = 0.0 if v4 else save
        self.fund = 0.0           # 창업 자금
        self.agency_day = None    # 창업한 때 (0일 0시부터 날 수)
        self.agency_daily = None  # 창업 직전 하루 내 돈 (켜 둔 + 꺼둔)
        self.helper_destroys = 0
        self.sales_log = {}       # 날 → 그날 끝 모든 트럭 시간당 매출 (창업 뒤)
        self.rank1_day = None     # 시내 1위가 된 날
        # v6b: 명장·보험·쿠폰·주간 목표·급송
        self.style = style
        self.accept = 0.0 if v4 else accept
        self.master = False       # 명장 열림
        self.week_bonus = ""      # 이번 주 보너스
        self.bonus = ""           # 지금 적용 중 (방문일 켜 둔 동안만) = GameState.active_bonus
        self.visiting = False
        self.weekday = 0
        self.coupons = 0
        self.coupons_got = 0
        self.coupons_used = 0
        self.insured = 0          # 보험 건 강화 수
        self.saved = 0            # 보험이 퍼짐을 막은 수
        self.doubles = 0
        self.weekly = 0
        self.weekly_done = False
        self.weekly_log = {}      # 주차(1~) → 채운 요일 (1 = 월 … 7 = 일)
        self.rush_money = 0.0
        # v5b 능력치: 받은 포인트, 찍은 포인트, 효과 값 (빌드 순서대로 바로 찍음)
        self.build = [] if v4 else BUILDS[build][1]
        self.ability_points = 0
        self.points = {}
        self.ab = {}
        self.share = SETTING_SHARE if setting else 0.0
        self.money = 0.0          # 강화·스페어 몫
        self.set_money = 0.0      # 세팅 몫
        self.spares = 0
        self.carry = 0.0          # 꺼둔 동안 스페어 소수 나머지 (GameState.spare_drop_carry)
        self.next_drop = self._geom()
        self.best = 0
        self.destroys = 0
        self.presses = 0
        self.rolls = 0
        self.spares_bought = 0
        self.spares_dropped = 0
        self.spent = {"engine": 0, "spare": 0, "setting": 0, "depot": 0, "insure": 0}
        # v5: 창고·야간팀, 기사 레벨, 퀘스트
        self.depot = {"warehouse": 1, "night": 1}
        self.level = 1
        self.xp = 0
        self.reputation = 0
        self.milestones_done = set()
        self.quest_index = 0
        self.parcels_total = 0
        self.parts_rolled = set()
        self.t_day = 0.0          # 지금 시각 (0일 0시부터 날 수)
        self.on_hours = 0.0       # 지금까지 켜 둔 시간
        self.max_at = None        # 만렙이 된 (날, 켜 둔 시간)
        self.open_climbs = []     # [원래 단계, 그동안 쓴 돈, 퍼진 날]
        self.climbs = []          # (원래 단계, 쓴 돈 ÷ 원래 단계 하루 수입, 걸린 날)
        self.snaps = {}           # 날 → dict

    def _geom(self):
        """다음 스페어 드랍까지 배송 몇 건 (배송마다 spare_chance 확률 = 기하분포)"""
        p = self.b.drop_chance(self.ab, self.bonus)
        if p <= 0:
            return math.inf
        if p >= 1:
            return 1
        return int(math.log(1.0 - self.rng.random()) / math.log(1.0 - p)) + 1

    def _income(self, amount):
        keep = amount * (1.0 - self.share)
        if self.stage == 0 and self.save > 0:   # 창업 전: 강화 몫의 일부를 창업 자금으로
            self.fund += keep * self.save
            keep *= 1.0 - self.save
        self.money += keep
        self.set_money += amount * self.share

    def _xpp(self):
        """내 트럭 배송 1건 경험치 (대리점이면 시내)"""
        return self.b.city_xp if self.stage >= 1 else self.b.xp_per_parcel

    def _ab_of(self, t):
        """능력치는 내 트럭만 (Trip._ability)"""
        return self.ab if t is self.trucks[0] else None

    def sales(self):
        """순위 기준 시간당 매출: 모든 트럭 시간당 번 돈 합 (Company.hourly_sales)"""
        return sum(self.b.hourly(t.star, t.tot, self._ab_of(t)) for t in self.trucks)

    def daily_all(self):
        """지금 하루 내 돈 (모든 트럭, 켜 둔 시간 + 꺼둔 동안, 직원 몫·세금 뗀 뒤, 급송 뺌)"""
        b = self.b
        cap, rate = self.cap_rate()
        total = 0.0
        for t in self.trucks:
            ab = self._ab_of(t)
            off = b.offline(t.star, t.tot, 24 - self.H, cap, rate, ab)[0]
            total += b.hourly(t.star, t.tot, ab, (t.helper, self.stage)) * self.H + b.split(off, t.helper, self.stage)[2]
        return total

    # ---------- v7a 창업·보조 트럭 ----------
    def _found(self):
        """창업 자금이 가격 이상이면 창업 (Company.found). 남은 자금은 강화 몫으로"""
        b = self.b
        if self.stage == 0 and self.save > 0 and self.fund >= b.agency_price:
            self.agency_daily = self.daily_all()
            self.money += self.fund - b.agency_price
            self.fund = 0.0
            self.stage = 1
            self.agency_day = self.t_day

    def _helper_next(self):
        """다음 보조 트럭 ("helper", 값). 대리점 전이거나 다 샀으면 None (Company.helper_price)"""
        k = len(self.trucks) - 1
        if self.stage < 1 or k >= len(self.b.helper_prices):
            return None
        return "helper", self.b.helper_prices[k]

    def _buy_helpers(self):
        while True:
            nxt = self._helper_next()
            if nxt is None or self.money < nxt[1]:
                return
            self.money -= nxt[1]
            self.trucks.append(Truck(self.b, True, self.on_hours, self.t_day, nxt[1]))

    # ---------- 꺼둔 동안·창고·야간팀 ----------
    def cap_rate(self):
        """꺼둔 동안 (시간, 비율): 창고·야간팀 레벨 (v4 비교는 고정)"""
        if self.v4:
            return V4_OFFLINE
        return self.b.depot_values["warehouse"][self.depot["warehouse"] - 1], self.b.depot_values["night"][self.depot["night"] - 1]

    def daily(self, star=None):
        return self.b.daily_income(self.star if star is None else star, self.tot, self.H, *self.cap_rate(), self.ab)

    def _depot_next(self):
        """규칙에 맞는 다음 업그레이드 (kind, 가격): 창고 → 야간팀 순서, 가격 ≤ 하루 수입 × DEPOT_DAYS. 없으면 None"""
        if self.v4:
            return None
        limit = self.daily_all() * DEPOT_DAYS
        for kind, _ in DEPOT_KINDS:
            price = self.b.depot_price(kind, self.depot[kind], self.stage >= 1)
            if price is not None and price <= limit:
                return kind, price
        return None

    def _quest_buy(self):
        """지금 차례 퀘스트가 사는 퀘스트면 (kind, 가격). 스페어 = ("spare", 가격). 아니면 None"""
        if self.v4 or self.quest_index >= len(self.b.quests):
            return None
        q = self.b.quests[self.quest_index]
        if self._quest_value(q) >= q["target"]:
            return None
        if q["kind"] == "spares_bought":
            return "spare", self.b.spare_price
        if q["kind"] in self.depot:
            price = self.b.depot_price(q["kind"], self.depot[q["kind"]], self.stage >= 1)
            return None if price is None else (q["kind"], price)
        return None

    def _buy_for_quest(self):
        nxt = self._quest_buy()
        if nxt is None or self.money < nxt[1]:
            return
        kind, price = nxt
        if kind == "spare":
            self._spend(price, "spare")
            self.spares += 1
            self.spares_bought += 1
        else:
            self._spend(price, "depot")
            self.depot[kind] += 1

    def _buy_depot(self):
        while True:
            nxt = self._depot_next()
            if nxt is None or self.money < nxt[1]:
                return
            self._spend(nxt[1], "depot")
            self.depot[nxt[0]] += 1

    # ---------- 기사 레벨·퀘스트 ----------
    def _add_xp(self, amount, when=None):
        """Driver.add_xp. when = 만렙이 된 (날, 켜 둔 시간). 안 주면 지금"""
        if amount <= 0:
            return
        b = self.b
        if self.level >= b.max_level:
            self.reputation += amount
            return
        self.xp += amount
        level0 = self.level
        while self.level < b.max_level and self.xp >= b.xp_need[self.level]:
            self.xp -= b.xp_need[self.level]
            self.level += 1
            self.ability_points += b.points_per_level + (b.bonus_points if self.level % 10 == 0 else 0)
        if self.level != level0:
            self._assign_points()
        if self.level >= b.max_level:
            self.reputation += self.xp
            self.xp = 0
            self.max_at = when or (self.t_day, self.on_hours)

    def _assign_points(self):
        """받은 포인트를 빌드 순서대로 바로 찍는다 (Ability.add를 남은 만큼). 정비 지식이 바뀌면 다음 드랍을 새 확률로 다시 뽑음"""
        left = self.ability_points - sum(self.points.values())
        mech0 = self.points.get("mech", 0)
        for k in self.build:
            room = self.b.abilities[k][1] - self.points.get(k, 0)
            add = min(room, left)
            if add > 0:
                self.points[k] = self.points.get(k, 0) + add
                left -= add
        self.ab = self.b.ab_values(self.points)
        if self.points.get("mech", 0) != mech0:
            self.next_drop = self._geom()   # 기하분포는 기억이 없어서 다시 뽑아도 같음

    def _weekly_add(self, n):
        """주간 목표에 배송 n건 (Weekly.add_parcels): 처음 닿으면 쿠폰 + 경험치, 몇 주차 무슨 요일인지 기록"""
        if self.v4 or n <= 0:
            return
        self.weekly += n
        if not self.weekly_done and self.weekly >= self.b.weekly_target:
            self.weekly_done = True
            self.coupons += self.b.weekly_coupons
            self.coupons_got += self.b.weekly_coupons
            day = int(self.t_day + 1e-9)            # 0일부터
            self.weekly_log[day // 7 + 1] = day % 7 + 1
            self._add_xp(self.b.weekly_xp)

    def _set_bonus(self, bonus):
        """지금 적용 중인 보너스를 바꾼다. 드랍 확률이 바뀌면 다음 드랍을 새 확률로 (기하분포라 다시 뽑아도 같음)"""
        if bonus != self.bonus:
            spare = "spare_mult" in (bonus, self.bonus)
            self.bonus = bonus
            if spare:
                self.next_drop = self._geom()

    def _star_reached(self, star):
        """Driver.on_star_reached: 그 단계 이상의 보너스 단계 중 처음인 것마다 (어느 트럭이든)"""
        for m in self.b.milestones:
            if star >= m and m not in self.milestones_done:
                self.milestones_done.add(m)
                self._add_xp(self.b.milestone_xp)
        if not self.master and not self.v4 and star >= self.b.master_unlock:   # Master.check_unlock → 요일 고름 (이번 주부터)
            self.master = True
            self.week_bonus = self.rng.choice(self.b.bonus_ids)
            self.visiting = self.weekday == MASTER_DAY
            self._set_bonus(self.week_bonus if self.visiting else "")

    def _quest_value(self, q):
        k = q["kind"]
        if k == "parcels":
            return self.parcels_total
        if k == "star":   # 트럭 중 가장 높은 단계
            return max(t.star for t in self.trucks)
        if k == "setting_rolls":
            return self.rolls
        if k == "setting_grade":
            return max(p["grade"] for t in self.trucks for p in t.parts.values())
        if k == "part_rolled":
            return 1 if q.get("part") in self.parts_rolled else 0
        if k == "spares_bought":
            return self.spares_bought
        if k in self.depot:
            return self.depot[k]
        if k == "level":
            return self.level
        if k == "agency":
            return 1 if self.stage >= 1 else 0
        if k == "helpers":
            return len(self.trucks) - 1
        raise ValueError(f"모르는 퀘스트 종류: {k}")

    def _quests(self):
        """찬 퀘스트를 차례대로 전부 끝낸다 (Quest.check를 프레임마다 부르는 것과 같음). 끝낸 수"""
        if self.v4:
            return 0
        done = 0
        qs = self.b.quests
        while self.quest_index < len(qs) and self._quest_value(qs[self.quest_index]) >= qs[self.quest_index]["target"]:
            q = qs[self.quest_index]
            self.quest_index += 1
            self._income(q["money"])
            self._add_xp(q["xp"])
            done += 1
        return done

    def _deliver(self, n, hours=0.0, frac0=0.0, rate=0.0):
        """켜 둔 동안 배송 n건: 돈 + 경험치 + 스페어 드랍. hours·frac0·rate = 이번 구간 (만렙 시각을 나눠 잡을 때)"""
        b = self.b
        self.parcels_total += n
        when = None
        xpp = self._xpp()
        if self.level < b.max_level and xpp > 0 and rate > 0:
            k = math.ceil((b.xp_to_max[self.level] - self.xp) / xpp)   # 만렙이 되는 배송 번호
            if k <= n:
                t = min(hours, max(0.0, (k - frac0) / rate))
                when = (self.t_day + t / 24.0, self.on_hours + t)
        self._add_xp(n * xpp, when)
        self._income(n * self.b.money_per_parcel(self.star, self.tot, self.ab, cut=(False, self.stage)))
        self._weekly_add(n)
        while n >= self.next_drop:
            n -= self.next_drop
            self.spares += 1
            self.spares_dropped += 1
            self.next_drop = self._geom()
        self.next_drop -= n

    def _earn(self, hours):
        rate = self.b.parcels_per_hour(self.star, self.tot, self.ab)
        frac0 = self.frac
        total = frac0 + rate * hours + 1e-9
        n = math.floor(total)
        self.frac = total - n
        self._deliver(n, hours, frac0, rate)
        b = self.b
        for t in self.trucks[1:]:   # 보조 트럭: 직원 몫·세금 뗀 평균 돈, 경험치 0, 드랍은 평균값
            total = t.frac + b.parcels_per_hour(t.star, t.tot) * hours + 1e-9
            k = math.floor(total)
            t.frac = total - k
            net = k * b.money_per_parcel(t.star, t.tot, cut=(True, self.stage))
            self._income(net)
            t.earned += net
            if t.payback is None and t.earned >= t.price:
                t.payback = self.on_hours + hours - t.bought_on
            self.parcels_total += k
            self._weekly_add(k)
            self.carry += k * b.drop_chance(None, self.bonus)
        rush = hours * self.b.rush_per_hour(self.star, self.tot, self.ab, self.accept, (False, self.stage))   # 급송 (평균, 내 트럭만)
        self.rush_money += rush
        self._income(rush)
        self.on_hours += hours
        self.t_day += hours / 24.0
        self._quests()   # 배송 수·레벨 퀘스트 (게임은 advance마다)

    def _spend(self, amount, kind, mine=True):
        """mine = 내 트럭에 쓴 돈 (퍼진 뒤 회복 비용에 셈)"""
        self.money -= amount
        self.spent[kind] += amount
        if mine:
            for c in self.open_climbs:
                c[1] += amount

    # ---------- 세팅 ----------
    def _open(self, t, part):
        """Setting.unlocked: 그 트럭 단계 ≥ unlock_star 이고 회사 단계 ≥ unlock_stage"""
        return t.star >= self.b.unlock[part] and self.stage >= self.b.unlock_stage[part]

    def _roll_part(self):
        """돌릴 (트럭, 부품): 열린 것 중 등급이 가장 낮은 것 (같으면 트럭 번호 → json 순서). 없으면 None"""
        best = None
        for t in self.trucks:
            for p in self.b.parts:
                if self._open(t, p) and (best is None or t.parts[p]["grade"] < best[0].parts[best[1]]["grade"]):
                    best = (t, p)
        return best

    def _value(self, t, tot):
        v = self.b.hourly(t.star, tot, self._ab_of(t))
        if self.b.needs_spare(t.star):
            v *= 1.0 + min(tot.get("engine_guard", 0.0), self.b.guard_cap)
        return v

    def _roll(self, tr, part):
        """Setting.try_roll + choose (값이 같거나 높으면 새 것)"""
        b, rng = self.b, self.rng
        p = tr.parts[part]
        g = p["grade"]
        cost = b.roll_cost_now(g, self.bonus)
        self.set_money -= cost
        self.spent["setting"] += cost
        self.rolls += 1
        self.parts_rolled.add(part)
        up = False
        if g < b.max_grade:
            p["counters"][g] += 1
            if p["counters"][g] >= b.ceiling[g]:
                up = True
            elif rng.random() < b.up_chance_now(g, self.bonus):
                up = True
            if up:
                p["counters"][g] = 0
        ng = g + 1 if up else g
        cum, ids, total = b.draw_table[(part, ng)]
        lines = [ids[min(len(ids) - 1, bisect.bisect_right(cum, rng.random() * total))] for _ in range(b.lines_by_grade[ng])]
        new_parts = dict(tr.parts)
        new_parts[part] = {"grade": ng, "lines": lines, "counters": p["counters"]}
        new_tot = b.totals(new_parts)
        if up or self._value(tr, new_tot) >= self._value(tr, tr.tot):
            p["grade"], p["lines"] = ng, lines
            tr.tot = new_tot

    def _settings(self):
        if not self.setting:
            return
        while True:
            tp = self._roll_part()
            cost = None if tp is None else self.b.roll_cost_now(tp[0].parts[tp[1]]["grade"], self.bonus)
            if tp is None or self.set_money < cost:
                return
            self._roll(*tp)
            if cost <= 0:
                return   # 공짜 돌리기면 살펴볼 때 1번만 (끝없이 돌지 않게)

    # ---------- 살펴보기 ----------
    def act(self, day):
        """살펴보기 1번: 퀘스트 → 창업·보조 트럭 → 세팅 → 창고·야간팀 → 강화. 그사이 끝난 퀘스트가 있으면 (보상 돈으로) 한 번 더"""
        while True:
            self._quests()
            self._buy_for_quest()
            self._found()
            self._buy_helpers()
            self._settings()
            self._buy_depot()
            self._enhance(day)
            if not self._quests():
                return

    def _enhance_target(self):
        """누를 트럭: 단계가 가장 낮은 트럭 (같으면 번호가 앞 = 내 트럭 먼저). 전부 최고 단계면 None"""
        live = [t for t in self.trucks if t.star < self.b.max_star]
        return min(live, key=lambda t: t.star) if live else None

    def _insure_now(self, t):
        """pool 유저가 트럭 t 단계에서 보험을 거나: None = 안 누르고 모음, "fee" = 방문일 추가 요금, "coupon" = 쿠폰, "" = 보험 없이"""
        if self.style != "pool" or t.star < POOL_FROM or not self.master or self.b.insure_fee_mult is None:
            return ""
        if self.visiting:
            return "fee"
        return "coupon" if self.coupons > 0 else None

    def _enhance(self, day):
        """누를 수 있는 동안 계속 강화 (단계가 가장 낮은 트럭부터). 스페어는 필요할 때 1개만 (보험이면 안 삼).
        pool 유저는 +18부터 방문일·쿠폰에만 (보험)"""
        b = self.b
        while True:
            t = self._enhance_target()
            if t is None:
                return
            mine = t is self.trucks[0]
            insure = self._insure_now(t)
            if insure is None:
                return
            if not insure and b.needs_spare(t.star) and self.spares == 0:
                if self.money < b.spare_price:
                    return
                self._spend(b.spare_price, "spare", mine)
                self.spares += 1
                self.spares_bought += 1
                continue
            cost = b.cost_now(t.star, self.bonus)
            fee = b.insure_fee(t.star, self.bonus) if insure == "fee" else 0
            if self.money < cost + fee:
                return
            self._spend(cost, "engine", mine)
            if fee:
                self._spend(fee, "insure", mine)
            if insure == "coupon":
                self.coupons -= 1
                self.coupons_used += 1
            if insure:
                self.insured += 1
            self.presses += 1
            r = self.rng.random()            # Enhance.decide_chances: 성공 → 퍼짐 → 실패 순서
            d = b.destroy_chance(t.star, t.tot, self.bonus)
            s = b.success_chance(t.star, d, self.bonus)
            if r < s:
                t.star += 1
                if self.bonus == "double_step" and t.star < b.max_star and self.rng.random() < b.bonuses["double_step"]:
                    t.star += 1
                    self.doubles += 1
                self.best = max(self.best, self.star)
                self._star_reached(t.star)
                self._close_climbs(day)
                self._settings()             # ECU가 열렸을 수 있음
            elif r < s + d:
                if insure:
                    self.saved += 1          # 보험: 퍼짐 → 실패 (단계 유지, 스페어 안 씀)
                    continue
                if mine:
                    self.destroys += 1
                    self.open_climbs.append([t.star, 0, day])
                else:
                    self.helper_destroys += 1
                self.spares -= 1
                t.star = min(t.star, b.drop_to)

    def _close_climbs(self, day):
        still = []
        for target, spent, start in self.open_climbs:
            if self.star >= target:
                self.climbs.append((target, spent / self.daily(target), day - start))
            else:
                still.append([target, spent, start])
        self.open_climbs = still

    def _hours_until(self, need, per_parcel, rate):
        """need원을 모으는 데 걸리는 시간 (배송 1건에 per_parcel원씩)"""
        if need <= 0:
            return 0.0
        if per_parcel <= 0 or rate <= 0:
            return math.inf
        return max(0.0, math.ceil(need / per_parcel) - self.frac) / rate

    def next_wait(self):
        """다음에 살펴볼 때까지 (강화·스페어, 세팅 돌리기, 창고·야간팀, 창업, 보조 트럭이 될 때까지) 몇 시간.
        돈 속도 = 내 트럭 배송 1건마다 (내 트럭 1건 내 돈 + 보조 트럭 시간당 내 돈 ÷ 내 트럭 시간당 배송). 급송 뺌"""
        b = self.b
        rate = b.parcels_per_hour(self.star, self.tot, self.ab)
        pay = b.money_per_parcel(self.star, self.tot, self.ab, cut=(False, self.stage))
        if rate > 0:
            pay += sum(b.hourly(t.star, t.tot, None, (True, self.stage)) for t in self.trucks[1:]) / rate
        save = self.save if self.stage == 0 else 0.0
        keep = pay * (1.0 - self.share)
        pool = keep * (1.0 - save)
        wait = math.inf
        t = self._enhance_target()
        insure = None if t is None else self._insure_now(t)
        if insure is not None:   # pool 유저가 모으는 중이면 강화로는 안 깸 (방문일 아침에 깸)
            if not insure and b.needs_spare(t.star) and self.spares == 0:
                price = b.spare_price
            else:
                price = b.cost_now(t.star, self.bonus) + (b.insure_fee(t.star, self.bonus) if insure == "fee" else 0)
            wait = self._hours_until(price - self.money, pool, rate)
        tp = self._roll_part() if self.setting else None
        if tp is not None:
            wait = min(wait, self._hours_until(b.roll_cost_now(tp[0].parts[tp[1]]["grade"], self.bonus) - self.set_money,
                                               pay * self.share, rate))
        for nxt in (self._depot_next(), self._quest_buy(), self._helper_next()):
            if nxt is not None:
                wait = min(wait, self._hours_until(nxt[1] - self.money, pool, rate))
        if save > 0:
            wait = min(wait, self._hours_until(b.agency_price - self.fund, keep * save, rate))
        return wait

    def run(self):
        b, H = self.b, self.H
        snap_set = set(SNAP_DAYS)
        for day in range(1, SIM_DAYS + 1):
            h = 0.0
            self.t_day = day - 1
            self.weekday = (day - 1) % 7                 # 1일째 = 월요일
            if self.weekday == 0:                        # 새 주: 주간 목표 0, 그 주 명장 보너스 (Master.tick)
                self.weekly = 0
                self.weekly_done = False
                if self.master:
                    self.week_bonus = self.rng.choice(b.bonus_ids)
            self.visiting = self.master and self.weekday == MASTER_DAY
            self._set_bonus(self.week_bonus if self.visiting else "")
            while True:
                self.act(day - 1 + h / 24)
                nh = h + self.next_wait()
                if nh != math.inf:
                    nh = max(h + CHECK_HOURS, math.ceil(nh / CHECK_HOURS - 1e-9) * CHECK_HOURS)
                if nh >= H:
                    self._earn(H - h)
                    break
                self._earn(nh - h)
                h = nh
            if self.stage >= 1:
                sales = self.sales()
                self.sales_log[day] = sales
                if self.rank1_day is None and sales >= max(b.rivals):
                    self.rank1_day = day
            if day in snap_set:
                self.snaps[day] = {
                    "star": self.star, "best": self.best, "destroys": self.destroys,
                    "money": self.money + self.set_money, "spares": self.spares,
                    "grades": {p: (self.parts[p]["grade"] if self._open(self.trucks[0], p) else -1) for p in b.parts},
                    "stage": self.stage, "stars": [t.star for t in self.trucks], "sales": self.sales(),
                    "spent": dict(self.spent), "hourly": b.hourly(self.star, self.tot, self.ab), "tot": dict(self.tot),
                    "points": dict(self.points),
                    "coupons": self.coupons, "coupons_got": self.coupons_got, "insured": self.insured, "saved": self.saved,
                    "master": self.master,
                    "level": self.level, "depot": dict(self.depot), "quests": self.quest_index,
                }
            self._set_bonus("")                          # 꺼둔 동안은 보너스·급송 없음
            self.visiting = False
            money, parcels, parcels0 = 0, 0, 0
            for t in self.trucks:   # Trip.apply_offline: 트럭마다 floor한 번 돈 → 직원 몫·세금 뗌
                g, n_t = b.offline(t.star, t.tot, 24 - H, *self.cap_rate(), self._ab_of(t))
                money += b.split(g, t.helper, self.stage)[2]
                parcels += n_t
                self.carry += n_t * b.drop_chance(self._ab_of(t))
                if t is self.trucks[0]:
                    parcels0 = n_t
            self._income(money)
            self.parcels_total += parcels
            self._weekly_add(parcels)
            self._add_xp(b.offline_xp(parcels0, self.ab, self._xpp()))   # 노하우, 내 트럭만 (만렙 시각은 켜 둔 시간이 끝난 때로)
            whole = math.floor(self.carry)
            self.carry -= whole
            self.spares += whole
            self.spares_dropped += whole
        return self


def simulate(b, hours, n, seed, setting, v4=False, build=DEFAULT_BUILD, style=DEFAULT_STYLE, accept=RUSH_ACCEPT, save=SAVE_SHARE):
    master = random.Random(seed)
    return [Player(b, hours, random.Random(master.random()), setting, v4, build, style, accept, save).run() for _ in range(n)]


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def won(v):
    """돈을 1.2만 / 3.4억 / 1.2조 꼴로 (게임 돈 표기와 비슷하게, 표 읽기용)"""
    for unit, name in ((10 ** 12, "조"), (10 ** 8, "억"), (10 ** 4, "만")):
        if abs(v) >= unit:
            x = v / unit
            return f"{x:.1f}{name}" if x < 100 else f"{x:,.0f}{name}"
    return f"{v:,.0f}"


def share_of(spent, kind):
    total = sum(spent.values())
    return spent[kind] / total if total > 0 else 0.0


def setting_share(spent):
    total = sum(spent.values())
    return spent["setting"] / total if total > 0 else 0.0


# ======================= 출력 =======================
def table(b):
    tot = {}
    lv1 = b.lv1_offline()
    print("=" * 100)
    print(f"■ 단계별 표 (balance.json v{b.version}, 세팅 없음)  배송 1건 {b.parcel_pay(tot)}원 = 단가 {b.unit_price} − 기름값 "
          f"{roundi(b.unit_price * b.fuel_rate)} − 정비비 {roundi(b.unit_price * b.maint_rate)}, 한 바퀴 {b.cargo(tot):g}건")
    print("=" * 100)
    print("  단계 | 출력 |  한 바퀴 초 | 한 바퀴 수입 |    시간당 수입 | 하루(2.5h) | 하루(8h) |      강화 비용 | 비용÷시간당")
    for s in range(b.max_star + 1):
        mark = "◀" if s in TABLE_STARS else " "
        cost = b.enhance_cost(s) if s < b.max_star else None
        cost_txt = f"{cost:>14,}" if cost is not None else f"{'-':>14}"
        hrs_txt = f"{cost / b.hourly(s, tot):8.1f}시간" if cost is not None else f"{'-':>12}"
        print(f"  {mark}+{s:<2} | {b.power(s):>4} | {b.lap_seconds(s, tot):>11.4f} | {b.lap_income(tot):>11,.0f} | "
              f"{b.hourly(s, tot):>14.4f} | {won(b.daily_income(s, tot, 2.5, *lv1)):>10} | {won(b.daily_income(s, tot, 8.0, *lv1)):>8} | "
              f"{cost_txt} | {hrs_txt}")
    print("  ◀ = C1 테스트(test_trip.gd test_lap_numbers_match_formula)가 찍는 단계. 시간당 수입이 같아야 함")
    print(f"  스페어 {b.spare_price:,}원 고정, 배송마다 {b.spare_chance * 100:g}% 드랍. "
          f"꺼둔 동안 (하루 열은 창고·야간팀 Lv1) 최대 {lv1[0]:g}시간 × {lv1[1] * 100:g}%, {b.ignore_under:g}초 미만 무시")
    print("  창고 확장: " + " → ".join(f"{h:g}시간" for h in b.depot_values["warehouse"])
          + "  가격 " + " / ".join(won(x) for x in b.depot_prices["warehouse"][:b.depot_buyable["warehouse"] - 1])
          + f" (Lv{b.depot_buyable['warehouse']}까지, 대리점 전)")
    print("  야간 배송팀: " + " → ".join(f"{r * 100:g}%" for r in b.depot_values["night"])
          + "  가격 " + " / ".join(won(x) for x in b.depot_prices["night"][:b.depot_buyable["night"] - 1]))
    print(f"  세팅 돌리기 1번: " + " / ".join(f"{GRADE_NAMES[g]} {won(c)}" for g, c in enumerate(b.roll_cost)))
    print(f"  팁: 배송마다 {b.tip_base * 100:g}% (+ 친절), 팁 = 단가 × {b.tip_rate:g} (기름값·정비비 안 뗌). "
          f"시간당 수입에는 평균 {b.tip_chance() * b.tip_pay():g}원/건이 들어감. 한 바퀴 수입 칸은 팁·대형·VIP 뺌 (보통 배송)")
    (lu, lm, ls), (vu, vm, vs) = b.special["large"], b.special["vip"]
    print(f"  대형 +{lu}부터 ×{lm:g} 몫 {ls * 100:g}%, VIP +{vu}부터 ×{vm:g} 몫 {vs * 100:g}% → 배송 1건 평균 배수 "
          + ", ".join(f"+{s} ×{sum(m * sh for m, sh in b.kind_shares(s)):.4g}" for s in (14, lu, vu)) + " (시간당 수입 칸에 들어감)")
    print(f"  급송: 벨 {b.rush_min:g}~{b.rush_max:g}분, 받으면 다음 {b.rush_parcels}건 ×{b.rush_mult:g} (시간당 칸에는 안 들어감). "
          f"주간 목표 {b.weekly_target:,}건 → 쿠폰 {b.weekly_coupons} + 경험치 {b.weekly_xp:,}. "
          f"명장 +{b.master_unlock}부터" + (f", 보험 = 비용 × {b.insure_fee_mult:g}" if b.insure_fee_mult is not None else " (보험 없음: v7-bal 보험사는 C3)"))
    print()
    print("■ 능력치 하나만 최대일 때 시간당 수입 (세팅 없음, 창고·야간팀 Lv1. 수입이 아닌 노하우·정비 지식은 효과만)")
    print("  능력치 (최대) |   효과   | " + " | ".join(f"+{s} 시간당 (차이)" for s in ABILITY_STARS))
    for k, (per, mx) in b.abilities.items():
        ab = b.ab_values({k: mx})
        cells = []
        for s in ABILITY_STARS:
            h0, h1 = b.hourly(s, tot), b.hourly(s, tot, ab)
            cells.append(f"{won(h1):>8} ({(h1 / h0 - 1) * 100:+5.1f}%)")
        print(f"  {ABILITY_NAMES.get(k, k):<6} {mx:>2}포인트 | {per * mx * 100:6.1f}% | " + " | ".join(cells))
    print()


def report(b, label, hours, players, seed, compare=None, v4=None, build=DEFAULT_BUILD, style=DEFAULT_STYLE, accept=RUSH_ACCEPT,
           save=SAVE_SHARE):
    n = len(players)
    lv1 = b.lv1_offline()
    target = TARGETS.get(hours)
    setting = players[0].setting
    print("=" * 100)
    print(f"■ {label}: 하루 {hours:g}시간 켜 둠, {24 - hours:g}시간 꺼 둠 (창고·야간팀 Lv1 {lv1[0]:g}시간 × {lv1[1] * 100:g}%에서 시작, "
          f"하루 수입의 {DEPOT_DAYS:g}배 이하면 삼), "
          f"{n:,}명, seed {seed}, " + (f"세팅 있음 (번 돈의 {SETTING_SHARE * 100:g}%)" if setting else "세팅 없음")
          + f", 능력치 빌드 {BUILDS[build][0]}({build}), 명장 {STYLES[style]}({style}), 급송 받는 비율 {accept * 100:g}%"
          + f", 창업 자금 {save * 100:g}%"
          + (f"  — 목표 30일 +{target}" if target else ""))
    print("=" * 100)
    print("    날짜 | 지금 단계 중앙값 [하위 10% ~ 상위 10%] | 최고 도달(참고) | 퍼짐 평균 | 시간당 수입 중앙값 | 쓴 돈 중 세팅 | 스페어 "
          "| 기사 Lv | 퀘스트")
    for d in SNAP_DAYS:
        cur = [p.snaps[d]["star"] for p in players]
        best = [p.snaps[d]["best"] for p in players]
        mark = " ← 판정" if d == JUDGE_DAY else ""
        if d == JUDGE_DAY and target:
            gap = st.median(cur) - target   # 넘쳐도 "맞음"이 아님 (목표는 그 단계. v5b부터 빠름도 표시)
            mark += f" (목표 +{target}: {'맞음' if gap == 0 else (f'빠름 +{gap:g}' if gap > 0 else f'모자람 {gap:g}')})"
        print(f"    {d:>3}일 |        +{st.median(cur):<4g} [+{pct(cur, 0.1):<2} ~ +{pct(cur, 0.9):<2}]"
              f"            |     +{st.median(best):<4g}      |  {st.mean(p.snaps[d]['destroys'] for p in players):6.2f}   | "
              f"{won(st.median(p.snaps[d]['hourly'] for p in players)):>17} | "
              f"{st.median(setting_share(p.snaps[d]['spent']) for p in players) * 100:11.1f}% | "
              f"{st.median(p.snaps[d]['spares'] for p in players):>5g} | "
              f"{st.median(p.snaps[d]['level'] for p in players):>7g} | {st.median(p.snaps[d]['quests'] for p in players):>4g}/{len(b.quests)}{mark}")
    if compare is not None:
        cur_c = [p.snaps[JUDGE_DAY]["star"] for p in compare]
        cur = [p.snaps[JUDGE_DAY]["star"] for p in players]
        hr_c = st.median(p.snaps[JUDGE_DAY]["hourly"] for p in compare)
        hr = st.median(p.snaps[JUDGE_DAY]["hourly"] for p in players)
        print(f"  ▶ 세팅 없음과 비교 (같은 seed, {JUDGE_DAY}일째): 지금 단계 중앙값 세팅 있음 +{st.median(cur):g} / 없음 +{st.median(cur_c):g}, "
              f"하위 10% +{pct(cur, 0.1)} / +{pct(cur_c, 0.1)}, 시간당 수입 중앙값 {won(hr)} / {won(hr_c)} ({(hr / hr_c - 1) * 100:+.1f}%)")
    if v4 is not None:
        cur_4 = [p.snaps[JUDGE_DAY]["star"] for p in v4]
        cur = [p.snaps[JUDGE_DAY]["star"] for p in players]
        print(f"  ▶ v4 숫자와 비교 (꺼둔 동안 {V4_OFFLINE[0]:g}시간 × {V4_OFFLINE[1] * 100:g}% 고정, 창고·야간팀·퀘스트 없음, 같은 seed, "
              f"{JUDGE_DAY}일째): 지금 단계 중앙값 v5 +{st.median(cur):g} / v4 +{st.median(cur_4):g}"
              + (f" (목표 +{target})" if target else "")
              + f", 하위 10% +{pct(cur, 0.1)} / +{pct(cur_4, 0.1)}, 상위 10% +{pct(cur, 0.9)} / +{pct(cur_4, 0.9)}")

    judge = [p.snaps[JUDGE_DAY]["star"] for p in players]
    print(f"\n  ▶ {JUDGE_DAY}일째 지금 단계 분포")
    for s in range(min(judge), max(judge) + 1):
        k = sum(1 for x in judge if x == s)
        if k:
            print(f"    +{s:<2} {k / n * 100:5.1f}% {'█' * round(k / n * 100)}")

    if setting:
        print(f"\n  ▶ 부품별 등급 분포 (잠김 = 그 부품이 아직 안 열림)")
        print("    날짜 | 부품      |   잠김 |   " + " | ".join(f"{g:>6}" for g in GRADE_NAMES))
        for d in GRADE_DAYS:
            for part in b.parts:
                grades = [p.snaps[d]["grades"][part] for p in players]
                cells = [sum(1 for g in grades if g == k) / n * 100 for k in range(-1, b.max_grade + 1)]
                print(f"    {d:>3}일 | {part:<9} | {cells[0]:5.1f}% | " + " | ".join(f"{c:7.1f}%" for c in cells[1:]))
        print("    세팅 효과 합 평균 (30일 / 90일): " + ", ".join(
            f"{e} {st.mean(p.snaps[30]['tot'].get(e, 0.0) for p in players) * 100:.1f}% / "
            f"{st.mean(p.snaps[90]['tot'].get(e, 0.0) for p in players) * 100:.1f}%" for e in EFFECTS))
        print(f"    {SIM_DAYS}일 동안 돌리기 {st.median(p.rolls for p in players):,.0f}번 (중앙값)")

    # --- v5: 기사 레벨·물류센터·퀘스트 ---
    reached = [p.max_at for p in players if p.max_at is not None]
    lv = [p.snaps[JUDGE_DAY]["level"] for p in players]
    print(f"\n  ▶ 기사 레벨 (만렙 {b.max_level})")
    if reached:
        days = [r[0] for r in reached]
        on = [r[1] for r in reached]
        print(f"    만렙까지: {SIM_DAYS}일 안에 {len(reached) / n * 100:.1f}% 도달 (못 감 {(n - len(reached)) / n * 100:.1f}%). "
              f"도달한 사람 중앙값 {st.median(days):.1f}일 [{pct(days, 0.1):.1f} ~ {pct(days, 0.9):.1f}], "
              f"켜 둔 시간 {st.median(on):.1f}시간 [{pct(on, 0.1):.1f} ~ {pct(on, 0.9):.1f}]")
    else:
        print(f"    만렙까지: {SIM_DAYS}일 안에 아무도 못 감 (100%)")
    print(f"    {JUDGE_DAY}일째 기사 레벨 중앙값 {st.median(lv):g} [하위 10% {pct(lv, 0.1)} ~ 상위 10% {pct(lv, 0.9)}]")
    if BUILDS[build][1]:
        pts = {}
        for p in players:
            for k, v in p.snaps[JUDGE_DAY]["points"].items():
                pts.setdefault(k, []).append(v)
        print(f"    {JUDGE_DAY}일째 찍은 능력치 중앙값: " + ", ".join(
            f"{ABILITY_NAMES.get(k, k)} {st.median(v + [0] * (n - len(v))):g}" for k, v in pts.items()))
    print(f"\n  ▶ 물류센터 {JUDGE_DAY}일째 레벨 분포 (규칙: 가격 ≤ 하루 수입 × {DEPOT_DAYS:g}이면 창고 → 야간팀 순서로 삼)")
    for kind, name in DEPOT_KINDS:
        levels = [p.snaps[JUDGE_DAY]["depot"][kind] for p in players]
        top = len(b.depot_values[kind])
        unit = (lambda v: f"{v:g}시간") if kind == "warehouse" else (lambda v: f"{v * 100:g}%")
        print(f"    {name:<5} " + " | ".join(f"Lv{k}({unit(b.depot_values[kind][k - 1])}) {sum(1 for x in levels if x == k) / n * 100:5.1f}%"
                                         for k in range(1, top + 1)))
    print(f"    쓴 돈 중 창고·야간팀 ({JUDGE_DAY}일째 중앙값) {st.median(share_of(p.snaps[JUDGE_DAY]['spent'], 'depot') for p in players) * 100:.1f}%")
    qs = [p.snaps[JUDGE_DAY]["quests"] for p in players]
    stuck = {}
    for x in qs:
        if x < len(b.quests):
            stuck[b.quests[x]["id"]] = stuck.get(b.quests[x]["id"], 0) + 1
    top_stuck = sorted(stuck.items(), key=lambda kv: -kv[1])[:3]
    print(f"\n  ▶ 퀘스트 ({JUDGE_DAY}일째): 끝낸 수 중앙값 {st.median(qs):g}/{len(b.quests)}, 다 끝냄 {sum(1 for x in qs if x >= len(b.quests)) / n * 100:.1f}%"
          + (", 지금 차례 많은 것: " + ", ".join(f"{k} {v / n * 100:.0f}%" for k, v in top_stuck) if top_stuck else ""))

    # --- v6b: 주간 목표·쿠폰·명장·보험·급송 ---
    print(f"\n  ▶ 주간 배송 목표 {b.weekly_target:,}건 (1일째 = 월요일): 주차별 채운 비율 · 채운 요일 중앙값 (1 = 월 … 7 = 일)")
    cells = []
    for w in range(1, SIM_DAYS // 7 + 1):
        days = [p.weekly_log[w] for p in players if w in p.weekly_log]
        cells.append(f"{w}주 {len(days) / n * 100:3.0f}%" + (f"·{st.median(days):g}일" if days else ""))
    for i in range(0, len(cells), 7):
        print("    " + " | ".join(cells[i:i + 7]))
    j = [p.snaps[JUDGE_DAY] for p in players]
    print(f"  ▶ 명장·보험 ({JUDGE_DAY}일째 / {SIM_DAYS}일째 평균): 열림 {sum(1 for x in j if x['master']) / n * 100:.0f}%, "
          f"받은 쿠폰 {st.mean(x['coupons_got'] for x in j):.1f} / {st.mean(p.coupons_got for p in players):.1f}장, "
          f"남은 쿠폰 {st.mean(x['coupons'] for x in j):.1f} / {st.mean(p.coupons for p in players):.1f}장, "
          f"보험 건 강화 {st.mean(x['insured'] for x in j):.1f} / {st.mean(p.insured for p in players):.1f}번, "
          f"보험이 막은 퍼짐 {st.mean(x['saved'] for x in j):.2f} / {st.mean(p.saved for p in players):.2f}번, "
          f"2단계 {st.mean(p.doubles for p in players):.2f}번, 쓴 돈 중 보험 추가 요금 "
          f"{st.median(share_of(p.spent, 'insure') for p in players) * 100:.1f}%")
    print(f"  ▶ 급송: {SIM_DAYS}일 동안 급송으로 더 번 돈 중앙값 {won(st.median(p.rush_money for p in players))}")
    if save > 0:
        report_v7a(b, players, save)

    print(f"\n  ▶ {SIM_DAYS}일 동안: 강화 {st.median(p.presses for p in players):,.0f}번 (중앙값), "
          f"스페어 산 것 평균 {st.mean(p.spares_bought for p in players):.2f}개 / 드랍 평균 {st.mean(p.spares_dropped for p in players):.2f}개, "
          f"쓴 돈 중 스페어 {st.median(p.spent['spare'] / max(1, sum(p.spent.values())) for p in players) * 100:.1f}% (중앙값)")

    print(f"\n  ▶ 퍼진 뒤 원래 단계로 돌아가는 데 든 돈 ({SIM_DAYS}일 안에 퍼진 것. 원래 단계 하루 수입의 며칠치)")
    print("    퍼진 단계 | 퍼짐 횟수 | 돌아감 | 든 돈 중앙값 [하위 10% ~ 상위 10%] | 평균    | 걸린 날 중앙값")
    climbs = [c for p in players for c in p.climbs]
    opened = {}
    for p in players:
        for c in p.open_climbs:
            opened[c[0]] = opened.get(c[0], 0) + 1
    for s in range(b.max_star):
        done = [c for c in climbs if c[0] == s]
        left = opened.get(s, 0)
        if not done and not left:
            continue
        if done:
            days = [c[1] for c in done]
            print(f"    +{s:<2}       | {len(done) + left:>8,} | {len(done) / (len(done) + left) * 100:5.1f}% | "
                  f"{st.median(days):8.2f}일 [{pct(days, 0.1):6.2f} ~ {pct(days, 0.9):6.2f}]   | {st.mean(days):6.2f}일 | "
                  f"{st.median(c[2] for c in done):6.2f}일")
        else:
            print(f"    +{s:<2}       | {left:>8,} |   0.0% | {'아직 아무도 못 돌아감':^34} |")
    print()


def report_v7a(b, players, save):
    """v7a: 창업한 날, 보조 트럭 산 날·본전, 트럭별 단계, 주차별 시간당 매출·순위, 1위가 된 날"""
    n = len(players)
    founded = [p for p in players if p.agency_day is not None]
    print(f"\n  ▶ 대리점 창업 ({won(b.agency_price)}, 창업 전 강화 몫의 {save * 100:g}%를 모음): {SIM_DAYS}일 안에 {len(founded) / n * 100:.0f}%"
          + (f", 창업한 날 중앙값 {st.median(p.agency_day + 1 for p in founded):.1f}일째 "
             f"[{pct([p.agency_day + 1 for p in founded], 0.1):.1f} ~ {pct([p.agency_day + 1 for p in founded], 0.9):.1f}], "
             f"그날 하루 내 돈 중앙값 {won(st.median(p.agency_daily for p in founded))} → 가격 = "
             f"{st.median(b.agency_price / p.agency_daily for p in founded):.1f}일치, 창업한 날 끝 시간당 매출 "
             f"{won(st.median(p.sales_log[int(p.agency_day) + 1] for p in founded))}" if founded else ""))
    base = b.hourly(0, {}, None, (True, 1))
    for k, price in enumerate(b.helper_prices):
        trs = [p.trucks[k + 1] for p in founded if len(p.trucks) > k + 1]
        if not trs:
            print(f"    {k + 2}호차 {won(price)}: 아무도 안 삼")
            continue
        pays = [tr.payback for tr in trs if tr.payback is not None]
        print(f"    {k + 2}호차 {won(price)}: 창업한 사람 중 {len(trs) / max(1, len(founded)) * 100:.0f}%가 삼, "
              f"산 날 중앙값 {st.median(tr.bought_day + 1 for tr in trs):.1f}일째, 본전(산 뒤 켜 둔 시간) 중앙값 "
              + (f"{st.median(pays):.1f}시간 [{pct(pays, 0.1):.1f} ~ {pct(pays, 0.9):.1f}]" if pays else "아직")
              + f" (+0 세팅 없음 시간당 내 돈 {won(base)} → 값 ÷ 그것 = {price / base:.1f}시간)")
    for d in (30, 60, 90):
        rows = [p.snaps[d] for p in players if p.snaps[d]["stage"] >= 1]
        if rows:
            cols = max(len(r["stars"]) for r in rows)
            print(f"    {d}일째 (창업한 {len(rows) / n * 100:.0f}%) 단계 중앙값: "
                  + ", ".join(f"{'내 트럭' if k == 0 else f'{k + 1}호차'} +{st.median(r['stars'][k] for r in rows if len(r['stars']) > k):g}"
                              for k in range(cols))
                  + f", 시간당 매출 {won(st.median(r['sales'] for r in rows))}")
    print(f"  ▶ 순위 (라이벌 {len(b.rivals)}곳 {won(b.rivals[0])} ~ {won(b.rivals[-1])}): 주차 끝 시간당 매출 중앙값 (창업한 사람) · 순위 중앙값")
    cells = []
    for d in WEEK_DAYS:
        s = [p.sales_log[d] for p in players if d in p.sales_log]
        if s:
            cells.append(f"{d // 7}주 {won(st.median(s))}·{st.median(1 + sum(1 for r in b.rivals if r > x) for x in s):g}위")
    for i in range(0, len(cells), 7):
        print("    " + " | ".join(cells[i:i + 7]))
    r1 = [math.inf if p.rank1_day is None else p.rank1_day for p in players]   # 못 간 사람은 "아직" (중앙값에 넣음)
    day = lambda x: "못 감" if x == math.inf else f"{x:g}일째 ({x / 7:.1f}주)"
    print(f"    시내 1위: {SIM_DAYS}일 안에 {sum(1 for x in r1 if x < math.inf) / n * 100:.0f}%, 처음 된 날 (못 간 사람 포함) "
          f"중앙값 {day(pct(r1, 0.5))} [하위 10% {day(pct(r1, 0.9))} ~ 상위 10% {day(pct(r1, 0.1))}]")
    print(f"    {SIM_DAYS}일 동안 보조 트럭 퍼짐 평균 {st.mean(p.helper_destroys for p in players):.2f}번")


def table_v7a(b):
    """v7a: 게임 테스트 대조 값, 곱셈 폭주 점검, 정비비 감소 한 줄의 가치"""
    import itertools
    print("■ v7a 게임 테스트 대조 (tests/test_company.gd 노트와 같아야 함)")
    for k, s in enumerate([5, 12, 18]):
        print(f"  대리점 트럭 {k} +{s}: 시간당 번 돈 {b.hourly(s, {}):.0f}, 내 돈 {b.hourly(s, {}, None, (k > 0, 1)):.0f}")
    gs = [math.floor(b.hourly(s, {}) * 3.0 * b.depot_values["night"][0]) for s in (10, 15, 18)]
    parts = [b.split(g, k > 0, 1) for k, g in enumerate(gs)]
    print(f"  대리점 3대 [+10, +15, +18] 꺼둔 3시간 (야간팀 Lv1): 번 돈 {sum(gs)}, 직원 몫 {sum(x[0] for x in parts)}, "
          f"세금 {sum(x[1] for x in parts)}, 내 돈 {sum(x[2] for x in parts)}")
    print(f"  +0 1건 돈: 세팅 없음 {b.parcel_pay({})}, 정비비 감소 3% {b.parcel_pay({'maint_cut': 0.03})}, 18% {b.parcel_pay({'maint_cut': 0.18})}, "
          f"기름값 절감 180% + 정비비 감소 54% {b.parcel_pay({'fuel_cut': 1.8, 'maint_cut': 0.54})}")
    # ⑤ 곱셈 폭주: 트럭 3대 +25 / 전부 최대 (+30, 부품마다 3줄 프로토타입 중 시간당이 가장 큰 조합, 내 트럭 능력치 돈벌이 59포인트)
    top = b.max_grade

    def best_tot(star):
        best = (0.0, {})
        choices = {pt: [list(c) for c in itertools.combinations_with_replacement(
            [o for o in b.part_options[pt] if b.options[o]["kind"] != "junk"], b.lines_by_grade[top])] for pt in b.parts}
        for combo in itertools.product(*choices.values()):
            tot = b.totals({pt: {"grade": top, "lines": lines} for pt, lines in zip(choices, combo)})
            h = b.hourly(star, tot)
            if h > best[0]:
                best = (h, tot)
        return best[1]
    pts, left = {}, 59
    for k in BUILDS["money"][1]:
        pts[k] = min(b.abilities[k][1], left)
        left -= pts[k]
    ab = b.ab_values(pts)
    print("\n■ v7a 곱셈 폭주 점검 (시간당 매출 = 번 돈 / 내 돈. 급송 뺌. 라이벌 1위 " + won(b.rivals[-1]) + ")")
    print("  경우 | 트럭마다 시간당 번 돈 | 3대 매출 | 3대 내 돈 | +25 1대 세팅 없음의 몇 배")
    one25 = b.hourly(25, {})
    for label, star, with_set, with_ab in [("3대 +25 세팅 없음", 25, False, False), ("3대 +25 세팅 최대", 25, True, False),
                                           ("3대 +30 세팅 최대 + 능력치 59", 30, True, True)]:
        tot = best_tot(star) if with_set else {}
        hs = [b.hourly(star, tot, ab if (with_ab and k == 0) else None) for k in range(3)]
        nets = [b.hourly(star, tot, ab if (with_ab and k == 0) else None, (k > 0, 1)) for k in range(3)]
        print(f"  {label} | " + " / ".join(won(h) for h in hs) + f" | {won(sum(hs))} | {won(sum(nets))} | ×{sum(hs) / one25:.1f}"
              + (f"  (세팅: " + ", ".join(f"{o} {v * 100:g}%" for o, v in sorted(tot.items())) + ")" if with_set else ""))
    # ⑥ 정비비 감소 한 줄의 가치 (이동 속도 한 줄 대비)
    print("\n■ v7a 옵션 한 줄의 가치: 시간당 수입 증가 % (다른 세팅 없음. 목표: 이동 속도 한 줄의 절반~비슷)")
    for star in (18, 25):
        h0 = b.hourly(star, {})
        cells = []
        for g in range(b.max_grade + 1):
            inc = {o: b.hourly(star, {o: b.options[o]["values"][g]}) / h0 - 1 for o in ("speed", "fuel_cut", "maint_cut")}
            cells.append(f"{GRADE_NAMES[g]} 속도 {inc['speed'] * 100:.1f}% · 기름 {inc['fuel_cut'] * 100:.1f}% · 정비 {inc['maint_cut'] * 100:.1f}%"
                         f" (정비÷속도 {inc['maint_cut'] / inc['speed']:.2f})")
        print(f"  +{star}: " + "\n        ".join(cells))
    print()


def main():
    ap = argparse.ArgumentParser(description="경제 시뮬레이터 (v5 기사 레벨·퀘스트·창고·야간팀 + v6-bal 규칙 + v5b 능력치·팁까지)")
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--hours", type=float, default=None, help="하루 켜 두는 시간 (안 주면 가볍게 2.5 + 열심히 8)")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--table", action="store_true", help="단계별 출력·한 바퀴·시간당 수입·강화 비용 표만")
    ap.add_argument("--no-setting", action="store_true", help="세팅 안 돌림 (v3와 비교용. 비교 줄 없음)")
    ap.add_argument("--style", choices=list(STYLES), default=DEFAULT_STYLE,
                    help="명장 유저: " + ", ".join(f"{k}={v}" for k, v in STYLES.items()) + f" (기본 {DEFAULT_STYLE})")
    ap.add_argument("--rush-accept", type=float, default=RUSH_ACCEPT, help=f"급송 전화를 받는 비율 0~1 (기본 {RUSH_ACCEPT})")
    ap.add_argument("--save", type=float, default=SAVE_SHARE,
                    help=f"창업 전 강화 몫 돈 중 창업 자금으로 모으는 비율 0~1 (기본 {SAVE_SHARE}, 0 = 창업 안 함)")
    ap.add_argument("--build", choices=list(BUILDS), default=DEFAULT_BUILD,
                    help="능력치 빌드: " + ", ".join(f"{k}={v[0]}" for k, v in BUILDS.items()) + f" (기본 {DEFAULT_BUILD})")
    a = ap.parse_args()
    if a.hours is not None and not 0 < a.hours <= 24:
        ap.error("--hours 는 0보다 크고 24 이하")
    if not 0.0 <= a.rush_accept <= 1.0:
        ap.error("--rush-accept 는 0~1")
    if not 0.0 <= a.save < 1.0:
        ap.error("--save 는 0 이상 1 미만")
    b = Bal(BALANCE_PATH)
    if a.table:
        table(b)
        table_v7a(b)
        return
    names = {h: name for name, h in PLAYER_TYPES}
    types = PLAYER_TYPES if a.hours is None else [(names.get(a.hours, "직접 정한 시간"), a.hours)]
    for label, hours in types:
        kw = {"build": a.build, "style": a.style, "accept": a.rush_accept, "save": a.save}
        if a.no_setting:
            report(b, label, hours, simulate(b, hours, a.players, a.seed, False, **kw), a.seed, **kw)
        else:
            report(b, label, hours, simulate(b, hours, a.players, a.seed, True, **kw), a.seed,
                   compare=simulate(b, hours, a.players, a.seed, False, **kw),
                   v4=simulate(b, hours, a.players, a.seed, True, v4=True), **kw)


if __name__ == "__main__":
    main()
