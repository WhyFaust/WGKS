#pragma semicolon 1
#include <sourcemod>
#include <shop>
#include <eItems>
#include <wgks_fragments>

#pragma newdecls required

public Plugin myinfo = 
{
    name = "[Shop] Fragments",
    author = "Faust",
    version = "1.0"
}

public void OnPluginStart()
{
    if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
    Shop_UnregisterMe();
}

public void Shop_Started()
{
    char sBuffer[PLATFORM_MAX_PATH];
    
    KeyValues hKeyValues = new KeyValues("Fragments_Shop");
    
    Shop_GetCfgFile(sBuffer, sizeof(sBuffer), "fragments_shop.txt");
    
    if (!hKeyValues.ImportFromFile(sBuffer)) SetFailState("Не удалось открыть файл '%s'", sBuffer);

    if(hKeyValues.GotoFirstSubKey(false))
    {
        CategoryId category = Shop_RegisterCategory("fragments_shop", "Фрагменты", "");
        char sWeaponNumStr[4];
        int iFragmentPrice;
        do
        {
            hKeyValues.GetSectionName(sWeaponNumStr, sizeof(sWeaponNumStr));
            int iWeaponNum = StringToInt(sWeaponNumStr);
            if (Shop_StartItem(category, sWeaponNumStr))
            {
                iFragmentPrice = hKeyValues.GetNum(NULL_STRING);
                char sName[64];
                eItems_GetWeaponDisplayNameByWeaponNum(iWeaponNum, sName, sizeof(sName));
                Format(sBuffer, sizeof(sBuffer), "Осколок на %s", sName);

                Shop_SetInfo(sBuffer, "", iFragmentPrice, -1, Item_Finite, 0);
                Shop_SetCallbacks(_, OnItemBuy);
                Shop_EndItem();
            }
        } while (hKeyValues.GotoNextKey(false));
    }
    
    delete hKeyValues;
}

public ShopAction OnItemBuy(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
    int iKnifeIndex = StringToInt(item);
    int iFragmentsCount = Fragments_GetClientKnifeCountFragments(iClient, iKnifeIndex);
    Fragments_SetClientKnifeCountFragments(iClient, iKnifeIndex, iFragmentsCount+1);

    return Shop_UseOn;
}