/////////////////////////////////////////////////////////////////////////////////
// ENERGY CAGE
/////////////////////////////////////////////////////////////////////////////////
// it's just an ice cube, but stronger and it looks different
// and eats people, i guess, too
/obj/flock_structure/flockdrone
	name = "weird energy cage"
	desc = "You can see the person inside being rapidly taken apart by fibrous mechanisms. You ought to do something about that."
	icon = 'icons/misc/featherzone.dmi'
	icon_state = "cage"
	health = 30
	alpha = 192
	var/atom/occupant = null
	var/obj/target = null
	var/eating_occupant = 0
	var/initial_volume = 200
	// convert things into different fluids, convert those fluids into coagulated gnesis, convert 50 of that into an egg
	var/target_fluid = "flockdrone_fluid"
	var/create_egg_at_fluid = 100
	var/absorb_per_process_tick = 2
	mat_changename = 0
	mat_changedesc = 0
	mat_changeappearance = 0


	New(loc, var/atom/iced, datum/flock/F=null)
		..(loc,F)
		if(iced && !isAI(iced) && !isblob(iced) && !iswraith(iced))
			if(istype(iced.loc, /obj/flock_structure/flockdrone)) //Already in a cube?
				qdel(src)
				return

			if(!(ismob(iced) || iscritter(iced)))
				qdel(src)
				return
			iced:set_loc(src)

			src.underlays += iced
			boutput(iced, "<span class='alert'>You are trapped within [src]!</span>") // since this is used in at least two places to trap people in things other than ice cubes

		processing_items.Add(src)
		src.flock = F
		var/datum/reagents/R = new /datum/reagents(initial_volume)
		src.reagents = R
		R.my_atom = src //grumble
		if(iced)
			if(istype(iced,/mob/living))
				var/mob/living/M = iced
				M.addOverlayComposition(/datum/overlayComposition/flockmindcircuit)
			occupant = iced
		processing_items |= src
		src.setMaterial(getMaterial("gnesis"))

	proc/getHumanPiece(var/mob/living/carbon/human/H)
		// prefer inventory items before limbs, and limbs before organs
		var/list/organs = list()
		var/list/limbs = list()
		var/list/items = list()
		var/obj/item/organ/brain/brain = null
		for(var/obj/item/I in H.contents)
			if(istype(I, /obj/item/organ/head) || istype(I, /obj/item/organ/chest) || istype(I, /obj/item/skull))
				continue // taking container organs is kinda too cheap
			if(istype(I, /obj/item/organ) || istype(I, /obj/item/clothing/head/butt))
				organs += I
				if(istype(I, /obj/item/organ/brain))
					brain = I
			else if(istype(I, /obj/item/parts))
				limbs += I
			else
				items += I
		// only take the brain as the very last thing
		if(organs.len >= 2)
			organs -= brain
		if(items.len >= 1)
			eating_occupant = 0
			target = pick(items)
			H.remove_item(target)
			playsound(src, "sound/weapons/nano-blade-1.ogg", 50, 1)
			boutput(H, "<span class='alert'>[src] pulls [target] from you and begins to rip it apart.</span>")
			src.visible_message("<span class='alert'>[src] pulls [target] from [H] and begins to rip it apart.</span>")
		else if(limbs.len >= 1)
			eating_occupant = 1
			target = pick(limbs)
			H.limbs.sever(target)
			H.emote("scream")
			random_brute_damage(H, 20)
			playsound(src, "sound/impact_sounds/Flesh_Tear_1.ogg", 80, 1)
			boutput(H, "<span class='alert bold'>[src] wrenches your [initial(target.name)] clean off and begins peeling it apart! Fuck!</span>")
			src.visible_message("<span class='alert bold'>[src] wrenches [target.name] clean off and begins peeling it apart!</span>")
		else if(organs.len >= 1)
			eating_occupant = 1
			target = pick(organs)
			H.drop_organ(target)
			H.emote("scream")
			random_brute_damage(H, 20)
			playsound(src, "sound/impact_sounds/Flesh_Tear_2.ogg", 80, 1)
			boutput(H, "<span class='alert bold'>[src] tears out your [initial(target.name)]! OH GOD!</span>")
			src.visible_message("<span class='alert bold'>[src] tears out [target.name]!</span>")
		else
			H.gib()
			occupant = null
			underlays -= H
			playsound(src, "sound/impact_sounds/Flesh_Tear_2.ogg", 80, 1)
			src.visible_message("<span class='alert bold'>[src] rips what's left of its occupant to shreds!</span>")

	Enter(atom/movable/O)
		. = ..()
		underlays += O

	proc/spawnEgg()
		src.visible_message("<span class='notice'>[src] spits out a device!</span>")
		var/obj/flock_structure/egg/egg = new(get_turf(src), src.flock)
		var/turf/target = null
		target = get_edge_target_turf(get_turf(src), pick(alldirs))
		egg.throw_at(target, 12, 3)

	process()
		// consume any fluid near us
		var/turf/T = get_turf(src)
		if(T?.active_liquid)
			var/obj/fluid/F = T.active_liquid
			F.group.drain(F, 15, src)

		// process fluids into stuff
		if(reagents.has_reagent(target_fluid, create_egg_at_fluid))
			reagents.remove_reagent(target_fluid, create_egg_at_fluid)
			spawnEgg()

		// process stuff into fluids
		if(isnull(target))
			// find a new thing to eat
			var/list/edibles = list()
			for(var/obj/O in src.contents)
				edibles += O
			if(edibles.len >= 1)
				target = pick(edibles)
				eating_occupant = 0
				playsound(src, "sound/weapons/nano-blade-1.ogg", 50, 1)
				if(occupant)
					boutput(occupant, "<span class='notice'>[src] begins to process [target].</span>")
			else if(occupant && ishuman(occupant))
				var/mob/living/carbon/human/H = occupant
				getHumanPiece(H)
			else if(isliving(occupant))
				var/mob/living/M = occupant
				M.gib()
			else if(iscritter(occupant))
				var/obj/critter/C = occupant
				C.CritterDeath()

			if(target)
				target.set_loc(src)
		else
			underlays -= target
			if(hasvar(target, "health"))
				var/absorption = min(absorb_per_process_tick, target:health)
				target:health -= absorption
				reagents.add_reagent(target_fluid, absorption * 2)
				if(target:health <= 0)
					reagents.add_reagent(target_fluid, 10)
					qdel(target)
					target = null
			else
				reagents.add_reagent(target_fluid, 10)
				qdel(target)
				target = null
		if(occupant)
			underlays -= occupant
			underlays += occupant
			if(eating_occupant && prob(20))
				boutput(occupant, "<span class='flocksay italics'>[pick_string("flockmind.txt", "flockmind_conversion")]</span>")
		if(src.contents.len <= 0 && reagents.get_reagent_amount(target_fluid) < 50)
			if(reagents.has_reagent(target_fluid)) // flood the area with our unprocessed contents
				playsound(src, "sound/impact_sounds/Slimy_Splat_1.ogg", 80, 1)
				T.fluid_react_single(reagents.get_reagent_amount(target_fluid))
			qdel(src)

	disposing()
		playsound(src, "sound/impact_sounds/Energy_Hit_2.ogg", 80, 1)
		processing_items -= src
		if(istype(occupant,/mob/living))
			var/mob/living/M = occupant
			M?.removeOverlayComposition(/datum/overlayComposition/flockmindcircuit)

		processing_items.Remove(src)
		for(var/atom/movable/AM in src)
			if(ismob(AM))
				var/mob/M = AM
				M.visible_message("<span class='alert'><b>[M]</b> breaks out of [src]!</span>","<span class='alert'>You break out of [src]!</span>")
			AM.set_loc(src.loc)

		..()

/////////////////////////////////////////////////////////////////////////////////////////////////////////area




	relaymove(mob/user as mob)
		if (user.stat)
			return

		if(prob(25))
			takeDamage(1)
		return

	takeDamage(var/damage)
		src.health -= damage
		if(src.health <= 0)
			qdel(src)
			return
		else
			var/wiggle = 3
			while(wiggle > 0)
				wiggle--
				src.pixel_x = rand(-2,2)
				src.pixel_y = rand(-2,2)
				sleep(0.5)
			src.pixel_x = 0
			src.pixel_y = 0

	attack_hand(mob/user as mob)
		user.visible_message("<span class='combat'><b>[user]</b> kicks [src]!</span>", "<span class='notice'>You kick [src].</span>")
		takeDamage(2)

	bullet_act(var/obj/projectile/P)
		var/damage = 0
		damage = round(((P.power/2)*P.proj_data.ks_ratio), 1.0)
		if (damage < 1)
			return

		switch(P.proj_data.damage_type)
			if(D_KINETIC)
				takeDamage(damage*2)
			if(D_PIERCING)
				takeDamage(damage/2)
			if(D_ENERGY)
				takeDamage(damage/4)

	attackby(obj/item/W as obj, mob/user as mob)
		takeDamage(W.force)

	mob_flip_inside(var/mob/user)
		..(user)
		user.show_text("<span class='alert'>[src] [pick("cracks","bends","shakes","groans")].</span>")
		src.takeDamage(6)

	ex_act(severity)
		for(var/atom/A in src)
			A.ex_act(severity)
		SPAWN(0)
			takeDamage(20 / severity)
		..()


	special_desc(dist, mob/user)
		if(isflock(user))
			return {"<span class='flocksay'><span class='bold'>###=-</span> Ident confirmed, data packet received.
			<br><span class='bold'>ID:</span> Matter Reprocessor
			<br><span class='bold'>Volume:</span> [src.reagents.get_reagent_amount(src.target_fluid)]
			<br><span class='bold'>Needed volume:</span> [src.create_egg_at_fluid]
			<br><span class='bold'>###=-</span></span>"}
		else
			return null // give the standard description


