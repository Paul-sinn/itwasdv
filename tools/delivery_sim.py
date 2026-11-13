"""
택배 방치형 게임 - 경제 시뮬레이터 v0.4

이번 버전:
  - 모든 가격을 "택배 수익" 기준으로 책정 (강화 1번 = 그 강수 트럭이 몇 시간 버는 돈)
  - 메이플 스타포스 확률표 참고. 실패 = 유지(하락 없음). 우리 게임은 더 순하게.
  - 돈 수급처 6종: 일반 배송 / 주소 불명 택배 / 극한 배송(빡센 지형) / 틀린 주소 찾기 /
    주간 퀘스트 / 급행 전화
  - 회사 규모에 따라 트럭 최대 대수가 늘어남
  - 가상 유저 1만 명 30일: 몇 강까지 가나, 엔진 퍼져서 몇 명 접나
  - "메이플 확률 그대로였다면"과 비교

사용법: `python tools/delivery_sim.py` 실행. 외부 라이브러리 필요 없음.
게임 숫자(확률, 가격, 수익)는 data/balance.json 에서 읽음. 게임과 시뮬이 같은 파일을 씀.
숫자를 바꾸려면 balance.json 을 고칠 것. (아래 [설정]의 게임 숫자는 파일이 없을 때만 쓰는 예비값)
유저 구성·접는 확률 같은 "시뮬 전용 가정"만 이 파일의 7, 8번 설정에서 고침.
주의: "접는 확률"은 실제 데이터가 아니라 가정값임. 출시 후 실제 수치로 바꿔야 함.
"""
import json
import os
import random
import statistics as st

# ============================ [설정] ============================
SEED = 7
N_PLAYERS = 10000
DAYS = 30

# ---------- 1. 수익 (모든 가격의 기준) ----------
BASE_HOURLY = 1000        # +0강 트럭 1대가 1시간에 버는 돈
STAR_MULT = 1.10          # 엔진 1강마다 수익 x1.10 (HIGH_FROM_STAR 전까지)
STAR_MULT_HIGH = 1.30     # HIGH_FROM_STAR강부터는 1강마다 x1.30 (수익이 확 오르는 구간)
HIGH_FROM_STAR = 20       # 이 강수가 되는 순간부터 STAR_MULT_HIGH (19→20강부터)
DRIVER_CUT = 0.8          # 부캐 트럭은 기사 월급 떼고 80%
OFFLINE_CAP_HOURS = 8     # 꺼둔 동안 최대 8시간치
OFFLINE_RATE = 0.5        # 꺼둔 동안은 50%

# ---------- 2. 엔진 강화 확률 ----------
MAX_STAR = 30
# 메이플 스타포스 (참고용, 비교 시뮬에 씀)
MAPLE_SUCCESS = [.9975, .945, .8925, .8925, .84, .7875, .735, .6825, .63, .5775,
                 .525, .4725, .42, .3675, .315, .315, .315, .1575, .1575, .1575,
                 .315, .1575, .1575, .105, .105, .105, .0735, .0525, .0315, .0105]
MAPLE_DESTROY = [0.0] * 15 + [.02055, .02055, .0674, .0674, .08425, .10275, .126375,
                              .1685, .179, .179, .179, .1853, .1895, .1937, .1979]
# 우리 게임 (순한 맛): 17강까지는 메이플과 거의 같고 퍼짐 없음, 18강부터 퍼짐(메이플보다 조금 낮게)
OUR_SUCCESS = [.9975, .945, .8925, .8925, .84, .7875, .735, .6825, .63, .5775,
               .525, .4725, .42, .3675, .315, .315, .315, .25, .20, .20,
               .30, .15, .15, .10, .10, .10, .07, .05, .03, .01]
OUR_DESTROY = [0.0] * 18 + [.05, .06, .07, .08, .10, .12, .12, .12, .14, .15, .16, .17]
OUR_BROKEN_DROP_TO = 15   # 퍼지면 15강 고장 엔진
MAPLE_BROKEN_DROP_TO = 12 # 메이플식: 12강으로

# ---------- 3. 가격 (수익 기준) ----------
# 강화 1번 비용 = "그 강수 트럭이 몇 시간 버는 돈"
COST_HOURS = [.02, .03, .04, .05, .07, .10, .13, .17, .22, .30,     # 0~9   (1~18분)
              .40, .55, .75, 1.0, 1.4,                              # 10~14
              4, 6, 9,                                              # 15~17
              14, 20,                                               # 18~19
              25, 35, 45, 60, 80,                                   # 20~24
              100, 130, 160, 200, 250]                              # 25~29
SPARE_PRICE = 50000       # 스페어 엔진 = 강수와 상관없는 고정 금액
# 튜닝(큐브) 1번 비용 = +0강 트럭 몇 시간치 (등급별)
TUNE_GRADES = ["일반", "레어", "에픽", "전설"]
TUNE_BONUS = [0.0, 0.10, 0.25, 0.50]
TUNE_COST_HOURS = [0.1, 1.5, 20]
TUNE_UP_CHANCE = [0.15, 0.05, 0.015]

# ---------- 4. 회사 규모 & 트럭 ----------
# (이름, 트럭 최대 대수, 승급 비용 = +0강 트럭 몇 시간치)
COMPANY_TIERS = [("개인사업자", 1, 0), ("동네 영업소", 3, 40), ("시내 지점", 5, 600),
                 ("지역 물류센터", 8, 6000), ("전국 물류회사", 11, 60000), ("물류 재벌", 15, 600000)]
TRUCK_PRICE_HOURS = 30    # 첫 부캐 트럭 = +0강 트럭 30시간치
TRUCK_PRICE_GROWTH = 2.0  # 한 대 살 때마다 x2
SUB_TRUCK_STAR_CAP = 17   # 부캐는 안전 구간까지만

# ---------- 5. 돈 수급처 ----------
# (1) 일반 배송: 위 수익 그대로 (방치)
# (2) 주소 불명 택배
PARCELS_PER_DAY = 3
PARCEL_TABLE = [("cash", 0.37), ("tune_kit", 0.30), ("protect", 0.10),
                ("spare", 0.03), ("nothing", 0.20)]
PARCEL_CASH_HOURS = 1.0   # 전체 수익 1시간치
# (3) 극한 배송(빡센 지형): 본캐 강수가 요구치 넘어야 도전 가능. 보상 = 본캐 수익 N시간치
EXTREME_PER_DAY = 2
EXTREME_TIERS = [(5, 1.0), (10, 1.5), (15, 2.0), (18, 3.0), (20, 4.0), (23, 6.0), (26, 8.0)]
EXTREME_SUCCESS = 0.9
# (4) 틀린 주소 찾기(힌트 미니게임): 직접 플레이. 성공률 = 유저 실력
ADDRESS_PER_DAY = 3
ADDRESS_REWARD_HOURS = 0.5  # 전체 수익 30분치
# (5) 주간 퀘스트
WEEKLY_REWARD_HOURS = 8     # 전체 수익 8시간치 + 방지권 1장
# (6) 급행 전화: 받으면 60%로 대박, 40%로 위약금
CALLS_PER_DAY = 1
CALL_WIN_CHANCE, CALL_WIN_HOURS, CALL_LOSE_HOURS = 0.6, 2.0, 0.5

# ---------- 6. 튜닝 데이 (매주 일요일, 3종 돌아가며) ----------
EVENT_DAY = 6
EVENT_KINDS = ["퍼짐 확률 30% 감소", "강화 비용 30% 할인", "튜닝 등급업 2배"]

# ---------- 7. 유저 구성 (가정) ----------
PLAY_TYPES = [("라이트", 0.30, 1, 3), ("미들", 0.50, 4, 8), ("헤비", 0.20, 10, 16)]  # 하루 켜두는 시간
SPEND_TYPES = [("본캐파", 0.30, 0.2), ("균형파", 0.40, 0.5), ("회사파", 0.30, 0.8)]   # 수익 중 회사 확장에 넣는 비율
PARK_TARGETS = [(17, 0.25), (20, 0.40), (22, 0.25), (30, 0.10)]  # 본캐 몇 강에서 멈추나
SAVER_SHARE = 0.30        # 튜닝 데이에만 지르는 존버 유저 비율
CAREFUL_SHARE = 0.60      # 스페어값 남겨두고만 지르는 신중한 유저 비율
CALL_TAKER_SHARE = 0.60   # 급행 전화 받는 유저 비율

# ---------- 8. 접는 확률 (가정! 실제 데이터 아님) ----------
QUIT_PER_PAIN_DAY = 0.04  # 퍼졌을 때 "복구에 드는 돈이 며칠치 벌이냐" 1일당 접을 확률 4%
QUIT_CAP = 0.60
QUIT_PER_BROKEN_DAY = 0.05  # 본캐가 고장난 채로 하루 지날 때마다 5%
# ================================================================

# ---------- balance.json 읽기 (게임과 같은 숫자 쓰기) ----------
BALANCE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "data", "balance.json")
_ALIAS = {"success": "OUR_SUCCESS", "destroy": "OUR_DESTROY",
          "broken_drop_to": "OUR_BROKEN_DROP_TO",
          "turbo_income_bonus": "TUNE_BONUS"}   # v2: 튜닝 1칸 = 터보로 봄
# v2 튜닝 7칸 중 터보 말고 나머지 효과: 이 시뮬은 튜닝을 1칸(터보)으로만 보니 조용히 넘김 (tools/tune_sim.py가 봄)
_SKIP = {"tire_jackpot_chance", "cargo_jackpot_mult", "suspension_destroy_cut",
         "fuel_extra_hours", "navi_extra_rate", "oil_cost_cut"}


def load_balance(path=BALANCE_PATH):
    if not os.path.exists(path):
        print(f"(balance.json 없음 → 파일 안의 예비값 사용: {path})")
        return
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    for section in data.values():
        if not isinstance(section, dict):
            continue
        for key, value in section.items():
            if key in _SKIP:
                continue
            name = _ALIAS.get(key, key.upper())
            if name in globals():
                globals()[name] = value
            else:
                print(f"(경고) balance.json의 '{key}'는 시뮬이 모르는 항목")
    print(f"(balance.json v{data.get('version', '?')} 읽음)")


load_balance()

INC = [BASE_HOURLY * STAR_MULT ** min(s, HIGH_FROM_STAR - 1)
       * STAR_MULT_HIGH ** max(0, s - (HIGH_FROM_STAR - 1)) for s in range(MAX_STAR + 1)]
COST = [COST_HOURS[s] * INC[s] for s in range(MAX_STAR)]
TUNE_COST = [h * BASE_HOURLY for h in TUNE_COST_HOURS]


def pick(rng, table):
    r, acc = rng.random(), 0.0
    for item in table:
        acc += item[1]
        if r < acc:
            return item
    return table[-1]


class Rules:
    def __init__(self, name, success, destroy, drop_to):
        self.name, self.p, self.d, self.drop_to = name, success, destroy, drop_to
        self.first_destroy = next(i for i, x in enumerate(destroy) if x > 0)

    def reclimb(self, frm, to):
        return sum(COST[s] / self.p[s] for s in range(frm, to))


class Truck:
    __slots__ = ("star", "tune", "broken", "broke_at")

    def __init__(self):
        self.star, self.tune, self.broken, self.broke_at = 0, 0, False, 0


class Player:
    def __init__(self, rng, rules):
        self.rng, self.rules = rng, rules
        pt = pick(rng, PLAY_TYPES)
        self.play_type = pt[0]
        self.hours = rng.uniform(pt[2], pt[3])
        sp = pick(rng, SPEND_TYPES)
        self.spend_type, self.fund_rate = sp[0], sp[2]
        self.park = pick(rng, PARK_TARGETS)[0]
        self.saver = rng.random() < SAVER_SHARE
        self.careful = rng.random() < CAREFUL_SHARE
        self.takes_calls = rng.random() < CALL_TAKER_SHARE
        self.skill = rng.uniform(0.4, 0.9)
        self.wallet, self.fund = 0.0, 0.0
        self.trucks = [Truck()]
        self.tier = 0
        self.protect = self.spares = self.free_tunes = 0
        self.best = 0
        self.destroyed = 0
        self.presses = 0
        self.quit_day, self.quit_why = None, None
        self.src = dict.fromkeys(["일반 배송", "주소 불명 택배", "극한 배송",
                                  "틀린 주소 찾기", "주간 퀘스트", "급행 전화"], 0.0)
        self.reach = {}

    # ---------- 수익 ----------
    def truck_income(self, i):
        t = self.trucks[i]
        if t.broken:
            return 0.0
        inc = INC[t.star] * (1 + TUNE_BONUS[t.tune])
        return inc if i == 0 else inc * DRIVER_CUT

    def hourly(self):
        return sum(self.truck_income(i) for i in range(len(self.trucks)))

    def gain(self, source, amount):
        self.src[source] += amount
        if self.next_expansion() is not None:
            self.fund += amount * self.fund_rate
            self.wallet += amount * (1 - self.fund_rate)
        else:
            self.wallet += amount

    # ---------- 회사 확장 ----------
    def next_expansion(self):
        n = len(self.trucks)
        if n < COMPANY_TIERS[self.tier][1]:
            return "truck", TRUCK_PRICE_HOURS * BASE_HOURLY * TRUCK_PRICE_GROWTH ** (n - 1)
        if self.tier + 1 < len(COMPANY_TIERS):
            return "tier", COMPANY_TIERS[self.tier + 1][2] * BASE_HOURLY
        return None

    def expand(self):
        while True:
            nx = self.next_expansion()
            if nx is None:
                self.wallet += self.fund
                self.fund = 0.0
                return
            kind, price = nx
            if self.fund < price:
                return
            self.fund -= price
            if kind == "truck":
                self.trucks.append(Truck())
            else:
                self.tier += 1

    # ---------- 강화 ----------
    def spare_price(self, star):
        return SPARE_PRICE   # 고정 금액 (star는 안 씀)

    def repair(self):
        for t in self.trucks:
            if not t.broken:
                continue
            price = self.spare_price(t.broke_at)
            if self.spares > 0:
                self.spares -= 1
                t.broken = False
            elif self.wallet + self.fund >= price:
                use = min(self.wallet, price)
                self.wallet -= use
                self.fund -= price - use
                t.broken = False

    def try_engine(self, i, event, day):
        t, R = self.trucks[i], self.rules
        cost = COST[t.star] * (0.7 if event == 1 else 1.0)
        self.wallet -= cost
        self.presses += 1
        p, d = R.p[t.star], R.d[t.star]
        if event == 0:
            d *= 0.7
        if d > 0 and self.protect > 0:
            self.protect -= 1
            d = 0.0
        r = self.rng.random()
        if r < p:
            t.star += 1
            if i == 0:
                self.best = max(self.best, t.star)
                self.reach.setdefault(t.star, day)
        elif r < p + d:
            before = t.star
            t.broke_at, t.star, t.broken = before, R.drop_to, True
            self.destroyed += 1
            if i == 0:
                daily = max(self.hourly_before * self.eff_hours, 1.0)
                pain = (self.spare_price(before) + R.reclimb(R.drop_to, before)) / daily
                if self.rng.random() < min(QUIT_CAP, QUIT_PER_PAIN_DAY * pain):
                    self.quit_day, self.quit_why = day, "퍼진 직후 홧김에"
                    return
            self.repair()

    def try_tune(self, i, event, free=False):
        t = self.trucks[i]
        if not free:
            self.wallet -= TUNE_COST[t.tune]
        self.presses += 1
        up = TUNE_UP_CHANCE[t.tune] * (2.0 if event == 2 else 1.0)
        if self.rng.random() < up:
            t.tune += 1

    def best_option(self, event):
        R, best = self.rules, None
        for i, t in enumerate(self.trucks):
            if t.broken:
                continue
            cut = 1.0 if i == 0 else DRIVER_CUT
            cap = self.park if i == 0 else SUB_TRUCK_STAR_CAP
            if t.star < cap:
                cost = COST[t.star] * (0.7 if event == 1 else 1.0)
                need = cost
                if R.d[t.star] > 0 and self.careful and self.spares == 0 and self.protect == 0:
                    need += self.spare_price(t.star)
                if need <= self.wallet:
                    gain = INC[t.star + 1] / INC[t.star] - 1   # 한 강 오를 때 수익 증가 비율 (20강부터 커짐)
                    v = INC[t.star] * (1 + TUNE_BONUS[t.tune]) * cut * gain * R.p[t.star] / cost
                    if best is None or v > best[0]:
                        best = (v, "engine", i)
            if t.tune < 3 and TUNE_COST[t.tune] <= self.wallet:
                up = TUNE_UP_CHANCE[t.tune] * (2.0 if event == 2 else 1.0)
                v = INC[t.star] * cut * (TUNE_BONUS[t.tune + 1] - TUNE_BONUS[t.tune]) * up / TUNE_COST[t.tune]
                if best is None or v > best[0]:
                    best = (v, "tune", i)
        return best

    # ---------- 하루 ----------
    def play_day(self, day):
        rng = self.rng
        event = (day // 7) % 3 if day % 7 == EVENT_DAY else None
        self.eff_hours = self.hours + min(24 - self.hours, OFFLINE_CAP_HOURS) * OFFLINE_RATE
        hourly = self.hourly_before = self.hourly()
        main = self.trucks[0]

        self.gain("일반 배송", hourly * self.eff_hours)
        for _ in range(PARCELS_PER_DAY):
            kind = pick(rng, PARCEL_TABLE)[0]
            if kind == "cash":
                self.gain("주소 불명 택배", hourly * PARCEL_CASH_HOURS)
            elif kind == "tune_kit":
                self.free_tunes += 1
            elif kind == "protect":
                self.protect += 1
            elif kind == "spare":
                self.spares += 1
        if not main.broken:
            tier = [h for req, h in EXTREME_TIERS if main.star >= req]
            if tier:
                for _ in range(EXTREME_PER_DAY):
                    if rng.random() < EXTREME_SUCCESS:
                        self.gain("극한 배송", self.truck_income(0) * tier[-1])
        for _ in range(ADDRESS_PER_DAY):
            if rng.random() < self.skill:
                self.gain("틀린 주소 찾기", hourly * ADDRESS_REWARD_HOURS)
        if day % 7 == 0:
            self.gain("주간 퀘스트", hourly * WEEKLY_REWARD_HOURS)
            self.protect += 1
        if self.takes_calls:
            for _ in range(CALLS_PER_DAY):
                if rng.random() < CALL_WIN_CHANCE:
                    self.gain("급행 전화", hourly * CALL_WIN_HOURS)
                else:
                    self.gain("급행 전화", -hourly * CALL_LOSE_HOURS)

        self.expand()
        self.repair()
        while self.free_tunes > 0:
            c = [i for i, t in enumerate(self.trucks) if t.tune < 3]
            if not c:
                break
            self.free_tunes -= 1
            self.try_tune(c[0], event, free=True)

        if not self.saver or event is not None:
            for _ in range(600):
                opt = self.best_option(event)
                if opt is None:
                    break
                if opt[1] == "engine":
                    self.try_engine(opt[2], event, day)
                    if self.quit_day:
                        return
                else:
                    self.try_tune(opt[2], event)

        if main.broken and rng.random() < QUIT_PER_BROKEN_DAY:
            self.quit_day, self.quit_why = day, "수리비 못 모아서"


# ======================= 출력 =======================
def price_table(rules):
    print("=" * 74)
    print("■ 가격표 (수익 기준)")
    print(f"  기준: +0강 트럭 1대 = 시간당 {BASE_HOURLY:,}")
    print("=" * 74)
    print("  강화    | 성공   | 퍼짐  | 1번 비용      | 그 트럭 몇 시간치 | 평균 몇 번 눌러야 성공")
    for s in [0, 5, 10, 12, 15, 17, 18, 19, 20, 21, 22, 25, 27, 29]:
        print(f"  {s:>2}→{s + 1:<2}강 | {rules.p[s] * 100:5.1f}% | {rules.d[s] * 100:4.1f}% "
              f"| {COST[s]:>12,.0f} | {COST_HOURS[s]:>8.2f}시간      | {1 / rules.p[s]:5.1f}번")
    print(f"\n  스페어 엔진: 고정 {SPARE_PRICE:,.0f} (18강 수익 {SPARE_PRICE / INC[18]:.1f}시간치 / "
          f"22강 {SPARE_PRICE / INC[22]:.1f}시간치 / 25강 {SPARE_PRICE / INC[25]:.1f}시간치)")
    print("  시간당 수익: " + " / ".join(f"{s}강 {INC[s]:,.0f}" for s in [0, 10, 18, 19, 20, 22, 25, 30]))
    print("  튜닝 1번: " + " / ".join(f"{g}→{TUNE_GRADES[i + 1]} {TUNE_COST[i]:,.0f} "
                                    f"(등급업 {TUNE_UP_CHANCE[i] * 100:.1f}%)"
                                    for i, g in enumerate(TUNE_GRADES[:3])))
    print("  회사 규모:")
    for name, slots, hrs in COMPANY_TIERS:
        print(f"    {name:<8} 트럭 최대 {slots:>2}대  (승급 비용 {hrs * BASE_HOURLY:>12,.0f})")
    print("  부캐 트럭 가격: " + ", ".join(
        f"{k + 2}번째 {TRUCK_PRICE_HOURS * BASE_HOURLY * TRUCK_PRICE_GROWTH ** k:,.0f}"
        for k in [0, 1, 3, 6, 9, 13]))
    print()


def simulate(rules, n):
    master = random.Random(SEED)
    ps = [Player(random.Random(master.random()), rules) for _ in range(n)]
    quits_by_day = {}
    for day in range(1, DAYS + 1):
        for p in ps:
            if p.quit_day is None:
                p.play_day(day)
        quits_by_day[day] = sum(1 for p in ps if p.quit_day)
    return ps, quits_by_day


def share(ps, cond):
    return sum(1 for p in ps if cond(p)) / len(ps) * 100


def report(ps, quits_by_day, rules):
    n = len(ps)
    alive = [p for p in ps if p.quit_day is None]
    print("=" * 74)
    print(f"■ [{rules.name}] 가상 유저 {n:,}명, {DAYS}일 후")
    print("=" * 74)

    print("\n  ▶ 본캐 엔진 강수 (30일차, 안 접은 유저 기준 / 괄호는 한 번이라도 찍어본 최고 기록)")
    bands = [("10강 이하", 0, 10), ("11~14강", 11, 14), ("15~17강", 15, 17), ("18~19강", 18, 19),
             ("20강", 20, 20), ("21~22강", 21, 22), ("23강 이상", 23, 30)]
    for label, lo, hi in bands:
        cur = share(alive, lambda p: lo <= p.trucks[0].star <= hi)
        best = share(ps, lambda p: lo <= p.best <= hi)
        print(f"    {label:<9} {cur:5.1f}%  ({best:5.1f}%)  {'█' * int(cur / 2)}")
    for m in [18, 20, 22, 25]:
        days = [p.reach[m] for p in ps if m in p.reach]
        if days:
            print(f"    +{m}강 찍어본 유저: {len(days) / n * 100:5.1f}%  (보통 {st.median(days):.0f}일차)")
        else:
            print(f"    +{m}강 찍어본 유저:   0.0%")

    print("\n  ▶ 유형별 (보통 값)")
    print("    유형     | 본캐 강수 | 트럭 수 | 시간당 수익  | 하루 강화 버튼")
    for name, _, _, _ in PLAY_TYPES:
        g = [p for p in alive if p.play_type == name]
        print(f"    {name:<6} | +{st.median([p.trucks[0].star for p in g]):.0f}강     "
              f"| {st.median([len(p.trucks) for p in g]):.0f}대    "
              f"| {st.median([p.hourly() for p in g]):>10,.0f}  | {st.median([p.presses / DAYS for p in g]):.0f}번")
    for name, _, _ in SPEND_TYPES:
        g = [p for p in alive if p.spend_type == name]
        print(f"    {name:<6} | +{st.median([p.trucks[0].star for p in g]):.0f}강     "
              f"| {st.median([len(p.trucks) for p in g]):.0f}대    "
              f"| {st.median([p.hourly() for p in g]):>10,.0f}  | {st.median([p.presses / DAYS for p in g]):.0f}번")

    print("\n  ▶ 회사 규모 (30일차)")
    for i, (name, slots, _) in enumerate(COMPANY_TIERS):
        print(f"    {name:<8} {share(alive, lambda p: p.tier == i):5.1f}%")
    print(f"    트럭 대수: 하위 10% {sorted(len(p.trucks) for p in alive)[len(alive) // 10]}대 / "
          f"보통 {st.median([len(p.trucks) for p in alive]):.0f}대 / "
          f"상위 10% {sorted(len(p.trucks) for p in alive)[len(alive) * 9 // 10]}대")

    print("\n  ▶ 엔진 퍼짐과 접는 유저 (접는 확률은 가정값)")
    print(f"    한 번이라도 퍼진 유저: {share(ps, lambda p: p.destroyed > 0):.1f}%"
          f"  (퍼진 유저 평균 {st.mean([p.destroyed for p in ps if p.destroyed] or [0]):.1f}번)")
    q = [p for p in ps if p.quit_day]
    print(f"    접은 유저: {len(q):,}명 ({len(q) / n * 100:.1f}%)")
    for why in ["퍼진 직후 홧김에", "수리비 못 모아서"]:
        print(f"      - {why}: {sum(1 for p in q if p.quit_why == why):,}명")
    print("    누적 접은 유저: " + " / ".join(f"{d}일 {quits_by_day[d]:,}명" for d in [7, 14, 21, 30]))
    for target, _ in PARK_TARGETS:
        g = [p for p in ps if p.park == target]
        label = "끝까지 지르는 유저" if target == 30 else f"{target}강에서 멈추는 유저"
        print(f"      {label}: {sum(1 for p in g if p.quit_day) / len(g) * 100:.1f}%가 접음")

    print("\n  ▶ 돈 수급처별 비중 (30일 합계)")
    for name, _, _, _ in PLAY_TYPES:
        g = [p for p in ps if p.play_type == name]
        tot = sum(sum(p.src.values()) for p in g)
        parts = ", ".join(f"{k} {sum(p.src[k] for p in g) / tot * 100:.0f}%" for k in g[0].src)
        print(f"    {name}: {parts}")
    print()


if __name__ == "__main__":
    ours = Rules("우리 게임(순한 맛)", OUR_SUCCESS, OUR_DESTROY, OUR_BROKEN_DROP_TO)
    maple = Rules("메이플 확률 그대로", MAPLE_SUCCESS, MAPLE_DESTROY, MAPLE_BROKEN_DROP_TO)
    price_table(ours)
    report(*simulate(ours, N_PLAYERS), ours)
    report(*simulate(maple, N_PLAYERS), maple)
