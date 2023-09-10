#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <msgstocks>

#define VERSION "0.1"

/*
const MAX_ATTRIB_LEVEL = 10;

const MIN_HP = 75;
const MAX_HP = 255;
const Float:MIN_SPEED_MUL = 0.9;
const Float:MAX_SPEED_MUL = 1.3;
*/

const Menu_ChooseAppearance = 3;

enum (+=100)
{
	TASK_CYCLE = 0,
	TASK_DISPLAYHUD,
	TASK_BOT,
};

enum
{
	WINSTATUS_NONE = 0,
	WINSTATUS_CTS,
	WINSTATUS_TERRORISTS,
	WINSTATUS_DRAW,
};

enum _:CsdmData
{
	Float:csdm_origin[3],
	Float:csdm_angles[3],
	Float:csdm_v_angle[3],
};

enum _:Attributes
{
	ATTRIB_HP, // 體力
	ATTRIB_DEF, // 防禦
	ATTRIB_ATK, // 攻擊
	ATTRIB_STR, // 力量
	ATTRIB_INT, // 智力
	ATTRIB_SPD, // 速度
};

enum _:SocietyData
{
	SOCIETY_NAME[32],
	SOCIETY_ATTRIB[Attributes],
};

// test enum
new const g_Societies[][SocietyData] = 
{
	{"???", {0, 0, 0, 0, 0, 0}},
	{"射擊社", {4, 6, 4, 7, 5, 4}},
	{"拳擊社", {6, 5, 8, 3, 3, 5}},
	{"資訊社", {1, 3, 1, 3, 8, 2}},
	{"田徑社", {4, 3, 3, 2, 3, 8}},
	{"化學社", {3, 1, 3, 6, 6, 3}},
	{"烹飪社", {8, 3, 4, 5, 4, 1}},
};

new const BOT_NAME[] = "Battle Royale BOT";

new const OBJECTIVE_CLASSNAME[][] =
{
	"func_bomb_target",
	"info_bomb_target",
	"info_vip_start",
	"func_vip_safetyzone",
	"func_escapezone",
	"hostage_entity",
	"monster_scientist",
	"func_hostage_rescue",
	"info_hostage_rescue",
	"func_buyzone"
};

const OFFSET_MAPZONE = 235;
const PLAYER_IN_BUYZONE = (1<<0);
const HUD_HIDE_TIMER = (1<<4);

new CvarFreezeTime, CvarPrepareTime, CvarBattleTime;
new CvarFriendlyFire;
new CvarLightLevel[16];

new g_Days;
new g_CountDown;
new g_Fakeplayer;

//new g_NinjaTeleported[MAX_PLAYERS + 1];
new g_PlayerSociety[MAX_PLAYERS + 1];

new g_PreparePhase;
new g_BattlePhase;

new g_fwdEntSpawn;

new Array:g_CsdmSpawns;
new g_SpawnCountCSDM;

new CvarMaxLevel;
new CvarMinHp, CvarMaxHp;
new Float:CvarMinSpeedMul, Float:CvarMaxSpeedMul;
new Float:CvarMinAtk, Float:CvarMaxAtk;
new Float:CvarMinDefense, Float:CvarMaxDefense;

new g_spr_steam;

public plugin_precache()
{
	g_fwdEntSpawn = register_forward(FM_Spawn, "OnEntSpawn");

	g_CsdmSpawns = ArrayCreate(CsdmData);

	g_spr_steam = precache_model("sprites/steam1.spr");
}

public plugin_init()
{
	register_plugin("Battle Royale", VERSION, "holla");

	//register_clcmd("joinclass", "CmdJoinClass");

	register_event("HLTV", "EventRestartRound", "a", "1=0", "2=0");
	register_event("ResetHUD", "EventResetHud", "be");
	register_event("HideWeapon", "EventHideWeapon", "be");

	register_message(get_user_msgid("StatusIcon"), "MsgStatusIcon");

	register_logevent("EventRoundStart", 2, "1=Round_Start")
	register_logevent("EventJoinTeam", 3, "1=joined team");

	unregister_forward(FM_Spawn, g_fwdEntSpawn);

	RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled");
	RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxSpeed_Post", 1);
	RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage");

	set_cvar_num("mp_playerid", 2); // no display name
	set_cvar_num("mp_autoteambalance", 0); // no auto team balance
	set_cvar_num("mp_limitteams", 0); // no limit join team

	new pcvar = get_cvar_pointer("mp_freezetime");
	bind_pcvar_num(pcvar, CvarFreezeTime);

	pcvar = create_cvar("br_prepare_time", "60");
	bind_pcvar_num(pcvar, CvarPrepareTime);

	pcvar = create_cvar("br_battle_time", "60");
	bind_pcvar_num(pcvar, CvarBattleTime);

	pcvar = create_cvar("br_light_level", "d");
	bind_pcvar_string(pcvar, CvarLightLevel, charsmax(CvarLightLevel));

	pcvar = create_cvar("br_max_attrib_level", "10");
	bind_pcvar_num(pcvar, CvarMaxLevel);

	pcvar = create_cvar("br_attr_min_hp", "75");
	bind_pcvar_num(pcvar, CvarMinHp);

	pcvar = create_cvar("br_attr_max_hp", "255");
	bind_pcvar_num(pcvar, CvarMaxHp);

	pcvar = create_cvar("br_attr_min_speed_mul", "0.85");
	bind_pcvar_float(pcvar, CvarMinSpeedMul);

	pcvar = create_cvar("br_attr_max_speed_mul", "1.3");
	bind_pcvar_float(pcvar, CvarMaxSpeedMul);

	pcvar = create_cvar("br_attr_min_atk", "0.6");
	bind_pcvar_float(pcvar, CvarMinAtk);

	pcvar = create_cvar("br_attr_max_atk", "2.5");
	bind_pcvar_float(pcvar, CvarMaxAtk);

	pcvar = create_cvar("br_attr_min_def", "1.0");
	bind_pcvar_float(pcvar, CvarMinDefense);

	pcvar = create_cvar("br_attr_max_def", "0.4");
	bind_pcvar_float(pcvar, CvarMaxDefense);

	CvarFriendlyFire = get_cvar_pointer("mp_friendlyfire");

	set_task(5.0, "UpdateBot", TASK_BOT);
	set_task(0.5, "TaskDisplayHud", TASK_DISPLAYHUD, _, _, "b");

	EventRestartRound(); // fix RestartRound()

	LoadSpawns();
}

public plugin_natives()
{
	register_library("BattleRoyale");

	register_native("BR_GetPlayerSociety", "NativeGetPlayerSociety");
	register_native("BR_GetPlayerAttrib", "NativeGetPlayerAttrib");
}

public OnEntSpawn(ent)
{
	if (!pev_valid(ent))
		return FMRES_IGNORED;
	
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));

	for (new i = 0; i < sizeof(OBJECTIVE_CLASSNAME); i++)
	{
		if (equal(classname, OBJECTIVE_CLASSNAME[i]))
		{
			remove_entity(ent);
			return FMRES_SUPERCEDE;
		}
	}

	return FMRES_IGNORED;
}

public EventRestartRound()
{
	g_PreparePhase = false;
	g_BattlePhase = false;
	g_CountDown = CvarFreezeTime;
	g_Days = 0;

	server_cmd("amx_set_ffa 0");
	server_exec();

	set_pcvar_num(CvarFriendlyFire, 0);

	set_lights("");

	remove_task(TASK_CYCLE);
	set_task(1.0, "TaskCountDown", TASK_CYCLE, _, _, "b");
}

public EventRoundStart()
{
	StartPrepareTime();
}

public EventResetHud(id)
{
	set_ent_data(id, "CBasePlayer", "m_iClientHideHUD", 0);
	set_ent_data(id, "CBasePlayer", "m_iHideHUD", HUD_HIDE_TIMER);
}

public EventHideWeapon(id)
{
	set_ent_data(id, "CBasePlayer", "m_iClientHideHUD", 0);
	set_ent_data(id, "CBasePlayer", "m_iHideHUD", HUD_HIDE_TIMER);
}

public MsgStatusIcon(msgid, msgdest, id)
{
	if (!is_user_alive(id))
		return PLUGIN_CONTINUE;

	new sprite[10];
	get_msg_arg_string(2, sprite, charsmax(sprite));
	
	if (equal(sprite, "buyzone"))
	{
		set_pdata_int(id, OFFSET_MAPZONE, get_pdata_int(id, OFFSET_MAPZONE) & ~PLAYER_IN_BUYZONE);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

/*
public CmdJoinClass(id)
{
	client_print(0, print_chat, "%n is used cmd joinclass", id);
	server_print("%n is used cmd joinclass", id);

	if (get_ent_data(id, "CBasePlayer", "m_iTeam") == 1)
		set_ent_data(id, "CBasePlayer", "m_iTeam", 2); // set player to ct
}*/

public EventJoinTeam()
{
	// copying code
	new loguser[80], name[32];
	read_logargv(0, loguser, charsmax(loguser));
	parse_loguser(loguser, name, charsmax(name));

	new id = get_user_index(name);

	if (!is_user_connected(id))
	{
		return;
	}

	new team[2];
	read_logargv(2, team, charsmax(team));

	if (team[0] == 'T')
	{
		cs_set_user_team(id, CS_TEAM_CT);
	}
}

public StartPrepareTime()
{
	g_Days++;

	if (g_Days > 3)
	{
		if (get_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus") == WINSTATUS_NONE)
		{
			client_print(0, print_center, "#Cstrike_TitlesTXT_Round_Draw");
			SendAudioMsg(0, 0, "%!MRAD_draw", 100);

			TerminateRound(5.0, WINSTATUS_DRAW);

			KillAllPlayers();
		}

		return;
	}
	else if (g_Days > 1)
	{
		RepsawnPlayers();
	}

	server_cmd("amx_set_ffa 0");
	server_exec();

	set_pcvar_num(CvarFriendlyFire, 0);

	set_lights("");

	g_PreparePhase = true;
	g_BattlePhase = false;

	g_CountDown = CvarPrepareTime;

	remove_task(TASK_CYCLE);
	set_task(1.0, "TaskCountDown", TASK_CYCLE, _, _, "b");

	client_cmd(0, "spk fvox/bell.wav");
}

public StartBattleTime()
{
	g_PreparePhase = false;
	g_BattlePhase = true;

	server_cmd("amx_set_ffa 1");
	server_exec();

	set_lights(CvarLightLevel);

	set_dhudmessage(0, 255, 0, -1.0, 0.25, 0, 0.0, 3.0, 1.0, 1.0);
	show_dhudmessage(0, "開始戰鬥! (第 %d 日)", g_Days);

	client_cmd(0, "spk scientist/scream1.wav");

	g_CountDown = CvarBattleTime;

	remove_task(TASK_CYCLE);
	set_task(1.0, "TaskCountDown", TASK_CYCLE, _, _, "b");
}

public TaskDisplayHud()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_alive(i))
			DisplayPlayerHud(i);
	}
}

public client_disconnected(id)
{
	if (g_Fakeplayer == id)
	{
		set_task(1.5, "UpdateBot");
		g_Fakeplayer = 0;
	}

	g_PlayerSociety[id] = 0;
}

public OnPlayerSpawn_Post(id)
{
	if (!is_user_alive(id))
		return;
	
	if (g_Fakeplayer == id)
	{
		set_pev( id, pev_frags, -689.0 );
		cs_set_user_deaths( id, -777 );
		
		set_pev( id, pev_effects, pev( id, pev_effects ) | EF_NODRAW );
		set_pev( id, pev_solid, SOLID_NOT );
		entity_set_origin( id, Float:{ 999999.0, 999999.0, 999999.0 } );
		dllfunc( DLLFunc_Think, id );
	}
	else
	{
		DoRandomSpawn(id);

		g_PlayerSociety[id] = random_num(1, sizeof(g_Societies) - 1);

		new lvl = GetPlayerAttrib(id, ATTRIB_HP);
		new hp = CvarMinHp + (CvarMaxHp - CvarMinHp) / CvarMaxLevel * lvl;

		set_pev(id, pev_health, float(hp));
		set_pev(id, pev_max_health, float(hp));

		ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id);
	}
}

public OnPlayerKilled(id)
{
	CheckWinConditions();
}

public OnPlayerResetMaxSpeed_Post(id)
{
	if (is_user_alive(id))
	{
		new Float:maxspeed;
		pev(id, pev_maxspeed, maxspeed);

		new lvl = GetPlayerAttrib(id, ATTRIB_SPD);
		new Float:multiplier = CvarMinSpeedMul + (CvarMaxSpeedMul - CvarMinSpeedMul) / CvarMaxLevel * lvl;

		set_pev(id, pev_maxspeed, maxspeed * multiplier);
	}
}

public OnPlayerTakeDamage(id, inflictor, attacker, Float:damage, dmg_type)
{
	if (is_user_connected(attacker) && inflictor == attacker && cs_get_user_team(id) != cs_get_user_team(attacker))
	{
		client_print(0, print_chat, "olddmg = %f", damage);

		new lvl = GetPlayerAttrib(attacker, ATTRIB_ATK);
		new Float:multiplier = CvarMinAtk + (CvarMaxAtk - CvarMinAtk) / CvarMaxLevel * lvl;
		damage *= multiplier;

		client_print(0, print_chat, "atk: %f", multiplier);

		lvl = GetPlayerAttrib(id, ATTRIB_DEF);
		multiplier = CvarMinDefense + (CvarMaxDefense - CvarMinDefense) / CvarMaxLevel * lvl;
		damage *= multiplier;

		client_print(0, print_chat, "def: %f", multiplier);
		client_print(0, print_chat, "newdmg = %f", damage);

		SetHamParamFloat(4, damage);
		return HAM_HANDLED;
	}

	return HAM_IGNORED;
}

public TaskCountDown()
{
	g_CountDown--;

	if (g_CountDown > 0)
	{
		if (g_CountDown <= 10)
		{
			new word[16];
			num_to_word(g_CountDown, word, charsmax(word));
			client_cmd(0, "spk fvox/%s", word); // play countdown sound
		}

		set_dhudmessage(0, 255, 0, -1.0, 0.2, 0, 0.0, 1.0, 0.0, 0.0);

		if (g_PreparePhase)
			show_dhudmessage(0, "預備時間 %d 秒...", g_CountDown);
		else if (!g_BattlePhase)
			show_dhudmessage(0, "靜止時間 %d 秒...", g_CountDown);
	}
	else
	{
		remove_task(TASK_CYCLE);

		if (g_PreparePhase)
			StartBattleTime();
		else if (g_BattlePhase)
			StartPrepareTime();
	}
}

public UpdateBot()
{
	new id = find_player( "i" );
	
	if ( !id )
	{
		id = engfunc( EngFunc_CreateFakeClient, BOT_NAME );
		if ( pev_valid( id ) )
		{
			engfunc( EngFunc_FreeEntPrivateData, id );
			dllfunc( MetaFunc_CallGameEntity, "player", id );
			set_user_info( id, "rate", "3500" );
			set_user_info( id, "cl_updaterate", "25" );
			set_user_info( id, "cl_lw", "1" );
			set_user_info( id, "cl_lc", "1" );
			set_user_info( id, "cl_dlmax", "128" );
			set_user_info( id, "cl_righthand", "1" );
			set_user_info( id, "_vgui_menus", "0" );
			set_user_info( id, "_ah", "0" );
			set_user_info( id, "dm", "0" );
			set_user_info( id, "tracker", "0" );
			set_user_info( id, "friends", "0" );
			set_user_info( id, "*bot", "1" );
			set_pev( id, pev_flags, pev( id, pev_flags ) | FL_FAKECLIENT );
			set_pev( id, pev_colormap, id );
			
			new szMsg[ 128 ];
			dllfunc( DLLFunc_ClientConnect, id, BOT_NAME, "127.0.0.1", szMsg );
			dllfunc( DLLFunc_ClientPutInServer, id );
			
			cs_set_user_team( id, CS_TEAM_T );
			ExecuteHamB( Ham_CS_RoundRespawn, id );
			
			set_pev( id, pev_effects, pev( id, pev_effects ) | EF_NODRAW );
			set_pev( id, pev_solid, SOLID_NOT );
			dllfunc( DLLFunc_Think, id );
			
			g_Fakeplayer = id;
		}
	}
}

public NativeGetPlayerSociety()
{
	new id = get_param(1);
	
	return g_PlayerSociety[id];
}

public NativeGetPlayerAttrib()
{
	new id = get_param(1);
	new attr = get_param(2);

	return GetPlayerAttrib(id, attr);
}

/* CS Source Code

inline void CHalfLifeMultiplay::TerminateRound(float tmDelay, int iWinStatus)
{
	m_iRoundWinStatus = iWinStatus;
	m_flRestartRoundTime = gpGlobals->time + tmDelay;
	m_bRoundTerminating = true;
}
*/

stock NinjaTeleport(id, attacker)
{
	g_NinjaTeleported[id] = 1;

	new origin[3];
	get_user_origin(id, origin);

	te_create_smoke(origin, g_spr_steam, 15, 10, 0, true);

	client_print(id, print_chat, "[BR] 你被打到重傷, 暫時撤退");
}

stock RepsawnPlayers()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		// not connected or choosing class
		if (!is_user_connected(i) || get_ent_data(i, "CBasePlayer", "m_iMenu") == Menu_ChooseAppearance)
			continue;
		
		// respawn only dead ct
		if (!is_user_alive(i) && get_ent_data(i, "CBasePlayer", "m_iTeam") == 2)
			ExecuteHam(Ham_CS_RoundRespawn, i);
	}
}

stock KillAllPlayers()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_alive(i))
			user_silentkill(i, 0);
	}
}

stock DisplayPlayerHud(id)
{
	set_hudmessage(0, 255, 0, -1.0, 0.05, 0, 0.0, 1.2, 0.0, 0.5, 4);

	new timermsg[32];
	if (g_BattlePhase)
	{
		new count = g_CountDown;
		new mins = count / 60;
		new secs = count % 60;

		formatex(timermsg, charsmax(timermsg), "| 戰鬥時間: %d:%s%d", mins, (secs < 10 ? "0" : ""), secs);
	}

	show_hudmessage(id, "第 %d 日 %s^n社團: %s (體:%d 防:%d 攻:%d 力:%d 智:%d 速:%d)", g_Days, timermsg, 
		g_Societies[g_PlayerSociety[id]][SOCIETY_NAME],
		GetPlayerAttrib(id, ATTRIB_HP), GetPlayerAttrib(id, ATTRIB_DEF), GetPlayerAttrib(id, ATTRIB_ATK),
		GetPlayerAttrib(id, ATTRIB_STR), GetPlayerAttrib(id, ATTRIB_INT), GetPlayerAttrib(id, ATTRIB_SPD));
}

stock CheckWinConditions()
{
	if (get_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus") != WINSTATUS_NONE)
		return;

	new numAliveCts = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
			numAliveCts++;
	}

	if (numAliveCts == 1)
	{
		// make end round!
		client_print(0, print_center, "#Cstrike_TitlesTXT_CTs_Win");
		SendAudioMsg(0, 0, "%!MRAD_ctwin", 100);

		set_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins", get_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins") + 1);
		UpdateTeamScores();

		TerminateRound(5.0, WINSTATUS_CTS);
	}
}

stock TerminateRound(Float:delay, win_status)
{
	// amxx 1.9 new functions, it is like set offset (set_pdata_xxx)
	set_gamerules_int("CHalfLifeMultiplay", "m_iRoundWinStatus", win_status);
	set_gamerules_float("CHalfLifeMultiplay", "m_fTeamCount", get_gametime() + delay);
	set_gamerules_int("CHalfLifeMultiplay", "m_bRoundTerminating", true);
}

stock SendAudioMsg(id, sender, const audio[], pitch)
{
	static msgSendAudio;
	msgSendAudio || (msgSendAudio = get_user_msgid("SendAudio"));
	
	emessage_begin(id ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgSendAudio, _, id);
	ewrite_byte(sender);
	ewrite_string(audio);
	ewrite_short(pitch);
	emessage_end();
}

stock UpdateTeamScores()
{
	static msgTeamScore;
	msgTeamScore || (msgTeamScore = get_user_msgid("TeamScore"));
	
	emessage_begin(MSG_BROADCAST, msgTeamScore);
	ewrite_string("CT");
	ewrite_short(get_gamerules_int("CHalfLifeMultiplay", "m_iNumCTWins"));
	emessage_end();
	
	emessage_begin(MSG_BROADCAST, msgTeamScore);
	ewrite_string("TERRORIST");
	ewrite_short(get_gamerules_int("CHalfLifeMultiplay", "m_iNumTerroristWins"));
	emessage_end();
}

stock DoRandomSpawn(id)
{
	new spawn_index, current_index;
	new hull = (pev(id, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;

	if (g_SpawnCountCSDM)
	{
		new csdmdata[CsdmData];
		spawn_index = random(g_SpawnCountCSDM);

		// Try to find a clear spawn
		for (current_index = spawn_index + 1; /*no condition*/; current_index++)
		{
			// Start over when we reach the end
			if (current_index >= g_SpawnCountCSDM) current_index = 0
			
			ArrayGetArray(g_CsdmSpawns, current_index, csdmdata);

			// Free spawn space?
			if (IsHullVacant(csdmdata[csdm_origin], hull))
			{
				// Engfunc_SetOrigin is used so ent's mins and maxs get updated instantly
				engfunc(EngFunc_SetOrigin, id, csdmdata[csdm_origin]);

				set_pev(id, pev_angles, csdmdata[csdm_angles]);
				set_pev(id, pev_v_angle, csdmdata[csdm_v_angle]);

				break;
			}
			
			// Loop completed, no free space found
			if (current_index == spawn_index) break;
		}
	}
}

stock LoadSpawns()
{
	new cfgdir[32], mapname[32], filepath[100], linedata[64];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/csdm/%s.spawns.cfg", cfgdir, mapname);

	if (file_exists(filepath))
	{
		new i;
		new csdmstr[10][6], file = fopen(filepath,"rt");
		new csdmdata[CsdmData];
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata))
			
			// invalid spawn
			if(!linedata[0] || str_count(linedata,' ') < 2) continue;
			
			// get spawn point data
			parse(linedata,csdmstr[0],5,csdmstr[1],5,csdmstr[2],5,csdmstr[3],5,csdmstr[4],5,csdmstr[5],5,csdmstr[6],5,csdmstr[7],5,csdmstr[8],5,csdmstr[9],5);
			
			for (i = 0; i < 3; i++)
			{
				csdmdata[csdm_origin][i] = str_to_float(csdmstr[i]);
				csdmdata[csdm_angles][i] = str_to_float(csdmstr[i+3]);
				csdmdata[csdm_v_angle][i] = str_to_float(csdmstr[i+6]);
			}
			
			ArrayPushArray(g_CsdmSpawns, csdmdata);

			/*
			server_print("[csdm] %d: origin{%.2f,%.2f,%.2f} angles{%.2f,%.2f,%.2f} v_angle{%.2f,%.2f,%.2f}", g_SpawnCountCSDM,
				csdmdata[csdm_origin][0], csdmdata[csdm_origin][1], csdmdata[csdm_origin][2],
				csdmdata[csdm_angles][0], csdmdata[csdm_angles][1], csdmdata[csdm_angles][2],
				csdmdata[csdm_v_angle][0], csdmdata[csdm_v_angle][1], csdmdata[csdm_v_angle][2]);
			*/
			// increase spawn count
			g_SpawnCountCSDM++
		}
		if (file) fclose(file)
	}
	else
	{
		// Collect regular spawns
		CollectSpawnsEnt("info_player_start")
		CollectSpawnsEnt("info_player_deathmatch")
	}
}

stock CollectSpawnsEnt(const classname[])
{
	new csdmdata[CsdmData];
	new Float:data[3];

	new ent = -1;
	while ((ent = find_ent_by_class(ent, classname)) != 0)
	{
		// get origin
		pev(ent, pev_origin, data)
		csdmdata[csdm_origin][0] = data[0];
		csdmdata[csdm_origin][1] = data[1];
		csdmdata[csdm_origin][2] = data[2];
		
		// angles
		pev(ent, pev_angles, data)
		csdmdata[csdm_angles][0] = data[0];
		csdmdata[csdm_angles][1] = data[1];
		csdmdata[csdm_angles][2] = data[2];
		
		// view angles
		pev(ent, pev_v_angle, data)
		csdmdata[csdm_v_angle][0] = data[0];
		csdmdata[csdm_v_angle][1] = data[1];
		csdmdata[csdm_v_angle][2] = data[2];
		
		ArrayPushArray(g_CsdmSpawns, csdmdata);

		/*
		server_print("[spawns] #%d: origin{%.2f,%.2f,%.2f} angles{%.2f,%.2f,%.2f} v_angle{%.2f,%.2f,%.2f}", g_SpawnCountCSDM,
			csdmdata[csdm_origin][0], csdmdata[csdm_origin][1], csdmdata[csdm_origin][2],
			csdmdata[csdm_angles][0], csdmdata[csdm_angles][1], csdmdata[csdm_angles][2],
			csdmdata[csdm_v_angle][0], csdmdata[csdm_v_angle][1], csdmdata[csdm_v_angle][2]);
		*/

		// increase spawn count
		g_SpawnCountCSDM++
	}
}

// Checks if a space is vacant (credits to VEN)
stock IsHullVacant(Float:origin[], hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0)
	
	if (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

// Stock by (probably) Twilight Suzuka -counts number of chars in a string
stock str_count(const str[], searchchar)
{
	new count, i, len = strlen(str)
	
	for (i = 0; i <= len; i++)
	{
		if(str[i] == searchchar)
			count++
	}
	
	return count;
}

stock GetPlayerAttrib(id, attrib)
{
	return g_Societies[g_PlayerSociety[id]][SOCIETY_ATTRIB][attrib];
}