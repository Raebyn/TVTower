Rem
	===========================================================
	GUI Button
	===========================================================
End Rem
SuperStrict
Import "base.gfx.gui.bmx"
Import "base.gfx.gui.label.bmx"
Import "base.util.registry.spriteloader.bmx"



Type TGUIButton Extends TGUIobject
	Field manualState:Int = 0
	Field spriteName:String = "gfx_gui_button.default"
	Field _sprite:TSprite 'private
	Field caption:TGUILabel	= Null
	Field captionArea:TRectangle = Null
	Field autoSizeModeWidth:Int = 0
	Field autoSizeModeHeight:Int = 0

	Global AUTO_SIZE_MODE_NONE:Int = 0
	Global AUTO_SIZE_MODE_TEXT:Int = 1
	Global AUTO_SIZE_MODE_SPRITE:Int = 2
	Global _typeDefaultFont:TBitmapFont
	Global _typeDefaultCaptionColor:TColor


	Method GetClassName:String()
		Return "tguibutton"
	End Method


	Method Create:TGUIButton(pos:TVec2D, dimension:TVec2D, value:String, State:String = "")
		'setup base widget
		Super.CreateBase(pos, dimension, State)

		SetValue(value)

    	GUIManager.Add(Self)
		Return Self
	End Method


	'override
	Method onClick:Int(triggerEvent:TEventBase)
		Super.onClick(triggerEvent)
		'send a more specialized event
		If Not triggerEvent.isVeto()
			EventManager.triggerEvent( TEventSimple.Create("guibutton.OnClick", triggerEvent._data, Self) )
		EndIf
	End Method


	Method RepositionCaption:Int()
		If Not caption Then Return False

		'resize to button dimension
		If captionArea
			Local newX:Float = captionArea.GetX()
			Local newY:Float = captionArea.GetY()
			Local newDimX:Float = captionArea.GetW()
			Local newDimY:Float = captionArea.GetH()
			'use parent values
			If newX = -1 Then newX = 0
			If newY = -1 Then newY = 0
			'take all the space left
			If newDimX <= 0 Then newDimX = rect.GetW() - newX
			If newDimY <= 0 Then newDimY = rect.GetH() - newY

			caption.SetPosition(newX, newY)
			caption.SetSize(newDimX, newDimY)
		Else
			caption.SetPosition(0, 0)
			caption.SetSize(rect.dimension.GetX(), rect.dimension.GetY())
		EndIf
	End Method


	'override SetSize() to add autocalculation and caption handling
	'size 0, 0 is not possible (leads to autosize)
	Method SetSize(w:Float = 0, h:Float = 0)
		If h <= 0 then h = rect.GetH()
rem
		'autocalculate width/height
		If w <= 0
			If autoSizeModeWidth = AUTO_SIZE_MODE_TEXT
				w = GetFont().GetWidth(value) + 8
			ElseIf autoSizeModeWidth = AUTO_SIZE_MODE_SPRITE
				w = GetSprite().GetWidth(False)
			EndIf
		EndIf
		If h <= 0
			h = rect.GetH()
			If autoSizeModeHeight <> AUTO_SIZE_MODE_NONE Or h = -1

				If autoSizeModeHeight = AUTO_SIZE_MODE_TEXT
					h = GetFont().GetMaxCharHeight()
				EndIf

				'if height is less then sprite height (the "minimum")
				'use this
				h = Max(h, GetSprite().GetHeight(False))
			EndIf
		EndIf
endrem

		Super.SetSize(w, h)
	End Method


	Method SetAutoSizeMode(modeWidth:Int = 1, modeHeight:Int = 1)
		If autoSizeModeWidth <> modeWidth Or autoSizeModeHeight <> modeHeight
			autoSizeModeWidth = modeWidth
			autoSizeModeHeight = modeHeight

			InvalidateLayout()
		EndIf
	End Method


	'override to inform other elements too
	Method SetAppearanceChanged:Int(bool:Int)
		Super.SetAppearanceChanged(bool)
		'only inform if changed
		If bool = True
			If caption Then caption.SetAppearanceChanged(bool)
		EndIf
	End Method



	'acts as cache
	Method GetSprite:TSprite()
		'refresh cache if not set or wrong sprite name
		If Not _sprite Or _sprite.GetName() <> spriteName
			_sprite = GetSpriteFromRegistry(spriteName)
			'new -non default- sprite: adjust appearance
			If _sprite.GetName() <> "defaultsprite"
				SetAppearanceChanged(True)
			EndIf
		EndIf
		Return _sprite
	End Method


	'override default - to use caption instead of value
	Method SetValue(value:String)
		SetCaption(value)
	End Method


	'override default - to use caption instead of value
	Method GetValue:String()
		If Not caption Then Return Super.GetValue()
		Return caption.GetValue()
	End Method


	Method SetCaption:Int(text:String, color:TColor=Null)
		If Not caption
			'caption area starts at top left of button
			caption = New TGUILabel.Create(Null, text, color, Null)
			caption.SetContentAlignment(ALIGN_CENTER, ALIGN_CENTER)
			'we want the caption to use the buttons font
			caption.SetOption(GUI_OBJECT_FONT_PREFER_PARENT_TO_TYPE, True)
			'we want to manage it...
			GUIManager.Remove(caption)

			'reposition the caption
			RepositionCaption()

			'assign button as parent of caption
			caption.SetParent(Self)
		ElseIf caption.value <> text
			caption.SetValue(text)
		EndIf

		If color
			caption.color = color
		ElseIf _typeDefaultCaptionColor
			caption.color = _typeDefaultCaptionColor
		EndIf
	End Method


	Method SetCaptionOffset:Int(x:Int = -1, y:Int = -1)
		If Not captionArea Then captionArea = New TRectangle
		captionArea.position.SetXY(x,y)

		if caption then caption.InvalidateScreenRect()
	End Method


	Function SetTypeCaptionColor:Int(color:TColor)
		_typeDefaultCaptionColor = color.Copy()
	End Function


	Function SetTypeFont:Int(font:TBitmapFont)
		_typeDefaultFont = font
	End Function


	'override in extended classes if wanted
	Function GetTypeFont:TBitmapFont()
		Return _typeDefaultFont
	End Function


	Method GetSpriteName:String()
		Return spriteName
	End Method


	Method SetCaptionAlign(alignType:String = "LEFT", valignType:String = "CENTER")
		If Not caption Then Return

		'by default labels have left aligned content
		Select aligntype.ToUpper()
			Case "CENTER" 	caption.SetContentAlignment(ALIGN_LEFT, caption.contentAlignment.y)
			Case "RIGHT" 	caption.SetContentAlignment(ALIGN_RIGHT, caption.contentAlignment.y)
			Default		 	caption.SetContentAlignment(ALIGN_CENTER, caption.contentAlignment.y)
		End Select
	End Method


	'override to update caption
	Method Update:Int()
		Super.Update()
		If caption Then caption.Update()
	End Method


	Method DrawButtonContent:Int(position:TVec2D)
		If Not caption Then Return False
		If Not caption.IsVisible() Then Return False

		'move caption
		If IsActive()
			caption.GetScreenRect().position.AddXY(1,1)
			caption.Draw()
			caption.GetScreenRect().position.AddXY(-1,-1)
		Else
			caption.Draw()
		EndIf
	End Method


	Method DrawContent()
		Local atPoint:TVec2D = GetScreenRect().position
		Local oldCol:TColor = New TColor.Get()

		SetColor 255, 255, 255
		SetAlpha oldCol.a * GetScreenAlpha()

		Local sprite:TSprite = GetSprite()
		If Not IsEnabled()
			sprite = GetSpriteFromRegistry(GetSpriteName() + ".disabled", sprite)
		Else
			sprite = GetSpriteFromRegistry(GetSpriteName() + GetStateSpriteAppendix(), sprite)
		EndIf

		If sprite
			'no active image available (when "mousedown" over widget)
			If IsActive() And (sprite.name = spriteName Or sprite.name="defaultsprite")
				sprite.DrawArea(atPoint.getX()+1, atPoint.getY()+1, rect.GetW(), rect.GetH())
			Else
				sprite.DrawArea(atPoint.getX(), atPoint.getY(), rect.GetW(), rect.GetH())
			EndIf
		EndIf

		'draw label/caption of button
		DrawButtonContent(atPoint)

		oldCol.SetRGBA()
	End Method


	'override
	Method UpdateLayout()
		'autocalculate width/height
		If autoSizeModeWidth = AUTO_SIZE_MODE_TEXT
			rect.SetW( GetFont().GetWidth(value) + 8)
		ElseIf autoSizeModeWidth = AUTO_SIZE_MODE_SPRITE
			rect.SetW( GetSprite().GetWidth(False) )
		EndIf

		If autoSizeModeHeight <> AUTO_SIZE_MODE_NONE Or rect.GetH() = -1
			If autoSizeModeHeight = AUTO_SIZE_MODE_TEXT
				rect.SetH( GetFont().GetMaxCharHeight() )
			EndIf

			'if height is less then sprite height (the "minimum")
			'use this
			rect.SetH( Max(rect.GetH(), GetSprite().GetHeight(False)) )
		EndIf

		'move caption according to its rules
		RepositionCaption()
	End Method


	Method InvalidateScreenRect:TRectangle()
		Super.InvalidateScreenRect()
		if caption then caption.InvalidateScreenRect()
	End Method


	Method InvalidateContentScreenRect()
		Super.InvalidateContentScreenRect()
		if caption then caption.InvalidateContentScreenRect()
	End Method


	'override
	Method OnReposition(dx:Float, dy:Float)
		If dx = 0 And dy = 0 Then Return

		Super.OnReposition(dx, dy)
		If caption Then caption.OnReposition(dx, dy)
	End Method


	Method OnParentReposition(parent:TGUIObject, dx:Float, dy:Float)
		Super.OnParentReposition(parent,dx,dy)
		If caption Then caption.OnParentReposition(Self, dx, dy)
	End Method
End Type
