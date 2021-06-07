void StripHtml(const char[] source, char[] output, int size)
{
    int start, end;
    strcopy(output, size, source);
    while((start = StrContains(output, ">")) > 0)
    {
        strcopy(output, size, output[start+1]);
        if((end = StrContains(output, "<")) > 0)
        {
            output[end] = '\0';
        }
    }
}

void CleanNameTag(char[] nameTag, int size)
{
    ReplaceString(nameTag, size, "%", "％");
    while(StrContains(nameTag, "  ") > -1)
    {
        ReplaceString(nameTag, size, "  ", " ");
    }
    StripQuotes(nameTag);
}

int GetTotalKnifeStatTrakCount(int client)
{
    int count = 0;
    for (int i = 0; i < g_iWeaponsCount; i++)
    {
        if (eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(i)))
        {
            //count += g_iStatTrakCount[client][i];
            count += g_PlayerWeapon[client][i].Weapon.StatTrakCount;
        }
    }
    return count;
}

bool IsWarmUpPeriod()
{
    return view_as<bool>(GameRules_GetProp("m_bWarmupPeriod"));
}

bool ClientHaveSkin(int iClient, int index, int skinid)
{
    if(!StrEqual(g_PlayerWeapon[iClient][index].Weapon.Skins, ""))
    {
        char sTempArray[256][4];
        ExplodeString(g_PlayerWeapon[iClient][index].Weapon.Skins, ";", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));
        
        //LogToFile("addons/sourcemod/logs/wgks_cases_debug.txt", "%N: weapon = %s %s", iClient, weaponName, g_sSkins[iClient][index]);
        char sSkinId[32];
        IntToString(skinid, sSkinId, sizeof(sSkinId));
        
        for(int i = 0; i<sizeof(sTempArray); i++)
        {
            //LogToFile("addons/sourcemod/logs/wgks_cases_debug.txt", "%N: %s", iClient, sTempArray[i]);
            if(StrEqual(sSkinId, sTempArray[i]))
            {
                //LogToFile("addons/sourcemod/logs/wgks_cases_debug.txt", "%N: TRUE", iClient);
                return true;
            }
        }
    }
    return false;
}

int GetClientSkinCount(int iClient, int index, int skinid)
{
    int iCount = 0;
    //if(!StrEqual(g_sSkins[iClient][index], ""))
    if(!StrEqual(g_PlayerWeapon[iClient][index].Weapon.Skins, ""))
    {
        char sTempArray[256][4];
        //ExplodeString(g_sSkins[iClient][index], ";", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));
        ExplodeString(g_PlayerWeapon[iClient][index].Weapon.Skins, ";", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));
        
        char sSkinId[32];
        IntToString(skinid, sSkinId, sizeof(sSkinId));
        
        for(int i = 0; i<sizeof(sTempArray); i++)
        {
            if(StrEqual(sSkinId, sTempArray[i]))
                iCount++;
        }
    }
    return iCount;
}

bool ClientHaveSkins(int iClient, int index)
{
    if(!StrEqual(g_PlayerWeapon[iClient][index].Weapon.Skins, ""))
        return true;
    else
        return false;
}

void GiveClientSkin(int iClient, int weapon, int skinIndex)
{
    if(IsValidClient(iClient))
    {
        char steamid[32];
        if(GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            DataPack data = new DataPack();
            data.WriteCell(iClient);
            data.WriteCell(weapon);
            data.WriteCell(skinIndex);
            data.Reset();
            
            char query[512];
            Format(query, sizeof(query), "SELECT skins FROM %sweapons WHERE steamid = '%s' AND weaponindex = %i;", g_TablePrefix, steamid, weapon);
            g_hDatabase.Query(SQLCallback_GiveClientSkinSelect, query, data);
        }
    }
}

public void SQLCallback_GiveClientSkinSelect(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (error[0])
    {
        LogError("[SQLCallback_GiveClientSkinSelect] Error (%i): %s", data, error);
        return;
    }

    int iClient = data.ReadCell();
    int weapon = data.ReadCell();
    int skinIndex = data.ReadCell();
    delete data;
    
    if(results.FetchRow())
    {
        char sSkins[1024];
        results.FetchString(0, sSkins, sizeof(sSkins));
        
        Format(sSkins, sizeof(sSkins), "%s%i;", sSkins, skinIndex);

        Format(g_PlayerWeapon[iClient][weapon].Weapon.Skins, 1024, sSkins);
        
        char steamid[32];
        if(GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[512];
            Format(query, sizeof(query), "UPDATE %sweapons SET skins = '%s' WHERE steamid = '%s' AND weaponindex = %i;", g_TablePrefix, sSkins, steamid, weapon);
            g_hDatabase.Query(SQLCallback_Void, query, data);
        }
    }
    else
    {
        Format(g_PlayerWeapon[iClient][weapon].Weapon.Skins, 1024, "%i;", skinIndex);

        char steamid[32];
        if(GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[512];
            Format(query, sizeof(query), "INSERT INTO `%sweapons`(`steamid`, `weaponindex`, `skins`) VALUES ('%s', %i, '%i;');", g_TablePrefix, steamid, weapon, skinIndex);
            g_hDatabase.Query(SQLCallback_Void, query, data);
        }
    }
}

void GiveClientGloves(int iClient, int skinIndex)
{
    if(IsValidClient(iClient))
    {
        char steamid[32];
        if(GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[512];
            
            Format(g_sGloves[iClient], sizeof(g_sGloves[]), "%s;%i", g_sGloves[iClient], skinIndex);
            
            //DataPack data = new DataPack();
            //data.WriteString(steamid);
            //data.WriteString(help);
            //data.Reset();
            
            //Format(query, sizeof(query), "SELECT gloves FROM %sgloves WHERE steamid = '%s';", g_TablePrefix, steamid);
            //g_hDatabase.Query(SQLCallback_GiveClientGlovesSelect, query, data);
        
            //char query[512];
            Format(query, sizeof(query), "UPDATE %sgloves SET gloves = '%s' WHERE steamid = '%s'", g_TablePrefix, g_sGloves[iClient], steamid);
            g_hDatabase.Query(SQLCallback_Void, query, iClient);
        }
    }
}

/*public void SQLCallback_GiveClientGlovesSelect(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (error[0])
    {
        LogError("[SQLCallback_GiveClientGlovesSelect] Error (%i): %s", data, error);
        return;
    }
    
    if(results.FetchRow())
    {
        char sGloves[512];
        results.FetchString(0, sGloves, sizeof(sGloves));
        char steamid[32], help[32];
        data.ReadString(steamid, sizeof(steamid));
        data.ReadString(help, sizeof(help));
        delete data;
        
        Format(sGloves, sizeof(sGloves), "%s%s", sGloves, help);
    }
}*/

bool ClientHaveGloves(int iClient, int index)
{
    if(!StrEqual(g_sGloves[iClient], ""))
    {
        char sTempArray[128][6];
        ExplodeString(g_sGloves[iClient], ";", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));

        char sGloveIndex[32];
        IntToString(index, sGloveIndex, sizeof(sGloveIndex));
        
        for(int i = 0; i<sizeof(sTempArray); i++)
        {
            if(StrEqual(sGloveIndex, sTempArray[i]))
                return true;
        }
    }
    return false;
}

public void GivePlayerGloves(int client)
{
    int playerTeam = GetClientTeam(client);
    if(g_iGloves[client][playerTeam] != 0)
    {
        int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
        if(ent != -1)
        {
            AcceptEntityInput(ent, "KillHierarchy");
        }
        FixCustomArms(client);
        ent = CreateEntityByName("wearable_item");
        if(ent != -1)
        {
            SetEntProp(ent, Prop_Send, "m_iItemIDLow", -1);
            
            SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", g_iGroup[client][playerTeam]);
            SetEntProp(ent, Prop_Send,  "m_nFallbackPaintKit", g_iGloves[client][playerTeam]);
            
            //SetEntPropFloat(ent, Prop_Send, "m_flFallbackWear", g_fFloatValue[client][playerTeam]);
            SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
            SetEntPropEnt(ent, Prop_Data, "m_hParent", client);
            if(g_bEnableWorldModel) SetEntPropEnt(ent, Prop_Data, "m_hMoveParent", client);
            SetEntProp(ent, Prop_Send, "m_bInitialized", 1);
            
            DispatchSpawn(ent);
            
            SetEntPropEnt(client, Prop_Send, "m_hMyWearables", ent);
            if(g_bEnableWorldModel) SetEntProp(client, Prop_Send, "m_nBody", 1);
        }
    }
}

stock void FixCustomArms(int client)
{
    char temp[2];
    GetEntPropString(client, Prop_Send, "m_szArmsModel", temp, sizeof(temp));
    if(temp[0])
    {
        SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
    }
}

stock bool AddMenuItemFormat(Menu menu, const char[] info, int style = ITEMDRAW_DEFAULT, const char[] format, any ...)
{
    char buffer[254];
    VFormat(buffer, sizeof(buffer), format, 5);
    return menu.AddItem(info, buffer, style);
}

void RefreshClientWeapon(int client, int index)
{
    // Validate weapon defIndex or knife.
    int defIndex = eItems_GetWeaponDefIndexByWeaponNum(index);
    if (eItems_IsDefIndexKnife(defIndex))
    {
        return;
    }

    // Get weapon classname.
    char classname[MAX_LENGTH_CLASSNAME];
    if (!eItems_GetWeaponClassNameByWeaponNum(index, classname, sizeof(classname)))
    {
        return;
    }

    int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
    for (int i = 0; i < size; i++)
    {
        int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
        if (eItems_IsValidWeapon(weapon))
        {
            int temp = eItems_GetWeaponNumByWeapon(weapon);
            if (temp == index)
            {
                eItems_RespawnWeapon(client, weapon);
                break;
            }
        }
    }
}

void RefreshWeapon(int client, int index)
{    
    bool HaveWeapon, Knife = false;

    if(index == -1)
    {
        eItems_RemoveKnife(client);
        HaveWeapon = true;
        Knife = true;
    }
    else if(eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(index)))
    {
        eItems_RemoveKnife(client);
        HaveWeapon = true;
        Knife = true;
    }
    else
    {
        int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");

        for (int i = 0; i < size; i++)
        {
            int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
            if (eItems_IsValidWeapon(weapon))
            {
                if (eItems_GetWeaponNumByWeapon(weapon) == index)
                {				
                    eItems_RemoveWeapon(client, weapon);
                    HaveWeapon = true;
                    break;
                }
            }
        }
    }

    if(HaveWeapon)
    {
        if (!Knife)
        {
            char weaponClass[64];
            eItems_GetWeaponClassNameByWeaponNum(index, SZF(weaponClass));
            eItems_GiveWeapon(client, weaponClass);
        }
        else
        {
            eItems_GiveWeapon(client, "weapon_knife");
        }
    }
}