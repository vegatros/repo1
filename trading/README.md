# NQ Dual EMA 9/21 Backtest
**NASDAQ-100 Futures · 1-Minute Bars · Trailing Stop Strategy**

A Python backtesting engine for the Dual EMA 9/21 crossover strategy applied to NQ (NASDAQ-100) futures on a 1-minute timeframe. Supports live data via yfinance, custom CSV exports from broker platforms, or built-in synthetic demo data.

---

## Strategy Summary

| Parameter | Value |
|---|---|
| Indicator | EMA(9) / EMA(21) crossover |
| Timeframe | 1-minute bars |
| Contract | 1 NQ full contract ($20/point) |
| Session | 9:30 AM – 4:00 PM ET, Mon–Fri |
| Hard Stop Loss | 50 points ($1,000 max risk/trade) |
| Trailing Stop | Activates at +25pt profit, trails 40pt behind best price |
| Take Profit | None — winners ride until trailed out or signal reverses |

**Entry logic:** A new position is entered when EMA(9) crosses over (long) or under (short) EMA(21) during session hours. Only one position is held at a time.

**Exit priority order:**
1. Hard stop loss hit (50pt from entry)
2. Trailing stop hit (40pt from best price, once +25pt in profit)
3. Opposite EMA crossover signal
4. Session end force-close at 4:00 PM ET

---

## Requirements

```
Python 3.8+
pandas
numpy
```

**Optional — for live data:**
```
yfinance       # pull recent NQ futures data automatically
```

**Optional — for equity chart:**
```
matplotlib
```

Install all dependencies at once:
```bash
pip install pandas numpy yfinance matplotlib
```

---

## Quick Start

### Option 1 — Demo Mode (no setup needed)
Run the script as-is. It uses built-in synthetic NQ price data so you can verify everything works before connecting real data.

```bash
python nq_ema_backtest.py
```

You will see output like:
```
Using synthetic NQ data (demo mode).
================================================================
  DUAL EMA 9/21  |  20$/pt  |  50pt SL  |  40pt TRAIL
  Session: 09:30 AM – 04:00 PM ET
================================================================
  Period           : 2025-02-10 → 2025-02-11
  Total Trades     : 19
  Winners          : 8 (42.1%)
  ...
✓ Trade log saved to nq_ema_trades.csv
```

---

### Option 2 — Live Data via yfinance (last 7 days)

1. Install yfinance:
   ```bash
   pip install yfinance
   ```

2. Open `nq_ema_backtest.py` and change line 42:
   ```python
   USE_REAL_DATA = True
   ```

3. Run the script:
   ```bash
   python nq_ema_backtest.py
   ```

> **Note:** Yahoo Finance provides approximately 7 days of 1-minute futures data for `NQ=F`. For longer history, use Option 3 below.

---

### Option 3 — Load from CSV (weeks or months of data)

Export 1-minute OHLCV data from your broker platform, then:

1. Open `nq_ema_backtest.py` and set:
   ```python
   USE_CSV  = True
   CSV_PATH = "path/to/your_data.csv"
   ```

2. Run the script:
   ```bash
   python nq_ema_backtest.py
   ```

**Expected CSV format:**
```
datetime,open,high,low,close,volume
2025-02-10 09:30:00,21500.25,21504.50,21498.75,21502.00,1240
2025-02-10 09:31:00,21502.00,21508.75,21499.50,21505.25,987
...
```

Column names are case-insensitive. The `volume` column is optional.

**How to export from common platforms:**

| Platform | Steps |
|---|---|
| **NinjaTrader** | Tools → Historical Data Manager → Export → select NQ, 1 Min, date range → Export |
| **Tradovate** | Reports → Trade History → Export CSV (use the market replay data export) |
| **Sierra Chart** | File → Export Chart Data → CSV, set interval to 1 minute |
| **TradeStation** | Insert → Symbol → right-click chart → Export Data → CSV |
| **Thinkorswim** | Studies → thinkScript → use OnDemand replay and export via thinkLog |

---

## Configuration Reference

All settings are at the top of `nq_ema_backtest.py` under the `CONFIGURATION` section.

### Data Source
```python
USE_REAL_DATA = False    # True = pull from yfinance (last 7 days)
USE_CSV       = False    # True = load from local CSV file
CSV_PATH      = "nq_1min.csv"  # path to your CSV when USE_CSV = True
```

### Contract Settings
```python
POINT_VALUE = 20.0    # NQ full contract  = $20 per point
                      # MNQ micro contract = $2 per point  ← change to 2.0 for MNQ
COMMISSION  = 4.24    # NQ round-trip commission (approx)
                      # MNQ ≈ $0.42 round-trip             ← change to 0.42 for MNQ
```

### Strategy Parameters
```python
FAST_EMA = 9     # fast EMA period
SLOW_EMA = 21    # slow EMA period
```

### Risk Management
```python
HARD_SL_PTS    = 50.0    # hard stop loss distance in points
                          # NQ: 50pt = $1,000 max risk per trade
                          # MNQ: 50pt = $100 max risk per trade

TRAIL_ACTIVATE = 25.0    # points in profit required before trailing activates
                          # trade must move 25pts in your favor first

TRAIL_DIST     = 40.0    # how far the trailing stop sits behind the best price
                          # e.g. if NQ rallies to entry+80pt, trail = entry+40pt
```

### Session Filter
```python
SESSION_START = datetime.time(9, 30)    # no trades before this time
SESSION_END   = datetime.time(16, 0)    # all positions closed at this time
TRADE_DAYS    = {0, 1, 2, 3, 4}        # Mon=0, Tue=1, Wed=2, Thu=3, Fri=4
                                        # remove a number to skip that day
```

**Example — trade only afternoons starting at 10:30 AM:**
```python
SESSION_START = datetime.time(10, 30)
SESSION_END   = datetime.time(16, 0)
```

**Example — skip Mondays and Fridays:**
```python
TRADE_DAYS = {1, 2, 3}    # Tuesday, Wednesday, Thursday only
```

---

## Output

### Console
Prints a full summary report including total trades, win rate, profit factor, reward:risk ratio, session breakdown (morning vs afternoon), and exit reason counts.

### Trade Log CSV
Saved automatically to `nq_ema_trades.csv` in the same folder. Contains one row per trade:

| Column | Description |
|---|---|
| `entry_time` | Datetime the trade was entered |
| `exit_time` | Datetime the trade was exited |
| `side` | LONG or SHORT |
| `entry` | Entry price |
| `exit` | Exit price |
| `pnl` | Net P&L in dollars (after commission) |
| `reason` | STOP LOSS / TRAIL STOP / EMA CROSS / SESSION END |
| `best_excursion` | Max favorable price movement in points |
| `duration_min` | Trade duration in minutes |
| `session` | Morning or Afternoon |

### Equity Chart
If `matplotlib` is installed, saves `nq_ema_equity.png` showing the cumulative equity curve and drawdown chart automatically.

---

## Backtest Results (Synthetic Data · 1 Week)

Results from the built-in demo run. For reference only — run with real data for meaningful results.

| Metric | Value |
|---|---|
| Period | Feb 10–11, 2025 (synthetic) |
| Total Trades | 19 |
| Win Rate | 42.1% |
| Avg Win | $1,371 |
| Avg Loss | -$699 |
| Reward:Risk | 1.96× |
| Profit Factor | 1.43 |
| Gross P&L | +$3,284 |
| Max Drawdown | -$2,253 |
| Best Trade | +$4,231 |
| Morning P&L | -$1,336 (12 trades) |
| Afternoon P&L | +$4,620 (7 trades) |

---

## Adapting for MNQ (Micro Contracts)

To switch from 1 NQ to 1 MNQ, change two lines in the configuration:

```python
POINT_VALUE = 2.0     # MNQ = $2 per point (was 20.0)
COMMISSION  = 0.42    # MNQ round-trip (was 4.24)
```

Everything else stays the same. Risk per trade at 50pt hard stop becomes $100 instead of $1,000.

---

## Notes & Limitations

- **Synthetic demo data** uses a statistical NQ price model (GBM, ~0.12% std/bar). Results will differ from live market data.
- **SL/TP are checked bar-by-bar** using the bar's high and low. In fast markets, actual fills may differ due to slippage.
- **Slippage is not modelled.** On a 1-minute NQ chart, expect 1–2 ticks ($5–$10) of slippage at entry and exit in real trading.
- **yfinance futures data** may have gaps or be adjusted. Always cross-check key trades against your broker's chart.
- This script is for **educational and research purposes only** and does not constitute financial advice.

---

## File Structure

```
nq_ema_backtest.py      ← main backtest script (edit this)
nq_ema_trades.csv       ← trade log output (auto-generated)
nq_ema_equity.png       ← equity chart (auto-generated if matplotlib installed)
nq_1min.csv             ← your data file (if using USE_CSV mode)
README.md               ← this file
```

---

*Not financial advice. Past performance does not guarantee future results.*
