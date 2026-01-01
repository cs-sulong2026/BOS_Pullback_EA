//+------------------------------------------------------------------+
//|                                                      Defines.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 28.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/AccountInfo.mqh>


//#region Structures

//+------------------------------------------------------------------+
//| Structures                                                       |
//|
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Pivot Point Structure                                            |
//+------------------------------------------------------------------+
struct PivotPoint
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isValid;
};

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
struct BoxData
{
   string   name;
   double   top;
   double   bottom;
   datetime left;
   datetime right;
   datetime created;
   color    bgcolor;
   color    bordercolor;
   int      border_style;
   double   volume;
   bool     is_support;
   bool     is_broken;
   bool     is_reheld;
   bool     traded;
   bool     drawn;
   int      traded_count;
   int      hold_count;
   int      box_hold_limit;
   int      break_count;
   int      box_break_limit;
   int      buyOnHold_count;
   int      buyOnBreakout_count;
   int      sellOnHold_count;
   int      sellOnBreakout_count;
   int      buyOnHold_limit;
   int      buyOnBreakout_limit;
   int      sellOnHold_limit;
   int      sellOnBreakout_limit;
};

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
struct BOSLevel
{
   double   price;
   datetime time;
   bool     isBullish;
   bool     isActive;
   int      barIndex;
};

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
struct SnRLevel
{
   double   price;
   datetime time;
   bool     isSupport;
   bool     isActive;
   int      barIndex;
};

//+------------------------------------------------------------------+

//#endregion
//#region Enums

//+------------------------------------------------------------------+
//| Enums                                                            |
//|
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Trend Types                                                      |
//+------------------------------------------------------------------+
enum TREND_TYPE
{
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_SIDEWAYS,
   TREND_UNDECIDED
};

//+------------------------------------------------------------------+
//| Market Conditions                                                |
//+------------------------------------------------------------------+
enum MARKET_CONDITIONS
{
   CLEAR_AND_STRONG_TREND, // Clear & strong momentum trend
   CONSOLIDATE_AND_RANGE,  // Price sideways
   AHEAD_OF_BIG_NEWS,      // Before big news release
   NOT_VALIDATE            // Not analyzed yet
};

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
enum TRADING_STRATEGY
{
   SWING_TRADING,
   TREND_FOLLOWER,
   RANGE_TRADING,
   BREAKOUT_TRADING,
   SCALPING,
   UNDECIDED
};

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
enum TRADE_DIRECTION
{
   TRADE_BOTH,      // Trade both Buy and Sell
   TRADE_BUY_ONLY,  // Trade Buy only
   TRADE_SELL_ONLY  // Trade Sell only
};

//+------------------------------------------------------------------+
//| Determine trend based on pivot points                            |
//+------------------------------------------------------------------+
TREND_TYPE DetermineTrend(ENUM_TIMEFRAMES timeframe, PivotPoint &lastHigh, PivotPoint &prevHigh, PivotPoint &lastLow, PivotPoint &prevLow)
{
   // Need at least last high and last low to determine trend
   if(!lastHigh.isValid || !lastLow.isValid)
      return TREND_UNDECIDED;
   
   // Check if we have both previous pivots for better analysis
   bool hasFullData = prevHigh.isValid && prevLow.isValid;
   
   if(hasFullData)
   {
      double close = iClose(_Symbol, timeframe, 0);
      // Higher Highs and Higher Lows = Bullish Trend
      bool higherHigh = lastHigh.price > prevHigh.price;
      bool higherLow = lastLow.price > prevLow.price;
      
      // Lower Highs and Lower Lows = Bearish Trend
      bool lowerHigh = lastHigh.price < prevHigh.price;
      bool lowerLow = lastLow.price < prevLow.price;
      
      // Strong bullish trend
      if(higherHigh && higherLow)
         return TREND_BULLISH;
      
      // Strong bearish trend
      if(lowerHigh && lowerLow)
         return TREND_BEARISH;
      
      // Sideways/ranging market (lower high + higher low)
      if(lowerHigh && higherLow)
      {
         if(close > prevHigh.price)
            return TREND_BULLISH;
         else if(close < prevLow.price)
            return TREND_BEARISH;
         else
            return TREND_SIDEWAYS;
      }
      
      // Conflicting signals (higher high + lower low) - check current price position
      if(higherHigh && lowerLow)
      {
         if(close > lastHigh.price)
            return TREND_BULLISH;
         else if(close < lastLow.price)
            return TREND_BEARISH;
         else
            return TREND_SIDEWAYS;
      }

      // No clear pattern - undecided
      return TREND_UNDECIDED;
   }
   else
   {
      // Fallback: compare last high and last low positions
      // If last high is more recent and higher, likely bullish
      // If last low is more recent and lower, likely bearish
      
      if(lastHigh.time > lastLow.time)
      {
         // Last high is more recent
         if(lastHigh.price > lastLow.price * 1.01) // 1% threshold
            return TREND_BULLISH;
      }
      else
      {
         // Last low is more recent
         if(lastLow.price < lastHigh.price * 0.99) // 1% threshold
            return TREND_BEARISH;
      }
      
      return TREND_SIDEWAYS;
   }
}

//+------------------------------------------------------------------+
//| Determine market conditions based on trend and pivot analysis    |
//+------------------------------------------------------------------+
MARKET_CONDITIONS DetermineMarketCondition(TREND_TYPE trend, PivotPoint &lastHigh, PivotPoint &prevHigh, PivotPoint &lastLow, PivotPoint &prevLow)
{
   // If we don't have enough data or trend is undecided
   if(!lastHigh.isValid || !lastLow.isValid || trend == TREND_UNDECIDED)
      return NOT_VALIDATE;
   
   // Sideways trend indicates consolidation/range
   if(trend == TREND_SIDEWAYS)
      return CONSOLIDATE_AND_RANGE;
   
   // If we have full pivot data, check trend strength
   if(prevHigh.isValid && prevLow.isValid)
   {
      // Calculate the strength of the trend movement
      double highMove = 0;
      double lowMove = 0;
      
      if(trend == TREND_BULLISH)
      {
         // Check how much higher the highs and lows are
         highMove = (lastHigh.price - prevHigh.price) / prevHigh.price * 100; // % change
         lowMove = (lastLow.price - prevLow.price) / prevLow.price * 100;
         
         // Strong bullish trend: both highs and lows moving up significantly
         // AND both must be actually moving up (positive values)
         if(highMove > 0.5 && lowMove > 0.3 && highMove > 0 && lowMove > 0)
            return CLEAR_AND_STRONG_TREND;
         
         // Weak bullish trend but still trending - consolidating within uptrend
         return CONSOLIDATE_AND_RANGE;
      }
      else if(trend == TREND_BEARISH)
      {
         // Check how much lower the highs and lows are
         highMove = (prevHigh.price - lastHigh.price) / prevHigh.price * 100; // % change
         lowMove = (prevLow.price - lastLow.price) / prevLow.price * 100;
         
         // Strong bearish trend: both highs and lows moving down significantly
         // AND both must be actually moving down (positive values after reversal calc)
         if(highMove > 0.5 && lowMove > 0.3 && highMove > 0 && lowMove > 0)
            return CLEAR_AND_STRONG_TREND;
         
         // Weak bearish trend but still trending - consolidating within downtrend
         return CONSOLIDATE_AND_RANGE;
      }
   }
   
   // If we don't have previous pivots but have a clear trend direction,
   // assume it's consolidating until we get more data to confirm strength
   if(trend == TREND_BULLISH || trend == TREND_BEARISH)
      return CONSOLIDATE_AND_RANGE;
   
   return NOT_VALIDATE;
}

//+------------------------------------------------------------------+
//| Determine trading strategy based on trend and market conditions  |
//+------------------------------------------------------------------+
TRADING_STRATEGY DetermineTradingStrategy(TREND_TYPE trend, MARKET_CONDITIONS condition, TRADING_STRATEGY &secondaryStrategy)
{
   // Reset secondary strategy
   secondaryStrategy = UNDECIDED;
   
   // If scalping mode is enabled, always use scalping
   if(InpEnableScalping)
      return SCALPING;
   
   // If data is not validated or trend is undecided
   if(condition == NOT_VALIDATE || trend == TREND_UNDECIDED)
      return UNDECIDED;
   
   // AHEAD_OF_BIG_NEWS - not used but handle defensively
   if(condition == AHEAD_OF_BIG_NEWS)
      return UNDECIDED;
   
   // Clear and strong trend - use trend following
   if(condition == CLEAR_AND_STRONG_TREND)
   {
      if(trend == TREND_BULLISH || trend == TREND_BEARISH)
         return TREND_FOLLOWER;
      
      // If somehow we have strong trend but sideways market (shouldn't happen)
      // This is a logic inconsistency - default to undecided
      return UNDECIDED;
   }
   
   // Consolidation and ranging market
   if(condition == CONSOLIDATE_AND_RANGE)
   {
      if(trend == TREND_SIDEWAYS)
      {
         // True sideways market - range trade or wait for breakout
         secondaryStrategy = BREAKOUT_TRADING;
         return RANGE_TRADING;  // Primary: trade the range, Secondary: wait for breakout
      }
      else if(trend == TREND_BULLISH || trend == TREND_BEARISH)
      {
         // Weak trend still moving in a direction - swing trade the pullbacks
         return SWING_TRADING;
      }
   }
   
   // Shouldn't reach here, but handle defensively
   return UNDECIDED;
}


//#endregion
//#region Input

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Account Info ==="
input bool              InpEnableEvaluation = true;         // Enable Prop Firm Evaluation Mode
input double            InpInitialBalance = 10000.0;        // Initial account balance for calculations
input double            InpDailyLossLimitPct = 5.0;         // Daily loss limit percentage
input double            InpMaxLossLimitPct = 10.0;          // Maximum loss limit percentage
input double            InpProfitTargetPct = 10.0;          // Daily profit target percentage

input group "===== SnR Settings ====="
input int               InpLookbackPeriod=20;               // Lookback period for SnR detection (H4 bars)
input int               InpVolFilterLen=2;                  // Delta Volume Filter Length
input double            InpBoxWidth=1;                      // Adjust Box Width

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES   InpTrendTF = PERIOD_D1;             // High Timeframe for trend analysis
input ENUM_TIMEFRAMES   InpSwingTF = PERIOD_H12;            // High Timeframe for swing points
input ENUM_TIMEFRAMES   InpSnRTF = PERIOD_H4;               // Timeframe for S/R detection
input ENUM_TIMEFRAMES   InpLowTF = PERIOD_M15;              // Low Timeframe for BOS detection
input int               InpPivotLeftBars = 5;               // Pivot detection left bars
input int               InpPivotRightBars = 5;              // Pivot detection right bars

input group "=== Trading Strategy ==="
input TRADE_DIRECTION   InpTradeDirection = TRADE_BOTH;     // Allowed trade direction
input bool              InpEnableScalping = false;          // Enable Scalping Mode
input bool              InpEnableSupertrend = true;         // Enable trade by Swing trend
input int               InpBOSPullbackPoints = 50;          // Min pullback points to BOS level
input int               InpSnRPullbackPoints = 50;          // Min pullback points to SnR level
input int               InpBOSConfirmBars = 2;              // BOS confirmation bars

input group "═══════ Trading Settings ═══════"
input bool              InpTradeBreakouts = true;          // Trade Breakouts
input bool              InpTradeRetests   = true;          // Trade Retests/Holds
input bool              InpBuySignals     = true;          // Enable Buy Signals
input bool              InpSellSignals    = true;          // Enable Sell Signals

input group "=== Risk Management ==="
input bool              InpUsePercentage = false;           // Use percentage-based lot sizing
input double            InpRiskPercent = 1.0;               // Risk percentage per trade (when UsePercentage=true)
input double            InpLotSize = 0.01;                  // Fixed lot size (when UsePercentage=false)
input int               InpStopLoss = 0;                    // Stop Loss in pips (0=auto from swing)
input int               InpTakeProfit = 0;                  // Take Profit in pips (0=auto from swing)
input double            InpRiskRewardRatio = 2.0;           // Risk:Reward ratio (when SL/TP=0)
input int               InpMaxBuyOnBOS = 1;                 // Max simultaneous BUY trades on BOS
input int               InpMaxSellOnBOS = 1;                // Max simultaneous SELL trades on BOS
input int               InpMaxBuyOnSnR = 1;                 // Max simultaneous BUY trades on S&R (all)
input int               InpMaxSellOnSnR = 1;                // Max simultaneous SELL trades on S&R (all)
input int               InpMaxBuyOnHold = 1;                // Max simultaneous BUY trades on Hold signals
input int               InpMaxSellOnHold = 1;               // Max simultaneous SELL trades on Hold signals
input int               InpMaxBuyOnBreakout = 1;            // Max simultaneous BUY trades on Breakout signals
input int               InpMaxSellOnBreakout = 1;           // Max simultaneous SELL trades on Breakout signals
input bool              InpBlockOppositeEntry = true;       // Block entry if opposite positions exist
input bool              InpCloseOnNewSwing = true;          // Close positions when new HTF swing detected
input bool              InpUseTrailingStop = false;         // Enable trailing stop
input int               InpTrailingStop = 50;               // Trailing stop distance in pips
input int               InpTrailingStep = 10;               // Minimum price movement to trail (pips)

input group "═══════ Display Settings ═══════"
// input bool              InpShowPreviousBoxes = true;        // Show Previous Boxes
input bool              InpShowOnlyClosest = false;          // Show Only Closest S/R Level (Hold/Breakout)
input int               InpMaxVisibleBoxes = 5;              // Maximum Visible Boxes (0=All)

input group "═══════ Order Management ═══════"
input int               InpBOSMagicNumber = 435067;         // BOS Magic Number
input int               InpSnRMagicNumber = 123456;         // SnR Magic Number
input string            InpTradeComment   = "PG_EA";        // Trade Comment
input int               InpSlippage       = 10;             // Slippage (points)

input group "═══════ Logging Settings ═══════"
input bool              InpEnableLogging = true;            // Enable Logging to File
input bool              InpSilentLogging = false;           // Silent Logging (no console output)

//#endregion
//#region Global Variables

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

CTrade            trade;
CSymbolInfo       symbolInfo;
CAccountInfo      account;

//--- Trend Analysis
TREND_TYPE        W_Trend = TREND_SIDEWAYS;
TREND_TYPE        D_Trend = TREND_SIDEWAYS;
TREND_TYPE        swH_Trend = TREND_SIDEWAYS;
TREND_TYPE        snrH_Trend = TREND_SIDEWAYS;

//--- Market Conditions
MARKET_CONDITIONS W_MarketCondition = NOT_VALIDATE;
MARKET_CONDITIONS D_MarketCondition = NOT_VALIDATE;
MARKET_CONDITIONS swH_MarketCondition = NOT_VALIDATE;
MARKET_CONDITIONS snrH_MarketCondition = NOT_VALIDATE;

//--- Trading Strategies
TRADING_STRATEGY  W_Strategy = UNDECIDED;
TRADING_STRATEGY  D_Strategy = UNDECIDED;
TRADING_STRATEGY  swH_Strategy = UNDECIDED;
TRADING_STRATEGY  snrH_Strategy = UNDECIDED;

//--- Secondary Trading Strategies (for sideways markets)
TRADING_STRATEGY  W_SecondaryStrategy = UNDECIDED;
TRADING_STRATEGY  D_SecondaryStrategy = UNDECIDED;
TRADING_STRATEGY  swH_SecondaryStrategy = UNDECIDED;
TRADING_STRATEGY  snrH_SecondaryStrategy = UNDECIDED;

//--- Weekly trend pivot points
PivotPoint        W_LastHigh;
PivotPoint        W_PrevHigh;
PivotPoint        W_LastLow;
PivotPoint        W_PrevLow;
//--- Daily trend pivot points
PivotPoint        D_LastHigh;
PivotPoint        D_PrevHigh;
PivotPoint        D_LastLow;
PivotPoint        D_PrevLow;
//--- Hourly swing pivot points
PivotPoint        swH_LastHigh;
PivotPoint        swH_PrevHigh;
PivotPoint        swH_LastLow;
PivotPoint        swH_PrevLow;
//--- Hourly S & R Points
PivotPoint        snrH_LastHigh;
PivotPoint        snrH_PrevHigh;
PivotPoint        snrH_LastLow;
PivotPoint        snrH_PrevLow;
//--- Current low BOS Pivot Points
PivotPoint        L_LastHigh;
PivotPoint        L_PrevHigh;
PivotPoint        L_LastLow;
PivotPoint        L_PrevLow;
//--- Current Timeframe Pivot Points
PivotPoint        LastHigh;
PivotPoint        PrevHigh;
PivotPoint        LastLow;
PivotPoint        PrevLow;
//--- For Support/Resistance Boxes
BoxData           g_Boxes[];
int               g_BoxCount = 0;
const int         MAX_BOXES = 50;

double            g_SupportLevel = 0;
double            g_SupportLevel1 = 0;
double            g_ResistanceLevel = 0;
double            g_ResistanceLevel1 = 0;

// Support/Resistance status
bool              g_ResIsSupport = false;
bool              g_SupIsResistance = false;
bool              IsBreakout = false;
bool              IsHold = false;
bool              TrendAligned = false;
int               g_ActiveBoxIndex = -1;  // Track which box triggered the signal
int               breakLimit = 2;
int               holdLimit = 2;

//--- Bar time tracking for each timeframe
datetime          g_LastBarTime_W1 = 0;
datetime          g_LastBarTime_D1 = 0;
datetime          g_LastBarTime_swH = 0;   // For InpSwingTF
datetime          g_LastBarTime_snrH = 0;   // For InpSnRTF
datetime          g_LastBarTime_L = 0;     // For InpLowTF
datetime          g_LastBarTime = 0;     // For current timeframe

double            g_PointValue = 0;
int               g_Digits = 0;

// BOS Detection
BOSLevel          BOS;
bool              waitingForPullback = false;
bool              lastSwingWasHigh = false;

// Account tracking
double            dailyStartBalance = 0.0;
datetime          currentDay = 0;
bool              dailyResetDone = false;

static int        log_counter = 0;
int               log_file = 0;
int               acc_login = 0;
string            expert_folder = "";
string            work_folder = "";
string            log_fileName = "";
bool              common_folder = false;
bool              silent_log = false;

//#endregion
//#region String Methods

//+------------------------------------------------------------------+
//| String methods                                                   |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
string TrendToString(TREND_TYPE trend)
{
   switch(trend)
   {
      case TREND_BULLISH: return "BULLISH";
      case TREND_BEARISH: return "BEARISH";
      case TREND_SIDEWAYS: return "SIDEWAYS";
      case TREND_UNDECIDED: return "NOT ENOUGH DATA";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
string TradingStrategyToString(TRADING_STRATEGY strategy)
{
   switch(strategy)
   {
      case SWING_TRADING: return "SWING TRADING";
      case TREND_FOLLOWER: return "TREND FOLLOWING";
      case RANGE_TRADING: return "RANGE TRADING";
      case BREAKOUT_TRADING: return "BREAKOUT";
      case SCALPING: return "SCALPING";
      case UNDECIDED: return "UNDECIDED";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
string MarketConditionToString(MARKET_CONDITIONS condition)
{
   switch(condition)
   {
      case CLEAR_AND_STRONG_TREND: return "CLEAR & STRONG";
      case CONSOLIDATE_AND_RANGE: return "CONSOLIDATING";
      case AHEAD_OF_BIG_NEWS: return "AHEAD OF NEWS";
      case NOT_VALIDATE: return "NOT VALIDATED";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
string TFtoString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M10: return "M10";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_H8: return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Method CurrentAccountInfo                                        |
//+------------------------------------------------------------------+
string CurrentAccountInfo(string server)
{
   int eq_pos = StringFind(server,"-");
   string server_name = (eq_pos != -1) ? StringSubstr(server, 0, eq_pos) : server;
   Print("Account Server: ",server_name);
   return(server_name);
}

//+------------------------------------------------------------------+
//| Method RemoveDots                                                |
//+------------------------------------------------------------------+
string RemoveDots(string str)
{
   StringReplace(str,".","");
   return(str);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
datetime DateToString()
{
   string dateStr = TimeToString(TimeLocal(), TIME_DATE);
   return StringToTime(dateStr);
}

//#endregion
//#region Double Methods

//+------------------------------------------------------------------+
//| Double methods                                                   |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Delta Volume (Up and Down Volume)                     |
//+------------------------------------------------------------------+
double UpAndDownVolume(int shift, ENUM_TIMEFRAMES timeframe)
{
   double posVol = 0.0;
   double negVol = 0.0;
   
   double o = iOpen(_Symbol, timeframe, shift);
   double c = iClose(_Symbol, timeframe, shift);
   long vol = iVolume(_Symbol, timeframe, shift);
   
   if(c > o)
      posVol += (double)vol;
   else if(c < o)
      negVol -= (double)vol;
   
   return posVol + negVol;
}

//+------------------------------------------------------------------+
//| Find Pivot High                                                 |
//+------------------------------------------------------------------+
double PivotHigh(int leftBars, int rightBars, int shift, ENUM_TIMEFRAMES timeframe)
{
   if(shift < rightBars)
      return 0;
      
   int centerBar = shift;
   double centerHigh = iHigh(_Symbol, timeframe, centerBar);
   
   // Check left side (older bars = higher shift numbers)
   for(int i = 1; i <= leftBars; i++)
   {
      if(iHigh(_Symbol, timeframe, centerBar + i) >= centerHigh)
         return 0;
   }
   
   // Check right side (newer bars = lower shift numbers)
   for(int i = 1; i <= rightBars; i++)
   {
      if(iHigh(_Symbol, timeframe, centerBar - i) >= centerHigh)
         return 0;
   }
   
   return centerHigh;
}

//+------------------------------------------------------------------+
//| Find Pivot Low                                                  |
//+------------------------------------------------------------------+
double PivotLow(int leftBars, int rightBars, int shift, ENUM_TIMEFRAMES timeframe)
{
   if(shift < rightBars)
      return 0;
      
   int centerBar = shift;
   double centerLow = iLow(_Symbol, timeframe, centerBar);
   
   // Check left side (older bars = higher shift numbers)
   for(int i = 1; i <= leftBars; i++)
   {
      if(iLow(_Symbol, timeframe, centerBar + i) <= centerLow)
         return 0;
   }
   
   // Check right side (newer bars = lower shift numbers)
   for(int i = 1; i <= rightBars; i++)
   {
      if(iLow(_Symbol, timeframe, centerBar - i) <= centerLow)
         return 0;
   }
   
   return centerLow;
}

//+------------------------------------------------------------------+
//| Calculate ATR                                                   |
//+------------------------------------------------------------------+
double CalculateATR(int period, int shift, ENUM_TIMEFRAMES timeframe)
{
   double sum = 0;
   int count = MathMin(period, Bars(_Symbol, timeframe) - shift - 1);
   
   for(int i = shift; i < shift + count; i++)
   {
      double high = iHigh(_Symbol, timeframe, i);
      double low = iLow(_Symbol, timeframe, i);
      double prevClose = iClose(_Symbol, timeframe, i + 1);
      
      double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
      sum += tr;
   }
   return sum / count;
}

//+------------------------------------------------------------------+
//| Get Highest Volume                                              |
//+------------------------------------------------------------------+
double GetHighestVolume(int period, int shift, ENUM_TIMEFRAMES timeframe)
{
   double maxVol = -DBL_MAX;
   for(int i = shift; i < shift + period; i++)
   {
      double vol = UpAndDownVolume(i, timeframe);
      if(vol > maxVol)
         maxVol = vol;
   }
   return maxVol / 2.5;
}

//+------------------------------------------------------------------+
//| Get Lowest Volume                                               |
//+------------------------------------------------------------------+
double GetLowestVolume(int period, int shift, ENUM_TIMEFRAMES timeframe)
{
   double minVol = DBL_MAX;
   for(int i = shift; i < shift + period; i++)
   {
      double vol = UpAndDownVolume(i, timeframe);
      if(vol < minVol)
         minVol = vol;
   }
   return minVol / 2.5;
}

//#endregion
//#region Int Methods

//+------------------------------------------------------------------+
//| Int methods                                                      |
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Bar Lookback Period Conversion                                   |
//+------------------------------------------------------------------+
int LookbackPeriod(ENUM_TIMEFRAMES timeframe)
{
   int lookback = 0;
   switch(timeframe)
   {
      case PERIOD_H12 : return lookback = 12;
      case PERIOD_D1  : return lookback = 6;
      case PERIOD_W1  : return lookback = 4;
      default: lookback = InpLookbackPeriod;
   }
   return lookback;
}

//#endregion

//+------------------------------------------------------------------+
//| Method CreateFolder                                              |
//+------------------------------------------------------------------+
bool CreateFolder(string folder_name, bool common_flag)
{
   int flag = common_flag ? FILE_COMMON : 0;
   string working_folder;
   if (common_flag)
      working_folder = TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\MQL5\\Files";
   else
      working_folder = TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files";
   //---
   // PrintFormat("folder_path=%s",folder_name);
   //---
   if (FolderCreate(folder_name, flag))
   {
      // PrintFormat("Created the folder %s",working_folder+"\\"+folder_name);
      ResetLastError();
      return(true);
   }
   else
      PrintFormat("Failed to create the folder %s. Error code %d",working_folder+folder_name,GetLastError());
   //--- 
   return(false);
}

void Logging(const string message)
{
   if(!InpEnableLogging)
      return;
   
   log_counter++;
   if (StringLen(log_fileName) > 0)
   {
      if (!FileIsExist(work_folder+log_fileName)) {
         if (CreateFolder(work_folder, common_folder)) {
            Print("New log folder created: ", work_folder);
            ResetLastError();
         }
         else {
            Print("Failed to create log folder: ", work_folder, ". Error code ", GetLastError());
            return;
         }
      }
      //---
      if (log_file == INVALID_HANDLE)
         log_file = FileOpen(work_folder + log_fileName, FILE_CSV|FILE_READ|FILE_WRITE, ' ');
      //---
      if (log_file == INVALID_HANDLE)
         Alert("Cannot open file for logging: ", work_folder + log_fileName);
      else if (FileSeek(log_file, 0, SEEK_END))
      {
         FileWrite(log_file, TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS), " #", log_counter, " ", message);
         FileFlush(log_file);
         FileClose(log_file);
         log_file = INVALID_HANDLE;
      }
      else Alert("Unexpected error accessing log file: ", work_folder + log_fileName);
   }      
   if (!silent_log)
      Print(message);
}

//+------------------------------------------------------------------+
