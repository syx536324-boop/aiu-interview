# Defines forest gathering names, mulberry regrowth and herbal-house soup recipes.
extends RefCounted
const REGROW := 120.0
const RARE_INTERVAL := 120.0
const RARE_CHANCE := 0.03
const NAMES := {"grass":"草丛","ginseng": "人参", "reishi": "灵芝", "goji": "枸杞", "mulberry": "桑树", "tree": "林木"}
const RECIPES := {
	"restorative_soup": {"name": "大补汤", "cost": {"ginseng": 1, "reishi": 1, "water_cup": 1}, "gain": {"restorative_soup": 1, "wooden_cup": 1}},
	"qi_soup": {"name": "补气汤", "cost": {"goji": 1, "mulberry_leaf": 1, "water_cup": 1}, "gain": {"qi_soup": 1, "wooden_cup": 1}}}
