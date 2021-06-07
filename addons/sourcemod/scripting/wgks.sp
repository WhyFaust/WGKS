#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <PTaH>
#include <autoexecconfig>
#include <eItems>
#include <csgocolors>
#include <wgks>

#undef REQUIRE_PLUGIN
#tryinclude <wgks_fragments>
#define REQUIRE_PLUGIN

#define PLUGIN    "wgks"

#include "wgks/Globals.sp"
#include "wgks/Forwards.sp"
#include "wgks/Hooks.sp"
#include "wgks/Helpers.sp"
#include "wgks/Database.sp"
#include "wgks/Config.sp"
#include "wgks/Cvars.sp"
#include "wgks/Menus.sp"
#include "wgks/CMD.sp"
#include "wgks/Natives.sp"
#include "wgks/Stocks.sp"

public Plugin myinfo = 
{
	name = "Weapons & Gloves & Knives & Stikers",
	author = "BaFeR",
	description = "All in one weapon skin management",
	version = WGKS_VERSION
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("Only CS:GO servers are supported!");
		return;
	}
	
	if(PTaH_Version() < 101000)
	{
		char sBuf[16];
		PTaH_Version(sBuf, sizeof(sBuf));
		SetFailState("PTaH extension needs to be updated. (Installed Version: %s - Required Version: 1.1.0+) [ Download from: https://ptah.zizt.ru ]", sBuf);
		return;
	}
	
	LoadTranslations("wgks.phrases");

	ReadConfig();
	Cvars_Setup();
	CMD_Setup();
	
	PTaH(PTaH_GiveNamedItemPre, Hook, GiveNamedItemPre);
	PTaH(PTaH_GiveNamedItemPost, Hook, GiveNamedItemPost);
	
	ConVar g_cvGameType = FindConVar("game_type");
	ConVar g_cvGameMode = FindConVar("game_mode");
	
	if(g_cvGameType.IntValue == 1 && g_cvGameMode.IntValue == 2)
	{
		PTaH(PTaH_WeaponCanUsePre, Hook, WeaponCanUsePre);
	}

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

	LoadSDK();

	AddCommandListener(ChatListener, "say");
	AddCommandListener(ChatListener, "say2");
	AddCommandListener(ChatListener, "say_team");
}

public void OnAllPluginsLoaded()
{
	DB_OnPluginStart();
	g_bFragmentsLoaded = LibraryExists("wgks_fragments");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "wgks_fragments"))
	{
		g_bFragmentsLoaded = false;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "wgks_fragments"))
	{
		g_bFragmentsLoaded = true;
	}
}

void LoadSDK()
{	
	Handle gameConf = LoadGameConfigFile("csgo_weaponstickers.games");

	if (gameConf == null)
	{
		SetFailState("Game config was not loaded right.");
		return;
	}

	// Get Server Platform.
	g_ServerPlatform = view_as<ServerPlatform>(GameConfGetOffset(gameConf, "ServerPlatform"));
	if (g_ServerPlatform == OS_Mac || g_ServerPlatform == OS_Unknown)
	{
		SetFailState("Only Linux/Windows support!");
		return;
	}

	// Setup CEconItem::GetItemDefinition.
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Virtual, "CEconItem::GetItemDefinition");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	if (!(g_SDKGetItemDefinition = EndPrepSDKCall()))
	{
		SetFailState("Method \"CEconItem::GetItemDefinition\" was not loaded right.");
		return;
	}

	// Setup CEconItemDefinition::GetNumSupportedStickerSlots.
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Virtual, "CEconItemDefinition::GetNumSupportedStickerSlots");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	if (!(g_SDKGetNumSupportedStickerSlots = EndPrepSDKCall()))
	{
		SetFailState("Method \"CEconItemDefinition::GetNumSupportedStickerSlots\" was not loaded right.");
		return;
	}

	// Setup ItemSystem.
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "ItemSystem");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	Handle SDKItemSystem;
	if (!(SDKItemSystem = EndPrepSDKCall()))
	{
		SetFailState("Method \"ItemSystem\" was not loaded right.");
		return;
	}

	g_pItemSystem = SDKCall(SDKItemSystem);
	if (g_pItemSystem == Address_Null)
	{
		SetFailState("Failed to get \"ItemSystem\" pointer address.");
		return;
	}

	delete SDKItemSystem;
	g_pItemSchema = g_pItemSystem + view_as<Address>(4);

	// Setup CAttributeList::AddAttribute.
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "CAttributeList::AddAttribute");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);

	if (g_ServerPlatform == OS_Windows)
	{
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	}

	if (!(g_SDKAddAttribute = EndPrepSDKCall()))
	{
		SetFailState("Method \"CAttributeList::AddAttribute\" was not loaded right.");
		return;
	}

	// Linux only.
	if (g_ServerPlatform == OS_Linux)
	{
		// Setup CEconItemSystem::GenerateAttribute.
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "CEconItemSystem::GenerateAttribute");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

		if (!(g_SDKGenerateAttribute = EndPrepSDKCall()))
		{
			SetFailState("Method \"CEconItemSystem::GenerateAttribute\" was not loaded right.");
			return;
		}
	}

	// Setup CEconItemSchema::GetAttributeDefinitionByName.
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(gameConf, SDKConf_Signature, "CEconItemSchema::GetAttributeDefinitionByName");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);

	if (!(g_SDKGetAttributeDefinitionByName = EndPrepSDKCall()))
	{
		SetFailState("Method \"CEconItemSchema::GetAttributeDefinitionByName\" was not loaded right.");
		return;
	}

	// Get Offsets.
	FindGameConfOffset(gameConf, g_networkedDynamicAttributesOffset, "m_NetworkedDynamicAttributesForDemos");
	FindGameConfOffset(gameConf, g_attributeListReadOffset, "CAttributeList_Read");
	FindGameConfOffset(gameConf, g_attributeListCountOffset, "CAttributeList_Count");

	delete gameConf;

	// Find netprops Offsets.
	g_econItemOffset = FindSendPropOffset("CBaseCombatWeapon", "m_Item");
}

public void eItems_OnItemsSynced()
{
	g_iWeaponsCount = eItems_GetWeaponCount();

	g_iPaintsCount = eItems_GetPaintsCount()

	g_iGlovesCount = eItems_GetGlovesCount();

	g_stickerCount = eItems_GetStickersCount();
	g_stickerSetsCount = eItems_GetStickersSetsCount();
}

public Action Command_Stickers(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (args != 0)
	{
		char arg[MAX_LENGTH_CLASSNAME];
		GetCmdArgString(arg, sizeof(arg));

		if (strlen(arg) < 2)
		{
			CPrintToChat(client, "%t", "Min Length Search");
			return Plugin_Handled;
		}

		ShowWeaponStickersMenu(client, arg);
	}
	else
	{
		ShowWeaponStickersMenu(client);
	}
	return Plugin_Handled;
}