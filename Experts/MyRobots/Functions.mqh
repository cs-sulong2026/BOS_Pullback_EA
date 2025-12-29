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
   CheckTradingSignals(timeframe, shift, hasSupport, g_SupportLevel, g_SupportLevel1, 
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
   // Print("      Current "+TFtoString(timeframe)+" Bar: High=", currHigh, " Low=", currLow);
   // Print("      Previous "+TFtoString(timeframe)+" Bar: High=", prevHigh, " Low=", prevLow);
   
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
         
         // Support breakout = SELL signal
         bool breakoutSup = (prevHigh >= g_Boxes[i].bottom && currHigh < g_Boxes[i].bottom);
         
         // Support hold = BUY signal (retest)
         bool supHolds = (prevLow <= g_Boxes[i].top && currLow > g_Boxes[i].top);
         
         // if(breakoutSup) Print("            🔴 Support BREAKOUT detected!");
         // if(supHolds) Print("            🟢 Support HOLD detected!");
         
         if(breakoutSup && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_SupIsResistance = true;
            // Print("            ⚡ Support broken! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, true);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "SUP", true);
            
            // SELL on support break
            if(InpTradeBreakouts && InpSellSignals && !g_Boxes[i].traded)
            {
               // Print("            ➤ Opening SELL on support break");
               CreateBreakoutLabel(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "Break Sup", false);
               // OpenTrade(ORDER_TYPE_SELL, "Support Break", g_Boxes[i].top);
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
            // Print("            ⚡ Support held! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "SUP", false);
            
            // BUY on support hold
            if(InpTradeRetests && InpBuySignals)
            {
               // Print("            ➤ Opening BUY on support hold");
               // OpenTrade(ORDER_TYPE_BUY, "Support Hold", g_Boxes[i].bottom);
               g_Boxes[i].traded = true;
            }
            else
            {
               // Print("            ✗ Trade blocked: Retests=", InpTradeRetests, 
               //       " | BuySignals=", InpBuySignals);
            }
         }
      }
      else // Resistance
      {
         // Print("         Box[", i, "] RESISTANCE: Top=", g_Boxes[i].top, " Bottom=", g_Boxes[i].bottom,
         //       " | Traded=", g_Boxes[i].traded, " | Broken=", g_Boxes[i].is_broken);
         
         // Resistance breakout = BUY signal
         bool breakoutRes = (prevLow <= g_Boxes[i].top && currLow > g_Boxes[i].top);
         
         // Resistance hold = SELL signal (retest)
         bool resHolds = (prevHigh >= g_Boxes[i].bottom && currHigh < g_Boxes[i].bottom);
         
         // if(breakoutRes) Print("            🟢 Resistance BREAKOUT detected!");
         // if(resHolds) Print("            🔴 Resistance HOLD detected!");
         
         if(breakoutRes && !g_Boxes[i].is_broken)
         {
            g_Boxes[i].is_broken = true;
            g_ResIsSupport = true;
            // Print("            ⚡ Resistance broken! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, true);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "RES", true);
            
            // BUY on resistance break
            if(InpTradeBreakouts && InpBuySignals && !g_Boxes[i].traded)
            {
               // Print("            ➤ Opening BUY on resistance break");
               CreateBreakoutLabel(iTime(_Symbol, timeframe, shift), g_Boxes[i].top, "Break Res", true);
               // OpenTrade(ORDER_TYPE_BUY, "Resistance Break", g_Boxes[i].bottom);
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
            // Print("            ⚡ Resistance held! Checking trade conditions...");
            
            // Update box visual
            UpdateBoxVisual(i, false);
            CreateVisualMarker(iTime(_Symbol, timeframe, shift), g_Boxes[i].bottom, "RES", false);
            
            // SELL on resistance hold
            if(InpTradeRetests && InpSellSignals)
            {
               // Print("            ➤ Opening SELL on resistance hold");
               // OpenTrade(ORDER_TYPE_SELL, "Resistance Hold", g_Boxes[i].top);
               g_Boxes[i].traded = true;
            }
            else
            {
               // Print("            ✗ Trade blocked: Retests=", InpTradeRetests,
               //       " | SellSignals=", InpSellSignals);
            }
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
   g_Boxes[g_BoxCount].traded = false;
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
      
      // Add volume label
      string labelName = boxName + "_label";
      double labelPrice = isSupport ? top : bottom;
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, leftTime, labelPrice))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, "Vol: " + DoubleToString(volume, 0));
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, ColorWithAlpha(clrWhite, 128));
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
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
   
   if(InpShowOnlyNearest)
   {
      // Find nearest support and resistance to current price
      int nearestSupport = -1;
      int nearestResistance = -1;
      double minSupportDist = DBL_MAX;
      double minResistanceDist = DBL_MAX;
      
      for(int i = 0; i < g_BoxCount; i++)
      {
         if(!g_Boxes[i].drawn)
            continue;
            
         if(g_Boxes[i].is_support)
         {
            double dist = MathAbs(currentPrice - g_Boxes[i].top);
            if(dist < minSupportDist)
            {
               minSupportDist = dist;
               nearestSupport = i;
            }
         }
         else
         {
            double dist = MathAbs(currentPrice - g_Boxes[i].bottom);
            if(dist < minResistanceDist)
            {
               minResistanceDist = dist;
               nearestResistance = i;
            }
         }
      }
      
      // Hide all boxes first
      for(int i = 0; i < g_BoxCount; i++)
         HideBox(i);
         
      // Show only nearest
      if(nearestSupport >= 0)
         ShowBox(nearestSupport);
      if(nearestResistance >= 0)
         ShowBox(nearestResistance);
   }
   else if(!InpShowPreviousBoxes)
   {
      // Show only the most recent boxes
      int boxesToShow = InpMaxVisibleBoxes > 0 ? InpMaxVisibleBoxes : g_BoxCount;
      
      for(int i = 0; i < g_BoxCount; i++)
      {
         if(i >= g_BoxCount - boxesToShow)
            ShowBox(i);
         else
            HideBox(i);
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
               ShowBox(i);
            else
               HideBox(i);
         }
      }
      else
      {
         // Show all boxes
         for(int i = 0; i < g_BoxCount; i++)
            ShowBox(i);
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
