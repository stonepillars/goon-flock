//
/// # Gnesis Turret - Shoots syringes full of coagulated gnesis at poor staffies
//
// A vat that slowly generates gnesis over time,
/obj/flock_structure/gnesisturret
	name = "spiky fluid vat"
	desc = "A vat of bubbling teal fluid, covered in hollow spikes."
	icon_state = "teleblocker-off"
	flock_id = "Gnesis turret"
	//resourcecost = 300
	health = 80
	var/fluid_level_max = 250
	var/fluid_gen_amt = 3
	var/fluid_gen_type = "flockdrone_fluid"
	var/fluid_shot_amt = 20
	var/target = null
	var/range = 8
	var/spread = 1
	var/datum/projectile/syringe/gnesis/current_projectile = null

	var/powered = FALSE
	// flockdrones can pass through this
	passthrough = TRUE
	usesgroups = TRUE
	var/fluid_gen_cost = 30 //generating gnesis consumes compute
	var/base_compute = 20
	compute = 0

	New(var/atom/location, var/datum/flock/F=null)
		..(location, F)
		ensure_reagent_holder()
		src.current_projectile = new /datum/projectile/syringe/gnesis(src)
		src.current_projectile.cost = src.fluid_shot_amt

	disposing()
		..()

	proc/ensure_reagent_holder()
		if (!src.reagents)
			var/datum/reagents/R = new /datum/reagents(src.fluid_level_max)
			src.reagents = R
			R.my_atom = src

	building_specific_info()
		return {"<span class='bold'>Status:</span> [!powered ? "offline" : ((src.reagents.total_volume < fluid_level_max) && (src.flock.can_afford_compute(base_compute+fluid_gen_cost)) ? "replicating" : "idle")].
	<br><span class='bold'>Gnesis Tank Level:</span> [src.reagents.total_volume]/[fluid_level_max]."}

	process()
		if(!src.group)//if it dont exist it off
			powered = FALSE
			src.compute = 0
			src.icon_state = "teleblocker-off"
			return

		if(src.flock.can_afford_compute(base_compute))
			powered = TRUE
			src.compute = -base_compute
			src.icon_state = "teleblocker-on"
		else//if there isnt enough juice
			powered = FALSE
			src.compute = 0
			src.icon_state = "teleblocker-off"
			return

		//if we need to generate more juice, do so and up the compute cost appropriately
		if(src.reagents.total_volume < src.reagents.maximum_volume)
			if(src.flock.can_afford_compute(base_compute+fluid_gen_cost))
				src.compute = -(base_compute + fluid_gen_cost)
				src.reagents.add_reagent(fluid_gen_type, fluid_gen_amt)

		if(src.reagents.total_volume >= fluid_shot_amt)
			//shamelessly stolen from deployable_turret.dm
			if(!src.target && !src.seek_target()) //attempt to set the target if no target
				return
			if(!src.target_valid(src.target)) //check valid target
				src.target = null
				return
			else //GUN THEM DOWN
				if(src.target)
					SPAWN(0)
						for(var/i in 1 to src.current_projectile.shot_number) //loop animation until finished
							//flick("gnturret_fire",src)
							muzzle_flash_any(src, 0, "muzzle_flash")
							sleep(src.current_projectile.shot_delay)
					shoot_projectile_ST_pixel_spread(src, current_projectile, target, 0, 0 , spread)

	proc/seek_target()
		var/list/target_list = list()
		for (var/mob/living/C in range(src.range,src.loc))
			if (!isnull(C) && src.target_valid(C))
				target_list += C
				var/distance = get_dist(C.loc,src.loc)
				target_list[C] = distance

		if (length(target_list)>0)
			var/min_dist = 99999

			for (var/mob/living/T in target_list)
				if (target_list[T] < min_dist)
					src.target = T
					min_dist = target_list[T]

			playsound(src.loc, "sound/vox/woofsound.ogg", 40, 1)

		return src.target

	proc/target_valid(var/mob/living/C)
		var/distance = get_dist(get_turf(C),get_turf(src))

		if(distance > src.range)
			return 0
		if (!C)
			return 0
		if(!isliving(C) || isintangible(C))
			return 0
		if (C.health < 0)
			return 0
		if (C.stat == 2)
			return 0
		if (!src.flock.isEnemy(C))
			return 0
		if (istype(C,/mob/living/carbon/human))
			var/mob/living/carbon/human/H = C
			if (H.hasStatus(list("resting", "weakened", "stunned", "paralysis"))) // stops it from uselessly firing at people who are already suppressed. It's meant to be a suppression weapon!
				return 0
			if (H.reagents.has_reagent(fluid_gen_type,100)) //don't keep shooting at people who are already 1/3 flock
				return 0
		if (isflock(C))
			return 0

		return 1


/datum/projectile/syringe/gnesis
	name = "nanite spike"
	icon = 'icons/misc/featherzone.dmi'
	icon_state = "stunbolt"
	cost = 10 //how much gnesis you get per-shot
	var/obj/flock_structure/gnesisturret/parentTurret = null

	New(var/obj/flock_structure/gnesisturret/gt)
		. = ..()
		src.parentTurret = gt

	on_launch(obj/projectile/O)
		. = ..()
		parentTurret.reagents.trans_to(O,src.cost)
