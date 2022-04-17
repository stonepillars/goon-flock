// /datum/lifeprocess/canmove but with floorrunning modifications
/datum/lifeprocess/canmove/flockdrone_canmove
	var/mob/living/critter/flock/drone/flockdrone

	New(new_owner, arguments)
		..()
		flockdrone = owner

	process()
		//if (flockdrone.floorrunning)
		//	flockdrone.set_density(FALSE)
		//else
		//	flockdrone.set_density(TRUE)

		if (HAS_ATOM_PROPERTY(flockdrone, PROP_MOB_CANTMOVE))
			flockdrone.canmove = 0
			return

		if (flockdrone.throwing & THROW_GUNIMPACT)
			flockdrone.canmove = 0
			return

		flockdrone.canmove = 1
