//+------------------------------------------------------------------+
//|                                                   FileHelper.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 09.01.2026 - File operations and logging helper classes         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

//+------------------------------------------------------------------+
//| CFileLogger - Enhanced logging class                             |
//+------------------------------------------------------------------+
class CFileLogger
{
private:
   int               m_fileHandle;
   int               m_logCounter;
   string            m_workFolder;
   string            m_logFileName;
   string            m_fullPath;
   bool              m_useCommonFolder;
   bool              m_enabled;
   bool              m_silentMode;
   bool              m_autoFlush;
   
   // Log level filtering
   enum LOG_LEVEL
   {
      LOG_DEBUG = 0,
      LOG_INFO = 1,
      LOG_REPORT = 2,
      LOG_WARNING = 3,
      LOG_ERROR = 4,
      LOG_CRITICAL = 5
   };
   
   LOG_LEVEL         m_minLevel;

public:
                     CFileLogger();
                    ~CFileLogger();
   
   // Initialization
   bool              Initialize(string folderName, string fileName, int accountLogin, 
                               string serverName, bool useCommon = false);
   void              SetEnabled(bool enabled) { m_enabled = enabled; }
   void              SetSilentMode(bool silent) { m_silentMode = silent; }
   void              SetAutoFlush(bool autoFlush) { m_autoFlush = autoFlush; }
   void              SetMinLogLevel(int level) { m_minLevel = (LOG_LEVEL)level; }
   
   // Logging methods
   void              Log(string message);
   void              Debug(string message);
   void              Info(string message);
   void              Report(string message);
   void              Warning(string message);
   void              Error(string message);
   void              Critical(string message);
   void              Separator(string title = "");
   
   // Getters
   string            GetWorkFolder() const { return m_workFolder; }
   string            GetFullPath() const { return m_fullPath; }
   int               GetLogCount() const { return m_logCounter; }
   bool              IsEnabled() const { return m_enabled; }
   
   // File operations
   void              Close();
   void              Flush();
   bool              Clear();

private:
   bool              CreateLogFolder();
   bool              OpenLogFile();
   void              WriteToFile(string message, string level = "INFO");
   string            FormatMessage(string message, string level);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CFileLogger::CFileLogger()
{
   m_fileHandle = INVALID_HANDLE;
   m_logCounter = 0;
   m_workFolder = "";
   m_logFileName = "";
   m_fullPath = "";
   m_useCommonFolder = false;
   m_enabled = true;
   m_silentMode = false;
   m_autoFlush = true;
   m_minLevel = LOG_DEBUG;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CFileLogger::~CFileLogger()
{
   Close();
}

//+------------------------------------------------------------------+
//| Initialize logger                                                 |
//+------------------------------------------------------------------+
bool CFileLogger::Initialize(string folderName, string fileName, int accountLogin,
                             string serverName, bool useCommon = false)
{
   m_useCommonFolder = useCommon;
   
   // Build work folder path
   string cleanServer = serverName;
   int eqPos = StringFind(serverName, "-");
   if(eqPos != -1)
      cleanServer = StringSubstr(serverName, 0, eqPos);
   
   m_workFolder = folderName + "\\" + cleanServer + "_" + IntegerToString(accountLogin);
   
   // Build log file name with date
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   m_logFileName = "\\" + fileName + "_" + dateStr + ".log";
   
   m_fullPath = m_workFolder + m_logFileName;
   
   // Create folder structure
   if(!CreateLogFolder())
   {
      Print("[CFileLogger] Failed to create log folder: ", m_workFolder);
      return false;
   }
   
   Info("Server: " + serverName);
   Info("Account Login: " + IntegerToString(accountLogin));
   Info("Logger initialized: " + m_fullPath);
   return true;
}

//+------------------------------------------------------------------+
//| Create log folder                                                 |
//+------------------------------------------------------------------+
bool CFileLogger::CreateLogFolder()
{
   int flag = m_useCommonFolder ? FILE_COMMON : 0;
   
   // Check if folder exists
   if(FolderCreate(m_workFolder, flag))
   {
      ResetLastError();
      return true;
   }
   
   int error = GetLastError();
   if(error == 5019) // Folder already exists
   {
      ResetLastError();
      return true;
   }
   
   Print("[CFileLogger] Failed to create folder: ", m_workFolder, " Error: ", error);
   return false;
}

//+------------------------------------------------------------------+
//| Open log file                                                     |
//+------------------------------------------------------------------+
bool CFileLogger::OpenLogFile()
{
   int flag = FILE_CSV | FILE_READ | FILE_WRITE;
   if(m_useCommonFolder)
      flag |= FILE_COMMON;
   
   m_fileHandle = FileOpen(m_fullPath, flag, ' ');
   
   if(m_fileHandle == INVALID_HANDLE)
   {
      Print("[CFileLogger] Cannot open file: ", m_fullPath, " Error: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Format log message                                                |
//+------------------------------------------------------------------+
string CFileLogger::FormatMessage(string message, string level)
{
   if(m_logCounter <= 9)
   {
      if(m_logCounter == 1)
         return "\n" + TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + 
            " [" + level + "]  0" + IntegerToString(m_logCounter) + "  " + message;
      else
         return TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + 
            " [" + level + "]  0" + IntegerToString(m_logCounter) + "  " + message;
   }
   else
      return TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS) + 
          " [" + level + "]  " + IntegerToString(m_logCounter) + "  " + message;
}

//+------------------------------------------------------------------+
//| Write to log file                                                 |
//+------------------------------------------------------------------+
void CFileLogger::WriteToFile(string message, string level)
{
   if(!m_enabled)
      return;
   
   m_logCounter++;
   
   if(!OpenLogFile())
      return;
   
   if(FileSeek(m_fileHandle, 0, SEEK_END))
   {
      string formattedMsg = FormatMessage(message, level);
      FileWrite(m_fileHandle, formattedMsg);
      
      if(m_autoFlush)
         FileFlush(m_fileHandle);
   }
   
   FileClose(m_fileHandle);
   m_fileHandle = INVALID_HANDLE;
   
   if(!m_silentMode)
   {
      // Print("\n", __FUNCTION__, ":");
      Print("[" + level + "] " + message);
   }
}

//+------------------------------------------------------------------+
//| Generic log method                                                |
//+------------------------------------------------------------------+
void CFileLogger::Log(string message)
{
   WriteToFile(message, "LOG");
}

//+------------------------------------------------------------------+
//| Debug level log                                                   |
//+------------------------------------------------------------------+
void CFileLogger::Debug(string message)
{
   if(m_minLevel <= LOG_DEBUG)
      WriteToFile(message, "DEBUG");
}

//+------------------------------------------------------------------+
//| Info level log                                                    |
//+------------------------------------------------------------------+
void CFileLogger::Info(string message)
{
   if(m_minLevel <= LOG_INFO)
      WriteToFile(message, "INFO");
}

//+------------------------------------------------------------------+
//| Report level log                                                  |
//+------------------------------------------------------------------+
void CFileLogger::Report(string message)
{
   if(m_minLevel <= LOG_REPORT)
      WriteToFile(message, "REPORT");
}

//+------------------------------------------------------------------+
//| Warning level log                                                 |
//+------------------------------------------------------------------+
void CFileLogger::Warning(string message)
{
   if(m_minLevel <= LOG_WARNING)
      WriteToFile(message, "WARN");
}

//+------------------------------------------------------------------+
//| Error level log                                                   |
//+------------------------------------------------------------------+
void CFileLogger::Error(string message)
{
   if(m_minLevel <= LOG_ERROR)
      WriteToFile(message, "ERROR");
}

//+------------------------------------------------------------------+
//| Critical level log                                                |
//+------------------------------------------------------------------+
void CFileLogger::Critical(string message)
{
   if(m_minLevel <= LOG_CRITICAL)
   {
      WriteToFile(message, "CRITICAL");
      Alert("[CRITICAL] " + message);
   }
}

//+------------------------------------------------------------------+
//| Log separator                                                     |
//+------------------------------------------------------------------+
void CFileLogger::Separator(string title = "")
{
   if(!m_enabled)
      return;
   
   string sep = "══════════════════════════════════════════════════";
   if(StringLen(title) > 0)
   {
      WriteToFile(sep, "");
      WriteToFile("   " + title, "");
      WriteToFile(sep, "");
   }
   else
   {
      WriteToFile(sep, "");
   }
}

//+------------------------------------------------------------------+
//| Close log file                                                    |
//+------------------------------------------------------------------+
void CFileLogger::Close()
{
   if(m_fileHandle != INVALID_HANDLE)
   {
      FileFlush(m_fileHandle);
      FileClose(m_fileHandle);
      m_fileHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Flush log file                                                    |
//+------------------------------------------------------------------+
void CFileLogger::Flush()
{
   if(m_fileHandle != INVALID_HANDLE)
      FileFlush(m_fileHandle);
}

//+------------------------------------------------------------------+
//| Clear log file                                                    |
//+------------------------------------------------------------------+
bool CFileLogger::Clear()
{
   Close();
   
   int flag = m_useCommonFolder ? FILE_COMMON : 0;
   
   if(FileDelete(m_fullPath, flag))
   {
      m_logCounter = 0;
      Info("Log file cleared");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| CFileHelper - General file operations helper                     |
//+------------------------------------------------------------------+
class CFileHelper
{
public:
   // Folder operations
   static bool       CreateFolder(string folderPath, bool useCommon = false);
   static bool       FolderExists(string folderPath, bool useCommon = false);
   static bool       DeleteFolder(string folderPath, bool useCommon = false);
   
   // File operations
   static bool       FileExists(string filePath, bool useCommon = false);
   static bool       DeleteFile(string filePath, bool useCommon = false);
   static bool       CopyFile(string source, string destination, bool useCommon = false);
   static long       GetFileSize(string filePath, bool useCommon = false);
   static datetime   GetFileModifyTime(string filePath, bool useCommon = false);
   
   // String operations
   static string     SanitizeFileName(string fileName);
   static string     ExtractServerName(string serverString);
   static string     RemoveDots(string str);
   static string     GetDateString(datetime time = 0);
   
   // Path operations
   static string     GetTerminalDataPath();
   static string     GetTerminalCommonPath();
   static string     CombinePath(string path1, string path2);
   
   // Binary file operations
   static bool       WriteBinaryData(string filePath, uchar &data[], bool useCommon = false);
   static bool       ReadBinaryData(string filePath, uchar &data[], bool useCommon = false);
   
   // CSV file operations
   static bool       WriteCSVLine(string filePath, string &columns[], bool append = true, bool useCommon = false);
   static bool       ReadCSVFile(string filePath, string &lines[], bool useCommon = false);
};

//+------------------------------------------------------------------+
//| Create folder                                                     |
//+------------------------------------------------------------------+
static bool CFileHelper::CreateFolder(string folderPath, bool useCommon = false)
{
   int flag = useCommon ? FILE_COMMON : 0;
   
   if(FolderCreate(folderPath, flag))
   {
      ResetLastError();
      return true;
   }
   
   int error = GetLastError();
   if(error == 5019) // Folder already exists
   {
      ResetLastError();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if folder exists                                            |
//+------------------------------------------------------------------+
static bool CFileHelper::FolderExists(string folderPath, bool useCommon = false)
{
   // Try to create - if it fails with "already exists", it exists
   int flag = useCommon ? FILE_COMMON : 0;
   
   if(FolderCreate(folderPath, flag))
   {
      // Successfully created, so it didn't exist before
      FolderDelete(folderPath, flag);
      ResetLastError();
      return false;
   }
   
   int error = GetLastError();
   ResetLastError();
   return (error == 5019); // ERR_CANNOT_CREATE_FOLDER means it exists
}

//+------------------------------------------------------------------+
//| Check if file exists                                              |
//+------------------------------------------------------------------+
static bool CFileHelper::FileExists(string filePath, bool useCommon = false)
{
   int flag = useCommon ? FILE_COMMON : 0;
   return FileIsExist(filePath, flag);
}

//+------------------------------------------------------------------+
//| Delete file                                                       |
//+------------------------------------------------------------------+
static bool CFileHelper::DeleteFile(string filePath, bool useCommon = false)
{
   int flag = useCommon ? FILE_COMMON : 0;
   return FileDelete(filePath, flag);
}

//+------------------------------------------------------------------+
//| Get file size                                                     |
//+------------------------------------------------------------------+
static long CFileHelper::GetFileSize(string filePath, bool useCommon = false)
{
   int flag = FILE_READ | FILE_BIN;
   if(useCommon)
      flag |= FILE_COMMON;
   
   int handle = FileOpen(filePath, flag);
   if(handle == INVALID_HANDLE)
      return -1;
   
   ulong size = FileSize(handle);
   FileClose(handle);
   
   return (long)size;
}

//+------------------------------------------------------------------+
//| Get file modify time                                              |
//+------------------------------------------------------------------+
static datetime CFileHelper::GetFileModifyTime(string filePath, bool useCommon = false)
{
   int flag = useCommon ? FILE_COMMON : 0;
   
   long fileTime = FileGetInteger(filePath, FILE_MODIFY_DATE, flag);
   if(fileTime > 0)
      return (datetime)fileTime;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Sanitize file name                                                |
//+------------------------------------------------------------------+
static string CFileHelper::SanitizeFileName(string fileName)
{
   string result = fileName;
   StringReplace(result, "\\", "_");
   StringReplace(result, "/", "_");
   StringReplace(result, ":", "_");
   StringReplace(result, "*", "_");
   StringReplace(result, "?", "_");
   StringReplace(result, "\"", "_");
   StringReplace(result, "<", "_");
   StringReplace(result, ">", "_");
   StringReplace(result, "|", "_");
   return result;
}

//+------------------------------------------------------------------+
//| Extract server name from server string                           |
//+------------------------------------------------------------------+
static string CFileHelper::ExtractServerName(string serverString)
{
   int eqPos = StringFind(serverString, "-");
   if(eqPos != -1)
      return StringSubstr(serverString, 0, eqPos);
   return serverString;
}

//+------------------------------------------------------------------+
//| Remove dots from string                                           |
//+------------------------------------------------------------------+
static string CFileHelper::RemoveDots(string str)
{
   string result = str;
   StringReplace(result, ".", "");
   return result;
}

//+------------------------------------------------------------------+
//| Get date string in DD.MM.YYYY format                             |
//+------------------------------------------------------------------+
static string CFileHelper::GetDateString(datetime time = 0)
{
   if(time == 0)
      time = TimeCurrent();
   
   MqlDateTime dt;
   TimeToStruct(time, dt);
   
   return StringFormat("%02d.%02d.%04d", dt.day, dt.mon, dt.year);
}

//+------------------------------------------------------------------+
//| Get terminal data path                                            |
//+------------------------------------------------------------------+
static string CFileHelper::GetTerminalDataPath()
{
   return TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
}

//+------------------------------------------------------------------+
//| Get terminal common path                                          |
//+------------------------------------------------------------------+
static string CFileHelper::GetTerminalCommonPath()
{
   return TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\MQL5\\Files";
}

//+------------------------------------------------------------------+
//| Combine path                                                      |
//+------------------------------------------------------------------+
static string CFileHelper::CombinePath(string path1, string path2)
{
   string result = path1;
   
   // Remove trailing slash from path1
   if(StringLen(result) > 0 && StringGetCharacter(result, StringLen(result) - 1) == '\\')
      result = StringSubstr(result, 0, StringLen(result) - 1);
   
   // Remove leading slash from path2
   if(StringLen(path2) > 0 && StringGetCharacter(path2, 0) == '\\')
      path2 = StringSubstr(path2, 1);
   
   return result + "\\" + path2;
}

//+------------------------------------------------------------------+
//| Write binary data to file                                         |
//+------------------------------------------------------------------+
static bool CFileHelper::WriteBinaryData(string filePath, uchar &data[], bool useCommon = false)
{
   int flag = FILE_WRITE | FILE_BIN;
   if(useCommon)
      flag |= FILE_COMMON;
   
   int handle = FileOpen(filePath, flag);
   if(handle == INVALID_HANDLE)
      return false;
   
   uint written = FileWriteArray(handle, data);
   FileClose(handle);
   
   return (written == ArraySize(data));
}

//+------------------------------------------------------------------+
//| Read binary data from file                                        |
//+------------------------------------------------------------------+
static bool CFileHelper::ReadBinaryData(string filePath, uchar &data[], bool useCommon = false)
{
   int flag = FILE_READ | FILE_BIN;
   if(useCommon)
      flag |= FILE_COMMON;
   
   int handle = FileOpen(filePath, flag);
   if(handle == INVALID_HANDLE)
      return false;
   
   ArrayResize(data, (int)FileSize(handle));
   uint read = FileReadArray(handle, data);
   FileClose(handle);
   
   return (read > 0);
}

//+------------------------------------------------------------------+
//| Write CSV line to file                                            |
//+------------------------------------------------------------------+
static bool CFileHelper::WriteCSVLine(string filePath, string &columns[], bool append = true, bool useCommon = false)
{
   int flag = FILE_CSV | FILE_WRITE;
   if(append)
      flag |= FILE_READ;
   if(useCommon)
      flag |= FILE_COMMON;
   
   int handle = FileOpen(filePath, flag, ',');
   if(handle == INVALID_HANDLE)
      return false;
   
   if(append)
      FileSeek(handle, 0, SEEK_END);
   
   // Write all columns
   for(int i = 0; i < ArraySize(columns); i++)
   {
      if(i > 0)
         FileWrite(handle, columns[i]);
      else
         FileWriteString(handle, columns[i]);
   }
   
   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Read CSV file into string array                                  |
//+------------------------------------------------------------------+
static bool CFileHelper::ReadCSVFile(string filePath, string &lines[], bool useCommon = false)
{
   int flag = FILE_CSV | FILE_READ;
   if(useCommon)
      flag |= FILE_COMMON;
   
   int handle = FileOpen(filePath, flag, ',');
   if(handle == INVALID_HANDLE)
      return false;
   
   ArrayResize(lines, 0);
   int count = 0;
   
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringLen(line) > 0)
      {
         ArrayResize(lines, count + 1);
         lines[count] = line;
         count++;
      }
   }
   
   FileClose(handle);
   return (count > 0);
}

//+------------------------------------------------------------------+
