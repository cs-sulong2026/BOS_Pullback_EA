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

   // Print("\n──────────────────────────────────────────────────");
   // Print("⏰ New "+EnumToString(timeframe)+" Bar Detected: ", TimeToString(currentBarTime, TIME_DATE|TIME_MINUTES));
   // Print("──────────────────────────────────────────────────");
   
   int lookback = InpLookbackPeriod;
   int foundHighs = 0;
   int foundLows = 0;

   // // Calculate delta volume
   // double deltaVol = UpAndDownVolume(lookback, PERIOD_H4);
   // double volHi = GetHighestVolume(InpVolFilterLen, lookback, PERIOD_H4);
   // double volLo = GetLowestVolume(InpVolFilterLen, lookback, PERIOD_H4);
   
   // Print("   Delta Volume: ", deltaVol, " | High Filter: ", volHi, " | Low Filter: ", volLo);
   
   // // Find pivots
   // double pivotHigh = 0.0;
   // double pivotLow = 0.0;

   // Temporary storage for newly found pivots
   PivotPoint tempLastHigh;
   PivotPoint tempPrevHigh;
   PivotPoint tempLastLow;
   PivotPoint tempPrevLow;

   // Initialize temp pivots
   tempLastHigh.isValid = false;
   tempPrevHigh.isValid = false;
   tempLastLow.isValid = false;
   tempPrevLow.isValid = false;

   // Search for pivot highs
   for(int i = InpPivotRightBars; i < lookback && foundHighs < 2; i++)
   {
      if(IsPivotHigh(i, timeframe))
      {
         double highPrice = iHigh(_Symbol, timeframe, i);
         datetime highTime = iTime(_Symbol, timeframe, i);

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

   // Search for pivot lows
   for(int i = InpPivotRightBars; i < lookback && foundLows < 2; i++)
   {
      if(IsPivotLow(i, timeframe))
      {
         double lowPrice = iLow(_Symbol, timeframe, i);
         datetime lowTime = iTime(_Symbol, timeframe, i);

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

   // Update htfLastHigh if new pivot found
   if(tempLastHigh.isValid)
   {
      if(!lastHigh.isValid || tempLastHigh.time > lastHigh.time)
      {
         // Only cascade if we didn't find tempPrevHigh
         if(!tempPrevHigh.isValid && lastHigh.isValid)
            prevHigh = lastHigh;
            
         lastHigh = tempLastHigh;

         // Ignore drawing pivot points for current timeframe
         if(timeframe != InpLowTF)
            DrawPivotPoints("HH", timeframe, lastHigh);
      }
   }
   
   // Update prevHigh - prefer tempPrevHigh if found
   if(tempPrevHigh.isValid)
   {
      prevHigh = tempPrevHigh;
      
      // Ignore drawing pivot points for current timeframe
      if(timeframe != InpLowTF)
         DrawPivotPoints("hh", timeframe, prevHigh);
   }

   // Update htfLastLow if new pivot found
   if(tempLastLow.isValid)
   {
      if(!lastLow.isValid || tempLastLow.time > lastLow.time)
      {
         // Only cascade if we didn't find tempPrevLow
         if(!tempPrevLow.isValid && lastLow.isValid)
            prevLow = lastLow;
            
         lastLow = tempLastLow;
         
         // Ignore drawing pivot points for BOS timeframe
         if(timeframe != InpLowTF)
            DrawPivotPoints("LL", timeframe, lastLow);
      }
   }
   
   // Update prevLow - prefer tempPrevLow if found
   if(tempPrevLow.isValid)
   {
      prevLow = tempPrevLow;

      // Ignore drawing pivot points for BOS timeframe
      if(timeframe != InpLowTF)
         DrawPivotPoints("ll", timeframe, prevLow);
   }
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
//|
//+------------------------------------------------------------------+
void AnalyzePreviousLevels(ENUM_TIMEFRAMES timeframe, int shift)
{
   if(g_BoxCount == 2)
      return;
   // Analyze the previous bar to catch missed levels
   AnalyzeLevels(timeframe, shift * 5);
}

//+------------------------------------------------------------------+
//| Check for trading signals                                       |
//+------------------------------------------------------------------+
void CheckTradingSignals(ENUM_TIMEFRAMES timeframe, int shift, 
                         bool hasSupport, double supportTop, double supportBottom,
                         bool hasResistance, double resistanceTop, double resistanceBottom,
                         double volume, double width)
{
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
         // Print("         Box[", i, "] SUPPORT: Top=", g_Boxes[i].top, " Bottom=", g_Boxes[i].bottom, 
         //       " | Traded=", g_Boxes[i].traded, " | Broken=", g_Boxes[i].is_broken);
         
         // Support breakout validated on snr tf = SELL signal
         prevHigh = iHigh(_Symbol, InpSnRTF, shift + 1);
         currHigh = iHigh(_Symbol, InpSnRTF, shift);
         bool breakoutSup = (prevHigh >= g_Boxes[i].bottom && currHigh < g_Boxes[i].bottom);
         
         // Support hold = BUY signal (retest)
         bool supHolds = (prevLow <= g_Boxes[i].top && currLow > g_Boxes[i].top);
         
         if(breakoutSup) Print("            🔴 Support BREAKOUT detected!");
         if(supHolds) Print("            🟢 Support HOLD detected!");
         
         if(breakoutSup && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_SupIsResistance = true;
            Print("            ⚡ Support broken! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, true);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "SUP", true);
            
            // SELL on support break
            if(InpTradeBreakouts && InpSellSignals && !g_Boxes[i].traded)
            {
               // Print("            ➤ Opening SELL on support break");
               CreateBreakoutLabel(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "Break Sup", false);
               // OpenTrade(ORDER_TYPE_SELL, "Support Break", g_Boxes[i].top);
               // CheckForBreakout(i);
               g_Boxes[i].traded = true;
            }
            else
            {
               // Print("            ✗ Trade blocked: Breakouts=", InpTradeBreakouts, 
               //       " | SellSignals=", InpSellSignals, " | AlreadyTraded=", g_Boxes[i].traded);
            }
         }
         
         if(supHolds && !g_Boxes[i].traded)
         {
            g_Boxes[i].is_broken = false;
            g_SupIsResistance = false;
            Print("            ⚡ Support held! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "SUP", false);
            
            // BUY on support hold
            if(InpTradeRetests && InpBuySignals)
            {
               // Print("            ➤ Opening BUY on support hold");
               // OpenTrade(ORDER_TYPE_BUY, "Support Hold", g_Boxes[i].bottom);
               // CheckForHold(i);
               // g_Boxes[i].traded = true;
               // Increment specific counter based on signal type
            }
            else
            {
               // Print("            ✗ Trade blocked: Retests=", InpTradeRetests, 
               //       " | BuySignals=", InpBuySignals);
            }
         }

         if(supHolds && g_Boxes[i].is_broken && g_Boxes[i].traded)
         {
            // Reset broken status if support held after being broken
            g_Boxes[i].is_reheld = true;
            g_Boxes[i].is_broken = false;
            g_SupIsResistance = false;
            // g_Boxes[i].traded = false;
            g_Boxes[i].break_count = 1;
            g_Boxes[i].hold_count = 0;
            // g_Boxes[i].box_hold_limit = 20;
            g_Boxes[i].buyOnHold_count = 0;
            // g_Boxes[i].buyOnHold_limit = 4;
            g_Boxes[i].sellOnBreakout_count = 0;
            // g_Boxes[i].sellOnBreakout_limit = 4;
            // holdLimit = 100;
            // breakLimit = 100;
            Logging("            ⚡ Support re-held after break!");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "SUP", false);
         }
      }
      else // Resistance
      {
         // Print("         Box[", i, "] RESISTANCE: Top=", g_Boxes[i].top, " Bottom=", g_Boxes[i].bottom,
         //       " | Traded=", g_Boxes[i].traded, " | Broken=", g_Boxes[i].is_broken);
         
         // Resistance breakout validated on snr tf = BUY signal
         prevLow = iLow(_Symbol, InpSnRTF, shift + 1);
         currLow = iLow(_Symbol, InpSnRTF, shift);
         bool breakoutRes = (prevLow <= g_Boxes[i].top && currLow > g_Boxes[i].top);
         
         // Resistance hold = SELL signal (retest)
         bool resHolds = (prevHigh >= g_Boxes[i].bottom && currHigh < g_Boxes[i].bottom);
         
         if(breakoutRes) Print("            🟢 Resistance BREAKOUT detected! Top= "+DoubleToString(g_Boxes[i].top,_Digits));
         if(resHolds) Print("            🔴 Resistance HOLD detected! Bottom= "+DoubleToString(g_Boxes[i].bottom,_Digits));
         
         if(breakoutRes && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_ResIsSupport = true;
            Print("            ⚡ Resistance broken! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, true);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "RES", true);
            
            // BUY on resistance break
            if(InpTradeBreakouts && InpBuySignals && !g_Boxes[i].traded)
            {
               // Print("            ➤ Opening BUY on resistance break");
               CreateBreakoutLabel(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "Break Res", true);
               // OpenTrade(ORDER_TYPE_BUY, "Resistance Break", g_Boxes[i].bottom);
               // CheckForBreakout(i);
               g_Boxes[i].traded = true;
            }
            else
            {
               // Print("            ✗ Trade blocked: Breakouts=", InpTradeBreakouts,
               //       " | BuySignals=", InpBuySignals, " | AlreadyTraded=", g_Boxes[i].traded);
            }
         }
         
         if(resHolds && !g_Boxes[i].traded)
         {
            g_Boxes[i].is_broken = false;
            g_ResIsSupport = false;
            Print("            ⚡ Resistance held! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "RES", false);
            
            // SELL on resistance hold
            if(InpTradeRetests && InpSellSignals)
            {
               // Print("            ➤ Opening SELL on resistance hold");
               // OpenTrade(ORDER_TYPE_SELL, "Resistance Hold", g_Boxes[i].top);
               // CheckForHold(i);
               // g_Boxes[i].traded = true;
            }
            else
            {
               // Print("            ✗ Trade blocked: Retests=", InpTradeRetests,
               //       " | SellSignals=", InpSellSignals);
            }
         }

         if(resHolds && g_Boxes[i].is_broken && g_Boxes[i].traded)
         {
            // Reset broken status if resistance held after being broken
            g_Boxes[i].is_reheld = true;
            g_Boxes[i].is_broken = false;
            g_ResIsSupport = false;
            // g_Boxes[i].traded = false;
            g_Boxes[i].break_count = 1;
            g_Boxes[i].hold_count = 0;
            // g_Boxes[i].box_hold_limit = 20;
            g_Boxes[i].sellOnHold_count = 0;
            // g_Boxes[i].sellOnHold_limit = 4;
            g_Boxes[i].buyOnBreakout_count = 0;
            // g_Boxes[i].buyOnBreakout_limit = 4;
            // holdLimit = 100;
            // breakLimit = 100;
            Logging("            ⚡ Resistance re-held after break!");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "RES", false);
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

      // int buy_Limit = g_Boxes[i].buyOnHold_limit;
      // int sell_Limit = g_Boxes[i].sellOnHold_limit;
      // if(g_Boxes[i].is_reheld && (g_Boxes[i].buyOnHold_count >= buy_Limit || g_Boxes[i].sellOnHold_count >= sell_Limit))
      // {
      //    // Print("      ⚡ Removing re-held box after hold limit reached: ", g_Boxes[i].name);
      //    // Delete box visuals
      //    ObjectDelete(0, g_Boxes[i].name);
      //    ObjectDelete(0, g_Boxes[i].name + "_label");
         
      //    // Remove box from array
      //    for(int j = i; j < g_BoxCount - 1; j++)
      //       g_Boxes[j] = g_Boxes[j + 1];
      //    g_BoxCount--;
      //    i--; // Adjust index after removal
      // }
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
//+------------------------------------------------------------------+
void DrawPivotPoints(string name, ENUM_TIMEFRAMES chartTF, PivotPoint &lastPoint)
{
   if(!lastPoint.isValid)
      return;
   
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
         // Resistance - Red
         labelColor = ColorWithAlpha(clrBrown, 128);
         labelText = tfString + "\n" + ((name == "HH") ? "HH" : "LL");
      }
      else
      {
         // Support - Green
         labelColor = ColorWithAlpha(clrTeal, 128);
         labelText = tfString + "\n" + ((name == "hh") ? "hh" : "ll");
      }

      ObjectSetString(0, objName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
      
      // Set anchor based on pivot type - highs below, lows above
      if(name == "HH" || name == "hh")
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
   double duplicateThreshold = boxHeight * 0.5; // 50% overlap threshold
   
   for(int i = 0; i < g_BoxCount; i++)
   {
      // Check if boxes are same type (both support or both resistance)
      if(g_Boxes[i].is_support != isSupport)
         continue;
      
      // Calculate center and overlap
      double existingCenter = (g_Boxes[i].top + g_Boxes[i].bottom) / 2.0;
      double priceDiff = MathAbs(priceCenter - existingCenter);
      
      // If centers are very close, consider it a duplicate
      if(priceDiff < duplicateThreshold)
      {
         // Print("   ⚠️ Duplicate box detected at ", DoubleToString(priceCenter, _Digits),
         //       " (existing: ", DoubleToString(existingCenter, _Digits), ") - Skipping");
         return; // Skip adding duplicate
      }
   }
   
   if(g_BoxCount >= MAX_BOXES)
   {
      Print("   ⚠️ Box limit reached, removing oldest box");
      // Delete oldest box visuals
      ObjectDelete(0, g_Boxes[0].name);
      ObjectDelete(0, g_Boxes[0].name + "_label");
      
      // Remove oldest box
      for(int i = 0; i < MAX_BOXES - 1; i++)
         g_Boxes[i] = g_Boxes[i + 1];
      g_BoxCount = MAX_BOXES - 1;
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
   
   // Determine colors
   color bgColor, borderColor;
   if(isSupport)
   {
      bgColor = ColorWithAlpha(clrLightGreen, 128);
      borderColor = ColorWithAlpha(clrGreen, 128);
   }
   else
   {
      bgColor = ColorWithAlpha(clrLightPink, 128);
      borderColor = ColorWithAlpha(clrRed, 128);
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
      newBorderColor = g_Boxes[index].is_support ? ColorWithAlpha(clrDarkRed, 128) : ColorWithAlpha(clrDarkGreen, 128);
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
//+------------------------------------------------------------------+
void HideBox(int index)
{
   if(index < 0 || index >= g_BoxCount)
      return;
      
   if(g_Boxes[index].name == "" || !g_Boxes[index].drawn)
      return;
      
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(0, g_Boxes[index].name + "_label", OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void ShowBox(int index)
{
   if(index < 0 || index >= g_BoxCount)
      return;
      
   if(g_Boxes[index].name == "" || !g_Boxes[index].drawn)
      return;
      
   ObjectSetInteger(0, g_Boxes[index].name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, g_Boxes[index].name + "_label", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
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
         ShowBox(boxIdx);
         CheckForBreakout(boxIdx);
         CheckForHold(boxIdx);
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
               CheckForBreakout(i);
               CheckForHold(i);
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
            CheckForBreakout(i);
            CheckForHold(i);
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
void CreateBreakoutLabel(datetime time, double price, string text, bool isUp)
{
   string name = "BreakLabel_" + IntegerToString(time);
   
   if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ColorWithAlpha(clrYellow, 128));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, isUp ? ANCHOR_LOWER : ANCHOR_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Check for Entry after Pullback (BOS)                             |
//+------------------------------------------------------------------+
void CheckForEntry()
{
   double currentPrice = iClose(_Symbol, InpLowTF, 0);
   double point = _Point;
   int minPullback = InpBOSPullbackPoints;
   
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
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_SELL, InpBOSMagicNumber) > 0)
      {
         Print("Blocked BUY entry - SELL positions already open");
         return;
      }
      
      // Check max buy trades limit
      if(GetOpenPositionsCount(POSITION_TYPE_BUY, InpBOSMagicNumber) >= InpMaxBuyOnBOS)
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
            Logging("Executing BUY trade at pullback to BOS level");
            Logging("   Swing Trend: " + TrendToString(swH_Trend) + 
                  " | Daily Trend: " + TrendToString(D_Trend));
            Logging("   Swing Strategy: " + TradingStrategyToString(swH_Strategy) + 
                  " | Daily Strategy: " + TradingStrategyToString(D_Strategy));
            ExecuteBuyTrade(0, InpBOSMagicNumber);
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
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_BUY, InpBOSMagicNumber) > 0)
      {
         Print("Blocked SELL entry - BUY positions already open");
         return;
      }
      
      // Check max sell trades limit
      if(GetOpenPositionsCount(POSITION_TYPE_SELL, InpBOSMagicNumber) >= InpMaxSellOnBOS)
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
            Logging("Executing SELL trade at pullback to BOS level");
            Logging("   Swing Trend: " + TrendToString(swH_Trend) + 
                  " | Daily Trend: " + TrendToString(D_Trend));
            Logging("   Swing Strategy: " + TradingStrategyToString(swH_Strategy) + 
                  " | Daily Strategy: " + TradingStrategyToString(D_Strategy));
            ExecuteSellTrade(0, InpBOSMagicNumber);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for breakout conditions with multi-timeframe validation     |
//+------------------------------------------------------------------+
void CheckForBreakout(int boxIndex)
{
   // Validate that we should trade breakouts
   if(!InpTradeBreakouts && !g_Boxes[boxIndex].drawn)
      return;

   // // Prevent conflicting signals
   // if(IsReHeld)
   //    return;
   
   // Check strategy alignment - prefer BREAKOUT_TRADING or TREND_FOLLOWER strategies
   bool strategyAligned = false;
   
   // Check if any timeframe suggests breakout trading
   if(swH_Strategy == BREAKOUT_TRADING || swH_SecondaryStrategy == BREAKOUT_TRADING)
      strategyAligned = true;
   else if(D_Strategy == BREAKOUT_TRADING || D_SecondaryStrategy == BREAKOUT_TRADING)
      strategyAligned = true;
   // Trend following also benefits from breakouts
   else if(swH_Strategy == TREND_FOLLOWER || D_Strategy == TREND_FOLLOWER)
      strategyAligned = true;
   
   if(!strategyAligned)
   {
      Print("Breakout blocked - Strategy not aligned (SW: ", TradingStrategyToString(swH_Strategy), 
            ", D: ", TradingStrategyToString(D_Strategy), ")");
      return;
   }
   
   // Set flags to signal valid breakout detected
   IsBreakout = true;
   g_ActiveBoxIndex = boxIndex;
   // Print("✓ Breakout validated - Strategy aligned (Box ", boxIndex, ")");
   
   // Immediately validate and execute if conditions met
   CheckEntryLevel();
}

//+------------------------------------------------------------------+
//| Check for hold/retest conditions with multi-timeframe validation  |
//+------------------------------------------------------------------+
void CheckForHold(int boxIndex)
{
   // Validate that we should trade retests
   if(!InpTradeRetests && !g_Boxes[boxIndex].drawn)
      return;

   // // Prevent conflicting signals
   // if(IsReHeld)
   //    return;

   // Check strategy alignment - prefer RANGE_TRADING, SWING_TRADING strategies
   bool strategyAligned = false;
   
   // Range trading benefits most from holds/retests
   if(swH_Strategy == RANGE_TRADING || swH_SecondaryStrategy == RANGE_TRADING)
      strategyAligned = true;
   else if(D_Strategy == RANGE_TRADING || D_SecondaryStrategy == RANGE_TRADING)
      strategyAligned = true;
   // Swing trading also uses retests
   else if(swH_Strategy == SWING_TRADING || D_Strategy == SWING_TRADING)
      strategyAligned = true;
   // Trend followers can use retests in pullbacks
   else if(swH_Strategy == TREND_FOLLOWER && swH_MarketCondition == CLEAR_AND_STRONG_TREND)
      strategyAligned = true;
   
   if(!strategyAligned)
   {
      Print("Hold/Retest blocked - Strategy not aligned (SW: ", TradingStrategyToString(swH_Strategy),
            ", D: ", TradingStrategyToString(D_Strategy), ")");
      return;
   }
   
   // Set flags to signal valid hold detected
   IsHold = true;
   g_ActiveBoxIndex = boxIndex;
   // Print("✓ Hold/Retest validated - Strategy aligned (Box ", boxIndex, ")");
   
   // Immediately validate and execute if conditions met
   CheckEntryLevel();
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
   
   // BUY signal trend validation
   if(isBuySignal)
   {
      bool trendAligned = false;
      
      if(W_Trend == TREND_BEARISH)
      {
         if(D_Trend == TREND_BULLISH && D_Strategy == TREND_FOLLOWER)
            trendAligned = true; // Allow if daily is bullish trend follower
         else if(D_Trend == TREND_SIDEWAYS && D_Strategy == RANGE_TRADING)
         {
            if(isSupport && !isBroken) // Support held
            {
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 4; // Increase buy on hold limit
               g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;
            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 2; // Reset buy on hold limit if conditions not met
               // trendAligned = false;
            }
         }
         else if(swH_Trend == TREND_SIDEWAYS && swH_Strategy == RANGE_TRADING)
         {
            if(g_Boxes[g_ActiveBoxIndex].is_reheld) // Support held
            {
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 6; // Increase buy on hold limit
               // g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;
            }
            else
               trendAligned = false;
         }
      }
      else if(W_Trend == TREND_SIDEWAYS)
      {
         if(D_Trend == TREND_BULLISH && D_Strategy == TREND_FOLLOWER)
            if(g_Boxes[g_ActiveBoxIndex].is_reheld)
            {
               if(!isSupport && isBroken) // Resistance re-broke
               {
                  g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit = 4; // Increase buy on breakout limit after re-break
                  g_Boxes[g_ActiveBoxIndex].box_break_limit += 1; // Slightly increase break limit
                  trendAligned = true;
               }
               Print("Hai");
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 8; // Increase buy on hold limit after re-hold
               g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;

            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 2; // Reset buy on hold limit if not re-held
               g_Boxes[g_ActiveBoxIndex].box_hold_limit = 2; // Reset hold limit
               trendAligned = true;
            }
         else if(D_Trend == TREND_SIDEWAYS && D_Strategy == RANGE_TRADING)
         {
            if(isSupport && !isBroken) // Support held
            {
               if(snrH_Trend != TREND_BEARISH)
               {
                  g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 4;
                  g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
                  trendAligned = true;
               }
            }
            else if(!isSupport && isBroken && swH_Trend == TREND_BULLISH) // Resistance broke
            {
               if(!g_Boxes[g_ActiveBoxIndex].is_reheld) // Only if not re-held
               {
                  g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit = 2;
                  g_Boxes[g_ActiveBoxIndex].box_break_limit = 2; // Slightly increase hold limit
                  trendAligned = true;
               }
               else if(g_Boxes[g_ActiveBoxIndex].is_reheld)
               {
                  g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit = 4;
                  g_Boxes[g_ActiveBoxIndex].box_break_limit += 1; // Slightly increase hold limit
                  trendAligned = true;
               }
            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].buyOnHold_limit = 2; // Reset buy on hold limit if conditions not met
               g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit = 2; // Reset buy on breakout limit if conditions not met
               trendAligned = false;
            }
         }
      }
      else // W_Trend == TREND_BULLISH
      {
         if(D_Trend == TREND_BULLISH && D_Strategy == TREND_FOLLOWER)
            trendAligned = true;
      }
      
      if(!trendAligned)
      {
         Print("BUY blocked - Trend not aligned (W: ", TrendToString(W_Trend),
               ", D: ", TrendToString(D_Trend),
               ", SW: ", TrendToString(swH_Trend),
               ", H4: ", TrendToString(snrH_Trend),
               ", Box: ", IntegerToString(boxIndex+1), ")");
         return false;
      }
      
      return true;
   }
   // SELL signal trend validation
   else
   {
      bool trendAligned = false;
      
      if(W_Trend == TREND_BULLISH)
      {
         if(D_Trend == TREND_BEARISH && D_Strategy == TREND_FOLLOWER)
            trendAligned = true;
         else if(D_Trend == TREND_SIDEWAYS && D_Strategy == RANGE_TRADING)
         {
            if(!isSupport && !isBroken) // Resistance held
            {
               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 4; // Increase sell on hold limit
               g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;
            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 2; // Reset sell on hold limit if conditions not met
               // trendAligned = false;
            }
         }
         else if(swH_Trend == TREND_SIDEWAYS && swH_Strategy == RANGE_TRADING)
         {
            if(g_Boxes[g_ActiveBoxIndex].is_reheld) // Resistance held
            {
               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 6; // Increase sell on hold limit
               // g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;
            }
            else
               trendAligned = false;
         }
      }
      else if(W_Trend == TREND_SIDEWAYS)
      {
         if(D_Trend == TREND_BEARISH && D_Strategy == TREND_FOLLOWER)
            if(g_Boxes[g_ActiveBoxIndex].is_reheld)
            {
               if(isSupport && isBroken) // Support re-broke
               {
                  g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit = 4; // Increase sell on breakout limit after re-break
                  g_Boxes[g_ActiveBoxIndex].box_break_limit += 1; // Slightly increase break limit
                  trendAligned = true;
               }

               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 8; // Increase sell on hold limit after re-hold
               g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
               trendAligned = true;

            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 2; // Reset sell on hold limit if not re-held
               trendAligned = true;
            }
         else if(D_Trend == TREND_SIDEWAYS && D_Strategy == RANGE_TRADING)
         {
            if(!isSupport && !isBroken) // Resistance held
            {
               if(snrH_Trend != TREND_BULLISH)
               {
                  g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 4;
                  g_Boxes[g_ActiveBoxIndex].box_hold_limit += 1; // Slightly increase hold limit
                  trendAligned = true;
               }
            }
            else if(isSupport && isBroken && swH_Trend == TREND_BEARISH) // Support broke
            {
               if(!g_Boxes[g_ActiveBoxIndex].is_reheld) // Only if not re-held
               {
                  g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit = 2;
                  g_Boxes[g_ActiveBoxIndex].box_break_limit = 2; // Slightly increase hold limit
                  trendAligned = true;
               }
               else if(g_Boxes[g_ActiveBoxIndex].is_reheld)
               {
                  g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit = 4;
                  g_Boxes[g_ActiveBoxIndex].box_break_limit += 1; // Slightly increase hold limit
                  trendAligned = true;
               }
            }
            else
            {
               g_Boxes[g_ActiveBoxIndex].sellOnHold_limit = 2; // Reset sell on hold limit if conditions not met
               g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit = 2; // Reset sell on breakout limit if conditions not met
               trendAligned = false;
            }
         }
      }
      else // W_Trend == TREND_BEARISH
      {
         if(D_Trend == TREND_BEARISH && D_Strategy == TREND_FOLLOWER)
            trendAligned = true;
      }
      
      if(!trendAligned)
      {
         Print("SELL blocked - Trend not aligned (W: ", TrendToString(W_Trend),
               ", D: ", TrendToString(D_Trend),
               ", SW: ", TrendToString(swH_Trend),
               ", H4: ", TrendToString(snrH_Trend),
               ", Box: ", IntegerToString(boxIndex+1), ")");
         return false;
      }
      
      return true;
   }
}

//+------------------------------------------------------------------+
//| Final entry validation with all conditions                        |
//+------------------------------------------------------------------+
void CheckEntryLevel()
{
   // Must have either breakout or hold signal
   if(!IsBreakout && !IsHold)
      return;
   
   // Check if box has been traded maximum times based on signal type
   if(g_ActiveBoxIndex >= 0)
   {
      if(IsBreakout && g_Boxes[g_ActiveBoxIndex].break_count >= g_Boxes[g_ActiveBoxIndex].box_break_limit)
      {
         Print("Trade blocked - Box already traded ", g_Boxes[g_ActiveBoxIndex].break_count, " breakouts (max "+IntegerToString(g_Boxes[g_ActiveBoxIndex].box_break_limit)+") (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      if(IsHold && g_Boxes[g_ActiveBoxIndex].hold_count >= g_Boxes[g_ActiveBoxIndex].box_hold_limit)
      {
         Print("Trade blocked - Box already traded ", g_Boxes[g_ActiveBoxIndex].hold_count, " holds (max "+IntegerToString(g_Boxes[g_ActiveBoxIndex].box_hold_limit)+") (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
   }
   
   // Determine trade direction based on which signal type we have and the actual box properties
   bool isBuySignal = false;
   bool isSellSignal = false;
   
   // Use the actual box's properties to determine signal direction
   bool isSupport = g_Boxes[g_ActiveBoxIndex].is_support;
   bool isBroken = g_Boxes[g_ActiveBoxIndex].is_broken;
   
   if(IsBreakout)
   {
      // Breakout logic based on box type:
      // - Resistance breakout (broken resistance) = BUY signal
      // - Support breakout (broken support) = SELL signal
      if(!isSupport && isBroken) // Resistance broke
         isBuySignal = true;
      else if(isSupport && isBroken) // Support broke
         isSellSignal = true;
   }
   else if(IsHold)
   {
      // Hold logic based on box type:
      // - Support hold (unbroken support) = BUY signal
      // - Resistance hold (unbroken resistance) = SELL signal
      if(isSupport && !isBroken) // Support held
         isBuySignal = true;
      else if(!isSupport && !isBroken) // Resistance held
         isSellSignal = true;
   }

   // Using middle price level of the box for reference
   // double referencePrice = (g_Boxes[g_ActiveBoxIndex].top + g_Boxes[g_ActiveBoxIndex].bottom) / 2.0;
   
   // Validate BUY conditions
   if(isBuySignal && InpBuySignals)
   {
      // Check trade direction filter
      if(InpTradeDirection == TRADE_SELL_ONLY)
      {
         Print("BUY blocked - Trade direction set to SELL_ONLY");
         ResetEntryFlags();
         return;
      }
      
      // Check if opposite positions exist
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_SELL, InpSnRMagicNumber) > 0)
      {
         Print("BUY blocked - SELL positions already open");
         ResetEntryFlags();
         return;
      }
      
      // Check max buy trades limit
      int currentBuyCount = GetOpenPositionsCount(POSITION_TYPE_BUY, InpSnRMagicNumber);
      
      // Check overall S&R limit
      if(currentBuyCount >= InpMaxBuyOnSnR)
      {
         Print("BUY blocked - InpMaxBuyOnSnR limit reached (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      
      // Check signal-specific limits
      if(IsHold && g_Boxes[g_ActiveBoxIndex].buyOnHold_count >= g_Boxes[g_ActiveBoxIndex].buyOnHold_limit)
      {
         Print("BUY blocked - InpMaxBuyOnHold limit reach "+IntegerToString(g_Boxes[g_ActiveBoxIndex].buyOnHold_limit)+" (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      if(IsBreakout && g_Boxes[g_ActiveBoxIndex].buyOnBreakout_count >= g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit)
      {
         Print("BUY blocked - InpMaxBuyOnBreakout limit reach "+IntegerToString(g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit)+" "+IntegerToString(g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit)+" (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      
      // Validate trend alignment using centralized function
      if(!CheckTrendConditions(g_ActiveBoxIndex, true))
      {
         ResetEntryFlags();
         return;
      }
      
      // Additional confirmation: check pullback to level with bullish candle (like BOS)
      double currentPrice = iClose(_Symbol, InpLowTF, 0);
      double point = _Point;
      double referencePrice = g_Boxes[g_ActiveBoxIndex].top;
      double distancePoints = MathAbs(currentPrice - referencePrice) / point;
      
      // Allow trade if:
      // 1. First time (!traded), OR
      // 2. Re-testing after previous trade (traded) AND price pulled back near level with candle confirmation
      bool allowTrade = false;
      
      if(!g_Boxes[g_ActiveBoxIndex].traded)
      {
         // First trade - just need to be near the level
         if(distancePoints <= InpSnRPullbackPoints)
         {
            allowTrade = true;
            // Increment counts
            if(IsBreakout)
               g_Boxes[g_ActiveBoxIndex].break_count++;
            if(IsHold)
               g_Boxes[g_ActiveBoxIndex].hold_count++;
         }
         
         // IsReHeld = false;
      }
      else
      {
         // Re-test after previous trade - require pullback confirmation
         if(distancePoints <= InpSnRPullbackPoints)
         {
            // Confirm with recent bullish candle
            double prevClose = iClose(_Symbol, InpLowTF, 1);
            double prevOpen = iOpen(_Symbol, InpLowTF, 1);
            
            if(prevClose > prevOpen) // Bullish confirmation
            {
               allowTrade = true;
               if(IsBreakout)
                  g_Boxes[g_ActiveBoxIndex].break_count++;
               if(IsHold)
                  g_Boxes[g_ActiveBoxIndex].hold_count++;
            }
            else
               Print("BUY re-test blocked - No bullish confirmation candle (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         }
         else
            Print("BUY re-test blocked - Price too far from level: ", DoubleToString(distancePoints, 0), " points (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
      }
      
      if(!allowTrade)
      {
         if(IsBreakout)
               Print("BUY blocked - Breakout pullback confirmation failed (Distance: ", DoubleToString(distancePoints, 0), " points, Break count: ", g_Boxes[g_ActiveBoxIndex].break_count, " , Box: ", IntegerToString(g_ActiveBoxIndex+1), ")");
         else if(IsHold)
            Print("BUY blocked - Hold pullback confirmation failed (Distance: ", DoubleToString(distancePoints, 0), " points, Hold count: ", g_Boxes[g_ActiveBoxIndex].hold_count, " , Box: ", IntegerToString(g_ActiveBoxIndex+1), ")");
         ResetEntryFlags();
         return;
      }
      
      // All validations passed - execute trade
      Logging("✓ All BUY conditions validated - Executing S&R trade");
      Logging("   Hold Count: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].hold_count) + 
              " | Box Hold Limit: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].box_hold_limit));
      Logging("   Breakout Count: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].break_count) + 
              " | Box Breakout Limit: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].box_break_limit));
      Logging("   Limit BUY entry on Hold: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].buyOnHold_limit) + 
              " | Limit BUY entry on Breakout: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].buyOnBreakout_limit));
      Logging("   Is Re-Held: " + (g_Boxes[g_ActiveBoxIndex].is_reheld ? "true" : "false"));
      Logging("   Box Index: " + IntegerToString(g_ActiveBoxIndex+1));
      Logging("   Price Level: " + DoubleToString(g_Boxes[g_ActiveBoxIndex].top, _Digits));
      Logging("   Distance: " + DoubleToString(distancePoints, 1) + " points | Previously Traded: " + (g_Boxes[g_ActiveBoxIndex].traded ? "Yes" : "No"));
      Logging("   Is Hold: " + (IsHold ? "true" : "false") + 
              " | Is Breakout: " + (IsBreakout ? "true" : "false"));
      Logging("   Weekly Trend: " + TrendToString(W_Trend) + 
              " | Daily Trend: " + TrendToString(D_Trend));
      Logging(" | Daily Strategy: " + TradingStrategyToString(D_Strategy));
      if(ExecuteBuyTrade(0, InpSnRMagicNumber))
      {
         g_Boxes[g_ActiveBoxIndex].traded = true;
         g_Boxes[g_ActiveBoxIndex].traded_count++;
         if(IsBreakout)
            g_Boxes[g_ActiveBoxIndex].buyOnBreakout_count++;
         if(IsHold)
            g_Boxes[g_ActiveBoxIndex].buyOnHold_count++;
      }
      ResetEntryFlags();
   }
   // Validate SELL conditions
   else if(isSellSignal && InpSellSignals)
   {
      // Check trade direction filter
      if(InpTradeDirection == TRADE_BUY_ONLY)
      {
         Print("SELL blocked - Trade direction set to BUY_ONLY");
         ResetEntryFlags();
         return;
      }
      
      // Check if opposite positions exist
      if(InpBlockOppositeEntry && GetOpenPositionsCount(POSITION_TYPE_BUY, InpSnRMagicNumber) > 0)
      {
         Print("SELL blocked - BUY positions already open");
         ResetEntryFlags();
         return;
      }
      
      // Check max sell trades limit
      int currentSellCount = GetOpenPositionsCount(POSITION_TYPE_SELL, InpSnRMagicNumber);
      
      // Check overall S&R limit
      if(currentSellCount >= InpMaxSellOnSnR)
      {
         Print("SELL blocked - InpMaxSellOnSnR limit reached (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      
      // Check signal-specific limits
      if(IsHold && g_Boxes[g_ActiveBoxIndex].sellOnHold_count >= g_Boxes[g_ActiveBoxIndex].sellOnHold_limit)
      {
         Print("SELL blocked - InpMaxSellOnHold limit reach "+IntegerToString(g_Boxes[g_ActiveBoxIndex].sellOnHold_limit)+" (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      if(IsBreakout && g_Boxes[g_ActiveBoxIndex].sellOnBreakout_count >= g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit)
      {
         Print("SELL blocked - InpMaxSellOnBreakout limit reached "+IntegerToString(g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit)+" (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         ResetEntryFlags();
         return;
      }
      
      // Validate trend alignment using centralized function
      if(!CheckTrendConditions(g_ActiveBoxIndex, false))
      {
         ResetEntryFlags();
         return;
      }
      
      // Additional confirmation: check pullback to level with bearish candle (like BOS)
      double currentPrice = iClose(_Symbol, InpLowTF, 0);
      double point = _Point;
      double referencePrice = g_Boxes[g_ActiveBoxIndex].bottom;
      double distancePoints = MathAbs(currentPrice - referencePrice) / point;
      
      // Allow trade if:
      // 1. First time (!traded), OR
      // 2. Re-testing after previous trade (traded) AND price pulled back near level with candle confirmation
      bool allowTrade = false;
      
      if(!g_Boxes[g_ActiveBoxIndex].traded)
      {
         // First trade - just need to be near the level
         if(distancePoints <= InpSnRPullbackPoints)
         {
            allowTrade = true;
            // Increment counts
            if(IsBreakout)
               g_Boxes[g_ActiveBoxIndex].break_count++;
            if(IsHold)
               g_Boxes[g_ActiveBoxIndex].hold_count++;
         }
         
         // IsReHeld = false;
      }
      else
      {
         // Re-test after previous trade - require pullback confirmation
         if(distancePoints <= InpSnRPullbackPoints)
         {
            // Confirm with recent bearish candle
            double prevClose = iClose(_Symbol, InpLowTF, 1);
            double prevOpen = iOpen(_Symbol, InpLowTF, 1);
            
            if(prevClose < prevOpen) // Bearish confirmation
            {
               allowTrade = true;
               if(IsBreakout)
                  g_Boxes[g_ActiveBoxIndex].break_count++;
               if(IsHold)
                  g_Boxes[g_ActiveBoxIndex].hold_count++;
            }
            else
               Print("SELL re-test blocked - No bearish confirmation candle (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
         }
         else
            Print("SELL re-test blocked - Price too far from level: ", DoubleToString(distancePoints, 0), " points (Box "+IntegerToString(g_ActiveBoxIndex+1)+")");
      }
      
      if(!allowTrade)
      {
         if(IsBreakout)
            Print("SELL blocked - Breakout pullback confirmation failed (Distance: ", DoubleToString(distancePoints, 0), " points, Break count: ", g_Boxes[g_ActiveBoxIndex].break_count, " , Box: ", IntegerToString(g_ActiveBoxIndex+1), ")");
         else if(IsHold)
            Print("SELL blocked - Hold pullback confirmation failed (Distance: ", DoubleToString(distancePoints, 0), " points, Hold count: ", g_Boxes[g_ActiveBoxIndex].hold_count, " , Box: ", IntegerToString(g_ActiveBoxIndex+1), ")");
         ResetEntryFlags();
         return;
      }
      
      // All validations passed - execute trade
      Logging("✓ All SELL conditions validated - Executing S&R trade");
      Logging("   Hold Count: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].hold_count) + 
              " | Box Hold Limit: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].box_hold_limit));
      Logging("   Breakout Count: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].break_count) + 
              " | Box Breakout Limit: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].box_break_limit));
      Logging("   Limit SELL entry on Hold: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].sellOnHold_limit) + 
              " | Limit SELL entry on Breakout: " + IntegerToString(g_Boxes[g_ActiveBoxIndex].sellOnBreakout_limit));
      Logging("   Is Re-Held: " + (g_Boxes[g_ActiveBoxIndex].is_reheld ? "true" : "false"));
      Logging("   Box Index: " + IntegerToString(g_ActiveBoxIndex+1));
      Logging("   Price Level: " + DoubleToString(g_Boxes[g_ActiveBoxIndex].bottom, _Digits));
      Logging("   Distance: " + DoubleToString(distancePoints, 1) + " points | Previously Traded: " + (g_Boxes[g_ActiveBoxIndex].traded ? "Yes" : "No"));
      Logging("   Is Hold: " + (IsHold ? "true" : "false") + 
              " | Is Breakout: " + (IsBreakout ? "true" : "false"));
      Logging("   Weekly Trend: " + TrendToString(W_Trend) + 
              " | Daily Trend: " + TrendToString(D_Trend));
      Logging(" | Daily Strategy: " + TradingStrategyToString(D_Strategy));
      if(ExecuteSellTrade(0, InpSnRMagicNumber))
      {
         g_Boxes[g_ActiveBoxIndex].traded = true;
         g_Boxes[g_ActiveBoxIndex].traded_count++;
         if(IsBreakout)
            g_Boxes[g_ActiveBoxIndex].sellOnBreakout_count++;
         if(IsHold)
            g_Boxes[g_ActiveBoxIndex].sellOnHold_count++;
      }
      ResetEntryFlags();
   }
   else
   {
      // No valid signal or signals disabled
      ResetEntryFlags();
   }
}

//+------------------------------------------------------------------+
//| Reset entry validation flags                                      |
//+------------------------------------------------------------------+
void ResetEntryFlags()
{
   IsBreakout = false;
   IsHold = false;
   g_ActiveBoxIndex = -1;
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
   
   // Build comment with box index for S&R trades
   string comment = InpTradeComment;
   if(magicNumber == InpSnRMagicNumber && g_ActiveBoxIndex >= 0)
      comment = InpTradeComment + "_Box" + IntegerToString(g_ActiveBoxIndex);
   
   if(trade.Buy(lotSize, _Symbol, ask, sl, tp, comment))
   {
      Print("BUY order opened - Entry: ", ask, " | SL: ", sl, " | TP: ", tp);
      waitingForPullback = false;
      BOS.isActive = false;
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
   
   // Build comment with box index for S&R trades
   string comment = InpTradeComment;
   if(magicNumber == InpSnRMagicNumber && g_ActiveBoxIndex >= 0)
      comment = InpTradeComment + "_Box" + IntegerToString(g_ActiveBoxIndex);
   
   if(trade.Sell(lotSize, _Symbol, bid, sl, tp, comment))
   {
      Print("SELL order opened - Entry: ", bid, " | SL: ", sl, " | TP: ", tp);
      waitingForPullback = false;
      BOS.isActive = false;
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
   double trailStep = InpTrailingStep * _Point;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      
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

