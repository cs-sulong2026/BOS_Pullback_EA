//+------------------------------------------------------------------+
//|                                       CS Supply and Demand.mq5   |
//|                          Copyright © 2025-2026, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 07.01.2026 - Volume-based Supply & Demand EA                     |
//+------------------------------------------------------------------+
#property copyright "Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"
#property version   "1.21"
#property strict

#property description "An Expert Advisor that identifies Supply and Demand zones based on volume and trades accordingly."
#property description "Includes advanced trailing stop mechanisms using ATR, Bollinger Bands, PSAR, and Moving Averages."
#property description "WARNING: There is no guarantee that the expert advisor will work as intended. Use at your own risk."

// Include the Supply & Demand classes
#include "SupplyDemand.mqh"
#include "FileHelper.mqh"
#include <Charts/Chart.mqh>
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>
#include <errordescription.mqh>

//--- Input parameters
input group "=== Account Information ==="
input bool              InpEnableEvaluation = true;            // Enable Prop Firm Evaluation Mode
input bool              InpEnableLotSizeValidation = false;    // Enable Lot Size Validation (startup check)
input double            InpInitialBalance = 10000.0;           // Initial account balance for calculations
// Evaluation Rules Toggle
input bool              InpEnableProfitConsistencyRule = true; // Enable Profit Consistency Rule (if disabled, DLB applies automatically)
input double            InpDailyLossBreachedPct = 1.0;         // Daily Loss Breached percentage (for payout calculation)
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
input bool              InpEnableTradeOnWeakZone = false;      // Enable Trading on Weak Zones
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
input bool              InpEnableTrailingBBands = false;       // Enable Bollinger Bands Trailing SL and TP
input int               InpBBands_Period = 20;                 // Bollinger Bands Period
input int               InpBBands_Shift = 0;                   // Bollinger Bands Shift
input double            InpBBands_Deviation = 2.0;             // Bollinger Bands Deviation
input bool              InpEnableTrailingPSAR = false;         // Enable PSAR Trailing SL
input double            InpPSAR_Step = 0.02;                   // PSAR Step
input double            InpPSAR_Maximum = 0.2;                 // PSAR Maximum
input bool              InpEnableTrailingMA = false;           // Enable MA Trailing SL
input int               InpMA_Period = 14;                     // MA Period
input int               InpMA_Shift = 0;                       // MA Shift
input ENUM_MA_METHOD    InpMA_Method = MODE_SMA;               // MA Method
input ENUM_APPLIED_PRICE InpMA_Applied = PRICE_CLOSE;          // MA Applied Price
input bool              InpEnableTrailingTP = false;           // Enable Trailing TP
input double            InpTrailingTPDistance = 50.0;          // Trailing TP Distance (points)
input double            InpTrailingTPStep = 10.0;              // Trailing TP Step (points)
input bool              InpEnableDynamicATR_TP = false;        // Enable ATR-Based Dynamic TP
input double            InpDynamicTP_ATRMultiplier = 3.5;      // Dynamic TP ATR Multiplier

input group "=== Zone Display Settings ==="
input int               InpShowZone = -1;                         // Show Zones (-1=all, 0=none, N=closest)
input int               InpMaxZones = 20;                         // Maximum zones to track
input color             InpSupplyColor = clrCrimson;              // Supply Zone Color
input color             InpDemandColor = clrDodgerBlue;           // Demand Zone Color
input color             InpSupplyColorFill = clrMistyRose;        // Supply Fill Color
input color             InpDemandColorFill = clrLightSteelBlue;   // Demand Fill Color
input int               InpZoneTransparency = 85;                 // Zone Transparency (0-100)
input bool              InpShowLabels = true;                     // Show Volume Labels

input group "=== Advanced Settings ==="
input ENUM_TIMEFRAMES   InpZoneTimeframe = PERIOD_CURRENT;     // Zone Detection Timeframe
input bool              InpDetectZoneByVolume = true;          // Detect Zones by Volume
input bool              InpAutoVolumeThreshold = true;         // Auto Calculate Volume Threshold
input double            InpVolumeMultiplier = 1.5;             // Volume Multiplier (for auto calc)
input bool              InpUpdateOnNewBar = true;              // Update Zones on New Bar
input int               InpUpdateIntervalSec = 300;            // Update Interval (seconds)
input bool              InpEnableZonePersistence = true;       // Enable Zone Persistence (save/load zones)
input bool              InpDebugMode = false;                  // Enable Debug Logging
input bool              InpSilentLogging = false;              // Silent Logging (no console output)
input bool              InpDeleteFolder = false;               // Delete log folder on EA removal (Temporary)

//--- Global objects
CSupplyDemandManager *g_SDManager = NULL;
CChart               g_Chart;
CTrade               g_Trade;
CAccountInfo         account;
CFileLogger          *loG = NULL;
CChartObjectLabel    g_label[12];

//--- Global indicators
int g_ATRHandle = INVALID_HANDLE;
int g_cuATRHandle = INVALID_HANDLE;
int g_PSARHandle = INVALID_HANDLE;
int g_MAHandle = INVALID_HANDLE;
int g_BBandsHandle = INVALID_HANDLE;

//--- Tracking variables
datetime g_LastBarTime = 0;
datetime g_LastUpdateTime = 0;
bool     g_DailyTimerSet = false;

//--- Evaluation tracking
int   acc_login = 0;                    // Account login (set in OnInit)
double g_DailyLossThreshold = 0;        // DLL threshold value (resets daily)
double g_MaxLossThreshold = 0;          // MLL threshold value (permanent)
double g_DLBThreshold = 0;              // Daily Loss Breach threshold (for payout calculation)
int g_DLBCount = 0;                     // Daily Loss Breach counter
int g_RCRCount = 0;                     // Risk Consistency Rule breach counter
bool g_TradingDisabled = false;         // Trading disabled flag
datetime g_LastResetTime = 0;           // Last daily reset time
string g_DisplayLabel = "SD_Eval";      // Chart label name
string g_FileName = "";                 // Data file name (set in OnInit)
string g_ZonesFileName = "";            // Zones file name (set in OnInit)

//--- Daily snapshot tracking
double g_DailyStartingEquity = 0;       // Starting equity for the day
double g_DailyStartingBalance = 0;      // Starting balance for the day
double g_LastEquityCheck = 0;           // Previous equity for edge detection

//--- Profit Consistency Tracking
double g_DailyProfits[];                // Array of daily profits (closed P/L + open loss)
datetime g_DailyDates[];                // Array of dates for each daily profit
double g_TodayOpeningBalance = 0;       // Balance at start of today (for daily P/L calc)
double g_ProfitConsistencyPct = 0.0;    // Current profit consistency percentage
double g_HighestDLBPct = 0.0;           // Highest DLB % ever reached (for payout calculation)
double g_LastPayoutTier = 90.0;         // Last payout tier percentage (for change detection)
bool g_DLB_WarningShown = false;        // Flag to prevent repeated DLB 1.4% warnings
int g_TPHitCount = 0;                   // Total Take Profit hits
int g_SLHitCount = 0;                   // Total Stop Loss hits
int g_WinCount = 0;                     // Total winning trades
int g_LossCount = 0;                    // Total losing trades
datetime g_LastDealCheckTime = 0;       // Last time deals were checked

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
//| Logging wrapper function (for compatibility)                     |
//+------------------------------------------------------------------+
void Logging(string message)
{
   if(loG != NULL)
      loG.Log(message);
   else
      Print(message);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize logging
   loG = new CFileLogger();
   if(loG == NULL)
   {
      Print("ERROR: Failed to create logger");
      return INIT_FAILED;
   }
   
   acc_login = (int)account.Login();
   g_FileName = "\\SnD_Data_" + IntegerToString(acc_login) + ".dat";
   g_ZonesFileName = "\\SnD_Zones_" + _Symbol + "_" + IntegerToString(acc_login) + ".dat";
   
   if(!loG.Initialize("SnD_Logs", "SnD", acc_login, account.Server(), false))
   {
      Print("ERROR: Failed to initialize logger");
      delete loG;
      loG = NULL;
      return INIT_FAILED;
   }
   
   loG.SetEnabled(InpDebugMode);
   loG.SetSilentMode(InpSilentLogging);
   loG.Info("===== Supply & Demand EA Initialization =====");

   // Create chart template object
   g_Chart.Attach(0);
   if(!CreateCustomChart())
   {
      loG.Error("Failed to create custom chart template! Error '" + ErrorDescription(GetLastError()) + "'");
      return INIT_FAILED;
   }

   // Create Supply & Demand Manager
   g_SDManager = new CSupplyDemandManager();
   if(g_SDManager == NULL)
   {
      loG.Error("Failed to create Supply Demand Manager! Error '" + ErrorDescription(GetLastError()) + "'");
      return INIT_FAILED;
   }
   
   // Calculate volume threshold if auto mode
   long volumeThreshold = InpVolumeThreshold;
   if(InpAutoVolumeThreshold)
   {
      volumeThreshold = CalculateVolumeThreshold();

      loG.Log("  Auto-calculated volume threshold: " + IntegerToString(volumeThreshold));
   }
   
   // Initialize manager
   if(!g_SDManager.Initialize(_Symbol, InpZoneTimeframe, InpLookbackBars, 
                              volumeThreshold, InpMinBarsInZone, InpMaxBarsInZone,
                              InpMinZoneSize, InpMaxZoneSize, InpMinPriceLeftDistance))
   {
      loG.Error("Failed to initialize Supply Demand Manager! Error '" + ErrorDescription(GetLastError()) + "'");
      delete g_SDManager;
      g_SDManager = NULL;
      return INIT_FAILED;
   }
   
   // Set display settings
   g_SDManager.SetShowZones(InpShowZone);
   g_SDManager.SetVisualSettings(InpSupplyColor, InpDemandColor, InpSupplyColorFill,
                                 InpDemandColorFill, InpZoneTransparency, 
                                 InpShowLabels);
   g_SDManager.SetEnableTradeOnWeakZone(InpEnableTradeOnWeakZone);
   
   // Load existing zones from file if persistence is enabled
   if(InpEnableZonePersistence)
   {
      string workFolder = loG.GetWorkFolder();
      if(g_SDManager.LoadZonesFromFile(workFolder + g_ZonesFileName))
      {
         loG.Info("  Successfully loaded zones from previous session");
         loG.Info("  Supply zones: " + IntegerToString(g_SDManager.GetSupplyZoneCount()) + " | Demand zones: " + IntegerToString(g_SDManager.GetDemandZoneCount()));
      }
      else
      {
         loG.Info("  No existing zones file found - will detect zones fresh");
      }
   }
   
   // Initialize trading
   if(InpEnableTrading)
   {
      g_Trade.SetExpertMagicNumber(InpMagicNumber);
      g_Trade.SetDeviationInPoints(10);
      g_Trade.SetTypeFilling(ORDER_FILLING_FOK);
      g_Trade.SetAsyncMode(false);
      g_Trade.LogLevel(-1);  // Disable trade logging
      
      // Create ATR indicator
      g_ATRHandle = iATR(_Symbol, InpZoneTimeframe, InpATRPeriod);
      if(g_ATRHandle == INVALID_HANDLE)
      {
         loG.Error("Failed to create ATR indicator! Error '" + ErrorDescription(GetLastError()) + "'");
         delete g_SDManager;
         g_SDManager = NULL;
         return INIT_FAILED;
      }

      // // Create Bollinger Bands indicator if enabled
      // if(InpEnableTrailingBBands)
      // {
      //    g_BBandsHandle = iBands(_Symbol, InpZoneTimeframe, InpBBands_Period, InpBBands_Shift, InpBBands_Deviation, PRICE_WEIGHTED);
      //    if(g_BBandsHandle == INVALID_HANDLE)
      //    {
      //       loG.Error("Failed to create Bollinger Bands indicator! Error '" + ErrorDescription(GetLastError()) + "'");
      //       delete g_SDManager;
      //       g_SDManager = NULL;
      //       return INIT_FAILED;
      //    }
      //    loG.Log("  Bollinger Bands Trailing SL/TP enabled (Period=20, Deviation=2.0)");
      // }

      // Create current ATR indicator for dynamic TP if enabled
      if(InpEnableDynamicATR_TP)
      {
         g_cuATRHandle = iATR(_Symbol, ChartPeriod(), InpATRPeriod);
         if(g_cuATRHandle == INVALID_HANDLE)
         {
            loG.Error("Failed to create Current ATR indicator! Error '" + ErrorDescription(GetLastError()) + "'");
            delete g_SDManager;
            g_SDManager = NULL;
            return INIT_FAILED;
         }
         loG.Log("  Dynamic ATR-based TP enabled (Multiplier=" + DoubleToString(InpDynamicTP_ATRMultiplier, 2) + ")");
      }
      
      // Create PSAR indicator if enabled
      if(InpEnableTrailingPSAR)
      {
         g_PSARHandle = iSAR(_Symbol, PERIOD_CURRENT, InpPSAR_Step, InpPSAR_Maximum);
         if(g_PSARHandle == INVALID_HANDLE)
         {
            loG.Error("Failed to create PSAR indicator! Error '" + ErrorDescription(GetLastError()) + "'");
            delete g_SDManager;
            g_SDManager = NULL;
            return INIT_FAILED;
         }
         loG.Log("  PSAR Trailing SL enabled (Step=" + DoubleToString(InpPSAR_Step, 2) + ", Max=" + DoubleToString(InpPSAR_Maximum, 2) + ")");
      }
      
      // Create MA indicator if enabled
      if(InpEnableTrailingMA)
      {
         g_MAHandle = iMA(_Symbol, PERIOD_CURRENT, InpMA_Period, InpMA_Shift, InpMA_Method, InpMA_Applied);
         if(g_MAHandle == INVALID_HANDLE)
         {
            loG.Error("Failed to create MA indicator! Error '" + ErrorDescription(GetLastError()) + "'");
            delete g_SDManager;
            g_SDManager = NULL;
            return INIT_FAILED;
         }
         loG.Log("  MA Trailing SL enabled (Period=" + IntegerToString(InpMA_Period) + ", Method=" + EnumToString(InpMA_Method) + ")");
      }
      
      // Create Bollinger Bands indicator if enabled
      if(InpEnableTrailingBBands)
      {
         g_BBandsHandle = iBands(_Symbol, PERIOD_CURRENT, InpBBands_Period, InpBBands_Shift, InpBBands_Deviation, PRICE_WEIGHTED);
         if(g_BBandsHandle == INVALID_HANDLE)
         {
            loG.Error("Failed to create Bollinger Bands indicator! Error '" + ErrorDescription(GetLastError()) + "'");
            delete g_SDManager;
            g_SDManager = NULL;
            return INIT_FAILED;
         }
         loG.Log("  Bollinger Bands Trailing enabled (Period=" + IntegerToString(InpBBands_Period) + ", Deviation=" + DoubleToString(InpBBands_Deviation, 1) + ")");
      }
      
      loG.Log("  Trading enabled with Magic Number: " + IntegerToString(InpMagicNumber));
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
         loG.Info("  Initialized new daily data - Equity: $" + DoubleToString(g_DailyStartingEquity, 2) + " | Balance: $" + DoubleToString(g_DailyStartingBalance, 2));
      }
      else
      {
         loG.Info("  Loaded daily data - Equity: $" + DoubleToString(g_DailyStartingEquity, 2) + " | Balance: $" + DoubleToString(g_DailyStartingBalance, 2));
         loG.Info("  Daily Profit History: " + IntegerToString(ArraySize(g_DailyProfits)) + " days recorded");
      }
      
      double dailyLoss = InpInitialBalance * InpDailyLossLimitPct / 100.0;
      double maxLoss = InpInitialBalance * InpMaxLossLimitPct / 100.0;
      double DLBLoss = InpInitialBalance * InpDailyLossBreachedPct / 100.0;
      
      g_DailyLossThreshold = InpInitialBalance - dailyLoss;
      g_MaxLossThreshold = InpInitialBalance - maxLoss;
      g_DLBThreshold = InpInitialBalance - DLBLoss;
      
      g_DLBCount = 0;
      g_RCRCount = 0;
      g_TradingDisabled = false;
      g_DLB_WarningShown = false;
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
   
   loG.Info("Supply & Demand EA initialized successfully!");
   Logging("  Symbol: " + _Symbol);
   Logging("  Zone Timeframe: " + EnumToString(InpZoneTimeframe));
   Logging("  Show zones: " + (InpShowZone == -1 ? "All" : (InpShowZone == 0 ? "None" : IntegerToString(InpShowZone) + " closest")));
   Logging("  Volume threshold: " + DoubleToString(volumeThreshold, 2));
   Logging("  Auto Trading: " + (InpEnableTrading ? "ENABLED" : "DISABLED"));

   EventSetTimer(1);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save zones before cleanup if persistence is enabled
   if(InpEnableZonePersistence && g_SDManager != NULL && loG != NULL)
   {
      string workFolder = loG.GetWorkFolder();
      g_SDManager.SaveZonesToFile(workFolder + g_ZonesFileName);
      loG.Info("Zones saved to file on EA shutdown");
   }
   
   // Cleanup logger
   if(loG != NULL)
   {
      loG.Separator("===== Supply & Demand EA Shutdown =====");
      delete loG;
      loG = NULL;
   }
   
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

   // Release Bollinger Bands indicator
   if(g_BBandsHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_BBandsHandle);
      g_BBandsHandle = INVALID_HANDLE;
   }

   // Release Current ATR indicator
   if(g_cuATRHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_cuATRHandle);
      g_cuATRHandle = INVALID_HANDLE;
   }
   
   // Release PSAR indicator
   if(g_PSARHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_PSARHandle);
      g_PSARHandle = INVALID_HANDLE;
   }
   
   // Release MA indicator
   if(g_MAHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_MAHandle);
      g_MAHandle = INVALID_HANDLE;
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
   
   // Delete testing logs if debug mode enabled
   DeleteTestingLogs();
   
   // if(InpDebugMode)
   // Print("Supply & Demand EA deinitialized. Reason: " + IntegerToString(reason));
   //--- destroy timer
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_SDManager == NULL)
      return;
   
   // Evaluation checks
   if(InpEnableEvaluation)
   {
      CheckTPSLHits();
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
         // Detect new zones on new bar
         if(InpDetectZoneByVolume)
            g_SDManager.DetectNewZones(20);
         else
            g_SDManager.DetectNewPriceActionZones(20);
      }
      
      if(InpEnableTrading && !g_TradingDisabled && InpEnableTrailingBBands)
      {
         ManageTrailing();
      }
   }
   
   // Time-based update (runs independently of new bar)
   datetime currentTime = TimeCurrent();
   bool shouldUpdate = (currentTime - g_LastUpdateTime >= InpUpdateIntervalSec);
   
   // Update zones if: 1) new bar with update enabled, OR 2) time interval reached
   if((isNewBar && InpUpdateOnNewBar) || shouldUpdate)
   {
      if(shouldUpdate)
         g_LastUpdateTime = currentTime;
      
      // Update all zones (state management, extension, cleanup)
      g_SDManager.UpdateAllZones();
      g_SDManager.ManageZoneDisplay();
      
      // Save zones to file if persistence is enabled
      if(InpEnableZonePersistence)
      {
         string workFolder = loG.GetWorkFolder();
         if(!g_SDManager.SaveZonesToFile(workFolder + g_ZonesFileName))
         {
            loG.Warning("Failed to save zones to file");
         }
      }
   }
   
   // Manage trailing stops and TPs
   if(InpEnableTrading && !g_TradingDisabled && (InpEnableTrailingStop || InpEnableTrailingTP))
   {
      ManageTrailing();
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
   // if(g_SDManager != NULL)
   // {
      // g_SDManager.UpdateAllZones();
      // g_SDManager.ManageZoneDisplay();
   // }
   
   // Check daily reset (23:55 server time)
   CheckDailyReset();
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
   // bool isTouched = false;

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
      
      // PSAR Trailing Stop Logic
      if(InpEnableTrailingPSAR && g_PSARHandle != INVALID_HANDLE)
      {
         double psarBuffer[];
         ArraySetAsSeries(psarBuffer, true);
         if(CopyBuffer(g_PSARHandle, 0, 0, 2, psarBuffer) > 0)
         {
            double level = (posType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) - SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point :
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
            
            double psar_sl = NormalizeDouble(psarBuffer[1], _Digits);
            double base = (posSL == 0.0) ? posOpenPrice : posSL;
            
            if(posType == POSITION_TYPE_BUY)
            {
               // For long: PSAR should be below price and higher than current SL
               if(psar_sl > base && psar_sl < level)
               {
                  newSL = psar_sl;
                  modified = true;
               }
            }
            else // POSITION_TYPE_SELL
            {
               // For short: PSAR should be above price and lower than current SL
               psar_sl = NormalizeDouble(psar_sl + SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point, _Digits);
               if(psar_sl < base && psar_sl > level)
               {
                  newSL = psar_sl;
                  modified = true;
               }
            }
         }
      }
      
      // MA Trailing Stop Logic
      if(InpEnableTrailingMA && g_MAHandle != INVALID_HANDLE)
      {
         double maBuffer[];
         ArraySetAsSeries(maBuffer, true);
         if(CopyBuffer(g_MAHandle, 0, 0, 2, maBuffer) > 0)
         {
            double level = (posType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) - SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point :
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
            
            double ma_sl = NormalizeDouble(maBuffer[1], _Digits);
            double base = (posSL == 0.0) ? posOpenPrice : posSL;
            
            if(posType == POSITION_TYPE_BUY)
            {
               // For long: MA should be below price and higher than current SL
               if(ma_sl > base && ma_sl < level)
               {
                  // Use the better SL (higher for longs)
                  if(ma_sl > newSL)
                  {
                     newSL = ma_sl;
                     modified = true;
                  }
               }
            }
            else // POSITION_TYPE_SELL
            {
               // For short: MA should be above price and lower than current SL
               ma_sl = NormalizeDouble(ma_sl + SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point, _Digits);
               if(ma_sl < base && ma_sl > level)
               {
                  // Use the better SL (lower for shorts)
                  if(ma_sl < newSL || newSL == posSL)
                  {
                     newSL = ma_sl;
                     modified = true;
                  }
               }
            }
         }
      }
      
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
                  double candidateSL = NormalizeDouble(MathFloor(newStopLevel / tickSize) * tickSize, _Digits);
                  // Use the better SL (higher for longs)
                  if(candidateSL > newSL)
                  {
                     newSL = candidateSL;
                     modified = true;
                  }
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
                  double candidateSL = NormalizeDouble(MathCeil(newStopLevel / tickSize) * tickSize, _Digits);
                  // Use the better SL (lower for shorts)
                  if(candidateSL < newSL || newSL == posSL)
                  {
                     newSL = candidateSL;
                     modified = true;
                  }
               }
            }
         }
      }
      
      // Bollinger Bands Trailing Stop and TP Logic
      if(InpEnableTrailingBBands && g_BBandsHandle != INVALID_HANDLE)
      {
         int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

         // 0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND
         bool upperRange = (currentPrice >= GetBollingerBand(0) && currentPrice <= GetBollingerBand(1));
         bool lowerRange = (currentPrice >= GetBollingerBand(2) && currentPrice <= GetBollingerBand(0));
         bool overRange = (currentPrice > GetBollingerBand(1) || currentPrice < GetBollingerBand(2));
         bool isTouched = (currentPrice >= GetBollingerBand(1) || currentPrice <= GetBollingerBand(2));

         if(overRange)
            continue; // No trailing outside bands
         
         if(posType == POSITION_TYPE_BUY)
         {
            double bandSL = 0.0;

            if(upperRange)
            {
               if(isTouched)
                  bandSL =  MathRound(GetBollingerBand(0)); // middle band
               else
                  bandSL =  MathRound(GetBollingerBand(2)); // lower band
            }
            else if(lowerRange)
            {
               if(isTouched)
                  bandSL =  MathRound(GetBollingerBand(0)); // middle band
               else
                  bandSL =  MathRound(GetBollingerBand(2)); // lower band
            }
            // Trail SL: only move higher, must be below current price
            if(bandSL < currentPrice && bandSL > posSL)
            {
               // Respect minimum stop level
               if(currentPrice - bandSL >= stopLevel * point)
               {
                  bandSL = NormalizeDouble(MathFloor(bandSL / tickSize) * tickSize, _Digits);
                  if(bandSL > newSL)
                  {
                     newSL = bandSL;
                     modified = true;
                  }
               }
            }
            
            if(posTP > 0)
            {
               double bandTP = 0.0;

               if(upperRange)
                  bandTP =  MathRound(GetBollingerBand(1)); // upper band
               else if(lowerRange)
                  bandTP =  MathRound(GetBollingerBand(0)); // middle band
               
               if(bandTP < posTP)
               {
                  // Ensure TP is above current price with minimum distance
                  if(bandTP > currentPrice && (bandTP - currentPrice) >= stopLevel * point)
                  {
                     bandTP = NormalizeDouble(MathCeil(bandTP / tickSize) * tickSize, _Digits);
                     if(bandTP > newTP)
                     {
                        newTP = bandTP;
                        modified = true;
                     }
                  }
               }
            }
         }
         else // POSITION_TYPE_SELL
         {
            // For SELL: Use upper band [1] as trailing SL (avoid repainting)
            double bandSL = 0.0;

            if(upperRange)
            {
               if(isTouched)
                  bandSL =  MathRound(GetBollingerBand(0)); // middle band
               else
                  bandSL =  MathRound(GetBollingerBand(1)); // upper band
            }
            else if(lowerRange)
            {
               if(isTouched)
                  bandSL =  MathRound(GetBollingerBand(0)); // middle band
               else
                  bandSL =  MathRound(GetBollingerBand(1)); // upper band
            }
            
            // Trail SL: only move lower, must be above current price
            if(bandSL > currentPrice && bandSL < posSL)
            {
               // Respect minimum stop level
               if(bandSL - currentPrice >= stopLevel * point)
               {
                  bandSL = NormalizeDouble(MathCeil(bandSL / tickSize) * tickSize, _Digits);
                  if(posSL == 0 || bandSL < newSL)
                  {
                     newSL = bandSL;
                     modified = true;
                  }
               }
            }
            
            if(posTP > 0)
            {
               double bandTP = 0.0;

               if(upperRange)
                  bandTP =  MathRound(GetBollingerBand(0)); // middle band
               else if(lowerRange)
                  bandTP =  MathRound(GetBollingerBand(2)); // lower band
               
               // Trail TP: only move lower, should be reasonable target
               if(bandTP > posTP)
               {
                  // Ensure TP is below current price with minimum distance
                  if(bandTP < currentPrice && (currentPrice - bandTP) >= stopLevel * point)
                  {
                     bandTP = NormalizeDouble(MathFloor(bandTP / tickSize) * tickSize, _Digits);
                     if(posTP == 0 || bandTP < newTP)
                     {
                        newTP = bandTP;
                        modified = true;
                     }
                  }
               }
            }
         }

      }

      // ATR-Based Dynamic TP Logic (Trailing - only extends, distance tightens with profit)
      if(InpEnableDynamicATR_TP && posTP > 0 && g_ATRHandle != INVALID_HANDLE)
      {
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         if(CopyBuffer(g_ATRHandle, 0, 0, 2, atrBuffer) > 0)
         {
            double currentATR = atrBuffer[0];
            
            if(posType == POSITION_TYPE_BUY)
            {
               // Calculate profit in ATR units
               double profitDistance = currentPrice - posOpenPrice;
               double profitInATR = (currentATR > 0) ? (profitDistance / currentATR) : 0;
               
               // Progressively reduce TP distance as profit increases
               // Start with full multiplier, reduce by 50% for each ATR unit of profit
               double adjustedMultiplier = InpDynamicTP_ATRMultiplier;
               if(profitInATR > 0)
               {
                  adjustedMultiplier = InpDynamicTP_ATRMultiplier * MathPow(0.50, profitInATR);
                  // Don't go below 1.0 ATR distance (minimum target)
                  adjustedMultiplier = MathMax(adjustedMultiplier, 1.0);
               }
               
               double dynamicTPDistance = currentATR * adjustedMultiplier;
               double dynamicTPLevel = currentPrice + dynamicTPDistance;
               dynamicTPLevel = NormalizeDouble(MathCeil(dynamicTPLevel / tickSize) * tickSize, _Digits);
               
               // Only extend TP if new level is HIGHER than current TP (trailing behavior)
               if(dynamicTPLevel > posTP && dynamicTPLevel > currentPrice)
               {
                  newTP = dynamicTPLevel;
                  modified = true;
               }
            }
            else // POSITION_TYPE_SELL
            {
               // Calculate profit in ATR units
               double profitDistance = posOpenPrice - currentPrice;
               double profitInATR = (currentATR > 0) ? (profitDistance / currentATR) : 0;
               
               // Progressively reduce TP distance as profit increases
               double adjustedMultiplier = InpDynamicTP_ATRMultiplier;
               if(profitInATR > 0)
               {
                  adjustedMultiplier = InpDynamicTP_ATRMultiplier * MathPow(0.50, profitInATR);
                  adjustedMultiplier = MathMax(adjustedMultiplier, 1.0);
               }
               
               double dynamicTPDistance = currentATR * adjustedMultiplier;
               double dynamicTPLevel = currentPrice - dynamicTPDistance;
               dynamicTPLevel = NormalizeDouble(MathFloor(dynamicTPLevel / tickSize) * tickSize, _Digits);
               
               // Only extend TP if new level is LOWER than current TP (trailing behavior)
               if(dynamicTPLevel < posTP && dynamicTPLevel < currentPrice)
               {
                  newTP = dynamicTPLevel;
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
         // Validate SL/TP were actually modified by trailing logic
         // If no trailing method changed SL, keep original
         if(newSL == posSL && !InpEnableTrailingStop && !InpEnableTrailingPSAR && !InpEnableTrailingMA)
            newSL = posSL;
         
         // If no trailing method changed TP, keep original
         if(newTP == posTP && !InpEnableTrailingTP && !InpEnableDynamicATR_TP)
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
//| Get Bollinger Band value                                         |
//+------------------------------------------------------------------+
double GetBollingerBand(int bandType)
{
   if(g_BBandsHandle == INVALID_HANDLE)
      return 0;
   
   double bandBuffer[];
   // int amount = MathAbs(InpBBands_Shift) + 1;
   ArraySetAsSeries(bandBuffer, true);
   
   if(CopyBuffer(g_BBandsHandle, bandType, 0, 2, bandBuffer) <= 0)
      return 0;
   
   return bandBuffer[1];
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
      loG.Info("[OpenBuyTrade] Max trades (" + IntegerToString(InpMaxTrade) + ") reached for DEMAND zones");
      return false;
   }
   
   double atr = GetATR();
   if(atr <= 0)
   {
      loG.Error("[BUY] ERROR: Invalid ATR value");
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
         loG.Warning("BUY trade blocked - Risk Consistency Rule would be breached");
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
      // loG.Info("  🟢 BUY order opened: Ticket: " + IntegerToString(g_Trade.ResultOrder()) + 
      //       " Entry: " + DoubleToString(price, _Digits) + " SL: " + DoubleToString(sl, _Digits) + " TP: " + DoubleToString(tp, _Digits));
      // loG.Info("[BUY] Checking middle band: " + DoubleToString(GetBollingerBand(0), _Digits));
      // loG.Info("[BUY] Checking upper band: " + DoubleToString(GetBollingerBand(1), _Digits));
      // loG.Info("[BUY] Checking lower band: " + DoubleToString(GetBollingerBand(2), _Digits));
      return true;
   }
   else
   {
      loG.Error("[BUY] ERROR: Failed to open BUY - " + g_Trade.ResultRetcodeDescription());
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
      loG.Warning("[SELL] Max trades (" + IntegerToString(InpMaxTrade) + ") reached for SUPPLY zones");
      return false;
   }
   
   double atr = GetATR();
   if(atr <= 0)
   {
      loG.Error("[SELL] ERROR: Invalid ATR value");
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
         loG.Warning("SELL trade blocked - Risk Consistency Rule would be breached");
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
      // loG.Info("  🔴 SELL order opened: Ticket: " + IntegerToString(g_Trade.ResultOrder()) +
      //       " Entry: " + DoubleToString(price, _Digits) + " SL: " + DoubleToString(sl, _Digits) + " TP: " + DoubleToString(tp, _Digits));
      // loG.Info("[SELL] Checking middle band: " + DoubleToString(GetBollingerBand(0), _Digits));
      // loG.Info("[SELL] Checking upper band: " + DoubleToString(GetBollingerBand(1), _Digits));
      // loG.Info("[SELL] Checking lower band: " + DoubleToString(GetBollingerBand(2), _Digits));
      return true;
   }
   else
   {
      loG.Error("[SELL] ERROR: Failed to open SELL - " + g_Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Open Buy Stop order                                              |
//+------------------------------------------------------------------+
bool PlaceBuyStop(CSupplyDemandZone *zone)
{
   if(zone == NULL || !InpEnableTrading || g_TradingDisabled)
      return false;

   double price = zone.GetTop();

   // Get distance to set SL
   double sl = zone.GetBottom();

   // Get distance to set TP
   double distance = zone.GetZoneSize() * 2.0;
   double tp = price + distance;

   // Check RCR before opening
   if(InpEnableEvaluation)
   {
      double potentialRisk = MathAbs(price - sl) * InpLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!CheckRiskConsistencyRule(_Symbol, POSITION_TYPE_BUY, potentialRisk))
      {
         loG.Warning("BUY STOP trade blocked - Risk Consistency Rule would be breached");
         return false;
      }
   }

   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathFloor(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathCeil(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_BUYSTOP_%.5f", InpTradeComment, price);
   
   if(g_Trade.BuyStop(InpLotSize, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
   {
      loG.Info("[BUY STOP] Buy Stop order placed at " + DoubleToString(price, _Digits) +
            " SL: " + DoubleToString(sl, _Digits) + " TP: " + DoubleToString(tp, _Digits));
      return true;
   }
   else
   {
      loG.Error("[BUY STOP] ERROR: Failed to place Buy Stop - " + g_Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Open Sell Stop order                                             |
//+------------------------------------------------------------------+
bool PlaceSellStop(CSupplyDemandZone *zone)
{
   if(zone == NULL || !InpEnableTrading || g_TradingDisabled)
      return false;

   double price = zone.GetBottom();
   double sl = zone.GetTop();

   // Get distance to set TP
   double distance = zone.GetZoneSize() * 2.0;
   double tp = price - distance;

   // Check RCR before opening
   if(InpEnableEvaluation)
   {
      double potentialRisk = MathAbs(price - sl) * InpLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!CheckRiskConsistencyRule(_Symbol, POSITION_TYPE_SELL, potentialRisk))
      {
         loG.Warning("SELL STOP trade blocked - Risk Consistency Rule would be breached");
         return false;
      }
   }

   // Normalize prices
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   sl = NormalizeDouble(MathCeil(sl / tickSize) * tickSize, _Digits);
   tp = NormalizeDouble(MathFloor(tp / tickSize) * tickSize, _Digits);
   
   string comment = StringFormat("%s_SELLSTOP_%.5f", InpTradeComment, price);
   
   if(g_Trade.SellStop(InpLotSize, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
   {
      loG.Info("[SELL STOP] Sell Stop order placed at " + DoubleToString(price, _Digits) +
            " SL: " + DoubleToString(sl, _Digits) + " TP: " + DoubleToString(tp, _Digits));
      return true;
   }
   else
   {
      loG.Error("[SELL STOP] ERROR: Failed to place Sell Stop - " + g_Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Check Daily Reset at 23:55 server time                          |
//+------------------------------------------------------------------+
void CheckDailyReset()
{   
   MqlDateTime tm = {};
   datetime time = TimeTradeServer(tm);
   int hours = tm.hour;
   int minutes = tm.min;
   int seconds = tm.sec;
   int dayOfWeek = tm.day_of_week;  // 0=Sunday, 1=Monday, ..., 6=Saturday

   // Check if it's 23:55 and we haven't reset today
   bool is_reset_time = (hours == 23 && minutes == 55 && seconds == 0);

   if(is_reset_time)
      g_DailyTimerSet = true;
   
   if(g_DailyTimerSet)
   {
      // Skip weekends (Saturday=6, Sunday=0) - don't record profit on non-trading days
      if(dayOfWeek == 0 || dayOfWeek == 6)
      {
         g_DailyTimerSet = false;
         loG.Info("Weekend detected - skipping daily profit recording");
         return;
      }
      
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double dailyLoss = InpInitialBalance * InpDailyLossLimitPct * 0.9 / 100.0;  // Use 90% of DLL as soft limit
      double DLBLoss = InpInitialBalance * InpDailyLossBreachedPct / 100.0;
      
      // Calculate today's profit before reset (Total Closed P/L + Open Loss)
      // Daily profit = current balance - opening balance (closed P/L only, ignore floating)
      double todayProfit = balance - g_TodayOpeningBalance;
      
      // Add to daily profits array (only on weekdays)
      int arraySize = ArraySize(g_DailyProfits);
      ArrayResize(g_DailyProfits, arraySize + 1);
      ArrayResize(g_DailyDates, arraySize + 1);
      g_DailyProfits[arraySize] = todayProfit;
      g_DailyDates[arraySize] = TimeCurrent();
      
      Logging("Daily Profit Recorded: $" + DoubleToString(todayProfit, 2) + " (Day " + IntegerToString(arraySize + 1) + " - " + CFileHelper::GetDateString(TimeCurrent()) + ")");
      
      // Calculate updated Profit Consistency with new daily profit
      double totalProfit = 0.0;
      double bestDayProfit = 0.0;
      int profitDays = ArraySize(g_DailyProfits);
      
      for(int i = 0; i < profitDays; i++)
      {
         totalProfit += g_DailyProfits[i];
         if(g_DailyProfits[i] > bestDayProfit)
            bestDayProfit = g_DailyProfits[i];
      }
      
      g_ProfitConsistencyPct = 0.0;
      if(totalProfit > 0)
         g_ProfitConsistencyPct = MathMin((bestDayProfit / totalProfit) * 100.0, 100.0);
      
      // Save current equity and balance as new daily starting values
      g_DailyStartingEquity = equity;
      g_DailyStartingBalance = balance;
      g_TodayOpeningBalance = balance;  // Reset for new day
      SaveDailyData();
      
      // Reset threshold based on Equity vs Balance
      if(equity > balance)
      {
         g_DailyLossThreshold = equity - dailyLoss;
         g_DLBThreshold = equity - DLBLoss;
      }
      else
      {
         g_DailyLossThreshold = balance - dailyLoss;
         g_DLBThreshold = balance - DLBLoss;
      }
      
      // Re-enable trading if it was disabled due to DLL
      g_TradingDisabled = false;
      
      // Reset DLB warning flag for new day
      g_DLB_WarningShown = false;
      
      // Reset last equity check for new day
      g_LastEquityCheck = equity;
      
      g_LastResetTime = TimeCurrent();
      g_DailyTimerSet = false;
      
      Logging("Daily Reset at 23:55 - Saved new daily snapshot: Equity $" + DoubleToString(equity, _Digits) + " | Balance $" + DoubleToString(balance, _Digits));
      Logging("New DLL Threshold: $" + DoubleToString(g_DailyLossThreshold, _Digits));
      Logging("New DLB Threshold: $" + DoubleToString(g_DLBThreshold, _Digits));
      Logging("Profit Consistency: " + DoubleToString(g_ProfitConsistencyPct, 2) + "%");
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
         loG.Separator();
         loG.Critical("*** MAXIMUM LOSS LIMIT BREACHED *** Equity: $" + DoubleToString(equity, _Digits) + 
               " <= MLL Threshold: $" + DoubleToString(g_MaxLossThreshold, _Digits));
         loG.Critical("TRADING PERMANENTLY DISABLED - Manual intervention required");
         loG.Separator();
         Alert("MLL BREACHED! Trading DISABLED. Equity: $", equity);
         ExpertRemove();
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
         loG.Separator();
         loG.Critical("*** DAILY LOSS LIMIT BREACHED *** Equity: $" + DoubleToString(equity, _Digits) + 
               " <= DLL Threshold: $" + DoubleToString(g_DailyLossThreshold, _Digits));
         loG.Critical("TRADING DISABLED until daily reset at 23:55");
         loG.Separator();
         Alert("DLL BREACHED! Trading DISABLED until 23:55. Equity: $", equity);
      }
      return;
   }
   // else
   // {
   //    // Re-enable trading if DLL is no longer breached after reset
   //    if(g_TradingDisabled)
   //    {
   //       g_TradingDisabled = false;
   //       loG.Info("Trading re-enabled after daily reset. Equity: $" + DoubleToString(equity, _Digits));
   //    }
   // }
   
   // Check Risk Consistency Rule at 1.5% soft limit - close violating trade ideas
   CheckRCRSoftLimit();
   
   // Check Risk Consistency Rule HARD LIMIT (2%) - disable trading if exceeded
   CheckRCRHardLimit();
   
   // Check Profit Sharing Rule - Qualify for payout
   CheckProfitSharingRule();
   
   // Check Daily Loss Breached (DLB) for payout calculation
   CheckDLBLimit();
   
   // Track Daily Loss Breached (DLB) for payout calculation (accumulates worst loss, resets daily)
   // DLB tracking runs regardless of which evaluation method is active
   double dailyStartBase = MathMax(g_DailyStartingEquity, g_DailyStartingBalance);
   double currentBase = MathMax(equity, balance);
   double dailyLoss = dailyStartBase - currentBase;
   double currentDLBPct = 0.0;
   
   if(dailyLoss > 0 && dailyStartBase > 0)
      currentDLBPct = (dailyLoss / dailyStartBase) * 100.0;
   
   // Track highest DLB percentage reached (for payout tier calculation)
   if(currentDLBPct > g_HighestDLBPct)
   {
      g_HighestDLBPct = currentDLBPct;
      
      // Calculate new payout tier
      double newPayoutTier = 90.0;
      if(g_HighestDLBPct >= 2.0) newPayoutTier = 20.0;
      else if(g_HighestDLBPct >= 1.5) newPayoutTier = 30.0;
      else if(g_HighestDLBPct >= 1.0) newPayoutTier = 50.0;
      
      // Only log when payout tier changes
      if(newPayoutTier != g_LastPayoutTier)
      {
         g_LastPayoutTier = newPayoutTier;
         loG.Info("[DLB] Payout tier changed to " + DoubleToString(newPayoutTier, 0) + "% | Highest DLB: " + DoubleToString(g_HighestDLBPct, 2) + "% | Current DLB: " + DoubleToString(currentDLBPct, 2) + "% | Daily Loss: $" + DoubleToString(dailyLoss, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| Check RCR Soft Limit (1.5%) - Close violating trade ideas       |
//+------------------------------------------------------------------+
void CheckRCRSoftLimit()
{
   if(!InpEnableEvaluation)
      return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double rcrSoftLimit = balance * InpRiskConsistencyPct * 0.9 / 100.0;  // 90% of RCR limit
   
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
      loG.Separator();
      loG.Critical("[EVAL] *** RCR SOFT LIMIT BREACHED (BUY) *** Risk: $" + DoubleToString(buyRisk, 2) + 
            " (" + DoubleToString(buyRiskPct, 2) + "%) > 90% of " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit - Closing all BUY positions");
      loG.Separator();
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
               Logging("Closed BUY position #" + IntegerToString(ticket) + " - RCR Soft Limit");
         }
      }
   }
   
   // Check SELL trade idea
   if(sellRisk > rcrSoftLimit)
   {
      double sellRiskPct = (sellRisk / InpInitialBalance) * 100.0;
      loG.Separator();
      loG.Critical("[EVAL] *** RCR SOFT LIMIT BREACHED (SELL) *** Risk: $" + DoubleToString(sellRisk, 2) + 
            " (" + DoubleToString(sellRiskPct, 2) + "%) > 90% of " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit - Closing all SELL positions");
      loG.Separator();
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
               Logging("Closed SELL position #" + IntegerToString(ticket) + " - RCR Soft Limit");
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
      
      loG.Critical("[EVAL] *** RCR HARD LIMIT BREACHED *** Direction: " + direction + " | Risk: $" + DoubleToString(breachedRisk, 2) + 
            " (" + DoubleToString(breachedPct, 2) + "%) >= " + DoubleToString(InpRiskConsistencyPct, 1) + "% limit");
      loG.Critical("[EVAL] TRADING DISABLED - Evaluation rules violated");
      Alert("CRITICAL: RCR HARD LIMIT BREACHED! Trading DISABLED. Risk: ", DoubleToString(breachedPct, 2), "%");
   }
}

//+------------------------------------------------------------------+
//| Check DLB limit and log warnings                                 |
//+------------------------------------------------------------------+
void CheckDLBLimit()
{
   if(!InpEnableEvaluation || InpEnableProfitConsistencyRule)
      return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   double antiDLBThreshold = MathMax(g_DailyStartingEquity, g_DailyStartingBalance) - (MathMax(g_DailyStartingEquity, g_DailyStartingBalance) * InpDailyLossBreachedPct * 0.9 / 100.0); // 90% of DLB limit

   // Check if DLB breached 90% threshold for warning
   if(equity <= antiDLBThreshold)
   {
      if(!g_DLB_WarningShown && !g_TradingDisabled)
      {
         g_DLB_WarningShown = true;
         g_TradingDisabled = true;
         CloseAllPositions("DLB WARNING THRESHOLD REACHED");
         loG.Warning("[DLB] WARNING: Daily Loss Breached approaching limit! DLB percentage: " +
                     DoubleToString(g_HighestDLBPct, 2) + "%");
         Alert("WARNING: Daily Loss Breached approaching limit! DLB percentage: ", DoubleToString(g_HighestDLBPct, 2) + "%");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Profit Sharing Rule - Qualify for payout                   |
//+------------------------------------------------------------------+
void CheckProfitSharingRule()
{
   if(!InpEnableEvaluation)
      return;
   
   // Check if profit target reached for payout qualification
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentProfit = balance - InpInitialBalance;
   double profitTarget = InpInitialBalance * InpProfitTargetPct / 100.0;
   
   // Must reach profit target first for payout
   if(currentProfit < profitTarget)
      return;
   
   // Get profit consistency data
   double totalProfit = 0.0;
   double bestDayProfit = 0.0;
   datetime bestDayDate = 0;
   int profitDays = ArraySize(g_DailyProfits);
   
   for(int i = 0; i < profitDays; i++)
   {
      totalProfit += g_DailyProfits[i];
      if(g_DailyProfits[i] > bestDayProfit)
      {
         bestDayProfit = g_DailyProfits[i];
         bestDayDate = g_DailyDates[i];
      }
   }
   
   // Use highest DLB percentage ever reached for payout tier calculation
   // (g_HighestDLBPct is tracked continuously and accumulates worst loss)
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double actualDLBPct = g_HighestDLBPct;
   
   // Determine payout percentage based on evaluation method
   double payoutPct = 0.0;
   string qualificationMethod = "";
   bool qualified = false;
   
   if(InpEnableProfitConsistencyRule)
   {
      // Use Profit Consistency Rule with tiered payouts
      if(g_ProfitConsistencyPct < InpProfitConsistencyPct && totalProfit > 0)
      {
         // < 20% = 90% profit sharing
         payoutPct = 90.0;
         qualificationMethod = DoubleToString(InpProfitConsistencyPct, 0) +  "% Profit Consistency Rule";
         qualified = true;
      }
      else if(g_ProfitConsistencyPct >= 20.0 && g_ProfitConsistencyPct < 30.0 && InpProfitConsistencyPct > 20.0 && totalProfit > 0)
      {
         // 20% - 30% = 10% profit sharing
         payoutPct = 10.0;
         qualificationMethod = DoubleToString(InpProfitConsistencyPct, 0) +  "% Profit Consistency Rule";
         qualified = true;
      }
   }
   else
   {
      // Use DLB-based payout calculation
      if(actualDLBPct < 1.0)
      {
         payoutPct = 90.0;  // Can be 75% on 2nd payout, 90% on 3rd payout (manual review)
         qualificationMethod = "DLB Rule (< 1%)";
         qualified = true;
      }
      else if(actualDLBPct >= 1.0 && actualDLBPct < 1.5)
      {
         payoutPct = 50.0;
         qualificationMethod = "DLB Rule (1% - 1.5%)";
         qualified = true;
      }
      else if(actualDLBPct >= 1.5 && actualDLBPct < 2.0)
      {
         payoutPct = 30.0;
         qualificationMethod = "DLB Rule (≥ 1.5%)";
         qualified = true;
      }
      else if(actualDLBPct >= 2.0)
      {
         payoutPct = 20.0;
         qualificationMethod = "DLB Rule (≥ 2%)";
         qualified = true;
      }
   }
   
   // Process payout if qualified
   if(qualified && payoutPct > 0)
   {
      g_TradingDisabled = true;
      CloseAllPositions("PAYOUT QUALIFIED - " + qualificationMethod);
      
      double payoutAmount = currentProfit * (payoutPct / 100.0);
      
      loG.Info("\n");
      loG.Info("         ╔════════════════════════════════════════╗");
      loG.Info("         ║  CONGRATULATIONS - PAYOUT QUALIFIED!   ║");
      loG.Info("         ╚════════════════════════════════════════╝");
      loG.Info("         " + DoubleToString(InpProfitTargetPct, 0) + "% Profit Target Achieved: $" + DoubleToString(currentProfit, 2) + " / $" + DoubleToString(profitTarget, 2));
      loG.Info("         Qualification Method: " + qualificationMethod);
      
      if(InpEnableProfitConsistencyRule)
      {
         loG.Info("         Profit Consistency: " + DoubleToString(g_ProfitConsistencyPct, 2) + "% < " + DoubleToString(InpProfitConsistencyPct, 0) + "% (PASSED)");
      }
      else
      {
         loG.Info("         Daily Loss Breached: " + DoubleToString(actualDLBPct, 2) + "%");
      }
      
      loG.Info("         Best Day Profit: $" + DoubleToString(bestDayProfit, 2) + " on " + (bestDayDate > 0 ? CFileHelper::GetDateString(bestDayDate) : "Unknown"));
      loG.Info("         Total Profit: $" + DoubleToString(currentProfit, 2));
      loG.Info("         Trading Days: " + IntegerToString(profitDays));
      loG.Info("         Take Profit Hits: " + IntegerToString(g_TPHitCount) + " | Stop Loss Hits: " + IntegerToString(g_SLHitCount));
      loG.Info("         Win Trades: " + IntegerToString(g_WinCount) + " | Loss Trades: " + IntegerToString(g_LossCount));
      loG.Info("         Win Rate: " + DoubleToString((g_WinCount + g_LossCount > 0 ? (g_WinCount * 100.0 / (g_WinCount + g_LossCount)) : 0.0), 2) + "%");
      loG.Info("         Payout Percentage: " + DoubleToString(payoutPct, 0) + "%");
      loG.Info("         Amount Eligible for Withdrawal: $" + DoubleToString(payoutAmount, 2));
      loG.Info("");
      loG.Info("         ┌─────────────────────┬──────────────────┬─────────────────────────┐");
      loG.Info("         │   Payout Tier       │  Profit Share %  │   Withdrawal Amount     │");
      loG.Info("         ├─────────────────────┼──────────────────┼─────────────────────────┤");
      loG.Info(StringFormat("         │   1st Payout        │       50%%        │   $%-20.2f│", currentProfit * 0.50));
      loG.Info(StringFormat("         │   2nd Payout        │       75%%        │   $%-20.2f│", currentProfit * 0.75));
      loG.Info(StringFormat("         │   From 3rd Payout   │       90%%        │   $%-20.2f│", currentProfit * 0.90));
      loG.Info("         └─────────────────────┴──────────────────┴─────────────────────────┘");
      loG.Info("");
      loG.Info("         Ready for payout withdrawal!");
      loG.Info("\n");
      
      Alert("🎉 PAYOUT QUALIFIED! Profit: $", DoubleToString(currentProfit, 2), 
            " | Payout: ", DoubleToString(payoutPct, 0), "% ($", DoubleToString(payoutAmount, 2), ")");
      ExpertRemove();
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
      loG.Critical("*** RCR SOFT LIMIT EXCEEDED *** Total Risk: $" + DoubleToString(totalRisk, _Digits) + 
            " > 90% RCR Limit: $" + DoubleToString(rcrLimit, _Digits) + " (" + DoubleToString(InpRiskConsistencyPct * 0.9, 2) + "%)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check TP/SL Hits from Deal History                              |
//+------------------------------------------------------------------+
void CheckTPSLHits()
{
   if(!InpEnableEvaluation)
      return;
   
   // Check deals since last check
   datetime currentTime = TimeCurrent();
   if(currentTime == g_LastDealCheckTime)
      return;
   
   HistorySelect(g_LastDealCheckTime, currentTime);
   
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // Only count our EA's deals
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      // Only count exit deals
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      // Get position ID and find entry deal to get opening price
      long dealPosID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      
      // Select all deals for this position
      HistorySelectByPosition(dealPosID);
      
      // Find the entry deal (opening price)
      double entryPrice = 0.0;
      for(int j = 0; j < HistoryDealsTotal(); j++)
      {
         ulong entryTicket = HistoryDealGetTicket(j);
         if(entryTicket == 0) continue;
         
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(entryTicket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_IN)
         {
            entryPrice = HistoryDealGetDouble(entryTicket, DEAL_PRICE);
            break;
         }
      }
      
      // Re-select original time range (HistorySelectByPosition changed the context)
      HistorySelect(g_LastDealCheckTime, currentTime);
      
      if(entryPrice == 0.0) continue; // Skip if entry price not found
      
      double dealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      double dealSL = HistoryDealGetDouble(dealTicket, DEAL_SL);
      double dealTP = HistoryDealGetDouble(dealTicket, DEAL_TP);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      
      // Calculate distance in pips
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      double pipFactor = (digits == 3 || digits == 5) ? 10.0 : 1.0; // 5-digit/3-digit brokers
      double dealDistancePips = MathAbs(entryPrice - dealPrice) / (point * pipFactor);

      // Check if TP hit
      if(dealTP > 0 && MathAbs(dealPrice - dealTP) < point)
      {
         g_TPHitCount++;
         loG.Log("[TP Hit] #" + IntegerToString(dealTicket) + 
               " | Profit: $" + DoubleToString(dealProfit, 2) + 
               " | Distance: " + DoubleToString(dealDistancePips, 1) + " pips");
      }
      // Check if SL hit
      else if(dealSL > 0 && MathAbs(dealPrice - dealSL) < point)
      {
         g_SLHitCount++;
         loG.Log("[SL Hit] #" + IntegerToString(dealTicket) + 
               " | Profit: $" + DoubleToString(dealProfit, 2) + 
               " | Distance: " + DoubleToString(dealDistancePips, 1) + " pips");
      }

      // Update win/loss
      if(dealProfit > 0)
         g_WinCount++;
      else if(dealProfit < 0)
         g_LossCount++;
   }
   
   g_LastDealCheckTime = currentTime;
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
         loG.Log("Closed position #" + IntegerToString(ticket) + " - Reason: " + reason);
      }
   }
   
   if(closed > 0)
      loG.Log("Total positions closed: " + IntegerToString(closed) + " - Reason: " + reason);
}

//+------------------------------------------------------------------+
//| Save Daily Data to File                                          |
//+------------------------------------------------------------------+
bool SaveDailyData()
{
   if(!InpEnableEvaluation)
      return false;
   
   string workFolder = loG.GetWorkFolder();
      
   // Ensure work folder exists
   if(!FileIsExist(workFolder))
   {
      if(!CFileHelper::CreateFolder(workFolder, false))
      {
         loG.Warning("[EVAL] Failed to create work folder: " + workFolder);
         return false;
      }
   }
   
   int handle = FileOpen(workFolder + g_FileName, FILE_WRITE | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      loG.Error("Failed to open file for writing: " + workFolder + g_FileName + " Error: " + IntegerToString(GetLastError()));
      return false;
   }
   
   // Write data version (updated to v4 for TP/SL tracking)
   int version = 4;
   FileWriteInteger(handle, version, INT_VALUE);
   
   // Write daily snapshot data
   FileWriteDouble(handle, g_DailyStartingEquity);
   FileWriteDouble(handle, g_DailyStartingBalance);
   FileWriteLong(handle, g_LastResetTime);
   
   // Write profit consistency data
   int dailyProfitCount = ArraySize(g_DailyProfits);
   FileWriteInteger(handle, dailyProfitCount, INT_VALUE);
   for(int i = 0; i < dailyProfitCount; i++)
   {
      FileWriteDouble(handle, g_DailyProfits[i]);
      FileWriteLong(handle, g_DailyDates[i]);
   }
   
   FileWriteDouble(handle, g_TodayOpeningBalance);
   
   // Write TP/SL tracking data (version 4+)
   FileWriteInteger(handle, g_TPHitCount, INT_VALUE);
   FileWriteInteger(handle, g_SLHitCount, INT_VALUE);
   FileWriteLong(handle, g_LastDealCheckTime);
   
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
      
   string workFolder = loG.GetWorkFolder();
   
   if(!FileIsExist(workFolder + g_FileName))
   {
      loG.Warning("Daily data file not found: " + workFolder + g_FileName);
      return false;
   }
   
   int handle = FileOpen(workFolder + g_FileName, FILE_READ | FILE_BIN);
   if(handle == INVALID_HANDLE)
      loG.Error("Failed to open file for reading: " + workFolder + g_FileName + " Error: " + IntegerToString(GetLastError()));
   // Read data version
   int version = FileReadInteger(handle, INT_VALUE);
   if(version < 1 || version > 4)
   {
      loG.Warning("Unsupported data file version: " + IntegerToString(version));
      FileClose(handle);
      return false;
   }
   
   // Read daily snapshot data (all versions)
   g_DailyStartingEquity = FileReadDouble(handle);
   g_DailyStartingBalance = FileReadDouble(handle);
   g_LastResetTime = (datetime)FileReadLong(handle);
   
   // Read profit consistency data (version 2 and 3)
   if(version >= 2)
   {
      int dailyProfitCount = FileReadInteger(handle, INT_VALUE);
      ArrayResize(g_DailyProfits, dailyProfitCount);
      ArrayResize(g_DailyDates, dailyProfitCount);
      
      for(int i = 0; i < dailyProfitCount; i++)
      {
         g_DailyProfits[i] = FileReadDouble(handle);
         
         // Version 3+ includes dates
         if(version >= 3)
            g_DailyDates[i] = (datetime)FileReadLong(handle);
         else
            g_DailyDates[i] = 0; // Unknown date for older data
      }
      
      g_TodayOpeningBalance = FileReadDouble(handle);
      
      // Read TP/SL tracking data (version 4+)
      if(version >= 4)
      {
         g_TPHitCount = FileReadInteger(handle, INT_VALUE);
         g_SLHitCount = FileReadInteger(handle, INT_VALUE);
         g_LastDealCheckTime = (datetime)FileReadLong(handle);
      }
      else
      {
         // Initialize TP/SL counters for older versions
         g_TPHitCount = 0;
         g_SLHitCount = 0;
         g_LastDealCheckTime = TimeCurrent() - 86400; // Start from yesterday
      }
   }
   else
   {
      // Version 1 - initialize empty profit array
      ArrayResize(g_DailyProfits, 0);
      ArrayResize(g_DailyDates, 0);
      g_TodayOpeningBalance = g_DailyStartingBalance;
      g_TPHitCount = 0;
      g_SLHitCount = 0;
      g_LastDealCheckTime = TimeCurrent() - 86400;
   }
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Delete Testing Logs (only if InpDeleteFolder>=true)              |
//+------------------------------------------------------------------+
void DeleteTestingLogs()
{
   if(!InpDeleteFolder)
      return;
   
   // Check if logger exists
   if(loG == NULL)
      return;
   
   string workFolder = loG.GetWorkFolder();
   string expertFolder = "SnD_Logs";
   int flag = 0; // Not using common folder
   int deletedFiles = 0;
   int deletedFolders = 0;
   
   // Delete all log files in workFolder
   string file_name;
   long search_handle = FileFindFirst(workFolder + "\\*.*", file_name, flag);
   
   if(search_handle != INVALID_HANDLE)
   {
      do
      {
         if(file_name != "." && file_name != "..")
         {
            if(FileDelete(workFolder + "\\" + file_name, flag))
               deletedFiles++;
         }
      }
      while(FileFindNext(search_handle, file_name));
      
      FileFindClose(search_handle);
   }
   
   // Delete workFolder (account-specific folder)
   if(deletedFiles > 0)
   {
      if(FolderDelete(workFolder, flag))
      {
         loG.Debug("[DEBUG] Deleted work folder: " + workFolder + " (" + IntegerToString(deletedFiles) + " files removed)");
         deletedFolders++;
      }
   }
   
   // Delete all other account folders in expertFolder
   string folder_name;
   search_handle = FileFindFirst(expertFolder + "\\*", folder_name, flag);
   
   if(search_handle != INVALID_HANDLE)
   {
      do
      {
         if(folder_name != "." && folder_name != "..")
         {
            string account_folder = expertFolder + "\\" + folder_name;
            
            // Delete all files in this account folder
            string sub_file;
            long sub_search = FileFindFirst(account_folder + "\\*.*", sub_file, flag);
            
            if(sub_search != INVALID_HANDLE)
            {
               do
               {
                  if(sub_file != "." && sub_file != "..")
                     FileDelete(account_folder + "\\" + sub_file, flag);
               }
               while(FileFindNext(sub_search, sub_file));
               
               FileFindClose(sub_search);
            }
            
            // Delete the account folder
            if(FolderDelete(account_folder, flag))
               deletedFolders++;
         }
      }
      while(FileFindNext(search_handle, folder_name));
      
      FileFindClose(search_handle);
   }
   
   // Delete main expertFolder
   if(deletedFolders > 0)
   {
      if(FolderDelete(expertFolder, 0))
         loG.Debug("Deleted main folder: " + expertFolder + " (" + IntegerToString(deletedFolders) + " subfolders removed)");
   }
   
   loG.Debug("Testing logs cleanup completed - Files: " + IntegerToString(deletedFiles) + " | Folders: " + IntegerToString(deletedFolders));
}

//+------------------------------------------------------------------+
//| Create Evaluation Display on Chart                               |
//+------------------------------------------------------------------+
void CreateEvaluationDisplay()
{
   int i,sy=7;
   int xOffset[12]=
   {
      10, 10,
      180, 180,
      350, 350,
      620, 620,
      850, 850,
      1080, 1080
   };
   int yOffset[12]=
   {
      2, 1,
      2, 1,
      2, 1,
      2, 1,
      2, 1,
      2, 1
   };
   int dy=16;
   
   // Create 6 column with 2 label lines (added total days traded)
   for(i = 0; i < 12; i++)
   {
      string labelName = g_DisplayLabel + "_" + IntegerToString(i);

      g_label[i].Create(0, labelName, 0, xOffset[i], yOffset[i] * dy + sy);
      g_label[i].Description("");
      g_label[i].Color(C'210,210,210');
      g_label[i].FontSize(9);
      g_label[i].Font("Microsoft Sans Serif");
      g_label[i].Corner(CORNER_LEFT_LOWER);

      if((g_TradingDisabled || g_DLB_WarningShown || !InpEnableTrading) && i == 1)
         g_label[i].Color(clrRed);
      else if((!g_TradingDisabled || !g_DLB_WarningShown || InpEnableTrading) && i == 1)
         g_label[i].Color(clrLime);
   }

   UpdateEvaluationDisplay();
   ChartRedraw();
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
   
   // Use highest DLB percentage ever reached (for payout tier calculation)
   // (g_HighestDLBPct is tracked continuously and accumulates worst loss)
   double actualDLBPct = g_HighestDLBPct;
   
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
   
   string statusText = (g_TradingDisabled || !InpEnableTrading) ? "  DISABLED" : "   ACTIVE";
   if(!InpEnableProfitConsistencyRule)
      statusText = g_DLB_WarningShown ? "DLB WARNING" : statusText;
   
   // Calculate Profit Consistency (best day / total profit)
   double totalProfit = 0.0;
   double bestDayProfit = 0.0;
   datetime bestDayDate = 0;
   int profitDays = ArraySize(g_DailyProfits);
   
   for(int i = 0; i < profitDays; i++)
   {
      totalProfit += g_DailyProfits[i];
      if(g_DailyProfits[i] > bestDayProfit)
      {
         bestDayProfit = g_DailyProfits[i];
         bestDayDate = g_DailyDates[i];
      }
   }
   
   // Calculate profit consistency percentage and update global variable
   g_ProfitConsistencyPct = 0.0;
   if(totalProfit > 0)
      g_ProfitConsistencyPct = MathMin((bestDayProfit / totalProfit) * 100.0, 100.0);  // Cap at 100%
   
   double profitConsistencyPct = g_ProfitConsistencyPct;
   
   double profitTarget = InpInitialBalance * InpProfitTargetPct / 100.0;
   double currentProfit = balance - InpInitialBalance;
   
   // Line by line text 
   g_label[0].Description("EVALUATION STATUS");
   g_label[1].Description("          " + statusText);
   g_label[2].Description(StringFormat("Equity: $%.2f", equity));
   g_label[3].Description(StringFormat("Balance: $%.2f", balance));
   g_label[4].Description(StringFormat("DLL: $%.2f / $%.2f (%.1f%%)", dailyRemaining, dailyLossAllowed, (dailyRemaining / dailyLossAllowed * 100.0)));
   g_label[5].Description(StringFormat("MLL: $%.2f / $%.2f (%.1f%%)", maxRemaining, maxLossAllowed, (maxRemaining / maxLossAllowed * 100.0)));
   // Calculate payout percentage for display
   string label6Text = "";
   if(InpEnableProfitConsistencyRule)
   {
      label6Text = StringFormat("DLB: %.2f%% (Not Used)", actualDLBPct);
   }
   else
   {
      // Determine payout % based on DLB
      double payoutPct = 0.0;
      if(actualDLBPct < 1.0) payoutPct = 90.0;
      else if(actualDLBPct >= 1.0 && actualDLBPct < 1.5) payoutPct = 50.0;
      else if(actualDLBPct >= 1.5 && actualDLBPct < 2.0) payoutPct = 30.0;
      else if(actualDLBPct >= 2.0) payoutPct = 20.0;
      label6Text = StringFormat("DLB: %.2f%% | Payout: %.0f%%", actualDLBPct, payoutPct);
   }
   
   g_label[6].Description(label6Text);
   g_label[7].Description(StringFormat("RCR: %.2f%% | Limit: %.1f%%", maxRCRPct, InpRiskConsistencyPct));
   g_label[8].Description(StringFormat("Profit Target: $%.2f / $%.2f", currentProfit, profitTarget));
   g_label[9].Description(StringFormat("Best Day: $%.2f (%s)", bestDayProfit, bestDayDate > 0 ? CFileHelper::GetDateString(bestDayDate) : "N/A"));
   g_label[10].Description(StringFormat("Profit Consistency: %.1f%% %s %.0f%%", profitConsistencyPct, InpEnableProfitConsistencyRule ? "<" : "(Not Used)", InpProfitConsistencyPct));
   g_label[11].Description(StringFormat("Total Days: %d | Profit: $%.2f", profitDays, totalProfit));
}

//+------------------------------------------------------------------+
//| Create custom chart template for evaluation display              |
//+------------------------------------------------------------------+
bool CreateCustomChart()
{
   ResetLastError();

   if(!g_Chart.ScaleFix(true))
      return false;
   else if(!g_Chart.Shift(true))
      return false;
   else if(!g_Chart.ShiftSize(50))
      return false;
   else if(!g_Chart.ShowLineAsk(true))
      return false;
   else if(!g_Chart.ShowPeriodSep(true))
      return false;
   else if(!g_Chart.ColorBackground(C'25,25,25'))
      return false;
   else if(!g_Chart.ColorForeground(C'105,105,105'))
      return false;
   else if(!g_Chart.ColorGrid(C'50,50,50'))
      return false;
   else if(!g_Chart.ColorBarUp(clrDeepSkyBlue))
      return false;
   else if(!g_Chart.ColorBarDown(C'210,210,210'))
      return false;
   else if(!g_Chart.ColorCandleBull(clrTurquoise))
      return false;
   else if(!g_Chart.ColorCandleBear(clrMediumOrchid))
      return false;
   else if(!g_Chart.ColorLineBid(clrLightSlateGray))
      return false;
   else if(!g_Chart.ColorLineAsk(clrBrown))
      return false;
   else if(!g_Chart.ColorLineLast(C'0,192,0'))
      return false;
   else if(!g_Chart.ColorStopLevels(clrBrown))
      return false;

   return true;
}