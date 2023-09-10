#include <amxmodx>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <BR_ItemInventory>

enum _:MaxItems
{
    ITEM_DOG = 0,
    ITEM_ROCK,
    ITEM_ROPE,
    ITEM_STICK,
    ITEM_APPLE,
    ITEM_ORANGE,
    ITEM_BANANA,
    ITEM_MEDKIT,
    ITEM_BIGJJ,
    ITEM_FRUITS,
    ITEM_AXE,
};

new g_itemid[MaxItems];

public plugin_init()
{
    register_plugin("[BR] Item: Test", "0.1", "holla");

    g_itemid[ITEM_DOG] = BR_Item_Register("黑警的狗牌", "PC9527", "item_dog", 0, 30);
    g_itemid[ITEM_ROCK] = BR_Item_Register("石頭", "尖銳的石頭", "item_rock", 0, 60);
    g_itemid[ITEM_ROPE] = BR_Item_Register("繩子", "", "item_rope", 0, 50);
    g_itemid[ITEM_STICK] = BR_Item_Register("樹枝", "粗樹枝", "item_stick", 0, 60);
    g_itemid[ITEM_APPLE] = BR_Item_Register("蘋果", "+30 HP", "food_apple", 0, 50);
    g_itemid[ITEM_ORANGE] = BR_Item_Register("橙", "+40 HP", "food_orange", 0, 45);
    g_itemid[ITEM_BANANA] = BR_Item_Register("香蕉", "+50 HP", "food_banana", 0, 40);
    //g_itemid[ITEM_M249] = BR_Item_Register("M249", "Machine Gun", "weapon_m249", 0, 10);
    //g_itemid[ITEM_DEAGLE] = BR_Item_Register("Deagle", "打手槍", "weapon_mp5", 0, 15);
    g_itemid[ITEM_MEDKIT] = BR_Item_Register("Medkit", "100HP", "heal_medkit", 0, 35);
    g_itemid[ITEM_BIGJJ] = BR_Item_Register("偉哥", "last longer get harder", "heal_bigjj", 0, 35);
    g_itemid[ITEM_FRUITS] = BR_Item_Register("生果盤", "+75 HP", "food_fruits", 0, 0);
    g_itemid[ITEM_AXE] = BR_Item_Register("簡單的石斧", "近戰武器", "weapon_axe", 0, 0);

    RequestFrame("AfterPluginInit");
}

public AfterPluginInit()
{
    BR_AddItemCombineCond("food_fruits", "food_apple", "蘋果");
    BR_AddItemCombineCond("food_fruits", "food_banana", "香蕉");
    BR_AddItemCombineCond("food_fruits", "food_orange", "橙");

    BR_AddItemCombineCond("weapon_axe", "item_stick", "樹枝");
    BR_AddItemCombineCond("weapon_axe", "item_rope", "繩子");
    BR_AddItemCombineCond("weapon_axe", "item_rock", "石頭");
}

public BR_OnCheckItemCombineCond(id, itemid, cond_id, const cond_name[])
{
    if (itemid == g_itemid[ITEM_FRUITS])
    {
        if (!BR_Inventory_HasItemClass(id, cond_name))
            return PLUGIN_HANDLED;
    }
    else if (itemid == g_itemid[ITEM_AXE])
    {
        if (!BR_Inventory_HasItemClass(id, cond_name))
            return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public BR_OnCombineItemPost(id, itemid, Array:conditions)
{
    if (itemid == g_itemid[ITEM_FRUITS])
    {
        RemoveRequiredItems(id, conditions);
        BR_Inventory_GiveByClass(id, "food_fruits");
    }
    else if (itemid == g_itemid[ITEM_AXE])
    {
        RemoveRequiredItems(id, conditions);
        BR_Inventory_GiveByClass(id, "weapon_axe");
    }

    new name[32];
    BR_Item_GetName(itemid, name, charsmax(name));

    client_print(id, print_center, "成功合成 ^"%s^"", name);
}

public BR_OnUseItem(id, slot, itemid)
{
    if (itemid == g_itemid[ITEM_DOG])
    {
        client_print(id, print_chat, "[BR] You cannot use this item.");
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public BR_OnUseItemPost(id, slot, itemid)
{
    if (itemid == g_itemid[ITEM_APPLE])
    {
        new Float:hp;
        pev(id, pev_health, hp);
        set_pev(id, pev_health, hp + 30.0);
    }
    else if (itemid == g_itemid[ITEM_ORANGE])
    {
        new Float:hp;
        pev(id, pev_health, hp);
        set_pev(id, pev_health, hp + 50.0);
    }
    else if (itemid == g_itemid[ITEM_MEDKIT])
    {
        set_pev(id, pev_health, 100.0);
    }
    else if (itemid == g_itemid[ITEM_BIGJJ])
    {
        set_pev(id, pev_health, 255.0);
        client_print(0, print_chat, "[BR] %n 食咗偉哥 !!!", id);
    }
}

stock RemoveRequiredItems(id, Array:conditions)
{
    new name[32];
    new size = ArraySize(conditions);

    for (new i = 0; i < size; i++)
    {
        BR_GetItemCombineCondName(conditions, i, name, charsmax(name));
        BR_Inventory_RemoveByClass(id, name);
    }
}