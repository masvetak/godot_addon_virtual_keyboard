@tool extends EditorPlugin

# ------------------------------------------------------------------------------
# Build-in methods
# ------------------------------------------------------------------------------

func _enter_tree():
	self.add_custom_type("VirtualKeyboard", "PanelContainer", preload("virtual_keyboard.gd"), preload("icon.png"))

func _exit_tree():
	self.remove_custom_type("VirtualKeyboard")
