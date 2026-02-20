"""
╔══════════════════════════════════════════════════════════════════╗
║  DUAL EMA 9/21 BACKTEST — NQ FUTURES                            ║
║  1 NQ Contract | 50pt Hard SL | 40pt Trailing Stop              ║
║  NY Session: 9:30 AM – 4:00 PM ET | Mon–Fri                     ║
╚══════════════════════════════════════════════════════════════════╝

STRATEGY LOGIC
──────────────
  Entry  : EMA(9) crosses over/under EMA(21) during session hours
  Exit 1 : Hard stop loss at 50pts from entry  (max $1,000 risk/trade)
  Exit 2 : Trailing stop — activates once trade moves +25pts in favor,
            then trails 40pts behind the best price reached
  Exit 3 : Opposite EMA crossover signal
  Exit 4 : Session end force-close at 4:00 PM ET

TO RUN WITH REAL DATA
──────────────────────
  pip install yfinance pandas numpy

  Then set USE_REAL_DATA = True below. yfinance provides up to
  7 days of 1-min data for NQ=F (or MNQ=F for micro).

  For longer history, export 1-min OHLCV from:
    - NinjaTrader  → export to CSV
    - Tradovate    → export to CSV
    - Sierra Chart → .dly file
    - TradeStation → RadarScreen export

  Then set USE_CSV = True and point CSV_PATH at your file.
  Expected CSV columns: datetime, open, high, low, close, volume
"""

import numpy as np
import pandas as pd
import datetime

# ═══════════════════════════════════════════════════
# CONFIGURATION — edit these values
# ═══════════════════════════════════════════════════

USE_REAL_DATA = False       # True  → pull from yfinance
USE_CSV       = False       # True  → load from local CSV file
CSV_PATH      = "nq_1min.csv"   # path to your CSV if USE_CSV = True

# Contract settings
POINT_VALUE   = 20.0        # NQ full contract = $20/point
                            # MNQ micro contract = $2/point
COMMISSION    = 4.24        # round-trip commission (NQ typical)
                            # MNQ ≈ $0.42 round-trip

# Strategy parameters
FAST_EMA      = 9           # fast EMA period
SLOW_EMA      = 21          # slow EMA period

# Risk management
HARD_SL_PTS   = 50.0        # hard stop loss in points ($1,000 for NQ)
TRAIL_ACTIVATE= 25.0        # points in profit before trailing activates
TRAIL_DIST    = 40.0        # trailing stop distance from best price

# Session filter (Eastern Time)
SESSION_START = datetime.time(9, 30)   # 9:30 AM ET
SESSION_END   = datetime.time(16, 0)   # 4:00 PM ET
TRADE_DAYS    = {0,1,2,3,4}            # Mon=0 … Fri=4 (remove days to skip)


# ═══════════════════════════════════════════════════
# STEP 1 — LOAD DATA
# ═══════════════════════════════════════════════════

if USE_REAL_DATA:
    import yfinance as yf
    print("Downloading NQ 1-min data from Yahoo Finance...")
    # Note: yfinance only provides ~7 days of 1-min data for futures
    df = yf.download("NQ=F", period="5d", interval="1m", auto_adjust=True)
    df.columns = [c.lower() for c in df.columns]
    df = df[["open","high","low","close"]].dropna()
    # Convert index to ET if needed (yfinance returns UTC for futures)
    df.index = df.index.tz_convert("America/New_York")
    df.index = df.index.tz_localize(None)
    print(f"Loaded {len(df):,} bars from {df.index[0]} to {df.index[-1]}")

elif USE_CSV:
    print(f"Loading data from {CSV_PATH}...")
    df = pd.read_csv(CSV_PATH, parse_dates=[0], index_col=0)
    df.columns = [c.lower().strip() for c in df.columns]
    df = df[["open","high","low","close"]].dropna()
    print(f"Loaded {len(df):,} bars from {df.index[0]} to {df.index[-1]}")

else:
    # ── SYNTHETIC DATA (demo mode) ──────────────────
    print("Using synthetic NQ data (demo mode).")
    print("Set USE_REAL_DATA=True or USE_CSV=True for live results.\n")
    np.random.seed(42)
    n           = 5 * 390       # 5 trading days × 390 min
    start_price = 21500
    tick        = 0.25
    returns     = np.random.normal(0.0001, 0.0012, n)
    prices      = start_price * np.exp(np.cumsum(returns))
    opens, highs, lows, closes = [], [], [], []
    for p in prices:
        r = abs(np.random.normal(0, 3))
        h, l = p + r, p - r
        opens.append(round(p / tick) * tick)
        highs.append(round(h / tick) * tick)
        lows.append(round(l / tick) * tick)
        closes.append(round(np.random.uniform(l, h) / tick) * tick)
    dates = pd.date_range("2025-02-10 09:30", periods=n, freq="1min")
    df = pd.DataFrame({"open":opens,"high":highs,"low":lows,"close":closes}, index=dates)


# ═══════════════════════════════════════════════════
# STEP 2 — INDICATORS
# ═══════════════════════════════════════════════════

# EMAs calculated on full dataset for accuracy (not just session hours)
df["ema_fast"] = df["close"].ewm(span=FAST_EMA,  adjust=False).mean()
df["ema_slow"] = df["close"].ewm(span=SLOW_EMA, adjust=False).mean()

# Crossover signals
df["bullish_cross"] = (
    (df["ema_fast"] > df["ema_slow"]) &
    (df["ema_fast"].shift(1) <= df["ema_slow"].shift(1))
)
df["bearish_cross"] = (
    (df["ema_fast"] < df["ema_slow"]) &
    (df["ema_fast"].shift(1) >= df["ema_slow"].shift(1))
)

# Session filter
def in_session(ts):
    if ts.weekday() not in TRADE_DAYS:
        return False
    t = ts.time()
    return SESSION_START <= t <= SESSION_END

df["in_session"] = df.index.map(in_session)


# ═══════════════════════════════════════════════════
# STEP 3 — BACKTEST ENGINE
# ═══════════════════════════════════════════════════

position     = 0        #  1 = long, -1 = short, 0 = flat
entry_price  = 0.0
entry_time   = None
hard_sl      = 0.0
trail_stop   = 0.0
best_price   = 0.0
trailing_on  = False
trades       = []

for ts, row in df.iterrows():
    t              = ts.time()
    is_session_end = (t == SESSION_END) and row["in_session"]

    # ── Manage open position ──────────────────────
    if position != 0:

        if position == 1:  # ── LONG ──
            # Update best (highest) price
            if row["high"] > best_price:
                best_price = row["high"]
                # Activate trail once +TRAIL_ACTIVATE pts in profit
                if best_price - entry_price >= TRAIL_ACTIVATE:
                    trailing_on = True
                if trailing_on:
                    trail_stop = best_price - TRAIL_DIST

            exit_price  = None
            exit_reason = None

            if row["low"] <= hard_sl:
                exit_price  = hard_sl
                exit_reason = "STOP LOSS"
            elif trailing_on and row["low"] <= trail_stop:
                exit_price  = trail_stop
                exit_reason = "TRAIL STOP"
            elif is_session_end:
                exit_price  = row["close"]
                exit_reason = "SESSION END"
            elif row["bearish_cross"]:
                exit_price  = row["close"]
                exit_reason = "EMA CROSS"

            if exit_price is not None:
                pnl = (exit_price - entry_price) * POINT_VALUE - COMMISSION
                trades.append({
                    "entry_time":      entry_time,
                    "exit_time":       ts,
                    "side":            "LONG",
                    "entry":           entry_price,
                    "exit":            exit_price,
                    "pnl":             round(pnl, 2),
                    "reason":          exit_reason,
                    "best_excursion":  round(best_price - entry_price, 2),
                    "duration_min":    int((ts - entry_time).total_seconds() / 60),
                })
                position = 0

        elif position == -1:  # ── SHORT ──
            # Update best (lowest) price
            if row["low"] < best_price:
                best_price = row["low"]
                if entry_price - best_price >= TRAIL_ACTIVATE:
                    trailing_on = True
                if trailing_on:
                    trail_stop = best_price + TRAIL_DIST

            exit_price  = None
            exit_reason = None

            if row["high"] >= hard_sl:
                exit_price  = hard_sl
                exit_reason = "STOP LOSS"
            elif trailing_on and row["high"] >= trail_stop:
                exit_price  = trail_stop
                exit_reason = "TRAIL STOP"
            elif is_session_end:
                exit_price  = row["close"]
                exit_reason = "SESSION END"
            elif row["bullish_cross"]:
                exit_price  = row["close"]
                exit_reason = "EMA CROSS"

            if exit_price is not None:
                pnl = (entry_price - exit_price) * POINT_VALUE - COMMISSION
                trades.append({
                    "entry_time":      entry_time,
                    "exit_time":       ts,
                    "side":            "SHORT",
                    "entry":           entry_price,
                    "exit":            exit_price,
                    "pnl":             round(pnl, 2),
                    "reason":          exit_reason,
                    "best_excursion":  round(entry_price - best_price, 2),
                    "duration_min":    int((ts - entry_time).total_seconds() / 60),
                })
                position = 0

    # ── New entry signal ─────────────────────────
    if position == 0 and row["in_session"] and not is_session_end:
        if row["bullish_cross"]:
            position     = 1
            entry_price  = row["close"]
            entry_time   = ts
            hard_sl      = entry_price - HARD_SL_PTS
            trail_stop   = hard_sl
            best_price   = entry_price
            trailing_on  = False

        elif row["bearish_cross"]:
            position     = -1
            entry_price  = row["close"]
            entry_time   = ts
            hard_sl      = entry_price + HARD_SL_PTS
            trail_stop   = hard_sl
            best_price   = entry_price
            trailing_on  = False


# ═══════════════════════════════════════════════════
# STEP 4 — STATISTICS
# ═══════════════════════════════════════════════════

tdf     = pd.DataFrame(trades)

if tdf.empty:
    print("No trades generated. Check your data and session settings.")
else:
    tdf["session"] = tdf["entry_time"].apply(
        lambda x: "Morning" if x.hour < 12 else "Afternoon"
    )

    winners = tdf[tdf["pnl"] > 0]
    losers  = tdf[tdf["pnl"] <= 0]
    equity  = tdf["pnl"].cumsum()
    dd      = equity - equity.cummax()
    pf      = (winners["pnl"].sum() / abs(losers["pnl"].sum())
               if len(losers) else float("inf"))
    rr      = (abs(winners["pnl"].mean() / losers["pnl"].mean())
               if len(losers) else float("inf"))

    reason_counts = tdf["reason"].value_counts().to_dict()
    m_df = tdf[tdf["session"] == "Morning"]
    a_df = tdf[tdf["session"] == "Afternoon"]

    print("=" * 64)
    print(f"  DUAL EMA {FAST_EMA}/{SLOW_EMA}  |  {POINT_VALUE:.0f}$/pt  |  "
          f"{HARD_SL_PTS:.0f}pt SL  |  {TRAIL_DIST:.0f}pt TRAIL")
    print(f"  Session: {SESSION_START.strftime('%I:%M %p')} – "
          f"{SESSION_END.strftime('%I:%M %p')} ET")
    print("=" * 64)
    print(f"  Period           : {tdf['entry_time'].min().date()} → "
          f"{tdf['exit_time'].max().date()}")
    print(f"  Total Trades     : {len(tdf)}")
    print(f"  Winners          : {len(winners)} ({len(winners)/len(tdf)*100:.1f}%)")
    print(f"  Losers           : {len(losers)} ({len(losers)/len(tdf)*100:.1f}%)")
    print(f"  Avg Win          : ${winners['pnl'].mean():,.2f}")
    print(f"  Avg Loss         : ${losers['pnl'].mean():,.2f}")
    print(f"  Reward : Risk    : {rr:.2f}×")
    print(f"  Profit Factor    : {pf:.2f}")
    print(f"  Gross P&L        : ${equity.iloc[-1]:,.2f}")
    print(f"  Max Drawdown     : ${dd.min():,.2f}")
    print(f"  Best Trade       : ${winners['pnl'].max():,.2f}")
    print(f"  Worst Trade      : ${losers['pnl'].min():,.2f}")
    print(f"  Avg Duration     : {tdf['duration_min'].mean():.0f} min")
    print(f"  Exit Reasons     : {reason_counts}")
    print(f"  ── Morning       : ${m_df['pnl'].sum():,.2f} ({len(m_df)} trades)")
    print(f"  ── Afternoon     : ${a_df['pnl'].sum():,.2f} ({len(a_df)} trades)")
    print("=" * 64)
    print()

    # Full trade log
    print(tdf[[
        "entry_time","side","entry","exit",
        "reason","duration_min","best_excursion","pnl"
    ]].to_string(index=False))
    print()

    # Save to CSV
    out = "nq_ema_trades.csv"
    tdf.to_csv(out, index=False)
    print(f"✓ Trade log saved to {out}")

    # Optional: plot equity curve (requires matplotlib)
    try:
        import matplotlib.pyplot as plt
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 7),
                                        gridspec_kw={"height_ratios":[3,1]})
        fig.patch.set_facecolor("#08090d")
        for ax in (ax1, ax2):
            ax.set_facecolor("#0d0f16")
            ax.tick_params(colors="#3e4d60")
            ax.spines[:].set_color("#1a2030")

        # Equity
        ax1.plot(equity.values, color="#3d8ef8", linewidth=1.8)
        ax1.fill_between(range(len(equity)), equity.values,
                         alpha=0.15, color="#3d8ef8")
        ax1.axhline(0, color="#1a2030", linewidth=1)
        ax1.set_title("Equity Curve — Dual EMA 9/21 NQ",
                      color="#e4edf8", fontsize=11)
        ax1.set_ylabel("P&L ($)", color="#3e4d60")

        # Drawdown
        ax2.fill_between(range(len(dd)), dd.values,
                         alpha=0.6, color="#ff3d57")
        ax2.set_ylabel("Drawdown ($)", color="#3e4d60")
        ax2.set_xlabel("Trade #", color="#3e4d60")

        plt.tight_layout()
        plt.savefig("nq_ema_equity.png", dpi=150,
                    facecolor="#08090d", bbox_inches="tight")
        print("✓ Equity chart saved to nq_ema_equity.png")
        plt.show()
    except ImportError:
        print("(Install matplotlib to generate equity chart: pip install matplotlib)")
