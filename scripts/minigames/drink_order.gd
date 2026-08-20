extends Node2D

const CUP_SCRIPT = preload("res://scripts/minigames/cup.gd")
const CUP_SIZES = CUP_SCRIPT.CupSize

const DISPENSER_SCRIPT = preload("res://scripts/minigames/dispenser.gd")
const FLAVORS = DISPENSER_SCRIPT.DrinkFlavor

const TOPPING_SCRIPT = preload("res://scripts/minigames/topping_spoon.gd")
const TOPPINGS = TOPPING_SCRIPT.Topping

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
@onready var backdrop: Control = $DetailsPopup/OverlayBackdrop
@onready var order_number: Label = $DetailsPopup/OverlayBackdrop/DetailPanel/VBoxContainer/Label

func _ready() -> void:
	details_popup.hide()
	_update_order_display()
	
	# Open overlay when ticket button is pressed
	ticket_button.pressed.connect(_on_ticket_pressed)
	
	# Close the overlay whenever anywhere on the backdrop screen is clicked/touched
	backdrop.gui_input.connect(_on_backdrop_gui_input)

func set_order(order: Dictionary) -> void:
	drink_order = order
	_update_order_display()

func _update_order_display() -> void:
	if order_number:
		order_number.text = "Size: %s\nFlavor: %s\nIce: %s" % [drink_order["size"], drink_order["flavor"], drink_order["has_ice"]]

func _on_ticket_pressed() -> void:
	print("show order popup")
	details_popup.show()

# Close overlay on any click/tap anywhere on screen
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("hide order popup")
		details_popup.hide()
		# Prevents the click from passing through to underlying game buttons/dispensers
		get_viewport().set_input_as_handled()
