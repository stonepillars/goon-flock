/obj/flock_structure/compute
	name = "Some weird lookin' thinking thing"
	desc = "It almost looks like a terminal of some kind."
	flock_id = "Compute node"
	health = 60
	icon_state = "compute"
	compute = 60
	var/static/display_count = 9
	var/glow_color = "#7BFFFFa2"

/obj/flock_structure/compute/New(var/atom/location, var/datum/flock/F=null)
	..(location, F)
	src.add_simple_light("compute_light", rgb2num(glow_color))
	var/image/screen = image('icons/misc/featherzone.dmi', "compute_screen", EFFECTS_LAYER_BASE)
	screen.pixel_y = 14
	src.UpdateOverlays(screen, "screen")
	SPAWN(0)
		while(src)
			var/id = rand(1, src.display_count)
			var/image/overlay = image('icons/misc/featherzone.dmi', "compute_display[id]", EFFECTS_LAYER_BASE)
			overlay.pixel_y = 16
			src.UpdateOverlays(overlay, "display")
			sleep(3 SECONDS)

/obj/flock_structure/compute/disposing()
	src.remove_simple_light("compute_light")
	. = ..()

/obj/flock_structure/compute/building_specific_info()
	return {"<span class='bold'>Compute generation:</span> Currently generating [src.compute_provided()]."}
