/obj/artifactclamp
	name = "artifact clamp"
	desc = "This is an artifact clamp used for securing large artifacts to the floor."
	flags = FPRINT | NOSPLASH | FLUID_SUBMERGE
	event_handler_flags = USE_FLUID_ENTER | USE_CHECKEXIT | NO_MOUSEDROP_QOL
	icon = 'icons/obj/artifacts/artifactclamp.dmi'
	icon_state = "deactivated"
	anchored = FALSE
	density = 1
	//density = 0
	throwforce = 50
	mouse_drag_pointer = MOUSE_ACTIVE_POINTER
	p_class = 2.5
	var/icon_deactivated = "deactivated"
	var/icon_activated = "activated"

	var/stage = 0 // 0 - nothing, 1 - stuck to floor, no artifact, 2 - stuck to floor, artifact clamped

	New()
		..()
		START_TRACKING
		SPAWN_DBG(1 DECI SECOND)
			src.UpdateIcon()

	disposing()
		STOP_TRACKING
		..()

	update_icon()
		if (src.stage != 3)
			src.icon_state = src.icon_deactivated
		else
			src.icon_state = src.icon_activated

	alter_health()
		. = get_turf(src)

	attack_hand(mob/user as mob)
		if (!in_interact_range(src, user))
			return

		//interact_particle(user, src)
		add_fingerprint(user)
		return src.Attackby(null, user)

	attackby(obj/item/W as obj, mob/user as mob)
		switch(stage)
			if (0)
				if (iswrenchingtool(W))
					playsound(src.loc, "sound/items/Ratchet.ogg", 50, 1)
					user.show_text("You tighten the artifact clamp's magnetic floor bolts!", "red")
					anchored = TRUE
					stage = 1
					return

			if (1)
				if (isscrewingtool(W))
					if (src.artifact_over())
						playsound(src.loc, "sound/items/Screwdriver.ogg", 50, 1)
						user.show_text("You activate the artifact clamp's artifact tether systems!", "red")
						var/obj/O = src.get_artifact_over()
						O.anchored = TRUE
						stage = 2
						icon_state = src.icon_activated
						logTheThing("station", user, src, "[user] secured an active artifact to the floor with [src].")
						return
					else
						user.show_text("You can't activate the artifact clamp's artifact tether systems without an artifact to secure!", "red")
						return

				if (iswrenchingtool(W))
					playsound(src.loc, "sound/items/Ratchet.ogg", 50, 1)
					user.show_text("You loosen the artifact clamp's magnetic floor bolts!", "red")
					anchored = FALSE
					stage = 0
					return

			if (2)
				if (isscrewingtool(W))
					playsound(src.loc, "sound/items/Screwdriver.ogg", 50, 1)
					user.show_text("You deactivate the artifact clamp's artifact tether systems!", "red")
					var/obj/O = src.get_artifact_over()
					O.anchored = FALSE
					stage = 1
					icon_state = src.icon_deactivated
					logTheThing("station", user, src, "[user] unsecured an active artifact to the floor with [src].")
					return
		src.update_icon()
		return ..()

	MouseDrop_T(atom/movable/O as mob|obj, mob/user as mob)
		if (!in_interact_range(user, src) || !in_interact_range(user, O) || user.restrained() || user.getStatusDuration("paralysis") || user.sleeping || user.stat || user.lying || isAI(user))
			return

		if (!((istype(O, /obj/machinery/artifact) || istype(O, /obj/artifact)) && !O.anchored))
			return

		if (src.stage == 0)
			user.show_text("The floor bolts are not yet secured!", "red")
			return

		if (src.stage == 3)
			user.show_text("The tether systems are active!", "red")
			return

		var/obj/art = O

		var/datum/artifact/A = art.artifact

		if (!A.activated)
			user.show_text("Only activated artifacts will work with a clamp!", "red")
			return

		src.add_fingerprint(user)
		O.add_fingerprint(user)
		O.set_loc(src.loc)

		return ..()

	attack_ai(mob/user)
		if (can_reach(user, src) <= 1 && (isrobot(user) || isshell(user)))
			. = src.Attackhand(user)

	alter_health()
		. = get_turf(src)

	Cross(atom/movable/mover)
		if(istype(mover, /obj/projectile))
			return 1
		return ..()

	CheckExit(atom/movable/O as mob|obj, target as turf)
		if(istype(O, /obj/projectile))
			return 1
		return ..()

	ex_act(severity)
		switch (severity)
			if (1)
				qdel(src)
			if (2)
				if (prob(50))
					qdel(src)
			if (3)
				if (prob(5))
					qdel(src)

	blob_act(var/power)
		if (prob(power * 2.5))
			qdel(src)

	meteorhit(obj/O as obj)
		qdel(src)
		return

	proc/artifact_over()
		var/turf/T = get_turf(src)
		for(var/obj/O in T.contents)
			if (istype(O, /obj/machinery/artifact) || istype(O, /obj/artifact))
				return TRUE
		return FALSE

	proc/get_artifact_over()
		var/turf/T = get_turf(src)
		for(var/obj/O in T.contents)
			if (istype(O, /obj/machinery/artifact) || istype(O, /obj/artifact))
				return O
