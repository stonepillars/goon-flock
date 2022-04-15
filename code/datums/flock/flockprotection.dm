/// Makes the flockmind 'protect' things by marking them as an enemy if a flockdrone spots them doing it.
/datum/component/flock_protection
	/// Do we stop flockdrones from harming it?
	var/flock_immune
	/// Do we get mad if someone punches it?
	var/report_unarmed
	/// Do we get mad if someone hits it with something?
	var/report_attack
	/// Do we get mad if someone throws something at it?
	var/report_thrown
	/// Do we get mad if someone shoots it?
	var/report_proj

/datum/component/flock_protection/Initialize(flock_immune=TRUE, report_unarmed=TRUE, report_attack=TRUE, report_thrown=TRUE, report_proj=TRUE)
	src.flock_immune = flock_immune
	src.report_unarmed = report_unarmed
	src.report_attack = report_attack
	src.report_thrown = report_thrown
	src.report_proj = report_proj

/datum/component/flock_protection/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATTACKHAND, .proc/handle_attackhand)
	RegisterSignal(parent, COMSIG_ATTACKBY, .proc/handle_attackby)
	RegisterSignal(parent, COMSIG_ATOM_HITBY_THROWN, .proc/handle_hitby_thrown)
	RegisterSignal(parent, COMSIG_ATOM_HITBY_PROJ, .proc/handle_hitby)

/// Protect against punches/kicks/etc.
/datum/component/flock_protection/proc/handle_attackhand(source, mob/user as mob)
	if (user.a_intent != INTENT_HARM)
		return

	if (isflock(user) && src.flock_immune)
		boutput(user, "<span class='alert'>The grip tool refuses to harm this, jamming briefly.</span>")
		return TRUE

	if (!isflock(user) && src.report_unarmed)
		src.attempt_report_attack(source, user)

/// Protect against being hit by something.
/datum/component/flock_protection/proc/handle_attackby(source, obj/item/W as obj, mob/user as mob)
	var/we_take_those = FALSE
	if (istype(source, /obj/lattice/flock) && isweldingtool(W) && W:try_weld(user,0,-1,0,0))
		we_take_those = TRUE
	else if (istype(source, /obj/storage/closet/flock))
		var/obj/storage/closet/flock/flockcloset = source
		if (!flockcloset.open)
			if(!isflock(user) && istype(W, /obj/item/cargotele))
				return
			we_take_those = TRUE
	else if (istype(source, /obj/machinery/door/feather))
		if (user.equipped()) // Doors immedately pass attack_hand to Attackby, so this check is required.
			we_take_those = TRUE
	else
		we_take_those = TRUE

	if(we_take_those)
		if(isflock(user) && src.flock_immune)
			boutput(user, "<span class='alert'>The grip tool refuses to allow damage to this, jamming briefly.</span>")
			return TRUE
		if(!isflock(user) && src.report_attack)
			src.attempt_report_attack(source, user)

/// Protect against someone chucking stuff at the parent.
/datum/component/flock_protection/proc/handle_hitby_thrown(source, atom/hit_atom, datum/thrown_thing/thr)
	var/mob/attacker = thr.user
	if(!istype(attacker))
		return
	if (!isflock(attacker) && src.report_thrown)
		src.attempt_report_attack(source, attacker)

/// Protect against someone shooting the parent.
/datum/component/flock_protection/proc/handle_hitby(source, obj/projectile/P)
	var/mob/attacker = P.shooter
	if(!istype(attacker))
		return
	if (!isflock(attacker) && src.report_proj)
		src.attempt_report_attack(source, attacker)

/// Look for flockdrones nearby who will snitch
/datum/component/flock_protection/proc/attempt_report_attack(source, mob/attacker)
	var/mob/living/critter/flock/drone/snitch
	for (var/mob/living/critter/flock/drone/flockdrone in view(7, source))
		if (!isdead(flockdrone) && flockdrone.is_npc && flockdrone.flock)
			snitch = flockdrone
			break

	if(!snitch)
		return

	if (!snitch.flock.isEnemy(attacker))
		flock_speak(snitch, "Damage sighted on [source], [pick_string("flockmind.txt", "flockdrone_enemy")] [attacker]", snitch.flock)
		snitch.flock.updateEnemy(attacker)
