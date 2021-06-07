public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

	CreateNative("WGKS_GetDatabase", WGKS_GetDatabase_Native);
	CreateNative("WGKS_GetDatabaseType", WGKS_GetDatabase_NativeType);
	
	CreateNative("Weapons_GiveClientSkin", Weapons_GiveClientSkin_Native);
	
	CreateNative("Gloves_IsClientUsingGloves", Native_IsClientUsingGloves);
	CreateNative("Gloves_RegisterCustomArms", Native_RegisterCustomArms);
	CreateNative("Gloves_SetArmsModel", Native_SetArmsModel);
	CreateNative("Gloves_GetArmsModel", Native_GetArmsModel);

	CreateNative("Gloves_GiveClientGloves", Gloves_GiveClientGloves_Native);
	
	MarkNativeAsOptional("Fragments_GetClientKnifeCountFragments");
	MarkNativeAsOptional("Fragments_SetClientKnifeCountFragments");
	MarkNativeAsOptional("Fragments_GetReqKnifeCountFragments");

	RegPluginLibrary("wgks");
	
	return APLRes_Success;
}

public int WGKS_GetDatabase_Native(Handle hPlugin, int iNumParams)
{
	return view_as<int>(CloneHandle(g_hDatabase, hPlugin));
}

public int WGKS_GetDatabase_NativeType(Handle hPlugin, int iNumParams)
{
	return (GLOBAL_INFO & IS_MySQL);
}

public int Weapons_GiveClientSkin_Native(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d).", client);
	}
	if(!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not in game.", client);
	}
	GiveClientSkin(client, GetNativeCell(2), GetNativeCell(3));
	return 0;
}

public int Gloves_GiveClientGloves_Native(Handle plugin, int numparams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d).", client);
	}
	if(!IsClientInGame(client))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Client (%d) is not in game.", client);
	}
	GiveClientGloves(client, GetNativeCell(2));
	return 0;
}

public int Native_IsClientUsingGloves(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	return g_iGloves[clientIndex][playerTeam] != 0;
}

public int Native_RegisterCustomArms(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	GetNativeString(2, g_CustomArms[clientIndex][playerTeam], 256);
}

public int Native_SetArmsModel(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	GetNativeString(2, g_CustomArms[clientIndex][playerTeam], 256);
	if(g_iGloves[clientIndex][playerTeam] == 0)
	{
		SetEntPropString(clientIndex, Prop_Send, "m_szArmsModel", g_CustomArms[clientIndex][playerTeam]);
	}
}

public int Native_GetArmsModel(Handle plugin, int numParams)
{
	int clientIndex = GetNativeCell(1);
	int playerTeam = GetClientTeam(clientIndex);
	int size = GetNativeCell(3);
	SetNativeString(2, g_CustomArms[clientIndex][playerTeam], size);
}