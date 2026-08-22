extends Node2D

const CUP_SCRIPT = preload("res://scripts/minigames/cup.gd")
const CUP_SIZES = CUP_SCRIPT.CupSize

const DISPENSER_SCRIPT = preload("res://scripts/minigames/dispenser.gd")
const FLAVORS = DISPENSER_SCRIPT.DrinkFlavor

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

# Stores the currently active open ticket across all instances
static var currently_open_ticket: Node = null

# Highlight colors
const COLOR_NORMAL := Color(1.0, 1.0, 1.0) # Standard tint
const COLOR_ACTIVE := Color(0.6, 0.6, 0.6)

var drink_order: Dictionary = {
	"number": 0,
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
	set_highlight(false)
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
	var order_str: String = "Order " + str(drink_order["number"])
	var size_str: String = CUP_SIZES.keys()[drink_order["size"]].capitalize()
	var flavor_str: String = FLAVORS.keys()[drink_order["flavor"]].capitalize()
	var ice_str: String = "+ Ice\n" if drink_order["has_ice"] else ""
	
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
	
	var toppings_str: String = ""

	if active_toppings.is_empty():
		toppings_str = "Toppings: None"
	elif active_toppings.size() == 1:
		# Single item: stays on the exact same line
		toppings_str = "Toppings: " + active_toppings[0]
	else:
		# Multiple items: newline, max 2 per line, separated by commas
		var toppings_lines: Array[String] = []
		for i in range(0, active_toppings.size(), 2):
			if i + 1 < active_toppings.size():
				var comma = "," if (i + 2 < active_toppings.size()) else ""
				toppings_lines.append("%s, %s%s" % [active_toppings[i], active_toppings[i + 1], comma])
			else:
				toppings_lines.append(active_toppings[i])
		toppings_str = "Toppings:\n" + "\n".join(toppings_lines)
			
	# Display formatted order details
	order_number.text = "%s - %s %s\n%s%s" % [
		order_str,
		size_str,
		flavor_str,
		ice_str,
		toppings_str
	]

func _on_ticket_pressed() -> void:
	print("order ticket pressed")
	
	# Release focus so Godot's button hover/focus state doesn't trap the color
	ticket_button.release_focus()
	
	# 1. If this exact ticket is already open, toggle it closed
	if currently_open_ticket == self:
		hide_details() # Called hide_details() instead of details_popup.hide()
		currently_open_ticket = null
		return

	# 2. If another ticket is currently open, close it
	if currently_open_ticket != null and is_instance_valid(currently_open_ticket):
		currently_open_ticket.hide_details()

	# 3. Open details for this ticket and mark it as active
	details_popup.show()
	set_highlight(true)
	currently_open_ticket = self

# Helper method called to enable/disable the highlight visual
func set_highlight(active: bool) -> void:
	ticket_button.self_modulate = COLOR_ACTIVE if active else COLOR_NORMAL

# Helper method called by other tickets to close this popup
func hide_details() -> void:
	details_popup.hide()
	set_highlight(false)

# Cleanup static reference if the ticket node gets destroyed while open
func _exit_tree() -> void:
	if currently_open_ticket == self:
		currently_open_ticket = null
