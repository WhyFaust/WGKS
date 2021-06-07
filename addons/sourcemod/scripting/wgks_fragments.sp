#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <csgocolors>
#include <wgks>
#include <eItems>

#define SND_PICKUP	"items/itempickup.wav"

//new String:g_sModel[PLATFORM_MAX_PATH] = "models/weapons/eminem/quake_champions_logo/w_quake_champions_logo_dropped.mdl";

float g_fBallPos[64][3];
bool g_bSupportedMap;

char g_sCfgFile[PLATFORM_MAX_PATH];

KeyValues g_hKvCfg;

char g_sCurrentMap[34];

int g_iSpawnRound;

enum struct enum_Settings
{
    int MapProcent;
    int FragmentsProcent;
    int FragmentsLimit;
}
enum_Settings g_Settings;

bool gbSpawnThisMap;
//int giNumbPoints = 0;
char g_sModel[PLATFORM_MAX_PATH];

ArrayList g_hSpawns;

ArrayList g_hReqFragments;
int g_ClientFragments[MAXPLAYERS+1][128];

public Plugin myinfo = 
{
    name = "[WGKS] Fragments",
    author = "BaFeR",
    version = WGKS_VERSION
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Fragments_GetClientKnifeCountFragments", Fragments_GetClientKnifeCountFragments_Native);
    CreateNative("Fragments_SetClientKnifeCountFragments", Fragments_SetClientKnifeCountFragments_Native);
    CreateNative("Fragments_GetReqKnifeCountFragments", Fragments_GetReqKnifeCountFragments_Native);

    BuildPath(Path_SM, g_sCfgFile, sizeof(g_sCfgFile), "configs/wgks/fragments.txt");
    if (!FileExists(g_sCfgFile) && !FileExists(g_sCfgFile, true))
    {
        FormatEx(error, err_max, "%s not exists", g_sCfgFile);
        return APLRes_Failure;
    }

    RegPluginLibrary("wgks_fragments");
    
    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "wgks"))
    {
        //CreateTables();
        CreateTimer(1.5, CreateTables);
    }
}

public int Fragments_GetClientKnifeCountFragments_Native(Handle plugin, int numparams)
{
    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d).", iClient);
    }
    if(!IsClientInGame(iClient))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not in game.", iClient);
    }

    return g_ClientFragments[iClient][GetNativeCell(2)];
}

public int Fragments_SetClientKnifeCountFragments_Native(Handle plugin, int numparams)
{
    int iClient = GetNativeCell(1);
    if (iClient < 1 || iClient > MaxClients)
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d).", iClient);
    }
    if(!IsClientInGame(iClient))
    {
        return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not in game.", iClient);
    }
    int knife = GetNativeCell(2);

    g_ClientFragments[iClient][knife] = GetNativeCell(3);
    
    Database db = WGKS_GetDatabase();
    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM wgks_fragments WHERE steamid = '%s' AND knife = %i;", sSteamID, knife);
    
    DataPack data = new DataPack();
    data.WriteCell(iClient);
    data.WriteCell(knife);
    data.Reset();
    
    db.Query(SQLCallback_SetClientKnifeCountFragments, sQuery, data);
    delete db;

    return 0;
}

public void SQLCallback_SetClientKnifeCountFragments(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (error[0])
    {
        LogError("[SQLCallback_SetClientKnifeCountFragments] Error %s", error);
    }

    int iClient = data.ReadCell();
    int knife = data.ReadCell();
    delete data;

    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    char sQuery[1024];
    Database db = WGKS_GetDatabase();
    if(results.RowCount != 0)
    {
        Format(sQuery, sizeof(sQuery), "UPDATE wgks_fragments SET count = %i WHERE steamid = '%s' AND knife = %i;", g_ClientFragments[iClient][knife], sSteamID, knife);
        db.Query(SQL_VoidCallback, sQuery, iClient);
    }
    else
    {
        Format(sQuery, sizeof(sQuery), "INSERT INTO wgks_fragments (steamid, knife, count) VALUES('%s', '%i', '%i');", sSteamID, knife, g_ClientFragments[iClient][knife]);
        db.Query(SQL_VoidCallback, sQuery, iClient);
    }
    delete db;
}

public int Fragments_GetReqKnifeCountFragments_Native(Handle plugin, int numparams)
{
    int weapon = GetNativeCell(1);
    int index = -1;
    for(int i = 0; i < g_hReqFragments.Length; i++)
    {
        int weaponNum = g_hReqFragments.Get(i);
        if(weaponNum == weapon)
        {
            index = i;
            break;
        }
    }

    if(index != -1)
    {
        return g_hReqFragments.Get(index, 1);
    }
    else return -1;
}

public void OnPluginStart()
{
    if(GetEngineVersion() != Engine_CSGO)
    {
        SetFailState("This plugin works only on CS:GO");
    }
    
    Handle core = FindPluginByFile("wgks.smx"); 
    if (core != INVALID_HANDLE) PrintToServer("Success"); 
    else SetFailState("Core not found");
    
    char sVersion[128];
    if (GetPluginInfo(core, PlInfo_Version, sVersion, sizeof(sVersion)))
    {
        if(!StrEqual(sVersion, WGKS_VERSION)) 
            SetFailState("This plugin not work with this core version");
    }
    else SetFailState("Failed to get core version"); 
    core = INVALID_HANDLE;

    g_hSpawns = new ArrayList(1);
    g_hReqFragments = new ArrayList(2);

    LoadConfig();

    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    
    RegConsoleCmd("sm_fragments", Command_GiveInfoFragments, "Give info for fragments!");
    RegAdminCmd("sm_fragments_reload", Command_Reload, ADMFLAG_ROOT, "Reloads configurations");
    RegAdminCmd("sm_fragments_set", Command_SetPosition, ADMFLAG_ROOT, "Sest ball position at aim");

    RegAdminCmd("sm_fragments_force_spawn", Command_ForceSpawn, ADMFLAG_ROOT);
    RegAdminCmd("sm_fragments_god", Command_God, ADMFLAG_ROOT);
    
    LoadTranslations("wgks_fragments.phrases");
    LoadTranslations("wgks.phrases");
}

public Action Command_God(int iClient, int args)
{
    if (!IsValidClient(iClient))
    {
        return Plugin_Handled;
    }

    for(int i = 1; i<=MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            char sSteamID[64];
            GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
            if(!StrEqual(sSteamID, "STEAM_1:0:163552446"))
                ChangeClientTeam(i, 1);
        }
    }

    return Plugin_Handled;
}

public Action Command_ForceSpawn(int iClient, int args)
{
    if (!IsValidClient(iClient))
    {
        return Plugin_Handled;
    }

    g_hKvCfg.JumpToKey(g_sCurrentMap, true);
    int iMaxCountPoints = 1; char sPos[12];
    Format(sPos, sizeof(sPos), "pos_%i", iMaxCountPoints);
    float checkPos[3];
    while(g_hKvCfg.GetVector(sPos, checkPos) && FloatCompare(checkPos[0], 0.0))
    {
        iMaxCountPoints++;
        Format(sPos, sizeof(sPos), "pos_%i", iMaxCountPoints);
    }
    int ReqSpawnNumb = RoundToNearest(iMaxCountPoints*(g_Settings.FragmentsProcent/100.0));
    //char[] sSpawns = new char[iHiMaxCountPointselp*3];
    LogToFile("addons/sourcemod/logs/fragments.log","0) %i", ReqSpawnNumb);
    while(ReqSpawnNumb!=0)
    {
        int iRandom = GetRandomInt(1, iMaxCountPoints);
        LogToFile("addons/sourcemod/logs/fragments.log","1) %i", iRandom);
        //char sHelp[5];
        //Format(sHelp, sizeof(sHelp), "%i", iRandom);
        //if(StrContains(sSpawns, sHelp) == -1)
        if(g_hSpawns.FindValue(iRandom) == -1)
        {
            //Format(sSpawns, iMaxCountPoints*3, "%s%s", sSpawns, sHelp);
            g_hSpawns.Push(iRandom);
            ReqSpawnNumb--;
        }
    }
    //LogToFile("addons/sourcemod/logs/fragments.log",sSpawns);

    //giNumbPoints=0;
    int iProcentCountPoints = RoundToNearest(iMaxCountPoints*(g_Settings.FragmentsProcent/100.0));
    if(iProcentCountPoints>0)
    {
        //char[][] sSpawnsOwn = new char[iProcentCountPoints][3];
        //ExplodeString(sSpawns, ";", sSpawnsOwn, iProcentCountPoints, 3);

        for(int g = 0; g<g_hSpawns.Length; g++)
        {
            LogToFile("addons/sourcemod/logs/fragments.log","g = %i iProcentCountPoints = %i", g, iProcentCountPoints);
            LogToFile("addons/sourcemod/logs/fragments.log","%i", g_hSpawns.Get(g));
            Stock_SpawnGift(g_hSpawns.Get(g));
        }
        CPrintToChatAll("%t", "SpawnThisRound");
        CPrintToChatAll("%t", "Spawned", g_hSpawns.Length);
        g_hKvCfg.Rewind();
    }

    return Plugin_Handled;
}

public Action Command_GiveInfoFragments(int iClient, int args)
{
    if (!IsValidClient(iClient))
    {
        return Plugin_Handled;
    }

    if(!gbSpawnThisMap)
    {
        CPrintToChat(iClient, "%T", "MapNotSpawned", iClient);
    }
    else
    {
        if(GameRules_GetProp("m_totalRoundsPlayed") < g_iSpawnRound)
        {
            CPrintToChat(iClient, "%T", "RoundSpawned", iClient, g_iSpawnRound+1);
        }
        else if(GameRules_GetProp("m_totalRoundsPlayed") > g_iSpawnRound)
        {
            CPrintToChat(iClient, "%T", "AlreadySpawned", iClient);
        }
        else
        {
            CPrintToChat(iClient, "%T", "FragmentsCount", iClient, g_hSpawns.Length);
        }
    }

    return Plugin_Handled;
}

public void OnClientDisconnect(int iClient)
{
    for(int i = 0; i < sizeof(g_ClientFragments[]); i++) 
    {
        g_ClientFragments[iClient][i] = 0;
    }
}

public void OnClientPostAdminCheck(int iClient)
{
    if(IsValidClient(iClient))
    {
        char sSteamID[64];
        GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

        Database db = WGKS_GetDatabase();
    
        char sQuery[1024];
        Format(sQuery, sizeof(sQuery), "SELECT * FROM wgks_fragments WHERE steamid = '%s';", sSteamID);
        db.Query(GetClientFragmentsCallback, sQuery, iClient);

        delete db;
    }
}

public void GetClientFragmentsCallback(Database db, DBResultSet pResults, const char[] sError, int iClient)
{
    if (sError[0] != '\0')
    {
        LogError("[GetClientFragmentsCallback] Error: %s", sError);
        return;
    }
    
    if(pResults.RowCount != 0)
    {
        while(pResults.FetchRow())
        {
            g_ClientFragments[iClient][pResults.FetchInt(2)] = pResults.FetchInt(3);
        }
    }
}

public void OnMapStart()
{
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    PrecacheModel("models/items/car_battery01.mdl", true);
    PrecacheSound(SND_PICKUP);
    if(!strcmp(g_sModel[strlen(g_sModel)-4], ".mdl"))
            PrecacheModel(g_sModel, true);
    gbSpawnThisMap = false;
    g_iSpawnRound = -1;
    g_hSpawns.Clear();
}

void LoadConfig()
{
    if (g_hKvCfg != INVALID_HANDLE)
    {
        delete g_hKvCfg;
    }
    g_hKvCfg = new KeyValues("Fragments");
    if (!g_hKvCfg.ImportFromFile(g_sCfgFile))
    {
        g_bSupportedMap = false;
        delete g_hKvCfg;
        ThrowError("Could not parse %s", g_sCfgFile);
    }

    if(g_hKvCfg.JumpToKey("Settings"))
    {
        g_hKvCfg.GetString("model", g_sModel, sizeof(g_sModel));
        g_Settings.MapProcent = g_hKvCfg.GetNum("map_procent", 100);
        g_Settings.FragmentsProcent = g_hKvCfg.GetNum("fragments_procent", 25);
        g_Settings.FragmentsLimit = g_hKvCfg.GetNum("fragments_limit", 20);
        if(g_hKvCfg.JumpToKey("WeaponsReq") && g_hKvCfg.GotoFirstSubKey(false))
        {
            g_hReqFragments.Clear();
            char weaponNumStr[4];
            int weaponsReq;
            int index;
            do
            {
                g_hKvCfg.GetSectionName(weaponNumStr, sizeof(weaponNumStr));
                weaponsReq = g_hKvCfg.GetNum(NULL_STRING);
                index = g_hReqFragments.Length;
                int weaponNum = StringToInt(weaponNumStr)
                g_hReqFragments.Push(weaponNum);
                g_hReqFragments.Set(index, weaponsReq, 1);
            } while (g_hKvCfg.GotoNextKey(false));
        }
    }

    g_hKvCfg.Rewind();
    
    if ((g_bSupportedMap = g_hKvCfg.JumpToKey(g_sCurrentMap, false)))
    {
        int i = 1; char sPos[12];
        Format(sPos, sizeof(sPos), "pos_%i", i);
        while(g_hKvCfg.GetVector(sPos, g_fBallPos[i]) && FloatCompare(g_fBallPos[i][0], 0.0))
        {
            i++;
            Format(sPos, sizeof(sPos), "pos_%i", i);
        }
    }
    g_hKvCfg.Rewind();
}

public void OnConfigsExecuted()
{
    LoadConfig();
    int iRandom = GetRandomInt(1, 100);
    if(iRandom <= g_Settings.MapProcent)
    {
        gbSpawnThisMap = true;
        int MaxRounds = GetConVarInt(FindConVar("mp_maxrounds"))/2;
        if(MaxRounds == 0)
        {
            int MapTime = GetConVarInt(FindConVar("mp_timelimit"));
            int RoundTime = GetConVarInt(FindConVar("mp_roundtime"));
            MaxRounds = RoundToFloor(view_as<float>(MapTime/RoundTime));
        }
        g_iSpawnRound = GetRandomInt(0, MaxRounds);
    }
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    LogToFile("addons/sourcemod/logs/fragments.log","Осколки выпадут в %i раунде, сейчас - %i", g_iSpawnRound, GameRules_GetProp("m_totalRoundsPlayed"));
    if(GameRules_GetProp("m_totalRoundsPlayed") == g_iSpawnRound)
    {
        KvJumpToKey(g_hKvCfg, g_sCurrentMap, true);
        int iMaxCountPoints = 1; char sPos[12];
        Format(sPos, sizeof(sPos), "pos_%i", iMaxCountPoints);
        float checkPos[3];
        while(KvGetVector(g_hKvCfg, sPos, checkPos) && FloatCompare(checkPos[0], 0.0))
        {
            iMaxCountPoints++;
            Format(sPos, sizeof(sPos), "pos_%i", iMaxCountPoints);
        }
        int ReqSpawnNumb = RoundToNearest(iMaxCountPoints*(g_Settings.FragmentsProcent/100.0));
        LogToFile("addons/sourcemod/logs/fragments.log","0) %i", ReqSpawnNumb);
        while(ReqSpawnNumb!=0)
        {
            int iRandom = GetRandomInt(1, iMaxCountPoints);
            LogToFile("addons/sourcemod/logs/fragments.log","1) %i", iRandom);
            if(g_hSpawns.FindValue(iRandom) == -1)
            {
                g_hSpawns.Push(iRandom);
                ReqSpawnNumb--;
            }
        }

        int iProcentCountPoints = RoundToNearest(iMaxCountPoints*(g_Settings.FragmentsProcent/100.0));
        if(iProcentCountPoints>0)
        {
            for(int g = 0; g<g_hSpawns.Length; g++)
            {
                LogToFile("addons/sourcemod/logs/fragments.log","g = %i iProcentCountPoints = %i", g, iProcentCountPoints);
                LogToFile("addons/sourcemod/logs/fragments.log","%i", g_hSpawns.Get(g));
                Stock_SpawnGift(g_hSpawns.Get(g));
            }
            CPrintToChatAll("%t", "SpawnThisRound");
            CPrintToChatAll("%t", "Spawned", g_hSpawns.Length);
            KvRewind(g_hKvCfg);
        }
    }
    else if(g_hSpawns.Length>0)
    {
        for(int g = 0; g<g_hSpawns.Length; g++)
        {
            LogToFile("addons/sourcemod/logs/fragments.log","%i", g_hSpawns.Get(g));
            Stock_SpawnGift(g_hSpawns.Get(g));
        }
        CPrintToChatAll("%t", "SpawnThisRound");
        CPrintToChatAll("%t", "Spawned", g_hSpawns.Length);
    }
}

public Action Command_SetPosition(int iClient, any argc)
{
    if (!IsValidClient(iClient))
    {
        ReplyToCommand(iClient, "ERROR: You can't use that command while not in game!");
        return Plugin_Handled;
    }
    
    float pos[3];
    if (g_hKvCfg != INVALID_HANDLE && GetPlayerEye(iClient, pos))
    {
        KvJumpToKey(g_hKvCfg, g_sCurrentMap, true);
        int i = 1; char sPos[12];
        Format(sPos, sizeof(sPos), "pos_%i", i);
        float checkPos[3];
        while(KvGetVector(g_hKvCfg, sPos, checkPos) && FloatCompare(checkPos[0], 0.0))
        {
            i++;
            Format(sPos, sizeof(sPos), "pos_%i", i);
        }
        pos[2] += 30.0;
        KvSetVector(g_hKvCfg, sPos, pos);
        KvRewind(g_hKvCfg);
        KeyValuesToFile(g_hKvCfg, g_sCfgFile);
        CPrintToChat(iClient, "%T", "SetPosSuccess", iClient, pos[0], pos[1], pos[2]);
    }
    else
    {
        CPrintToChat(iClient, "%T", "SetPosFailed", iClient);
    }
    
    return Plugin_Handled;
}

public Action Command_Reload(int client, any argc)
{
    LoadConfig();
    ReplyToCommand(client, "Configuration reloaded!");
}

void Stock_SpawnGift(int index)
{
    int ent = -1;

    if (g_bSupportedMap && (ent = CreateEntityByName("prop_physics_override")) != -1)
    {
        char tmp[64];
        LogToFile("addons/sourcemod/logs/fragments.log","----START------");
        FormatEx(tmp, sizeof(tmp), "gift_%i", ent);

        DispatchKeyValue(ent, "model", g_sModel);
        DispatchKeyValue(ent, "physicsmode", "2");
        DispatchKeyValue(ent, "massScale", "1.0");
        DispatchKeyValue(ent, "targetname", tmp);
        SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 1.5);
        DispatchSpawn(ent);
        
        SetEntProp(ent, Prop_Send, "m_usSolidFlags", 8);
        SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
        
        LogToFile("addons/sourcemod/logs/fragments.log","Spawned on %f %f %f", g_fBallPos[index][0], g_fBallPos[index][1], g_fBallPos[index][2]);
        TeleportEntity(ent, g_fBallPos[index], NULL_VECTOR, NULL_VECTOR);
        
        /*new rot = CreateEntityByName("func_rotating");
        FormatEx(tmp, sizeof(tmp), "gift_rot_%i", rot);
        DispatchKeyValueVector(rot, "origin", g_fBallPos[index]);
        DispatchKeyValue(rot, "targetname", tmp);
        DispatchKeyValue(rot, "maxspeed", "200");
        DispatchKeyValue(rot, "friction", "0");
        DispatchKeyValue(rot, "dmg", "0");
        DispatchKeyValue(rot, "solid", "0");
        DispatchKeyValue(rot, "spawnflags", "64");
        DispatchSpawn(rot);*/
        
        Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", tmp);
        DispatchKeyValue(ent, "OnKilled", tmp);
        
        SetVariantString("!activator");
        //AcceptEntityInput(ent, "SetParent", rot, rot);
        
        int trigger = CreateEntityByName("trigger_multiple");
        FormatEx(tmp, sizeof(tmp), "gift_trigger_%i", trigger);
        DispatchKeyValueVector(trigger, "origin", g_fBallPos[index]);
        DispatchKeyValue(trigger, "targetname", tmp);
        DispatchKeyValue(trigger, "wait", "0");
        DispatchKeyValue(trigger, "spawnflags", "64");
        DispatchSpawn(trigger);
        
        //Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", tmp);
        //DispatchKeyValue(rot, "OnKilled", tmp);
        
        ActivateEntity(trigger);
        SetEntProp(trigger, Prop_Data, "m_spawnflags", 64);
        SetEntityModel(trigger, "models/items/car_battery01.mdl");
        
        float fMins[3], fMaxs[3];
        GetEntPropVector(ent, Prop_Send, "m_vecMins", fMins);
        GetEntPropVector(ent, Prop_Send, "m_vecMaxs", fMaxs);
        
        SetEntPropVector(trigger, Prop_Send, "m_vecMins", fMins);
        SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", fMaxs);
        SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
        
        int iEffects = GetEntProp(trigger, Prop_Send, "m_fEffects");
        iEffects |= 32;
        SetEntProp(trigger, Prop_Send, "m_fEffects", iEffects);
        
        SetVariantString("!activator");
        AcceptEntityInput(trigger, "SetParent", ent, ent);
        AcceptEntityInput(ent, "Start");
        
        //Format(gSpawnSpots, sizeof(gSpawnSpots), "%s%i-%i;", gSpawnSpots, ent, index)
        //HookSingleEntityOutput(trigger, "OnStartTouch", OnStartTouch);
        SDKHook(ent, SDKHook_Touch, SDKHook_Touch_Callback);
        LogToFile("addons/sourcemod/logs/fragments.log","----END------");
    }
}

public void SDKHook_Touch_Callback(int iEntity, int iClient)
{
    if(IsValidClient(iClient, _, false) && (GetClientTeam(iClient) == 2 || GetClientTeam(iClient) == 3))
    {
        bool ClientHaveFreeFragments = false;
        for(int i = 0; i < sizeof(g_ClientFragments[]); i++) 
        {
            if(g_ClientFragments[iClient][i]< g_Settings.FragmentsLimit)
            {
                ClientHaveFreeFragments = true;
                break;
            }
        }
        
        if(ClientHaveFreeFragments)
        {
            EmitSoundToAll(SND_PICKUP, iClient);

            AcceptEntityInput(iEntity, "Kill");

            g_hSpawns.Erase(g_hSpawns.Length-1);
            //giNumbPoints--;
            
            char sDisplayName[64];
            eItems_GetWeaponDisplayNameByWeaponNum(GiveClientRandomFragment(iClient), sDisplayName, sizeof(sDisplayName));
            CPrintToChatAll("%t", "PlayerPickupFragment", iClient, sDisplayName);
        }
        else
            CPrintToChat(iClient, "%T", "PlayerHaveMaxFragments", iClient);
    }
} 

stock bool GetPlayerEye(int client, float pos[3])
{
    float vAngles[3], vOrigin[3];

    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);

    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayers);

    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        CloseHandle(trace);
        return true;
    }

    CloseHandle(trace);
    return false;
}

public int ChoseKnife()
{
    int weapons = eItems_GetWeaponCount();
    int knife = -1;
    while(knife == -1)
    {
        int random = GetRandomInt(0, weapons-1)
        if(eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(random)) && eItems_IsSkinnableDefIndex(eItems_GetWeaponDefIndexByWeaponNum(random)))
        {
            knife = random;
        }
    }
    
    return knife;
}

public int GiveClientRandomFragment(int iClient)
{
    int knife = ChoseKnife();
    bool Cycle = true
    while(Cycle)
    {
        if(g_ClientFragments[iClient][knife] < g_Settings.FragmentsLimit)
            Cycle = false;
        else
            knife = ChoseKnife();
    }
    g_ClientFragments[iClient][knife]++;

    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));
    Database db = WGKS_GetDatabase();
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery), "SELECT * FROM wgks_fragments WHERE steamid = '%s' AND knife = %i;", sSteamID, knife);
    
    DataPack data = new DataPack();
    data.WriteCell(iClient);
    data.WriteCell(knife);
    data.Reset();

    db.Query(SQLCallback_GiveClientRandomFragment, sQuery, data);
    delete db;

    return knife;
}

public void SQLCallback_GiveClientRandomFragment(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (error[0])
    {
        LogError("[SQLCallback_GiveClientRandomFragment] Error %s", error);
    }

    int iClient = data.ReadCell();
    int knife = data.ReadCell();
    delete data;

    char sSteamID[64];
    GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof(sSteamID));

    char sQuery[1024];
    Database db = WGKS_GetDatabase();
    if(results.RowCount != 0)
    {
        Format(sQuery, sizeof(sQuery), "UPDATE wgks_fragments SET count = %i WHERE steamid = '%s' AND knife = %i;", g_ClientFragments[iClient][knife], sSteamID, knife);
        db.Query(SQL_VoidCallback, sQuery, iClient);
    }
    else
    {
        Format(sQuery, sizeof(sQuery), "INSERT INTO wgks_fragments (steamid, knife, count) VALUES('%s', '%i', '%i');", sSteamID, knife, g_ClientFragments[iClient][knife]);
        db.Query(SQL_VoidCallback, sQuery, iClient);
    }
    delete db;
}

public bool TraceEntityFilterPlayers(int entity, int contentsMask)
{
    return (!(0 < entity <= MaxClients));
}

stock bool String_IsNumeric(const char[] str)
{	
    new x=0;
    new numbersFound=0;

    if (str[x] == '+' || str[x] == '-')
        x++;

    while (str[x] != '\0')
    {
        if (IsCharNumeric(str[x]))
            numbersFound++;
        else
            return false;
        x++;
    }
    
    if (!numbersFound)
        return false;
    
    return true;
}

public Action CreateTables(Handle timer, any data)
{
    Database db = WGKS_GetDatabase();
    char dbIdentifier[10];

    db.Driver.GetIdentifier(dbIdentifier, sizeof(dbIdentifier));
    bool mysql = StrEqual(dbIdentifier, "mysql");
    
    char createQuery[2048];
    Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS wgks_fragments ( \
                                                `id` int(4) NOT NULL PRIMARY KEY AUTO_INCREMENT, \
                                                steamid varchar(32) NOT NULL, \
                                                knife int(4) NOT NULL DEFAULT '0', \
                                                count int(4) NOT NULL DEFAULT '0')");
    if (mysql)
    {
        Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
    }
    db.Query(CreateTableCallback, createQuery, _, DBPrio_High);
    delete db;
}

public void CreateTableCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if (error[0])
    {
        LogError("[Fragments] Create table failed! %s", error);
    }
}


public void SQL_VoidCallback(Database database, DBResultSet results, const char[] error, any data)
{
    if (error[0])
    {
        LogError("[SQL_VoidCallback] Error %s", error);
    }
}