#if defined fortwarsgo_include
  #endinput
#endif
#define fortwarsgo_include

/**
 * Returns the teams flag
 *
 * @param team index
 * @return  int				flag entity index
 */
native int FortWarsGO_GetFlag(int team);

/**
 * Returns wardens client index, -1 on failure
 *
 * @param flag entity index
 * @return  int				wardens client index
 */
native int FortWarsGO_GetFlagTeam(int flag);

/**
 * Returns the flags carrier, -1 on failure
 *
 * @param flag entity index
 * @return  int			client index
 */
native int FortWarsGO_GetFlagCarrier(int flag);

/**
 * Returns the amount of props the client has placed
 *
 * @param client index
 * @return  int				amount of props placed
 */
native int FortWarsGO_GetClientPropCount(int client);

/**
 * Returns the max amount of props one player can place during the active round
 *
 * @param team index
 * @return  int			entity index
 */
native int FortWarsGO_GetMaxProps(int team);

/**
 * Returns the teams score
 *
 * @param team index
 * @return  int			team score
 */
native int FortWarsGO_GetScore(int team);

/**
 * Returns the client index who placed this prop
 *
 * @param entity index
 * @return  int			client index
 */
native int FortWarsGO_GetPropOwner(int prop);

/**
 * Returns the price of the prop
 *
 * @param entity index
 * @return  int				price of prop
 */
native int FortWarsGO_GetPropPrice(int prop);

/**
 * Called when game is live (After setup/build state)
 * @param last guards client index
 * @noreturn
 */
forward void FortWarsGO_OnGameStart();

/**
 * Called when someone picks up a flag
 * @param client client index (Terrorist)
 * @param flag entity index
 * @noreturn
 */
forward void FortWarsGO_OnFlagPickedUp(int client, int flag);

/**
 * Called when someone drops a flag
 * @param client client index (Terrorist)
 * @param flag entity index
 * @noreturn
 */
forward void FortWarsGO_OnFlagDropped(int client, int flag);

/**
 * Called when someone captures a flag
 * @param capturer client index
 * @param flag entity index
 * @noreturn
 */
forward void FortWarsGO_OnFlagCaptured(int capturer, int flag);

/**
 * Called when a flag returns to base
 * @param flag entity index
 * @noreturn
 */
forward void FortWarsGO_OnFlagReturned(int flag);

public SharedPlugin __pl_fortwarsgo  =
{
	name = "fortwarsgo",
	file = "fortwarsgo.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_fortwarsgo_SetNTVOptional()
{	
	MarkNativeAsOptional("FortWarsGO_OnGameStart");
	MarkNativeAsOptional("FortWarsGO_OnFlagPickedUp");
	MarkNativeAsOptional("FortWarsGO_OnFlagDropped");
	MarkNativeAsOptional("FortWarsGO_OnFlagCaptured");
	MarkNativeAsOptional("FortWarsGO_OnFlagReturned");
}
#endif