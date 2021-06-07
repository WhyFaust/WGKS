public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int clientIndex = GetClientOfUserId(event.GetInt("userid"));
    if(IsValidClient(clientIndex))
    {
        GivePlayerGloves(clientIndex);
    }
}

public void HookPlayer(int client)
{
    if(g_bEnableStatTrak)
        SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

public void UnhookPlayer(int client)
{
    if(g_bEnableStatTrak)
        SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

Action GiveNamedItemPre(int client, char classname[64], CEconItemView &item, bool &ignoredCEconItemView, bool &OriginIsNULL, float Origin[3])
{
    if (IsValidClient(client))
    {
        if (g_iKnife[client] != -1 && eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByClassName(classname)))
        {
            ignoredCEconItemView = true;
            eItems_GetWeaponClassNameByWeaponNum(g_iKnife[client], SZF(classname));

            return Plugin_Changed;
        }

        int defIndex = eItems_GetWeaponDefIndexByClassName(classname);
        
        if(eItems_IsSkinnableDefIndex(defIndex))
            if(g_PlayerWeapon[client][defIndex].Weapon.Skin > 0)
                if (ClientWeaponHasStickers(client, defIndex))
                {
                    ignoredCEconItemView = true;
                    return Plugin_Changed;
                }
    }
    return Plugin_Continue;
}

void GiveNamedItemPost(int client, const char[] classname, const CEconItemView item, int entity, bool OriginIsNULL, const float Origin[3])
{
    if (IsValidClient(client) && IsValidEntity(entity))
    {
        if (eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByClassName(classname)))
        {
            EquipPlayerWeapon(client, entity);
        }
        SetWeaponProps(client, entity);
        SetWeaponSticker(client, entity);
    }
}

void SetWeaponProps(int client, int entity)
{
	int index = eItems_GetWeaponNumByWeapon(entity);
	if (index > -1 && g_PlayerWeapon[client][index].Weapon.Skin != 0)
	{
		static int IDHigh = 16384;
		SetEntProp(entity, Prop_Send, "m_iItemIDLow", -1);
		SetEntProp(entity, Prop_Send, "m_iItemIDHigh", IDHigh++);
		SetEntProp(entity, Prop_Send, "m_nFallbackPaintKit", g_PlayerWeapon[client][index].Weapon.Skin);
		SetEntPropFloat(entity, Prop_Send, "m_flFallbackWear", !g_bEnableFloat || g_PlayerWeapon[client][index].Weapon.Float == 0.0 ? 0.000001 : g_PlayerWeapon[client][index].Weapon.Float == 1.0 ? 0.999999 : g_PlayerWeapon[client][index].Weapon.Float);
		
		if(!eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeapon(entity)))
		{
			if(g_bEnableStatTrak)
			{
				//SetEntProp(entity, Prop_Send, "m_nFallbackStatTrak", g_iStatTrak[client][index] == 1 ? g_iStatTrakCount[client][index] : -1);
				//SetEntProp(entity, Prop_Send, "m_iEntityQuality", g_iStatTrak[client][index] == 1 ? 9 : 0);
				
				SetEntProp(entity, Prop_Send, "m_nFallbackStatTrak", g_PlayerWeapon[client][index].Weapon.StatTrak == 1 ? g_PlayerWeapon[client][index].Weapon.StatTrakCount : -1);
				SetEntProp(entity, Prop_Send, "m_iEntityQuality", g_PlayerWeapon[client][index].Weapon.StatTrak == 1 ? 9 : 0);
			}
		}
		else
		{
			if(g_bEnableStatTrak)
			{
				//SetEntProp(entity, Prop_Send, "m_nFallbackStatTrak", g_iStatTrak[client][index] == 0 ? -1 : g_iKnifeStatTrakMode == 0 ? GetTotalKnifeStatTrakCount(client) : g_iStatTrakCount[client][index]);
				SetEntProp(entity, Prop_Send, "m_nFallbackStatTrak", g_PlayerWeapon[client][index].Weapon.StatTrak == 0 ? -1 : g_iKnifeStatTrakMode == 0 ? GetTotalKnifeStatTrakCount(client) : g_PlayerWeapon[client][index].Weapon.StatTrakCount);
			}
			SetEntProp(entity, Prop_Send, "m_iEntityQuality", 3);
		}
		/*if (g_bEnableNameTag && strlen(g_NameTag[client][index]) > 0)
		{
			SetEntDataString(entity, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), g_NameTag[client][index], 128);
		}*/
		if (g_bEnableNameTag && strlen(g_PlayerWeapon[client][index].Weapon.NameTag) > 0)
		{
			SetEntDataString(entity, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), g_PlayerWeapon[client][index].Weapon.NameTag, 128);
		}
		SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client));
		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
		SetEntPropEnt(entity, Prop_Send, "m_hPrevOwner", -1);
	}
}

void SetWeaponSticker(int client, int entity)
{
    int defIndex = eItems_GetWeaponDefIndexByWeapon(entity);
    if (ClientWeaponHasStickers(client, defIndex))
    {
        int index = eItems_GetWeaponNumByDefIndex(defIndex);
        if (index != -1)
        {
            // Check if item is already initialized by external ws.
            if (GetEntProp(entity, Prop_Send, "m_iItemIDHigh") < 16384)
            {
                static int IDHigh = 16384;
                SetEntProp(entity, Prop_Send, "m_iItemIDLow", -1);
                SetEntProp(entity, Prop_Send, "m_iItemIDHigh", IDHigh++);
                SetEntProp(entity, Prop_Send, "m_iAccountID", GetSteamAccountID(client, true));
                SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
                SetEntPropEnt(entity, Prop_Send, "m_hPrevOwner", -1);
            }

            // Change stickers.
            Address pWeapon = GetEntityAddress(entity);
            if (pWeapon == Address_Null)
            {
                CPrintToChat(client, "%t", "Unknown Error");
                return;
            }

            Address pEconItemView = pWeapon + view_as<Address>(g_econItemOffset);
        
            bool isUpdated = false;
            for (int i = 0; i < MAX_STICKERS_SLOT; i++)
            {
                if (g_PlayerWeapon[client][index].Sticker[i] != 0)
                {
                    // Sticker updated.
                    isUpdated = true;

                    SetAttributeValue(client, pEconItemView, g_PlayerWeapon[client][index].Sticker[i], "sticker slot %i id", i);
                    SetAttributeValue(client, pEconItemView, view_as<int>(0.0), "sticker slot %i wear", i); // default wear.
                }
            }

            // Update viewmodel if enabled.
            if (isUpdated && g_isStickerRefresh[client])
            {
                g_isStickerRefresh[client] = false;
        
                PTaH_ForceFullUpdate(client);
            }
        }
    }
}

public Action ChatListener(int client, const char[] command, int args)
{
    char msg[128];
    GetCmdArgString(msg, sizeof(msg));
    StripQuotes(msg);
    if(g_bWeaponsEnable)
    {
        if (StrEqual(msg, "!ws") || StrEqual(msg, "!knife") || StrEqual(msg, "!wslang") || StrContains(msg, "!nametag") == 0 || StrContains(msg, "!seed") == 0)
        {
            return Plugin_Handled;
        }
        else if (g_bWaitingForNametag[client] && IsValidClient(client) && g_iIndex[client] > -1 && !IsChatTrigger())
        {
            CleanNameTag(msg, sizeof(msg));
            
            g_bWaitingForNametag[client] = false;
            
            if (StrEqual(msg, "!cancel") || StrEqual(msg, "!iptal"))
            {
                PrintToChat(client, " %s \x02%t", g_ChatPrefix, "NameTagCancelled");
                return Plugin_Handled;
            }
            
            strcopy(g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag, 128, msg);
            
            RefreshWeapon(client, g_iIndex[client]);
            
            char updateFields[1024];
            char escaped[257];
            g_hDatabase.Escape(msg, escaped, sizeof(escaped));
            Format(updateFields, sizeof(updateFields), "tag = '%s'", escaped);
            StartUpdatePlayerData(client, updateFields);
            
            PrintToChat(client, " %s \x04%t: \x01\"%s\"", g_ChatPrefix, "NameTagSuccess", msg);
            
            CreateNameTagMenu(client);
            
            return Plugin_Handled;
        }
    }
    if(g_bGlovesEnable)
    {
        if (StrEqual(msg, "!gloves") || StrEqual(msg, "!glove") || StrEqual(msg, "!eldiven") || StrContains(msg, "!gllang") == 0)
        {
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (float(GetClientHealth(victim)) - damage > 0.0)
        return Plugin_Continue;
        
    if (!(damagetype & DMG_SLASH) && !(damagetype & DMG_BULLET))
        return Plugin_Continue;
        
    if (!IsValidClient(attacker))
        return Plugin_Continue;
        
    if (!eItems_IsValidWeapon(weapon))
        return Plugin_Continue;
        
    int index = eItems_GetWeaponNumByWeapon(weapon);

    if (index != -1 && g_PlayerWeapon[attacker][index].Weapon.Skin != 0 && g_PlayerWeapon[attacker][index].Weapon.StatTrak != 1)
        return Plugin_Continue;
        
    if (GetEntProp(weapon, Prop_Send, "m_nFallbackStatTrak") == -1)
        return Plugin_Continue;
        
    int previousOwner;
    if ((previousOwner = GetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner")) != INVALID_ENT_REFERENCE && previousOwner != attacker)
        return Plugin_Continue;
    
    g_PlayerWeapon[attacker][index].Weapon.StatTrakCount++;
    

    char updateFields[256];
    Format(updateFields, sizeof(updateFields), "trak_count = %d", g_PlayerWeapon[attacker][index].Weapon.StatTrakCount);
    StartUpdatePlayerData(attacker, updateFields);

    //Сделать обновление счетчика

    return Plugin_Continue;
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
    if (IsWarmUpPeriod())
    {
        g_iRoundStartTime = 0;
    }
    else
    {
        g_iRoundStartTime = GetTime();
    }
}

Action WeaponCanUsePre(int client, int weapon, bool& pickup)
{
    if (eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeapon(weapon)) && IsValidClient(client))
    {
        pickup = true;
        return Plugin_Changed;
    }
    return Plugin_Continue;
}
