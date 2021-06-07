#include <cstrike>
#include <sdkhooks>
#include <clientprefs>
#include <wgks>
#include <eItems>

int g_iChanseToWin, g_iMaxChanse, g_iMaxWin, g_iClientWin[MAXPLAYERS+1], g_iMinClient;
ArrayList g_hArrayChanse;
char g_sLogFile[PLATFORM_MAX_PATH];
bool g_bLog;

public Plugin myinfo = 
{
    name = "[WGKS] MapEnd Random",
    author = "Faust",
    version = "1.1"
}

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("This plugin works only on CS:GO");
	}

    g_hArrayChanse = new ArrayList(3);
    HookEvent("cs_win_panel_match", EventCSWIN_Panel);
    LoadConfig();
}

public void LoadConfig()
{
    char szBuffer[1024]; 
    BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/wgks/mapend_random.cfg");

    KeyValues hKeyValues = new KeyValues("MapEnd_Random");

    if (!hKeyValues.ImportFromFile(szBuffer))
    {
        SetFailState("Не удалось открыть файл %s", szBuffer);
        return;
    }

    g_iChanseToWin = hKeyValues.GetNum("chanse_to_win", 0);
    g_iMinClient = hKeyValues.GetNum("min_client", 4);
    g_iMaxWin = hKeyValues.GetNum("max_win_on_client", 1);
    g_bLog = !!hKeyValues.GetNum("log", 1);
    if(g_bLog)
        BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/wgks_mapend_random.log");

    if(g_iChanseToWin < 0) 
        g_iChanseToWin = 0;
    else if(g_iChanseToWin > 100) 
        g_iChanseToWin = 100;

    if (hKeyValues.JumpToKey("chanse") && hKeyValues.GotoFirstSubKey(false))
    {
        g_hArrayChanse.Clear();

        char sIdSkin[6];
        char sTemp[64];
        char sInfo[2][32];
        int iIndex;
        int iLength;
        do
        {
            hKeyValues.GetSectionName(sIdSkin, sizeof(sIdSkin));
            hKeyValues.GetString(NULL_STRING, sTemp, sizeof sTemp);
            iLength = ExplodeString(sTemp,"-",sInfo, sizeof(sInfo),sizeof (sInfo[]));
            for(int i=0 ; i<iLength; i++)
            {
                TrimString(sInfo[i]);
            }
            g_iMaxChanse += StringToInt(sInfo[0]);
            iIndex = g_hArrayChanse.Length;
            if(iLength == 2 && StringToInt(sInfo[1]) >= 0)
            {
                g_hArrayChanse.Push(StringToInt(sInfo[1]));
                g_hArrayChanse.Set(iIndex, StringToInt(sIdSkin), 1);
                g_hArrayChanse.Set(iIndex, g_iMaxChanse, 2);
            }
        } while (hKeyValues.GotoNextKey(false));
    }
    delete hKeyValues;
}

public void EventCSWIN_Panel(Event hEvent, const char[] sName, bool bDontBroadcast)
{
    if(GetClientCount(true) >= g_iMinClient)
    {
        for(int i=1; i<=MaxClients; i++)
        {
            if(IsClientInGame(i) && !IsFakeClient(i)) 
            {
                g_iClientWin[i] = 0;
                GiveDropChanse(i);
            }
        }
    }   
}

public void GiveDropChanse(int iClient)
{
    if(GetRandomInt(1, 100) <= g_iChanseToWin && g_iClientWin[iClient] < g_iMaxWin)
    {
        g_iClientWin[iClient]++;
        int iRandomInt = GetRandomInt(1, g_iMaxChanse);
        int iResult = -1;
        for(int i = 0; i < g_hArrayChanse.Length; i++)
        {
            if(g_hArrayChanse.Get(i, 2) >= iRandomInt)
            {
                iResult = i;
                break;
            }
        }
        if(iResult != -1)
        {
            GiveDrop(iClient, g_hArrayChanse.Get(iResult, 1), g_hArrayChanse.Get(iResult, 0));
            if(g_bLog)
            {
                char szAuth[32];
                GetClientAuthId(iClient, AuthId_Engine, szAuth, sizeof szAuth, true);
                LogToFile(g_sLogFile, "Игрок %N (%s) получил id Скина: %i id Оружия: %i", iClient, szAuth, g_hArrayChanse.Get(iResult, 1), g_hArrayChanse.Get(iResult, 0));
            }
        }
        GiveDropChanse(iClient);
    }
}

public int GiveDrop(int iClient, int iSkinId, int iWeaponId)
{
    if(!IsValidClient(iClient))
    {
        return 0;
    }
    else
    {
        Weapons_GiveClientSkin(iClient, iWeaponId, eItems_GetSkinDefIndexBySkinNum(iSkinId));
        Protobuf pb = view_as<Protobuf>(StartMessageAll("SendPlayerItemDrops", USERMSG_RELIABLE));
        Protobuf entity_updates = pb.AddMessage("entity_updates");
        int itemId[2];

        itemId[0] = GetRandomInt(0, 1000000);
        itemId[1] = itemId[0];
        entity_updates.SetInt("accountid", GetSteamAccountID(iClient)); 
        entity_updates.SetInt64("itemid", itemId);
        entity_updates.SetInt("defindex", eItems_GetWeaponDefIndexByWeaponNum(iWeaponId));
        entity_updates.SetInt("paintindex", iSkinId); 
        entity_updates.SetInt("rarity", 1); 
        EndMessage();
        return 1;
    }
}