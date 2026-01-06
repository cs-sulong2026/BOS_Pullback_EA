//+------------------------------------------------------------------+
//|                                                    Functions.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 28.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| Convert color to ARGB with transparency                          |
//+------------------------------------------------------------------+
color ColorWithAlpha(color baseColor, uchar alpha)
{
   // Extract RGB components
   uchar r = (uchar)(baseColor & 0xFF);
   uchar g = (uchar)((baseColor >> 8) & 0xFF);
   uchar b = (uchar)((baseColor >> 16) & 0xFF);
   
   // Combine ARGB (Alpha in high byte)
   return (color)((alpha << 24) | (b << 16) | (g << 8) | r);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void InitPivotPoints()
{
   // Initialize HTF Pivot Points
   LastHigh.isValid = false;
   PrevHigh.isValid = false;
   LastLow.isValid = false;
   PrevLow.isValid = false;

   // Initialize Weekly Pivot Points
   W_LastHigh.isValid = false;
   W_PrevHigh.isValid = false;
   W_LastLow.isValid = false;
   W_PrevLow.isValid = false;

   // Initialize Daily Pivot Points
   D_LastHigh.isValid = false;
   D_PrevHigh.isValid = false;
   D_LastLow.isValid = false;
   D_PrevLow.isValid = false;
}

//+------------------------------------------------------------------+
//| Analyze pivot points                                              |
//+------------------------------------------------------------------+
void AnalyzePivotPoints(ENUM_TIMEFRAMES timeframe, PivotPoint &lastHigh, PivotPoint &prevHigh, PivotPoint &lastLow, PivotPoint &prevLow)
{
   // Check for new bar on this specific timeframe
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   
   // Check appropriate last bar time based on timeframe
   if(timeframe == PERIOD_W1)
   {
      if(currentBarTime == g_LastBarTime_W1)
         return;
      g_LastBarTime_W1 = currentBarTime;
   }
   else if(timeframe == PERIOD_D1 || timeframe == InpTrendTF)
   {
      if(currentBarTime == g_LastBarTime_D1)
         return;
      g_LastBarTime_D1 = currentBarTime;
   }
   else if(timeframe == InpSwingTF)
   {
      if(currentBarTime == g_LastBarTime_swH)
         return;
      g_LastBarTime_swH = currentBarTime;
   }
   else if(timeframe == InpSnRTF)
   {
      if(currentBarTime == g_LastBarTime_snrH)
         return;
      g_LastBarTime_snrH = currentBarTime;
   }
   else if(timeframe == InpLowTF)
   {
      if(currentBarTime == g_LastBarTime_L)
         return;
      g_LastBarTime_L = currentBarTime;
   }
   else // Default to current timeframe tracker
   {
      if(currentBarTime == g_LastBarTime)
         return;
      g_LastBarTime = currentBarTime;
   }
   
   int lookback = InpLookbackPeriod;
   int foundHighs = 0;
   int foundLows = 0;

   // Temporary storage for newly found pivots with structure classification
   PivotPoint tempLastHigherHigh, tempPrevHigherHigh, tempLastHigherLow, tempPrevHigherLow;
   PivotPoint tempLastLowerLow, tempPrevLowerLow, tempLastLowerHigh, tempPrevLowerHigh;
   
   // Arrays to store all found pivots for validation
   PivotPoint allHighs[], allLows[];
   ArrayResize(allHighs, 0);
   ArrayResize(allLows, 0);
   
   // Initialize all temp pivots
   tempLastHigherHigh.isValid = false;
   tempPrevHigherHigh.isValid = false;
   tempLastHigherLow.isValid = false;
   tempPrevHigherLow.isValid = false;
   tempLastLowerLow.isValid = false;
   tempPrevLowerLow.isValid = false;
   tempLastLowerHigh.isValid = false;
   tempPrevLowerHigh.isValid = false;

   // Search for ALL pivot highs first (extended search for validation)
   for(int i = InpPivotRightBars; i < lookback; i++)
   {
      if(IsPivotHigh(i, timeframe))
      {
         int idx = ArraySize(allHighs);
         ArrayResize(allHighs, idx + 1);
         allHighs[idx].price = iHigh(_Symbol, timeframe, i);
         allHighs[idx].time = iTime(_Symbol, timeframe, i);
         allHighs[idx].barIndex = i;
         allHighs[idx].isValid = true;
      }
   }

   // Search for ALL pivot lows (extended search for validation)
   for(int i = InpPivotRightBars; i < lookback; i++)
   {
      if(IsPivotLow(i, timeframe))
      {
         int idx = ArraySize(allLows);
         ArrayResize(allLows, idx + 1);
         allLows[idx].price = iLow(_Symbol, timeframe, i);
         allLows[idx].time = iTime(_Symbol, timeframe, i);
         allLows[idx].barIndex = i;
         allLows[idx].isValid = true;
      }
   }
   
   // Now classify the first 2 highs
   if(ArraySize(allHighs) >= 2)
   {
      // Compare recent vs older high to determine trend direction
      double recentHigh = allHighs[0].price;  // Most recent
      double olderHigh = allHighs[1].price;   // Older
      
      if(recentHigh > olderHigh)
      {
         // UPTREND in highs: Recent > Older
         // Recent = HH (Higher High), Older = hh (previous high)
         tempLastHigherHigh = allHighs[0];
         tempPrevHigherHigh = allHighs[1];
         foundHighs = 2;
      }
      else
      {
         // DOWNTREND in highs: Recent < Older
         // Recent = LH (Lower High - most recent), Older = lh (previous lower high)
         tempLastLowerHigh = allHighs[0];      // Recent is LH
         tempPrevLowerHigh = allHighs[1];      // Older is lh
         foundHighs = 2;
      }
   }
   else if(ArraySize(allHighs) == 1)
   {
      tempLastHigherHigh = allHighs[0];
      foundHighs = 1;
   }

   // Classify the first 2 lows
   if(ArraySize(allLows) >= 2)
   {
      // Compare recent vs older low to determine trend direction
      double recentLow = allLows[0].price;   // Most recent
      double olderLow = allLows[1].price;    // Older
      
      if(recentLow < olderLow)
      {
         // DOWNTREND in lows: Recent < Older
         // Recent = LL (Lower Low - most recent), Older = ll (previous low)
         tempLastLowerLow = allLows[0];       // Recent is LL
         tempPrevLowerLow = allLows[1];       // Older is ll
         foundLows = 2;
      }
      else
      {
         // UPTREND in lows: Recent > Older
         // Recent = HL (Higher Low - most recent), Older = hl (previous higher low)
         tempLastHigherLow = allLows[0];      // Recent is HL
         tempPrevHigherLow = allLows[1];      // Older is hl
         foundLows = 2;
      }
   }
   else if(ArraySize(allLows) == 1)
   {
      tempLastLowerLow = allLows[0];
      foundLows = 1;
   }
   
   // Validate structure: Check for uptrend pattern (HH, hh, HL, hl)
   // If we have HH > hh and HL, validate first low against previous pivots
   if(tempLastHigherHigh.isValid && tempPrevHigherHigh.isValid && tempPrevHigherLow.isValid)
   {
      // We have HH, hh, and HL pattern - validate first low
      // Check if there are previous pivots before the first low
      for(int i = 0; i < ArraySize(allLows); i++)
      {
         // Find lows that are older than first low (higher bar index)
         if(allLows[i].barIndex > tempPrevHigherLow.barIndex)
         {
            // Check if this previous low < first low (which we labeled as HL)
            if(allLows[i].price < tempPrevHigherLow.price)
            {
               // Found a lower previous low - this confirms first point should be HL
               // The older low becomes the true LL
               tempLastLowerLow = allLows[i];
               break;
            }
         }
      }
   }

   // Assign structured pivots to reference parameters with correct labels
   // Priority order: Update most recent pivots first, then previous pivots
   
   // Assign HIGHS - check for both uptrend (HH/hh) and downtrend (LH/lh) patterns
   if(tempLastHigherHigh.isValid)
   {
      // Uptrend: HH (highest high)
      if(!lastHigh.isValid || tempLastHigherHigh.time > lastHigh.time || tempLastHigherHigh.price != lastHigh.price)
      {
         lastHigh = tempLastHigherHigh;
         lastHigh.name = "HH";
         if(timeframe == InpTrendTF)
            DrawPivotPoints("HH", timeframe, lastHigh);
      }
      
      // Previous high in uptrend: hh
      if(tempPrevHigherHigh.isValid)
      {
         if(!prevHigh.isValid || tempPrevHigherHigh.time > prevHigh.time || tempPrevHigherHigh.price != prevHigh.price)
         {
            prevHigh = tempPrevHigherHigh;
            prevHigh.name = "hh";
            if(timeframe == InpTrendTF)
               DrawPivotPoints("hh", timeframe, prevHigh);
         }
      }
   }
   else if(tempLastLowerHigh.isValid)
   {
      // Downtrend: LH (lower high)
      if(!lastHigh.isValid || tempLastLowerHigh.time > lastHigh.time || tempLastLowerHigh.price != lastHigh.price)
      {
         lastHigh = tempLastLowerHigh;
         lastHigh.name = "LH";
         if(timeframe == InpTrendTF)
            DrawPivotPoints("LH", timeframe, lastHigh);
      }
      
      // Previous high in downtrend: lh
      if(tempPrevLowerHigh.isValid)
      {
         if(!prevHigh.isValid || tempPrevLowerHigh.time > prevHigh.time || tempPrevLowerHigh.price != prevHigh.price)
         {
            prevHigh = tempPrevLowerHigh;
            prevHigh.name = "lh";
            if(timeframe == InpTrendTF)
               DrawPivotPoints("lh", timeframe, prevHigh);
         }
      }
   }
   
   // Assign LOWS - check for both downtrend (LL/ll) and uptrend (HL/hl) patterns
   if(tempLastLowerLow.isValid)
   {
      // Downtrend: LL (lowest low)
      if(!lastLow.isValid || tempLastLowerLow.time > lastLow.time || tempLastLowerLow.price != lastLow.price)
      {
         lastLow = tempLastLowerLow;
         lastLow.name = "LL";
         if(timeframe == InpTrendTF)
            DrawPivotPoints("LL", timeframe, lastLow);
      }
      
      // Previous low in downtrend: ll
      if(tempPrevLowerLow.isValid)
      {
         if(!prevLow.isValid || tempPrevLowerLow.time > prevLow.time || tempPrevLowerLow.price != prevLow.price)
         {
            prevLow = tempPrevLowerLow;
            prevLow.name = "ll";
            if(timeframe == InpTrendTF)
               DrawPivotPoints("ll", timeframe, prevLow);
         }
      }
   }
   else if(tempLastHigherLow.isValid)
   {
      // Uptrend: HL (higher low)
      if(!lastLow.isValid || tempLastHigherLow.time > lastLow.time || tempLastHigherLow.price != lastLow.price)
      {
         lastLow = tempLastHigherLow;
         lastLow.name = "HL";
         if(timeframe == InpTrendTF)
            DrawPivotPoints("HL", timeframe, lastLow);
      }
      
      // Previous low in uptrend: hl
      if(tempPrevHigherLow.isValid)
      {
         if(!prevLow.isValid || tempPrevHigherLow.time > prevLow.time || tempPrevHigherLow.price != prevLow.price)
         {
            prevLow = tempPrevHigherLow;
            prevLow.name = "hl";
            if(timeframe == InpTrendTF)
               DrawPivotPoints("hl", timeframe, prevLow);
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Check for rejection candle (long wick, small body)               |
//+------------------------------------------------------------------+
bool HasRejectionCandle(ENUM_TIMEFRAMES timeframe, int shift, bool checkBullishRejection)
{
   double open = iOpen(_Symbol, timeframe, shift);
   double close = iClose(_Symbol, timeframe, shift);
   double high = iHigh(_Symbol, timeframe, shift);
   double low = iLow(_Symbol, timeframe, shift);
   
   double bodySize = MathAbs(close - open);
   double totalRange = high - low;
   
   if(totalRange == 0)
      return false;
   
   if(checkBullishRejection)
   {
      // Bullish rejection: long lower wick, buyers rejected lower prices
      double lowerWick = MathMin(open, close) - low;
      double upperWick = high - MathMax(open, close);
      
      // Lower wick should be at least 2x body size and at least 50% of total range
      if(lowerWick >= bodySize * 2.0 && lowerWick >= totalRange * 0.5)
         return true;
   }
   else
   {
      // Bearish rejection: long upper wick, sellers rejected higher prices
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      
      // Upper wick should be at least 2x body size and at least 50% of total range
      if(upperWick >= bodySize * 2.0 && upperWick >= totalRange * 0.5)
         return true;
   }
   
   return false;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void AnalyzeLevels(ENUM_TIMEFRAMES timeframe, int shift)
{
   int lookback = InpPivotLeftBars + InpPivotRightBars + 10;

   int barsTotal = Bars(_Symbol, timeframe);
   // Print("   Bars available: ", barsTotal);
   
   if(barsTotal < InpLookbackPeriod * 2 + 10)
   {
      // Print("   ⚠️ Not enough bars. Need: ", InpLookbackPeriod * 2 + 10, " | Have: ", barsTotal);
      return;
   }
   
   // Need to check bar at InpLookbackPeriod shift to have enough bars on both sides for pivot detection
   if(shift < InpLookbackPeriod)
      return;
   // Print("   Analyzing "+TFtoString(timeframe)+" bar shift: ", shift, " (", TimeToString(iTime(_Symbol, timeframe, shift), TIME_DATE|TIME_MINUTES), ")");
   
   // Calculate delta volume
   double deltaVol = UpAndDownVolume(shift, timeframe);
   double volHi = GetHighestVolume(InpVolFilterLen, shift, timeframe);
   double volLo = GetLowestVolume(InpVolFilterLen, shift, timeframe);
   
   // Print("   Delta Volume: ", deltaVol, " | High Filter: ", volHi, " | Low Filter: ", volLo);
   
   // Find pivots
   double pivotHigh = PivotHigh(InpLookbackPeriod, InpLookbackPeriod, shift, timeframe);
   double pivotLow = PivotLow(InpLookbackPeriod, InpLookbackPeriod, shift, timeframe);
   
   // Print("   Pivot High: ", pivotHigh, " | Pivot Low: ", pivotLow);
   
   // Calculate ATR for box width
   double atr = CalculateATR(200, shift, timeframe);
   double width = atr * InpBoxWidth;
   
   // Print("   ATR(200): ", atr, " | Box Width: ", width);
   
   // Prepare support/resistance levels
   bool hasSupport = (pivotLow > 0 && deltaVol > volHi);
   bool hasResistance = (pivotHigh > 0 && deltaVol < volLo);
   
   if(hasSupport)
   {
      g_SupportLevel = pivotLow;
      g_SupportLevel1 = g_SupportLevel - width;
   }
   
   if(hasResistance)
   {
      g_ResistanceLevel = pivotHigh;
      g_ResistanceLevel1 = g_ResistanceLevel + width;
   }

   // Check for trading signals and create boxes
   CheckTradingSignals(InpLowTF, shift, hasSupport, g_SupportLevel, g_SupportLevel1, 
                       hasResistance, g_ResistanceLevel1, g_ResistanceLevel, deltaVol, width);
}

//+------------------------------------------------------------------+
//| Analyze Low Timeframe for swing points                           |
//+------------------------------------------------------------------+
void AnalyzeLowPivots()
{
   int lookback = 50;
   
   // Reset previous values
   L_PrevHigh.isValid = false;
   L_PrevLow.isValid = false;
   
   for(int i = InpPivotRightBars; i < lookback; i++)
   {
      // Check for swing high
      if(IsPivotHigh(i, InpLowTF))
      {
         double highPrice = iHigh(_Symbol, InpLowTF, i);
         datetime highTime = iTime(_Symbol, InpLowTF, i);
         
         if(!L_LastHigh.isValid || highTime > L_LastHigh.time)
         {
            L_PrevHigh = L_LastHigh;
            L_LastHigh.price = highPrice;
            L_LastHigh.time = highTime;
            L_LastHigh.barIndex = i;
            L_LastHigh.isValid = true;
         }
         else if(!L_PrevHigh.isValid)
         {
            L_PrevHigh.price = highPrice;
            L_PrevHigh.time = highTime;
            L_PrevHigh.barIndex = i;
            L_PrevHigh.isValid = true;
         }
      }
      
      // Check for swing low
      if(IsPivotLow(i, InpLowTF))
      {
         double lowPrice = iLow(_Symbol, InpLowTF, i);
         datetime lowTime = iTime(_Symbol, InpLowTF, i);
         
         if(!L_LastLow.isValid || lowTime > L_LastLow.time)
         {
            L_PrevLow = L_LastLow;
            L_LastLow.price = lowPrice;
            L_LastLow.time = lowTime;
            L_LastLow.barIndex = i;
            L_LastLow.isValid = true;
         }
         else if(!L_PrevLow.isValid)
         {
            L_PrevLow.price = lowPrice;
            L_PrevLow.time = lowTime;
            L_PrevLow.barIndex = i;
            L_PrevLow.isValid = true;
         }
      }
   }
}

//+------------------------------------------------------------------+
//|
//+------------------------------------------------------------------+
void MostRecentPoints()
{
   if(D_LastHigh.isValid && D_LastLow.isValid)
   {
      if(D_LastHigh.time > D_LastLow.time)
      {
         lastSwingWasHigh = true;
         if(D_LastHigh.name == "HH")
            lastIsHigherHigh = true;
         else
            lastIsHigherHigh = false;
      }
      else if(D_LastLow.time > D_LastHigh.time)
      {
         lastSwingWasHigh = false;
         if(D_LastLow.name == "LL")
            lastIsLowerLow = true;
         else
            lastIsLowerLow = false;
      }
      else if(D_LastHigh.barIndex < D_LastLow.barIndex)
      {
         lastSwingWasHigh = true;
         if(D_LastHigh.name == "HH")
            lastIsHigherHigh = true;
         else
            lastIsHigherHigh = false;
      }
      else
      {
         lastSwingWasHigh = false;
         if(D_LastLow.name == "LL")
            lastIsLowerLow = true;
         else
            lastIsLowerLow = false;
      }
   }
   else if(D_LastHigh.isValid)
   {
      lastSwingWasHigh = true;
      if(D_LastHigh.name == "HH")
         lastIsHigherHigh = true;
      else
         lastIsHigherHigh = false;
   }
   else if(D_LastLow.isValid)
   {
      lastSwingWasHigh = false;
      if(D_LastLow.name == "LL")
         lastIsLowerLow = true;
      else
         lastIsLowerLow = false;
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals                                       |
//+------------------------------------------------------------------+
void CheckTradingSignals(ENUM_TIMEFRAMES timeframe, int oldShift, 
                         bool hasSupport, double supportTop, double supportBottom,
                         bool hasResistance, double resistanceTop, double resistanceBottom,
                         double volume, double width)
{
   int shift = oldShift/2; // Adjust shift for low timeframe analysis
   // Create boxes with exact pivot shift time
   datetime leftTime = iTime(_Symbol, timeframe, shift);
   
   if(hasSupport)
   {
      AddBoxAtTime(timeframe, leftTime, supportTop, supportBottom, volume, true);
   }
   
   if(hasResistance)
   {
      AddBoxAtTime(timeframe, leftTime, resistanceTop, resistanceBottom, volume, false);
   }
   
   double currLow = iLow(_Symbol, timeframe, shift);
   double currHigh = iHigh(_Symbol, timeframe, shift);
   double prevLow = iLow(_Symbol, timeframe, shift + 1);
   double prevHigh = iHigh(_Symbol, timeframe, shift + 1);

   prevHigh = NormalizeDouble(prevHigh, _Digits);
   currHigh = NormalizeDouble(currHigh, _Digits);
   prevLow = NormalizeDouble(prevLow, _Digits);
   currLow = NormalizeDouble(currLow, _Digits);
   // Print("      Current "+TFtoString(timeframe)+" Bar: High=", currHigh, " Low=", currLow, " Shift=", shift);
   // Print("      Previous "+TFtoString(timeframe)+" Bar: High=", prevHigh, " Low=", prevLow, " Shift=", shift + 1);
   
   if(g_BoxCount == 0)
   {
      // Print("      ⚠️ No boxes to check for signals");
      return;
   }
   
   int boxesToCheck = MathMin(10, g_BoxCount);
   // Print("      Checking last ", boxesToCheck, " boxes...");
      // Check recent boxes for signals
   for(int i = g_BoxCount - 1; i >= 0 && i >= g_BoxCount - 10; i--)
   {
      if(g_Boxes[i].is_support)
      {
         double boxBottom = NormalizeDouble(g_Boxes[i].bottom, _Digits);
         double boxTop = NormalizeDouble(g_Boxes[i].top, _Digits);

         // Print("         Box[", i+1, "] SUPPORT:\nsupHolds ? PrevLow>=Top: ", prevLow, ">=", boxTop, " && CurrLow>Top: ", currLow, ">", boxTop,
         //       "\nbreakoutSup ? PrevHigh>=Bottom: ", prevHigh, ">=", boxBottom, " && CurrHigh<Bottom: ", currHigh, "<", boxBottom,
         //       "\n | Traded=", g_Boxes[i].traded, " | Broken=", g_Boxes[i].is_broken);
         
         // Calculate buffer to filter noise (especially important for M1)
         double atrBuffer = CalculateATR(14, shift, timeframe) * 0.2; // 20% of ATR
         
         // Get candle close prices
         double currClose = iClose(_Symbol, timeframe, shift);
         double currOpen = iOpen(_Symbol, timeframe, shift);
         double prevClose = iClose(_Symbol, timeframe, shift+1);
         
         // Support breakout: candle body closes below bottom with buffer (SELL signal)
         // Use body (not wicks) to avoid false signals from spikes
         bool breakoutSup = (MathMin(currClose, currOpen) < (boxBottom - atrBuffer) && 
                            prevClose >= boxBottom);
         
         // Support hold: candle body closes above top (BUY signal - retest)
         // If box is already broken, just check if price is above top (less strict for re-hold)
         bool supHolds = false;
         if(g_Boxes[i].is_broken)
         {
            // Re-hold detection: just check if price is back above top
            supHolds = (MathMax(currClose, currOpen) > boxTop);
         }
         else
         {
            // First hold: require transition pattern
            supHolds = (MathMax(currClose, currOpen) > boxTop && 
                       MathMax(prevClose, iOpen(_Symbol, timeframe, shift+1)) <= boxTop);
         }
         
         if(breakoutSup && (InpBoxDebug < 0 || i+1 == InpBoxDebug))
            Logging("            🔴 Support BREAKOUT detected! (Box: "+IntegerToString(i+1)+")");
         if(supHolds && (InpBoxDebug < 0 || i+1 == InpBoxDebug))
            Logging("            🟢 Support HOLD detected! (Box: "+IntegerToString(i+1)+")");

         // Determine box weak/strong state based on LL price between top/bottom
         if(!g_Boxes[i].is_strong && D_LastLow.isValid && D_LastLow.name == "LL")
         {
            if(D_LastLow.price < boxTop && D_LastLow.price > boxBottom)
            {
               g_Boxes[i].is_strong = true; // Strong box
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            ⚠️ Box classified as STRONG (LL within box). (Box: "+IntegerToString(i+1)+")");
            }
            else
            {
               g_Boxes[i].is_strong = false; // Weak box
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            ✅ Box classified as WEAK (LL outside box). (Box: "+IntegerToString(i+1)+")");
            }
         }

         if(breakoutSup && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_SupIsResistance = true;
            if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
            {
               Logging("            ⚡ Support broken! Checking trade conditions... (Box: "+IntegerToString(i+1)+")");
               Logging("            ❗ Checking Box if traded " + (g_Boxes[i].traded ? "✅" : "❌"));
            }
            
            // Update box visual
            UpdateBoxVisual(i, true);
            // CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "SUP", true);

            // Clear any existing BOS for this box (could be bullish if it held before)
            if(g_BOS[i].isActive)
            {
               string oldBOSName = g_BOS[i].isBullish ? "BULLISH BOS_" : "BEARISH BOS_";
               ObjectDelete(0, oldBOSName + IntegerToString(i+1));
               g_Boxes[i].waitingForPullback = false;
               g_BOS[i].isActive = false;
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            Cleared previous " + oldBOSName + " for Box " + IntegerToString(i+1) + " - ready for opposite BOS");
            }
            
            // SELL on support break
            if(InpTradeBreakouts && InpSellSignals && !g_Boxes[i].traded && !g_Boxes[i].is_disabled)
            {
               // Print("            ➤ Opening SELL on support break");
               CreateBreakoutLabel(i, iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "Break Sup", false);
               // OpenTrade(ORDER_TYPE_SELL, "Support Break", g_Boxes[i].top);
               // g_Boxes[i].traded = true;
            }
         }
         else if(breakoutSup && g_Boxes[i].is_broken)
         {
            g_SupIsResistance = true;
            g_Boxes[i].is_reheld = false; // Reset re-held state if it was set
            
            if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
            {
               Logging("⚠️ Support breakout on already-broken box (no state change). (Box: "+IntegerToString(i+1)+")");
               Logging("            ❗ Box State - Traded: " + (g_Boxes[i].traded ? "✅" : "❌") + " | Broken: ✅");
            }

            // Update box visual
            UpdateBoxVisual(i, true);

            // Clear any existing BOS for this box (could be bearish if it held before)
            if(g_BOS[i].isActive)
            {
               // Delete the old BOS line (could be either bullish or bearish)
               string oldBOSName = g_BOS[i].isBullish ? "BULLISH BOS_" : "BEARISH BOS_";
               ObjectDelete(0, oldBOSName + IntegerToString(i+1));
               
               // Reset BOS state to allow new BOS detection
               g_Boxes[i].waitingForPullback = false;
               g_BOS[i].isActive = false;
               
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            Cleared previous " + oldBOSName + " for Box " + IntegerToString(i+1) + " - ready for opposite BOS");
            }

            if(g_Boxes[i].traded)
            {
               g_Boxes[i].is_disabled = true;
               g_Boxes[i].drawn = false;  // Prevent further signal checks
            }
         }
         
         if(supHolds && (!g_Boxes[i].traded || g_Boxes[i].is_broken))
         {
            // Case 1: !traded && !broken - First hold (normal case)
            if(!g_Boxes[i].traded && !g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            🟢 Support held! First hold detected. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ❌ | Broken: ❌");
               }
            }
            // Case 2: !traded && broken - Box was broken but never traded, now holds again (reset)
            else if(!g_Boxes[i].traded && g_Boxes[i].is_broken)
            {
               g_Boxes[i].is_broken = false;
               g_SupIsResistance = false;
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            🔄 Support re-held without trade! Resetting broken state. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ❌ | Broken: ✅➜❌");
               }
               
               // Clear BOS if active for this box
               if(g_BOS[i].isActive)
               {
                  // Delete BOTH bullish and bearish BOS lines to ensure cleanup
                  ObjectDelete(0, "BULLISH BOS_" + IntegerToString(i+1));
                  ObjectDelete(0, "BEARISH BOS_" + IntegerToString(i+1));
                  
                  // Reset BOS global state
                  g_Boxes[i].waitingForPullback = false;
                  g_BOS[i].isActive = false;
               }
            }
            // Case 3: traded && !broken - Shouldn't happen normally, but handle defensively
            else if(g_Boxes[i].traded && !g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("⚠️ Support hold on already-traded box (unexpected state). (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ✅ | Broken: ❌");
               }
            }
            // Case 4: traded && broken - Re-held after break and trade (disable box)
            else if(g_Boxes[i].traded && g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            ⚡ Support re-held after break and trade! Box disabled. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ✅ | Broken: ✅");
               }

               // Clear BOS if active
               if(g_BOS[i].isActive)
               {
                  // Delete BOTH bullish and bearish BOS lines to ensure cleanup
                  ObjectDelete(0, "BULLISH BOS_" + IntegerToString(i+1));
                  ObjectDelete(0, "BEARISH BOS_" + IntegerToString(i+1));
                  
                  // Reset BOS global state
                  g_BOS[i].isActive = false;
               }
               
               // Disable box immediately (keep visual but stop checking)
               g_Boxes[i].waitingForPullback = false;
               // g_Boxes[i].is_disabled = true;
               // g_Boxes[i].drawn = false;  // Prevent further signal checks
               g_Boxes[i].is_reheld = true;
            }
            
            // Update box visual
            UpdateBoxVisual(i, false);
            // CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "SUP", false);
         }
      }
      else // Resistance
      {
         double boxBottom = NormalizeDouble(g_Boxes[i].bottom, _Digits);
         double boxTop = NormalizeDouble(g_Boxes[i].top, _Digits);
         
         // Print("         Box[", i+1, "] RESISTANCE:\nresHolds ? PrevHigh>=Bottom: ", prevHigh, ">=", boxBottom, " && CurrHigh<Bottom: ", currHigh, "<", boxBottom,
         //       "\nbreakoutRes ? PrevLow<=Top: ", prevLow, "<=", boxTop, " && CurrLow>Top: ", currLow, ">", boxTop,
         //       "\n | Traded=", g_Boxes[i].traded, " | Broken=", g_Boxes[i].is_broken);
         
         // Calculate buffer to filter noise (especially important for M1)
         double atrBuffer = CalculateATR(14, shift, timeframe) * 0.2; // 20% of ATR
         
         // Get candle close prices
         double currClose = iClose(_Symbol, timeframe, shift);
         double currOpen = iOpen(_Symbol, timeframe, shift);
         double prevClose = iClose(_Symbol, timeframe, shift+1);
         
         // Resistance breakout: candle body closes above top with buffer (BUY signal)
         // Use body (not wicks) to avoid false signals from spikes
         bool breakoutRes = (MathMax(currClose, currOpen) > (boxTop + atrBuffer) && 
                            prevClose <= boxTop);
         
         // Resistance hold: candle body closes below bottom (SELL signal - retest)
         // If box is already broken, just check if price is below bottom (less strict for re-hold)
         bool resHolds = false;
         if(g_Boxes[i].is_broken)
         {
            // Re-hold detection: just check if price is back below bottom
            resHolds = (MathMin(currClose, currOpen) < boxBottom);
         }
         else
         {
            // First hold: require transition pattern
            resHolds = (MathMin(currClose, currOpen) < boxBottom && 
                       MathMin(prevClose, iOpen(_Symbol, timeframe, shift+1)) >= boxBottom);
         }
         
         if(breakoutRes && (InpBoxDebug < 0 || i+1 == InpBoxDebug))
            Logging("            🟢 Resistance BREAKOUT detected! (Box: "+IntegerToString(i+1)+")");
         if(resHolds && (InpBoxDebug < 0 || i+1 == InpBoxDebug))
            Logging("            🔴 Resistance HOLD detected! (Box: "+IntegerToString(i+1)+")");

         // Determine box weak/strong state based on HH price between top/bottom
         if(!g_Boxes[i].is_strong && D_LastHigh.isValid && D_LastHigh.name == "HH")
         {
            if(D_LastHigh.price < boxTop && D_LastHigh.price > boxBottom)
            {
               g_Boxes[i].is_strong = true;  // Strong box
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            ⚠️ Box classified as STRONG (HH within box). (Box: "+IntegerToString(i+1)+")");
            }
            else
            {
               g_Boxes[i].is_strong = false; // weak box
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            ✅ Box classified as WEAK (HH outside box). (Box: "+IntegerToString(i+1)+")");
            }
         }

         if(breakoutRes && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_ResIsSupport = true;
            if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
            {
               Logging("            ⚡ Resistance broken! Checking trade conditions... (Box: "+IntegerToString(i+1)+")");
               Logging("            ❗ Checking Box if traded " + (g_Boxes[i].traded ? "✅" : "❌"));
            }
            
            // Update box visual
            UpdateBoxVisual(i, true);
            // CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "RES", true);

            // Clear any existing BOS for this box (could be bearish if it held before)
            if(g_BOS[i].isActive)
            {
               string oldBOSName = g_BOS[i].isBullish ? "BULLISH BOS_" : "BEARISH BOS_";
               ObjectDelete(0, oldBOSName + IntegerToString(i+1));
               
               // Reset BOS state to allow new BOS detection
               g_Boxes[i].waitingForPullback = false;
               g_BOS[i].isActive = false;
               
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            Cleared previous " + oldBOSName + " for Box " + IntegerToString(i+1) + " - ready for opposite BOS");
            }
            
            // BUY on resistance break
            if(InpTradeBreakouts && InpBuySignals && !g_Boxes[i].traded && !g_Boxes[i].is_disabled)
            {
               // Print("            ➤ Opening BUY on resistance break");
               CreateBreakoutLabel(i, iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "Break Res", true);
               // OpenTrade(ORDER_TYPE_BUY, "Resistance Break", g_Boxes[i].bottom);
               // g_Boxes[i].traded = true;
            }
         }
         else if(breakoutRes && g_Boxes[i].is_broken)
         {
            g_ResIsSupport = true;
            g_Boxes[i].is_reheld = false; // Reset re-held state if it was set

            if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
            {
               Logging("⚠️ Resistance breakout on already-broken box (no state change). (Box: "+IntegerToString(i+1)+")");
               Logging("            ❗ Box State - Traded: " + (g_Boxes[i].traded ? "✅" : "❌") + " | Broken: ✅");
            }

            // Update box visual
            UpdateBoxVisual(i, true);

            // Clear any existing BOS for this box (could be bearish if it held before)
            if(g_BOS[i].isActive)
            {
               // Delete the old BOS line (could be either bullish or bearish)
               string oldBOSName = g_BOS[i].isBullish ? "BULLISH BOS_" : "BEARISH BOS_";
               ObjectDelete(0, oldBOSName + IntegerToString(i+1));
               
               // Reset BOS state to allow new BOS detection
               g_Boxes[i].waitingForPullback = false;
               g_BOS[i].isActive = false;
               
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
                  Logging("            Cleared previous " + oldBOSName + " for Box " + IntegerToString(i+1) + " - ready for opposite BOS");
            }

            if(g_Boxes[i].traded)
            {
               g_Boxes[i].is_disabled = true;
               g_Boxes[i].drawn = false;  // Prevent further signal checks
            }
         }
         
         if(resHolds && (!g_Boxes[i].traded || g_Boxes[i].is_broken))
         {
            // Case 1: !traded && !broken - First hold (normal case)
            if(!g_Boxes[i].traded && !g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            🔴 Resistance held! First hold detected. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ❌ | Broken: ❌");
               }
            }
            // Case 2: !traded && broken - Box was broken but never traded, now holds again (reset)
            else if(!g_Boxes[i].traded && g_Boxes[i].is_broken)
            {
               g_Boxes[i].is_broken = false;
               g_ResIsSupport = false;
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            🔄 Resistance re-held without trade! Resetting broken state. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ❌ | Broken: ✅➜❌");
               }
               
               // Clear BOS if active for this box
               if(g_BOS[i].isActive)
               {
                  // Delete BOTH bullish and bearish BOS lines to ensure cleanup
                  ObjectDelete(0, "BULLISH BOS_" + IntegerToString(i+1));
                  ObjectDelete(0, "BEARISH BOS_" + IntegerToString(i+1));
                  
                  // Reset BOS global state
                  g_Boxes[i].waitingForPullback = false;
                  g_BOS[i].isActive = false;
               }
            }
            // Case 3: traded && !broken - Shouldn't happen normally, but handle defensively
            else if(g_Boxes[i].traded && !g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("⚠️ Resistance hold on already-traded box (unexpected state). (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ✅ | Broken: ❌");
               }
            }
            // Case 4: traded && broken - Re-held after break and trade (disable box)
            else if(g_Boxes[i].traded && g_Boxes[i].is_broken)
            {
               if(InpBoxDebug < 0 || i+1 == InpBoxDebug)
               {
                  Logging("            ⚡ Resistance re-held after break and trade! Box disabled. (Box: "+IntegerToString(i+1)+")");
                  Logging("            ❗ Box State - Traded: ✅ | Broken: ✅");
               }

               // Clear BOS if active
               if(g_BOS[i].isActive)
               {
                  // Delete BOTH bullish and bearish BOS lines to ensure cleanup
                  ObjectDelete(0, "BULLISH BOS_" + IntegerToString(i+1));
                  ObjectDelete(0, "BEARISH BOS_" + IntegerToString(i+1));
                  
                  // Reset BOS global state
                  g_BOS[i].isActive = false;
               }
               
               // Disable box immediately (keep visual but stop checking)
               g_Boxes[i].waitingForPullback = false;
               // g_Boxes[i].is_disabled = true;
               // g_Boxes[i].drawn = false;  // Prevent further signal checks
               g_Boxes[i].is_reheld = true;
            }
            
            // Update box visual
            UpdateBoxVisual(i, false);
            // CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "RES", false);
         }
      }
   }
   
   // Extend all boxes to current time (outside the loop for efficiency)
   datetime currentTime = iTime(_Symbol, timeframe, 0);
   for(int i = 0; i < g_BoxCount; i++)
   {
      if(g_Boxes[i].drawn)
      {
         // Only move point 1 (right corner) to extend the box
         if(!ObjectMove(0, g_Boxes[i].name, 1, currentTime, g_Boxes[i].bottom))
         {} // Print("      ⚠️ Failed to extend box: ", g_Boxes[i].name, " Error: ", GetLastError());
      }
      // Update trailing stop for this box's trades if enabled - MOVED TO OnTick() for better performance
      // if(InpUseTrailingStop)
      //    ApplyTrailingStop(magicNumber);
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool IsPivotHigh(int bar, ENUM_TIMEFRAMES timeframe)
{
   // Ensure we have enough bars on the left side
   if(bar < InpPivotLeftBars)
      return false;
      
   double centerHigh = iHigh(_Symbol, timeframe, bar);
   
   for(int i = bar - InpPivotLeftBars; i <= bar + InpPivotRightBars; i++)
   {
      if(i != bar)
      {
         double compareHigh = iHigh(_Symbol, timeframe, i);
         if(compareHigh >= centerHigh)
            return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool IsPivotLow(int bar, ENUM_TIMEFRAMES timeframe)
{
   // Ensure we have enough bars on the left side
   if(bar < InpPivotLeftBars)
      return false;
      
   double centerLow = iLow(_Symbol, timeframe, bar);
   
   for(int i = bar - InpPivotLeftBars; i <= bar + InpPivotRightBars; i++)
   {
      if(i != bar)
      {
         double compareLow = iLow(_Symbol, timeframe, i);
         if(compareLow <= centerLow)
            return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Delete all pivot labels at a specific location                   |
//+------------------------------------------------------------------+
void DeletePivotLabelsAtLocation(datetime time, double price, ENUM_TIMEFRAMES chartTF)
{
   // List of all possible pivot labels
   string allLabels[] = {"HH", "hh", "LH", "lh", "LL", "ll", "HL", "hl"};
   string tfStr = TFtoString(chartTF);
   
   for(int i = 0; i < ArraySize(allLabels); i++)
   {
      string objName = allLabels[i] + " " + tfStr;
      if(ObjectFind(0, objName) >= 0)
      {
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
         double objPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE);
         
         // If object is at same location, delete it
         if(objTime == time && MathAbs(objPrice - price) < _Point * 0.5)
         {
            ObjectDelete(0, objName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void DrawPivotPoints(string name, ENUM_TIMEFRAMES chartTF, PivotPoint &lastPoint)
{
   if(!lastPoint.isValid)
      return;
   
   // First, delete any old conflicting labels at this location
   DeletePivotLabelsAtLocation(lastPoint.time, lastPoint.price, chartTF);
   
   // Create unique object name
   string objName =  name + " " + TFtoString(chartTF);

   // Delete existing object if it exists
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);

   color labelColor;
   string labelText;

   // Create text label at pivot point
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, lastPoint.time, lastPoint.price))
   {
      // Determine color and label code based on pivot type
      string tfString = TFtoString(chartTF);
      
      if(name == "HH" || name == "LL")
      {
         // Primary pivots (extremes) - Brown
         labelColor = ColorWithAlpha(clrBrown, 128);
         labelText = tfString + "\n" + name;
      }
      else if(name == "hh" || name == "ll")
      {
         // Previous pivots (same trend) - Teal
         labelColor = ColorWithAlpha(clrTeal, 128);
         labelText = tfString + "\n" + name;
      }
      else if(name == "LH" || name == "HL")
      {
         // Reversal pivots (main) - Orange
         labelColor = ColorWithAlpha(clrOrange, 128);
         labelText = tfString + "\n" + name;
      }
      else if(name == "lh" || name == "hl")
      {
         // Reversal pivots (previous) - Yellow
         labelColor = ColorWithAlpha(clrYellow, 128);
         labelText = tfString + "\n" + name;
      }
      else
      {
         // Default fallback
         labelColor = ColorWithAlpha(clrGray, 128);
         labelText = tfString + "\n" + name;
      }

      ObjectSetString(0, objName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
      
      // Set anchor based on pivot type - highs below, lows above
      if(name == "HH" || name == "hh" || name == "LH" || name == "lh")
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      else
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
         
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, name + " @ " + DoubleToString(lastPoint.price, _Digits));
   }


}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void AddBoxAtTime(ENUM_TIMEFRAMES timeframe, datetime leftTime, double top, double bottom, double volume, bool isSupport)
{
   // Check for duplicate boxes at similar price levels
   double priceCenter = (top + bottom) / 2.0;
   double boxHeight = top - bottom;
   double duplicateThreshold = boxHeight * 1.5; // 150% overlap threshold
   
   for(int i = 0; i < g_BoxCount; i++)
   {
      // Check if boxes are same type (both support or both resistance)
      if(g_Boxes[i].is_support != isSupport)
         continue;

      // Allow new box if existing box is inactive (disabled, broken+traded, or re-held)
      if(g_Boxes[i].is_disabled && !g_Boxes[i].drawn)
      {
         // Print("   ✅ Existing box (Box:" + IntegerToString(i+1) + ") is disabled/not drawn - allowing new box at similar level");
         continue; // Don't skip, allow adding new box
      }
      
      // Allow new box if existing box has been broken and traded (completed its lifecycle)
      if(g_Boxes[i].is_broken && g_Boxes[i].traded)
      {
         // Print("   ✅ Existing box (Box:" + IntegerToString(i+1) + ") is broken+traded - allowing new box at similar level");
         continue; // Don't skip, allow adding new box
      }
      
      // Allow new box if existing box has been re-held (flipped polarity)
      if(g_Boxes[i].is_reheld)
      {
         // Print("   ✅ Existing box (Box:" + IntegerToString(i+1) + ") is re-held - allowing new box at similar level");
         continue; // Don't skip, allow adding new box
      }
      
      // Calculate center and overlap
      double existingCenter = (g_Boxes[i].top + g_Boxes[i].bottom) / 2.0;
      double priceDiff = MathAbs(priceCenter - existingCenter);
      
      // If centers are very close, consider it a duplicate
      if(priceDiff < duplicateThreshold)
      {
         // Print("   ⚠️ Duplicate box detected at ", DoubleToString(priceCenter, _Digits),
         //       " (existing Box "+IntegerToString(i+1)+" at: ", DoubleToString(existingCenter, _Digits), ") - Skipping");
         return; // Skip adding duplicate
      }
   }
   
   if(g_BoxCount >= MAX_BOXES)
   {
      Print("   ⚠️ Box limit reached, removing 25 oldest boxes");
      
      // Delete visuals for the first 25 boxes
      for(int i = 0; i < 25; i++)
      {
         ObjectDelete(0, g_Boxes[i].name);
         ObjectDelete(0, g_Boxes[i].name + "_label");
         
         // Delete associated BOS lines if they exist
         string bullishBOSName = "BULLISH BOS_" + IntegerToString(i+1);
         string bearishBOSName = "BEARISH BOS_" + IntegerToString(i+1);
         if(ObjectFind(0, bullishBOSName) >= 0)
            ObjectDelete(0, bullishBOSName);
         if(ObjectFind(0, bearishBOSName) >= 0)
            ObjectDelete(0, bearishBOSName);
      }
      
      // Shift remaining boxes down (keep boxes 25-49, move them to positions 0-24)
      for(int i = 0; i < 25; i++)
         g_Boxes[i] = g_Boxes[i + 25];
      g_BoxCount = 25;
      
      // Update all box labels with new indices after shift
      for(int i = 0; i < g_BoxCount; i++)
      {
         string labelName = g_Boxes[i].name + "_label";
         if(ObjectFind(0, labelName) >= 0)
         {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "Vol: " + DoubleToString(g_Boxes[i].volume, 0) + " Box: " + IntegerToString(i + 1));
         }
      }
   }
   
   datetime currentTime = TimeCurrent();
   datetime rightTime = iTime(_Symbol, timeframe, 0);
   
   string boxName = "SRBox_" + TimeToString(currentTime, TIME_DATE|TIME_SECONDS) + "_" + (isSupport ? "SUP" : "RES");
   
   g_Boxes[g_BoxCount].name = boxName;
   g_Boxes[g_BoxCount].top = top;
   g_Boxes[g_BoxCount].bottom = bottom;
   g_Boxes[g_BoxCount].left = leftTime;
   g_Boxes[g_BoxCount].right = rightTime;
   g_Boxes[g_BoxCount].created = currentTime;
   g_Boxes[g_BoxCount].volume = volume;
   g_Boxes[g_BoxCount].is_support = isSupport;
   g_Boxes[g_BoxCount].is_broken = false;
   g_Boxes[g_BoxCount].is_reheld = false;
   g_Boxes[g_BoxCount].is_disabled = false;
   g_Boxes[g_BoxCount].waitingForPullback = false;
   g_Boxes[g_BoxCount].traded = false;
   g_Boxes[g_BoxCount].traded_count = 0;
   g_Boxes[g_BoxCount].hold_count = 0;
   g_Boxes[g_BoxCount].box_hold_limit = holdLimit;
   g_Boxes[g_BoxCount].break_count = 0;
   g_Boxes[g_BoxCount].box_break_limit = breakLimit;
   g_Boxes[g_BoxCount].buyOnHold_count = 0;
   g_Boxes[g_BoxCount].buyOnBreakout_count = 0;
   g_Boxes[g_BoxCount].sellOnHold_count = 0;
   g_Boxes[g_BoxCount].sellOnBreakout_count = 0;
   g_Boxes[g_BoxCount].buyOnHold_limit = InpMaxBuyOnHold;
   g_Boxes[g_BoxCount].buyOnBreakout_limit = InpMaxBuyOnBreakout;
   g_Boxes[g_BoxCount].sellOnHold_limit = InpMaxSellOnHold;
   g_Boxes[g_BoxCount].sellOnBreakout_limit = InpMaxSellOnBreakout;
   g_Boxes[g_BoxCount].drawn = false;
   g_Boxes[g_BoxCount].is_strong = false;
   
   // Determine colors
   color bgColor, borderColor;
   if(isSupport)
   {
      // bgColor = ColorWithAlpha(clrLightGreen, 64);
      // borderColor = ColorWithAlpha(clrGreen, 64);
      bgColor = C'0,60,0';
      borderColor = C'0,60,0';
   }
   else
   {
      // bgColor = ColorWithAlpha(clrSteelBlue, 64);
      // borderColor = ColorWithAlpha(clrDodgerBlue, 64);
      bgColor = C'41,77,105';
      borderColor = C'41,77,105';
   }
   
   g_Boxes[g_BoxCount].bgcolor = bgColor;
   g_Boxes[g_BoxCount].bordercolor = borderColor;
   g_Boxes[g_BoxCount].border_style = STYLE_SOLID;
   
   // Draw the box on chart
   if(ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, leftTime, top, rightTime, bottom))
   {
      ObjectSetInteger(0, boxName, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
      ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, boxName, OBJPROP_SELECTED, false);
      
      // If ShowOnlyClosest is enabled, start boxes hidden - UpdateBoxVisibility will show the closest ones
      if(InpShowOnlyClosest)
         ObjectSetInteger(0, boxName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      
      // Add volume label
      string labelName = boxName + "_label";
      double labelPrice = isSupport ? top : bottom;
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, leftTime, labelPrice))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, "Vol: " + DoubleToString(volume, 0)+" Box: "+IntegerToString(g_BoxCount+1));
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, ColorWithAlpha(clrWhite, 128));
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
         
         // Also hide label if ShowOnlyClosest is enabled
         if(InpShowOnlyClosest)
            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      
      g_Boxes[g_BoxCount].drawn = true;
   }
   
   g_BoxCount++;
   
   // Print("   📦 Box added [#", g_BoxCount, "] - Type: ", (isSupport ? "SUPPORT" : "RESISTANCE"), 
   //       " | Top: ", top, " | Bottom: ", bottom, " | LeftTime: ", TimeToString(leftTime, TIME_DATE|TIME_MINUTES),
   //       " | Total boxes: ", g_BoxCount);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void UpdateBoxVisual(int index, bool broken)
{
   if(index < 0 || index >= g_BoxCount)
      return;
      
   if(g_Boxes[index].name == "" || !g_Boxes[index].drawn)
      return;
      
   color newBgColor, newBorderColor;
   int newStyle;
   
   if(broken)
   {
      newBgColor = ColorWithAlpha(clrLightGray, 128);
      // newBorderColor = ColorWithAlpha(clrDarkRed, 128);  // Red for all breakouts
      newBorderColor = C'100,25,25';
      newStyle = STYLE_DASH;
   }
   else
   {
      newBgColor = g_Boxes[index].bgcolor;
      newBorderColor = g_Boxes[index].bordercolor;
      newStyle = STYLE_SOLID;
   }
   
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_BGCOLOR, newBgColor);
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_COLOR, newBorderColor);
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_STYLE, newStyle);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool ExtendBoxVisual(const long chart_id,
                     const string objName,
                     const int pt_index,
                     datetime time,
                     double price)
{
   datetime extend_time = time+PeriodSeconds(_Period)*10;
//--- reset the error value
   ResetLastError();
//--- move trend line's anchor point
   if(!ObjectMove(chart_id,objName,pt_index,extend_time,price))
     {
      Print(__FUNCTION__,
            ": failed to move the anchor point! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return true;
}

//+------------------------------------------------------------------+
//| Extend BOS Level Line                                            |
//+------------------------------------------------------------------+
bool ExtendBOSLevel(int boxIndex, datetime time, double price)
{
   if(boxIndex < 0 || boxIndex >= g_BoxCount)
      return false;
      
   string name = g_BOS[boxIndex].isBullish ? "BULLISH BOS" : "BEARISH BOS";
   string objName = name + "_" + IntegerToString(boxIndex+1);
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
//+------------------------------------------------------------------+
void HideBox(int index)
{
   if(index < 0 || index >= g_BoxCount)
      return;
      
   if(g_Boxes[index].name == "" || !g_Boxes[index].drawn)
      return;

   // If this box owns the active BOS, clear the BOS state so other boxes can create their own
   // if(BOS.isActive && BOS.boxIndex == index)
   // {
   //    g_Boxes[index].waitingForPullback = false;
   //    BOS.isActive = false;
   //    BOS.boxIndex = -1;
   //    // if(InpBoxDebug < 0 || index+1 == InpBoxDebug)
   //    Print("            🗑️ Cleared BOS state for Box " + IntegerToString(index+1) + " due to hiding");
   // }

   // Hide BOS lines for this box (both bullish and bearish)
   string bullishBOSName = "BULLISH BOS_" + IntegerToString(index+1);
   string bearishBOSName = "BEARISH BOS_" + IntegerToString(index+1);
   
   if(ObjectFind(0, bullishBOSName) >= 0)
      ObjectSetInteger(0, bullishBOSName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   if(ObjectFind(0, bearishBOSName) >= 0)
      ObjectSetInteger(0, bearishBOSName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(0, g_Boxes[index].name + "_label", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool ShowBox(int index)
{
   if(index < 0 || index >= g_BoxCount)
      return false;
      
   if(g_Boxes[index].name == "" || !g_Boxes[index].drawn)
      return false;

   // if(BOS.isActive && BOS.boxIndex == index)
   // {
   //    // if(InpBoxDebug < 0 || index+1 == InpBoxDebug)
      
   // }

   // Show BOS lines for this box if they exist
   string bullishBOSName = "BULLISH BOS_" + IntegerToString(index+1);
   string bearishBOSName = "BEARISH BOS_" + IntegerToString(index+1);
   
   if(ObjectFind(0, bullishBOSName) >= 0)
      ObjectSetInteger(0, bullishBOSName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   if(ObjectFind(0, bearishBOSName) >= 0)
      ObjectSetInteger(0, bearishBOSName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, g_Boxes[index].name + "_label", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

   return (g_BOS[index].isActive && g_BOS[index].boxIndex == index);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void UpdateBoxVisibility()
{
   if(g_BoxCount == 0)
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(InpShowOnlyClosest)
   {
      // Structure to hold box index and distance pairs
      struct BoxDistance
      {
         int index;
         double distance;
         string type; // "hold_support", "break_support", "hold_resistance", "break_resistance"
      };
      
      BoxDistance boxes[];
      ArrayResize(boxes, 0);
      
      // Find all boxes with their distances to current price
      for(int i = 0; i < g_BoxCount; i++)
      {
         if(!g_Boxes[i].drawn)
            continue;
         
         int idx = ArraySize(boxes);
         ArrayResize(boxes, idx + 1);
         boxes[idx].index = i;
         
         if(g_Boxes[i].is_support)
         {
            // For support: use top as reference (hold level) and bottom as breakout level
            if(!g_Boxes[i].is_broken)
            {
               boxes[idx].distance = MathAbs(currentPrice - g_Boxes[i].top);
               boxes[idx].type = "hold_support";
            }
            else
            {
               boxes[idx].distance = MathAbs(currentPrice - g_Boxes[i].bottom);
               boxes[idx].type = "break_support";
            }
         }
         else // Resistance
         {
            // For resistance: use bottom as reference (hold level) and top as breakout level
            if(!g_Boxes[i].is_broken)
            {
               boxes[idx].distance = MathAbs(currentPrice - g_Boxes[i].bottom);
               boxes[idx].type = "hold_resistance";
            }
            else
            {
               boxes[idx].distance = MathAbs(currentPrice - g_Boxes[i].top);
               boxes[idx].type = "break_resistance";
            }
         }
      }
      
      // Sort by distance (simple bubble sort)
      int n = ArraySize(boxes);
      for(int i = 0; i < n - 1; i++)
      {
         for(int j = 0; j < n - i - 1; j++)
         {
            if(boxes[j].distance > boxes[j + 1].distance)
            {
               BoxDistance temp = boxes[j];
               boxes[j] = boxes[j + 1];
               boxes[j + 1] = temp;
            }
         }
      }
      
      // Hide all boxes first
      for(int i = 0; i < g_BoxCount; i++)
         HideBox(i);
      
      // Show only the closest N boxes (respecting InpMaxVisibleBoxes)
      int maxToShow = (InpMaxVisibleBoxes > 0) ? InpMaxVisibleBoxes : 4; // Default to 4 if not specified
      int shown = 0;
      
      for(int i = 0; i < ArraySize(boxes) && shown < maxToShow; i++)
      {
         int boxIdx = boxes[i].index;
         bool hasActiveBOS = ShowBox(boxIdx);
         
         if(hasActiveBOS && (InpBoxDebug < 0 || boxIdx+1 == InpBoxDebug))
            Print("            ✅ Restored BOS state for Box " + IntegerToString(boxIdx+1) + " upon showing");
         
         // Process entry level check for this box (always call, not dependent on Print above)
         CheckEntryLevel(boxIdx);
         
         shown++;
      }
   }
   else
   {
      // Show based on max visible boxes setting
      if(InpMaxVisibleBoxes > 0 && g_BoxCount > InpMaxVisibleBoxes)
      {
         for(int i = 0; i < g_BoxCount; i++)
         {
            if(i >= g_BoxCount - InpMaxVisibleBoxes)
            {
               ShowBox(i);
               
               // Process entry level check for this box
               CheckEntryLevel(i);
            }
            else
               HideBox(i);
         }
      }
      else
      {
         // Show all boxes
         for(int i = 0; i < g_BoxCount; i++)
         {
            ShowBox(i);
            
            // Process entry level check for this box
            CheckEntryLevel(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CreateVisualMarker(datetime time, double price, string type, bool isBreak)
{
   string name = (isBreak ? "BreakMark_" : "HoldMark_") + IntegerToString(time);
   
   if(ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 108); // Diamond
      ObjectSetInteger(0, name, OBJPROP_COLOR, isBreak ? ColorWithAlpha(clrOrange, 128) : ColorWithAlpha(clrLime, 128));
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void CreateBreakoutLabel(int index, datetime time, double price, string text, bool isUp)
{
   string name = "BreakLabel_" + "Box " + IntegerToString(index+1) + "\n" + TimeToString(time, TIME_DATE|TIME_SECONDS);
   
   if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ColorWithAlpha(clrYellow, 128));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, isUp ? ANCHOR_LOWER : ANCHOR_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Draw BOS Level on Chart                                          |
//+------------------------------------------------------------------+
void DrawBOSLevel(string name, int boxIndex, double price, datetime time, bool isBullish=true)
{
   string objName = name + "_" + IntegerToString(boxIndex+1);
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
//| Check for BOS on Low Timeframe with box type validation          |
//+------------------------------------------------------------------+
void CheckForBOS(int boxIndex)
{
   if(boxIndex < 0 || boxIndex >= g_BoxCount)
   {
      Print("CheckForBOS: Invalid box index ", boxIndex);
      return;
   }

   if(!g_Boxes[boxIndex].drawn)
      return;
   
   if(!L_LastHigh.isValid || !L_LastLow.isValid)
   {
      Print("CheckForBOS: Low TF pivots not valid - High:", L_LastHigh.isValid, " Low:", L_LastLow.isValid);
      return;
   }
   
   double currentClose = iClose(_Symbol, InpLowTF, 0);
   
   // Determine trade direction based on which signal type we have and the actual box properties
   bool isBuySignal = false;
   bool isSellSignal = false;
   
   // Use the actual box's properties to determine signal direction
   bool isSupport = g_Boxes[boxIndex].is_support;
   bool isBroken = g_Boxes[boxIndex].is_broken;
   bool isReheld = g_Boxes[boxIndex].is_reheld;
   
   // if(!BOS.isActive)
   // {
   //    Logging("=== CheckForBOS Debug (Box "+IntegerToString(boxIndex+1)+") ===");
   //    Logging("Box Type: "+(isSupport ? "SUPPORT" : "RESISTANCE")+" | Broken: "+(isBroken ? "YES" : "NO"));
   //    Logging("Current Close: "+DoubleToString(currentClose, _Digits)+" | L_LastHigh: "+DoubleToString(L_LastHigh.price, _Digits)+" | L_LastLow: "+DoubleToString(L_LastLow.price, _Digits));
   //    Logging("Current BOS - Active: "+(BOS.isActive ? "YES" : "NO")+" | Bullish: "+(BOS.isBullish ? "YES" : "NO")+" | Price: "+DoubleToString(BOS.price, _Digits)+"\n");
   // }

   // Allow BOS detection for this box even if another box has active BOS
   // Each visible box should be able to create its own BOS level
   // The most recent BOS detection will update the global BOS state
   
   // Determine required BOS direction based on box type and state
   bool needBullishBOS = false;
   bool needBearishBOS = false;

   // Determine signal type from box state (same logic as CheckEntryLevel)
   if(isBroken)
   {
      // Breakout scenario
      if(!isSupport) // Resistance broke
      {
         if(isReheld)
            needBearishBOS = true;  // Sell signal
         else
            needBullishBOS = true;  // Buy signal
      }
      else // Support broke
      {
         if(isReheld)
            needBullishBOS = true;  // Buy signal
         else
            needBearishBOS = true;  // Sell signal
      }
   }
   else
   {
      // Hold scenario
      if(isSupport) // Support held
         needBullishBOS = true;  // Buy signal
      else // Resistance held
         needBearishBOS = true;  // Sell signal
   }
   
   if(needBullishBOS)
   {
      if(L_LastHigh.isValid)
      {
         if(currentClose > L_LastHigh.price && !g_BOS[boxIndex].isActive)
         {
            if(InpBoxDebug < 0 || boxIndex+1 == InpBoxDebug)
               Logging("→ TRIGGERING BULLISH BOS!");
            g_BOS[boxIndex].name = "BULLISH BOS";
            g_BOS[boxIndex].isBullish = true;
            // Determine BOS price level based on box type
            // if(!isSupport)
            //    g_BOS[boxIndex].price = g_Boxes[boxIndex].top; // Use box top for resistance breakout
            // else
            //    g_BOS[boxIndex].price = g_Boxes[boxIndex].bottom; // Use box bottom for support hold
            //---
            g_BOS[boxIndex].price = L_LastHigh.price;
            g_BOS[boxIndex].time = TimeCurrent();
            g_BOS[boxIndex].isActive = true;
            g_BOS[boxIndex].barIndex = 0;
            g_BOS[boxIndex].boxIndex = boxIndex;
            g_BOS[boxIndex].magicNumber = InpBOSMagicNumber+(int)DoubleToString(g_BOS[boxIndex].price,0);
            g_Boxes[boxIndex].waitingForPullback = true;
            
            string boxType = isSupport ? "Support" : "Resistance";
            string signal = isBroken ? "Breakout" : "Hold";
            if(InpBoxDebug < 0 || boxIndex+1 == InpBoxDebug)
               Logging("🟢 BULLISH BOS detected for "+boxType+" "+signal+" at "+DoubleToString(g_BOS[boxIndex].price, _Digits)+" (Box "+IntegerToString(boxIndex+1)+")");
            DrawBOSLevel(g_BOS[boxIndex].name, boxIndex, g_BOS[boxIndex].price, g_BOS[boxIndex].time, true);
         }
      }
   }
   if(needBearishBOS)
   {
      if(L_LastLow.isValid)
      {
         if(currentClose < L_LastLow.price && !g_BOS[boxIndex].isActive)
         {
            if(InpBoxDebug < 0 || boxIndex+1 == InpBoxDebug)
               Logging("→ TRIGGERING BEARISH BOS!");
            g_BOS[boxIndex].name = "BEARISH BOS";
            g_BOS[boxIndex].isBullish = false;
            // Determine BOS price level based on box type
            // if(!isSupport)
            //    g_BOS[boxIndex].price = g_Boxes[boxIndex].bottom; // Use box bottom for resistance hold
            // else
            //    g_BOS[boxIndex].price = g_Boxes[boxIndex].top; // Use box top for support breakout
            g_BOS[boxIndex].price = L_LastLow.price;
            g_BOS[boxIndex].time = TimeCurrent();
            g_BOS[boxIndex].isActive = true;
            g_BOS[boxIndex].barIndex = 0;
            g_BOS[boxIndex].boxIndex = boxIndex;
            g_BOS[boxIndex].magicNumber = InpBOSMagicNumber+(int)DoubleToString(g_BOS[boxIndex].price,0);
            g_Boxes[boxIndex].waitingForPullback = true;
            
            string boxType = isSupport ? "Support" : "Resistance";
            string signal = isBroken ? "Breakout" : "Hold";
            if(InpBoxDebug < 0 || boxIndex+1 == InpBoxDebug)
               Logging("🔴 BEARISH BOS detected for "+boxType+" "+signal+" at "+DoubleToString(g_BOS[boxIndex].price, _Digits)+" (Box "+IntegerToString(boxIndex+1)+")");
            DrawBOSLevel(g_BOS[boxIndex].name, boxIndex, g_BOS[boxIndex].price, g_BOS[boxIndex].time, false);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for entry after BOS pullback                               |
//+------------------------------------------------------------------+
void CheckForEntry(int boxIndex)
{
   // Check if we have an active BOS with valid box index
   if(boxIndex < 0 || boxIndex >= g_BoxCount)
      return;
      
   if(!g_BOS[boxIndex].isActive)
      return;
   
   double currentPrice = iClose(_Symbol, InpLowTF, 0);
   double point = _Point;
   int minPullback = InpBOSPullbackPoints;
   
   // Bullish entry: Wait for pullback to BOS level
   if(g_BOS[boxIndex].isBullish && g_Boxes[boxIndex].waitingForPullback)
   {
      // Check trade direction filter
      if(InpTradeDirection == TRADE_SELL_ONLY)
         return;
      
      // Check if opposite positions exist
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_SELL, g_BOS[boxIndex].magicNumber) > 0)
      {
         Print("Blocked BUY entry - SELL positions already open");
         return;
      }
      
      // Check if price pulled back near BOS level
      double distancePoints = MathAbs(currentPrice - g_BOS[boxIndex].price) / point;
      
      if(distancePoints <= minPullback)
      {
         // Confirm with recent bullish candle
         double prevClose = iClose(_Symbol, InpLowTF, 1);
         double prevOpen = iOpen(_Symbol, InpLowTF, 1);
         
         if(prevClose > prevOpen)
         {
            if(CheckTrendConditions(boxIndex, true))
            {
               if(GetOpenPositionsCount(POSITION_TYPE_BUY, g_BOS[boxIndex].magicNumber) >= g_BOS[boxIndex].maxEntry)
                  return;
               // Execute BUY trade
               Logging("Executing BUY trade at BOS pullback "+DoubleToString(g_BOS[boxIndex].price, _Digits)+" (Box "+IntegerToString(boxIndex+1)+")");
               if(ExecuteBuyTrade(0, g_BOS[boxIndex].magicNumber))
               {
                  g_Boxes[boxIndex].traded = true;
               }
            }
            else
            {
               // Logging or handling when trend conditions are not met
               Print("BUY blocked - Trend not aligned (H8: ", TrendToString(D_Trend),
                     ", H4: ", TrendToString(swH_Trend),
                     ", M5: ", TrendToString(snrH_Trend),
                     ", Box: ", IntegerToString(boxIndex+1), ")");
               // Print("Last higher high? ", lastIsHigherHigh ? "YES" : "NO", 
               //       " | Last lower low? ", lastIsLowerLow ? "YES" : "NO",
               //       " | Is swing high? ", lastSwingWasHigh ? "YES" : "NO");
            }
         }
      }
   }
   // Bearish entry
   else if(!g_BOS[boxIndex].isBullish && g_Boxes[boxIndex].waitingForPullback)
   {
      if(InpTradeDirection == TRADE_BUY_ONLY)
         return;
      
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_BUY, g_BOS[boxIndex].magicNumber) > 0)
      {
         Print("Blocked SELL entry - BUY positions already open");
         return;
      }
      
      double distancePoints = MathAbs(currentPrice - g_BOS[boxIndex].price) / point;
      
      if(distancePoints <= minPullback)
      {
         double prevClose = iClose(_Symbol, InpLowTF, 1);
         double prevOpen = iOpen(_Symbol, InpLowTF, 1);
         
         if(prevClose < prevOpen)
         {
            if(CheckTrendConditions(boxIndex, false))
            {
               if(GetOpenPositionsCount(POSITION_TYPE_SELL, g_BOS[boxIndex].magicNumber) >= g_BOS[boxIndex].maxEntry)
                  return;
               // Execute SELL trade
               Logging("Executing SELL trade at BOS pullback "+DoubleToString(g_BOS[boxIndex].price, _Digits)+" (Box "+IntegerToString(boxIndex+1)+")");
               if(ExecuteSellTrade(0, g_BOS[boxIndex].magicNumber))
               {
                  g_Boxes[boxIndex].traded = true;
               }
            }
            else
            {
               // Logging or handling when trend conditions are not met
               Print("SELL blocked - Trend not aligned (H8: ", TrendToString(D_Trend),
                     ", H4: ", TrendToString(swH_Trend),
                     ", M5: ", TrendToString(snrH_Trend),
                     ", Box: ", IntegerToString(boxIndex+1), ")");
               // Print("Last higher high? ", lastIsHigherHigh ? "YES" : "NO", 
               //       " | Last lower low? ", lastIsLowerLow ? "YES" : "NO",
               //       " | Is swing high? ", lastSwingWasHigh ? "YES" : "NO");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate trend alignment for the signal type                      |
//+------------------------------------------------------------------+
bool CheckTrendConditions(int boxIndex, bool isBuySignal)
{
   // Validate that we should trade retests/breakouts
   if((!InpTradeRetests || !InpTradeBreakouts) && !g_Boxes[boxIndex].drawn)
      return false;

   // Without supertrend filter, allow if not strongly against trend
   if(!InpEnableSupertrend)
   {
      if(isBuySignal)
      {
         // For BUY: allow if not strongly bearish
         if(swH_Trend != TREND_BEARISH || swH_MarketCondition != CLEAR_AND_STRONG_TREND)
            return true;
      }
      else
      {
         // For SELL: allow if not strongly bullish
         if(swH_Trend != TREND_BULLISH || swH_MarketCondition != CLEAR_AND_STRONG_TREND)
            return true;
      }
      return false;
   }

   // Use the actual box's properties to determine context
   bool isSupport = g_Boxes[boxIndex].is_support;
   bool isBroken = g_Boxes[boxIndex].is_broken;
   bool isReheld = g_Boxes[boxIndex].is_reheld;
   
   // BUY signal trend validation
   if(isBuySignal)
   {
      // Initialize with default value
      g_BOS[boxIndex].maxEntry = InpMaxBuyOnBOS;
      bool trendAligned = false;
      
      if(D_Trend == TREND_BEARISH)
      {
         if(D_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE &&
            (swH_MarketCondition == CONSOLIDATE_AND_RANGE || swH_MarketCondition == CLEAR_AND_STRONG_TREND))
         {
            if(swH_Trend == TREND_BEARISH ) // COMPLETED BUT NOT VALIDATED
            {
               if(snrH_Trend == TREND_BEARISH)
               {
                  // In strong bearish trend but all lower timeframes also in range, still consider BUY on support holds
                  if(!isSupport && isBroken) // Resistance broke
                  {
                     if(!lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and all lower timeframes in range
                        trendAligned = true;
                     }
                  }
                  else if(isSupport && !isBroken) // Support held
                  {
                     if(!lastSwingWasHigh || lastIsLowerLow)
                     {
                        // Extra boost if recent swing is high and support holds
                        g_BOS[boxIndex].maxEntry += 1;
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // VALIDATED
               {
                  if(!isSupport && isBroken) // Resistance broke
                  {
                     if(lastSwingWasHigh || lastIsLowerLow) 
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
                  else if(isSupport && !isBroken) // Support held
                  {
                     if(!lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_BULLISH)
               {
                  if(lastSwingWasHigh || lastIsHigherHigh) // lastSwingWasHigh is checked
                  {
                     // Extra boost if recent swing is low and resistance broke
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
            }
            else if(swH_Trend == TREND_SIDEWAYS) // Empty
            {

            }
            else if(swH_Trend == TREND_BULLISH) // Empty
            {

            }

            // In case a Resistance is strong and ready for a breakout
            if(g_Boxes[boxIndex].is_strong && !isSupport)
            {
               // Confirming by lowest trend tf being a sideways
               if(snrH_Trend == TREND_SIDEWAYS && isBroken)
               {
                  if(!lastSwingWasHigh || lastIsLowerLow)
                  {
                     g_BOS[boxIndex].maxEntry += 2; // H4 aligned and M5 sideways
                     trendAligned = true;
                  }
               }
            }
         }
         else if(D_MarketCondition == CLEAR_AND_STRONG_TREND && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            if(swH_Trend == TREND_BEARISH) // Empty
            {

            }
            else if(swH_Trend == TREND_SIDEWAYS) // Support unvalidated
            {
               if(isSupport && !isBroken) // Support held
               {
                  if(lastIsLowerLow) // lastIsLowerLow not checked yet
                  {
                     g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                     trendAligned = true;
                  }
               }
            }
            else if(swH_Trend == TREND_BULLISH) // Empty
            {

            }
         }
      }
      else if(D_Trend == TREND_SIDEWAYS)
      {
         if(swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            // Less strict
            if(isReheld && lastIsLowerLow) // lastIsLowerLow not checked yet
            {
               g_BOS[boxIndex].maxEntry += 1;
               trendAligned = true;
            }
         }
      }
      else if(D_Trend == TREND_BULLISH) // D_Trend == TREND_BULLISH
      {
         if(D_MarketCondition == CLEAR_AND_STRONG_TREND && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE) // Empty
         {
            if(swH_Trend == TREND_BULLISH) // Empty
            {

            }
            else if(swH_Trend == TREND_SIDEWAYS) // Support unvalidated
            {
               
            }
            else if(swH_Trend == TREND_BEARISH) // Empty
            {
               if(snrH_Trend == TREND_BEARISH)
               {
                  if(isSupport && !isBroken) // Support held
                  {
                     if(lastIsHigherHigh) // lastIsHigherHigh checked
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // Support unvalidated
               {
                  
               }
               else if(snrH_Trend == TREND_BULLISH)
               {

               }
            }
         }
         else if(D_MarketCondition == CONSOLIDATE_AND_RANGE && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            if(swH_Trend == TREND_BULLISH) // COMPLETED BUT NOT VALIDATED
            {
               if(snrH_Trend == TREND_BEARISH)
               {
                  if(isReheld && lastSwingWasHigh)
                  {
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // Resistance unvalidated
               {
                  // if(!lastSwingWasHigh)
                  // {
                  //    g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                  //    trendAligned = true;
                  // }
               }
               else if(snrH_Trend == TREND_BULLISH)
               {
                  // In strong bullish trend but all lower timeframes also in range, favorable for BUY on support holds
                  if(isSupport && !isBroken) // Support held
                  {
                     if(!lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and all lower timeframes in range
                        trendAligned = true;
                     }
                  }
                  else if(!isSupport && isBroken) // Resistance broke
                  {
                     if(lastSwingWasHigh || lastIsHigherHigh)
                     {
                        // Extra boost if recent swing is high and resistance broke
                        g_BOS[boxIndex].maxEntry += 1;
                        trendAligned = true;
                     }
                  }

                  // Special case for reheld support in bullish trend
                  if(isReheld && lastSwingWasHigh)
                  {
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
            }
         }
      }
      
      if(!trendAligned)
      {
         // Print("BUY blocked - Trend not aligned (H4: ", TrendToString(D_Trend),
         //       ", H1: ", TrendToString(swH_Trend),
         //       ", M5: ", TrendToString(snrH_Trend),
         //       ", Box: ", IntegerToString(boxIndex+1), ")");
         return false;
      }
      
      Print("BUY trend validated! Last HH? " + (lastIsHigherHigh ? "Yes" : "No") + " | Last LL? " +
                    (lastIsLowerLow ? "Yes" : "No") + " | Last high? " + (lastSwingWasHigh ? "Yes" : "No") +
                    " ("+TFtoString(InpTrendTF)+": " + TrendToString(D_Trend) + ", "+ TFtoString(InpSwingTF) +
                    ": " + TrendToString(swH_Trend) +", " + TFtoString(InpSnRTF) + ": " + TrendToString(snrH_Trend) +
                    " (Box "+IntegerToString(boxIndex+1)+": "+(g_Boxes[boxIndex].is_strong ? "Strong" : "Weak")+")");
      return true;
   }
   // SELL signal trend validation
   else
   {
      // Initialize with default value
      g_BOS[boxIndex].maxEntry = InpMaxSellOnBOS;
      bool trendAligned = false;
      
      if(D_Trend == TREND_BULLISH)
      {
         if(D_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE &&
            (swH_MarketCondition == CONSOLIDATE_AND_RANGE || swH_MarketCondition == CLEAR_AND_STRONG_TREND))
         {
            if(swH_Trend == TREND_BULLISH ) // COMPLETED BUT NOT VALIDATED
            {
               if(snrH_Trend == TREND_BULLISH)
               {
                  // In strong bullish trend but all lower timeframes also in range, favorable for SELL on resistance holds
                  if(isSupport && isBroken) // Support broke
                  {
                     if(lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and all lower timeframes in range
                        trendAligned = true;
                     }
                  }
                  else if(!isSupport && !isBroken) // Resistance held
                  {
                     if(lastSwingWasHigh || lastIsHigherHigh)
                     {
                        // Extra boost if recent swing is low and resistance holds
                        g_BOS[boxIndex].maxEntry += 1;
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // 
               {
                  if(isSupport && isBroken) // Support broke
                  {
                     if(!lastSwingWasHigh || lastIsHigherHigh)
                     {
                           // Extra boost if recent swing is low and support broke}
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
                  else if(!isSupport && !isBroken) // Resistance held
                  {
                     if(lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_BEARISH)
               {
                  if(!lastSwingWasHigh || lastIsLowerLow) // Not checked yet
                  {
                     // Extra boost if recent swing is low and support broke
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
            }
            else if(swH_Trend == TREND_SIDEWAYS) // Empty
            {

            }
            else if(swH_Trend == TREND_BEARISH) // Empty
            {

            }

            // In case a Support is strong and ready for a breakout
            if(g_Boxes[boxIndex].is_strong && isSupport)
            {
               // Confirming by lowest trend tf being a sideways
               if(snrH_Trend == TREND_SIDEWAYS && isBroken)
               {
                  if(lastSwingWasHigh || lastIsHigherHigh)
                  {
                     g_BOS[boxIndex].maxEntry += 2; // H4 aligned and M5 sideways
                     trendAligned = true;
                  }
               }
            }
         }
         else if(D_MarketCondition == CLEAR_AND_STRONG_TREND && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            if(swH_Trend == TREND_BULLISH)
            {
               if(snrH_Trend == TREND_BULLISH) // Empty
               {

               }
               else if(snrH_Trend == TREND_SIDEWAYS) // Resistance checked
               {
                  if(!isSupport && !isBroken) // Resistance held
                  {
                     if(lastIsHigherHigh) // lastIsHigherHigh is checked
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_BEARISH) // Empty
               {

               }
            }
         }
      }
      else if(D_Trend == TREND_SIDEWAYS)
      {
         if(swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            // Less strict
            if(isReheld && lastIsHigherHigh) // not yet checked
            {
               g_BOS[boxIndex].maxEntry += 1;
               trendAligned = true;
            }
         }
      }
      else if(D_Trend == TREND_BEARISH) // D_Trend == TREND_BEARISH
      {
         if(D_MarketCondition == CLEAR_AND_STRONG_TREND && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE) // Empty
         {
            if(swH_Trend == TREND_BEARISH) // Empty
            {

            }
            else if(swH_Trend == TREND_SIDEWAYS) // Resistance unvalidated
            {

            }
            else if(swH_Trend == TREND_BULLISH) // Empty
            {
               if(snrH_Trend == TREND_BULLISH)
               {
                  if(!isSupport && !isBroken) // Resistance held
                  {
                     if(lastIsLowerLow) // lastIsLowerLow not yet checked
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                        trendAligned = true;
                     }
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // Resistance unvalidated
               {

               }
               else if(snrH_Trend == TREND_BEARISH)
               {

               }
            }
         }
         else if(D_MarketCondition == CONSOLIDATE_AND_RANGE && swH_MarketCondition == CONSOLIDATE_AND_RANGE && snrH_MarketCondition == CONSOLIDATE_AND_RANGE)
         {
            if(swH_Trend == TREND_BEARISH) // COMPLETED BUT NOT VALIDATED
            {
               if(snrH_Trend == TREND_BULLISH)
               {
                  // Special case for reheld resistance in bearish trend
                  if(isReheld && !lastSwingWasHigh)
                  {
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
               else if(snrH_Trend == TREND_SIDEWAYS) // Support unvalidated
               {
                  // if(lastSwingWasHigh)
                  // {
                  //    g_BOS[boxIndex].maxEntry += 1; // H4 aligned and M5 sideways
                  //    trendAligned = true;
                  // }
               }
               else if(snrH_Trend == TREND_BEARISH)
               {
                  // In strong bearish trend but all lower timeframes also in range, still consider SELL on resistance holds
                  if(!isSupport && !isBroken) // Resistance held
                  {
                     if(lastSwingWasHigh)
                     {
                        g_BOS[boxIndex].maxEntry += 1; // H4 aligned and all lower timeframes in range
                        trendAligned = true;
                     }
                  }
                  else if(isSupport && isBroken) // Support broke
                  {
                     if(!lastSwingWasHigh || lastIsLowerLow)
                     {
                        // Extra boost if recent swing is low and support broke
                        g_BOS[boxIndex].maxEntry += 1;
                        trendAligned = true;
                     }
                  }

                  // Special case for reheld resistance in bearish trend
                  if(isReheld && !lastSwingWasHigh)
                  {
                     g_BOS[boxIndex].maxEntry += 1;
                     trendAligned = true;
                  }
               }
            }
         }
      }

      if(!trendAligned)
      {
         // Print("SELL blocked - Trend not aligned (H4: ", TrendToString(D_Trend),
         //       ", H1: ", TrendToString(swH_Trend),
         //       ", M5: ", TrendToString(snrH_Trend),
         //       ", Box: ", IntegerToString(boxIndex+1), ")");
         return false;
      }
      
      Print("SELL trend validated! Last HH? " + (lastIsHigherHigh ? "Yes" : "No") + " | Last LL? " +
                    (lastIsLowerLow ? "Yes" : "No") + " | Last high? " + (lastSwingWasHigh ? "Yes" : "No") +
                    " ("+TFtoString(InpTrendTF)+": " + TrendToString(D_Trend) + ", "+ TFtoString(InpSwingTF) +
                    ": " + TrendToString(swH_Trend) +", " + TFtoString(InpSnRTF) + ": " + TrendToString(snrH_Trend) +
                    " (Box "+IntegerToString(boxIndex+1)+": "+(g_Boxes[boxIndex].is_strong ? "Strong" : "Weak")+")");
      return true;
   }
}

//+------------------------------------------------------------------+
//| Final entry validation with all conditions                        |
//+------------------------------------------------------------------+
void CheckEntryLevel(int boxIndex)
{
   // Validate box index
   if(boxIndex < 0 || boxIndex >= g_BoxCount)
   {
      return;
   }
   
   // Skip if box is not drawn
   if(!g_Boxes[boxIndex].drawn)
   {
      return;
   }
   
   // Determine trade direction based on box properties
   bool isBuySignal = false;
   bool isSellSignal = false;
   
   // Use the actual box's properties to determine signal direction
   bool isSupport = g_Boxes[boxIndex].is_support;
   bool isBroken = g_Boxes[boxIndex].is_broken;
   bool isReheld = g_Boxes[boxIndex].is_reheld;
   
   // Determine signal type from box state
   if(isBroken)
   {
      // Breakout scenario
      if(!isSupport) // Resistance broke
      {
         if(isReheld)
            isSellSignal = true;
         else
            isBuySignal = true;
      }
      else // Support broke
      {
         if(isReheld)
            isBuySignal = true;
         else
            isSellSignal = true;
      }
   }
   else
   {
      // Hold scenario
      if(isSupport) // Support held
         isBuySignal = true;
      else // Resistance held
         isSellSignal = true;
   }
   
   // Validate BUY conditions
   if(isBuySignal && InpBuySignals)
   {
      // Check trade direction filter
      if(InpTradeDirection == TRADE_SELL_ONLY)
      {
         Print("BUY blocked - Trade direction set to SELL_ONLY");
         return;
      }

      // // Validate trend alignment using centralized function
      // if(!CheckTrendConditions(boxIndex, true))
      // {
      //    return;
      // }
      
      // Additional confirmation: check pullback to level with bullish candle (like BOS)
      double currentPrice = iClose(_Symbol, InpLowTF, 0);
      double point = _Point;
      double referencePrice = g_Boxes[boxIndex].top;
      double distancePoints = MathAbs(currentPrice - referencePrice) / point;
      
      // Allow trade if:
      // 1. First time (!traded), OR
      // 2. Re-testing after previous trade (traded) AND price pulled back near level with candle confirmation
      bool allowTrade = false;
      
      if(!g_Boxes[boxIndex].traded)
      {
         // First trade - just need to be near the level
         if(distancePoints <= InpSnRPullbackPoints)
         {
            allowTrade = true;

            if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
               CheckForBOS(boxIndex);
         }
      }
      else
      {
         // Re-test after previous trade - require pullback confirmation
         if(distancePoints <= InpSnRPullbackPoints)
         {
            // Confirm with recent bullish candle
            double prevClose = iClose(_Symbol, InpLowTF, 1);
            double prevOpen = iOpen(_Symbol, InpLowTF, 1);
            
            if(isReheld)
            {
               allowTrade = true;

               if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
                  CheckForBOS(boxIndex);
            }
            else if(prevClose > prevOpen) // Bullish confirmation
            {
               allowTrade = true;

               if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
                  CheckForBOS(boxIndex);
            }
            else
               Print("BUY re-test blocked - No bullish confirmation candle. Last HH? " + (lastIsHigherHigh ? "Yes" : "No") + " | Last LL? " +
                    (lastIsLowerLow ? "Yes" : "No") + " | Is swing high? " + (lastSwingWasHigh ? "Yes" : "No") + " (Box "+IntegerToString(boxIndex+1)+")");
         }
         else if(distancePoints <= InpSnRPullbackPoints * 1.5)
            Print("BUY re-test blocked - Price too far from level: ", DoubleToString(distancePoints, 0), " points (Box "+IntegerToString(boxIndex+1)+")");
      }
      
      if(!allowTrade)
      {
         return;
      }
   }
   // Validate SELL conditions
   else if(isSellSignal && InpSellSignals)
   {
      // Check trade direction filter
      if(InpTradeDirection == TRADE_BUY_ONLY)
      {
         Print("SELL blocked - Trade direction set to BUY_ONLY");
         return;
      }
           
      // // Validate trend alignment using centralized function
      // if(!CheckTrendConditions(boxIndex, false))
      // {
      //    return;
      // }
      
      // Additional confirmation: check pullback to level with bearish candle (like BOS)
      double currentPrice = iClose(_Symbol, InpLowTF, 0);
      double point = _Point;
      double referencePrice = g_Boxes[boxIndex].bottom;
      double distancePoints = MathAbs(currentPrice - referencePrice) / point;
      
      // Allow trade if:
      // 1. First time (!traded), OR
      // 2. Re-testing after previous trade (traded) AND price pulled back near level with candle confirmation
      bool allowTrade = false;
      
      if(!g_Boxes[boxIndex].traded)
      {
         // First trade - just need to be near the level
         if(distancePoints <= InpSnRPullbackPoints)
         {
            allowTrade = true;

            if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
               CheckForBOS(boxIndex);
         }
      }
      else
      {
         // Re-test after previous trade - require pullback confirmation
         if(distancePoints <= InpSnRPullbackPoints)
         {
            // Confirm with recent bearish candle
            double prevClose = iClose(_Symbol, InpLowTF, 1);
            double prevOpen = iOpen(_Symbol, InpLowTF, 1);
            
            if(isReheld)
            {
               allowTrade = true;

               if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
                  CheckForBOS(boxIndex);
            }
            else if(prevClose < prevOpen) // Bearish confirmation
            {
               allowTrade = true;

               if(InpUseBOSValidation && !g_Boxes[boxIndex].waitingForPullback)
                  CheckForBOS(boxIndex);
            }
            else
               Print("SELL re-test blocked - No bearish confirmation candle. Last HH? " + (lastIsHigherHigh ? "Yes" : "No") + " | Last LL? " +
                    (lastIsLowerLow ? "Yes" : "No") + " | Is swing high? " + (lastSwingWasHigh ? "Yes" : "No") + " (Box "+IntegerToString(boxIndex+1)+")");
         }
         else if(distancePoints <= InpSnRPullbackPoints * 1.5)
            Print("SELL re-test blocked - Price too far from level: ", DoubleToString(distancePoints, 0), " points (Box "+IntegerToString(boxIndex+1)+")");
      }
      
      if(!allowTrade)
      {
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Buy Trade                                                |
//+------------------------------------------------------------------+
bool ExecuteBuyTrade(double price = 0, int magicNumber = 0)
{
   // Set magic number for this trade
   if(magicNumber == 0)
      magicNumber = InpSnRMagicNumber; // Default to S&R magic
   
   trade.SetExpertMagicNumber(magicNumber);
   
   if(price <= 0)
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double ask = price;
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
      double atr = CalculateATR(200, 0, PERIOD_D1);
      sl = NormalizeDouble(ask - atr * 3, _Digits);
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      datetime barTime = iTime(_Symbol, InpSnRTF, 0);
      bool hasRejection = HasRejectionCandle(InpTrendTF, 0, false); // Check for bearish rejection

      if(hasRejection)
         tp = ask + InpTakeProfit * pipSize * 0.5; // Reduced TP 50% in sideways markets
      else
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
   
   // Build comment - BOS trades use g_BOS[].boxIndex to find which box
   string comment = InpTradeComment;
   if(magicNumber == InpSnRMagicNumber)
   {
      // Find which box this magic number belongs to
      for(int i=0; i<g_BoxCount; i++)
      {
         if(g_BOS[i].isActive && g_BOS[i].magicNumber == magicNumber)
         {
            comment = InpTradeComment + "_Box" + IntegerToString(i+1);
            break;
         }
      }
   }
   
   if(trade.Buy(lotSize, _Symbol, ask, sl, tp, comment))
   {
      Print("BUY order opened - Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
      // waitingForPullback = false;
      // BOS.isActive = false;
      return true;
   }
   else
   {
      Print("Failed to open BUY order. Error: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Trade                                               |
//+------------------------------------------------------------------+
bool ExecuteSellTrade(double price = 0, int magicNumber = 0)
{
   // Set magic number for this trade
   if(magicNumber == 0)
      magicNumber = InpSnRMagicNumber; // Default to S&R magic
   
   trade.SetExpertMagicNumber(magicNumber);
   
   if(price <= 0)
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double bid = price;
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
      double atr = CalculateATR(200, 0, PERIOD_D1);
      sl = NormalizeDouble(bid + atr * 3, _Digits);
   }
   
   // Use input TP if specified, otherwise use automatic from swing points
   if(InpTakeProfit > 0)
   {
      datetime barTime = iTime(_Symbol, InpSnRTF, 0);
      bool hasRejection = HasRejectionCandle(InpTrendTF, 0, true); // Check for bullish rejection

      if(hasRejection)
         tp = bid - InpTakeProfit * pipSize * 0.5; // Reduced TP 50% in sideways markets
      else
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
   
   // Build comment - BOS trades use g_BOS[].boxIndex to find which box
   string comment = InpTradeComment;
   if(magicNumber == InpSnRMagicNumber)
   {
      // Find which box this magic number belongs to
      for(int i=0; i<g_BoxCount; i++)
      {
         if(g_BOS[i].isActive && g_BOS[i].magicNumber == magicNumber)
         {
            comment = InpTradeComment + "_Box" + IntegerToString(i+1);
            break;
         }
      }
   }
   
   if(trade.Sell(lotSize, _Symbol, bid, sl, tp, comment))
   {
      Print("SELL order opened - Entry: ", bid, " | SL: ", sl, " | TP: ", tp);
      // waitingForPullback = false;
      // BOS.isActive = false;
      return true;
   }
   else
   {
      Print("Failed to open SELL order. Error: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Get Open Positions Count (optionally filtered by type)           |
//+------------------------------------------------------------------+
int GetOpenPositionsCount(ENUM_POSITION_TYPE posType = -1, int magicNumber = 0)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         
         long posMagic = PositionGetInteger(POSITION_MAGIC);
         
         // If magic number specified, filter by it
         // Otherwise check if position belongs to either BOS or S&R system
         bool magicMatch = false;
         if(magicNumber != 0)
            magicMatch = (posMagic == magicNumber);
         else
            magicMatch = (posMagic == InpBOSMagicNumber || posMagic == InpSnRMagicNumber);
         
         if(magicMatch)
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
//| Reset box counters when no positions exist for that box          |
//+------------------------------------------------------------------+
void ResetBoxCountersIfClosed()
{
   // Check each box
   for(int boxIdx = 0; boxIdx < g_BoxCount; boxIdx++)
   {
      // Only check boxes that have been traded
      if(!g_Boxes[boxIdx].traded)
         continue;
      
      // Check if any positions exist for this box
      bool hasOpenPositions = false;
      string boxMarker = "_Box" + IntegerToString(boxIdx);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
            
            long posMagic = PositionGetInteger(POSITION_MAGIC);
            if(posMagic != InpSnRMagicNumber)
               continue;
            
            string posComment = PositionGetString(POSITION_COMMENT);
            
            // Check if this position belongs to our box
            if(StringFind(posComment, boxMarker) >= 0)
            {
               hasOpenPositions = true;
               break;
            }
         }
      }
      
      // If no positions exist for this box, reset counters
      if(!hasOpenPositions)
      {
         bool needsReset = (g_Boxes[boxIdx].buyOnHold_count > 0 || 
                           g_Boxes[boxIdx].buyOnBreakout_count > 0 ||
                           g_Boxes[boxIdx].sellOnHold_count > 0 ||
                           g_Boxes[boxIdx].sellOnBreakout_count > 0);
         
         if(needsReset)
         {
            Print("Resetting counters for Box ", boxIdx + 1, " - No open positions");
            g_Boxes[boxIdx].buyOnHold_count = 0;
            g_Boxes[boxIdx].buyOnBreakout_count = 0;
            g_Boxes[boxIdx].sellOnHold_count = 0;
            g_Boxes[boxIdx].sellOnBreakout_count = 0;
            // g_Boxes[boxIdx].traded = false;
            // g_Boxes[boxIdx].traded_count = 0;
         }
      }
   }
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
void ApplyTrailingStop(int magicNumber = 0)
{
   // double pipSize = (_Digits == 5 || _Digits == 3) ? 10 * _Point : _Point;
   double trailDistance = InpTrailingStop * _Point;
   trailDistance *= 0.5; // Decrease trailing distance by 50% to reduce whipsaws
   double trailStep = InpTrailingStep * _Point;
   
   int totalPositions = PositionsTotal();
   int processedCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      
      long posMagic = PositionGetInteger(POSITION_MAGIC);
      
      // If magic number specified, filter by exact match
      // Otherwise apply to BOS trades (any magic >= InpBOSMagicNumber to catch all BOS instances)
      bool magicMatch = false;
      if(magicNumber != 0)
         magicMatch = (posMagic == magicNumber);
      else
         magicMatch = (posMagic >= InpBOSMagicNumber); // Match all BOS trades
      // Logging("  Position #"+ IntegerToString(ticket)+ " | Magic: "+ IntegerToString(posMagic)+ " | Match: YES");
      if(!magicMatch)
         continue;
      


      // if(posMagic==InpSnRMagicNumber)
      // {  
      //    trailDistance*=2.0; // Double trailing distance for S&R trades
      //    // trailStep*=1.5; // Double trailing step for S&R trades
      // }
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

      bool isProfitable = (posType == POSITION_TYPE_BUY) ? (currentPrice > posOpenPrice) : (currentPrice < posOpenPrice);
      
      // Print("    Type: ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " | Entry: ", posOpenPrice, " | Current: ", currentPrice, " | SL: ", posSL, " | Profitable: ", (isProfitable ? "YES" : "NO"));
      
      double newSL = 0;
      double newTP = 0;
      bool needUpdate = false;
      
      if(posType == POSITION_TYPE_BUY)
      {
         // Apply normal trailing stop
         newSL = NormalizeDouble(currentPrice - trailDistance, _Digits);
         newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);

         // Apply normal trailing take profit
         newTP = NormalizeDouble(currentPrice + trailDistance/1.8, _Digits);
         newTP = NormalizeDouble(MathRound(newTP / tickSize) * tickSize, _Digits);
         
         // Validate: new SL must be below current price and above entry
         if(newSL >= currentPrice)
            continue; // Skip invalid SL

         // Validate: new TP must be above current price and above entry
         if(newTP <= currentPrice)
            continue; // Skip invalid TP
         
         // Check if we should update (price moved enough and new SL is better and new TP is better)
         if((posSL == 0 || (newSL > posSL && (newSL - posSL) >= trailStep)) && (posTP == 0 || (newTP > posTP && (newTP - posTP) >= trailStep)))
            needUpdate = true;
      }
      else // POSITION_TYPE_SELL
      {
         // Apply normal trailing stop
         newSL = NormalizeDouble(currentPrice + trailDistance, _Digits);
         newSL = NormalizeDouble(MathRound(newSL / tickSize) * tickSize, _Digits);

         // Apply normal trailing take profit
         newTP = NormalizeDouble(currentPrice - trailDistance/1.8, _Digits);
         newTP = NormalizeDouble(MathRound(newTP / tickSize) * tickSize, _Digits);

         // Validate: new SL must be above current price and below entry
         if(newSL <= currentPrice)
            continue; // Skip invalid SL

         // Validate: new TP must be below current price and below entry
         if(newTP >= currentPrice)
            continue; // Skip invalid TP
         
         // Check if we should update (price moved enough and new SL is better and TP is better)
         if((posSL == 0 || (newSL < posSL && (posSL - newSL) >= trailStep)) && (posTP == 0 || (newTP < posTP && (posTP - newTP) >= trailStep)))
            needUpdate = true;
      }
      
      // Print("    Need Update: ", (needUpdate ? "YES" : "NO"), " | New SL: ", newSL);
      
      if(needUpdate)
      {
         // Print("    → Attempting to modify SL to ", newSL);
         newSL = NormalizeDouble(newSL, _Digits);
         newTP = NormalizeDouble(newTP, _Digits);
         
         // // Get broker's minimum stop level
         // double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         // double currentPriceForCheck = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         // // Validate minimum distance from current price
         // if((posType == POSITION_TYPE_BUY && (currentPriceForCheck - newSL) < minStopLevel) ||
         //    (posType == POSITION_TYPE_SELL && (newSL - currentPriceForCheck) < minStopLevel))
         // {
         //    Print("Warning: New SL too close to market. MinStopLevel: ", minStopLevel, " | Distance: ", 
         //          (posType == POSITION_TYPE_BUY ? currentPriceForCheck - newSL : newSL - currentPriceForCheck));
         //    continue;
         // }
         
         if(trade.PositionModify(ticket, newSL, newTP))
         {
            // Logging("    ✓ SL modified successfully to "+ DoubleToString(newSL, _Digits)+" for position #"+IntegerToString(ticket));
         }
         else
         {
            int errorCode = GetLastError();
            // Print("    ✗ Failed to modify SL. Error: ", errorCode, " | Old SL: ", posSL, " | New SL: ", newSL);
            // Print("Failed to modify position #", ticket, ". Error: ", errorCode,
            //       " | Current Price: ", currentPriceForCheck,
            //       " | Old SL: ", posSL,
            //       " | New SL: ", newSL,
            //       " | TP: ", posTP);
         }
      }
   }
   
   // Log END message only if positions were processed
   if(processedCount > 0)
   {
      // Print("=== ApplyTrailingStop END === Processed: ", processedCount, " positions");
   }
}

//+------------------------------------------------------------------+
//| Close All Positions by Type                                      |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE posType, int magicNumber = 0)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         
         if(PositionGetInteger(POSITION_TYPE) != posType)
            continue;
         
         long posMagic = PositionGetInteger(POSITION_MAGIC);
         
         // If magic number specified, filter by it
         // Otherwise check if position belongs to either BOS or S&R system
         bool magicMatch = false;
         if(magicNumber != 0)
            magicMatch = (posMagic == magicNumber);
         else
            magicMatch = (posMagic == InpBOSMagicNumber || posMagic == InpSnRMagicNumber);
         
         if(magicMatch)
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

