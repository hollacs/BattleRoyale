#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <engine_stocks>
#include <fakemeta>
#include <xs>

#define VERSION "0.1"

#define NULL_ITEM -1

enum _:ItemData
{
	ITEM_NAME[32],
	ITEM_DESC[64],
	ITEM_CLASS[32],
	ITEM_FLAGS,
	ITEM_WEIGHT,
};

enum _:SpawnData
{
	Float:SPAWN_POS[3],
	Float:SPAWN_ANGLE[3],
};

new const ITEM_MODEL[] = "models/w_isotopebox.mdl";
new const TEMP_ENT_CLASSNAME[] = "br_temp_item";
new const ENT_CLASSNAME[] = "br_item_ent";

new CvarMaxMapItems;
new Float:CvarItemRespawnTime;

new Array:g_ItemData;
new g_ItemCount;

new Trie:g_ItemHashMap;

new Array:g_ItemSpawns;
new g_SpawnCount;

new bool:g_EditMode;

new g_fwdSetModel;
new g_fwdTouchItem;

public plugin_precache()
{
	precache_model(ITEM_MODEL);

	g_ItemData = ArrayCreate(ItemData);
	g_ItemSpawns = ArrayCreate(SpawnData);
	g_ItemHashMap = TrieCreate();
}

public plugin_init()
{
	register_plugin("[BR] Item Manager", VERSION, "holla");

	register_clcmd("br_editmode", "CmdEditMode");
	register_clcmd("br_additempos", "CmdAddItemPos");
	register_clcmd("br_delitempos", "CmdDeleteItemPos");
	register_clcmd("br_saveitems", "CmdSaveItems");

	register_event("HLTV", "EventRestartRound", "a", "1=0", "2=0");
	register_logevent("EventRoundEnd", 2, "1=Round_End");

	register_touch(ENT_CLASSNAME, "player", "OnTouchItem");

	register_clcmd("itemlist", "CmdItemList");

	new pcvar = create_cvar("br_max_map_items", "30");
	bind_pcvar_num(pcvar, CvarMaxMapItems);

	pcvar = create_cvar("br_item_respawn_time", "60"); // test 60
	bind_pcvar_float(pcvar, CvarItemRespawnTime);

	LoadSpawns();

	g_fwdSetModel = CreateMultiForward("BR_OnItemEntSetModel", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwdTouchItem = CreateMultiForward("BR_OnTouchItem", ET_STOP2, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_natives()
{
	register_library("BR_ItemManager");

	register_native("BR_Item_Register", "NativeRegister");
	register_native("BR_Item_GetName", "NativeGetName");
	register_native("BR_Item_GetDesc", "NativeGetDesc");
	register_native("BR_Item_GetClass", "NativeGetClass");
	register_native("BR_Item_GetFlags", "NativeGetFlags");
	register_native("BR_Item_GetWeight", "NativeGetWeight");
	register_native("BR_Item_FindByClass", "NativeFindByClass");
}

public CmdItemList(id)
{
	client_print(id, print_console, "--------------- Item List ---------------");
	client_print(id, print_console, "[name]      [desc]      [class]");

	new name[32], desc[64], class[32];

	for (new i = 0; i < g_ItemCount; i++)
	{
		GetItemName(i, name, charsmax(name));
		GetItemDesc(i, desc, charsmax(desc));
		GetItemClass(i, class, charsmax(class));

		client_print(id, print_console, "^"%s^"   ^"%s^"   ^"%s^"", name, desc, class);
	}

	client_print(id, print_console, "-----------------------------------------");

	return PLUGIN_HANDLED;
}

public EventRestartRound()
{
	remove_entity_name(ENT_CLASSNAME);

	SpawnItemEntities();
}

public EventRoundEnd()
{
	remove_task();
}

public OnTouchItem(ent, player)
{
	if (is_user_alive(player) && is_valid_ent(ent))
	{
		new itemid = entity_get_int(ent, EV_INT_iStepLeft);

		new ret;
		ExecuteForward(g_fwdTouchItem, ret, player, ent, itemid);
	}
}

public CmdEditMode(id)
{
	new arg[8];
	read_argv(1, arg, charsmax(arg));

	if (!is_str_num(arg))
		return PLUGIN_HANDLED;

	ToggleEditMode(str_to_num(arg) ? true : false);

	client_print(0, print_chat, "[BR] Edit Mode: %s (total spawns: %d)", g_EditMode ? "On" : "Off", g_SpawnCount);
	return PLUGIN_HANDLED;
}

// later make only admin use
public CmdAddItemPos(id)
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

	data[SPAWN_ANGLE][0] = 0.0; // [0] or [1] ? forgot

	CreateTempItemEnt(data);

	new total = CountTempItemEnts();

	client_print(0, print_chat, "[BR] Added item spawn point (total: %d)", total);
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

	new ent = FindTempEntInSphere(id, 50.0);
	if (!is_valid_ent(ent))
	{
		client_print(0, print_chat, "[BR] Entity not found.");
		return PLUGIN_HANDLED;
	}

	remove_entity(ent);

	new total = CountTempItemEnts();
	client_print(0, print_chat, "[BR] Removed item spawn point (total: %d)", total);

	return PLUGIN_HANDLED;
}

public CmdSaveItems(id)
{
	if (!g_EditMode)
	{
		client_print(0, print_chat, "[BR] Edit mode is not enabled.");
		return PLUGIN_HANDLED;
	}

	new total = SaveTempSpawns();

	client_print(0, print_chat, "[BR] Saved all item spawn points (total: %d)", total);
	return PLUGIN_HANDLED;
}

public TaskRespawnMapItems()
{
	SpawnItemEntities();
}

public NativeRegister()
{
	new name[32], desc[64], class[32], flags, weight;
	get_string(1, name, charsmax(name));
	get_string(2, desc, charsmax(desc));
	get_string(3, class, charsmax(class));
	flags = get_param(4);
	weight = get_param(5);

	return RegisterItem(name, desc, class, flags, weight);
}

public NativeGetName()
{
	new index = get_param(1);

	new name[32];
	GetItemName(index, name, charsmax(name));

	set_string(2, name, get_param(3));
}

public NativeGetDesc()
{
	new index = get_param(1);

	new desc[64];
	GetItemDesc(index, desc, charsmax(desc));

	set_string(2, desc, get_param(3));
}

public NativeGetClass()
{
	new index = get_param(1);

	new class[32];
	GetItemClass(index, class, charsmax(class));

	set_string(2, class, get_param(3));
}

public NativeGetFlags()
{
	new index = get_param(1);

	return GetItemFlags(index);
}

public NativeGetWeight()
{
	new index = get_param(1);

	return GetItemWeight(index);
}

public NativeFindByClass()
{
	new class[32];
	get_string(1, class, charsmax(class));

	return FindItemByClass(class);
}

stock ToggleEditMode(bool:enable)
{
	if (enable)
		EnableEditMode();
	else
		DisableEditMode();
}

stock SpawnItemEntities()
{
	new data[SpawnData];

	new Array:array;
	array = ArrayCreate(1);

	for (new i = 0; i < g_SpawnCount; i++)
	{
		ArrayPushCell(array, i);
	}

	new num = CountItemEnts();
	new rand, index, size;
	new Float:origin[3];

	while (num < CvarMaxMapItems)
	{
		size = ArraySize(array);
		if (size < 1)
			break;

		rand = random(size);
		index = ArrayGetCell(array, rand);

		ArrayGetArray(g_ItemSpawns, index, data);
		ArrayDeleteItem(array, rand); // remove anyway
		xs_vec_copy(data[SPAWN_POS], origin);

		if (CheckSpawnPosition(origin, 64.0))
		{
			SpawnRandomItem(data);
			size--;
			num++;
		}
		//CreateItemEnt(data);
	}

	ArrayDestroy(array);

	client_print(0, print_chat, "[BR] respawn map items");

	remove_task();
	set_task(CvarItemRespawnTime, "TaskRespawnMapItems");
}

stock bool:CheckSpawnPosition(Float:origin[3], Float:radius)
{
	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, radius)))
	{
		if (!is_valid_ent(ent))
			continue;
		
		if (entity_get_int(ent, EV_INT_solid) > SOLID_NOT)
			return false;
	}

	return true;
}

stock SpawnRandomItem(data[SpawnData])
{
	new sum_of_weight = 0;

	for (new i = 0; i < g_ItemCount; i++)
	{
		sum_of_weight += GetItemWeight(i);
	}

	new rnd = random(sum_of_weight); // 0 to (sum_of_weight-1)
	new weight;

	for (new i = 0; i < g_ItemCount; i++)
	{
		weight = GetItemWeight(i);

		if (weight < 1) // no weight
			continue;
		
		if (rnd < weight)
		{
			CreateItemEnt(data, i);
			break;
		}
		
		rnd -= weight;
	}
}

stock SaveTempSpawns()
{
	if (g_EditMode)
	{
		ArrayClear(g_ItemSpawns);
		g_SpawnCount = 0;

		new data[SpawnData];
		new ent = -1;

		while ((ent = find_ent_by_class(ent, TEMP_ENT_CLASSNAME)))
		{
			if (is_valid_ent(ent))
			{
				pev(ent, pev_origin, data[SPAWN_POS]);
				pev(ent, pev_angles, data[SPAWN_ANGLE]);

				ArrayPushArray(g_ItemSpawns, data);
				g_SpawnCount++;
			}
		}

		SaveSpawns();
		return g_SpawnCount;
	}

	return 0;
}

stock EnableEditMode()
{
	if (g_EditMode)
		return;

	new spawndata[SpawnData];

	for (new i = 0; i < g_SpawnCount; i++)
	{
		ArrayGetArray(g_ItemSpawns, i, spawndata);

		CreateTempItemEnt(spawndata);
	}

	g_EditMode = true;
}

stock DisableEditMode()
{
	if (!g_EditMode)
		return;

	SaveTempSpawns();
	remove_entity_name(TEMP_ENT_CLASSNAME);

	g_EditMode = false;
}

stock LoadSpawns()
{
	new cfgdir[32], mapname[32], filepath[100], linedata[64];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/BattleRoyale/item/%s.spawns.cfg", cfgdir, mapname);

	if (file_exists(filepath))
	{
		new i;
		new str[6][6], file = fopen(filepath, "rt");
		new data[SpawnData];
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata));
			
			// invalid spawn
			if(!linedata[0] || str_count(linedata,' ') < 2) continue;
			
			// get spawn point data
			parse(linedata,str[0],5,str[1],5,str[2],5,str[3],5,str[4],5,str[5],5);
			
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

stock SaveSpawns()
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

stock CreateItemEnt(data[SpawnData], itemid)
{
	new ent = create_entity("info_target");

	engfunc(EngFunc_SetOrigin, ent, data[SPAWN_POS]);
	set_pev(ent, pev_angles, data[SPAWN_ANGLE]);

	entity_set_string(ent, EV_SZ_classname, ENT_CLASSNAME);

	entity_set_model(ent, ITEM_MODEL);

	new ret;
	ExecuteForward(g_fwdSetModel, ret, ent, itemid);

	entity_set_size(ent, Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0});

	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);
	entity_set_int(ent, EV_INT_iStepLeft, itemid); // use a unused pev to store our value

	drop_to_floor(ent);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);

	return ent;
}

stock CreateTempItemEnt(data[SpawnData])
{
	new ent = create_entity("info_target");

	engfunc(EngFunc_SetOrigin, ent, data[SPAWN_POS]);
	set_pev(ent, pev_angles, data[SPAWN_ANGLE]);

	entity_set_string(ent, EV_SZ_classname, TEMP_ENT_CLASSNAME);
	entity_set_model(ent, ITEM_MODEL);
	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);

	entity_set_size(ent, Float:{0.0, 0.0, 0.0}, Float:{0.0, 0.0, 0.0});

	entity_set_int(ent, EV_INT_rendermode, kRenderTransAlpha);
	entity_set_float(ent, EV_FL_renderamt, 130.0);

	return ent;
}

stock CountItemEnts()
{
	new num = 0;
	new ent = -1;

	while ((ent = find_ent_by_class(ent, ENT_CLASSNAME)))
	{
		if (is_valid_ent(ent))
			num++;
	}

	return num;
}

stock CountTempItemEnts()
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

stock FindTempEntInSphere(id, Float:radius)
{
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);

	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, radius)))
	{
		if (is_valid_ent(ent) && IsTempItemEnt(ent))
			return ent;
	}

	return -1;
}

stock bool:IsTempItemEnt(ent)
{
	new classname[32];
	pev(ent, pev_classname, classname, charsmax(classname));

	return bool:equal(classname, TEMP_ENT_CLASSNAME);
}

stock RegisterItem(const name[], const desc[], const class[], flags, weight)
{
	new itemdata[ItemData];
	
	copy(itemdata[ITEM_NAME], charsmax(itemdata[ITEM_NAME]), name);
	copy(itemdata[ITEM_DESC], charsmax(itemdata[ITEM_DESC]), desc);
	copy(itemdata[ITEM_CLASS], charsmax(itemdata[ITEM_CLASS]), class);

	itemdata[ITEM_FLAGS] = flags;
	itemdata[ITEM_WEIGHT] = weight;

	ArrayPushArray(g_ItemData, itemdata);

	TrieSetCell(g_ItemHashMap, class, g_ItemCount);

	g_ItemCount++;
	return (g_ItemCount - 1);
}

stock GetItemName(index, name[], len)
{
	new itemdata[ItemData];
	ArrayGetArray(g_ItemData, index, itemdata);
	copy(name, len, itemdata[ITEM_NAME]);
}

stock GetItemDesc(index, desc[], len)
{
	new itemdata[ItemData];
	ArrayGetArray(g_ItemData, index, itemdata);
	copy(desc, len, itemdata[ITEM_DESC]);
}

stock GetItemClass(index, class[], len)
{
	new itemdata[ItemData];
	ArrayGetArray(g_ItemData, index, itemdata);
	copy(class, len, itemdata[ITEM_CLASS]);
}

stock GetItemFlags(index)
{
	new itemdata[ItemData];
	ArrayGetArray(g_ItemData, index, itemdata);
	
	return itemdata[ITEM_FLAGS];
}

stock GetItemWeight(index)
{
	new itemdata[ItemData];
	ArrayGetArray(g_ItemData, index, itemdata);
	
	return itemdata[ITEM_WEIGHT];
}

stock FindItemByClass(const classname[])
{
	/*
	new class[32];

	for (new i = 0; i < g_ItemCount; i++)
	{
		GetItemClass(i, class, charsmax(class));

		if (equal(class, classname))
			return i;
	}

	return NULL_ITEM;*/

	new itemid;
	if (TrieGetCell(g_ItemHashMap, classname, itemid))
		return itemid;
	
	return NULL_ITEM; // not found
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