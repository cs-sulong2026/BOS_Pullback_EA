//+------------------------------------------------------------------+
//|                                                 SupplyDemand.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 07.01.2026 - Volume-based Supply & Demand Zone Detection        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

//--- Forward declarations for trade functions (implemented in .mq5)
class CSupplyDemandZone;  // Forward declare class
bool OpenBuyTrade(CSupplyDemandZone *zone);   // Demand zone entry
bool OpenSellTrade(CSupplyDemandZone *zone);  // Supply zone entry

//--- Enumerations
enum ENUM_SD_ZONE_TYPE
{
   SD_ZONE_SUPPLY,      // Supply zone (selling pressure)
   SD_ZONE_DEMAND       // Demand zone (buying pressure)
};

enum ENUM_SD_ZONE_STATE
{
   SD_STATE_UNTESTED,   // Zone not yet tested
   SD_STATE_TESTED,     // Zone has been tested
   SD_STATE_BROKEN,     // Zone has been broken
   SD_STATE_ACTIVE      // Zone is currently being tested
};

//--- Structures
struct SSupplyDemandZone
{
   ENUM_SD_ZONE_TYPE  type;              // Zone type
   ENUM_SD_ZONE_STATE state;             // Zone state
   double            priceTop;           // Top price of zone
   double            priceBottom;        // Bottom price of zone
   datetime          timeStart;          // Zone formation time
   datetime          timeEnd;            // Zone end time (for extension)
   long              volumeTotal;        // Total volume in zone
   double            volumeAvg;          // Average volume
   int               barsInZone;         // Number of bars forming zone
   int               touchCount;         // Times price returned to zone
   bool              isValid;            // Is zone valid
   double            distanceToPrice;    // Distance to current price
   bool              hasArrow;           // Has entry arrow been drawn
   bool              priceHasLeft;       // Has price left the zone since formation
   
   // Chart objects
   string            rectangleName;      // Rectangle object name
   string            arrowName;          // Arrow signal name
   string            labelName;          // Volume label name
};

//+------------------------------------------------------------------+
//| CSupplyDemandZone - Individual Zone Class                        |
//+------------------------------------------------------------------+
class CSupplyDemandZone
{
private:
   SSupplyDemandZone m_zone;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   long              m_chartID;
   
   // Visual settings
   color             m_supplyColor;
   color             m_demandColor;
   color             m_supplyColorFill;
   color             m_demandColorFill;
   bool              m_showArrows;
   bool              m_showLabels;

public:
                     CSupplyDemandZone();
                    ~CSupplyDemandZone();
   
   // Initialization
   bool              Create(ENUM_SD_ZONE_TYPE type, double top, double bottom, datetime timeStart,
                           long volumeTotal, double volumeAvg, int barsInZone);
   
   // Getters
   ENUM_SD_ZONE_TYPE GetType() const { return m_zone.type; }
   ENUM_SD_ZONE_STATE GetState() const { return m_zone.state; }
   double            GetTop() const { return m_zone.priceTop; }
   double            GetBottom() const { return m_zone.priceBottom; }
   datetime          GetTimeStart() const { return m_zone.timeStart; }
   datetime          GetTimeEnd() const { return m_zone.timeEnd; }
   long              GetVolume() const { return m_zone.volumeTotal; }
   double            GetVolumeAvg() const { return m_zone.volumeAvg; }
   bool              IsValid() const { return m_zone.isValid; }
   double            GetDistanceToPrice() const { return m_zone.distanceToPrice; }
   int               GetTouchCount() const { return m_zone.touchCount; }
   SSupplyDemandZone GetZoneData() const { return m_zone; }
   
   // Setters
   void              SetState(ENUM_SD_ZONE_STATE state) { m_zone.state = state; }
   void              SetValid(bool valid) { m_zone.isValid = valid; }
   void              IncrementTouch() { m_zone.touchCount++; }
   void              SetPriceHasLeft(bool hasLeft) { m_zone.priceHasLeft = hasLeft; }
   void              SetHasArrow(bool hasArrow) { m_zone.hasArrow = hasArrow; }
   void              SetVisualSettings(color supplyCol, color demandCol, color supplyFill, 
                                      color demandFill, int transparency, bool arrows, bool labels);
   
   // Analysis
   void              UpdateDistanceToPrice(double currentPrice);
   bool              IsPriceInZone(double price);
   bool              IsPriceTouching(double price, double tolerance);
   bool              HasPriceBroken(double price);
   double            GetZoneMiddlePrice() const { return (m_zone.priceTop + m_zone.priceBottom) / 2.0; }
   double            GetZoneSize() const { return m_zone.priceTop - m_zone.priceBottom; }
   
   // Drawing
   bool              Draw();
   bool              ExtendZone(datetime newEndTime);
   void              Update();
   void              Hide();
   void              Show();
   void              Delete();
   void              DrawArrow(datetime touchTime, double touchPrice);  // Public for entry signal drawing
   
private:
   string            GenerateObjectName(string prefix);
   color             GetZoneColor(bool filled);
   void              DrawRectangle();
   void              DrawLabel();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSupplyDemandZone::CSupplyDemandZone()
{
   ZeroMemory(m_zone);
   m_symbol = _Symbol;
   m_timeframe = _Period;
   m_chartID = 0;
   
   m_supplyColor = clrCrimson;
   m_demandColor = clrDodgerBlue;
   m_supplyColorFill = clrMistyRose;
   m_demandColorFill = clrLightSteelBlue;
   m_showArrows = true;
   m_showLabels = true;
   
   m_zone.isValid = false;
   m_zone.state = SD_STATE_UNTESTED;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSupplyDemandZone::~CSupplyDemandZone()
{
   Delete();
}

//+------------------------------------------------------------------+
//| Create zone                                                       |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::Create(ENUM_SD_ZONE_TYPE type, double top, double bottom, datetime timeStart,
                                long volumeTotal, double volumeAvg, int barsInZone)
{
   m_zone.type = type;
   m_zone.priceTop = top;
   m_zone.priceBottom = bottom;
   m_zone.timeStart = timeStart;
   m_zone.timeEnd = TimeCurrent();
   m_zone.volumeTotal = volumeTotal;
   m_zone.volumeAvg = volumeAvg;
   m_zone.barsInZone = barsInZone;
   m_zone.touchCount = 0;
   m_zone.isValid = true;
   m_zone.state = SD_STATE_UNTESTED;
   m_zone.distanceToPrice = 0;
   m_zone.hasArrow = false;  // Arrow not drawn yet
   m_zone.priceHasLeft = false;  // Price hasn't left the zone yet
   
   // Generate object names
   m_zone.rectangleName = GenerateObjectName("SD_Zone_");
   m_zone.arrowName = GenerateObjectName("SD_Arrow_");
   m_zone.labelName = GenerateObjectName("SD_Label_");
   
   return true;
}

//+------------------------------------------------------------------+
//| Generate unique object name                                      |
//+------------------------------------------------------------------+
string CSupplyDemandZone::GenerateObjectName(string prefix)
{
   string typeStr = (m_zone.type == SD_ZONE_SUPPLY) ? "Supply_" : "Demand_";
   return prefix + typeStr + TimeToString(m_zone.timeStart, TIME_DATE | TIME_MINUTES) + "_" +
          DoubleToString(m_zone.priceTop, _Digits) + "_" + IntegerToString(GetTickCount());
}

//+------------------------------------------------------------------+
//| Set visual settings                                              |
//+------------------------------------------------------------------+
void CSupplyDemandZone::SetVisualSettings(color supplyCol, color demandCol, color supplyFill,
                                          color demandFill, int transparency, bool arrows, bool labels)
{
   m_supplyColor = supplyCol;
   m_demandColor = demandCol;
   m_supplyColorFill = supplyFill;
   m_demandColorFill = demandFill;
   m_showArrows = arrows;
   m_showLabels = labels;
   // Note: transparency parameter ignored - transparency is now state-based
}

//+------------------------------------------------------------------+
//| Get zone color                                                    |
//+------------------------------------------------------------------+
color CSupplyDemandZone::GetZoneColor(bool filled)
{
   if(filled)
      return (m_zone.type == SD_ZONE_SUPPLY) ? m_supplyColorFill : m_demandColorFill;
   else
      return (m_zone.type == SD_ZONE_SUPPLY) ? m_supplyColor : m_demandColor;
}

//+------------------------------------------------------------------+
//| Update distance to current price                                 |
//+------------------------------------------------------------------+
void CSupplyDemandZone::UpdateDistanceToPrice(double currentPrice)
{
   if(currentPrice >= m_zone.priceBottom && currentPrice <= m_zone.priceTop)
   {
      m_zone.distanceToPrice = 0; // Price is inside zone
   }
   else if(currentPrice > m_zone.priceTop)
   {
      m_zone.distanceToPrice = currentPrice - m_zone.priceTop;
   }
   else
   {
      m_zone.distanceToPrice = m_zone.priceBottom - currentPrice;
   }
}

//+------------------------------------------------------------------+
//| Check if price is in zone                                        |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::IsPriceInZone(double price)
{
   return (price >= m_zone.priceBottom && price <= m_zone.priceTop);
}

//+------------------------------------------------------------------+
//| Check if price is touching zone                                  |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::IsPriceTouching(double price, double tolerance)
{
   double touchRange = GetZoneSize() * 0.05; // 5% of zone size
   if(tolerance > 0)
      touchRange = tolerance;
   
   return (price >= m_zone.priceBottom - touchRange && price <= m_zone.priceTop + touchRange);
}

//+------------------------------------------------------------------+
//| Check if price has broken zone                                   |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::HasPriceBroken(double price)
{
   if(m_zone.type == SD_ZONE_SUPPLY)
      return (price > m_zone.priceTop);
   else
      return (price < m_zone.priceBottom);
}

//+------------------------------------------------------------------+
//| Draw rectangle zone                                              |
//+------------------------------------------------------------------+
void CSupplyDemandZone::DrawRectangle()
{
   // Create rectangle
   if(!ObjectCreate(m_chartID, m_zone.rectangleName, OBJ_RECTANGLE, 0, 
                    m_zone.timeStart, m_zone.priceTop, m_zone.timeEnd, m_zone.priceBottom))
   {
      Print("Failed to create rectangle: ", m_zone.rectangleName, " Error: ", GetLastError());
      return;
   }
   
   // Set rectangle properties
   color borderColor = GetZoneColor(false);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_FILL, true);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_BACK, true);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_SELECTED, false);
   
   // Set description
   string desc = StringFormat("%s Zone | Vol: %I64d | Touches: %d | State: %s",
                             (m_zone.type == SD_ZONE_SUPPLY) ? "SUPPLY" : "DEMAND",
                             m_zone.volumeTotal,
                             m_zone.touchCount,
                             EnumToString(m_zone.state));
   ObjectSetString(m_chartID, m_zone.rectangleName, OBJPROP_TOOLTIP, desc);
}

//+------------------------------------------------------------------+
//| Draw arrow signal (OBJ_ARROW code 108) at specific price/time   |
//+------------------------------------------------------------------+
void CSupplyDemandZone::DrawArrow(datetime touchTime, double touchPrice)
{
   if(!m_showArrows || m_zone.hasArrow)
      return;
   
   // OBJ_ARROW code 108 is a circle marker - draw at touch point
   if(!ObjectCreate(m_chartID, m_zone.arrowName, OBJ_ARROW_CHECK, 0, touchTime, touchPrice))
   {
      // Print("Failed to create arrow: ", m_zone.arrowName, " Error: ", GetLastError());
      return;
   }
   
   color arrowColor = GetZoneColor(false);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_ARROWCODE, 108); // Circle marker
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_BACK, false);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_HIDDEN, true);
   
   string tooltip = StringFormat("%s Entry Signal\nVol: %I64d", 
                                 (m_zone.type == SD_ZONE_SUPPLY) ? "SELL" : "BUY",
                                 m_zone.volumeTotal);
   ObjectSetString(m_chartID, m_zone.arrowName, OBJPROP_TOOLTIP, tooltip);

   if(m_zone.type == SD_ZONE_SUPPLY)
      ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   else
      ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_ANCHOR, ANCHOR_TOP);
   
   m_zone.hasArrow = true;  // Mark arrow as drawn
}

//+------------------------------------------------------------------+
//| Draw volume label in middle of zone                             |
//+------------------------------------------------------------------+
void CSupplyDemandZone::DrawLabel()
{
   if(!m_showLabels)
      return;
   
   double middlePrice = GetZoneMiddlePrice();
   datetime middleTime = m_zone.timeStart + (datetime)((m_zone.timeEnd - m_zone.timeStart) / 2);
   
   if(!ObjectCreate(m_chartID, m_zone.labelName, OBJ_TEXT, 0, middleTime, middlePrice))
   {
      // Print("Failed to create label: ", m_zone.labelName, " Error: ", GetLastError());
      return;
   }
   
   // Format volume display
   string volumeText = "";
   if(m_zone.volumeTotal >= 1000000)
      volumeText = DoubleToString(m_zone.volumeTotal / 1000000.0, 2) + "M";
   else if(m_zone.volumeTotal >= 1000)
      volumeText = DoubleToString(m_zone.volumeTotal / 1000.0, 1) + "K";
   else
      volumeText = IntegerToString(m_zone.volumeTotal);
   
   // Format state display
   string stateText = "";
   switch(m_zone.state)
   {
      case SD_STATE_UNTESTED: stateText = "STRONG"; break;
      case SD_STATE_TESTED:   stateText = "WEAK"; break;
      case SD_STATE_ACTIVE:   stateText = "ACTIVE"; break;
      case SD_STATE_BROKEN:   stateText = "BROKEN"; break;
      default:                stateText = "UNKNOWN"; break;
   }
   
   string labelText = StringFormat("%s \nVol: %s \nAvg: %.0f", stateText, volumeText, m_zone.volumeAvg);
   
   ObjectSetString(m_chartID, m_zone.labelName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(m_chartID, m_zone.labelName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_BACK, false);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Draw zone and all components                                     |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::Draw()
{
   DrawRectangle();
   // Arrow is drawn only when price touches zone (see UpdateAllZones)
   DrawLabel();
   return true;
}

//+------------------------------------------------------------------+
//| Extend zone using ObjectMove                                     |
//+------------------------------------------------------------------+
bool CSupplyDemandZone::ExtendZone(datetime newEndTime)
{
   m_zone.timeEnd = newEndTime;
   
   // Use ObjectMove to extend the rectangle (point 1 is the second time/price anchor)
   if(ObjectFind(m_chartID, m_zone.rectangleName) >= 0)
   {
      if(!ObjectMove(m_chartID, m_zone.rectangleName, 1, newEndTime, m_zone.priceBottom))
      {
         // Print("Failed to extend zone: ", m_zone.rectangleName, " Error: ", GetLastError());
         return false;
      }
   }
   
   // Update label position to middle of extended zone
   if(m_showLabels && ObjectFind(m_chartID, m_zone.labelName) >= 0)
   {
      datetime middleTime = m_zone.timeStart + (datetime)((m_zone.timeEnd - m_zone.timeStart) / 2);
      ObjectMove(m_chartID, m_zone.labelName, 0, middleTime, GetZoneMiddlePrice());
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update zone                                                       |
//+------------------------------------------------------------------+
void CSupplyDemandZone::Update()
{
   // Extend zone to current time
   ExtendZone(TimeCurrent());
   
   // Update rectangle transparency based on zone state
   if(ObjectFind(m_chartID, m_zone.rectangleName) >= 0)
   {
      color borderColor = GetZoneColor(false);
      color fillColor = GetZoneColor(true);
      
      // Set transparency based on zone validity and state
      int transparency;
      
      if(m_zone.state == SD_STATE_UNTESTED)
      {
         // Strongest zones - most opaque (low transparency)
         transparency = 40;  // Very solid/opaque
      }
      else if(m_zone.state == SD_STATE_TESTED)
      {
         // Tested zones - medium opacity
         transparency = 65;
      }
      else if(m_zone.state == SD_STATE_ACTIVE)
      {
         // Currently active - medium opacity with different color
         transparency = 50;
      }
      else if(m_zone.state == SD_STATE_BROKEN)
      {
         // Broken zones - very transparent (almost invisible)
         transparency = 95;
      }
      else
      {
         // Default
         transparency = 70;
      }
      
      ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_BGCOLOR, fillColor);
      
      // Update border width - thicker for untested zones
      int borderWidth = (m_zone.state == SD_STATE_UNTESTED) ? 2 : 1;
      ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_WIDTH, borderWidth);
   }
}

//+------------------------------------------------------------------+
//| Hide zone                                                         |
//+------------------------------------------------------------------+
void CSupplyDemandZone::Hide()
{
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

//+------------------------------------------------------------------+
//| Show zone                                                         |
//+------------------------------------------------------------------+
void CSupplyDemandZone::Show()
{
   ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//+------------------------------------------------------------------+
//| Delete zone and all objects (except arrows - they persist)      |
//+------------------------------------------------------------------+
void CSupplyDemandZone::Delete()
{
   ObjectDelete(m_chartID, m_zone.rectangleName);
   // Keep arrow on chart even when zone is deleted
   // ObjectDelete(m_chartID, m_zone.arrowName);
   ObjectDelete(m_chartID, m_zone.labelName);
}

//+------------------------------------------------------------------+
//| CSupplyDemandManager - Manager Class for EA                      |
//+------------------------------------------------------------------+
class CSupplyDemandManager
{
private:
   CSupplyDemandZone *m_supplyZones[];    // Array of supply zones
   CSupplyDemandZone *m_demandZones[];    // Array of demand zones
   
   // Settings
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookbackBars;
   long              m_volumeThreshold;   // Minimum volume for zone formation
   int               m_minBarsInZone;     // Minimum bars to form a zone
   int               m_maxBarsInZone;     // Maximum bars to form a zone
   double            m_minZoneSize;       // Minimum zone size in points
   double            m_maxZoneSize;       // Maximum zone size in points
   double            m_minPriceLeftDistance; // Minimum points price must move away to be considered "left"
   
   // Display settings
   int               m_showZones;         // -1 = all, 0 = none, N = show N closest zones
   color             m_supplyColor;
   color             m_demandColor;
   color             m_supplyColorFill;
   color             m_demandColorFill;
   bool              m_showArrows;
   bool              m_showLabels;
   
   // Tracking
   datetime          m_lastUpdateTime;
   int               m_lastScannedBar;    // Track last bar index scanned for zones

public:
                     CSupplyDemandManager();
                    ~CSupplyDemandManager();
   
   // Initialization
   bool              Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, 
                               long volumeThreshold, int minBars, int maxBars,
                               double minSize, double maxSize, double minPriceLeftDist);
   
   // Settings
   void              SetShowZones(int showZones) { m_showZones = showZones; }
   void              SetVisualSettings(color supplyCol, color demandCol, color supplyFill,
                                      color demandFill, int transparency, bool arrows, bool labels);
   
   // Zone detection
   bool              DetectZones();
   void              UpdateAllZones();
   void              ManageZoneDisplay();
   bool              DetectNewZones(int lookbackBars = 20);  // Detect zones in recent bars only
   
   // Analysis
   int               GetSupplyZoneCount() const { return ArraySize(m_supplyZones); }
   int               GetDemandZoneCount() const { return ArraySize(m_demandZones); }
   CSupplyDemandZone* GetClosestSupplyZone(double price);
   CSupplyDemandZone* GetClosestDemandZone(double price);
   
   // Cleanup
   void              DeleteAllZones();
   
private:
   bool              DetectSupplyZoneByVolume(int startBar, double &top, double &bottom, 
                                             long &volumeTotal, double &volumeAvg, int &bars);
   bool              DetectDemandZoneByVolume(int startBar, double &top, double &bottom,
                                             long &volumeTotal, double &volumeAvg, int &bars);
   bool              AddSupplyZone(double top, double bottom, datetime time, long volume, 
                                  double volumeAvg, int bars);
   bool              AddDemandZone(double top, double bottom, datetime time, long volume,
                                  double volumeAvg, int bars);
   bool              IsValidZoneSize(double size);
   bool              IsZoneOverlapping(ENUM_SD_ZONE_TYPE type, double top, double bottom);
   void              SortZonesByDistance(double currentPrice);
   void              ShowClosestZones(int count);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSupplyDemandManager::CSupplyDemandManager()
{
   m_symbol = _Symbol;
   m_timeframe = _Period;
   m_lookbackBars = 500;
   m_volumeThreshold = 0;
   m_minBarsInZone = 2;
   m_maxBarsInZone = 10;
   m_minZoneSize = 50;
   m_maxZoneSize = 1000;
   m_showZones = -1; // Show all by default
   
   m_supplyColor = clrCrimson;
   m_demandColor = clrDodgerBlue;
   m_supplyColorFill = clrMistyRose;
   m_demandColorFill = clrLightSteelBlue;
   m_showArrows = true;
   m_showLabels = true;
   
   m_lastUpdateTime = 0;
   m_lastScannedBar = 0;  // Initialize tracking
   
   ArrayResize(m_supplyZones, 0);
   ArrayResize(m_demandZones, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSupplyDemandManager::~CSupplyDemandManager()
{
   DeleteAllZones();
}

//+------------------------------------------------------------------+
//| Initialize manager                                                |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int lookback,
                                      long volumeThreshold, int minBars, int maxBars,
                                      double minSize, double maxSize, double minPriceLeftDist)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_lookbackBars = lookback;
   m_volumeThreshold = volumeThreshold;
   m_minBarsInZone = minBars;
   m_maxBarsInZone = maxBars;
   m_minZoneSize = minSize;
   m_maxZoneSize = maxSize;
   m_minPriceLeftDistance = minPriceLeftDist;
   
   return true;
}

//+------------------------------------------------------------------+
//| Set visual settings                                              |
//+------------------------------------------------------------------+
void CSupplyDemandManager::SetVisualSettings(color supplyCol, color demandCol, color supplyFill,
                                             color demandFill, int transparency, bool arrows, bool labels)
{
   m_supplyColor = supplyCol;
   m_demandColor = demandCol;
   m_supplyColorFill = supplyFill;
   m_demandColorFill = demandFill;
   m_showArrows = arrows;
   m_showLabels = labels;
   // Note: transparency parameter ignored - transparency is now state-based
   
   // Update existing zones
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL)
         m_supplyZones[i].SetVisualSettings(supplyCol, demandCol, supplyFill, demandFill, 
                                            transparency, arrows, labels);
   }
   
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL)
         m_demandZones[i].SetVisualSettings(supplyCol, demandCol, supplyFill, demandFill,
                                            transparency, arrows, labels);
   }
}

//+------------------------------------------------------------------+
//| Check if zone size is valid                                      |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::IsValidZoneSize(double size)
{
   double sizeInPoints = size / _Point;
   return (sizeInPoints >= m_minZoneSize && sizeInPoints <= m_maxZoneSize);
}

//+------------------------------------------------------------------+
//| Check if zone overlaps with existing zones                       |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::IsZoneOverlapping(ENUM_SD_ZONE_TYPE type, double top, double bottom)
{
   CSupplyDemandZone *zones[];
   int count = 0;
   
   if(type == SD_ZONE_SUPPLY)
   {
      count = ArraySize(m_supplyZones);
      ArrayResize(zones, count);
      for(int i = 0; i < count; i++)
         zones[i] = m_supplyZones[i];
   }
   else
   {
      count = ArraySize(m_demandZones);
      ArrayResize(zones, count);
      for(int i = 0; i < count; i++)
         zones[i] = m_demandZones[i];
   }
   
   for(int i = 0; i < count; i++)
   {
      if(zones[i] == NULL || !zones[i].IsValid())
         continue;
      
      double existingTop = zones[i].GetTop();
      double existingBottom = zones[i].GetBottom();
      
      // Check for overlap (allow small tolerance)
      double tolerance = (top - bottom) * 0.1; // 10% overlap tolerance
      if((bottom <= existingTop + tolerance && bottom >= existingBottom - tolerance) ||
         (top >= existingBottom - tolerance && top <= existingTop + tolerance) ||
         (bottom <= existingBottom && top >= existingTop))
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect supply zone by volume (high selling pressure)            |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::DetectSupplyZoneByVolume(int startBar, double &top, double &bottom,
                                                    long &volumeTotal, double &volumeAvg, int &bars)
{
   if(startBar < m_maxBarsInZone || startBar >= Bars(m_symbol, m_timeframe) - 10)
      return false;
   
   double high[], low[], close[], open[];
   long volume[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(volume, true);
   
   int copied = CopyHigh(m_symbol, m_timeframe, 0, startBar + 10, high);
   if(copied <= 0) return false;
   CopyLow(m_symbol, m_timeframe, 0, startBar + 10, low);
   CopyClose(m_symbol, m_timeframe, 0, startBar + 10, close);
   CopyOpen(m_symbol, m_timeframe, 0, startBar + 10, open);
   CopyTickVolume(m_symbol, m_timeframe, 0, startBar + 10, volume);
   
   // Look for potential supply zone (any bar type, volume based)
   long barVolume = volume[startBar];
   
   // If volume threshold is set, check it; otherwise accept any bar
   if(m_volumeThreshold > 0 && barVolume < m_volumeThreshold)
      return false;
   
   // Check if this is a local high
   bool isLocalHigh = (high[startBar] >= high[startBar-1] && high[startBar] >= high[startBar-2] &&
                       high[startBar] >= high[startBar+1] && high[startBar] >= high[startBar+2]);
   
   if(!isLocalHigh)
      return false;
   
   // Find the consolidation zone
   top = high[startBar];
   bottom = low[startBar];
   volumeTotal = barVolume;
   bars = 1;
   
   // Look for consecutive bars forming the zone (consolidation area)
   for(int i = startBar - 1; i >= startBar - m_maxBarsInZone && i >= 0; i--)
   {
      double zoneRange = top - bottom;
      
      // Allow bars that stay within reasonable range
      if(high[i] > top + zoneRange * 0.3 || low[i] < bottom - zoneRange * 0.3)
         break;
      
      if(high[i] > top) top = high[i];
      if(low[i] < bottom) bottom = low[i];
      
      volumeTotal += volume[i];
      bars++;
      
      if(bars >= m_maxBarsInZone)
         break;
   }
   
   // Verify there's a downward move after the zone
   bool hasMove = false;
   for(int i = startBar + 1; i <= startBar + 5 && i < ArraySize(close); i++)
   {
      double moveSize = top - low[i];
      double zoneSize = top - bottom;
      if(moveSize > zoneSize * 0.5) // At least 50% of zone size
      {
         hasMove = true;
         break;
      }
   }
   
   if(!hasMove || bars < m_minBarsInZone)
      return false;
   
   volumeAvg = (double)volumeTotal / bars;
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect demand zone by volume (high buying pressure)             |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::DetectDemandZoneByVolume(int startBar, double &top, double &bottom,
                                                    long &volumeTotal, double &volumeAvg, int &bars)
{
   if(startBar < m_maxBarsInZone || startBar >= Bars(m_symbol, m_timeframe) - 10)
      return false;
   
   double high[], low[], close[], open[];
   long volume[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(volume, true);
   
   int copied = CopyHigh(m_symbol, m_timeframe, 0, startBar + 10, high);
   if(copied <= 0) return false;
   CopyLow(m_symbol, m_timeframe, 0, startBar + 10, low);
   CopyClose(m_symbol, m_timeframe, 0, startBar + 10, close);
   CopyOpen(m_symbol, m_timeframe, 0, startBar + 10, open);
   CopyTickVolume(m_symbol, m_timeframe, 0, startBar + 10, volume);
   
   // Look for potential demand zone (any bar type, volume based)
   long barVolume = volume[startBar];
   
   // If volume threshold is set, check it; otherwise accept any bar
   if(m_volumeThreshold > 0 && barVolume < m_volumeThreshold)
      return false;
   
   // Check if this is a local low
   bool isLocalLow = (low[startBar] <= low[startBar-1] && low[startBar] <= low[startBar-2] &&
                      low[startBar] <= low[startBar+1] && low[startBar] <= low[startBar+2]);
   
   if(!isLocalLow)
      return false;
   
   // Find the consolidation zone
   top = high[startBar];
   bottom = low[startBar];
   volumeTotal = barVolume;
   bars = 1;
   
   // Look for consecutive bars forming the zone (consolidation area)
   for(int i = startBar - 1; i >= startBar - m_maxBarsInZone && i >= 0; i--)
   {
      double zoneRange = top - bottom;
      
      // Allow bars that stay within reasonable range
      if(high[i] > top + zoneRange * 0.3 || low[i] < bottom - zoneRange * 0.3)
         break;
      
      if(high[i] > top) top = high[i];
      if(low[i] < bottom) bottom = low[i];
      
      volumeTotal += volume[i];
      bars++;
      
      if(bars >= m_maxBarsInZone)
         break;
   }
   
   // Verify there's an upward move after the zone
   bool hasMove = false;
   for(int i = startBar + 1; i <= startBar + 5 && i < ArraySize(close); i++)
   {
      double moveSize = high[i] - bottom;
      double zoneSize = top - bottom;
      if(moveSize > zoneSize * 0.5) // At least 50% of zone size
      {
         hasMove = true;
         break;
      }
   }
   
   if(!hasMove || bars < m_minBarsInZone)
      return false;
   
   volumeAvg = (double)volumeTotal / bars;
   
   return true;
}

//+------------------------------------------------------------------+
//| Add supply zone                                                   |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::AddSupplyZone(double top, double bottom, datetime time, long volume,
                                         double volumeAvg, int bars)
{
   if(!IsValidZoneSize(top - bottom))
      return false;
   
   if(IsZoneOverlapping(SD_ZONE_SUPPLY, top, bottom))
      return false;
   
   CSupplyDemandZone *zone = new CSupplyDemandZone();
   if(zone == NULL)
      return false;
   
   if(!zone.Create(SD_ZONE_SUPPLY, top, bottom, time, volume, volumeAvg, bars))
   {
      delete zone;
      return false;
   }
   
   zone.SetVisualSettings(m_supplyColor, m_demandColor, m_supplyColorFill, m_demandColorFill,
                         0, m_showArrows, m_showLabels);  // transparency ignored
   
   int size = ArraySize(m_supplyZones);
   ArrayResize(m_supplyZones, size + 1);
   m_supplyZones[size] = zone;
   
   return true;
}

//+------------------------------------------------------------------+
//| Add demand zone                                                   |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::AddDemandZone(double top, double bottom, datetime time, long volume,
                                         double volumeAvg, int bars)
{
   if(!IsValidZoneSize(top - bottom))
      return false;
   
   if(IsZoneOverlapping(SD_ZONE_DEMAND, top, bottom))
      return false;
   
   CSupplyDemandZone *zone = new CSupplyDemandZone();
   if(zone == NULL)
      return false;
   
   if(!zone.Create(SD_ZONE_DEMAND, top, bottom, time, volume, volumeAvg, bars))
   {
      delete zone;
      return false;
   }
   
   zone.SetVisualSettings(m_supplyColor, m_demandColor, m_supplyColorFill, m_demandColorFill,
                         0, m_showArrows, m_showLabels);  // transparency ignored
   
   int size = ArraySize(m_demandZones);
   ArrayResize(m_demandZones, size + 1);
   m_demandZones[size] = zone;
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect all zones                                                  |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::DetectZones()
{
   // Clear existing zones
   DeleteAllZones();
   
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(m_symbol, m_timeframe, 0, m_lookbackBars, time) <= 0)
   {
      // Print("ERROR: Failed to copy time data");
      return false;
   }
   
   int detectedSupply = 0;
   int detectedDemand = 0;
   
   // Scan for zones
   for(int i = 10; i < m_lookbackBars - 10; i++)
   {
      // Detect supply zones
      double top, bottom;
      long volumeTotal;
      double volumeAvg;
      int bars;
      
      if(DetectSupplyZoneByVolume(i, top, bottom, volumeTotal, volumeAvg, bars))
      {
         if(AddSupplyZone(top, bottom, time[i], volumeTotal, volumeAvg, bars))
            detectedSupply++;
      }
      
      // Detect demand zones
      if(DetectDemandZoneByVolume(i, top, bottom, volumeTotal, volumeAvg, bars))
      {
         if(AddDemandZone(top, bottom, time[i], volumeTotal, volumeAvg, bars))
            detectedDemand++;
      }
   }
   
   // Print("Zone detection complete: Supply=", detectedSupply, " Demand=", detectedDemand);
   Print("[DetectZones] Initial detection: Supply=", detectedSupply, " Demand=", detectedDemand);
   
   // Draw all zones immediately
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
         m_supplyZones[i].Draw();
   }
   
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
         m_demandZones[i].Draw();
   }
   
   Print("[DetectZones] After draw: Supply=", ArraySize(m_supplyZones), " Demand=", ArraySize(m_demandZones));
   
   m_lastUpdateTime = TimeCurrent();
   m_lastScannedBar = m_lookbackBars;  // Mark initial scan complete
   ChartRedraw();
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect new zones in recent bars only (no re-detection)          |
//+------------------------------------------------------------------+
bool CSupplyDemandManager::DetectNewZones(int lookbackBars = 20)
{
   datetime time[];
   ArraySetAsSeries(time, true);
   
   // Scan only the new bars since last scan
   int barsToScan = MathMin(lookbackBars + 20, m_lookbackBars);  // Add buffer for local high/low detection
   if(CopyTime(m_symbol, m_timeframe, 0, barsToScan, time) <= 0)
      return false;
   
   int detectedSupply = 0;
   int detectedDemand = 0;
   
   // Only scan from bar 10 to the last scanned position (avoid re-scanning old bars)
   int scanStart = 10;
   int scanEnd = MathMin(lookbackBars, barsToScan - 10);
   
   Print("[DetectNewZones] Scanning bars ", scanStart, " to ", scanEnd);
   
   // Scan bars that haven't been scanned yet
   for(int i = scanStart; i < scanEnd; i++)
   {
      double top, bottom;
      long volumeTotal;
      double volumeAvg;
      int bars;
      
      // Detect supply zones
      if(DetectSupplyZoneByVolume(i, top, bottom, volumeTotal, volumeAvg, bars))
      {
         if(AddSupplyZone(top, bottom, time[i], volumeTotal, volumeAvg, bars))
         {
            detectedSupply++;
            Print("[DetectNewZones] New SUPPLY zone at bar ", i, " | Price: ", top, "-", bottom);
         }
      }
      
      // Detect demand zones
      if(DetectDemandZoneByVolume(i, top, bottom, volumeTotal, volumeAvg, bars))
      {
         if(AddDemandZone(top, bottom, time[i], volumeTotal, volumeAvg, bars))
         {
            detectedDemand++;
            Print("[DetectNewZones] New DEMAND zone at bar ", i, " | Price: ", top, "-", bottom);
         }
      }
   }
   
   if(detectedSupply > 0 || detectedDemand > 0)
   {
      Print("[DetectNewZones] Found new zones: Supply=", detectedSupply, " Demand=", detectedDemand);
      Print("[DetectNewZones] Total zones: Supply=", ArraySize(m_supplyZones), " Demand=", ArraySize(m_demandZones));
      
      // Draw all zones (newly detected ones will be drawn)
      for(int i = 0; i < ArraySize(m_supplyZones); i++)
      {
         if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
            m_supplyZones[i].Draw();
      }
      
      for(int i = 0; i < ArraySize(m_demandZones); i++)
      {
         if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
            m_demandZones[i].Draw();
      }
      
      ChartRedraw();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update all zones (apply S&D validity rules)                     |
//+------------------------------------------------------------------+
void CSupplyDemandManager::UpdateAllZones()
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   int initialSupply = ArraySize(m_supplyZones);
   int initialDemand = ArraySize(m_demandZones);
   Print("[UpdateAllZones START] Supply=", initialSupply, " Demand=", initialDemand, " Price=", currentPrice);
   
   // Update supply zones (backwards to safely delete)
   for(int i = ArraySize(m_supplyZones) - 1; i >= 0; i--)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
      {
         m_supplyZones[i].UpdateDistanceToPrice(currentPrice);
         
         // Check zone state based on S&D rules
         if(m_supplyZones[i].HasPriceBroken(currentPrice))
         {
            // Zone is broken - delete it
            Print("[HasPriceBroken] SUPPLY[", i, "] Price=", currentPrice, " > Top=", m_supplyZones[i].GetTop(), " - DELETING");
            delete m_supplyZones[i];
            
            // Shift array down
            for(int j = i; j < ArraySize(m_supplyZones) - 1; j++)
               m_supplyZones[j] = m_supplyZones[j + 1];
            
            ArrayResize(m_supplyZones, ArraySize(m_supplyZones) - 1);
            continue;  // Skip to next zone
         }
         else if(m_supplyZones[i].IsPriceTouching(currentPrice, 0))
         {
            // Price is currently at the zone
            if(m_supplyZones[i].GetState() == SD_STATE_UNTESTED)
            {
               // Check if price has left the zone before
               if(m_supplyZones[i].GetZoneData().priceHasLeft)
               {
                  // Price returned after leaving - NOW draw entry arrow and open trade
                  Print("[IsPriceTouching] SUPPLY[", i, "] RETURN after leaving | Price=", currentPrice, " Bottom=", m_supplyZones[i].GetBottom(), " Top=", m_supplyZones[i].GetTop());
                  m_supplyZones[i].DrawArrow(TimeCurrent(), currentPrice);
                  m_supplyZones[i].SetState(SD_STATE_ACTIVE);
                  
                  // Open SELL trade for supply zone
                  OpenSellTrade(m_supplyZones[i]);
               }
               else
               {
                  // Price still in zone from formation - wait for it to leave first
                  Print("[IsPriceTouching] SUPPLY[", i, "] Still in zone from formation - waiting for exit");
               }
            }
            else if(m_supplyZones[i].GetState() == SD_STATE_TESTED)
            {
               // Weak zone - also draw entry arrow if price returns after leaving
               if(!m_supplyZones[i].GetZoneData().hasArrow)
               {
                  Print("[IsPriceTouching] SUPPLY[", i, "] WEAK zone return | Price=", currentPrice);
                  m_supplyZones[i].DrawArrow(TimeCurrent(), currentPrice);
                  
                  // Open SELL trade for weak supply zone
                  OpenSellTrade(m_supplyZones[i]);
               }
               m_supplyZones[i].SetState(SD_STATE_ACTIVE);
            }
            else
            {
               m_supplyZones[i].SetState(SD_STATE_ACTIVE);
            }
         }
         else
         {
            // Price is NOT touching the zone
            if(!m_supplyZones[i].GetZoneData().priceHasLeft)
            {
               // Check if price has moved far enough away from zone
               double zoneTop = m_supplyZones[i].GetTop();
               double zoneBottom = m_supplyZones[i].GetBottom();
               double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double minDistance = 0;
               
               if(m_minPriceLeftDistance == 0)
               {
                  // Auto-calculate distance based on nearest DEMAND zone below
                  double nearestDemandTop = 0;
                  bool foundDemand = false;
                  
                  for(int j = 0; j < ArraySize(m_demandZones); j++)
                  {
                     if(m_demandZones[j] != NULL && m_demandZones[j].IsValid())
                     {
                        double demandTop = m_demandZones[j].GetTop();
                        // Find demand zone below current supply zone
                        if(demandTop < zoneBottom)
                        {
                           if(!foundDemand || demandTop > nearestDemandTop)
                           {
                              nearestDemandTop = demandTop;
                              foundDemand = true;
                           }
                        }
                     }
                  }
                  
                  if(foundDemand)
                  {
                     // Distance = from zone bottom to demand zone top
                     minDistance = zoneBottom - nearestDemandTop;
                  }
                  else
                  {
                     // No opposite zone found, use zone size as minimum
                     minDistance = (zoneTop - zoneBottom) * 2;
                  }
               }
               else
               {
                  minDistance = m_minPriceLeftDistance * point;
               }
               
               // Price must be below zone top by at least minDistance
               if(currentPrice < zoneTop - minDistance)
               {
                  // Mark that price has left the zone for the first time
                  m_supplyZones[i].SetPriceHasLeft(true);
                  Print("[UpdateAllZones] SUPPLY[", i, "] Price LEFT zone - now validated (distance=", 
                        (zoneTop - currentPrice) / point, " points, required=", minDistance / point, " points)");
               }
            }
            
            if(m_supplyZones[i].GetState() == SD_STATE_ACTIVE)
            {
               // Price has left an active zone - mark as tested
               m_supplyZones[i].SetState(SD_STATE_TESTED);
               m_supplyZones[i].IncrementTouch();
               // Reset arrow flag so next return draws new arrow for weak zone
               m_supplyZones[i].SetHasArrow(false);
            }
         }
         
         m_supplyZones[i].Update();
      }
   }
   
   // Update demand zones (backwards to safely delete)
   for(int i = ArraySize(m_demandZones) - 1; i >= 0; i--)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
      {
         m_demandZones[i].UpdateDistanceToPrice(currentPrice);
         
         // Check zone state based on S&D rules
         if(m_demandZones[i].HasPriceBroken(currentPrice))
         {
            // Zone is broken - delete it
            Print("[HasPriceBroken] DEMAND[", i, "] Price=", currentPrice, " < Bottom=", m_demandZones[i].GetBottom(), " - DELETING");
            delete m_demandZones[i];
            
            // Shift array down
            for(int j = i; j < ArraySize(m_demandZones) - 1; j++)
               m_demandZones[j] = m_demandZones[j + 1];
            
            ArrayResize(m_demandZones, ArraySize(m_demandZones) - 1);
            continue;  // Skip to next zone
         }
         else if(m_demandZones[i].IsPriceTouching(currentPrice, 0))
         {
            // Price is currently at the zone
            if(m_demandZones[i].GetState() == SD_STATE_UNTESTED)
            {
               // Check if price has left the zone before
               if(m_demandZones[i].GetZoneData().priceHasLeft)
               {
                  // Price returned after leaving - NOW draw entry arrow and open trade
                  Print("[IsPriceTouching] DEMAND[", i, "] RETURN after leaving | Price=", currentPrice, " Bottom=", m_demandZones[i].GetBottom(), " Top=", m_demandZones[i].GetTop());
                  m_demandZones[i].DrawArrow(TimeCurrent(), currentPrice);
                  m_demandZones[i].SetState(SD_STATE_ACTIVE);
                  
                  // Open BUY trade for demand zone
                  OpenBuyTrade(m_demandZones[i]);
               }
               else
               {
                  // Price still in zone from formation - wait for it to leave first
                  Print("[IsPriceTouching] DEMAND[", i, "] Still in zone from formation - waiting for exit");
               }
            }
            else if(m_demandZones[i].GetState() == SD_STATE_TESTED)
            {
               // Weak zone - also draw entry arrow if price returns after leaving
               if(!m_demandZones[i].GetZoneData().hasArrow)
               {
                  Print("[IsPriceTouching] DEMAND[", i, "] WEAK zone return | Price=", currentPrice);
                  m_demandZones[i].DrawArrow(TimeCurrent(), currentPrice);
                  
                  // Open BUY trade for weak demand zone
                  OpenBuyTrade(m_demandZones[i]);
               }
               m_demandZones[i].SetState(SD_STATE_ACTIVE);
            }
            else
            {
               m_demandZones[i].SetState(SD_STATE_ACTIVE);
            }
         }
         else
         {
            // Price is NOT touching the zone
            if(!m_demandZones[i].GetZoneData().priceHasLeft)
            {
               // Check if price has moved far enough away from zone
               double zoneBottom = m_demandZones[i].GetBottom();
               double zoneTop = m_demandZones[i].GetTop();
               double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double minDistance = 0;
               
               if(m_minPriceLeftDistance == 0)
               {
                  // Auto-calculate distance based on nearest SUPPLY zone above
                  double nearestSupplyBottom = DBL_MAX;
                  bool foundSupply = false;
                  
                  for(int j = 0; j < ArraySize(m_supplyZones); j++)
                  {
                     if(m_supplyZones[j] != NULL && m_supplyZones[j].IsValid())
                     {
                        double supplyBottom = m_supplyZones[j].GetBottom();
                        // Find supply zone above current demand zone
                        if(supplyBottom > zoneTop)
                        {
                           if(!foundSupply || supplyBottom < nearestSupplyBottom)
                           {
                              nearestSupplyBottom = supplyBottom;
                              foundSupply = true;
                           }
                        }
                     }
                  }
                  
                  if(foundSupply)
                  {
                     // Distance = from zone top to supply zone bottom
                     minDistance = nearestSupplyBottom - zoneTop;
                  }
                  else
                  {
                     // No opposite zone found, use zone size as minimum
                     minDistance = (zoneTop - zoneBottom) * 2;
                  }
               }
               else
               {
                  minDistance = m_minPriceLeftDistance * point;
               }
               
               // Price must be above zone bottom by at least minDistance
               if(currentPrice > zoneBottom + minDistance)
               {
                  // Mark that price has left the zone for the first time
                  m_demandZones[i].SetPriceHasLeft(true);
                  Print("[UpdateAllZones] DEMAND[", i, "] Price LEFT zone - now validated (distance=", 
                        (currentPrice - zoneBottom) / point, " points, required=", minDistance / point, " points)");
               }
            }
            
            if(m_demandZones[i].GetState() == SD_STATE_ACTIVE)
            {
               // Price has left an active zone - mark as tested
               m_demandZones[i].SetState(SD_STATE_TESTED);
               m_demandZones[i].IncrementTouch();
               // Reset arrow flag so next return draws new arrow for weak zone
               m_demandZones[i].SetHasArrow(false);
            }
         }
         
         m_demandZones[i].Update();
      }
   }
   
   Print("[UpdateAllZones END] Supply=", ArraySize(m_supplyZones), " Demand=", ArraySize(m_demandZones));
}

//+------------------------------------------------------------------+
//| Sort zones by distance to current price                          |
//+------------------------------------------------------------------+
void CSupplyDemandManager::SortZonesByDistance(double currentPrice)
{
   // Update distances first
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
      if(m_supplyZones[i] != NULL)
         m_supplyZones[i].UpdateDistanceToPrice(currentPrice);
   
   for(int i = 0; i < ArraySize(m_demandZones); i++)
      if(m_demandZones[i] != NULL)
         m_demandZones[i].UpdateDistanceToPrice(currentPrice);
   
   // Simple bubble sort for supply zones
   for(int i = 0; i < ArraySize(m_supplyZones) - 1; i++)
   {
      for(int j = 0; j < ArraySize(m_supplyZones) - i - 1; j++)
      {
         if(m_supplyZones[j] != NULL && m_supplyZones[j + 1] != NULL)
         {
            if(m_supplyZones[j].GetDistanceToPrice() > m_supplyZones[j + 1].GetDistanceToPrice())
            {
               CSupplyDemandZone *temp = m_supplyZones[j];
               m_supplyZones[j] = m_supplyZones[j + 1];
               m_supplyZones[j + 1] = temp;
            }
         }
      }
   }
   
   // Simple bubble sort for demand zones
   for(int i = 0; i < ArraySize(m_demandZones) - 1; i++)
   {
      for(int j = 0; j < ArraySize(m_demandZones) - i - 1; j++)
      {
         if(m_demandZones[j] != NULL && m_demandZones[j + 1] != NULL)
         {
            if(m_demandZones[j].GetDistanceToPrice() > m_demandZones[j + 1].GetDistanceToPrice())
            {
               CSupplyDemandZone *temp = m_demandZones[j];
               m_demandZones[j] = m_demandZones[j + 1];
               m_demandZones[j + 1] = temp;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Show only closest N zones (combined supply and demand)          |
//+------------------------------------------------------------------+
void CSupplyDemandManager::ShowClosestZones(int count)
{
   // Create combined array of all zones with distances
   struct SZoneDistance
   {
      CSupplyDemandZone *zone;
      double distance;
   };
   
   SZoneDistance allZones[];
   int totalZones = 0;
   
   // Add all valid supply zones
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
      {
         ArrayResize(allZones, totalZones + 1);
         allZones[totalZones].zone = m_supplyZones[i];
         allZones[totalZones].distance = m_supplyZones[i].GetDistanceToPrice();
         totalZones++;
      }
   }
   
   // Add all valid demand zones
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
      {
         ArrayResize(allZones, totalZones + 1);
         allZones[totalZones].zone = m_demandZones[i];
         allZones[totalZones].distance = m_demandZones[i].GetDistanceToPrice();
         totalZones++;
      }
   }
   
   // Sort all zones by distance
   for(int i = 0; i < totalZones - 1; i++)
   {
      for(int j = 0; j < totalZones - i - 1; j++)
      {
         if(allZones[j].distance > allZones[j + 1].distance)
         {
            SZoneDistance temp = allZones[j];
            allZones[j] = allZones[j + 1];
            allZones[j + 1] = temp;
         }
      }
   }
   
   // First hide all zones
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
      if(m_supplyZones[i] != NULL)
         m_supplyZones[i].Hide();
   
   for(int i = 0; i < ArraySize(m_demandZones); i++)
      if(m_demandZones[i] != NULL)
         m_demandZones[i].Hide();
   
   // Show only the N closest zones (combined)
   for(int i = 0; i < MathMin(count, totalZones); i++)
   {
      if(allZones[i].zone != NULL)
         allZones[i].zone.Show();
   }
}

//+------------------------------------------------------------------+
//| Manage zone display (InpShowZone: -1=all, 0=none, N=closest)    |
//+------------------------------------------------------------------+
void CSupplyDemandManager::ManageZoneDisplay()
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   Print("[ManageZoneDisplay] Mode=", m_showZones, " Supply=", ArraySize(m_supplyZones), " Demand=", ArraySize(m_demandZones));
   
   if(m_showZones == 0)
   {
      // Hide all zones
      for(int i = 0; i < ArraySize(m_supplyZones); i++)
         if(m_supplyZones[i] != NULL)
            m_supplyZones[i].Hide();
      
      for(int i = 0; i < ArraySize(m_demandZones); i++)
         if(m_demandZones[i] != NULL)
            m_demandZones[i].Hide();
   }
   else if(m_showZones == -1)
   {
      // Show all zones
      for(int i = 0; i < ArraySize(m_supplyZones); i++)
         if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
            m_supplyZones[i].Show();
      
      for(int i = 0; i < ArraySize(m_demandZones); i++)
         if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
            m_demandZones[i].Show();
   }
   else if(m_showZones > 0)
   {
      // Show only N closest zones
      SortZonesByDistance(currentPrice);
      ShowClosestZones(m_showZones);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Get closest supply zone to current price                        |
//+------------------------------------------------------------------+
CSupplyDemandZone* CSupplyDemandManager::GetClosestSupplyZone(double price)
{
   CSupplyDemandZone *closest = NULL;
   double minDistance = DBL_MAX;
   
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid() && 
         m_supplyZones[i].GetState() != SD_STATE_BROKEN)
      {
         m_supplyZones[i].UpdateDistanceToPrice(price);
         double distance = m_supplyZones[i].GetDistanceToPrice();
         
         if(distance < minDistance)
         {
            minDistance = distance;
            closest = m_supplyZones[i];
         }
      }
   }
   
   return closest;
}

//+------------------------------------------------------------------+
//| Get closest demand zone to current price                        |
//+------------------------------------------------------------------+
CSupplyDemandZone* CSupplyDemandManager::GetClosestDemandZone(double price)
{
   CSupplyDemandZone *closest = NULL;
   double minDistance = DBL_MAX;
   
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid() &&
         m_demandZones[i].GetState() != SD_STATE_BROKEN)
      {
         m_demandZones[i].UpdateDistanceToPrice(price);
         double distance = m_demandZones[i].GetDistanceToPrice();
         
         if(distance < minDistance)
         {
            minDistance = distance;
            closest = m_demandZones[i];
         }
      }
   }
   
   return closest;
}

//+------------------------------------------------------------------+
//| Delete all zones                                                  |
//+------------------------------------------------------------------+
void CSupplyDemandManager::DeleteAllZones()
{
   // Delete supply zones
   for(int i = ArraySize(m_supplyZones) - 1; i >= 0; i--)
   {
      if(m_supplyZones[i] != NULL)
      {
         delete m_supplyZones[i];
         m_supplyZones[i] = NULL;
      }
   }
   ArrayResize(m_supplyZones, 0);
   
   // Delete demand zones
   for(int i = ArraySize(m_demandZones) - 1; i >= 0; i--)
   {
      if(m_demandZones[i] != NULL)
      {
         delete m_demandZones[i];
         m_demandZones[i] = NULL;
      }
   }
   ArrayResize(m_demandZones, 0);
}
