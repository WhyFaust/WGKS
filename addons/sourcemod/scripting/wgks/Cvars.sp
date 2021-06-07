void Cvars_Setup()
{
	AutoExecConfig_SetFile("wgks");

	ConVar hCvar = AutoExecConfig_CreateConVar("sm_wgks_table_prefix", 			"", 				"Prefix for database table (example: 'xyz_')");
	hCvar.AddChangeHook(OnTablePrefixChange);
	hCvar.GetString(g_TablePrefix, sizeof(g_TablePrefix));

	hCvar = AutoExecConfig_CreateConVar("sm_wgks_chat_prefix", 			"[WGKS]", 	"Prefix for chat messages");
	hCvar.AddChangeHook(OnChatPrefixChange);
	hCvar.GetString(g_ChatPrefix, sizeof(g_ChatPrefix));

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void OnTablePrefixChange(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	hCvar.GetString(g_TablePrefix, sizeof(g_TablePrefix));
}

public void OnChatPrefixChange(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
	hCvar.GetString(g_ChatPrefix, sizeof(g_ChatPrefix));
}
