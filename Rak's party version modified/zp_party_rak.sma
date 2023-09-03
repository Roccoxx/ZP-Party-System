#include <amxmodx>
#include <hamsandwich>
#include <zombieplague>

#define PLUGIN "Party Menu"
#define VERSION "2.2"
#define AUTHOR "[R]ak"

#define TAG	"[Party]"
#define ID_HUD	(taskid - TASK_HUD)

enum (+= 77) {
	TASK_HUD = 777,
	TASK_ACEPT
}

enum {
	NONE = -1,
	Master,
	Start_Amount
}

enum _:pdata {
	In_Party,
	Position,
	Amount_In_Party,
	Block_Party,
	UserName[32]
}

enum _:DataCallBack {
	MASTER,
	USER
}

new g_PartyData[33][pdata], Array:Party_Ids[33], g_maxplayers, g_MenuCallback[DataCallBack], g_MsgSayText

new cvar_time_acept, cvar_max_players, cvar_allow_bots

///////////////////// COMBOLAS

const TASK_FINISH_COMBO = 6969
#define ID_FINISH_COMBO (taskid - TASK_FINISH_COMBO)

new Float:iComboTime[33], Float:g_fDamageComboReward[33], g_iComboPartyHits[33], g_iComboPartyAP[33];

const Float:AmmoDamageReward = 500.0 // Cantidad de Daño a realizar para recibir 1 ammopack

// POSICION DEL HUD
const Float:fHudX = -1.0;
const Float:fHudY = 0.9;

new g_MsgSyncParty;

public plugin_init() {
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say /party", "cmdParty")
	register_clcmd("say_team", "cmdSayTeam")
	
	cvar_time_acept = register_cvar("party_time_acept","15")
	cvar_max_players = register_cvar("party_max_players","3")
	cvar_allow_bots = register_cvar("party_allow_bots","0")
	
	g_maxplayers = get_maxplayers()
	g_MsgSayText = get_user_msgid("SayText")
	
	g_MenuCallback[MASTER] = menu_makecallback("check_master")
	g_MenuCallback[USER] = menu_makecallback("check_user")

	// COMBOLAS
	RegisterHam(Ham_TakeDamage, "player", "Fw_TakeDamagePre", false);
	g_MsgSyncParty = CreateHudSyncObj();
}

public plugin_natives() register_native("zp_get_user_inparty", "is_user_inparty");

// en su plugin agregan: native zp_get_user_inparty(const id) debajo de los include y listo.
public is_user_inparty(const id) return g_PartyData[id][In_Party] ? 1 : 0;

public plugin_cfg()
	for(new i = 1; i <= g_maxplayers; i++)
		Party_Ids[i] = ArrayCreate(1, 1)

public client_disconnected(id){
	
	if(g_PartyData[id][In_Party])
		g_PartyData[id][Position] ? g_PartyData[id][Amount_In_Party] > 1 ? destoy_party(id) : remove_party_user(id) : destoy_party(id)
		
	g_PartyData[id][UserName][0] = 0
	g_PartyData[id][Block_Party] = false

	// COMBOLAS
	remove_task(id+TASK_FINISH_COMBO);
	g_fDamageComboReward[id] = 0.0;
	g_iComboPartyHits[id] = 0;
	g_iComboPartyAP[id] = 0;
	iComboTime[id] = 0.0;
	ClearSyncHud(id, g_MsgSyncParty);
}

public cmdParty(id) {
	
	if(g_PartyData[id][In_Party])
		show_party_info_menu(id)
	else
		show_party_menu(id)
	
	return PLUGIN_HANDLED
}

public show_party_menu(id) {
	
	new iMenu = menu_create("[R]ak Acme Inc.- \rMenu Party:","party_menu"), BlockParty[50]
	
	menu_additem(iMenu, "\yCrear Party", "0")
	
	formatex(BlockParty, charsmax(BlockParty), "\yBloquear Invitaciones De Party: \w%s",g_PartyData[id][Block_Party] ? "Si" : "No")
	
	menu_additem(iMenu, BlockParty, "1")
	
	menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
	
	menu_display(id, iMenu, 0)
}

public show_party_info_menu(id) {
	
	new iMenu = menu_create("[R]ak Acme Inc.- \rMenu Party:","party_info_menu")
	
	menu_additem(iMenu, "Agregar Integrante", .callback = g_MenuCallback[MASTER])
	menu_additem(iMenu, "Expulsar Integrande", .callback = g_MenuCallback[MASTER])
	menu_additem(iMenu, "Destruir Party", .callback = g_MenuCallback[MASTER])
	menu_additem(iMenu, "Salir del Party", .callback = g_MenuCallback[USER])
	
	menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
	
	menu_display(id, iMenu)
}

public show_party_add_menu(id) {
	
	new iMenu = menu_create(g_PartyData[id][In_Party] ? "\rAgregar Integrante:" : "\rCrear Party:", "party_create_menu"), Poss[6], Name[32]
	
	for(new i = 1; i <= g_maxplayers; i++) {
		
		if(!is_available_to_party(i) || id == i)
			continue;
			
		get_user_name(i, Name, charsmax(Name))
		num_to_str(i, Poss, charsmax(Poss))
		menu_additem(iMenu, Name, Poss)
	}
	
	menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
	
	menu_display(id, iMenu)
}

public show_party_kick_menu(id) {
	
	new iMenu = menu_create("\rKick Party Menu:","party_kick_menu"), Players[32], Poss[6], user
	
	get_party_index(id, Players)
	
	for(new i; i < g_PartyData[id][Amount_In_Party]; i++) {
		user = Players[i]
		num_to_str(user, Poss, charsmax(Poss))
		menu_additem(iMenu, g_PartyData[user][UserName], Poss)
	}
	
	menu_setprop(iMenu, MPROP_EXITNAME, "Salir")
	
	menu_display(id, iMenu)
}

public show_party_invite_menu(id2, MasterId) {
	
	new MenuTitle[128], iMenu, Str_MasterId[6]
	
	set_player_party_name(MasterId)
	set_player_party_name(id2)
	
	client_print(MasterId, print_chat, "%s Solicitud enviada a %s", TAG, g_PartyData[id2][UserName])
	
	formatex(MenuTitle, charsmax(MenuTitle), "%s te mando una invitacion para %s Party", g_PartyData[MasterId][UserName], g_PartyData[MasterId][In_Party] ? "unirte al" : "crear un")
	
	new UserTaskArgs[3]
	
	UserTaskArgs[0] = iMenu = menu_create( MenuTitle , "party_invite_menu")
	UserTaskArgs[1] = MasterId
	
	num_to_str(MasterId, Str_MasterId, charsmax(Str_MasterId))
	
	menu_additem( iMenu , "Aceptar", Str_MasterId)
	menu_additem( iMenu , "Rechazar", Str_MasterId)
	
	if(is_user_bot(id2) && get_pcvar_num(cvar_allow_bots)) {
		party_invite_menu(id2, iMenu, 0)
		return
	}
	
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER)
	
	menu_display(id2, iMenu)
	
	remove_task_acept(id2)
	
	set_task(get_pcvar_float(cvar_time_acept), "Time_Acept", id2+TASK_ACEPT, UserTaskArgs, 2)
}
	

public party_menu(id, menu, item) {
	
	if(item == MENU_EXIT) {
		menu_destroy(menu)
		return
	}
	
	if(item) {
		g_PartyData[id][Block_Party] = g_PartyData[id][Block_Party] ? false : true
		show_party_menu(id)
	}
	else
		show_party_add_menu(id)
	
	menu_destroy(menu)
	
}

public party_create_menu(id, menu, item) {
	
	if(item == MENU_EXIT) {
		menu_destroy(menu)
		return
	}
	
	new iKey[6], iAccess, iCallback, id2
	
	menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
	
	id2 = str_to_num(iKey)
	
	if(!is_available_to_party(id2))
		return
	
	show_party_invite_menu(id2, id)
	
	menu_destroy(menu)
}

public party_invite_menu(id, menu, item) {
	
	if(item == MENU_EXIT) {
		menu_destroy(menu)
		remove_task_acept(id)
		return
	}
	
	new iKey[6], iAccess, iCallback, id_master
	
	menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
	
	id_master = str_to_num(iKey)
	
	switch(item) {
		case 0: {
						
			if(!g_PartyData[id_master][In_Party]) {
				create_party(id_master, id)
				set_task_party_hud(id_master)
				set_task_party_hud(id)
			}
			else {
				if(g_PartyData[id_master][Amount_In_Party] == get_pcvar_num(cvar_max_players)) {
				
					client_print(id, print_chat, "%s Ya se alcanzo el numero maximo de integrantes en la party", TAG)
					client_print(id_master, print_chat, "%s Ya alcanzaste el numero maximo de integrantes en la party", TAG)
				
					remove_task_acept(id)
	
					menu_destroy(menu)
					return
				}
				
				add_party_user(id_master, id)
				set_task_party_hud(id)
			}
			
			client_print(id_master, print_chat, "%s %s fue agregado al Party", TAG, g_PartyData[id][UserName])
		}
		case 1: client_print(id_master, print_chat, "%s %s cancelo la invitacion de Party", TAG, g_PartyData[id][UserName])
	}
	
	remove_task_acept(id)
	
	menu_destroy(menu)
}

public party_kick_menu(id, menu, item) {
	
	if(item == MENU_EXIT) {
		menu_destroy(menu)
		return
	}
	
	new iKey[6], iAccess, iCallback, id2
	
	menu_item_getinfo(menu, item, iAccess, iKey, charsmax(iKey), _, _, iCallback)
	
	id2 = str_to_num(iKey)
	
	if(is_user_connected(id2))
		g_PartyData[id][Amount_In_Party] > 1 ? destoy_party(id) : remove_party_user(id2)
	
	menu_destroy(menu)
}

public party_info_menu(id, menu,item) {
	
	if(item == MENU_EXIT) {
		menu_destroy(menu)
		return
	}
	
	switch(item) {
		case 0: {
			if(g_PartyData[id][Amount_In_Party] < get_pcvar_num(cvar_max_players))
				show_party_add_menu(id)
			else
				client_print(id, print_chat, "%s Ya alcanzaste el numero maximo de integrantes en la party", TAG)
		}
		case 1: show_party_kick_menu(id)
		case 2: destoy_party(id)
		case 3: remove_party_user(id)
	}
	
	menu_destroy(menu)
}

public PartyHud(taskid) {
	
	static id
	id = ID_HUD
	
	if(!is_user_connected(id)) {
		remove_task(taskid)
		return
	}
	
	static CountParty, PartyMsg[256], Players[32], id2
	
	CountParty = 0
	PartyMsg[0] = 0

	get_party_index(id, Players)
	for(new i; i < g_PartyData[id][Amount_In_Party]; i++) {
		
		id2 = Players[i]
		
		if(CountParty)
			add(PartyMsg, charsmax(PartyMsg), "^n")
		
		format(PartyMsg, charsmax(PartyMsg), "%s%s", strlen(PartyMsg) ? PartyMsg : "^t^t^tMiembros del Party^n", g_PartyData[id2][UserName])
		CountParty++
	}
		
	set_hudmessage(255, 255, 255, 0.75, 0.34, 0, 6.0, 1.0);
	show_hudmessage(id, PartyMsg)
}

public Time_Acept(UserTaskArgs[], taskid) {
	
	taskid -= TASK_ACEPT;
	
	if(!g_PartyData[taskid][In_Party]) {
		
		client_print(UserTaskArgs[1], print_chat, "%s %s cancelo la invitacion de party", TAG, g_PartyData[taskid][UserName])
		menu_destroy(UserTaskArgs[0])
		show_menu(taskid, 0, "^n", 1)
	}
}

stock create_party(master, guest) {
	
	set_party_member(master, master)
	set_party_member(master, guest)
	set_party_member(guest, master)
	set_party_member(guest, guest)
	
	set_party_vars(master, Start_Amount)
	set_party_vars(guest, ++g_PartyData[master][Amount_In_Party])
}

stock add_party_user(master, guest) {
	
	new Players[32], member, amount = g_PartyData[master][Amount_In_Party]
		
	get_party_index(master, Players)
	
	for(new i; i < amount; i++) {
		
		member = Players[i]
		
		set_party_member(guest, member)
		set_party_member(member, guest)
		g_PartyData[member][Amount_In_Party]++
		
	}
	
	set_party_member(guest, guest)
	set_party_vars(guest, amount+1)	
}

stock set_party_member(id, id2)
	ArrayPushCell(Party_Ids[id], id2)

stock set_party_vars(id, amount) {
	
	g_PartyData[id][In_Party] = true
	g_PartyData[id][Position] = amount-1
	g_PartyData[id][Amount_In_Party] = amount
	
}

stock destoy_party(id){
	new Players[32], id2, Amount = g_PartyData[id][Amount_In_Party]
	get_party_index(id, Players)
	
	for(new i; i < Amount; i++) {
		id2 = Players[i]
		clear_party_user(id2)
		client_print(id2, print_chat, "%s La party fue destruida", TAG)
		
		// COMBOLAS
		remove_task(id2+TASK_FINISH_COMBO)
		set_task(1.0, "finish_combo", id2+TASK_FINISH_COMBO)	
	}
}

stock remove_party_user(user) {
	
	new Players[32], id, Amount = g_PartyData[user][Amount_In_Party]
	
	get_party_index(user, Players)
	
	clear_party_user(user)
	
	for(new i; i < Amount; i++) {
	
		id = Players[i]
		
		if(id != user) {
			ArrayClear(Party_Ids[id])
			
			for(new z; z < Amount; z++)					
				if(Players[z] != user)
					set_party_member(id, Players[z])
				
			g_PartyData[id][Position] = i
			g_PartyData[id][Amount_In_Party] = Amount-1
			client_print(id, print_chat, "%s %s salio del party", TAG, g_PartyData[user][UserName])
		}
	}
}

stock clear_party_user(id) {
	ArrayClear(Party_Ids[id])
	g_PartyData[id][In_Party] = false
	g_PartyData[id][Position] = NONE
	g_PartyData[id][Amount_In_Party] = NONE
	remove_task_party_hud(id)
	
	// COMBOLAS
	remove_task(id+TASK_FINISH_COMBO);
	g_fDamageComboReward[id] = 0.0;
	g_iComboPartyHits[id] = 0;
	g_iComboPartyAP[id] = 0;
	iComboTime[id] = 0.0;
	ClearSyncHud(id, g_MsgSyncParty);
}

stock set_task_party_hud(id)
	set_task(1.0, "PartyHud", id+TASK_HUD, _, _, "b")
	
stock remove_task_party_hud(id)
	remove_task(id+TASK_HUD)

stock remove_task_acept(id)
	if(task_exists(id+TASK_ACEPT))
		remove_task(id+TASK_ACEPT)
	

stock set_player_party_name(id) {
	
	if(g_PartyData[id][UserName][0])
		return 0
	
	get_user_name(id, g_PartyData[id][UserName], charsmax(g_PartyData[][UserName]))
	
	return 1
}

stock is_available_to_party(id) {
	
	if(!is_user_connected(id) || g_PartyData[id][In_Party] || g_PartyData[id][Block_Party])
		return false
	
	return true
}		
	
stock get_party_index(id, players[]) {
	
	for(new i; i < g_PartyData[id][Amount_In_Party]; i++)
		players[i] = ArrayGetCell(Party_Ids[id], i)
	
	return players[0] ? 1 : 0
}

public check_master(id)
	return g_PartyData[id][Position] ? ITEM_DISABLED : ITEM_ENABLED
	
public check_user(id)
	return g_PartyData[id][Position] ? ITEM_ENABLED : ITEM_DISABLED

public cmdSayTeam(id) {
	static Text[192]
	read_args(Text, charsmax(Text))
	remove_quotes(Text)
	
	replace_all(Text, charsmax(Text), "%", "")
	
	if(!ValidMessage(Text) || !g_PartyData[id][In_Party]) {
		client_print(id, print_chat,"%s Tu Mensaje es invalido o no te encuentras en un Party", TAG)
		return PLUGIN_HANDLED;
	}
	
	static Message[192], Players[32], id2, Amount 
	Amount = g_PartyData[id][Amount_In_Party]
	
	get_party_index(id, Players)
	
	formatex(Message, charsmax(Message), "^x04%s ^x03%s^x01 : %s", TAG, g_PartyData[id][UserName], Text)
	
	for(new i; i < Amount; i++){
		id2 = Players[i]

		if(!is_user_connected(id2)) continue;
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgSayText, _, id2)
		write_byte(id)
		write_string(Message)
		message_end()
	}
	
	return PLUGIN_HANDLED;
}

ValidMessage(text[]) {
	static len, i
	len = strlen(text)
	
	if(!len)
		return false
	
	for(i = 0; i < len; i++) {
		if( text[i] != ' ' ) {
			return true
		}
	}

	return false
}

////////////////////////////////////////////////////////////////////////////

public Fw_TakeDamagePre(iVictim, iInflictor, iAttacker, Float:fDamage) {
	if(is_user_connected(iAttacker) && is_user_connected(iVictim) && iAttacker != iVictim && g_PartyData[iAttacker][In_Party] && !zp_get_user_zombie(iAttacker)){
		
		static Float:gametime; gametime = get_gametime();
		static players[32], user; get_party_index(iAttacker, players );
		static bWinAP; bWinAP = false;

		// cuando el wachin haga el daño necesario se lo aporta al party.
		while(g_fDamageComboReward[iAttacker] >= AmmoDamageReward)
		{
			g_fDamageComboReward[iAttacker] -= AmmoDamageReward;
			bWinAP = true;
		}

		g_fDamageComboReward[iAttacker] += fDamage;

		for(new i; i < g_PartyData[iAttacker][Amount_In_Party]; i++) 
		{
			user = players[i];
			
			g_iComboPartyHits[user]++; // hits totales del party

			if(bWinAP) g_iComboPartyAP[user]++; // asignamos un AP al combo.
		
			if(iComboTime[user] < gametime)
			{
				ShowPartyCombo(user, iAttacker, fDamage);
				iComboTime[user] = gametime+0.1;
			}
		}
	}
}

ShowPartyCombo(iPartyID, iAttacker, Float:fDamage)
{
	if(iPartyID == iAttacker){
		set_hudmessage(0, 255, 0, fHudX, fHudY, 0, 3.0, 3.0, 0.01, 0.01);
		ShowSyncHudMsg(iPartyID, g_MsgSyncParty, "Combo Party - Ammopacks: %d^nHits: %d - Daño: %2.f", g_iComboPartyAP[iPartyID], g_iComboPartyHits[iPartyID], fDamage);
	}
	else{
		set_hudmessage(0, 255, 0, fHudX, fHudY, 0, 3.0, 3.0, 0.01, 0.01);
		ShowSyncHudMsg(iPartyID, g_MsgSyncParty, "Combo Party - Ammopacks: %d - Hits: %d", g_iComboPartyAP[iPartyID], g_iComboPartyHits[iPartyID]);
	}

	remove_task(iPartyID+TASK_FINISH_COMBO);
	set_task(10.0, "finish_combo", iPartyID+TASK_FINISH_COMBO);
}

public finish_combo(taskid){
	static id; id = ID_FINISH_COMBO;
	
	static recibidos; recibidos = ( g_iComboPartyAP[id] / g_PartyData[ id ][ Amount_In_Party ])

	if(recibidos < 0) recibidos = 0;

	zp_set_user_ammo_packs(id, zp_get_user_ammo_packs(id) + recibidos);			
	client_print_color(id, print_team_default, "^x04[PARTY]^x01 Ammopacks:^x03 %d con %d^x01 Hits en^x03 %d Personas", recibidos, g_iComboPartyHits[id], g_PartyData[ id ][ Amount_In_Party ]);

	g_fDamageComboReward[id] = 0.0;
	g_iComboPartyHits[id] = 0;
	g_iComboPartyAP[id] = 0;
	iComboTime[id] = 0.0;
	ClearSyncHud(id, g_MsgSyncParty);
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang11274\\ f0\\ fs16 \n\\ par }
*/
