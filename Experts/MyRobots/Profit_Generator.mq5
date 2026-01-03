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
// #include "Functions_SnR_BOS.mqh"
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
   // Initialize logging
   log_file = INVALID_HANDLE;
   acc_login = (int)account.Login();
   expert_folder = "PG_Logs";
   work_folder = expert_folder+"\\"+CurrentAccountInfo(account.Server())+"_"+IntegerToString(acc_login);
   log_fileName = "\\Log_"+RemoveDots(TimeToString(DateToString(), TIME_DATE))+".log";
   common_folder = false;
   silent_log = InpSilentLogging;

   // Initialize trade object (magic number will be set dynamically per trade)
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
   


   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime == g_LastBarTime)
      return;
   
   g_LastBarTime = currentBarTime;

   // Print("\n──────────────────────────────────────────────────");
   // Print("⏰ New "+EnumToString(PERIOD_CURRENT)+" Bar Detected: ", TimeToString(currentBarTime, TIME_DATE|TIME_MINUTES));
   // Print("──────────────────────────────────────────────────");

   // Update analysis
   // AnalyzePivotPoints(PERIOD_W1, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   AnalyzePivotPoints(InpTrendTF, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   AnalyzePivotPoints(InpSwingTF, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   AnalyzePivotPoints(InpSnRTF, snrH_LastHigh, snrH_PrevHigh, snrH_LastLow, snrH_PrevLow);
   
   // // Determine trend for each timeframe
   // W_Trend = DetermineTrend(PERIOD_W1, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   D_Trend = DetermineTrend(InpTrendTF, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   swH_Trend = DetermineTrend(InpSwingTF, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   snrH_Trend = DetermineTrend(InpSnRTF, snrH_LastHigh, snrH_PrevHigh, snrH_LastLow, snrH_PrevLow);
   
   // // Determine market conditions
   // W_MarketCondition = DetermineMarketCondition(W_Trend, W_LastHigh, W_PrevHigh, W_LastLow, W_PrevLow);
   D_MarketCondition = DetermineMarketCondition(D_Trend, D_LastHigh, D_PrevHigh, D_LastLow, D_PrevLow);
   swH_MarketCondition = DetermineMarketCondition(swH_Trend, swH_LastHigh, swH_PrevHigh, swH_LastLow, swH_PrevLow);
   snrH_MarketCondition = DetermineMarketCondition(snrH_Trend, snrH_LastHigh, snrH_PrevHigh, snrH_LastLow, snrH_PrevLow);
   
   // // Determine trading strategies
   // W_Strategy = DetermineTradingStrategy(W_Trend, W_MarketCondition, W_SecondaryStrategy);
   D_Strategy = DetermineTradingStrategy(D_Trend, D_MarketCondition, D_SecondaryStrategy);
   swH_Strategy = DetermineTradingStrategy(swH_Trend, swH_MarketCondition, swH_SecondaryStrategy);
   snrH_Strategy = DetermineTradingStrategy(snrH_Trend, snrH_MarketCondition, snrH_SecondaryStrategy);
   
   // Display all analysis on chart
   DisplayAllTimeframesAnalysis();

   // Analyze previous levels to catch any missed boxes
   // AnalyzePreviousLevels(InpSnRTF, InpLookbackPeriod);
   
   // Print("🔍 Starting Support & Resistance analysis on timeframe: ", EnumToString(InpSnRTF), "...");
   AnalyzeLevels(InpSnRTF, InpLookbackPeriod);
   AnalyzeLowPivots();
   // AnalyzePivotPoints(InpLowTF, L_LastHigh, L_PrevHigh, L_LastLow, L_PrevLow);
   // AnalyzeLevels(PERIOD_H1, InpLookbackPeriod);
   
   // Update box visibility based on settings
   UpdateBoxVisibility();
   
   // Print("✓ Analysis complete\n");

   // // Handle BOS invalidation when new swing high/low detected on low timeframe
   // if(swH_LastHigh.isValid)
   // {
   //    // Close all BUY positions when new swing high is detected (if enabled)
   //    if(InpCloseOnNewSwing)
   //       CloseAllPositions(POSITION_TYPE_BUY);
      
   //    // Invalidate existing BOS when new swing high is detected
   //    if(BOS.isActive && !BOS.isBullish)
   //    {
   //       // Print("New Swing High detected - Invalidating existing bearish BOS");
   //       BOS.isActive = false;
   //       waitingForPullback = false;
   //       ObjectDelete(0, "BOS_Level");
   //    }
   // }
   
   // if(swH_LastLow.isValid)
   // {
   //    // Close all SELL positions when new swing low is detected (if enabled)
   //    if(InpCloseOnNewSwing)
   //       CloseAllPositions(POSITION_TYPE_SELL);
      
   //    // Invalidate existing BOS when new swing low is detected
   //    if(BOS.isActive && BOS.isBullish)
   //    {
   //       // Print("New Swing Low detected - Invalidating existing bullish BOS");
   //       BOS.isActive = false;
   //       waitingForPullback = false;
   //       ObjectDelete(0, "BOS_Level");
   //    }
   // }

   // Execute entry if signal flags are set
   if(IsBreakout || IsHold)
      CheckEntryLevel();
   
   if(InpUseBOSValidation && !waitingForPullback)
   {
      // Print("Box Index: ", IntegerToString(g_ActiveBoxIndex));
   }
   
   // Check for pullback entry
   if(waitingForPullback && BOS.isActive)
   {
      ExtendBOSLevel(currentBarTime, BOS.price);
      CheckForEntry();
   }
   
   // Apply trailing stop on every tick if enabled
   if(InpUseTrailingStop)
      ApplyTrailingStop(); // Pass 0 (default) to apply to all BOS trades
   
   // Note: CheckForBreakout/Hold are now called automatically when boxes are detected
   // in CheckTradingSignals() and immediately trigger CheckEntryLevel() if validated
   
   // Reset box counters if all positions closed
   ResetBoxCountersIfClosed();
}
//#endregion
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check for Break of Structure on Low Timeframe                    |
//+------------------------------------------------------------------+
// void CheckForBOS()
// {
//    if(!L_LastHigh.isValid || !L_LastLow.isValid)
//       return;
   
//    double currentClose = iClose(_Symbol, InpLowTF, 0);
   
//    // When InpEnableSupertrend is enabled
//    if(InpEnableSupertrend)
//    {
//       // If swing trend is sideways, check daily trend
//       if(swH_Trend == TREND_SIDEWAYS)
//       {
//          // Only proceed if daily trend is clear and strong
//          if(D_MarketCondition != CLEAR_AND_STRONG_TREND)
//             return;
            
//          // Use daily trend direction instead
//          if(D_Trend == TREND_BEARISH && InpTradeDirection != TRADE_BUY_ONLY)
//          {
//             // Bearish BOS: Price breaks below most recent swing low
//             if(L_LastLow.isValid)
//             {
//                if(currentClose < L_LastLow.price && !BOS.isActive)
//                {
//                   BOS.price = L_LastLow.price;
//                   BOS.time = TimeCurrent();
//                   BOS.isBullish = false;
//                   BOS.isActive = true;
//                   BOS.barIndex = 0;
//                   waitingForPullback = true;
                  
//                   // Print("Bearish BOS detected at ", BOS.price, " (Swing: SIDEWAYS, Daily Trend: BEARISH)");
//                   DrawBOSLevel(BOS.price, BOS.time, false);
//                }
//             }
//          }
//          else if(D_Trend == TREND_BULLISH && InpTradeDirection != TRADE_SELL_ONLY)
//          {
//             // Bullish BOS: Price breaks above most recent swing high
//             if(L_LastHigh.isValid)
//             {
//                if(currentClose > L_LastHigh.price && !BOS.isActive)
//                {
//                   BOS.price = L_LastHigh.price;
//                   BOS.time = TimeCurrent();
//                   BOS.isBullish = true;
//                   BOS.isActive = true;
//                   BOS.barIndex = 0;
//                   waitingForPullback = true;
                  
//                   // Print("Bullish BOS detected at ", BOS.price, " (Swing: SIDEWAYS, Daily Trend: BULLISH)");
//                   DrawBOSLevel(BOS.price, BOS.time);
//                }
//             }
//          }
//          else
//          {
//             // Daily trend is also sideways or undecided - no BOS
//             return;
//          }
//       }
//       // Swing trend is clear (not sideways)
//       else if(swH_Trend == TREND_BEARISH && InpTradeDirection != TRADE_BUY_ONLY)
//       {
//          // Bearish BOS: Price breaks below most recent swing low
//          if(L_LastLow.isValid)
//          {
//             if(currentClose < L_LastLow.price && !BOS.isActive)
//             {
//                BOS.price = L_LastLow.price;
//                BOS.time = TimeCurrent();
//                BOS.isBullish = false;
//                BOS.isActive = true;
//                BOS.barIndex = 0;
//                waitingForPullback = true;
               
//                // Print("Bearish BOS detected at ", BOS.price, " (HTF Trend: BEARISH)");
//                DrawBOSLevel(BOS.price, BOS.time, false);
//             }
//          }
//       }
//       // Check for BULLISH BOS when trend is bullish
//       else if(swH_Trend == TREND_BULLISH && InpTradeDirection != TRADE_SELL_ONLY)
//       {
//          // Bullish BOS: Price breaks above most recent swing high
//          if(L_LastHigh.isValid)
//          {
//             if(currentClose > L_LastHigh.price && !BOS.isActive)
//             {
//                BOS.price = L_LastHigh.price;
//                BOS.time = TimeCurrent();
//                BOS.isBullish = true;
//                BOS.isActive = true;
//                BOS.barIndex = 0;
//                waitingForPullback = true;
               
//                // Print("Bullish BOS detected at ", BOS.price, " (HTF Trend: BULLISH)");
//                DrawBOSLevel(BOS.price, BOS.time);
//             }
//          }
//       }
//    }
//    // When InpEnableSupertrend is disabled - BOS follows last HTF swing point
//    else
//    {
//       // If last HTF swing was HIGH, look for BEARISH BOS
//       if(lastSwingWasHigh && InpTradeDirection != TRADE_BUY_ONLY)
//       {
//          // Bearish BOS: Price breaks below most recent swing low
//          if(L_LastLow.isValid)
//          {
//             if(currentClose < L_LastLow.price && !BOS.isActive)
//             {
//                BOS.price = L_LastLow.price;
//                BOS.time = TimeCurrent();
//                BOS.isBullish = false;
//                BOS.isActive = true;
//                BOS.barIndex = 0;
//                waitingForPullback = true;
               
//                // Print("Bearish BOS detected at ", BOS.price, " (Last HTF swing was HIGH)");
//                DrawBOSLevel(BOS.price, BOS.time, false);
//             }
//          }
//       }
//       // If last HTF swing was LOW, look for BULLISH BOS
//       else if(!lastSwingWasHigh && InpTradeDirection != TRADE_SELL_ONLY)
//       {
//          // Bullish BOS: Price breaks above most recent swing high
//          if(L_LastHigh.isValid)
//          {
//             if(currentClose > L_LastHigh.price && !BOS.isActive)
//             {
//                BOS.price = L_LastHigh.price;
//                BOS.time = TimeCurrent();
//                BOS.isBullish = true;
//                BOS.isActive = true;
//                BOS.barIndex = 0;
//                waitingForPullback = true;
               
//                // Print("Bullish BOS detected at ", BOS.price, " (Last HTF swing was LOW)");
//                DrawBOSLevel(BOS.price, BOS.time);
//             }
//          }
//       }
//    }
// }
