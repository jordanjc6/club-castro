extends Node2D

const CUP_SCRIPT = preload("res://scripts/minigames/cup.gd")
const CUP_SIZES = CUP_SCRIPT.CupSize

const DISPENSER_SCRIPT = preload("res://scripts/minigames/dispenser.gd")
const FLAVORS = DISPENSER_SCRIPT.DrinkFlavor

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

# Stores the currently active open ticket across all instances
static var currently_open_ticket: Node = null

var drink_order: Dictionary = {
		"size": CUP_SIZES.NONE,
		"flavor": FLAVORS.NONE,
		"has_ice": false,
		"has_tapioca": false,
		"has_popping_boba": false,
		"has_grass_jelly": false,
		"has_pudding": false
	}

@onready var ticket_button: TextureButton = $TicketButton
@onready var details_popup: CanvasLayer = $DetailsPopup
@onready var order_number: Label = $DetailsPopup/DetailPanel/VBoxContainer/Label


func _ready() -> void:
	details_popup.hide()
	_update_order_display()
	
	# Open overlay when ticket button is pressed
	ticket_button.pressed.connect(_on_ticket_pressed)
	
	# Close the overlay whenever anywhere on the backdrop screen is clicked/touched
	#backdrop.gui_input.connect(_on_backdrop_gui_input)

func set_order(order: Dictionary) -> void:
	drink_order = order
	_update_order_display()

func _update_order_display() -> void:
	if not order_number:
		return

	# Convert enum integer values (e.g. 1, 2) to readable formatted text ("Small", "Mango")
	var size_str: String = CUP_SIZES.keys()[drink_order["size"]].capitalize()
	var flavor_str: String = FLAVORS.keys()[drink_order["flavor"]].capitalize()
	var ice_str: String = "Yes" if drink_order["has_ice"] else "No"

	# Build active toppings list
	var active_toppings: Array[String] = []
	if drink_order.get("has_tapioca", false):
		active_toppings.append("Tapioca")
	if drink_order.get("has_popping_boba", false):
		active_toppings.append("Popping Boba")
	if drink_order.get("has_grass_jelly", false):
		active_toppings.append("Grass Jelly")
	if drink_order.get("has_pudding", false):
		active_toppings.append("Pudding")

	var toppings_str: String = ", ".join(active_toppings) if active_toppings.size() > 0 else "None"

	# Display formatted order details
	order_number.text = "Size: %s\nFlavor: %s\nIce: %s\nToppings: %s" % [
		size_str,
		flavor_str,
		ice_str,
		toppings_str
	]

func _on_ticket_pressed() -> void:
	#if !find_parent("BaristaMinigame").is_match_running: return
	
	print("order ticket pressed")
	
	# 1. If this exact ticket is already open, toggle it closed
	if currently_open_ticket == self:
		details_popup.hide()
		currently_open_ticket = null
		return

	# 2. If another ticket is currently open, close it
	if currently_open_ticket != null and is_instance_valid(currently_open_ticket):
		currently_open_ticket.hide_details()

	# 3. Open details for this ticket and mark it as active
	details_popup.show()
	currently_open_ticket = self

# Helper method called by other tickets to close this popup
func hide_details() -> void:
	details_popup.hide()

# Cleanup static reference if the ticket node gets destroyed while open
func _exit_tree() -> void:
	if currently_open_ticket == self:
		currently_open_ticket = null
