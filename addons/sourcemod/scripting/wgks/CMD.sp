void CMD_Setup()
{
	RegConsoleCmd("buyammo1", CommandWeaponSkins);
	RegConsoleCmd("sm_ws", CommandWeaponSkins);
	
	RegConsoleCmd("sm_nametag", CommandNameTag);
	
	RegConsoleCmd("buyammo2", CommandKnife);
	RegConsoleCmd("sm_knife", CommandKnife);

	RegConsoleCmd("sm_gloves", CommandGlove);
	RegConsoleCmd("sm_glove", CommandGlove);
	RegConsoleCmd("sm_gl", CommandGlove);
	RegConsoleCmd("sm_eldiven", CommandGlove);
	
	RegConsoleCmd("sm_sticker", Command_Stickers);
	RegConsoleCmd("sm_stickers", Command_Stickers);

	RegAdminCmd("sm_reload_wgks_cfg", ReloadWGKSCfg_CMD, ADMFLAG_ROOT);
}

/*public void OnConfigsExecuted()
{	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}*/

public Action CommandWeaponSkins(int client, int args)
{
	if (IsValidClient(client))
	{
		CreateMainMenu(client);
	}
	return Plugin_Handled;
}

public Action CommandKnife(int client, int args)
{
	if (IsValidClient(client))
	{
		CreateKnifeMenu(client);
	}
	return Plugin_Handled;
}

public Action CommandGlove(int client, int args)
{
	if (IsValidClient(client))
	{
		CreateGlovesMenu(client).Display(client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public Action CommandNameTag(int client, int args)
{
	if(!g_bEnableNameTag)
	{
		ReplyToCommand(client, " %s \x02%T", g_ChatPrefix, "NameTagDisabled", client);
		return Plugin_Handled;
	}
	ReplyToCommand(client, " %s \x04%T", g_ChatPrefix, "NameTagNew", client);
	return Plugin_Handled;
}

public Action ReloadWGKSCfg_CMD(int iClient, int iArgs)
{
	ReadConfig();
	
	return Plugin_Handled;
}