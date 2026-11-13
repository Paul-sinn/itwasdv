"""
택배 방치형 - 경제 시뮬레이터 (v3 경제 뼈대, 판정용)

흉내 내는 것 (v3 게임에 있는 것만):
  트럭 1대, 엔진 강화(성공 / 실패=유지 / 퍼짐 → 스페어 1개 쓰고 +15), 강화 비용 고정표,
  스페어 엔진(고정가 구매 + 배송마다 낮은 확률 드랍, 꺼둔 동안은 평균값),
  한 바퀴 수입(출력 → 속도 → 한 바퀴 초), 기름값·정비비, 꺼둔 동안(상한 시간 × 비율).
  세팅·기사 레벨·명장·보험·창고 확장·보조 트럭은 아직 없음 (v4~).

계산식은 docs/PROTOTYPE_V3.md "계산식" = scripts/core/trip.gd, economy.gd, enhance.gd 와 같다.
  반올림은 Godot roundi와 같게 (0.5는 0에서 먼 쪽. 파이썬 round()는 짝수 쪽이라 안 씀)
게임 숫자는 전부 data/balance.json (게임과 같은 파일)의 trip / engine / offline 묶음.

실행:  python -I -X utf8 tools/tune_sim.py                   가볍게(2.5시간)·열심히(8시간) 둘 다
       python -I -X utf8 tools/tune_sim.py --hours 2.5      그 시간만
       python -I -X utf8 tools/tune_sim.py --table          단계별 출력·한 바퀴·시간당 수입·강화 비용 표
       (옵션: --players 1000  --seed 7)
       -X utf8: 막대그래프 글자(█) 때문에 cp949 콘솔에서 필요
판정: "30일" 줄의 지금 단계 중앙값 (기획서 16.7). 최고 도달 단계는 참고만.

플레이어 가정 (시뮬 전용. 게임 숫자 아님):
  - 하루 HOURS시간 켜 둠, 나머지(24 − HOURS)는 꺼 둠 → 다음 날 켤 때 꺼둔 동안 돈·스페어를 받는다
    (게임 Trip.apply_offline과 같음: min(꺼둔 시간, cap_hours) × rate, 스페어는 소수 나머지를 이어 감)
  - 켜 둔 동안 돈은 배송 1건마다 들어온다. 배송은 한 바퀴 평균 속도(N ÷ 한 바퀴 초)로 고르게 나온다고 본다
    (게임은 바퀴 안에서 싣는 시간·집마다 시각이 다름. 1시간 합계 차이는 한 바퀴치 안쪽 = C1 테스트 ②)
  - 행동 규칙 하나 ("버는 족족 강화"):
      돈이 생기면 CHECK_HOURS(30분) 안에 화면을 보고, 누를 수 있는 동안 계속 강화를 누른다.
      퍼질 수 있는 단계(+18~)인데 스페어가 0개면 그때 스페어를 1개 산다 (미리 쌓아 두지 않음).
      +30이 되면 더 안 누름.
  - 퍼진 뒤 회복 비용: 퍼진 순간부터 원래 단계로 다시 올라갈 때까지 쓴 돈(강화 + 스페어 구매)을
    "원래 단계에서의 하루 수입(켜 둔 시간 + 꺼둔 동안)"으로 나눈 값. 퍼질 때 쓴 스페어 1개는 안 셈
"""
import argparse
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
SIM_DAYS = 90             # 판정은 30일. 그 뒤는 참고 + 후반 퍼짐 회복 비용용
SNAP_DAYS = [1, 3, 7, 14, 30, 60, 90]
JUDGE_DAY = 30
TABLE_STARS = [0, 10, 18, 30]   # C1 테스트 ①이 찍는 단계


def roundi(x):
    """Godot roundi와 같게 (0.5는 0에서 먼 쪽으로)"""
    if x < 0:
        return -roundi(-x)
    f = math.floor(x)
    return int(f) + (1 if x - f >= 0.5 else 0)


class Bal:
    """balance.json 의 trip / engine / offline 묶음 + 게임 계산식 (trip.gd, economy.gd)"""

    def __init__(self, path):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        self.version = d.get("version", "?")
        trip, eng, off = d["trip"], d["engine"], d["offline"]
        self.unit_price = int(trip["unit_price"])
        self.cargo = int(trip["base_cargo"])
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

    # --- Trip ---
    def power(self, star):
        return self.base_power + sum(self.power_gain[:star])

    def lap_seconds(self, star):
        return self.load + self.road / float(self.power(star)) + self.cargo * self.stop

    def parcel_pay(self):
        u = self.unit_price
        return u - roundi(u * self.fuel_rate) - roundi(u * self.maint_rate)

    def lap_income(self):
        return self.cargo * self.parcel_pay()

    def hourly(self, star):
        return self.lap_income() * 3600.0 / self.lap_seconds(star)

    def parcels_per_hour(self, star):
        return self.cargo * 3600.0 / self.lap_seconds(star)

    # --- Economy / Enhance ---
    def enhance_cost(self, star):
        return roundi(self.cost_base * self.cost_mult ** star)

    def needs_spare(self, star):
        return 0 <= star < self.max_star and self.destroy[star] > 0.0

    # --- 꺼둔 동안 (Trip.apply_offline, 트럭 1대) ---
    def offline(self, star, hours_away):
        """→ (돈, 배송 수). 꺼둔 시간이 0 이하면 (0, 0)"""
        if hours_away <= 0:
            return 0, 0
        hours = min(hours_away * 3600.0 / 3600.0, self.offline_cap)
        money = math.floor(self.hourly(star) * hours * self.offline_rate)
        parcels = math.floor(self.cargo * 3600.0 / self.lap_seconds(star) * hours * self.offline_rate)
        return money, parcels

    def daily_income(self, star, hours_on):
        """켜 둔 시간 + 꺼둔 동안 하루 수입 (퍼짐 회복 비용을 며칠치로 바꿀 때)"""
        return self.hourly(star) * hours_on + self.offline(star, 24 - hours_on)[0]


class Player:
    def __init__(self, b, hours, rng):
        self.b, self.H, self.rng = b, hours, rng
        self.star = 0
        self.money = 0
        self.spares = 0
        self.carry = 0.0          # 꺼둔 동안 스페어 소수 나머지 (GameState.spare_drop_carry)
        self.frac = 0.0           # 켜 둔 동안 배송 소수 진행
        self.next_drop = self._geom()
        self.best = 0
        self.destroys = 0
        self.presses = 0
        self.spares_bought = 0
        self.spares_dropped = 0
        self.spent = {"engine": 0, "spare": 0}
        self.open_climbs = []     # [원래 단계, 그동안 쓴 돈, 퍼진 날]
        self.climbs = []          # (원래 단계, 쓴 돈 ÷ 원래 단계 하루 수입, 걸린 날)
        self.snaps = {}           # 날 → (지금 단계, 최고 단계, 퍼짐 횟수, 돈, 스페어)

    def _geom(self):
        """다음 스페어 드랍까지 배송 몇 건 (배송마다 spare_chance 확률 = 기하분포)"""
        p = self.b.spare_chance
        if p <= 0:
            return math.inf
        if p >= 1:
            return 1
        return int(math.log(1.0 - self.rng.random()) / math.log(1.0 - p)) + 1

    def _deliver(self, n):
        """켜 둔 동안 배송 n건: 돈 + 스페어 드랍"""
        self.money += n * self.b.parcel_pay()
        while n >= self.next_drop:
            n -= self.next_drop
            self.spares += 1
            self.spares_dropped += 1
            self.next_drop = self._geom()
        self.next_drop -= n

    def _earn(self, hours):
        total = self.frac + self.b.parcels_per_hour(self.star) * hours + 1e-9
        n = math.floor(total)
        self.frac = total - n
        self._deliver(n)

    def _spend(self, amount, kind):
        self.money -= amount
        self.spent[kind] += amount
        for c in self.open_climbs:
            c[1] += amount

    def act(self, day):
        """살펴보기 1번: 누를 수 있는 동안 계속 누른다. 스페어는 필요할 때 1개만"""
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
            r = self.rng.random()            # Enhance.decide: 성공 → 퍼짐 → 실패 순서
            s, d = b.success[self.star], b.destroy[self.star]
            if r < s:
                self.star += 1
                self.best = max(self.best, self.star)
                self._close_climbs(day)
            elif r < s + d:
                self.destroys += 1
                self.open_climbs.append([self.star, 0, day])
                self.spares -= 1
                self.star = min(self.star, b.drop_to)

    def _close_climbs(self, day):
        still = []
        for target, spent, start in self.open_climbs:
            if self.star >= target:
                self.climbs.append((target, spent / self.b.daily_income(target, self.H), day - start))
            else:
                still.append([target, spent, start])
        self.open_climbs = still

    def next_price(self):
        """지금 모으는 돈 (없으면 None)"""
        b = self.b
        if self.star >= b.max_star:
            return None
        if b.needs_spare(self.star) and self.spares == 0:
            return b.spare_price
        return b.enhance_cost(self.star)

    def run(self):
        b, H = self.b, self.H
        snap_set = set(SNAP_DAYS)
        for day in range(1, SIM_DAYS + 1):
            h = 0.0
            while True:
                self.act(day - 1 + h / 24)
                price = self.next_price()
                rate = b.parcels_per_hour(self.star)
                if price is None:
                    nh = H
                else:
                    parcels = max(0, math.ceil((price - self.money) / b.parcel_pay()))
                    nh = h + max(0.0, parcels - self.frac) / rate
                    nh = max(h + CHECK_HOURS, math.ceil(nh / CHECK_HOURS - 1e-9) * CHECK_HOURS)
                if nh >= H:
                    self._earn(H - h)
                    break
                self._earn(nh - h)
                h = nh
            if day in snap_set:
                self.snaps[day] = (self.star, self.best, self.destroys, self.money, self.spares)
            money, parcels = b.offline(self.star, 24 - H)
            self.money += money
            self.carry += parcels * b.spare_chance
            whole = math.floor(self.carry)
            self.carry -= whole
            self.spares += whole
            self.spares_dropped += whole
        return self


def simulate(b, hours, n, seed):
    master = random.Random(seed)
    return [Player(b, hours, random.Random(master.random())).run() for _ in range(n)]


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


# ======================= 출력 =======================
def table(b):
    print("=" * 96)
    print(f"■ 단계별 표 (balance.json v{b.version})  배송 1건 {b.parcel_pay()}원 = 단가 {b.unit_price} − 기름값 "
          f"{roundi(b.unit_price * b.fuel_rate)} − 정비비 {roundi(b.unit_price * b.maint_rate)}, 한 바퀴 {b.cargo}건")
    print("=" * 96)
    print("  단계 | 출력 |  한 바퀴 초 | 한 바퀴 수입 |   시간당 수입 | 하루(2.5h) | 하루(8h) |    강화 비용 | 비용÷시간당")
    for s in range(b.max_star + 1):
        mark = "◀" if s in TABLE_STARS else " "
        cost = b.enhance_cost(s) if s < b.max_star else None
        cost_txt = f"{cost:>12,}" if cost is not None else f"{'-':>12}"
        hrs_txt = f"{cost / b.hourly(s):8.1f}시간" if cost is not None else f"{'-':>12}"
        print(f"  {mark}+{s:<2} | {b.power(s):>4} | {b.lap_seconds(s):>11.4f} | {b.lap_income():>11,} | "
              f"{b.hourly(s):>13.4f} | {won(b.daily_income(s, 2.5)):>10} | {won(b.daily_income(s, 8.0)):>8} | "
              f"{cost_txt} | {hrs_txt}")
    print("  ◀ = C1 테스트 ①(test_trip.gd test_lap_numbers_match_formula)이 찍는 단계. 시간당 수입이 같아야 함")
    print(f"  스페어 {b.spare_price:,}원 고정, 배송마다 {b.spare_chance * 100:g}% 드랍. "
          f"꺼둔 동안 최대 {b.offline_cap:g}시간 × {b.offline_rate * 100:g}%")
    print()


def report(b, label, hours, players, seed):
    n = len(players)
    off_h = min(24 - hours, b.offline_cap)
    target = TARGETS.get(hours)
    print("=" * 96)
    print(f"■ {label}: 하루 {hours:g}시간 켜 둠, {24 - hours:g}시간 꺼 둠 (→ {off_h:g}시간치 × {b.offline_rate * 100:g}%), "
          f"{n:,}명, seed {seed}" + (f"  — 목표 30일 +{target}" if target else ""))
    print("=" * 96)
    print("    날짜 | 지금 단계 중앙값 [하위 10% ~ 상위 10%] | 최고 도달(참고) | 퍼짐 평균 | 들고 있는 돈 중앙값 | 스페어 중앙값")
    for d in SNAP_DAYS:
        cur = [p.snaps[d][0] for p in players]
        best = [p.snaps[d][1] for p in players]
        mark = " ← 판정" if d == JUDGE_DAY else ""
        if d == JUDGE_DAY and target:
            mark += f" (목표 +{target}: {'맞음' if st.median(cur) >= target else '모자람'})"
        print(f"    {d:>3}일 |        +{st.median(cur):<4g} [+{pct(cur, 0.1):<2} ~ +{pct(cur, 0.9):<2}]"
              f"            |     +{st.median(best):<4g}      |  {st.mean(p.snaps[d][2] for p in players):6.2f}   | "
              f"{won(st.median(p.snaps[d][3] for p in players)):>18} | {st.median(p.snaps[d][4] for p in players):>8g}{mark}")

    judge = [p.snaps[JUDGE_DAY][0] for p in players]
    print(f"\n  ▶ {JUDGE_DAY}일째 지금 단계 분포")
    for s in range(min(judge), max(judge) + 1):
        k = sum(1 for x in judge if x == s)
        if k:
            print(f"    +{s:<2} {k / n * 100:5.1f}% {'█' * round(k / n * 100)}")

    print(f"\n  ▶ {SIM_DAYS}일 동안: 강화 {st.median(p.presses for p in players):,.0f}번 (중앙값), "
          f"스페어 산 것 평균 {st.mean(p.spares_bought for p in players):.2f}개 / 드랍 평균 {st.mean(p.spares_dropped for p in players):.2f}개, "
          f"쓴 돈 중 스페어 {st.median(p.spent['spare'] / max(1, p.spent['engine'] + p.spent['spare']) for p in players) * 100:.1f}% (중앙값)")

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
    ap = argparse.ArgumentParser(description="경제 시뮬레이터 (v3 경제 뼈대)")
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--hours", type=float, default=None, help="하루 켜 두는 시간 (안 주면 가볍게 2.5 + 열심히 8)")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--table", action="store_true", help="단계별 출력·한 바퀴·시간당 수입·강화 비용 표만")
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
        report(b, label, hours, simulate(b, hours, a.players, a.seed), a.seed)


if __name__ == "__main__":
    main()
