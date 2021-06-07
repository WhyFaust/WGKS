public void ReadConfig()
{
    KeyValues ConfigSettings = new KeyValues("Setting");
    char sBuffer[256];
    BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/wgks/settings.txt");
    ConfigSettings.ImportFromFile(sBuffer);
    ConfigSettings.Rewind();
    g_bWeaponsEnable = ConfigSettings.GetNum("weapons");
    g_iWeaponsMode = ConfigSettings.GetNum("weapons_mode");
    g_bOverwriteEnabled = ConfigSettings.GetNum("overwrite");

    g_bEnableFloat = ConfigSettings.GetNum("float");
    g_fFloatIncrementSize = ConfigSettings.GetFloat("float_increment_size");
    g_iFloatIncrementPercentage = RoundFloat(g_fFloatIncrementSize * 100.0);

    g_bEnableNameTag = ConfigSettings.GetNum("nametag");
    
    g_bEnableStatTrak = ConfigSettings.GetNum("stattrak");
    g_iKnifeStatTrakMode = ConfigSettings.GetNum("knife_stattrak_mode");

    g_iGracePeriod = ConfigSettings.GetNum("grace_period");
    if(g_iGracePeriod > 0)
    {
        HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    }

    g_iGraceInactiveDays = ConfigSettings.GetNum("inactive_days");

    g_bGlovesEnable = ConfigSettings.GetNum("gloves");
    g_bEnableWorldModel = ConfigSettings.GetNum("gloves_world_model");


    g_bStikersEnable = ConfigSettings.GetNum("stikers");
    
    g_bKnifesEnable = ConfigSettings.GetNum("knifes");
    g_bKnifeMode = ConfigSettings.GetNum("knife_mode", 0);
}
