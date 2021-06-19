void DB_OnPluginStart()
{
    DB_Connect();
}

void DB_Connect()
{
    if (GLOBAL_INFO & IS_LOADING)
    {
        return;
    }

    if (g_hDatabase != null)
    {
        UNSET_BIT(GLOBAL_INFO, IS_LOADING);
        return;
    }
    
    SET_BIT(GLOBAL_INFO, IS_LOADING);

    if (SQL_CheckConfig("wgks"))
    {
        Database.Connect(OnDBConnect, "wgks", 0);
    }
    else
    {
        char szError[256];
        g_hDatabase = SQLite_UseDatabase("wgks", SZF(szError));
        OnDBConnect(g_hDatabase, szError, 1);
    }
}

public void OnDBConnect(Database hDatabase, const char[] szError, any data)
{
    if (hDatabase == null || szError[0])
    {
        SetFailState("OnDBConnect %s", szError);
        UNSET_BIT(GLOBAL_INFO, IS_MySQL);
        return;
    }

    g_hDatabase = hDatabase;
    
    if (data == 1)
    {
        UNSET_BIT(GLOBAL_INFO, IS_MySQL);
    }
    else
    {
        char szDriver[8];
        g_hDatabase.Driver.GetIdentifier(SZF(szDriver));

        if (strcmp(szDriver, "mysql", false) == 0)
        {
            SET_BIT(GLOBAL_INFO, IS_MySQL);
        }
        else
        {
            UNSET_BIT(GLOBAL_INFO, IS_MySQL);
        }
    }
    
    CreateTables();
}


void CreateTables()
{
    char createQuery[2048];
    if(g_bWeaponsEnable)
    {
        Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS `%sweapons` ( \
                                                `id` int(4) NOT NULL PRIMARY KEY AUTO_INCREMENT, \
                                                `steamid` varchar(64) NOT NULL, \
                                                `weaponindex` int(11) NOT NULL DEFAULT '0', \
                                                `selectedskin` int(4) NOT NULL DEFAULT '0', \
                                                `float` decimal(3,2) NOT NULL DEFAULT '0.0', \
                                                `trak` int(1) NOT NULL DEFAULT '0', \
                                                `trak_count` int(10) NOT NULL DEFAULT '0', \
                                                `tag` varchar(256) NOT NULL DEFAULT '', \
                                                `skins` text(1024) NULL)", g_TablePrefix);
        
        if (GLOBAL_INFO & IS_MySQL)
        {
            Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
        }
        
        g_hDatabase.Query(T_CreateTableCallback, createQuery, _, DBPrio_High);
    }
    if(g_bGlovesEnable)
    {
        Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS %sgloves ( \
                                                    steamid varchar(32) NOT NULL PRIMARY KEY,  \
                                                    t_group int(5) NOT NULL DEFAULT '0',  \
                                                    t_glove int(5) NOT NULL DEFAULT '0',  \
                                                    t_float decimal(3,2) NOT NULL DEFAULT '0.0',  \
                                                    ct_group int(5) NOT NULL DEFAULT '0',  \
                                                    ct_glove int(5) NOT NULL DEFAULT '0',  \
                                                    ct_float decimal(3,2) NOT NULL DEFAULT '0.0',  \
                                                    gloves text(512) NULL)", g_TablePrefix);
        
        if (GLOBAL_INFO & IS_MySQL)
        {
            Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
        }
        
        g_hDatabase.Query(T_CreateTableCallback, createQuery, _, DBPrio_High);
    }
    if(g_bStikersEnable)
    {
        Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS `%sstickers` ( \
                                                `id` int(4) NOT NULL PRIMARY KEY AUTO_INCREMENT, \
                                                `steamid` varchar(64) NOT NULL, \
                                                `weaponindex` int(11) NOT NULL DEFAULT '0', \
                                                `slot0` int(11) NOT NULL DEFAULT '0', \
                                                `slot1` int(11) NOT NULL DEFAULT '0', \
                                                `slot2` int(11) NOT NULL DEFAULT '0', \
                                                `slot3` int(11) NOT NULL DEFAULT '0', \
                                                `slot4` int(11) NOT NULL DEFAULT '0', \
                                                `slot5` int(11) NOT NULL DEFAULT '0')", g_TablePrefix);
        
        if (GLOBAL_INFO & IS_MySQL)
        {
            Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
        }
        
        g_hDatabase.Query(T_CreateTableCallback, createQuery, _, DBPrio_High);
    }
    if(g_bFragmentsLoaded)
    {
        Format(createQuery, sizeof(createQuery), "CREATE TABLE IF NOT EXISTS %sknifes ( \
                                                `id` int(4) NOT NULL PRIMARY KEY AUTO_INCREMENT, \
                                                `steamid` varchar(32) NOT NULL, \
                                                `knifeindex` int(4) NOT NULL DEFAULT '0', \
                                                `value` int(4) NOT NULL DEFAULT '0')", g_TablePrefix);
        
        if (GLOBAL_INFO & IS_MySQL)
        {
            Format(createQuery, sizeof(createQuery), "%s ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", createQuery);
        }
        
        g_hDatabase.Query(T_CreateTableCallback, createQuery, _, DBPrio_High);
    }
}

void GetPlayerData(int iClient)
{
    char steamid[32];
    if(GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true))
    {
        char query[255];
        if(g_bWeaponsEnable)
        {
            FormatEx(query, sizeof(query), "SELECT * FROM %sweapons WHERE steamid = '%s'", g_TablePrefix, steamid);
            g_hDatabase.Query(T_GetPlayerWeaponsDataCallback, query, iClient);
        }
        if(g_bGlovesEnable)
        {
            FormatEx(query, sizeof(query), "SELECT * FROM %sgloves WHERE steamid = '%s'", g_TablePrefix, steamid);
            g_hDatabase.Query(T_GetPlayerGlovesDataCallback, query, iClient);
        }
        if(g_bFragmentsLoaded)
        {
            FormatEx(query, sizeof(query), "SELECT * FROM %sknifes WHERE steamid = '%s'", g_TablePrefix, steamid);
            g_hDatabase.Query(T_GetPlayerKnifesDataCallback, query, iClient);
        }
        if(g_bStikersEnable)
        {
            FormatEx(query, sizeof(query), "SELECT * FROM %sstickers WHERE steamid = '%s'", g_TablePrefix, steamid);
            g_hDatabase.Query(T_GetPlayerStickersDataCallback, query, iClient);
        }
    }
}

public void T_GetPlayerWeaponsDataCallback(Database database, DBResultSet results, const char[] error, int iClient)
{
    if (database == null || strlen(error) > 0)
    {
        LogError("[T_GetPlayerWeaponsDataCallback] Fail at Query: %s", error);
    }
    else
    {
        if (results.RowCount > 0)
        {
            if (IsValidClient(iClient))
            {
                while (results.FetchRow())
                {
                    int weaponIndex = results.FetchInt(2);
                    if(weaponIndex == -1)
                    {
                        g_iKnife[iClient] = results.FetchInt(3);
                    }
                    else
                    {
                        g_PlayerWeapon[iClient][weaponIndex].Weapon.Skin = results.FetchInt(3);
                        g_PlayerWeapon[iClient][weaponIndex].Weapon.Float = results.FetchFloat(4);
                        g_PlayerWeapon[iClient][weaponIndex].Weapon.StatTrak = results.FetchInt(5);
                        g_PlayerWeapon[iClient][weaponIndex].Weapon.StatTrakCount = results.FetchInt(6);
                        results.FetchString(7, g_PlayerWeapon[iClient][weaponIndex].Weapon.NameTag, 128);
                        results.FetchString(8, g_PlayerWeapon[iClient][weaponIndex].Weapon.Skins, 1024);
                    }
                }
            }
        }
    }
}

public void T_GetPlayerStickersDataCallback(Database database, DBResultSet results, const char[] error, int iClient)
{
    if (database == null || strlen(error) > 0)
    {
        LogError("[T_GetPlayerStickersDataCallback] Fail at Query: %s", error);
    }
    else
    {
        if (results.HasResults)
        {
            if (IsValidClient(iClient))
            {
                while (results.FetchRow())
                {
                    // Get weapon defIndex and check if is valid to stickers.
                    int weaponIndex = results.FetchInt(2);
                    if (weaponIndex != -1)
                    {
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[0] = results.FetchInt(3);
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[1] = results.FetchInt(4);
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[2] = results.FetchInt(5);
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[3] = results.FetchInt(6);
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[4] = results.FetchInt(7);
                        g_PlayerWeapon[iClient][weaponIndex].Sticker[5] = results.FetchInt(8);
                    }
                }
            }
        }
    }
}

public void T_GetPlayerKnifesDataCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if(IsValidClient(client))
    {
        if (results == null)
        {
            LogError("Query failed! %s", error);
        }
        else if (results.RowCount != 0)
        {
            while(results.FetchRow())
            {
                g_ClientKnifeAmount[client][results.FetchInt(2)] = results.FetchInt(3);
            }
        }
    }
}

public void T_GetPlayerGlovesDataCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if(IsValidClient(client))
    {
        if (results == null)
        {
            LogError("Query failed! %s", error);
        }
        else if (results.RowCount == 0)
        {
            char steamid[32];
            GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
            char query[255];
            FormatEx(query, sizeof(query), "INSERT INTO %sgloves (steamid) VALUES ('%s')", g_TablePrefix, steamid);
            g_hDatabase.Query(SQLCallback_Void, query);
            g_iGroup[client][CS_TEAM_T] = 0;
            g_iGloves[client][CS_TEAM_T] = 0;
            //g_fFloatValue[client][CS_TEAM_T] = 0.0;
            g_iGroup[client][CS_TEAM_CT] = 0;
            g_iGloves[client][CS_TEAM_CT] = 0;
            //g_fFloatValue[client][CS_TEAM_CT] = 0.0;
        }
        else
        {
            if(results.FetchRow())
            {
                for(int i = 1, j = 2; j < 4; i += 3, j++) 
                {
                    g_iGroup[client][j] = results.FetchInt(i);
                    g_iGloves[client][j] = results.FetchInt(i + 1);
                    //g_fFloatValue[client][j] = results.FetchFloat(i + 2);
                }
                
                results.FetchString(7, g_sGloves[client], sizeof(g_sGloves[]));
            }
        }
    }
}

void UpdatePlayerGlovesData(int client, char[] updateFields)
{
    char steamid[32];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
    char query[255];
    FormatEx(query, sizeof(query), "UPDATE %sgloves SET %s WHERE steamid = '%s'", g_TablePrefix, updateFields, steamid);
    g_hDatabase.Query(T_UpdatePlayerGlovesDataCallback, query, client);
}

public void T_UpdatePlayerGlovesDataCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if (results == null)
    {
        LogError("Update Player failed! %s", error);
    }
}

public void T_CreateTableCallback(Database database, DBResultSet results, const char[] error, int client)
{
    if (results == null)
    {
        LogError("[T_CreateTableCallback] Create table failed! %s", error);
    }
    else
    {
        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientConnected(i))
            {
                OnClientPostAdminCheck(i);
            }
        }
    }
}

void StartKnifeUpdatePlayerData(int client, int knife)
{
    char steamid[32];
    if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
    {
        char query[1024];
        FormatEx(query, sizeof(query), "SELECT * FROM %sweapons WHERE `steamid` = '%s' AND `weaponindex` = -1", g_TablePrefix, steamid);
        DataPack data = new DataPack();
        data.WriteCell(client);
        data.WriteCell(knife);
        data.Reset();
        g_hDatabase.Query(KnifeUpdatePlayerData, query, data);
    }
}

public void KnifeUpdatePlayerData(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (strlen(error)>0)
    {
        LogError("[KnifeUpdatePlayerData]: %s", error);
    }
    else
    {
        int client = data.ReadCell();
        int knife = data.ReadCell();
        delete data;

        char steamid[32];
        if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[1024];
            if (results.RowCount>0)
            {
                FormatEx(query, sizeof(query), "UPDATE %sweapons SET `selectedskin` = %i WHERE `steamid` = '%s' AND `weaponindex` = -1", g_TablePrefix, knife, steamid);
                g_hDatabase.Query(SQLCallback_Void, query);
            }
            else
            {
                FormatEx(query, sizeof(query), "INSERT INTO %sweapons (`steamid`, `weaponindex`, `selectedskin`) VALUES ('%s', -1, %i)", g_TablePrefix, steamid, knife);
                g_hDatabase.Query(SQLCallback_Void, query);
            }
        }
    }
}

public void StartUpdatePlayerData(int client, char[] value)
{
    char steamid[32];
    if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
    {
        char query[1024];
        FormatEx(query, sizeof(query), "SELECT * FROM %sweapons WHERE `steamid` = '%s' AND `weaponindex` = %i", g_TablePrefix, steamid, g_iIndex[client]);
        DataPack data = new DataPack();
        data.WriteCell(client);
        data.WriteString(value);
        data.Reset();
        g_hDatabase.Query(UpdatePlayerData, query, data);
    }
}

public void UpdatePlayerData(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (strlen(error)>0)
    {
        LogError("[UpdatePlayerData]: %s", error);
    }
    else
    {
        char value[64];
        int client = data.ReadCell();
        data.ReadString(SZF(value));
        delete data;

        char steamid[32];
        if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[1024];
            if (results.RowCount > 0)
            {
                FormatEx(query, sizeof(query), "UPDATE %sweapons SET %s WHERE `steamid` = '%s' AND `weaponindex` = %i", g_TablePrefix, value, steamid, g_iIndex[client]);
                g_hDatabase.Query(SQLCallback_Void, query);
            }
            else
            {
                DataPack data1 = new DataPack();
                data1.WriteCell(client);
                data1.WriteString(value);
                data1.Reset();
                FormatEx(query, sizeof(query), "INSERT INTO %sweapons (`steamid`, `weaponindex`) VALUES ('%s', %i)", g_TablePrefix, steamid, g_iIndex[client]);
                g_hDatabase.Query(T_UpdatePlayerDataCallback, query, data1);
            }
        }
    }
}

public void T_UpdatePlayerDataCallback(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (strlen(error)>0)
    {
        LogError("[T_UpdatePlayerDataCallback] error: \"%s\"", error);
        return;
    }
    int client = data.ReadCell();
    char value[64];
    data.ReadString(value, sizeof(value));
    delete data;

    char steamid[32];
    if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
    {
        char query[1024];
        FormatEx(query, sizeof(query), "UPDATE %sweapons SET %s WHERE `steamid` = '%s' AND `weaponindex` = %i", g_TablePrefix, value, steamid, g_iIndex[client]);
        g_hDatabase.Query(SQLCallback_Void, query);
    }
}

void UpdateClientStickersData(int client, int index, int slot)
{
    if (!client || !IsClientInGame(client))
    {
        return;
    }

    char authId[MAX_LENGTH_AUTHID];
    if (!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId)))
    {
        LogError("[UpdateClientStickersData] Auth failed for client index %d", client);
        return;
    }

    int defIndex = eItems_GetWeaponDefIndexByWeaponNum(index);
    // Update MySQL.
    char query[2048];
    FormatEx(query, sizeof(query), "SELECT * FROM %sstickers WHERE `steamid` = '%s' AND `weaponindex` = %i", g_TablePrefix, authId, defIndex);
    DataPack data = new DataPack();
    data.WriteCell(client);
    data.WriteCell(index);
    data.WriteCell(slot);
    data.Reset();
    
    g_hDatabase.Query(UpdateClientStickersDataPost, query, data);
}

public void UpdateClientStickersDataPost(Database database, DBResultSet results, const char[] error, DataPack data)
{
    if (strlen(error)>0)
    {
        LogError("[UpdateClientStickersDataPost]: %s", error);
    }
    else
    {
        int client = data.ReadCell();
        int index = data.ReadCell();
        int defIndex = eItems_GetWeaponDefIndexByWeaponNum(index);
        int slot = data.ReadCell();
        delete data;

        char steamid[32];
        if(GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true))
        {
            char query[1024];
            if (results.RowCount > 0)
            {
                FormatEx(query, sizeof(query), "UPDATE %sstickers SET `slot%i`=%i WHERE `steamid` = '%s' AND `weaponindex` = %i", g_TablePrefix, slot, g_PlayerWeapon[client][index].Sticker[slot], steamid, defIndex);
                g_hDatabase.Query(SQLCallback_Void, query);
            }
            else
            {
                FormatEx(query, sizeof(query), "INSERT INTO %sstickers (`steamid`, `weaponindex`, `slot%i`) VALUES (\"%s\", '%i', '%i');", g_TablePrefix, slot, steamid, defIndex, g_PlayerWeapon[client][index].Sticker[slot]);
                g_hDatabase.Query(SQLCallback_Void, query);
            }
        }
    }
}

public void SQLCallback_Void(Database database, DBResultSet results, const char[] error, any data)
{
    if (strlen(error)>0)
    {
        LogError("[SQLCallback_Void] Error (%i): %s", data, error);
    }
}