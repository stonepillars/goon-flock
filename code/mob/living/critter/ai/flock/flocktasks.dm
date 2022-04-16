// base shared flock AI stuff
// main default "what do we do next" task, run for one tick and then switches to a new task
/datum/aiHolder/flock
//task priorities and preconditions at a glance:
/*
replicate
	-weight 7
	-precondition: can_afford(100)

nest
	-weight 6
	-precondition: can_afford(100)

building
	-weight 5
	-precondition: can_afford(20)

building/drone
	-weight 1
	-precondition: can_afford(20)

repair
	-weight 4
	-precondition: can_afford(10)

deposit
	-weight 8
	-procondition: can_afford(10)

open_container
	-weight 3
	-precondition: none

rumage
	-weight 3
	precondition: none

harvest
	-weight 2
	precondition: none

shooting
	-weight 10

capture
	-weight 15
	-precondition: can_afford(15)

butcher
	-weight 3

*/

/datum/aiTask/prioritizer/flock
	name = "base thinking (should never see this)"

/datum/aiTask/prioritizer/flock/New()
	..()

/datum/aiTask/prioritizer/flock/on_tick()
	if(isdead(holder.owner))
		holder.enabled = FALSE
		walk(holder.owner, 0) // STOP RUNNING AROUND YOU'RE SUPPOSED TO BE DEAD

/datum/aiTask/prioritizer/flock/on_reset()
	..()
	walk(holder.owner, 0)

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// RALLY TO GOAL
// target: the rally target given when this is invoked
// precondition: none, this is an override
/datum/aiTask/sequence/goalbased/rally
	name = "rallying"
	weight = 0
	can_be_adjacent_to_target = FALSE
	max_dist = 0
// most of the functionality here is already in the base goalbased task, we only want movement

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// REPLICATION GOAL
// targets: valid nesting sites
// precondition: 100 resources
/datum/aiTask/sequence/goalbased/replicate
	name = "replicating"
	weight = 7
	can_be_adjacent_to_target = FALSE

/datum/aiTask/sequence/goalbased/replicate/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/replicate, list(holder)))

/datum/aiTask/sequence/goalbased/replicate/precondition()
	. = FALSE
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F?.can_afford(100))
		. = TRUE

/datum/aiTask/sequence/goalbased/replicate/get_targets()
	. = list()
	for(var/turf/simulated/floor/feather/F in view(max_dist, holder.owner))
		// let's not spam eggs all the time
		if(isnull(locate(/obj/flock_structure/egg) in F))
			// if we can get a valid path to the target, include it for consideration
			. += F
	. = get_path_to(holder.owner, ., max_dist*2, can_be_adjacent_to_target)

////////

/datum/aiTask/succeedable/replicate
	name = "replicate subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/replicate/failed()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(!F)
		return TRUE
	if(F && !F.can_afford(100))
		return TRUE
	var/turf/simulated/floor/feather/N = get_turf(holder.owner)
	if(!N)
		return TRUE

/datum/aiTask/succeedable/replicate/succeeded()
	. = (!actions.hasAction(holder.owner, "flock_egg")) // for whatever reason, the required action has stopped

/datum/aiTask/succeedable/replicate/on_tick()
	if(!has_started)
		var/mob/living/critter/flock/drone/F = holder.owner
		if(F)
			F.create_egg()
			has_started = TRUE

/datum/aiTask/succeedable/replicate/on_reset()
	has_started = FALSE


///////////////////////////////////////////////////////////////////////////////////////////////////////////
// NEST + REPLICATION GOAL
// targets: valid nesting sites
// precondition: 120 resources, no flocktiles in view
/datum/aiTask/sequence/goalbased/nest
	name = "nesting"
	weight = 6
	can_be_adjacent_to_target = TRUE
	max_dist = 2

/datum/aiTask/sequence/goalbased/nest/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/build, list(holder)))

/datum/aiTask/sequence/goalbased/nest/precondition()
	. = FALSE
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F?.can_afford(120))
		. = TRUE //we can afford
		for(var/turf/simulated/floor/feather/T in view(max_dist, holder.owner))
			return FALSE //but there's a flocktile in view


/datum/aiTask/sequence/goalbased/nest/get_targets()
	. = list()
	var/mob/living/critter/flock/F = holder.owner
	// grab a nearby unconverted tile
	for(var/turf/simulated/floor/T in view(max_dist, holder.owner))
		if(!isfeathertile(T))
			if(F?.flock && !F.flock.isTurfFree(T, F.real_name))
				continue // this tile's been claimed by someone else
			// if we can get a valid path to the target, include it for consideration
			. += T
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// BUILDING GOAL
// targets: priority tiles, fetched from holder.owner.flock (with casting)
//			or, if they're not available, whatever's available nearby
// precondition: 20 resources
/datum/aiTask/sequence/goalbased/build
	name = "building"
	weight = 10
	max_dist = 5

/datum/aiTask/sequence/goalbased/build/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/build, list(holder)))

/datum/aiTask/sequence/goalbased/build/precondition()
	var/mob/living/critter/flock/F = holder.owner
	return F?.can_afford(20)

/datum/aiTask/sequence/goalbased/build/on_tick()
	var/had_target = holder.target
	. = ..()
	if (!had_target && holder.target)
		var/turf/simulated/T = get_turf(holder.target)
		var/mob/living/critter/flock/F = holder.owner
		if (F.flock?.isTurfFree(T, F.real_name))
			F.flock.reserveTurf(T, F.real_name)

/datum/aiTask/sequence/goalbased/build/get_targets()
	var/mob/living/critter/flock/F = holder.owner

	if(F?.flock)
		// if we can go for a tile we already have reserved, go for it
		var/turf/simulated/reserved = F.flock.busy_tiles[F.real_name]
		if(istype(reserved) && !isfeathertile(reserved))
			. = get_path_to(holder.owner, reserved, max_dist, 1)
			if(length(.)) //if we got a valid path
				return
			//unreserve the turf if we can't get at it
			F.flock.busy_tiles[F.real_name] = null

		// if there's a priority tile we can go for, do it
		var/list/priority_turfs = F.flock.getPriorityTurfs(F)
		if(length(priority_turfs))
			. = get_path_to(holder.owner, priority_turfs, max_dist, 1)
			if(length(.)) //if we got a valid path
				return

	. = list()
	// else just go for one nearby
	for(var/turf/simulated/T in view(max_dist, holder.owner))
		if(!isfeathertile(T))
			if(F?.flock && !F.flock.isTurfFree(T, F.real_name))
				continue // this tile's been claimed by someone else
			// if we can get a valid path to the target, include it for consideration
			. += T
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/build
	name = "build subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/build/failed()
	var/turf/simulated/floor/build_target = holder.target
	if(!build_target || BOUNDS_DIST(holder.owner, build_target) > 0)
		return TRUE
	var/mob/living/critter/flock/F = holder.owner
	if(!F)
		return TRUE
	if(!F.can_afford(20))
		return TRUE
	if(F.flock && !F.flock.isTurfFree(build_target, F.real_name)) // oh no, someone else claimed this tile before we got to it
		return TRUE

/datum/aiTask/succeedable/build/succeeded()
	. = isfeathertile(holder.target) || (has_started && !actions.hasAction(holder.owner, "flock_convert"))

/datum/aiTask/succeedable/build/on_tick()
	if(!has_started && !failed() && !succeeded())
		var/mob/living/critter/flock/F = holder.owner
		if(F?.set_hand(2)) // nanite spray
			holder.owner.set_dir(get_dir(holder.owner, holder.target))
			F.hand_attack(holder.target)
			has_started = TRUE

/datum/aiTask/succeedable/build/on_reset()
	has_started = FALSE
	var/mob/living/critter/flock/F = holder.owner
	if(F?.flock && !failed() && !succeeded())
		F.flock.reserveTurf(holder.target, F.real_name)

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// BUILDING GOAL - FLOCKDRONE ONLY
// targets: priority tiles, fetched from holder.owner.flock (with casting)
//			or, if they're not available, storage closets, walls and doors
//			failing that, nearest tiles
// precondition: 20 resources
/datum/aiTask/sequence/goalbased/build/drone
	name = "building"
	weight = 1
	max_dist = 4

/datum/aiTask/sequence/goalbased/build/drone/precondition()
	var/mob/living/critter/flock/F = holder.owner
	return F?.can_afford(20)


/datum/aiTask/sequence/goalbased/build/drone/get_targets()
	var/mob/living/critter/flock/F = holder.owner

	if(F?.flock)
		// if we can go for a tile we already have reserved, go for it
		var/turf/simulated/reserved = F.flock.busy_tiles[F.real_name]
		if(istype(reserved) && !isfeathertile(reserved))
			. = get_path_to(holder.owner, reserved, max_dist, 1)
			if(length(.))
				return
			else
				//unreserve the turf if we can't get at it
				F.flock.busy_tiles[F.real_name] = null

		// if there's a priority tile we can go for, do it
		var/list/priority_turfs = F.flock.getPriorityTurfs(F)
		if(length(priority_turfs))
			. = get_path_to(holder.owner, priority_turfs, max_dist, 1)
			if(length(.))
				return

	. = list()
	//as drone, we want to prioritise converting doors and walls and containers
	for(var/turf/simulated/T in view(max_dist, holder.owner))
		if(!isfeathertile(T) && (
			istype(T, /turf/simulated/wall) || \
			locate(/obj/machinery/door/airlock) in T || \
			locate(/obj/storage) in T))
			if(F?.flock && !F.flock.isTurfFree(T, F.real_name))
				continue // this tile's been claimed by someone else
			// if we can get a valid path to the target, include it for consideration
			. += T

	// if there are absolutely no walls/doors/closets in view, and no reserved tiles, then fine, you can have a floor tile
	if(!length(.))
		for(var/turf/simulated/T in view(max_dist, holder.owner))
			if(!isfeathertile(T))
				if(F?.flock && !F.flock.isTurfFree(T, F.real_name))
					continue // this tile's been claimed by someone else
				// if we can get a valid path to the target, include it for consideration
				. += T
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// REPAIR GOAL
// targets: other flockdrones in the same flock
// precondition: 10 resources
/datum/aiTask/sequence/goalbased/repair
	name = "repairing"
	weight = 4

/datum/aiTask/sequence/goalbased/repair/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/repair, list(holder)))

/datum/aiTask/sequence/goalbased/repair/precondition()
	. = FALSE
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F?.can_afford(10))
		. = TRUE

/datum/aiTask/sequence/goalbased/repair/on_reset()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F)
		F.active_hand = 2 // nanite spray
		F.set_a_intent(INTENT_HELP)
		F.hud?.update_intent()
		F.hud?.update_hands() // for observers

/datum/aiTask/sequence/goalbased/repair/get_targets()
	. = list()
	for(var/mob/living/critter/flock/drone/F in view(max_dist, holder.owner))
		if(F == holder.owner)
			continue
		if(F.get_health_percentage() < 0.66 && !isdead(F))//yeesh dont try to repair something which is dead
			// if we can get a valid path to the target, include it for consideration
			. += F
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/repair
	name = "repair subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/repair/failed()
	var/mob/living/critter/flock/drone/F = holder.owner
	var/mob/living/critter/flock/drone/T = holder.target
	if(!F || !T || BOUNDS_DIST(T, F) > 0)
		return TRUE
	if(F && (!F.can_afford() || !F.abilityHolder))
		return TRUE

/datum/aiTask/succeedable/repair/succeeded()
	. = (!actions.hasAction(holder.owner, "flock_repair")) // for whatever reason, the required action has stopped

/datum/aiTask/succeedable/repair/on_tick()
	if(!has_started)
		var/mob/living/critter/flock/drone/F = holder.owner
		var/mob/living/critter/flock/drone/T = holder.target
		if(F && T && BOUNDS_DIST(holder.owner, holder.target) == FALSE)
			if(F.set_hand(2)) // nanite spray
				holder.owner.set_dir(get_dir(holder.owner, holder.target))
				F.hand_attack(T)
				has_started = TRUE

/datum/aiTask/succeedable/repair/on_reset()
	has_started = FALSE

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// DEPOSIT GOAL
// targets: ghost tealprints in the same flock
// precondition: 10 resources
/datum/aiTask/sequence/goalbased/deposit
	name = "depositing"
	weight = 8

/datum/aiTask/sequence/goalbased/deposit/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/deposit, list(holder)))

/datum/aiTask/sequence/goalbased/deposit/precondition()
	. = FALSE
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F?.can_afford(10))
		. = TRUE

/datum/aiTask/sequence/goalbased/deposit/on_reset()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F)
		F.active_hand = 2 // nanite spray
		F.set_a_intent(INTENT_HELP)
		F.hud?.update_intent()
		F.hud?.update_hands() // for observers

/datum/aiTask/sequence/goalbased/deposit/get_targets()
	var/mob/living/critter/flock/drone/F = holder.owner
	. = list()
	for(var/obj/flock_structure/ghost/S in view(max_dist, F))
		if(S.flock == F.flock && S.goal > S.currentmats)
			// if we can get a valid path to the target, include it for consideration
			. += S
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/deposit
	name = "deposit subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/deposit/failed()
	var/mob/living/critter/flock/drone/F = holder.owner
	var/obj/flock_structure/ghost/T = holder.target
	if(!F || !T || BOUNDS_DIST(T, F) > 0)
		return TRUE
	if(F && (!F.can_afford() || !F.abilityHolder))
		return TRUE

/datum/aiTask/succeedable/deposit/succeeded()
	. = (!actions.hasAction(holder.owner, "flock_repair")) // for whatever reason, the required action has stopped

/datum/aiTask/succeedable/deposit/on_tick()
	if(!has_started)
		var/mob/living/critter/flock/drone/F = holder.owner
		var/obj/flock_structure/ghost/T = holder.target
		if(F && T && BOUNDS_DIST(holder.owner, holder.target) == FALSE)
			if(F.set_hand(2)) // nanite spray
				holder.owner.set_dir(get_dir(holder.owner, holder.target))
				F.hand_attack(T)
				has_started = TRUE

/datum/aiTask/succeedable/deposit/on_reset()
	has_started = FALSE

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// OPEN CONTAINER GOAL
// targets: any large storage object
// precondition: none
// the idea is the drones will open unlocked, unwelded crates and lockers to reveal the delicious things inside
// the way this shakes out, drones will prioritise making more things available if there's targets in range than taking things
/datum/aiTask/sequence/goalbased/open_container
	name = "opening container"
	weight = 3
	max_dist = 4

/datum/aiTask/sequence/goalbased/open_container/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/open_container, list(holder)))

/datum/aiTask/sequence/goalbased/open_container/precondition()
	. = TRUE // no precondition required that isn't already checked for targets

/datum/aiTask/sequence/goalbased/open_container/get_targets()
	. = list()
	for(var/obj/storage/S in view(max_dist, holder.owner))
		if(!S.open && !S.welded && !S.locked)
			// if we can get a valid path to the target, include it for consideration
			. += S
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/open_container
	name = "open container subtask"
	max_fails = 5

/datum/aiTask/succeedable/open_container/failed()
	var/obj/storage/container_target = holder.target
	if(!container_target || BOUNDS_DIST(holder.owner, container_target) > 0 || fails >= max_fails)
		. = TRUE

/datum/aiTask/succeedable/open_container/succeeded()
	var/obj/storage/container_target = holder.target
	if(container_target) // fix runtime Cannot read null.open
		return container_target.open
	else
		return FALSE

/datum/aiTask/succeedable/open_container/on_tick()
	var/obj/storage/container_target = holder.target
	if(container_target && BOUNDS_DIST(holder.owner, container_target) == FALSE && !succeeded())
		var/mob/living/critter/flock/drone/F = holder.owner
		if(F?.set_hand(1)) // grip tool
			F.set_dir(get_dir(F, container_target))
			F.hand_attack(container_target) // wooo
	// tick up a fail counter so we don't try to open something we can't forever
	fails++

/datum/aiTask/succeedable/open_container/on_reset()
	fails = 0

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// RUMMAGE GOAL
// targets: any small storage object
// precondition: none
// rummage through the storage object and throw every item in it we can get all over the place
/datum/aiTask/sequence/goalbased/rummage
	name = "rummaging"
	weight = 3
	max_dist = 4

/datum/aiTask/sequence/goalbased/rummage/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/rummage, list(holder)))

/datum/aiTask/sequence/goalbased/rummage/precondition()
	. = TRUE // no precondition required that isn't already checked for targets

/datum/aiTask/sequence/goalbased/rummage/get_targets()
	. = list()
	for(var/obj/item/storage/I in view(max_dist, holder.owner))
		if(length(I.contents) && I.loc != holder.owner && I.does_not_open_in_pocket)
			// if we can get a valid path to the target, include it for consideration
			. += I
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/rummage
	name = "rummage subtask"
	max_fails = 5
	var/list/dummy_params = list("screen-loc" = "7:16,8:16") // click on the first item in storage menu on turf

/datum/aiTask/succeedable/rummage/failed()
	var/obj/item/storage/container_target = holder.target
	if(!container_target || BOUNDS_DIST(holder.owner, container_target) > 0 || fails >= max_fails)
		. = TRUE

/datum/aiTask/succeedable/rummage/succeeded()
	var/obj/item/storage/container_target = holder.target
	var/mob/living/critter/flock/drone/F = holder.owner
	if(container_target) // fix runtime Cannot read null.contents
		return !length(container_target.contents) || (F.absorber.item == container_target)

	else
		return FALSE

/datum/aiTask/succeedable/rummage/on_tick()
	var/obj/item/storage/container_target = holder.target
	if(container_target && BOUNDS_DIST(holder.owner, container_target) == 0 && !succeeded())
		var/mob/living/critter/flock/drone/F = holder.owner
		usr = F // don't ask, please, don't
		if(F?.set_hand(1)) // grip tool
			// drop whatever we're holding
			if(!F.is_in_hands(container_target)) //if it's not in any of our hands, pick it up
				F.drop_item()
				F.set_dir(get_dir(F, container_target))
				F.hand_attack(container_target) //try and pick it up
			if(F.is_in_hands(container_target)) //did we do it?
				if(F.absorber.item != container_target) //if it's in our manipulating hand
					// we've picked up a container, just eat it, dump it onto the floor
					container_target.MouseDrop(get_turf(F)) //this will do nothing on a locked secure storage
					// might as well eat the container now
					F.absorber.equip(container_target) //eating the container drops the contents anyway
					return
			else
				// we've opened a HUD, do a fake HUD click, because i am dedicated to this whole puppetry schtick
				container_target.hud.relay_click("boxes", F, dummy_params)
				if(isitem(F.equipped()))
					// we got an item from the thing, drop it for our friends to munch on
					F.drop_item()
					return
				else
					container_target.MouseDrop(holder.owner) //last ditch, try click dragging it onto us
					if(isitem(F.equipped()))
						return
				// either the container is empty and we're fruitlessly trying to get something, or we can't work the HUD for some reason
				// (maybe the format got changed?)

	// tick up a fail counter so we don't try to open something we can't forever
	fails++

/datum/aiTask/succeedable/rummage/on_reset()
	fails = 0

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// HARVEST GOAL
// targets: any item
// precondition: empty absorber slot
/datum/aiTask/sequence/goalbased/harvest
	name = "harvesting"
	weight = 2
	max_dist = 6

/datum/aiTask/sequence/goalbased/harvest/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/harvest, list(holder)))

/datum/aiTask/sequence/goalbased/harvest/precondition()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F)
		return !(F.absorber.item)
	else
		return FALSE // can't harvest anyway, if not a flockdrone

/datum/aiTask/sequence/goalbased/harvest/get_targets()
	. = list()
	for(var/obj/item/I in view(max_dist, holder.owner))
		if(!I.anchored && I.loc != holder.owner)
			if(istype(I, /obj/item/game_kit))
				continue // fuck the game kit
			// if we can get a valid path to the target, include it for consideration
			. += I
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/harvest
	name = "harvest subtask"
	max_fails = 5

/datum/aiTask/succeedable/harvest/failed()
	var/obj/item/harvest_target = holder.target
	if(!harvest_target || BOUNDS_DIST(holder.owner, harvest_target) > 0 || fails >= max_fails)
		. = TRUE

/datum/aiTask/succeedable/harvest/succeeded()
	. = holder.owner.find_in_equipment(holder.target)

/datum/aiTask/succeedable/harvest/on_tick()
	var/obj/item/harvest_target = holder.target
	if(harvest_target && BOUNDS_DIST(holder.owner, harvest_target) == 0 && !succeeded())
		var/mob/living/critter/flock/drone/F = holder.owner
		if(F?.set_hand(1)) // grip tool
			var/obj/item/already_held = F.get_active_hand().item
			if(already_held)
				// we're already holding a thing to eat
				harvest_target = already_held
			else
				F.empty_hand(1) // drop whatever we might be holding just in case
				// grab the item
				F.set_dir(get_dir(F, harvest_target)) //look at it
				//special item type handling
				if(istype(harvest_target,/obj/item/card_group))
					if(harvest_target.loc == holder.owner) //checks hand for card to allow taking from pockets/storage
						holder.owner.u_equip(harvest_target)
					holder.owner.put_in_hand_or_drop(harvest_target)
				else if(istype(harvest_target, /obj/item/paper_bin))
					// special consideration because these things can empty out
					var/obj/item/paper_bin/P = harvest_target
					if(P.amount <= 0) //if it's empty, pick up the bin
						holder.owner.put_in_hand_or_drop(harvest_target)
					else
						F.hand_attack(harvest_target) //else grab some paper
				else
					F.hand_attack(harvest_target)
			// if we have the item, equip it into our horrifying death chamber
			if(F.is_in_hands(harvest_target))
				F.absorber.equip(harvest_target) // hooray!
	// tick up a fail counter so we don't try to get something we can't forever
	fails++

/datum/aiTask/succeedable/harvest/on_reset()
	fails = 0

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// FLOCKDRONE-SPECIFIC SHOOT TASK
// ho boy
// so within this timed task, look through valid targets in holder.owner.flock
// pick a target within range and shoot at them if they're not already stunned
/datum/aiTask/timed/targeted/flockdrone_shoot
	name = "shooting"
	minimum_task_ticks = 10
	maximum_task_ticks = 25
	var/weight = 10
	target_range = 12
	var/shoot_range = 6
	var/run_range = 3
	var/list/dummy_params = list("icon-x" = 16, "icon-y" = 16)


/datum/aiTask/timed/targeted/flockdrone_shoot/evaluate()
	return weight * score_target(get_best_target(get_targets()))

/datum/aiTask/timed/targeted/flockdrone_shoot/on_tick()
	var/mob/living/critter/owncritter = holder.owner
	walk(owncritter, 0)
	if(!holder.target)
		holder.target = get_best_target(get_targets())
	if(holder.target)
		var/atom/T = holder.target
		// if target is down or in a cage, we don't care about this target now
		// fetch a new one if we can
		if(isliving(T))
			var/mob/living/M = T
			if(is_incapacitated(M))
				holder.target = get_best_target(get_targets())
		if(istype(T.loc, /obj/flock_structure/cage))
			holder.target = get_best_target(get_targets())

		if(!holder.target)
			holder.interrupt()
			return

		var/dist = get_dist(owncritter, holder.target)
		if(dist > target_range)
			holder.target = get_best_target(get_targets())
		else if(dist > shoot_range)
			holder.move_to(holder.target,4)
			frustration++ //if frustration gets too high, the task is ended and re-evaluated
		else
			if(owncritter.active_hand != 3) // stunner
				owncritter.set_hand(3)
			owncritter.set_dir(get_dir(owncritter, holder.target))
			owncritter.hand_range_attack(holder.target, dummy_params)
			if(dist < run_range)
				if(prob(20))
					// RUN
					holder.move_away(holder.target,4)
			else if(prob(30))
				// ROBUST DODGE
				walk(owncritter, 0)
				walk_rand(owncritter, 1, 2)


/datum/aiTask/timed/targeted/flockdrone_shoot/get_targets()
	. = list()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(!F?.flock)
		return
	for(var/atom/T in view(target_range, holder.owner))
		if(!F.flock.isEnemy(T))
			continue
		if(isliving(T))
			var/mob/living/M = T
			if(is_incapacitated(M))
				continue

		// mob is a valid target, check if they're not already in a cage
		if(!istype(T.loc.type, /obj/flock_structure/cage))
			// if we can get a valid path to the target, include it for consideration
			. += T
		F.flock.updateEnemy(T)


///////////////////////////////////////////////////////////////////////////////////////////////////////////
// FLOCKDRONE-SPECIFIC CAPTURE TASK
// look through valid targets that are in the flock targets AND are stunned
/datum/aiTask/sequence/goalbased/flockdrone_capture
	name = "capturing"
	weight = 15
	max_dist = 12
	can_be_adjacent_to_target = TRUE

/datum/aiTask/sequence/goalbased/flockdrone_capture/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/capture, list(holder)))

/datum/aiTask/sequence/goalbased/flockdrone_capture/precondition()
	var/mob/living/critter/flock/F = holder.owner
	return F?.can_afford(15)

/datum/aiTask/sequence/goalbased/flockdrone_capture/evaluate()
	. = precondition() * weight * score_target(get_best_target(get_targets()))

/datum/aiTask/sequence/goalbased/flockdrone_capture/on_tick()
	if(!holder.target)
		holder.target = get_best_target(get_targets())
	..()

/datum/aiTask/sequence/goalbased/flockdrone_capture/get_targets()
	. = list()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F?.flock)
		for(var/atom/T in view(max_dist, holder.owner))
			if(!F.flock.isEnemy(T))
				continue
			if(istype(T,/mob/living))
				var/mob/living/M = T
				if(!is_incapacitated(M))
					continue

			// mob is a valid target, check if they're not already in a cage
			if(!istype(T.loc, /obj/flock_structure/cage))
				// if we can get a valid path to the target, include it for consideration
				. += T
			F.flock.updateEnemy(T)
	. = get_path_to(holder.owner, ., max_dist*2, 1)

/datum/aiTask/succeedable/capture
	name = "capture subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/capture/failed()
	var/mob/living/critter/flock/F = holder.owner
	if(!F)
		return TRUE
	if(!F.can_afford(15))
		return TRUE
	if(get_dist(F, holder.target) > 1) //moved away before we could finish
		return TRUE

/datum/aiTask/succeedable/capture/succeeded()
	. = istype(holder?.target?.loc, /obj/flock_structure/cage) || (has_started && !actions.hasAction(holder.owner, "flock_entomb"))

/datum/aiTask/succeedable/capture/on_tick()
	if(!has_started && !failed() && !succeeded())
		if(holder.target)
			var/atom/T = holder.target
			if(isliving(T))
				var/mob/living/M = T
				if(!is_incapacitated(M))
					// target is up, abort
					holder.interrupt() // re-evaluate task options
					return
			var/mob/living/critter/flock/drone/owncritter = holder.owner
			var/dist = get_dist(owncritter, holder.target)
			if(dist > 1)
				holder.interrupt() //this should basically never happen, but sanity check just in case
				return
			else if(!actions.hasAction(owncritter, "flock_entomb")) // let's not keep interrupting our own action
				if(owncritter.active_hand != 2) // nanite spray
					owncritter.set_hand(2)
					owncritter.set_a_intent(INTENT_DISARM)
					owncritter.hud.update_intent()
				owncritter.set_dir(get_dir(owncritter, holder.target))
				owncritter.hand_attack(holder.target)
		else
			holder.interrupt() //somehow lost target, go do something else
			return
/datum/aiTask/succeedable/capture/on_reset()
	has_started = FALSE

///////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// BUTCHER GOAL
// targets: other dead flockdrones in the same flock
/datum/aiTask/sequence/goalbased/butcher
	name = "butchering"
	weight = 3

/datum/aiTask/sequence/goalbased/butcher/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/butcher, list(holder)))


/datum/aiTask/sequence/goalbased/butcher/on_reset()
	var/mob/living/critter/flock/drone/F = holder.owner
	if(F)
		F.active_hand = 2 // nanite spray
		F.set_a_intent(INTENT_HARM)
		F.hud?.update_intent()
		F.hud?.update_hands() // for observers

/datum/aiTask/sequence/goalbased/butcher/get_targets()
	. = list()
	for(var/mob/living/critter/flock/drone/F in view(max_dist, holder.owner))
		if(F == holder.owner || F.butcherer)
			continue
		if(isdead(F))
			. += F
	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/butcher
	name = "butcher subtask"
	var/has_started = FALSE

/datum/aiTask/succeedable/butcher/failed()
	var/mob/living/critter/flock/drone/F = holder.owner
	var/mob/living/critter/flock/drone/T = holder.target
	if(!F || !T || BOUNDS_DIST(T, F) > 0)
		return TRUE
	if(F && !F.abilityHolder)
		return TRUE

/datum/aiTask/succeedable/butcher/succeeded()
	. = (!actions.hasAction(holder.owner, "butcherlivingcritter")) // for whatever reason, the required action has stopped

/datum/aiTask/succeedable/butcher/on_tick()
	if(!has_started)
		var/mob/living/critter/flock/drone/F = holder.owner
		var/mob/living/critter/flock/drone/T = holder.target
		if(F && T && BOUNDS_DIST(holder.owner, holder.target) == 0)
			if(F.set_hand(2)) // nanite spray
				holder.owner.set_dir(get_dir(holder.owner, holder.target))
				F.hand_attack(T)
				has_started = TRUE

/datum/aiTask/succeedable/butcher/on_reset()
	has_started = FALSE

///////////////////////////////////////////////////////////////////////////////////////////////////////////
// STARE AT BIRDS
// targets: any bird critters
// precondition: cooldown
/datum/aiTask/sequence/goalbased/stare
	name = "observing"
	weight = 1 //same as wander

/datum/aiTask/sequence/goalbased/stare/New(parentHolder, transTask)
	..(parentHolder, transTask)
	add_task(holder.get_instance(/datum/aiTask/succeedable/stare_at_bird, list(holder)))

/datum/aiTask/sequence/goalbased/stare/precondition()
	. = FALSE
	if(!GET_COOLDOWN(holder.owner, "bird_staring"))
		. = TRUE

/datum/aiTask/sequence/goalbased/stare/get_targets()
	. = list()
	for(var/mob/living/critter/C in view(max_dist, holder.owner)) //I'm not handling obj/critter birds. i'm just not. deal with it.
		if(istype(C,/mob/living/critter/small_animal/bird) || istype(C,/mob/living/critter/small_animal/ranch_base/chicken))
			. += C

	. = get_path_to(holder.owner, ., max_dist*2, 1)

////////

/datum/aiTask/succeedable/stare_at_bird
	name = "stur at burd"
	var/has_started = FALSE

/datum/aiTask/succeedable/stare_at_bird/failed()
	return !IN_RANGE(holder.owner, holder.target, 1)

/datum/aiTask/succeedable/stare_at_bird/succeeded()
	return has_started

/datum/aiTask/succeedable/stare_at_bird/on_tick()
	if(!has_started)
		var/mob/living/critter/target = holder.target
		var/mob/living/critter/flock/drone/F = holder.owner
		if(target && IN_RANGE(holder.owner, target, 1))
			if(!ON_COOLDOWN(holder.owner,"bird_staring",rand(60 SECONDS, 180 SECONDS))) //you can only stare at birds once every now an then. randomise for staggering
				switch(rand(1,100))
					if(1 to 30)
						//pat the birb
						if(F.set_hand(1)) // manipulator hand
							F.empty_hand(1) //drop any item we might be holding first
							F.set_a_intent(INTENT_HELP)
							holder.owner.set_dir(get_dir(holder.owner, holder.target))
							F.hand_attack(target)
							has_started = TRUE
					if(30 to 50)
						//attempt to communicate
						holder.owner.set_dir(get_dir(holder.owner, holder.target))
						F.emote("whistle", FALSE)
						has_started = TRUE
					if(50 to 90)
						//watch carefully
						holder.owner.set_dir(get_dir(holder.owner, holder.target))
						F.emote("stare [target]", FALSE)
						has_started = TRUE
					if(90 to 101)
						if(istype(holder.target, /mob/living/critter/small_animal/bird/owl/))
							F.say("hoot hoot")
						else
							F.say("tweet tweet")
						has_started = TRUE

/datum/aiTask/succeedable/stare_at_bird/on_reset()
	has_started = FALSE
