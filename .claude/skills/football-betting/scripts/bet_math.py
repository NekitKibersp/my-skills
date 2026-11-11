#!/usr/bin/env python3
"""Математика для анализа футбольных ставок: Пуассон, маржа, ценность (EV), Келли, экспрессы, оценка 1-10, журнал ставок.

Примеры:
  # модель матча по средним (дома у хозяев / в гостях у гостей) + коэффициенты для проверки ценности
  bet_math.py match --home-for 1.9 --home-against 0.9 --away-for 1.1 --away-against 1.6 \
      --league-home 1.55 --league-away 1.25 --corners 10.4 --cards 4.6 \
      --odds "П1=1.85 X=3.6 П2=4.5 ТБ2.5=1.95 ТМ2.5=1.9 ОЗ-да=1.9 УглТБ9.5=1.85 ЖКТБ4.5=2.0" --quality 3

  bet_math.py margin 1.85 3.6 4.5              # маржа букмекера и «честные» вероятности
  bet_math.py value --p 0.58 --odds 1.95 --quality 2   # EV, честный кэф, Келли, оценка
  bet_math.py coupon "0.58@1.95" "0.62@1.70" "0.55@2.05"   # экспресс: вероятность, EV, оценка
  bet_math.py journal add --match "Зенит - Спартак" --market "ТБ2.5" --odds 1.95 --stake 200 --p 0.58
  bet_math.py journal settle 3 win --closing 1.80
  bet_math.py journal report
"""
import argparse, csv, datetime, math, os, re, sys

JOURNAL = os.path.expanduser(os.environ.get("BET_JOURNAL", "~/bets/journal.csv"))


# ---------- базовая математика ----------
def pois(k, lam):
    return math.exp(-lam) * lam ** k / math.factorial(k)


def score_matrix(lh, la, n=11):
    return [[pois(i, lh) * pois(j, la) for j in range(n)] for i in range(n)]


def total_over(lam, line):
    """P(X > line) для пуассоновской величины, line вида 2.5 / 9.5."""
    k_max = math.floor(line)
    return 1 - sum(pois(k, lam) for k in range(k_max + 1))


def ev(p, odds):
    return p * odds - 1


def kelly(p, odds):
    b = odds - 1
    f = (b * p - (1 - p)) / b if b > 0 else 0
    return max(0.0, f)


def rating(p, odds, quality=2, legs=1, coupon=False):
    """Оценка 1-10. quality: 1 — мало/плохие данные, 2 — средние, 3 — полные и свежие.

    База — ценность (EV): EV<=-8% → 1, -3% → 3, 0 → 4, +3% → 6, +6% → 7, +10% → 8, +15% и выше → 9.
    Поправки: качество данных 1 → −2, 2 → −1; вероятность < 35% → −1 (высокая дисперсия);
    в экспрессе каждая нога сверх двух → −1. 10 — только EV ≥ 10%, quality=3, p ≥ 0.5, одиночная ставка.
    EV > 20% почти всегда означает ошибку модели или устаревшие данные — оценка не выше 7, с пометкой.
    """
    e = ev(p, odds)
    pts = [(-0.08, 1), (-0.05, 2), (-0.03, 3), (0.0, 4), (0.015, 5), (0.03, 6), (0.06, 7), (0.10, 8), (0.15, 9)]
    r = 1
    for thr, val in pts:
        if e >= thr:
            r = val
    if quality <= 1:
        r -= 2
    elif quality == 2:
        r -= 1
    if p < 0.35:
        r -= 1
    if legs > 2:
        r -= legs - 2
    if 0.10 <= e <= 0.15 and quality >= 3 and p >= 0.5 and legs == 1:
        r = 10
    note = ""
    if not coupon:
        gap = p - 1 / odds  # модель против вероятности, заложенной в кэф
        if e > 0.20:
            r = min(r, 7)
            note = "EV > 20% — подозрительно: перепроверь данные (составы, мотивация, ошибка в средних)"
        elif gap > 0.10:
            r = min(r, 7)
            note = f"модель на {gap*100:.0f} п.п. выше рынка — рынок обычно умнее, ищи, что не учтено"
    return max(1, min(10, r)), note


def verdict(r):
    if r >= 8:
        return "сильная ставка"
    if r >= 6:
        return "есть ценность, ставить умеренно"
    if r == 5:
        return "на грани, лучше пропустить или минимальной суммой"
    return "НЕ ставить: ценности нет"


# ---------- команды ----------
def parse_odds(s):
    out = {}
    for tok in (s or "").split():
        if "=" in tok:
            k, v = tok.split("=", 1)
            out[k.strip()] = float(v.replace(",", "."))
    return out


def cmd_match(a):
    # силы атаки/обороны относительно среднего по лиге (модель Махера/Пуассона)
    lh = a.home_for / a.league_home * a.away_against / a.league_home * a.league_home
    la = a.away_for / a.league_away * a.home_against / a.league_away * a.league_away
    m = score_matrix(lh, la)
    n = len(m)
    p1 = sum(m[i][j] for i in range(n) for j in range(n) if i > j)
    px = sum(m[i][i] for i in range(n))
    p2 = 1 - p1 - px
    btts = (1 - pois(0, lh)) * (1 - pois(0, la))
    tot = lh + la
    probs = {"П1": p1, "X": px, "П2": p2, "1X": p1 + px, "X2": px + p2, "12": p1 + p2,
             "ОЗ-да": btts, "ОЗ-нет": 1 - btts}
    for line in (0.5, 1.5, 2.5, 3.5, 4.5):
        o = total_over(tot, line)
        probs[f"ТБ{line}"], probs[f"ТМ{line}"] = o, 1 - o
    for line in (0.5, 1.5, 2.5):
        probs[f"ИТ1Б{line}"] = total_over(lh, line)
        probs[f"ИТ2Б{line}"] = total_over(la, line)
    if a.corners:
        for line in (7.5, 8.5, 9.5, 10.5, 11.5):
            o = total_over(a.corners, line)
            probs[f"УглТБ{line}"], probs[f"УглТМ{line}"] = o, 1 - o
    if a.cards:
        for line in (2.5, 3.5, 4.5, 5.5):
            o = total_over(a.cards, line)
            probs[f"ЖКТБ{line}"], probs[f"ЖКТМ{line}"] = o, 1 - o

    print(f"Ожидаемые голы: хозяева {lh:.2f}, гости {la:.2f}, всего {tot:.2f}")
    top = sorted(((m[i][j], f"{i}:{j}") for i in range(n) for j in range(n)), reverse=True)[:5]
    print("Самые вероятные счета: " + ", ".join(f"{s} ({p*100:.1f}%)" for p, s in top))
    if a.corners or a.cards:
        print("Внимание: угловые и ЖК в реальности разбросаны сильнее Пуассона — вероятности на крайних линиях завышены по уверенности.")
    odds = parse_odds(a.odds)
    print(f"\n{'Рынок':<11}{'Вероятн.':>9}{'Честн.кэф':>10}{'Кэф БК':>8}{'EV':>8}{'Келли/4':>9}{'Оценка':>8}")
    for k, p in probs.items():
        if odds and k not in odds and not a.all:
            continue
        fair = 1 / p if p > 0 else float("inf")
        line = f"{k:<11}{p*100:>8.1f}%{fair:>10.2f}"
        if k in odds:
            o = odds[k]
            r, note = rating(p, o, a.quality)
            line += f"{o:>8.2f}{ev(p, o)*100:>7.1f}%{kelly(p, o)/4*100:>8.1f}%{r:>6}/10  {verdict(r)}"
            if note:
                line += f"  [{note}]"
        print(line)
    missing = [k for k in odds if k not in probs]
    if missing:
        print("Не распознаны рынки: " + ", ".join(missing) + " (имена как в таблице: П1 X П2 1X ТБ2.5 ОЗ-да УглТБ9.5 ЖКТБ4.5 ИТ1Б1.5 ...)")


def cmd_margin(a):
    inv = [1 / o for o in a.odds]
    s = sum(inv)
    print(f"Маржа букмекера: {(s - 1) * 100:.2f}%")
    for o, i in zip(a.odds, inv):
        p = i / s
        print(f"  кэф {o:.2f} → честная вероятность {p*100:.1f}% → честный кэф {1/p:.2f}")


def cmd_value(a):
    r, note = rating(a.p, a.odds, a.quality)
    print(f"Вероятность {a.p*100:.1f}%, кэф {a.odds:.2f}: честный кэф {1/a.p:.2f}, EV {ev(a.p, a.odds)*100:+.1f}%")
    print(f"Келли {kelly(a.p, a.odds)*100:.1f}% банка, четверть Келли {kelly(a.p, a.odds)/4*100:.1f}% (рекомендуемо не больше 2-3%)")
    print(f"Оценка {r}/10 — {verdict(r)}" + (f" [{note}]" if note else ""))


def cmd_coupon(a):
    legs = []
    for t in a.legs:
        p, o = t.split("@")
        legs.append((float(p), float(o)))
    P = math.prod(p for p, _ in legs)
    K = math.prod(o for _, o in legs)
    print(f"Ног: {len(legs)}, общий кэф {K:.2f}, вероятность прохода {P*100:.1f}%, EV {ev(P, K)*100:+.1f}%")
    leg_r = [rating(p, o, a.quality)[0] for p, o in legs]
    for (p, o), r in zip(legs, leg_r):
        print(f"  {p*100:.0f}% @ {o:.2f}: EV {ev(p, o)*100:+.1f}%, {r}/10")
    r_ev, _ = rating(P, K, a.quality, legs=len(legs), coupon=True)
    r = min(r_ev, min(leg_r))  # купон не лучше своей худшей ноги
    why = []
    if min(leg_r) < r_ev:
        why.append(f"ограничена худшей ногой ({min(leg_r)}/10)")
    if len(legs) > 2:
        why.append(f"штраф за {len(legs)} ноги: −{len(legs) - 2}")
    print(f"Оценка купона {r}/10 — {verdict(r)}" + (f" ({'; '.join(why)})" if why else ""))
    if ev(P, K) > 0 and r <= 4:
        print("Общий EV в плюсе только за счёт перемножения сильных ног — слабая нога всё равно съедает шанс прохода.")
    bad = [i + 1 for i, (p, o) in enumerate(legs) if ev(p, o) < 0]
    if bad:
        print(f"Ноги без ценности: {bad} — они тянут весь купон в минус, убери их или сыграй остальное ординарами.")
    if len(legs) >= 4:
        print("4+ ноги: маржа букмекера перемножается, дисперсия огромная — это лотерея, а не стратегия.")


def cmd_journal(a):
    os.makedirs(os.path.dirname(JOURNAL), exist_ok=True)
    fields = ["id", "date", "match", "market", "odds", "stake", "p", "result", "closing", "profit"]
    rows = []
    if os.path.exists(JOURNAL):
        with open(JOURNAL, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
    if a.action == "add":
        rows.append({"id": str(len(rows) + 1), "date": datetime.date.today().isoformat(), "match": a.match,
                     "market": a.market, "odds": a.odds, "stake": a.stake, "p": a.p or "",
                     "result": "", "closing": "", "profit": ""})
        print(f"Записана ставка #{len(rows)}")
    elif a.action == "settle":
        r = next(x for x in rows if x["id"] == str(a.id))
        o, s = float(r["odds"]), float(r["stake"])
        r["result"] = a.result
        r["profit"] = f"{(o - 1) * s if a.result == 'win' else (0 if a.result == 'void' else -s):.2f}"
        if a.closing:
            r["closing"] = a.closing
        print(f"#{a.id}: {a.result}, прибыль {r['profit']}")
    else:
        done = [x for x in rows if x["result"]]
        if not done:
            print("Рассчитанных ставок пока нет.")
            return
        stake = sum(float(x["stake"]) for x in done)
        prof = sum(float(x["profit"]) for x in done)
        wins = sum(x["result"] == "win" for x in done)
        clv = [float(x["odds"]) / float(x["closing"]) - 1 for x in done if x["closing"]]
        print(f"Ставок: {len(done)}, выиграно {wins} ({wins/len(done)*100:.0f}%), оборот {stake:.0f}, прибыль {prof:+.0f}, ROI {prof/stake*100:+.1f}%")
        if clv:
            print(f"CLV (кэф взятия против закрытия): {sum(clv)/len(clv)*100:+.1f}% по {len(clv)} ставкам — "
                  "плюс значит, что ты стабильно берёшь кэф лучше рынка (главный признак, что система работает)")
        if len(done) < 100:
            print("Меньше 100 ставок — по ROI ещё ничего нельзя сказать, это шум.")
    with open(JOURNAL, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("match")
    for k in ("home-for", "home-against", "away-for", "away-against"):
        m.add_argument("--" + k, type=float, required=True)
    m.add_argument("--league-home", type=float, default=1.5, help="средние голы хозяев в лиге")
    m.add_argument("--league-away", type=float, default=1.2, help="средние голы гостей в лиге")
    m.add_argument("--corners", type=float, help="ожидаемый тотал угловых в матче")
    m.add_argument("--cards", type=float, help="ожидаемый тотал ЖК (с учётом судьи)")
    m.add_argument("--odds", help='кэфы: "П1=1.85 X=3.6 ТБ2.5=1.95 ..."')
    m.add_argument("--quality", type=int, default=2, choices=(1, 2, 3))
    m.add_argument("--all", action="store_true", help="показать все рынки, даже без кэфа")
    m.set_defaults(f=cmd_match)
    g = sub.add_parser("margin"); g.add_argument("odds", type=float, nargs="+"); g.set_defaults(f=cmd_margin)
    v = sub.add_parser("value")
    v.add_argument("--p", type=float, required=True); v.add_argument("--odds", type=float, required=True)
    v.add_argument("--quality", type=int, default=2, choices=(1, 2, 3)); v.set_defaults(f=cmd_value)
    c = sub.add_parser("coupon"); c.add_argument("legs", nargs="+", help="p@odds, например 0.58@1.95")
    c.add_argument("--quality", type=int, default=2, choices=(1, 2, 3)); c.set_defaults(f=cmd_coupon)
    j = sub.add_parser("journal"); jj = j.add_subparsers(dest="action", required=True)
    ja = jj.add_parser("add")
    ja.add_argument("--match", required=True); ja.add_argument("--market", required=True)
    ja.add_argument("--odds", required=True); ja.add_argument("--stake", required=True); ja.add_argument("--p")
    js = jj.add_parser("settle"); js.add_argument("id", type=int); js.add_argument("result", choices=("win", "lose", "void"))
    js.add_argument("--closing")
    jj.add_parser("report")
    j.set_defaults(f=cmd_journal)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
