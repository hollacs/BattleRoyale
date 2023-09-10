
// 15/04/2020: Initially completed

#include <amxmodx>
#include <fun>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <xs>


#define PLUGIN "Sleeping Sysytem"
#define VERSION "0.1" 
#define AUTHOR "Slime"

#define TASK_WAKEUP 100

#define ID_WAKEUP (taskid - TASK_WAKEUP)

#define OFFSET_PRIMARYWEAPON 116

new g_IsHiding[33]
new g_Weapons[33][32], g_PlayerClip[33][32], g_PlayerBpAmmo[33][32], g_numWeapons[33]

new Float:cvar_sleepingtime

new const WEAPONNAME[][] = {"", "weapon_p228", "weapon_shield", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10", "weapon_aug", "weapon_smokegrenade",
"weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550", "weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90"}

const FFADE_IN = 0x0000

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)
    register_clcmd("say /sleep", "clcmd_sleep")

    RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxSpeed", 1)

    new pcvar = create_cvar("sleepingtime", "10")
    bind_pcvar_float(pcvar, cvar_sleepingtime)
}

public client_disconnected(id)
{
    g_IsHiding[id] = false
    remove_task(id+TASK_WAKEUP)
}
public clcmd_sleep(id)
{
    if (!is_user_alive(id) || g_IsHiding[id])
        return PLUGIN_HANDLED;

    g_IsHiding[id] = true

    new Weapons[32]
    new numWeapons, i, clip, bpammo 

    // Store gun type and numbers of ammo
    get_user_weapons(id, Weapons, numWeapons)
    g_numWeapons[id] = numWeapons

    for (i=0; i<numWeapons; i++)
    {
        get_user_ammo(id, Weapons[i], clip, bpammo)
        g_Weapons[id][i] = Weapons[i]
        g_PlayerClip[id][i] = clip
        g_PlayerBpAmmo[id][i] = bpammo
    }

    // Client become invisible
    engclient_cmd(id, "weapon_knife")
    RequestFrame("delay_strip_user_weapons", id)
    set_pev(id, pev_solid, SOLID_NOT)
    set_pev(id, pev_effects, pev(id, pev_effects) | EF_NODRAW)

    // Set maxspeed to 1
    ExecuteHamB(Ham_CS_Player_ResetMaxSpeed, id)

    SendScreenFade(id, 0.01, cvar_sleepingtime, FFADE_IN, {0, 0, 200}, 70) // r, g, b

    // Create a sleeping entity
    new Float:origin[3]
    new modelpath[100], modelname[32]

    pev(id, pev_origin, origin)
    cs_get_user_model(id, modelname, 31)

    formatex(modelpath, 99, "models/player/%s/%s.mdl", modelname, modelname)

    new ent = create_entity("info_target")
    new Float:vec[3]
    
    velocity_by_aim(id, 60, vec)
    vec[2] = 0.0
    xs_vec_add(origin, vec, origin)
    entity_set_origin(ent, origin)
    entity_set_model(ent, modelpath)

    entity_set_string(ent, EV_SZ_classname, "sleepingbody")
    entity_set_edict(ent, EV_ENT_owner, id)
    
    entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
    entity_set_size(ent, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0})
    entity_set_int(ent, EV_INT_sequence, 108)
    entity_set_float(ent, EV_FL_framerate, 1.0)
	entity_set_float(ent, EV_FL_frame, 254.0)

    new Float:angle[3]

    entity_get_vector(id, EV_VEC_angles, angle)
    entity_set_vector(ent, EV_VEC_angles, angle)

    set_task(cvar_sleepingtime, "WakeUp", id+TASK_WAKEUP)

    return PLUGIN_HANDLED;
}

public OnPlayerResetMaxSpeed(id)
{
    if (is_user_alive(id) && g_IsHiding[id])
        set_pev(id, pev_maxspeed, 1.0);
}

public delay_strip_user_weapons(id)
{
    strip_user_weapons(id)
}

public WakeUp(taskid)
{
    g_IsHiding[ID_WAKEUP] = false

    new ent = find_ent_by_owner(-1, "sleepingbody", ID_WAKEUP)
    remove_entity(ent)

    // Client become visible
    set_pev(ID_WAKEUP, pev_solid, SOLID_SLIDEBOX)
    set_pev(ID_WAKEUP, pev_effects, pev(ID_WAKEUP, pev_effects) & ~EF_NODRAW)
    
    // Give back client's weapons
    new i

    for (i=0; i<g_numWeapons[ID_WAKEUP]; i++)
    {
        new ent_id = give_item(ID_WAKEUP, WEAPONNAME[g_Weapons[ID_WAKEUP][i]])
        cs_set_weapon_ammo(ent_id, g_PlayerClip[ID_WAKEUP][i])
        cs_set_user_bpammo(ID_WAKEUP, g_Weapons[ID_WAKEUP][i], g_PlayerBpAmmo[ID_WAKEUP][i])
    }
}

stock SendScreenFade(id, Float:duration, Float:holdTime, flags, color[3], alpha, bool:external=false)
{
	static msgScreenFade;
	msgScreenFade || (msgScreenFade = get_user_msgid("ScreenFade"));
	
	if (external)
	{
		emessage_begin(MSG_ONE_UNRELIABLE, msgScreenFade, _, id);
		ewrite_short(FixedUnsigned16(duration, 1<<12));
		ewrite_short(FixedUnsigned16(holdTime, 1<<12));
		ewrite_short(flags);
		ewrite_byte(color[0]);
		ewrite_byte(color[1]);
		ewrite_byte(color[2]);
		ewrite_byte(alpha);
		emessage_end();
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, msgScreenFade, _, id);
		write_short(FixedUnsigned16(duration, 1<<12));
		write_short(FixedUnsigned16(holdTime, 1<<12));
		write_short(flags);
		write_byte(color[0]);
		write_byte(color[1]);
		write_byte(color[2]);
		write_byte(alpha);
		message_end();
	}
}

stock FixedUnsigned16(Float:value, scale)
{
	new output = floatround(value * scale);
	return clamp(output, 0, 0xFFFF);
}