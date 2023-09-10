#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <xs>
#include <BattleRoyale>
#include <BR_ItemInventory>

#define VERSION "0.1"

new const COMPUTER_MODEL[] = "models/test/computer.mdl";

enum _:ItemData
{
	ITEM_MOBO,
	ITEM_CPU,
	ITEM_POWERSUPPLY,
	ITEM_COMPUTER
};

new g_itemid[ItemData];
new bool:g_IsPlacing[MAX_PLAYERS + 1];
new g_PlayerEnt[MAX_PLAYERS + 1];
new Float:g_LastPressTime[MAX_PLAYERS + 1];
new Float:g_LastUseTime[MAX_PLAYERS + 1];

public plugin_precache()
{
	precache_model(COMPUTER_MODEL);
}

public plugin_init()
{
	register_plugin("[BR] Item: Computer", VERSION, "holla");

	register_forward(FM_CmdStart, "OnCmdStart");
	register_forward(FM_PlayerPreThink, "OnPlayerPreThink");

	g_itemid[ITEM_MOBO] = BR_Item_Register("主機板", "電腦零件", "item_mobo", 0, 35);
	g_itemid[ITEM_CPU] = BR_Item_Register("CPU處理器", "電腦核心", "item_cpu", 0, 30);
	g_itemid[ITEM_POWERSUPPLY] = BR_Item_Register("電源供應器", "火牛", "item_powersupply", 0, 35);
	g_itemid[ITEM_COMPUTER] = BR_Item_Register("電腦", "Hacking", "item_computer", 0, 0);

	RequestFrame("AfterPluginInit");
}

public AfterPluginInit()
{
	BR_AddItemCombineCond("item_computer", "item_mobo", "主機板");
	BR_AddItemCombineCond("item_computer", "item_cpu", "CPU處理器");
	BR_AddItemCombineCond("item_computer", "item_powersupply", "電源供應器");
	BR_AddItemCombineCond("item_computer", "limit_int", "智力 8 或以上");
}

public BR_OnCheckItemCombineCond(id, itemid, cond_id, const cond_name[])
{
	if (itemid == g_itemid[ITEM_COMPUTER])
	{
		if (equal(cond_name, "item_", 5))
		{
			if (!BR_Inventory_HasItemClass(id, cond_name))
				return PLUGIN_HANDLED;
		}
		else if (equal(cond_name, "limit_int"))
		{
			if (BR_GetPlayerAttrib(id, ATTRIB_INT) < 8)
				return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public BR_OnCombineItemPost(id, itemid, Array:conditions)
{
	if (itemid == g_itemid[ITEM_COMPUTER])
	{
		BR_Inventory_RemoveByClass(id, "item_mobo");
		BR_Inventory_RemoveByClass(id, "item_cpu");
		BR_Inventory_RemoveByClass(id, "item_powersupply");
		BR_Inventory_GiveByClass(id, "item_computer");
	}
}

public BR_OnUseItem(id, slot, itemid)
{
	if (itemid == g_itemid[ITEM_COMPUTER])
	{
		if (g_IsPlacing[id])
		{
			client_print(id, print_center, "你在放置電腦");
			return PLUGIN_HANDLED;
		}
		else
		{
			g_PlayerEnt[id] = CreateTempComputer(id);
			g_IsPlacing[id] = true;
			g_LastUseTime[id] = get_gametime();

			client_print(id, print_chat, "[BR] 放置電腦中...按住 E 放置, 快按兩下 E 鍵取消");
			return PLUGIN_HANDLED;
		}
	}

	return PLUGIN_CONTINUE;
}

public OnCmdStart(id, uc)
{
	if (is_user_alive(id) && g_IsPlacing[id])
	{
		new button = get_uc(uc, UC_Buttons);
		new oldbutton = entity_get_int(id, EV_INT_oldbuttons);

		if (button & IN_USE)
		{
			if (~oldbutton & IN_USE)
			{
				if (get_gametime() < g_LastPressTime[id] + 0.25)
				{
					ResetPlayerComputer(id, true);
					client_print(id, print_chat, "放置狀態取消");
				}

				g_LastPressTime[id] = get_gametime();
			}
			else
			{
				if (get_gametime() >= g_LastPressTime[id] + 1.5)
				{
					PlaceComputer(id);
				}
			}
		}
	}
}

public OnPlayerPreThink(id)
{
	if (g_IsPlacing[id])
	{
		new ent = g_PlayerEnt[id];

		if (!is_user_alive(id) || !is_valid_ent(ent) || !BR_Inventory_HasItem(id, g_itemid[ITEM_COMPUTER]))
		{
			ResetPlayerComputer(id, true);
			return;
		}

		if (get_gametime() >= g_LastUseTime[id] + 15.0)
		{
			ResetPlayerComputer(id, true);
			client_print(id, print_chat, "因為你長時間未放置, 放置狀態已經取消");
			return;
		}

		new Float:start[3], Float:end[3];
		entity_get_vector(id, EV_VEC_origin, start);
		entity_get_vector(id, EV_VEC_view_ofs, end);
		xs_vec_add(start, end, start);

		velocity_by_aim(id, 100, end);
		xs_vec_add(start, end, end);

		engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, 0);		
		get_tr2(0, TR_vecEndPos, end);

		start = end;
		end[2] -= 100.0;

		engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, 0);
		get_tr2(0, TR_vecEndPos, end);

		entity_set_origin(ent, end);

		new Float:angle[3];
		entity_get_vector(id, EV_VEC_v_angle, angle);

		angle[0] = 0.0;
		angle[1] += 180.0;
		angle[1] += angle[1] > 180.0 ? -360.0 : 0.0;

		entity_set_vector(ent, EV_VEC_angles, angle);	
	}
}

stock PlaceComputer(id)
{
	new ent = g_PlayerEnt[id];

	if (!is_valid_ent(ent) || !BR_Inventory_HasItem(id, g_itemid[ITEM_COMPUTER]))
		return;

	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);
	entity_set_int(ent, EV_INT_rendermode, kRenderNormal);
	entity_set_float(ent, EV_FL_renderamt, 255.0);

	ResetPlayerComputer(id, false);

	BR_Inventory_RemoveByClass(id, "item_computer");
	client_print(0, print_chat, "[BR] %n 放置了電腦", id);
}

stock ResetPlayerComputer(id, bool:remove=true)
{
	new ent = g_PlayerEnt[id];

	if (remove && is_valid_ent(ent))
	{
		remove_entity(ent);
	}

	g_PlayerEnt[id] = 0;
	g_IsPlacing[id] = false;
}

stock CreateTempComputer(id)
{
	new ent = create_entity("func_button");

	entity_set_string(ent, EV_SZ_classname, "br_computer");
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_edict(ent, EV_ENT_enemy, id);

	entity_set_model(ent, COMPUTER_MODEL);

	entity_set_int(ent, EV_INT_rendermode, kRenderTransAlpha);
	entity_set_float(ent, EV_FL_renderamt, 130.0);

	return ent;
}