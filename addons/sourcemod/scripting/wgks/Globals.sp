#define GLOBAL_INFO			g_iClientInfo[0]

#define SZF(%0) 			%0, sizeof(%0)
#define SZFA(%0,%1)         %0[%1], sizeof(%0[])

#define SET_BIT(%0,%1) 		%0 |= %1
#define UNSET_BIT(%0,%1) 	%0 &= ~%1

#define IS_STARTED					(1<<0)
#define IS_MySQL					(1<<1)
#define IS_LOADING					(1<<2)

int			g_iClientInfo[MAXPLAYERS+1];

int g_iWeaponsCount = 0;

int g_iPaintsCount = 0;

int g_iGlovesCount = 0;

int g_stickerCount = 0;
int g_stickerSetsCount = 0;

bool g_bFragmentsLoaded;

int g_ClientKnifeAmount[MAXPLAYERS+1][128];

Database g_hDatabase;

char g_TablePrefix[10];
char g_ChatPrefix[32];

float g_fFloatIncrementSize;
int g_iFloatIncrementPercentage;

int g_iKnifeStatTrakMode;

int g_bEnableFloat;

int g_bEnableNameTag;

int g_bEnableStatTrak;

int g_bOverwriteEnabled;

int g_iGracePeriod;

int g_iGraceInactiveDays;

int g_bEnableWorldModel;

int g_bWeaponsEnable;
int g_iWeaponsMode;

int g_bGlovesEnable;
int g_bStikersEnable;

int g_bKnifesEnable;
int g_bKnifeMode;

//int g_iSkins[MAXPLAYERS+1][sizeof(g_WeaponClasses)];
//int g_iStatTrak[MAXPLAYERS+1][sizeof(g_WeaponClasses)];
//int g_iStatTrakCount[MAXPLAYERS+1][sizeof(g_WeaponClasses)];
//int g_iWeaponSeed[MAXPLAYERS+1][sizeof(g_WeaponClasses)];
//char g_NameTag[MAXPLAYERS+1][sizeof(g_WeaponClasses)][128];
//float g_fFloatValue[MAXPLAYERS+1][sizeof(g_WeaponClasses)];
//char g_sSkins[MAXPLAYERS+1][sizeof(g_WeaponClasses)][1024];

#define MAX_WEAPONS				128
#define MAX_PAINTS				64
#define MAX_STICKERS			5000
#define MAX_STICKERS_SETS		24
#define MAX_STICKERS_SLOT		6

enum struct WeaponFunc
{
	int Skin;
	float Float;
	int StatTrak;
	int StatTrakCount;
	char NameTag[128];
	char Skins[1024];
	// TODO: wear and rotation
}

enum struct PlayerWeapon
{
	int Sticker[MAX_STICKERS_SLOT];
	int Knife;
	WeaponFunc Weapon;
	// TODO: wear and rotation
}
PlayerWeapon g_PlayerWeapon[MAXPLAYERS + 1][MAX_WEAPONS];

int g_iGroup[MAXPLAYERS+1][4];
int g_iGloves[MAXPLAYERS+1][4];
char g_CustomArms[MAXPLAYERS+1][4][256];
int g_iTeam[MAXPLAYERS+1] = { 0, ... };
//int g_iSteam32[MAXPLAYERS+1] = { 0, ... };
char g_sGloves[MAXPLAYERS+1][256];

int g_iIndex[MAXPLAYERS+1] = { 0, ... };
Handle g_FloatTimer[MAXPLAYERS+1] = { INVALID_HANDLE, ... };

bool g_bWaitingForNametag[MAXPLAYERS+1] = { false, ... };
bool g_bWaitingForSeed[MAXPLAYERS+1] = { false, ... };

int g_iKnife[MAXPLAYERS+1] = {-1, ... };

int g_iRoundStartTime = 0;

#define MAX_LENGTH_AUTHID		64
#define MAX_LENGTH_CLASSNAME 	32
#define MAX_LENGTH_DISPLAY		128
#define MAX_LENGTH_INDEX		16

bool g_isStickerRefresh[MAXPLAYERS + 1] = {false, ...};

enum ServerPlatform
{
	OS_Unknown = 0,
	OS_Windows,
	OS_Linux,
	OS_Mac
}
ServerPlatform g_ServerPlatform;

/* SDK */
Address g_pItemSystem = Address_Null;
Address g_pItemSchema = Address_Null;

// SDKCalls
Handle g_SDKGetItemDefinition = null;
Handle g_SDKGetNumSupportedStickerSlots = null;
Handle g_SDKAddAttribute = null;
Handle g_SDKGenerateAttribute = null;
Handle g_SDKGetAttributeDefinitionByName = null;

// Offsets
int g_networkedDynamicAttributesOffset = -1;
int g_attributeListReadOffset = -1;
int g_attributeListCountOffset = -1;
int g_econItemOffset = -1;

// Stickers
#define ALL_SLOTS 99

int g_menuSite[MAXPLAYERS + 1] = {0, ...};
int g_tempSlot[MAXPLAYERS + 1] = {-1, ...};
int g_tempMaxSlots[MAXPLAYERS + 1] = {0, ...};
int g_tempIndex[MAXPLAYERS + 1] = {-1, ...};
char g_tempSearch[MAXPLAYERS +1][MAX_LENGTH_CLASSNAME];