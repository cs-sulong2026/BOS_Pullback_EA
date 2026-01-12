//+------------------------------------------------------------------+
//|                                                       BOS_EA.mq5 |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 22.12.2025 - Initial release                                     |
//| BOS + Pullback EA with Multi-Timeframe Analysis                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"
#property version   "1.00"
#property description "BOS Pullback EA - Entry at BOS level with HTF confirmation"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum TRADE_DIRECTION
{
   TRADE_BOTH,      // Trade both Buy and Sell
   TRADE_BUY_ONLY,  // Trade Buy only
   TRADE_SELL_ONLY  // Trade Sell only
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Account Info ==="
input bool            InpEnableEvaluation = true;  // Enable Prop Firm Evaluation Mode
input double          InpInitialBalance = 10000.0; // Initial account balance for calculations
input double          InpDailyLossLimitPct = 5.0;   // Daily loss limit percentage
input double          InpMaxLossLimitPct = 10.0;    // Maximum loss limit percentage
input double          iInpProfitTargetPct = 10.0;   // Daily profit target percentage

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpHighTF = PERIOD_H4;      // High Timeframe for swing points
input ENUM_TIMEFRAMES InpLowTF = PERIOD_M15;      // Low Timeframe for BOS detection
input int             InpSwingLeftBars = 5;       // Swing detection left bars
input int             InpSwingRightBars = 5;      // Swing detection right bars

input group "=== Entry Settings ==="
input TRADE_DIRECTION InpTradeDirection = TRADE_BOTH; // Allowed trade direction
input bool            InpEnableSupertrend = true; // Enable trade by HTF trend
input int             InpPullbackPoints = 50;     // Min pullback points to BOS level
input int             InpBOSConfirmBars = 2;      // BOS confirmation bars

input group "=== Risk Management ==="
input bool            InpUsePercentage = false;   // Use percentage-based lot sizing
input double          InpRiskPercent = 1.0;       // Risk percentage per trade (when UsePercentage=true)
input double          InpLotSize = 0.01;          // Fixed lot size (when UsePercentage=false)
input int             InpStopLoss = 0;            // Stop Loss in pips (0=auto from swing)
input int             InpTakeProfit = 0;          // Take Profit in pips (0=auto from swing)
input double          InpRiskRewardRatio = 2.0;   // Risk:Reward ratio (when SL/TP=0)
input int             InpMaxBuyTrades = 1;        // Max simultaneous BUY trades
input int             InpMaxSellTrades = 1;       // Max simultaneous SELL trades
input bool            InpBlockOppositeEntry = true; // Block entry if opposite positions exist
input bool            InpCloseOnNewSwing = true;  // Close positions when new HTF swing detected
input bool            InpUseTrailingStop = false; // Enable trailing stop
input int             InpTrailingStop = 50;       // Trailing stop distance in pips
input int             InpTrailingStep = 10;       // Minimum price movement to trail (pips)

input group "=== Advanced ==="
input int             InpMagicNumber = 123456;    // Magic number
input string          InpTradeComment = "BOS_EA"; // Trade comment
input bool            InpShowInfo = true;         // Show info on chart

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
enum TREND_TYPE
{
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_NEUTRAL
};

struct SwingPoint
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isValid;
};

struct BOSLevel
{
   double   price;
   datetime time;
   bool     isBullish;
   bool     isActive;
   int      barIndex;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade            trade;
CSymbolInfo       symbolInfo;
datetime          lastBarTime;

// High Timeframe Swing Points
SwingPoint        htfLastHigh;
SwingPoint        htfLastLow;
SwingPoint        htfPrevHigh;
SwingPoint        htfPrevLow;

// Low Timeframe Swing Points
SwingPoint        ltfLastHigh;
SwingPoint        ltfLastLow;
SwingPoint        ltfPrevHigh;
SwingPoint        ltfPrevLow;

// BOS Detection
BOSLevel          currentBOS;
TREND_TYPE        htfTrend = TREND_NEUTRAL;
bool              waitingForPullback = false;
bool              lastHTFSwingWasHigh = false;

// Account tracking
double            dailyStartBalance = 0.0;
datetime          currentDay = 0;
bool              dailyResetDone = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   trade.LogLevel(LOG_LEVEL_NO); // Only log errors, not every trade operation
   
   // Initialize symbol info
   symbolInfo.Name(_Symbol);
   symbolInfo.Refresh();
   
   // Initialize daily balance tracking
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   currentDay = TimeCurrent();
   
   // Initialize swing points
   InitSwingPoints();
   
   // Initialize BOS
   currentBOS.price = 0.0;
   currentBOS.time = 0;
   currentBOS.isBullish = false;
   currentBOS.isActive = false;
   currentBOS.barIndex = 0;
   
   lastBarTime = 0;
   
   Print("BOS EA initialized - Symbol: ", _Symbol);
   Print("High TF: ", EnumToString(InpHighTF), " | Low TF: ", EnumToString(InpLowTF));
   
   // Perform initial market analysis
   AnalyzeHighTimeframe();
   AnalyzeLowTimeframe();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up chart objects
   ObjectsDeleteAll(0, "BOS_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for daily reset at 23:55 (only in evaluation mode)
   if(InpEnableEvaluation)
      CheckDailyReset();
   
   // Check account limits when there are open positions (only in evaluation mode)
   if(InpEnableEvaluation && GetOpenPositionsCount() > 0)
      CheckAccountLimits();
   
   // Apply trailing stop on every tick if enabled
   if(InpUseTrailingStop)
      ApplyTrailingStop();
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, InpLowTF, 0);
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   
   // Update analysis
   AnalyzeHighTimeframe();
   AnalyzeLowTimeframe();
   
   // Draw LTF swing labels
   DrawLTFSwingLabels();
   
   // Determine HTF trend
   DetermineHTFTrend();
   
   // Check for BOS on low timeframe
   if(!waitingForPullback)
   {
      CheckForBOS();
   }
   
   // Check for pullback entry
   if(waitingForPullback && currentBOS.isActive)
   {
      ExtendBOSLevel(currentBarTime, currentBOS.price);
      CheckForEntry();
   }
   
   // Display info
   if(InpShowInfo)
      DisplayInfo();
}

//+------------------------------------------------------------------+
//| Initialize swing points                                          |
//+------------------------------------------------------------------+
void InitSwingPoints()
{
   htfLastHigh.price = 0.0;
   htfLastHigh.time = 0;
   htfLastHigh.barIndex = 0;
   htfLastHigh.isValid = false;
   
   htfLastLow.price = 0.0;
   htfLastLow.time = 0;
   htfLastLow.barIndex = 0;
   htfLastLow.isValid = false;
   
   htfPrevHigh.price = 0.0;
   htfPrevHigh.time = 0;
   htfPrevHigh.barIndex = 0;
   htfPrevHigh.isValid = false;
   
   htfPrevLow.price = 0.0;
   htfPrevLow.time = 0;
   htfPrevLow.barIndex = 0;
   htfPrevLow.isValid = false;
   
   // Low timeframe
   ltfLastHigh.price = 0.0;
   ltfLastHigh.time = 0;
   ltfLastHigh.barIndex = 0;
   ltfLastHigh.isValid = false;
   
   ltfLastLow.price = 0.0;
   ltfLastLow.time = 0;
   ltfLastLow.barIndex = 0;
   ltfLastLow.isValid = false;
   
   ltfPrevHigh.price = 0.0;
   ltfPrevHigh.time = 0;
   ltfPrevHigh.barIndex = 0;
   ltfPrevHigh.isValid = false;
   
   ltfPrevLow.price = 0.0;
   ltfPrevLow.time = 0;
   ltfPrevLow.barIndex = 0;
   ltfPrevLow.isValid = false;
}

//+------------------------------------------------------------------+
//| Analyze High Timeframe for swing points                          |
//+------------------------------------------------------------------+
void AnalyzeHighTimeframe()
{
   int lookback = 100;
   int foundHighs = 0;
   int foundLows = 0;
   
   // Temporary storage for newly found swings
   SwingPoint tempLastHigh, tempPrevHigh;
   SwingPoint tempLastLow, tempPrevLow;
   
   // Initialize temp swings
   tempLastHigh.isValid = false;
   tempPrevHigh.isValid = false;
   tempLastLow.isValid = false;
   tempPrevLow.isValid = false;
   
   // Search for swing highs
   for(int i = InpSwingRightBars; i < lookback && foundHighs < 2; i++)
   {
      if(IsSwingHigh(i, InpHighTF))
      {
         double highPrice = iHigh(_Symbol, InpHighTF, i);
         datetime highTime = iTime(_Symbol, InpHighTF, i);
         
         if(foundHighs == 0)
         {
            tempLastHigh.price = highPrice;
            tempLastHigh.time = highTime;
            tempLastHigh.barIndex = i;
            tempLastHigh.isValid = true;
            foundHighs++;
         }
         else if(foundHighs == 1)
         {
            tempPrevHigh.price = highPrice;
            tempPrevHigh.time = highTime;
            tempPrevHigh.barIndex = i;
            tempPrevHigh.isValid = true;
            foundHighs++;
         }
      }
   }
   
   // Search for swing lows
   for(int i = InpSwingRightBars; i < lookback && foundLows < 2; i++)
   {
      if(IsSwingLow(i, InpHighTF))
      {
         double lowPrice = iLow(_Symbol, InpHighTF, i);
         datetime lowTime = iTime(_Symbol, InpHighTF, i);
         
         if(foundLows == 0)
         {
            tempLastLow.price = lowPrice;
            tempLastLow.time = lowTime;
            tempLastLow.barIndex = i;
            tempLastLow.isValid = true;
            foundLows++;
         }
         else if(foundLows == 1)
         {
            tempPrevLow.price = lowPrice;
            tempPrevLow.time = lowTime;
            tempPrevLow.barIndex = i;
            tempPrevLow.isValid = true;
            foundLows++;
         }
      }
   }
   
   // Update htfLastHigh if new swing found
   if(tempLastHigh.isValid)
   {
      if(!htfLastHigh.isValid || tempLastHigh.time != htfLastHigh.time)
      {
         htfPrevHigh = htfLastHigh;
         htfLastHigh = tempLastHigh;
         DrawSwingPoints("HTF Last Swing High", InpHighTF, htfLastHigh, STYLE_SOLID, 2);
         Print("Updated HTF Last Swing High at ", htfLastHigh.price, " Time: ", TimeToString(htfLastHigh.time));
         
         // Close all BUY positions when new high is detected (if enabled)
         if(InpCloseOnNewSwing)
            CloseAllPositions(POSITION_TYPE_BUY);
         
         // Invalidate existing BOS when new HTF swing is detected
         if(currentBOS.isActive)
         {
            Print("New HTF Swing High detected - Invalidating existing BOS");
            currentBOS.isActive = false;
            waitingForPullback = false;
            ObjectDelete(0, "BOS_Level");
         }
      }
      
      if(tempPrevHigh.isValid)
      {
         htfPrevHigh = tempPrevHigh;
         DrawSwingPoints("HTF Previous Swing High", InpHighTF, htfPrevHigh, STYLE_SOLID, 2);
      }
   }
   
   // Update htfLastLow if new swing found
   if(tempLastLow.isValid)
   {
      if(!htfLastLow.isValid || tempLastLow.time != htfLastLow.time)
      {
         htfPrevLow = htfLastLow;
         htfLastLow = tempLastLow;
         DrawSwingPoints("HTF Last Swing Low", InpHighTF, htfLastLow, STYLE_SOLID, 2);
         Print("Updated HTF Last Swing Low at ", htfLastLow.price, " Time: ", TimeToString(htfLastLow.time));
         
         // Close all SELL positions when new low is detected (if enabled)
         if(InpCloseOnNewSwing)
            CloseAllPositions(POSITION_TYPE_SELL);
         
         // Invalidate existing BOS when new HTF swing is detected
         if(currentBOS.isActive)
         {
            Print("New HTF Swing Low detected - Invalidating existing BOS");
            currentBOS.isActive = false;
            waitingForPullback = false;
            ObjectDelete(0, "BOS_Level");
         }
      }
      
      if(tempPrevLow.isValid)
      {
         htfPrevLow = tempPrevLow;
         DrawSwingPoints("HTF Previous Swing Low", InpHighTF, htfPrevLow, STYLE_SOLID, 2);
      }
   }
   
   // Determine which swing point is most recent based on timestamp
   if(htfLastHigh.isValid && htfLastLow.isValid)
   {
      // Compare timestamps - more recent time means it formed later
      if(htfLastHigh.time > htfLastLow.time)
         lastHTFSwingWasHigh = true;
      else if(htfLastHigh.time < htfLastLow.time)
         lastHTFSwingWasHigh = false;
      // If timestamps are equal (unlikely), use bar index (lower = more recent)
      else if(htfLastHigh.barIndex < htfLastLow.barIndex)
         lastHTFSwingWasHigh = true;
      else
         lastHTFSwingWasHigh = false;
   }
   else if(htfLastHigh.isValid)
      lastHTFSwingWasHigh = true;
   else if(htfLastLow.isValid)
      lastHTFSwingWasHigh = false;

   //---
   // Print("lastHTFSwingWasHigh: ", lastHTFSwingWasHigh, 
   //       " | Last High Time: ", (htfLastHigh.isValid ? TimeToString(htfLastHigh.time) : "N/A"),
   //       " | Last Low Time: ", (htfLastLow.isValid ? TimeToString(htfLastLow.time) : "N/A"));
}

//+------------------------------------------------------------------+
//| Analyze Low Timeframe for swing points                           |
//+------------------------------------------------------------------+
void AnalyzeLowTimeframe()
{
   int lookback = 50;
   
   // Reset previous values
   ltfPrevHigh.isValid = false;
   ltfPrevLow.isValid = false;
   
   for(int i = InpSwingRightBars; i < lookback; i++)
   {
      // Check for swing high
      if(IsSwingHigh(i, InpLowTF))
      {
         double highPrice = iHigh(_Symbol, InpLowTF, i);
         datetime highTime = iTime(_Symbol, InpLowTF, i);
         
         if(!ltfLastHigh.isValid || highTime > ltfLastHigh.time)
         {
            ltfPrevHigh = ltfLastHigh;
            ltfLastHigh.price = highPrice;
            ltfLastHigh.time = highTime;
            ltfLastHigh.barIndex = i;
            ltfLastHigh.isValid = true;
         }
         else if(!ltfPrevHigh.isValid)
         {
            ltfPrevHigh.price = highPrice;
            ltfPrevHigh.time = highTime;
            ltfPrevHigh.barIndex = i;
            ltfPrevHigh.isValid = true;
         }
      }
      
      // Check for swing low
      if(IsSwingLow(i, InpLowTF))
      {
         double lowPrice = iLow(_Symbol, InpLowTF, i);
         datetime lowTime = iTime(_Symbol, InpLowTF, i);
         
         if(!ltfLastLow.isValid || lowTime > ltfLastLow.time)
         {
            ltfPrevLow = ltfLastLow;
            ltfLastLow.price = lowPrice;
            ltfLastLow.time = lowTime;
            ltfLastLow.barIndex = i;
            ltfLastLow.isValid = true;
         }
         else if(!ltfPrevLow.isValid)
         {
            ltfPrevLow.price = lowPrice;
            ltfPrevLow.time = lowTime;
            ltfPrevLow.barIndex = i;
            ltfPrevLow.isValid = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if bar is swing high                                       |
//+------------------------------------------------------------------+
bool IsSwingHigh(int bar, ENUM_TIMEFRAMES tf)
{
   double centerHigh = iHigh(_Symbol, tf, bar);
   
   // Check left bars
   for(int i = 1; i <= InpSwingLeftBars; i++)
   {
      if(iHigh(_Symbol, tf, bar + i) >= centerHigh)
         return false;
   }
   
   // Check right bars
   for(int i = 1; i <= InpSwingRightBars; i++)
   {
      if(iHigh(_Symbol, tf, bar - i) > centerHigh)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing low                                        |
//+------------------------------------------------------------------+
bool IsSwingLow(int bar, ENUM_TIMEFRAMES tf)
{
   double centerLow = iLow(_Symbol, tf, bar);
   
   // Check left bars
   for(int i = 1; i <= InpSwingLeftBars; i++)
   {
      if(iLow(_Symbol, tf, bar + i) <= centerLow)
         return false;
   }
   
   // Check right bars
   for(int i = 1; i <= InpSwingRightBars; i++)
   {
      if(iLow(_Symbol, tf, bar - i) < centerLow)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Determine High Timeframe Trend                                   |
//+------------------------------------------------------------------+
void DetermineHTFTrend()
{
   if(!htfLastHigh.isValid || !htfLastLow.isValid || !htfPrevHigh.isValid || !htfPrevLow.isValid)
   {
      htfTrend = TREND_NEUTRAL;
      return;
   }
   
   // Bullish: Higher Highs and Higher Lows
   if(htfLastHigh.price > htfPrevHigh.price && htfLastLow.price > htfPrevLow.price)
   {
      htfTrend = TREND_BULLISH;
   }
   // Bearish: Lower Highs and Lower Lows
   else if(htfLastHigh.price < htfPrevHigh.price && htfLastLow.price < htfPrevLow.price)
   {
      htfTrend = TREND_BEARISH;
   }
   else
   {
      htfTrend = TREND_NEUTRAL;
   }
}

//+------------------------------------------------------------------+
//| Check for Break of Structure on Low Timeframe                    |
//+------------------------------------------------------------------+
void CheckForBOS()
{
   if(!ltfLastHigh.isValid || !ltfLastLow.isValid)
      return;
   
   double currentClose = iClose(_Symbol, InpLowTF, 0);
   
   // When InpEnableSupertrend is enabled
   if(InpEnableSupertrend)
   {
      // Block trades when trend is neutral
      if(htfTrend == TREND_NEUTRAL)
         return;
      
      // Check for BEARISH BOS when trend is bearish
      if(htfTrend == TREND_BEARISH && InpTradeDirection != TRADE_BUY_ONLY)
      {
         // Bearish BOS: Price breaks below most recent swing low
         if(ltfLastLow.isValid)
         {
            if(currentClose < ltfLastLow.price && !currentBOS.isActive)
            {
               currentBOS.price = ltfLastLow.price;
               currentBOS.time = TimeCurrent();
               currentBOS.isBullish = false;
               currentBOS.isActive = true;
               currentBOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bearish BOS detected at ", currentBOS.price, " (HTF Trend: BEARISH)");
               DrawBOSLevel(currentBOS.price, currentBOS.time, false);
            }
         }
      }
      // Check for BULLISH BOS when trend is bullish
      else if(htfTrend == TREND_BULLISH && InpTradeDirection != TRADE_SELL_ONLY)
      {
         // Bullish BOS: Price breaks above most recent swing high
         if(ltfLastHigh.isValid)
         {
            if(currentClose > ltfLastHigh.price && !currentBOS.isActive)
            {
               currentBOS.price = ltfLastHigh.price;
               currentBOS.time = TimeCurrent();
               currentBOS.isBullish = true;
               currentBOS.isActive = true;
               currentBOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bullish BOS detected at ", currentBOS.price, " (HTF Trend: BULLISH)");
               DrawBOSLevel(currentBOS.price, currentBOS.time);
            }
         }
      }
   }
   // When InpEnableSupertrend is disabled - BOS follows last HTF swing point
   else
   {
      // If last HTF swing was HIGH, look for BEARISH BOS
      if(lastHTFSwingWasHigh && InpTradeDirection != TRADE_BUY_ONLY)
      {
         // Bearish BOS: Price breaks below most recent swing low
         if(ltfLastLow.isValid)
         {
            if(currentClose < ltfLastLow.price && !currentBOS.isActive)
            {
               currentBOS.price = ltfLastLow.price;
               currentBOS.time = TimeCurrent();
               currentBOS.isBullish = false;
               currentBOS.isActive = true;
               currentBOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bearish BOS detected at ", currentBOS.price, " (Last HTF swing was HIGH)");
               DrawBOSLevel(currentBOS.price, currentBOS.time, false);
            }
         }
      }
      // If last HTF swing was LOW, look for BULLISH BOS
      else if(!lastHTFSwingWasHigh && InpTradeDirection != TRADE_SELL_ONLY)
      {
         // Bullish BOS: Price breaks above most recent swing high
         if(ltfLastHigh.isValid)
         {
            if(currentClose > ltfLastHigh.price && !currentBOS.isActive)
            {
               currentBOS.price = ltfLastHigh.price;
               currentBOS.time = TimeCurrent();
               currentBOS.isBullish = true;
               currentBOS.isActive = true;
               currentBOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bullish BOS detected at ", currentBOS.price, " (Last HTF swing was LOW)");
               DrawBOSLevel(currentBOS.price, currentBOS.time);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Entry after Pullback                                   |
//+------------------------------------------------------------------+
void CheckForEntry()
{
   double currentPrice = iClose(_Symbol, InpLowTF, 0);
   double point = _Point;
   int minPullback = InpPullbackPoints;
   
   // Determine if trend check is required
   bool checkTrend = InpEnableSupertrend;
   
   // Bullish entry: Wait for pullback to BOS level
   if(currentBOS.isBullish && waitingForPullback)
   {
      // Check trend alignment if supertrend filter is enabled
      if(checkTrend && htfTrend != TREND_BULLISH)
         return;
      
      // Check trade direction filter
      if(InpTradeDirection == TRADE_SELL_ONLY)
         return;
      
      // Check if opposite positions exist
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_SELL) > 0)
      {
         Print("Blocked BUY entry - SELL positions already open");
         return;
      }
      
      // Check max buy trades limit
      if(GetOpenPositionsCount(POSITION_TYPE_BUY) >= InpMaxBuyTrades)
         return;
      
      // Check if price pulled back near BOS level
      double distancePoints = MathAbs(currentPrice - currentBOS.price) / point;
      
      if(distancePoints <= minPullback)
      {
         // Confirm with recent bullish candle
         double prevClose = iClose(_Symbol, InpLowTF, 1);
         double prevOpen = iOpen(_Symbol, InpLowTF, 1);
         
         Print("Bullish pullback detected - Distance: ", distancePoints, " points | Candle: ", (prevClose > prevOpen ? "Bullish" : "Bearish"));
         
         if(prevClose > prevOpen) // Bullish confirmation candle
         {
            ExecuteBuyTrade();
         }
      }
   }
   
   // Bearish entry: Wait for pullback to BOS level
   else if(!currentBOS.isBullish && waitingForPullback)
   {
      // Check trend alignment if supertrend filter is enabled
      if(checkTrend && htfTrend != TREND_BEARISH)
         return;
      
      // Check trade direction filter
      if(InpTradeDirection == TRADE_BUY_ONLY)
         return;
      
      // Check if opposite positions exist
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_BUY) > 0)
      {
         Print("Blocked SELL entry - BUY positions already open");
         return;
      }
      
      // Check max sell trades limit
      if(GetOpenPositionsCount(POSITION_TYPE_SELL) >= InpMaxSellTrades)
         return;
      
      // Check if price pulled back near BOS level
      double distancePoints = MathAbs(currentPrice - currentBOS.price) / point;
      
      if(distancePoints <= minPullback)
      {
         // Confirm with recent bearish candle
         double prevClose = iClose(_Symbol, InpLowTF, 1);
         double prevOpen = iOpen(_Symbol, InpLowTF, 1);
         
         Print("Bearish pullback detected - Distance: ", distancePoints, " points | Candle: ", (prevClose < prevOpen ? "Bearish" : "Bullish"));
         
         if(prevClose < prevOpen) // Bearish confirmation candle
         {
            ExecuteSellTrade();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl, tp;
   
   // Calculate pip value (10 points for 5-digit, 1 point for 3-digit)
   double pipSize = (_Digits == 5 || _Digits == 3) ? 10 * _Point : _Point;
   
   // Use input SL if specified, otherwise use automatic from swing points
   if(InpStopLoss > 0)
   {
      sl = ask - InpStopLoss * pipSize;
   }
   else
   {
      // Use HTF last low as SL if valid and below entry
      if(htfLastLow.isValid && htfLastLow.price < ask)
      {
         sl = NormalizeDouble(htfLastLow.price - 100 * _Point, _Digits);
      }
      else
      {
         Print("Warning: HTF last low invalid or too close. Using 100 pips default SL.");
         sl = ask - 100 * pipSize;
      }
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      tp = ask + InpTakeProfit * pipSize;
   }
   else
   {
      // // Try to use HTF swing high as TP target
      // if(htfLastHigh.isValid)
      // {
      //    tp = htfLastHigh.price - 200 * _Point;
      //    // Validate: TP must be above entry price for BUY
      //    if(tp <= ask)
      //    {
      //       Print("Warning: HTF last high (", htfLastHigh.price, ") is at or below entry price.");
      //       // Try previous HTF high as fallback
      //       if(htfPrevHigh.isValid)
      //       {
      //          tp = htfPrevHigh.price - 200 * _Point;
      //          if(tp <= ask)
      //          {
      //             Print("Warning: HTF previous high (", htfPrevHigh.price, ") also invalid. Using default 3000 pips TP.");
      //             tp = ask + 3000 * pipSize;
      //          }
      //          else
      //          {
      //             Print("Using HTF previous high as TP: ", htfPrevHigh.price);
      //          }
      //       }
      //       else
      //       {
      //          Print("No valid HTF previous high. Using default 3000 pips TP.");
      //          tp = ask + 3000 * pipSize;
      //       }
      //    }
      // }
      // Try to use HTF swing high as TP target
      if(htfPrevHigh.isValid)
      {
         tp = htfPrevHigh.price - 50 * _Point;
         // Validate: TP must be above entry price for BUY
         if(tp <= ask)
         {
            Print("Warning: HTF previous high (", htfPrevHigh.price, ") is at or below entry price. Using default 50 pips TP.");
            tp = ask + 50 * pipSize;
         }
      }
      else
      {
         // No HTF high available, use R:R ratio
         tp = ask + (ask - sl) * InpRiskRewardRatio;
      }
   }
   
   // Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Calculate lot size based on risk
   double lotSize = CalculateLotSize(ask, sl);
   Print("Attempting BUY - Entry: ", ask, " | SL: ", sl, " | TP: ", tp, " | Lot: ", lotSize);
   
   if(trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment))
   {
      Print("BUY order opened - Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
      waitingForPullback = false;
      currentBOS.isActive = false;
   }
   else
   {
      Print("Failed to open BUY order. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Trade                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp;
   
   // Calculate pip value (10 points for 5-digit, 1 point for 3-digit)
   double pipSize = (_Digits == 5 || _Digits == 3) ? 10 * _Point : _Point;
   
   // Use input SL if specified, otherwise use automatic from swing points
   if(InpStopLoss > 0)
   {
      sl = bid + InpStopLoss * pipSize;
   }
   else
   {
      // Use HTF last high as SL if valid and above entry
      if(htfLastHigh.isValid && htfLastHigh.price > bid)
      {
         sl = NormalizeDouble(htfLastHigh.price + 100 * _Point, _Digits);
      }
      else
      {
         Print("Warning: HTF last high invalid or too close. Using 100 pips default SL.");
         sl = bid + 100 * pipSize;
      }
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      tp = bid - InpTakeProfit * pipSize;
   }
   else
   {
      // // Try to use HTF swing low as TP target
      // if(htfLastLow.isValid)
      // {
      //    tp = htfLastLow.price + 200 * _Point;
      //    // Validate: TP must be below entry price for SELL
      //    if(tp >= bid)
      //    {
      //       Print("Warning: HTF last low (", htfLastLow.price, ") is at or above entry price.");
      //       // Try previous HTF low as fallback
      //       if(htfPrevLow.isValid)
      //       {
      //          tp = htfPrevLow.price + 200 * _Point;
      //          if(tp >= bid)
      //          {
      //             Print("Warning: HTF previous low (", htfPrevLow.price, ") also invalid. Using default 3000 pips TP.");
      //             tp = bid - 3000 * pipSize;
      //          }
      //          else
      //          {
      //             Print("Using HTF previous low as TP: ", htfPrevLow.price);
      //          }
      //       }
      //       else
      //       {
      //          Print("No valid HTF previous low. Using default 3000 pips TP.");
      //          tp = bid - 3000 * pipSize;
      //       }
      //    }
      // }
      if(htfPrevLow.isValid)
      {
         tp = htfPrevLow.price + 50 * _Point;
         // Validate: TP must be below entry price for SELL
         if(tp >= bid)
         {
            Print("Warning: HTF previous low (", htfPrevLow.price, ") is at or above entry price. Using default 50 pips TP.");
            tp = bid - 50 * pipSize;
         }
      }
      else
      {
         // No HTF low available, use R:R ratio
         tp = bid - (sl - bid) * InpRiskRewardRatio;
      }
   }
   
   // Normalize prices
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Calculate lot size based on risk
   double lotSize = CalculateLotSize(bid, sl);
   Print("Attempting SELL - Entry: ", bid, " | SL: ", sl, " | TP: ", tp, " | Lot: ", lotSize);
   // lotSize = 0.02; // For testing purposes only, remove in production
   
   if(trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment))
   {
      Print("SELL order opened - Entry: ", bid, " | SL: ", sl, " | TP: ", tp);
      waitingForPullback = false;
      currentBOS.isActive = false;
   }
   else
   {
      Print("Failed to open SELL order. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Get Open Positions Count (optionally filtered by type)           |
//+------------------------------------------------------------------+
int GetOpenPositionsCount(ENUM_POSITION_TYPE posType = -1)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            // If posType is specified, filter by position type
            if(posType == -1 || PositionGetInteger(POSITION_TYPE) == posType)
            {
               count++;
            }
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk Percentage                     |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss)
{
   if(!InpUsePercentage)
      return InpLotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * InpRiskPercent / 100.0;
   
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) > 0)
      pointValue = pointValue / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * _Point;
   
   double slDistance = MathAbs(entryPrice - stopLoss);
   double lotSize = 0.0;
   
   if(slDistance > 0 && pointValue > 0)
   {
      lotSize = riskAmount / (slDistance / _Point * pointValue);
      
      // Normalize lot size to allowed values
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   }
   else
   {
      lotSize = InpLotSize; // Fallback to fixed lot size
   }
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop to Open Positions                           |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   // double pipSize = (_Digits == 5 || _Digits == 3) ? 10 * _Point : _Point;
   double trailDistance = InpTrailingStop * _Point;
   double trailStep = InpTrailingStep * _Point;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      bool isProfitable = (posType == POSITION_TYPE_BUY) ? (currentPrice > posOpenPrice) : (currentPrice < posOpenPrice);
      
      double newSL = 0;
      bool needUpdate = false;
      
      if(posType == POSITION_TYPE_BUY)
      {
         // Check if trailing has started (price reached htfLastHigh)
         bool trailingStarted = htfLastHigh.isValid && currentPrice >= htfLastHigh.price;
         
         if(trailingStarted)
         {
            // Apply normal trailing stop
            newSL = NormalizeDouble(currentPrice - trailDistance, _Digits);
            newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);
            
            // Validate: new SL must be below current price and above entry
            if(newSL >= currentPrice)
            {
               continue; // Skip invalid SL
            }
            
            // Check if we should update (price moved enough and new SL is better)
            if(posSL == 0 || (newSL > posSL && (newSL - posSL) >= trailStep))
            {
               needUpdate = true;
            }
         }
         else
         {
            // Trailing not started yet - update SL to htfLastLow if it's better
            if(htfLastLow.isValid)
            {
               trailingStarted = isProfitable && (currentPrice - posOpenPrice) >= trailDistance;

               if(trailingStarted)
               {
                  // Apply normal trailing stop
                  newSL = NormalizeDouble(currentPrice - trailDistance, _Digits);
                  newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);               
                  // Only update if new SL is better (higher) than current SL and moved enough
                  if(posSL == 0 || (newSL > posSL && (newSL - posSL) >= trailStep))
                  {
                     needUpdate = true;
                  }
               }
               else
               {
                  newSL = NormalizeDouble(htfLastLow.price - 50 * _Point, _Digits);
               }
            }
         }
      }
      else // POSITION_TYPE_SELL
      {
         // Check if trailing has started (price reached htfLastLow)
         bool trailingStarted = htfLastLow.isValid && currentPrice <= htfLastLow.price;
         
         if(trailingStarted)
         {
            // Apply normal trailing stop
            newSL = NormalizeDouble(currentPrice + trailDistance, _Digits);
            newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);
            
            // Check if we should update (price moved enough and new SL is better)
            if(posSL == 0 || (newSL < posSL && (posSL - newSL) >= trailStep))
            {
               needUpdate = true;
            }
         }
         else
         {
            // Trailing not started yet - update SL to htfLastHigh if it's better
            if(htfLastHigh.isValid)
            {
               trailingStarted = isProfitable && (posOpenPrice - currentPrice) >= trailDistance;

               if(trailingStarted)
               {
                  // Apply normal trailing stop
                  newSL = NormalizeDouble(currentPrice + trailDistance, _Digits);
                  newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);               
                  // Only update if new SL is better (lower) than current SL and moved enough
                  if(posSL == 0 || (newSL < posSL && (posSL - newSL) >= trailStep))
                  {
                     needUpdate = true;
                  }
               }
               else
               {
                  newSL = NormalizeDouble(htfLastHigh.price + 50 * _Point, _Digits);
               }
            }
         }
      }
      
      if(needUpdate)
      {
         newSL = NormalizeDouble(newSL, _Digits);
         
         // Get broker's minimum stop level
         double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         double currentPriceForCheck = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // Validate minimum distance from current price
         if((posType == POSITION_TYPE_BUY && (currentPriceForCheck - newSL) < minStopLevel) ||
            (posType == POSITION_TYPE_SELL && (newSL - currentPriceForCheck) < minStopLevel))
         {
            Print("Warning: New SL too close to market. MinStopLevel: ", minStopLevel, " | Distance: ", 
                  (posType == POSITION_TYPE_BUY ? currentPriceForCheck - newSL : newSL - currentPriceForCheck));
            continue;
         }
         
         if(trade.PositionModify(ticket, newSL, posTP))
         {
            // Position modified successfully
         }
         else
         {
            int errorCode = GetLastError();
            Print("Failed to modify position #", ticket, ". Error: ", errorCode,
                  " | Current Price: ", currentPriceForCheck,
                  " | Old SL: ", posSL,
                  " | New SL: ", newSL,
                  " | TP: ", posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions by Type                                      |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            if(trade.PositionClose(ticket))
            {
               Print("Closed ", EnumToString(posType), " position #", ticket, " due to new HTF swing point");
            }
            else
            {
               Print("Failed to close position #", ticket, ". Error: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw BOS Level on Chart                                          |
//+------------------------------------------------------------------+
void DrawBOSLevel(double price, datetime time, bool isBullish=true)
{
   string str = isBullish ? "BULLISH" : "BEARISH";
   string objName = str+"\nBOS_Level";
   //--- set time1 and time2 for trend line
   datetime currentTime = TimeCurrent();
   //--- set time1 to previous 5 bars from BOS detection
   datetime time1 = time - 5 * PeriodSeconds(PERIOD_CURRENT);
   //--- set time2 to 5 bars ahead of current time
   datetime time2 = currentTime + 10 * PeriodSeconds(PERIOD_CURRENT);

   //--- Delete old object if exists to redraw at new level
   if(ObjectFind(0, objName) >= 0) {
      ObjectDelete(0, objName);
   }
   //--- Create trend line object
   ObjectCreate(0, objName, OBJ_TREND, 0, time1, price, time2, price);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   if(isBullish)
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
   else
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Extend BOS Level Line                                            |
//+------------------------------------------------------------------+
bool ExtendBOSLevel(datetime time, double price)
{
   string str = currentBOS.isBullish ? "BULLISH" : "BEARISH";
   string objName = str+"\nBOS_Level";
   datetime extend_time = time + 10 * PeriodSeconds(PERIOD_CURRENT);
//--- reset the error value
   ResetLastError();
//--- move trend line's anchor point
   if(!ObjectMove(0,objName,1,extend_time,price))
     {
      Print(__FUNCTION__,
            ": failed to move the anchor point! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return true;
}

//+------------------------------------------------------------------+
//| Draw LTF Swing Labels                                            |
//+------------------------------------------------------------------+
void DrawLTFSwingLabels()
{
   // Draw label for LTF Last High (SH)
   if(ltfLastHigh.isValid)
   {
      string objName = "BOS_LTF_SH";
      
      if(ObjectFind(0, objName) >= 0)
         ObjectDelete(0, objName);
      
      if(ObjectCreate(0, objName, OBJ_TEXT, 0, ltfLastHigh.time, ltfLastHigh.price))
      {
         ObjectSetString(0, objName, OBJPROP_TEXT, "SH");
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrangeRed);
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, "LTF Swing High @ " + DoubleToString(ltfLastHigh.price, _Digits));
      }
   }
   
   // Draw label for LTF Last Low (SL)
   if(ltfLastLow.isValid)
   {
      string objName = "BOS_LTF_SL";
      
      if(ObjectFind(0, objName) >= 0)
         ObjectDelete(0, objName);
      
      if(ObjectCreate(0, objName, OBJ_TEXT, 0, ltfLastLow.time, ltfLastLow.price))
      {
         ObjectSetString(0, objName, OBJPROP_TEXT, "SL");
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         ObjectSetString(0, objName, OBJPROP_TOOLTIP, "LTF Swing Low @ " + DoubleToString(ltfLastLow.price, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart                                       |
//+------------------------------------------------------------------+
void DrawSwingPoints(string name, ENUM_TIMEFRAMES tf, SwingPoint &lastPoint, ENUM_LINE_STYLE style, int width=1)
{
   if(!lastPoint.isValid)
      return;
   
   // Create unique object name
   string objName = "BOS_" + name + "_" + EnumToString(tf);
   
   // Determine if this is a high or low swing point
   bool isHigh = (StringFind(name, "High") >= 0);
   bool isHTF = (tf == InpHighTF);
   
   // Determine color and arrow code based on timeframe and swing type
   color arrowColor;
   int arrowCode;
   
   if(isHTF)
   {
      arrowColor = isHigh ? clrDarkOrange : clrDodgerBlue;
      arrowCode = isHigh ? 234 : 233; // 234 = down arrow, 233 = up arrow
   }
   else
   {
      arrowColor = isHigh ? clrOrangeRed : clrAqua;
      arrowCode = isHigh ? 234 : 233;
   }
   
   // Delete existing object if it exists
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Create arrow at swing point
   if(ObjectCreate(0, objName, OBJ_ARROW, 0, lastPoint.time, lastPoint.price))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, name + " [" + EnumToString(tf) + "] @ " + DoubleToString(lastPoint.price, _Digits));
   }
}

//+------------------------------------------------------------------+
//| Check for daily reset at 23:55                                   |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   // Check if it's 23:55
   if(currentTime.hour == 23 && currentTime.min == 55)
   {
      if(!dailyResetDone)
      {
         double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         
         // Set daily start balance to the higher of equity or balance
         if(currentEquity > currentBalance)
         {
            dailyStartBalance = currentEquity;
            Print("Daily reset at 23:55 - Using Equity: ", DoubleToString(dailyStartBalance, 2));
         }
         else
         {
            dailyStartBalance = currentBalance;
            Print("Daily reset at 23:55 - Using Balance: ", DoubleToString(dailyStartBalance, 2));
         }
         
         currentDay = TimeCurrent();
         dailyResetDone = true;
      }
   }
   else
   {
      // Reset flag when time is no longer 23:55
      dailyResetDone = false;
   }
}

//+------------------------------------------------------------------+
//| Check account limits and close positions if needed               |
//+------------------------------------------------------------------+
void CheckAccountLimits()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Calculate P&L from initial balance
   double totalPnL = currentBalance - InpInitialBalance;
   double dailyPnL = currentBalance - dailyStartBalance;
   
   // Calculate floating P&L (including open positions)
   double floatingPnL = currentEquity - currentBalance;
   double dailyPnLWithFloating = currentEquity - dailyStartBalance;
   
   // Calculate limits
   double dailyLossLimit = InpInitialBalance * InpDailyLossLimitPct / 100.0;
   double maxLossLimit = InpInitialBalance * InpMaxLossLimitPct / 100.0;
   double profitTarget = InpInitialBalance * iInpProfitTargetPct / 100.0;
   
   // Check daily loss limit (including floating)
   if(dailyPnLWithFloating <= -dailyLossLimit)
   {
      Print("Daily loss limit reached (floating): ", DoubleToString(dailyPnLWithFloating, 2), " / -", DoubleToString(dailyLossLimit, 2));
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      Alert("Daily loss limit reached! All positions closed.");
      ExpertRemove();
      return;
   }
   
   // Check maximum loss limit
   if(totalPnL <= -maxLossLimit)
   {
      Print("Maximum loss limit reached: ", DoubleToString(totalPnL, 2), " / -", DoubleToString(maxLossLimit, 2));
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      Alert("Maximum loss limit reached! All positions closed.");
      ExpertRemove();
      return;
   }
   
   // Check profit target
   if(dailyPnL >= profitTarget)
   {
      Print("Daily profit target reached: ", DoubleToString(dailyPnL, 2), " / ", DoubleToString(profitTarget, 2));
      CloseAllPositions(POSITION_TYPE_BUY);
      CloseAllPositions(POSITION_TYPE_SELL);
      Alert("Daily profit target reached! All positions closed.");
      ExpertRemove();
      return;
   }
}

//+------------------------------------------------------------------+
//| Display Info on Chart                                            |
//+------------------------------------------------------------------+
void DisplayInfo()
{
   // Calculate current P&L
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalPnL = currentBalance - InpInitialBalance;
   double dailyPnL = currentBalance - dailyStartBalance;
   
   // Calculate account limits
   double dailyLossLimit = InpInitialBalance * InpDailyLossLimitPct / 100.0;
   double maxLossLimit = InpInitialBalance * InpMaxLossLimitPct / 100.0;
   double profitTarget = InpInitialBalance * iInpProfitTargetPct / 100.0;
   
   // Calculate remaining limits
   double dailyLossRemaining = dailyLossLimit + dailyPnL;  // How much more loss allowed
   double maxLossRemaining = maxLossLimit + totalPnL;      // How much more loss allowed
   double profitRemaining = profitTarget - dailyPnL;       // How much more profit needed
   
   string info = "\n=== BOS EA Info ===\n";
   info += "Evaluation Mode: " + (InpEnableEvaluation ? "ON" : "OFF") + "\n";
   info += "Daily Start Bal: " + DoubleToString(dailyStartBalance, 2) + "\n";
   info += "Current Bal: " + DoubleToString(currentBalance, 2) + "\n";
   info += "Daily P&L: " + DoubleToString(dailyPnL, 2) + "\n";
   info += "Daily Loss Limit: " + DoubleToString(dailyLossRemaining, 2) + "\n";
   info += "Max Loss Limit: " + DoubleToString(maxLossRemaining, 2) + "\n";
   info += "Profit Target: " + DoubleToString(profitRemaining, 2) + "\n";
   info += "\n";
   info += "HTF Trend: " + EnumToString(htfTrend) + "\n";
   info += "Last HTF Swing: " + (lastHTFSwingWasHigh ? "HIGH" : "LOW") + "\n";
   info += "HTF Last High: " + DoubleToString(htfLastHigh.price, _Digits) + "\n";
   info += "HTF Last Low: " + DoubleToString(ltfLastLow.price, _Digits) + "\n";
   info += "LTF Last High: " + DoubleToString(ltfLastHigh.price, _Digits) + "\n";
   info += "LTF Last Low: " + DoubleToString(ltfLastLow.price, _Digits) + "\n";
   info += "BOS Active: " + (currentBOS.isActive ? "Yes" : "No") + "\n";
   if(currentBOS.isActive)
   {
      info += "BOS Level: " + DoubleToString(currentBOS.price, _Digits) + "\n";
      info += "BOS Type: " + (currentBOS.isBullish ? "Bullish" : "Bearish") + "\n";
   }
   info += "Waiting Pullback: " + (waitingForPullback ? "Yes" : "No") + "\n";
   info += "Open Positions: " + IntegerToString(GetOpenPositionsCount()) + "\n";
   
   Comment(info);
}
//+------------------------------------------------------------------+
