stock void TE_SendBox(float vMins[3], float vMaxs[3], int color[4], float lifetime)
{
	float vPos1[3], vPos2[3], vPos3[3], vPos4[3], vPos5[3], vPos6[3];
	vPos1 = vMaxs;
	vPos1[0] = vMins[0];
	vPos2 = vMaxs;
	vPos2[1] = vMins[1];
	vPos3 = vMaxs;
	vPos3[2] = vMins[2];
	vPos4 = vMins;
	vPos4[0] = vMaxs[0];
	vPos5 = vMins;
	vPos5[1] = vMaxs[1];
	vPos6 = vMins;
	vPos6[2] = vMaxs[2];
	TE_SendBeam(vMaxs, vPos1, color, lifetime);
	TE_SendBeam(vMaxs, vPos2, color, lifetime);
	TE_SendBeam(vMaxs, vPos3, color, lifetime);	//Vertical
	TE_SendBeam(vPos6, vPos1, color, lifetime);
	TE_SendBeam(vPos6, vPos2, color, lifetime);
	TE_SendBeam(vPos6, vMins, color, lifetime);	//Vertical
	TE_SendBeam(vPos4, vMins, color, lifetime);
	TE_SendBeam(vPos5, vMins, color, lifetime);
	TE_SendBeam(vPos5, vPos1, color, lifetime);	//Vertical
	TE_SendBeam(vPos5, vPos3, color, lifetime);
	TE_SendBeam(vPos4, vPos3, color, lifetime);
	TE_SendBeam(vPos4, vPos2, color, lifetime);	//Vertical
}

stock void TE_SendBeam(const float vMins[3], const float vMaxs[3], const int color[4], float lifetime)
{
	TE_SetupBeamPoints(vMins, vMaxs, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 0, lifetime, 1.0, 1.0, 1, 0.0, color, 0);
	
	TE_SendToAll();
}

stock void LocateFlagPositions()
{
	int iEnt = MAXPLAYERS + 1;
	char targetName[32];
	while((iEnt = FindEntityByClassname(iEnt, "info_target")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
		if (StrEqual(targetName, "fortwarsgo_t_flag_spawn", false))
			GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", g_vecFlagPosT);
		else if (StrEqual(targetName, "fortwarsgo_ct_flag_spawn", false))
			GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", g_vecFlagPosCT);
	}
}

stock void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(vec1, mid, buffer);
}

stock void CreateFlagTrigger(int flag, float pos[3])
{
	float vMax[3];
	float vMin[3];
	float middle[3];

	vMax[0] = pos[0] + 15;
	vMax[1] = pos[1] + 15;
	vMax[2] = pos[2] + 100;
	
	vMin[0] = pos[0] - 15;
	vMin[1] = pos[1] - 15;
	vMin[2] = pos[2];
	
	//int color[4] =  { 255, 0, 0, 255 };
	//TE_SendBox(vMin, vMax, color, 10.0);

	int iEnt = CreateEntityByName("trigger_multiple");
	SetEntityModel(iEnt, "models/props/de_train/barrel.mdl");
	DispatchKeyValue(iEnt, "spawnflags", "257");
	DispatchKeyValue(iEnt, "StartDisabled", "0");
	DispatchKeyValue(iEnt, "wait", "0");
	if (DispatchSpawn(iEnt))
	{
		ActivateEntity(iEnt);
		GetMiddleOfABox(vMin, vMax, middle);
		TeleportEntity(iEnt, middle, NULL_VECTOR, NULL_VECTOR);
		
		for(int i = 0; i < 3; i++){
			vMin[i] = vMin[i] - middle[i];
			if(vMin[i] > 0.0)
				vMin[i] *= -1.0;
		}
		
		// And the maxs always be positive
		for(int i = 0; i < 3; i++){
			vMax[i] = vMax[i] - middle[i];
			if(vMax[i] < 0.0)
				vMax[i] *= -1.0;
		}
		
		SetEntPropVector(iEnt, Prop_Send, "m_vecMins", vMin);
		SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vMax);
		SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);
		
		SetVariantString("!activator");
		AcceptEntityInput(iEnt, "SetParent", flag);
		
		SDKHook(iEnt, SDKHook_StartTouch, OnTouchFlagTrigger);
	}
}

stock void PickUpFlag(int flag, int client)
{
	if(g_eGameState != FortWarsGameState_Live)
		return;
	
	if(flag == INVALID_ENT_REFERENCE)
		return;
		
	int iBone;
	float boneorigin[3], boneangles[3];
	DispatchKeyValue(flag, "modelscale", "0.8");
	iBone = SDKCall(g_hLookupBone, client, "primary_jiggle_jnt");
	SDKCall(g_hGetBonePosition, client, iBone, boneorigin, boneangles);
	boneorigin[2] -= 30.0;
	TeleportEntity(flag, boneorigin, NULL_VECTOR, NULL_VECTOR);
			
	SetVariantString("!activator");
	AcceptEntityInput(flag, "SetParent", client);
	
	int team = GetFlagTeam(flag);
	if(team == CS_TEAM_T)
	{
		SetHudTextParams(0.02, 0.54, 5.0, 255, 0, 0, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
					EmitSoundToClientAny(i, SOUND_RED_FLAG_TAKEN, _, SNDCHAN_AUTO);
				else if(GetClientTeam(i) == CS_TEAM_T)
					EmitSoundToClientAny(i, SOUND_YOUR_FLAG_TAKEN, _, SNDCHAN_AUTO);
				else if(GetClientTeam(i) == CS_TEAM_CT)
					EmitSoundToClientAny(i, SOUND_ENEMY_FLAG_TAKEN, _, SNDCHAN_AUTO);

				ShowSyncHudText(i, g_hHudSynchT, "FLAG TAKEN");
			}
		}
		if(g_hFlagTimerT != INVALID_HANDLE)
		{
			KillTimer(g_hFlagTimerT);
			g_hFlagTimerT = INVALID_HANDLE;
		}
	}
	else if(team == CS_TEAM_CT)
	{
		SetHudTextParams(0.02, 0.57, 5.0, 0, 0, 255, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				if(GetClientTeam(i) == CS_TEAM_SPECTATOR)
					EmitSoundToClientAny(i, SOUND_BLUE_FLAG_TAKEN, _, SNDCHAN_AUTO);
				else if(GetClientTeam(i) == CS_TEAM_T)
					EmitSoundToClientAny(i, SOUND_ENEMY_FLAG_TAKEN, _, SNDCHAN_AUTO);
				else if(GetClientTeam(i) == CS_TEAM_CT)
					EmitSoundToClientAny(i, SOUND_YOUR_FLAG_TAKEN, _, SNDCHAN_AUTO);
				
				ShowSyncHudText(i, g_hHudSynchCT, "FLAG TAKEN");
			}
		}
		if(g_hFlagTimerCT != INVALID_HANDLE)
		{
			KillTimer(g_hFlagTimerCT);
			g_hFlagTimerCT = INVALID_HANDLE;
		}
	}
	
	Call_StartForward(g_hOnFlagPickedUp);
	Call_PushCell(client);
	Call_PushCell(flag);
	Call_Finish();
}

stock void DropFlag(int flag, int client)
{
	if(flag == INVALID_ENT_REFERENCE)
		return;
		
	AcceptEntityInput(flag, "ClearParent");
	DispatchKeyValue(flag, "modelscale", "1.0");
	float flagPos[3];
	GetEntPropVector(flag, Prop_Data, "m_vecOrigin", flagPos);
	Handle trace = TR_TraceRayFilterEx(flagPos, view_as<float>({90.0, 0.0, 0.0}), MASK_ALL, RayType_Infinite, TraceFilterNotSelf, client);
	if(TR_DidHit(trace))
	{
		float endPos[3];
		TR_GetEndPosition(endPos, trace);
		TeleportEntity(flag, endPos, NULL_VECTOR, NULL_VECTOR);

	}
	int trigger = GetEntPropEnt(flag, Prop_Data, "m_hMoveChild");
	if(trigger != INVALID_ENT_REFERENCE)
		SDKHook(trigger, SDKHook_StartTouch, OnTouchFlagTrigger);
	
	CloseHandle(trace);
	int team = GetFlagTeam(flag);
	if(team == CS_TEAM_CT)
	{
		SetHudTextParams(0.02, 0.57, 5.0, 0, 0, 255, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				ShowSyncHudText(i, g_hHudSynchCT, "FLAG DROPPED");
		}
		g_iFlagTimerCT = g_FlagReturnTime.IntValue;
		g_hFlagTimerCT = CreateTimer(1.0, Timer_Flag, CS_TEAM_CT, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(team == CS_TEAM_T)
	{
		SetHudTextParams(0.02, 0.54, 5.0, 255, 0, 0, 100, 0, 0.0, 0.0, 0.5);
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
				ShowSyncHudText(i, g_hHudSynchT, "FLAG DROPPED");
		}
		g_iFlagTimerT = g_FlagReturnTime.IntValue;
		g_hFlagTimerT = CreateTimer(1.0, Timer_Flag, CS_TEAM_T, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	
	Call_StartForward(g_hOnFlagDropped);
	Call_PushCell(client);
	Call_PushCell(flag);
	Call_Finish();
}

stock void ResetFlag(int flag)
{
	DispatchKeyValue(flag, "modelscale", "1.0");
	int flagparent = GetEntPropEnt(flag, Prop_Data, "m_hMoveParent");
	if(flagparent != INVALID_ENT_REFERENCE)
		AcceptEntityInput(flag, "ClearParent");
	
	int team = GetFlagTeam(flag);
	if(team == CS_TEAM_T)
		TeleportEntity(flag, g_vecFlagPosT, NULL_VECTOR, NULL_VECTOR);
	else if(team == CS_TEAM_CT)
		TeleportEntity(flag, g_vecFlagPosCT, NULL_VECTOR, NULL_VECTOR);
		
	int trigger = GetEntPropEnt(flag, Prop_Data, "m_hMoveChild");
	if(trigger != INVALID_ENT_REFERENCE)
		SDKHook(trigger, SDKHook_StartTouch, OnTouchFlagTrigger);
}

stock int GetFlagOwner(int flag)
{
	if(flag == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;
		
	int flagparent = GetEntPropEnt(flag, Prop_Data, "m_hMoveParent");
	if(flagparent != INVALID_ENT_REFERENCE)
		return flagparent;
	return INVALID_ENT_REFERENCE;
}

stock int GetFlagTeam(int flag)
{
	if(flag == INVALID_ENT_REFERENCE)
		return 0;
		
	char szName[16];
	GetEntPropString(flag, Prop_Data, "m_iName", szName, sizeof(szName));
	if(StrEqual(szName, "tflag", false))
		return CS_TEAM_T;
	else if(StrEqual(szName, "ctflag", false))
		return CS_TEAM_CT;
	
	return 0;
}

stock void BreakBarrier()
{
	char triggerName[32];
	int iEnt = MAXPLAYERS + 1;
	while((iEnt = FindEntityByClassname(iEnt, "func_breakable")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", triggerName, sizeof(triggerName));
		if (StrEqual(triggerName, "fortwarsgo_barrier", false))
			AcceptEntityInput(iEnt, "Break");
	}
}

stock bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	if(entity >= 0 && entityhit != entity)
		return true;
	
	return false;
}

stock void ExecuteGamemodeCvars()
{
	SetConVarInt(FindConVar("mp_roundtime"), g_MatchTime.IntValue + g_SetupTime.IntValue);
	SetConVarInt(FindConVar("game_mode"), 0);
	SetConVarInt(FindConVar("game_type"), 0);
	SetConVarInt(FindConVar("mp_startmoney"), 0);
	SetConVarInt(FindConVar("mp_afterroundmoney"), 0);
	SetConVarInt(FindConVar("mp_respawn_on_death_t"), 0);
	SetConVarInt(FindConVar("mp_respawn_on_death_ct"), 0);
	SetConVarInt(FindConVar("mp_ignore_round_win_conditions"), 1);
}

stock void SpawnProp(float pos[3], float angles[3], int client, const char[] model, int price, int health)
{
	if(!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s \x07You cannot build while dead!", FORTWARS_PREFIX);
		return;
	}
		
	if(g_eGameState != FortWarsGameState_Build || GameRules_GetProp("m_bWarmupPeriod") == 1)
	{
		ReplyToCommand(client, "%s \x07You can only build while in setup!", FORTWARS_PREFIX);
		return;
	}
	
	g_iProps[client]++;
	char szTargetName[16];
	Format(szTargetName, sizeof(szTargetName), "prop;%d;%d;%d;%d", GetClientUserId(client), GetClientTeam(client), price, health);
	int prop = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(prop, "model", model);
	DispatchKeyValue(prop, "disablereceiveshadows", "1");
	DispatchKeyValue(prop, "disableshadows", "1");
	DispatchKeyValue(prop, "Solid", "6");
	DispatchKeyValue(prop, "targetname", szTargetName);
	DispatchSpawn(prop);
	TeleportEntity(prop, pos, angles, NULL_VECTOR);
	SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount")-price);
	SetEntityRenderMode(prop, RENDER_TRANSALPHA);
	SetEntProp(prop, Prop_Data, "m_iMaxHealth", health);
	SetEntProp(prop, Prop_Data, "m_iHealth", health);

	HookSingleEntityOutput(prop, "OnHealthChanged", OnPropDamaged, false);
}

stock void RemoveProp(int client, int prop)
{
	char szPropName[32];
	GetEntPropString(prop, Prop_Data, "m_iName", szPropName, sizeof(szPropName));

	char propNameBuffers[4][12];
   	ExplodeString(szPropName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
   	int price = StringToInt(propNameBuffers[3]);
   	int owner = GetClientOfUserId(StringToInt(propNameBuffers[1]));
   	
   	if(client == owner)
   	{
   		SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount")+price);
   		AcceptEntityInput(prop, "Kill");
   		g_iProps[client]--;
   		PrintToChat(client, "%s \x07Prop removed! \x04+%d$", FORTWARS_PREFIX, price);
   	}
   	else
   		PrintToChat(client, "%s \x07That is not your prop!", FORTWARS_PREFIX);
}

stock void EnablePropDamage()
{
	int iEnt = MAXPLAYERS + 1;
	char targetName[32];
	char propNameBuffers[4][12];
	while((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
   		ExplodeString(targetName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
		if (StrEqual(propNameBuffers[0], "prop", false))
		{
			SetEntProp(iEnt, Prop_Data, "m_takedamage", 2);
		}
	}
}

stock void ColorProp(int prop)
{
	int health = GetEntProp(prop, Prop_Data, "m_iHealth");
	int maxhealth = GetEntProp(prop, Prop_Data, "m_iMaxHealth");

	float percentage = (float(health) / float(maxhealth));
	int color = RoundToNearest(percentage * 255.0);
	
	SetEntityRenderColor(prop, color, color, color, 255);
}

stock bool IsValidClient(int client)
{
	if(client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client))
			return true;
	}
	return false;
}

stock bool IsPropInBuildZone(int prop)
{
	char szPropName[32];
	GetEntPropString(prop, Prop_Data, "m_iName", szPropName, sizeof(szPropName));
	
	char propNameBuffers[4][12];
   	ExplodeString(szPropName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
   	int team = StringToInt(propNameBuffers[2]);
   	float vPropMin[3], vPropMax[3];
   	float entPos[3];
   	GetEntPropVector(prop, Prop_Data, "m_vecOrigin", entPos);
   	GetEntPropVector(prop, Prop_Send, "m_vecMins", vPropMin);
	GetEntPropVector(prop, Prop_Send, "m_vecMaxs", vPropMax);
	AddVectors(entPos, vPropMin, vPropMin);
	AddVectors(entPos, vPropMax, vPropMax);
   	if(team == CS_TEAM_T)
   	{
   		for (int i = 0; i < g_hBuildZonesT.Length;i++)
   		{
   			int zone = EntRefToEntIndex(g_hBuildZonesT.Get(i));
   			if(zone != INVALID_ENT_REFERENCE)
   			{
				float vBuildZoneMin[3], vBuildZoneMax[3];
				float zonePos[3];
				GetEntPropVector(zone, Prop_Data, "m_vecOrigin", zonePos);
				GetEntPropVector(zone, Prop_Send, "m_vecMins", vBuildZoneMin);
				GetEntPropVector(zone, Prop_Send, "m_vecMaxs", vBuildZoneMax);
				AddVectors(zonePos, vBuildZoneMin, vBuildZoneMin);
				AddVectors(zonePos, vBuildZoneMax, vBuildZoneMax);
				
				if( (vPropMin[0] <= vBuildZoneMax[0] && vPropMax[0] >= vBuildZoneMin[0]) &&
					(vPropMin[1] <= vBuildZoneMax[1] && vPropMax[1] >= vBuildZoneMin[1]) &&
					(vPropMin[2] <= vBuildZoneMax[2] && vPropMax[2] >= vBuildZoneMin[2]))
				{
					return true;
				}
   			}
   		}
   	}
   	else if(team == CS_TEAM_CT)
   	{
   		for (int i = 0; i < g_hBuildZonesCT.Length;i++)
   		{
   			int zone = EntRefToEntIndex(g_hBuildZonesCT.Get(i));
   			if(zone != INVALID_ENT_REFERENCE)
   			{
				float vBuildZoneMin[3], vBuildZoneMax[3];
				float zonePos[3];
				GetEntPropVector(zone, Prop_Data, "m_vecOrigin", zonePos);
				GetEntPropVector(zone, Prop_Send, "m_vecMins", vBuildZoneMin);
				GetEntPropVector(zone, Prop_Send, "m_vecMaxs", vBuildZoneMax);
				AddVectors(zonePos, vBuildZoneMin, vBuildZoneMin);
				AddVectors(zonePos, vBuildZoneMax, vBuildZoneMax);
				if( (vPropMin[0] <= vBuildZoneMax[0] && vPropMax[0] >= vBuildZoneMin[0]) &&
					(vPropMin[1] <= vBuildZoneMax[1] && vPropMax[1] >= vBuildZoneMin[1]) &&
					(vPropMin[2] <= vBuildZoneMax[2] && vPropMax[2] >= vBuildZoneMin[2]))
				{
					return true;
				}
   			}
   		}
   	}
   	return false;
}

stock void StripWeapons(int client, bool knife = true)
{
	int weapon; 
	for(int i = 0; i < 5; i++) 
	{ 
	    if((weapon = GetPlayerWeaponSlot(client, i)) != -1) 
	    { 
	        SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR); 
	        AcceptEntityInput(weapon, "Kill"); 
	    } 
	}
	if(!knife)
		GivePlayerItem(client, "weapon_knife");
}

stock void EquipPrefWeapons(int client)
{
	if(!StrEqual(g_szSecondary[client], "", false))
	{
		StripWeapons(client, false);
		GivePlayerItem(client, g_szSecondary[client]);
	}

	if(!StrEqual(g_szPrimary[client], "", false))
		GivePlayerItem(client, g_szPrimary[client]);
}

stock int GetAliveTeamCount(int team)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
			count++;
	}
	return count;
}

stock void RemoveDisconnectedProps(int client)
{
	int iEnt = MAXPLAYERS + 1;
	char targetName[32];
	while((iEnt = FindEntityByClassname(iEnt, "prop_dynamic_override")) != -1)
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", targetName, sizeof(targetName));
		char propNameBuffers[4][12];
	   	ExplodeString(targetName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
	   	
	   	int owner = GetClientOfUserId(StringToInt(propNameBuffers[1]));
		if (StrEqual(propNameBuffers[0], "prop", false) && client == owner)
			AcceptEntityInput(iEnt, "Kill");
	}
}

stock void UpdateScoreboardTeamScore(int team, int score)
{
	int iEnt = MAXPLAYERS + 1;
	while((iEnt = FindEntityByClassname(iEnt, "cs_team_manager")) != -1)
	{
		if(GetEntProp(iEnt, Prop_Send, "m_iTeamNum") == team)
		{
			SetEntProp(iEnt, Prop_Send, "m_scoreTotal", score);	
			break;
		}
	}	
}

/* I HAVE NO IDEA WHAT IM DOING BUT I TRIED
stock void RotateVectorAroundAxisAngle(float axis[3], float angle, float center[3])
{
	float ang = DEG2RAD(angle);
	
	float tempBuffer[3];
	GetVectorCrossProduct(axis, center, tempBuffer);
	float dot = GetVectorDotProduct(center, axis);
	float angleCos = Cosine(ang);
	float angleSine = Sine(ang);
	center[0] = center[0] * angleCos + (dot * axis[0] * (1 - angleCos)) + (tempBuffer[0] * angleSine);
	center[1] = center[1] * angleCos + (dot * axis[1] * (1 - angleCos)) + (tempBuffer[1] * angleSine);
	center[2] = center[2] * angleCos + (dot * axis[2] * (1 - angleCos)) + (tempBuffer[2] * angleSine);
}

			
float entityAngles[3];
GetEntPropVector(prop, Prop_Data, "m_angRotation", entityAngles);

float fwd[3], right[3], up[3];
GetAngleVectors(entityAngles, fwd, right, up);

float entityPos1[3], entityPos2[3];
GetEntPropVector(prop, Prop_Data, "m_vecOrigin", entityPos1);
entityPos2 = entityPos1;

RotateVectorAroundAxisAngle(view_as<float>({1.0, 0.0, 0.0}), g_fAngle[client][0], entityPos1);
RotateVectorAroundAxisAngle(view_as<float>({0.0, 1.0, 0.0}), g_fAngle[client][1], entityPos2);

g_fAngle[client][0] += float(mouse[0]) * 0.1;
g_fAngle[client][1] += float(mouse[1]) * 0.1;

entityPos1[2] = 0.0;
entityPos1[0] = entityPos2[0];
//entityPos1[0] = 0.0;
char szName[16];
GetEntPropString(prop, Prop_Data, "m_iName", szName, sizeof(szName));
if(GetClientOfUserId(StringToInt(szName)) == client)
{
	TeleportEntity(prop, NULL_VECTOR, entityPos1, NULL_VECTOR);
	TeleportEntity(client, NULL_VECTOR, g_vecRotate[client], NULL_VECTOR);
}
*/