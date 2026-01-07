//+------------------------------------------------------------------+
//|                                               SupplyDemand.mq5   |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 07.01.2026 - Volume-based Supply & Demand EA                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"
#property version   "1.00"
#property strict

// Include the Supply & Demand classes
#include "SupplyDemand.mqh"
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Zone Detection Settings ==="
input int               InpLookbackBars = 500;           // Lookback Period (bars)
input long              InpVolumeThreshold = 1000;       // Volume Threshold (0=auto calculate)
input int               InpMinBarsInZone = 2;            // Minimum Bars in Zone
input int               InpMaxBarsInZone = 10;           // Maximum Bars in Zone
input double            InpMinZoneSize = 50.0;           // Minimum Zone Size (points)
input double            InpMaxZoneSize = 1000.0;         // Maximum Zone Size (points)
input double            InpMinPriceLeftDistance = 20.0;  // Min Distance to Consider Left (points)

input group "=== Trading Settings ==="
input bool              InpEnableTrading = true;         // Enable Auto Trading
input double            InpLotSize = 0.01;               // Fixed Lot Size
input int               InpMaxTrade = 3;                 // Maximum Concurrent Trades
input int               InpATRPeriod = 14;               // ATR Period
input double            InpATRMultiplierSL = 2.0;        // ATR Multiplier for SL
input double            InpATRMultiplierTP = 3.0;        // ATR Multiplier for TP
input int               InpMagicNumber = 123456;         // Magic Number
input string            InpTradeComment = "SD_EA";       // Trade Comment

input group "=== Trailing Settings ==="
input bool              InpEnableTrailingStop = false;   // Enable Trailing Stop
input double            InpTrailingStopDistance = 50.0;  // Trailing Stop Distance (points)
input double            InpTrailingStopStep = 10.0;      // Trailing Stop Step (points)
input bool              InpEnableTrailingTP = false;     // Enable Trailing TP
input double            InpTrailingTPDistance = 50.0;    // Trailing TP Distance (points)
input double            InpTrailingTPStep = 10.0;        // Trailing TP Step (points)

input group "=== Zone Display Settings ==="
input int               InpShowZone = -1;                // Show Zones (-1=all, 0=none, N=closest)
input color             InpSupplyColor = clrCrimson;     // Supply Zone Color
input color             InpDemandColor = clrDodgerBlue;  // Demand Zone Color
input color             InpSupplyColorFill = clrMistyRose;       // Supply Fill Color
input color             InpDemandColorFill = clrLightSteelBlue;  // Demand Fill Color
input int               InpZoneTransparency = 85;        // Zone Transparency (0-100)
input bool              InpShowArrows = true;            // Show Arrow Signals (108)
input bool              InpShowLabels = true;            // Show Volume Labels

input group "=== Advanced Settings ==="
input ENUM_TIMEFRAMES   InpZoneTimeframe = PERIOD_CURRENT; // Zone Detection Timeframe
input bool              InpAutoVolumeThreshold = true;   // Auto Calculate Volume Threshold
input double            InpVolumeMultiplier = 1.5;       // Volume Multiplier (for auto calc)
input bool              InpUpdateOnNewBar = true;        // Update Zones on New Bar
input int               InpUpdateIntervalSec = 300;      // Update Interval (seconds)
input bool              InpDebugMode = false;            // Enable Debug Logging

//--- Global objects
CSupplyDemandManager *g_SDManager = NULL;
CTrade g_Trade;

//--- Global indicators
int g_ATRHandle = INVALID_HANDLE;

//--- Tracking variables
datetime g_LastBarTime = 0;
datetime g_LastUpdateTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create Supply & Demand Manager
   g_SDManager = new CSupplyDemandManager();
   if(g_SDManager == NULL)
   {
      Print("ERROR: Failed to create Supply Demand Manager");
      return INIT_FAILED;
   }
   
   // Calculate volume threshold if auto mode
   long volumeThreshold = InpVolumeThreshold;
   if(InpAutoVolumeThreshold)
   {
      volumeThreshold = CalculateVolumeThreshold();
      if(InpDebugMode)
         Print("Auto-calculated volume threshold: ", volumeThreshold);
   }
   
   // Initialize manager
   if(!g_SDManager.Initialize(_Symbol, InpZoneTimeframe, InpLookbackBars, 
                              volumeThreshold, InpMinBarsInZone, InpMaxBarsInZone,
                              InpMinZoneSize, InpMaxZoneSize, InpMinPriceLeftDistance))
   {
      Print("ERROR: Failed to initialize Supply Demand Manager");
      delete g_SDManager;
      g_SDManager = NULL;
      return INIT_FAILED;
   }
   
   // Set display settings
   g_SDManager.SetShowZones(InpShowZone);
   g_SDManager.SetVisualSettings(InpSupplyColor, InpDemandColor, InpSupplyColorFill,
                                 InpDemandColorFill, InpZoneTransparency, 
                                 InpShowArrows, InpShowLabels);
   
   // Initialize trading
   if(InpEnableTrading)
   {
      g_Trade.SetExpertMagicNumber(InpMagicNumber);
      g_Trade.SetDeviationInPoints(10);
      g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
      g_Trade.SetAsyncMode(false);
      
      // Create ATR indicator
      g_ATRHandle = iATR(_Symbol, InpZoneTimeframe, InpATRPeriod);
      if(g_ATRHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator");
         delete g_SDManager;
         g_SDManager = NULL;
         return INIT_FAILED;
      }
      
      if(InpDebugMode)
         Print("Trading enabled with Magic Number: ", InpMagicNumber);
   }
   
   // Perform initial zone detection
   if(InpDebugMode)
      Print("Starting initial zone detection...");
   
   if(!g_SDManager.DetectZones())
   {
      Print("WARNING: Initial zone detection failed");
   }
   else
   {
      g_SDManager.ManageZoneDisplay();
      
      if(InpDebugMode)
      {
         Print("Zone detection complete:");
         Print("  Supply zones: ", g_SDManager.GetSupplyZoneCount());
         Print("  Demand zones: ", g_SDManager.GetDemandZoneCount());
      }
   }
   
   // Initialize tracking
   g_LastBarTime = iTime(_Symbol, InpZoneTimeframe, 0);
   g_LastUpdateTime = TimeCurrent();
   
   Print("Supply & Demand EA initialized successfully");
   Print("  Symbol: ", _Symbol);
   Print("  Timeframe: ", EnumToString(InpZoneTimeframe));
   Print("  Show zones: ", InpShowZone == -1 ? "All" : (InpShowZone == 0 ? "None" : IntegerToString(InpShowZone) + " closest"));
   Print("  Volume threshold: ", volumeThreshold);
   Print("  Trading: ", InpEnableTrading ? "ENABLED" : "DISABLED");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup
   if(g_SDManager != NULL)
   {
      g_SDManager.DeleteAllZones();
      delete g_SDManager;
      g_SDManager = NULL;
   }
   
   // Release ATR indicator
   if(g_ATRHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ATRHandle);
      g_ATRHandle = INVALID_HANDLE;
   }
   
   if(InpDebugMode)
      Print("Supply & Demand EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_SDManager == NULL)
      return;
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, InpZoneTimeframe, 0);
   bool isNewBar = (currentBarTime != g_LastBarTime);
   
   if(isNewBar)
   {
      g_LastBarTime = currentBarTime;
      
      if(InpUpdateOnNewBar)
      {
         if(InpDebugMode)
            Print("New bar detected, updating zones...");
         
         // Detect new zones in recent bars
         g_SDManager.DetectNewZones(20);
         
         // Update existing zones (check for broken/touched zones)
         g_SDManager.UpdateAllZones();
         g_SDManager.ManageZoneDisplay();
      }
   }
   
   // Manage trailing stops and TPs
   if(InpEnableTrading && (InpEnableTrailingStop || InpEnableTrailingTP))
   {
      ManageTrailing();
   }
   
   // Time-based update
   datetime currentTime = TimeCurrent();
   if(currentTime - g_LastUpdateTime >= InpUpdateIntervalSec)
   {
      g_LastUpdateTime = currentTime;
      
      // Update all zones
      g_SDManager.UpdateAllZones();
      g_SDManager.ManageZoneDisplay();
      
      if(InpDebugMode && !isNewBar)
      {
         Print("Periodic update:");
         Print("  Supply zones: ", g_SDManager.GetSupplyZoneCount());
         Print("  Demand zones: ", g_SDManager.GetDemandZoneCount());
      }
   }
   
   // Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get closest zones (for future trading logic)
   CSupplyDemandZone *closestSupply = g_SDManager.GetClosestSupplyZone(currentPrice);
   CSupplyDemandZone *closestDemand = g_SDManager.GetClosestDemandZone(currentPrice);
   
   // Debug: Show closest zone info
   static datetime lastDebugTime = 0;
   if(InpDebugMode && currentTime - lastDebugTime >= 60) // Every minute
   {
      lastDebugTime = currentTime;
      
      if(closestSupply != NULL)
      {
         Print("Closest SUPPLY zone: ", closestSupply.GetBottom(), " - ", closestSupply.GetTop(),
               " | Distance: ", DoubleToString(closestSupply.GetDistanceToPrice(), 1), 
               " | Volume: ", closestSupply.GetVolume(),
               " | State: ", EnumToString(closestSupply.GetState()));
      }
      
      if(closestDemand != NULL)
      {
         Print("Closest DEMAND zone: ", closestDemand.GetBottom(), " - ", closestDemand.GetTop(),
               " | Distance: ", DoubleToString(closestDemand.GetDistanceToPrice(), 1),
               " | Volume: ", closestDemand.GetVolume(),
               " | State: ", EnumToString(closestDemand.GetState()));
      }
   }
   
   //--- TODO: Add trading logic here
   //--- Use closestSupply and closestDemand for entry decisions
   //--- Check zone state (SD_STATE_ACTIVE, SD_STATE_UNTESTED, etc.)
   //--- Implement entry conditions based on zone touches
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Optional: Additional periodic updates
   if(g_SDManager != NULL)
   {
      g_SDManager.UpdateAllZones();
      g_SDManager.ManageZoneDisplay();
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle chart events
   if(id == CHARTEVENT_CHART_CHANGE && g_SDManager != NULL)
   {
      // Redraw zones on chart change
      g_SDManager.ManageZoneDisplay();
   }
}

//+------------------------------------------------------------------+
//| Calculate automatic volume threshold                            |
//+------------------------------------------------------------------+
long CalculateVolumeThreshold()
{
   // Calculate average volume over lookback period
   long volume[];
   ArraySetAsSeries(volume, true);
   
   int bars = MathMin(InpLookbackBars, Bars(_Symbol, InpZoneTimeframe));
   if(bars < 50)
      return 1000; // Default if not enough data
   
   if(CopyTickVolume(_Symbol, InpZoneTimeframe, 0, bars, volume) <= 0)
      return 1000;
   
   // Calculate average
   long totalVolume = 0;
   for(int i = 0; i < bars; i++)
      totalVolume += volume[i];
   
   double avgVolume = (double)totalVolume / bars;
   
   // Return threshold as multiplier of average
   long threshold = (long)(avgVolume * InpVolumeMultiplier);
   
   return MathMax(threshold, 100); // Minimum threshold
}

//+------------------------------------------------------------------+
//| Get zone information for debugging                               |
//+------------------------------------------------------------------+
string GetZoneInfo(CSupplyDemandZone *zone)
{
   if(zone == NULL)
      return "NULL";
   
   string info = StringFormat("%s Zone [%.5f - %.5f] Vol:%I64d Touches:%d State:%s",
                             zone.GetType() == SD_ZONE_SUPPLY ? "SUPPLY" : "DEMAND",
                             zone.GetBottom(),
                             zone.GetTop(),
                             zone.GetVolume(),
                             zone.GetTouchCount(),
                             EnumToString(zone.GetState()));
   
   return info;
}

//+------------------------------------------------------------------+
//| Trade Entry Logic Template (TO BE IMPLEMENTED)                   |
//+------------------------------------------------------------------+
bool CheckSupplyZoneEntry(CSupplyDemandZone *zone)
{
   if(zone == NULL || !zone.IsValid())
      return false;
   
   // TODO: Implement supply zone entry logic
   // - Check if price is touching zone
   // - Check zone state (prefer UNTESTED)
   // - Check for rejection patterns
   // - Verify volume confirmation
   
   return false;
}

bool CheckDemandZoneEntry(CSupplyDemandZone *zone)
{
   if(zone == NULL || !zone.IsValid())
      return false;
   
   // TODO: Implement demand zone entry logic
   // - Check if price is touching zone
   // - Check zone state (prefer UNTESTED)
   // - Check for bounce patterns
   // - Verify volume confirmation
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop and Trailing TP                            |
//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      bool modified = false;
      double newSL = posSL;
      double newTP = posTP;
      
      // Trailing Stop Logic
      if(InpEnableTrailingStop)
      {
         double trailDistance = InpTrailingStopDistance * point;
         double trailStep = InpTrailingStopStep * point;
         
         if(posType == POSITION_TYPE_BUY)
         {
            // BUY position: only trail if price has moved in profit beyond trailing distance
            if(currentPrice > posOpenPrice + trailDistance)
            {
               // Trail stop below current price
               double newStopLevel = currentPrice - trailDistance;
               
               // Only modify if new SL is higher than current SL by at least step amount
               if(newStopLevel > posSL + trailStep)
               {
                  newSL = NormalizeDouble(MathFloor(newStopLevel / tickSize) * tickSize, _Digits);
                  modified = true;
               }
            }
         }
         else // POSITION_TYPE_SELL
         {
            // SELL position: only trail if price has moved in profit beyond trailing distance
            if(currentPrice < posOpenPrice - trailDistance)
            {
               // Trail stop above current price
               double newStopLevel = currentPrice + trailDistance;
               
               // Only modify if new SL is lower than current SL by at least step amount
               if(newStopLevel < posSL - trailStep)
               {
                  newSL = NormalizeDouble(MathCeil(newStopLevel / tickSize) * tickSize, _Digits);
                  modified = true;
               }
            }
         }
      }
      
      // Trailing TP Logic
      if(InpEnableTrailingTP && posTP > 0)
      {
         double trailTPDistance = InpTrailingTPDistance * point;
         double trailTPStep = InpTrailingTPStep * point;
         
         if(posType == POSITION_TYPE_BUY)
         {
            // BUY position: only trail TP if price has moved in profit
            if(currentPrice > posOpenPrice + trailTPDistance)
            {
               // Move TP up with price
               double newTPLevel = currentPrice + trailTPDistance;
               
               // Only modify if new TP is higher than current TP by at least step amount
               if(newTPLevel > posTP + trailTPStep)
               {
                  newTP = NormalizeDouble(MathCeil(newTPLevel / tickSize) * tickSize, _Digits);
                  modified = true;
               }
            }
         }
         else // POSITION_TYPE_SELL
         {
            // SELL position: only trail TP if price has moved in profit
            if(currentPrice < posOpenPrice - trailTPDistance)
            {
               // Move TP down with price
               double newTPLevel = currentPrice - trailTPDistance;
               
               // Only modify if new TP is lower than current TP by at least step amount
               if(newTPLevel < posTP - trailTPStep)
               {
                  newTP = NormalizeDouble(MathFloor(newTPLevel / tickSize) * tickSize, _Digits);
                  modified = true;
               }
            }
         }
      }
      
      // Modify position if needed
      if(modified)
      {
         // Use current SL/TP if not trailing that particular one
         if(!InpEnableTrailingStop)
            newSL = posSL;
         if(!InpEnableTrailingTP)
            newTP = posTP;
         
         if(g_Trade.PositionModify(ticket, newSL, newTP))
         {
            if(InpDebugMode)
               Print("[Trailing] Ticket=", ticket, " Type=", EnumToString(posType), 
                     " NewSL=", newSL, " NewTP=", newTP);
         }
         else
         {
            if(InpDebugMode)
               Print("[Trailing] ERROR: Failed to modify ticket=", ticket, 
                     " - ", g_Trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double GetATR()
{
   if(g_ATRHandle == INVALID_HANDLE)
      return 0;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) <= 0)
      return 0;
   
   return atr[0];
}

//+------------------------------------------------------------------+
//| Check if position count exceeds maximum for this zone type      |
//+------------------------------------------------------------------+
bool HasPositionForZone(ENUM_SD_ZONE_TYPE zoneType)
{
   int positionCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      
      // Count positions matching zone type
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(zoneType == SD_ZONE_SUPPLY && posType == POSITION_TYPE_SELL)
         positionCount++;
      else if(zoneType == SD_ZONE_DEMAND && posType == POSITION_TYPE_BUY)
         positionCount++;
   }
   
   // Return true if max trades reached
   return (positionCount >= InpMaxTrade);
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                    |
//+------------------------------------------------------------------+
bool OpenBuyTrade(CSupplyDemandZone *zone)
{
   if(zone == NULL || !InpEnableTrading)
      return false;
   
   // Check if max trades reached
   if(HasPositionForZone(SD_ZONE_DEMAND))
   {
      if(InpDebugMode)
         Print("[OpenBuyTrade] Max trades (", InpMaxTrade, ") reached for DEMAND zones");
      return false;
   }
   
   double atr = GetATR();
   if(atr <= 0)
   {
      Print("[OpenBuyTrade] ERROR: Invalid ATR value");
      return false;
   }
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - (atr * InpATRMultiplierSL);
   double tp = price + (atr * InpATRMultiplierTP);
   
   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathFloor(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathCeil(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_BUY_D%.2f", InpTradeComment, zone.GetBottom());
   
   if(InpDebugMode)
      Print("[OpenBuyTrade] Entry=", price, " SL=", sl, " TP=", tp, " ATR=", atr);
   
   if(g_Trade.Buy(InpLotSize, _Symbol, price, sl, tp, comment))
   {
      Print("[OpenBuyTrade] BUY order opened: Ticket=", g_Trade.ResultOrder(), 
            " Entry=", price, " SL=", sl, " TP=", tp);
      return true;
   }
   else
   {
      Print("[OpenBuyTrade] ERROR: Failed to open BUY - ", g_Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                   |
//+------------------------------------------------------------------+
bool OpenSellTrade(CSupplyDemandZone *zone)
{
   if(zone == NULL || !InpEnableTrading)
      return false;
   
   // Check if max trades reached
   if(HasPositionForZone(SD_ZONE_SUPPLY))
   {
      if(InpDebugMode)
         Print("[OpenSellTrade] Max trades (", InpMaxTrade, ") reached for SUPPLY zones");
      return false;
   }
   
   double atr = GetATR();
   if(atr <= 0)
   {
      Print("[OpenSellTrade] ERROR: Invalid ATR value");
      return false;
   }
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + (atr * InpATRMultiplierSL);
   double tp = price - (atr * InpATRMultiplierTP);
   
   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathCeil(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathFloor(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_SELL_S%.2f", InpTradeComment, zone.GetTop());
   
   if(InpDebugMode)
      Print("[OpenSellTrade] Entry=", price, " SL=", sl, " TP=", tp, " ATR=", atr);
   
   if(g_Trade.Sell(InpLotSize, _Symbol, price, sl, tp, comment))
   {
      Print("[OpenSellTrade] SELL order opened: Ticket=", g_Trade.ResultOrder(),
            " Entry=", price, " SL=", sl, " TP=", tp);
      return true;
   }
   else
   {
      Print("[OpenSellTrade] ERROR: Failed to open SELL - ", g_Trade.ResultRetcodeDescription());
      return false;
   }
}
