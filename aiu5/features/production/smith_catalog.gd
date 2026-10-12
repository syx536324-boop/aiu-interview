# Defines eight blacksmith-only leather and crude-iron armor recipes.
extends RefCounted
const RECIPES := {
	"smith:leather_armor":{"name":"皮盔甲","cost":{"leather":8},"gain":{"leather_armor":1}},
	"smith:leather_leggings":{"name":"皮护腿","cost":{"leather":5},"gain":{"leather_leggings":1}},
	"smith:leather_helmet":{"name":"皮头盔","cost":{"leather":4},"gain":{"leather_helmet":1}},
	"smith:leather_boots":{"name":"皮靴","cost":{"leather":4},"gain":{"leather_boots":1}},
	"smith:iron_armor":{"name":"铁盔甲","cost":{"crude_iron":8},"gain":{"iron_armor":1}},
	"smith:iron_leggings":{"name":"铁护腿","cost":{"crude_iron":5},"gain":{"iron_leggings":1}},
	"smith:iron_helmet":{"name":"铁头盔","cost":{"crude_iron":4},"gain":{"iron_helmet":1}},
	"smith:iron_boots":{"name":"铁靴","cost":{"crude_iron":4},"gain":{"iron_boots":1}}}
