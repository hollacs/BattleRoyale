#include <amxmodx>
#include <engine>
#include <BR_ItemInventory>

#define VERSION "0.1"

public plugin_precache()
{
    precache_model("models/w_grenade.mdl");
    precache_model("models/w_battery.mdl");
    precache_model("models/w_weaponbox.mdl");
    precache_model("models/w_medkit.mdl");
}

public plugin_init()
{
    register_plugin("[BR] Item Models", VERSION, "holla");
}

public BR_OnTouchItem(player, ent, itemid)
{
	if (BR_Inventory_Give(player, itemid))
	{
		new name[32];
		BR_Item_GetName(itemid, name, charsmax(name));

		client_print(0, print_chat, "^"%n^" 執到 ^"%s^".", player, name);
		remove_entity(ent);
	}
}

public BR_OnCombineItemPost(id, itemid, Array:conditions)
{
    new name[32];
    BR_Item_GetName(itemid, name, charsmax(name));

    client_print(id, print_chat, "你成功合成了 '%s', 已存放到背包中", name);
}

public BR_OnItemEntSetModel(ent, itemid)
{
    new classname[32];
    BR_Item_GetClass(itemid, classname, charsmax(classname));

    if (equal(classname, "food_", 5))
        entity_set_model(ent, "models/w_grenade.mdl");
    else if (equal(classname, "item_", 5))
        entity_set_model(ent, "models/w_battery.mdl");
    else if (equal(classname, "weapon_", 7))
        entity_set_model(ent, "models/w_weaponbox.mdl");
    else if (equal(classname, "heal_", 5))
        entity_set_model(ent, "models/w_medkit.mdl");
}