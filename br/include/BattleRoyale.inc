#if defined _BattleRoyale_included
	#endinput
#endif
#define _BattleRoyale_included

enum
{
	ATTRIB_HP, // 體力
	ATTRIB_DEF, // 防禦
	ATTRIB_ATK, // 攻擊
	ATTRIB_STR, // 力量
	ATTRIB_INT, // 智力
	ATTRIB_SPD, // 速度
};

native BR_GetPlayerSociety(id);
native BR_GetPlayerAttrib(id, attrib);