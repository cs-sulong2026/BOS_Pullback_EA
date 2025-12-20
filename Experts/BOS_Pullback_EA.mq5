//+------------------------------------------------------------------+
//|                                              BOS_Pullback_EA.mq5 |
//|                                  Break of Structure with Pullback |
//|                                   Price Action Automated Strategy |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"
#property description "Trades Break of Structure with pullback entry + Trend detection"

#include <Trade/Trade.mqh>

//--- Input parameters
input group "=== Strategy Settings ==="
input int      InpSwingPeriod = 10;              // Swing detection period (bars)
input double   InpPullbackFibo = 0.5;            // Pullback Fibonacci level (0.382-0.618)
input int      InpConfirmationBars = 2;          // Confirmation bars after pullback
input bool     InpTradeOnlyTrend = true;         // Trade only in trending markets
input bool     InpShowTrendStructure = true;     // Show HH/HL/LH/LL labels

input group "=== Reversal Strategy (LL Pattern) ==="
input bool     InpEnableReversalStrategy = true; // Enable LL reversal strategy
input int      InpLLCandleRange = 10;            // Max candles between LL signs
input int      InpLLPointRange = 200;            // Max points between LL signs
input int      InpHHCandleRange = 10;            // Max candles between HH signs
input int      InpHHPointRange = 200;            // Max points between HH signs
input double   InpReversalLotSize = 0.01;        // Fixed lot size for reversal trades
input bool     InpSetTPAfterClose = true;        // Set TP after candle closes
input bool     InpUseCandleBasedTP = false;      // Use candle size * 2 for TP (false = use R:R)
input int      InpStructurePendingRange = 50;     // Range for 3-LL pending order (points from first LL)

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
input bool     InpTradeIdeaAllowed = false;      // Allow opposite direction trades

input group "=== Partial Closure Settings ==="
input bool     InpEnablePartialClosure = false;  // Enable partial closure
input double   InpPartialClosePercent = 50.0;    // Volume to close (% of total)
input bool     InpUseFloatingLossPct = false;    // Use floating loss % of balance
input double   InpFloatingLossPct = 2.0;         // Floating loss % of balance to trigger
input bool     InpUseFloatingLossAmount = false; // Use floating loss currency amount
input double   InpFloatingLossAmount = 100.0;    // Floating loss amount ($) to trigger
input bool     InpUseFloatingLossPoints = false; // Use floating loss points
input int      InpFloatingLossPoints = 500;      // Floating loss points to trigger
input bool     InpUseFloatingProfitPct = false;  // Use floating profit % of balance
input double   InpFloatingProfitPct = 1.0;       // Floating profit % of balance to trigger
input bool     InpUseFloatingProfitAmount = false; // Use floating profit currency amount
input double   InpFloatingProfitAmount = 50.0;   // Floating profit amount ($) to trigger
input bool     InpUseFloatingProfitPoints = false; // Use floating profit points
input int      InpFloatingProfitPoints = 300;    // Floating profit points to trigger

//--- Global variables
CTrade trade;
datetime lastBarTime;

struct SwingPoint {
   double price;
   datetime time;
   int barIndex;
   bool isHigh;  // true for swing high, false for swing low
};

SwingPoint lastSwingHigh;
SwingPoint lastSwingLow;
SwingPoint prevSwingHigh;
SwingPoint prevSwingLow;
bool bullishBOS = false;
bool bearishBOS = false;
double bosLevel = 0;
datetime bosTime = 0;
bool waitingForPullback = false;
double pullbackLevel = 0;

// Trend state
enum TrendState {
   TREND_NONE,
   TREND_UP,    // Higher highs and higher lows
   TREND_DOWN   // Lower highs and lower lows
};
TrendState currentTrend = TREND_NONE;

// LL Reversal Strategy
struct LLSign {
   double price;
   datetime time;
   int barIndex;
   bool valid;
};

LLSign llSigns[3];  // Track up to 3 LL signs
int llSignCount = 0;
double LL_keyLevel = 0;  // Remember the three-LL price
ulong short_PO_ticket = 0;  // Track pending order
ulong reversalPositionTicket = 0;  // Track opened reversal position
int entryBarIndex = -1;  // Track entry bar for TP calculation
double entryCandleSize = 0;  // Store entry candle size
bool reversalTradeActive = false;  // Track if reversal trade is active
static bool isLLkeyInvalid = false;  // Track if key LL is valid
static int LL_counter = 0;  // Counter for LL signs

// HH Reversal Strategy
struct HHSign {
   double price;
   datetime time;
   int barIndex;
   bool valid;
};

HHSign hhSigns[3];  // Track up to 3 HH signs
int hhSignCount = 0;
double HH_keyLevel = 0;  // Remember the three-HH price
ulong long_PO_ticket = 0;  // Track pending sell order
ulong reversalPositionTicketHH = 0;  // Track opened HH reversal position
int entryBarIndexHH = -1;  // Track entry bar for TP calculation (HH)
double entryCandleSizeHH = 0;  // Store entry candle size (HH)
bool reversalTradeActiveHH = false;  // Track if HH reversal trade is active
static bool isHHkeyInvalid = false;  // Track if key HH is valid
static int HH_counter = 0;  // Counter for HH signs

// Partial closure tracking
ulong partiallyClosedTickets[];  // Track tickets that have been partially closed

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   // Initialize last bar time
   lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Initialize swing points
   lastSwingHigh.price = 0;
   lastSwingHigh.time = 0;
   lastSwingLow.price = 0;
   lastSwingLow.time = 0;
   prevSwingHigh.price = 0;
   prevSwingHigh.time = 0;
   prevSwingLow.price = 0;
   prevSwingLow.time = 0;
   
   // Initialize LL reversal tracking
   for(int i = 0; i < 3; i++) {
      llSigns[i].price = 0;
      llSigns[i].time = 0;
      llSigns[i].barIndex = 0;
      llSigns[i].valid = false;
   }
   llSignCount = 0;
   LL_keyLevel = 0;
   short_PO_ticket = 0;
   reversalPositionTicket = 0;
   entryBarIndex = -1;
   entryCandleSize = 0;
   reversalTradeActive = false;
   isLLkeyInvalid = false;
   
   // Initialize HH reversal tracking
   for(int i = 0; i < 3; i++) {
      hhSigns[i].price = 0;
      hhSigns[i].time = 0;
      hhSigns[i].barIndex = 0;
      hhSigns[i].valid = false;
   }
   hhSignCount = 0;
   HH_keyLevel = 0;
   long_PO_ticket = 0;
   reversalPositionTicketHH = 0;
   entryBarIndexHH = -1;
   entryCandleSizeHH = 0;
   reversalTradeActiveHH = false;
   isHHkeyInvalid = false;
   
   // Initialize partial closure tracking
   ArrayResize(partiallyClosedTickets, 0);
   
   //Print("BOS Pullback EA initialized on ", _Symbol);
   //Print("Swing Period: ", InpSwingPeriod, " | Pullback Fibo: ", InpPullbackFibo);
   //Print("Trend Structure Detection: ", InpShowTrendStructure ? "ENABLED" : "DISABLED");
   //Print("LL Reversal Strategy: ", InpEnableReversalStrategy ? "ENABLED" : "DISABLED");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up chart objects
   if(InpShowLevels) {
      ObjectsDeleteAll(0, "BOS_");
   }
   if(InpShowTrendStructure) {
      ObjectsDeleteAll(0, "TREND_");
   }
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == lastBarTime)
      return;
   
   lastBarTime = currentBarTime;
   
   // Update swing points
   UpdateSwingPoints();
   
   // Detect trend structure (HH/HL/LH/LL)
   if(InpShowTrendStructure) {
      DetectTrendStructure();
      CheckPullbackEntry();
   }
   
   // Check for Break of Structure
   // CheckForBOS();
   
   // // Monitor pullback and enter trades
   // if(waitingForPullback) {
   //    CheckPullbackEntry();
   // }
   
   // Check partial closure conditions
   if(InpEnablePartialClosure) {
      CheckPartialClosure();
   }
   
   // Update chart display
   UpdateChartInfo();
}

//+------------------------------------------------------------------+
//| Update swing high and low points                                 |
//+------------------------------------------------------------------+
void UpdateSwingPoints()
{
   // Find swing high
   int highestBar = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, InpSwingPeriod * 2 + 1, InpSwingPeriod);
   if(highestBar == InpSwingPeriod) {
      double swingHigh = iHigh(_Symbol, PERIOD_CURRENT, highestBar);
      datetime swingTime = iTime(_Symbol, PERIOD_CURRENT, highestBar);
      
      if(swingHigh != lastSwingHigh.price || swingTime != lastSwingHigh.time) {
         // Save previous swing high
         prevSwingHigh = lastSwingHigh;
         
         // Update last swing high
         lastSwingHigh.price = swingHigh;
         lastSwingHigh.time = swingTime;
         lastSwingHigh.barIndex = highestBar;
         lastSwingHigh.isHigh = true;
         
         if(InpShowLevels) {
            DrawLevel("BOS_SwingHigh", lastSwingHigh.price, clrBlue, STYLE_DOT);
         }
         
         //Print("Swing High detected at ", swingHigh, " (bar ", highestBar, ")");
         //---
         if(swingHigh > HH_keyLevel && !isHHkeyInvalid) {
            //Print(__FUNCTION__+"   HH_KEY_LEVEL INVALIDATED - price above swing high");
            HH_keyLevel = 0.0;
            isHHkeyInvalid = true;
            ObjectDelete(0, "HH_REVERSAL_KeyLevel");
            ChartRedraw();
         }
      }
   }
   
   // Find swing low
   int lowestBar = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, InpSwingPeriod * 2 + 1, InpSwingPeriod);
   if(lowestBar == InpSwingPeriod) {
      double swingLow = iLow(_Symbol, PERIOD_CURRENT, lowestBar);
      datetime swingTime = iTime(_Symbol, PERIOD_CURRENT, lowestBar);
      
      if(swingLow != lastSwingLow.price || swingTime != lastSwingLow.time) {
         // Save previous swing low
         prevSwingLow = lastSwingLow;
         
         // Update last swing low
         lastSwingLow.price = swingLow;
         lastSwingLow.time = swingTime;
         lastSwingLow.barIndex = lowestBar;
         lastSwingLow.isHigh = false;
         
         if(InpShowLevels) {
            DrawLevel("BOS_SwingLow", lastSwingLow.price, clrRed, STYLE_DOT);
         }
         
         //Print("Swing Low detected at ", swingLow, " (bar ", lowestBar, ")");
         //---
         if(swingLow < LL_keyLevel && !isLLkeyInvalid)
            IsKeyLevelStillValid();
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Trend Structure (HH, HL, LH, LL)                          |
//+------------------------------------------------------------------+
void DetectTrendStructure()
{
   // Check for Higher High (HH) - Bullish
   if(lastSwingHigh.price > 0 && prevSwingHigh.price > 0) {
      if(lastSwingHigh.price > prevSwingHigh.price) {
         DrawTrendLabel("TREND_HH_" + IntegerToString(lastSwingHigh.time), 
                       lastSwingHigh.price, lastSwingHigh.time, "HH", clrDeepSkyBlue);
         //Print("Higher High detected at ", lastSwingHigh.price);
         
         // Track HH for reversal strategy (uptrend reversal → SELL)
         if(InpEnableReversalStrategy) {
            AddHHSign(lastSwingHigh.price, lastSwingHigh.time, lastSwingHigh.barIndex);
            CheckHHReversalStrategy();
            ManageReversalTPHH();
         }
         HH_counter++;
         LL_counter = 0;
      }
   }
   
   // Check for Lower High (LH) - Bearish
   if(lastSwingHigh.price > 0 && prevSwingHigh.price > 0) {
      if(lastSwingHigh.price < prevSwingHigh.price) {
         DrawTrendLabel("TREND_LH_" + IntegerToString(lastSwingHigh.time), 
                       lastSwingHigh.price, lastSwingHigh.time, "LH", clrRed);
         //Print("Lower High detected at ", lastSwingHigh.price);
         if(LL_counter > 4 && HH_counter == 0 && PositionsTotal() <= InpMaxSimultaneousTrades) {
            ExecuteSellTrade();
            //Print("Executing SELL trade on Lower High detection");
         }
      }
   }
   
   // Check for Higher Low (HL) - Bullish
   if(lastSwingLow.price > 0 && prevSwingLow.price > 0) {
      if(lastSwingLow.price > prevSwingLow.price) {
         DrawTrendLabel("TREND_HL_" + IntegerToString(lastSwingLow.time), 
                       lastSwingLow.price, lastSwingLow.time, "HL", clrDeepSkyBlue);
         //Print("Higher Low detected at ", lastSwingLow.price);
         if(HH_counter > 4 && LL_counter == 0 && PositionsTotal() <= InpMaxSimultaneousTrades) {
            ExecuteBuyTrade();
            //Print("Executing BUY trade on Higher Low detection");
         }
      }
   }
   
   // Check for Lower Low (LL) - Bearish
   if(lastSwingLow.price > 0 && prevSwingLow.price > 0) {
      if(lastSwingLow.price < prevSwingLow.price) {
         DrawTrendLabel("TREND_LL_" + IntegerToString(lastSwingLow.time), 
                       lastSwingLow.price, lastSwingLow.time, "LL", clrRed);
         //Print("Lower Low detected at ", lastSwingLow.price);
         
         // Track LL for reversal strategy (downtrend reversal → BUY)
         if(InpEnableReversalStrategy) {
            AddLLSign(lastSwingLow.price, lastSwingLow.time, lastSwingLow.barIndex);
            CheckLLReversalStrategy();
            ManageReversalTP();
         }
         
         // If waiting for trend confirmation (HH), place pending SELL order at first HH
         // if(waitingForTrendConfirmationHH && hhSignCount >= 2 && pendingOrderTicketHH == 0) {
         //    Print("LL detected - Placing pending SELL order at first HH");
         //    PlacePendingSellLimit(hhSigns[0].price, hhSigns[0].barIndex);
         //    waitingForTrendConfirmationHH = false;
         // }
         LL_counter++;
         HH_counter = 0;
      }
   }
   
   // Determine overall trend
   if(lastSwingHigh.price > prevSwingHigh.price && lastSwingLow.price > prevSwingLow.price) {
      currentTrend = TREND_UP;
   } else if(lastSwingHigh.price < prevSwingHigh.price && lastSwingLow.price < prevSwingLow.price) {
      currentTrend = TREND_DOWN;
   }
}

void IsKeyLevelStillValid()
{
   // Check if LL_keyLevel is still valid
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(currentClose < lastSwingLow.price) {
      //Print(__FUNCTION__+" LL_KEY_LEVEL invalidated - price below swing low");
      ObjectDelete(0, "LL_REVERSAL_KeyLevel");
      ChartRedraw();
      LL_keyLevel = 0.0;
      isLLkeyInvalid = true;
      CheckPosition("LONG");
   }

// Check if HH_keyLevel is still valid
   if(currentClose > lastSwingHigh.price) {
      //Print(__FUNCTION__+" HH_KEY_LEVEL invalidated - price above swing high");
      ObjectDelete(0, "HH_REVERSAL_KeyLevel");
      ChartRedraw();
      HH_keyLevel = 0.0;
      isHHkeyInvalid = true;
      CheckPosition("SHORT");
   }
}

//+------------------------------------------------------------------+
//| Check for Break of Structure                                     |
//+------------------------------------------------------------------+
void CheckForBOS()
{
   if(waitingForPullback)
      return;  // Already waiting for pullback
   
   double closePrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   
   // Check for Bullish BOS (price breaks above previous swing high)
   if(lastSwingHigh.price > 0 && closePrice > lastSwingHigh.price) {
      // Only trade with trend if filter enabled
      if(InpTradeOnlyTrend && currentTrend != TREND_UP)
         return;
         
      if(!bullishBOS || bosLevel != lastSwingHigh.price) {
         bullishBOS = true;
         bearishBOS = false;
         bosLevel = lastSwingHigh.price;
         bosTime = TimeCurrent();
         waitingForPullback = true;
         
         // Calculate pullback level
         double range = lastSwingHigh.price - lastSwingLow.price;
         pullbackLevel = lastSwingHigh.price - (range * InpPullbackFibo);
         
         //Print("Bullish BOS detected at ", bosLevel, " | Waiting for pullback to ", pullbackLevel);
         
         if(InpShowLevels) {
            DrawLevel("BOS_Break", bosLevel, clrLime, STYLE_SOLID, 2);
            DrawLevel("BOS_Pullback", pullbackLevel, clrYellow, STYLE_DASH);
         }
      }
   }
   
   // Check for Bearish BOS (price breaks below previous swing low)
   if(lastSwingLow.price > 0 && closePrice < lastSwingLow.price) {
      // Only trade with trend if filter enabled
      if(InpTradeOnlyTrend && currentTrend != TREND_DOWN)
         return;
         
      if(!bearishBOS || bosLevel != lastSwingLow.price) {
         bearishBOS = true;
         bullishBOS = false;
         bosLevel = lastSwingLow.price;
         bosTime = TimeCurrent();
         waitingForPullback = true;
         
         // Calculate pullback level
         double range = lastSwingHigh.price - lastSwingLow.price;
         pullbackLevel = lastSwingLow.price + (range * InpPullbackFibo);
         
         //Print("Bearish BOS detected at ", bosLevel, " | Waiting for pullback to ", pullbackLevel);
         
         if(InpShowLevels) {
            DrawLevel("BOS_Break", bosLevel, clrRed, STYLE_SOLID, 2);
            DrawLevel("BOS_Pullback", pullbackLevel, clrYellow, STYLE_DASH);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for pullback completion and entry                          |
//+------------------------------------------------------------------+
void CheckPullbackEntry()
{
   // Check time filter
   if(InpUseTimeFilter && !IsWithinTradingHours())
      return;
   
   // Check max trades
   if(CountOpenPositions() >= InpMaxSimultaneousTrades)
      return;
   
   double currentClose = iClose(_Symbol, PERIOD_CURRENT, 1);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 1);
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   
   // Bullish entry: price pulled back to level and starting to move up
   if(bullishBOS && waitingForPullback) {
      if(currentLow <= pullbackLevel) {
         // Check for confirmation (price moving back up)
         double recentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
         if(recentHigh > currentHigh) {
            ExecuteBuyTrade();
            waitingForPullback = false;
            bullishBOS = false;
         }
      }
      
      // Invalidate if price breaks below swing low
      if(currentClose < lastSwingLow.price) {
         //Print("Bullish setup invalidated - price below swing low");
         waitingForPullback = false;
         bullishBOS = false;
      }
   }
   
   // Bearish entry: price pulled back to level and starting to move down
   if(bearishBOS && waitingForPullback) {
      if(currentHigh >= pullbackLevel) {
         // Check for confirmation (price moving back down)
         double recentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
         if(recentLow < currentLow) {
            ExecuteSellTrade();
            waitingForPullback = false;
            bearishBOS = false;
         }
      }
      
      // Invalidate if price breaks above swing high
      if(currentClose > lastSwingHigh.price) {
         //Print("Bearish setup invalidated - price above swing high");
         waitingForPullback = false;
         bearishBOS = false;
      }
   }
   //--- Pullback for second entry at key level (LL Reversal Strategy)
   if(!isLLkeyInvalid) {
      if(currentClose <= LL_keyLevel && bullishBOS) {
         //Print("LL Reversal Strategy - Price reached key LL level for BUY entry");
         ExecuteBuyTrade();
         isLLkeyInvalid = true;  // Prevent multiple entries
      }
   }
   //--- Pullback for second entry at key level (HH Reversal Strategy)
   if(!isHHkeyInvalid) {
      if(currentClose >= HH_keyLevel && bearishBOS) {
         //Print("HH Reversal Strategy - Price reached key HH level for SELL entry");
         ExecuteSellTrade();
         isHHkeyInvalid = true;  // Prevent multiple entries
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Trade                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade()
{
   // Check for opposite direction positions
   if(!InpTradeIdeaAllowed && HasOppositeDirectionPosition(POSITION_TYPE_BUY)) {
      //Print("BUY trade blocked - SELL position(s) already running");
      return;
   }
   
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl, tp;
   
   // Calculate Stop Loss
   if(InpStopLossPoints > 0) {
      sl = entryPrice - InpStopLossPoints * _Point;
   } else {
      sl = lastSwingLow.price - 10 * _Point;  // Below swing low
   }
   
   // Calculate Take Profit
   if(InpTakeProfitPoints > 0) {
      tp = entryPrice + InpTakeProfitPoints * _Point;
   } else {
      double slDistance = entryPrice - sl;
      tp = entryPrice + (slDistance * InpRiskRewardRatio);
   }
   
   // Calculate lot size based on risk
   double lotSize = CalculateLotSize(entryPrice - sl);
   // Sleep(2000);
   // Execute trade
   if(trade.Buy(lotSize, _Symbol, entryPrice, sl, tp, InpTradeComment)) {
      //Print("BUY order opened at ", entryPrice, " | SL: ", sl, " | TP: ", tp, " | Lot: ", lotSize);
   } else {
      //Print("BUY order failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Trade                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade()
{
   // Check for opposite direction positions
   if(!InpTradeIdeaAllowed && HasOppositeDirectionPosition(POSITION_TYPE_SELL)) {
      //Print("SELL trade blocked - BUY position(s) already running");
      return;
   }
   
   double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp;
   
   // Calculate Stop Loss
   if(InpStopLossPoints > 0) {
      sl = entryPrice + InpStopLossPoints * _Point;
   } else {
      sl = lastSwingHigh.price + 10 * _Point;  // Above swing high
   }
   
   // Calculate Take Profit
   if(InpTakeProfitPoints > 0) {
      tp = entryPrice - InpTakeProfitPoints * _Point;
   } else {
      double slDistance = sl - entryPrice;
      tp = entryPrice - (slDistance * InpRiskRewardRatio);
   }
   
   // Calculate lot size based on risk
   double lotSize = CalculateLotSize(sl - entryPrice);
   // Sleep(2000);
   
   // Execute trade
   if(trade.Sell(lotSize, _Symbol, entryPrice, sl, tp, InpTradeComment)) {
      //Print("SELL order opened at ", entryPrice, " | SL: ", sl, " | TP: ", tp, " | Lot: ", lotSize);
   } else {
      //Print("SELL order failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPercent / 100.0;
   
   double slTicks = slDistance / tickSize;
   double lotSize = riskMoney / (slTicks * tickValue);
   
   // Round to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply limits
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Count open positions with this magic number                      |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if there are positions in opposite direction               |
//+------------------------------------------------------------------+
bool HasOppositeDirectionPosition(ENUM_POSITION_TYPE direction)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Check for opposite direction
      if(direction == POSITION_TYPE_BUY && posType == POSITION_TYPE_SELL)
         return true;
      if(direction == POSITION_TYPE_SELL && posType == POSITION_TYPE_BUY)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                    |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(InpStartHour < InpEndHour) {
      return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
   } else {
      return (dt.hour >= InpStartHour || dt.hour < InpEndHour);
   }
}

//+------------------------------------------------------------------+
//| Draw horizontal level on chart                                   |
//+------------------------------------------------------------------+
void DrawLevel(string name, double price, color clr, int style, int width = 1)
{
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
void ClearLevel(string name)
{
   if(ObjectFind(0, name) >= 0) {
      ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
//| Add LL sign to tracking array                                    |
//+------------------------------------------------------------------+
void AddLLSign(double price, datetime time, int barIndex)
{
   // Shift existing signs
   if(llSignCount >= 3) {
      llSigns[0] = llSigns[1];
      llSigns[1] = llSigns[2];
      llSignCount = 2;
   }
   
   if(llSigns[llSignCount].price == price && llSigns[llSignCount].valid) {
      //Print(__FUNCTION__+" Duplicate LL sign detected - ignoring");
      return;
   }
   // Add new LL sign
   llSigns[llSignCount].price = price;
   llSigns[llSignCount].time = time;
   llSigns[llSignCount].barIndex = barIndex;
   llSigns[llSignCount].valid = true;
   llSignCount++;
   
   //Print(__FUNCTION__+"LL sign added: ", llSignCount, " total | Price: ", price);
}

//+------------------------------------------------------------------+
//| Check LL Reversal Strategy conditions                            |
//+------------------------------------------------------------------+
void CheckLLReversalStrategy()
{
   if(llSignCount < 2)
      return;  // Need at least 2 LL signs
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Get the most recent two LL signs
   LLSign firstLL = llSigns[llSignCount - 2];
   LLSign secondLL = llSigns[llSignCount - 1];
   
   if(!firstLL.valid || !secondLL.valid)
      return;
   
   // Check candle distance
   int candleDistance = MathAbs(secondLL.barIndex - firstLL.barIndex);
   if(candleDistance > InpLLCandleRange) {
      //Print(__FUNCTION__+" LL signs too far apart in candles: ", candleDistance);
      return;
   }
   
   // Check point distance
   double pointDistance = MathAbs(secondLL.price - firstLL.price) / _Point;
   if(pointDistance > InpLLPointRange) {
      //Print(__FUNCTION__+" LL signs too far apart in points: ", pointDistance);
      return;
   }
   
   //Print(__FUNCTION__+" Valid LL pattern detected | Candles: ", candleDistance, " | Points: ", pointDistance);
   
   // Condition for 2 LL signs
   if(llSignCount == 2) {
      // Check if price is below both LLs - ignore
      if(currentPrice < firstLL.price && currentPrice < secondLL.price) {
         //Print(__FUNCTION__+" Price below both LLs - ignoring pattern");
         return;
      }
      
      // If price above BOTH LLs and within range, place instant MARKET order
      double maxLL = MathMax(firstLL.price, secondLL.price);
      if(currentPrice > firstLL.price && currentPrice > secondLL.price) {
         // Check if price is within range from highest LL
         double priceDistanceFromMax = (currentPrice - maxLL) / _Point;
         PrintFormat("Position count: %d", CountOpenPositions());
         
         if(priceDistanceFromMax <= InpLLPointRange && !reversalTradeActive && CountOpenPositions() <= InpMaxSimultaneousTrades) {
            //Print(__FUNCTION__+" Price above both LLs and within range (", priceDistanceFromMax, " points) - INSTANT MARKET BUY");
            if(LL_counter < 5)
               ExecuteBuyTrade();
            //---
            reversalTradeActive = true;
         } else if(priceDistanceFromMax > InpLLPointRange) {
            //Print(__FUNCTION__+" Price too far from LLs (", priceDistanceFromMax, " points) - ignoring");
         }
      }
   }
   
   // Condition for 3 LL signs
   if(llSignCount == 3) {
      LLSign thirdLL = llSigns[2];
       
      // Check if all three are within range
      double maxPrice = MathMax(MathMax(firstLL.price, secondLL.price), thirdLL.price);
      double minPrice = MathMin(MathMin(firstLL.price, secondLL.price), thirdLL.price);
      double threeSignRange = (maxPrice - minPrice) / _Point;
      
      if(threeSignRange <= InpLLPointRange) {
         //Print(__FUNCTION__+" Three LL signs within range (", threeSignRange, " points)");
         PrintFormat("Total Positions: %d", CountOpenPositions());
         // If position already exists from 2-LL, place SECOND BUY order
         if(reversalTradeActive && LL_counter < 3 && CountOpenPositions() <= InpMaxSimultaneousTrades) {
            //Print(__FUNCTION__+" First position exists - Placing SECOND MARKET BUY on third LL");
            ExecuteBuyTrade();
         }
         
         // Remember key level (average of three LLs)
         if(LL_keyLevel == 0.0) {
            LL_keyLevel = (firstLL.price + secondLL.price + thirdLL.price) / 3.0;
            isLLkeyInvalid = false;
            //Print(__FUNCTION__+" Key LL level set at ", LL_keyLevel);
         }
         
         // Draw key level
         DrawLevel("LL_REVERSAL_KeyLevel", LL_keyLevel, clrGold, STYLE_SOLID, 3);
         
         // Reset LL tracking
         llSignCount = 0;
         for(int i = 0; i < 3; i++) {
            llSigns[i].valid = false;
         }
         reversalTradeActive = false;
      }
   }
}
//+------------------------------------------------------------------+
//| Check HH Reversal Strategy conditions (uptrend reversal → SELL) |
//+------------------------------------------------------------------+
void CheckHHReversalStrategy()
{
   if(hhSignCount < 2)
      return;  // Need at least 2 HH signs
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Get the most recent two HH signs
   HHSign firstHH = hhSigns[hhSignCount - 2];
   HHSign secondHH = hhSigns[hhSignCount - 1];
   
   if(!firstHH.valid || !secondHH.valid)
      return;
   
   // Check candle distance
   int candleDistance = MathAbs(secondHH.barIndex - firstHH.barIndex);
   if(candleDistance > InpHHCandleRange) {
      //Print(__FUNCTION__+"HH signs too far apart in candles: ", candleDistance);
      return;
   }
   
   // Check point distance
   double pointDistance = MathAbs(secondHH.price - firstHH.price) / _Point;
   if(pointDistance > InpHHPointRange) {
      //Print(__FUNCTION__+"HH signs too far apart in points: ", pointDistance);
      return;
   }
   
   //Print(__FUNCTION__+"Valid HH pattern detected | Candles: ", candleDistance, " | Points: ", pointDistance);
   
   // Condition for 2 HH signs
   if(hhSignCount == 2) {
      // Check if price is ABOVE both HHs - ignore
      if(currentPrice > firstHH.price && currentPrice > secondHH.price) {
         //Print(__FUNCTION__+"Price above both HHs - ignoring pattern");
         return;
      }
      
      // If price BELOW BOTH HHs and within range, place instant MARKET SELL order
      double minHH = MathMin(firstHH.price, secondHH.price);
      if(currentPrice < firstHH.price && currentPrice < secondHH.price) {
         // Check if price is within range from lowest HH
         double priceDistanceFromMin = (minHH - currentPrice) / _Point;
         int total_pos = PositionsTotal();
         
         if(priceDistanceFromMin <= InpHHPointRange && !reversalTradeActiveHH && total_pos < InpMaxSimultaneousTrades) {
            //Print(__FUNCTION__+"Price below both HHs and within range (", priceDistanceFromMin, " points) - INSTANT MARKET SELL");
            if(HH_counter < 6)
               ExecuteSellTrade();
            //---
            reversalTradeActiveHH = true;
         } else if(priceDistanceFromMin > InpHHPointRange) {
            //Print(__FUNCTION__+"Price too far from HHs (", priceDistanceFromMin, " points) - ignoring");
         }
      }
   }
   
   // Condition for 3 HH signs
   if(hhSignCount == 3) {
      HHSign thirdHH = hhSigns[2];
      
      // Check if all three are within range
      double maxPrice = MathMax(MathMax(firstHH.price, secondHH.price), thirdHH.price);
      double minPrice = MathMin(MathMin(firstHH.price, secondHH.price), thirdHH.price);
      double threeSignRange = (maxPrice - minPrice) / _Point;
      
      if(threeSignRange <= InpHHPointRange) {
         //Print(__FUNCTION__+"Three HH signs within range (", threeSignRange, " points)");
         
         // If position already exists from 2-HH, place SECOND SELL order
         if(reversalTradeActiveHH && HH_counter < 3 && CountOpenPositions() <= InpMaxSimultaneousTrades) {
            //Print(__FUNCTION__+"First position exists - Placing SECOND MARKET SELL on third HH");
            ExecuteSellTrade();
         }
         
         // Remember key level (average of three HHs)
         if(HH_keyLevel == 0.0) {
            HH_keyLevel = (firstHH.price + secondHH.price + thirdHH.price) / 3.0;
            isHHkeyInvalid = false;
            //Print(__FUNCTION__+"Key HH level set at ", HH_keyLevel);
         }
         
         // Draw key level
         DrawLevel("HH_REVERSAL_KeyLevel", HH_keyLevel, clrOrange, STYLE_SOLID, 3);
         
         // Reset HH tracking
         hhSignCount = 0;
         for(int i = 0; i < 3; i++) {
            hhSigns[i].valid = false;
         }
         reversalTradeActiveHH = false;
      }
   }
}
//+------------------------------------------------------------------+
void CheckPosition(string positionType)
{
   //--- Set new TP to breakeven with profit half from R:R(if TP set to 0), else follow input TP point / 2
   double new_TP = 0.0;
   //--- Set new SL to half of original SL
   double new_SL = 0.0;
   //---
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      
      string posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "LONG" : "SHORT";
      if(positionType == "LONG") {
         new_TP = PositionGetDouble(POSITION_PRICE_OPEN) + 
                  (PositionGetDouble(POSITION_PRICE_OPEN) - PositionGetDouble(POSITION_SL)) * 0.5;
         new_SL = PositionGetDouble(POSITION_SL);
      } else if(positionType == "SHORT") {
         new_TP = PositionGetDouble(POSITION_PRICE_OPEN) - 
                  (PositionGetDouble(POSITION_SL) - PositionGetDouble(POSITION_PRICE_OPEN)) * 0.5;
         new_SL = PositionGetDouble(POSITION_SL);
      }
      //--- Modify position TP
      if(positionType == posType) {
         if(trade.PositionModify(ticket, new_SL, new_TP)) {
            //Print(__FUNCTION__+"Position TP and SL modified to new levels | TP: ", new_TP, " | SL: ", new_SL);
         } else {
            //Print(__FUNCTION__+"Failed to modify position: ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Place pending BUY limit order                                    |
//+------------------------------------------------------------------+
// void PlacePendingBuyLimit(double price, int barIndex)
// {
//    // Check if order already exists
//    if(pendingOrderTicket > 0) {
//       if(OrderSelect(pendingOrderTicket)) {
//          Print(__FUNCTION__+"Pending order already exists");
//          return;
//       } else {
//          pendingOrderTicket = 0;  // Order no longer exists
//       }
//    }
   
//    // Store entry candle info for later TP calculation
//    double candleOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
//    double candleClose = iClose(_Symbol, PERIOD_CURRENT, barIndex);
//    entryCandleSize = MathAbs(candleClose - candleOpen) / _Point;
//    entryBarIndex = barIndex;
   
//    double sl = price - InpLLPointRange * _Point;  // SL below the pattern
//    double tp = 0;  // No TP initially, set after candle closes if enabled
   
//    Print(__FUNCTION__+"Entry candle size: ", entryCandleSize, " points");
   
//    if(trade.BuyLimit(InpReversalLotSize, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "LL_Reversal_Limit")) {
//       pendingOrderTicket = trade.ResultOrder();
//       Print(__FUNCTION__+"Pending BUY LIMIT placed at ", price, " | SL: ", sl, " | No TP (will set after close)");
//    } else {
//       Print(__FUNCTION__+"Failed to place pending order: ", trade.ResultRetcodeDescription());
//    }
// }

//+------------------------------------------------------------------+
//| Place market BUY order                                           |
//+------------------------------------------------------------------+
// void PlaceMarketBuy()
// {
//    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
//    double sl = currentPrice - InpLLPointRange * _Point;
//    double tp = currentPrice + (currentPrice - sl) * InpRiskRewardRatio;
   
//    if(trade.Buy(InpReversalLotSize, _Symbol, currentPrice, sl, tp, "LL_Reversal_Market")) {
//       Print(__FUNCTION__+"MARKET BUY executed at ", currentPrice, " | Third LL reversal");
      
//       // Draw entry arrow
//       ObjectCreate(0, "REVERSAL_Entry_" + IntegerToString(TimeCurrent()), OBJ_ARROW_BUY, 0, TimeCurrent(), currentPrice);
//       ObjectSetInteger(0, "REVERSAL_Entry_" + IntegerToString(TimeCurrent()), OBJPROP_COLOR, clrLime);
//       ObjectSetInteger(0, "REVERSAL_Entry_" + IntegerToString(TimeCurrent()), OBJPROP_WIDTH, 3);
//    } else {
//       Print(__FUNCTION__+"Failed to place market BUY: ", trade.ResultRetcodeDescription());
//    }
// }

//+------------------------------------------------------------------+
//| Manage TP for reversal positions                                 |
//+------------------------------------------------------------------+
void ManageReversalTP()
{
   if(!InpSetTPAfterClose)
      return;  // TP management disabled
   
   // Check if we have a reversal position without TP
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "LL_Reversal") < 0)
         continue;  // Not a reversal trade
      
      double currentTP = PositionGetDouble(POSITION_TP);
      if(currentTP > 0)
         continue;  // TP already set
      
      // Check if entry candle has closed
      if(entryBarIndex >= 0 && iTime(_Symbol, PERIOD_CURRENT, 0) != iTime(_Symbol, PERIOD_CURRENT, entryBarIndex)) {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp;
         
         if(InpUseCandleBasedTP) {
            // TP = entry + (candle size * 2)
            tp = entryPrice + (entryCandleSize * 2 * _Point);
            //Print(__FUNCTION__+"Setting candle-based TP: ", entryCandleSize, " * 2 = ", entryCandleSize * 2, " points");
         } else {
            // TP = entry + (SL distance * R:R)
            double slDistance = MathAbs(entryPrice - sl);
            tp = entryPrice + (slDistance * InpRiskRewardRatio);
            //Print(__FUNCTION__+"Setting R:R based TP: ", InpRiskRewardRatio, " ratio");
         }
         
         if(trade.PositionModify(ticket, sl, tp)) {
            //Print(__FUNCTION__+"TP set for reversal position at ", tp);
            entryBarIndex = -1;  // Reset
         } else {
            //Print(__FUNCTION__+"Failed to modify position TP: ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add HH sign to tracking array                                    |
//+------------------------------------------------------------------+
void AddHHSign(double price, datetime time, int barIndex)
{
   // Shift existing signs
   if(hhSignCount >= 3) {
      hhSigns[0] = hhSigns[1];
      hhSigns[1] = hhSigns[2];
      hhSignCount = 2;
   }
   
   // Add new HH sign
   hhSigns[hhSignCount].price = price;
   hhSigns[hhSignCount].time = time;
   hhSigns[hhSignCount].barIndex = barIndex;
   hhSigns[hhSignCount].valid = true;
   hhSignCount++;
   
   //Print(__FUNCTION__+"HH sign added: ", hhSignCount, " total | Price: ", price);
}


//+------------------------------------------------------------------+
//| Place pending SELL limit order                                   |
//+------------------------------------------------------------------+
// void PlacePendingSellLimit(double price, int barIndex)
// {
//    // Check if order already exists
//    if(pendingOrderTicketHH > 0) {
//       if(OrderSelect(pendingOrderTicketHH)) {
//          Print(__FUNCTION__+"Pending SELL order already exists");
//          return;
//       } else {
//          pendingOrderTicketHH = 0;  // Order no longer exists
//       }
//    }
   
//    // Store entry candle info for later TP calculation
//    double candleOpen = iOpen(_Symbol, PERIOD_CURRENT, barIndex);
//    double candleClose = iClose(_Symbol, PERIOD_CURRENT, barIndex);
//    entryCandleSizeHH = MathAbs(candleClose - candleOpen) / _Point;
//    entryBarIndexHH = barIndex;
   
//    double sl = price + InpHHPointRange * _Point;  // SL above the pattern
//    double tp = 0;  // No TP initially, set after candle closes if enabled
   
//    Print(__FUNCTION__+"Entry candle size (HH): ", entryCandleSizeHH, " points");
   
//    if(trade.SellLimit(InpReversalLotSize, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "HH_Reversal_Limit")) {
//       pendingOrderTicketHH = trade.ResultOrder();
//       Print(__FUNCTION__+"Pending SELL LIMIT placed at ", price, " | SL: ", sl, " | No TP (will set after close)");
//    } else {
//       Print(__FUNCTION__+"Failed to place pending SELL order: ", trade.ResultRetcodeDescription());
//    }
// }

//+------------------------------------------------------------------+
//| Manage TP for HH reversal positions                              |
//+------------------------------------------------------------------+
void ManageReversalTPHH()
{
   if(!InpSetTPAfterClose)
      return;  // TP management disabled
   
   // Check if we have a HH reversal position without TP
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "HH_Reversal") < 0)
         continue;  // Not a HH reversal trade
      
      double currentTP = PositionGetDouble(POSITION_TP);
      if(currentTP > 0)
         continue;  // TP already set
      
      // Check if entry candle has closed
      if(entryBarIndexHH >= 0 && iTime(_Symbol, PERIOD_CURRENT, 0) != iTime(_Symbol, PERIOD_CURRENT, entryBarIndexHH)) {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp;
         
         if(InpUseCandleBasedTP) {
            // TP = entry - (candle size * 2)
            tp = entryPrice - (entryCandleSizeHH * 2 * _Point);
            //Print(__FUNCTION__+"Setting candle-based TP (HH): ", entryCandleSizeHH, " * 2 = ", entryCandleSizeHH * 2, " points");
         } else {
            // TP = entry - (SL distance * R:R)
            double slDistance = MathAbs(sl - entryPrice);
            tp = entryPrice - (slDistance * InpRiskRewardRatio);
            //Print(__FUNCTION__+"Setting R:R based TP (HH): ", InpRiskRewardRatio, " ratio");
         }
         
         if(trade.PositionModify(ticket, sl, tp)) {
            //Print(__FUNCTION__+"TP set for HH reversal position at ", tp);
            entryBarIndexHH = -1;  // Reset
         } else {
            //Print(__FUNCTION__+"Failed to modify HH position TP: ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if ticket already partially closed                         |
//+------------------------------------------------------------------+
bool IsTicketPartiallyClosed(ulong ticket)
{
   int size = ArraySize(partiallyClosedTickets);
   for(int i = 0; i < size; i++) {
      if(partiallyClosedTickets[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add ticket to partially closed list                              |
//+------------------------------------------------------------------+
void AddPartiallyClosedTicket(ulong ticket)
{
   int size = ArraySize(partiallyClosedTickets);
   ArrayResize(partiallyClosedTickets, size + 1);
   partiallyClosedTickets[size] = ticket;
}

//+------------------------------------------------------------------+
//| Check and execute partial closure based on conditions            |
//+------------------------------------------------------------------+
void CheckPartialClosure()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      // Skip if already partially closed
      if(IsTicketPartiallyClosed(ticket))
         continue;
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      bool shouldClose = false;
      string reason = "";
      
      // Check floating LOSS conditions
      if(profit < 0) {
         double loss = MathAbs(profit);
         
         // Check loss as % of balance
         if(InpUseFloatingLossPct) {
            double lossPct = (loss / balance) * 100.0;
            if(lossPct >= InpFloatingLossPct) {
               shouldClose = true;
               reason = "Loss " + DoubleToString(lossPct, 2) + "% of balance";
            }
         }
         
         // Check loss as currency amount
         if(!shouldClose && InpUseFloatingLossAmount) {
            if(loss >= InpFloatingLossAmount) {
               shouldClose = true;
               reason = "Loss $" + DoubleToString(loss, 2);
            }
         }
         
         // Check loss in points
         if(!shouldClose && InpUseFloatingLossPoints) {
            double lossPoints = MathAbs(currentPrice - openPrice) / _Point;
            if(lossPoints >= InpFloatingLossPoints) {
               shouldClose = true;
               reason = "Loss " + DoubleToString(lossPoints, 0) + " points";
            }
         }
      }
      
      // Check floating PROFIT conditions
      if(!shouldClose && profit > 0) {
         // Check profit as % of balance
         if(InpUseFloatingProfitPct) {
            double profitPct = (profit / balance) * 100.0;
            if(profitPct >= InpFloatingProfitPct) {
               shouldClose = true;
               reason = "Profit " + DoubleToString(profitPct, 2) + "% of balance";
            }
         }
         
         // Check profit as currency amount
         if(!shouldClose && InpUseFloatingProfitAmount) {
            if(profit >= InpFloatingProfitAmount) {
               shouldClose = true;
               reason = "Profit $" + DoubleToString(profit, 2);
            }
         }
         
         // Check profit in points
         if(!shouldClose && InpUseFloatingProfitPoints) {
            double profitPoints = MathAbs(currentPrice - openPrice) / _Point;
            if(profitPoints >= InpFloatingProfitPoints) {
               shouldClose = true;
               reason = "Profit " + DoubleToString(profitPoints, 0) + " points";
            }
         }
      }
      
      // Execute partial closure
      if(shouldClose) {
         double closeVolume = volume * (InpPartialClosePercent / 100.0);
         
         // Round to lot step
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
         
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(closeVolume < minLot) {
            //Print(__FUNCTION__+"Close volume too small: ", closeVolume, " | Min: ", minLot);
            continue;
         }
         
         // Ensure we don't close more than available
         if(closeVolume >= volume) {
            closeVolume = volume - lotStep;  // Leave minimum
            if(closeVolume < minLot)
               closeVolume = volume;  // Close all if can't leave remainder
         }
         
         //Print(__FUNCTION__+"Partial close triggered: ", reason, " | Closing ", 
         //       DoubleToString(InpPartialClosePercent, 1), "% (", closeVolume, " lots)");
         
         // if(trade.PositionClosePartial(ticket, closeVolume)) {
         //    //Print(__FUNCTION__+"Partial closure successful | Ticket: ", ticket, 
         //          " | Closed: ", closeVolume, " | Remaining: ", volume - closeVolume);
         //    AddPartiallyClosedTicket(ticket);
         // } else {
         //    //Print(__FUNCTION__+"Partial closure failed: ", trade.ResultRetcodeDescription());
         // }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw trend structure label (HH, HL, LH, LL)                      |
//+------------------------------------------------------------------+
void DrawTrendLabel(string name, double price, datetime time, string text, color clr)
{
   if(ObjectFind(0, name) >= 0)
      return;  // Already exists
   
   // Create text label
   if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price)) {
      ObjectSetString(0, name, OBJPROP_TEXT, " ✓ " + text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//| Update chart information display                                 |
//+------------------------------------------------------------------+
void UpdateChartInfo()
{
   string info = "\n=== BOS Pullback EA ===\n";
   info += "Last Swing High: " + DoubleToString(lastSwingHigh.price, _Digits) + "\n";
   info += "Last Swing Low: " + DoubleToString(lastSwingLow.price, _Digits) + "\n";
   
   // Show trend state
   string trendText = "NONE/RANGING";
   color trendColor = clrGray;
   if(currentTrend == TREND_UP) {
      trendText = "UPTREND (HH + HL)";
      trendColor = clrDeepSkyBlue;
   } else if(currentTrend == TREND_DOWN) {
      trendText = "DOWNTREND (LH + LL)";
      trendColor = clrRed;
   }
   info += "Current Trend: " + trendText + "\n";
   
   if(waitingForPullback) {
      info += "\n--- WAITING FOR PULLBACK ---\n";
      info += "Type: " + (bullishBOS ? "BULLISH" : "BEARISH") + "\n";
      info += "BOS Level: " + DoubleToString(bosLevel, _Digits) + "\n";
      info += "Pullback Target: " + DoubleToString(pullbackLevel, _Digits) + "\n";
   } else {
      info += "\nScanning for Break of Structure...\n";
   }
   
   info += "\nOpen Positions: " + IntegerToString(CountOpenPositions()) + " / " + IntegerToString(InpMaxSimultaneousTrades);
   
   Comment(info);
}
//+------------------------------------------------------------------+
