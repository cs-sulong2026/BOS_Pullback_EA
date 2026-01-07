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

//--- Input parameters
input group "=== Zone Detection Settings ==="
input int               InpLookbackBars = 500;           // Lookback Period (bars)
input long              InpVolumeThreshold = 1000;       // Volume Threshold (0=auto calculate)
input int               InpMinBarsInZone = 2;            // Minimum Bars in Zone
input int               InpMaxBarsInZone = 10;           // Maximum Bars in Zone
input double            InpMinZoneSize = 50.0;           // Minimum Zone Size (points)
input double            InpMaxZoneSize = 1000.0;         // Maximum Zone Size (points)

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
                              InpMinZoneSize, InpMaxZoneSize))
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
         
         // Re-detect zones on new bar
         g_SDManager.DetectZones();
      }
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
//| Open Buy Trade Template                                          |
//+------------------------------------------------------------------+
bool OpenBuyTrade(CSupplyDemandZone *zone)
{
   if(zone == NULL)
      return false;
   
   // TODO: Implement buy trade logic
   // - Calculate lot size based on risk
   // - Set stop loss at zone bottom
   // - Set take profit based on reward:risk
   // - Use CTrade object to place order
   
   return false;
}

//+------------------------------------------------------------------+
//| Open Sell Trade Template                                         |
//+------------------------------------------------------------------+
bool OpenSellTrade(CSupplyDemandZone *zone)
{
   if(zone == NULL)
      return false;
   
   // TODO: Implement sell trade logic
   // - Calculate lot size based on risk
   // - Set stop loss at zone top
   // - Set take profit based on reward:risk
   // - Use CTrade object to place order
   
   return false;
}
