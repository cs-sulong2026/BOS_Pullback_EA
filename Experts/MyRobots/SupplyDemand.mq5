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
#include "FileNLogger.mqh"
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

//--- Input parameters
input group "=== Account Information ==="
input bool              InpEnableEvaluation = true;      // Enable Prop Firm Evaluation Mode
input double            InpInitialBalance = 10000.0;     // Initial account balance for calculations
input double            InpDailyLossBreachedPct = 1.0;   // Daily Loss Breached percentage
input double            InpRiskConsistencyPct = 2.0;     // Risk Consistency Rule percentage per trade idea
input double            InpDailyLossLimitPct = 5.0;      // Daily loss limit percentage
input double            InpMaxLossLimitPct = 10.0;       // Maximum loss limit

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
input bool              InpSilentLogging = false;           // Silent Logging (no console output)
//--- Global objects
CSupplyDemandManager *g_SDManager = NULL;
CTrade            g_Trade;
CAccountInfo      account;

//--- Global indicators
int g_ATRHandle = INVALID_HANDLE;

//--- Tracking variables
datetime g_LastBarTime = 0;
datetime g_LastUpdateTime = 0;

//--- Evaluation tracking
double g_DailyLossThreshold = 0;        // DLL threshold value (resets daily)
double g_MaxLossThreshold = 0;          // MLL threshold value (permanent)
int g_DLBCount = 0;                     // Daily Loss Breach counter
int g_RCRCount = 0;                     // Risk Consistency Rule breach counter
bool g_TradingDisabled = false;         // Trading disabled flag
datetime g_LastResetTime = 0;           // Last daily reset time
string g_DisplayLabel = "SD_Eval";      // Chart label name
string g_FileName = "\\SnD_Data_"+IntegerToString(acc_login)+".dat";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize logging
   log_file = INVALID_HANDLE;
   acc_login = (int)account.Login();
   expert_folder = "SnD_Logs";
   work_folder = expert_folder+"\\"+CurrentAccountInfo(account.Server())+"_"+IntegerToString(acc_login);
   log_fileName = "\\SnD_"+RemoveDots(TimeToString(DateToString(), TIME_DATE))+".log";
   common_folder = false;
   log_enabled = InpDebugMode;
   silent_log = InpSilentLogging;

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
   
   // Initialize evaluation system
   if(InpEnableEvaluation)
   {
      double dailyLoss = InpInitialBalance * InpDailyLossLimitPct / 100.0;
      double maxLoss = InpInitialBalance * InpMaxLossLimitPct / 100.0;
      
      g_DailyLossThreshold = InpInitialBalance - dailyLoss;
      g_MaxLossThreshold = InpInitialBalance - maxLoss;
      g_DLBCount = 0;
      g_RCRCount = 0;
      g_TradingDisabled = false;
      g_LastResetTime = TimeCurrent();
      
      Print("Evaluation Mode ENABLED:");
      Print("  Initial Balance: $", InpInitialBalance);
      Print("  Daily Loss Limit: $", dailyLoss, " (Threshold: $", g_DailyLossThreshold, ")");
      Print("  Max Loss Limit: $", maxLoss, " (Threshold: $", g_MaxLossThreshold, ")");
      Print("  DLB %: ", InpDailyLossBreachedPct, "% | RCR %: ", InpRiskConsistencyPct, "%");
      
      CreateEvaluationDisplay();
   }
   
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
   
   // Clean up evaluation display
   if(InpEnableEvaluation)
   {
      for(int i = 0; i < 10; i++)
      {
         string labelName = g_DisplayLabel + "_" + IntegerToString(i);
         ObjectDelete(0, labelName);
      }
   }
   
   // if(InpDebugMode)
   //    Print("Supply & Demand EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_SDManager == NULL)
      return;
   
   // Check daily reset (23:55 server time)
   if(InpEnableEvaluation)
   {
      CheckDailyReset();
      CheckEvaluationLimits();
      UpdateEvaluationDisplay();
   }
   
   // Check for new bar
   datetime currentBarTime = iTime(_Symbol, InpZoneTimeframe, 0);
   bool isNewBar = (currentBarTime != g_LastBarTime);
   
   if(isNewBar)
   {
      g_LastBarTime = currentBarTime;
      
      if(InpUpdateOnNewBar)
      {
         // if(InpDebugMode)
         //    Print("New bar detected, updating zones...");
         
         // Detect new zones in recent bars
         g_SDManager.DetectNewZones(20);
         
         // Update existing zones (check for broken/touched zones)
         g_SDManager.UpdateAllZones();
         g_SDManager.ManageZoneDisplay();
      }
   }
   
   // Manage trailing stops and TPs
   if(InpEnableTrading && !g_TradingDisabled && (InpEnableTrailingStop || InpEnableTrailingTP))
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
      
      // if(InpDebugMode && !isNewBar)
      // {
      //    Print("Periodic update:");
      //    Print("  Supply zones: ", g_SDManager.GetSupplyZoneCount());
      //    Print("  Demand zones: ", g_SDManager.GetDemandZoneCount());
      // }
   }
   
   // Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get closest zones (for future trading logic)
   CSupplyDemandZone *closestSupply = g_SDManager.GetClosestSupplyZone(currentPrice);
   CSupplyDemandZone *closestDemand = g_SDManager.GetClosestDemandZone(currentPrice);
   
   // Debug: Show closest zone info
   // static datetime lastDebugTime = 0;
   // if(InpDebugMode && currentTime - lastDebugTime >= 60) // Every minute
   // {
   //    lastDebugTime = currentTime;
   //    
   //    if(closestSupply != NULL)
   //    {
   //       Print("Closest SUPPLY zone: ", closestSupply.GetBottom(), " - ", closestSupply.GetTop(),
   //             " | Distance: ", DoubleToString(closestSupply.GetDistanceToPrice(), 1), 
   //             " | Volume: ", closestSupply.GetVolume(),
   //             " | State: ", EnumToString(closestSupply.GetState()));
   //    }
   //    
   //    if(closestDemand != NULL)
   //    {
   //       Print("Closest DEMAND zone: ", closestDemand.GetBottom(), " - ", closestDemand.GetTop(),
   //             " | Distance: ", DoubleToString(closestDemand.GetDistanceToPrice(), 1),
   //             " | Volume: ", closestDemand.GetVolume(),
   //             " | State: ", EnumToString(closestDemand.GetState()));
   //    }
   // }
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
            // if(InpDebugMode)
            //    Print("[Trailing] Ticket=", ticket, " Type=", EnumToString(posType), 
            //          " NewSL=", newSL, " NewTP=", newTP);
         }
         else
         {
            // if(InpDebugMode)
            //    Print("[Trailing] ERROR: Failed to modify ticket=", ticket, 
            //          " - ", g_Trade.ResultRetcodeDescription());
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
//| Get position commission from deals                                |
//+------------------------------------------------------------------+
double GetPositionCommission(ulong positionTicket)
{
   double commission = 0;
   
   // Get position identifier
   if(!PositionSelectByTicket(positionTicket))
      return 0;
   
   ulong positionId = PositionGetInteger(POSITION_IDENTIFIER);
   
   // Search through deals history for this position
   HistorySelectByPosition(positionId);
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      }
   }
   
   return commission;
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
   if(zone == NULL || !InpEnableTrading || g_TradingDisabled)
      return false;
   
   // Check if max trades reached
   if(HasPositionForZone(SD_ZONE_DEMAND))
   {
      // if(InpDebugMode)
      //    Print("[OpenBuyTrade] Max trades (", InpMaxTrade, ") reached for DEMAND zones");
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
   
   // Check RCR before opening
   if(InpEnableEvaluation)
   {
      double potentialRisk = MathAbs(price - sl) * InpLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!CheckRiskConsistencyRule(_Symbol, POSITION_TYPE_BUY, potentialRisk))
      {
         Print("[EVAL] BUY trade blocked - Risk Consistency Rule would be breached");
         return false;
      }
   }
   
   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathFloor(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathCeil(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_BUY_D%.2f", InpTradeComment, zone.GetBottom());
   
   // if(InpDebugMode)
   //    Print("[OpenBuyTrade] Entry=", price, " SL=", sl, " TP=", tp, " ATR=", atr);
   
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
   if(zone == NULL || !InpEnableTrading || g_TradingDisabled)
      return false;
   
   // Check if max trades reached
   if(HasPositionForZone(SD_ZONE_SUPPLY))
   {
      // if(InpDebugMode)
      //    Print("[OpenSellTrade] Max trades (", InpMaxTrade, ") reached for SUPPLY zones");
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
   
   // Check RCR before opening
   if(InpEnableEvaluation)
   {
      double potentialRisk = MathAbs(price - sl) * InpLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!CheckRiskConsistencyRule(_Symbol, POSITION_TYPE_SELL, potentialRisk))
      {
         Print("[EVAL] SELL trade blocked - Risk Consistency Rule would be breached");
         return false;
      }
   }
   
   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathCeil(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathFloor(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_SELL_S%.2f", InpTradeComment, zone.GetTop());
   
   // if(InpDebugMode)
   //    Print("[OpenSellTrade] Entry=", price, " SL=", sl, " TP=", tp, " ATR=", atr);
   
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

//+------------------------------------------------------------------+
//| Check Daily Reset at 23:55 server time                          |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   MqlDateTime lastResetTime;
   TimeToStruct(g_LastResetTime, lastResetTime);
   
   // Check if it's 23:55 and we haven't reset today
   if(currentTime.hour == 23 && currentTime.min == 55)
   {
      if(currentTime.day != lastResetTime.day || currentTime.mon != lastResetTime.mon)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double dailyLoss = InpInitialBalance * InpDailyLossLimitPct / 100.0;
         
         // Reset threshold based on Equity vs Balance
         if(equity > balance)
            g_DailyLossThreshold = equity - dailyLoss;
         else
            g_DailyLossThreshold = balance - dailyLoss;
         
         g_LastResetTime = TimeCurrent();
         
         Print("[EVAL] Daily Reset at 23:55 | New DLL Threshold: $", g_DailyLossThreshold, 
               " | Equity: $", equity, " | Balance: $", balance);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Evaluation Limits (DLB, RCR, DLL, MLL)                    |
//+------------------------------------------------------------------+
void CheckEvaluationLimits()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Check Maximum Loss Limit (MLL) - Permanent disable
   if(equity <= g_MaxLossThreshold)
   {
      if(!g_TradingDisabled)
      {
         g_TradingDisabled = true;
         CloseAllPositions("MLL Breached");
         Print("[EVAL] *** MAXIMUM LOSS LIMIT BREACHED *** Equity: $", equity, 
               " <= MLL Threshold: $", g_MaxLossThreshold);
         Print("[EVAL] TRADING PERMANENTLY DISABLED - Manual intervention required");
         Alert("MLL BREACHED! Trading DISABLED. Equity: $", equity);
      }
      return;
   }
   
   // Check Daily Loss Limit (DLL) - Daily disable
   if(equity <= g_DailyLossThreshold)
   {
      if(!g_TradingDisabled)
      {
         g_TradingDisabled = true;
         CloseAllPositions("DLL Breached");
         Print("[EVAL] *** DAILY LOSS LIMIT BREACHED *** Equity: $", equity, 
               " <= DLL Threshold: $", g_DailyLossThreshold);
         Print("[EVAL] TRADING DISABLED until daily reset at 23:55");
         Alert("DLL BREACHED! Trading DISABLED until 23:55. Equity: $", equity);
      }
      return;
   }
   else
   {
      // Re-enable trading if DLL is no longer breached after reset
      if(g_TradingDisabled)
      {
         g_TradingDisabled = false;
         Print("[EVAL] Trading re-enabled after daily reset. Equity: $", equity);
      }
   }
   
   // Check Daily Loss Breached (DLB) - Soft limit
   double dlbThreshold = InpInitialBalance * (1.0 - InpDailyLossBreachedPct / 100.0);
   if(equity < dlbThreshold)
   {
      g_DLBCount++;
      CloseAllPositions("DLB Soft Breach");
      Print("[EVAL] *** DLB BREACHED *** Count: ", g_DLBCount, " | Equity: $", equity, 
            " < DLB Threshold: $", dlbThreshold, " (", InpDailyLossBreachedPct, "%)");
      Print("[EVAL] All positions closed. Trading continues with increased breach count.");
   }
}

//+------------------------------------------------------------------+
//| Check Risk Consistency Rule for trade idea                       |
//+------------------------------------------------------------------+
bool CheckRiskConsistencyRule(string symbol, ENUM_POSITION_TYPE direction, double newRisk)
{
   double totalRisk = newRisk; // Start with new trade risk
   
   // Calculate total risk for same symbol + direction (trade idea)
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType != direction) continue;
      
      // Calculate position risk (including floating loss)
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      double posProfit = PositionGetDouble(POSITION_PROFIT);
      double posSwap = PositionGetDouble(POSITION_SWAP);
      double posCommission = GetPositionCommission(ticket);
      
      // Risk = max potential loss from SL
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double posRisk = riskDistance * posLots * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      // Add current floating loss if negative
      double floatingPnL = posProfit + posSwap + posCommission;
      if(floatingPnL < 0)
         posRisk += MathAbs(floatingPnL);
      
      totalRisk += posRisk;
   }
   
   // Check against RCR percentage
   double rcrLimit = InpInitialBalance * InpRiskConsistencyPct / 100.0;
   
   if(totalRisk > rcrLimit)
   {
      g_RCRCount++;
      Print("[EVAL] *** RCR WOULD BE BREACHED *** Count: ", g_RCRCount, 
            " | Total Risk: $", totalRisk, " > RCR Limit: $", rcrLimit, " (", InpRiskConsistencyPct, "%)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close all positions with reason                                  |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      if(g_Trade.PositionClose(ticket))
      {
         closed++;
         Print("[EVAL] Closed position #", ticket, " - Reason: ", reason);
      }
   }
   
   if(closed > 0)
      Print("[EVAL] Total positions closed: ", closed, " - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Create Evaluation Display on Chart                               |
//+------------------------------------------------------------------+
void CreateEvaluationDisplay()
{
   int yOffset = 50;
   int lineHeight = 14;
   
   // Create 10 label lines
   for(int i = 0; i < 10; i++)
   {
      string labelName = g_DisplayLabel + "_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yOffset + (i * lineHeight));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrDarkGray);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Microsoft Sans Serif");
   }
}

//+------------------------------------------------------------------+
//| Update Evaluation Display on Chart                               |
//+------------------------------------------------------------------+
void UpdateEvaluationDisplay()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double dailyLossAllowed = InpInitialBalance * InpDailyLossLimitPct / 100.0;
   double maxLossAllowed = InpInitialBalance * InpMaxLossLimitPct / 100.0;
   
   double dailyRemaining = equity - g_DailyLossThreshold;
   double maxRemaining = equity - g_MaxLossThreshold;
   
   string statusText = g_TradingDisabled ? "DISABLED" : "ACTIVE";
   color statusColor = g_TradingDisabled ? clrRed : clrLime;
   
   // Line by line text
   string lines[10];
   lines[0] = "═══ EVALUATION STATUS ═══";
   lines[1] = "Status: " + statusText;
   lines[2] = StringFormat("Equity: $%.2f | Balance: $%.2f", equity, balance);
   lines[3] = "─────────────────────────";
   lines[4] = StringFormat("DLL: $%.2f / $%.2f (%.1f%%)", dailyRemaining, dailyLossAllowed, (dailyRemaining / dailyLossAllowed * 100.0));
   lines[5] = StringFormat("MLL: $%.2f / $%.2f (%.1f%%)", maxRemaining, maxLossAllowed, (maxRemaining / maxLossAllowed * 100.0));
   lines[6] = "─────────────────────────";
   lines[7] = StringFormat("DLB Count: %d (%.1f%%)", g_DLBCount, InpDailyLossBreachedPct);
   lines[8] = StringFormat("RCR Count: %d (%.1f%%)", g_RCRCount, InpRiskConsistencyPct);
   lines[9] = "";
   
   // Update each label
   for(int i = 0; i < 10; i++)
   {
      string labelName = g_DisplayLabel + "_" + IntegerToString(i);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lines[i]);
      
      // Color status line differently
      if(i == 1)
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, statusColor);
      else
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrDarkGray);
   }
}
