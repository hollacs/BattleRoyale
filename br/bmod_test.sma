#include <amxmodx>
#include <amxmisc>
#include <bmod>
#include <engine>
#include <xs>

#define MAX_BRUSH_ENTS 512

//first two staticClasses are also toggleClasses
new toggleClasses = 2;
new staticClasses[][] = {"func_breakable", "func_wall_toggle", "func_conveyor", "button_target",
"func_healthcharger", "func_recharge", "func_wall", ""};
//on index 0 is water class
new waterClass = 0;
new kinematicClasses[][] = {"func_water", "func_button", "func_door", "func_door_rotating", "func_guntarget",
"func_pendulum", "func_plat", "func_platrot", "func_pushable", "func_rot_button", "func_rotating",
"func_tank", "func_tanklaser", "func_tankmortar", "func_tracktrain", "func_train", "func_vehicle",
"momentary_door", "momentary_rot_button", ""};
new toggleObjs[MAX_BRUSH_ENTS][3]; //{obj, ent, solid}
new toggleCount = 0;
//new waterObjs[MAX_BRUSH_ENTS][2]; //{obj, ent}
//new waterCount = 0;
//new playerObj[MAX_PLAYERS + 1];

public plugin_init() {
	register_concmd("bmod_test","_bmod_test");
	//create static bmod object from worldspawn
	bmod_shape_cfg(TST_concave_static);
	bmod_obj_from_ent(0);
	//static entities
	for(new i = 0; staticClasses[i][0]; i++){
		new entid = -1;
		while((entid = find_ent_by_class(entid, staticClasses[i]))){
			new obj = bmod_obj_from_ent(entid)
			
			//is this toggleClass?
			if(i < toggleClasses){
				toggleObjs[toggleCount][0] = obj;
				toggleObjs[toggleCount][1] = entid;
				toggleObjs[toggleCount][2] = SOLID_BSP;
				toggleCount++;
			}
		}
	}
	/*
	//kinematic entities
	for(new i = 0; kinematicClasses[i][0]; i++){
		new entid = -1;
		while((entid = find_ent_by_class(entid, kinematicClasses[i]))){
			//if this is waterClass, we should use convex shape!
			if(i == waterClass)
				bmod_shape_cfg(TST_convex)
				
			new obj = bmod_obj_from_ent(entid)
			bmod_obj_set_kinematic(obj, true)
			
			//is this waterClass?
			if(i == waterClass){
				new CollisionFlags:flags;
				bmod_obj_call(obj, "getCollisionFlags", flags)
				flags |= CF_NO_CONTACT_RESPONSE
				bmod_obj_call(obj, "setCollisionFlags", flags)
				waterObjs[waterCount][0] = obj;
				waterObjs[waterCount][1] = entid;
				waterCount++;
				bmod_shape_cfg(TST_concave_static)
			}
		}
	}*/

	bmod_stepcfg(24, 1.0/1000);
}

public server_frame(){
	static i, solid, CollisionFlags:flags;
	for(i = 0; i < toggleCount; i++){
		solid = entity_get_int(toggleObjs[i][1], EV_INT_solid);
		if(solid != toggleObjs[i][2]){
			bmod_obj_call(toggleObjs[i][0], "getCollisionFlags", flags);
			if(solid == SOLID_BSP){
				//activate
				flags &= ~CF_NO_CONTACT_RESPONSE;
			}else{
				//deactivate
				flags |= CF_NO_CONTACT_RESPONSE;
			}
			bmod_obj_call(toggleObjs[i][0], "setCollisionFlags", flags);
			toggleObjs[i][2] = solid;
		}
	}
}

public _bmod_test(id){
	//create a new entity
	new entity = create_entity("func_wall");
	entity_set_model(entity,"models/test/car_sm.mdl");
	//set entity origin 128 units above player
	new Float:origin[3];
	entity_get_vector(id,EV_VEC_origin,origin);
	origin[2]+=128;
	entity_set_origin(entity,origin);
	//set some movetype and nextthink, so entity movement is smoother (because of velocity and avelocity)
	entity_set_float(entity,EV_FL_nextthink,86400.0);
	entity_set_int(entity,EV_INT_movetype,8);

	//create new bmod object
	bmod_shape_cfg(TST_convex, Float:{0.0, 0.0, 0.0});
	new object = bmod_obj_new("models/test/car_sm.mdl", 50.0);
	//hook entity with bmod object
	bmod_obj_assign_ent(object, entity);
	bmod_obj_update_pos(object);
}

public client_putinserver(plr){
	new obj = bmod_obj_new("BMOD/box/16/16/36");
	bmod_obj_assign_ent(obj, plr);
	bmod_obj_set_kinematic(obj, true);
	bmod_obj_set_mass(obj, 1.0);
}

public client_disconnected(plr){
	bmod_obj_delete(bmod_obj_by_ent(plr));
}

public plugin_precache(){
	precache_model("models/test/car_sm.mdl");
}

public bmod_forward_contact(obj1, obj2, Float:distance){
	if(distance >= 0)
		return;

	static ents[2];
	bmod_obj_get_ents(obj1, ents, sizeof ents);

	if ((1 <= ents[0] <= MaxClients)) {
		static Float:vel[3];
		entity_get_vector(ents[0], EV_VEC_velocity, vel);

		if (xs_vec_len(vel) > 0.0) {
			static Float:pos1[3], Float:pos2[3], Float:rotate[3];
			bmod_obj_call(obj1, "getWorldTransform", pos1, rotate);
			bmod_obj_call(obj2, "getWorldTransform", pos2, rotate);
			
			static Float:vec[3];
			xs_vec_sub(pos2, pos1, vec);
			xs_vec_normalize(vec, vec);
			xs_vec_mul_scalar(vec, distance, vec);

			entity_get_vector(ents[0], EV_VEC_velocity, vel);
			xs_vec_add(vel, vec, vel);

			entity_set_vector(ents[0], EV_VEC_velocity, vel);
		}
	}

	/*
	static i, obj3;
	static Float:vec1[3], Float:vec2[3];
	for(i = 0; i < waterCount; i++){
		//swap, water should be obj1
		if(waterObjs[i][0] == obj2){
			obj3 = obj1;
			obj1 = obj2;
			obj2 = obj3;
		}
		if(waterObjs[i][0] == obj1){
			bmod_obj_call(obj2, "getWorldTransform", vec1, vec2)
			entity_get_vector(waterObjs[i][1], EV_VEC_absmax, vec2)
			vec2[0] = 0.0;
			vec2[1] = 0.0;
			vec2[2] -= vec1[2];
			if(vec2[2] > 0){
				vec2[2] *= vec2[2];
				vec2[2] *= 0.01;
				bmod_obj_call(obj2, "applyImpulse", vec2, vec1);
			}
			bmod_obj_call(obj2, "getLinearVelocity", vec2);
			vec2[0] *= 0.99;
			vec2[1] *= 0.99;
			vec2[2] *= 0.99;
			bmod_obj_call(obj2, "setLinearVelocity", vec2);
			bmod_obj_call(obj2, "getAngularVelocity", vec2);
			vec2[0] *= 0.99;
			vec2[1] *= 0.99;
			vec2[2] *= 0.99;
			bmod_obj_call(obj2, "setAngularVelocity", vec2);
		}
	}*/
}
