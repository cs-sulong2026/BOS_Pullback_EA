//+------------------------------------------------------------------+
//|                                              BOS_Pullback_EA.mq5 |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 20.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"
#property version   "1.00"
#property description "Trades Break of Structure with pullback entry + Trend detection"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
//#region Input Parameters
input group "=== Strategy Settings ==="
input int      InpSwingPeriod = 10;              // Swing detection period (bars)
input double   InpPullbackFibo = 0.5;            // Pullback Fibonacci level (0.382-0.618)
input int      InpConfirmationBars = 2;          // Confirmation bars after pullback
input bool     InpEnableReversalStrategy = true; // Enable reversal strategy
input int      InpConfirmationCandles = 3;      // Confirmation candles after reversal
input int      InpConfirmationPoints = 50;    // Confirmation points after reversal
input bool     InpUseFiboForReversal = true;    // Use Fibonacci level for reversal confirmation
// input double   InpFiboLevel = 0.5;               // Fibonacci level for reversal confirmation (0.382-0.618)
input bool     InpEnableScalpingMode = true;        // Enable scalping mode
// input int      InpLLCandleRange = 10;            // Max candles between LL signs
// input int      InpLLPointRange = 200;            // Max points between LL signs
// input int      InpHHCandleRange = 10;            // Max candles between HH signs
// input int      InpHHPointRange = 200;            // Max points between HH signs
input double   InpReversalLotSize = 0.01;        // Fixed lot size for reversal trades
input double   InpScalpingLotSize = 0.01;        // Fixed lot size for scalping trades

input group "=== Risk Management ==="
input double   InpRiskPercent = 1.0;             // Risk per trade (% of balance)
input double   InpRiskRewardRatio = 2.0;         // Risk:Reward ratio
input int      InpStopLossPoints = 0;            // Stop Loss in points (0=auto from swing)
input int      InpTakeProfitPoints = 0;          // Take Profit in points (0=auto from R:R)
input int      InpMaxSimultaneousTrades = 1;     // Max simultaneous trades

input group "=== Trading Hours ==="
input bool     InpUseTimeFilter = false;         // Enable time filter
input int      InpStartHour = 8;                 // Start hour (server time)
input int      InpEndHour = 18;                  // End hour (server time)

input group "=== Advanced ==="
input int      InpMagicNumber = 234567;          // Magic number
input string   InpTradeComment = "BOS_Pullback"; // Trade comment
input bool     InpShowLevels = true;             // Show S/R levels on chart
//#endregion
//#region Structures and Enums
enum ENUM_TREND_DIRECTION
{
   TREND_UP,
   TREND_DOWN,
   TREND_SIDEWAYS,
   TREND_UNDEFINED
};
ENUM_TREND_DIRECTION currentTrend = TREND_UNDEFINED;

enum ENUM_TREND_INDICATOR
{
   HIGHER_HIGH,
   HIGHER_LOW,
   LOWER_HIGH,
   LOWER_LOW,
   NONE
};
ENUM_TREND_INDICATOR trendPattern = NONE;
//---

struct SwingPoint
{
   int      barIndex;
   bool     is_high; // true=high, false=low (for sideways detection)
   bool     valid;
   double   price;
   datetime time;
};

//--- Structure to store trend segment
struct TrendSegment
  {
   datetime             startTime;
   datetime             endTime;
   double               startPrice;
   double               endPrice;
   ENUM_TREND_DIRECTION trendType;
   int                  bars;
   double               priceChange;
   double               percentChange;
  };

//---
struct TrendPattern
{
   int         LL_count;
   int         HH_count;
   SwingPoint  LL_sign[10];
   SwingPoint  HH_sign[10];
};
//---
struct BOS
{
   bool     is_bullish;
   bool     is_bearish;
   double   level;
   datetime time;
};
//#endregion
//#region Global State Variables
BOS               bos;
CTrade            trade;
datetime          lastCandleTime;
CSymbolInfo       c_symbol;
//--- Current Timeframe Swing Points
SwingPoint        lastSwingHigh;
SwingPoint        lastSwingLow;
SwingPoint        prevSwingHigh;
SwingPoint        prevSwingLow;
//--- Highest Timeframe Swing Points
SwingPoint        lastHighTF_SwingHigh;
SwingPoint        lastHighTF_SwingLow;
SwingPoint        prevHighTF_SwingHigh;
SwingPoint        prevHighTF_SwingLow;
//--- Trend and Structure Variables
SwingPoint        swingPoints[];
TrendSegment      trendSegments[];
TrendPattern      trend;
ENUM_TIMEFRAMES   chartTF=PERIOD_CURRENT;
ENUM_TIMEFRAMES   timeFrameToAnalize=PERIOD_CURRENT;
bool              isBreakout=false;
bool              swingLevelChecked=false;
bool              waitingPullback=false;
ulong             PO_Ticket=0;
double            pullbackLevel=0.0;
double            resistanceLevel=0.0;
double            supportLevel=0.0;
static int        count_LL=0;
static int        count_HH=0;
//#endregion
//#region MQL5 Functions
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   trade.LogLevel(LOG_LEVEL_ERRORS);

//--- Initialize other variables
   lastCandleTime=0;
   currentTrend = TREND_UNDEFINED;
   trendPattern = NONE;
   chartTF=ChartPeriod();

//--- Initialize swing points
   lastSwingHigh.price=0.0;
   lastSwingHigh.time=0;
   lastSwingLow.price=0.0;
   lastSwingLow.time=0;
   prevSwingHigh.price=0.0;
   prevSwingHigh.time=0;
   prevSwingLow.price=0.0;
   prevSwingLow.time=0;

   lastHighTF_SwingHigh.price=0.0;
   lastHighTF_SwingHigh.time=0;
   lastHighTF_SwingLow.price=0.0;
   lastHighTF_SwingLow.time=0;
   prevHighTF_SwingHigh.price=0.0;
   prevHighTF_SwingHigh.time=0;
   prevHighTF_SwingLow.price=0.0;
   prevHighTF_SwingLow.time=0;

//--- Initialize trend structure
   trend.LL_count=0;
   trend.HH_count=0;
   //--- Initialize LL and HH check arrays
   for(int i=0;i<10;i++)
     {
      trend.LL_sign[i].price=0.0;
      trend.LL_sign[i].time=0;
      trend.HH_sign[i].price=0.0;
      trend.HH_sign[i].time=0;
     }

//--- Initialize BOS structure
   bos.is_bullish=false;
   bos.is_bearish=false;
   bos.level=0.0;
   bos.time=0;

//--- Display initialization message
   Print("BOS Pullback EA initialized on ",Symbol()," with Magic Number: ",InpMagicNumber);
   Print("Swing Period: ", InpSwingPeriod, " | Pullback Fibo: ", InpPullbackFibo);

//--- Analize Market and Trend Segments at initialization
   // if(!MarketAnalyze())
   // {
   //    Print("Market analysis failed during initialization.");
   //    return(INIT_FAILED);
   // }
   // ResultToChart();
   if(chartTF==PERIOD_H1)
      timeFrameToAnalize=PERIOD_H4;
   else if(chartTF==PERIOD_M30)
      timeFrameToAnalize=PERIOD_H4;
   else if(chartTF==PERIOD_M15)
      timeFrameToAnalize=PERIOD_H1;
   
   // MarketAnalyze();

//--- Successful initialization
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- Cleanup chart objects if any

   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//--- Check if EA already processed within 12 hours
   datetime currentCandleTime=iTime(_Symbol,PERIOD_CURRENT,0);
   if(currentCandleTime==lastCandleTime)
      return; // Already processed this candle

   lastCandleTime=currentCandleTime;

   //--- Main EA logic goes here

   SwingDetection();   

   //Check for Break of Structure
   CheckBOS();
   
   // // Monitor pullback and enter trades
   if(waitingPullback) {
      TrendPointChange(0,"BOS_Break",currentCandleTime,bos.level);
      CheckPullback();
   }

//--- Execute trades based on detected patterns
   OnTradeProcessing();
   
   //---
   InfoToChart();
}
//#endregion

//#region Market Analysis

//+------------------------------------------------------------------+
//| Method to check previous swing levels                            |
//+------------------------------------------------------------------+
bool MarketAnalyze()
{
   int lookback=200;
   int left_bars=1;
   int right_bars=1;
   ENUM_TIMEFRAMES tf=timeFrameToAnalize;
   string tf_name=EEnumToString(tf);
   //---
   Print("Analyzing ", tf_name, " timeframe (", EnumToString(tf), ") - ", lookback, " bars...");
   //--- Detect last swing points before EA start
   for(int i=right_bars;i<lookback+right_bars;i++)
   {
      //--- Check for swing high
      if(IsSwingHigh(i,tf,left_bars,right_bars))
      {
         if(lastHighTF_SwingHigh.price==0.0)
         {
            lastHighTF_SwingHigh.price=iHigh(_Symbol,tf,i);
            lastHighTF_SwingHigh.time=iTime(_Symbol,tf,i);
         }
         else if(prevHighTF_SwingHigh.price==0.0)
         {
            prevHighTF_SwingHigh.price=iHigh(_Symbol,tf,i);
            prevHighTF_SwingHigh.time=iTime(_Symbol,tf,i);
         }
      }
      //--- Check for swing low
      if(IsSwingLow(i,tf,right_bars,right_bars))
      {
         if(lastHighTF_SwingLow.price==0.0)
         {
            lastHighTF_SwingLow.price=iLow(_Symbol,tf,i);
            lastHighTF_SwingLow.time=iTime(_Symbol,tf,i);
         }
         else if(prevHighTF_SwingLow.price==0.0)
         {
            prevHighTF_SwingLow.price=iLow(_Symbol,tf,i);
            prevHighTF_SwingLow.time=iTime(_Symbol,tf,i);
         }
      }

      //--- Check if both swings found (both highs and lows)
      if(lastHighTF_SwingHigh.price!=0.0 && prevHighTF_SwingHigh.price!=0.0 &&
         lastHighTF_SwingLow.price!=0.0 && prevHighTF_SwingLow.price!=0.0)
      {
         break; // Exit loop when all 4 swing points are found
      }
   }
   Print("Last High TF Swing High: ",lastHighTF_SwingHigh.price," at ",TimeToString(lastHighTF_SwingHigh.time));
   Print("Prev High TF Swing High: ",prevHighTF_SwingHigh.price," at ",TimeToString(prevHighTF_SwingHigh.time));
   Print("Last High TF Swing Low: ",lastHighTF_SwingLow.price," at ",TimeToString(lastHighTF_SwingLow.time));
   Print("Prev High TF Swing Low: ",prevHighTF_SwingLow.price," at ",TimeToString(prevHighTF_SwingLow.time));
   //--- Mark Swing High
   MarkTrendPattern("HH_"+tf_name,lastHighTF_SwingHigh.price,lastHighTF_SwingHigh.time,clrTeal);
   MarkTrendPattern("LH_"+tf_name,prevHighTF_SwingHigh.price,prevHighTF_SwingHigh.time,clrBrown);
   //--- Mark Swing Low
   MarkTrendPattern("HL_"+tf_name,lastHighTF_SwingLow.price,lastHighTF_SwingLow.time,clrTeal);
   MarkTrendPattern("LL_"+tf_name,prevHighTF_SwingLow.price,prevHighTF_SwingLow.time,clrBrown);
   //--- Determine trend direction
   if(lastHighTF_SwingHigh.price>prevHighTF_SwingHigh.price &&
      lastHighTF_SwingLow.price>prevHighTF_SwingLow.price)
   {
      Print("Detected Higher High and Higher Low on ",tf_name," timeframe.");
      currentTrend=TREND_UP;
   }
   else if(lastHighTF_SwingHigh.price<prevHighTF_SwingHigh.price &&
           lastHighTF_SwingLow.price<prevHighTF_SwingLow.price)
   {
      Print("Detected Lower High and Lower Low on ",tf_name," timeframe.");
      currentTrend=TREND_DOWN;
   }
   else
   {
      Print("No clear trend detected on ",tf_name," timeframe.");
      currentTrend=TREND_SIDEWAYS;
   }
   // if(!SwingDetection(chartTF))
   //    return(false);
   // //---
   // if(!AnalyzeTrendSegments())
   //    return(false);
   
   // swingLevelChecked=true;
   return(true); // Placeholder
}
//+------------------------------------------------------------------+
//| Method to mark swing levels on chart                             |
//+------------------------------------------------------------------+
bool SwingDetection(ENUM_TIMEFRAMES timeframe)
{
   int barToAnalyze=100;
   int swingPeriod=10;
   //---
   if(timeframe==PERIOD_H1)
      timeFrameToAnalize=PERIOD_H4;
   else if(timeframe==PERIOD_M30)
      timeFrameToAnalize=PERIOD_H1;
   else if(timeframe==PERIOD_M15)
      timeFrameToAnalize=PERIOD_M30;
   //---
   ArrayResize(swingPoints, 0);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, timeFrameToAnalize, 0, barToAnalyze, rates);
   if(copied < barToAnalyze)
   {
      Print("Error copying rates: ", GetLastError());
      return false;
   }
   
//--- Detect swing highs and lows
   for(int i = swingPeriod; i < copied - swingPeriod; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      //--- Check if it's a swing high
      for(int j = 1; j <= swingPeriod; j++)
      {
         if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      //--- Check if it's a swing low
      for(int j = 1; j <= swingPeriod; j++)
      {
         if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      //--- Add swing point if found
      if(isSwingHigh)
      {
         int size = ArraySize(swingPoints);
         ArrayResize(swingPoints, size + 1);
         swingPoints[size].time = rates[i].time;
         swingPoints[size].price = rates[i].high;
         swingPoints[size].is_high = true;
         swingPoints[size].barIndex = i;
      }
      else if(isSwingLow)
      {
         int size = ArraySize(swingPoints);
         ArrayResize(swingPoints, size + 1);
         swingPoints[size].time = rates[i].time;
         swingPoints[size].price = rates[i].low;
         swingPoints[size].is_high = false;
         swingPoints[size].barIndex = i;
      }
      //---
      // if(ArraySize(swingPoints)==4)
      //    break;
   }
   //---
   Print("Detected ", ArraySize(swingPoints), " swing points");
   return ArraySize(swingPoints) > 0;
}
//+------------------------------------------------------------------+
//| Analyze trend segments between swing points                      |
//+------------------------------------------------------------------+
bool AnalyzeTrendSegments()
{
   ArrayResize(trendSegments, 0);
   
   if(ArraySize(swingPoints) < 2)
      return false;
   
//--- Analyze each segment between consecutive swing points
   for(int i = 0; i < ArraySize(swingPoints) - 1; i++)
   {
      int size = ArraySize(trendSegments);
      ArrayResize(trendSegments, size + 1);
      
      trendSegments[size].startTime = swingPoints[i].time;
      trendSegments[size].endTime = swingPoints[i+1].time;
      trendSegments[size].startPrice = swingPoints[i].price;
      trendSegments[size].endPrice = swingPoints[i+1].price;
      
      //--- Calculate price change
      trendSegments[size].priceChange = swingPoints[i+1].price - swingPoints[i].price;
      trendSegments[size].percentChange = (trendSegments[size].priceChange / swingPoints[i].price) * 100;
      
      //--- Calculate bars in segment
      trendSegments[size].bars = swingPoints[i].barIndex - swingPoints[i+1].barIndex;
      
      //--- Determine trend type
      if(swingPoints[i].is_high && !swingPoints[i+1].is_high)
      {
         //--- High to Low = Downtrend
         trendSegments[size].trendType = TREND_DOWN;
      }
      else if(!swingPoints[i].is_high && swingPoints[i+1].is_high)
      {
         //--- Low to High = Uptrend
         trendSegments[size].trendType = TREND_UP;
      }
      else
      {
         //--- High to High or Low to Low = Sideways/Continuation
         double priceMove = MathAbs(trendSegments[size].priceChange);
         double atr = GetATR(20, timeFrameToAnalize);
         
         if(priceMove < atr * 0.5)
            trendSegments[size].trendType = TREND_SIDEWAYS;
         else if(trendSegments[size].priceChange > 0)
            trendSegments[size].trendType = TREND_UP;
         else
            trendSegments[size].trendType = TREND_DOWN;
      }
   }
   //---
   currentTrend=trendSegments[ArraySize(trendSegments)-1].trendType;
   //---
   Print("Analyzed ", ArraySize(trendSegments), " trend segments");
   return true; // Placeholder
}
//+------------------------------------------------------------------+
//| Get Average True Range for volatility context                    |
//+------------------------------------------------------------------+
double GetATR(int period, ENUM_TIMEFRAMES timeFrameToAnalyze)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   int handle = iATR(_Symbol, timeFrameToAnalyze, period);
   if(handle == INVALID_HANDLE)
      return 0;
   
   if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
   {
      IndicatorRelease(handle);
      return 0;
   }
   
   IndicatorRelease(handle);
   return atr[0];
}
//endregion
//#region Swing and Trend Detection
//+------------------------------------------------------------------+
//| Method to detect swing points                                    |
//+------------------------------------------------------------------+
void SwingDetection()
{
   //--- Detect Swing High in higher timeframe
   int highTF_highestCandle = iHighest(Symbol(), timeFrameToAnalize, MODE_HIGH, InpSwingPeriod*2+1, InpSwingPeriod/2);
   if(highTF_highestCandle==InpSwingPeriod)
   {
      double swingHigh = iHigh(Symbol(), timeFrameToAnalize, highTF_highestCandle);
      datetime swingTime = iTime(Symbol(), timeFrameToAnalize, highTF_highestCandle);
      //---
      if(swingHigh != lastHighTF_SwingHigh.price || swingTime != lastHighTF_SwingHigh.time) {
         //--- Save previous swing high
         prevHighTF_SwingHigh = lastHighTF_SwingHigh;

         //--- Update last swing high
         lastHighTF_SwingHigh.barIndex = highTF_highestCandle;
         lastHighTF_SwingHigh.is_high = true;
         lastHighTF_SwingHigh.price = swingHigh;
         lastHighTF_SwingHigh.time = swingTime;
         //--- Draw line on chart if enabled
         if(InpShowLevels)
            MarkSwingLevel("BOS_HighTF_SwingHigh", swingHigh, clrTeal, STYLE_DOT, 2);
         //---
      }
   }

   //--- Detect Swing Low in higher timeframe
   int highTF_lowestCandle = iLowest(Symbol(), timeFrameToAnalize, MODE_LOW, InpSwingPeriod*2+1, InpSwingPeriod/2);
   if(highTF_lowestCandle==InpSwingPeriod)
   {
      double swingLow = iLow(Symbol(), timeFrameToAnalize, highTF_lowestCandle);
      datetime swingTime = iTime(Symbol(), timeFrameToAnalize, highTF_lowestCandle);
      //---
      if(swingLow != lastHighTF_SwingLow.price || swingTime != lastHighTF_SwingLow.time) {
         //--- Save previous swing low
         prevHighTF_SwingLow = lastHighTF_SwingLow;
         
         //--- Update last swing low
         lastHighTF_SwingLow.barIndex = highTF_lowestCandle;
         lastHighTF_SwingLow.is_high = false;
         lastHighTF_SwingLow.price = swingLow;
         lastHighTF_SwingLow.time = swingTime;
         //--- Draw line on chart if enabled
         if(InpShowLevels)
            MarkSwingLevel("BOS_HighTF_SwingLow", swingLow, clrBrown, STYLE_DOT, 2);
         //---
      }
   }

   //--- Detect Swing points in current timeframe
   if(lastHighTF_SwingHigh.price>0 && lastHighTF_SwingLow.price>0)
   {
      //-- - Detect Swing High in current timeframe
      int highestCandle = iHighest(Symbol(), chartTF, MODE_HIGH, InpSwingPeriod*2+1, InpSwingPeriod);
      if(highestCandle==InpSwingPeriod)
      {
         double swingHigh = iHigh(Symbol(), chartTF, highestCandle);
         datetime swingTime = iTime(Symbol(), chartTF, highestCandle);
         //---
         if(swingHigh != lastSwingHigh.price || swingTime != lastSwingHigh.time) {
            //--- Save previous swing high
            prevSwingHigh = lastSwingHigh;

            //--- Update last swing high
            lastSwingHigh.barIndex = highestCandle;
            lastSwingHigh.is_high = true;
            lastSwingHigh.price = swingHigh;
            lastSwingHigh.time = swingTime;

            //--- Draw line on chart if enabled
            if(InpShowLevels)
               MarkSwingLevel("BOS_SwingHigh", swingHigh, clrTeal, STYLE_DOT);
            //---
            Print("New Swing High detected at ", swingHigh);
         }
         //---
         TrendValidation();
      }      
      //--- Detect Swing Low in current timeframe
      int lowestCandle = iLowest(Symbol(), chartTF, MODE_LOW, InpSwingPeriod*2+1, InpSwingPeriod);
      if(lowestCandle==InpSwingPeriod)
      {
         double swingLow = iLow(Symbol(), chartTF, lowestCandle);
         datetime swingTime = iTime(Symbol(), chartTF, lowestCandle);
         //---
         if(swingLow != lastSwingLow.price || swingTime != lastSwingLow.time) {
            //--- Save previous swing low
            prevSwingLow = lastSwingLow;
            
            //--- Update last swing low
            lastSwingLow.barIndex = lowestCandle;
            lastSwingLow.is_high = false;
            lastSwingLow.price = swingLow;
            lastSwingLow.time = swingTime;
            //--- Draw line on chart if enabled
            if(InpShowLevels)
               MarkSwingLevel("BOS_SwingLow", swingLow, clrBrown, STYLE_DOT);
            //---
            Print("New Swing Low detected at ", swingLow);
         }
         //---
         TrendValidation();
      }
   }
}
//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 
//+------------------------------------------------------------------+
void TrendValidation(void)
{
   //--- Identifiying trend
   if(lastSwingHigh.price>0 && prevSwingHigh.price>0)
   {
      //--- Identifiying Higher High (HH) - Bullish trend
      if(lastSwingHigh.price>prevSwingHigh.price) {
         trendPattern = HIGHER_HIGH;
         //--- Draw sign on chart
         MarkTrendPattern("HH", lastSwingHigh.price, lastSwingHigh.time, clrTeal);
         //---
         if(InpEnableReversalStrategy) {
            //--- Add HH to tracking array
            AddSign(trendPattern, lastSwingHigh.price, lastSwingHigh.time, lastSwingHigh.barIndex);
            CheckReversalPattern(trendPattern);
         }
         //---
      }
      //--- Identifiying Lower High (LH) - Bearish trend
      if(lastSwingHigh.price<prevSwingHigh.price) {
         trendPattern = LOWER_HIGH;
         //--- Draw sign on chart
         MarkTrendPattern("LH", lastSwingHigh.price, lastSwingHigh.time,clrBrown);
         //---
         if(InpEnableReversalStrategy) {
            //--- Add HH to tracking array
            AddSign(trendPattern, lastSwingHigh.price, lastSwingHigh.time, lastSwingHigh.barIndex);
            CheckReversalPattern(trendPattern);
         }
         //---
      }
   }
   //--- Identifiying trend
   if(lastSwingLow.price>0 && prevSwingLow.price>0)
   {
      //--- Identifiying Higher Low (HL) - Bullish trend
      if(lastSwingLow.price>prevSwingLow.price) {
         trendPattern = HIGHER_LOW;
         //--- Draw sign on chart
         MarkTrendPattern("HL", lastSwingLow.price, lastSwingLow.time, clrTeal);
         //---
         if(InpEnableReversalStrategy) {
            //--- Add HH to tracking array
            AddSign(trendPattern, lastSwingHigh.price, lastSwingHigh.time, lastSwingHigh.barIndex);
            CheckReversalPattern(trendPattern);
         }
         //---
      }
      //--- Identifiying Lower Low (LL) - Bearish trend
      if(lastSwingLow.price<prevSwingLow.price) {
         trendPattern = LOWER_LOW;
         //--- Draw sign on chart
         MarkTrendPattern("LL", lastSwingLow.price, lastSwingLow.time, clrBrown);
         //--- Add HH+LH+HL+LL sign to tracking array
         if(InpEnableReversalStrategy) {
            //--- Add HH+LH+HL+LL sign to tracking array
            AddSign(trendPattern, lastSwingLow.price, lastSwingLow.time, lastSwingLow.barIndex);
            CheckReversalPattern(trendPattern);
         }
         //---
      }
   }
}
//+------------------------------------------------------------------+
//| Method to detect trend patterns                                  |
//+------------------------------------------------------------------+
void CheckReversalPattern(ENUM_TREND_INDICATOR trend_pattern=NONE)
{
   //--- Implementation of trend pattern detection logic
   if(!InpEnableReversalStrategy)
      return;
   //--- Get current price
   double currentPrice=iClose(_Symbol,PERIOD_CURRENT,0);
   //--- Check for LL Reversal Pattern
   int candleDiff=0;
   double pointDiff=0.0;
   double priceWithinRange=0.0;
   //--- Similar logic can be implemented for HH reversal patterns if needed
   if(lastSwingHigh.is_high && trend_pattern == HIGHER_HIGH) // && lastSwingHigh.price>HH_second.price
   {
      //--- Check if we have at least 2 HH entries
      if(trend.HH_count < 2) return;
      //--- Get the most recent two HH points
      SwingPoint HH_first=trend.HH_sign[trend.HH_count-2];
      SwingPoint HH_second=trend.HH_sign[trend.HH_count-1];
      //--- 
      if(!HH_first.valid || !HH_second.valid) return;
      //--- Calculate differences
      candleDiff=MathAbs(HH_second.barIndex - HH_first.barIndex);
      if(candleDiff>InpConfirmationCandles) 
         return;
      //--- Calculate point difference
      pointDiff=MathAbs(HH_second.price - HH_first.price)/_Point;
      if(pointDiff>InpConfirmationPoints) return;
      //---
      if(trend.HH_count==2) {
         //--- Additional check: current price should be below HH points
         if(currentPrice>HH_second.price && currentPrice>HH_first.price) return;
         //--- 
         double HH_min = MathMin(HH_first.price, HH_second.price);
         if(currentPrice<HH_min)
         {
            priceWithinRange=(HH_min - currentPrice)/_Point;
            if(priceWithinRange<=InpConfirmationPoints && MaxTradeAllowed())
            {
               // Print("HH Reversal confirmed by price action below HH min.");
               //--- Execute trade logic here
            }
         }
      }

      //---
      if(trend.HH_count==3) {
         SwingPoint HH_third=trend.HH_sign[trend.HH_count-3];
         //--- Check if all three are within range
         double maxPrice=MathMax(HH_first.price, MathMax(HH_second.price, HH_third.price));
         double minPrice=MathMin(HH_first.price, MathMin(HH_second.price, HH_third.price));
         double rangePoints=(maxPrice - minPrice)/_Point;

         //---
         if(rangePoints<=InpConfirmationPoints && MaxTradeAllowed())
         {
            // Print("HH Reversal confirmed by 3-point consolidation.");
            //--- Execute trade logic here
         }

         //---
         //--- resistance level
         
         //--- draw rectangle on chart
         //...

         //--- reset HH tracking
         trend.HH_count=0;
         for(int i=0;i<10;i++) {
            trend.HH_sign[i].price=0.0;
            trend.HH_sign[i].time=0;
            trend.HH_sign[i].valid=false;
         }
      }
   }
   //---
   if(!lastSwingLow.is_high && trend_pattern == LOWER_LOW) //  && lastSwingLow.price<LL_second.price
   {
      //--- Check if we have at least 2 LL entries
      if(trend.LL_count < 2) return;
      //--- Get the most recent two LL points
      SwingPoint LL_first=trend.LL_sign[trend.LL_count-2];
      SwingPoint LL_second=trend.LL_sign[trend.LL_count-1];
      //--- 
      if(!LL_first.valid || !LL_second.valid) return;
      //--- Calculate differences
      candleDiff=MathAbs(LL_second.barIndex - LL_first.barIndex);
      if(candleDiff>InpConfirmationCandles) return;
      //--- Calculate point difference
      pointDiff=MathAbs(LL_second.price - LL_first.price)/_Point;
      if(pointDiff>InpConfirmationPoints) return;
      //---
      if(trend.LL_count==2) {
         //--- Additional check: current price should be above both LL points
         if(currentPrice<LL_second.price && currentPrice<LL_first.price) return;
         //--- 
         double LL_max = MathMax(LL_first.price, LL_second.price);
         if(currentPrice>LL_max)
         {
            priceWithinRange=(currentPrice - LL_max)/_Point;
            if(priceWithinRange<=InpConfirmationPoints && MaxTradeAllowed())
            {
               // Print("LL Reversal confirmed by price action above LL max.");
               //--- Execute trade logic here
            }
         }
      }

      //---
      if(trend.LL_count==3) {
         SwingPoint LL_third=trend.LL_sign[trend.LL_count-3];
         //--- Check if all three are within range
         double maxPrice=MathMax(LL_first.price, MathMax(LL_second.price, LL_third.price));
         double minPrice=MathMin(LL_first.price, MathMin(LL_second.price, LL_third.price));
         double rangePoints=(maxPrice - minPrice)/_Point;

         //---
         if(rangePoints<=InpConfirmationPoints && MaxTradeAllowed())
         {
            // Print("LL Reversal confirmed by 3-point consolidation.");
            //--- Execute trade logic here
         }

         //--- support level

         //--- draw rectangle on chart
         //...

         //--- reset LL tracking
         trend.LL_count=0;
         for(int i=0;i<10;i++) {
            trend.LL_sign[i].price=0.0;
            trend.LL_sign[i].time=0;
            trend.LL_sign[i].valid=false;
         }
      }
   }
   //--- TODO: Implement else-if for LL reversal pattern
   // else
   // {
   //    Print("Last swing is not a LL. No reversal pattern detected.");
   // }

   //--- Determine overall trend
   if(count_HH >= 2)
      currentTrend = TREND_UP;
   else if(count_LL >= 2)
      currentTrend = TREND_DOWN;
   else
      currentTrend = TREND_SIDEWAYS;
}
//+------------------------------------------------------------------+
//| Method to check Break of Structure                               |
//+------------------------------------------------------------------+
void CheckBOS()
{
   if(waitingPullback)
      return;  // Already waiting for pullback
   
   double closePrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   double range = 0.0;
   
   // Check for Bullish BOS (price breaks above previous swing high)
   if(lastSwingHigh.price > 0 && closePrice > lastHighTF_SwingHigh.price && lastSwingLow.price!=0 && lastHighTF_SwingLow.price!=0 && lastHighTF_SwingHigh.price!=0) {         
      if(!bos.is_bullish || bos.level != lastSwingHigh.price) {
         bos.is_bullish = true;
         bos.is_bearish = false;
         bos.level = lastHighTF_SwingHigh.price;
         bos.time = TimeCurrent();
         waitingPullback = true;
         
         // Calculate pullback level
         range = lastSwingHigh.price - lastSwingLow.price;
         pullbackLevel = lastSwingHigh.price - NormalizeDouble(range * InpPullbackFibo, _Digits);
         
         Print("Bullish BOS detected at ", bos.level, " | Waiting for pullback to ", NormalizeDouble(pullbackLevel, _Digits));
         
         if(InpShowLevels) {
            DrawLevel("BOS_Break", bos.level, bos.time);
            DrawLevel("BOS_Pullback", pullbackLevel, bos.time);
         }

         //---
         // if(trade.BuyLimit(InpReversalLotSize, pullbackLevel, _Symbol, NormalizeDouble(lastSwingLow.price, _Digits), NormalizeDouble(lastHighTF_SwingHigh.price, _Digits), ORDER_TIME_GTC, 0, InpTradeComment)) {
         //    PO_Ticket = trade.ResultOrder();
         //    Print("Buy Limit order placed at pullback level: ", NormalizeDouble(pullbackLevel, _Digits), " | Ticket: ", PO_Ticket);
         // } else {
         //    Print("Failed to place Buy Limit order. Error: ", GetLastError());
         // }
         //---
         // if(trade.BuyLimit(InpReversalLotSize, NormalizeDouble(bos.level, _Digits), _Symbol, 0, 0, ORDER_TIME_GTC, 0, InpTradeComment)) {
         //    Print("Buy Limit order placed at BOS level: ", NormalizeDouble(bos.level, _Digits));
         // } else {
         //    Print("Failed to place Buy Limit order. Error: ", GetLastError());
         // }
      }
   }
   
   // Check for Bearish BOS (price breaks below previous swing low)
   if(lastSwingLow.price > 0 && closePrice < lastHighTF_SwingLow.price && lastSwingHigh.price!=0 && lastHighTF_SwingHigh.price!=0 && lastHighTF_SwingLow.price!=0) {
      if(!bos.is_bearish || bos.level != lastSwingLow.price) {
         bos.is_bearish = true;
         bos.is_bullish = false;
         bos.level = lastHighTF_SwingLow.price;
         bos.time = TimeCurrent();
         waitingPullback = true;
         
         // Calculate pullback level
         range = lastSwingHigh.price - lastSwingLow.price;
         pullbackLevel = lastSwingLow.price + NormalizeDouble(range * InpPullbackFibo, _Digits);
         
         Print("Bearish BOS detected at ", bos.level, " | Waiting for pullback to ", NormalizeDouble(pullbackLevel, _Digits));
         
         if(InpShowLevels) {
            DrawLevel("BOS_Break", bos.level, bos.time);
            DrawLevel("BOS_Pullback", pullbackLevel, bos.time);
         }

         //---
         // if(trade.SellLimit(InpReversalLotSize, pullbackLevel, _Symbol, NormalizeDouble(lastSwingHigh.price, _Digits), NormalizeDouble(lastHighTF_SwingLow.price, _Digits), ORDER_TIME_GTC, 0, InpTradeComment)) {
         //    PO_Ticket = trade.ResultOrder();
         //    Print("Sell Limit order placed at pullback level: ", NormalizeDouble(pullbackLevel, _Digits), " | Ticket: ", PO_Ticket);
         // } else {
         //    Print("Failed to place Sell Limit order. Error: ", GetLastError());
         // }
         //---
         // if(trade.SellLimit(InpReversalLotSize, NormalizeDouble(bos.level, _Digits), _Symbol, 0, NormalizeDouble(lastSwingLow.price, _Digits), ORDER_TIME_GTC, 0, InpTradeComment)) {
         //    Print("Sell Limit order placed at BOS level: ", NormalizeDouble(bos.level, _Digits));
         // } else {
         //    Print("Failed to place Sell Limit order. Error: ", GetLastError());
         // }
      }
   }
}
//+------------------------------------------------------------------+
//| Method to check for pullback entry                               |
//+------------------------------------------------------------------+
void CheckPullback()
{
   // Check max trades
   // if(CountOpenPositions() >= InpMaxSimultaneousTrades)
   //    return;
   
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Bullish entry: price pulled back to level and starting to move up
   if(bos.is_bullish && waitingPullback) {
      double recentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
      if(InpEnableScalpingMode && recentLow <= bos.level) {
         ExecuteBuyTrade();
         waitingPullback = false;
         bos.is_bullish = false;
      }
      // if(currentLow <= pullbackLevel) {
      //    // Check for confirmation (price moving back up)
      //    double recentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
      //    if(recentHigh > currentHigh) {
      //       ExecuteBuyTrade();
      //       Print("Entry BUY at Pullback level: ", NormalizeDouble(pullbackLevel, _Digits));
      //       waitingPullback = false;
      //       bos.is_bullish = false;
      //    }
      // }
      
      // Invalidate if price breaks below swing low
      if(currentClose < lastSwingLow.price) {
         Print("Bullish setup invalidated - price below swing low");
         //--- Delete pending order if exists
         if(PO_Ticket > 0) {
            if(trade.OrderDelete(PO_Ticket)) {
               Print("Pending Buy Limit order deleted. Ticket: ", PO_Ticket);
               PO_Ticket = 0;
            }
         }
         waitingPullback = false;
         bos.is_bullish = false;
      }

      if(bos.level!=lastHighTF_SwingHigh.price) {
         Print("Bullish BOS level changed - invalidating pullback");
         waitingPullback = false;
         bos.is_bullish = false;
      }
   }
   
   // Bearish entry: price pulled back to level and starting to move down
   if(bos.is_bearish && waitingPullback) {

      if(currentHigh >= pullbackLevel) {
         //Check for confirmation (price moving back down)
         double recentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
         if(recentLow < currentLow) {
            ExecuteSellTrade();
            Print("Entry SELL at Pullback level: ", NormalizeDouble(pullbackLevel, _Digits));
            waitingPullback = false;
            bos.is_bearish = false;
         }
      }
      
      // Invalidate if price breaks above swing high
      if(currentClose > lastSwingHigh.price) {
         Print("Bearish setup invalidated - price above swing high");
         //--- Delete pending order if exists
         if(PO_Ticket > 0) {
            if(trade.OrderDelete(PO_Ticket)) {
               Print("Pending Sell Limit order deleted. Ticket: ", PO_Ticket);
               PO_Ticket = 0;
            }
         }
         waitingPullback = false;
         bos.is_bearish = false;
      }
   }
   // //--- Pullback for second entry at key level (LL Reversal Strategy)
   // if(!isLLkeyInvalid) {
   //    if(currentClose <= LL_keyLevel && bullishBOS) {
   //       //Print("LL Reversal Strategy - Price reached key LL level for BUY entry");
   //       ExecuteBuyTrade();
   //       isLLkeyInvalid = true;  // Prevent multiple entries
   //    }
   // }
   // //--- Pullback for second entry at key level (HH Reversal Strategy)
   // if(!isHHkeyInvalid) {
   //    if(currentClose >= HH_keyLevel && bearishBOS) {
   //       //Print("HH Reversal Strategy - Price reached key HH level for SELL entry");
   //       ExecuteSellTrade();
   //       isHHkeyInvalid = true;  // Prevent multiple entries
   //    }
   // }
}
//endregion
//+------------------------------------------------------------------+
//| Method to process trades based on detected patterns              |
//+------------------------------------------------------------------+
void OnTradeProcessing()
{
   //--- Implementation of trade execution logic based on detected patterns
   //--- Use trade object to open/close positions
}
//+------------------------------------------------------------------+
//| Draw horizontal line on chart                                    |
//+------------------------------------------------------------------+
void MarkSwingLevel(string lvl_name, double lvl_price, color lvl_lineColor, ENUM_LINE_STYLE lvl_lineStyle, int lvl_width=1)
{
   //--- Create or update horizontal line object
   if(ObjectFind(0, lvl_name) < 0)
   {
      ObjectCreate(0, lvl_name, OBJ_HLINE, 0, 0, lvl_price);
      ObjectSetDouble(0, lvl_name, OBJPROP_PRICE, lvl_price);
      ObjectSetInteger(0, lvl_name, OBJPROP_COLOR, lvl_lineColor);
      ObjectSetInteger(0, lvl_name, OBJPROP_STYLE, lvl_lineStyle);
      ObjectSetInteger(0, lvl_name, OBJPROP_WIDTH, lvl_width);
      ObjectSetInteger(0, lvl_name, OBJPROP_BACK, true);
   }
   else
      ObjectSetDouble(0, lvl_name, OBJPROP_PRICE, lvl_price);

}
//+------------------------------------------------------------------+
//| Method to add trend signs to tracking array                     |
//+------------------------------------------------------------------+
void AddSign(ENUM_TREND_INDICATOR trend_pattern, double chk_price, datetime chk_time, int chk_barIndex)
{
   switch(trend_pattern)
   {
      case LOWER_LOW:
         // Shift existing LL signs
         if(trend.LL_count>=3) {
            trend.LL_sign[0]=trend.LL_sign[1];
            trend.LL_sign[1]=trend.LL_sign[2];
            // trend.LL_sign[2]=trend.LL_sign[3];
            // trend.LL_sign[3]=trend.LL_sign[4];
            trend.LL_count=2;
         }
         // Check for duplicates (skip if same price and time as previous entry)
         if(trend.LL_count>0 && trend.LL_sign[trend.LL_count-1].price==chk_price && trend.LL_sign[trend.LL_count-1].time==chk_time)
            return; // Duplicate, skip
         // Add new entry
         trend.LL_sign[trend.LL_count].price=chk_price;
         trend.LL_sign[trend.LL_count].time=chk_time;
         trend.LL_sign[trend.LL_count].barIndex=chk_barIndex;
         trend.LL_sign[trend.LL_count].valid=true;
         trend.LL_count++;
         count_LL++;
         //--- Reset opposite counter if 2 or more LL patterns detected
         if(count_LL >= 2) {
            count_HH = 0;
         }
         // Print("LL sign added. Consecutive LL count: ", IntegerToString(count_LL), " | Array count: ", IntegerToString(trend.LL_count));
         break;
      case HIGHER_HIGH:
         // Shift existing HH signs
         if(trend.HH_count>=3) {
            trend.HH_sign[0]=trend.HH_sign[1];
            trend.HH_sign[1]=trend.HH_sign[2];
            // trend.HH_sign[2]=trend.HH_sign[3];
            // trend.HH_sign[3]=trend.HH_sign[4];
            trend.HH_count=2;
         }
         // Check for duplicates (skip if same price and time as previous entry)
         if(trend.HH_count>0 && trend.HH_sign[trend.HH_count-1].price==chk_price && trend.HH_sign[trend.HH_count-1].time==chk_time)
            return; // Duplicate, skip
         // Add new entry
         trend.HH_sign[trend.HH_count].price=chk_price;
         trend.HH_sign[trend.HH_count].time=chk_time;
         trend.HH_sign[trend.HH_count].barIndex=chk_barIndex;
         trend.HH_sign[trend.HH_count].valid=true;
         trend.HH_count++;
         count_HH++;
         //--- Reset opposite counter if 2 or more HH patterns detected
         if(count_HH >= 2) {
            count_LL = 0;
         }
         // Print("HH sign added. Consecutive HH count: ", IntegerToString(count_HH), " | Array count: ", IntegerToString(trend.HH_count));
         break;
   }
}
//+------------------------------------------------------------------+
//| Draw trend pattern sign on chart                                 |
//+------------------------------------------------------------------+
void MarkTrendPattern(string sign_name, double sign_price, datetime sign_time, color sign_color)
{
   string name = sign_name + " " + EEnumToString(chartTF)+ "\n" + TimeToString(sign_time, TIME_DATE|TIME_SECONDS);
   //--- Create or update trend pattern sign on chart
   if(ObjectFind(0, name) >= 0)
      return; // Sign already exists
   //--- Create text label
   if(ObjectCreate(0, name, OBJ_TEXT, 0, sign_time, sign_price))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, sign_name);
      ObjectSetInteger(0, name, OBJPROP_COLOR, sign_color);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      // ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   //--- Set anchor position based on trend pattern
   if(trendPattern==HIGHER_HIGH || trendPattern==LOWER_HIGH)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   else if(trendPattern==HIGHER_LOW || trendPattern==LOWER_LOW)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
}
//+------------------------------------------------------------------+
//| Assign trend based on detected swings                            |
//+------------------------------------------------------------------+
void PatternAssigned(double price, datetime time, int barIndex)
{
   //--- Implementation of trend assignment logic based on detected patterns
   //--- Update currentTrend accordingly
}
//+------------------------------------------------------------------+
//| Draw trend horizontal line level on chart                                   |
//+------------------------------------------------------------------+
void DrawLevel(string name, double price, datetime time)
{
   //--- set time1 and time2 for trend line
   datetime currentTime = TimeCurrent();
   //--- set time1 to previous 5 bars from BOS detection
   datetime time1 = time - 5 * PeriodSeconds(PERIOD_CURRENT);
   //--- set time2 to 10 bars ahead of current time (keeps extending)
   datetime time2 = currentTime + 5 * PeriodSeconds(PERIOD_CURRENT);
   //---
   color breakout_clr=C'130,95,7';
   color pullback_clr=clrDarkGreen;
   int breakout_style=STYLE_DASH;
   int pullback_style=STYLE_DASHDOT;
   int breakout_width=2;
   int pullback_width=1;

   Print("Drawing level: ", name, " at price: ", NormalizeDouble(price, _Digits));
   //---
   if(name=="BOS_Break")
   {
      //--- Delete old object if exists to redraw at new level
      if(ObjectFind(0, name) >= 0) {
         ObjectDelete(0, name);
      }
      //--- Create trend line object
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price, time2, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, breakout_clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, breakout_style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, breakout_width);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false); 
   }

   //---
   if(name=="BOS_Pullback") // Draw horizontal line for pullback level
   {
      //--- Delete old object if exists to redraw at new level
      if(ObjectFind(0, name) >= 0) {
         ObjectDelete(0, name);
      }
      //--- Create horizontal line object
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, pullback_clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, pullback_style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, pullback_width);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}
//+------------------------------------------------------------------+
//| Move trend line anchor point                                     |
//+------------------------------------------------------------------+
bool TrendPointChange(const long   chart_ID=0,       // chart's ID
                      const string name="BOS_Break", // line name
                     //  const int    point_index=0,    // anchor point index
                      datetime     time=0,           // anchor point time coordinate
                      double       price=0)          // anchor point price coordinate
{
//--- if point position is not set, move it to the current bar having Bid price
   if(!time)
      time=TimeCurrent();
   if(!price)
      price=iClose(_Symbol, PERIOD_CURRENT, 0);
   
   datetime time_extend=time + 5 * PeriodSeconds(PERIOD_CURRENT);
//--- reset the error value
   ResetLastError();
//--- move trend line's anchor point
   if(!ObjectMove(chart_ID,name,1,time_extend,price))
     {
      Print(__FUNCTION__,
            ": failed to move the anchor point! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
}
//+------------------------------------------------------------------+
//| Check if maximum trades allowed is not exceeded                  |
//+------------------------------------------------------------------+
bool MaxTradeAllowed()
{
   int openPositions=CountOpenPositions();
   if(openPositions>=InpMaxSimultaneousTrades)
   {
      Print("Maximum simultaneous trades reached: ", IntegerToString(openPositions));
      return(false);
   }
   return(true);
}
//+------------------------------------------------------------------+
//| Execute Buy Trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade()
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl, tp;
   
   // // Calculate Stop Loss
   // if(InpStopLossPoints > 0) {
   //    sl = entryPrice - InpStopLossPoints * _Point;
   // } else {
   //    sl = lastSwingLow.price - 10 * _Point;  // Below swing low
   // }
   
   // // Calculate Take Profit
   // if(InpTakeProfitPoints > 0) {
   //    tp = entryPrice + InpTakeProfitPoints * _Point;
   // } else {
   //    tp = NormalizeDouble(lastSwingHigh.price * _Point, _Digits);
   // }
   
   // Calculate lot size based on risk
   // double lotSize = CalculateLotSize(entryPrice - sl);
   // Sleep(2000);
   if(InpEnableScalpingMode) {
      entryPrice = bos.level + 10 * _Point;  // Slightly above BOS level
      sl = pullbackLevel - 10 * _Point;  // Below pullback level
      tp = 2000 * _Point;  // Fixed TP for scalping
   } else {
      sl = 0;
      tp = 0;
   }
   // Execute trade
   if(trade.Buy(InpReversalLotSize, _Symbol, entryPrice, sl, tp, InpTradeComment)) {
      Print("BUY order opened at ", entryPrice, " | SL: ", sl, " | TP: ", tp, " | Lot: ", InpReversalLotSize);
   } else {
      Print("BUY order failed: ", trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
//| Execute Sell Trade                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade()
{
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // double sl, tp;
   
   // // Calculate Stop Loss
   // if(InpStopLossPoints > 0) {
   //    sl = entryPrice + InpStopLossPoints * _Point;
   // } else {
   //    sl = NormalizeDouble(lastSwingHigh.price + 10 * _Point, _Digits);  // Above swing high
   // }
   
   // // Calculate Take Profit
   // if(InpTakeProfitPoints > 0) {
   //    tp = entryPrice - InpTakeProfitPoints * _Point;
   // } else {
   //    tp = NormalizeDouble(prevSwingLow.price * _Point, _Digits);
   // }
   
   // Calculate lot size based on risk
   // double lotSize = CalculateLotSize(sl - entryPrice);
   // Sleep(2000);
   
   // Execute trade
   if(trade.Sell(InpReversalLotSize, _Symbol, entryPrice, 0, 0, InpTradeComment)) {
      Print("SELL order opened at ", entryPrice, " | SL: ", " | Lot: ", InpReversalLotSize);
   } else {
      Print("SELL order failed: ", trade.ResultRetcodeDescription());
   }
}
//+------------------------------------------------------------------+
//| Count open positions for this EA and symbol                      |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int total=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL)==Symbol())
         {
            total++;
         }
      }
   }
   return(total);
}
//+------------------------------------------------------------------+
//| Method to display swing points and trend segments on chart       |
//+------------------------------------------------------------------+
void ResultToChart()
{
   //--- Draw swing points
   for(int i=0;i<ArraySize(swingPoints);i++)
   {
      string objName = "SwingPoint_" + IntegerToString(i) + "_" + EEnumToString(timeFrameToAnalize);
      color pointColor = swingPoints[i].is_high ? clrTeal : clrBrown;
      //--- Create or update swing point on chart
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_ARROW, 0, swingPoints[i].time, swingPoints[i].price);
         // ObjectSetDouble(0, objName, OBJPROP_PRICE, swingPoints[i].price);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, swingPoints[i].is_high ? 234 : 233);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, pointColor);
         // ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
         // ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetString(0, objName, OBJPROP_TEXT, swingPoints[i].is_high ? "High" : "Low");
      }
      else
         ObjectSetDouble(0, objName, OBJPROP_PRICE, swingPoints[i].price);
   }

   //--- Draw trend lines
   for(int j=0;j<ArraySize(trendSegments);j++)
   {
      string trendLineName = "TrendSegment_" + IntegerToString(j) + "_" + EEnumToString(timeFrameToAnalize);
      color lineColor = clrGray;
      if(trendSegments[j].trendType == TREND_UP)
         lineColor = clrLime;
      else if(trendSegments[j].trendType == TREND_DOWN)
         lineColor = clrRed;
      else if(trendSegments[j].trendType == TREND_SIDEWAYS)
         lineColor = clrYellow;

      //--- Create or update trend line on chart
      if(ObjectFind(0, trendLineName) < 0)
      {
         ObjectCreate(0, trendLineName, OBJ_TREND, 0,
                      trendSegments[j].startTime, trendSegments[j].startPrice,
                      trendSegments[j].endTime, trendSegments[j].endPrice);
         ObjectSetInteger(0, trendLineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, trendLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, trendLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, trendLineName, OBJPROP_RAY_RIGHT, false);
      }
   }
}
//+------------------------------------------------------------------+
//| Method to display information on chart                           |
//+------------------------------------------------------------------+
void InfoToChart()
{
   string info = "\n=== BOS Pullback EA ===\n";
   info += "Last "+ EEnumToString(timeFrameToAnalize) + " Swing High:" + DoubleToString(lastHighTF_SwingHigh.price, _Digits) + "\n";
   info += "Last "+ EEnumToString(timeFrameToAnalize) + " Swing Low:" + DoubleToString(lastHighTF_SwingLow.price, _Digits) + "\n";
   info += "Last Swing High: " + DoubleToString(lastSwingHigh.price, _Digits) + "\n";
   info += "Last Swing Low: " + DoubleToString(lastSwingLow.price, _Digits) + "\n";
   
   //--- Show trend info
   // Show trend state
   string trendText = "DETECTING...";
   switch(currentTrend)
   {
      case TREND_UP:
         trendText = "UPTREND::BULLISH (HH + HL)";
         break;
      case TREND_DOWN:
         trendText = "DOWNTREND::BEARISH (LL + LH)";
         break;
      case TREND_SIDEWAYS:
         trendText = "SIDEWAYS::RANGING MARKET";
         break;
      default:
         trendText = "UNDEFINED";
         break;
   }
   info += "Current Trend: " + trendText + "\n";
   
   if(waitingPullback) {
      info += "\n--- WAITING FOR PULLBACK ---\n";
      if(InpEnableScalpingMode) {
         info += "Scalping Mode: ENABLED\n";
         info += "Entry at BOS Level: " + DoubleToString(bos.level, _Digits) + "\n";
      } else {
         info += "Scalping Mode: DISABLED\n";
      }
      info += "Type: " + (bos.is_bullish ? "BULLISH" : "BEARISH") + "\n";
      info += "BOS Level: " + DoubleToString(bos.level, _Digits) + "\n";
      info += "Pullback Target: " + DoubleToString(pullbackLevel, _Digits) + "\n";
   } else {
      info += "\nScanning for Break of Structure...\n";
   }
   
   info += "\nOpen Positions: " + IntegerToString(CountOpenPositions()) + " / " + IntegerToString(InpMaxSimultaneousTrades);
   
   Comment(info);
}
//+------------------------------------------------------------------+
//| Convert ENUM_TIMEFRAMES to string representation                 |
//+------------------------------------------------------------------+
string EEnumToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "UNKNOWN";
   }
}
//+------------------------------------------------------------------+
//| Check if bar is a Swing High                                     |
//+------------------------------------------------------------------+
bool IsSwingHigh(int bar_index, ENUM_TIMEFRAMES tf, int left_bars, int right_bars)
{
   int i,j;
   double center_price = iHigh(_Symbol, tf, bar_index);
   for(i=1; i<=left_bars; i++)
   {
      if(iHigh(_Symbol, tf, bar_index + i) >= center_price)
         return(false);
   }
   for(j=1; j<=right_bars; j++)
   {
      if(iHigh(_Symbol, tf, bar_index - j) >= center_price)
         return(false);
   }
   return(true);
}
//+------------------------------------------------------------------+
//| Check if bar is a Swing Low                                      |
//+------------------------------------------------------------------+
bool IsSwingLow(int bar_index, ENUM_TIMEFRAMES tf, int left_bars, int right_bars)
{
   int i,j;
   double center_price = iLow(_Symbol, tf, bar_index);
   for(i=1; i<=left_bars; i++)
   {
      if(iLow(_Symbol, tf, bar_index + i) <= center_price)
         return(false);
   }
   for(j=1; j<=right_bars; j++)
   {
      if(iLow(_Symbol, tf, bar_index - j) <= center_price)
         return(false);
   }
   return(true);
}