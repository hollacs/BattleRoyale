#if defined _BR_ItemManager_included
	#endinput
#endif
#define _BR_ItemManager_included

#define NULL_ITEM -1

native BR_Item_Register(const name[], const desc[], const class[], flags, weight);
native BR_Item_GetName(index, name[], len);
native BR_Item_GetDesc(index, desc[], len);
native BR_Item_GetClass(index, class[], len);
native BR_Item_GetFlags(index);
native BR_Item_GetWeight(index);
native BR_Item_FindByClass(const classname[]);

forward BR_OnItemEntSetModel(ent, itemid);
forward BR_OnTouchItem(player, ent, itemid);