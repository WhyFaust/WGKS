stock int GetWeaponEntityIndexByClassname(int iClient, char[] sWeapon_Classname)
{
    for (int i = 0; i < 4; i++)
    {
        int iWeapon_Entity_Index = GetPlayerWeaponSlot(iClient, i);
        
        if (iWeapon_Entity_Index != -1)
        {
            int iEntity = -1;
            
            while ((iEntity = FindEntityByClassname(iEntity, sWeapon_Classname)) != INVALID_ENT_REFERENCE)
            {
                if (iWeapon_Entity_Index == iEntity)
                    return iEntity;
            }
        }
    }
    
    return -1;
}

stock bool ClientWeaponHasStickers(int client, int defIndex)
{
	int index = eItems_GetWeaponNumByDefIndex(defIndex);
	if (index < 0)
	{
		return false;
	}

	for (int i = 0; i < MAX_STICKERS_SLOT; i++)
	{
		if (g_PlayerWeapon[client][index].Sticker[i] != 0)
		{
			return true;
		}
	}
	return false;
}

stock void FindGameConfOffset(Handle gameConf, int &offset, char[] key)
{
	if ((offset = GameConfGetOffset(gameConf, key)) == -1)
	{
		SetFailState("Failed to get \"%s\" offset.", key);
	}
}

stock int FindSendPropOffset(char[] cls, char[] prop)
{
	int offset;
	if ((offset = FindSendPropInfo(cls, prop)) < 1)
	{
		SetFailState("Failed to find prop: \"%s\" on \"%s\" class.", prop, cls);
	}
	return offset;
}

stock bool SetAttributeValue(int client, Address pEconItemView, int attrValue, const char[] format, any ...)
{
	char attr[254];
	VFormat(attr, sizeof(attr), format, 5);

	Address pAttributeDef = SDKCall(g_SDKGetAttributeDefinitionByName, g_pItemSchema, attr);
	if (pAttributeDef == Address_Null)
	{
		PrintToChat(client, "[SM] Invalid item attribute definition, contact an administrator.");
		return false;
	}

	// Get item attribute list.
	Address pAttributeList = pEconItemView + view_as<Address>(g_networkedDynamicAttributesOffset);

	// Get attribute data.
	int attrDefIndex = LoadFromAddress(pAttributeDef + view_as<Address>(0x8), NumberType_Int16);
	int attrCount = LoadFromAddress(pAttributeList + view_as<Address>(g_attributeListCountOffset), NumberType_Int32);
	Address pAttrData = DereferencePointer(pAttributeList + view_as<Address>(g_attributeListReadOffset));

	// Checks if the item already has the attribute, then update value.
	int k = 0;
	for (int i = 0; i < attrCount; i++)
	{
		Address pAttribute = pAttrData + view_as<Address>(k);

		int defIndex = LoadFromAddress(pAttribute + view_as<Address>(0x4), NumberType_Int16);
		if (defIndex == attrDefIndex)
		{
			// Checks if the value is different.
			int value = LoadFromAddress(pAttribute + view_as<Address>(0x8), NumberType_Int32);
			if (value != attrValue)
			{
				StoreToAddress(pAttribute + view_as<Address>(0x8), attrValue, NumberType_Int32);
				return true;
			}
			return false;
		}

		// Increment index.
		k += 24;
	}

	Address pAttribute = SDKCall(g_SDKGenerateAttribute, g_pItemSystem, attrDefIndex, view_as<float>(attrValue));
	if (IsValidAddress(pAttribute))
	{
		// Attach attribute in weapon.
		SDKCall(g_SDKAddAttribute, pAttributeList, pAttribute);
		return true;
	}
	return false;
}

stock Address DereferencePointer(Address addr)
{
	return view_as<Address>(LoadFromAddress(addr, NumberType_Int32));
}

stock bool IsValidAddress(Address pAddress)
{
	static Address Address_MinimumValid = view_as<Address>(0x10000);
	if (pAddress == Address_Null)
	{
		return false;
	}
	return unsigned_compare(view_as<int>(pAddress), view_as<int>(Address_MinimumValid)) >= 0;
}

stock int unsigned_compare(int a, int b)
{
	if (a == b)
	{
		return 0;
	}

	if ((a >>> 31) == (b >>> 31))
	{
		return ((a & 0x7FFFFFFF) > (b & 0x7FFFFFFF)) ? 1 : -1;
	}
	return ((a >>> 31) > (b >>> 31)) ? 1 : -1;
}