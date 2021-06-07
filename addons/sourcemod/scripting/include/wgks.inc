#if defined _wgks_included_
  #endinput
#endif
#define _wgks_included_

#define WGKS_VERSION "1.4 [PRIVATE]"

bool IsValidClient(int iClient, bool bAllowBots = false, bool bAllowDead = true)
{
	if (!(1 <= iClient <= MaxClients) || !IsClientInGame(iClient) || (IsFakeClient(iClient) && !bAllowBots) || IsClientSourceTV(iClient) || IsClientReplay(iClient) || (!bAllowDead && !IsPlayerAlive(iClient)))
		return false;
	return true;
}

/**
 *	Получает Handle базы данных. После работы необходимо закрыть с помощью CloseHandle() или delete
 *
 *	@noparams
 *
 *	@return					Database (Handle) базы данных
*/
native Database WGKS_GetDatabase();

/**
 *	Получает тип базы данных.
 *
 *	@noparams
 *
 * @return					true - MySQL.
 * 							false - SQLite.
*/
native bool WGKS_GetDatabaseType();

native void Weapons_GiveClientSkin(int client, int weaponIndex, int skinDefIndex);

native bool Gloves_IsClientUsingGloves(int client);

native void Gloves_RegisterCustomArms(int client, const char[] armsModel);

native void Gloves_SetArmsModel(int client, const char[] armsModel);

native void Gloves_GetArmsModel(int client, char[] armsModel, int size);

native void Gloves_GiveClientGloves(int client, int index);

public SharedPlugin __pl_wgks=
{
	name = "wgks",
	file = "wgks.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_wgks_SetNTVOptional()
{
	MarkNativeAsOptional("WGKS_GetDatabase");
	MarkNativeAsOptional("WGKS_GetDatabaseType");
	MarkNativeAsOptional("Weapons_GetClientKnife");
	MarkNativeAsOptional("Weapons_SetClientKnife");
	MarkNativeAsOptional("Weapons_GiveClientSkin");
	MarkNativeAsOptional("Gloves_IsClientUsingGloves");
	MarkNativeAsOptional("Gloves_RegisterCustomArms");
	MarkNativeAsOptional("Gloves_SetArmsModel");
	MarkNativeAsOptional("Gloves_GetArmsModel");
	MarkNativeAsOptional("Gloves_GiveClientGloves");
}
#endif