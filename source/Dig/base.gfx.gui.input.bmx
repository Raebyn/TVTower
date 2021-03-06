Rem
	===========================================================
	GUI Input box
	===========================================================
End Rem
SuperStrict
Import "base.util.registry.spriteloader.bmx"
Import "base.gfx.gui.bmx"
Import "base.gfx.sprite.bmx"



Type TGUIinput Extends TGUIobject
    Field maxLength:Int
    Field color:TColor = New TColor.Create(120,120,120)
    Field editColor:TColor
    Field maxTextWidthBase:Int
    Field maxTextWidthCurrent:Int
    Field spriteName:String = "gfx_gui_input.default"
    Field textEffectAmount:Float = -1.0
    Field textEffectType:Int = 1
    Field overlayArea:TRectangle = New TRectangle


	'=== OVERLAY ===
	'containing text or an icon (displayed separate from input widget)

    'name in case of dynamic getting
    Field overlaySpriteName:String = Null
    'icon in case of a custom created sprite
    Field overlaySprite:TSprite = Null
    'text to display separately
    Field overlayText:String = ""
    'color for overlay text
    Field overlayColor:TColor
	'where to position the overlay: empty=none, "left", "right"
	Field overlayPosition:String = ""

	Field placeholder:String = ""
    Field placeholderColor:TColor
	Field valueDisplacement:TVec2D
	Field _textPos:TVec2D
	Field _cursorPosition:Int = -1
	Field _valueChanged:Int	= False '1 if changed
	Field _valueBeforeEdit:String = ""
	Field _valueAtLastUpdate:String = ""
	Field _valueOffset:Int = 0
	Field _editable:Int = True

	Global minDimension:TVec2D = New TVec2D.Init(40,28)
	'default name for all inputs
    Global spriteNameDefault:String	= "gfx_gui_input.default"


	Method GetClassName:String()
		Return "tguiinput"
	End Method


	Method Create:TGUIinput(pos:TVec2D, dimension:TVec2D, value:String, maxLength:Int=128, limitState:String = "")
		'setup base widget
		Super.CreateBase(pos, dimension, limitState)

'		SetZindex(20)
		SetValue(value)
		If maxLength >= 0
			SetMaxLength(maxLength)
		Else
			SetMaxLength(2048)
		EndIf
'		SetValueColor(new TColor.Init(120,120,120))

		'this element reacts to keystrokes
		SetOption(GUI_OBJECT_CAN_RECEIVE_KEYSTROKES, True)


		GUIMAnager.Add(Self)
	  	Return Self
	End Method


	'override resize to add autocalculation and min handling
	Method SetSize(w:Float = 0, h:Float = 0)
		Super.SetSize(Max(w, minDimension.GetX()), Max(h, minDimension.GetY()))
	End Method


	Method SetEditable:Int(bool:Int)
		_editable = bool
	End Method


	Method SetMaxLength:Int(maxLength:Int)
		Self.maxLength = maxLength
	End Method


	Method SetMaxTextWidth(maxTextWidth:Int)
		maxTextWidthBase = maxTextWidth
	End Method


	Method SetValueDisplacement(x:Int, y:Int)
		valueDisplacement = New TVec2D.Init(x,y)
	End Method


	'override
	Method SetValue(value:String)
		If value <> GetValue()
			_valueChanged = True
			_valueBeforeEdit = value

			Super.SetValue(value)
		EndIf
	End Method


	'override
	Method GetValue:String()
		'return the original value until edit was finished (or aborted)
		If _valueChanged Then Return _valueBeforeEdit

		Return Super.GetValue()
	End Method


	Method GetCurrentValue:String()
		'return the current value regardless of "in edit" or not
		Return value
	End Method


	'override
	'(this creates a backup of the old value)
	Method _OnSetFocus:Int()
		If Super._OnSetFocus()
			'backup old value
			_valueBeforeEdit = value

			'clear "getchar()"-queue and states
			'(this avoids entering previously pressed keystrokes)
			FlushKeys()

			Return True
		Else
			Return False
		EndIf
	End Method


	'override default update-method
	Method Update:Int()
		Super.Update()

		If Self._flags & GUI_OBJECT_ENABLED
			If _editable
				'manual entering "focus" with ENTER-key is not intended,
				'this is done by the app/game with "if enter then setFocus..."

				'enter pressed means: finished editing -> loose focus too
				If KEYMANAGER.isHit(KEY_ENTER) And IsFocused()
					KEYMANAGER.blockKey(KEY_ENTER, 200) 'to avoid auto-enter on a chat input
					GuiManager.ResetFocus()
					If Self = GuiManager.GetKeystrokeReceiver() Then GuiManager.SetKeystrokeReceiver(Null)
				EndIf


				'active input fields react to mouse clicks on the input-area
				'to move the cursor position
				If Self = GuiManager.GetKeystrokeReceiver()
					If MouseManager.IsClicked(1) And _textPos
						'shrink screenrect to "text area"
						Local screenX:Int = _textPos.GetX()
						Local screenY:Int = _textPos.GetY()
						Local screenW:Int = Self.maxTextWidthCurrent
						Local screenH:Int = GetScreenRect().GetH() - (_textPos.GetY() - GetScreenRect().GetY())


						If THelper.MouseIn(screenX, screenY, screenW, screenH)
							Local valueOffsetPixels:Int = 0
							If _valueOffset > 0 Then valueOffsetPixels = GetFont().GetWidth( value[.. _valueOffset] )
'local old:int = _cursorPosition
							Local valueClickedPixel:Int = MouseManager.x - screenX + valueOffsetPixels
							Local newCursorPosition:Int = -1
							For Local i:Int = 0 To value.length-1
								If GetFont().GetWidth(value[.. i]) > valueClickedPixel
									newCursorPosition = Max(0, i-1)
									Exit
								EndIf
							Next
							If newCursorPosition <> -1 Then _cursorPosition = newCursorPosition
'print " ... Mouse "+int(MouseManager.x)+", "+int(MouseManager.y)+" is in. Position: " + old +" => " + _cursorPosition + "  valueClickedPixel="+valueClickedPixel+"  valueOffsetPixels="+valueOffsetPixels

							'handled left click
							MouseManager.SetClickHandled(1)
						EndIf
					EndIf
				EndIf



				'as soon as an input field is marked as active input
				'all key strokes could change the input
				If Self = GuiManager.GetKeystrokeReceiver()
					If _cursorPosition = -1 Then _cursorPosition = value.length

					'ignore enter keys => TRUE
					If Not ConvertKeystrokesToText(value, _cursorPosition, True)
						value = _valueBeforeEdit

						'do not allow another ESC-press for 150ms
						KeyManager.blockKey(KEY_ESCAPE, 150)

						If Self = GuiManager.GetKeystrokeReceiver() Then GuiManager.SetKeystrokeReceiver(Null)
						GuiManager.ResetFocus()
					Else
						_valueChanged = (_valueBeforeEdit <> value)
					EndIf

					If _valueAtLastUpdate <> value
						'explicitely inform about a change of the displayed value
						EventManager.triggerEvent( TEventSimple.Create( "guiinput.onChangeValue", New TData.AddNumber("type", 1).AddString("value", value).AddString("originalValue", _valueBeforeEdit).AddString("previousValue", _valueAtLastUpdate), Self ) )
						_valueAtLastUpdate = value
					EndIf
				EndIf
			EndIf

			'if input is not the active input (enter key or clicked on another input)
			'and the value changed, inform others with an event
			If Self <> GuiManager.GetKeystrokeReceiver() And _valueChanged
				FinishEdit()
			EndIf
		EndIf
		'set to "active" look
		If _editable And Self = GuiManager.GetKeystrokeReceiver() Then SetActive(True)

		'limit input length
        If value.length > maxlength
			value = value[..maxlength]
			_cursorPosition = -1
		EndIf
	End Method
	
	
	Method FinishEdit()
		If Not _valueChanged Then Return

		'reset changed indicator
		_valueChanged = False
		'reset cursor position
		_cursorPosition = -1

		'fire onChange-event (text changed)
		EventManager.triggerEvent( TEventSimple.Create( "guiobject.onChange", New TData.AddNumber("type", 1).AddString("value", value).AddString("originalValue", _valueBeforeEdit), Self ) )

		'explicitely inform about a change of the displayed value
		'only send this once
		If _valueAtLastUpdate <> value
			EventManager.triggerEvent( TEventSimple.Create( "guiinput.onChangeValue", New TData.AddNumber("type", 1).AddString("value", value).AddString("originalValue", _valueBeforeEdit), Self ) )
		EndIf
	End Method


    Method SetOverlayPosition:Int(position:String="left")
		Select position.toLower()
			Case "left" 	overlayPosition = "iconLeft"
			Case "right" 	overlayPosition = "iconRight"
			Default			overlayPosition = ""
		EndSelect
    End Method


	Method GetOverlaySprite:TSprite()
		If overlaySprite Then Return overlaySprite
		If overlaySpriteName Then Return GetSpriteFromRegistry(overlaySpriteName)
		Return Null
	End Method


	Method SetOverlay:Int(spriteOrSpriteName:Object=Null, text:String="")
		'reset old
		overlaySprite = Null
		overlaySpriteName = ""
		If TSprite(spriteOrSpriteName) Then overlaySprite = TSprite(spriteOrSpriteName)
		If String(spriteOrSpriteName) Then overlaySpriteName = String(spriteOrSpriteName)

		overlayText = text
		'give it an default orientation
		If overlayPosition = "" Then SetOverlayPosition("left")
	End Method


	'returns the area the overlay covers
	Method GetOverlayArea:TRectangle()
		If overlayText<>""
			overlayArea.dimension.SetXY(GetFont().GetWidth(overlayText), GetFont().GetHeight(overlayText))
		ElseIf GetOverlaySprite()
			overlayArea.dimension.SetXY(GetOverlaySprite().GetWidth(), GetOverlaySprite().GetHeight())
		Else
			overlayArea.dimension.SetXY(-1, -1)
		EndIf
		Return overlayArea
	End Method


	Method GetSpriteName:String()
		If overlayPosition<>"" Then Return spriteName + "."+overlayPosition
		Return spriteName
	End Method


	'draws overlay and returns used dimension/space
	Method DrawButtonOverlay:TVec2D(position:TVec2D)
		'contains width/height of space the overlay uses
		Local dim:TVec2D = New TVec2D.Init(0,0)
		Local overlayArea:TRectangle = GetOverlayArea()
		'skip invalid overlay data
		If overlayArea.GetW() < 0  Or overlayPosition = "" Then Return dim

		'draw background for overlay  [.][  Input  ]
		'design of input/button has to have a "name.background" sprite for this
		'area to get drawn properly
		'the overlays dimension is: overlaySprites border + icon dimension
		Local overlayBGSprite:TSprite
		If Self.IsHovered()
			overlayBGSprite = GetSpriteFromRegistry(GetSpriteName() + ".background.hover")
		ElseIf Self.IsActive()
			overlayBGSprite = GetSpriteFromRegistry(GetSpriteName() + ".background.active")
		Else
			overlayBGSprite = GetSpriteFromRegistry(GetSpriteName() + ".background")
		EndIf
		If overlayBGSprite
			'calculate center of overlayBG (left and right border could have different values)
			'-> bgBorderWidth/2
			Local bgBorderWidth:Int = overlayBGSprite.GetNinePatchBorderDimension().GetLeft() + overlayBGSprite.GetNinePatchBorderDimension().GetRight()
			Local bgBorderHeight:Int = overlayBGSprite.GetNinePatchBorderDimension().GetTop() + overlayBGSprite.GetNinePatchBorderDimension().GetBottom()

			'overlay background width is overlay + background  borders (the non content area)
			dim.SetX(overlayArea.GetW() + bgBorderWidth)

			If overlayPosition = "iconLeft"
				overlayBGSprite.DrawArea(position.GetX(), position.getY(), dim.GetX(), rect.GetH())
				'move area of overlay (eg. icon) - so it centers on the overlayBG
				overlayArea.position.SetX(bgBorderWidth/2)
			ElseIf overlayPosition = "iconRight"
				overlayBGSprite.DrawArea(position.GetX() + rect.GetW() - dim.GetX(), position.getY(), dim.GetX(), rect.GetH())
				'move area of overlay (eg. icon)
				overlayArea.position.SetX(rect.GetW() - dim.GetX() + bgBorderWidth/2)
			EndIf
		EndIf

		'vertical align overlayArea (ceil: "odd" values get rounded so coords are more likely within button area)
		overlayArea.position.SetY(Float(Ceil((rect.GetH()- overlayArea.GetH())/2)))
		'draw the icon or label if needed
		If GetOverlaySprite()
			GetOverlaySprite().Draw(position.GetX() + overlayArea.GetX(), position.getY() + overlayArea.GetY())
		ElseIf overlayText<>""
			GetFont().Draw(overlayText, position.GetX() + overlayArea.GetX(), position.getY() + overlayArea.GetY(), overlayColor)
		EndIf

		Return dim
	End Method


	Method DrawInputContent:Int(position:TVec2D)
	    Local i:Int	= 0
		Local printValue:String	= value

		'if we are the input receiving keystrokes, symbolize it with the
		'blinking underscore sign "text_"
		'else just draw it like a normal gui object
		If _editable And Self = GuiManager.GetKeystrokeReceiver()
			If editColor
				editColor.SetRGB()
			Else
				color.copy().AdjustFactor(-80).SetRGB()
			EndIf

			If _cursorPosition = -1 Then _cursorPosition = printValue.length

			'calculate values left and right sided of the cursor
			_valueOffset = 0
			Local leftValue:String, rightValue:String
			Local leftValueW:Int, rightValueW:Int
			Local cursorW:Int = 0
			If _cursorPosition = printValue.length
				leftValue = printValue
				rightValue = ""
			ElseIf _cursorPosition = 0
				leftValue = ""
				rightValue = printValue
			Else
				leftValue = printValue[.. _cursorPosition]
				rightValue = printValue[_cursorPosition ..]
			EndIf

			'make sure we see the cursor
			While leftValue.length > 1 And GetFont().getWidth(leftValue) + cursorW > maxTextWidthCurrent
				leftValue = leftValue[1..]
				_valueOffset :+ 1
			Wend
			'beautify: if there is much on the right side left, move it even further to the left
			'if value.length - leftValue.length > 0 and leftValue.length >= 3
			'	leftValue = leftValue[3 ..]
			'endif

			leftValueW = Int(GetFont().getWidth(leftValue))

			'limit rightValue to fit into the left space
			If rightValue <> ""
				While rightValue.length > 0 And GetFont().getWidth(rightValue) > maxTextWidthCurrent - leftValueW - cursorW
					rightValue = rightValue[.. rightValue.length -1]
				Wend
			EndIf


			GetFont().draw(leftValue, position.GetIntX(), position.GetIntY())

			DrawCaret(Int(position.GetIntX() + leftValueW), Int(position.GetY()))

			'ignore cursor-offset (to avoid "letter-jiggling")
			GetFont().draw(rightValue, position.GetIntX() + leftValueW, position.GetIntY())
	    Else
			If printValue.length = 0
				printValue = placeholder
			EndIf

			While printValue.length > 0 And GetFont().GetWidth(printValue) > maxTextWidthCurrent
				printValue = printValue[.. printValue.length - 1]
			Wend

			If textEffectType <> 0
				If value.length = 0
					GetFont().drawStyled(printValue, position.GetIntX(), position.GetIntY(), placeholderColor, textEffectType, 1, textEffectAmount)
				Else
					GetFont().drawStyled(printValue, position.GetIntX(), position.GetIntY(), color, textEffectType, 1, textEffectAmount)
				EndIf
			Else
				If value.length = 0
					GetFont().draw(printValue, position.GetIntX(), position.GetIntY(), placeholderColor)
				Else
					GetFont().draw(printValue, position.GetIntX(), position.GetIntY(), color)
				EndIf
			EndIf
		EndIf

	End Method


	Method DrawCaret(x:Int, y:Int)
		Local oldAlpha:Float = GetAlpha()
		SetAlpha Float(Ceil(Sin(Time.GetTimeGone() / 4)) * oldAlpha)
		DrawLine(x, y, x, y + GetFont().GetMaxCharHeight() )
		SetAlpha oldAlpha
	End Method


	Method DrawContent()
		'to allow modification
		Local atPointX:Int = GetScreenRect().position.x
		Local atPointY:Int = GetScreenRect().position.y
		Local oldCol:TColor = New TColor.Get()
		SetAlpha oldCol.a * GetScreenAlpha()

		Local widgetWidth:Int = rect.GetW()

		If Not _textPos Then _textPos = New TVec2D

		If Not valueDisplacement
			'add "false" to GetMaxCharHeight so it ignores parts of
			'characters with parts below baseline.
			'avoids "above center"-look if value does not contain such
			'characters
			_textPos.Init(2, (rect.GetH() - GetFont().GetMaxCharHeight(False)) /2)
		Else
			_textPos.copyFrom(valueDisplacement)
		EndIf
		_textPos.AddXY(atPointX, atPointY)


		'=== DRAW BACKGROUND SPRITE ===
		'if a spriteName is set, we use a spriteNameDefault,
		'else we just skip drawing the sprite
		Local sprite:TSprite
		If spriteName
			If Self.IsHovered()
				sprite = GetSpriteFromRegistry(GetSpriteName() + ".hover", spriteNameDefault)
			ElseIf Self.IsActive()
				sprite = GetSpriteFromRegistry(GetSpriteName() + ".active", spriteNameDefault)
			Else
				sprite = GetSpriteFromRegistry(GetSpriteName(), spriteNameDefault)
			EndIf
		EndIf
		If sprite
			'draw overlay and save occupied space
			Local overlayDim:TVec2D = DrawButtonOverlay(GetScreenRect().position)

			'move sprite by Icon-Area (and decrease width)
			If overlayPosition = "iconLeft"
				atPointX :+ overlayDim.GetX()
				atPointY :+ overlayDim.GetY()
				_textPos.AddX(overlayDim.GetX())
			EndIf
			widgetWidth :- overlayDim.GetX()

			sprite.DrawArea(atPointX, atPointY, widgetWidth, rect.GetH())
			'move text according to content borders
			_textPos.AddX(sprite.GetNinePatchContentBorder().GetLeft())
			'_textPos.SetX(Max(_textPos.GetX(), sprite.GetNinePatchContentBorder().GetLeft()))
		EndIf


		'=== DRAW TEXT/CONTENT ===
		'limit maximal text width
		If maxTextWidthBase > 0
			Self.maxTextWidthCurrent = Min(maxTextWidthBase, widgetWidth - (_textPos.GetX() - atPointX)*2)
		Else
			Self.maxTextWidthCurrent = widgetWidth - (_textPos.GetX() - atPointX)*2
		EndIf
		'actually draw
		DrawInputContent(_textPos)

		oldCol.SetRGBA()
	End Method


	Method UpdateLayout()
	End Method


	'override
	Method _OnRemoveFocus:Int()
		FinishEdit()
		Return True
	End Method
End Type