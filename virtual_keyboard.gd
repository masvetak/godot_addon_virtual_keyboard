extends PanelContainer

signal visibilityChanged()
signal layoutChanged()

@export var autoShow:bool = true
@export_file var customLayoutFile:
	set(new_value):
		customLayoutFile = new_value
		_initKeyboard()
@export var setToolTip := true

@export_group("Style")
@export var background:StyleBoxFlat = null:
	set(new_val):
		styleBackground = new_val
		background = new_val
	get:
		return styleBackground
@export var normal:StyleBoxFlat = null:
	set(new_val):
		styleNormal = new_val
		normal = new_val
	get:
		return styleNormal
@export var hover:StyleBoxFlat = null:
	set(new_val):
		styleHover = new_val
		hover = new_val
	get:
		return styleHover
@export var pressed:StyleBoxFlat = null:
	set(new_val):
		stylePressed = new_val
		pressed = new_val
	get:
		return stylePressed
@export var specialKeys:StyleBoxFlat = null:
	set(new_val):
		styleSpecialKeys = new_val
		specialKeys = new_val
	get:
		return styleSpecialKeys

@export_group("Font")
@export var font:FontFile
@export var fontColorNormal:Color = Color(1,1,1)
@export var fontColorHover:Color = Color(1,1,1)
@export var fontColorPressed:Color = Color(1,1,1)

var styleBackground:StyleBoxFlat = null
var styleNormal:StyleBoxFlat = null
var styleHover:StyleBoxFlat = null
var stylePressed:StyleBoxFlat = null
var styleSpecialKeys:StyleBoxFlat = null

var KeyListHandler

var layouts = []
var keys = []
var capslockKeys = []
var uppercase = false

var tweenPosition
var tweenSpeed = .2

var focusObject = null

var released = true

var prevPrevLayout = null
var previousLayout = null
var currentLayout = null

# ------------------------------------------------------------------------------
# Build-in methods
# ------------------------------------------------------------------------------

func _enter_tree():
	if not self.get_tree().get_root().size_changed.is_connected(size_changed):
		self.get_tree().get_root().size_changed.connect(size_changed)
	_initKeyboard()

func _input(event):
	_updateAutoDisplayOnInput(event)

# ------------------------------------------------------------------------------
# Public methods
# ------------------------------------------------------------------------------

func show():
	_showKeyboard()
	
func hide():
	_hideKeyboard()

func setActiveLayoutByName(layout_name):
	for layout in layouts:
		if layout.get_meta("layout_name") == str(layout_name):
			_showLayout(layout)
		else:
			_hideLayout(layout)

# ------------------------------------------------------------------------------
# Private methods
# ------------------------------------------------------------------------------

func size_changed():
	if autoShow:
		_hideKeyboard()

func _initKeyboard():
	var layout_list: Array = self.get_children()
	for layout in layout_list:
		self.remove_child(layout)

	if customLayoutFile == null:
		var defaultLayout = KeyboardDefaultLayout.new()
		_createKeyboard(defaultLayout.data)
	else:
		_createKeyboard(_loadJSON(customLayoutFile))
	if autoShow:
		_hideKeyboard()

func _updateAutoDisplayOnInput(event):
	if autoShow == false:
		return
	
	if event is InputEventMouseButton:
		released = !released
		if released == false:
			return
		
		var focusObject = get_viewport().gui_get_focus_owner()
		if focusObject != null:
			var clickOnInput = Rect2(focusObject.global_position,focusObject.size).has_point(get_global_mouse_position())
			var clickOnKeyboard = Rect2(global_position,size).has_point(
				get_global_mouse_position()
			)
			
			if clickOnInput:
				if isKeyboardFocusObject(focusObject):
					_showKeyboard()
			elif clickOnKeyboard:
				_showKeyboard()
			else:
				_hideKeyboard()
					
	if event is InputEventKey:
		var focusObject = get_viewport().gui_get_focus_owner()
		if focusObject != null:
			if event.keycode == KEY_ENTER:
				if isKeyboardFocusObjectCompleteOnEnter(focusObject):
					_hideKeyboard()


func _hideKeyboard(keyData=null):
	if get_owner() == null: return
	
	var tween = get_tree().create_tween()
	tween.tween_property(self, "position", Vector2(position.x,get_viewport().get_visible_rect().size.y + 10), tweenSpeed).set_trans(Tween.TRANS_SINE)
	_setCapsLock(false)
	visibilityChanged.emit(false)


func _showKeyboard(keyData=null):
	var tween = get_tree().create_tween()
	tween.tween_property(
		self,"position",
		Vector2(position.x,get_viewport().get_visible_rect().size.y-size.y),
		tweenSpeed
	).set_trans(Tween.TRANS_SINE)
	visibilityChanged.emit(true)



func _showLayout(layout):
	layout.show()
	currentLayout = layout
	
func _hideLayout(layout):
	layout.hide()

func _switchLayout(keyData):
	var layout_list: Array = self.get_children()
	for layout in layout_list:
		if layout.get_meta("layout_name") == keyData.get("layout-name"):
			_showLayout(layout)
		else:
			_hideLayout(layout)
	_setCapsLock(false)

func _setCapsLock(value: bool):
	uppercase = value
	for key in capslockKeys:
		if value:
			if key.get_draw_mode() != BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
		else:
			if key.get_draw_mode() == BaseButton.DRAW_PRESSED:
				key.button_pressed = !key.button_pressed
				
	for key in keys:
		key.changeUppercase(value)


func _triggerUppercase(keyData):
	uppercase = !uppercase
	_setCapsLock(uppercase)


func _keyReleased(keyData):
	if keyData.has("output"):
		var keyValue = keyData.get("output")
		var inputEventKey = InputEventKey.new()
		inputEventKey.shift_pressed = uppercase
		inputEventKey.alt_pressed = false
		inputEventKey.meta_pressed = false
		inputEventKey.ctrl_pressed = false
		inputEventKey.pressed = true
		var keyUnicode = KeyListHandler.getUnicodeFromString(keyValue)
		if !uppercase && KeyListHandler.hasLowercase(keyUnicode):
			keyUnicode +=32
		inputEventKey.keycode = keyUnicode
		inputEventKey.unicode = keyUnicode
		Input.parse_input_event(inputEventKey)
		_setCapsLock(false)

func _setKeyStyle(styleName:String, key: Control, style:StyleBoxFlat):
	if style != null:
		key.add_theme_stylebox_override(styleName, style)

func _createKeyboard(layoutData):
	if layoutData == null:
		print("ERROR. No layout file found")
		return
	
	KeyListHandler = KeyboardKeyList.new()
	
	var ICON_DELETE = preload("keyboard_icons/delete.png")
	var ICON_SHIFT = preload("keyboard_icons/shift.png")
	var ICON_LEFT = preload("keyboard_icons/left.png")
	var ICON_RIGHT = preload("keyboard_icons/right.png")
	var ICON_HIDE = preload("keyboard_icons/hide.png")
	var ICON_ENTER = preload("keyboard_icons/enter.png")
	
	var data = layoutData
	
	if styleBackground != null:
		add_theme_stylebox_override('panel', styleBackground)
	
	var index = 0
	for layout in data.get("layouts"):

		var layoutContainer = PanelContainer.new()
		
		if styleBackground != null:
			layoutContainer.add_theme_stylebox_override('panel', styleBackground)
		
		if index > 0:
			layoutContainer.hide()
		else:
			currentLayout = layoutContainer
		
		var layout_name = layout.get("name")
		layoutContainer.set_meta("layout_name", layout_name)
		if setToolTip:
			layoutContainer.tooltip_text = layout_name
		layouts.push_back(layoutContainer)
		add_child(layoutContainer)
		
		var baseVbox = VBoxContainer.new()
		baseVbox.size_flags_horizontal = SIZE_EXPAND_FILL
		baseVbox.size_flags_vertical = SIZE_EXPAND_FILL
		
		for row in layout.get("rows"):

			var keyRow = HBoxContainer.new()
			keyRow.size_flags_horizontal = SIZE_EXPAND_FILL
			keyRow.size_flags_vertical = SIZE_EXPAND_FILL
			
			for key in row.get("keys"):
				var newKey = KeyboardButton.new(key)
				
				_setKeyStyle("normal",newKey, styleNormal)
				_setKeyStyle("hover",newKey, styleHover)
				_setKeyStyle("pressed",newKey, stylePressed)
					
				if font != null:
					newKey.set('theme_override_fonts/font', font)
				if fontColorNormal != null:
					newKey.set('theme_override_colors/font_color', fontColorNormal)
					newKey.set('theme_override_colors/font_hover_color', fontColorHover)
					newKey.set('theme_override_colors/font_pressed_color', fontColorPressed)
					newKey.set('theme_override_colors/font_disabled_color', fontColorNormal)
					
				newKey.released.connect(_keyReleased)
				
				if key.has("type"):
					if key.get("type") == "switch-layout":
						newKey.released.connect(_switchLayout)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special":
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special-shift":
						newKey.released.connect(_triggerUppercase)
						newKey.toggle_mode = true
						capslockKeys.push_back(newKey)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
					elif key.get("type") == "special-hide-keyboard":
						newKey.released.connect(_hideKeyboard)
						_setKeyStyle("normal",newKey, styleSpecialKeys)
				
				# SET ICONS
				if key.has("display-icon"):
					var iconData = str(key.get("display-icon")).split(":")
					# PREDEFINED
					if str(iconData[0])=="PREDEFINED":
						if str(iconData[1])=="DELETE":
							newKey.setIcon(ICON_DELETE)
						elif str(iconData[1])=="SHIFT":
							newKey.setIcon(ICON_SHIFT)
						elif str(iconData[1])=="LEFT":
							newKey.setIcon(ICON_LEFT)
						elif str(iconData[1])=="RIGHT":
							newKey.setIcon(ICON_RIGHT)
						elif str(iconData[1])=="HIDE":
							newKey.setIcon(ICON_HIDE)
						elif str(iconData[1])=="ENTER":
							newKey.setIcon(ICON_ENTER)
					# CUSTOM
					if str(iconData[0])=="res":
						var texture = load(key.get("display-icon"))
						newKey.setIcon(texture)
						
					if fontColorNormal != null:
						newKey.setIconColor(fontColorNormal)
				
				keyRow.add_child(newKey)
				keys.push_back(newKey)
				
			baseVbox.add_child(keyRow)
		
		layoutContainer.add_child(baseVbox)
		index+=1

func _loadJSON(filePath) -> Variant:
	var json = JSON.new()
	var json_string = _loadFile(filePath)
	var error = json.parse(json_string)
	if error == OK:
		var data_received = json.data
		if typeof(data_received) == TYPE_DICTIONARY:
			return data_received
		else:
			return {"msg": "unexpected data => exptected DICTIONARY"}
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())	
		return {"msg":json.get_error_message()}


func _loadFile(filePath):
	var file = FileAccess.open(filePath, FileAccess.READ)
	if not file:
		print("Error loading File. Error: ")
	
	var content = file.get_as_text()
	file.close()
	return content

func isKeyboardFocusObjectCompleteOnEnter(focusObject):
	if focusObject is LineEdit:
		return true
	return false

func isKeyboardFocusObject(focusObject):
	if focusObject is LineEdit or focusObject is TextEdit:
		return true
	return false
