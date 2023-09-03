#if defined _groups_included
  #endinput
#endif
#define _groups_included

/**
 * Show groups menu to a player
 *
 * @param iPlayer 		Player id
 *
 * @noreturn
 */
native show_groups_menu( const iPlayer );

/**
 * Get a players group
 *
 * @param iPlayer 		Player id
 *
 * @return 				Group id if player belongs to a group, -1 otherwise.
 */
native get_user_group( const iPlayer );

/**
 * Get a players group
 *
 * @param iPlayer 		Player id
 * @param iGroup 		Group id
 * @param iMembers 		Group members
 * @param iSize 		Group size
 *
 * note: If a player is passed then the group's id is going
 *		 to be taken from this player's current group
 *
 * @noreturn
 */
native _get_group_members( const iPlayer = 0, const iGroup = -1, iMembers[ ], &iSize );