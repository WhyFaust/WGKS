#include <sourcemod>
#include <wgks>
#include <csgocolors>
#include <sdktools_stringtables>
#include <eItems>

#undef REQUIRE_PLUGIN
#include <shop>
#include <lk>
#define REQUIRE_PLUGIN

bool g_bShopLoaded;
bool g_bLKLoaded;

int g_iCratesCount;
int g_iWeaponsCount;
int g_iPaintsCount;

int g_iTempCaseNum[MAXPLAYERS+1];
int g_iTempCaseCost[MAXPLAYERS+1];
bool iClientInstantlyOpen[MAXPLAYERS+1] = false;

int g_iClientWinSkinNumPre[MAXPLAYERS+1] = -1;
int g_iClientWinWeaponDefIndPre[MAXPLAYERS+1] = -1;
int g_iClientWinSkinNum[MAXPLAYERS+1] = -1;
int g_iClientWinWeaponDefInd[MAXPLAYERS+1] = -1;
int g_iClientWinSkinNumPost[MAXPLAYERS+1] = -1;
int g_iClientWinWeaponDefIndPost[MAXPLAYERS+1] = -1;

Handle g_hTimerCase[MAXPLAYERS+1];
int iClientTimerCount[MAXPLAYERS+1] = 0;

char g_sClientCases[MAXPLAYERS+1][512];

KeyValues ConfigCases[MAXPLAYERS+1];

Handle g_hOnCaseOpened, g_hOnCaseOpen;

public void OnAllPluginsLoaded()
{
    g_bShopLoaded = LibraryExists("shop");
    g_bLKLoaded = LibraryExists("lk");
}

public void OnLibraryRemoved(const char[] name)
{
    if(StrEqual(name, "shop"))
    {
        g_bShopLoaded = false;
    }
    else if(StrEqual(name, "lk"))
    {
        g_bLKLoaded = false;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if(StrEqual(name, "shop"))
    {
        g_bShopLoaded = true;
    }
    else if(StrEqual(name, "lk"))
    {
        g_bLKLoaded = true;
    }
    else if(StrEqual(name, "wgks"))
    {
        CreateTimer(1.5, CreateTables);
    }
}

public Plugin myinfo =
{
    name = "[WGKS MODULE] Cases",
    author = "baferpro",
    version = WGKS_VERSION
};

public void OnMapStart()
{
    AddFileToDownloadsTable("sound/BaFeR/cases/tuturuu.mp3");
    AddToStringTable(FindStringTable("soundprecache"), "BaFeR/cases/tuturuu.mp3");
}

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("This plugin works only on CS:GO");
    }
    
    Handle core = FindPluginByFile("wgks.smx"); 
    if(core != INVALID_HANDLE) PrintToServer("Success"); 
    else SetFailState("Core not found");

    LoadTranslations("wgks_cases.phrases");
    
    char sVersion[128];
    if(GetPluginInfo(core, PlInfo_Version, sVersion, sizeof(sVersion)))
    {
        if(!StrEqual(sVersion, WGKS_VERSION)) 
            SetFailState("This plugin not work with this core version");
    }
    else SetFailState("Failed to get core version"); 
    core = INVALID_HANDLE;

    RegConsoleCmd("sm_cases", Command_OpenCasesMenu, "Open cases menu!");
    RegConsoleCmd("sm_case", Command_OpenCasesMenu, "Open cases menu!");

    RegConsoleCmd("sm_fo", Command_FastOpen, "Fast open case.");
    RegConsoleCmd("sm_fastopen", Command_FastOpen, "Fast open case.");

    g_hOnCaseOpened = CreateGlobalForward("WGKS_Cases_CaseOpened", ET_Ignore, Param_Cell);
    g_hOnCaseOpen = CreateGlobalForward("WGKS_Cases_CaseOpen", ET_Ignore, Param_Cell, Param_String, Param_Cell);
    //CreateTimer(1.5, CreateTables);
}

public void eItems_OnItemsSynced()
{
    g_iCratesCount = eItems_GetCratesCount();
    g_iWeaponsCount = eItems_GetWeaponCount();
    g_iPaintsCount = eItems_GetPaintsCount();
}

public void OnClientPostAdminCheck(int iClient)
{
    if(IsValidClient(iClient))
    {
        char sSteamID[64];
        GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

        Database db = WGKS_GetDatabase();
    
        char sQuery[1024];
        Format(sQuery, sizeof(sQuery), "SELECT cases FROM wgks_cases WHERE steamid = '%s';", sSteamID);
        db.Query(GetClientCasesCallback, sQuery, iClient);

        delete db;
    }
}

public void GetClientCasesCallback(Database db, DBResultSet pResults, const char[] sError, int iClient)
{
    if(sError[0] != '\0')
    {
        LogError("[GetClientCasesCallback] Error: %s", sError);
        return;
    }
    
    if(pResults.RowCount != 0)
    {
        if(pResults.FetchRow())
        {
            pResults.FetchString(0, g_sClientCases[iClient], sizeof(g_sClientCases[]));
        }
    }
    else
    {
        char sSteamID[64];
        GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

        char sQuery[1024];
        Format(sQuery, sizeof(sQuery), "INSERT INTO wgks_cases (steamid, cases) VALUES ('%s', '');", sSteamID);
        db.Query(SQL_VoidCallback, sQuery);
    }
}

public Action Command_OpenCasesMenu(int iClient, int args)
{
    if(!IsValidClient(iClient))
    {
        return Plugin_Handled;
    }
    if(g_hTimerCase[iClient] != INVALID_HANDLE)
    {
        CPrintToChat(iClient, "%T", "AlreadyOpening", iClient);
        return Plugin_Handled;
    }
    LoadConfig(iClient);
    ResetClient(iClient, true);
    OpenCasesMenu(iClient);
    return Plugin_Handled;
}

void OpenCasesMenu(int iClient)
{
    Menu menu = CreateMenu(CasesMenu_Callback, MenuAction_Select | MenuAction_End);
    
    char sBuffer[256];
    Format(sBuffer, sizeof(sBuffer), "%T", "MenuTitle", iClient);
    SetMenuTitle(menu, sBuffer);

    ConfigCases[iClient].Rewind();
    if(ConfigCases[iClient].JumpToKey("Settings"))
    {
        for(int i = 0; i < g_iCratesCount; i++)
        {
            char sHelp[64];
            Format(sHelp, sizeof(sHelp), "%i", i);
            if(ConfigCases[iClient].GetNum(sHelp, 0) != -1)
            {
                eItems_GetCrateDisplayNameByCrateNum(i, sBuffer, sizeof(sBuffer));
                Format(sHelp, sizeof(sHelp), "%i;%i", i, ConfigCases[iClient].GetNum(sHelp, 0));
                menu.AddItem(sHelp, sBuffer);
            }
        }
    }

    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int CasesMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
        case MenuAction_Select:
        {
            int iClient = param1;
            char sInfo[256], sHelp[2][64];
            GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
            ExplodeString(sInfo, ";", sHelp, sizeof(sHelp), sizeof(sHelp[]));

            int iCaseNum = StringToInt(sHelp[0]);
            int iPrice = StringToInt(sHelp[1]);
            
            if(iPrice > 0)
            {
                g_iTempCaseNum[iClient] = iCaseNum;
                g_iTempCaseCost[iClient] = iPrice;

                Menu menu1 = CreateMenu(CasesSubMenu_Callback, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem | MenuAction_DrawItem);
                char sBuffer[256];
                eItems_GetCrateDisplayNameByCrateNum(g_iTempCaseNum[iClient], sBuffer, sizeof(sBuffer));
                SetMenuTitle(menu1, sBuffer);

                Format(sInfo, sizeof(sInfo), "%T", "MenuItemOpen", iClient, GetClientCasesCount(iClient));
                menu1.AddItem("0", sInfo);

                Format(sInfo, sizeof(sInfo), "%T", "MenuItemBuy", iClient, g_iTempCaseCost[iClient]);
                menu1.AddItem("1", sInfo);

                Format(sInfo, sizeof(sInfo), "%T", "MenuItemBuyAndOpen", iClient, g_iTempCaseCost[iClient]);
                menu1.AddItem("2", sInfo);

                Format(sInfo, sizeof(sInfo), "%T", "MenuItemInstantlyOpen", iClient, (iClientInstantlyOpen[iClient])?"+":"-");
                menu1.AddItem("3", sInfo);

                Format(sInfo, sizeof(sInfo), "%T", "MenuItemShowDrop", iClient);
                menu1.AddItem("4", sInfo);

                menu1.Display(iClient, MENU_TIME_FOREVER);
            }
            else
            {
                PrintToChat(iClient, "%T", "Incorrect", iClient, iCaseNum);
            }
        }
    }
    return;
}

public int CasesSubMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_DisplayItem:
        {
            char sDisplayBuffer[64];
            int iClient = param1;
            char sInfo[128];
            GetMenuItem(menu, param2, sInfo, sizeof(sInfo));

            if(StrEqual(sInfo, "0"))
            {
                Format(sDisplayBuffer, sizeof(sDisplayBuffer), "%T", "MenuItemOpen", iClient, GetClientCasesCount(iClient));
                return RedrawMenuItem(sDisplayBuffer);
            }
            else if(StrEqual(sInfo, "3"))
            {
                Format(sDisplayBuffer, sizeof(sDisplayBuffer), "%T", "MenuItemInstantlyOpen", iClient, (iClientInstantlyOpen[iClient])?"+":"-");
                return RedrawMenuItem(sDisplayBuffer);
            }
        }
        case MenuAction_DrawItem:
        {
            int iClient = param1;
            char sInfo[128];
            GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
            if(StrEqual(sInfo, "0"))
            {
                if(GetClientCasesCount(iClient)>0)
                    return ITEMDRAW_DEFAULT;
                else return ITEMDRAW_DISABLED;
            }
            if(StrEqual(sInfo, "1"))
            {
                if(g_bShopLoaded)
                {
                    if(Shop_GetClientCredits(iClient)>=g_iTempCaseCost[iClient])
                        return ITEMDRAW_DEFAULT;
                    else return ITEMDRAW_DISABLED;
                }
                else if(g_bLKLoaded)
                {
                    if(LK_GetClientCash(iClient)>=g_iTempCaseCost[iClient])
                        return ITEMDRAW_DEFAULT;
                    else return ITEMDRAW_DISABLED;
                }
            }
            if(StrEqual(sInfo, "2"))
            {
                if(g_bShopLoaded)
                {
                    if(Shop_GetClientCredits(iClient)>=g_iTempCaseCost[iClient])
                        return ITEMDRAW_DEFAULT;
                    else return ITEMDRAW_DISABLED;
                }
                else if(g_bLKLoaded)
                {
                    if(LK_GetClientCash(iClient)>=g_iTempCaseCost[iClient])
                        return ITEMDRAW_DEFAULT;
                    else return ITEMDRAW_DISABLED;
                }
            }
        }
        case MenuAction_Select:
        {
            int iClient = param1;
            char sInfo[128];
            GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
            
            if(StrEqual(sInfo, "0"))
            {
                if(g_hTimerCase[iClient] == INVALID_HANDLE)
                {
                    TakeCase(iClient, true);
                    if(!iClientInstantlyOpen[iClient])
                    {
                        Call_StartForward(g_hOnCaseOpened);
                        Call_PushCell(iClient);
                        Call_Finish();
                        g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                        CPrintToChat(iClient, "%T", "PrintFastOpen", iClient);
                    }
                    else
                    {
                        iClientTimerCount[iClient] = 185;
                        g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                        menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                    }
                }
                else CPrintToChat(iClient, "%T", "AlreadyOpening", iClient);
            }
            else if(StrEqual(sInfo, "1"))
            {	
                if(g_bShopLoaded)
                {
                    Shop_TakeClientCredits(iClient, g_iTempCaseCost[iClient]);
                    BuyCase(iClient, true);
                    menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
                else if(g_bLKLoaded)
                {
                    LK_TakeClientCash(iClient, g_iTempCaseCost[iClient]);
                    BuyCase(iClient, true);
                    menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
            }
            else if(StrEqual(sInfo, "2"))
            {
                if(g_hTimerCase[iClient] == INVALID_HANDLE)
                {
                    if(g_bShopLoaded)
                    {
                        Shop_TakeClientCredits(iClient, g_iTempCaseCost[iClient]);
                        BuyCase(iClient, false);
                        TakeCase(iClient, false);
                        if(!iClientInstantlyOpen[iClient])
                        {
                            Call_StartForward(g_hOnCaseOpened);
                            Call_PushCell(iClient);
                            Call_Finish();
                            g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                            CPrintToChat(iClient, "%T", "PrintFastOpen", iClient);
                        }
                        else
                        {
                            iClientTimerCount[iClient] = 185;
                            g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                            menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                        }
                    }
                    else if(g_bLKLoaded)
                    {
                        LK_TakeClientCash(iClient, g_iTempCaseCost[iClient]);
                        BuyCase(iClient, false);
                        TakeCase(iClient, false);
                        if(!iClientInstantlyOpen[iClient])
                        {
                            Call_StartForward(g_hOnCaseOpened);
                            Call_PushCell(iClient);
                            Call_Finish();
                            g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                            CPrintToChat(iClient, "%T", "PrintFastOpen", iClient);
                        }
                        else
                        {
                            iClientTimerCount[iClient] = 185;
                            g_hTimerCase[iClient] = CreateTimer(0.1, StartOpenCase, iClient, TIMER_REPEAT);
                            menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                        }
                    }
                }
                else CPrintToChat(iClient, "%T", "AlreadyOpening", iClient);
            }
            else if(StrEqual(sInfo, "3"))
            {
                iClientInstantlyOpen[iClient] = !iClientInstantlyOpen[iClient];
                menu.DisplayAt(iClient, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
            }
            else if(StrEqual(sInfo, "4"))
            {
                OpenDropMenu(iClient);
            }
        }
    }
    return 0;
}

void BuyCase(int iClient, bool SafeInDb = false)
{
    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    Format(g_sClientCases[iClient], sizeof(g_sClientCases[]), "%s%i;", g_sClientCases[iClient], g_iTempCaseNum[iClient]);

    if(SafeInDb)
    {
        Database db = WGKS_GetDatabase();
        char sQuery[1024];
        Format(sQuery, sizeof(sQuery), "UPDATE wgks_cases SET cases = '%s' WHERE steamid = '%s';", g_sClientCases[iClient], sSteamID);
        db.Query(SQL_VoidCallback, sQuery);
        delete db;
    }
}

void TakeCase(int iClient, bool SafeInDb = false)
{
    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    char sCase[3];
    IntToString(g_iTempCaseNum[iClient], sCase, sizeof(sCase));

    int iLeng = 0;
    for(int i = 0; i<=strlen(g_sClientCases[iClient]); i++)
    {
        if(g_sClientCases[iClient][i] == ';')
        {
            iLeng++;
        }
    }

    char[][] sCases1 = new char[iLeng][3];
    ExplodeString(g_sClientCases[iClient], ";", sCases1, iLeng, 3);

    char sNewCases[512];
    for(int i = 0; i<iLeng; i++)
    {
        if(StrEqual(sCase, sCases1[i]))
        {
            Format(sCases1[i], 3, "");
            for(int g = 0; g<iLeng; g++)
            {
                if(strlen(sCases1[g]) > 0)
                    Format(sNewCases, sizeof(sNewCases), "%s%s;", sNewCases, sCases1[g]);
            }
            g_sClientCases[iClient] = sNewCases;
            if(SafeInDb)
            {
                Database db = WGKS_GetDatabase();
                char sQuery[1024];
                Format(sQuery, sizeof(sQuery), "UPDATE wgks_cases SET cases = '%s' WHERE steamid = '%s';", g_sClientCases[iClient], sSteamID);
                db.Query(SQL_VoidCallback, sQuery);
                delete db;
            }
            break;
        }
    }
}

public void OpenDropMenu(int iClient)
{
    Menu menu = CreateMenu(DropMenu_Callback, MenuAction_Select | MenuAction_End);
    char sBuffer[128];
    Format(sBuffer, sizeof(sBuffer), "%T", "DropMenuTitle", iClient)
    SetMenuTitle(menu, sBuffer);

    for(int i = 0; i < eItems_GetCrateItemsCountByCrateNum(g_iTempCaseNum[iClient]); i++)
    {
        eItems_CrateItem item;
        eItems_GetCrateItemByCrateNum(g_iTempCaseNum[iClient], i, item, sizeof(item));

        char sHelp[128];
        eItems_GetSkinDisplayNameByDefIndex(item.SkinDefIndex, sBuffer, sizeof(sBuffer));
        eItems_GetSkinRarityName(item.SkinDefIndex, sHelp, sizeof(sHelp));
        Format(sBuffer, sizeof(sBuffer), "%s(%s)", sBuffer, sHelp)
        menu.AddItem(sBuffer, sBuffer);
    }
    Format(sBuffer, sizeof(sBuffer), "%T", "Knife", iClient)
    menu.AddItem(sBuffer, sBuffer);

    menu.Display(iClient, MENU_TIME_FOREVER);
}

public int DropMenu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return;
}		

public Action Command_FastOpen(int iClient, int args)
{
    if(IsValidClient(iClient))
    {
        if(iClientTimerCount[iClient] < 109)
            iClientTimerCount[iClient] = 109;
    }
    return Plugin_Handled;
}

public Action StartOpenCase(Handle timer, int iClient)
{
    if(IsValidClient(iClient))
    {
        if((iClientTimerCount[iClient] < 70 && iClientTimerCount[iClient]%2 == 0) || (iClientTimerCount[iClient] >= 70 && iClientTimerCount[iClient] < 110 && iClientTimerCount[iClient]%3 == 0) || (iClientTimerCount[iClient] >= 110 && iClientTimerCount[iClient] < 130 && iClientTimerCount[iClient]%5 == 0) || iClientTimerCount[iClient] == 140 || iClientTimerCount[iClient] == 155 || iClientTimerCount[iClient] == 185)
        {
            if(iClientTimerCount[iClient] == 0)
                ClientCommand(iClient, "play %s", "ui/csgo_ui_crate_open.wav");
            else
                ClientCommand(iClient, "play %s", "ui/csgo_ui_crate_item_scroll.wav");
            
            GetCaseSkin(iClient);	
            
            CasePrintHint(iClient);
        }
        iClientTimerCount[iClient]++;
        if(iClientTimerCount[iClient] >= 185) 
        {
            CasePrintHint(iClient);
            if(eItems_GetSkinRarity(g_iClientWinSkinNumPre[iClient])>=4)
            {
                char sName[32];
                GetClientName(iClient, sName, sizeof(sName));
                char sColor[16];
                switch(eItems_GetSkinRarity(g_iClientWinSkinNumPre[iClient]))
                {
                    case 1: Format(sColor, sizeof(sColor), "{GRAY}");
                    case 2: Format(sColor, sizeof(sColor), "{BLUE}");
                    case 3: Format(sColor, sizeof(sColor), "{DARKBLUE}");
                    case 4: Format(sColor, sizeof(sColor), "{PURPLE}");
                    case 5: Format(sColor, sizeof(sColor), "{PINK}");
                    case 6: Format(sColor, sizeof(sColor), "{RED}");
                    case 7: Format(sColor, sizeof(sColor), "{YELLOW}");
                }
                char DisplaySkinName[128], DisplayCrateName[128], DisplayWeaponName[128];
                eItems_GetSkinDisplayNameByDefIndex(g_iClientWinSkinNum[iClient], DisplaySkinName, sizeof(DisplaySkinName));
                eItems_GetCrateDisplayNameByCrateNum(g_iTempCaseNum[iClient], DisplayCrateName, sizeof(DisplayCrateName));
                eItems_GetWeaponDisplayNameByDefIndex(g_iClientWinWeaponDefInd[iClient], DisplayWeaponName, sizeof(DisplayWeaponName));
                CPrintToChatAll("%t", "PrintAll", sName, sColor, DisplaySkinName, DisplayCrateName, DisplayWeaponName);
                for(int i = 1; i<=MaxClients; i++)
                {
                    if(IsValidClient(i))
                    {
                        ClientCommand(i, "play %s", "BaFeR/cases/tuturuu.mp3");
                    }
                }
            }
            else
            {
                ClientCommand(iClient, "play %s", "ui/csgo_ui_crate_display.wav");
                char sColor[16];
                if(eItems_IsDefIndexKnife(g_iClientWinWeaponDefInd[iClient]))
                    Format(sColor, sizeof(sColor), "{YELLOW}");
                else
                {
                    switch(eItems_GetSkinRarity(g_iClientWinSkinNumPre[iClient]))
                    {
                        case 1: Format(sColor, sizeof(sColor), "{GRAY}");
                        case 2: Format(sColor, sizeof(sColor), "{BLUE}");
                        case 3: Format(sColor, sizeof(sColor), "{DARKBLUE}");
                        case 4: Format(sColor, sizeof(sColor), "{PURPLE}");
                        case 5: Format(sColor, sizeof(sColor), "{PINK}");
                        case 6: Format(sColor, sizeof(sColor), "{RED}");
                        case 7: Format(sColor, sizeof(sColor), "{YELLOW}");
                    }
                }
                char DisplaySkinName[128], DisplayCrateName[128], DisplayWeaponName[128];
                eItems_GetSkinDisplayNameByDefIndex(g_iClientWinSkinNum[iClient], DisplaySkinName, sizeof(DisplaySkinName));
                eItems_GetCrateDisplayNameByCrateNum(g_iTempCaseNum[iClient], DisplayCrateName, sizeof(DisplayCrateName));
                eItems_GetWeaponDisplayNameByDefIndex(g_iClientWinWeaponDefInd[iClient], DisplayWeaponName, sizeof(DisplayWeaponName));
                CPrintToChat(iClient, "%T", "PrintClient", iClient, sColor, DisplaySkinName, DisplayCrateName, DisplayWeaponName);
            }

            //if(StrEqual(g_iClientWinWeaponDefInd[iClient], "gloves"))
            //    Gloves_GiveClientGloves(iClient, g_iClientWinSkinNum[iClient]);
            //else
                Weapons_GiveClientSkin(iClient, eItems_GetWeaponNumByDefIndex(g_iClientWinWeaponDefInd[iClient]), g_iClientWinSkinNum[iClient]);

            Call_StartForward(g_hOnCaseOpen);
            Call_PushCell(iClient);
            //eItems_GetWeaponNumByDefIndex(g_iClientWinWeaponDefInd[iClient])
            Call_PushString("123");//
            Call_PushCell(g_iClientWinSkinNum[iClient]);
            Call_Finish();

            ResetClient(iClient, true);
        }
    }
}

void CasePrintHint(int iClient)
{
    char sBuffer[512];
    StrCat(sBuffer, 512, "<pre>");
    AddHUDToBuffer_CSGO(iClient, sBuffer, 512);
    StrCat(sBuffer, 512, "</pre>");
    PrintCSGOHUDText(iClient, "%s", sBuffer);
}

void PrintCSGOHUDText(int iClient, const char[] format, any ...)
{
    char buff[225];
    VFormat(buff, sizeof(buff), format, 3);
    Format(buff, sizeof(buff), "</font>%s ", buff);
    
    for(int i = strlen(buff); i < sizeof(buff); i++)
    {
        buff[i] = '\n';
    }
    
    Protobuf pb = view_as<Protobuf>(StartMessageOne("TextMsg", iClient, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS));
    pb.SetInt("msg_dst", 4);
    pb.AddString("params", "#SFUI_ContractKillStart");
    pb.AddString("params", buff);
    pb.AddString("params", NULL_STRING);
    pb.AddString("params", NULL_STRING);
    pb.AddString("params", NULL_STRING);
    pb.AddString("params", NULL_STRING);
    
    EndMessage();
}

int AddHUDToBuffer_CSGO(int iClient, char[] buffer, int maxlen)
{
    int iLines = 0;
    char sLine[128];

    Format(sLine, sizeof(sLine), "<font color='");
    if(eItems_IsDefIndexKnife(g_iClientWinWeaponDefIndPre[iClient]))
        Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
    else
    {
        switch(eItems_GetSkinRarity(g_iClientWinSkinNumPre[iClient]))
        {
            case 1: Format(sLine, sizeof(sLine), "%s%s", sLine, "#808080");
            case 2: Format(sLine, sizeof(sLine), "%s%s", sLine, "#99ccff");
            case 3: Format(sLine, sizeof(sLine), "%s%s", sLine, "#0000ff");
            case 4: Format(sLine, sizeof(sLine), "%s%s", sLine, "#993366");
            case 5: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff00ff");
            case 6: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff0000");
            case 7: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
        }
    }
    
    char DisplayName[128];
    eItems_GetSkinDisplayNameByDefIndex(g_iClientWinSkinNumPre[iClient], DisplayName, sizeof(DisplayName));
    Format(sLine, sizeof(sLine), "%s'>  %s</font>", sLine, DisplayName);
    AddHUDLine(buffer, maxlen, sLine, iLines);
    iLines++;

    Format(sLine, sizeof(sLine), "»<font color='");
    if(eItems_IsDefIndexKnife(g_iClientWinWeaponDefInd[iClient]))
        Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
    else
    {
        switch(eItems_GetSkinRarity(g_iClientWinSkinNum[iClient]))
        {
            case 1: Format(sLine, sizeof(sLine), "%s%s", sLine, "#808080");
            case 2: Format(sLine, sizeof(sLine), "%s%s", sLine, "#99ccff");
            case 3: Format(sLine, sizeof(sLine), "%s%s", sLine, "#0000ff");
            case 4: Format(sLine, sizeof(sLine), "%s%s", sLine, "#993366");
            case 5: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff00ff");
            case 6: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff0000");
            case 7: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
        }
    }
    eItems_GetSkinDisplayNameByDefIndex(g_iClientWinSkinNum[iClient], DisplayName, sizeof(DisplayName));
    Format(sLine, sizeof(sLine), "%s'>%s</font>«", sLine, DisplayName);
    AddHUDLine(buffer, maxlen, sLine, iLines);
    iLines++;

    Format(sLine, sizeof(sLine), "<font color='");
    if(eItems_IsDefIndexKnife(g_iClientWinWeaponDefIndPost[iClient]))
        Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
    else
    {
        switch(eItems_GetSkinRarity(g_iClientWinSkinNumPost[iClient]))
        {
            case 1: Format(sLine, sizeof(sLine), "%s%s", sLine, "#808080");
            case 2: Format(sLine, sizeof(sLine), "%s%s", sLine, "#99ccff");
            case 3: Format(sLine, sizeof(sLine), "%s%s", sLine, "#0000ff");
            case 4: Format(sLine, sizeof(sLine), "%s%s", sLine, "#993366");
            case 5: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff00ff");
            case 6: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ff0000");
            case 7: Format(sLine, sizeof(sLine), "%s%s", sLine, "#ffcc00");
        }
    }
    eItems_GetSkinDisplayNameByDefIndex(g_iClientWinSkinNumPost[iClient], DisplayName, sizeof(DisplayName));
    Format(sLine, sizeof(sLine), "%s'>  %s</font>", sLine, DisplayName);
    AddHUDLine(buffer, maxlen, sLine, iLines);
    iLines++;

    StrCat(buffer, maxlen, "</span>");

    return iLines;
}	

void AddHUDLine(char[] buffer, int maxlen, const char[] line, int lines)
{
    if(lines > 0)
    {
        Format(buffer, maxlen, "%s\n%s", buffer, line);
    }
    else
    {
        StrCat(buffer, maxlen, line);
    }
}

int GetClientCasesCount(int iClient)
{
    int iCount = 0;
    if(IsValidClient(iClient))
    {
        char sCaseNum[3];
        IntToString(g_iTempCaseNum[iClient], sCaseNum, sizeof(sCaseNum));
        char sClientCases[128][3]
        ExplodeString(g_sClientCases[iClient], ";", sClientCases, sizeof(sClientCases), sizeof(sClientCases[]));
        for(int i = 0; i<sizeof(sClientCases); i++)
        {
            if(StrEqual(sClientCases[i], sCaseNum))
                iCount++;
        }
    }
    return iCount;
}

void GetCaseSkin(int iClient)
{
    if(IsValidClient(iClient))
    {
        ConfigCases[iClient].Rewind();
        if(ConfigCases[iClient].JumpToKey("Chanse") && ConfigCases[iClient].GotoFirstSubKey(false))
        {
            ArrayList hArrayChanse = new ArrayList(1);
            int ChanseSumm = 0;
            int FirstRare = 1;
            eItems_CrateItem itemTest;
            eItems_GetCrateItemByCrateNum(g_iTempCaseNum[iClient], 0, itemTest, sizeof(itemTest));
            FirstRare = eItems_GetSkinRarity(itemTest.SkinDefIndex);
            do
            {
                if(FirstRare == 1)
                {
                    ChanseSumm += ConfigCases[iClient].GetNum(NULL_STRING);
                    hArrayChanse.Push(ChanseSumm);
                }
                else FirstRare--;
            } while(ConfigCases[iClient].GotoNextKey(false));

            if(g_iClientWinSkinNum[iClient] == -1)
            {
                int RandomChanse = GetRandomInt(1, ChanseSumm);
                int Result = -1;

                for(int i = 0; i < hArrayChanse.Length; i++)
                {
                    if(hArrayChanse.Get(i) >= RandomChanse)
                    {
                        Result = i+(8-hArrayChanse.Length);
                        break;
                    }
                }

                if(Result != -1)
                {
                    ArrayList hArrayItems = new ArrayList(2);
                    if(Result == 7)
                    {
                        for(int i = 0; i < g_iWeaponsCount; i++)
                        {
                            if(eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(i)))
                            {
                                int index = hArrayItems.Length;
                                ArrayList hTempArray = new ArrayList(1);
                                for(int g = 0; g < g_iPaintsCount; g++)
                                {
                                    if(eItems_IsNativeSkin(g, i, ITEMTYPE_WEAPON))
                                    {
                                        hTempArray.Push(eItems_GetSkinDefIndexBySkinNum(g));
                                    }
                                }
                                if(hTempArray.Length>0)
                                {
                                    hArrayItems.Push(eItems_GetWeaponDefIndexByWeaponNum(i));
                                    int RandomSkin = GetRandomInt(0, hTempArray.Length-1);
                                    int SelectedSkin = hTempArray.Get(RandomSkin);
                                    hArrayItems.Set(index, SelectedSkin, 1);
                                }
                            }
                        }
                    }
                    else
                    {
                        for(int i = 0; i < eItems_GetCrateItemsCountByCrateNum(g_iTempCaseNum[iClient]); i++)
                        {
                            eItems_CrateItem item;
                            eItems_GetCrateItemByCrateNum(g_iTempCaseNum[iClient], i, item, sizeof(item));
                            if(Result == eItems_GetSkinRarity(item.SkinDefIndex))
                            {
                                int index = hArrayItems.Length;
                                hArrayItems.Push(item.WeaponDefIndex);
                                hArrayItems.Set(index, item.SkinDefIndex, 1);
                            }
                        }
                    }
                    int RandomSkin = GetRandomInt(0, hArrayItems.Length-1);
                    g_iClientWinWeaponDefIndPre[iClient] = hArrayItems.Get(RandomSkin);
                    g_iClientWinSkinNumPre[iClient] = hArrayItems.Get(RandomSkin, 1);
                }
            }
            else
            {
                g_iClientWinSkinNumPre[iClient] = g_iClientWinSkinNum[iClient];
                g_iClientWinWeaponDefIndPre[iClient] = g_iClientWinWeaponDefInd[iClient];
            }
            if(g_iClientWinSkinNumPost[iClient] == -1)
            {
                int RandomChanse = GetRandomInt(1, ChanseSumm);
                int Result = -1;

                for(int i = 0; i < hArrayChanse.Length; i++)
                {
                    if(hArrayChanse.Get(i) >= RandomChanse)
                    {
                        Result = i+(8-hArrayChanse.Length);
                        break;
                    }
                }

                if(Result != -1)
                {
                    ArrayList hArrayItems = new ArrayList(2);
                    if(Result == 7)
                    {
                        for(int i = 0; i < g_iWeaponsCount; i++)
                        {
                            if(eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(i)))
                            {
                                int index = hArrayItems.Length;
                                ArrayList hTempArray = new ArrayList(1);
                                for(int g = 0; g < g_iPaintsCount; g++)
                                {
                                    if(eItems_IsNativeSkin(g, i, ITEMTYPE_WEAPON))
                                    {
                                        hTempArray.Push(eItems_GetSkinDefIndexBySkinNum(g));
                                    }
                                }
                                if(hTempArray.Length>0)
                                {
                                    hArrayItems.Push(eItems_GetWeaponDefIndexByWeaponNum(i));
                                    int RandomSkin = GetRandomInt(0, hTempArray.Length-1);
                                    int SelectedSkin = hTempArray.Get(RandomSkin);
                                    hArrayItems.Set(index, SelectedSkin, 1);
                                }
                            }
                        }
                    }
                    else
                    {
                        for(int i = 0; i < eItems_GetCrateItemsCountByCrateNum(g_iTempCaseNum[iClient]); i++)
                        {
                            eItems_CrateItem item;
                            eItems_GetCrateItemByCrateNum(g_iTempCaseNum[iClient], i, item, sizeof(item));
                            if(Result == eItems_GetSkinRarity(item.SkinDefIndex))
                            {
                                int index = hArrayItems.Length;
                                hArrayItems.Push(item.WeaponDefIndex);
                                hArrayItems.Set(index, item.SkinDefIndex, 1);
                            }
                        }
                    }
                    int RandomSkin = GetRandomInt(0, hArrayItems.Length-1);
                    g_iClientWinWeaponDefInd[iClient] = hArrayItems.Get(RandomSkin);
                    g_iClientWinSkinNum[iClient] = hArrayItems.Get(RandomSkin, 1)
                }
            }
            else
            {
                g_iClientWinSkinNum[iClient] = g_iClientWinSkinNumPost[iClient];
                g_iClientWinWeaponDefInd[iClient] = g_iClientWinWeaponDefIndPost[iClient];
            }
            int RandomChanse = GetRandomInt(1, ChanseSumm);
            int Result = -1;

            for(int i = 0; i < hArrayChanse.Length; i++)
            {
                if(hArrayChanse.Get(i) >= RandomChanse)
                {
                    Result = i+(8-hArrayChanse.Length);
                    break;
                }
            }

            if(Result != -1)
            {
                ArrayList hArrayItems = new ArrayList(2);
                if(Result == 7)
                {
                    for(int i = 0; i < g_iWeaponsCount; i++)
                    {
                        if(eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(i)))
                        {
                            int index = hArrayItems.Length;
                            ArrayList hTempArray = new ArrayList(1);
                            for(int g = 0; g < g_iPaintsCount; g++)
                            {
                                if(eItems_IsNativeSkin(g, i, ITEMTYPE_WEAPON))
                                {
                                    hTempArray.Push(eItems_GetSkinDefIndexBySkinNum(g));
                                }
                            }
                            if(hTempArray.Length>0)
                            {
                                hArrayItems.Push(eItems_GetWeaponDefIndexByWeaponNum(i));
                                int RandomSkin = GetRandomInt(0, hTempArray.Length-1);
                                int SelectedSkin = hTempArray.Get(RandomSkin);
                                hArrayItems.Set(index, SelectedSkin, 1);
                            }
                        }
                    }
                }
                else
                {
                    for(int i = 0; i < eItems_GetCrateItemsCountByCrateNum(g_iTempCaseNum[iClient]); i++)
                    {
                        eItems_CrateItem item;
                        eItems_GetCrateItemByCrateNum(g_iTempCaseNum[iClient], i, item, sizeof(item));
                        if(Result == eItems_GetSkinRarity(item.SkinDefIndex))
                        {
                            int index = hArrayItems.Length;
                            hArrayItems.Push(item.WeaponDefIndex);
                            hArrayItems.Set(index, item.SkinDefIndex, 1);
                        }
                    }
                }
                int RandomSkin = GetRandomInt(0, hArrayItems.Length-1);
                g_iClientWinWeaponDefIndPost[iClient] = hArrayItems.Get(RandomSkin);
                g_iClientWinSkinNumPost[iClient] = hArrayItems.Get(RandomSkin, 1)
            }
        }
    }
}

public Action CreateTables(Handle timer, any data)
{
    Database db = WGKS_GetDatabase();
    char dbIdentifier[10];

    db.Driver.GetIdentifier(dbIdentifier, sizeof(dbIdentifier));
    bool mysql = StrEqual(dbIdentifier, "mysql");
    
    char createQuery[1024];
    Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS wgks_cases (steamid varchar(32) NOT NULL PRIMARY KEY, cases text(512) NULL)");
    if(mysql)
    {
        Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
    }
    db.Query(CreateTableCallback, createQuery, _, DBPrio_High);
    delete db;
}

public void SQL_VoidCallback(Database database, DBResultSet results, const char[] error, any data)
{
    if(error[0])
    {
        LogError("[SQL_VoidCallback] Error %s", error);
    }
}

public void CreateTableCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if(error[0])
    {
        LogError("[Cases] Create table failed! %s", error);
    }
}

public void OnClientDisconnect(int iClient)
{
    ResetClient(iClient, true, true);
}

void LoadConfig(int iClient)
{
    ConfigCases[iClient] = new KeyValues("Cases");
    char szBuffer[256];
    BuildPath(Path_SM, szBuffer,256, "configs/wgks/cases.txt");
    ConfigCases[iClient].ImportFromFile(szBuffer);
}

void ResetClient(int iClient, bool Full = false, bool SuperFull = false)
{
    if(Full)
    {
        g_iClientWinSkinNumPre[iClient] = -1;
        g_iClientWinWeaponDefIndPre[iClient] = -1;
        g_iClientWinSkinNum[iClient] = -1;
        g_iClientWinWeaponDefInd[iClient] = -1;
        g_iClientWinSkinNumPost[iClient] = -1;
        g_iClientWinWeaponDefIndPost[iClient] = -1;

        if(g_hTimerCase[iClient] != INVALID_HANDLE)
        {
            KillTimer(g_hTimerCase[iClient]);
            g_hTimerCase[iClient] = INVALID_HANDLE;
        }
        iClientTimerCount[iClient] = 0;
    }
    if(SuperFull)
    {
        iClientInstantlyOpen[iClient] = false;
        g_sClientCases[iClient] = "";
    }
}