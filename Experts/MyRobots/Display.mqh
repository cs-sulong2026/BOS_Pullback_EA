//+------------------------------------------------------------------+
//|                                                      Display.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 28.12.2025 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

#include "Defines.mqh"
#include "Functions.mqh"

// //+------------------------------------------------------------------+
// //| Convert color to ARGB with transparency                          |
// //+------------------------------------------------------------------+
// color ColorWithAlpha(color baseColor, uchar alpha)
// {
//    // Extract RGB components
//    uchar r = (uchar)(baseColor & 0xFF);
//    uchar g = (uchar)((baseColor >> 8) & 0xFF);
//    uchar b = (uchar)((baseColor >> 16) & 0xFF);
   
//    // Combine ARGB (Alpha in high byte)
//    return (color)((alpha << 24) | (b << 16) | (g << 8) | r);
// }

//+------------------------------------------------------------------+
//| Display market analysis on chart                                 |
//+------------------------------------------------------------------+
void DisplayMarketAnalysis(ENUM_TIMEFRAMES timeframe, TREND_TYPE trend, MARKET_CONDITIONS condition, 
                          TRADING_STRATEGY strategy, TRADING_STRATEGY secondaryStrategy, int yOffset = 0)
{
   string tfString = TFtoString(timeframe);
   string prefix = "Analysis_" + tfString + "_";
   
   // Starting position
   int baseX = 20;
   int baseY = 30 + yOffset;
   int lineHeight = 20;
   
   color headerColor = clrWhite;
   color trendColor;
   color conditionColor;
   color strategyColor = clrYellow;
   
   // Determine trend color
   switch(trend)
   {
      case TREND_BULLISH: trendColor = clrLime; break;
      case TREND_BEARISH: trendColor = clrRed; break;
      case TREND_SIDEWAYS: trendColor = clrOrange; break;
      case TREND_UNDECIDED: trendColor = clrGray; break;
      default: trendColor = clrGray;
   }
   
   // Determine condition color
   switch(condition)
   {
      case CLEAR_AND_STRONG_TREND: conditionColor = clrLime; break;
      case CONSOLIDATE_AND_RANGE: conditionColor = clrOrange; break;
      default: conditionColor = clrGray;
   }
   
   // Create or update header label
   string headerName = prefix + "Header";
   if(ObjectFind(0, headerName) >= 0)
      ObjectDelete(0, headerName);
      
   if(ObjectCreate(0, headerName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, headerName, OBJPROP_XDISTANCE, baseX);
      ObjectSetInteger(0, headerName, OBJPROP_YDISTANCE, baseY);
      ObjectSetString(0, headerName, OBJPROP_TEXT, "══ " + tfString + " Analysis ══");
      ObjectSetInteger(0, headerName, OBJPROP_COLOR, headerColor);
      ObjectSetInteger(0, headerName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, headerName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, headerName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   
   // Display Trend
   string trendName = prefix + "Trend";
   if(ObjectFind(0, trendName) >= 0)
      ObjectDelete(0, trendName);
      
   if(ObjectCreate(0, trendName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, trendName, OBJPROP_XDISTANCE, baseX + 5);
      ObjectSetInteger(0, trendName, OBJPROP_YDISTANCE, baseY + lineHeight);
      ObjectSetString(0, trendName, OBJPROP_TEXT, "Trend: " + TrendToString(trend));
      ObjectSetInteger(0, trendName, OBJPROP_COLOR, trendColor);
      ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, trendName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, trendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   
   // Display Market Condition
   string conditionName = prefix + "Condition";
   if(ObjectFind(0, conditionName) >= 0)
      ObjectDelete(0, conditionName);
      
   if(ObjectCreate(0, conditionName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, conditionName, OBJPROP_XDISTANCE, baseX + 5);
      ObjectSetInteger(0, conditionName, OBJPROP_YDISTANCE, baseY + lineHeight * 2);
      ObjectSetString(0, conditionName, OBJPROP_TEXT, "Condition: " + MarketConditionToString(condition));
      ObjectSetInteger(0, conditionName, OBJPROP_COLOR, conditionColor);
      ObjectSetInteger(0, conditionName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, conditionName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, conditionName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   
   // Display Trading Strategy
   string strategyName = prefix + "Strategy";
   if(ObjectFind(0, strategyName) >= 0)
      ObjectDelete(0, strategyName);
      
   string strategyText = "Strategy: " + TradingStrategyToString(strategy);
   if(secondaryStrategy != UNDECIDED)
      strategyText += " / " + TradingStrategyToString(secondaryStrategy);
      
   if(ObjectCreate(0, strategyName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, strategyName, OBJPROP_XDISTANCE, baseX + 5);
      ObjectSetInteger(0, strategyName, OBJPROP_YDISTANCE, baseY + lineHeight * 3);
      ObjectSetString(0, strategyName, OBJPROP_TEXT, strategyText);
      ObjectSetInteger(0, strategyName, OBJPROP_COLOR, strategyColor);
      ObjectSetInteger(0, strategyName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, strategyName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, strategyName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
}

//+------------------------------------------------------------------+
//| Display all timeframes analysis                                  |
//+------------------------------------------------------------------+
void DisplayAllTimeframesAnalysis()
{
   int offset = 0;
   
   // Display Weekly Analysis
   if(W_LastHigh.isValid || W_LastLow.isValid)
   {
      DisplayMarketAnalysis(PERIOD_W1, W_Trend, W_MarketCondition, W_Strategy, W_SecondaryStrategy, offset);
      offset += 100;
   }
   
   // Display Daily Analysis
   if(D_LastHigh.isValid || D_LastLow.isValid)
   {
      DisplayMarketAnalysis(PERIOD_D1, D_Trend, D_MarketCondition, D_Strategy, D_SecondaryStrategy, offset);
      offset += 100;
   }
   
   // Display Higher Timeframe Analysis (H4 or custom)
   if(swH_LastHigh.isValid || swH_LastLow.isValid)
   {
      DisplayMarketAnalysis(InpSwingTF, swH_Trend, swH_MarketCondition, swH_Strategy, swH_SecondaryStrategy, offset);
      offset += 100;
   }
   
   // // Display Lower Timeframe Analysis (M15 or custom)
   // if(M_LastHigh.isValid || M_LastLow.isValid)
   // {
   //    DisplayMarketAnalysis(InpLowTF, M_Trend, M_MarketCondition, M_Strategy, M_SecondaryStrategy, offset);
   //    offset += 100;
   // }
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
   string str = BOS.isBullish ? "BULLISH" : "BEARISH";
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
//| Delete all analysis objects from chart                           |
//+------------------------------------------------------------------+
void DeleteAllAnalysisObjects()
{
   string prefixes[] = {"Analysis_W1_", "Analysis_D1_", "Analysis_H12_", "Analysis_H4_", "Analysis_H1_", "Analysis_M15_", "Analysis_M5_"};
   
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      string prefix = prefixes[p];
      ObjectDelete(0, prefix + "Header");
      ObjectDelete(0, prefix + "Trend");
      ObjectDelete(0, prefix + "Condition");
      ObjectDelete(0, prefix + "Strategy");
   }
}

//+------------------------------------------------------------------+
