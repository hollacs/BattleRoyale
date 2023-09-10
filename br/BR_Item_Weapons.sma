#include <amxmodx>
#include <fun>
#include <fakemeta>
#include <engine>
#include <BR_ItemInventory>

const PRIMARY_WEAPONS = (1<<CSW_M3)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_TMP)|(1<<CSW_MP5NAVY)|(1<<CSW_UMP45)|(1<<CSW_P90)|
    (1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AK47)|(1<<CSW_M4A1)|(1<<CSW_SG552)|(1<<CSW_AUG)|(1<<CSW_SG550)|(1<<CSW_G3SG1)|
    (1<<CSW_SCOUT)|(1<<CSW_AWP)|(1<<CSW_M249);

const SECONDARY_WEAPONS = (1<<CSW_GLOCK18)|(1<<CSW_USP)|(1<<CSW_P228)|(1<<CSW_DEAGLE)|(1<<CSW_FIVESEVEN)|(1<<CSW_ELITE);

const AVAILABLE_WEAPONS = PRIMARY_WEAPONS|SECONDARY_WEAPONS;

new const WEAPON_NAMES[][] = { "", "P228 Compact", "", "Schmidt Scout", "HE Grenade", "XM1014 M4", "", "Ingram MAC-10", "Steyr AUG A1",
			"Smoke Grenade", "Dual Elite Berettas", "FiveseveN", "UMP 45", "SG-550 Auto-Sniper", "IMI Galil", "Famas",
			"USP .45 ACP Tactical", "Glock 18C", "AWP Magnum Sniper", "MP5 Navy", "M249 Para Machinegun",
			"M3 Super 90", "M4A1 Carbine", "Schmidt TMP", "G3SG1 Auto-Sniper", "Flashbang", "Desert Eagle .50 AE",
			"SG-552 Commando", "AK-47 Kalashnikov", "", "ES P90" };

new const WEAPON_WEIGHT[] = { 0, 2, 0, 2, 0, 1, 0, 3, 0,
			0, 3, 2, 2, 0, 1, 1,
			2, 3, 0, 2, 0,
			1, 0, 3, 0, 0, 0,
			0, 0, 0, 1 };

const MAX_GUNS = 24;

new g_ItemId[MAX_GUNS];
new g_NumItems;

public plugin_init()
{
    register_plugin("[BR] Item: Weapons", "0.1", "holla");

    register_forward(FM_SetModel, "OnSetModel");

    new weaponname[32];
    new total = 0;

    for (new i = CSW_P228; i <= CSW_P90; i++)
    {
        if (AVAILABLE_WEAPONS & (1 << i))
        {
            get_weaponname(i, weaponname, charsmax(weaponname));
            g_ItemId[g_NumItems++] = BR_Item_Register(WEAPON_NAMES[i], "槍械", weaponname, 0, WEAPON_WEIGHT[i]);
            total += WEAPON_WEIGHT[i];
        }
    }

    server_print("total weapon weight: %d", total);
}

public OnSetModel(ent, const model[])
{
    if (strlen(model) < 8)
        return;
    
    // Get entity's classname
    new classname[10];
    entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname));
    
    // Check if it's a weapon box
    if (equal(classname, "weaponbox"))
    {
        new owner = entity_get_edict(ent, EV_ENT_owner);

        if (is_user_connected(owner) && !is_user_alive(owner))
        {
            entity_set_int(ent, EV_INT_flags, entity_get_int(ent, EV_INT_flags) | FL_KILLME);
        }
    }
}

public BR_OnTouchItem(player, ent, itemid)
{
    // weapon range
    if (itemid >= g_ItemId[0] && itemid <= g_ItemId[g_NumItems-1])
    {
        new classname[32];
        BR_Item_GetClass(itemid, classname, charsmax(classname));

        new weaponid = get_weaponid(classname);
        
        if (AVAILABLE_WEAPONS & (1 << weaponid))
        {
            give_item(player, classname);
            remove_entity(ent);
            return PLUGIN_HANDLED;
        }
    }

    return PLUGIN_CONTINUE;
}

public BR_OnCreateBackpackEntity(id, ent)
{
    new weapons[32], num;
    get_user_weapons(id, weapons, num);

    new weaponid, weaponname[32];
    new itemid;

    for (new i = 0; i < num; i++)
    {
        weaponid = weapons[i];

        if (~AVAILABLE_WEAPONS & (1 << weaponid))
            continue;

        get_weaponname(weaponid, weaponname, charsmax(weaponname));
        itemid = BR_Item_FindByClass(weaponname);
        
        if (itemid == NULL_ITEM)
            continue;
        
        // add weapons to die backpack
        BR_AddItemToBackpack(ent, itemid);
    }
}

public BR_OnUseItemPost(id, slot, itemid)
{
    if (itemid >= g_ItemId[0] && itemid <= g_ItemId[g_NumItems-1])
    {
        new classname[32];
        BR_Item_GetClass(itemid, classname, charsmax(classname));

        new weaponid = get_weaponid(classname);

        if (AVAILABLE_WEAPONS & (1 << weaponid))
            give_item(id, classname);
    }
}