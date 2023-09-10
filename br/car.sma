#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <hamsandwich>
#include <xs>
#include <bmod>

new g_PlayerCar[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Car", "0.1", "holla");

	register_clcmd("say /car", "CmdSayCar");

	register_forward(FM_CmdStart, "OnCmdStart");
	//register_forward(FM_SetView, "OnSetView");

	RegisterHam(Ham_Think, "trigger_camera", "OnCameraThink");

	bmod_stepcfg(5, 1.0/1000);
	bmod_shape_cfg(TST_concave_static);
	bmod_obj_from_ent(0);
}

public plugin_precache()
{
	precache_model("models/test/car_z.mdl");
}

public CmdSayCar(id)
{
	if (!is_user_alive(id))
		return PLUGIN_HANDLED;

	new ent = create_entity("func_wall");

	if (!is_valid_ent(ent))
		return PLUGIN_HANDLED;

	new Float:origin[3], obj;
	entity_get_vector(id, EV_VEC_origin, origin);
	origin[2] += 128.0;

	//entity_set_int(id, EV_INT_movetype, MOVETYPE_FLY);

	entity_set_origin(ent, origin);

	entity_set_model(ent, "models/test/car_z.mdl");
	entity_set_float(ent, EV_FL_nextthink, 86400.0);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_edict(ent, EV_ENT_owner, id);

	bmod_shape_cfg(TST_convex);
	obj = bmod_obj_new("models/test/car_z.mdl", 40.0);
	bmod_obj_assign_ent(obj, ent);
	bmod_obj_update_pos(obj);

	//g_PlayerCar[id] = obj;

	//CreateCamera(id, ent);

	return PLUGIN_HANDLED;
}

public OnCmdStart(id, uc)
{
	if (!is_user_alive(id))
		return;
	
	static Float:fwd_move, Float:side_move;
	get_uc(uc, UC_ForwardMove, fwd_move);
	get_uc(uc, UC_SideMove, side_move);

	if (fwd_move > 0.0)
	{
		new obj = g_PlayerCar[id];


	}
}

public OnCameraThink(cam)
{
	static owner, ent;
	owner = entity_get_edict(cam, EV_ENT_owner);
	ent = entity_get_edict(cam, EV_ENT_enemy);

	if (!is_user_alive(owner) || !is_valid_ent(ent))
		return;
	
	static Float:origin[3], Float:cam_origin[3];
	static Float:angles[3], Float:v_back[3];

	entity_get_vector(ent, EV_VEC_origin, origin);
	entity_get_vector(owner, EV_VEC_v_angle, angles);

	origin[2] += 36.0

	angle_vector(angles, ANGLEVECTOR_FORWARD, v_back);

	cam_origin[0] = origin[0] + (-v_back[0] * 150.0);
	cam_origin[1] = origin[1] + (-v_back[1] * 150.0);
	cam_origin[2] = origin[2] + (-v_back[2] * 150.0);

	engfunc(EngFunc_TraceLine, origin, cam_origin, IGNORE_MONSTERS, owner, 0);
	
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction)

	if (fraction < 1.0)
	{
		fraction *= 150.0;

		cam_origin[0] = origin[0] + (-v_back[0] * fraction);
		cam_origin[1] = origin[1] + (-v_back[1] * fraction);
		cam_origin[2] = origin[2] + (-v_back[2] * fraction);
	}

	entity_set_vector(cam, EV_VEC_origin, cam_origin);
	entity_set_vector(cam, EV_VEC_angles, angles);
	entity_set_origin(owner, origin);
}

public client_putinserver(id)
{
	new obj = bmod_obj_new("BMOD/box/16/16/36");
	bmod_obj_assign_ent(obj, id);
	bmod_obj_set_kinematic(obj, true);
	bmod_obj_set_mass(obj, 1.0);
}

public client_disconnected(id)
{
	bmod_obj_delete(bmod_obj_by_ent(id));
}

stock CreateCamera(id, ent)
{
	new cam = create_entity("trigger_camera");

	DispatchKeyValue(cam, "wait", "999999");

	entity_set_int(cam, EV_INT_spawnflags, SF_CAMERA_PLAYER_TARGET|SF_CAMERA_PLAYER_POSITION);
	entity_set_int(cam, EV_INT_flags, entity_get_int(cam, EV_INT_flags) | FL_ALWAYSTHINK);

	DispatchSpawn(cam);

	entity_set_edict(cam, EV_ENT_owner, id);
	entity_set_edict(cam, EV_ENT_enemy, ent);

	ExecuteHam(Ham_Use, cam, id, id, USE_TOGGLE, 1.0);
}