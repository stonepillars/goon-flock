// flockdrone stuff, ask cirr or do a search for "flockdrone"

/////////////////////////////
// FLOCK DATUM
/////////////////////////////
// used to manage and share information between members of a flock/nest
/var/list/flocks = list()
/datum/flock
	var/name
	var/list/all_owned_tiles = list()
	var/list/busy_tiles = list()
	var/list/priority_tiles = list()
	var/list/deconstruct_targets = list()
	var/list/traces = list()
	var/list/units = list()
	var/list/enemies = list()
	var/list/annotation_viewers = list()
	var/list/annotations_busy_tiles = list()  // key is atom ref, value is image
	var/list/annotations_priority_tiles = list()
	var/list/annotations_enemies = list()
	var/list/obj/flock_structure/structures = list()
	var/list/datum/unlockable_flock_structure/unlockableStructures = list()
	///list of strings that lets flock record achievements for structure unlocks
	var/list/achievements = list()
	var/mob/living/intangible/flock/flockmind/flockmind
	var/snoop_clarity = 80 // how easily we can see silicon messages, how easily silicons can see this flock's messages
	var/snooping = 0 //are both sides of communication currently accessible?
	var/datum/tgui/flockpanel

/datum/flock/New()
	..()
	src.name = "[pick(consonants_lower)][pick(vowels_lower)].[pick(consonants_lower)][pick(vowels_lower)]"
	flocks[src.name] = src
	processing_items |= src
	for(var/DT in childrentypesof(/datum/unlockable_flock_structure))
		src.unlockableStructures += new DT(src)

/datum/flock/ui_status(mob/user)
	// only flockminds and admins allowed
	return istype(user, /mob/living/intangible/flock/flockmind) || tgui_admin_state.can_use_topic(src, user)

/datum/flock/ui_data(mob/user)
	return describe_state()

/datum/flock/ui_interact(mob/user, datum/tgui/ui)
	ui = tgui_process.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "FlockPanel")
		ui.open()

/datum/flock/ui_act(action, list/params, datum/tgui/ui)
	var/mob/user = ui.user;
	if (!istype(user, /mob/living/intangible/flock/flockmind)) //no humans allowed
		return
	switch(action)
		if("jump_to")
			var/atom/movable/origin = locate(params["origin"])
			if(origin)
				var/turf/T = get_turf(origin)
				if(T.z != Z_LEVEL_STATION)
					// make sure they're not trying to spoof data and jump into a z-level they ought not to go
					boutput(user, "<span class='alert'>They seem to be beyond your capacity to reach.</span>")
				else
					user.set_loc(T)
		if("rally")
			var/mob/living/critter/flock/C = locate(params["origin"])
			if(C?.flock == src) // no ordering other flocks' drones around
				C.rally(get_turf(user))
		if("remove_enemy")
			var/mob/living/E = locate(params["origin"])
			if(E)
				src.removeEnemy(E)
		if("eject_trace")
			var/mob/living/intangible/flock/trace/T = locate(params["origin"])
			if(T)
				var/mob/living/critter/flock/drone/host = T.loc
				if(istype(host))
					// kick them out of the drone
					boutput(host, "<span class='flocksay'><b>\[SYSTEM: The flockmind has removed you from your previous corporeal shell.\]</b></span>")
					host.release_control()
		if("delete_trace")
			var/mob/living/intangible/flock/trace/T = locate(params["origin"])
			if(T)
				if(tgui_alert(user, "This will destroy the Flocktrace. Are you sure you want to do this?", "Confirmation", list("Yes", "No")) == "Yes")
					// if they're in a drone, kick them out
					var/mob/living/critter/flock/drone/host = T.loc
					if(istype(host))
						host.release_control()
					// DELETE
					flock_speak(null, "Partition [T.real_name] has been reintegrated into flock background processes.", src)
					boutput(T, "<span class='flocksay'><b>\[SYSTEM: Your higher cognition has been forcibly reintegrated into the collective will of the flock.\]</b></span>")
					T.death()
		if ("cancel_tealprint")
			var/obj/flock_structure/ghost/tealprint = locate(params["origin"])
			if (tealprint)
				tealprint.cancelBuild()

/datum/flock/proc/describe_state()
	var/list/state = list()
	state["update"] = "flock"

	// DESCRIBE TRACES
	var/list/tracelist = list()
	for(var/mob/living/intangible/flock/trace/T as anything in src.traces)
		tracelist += list(T.describe_state())
	state["partitions"] = tracelist

	// DESCRIBE DRONES
	var/list/dronelist = list()
	for(var/mob/living/critter/flock/drone/F in src.units)
		dronelist += list(F.describe_state())
	state["drones"] = dronelist

	// DESCRIBE STRUCTURES
	var/list/structureList = list()
	for(var/obj/flock_structure/structure as anything in src.structures)
		structureList += list(structure.describe_state())
	state["structures"] = structureList

	// DESCRIBE ENEMIES
	var/list/enemylist = list()
	for(var/name in src.enemies)
		var/list/enemy_stats = src.enemies[name]
		var/atom/M = enemy_stats["mob"]
		if(M)
			var/list/enemy = list()
			enemy["name"] = M.name
			enemy["area"] = enemy_stats["last_seen"]
			enemy["ref"] = "\ref[M]"
			enemylist += list(enemy)
		else
			// enemy no longer exists, let's do something about that
			src.enemies -= name
	state["enemies"] = enemylist

	// DESCRIBE VITALS
	var/list/vitals = list()
	vitals["name"] = src.name
	state["vitals"] = vitals

	return state

/datum/flock/disposing()
	flocks[src.name] = null
	processing_items -= src
	..()

/datum/flock/proc/total_health_percentage()
	var/hp = 0
	var/max_hp = 0
	for(var/mob/living/critter/flock/F as anything in src.units)
		F.count_healths()
		hp += F.health
		max_hp += F.max_health
	if(max_hp != 0)
		return hp/max_hp
	else
		return 0

/datum/flock/proc/total_resources()
	. = 0
	for(var/mob/living/critter/flock/F as anything in src.units)
		. += F.resources


/datum/flock/proc/total_compute()
	. = 0
	var/comp_provided = 0
	if (src.hasAchieved("infinite_compute"))
		return 1000000
	for(var/mob/living/critter/flock/F as anything in src.units)
		comp_provided = F.compute_provided()
		if(comp_provided>0)
			. += comp_provided

	for(var/obj/flock_structure/S as anything in src.structures)
		comp_provided = S.compute_provided()
		if(comp_provided>0)
			. += comp_provided


/datum/flock/proc/used_compute()
	. = 0
	var/comp_provided = 0
	for(var/mob/living/critter/flock/F as anything in src.units)
		comp_provided = F.compute_provided()
		if(comp_provided<0)
			. += abs(comp_provided)

	for(var/obj/flock_structure/S as anything in src.structures)
		comp_provided = S.compute_provided()
		if(comp_provided<0)
			. += abs(comp_provided)

	//not strictly necessary, but maybe future traces can provide compute in some way or cost more when doing stuff?
	for(var/mob/living/intangible/flock/trace/T as anything in src.traces)
		comp_provided = T.compute_provided()
		if(comp_provided<0)
			. += abs(comp_provided)

/datum/flock/proc/can_afford_compute(var/cost)
	return (cost <= src.total_compute() - src.used_compute())

/datum/flock/proc/registerFlockmind(var/mob/living/intangible/flock/flockmind/F)
	if(!F)
		return
	src.flockmind = F

//since flocktraces need to be given their flock in New this is useful for debug
/datum/flock/proc/spawnTrace()
	var/mob/living/intangible/flock/trace/T = new(usr.loc, src)
	return T

/datum/flock/proc/addTrace(var/mob/living/intangible/flock/trace/T)
	if(!T)
		return
	src.traces |= T
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH?.updateCompute()

/datum/flock/proc/removeTrace(var/mob/living/intangible/flock/trace/T)
	if(!T)
		return
	src.traces -= T
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH?.updateCompute()

/datum/flock/proc/ping(var/atom/target, var/mob/living/intangible/flock/pinger)
	//awful typecheck because turfs and movables have vis_contents defined seperately because god hates us
	if (!istype(pinger) || (!istype(target, /atom/movable) && !istype(target, /turf)))
		return

	target.AddComponent(/datum/component/flock_ping)

	for (var/mob/living/intangible/flock/F in (src.traces + src.flockmind))
		if (F != pinger)
			var/image/arrow = image(icon = 'icons/mob/screen1.dmi', icon_state = "arrow", loc = F, layer = HUD_LAYER)
			arrow.color = "#00ff9dff"
			arrow.pixel_y = 20
			arrow.transform = matrix(arrow.transform, 2,2, MATRIX_SCALE)
			var/angle = 180 + get_angle(F, target)
			arrow.transform = matrix(arrow.transform, angle, MATRIX_ROTATE)
			F.client?.images += arrow
			animate(arrow, time = 3 SECONDS, alpha = 0)
			SPAWN(3 SECONDS)
				F.client?.images -= arrow
				qdel(arrow)
		var/class = "flocksay ping [istype(F, /mob/living/intangible/flock/flockmind) ? "flockmindsay" : ""]"
		var/prefix = "<span class='bold'>\[[src.name]\] </span><span class='name'>[pinger.name]</span>"
		boutput(F, "<span class='[class]'><a href='?src=\ref[F];origin=\ref[target];ping=[TRUE]'>[prefix]: Interrupt request, target: [target] in [get_area(target)].</a></span>")
	playsound_global(src.traces + src.flockmind, "sound/misc/flockmind/ping.ogg", 50, 0.5)

//is this a weird use case for components? probably, but it's kinda neat
/datum/component/flock_ping
	dupe_mode = COMPONENT_DUPE_UNIQUE

	var/const/duration = 5 SECOND
	var/end_time = -1
	var/obj/dummy = null
	var/outline_color = "#00ff9d"

	Initialize()
		if (!ismovable(parent) && !isturf(parent))
			return COMPONENT_INCOMPATIBLE

	RegisterWithParent()
		//this cast looks horribly unsafe, but we've guaranteed that parent is a type with vis_contents in Initialize
		var/atom/movable/target = parent

		src.end_time = TIME + duration

		dummy = new()
		dummy.layer = target.layer
		dummy.plane = PLANE_FLOCKVISION
		dummy.invisibility = INVIS_FLOCKMIND
		dummy.appearance_flags = PIXEL_SCALE | RESET_TRANSFORM | RESET_COLOR | PASS_MOUSE
		dummy.icon = target.icon
		dummy.icon_state = target.icon_state
		target.render_target = ref(parent)
		dummy.render_source = target.render_target
		dummy.add_filter("outline", 1, outline_filter(size=1,color=src.outline_color))
		target.vis_contents += dummy

		play_animation()

		SPAWN(0)
			while(TIME < src.end_time)
				var/delta = src.end_time - TIME
				sleep(min(src.duration, delta))
			qdel(src)

	//when a new ping component is added, reset the original's duration
	InheritComponent(datum/component/flock_ping/C, i_am_original)
		if (i_am_original)
			play_animation()
			src.end_time = TIME + duration

	disposing()
		qdel(dummy)
		. = ..()

	proc/play_animation()
		animate(dummy, time = duration/9, alpha = 100)
		for (var/i in 1 to 4)
			animate(time = duration/9, alpha = 255)
			animate(time = duration/9, alpha = 100)
// ANNOTATIONS

// currently both flockmind and player units get the same annotations: what tiles are marked for conversion, and who is shitlisted
/datum/flock/proc/showAnnotations(var/mob/M)
	if(!M)
		return
	src.annotation_viewers |= M
	var/client/C = M.client
	if(C)
		for(var/atom/key in src.annotations_priority_tiles)
			C.images |= src.annotations_priority_tiles[key]
		for(var/atom/key in src.annotations_busy_tiles)
			C.images |= src.annotations_busy_tiles[key]
		for(var/atom/key in src.annotations_enemies)
			C.images |= src.annotations_enemies[key]

/datum/flock/proc/hideAnnotations(var/mob/M)
	if(!M)
		return
	src.annotation_viewers -= M
	var/client/C = M.client
	if(C)
		for(var/atom/key in src.annotations_priority_tiles)
			C.images -= src.annotations_priority_tiles[key]
		for(var/atom/key in src.annotations_busy_tiles)
			C.images -= src.annotations_busy_tiles[key]
		for(var/atom/key in src.annotations_enemies)
			C.images -= src.annotations_enemies[key]

/datum/flock/proc/addClientImage(image/I)
	for (var/mob/M in src.annotation_viewers)
		M.client?.images += I

/datum/flock/proc/removeClientImage(image/I)
	for (var/mob/M in src.annotation_viewers)
		M.client?.images -= I

// UNITS

/datum/flock/proc/registerUnit(var/atom/movable/D)
	if(isflock(D))
		src.units |= D
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH.updateCompute()

/datum/flock/proc/removeDrone(var/atom/movable/D)
	if(isflock(D))
		src.units -= D

		if(D:real_name && busy_tiles[D:real_name])
			src.busy_tiles[D:real_name] = null
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()
// STRUCTURES

///This function only notifies the flock of the unlock, actual unlock logic is handled in the datum
/datum/flock/proc/notifyUnlockStructure(var/datum/unlockable_flock_structure/SD)
	flock_speak(null, "New structure devised: [SD.friendly_name]", src)

///This function only notifies the flock of the relock, actual unlock logic is handled in the datum
/datum/flock/proc/notifyRelockStructure(var/datum/unlockable_flock_structure/SD)
	flock_speak(null, "Alert, structure tealprint disabled: [SD.friendly_name]", src)

/datum/flock/proc/registerStructure(var/atom/movable/S)
	if(isflockstructure(S))
		src.structures |= S
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()

/datum/flock/proc/removeStructure(var/atom/movable/S)
	if(isflockstructure(S))
		src.structures -= S
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()

/datum/flock/proc/getComplexDroneCount()
	var/count = 0
	for(var/mob/living/critter/flock/drone/D in src.units)
		count++
	return count

// ENEMIES

/datum/flock/proc/updateEnemy(atom/M)
	if(!M)
		return
	if(!isliving(M) && !iscritter(M))
		return
	var/enemy_name = M
	var/list/enemy_deets
	if(!(enemy_name in src.enemies))
		// add new
		var/area/enemy_area = get_area(M)
		enemy_deets = list()
		enemy_deets["mob"] = M
		enemy_deets["last_seen"] = enemy_area
		src.enemies[enemy_name] = enemy_deets
	else
		enemy_deets = src.enemies[enemy_name]
		enemy_deets["last_seen"] = get_area(M)
	if (!(M in src.annotations_enemies))
		var/image/I = image('icons/misc/featherzone.dmi', M, "hazard")
		I.blend_mode = BLEND_ADD
		I.pixel_y = 16
		I.plane = PLANE_ABOVE_LIGHTING
		I.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
		src.annotations_enemies[M] = I
		src.addClientImage(I)

/datum/flock/proc/removeEnemy(atom/M)
	// call off all drones attacking this guy
	if(!isliving(M) && !iscritter(M))
		return
	src.enemies -= M

	var/image/I = src.annotations_enemies[M]
	src.annotations_enemies -= M
	src.removeClientImage(I)

/datum/flock/proc/isEnemy(atom/M)
	var/enemy_name = M
	return (enemy_name in src.enemies)

// DEATH

/datum/flock/proc/perish()
	//cleanup as necessary
	if(src.flockmind)
		hideAnnotations(src.flockmind)
	for(var/mob/M in src.units)
		hideAnnotations(M)
	all_owned_tiles = null
	busy_tiles = null
	priority_tiles = null
	units = null
	enemies = null
	annotations_busy_tiles = null
	annotations_priority_tiles = null
	annotations_enemies = null
	flockmind = null
	qdel(src)

// TURFS

/datum/flock/proc/reserveTurf(var/turf/simulated/T, var/name)
	if(T in all_owned_tiles)
		return
	if(name in src.busy_tiles)
		return
	src.busy_tiles[name] = T

	var/image/I = image('icons/misc/featherzone.dmi', T.RL_MulOverlay ? T.RL_MulOverlay : T, "frontier")
	I.appearance_flags = RESET_ALPHA | RESET_COLOR
	I.alpha = 80
	I.plane = PLANE_ABOVE_LIGHTING
	I.mouse_opacity = FALSE
	src.annotations_busy_tiles[T] = I
	src.addClientImage(I)

/datum/flock/proc/unreserveTurf(var/name)
	var/turf/simulated/T = src.busy_tiles[name]
	src.busy_tiles -= name

	var/image/I = src.annotations_busy_tiles[T]
	src.annotations_busy_tiles -= T
	src.removeClientImage(I)

/datum/flock/proc/claimTurf(var/turf/simulated/T)
	src.all_owned_tiles |= T
	src.priority_tiles -= T
	for (var/obj/flock_structure/structure in T.contents)
		structure.flock = src
		src.registerStructure(structure)

	var/image/I = src.annotations_priority_tiles[T]
	src.annotations_priority_tiles -= T
	src.removeClientImage(I)

/datum/flock/proc/isTurfFree(var/turf/simulated/T, var/queryName) // provide the drone's name here: if they own the turf it's free _to them_
	for(var/name in src.busy_tiles)
		if(name == queryName)
			continue
		if(src.busy_tiles[name] == T)
			return 0
	return 1

/datum/flock/proc/togglePriorityTurf(var/turf/T)
	if(!T)
		return TRUE
	var/image/I
	if(T in priority_tiles)
		priority_tiles -= T

		I = src.annotations_priority_tiles[T]
		src.annotations_priority_tiles -= T
		src.removeClientImage(I)
	else
		priority_tiles |= T

		I = image('icons/misc/featherzone.dmi', T.RL_MulOverlay ? T.RL_MulOverlay : T, "frontier")
		I.appearance_flags = RESET_ALPHA | RESET_COLOR
		I.alpha = 180
		I.plane = PLANE_ABOVE_LIGHTING
		I.mouse_opacity = FALSE
		src.annotations_priority_tiles[T] = I
		src.addClientImage(I)

// get closest unclaimed tile to requester
/datum/flock/proc/getPriorityTurfs(var/mob/living/critter/flock/drone/requester)
	if(!requester)
		return
	if(src.busy_tiles[requester.name])
		return src.busy_tiles[requester.name] // work on your claimed tile first you JERK
	if(length(priority_tiles))
		var/list/available_tiles = priority_tiles
		for(var/owner in src.busy_tiles)
			available_tiles -= src.busy_tiles[owner]
		return available_tiles

// PROCESS

/datum/flock/proc/process()
	var/list/floors_no_longer_existing = list()
	// check all active floors
	for(var/turf/simulated/floor/feather/T in src.all_owned_tiles)
		if(!T || T.loc == null || T.broken)
			// tile got killed, remove it
			floors_no_longer_existing |= T
			continue

	if(floors_no_longer_existing.len > 0)
		src.all_owned_tiles -= floors_no_longer_existing

	for(var/datum/unlockable_flock_structure/ufs as anything in src.unlockableStructures)
		ufs.process()

	//handle deconstruct targets being destroyed by other means
	for(var/atom/S in src.deconstruct_targets)
		if(S.disposed)
			src.deconstruct_targets -= S

/datum/flock/proc/convert_turf(var/turf/T, var/converterName)
	src.unreserveTurf(converterName)
	src.claimTurf(flock_convert_turf(T))
	playsound(T, "sound/items/Deconstruct.ogg", 70, 1)

///Unlock an achievement (string) if it isn't already unlocked
/datum/flock/proc/achieve(var/str)
	src.achievements |= str
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH?.updateCompute()

/datum/flock/proc/unAchieve(var/str)
	src.achievements -= str
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH?.updateCompute()

///Unlock an achievement (string) if it isn't already unlocked
/datum/flock/proc/hasAchieved(var/str)
	return (str in src.achievements)
////////////////////
// GLOBAL PROCS!!
////////////////////

// made into a global proc so a reagent can use it
// simple enough: if object path matches key, replace with instance of value
// if value is null, just delete object
// !!!! priority is determined by list order !!!!
// if you have a subclass, it MUST go first in the list, or the first type that matches will take priority (ie, the superclass)
// see /obj/machinery/light/small/floor and /obj/machinery/light for examples of this
/var/list/flock_conversion_paths = list(
	/obj/grille/steel = /obj/grille/flock,
	/obj/window = /obj/window/feather,
	/obj/machinery/door/airlock = /obj/machinery/door/feather,
	/obj/machinery/door = null,
	/obj/stool = /obj/stool/chair/comfy/flock,
	/obj/table = /obj/table/flock/auto,
	/obj/machinery/light/small/floor = /obj/machinery/light/flock/floor,
	/obj/machinery/light = /obj/machinery/light/flock,
	/obj/storage/closet = /obj/storage/closet/flock,
	/obj/storage/secure/closet = /obj/storage/closet/flock,
	/obj/machinery/computer3 = /obj/flock_structure/compute,
	/obj/machinery/computer = /obj/flock_structure/compute,
	/obj/machinery/networked/teleconsole = /obj/flock_structure/compute,
	)

/proc/flock_convert_turf(var/turf/T)
	if(!T)
		return

	// take light values to copy over
	var/RL_LumR = T.RL_LumR
	var/RL_LumG = T.RL_LumG
	var/RL_LumB = T.RL_LumB
	var/RL_AddLumR = T.RL_AddLumR
	var/RL_AddLumG = T.RL_AddLumG
	var/RL_AddLumB = T.RL_AddLumB

	if(istype(T, /turf/simulated/floor))
		if(istype(T, /turf/simulated/floor/feather))
			// fix instead of replace
			var/turf/simulated/floor/feather/TF = T
			TF.repair()
			animate_flock_convert_complete(T)
		else
			T.ReplaceWith("/turf/simulated/floor/feather", 0)
			animate_flock_convert_complete(T)

	if(istype(T, /turf/simulated/wall))
		var/turf/converted_wall = T.ReplaceWith("/turf/simulated/wall/auto/feather", 0)
		animate_flock_convert_complete(T)
		APPLY_ATOM_PROPERTY(converted_wall, PROP_ATOM_FLOCK_THING, "flock_convert_turf")

	// regular and flock lattices
	var/obj/lattice/lat = locate(/obj/lattice) in T
	if(lat)
		qdel(lat)
		T.ReplaceWith("/turf/simulated/floor/feather", 0)
		animate_flock_convert_complete(T)

	var/obj/grille/catwalk/catw = locate(/obj/grille/catwalk) in T
	if(catw)
		qdel(catw)
		T.ReplaceWith("/turf/simulated/floor/feather", 0)
		animate_flock_convert_complete(T)

	if(istype(T, /turf/space))
		var/obj/lattice/flock/FL = locate(/obj/lattice/flock) in T
		if(!FL)
			FL = new /obj/lattice/flock(T) //may as well reuse the var
			APPLY_ATOM_PROPERTY(FL, PROP_ATOM_FLOCK_THING, "flock_convert_turf")
	else // don't do this stuff if the turf is space, it fucks it up more
		T.RL_Cleanup()
		T.RL_LumR = RL_LumR
		T.RL_LumG = RL_LumG
		T.RL_LumB = RL_LumB
		T.RL_AddLumR = RL_AddLumR
		T.RL_AddLumG = RL_AddLumG
		T.RL_AddLumB = RL_AddLumB
		if (RL_Started) RL_UPDATE_LIGHT(T)

	for(var/obj/O in T)
		if(istype(O, /obj/machinery/door/feather))
			// repair door
			var/obj/machinery/door/feather/door = O
			door.heal_damage()
			animate_flock_convert_complete(O)
		else
			for(var/keyPath in flock_conversion_paths) //types are converted with priority determined by list order
				var/obj/replacementPath = flock_conversion_paths[keyPath] //put subclasses ahead of superclasses in the flock_conversion_paths list
				if(istype(O, keyPath))
					if(isnull(replacementPath))
						qdel(O)
					else
						var/dir = O.dir
						var/obj/converted = new replacementPath(T)
						// if the object is a closet, it might not have spawned its contents yet
						// so force it to do that first
						if(istype(O, /obj/storage))
							var/obj/storage/S = O
							if(!isnull(S.spawn_contents))
								S.make_my_stuff()
						// if the object has contents, move them over!!
						for (var/obj/OO in O)
							OO.set_loc(converted)
						for (var/mob/M in O)
							M.set_loc(converted)
						qdel(O)
						converted.set_dir(dir)
						APPLY_ATOM_PROPERTY(converted, PROP_ATOM_FLOCK_THING, "flock_convert_turf")
						animate_flock_convert_complete(converted)
					break //we found and converted the type, don't convert it again


	return T

/proc/mass_flock_convert_turf(var/turf/T)
	// a terrible idea
	if(!T)
		T = get_turf(usr)
	if(!T)
		return // not sure if this can happen, so it will

	flock_spiral_conversion(T)

/proc/radial_flock_conversion(var/atom/movable/source, var/max_radius=20)
	if(!source) return
	var/turf/T = get_turf(source)
	var/radius = 1
	while(radius <= max_radius)
		var/list/turfs = circular_range(T, radius)
		LAGCHECK(LAG_LOW)
		for(var/turf/tile in turfs)
			if(istype(tile, /turf/simulated) && !isfeathertile(tile))
				flock_convert_turf(tile)
				sleep(0.5)
		LAGCHECK(LAG_LOW)
		radius++
		sleep(radius * 10)
		if(isnull(source))
			return // our source is gone, stop the process


/proc/flock_spiral_conversion(var/turf/T)
	if(!T) return
	// spiral algorithm adapted from https://stackoverflow.com/questions/398299/looping-in-a-spiral
	var/ox = T.x
	var/oy = T.y
	var/x = 0
	var/y = 0
	var/z = T.z
	var/dx = 0
	var/dy = -1
	var/temp = 0

	while(isturf(T))
		if(istype(T, /turf/simulated) && !isfeathertile(T))
			// do stuff to turf
			flock_convert_turf(T)
			sleep(0.2 SECONDS)
		LAGCHECK(LAG_LOW)
		// figure out where next turf is
		if (x == y || (x < 0 && x == -y) || (x > 0 && x == 1-y))
			temp = dx
			dx = -dy
			dy = temp
		x += dx
		y += dy
		// get next turf
		T = locate(ox + x, oy + y, z)


