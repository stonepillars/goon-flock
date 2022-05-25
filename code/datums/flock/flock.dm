/////////////////////////////
// FLOCK DATUM
/////////////////////////////

/// associative list of flock names to their flock
/var/list/flocks = list()

/// manages and holds information for a flock
/datum/flock
	var/name
	var/list/all_owned_tiles = list()
	var/list/busy_tiles = list()
	var/list/priority_tiles = list()
	var/list/deconstruct_targets = list()
	var/list/traces = list()
	/// Store a list of all minds who have been flocktraces of this flock at some point, indexed by name
	var/list/trace_minds = list()
	/// Store the mind of the current flockmind
	var/datum/mind/flockmind_mind = null
	/// Stores associative lists of type => list(units) - do not edit directly, use removeDrone() and registerUnit()
	var/list/units = list()
	/// associative list of used names (for traces, drones, and bits) to true values
	var/list/active_names = list()
	var/list/enemies = list()
	///Associative list of objects to an associative list of their annotation names to images
	var/list/annotations = list()
	///Static cache of annotation images
	var/static/list/annotation_imgs = null
	var/list/obj/flock_structure/structures = list()
	var/list/datum/unlockable_flock_structure/unlockableStructures = list()
	///list of strings that lets flock record achievements for structure unlocks
	var/list/achievements = list()
	var/mob/living/intangible/flock/flockmind/flockmind
	var/snoop_clarity = 80 // how easily we can see silicon messages, how easily silicons can see this flock's messages
	var/snooping = FALSE //are both sides of communication currently accessible?
	var/datum/tgui/flockpanel

/datum/flock/New()
	..()
	src.name = src.pick_name("flock")
	flocks[src.name] = src
	processing_items |= src
	for(var/DT in childrentypesof(/datum/unlockable_flock_structure))
		src.unlockableStructures += new DT(src)
	if (!annotation_imgs)
		annotation_imgs = build_annotation_imgs()
	src.units[/mob/living/critter/flock/drone] = list() //this one needs initialising

/datum/flock/ui_status(mob/user)
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
	if (!istype(user, /mob/living/intangible/flock/flockmind))
		return
	switch(action)
		if("jump_to")
			var/atom/movable/origin = locate(params["origin"])
			if(!QDELETED(origin))
				var/turf/T = get_turf(origin)
				if(T.z != Z_LEVEL_STATION)
					boutput(user, "<span class='alert'>They seem to be beyond your capacity to reach.</span>")
				else
					user.set_loc(T)
		if("rally")
			var/mob/living/critter/flock/C = locate(params["origin"])
			if(C?.flock == src) // not sure when it'd apply but in case
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
					boutput(host, "<span class='flocksay'><b>\[SYSTEM: The flockmind has removed you from your previous corporeal shell.\]</b></span>")
					host.release_control()
		if("delete_trace")
			var/mob/living/intangible/flock/trace/T = locate(params["origin"])
			if(T)
				if(tgui_alert(user, "This will destroy the Flocktrace. Are you sure you want to do this?", "Confirmation", list("Yes", "No")) == "Yes")
					var/mob/living/critter/flock/drone/host = T.loc
					if(istype(host))
						host.release_control()
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
	for(var/mob/living/critter/flock/drone/F as anything in src.units[/mob/living/critter/flock/drone])
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
		if(!QDELETED(M))
			var/list/enemy = list()
			enemy["name"] = M.name
			enemy["area"] = enemy_stats["last_seen"]
			enemy["ref"] = "\ref[M]"
			enemylist += list(enemy)
		else
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
	for(var/pathkey in src.units)
		for(var/mob/living/critter/flock/F as anything in src.units[pathkey])
			F.count_healths()
			hp += F.health
			max_hp += F.max_health
	if(max_hp != 0)
		return hp/max_hp
	else
		return 0

/datum/flock/proc/total_resources()
	. = 0
	for(var/mob/living/critter/flock/drone/F as anything in src.units[/mob/living/critter/flock/drone])
		. += F.resources


/datum/flock/proc/total_compute()
	. = 0
	var/comp_provided = 0
	if (src.hasAchieved(FLOCK_ACHIEVEMENT_CHEAT_COMPUTE))
		return 1000000
	for(var/pathkey in src.units)
		for(var/mob/living/critter/flock/F as anything in src.units[pathkey])
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
	for(var/pathkey in src.units)
		for(var/mob/living/critter/flock/F as anything in src.units[pathkey])
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
	src.active_names -= T.real_name
	hideAnnotations(T)
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
		dummy.invisibility = INVIS_FLOCK
		dummy.appearance_flags = PIXEL_SCALE | RESET_TRANSFORM | RESET_COLOR | PASS_MOUSE
		dummy.icon = target.icon
		dummy.icon_state = target.icon_state
		target.render_target = ref(parent)
		dummy.render_source = target.render_target
		dummy.add_filter("outline", 1, outline_filter(size=1,color=src.outline_color))
		if (isturf(target))
			dummy.add_filter("mask", 2, alpha_mask_filter(icon=dummy.icon, flags=MASK_INVERSE))
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

///Init annotation images to copy
/datum/flock/proc/build_annotation_imgs()
	. = list()

	var/image/hazard = image('icons/misc/featherzone.dmi', icon_state = "hazard")
	hazard.blend_mode = BLEND_ADD
	hazard.plane = PLANE_ABOVE_LIGHTING
	hazard.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	hazard.pixel_y = 16
	.[FLOCK_ANNOTATION_HAZARD] = .[FLOCK_ANNOTATION_DECONSTRUCT] = hazard

	var/image/priority = image('icons/misc/featherzone.dmi', icon_state = "frontier")
	priority.appearance_flags = RESET_ALPHA | RESET_COLOR
	priority.alpha = 180
	priority.plane = PLANE_ABOVE_LIGHTING
	priority.mouse_opacity = FALSE
	.[FLOCK_ANNOTATION_PRIORITY] = priority

	var/image/reserved = image('icons/misc/featherzone.dmi', icon_state = "frontier")
	reserved.appearance_flags = RESET_ALPHA | RESET_COLOR
	reserved.alpha = 80
	reserved.plane = PLANE_ABOVE_LIGHTING
	reserved.mouse_opacity = FALSE
	.[FLOCK_ANNOTATION_RESERVED] = reserved

	var/image/flock_face = image('icons/misc/featherzone.dmi', icon_state = "flockmind_face")
	flock_face.blend_mode = BLEND_ADD
	flock_face.plane = PLANE_ABOVE_LIGHTING
	flock_face.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	flock_face.pixel_y = 16
	.[FLOCK_ANNOTATION_FLOCKMIND_CONTROL] = flock_face

	var/image/trace_face = image('icons/misc/featherzone.dmi', icon_state = "flocktrace_face")
	trace_face.blend_mode = BLEND_ADD
	trace_face.plane = PLANE_ABOVE_LIGHTING
	trace_face.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	trace_face.pixel_y = 16
	.[FLOCK_ANNOTATION_FLOCKTRACE_CONTROL] = trace_face

	var/image/health = image('icons/misc/featherzone.dmi', icon_state = "hp-100")
	health.blend_mode = BLEND_ADD
	health.pixel_x = 10
	health.pixel_y = 16
	health.plane = PLANE_ABOVE_LIGHTING
	health.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	.[FLOCK_ANNOTATION_HEALTH] = health

///proc to get the indexed list of annotations on a particular mob
/datum/flock/proc/getAnnotations(atom/target)
	var/active = src.annotations[target]
	if(!islist(active))
		active = list()
		src.annotations[target] = active
	return active

///Toggle a named annotation
/datum/flock/proc/toggleAnnotation(atom/target, var/annotation)
	var/active = getAnnotations(target)
	if (annotation in active)
		removeAnnotation(target, annotation)
	else
		addAnnotation(target, annotation)

///Add a named annotation
/datum/flock/proc/addAnnotation(atom/target, var/annotation)
	var/active = getAnnotations(target)
	if(!(annotation in active))
		var/image/icon = image(src.annotation_imgs[annotation], loc=target)
		if (isturf(target))
			var/turf/T = target
			icon.loc = T.RL_MulOverlay || T
		active[annotation] = icon
		get_image_group(src).add_image(icon)

///Remove a named annotation
/datum/flock/proc/removeAnnotation(atom/target, var/annotation)
	var/active = getAnnotations(target)
	var/image/image = active[annotation]
	if (image)
		get_image_group(src).remove_image(image)
		active -= annotation
		qdel(image)

/datum/flock/proc/showAnnotations(var/mob/M)
	get_image_group(src).add_mob(M)

/datum/flock/proc/hideAnnotations(var/mob/M)
	get_image_group(src).remove_mob(M)

// naming

/datum/flock/proc/pick_name(flock_type)
	var/name
	var/name_found = FALSE
	var/tries = 0
	var/max_tries = 5000 // really shouldn't occur

	while (!name_found && tries < max_tries)
		if (flock_type == "flock")
			name = "[pick(consonants_lower)][pick(vowels_lower)].[pick(consonants_lower)][pick(vowels_lower)]"
			if (!flocks[name])
				name_found = TRUE
		else
			if (flock_type == "flocktrace")
				name = "[pick(consonants_upper)][pick(vowels_lower)].[pick(vowels_lower)]"
			if (flock_type == "flockdrone")
				name = "[pick(consonants_lower)][pick(vowels_lower)].[pick(consonants_lower)][pick(vowels_lower)].[pick(consonants_lower)][pick(vowels_lower)]"
			else if (flock_type == "flockbit")
				name = "[pick(consonants_upper)].[rand(10,99)].[rand(10,99)]"

			if (!src.active_names[name])
				name_found = TRUE
				src.active_names[name] = TRUE
		tries++
	if (!name_found && tries == max_tries)
		logTheThing("debug", null, null, "Too many tries were reached in trying to name a flock or one of its units.")
		return "error"
	return name

// UNITS

/datum/flock/proc/registerUnit(var/mob/living/critter/flock/D, check_name_uniqueness = FALSE)
	if(isflock(D))
		if(!src.units[D.type])
			src.units[D.type] = list()
		src.units[D.type] |= D
		if (check_name_uniqueness && src.active_names[D.real_name])
			D.real_name = istype(D, /mob/living/critter/flock/drone) ? src.pick_name("flockdrone") : src.pick_name("flockbit")
	D.AddComponent(/datum/component/flock_interest, src)
	var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
	aH.updateCompute()

/datum/flock/proc/removeDrone(var/mob/living/critter/flock/D)
	if(isflock(D))
		src.units[D.type] -= D
		src.active_names -= D.real_name
		D.GetComponent(/datum/component/flock_interest)?.RemoveComponent(/datum/component/flock_interest)
		if(D.real_name && busy_tiles[D.real_name])
			src.unreserveTurf(D.real_name)
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()

// TRACES

/datum/flock/proc/getActiveTraces()
	var/list/active_traces = list()
	for (var/mob/living/intangible/flock/trace/T as anything in src.traces)
		if (T.client)
			active_traces += T
		else if (istype(T.loc, /mob/living/critter/flock/drone))
			var/mob/living/critter/flock/drone/flockdrone = T.loc
			if (flockdrone.client)
				active_traces += T
	return active_traces

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
		S.AddComponent(/datum/component/flock_interest, src)
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()

/datum/flock/proc/removeStructure(var/atom/movable/S)
	if(isflockstructure(S))
		var/obj/flock_structure/structure = S
		src.structures -= structure
		structure.GetComponent(/datum/component/flock_interest)?.RemoveComponent(/datum/component/flock_interest)
		structure.flock = null
		var/datum/abilityHolder/flockmind/aH = src.flockmind.abilityHolder
		aH.updateCompute()

/datum/flock/proc/getComplexDroneCount()
	return length(src.units[/mob/living/critter/flock/drone/])

/datum/flock/proc/toggleDeconstructionFlag(var/atom/target)
	toggleAnnotation(target, FLOCK_ANNOTATION_DECONSTRUCT)
	src.deconstruct_targets ^= target

// ENEMIES

/datum/flock/proc/updateEnemy(atom/M)
	if(!M)
		return
	if (isvehicle(M))
		for (var/mob/occupant in M) // making assumption flock knows who everyone in the pod is
			src.updateEnemy(occupant)
	//vehicles can be enemies but drones will only attack them if they are occupied
	if(!isliving(M) && !iscritter(M) && !isvehicle(M))
		return
	var/enemy_name = M
	var/list/enemy_deets
	if(!(enemy_name in src.enemies))
		var/area/enemy_area = get_area(M)
		enemy_deets = list()
		enemy_deets["mob"] = M
		enemy_deets["last_seen"] = enemy_area
		src.enemies[enemy_name] = enemy_deets
		addAnnotation(M, FLOCK_ANNOTATION_HAZARD)
	else
		enemy_deets = src.enemies[enemy_name]
		enemy_deets["last_seen"] = get_area(M)

/datum/flock/proc/removeEnemy(atom/M)
	if(!isliving(M) && !iscritter(M) && !isvehicle(M))
		return
	src.enemies -= M

	removeAnnotation(M, FLOCK_ANNOTATION_HAZARD)

/datum/flock/proc/isEnemy(atom/M)
	var/enemy_name = M
	return (enemy_name in src.enemies)

// DEATH

/datum/flock/proc/perish()
	if(src.flockmind)
		hideAnnotations(src.flockmind)
	for(var/mob/living/intangible/flock/trace/T as anything in src.traces)
		T.death()
	for(var/pathkey in src.units)
		for(var/mob/living/critter/flock/F as anything in src.units[pathkey])
			F.dormantize()
	for(var/obj/flock_structure/S as anything in src.structures)
		src.removeStructure(S)
	qdel(get_image_group(src))
	annotations = null
	all_owned_tiles = null
	busy_tiles = null
	priority_tiles = null
	units = null
	active_names = null
	enemies = null
	flockmind = null
	//while this is neat cleanup, we still need the flock datum for tracking flocktrace mind connections
	// qdel(src)

// TURFS

/datum/flock/proc/reserveTurf(var/turf/simulated/T, var/name)
	if(T in all_owned_tiles)
		return
	if(name in src.busy_tiles)
		return
	src.busy_tiles[name] = T
	addAnnotation(T, FLOCK_ANNOTATION_RESERVED)

/datum/flock/proc/unreserveTurf(var/name)
	var/turf/simulated/T = src.busy_tiles[name]
	src.busy_tiles -= name
	removeAnnotation(T, FLOCK_ANNOTATION_RESERVED)

/datum/flock/proc/claimTurf(var/turf/simulated/T)
	src.all_owned_tiles |= T
	src.priority_tiles -= T
	T.AddComponent(/datum/component/flock_interest, src)
	for(var/obj/O in T.contents)
		if(HAS_ATOM_PROPERTY(O, PROP_ATOM_FLOCK_THING))
			O.AddComponent(/datum/component/flock_interest, src)
		if(istype(O, /obj/flock_structure))
			var/obj/flock_structure/structure = O
			structure.flock = src
			src.registerStructure(structure)
	removeAnnotation(T, FLOCK_ANNOTATION_PRIORITY)

// whether the turf is reserved/being converted or not, will still count as free to provided drone name if they have reserved/are converting it
/datum/flock/proc/isTurfFree(var/turf/simulated/T, var/queryName)
	for(var/name in src.busy_tiles)
		if(name == queryName)
			continue
		if(src.busy_tiles[name] == T)
			return FALSE
	return TRUE

/datum/flock/proc/togglePriorityTurf(var/turf/T)
	if (!T)
		return TRUE
	toggleAnnotation(T, FLOCK_ANNOTATION_PRIORITY)
	priority_tiles ^= T

// get closest unclaimed tile to requester
/datum/flock/proc/getPriorityTurfs(var/mob/living/critter/flock/drone/requester)
	if(!requester)
		return
	if(src.busy_tiles[requester.name])
		return src.busy_tiles[requester.name]
	if(length(priority_tiles))
		var/list/available_tiles = priority_tiles
		for(var/owner in src.busy_tiles)
			available_tiles -= src.busy_tiles[owner]
		return available_tiles

// PROCESS

/datum/flock/proc/process()
	var/list/floors_no_longer_existing = list()

	for(var/turf/simulated/floor/feather/T in src.all_owned_tiles)
		if(!T || T.loc == null || T.broken)
			floors_no_longer_existing |= T
			continue

	if(length(floors_no_longer_existing))
		src.all_owned_tiles -= floors_no_longer_existing

	for(var/datum/unlockable_flock_structure/ufs as anything in src.unlockableStructures)
		ufs.process()

	var/turf/busy_turf
	for(var/name in src.busy_tiles)
		busy_turf = src.busy_tiles[name]
		if (QDELETED(busy_turf))
			src.unreserveTurf(busy_turf)

	for(var/turf/T in src.priority_tiles)
		if (QDELETED(T))
			src.togglePriorityTurf(T)

	for(var/atom/S in src.deconstruct_targets)
		if(QDELETED(S))
			src.toggleDeconstructionFlag(S)

	var/atom/M
	for(var/enemy in src.enemies)
		M = src.enemies[enemy]["mob"]
		if (QDELETED(M))
			src.removeEnemy(M)

/datum/flock/proc/convert_turf(var/turf/T, var/converterName)
	src.unreserveTurf(converterName)
	src.claimTurf(flock_convert_turf(T))
	playsound(T, "sound/items/Deconstruct.ogg", 40, 1)

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
	/obj/window = /obj/window/auto/feather,
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
	/obj/machinery/networked/mainframe = /obj/flock_structure/compute/mainframe,
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
		T.ReplaceWith("/turf/simulated/floor/feather", FALSE)
		animate_flock_convert_complete(T)

	if(istype(T, /turf/simulated/wall))
		T.ReplaceWith("/turf/simulated/wall/auto/feather", FALSE)
		animate_flock_convert_complete(T)

	// regular and flock lattices
	var/obj/lattice/lat = locate(/obj/lattice) in T
	if(lat)
		qdel(lat)
		T.ReplaceWith("/turf/simulated/floor/feather", FALSE)
		animate_flock_convert_complete(T)

	var/obj/grille/catwalk/catw = locate(/obj/grille/catwalk) in T
	if(catw)
		qdel(catw)
		T.ReplaceWith("/turf/simulated/floor/feather", FALSE)
		animate_flock_convert_complete(T)

	if(istype(T, /turf/space))
		var/obj/lattice/flock/FL = locate(/obj/lattice/flock) in T
		if(!FL)
			FL = new /obj/lattice/flock(T)
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
						animate_flock_convert_complete(converted)
					break //we found and converted the type, don't convert it again


	return T

/proc/mass_flock_convert_turf(var/turf/T, datum/flock/F)
	if(!T)
		T = get_turf(usr)
	if(!T)
		return

	flock_spiral_conversion(T, F)

/proc/radial_flock_conversion(var/atom/movable/source, datum/flock/F, var/max_radius=20)
	if(!source) return
	var/turf/T = get_turf(source)
	var/radius = 1
	while(radius <= max_radius)
		var/list/turfs = circular_range(T, radius)
		LAGCHECK(LAG_LOW)
		for(var/turf/tile in turfs)
			if(istype(tile, /turf/simulated) && !isfeathertile(tile))
				if (F)
					F.claimTurf(flock_convert_turf(tile))
				else
					flock_convert_turf(tile)
				sleep(0.5)
		LAGCHECK(LAG_LOW)
		radius++
		sleep(radius * 10)
		if(isnull(source))
			return


/proc/flock_spiral_conversion(var/turf/T, datum/flock/F)
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
			if (F)
				F.claimTurf(flock_convert_turf(T))
			else
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


