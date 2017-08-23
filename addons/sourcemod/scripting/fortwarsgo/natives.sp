public int Native_GetFlag(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	if(team == CS_TEAM_T)
		return g_iFlagT;
	else if(team == CS_TEAM_CT)
		return g_iFlagCT;
		
	return -1;
}

public int Native_GetFlagTeam(Handle plugin, int numParams)
{
	int flag = GetNativeCell(1);
	if(flag == g_iFlagT)
		return CS_TEAM_T;
	else if(flag == g_iFlagCT)
		return CS_TEAM_CT;
		
	return 0;
}

public int Native_GetFlagCarrier(Handle plugin, int numParams)
{
	int flag = GetNativeCell(1);
	int flagcarrier = GetEntPropEnt(flag, Prop_Data, "m_hMoveParent");
	if(flagcarrier != INVALID_ENT_REFERENCE)
	{
		if(flagcarrier > 0 && flagcarrier <= MaxClients && IsClientInGame(flagcarrier) && IsPlayerAlive(flagcarrier))
			return flagcarrier;
	}
	
	return -1;
}

public int Native_GetClientPropCount(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_iProps[client];
}

public int Native_GetClientGrabbedProp(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return EntRefToEntIndex(g_iActiveProp[client]);
}

public int Native_GetMaxProps(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	if(team == CS_TEAM_T)
		return g_iRedMaxProps;
	else if(team == CS_TEAM_CT)
		return g_iBlueMaxProps;
		
	return 0;
}

public int Native_GetScore(Handle plugin, int numParams)
{
	int team = GetNativeCell(1);
	if(team == CS_TEAM_T)
		return g_iRedScore;
	else if(team == CS_TEAM_CT)
		return g_iBlueScore;
		
	return 0;
}

public int Native_GetPropOwner(Handle plugin, int numParams)
{
	int prop = GetNativeCell(1);
	char szName[16];
	char propNameBuffers[4][12];
	GetEntPropString(prop, Prop_Data, "m_iName", szName, sizeof(szName));
	ExplodeString(szName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
	
	if(StrEqual(propNameBuffers[0], "prop", false))
		return GetClientOfUserId(StringToInt(propNameBuffers[1]));
	
	return -1;
}

public int Native_GetPropPrice(Handle plugin, int numParams)
{
	int prop = GetNativeCell(1);
	char szName[16];
	char propNameBuffers[4][12];
	GetEntPropString(prop, Prop_Data, "m_iName", szName, sizeof(szName));
	ExplodeString(szName, ";", propNameBuffers, sizeof(propNameBuffers), sizeof(propNameBuffers[]));
	
	if(StrEqual(propNameBuffers[0], "prop", false))
		return StringToInt(propNameBuffers[2]);
	
	return -1;
}
