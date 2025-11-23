//+------------------------------------------------------------------+
//| Ultra Safe SMC EA for Small Capital                             |
//+------------------------------------------------------------------+
#property copyright "Safe SMC Micro EA"
#property link      ""
#property version   "1.00"
#property strict

// === USER SETTINGS ===
input long   MagicNumber    = 123456;     // Unique EA ID
input double LotSize        = 0.01;       // Fixed 0.01 lot size
input int    StopLossPips   = 30;         // TIGHT stop loss for safety
input int    TakeProfitPips = 60;         // Conservative take profit
input double MaxRiskPercent = 1.0;        // Maximum risk per trade
input bool   UseSafeSignals = true;       // Only high-probability trades
input int    MinBarsBetweenTrades = 5;    // Avoid overtrading
input int    MaxTradesPerDay = 2;         // Limit daily trades

// === GLOBALS ===
MqlTradeRequest request;
MqlTradeResult  result;
datetime lastTradeTime = 0;
int todayTrades = 0;
datetime lastDayChecked = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Ultra Safe SMC EA Started - Designed for Small Accounts");
   ResetDailyCounter();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Reset daily trade counter                                        |
//+------------------------------------------------------------------+
void ResetDailyCounter()
{
   MqlDateTime today;
   TimeCurrent(today);
   today.day_of_year = today.day;
   todayTrades = 0;
   lastDayChecked = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate probability for safe trading                          |
//+------------------------------------------------------------------+
double CalculateTradeProbability(bool isBuy)
{
   double probability = 50.0; // Base 50%
   
   // 1. Trend Analysis (30% weight)
   double trendStrength = CalculateTrendStrength();
   if((isBuy && trendStrength > 0) || (!isBuy && trendStrength < 0))
      probability += 15;
   else
      probability -= 10;
   
   // 2. Support/Resistance (30% weight)
   double srStrength = CalculateSupportResistance(isBuy);
   probability += srStrength;
   
   // 3. Price Action (20% weight)
   double paStrength = CalculatePriceAction(isBuy);
   probability += paStrength;
   
   // 4. Volume Analysis (20% weight)
   double volumeStrength = CalculateVolumeAnalysis();
   probability += volumeStrength;
   
   return MathMin(95, MathMax(5, probability)); // Cap between 5-95%
}

//+------------------------------------------------------------------+
//| Calculate trend strength                                         |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
   double maFast = iMA(_Symbol, _Period, 14, 0, MODE_SMA, PRICE_CLOSE, 0);
   double maSlow = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
   double maPrevFast = iMA(_Symbol, _Period, 14, 0, MODE_SMA, PRICE_CLOSE, 1);
   double maPrevSlow = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE, 1);
   
   if(maFast > maSlow && maPrevFast > maPrevSlow) return 1.0;    // Strong uptrend
   if(maFast < maSlow && maPrevFast < maPrevSlow) return -1.0;   // Strong downtrend
   return 0.0; // No clear trend
}

//+------------------------------------------------------------------+
//| Calculate support/resistance levels                              |
//+------------------------------------------------------------------+
double CalculateSupportResistance(bool isBuy)
{
   double currentPrice = (Ask + Bid) / 2;
   
   // Simple S/R using recent highs/lows
   double recentHigh = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, 20, 1));
   double recentLow = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, 20, 1));
   
   // Distance to S/R levels
   double distanceToResistance = recentHigh - currentPrice;
   double distanceToSupport = currentPrice - recentLow;
   
   if(isBuy)
   {
      // Better probability if we're near support
      if(distanceToSupport < distanceToResistance * 0.5) return 10;
      if(distanceToSupport > distanceToResistance * 2) return -10;
   }
   else
   {
      // Better probability if we're near resistance
      if(distanceToResistance < distanceToSupport * 0.5) return 10;
      if(distanceToResistance > distanceToSupport * 2) return -10;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate price action signals                                   |
//+------------------------------------------------------------------+
double CalculatePriceAction(bool isBuy)
{
   double open = iOpen(_Symbol, _Period, 0);
   double high = iHigh(_Symbol, _Period, 0);
   double low = iLow(_Symbol, _Period, 0);
   double close = iClose(_Symbol, _Period, 0);
   
   // Bullish candle for buy, bearish for sell
   if(isBuy && close > open) return 5;
   if(!isBuy && close < open) return 5;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate volume analysis                                        |
//+------------------------------------------------------------------+
double CalculateVolumeAnalysis()
{
   long currentVolume = iVolume(_Symbol, _Period, 0);
   long avgVolume = 0;
   
   for(int i = 1; i <= 10; i++)
      avgVolume += iVolume(_Symbol, _Period, i);
   avgVolume /= 10;
   
   if(currentVolume > avgVolume * 1.2) return 5;  // High volume = better signal
   return 0;
}

//+------------------------------------------------------------------+
//| Check if safe to trade                                           |
//+------------------------------------------------------------------+
bool IsSafeToTrade()
{
   // Check daily trade limit
   if(TimeCurrent() - lastDayChecked >= 86400) // New day
      ResetDailyCounter();
   
   if(todayTrades >= MaxTradesPerDay)
   {
      Print("Daily trade limit reached: ", MaxTradesPerDay);
      return false;
   }
   
   // Check time between trades
   if(TimeCurrent() - lastTradeTime < MinBarsBetweenTrades * PeriodSeconds())
   {
      Print("Waiting between trades...");
      return false;
   }
   
   // Avoid volatile periods (spread check)
   double spread = Ask - Bid;
   if(spread > 20 * _Point) // More than 2 pips spread
   {
      Print("Spread too wide: ", NormalizeDouble(spread / _Point, 1), " pips");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size with extra safety                       |
//+------------------------------------------------------------------+
double CalculateSafeLotSize()
{
   // For £1 account, we'll use fixed 0.01 but with extra checks
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(accountBalance < 10) // Emergency stop if account too low
   {
      Print("ACCOUNT TOO LOW - STOPPING TRADING");
      return 0;
   }
   
   return LotSize; // Fixed 0.01 for safety
}

//+------------------------------------------------------------------+
//| Open Buy Order with Safety Checks                               |
//+------------------------------------------------------------------+
void OpenBuy()
{
   if(!IsSafeToTrade()) return;
   
   double probability = CalculateTradeProbability(true);
   if(probability < 65.0) // Minimum 65% probability
   {
      Print("BUY probability too low: ", probability, "%");
      return;
   }
   
   double lotSize = CalculateSafeLotSize();
   if(lotSize <= 0) return;
   
   ZeroMemory(request);
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lotSize;
   request.type     = ORDER_TYPE_BUY;
   request.price    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.sl       = NormalizeDouble(Ask - StopLossPips * _Point, _Digits);
   request.tp       = NormalizeDouble(Ask + TakeProfitPips * _Point, _Digits);
   request.magic    = MagicNumber;
   request.deviation= 10;
   
   if(OrderSend(request, result))
   {
      Print("SAFE BUY opened. Prob: ", probability, "%, Ticket: ", result.order);
      lastTradeTime = TimeCurrent();
      todayTrades++;
   }
   else
   {
      Print("Error opening BUY: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Order with Safety Checks                              |
//+------------------------------------------------------------------+
void OpenSell()
{
   if(!IsSafeToTrade()) return;
   
   double probability = CalculateTradeProbability(false);
   if(probability < 65.0) // Minimum 65% probability
   {
      Print("SELL probability too low: ", probability, "%");
      return;
   }
   
   double lotSize = CalculateSafeLotSize();
   if(lotSize <= 0) return;
   
   ZeroMemory(request);
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lotSize;
   request.type     = ORDER_TYPE_SELL;
   request.price    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   request.sl       = NormalizeDouble(Bid + StopLossPips * _Point, _Digits);
   request.tp       = NormalizeDouble(Bid - TakeProfitPips * _Point, _Digits);
   request.magic    = MagicNumber;
   request.deviation= 10;
   
   if(OrderSend(request, result))
   {
      Print("SAFE SELL opened. Prob: ", probability, "%, Ticket: ", result.order);
      lastTradeTime = TimeCurrent();
      todayTrades++;
   }
   else
   {
      Print("Error opening SELL: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Check for open positions                                         |
//+------------------------------------------------------------------+
bool HasOpenTrade()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Main trading logic with ultra safety                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only trade once per bar to avoid noise
   static datetime lastBarTime = 0;
   if(lastBarTime == iTime(_Symbol, _Period, 0)) return;
   lastBarTime = iTime(_Symbol, _Period, 0);
   
   // Don't trade if already in position
   if(HasOpenTrade()) return;
   
   // Calculate probabilities for both directions
   double buyProb = CalculateTradeProbability(true);
   double sellProb = CalculateTradeProbability(false);
   
   // Only trade if one direction has clear advantage
   if(buyProb > sellProb + 10 && buyProb >= 65) // Buy has 10%+ advantage
   {
      OpenBuy();
   }
   else if(sellProb > buyProb + 10 && sellProb >= 65) // Sell has 10%+ advantage
   {
      OpenSell();
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Ultra Safe SMC EA Stopped. Total trades today: ", todayTrades);
}