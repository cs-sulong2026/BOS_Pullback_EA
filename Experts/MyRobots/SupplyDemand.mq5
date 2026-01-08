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
input bool              InpEnableEvaluation = true;            // Enable Prop Firm Evaluation Mode
input bool              InpEnableLotSizeValidation = false;    // Enable Lot Size Validation (startup check)
input double            InpInitialBalance = 10000.0;           // Initial account balance for calculations
// Evaluation Rules Toggle
input bool              InpEnableDLB = false;                  // Enable Daily Loss Breached Rule (DLB)
input double            InpDailyLossBreachedPct = 1.0;         // Daily Loss Breached percentage
input double            InpRiskConsistencyPct = 2.0;           // Risk Consistency Rule percentage per trade idea
input double            InpDailyLossLimitPct = 5.0;            // Daily loss limit percentage
input double            InpMaxLossLimitPct = 10.0;             // Maximum loss limit
// Profit Sharing Rules
input double            InpProfitTargetPct = 10.0;             // Profit Target percentage
input double            InpProfitConsistencyPct = 20.0;        // Profit Consistency Rule percentage

input group "=== Zone Detection Settings ==="
input int               InpLookbackBars = 500;                 // Lookback Period (bars)
input long              InpVolumeThreshold = 1000;             // Volume Threshold (0=auto calculate)
input int               InpMinBarsInZone = 2;                  // Minimum Bars in Zone
input int               InpMaxBarsInZone = 10;                 // Maximum Bars in Zone
input double            InpMinZoneSize = 50.0;                 // Minimum Zone Size (points)
input double            InpMaxZoneSize = 1000.0;               // Maximum Zone Size (points)
input double            InpMinPriceLeftDistance = 20.0;        // Min Distance to Consider Left (points)

input group "=== Trading Settings ==="
input bool              InpEnableTrading = true;               // Enable Auto Trading
input double            InpLotSize = 0.01;                     // Fixed Lot Size
input int               InpMaxTrade = 3;                       // Maximum Concurrent Trades
input int               InpATRPeriod = 14;                     // ATR Period
input double            InpATRMultiplierSL = 2.0;              // ATR Multiplier for SL
input double            InpATRMultiplierTP = 3.0;              // ATR Multiplier for TP
input int               InpMagicNumber = 123456;               // Magic Number
input string            InpTradeComment = "SD_EA";             // Trade Comment

input group "=== Trailing Settings ==="
input bool              InpEnableTrailingStop = false;         // Enable Trailing Stop
input double            InpTrailingStopDistance = 50.0;        // Trailing Stop Distance (points)
input double            InpTrailingStopStep = 10.0;            // Trailing Stop Step (points)
input bool              InpEnableTrailingTP = false;           // Enable Trailing TP
input double            InpTrailingTPDistance = 50.0;          // Trailing TP Distance (points)
input double            InpTrailingTPStep = 10.0;              // Trailing TP Step (points)

input group "=== Zone Display Settings ==="
input int               InpShowZone = -1;                            // Show Zones (-1=all, 0=none, N=closest)
input color             InpSupplyColor = clrCrimson;              // Supply Zone Color
input color             InpDemandColor = clrDodgerBlue;           // Demand Zone Color
input color             InpSupplyColorFill = clrMistyRose;        // Supply Fill Color
input color             InpDemandColorFill = clrLightSteelBlue;   // Demand Fill Color
input int               InpZoneTransparency = 85;                    // Zone Transparency (0-100)
input bool              InpShowLabels = true;                        // Show Volume Labels

input group "=== Advanced Settings ==="
input ENUM_TIMEFRAMES   InpZoneTimeframe = PERIOD_CURRENT;     // Zone Detection Timeframe
input bool              InpAutoVolumeThreshold = true;         // Auto Calculate Volume Threshold
input double            InpVolumeMultiplier = 1.5;             // Volume Multiplier (for auto calc)
input bool              InpUpdateOnNewBar = true;              // Update Zones on New Bar
input int               InpUpdateIntervalSec = 300;            // Update Interval (seconds)
input bool              InpDebugMode = false;                  // Enable Debug Logging
input bool              InpSilentLogging = false;              // Silent Logging (no console output)

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

//--- Daily snapshot tracking
double g_DailyStartingEquity = 0;       // Starting equity for the day
double g_DailyStartingBalance = 0;      // Starting balance for the day
double g_LastEquityCheck = 0;           // Previous equity for edge detection

//--- Profit Consistency Tracking
double g_DailyProfits[];                // Array of daily profits (closed P/L + open loss)
double g_TodayOpeningBalance = 0;       // Balance at start of today (for daily P/L calc)

//+------------------------------------------------------------------+
//| Validate lot size compatibility with RCR limit                   |
//+------------------------------------------------------------------+
bool ValidateLotSizeForRCR()
{
   // Skip validation if disabled by user
   if(!InpEnableLotSizeValidation) return true;
   
   if(!InpEnableEvaluation || !InpEnableTrading) return true;
   
   // Calculate ATR manually from recent bars (more reliable at startup)
   double atrValue = 0.0;
   int lookback = InpATRPeriod + 10;  // Get extra bars for calculation
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(_Symbol, InpZoneTimeframe, 0, lookback, high) <= 0 ||
      CopyLow(_Symbol, InpZoneTimeframe, 0, lookback, low) <= 0 ||
      CopyClose(_Symbol, InpZoneTimeframe, 0, lookback, close) <= 0)
   {
      Logging("[VALIDATION] WARNING: Cannot get price data for validation - skipping");
      return true;  // Don't block initialization
   }
   
   // Calculate simple ATR estimation (average true range over period)
   double totalTR = 0.0;
   for(int i = 1; i < InpATRPeriod + 1; i++)
   {
      double tr1 = high[i] - low[i];
      double tr2 = MathAbs(high[i] - close[i+1]);
      double tr3 = MathAbs(low[i] - close[i+1]);
      totalTR += MathMax(tr1, MathMax(tr2, tr3));
   }
   atrValue = totalTR / InpATRPeriod;
   double slDistance = atrValue * InpATRMultiplierSL;
   
   // Calculate risk per trade
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskPerTrade = slDistance * InpLotSize * tickValue / tickSize;
   
   // Calculate maximum concurrent risk with InpMaxTrade positions
   double maxConcurrentRisk = riskPerTrade * InpMaxTrade;
   
   // RCR soft limit (90% of configured limit)
   double rcrSoftLimit = InpInitialBalance * InpRiskConsistencyPct * 0.9 / 100.0;
   
   // RCR hard limit (100% of configured limit)
   double rcrHardLimit = InpInitialBalance * InpRiskConsistencyPct / 100.0;
   
   // Log validation results
   Logging("===== LOT SIZE VALIDATION =====");
   Logging("  ATR Value: " + DoubleToString(atrValue, _Digits));
   Logging("  SL Distance: " + DoubleToString(slDistance, _Digits) + " (ATR × " + DoubleToString(InpATRMultiplierSL, 1) + ")");
   Logging("  Risk per trade: $" + DoubleToString(riskPerTrade, 2) + " (" + DoubleToString((riskPerTrade / InpInitialBalance) * 100, 2) + "%)");
   Logging("  Max concurrent risk: $" + DoubleToString(maxConcurrentRisk, 2) + " (" + IntegerToString(InpMaxTrade) + " trades)");
   Logging("  RCR Soft Limit (90%): $" + DoubleToString(rcrSoftLimit, 2) + " (" + DoubleToString(InpRiskConsistencyPct * 0.9, 2) + "%)");
   Logging("  RCR Hard Limit (100%): $" + DoubleToString(rcrHardLimit, 2) + " (" + DoubleToString(InpRiskConsistencyPct, 2) + "%)");
   
   // Check if single trade exceeds soft limit
   if(riskPerTrade > rcrSoftLimit)
   {
      Logging("===== ⚠️ LOT SIZE TOO LARGE =====");
      Logging("  CRITICAL: Risk per trade ($" + DoubleToString(riskPerTrade, 2) + ") exceeds RCR soft limit ($" + DoubleToString(rcrSoftLimit, 2) + ")");
      Logging("  EA will BLOCK all trades immediately!");
      Logging("  ");
      Logging("  RECOMMENDED ACTIONS:");
      double maxSafeLots = (rcrSoftLimit * tickSize) / (slDistance * tickValue);
      Logging("    1. Reduce lot size to: " + DoubleToString(maxSafeLots, 2) + " or lower");
      Logging("    2. Reduce ATR SL multiplier from " + DoubleToString(InpATRMultiplierSL, 1) + " to lower value");
      Logging("    3. Increase RCR limit from " + DoubleToString(InpRiskConsistencyPct, 1) + "% to higher value");
      Logging("================================");
      
      Alert("⚠️ LOT SIZE TOO LARGE! Risk $" + DoubleToString(riskPerTrade, 2) + " > RCR Limit $" + DoubleToString(rcrSoftLimit, 2) + 
            "\nReduce lot size to " + DoubleToString(maxSafeLots, 2) + " or adjust parameters!");
      
      return false;
   }
   
   // Check if concurrent trades might exceed hard limit
   if(maxConcurrentRisk > rcrHardLimit)
   {
      Logging("===== ⚠️ CONCURRENT RISK WARNING =====");
      Logging("  WARNING: Max concurrent risk ($" + DoubleToString(maxConcurrentRisk, 2) + ") may exceed RCR hard limit ($" + DoubleToString(rcrHardLimit, 2) + ")");
      Logging("  EA may disable trading if all " + IntegerToString(InpMaxTrade) + " trades open simultaneously");
      Logging("  ");
      Logging("  SUGGESTED ACTIONS:");
      int maxSafeTrades = (int)(rcrHardLimit / riskPerTrade);
      Logging("    1. Reduce MaxTrade from " + IntegerToString(InpMaxTrade) + " to " + IntegerToString(maxSafeTrades) + " or lower");
      Logging("    2. Reduce lot size for safer margin");
      Logging("=====================================");
      
      // This is a warning, not a blocker - return true but inform user
   }
   else
   {
      Logging("===== ✅ LOT SIZE VALIDATION PASSED =====");
      Logging("  Configuration is compatible with RCR limits");
      Logging("  Single trade risk is within acceptable range");
      Logging("=========================================");
   }
   
   return true;
}

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
                                 InpShowLabels);
   
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
         Logging("Zone detection complete:");
         Logging("  Supply zones: " + IntegerToString(g_SDManager.GetSupplyZoneCount()));
         Logging("  Demand zones: " + IntegerToString(g_SDManager.GetDemandZoneCount()));
      }
   }
   
   // Initialize tracking
   g_LastBarTime = iTime(_Symbol, InpZoneTimeframe, 0);
   g_LastUpdateTime = TimeCurrent();
   
   // Initialize evaluation system
   if(InpEnableEvaluation)
   {
      // Try to load existing daily data
      if(!LoadDailyData())
      {
         // First time or file not found - initialize with current values
         g_DailyStartingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         g_DailyStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         g_TodayOpeningBalance = g_DailyStartingBalance;  // Initialize today's opening balance
         ArrayResize(g_DailyProfits, 0);  // Initialize empty array
         SaveDailyData();
         Logging("[EVAL] Initialized new daily data - Equity: $" + DoubleToString(g_DailyStartingEquity, 2) + " | Balance: $" + DoubleToString(g_DailyStartingBalance, 2));
      }
      else
      {
         Logging("[EVAL] Loaded daily data - Equity: $" + DoubleToString(g_DailyStartingEquity, 2) + " | Balance: $" + DoubleToString(g_DailyStartingBalance, 2));
         Logging("[EVAL] Daily Profit History: " + IntegerToString(ArraySize(g_DailyProfits)) + " days recorded");
      }
      
      double dailyLoss = InpInitialBalance * InpDailyLossLimitPct / 100.0;
      double maxLoss = InpInitialBalance * InpMaxLossLimitPct / 100.0;
      
      g_DailyLossThreshold = InpInitialBalance - dailyLoss;
      g_MaxLossThreshold = InpInitialBalance - maxLoss;
      g_DLBCount = 0;
      g_RCRCount = 0;
      g_TradingDisabled = false;
      g_LastResetTime = TimeCurrent();
      g_LastEquityCheck = AccountInfoDouble(ACCOUNT_EQUITY);  // Initialize for edge detection
      
      Logging("  Evaluation Mode: ENABLED");
      Logging("  Initial Balance: $" + DoubleToString(InpInitialBalance, 2));
      Logging("  Daily Loss Limit: $" + DoubleToString(dailyLoss, 2) + " (Threshold: $" + DoubleToString(g_DailyLossThreshold, 2) + ")");
      Logging("  Max Loss Limit: $" + DoubleToString(maxLoss, 2) + " (Threshold: $" + DoubleToString(g_MaxLossThreshold, 2) + ")");
      Logging("  DLB %: " + DoubleToString(InpDailyLossBreachedPct, 2) + "% | RCR %: " + DoubleToString(InpRiskConsistencyPct, 2) + "%");
      
      CreateEvaluationDisplay();
      
      // Validate lot size compatibility with RCR limit
      if(!ValidateLotSizeForRCR())
      {
         Logging("[WARNING] Lot size may be too large for RCR limit - EA may block trades immediately!");
      }
   }
   
   Logging("Supply & Demand EA initialized successfully!");
   Logging("  Symbol: " + _Symbol);
   Logging("  Zone Timeframe: " + EnumToString(InpZoneTimeframe));
   Logging("  Show zones: " + (InpShowZone == -1 ? "All" : (InpShowZone == 0 ? "None" : IntegerToString(InpShowZone) + " closest")));
   Logging("  Volume threshold: " + DoubleToString(volumeThreshold, 2));
   Logging("  Auto Trading: " + (InpEnableTrailingStop ? "ENABLED" : "DISABLED"));
   
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
      Logging("[BUY] ERROR: Invalid ATR value");
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
         Logging("[EVAL] BUY trade blocked - Risk Consistency Rule would be breached");
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
      Logging("  🟢 BUY order opened: Ticket=" + IntegerToString(g_Trade.ResultOrder()) + 
            " Entry=" + DoubleToString(price, _Digits) + " SL=" + DoubleToString(sl, _Digits) + " TP=" + DoubleToString(tp, _Digits));
      return true;
   }
   else
   {
      Logging("[BUY] ERROR: Failed to open BUY - " + g_Trade.ResultRetcodeDescription());
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
      Logging("[SELL] ERROR: Invalid ATR value");
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
         Logging("[EVAL] SELL trade blocked - Risk Consistency Rule would be breached");
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
      Logging("  🔴 SELL order opened: Ticket=" + IntegerToString(g_Trade.ResultOrder()) +
            " Entry=" + DoubleToString(price, _Digits) + " SL=" + DoubleToString(sl, _Digits) + " TP=" + DoubleToString(tp, _Digits));
      return true;
   }
   else
   {
      Logging("[SELL] ERROR: Failed to open SELL - " + g_Trade.ResultRetcodeDescription());
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
         double dailyLoss = InpInitialBalance * InpDailyLossLimitPct * 0.9 / 100.0;  // Use 90% of DLL as soft limit
         
         // Calculate today's profit before reset (Total Closed P/L + Open Loss)
         // Daily profit = current balance - opening balance (closed P/L only, ignore floating)
         double todayProfit = balance - g_TodayOpeningBalance;
         
         // Add to daily profits array
         int arraySize = ArraySize(g_DailyProfits);
         ArrayResize(g_DailyProfits, arraySize + 1);
         g_DailyProfits[arraySize] = todayProfit;
         
         Logging("[EVAL] Daily Profit Recorded: $" + DoubleToString(todayProfit, 2) + " (Day " + IntegerToString(arraySize + 1) + ")");
         
         // Save current equity and balance as new daily starting values
         g_DailyStartingEquity = equity;
         g_DailyStartingBalance = balance;
         g_TodayOpeningBalance = balance;  // Reset for new day
         SaveDailyData();
         
         // Reset threshold based on Equity vs Balance
         if(equity > balance)
            g_DailyLossThreshold = equity - dailyLoss;
         else
            g_DailyLossThreshold = balance - dailyLoss;
         
         // Re-enable trading if it was disabled due to DLL
         g_TradingDisabled = false;
         
         // Reset last equity check for new day
         g_LastEquityCheck = equity;
         
         g_LastResetTime = TimeCurrent();
         
         Logging("[EVAL] Daily Reset at 23:55 - Saved new daily snapshot: Equity $" + DoubleToString(equity, _Digits) + " | Balance $" + DoubleToString(balance, _Digits));
         Logging("[EVAL] New DLL Threshold: $" + DoubleToString(g_DailyLossThreshold, _Digits));
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
         Logging("[EVAL] *** MAXIMUM LOSS LIMIT BREACHED *** Equity: $" + DoubleToString(equity, _Digits) + 
               " <= MLL Threshold: $" + DoubleToString(g_MaxLossThreshold, _Digits));
         Logging("[EVAL] TRADING PERMANENTLY DISABLED - Manual intervention required");
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
         Logging("[EVAL] *** DAILY LOSS LIMIT BREACHED *** Equity: $" + DoubleToString(equity, _Digits) + 
               " <= DLL Threshold: $" + DoubleToString(g_DailyLossThreshold, _Digits));
         Logging("[EVAL] TRADING DISABLED until daily reset at 23:55");
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
         Logging("[EVAL] Trading re-enabled after daily reset. Equity: $" + DoubleToString(equity, _Digits));
      }
   }
   
   // Check Risk Consistency Rule at 1.5% soft limit - close violating trade ideas
   CheckRCRSoftLimit();
   
   // Check Risk Consistency Rule HARD LIMIT (2%) - disable trading if exceeded
   CheckRCRHardLimit();
   
   // Check Daily Loss Breached (DLB) - Soft limit (check against daily starting equity/balance)
   // Only enforce if InpEnableDLB is true
   if(InpEnableDLB)
   {
      // Use edge detection: only count when crossing FROM above threshold TO below threshold
      double dailyStartBase = (g_DailyStartingEquity > g_DailyStartingBalance) ? g_DailyStartingEquity : g_DailyStartingBalance;
      double dlbThreshold = dailyStartBase * (1.0 - InpDailyLossBreachedPct / 100.0);
      
      // Check if we're crossing the threshold (edge detection)
      bool wasAboveThreshold = (g_LastEquityCheck >= dlbThreshold);
      bool isNowBelowThreshold = (equity < dlbThreshold);
      
      if(isNowBelowThreshold && wasAboveThreshold)
      {
         CloseAllPositions("DLB Soft Breach");
         Logging("[EVAL] *** DLB BREACHED *** Equity: $" + DoubleToString(equity, _Digits) + 
               " < DLB Threshold: $" + DoubleToString(dlbThreshold, _Digits) + " (" + DoubleToString(InpDailyLossBreachedPct, 2) + "%) | Daily Start: $" + DoubleToString(dailyStartBase, _Digits));
         Logging("[EVAL] All positions closed. Trading continues.");
         Alert("DLB BREACHED! Equity: $", equity);
      }
      
      // Update last equity for next check
      g_LastEquityCheck = equity;
   }
}

//+------------------------------------------------------------------+
//| Check RCR Soft Limit (1.5%) - Close violating trade ideas       |
//+------------------------------------------------------------------+
void CheckRCRSoftLimit()
{
   if(!InpEnableEvaluation)
      return;
   
   double rcrSoftLimit = InpInitialBalance * InpRiskConsistencyPct * 0.9 / 100.0;  // 90% of RCR limit
   
   // Calculate risk for BUY trade idea
   double buyRisk = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType != POSITION_TYPE_BUY) continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double slRisk = riskDistance * posLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      buyRisk += slRisk;
   }
   
   // Calculate risk for SELL trade idea
   double sellRisk = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType != POSITION_TYPE_SELL) continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double slRisk = riskDistance * posLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      sellRisk += slRisk;
   }
   
   // Check BUY trade idea
   if(buyRisk > rcrSoftLimit)
   {
      double buyRiskPct = (buyRisk / InpInitialBalance) * 100.0;
      Logging("[EVAL] *** RCR SOFT LIMIT BREACHED (BUY) *** Risk: $" + DoubleToString(buyRisk, 2) + 
            " (" + DoubleToString(buyRiskPct, 2) + "%) > 90% of " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit - Closing all BUY positions");
      Alert("RCR BREACH! Closing all BUY positions to prevent evaluation failure. Risk: ", DoubleToString(buyRiskPct, 2), "%");
      
      // Close all BUY positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(g_Trade.PositionClose(ticket))
               Logging("[EVAL] Closed BUY position #" + IntegerToString(ticket) + " - RCR Soft Limit");
         }
      }
   }
   
   // Check SELL trade idea
   if(sellRisk > rcrSoftLimit)
   {
      double sellRiskPct = (sellRisk / InpInitialBalance) * 100.0;
      Logging("[EVAL] *** RCR SOFT LIMIT BREACHED (SELL) *** Risk: $" + DoubleToString(sellRisk, 2) + 
            " (" + DoubleToString(sellRiskPct, 2) + "%) > 90% of " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit - Closing all SELL positions");
      Alert("RCR BREACH! Closing all SELL positions to prevent evaluation failure. Risk: ", DoubleToString(sellRiskPct, 2), "%");
      
      // Close all SELL positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if(g_Trade.PositionClose(ticket))
               Logging("[EVAL] Closed SELL position #" + IntegerToString(ticket) + " - RCR Soft Limit");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check RCR Hard Limit (2%) - Disable trading if exceeded         |
//+------------------------------------------------------------------+
void CheckRCRHardLimit()
{
   if(!InpEnableEvaluation)
      return;
   
   if(g_TradingDisabled)  // Already disabled
      return;
   
   double rcrHardLimit = InpInitialBalance * InpRiskConsistencyPct / 100.0;  // Full 2% limit
   
   // Calculate risk for BUY trade idea
   double buyRisk = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType != POSITION_TYPE_BUY) continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double slRisk = riskDistance * posLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      buyRisk += slRisk;
   }
   
   // Calculate risk for SELL trade idea
   double sellRisk = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType != POSITION_TYPE_SELL) continue;
      
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double slRisk = riskDistance * posLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      sellRisk += slRisk;
   }
   
   // Check if either trade idea exceeds HARD limit
   if(buyRisk > rcrHardLimit || sellRisk > rcrHardLimit)
   {
      g_TradingDisabled = true;
      CloseAllPositions("RCR HARD LIMIT BREACHED");
      
      double breachedRisk = MathMax(buyRisk, sellRisk);
      double breachedPct = (breachedRisk / InpInitialBalance) * 100.0;
      string direction = (buyRisk > sellRisk) ? "BUY" : "SELL";
      
      Logging("[EVAL] *** RCR HARD LIMIT BREACHED *** Direction: " + direction + " | Risk: $" + DoubleToString(breachedRisk, 2) + 
            " (" + DoubleToString(breachedPct, 2) + "%) >= " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit");
      Logging("[EVAL] TRADING DISABLED - Evaluation rules violated");
      Alert("CRITICAL: RCR HARD LIMIT BREACHED! Trading DISABLED. Risk: ", DoubleToString(breachedPct, 2), "%");
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
      
      // Only count SL risk, NOT floating losses
      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posLots = PositionGetDouble(POSITION_VOLUME);
      
      // Risk = max potential loss from SL only
      double riskDistance = MathAbs(posOpenPrice - posSL);
      double posRisk = riskDistance * posLots * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      totalRisk += posRisk;
   }
   
   // Check against RCR percentage (90% of limit as soft threshold)
   double rcrLimit = InpInitialBalance * InpRiskConsistencyPct * 0.9 / 100.0;
   
   if(totalRisk > rcrLimit)
   {
      Logging("[EVAL] *** RCR SOFT LIMIT EXCEEDED *** Total Risk: $" + DoubleToString(totalRisk, _Digits) + 
            " > 90% RCR Limit: $" + DoubleToString(rcrLimit, _Digits) + " (" + DoubleToString(InpRiskConsistencyPct * 0.9, 2) + "%)");
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
         Logging("[EVAL] Closed position #" + IntegerToString(ticket) + " - Reason: " + reason);
      }
   }
   
   if(closed > 0)
      Logging("[EVAL] Total positions closed: " + IntegerToString(closed) + " - Reason: " + reason);
}

//+------------------------------------------------------------------+
//| Save Daily Data to File                                          |
//+------------------------------------------------------------------+
bool SaveDailyData()
{
   if(!InpEnableEvaluation)
      return false;
      
   // Ensure work folder exists
   if(!FileIsExist(work_folder))
   {
      if(!CreateFolder(work_folder, common_folder))
      {
         Logging("[EVAL] Failed to create work folder: " + work_folder);
         return false;
      }
   }
   
   int handle = FileOpen(work_folder + g_FileName, FILE_WRITE | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      Logging("[EVAL] Failed to open file for writing: " + work_folder + g_FileName + " Error: " + IntegerToString(GetLastError()));
      return false;
   }
   
   // Write data version (updated to v2 for profit consistency)
   int version = 2;
   FileWriteInteger(handle, version, INT_VALUE);
   
   // Write daily snapshot data
   FileWriteDouble(handle, g_DailyStartingEquity);
   FileWriteDouble(handle, g_DailyStartingBalance);
   FileWriteLong(handle, g_LastResetTime);
   
   // Write profit consistency data
   int dailyProfitCount = ArraySize(g_DailyProfits);
   FileWriteInteger(handle, dailyProfitCount, INT_VALUE);
   for(int i = 0; i < dailyProfitCount; i++)
      FileWriteDouble(handle, g_DailyProfits[i]);
   
   FileWriteDouble(handle, g_TodayOpeningBalance);
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load Daily Data from File                                        |
//+------------------------------------------------------------------+
bool LoadDailyData()
{
   if(!InpEnableEvaluation)
      return false;
      
   if(!FileIsExist(work_folder + g_FileName))
   {
      Logging("[EVAL] Daily data file not found: " + work_folder + g_FileName);
      return false;
   }
   
   int handle = FileOpen(work_folder + g_FileName, FILE_READ | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      Logging("[EVAL] Failed to open file for reading: " + work_folder + g_FileName + " Error: " + IntegerToString(GetLastError()));
      return false;
   }
   
   // Read data version
   int version = FileReadInteger(handle, INT_VALUE);
   if(version < 1 || version > 2)
   {
      Logging("[EVAL] Unsupported data file version: " + IntegerToString(version));
      FileClose(handle);
      return false;
   }
   
   // Read daily snapshot data (version 1 and 2)
   g_DailyStartingEquity = FileReadDouble(handle);
   g_DailyStartingBalance = FileReadDouble(handle);
   g_LastResetTime = (datetime)FileReadLong(handle);
   
   // Read profit consistency data (version 2 only)
   if(version >= 2)
   {
      int dailyProfitCount = FileReadInteger(handle, INT_VALUE);
      ArrayResize(g_DailyProfits, dailyProfitCount);
      for(int i = 0; i < dailyProfitCount; i++)
         g_DailyProfits[i] = FileReadDouble(handle);
      
      g_TodayOpeningBalance = FileReadDouble(handle);
   }
   else
   {
      // Version 1 - initialize empty profit array
      ArrayResize(g_DailyProfits, 0);
      g_TodayOpeningBalance = g_DailyStartingBalance;
   }
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Create Evaluation Display on Chart                               |
//+------------------------------------------------------------------+
void CreateEvaluationDisplay()
{
   int yOffset = 50;
   int lineHeight = 14;
   
   // Create 14 label lines (added total days traded)
   for(int i = 0; i < 14; i++)
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
   
   // Calculate actual DLB percentage (based on daily starting equity/balance)
   // Only count losses from closed positions and balance changes, NOT floating unrealized losses
   double dailyStartBase = MathMax(g_DailyStartingEquity, g_DailyStartingBalance);
   double currentBase = MathMax(equity, balance); // Use the higher of equity or balance
   double dailyLoss = dailyStartBase - currentBase;
   
   // If in profit, stick at 0%
   double actualDLBPct = 0.0;
   if(dailyLoss > 0 && dailyStartBase > 0)
      actualDLBPct = dailyLoss / dailyStartBase * 100.0;
   
   // Calculate actual RCR percentage (highest risk from any trade idea)
   double maxRCRPct = 0.0;
   
   // Only calculate if there are positions for this EA
   bool hasOurPositions = false;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      hasOurPositions = true;
      break;
   }
   
   if(hasOurPositions)
   {
      // Track unique trade ideas (BUY and SELL separately)
      double buyIdeaRisk = 0.0;
      double sellIdeaRisk = 0.0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Only count SL risk, NOT floating losses
         double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posSL = PositionGetDouble(POSITION_SL);
         double posLots = PositionGetDouble(POSITION_VOLUME);
         
         // Calculate SL risk only
         double riskDistance = MathAbs(posOpenPrice - posSL);
         double slRisk = riskDistance * posLots * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         
         if(posType == POSITION_TYPE_BUY)
            buyIdeaRisk += slRisk;
         else
            sellIdeaRisk += slRisk;
      }
      
      // Get the highest risk percentage
      double buyRiskPct = (InpInitialBalance > 0) ? (buyIdeaRisk / InpInitialBalance * 100.0) : 0.0;
      double sellRiskPct = (InpInitialBalance > 0) ? (sellIdeaRisk / InpInitialBalance * 100.0) : 0.0;
      maxRCRPct = MathMax(buyRiskPct, sellRiskPct);
   }
   
   string statusText = g_TradingDisabled ? "DISABLED" : "ACTIVE";
   color statusColor = g_TradingDisabled ? clrRed : clrLime;
   
   // Calculate Profit Consistency (best day / total profit)
   double totalProfit = 0.0;
   double bestDayProfit = 0.0;
   int profitDays = ArraySize(g_DailyProfits);
   
   for(int i = 0; i < profitDays; i++)
   {
      totalProfit += g_DailyProfits[i];
      if(g_DailyProfits[i] > bestDayProfit)
         bestDayProfit = g_DailyProfits[i];
   }
   
   double profitConsistencyPct = 0.0;
   if(totalProfit > 0)
      profitConsistencyPct = (bestDayProfit / totalProfit) * 100.0;
   
   double profitTarget = InpInitialBalance * InpProfitTargetPct / 100.0;
   double currentProfit = balance - InpInitialBalance;
   
   // Line by line text (14 lines)
   string lines[14];
   lines[0] = "═══ EVALUATION STATUS ═══";
   lines[1] = "Status: " + statusText;
   lines[2] = StringFormat("Equity: $%.2f | Balance: $%.2f", equity, balance);
   lines[3] = "─────────────────────────";
   lines[4] = StringFormat("DLL: $%.2f / $%.2f (%.1f%%)", dailyRemaining, dailyLossAllowed, (dailyRemaining / dailyLossAllowed * 100.0));
   lines[5] = StringFormat("MLL: $%.2f / $%.2f (%.1f%%)", maxRemaining, maxLossAllowed, (maxRemaining / maxLossAllowed * 100.0));
   lines[6] = "─────────────────────────";
   lines[7] = StringFormat("DLB: %.2f%% | Limit: %.1f%%", actualDLBPct, InpDailyLossBreachedPct);
   lines[8] = StringFormat("RCR: %.2f%% | Limit: %.1f%%", maxRCRPct, InpRiskConsistencyPct);
   lines[9] = "─────────────────────────";
   lines[10] = StringFormat("Profit Target: $%.2f / $%.2f", currentProfit, profitTarget);
   lines[11] = StringFormat("Best Day: $%.2f | Total: $%.2f", bestDayProfit, totalProfit);
   lines[12] = StringFormat("Profit Consistency: %.1f%% (Limit: %.0f%%)", profitConsistencyPct, InpProfitConsistencyPct);
   lines[13] = StringFormat("Total Days Traded: %d", profitDays);
   
   // Update each label
   for(int i = 0; i < 14; i++)
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
