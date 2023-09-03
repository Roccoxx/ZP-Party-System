#include <amxmodx>

/* =================================================================================
* 				[ Global ]
* ================================================================================= */

#define MAX_GROUPS 16
#define MAX_GROUP_MEMBERS 4

#define MAX_MESSAGE_LENGTH 191

#define GROUP_NONE -1
#define OWNER_NONE 0
#define MEMBER_NONE 0

#define PLAYER_ARRAY 33

#define IsPlayer(%0) 			( 1 <= %0 <= MAX_PLAYERS )

#define GetPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )
#define SwitchPlayerBit(%0,%1) 	( IsPlayer(%1) && ( %0 ^= ( 1 << ( %1 & 31 ) ) ) )

#define IsInviteable(%0) 		( !GetPlayerBit( g_iHasGroup, %0 ) && g_sPlayers[ %0 ][ Player_Invites ] )

#define GetGroupIndex(%0) 		( g_sPlayers[ %0 ][ Player_Group ] )
#define GetGroupSize(%0) 		( g_sGroups[ %0 ][ Group_Size ] )
#define GetGroupOwner(%0) 		( g_sGroups[ %0 ][ Group_Owner ] )
#define GetGroupMember(%0,%1) 	( g_sGroups[ %0 ][ Group_Members ][ %1 ] )

#define ClientPlaySound(%0,%1) 	client_cmd( %0, "spk ^"%s^"", %1 )

enum _:Group_Struct
{
	Group_Size,
	Group_Owner,
	Group_Members[ MAX_GROUP_MEMBERS ]
}

enum _:Player_Struct
{
	Player_Name[ 32 ],
	
	Player_Userid,
	Player_Group,
	bool:Player_Invites,
	Float:Player_Invite_Cooldown
}

new const g_szPrefix[ ] 		= "Grupos";

new const g_szLeftSound[ ]		= "buttons/button8.wav";
new const g_szJoinSound[ ]		= "buttons/button1.wav";
new const g_szInviteSound[ ] 	= "buttons/blip2.wav";

new	g_iIsConnected;

new g_iHasGroup;

new g_sGroups[ MAX_GROUPS ][ Group_Struct ];
new g_sPlayers[ PLAYER_ARRAY ][ Player_Struct ];

/* =================================================================================
* 				[ Plugin Events ]
* ================================================================================= */

public plugin_natives( )
{
	register_native( "show_groups_menu", "_show_groups_menu" );
	
	register_native( "get_user_group", "_get_user_group" );
	register_native( "get_group_members", "_get_group_members" );
}

public plugin_precache( )
{
	precache_sound( g_szLeftSound );
	precache_sound( g_szJoinSound );
	precache_sound( g_szInviteSound );
}

public plugin_init( )
{
	register_plugin( "Grupos", "1.0", "Manu" );
	
	register_clcmd( "say", "ClientCommand_Say" );
	
	register_clcmd( "say /grupo", "ClientCommand_Group" );
	register_clcmd( "say /party", "ClientCommand_Group" );
}

/* =================================================================================
* 				[ Update Name On Change ]
* ================================================================================= */

public client_infochanged( iId )
{
	if ( !GetPlayerBit( g_iIsConnected, iId ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	static szName[ 32 ];
	
	get_user_name( iId, szName, charsmax( szName ) );
	
	if ( !equal( szName, g_sPlayers[ iId ][ Player_Name ] ) )
	{
		copy( g_sPlayers[ iId ][ Player_Name ], charsmax( g_sPlayers[ ][ Player_Name ] ), szName );
	}
	
	return PLUGIN_CONTINUE;
}

/* =================================================================================
* 				[ Client Connection ]
* ================================================================================= */

public client_putinserver( iId )
{
	SetPlayerBit( g_iIsConnected, iId );
	
	g_sPlayers[ iId ][ Player_Group ] = GROUP_NONE;
	g_sPlayers[ iId ][ Player_Userid ] = get_user_userid( iId );
	
	get_user_name( iId, g_sPlayers[ iId ][ Player_Name ], charsmax( g_sPlayers[ ][ Player_Name ] ) );
}

public client_disconnected( iId )
{
	ClearPlayerBit( g_iIsConnected, iId );
	
	if ( GetPlayerBit( g_iHasGroup, iId ) )
	{
		LeaveGroup( iId );
	}
}

/* =================================================================================
* 				[ Client Commands ]
* ================================================================================= */

public ClientCommand_Group( iId )
{
	ShowGroupMenu( iId );
	
	return PLUGIN_HANDLED;
}

public ClientCommand_Say( iId )
{
	if ( !GetPlayerBit( g_iHasGroup, iId ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	static szData[ 192 ];
	
	read_args( szData, charsmax( szData ) );
	remove_quotes( szData );
	trim( szData );
	
	replace_all( szData, charsmax( szData ), "%", "" );
	replace_all( szData, charsmax( szData ), "#", "" );
	replace_all( szData, charsmax( szData ), "\", "" );
	
	if ( szData[ 0 ] != '!' )
	{
		return PLUGIN_CONTINUE;
	}
	
	new iGroup = GetGroupIndex( iId );
	new iSize = GetGroupSize( iGroup );
	
	new iMember;
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iMember = GetGroupMember( iGroup, i );
		
		if ( !GetPlayerBit( g_iIsConnected, iMember ) )
		{
			continue;
		}
		
		client_print_color( iMember, iId, "^4(GRUPO) ^3%s:^1 %s", g_sPlayers[ iId ][ Player_Name ], szData[1] );
	}
	
	return PLUGIN_HANDLED_MAIN;
}

/* =================================================================================
* 				[ Client Menus ]
* ================================================================================= */

ShowGroupMenu( const iId )
{
	new iMenu = menu_create( "Grupos", "OnGroupMenuHandler" );
	
	if ( GetPlayerBit( g_iHasGroup, iId ) )
	{
		new iGroup = GetGroupIndex( iId );
		new iOwner = GetGroupOwner( iGroup );
		
		menu_additem( iMenu, "\yVer \wmiembros^n", "m" );
		
		if ( iOwner == iId )
		{
			menu_additem( iMenu, "\yInvitar \wun jugador", "i" );
			menu_additem( iMenu, "\yExpulsar \wun jugador^n", "k" );
		}
		else
		{
			menu_additem( iMenu, "\dInvitar un jugador", "i" );
			menu_additem( iMenu, "\dExpulsar un jugador^n", "k" );
		}
		
		menu_additem( iMenu, "\rAbandonar \wel grupo", "l" );
	}
	else
	{
		menu_additem( iMenu, "\yCrear \wun grupo", "i" );
		menu_additem( iMenu, "\yLeer \wayuda^n", "h" );
		
		g_sPlayers[ iId ][ Player_Invites ] ?
			menu_additem( iMenu, "Recibir invitaciones \d| \ySI", "a" ) :
			menu_additem( iMenu, "Recibir invitaciones \d| \rNO", "a" );
	}
	
	menu_setprop( iMenu, MPROP_EXITNAME, "Cancelar" );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public OnGroupMenuHandler( const iId, const iMenu, const iItem )
{
	if ( iItem == MENU_EXIT )
	{
		menu_destroy( iMenu );
		
		return PLUGIN_HANDLED;
	}
	
	new iNum;
	new szInfo[ 2 ];
	
	menu_item_getinfo( iMenu, iItem, iNum, szInfo, charsmax( szInfo ), _, _, iNum );
	menu_destroy( iMenu );
	
	switch ( szInfo[ 0 ] )
	{
		case 'i':
		{
			if ( GetPlayerBit( g_iHasGroup, iId ) )
			{
				new iGroup = GetGroupIndex( iId );
				new iOwner = GetGroupOwner( iGroup );
				
				if ( iOwner != iId )
				{
					client_print_color( iId, print_team_default, "^4[%s]^1 Solo el dueño del grupo puede invitar jugadores.", g_szPrefix );
					
					return PLUGIN_HANDLED;
				}
				
				new iSize = GetGroupSize( iGroup );
				
				if ( iSize >= MAX_GROUP_MEMBERS )
				{
					client_print_color( iId, print_team_default, "^4[%s]^1 Tu grupo ya posee la cantidad maxima de miembros.", g_szPrefix );
					
					return PLUGIN_HANDLED;
				}
			}
			else if ( g_sPlayers[ iId ][ Player_Invite_Cooldown ] > get_gametime( ) )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 Debes esperar a que tu invitacion caduque o sea respondida para mandar otra.", g_szPrefix );
				client_print_color( iId, print_team_default, "^4[%s]^1 Las invitaciones caducan luego de diez segundos sin ser respondidas.", g_szPrefix );
				
				return PLUGIN_HANDLED;
			}
			
			ShowInviteMenu( iId );
			
			client_print_color( iId, print_team_default, "^4[%s]^1 Si no encuentras un jugador es porque no puede recibir invitaciones.", g_szPrefix );
		}
		case 'k':
		{
			if ( !GetPlayerBit( g_iHasGroup, iId ) )
			{
				return PLUGIN_HANDLED;
			}
			
			new iGroup = GetGroupIndex( iId );
			new iOwner = GetGroupOwner( iGroup )
			
			if ( iOwner != iId )
			{
				client_print_color( iId, print_team_default, "^4[%s]^1 Solo el dueño del grupo puede expulsar jugadores.", g_szPrefix );
				
				return PLUGIN_HANDLED;
			}
			
			ShowKickMenu( iId );
		}
		case 'm':
		{
			if ( GetPlayerBit( g_iHasGroup, iId ) )
			{
				ShowMembersMenu( iId );
			}
		}
		case 'l':
		{
			if ( GetPlayerBit( g_iHasGroup, iId ) )
			{
				LeaveGroup( iId );
			}
		}
		case 'h':
		{
			client_print_color( iId, print_team_default, "^4[%s]^1 Puedes abrir el menu de grupo con^4 /grupo^1 o^4 /party^1.", g_szPrefix );
			client_print_color( iId, print_team_default, "^4[%s]^1 Si desactivas las invitaciones^4 no podras ser invitado^1 a ningun grupo.", g_szPrefix );
			client_print_color( iId, print_team_default, "^4[%s]^1 Comienza tu mensaje con un ^4!^1 para conversar con tu grupo de forma privada.", g_szPrefix );
		}
		case 'a':
		{
			g_sPlayers[ iId ][ Player_Invites ] = !g_sPlayers[ iId ][ Player_Invites ];
			
			ShowGroupMenu( iId );
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMembersMenu( const iId )
{
	new szData[ 64 ];
	
	new iGroup = GetGroupSize( iId );
	new iSize = GetGroupSize( iGroup );
	
	new iMember;
	
	new iMenu = menu_create( "\wListado de \ymiembros", "OnMembersMenuHandler" );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iMember = GetGroupMember( iGroup, i );
		
		formatex( szData, charsmax( szData ), "%s%s", g_sPlayers[ iMember ][ Player_Name ], is_user_alive( iMember ) ? " \r(Vivo)" : " \d(Muerto)" );
		menu_additem( iMenu, szData );
	}
	
	menu_setprop( iMenu, MPROP_EXITNAME, "Siguiente" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Anterior" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Volver" );
	
	menu_display( iId, iMenu );
}

public OnMembersMenuHandler( const iId, const iMenu, const iItem )
{
	menu_destroy( iMenu );
	
	if ( ( iItem == MENU_EXIT ) && GetPlayerBit( g_iIsConnected, iId ) )
	{
		ShowGroupMenu( iId );
	}
	
	return PLUGIN_HANDLED;
}

ShowInviteMenu( const iId )
{
	new szNum[ 16 ];
	
	new iMenu = menu_create( "\wInvitar un jugador", "OnInviteMenuHandler" );
	
	for ( new iPlayer = 1 ; iPlayer <= MAX_PLAYERS ; iPlayer++ )
	{
		if ( ( iPlayer == iId ) || !GetPlayerBit( g_iIsConnected, iPlayer ) || !IsInviteable( iPlayer ) )
		{
			continue;
		}
		
		formatex( szNum, charsmax( szNum ), "%d#%d", iPlayer, g_sPlayers[ iPlayer ][ Player_Userid ] );
		
		menu_additem( iMenu, g_sPlayers[ iPlayer ][ Player_Name ], szNum );
	}
	
	menu_setprop( iMenu, MPROP_NEXTNAME, "Siguiente" );
	menu_setprop( iMenu, MPROP_BACKNAME, "Anterior" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Cancelar" );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public OnInviteMenuHandler( const iId, const iMenu, const iItem )
{
	if ( ( iItem == MENU_EXIT ) || !GetPlayerBit( g_iIsConnected, iId ) )
	{
		menu_destroy( iMenu );
		
		return PLUGIN_HANDLED;
	}
	
	new iNum;
	
	new szInfo[ 16 ];
	new szTarget[ 4 ]
	new szUserid[ 12 ];
	
	menu_item_getinfo( iMenu, iItem, iNum, szInfo, charsmax( szInfo ), _, _, iNum );
	menu_destroy( iMenu );
	
	strtok( szInfo, szTarget, charsmax( szTarget ), szUserid, charsmax( szUserid ), '#' );
	
	new iTarget = str_to_num( szTarget );
	new iUserid = str_to_num( szUserid );
	
	if ( !GetPlayerBit( g_iIsConnected, iTarget ) || ( g_sPlayers[ iTarget ][ Player_Userid ] != iUserid ) || !IsInviteable( iTarget ) )
	{
		return PLUGIN_HANDLED;
	}
	
	ShowConfirmMenu( iTarget, iId );
	
	g_sPlayers[ iId ][ Player_Invite_Cooldown ] = ( get_gametime( ) + 10.0 );
	
	client_print_color( iId, print_team_default, "^4[%s]^1 Se envio tu invitacion a^4 %s^1 correctamente.", g_szPrefix, g_sPlayers[ iTarget ][ Player_Name ] );
	client_print_color( iTarget, print_team_default, "^4[%s]^1 Has recibido una invitacion de^4 %s^1.", g_szPrefix, g_sPlayers[ iId ][ Player_Name ] );
	
	return PLUGIN_HANDLED;
}

ShowKickMenu( const iId )
{
	new szNum[ 16 ];
	
	new iGroup = GetGroupIndex( iId );
	new iSize = GetGroupSize( iGroup );
	
	new iMember;
	
	new iMenu = menu_create( "\wExpulsar un jugador", "OnKickMenuHandler" );
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iMember = GetGroupMember( iGroup, i );
		
		if ( iMember == iId )
		{
			continue;
		}
		
		formatex( szNum, charsmax( szNum ), "%d#%d", iMember, g_sPlayers[ iMember ][ Player_Userid ] );
		
		menu_additem( iMenu, g_sPlayers[ iMember ][ Player_Name ], szNum );
	}
	
	menu_setprop( iMenu, MPROP_NEXTNAME, "Siguiente" );
	menu_setprop( iMenu, MPROP_BACKNAME, "Anterior" );
	menu_setprop( iMenu, MPROP_EXITNAME, "Volver" );
	
	menu_display( iId, iMenu );
	
	return PLUGIN_HANDLED;
}

public OnKickMenuHandler( const iId, const iMenu, const iItem )
{
	if ( ( iItem == MENU_EXIT ) || !GetPlayerBit( g_iHasGroup, iId ) )
	{
		menu_destroy( iMenu );
		
		return PLUGIN_HANDLED;
	}
	
	new iNum;
	
	new szInfo[ 16 ];
	new szTarget[ 4 ]
	new szUserid[ 12 ];
	
	menu_item_getinfo( iMenu, iItem, iNum, szInfo, charsmax( szInfo ), _, _, iNum );
	menu_destroy( iMenu );
	
	strtok( szInfo, szTarget, charsmax( szTarget ), szUserid, charsmax( szUserid ), '#' );
	
	new iTarget = str_to_num( szTarget );
	new iUserid = str_to_num( szUserid );
	
	if ( !GetPlayerBit( g_iHasGroup, iTarget ) || ( g_sPlayers[ iTarget ][ Player_Userid ] != iUserid ) )
	{
		return PLUGIN_HANDLED;
	}
	
	new iGroup = GetGroupIndex( iTarget );
	new iOwner = GetGroupOwner( iGroup );
	
	if ( iOwner == iId )
	{
		LeaveGroup( iTarget );
		
		ClientPlaySound( iTarget, g_szLeftSound );
		client_print_color( iTarget, print_team_default, "^4[%s]^1 Has sido expulsado por el creador del grupo.", g_szPrefix );
	}
	
	return PLUGIN_HANDLED;
}

ShowConfirmMenu( const iId, const iInviter )
{
	new szData[ 64 ];
	new szNum[ 16 ];
	
	formatex( szData, charsmax( szData ), "\r%s \wte invito a su grupo", g_sPlayers[ iInviter ][ Player_Name ] );
	formatex( szNum, charsmax( szNum ), "%d#%d", iInviter, g_sPlayers[ iInviter ][ Player_Userid ] );
	
	new iMenu = menu_create( szData, "OnConfirmMenuHandler" );
	
	menu_additem( iMenu, "Si, quiero \yunirme", szNum );
	menu_additem( iMenu, "No, \yrechazar \winvitacion^n", szNum );
	
	menu_addtext( iMenu, "\r~ \wSolo tienes \r10 segundos para aceptar \wla invitacion", 0 );
	menu_addtext( iMenu, "\r~ \wPuedes \rdesactivar las invitaciones \wdesde el menu de grupos", 0 );
	
	menu_setprop( iMenu, MPROP_EXIT, MEXIT_NEVER );
	
	menu_display( iId, iMenu, .time = 10 );
	
	ClientPlaySound( iId, g_szInviteSound );
	
	return PLUGIN_HANDLED;
}

public OnConfirmMenuHandler( const iId, const iMenu, const iItem )
{
	if ( ( iItem == MENU_EXIT ) || ( iItem == MENU_TIMEOUT ) || !GetPlayerBit( g_iIsConnected, iId ) || GetPlayerBit( g_iHasGroup, iId ) )
	{
		menu_destroy( iMenu );
		
		return PLUGIN_HANDLED;
	}
	
	new iNum;
	
	new szInfo[ 16 ];
	new szInviter[ 4 ]
	new szUserid[ 12 ];
	
	menu_item_getinfo( iMenu, iItem, iNum, szInfo, charsmax( szInfo ), _, _, iNum );
	menu_destroy( iMenu );
	
	strtok( szInfo, szInviter, charsmax( szInviter ), szUserid, charsmax( szUserid ), '#' );
	
	new iInviter = str_to_num( szInviter );
	new iUserid = str_to_num( szUserid );
	
	if ( !GetPlayerBit( g_iIsConnected, iInviter ) || ( g_sPlayers[ iInviter ][ Player_Userid ] != iUserid ) )
	{
		return PLUGIN_HANDLED;
	}
	
	g_sPlayers[ iInviter ][ Player_Invite_Cooldown ] = 0.0;
	
	if ( iItem == 0 )
	{
		if ( !JoinGroup( iId, iInviter ) )
		{
			client_print_color( iId, print_team_default, "^4[%s]^1 No has podido unirte al grupo de^3 %s^1.", g_szPrefix, g_sPlayers[ iInviter ][ Player_Name ] );
			client_print_color( iInviter, print_team_default, "^4[%s]^3 %s^1 no pudo unirse a tu grupo.", g_szPrefix, g_sPlayers[ iId ][ Player_Name ] );
		}
	}
	else
	{
		client_print_color( iInviter, print_team_default, "^4[%s]^3 %s^1 ha rechazado tu invitacion.", g_szPrefix, g_sPlayers[ iId ][ Player_Name ] );
	}
	
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Group Modules ]
* ================================================================================= */

bool:JoinGroup( const iId, const iOwner )
{
	if ( !GetPlayerBit( g_iHasGroup, iOwner ) )
	{
		new iGroup = GetAvailableGroup( );
		
		if ( iGroup == GROUP_NONE )
		{
			return false;
		}
		
		g_sGroups[ iGroup ][ Group_Owner ] = iOwner;
		
		AddMember( iGroup, iOwner );
		AddMember( iGroup, iId );
		
		PrintGroupNotification( iGroup, g_szJoinSound, "Has sido integrado a un nuevo grupo." );
		
		return true;
	}
	
	new iGroup = g_sPlayers[ iOwner ][ Player_Group ];
	new iSize = g_sGroups[ iGroup ][ Group_Size ];
	
	if ( ( iSize >= MAX_GROUP_MEMBERS ) || ( GetGroupOwner( iGroup ) != iOwner ) )
	{
		return false;
	}
	
	AddMember( iGroup, iId );
	
	PrintGroupNotification( iGroup, g_szJoinSound, "^3%s^1 se ha unido al grupo.", g_sPlayers[ iId ][ Player_Name ] );
	
	return true;
}

LeaveGroup( const iLeaver )
{
	new iGroup = GetGroupIndex( iLeaver );
	new iSize = GetGroupSize( iGroup );
	new iOwner = GetGroupOwner( iGroup );
	
	if ( ( iSize == 2 ) || ( iOwner == iLeaver ) )
	{
		PrintGroupNotification( iGroup, g_szLeftSound, "El grupo se ha disuelto." );
		
		CleanGroup( iGroup );
	}
	else
	{
		RemoveMember( iGroup, iLeaver );
		
		PrintGroupNotification( iGroup, g_szLeftSound, "^3%s^1 ha abandonado el grupo.", g_sPlayers[ iLeaver ][ Player_Name ] );
	}
}

AddMember( const iGroup, const iMember )
{
	new iSize = GetGroupSize( iGroup );
	
	g_sGroups[ iGroup ][ Group_Members ][ iSize ] = iMember;
	g_sGroups[ iGroup ][ Group_Size ]++;
	
	g_sPlayers[ iMember ][ Player_Group ] = iGroup;
	
	SetPlayerBit( g_iHasGroup, iMember );
}

RemoveMember( const iGroup, const iMember )
{
	new iSize = GetGroupSize( iGroup );
	
	for ( new i = 0 ; i < ( iSize - 1 ) ; i++ )
	{
		if ( GetGroupMember( iGroup, i ) == iMember )
		{
			g_sGroups[ iGroup ][ Group_Members ][ i ] = GetGroupMember( iGroup, ( iSize - 1 ) );
			
			break;
		}
	}
	
	g_sGroups[ iGroup ][ Group_Members ][ iSize - 1 ] = MEMBER_NONE;
	g_sGroups[ iGroup ][ Group_Size ]--;
	
	g_sPlayers[ iMember ][ Player_Group ] = GROUP_NONE;
	
	ClearPlayerBit( g_iHasGroup, iMember );
}

CleanGroup( const iGroup )
{
	new iSize = GetGroupSize( iGroup );
	
	for ( new i = ( iSize - 1 ) ; i >= 0 ; i-- )
	{
		RemoveMember( iGroup, GetGroupMember( iGroup, i ) );
	}
	
	g_sGroups[ iGroup ][ Group_Owner ] = OWNER_NONE;
	g_sGroups[ iGroup ][ Group_Size ] = 0;
}

GetAvailableGroup( )
{
	new iGroup = GROUP_NONE;
	
	for ( new i = 0 ; i < MAX_GROUPS ; i++ )
	{
		if ( g_sGroups[ i ][ Group_Size ] == 0 )
		{
			iGroup = i;
			
			break;
		}
	}
	
	return iGroup;
}

PrintGroupNotification( const iGroup, const szSound[ ] = "", const szMessage[ ], any:... )
{
	new szBuffer[ MAX_MESSAGE_LENGTH ];
	
	( numargs( ) > 3 ) ?
		vformat( szBuffer, charsmax( szBuffer ), szMessage, 4 ) :
		copy( szBuffer, charsmax( szBuffer ), szMessage );
	
	new iSize = GetGroupSize( iGroup );
	new iMember = 0;
	
	for ( new i = 0 ; i < iSize ; i++ )
	{
		iMember = GetGroupMember( iGroup, i );
		
		if ( GetPlayerBit( g_iIsConnected, iMember ) )
		{
			ClientPlaySound( iMember, szSound );
			client_print_color( iMember, print_team_default, "^4[%s]^1 %s.", g_szPrefix, szBuffer );
		}
	}
}

/* =================================================================================
* 				[ Natives ]
* ================================================================================= */

public _show_groups_menu( iPlugin, iParams )
{
	if ( iParams != 1 )
	{
		return;
	}
	
	new iId = get_param( 1 );
	
	if ( GetPlayerBit( g_iIsConnected, iId ) )
	{
		ShowGroupMenu( iId );
	}
}

public _get_user_group( iPlugin, iParams )
{
	if ( iParams != 1 )
	{
		return GROUP_NONE;
	}
	
	new iId = get_param( 1 );
	
	if ( !GetPlayerBit( g_iHasGroup, iId ) )
	{
		return GROUP_NONE;
	}
	
	return GetGroupIndex( iId );
}

public _get_group_members( iPlugin, iParams )
{
	if ( iParams != 4 )
	{
		return;
	}
	
	new iId = get_param( 1 );
	new iGroup = get_param( 2 );
	
	if ( GetPlayerBit( g_iHasGroup, iId ) )
	{
		iGroup = GetGroupIndex( iId );
	}
	
	if ( ( iGroup < 0 ) || ( iGroup >= MAX_GROUPS ) )
	{
		return;
	}
	
	set_array( 2, g_sGroups[ iGroup ][ Group_Members ], MAX_GROUP_MEMBERS );
	set_param_byref( 3, g_sGroups[ iGroup ][ Group_Size ] );
}