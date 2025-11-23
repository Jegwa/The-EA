import time
import math
from collections import defaultdict
from datetime import datetime, timedelta
from broker import BrokerClient

SYMBOLS = ["XAUUSD","USDJPY","EURUSD","BTCUSD","GBPUSD"]
MAGIC = 123456
LOT_SIZE = 0.01
STOP_LOSS_PIPS = 30
TAKE_PROFIT_PIPS = 60
MIN_PROB = 65.0
MIN_BARS_BETWEEN_TRADES = 5
MAX_TRADES_PER_DAY = 2
POLL_SECONDS = 10          # how often to poll prices
MA_FAST = 14
MA_SLOW = 50

client = BrokerClient()  # you will implement: reads API keys from env

# tracking
last_trade_time = {s: datetime(1970,1,1) for s in SYMBOLS}
trades_today = defaultdict(int)
last_day_checked = datetime.utcnow().date()

def period_seconds():
    # Using 1-minute bars by default (adjust if you want hourly/daily)
    return 60

def calc_ma(symbol, bars, period):
    # bars is list of closes newest-first or oldest-first — see broker.get_history
    if len(bars) < period:
        return None
    return sum(bars[-period:]) / period  # simple moving average

def calculate_trend_strength(symbol):
    # retrieve history (e.g., 100 bars)
    history = client.get_history(symbol, timeframe='M1', count=200)  # implement in broker
    closes = [h['close'] for h in history]
    ma_fast = calc_ma(symbol, closes, MA_FAST)
    ma_slow = calc_ma(symbol, closes, MA_SLOW)
    # previous values
    ma_fast_prev = calc_ma(symbol, closes[:-1], MA_FAST) if len(closes) > 1 else ma_fast
    ma_slow_prev = calc_ma(symbol, closes[:-1], MA_SLOW) if len(closes) > 1 else ma_slow
    if ma_fast is None or ma_slow is None:
        return 0.0
    if ma_fast > ma_slow and ma_fast_prev > ma_slow_prev:
        return 1.0
    if ma_fast < ma_slow and ma_fast_prev < ma_slow_prev:
        return -1.0
    return 0.0

def calculate_support_resistance(symbol, is_buy):
    history = client.get_history(symbol, timeframe='M1', count=50)
    highs = [h['high'] for h in history]
    lows = [h['low'] for h in history]
    if not highs or not lows:
        return 0
    recent_high = max(highs)
    recent_low = min(lows)
    price = client.get_price(symbol)['mid']
    dist_res = recent_high - price
    dist_sup = price - recent_low
    # defensive checks
    if is_buy:
        if dist_sup < dist_res * 0.5: return 10
        if dist_sup > dist_res * 2: return -10
    else:
        if dist_res < dist_sup * 0.5: return 10
        if dist_res > dist_sup * 2: return -10
    return 0

def calculate_price_action(symbol, is_buy):
    ohlc = client.get_history(symbol, timeframe='M1', count=1)[-1]
    if not ohlc: return 0
    open_ = ohlc['open']; close = ohlc['close']
    if is_buy and close > open_: return 5
    if (not is_buy) and close < open_: return 5
    return 0

def calculate_volume_analysis(symbol):
    hist = client.get_history(symbol, timeframe='M1', count=11)
    if len(hist) < 2: return 0
    curr = hist[-1]['volume']
    avg = sum(h['volume'] for h in hist[:-1]) / (len(hist)-1)
    if avg == 0: return 0
    if curr > avg * 1.2: return 5
    return 0

def calculate_trade_probability(symbol, is_buy):
    prob = 50.0
    trend = calculate_trend_strength(symbol)
    if (is_buy and trend>0) or (not is_buy and trend<0):
        prob += 15
    else:
        prob -= 10
    prob += calculate_support_resistance(symbol, is_buy)
    prob += calculate_price_action(symbol, is_buy)
    prob += calculate_volume_analysis(symbol)
    prob = max(5, min(95, prob))
    return prob

def is_safe_to_trade(symbol):
    global last_day_checked, trades_today
    if datetime.utcnow().date() != last_day_checked:
        last_day_checked = datetime.utcnow().date()
        trades_today = defaultdict(int)
    if trades_today[symbol] >= MAX_TRADES_PER_DAY:
        return False
    if (datetime.utcnow() - last_trade_time[symbol]).total_seconds() < MIN_BARS_BETWEEN_TRADES * period_seconds():
        return False
    spread = client.get_price(symbol)['ask'] - client.get_price(symbol)['bid']
    # assume point is small; for simplicity check spread in pips roughly:
    if spread > 0.0002:  # adjust threshold per symbol; this is simplistic
        return False
    return True

def calculate_safe_lot_size():
    balance = client.get_balance()
    if balance < 10:
        return 0
    return LOT_SIZE

def open_buy(symbol):
    if not is_safe_to_trade(symbol): return
    prob = calculate_trade_probability(symbol, True)
    if prob < MIN_PROB:
        return
    lot = calculate_safe_lot_size()
    if lot <= 0: return
    price = client.get_price(symbol)['ask']
    sl = price - STOP_LOSS_PIPS * client.pip_value(symbol)
    tp = price + TAKE_PROFIT_PIPS * client.pip_value(symbol)
    order = client.place_order(symbol, side='buy', volume=lot, sl=sl, tp=tp)
    if order.get('success'):
        last_trade_time[symbol] = datetime.utcnow()
        trades_today[symbol] += 1

def open_sell(symbol):
    if not is_safe_to_trade(symbol): return
    prob = calculate_trade_probability(symbol, False)
    if prob < MIN_PROB:
        return
    lot = calculate_safe_lot_size()
    if lot <= 0: return
    price = client.get_price(symbol)['bid']
    sl = price + STOP_LOSS_PIPS * client.pip_value(symbol)
    tp = price - TAKE_PROFIT_PIPS * client.pip_value(symbol)
    order = client.place_order(symbol, side='sell', volume=lot, sl=sl, tp=tp)
    if order.get('success'):
        last_trade_time[symbol] = datetime.utcnow()
        trades_today[symbol] += 1

def has_open_trade(symbol):
    # check open positions for this magic and symbol
    positions = client.get_positions()
    for p in positions:
        if p.get('symbol') == symbol and p.get('magic') == MAGIC:
            return True
    return False

def main_loop():
    while True:
        try:
            for s in SYMBOLS:
                if has_open_trade(s):
                    continue
                buyp = calculate_trade_probability(s, True)
                sellp = calculate_trade_probability(s, False)
                if buyp > sellp + 10 and buyp >= MIN_PROB:
                    open_buy(s)
                elif sellp > buyp + 10 and sellp >= MIN_PROB:
                    open_sell(s)
            time.sleep(POLL_SECONDS)
        except Exception as e:
            print("Error in main loop:", e)
            time.sleep(5)

if __name__ == "__main__":
    print("Starting Python EA bot")
    main_loop()