"""
택배 방치형 - 경제 시뮬레이터 (v4 세팅 돌리기까지, 판정용)

흉내 내는 것 (v4 게임에 있는 것만):
  트럭 1대, 엔진 강화(성공 / 실패=유지 / 퍼짐 → 스페어 1개 쓰고 +15), 강화 비용 고정표,
  스페어 엔진(고정가 구매 + 배송마다 낮은 확률 드랍, 꺼둔 동안은 평균값),
  한 바퀴 수입(출력 → 속도 → 한 바퀴 초), 기름값·정비비, 꺼둔 동안(상한 시간 × 비율),
  세팅 돌리기(적재함·ECU: 등급업·천장·옵션 뽑기·메모리얼 고르기, 이동 속도·적재량·기름값 절감·엔진 보호·오버부스트).
  기사 레벨·명장·보험·창고 확장·보조 트럭은 아직 없음 (v5~).

계산식은 docs/PROTOTYPE_V3.md·V4.md "계산식" = scripts/core/trip.gd, economy.gd, enhance.gd, setting.gd 와 같다.
  반올림은 Godot roundi와 같게 (0.5는 0에서 먼 쪽. 파이썬 round()는 짝수 쪽이라 안 씀)
  적재량은 게임처럼 floor(… + 1e-9) (딱 떨어져야 할 값이 실수 찌꺼기로 1건 모자라지 않게)
  오버부스트는 평균 한 바퀴 초로 (게임의 "시간당 수입"·꺼둔 동안과 같음)
게임 숫자는 전부 data/balance.json (게임과 같은 파일)의 trip / engine / offline / setting 묶음.

실행:  python -I -X utf8 tools/tune_sim.py                   가볍게(2.5시간)·열심히(8시간) 둘 다, 세팅 있음 (+ 세팅 없음 비교 줄)
       python -I -X utf8 tools/tune_sim.py --hours 2.5      그 시간만
       python -I -X utf8 tools/tune_sim.py --no-setting     세팅 안 돌림 (v3와 비교용)
       python -I -X utf8 tools/tune_sim.py --table          단계별 출력·한 바퀴·시간당 수입·강화 비용 표 (세팅 없음)
       (옵션: --players 1000  --seed 7)
       -X utf8: 막대그래프 글자(█) 때문에 cp949 콘솔에서 필요
판정: "30일" 줄의 지금 단계 중앙값 (기획서 16.7). 최고 도달 단계는 참고만.

플레이어 가정 (시뮬 전용. 게임 숫자 아님):
  - 하루 HOURS시간 켜 둠, 나머지(24 − HOURS)는 꺼 둠 → 다음 날 켤 때 꺼둔 동안 돈·스페어를 받는다
    (게임 Trip.apply_offline과 같음: min(꺼둔 시간, cap_hours) × rate, 스페어는 소수 나머지를 이어 감)
  - 켜 둔 동안 돈은 배송 1건마다 들어온다. 배송은 평균 한 바퀴 속도(N ÷ 평균 한 바퀴 초)로 고르게 나온다고 본다
    (게임은 바퀴 안에서 싣는 시간·집마다 시각이 다르고 오버부스트는 바퀴마다 굴림. 1시간 합계 차이는 2% 안쪽 = C1 테스트)
  - 강화 규칙 ("버는 족족 강화"):
      돈이 생기면 CHECK_HOURS(30분) 안에 화면을 보고, 누를 수 있는 동안 계속 강화를 누른다.
      퍼질 수 있는 단계(+18~)인데 스페어가 0개면 그때 스페어를 1개 산다 (미리 쌓아 두지 않음). +30이면 그만.
  - 세팅 규칙 (하나):
      번 돈(켜 둔 동안 + 꺼둔 동안)의 SETTING_SHARE(20%)는 세팅 몫으로 따로 모으고, 나머지로 강화·스페어를 산다.
      세팅 몫이 돌리기 비용 이상이면 돌린다. 돌릴 부품 = 열린 부품 중 등급이 가장 낮은 것 (같으면 json 순서: 적재함 먼저).
      고르기: 새 상태의 값 ≥ 예전 상태의 값이면 새 것, 아니면 예전 것.
        값 = 평균 시간당 수입 (이동 속도·적재량·기름값 절감·오버부스트가 다 들어감)
             × (1 + min(엔진 보호 합, 상한))  ← 퍼질 수 있는 단계(+18~)에서만. 엔진 보호 10% = 수입 10%로 친다
      (가진 돈의 몇 %를 그때그때 쓰는 규칙은 강화 비용이 큰 뒤에 켤 때마다 모은 돈을 깎아 먹어서 안 씀)
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
SIM_DAYS = 90             # 판정은 30일. 그 뒤는 참고 + 후반 퍼짐 회복 비용용
SNAP_DAYS = [1, 3, 7, 14, 30, 60, 90]
JUDGE_DAY = 30
GRADE_DAYS = [30, 90]     # 부품별 등급 분포를 찍는 날
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
        self.offline_cap = float(off["cap_hours"])
        self.offline_rate = float(off["rate"])
        # --- setting ---
        self.lines_by_grade = [int(x) for x in st_["lines_by_grade"]]
        self.max_grade = len(self.lines_by_grade) - 1
        self.up_chance = [float(x) for x in st_["up_chance"]]
        self.ceiling = [int(x) for x in st_["ceiling"]]
        self.roll_cost = [int(x) for x in st_["roll_cost"]]
        self.cost_cut_cap = float(st_["cost_cut_cap"])
        self.guard_cap = float(st_["engine_guard_cap"])
        self.ob_seconds = float(st_["overboost_seconds"])
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
        return math.floor(self.base_cargo * (1.0 + tot.get("cargo", 0.0)) + 1e-9)

    def parcel_pay(self, tot):
        f, m = tot.get("fuel_cut", 0.0), tot.get("maint_cut", 0.0)
        s = f + m
        if s > self.cost_cut_cap:
            f = f * self.cost_cut_cap / s
            m = m * self.cost_cut_cap / s
        u = self.unit_price
        return u - roundi(u * self.fuel_rate * (1.0 - f)) - roundi(u * self.maint_rate * (1.0 - m))

    def lap_seconds(self, star, tot, boosted=False):
        drive = self.road / self.speed(star, tot)
        if boosted:
            drive -= min(self.ob_seconds, drive / self.ob_mult)
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

    # --- 꺼둔 동안 (Trip.apply_offline, 트럭 1대) ---
    def offline(self, star, tot, hours_away):
        """→ (돈, 배송 수). 꺼둔 시간이 0 이하면 (0, 0)"""
        if hours_away <= 0:
            return 0, 0
        hours = min(hours_away * 3600.0 / 3600.0, self.offline_cap)
        money = math.floor(self.hourly(star, tot) * hours * self.offline_rate)
        parcels = math.floor(self.cargo(tot) * 3600.0 / self.avg_lap_seconds(star, tot) * hours * self.offline_rate)
        return money, parcels

    def daily_income(self, star, tot, hours_on):
        """켜 둔 시간 + 꺼둔 동안 하루 수입 (퍼짐 회복 비용을 며칠치로 바꿀 때)"""
        return self.hourly(star, tot) * hours_on + self.offline(star, tot, 24 - hours_on)[0]

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
    def __init__(self, b, hours, rng, setting):
        self.b, self.H, self.rng, self.setting = b, hours, rng, setting
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
        self.spent = {"engine": 0, "spare": 0, "setting": 0}
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

    def _deliver(self, n):
        """켜 둔 동안 배송 n건: 돈 + 스페어 드랍"""
        self._income(n * self.b.parcel_pay(self.tot))
        while n >= self.next_drop:
            n -= self.next_drop
            self.spares += 1
            self.spares_dropped += 1
            self.next_drop = self._geom()
        self.next_drop -= n

    def _earn(self, hours):
        total = self.frac + self.b.parcels_per_hour(self.star, self.tot) * hours + 1e-9
        n = math.floor(total)
        self.frac = total - n
        self._deliver(n)

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
        if self._value(new_tot) >= self._value(self.tot):
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

    # ---------- 강화 ----------
    def act(self, day):
        """살펴보기 1번: 세팅 몫으로 돌리고, 누를 수 있는 동안 계속 강화. 스페어는 필요할 때 1개만"""
        b = self.b
        self._settings()
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
                self.climbs.append((target, spent / self.b.daily_income(target, self.tot, self.H), day - start))
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
        return wait

    def run(self):
        b, H = self.b, self.H
        snap_set = set(SNAP_DAYS)
        for day in range(1, SIM_DAYS + 1):
            h = 0.0
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
                }
            money, parcels = b.offline(self.star, self.tot, 24 - H)
            self._income(money)
            self.carry += parcels * b.spare_chance
            whole = math.floor(self.carry)
            self.carry -= whole
            self.spares += whole
            self.spares_dropped += whole
        return self


def simulate(b, hours, n, seed, setting):
    master = random.Random(seed)
    return [Player(b, hours, random.Random(master.random()), setting).run() for _ in range(n)]


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


def setting_share(spent):
    total = sum(spent.values())
    return spent["setting"] / total if total > 0 else 0.0


# ======================= 출력 =======================
def table(b):
    tot = {}
    print("=" * 100)
    print(f"■ 단계별 표 (balance.json v{b.version}, 세팅 없음)  배송 1건 {b.parcel_pay(tot)}원 = 단가 {b.unit_price} − 기름값 "
          f"{roundi(b.unit_price * b.fuel_rate)} − 정비비 {roundi(b.unit_price * b.maint_rate)}, 한 바퀴 {b.cargo(tot)}건")
    print("=" * 100)
    print("  단계 | 출력 |  한 바퀴 초 | 한 바퀴 수입 |    시간당 수입 | 하루(2.5h) | 하루(8h) |      강화 비용 | 비용÷시간당")
    for s in range(b.max_star + 1):
        mark = "◀" if s in TABLE_STARS else " "
        cost = b.enhance_cost(s) if s < b.max_star else None
        cost_txt = f"{cost:>14,}" if cost is not None else f"{'-':>14}"
        hrs_txt = f"{cost / b.hourly(s, tot):8.1f}시간" if cost is not None else f"{'-':>12}"
        print(f"  {mark}+{s:<2} | {b.power(s):>4} | {b.lap_seconds(s, tot):>11.4f} | {b.lap_income(tot):>11,} | "
              f"{b.hourly(s, tot):>14.4f} | {won(b.daily_income(s, tot, 2.5)):>10} | {won(b.daily_income(s, tot, 8.0)):>8} | "
              f"{cost_txt} | {hrs_txt}")
    print("  ◀ = C1 테스트(test_trip.gd test_lap_numbers_match_formula)가 찍는 단계. 시간당 수입이 같아야 함")
    print(f"  스페어 {b.spare_price:,}원 고정, 배송마다 {b.spare_chance * 100:g}% 드랍. "
          f"꺼둔 동안 최대 {b.offline_cap:g}시간 × {b.offline_rate * 100:g}%")
    print(f"  세팅 돌리기 1번: " + " / ".join(f"{GRADE_NAMES[g]} {won(c)}" for g, c in enumerate(b.roll_cost)))
    print()


def report(b, label, hours, players, seed, compare=None):
    n = len(players)
    off_h = min(24 - hours, b.offline_cap)
    target = TARGETS.get(hours)
    setting = players[0].setting
    print("=" * 100)
    print(f"■ {label}: 하루 {hours:g}시간 켜 둠, {24 - hours:g}시간 꺼 둠 (→ {off_h:g}시간치 × {b.offline_rate * 100:g}%), "
          f"{n:,}명, seed {seed}, " + (f"세팅 있음 (번 돈의 {SETTING_SHARE * 100:g}%)" if setting else "세팅 없음")
          + (f"  — 목표 30일 +{target}" if target else ""))
    print("=" * 100)
    print("    날짜 | 지금 단계 중앙값 [하위 10% ~ 상위 10%] | 최고 도달(참고) | 퍼짐 평균 | 시간당 수입 중앙값 | 쓴 돈 중 세팅 | 스페어")
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
              f"{st.median(p.snaps[d]['spares'] for p in players):>5g}{mark}")
    if compare is not None:
        cur_c = [p.snaps[JUDGE_DAY]["star"] for p in compare]
        cur = [p.snaps[JUDGE_DAY]["star"] for p in players]
        hr_c = st.median(p.snaps[JUDGE_DAY]["hourly"] for p in compare)
        hr = st.median(p.snaps[JUDGE_DAY]["hourly"] for p in players)
        print(f"  ▶ 세팅 없음과 비교 (같은 seed, {JUDGE_DAY}일째): 지금 단계 중앙값 세팅 있음 +{st.median(cur):g} / 없음 +{st.median(cur_c):g}, "
              f"하위 10% +{pct(cur, 0.1)} / +{pct(cur_c, 0.1)}, 시간당 수입 중앙값 {won(hr)} / {won(hr_c)} ({(hr / hr_c - 1) * 100:+.1f}%)")

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
    ap = argparse.ArgumentParser(description="경제 시뮬레이터 (v4 세팅 돌리기까지)")
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--hours", type=float, default=None, help="하루 켜 두는 시간 (안 주면 가볍게 2.5 + 열심히 8)")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--table", action="store_true", help="단계별 출력·한 바퀴·시간당 수입·강화 비용 표만")
    ap.add_argument("--no-setting", action="store_true", help="세팅 안 돌림 (v3와 비교용)")
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
                   compare=simulate(b, hours, a.players, a.seed, False))


if __name__ == "__main__":
    main()
