#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <BR_ItemManager>

#define VERSION "0.1"

#define MAX_SLOTS 6
#define MAX_STORAGE_SIZE 14

#define ALL_KEYS (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0)

new const BACKPACK_CLASSNAME[] = "br_backpack";
new const BACKPACK_MODEL[] = "models/w_backpack.mdl";
new const STORAGE_CLASSNAME[] = "br_storage";
new const STORAGE_MODEL[] = "models/gman.mdl";
new const COMBINER_CLASSNAME[] = "br_combiner";
new const COMBINER_MODEL[] = "models/scientist.mdl";

enum _:SpawnData
{
	Float:SPAWN_POS[3],
	Float:SPAWN_ANGLE[3],
};

enum _:CombineCondData
{
	CCOND_NAME[32],
	CCOND_INFO[32],
};

//new Trie:g_ItemMaxStacks;

new g_Storage[MAX_PLAYERS + 1][MAX_STORAGE_SIZE];
new g_Inventory[MAX_PLAYERS + 1][MAX_SLOTS];
new g_MenuData[MAX_PLAYERS + 1];
new g_MenuEnt[MAX_PLAYERS + 1];
//new g_PlayerItemStack[MAX_PLAYERS + 1][MAX_SLOTS];

new Array:g_BackpackData;
new Array:g_BackpackEnt;

new g_BackpackMenuId;
new g_ChooseItemMenuId;
new g_StorageMenuId;
new g_CombineMenuId;
new g_CombineMenuId2;

new Trie:g_tItemCombination;
new Array:g_aItemCombination;
new Trie:g_CombinationHashmap; // need?
new g_NumCombinations;

new Array:g_StorageSpawns, Array:g_CombinerSpawns;
new g_NumStorageSpawns, g_NumCombinerSpawns;

new g_fwdUseItem, g_fwdUseItemPost;
new g_fwdRemoveItem;
new g_fwdGiveItem, g_fwdGiveItemPost;
new g_fwdCheckItemCombineCond;
new g_fwdCombineItem, g_fwdCombineItemPost;
new g_fwdCreateBackpackEntity;

public plugin_precache()
{
	precache_model(BACKPACK_MODEL);
	precache_model(STORAGE_MODEL);
	precache_model(COMBINER_MODEL);

	g_BackpackEnt = ArrayCreate(1);
	g_BackpackData = ArrayCreate(1);
	g_StorageSpawns = ArrayCreate(SpawnData);
	g_CombinerSpawns = ArrayCreate(SpawnData);

	g_tItemCombination = TrieCreate();
	g_aItemCombination = ArrayCreate(32);
	g_CombinationHashmap = TrieCreate();
}

public plugin_init()
{
	register_plugin("[BR] Item Inventory", VERSION, "holla");

	g_BackpackMenuId = register_menuid("Backpack Menu");
	g_ChooseItemMenuId = register_menuid("Choose Item Menu");
	g_StorageMenuId = register_menuid("Storage Menu");
	g_CombineMenuId = register_menuid("Combiner Menu");
	g_CombineMenuId2 = register_menuid("Sub Combine Menu");

	register_menucmd(register_menuid("Inventory Menu"), ALL_KEYS, "HandleInventoryMenu");
	register_menucmd(register_menuid("Confirm Menu"), ALL_KEYS, "HandleConfirmMenu");
	register_menucmd(g_BackpackMenuId, ALL_KEYS, "HandleBackpackMenu");
	register_menucmd(g_ChooseItemMenuId, ALL_KEYS, "HandleChooseItemMenu");
	register_menucmd(g_StorageMenuId, ALL_KEYS, "HandleStorageMenu");
	register_menucmd(g_CombineMenuId, ALL_KEYS, "HandleCombinerMenu");
	register_menucmd(g_CombineMenuId2, ALL_KEYS, "HandleSubCombineMenu");

	register_clcmd("inventory", "CmdInventory");
	register_clcmd("giveitem", "CmdGiveItem");
	register_clcmd("create_storage", "CmdCreateStorage");
	register_clcmd("remove_storage", "CmdRemoveStorage");
	register_clcmd("create_combiner", "CmdCreateCombiner");
	register_clcmd("remove_combiner", "CmdRemoveCombiner");

	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");
	register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");

	RegisterHam(Ham_Killed, "player", "OnPlayerKilled_Post", 1);
	RegisterHam(Ham_Killed, "func_button", "OnBackpackKilled");
	RegisterHam(Ham_Use, "func_button", "OnButtonUse");

	g_fwdUseItem = CreateMultiForward("BR_OnUseItem", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_fwdUseItemPost = CreateMultiForward("BR_OnUseItemPost", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	
	g_fwdRemoveItem = CreateMultiForward("BR_OnRemoveItem", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	//g_fwdRemoveItemPost = CreateMultiForward("BR_OnUseItemPost", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	
	g_fwdGiveItem = CreateMultiForward("BR_OnGiveItem", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_fwdGiveItemPost = CreateMultiForward("BR_OnGiveItemPost", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

	g_fwdCheckItemCombineCond = CreateMultiForward("BR_OnCheckItemCombineCond", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_STRING);
	g_fwdCombineItem = CreateMultiForward("BR_OnCombineItem", ET_CONTINUE, FP_CELL, FP_CELL);
	g_fwdCombineItemPost = CreateMultiForward("BR_OnCombineItemPost", ET_STOP2, FP_CELL, FP_CELL, FP_CELL);

	g_fwdCreateBackpackEntity = CreateMultiForward("BR_OnCreateBackpackEntity", ET_STOP2, FP_CELL, FP_CELL);

	LoadSpawns();
	CreateMapEnts();

/*
	new sum = 5 / 7 * 7;
	server_print("test sum = %d", sum);
	*/
}

public plugin_natives()
{
	register_library("BR_ItemInventory");

	register_native("BR_Inventory_Get", "NativeGet");
	register_native("BR_Inventory_Give", "NativeGive");
	register_native("BR_Inventory_Use", "NativeUse");
	register_native("BR_Inventory_Remove", "NativeRemove");
	register_native("BR_Inventory_RemoveItem", "NativeRemoveItem");
	register_native("BR_Inventory_HasItem", "NativeHasItem");
	register_native("BR_AddItemCombineCond", "NativeAddItemCombineCond");
	register_native("BR_GetItemCombineCondName", "NativeGetItemCombineCondName");
	register_native("BR_AddItemToBackpack", "NativeAddItemToBackpack");
}

public EventNewRound()
{
	new ent = -1;
	while ((ent = find_ent_by_class(ent, BACKPACK_CLASSNAME)))
	{
		if (is_valid_ent(ent))
		{
			ExecuteHamB(Ham_Killed, ent, ent, 0);
		}
	}

	for (new i = 1; i <= MaxClients; i++)
	{
		arrayset(g_Inventory[i], NULL_ITEM, sizeof g_Inventory[]);
		arrayset(g_Storage[i], NULL_ITEM, sizeof g_Storage[]);
	}
}

public OnPlayerPreThink(id)
{
	if (!is_user_connected(id))
		return;

	new menuid, menuid2, dummy;
	player_menu_info(id, menuid, menuid2, dummy);

	if (menuid == g_BackpackMenuId || menuid == g_StorageMenuId || menuid == g_ChooseItemMenuId || menuid == g_CombineMenuId || menuid == g_CombineMenuId2)
	{
		new ent = g_MenuEnt[id];

		if (!is_user_alive(id) || (is_valid_ent(ent) && entity_range(id, ent) >= 64.0))
		{
			client_print(id, print_chat, "[BR TEST] Auto turn off menu");
			show_menu(id, 0, "^n", 1);
			g_MenuEnt[id] = 0;
		}
	}
}

public OnPlayerKilled_Post(id)
{
	CreateBackpackEntity(id);
}

public OnButtonUse(ent, id, activator, use_type, Float:value)
{
	if (!is_user_alive(id) || use_type != 2 || value != 1.0 || entity_range(id, ent) >= 64.0)
		return;

	new classname[32];
	entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
	
	if (equal(classname, BACKPACK_CLASSNAME))
	{
		// test OnBackpackUse(122, 1, 1, 2, 1.000000)
		//client_print(0, print_chat, "OnBackpackUse(%d, %d, %d, %d, %f)", ent, id, activator, use_type, value);
		
		ShowBackpackMenu(id, ent);
	}
	else if (equal(classname, STORAGE_CLASSNAME))
	{
		g_MenuData[id] = 0;
		ShowStorageMenu(id, ent);
	}
	else if (equal(classname, COMBINER_CLASSNAME))
	{
		g_MenuData[id] = 0;
		ShowCombinerMenu(id, ent);
	}
}

public OnBackpackKilled(ent)
{
	new index = ArrayFindValue(g_BackpackEnt, ent);
	if (index != -1)
	{
		ArrayDeleteItem(g_BackpackEnt, index);
		ArrayDeleteItem(g_BackpackData, index);
	}
}

public CmdInventory(id)
{
	ShowInventoryMenu(id);
	return PLUGIN_HANDLED;
}

public CmdGiveItem(id)
{
	new arg[32];
	read_argv(1, arg, charsmax(arg));

	new player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
	if (!player)
		return PLUGIN_HANDLED;

	read_argv(2, arg, charsmax(arg));

	new itemid = BR_Item_FindByClass(arg);
	if (itemid == NULL_ITEM)
	{
		client_print(id, print_console, "[BR] Item '%s' not found.", arg);
		return PLUGIN_HANDLED;
	}

	GivePlayerItem(player, itemid);

	new name[32];
	BR_Item_GetName(itemid, name, charsmax(name));

	client_print(0, print_chat, "[BR] %n give %s to %n.", id, name, player)
	return PLUGIN_HANDLED;
}

public CmdCreateStorage(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new Float:origin[3], Float:angle[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(id, EV_VEC_angles, angle);
	
	origin[2] += 80.0
	entity_set_origin(id, origin);


	origin[2] -= 80.0;
	CreateStorageEnt(origin, angle);
	SaveSpawns();

	client_print(0, print_chat, "[BR] Create new storage entity (total: %d)", g_NumStorageSpawns);

	return PLUGIN_HANDLED;
}

public CmdRemoveStorage(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new ent = FindEntInSphere(id, 50.0, STORAGE_CLASSNAME);
	if (!is_valid_ent(ent))
	{
		client_print(0, print_chat, "[BR] Entity not found.");
		return PLUGIN_HANDLED;
	}

	remove_entity(ent);
	SaveSpawns();

	client_print(0, print_chat, "[BR] Remove storage entity (total: %d)", g_NumCombinerSpawns);

	return PLUGIN_HANDLED;
}

public CmdCreateCombiner(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new Float:origin[3], Float:angle[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(id, EV_VEC_angles, angle);

	origin[2] += 80.0
	entity_set_origin(id, origin);
	
	origin[2] -= 80.0;
	CreateCombinerEnt(origin, angle);
	SaveSpawns();

	client_print(0, print_chat, "[BR] Create new combiner entity (total: %d)", g_NumStorageSpawns);

	return PLUGIN_HANDLED;
}

public CmdRemoveCombiner(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_HANDLED;
	}

	new ent = FindEntInSphere(id, 50.0, COMBINER_CLASSNAME);
	if (!is_valid_ent(ent))
	{
		client_print(0, print_chat, "[BR] Entity not found.");
		return PLUGIN_HANDLED;
	}

	remove_entity(ent);
	SaveSpawns();

	client_print(0, print_chat, "[BR] Remove combiner entity (total: %d)", g_NumCombinerSpawns);

	return PLUGIN_HANDLED;
}

public ShowCombinerMenu(id, ent)
{
	static menu[512];

	new startid = floatround(g_MenuData[id] / 7.0, floatround_floor) * 7;
	new maxpages = floatround(g_NumCombinations / 7.0, floatround_ceil);
	new len = formatex(menu, 511, "\y合成列表 %d/%d^n^n", startid / 7 + 1, maxpages);

	new keys = MENU_KEY_0;
	new name[32], desc[64], classname[32];
	new keyid, itemid;

	new maxloops = min(startid + 7, g_NumCombinations);

	for (new i = startid; i < maxloops; i++)
	{
		keyid = i - startid;

		ArrayGetString(g_aItemCombination, i, classname, charsmax(classname));
		itemid = BR_Item_FindByClass(classname);

		if (itemid != NULL_ITEM)
		{
			BR_Item_GetName(itemid, name, charsmax(name));
			BR_Item_GetDesc(itemid, desc, charsmax(desc));

			if (IsItemCombinable(id, itemid)) 
				len += formatex(menu[len], 511-len, "\y%d. \w%s \y%s^n", keyid+1, name, desc);
			else
				len += formatex(menu[len], 511-len, "\y%d. \d%s %s^n", keyid+1, name, desc);

			keys |= (1 << keyid);
		}
	}

	if (maxpages > 1)
	{
		if (startid > 0) // has prev
			keys |= MENU_KEY_8;
		else if (startid + 7 < MAX_STORAGE_SIZE) // has next
			keys |= MENU_KEY_9;
		
		len += formatex(menu[len], 511-len, "^n\y8. %s上頁", (startid == 0) ? "\d" : "\w");
		len += formatex(menu[len], 511-len, "^n\y9. %s下頁", (startid + 7 >= MAX_STORAGE_SIZE) ? "\d" : "\w");
	}

	len += formatex(menu[len], 511-len, "^n\y0. \w離開");

	 // \y9. \w下頁^n\y0. \w離開");

	show_menu(id, keys, menu, -1, "Combiner Menu");

	g_MenuEnt[id] = ent;
	g_MenuData[id] = startid;
}

public HandleCombinerMenu(id, key)
{
	new ent = g_MenuEnt[id];
	g_MenuEnt[id] = ent;

	if (!is_user_alive(id) || !is_valid_ent(ent))
	{
		g_MenuData[id] = 0;
		return;
	}
	
	switch (key)
	{
		case 7: // back
		{
			g_MenuData[id] = max(g_MenuData[id] - 7, 0);
			ShowCombinerMenu(id, ent);
			return;
		}
		case 8: // next
		{
			g_MenuData[id] = min(g_MenuData[id] + 7, MAX_STORAGE_SIZE);
			ShowCombinerMenu(id, ent);
			return;
		}
		case 9: // exit
		{
			g_MenuData[id] = 0;
			return;
		}
	}

	new index = g_MenuData[id] + key;

	new classname[32];
	ArrayGetString(g_aItemCombination, index, classname, charsmax(classname));

	new itemid = BR_Item_FindByClass(classname);
	if (itemid == NULL_ITEM)
	{
		g_MenuData[id] = 0;
		return;
	}

	ShowCombinerMenu2(id, ent, index);
}

public ShowCombinerMenu2(id, ent, index)
{
	static menu[512];

	new classname[32];
	ArrayGetString(g_aItemCombination, index, classname, charsmax(classname));

	new itemid = BR_Item_FindByClass(classname);
	
	new name[32];
	BR_Item_GetName(itemid, name, charsmax(name));
	
	new len = formatex(menu, 511, "\y合成 \w%s \y的條件^n^n", name);

	new data[CombineCondData];

	new Array:conditions = Invalid_Array;
	TrieGetCell(g_tItemCombination, classname, conditions);

	new numCond = ArraySize(conditions);
	new combinable = 0;

	for (new i = 0; i < numCond; i++)
	{
		// get condition info
		ArrayGetArray(conditions, i, data);

		if (CheckItemCombineCond(id, itemid, conditions, i))
		{
			len += formatex(menu[len], 511-len, "\w%s:\y O^n", data[CCOND_INFO]);
			combinable++;
		}
		else
		{
			len += formatex(menu[len], 511-len, "\w%s:\r X^n", data[CCOND_INFO]);
		}
	}

	if (combinable >= numCond)
		len += formatex(menu[len], 511-len, "^n\y1. \w合成^n");
	else
		len += formatex(menu[len], 511-len, "^n\d1. 合成^n");

	len += formatex(menu[len], 511-len, "\y0. \w返回合成列表");

	g_MenuEnt[id] = ent;
	g_MenuData[id] = index;

	new keys = MENU_KEY_0|MENU_KEY_1;

	show_menu(id, keys, menu, -1, "Sub Combine Menu");
}

public HandleSubCombineMenu(id, key)
{
	new ent = g_MenuEnt[id];
	g_MenuEnt[id] = 0;

	if (!is_valid_ent(ent) || !is_user_alive(id))
	{
		g_MenuData[id] = 0;
		return;
	}

	new index = g_MenuData[id];

	switch (key)
	{
		case 0: // 1. Combine
		{
			new classname[32];
			ArrayGetString(g_aItemCombination, index, classname, charsmax(classname));
			
			new itemid = BR_Item_FindByClass(classname);
			CombineItem(id, itemid); // should we use classname or itemid?

			g_MenuData[id] = 0;
		}
		case 9: // 0. Back to list
		{
			ShowCombinerMenu(id, ent);
		}
	}
}

public ShowStorageMenu(id, ent)
{
	static menu[512];

	new maxpages = floatround(MAX_STORAGE_SIZE / 7.0, floatround_ceil);
	new startid = floatround(g_MenuData[id] / 7.0, floatround_floor) * 7;
	new len = formatex(menu, 511, "\y倉庫 \d(按一下空位存放物品)\y %d/%d^n^n", startid / 7 + 1, maxpages);

	new keys = MENU_KEY_0;
	new name[32], desc[64];
	new itemid, keyid;

	new maxloops = min(startid + 7, MAX_STORAGE_SIZE);

	for (new i = startid; i < maxloops; i++)
	{
		keyid = i - startid;
		itemid = g_Storage[id][i];

		if (itemid != NULL_ITEM)
		{
			BR_Item_GetName(itemid, name, charsmax(name));
			BR_Item_GetDesc(itemid, desc, charsmax(desc));

			len += formatex(menu[len], 511-len, "\y%d. \w%s \y%s^n", keyid+1, name, desc);
		}
		else
		{
			len += formatex(menu[len], 511-len, "\y%d. \d---^n", keyid+1);
		}

		keys |= (1 << keyid);
	}

	if (maxpages > 1)
	{
		if (startid > 0)
			keys |= MENU_KEY_8;
		else if (startid + 7 < MAX_STORAGE_SIZE)
			keys |= MENU_KEY_9;

		len += formatex(menu[len], 511-len, "^n\y8. %s上頁^n", (startid == 0) ? "\d" : "\w");
		len += formatex(menu[len], 511-len, "\y9. %s下頁^n", (startid + 7 >= MAX_STORAGE_SIZE) ? "\d" : "\w");
	}

	len += formatex(menu[len], 511-len, "^n\y0. \w離開");

	 // \y9. \w下頁^n\y0. \w離開");

	show_menu(id, keys, menu, -1, "Storage Menu");

	g_MenuEnt[id] = ent;
	g_MenuData[id] = startid;
}

public HandleStorageMenu(id, key)
{
	new ent = g_MenuEnt[id];
	g_MenuEnt[id] = 0

	if (!is_user_alive(id) || !is_valid_ent(ent))
	{
		g_MenuData[id] = 0;
		return;
	}
	
	switch (key)
	{
		case 7: // back
		{
			g_MenuData[id] = max(g_MenuData[id] - 7, 0);
			ShowStorageMenu(id, ent);
			return;
		}
		case 8: // next
		{
			g_MenuData[id] = min(g_MenuData[id] + 7, MAX_STORAGE_SIZE);
			ShowStorageMenu(id, ent);
			return;
		}
		case 9: // exit
		{
			g_MenuData[id] = 0;
			return;
		}
	}

	new index = g_MenuData[id] + key;
	new itemid = g_Storage[id][index];

	if (itemid == NULL_ITEM)
	{
		ShowChooseItemMenu(id, ent, index);
	}
	else
	{
		if (GivePlayerItem(id, itemid))
		{
			new name[32];
			BR_Item_GetName(itemid, name, charsmax(name));

			g_Storage[id][index] = NULL_ITEM;

			client_print(id, print_center, "^"%s^" 已存放到你的背包", name);
		}
		else
		{
			client_print(id, print_center, "你的背包沒有空位了");
		}

		ShowStorageMenu(id, ent);
	}
}

public ShowChooseItemMenu(id, ent, slot)
{
	static menu[512];

	new len;
	len = formatex(menu, 511, "\y你的背包^n\w選擇要存放到倉庫的物品^n^n");

	new itemid, name[32], desc[64];
	new keys = MENU_KEY_0;

	for (new i = 0; i < MAX_SLOTS; i++)
	{
		itemid = g_Inventory[id][i];

		if (itemid != NULL_ITEM)
		{
			BR_Item_GetName(itemid, name, charsmax(name));
			BR_Item_GetDesc(itemid, desc, charsmax(desc));

			len += formatex(menu[len], 511-len, "\r%d. \w%s \y%s^n", i+1, name, desc);
			keys |= (1 << i);
		}
		else
		{
			len += formatex(menu[len], 511-len, "\r%d. \d---^n", i+1);
		}
	}

	len += formatex(menu[len], 511-len, "^n\r0. \w返回倉庫");

	show_menu(id, keys, menu, -1, "Choose Item Menu");

	g_MenuEnt[id] = ent;
	g_MenuData[id] = slot;
}

public HandleChooseItemMenu(id, key)
{
	new ent = g_MenuEnt[id];
	g_MenuEnt[id] = 0;

	if (!is_valid_ent(ent) || !is_user_alive(id))
	{
		g_MenuData[id] = 0;
		return;
	}

	new slot = g_MenuData[id];
	if (key < MAX_SLOTS)
	{
		new itemid = g_Inventory[id][key];
		if (itemid == NULL_ITEM)
		{
			ShowChooseItemMenu(id, ent, slot);
			return;
		}

		if (AddItemToStorage(id, itemid, slot))
		{
			g_Inventory[id][key] = NULL_ITEM;

			new name[32];
			BR_Item_GetName(itemid, name, charsmax(name));
			client_print(id, print_center, "^"%s^" 已存放到倉庫", name);
		}
		else
		{
			client_print(id, print_center, "倉庫沒有空位了");
		}

		ShowStorageMenu(id, ent);
	}
	else if (key == 9) // exit
	{
		ShowStorageMenu(id, ent);
	}
}

public ShowBackpackMenu(id, ent)
{
	new index = ArrayFindValue(g_BackpackEnt, ent);
	if (index == -1)
		return;
	
	new Array:data;
	data = ArrayGetCell(g_BackpackData, index);

	new name[32] = "某人";
	new owner = entity_get_edict(ent, EV_ENT_enemy);
	
	if (is_user_connected(owner))
		get_user_name(owner, name, charsmax(name));

	static menu[512];

	new len = formatex(menu, 511, "\w%s \y的背包^n^n", name);
	new itemid, desc[64];
	new keys = MENU_KEY_0;

	new size = ArraySize(data);

	for (new i = 0; i < size; i++)
	{
		itemid = ArrayGetCell(data, i);

		if (itemid != NULL_ITEM)
		{
			BR_Item_GetName(itemid, name, charsmax(name));
			BR_Item_GetDesc(itemid, desc, charsmax(desc));

			len += formatex(menu[len], 511-len, "\y%d. \w%s \y%s^n", i+1, name, desc);
			keys |= (1 << i);
		}
	}

	len += formatex(menu[len], 511-len, "^n\y0. \w離開");

	g_MenuEnt[id] = ent;

	show_menu(id, keys, menu, -1, "Backpack Menu");
}

public HandleBackpackMenu(id, key)
{
	if (key == 9 || !is_user_alive(id))
		return;

	new ent = g_MenuEnt[id];
	g_MenuEnt[id] = 0;

	if (!is_valid_ent(ent))
		return;
	
	new index = ArrayFindValue(g_BackpackEnt, ent);
	if (index == -1)
		return;
	
	new Array:data;
	data = ArrayGetCell(g_BackpackData, index);
	
	if (key >= ArraySize(data))
	{
		ShowBackpackMenu(id, ent);
		return;
	}

	new itemid = ArrayGetCell(data, key);
	if (GivePlayerItem(id, itemid))
	{
		new name[32];
		BR_Item_GetName(itemid, name, charsmax(name));

		client_print(id, print_center, "^"%s^" 已存放到你的背包", name);

		ArrayDeleteItem(data, key);

		if (ArraySize(data) < 1)
		{
			ExecuteHamB(Ham_Killed, ent, id, 0);
		}
		else
		{
			ShowBackpackMenu(id, ent);
		}
	}
	else
	{
		client_print(id, print_center, "你的背包已滿");
	}
}

public ShowInventoryMenu(id)
{
	static menu[512];

	new len;
	len = formatex(menu, 511, "\y背包^n^n");

	new itemid, name[32], desc[64];
	new keys = MENU_KEY_0;

	for (new i = 0; i < MAX_SLOTS; i++)
	{
		itemid = g_Inventory[id][i];

		if (itemid != NULL_ITEM)
		{
			BR_Item_GetName(itemid, name, charsmax(name));
			BR_Item_GetDesc(itemid, desc, charsmax(desc));

			len += formatex(menu[len], 511-len, "\r%d. \w%s \y%s^n", i+1, name, desc);
			keys |= (1 << i);
		}
		else
		{
			len += formatex(menu[len], 511-len, "\r%d. \d---^n", i+1);
			keys |= (1 << i);
		}
	}

	len += formatex(menu[len], 511-len, "^n\r0. \w離開");

	show_menu(id, keys, menu, -1, "Inventory Menu");
}

public HandleInventoryMenu(id, key)
{
	if (!is_user_alive(id))
		return;

	if (key < MAX_SLOTS)
	{
		new itemid = g_Inventory[id][key];
		if (itemid == NULL_ITEM)
		{
			// Refresh menu
			ShowInventoryMenu(id);
			return;
		}

		ShowConfirmMenu(id, key);
	}
}

public ShowConfirmMenu(id, slot)
{
	new itemid = g_Inventory[id][slot];

	new keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2;

	static menu[512];

	new name[32], desc[64];
	BR_Item_GetName(itemid, name, charsmax(name));
	BR_Item_GetDesc(itemid, desc, charsmax(desc));

	new len = formatex(menu, 511, "\y如何處理 \w%s \y?^n", name);
	len += formatex(menu[len], 511-len, "\w%s^n^n", desc);
	len += formatex(menu[len], 511-len, "\y1. \w使用^n\y2. \w丟棄^n^n\y0. \w返回背包");

	g_MenuData[id] = slot;

	show_menu(id, keys, menu, -1, "Confirm Menu");
}

public HandleConfirmMenu(id, key)
{
	new slot = g_MenuData[id];
	g_MenuData[id] = 0;
	//new itemid = g_Inventory[id][slot];
	
	switch (key)
	{
		case 0:
		{
			UseInventoryItem(id, slot);
		}
		case 1:
		{
			RemoveInventorySlot(id, slot);
		}
		case 9:
		{
			ShowInventoryMenu(id);
		}
	}
}


public client_disconnected(id)
{
	g_MenuEnt[id] = 0;
	g_MenuData[id] = 0;
}

public client_putinserver(id)
{
	arrayset(g_Inventory[id], NULL_ITEM, MAX_SLOTS);
	arrayset(g_Storage[id], NULL_ITEM, MAX_STORAGE_SIZE);
}

public NativeGive()
{
	new id = get_param(1);
	new itemid = get_param(2);

	return GivePlayerItem(id, itemid);
}

public NativeUse()
{
	new id = get_param(1);
	new slot = get_param(2);

	return UseInventoryItem(id, slot);
}

public NativeRemove()
{
	new id = get_param(1);
	new slot = get_param(2);

	return RemoveInventorySlot(id, slot);
}

public NativeGet()
{
	new id = get_param(1);
	new slot = get_param(2);

	return g_Inventory[id][slot];
}

public NativeHasItem()
{
	new id = get_param(1);
	new itemid = get_param(2);

	return InventoryHasItem(id, itemid);
}

public NativeRemoveItem()
{
	new id = get_param(1);
	new itemid = get_param(2);

	return RemoveInventoryItem(id, itemid);
}

public NativeAddItemCombineCond()
{
	new classname[32], cond_name[32], cond_info[32];
	get_string(1, classname, charsmax(classname));
	get_string(2, cond_name, charsmax(cond_name));
	get_string(3, cond_info, charsmax(cond_info));

	return AddItemCombineCondition(classname, cond_name, cond_info);
}

public NativeGetItemCombineCondName()
{
	new Array:conditions = Array:get_param(1);
	if (conditions == Invalid_Array)
		return 0;

	new index = get_param(2);
	if (index >= ArraySize(conditions))
		return 0;

	new data[CombineCondData];
	ArrayGetArray(conditions, index, data);

	set_string(3, data[CCOND_NAME], get_param(4));
	return 1;
}

public NativeAddItemToBackpack()
{
	new ent = get_param(1);
	new itemid = get_param(2);

	return AddItemToBackpack(ent, itemid);
}

stock CreateMapEnts()
{
	new data[SpawnData];
	new Float:origin[3], Float:angle[3];

	for (new i = 0; i < g_NumStorageSpawns; i++)
	{
		ArrayGetArray(g_StorageSpawns, i, data);
		xs_vec_copy(data[SPAWN_POS], origin);
		xs_vec_copy(data[SPAWN_ANGLE], angle);

		CreateStorageEnt(origin, angle);
	}

	for (new i = 0; i < g_NumCombinerSpawns; i++)
	{
		ArrayGetArray(g_CombinerSpawns, i, data);
		xs_vec_copy(data[SPAWN_POS], origin);
		xs_vec_copy(data[SPAWN_ANGLE], angle);

		CreateCombinerEnt(origin, angle);
	}
}

stock CreateCombinerEnt(Float:origin[3], Float:angle[3])
{
	new ent = create_entity("func_button");

	entity_set_origin(ent, origin);
	entity_set_vector(ent, EV_VEC_angles, angle);

	entity_set_string(ent, EV_SZ_classname, COMBINER_CLASSNAME);
	entity_set_model(ent, COMBINER_MODEL);

	entity_set_size(ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 72.0});

	entity_set_float(ent, EV_FL_framerate, 1.0);

	entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
	
	drop_to_floor(ent);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
}

stock CreateStorageEnt(Float:origin[3], Float:angle[3])
{
	new ent = create_entity("func_button");

	entity_set_origin(ent, origin);
	entity_set_vector(ent, EV_VEC_angles, angle);

	entity_set_string(ent, EV_SZ_classname, STORAGE_CLASSNAME);
	entity_set_model(ent, STORAGE_MODEL);

	entity_set_size(ent, Float:{-16.0, -16.0, 0.0}, Float:{16.0, 16.0, 72.0});

	entity_set_float(ent, EV_FL_framerate, 1.0);

	entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
	
	drop_to_floor(ent);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
}

stock FindEntInSphere(id, Float:radius, const match[])
{
	new classname[32];
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);

	new ent = -1;
	while ((ent = find_ent_in_sphere(ent, origin, radius)))
	{
		if (is_valid_ent(ent))
		{
			entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));

			if (equal(classname, match))
			{
				return ent;
			}
		}
	}

	return -1;
}

stock CountStorageEnts()
{
	new count = 0;
	new ent = -1;

	while ((ent = find_ent_by_class(ent, STORAGE_CLASSNAME)))
	{
		if (is_valid_ent(ent))
			count++;
	}

	return count;
}

stock LoadSpawns()
{
	new cfgdir[32], mapname[32], filepath[100], linedata[64];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/BattleRoyale/storage/%s.spawns.cfg", cfgdir, mapname);

	if (file_exists(filepath))
	{
		new i;
		new str[6][6], file = fopen(filepath, "rt");
		new data[SpawnData];
		new combiner = 0;
		
		while (file && !feof(file))
		{
			fgets(file, linedata, charsmax(linedata));
			
			// invalid spawn
			if (!linedata[0]) continue;
			trim(linedata);

			if (equal(linedata, "combiner"))
			{
				combiner = 1;
				continue;
			}

			if (str_count(linedata,' ') < 2)
				continue;
			
			// get spawn point data
			parse(linedata,str[0],5,str[1],5,str[2],5,str[3],5,str[4],5,str[5],5);
			
			for (i = 0; i < 3; i++)
			{
				data[SPAWN_POS][i] = str_to_float(str[i]);
				data[SPAWN_ANGLE][i] = str_to_float(str[i+3]);
			}
			
			if (!combiner)
			{
				ArrayPushArray(g_StorageSpawns, data);
				g_NumStorageSpawns++
			}
			else
			{
				ArrayPushArray(g_CombinerSpawns, data);
				g_NumCombinerSpawns++
			}
		}
		if (file) fclose(file)
	}
}

stock SaveSpawns()
{
	g_NumStorageSpawns = 0;
	g_NumCombinerSpawns = 0;
	ArrayClear(g_StorageSpawns);
	ArrayClear(g_CombinerSpawns);

	new cfgdir[32], mapname[32], filepath[100];
	get_configsdir(cfgdir, charsmax(cfgdir));
	get_mapname(mapname, charsmax(mapname));
	formatex(filepath, charsmax(filepath), "%s/BattleRoyale/storage/%s.spawns.cfg", cfgdir, mapname);

	new file = fopen(filepath, "wt");
	if (file)
	{
		new data[SpawnData];
		new Float:origin[3], Float:angle[3];

		new ent = -1;
		while ((ent = find_ent_by_class(ent, STORAGE_CLASSNAME)))
		{
			if (!is_valid_ent(ent))
				continue;

			entity_get_vector(ent, EV_VEC_origin, origin);
			entity_get_vector(ent, EV_VEC_angles, angle);

			fprintf(file, "%f %f %f %f %f %f^n", 
				origin[0], origin[1], origin[2],
				angle[0], angle[1], angle[2]);

			xs_vec_copy(origin, data[SPAWN_POS]);
			xs_vec_copy(angle, data[SPAWN_ANGLE]);

			ArrayPushArray(g_StorageSpawns, data);
			g_NumStorageSpawns++;
		}

		fprintf(file, "combiner^n");

		ent = -1;
		while ((ent = find_ent_by_class(ent, COMBINER_CLASSNAME)))
		{
			if (!is_valid_ent(ent))
				continue;

			entity_get_vector(ent, EV_VEC_origin, origin);
			entity_get_vector(ent, EV_VEC_angles, angle);

			fprintf(file, "%f %f %f %f %f %f^n", 
				origin[0], origin[1], origin[2],
				angle[0], angle[1], angle[2]);

			xs_vec_copy(origin, data[SPAWN_POS]);
			xs_vec_copy(angle, data[SPAWN_ANGLE]);

			ArrayPushArray(g_CombinerSpawns, data);
			g_NumCombinerSpawns++;
		}

		fclose(file);
	}
}

stock CreateBackpackEntity(id)
{
	new Float:origin[3], Float:angle[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(id, EV_VEC_angles, angle);

	angle[0] = 0.0;

	new ent = create_entity("func_button");

	entity_set_origin(ent, origin);
	entity_set_vector(ent, EV_VEC_angles, angle);

	entity_set_string(ent, EV_SZ_classname, BACKPACK_CLASSNAME);
	entity_set_model(ent, BACKPACK_MODEL);

	entity_set_size(ent, Float:{-8.0, -8.0, -2.0}, Float:{8.0, 8.0, 2.0});

	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);
	entity_set_edict(ent, EV_ENT_enemy, id);
	
	drop_to_floor(ent);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);

	if (!SwapBackpackDataToEnt(id, ent))
	{
		remove_entity(ent);
		return;
	}

	new ret;
	ExecuteForward(g_fwdCreateBackpackEntity, ret, id, ent);

	
}

stock AddItemToBackpack(ent, itemid)
{
	new index = ArrayFindValue(g_BackpackEnt, ent);
	if (index != -1)
	{
		new Array:data = Invalid_Array;
		data = ArrayGetCell(g_BackpackData, index);

		if (data != Invalid_Array)
		{
			ArrayPushCell(data, itemid);
			return 1;
		}
	}

	return 0;
}

stock SwapBackpackDataToEnt(id, ent)
{
	new Array:data = ArrayCreate(1);
	new itemid;

	for (new i = 0; i < MAX_SLOTS; i++)
	{
		itemid = g_Inventory[id][i];

		if (itemid != NULL_ITEM)
		{
			ArrayPushCell(data, itemid);
			g_Inventory[id][i] = NULL_ITEM;
		}
	}

	if (ArraySize(data) > 0)
	{
		ArrayPushCell(g_BackpackEnt, ent);
		ArrayPushCell(g_BackpackData, data);
		return true;
	}

	ArrayDestroy(data);
	return false;
}

stock AddItemToStorage(id, itemid, slot)
{
	for (new i = slot; i < MAX_STORAGE_SIZE; i++)
	{
		if (g_Storage[id][i] == NULL_ITEM)
		{
			g_Storage[id][i] = itemid;
			return 1;
		}
	}

	return 0;
}

stock UseInventoryItem(id, slot)
{
	new itemid = g_Inventory[id][slot]
	if (itemid == NULL_ITEM)
		return 0;
	
	new ret;
	ExecuteForward(g_fwdUseItem, ret, id, slot, itemid);

	if (ret == PLUGIN_HANDLED)
		return 0;

	g_Inventory[id][slot] = NULL_ITEM;

	ExecuteForward(g_fwdUseItemPost, ret, id, slot, itemid);
	return 1;
}

stock InventoryHasItem(id, itemid)
{
	for (new i = 0; i < MAX_SLOTS; i++)
	{
		if (g_Inventory[id][i] == itemid)
			return 1;
	}

	return 0;
}

stock RemoveInventoryItem(id, itemid)
{
	for (new i = 0; i < MAX_SLOTS; i++)
	{
		if (g_Inventory[id][i] == itemid)
		{
			RemoveInventorySlot(id, i);
			return 1;
		}
	}

	return 0;
}

stock RemoveInventorySlot(id, slot)
{
	new itemid = g_Inventory[id][slot]
	if (itemid == NULL_ITEM)
		return 0;

	g_Inventory[id][slot] = NULL_ITEM;

	new ret;
	ExecuteForward(g_fwdRemoveItem, ret, id, slot, itemid);

	return 1;
}

stock GivePlayerItem(id, itemid)
{
	new slot = -1;

	for (new i = 0; i < MAX_SLOTS; i++)
	{
		if (g_Inventory[id][i] == NULL_ITEM)
		{
			slot = i;
			break;
		}
	}

	if (slot == -1)
		return 0;
	
	new ret;
	ExecuteForward(g_fwdGiveItem, ret, id, slot, itemid);
	
	if (ret == PLUGIN_HANDLED)
		return 0;
	
	g_Inventory[id][slot] = itemid;

	ExecuteForward(g_fwdGiveItemPost, ret, id, slot, itemid);
	return 1;
}

/*
stock AddItemCombination(const classname[], const conditions[])
{
	new itemid = FindItemByClass(classname);
	if (itemid == NULL_ITEM)
		return;

	new Trie:handle = TrieSetString(g_tItemCombination, classname, conditions, true);

	if (!TrieKeyExists(g_tItemCombination, classname))
	{
		ArrayPushCell(g_aItemCombination, handle);
	}

	return handle;
}*/

/*
stock GetItemMaxStacks(itemid)
{
	new class[32], value;
	BR_Item_GetClass(itemid, class, charsmax(class));

	if (TrieGetCell(g_ItemMaxStacks, class, value))
		return value;
	
	return 1; // default 1
}*/

stock AddItemCombineCondition(const classname[], const cond_name[], const cond_info[])
{
	// item not registered
	if (BR_Item_FindByClass(classname) == NULL_ITEM)
		return 0

	new Array:conditions = Invalid_Array;

	// key not found
	if (!TrieKeyExists(g_tItemCombination, classname))
	{
		conditions = ArrayCreate(CombineCondData); // create condition array
		TrieSetCell(g_tItemCombination, classname, conditions); // set array index as value
		ArrayPushString(g_aItemCombination, classname); // push key
		TrieSetCell(g_CombinationHashmap, classname, g_NumCombinations) // set index
		g_NumCombinations++;
	}
	else
	{
		TrieGetCell(g_tItemCombination, classname, conditions);	// get array index from old value
	}

	// invalid array index
	if (conditions == Invalid_Array)
		return 0;
	
	// push condition name to the array
	new data[CombineCondData];
	copy(data[CCOND_NAME], charsmax(data[CCOND_NAME]), cond_name);
	copy(data[CCOND_INFO], charsmax(data[CCOND_INFO]), cond_info);
	ArrayPushArray(conditions, data);

	return 1;
}

stock CheckItemCombineCond(id, itemid, Array:conditions, cond_id)
{
	new data[CombineCondData];
	ArrayGetArray(conditions, cond_id, data);

	new ret;
	ExecuteForward(g_fwdCheckItemCombineCond, ret, id, itemid, cond_id, data[CCOND_NAME]);

	// false
	if (ret == PLUGIN_HANDLED)
		return 0;
	
	// true
	return 1;
}

stock IsItemCombinable(id, itemid)
{
	new classname[32];
	BR_Item_GetClass(itemid, classname, charsmax(classname));

	new Array:conditions = Invalid_Array;
	if (!TrieGetCell(g_tItemCombination, classname, conditions))
		return 0;
	
	if (conditions == Invalid_Array)
		return 0;
	
	new numCond = ArraySize(conditions);

	for (new i = 0; i < numCond; i++)
	{
		if (!CheckItemCombineCond(id, itemid, conditions, i))
			return 0; // not combinable
	}

	// combinable
	return 1;
}

stock CombineItem(id, itemid)
{
	new ret;
	ExecuteForward(g_fwdCombineItem, ret, id, itemid);

	if (ret == PLUGIN_HANDLED)
		return 0;

	if (!IsItemCombinable(id, itemid))
		return 0;

	new classname[32];
	BR_Item_GetClass(itemid, classname, charsmax(classname));

	new Array:conditions = Invalid_Array;
	if (!TrieGetCell(g_tItemCombination, classname, conditions))
		return 0;
	
	ExecuteForward(g_fwdCombineItemPost, ret, id, itemid, conditions);
	return 1;
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

/*
[sub menu like this]

合成 石斧 的需求:

木棍: ✔
繩子: ✔
削尖的石頭: ✖

1. 合成
0. 返回合成列表

*/