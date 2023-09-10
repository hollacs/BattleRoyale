#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>

new MaxServerSlots;

#define IsAlivePlayer(%0)  ( 1 <= %0 <= MaxServerSlots && is_user_alive( %0 ) )
#define IsUserVIP(%0)      ( get_pdata_int( %0, /*m_fVIPStatus*/ 209 ) & /*VipStatus_IsVIP*/ 1<<8 )
#define IsShieldDrawn(%0)  ( get_pdata_int( %0, /*m_iUserPrefs*/ 510 ) & /*UserPrefs_ShielDrawn*/ 1<<16 )
#define IsOnGround(%0)     ( pev_valid( %0 ) && pev( %0, pev_flags ) & FL_ONGROUND )

public plugin_init()
{
    register_plugin( "Pickup Multiple Weapon", "1.0.0", "Arkshine" );

    RegisterHam( Ham_Touch, "weaponbox", "OnWeaponboxTouch", true );

    MaxServerSlots = get_maxplayers();
}

public OnWeaponboxTouch( const weaponbox, const other )
{
    if( IsAlivePlayer( other ) && IsOnGround( weaponbox ) && !IsUserVIP( other ) && !IsShieldDrawn( other ) )
    {
        const m_rgpPlayerItems_Slot0 = 34;
        const m_pNext = 42;

        for( new slot = 1, item, nextItem; slot <= 2; slot++ )
        {
            item = get_pdata_cbase( weaponbox, m_rgpPlayerItems_Slot0 + slot, .linuxdiff = 4 );

            while( item > 0 )
            {
                set_pdata_cbase( weaponbox, m_rgpPlayerItems_Slot0 + slot, nextItem = get_pdata_cbase( item, m_pNext, .linuxdiff = 4 ), .linuxdiff = 4 );

                if( ExecuteHam( Ham_AddPlayerItem, other, item ) )
                {
                    ExecuteHam( Ham_Item_AttachToPlayer, item, other );
                }

                item = nextItem;
            }
        }

        emit_sound( other, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM );

        set_pev( weaponbox, pev_flags, pev( weaponbox, pev_flags ) | FL_KILLME );
    }
}  