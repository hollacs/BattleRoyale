#include <amxmodx>
#include <engine>
#include <engine_stocks>
#include <fakemeta>
#include <xs>

#define VERSION "0.1"

new const SPAWN_CLASSNAME[] = "spawn_item";
new const SPAWN_MODEL[] = "models/w_isotopebox.mdl";

public plugin_precache()
{
	precache_model(SPAWN_MODEL);
}

public plugin_init()
{
	register_plugin("[BR] Item Spawns", VERSION, "holla");

	register_clcmd("br_item_edit", "CmdItemEdit");
	register_clcmd("br_item_addspawn", "CmdItemAddSpawn");
	register_clcmd("br_item_delspawn", "CmdItemDeleteSpawn");
	register_clcmd("br_item_save", "CmdItemSave");
}

public CmdItemEdit(id)
{
	new arg[8];
	read_argv(1, arg, charsmax(arg));

	if (!is_str_num(arg))
		return PLUGIN_HANDLED;
	
	if (str_to_num(arg))
		EnableEditMode();
	else
		DisableEditMode();
	
	client_print(0, print_chat, "[BR] Item Edit Mode: %s", g_EditMode ? "On" : "Off");
	return PLUGIN_HANDLED;
}

public CmdItemAddSpawn(id)
{
	if (!g_EditMode)
	{
		client_print(0, print_chat, "[BR] Edit mode is not enabled.");
		return PLUGIN_HANDLED;
	}

	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new data[SpawnData];
	pev(id, pev_origin, data[SPAWN_POS]);
	pev(id, pev_angles, data[SPAWN_ANGLE]);

	data[SPAWN_ANGLE][0] = 0.0;

	CreateItemSpawnEnt(data);

	new total = CountItemSpawnEnts();

	client_print(0, print_chat, "[BR] Add item spawn point (total: %d)", total);
	return PLUGIN_HANDLED;
}

public CmdDeleteItemPos(id)
{
	if (!g_EditMode)
	{
		client_print(0, print_chat, "[BR] Edit mode is not enabled.");
		return PLUGIN_HANDLED;
	}

	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);

	new ent = FindEntInSphere(origin, SPAWN_CLASSNAME, 50.0);

	if (!is_valid_ent(ent))
	{
		client_print(0, print_chat, "[BR] Entity not found.");
		return PLUGIN_HANDLED;
	}

	remove_entity(ent);

	new total = CountItemSpawnEnts();

	client_print(0, print_chat, "[BR] Remove item spawn point (total: %d)", total);
	return PLUGIN_HANDLED;
}

public CmdItemSave(id)
{
	if (!g_EditMode)
	{
		client_print(0, print_chat, "[BR] Edit mode is not enabled.");
		return PLUGIN_HANDLED;
	}

	new total = SaveItemSpawns();

	client_print(0, print_chat, "[BR] Save all item spawn points (total: %d)", total);
	return PLUGIN_HANDLED;
}

stock EnableEditMode()
{
	if (g_EditMode)
		return;
	
	new data[SpawnData];

	for (new i = 0; i < g_SpawnCount; i++)
	{
		ArrayGetArray(g_ItemSpawns, i, spawndata);

		CreateItemSpawnEnt(spawndata);
	}

	g_EditMode = true;
}

stock DisableEditMode()
{
	if (!g_EditMode)
		return;

	SaveItemSpawns();
	remove_entity_name(SPAWN_CLASSNAME);

	g_EditMode = false;
}

stock CreateTempItemEnt(data[SpawnData])
{
	new ent = create_entity("info_target");

	if (!is_valid_ent(ent))
		return 0;

	engfunc(EngFunc_SetOrigin, ent, data[SPAWN_POS]);
	set_pev(ent, pev_angles, data[SPAWN_ANGLE]);

	entity_set_string(ent, EV_SZ_classname, SPAWN_CLASSNAME);
	entity_set_model(ent, SPAWN_MODEL);
	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);

	entity_set_size(ent, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});

	entity_set_int(ent, EV_INT_rendermode, kRenderTransAlpha);
	entity_set_float(ent, EV_FL_renderamt, 130.0);

	return ent;
}

stock FindEntInSphere(Float:origin[3], const classname[], Float:radius)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);

	new class[32];

	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, radius)))
	{
		if (!is_valid_ent(ent))
			continue;
		
		entity_get_string(ent, EV_SZ_classname, class, charsmax(class));

		if (equal(class, classname))
			return ent;
	}

	return -1;
}

stock CountItemSpawnEnts()
{
	new num = 0;
	new ent = -1;

	while ((ent = find_ent_by_class(ent, TEMP_ENT_CLASSNAME)))
	{
		if (is_valid_ent(ent))
			num++;
	}

	return num;
}

stock SaveItemSpawns()
{
	if (!g_EditMode)
		return;

	ArrayClear(g_ItemSpawns);
	g_SpawnCount = 0;

	new data[SpawnData];
	new ent = -1;

	while ((ent = find_ent_by_class(ent, SPAWN_CLASSNAME)))
	{
		if (is_valid_ent(ent))
		{
			pev(ent, pev_origin, data[SPAWN_POS]);
			pev(ent, pev_angles, data[SPAWN_ANGLE]);

			ArrayPushArray(g_ItemSpawns, data);
			g_SpawnCount++;
		}
	}

	return g_SpawnCount;
}

stock SaveSpawnsFile()
{
	new cfgdir[32], mapname[32], filepath[100];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/BattleRoyale/item/%s.spawns.cfg", cfgdir, mapname);

	new file = fopen(filepath, "wt");
	if (file)
	{
		new spawndata[SpawnData];

		for (new i = 0; i < g_SpawnCount; i++)
		{
			ArrayGetArray(g_ItemSpawns, i, spawndata);

			fprintf(file, "%f %f %f %f %f %f^n", 
				spawndata[SPAWN_POS][0], spawndata[SPAWN_POS][1], spawndata[SPAWN_POS][2],
				spawndata[SPAWN_ANGLE][0], spawndata[SPAWN_ANGLE][1], spawndata[SPAWN_ANGLE][2]);
		}

		fclose(file);
	}
}

stock LoadSpawnsFile()
{
	new cfgdir[32], mapname[32], filepath[100];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/BattleRoyale/item/%s.spawns.cfg", cfgdir, mapname);

	if (file_exists(filepath))
	{
		new i;
		new str[6][6];
		new data[SpawnData], linedata[64];

		new file = fopen(filepath, "rt");
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata));
			
			// invalid spawn
			if (!linedata[0] || equal(linedata, "//", 2))
				continue;
			
			// get spawn point data
			parse(linedata, str[0], 5, str[1], 5, str[2], 5, str[3], 5, str[4], 5, str[5], 5);
			
			for (i = 0; i < 3; i++)
			{
				data[SPAWN_POS][i] = str_to_float(str[i]);
				data[SPAWN_ANGLE][i] = str_to_float(str[i+3]);
			}
			
			ArrayPushArray(g_ItemSpawns, data);
			g_SpawnCount++
		}
		if (file) fclose(file)
	}
}