/obj/flock_structure/compute
	name = "Some weird lookin' thinking thing"
	desc = "It almost looks like a terminal of some kind."
	flock_id = "Compute node"
	health = 60
	icon_state = "compute"
	compute = 60
	var/static/screen_count = 4

/obj/flock_structure/compute/New(var/atom/location, var/datum/flock/F=null)
	..(location, F)
	SPAWN(0)
		while(src)
			var/id = rand(1, src.screen_count)
			var/image/overlay = image('icons/misc/featherzone.dmi', "compute_screen[id]")
			src.UpdateOverlays(overlay, "display")
			sleep(5 SECONDS)

/obj/flock_structure/compute/building_specific_info()
	return {"<span class='bold'>Compute generation:</span> Currently generating [src.compute_provided()]."}
