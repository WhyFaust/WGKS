#if defined _wgks_cases_included_
  #endinput
#endif
#define _wgks_cases_included_

forward void WGKS_Cases_CaseOpened(int iClient);

forward void WGKS_Cases_CaseOpen(int iClient, char[] sWeapon, int weaponIndex);

public SharedPlugin __pl_wgks_cases  =
{
	name = "wgks_cases",
	file = "wgks_cases.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};