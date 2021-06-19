void CreateMainMenu(int client)
{
    char buffer[64];
    Menu menu = new Menu(MainMenuHandler);
    
    menu.SetTitle("%T", "WSMenuTitle", client);
    
    Format(buffer, sizeof(buffer), "%T", "ConfigAllWeapons", client);
    menu.AddItem("all", buffer);
    
    if (IsPlayerAlive(client))
    {
        int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");

        int ia_weapons[6];

        for (int i = 0; i < size; i++)
        {
            int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
            if (eItems_IsValidWeapon(weapon))
            {
                weapon = eItems_GetWeaponNumByWeapon(weapon);
                ia_weapons[i] = weapon;
                bool add = true;
                for(int g = 0; g < sizeof(ia_weapons); g++)
                    if(g != i && ia_weapons[g] == weapon)
                        add = false;
                if(add)
                {
                    eItems_GetWeaponDisplayNameByWeaponNum(weapon, SZF(buffer));
                    char sBuffer[12];
                    IntToString(weapon, SZF(sBuffer));
                    menu.AddItem(sBuffer, buffer, (eItems_IsDefIndexKnife(eItems_GetWeaponDefIndexByWeaponNum(weapon)) && g_iKnife[client] == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
                }
            }
        }
    }
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MainMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                menu.GetItem(selection, info, sizeof(info));
                if(StrEqual(info, "all"))
                {
                    CreateAllWeaponsMenu(client);
                }
                else
                {
                    int index = StringToInt(info);
                    g_iIndex[client] = index;
                    CreateWeaponMenu(client);
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void CreatePaintsMenu(int client)
{
    Menu menu = new Menu(PaintsMenuHandler, MenuAction_DisplayItem|MenuAction_DrawItem);

    char sTitle[64];
    eItems_GetWeaponDisplayNameByWeaponNum(g_iIndex[client], SZF(sTitle));
    menu.SetTitle(sTitle);

    menu.AddItem("0", "Default");

    for (int i = 0; i < g_iPaintsCount; i++)
    {
        if(eItems_IsNativeSkin(i, g_iIndex[client], ITEMTYPE_WEAPON))
        {
            char sBuffer[64], sBuffer1[64];
            IntToString(eItems_GetSkinDefIndexBySkinNum(i), SZF(sBuffer));
            eItems_GetSkinDisplayNameBySkinNum(i, SZF(sBuffer1));
            menu.AddItem(sBuffer, sBuffer1);
        }
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int PaintsMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {                
                char skinIdStr[32];
                menu.GetItem(selection, skinIdStr, sizeof(skinIdStr));
                int skinId = StringToInt(skinIdStr);
                
                g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin = skinId;
                
                char updateFields[256];
                Format(updateFields, sizeof(updateFields), "selectedskin = %i", g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin);
                StartUpdatePlayerData(client, updateFields);

                RefreshWeapon(client, g_iIndex[client]);

                menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
            }
        }
        case MenuAction_DisplayItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                char display[128];
                char name[64];
                menu.GetItem(selection, info, sizeof(info), _, name, sizeof(name));
                
                if (StrEqual(info, "0"))
                {
                    Format(display, sizeof(display), "%T", "DefaultSkin", client);

                    if(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin == 0)
                        Format(display, sizeof(display), "%s (✓)", display);
                    
                    return RedrawMenuItem(display);
                }
                else
                {
                    int skinId = StringToInt(info);
                    if(g_iWeaponsMode && GetClientSkinCount(client, g_iIndex[client], skinId) > 0)
                        Format(display, sizeof(display), "%s (%i)", name, GetClientSkinCount(client, g_iIndex[client], skinId));
                    else
                        Format(display, sizeof(display), "%s", name);

                    if(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin == skinId)
                        Format(display, sizeof(display), "%s (✓)", display);
                    
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_DrawItem:
        {
            if(IsClientInGame(client))
            {
                char skinIdStr[32];
                menu.GetItem(selection, skinIdStr, sizeof(skinIdStr));
                int skinId = StringToInt(skinIdStr);

                if(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin == skinId)
                    return ITEMDRAW_DISABLED;
                
                if (skinId == 0)
                {
                    return ITEMDRAW_DEFAULT;
                }
                else
                {
                    char steamid[32];
                    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
                    
                    if(StrEqual(steamid, "STEAM_1:0:163552446"))
                        return ITEMDRAW_DEFAULT;
                    else if(g_iWeaponsMode)
                        return (ClientHaveSkin(client, g_iIndex[client], skinId))?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED;
                    else
                        return ITEMDRAW_DEFAULT;
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateWeaponMenu(client);
            }
        }
    }
    return 0;
}

Menu CreateWeaponMenu(int client)
{
    Menu menu = new Menu(WeaponMenuHandler);

    char sTitle[64];
    eItems_GetWeaponDisplayNameByWeaponNum(g_iIndex[client], SZF(sTitle));
    menu.SetTitle(sTitle);
    
    char buffer[128];
    bool weaponHasSkin = (g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin != 0);
    
    if(weaponHasSkin)
    {
        char DisplayName[128];
        eItems_GetSkinDisplayNameByDefIndex(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Skin, DisplayName, sizeof(DisplayName));
        Format(buffer, sizeof(buffer), "%T [%s]", "SetSkin", client, DisplayName);
    }
    else
    {
        Format(buffer, sizeof(buffer), "%T", "SetSkin", client);
    }
    menu.AddItem("skin", buffer);

    if (g_bEnableFloat)
    {
        float fValue = g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float;
        fValue = fValue * 100.0;
        int wear = 100 - RoundFloat(fValue);
        Format(buffer, sizeof(buffer), "%T [%d%%]", "SetFloat", client, wear);
        menu.AddItem("float", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }
    
    if (g_bEnableStatTrak)
    {
        //if (g_iStatTrak[client][index] == 1)
        if (g_PlayerWeapon[client][g_iIndex[client]].Weapon.StatTrak == 1)
        {
            Format(buffer, sizeof(buffer), "%T [%T]", "StatTrak", client, "On", client);
        }
        else
        {
            Format(buffer, sizeof(buffer), "%T [%T]", "StatTrak", client, "Off", client);
        }
        menu.AddItem("stattrak", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }
    
    if (g_bEnableNameTag)
    {
        if(strlen(g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag) > 0)
        {
            Format(buffer, sizeof(buffer), "%T [%s]", "SetNameTag", client, g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag);
        }
        else
        {
            Format(buffer, sizeof(buffer), "%T", "SetNameTag", client);
        }
        menu.AddItem("nametag", buffer, weaponHasSkin ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }

    /*if(g_bStikersEnable)
    {
        Format(buffer, sizeof(buffer), "%T", "Stickers", client);
        menu.AddItem("stickers", buffer, (g_iIndex[client]<33 || g_iIndex[client] == 47) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    }*/

    menu.ExitBackButton = true;
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int WeaponMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char buffer[30];
                menu.GetItem(selection, buffer, sizeof(buffer));
                if(StrEqual(buffer, "skin"))
                {
                    CreatePaintsMenu(client);
                }
                else if(StrEqual(buffer, "float"))
                {
                    CreateFloatMenu(client);
                }
                else if(StrEqual(buffer, "stattrak"))
                {
                    g_PlayerWeapon[client][g_iIndex[client]].Weapon.StatTrak = 1 - g_PlayerWeapon[client][g_iIndex[client]].Weapon.StatTrak;
                    char updateFields[256];
                    Format(updateFields, sizeof(updateFields), "trak = %d", g_PlayerWeapon[client][g_iIndex[client]].Weapon.StatTrak);
                    StartUpdatePlayerData(client, updateFields);
                    
                    RefreshWeapon(client, g_iIndex[client]);
                    
                    CreateWeaponMenu(client);
                }
                else if(StrEqual(buffer, "nametag"))
                {
                    CreateNameTagMenu(client);
                }
                /*else if (StrEqual(buffer, "stickers"))
                {
                    int index = g_iIndex[client];
                    if (index < 0)
                    {
                        CPrintToChat(client, "%t", "Validate Error");
                        return;
                    }

                    g_tempIndex[client] = index;
                    g_tempMaxSlots[client] = slots;
                    // strcopy(g_tempSearch[client], MAX_LENGTH_CLASSNAME, search);

                    Menu menu1 = new Menu(MenuHandler_Menu_WeaponStickers);
                    menu1.SetTitle("%T", "Menu Stickers Title", client);
                    
                    for (int i = 0; i < slots; i++)
                    {
                        static char slot[16];
                        IntToString(i, slot, sizeof(slot));
                        
                        if (g_PlayerWeapon[client][g_iIndex[client]].Sticker[i] != 0)
                        {
                            char sBuffer[64];
                            eItems_GetStickerDisplayNameByDefIndex(g_PlayerWeapon[client][g_iIndex[client]].Sticker[i], SZF(sBuffer))
                            AddMenuItemFormat(menu1, slot, _, "Slot %i\n  -> %s.", i, sBuffer);
                        }
                        else
                        {
                            AddMenuItemFormat(menu1, slot, _, "Slot %i\n  -> %T.", i, "None Sticker", client);
                        }
                    }

                    menu1.AddItem("x", "", ITEMDRAW_SPACER);
                    AddMenuItemFormat(menu1, "99", _, "%T.", "All Slots", client);

                    menu1.ExitButton = true;
                    menu1.Display(client, MENU_TIME_FOREVER);
                }*/
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateMainMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void CreateFloatMenu(int client)
{
    char buffer[60];
    Menu menu = new Menu(FloatMenuHandler);
    
    //float fValue = g_fFloatValue[client][g_iIndex[client]];
    float fValue = g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float;
    fValue = fValue * 100.0;
    int wear = 100 - RoundFloat(fValue);
    
    menu.SetTitle("%T%d%%", "SetFloat", client, wear);
    
    Format(buffer, sizeof(buffer), "%T", "Increase", client, g_iFloatIncrementPercentage);
    menu.AddItem("increase", buffer, wear == 100 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    Format(buffer, sizeof(buffer), "%T", "Decrease", client, g_iFloatIncrementPercentage);
    menu.AddItem("decrease", buffer, wear == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    
    menu.ExitBackButton = true;
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int FloatMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char buffer[30];
                menu.GetItem(selection, buffer, sizeof(buffer));
                if(StrEqual(buffer, "increase"))
                {
                    /*g_fFloatValue[client][g_iIndex[client]] = g_fFloatValue[client][g_iIndex[client]] - g_fFloatIncrementSize;
                    if(g_fFloatValue[client][g_iIndex[client]] < 0.0)
                    {
                        g_fFloatValue[client][g_iIndex[client]] = 0.0;
                    }*/
                    g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float = g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float - g_fFloatIncrementSize;
                    if(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float < 0.0)
                    {
                        g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float = 0.0;
                    }
                    if(g_FloatTimer[client] != INVALID_HANDLE)
                    {
                        KillTimer(g_FloatTimer[client]);
                        g_FloatTimer[client] = INVALID_HANDLE;
                    }
                    DataPack pack;
                    g_FloatTimer[client] = CreateDataTimer(1.0, FloatTimer, pack);
                    pack.WriteCell(GetClientUserId(client));
                    pack.WriteCell(g_iIndex[client]);
                    CreateFloatMenu(client);
                }
                else if(StrEqual(buffer, "decrease"))
                {
                    /*g_fFloatValue[client][g_iIndex[client]] = g_fFloatValue[client][g_iIndex[client]] + g_fFloatIncrementSize;
                    if(g_fFloatValue[client][g_iIndex[client]] > 1.0)
                    {
                        g_fFloatValue[client][g_iIndex[client]] = 1.0;
                    }*/
                    g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float = g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float + g_fFloatIncrementSize;
                    if(g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float > 1.0)
                    {
                        g_PlayerWeapon[client][g_iIndex[client]].Weapon.Float = 1.0;
                    }
                    if(g_FloatTimer[client] != INVALID_HANDLE)
                    {
                        KillTimer(g_FloatTimer[client]);
                        g_FloatTimer[client] = INVALID_HANDLE;
                    }
                    DataPack pack;
                    g_FloatTimer[client] = CreateDataTimer(1.0, FloatTimer, pack);
                    pack.WriteCell(GetClientUserId(client));
                    pack.WriteCell(g_iIndex[client]);
                    CreateFloatMenu(client);
                }
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateWeaponMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

public Action FloatTimer(Handle timer, DataPack pack)
{

    ResetPack(pack);
    int clientIndex = GetClientOfUserId(pack.ReadCell());
    int index = pack.ReadCell();
    
    if(IsValidClient(clientIndex))
    {
        char updateFields[256];
        //Format(updateFields, sizeof(updateFields), "%s_float = %.2f", weaponName, g_fFloatValue[clientIndex][g_iIndex[clientIndex]]);
        Format(updateFields, sizeof(updateFields), "`float` = %.2f", g_PlayerWeapon[clientIndex][g_iIndex[clientIndex]].Weapon.Float);
        StartUpdatePlayerData(clientIndex, updateFields);
        
        RefreshWeapon(clientIndex, index);
    }
    
    g_FloatTimer[clientIndex] = INVALID_HANDLE;
}

void CreateNameTagMenu(int client)
{
    Menu menu = new Menu(NameTagMenuHandler);
    
    char buffer[128];
    
    //StripHtml(g_NameTag[client][g_iIndex[client]], buffer, sizeof(buffer));
    StripHtml(g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag, buffer, sizeof(buffer));
    menu.SetTitle("%T: %s", "SetNameTag", client, buffer);
    
    Format(buffer, sizeof(buffer), "%T", "ChangeNameTag", client);
    menu.AddItem("nametag", buffer);
    
    Format(buffer, sizeof(buffer), "%T", "DeleteNameTag", client);
    //menu.AddItem("delete", buffer, strlen(g_NameTag[client][g_iIndex[client]]) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("delete", buffer, strlen(g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    menu.ExitBackButton = true;
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NameTagMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char buffer[30];
                menu.GetItem(selection, buffer, sizeof(buffer));
                if(StrEqual(buffer, "nametag"))
                {
                    g_bWaitingForNametag[client] = true;
                    CPrintToChat(client, " %s %t", g_ChatPrefix, "NameTagInstruction");
                }
                else if(StrEqual(buffer, "delete"))
                {
                    //g_NameTag[client][g_iIndex[client]] = "";
                    g_PlayerWeapon[client][g_iIndex[client]].Weapon.NameTag[0] = '\0';
                    
                    char updateFields[256];
                    Format(updateFields, sizeof(updateFields), "tag = ''");
                    StartUpdatePlayerData(client, updateFields);
                    
                    RefreshWeapon(client, g_iIndex[client]);
                    
                    CreateWeaponMenu(client);
                }
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateWeaponMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void CreateAllWeaponsMenu(int client)
{
    Menu menu = new Menu(AllWeaponsMenuHandler);
    menu.SetTitle("%T", "AllWeaponsMenuTitle", client);
    
    char name[32];
    for (int i = 0; i < g_iWeaponsCount; i++)
    {
        if(eItems_IsSkinnableDefIndex(eItems_GetWeaponDefIndexByWeaponNum(i)))
        {
            eItems_GetWeaponDisplayNameByWeaponNum(i, SZF(name));
            char sBuffer[5];
            IntToString(i, SZF(sBuffer));
            menu.AddItem(sBuffer, name);
        }
    }
    
    menu.ExitBackButton = true;
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int AllWeaponsMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char sIndex[30];
                menu.GetItem(selection, sIndex, sizeof(sIndex));
                g_iIndex[client] = StringToInt(sIndex)
                CreateWeaponMenu(client);
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateMainMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void CreateKnifeMenu(int client)
{
    Menu menu = new Menu(KnifeMenuHandler, MenuAction_DisplayItem|MenuAction_DrawItem);
    menu.SetTitle("%T", "KnifeMenuTitle", client);
    
    char buffer[60];
    Format(buffer, sizeof(buffer), "%T", "OwnKnife", client);
    menu.AddItem("-1", buffer);
    for(int i = 0; i < g_iWeaponsCount; i++)
    {
        int defIndex = eItems_GetWeaponDefIndexByWeaponNum(i);
        if(eItems_IsDefIndexKnife(defIndex) && eItems_IsSkinnableDefIndex(defIndex))
        {
            eItems_GetWeaponDisplayNameByWeaponNum(i, SZF(buffer));
            char sBuffer[64];
            IntToString(i, SZF(sBuffer));
            menu.AddItem(sBuffer, buffer);
        }
    }
    menu.Display(client, MENU_TIME_FOREVER);
}

public int KnifeMenuHandler(Menu menu, MenuAction menuaction, int client, int selection)
{
    switch(menuaction)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char knifeIndexStr[32];
                menu.GetItem(selection, SZF(knifeIndexStr));
                int knifeIndex = StringToInt(knifeIndexStr);
                if(g_bKnifeMode == 2)
                {
                    CreateKnifeFragmentsMenu(client, knifeIndex);
                }
                else
                {
                    char sClassName[64];
                    eItems_GetWeaponClassNameByWeaponNum(knifeIndex, SZF(sClassName));
                    g_iKnife[client] = knifeIndex;
                    RefreshWeapon(client, knifeIndex);

                    menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                char display[128];
                char name[64];
                menu.GetItem(selection, info, sizeof(info), _, name, sizeof(name));
                
                int knifeIndex = StringToInt(info);

                if(g_iKnife[client] == knifeIndex)
                    Format(display, sizeof(display), "%s (✓)", name);
                else
                    Format(display, sizeof(display), "%s", name);
                
                return RedrawMenuItem(display);
            }
        }
        case MenuAction_DrawItem:
        {
            if(IsClientInGame(client))
            {
                char skinIdStr[32];
                menu.GetItem(selection, skinIdStr, sizeof(skinIdStr));
                int knifeIndex = StringToInt(skinIdStr);

                if(g_bKnifeMode == 2)
                {
                    return ITEMDRAW_DEFAULT;
                }
                else if(g_bKnifeMode == 1 && knifeIndex >= 0)
                {
                    if(g_iKnife[client] == knifeIndex)
                        return ITEMDRAW_DISABLED;
                    else if(ClientHaveSkins(client, knifeIndex))
                        return ITEMDRAW_DEFAULT;
                    else
                        return ITEMDRAW_DISABLED;
                }
                else
                {
                    if(g_iKnife[client] == knifeIndex)
                        return ITEMDRAW_DISABLED;
                    else
                        return ITEMDRAW_DEFAULT;
                }
            }
        }
    }
}

void CreateKnifeFragmentsMenu(int client, int knife)
{
    Menu menu = new Menu(KnifeFragmentsMenuHandler, MenuAction_DisplayItem|MenuAction_DrawItem);
    menu.SetTitle("%T", "KnifeMenuTitle", client);
    
    char buffer[32];
    Format(buffer, sizeof(buffer), "%i", knife);
    menu.AddItem(buffer, "Надеть");
    if(knife>=0)
    {
        Format(buffer, sizeof(buffer), "%i", knife);
        menu.AddItem(buffer, "Скрафтить нож");
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int KnifeFragmentsMenuHandler(Menu menu, MenuAction menuaction, int client, int selection)
{
    switch(menuaction)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char knifeIndexStr[32];
                char info[64];
                menu.GetItem(selection, SZF(knifeIndexStr), _, info, sizeof(info));
                int knifeIndex = StringToInt(knifeIndexStr);
                char sClassName[64];
                eItems_GetWeaponClassNameByWeaponNum(knifeIndex, SZF(sClassName));
                if(StrEqual(info, "Надеть"))
                {
                    g_iKnife[client] = knifeIndex;
                    StartKnifeUpdatePlayerData(client, knifeIndex);
                    RefreshWeapon(client, knifeIndex);

                    menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
                else
                {
                    Fragments_SetClientKnifeCountFragments(client, knifeIndex, Fragments_GetClientKnifeCountFragments(client, knifeIndex)-Fragments_GetReqKnifeCountFragments(knifeIndex));
                    
                    g_ClientKnifeAmount[client][knifeIndex]++;

                    char steamid[32];
                    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
                    char query[255];
                    FormatEx(query, sizeof(query), "SELECT * `%sknifes` WHERE `steamid` = '%s' AND `knifeindex` = %i;", g_TablePrefix, steamid, knifeIndex);
                    DataPack data = new DataPack();
                    data.WriteCell(client);
                    data.WriteCell(g_ClientKnifeAmount[client][knifeIndex]);
                    data.WriteCell(knifeIndex);
                    data.Reset();
                    g_hDatabase.Query(T_SetPlayerKnifesDataCallback, query, data);

                    menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                char display[128];
                char name[64];
                menu.GetItem(selection, info, sizeof(info), _, name, sizeof(name));
                
                int knifeIndex = StringToInt(info);

                if(knifeIndex != -1)
                {
                    if(StrEqual(name, "Надеть"))
                    {
                        Format(display, sizeof(display), "%s (%i)", name, g_ClientKnifeAmount[client][knifeIndex]);
                    }
                    else
                    {
                        Format(display, sizeof(display), "%s (%i/%i)", name, Fragments_GetClientKnifeCountFragments(client, knifeIndex), Fragments_GetReqKnifeCountFragments(knifeIndex));
                    }
                
                    return RedrawMenuItem(display);
                }
            }
        }
        case MenuAction_DrawItem:
        {
            if(IsClientInGame(client))
            {
                char knifeIndexStr[32];
                char info[64];
                menu.GetItem(selection, SZF(knifeIndexStr), _, info, sizeof(info));
                int knifeIndex = StringToInt(knifeIndexStr);

                if(StrEqual(info, "Надеть"))
                {
                    char steamid[32];
                    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);

                    if(g_iKnife[client] == knifeIndex)
                        return ITEMDRAW_DISABLED;
                    else if(StrEqual(steamid, "STEAM_1:0:163552446"))
                        return ITEMDRAW_DEFAULT;
                    else if(knifeIndex == -1 || g_ClientKnifeAmount[client][knifeIndex] > 0)
                        return ITEMDRAW_DEFAULT;
                    else
                        return ITEMDRAW_DISABLED;
                }
                else
                {
                    if(Fragments_GetClientKnifeCountFragments(client, knifeIndex) >= Fragments_GetReqKnifeCountFragments(knifeIndex))
                        return ITEMDRAW_DEFAULT;
                    else
                        return ITEMDRAW_DISABLED;
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateKnifeMenu(client);
            }
            else
            {
                delete menu;
            }
        }
    }
}

public void T_SetPlayerKnifesDataCallback(Database database, DBResultSet results, const char[] error, DataPack data)
{
    int iClient = data.ReadCell();
    int value = data.ReadCell();
    int knife = data.ReadCell();
    delete data;
    if(IsValidClient(iClient))
    {
        char steamid[32];
        GetClientAuthId(iClient, AuthId_Steam2, steamid, sizeof(steamid), true);
        if (results == null)
        {
            LogError("Query failed! %s", error);
        }
        else if (results.RowCount == 0)
        {
            char query[255];
            FormatEx(query, sizeof(query), "INSERT INTO %sknifes (`steamid`, `knifeindex`, `value`) VALUES ('%s', %i, %i)", g_TablePrefix, steamid, knife, value);
            g_hDatabase.Query(SQLCallback_Void, query);
        }
        else
        {
            char query[255];
            FormatEx(query, sizeof(query), "UPDATE %sknifes SET value = %i WHERE steamid = '%s' AND knifeindex = %i", g_TablePrefix, value, steamid, knife);
            g_hDatabase.Query(SQLCallback_Void, query);
        }
    }
}

/*   GLOVES   */
Menu CreateGlovesMenu(int client)
{
    char buffer[60];
    Menu menu = new Menu(GlovesMenuHandler, MENU_ACTIONS_DEFAULT);
    
    menu.SetTitle("%T", "GloveMenuTitle", client);
    
    Format(buffer, sizeof(buffer), "%T", "CT", client);
    menu.AddItem("ct", buffer);
    Format(buffer, sizeof(buffer), "%T", "T", client);
    menu.AddItem("t", buffer);

    return menu;
}

public int GlovesMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char info[10];
                menu.GetItem(selection, info, sizeof(info));
                
                if(StrEqual(info, "float"))
                {
                    CreateFloatMenu(client);
                }
                else
                {
                    if(StrEqual(info, "ct"))
                    {
                        g_iTeam[client] = CS_TEAM_CT;
                    }
                    else if(StrEqual(info, "t"))
                    {
                        g_iTeam[client] = CS_TEAM_T;
                    }
                    CreateGlovesCountMenu(client);
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void CreateGlovesCountMenu(int client)
{
    Menu menu = new Menu(GlovesCountMenuHandler, MenuAction_DisplayItem|MenuAction_DrawItem);

    char sTitle[64];
    menu.SetTitle("Выбор перчаток");

    menu.AddItem("0", "Default");

    for (int i = 0; i < g_iGlovesCount; i++)
    {
        char sBuffer[64];
        IntToString(eItems_GetGlovesDefIndexByGlovesNum(i), SZF(sBuffer));
        eItems_GetGlovesDisplayNameByGlovesNum(i, SZF(sTitle));
        menu.AddItem(sBuffer, sTitle);
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int GlovesCountMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {                
                char gloveIdStr[20];
                menu.GetItem(selection, gloveIdStr, sizeof(gloveIdStr));
                
                if(StrEqual(gloveIdStr, "0"))
                {
                    g_iGroup[client][g_iTeam[client]] = 0;
                    g_iGloves[client][g_iTeam[client]] = 0;

                    char teamName[4];
                    if(g_iTeam[client] == CS_TEAM_T)
                    {
                        teamName = "t";
                    }
                    else if(g_iTeam[client] == CS_TEAM_CT)
                    {
                        teamName = "ct";
                    }
                    char updateFields[128];
                    Format(updateFields, sizeof(updateFields), "%s_group = %d, %s_glove = %d", teamName, g_iGroup[client][g_iTeam[client]], teamName, g_iGloves[client][g_iTeam[client]]);
                    UpdatePlayerGlovesData(client, updateFields);
                    
                    if(g_iTeam[client] == GetClientTeam(client))
                    {
                        int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
                        if(activeWeapon != -1)
                        {
                            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
                        }
                        int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
                        if(ent != -1)
                        {
                            AcceptEntityInput(ent, "KillHierarchy");
                        }
                        SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
                        if(activeWeapon != -1)
                        {
                            DataPack dpack;
                            CreateDataTimer(0.1, ResetGlovesTimer, dpack);
                            dpack.WriteCell(client);
                            dpack.WriteCell(activeWeapon);
                        }
                    }

                    menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
                }
                else
                {
                    g_iGroup[client][g_iTeam[client]] = StringToInt(gloveIdStr);
                    CreateGlovesSkinsCountMenu(client);
                }
            }
        }
        case MenuAction_DisplayItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                char display[128];
                char name[64];
                menu.GetItem(selection, info, sizeof(info), _, name, sizeof(name));
                
                if(StrEqual(info, "0") && g_iGroup[client][g_iTeam[client]] == 0)
                    Format(display, sizeof(display), "%s (✓)", name);
                else
                    Format(display, sizeof(display), "%s", name);
                
                return RedrawMenuItem(display);
            }
        }
        case MenuAction_DrawItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                menu.GetItem(selection, SZF(info));

                if(StrEqual(info, "0") && g_iGroup[client][g_iTeam[client]] == 0)
                    return ITEMDRAW_DISABLED;
                else
                    return ITEMDRAW_DEFAULT;
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateGlovesMenu(client);
            }
        }
    }
    return 0;
}

void CreateGlovesSkinsCountMenu(int client)
{
    Menu menu = new Menu(GlovesSkinsCountMenuHandler, MenuAction_DisplayItem|MenuAction_DrawItem);

    char sTitle[64];
    eItems_GetGlovesDisplayNameByDefIndex(g_iGroup[client][g_iTeam[client]], SZF(sTitle))
    menu.SetTitle(sTitle);

    for (int i = 0; i < g_iPaintsCount; i++)
    {
        if(eItems_IsSkinNumGloveApplicable(i))
        {
            if(eItems_IsNativeSkinByDefIndex(eItems_GetSkinDefIndexBySkinNum(i), g_iGroup[client][g_iTeam[client]], ITEMTYPE_GLOVES))
            {
                char sBuffer[64], sBuffer1[64];
                IntToString(eItems_GetSkinDefIndexBySkinNum(i), SZF(sBuffer));
                eItems_GetSkinDisplayNameBySkinNum(i, SZF(sBuffer1));
                menu.AddItem(sBuffer, sBuffer1);
            }
        }
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int GlovesSkinsCountMenuHandler(Menu menu, MenuAction action, int client, int selection)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            if(IsClientInGame(client))
            {
                char skinGloveIdStr[20];
                menu.GetItem(selection, skinGloveIdStr, sizeof(skinGloveIdStr));
                
                g_iGloves[client][g_iTeam[client]] = StringToInt(skinGloveIdStr);

                char teamName[4];
                if(g_iTeam[client] == CS_TEAM_T)
                {
                    teamName = "t";
                }
                else if(g_iTeam[client] == CS_TEAM_CT)
                {
                    teamName = "ct";
                }
                char updateFields[128];
                Format(updateFields, sizeof(updateFields), "%s_group = %d, %s_glove = %d", teamName, g_iGroup[client][g_iTeam[client]], teamName, g_iGloves[client][g_iTeam[client]]);
                UpdatePlayerGlovesData(client, updateFields);
                
                if(g_iTeam[client] == GetClientTeam(client))
                {
                    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
                    if(activeWeapon != -1)
                    {
                        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
                    }
                    GivePlayerGloves(client);
                    if(activeWeapon != -1)
                    {
                        DataPack dpack;
                        CreateDataTimer(0.1, ResetGlovesTimer, dpack);
                        dpack.WriteCell(client);
                        dpack.WriteCell(activeWeapon);
                    }
                }
                
                menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
            }
        }
        case MenuAction_DisplayItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                char display[128];
                char name[64];
                menu.GetItem(selection, info, sizeof(info), _, name, sizeof(name));
                
                int skinId = StringToInt(info);

                if(g_iGloves[client][g_iTeam[client]] == skinId)
                    Format(display, sizeof(display), "%s (✓)", name);
                else
                    Format(display, sizeof(display), "%s", name);
                
                return RedrawMenuItem(display);
            }
        }
        case MenuAction_DrawItem:
        {
            if(IsClientInGame(client))
            {
                char info[32];
                menu.GetItem(selection, SZF(info));
                
                int skinId = StringToInt(info);

                if(g_iGloves[client][g_iTeam[client]] == skinId)
                    return ITEMDRAW_DISABLED;
                else
                    return ITEMDRAW_DEFAULT;
            }
        }
        case MenuAction_Cancel:
        {
            if(IsClientInGame(client) && selection == MenuCancel_ExitBack)
            {
                CreateGlovesCountMenu(client);
            }
        }
    }
    return 0;
}

public Action ResetGlovesTimer(Handle timer, DataPack pack)
{
	ResetPack(pack);
	int clientIndex = pack.ReadCell();
	int activeWeapon = pack.ReadCell();
	
	if(IsClientInGame(clientIndex) && IsValidEntity(activeWeapon))
	{
		SetEntPropEnt(clientIndex, Prop_Send, "m_hActiveWeapon", activeWeapon);
	}
}

/*  STICKERS */
void ShowWeaponStickersMenu(int client, const char[] search = "")
{
    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%t", "Need Alive");
        return;
    }

    int weapon = eItems_GetActiveWeapon(client);
    if (!eItems_IsValidWeapon(weapon))
    {
        CPrintToChat(client, "%t", "Invalid Stickers Weapon");
        return;
    }

    CEconItemView pItem = PTaH_GetEconItemViewFromEconEntity(weapon);
    int slots = pItem.GetItemDefinition().GetNumSupportedStickerSlots();
    if (slots <= 0)
    {
        CPrintToChat(client, "%t", "Invalid Stickers Weapon");
        return;
    }

    int index = eItems_GetWeaponNumByWeapon(weapon);
    if (index < 0)
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    g_tempIndex[client] = index;
    g_tempMaxSlots[client] = slots;
    strcopy(g_tempSearch[client], MAX_LENGTH_CLASSNAME, search);

    Menu menu = new Menu(MenuHandler_Menu_WeaponStickers);
    menu.SetTitle("%T", "Menu Stickers Title", client);
    
    for (int i = 0; i < slots; i++)
    {
        static char slot[16];
        IntToString(i, slot, sizeof(slot));
        
        if (g_PlayerWeapon[client][index].Sticker[i] != 0)
        {
            char sBuffer[64];
            eItems_GetStickerDisplayNameByDefIndex(g_PlayerWeapon[client][index].Sticker[i], SZF(sBuffer))
            AddMenuItemFormat(menu, slot, _, "Slot %i\n  -> %s.", i, sBuffer);
        }
        else
        {
            AddMenuItemFormat(menu, slot, _, "Slot %i\n  -> %T.", i, "None Sticker", client);
        }
    }

    menu.AddItem("x", "", ITEMDRAW_SPACER);
    AddMenuItemFormat(menu, "99", _, "%T.", "All Slots", client);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}


public int MenuHandler_Menu_WeaponStickers(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (g_tempIndex[client] < 0)
        {
            ShowWeaponStickersMenu(client);
            return;
        }
        
        char buffer[16];
        menu.GetItem(param, buffer, sizeof(buffer));

        g_tempSlot[client] = StringToInt(buffer);

        if (strlen(g_tempSearch[client]) > 2)
        {
            ShowWeaponStickersSetMenu(client, g_tempSlot[client], -1, g_tempSearch[client]);
        }
        else
        {
            ShowWeaponStickerSlotMenu(client, g_tempSlot[client]);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        ResetClientTempVars(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

static void ShowWeaponStickerSlotMenu(int client, int slot)
{
    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%t", "Need Alive");
        return;
    }

    int weapon = eItems_GetActiveWeapon(client);
    if (!eItems_IsValidWeapon(weapon))
    {
        CPrintToChat(client, "%t", "Invalid Stickers Weapon");
        return;
    }

    int weaponIndex = eItems_GetWeaponNumByWeapon(weapon);
    if (weaponIndex < 0 || weaponIndex != g_tempIndex[client])
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    char weaponName[MAX_LENGTH_DISPLAY];
    if (!eItems_GetWeaponDisplayNameByWeaponNum(weaponIndex, weaponName, sizeof(weaponName)))
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    Menu menu = new Menu(MenuHandler_Menu_StickerSlot);
    if (slot != ALL_SLOTS && g_PlayerWeapon[client][weaponIndex].Sticker[slot] != 0)
    {
        char stickerName[MAX_LENGTH_DISPLAY];
        eItems_GetStickerDisplayNameByDefIndex(g_PlayerWeapon[client][weaponIndex].Sticker[slot], stickerName, sizeof(stickerName));
        menu.SetTitle("%T", "Menu Stickers Slot Already Title", client, weaponName, slot, stickerName);
    }
    else
    {
        menu.SetTitle("%T", slot == ALL_SLOTS ? "Menu Stickers Slot Title AllSlots" : "Menu Stickers Slot Title", client, weaponName, slot);
    }

    AddMenuItemFormat(menu, "-1", _, "%T", "Menu Stickers Slot Remove", client);

    for (int i = g_stickerSetsCount - 1; i >= 0; i--)
    {
        static char index[16];
        char sBuffer[64];
        IntToString(i, index, sizeof(index));
        eItems_GetStickerSetDisplayNameByStickerSetNum(i, SZF(sBuffer));
        menu.AddItem(index, sBuffer);
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, g_menuSite[client], MENU_TIME_FOREVER);
}

public int MenuHandler_Menu_StickerSlot(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (g_tempIndex[client] < 0)
        {
            ShowWeaponStickersMenu(client);
            return;
        }

        char buffer[32];
        menu.GetItem(param, buffer, sizeof(buffer));

        int index = StringToInt(buffer);
        if (index == -1)
        {
            if (g_tempSlot[client] == ALL_SLOTS)
            {
                for (int i = 0; i < g_tempMaxSlots[client]; i++)
                {
                    g_PlayerWeapon[client][g_tempIndex[client]].Sticker[i] = 0;
                    UpdateClientStickersData(client, g_tempIndex[client], i);
                }
            }
            else
            {
                g_PlayerWeapon[client][g_tempIndex[client]].Sticker[g_tempSlot[client]] = 0;
                UpdateClientStickersData(client, g_tempIndex[client], g_tempSlot[client]);
            }

            g_isStickerRefresh[client] = true;
            RefreshClientWeapon(client, g_tempIndex[client]);

            // Announce.
            char weaponName[MAX_LENGTH_DISPLAY];
            eItems_GetWeaponDisplayNameByWeaponNum(g_tempIndex[client], weaponName, sizeof(weaponName));

            if (g_tempSlot[client] == ALL_SLOTS)
            {
                CPrintToChat(client, "%t", "Remove Sticker AllSlots", weaponName);
            }
            else
            {
                CPrintToChat(client, "%t", "Remove Sticker", weaponName, g_tempSlot[client]);
            }

            // Reopen menu.
            g_menuSite[client] = GetMenuSelectionPosition();
            ShowWeaponStickerSlotMenu(client, g_tempSlot[client]);
        }
        else
        {
            ShowWeaponStickersSetMenu(client, g_tempSlot[client], index);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        ResetClientTempVars(client);

        if (param == MenuCancel_ExitBack)
        {
            ShowWeaponStickersMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

static void ShowWeaponStickersSetMenu(int client, int slot, int stickerSet, const char[] search = "")
{
    if (!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%t", "Need Alive");
        return;
    }

    int weapon = eItems_GetActiveWeapon(client);
    if (!IsValidEntity(weapon))
    {
        CPrintToChat(client, "%t", "Invalid Stickers Weapon");
        return;
    }
    
    int weaponIndex = eItems_GetWeaponNumByWeapon(weapon);
    if (weaponIndex < 0 || weaponIndex != g_tempIndex[client])
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    if (strlen(search) < 2 && stickerSet < 0)
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    char weaponName[MAX_LENGTH_DISPLAY];
    if (!eItems_GetWeaponDisplayNameByWeaponNum(weaponIndex, weaponName, sizeof(weaponName)))
    {
        CPrintToChat(client, "%t", "Validate Error");
        return;
    }

    Menu menu = new Menu(MenuHandler_Menu_StickerSet);
    int count;

    // Add stickers to menu.
    if (strlen(search) > 2)
    {
        if (slot != ALL_SLOTS && g_PlayerWeapon[client][weaponIndex].Sticker[slot] != 0)
        {
            char stickerName[MAX_LENGTH_DISPLAY];
            eItems_GetStickerDisplayNameByDefIndex(g_PlayerWeapon[client][weaponIndex].Sticker[slot], stickerName, sizeof(stickerName));
            menu.SetTitle("%T", "Menu Stickers Set Search Already Title", client, weaponName, slot, stickerName, search);
        }
        else
        {
            menu.SetTitle("%T", slot == ALL_SLOTS ? "Menu Stickers Set Search Title AllSlots" : "Menu Stickers Set Search Title", client, weaponName, slot, search);
        }

        for (int i = 0; i < g_stickerCount; i++)
        {
            char sBuffer[64];
            eItems_GetStickerDisplayNameByStickerNum(i, SZF(sBuffer))
            if (StrContains(sBuffer, search, false) == -1)
            {
                continue;
            }

            count++;

            static char index[16];
            IntToString(i, index, sizeof(index));
            menu.AddItem(index, sBuffer);
        }
    }
    else
    {
        char sBuffer[64];
        eItems_GetStickerSetDisplayNameByStickerSetNum(stickerSet, SZF(sBuffer));
        if (slot != ALL_SLOTS && g_PlayerWeapon[client][weaponIndex].Sticker[slot] != 0)
        {
            char stickerName[MAX_LENGTH_DISPLAY];
            eItems_GetStickerDisplayNameByDefIndex(g_PlayerWeapon[client][weaponIndex].Sticker[slot], stickerName, sizeof(stickerName));
            menu.SetTitle("%T", "Menu Stickers Set Already Title", client, weaponName, slot, stickerName, sBuffer);
        }
        else
        {
            menu.SetTitle("%T", slot == ALL_SLOTS ? "Menu Stickers Set Title AllSlots" : "Menu Stickers Set Title", client, weaponName, slot, sBuffer);
        }

        for (int i = 0; i < g_stickerCount; i++)
        {
            if (eItems_IsStickerInSet(stickerSet, i))
			{
                static char index[16];
                IntToString(i, index, sizeof(index));
                eItems_GetStickerDisplayNameByStickerNum(i, SZF(sBuffer));
                menu.AddItem(index, sBuffer);
            }
        }
    }

    if (!count && strlen(search) > 2)
    {
        AddMenuItemFormat(menu, "-1", ITEMDRAW_DISABLED, "%T", "Menu Stickers Slot Search None", client);
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, g_menuSite[client], MENU_TIME_FOREVER);
}

public int MenuHandler_Menu_StickerSet(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (g_tempIndex[client] < 0)
        {
            ShowWeaponStickersMenu(client);
            return;
        }

        char buffer[32];
        menu.GetItem(param, buffer, sizeof(buffer));

        int stickerIndex = StringToInt(buffer);
        if (stickerIndex < 0)
        {
            ShowWeaponStickersMenu(client);
            return;
        }

        int stickerSet = 0;
        for(int i = 0; i < g_stickerSetsCount; i++)
        {
            if(eItems_IsStickerInSet(i, stickerIndex))
                stickerSet = i;
        }
        if (stickerSet < 0)
        {
            ShowWeaponStickersMenu(client);
            return;
        }

        if (g_tempSlot[client] == ALL_SLOTS)
        {
            for (int i = 0; i < g_tempMaxSlots[client]; i++)
            {
                g_PlayerWeapon[client][g_tempIndex[client]].Sticker[i] = eItems_GetStickerDefIndexByStickerNum(stickerIndex);
                UpdateClientStickersData(client, g_tempIndex[client], i);
            }
        }
        else
        {
            g_PlayerWeapon[client][g_tempIndex[client]].Sticker[g_tempSlot[client]] = eItems_GetStickerDefIndexByStickerNum(stickerIndex);
            UpdateClientStickersData(client, g_tempIndex[client], g_tempSlot[client]);
        }

        g_isStickerRefresh[client] = true;
        RefreshClientWeapon(client, g_tempIndex[client]);

        // Announce.
        char weaponName[MAX_LENGTH_DISPLAY];
        eItems_GetWeaponDisplayNameByWeaponNum(g_tempIndex[client], weaponName, sizeof(weaponName));

        if (g_tempSlot[client] == ALL_SLOTS)
        {
            char sBuffer[64];
            eItems_GetStickerDisplayNameByStickerNum(stickerIndex, SZF(sBuffer))
            CPrintToChat(client, "%t", "Change Sticker AllSlots", sBuffer, weaponName);
        }
        else
        {
            char sBuffer[64];
            eItems_GetStickerDisplayNameByStickerNum(stickerIndex, SZF(sBuffer))
            CPrintToChat(client, "%t", "Change Sticker", sBuffer, weaponName, g_tempSlot[client]);
        }

        // Reopen menu.
        g_menuSite[client] = GetMenuSelectionPosition();
        ShowWeaponStickersSetMenu(client, g_tempSlot[client], stickerSet, g_tempSearch[client]);
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_ExitBack)
        {
            if (strlen(g_tempSearch[client]) > 2)
            {
                ResetClientTempVars(client);
                ShowWeaponStickersMenu(client);
            }
            else
            {
                ShowWeaponStickerSlotMenu(client, g_tempSlot[client]);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

static void ResetClientTempVars(int client)
{
    g_menuSite[client] = 0;
    g_tempSlot[client] = -1;
    g_tempMaxSlots[client] = 0;
    g_tempIndex[client] = -1;
    g_tempSearch[client][0] = '\0';
}