#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <fakemeta>
#include <fun>
#include <msgstocks>

#if AMXX_VERSION_NUM < 183
    #include <dhudmessage>
#endif

#define rnd random(256)
#pragma unused lightning

new pos1[3] = {358, 2048, -53}, ent1
new pos2[3] = {390, 2527, -82}, ent2
new beam, rec, menu, page, unused, explosion, smoke 
new lightning, ball, flame, glow, bubbles

public plugin_precache()
{
    beam = precache_model("sprites/laserbeam.spr")
    explosion = precache_model("sprites/fexplo.spr")
    smoke = precache_model("sprites/steam1.spr")
    lightning = precache_model("sprites/lgtning.spr")
    ball = precache_model("models/w_grenade.mdl")
    flame = precache_model("sprites/flame.spr")
    glow = precache_model("sprites/glow01.spr")
    bubbles = precache_model("sprites/bubble.spr")
}

public act(id)
{
    menu_display(id, menu, clamp(page, .max = menu_pages(menu) - 1))
    return PLUGIN_HANDLED
}

public plugin_init()
{
    register_plugin("TE_TESTING", "1.0", "OciXCrom")
    register_concmd("act", "act")
    register_concmd("set", "set")
    register_clcmd("set1", "set1")
    register_clcmd("set2", "set2")
    register_clcmd("switch", "switchit")

    menu = menu_create("Temporary entity effects list", "menuhandler")
    menu_additem(menu, "te_create_beam_between_points")
    menu_additem(menu, "te_create_beam_from_entity")
    menu_additem(menu, "te_create_gunshot")
    menu_additem(menu, "te_create_explosion")
    menu_additem(menu, "te_create_tar_explosion")
    menu_additem(menu, "te_create_smoke")
    menu_additem(menu, "te_create_tracer")
    menu_additem(menu, "te_create_beam_between_entities")
    menu_additem(menu, "te_create_sparks")
    menu_additem(menu, "te_create_lava_splash")
    menu_additem(menu, "te_create_teleport_splash")
    menu_additem(menu, "te_create_colored_explosion")
    menu_additem(menu, "te_place_decal_from_bsp_file")
    menu_additem(menu, "te_create_implosion")
    menu_additem(menu, "te_create_model_trail")
    menu_additem(menu, "te_display_additive_sprite")
    menu_additem(menu, "te_create_beam_sprite")
    menu_additem(menu, "te_create_beam_ring")
    menu_additem(menu, "te_create_beam_disk")
    menu_additem(menu, "te_create_beam_cylinder")
    menu_additem(menu, "te_create_following_beam")
    menu_additem(menu, "te_display_glow_sprite")
    menu_additem(menu, "te_create_beam_ring_between_entities")
    menu_additem(menu, "te_create_tracer_shower")
    menu_additem(menu, "te_create_dynamic_light")
    menu_additem(menu, "te_create_entity_light")
    menu_additem(menu, "te_draw_line")
    menu_additem(menu, "te_create_box")
    menu_additem(menu, "te_remove_all_beams_from_entity")
    menu_additem(menu, "te_create_large_funnel")
    menu_additem(menu, "te_create_bloodstream")
    menu_additem(menu, "te_draw_blood_line")
    menu_additem(menu, "te_spray_blood")
    menu_additem(menu, "te_place_brush_decal")
    menu_additem(menu, "te_create_bouncing_model")
    menu_additem(menu, "te_create_explode_model")
    menu_additem(menu, "te_create_break_model")
    menu_additem(menu, "te_place_gunshot_decal")
    menu_additem(menu, "te_create_sprite_spray")
    menu_additem(menu, "te_create_armor_ricochet")
    menu_additem(menu, "te_place_player_spray")
    menu_additem(menu, "te_create_bubble_box")
    menu_additem(menu, "te_create_bubble_line")
    menu_additem(menu, "te_display_falling_sprite")
    menu_additem(menu, "te_place_world_decal")
    menu_additem(menu, "te_create_projectile")
    menu_additem(menu, "te_create_sprite_shower")
    menu_additem(menu, "te_emit_sprite_from_player")
    menu_additem(menu, "te_create_particle_burst")
    menu_additem(menu, "te_create_fire_field")
    menu_additem(menu, "te_attach_model_to_player")
    menu_additem(menu, "te_remove_player_attachments")
    menu_additem(menu, "te_create_multi_gunshot")
    menu_additem(menu, "te_create_user_tracer")
    menu_additem(menu, "draw_ammo_pickup_icon")
    menu_additem(menu, "draw_weapon_pickup_icon")
    menu_additem(menu, "draw_status_icon")
    menu_additem(menu, "draw_train_controls")
    menu_additem(menu, "send_geiger_signal")
    menu_additem(menu, "hide_hud_elements")
    menu_additem(menu, "fade_user_screen")
    menu_additem(menu, "shake_user_screen")
    menu_additem(menu, "set_user_fov")
    menu_additem(menu, "cs_draw_progress_bar")
    menu_additem(menu, "cs_play_reload_sound")
    menu_additem(menu, "cs_set_hud_icon")
    menu_additem(menu, "cs_set_user_shadow")
}

public menuhandler(id, menu, item)
{
    if(!is_user_connected(id))
        return

    new upos[3], vpos[3]
    get_user_origin(id, upos)
    get_user_origin(id, vpos, 3)
    player_menu_info(id, unused, unused, page)

    switch(item)
    {
        case 0: te_create_beam_between_points(pos1, pos2, beam, .r = rnd, .g = rnd, .b = rnd)
        case 1: te_create_beam_from_entity(ent1, vpos, beam, .r = rnd, .g = rnd, .b = rnd)
        case 2: te_create_gunshot(vpos)
        case 3: te_create_explosion(vpos, explosion)
        case 4: te_create_tar_explosion(vpos)
        case 5: te_create_smoke(vpos, smoke)
        case 6: te_create_tracer(upos, vpos)
        case 7: te_create_beam_between_entities(ent1, ent2, beam, .r = rnd, .g = rnd, .b = rnd)
        case 8: te_create_sparks(vpos)
        case 9: te_create_lava_splash(vpos)
        case 10: te_create_teleport_splash(vpos)
        case 11: te_create_colored_explosion(vpos, 0, 0)
        case 12: te_place_decal_from_bsp_file(vpos, rec)
        case 13: te_create_implosion(vpos)
        case 14: te_create_model_trail(upos, vpos, ball)
        case 15: te_display_additive_sprite(vpos, flame)
        case 16: te_create_beam_sprite(upos, vpos, beam, flame)
        case 17: te_create_beam_ring(vpos, beam, .r = rnd, .g = rnd, .b = rnd)
        case 18: te_create_beam_disk(vpos, beam, .r = rnd, .g = rnd, .b = rnd)
        case 19: te_create_beam_cylinder(vpos, beam, .r = rnd, .g = rnd, .b = rnd)
        case 20: te_create_following_beam(id, beam, .r = rnd, .g = rnd, .b = rnd)
        case 21: te_display_glow_sprite(vpos, glow)
        case 22: te_create_beam_ring_between_ent(ent1, ent2, beam, .r = rnd, .g = rnd, .b = rnd)
        case 23: te_create_tracer_shower(vpos, _, rnd, 16)
        case 24: te_create_dynamic_light(vpos, .r = rnd, .g = rnd, .b = rnd)
        case 25: te_create_entity_light(ent1, .r = rnd, .g = rnd, .b = rnd)
        case 26: te_draw_line(upos, vpos, .r = rnd, .g = rnd, .b = rnd)
        case 27: te_create_box(upos, vpos, .r = rnd, .g = rnd, .b = rnd)
        case 28: te_remove_all_beams_from_entity(id)
        case 29: te_create_large_funnel(vpos, glow)
        case 30: te_create_bloodstream(vpos, .color = rnd)
        case 31: te_draw_blood_line(upos, vpos)
        case 32: te_spray_blood(vpos)
        case 33: te_place_brush_decal(vpos, ent1, rec)
        case 34: te_create_bouncing_model(vpos, ball, .bouncesound = BounceSound_ShotShell)
        case 35: te_create_explode_model(vpos, ball)
        case 36: te_create_break_model(vpos, ball, .flags = BreakModel_Flesh)
        case 37: te_place_gunshot_decal(vpos)
        case 38: te_create_sprite_spray(vpos, beam)
        case 39: te_create_armor_ricochet(vpos)
        case 40: te_place_player_spray(vpos, id)
        case 41: te_create_bubble_box(vpos, vpos, bubbles)
        case 42: te_create_bubble_line(pos1, pos2, bubbles)
        case 43: te_display_falling_sprite(vpos, ball, ball, rnd, rec)
        case 44: te_place_world_decal(vpos, rec)
        case 45: te_create_projectile(vpos, {50,50,50}, ball)
        case 46: te_create_sprite_shower(vpos, flame)
        case 47: te_emit_sprite_from_player(ent1, ball)
        case 48: te_create_particle_burst(vpos)
        case 49: te_create_fire_field(vpos, flame, .flags = TEFIRE_FLAG_ALPHA)
        case 50: te_attach_model_to_player(ent1, ball)
        case 51: te_remove_player_attachments(ent1)
        case 52: te_create_multi_gunshot(upos, vpos)
        case 53: te_create_user_tracer(upos, vpos, 20, 2, 5)
        case 54: draw_ammo_pickup_icon(id, rec, 69)
        case 55: draw_weapon_pickup_icon(id, rec)
        case 56: draw_status_icon(id, "d_ump45", StatusIcon_Show, rnd, rnd, rnd)
        case 57: draw_train_controls(id, TrainControls_Medium)
        case 58: send_geiger_signal(id, rec)
        case 59: hide_hud_elements(rec, HideElement_Money, true)
        case 60: fade_user_screen(id, .r = rnd, .g = rnd, .b = rnd)
        case 61: shake_user_screen(id)
        case 62: set_user_fov(id, rec)
        case 63: cs_draw_progress_bar(id, rec)
        case 64: cs_play_reload_sound(id)
        case 65: cs_set_hud_icon(id, 1, "d_ump45", rec, 4, 2)
        case 66: cs_set_user_shadow(id, rec)
    }

    new iname[64], unused, szunused[2]
    menu_item_getinfo(menu, item, unused, szunused, unused, iname, charsmax(iname), unused)

    set_dhudmessage(rnd, rnd, rnd, -1.0, 0.85, 0, 0.2, 1.0, 0.1, 0.1)
    show_dhudmessage(id, iname)

    if(item != MENU_EXIT)
        act(id)
}

public set(id)
{
    new szPlayer[32]
    read_argv(1, szPlayer, charsmax(szPlayer))
    rec = str_to_num(szPlayer)
    CromChat(id, "Receiver set to &x04%i", rec)
    return PLUGIN_HANDLED
}

public set1(id)
{
    get_user_aiming(id, ent1, unused)

    if(pev_valid(ent1))
        CromChat(id, "&x06Primary entity set to &x04%i", ent1)
    else
    {
        get_user_origin(id, pos1, 3)
        CromChat(id, "&x06Primary position set at &x04%i %i %i", pos1[0], pos1[1], pos1[2])
    }

    return PLUGIN_HANDLED
}

public set2(id)
{
    get_user_aiming(id, ent2, unused)

    if(pev_valid(ent2))
        CromChat(id, "&x07Secondary entity set to &x04%i", ent2)
    else
    {
        get_user_origin(id, pos2, 3)
        CromChat(id, "&x07Secondary position set at &x04%i %i %i", pos2[0], pos2[1], pos2[2])
    }

    return PLUGIN_HANDLED
}

public switchit(id)
{
    new oldbeam = beam
    new oldball = ball

    beam = oldball
    ball = oldbeam

    CromChat(id, "Switch successfull!")
    return PLUGIN_HANDLED
}  