//+------------------------------------------------------------------+
//|                                                  FileNLogger.mqh |
//|                                 Copyright 2025, Cheruhaya Sulong |
//|                           https://www.mql5.com/en/users/cssulong |
//| 07.01.2026 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Cheruhaya Sulong"
#property link      "https://www.mql5.com/en/users/cssulong"

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+

// Files and Logging
static int        log_counter = 0;
int               log_file = 0;
int               acc_login = 0;
string            expert_folder = "";
string            work_folder = "";
string            log_fileName = "";
bool              common_folder = false;
bool              log_enabled = false;
bool              silent_log = false;

//+------------------------------------------------------------------+
//| Method CurrentAccountInfo                                        |
//+------------------------------------------------------------------+
string CurrentAccountInfo(string server)
{
   int eq_pos = StringFind(server,"-");
   string server_name = (eq_pos != -1) ? StringSubstr(server, 0, eq_pos) : server;
   Print("Account Server: ",server_name);
   return(server_name);
}

//+------------------------------------------------------------------+
//| Method RemoveDots                                                |
//+------------------------------------------------------------------+
string RemoveDots(string str)
{
   StringReplace(str,".","");
   return(str);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
datetime DateToString()
{
   string dateStr = TimeToString(TimeLocal(), TIME_DATE);
   return StringToTime(dateStr);
}

//+------------------------------------------------------------------+
//| Method CreateFolder                                              |
//+------------------------------------------------------------------+
bool CreateFolder(string folder_name, bool common_flag)
{
   int flag = common_flag ? FILE_COMMON : 0;
   string working_folder;
   if (common_flag)
      working_folder = TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\MQL5\\Files";
   else
      working_folder = TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files";
   //---
   // PrintFormat("folder_path=%s",folder_name);
   //---
   if (FolderCreate(folder_name, flag))
   {
      // PrintFormat("Created the folder %s",working_folder+"\\"+folder_name);
      ResetLastError();
      return(true);
   }
   else
      PrintFormat("Failed to create the folder %s. Error code %d",working_folder+folder_name,GetLastError());
   //--- 
   return(false);
}

void Logging(const string message)
{
   if(!log_enabled)
      return;
   
   log_counter++;
   if (StringLen(log_fileName) > 0)
   {
      if (!FileIsExist(work_folder+log_fileName)) {
         if (CreateFolder(work_folder, common_folder)) {
            Print("New log folder created: ", work_folder);
            ResetLastError();
         }
         else {
            Print("Failed to create log folder: ", work_folder, ". Error code ", GetLastError());
            return;
         }
      }
      //---
      if (log_file == INVALID_HANDLE)
         log_file = FileOpen(work_folder + log_fileName, FILE_CSV|FILE_READ|FILE_WRITE, ' ');
      //---
      if (log_file == INVALID_HANDLE)
         Alert("Cannot open file for logging: ", work_folder + log_fileName);
      else if (FileSeek(log_file, 0, SEEK_END))
      {
         FileWrite(log_file, TimeToString(TimeLocal(), TIME_DATE | TIME_MINUTES | TIME_SECONDS), " #", log_counter, " ", message);
         FileFlush(log_file);
         FileClose(log_file);
         log_file = INVALID_HANDLE;
      }
      else Alert("Unexpected error accessing log file: ", work_folder + log_fileName);
   }      
   if (!silent_log)
      Print(message);
}

//+------------------------------------------------------------------+
