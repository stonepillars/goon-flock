/mob/living/critter/flock/bit
	name = "floaty gewgaw"
	desc = "Well, that's a thing."
	icon_state = "flockbit"
	density = 0
	hand_count = 2
	pays_to_construct = 0 // free buildings!!
	health_brute = 5 // fragile, handle with care (one smack will destroy them)
	health_burn = 5
	fits_under_table = 1
	flags = TABLEPASS

/mob/living/critter/flock/bit/New(var/atom/location, var/datum/flock/F=null)
	..(src, F)

	src.ai = new /datum/aiHolder/flock/bit(src)

	SPAWN(1 SECOND) // aaaaaaa
		animate_bumble(src)
		src.zone_sel.change_hud_style('icons/mob/flock_ui.dmi')

	src.name = "[pick_string("flockmind.txt", "flockbit_name_adj")] [pick_string("flockmind.txt", "flockbit_name_noun")]"
	src.real_name = "[pick(consonants_upper)].[rand(10,99)].[rand(10,99)]"
	src.update_name_tag()

	APPLY_ATOM_PROPERTY(src, PROP_ATOM_FLOCK_THING, src)
	src.AddComponent(/datum/component/flock_protection)

/mob/living/critter/flock/bit/special_desc(dist, mob/user)
	if(isflock(user))
		return {"<span class='flocksay'><span class='bold'>###=-</span> Ident confirmed, data packet received.
		<br><span class='bold'>ID:</span> [src.real_name]
		<br><span class='bold'>Flock:</span> [src.flock ? src.flock.name : "none"]
		<br><span class='bold'>System Integrity:</span> [max(0, round(src.get_health_percentage() * 100))]%
		<br><span class='bold'>Cognition:</span> [src.dormant ? "ABSENT" : "PREDEFINED"]
		<br><span class='bold'>###=-</span></span>"}
	else
		return null // give the standard description

/mob/living/critter/flock/bit/Life(datum/controller/process/mobs/parent)
	if (..(parent))
		return 1
	if (!src.dormant && src.z != Z_LEVEL_STATION)
		src.dormantize()

/mob/living/critter/flock/bit/MouseDrop_T(mob/living/target, mob/user)
	if(!target || !user)
		return
	if(target == user)
		if(istype(user, /mob/living/intangible/flock))
			// whoops
			boutput(user, "<span class='flocksay'>Insufficient processing power for partition override.</span>")
		else
			..() // do ghost observes, i guess
	else
		..()

/mob/living/critter/flock/bit/setup_hands()
	..()
	var/datum/handHolder/HH = hands[1]
	HH.limb = new /datum/limb/flock_grip
	HH.name = "grip tool"
	HH.icon = 'icons/mob/flock_ui.dmi'
	HH.icon_state = "griptool"
	HH.limb_name = HH.name
	HH.can_hold_items = 1
	HH.can_attack = 1
	HH.can_range_attack = 0

	HH = hands[2]
	HH.limb = new /datum/limb/flockbit_converter
	HH.name = "nanite spray"
	HH.icon = 'icons/mob/flock_ui.dmi'
	HH.icon_state = "converter"
	HH.limb_name = HH.name
	HH.can_hold_items = 0
	HH.can_attack = 1
	HH.can_range_attack = 0

/mob/living/critter/flock/bit/dormantize()
	src.icon_state = "bit-dormant"
	animate(src) // doesnt work right now
	..()

/mob/living/critter/flock/bit/death(var/gibbed)
	..()
	flockdronegibs(get_turf(src))
	if (src.mind || src.client)
		src.ghostize()
	src.update_health_icon()
	qdel(src)

/mob/living/critter/flock/bit/TakeDamage(zone, brute, burn, tox, damage_type, disallow_limb_loss)
	..()
	src.update_health_icon()

/mob/living/critter/flock/bit/proc/update_health_icon()
	if (!src.flock)
		return
	var/image/I
	if (src.real_name in src.flock.annotations_health)
		I = src.flock.annotations_health[src.real_name]
		src.flock.annotations_health -= src.real_name
		src.flock.removeClientImage(I)

	if (isdead(src) || src.dormant || src.disposed)
		return

	I = image('icons/misc/featherzone.dmi', src, "hp-[round(src.get_health_percentage() * 10) * 10]")
	I.blend_mode = BLEND_ADD
	I.pixel_x = 10
	I.pixel_y = 16
	I.plane = PLANE_ABOVE_LIGHTING
	I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	src.flock.annotations_health[src.real_name] = I
	src.flock.addClientImage(I)

/mob/living/critter/flock/bit/disposing()
	if (src.mind || src.client)
		src.ghostize()
	..()

// okay so this might be fun for gimmicks
/mob/living/critter/flock/bit/Login()
	..()
	src.client?.color = null
	src.ai?.stop_move()
	src.is_npc = 0

/mob/living/critter/flock/bit/specific_emotes(var/act, var/param = null, var/voluntary = 0)
	switch (act)
		if ("whistle", "beep", "burp", "scream", "growl", "abeep", "grump", "fart")
			if (src.emote_check(voluntary, 50))
				playsound(src, "sound/misc/flockmind/flockbit_wisp[pick("1","2","3","4","5","6")].ogg", 40, 1)
				return "<b>[src]</b> chimes."
		if ("flip")
			if (src.emote_check(voluntary, 50) && !src.shrunk)
				SPAWN(1 SECOND)
					animate_bumble(src) // start the floaty animation again (stolen from bees of course)
				return null
	return null

/////////////////////////////////////

/datum/limb/flockbit_converter // can only convert turfs but can do it for free and faster

/datum/limb/flockbit_converter/attack_hand(atom/target, var/mob/living/critter/flock/bit/user, var/reach, params, location, control)
	if (!holder)
		return
	if(check_target_immunity( target ))
		return
	if (!istype(user))
		return
	// CONVERT TURF
	if(!isturf(target))
		target = get_turf(target)

	if(!istype(target, /turf/simulated) && !istype(target, /turf/space))
		boutput(user, "<span class='alert'>Something about this structure prevents it from being assimilated.</span>")
	else
		playsound(src, "sound/misc/flockmind/flockbit_wisp[pick("1","2","3","4","5","6")].ogg", 40)
		actions.start(new/datum/action/bar/flock_convert(target, 25), user)
