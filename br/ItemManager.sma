#include <amxmodx>

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

new Array:g_ItemData;
new g_NumItems;

new Trie:g_ItemHashMap;

public plugin_precache()
{
    g_ItemData = ArrayCreate(ItemData);
    g_ItemHashMap = TrieCreate();
}

public plugin_init()
{
	register_plugin("[BR] Item Manager", VERSION, "holla");
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

public NativeRegister()
{
    new name[32], desc[64], class[32];
    get_string(1, name, charsmax(name));
    get_string(2, desc, charsmax(desc));
    get_string(3, class, charsmax(class));

    new flags = get_param(4);
    new weight = get_param(5);

    return RegisterItem(name, desc, class, flags, weight);
}

public NativeGetName()
{
    new itemid = get_param(1);
    
    new name[32]
    GetItemName(itemid, name, charsmax(name));

    set_string(2, name, get_param(3));
}

public NativeGetDesc()
{
    new itemid = get_param(1);
    
    new desc[64]
    GetItemDesc(itemid, desc, charsmax(desc));

    set_string(2, desc, get_param(3));
}

public NativeGetClass()
{
    new itemid = get_param(1);
    
    new class[32]
    GetItemName(itemid, class, charsmax(class));

    set_string(2, class, get_param(3));
}

public NativeGetFlags()
{
    new itemid = get_param(1);

    return GetItemFlags(itemid);
}

public NativeGetWeight()
{
    new itemid = get_param(1);
    
    return GetItemWeight(itemid);
}

public NativeFindByClass()
{
    new classname[32];
    get_string(1, classname, charsmax(classname));

    return FindItemByClass(classname);
}

stock RegisterItem(const name[], const desc[], const class[], flags, weight)
{
    new data[ItemData];

    copy(data[ITEM_NAME], charsmax(data[ITEM_NAME]), name);
    copy(data[ITEM_DESC], charsmax(data[ITEM_DESC]), desc);
    copy(data[ITEM_CLASS], charsmax(data[ITEM_CLASS]), class);

    data[ITEM_FLAGS] = flags;
    data[ITEM_WEIGHT] = weight;

    ArrayPushArray(g_ItemData, data);
    TrieSetCell(g_ItemHashMap, class, g_NumItems);

    g_NumItems++;
    return (g_NumItems - 1);
}

stock GetItemName(itemid, buffer[], len)
{
    new data[ItemData];
    ArrayGetArray(g_ItemData, itemid, data);

    copy(buffer, len, data[ITEM_NAME]);
}

stock GetItemDesc(itemid, buffer[], len)
{
    new data[ItemData];
    ArrayGetArray(g_ItemData, itemid, data);

    copy(buffer, len, data[ITEM_DESC]);
}

stock GetItemClass(itemid, buffer[], len)
{
    new data[ItemData];
    ArrayGetArray(g_ItemData, itemid, data);

    copy(buffer, len, data[ITEM_CLASS]);
}

stock GetItemFlags(itemid)
{
    new data[ItemData];
    ArrayGetArray(g_ItemData, itemid, data);

    return data[ITEM_FLAGS];
}

stock GetItemWeight(itemid)
{
    new data[ItemData];
    ArrayGetArray(g_ItemData, itemid, data);

    return data[ITEM_WEIGHT];
}

stock FindItemByClass(const classname[])
{
    new itemid;
    if (TrieGetCell(g_ItemHashMap, classname, itemid))
        return itemid;
    
    return NULL_ITEM;
}