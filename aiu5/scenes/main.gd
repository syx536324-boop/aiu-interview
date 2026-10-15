# Composes the village simulation and its presentation.
extends Node

const Profile := preload("res://features/save_slots/profile.gd")

func _enter_tree() -> void:
	Profile.configure($World)

func _ready() -> void:
	$Inventory.start()
	$Harvesting.start($World, $Inventory)
	$Interiors.layout_overrides = $Inventory.layouts
	$Interiors.minimal_start=$World.settlement=="starter_v2"
	$FurnitureEditor.start($World, $Interiors, $Inventory)
	$Session.start($World, $Interiors, $Inventory, $FurnitureEditor, $Harvesting)
	$Homestead.start($World, $Interiors, $Inventory)
	$Landscape.start($World)
	$Livestock.start($World, $Inventory)
	$Mining.start($World, $Interiors, $Inventory)
	$WorldResources.start($World, $Inventory, $Harvesting, $Mining, $Homestead, $Grounds)
	$Grounds.start($World, $Homestead, $Inventory.layouts.get("outdoors", []))
	$FurnitureEditor.grounds = $Grounds
	$Vitals.start($World, $Inventory)
	$Session.vitals = $Vitals
	$Session.homestead = $Homestead
	$Session.grounds = $Grounds
	$Session.livestock = $Livestock
	$Session.mining = $Mining
	$Session.landscape = $Landscape
	$Session.resources = $WorldResources
	$Session.persistence = $Persistence
	$Session.offerings = $Offerings
	$Offerings.start($Session)
	$Session.magic = $Magic
	$Magic.start($Session)
	$Vitals.magic = $Magic
	$Harvesting.equipment = $Magic
	$Mining.equipment = $Magic
	$Magic.message.connect($Session._set_notice)
	$Homestead.message.connect($Session._set_notice)
	$Livestock.message.connect($Session._set_notice)
	$Mining.message.connect($Session._set_notice)
	$Vitals.message.connect($Session._set_notice)
	$Persistence.message.connect($Session._set_notice)
	for actor in $World.controllable: $Inventory.grant_supplies(actor.resident_id)
	$Session.construction = $Construction
	$Session.production = $Production
	$Session.combat = $Combat
	$Construction.start($Session)
	$Production.start($Session)
	$FurnitureEditor.removal_guard = $Production.can_remove_fixture
	$Combat.start($Session)
	$Session.achievements=$Achievements
	$Achievements.start($Session)
	$Session.foraging=$Foraging
	$Foraging.start($Session)
	$Session.forest = $Forest
	$Forest.start($Session)
	$Forest.message.connect($Session._set_notice)
	$FurnitureEditor.deploy_commit = $Production.commit
	$Construction.message.connect($Session._set_notice)
	$Production.message.connect($Session._set_notice)
	$Combat.message.connect($Session._set_notice)
	var torches := preload("res://features/lighting/torches.gd").new()
	torches.name = "Torches"
	add_child(torches)
	$Session.torches = torches
	torches.start($Session)
	$Session.day_night = $DayNight
	$DayNight.start($Session)
	var wildlife := preload("res://features/livestock/wildlife.gd").new()
	wildlife.name="Wildlife"; add_child(wildlife); $Session.wildlife=wildlife; wildlife.start($Session)
	var tribes := preload("res://features/tribes/tribes.gd").new()
	tribes.name="Tribes"; add_child(tribes); $Session.tribes=tribes; tribes.start($Session)
	# 未归附部落成员的日常行为与招式运行域，在部落域启动后注入。
	var npc_skills: Node
	var guards: Node
	if ResourceLoader.exists("res://features/combat/npc_skills.gd"):
		npc_skills = (load("res://features/combat/npc_skills.gd") as Script).new(); npc_skills.name="NpcSkills"; add_child(npc_skills); tribes.npc_skills=npc_skills
	if ResourceLoader.exists("res://features/tribes/guards.gd"):
		guards = (load("res://features/tribes/guards.gd") as Script).new(); guards.name="Guards"; add_child(guards); tribes.guards=guards
	if is_instance_valid(guards): guards.start(tribes)
	if is_instance_valid(npc_skills): npc_skills.start(tribes, guards)
	var onboarding := preload("res://features/onboarding/onboarding.gd").new()
	onboarding.name="Onboarding"; add_child(onboarding); $Session.onboarding=onboarding; onboarding.start($Session)
	$Foraging.gathered.connect(onboarding.record_pickup)
	$Production.craft_completed.connect(onboarding.record_craft)
	$Mining.deposit_mined.connect(onboarding.record_mining)
	$Persistence.start($Session, $Vitals, $Homestead, $Grounds)
	var onboarding_view := preload("res://features/onboarding/view.gd").new()
	onboarding_view.name="OnboardingView"; add_child(onboarding_view); onboarding_view.bind(onboarding,$Session)
	$HUD.bind_session($Session)
	$HUD.resident_requested.connect($Session.select_resident)
	$HUD.weapon_requested.connect($Session.weapon_slot_clicked)
	$HUD.torch_requested.connect(torches.slot_clicked)
	$HUD.roster_close_requested.connect($Session.close_roster)
	$HUD.founder_names_requested.connect($Session.rename_founders)
	$HUD.attributes_requested.connect($Session.show_attributes)
	$Session.names_result.connect($HUD.present_names_result)
	$Belongings.bind_session($Session)
	$Inventory.changed.connect($Session.refresh_interface)
	$Inventory.message.connect($Session._set_notice)
	$Harvesting.message.connect($Session._set_notice)
	$FurnitureEditor.changed.connect($Session.refresh_interface)
	$FurnitureEditor.message.connect($Session._set_notice)
	$Belongings.slot_requested.connect($Inventory.slot_clicked)
	$Belongings.inventory_close_requested.connect($Session.close_inventory)
	$Belongings.furniture_requested.connect($FurnitureEditor.choose)
	$Belongings.editor_close_requested.connect($Session.close_furnishing)
	$Belongings.editor_rotate_requested.connect($FurnitureEditor.rotate_selected)
	$Belongings.editor_remove_requested.connect($FurnitureEditor.remove_selected)
	$Belongings.use_requested.connect($Session.use_selected)
	$Belongings.gift_attribute_requested.connect($Gifts.assign_selected_attribute)
	$Belongings.sacrifice_requested.connect($Session.sacrifice_selected)
	$Attributes.bind_session($Session)
	$Attributes.close_requested.connect($Session.close_attributes)
	$Attributes.awaken_open_requested.connect($Session.open_awakening)
	$Attributes.awaken_close_requested.connect($Session.close_awakening)
	$Attributes.awaken_requested.connect($Session.awaken_selected)
	$Attributes.equip_requested.connect($Session.equip_attribute)
	$Attributes.unlock_requested.connect($Session.unlock_attribute)
	$Attributes.branch_selected.connect($Session.select_branch)
	$Attributes.crystals_requested.connect($Session.claim_crystals)
	$Attributes.claim_gear_requested.connect($Session.claim_attribute_gear)
	$Workshop.bind_session($Session)
	$Workshop.close_requested.connect($Production.close)
	$Workshop.recipe_requested.connect($Production.perform)
	$Session.simulation = $Simulation
	$Simulation.start($Session)
	$AltarDisplay.start($World, $Inventory)
	$Streaming.start($Session)
	$Session.gifts = $Gifts
	$Gifts.start($Session, $GiftCamera)
	$GiftView.bind_gifts($Gifts)
