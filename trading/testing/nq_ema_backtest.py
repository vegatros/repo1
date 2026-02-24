"""
Dual EMA 9/21 Backtest — NQ Futures, 1-Min, 1-Week
====================================================
To use with REAL data:
  pip install yfinance pandas numpy

Then run:
  python3 nq_ema_backtest.py

Or replace the data loading section with your own CSV export from
Tradovate, NinjaTrader, Sierra Chart, etc.
"""

import numpy as np
import pandas as pd

# ─────────────────────────────────────────
# 1. LOAD DATA
# Option A: Yahoo Finance (requires network)
# ─────────────────────────────────────────
USE_REAL_DATA = False   # ← Set to True + uncomment below to use yfinance

if USE_REAL_DATA:
    import yfinance as yf
    from datetime import datetime, timedelta
    end   = datetime.today()
    start = end - timedelta(days=7)
    df = yf.download("NQ=F", start=start, end=end, interval="1m")
    df.columns = [c.lower() for c in df.columns]
    df = df[["open","high","low","close","volume"]].dropna()

else:
    # ─────────────────────────────────────────
    # Option B: Synthetic data (demo mode)
    # ─────────────────────────────────────────
    np.random.seed(42)
    n = 5 * 390
    start_price = 21500
    tick = 0.25
    returns = np.random.normal(0.0001, 0.0012, n)
    prices  = start_price * np.exp(np.cumsum(returns))
    opens, highs, lows, closes = [], [], [], []
    for i in range(n):
        o = prices[i]
        r = abs(np.random.normal(0, 3))
        h, l = o + r, o - r
        c = np.random.uniform(l, h)
        opens.append(round(o/tick)*tick)
        highs.append(round(h/tick)*tick)
        lows.append(round(l/tick)*tick)
        closes.append(round(c/tick)*tick)
    dates = pd.date_range("2025-02-10 09:30", periods=n, freq="1min")
    df = pd.DataFrame({"open":opens,"high":highs,"low":lows,"close":closes}, index=dates)

# ─────────────────────────────────────────
# 2. STRATEGY PARAMETERS
# ─────────────────────────────────────────
FAST_LEN     = 9
SLOW_LEN     = 21
POINT_VALUE  = 20    # NQ: $20 per full point
COMMISSION   = 4.24  # round-trip NQ ($2.12 per side typical)

# ─────────────────────────────────────────
# 3. INDICATORS
# ─────────────────────────────────────────
df["ema_fast"] = df["close"].ewm(span=FAST_LEN, adjust=False).mean()
df["ema_slow"] = df["close"].ewm(span=SLOW_LEN, adjust=False).mean()

df["bullish_cross"] = (df["ema_fast"] > df["ema_slow"]) & \
                      (df["ema_fast"].shift(1) <= df["ema_slow"].shift(1))
df["bearish_cross"] = (df["ema_fast"] < df["ema_slow"]) & \
                      (df["ema_fast"].shift(1) >= df["ema_slow"].shift(1))

# ─────────────────────────────────────────
# 4. BACKTEST ENGINE
# ─────────────────────────────────────────
position    = 0
entry_price = 0
trades      = []

for ts, row in df.iterrows():
    if row["bullish_cross"] and position != 1:
        if position == -1:
            pnl = (entry_price - row["close"]) * POINT_VALUE - COMMISSION
            trades.append(dict(time=ts, side="SHORT", entry=entry_price,
                               exit=row["close"], pnl=pnl))
        position    = 1
        entry_price = row["close"]

    elif row["bearish_cross"] and position != -1:
        if position == 1:
            pnl = (row["close"] - entry_price) * POINT_VALUE - COMMISSION
            trades.append(dict(time=ts, side="LONG", entry=entry_price,
                               exit=row["close"], pnl=pnl))
        position    = -1
        entry_price = row["close"]

# Close open position at end
if position == 1:
    pnl = (df["close"].iloc[-1] - entry_price) * POINT_VALUE - COMMISSION
    trades.append(dict(time=df.index[-1], side="LONG (open)", entry=entry_price,
                       exit=df["close"].iloc[-1], pnl=pnl))
elif position == -1:
    pnl = (entry_price - df["close"].iloc[-1]) * POINT_VALUE - COMMISSION
    trades.append(dict(time=df.index[-1], side="SHORT (open)", entry=entry_price,
                       exit=df["close"].iloc[-1], pnl=pnl))

tdf = pd.DataFrame(trades)

# ─────────────────────────────────────────
# 5. STATISTICS
# ─────────────────────────────────────────
winners = tdf[tdf["pnl"] > 0]
losers  = tdf[tdf["pnl"] <= 0]
equity  = tdf["pnl"].cumsum()
drawdown = equity - equity.cummax()

print("=" * 58)
print("  DUAL EMA 9/21 BACKTEST — NQ FUTURES (1-MIN, 1 WEEK)")
print("=" * 58)
print(f"  Bars             : {len(df):,}")
print(f"  EMA Crossovers   : {int(df['bullish_cross'].sum() + df['bearish_cross'].sum())}")
print(f"  Total Trades     : {len(tdf)}")
print(f"  Winning Trades   : {len(winners)}  ({len(winners)/len(tdf)*100:.1f}%)")
print(f"  Losing Trades    : {len(losers)}  ({len(losers)/len(tdf)*100:.1f}%)")
print(f"  Avg Win          : ${winners['pnl'].mean():,.2f}")
print(f"  Avg Loss         : ${losers['pnl'].mean():,.2f}")
pf = winners["pnl"].sum() / abs(losers["pnl"].sum()) if len(losers) else float("inf")
print(f"  Profit Factor    : {pf:.2f}")
print(f"  Gross P&L        : ${equity.iloc[-1]:,.2f}")
print(f"  Max Drawdown     : ${drawdown.min():,.2f}")
print("=" * 58)

tdf.to_csv("nq_ema_trades.csv", index=False)
print("\n✓ Trade log saved to nq_ema_trades.csv")
