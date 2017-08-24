#pragma semicolon 1

#define PLUGIN_AUTHOR "Rachnus"
#define PLUGIN_VERSION "1.03"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <emitsoundany>
#include <clientprefs>

#pragma newdecls required

#define FORTWARS_PREFIX " \x09[\x04FortWarsGo\x09]\x01"

#define SOUND_PREPARE_TO_FIGHT "fortwarsgo/prepare_to_fight.mp3"
#define SOUND_FIGHT "fortwarsgo/fight.mp3"
#define SOUND_DENIED "fortwarsgo/denied.mp3"

#define SOUND_ENEMY_FLAG_TAKEN "fortwarsgo/enemy_flag_taken.mp3"
#define SOUND_ENEMY_FLAG_RETURNED "fortwarsgo/enemy_flag_returned.mp3"
#define SOUND_ENEMY_SCORES "fortwarsgo/enemy_scores.mp3"

#define SOUND_YOUR_FLAG_TAKEN "fortwarsgo/your_flag_taken.mp3"
#define SOUND_YOUR_FLAG_RETURNED "fortwarsgo/your_flag_taken.mp3"
#define SOUND_YOUR_TEAM_SCORES "fortwarsgo/your_team_scores.mp3"

#define SOUND_RED_FLAG_TAKEN "fortwarsgo/red_flag_taken.mp3"
#define SOUND_RED_FLAG_RETURNED "fortwarsgo/red_flag_taken.mp3"
#define SOUND_RED_TEAM_SCORES "fortwarsgo/red_scores.mp3"
#define SOUND_RED_WINS "fortwarsgo/red_wins.mp3"

#define SOUND_BLUE_FLAG_TAKEN "fortwarsgo/blue_flag_taken.mp3"
#define SOUND_BLUE_FLAG_RETURNED "fortwarsgo/blue_flag_taken.mp3"
#define SOUND_BLUE_TEAM_SCORES "fortwarsgo/blue_scores.mp3"
#define SOUND_BLUE_WINS "fortwarsgo/blue_wins.mp3"

enum FortWarsGameState
{
	FortWarsGameState_Build = 0,
	FortWarsGameState_Live = 1,
	FortWarsGameState_PostRound = 2
}

EngineVersion g_Game;
bool g_bPressedReload[MAXPLAYERS + 1] =  { false, ... };
bool g_bPressedUse[MAXPLAYERS + 1] =  { false, ... };
bool g_bPressedAttack2[MAXPLAYERS + 1] =  { false, ... };
int g_iActiveProp[MAXPLAYERS + 1] =  { INVALID_ENT_REFERENCE, ... };
int g_iProps[MAXPLAYERS + 1] =  { 0, ... };
int g_iPropRotationCycle[MAXPLAYERS + 1] =  { 0, ... };
int g_iRedScore = 0;
int g_iBlueScore = 0;
int g_iRedMaxProps = 0;
int g_iBlueMaxProps = 0;
int g_iFlagT = INVALID_ENT_REFERENCE;
int g_iFlagCT = INVALID_ENT_REFERENCE;
int g_iFlagTimerT = 0;
int g_iFlagTimerCT = 0;
int g_iSetupTimer = 0;
int g_iPathLaserModelIndex = 0;
float g_fTimeUsedStuck[MAXPLAYERS + 1] =  { 0.0, ... };
float g_fTimeKilled[MAXPLAYERS + 1] =  { 0.0, ... };
float g_fDistance[MAXPLAYERS + 1];
float g_vecFlagPosT[3];
float g_vecFlagPosCT[3];
float g_vecRotate[MAXPLAYERS + 1][3];
float g_vecPropOffset[MAXPLAYERS + 1][3];
char g_szPrimary[MAXPLAYERS + 1][32];
char g_szSecondary[MAXPLAYERS + 1][32];
Handle g_hPrimaryWeapon = INVALID_HANDLE;
Handle g_hSecondaryWeapon = INVALID_HANDLE;
Handle g_hGetBonePosition = INVALID_HANDLE;
Handle g_hLookupBone = INVALID_HANDLE;
Handle g_hFlagTimerT = INVALID_HANDLE;
Handle g_hFlagTimerCT = INVALID_HANDLE;
Handle g_hSetupTimer = INVALID_HANDLE;
Handle g_hMatchTimer = INVALID_HANDLE;

Handle g_hHudSynchT, g_hHudSynchCT;

ArrayList g_hBuildZonesT;
ArrayList g_hBuildZonesCT;

KeyValues g_hProps;

ConVar g_FlagReturnTime;
ConVar g_SetupTime;
ConVar g_MatchTime;
ConVar g_RespawnTime;
ConVar g_AmountOfFlagsToWin;
ConVar g_MoneyPerTeam;
ConVar g_MaxPropsPerTeam;

Handle g_hOnGameStart;
Handle g_hOnFlagPickedUp;
Handle g_hOnFlagDropped;
Handle g_hOnFlagCaptured;
Handle g_hOnFlagReturned;

FortWarsGameState g_eGameState;

#include "fortwarsgo/stocks.sp"
#include "fortwarsgo/natives.sp"
public Plugin myinfo = 
{
	name = "FortWarsGO v1.0",
	author = PLUGIN_AUTHOR,
	description = "Build forts then play Capture The Flag",
	version = PLUGIN_VERSION,
	url = "https://github.com/Rachnus"
};

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
		SetFailState("This plugin is for CSGO.");	
	
	LoadTranslations("common.phrases");
	LoadTranslations("fortwarsgo.phrases");
	
	g_FlagReturnTime = CreateConVar("fortwarsgo_flag_return_time", "30", "The amount of time in seconds it takes until the flag returns to its spawn if its left somewhere", FCVAR_NOTIFY);
	g_SetupTime = CreateConVar("fortwarsgo_setup_time", "3", "The amount of time in minutes each team got to build", FCVAR_NOTIFY);
	g_MatchTime = CreateConVar("fortwarsgo_match_time", "7", "The amount of time in minutes one round lasts", FCVAR_NOTIFY);
	g_RespawnTime = CreateConVar("fortwarsgo_respawn_time", "10", "The amount of time in seconds until player respawns", FCVAR_NOTIFY);
	g_AmountOfFlagsToWin = CreateConVar("fortwarsgo_amount_of_score_to_win", "5", "The amount of score needed to win the round", FCVAR_NOTIFY);
	g_MoneyPerTeam = CreateConVar("fortwarsgo_money_per_team", "30000", "The amount of money that should be split to all players per team", FCVAR_NOTIFY);
	g_MaxPropsPerTeam = CreateConVar("fortwarsgo_max_props_per_team", "700", "The amount of props the team can have", FCVAR_NOTIFY, true, 0.0, true, 800.0);
	
	HookConVarChange(g_SetupTime, ConVar_MatchSetupTime);
	HookConVarChange(g_MatchTime, ConVar_MatchSetupTime);

	RegAdminCmd("sm_reloadprops", Command_ReloadProps, ADMFLAG_ROOT);
	RegConsoleCmd("sm_fw", Command_Build);
	RegConsoleCmd("sm_build", Command_Build);
	RegConsoleCmd("sm_props", Command_Props);
	RegConsoleCmd("sm_remove", Command_Remove);
	RegConsoleCmd("sm_guns", Command_Guns, "Select guns to spawn with");
	RegConsoleCmd("sm_stuck", Command_Stuck, "Respawns player");
	HookEvent("round_poststart", Event_RoundPostStart);
	HookEvent("round_freeze_end", Event_RoundFreezeEnd);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	g_hOnGameStart = CreateGlobalForward("FortWarsGO_OnGameStart", ET_Ignore);
	g_hOnFlagPickedUp = CreateGlobalForward("FortWarsGO_OnFlagPickedUp", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnFlagDropped = CreateGlobalForward("FortWarsGO_OnFlagDropped", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnFlagCaptured = CreateGlobalForward("FortWarsGO_OnFlagCaptured", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnFlagReturned = CreateGlobalForward("FortWarsGO_OnFlagReturned", ET_Ignore, Param_Cell);
	
	g_hPrimaryWeapon = 	RegClientCookie("FWGO_Primary_Weapon", "Primary weapon to equip on round start", CookieAccess_Private);
	g_hSecondaryWeapon = RegClientCookie("FWGO_Secondary_Weapon", "Secondary weapon to equip on round start", CookieAccess_Private);
	
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/fortwarsgo_props.txt");
	g_hProps = new KeyValues("Props");
	
	if(!g_hProps.ImportFromFile(path))
		SetFailState("Could not open %s", path);
	g_hProps.SetEscapeSequences(true);
	
	Handle hConf = LoadGameConfigFile("fortwarsgo.games");
	
	//CBaseAnimating::LookupBone( const char *szName )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupBone");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hLookupBone = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::LookupBone signature!");
	
	
	//void CBaseAnimating::GetBonePosition ( int iBone, Vector &origin, QAngle &angles )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::GetBonePosition");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if ((g_hGetBonePosition = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::GetBonePosition signature!");
	
	g_hHudSynchT = CreateHudSynchronizer();
	g_hHudSynchCT = CreateHudSynchronizer();
	
	g_hBuildZonesT = new ArrayList();
	g_hBuildZonesCT = new ArrayList();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	CreateNative("FortWarsGO_GetFlag", Native_GetFlag);
	CreateNative("FortWarsGO_GetFlagTeam", Native_GetFlagTeam);
	CreateNative("FortWarsGO_GetFlagCarrier", Native_GetFlagCarrier);
	CreateNative("FortWarsGO_GetClientPropCount", Native_GetClientPropCount);
	CreateNative("FortWarsGO_GetClientGrabbedProp", Native_GetClientGrabbedProp);
	CreateNative("FortWarsGO_GetMaxProps", Native_GetMaxProps);
	CreateNative("FortWarsGO_GetScore", Native_GetScore);
	CreateNative("FortWarsGO_GetPropOwner", Native_GetPropOwner);
	CreateNative("FortWarsGO_GetPropPrice", Native_GetPropPrice);
	
	RegPluginLibrary("fortwarsgo");

	return APLRes_Success;
}

public void ConVar_MatchSetupTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(FindConVar("mp_roundtime"), g_MatchTime.IntValue + g_SetupTime.IntValue);
}

public Action Command_Stuck(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Stuck");
		return Plugin_Continue;
	}
		
	if(g_eGameState != FortWarsGameState_Build || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Stuck Build");
		return Plugin_Continue;
	}
	
	float time = 0.0;
	if(g_fTimeUsedStuck[client] != 0.0)
	{
		time = 10.0;
		time -= GetGameTime() - g_fTimeUsedStuck[client];
	}
	
	if(time > 0.0)
	{
		ReplyToCommand(client, "%s \x09%t", FORTWARS_PREFIX, "Stuck Timer", "\x04", RoundToNearest(time), "\x09");
		return Plugin_Handled;
	}
	g_fTimeUsedStuck[client] = GetGameTime();
	CS_RespawnPlayer(client);
	return Plugin_Continue;
}

public Action Command_ReloadProps(int client, int args)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/fortwarsgo_props.txt");
	g_hProps = new KeyValues("Props");
	
	if(!g_hProps.ImportFromFile(path))
		SetFailState("Could not open %s", path);
	g_hProps.SetEscapeSequences(true);
}

public Action Command_Build(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Dead");
		return Plugin_Continue;
	}
		
	if(g_eGameState != FortWarsGameState_Build || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Not Setup");
		return Plugin_Continue;
	}
	
	Menu menu = new Menu(BuildMenuHandler);
	menu.SetTitle("FortWarsGO");
	
	char szItem[32];
	Format(szItem, sizeof(szItem), "%t", "Props");
	menu.AddItem("", szItem);
	Format(szItem, sizeof(szItem), "%t", "Remove");
	menu.AddItem("", szItem);
	Format(szItem, sizeof(szItem), "%t", "Guns");
	menu.AddItem("", szItem);
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}

public Action Command_Props(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Dead");
		return Plugin_Continue;
	}
		
	if(g_eGameState != FortWarsGameState_Build || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Not Setup");
		return Plugin_Continue;
	}
		
	char szProp[PLATFORM_MAX_PATH + 13];
	char szPropName[32];
	char szMenuItem[32];
	int price, health;
	
	Menu menu = new Menu(PropsMenuHandler);
	char szItem[32];
	Format(szItem, sizeof(szItem), "%t", "Props");
	menu.SetTitle(szItem);
	g_hProps.Rewind();
	if(g_hProps.GotoFirstSubKey())
	{
		do 
		{
			g_hProps.GetSectionName(szPropName, sizeof(szPropName));
			g_hProps.GetString("model", szProp, sizeof(szProp));
			price = g_hProps.GetNum("price", 50);
			health = g_hProps.GetNum("health", 50);
			Format(szMenuItem, sizeof(szMenuItem), "[$%d] %s", price, szPropName);
			Format(szProp, sizeof(szProp), "%s;%d;%d", szProp, price, health);
			menu.AddItem(szProp, szMenuItem);
		} while (g_hProps.GotoNextKey());
	}	
	
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Continue;
}

public Action Command_Remove(int client, int args)
{
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Dead");
		return Plugin_Continue;
	}
		
	if(g_eGameState != FortWarsGameState_Build || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ReplyToCommand(client, "%s \x07%t", FORTWARS_PREFIX, "Cannot Build Not Setup");
		return Plugin_Continue;
	}
		
	int target = GetClientAimTarget(client, false);
	if(target != INVALID_ENT_REFERENCE && target > MAXPLAYERS +1)
		RemoveProp(client, target);
	
	return Plugin_Continue;
}

public Action Command_Guns(int client, int args)
{
	Menu menu = new Menu(GunsMenuHandler);
	char szItem[32];
	Format(szItem, sizeof(szItem), "%t", "Guns");
	menu.SetTitle(szItem);
	Format(szItem, sizeof(szItem), "%t", "Primary");
	menu.AddItem("", szItem);
	Format(szItem, sizeof(szItem), "%t", "Secondary");
	menu.AddItem("", szItem);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Continue;
}

public int GunsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
				{
					Menu primaryMenu = new Menu(PrimaryMenuHandler);
					char szTitle[64];
					Format(szTitle, sizeof(szTitle), "%t", "Primary Menu");
					primaryMenu.SetTitle(szTitle);
					primaryMenu.AddItem("weapon_m4a1;M4A4", "M4A4");
					primaryMenu.AddItem("weapon_m4a1_silencer;M4A1 (Silencer)", "M4A1 (Silencer)");
					primaryMenu.AddItem("weapon_ak47;AK-47", "AK-47");
					primaryMenu.AddItem("weapon_awp;Awp", "Awp");
					primaryMenu.AddItem("weapon_ssg08;Scout (SSG08)", "Scout (SSG08)");
					primaryMenu.AddItem("weapon_aug;Aug", "Aug");
					primaryMenu.AddItem("weapon_sg556;SG556", "SG556");
					primaryMenu.AddItem("weapon_famas;Famas", "Famas");
					primaryMenu.AddItem("weapon_galilar;Galil", "Galil");
					primaryMenu.AddItem("weapon_p90;P90", "P90");
					primaryMenu.AddItem("weapon_ump45;UMP", "UMP-45");
					primaryMenu.AddItem("weapon_mp7;MP7", "MP7");
					primaryMenu.AddItem("weapon_bizon;PP", "PP-Bizon");
					primaryMenu.AddItem("weapon_mac10;MAC-10", "MAC-10");
					primaryMenu.AddItem("weapon_mp8;MP9", "MP9");
					primaryMenu.AddItem("weapon_nova;Nova", "Nova");
					primaryMenu.AddItem("weapon_mag7;Mag-7", "Mag-7");
					primaryMenu.AddItem("weapon_sawedoff;Sawed-Off", "Sawed-Off");
					primaryMenu.AddItem("weapon_xm1014;XM1014", "XM1014");
					primaryMenu.ExitBackButton = true;
					primaryMenu.ExitButton = true;
					primaryMenu.Display(param1, MENU_TIME_FOREVER);
				}
				case 1:
				{
					Menu secondaryMenu = new Menu(SecondaryMenuHandler);
					char szTitle[64];
					Format(szTitle, sizeof(szTitle), "%t", "Secondary Menu");
					secondaryMenu.SetTitle(szTitle);
					secondaryMenu.AddItem("weapon_deagle;Deagle", "Deagle");
					secondaryMenu.AddItem("weapon_p250;P250", "P250");
					secondaryMenu.AddItem("weapon_cz75a;CZ75-Auto", "CZ75-Auto");
					secondaryMenu.AddItem("weapon_elite;Dual Berettas", "Dual Berettas");
					secondaryMenu.AddItem("weapon_tec9;TEC-9", "TEC-9");
					secondaryMenu.AddItem("weapon_revolver;R8-Revolver", "R8-Revolver");
					secondaryMenu.AddItem("weapon_fiveseven;Five-SeveN", "Five-SeveN");
					secondaryMenu.AddItem("weapon_usp_silencer;USP-S", "USP-S");
					secondaryMenu.AddItem("weapon_hkp2000;P2000", "P2000");
					secondaryMenu.AddItem("weapon_glock;Glock", "Glock");
					secondaryMenu.ExitBackButton = true;
					secondaryMenu.ExitButton = true;
					secondaryMenu.Display(param1, MENU_TIME_FOREVER);
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			Command_Build(param1, 0);
		}
	}
	return 0;
}

public int PrimaryMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szInfo[128];
			GetMenuItem(menu, param2, szInfo, sizeof(szInfo));
			char szTempArray[2][32];
			ExplodeString(szInfo, ";", szTempArray, 2, sizeof(szTempArray[]));
			
			g_szPrimary[param1] = szTempArray[0];
			SetClientCookie(param1, g_hPrimaryWeapon, szTempArray[0]); 
			PrintToChat(param1, "%s \x09%t \x04%s", FORTWARS_PREFIX, "Primary Weapon Set", szTempArray[1]);
			if(g_eGameState == FortWarsGameState_Live || GameRules_GetProp("m_bWarmupPeriod") == 1)
				EquipPrefWeapons(param1);
				
			OnClientCookiesCached(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			Command_Guns(param1, 0);
		}
	}
	return 0;
}

public int SecondaryMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szInfo[128];
			GetMenuItem(menu, param2, szInfo, sizeof(szInfo));
			char szTempArray[2][32];
			ExplodeString(szInfo, ";", szTempArray, 2, sizeof(szTempArray[]));
			
			g_szSecondary[param1] = szTempArray[0];
			SetClientCookie(param1, g_hSecondaryWeapon, szTempArray[0]); 
			PrintToChat(param1, "%s \x09%t \x04%s", FORTWARS_PREFIX, "Secondary Weapon Set", szTempArray[1]);
			if(g_eGameState == FortWarsGameState_Live || GameRules_GetProp("m_bWarmupPeriod") == 1)
				EquipPrefWeapons(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			Command_Guns(param1, 0);
		}
	}
	return 0;
}

public int PropsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szInfo[PLATFORM_MAX_PATH+13];
			GetMenuItem(menu, param2, szInfo, sizeof(szInfo));
			char szTempArray[3][PLATFORM_MAX_PATH+13];
			ExplodeString(szInfo, ";", szTempArray, 3, sizeof(szTempArray[]));
			int price = StringToInt(szTempArray[1]);
			int health = StringToInt(szTempArray[2]);
			int team = GetClientTeam(param1);
			if(GetEntProp(param1, Prop_Send, "m_iAccount") < price)
			{
				PrintToChat(param1, "%s \x07%t", FORTWARS_PREFIX, "Not Enough Money");
				Command_Props(param1, 0);
				return 0;
			}
			if(team == CS_TEAM_T)
			{
				if(g_iProps[param1] >= g_iRedMaxProps)
				{
					PrintToChat(param1, "%s \x07%t \x04%d\x07/\x04%d", FORTWARS_PREFIX, "Cannot Place Props", g_iProps[param1], g_iRedMaxProps);
					Command_Props(param1, 0);
					return 0;
				}
			}
			else if(team == CS_TEAM_CT)
			{
				if(g_iProps[param1] >= g_iBlueMaxProps)
				{
					PrintToChat(param1, "%s \x07%t \x04%d\x07/\x04%d", FORTWARS_PREFIX, "Cannot Place Props", g_iProps[param1], g_iBlueMaxProps);
					Command_Props(param1, 0);
					return 0;
				}
			}
			
			float traceendPos[3], eyeAngles[3], eyePos[3];
			GetClientEyeAngles(param1, eyeAngles);
			GetClientEyePosition(param1, eyePos);

			Handle trace = TR_TraceRayFilterEx(eyePos, eyeAngles, MASK_ALL, RayType_Infinite, TraceFilterNotSelf, param1);
			if(TR_DidHit(trace))
				TR_GetEndPosition(traceendPos, trace);

			CloseHandle(trace);
			eyeAngles[0] = 0.0;
			SpawnProp(traceendPos, eyeAngles, param1, szTempArray[0], price, health);
			Command_Props(param1, 0);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			Command_Build(param1, 0);
		}
	}
	return 0;
}

public int BuildMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch(param2)
			{
				case 0:
				{
					Command_Props(param1, 0);
				}
				case 1:
				{
					Command_Remove(param1, 0);
					Command_Build(param1, 0);
				}
				case 2:
				{
					Command_Guns(param1, 0);
				}
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	switch(param2)
	{
		case MenuCancel_ExitBack:
		{
			
		}
	}
	return 0;
}

public void OnPropDamaged(const char[] output, int caller, int activator, float delay)
{
	int hp = GetEntProp(caller, Prop_Data, "m_iHealth");
	if(hp <= 0)
		AcceptEntityInput(caller, "Kill");
	ColorProp(caller);
}

public void OnPropBreak(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("PROP BREAK");
	AcceptEntityInput(caller, "Kill");
}



public Action OnTouchFlagTrigger(int caller, int activator)
{
	if(g_eGameState != FortWarsGameState_Live)
		return Plugin_Continue;
	
	int flag = GetEntPropEnt(caller, Prop_Data, "m_hMoveParent");
	int tflag = EntRefToEntIndex(g_iFlagT);
	int ctflag = EntRefToEntIndex(g_iFlagCT);
	
	if(flag == INVALID_ENT_REFERENCE)
		return Plugin_Continue;
	
	if(activator > 0 && activator <= MaxClients && IsPlayerAlive(activator))
	{
		if(flag == tflag)
		{
			if(GetClientTeam(activator) == CS_TEAM_CT)
				PickUpFlag(flag, activator);
		}
		else if(flag == ctflag)
		{
			if(GetClientTeam(activator) == CS_TEAM_T)
				PickUpFlag(flag, activator);
		}
	}
	SDKUnhook(caller, SDKHook_StartTouch, OnTouchFlagTrigger);
	return Plugin_Continue;
}

public Action OnEnterCaptureZone(int caller, int activator)
{
	if(g_eGameState != FortWarsGameState_Live)
		return Plugin_Continue;
		
	char szName[32];
	GetEntPropString(caller, Prop_Data, "m_iName", szName, sizeof(szName));
	if (StrEqual(szName, "fortwarsgo_t_capture_zone", false))
	{
		if(activator > 0 && activator <= MaxClients && IsPlayerAlive(activator))
		{
			if(GetClientTeam(activator) == CS_TEAM_T)
			{
				int ctflag = EntRefToEntIndex(g_iFlagCT);
				if(ctflag != INVALID_ENT_REFERENCE)
				{
					int ctflagparent = GetEntPropEnt(ctflag, Prop_Data, "m_hMoveParent");
					if(ctflagparent == activator)
					{
						//T SCORE
						g_iRedScore++;
						PrintToChatAll("%s \x07%t\x01: \x04%d\x01 | \x0C%t\x01: \x04%d", FORTWARS_PREFIX, "Red Team", g_iRedScore, "Blue Team", g_iBlueScore);
						ResetFlag(ctflag);
						
						if(g_iRedScore >= g_AmountOfFlagsToWin.IntValue)
						{
							int newScore = CS_GetTeamScore(CS_TEAM_T) + 1;
							CS_SetTeamScore(CS_TEAM_T, newScore);
							UpdateScoreboardTeamScore(CS_TEAM_T, newScore);
							EmitSoundToAllAny(SOUND_RED_WINS);
							CS_TerminateRound(5.0, CSRoundEnd_TerroristWin, true);

						}
						else
						{
							for (int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i))
								{
									if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
										EmitSoundToClientAny(i, SOUND_RED_TEAM_SCORES, _, SNDCHAN_AUTO);
									else if(GetClientTeam(i) == CS_TEAM_T)
										EmitSoundToClientAny(i, SOUND_YOUR_TEAM_SCORES, _, SNDCHAN_AUTO);
									else if(GetClientTeam(i) == CS_TEAM_CT)
										EmitSoundToClientAny(i, SOUND_ENEMY_SCORES, _, SNDCHAN_AUTO);
								}
							}
						}
						
						Call_StartForward(g_hOnFlagCaptured);
						Call_PushCell(ctflagparent);
						Call_PushCell(ctflag);
						Call_Finish();
					}
				}
			}
		}
	}
	else if (StrEqual(szName, "fortwarsgo_ct_capture_zone", false))
	{
		if(activator > 0 && activator <= MaxClients && IsPlayerAlive(activator))
		{
			if(GetClientTeam(activator) == CS_TEAM_CT)
			{
				int tflag = EntRefToEntIndex(g_iFlagT);
				if(tflag != INVALID_ENT_REFERENCE)
				{
					int tflagparent = GetEntPropEnt(tflag, Prop_Data, "m_hMoveParent");
					if(tflagparent == activator)
					{
						//CT SCORE
						g_iBlueScore++;
						PrintToChatAll("%s \x07%t\x01: \x04%d\x01 | \x0C%t\x01: \x04%d", FORTWARS_PREFIX, "Red Team", g_iRedScore, "Blue Team", g_iBlueScore);
						ResetFlag(tflag);
						
						if(g_iBlueScore >= g_AmountOfFlagsToWin.IntValue)
						{
							int newScore = CS_GetTeamScore(CS_TEAM_CT) + 1;
							CS_SetTeamScore(CS_TEAM_CT, newScore);
							UpdateScoreboardTeamScore(CS_TEAM_CT, newScore);
							EmitSoundToAllAny(SOUND_BLUE_WINS);
							CS_TerminateRound(5.0, CSRoundEnd_CTWin, true);
						}
						else
						{
							for (int i = 1; i <= MaxClients; i++)
							{
								if(IsClientInGame(i))
								{
									if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
										EmitSoundToClientAny(i, SOUND_BLUE_TEAM_SCORES, _, SNDCHAN_AUTO);
									else if(GetClientTeam(i) == CS_TEAM_T)
										EmitSoundToClientAny(i, SOUND_ENEMY_SCORES, _, SNDCHAN_AUTO);
									else if(GetClientTeam(i) == CS_TEAM_CT)
										EmitSoundToClientAny(i, SOUND_YOUR_TEAM_SCORES, _, SNDCHAN_AUTO);
								}
							}
						}
						Call_StartForward(g_hOnFlagCaptured);
						Call_PushCell(tflagparent);
						Call_PushCell(tflag);
						Call_Finish();
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_eGameState = FortWarsGameState_PostRound;
	if(g_hSetupTimer != INVALID_HANDLE)
	{
		KillTimer(g_hSetupTimer);
		g_hSetupTimer = INVALID_HANDLE;
	}

	g_hBuildZonesT.Clear();
	g_hBuildZonesCT.Clear();

	event.BroadcastDisabled = true;
	return Plugin_Continue;
}

public Action Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(GameRules_GetProp("m_bWarmupPeriod") != 1)
	{
		g_iSetupTimer = (g_SetupTime.IntValue * 60);
		g_hSetupTimer = CreateTimer(1.0, Timer_Setup, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);	
		EmitSoundToAllAny(SOUND_PREPARE_TO_FIGHT);
		int tmoney = RoundToNearest(g_MoneyPerTeam.FloatValue / float(GetAliveTeamCount(CS_TEAM_T)));
		int ctmoney = RoundToNearest(g_MoneyPerTeam.IntValue / float(GetAliveTeamCount(CS_TEAM_CT)));
		g_iRedMaxProps = RoundToNearest(g_MaxPropsPerTeam.FloatValue / float(GetAliveTeamCount(CS_TEAM_T)));
		g_iBlueMaxProps = RoundToNearest(g_MaxPropsPerTeam.FloatValue / float(GetAliveTeamCount(CS_TEAM_CT)));
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i) == CS_TEAM_T)
				{
					SetEntProp(i, Prop_Send, "m_iAccount", tmoney);
				}
				else if(GetClientTeam(i) == CS_TEAM_CT)
				{
					SetEntProp(i, Prop_Send, "m_iAccount", ctmoney);
				}
				Command_Build(i, 0);
			}
		}
	}
	
	if(g_hMatchTimer != INVALID_HANDLE)
		KillTimer(g_hMatchTimer);
	g_hMatchTimer = CreateTimer(float(FindConVar("mp_roundtime").IntValue*60), Timer_Match);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int tflag = EntRefToEntIndex(g_iFlagT);
	int ctflag = EntRefToEntIndex(g_iFlagCT);
	int tflagparent;
	int ctflagparent;
	if(tflag != INVALID_ENT_REFERENCE)
		tflagparent = GetEntPropEnt(tflag, Prop_Data, "m_hMoveParent");
	if(ctflag != INVALID_ENT_REFERENCE)
		ctflagparent = GetEntPropEnt(ctflag, Prop_Data, "m_hMoveParent");
	
	g_fTimeKilled[client] = GetGameTime();
	
	if(tflagparent == client)
		DropFlag(tflag, client);
	else if(ctflagparent == client)
		DropFlag(ctflag, client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	PrintToChat(client, "%s \x09%t", FORTWARS_PREFIX, "Guns Notice", "\x04", "\x09");
	if(g_eGameState == FortWarsGameState_Build)
	{
		StripWeapons(client, false);
	}
	else if(g_eGameState == FortWarsGameState_Live || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		EquipPrefWeapons(client);
	}
}

public Action Event_RoundPostStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_hFlagTimerT != INVALID_HANDLE)
	{
		KillTimer(g_hFlagTimerT);
		g_hFlagTimerT = INVALID_HANDLE;
	}
		
	if(g_hFlagTimerCT != INVALID_HANDLE)
	{
		KillTimer(g_hFlagTimerCT);
		g_hFlagTimerCT = INVALID_HANDLE;
	}
	
	if(g_hSetupTimer != INVALID_HANDLE)
	{
		KillTimer(g_hSetupTimer);
		g_hSetupTimer = INVALID_HANDLE;
	}
	
	
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iProps[i] = 0;
		if(IsClientInGame(i) && IsPlayerAlive(i))
			StripWeapons(i, false);
	}
		
	int red[4] =  { 255, 0, 0, 255 };
	int blue[4] =  { 0, 0, 255, 255 };
	g_eGameState = FortWarsGameState_Build;
	int tflag = CreateEntityByName("prop_dynamic");
	int ctflag = CreateEntityByName("prop_dynamic");
	
	g_iRedScore = 0;
	g_iBlueScore = 0;
	
	DispatchKeyValue(tflag, "targetname", "tflag"); 
	DispatchKeyValue(tflag, "model", "models/mapmodels/flags.mdl");
	DispatchKeyValue(tflag, "body", "7"); 
	SetEntProp(tflag, Prop_Send, "m_bShouldGlow", true);
	SetEntPropFloat(tflag, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	//SetEntProp(tflag, Prop_Send, "m_nGlowStyle", 4);
	DispatchSpawn(tflag);
	SetEntityMoveType(tflag, MOVETYPE_NONE);
	TeleportEntity(tflag, g_vecFlagPosT, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("flag_idle1");
	AcceptEntityInput(tflag, "setanimation");
	
	SetVariantColor(red);
	AcceptEntityInput(tflag, "SetGlowColor");
	
	DispatchKeyValue(ctflag, "targetname", "ctflag"); 
	DispatchKeyValue(ctflag, "model", "models/mapmodels/flags.mdl");
	DispatchKeyValue(ctflag, "body", "0"); 
	SetEntProp(ctflag, Prop_Send, "m_bShouldGlow", true);
	SetEntPropFloat(ctflag, Prop_Send, "m_flGlowMaxDist", 10000000.0);
	//SetEntProp(ctflag, Prop_Send, "m_nGlowStyle", 4);
	DispatchSpawn(ctflag);
	SetEntityMoveType(ctflag, MOVETYPE_NONE);
	TeleportEntity(ctflag, g_vecFlagPosCT, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantColor(blue);
	AcceptEntityInput(ctflag, "SetGlowColor");
	
	SetVariantString("flag_idle1");
	AcceptEntityInput(ctflag, "setanimation");
	g_iFlagT = EntIndexToEntRef(tflag);
	g_iFlagCT = EntIndexToEntRef(ctflag);

	if(GameRules_GetProp("m_bWarmupPeriod") != 1)
	{
		CreateFlagTrigger(tflag, g_vecFlagPosT);
		CreateFlagTrigger(ctflag, g_vecFlagPosCT);
	}
	else
		BreakBarrier();
}

public Action Timer_Spawn(Handle timer, any flagteam)
{
	float time = 0.0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int team = GetClientTeam(i);
			if((team == CS_TEAM_T || team == CS_TEAM_CT) && !IsPlayerAlive(i))
			{
				if(g_fTimeKilled[i] != 0.0)
				{
					time = g_RespawnTime.FloatValue;
					time -= GetGameTime() - g_fTimeKilled[i];
					if(time > 0.0)
					{
						SetHudTextParams(0.438, 0.20, 1.0, 0, 255, 0, 100, 0, 0.0, 0.0, 0.0);
						ShowHudText(i, -1, "%t: %d", "Respawning", RoundToNearest(time));
					}
					else
					{
						SetHudTextParams(0.42, 0.20, 1.0, 0, 255, 0, 100, 0, 0.0, 0.0, 0.0);
						ShowHudText(i, -1, "%t", "Respawned");
						g_fTimeKilled[i] = 0.0;
						CS_RespawnPlayer(i);
					}
				}					
			}
		}
	}
}

public Action Timer_Match(Handle timer, any flagteam)
{
	g_hMatchTimer = INVALID_HANDLE;
	if(g_iRedScore < g_AmountOfFlagsToWin.IntValue && g_iBlueScore < g_AmountOfFlagsToWin.IntValue)
	{
		if(g_iRedScore > g_iBlueScore)
		{
			EmitSoundToAllAny(SOUND_RED_WINS);
			int newScore = CS_GetTeamScore(CS_TEAM_T) + 1;
			CS_SetTeamScore(CS_TEAM_T, newScore);
			UpdateScoreboardTeamScore(CS_TEAM_T, newScore);
			CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
			return Plugin_Stop;
		}
		else if(g_iBlueScore > g_iRedScore)
		{
			EmitSoundToAllAny(SOUND_BLUE_WINS);
			int newScore = CS_GetTeamScore(CS_TEAM_CT) + 1;
			CS_SetTeamScore(CS_TEAM_CT, newScore);
			UpdateScoreboardTeamScore(CS_TEAM_CT, newScore);
			CS_TerminateRound(5.0, CSRoundEnd_CTWin);
			return Plugin_Stop;
		}
	}
	CS_TerminateRound(5.0, CSRoundEnd_Draw);
	return Plugin_Stop;
}

public void StartGame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			EquipPrefWeapons(i);
		}
	}
	EnablePropDamage();
	BreakBarrier();
	EmitSoundToAllAny(SOUND_FIGHT);
	g_eGameState = FortWarsGameState_Live;
	Call_StartForward(g_hOnGameStart);
	Call_Finish();
}

public Action Timer_Setup(Handle timer, any flagteam)
{
	SetHudTextParams(0.445, 0.1, 1.0, 0, 255, 0, 100, 0, 0.0, 0.0, 0.0);
	
	if(g_iSetupTimer <= 0)
	{
		StartGame();
		g_hSetupTimer = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			ShowHudText(i, -1, "%t: %d", "Setup Time", g_iSetupTimer);
	}
	g_iSetupTimer--;
	
	return Plugin_Continue;
}

public Action Timer_Flag(Handle timer, any flagteam)
{
	if(flagteam == CS_TEAM_T)
	{
		int flag = EntRefToEntIndex(g_iFlagT);
		if(flag == INVALID_ENT_REFERENCE)
		{
			g_hFlagTimerT = INVALID_HANDLE;
			return Plugin_Stop;
		}
		SetHudTextParams(0.02, 0.54, 5.0, 255, 0, 0, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				ShowSyncHudText(i, g_hHudSynchT, "%t: %d", "Flag Returns", g_iFlagTimerT);
		}
		
		if(g_iFlagTimerT <= 0)
		{
			SetHudTextParams(0.02, 0.54, 5.0, 255, 0, 0, 100, 0, 0.0, 0.0, 0.5);
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
						EmitSoundToClientAny(i, SOUND_RED_FLAG_RETURNED, _, SNDCHAN_AUTO);
					else if(GetClientTeam(i) == CS_TEAM_T)
						EmitSoundToClientAny(i, SOUND_YOUR_FLAG_RETURNED, _, SNDCHAN_AUTO);
					else if(GetClientTeam(i) == CS_TEAM_CT)
						EmitSoundToClientAny(i, SOUND_ENEMY_FLAG_RETURNED, _, SNDCHAN_AUTO);
					
					ShowSyncHudText(i, g_hHudSynchT, "%t", "Flag Returned");
				}
			}
			TeleportEntity(flag, g_vecFlagPosT, NULL_VECTOR, NULL_VECTOR);
			g_hFlagTimerT = INVALID_HANDLE;
			
			Call_StartForward(g_hOnFlagReturned);
			Call_PushCell(flag);
			Call_Finish();
			return Plugin_Stop;
		}
		g_iFlagTimerT--;
	}
	else if(flagteam == CS_TEAM_CT)
	{
		int flag = EntRefToEntIndex(g_iFlagCT);
		if(flag == INVALID_ENT_REFERENCE)
		{
			g_hFlagTimerCT = INVALID_HANDLE;
			return Plugin_Stop;
		}
		SetHudTextParams(0.02, 0.57, 5.0, 0, 0, 255, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				ShowSyncHudText(i, g_hHudSynchCT, "%t: %d", "Flag Returns", g_iFlagTimerCT);
		}
		
		if(g_iFlagTimerCT <= 0)
		{
			SetHudTextParams(0.02, 0.57, 5.0, 0, 0, 255, 100, 0, 0.0, 0.0, 0.5);
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
						EmitSoundToClientAny(i, SOUND_BLUE_FLAG_RETURNED, _, SNDCHAN_AUTO);
					else if(GetClientTeam(i) == CS_TEAM_T)
						EmitSoundToClientAny(i, SOUND_ENEMY_FLAG_RETURNED, _, SNDCHAN_AUTO);
					else if(GetClientTeam(i) == CS_TEAM_CT)
						EmitSoundToClientAny(i, SOUND_YOUR_FLAG_RETURNED, _, SNDCHAN_AUTO);
						
					ShowSyncHudText(i, g_hHudSynchCT, "%t", "Flag Returned");
				}
			}
			TeleportEntity(flag, g_vecFlagPosCT, NULL_VECTOR, NULL_VECTOR);
			g_hFlagTimerCT = INVALID_HANDLE;
			return Plugin_Stop;
		}
		g_iFlagTimerCT--;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(g_eGameState == FortWarsGameState_Build)
	{
		PrintHintText(client, "<font size='20' face=''>%t: <font color='#00ff00'>%d/%d</font>\n<font size='20' face=''>%t: <font color='#00ff00'>%d$</font>\n<font size='16' face=''>%t: <font color='#cc3300'>%t", "Props", g_iProps[client], g_iRedMaxProps, "Money", GetEntProp(client, Prop_Send, "m_iAccount"), "Buttons", "Prop Tip");
		if(buttons & IN_RELOAD || buttons & IN_USE)
		{	
			int prop = EntRefToEntIndex(g_iActiveProp[client]);
			if(prop != INVALID_ENT_REFERENCE)
			{
				if(!IsPropInBuildZone(prop))
				{
					g_iActiveProp[client] = INVALID_ENT_REFERENCE;
					RemoveProp(client, prop);
				}
				float eyePos[3];
				float entityAngles[3];
				GetEntPropVector(prop, Prop_Data, "m_angRotation", entityAngles);
	
				if(buttons & IN_USE)
				{
					if(buttons & IN_ATTACK)
						g_fDistance[client] += 5.0;
					else if(buttons & IN_ATTACK2)
					{
						g_fDistance[client] -= 5.0;
						if (g_fDistance[client] <= 50.0)
							g_fDistance[client] = 50.0;
					}
					float eyeAngles[3], entityPos[3];
					GetEntPropVector(prop, Prop_Data, "m_vecOrigin", entityPos);
					GetClientEyePosition(client, eyePos);
					GetClientEyeAngles(client, eyeAngles);
					GetAngleVectors(eyeAngles, eyeAngles, NULL_VECTOR, NULL_VECTOR);
					
					if(!g_bPressedUse[client])
					{
						GetClientEyePosition(client, eyePos);
						g_fDistance[client] = GetVectorDistance(eyePos, entityPos);
						if(g_fDistance[client] <= 50.0)
							g_fDistance[client] = 50.0;
					}
					
					for (int i = 0; i < 3; i++)
						eyePos[i] += eyeAngles[i] * g_fDistance[client];
					
					if(!g_bPressedUse[client])
					{
						g_bPressedUse[client] = true;
						SubtractVectors(entityPos, eyePos, g_vecPropOffset[client]);
	
					}
					
					AddVectors(g_vecPropOffset[client], eyePos, eyePos);
				}
				else if(buttons & IN_RELOAD)
				{
					if(buttons & IN_ATTACK)
					{
						entityAngles[1] += mouse[0];
						entityAngles[2] += mouse[1];
					}
					else
					{
						entityAngles[1] += mouse[0];
						entityAngles[0] += mouse[1];	
					}
					
					if(buttons & IN_ATTACK2)
					{
						if(!g_bPressedAttack2[client])
						{
							if(g_iPropRotationCycle[client] == 0)
							{
								entityAngles[0] = 90.0;
								entityAngles[1] = 0.0;
								entityAngles[2] = 0.0;
							}
							else if(g_iPropRotationCycle[client] == 1)
							{
								entityAngles[0] = 0.0;
								entityAngles[1] = 90.0;
								entityAngles[2] = 0.0;
							}
							else if(g_iPropRotationCycle[client] == 2)
							{
								entityAngles[0] = 0.0;
								entityAngles[1] = 0.0;
								entityAngles[2] = 90.0;
							}
							else if(g_iPropRotationCycle[client] == 3)
							{
								entityAngles[0] = 0.0;
								entityAngles[1] = 0.0;
								entityAngles[2] = 0.0;
							}
							g_bPressedAttack2[client] = true;
							g_iPropRotationCycle[client]++;
							if(g_iPropRotationCycle[client] >= 4)
								g_iPropRotationCycle[client] = 0;
						}
					}
					else
					{
						g_bPressedAttack2[client] = false;
					}
					
					if(!g_bPressedReload[client])
					{
						g_bPressedReload[client] = true;
						GetClientEyeAngles(client, g_vecRotate[client]);
					}
				}
				
				char szName[16];
				char propNameBuffers[4][12];
				GetEntPropString(prop, Prop_Data, "m_iName", szName, sizeof(szName));
	   			ExplodeString(szName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
				if(GetClientOfUserId(StringToInt(propNameBuffers[1])) == client)
				{
					if(buttons & IN_USE)
						TeleportEntity(prop, eyePos, NULL_VECTOR, NULL_VECTOR);
					else if(buttons & IN_RELOAD)
					{
						TeleportEntity(client, NULL_VECTOR, g_vecRotate[client], NULL_VECTOR);
						TeleportEntity(prop, NULL_VECTOR, entityAngles, NULL_VECTOR);
					}
				}
			}
			else
			{
				int entity = GetClientAimTarget(client, false);
				if(entity != INVALID_ENT_REFERENCE && entity > MAXPLAYERS + 1)
				{
					char szName[32];
					char propNameBuffers[4][12];
					GetEntPropString(entity, Prop_Data, "m_iName", szName, sizeof(szName));
	   				ExplodeString(szName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
	   				if(StrEqual(propNameBuffers[0], "prop", false))
						g_iActiveProp[client] = EntIndexToEntRef(entity);
				}	
			}
		}
		else
		{
			g_iActiveProp[client] = INVALID_ENT_REFERENCE;
		}
	}
	else
	{
		g_iActiveProp[client] = INVALID_ENT_REFERENCE;
	}
	
		
	if(!(buttons & IN_RELOAD))
		g_bPressedReload[client] = false;
	
	if(!(buttons & IN_USE))
		g_bPressedUse[client] = false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "trigger_multiple", false))
		SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
}


public Action OnEntitySpawned(int entity)
{
	char triggerName[32];
	GetEntPropString(entity, Prop_Data, "m_iName", triggerName, sizeof(triggerName));
	if (StrEqual(triggerName, "fortwarsgo_t_capture_zone", false))
		SDKHook(entity, SDKHook_StartTouch, OnEnterCaptureZone);
	else if (StrEqual(triggerName, "fortwarsgo_ct_capture_zone", false))
		SDKHook(entity, SDKHook_StartTouch, OnEnterCaptureZone);
	else if(StrEqual(triggerName, "fortwarsgo_t_build_zone", false))
		g_hBuildZonesT.Push(EntIndexToEntRef(entity));
	else if(StrEqual(triggerName, "fortwarsgo_ct_build_zone", false))
		g_hBuildZonesCT.Push(EntIndexToEntRef(entity));
}

public void OnClientCookiesCached(int client)
{
	char value[32];
	GetClientCookie(client, g_hPrimaryWeapon, value, sizeof(value));
	g_szPrimary[client] = value;
	
	GetClientCookie(client, g_hSecondaryWeapon, value, sizeof(value));
	g_szSecondary[client] = value;
}

public void OnClientDisconnect(int client)
{
	if(g_eGameState == FortWarsGameState_Build)
		RemoveDisconnectedProps(client);
	
	int tflag = EntRefToEntIndex(g_iFlagT);
	int ctflag = EntRefToEntIndex(g_iFlagCT);

	if(GetFlagOwner(tflag) == client)
		DropFlag(tflag, client);
	else if(GetFlagOwner(ctflag) == client)
		DropFlag(ctflag, client);
		
	g_fTimeKilled[client] = 0.0;
	g_fTimeUsedStuck[client] = 0.0;
	g_iPropRotationCycle[client] = 0;
	g_bPressedReload[client] = false;
	g_bPressedUse[client] = false;
	g_bPressedAttack2[client] = false;
	g_iActiveProp[client] = INVALID_ENT_REFERENCE;
	g_iProps[client] = 0;
}

public void OnMapStart()
{
	LocateFlagPositions();
	
	//FLAGS
	AddFileToDownloadsTable("models/mapmodels/flags.mdl");
	AddFileToDownloadsTable("models/mapmodels/flags.dx80.vtx");
	AddFileToDownloadsTable("models/mapmodels/flags.dx90.vtx");
	AddFileToDownloadsTable("models/mapmodels/flags.sw.vtx");
	AddFileToDownloadsTable("models/mapmodels/flags.vvd");
	AddFileToDownloadsTable("materials/models/mapmodels/flags/axisflag.vmt");
	AddFileToDownloadsTable("materials/models/mapmodels/flags/axisflag.vtf");
	AddFileToDownloadsTable("materials/models/mapmodels/flags/neutralflag.vmt");
	AddFileToDownloadsTable("materials/models/mapmodels/flags/neutralflag.vtf");
	
	//Pole
	AddFileToDownloadsTable("models/props/pole.dx80.vtx");
	AddFileToDownloadsTable("models/props/pole.dx90.vtx");
	AddFileToDownloadsTable("models/props/pole.mdl");
	AddFileToDownloadsTable("models/props/pole.phy");
	AddFileToDownloadsTable("models/props/pole.sw.vtx");
	AddFileToDownloadsTable("models/props/pole.vvd");
	AddFileToDownloadsTable("materials/models/props/pole/gray.vmt");
	AddFileToDownloadsTable("materials/editor/gray.vtf");
	AddFileToDownloadsTable("materials/editor/gray.vmt");
	
	//Sounds
	AddFileToDownloadsTable("sound/fortwarsgo/enemy_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/enemy_flag_returned.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/enemy_scores.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/your_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/your_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/your_team_scores.mp3");
	
	AddFileToDownloadsTable("sound/fortwarsgo/red_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/red_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/red_scores.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/red_wins.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/blue_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/blue_flag_taken.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/blue_scores.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/blue_wins.mp3");
	
	AddFileToDownloadsTable("sound/fortwarsgo/prepare_to_fight.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/fight.mp3");
	AddFileToDownloadsTable("sound/fortwarsgo/denied.mp3");
	
	PrecacheSoundAny(SOUND_ENEMY_FLAG_TAKEN, true);
	PrecacheSoundAny(SOUND_ENEMY_FLAG_RETURNED, true);
	PrecacheSoundAny(SOUND_ENEMY_SCORES, true);
	PrecacheSoundAny(SOUND_YOUR_FLAG_TAKEN, true);
	PrecacheSoundAny(SOUND_YOUR_FLAG_RETURNED, true);
	PrecacheSoundAny(SOUND_YOUR_TEAM_SCORES, true);
	
	PrecacheSoundAny(SOUND_RED_FLAG_TAKEN, true);
	PrecacheSoundAny(SOUND_RED_FLAG_RETURNED, true);
	PrecacheSoundAny(SOUND_RED_TEAM_SCORES, true);
	PrecacheSoundAny(SOUND_RED_WINS, true);
	PrecacheSoundAny(SOUND_BLUE_FLAG_TAKEN, true);
	PrecacheSoundAny(SOUND_BLUE_FLAG_RETURNED, true);
	PrecacheSoundAny(SOUND_BLUE_TEAM_SCORES, true);
	PrecacheSoundAny(SOUND_BLUE_WINS, true);
	
	PrecacheSoundAny(SOUND_PREPARE_TO_FIGHT, true);
	PrecacheSoundAny(SOUND_FIGHT, true);
	PrecacheSoundAny(SOUND_DENIED, true);
	
	char szProp[PLATFORM_MAX_PATH];
	g_hProps.Rewind();
	if(g_hProps.GotoFirstSubKey())
	{
		do 
		{
			g_hProps.GetString("model", szProp, sizeof(szProp));
			PrecacheModel(szProp, true);
		} while (g_hProps.GotoNextKey());
	}	
	
	
	PrecacheModel("models/mapmodels/flags.mdl", true);
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	PrecacheModel("models/props/de_train/barrel.mdl");
	
	ExecuteGamemodeCvars();
	
	CreateTimer(1.0, Timer_Spawn, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	if(g_hFlagTimerT != INVALID_HANDLE)
	{
		KillTimer(g_hFlagTimerT);
		g_hFlagTimerT = INVALID_HANDLE;
	}
		
	if(g_hFlagTimerCT != INVALID_HANDLE)
	{
		KillTimer(g_hFlagTimerCT);
		g_hFlagTimerCT = INVALID_HANDLE;
	}
	
	if(g_hSetupTimer != INVALID_HANDLE)
	{
		KillTimer(g_hSetupTimer);
		g_hSetupTimer = INVALID_HANDLE;
	}
	
	if(g_hMatchTimer != INVALID_HANDLE)
	{
		KillTimer(g_hMatchTimer);
		g_hMatchTimer = INVALID_HANDLE;
	}
	
	g_iFlagT = INVALID_ENT_REFERENCE;
	g_iFlagCT = INVALID_ENT_REFERENCE;
	
	g_hBuildZonesT.Clear();
	g_hBuildZonesCT.Clear();
}