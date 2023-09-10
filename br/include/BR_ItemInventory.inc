#if defined _BR_ItemInventory_included
	#endinput
#endif
#define _BR_ItemInventory_included

#include <BR_ItemManager>

native BR_Inventory_Get(id, slot);
native BR_Inventory_Give(id, itemid);
native BR_Inventory_Use(id, slot);
native BR_Inventory_Remove(id, slot);
native BR_Inventory_HasItem(id, itemid);
native BR_Inventory_RemoveItem(id, itemid);

native BR_GetItemCombineCondName(Array:conditions, index, output[], len);
native BR_AddItemCombineCond(const classname[], const cond_name[], const cond_info[]);

native BR_AddItemToBackpack(ent, itemid);

forward BR_OnUseItem(id, slot, itemid);
forward BR_OnUseItemPost(id, slot, itemid);

forward BR_OnRemoveItem(id, slot, itemid);

forward BR_OnGiveItem(id, slot, itemid);
forward BR_OnGiveItem_Post(id, slot, itemid);

forward BR_OnCheckItemCombineCond(id, itemid, cond_id, const cond_name[]);
forward BR_OnCombineItem(id, itemid);
forward BR_OnCombineItemPost(id, itemid, Array:conditions);

forward BR_OnCreateBackpackEntity(id, ent);

stock BR_Inventory_GiveByClass(id, const classname[])
{
	new itemid = BR_Item_FindByClass(classname);
	return BR_Inventory_Give(id, itemid);
}

stock BR_Inventory_RemoveByClass(id, const classname[])
{
	new itemid = BR_Item_FindByClass(classname);
	return BR_Inventory_RemoveItem(id, itemid);
}

stock BR_Inventory_HasItemClass(id, const classname[])
{
	new itemid = BR_Item_FindByClass(classname);
	return BR_Inventory_HasItem(id, itemid);
}