Rem
	====================================================================
	Game specific implementation/configuration of the generic
	TToastMessage.
	====================================================================
End Rem

SuperStrict

Import "Dig/base.framework.toastmessage.bmx"
Import "Dig/base.util.registry.spriteloader.bmx"
Import "game.world.worldtime.bmx"
Import "game.gameconstants.bmx"



Type TGameToastMessage Extends TToastMessage
	Field backgroundSprite:TSprite
	Field messageType:Int = 0
	Field messageCategory:Int = TVTMessageCategory.MISC
	Field caption:String = ""
	Field text:String = ""
	Field clickText:String = ""
	'the higher the more important the message is
	Field priority:Int = 0
	Field showBackgroundSprite:Int = True
	'an array containing registered event listeners
	Field _registeredEventListener:TEventListenerBase[]
	Field _closeAtWorldTime:Double = -1
	Field _closeAtWorldTimeText:String = "closing at %TIME%"
	Global spriteNameLS_MessageType_Info:TLowerString = New TLowerString.Create("gfx_toastmessage.info")
	Global spriteNameLS_MessageType_Attention:TLowerString = New TLowerString.Create("gfx_toastmessage.attention")
	Global spriteNameLS_MessageType_Positive:TLowerString = New TLowerString.Create("gfx_toastmessage.positive")
	Global spriteNameLS_MessageType_Negative:TLowerString = New TLowerString.Create("gfx_toastmessage.negative")


	Method New()
		area.dimension.SetXY(250,50)
	End Method


	Method Remove:Int()
		EventManager.UnregisterListenersArray(_registeredEventListener)
		_registeredEventListener = new TEventListenerBase[0]

		Return Super.Remove()
	End Method


	Method SetMessageCategory:Int(messageCategory:Int)
		Self.messageCategory = messageCategory
	End Method


	Method SetMessageType:Int(messageType:Int)
		Self.messageType = messageType

		Select messageType
			Case 0
				Self.backgroundSprite = GetSpriteFromRegistry(spriteNameLS_MessageType_Info)
			Case 1
				Self.backgroundSprite = GetSpriteFromRegistry(spriteNameLS_MessageType_Attention)
			Case 2
				Self.backgroundSprite = GetSpriteFromRegistry(spriteNameLS_MessageType_Positive)
			Case 3
				Self.backgroundSprite = GetSpriteFromRegistry(spriteNameLS_MessageType_Negative)
		EndSelect

		RecalculateHeight()
	End Method


	Method SetCloseAtWorldTimeText:Int(text:String)
		_closeAtWorldTimeText = text
	End Method


	Method AddCloseOnEvent(eventKey:String)
		Local listener:TEventListenerBase = EventManager.registerListenerMethod(eventKey, Self, "onReceiveCloseEvent", Self)
		_registeredEventListener :+ [listener]
	End Method


	Method onReceiveCloseEvent(triggerEvent:TEventSimple)
		Close()
	End Method


	Method SetCaption:Int(caption:String, skipRecalculation:Int=False)
		If Self.caption = caption Then Return False

		Self.caption = caption
		If Not skipRecalculation Then RecalculateHeight()
		Return True
	End Method


	Method SetText:Int(text:String, skipRecalculation:Int=False)
		If Self.text = text Then Return False

		Self.text = text
		If Not skipRecalculation Then RecalculateHeight()
		Return True
	End Method


	Method SetClickText:Int(clickText:String, skipRecalculation:Int=False)
		If Self.clickText = clickText Then Return False

		Self.clickText = clickText
		If Not skipRecalculation Then RecalculateHeight()
		Return True
	End Method


	'override to add height recalculation (as a bar is drawn then)
	Method SetLifeTime:Int(lifeTime:Float = -1)
		Super.SetLifeTime(lifeTime)

		If lifeTime > 0
			RecalculateHeight()
		EndIf
	End Method


	Method SetCloseAtWorldTime:Int(worldTime:Double = -1)
		_closeAtWorldTime = worldTime
		If _closeAtWorldTime > 0 And _closeAtWorldTimeText <> ""
			RecalculateHeight()
		EndIf
	End Method


	Method SetPriority:Int(priority:Int=0)
		Self.priority = priority
	End Method


	Method RecalculateHeight:Int()
		Local height:Int = 0
		'caption singleline
		'height :+ GetBitmapFontManager().baseFontBold.GetMaxCharHeight()
		height :+ GetBitmapFontManager().baseFontBold.GetBlockDimension(caption, GetContentWidth(), -1).GetY()
		'text
		'attention: subtract some pixels from width (to avoid texts fitting
		'because of rounding errors - but then when drawing they do not
		'fit)
		height :+ GetBitmapFontManager().baseFont.GetBlockDimension(text, GetContentWidth(), -1).GetY()
		If clickText
			height :+ GetBitmapFontManager().baseFont.GetBlockDimension(clickText, GetContentWidth(), -1).GetY()
		EndIf
		'gfx padding
		If showBackgroundSprite And backgroundSprite
			height :+ backgroundSprite.GetNinePatchContentBorder().GetTop()
			height :+ backgroundSprite.GetNinePatchContentBorder().GetBottom()
		EndIf
		'lifetime bar
		If _lifeTime > 0 Then height :+ 5
		'close hint
		If _closeAtWorldTime > 0 And _closeAtWorldTimeText <> ""
			height :+ GetBitmapFontManager().baseFontBold.GetMaxCharHeight()
		EndIf

		area.dimension.SetY(height)
	End Method


	Method GetContentWidth:Int()
		If showBackgroundSprite And backgroundSprite
			Return GetScreenRect().GetW() - backgroundSprite.GetNinePatchContentBorder().GetLeft() - backgroundSprite.GetNinePatchContentBorder().GetRight()
		Else
			Return GetScreenRect().GetW()
		EndIf
	End Method


	'override to add worldTime
	Method Update:Int()
		'check if lifetime is running out - close message then
		If _closeAtWorldTime >= 0 And Not HasStatus(TOASTMESSAGE_OPENING_OR_CLOSING)
			If _closeAtWorldTime < GetWorldTime().GetTimeGone()
				close()
			EndIf
		EndIf

		Return Super.Update()
	End Method


	'override to draw our nice background
	Method RenderBackground:Int(xOffset:Float=0, yOffset:Float=0)
		If showBackgroundSprite
			'set type again to reload sprite
			If Not backgroundSprite Or backgroundSprite.name = "defaultsprite" Then SetMessageType(messageType)
			If backgroundSprite
				Local oldAlpha:Float = GetAlpha()
				SetAlpha oldAlpha * 0.80
				backgroundSprite.DrawArea(xOffset + GetScreenRect().GetX(), yOffset + GetScreenRect().GetY(), area.GetW(), area.GetH())
				SetAlpha oldAlpha
			EndIf
		EndIf
	End Method


	'override to draw our texts
	Method RenderForeground:Int(xOffset:Float=0, yOffset:Float=0)
		Local contentX:Int = xOffset + GetScreenRect().GetX()
		Local contentY:Int = yOffset + GetScreenRect().GetY()
		Local contentX2:Int = contentX + GetScreenRect().GetW()
		Local contentY2:Int = contentY + GetScreenRect().GetH()
		If showBackgroundSprite And backgroundSprite
			contentX :+ backgroundSprite.GetNinePatchContentBorder().GetLeft()
			contentY :+ backgroundSprite.GetNinePatchContentBorder().GetTop()
			contentX2 :- backgroundSprite.GetNinePatchContentBorder().GetRight()
			contentY2 :- backgroundSprite.GetNinePatchContentBorder().GetBottom()
		EndIf

		Local captionH:Int ' = GetBitmapFontManager().baseFontBold.GetMaxCharHeight()
		Local textH:Int ' = GetBitmapFontManager().baseFontBold.GetMaxCharHeight()
		Local captionDim:TVec2D = New TVec2D
		GetBitmapFontManager().baseFontBold.DrawBlock(caption, contentX, contentY, GetContentWidth(), -1, Null, TColor.clBlack, , , , , , , captionDim)
		captionH :+ captionDim.y
		GetBitmapFontManager().baseFont.DrawBlock(text+clickText, contentX, contentY + captionH, GetContentWidth(), -1, Null, TColor.CreateGrey(50))


		'worldtime close hint
		If _closeAtWorldTime > 0 And _closeAtWorldTimeText <> ""
			Local text:String = GetLocale(_closeAtWorldTimeText)
			text = text.Replace("%H%", GetWorldTime().GetDayHour(_closeAtWorldTime))
			text = text.Replace("%I%", GetWorldTime().GetDayMinute(_closeAtWorldTime))
			text = text.Replace("%S%", GetWorldTime().GetDaySecond(_closeAtWorldTime))
			text = text.Replace("%D%", GetWorldTime().GetOnDay(_closeAtWorldTime))
			text = text.Replace("%Y%", GetWorldTime().GetYear(_closeAtWorldTime))
			text = text.Replace("%SEASON%", GetWorldTime().GetSeason(_closeAtWorldTime))

			Local timeString:String = GetWorldTime().GetFormattedTime(_closeAtWorldTime)
			'prepend day if it does not finish today
			If GetWorldTime().GetDay() < GetWorldTime().GetDay(_closeAtWorldTime)
				timeString = GetWorldTime().GetFormattedDay(GetWorldTime().GetDaysRun(_closeAtWorldTime) +1 ) + " " + timeString
			EndIf
			text = text.Replace("%TIME%", timeString)

			GetBitmapFontManager().baseFontItalic.DrawBlock(text, contentX, contentY2 - GetBitmapFontManager().baseFontBold.GetMaxCharHeight(), contentX2 - contentX, -1, Null, TColor.CreateGrey(40))
		EndIf

		'lifetime bar
		If _lifeTime > 0
			Local lifeTimeWidth:Int = contentX2 - contentX
			Local oldCol:TColor = New TColor.Get()
			lifeTimeWidth :* GetLifeTimeProgress()

			If priority <= 2
				SetAlpha oldCol.a * 0.2 + 0.05*priority
				SetColor(120,120,120)
			ElseIf priority <= 5
				SetAlpha oldCol.a * 0.3 + 0.1*priority
				SetColor(200,150,50)
			Else
				SetAlpha oldCol.a * 0.5 + 0.05*priority
				SetColor(255,80,80)
			EndIf
			'+2 = a bit of padding
			DrawRect(contentX, contentY2 - 5 + 2, lifeTimeWidth, 3)
			oldCol.SetRGBA()
		EndIf

	End Method
End Type
