//+------------------------------------------------------------------+
//|                                             Profit_Generator.mq5 |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 27.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"
#property version   "1.00"
#property description "Profit Generator - Expert based on defined strategies"
//---
#include "Functions.mqh"
#include "Display.mqh"
//---
//---

//#region Main EA Code

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Print("══════════════════════════════════════════════════");
   // Print("SR Breakout EA - Initialization Started");
   // Print("══════════════════════════════════════════════════");
//---
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

   InitPivotPoints();

   // Initialize BOS
   BOS.price = 0.0;
   BOS.time = 0;
   BOS.isBullish = false;
   BOS.isActive = false;
   BOS.barIndex = 0;

   // Initialize boxes array
   ArrayResize(g_Boxes, MAX_BOXES);
   g_BoxCount = 0;
   
   g_PointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_Digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   
   // Print("Symbol: ", _Symbol);
   // Print("Chart Period: ", EnumToString(PERIOD_CURRENT));
   // Print("Trend Analysis Timeframe: ", EnumToString(InpTrendTF));
   // Print("Swing Analysis Timeframe: ", EnumToString(InpSwingTF));
   // Print("Support & Resistance Analysis Timeframe: ", EnumToString(InpSnRTF));
   // Print("Low Timeframe for BOS Detection: ", EnumToString(InpLowTF));
   // // Print("Magic Number: ", InpMagicNumber);
   // Print("Point Value: ", g_PointValue);
   // Print("Digits: ", g_Digits);
   // int lookback = InpPivotLeftBars + InpPivotRightBars;
   // Print("Pivot Lookback Period: ", lookback);
   // Print("Pivot Left Bars: ", InpPivotLeftBars);
   // Print("Pivot Right Bars: ", InpPivotRightBars);
   // Print("Volume Filter Length: ", InpVolFilterLen);
   // Print("Box Width Multiplier: ", InpBoxWidth);
   // Print("Trade Breakouts: ", InpTradeBreakouts);
   // Print("Trade Retests: ", InpTradeRetests);
   // Print("Buy Signals Enabled: ", InpBuySignals);
   // Print("Sell Signals Enabled: ", InpSellSignals);
   // Print("Enable Scalping Mode: ", InpEnableScalping);
   // // Print("Lot Size: ", InpLotSize);
   // // Print("Stop Loss: ", InpStopLossPips, " pips");
   // // Print("Take Profit: ", InpTakeProfitPips, " pips");
   // Print("══════════════════════════════════════════════════");
   // Print("✓ SR Breakout EA Initialized Successfully");
   // Print("══════════════════════════════════════════════════");
//---
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//---
   DeleteAllAnalysisObjects();
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
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == g_LastBarTime)
      return;
   
   g_LastBarTime = currentBarTime;

   // Print("\n──────────────────────────────────────────────────");
   // Print("⏰ New "+EnumToString(PERIOD_CURRENT)+" Bar Detected: ", TimeToString(currentBarTime, TIME_DATE|TIME_MINUTES));
   // Print("──────────────────────────────────────────────────");

   // Update analysis
   AnalyzePivotPoints(PERIOD_W1, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   AnalyzePivotPoints(InpTrendTF, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   AnalyzePivotPoints(InpSwingTF, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   AnalyzePivotPoints(InpLowTF, L_LastHigh, L_PrevHigh, L_LastLow, L_PrevLow);
   
   // Determine trend for each timeframe
   W_Trend = DetermineTrend(PERIOD_W1, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   D_Trend = DetermineTrend(InpTrendTF, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   swH_Trend = DetermineTrend(InpSwingTF, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   
   // Determine market conditions
   W_MarketCondition = DetermineMarketCondition(W_Trend, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   D_MarketCondition = DetermineMarketCondition(D_Trend, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   swH_MarketCondition = DetermineMarketCondition(swH_Trend, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   
   // Determine trading strategies
   W_Strategy = DetermineTradingStrategy(W_Trend, W_MarketCondition, W_SecondaryStrategy);
   D_Strategy = DetermineTradingStrategy(D_Trend, D_MarketCondition, D_SecondaryStrategy);
   swH_Strategy = DetermineTradingStrategy(swH_Trend, swH_MarketCondition, swH_SecondaryStrategy);
   
   // Display all analysis on chart
   DisplayAllTimeframesAnalysis();

   // Analyze previous levels to catch any missed boxes
   AnalyzePreviousLevels(InpSnRTF, InpLookbackPeriod);
   
   // Print("🔍 Starting Support & Resistance analysis on timeframe: ", EnumToString(InpSnRTF), "...");
   AnalyzeLevels(InpSnRTF, InpLookbackPeriod);
   
   // Update box visibility based on settings
   UpdateBoxVisibility();
   
   // Print("✓ Analysis complete\n");

   // Handle BOS invalidation when new swing high/low detected on low timeframe
   if(swH_LastHigh.isValid)
   {
      // Close all BUY positions when new swing high is detected (if enabled)
      if(InpCloseOnNewSwing)
         CloseAllPositions(POSITION_TYPE_BUY);
      
      // Invalidate existing BOS when new swing high is detected
      if(BOS.isActive && !BOS.isBullish)
      {
         Print("New Swing High detected - Invalidating existing bearish BOS");
         BOS.isActive = false;
         waitingForPullback = false;
         ObjectDelete(0, "BOS_Level");
      }
   }
   
   if(swH_LastLow.isValid)
   {
      // Close all SELL positions when new swing low is detected (if enabled)
      if(InpCloseOnNewSwing)
         CloseAllPositions(POSITION_TYPE_SELL);
      
      // Invalidate existing BOS when new swing low is detected
      if(BOS.isActive && BOS.isBullish)
      {
         Print("New Swing Low detected - Invalidating existing bullish BOS");
         BOS.isActive = false;
         waitingForPullback = false;
         ObjectDelete(0, "BOS_Level");
      }
   }
   
   // Check for BOS on low timeframe
   if(!waitingForPullback)
   {
      CheckForBOS();
   }
   
   // Check for pullback entry
   if(waitingForPullback && BOS.isActive)
   {
      ExtendBOSLevel(currentBarTime, BOS.price);
      CheckForEntry();
   }
}
//#endregion
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for Break of Structure on Low Timeframe                    |
//+------------------------------------------------------------------+
void CheckForBOS()
{
   if(!L_LastHigh.isValid || !L_LastLow.isValid)
      return;
   
   double currentClose = iClose(_Symbol, InpLowTF, 0);
   
   // When InpEnableSupertrend is enabled
   if(InpEnableSupertrend)
   {
      // If swing trend is sideways, check daily trend
      if(swH_Trend == TREND_SIDEWAYS)
      {
         // Only proceed if daily trend is clear and strong
         if(D_MarketCondition != CLEAR_AND_STRONG_TREND)
            return;
            
         // Use daily trend direction instead
         if(D_Trend == TREND_BEARISH && InpTradeDirection != TRADE_BUY_ONLY)
         {
            // Bearish BOS: Price breaks below most recent swing low
            if(L_LastLow.isValid)
            {
               if(currentClose < L_LastLow.price && !BOS.isActive)
               {
                  BOS.price = L_LastLow.price;
                  BOS.time = TimeCurrent();
                  BOS.isBullish = false;
                  BOS.isActive = true;
                  BOS.barIndex = 0;
                  waitingForPullback = true;
                  
                  Print("Bearish BOS detected at ", BOS.price, " (Swing: SIDEWAYS, Daily Trend: BEARISH)");
                  DrawBOSLevel(BOS.price, BOS.time, false);
               }
            }
         }
         else if(D_Trend == TREND_BULLISH && InpTradeDirection != TRADE_SELL_ONLY)
         {
            // Bullish BOS: Price breaks above most recent swing high
            if(L_LastHigh.isValid)
            {
               if(currentClose > L_LastHigh.price && !BOS.isActive)
               {
                  BOS.price = L_LastHigh.price;
                  BOS.time = TimeCurrent();
                  BOS.isBullish = true;
                  BOS.isActive = true;
                  BOS.barIndex = 0;
                  waitingForPullback = true;
                  
                  Print("Bullish BOS detected at ", BOS.price, " (Swing: SIDEWAYS, Daily Trend: BULLISH)");
                  DrawBOSLevel(BOS.price, BOS.time);
               }
            }
         }
         else
         {
            // Daily trend is also sideways or undecided - no BOS
            return;
         }
      }
      // Swing trend is clear (not sideways)
      else if(swH_Trend == TREND_BEARISH && InpTradeDirection != TRADE_BUY_ONLY)
      {
         // Bearish BOS: Price breaks below most recent swing low
         if(L_LastLow.isValid)
         {
            if(currentClose < L_LastLow.price && !BOS.isActive)
            {
               BOS.price = L_LastLow.price;
               BOS.time = TimeCurrent();
               BOS.isBullish = false;
               BOS.isActive = true;
               BOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bearish BOS detected at ", BOS.price, " (HTF Trend: BEARISH)");
               DrawBOSLevel(BOS.price, BOS.time, false);
            }
         }
      }
      // Check for BULLISH BOS when trend is bullish
      else if(swH_Trend == TREND_BULLISH && InpTradeDirection != TRADE_SELL_ONLY)
      {
         // Bullish BOS: Price breaks above most recent swing high
         if(L_LastHigh.isValid)
         {
            if(currentClose > L_LastHigh.price && !BOS.isActive)
            {
               BOS.price = L_LastHigh.price;
               BOS.time = TimeCurrent();
               BOS.isBullish = true;
               BOS.isActive = true;
               BOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bullish BOS detected at ", BOS.price, " (HTF Trend: BULLISH)");
               DrawBOSLevel(BOS.price, BOS.time);
            }
         }
      }
   }
   // When InpEnableSupertrend is disabled - BOS follows last HTF swing point
   else
   {
      // If last HTF swing was HIGH, look for BEARISH BOS
      if(lastSwingWasHigh && InpTradeDirection != TRADE_BUY_ONLY)
      {
         // Bearish BOS: Price breaks below most recent swing low
         if(L_LastLow.isValid)
         {
            if(currentClose < L_LastLow.price && !BOS.isActive)
            {
               BOS.price = L_LastLow.price;
               BOS.time = TimeCurrent();
               BOS.isBullish = false;
               BOS.isActive = true;
               BOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bearish BOS detected at ", BOS.price, " (Last HTF swing was HIGH)");
               DrawBOSLevel(BOS.price, BOS.time, false);
            }
         }
      }
      // If last HTF swing was LOW, look for BULLISH BOS
      else if(!lastSwingWasHigh && InpTradeDirection != TRADE_SELL_ONLY)
      {
         // Bullish BOS: Price breaks above most recent swing high
         if(L_LastHigh.isValid)
         {
            if(currentClose > L_LastHigh.price && !BOS.isActive)
            {
               BOS.price = L_LastHigh.price;
               BOS.time = TimeCurrent();
               BOS.isBullish = true;
               BOS.isActive = true;
               BOS.barIndex = 0;
               waitingForPullback = true;
               
               Print("Bullish BOS detected at ", BOS.price, " (Last HTF swing was LOW)");
               DrawBOSLevel(BOS.price, BOS.time);
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
   if(BOS.isBullish && waitingForPullback)
   {
      // Check trend alignment if supertrend filter is enabled
      if(checkTrend)
      {
         // If swing trend is sideways, check daily trend
         if(swH_Trend == TREND_SIDEWAYS)
         {
            // Only proceed if daily trend is bullish and market is clear
            if(D_Trend != TREND_BULLISH || D_MarketCondition != CLEAR_AND_STRONG_TREND)
               return;
         }
         // If swing trend is not sideways, it must be bullish
         else if(swH_Trend != TREND_BULLISH)
            return;
      }
      
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
      double distancePoints = MathAbs(currentPrice - BOS.price) / point;
      
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
   else if(!BOS.isBullish && waitingForPullback)
   {
      // Check trend alignment if supertrend filter is enabled
      if(checkTrend)
      {
         // If swing trend is sideways, check daily trend
         if(swH_Trend == TREND_SIDEWAYS)
         {
            // Only proceed if daily trend is bearish and market is clear
            if(D_Trend != TREND_BEARISH || D_MarketCondition != CLEAR_AND_STRONG_TREND)
               return;
         }
         // If swing trend is not sideways, it must be bearish
         else if(swH_Trend != TREND_BEARISH)
            return;
      }
      
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
      double distancePoints = MathAbs(currentPrice - BOS.price) / point;
      
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
      // Use ATR-based SL
      double atr = CalculateATR(200, 0, InpSwingTF);
      sl = NormalizeDouble(ask - atr * 1.5, _Digits);
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      tp = ask + InpTakeProfit * pipSize;
   }
   else
   {
      // Try to use HTF swing high as TP target
      if(swH_PrevHigh.isValid)
      {
         tp = swH_PrevHigh.price - 50 * _Point;
         // Validate: TP must be above entry price for BUY
         if(tp <= ask)
         {
            Print("Warning: swing previous high (", swH_PrevHigh.price, ") is at or below entry price. Using default 50 pips TP.");
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
      BOS.isActive = false;
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
      // Use ATR-based SL
      double atr = CalculateATR(200, 0, InpSwingTF);
      sl = NormalizeDouble(bid + atr * 1.5, _Digits);
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      tp = bid - InpTakeProfit * pipSize;
   }
   else
   {
      if(swH_PrevLow.isValid)
      {
         tp = swH_PrevLow.price + 50 * _Point;
         // Validate: TP must be below entry price for SELL
         if(tp >= bid)
         {
            Print("Warning: swing previous low (", swH_PrevLow.price, ") is at or above entry price. Using default 50 pips TP.");
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
      BOS.isActive = false;
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
         // Check if trailing has started (price reached swH_LastHigh)
         bool trailingStarted = swH_LastHigh.isValid && currentPrice >= swH_LastHigh.price;
         
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
            // Trailing not started yet - update SL to swH_LastLow if it's better
            if(swH_LastLow.isValid)
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
                  newSL = NormalizeDouble(swH_LastLow.price - 50 * _Point, _Digits);
               }
            }
         }
      }
      else // POSITION_TYPE_SELL
      {
         // Check if trailing has started (price reached swH_LastLow)
         bool trailingStarted = swH_LastLow.isValid && currentPrice <= swH_LastLow.price;
         
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
            // Trailing not started yet - update SL to swH_LastHigh if it's better
            if(swH_LastHigh.isValid)
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
                  newSL = NormalizeDouble(swH_LastHigh.price + 50 * _Point, _Digits);
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
   double profitTarget = InpInitialBalance * InpProfitTargetPct / 100.0;
   
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
