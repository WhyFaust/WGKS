public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		if(g_bEnableStatTrak)
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
	else if(IsValidClient(client))
	{
		g_iIndex[client] = 0;
		g_FloatTimer[client] = INVALID_HANDLE;
		g_bWaitingForNametag[client] = false;
		HookPlayer(client);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if(IsValidClient(client))
	{
		GetPlayerData(client);
	}
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client)) 
	{
		if(g_bEnableStatTrak)
			SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	}
	else if(IsValidClient(client))
	{
		UnhookPlayer(client);
		for(int i = 0; i < g_iWeaponsCount; i++)
		{
			g_PlayerWeapon[client][i].Weapon.Skin = 0;
			g_PlayerWeapon[client][i].Weapon.Float = 0.0;
			g_PlayerWeapon[client][i].Weapon.StatTrak = 0;
			g_PlayerWeapon[client][i].Weapon.StatTrakCount = 0;
			g_PlayerWeapon[client][i].Weapon.NameTag[0] = '\0';
			g_PlayerWeapon[client][i].Weapon.Skins[0] = '\0';
		}
		g_iKnife[client] = -1;
	}
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientDisconnect(i);
		}
	}
}
