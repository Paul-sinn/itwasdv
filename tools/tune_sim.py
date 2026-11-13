"""
택배 방치형 - 경제 시뮬레이터 (v5 기사 레벨·퀘스트·창고·야간팀 + v6-bal 규칙까지, 판정용)

흉내 내는 것 (v6-bal 게임에 있는 것만):
  트럭 1대, 엔진 강화(성공 / 실패=유지 / 퍼짐 → 스페어 1개 쓰고 +15), 강화 비용 고정표,
  스페어 엔진(고정가 구매 + 배송마다 낮은 확률 드랍, 꺼둔 동안은 평균값),
  한 바퀴 수입(출력 → 속도 → 한 바퀴 초), 기름값·정비비,
  꺼둔 동안(창고 레벨 시간 × 야간팀 레벨 비율, 3분 미만 무시),
  세팅 돌리기(적재함·ECU: 등급업·천장·옵션 뽑기·메모리얼 고르기, 이동 속도·적재량·기름값 절감·엔진 보호·오버부스트),
  기사 레벨(켜 둔 동안 배송 경험치 + 강화 첫 달성 보너스 + 퀘스트 보상, 만렙 뒤 평판), 퀘스트 22개(보상 돈·경험치),
  창고 확장·야간 배송팀 사기.
  능력치·명장·보험·보조 트럭은 아직 없음 (v5b~). 능력치 포인트는 쌓이기만 해서 경제에 영향 없음.

계산식은 docs/PROTOTYPE_V3~V5.md "계산식" + PROTOTYPE_V6_BAL.md "바뀌는 규칙" = scripts/core/trip.gd, economy.gd,
enhance.gd, setting.gd, driver.gd, depot.gd, quest.gd 와 같다.
  반올림은 Godot roundi와 같게 (0.5는 0에서 먼 쪽. 파이썬 round()는 짝수 쪽이라 안 씀)
  적재량은 평균값 그대로 (게임 Trip.cargo: 21.6처럼 소수. 정수에 1e-9 안쪽이면 정수로).
    게임은 바퀴마다 소수점을 굴려 21 또는 22건을 싣지만 평균은 같아서, 시뮬은 평균으로 센다 (게임의 시간당 수입·꺼둔 동안과 같음)
  오버부스트: 걸린 바퀴는 바퀴 내내 운전 속도 overboost_mult배 (= 달리는 초 ÷ overboost_mult). 시뮬은 평균 한 바퀴 초로
    (게임의 "시간당 수입"·꺼둔 동안과 같음)
게임 숫자는 전부 data/balance.json (게임과 같은 파일)의 trip / engine / offline / setting / driver / depot / quests.

실행:  python -I -X utf8 tools/tune_sim.py                   가볍게(2.5시간)·열심히(8시간) 둘 다, 세팅 있음
                                                             (+ 세팅 없음 비교 줄, v4 숫자 비교 줄)
       python -I -X utf8 tools/tune_sim.py --hours 2.5      그 시간만
       python -I -X utf8 tools/tune_sim.py --no-setting     세팅 안 돌림 (v3와 비교용)
       python -I -X utf8 tools/tune_sim.py --table          단계별 출력·한 바퀴·시간당 수입·강화 비용 표 (세팅 없음)
       (옵션: --players 1000  --seed 7)
       -X utf8: 막대그래프 글자(█) 때문에 cp949 콘솔에서 필요
판정: "30일" 줄의 지금 단계 중앙값 (기획서 16.7). 최고 도달 단계는 참고만.
v4 숫자 비교: 같은 유저를 꺼둔 동안 V4_OFFLINE(8시간 × 50%) 고정, 창고·야간팀·퀘스트 없이(= v4 게임) 돌린 결과.

플레이어 가정 (시뮬 전용. 게임 숫자 아님):
  - 하루 HOURS시간 켜 둠, 나머지(24 − HOURS)는 꺼 둠 → 다음 날 켤 때 꺼둔 동안 돈·스페어·배송 수를 받는다
    (게임 Trip.apply_offline과 같음: min(꺼둔 시간, 창고 시간) × 야간팀 비율, 스페어는 소수 나머지를 이어 감.
     3분 미만 무시는 하루에 한 번 길게 꺼 두는 이 시뮬에서는 --hours 24 근처가 아니면 영향 없음. 꺼둔 동안 경험치는 0)
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
  - 퍼진 뒤 회복 비용: 퍼진 순간부터 원래 단계로 다시 올라갈 때까지 강화·스페어에 쓴 돈을
    "원래 단계에서의 하루 수입(켜 둔 시간 + 꺼둔 동안)"으로 나눈 값. 퍼질 때 쓴 스페어 1개와 세팅 돈은 안 셈
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
EFFECTS = ["speed", "cargo", "fuel_cut", "engine_guard", "overboost"]


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
        # --- driver (기사 레벨) ---
        drv = d["driver"]
        self.max_level = int(drv["max_level"])
        self.xp_per_parcel = int(drv["xp_per_parcel"])
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
        self.cost_cut_cap = float(st_["cost_cut_cap"])
        self.guard_cap = float(st_["engine_guard_cap"])
        self.ob_mult = float(st_["overboost_mult"])
        self.options = {}
        for oid, o in st_["options"].items():
            values = [0.0] * len(self.lines_by_grade) if o["kind"] == "junk" else [float(v) for v in o["values"]]
            self.options[oid] = {"kind": o["kind"], "weight": float(o["weight"]), "values": values}
        self.parts = list(st_["parts"].keys())   # json 순서
        self.unlock = {p: int(st_["parts"][p]["unlock_star"]) for p in self.parts}
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

    def parcel_pay(self, tot):
        f, m = tot.get("fuel_cut", 0.0), tot.get("maint_cut", 0.0)
        s = f + m
        if s > self.cost_cut_cap:
            f = f * self.cost_cut_cap / s
            m = m * self.cost_cut_cap / s
        u = self.unit_price
        return u - roundi(u * self.fuel_rate * (1.0 - f)) - roundi(u * self.maint_rate * (1.0 - m))

    def lap_seconds(self, star, tot, boosted=False):
        """한 바퀴 초 (정차는 평균 적재량). 걸린 바퀴는 달리는 초 ÷ overboost_mult"""
        drive = self.road / self.speed(star, tot)
        if boosted:
            drive /= self.ob_mult
        return self.load + drive + self.cargo(tot) * self.stop

    def avg_lap_seconds(self, star, tot):
        p = min(tot.get("overboost", 0.0), 1.0)
        return self.lap_seconds(star, tot, False) * (1.0 - p) + self.lap_seconds(star, tot, True) * p

    def lap_income(self, tot):
        return self.cargo(tot) * self.parcel_pay(tot)

    def hourly(self, star, tot):
        return self.lap_income(tot) * 3600.0 / self.avg_lap_seconds(star, tot)

    def parcels_per_hour(self, star, tot):
        return self.cargo(tot) * 3600.0 / self.avg_lap_seconds(star, tot)

    # --- Economy / Enhance ---
    def enhance_cost(self, star):
        return roundi(self.cost_base * self.cost_mult ** star)

    def needs_spare(self, star):
        return 0 <= star < self.max_star and self.destroy[star] > 0.0

    def destroy_chance(self, star, tot):
        """Enhance.chances_for: 퍼짐 × (1 − min(엔진 보호, 상한))"""
        return self.destroy[star] * (1.0 - min(tot.get("engine_guard", 0.0), self.guard_cap))

    # --- 꺼둔 동안 (Trip.apply_offline, 트럭 1대). cap·rate = 창고 시간·야간팀 비율 (Depot.cap_hours / rate) ---
    def offline(self, star, tot, hours_away, cap, rate):
        """→ (돈, 배송 수). 꺼둔 시간이 3분(ignore_under_seconds) 미만이면 (0, 0)"""
        if hours_away * 3600.0 < self.ignore_under:
            return 0, 0
        hours = min(hours_away, cap)
        money = math.floor(self.hourly(star, tot) * hours * rate)
        parcels = math.floor(self.cargo(tot) * 3600.0 / self.avg_lap_seconds(star, tot) * hours * rate)
        return money, parcels

    def daily_income(self, star, tot, hours_on, cap, rate):
        """켜 둔 시간 + 꺼둔 동안 하루 수입 (퍼짐 회복 비용을 며칠치로 바꿀 때, 창고·야간팀 사기 기준)"""
        return self.hourly(star, tot) * hours_on + self.offline(star, tot, 24 - hours_on, cap, rate)[0]

    def lv1_offline(self):
        """창고·야간팀 Lv1 (새 게임)의 (시간, 비율)"""
        return self.depot_values["warehouse"][0], self.depot_values["night"][0]

    # --- Depot ---
    def depot_price(self, kind, level):
        """다음 레벨 가격 (Depot.price). 더 못 사면 None"""
        if level >= self.depot_buyable[kind]:
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


class Player:
    def __init__(self, b, hours, rng, setting, v4=False):
        """v4 = v4 숫자 비교용: 꺼둔 동안 V4_OFFLINE 고정, 창고·야간팀·퀘스트 없음"""
        self.b, self.H, self.rng, self.setting, self.v4 = b, hours, rng, setting, v4
        self.share = SETTING_SHARE if setting else 0.0
        self.star = 0
        self.money = 0.0          # 강화·스페어 몫
        self.set_money = 0.0      # 세팅 몫
        self.spares = 0
        self.carry = 0.0          # 꺼둔 동안 스페어 소수 나머지 (GameState.spare_drop_carry)
        self.frac = 0.0           # 켜 둔 동안 배송 소수 진행
        self.parts = {p: {"grade": 0, "lines": [], "counters": [0] * (b.max_grade + 1)} for p in b.parts}
        self.tot = {}
        self.next_drop = self._geom()
        self.best = 0
        self.destroys = 0
        self.presses = 0
        self.rolls = 0
        self.spares_bought = 0
        self.spares_dropped = 0
        self.spent = {"engine": 0, "spare": 0, "setting": 0, "depot": 0}
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
        p = self.b.spare_chance
        if p <= 0:
            return math.inf
        if p >= 1:
            return 1
        return int(math.log(1.0 - self.rng.random()) / math.log(1.0 - p)) + 1

    def _income(self, amount):
        self.money += amount * (1.0 - self.share)
        self.set_money += amount * self.share

    # ---------- 꺼둔 동안·창고·야간팀 ----------
    def cap_rate(self):
        """꺼둔 동안 (시간, 비율): 창고·야간팀 레벨 (v4 비교는 고정)"""
        if self.v4:
            return V4_OFFLINE
        return self.b.depot_values["warehouse"][self.depot["warehouse"] - 1], self.b.depot_values["night"][self.depot["night"] - 1]

    def daily(self, star=None):
        return self.b.daily_income(self.star if star is None else star, self.tot, self.H, *self.cap_rate())

    def _depot_next(self):
        """규칙에 맞는 다음 업그레이드 (kind, 가격): 창고 → 야간팀 순서, 가격 ≤ 하루 수입 × DEPOT_DAYS. 없으면 None"""
        if self.v4:
            return None
        limit = self.daily() * DEPOT_DAYS
        for kind, _ in DEPOT_KINDS:
            price = self.b.depot_price(kind, self.depot[kind])
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
            price = self.b.depot_price(q["kind"], self.depot[q["kind"]])
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
        while self.level < b.max_level and self.xp >= b.xp_need[self.level]:
            self.xp -= b.xp_need[self.level]
            self.level += 1
        if self.level >= b.max_level:
            self.reputation += self.xp
            self.xp = 0
            self.max_at = when or (self.t_day, self.on_hours)

    def _star_reached(self):
        """Driver.on_star_reached: 그 단계 이상의 보너스 단계 중 처음인 것마다"""
        for m in self.b.milestones:
            if self.star >= m and m not in self.milestones_done:
                self.milestones_done.add(m)
                self._add_xp(self.b.milestone_xp)

    def _quest_value(self, q):
        k = q["kind"]
        if k == "parcels":
            return self.parcels_total
        if k == "star":
            return self.star
        if k == "setting_rolls":
            return self.rolls
        if k == "setting_grade":
            return max(p["grade"] for p in self.parts.values())
        if k == "part_rolled":
            return 1 if q.get("part") in self.parts_rolled else 0
        if k == "spares_bought":
            return self.spares_bought
        if k in self.depot:
            return self.depot[k]
        if k == "level":
            return self.level
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
        if self.level < b.max_level and b.xp_per_parcel > 0 and rate > 0:
            k = math.ceil((b.xp_to_max[self.level] - self.xp) / b.xp_per_parcel)   # 만렙이 되는 배송 번호
            if k <= n:
                t = min(hours, max(0.0, (k - frac0) / rate))
                when = (self.t_day + t / 24.0, self.on_hours + t)
        self._add_xp(n * b.xp_per_parcel, when)
        self._income(n * self.b.parcel_pay(self.tot))
        while n >= self.next_drop:
            n -= self.next_drop
            self.spares += 1
            self.spares_dropped += 1
            self.next_drop = self._geom()
        self.next_drop -= n

    def _earn(self, hours):
        rate = self.b.parcels_per_hour(self.star, self.tot)
        frac0 = self.frac
        total = frac0 + rate * hours + 1e-9
        n = math.floor(total)
        self.frac = total - n
        self._deliver(n, hours, frac0, rate)
        self.on_hours += hours
        self.t_day += hours / 24.0
        self._quests()   # 배송 수·레벨 퀘스트 (게임은 advance마다)

    def _spend(self, amount, kind):
        self.money -= amount
        self.spent[kind] += amount
        for c in self.open_climbs:
            c[1] += amount

    # ---------- 세팅 ----------
    def _roll_part(self):
        """돌릴 부품: 열린 부품 중 등급이 가장 낮은 것 (같으면 json 순서). 없으면 None"""
        b = self.b
        best = None
        for p in b.parts:
            if self.star >= b.unlock[p] and (best is None or self.parts[p]["grade"] < self.parts[best]["grade"]):
                best = p
        return best

    def _value(self, tot):
        v = self.b.hourly(self.star, tot)
        if self.b.needs_spare(self.star):
            v *= 1.0 + min(tot.get("engine_guard", 0.0), self.b.guard_cap)
        return v

    def _roll(self, part):
        """Setting.try_roll + choose (값이 같거나 높으면 새 것)"""
        b, rng = self.b, self.rng
        p = self.parts[part]
        g = p["grade"]
        cost = b.roll_cost[g]
        self.set_money -= cost
        self.spent["setting"] += cost
        self.rolls += 1
        self.parts_rolled.add(part)
        up = False
        if g < b.max_grade:
            p["counters"][g] += 1
            if p["counters"][g] >= b.ceiling[g]:
                up = True
            elif rng.random() < b.up_chance[g]:
                up = True
            if up:
                p["counters"][g] = 0
        ng = g + 1 if up else g
        cum, ids, total = b.draw_table[(part, ng)]
        lines = [ids[min(len(ids) - 1, bisect.bisect_right(cum, rng.random() * total))] for _ in range(b.lines_by_grade[ng])]
        new_parts = dict(self.parts)
        new_parts[part] = {"grade": ng, "lines": lines, "counters": p["counters"]}
        new_tot = b.totals(new_parts)
        if up or self._value(new_tot) >= self._value(self.tot):
            p["grade"], p["lines"] = ng, lines
            self.tot = new_tot

    def _settings(self):
        if not self.setting:
            return
        while True:
            part = self._roll_part()
            cost = None if part is None else self.b.roll_cost[self.parts[part]["grade"]]
            if part is None or self.set_money < cost:
                return
            self._roll(part)
            if cost <= 0:
                return   # 공짜 돌리기면 살펴볼 때 1번만 (끝없이 돌지 않게)

    # ---------- 살펴보기 ----------
    def act(self, day):
        """살펴보기 1번: 퀘스트 → 세팅 → 창고·야간팀 → 강화. 그사이 끝난 퀘스트가 있으면 (보상 돈으로) 한 번 더"""
        while True:
            self._quests()
            self._buy_for_quest()
            self._settings()
            self._buy_depot()
            self._enhance(day)
            if not self._quests():
                return

    def _enhance(self, day):
        """누를 수 있는 동안 계속 강화. 스페어는 필요할 때 1개만"""
        b = self.b
        while self.star < b.max_star:
            if b.needs_spare(self.star) and self.spares == 0:
                if self.money < b.spare_price:
                    return
                self._spend(b.spare_price, "spare")
                self.spares += 1
                self.spares_bought += 1
                continue
            cost = b.enhance_cost(self.star)
            if self.money < cost:
                return
            self._spend(cost, "engine")
            self.presses += 1
            r = self.rng.random()            # Enhance.decide_chances: 성공 → 퍼짐 → 실패 순서
            s, d = b.success[self.star], b.destroy_chance(self.star, self.tot)
            if r < s:
                self.star += 1
                self.best = max(self.best, self.star)
                self._star_reached()
                self._close_climbs(day)
                self._settings()             # ECU가 열렸을 수 있음
            elif r < s + d:
                self.destroys += 1
                self.open_climbs.append([self.star, 0, day])
                self.spares -= 1
                self.star = min(self.star, b.drop_to)

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
        """다음에 살펴볼 때까지 (강화·스페어 또는 세팅 돌리기가 될 때까지) 몇 시간"""
        b = self.b
        pay = b.parcel_pay(self.tot)
        rate = b.parcels_per_hour(self.star, self.tot)
        wait = math.inf
        if self.star < b.max_star:
            price = b.spare_price if b.needs_spare(self.star) and self.spares == 0 else b.enhance_cost(self.star)
            wait = self._hours_until(price - self.money, pay * (1.0 - self.share), rate)
        part = self._roll_part() if self.setting else None
        if part is not None:
            wait = min(wait, self._hours_until(b.roll_cost[self.parts[part]["grade"]] - self.set_money, pay * self.share, rate))
        for nxt in (self._depot_next(), self._quest_buy()):
            if nxt is not None:
                wait = min(wait, self._hours_until(nxt[1] - self.money, pay * (1.0 - self.share), rate))
        return wait

    def run(self):
        b, H = self.b, self.H
        snap_set = set(SNAP_DAYS)
        for day in range(1, SIM_DAYS + 1):
            h = 0.0
            self.t_day = day - 1
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
            if day in snap_set:
                self.snaps[day] = {
                    "star": self.star, "best": self.best, "destroys": self.destroys,
                    "money": self.money + self.set_money, "spares": self.spares,
                    "grades": {p: (self.parts[p]["grade"] if self.star >= b.unlock[p] else -1) for p in b.parts},
                    "spent": dict(self.spent), "hourly": b.hourly(self.star, self.tot), "tot": dict(self.tot),
                    "level": self.level, "depot": dict(self.depot), "quests": self.quest_index,
                }
            money, parcels = b.offline(self.star, self.tot, 24 - H, *self.cap_rate())
            self._income(money)
            self.parcels_total += parcels
            self.carry += parcels * b.spare_chance
            whole = math.floor(self.carry)
            self.carry -= whole
            self.spares += whole
            self.spares_dropped += whole
        return self


def simulate(b, hours, n, seed, setting, v4=False):
    master = random.Random(seed)
    return [Player(b, hours, random.Random(master.random()), setting, v4).run() for _ in range(n)]


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
    print()


def report(b, label, hours, players, seed, compare=None, v4=None):
    n = len(players)
    lv1 = b.lv1_offline()
    target = TARGETS.get(hours)
    setting = players[0].setting
    print("=" * 100)
    print(f"■ {label}: 하루 {hours:g}시간 켜 둠, {24 - hours:g}시간 꺼 둠 (창고·야간팀 Lv1 {lv1[0]:g}시간 × {lv1[1] * 100:g}%에서 시작, "
          f"하루 수입의 {DEPOT_DAYS:g}배 이하면 삼), "
          f"{n:,}명, seed {seed}, " + (f"세팅 있음 (번 돈의 {SETTING_SHARE * 100:g}%)" if setting else "세팅 없음")
          + (f"  — 목표 30일 +{target}" if target else ""))
    print("=" * 100)
    print("    날짜 | 지금 단계 중앙값 [하위 10% ~ 상위 10%] | 최고 도달(참고) | 퍼짐 평균 | 시간당 수입 중앙값 | 쓴 돈 중 세팅 | 스페어 "
          "| 기사 Lv | 퀘스트")
    for d in SNAP_DAYS:
        cur = [p.snaps[d]["star"] for p in players]
        best = [p.snaps[d]["best"] for p in players]
        mark = " ← 판정" if d == JUDGE_DAY else ""
        if d == JUDGE_DAY and target:
            mark += f" (목표 +{target}: {'맞음' if st.median(cur) >= target else '모자람'})"
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


def main():
    ap = argparse.ArgumentParser(description="경제 시뮬레이터 (v5 기사 레벨·퀘스트·창고·야간팀 + v6-bal 규칙까지)")
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--hours", type=float, default=None, help="하루 켜 두는 시간 (안 주면 가볍게 2.5 + 열심히 8)")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--table", action="store_true", help="단계별 출력·한 바퀴·시간당 수입·강화 비용 표만")
    ap.add_argument("--no-setting", action="store_true", help="세팅 안 돌림 (v3와 비교용. 비교 줄 없음)")
    a = ap.parse_args()
    if a.hours is not None and not 0 < a.hours <= 24:
        ap.error("--hours 는 0보다 크고 24 이하")
    b = Bal(BALANCE_PATH)
    if a.table:
        table(b)
        return
    names = {h: name for name, h in PLAYER_TYPES}
    types = PLAYER_TYPES if a.hours is None else [(names.get(a.hours, "직접 정한 시간"), a.hours)]
    for label, hours in types:
        if a.no_setting:
            report(b, label, hours, simulate(b, hours, a.players, a.seed, False), a.seed)
        else:
            report(b, label, hours, simulate(b, hours, a.players, a.seed, True), a.seed,
                   compare=simulate(b, hours, a.players, a.seed, False),
                   v4=simulate(b, hours, a.players, a.seed, True, v4=True))


if __name__ == "__main__":
    main()
