"""
택배 방치형 - 튜닝(큐브) 시뮬레이터 (v2 1단계)

트럭 1대 = 엔진(강화 ★) + 튜닝 7칸. 돈을 "가장 이득인 곳"에 쓰는 가상 플레이어로
  - 튜닝 있을 때 / 없을 때 15·18·20·22·25강까지 걸리는 시간
  - 튜닝에 쓴 돈 비율
  - 시간이 지나며 부위 등급이 어떻게 오르나
를 본다.

실행:  python -I -X utf8 tools/tune_sim.py
       (옵션: --players 1000  --hours 8  --seed 7)
       -X utf8: 막대그래프 글자(█) 때문에 cp949 콘솔에서 필요
게임 숫자는 전부 data/balance.json (게임과 같은 파일). 계산식은 docs/PROTOTYPE_V2.md "계산식"과 같다.

플레이어 가정 (시뮬 전용. 게임 숫자 아님):
  - 하루 HOURS시간 켜 둠(기본 8), 나머지는 꺼 둠 → 다음 날 켤 때 꺼둔 동안 수익을 받는다
  - 켜 둔 동안 CHECK_HOURS(30분)마다 살펴보고, 살 수 있는 것 중 이득인 것을 산다
  - "이득" = 목표까지 남은 시간이 얼마나 줄어드나. 목표는 두 가지 플레이어로 본다:
      가까이 보는 플레이어: 다음 목표 강수(15·18·20·22·25 중 지금보다 높은 가장 낮은 것)
      멀리 보는 플레이어: 처음부터 GOAL강
      튜닝 1번의 이득 = 등급업 확률 × (지금 남은 시간 − 등급업하면 남은 시간) − 그 돈을 버는 데 걸리는 시간
    이게 0보다 큰 튜닝이 있으면 (이득/비용이 큰 것부터) 튜닝, 없으면 강화. 고장 나면 스페어부터.
    남은 시간은 퍼짐(15강으로 떨어져 다시 올라오기 + 스페어값)까지 넣은 기댓값
  - 대박 배송은 평균으로 계산 (배송이 시간당 수백 번이라 하루 단위로는 평균과 거의 같음)
  - 튜닝 없음 = 같은 플레이어가 튜닝 버튼을 아예 안 누름
"""
import argparse
import json
import math
import os
import random
import statistics as st

BALANCE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "balance.json")

# 화면 순서 (scripts/core/tune.gd PARTS) → balance.json 효과 이름 (scripts/core/balance.gd TUNE_EFFECT_KEYS)
PARTS = ["turbo", "tire", "cargo", "suspension", "fuel_tank", "navigation", "engine_oil"]
EFFECT_KEYS = {
    "turbo": "turbo_income_bonus", "tire": "tire_jackpot_chance", "cargo": "cargo_jackpot_mult",
    "suspension": "suspension_destroy_cut", "fuel_tank": "fuel_extra_hours",
    "navigation": "navi_extra_rate", "engine_oil": "oil_cost_cut",
}
PART_NAMES = {"turbo": "터보", "tire": "타이어", "cargo": "짐칸", "suspension": "서스펜션",
              "fuel_tank": "연료탱크", "navigation": "내비", "engine_oil": "엔진오일"}
TURBO, TIRE, CARGO, SUS, FUEL, NAVI, OIL = range(7)

# ---------- 시뮬 전용 가정 ----------
MILESTONES = [15, 18, 20, 22, 25]
GOAL = 25                 # 플레이어가 노리는 강수 (여기 닿으면 그 플레이어는 끝)
CHECK_HOURS = 0.5         # 켜 둔 동안 몇 시간마다 살펴보나
MAX_DAYS = 1500           # 이 안에 목표에 못 닿으면 "못 감"
SNAP_DAYS = [1, 3, 7, 14, 30, 60, 90, 180, 365]


def roundf(x):
    """Godot roundf와 같게 (0.5는 0에서 먼 쪽으로)"""
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


class Bal:
    """balance.json 의 income / engine / tune 묶음"""

    def __init__(self, path):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        self.version = d.get("version", "?")
        inc, eng, tune = d["income"], d["engine"], d["tune"]
        self.base = float(inc["base_hourly"])
        self.offline_cap = float(inc["offline_cap_hours"])
        self.offline_rate = float(inc["offline_rate"])
        self.max_star = int(eng["max_star"])
        self.success = eng["success"]
        self.destroy = eng["destroy"]
        self.cost_hours = eng["cost_hours"]
        self.drop_to = int(eng["broken_drop_to"])
        self.spare = float(eng["spare_price"])
        hi = int(inc["high_from_star"])
        self.inc = [self.base * inc["star_mult"] ** min(s, hi - 1) * inc["star_mult_high"] ** max(0, s - (hi - 1))
                    for s in range(self.max_star + 1)]
        self.grades = tune["tune_grades"]
        self.top = len(self.grades) - 1
        self.tune_cost = [roundf(h * self.base) for h in tune["tune_cost_hours"]]
        self.up = tune["tune_up_chance"]
        self.eff = [tune[EFFECT_KEYS[p]] for p in PARTS]


class Model:
    """목표까지 남은 시간 계산 (튜닝 등급 → 남은 시간). HOURS(하루 켜 두는 시간)마다 하나"""

    def __init__(self, b, hours):
        self.b, self.hours = b, hours
        n = b.top + 1
        # P[엔진오일][서스펜션][k] = 0강부터 k강까지 θ 합.
        # θ[k] = k강 → k+1강 평균 몇 시간 (그 강수 엔진 수익만으로 24시간 벌 때. 퍼져서 15강부터 다시 올라오는 시간 포함)
        # 진짜 시간 = θ 합 ÷ mult(튜닝 등급)
        self.P = [[self._prefix(b.eff[OIL][o], b.eff[SUS][s]) for s in range(n)] for o in range(n)]

    def _prefix(self, oil_cut, sus_cut):
        b = self.b
        theta = []
        for k in range(b.max_star):
            p = b.success[k]
            d = b.destroy[k] * (1 - sus_cut)
            reclimb = sum(theta[b.drop_to:k]) if k > b.drop_to else 0.0
            # 1번 누를 때: 강화 비용(엔진오일 반영) / 퍼지면 스페어값 + 15강부터 다시 올라오기. 성공할 때까지 평균
            theta.append((b.cost_hours[k] * (1 - oil_cut) + d * (b.spare / b.inc[k] + reclimb)) / p)
        prefix = [0.0]
        for t in theta:
            prefix.append(prefix[-1] + t)
        return prefix

    def mult(self, g):
        """수익 배수 (엔진 수익 대비 하루 평균): (1 + 터보) × 대박 평균 × (켜 둔 시간 + 꺼둔 동안 몫) / 24"""
        b = self.b
        jack = 1 + b.eff[TIRE][g[TIRE]] * (b.eff[CARGO][g[CARGO]] - 1)
        off = min(24 - self.hours, b.offline_cap + b.eff[FUEL][g[FUEL]]) * (b.offline_rate + b.eff[NAVI][g[NAVI]])
        return (1 + b.eff[TURBO][g[TURBO]]) * jack * (self.hours + off) / 24

    def remaining(self, star, g, goal):
        """goal강까지 남은 시간 (진짜 시간, 시간 단위)"""
        prefix = self.P[g[OIL]][g[SUS]]
        return (prefix[goal] - prefix[star]) / self.mult(g)

    def tune_options(self, star, g, goal):
        """이득이 0보다 큰 튜닝 [(이득/비용, 부위 번호, 비용)] 큰 것부터"""
        b = self.b
        now = self.remaining(star, g, goal)
        earn_per_hour = b.inc[star] * self.mult(g)
        out = []
        for i in range(7):
            gi = g[i]
            if gi >= b.top:
                continue
            g2 = list(g)
            g2[i] = gi + 1
            cost = b.tune_cost[gi]
            gain = b.up[gi] * (now - self.remaining(star, g2, goal)) - cost / earn_per_hour
            if gain > 0:
                out.append((gain / cost, i, cost))
        out.sort(reverse=True)
        return out


def next_goal(star, far):
    """플레이어가 지금 노리는 강수"""
    if far:
        return GOAL
    return next((m for m in MILESTONES if m > star), GOAL)


class Player:
    def __init__(self, b, model, rng, tuning, far):
        self.b, self.m, self.rng, self.tuning, self.far = b, model, rng, tuning, far
        self.star, self.broken, self.g, self.money = 0, False, [0] * 7, 0.0
        self.spent = {"engine": 0.0, "spare": 0.0, "tune": 0.0}
        self.reach = {}          # 강수 → 처음 닿은 날 (진짜 시간, 일)
        self.reach_tune_share = {}
        self.legend_day = {}     # 부위 번호 → 전설 된 날
        self.snaps = {}          # 날 → (강수, 등급들, 튜닝에 쓴 돈 비율)
        self.presses = {"engine": 0, "tune": 0}

    # --- 게임 계산식 (game_state.gd와 같음) ---
    def hourly(self):
        if self.broken:
            return 0.0
        b, g = self.b, self.g
        return b.inc[self.star] * (1 + b.eff[TURBO][g[TURBO]]) * (1 + b.eff[TIRE][g[TIRE]] * (b.eff[CARGO][g[CARGO]] - 1))

    def enhance_cost(self):
        b = self.b
        return roundf(b.cost_hours[self.star] * b.inc[self.star] * (1 - b.eff[OIL][self.g[OIL]]))

    def enhance_need(self):
        return self.enhance_cost() + (self.b.spare if self.b.destroy[self.star] > 0 else 0.0)

    def offline(self, hours_off):
        b, g = self.b, self.g
        if self.broken or hours_off <= 0:
            return 0.0
        return self.hourly() * min(hours_off, b.offline_cap + b.eff[FUEL][g[FUEL]]) * (b.offline_rate + b.eff[NAVI][g[NAVI]])

    def tune_share(self):
        total = sum(self.spent.values())
        return self.spent["tune"] / total if total > 0 else 0.0

    # --- 살펴보기 1번: 살 수 있는 것 중 이득인 것을 계속 산다 ---
    def act(self, now_day):
        b = self.b
        while True:
            if self.broken:
                if self.money < b.spare:
                    return
                self.money -= b.spare
                self.spent["spare"] += b.spare
                self.broken = False
                continue
            if self.star >= GOAL:
                return
            if self.tuning:
                bought = False
                for _, i, cost in self.m.tune_options(self.star, self.g, next_goal(self.star, self.far)):
                    if self.money >= cost:
                        self.money -= cost
                        self.spent["tune"] += cost
                        self.presses["tune"] += 1
                        if self.rng.random() < b.up[self.g[i]]:
                            self.g[i] += 1
                            if self.g[i] == b.top:
                                self.legend_day[i] = now_day
                        bought = True
                        break
                if bought:
                    continue
            if self.money < self.enhance_need():
                return
            cost = self.enhance_cost()
            self.money -= cost
            self.spent["engine"] += cost
            self.presses["engine"] += 1
            p = b.success[self.star]
            d = b.destroy[self.star] * (1 - b.eff[SUS][self.g[SUS]])
            r = self.rng.random()
            if r < p:
                self.star += 1
                if self.star not in self.reach:
                    self.reach[self.star] = now_day
                    self.reach_tune_share[self.star] = self.tune_share()
            elif r < p + d:
                self.star = min(self.star, b.drop_to)
                self.broken = True

    def next_price(self):
        """지금 사고 싶은 것 중 가장 싼 값 (없으면 None)"""
        if self.broken:
            return self.b.spare
        if self.star >= GOAL:
            return None
        prices = [self.enhance_need()]
        if self.tuning:
            prices += [c for _, _, c in self.m.tune_options(self.star, self.g, next_goal(self.star, self.far))]
        return min(prices)

    def run(self):
        H = self.m.hours
        snap_set = set(SNAP_DAYS)
        for day in range(MAX_DAYS):
            if day in snap_set:
                self.snaps[day] = (self.star, tuple(self.g), self.tune_share())
            h = 0.0
            while True:
                self.act((day * 24 + h) / 24)
                if self.star >= GOAL:
                    return self._finish()
                rate, price = self.hourly(), self.next_price()
                if rate <= 0 or price is None:
                    nh = H
                else:
                    nh = h + max(0.0, (price - self.money) / rate)
                    nh = max(h + CHECK_HOURS, math.ceil(nh / CHECK_HOURS - 1e-9) * CHECK_HOURS)
                if nh >= H:
                    self.money += rate * (H - h)
                    break
                self.money += rate * (nh - h)
                h = nh
            self.money += self.offline(24 - H)
        return self._finish()

    def _finish(self):
        for d in SNAP_DAYS:
            self.snaps.setdefault(d, (self.star, tuple(self.g), self.tune_share()))
        return self


def simulate(b, model, n, seed, tuning, far):
    master = random.Random(seed)
    return [Player(b, model, random.Random(master.random()), tuning, far).run() for _ in range(n)]


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def fmt_days(d):
    if d is None:
        return "   -  "
    return f"{d * 24:5.1f}시간" if d < 1 else f"{d:6.1f}일 "


# ======================= 출력 =======================
def price_table(b):
    print("=" * 78)
    print(f"■ 튜닝 가격표 (balance.json v{b.version})")
    print("=" * 78)
    total = 0.0
    for g in range(b.top):
        avg = b.tune_cost[g] / b.up[g]
        total += avg
        print(f"  {b.grades[g]}→{b.grades[g + 1]}: 1번 {b.tune_cost[g]:>7,.0f}원, 등급업 {b.up[g] * 100:4.1f}% "
              f"→ 평균 {1 / b.up[g]:5.1f}번, 약 {avg:>11,.0f}원")
    print(f"  한 부위 전설까지 평균 약 {total:,.0f}원 / 7부위 약 {total * 7:,.0f}원")
    print("  이 돈이 몇 시간치 수익인가 (엔진만): " + " / ".join(
        f"{s}강 {total / b.inc[s]:,.0f}시간" for s in [10, 15, 18, 20, 22, 25]))
    print("  부위 효과 (" + " / ".join(b.grades) + "):")
    for i, p in enumerate(PARTS):
        print(f"    {PART_NAMES[p]:<5} {' / '.join(f'{v:g}' for v in b.eff[i])}")
    print()


def report(b, model, far, with_tune, no_tune):
    n = len(with_tune)
    print("=" * 78)
    who = f"멀리 보는 플레이어 (처음부터 {GOAL}강 목표)" if far else "가까이 보는 플레이어 (다음 목표 강수만 봄)"
    print(f"■ {who}")
    print(f"  {n:,}명 × 2 (튜닝 있음 / 없음), 하루 {model.hours:g}시간 켜 둠, {CHECK_HOURS * 60:.0f}분마다 살펴봄")
    print("=" * 78)

    print("\n  ▶ 강수까지 걸린 진짜 시간 (중간값 [빠른 10% ~ 느린 10%])")
    print("    강수 |        튜닝 있음                 |        튜닝 없음                 | 없음÷있음 | 그때 튜닝에 쓴 돈")
    for m in MILESTONES:
        row = []
        meds = []
        for ps in (with_tune, no_tune):
            days = [p.reach[m] for p in ps if m in p.reach]
            if len(days) < n // 2:
                row.append(f"{'절반 넘게 못 감':^31}")
                meds.append(None)
                continue
            med = st.median(days)
            meds.append(med)
            row.append(f"{fmt_days(med)} [{fmt_days(pct(days, 0.1))}~{fmt_days(pct(days, 0.9))}]")
        speed = f"{meds[1] / meds[0]:5.2f}배" if meds[0] and meds[1] else "   -  "
        shares = [p.reach_tune_share[m] for p in with_tune if m in p.reach_tune_share]
        share = f"{st.median(shares) * 100:5.1f}%" if shares else "-"
        print(f"    {m:>2}강 | {row[0]} | {row[1]} |  {speed}  | {share}")
    for label, ps in (("튜닝 있음", with_tune), ("튜닝 없음", no_tune)):
        got = sum(1 for p in ps if GOAL in p.reach)
        print(f"    {label}: {MAX_DAYS}일 안에 {GOAL}강 {got / n * 100:.1f}%")

    print(f"\n  ▶ 돈 쓴 곳 ({GOAL}강 닿을 때까지, 튜닝 있음, 중간값)")
    tot = lambda p: sum(p.spent.values())
    for k, label in (("engine", "강화"), ("spare", "스페어"), ("tune", "튜닝")):
        print(f"    {label:<4} {st.median([p.spent[k] / tot(p) * 100 for p in with_tune]):5.1f}%  "
              f"(평균 {st.mean([p.spent[k] for p in with_tune]):>14,.0f}원)")
    print(f"    버튼 누른 횟수: 강화 {st.median([p.presses['engine'] for p in with_tune]):,.0f}번 / "
          f"튜닝 {st.median([p.presses['tune'] for p in with_tune]):,.0f}번  "
          f"(튜닝 없음: 강화 {st.median([p.presses['engine'] for p in no_tune]):,.0f}번)")

    print("\n  ▶ 시간별 부위 등급 (튜닝 있음, 평균 등급 0 일반 ~ 3 전설 / 아래 줄은 강수 중간값)")
    head = "    날짜  " + "".join(f"{PART_NAMES[p]:>7}" for p in PARTS) + "   | 강수(있음/없음) | 튜닝 돈 비율"
    print(head)
    for d in SNAP_DAYS:
        avg = [st.mean(p.snaps[d][1][i] for p in with_tune) for i in range(7)]
        star_t = st.median(p.snaps[d][0] for p in with_tune)
        star_n = st.median(p.snaps[d][0] for p in no_tune)
        share = st.median(p.snaps[d][2] for p in with_tune) * 100
        print(f"    {d:>3}일  " + "".join(f"{a:7.2f}" for a in avg) + f"   |   {star_t:4.0f} / {star_n:<4.0f}    |  {share:5.1f}%")

    print("\n  ▶ 부위별 전설 된 날 (중간값, 전설까지 간 플레이어 비율)")
    for i, p in enumerate(PARTS):
        days = [pl.legend_day[i] for pl in with_tune if i in pl.legend_day]
        if days:
            bar = "█" * min(40, int(st.median(days) / 2))
            print(f"    {PART_NAMES[p]:<5} {fmt_days(st.median(days))} ({len(days) / n * 100:5.1f}%) {bar}")
        else:
            print(f"    {PART_NAMES[p]:<5} 아무도 전설까지 안 감")

    print("\n  ▶ 일반→레어 튜닝 1번(100원)의 이득 (전부 일반일 때. 목표까지 줄어드는 시간 − 100원 버는 시간, 분)")
    print("    강수 " + "".join(f"{PART_NAMES[p]:>8}" for p in PARTS))
    for s in [0, 10, 15, 18, 20, 22]:
        g = [0] * 7
        goal = next_goal(s, far)
        now = model.remaining(s, g, goal)
        cells = []
        for i in range(7):
            g2 = list(g)
            g2[i] = 1
            cost = b.tune_cost[0]
            gain = b.up[0] * (now - model.remaining(s, g2, goal)) - cost / (b.inc[s] * model.mult(g))
            cells.append(f"{gain * 60:8.1f}")
        print(f"    {s:>2}강 " + "".join(cells))
    print()


def main():
    ap = argparse.ArgumentParser(description="튜닝(큐브) 시뮬레이터")
    ap.add_argument("--players", type=int, default=1000)
    ap.add_argument("--hours", type=float, default=8.0, help="하루 켜 두는 시간")
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args()
    b = Bal(BALANCE_PATH)
    model = Model(b, a.hours)
    price_table(b)
    no_tune = simulate(b, model, a.players, a.seed, False, False)
    for far in (False, True):
        report(b, model, far, simulate(b, model, a.players, a.seed, True, far), no_tune)


if __name__ == "__main__":
    main()
