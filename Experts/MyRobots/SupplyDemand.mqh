//+------------------------------------------------------------------+
//|                                                 SupplyDemand.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 07.01.2026 - Volume-based Supply & Demand Zone Detection        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

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
   int               m_zoneTransparency;
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
   
   // Setters
   void              SetState(ENUM_SD_ZONE_STATE state) { m_zone.state = state; }
   void              SetValid(bool valid) { m_zone.isValid = valid; }
   void              IncrementTouch() { m_zone.touchCount++; }
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
   
private:
   string            GenerateObjectName(string prefix);
   color             GetZoneColor(bool filled);
   void              DrawRectangle();
   void              DrawArrow();
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
   m_zoneTransparency = 85;
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
   m_zoneTransparency = transparency;
   m_showArrows = arrows;
   m_showLabels = labels;
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
//| Draw arrow signal (OBJ_ARROW code 108)                          |
//+------------------------------------------------------------------+
void CSupplyDemandZone::DrawArrow()
{
   if(!m_showArrows)
      return;
   
   // OBJ_ARROW code 108 is a circle marker
   double arrowPrice = (m_zone.type == SD_ZONE_SUPPLY) ? m_zone.priceTop : m_zone.priceBottom;
   
   if(!ObjectCreate(m_chartID, m_zone.arrowName, OBJ_ARROW, 0, m_zone.timeStart, arrowPrice))
   {
      Print("Failed to create arrow: ", m_zone.arrowName, " Error: ", GetLastError());
      return;
   }
   
   color arrowColor = GetZoneColor(false);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_ARROWCODE, 108); // Circle marker
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_BACK, false);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(m_chartID, m_zone.arrowName, OBJPROP_HIDDEN, true);
   
   string tooltip = StringFormat("%s Signal | Vol: %I64d", 
                                 (m_zone.type == SD_ZONE_SUPPLY) ? "SELL" : "BUY",
                                 m_zone.volumeTotal);
   ObjectSetString(m_chartID, m_zone.arrowName, OBJPROP_TOOLTIP, tooltip);
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
      Print("Failed to create label: ", m_zone.labelName, " Error: ", GetLastError());
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
   
   string labelText = StringFormat("Vol: %s\nAvg: %.0f", volumeText, m_zone.volumeAvg);
   
   ObjectSetString(m_chartID, m_zone.labelName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_COLOR, GetZoneColor(false));
   ObjectSetInteger(m_chartID, m_zone.labelName, OBJPROP_FONTSIZE, 8);
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
   DrawArrow();
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
         Print("Failed to extend zone: ", m_zone.rectangleName, " Error: ", GetLastError());
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
   
   // Update rectangle fill based on state
   if(ObjectFind(m_chartID, m_zone.rectangleName) >= 0)
   {
      color fillColor = GetZoneColor(true);
      
      // Adjust transparency based on state
      int transparency = m_zoneTransparency;
      if(m_zone.state == SD_STATE_BROKEN)
         transparency = 95; // More transparent if broken
      else if(m_zone.state == SD_STATE_ACTIVE)
         transparency = 70; // Less transparent if active
      
      ObjectSetInteger(m_chartID, m_zone.rectangleName, OBJPROP_BGCOLOR, fillColor);
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
//| Delete zone and all objects                                      |
//+------------------------------------------------------------------+
void CSupplyDemandZone::Delete()
{
   ObjectDelete(m_chartID, m_zone.rectangleName);
   ObjectDelete(m_chartID, m_zone.arrowName);
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
   
   // Display settings
   int               m_showZones;         // -1 = all, 0 = none, N = show N closest zones
   color             m_supplyColor;
   color             m_demandColor;
   color             m_supplyColorFill;
   color             m_demandColorFill;
   int               m_zoneTransparency;
   bool              m_showArrows;
   bool              m_showLabels;
   
   // Tracking
   datetime          m_lastUpdateTime;

public:
                     CSupplyDemandManager();
                    ~CSupplyDemandManager();
   
   // Initialization
   bool              Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int lookback, 
                               long volumeThreshold, int minBars, int maxBars,
                               double minSize, double maxSize);
   
   // Settings
   void              SetShowZones(int showZones) { m_showZones = showZones; }
   void              SetVisualSettings(color supplyCol, color demandCol, color supplyFill,
                                      color demandFill, int transparency, bool arrows, bool labels);
   
   // Zone detection
   bool              DetectZones();
   void              UpdateAllZones();
   void              ManageZoneDisplay();
   
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
   m_zoneTransparency = 85;
   m_showArrows = true;
   m_showLabels = true;
   
   m_lastUpdateTime = 0;
   
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
                                      double minSize, double maxSize)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_lookbackBars = lookback;
   m_volumeThreshold = volumeThreshold;
   m_minBarsInZone = minBars;
   m_maxBarsInZone = maxBars;
   m_minZoneSize = minSize;
   m_maxZoneSize = maxSize;
   
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
   m_zoneTransparency = transparency;
   m_showArrows = arrows;
   m_showLabels = labels;
   
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
   
   // Look for bearish bars with high volume
   bool isBearish = close[startBar] < open[startBar];
   if(!isBearish)
      return false;
   
   long barVolume = volume[startBar];
   if(barVolume < m_volumeThreshold)
      return false;
   
   // Find the consolidation/rejection zone
   top = high[startBar];
   bottom = low[startBar];
   volumeTotal = barVolume;
   bars = 1;
   
   // Look for consecutive bars forming the zone
   for(int i = startBar - 1; i >= startBar - m_maxBarsInZone && i >= 0; i--)
   {
      // Check if bars are forming a base (limited range)
      if(high[i] > top * 1.002 || low[i] < bottom * 0.998) // 0.2% tolerance
         break;
      
      if(high[i] > top) top = high[i];
      if(low[i] < bottom) bottom = low[i];
      
      // Only count bearish or consolidation bars in zone
      if(close[i] <= open[i] || MathAbs(close[i] - open[i]) < (high[i] - low[i]) * 0.3)
      {
         volumeTotal += volume[i];
         bars++;
      }
      else
         break;
   }
   
   // Verify there's a strong move down after the zone (confirms selling pressure)
   bool hasStrongMove = false;
   for(int i = startBar + 1; i <= startBar + 5 && i < ArraySize(close); i++)
   {
      if(low[i] < bottom - (top - bottom) * 1.5)
      {
         hasStrongMove = true;
         break;
      }
   }
   
   if(!hasStrongMove || bars < m_minBarsInZone)
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
   
   // Look for bullish bars with high volume
   bool isBullish = close[startBar] > open[startBar];
   if(!isBullish)
      return false;
   
   long barVolume = volume[startBar];
   if(barVolume < m_volumeThreshold)
      return false;
   
   // Find the consolidation/reaction zone
   top = high[startBar];
   bottom = low[startBar];
   volumeTotal = barVolume;
   bars = 1;
   
   // Look for consecutive bars forming the zone
   for(int i = startBar - 1; i >= startBar - m_maxBarsInZone && i >= 0; i--)
   {
      // Check if bars are forming a base (limited range)
      if(high[i] > top * 1.002 || low[i] < bottom * 0.998) // 0.2% tolerance
         break;
      
      if(high[i] > top) top = high[i];
      if(low[i] < bottom) bottom = low[i];
      
      // Only count bullish or consolidation bars in zone
      if(close[i] >= open[i] || MathAbs(close[i] - open[i]) < (high[i] - low[i]) * 0.3)
      {
         volumeTotal += volume[i];
         bars++;
      }
      else
         break;
   }
   
   // Verify there's a strong move up after the zone (confirms buying pressure)
   bool hasStrongMove = false;
   for(int i = startBar + 1; i <= startBar + 5 && i < ArraySize(close); i++)
   {
      if(high[i] > top + (top - bottom) * 1.5)
      {
         hasStrongMove = true;
         break;
      }
   }
   
   if(!hasStrongMove || bars < m_minBarsInZone)
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
                         m_zoneTransparency, m_showArrows, m_showLabels);
   
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
                         m_zoneTransparency, m_showArrows, m_showLabels);
   
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
      return false;
   
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
         AddSupplyZone(top, bottom, time[i], volumeTotal, volumeAvg, bars);
      }
      
      // Detect demand zones
      if(DetectDemandZoneByVolume(i, top, bottom, volumeTotal, volumeAvg, bars))
      {
         AddDemandZone(top, bottom, time[i], volumeTotal, volumeAvg, bars);
      }
   }
   
   Print("Supply zones detected: ", ArraySize(m_supplyZones));
   Print("Demand zones detected: ", ArraySize(m_demandZones));
   
   m_lastUpdateTime = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Update all zones                                                  |
//+------------------------------------------------------------------+
void CSupplyDemandManager::UpdateAllZones()
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   // Update supply zones
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
      {
         m_supplyZones[i].UpdateDistanceToPrice(currentPrice);
         m_supplyZones[i].Update();
         
         // Check zone state
         if(m_supplyZones[i].HasPriceBroken(currentPrice))
            m_supplyZones[i].SetState(SD_STATE_BROKEN);
         else if(m_supplyZones[i].IsPriceTouching(currentPrice, 0))
            m_supplyZones[i].SetState(SD_STATE_ACTIVE);
      }
   }
   
   // Update demand zones
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
      {
         m_demandZones[i].UpdateDistanceToPrice(currentPrice);
         m_demandZones[i].Update();
         
         // Check zone state
         if(m_demandZones[i].HasPriceBroken(currentPrice))
            m_demandZones[i].SetState(SD_STATE_BROKEN);
         else if(m_demandZones[i].IsPriceTouching(currentPrice, 0))
            m_demandZones[i].SetState(SD_STATE_ACTIVE);
      }
   }
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
//| Show only closest N zones                                        |
//+------------------------------------------------------------------+
void CSupplyDemandManager::ShowClosestZones(int count)
{
   // Show first N supply zones, hide rest
   for(int i = 0; i < ArraySize(m_supplyZones); i++)
   {
      if(m_supplyZones[i] != NULL && m_supplyZones[i].IsValid())
      {
         if(i < count)
            m_supplyZones[i].Show();
         else
            m_supplyZones[i].Hide();
      }
   }
   
   // Show first N demand zones, hide rest
   for(int i = 0; i < ArraySize(m_demandZones); i++)
   {
      if(m_demandZones[i] != NULL && m_demandZones[i].IsValid())
      {
         if(i < count)
            m_demandZones[i].Show();
         else
            m_demandZones[i].Hide();
      }
   }
}

//+------------------------------------------------------------------+
//| Manage zone display (InpShowZone: -1=all, 0=none, N=closest)    |
//+------------------------------------------------------------------+
void CSupplyDemandManager::ManageZoneDisplay()
{
   double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
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
