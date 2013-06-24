'Application: TVGigant/TVTower
'Author: Ronny Otto

SuperStrict
Import brl.timer
Import brl.Graphics
Import "basefunctions_network.bmx"
Import "basefunctions.bmx"						'Base-functions for Color, Image, Localization, XML ...
Import "basefunctions_sound.bmx"
Import "basefunctions_guielements.bmx"			'Guielements like Input, Listbox, Button...
Import "basefunctions_events.bmx"				'event handler
Import "basefunctions_deltatimer.bmx"
Import "basefunctions_lua.bmx"					'our lua engine
Import "basefunctions_resourcemanager.bmx"

?Linux
Import "external/bufferedglmax2d/bufferedglmax2d.bmx"
?Win32
Import brl.D3D9Max2D
Import brl.D3D7Max2D
?

Include "gamefunctions.bmx" 					'Types: - TError - Errorwindows with handling
												'		- base class For buttons And extension newsbutton
												'		- stationmap-handling, -creation ...


Global VersionDate:String		= LoadText("incbin::source/version.txt")
Global VersionString:String		= "version of " + VersionDate
Global CopyrightString:String	= "by Ronny Otto & Manuel V�gele"
AppTitle = "TVTower: " + VersionString + " " + CopyrightString

Global App:TApp = TApp.Create(60, 60) 'create with 60fps for physics and graphics
App.LoadResources("config/resources.xml")

GUIManager.globalScale	= 1.00
GUIManager.defaultFont	= Assets.GetFont("Default", 12)
Include "gamefunctions_tvprogramme.bmx"  		'contains structures for TV-programme-data/Blocks and dnd-objects
Include "gamefunctions_rooms.bmx"				'basic roomtypes with handling
Include "gamefunctions_ki.bmx"					'LUA connection
Include "gamefunctions_sound.bmx"				'TVTower spezifische Sounddefinitionen


Global ArchiveProgrammeList:TgfxProgrammelist	= TgfxProgrammelist.Create(575, 16, 21)

Global SaveError:TError, LoadError:TError
Global ExitGame:Int 							= 0 			'=1 and the game will exit
Global Fader:TFader								= New TFader
Global NewsAgency:TNewsAgency					= New TNewsAgency

SeedRand(103452)
Print "seedRand festgelegt - bei Netzwerk bitte jeweils neu ausw�rfeln und bei join mitschicken - fuer Testzwecke aber aktiv, immer gleiches Programm"

TTooltip.UseFontBold	= Assets.fonts.baseFontBold
TTooltip.UseFont 		= Assets.fonts.baseFont
TTooltip.ToolTipIcons	= Assets.GetSprite("gfx_building_tooltips")
TTooltip.TooltipHeader	= Assets.GetSprite("gfx_tooltip_header")


rem
Enthaelt Verbindung zu Einstellungen und Timern
sonst nix
endrem
Type TApp
	Field Timer:TDeltaTimer
	Field limitFrames:Int				= 0
	Field settings:TApplicationSettings
	Field prepareScreenshot:Int			= 0						'logo for screenshot
	Field g:TGraphics

	Field creationTime:int 'only used for debug purpose (loadingtime)
	global lastLoadEvent:TEventSimple	= null
	global baseResourcesLoaded:int		= 0						'able to draw loading screen?
	global baseResourceXmlUrl:string	= "config/startup.xml"	'holds bg for loading screen and more
	global currentResourceUrl:string	= ""
	global maxResourceCount:int			= 331					'set to <=0 to get a output of loaded resources

	global LogoFadeInFirstCall:Int		= 0
	global LoaderWidth:Int				= 0


	Function Create:TApp(updatesPerSecond:Int = 60, framesPerSecond:Int = 60)
		Local obj:TApp = New TApp
		obj.creationTime = Millisecs()
		obj.settings = new TApplicationSettings
		'create timer
		obj.timer = TDeltaTimer.Create(updatesPerSecond, framesPerSecond)
		'listen to App-timer
		'-register to draw loading screen
		EventManager.registerListenerFunction( "App.onDraw", 	TApp.drawLoadingScreen )
		'-register for each toLoad-Element from XML files
		EventManager.registerListenerFunction( "XmlLoader.onLoadElement",	TApp.onLoadElement )
		EventManager.registerListenerFunction( "XmlLoader.onFinishParsing",	TApp.onFinishParsingXML )
		EventManager.registerListenerFunction( "Loader.onLoadElement",	TApp.onLoadElement )

		obj.LoadSettings("config/settings.xml")
		obj.InitGraphics()
		'load graphics needed for loading screen
		obj.currentResourceUrl = obj.baseResourceXmlUrl
		obj.LoadResources(obj.baseResourceXmlUrl)


		Return obj
	End Function

	Method LoadSettings:int(path:string="config/settings.xml")
		Local xml:TXmlHelper = TXmlHelper.Create(path)
		local node:TXmlNode = xml.findRootChild("settings")
		If node = Null Or node.getName() <> "settings" then	Print "settings.xml fehlt der settings-Bereich"

		self.settings.fullscreen	= xml.FindValueInt(node, "fullscreen", self.settings.fullscreen, "settings.xml fehlt 'fullscreen', setze Defaultwert: "+self.settings.fullscreen)
		self.settings.directx		= xml.FindValueInt(node, "directx", self.settings.directx, "settings.xml fehlt 'directx', setze Defaultwert: "+self.settings.directx+" (OpenGL)")
		self.settings.colordepth	= xml.FindValueInt(node, "colordepth", self.settings.colordepth, "settings.xml fehlt 'colordepth', setze Defaultwert: "+self.settings.colordepth)

		If self.settings.colordepth <> 16 And self.settings.colordepth <> 32
			Print "settings.xml enthaelt fehlerhaften Eintrag fuer 'colordepth', setze Defaultwert: 16"
			self.settings.colordepth = 16
		EndIf
	End Method

	Method LoadResources:int(path:string="config/resources.xml")
		local XmlLoader:TXmlLoader = TXmlLoader.Create()
		XmlLoader.Parse(path)
		Assets.AddSet(XmlLoader.Values) 'copy XML-values
	End Method

	Method StartApp()
		EventManager.unregisterAllListeners( "App.onDraw" )
		EventManager.registerListener( "App.onUpdate", 	TEventListenerOnAppUpdate.Create() )
		EventManager.registerListener( "App.onDraw", 	TEventListenerOnAppDraw.Create() )
		EventManager.registerListener( "App.onSoundUpdate", TEventListenerOnSoundUpdate.Create() )
		SoundManager.PlayMusic(MUSIC_TITLE)
		print "LADEZEIT : "+(Millisecs() - self.creationTime) +"ms"
	End Method

	Method InitGraphics:int()
		Try
			Select Settings.directx
				?Win32
				Case  1	SetGraphicsDriver D3D7Max2DDriver()
				Case  2	SetGraphicsDriver D3D9Max2DDriver()
				?
				Case -1 SetGraphicsDriver GLMax2DDriver()
				'Default SetGraphicsDriver BufferedGLMax2DDriver()
				Default SetGraphicsDriver GLMax2DDriver()
			EndSelect
			g = Graphics(Settings.width, Settings.height, Settings.colordepth*Settings.fullscreen, Settings.Hertz, Settings.flag)
			If g = Null
			?Win32
				Throw "Graphics initiation error! The game will try to open in windowed DirectX 7 mode."
				SetGraphicsDriver D3D7Max2DDriver()
				g = Graphics(Settings.width, Settings.height, 0, Settings.Hertz)
			?not Win32
				Throw "Graphics initiation error! no OpenGL available."
			?
			EndIf
		EndTry
		SetBlend ALPHABLEND
		SetMaskColor 0, 0, 0
		HideMouse()
	End Method

	Function onFinishParsingXML( triggerEvent:TEventBase )
		Local evt:TEventSimple = TEventSimple(triggerEvent)
		If evt<>Null
			if evt.getData().getString("url") = TApp.baseResourceXmlUrl then TApp.baseResourcesLoaded = 1
			if TApp.maxResourceCount <= 0 then print "loaded items from xml: "+evt.getData().getInt("loaded")
		endif
	End Function

	Function onLoadElement( triggerEvent:TEventBase )
		TApp.lastLoadEvent = TEventSimple(triggerEvent)
		if TApp.baseResourcesLoaded
			App.timer.loop()
 		endif
	End Function

	Function drawLoadingScreen( triggerEvent:TEventBase )
		Local evt:TEventSimple = TApp.lastLoadEvent
		If evt<>Null
			local element:string		= evt.getData().getString("element")
			local text:string			= evt.getData().getString("text")
			local itemNumber:int		= evt.getData().getInt("itemNumber")
			local error:int				= evt.getData().getInt("error")
			local maxItemNumber:int		= 0
			if itemNumber > 0 then maxItemNumber = evt.getData().getInt("maxItemNumber")

			if element = "XmlFile" then TApp.currentResourceUrl = text

			SetColor 255, 255, 255
			Assets.GetSprite("gfx_startscreen").Draw(0,0)

			If LogoFadeInFirstCall = 0 Then LogoFadeInFirstCall = MilliSecs()
			SetAlpha Float(Float(MilliSecs() - LogoFadeInFirstCall) / 750.0)
			Assets.GetSprite("gfx_startscreen_logo").Draw( App.settings.width/2 - Assets.GetSprite("gfx_startscreen_logo").w / 2, 100)
			SetAlpha 1.0
			Assets.GetSprite("gfx_startscreen_loadingBar").Draw( 400, 376, 1, 0, 0.5)

			LoaderWidth = Min(680, LoaderWidth + (680.0 / TApp.maxResourceCount))
			Assets.GetSprite("gfx_startscreen_loadingBar").TileDraw((400-Assets.GetSprite("gfx_startscreen_loadingBar").framew / 2) ,376,LoaderWidth, Assets.GetSprite("gfx_startscreen_loadingBar").frameh)
			SetColor 0,0,0
			if itemNumber > 0
				SetAlpha 0.25
				DrawText "[" + Replace(RSet(itemNumber, string(maxItemNumber).length), " ", "0") + "/" + maxItemNumber + "]", 670, 415
				DrawText TApp.currentResourceUrl, 80, 402
			endif
			SetAlpha 0.5
			DrawText "Loading: "+text, 80, 415
			SetAlpha 1.0
			if error > 0
				SetColor 255, 0 ,0
				DrawText("ERROR: ", 80,440)
				SetAlpha 0.75
				DrawText(text+" not found. (press ESC to exit)", 130,440)
				SetAlpha 1.0
			endif
			SetColor 255, 255, 255

			'base cursor
			Assets.GetSprite("gfx_mousecursor").Draw(MouseX()-7, 	MouseY()	,0)

			Flip 0
		endif
	End Function
End Type


Const GAMESTATE_RUNNING:Int					= 0
Const GAMESTATE_MAINMENU:Int				= 1
Const GAMESTATE_NETWORKLOBBY:Int			= 2
Const GAMESTATE_SETTINGSMENU:Int			= 3
Const GAMESTATE_STARTMULTIPLAYER:Int		= 4		'mode when data gets synchronized

'Game - holds time, audience, money and other variables (typelike structure makes it easier to save the actual state)
Type TGame {_exposeToLua="selected"}
	''rename CONFIG-vars ... config_DoorOpenTime... config_gameSpeed ...
	Const maxAbonnementLevel:Int		= 3

	Field maxAudiencePercentage:Float 	= 0.3	{nosave}	'how many 0.0-1.0 (100%) audience is maximum reachable
	Field maxContractsAllowed:Int 		= 8		{nosave}	'how many contracts a player can possess
	Field maxMoviesInSuitcaseAllowed:Int= 12	{nosave}	'how many movies can be carried in suitcase
	Field startMovieAmount:Int 			= 5		{nosave}	'how many movies does a player get on a new game
	Field startSeriesAmount:Int			= 1		{nosave}	'how many series does a player get on a new game
	Field startAdAmount:Int				= 3		{nosave}	'how many contracts a player gets on a new game
	Field debugmode:Byte				= 0		{nosave}	'0=no debug messages; 1=some debugmessages
	Field DebugInfos:Byte				= 0		{nosave}

	Field daynames:String[]						{nosave}	'array of abbreviated (short) daynames
	Field daynamesLong:String[] 				{nosave}	'array of daynames (long version)
	Field DoorOpenTime:Int				= 100	{nosave}	'time how long a door will be shown open until figure enters

	Field username:String				= ""	{nosave}	'username of the player ->set in config
	Field userport:Short				= 4544	{nosave}	'userport of the player ->set in config
	Field userchannelname:String		= ""	{nosave}	'channelname the player uses ->set in config
	Field userlanguage:String			= "de"	{nosave}	'language the player uses ->set in config
	Field userdb:String					= ""	{nosave}
	Field userfallbackip:String			= "" 	{nosave}

	Field speed:Float				= 0.1 					'Speed of the game
	Field oldspeed:Float			= 0.1 					'Speed of the game - used when saving a game ("pause")
	Field minutesOfDayGone:Float	= 0.0					'time of day in game, unformatted
	Field lastMinutesOfDayGone:Float= 0.0					'time last update was done
	Field timeGone:Double			= 0.0					'time in game, not reset every day
	Field timeStart:Double			= 0.0					'time used when starting the game
	Field daysPlayed:int			= 0
	const daysPerYear:int			= 14 					'5 weeks
	Field daytoplan:Int 			= 0						'which day has to be shown in programmeplanner

	Field title:String 				= "MyGame"				'title of the game

	Field cursorstate:Int		 	= 0 					'which cursor has to be shown? 0=normal 1=dragging
	Field playerID:Int 				= 1						'playerID of player who sits in front of the screen
	Field error:Int 				= 0 					'is there a error (errorbox) floating around?
	Field gamestate:Int 			= 0						'0 = Mainmenu, 1=Running, ...

	Field stateSyncTime:Int			= 0						'last sync
	Field stateSyncTimer:Int		= 2000					'sync every

	'--networkgame auf "isNetworkGame()" umbauen
	Field networkgame:Int 			= 0 					'are we playing a network game? 0=false, 1=true, 2
	Field networkgameready:Int 		= 0 					'is the network game ready - all options set? 0=false
	Field onlinegame:Int 			= 0 					'playing over internet? 0=false

	'Summary: saves the GameObject to a XMLstream
	Function REMOVE_Save:Int()
		LoadSaveFile.xmlBeginNode("GAMESETTINGS")
		Local typ:TTypeId = TTypeId.ForObject(Game)
		For Local t:TField = EachIn typ.EnumFields()
			If t.MetaData("saveload") <> "nosave" Or t.MetaData("saveload") = "normal"
				LoadSaveFile.xmlWrite(Upper(t.Name()), String(t.Get(Game)))
			EndIf
		Next
		LoadSaveFile.xmlCloseNode()
	End Function

	'Summary: loads the GameObject from a XMLstream
	Function REMOVE_Load:Int()
Print "implement TGame:Load"
Return 0
Rem
		PrintDebug("TGame.Load()", "Lade Spieleinstellungen", DEBUG_SAVELOAD)
		Local NODE:xmlNode = LoadSaveFile.NODE.FirstChild()
		Local nodevalue:String
		While NODE <> Null
			nodevalue = ""
			If NODE.hasAttribute("var", False) Then nodevalue = NODE.Attribute("var").Value
			Local typ:TTypeId = TTypeId.ForObject(Game)
			For Local t:TField = EachIn typ.EnumFields()
				If (t.MetaData("saveload") = "normal" Or t.MetaData("saveload") <> "nosave") And Upper(t.Name()) = NODE.Name
					t.Set(Game, nodevalue)
				EndIf
			Next
			NODE = NODE.nextSibling()
		Wend
endrem
	End Function

	'Summary: saves all objects of the game (figures, quotes...)
	Function SaveGame:Int(savename:String="savegame.xml")
		LoadSaveFile.InitSave()   'opens a savegamefile for getting filled
		For Local i:Int = 1 To 4
			If Players[i] <> Null
				If Players[i].PlayerKI = Null And Players[i].figure.controlledbyID = 0 Then PrintDebug ("TGame.Update()", "FEHLER: KI fuer Spieler " + i + " nicht gefunden", DEBUG_UPDATES)
				If Players[i].figure.controlledbyID = 0
					LoadSaveFile.xmlWrite("KI"+i, Players[i].PlayerKI.CallOnSave())
				EndIf
			EndIf
		Next
		LoadSaveFile.SaveObject(Game, "GAMESETTINGS", Null) ; TError.DrawErrors() ;Flip 0  'XML
		LoadSaveFile.SaveObject(TFigures.List, "FIGURES", TFigures.AdditionalSave) ; TError.DrawErrors() ;Flip 0  'XML
		LoadSaveFile.SaveObject(TPlayer.List, "PLAYERS", TFigures.AdditionalSave) ; TError.DrawErrors() ;Flip 0  'XML


		TStationMap.SaveAll();				TError.DrawErrors();Flip 0  'XML
		TAudienceQuotes.SaveAll();			TError.DrawErrors();Flip 0  'XML
		TProgramme.SaveAll();	 			TError.DrawErrors();Flip 0  'XML
		TContract.SaveAll();	  			TError.DrawErrors();Flip 0  'XML
		TNews.SaveAll();	  				TError.DrawErrors();Flip 0  'XML
		TContractBlock.SaveAll();			TError.DrawErrors();Flip 0  'XML
		TProgrammeBlock.SaveAll();			TError.DrawErrors();Flip 0  'XML
		TAdBlock.SaveAll();					TError.DrawErrors();Flip 0  'XML
		TNewsBlock.SaveAll();				TError.DrawErrors();Flip 0  'XML
		TMovieAgencyBlocks.SaveAll();		TError.DrawErrors();Flip 0  'XML
		TArchiveProgrammeBlock.SaveAll();	TError.DrawErrors();Flip 0  'XML
		Building.Elevator.Save();			TError.DrawErrors();Flip 0  'XML
		'Delay(50)
		LoadSaveFile.xmlWrite("ENDSAVEGAME", "CHECKSUM")
		'LoadSaveFile.file.setCompressMode(9)
		LoadSaveFile.xmlSave("savegame.zip", True)
		'LoadSaveFile.file.Free()
	End Function

	'Summary: loads all objects of the games (figures, programme...)
	Function LoadGame:Int(savename:String="save")
		PrintDebug("TGame.LoadGame()", "Leere Listen", DEBUG_SAVELOAD)
		TError(TError.List.Last()).message = "Leere Listen...";TError.DrawErrors() ;Flip 0
		PrintDebug("TGame.LoadGame()", "Lade Spielstandsdatei", DEBUG_SAVELOAD)
		TError.DrawNewError("Lade Spielstandsdatei...")
		LoadSaveFile.InitLoad("savegame.zip", True)
		If LoadSaveFile.xml.file = Null
			PrintDebug("TGame.LoadGame()", "Spielstandsdatei defekt!", DEBUG_SAVELOAD)
			TError.DrawNewError("Spielstandsdatei defekt!...") ;Delay(2500)
		Else
			Local NodeList:TList = LoadSaveFile.node.getChildren()
			For Local NODE:TxmlNode = EachIn NodeList
				LoadSaveFile.NODE = NODE
				Select LoadSaveFile.NODE.getName()
					Case "KI1"
						Players[1].PlayerKI.CallOnLoad(LoadSaveFile.NODE.getContent())
					Case "KI2"
						Players[2].PlayerKI.CallOnLoad(LoadSaveFile.NODE.getContent())
					Case "KI3"
						Players[3].PlayerKI.CallOnLoad(LoadSaveFile.NODE.getContent())
					Case "KI4"
						Players[4].PlayerKI.CallOnLoad(LoadSaveFile.NODE.getContent())
					Case "GAMESETTINGS"
						TError.DrawNewError("Lade Basiseinstellungen...")
						TGame.REMOVE_Load()
					Case "ALLFIGURES"
						TError.DrawNewError("Lade Spielfiguren...")
						TFigures.LoadAll()
					Case "ALLPLAYERS"
						TError.DrawNewError("Lade Spieler...")
						TPlayer.LoadAll()
					Case "ALLSTATIONMAPS"
						TError.DrawNewError("Lade Senderkarten...")
						TStationMap.LoadAll()
					Case "ALLAUDIENCEQUOTES"
						TError.DrawNewError("Lade Quotenarchiv...")
						TAudienceQuotes.LoadAll()
					Case "ALLPROGRAMMES"
						TError.DrawNewError("Lade Programme...")
						TProgramme.LoadAll()
					Case "ALLCONTRACTS"
						TError.DrawNewError("Lade Werbevertr�ge...")
					'TContract.LoadAll()
					Case "ALLNEWS"
						TError.DrawNewError("Lade Nachrichten...")
					'TNews.LoadAll()
					Case "ALLCONTRACTBLOCKS"
						TError.DrawNewError("Lade Werbevertr�gebl�cke...")
					'TContractBlock.LoadAll()
					Case "ALLPROGRAMMEBLOCKS"
						TError.DrawNewError("Lade Programmbl�cke...")
					'TProgrammeBlock.LoadAll()
					Case "ALLADBLOCKS"
						TError.DrawNewError("Lade Werbebl�cke...")
					'TAdBlock.LoadAll()
					Case "ALLNEWSBLOCKS"
						TError.DrawNewError("Lade Newsbl�cke...")
					'TNewsBlock.LoadAll()
					Case "ALLMOVIEAGENCYBLOCKS"
						TError.DrawNewError("Lade Filmh�ndlerbl�cke...")
					'TMovieAgencyBlocks.LoadAll()
					Case "ELEVATOR"
						TError.DrawNewError("Lade Fahrstuhl...")
					'building.elevator.Load()
				End Select
			Next
			Print "verarbeite savegame OK"
			'			LoadSaveFile.file.Free()
		EndIf
	End Function

	'Summary: create a game, every variable is set to Zero
	Function Create:TGame()
		Local Game:TGame=New TGame
		Game.LoadConfig("config/settings.xml")
		Localization.AddLanguages("de, en") 'adds German and English to possible language
		Localization.SetLanguage(Game.userlanguage) 'selects language
		Localization.LoadResource("res/lang/lang_"+Game.userlanguage+".txt")
		Game.networkgame		= 0
		Game.minutesOfDayGone	= 0

		Game.timeGone			= Game.MakeTime(1985,1,0,0)
		Game.timeStart			= Game.MakeTime(1985,1,0,0)
		'print "year: "+Game.GetYear()+" day: "+Game.GetDay()+" hour: "+Game.GetHour()+" min: "+Game.GetMinute()
		Game.dayToPlan			= Game.GetDay()
		Game.title				= "unknown"
		Return Game
	End Function

	'Things to init directly after game started
	Function onStart:int(triggerEvent:TEventBase)
		'create 3 starting news
		If Game.IsGameLeader()
			NewsAgency.AnnounceNewNews(-60)
			NewsAgency.AnnounceNewNews(-120)
			NewsAgency.AnnounceNewNews(-120)
		endif
	End Function

	'returns whether the given number is a valid player id
	Method IsPlayerID:Int(number:Int)
		Return (number > 0 And number <= 4)
	End Method

	Method IsAIPlayer:Int(number:int)
		return (Players[number].PlayerKI <> NULL And Players[number].figure.controlledbyID = 0)
	End Method

	Method IsLocalPlayer:Int(number:int)
		return number = self.playerID
	End Method



	Method GetMaxAudience:Int(playerID:Int=-1)
		If Not Game.isPlayerID(playerID)
			Local avg:Int = 0
			For Local i:Int = 1 To 4
				avg :+ Players[ i ].maxaudience
			Next
			avg:/4
			Return avg
		EndIf
		Return Players[ playerID ].maxaudience
	End Method

	Method GetDayName:String(day:Int, longVersion:Int=0) {_exposeToLua}
		Local versionString:String = "SHORT"
		If longVersion = 1 Then versionString = "LONG"

		Select day
			Case 0	Return GetLocale("WEEK_"+versionString+"_MONDAY")
			Case 1	Return GetLocale("WEEK_"+versionString+"_TUESDAY")
			Case 2	Return GetLocale("WEEK_"+versionString+"_WEDNESDAY")
			Case 3	Return GetLocale("WEEK_"+versionString+"_THURSDAY")
			Case 4	Return GetLocale("WEEK_"+versionString+"_FRIDAY")
			Case 5	Return GetLocale("WEEK_"+versionString+"_SATURDAY")
			Case 6	Return GetLocale("WEEK_"+versionString+"_SUNDAY")
			Default	Return "not a day"
		EndSelect
	End Method

	'Summary: load the config-file and set variables depending on it
	Method LoadConfig:Byte(configfile:String="config/settings.xml")
		Local xml:TxmlHelper = TxmlHelper.Create(configfile)
		If xml <> Null Then PrintDebug ("TGame.LoadConfig()", "settings.xml eingelesen", DEBUG_LOADING)
		Local node:TxmlNode = xml.FindRootChild("settings")
		If node = Null Or node.getName() <> "settings"
			Print "settings.xml fehlt der settings-Bereich"
			Return 0
		EndIf
		Self.username			= xml.FindValue(node,"username", "Ano Nymus")	'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'username' fehlt, setze Defaultwert: 'Ano Nymus'", DEBUG_LOADING)
		Self.userchannelname	= xml.FindValue(node,"channelname", "SunTV")	'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'userchannelname' fehlt, setze Defaultwert: 'SunTV'", DEBUG_LOADING)
		Self.userlanguage		= xml.FindValue(node,"language", "de")			'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'language' fehlt, setze Defaultwert: 'de'", DEBUG_LOADING)
		Self.userport			= xml.FindValueInt(node,"onlineport", 4444)		'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'onlineport' fehlt, setze Defaultwert: '4444'", DEBUG_LOADING)
		Self.userdb				= xml.FindValue(node,"database", "res/database.xml")	'Print "settings.xml - missing 'database' - set to default: 'database.xml'"
		Self.title				= xml.FindValue(node,"defaultgamename", "MyGame")		'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'defaultgamename' fehlt, setze Defaultwert: 'MyGame'", DEBUG_LOADING)
		Self.userfallbackip		= xml.FindValue(node,"fallbacklocalip", "192.168.0.1")	'PrintDebug ("TGame.LoadConfig()", "settings.xml - 'fallbacklocalip' fehlt, setze Defaultwert: '192.168.0.1'", DEBUG_LOADING)
	End Method

	Method calculateMaxAudiencePercentage:Float(forHour:Int= -1)
		If forHour <= 0 Then forHour = Self.GetHour()

		'based on weekday (thursday) in march 2011 - maybe add weekend
		Select self.GetHour()
			Case 0	game.maxAudiencePercentage = 11.40 + Float(RandRange( -6, 6))/ 100.0 'Germany ~9 Mio
			Case 1	game.maxAudiencePercentage =  6.50 + Float(RandRange( -4, 4))/ 100.0 'Germany ~5 Mio
			Case 2	game.maxAudiencePercentage =  3.80 + Float(RandRange( -3, 3))/ 100.0
			Case 3	game.maxAudiencePercentage =  3.60 + Float(RandRange( -3, 3))/ 100.0
			Case 4	game.maxAudiencePercentage =  2.25 + Float(RandRange( -2, 2))/ 100.0
			Case 5	game.maxAudiencePercentage =  3.45 + Float(RandRange( -2, 2))/ 100.0 'workers awake
			Case 6	game.maxAudiencePercentage =  3.25 + Float(RandRange( -2, 2))/ 100.0 'some go to work
			Case 7	game.maxAudiencePercentage =  4.45 + Float(RandRange( -3, 3))/ 100.0 'more awake
			Case 8	game.maxAudiencePercentage =  5.05 + Float(RandRange( -4, 4))/ 100.0
			Case 9	game.maxAudiencePercentage =  5.60 + Float(RandRange( -4, 4))/ 100.0
			Case 10	game.maxAudiencePercentage =  5.85 + Float(RandRange( -4, 4))/ 100.0
			Case 11	game.maxAudiencePercentage =  6.70 + Float(RandRange( -4, 4))/ 100.0
			Case 12	game.maxAudiencePercentage =  7.85 + Float(RandRange( -4, 4))/ 100.0
			Case 13	game.maxAudiencePercentage =  9.10 + Float(RandRange( -5, 5))/ 100.0
			Case 14	game.maxAudiencePercentage = 10.20 + Float(RandRange( -5, 5))/ 100.0
			Case 15	game.maxAudiencePercentage = 10.90 + Float(RandRange( -5, 5))/ 100.0
			Case 16	game.maxAudiencePercentage = 11.45 + Float(RandRange( -6, 6))/ 100.0
			Case 17	game.maxAudiencePercentage = 14.10 + Float(RandRange( -7, 7))/ 100.0 'people come home
			Case 18	game.maxAudiencePercentage = 22.95 + Float(RandRange( -8, 8))/ 100.0 'meal + worker coming home
			Case 19	game.maxAudiencePercentage = 33.45 + Float(RandRange(-10,10))/ 100.0
			Case 20	game.maxAudiencePercentage = 38.70 + Float(RandRange(-15,15))/ 100.0
			Case 21	game.maxAudiencePercentage = 37.60 + Float(RandRange(-15,15))/ 100.0
			Case 22	game.maxAudiencePercentage = 28.60 + Float(RandRange( -9, 9))/ 100.0 'bed time starts
			Case 23	game.maxAudiencePercentage = 18.80 + Float(RandRange( -7, 7))/ 100.0
		EndSelect
		game.maxAudiencePercentage :/ 100.0

		Return game.maxAudiencePercentage
	End Method

	Method GetNextHour:Int() {_exposeToLua}
		local nextHour:int = self.GetHour()+1
		If nextHour > 24 Then Return nextHour - 24
		Return nextHour
	End Method

	Method IsGameLeader:Int()
		Return (Game.networkgame And Network.isServer) Or (Not Game.networkgame)
	End Method

	'Summary: Updates Time, Costs, States ...
	Method Update(deltaTime:Float=1.0)
		Self.minutesOfDayGone	:+ (Float(speed) / 10.0)
		Self.timeGone			:+ (Float(speed) / 10.0)

		'time for news ?
		If IsGameLeader() And NewsAgency.NextEventTime < self.timeGone Then NewsAgency.AnnounceNewNews()

		'send state to clients
		If IsGameLeader() And Self.networkgame And Self.stateSyncTime < MilliSecs()
			NetworkHelper.SendGameState()
			Self.stateSyncTime = MilliSecs() + Self.stateSyncTimer
		EndIf

		'if speed to high - potential skip of minutes, so "fetch them"
		'sets minute / hour / day
		Local missedMinutes:Int = Floor(Self.minutesOfDayGone - Self.lastMinutesOfDayGone)
		If missedMinutes = 0 Then Return

		local minute:int	= 0
		local hour:int		= 0
		For Local i:Int = 1 To missedMinutes
			minute = (Floor(Self.lastMinutesOfDayGone)  + i ) Mod 60 '0 to 59
			EventManager.registerEvent(TEventOnTime.Create("Game.OnMinute", minute))

			'hour
			If minute = 0
				hour = Floor( (Self.lastMinutesOfDayGone + i) / 60) Mod 24 '0 after midnight
				EventManager.registerEvent(TEventOnTime.Create("Game.OnHour", hour))
			EndIf

			'day
			If hour = 0 And minute = 0
				Self.minutesOfDayGone 	= 0			'reset minutes of day
				Self.daysPlayed			:+1			'increase current day
			 	'automatically change current-plan-day on day change
				Self.dayToPlan 			= Self.getDay()
				EventManager.registerEvent(TEventOnTime.Create("Game.OnDay", Self.GetDay()))
			EndIf
		Next
		Self.lastMinutesOfDayGone = Floor(Self.minutesOfDayGone)
	End Method

	'Summary: returns day of the week including gameday
	Method GetFormattedDay:String(_day:Int = -5) {_exposeToLua}
		Return _day+"."+GetLocale("DAY")+" ("+Self.GetDayName( Max(0,_day-1) Mod 7, 0)+ ")"
	End Method

	Method GetFormattedDayLong:String(_day:Int = -1) {_exposeToLua}
		If _day < 0 Then _day = Self.GetDay()
		Return Self.GetDayName( Max(0,_day-1) Mod 7, 1)
	End Method

	'Summary: returns formatted value of actual gametime
	Method GetFormattedTime:String(time:double=0) {_exposeToLua}
		Local strHours:String = Self.GetHour(time)
		Local strMinutes:String = Self.GetMinute(time)

		If int(strHours) < 10 Then strHours = "0"+strHours
		If int(strMinutes) < 10 Then strMinutes = "0"+strMinutes
		Return strHours+":"+strMinutes
	End Method

	Method GetWeekday:Int(_day:Int = -1) {_exposeToLua}
		If _day < 0 Then _day = Self.GetDay()
		Return Max(0,_day-1) Mod 7
	End Method

	Method MakeTime:double(year:int,day:int,hour:int,minute:int) {_exposeToLua}
		'year=1,day=1,hour=0,minute=1 should result in "1*yearInSeconds+1"
		'as it is 1 minute after end of last year - new years eve ;D
		'there is no "day 0" (as there would be no "month 0")

		return (((day-1) + year*self.daysPerYear)*24 + hour)*60 + minute
	End Method

	Method GetTimeGone:double() {_exposeToLua}
		Return Self.timeGone
	End Method

	Method GetTimeStart:double() {_exposeToLua}
		Return Self.timeStart
	End Method

	Method GetYear:Int(_time:double = 0) {_exposeToLua}
		If _time = 0 Then _time = self.timeGone
		_time = floor(_time / (24 * 60 * self.daysPerYear))
		Return Int(_time)
	End Method

	Method GetDayOfYear:int(_time:double = 0) {_exposeToLua}
		return (self.GetDay() - self.GetYear()*self.daysPerYear)
	End Method

	Method GetDay:Int(_time:double = 0) {_exposeToLua}
		If _time = 0 Then _time = self.timeGone
		_time = floor(_time / (24 * 60))
		'we are ON a day (it is not finished yet)
		'if we "ceil" the time, we would ignore 1.0 as this would
		'not get rounded to 2.0 like 1.01 would do
		Return 1 + Int(_time)
	End Method

	Method GetHour:Int(_time:double = 0) {_exposeToLua}
		If _time = 0 Then _time = self.timeGone
		'remove days from time
		_time = _time Mod (24*60)
		'hours = how many times 60 minutes fit into rest time
		Return Int(Floor(_time / 60))
	End Method

	Method GetMinute:Int(_time:double = 0) {_exposeToLua}
		If _time = 0 Then _time = self.timeGone
		'remove days from time
		_time = _time Mod (24*60)
		'minutes = rest not fitting into hours
		Return Int(_time) Mod 60
	End Method
End Type

Type PacketTypes
	Global PlayerState:Byte				= 6					' Player Name, Position...
End Type

'class holding name, channelname, infos about the figure, programmeplan, programmecollection and so on - from a player
Type TPlayer {_exposeToLua="selected"}
	Field Name:String 										{saveload = "normal"}		'playername
	Field channelname:String 								{saveload = "normal"} 		'name of the channel
	Field finances:TFinancials[7]														'One week of financial stats about credit, money, payments ...
	Field audience:Int 			= 0 						{saveload = "normal"}		'general audience
	Field maxaudience:Int 		= 0 						{saveload = "normal"}		'maximum possible audience
	Field ProgrammeCollection:TPlayerProgrammeCollection	{_exposeToLua}
	Field ProgrammePlan:TPlayerProgrammePlan				{_exposeToLua}
	Field Figure:TFigures									{_exposeToLua}				'actual figure the player uses
	Field playerID:Int 			= 0							{saveload = "normal"}		'global used ID of the player
	Field color:TColor																	'the color used to colorize symbols and figures
	Field figurebase:Int 		= 0							{saveload = "normal"}		'actual number of an array of figure-images
	Field networkstate:Int 		= 0							{saveload = "normal"}		'1=ready, 0=not set, ...
	Field newsabonnements:Int[6]							{_private}					'abonnementlevels for the newsgenres
	Field PlayerKI:KI			= Null						{_private}
	Global globalID:Int			= 1							{_private}
	Global List:TList = CreateList()						{_private}
	Field CreditCurrent:Int = 200000						{_private}
	Field CreditMaximum:Int = 300000						{_private}

	Function getByID:TPlayer( playerID:Int = 0)
		For Local player:TPlayer = EachIn TPlayer.list
			If playerID = player.playerID Then Return player
		Next
		Return Null
	End Function

	Function Load:Tplayer(pnode:TxmlNode)
Print "implement Load:Tplayer"
Return Null
Rem
		Local Player:TPlayer = TPlayer.Create("save", "save", Assets.GetSpritePack("figures").GetSprite("Man1") , 0, 0, 0, 0, 0, 0, 1, "")
		TFigures.List.Remove(Player.figure)
		Local i:Int = 0, j:Int = 0
		Local col:TColor = null
		Local FigureID:Int = 0

		Local NODE:xmlNode = pnode.FirstChild()
		While NODE <> Null
			Local nodevalue:String = ""
			If node.HasAttribute("var", False) Then nodevalue = node.Attribute("var").Value
			Local typ:TTypeId = TTypeId.ForObject(Player)
			For Local t:TField = EachIn typ.EnumFields()
				If t.MetaData("saveload") = "normal" And Upper(t.Name()) = NODE.Name
					t.Set(Player, nodevalue)
				EndIf
			Next
			Select NODE.Name
				Case "FINANCE" Player.finances[i].Create(Player.PlayerID, 550000, 2500000) ;Player.finances[i].Load(NODE, Player.finances[i] ) ;i:+1
				Case "COLOR" col = TColor.FromInt(nodevalue)
				Case "FIGUREID" FigureID = Int(nodevalue)
				Case "NEWSABONNEMENTS0" Or "NEWSABONNEMENTS1" Or "NEWSABONNEMENTS2" Or "NEWSABONNEMENTS3" Or "NEWSABONNEMENTS4" Or "NEWSABONNEMENTS5"
					If TNewsbuttons.GetButton(j, Player.playerID) <> Null Then TNewsbuttons.GetButton(j, Player.playerID).clickstate = Player.newsabonnements[j] ;j:+1
			End Select
			Node = Node.NextSibling()
		Wend
		Player.color = TColor.getFromListObj(col)
		Players[Player.playerID] = Player  '.player is player in root-scope
		Player.Figure = TFigures.GetByID( FigureID )
		If Player.figure.controlledByID = 0 And Game.playerID = 1 Then
			PrintDebug("TPlayer.Load()", "Lade AI f�r Spieler" + Player.playerID, DEBUG_SAVELOAD)
			Player.playerKI = KI.Create(Player.playerID, "res/ai/DefaultAIPlayer.lua")
		EndIf
		Player.Figure.ParentPlayer = Player
		Player.UpdateFigureBase(Player.figurebase)
		Player.RecolorFigure(Player.color)
		Return Player
endrem
	End Function

	Function LoadAll()
		TPlayer.List.Clear()
		Players[1] = Null;Players[2] = Null;Players[3] = Null;Players[4] = Null;
		TPlayer.globalID = 1
		TFinancials.List.Clear()
		Local Children:TList = LoadSaveFile.NODE.getChildren()
		For Local node:txmlNode = EachIn Children
			If NODE.getName() = "PLAYER" Then TPlayer.Load(NODE)
		Next
		'Print "loaded player informations"
	End Function

	Function SaveAll()
		LoadSaveFile.xmlBeginNode("ALLPLAYERS")
		For Local Player:TPlayer = EachIn TPlayer.List
			If Player<> Null Then Player.Save()
		Next
		LoadSaveFile.xmlCloseNode()
	End Function

	Method Save()
		LoadSaveFile.xmlBeginNode("PLAYER")
		Local typ:TTypeId = TTypeId.ForObject(Self)
		For Local t:TField = EachIn typ.EnumFields()
			If t.MetaData("saveload") = "normal"
				LoadSaveFile.xmlWrite(Upper(t.Name()), String(t.Get(Self)))
			EndIf
		Next
		For Local i:Int = 0 To 6
			Self.finances[i].Save()
		Next
		LoadSaveFile.xmlWrite("COLOR",		Self.color.ToInt())
		LoadSaveFile.xmlWrite("FIGUREID",	Self.figure.id)
		For Local j:Int = 0 To 5
			LoadSaveFile.xmlWrite("NEWSABONNEMENTS"+j,	Self.newsabonnements[j])
		Next
		LoadSaveFile.xmlCloseNode()
	End Method

	Method GetPlayerID:int() {_exposeToLua}
		return self.playerID
	End Method

	Method IsAI:Int() {_exposeToLua}
		'return self.playerKI <> null
		Return Self.figure.IsAI()
	End Method

	'creates and returns a player
	'-creates the given playercolor and a figure with the given
	' figureimage, a programmecollection and a programmeplan
	Function Create:TPlayer(Name:String, channelname:String = "", sprite:TGW_Sprites, x:Int, onFloor:Int = 13, dx:Int, color:TColor, ControlledByID:Int = 1, FigureName:String = "")
		Local Player:TPlayer		= New TPlayer
		EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Create Player").AddNumber("itemNumber", globalID).AddNumber("maxItemNumber", 4) ) )

		Player.Name					= Name
		Player.playerID				= globalID
		Player.color				= color.AddToList(true).SetOwner(TPlayer.globalID)
		Player.channelname			= channelname
		Player.Figure				= new TFigures.CreateFigure(FigureName, sprite, x, onFloor, dx, ControlledByID)
		Player.Figure.ParentPlayer	= Player
		For Local i:Int = 0 To 6
			Player.finances[i] = TFinancials.Create(Player.playerID, 550000, 250000)
			Player.finances[i].revenue_before = 550000
			Player.finances[i].revenue_after  = 550000
		Next
		Player.ProgrammeCollection	= TPlayerProgrammeCollection.Create(Player)
		Player.ProgrammePlan		= TPlayerProgrammePlan.Create(Player)
'		Player.RecolorFigure(Player.color.GetUnusedColor(globalID))
		Player.RecolorFigure(Player.color)
		Player.UpdateFigureBase(0)
		Player.globalID:+1

		List.AddLast(Player)
		List.sort()

		If controlledByID = 0 And Game.playerID = 1
			If Player.playerID = 2
				Player.PlayerKI = KI.Create(Player.playerID, "res/ai/DefaultAIPlayer.lua")
			Else
				Player.PlayerKI = KI.Create(Player.playerID, "res/ai/test_base.lua")
			EndIf
		EndIf

		Return Player
	End Function

	'loads a new figurbase and colorizes it
	Method UpdateFigureBase(newfigurebase:Int)
		Local figureCount:Int = 12
		If newfigurebase > figureCount - 1 Then newfigurebase = 0
		If newfigurebase < 0 Then newfigurebase = figureCount - 1
		figurebase = newfigurebase

		Local tmpSprite:TGW_Sprites = Assets.GetSpritePack("figures").GetSprite("Player" + Self.playerID)
		Local tmppix:TPixmap = LockImage(Assets.GetSpritePack("figures").image, 0)
		'clear area in all-figures-image
		tmppix.Window(tmpSprite.Pos.x, tmpSprite.Pos.y, tmpSprite.w, tmpSprite.h).ClearPixels(0)
		DrawOnPixmap(ColorizeTImage(Assets.GetSpritePack("figures").GetSpriteImage("", figurebase, False), color), 0, tmppix, tmpSprite.Pos.x, tmpSprite.Pos.y)
		'unlock not needed as doing nothing
		'UnlockImage(Assets.GetSpritePack("figures").image, 0)
	End Method

	'colorizes a figure and the corresponding sign next to the players doors in the building
	Method RecolorFigure(newColor:TColor = Null)
		If newColor = Null Then newColor = Self.color
		self.color.ownerID	= 0
		self.color			= newColor
		self.color.ownerID	= playerID
		UpdateFigureBase(figurebase)
		'overwrite asset
		Assets.AddImageAsSprite( "gfx_building_sign"+String(playerID), ColorizeTImage(Assets.GetSprite("gfx_building_sign_base").getImage(), color) )
	End Method

	'nothing up to now
	Method UpdateFinances:Int()
		For Local i:Int = 0 To 6
			'
		Next
	End Method

	Method GetNewsAbonnementPrice:int(level:int=0)
		return Min(5,level) * 10000
	End Method

	Method GetNewsAbonnement:Int(genre:Int) {_exposeToLua}
		If genre > 5 Then Return 0 'max 6 categories 0-5
		Return Self.newsabonnements[genre]
	End Method

	Method IncreaseNewsAbonnement(genre:int) {_exposeToLua}
		self.SetNewsAbonnement( genre, self.GetNewsAbonnement(genre)+1 )
	End Method

	Method SetNewsAbonnement(genre:Int, level:Int, sendToNetwork:Int = True) {_exposeToLua}
		If level > Game.maxAbonnementLevel Then level = 0 'before: Return
		If genre > 5 Then Return 'max 6 categories 0-5
		If Self.newsabonnements[genre] <> level
			Self.newsabonnements[genre] = level
			If Game.networkgame And Network.IsConnected And sendToNetwork Then NetworkHelper.SendNewsSubscriptionChange(self.playerID, genre, level)
		EndIf
	End Method

	'calculates and returns the percentage of the players audience depending on the maxaudience
	Method GetAudiencePercentage:Float() {_exposeToLua}
		If maxaudience > 0 And audience > 0
			Return Float(audience * 100) / Float(maxaudience)
		EndIf
		Return 0.0
	End Method

	'calculates and returns the percentage of the players audience depending on the maxaudience
	Method GetRelativeAudiencePercentage:Float() {_exposeToLua}
		If game.maxAudiencePercentage > 0
			Return Float(GetAudiencePercentage() / game.maxAudiencePercentage)
		EndIf
		Return 0.0
	End Method


	'returns value chief will give as credit
	Method GetCreditAvailable:Int() {_exposeToLua}
		Return Max(0, Self.CreditMaximum - Self.CreditCurrent)
	End Method

	Method GetCreditCurrent:Int() {_exposeToLua}
		Return Self.CreditCurrent
	End Method

	'helper to call from external types - only for current game.playerID-Player
	Function extSetCredit:String(amount:Int)
		Players[Game.playerID].SetCredit(amount)
	End Function

	'increases Credit
	Method SetCredit(amount:Int)
		Self.finances[Game.getWeekday()].TakeCredit(amount)
		Self.CreditCurrent:+amount
	End Method

	'computes daily costs like station or newsagency fees for every player
	Function ComputeDailyCosts()
		Local playerID:Int = 1
		For Local Player:TPlayer = EachIn TPlayer.List
			'stationfees
			Player.finances[Game.getWeekday()].PayStationFees(StationMap.CalculateStationCosts(playerID))

			'newsagencyfees
			Local newsagencyfees:Int =0
			For Local i:Int = 0 To 5
				newsagencyfees:+ Player.newsabonnements[i]*10000 'baseprice for an subscriptionlevel
			Next
			Player.finances[Game.getWeekday()].PayNewsAgencies((newsagencyfees/2))

			playerID :+1
		Next
	End Function

	'computes ads - if a adblock is botched or run successful
	'if successfull and ad-contract finished then it sells the ad (earn money)
	Function ComputeAds()
		Local Adblock:TAdBlock
		For Local Player:TPlayer = EachIn TPlayer.List
			Adblock = Player.ProgrammePlan.GetCurrentAdBlock()
			'skip if no ad is send at the moment
			If not Adblock then continue

			'ad failed (audience lower than needed)
			If Player.audience < Adblock.contract.GetMinAudience()
				Adblock.SetBotched(1)
			'ad is ok
			else
				Adblock.SetBotched(0)
				'successful sent - so increase the value the contract
				AdBlock.contract.spotsSent:+1

				'successful sent all needed spots?
				If Adblock.contract.GetSpotsSent() >= Adblock.contract.GetSpotsToSend()
					'set contract fulfilled
					Adblock.contract.state = 1

					'give money
					Player.finances[Game.getWeekday()].earnAdProfit(Adblock.contract.GetProfit() )

					'removes Blocks which are more than needed (eg 3 of 2 to be shown Adblocks)
					AdBlock.RemoveOverheadAdblocks()

					'remove contract from collection (and suitcase)
					'contract is still stored within adblocks (until they get deleted)
					TContractBlock.RemoveContractFromSuitcase(Adblock.contract)
					Player.ProgrammeCollection.RemoveContract(Adblock.contract)
				endif
			EndIf
		Next
	End Function

	'end of day - take over money for next day
	Function TakeOverMoney()
		Local dayBefore:Int = Max(0, Game.getWeekday()-1)
		For Local Player:TPlayer = EachIn TPlayer.List
			Player.finances[Game.getWeekday()].takeOverFromDayBefore(Player.finances[ dayBefore ])
		Next
	End Function

	'computes penalties for expired ad-contracts
	Function ComputeContractPenalties()
		For Local Player:TPlayer = EachIn TPlayer.List
			For Local Contract:TContract = EachIn Player.ProgrammeCollection.contractlist
				If not contract then continue

				If contract.GetDaysLeft() <= 0
					Player.finances[Game.getWeekday()].PayPenalty(contract.GetPenalty() )
					Player.ProgrammeCollection.RemoveContract(contract)
					TAdBlock.RemoveAdblocks(contract, Game.GetDay())
					'Print Player.name+" paid a penalty of "+contract.calculatedPenalty+" for contract:"+contract.title
				EndIf
			Next
		Next
	End Function

	'computes audience depending on ComputeAudienceQuote and if the time is the same
	'as for the last block of a programme, it decreases the topicality of that programme
	Function ComputeAudience(recompute:Int = 0)
		Local block:TProgrammeBlock
		For Local Player:TPlayer = EachIn TPlayer.List
			block = Player.ProgrammePlan.GetCurrentProgrammeBlock()
			Player.audience = 0

			If block And block.programme And Player.maxaudience <> 0
				Player.audience = Floor(Player.maxaudience * block.Programme.getAudienceQuote(Player.audience/Player.maxaudience) / 1000)*1000
				'maybe someone sold a station
				If recompute
					Local quote:TAudienceQuotes = TAudienceQuotes.GetAudienceOfDate(Player.playerID, Game.GetDay(), Game.GetHour(), Game.GetMinute())
					If quote <> Null
						quote.audience = Player.audience
						quote.audiencepercentage = Int(Floor(Player.audience * 1000 / Player.maxaudience))
					EndIf
				Else
					TAudienceQuotes.Create(block.Programme.title + " (" + GetLocale("BLOCK") + " " + (1 + Game.GetHour() - (block.sendhour - Game.GetDay()*24)) + "/" + block.Programme.blocks, Int(Player.audience), Int(Floor(Player.audience * 1000 / Player.maxaudience)), Game.GetHour(), Game.GetMinute(), Game.GetDay(), Player.playerID)
				EndIf
				If block.sendHour - (Game.GetDay()*24) + block.Programme.blocks <= Game.getNextHour()
					If Not recompute
						block.Programme.CutTopicality()
						block.Programme.getPrice()
					EndIf
				EndIf
			EndIf
		Next
	End Function

	'computes newsshow-audience
	Function ComputeNewsAudience()
		Local newsBlock:TNewsBlock
		For Local Player:TPlayer = EachIn TPlayer.List
			Player.audience = 0
			Local audience:Int = 0
			For Local i:Int = 1 To 3
				newsBlock = Player.ProgrammePlan.GetNewsBlockFromSlot(i)
				If newsBlock <> Null And Player.maxaudience <> 0
					audience :+ Floor(Player.maxaudience * NewsBlock.news.ComputeAudienceQuote(Player.audience/Player.maxaudience) / 1000)*1000
					'If Player.playerID = 1 Print "Newsaudience for News: "+i+" - "+audience
				EndIf
			Next
			Player.audience= Ceil(audience / 3)
			TAudienceQuotes.Create("News: "+ Game.GetHour()+":00", Int(Player.audience), Int(Floor(Player.audience*1000/Player.maxaudience)),Game.GetHour(),Game.GetMinute(),Game.GetDay(), Player.playerID)
		Next
	End Function

	'nothing up to now
	Method Update:Int()
		''
	End Method

	'returns formatted value of actual money
	'gibt einen formatierten Wert des aktuellen Geldvermoegens zurueck
	Method GetMoneyFormatted:String()
		Return functions.convertValue(String(Self.finances[Game.getWeekday()].money), 2, 0)
	End Method

	Method GetMoney:Int() {_exposeToLua}
		Return Self.finances[Game.getWeekday()].money
	End Method

	'returns formatted value of actual credit
	Method GetCreditFormatted:String()
		Return functions.convertValue(String(Self.finances[Game.getWeekday()].credit), 2, 0)
	End Method

	Method GetCredit:int() {_exposeToLua}
		return Self.finances[Game.getWeekday()].credit
	End Method

	Method GetAudience:int() {_exposeToLua}
		return Self.audience
	End Method

	Method GetMaxAudience:int() {_exposeToLua}
		return Self.maxaudience
	End Method


	'returns formatted value of actual audience
	'gibt einen formatierten Wert der aktuellen Zuschauer zurueck
	Method GetFormattedAudience:String() {_exposeToLua}
		Return functions.convertValue(String(Self.audience), 2, 0)
	End Method

	Method Compare:Int(otherObject:Object)
		Local s:TPlayer = TPlayer(otherObject)
		If Not s Then Return 1
		If s.playerID > Self.playerID Then Return 1
		Return 0
	End Method
End Type

'holds data of WHAT has been bought, which amount of money was used and so on ... for 7 days
'containts methods for refreshing stats when paying or selling something
Type TFinancials
	Field paid_movies:Int 			= 0
	Field paid_stations:Int 		= 0
	Field paid_scripts:Int 			= 0
	Field paid_productionstuff:Int 	= 0
	Field paid_penalty:Int 			= 0
	Field paid_rent:Int 			= 0
	Field paid_news:Int 			= 0
	Field paid_newsagencies:Int 	= 0
	Field paid_stationfees:Int 		= 0
	Field paid_misc:Int 			= 0
	Field paid_total:Int 			= 0

	Field sold_movies:Int 			= 0
	Field sold_ads:Int 				= 0
	Field callerRevenue:Int			= 0
	Field sold_misc:Int				= 0
	Field sold_total:Int = 0
	Field sold_stations:Int = 0
	Field revenue_interest:Int = 0
	Field revenue_before:Int 		=-1
	Field revenue_after:Int 		= 0
	Field money:Int					= 0
	Field credit:Int 				= 0
	Field playerID:Int 				= 0
	Field ListLink:TLink {saveload = "special" sl = "no"}
	Global List:TList = CreateList() {saveload = "special" sl = "no"}

	Global debug:Int = 0

	Function Load:TFinancials(pnode:txmlNode, finance:TFinancials)
Print "implement Load:TFinancials"
Return Null
Rem
		Local NODE:xmlNode = pnode.FirstChild()
		While NODE <> Null
			Local nodevalue:String = ""
			If node.HasAttribute("var", False) Then nodevalue = node.Attribute("var").Value
			Local typ:TTypeId = TTypeId.ForObject(finance)
			For Local t:TField = EachIn typ.EnumFields()
				If t.MetaData("saveload") <> "special" And Upper(t.Name()) = NODE.Name
					t.Set(finance, nodevalue)
				EndIf
			Next
			Node = Node.NextSibling()
		Wend
		Return finance
endrem
	End Function

	'not used - implemented in player-class
	Function LoadAll()
		TFinancials.List.Clear()
		Local Children:TList = LoadSaveFile.NODE.getChildren()
		For Local NODE:txmlNode = EachIn Children
			If NODE.getName() = "FINANCE"
				Local finance:TFinancials = New TFinancials
				finance = TFinancials.Load(NODE, finance)
				finance.ListLink = TFinancials.List.AddLast(finance)
			End If
		Next
		Print "loaded finance-information"
	End Function

	Function SaveAll()
		TFinancials.List.Sort()
		LoadSaveFile.xmlBeginNode("FINANCIALS")
		For Local finance:TFinancials = EachIn TFinancials.List
			If finance <> Null Then finance.Save()
		Next
		LoadSaveFile.xmlCloseNode()
	End Function

	Method Save()
		LoadSaveFile.xmlBeginNode("FINANCE")
		Local typ:TTypeId = TTypeId.ForObject(Self)
		For Local t:TField = EachIn typ.EnumFields()
			If t.MetaData("saveload") <> "special"
				LoadSaveFile.xmlWrite(Upper(t.Name()), String(t.Get(Self)))
			EndIf
		Next
		LoadSaveFile.xmlCloseNode()
	End Method

	Function Create:TFinancials(playerID:Int, startmoney:Int=550000, startcredit:Int = 250000)
		Local finances:TFinancials = New TFinancials
		finances.money		= startmoney
		finances.credit		= startcredit
		finances.playerID	= playerID
		finances.ListLink	= List.AddLast(finances)
		Return finances
	End Function

	Method TakeOverFromDayBefore:Int(otherFinances:TFinancials)
		Self.money = otherFinances.money
		Self.credit = otherFinances.credit
	End Method

	'refreshs stats about misc sells
	Method SellMisc(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" MISC : "+_money
		sold_ads	:+_money
		sold_total	:+_money
		ChangeMoney(_money)
	End Method

	Method SellStation:Int(_money:Int)
		Self.sold_stations:+_money
		Self.sold_total:+money
		ChangeMoney(+ _money)
		Return True
	End Method

	Method ChangeMoney(_moneychange:Int)
		money:+_moneychange
		If Players[ Self.playerID ].isAI() Then Players[ Self.playerID ].PlayerKI.CallOnMoneyChanged()
		If Self.playerID = Game.playerID Then Interface.BottomImgDirty = True
		If debug Then Print "FINANZ: player :"+Self.playerID+" geldaenderung:"+_moneychange
	End Method

	'refreshs stats about earned money from adspots
	Method earnAdProfit(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Werbeeinahme: "+_money
		sold_ads	:+_money
		sold_total	:+_money
		ChangeMoney(_money)
	End Method

	'refreshs stats about earned money from sending ad powered shows or call-in
	Method earnCallerRevenue(_money:Int)
		Self.callerRevenue	:+_money
		Self.sold_total		:+_money
		If debug Then Print "FINANZ: player :"+Self.playerID+" Callshowgewinn: "+_money
		ChangeMoney(_money)
	End Method

	'refreshs stats about earned money from selling a movie/programme
	Method SellMovie(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Filmverkauf: "+_money
		sold_movies	:+_money
		sold_total	:+_money
		ChangeMoney(_money)
	End Method

	'pay the bid for an auction programme
	Method PayProgrammeBid:Byte(_money:Int)
		If money >= _money
			paid_movies	:+_money
			paid_total	:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'get the bid paid before another player bid for an auction programme
	Method GetProgrammeBid(_money:Int)
		paid_movies:-_money
		paid_total:-_money
		ChangeMoney(+ _money)
	End Method

	Method TakeCredit:Byte(_money:Int)
		credit		:+_money
		sold_misc	:+_money	'kind of income
		sold_total	:+_money	'kind of income
		paid_misc	:+_money	'kind of duty
		paid_total	:+_money	'kind of duty
		ChangeMoney(+ _money)
	End Method

	'refreshs stats about paid money from buying a movie/programme
	Method PayMovie:Byte(_money:Int)
		If money >= _money
			If debug Then Print "FINANZ: player :"+Self.playerID+" Filmkauf: -"+_money
			paid_movies:+_money
			paid_total:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'refreshs stats about paid money from buying a station
	Method PayStation:Byte(_money:Int)
		If money >= _money
			If debug Then Print "FINANZ: player :"+Self.playerID+" Stationkauf: -"+_money
			paid_stations:+_money
			paid_total:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'refreshs stats about paid money from buying a script (own production)
	Method PayScript:Byte(_money:Int)
		If money >= _money
			If debug Then Print "FINANZ: player :"+Self.playerID+" Scriptkauf: -"+_money
			paid_scripts:+_money
			paid_total:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'refreshs stats about paid money from buying stuff for own production
	Method PayProductionStuff:Byte(_money:Int)
		If money >= _money
			paid_productionstuff:+_money
			paid_total:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'refreshs stats about paid money from paying a penalty fee (not sent the necessary adspots)
	Method PayPenalty(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Werbestrafe: -"+_money
		paid_penalty:+_money
		paid_total:+_money
		ChangeMoney(- _money)
	End Method

	'refreshs stats about paid money from paying the rent of rooms
	Method PayRent(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Miete: -"+_money
		paid_rent:+_money
		paid_total:+_money
		ChangeMoney(- _money)
	End Method

	'refreshs stats about paid money from paying for the sent newsblocks
	Method PayNews:Byte(_money:Int)
		If money >= _money
			If debug Then Print "FINANZ: player :"+Self.playerID+" Newskauf: -"+_money
			paid_news:+_money
			paid_total:+_money
			ChangeMoney(- _money)
			Return True
		Else
			If playerID = Game.playerID Then TError.CreateNotEnoughMoneyError()
			Return False
		EndIf
	End Method

	'refreshs stats about paid money from paying the daily costs a newsagency-abonnement
	Method PayNewsAgencies(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Newsabo: -"+_money
		paid_newsagencies:+_money
		paid_total:+_money
		ChangeMoney(- _money)
	End Method

	'refreshs stats about paid money from paying the fees for the owned stations
	Method PayStationFees(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" Stationsgebuehren: -"+_money
		paid_stationfees:+_money
		paid_total:+_money
		ChangeMoney(- _money)
	End Method

	'refreshs stats about paid money from paying misc things
	Method PayMisc(_money:Int)
		If debug Then Print "FINANZ: player :"+Self.playerID+" MISC: -"+_money
		paid_misc:+_money
		paid_total:+_money
		ChangeMoney(- _money)
	End Method
End Type


'Include "gamefunctions_interface.bmx"

'create just one drop-zone-grid for all programme blocks instead the whole set for every block..
Function CreateDropZones:Int()
	Local i:Int = 0
	'Archive: Movie DND-zones in suitcase
	For i = 0 To Game.maxMoviesInSuitcaseAllowed-1
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i
		DragAndDrop.typ = "archiveprogrammeblock"
		DragAndDrop.pos.setXY(57+Assets.GetSprite("gfx_movie0").w*i, 297)
		DragAndDrop.w = Assets.GetSprite("gfx_movie0").w
		DragAndDrop.h = Assets.GetSprite("gfx_movie0").h
		If Not TArchiveProgrammeBlock.DragAndDropList Then TArchiveProgrammeBlock.DragAndDropList = CreateList()
		TArchiveProgrammeBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TArchiveProgrammeBlock.DragAndDropList
	Next

	'AdAgency: Contract DND-zones
	For i = 0 To Game.maxContractsAllowed-1
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i
		DragAndDrop.pos.setXY(550 + Assets.GetSprite("gfx_contracts_base").w * i, 87)
		DragAndDrop.w = Assets.GetSprite("gfx_contracts_base").w - 1
		DragAndDrop.h = Assets.GetSprite("gfx_contracts_base").h
		If Not TContractBlock.DragAndDropList Then TContractBlock.DragAndDropList = CreateList()
		TContractBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TContractBlock.DragAndDropList
	Next

	'adblock
	For i = 0 To 11
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i
		DragAndDrop.typ = "adblock"
		DragAndDrop.pos.setXY( 394 + Assets.GetSprite("pp_programmeblock1").w, 17 + i * Assets.GetSprite("pp_adblock1").h)
		DragAndDrop.w = Assets.GetSprite("pp_adblock1").w
		DragAndDrop.h = Assets.GetSprite("pp_adblock1").h
		If Not TAdBlock.DragAndDropList Then TAdBlock.DragAndDropList = CreateList()
		TAdBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TAdBlock.DragAndDropList
	Next
	'adblock
	For i = 0 To 11
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i+11
		DragAndDrop.typ = "adblock"
		DragAndDrop.pos.setXY( 67 + Assets.GetSprite("pp_programmeblock1").w, 17 + i * Assets.GetSprite("pp_adblock1").h )
		DragAndDrop.w = Assets.GetSprite("pp_adblock1").w
		DragAndDrop.h = Assets.GetSprite("pp_adblock1").h
		If Not TAdBlock.DragAndDropList Then TAdBlock.DragAndDropList = CreateList()
		TAdBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TAdBlock.DragAndDropList
	Next
	'programmeblock
	For i = 0 To 11
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i
		DragAndDrop.typ = "programmeblock"
		DragAndDrop.pos.setXY( 394, 17 + i * Assets.GetSprite("pp_programmeblock1").h )
		DragAndDrop.w = Assets.GetSprite("pp_programmeblock1").w
		DragAndDrop.h = Assets.GetSprite("pp_programmeblock1").h
		If Not TProgrammeBlock.DragAndDropList Then TProgrammeBlock.DragAndDropList = CreateList()
		TProgrammeBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TProgrammeBlock.DragAndDropList
	Next

	For i = 0 To 11
		Local DragAndDrop:TDragAndDrop = New TDragAndDrop
		DragAndDrop.slot = i+11
		DragAndDrop.typ = "programmeblock"
		DragAndDrop.pos.setXY( 67, 17 + i * Assets.GetSprite("pp_programmeblock1").h )
		DragAndDrop.w = Assets.GetSprite("pp_programmeblock1").w
		DragAndDrop.h = Assets.GetSprite("pp_programmeblock1").h
		If Not TProgrammeBlock.DragAndDropList Then TProgrammeBlock.DragAndDropList = CreateList()
		TProgrammeBlock.DragAndDropList.AddLast(DragAndDrop)
		SortList TProgrammeBlock.DragAndDropList
	Next

End Function

Include "gamefunctions_elevator.bmx"
Include "gamefunctions_figures.bmx"

'Summary: Type of building, area around it and doors,...
Type TBuilding Extends TRenderable
	Field pos:TPoint = TPoint.Create(20,0)
	Field borderright:Int 			= 127 + 40 + 429
	Field borderleft:Int			= 127 + 40
	Field skycolor:Float = 0
	Field ufo_normal:TMoveableAnimSprites = new TMoveableAnimSprites.Create(Assets.GetSprite("gfx_building_BG_ufo"), 9, 100).SetupMoveable(0, 100, 0,0)
	Field ufo_beaming:TMoveableAnimSprites = new TMoveableAnimSprites.Create(Assets.GetSprite("gfx_building_BG_ufo2"), 9, 100).SetupMoveable(0, 100, 0,0)
	Field Elevator:TElevator

	Field Moon_curKubSplineX:appKubSpline =New appKubSpline
	Field Moon_curKubSplineY:appKubSpline =New appKubSpline
	Field Moon_curvStep:Float 		=.05
	Field Moon_tPos:Float 			= 3
	Field Moon_lastTChange:Int 		= MilliSecs()
	Field Moon_setNewCurve:Int 		= False
	Field Moon_newDataT:Int[], Moon_newDataX:Int[], Moon_newDataY:Int[]
	Field Moon_constSpeed:Int 		= False
	Field Moon_pixelPerSecond:Float 	= 10

	Field ufo_curKubSplineX:appKubSpline =New appKubSpline
	Field ufo_curKubSplineY:appKubSpline =New appKubSpline
	Field ufo_curvStep:Float 			=.05
	Field ufo_tPos:Float 				= 1
	Field ufo_lastTChange:Int 		= MilliSecs()
	Field ufo_setNewCurve:Int 		= False
	Field ufo_newDataT:Int[], ufo_newDataX:Int[], ufo_newDataY:Int[]
	Field ufo_constSpeed:Int 			= False
	Field ufo_pixelPerSecond:Float	= 25
	Field Clouds:TMoveableAnimSprites[5]
	Field CloudCount:Int = 5
	Field TimeColor:Double
	Field DezimalTime:Float
	Field ActHour:Int
	Field ItemsDrawnToBackground:Byte = 0
	Field gfx_bgBuildings:TGW_Sprites[6]
	Field gfx_building:TGW_Sprites
	Field gfx_buildingEntrance:TGW_Sprites
	Field gfx_buildingRoof:TGW_Sprites
	Field gfx_buildingWall:TGW_Sprites

	Field roomUsedTooltip:TTooltip = null

	Global StarsX:Int[60]
	Global StarsY:Int[60]
	Global StarsC:Int[60]
	Global List:TList = CreateList()

	Function Create:TBuilding()
		EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Create Building").AddNumber("itemNumber", 1).AddNumber("maxItemNumber", 1) ) )

		Local Building:TBuilding = New TBuilding
		Building.gfx_building	= Assets.GetSprite("gfx_building")
		Building.pos.y			= 0 - Building.gfx_building.h + 5 * 73 + 20	' 20 = interfacetop, 373 = raumhoehe
		Building.Elevator		= TElevator.Create(Building)
		Building.Elevator.RouteLogic = TElevatorSmartLogic.Create(Building.Elevator, 0) 'Die Logik die im Elevator verwendet wird. 1 hei�t, dass der PrivilegePlayerMode aktiv ist... mMn macht's nur so wirklich Spa�

		Building.Moon_curKubSplineX.GetDataInt([1, 2, 3, 4, 5], [-50, -50, 400, 850, 850])
		Building.Moon_curKubSplineY.GetDataInt([1, 2, 3, 4, 5], [650, 200, 20 , 200, 650])
		Building.ufo_curKubSplineX.GetDataInt([1, 2, 3, 4, 5], [-150, 200+RandMax(400), 200+RandMax(200), 65, -50])
		Building.ufo_curKubSplineY.GetDataInt([1, 2, 3, 4, 5], [-50+RandMax(200), 100+RandMax(200) , 200+RandMax(300), 330,150])
		For Local i:Int = 0 To Building.CloudCount-1
			Building.Clouds[i] = new TMoveableAnimSprites.Create(Assets.GetSprite("gfx_building_BG_clouds"), 1,0).SetupMoveable(- 200 * i + (i + 1) * RandMax(400), - 30 + RandMax(30), 2 + RandRange(0, 6),0)
		Next

		'background buildings
		Building.gfx_bgBuildings[0] = Assets.GetSprite("gfx_building_BG_Ebene3L")
		Building.gfx_bgBuildings[1] = Assets.GetSprite("gfx_building_BG_Ebene3R")
		Building.gfx_bgBuildings[2] = Assets.GetSprite("gfx_building_BG_Ebene2L")
		Building.gfx_bgBuildings[3] = Assets.GetSprite("gfx_building_BG_Ebene2R")
		Building.gfx_bgBuildings[4] = Assets.GetSprite("gfx_building_BG_Ebene1L")
		Building.gfx_bgBuildings[5] = Assets.GetSprite("gfx_building_BG_Ebene1R")

		'building assets
		Building.gfx_buildingEntrance	= Assets.GetSprite("gfx_building_Eingang")
		Building.gfx_buildingWall		= Assets.GetSprite("gfx_building_Zaun")
		Building.gfx_buildingRoof		= Assets.GetSprite("gfx_building_Dach")

		For Local j:Int = 0 To 29
			StarsX[j] = 10+RandMax(150)
			StarsY[j] = 20+RandMax(273)
			StarsC[j] = 50+RandMax(150)
		Next
		For Local j:Int = 30 To 59
			StarsX[j] = 650+RandMax(150)
			StarsY[j] = 20+RandMax(273)
			StarsC[j] = 50+RandMax(150)
		Next
		If Not List Then List = CreateList()
		List.AddLast(Building)
		SortList List
		Return Building
	End Function

	Method Update(deltaTime:Float=1.0)
		pos.y = Clamp(pos.y, - 637, 88)
		UpdateBackground(deltaTime)

		if self.roomUsedTooltip <> null then self.roomUsedTooltip.Update(deltaTime)
	End Method

	Method DrawItemsToBackground:Int()
		Local locy13:Int	= GetFloorY(13)
		Local locy3:Int		= GetFloorY(3)
		Local locy0:Int		= GetFloorY(0)
		Local locy12:Int	= GetFloorY(12)
		If Not ItemsDrawnToBackground
			Local Pix:TPixmap = LockImage(gfx_building.parent.image)
			'	  Local Pix:TPixmap = gfx_building_skyscraper.RestorePixmap()

			DrawOnPixmap(Assets.GetSprite("gfx_building_Pflanze4").GetImage(), 0, Pix, 127 + borderleft + 40, locy12 - Assets.GetSprite("gfx_building_Pflanze4").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Pflanze6").GetImage(), 0, Pix, 127 + borderright - 95, locy12 - Assets.GetSprite("gfx_building_Pflanze6").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Pflanze2").GetImage(), 0, Pix, 127 + borderleft + 105, locy13 - Assets.GetSprite("gfx_building_Pflanze2").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Pflanze3").GetImage(), 0, Pix, 127 + borderright - 105, locy13 - Assets.GetSprite("gfx_building_Pflanze3").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 145, locy0 - Assets.GetSprite("gfx_building_Wandlampe").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 506 - 145 - Assets.GetSprite("gfx_building_Wandlampe").w, locy0 - Assets.GetSprite("gfx_building_Wandlampe").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 145, locy13 - Assets.GetSprite("gfx_building_Wandlampe").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 506 - 145 - Assets.GetSprite("gfx_building_Wandlampe").w, locy13 - Assets.GetSprite("gfx_building_Wandlampe").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 145, locy3 - Assets.GetSprite("gfx_building_Wandlampe").h)
			DrawOnPixmap(Assets.GetSprite("gfx_building_Wandlampe").GetImage(), 0, Pix, 506 - 145 - Assets.GetSprite("gfx_building_Wandlampe").w, locy3 - Assets.GetSprite("gfx_building_Wandlampe").h)
			UnlockImage(gfx_building.parent.image)
			Pix = Null
			ItemsDrawnToBackground = True
		EndIf
	End Method

	Method Draw(tweenValue:Float=1.0)
		TProfiler.Enter("Draw-Building-Background")
		DrawBackground(tweenValue)
		TProfiler.Leave("Draw-Building-Background")

		If Building.GetFloor(Players[Game.playerID].Figure.rect.GetY()) <= 4
			SetColor Int(205 * timecolor) + 150, Int(205 * timecolor) + 150, Int(205 * timecolor) + 150
			Building.gfx_buildingEntrance.Draw(pos.x, pos.y + 1024 - Building.gfx_buildingEntrance.h - 3)
			Building.gfx_buildingWall.Draw(pos.x + 127 + 507, pos.y + 1024 - Building.gfx_buildingWall.h - 3)
		Else If Building.GetFloor(Players[Game.playerID].Figure.rect.GetY()) >= 8
			SetColor 255, 255, 255
			Building.gfx_buildingRoof.Draw(pos.x + 127, pos.y - Building.gfx_buildingRoof.h)
		EndIf
		SetBlend MASKBLEND
		elevator.DrawFloorDoors()

		Assets.GetSprite("gfx_building").draw(pos.x + 127, pos.y)

		SetBlend MASKBLEND

		'draw overlay - open doors are drawn over "background-image-doors" etc.
		TRooms.DrawDoors()
		'draw elevator parts
		Elevator.Draw()

		SetBlend ALPHABLEND

		For Local Figure:TFigures = EachIn TFigures.List
			If Not Figure.alreadydrawn Then Figure.Draw()
		Next


		SetBlend MASKBLEND
		Local pack:TGW_Spritepack = Assets.getSpritePack("gfx_hochhauspack")
		pack.GetSprite("gfx_building_Pflanze1").Draw(pos.x + borderright - 130, pos.y + GetFloorY(9), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze1").Draw(pos.x + borderleft + 150, pos.y + GetFloorY(13), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze2").Draw(pos.x + borderright - 110, pos.y + GetFloorY(9), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze2").Draw(pos.x + borderleft + 150, pos.y + GetFloorY(6), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze6").Draw(pos.x + borderright - 85, pos.y + GetFloorY(8), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze3a").Draw(pos.x + borderleft + 60, pos.y + GetFloorY(1), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze3a").Draw(pos.x + borderleft + 60, pos.y + GetFloorY(12), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze3b").Draw(pos.x + borderleft + 150, pos.y + GetFloorY(12), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze1").Draw(pos.x + borderright - 70, pos.y + GetFloorY(3), - 1, 1)
		pack.GetSprite("gfx_building_Pflanze2").Draw(pos.x + borderright - 75, pos.y + GetFloorY(12), - 1, 1)
		SetBlend ALPHABLEND
		TRooms.DrawDoorToolTips()
		if self.roomUsedTooltip <> null then self.roomUsedTooltip.Draw()
	End Method

	Method UpdateBackground(deltaTime:Float)
		ActHour = Game.GetHour()
		DezimalTime = Float(Game.GetHour()) + Float(Game.GetMinute())*10/6/100
		If 9 <= ActHour And Acthour < 18 Then TimeColor = 1
		If 5 <= ActHour And Acthour <= 9 		'overlapping to avoid colorjumps
			skycolor = DezimalTime
			TimeColor = (skycolor - 5) / 4
			If TimeColor > 1 Then TimeColor = 1
			If skycolor >= 350 Then skycolor = 350
		EndIf
		If 18 <= ActHour And Acthour <= 23 	'overlapping to avoid colorjumps
			skycolor = DezimalTime
			TimeColor = 1 - (skycolor - 18) / 5
			If TimeColor < 0 Then TimeColor = 0
			If skycolor <= 0 Then skycolor = 0
		EndIf
		'compute and draw moon
		If ActHour > 18 Or ActHour < 7 Then Moon_pixelPerSecond = Float(Floor(Game.speed * 10))
		If ActHour > 18 And ActHour < 20
			Moon_tPos = 2;
			Moon_lastTChange = MilliSecs()
		EndIf
		If ActHour = 7 Or ActHour = 18
			Moon_tPos = 2;
			Moon_pixelPerSecond = 1
			Moon_lastTChange = MilliSecs()
		EndIf
		Local nextTPos:Float
		Local curDist:Float =0
		For nextTPos = Moon_tPos To Moon_tPos + Moon_curKubSplineX.dataX[Moon_curKubSplineX.dataCount - 1] -.001 Step.001
			curDist:+Sqr((Moon_curKubSplineX.Value(nextTPos +.001) - Moon_curKubSplineX.Value(nextTPos)) ^ 2 + (Moon_curKubSplineY.Value(nextTPos +.001) - Moon_curKubSplineY.Value(nextTPos)) ^ 2)
			If curDist >= Moon_pixelPerSecond Then Exit
		Next
		Moon_tPos:+(nextTPos - Moon_tPos) * (MilliSecs() - Moon_lastTChange) / 1000
		Moon_lastTChange = MilliSecs()
		'end compute and draw moon
		If DezimalTime > 18 Or DezimalTime < 7
			If Game.GetDay() Mod 2 = 0
				'compute and draw Ufo
				If ActHour < 6 Then ufo_pixelPerSecond = Float(Floor(Game.speed * 30))
				If ActHour = 0
					ufo_tPos = 1
					ufo_lastTChange = MilliSecs()
				EndIf
				If ActHour = 6 'or ActHour = 18
					ufo_tPos = 6
					ufo_pixelPerSecond = 1
					ufo_lastTChange = MilliSecs()
				EndIf
				If (Floor(ufo_curKubSplineX.ValueInt(ufo_tPos)) = 65 And Floor(ufo_curKubSplineY.ValueInt(ufo_tPos)) = 330) Or (ufo_beaming.getCurrentAnimation().getCurrentFramePos() > 1 And ufo_beaming.getCurrentAnimation().getCurrentFramePos() <= ufo_beaming.getCurrentAnimation().getFrameCount())
					ufo_beaming.rect.position.SetXY( 65, -15 + 105 + 0.25 * (pos.y + Assets.GetSprite("gfx_building").h - Assets.GetSprite("gfx_building_BG_Ebene3L").h) )
					ufo_beaming.Update(deltatime)
					If ufo_beaming.getCurrentAnimation().getCurrentFramePos() <> 6
						ufo_pixelPerSecond = 0
					Else
						ufo_pixelPerSecond = 10
						ufo_lastTChange:+50
					EndIf
				Else
					curDist = 0
					For nextTPos = ufo_tPos To ufo_tPos + ufo_curKubSplineX.dataX[ufo_curKubSplineX.dataCount - 1] -.001 Step.001
						curDist:+Sqr((ufo_curKubSplineX.Value(nextTPos +.001) - ufo_curKubSplineX.Value(nextTPos)) ^ 2 + (ufo_curKubSplineY.Value(nextTPos +.001) - ufo_curKubSplineY.Value(nextTPos)) ^ 2)
						If curDist >= ufo_pixelPerSecond Then Exit
					Next
				EndIf
				If ufo_pixelPerSecond > 0 Then ufo_tPos:+(nextTPos - ufo_tPos) * (MilliSecs() - ufo_lastTChange) / 1000
				ufo_lastTChange = MilliSecs()
				'end compute and draw Ufo
			EndIf
		EndIf
		For Local i:Int = 0 To Building.CloudCount-1
			Clouds[i].Update(deltaTime)
		Next
	End Method

	'Summary: Draws background of the mainscreen (stars, buildings, moon...)
	Method DrawBackground(tweenValue:Float=1.0)
		Local BuildingHeight:Int = gfx_building.h + 56
		SetBlend MASKBLEND
		DezimalTime = Float(Game.GetHour()) + Float(Game.GetMinute())*10/6/100
		If DezimalTime > 18 Or DezimalTime < 7
			If DezimalTime > 18 And DezimalTime < 19 Then SetAlpha (19 - Dezimaltime)
			If DezimalTime > 6 And DezimalTime < 8 Then SetAlpha (4 - Dezimaltime / 2)

			'stars
			Local minute:Float = Game.GetMinute()
			For Local i:Int = 0 To 59
				If i Mod 6 = 0 And minute Mod 2 = 0 Then StarsC[i] = RandMax( Max(1,StarsC[i]) )
				SetColor StarsC[i] , StarsC[i] , StarsC[i]
				Plot(StarsX[i] , StarsY[i] )
			Next

			SetColor 255, 255, 255
			DezimalTime:+3
			If DezimalTime > 24 Then DezimalTime:-24
			SetBlend ALPHABLEND
			Assets.GetSprite("gfx_building_BG_moon").DrawInViewPort(Moon_curKubSplineX.ValueInt(Moon_tPos), pos.y + Moon_curKubSplineY.ValueInt(Moon_tPos), 0, Game.GetDay() Mod 12)
		EndIf
		SetColor Int(205 * timecolor) + 50, Int(205 * timecolor) + 50, Int(205 * timecolor) + 50

		For Local i:Int = 0 To Building.CloudCount - 1
			Clouds[i].Draw(Null, Clouds[i].rect.position.Y + 0.2*pos.y) 'parallax
		Next

		If DezimalTime > 18 Or DezimalTime < 7
			SetBlend MASKBLEND
			SetAlpha 1.0

			If Game.GetDay() Mod 2 = 0 Then
				'compute and draw Ufo
				If (Floor(ufo_curKubSplineX.ValueInt(ufo_tPos)) = 65 And Floor(ufo_curKubSplineY.ValueInt(ufo_tPos)) = 330) Or (ufo_beaming.getCurrentAnimation().getCurrentFramePos() > 1 And ufo_beaming.getCurrentAnimation().getCurrentFramePos() <= ufo_beaming.getCurrentAnimation().getFrameCount())
					ufo_beaming.Draw()
				Else
					Assets.GetSprite("gfx_building_BG_ufo").DrawInViewPort(ufo_curKubSplineX.ValueInt(ufo_tPos), - 330 - 15 + 105 + 0.25 * (pos.y + Assets.GetSprite("gfx_building").h - Assets.GetSprite("gfx_building_BG_Ebene3L").h) + ufo_curKubSplineY.ValueInt(ufo_tPos), 0, ufo_normal.GetCurrentFrame())
				EndIf
			EndIf
		EndIf

		SetBlend MASKBLEND

		SetColor Int(225 * timecolor) + 30, Int(225 * timecolor) + 30, Int(225 * timecolor) + 30
		gfx_bgBuildings[0].Draw(pos.x		, 105 + 0.25 * (pos.y + 5 + BuildingHeight - gfx_bgBuildings[0].h), - 1, 0)
		gfx_bgBuildings[1].Draw(pos.x + 634	, 105 + 0.25 * (pos.y + 5 + BuildingHeight - gfx_bgBuildings[1].h), - 1, 0)

		SetColor Int(215 * timecolor) + 40, Int(215 * timecolor) + 40, Int(215 * timecolor) + 40
		gfx_bgBuildings[2].Draw(pos.x		, 120 + 0.35 * (pos.y 		+ BuildingHeight - gfx_bgBuildings[2].h), - 1, 0)
		gfx_bgBuildings[3].Draw(pos.x + 636	, 120 + 0.35 * (pos.y + 60	+ BuildingHeight - gfx_bgBuildings[3].h), - 1, 0)

		SetColor Int(205 * timecolor) + 50, Int(205 * timecolor) + 50, Int(205 * timecolor) + 50
		gfx_bgBuildings[4].Draw(pos.x		, 45 + 0.80 * (pos.y + BuildingHeight - gfx_bgBuildings[4].h), - 1, 0)
		gfx_bgBuildings[5].Draw(pos.x + 634	, 45 + 0.80 * (pos.y + BuildingHeight - gfx_bgBuildings[5].h), - 1, 0)

		SetColor 255, 255, 255
		SetBlend ALPHABLEND
	End Method

	Method CreateRoomUsedTooltip:int(room:TRooms)
		roomUsedTooltip			= TTooltip.Create("Besetzt", "In diesem Raum ist schon jemand", 0,0,-1,-1,2000)
		roomUsedTooltip.pos.y	= pos.y + GetFloorY(room.Pos.y)
		roomUsedTooltip.pos.x	= room.Pos.x + room.doorwidth/2 - roomUsedTooltip.GetWidth()/2
		roomUsedTooltip.enabled = 1
	End Method

	Method CenterToFloor:Int(floornumber:Int)
		pos.y = ((13 - (floornumber)) * 73) - 115
	End Method

	'Summary: returns y which has to be added to building.y, so its the difference
	Method GetFloorY:Int(floornumber:Int)
		Return (66 + 1 + (13 - floornumber) * 73)		  ' +10 = interface
	End Method

	Method GetFloor:Int(_y:Int)
		Return Clamp(14 - Ceil((_y - pos.y) / 73),0,13) 'TODO/FIXIT mv 10.11.2012 scheint nicht zu funktionieren!!! Liefert immer die gleiche Zahl egal in welchem Stockwerk man ist
	End Method

	Method getFloorByPixelExactPoint:Int(point:TPoint) 'y ist hier NICHT zwischen 0 und 13... sondern pixelgenau... also zwischen 0 und ~ 1000
		for local i:int = 0 to 13
			If Building.GetFloorY(i) < point.y Then Return i
		next
		Return -1
	End Method
End Type


'likely a kind of agency providing news... 'at the moment only a base object
Type TNewsAgency
	Field LastEventTime:Double = 0
	Field NextEventTime:Double = 0
	Field LastNewsList:TList = CreateList() 'holding news from the past hours/day for chains


	Method GetNextFromChain:TNews()
		Local news:TNews
		For Local parentnews:TNews = EachIn LastNewsList
			If Game.GetDay(parentnews.happenedtime) < Game.getDay()
				If parentnews.parent <> Null
					If parentnews.episode < parentnews.parent.episodecount
						news = TNews.GetNextInNewsChain(parentnews)
					EndIf
				End If
				If parentnews.episodecount > 0 And parentnews.parent = Null
					news = TNews.GetNextInNewsChain(parentnews, True) 'true = is the parent
				EndIf
				LastNewsList.Remove(parentnews)
				If news <> Null Then PrintDebug("TNewsAgency.GetNextFromChain()", "NEWS: returning news:" + news.episode + " " + news.title, DEBUG_NEWS)
				'Print "NEWS: returning previous news"
				Return news
			End If
		Next
		'Print "NEWS: no previous news found"
	End Method

	Method AddNewsToPlayer(news:TNews, forPlayer:Int=-1, fromNetwork:Int=0)
		'only add news/newsblock if player is Host/Player OR AI
		if not Game.isLocalPlayer(forPlayer) AND not Game.isAIPlayer(forPlayer) then return 'TODO: Wenn man gerade Spieler 2 ist/verfolgt (Taste 2) dann bekommt Spieler 1 keine News
		If Players[ forPlayer ].newsabonnements[news.genre] > 0
			TNewsBlock.Create("", forPlayer, 60*(3-Players[ forPlayer ].newsabonnements[news.genre]), news)
			If Game.isGameLeader() And Not fromNetwork And Game.networkgame Then NetworkHelper.SendNews( forPlayer, news)
		EndIf
	End Method

	Method AnnounceNewNews(delayAnnouncement:int=0)
		Local news:TNews = Null
		If RandRange(1,10)>3 Then news = GetNextFromChain()  '70% alte Nachrichten holen, 30% neue Kette/Singlenews
		If news = Null Then news = TNews.GetRandomNews() 'TNews.GetRandomChainParent()
		If news <> Null
			news.happenedtime			= Game.timeGone + delayAnnouncement

			Local NoOneSubscribed:Int	= True
			For Local i:Int = 1 To 4
				If Players[i].newsabonnements[news.genre] > 0 Then NoOneSubscribed = False
			Next
			'only add news if there are players wanting the news, else save them
			'for later stages
			If Not NoOneSubscribed
				For Local i:Int = 1 To 4
					AddNewsToPlayer(news, i)
				Next
				LastNewsList.AddLast(News)
				Print "ANNOUNCENEWNEWS: added news | "+news.title+" | now:"+Game.GetTimeGone()+" | happenedtime:"+news.happenedtime+" day:"+Game.getDay(news.happenedtime)+" "+Game.GetFormattedTime(news.happenedtime)
			Else
				News.used = 0
			EndIf
		EndIf
		LastEventTime = Game.timeGone
		If RandRange(0,10) = 1
			NextEventTime = Game.timeGone + RandRange(20,50) 'between 20 and 50 minutes until next news
		Else
			NextEventTime = Game.timeGone + RandRange(90,250) 'between 90 and 250 minutes until next news
		EndIf
	End Method
End Type



Function UpdateBote:Int(ListLink:TLink, deltaTime:Float=1.0) 'SpecialTime = 1 if letter in hand
	Local Figure:TFigures = TFigures(ListLink.value())
	Figure.FigureMovement(deltaTime)
	Figure.FigureAnimation(deltaTime)
	If figure.inRoom <> Null
		If figure.SpecialTimer.isExpired()
			Figure.SpecialTimer.Reset()
			'sometimes wait a bit longer
			if rand(0,100) < 20
				Local room:TRooms
				Repeat
					room = TRooms(TRooms.RoomList.ValueAtIndex(Rand(TRooms.RoomList.Count() - 1)))
				Until room.doortype >0 and room <> Figure.inRoom

				If Figure.sprite = Assets.GetSpritePack("figures").GetSprite("BotePost")
					Figure.sprite = Assets.GetSpritePack("figures").GetSprite("BoteLeer")
				else
					Figure.sprite = Assets.GetSpritePack("figures").GetSprite("BotePost")
				EndIf
				'Print "Bote: war in Raum -> neues Ziel gesucht"
				Figure.ChangeTarget(room.Pos.x + 13, Building.pos.y + Building.GetFloorY(room.Pos.y) - figure.sprite.h)
			endif
		EndIf
	EndIf
	If figure.inRoom = Null And figure.clickedToRoom = Null And figure.vel.GetX() = 0 And Not (Figure.IsAtElevator() Or Figure.IsInElevator()) 'not moving but not in/at elevator
		Local room:TRooms
		Repeat
			room = TRooms(TRooms.RoomList.ValueAtIndex(Rand(TRooms.RoomList.Count() - 1)))
		Until room.doortype >0 and room.name = "supermarket"
		'Print "Bote: steht rum -> neues Ziel gesucht"
		Figure.ChangeTarget(room.Pos.x + 13, Building.pos.y + Building.GetFloorY(room.Pos.y) - figure.sprite.h)
	EndIf
End Function

Function UpdateHausmeister:Int(ListLink:TLink, deltaTime:Float=1.0)
	Local Figure:TFigures = TFigures(ListLink.value())

	'waited to long - change target
	If figure.hasToChangeFloor() and figure.WaitAtElevatorTimer.isExpired()
		figure.WaitAtElevatorTimer.Reset()
		Figure.ChangeTarget(RandRange(150, 580), Building.pos.y + Building.GetFloorY(figure.GetFloor()) - figure.sprite.h)
	EndIf

	'reached target
	If Int(Figure.rect.GetX()) = Int(Figure.target.x) And Not Figure.IsInElevator() And Not figure.hasToChangeFloor()
		'do something special
		If figure.SpecialTimer.isExpired()
			'reset is done later - we want to catch isExpired there too
			'figure.SpecialTimer.Reset()

			Local zufall:Int = RandRange(0, 100)	'what to do?
			Local zufallx:Int = RandRange(150, 580)	'where to go?

			'move to a spot further away than just some pixels
			Repeat
				zufallx = RandRange(150, 580)
			Until Abs(figure.rect.GetX() - zufallx) > 15

			'move to a different floor
			If zufall > 80 And Not figure.IsAtElevator() And Not figure.hasToChangeFloor()
				Local sendToFloor:Int = figure.GetFloor() + 1
				If sendToFloor > 13 Then sendToFloor = 0
				Figure.ChangeTarget(zufallx, Building.pos.y + Building.GetFloorY(sendToFloor) - figure.sprite.h)
				Figure.WaitAtElevatorTimer.Reset()

			'move to a different X on same floor
			Else If zufall <= 80 And Not figure.hasToChangeFloor()
				Figure.ChangeTarget(zufallx, Building.pos.y + Building.GetFloorY(figure.GetFloor()) - figure.sprite.h)
			EndIf
		EndIf
	EndIf
	'do default Movement (limit borders, move in elevator...)
	Figure.FigureMovement(deltaTime)

	'get next sprite frame number
	If Figure.vel.GetX() = 0
		'show the backside if at elevator
		If Figure.hasToChangeFloor() and not Figure.IsInElevator() and Figure.IsAtElevator()
			Figure.setCurrentAnimation("standBack",true)
		'show front or custom idle/specials
		Else
			'stopping from movement -> do special
			If Figure.getCurrentAnimationName() = "walkright" or Figure.getCurrentAnimationName() = "walkright"
				Figure.SpecialTimer.expire()
			endif

			'maybe something special?
			If Figure.SpecialTimer.isExpired()
				Figure.SpecialTimer.Reset()

				'only clean with a chance of 30%
				if RandRange(0,100) < 30
					'clean to the right
					If Figure.getCurrentAnimationName() = "walkright"
						Figure.setCurrentAnimation("cleanRight")
					'clean to the left
					else
						Figure.setCurrentAnimation("cleanLeft")
					endif
				else
					Figure.setCurrentAnimation("standFront")
				endif
			EndIf
		EndIf
	EndIf
	if Figure.vel.GetX() > 0 then Figure.setCurrentAnimation("walkRight")
	if Figure.vel.GetX() < 0 then Figure.setCurrentAnimation("walkLeft")


	'limit position to left and right border of building
	If Floor(Figure.rect.GetX()) <= 200 Then Figure.rect.position.setX(200);Figure.target.setX(200)
	If Floor(Figure.rect.GetX()) >= 579 Then Figure.rect.position.setX(579);Figure.target.setX(579)
End Function


'Sound-Files einlesen - da es lange dauert eventuell nur bei Bedarf oder in einem anderen Thread laden.
SoundManager.SetDefaultReceiver(TPlayerElementPosition.Create())
SoundManager.LoadSoundFiles()


'#Region: Globals, Player-Creation
Global StationMap:TStationMap	= TStationMap.Create()
Global Interface:TInterface		= TInterface.Create()
Global Game:TGame	  			= TGame.Create()
Global Building:TBuilding		= TBuilding.Create()

EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Create Rooms").AddNumber("itemNumber", 1).AddNumber("maxItemNumber", 1) ) )
Init_CreateAllRooms() 				'creates all Rooms - with the names assigned at this moment

'Creating PlayerColors - could also be done "automagically"
local playerColors:TList = Assets.GetList("playerColors")
if playerColors = null then Throw "no playerColors found in configuration"
For local col:TColor = eachin playerColors
	col.AddToList()
Next




'create playerfigures in figures-image
'Local tmpFigure:TImage = Assets.GetSpritePack("figures").GetSpriteImage("", 0)
Global Players:TPlayer[5]
'TColor.GetByOwner -> get first unused color, TPlayer.Create sets owner of the color
Players[1] = TPlayer.Create(Game.username	,Game.userchannelname	,Assets.GetSprite("Player1"),	500,  1, 90, TColor.getByOwner(0), 1, "Player 1")
Players[2] = TPlayer.Create("Alfie"			,"SunTV"				,Assets.GetSprite("Player2"),	450,  3, 90, TColor.getByOwner(0), 0, "Player 2")
Players[3] = TPlayer.Create("Seidi"			,"FunTV"				,Assets.GetSprite("Player3"),	250,  8, 90, TColor.getByOwner(0), 0, "Player 3")
Players[4] = TPlayer.Create("Sandra"		,"RatTV"				,Assets.GetSprite("Player4"),	480, 13, 90, TColor.getByOwner(0), 0, "Player 4")

Local tempfigur:TFigures= new TFigures.CreateFigure("Hausmeister", Assets.GetSprite("figure_Hausmeister"), 210, 2,60,0)
tempfigur.InsertAnimation("cleanRight", TAnimation.Create([ [11,130], [12,130] ], -1, 0) )
tempfigur.InsertAnimation("cleanLeft", TAnimation.Create([ [13,130], [14,130] ], -1, 0) )

tempfigur.rect.dimension.SetX(12) 'overwriting
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateHausmeister
Global figure_HausmeisterID:Int = tempfigur.id

tempfigur				= new TFigures.CreateFigure("Bote1", Assets.GetSprite("BoteLeer"), 210, 3, 65, 0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote

tempfigur				= new TFigures.CreateFigure("Bote2", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 1,-65,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote
REM
tempfigur				= new TFigures.CreateFigure("Bote3", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 2,-55,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote

tempfigur				= new TFigures.CreateFigure("Bote4", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 3,-45,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote

tempfigur				= new TFigures.CreateFigure("Bote5", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 4,-75,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote

tempfigur				= new TFigures.CreateFigure("Bote6", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 5,-85,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote

tempfigur				= new TFigures.CreateFigure("Bote7", Assets.GetSpritePack("figures").GetSprite("BotePost"), 410, 6,-70,0)
tempfigur.rect.dimension.SetX(12)
tempfigur.target.setX(550)
tempfigur.updatefunc_	= UpdateBote
ENDREM
tempfigur = Null

Global MenuPlayerNames:TGUIinput[4]
Global MenuChannelNames:TGUIinput[4]
Global MenuFigureArrows:TGUIArrowButton[8]

PrintDebug ("Base", "creating GUIelements", DEBUG_START)
'MainMenu

Global MainMenuButton_Start:TGUIButton		= new TGUIButton.Create(TPoint.Create(600, 300), 120, GetLocale("MENU_SOLO_GAME"), "MainMenu", Assets.fonts.baseFontBold)
Global MainMenuButton_Network:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 348), 120, GetLocale("MENU_NETWORKGAME"), "MainMenu", Assets.fonts.baseFontBold)
Global MainMenuButton_Online:TGUIButton		= new TGUIButton.Create(TPoint.Create(600, 396), 120, GetLocale("MENU_ONLINEGAME"), "MainMenu", Assets.fonts.baseFontBold)


Global NetgameLobbyButton_Join:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 300), 120, GetLocale("MENU_JOIN"), "NetGameLobby", Assets.fonts.baseFontBold)
Global NetgameLobbyButton_Create:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 345), 120, GetLocale("MENU_CREATE_GAME"), "NetGameLobby", Assets.fonts.baseFontBold)
Global NetgameLobbyButton_Back:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 390), 120, GetLocale("MENU_BACK"), "NetGameLobby", Assets.fonts.baseFontBold)
Global NetgameLobby_gamelist:TGUIList		= new TGUIList.Create(20, 300, 520, 250, 100, "NetGameLobby")
NetgameLobby_gamelist.SetFilter("HOSTGAME")
NetgameLobby_gamelist.AddBackground("")

Global GameSettingsBG:TGUIBackgroundBox = new TGUIBackgroundBox.Create(20, 20, 760, 260, "GameSettings")
GameSettingsBG.value = "Spieleinstellungen"
GameSettingsBG.useFont = Assets.GetFont("Default", 16, BOLDFONT)
Global GameSettingsOkButton_Announce:TGUIOkButton = new TGUIOkButton.Create(420, 234, FALSE, "Spieleinstellungen abgeschlossen", "GameSettings", Assets.fonts.baseFontBold)
Global GameSettingsGameTitle:TGuiInput		= new TGUIinput.Create(50, 230, 320, Game.title, 32, "GameSettings")
Global GameSettingsButton_Start:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 300), 120, GetLocale("MENU_START_GAME"), "GameSettings", Assets.fonts.baseFontBold)
Global GameSettingsButton_Back:TGUIButton	= new TGUIButton.Create(TPoint.Create(600, 345), 120, GetLocale("MENU_BACK"), "GameSettings", Assets.fonts.baseFontBold)

'chat windows
Global GameSettings_Chat:TGUIChatNEW = new TGUIChatNEW.Create(20,300,520,200,"GameSettings")
GameSettings_Chat.guiInput.setMaxLength(200)
GameSettings_Chat.SetBackground( new TGUIBackgroundBox.Create(0,0,520,200,"") )
GameSettings_Chat.SetPadding(35,5,7,6)
GameSettings_Chat.guiBackground.value	= "Chat"
GameSettings_Chat.guiBackground.usefont	= Assets.GetFont("Default", 16, BOLDFONT)

Global InGame_Chat:TGUIChatNEW = new TGUIChatNEW.Create(20,10,250,200,"InGame")
InGame_Chat.guiList.backgroundColor = TColor.Create(0,0,0,0.5)
InGame_Chat.setOption(GUI_OBJECT_CLICKABLE, FALSE)
InGame_Chat.SetDefaultTextColor( TColor.Create(255,255,255) )
InGame_Chat.guiList.autoHideScroller = true
'reposition input
InGame_Chat.guiInput.rect.position.setXY( 275, 387)
InGame_Chat.guiInput.setMaxLength(200)
InGame_Chat.guiInput.setOption(GUI_OBJECT_POSITIONABSOLUTE, TRUE)
InGame_Chat.guiInput.maxTextWidth		= gfx_GuiPack.GetSprite("Chat_IngameOverlay").w - 20
InGame_Chat.guiInput.InputImageActive	= gfx_GuiPack.GetSprite("Chat_IngameOverlay")
InGame_Chat.guiInput.color.adjust(255,255,255,true)
InGame_Chat.guiInput.autoAlignText = 0
InGame_Chat.guiInput.TextDisplacement.setXY(0,5)

'Doubleclick-function for NetGameLobby_GameList
Function onClick_NetGameLobby:Int(triggerEvent:TEventBase)
	Local evt:TEventSimple = TEventSimple(triggerEvent)
	If evt<>Null
		local clickType:int = evt.getData().getInt("type")
		if clickType = EVENT_GUI_DOUBLECLICK
			NetgameLobbyButton_Join.mouseIsClicked	= TPoint.Create(1,1)
			GameSettingsButton_Start.disable()

			If Network.ConnectToServer( HostIp(NetgameLobby_gamelist.GetEntryIP()), NetgameLobby_gamelist.GetEntryPort() )
				Game.gamestate = GAMESTATE_SETTINGSMENU
				GameSettingsGameTitle.Value = NetgameLobby_gamelist.GetEntryTitle()
			EndIf
		endif
	endif
End Function
EventManager.registerListenerFunction( "guiobject.onClick",	onClick_NetGameLobby, NetgameLobby_gamelist )


Include "gamefunctions_network.bmx"
'Network.init(game.userfallbackip)

For Local i:Int = 0 To 7
	If i < 4
		MenuPlayerNames[i]	= new TGUIinput.Create(50 + 190 * i, 65, 130, Players[i + 1].Name, 16, "GameSettings", Assets.GetFont("Default", 12)).SetOverlayImage(Assets.GetSprite("gfx_gui_overlay_player"))
		MenuPlayerNames[i].TextDisplacement.setX(3)
		MenuPlayerNames[i].setZindex(150)

		MenuChannelNames[i]	= new TGUIinput.Create(50 + 190 * i, 180, 130, Players[i + 1].channelname, 16, "GameSettings", Assets.GetFont("Default", 12)).SetOverlayImage(Assets.GetSprite("gfx_gui_overlay_tvchannel"))
		MenuChannelNames[i].TextDisplacement.setX(3)
		MenuChannelNames[i].setZindex(150)
	EndIf
	If i Mod 2 = 0
		MenuFigureArrows[i] = new TGUIArrowButton.Create(25+ 20+190*Ceil(i/2)+10, 125,0,"GameSettings")
	Else
		MenuFigureArrows[i] = new TGUIArrowButton.Create(25+140+190*Ceil(i/2)+10, 125,2,"GameSettings")
		MenuFigureArrows[i].rect.position.MoveXY(-MenuFigureArrows[i].GetScreenWidth(),0)
	EndIf
	MenuFigureArrows[i].setZindex(150)
Next


CreateDropZones()
Global Database:TDatabase = TDatabase.Create(); Database.Load(Game.userdb) 'load all movies, news, series and ad-contracts

StationMap.AddStation(310, 260, 1, Players[1].maxaudience)
StationMap.AddStation(310, 260, 2, Players[2].maxaudience)
StationMap.AddStation(310, 260, 3, Players[3].maxaudience)
StationMap.AddStation(310, 260, 4, Players[4].maxaudience)

SetColor 255,255,255

For Local i:Int = 0 To 9
	local contract:TContract = TContract.Create( TContractBase.GetRandomWithMaxAudience(Game.getMaxAudience(-1), 0.15) )
	TContractBlock.Create(contract, i, 0)
	TMovieAgencyBlocks.Create(TProgramme.GetRandomMovie(),i,0)
	If i > 0 And i < 9 Then TAuctionProgrammeBlocks.Create(TProgramme.GetRandomMovieWithMinPrice(200000),i)
Next

Global PlayerDetailsTimer:Int
'Menuroutines... Submenus and so on
Function Menu_Main()
	GUIManager.Update("MainMenu")
	If MainMenuButton_Start.GetClicks() > 0 Then Game.gamestate = GAMESTATE_SETTINGSMENU
	If MainMenuButton_Network.GetClicks() > 0
		Game.gamestate  = GAMESTATE_NETWORKLOBBY
		Game.onlinegame = 0
	EndIf
	If MainMenuButton_Online.GetClicks() > 0
		Game.gamestate = GAMESTATE_NETWORKLOBBY
		Game.onlinegame = 1
	EndIf
	'multiplayer
	If game.gamestate = GAMESTATE_NETWORKLOBBY then Game.networkgame = 1
End Function

Function Menu_NetworkLobby()
	NetgameLobby_gamelist.RemoveOldEntries(NetgameLobby_gamelist._id, 11000)
	If Game.onlinegame
		If Network.OnlineIP = ""
			Local Onlinestream:TStream	= ReadStream("http::www.tvgigant.de/lobby/lobby.php?action=MyIP")
			Local timeouttimer:Int		= MilliSecs()+5000 '5 seconds okay?
			Local timeout:Byte			= False
			If Not Onlinestream Then Throw ("Not Online?")
			While Not Eof(Onlinestream) Or timeout
				If timeouttimer < MilliSecs() Then timeout = True
				Local responsestring:String = ReadLine(Onlinestream)
				Local responseArray:String[] = responsestring.split("|")
				If responseArray <> Null
					Network.OnlineIP = responseArray[0]
					Network.intOnlineIP = HostIp(Network.OnlineIP)
'					Network.intOnlineIP = TNetwork.IntIP(Network.OnlineIP)
					Print "set your onlineIP"+responseArray[0]
				EndIf
			Wend
			CloseStream Onlinestream
		Else
			NetgameLobby_gamelist.SetFilter("ONLINEHOSTGAME")
			If Network.LastOnlineRequestTimer + Network.LastOnlineRequestTime < MilliSecs()
				Network.LastOnlineRequestTimer = MilliSecs()
				Local Onlinestream:TStream   = ReadStream("http::www.tvgigant.de/lobby/lobby.php?action=ListGames")
				Local timeouttimer:Int = MilliSecs()+2500 '2.5 seconds okay?
				Local timeout:Byte = False
				If Not Onlinestream Then Throw ("Not Online?")
				While Not Eof(Onlinestream) Or timeout
					If timeouttimer < MilliSecs() Then timeout = True
					Local responsestring:String = ReadLine(Onlinestream)
					Local responseArray:String[] = responsestring.split("|")
					If responseArray <> Null
						NetgameLobby_gamelist.addUniqueEntry(Network.URLDecode(responseArray[0]), Network.URLDecode(responseArray[0])+"  (Spieler: "+responseArray[1]+" von 4)","",responseArray[2],Short(responseArray[3]),0, "ONLINEHOSTGAME")
						Print "added "+responseArray[0]
					EndIf
				Wend
				CloseStream Onlinestream
			EndIf
		EndIf
	EndIf
	If Not Game.onlinegame Then NetgameLobby_gamelist.SetFilter("HOSTGAME")

	GUIManager.Update("NetGameLobby")
	If NetgameLobbyButton_Create.GetClicks() > 0 Then
		GameSettingsButton_Start.enable()
		Game.gamestate	= GAMESTATE_SETTINGSMENU
		Network.localFallbackIP = HostIp(game.userfallbackip)
		Network.StartServer()
		Network.ConnectToLocalServer()
		Network.client.playerID	= 1
	EndIf
	If NetgameLobbyButton_Join.GetClicks() > 0 Then
		GameSettingsButton_Start.disable()
		Network.isServer				= False

		If Network.ConnectToServer( HostIp(NetgameLobby_gamelist.GetEntryIP()), NetgameLobby_gamelist.GetEntryPort() )
			Game.gamestate = GAMESTATE_SETTINGSMENU
			GameSettingsGameTitle.Value = NetgameLobby_gamelist.GetEntryTitle()
		EndIf
	EndIf
	If NetgameLobbyButton_Back.GetClicks() > 0 Then
		Game.gamestate		= GAMESTATE_MAINMENU
		Game.onlinegame		= False

		If Network.infoStream Then Network.infoStream.close()
		Game.networkgame	= False
	EndIf
End Function

Function Menu_GameSettings()
	Local modifiedPlayers:Int = False
	Local ChangesAllowed:Byte[4]

	'disable/enable announcement on lan/online
	Network.announceEnabled = GameSettingsOkButton_Announce.crossed

	If GameSettingsOkButton_Announce.crossed And Game.playerID=1
		GameSettingsOkButton_Announce.enable()
		GameSettingsGameTitle.disable()
		If GameSettingsGameTitle.Value = "" Then GameSettingsGameTitle.Value = "no title"
		Game.title = GameSettingsGameTitle.Value
	Else
		GameSettingsGameTitle.enable()
	EndIf
	If Game.playerID <> 1
		GameSettingsGameTitle.disable()
		GameSettingsOkButton_Announce.disable()
	EndIf

	For Local i:Int = 0 To 3
		If Not MenuPlayerNames[i].isActive() Then Players[i+1].Name = MenuPlayerNames[i].Value
		If Not MenuChannelNames[i].isActive() Then Players[i+1].channelname = MenuChannelNames[i].Value
		If Game.networkgame Or Game.playerID=1 Then
			If Game.gamestate <> GAMESTATE_STARTMULTIPLAYER And Players[i+1].Figure.ControlledByID = Game.playerID Or (Players[i+1].Figure.ControlledByID = 0 And Game.playerID=1)
				ChangesAllowed[i] = True
				MenuPlayerNames[i].enable()
				MenuChannelNames[i].enable()
				MenuFigureArrows[i*2].enable()
				MenuFigureArrows[i*2 +1].enable()
			Else
				ChangesAllowed[i] = False
				MenuPlayerNames[i].disable()
				MenuChannelNames[i].disable()
				MenuFigureArrows[i*2].disable()
				MenuFigureArrows[i*2 +1].disable()
			EndIf
		EndIf
	Next

	GUIManager.Update("GameSettings")

	If GameSettingsButton_Start.GetClicks() > 0
		If Not Game.networkgame And Not Game.onlinegame
			If Not Init_Complete Then Init_All() ;Init_Complete = True		'check if rooms/colors/... are initiated
			Game.gamestate = GAMESTATE_RUNNING
		Else
			GameSettingsOkButton_Announce.crossed = False
			Interface.ShowChannel = Game.playerID

			Game.gamestate = GAMESTATE_STARTMULTIPLAYER
		EndIf

		'Begin Game - create Events
		EventManager.registerEvent( TEventOnTime.Create("Game.OnMinute", game.GetMinute()) )
		EventManager.registerEvent( TEventOnTime.Create("Game.OnHour", game.GetHour()) )
		EventManager.registerEvent( TEventOnTime.Create("Game.OnDay", Game.GetDay()) )

		'so we could add news etc.
		EventManager.triggerEvent( TEventSimple.Create("Game.OnStart") )

		Soundmanager.PlayMusic(MUSIC_MUSIC)
	EndIf
	If GameSettingsButton_Back.GetClicks() > 0 Then
		If Game.networkgame
			If Game.networkgame Then Network.DisconnectFromServer()
			Game.playerID = 1
			Game.gamestate = GAMESTATE_NETWORKLOBBY
			GameSettingsOkButton_Announce.crossed = False
		Else
			Game.gamestate = GAMESTATE_MAINMENU
		EndIf
	EndIf

	'clicks on color rect
	Local i:Int = 0

'	rewrite to Assets instead of global list in TColor ?
'	local colors:TList = Assets.GetList("PlayerColors")

	If MOUSEMANAGER.IsHit(1)
		For Local obj:TColor = EachIn TColor.List
			'only for unused colors
			If obj.ownerID = 0
				If functions.IsIn(MouseX(), MouseY(), 26 + 40 + i * 10, 92 + 68, 7, 9) And (Players[1].Figure.ControlledByID = Game.playerID Or (Players[1].Figure.ControlledByID = 0 And Game.playerID = 1)) Then modifiedPlayers=True;Players[1].RecolorFigure(obj)
				If functions.IsIn(MouseX(), MouseY(), 216 + 40 + i * 10, 92 + 68, 7, 9) And (Players[2].Figure.ControlledByID = Game.playerID Or (Players[2].Figure.ControlledByID = 0 And Game.playerID = 1)) Then modifiedPlayers=True;Players[2].RecolorFigure(obj)
				If functions.IsIn(MouseX(), MouseY(), 406 + 40 + i * 10, 92 + 68, 7, 9) And (Players[3].Figure.ControlledByID = Game.playerID Or (Players[3].Figure.ControlledByID = 0 And Game.playerID = 1)) Then modifiedPlayers=True;Players[3].RecolorFigure(obj)
				If functions.IsIn(MouseX(), MouseY(), 596 + 40 + i * 10, 92 + 68, 7, 9) And (Players[4].Figure.ControlledByID = Game.playerID Or (Players[4].Figure.ControlledByID = 0 And Game.playerID = 1)) Then modifiedPlayers=True;Players[4].RecolorFigure(obj)
				i:+1
			EndIf
		Next
	EndIf

	'left right arrows to change figure base
	For Local i:Int = 0 To 7
		If ChangesAllowed[Ceil(i/2)]
			If MenuFigureArrows[i].GetClicks() > 0
				If i Mod 2  = 0 Then Players[1+Ceil(i/2)].UpdateFigureBase(Players[Ceil(1+i/2)].figurebase -1)
				If i Mod 2 <> 0 Then Players[1+Ceil(i/2)].UpdateFigureBase(Players[Ceil(1+i/2)].figurebase +1)
				modifiedPlayers = True
			EndIf
		EndIf
	Next

	If Game.networkgame = 1
		If modifiedPlayers
			NetworkHelper.SendPlayerDetails()
			PlayerDetailsTimer = MilliSecs()
		EndIf
		If MilliSecs() >= PlayerDetailsTimer + 1000
			NetworkHelper.SendPlayerDetails()
			PlayerDetailsTimer = MilliSecs()
		EndIf
	EndIf


End Function

Global MenuPreviewPicTimer:Int = 0
Global MenuPreviewPicTime:Int = 4000
Global MenuPreviewPic:TGW_Sprites = Null
Function Menu_Main_Draw()
	If RandRange(0,10) = 10 Then GCCollect()
	SetColor 190,220,240
	SetAlpha 0.5
	DrawRect(0,0,App.settings.width,App.settings.Height)
	SetAlpha 1.0
	SetColor 255, 255, 255

	Local ScaledRoomHeight:Float = 190.0
	Local RoomImgScale:Float = ScaledRoomHeight / 373.0
	Local ScaledRoomWidth:Float = RoomImgScale * 760.0

	If MenuPreviewPicTimer < MilliSecs()
		MenuPreviewPicTimer = MilliSecs() + MenuPreviewPicTime
		MenuPreviewPic = TRooms(TRooms.RoomList.ValueAtIndex(Rnd(1, TRooms.RoomList.Count() - 1))).screenManager.GetCurrentScreen().background
	EndIf
	If MenuPreviewPic <> Null
		SetBlend ALPHABLEND
		If MenuPreviewPicTimer - MilliSecs() > 3000 Then SetAlpha (4.0 - Float(MenuPreviewPicTimer - MilliSecs()) / 1000)
		If MenuPreviewPicTimer - MilliSecs() < 750 Then SetAlpha (0.25 + Float(MenuPreviewPicTimer - MilliSecs()) / 1000)
		SetScale(RoomImgScale, RoomImgScale)
		MenuPreviewPic.Draw(55 + 5, 265 + 5, RoomImgScale)
		SetScale(1.0, 1.0)
		SetAlpha (1.0)
	EndIf
	DrawGFXRect(Assets.GetSpritePack("gfx_gui_rect"), 50, 260, ScaledRoomWidth + 20, 210)

	DrawGFXRect(Assets.GetSpritePack("gfx_gui_rect"), 575, 260, 170, 210)
	GUIManager.Draw("MainMenu")
End Function

Function Menu_NetworkLobby_Draw()
	SetColor 190,220,240
	SetAlpha 0.5
	DrawRect(0,0,App.settings.width,App.settings.height)
	SetAlpha 1.0
	SetColor 255,255,255

	If Not Game.onlinegame
		NetgameLobby_gamelist.background.value = Localization.GetString("MENU_NETWORKGAME")+" : "+Localization.GetString("MENU_AVAILABLE_GAMES")
	Else
		NetgameLobby_gamelist.background.value = Localization.GetString("MENU_ONLINEGAME")+" : "+Localization.GetString("MENU_AVAILABLE_GAMES")
	EndIf


	GUIManager.Draw("NetGameLobby")
End Function

Function Menu_GameSettings_Draw()
	SetColor 190,220,240
	SetAlpha 0.5
	DrawRect(0,0,App.settings.width,App.settings.height)
	SetAlpha 1.0
	SetColor 255,255,255

	' Local ChangesAllowed:Byte[4]
	If Not Game.networkgame
		GameSettingsBG.value = GetLocale("MENU_SOLO_GAME")
		GameSettings_Chat.setOption(GUI_OBJECT_VISIBLE,FALSE)
	Else
		GameSettings_Chat.setOption(GUI_OBJECT_VISIBLE,TRUE)
		If Not Game.onlinegame Then
			GameSettingsBG.value = GetLocale("MENU_NETWORKGAME")
		Else
			GameSettingsBG.value = GetLocale("MENU_ONLINEGAME")
		EndIf
	EndIf
	'background gui items
	GUIManager.Draw("GameSettings",0, 0, 100)

	For Local i:Int = 0 To 3
		SetColor 50,50,50
		DrawRect(60 + i*190, 90, 110,110)
		If Game.networkgame Or Game.playerID=1 Then
			If Game.gamestate <> GAMESTATE_STARTMULTIPLAYER And Players[i+1].Figure.ControlledByID = Game.playerID Or (Players[i+1].Figure.ControlledByID = 0 And Game.playerID=1)
				SetColor 255,255,255
			Else
				SetColor 225,255,150
			EndIf
		EndIf
		DrawRect(60 + i*190 +1, 90+1, 110-2,110-2)
'		DrawGFXRect(Assets.GetSpritePack("gfx_gui_rect"), 25 + 3 + i * 190, 50, 180, 200)
	Next

	'player-figure background
	SetColor 100,100,120
	DrawRect(25 + 40, 110, 101, 50 + 10) '+10 for colorselectionborders
	DrawRect(215 + 40, 110, 101, 50 + 10)
	DrawRect(405 + 40, 110, 101, 50 + 10)
	DrawRect(595 + 40, 110, 101, 50 + 10)
	SetColor 180,180,200
	DrawRect(25 + 41, 111, 99, 48)
	DrawRect(215 + 41, 111, 99, 48)
	DrawRect(405 + 41, 111, 99, 48)
	DrawRect(595 + 41, 111, 99, 48)


	Local i:Int =0
	For Local obj:TColor = EachIn TColor.List
		If obj.ownerID = 0 and i <= 10
			obj.SetRGB()
			DrawRect(26 + 40 + i * 10, 92 + 68, 9, 9)
			DrawRect(216 + 40 + i * 10, 92 + 68, 9, 9)
			DrawRect(406 + 40 + i * 10, 92 + 68, 9, 9)
			DrawRect(596 + 40 + i * 10, 92 + 68, 9, 9)
			i:+1
		EndIf
	Next
	SetColor 255,255,255

	Players[1].Figure.Sprite.Draw(25 + 90 - Players[1].Figure.Sprite.framew / 2, 159 - Players[1].Figure.Sprite.h, 8)
	Players[2].Figure.Sprite.Draw(215 + 90 - Players[2].Figure.Sprite.framew / 2, 159 - Players[2].Figure.Sprite.h, 8)
	Players[3].Figure.Sprite.Draw(405 + 90 - Players[3].Figure.Sprite.framew / 2, 159 - Players[3].Figure.Sprite.h, 8)
	Players[4].Figure.Sprite.Draw(595 + 90 - Players[4].Figure.Sprite.framew / 2, 159 - Players[4].Figure.Sprite.h, 8)

	'overlay gui items (higher zindex)
	GUIManager.Draw("GameSettings",0, 101)

	If Game.gamestate = GAMESTATE_STARTMULTIPLAYER
		SetColor 180,180,200
		SetAlpha 0.5
		DrawRect 200,200,400,200
		SetAlpha 1.0
		SetColor 0,0,0
		Assets.fonts.baseFont.draw("Synchronisiere Startbedingungen...", 220,220)
		Assets.fonts.baseFont.draw("Starte Netzwerkspiel...", 220,240)

		'master should spread startprogramme around
		If Game.isGameLeader()
			For Local playerids:Int = 1 To 4
				Local ProgrammeArray:TProgramme[Game.startMovieAmount + Game.startSeriesAmount + 1]
				SeedRnd(MilliSecs())
				Local i:Int = 0
				For i = 0 To Game.startMovieAmount-1
					ProgrammeArray[i] = TProgramme.GetRandomMovie(playerids)
				Next
				'give series to each player
				For i = Game.startMovieAmount To Game.startMovieAmount + Game.startSeriesAmount-1
					ProgrammeArray[i] = TProgramme.GetRandomSerie(playerids)
				Next
				'give 1 call in
				ProgrammeArray[Game.startMovieAmount + Game.startSeriesAmount] = TProgramme.GetRandomProgrammeByGenre(20)
				NetworkHelper.SendProgrammesToPlayer(playerids, ProgrammeArray)

				Local ContractArray:TContract[]
				For Local j:Int = 0 To Game.startAdAmount-1
					ContractArray		= ContractArray[..ContractArray.length+1]
					ContractArray[j]	= TContract.Create(TContractBase.GetRandomWithMaxAudience(Players[ playerids ].maxaudience, 0.10))
				Next
				NetworkHelper.SendContractsToPlayer(playerids, ContractArray)
				Print "sent data for player: "+playerids

				'add to local collections
				For Local programme:TProgramme = EachIn programmeArray
					If programme Then Players[ playerids ].ProgrammeCollection.AddProgramme( programme )
				Next
				For Local contract:TContract = EachIn contractArray
					If contract Then Players[ playerids ].ProgrammeCollection.AddContract( contract )
				Next



			Next
			NetworkHelper.SendGameReady(Game.playerID)
		EndIf

		Local start:Int = MilliSecs()
		Repeat
			SetColor 180,180,200
			SetAlpha 1.0
			DrawRect 200,200,400,200
			SetAlpha 1.0
			SetColor 0,0,0
			Assets.fonts.baseFont.draw("Synchronisiere Startbedingungen...", 220,220)
			Assets.fonts.baseFont.draw("Starte Netzwerkspiel...", 220,240)
			Assets.fonts.baseFont.draw("Player 1..."+Players[1].networkstate+" MovieListCount: "+Players[1].ProgrammeCollection.MovieList.Count(), 220,260)
			Assets.fonts.baseFont.draw("Player 2..."+Players[2].networkstate+" MovieListCount: "+Players[2].ProgrammeCollection.MovieList.Count(), 220,280)
			Assets.fonts.baseFont.draw("Player 3..."+Players[3].networkstate+" MovieListCount: "+Players[3].ProgrammeCollection.MovieList.Count(), 220,300)
			Assets.fonts.baseFont.draw("Player 4..."+Players[4].networkstate+" MovieListCount: "+Players[4].ProgrammeCollection.MovieList.Count(), 220,320)
			If Not Game.networkgameready = 1 Then Assets.fonts.baseFont.draw("not ready!!", 220,360)
			Flip
			Network.Update()
			If MilliSecs() - start > 5000 Then game.gamestate = GAMESTATE_SETTINGSMENU
		Until Game.networkgameready = 1 Or game.gamestate <> GAMESTATE_STARTMULTIPLAYER

		If Game.networkgameready
			If Not Init_Complete Then Init_All() ;Init_Complete = True		'check if rooms/colors/... are initiated
			Game.networkgameready = 1
			Game.gamestate = GAMESTATE_RUNNING
			GameSettingsOkButton_Announce.crossed = False
			Players[Game.playerID].networkstate=1
			Game.gamestate = GAMESTATE_RUNNING
			Print "STARTED THE GAME ..."
		EndIf
	EndIf
End Function

Global Betty:TBetty = New TBetty
Type TBetty
	Field InLove:Float[5]
	Field LoveSum:Float
	Field AwardWinner:Float[5]
	Field AwardSum:Float = 0.0
	Field CurrentAwardType:Int = 0
	Field AwardEndingAtDay:Int = 0
	Field MaxAwardTypes:Int = 3
	Field AwardDuration:Int = 3
	Field LastAwardWinner:Int = 0
	Field LastAwardType:Int = 0

	Method IncInLove(PlayerID:Int, Amount:Float)
		For Local i:Int = 1 To 4
			Self.InLove[i] :-Amount / 4
		Next
		Self.InLove[PlayerID] :+Amount * 5 / 4
		Self.LoveSum = 0
		For Local i:Int = 1 To 4
			Self.LoveSum:+Self.InLove[i]
		Next
	End Method

	Method IncAward(PlayerID:Int, Amount:Float)
		For Local i:Int = 1 To 4
			Self.AwardWinner[i] :-Amount / 4
		Next
		Self.AwardWinner[PlayerID] :+Amount * 5 / 4
		Self.AwardSum = 0
		For Local i:Int = 1 To 4
			Self.AwardSum:+Self.AwardWinner[i]
		Next
	End Method

	Method GetAwardTypeString:String(AwardType:Int = 0)
		If AwardType = 0 Then AwardType = CurrentAwardType
		Select AwardType
			Case 0 Return "NONE"
			Case 1 Return "News"
			Case 2 Return "Kultur"
			Case 3 Return "Quoten"
		End Select
	End Method

	Method SetAwardType(AwardType:Int = 0, SetEndingDay:Int = 0, Duration:Int = 0)
		If Duration = 0 Then Duration = Self.AwardDuration
		CurrentAwardType = AwardType
		If SetEndingDay = True Then AwardEndingAtDay = Game.GetDay() + Duration
	End Method

	Method GetAwardEnding:Int()
		Return AwardEndingAtDay
	End Method

	Method GetRealLove:Int(PlayerID:Int)
		If Self.LoveSum < 100 Then Return Ceil(Self.InLove[PlayerID] / 100)
		Return Ceil(Self.InLove[PlayerID] / Self.LoveSum)
	End Method

	Method GetLastAwardWinner:Int()
		Local HighestAmount:Float = 0.0
		Local HighestPlayer:Int = 0
		For Local i:Int = 1 To 4
			If Self.GetRealAward(i) > HighestAmount Then HighestAmount = Self.GetRealAward(i) ;HighestPlayer = i
		Next
		LastAwardWinner = HighestPlayer
		Return HighestPlayer
	End Method

	Method GetRealAward:Int(PlayerID:Int)
		If Self.AwardSum < 100 Then Return Ceil(100 * Self.AwardWinner[PlayerID] / 100)
		Return Ceil(100 * Self.AwardWinner[PlayerID] / Self.AwardSum)
	End Method
End Type

Game.gamestate = GAMESTATE_MAINMENU
Function UpdateMenu(deltaTime:Float=1.0)
	'	App.Timer.Update(0)
	If Game.networkgame Then Network.Update()
	Select Game.gamestate
		Case GAMESTATE_MAINMENU
			Menu_Main()
		Case GAMESTATE_NETWORKLOBBY
			Menu_NetworkLobby()
		Case GAMESTATE_SETTINGSMENU, GAMESTATE_STARTMULTIPLAYER
			Menu_GameSettings()
	EndSelect

	If KEYMANAGER.IsHit(KEY_ESCAPE) Then ExitGame = 1
	If AppTerminate() Then ExitGame = 1
End Function

Global LogoTargetY:Float = 20
Global LogoCurrY:Float = 100
Function DrawMenu(tweenValue:Float=1.0)
'no cls needed - we render a background
'	Cls
	SetColor 255,255,255
	Assets.GetSprite("gfx_startscreen").Draw(0,0)

	' DrawImage(gfx_startscreen, 0, 0)


	Select game.gamestate
		Case GAMESTATE_SETTINGSMENU, GAMESTATE_STARTMULTIPLAYER
			Assets.GetSprite("gfx_startscreen_logoSmall").Draw(540, 480)
		Default
			If LogoCurrY > LogoTargetY Then LogoCurrY:+- 30.0 * App.Timer.getDeltaTime() Else LogoCurrY = LogoTargetY
			Assets.GetSprite("gfx_startscreen_logo").Draw(400, LogoCurrY, 0, 0, 0.5)
	EndSelect
	SetColor 0, 0, 0

	SetColor 255,255,255
	Assets.GetFont("Default",11, ITALICFONT).drawBlock(versionstring, 10,575, 500,20,0,75,75,140)
	Assets.GetFont("Default",11, ITALICFONT).drawBlock(copyrightstring, 10,585, 500,20,0,60,60,120)

	Select Game.gamestate
		Case GAMESTATE_MAINMENU
			Menu_Main_Draw()
		Case GAMESTATE_NETWORKLOBBY
			Menu_NetworkLobby_Draw()
		Case GAMESTATE_SETTINGSMENU, GAMESTATE_STARTMULTIPLAYER
			Menu_GameSettings_Draw()
	EndSelect

	If Game.cursorstate = 0 Then Assets.GetSprite("gfx_mousecursor").Draw(MouseX()-7, 	MouseY()	,0)
	If Game.cursorstate = 1 Then Assets.GetSprite("gfx_mousecursor").Draw(MouseX()-7, 	MouseY()-4	,1)
	If Game.cursorstate = 2 Then Assets.GetSprite("gfx_mousecursor").Draw(MouseX()-10,	MouseY()-12	,2)
End Function



Function Init_Creation()
	Local lastblocks:Int = 0
	'Local lastprogramme:TProgrammeBlock = New TProgrammeBlock
	For Local i:Int = 0 To 5
		TMovieAgencyBlocks.Create(TProgramme.GetRandomSerie(),20+i,0)
	Next

	'create random programmes and so on
	TFigures.GetByID(figure_HausmeisterID).updatefunc_ = Null
	If Not Game.networkgame Then
		For Local playerids:Int = 1 To 4
			SeedRnd(MilliSecs())
			Local i:Int = 0
			For i = 0 To Game.startMovieAmount-1
				Players[playerids].ProgrammeCollection.AddProgramme(TProgramme.GetRandomMovie(playerids))
			Next
			'give series to each player
			For i = Game.startMovieAmount To Game.startMovieAmount + Game.startSeriesAmount-1
				Players[playerids].ProgrammeCollection.AddProgramme(TProgramme.GetRandomSerie(playerids))
			Next
			'give 1 call in
			Players[playerids].ProgrammeCollection.AddProgramme(TProgramme.GetRandomProgrammeByGenre(20))

			For Local i:Int = 0 To 2
				Players[playerids].ProgrammeCollection.AddContract(TContract.Create(TContractBase.GetRandomWithMaxAudience(Players[ playerids ].maxaudience, 0.10)),playerids)
			Next
		Next
		TFigures.GetByID(figure_HausmeisterID).updatefunc_ = UpdateHausmeister
	EndIf
			'abonnement for each newsgroup = 1
	For Local playerids:Int = 1 To 4
		For Local i:Int = 0 To 4
			Players[playerids].SetNewsAbonnement(i, 1)
		Next
	Next

	'creation of blocks for players rooms
	For Local playerids:Int = 1 To 4
		lastblocks = 0
		SortList(Players[playerids].ProgrammeCollection.ContractList)

		local addWidth:int = Assets.GetSprite("pp_programmeblock1").w
		local addHeight:int = Assets.GetSprite("pp_adblock1").h
		local playerCollection:TPlayerProgrammeCollection = Players[playerids].ProgrammeCollection
		TAdBlock.Create(playerCollection.GetRandomContract(), 67 + addWidth, 17 + 0 * addHeight, playerids)
		TAdBlock.Create(playerCollection.GetRandomContract(), 67 + addWidth, 17 + 1 * addHeight, playerids)
		TAdBlock.Create(playerCollection.GetRandomContract(), 67 + addWidth, 17 + 2 * addHeight, playerids)

		Local lastprogramme:TProgrammeBlock
		lastprogramme = TProgrammeBlock.Create(67, 17 + 0 * Assets.GetSprite("pp_programmeblock1").h, 0, playerids, 1)
		lastblocks :+ lastprogramme.programme.blocks
		lastprogramme = TProgrammeBlock.Create(67, 17 + lastblocks * Assets.GetSprite("pp_programmeblock1").h, 0, playerids, 2)
		lastblocks :+ lastprogramme.programme.blocks
		lastprogramme = TProgrammeBlock.Create(67, 17 + lastblocks * Assets.GetSprite("pp_programmeblock1").h, 0, playerids, 3)
	Next
End Function

Function Init_Colorization()
	EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Colorization").AddNumber("itemNumber", 1).AddNumber("maxItemNumber", 1) ) )
	'colorize the images
	local gray:TColor = TColor.Create(200, 200, 200)
	local gray2:TColor = TColor.Create(100, 100, 100)
	Assets.AddImageAsSprite("gfx_financials_barren0", Assets.GetSprite("gfx_officepack_financials_barren").GetColorizedImage( gray ) )
	Assets.AddImageAsSprite("gfx_building_sign0", Assets.GetSprite("gfx_building_sign_base").GetColorizedImage( gray ) )
	Assets.AddImageAsSprite("gfx_elevator_sign0", Assets.GetSprite("gfx_elevator_sign_base").GetColorizedImage( gray ) )
	Assets.AddImageAsSprite("gfx_elevator_sign_dragged0", Assets.GetSprite("gfx_elevator_sign_dragged_base").GetColorizedImage( gray ) )
	Assets.AddImageAsSprite("gfx_interface_channelbuttons0", Assets.GetSprite("gfx_interface_channelbuttons_off").GetColorizedImage( gray2 ), Assets.GetSprite("gfx_building_sign_base").animcount )
	Assets.AddImageAsSprite("gfx_interface_channelbuttons5", Assets.GetSprite("gfx_interface_channelbuttons_on").GetColorizedImage( gray2 ), Assets.GetSprite("gfx_building_sign_base").animcount )

	'colorizing for every player and inputvalues (player and channelname) to players variables
	For Local i:Int = 1 To 4
		Players[i].Name					= MenuPlayerNames[i-1].Value
		Players[i].channelname			= MenuChannelNames[i-1].Value
		Assets.AddImageAsSprite("gfx_financials_barren"+i, Assets.GetSprite("gfx_officepack_financials_barren").GetColorizedImage(Players[i].color) )
		Assets.AddImageAsSprite("gfx_building_sign"+i, Assets.GetSprite("gfx_building_sign_base").GetColorizedImage(Players[i].color) )
		Assets.AddImageAsSprite("gfx_elevator_sign"+i, Assets.GetSprite("gfx_elevator_sign_base").GetColorizedImage( Players[i].color) )
		Assets.AddImageAsSprite("gfx_elevator_sign_dragged"+i, Assets.GetSprite("gfx_elevator_sign_dragged_base").GetColorizedImage(Players[i].color) )
		Assets.AddImageAsSprite("gfx_interface_channelbuttons"+i,   Assets.GetSprite("gfx_interface_channelbuttons_off").GetColorizedImage(Players[i].color),Assets.GetSprite("gfx_interface_channelbuttons_off").animcount )
		Assets.AddImageAsSprite("gfx_interface_channelbuttons"+(i+5), Assets.GetSprite("gfx_interface_channelbuttons_on").GetColorizedImage(Players[i].color),Assets.GetSprite("gfx_interface_channelbuttons_on").animcount )
	Next
End Function

Function Init_All()

	PrintDebug ("Init_All()", "start", DEBUG_START)
	Init_Creation()
	PrintDebug ("  Init_Colorization()", "colorizing Images corresponding to playercolors", DEBUG_START)
	Init_Colorization()

	EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Create Roomtooltips").AddNumber("itemNumber", 1).AddNumber("maxItemNumber", 1) ) )
	'setzt Raumnamen, erstellt Raum-Tooltips und Raumplaner-Schilder
	Init_CreateRoomDetails()

	EventManager.triggerEvent( TEventSimple.Create("Loader.onLoadElement", TData.Create().AddString("text", "Fill background of building").AddNumber("itemNumber", 1).AddNumber("maxItemNumber", 1) ) )

	PrintDebug ("  TRooms.DrawDoorsOnBackground()", "drawing door-sprites on the building-sprite", DEBUG_START)
	TRooms.DrawDoorsOnBackground()		'draws the door-sprites on the building-sprite

	PrintDebug ("  Building.DrawItemsToBackground()", "drawing plants and lights on the building-sprite", DEBUG_START)
	Building.DrawItemsToBackground()	'draws plants and lights which are behind the figures

	PrintDebug ("Init_All()", "complete", DEBUG_START)
End Function


'ingame update
Function UpdateMain(deltaTime:Float = 1.0)
	TError.UpdateErrors()
	Game.cursorstate = 0
	If Players[Game.playerID].Figure.inRoom <> Null Then Players[Game.playerID].Figure.inRoom.Update()

	'ingamechat
	If KEYMANAGER.IsHit(KEY_ENTER)
		If Not GUIManager.isActive(InGame_Chat.guiInput._id)
			If InGame_Chat.antiSpamTimer < MilliSecs()
				GUIManager.setActive( InGame_Chat.guiInput._id )
			Else
				Print "no spam pls (input stays deactivated)"
			EndIf
		EndIf
	EndIf

	'check for clicks on items BEFORE others check and use it
	GUIManager.Update("InGame")

	If Players[Game.playerID].Figure.inRoom = Null
		If MOUSEMANAGER.IsDown(1)
			If functions.IsIn(MouseX(), MouseY(), 20, 10, 760, 373)
				Players[Game.playerID].Figure.ChangeTarget(MouseX(), MouseY())
			EndIf
			MOUSEMANAGER.resetKey(1)
		EndIf
	EndIf
	'66 = 13th floor height, 2 floors normal = 1*73, 50 = roof
	If Players[Game.playerID].Figure.inRoom = Null Then Building.pos.y =  1 * 66 + 1 * 73 + 50 - Players[Game.playerID].Figure.rect.GetY()  'working for player as center
	Fader.Update(deltaTime)

	Game.Update(deltaTime)
	Interface.Update(deltaTime)
	If Players[Game.playerID].Figure.inRoom = Null Then Building.Update(deltaTime)
	Building.Elevator.Update(deltaTime)
	TFigures.UpdateAll(deltaTime)

	If KEYMANAGER.IsHit(KEY_ESCAPE) Then ExitGame = 1
	If KEYMANAGER.IsHit(KEY_F12) Then App.prepareScreenshot = 1
	If Game.networkgame Then Network.Update()
End Function

'inGame
Function DrawMain(tweenValue:Float=1.0)
	If Players[Game.playerID].Figure.inRoom = Null
		TProfiler.Enter("Draw-Building")
		SetColor Int(190 * Building.timecolor), Int(215 * Building.timecolor), Int(230 * Building.timecolor)
		DrawRect(20, 10, 140, 373)
		If Building.pos.y > 10 Then DrawRect(150, 10, 500, 200)
		DrawRect(650, 10, 130, 373)
		SetColor 255, 255, 255
		Building.Draw()									'player is not in a room so draw building
		TProfiler.Leave("Draw-Building")
	Else
		TProfiler.Enter("Draw-Room")
		Players[Game.playerID].Figure.inRoom.Draw()		'draw the room
		TProfiler.Leave("Draw-Room")
	EndIf

	Fader.Draw()
	TProfiler.Enter("Draw-Interface")
	Interface.Draw()
	TProfiler.Leave("Draw-Interface")

	Assets.fonts.baseFont.draw( "Netstate:" + Players[Game.playerID].networkstate + " Speed:" + Int(Game.speed * 100), 0, 0)

	If Game.DebugInfos
		SetColor 0,0,0
		DrawRect(20,10,140,373)
		SetColor 255, 255, 255
		If App.settings.directx = -1 Then Assets.fonts.baseFont.draw("Mode: OpenGL", 25,50)
		If App.settings.directx = 0  Then Assets.fonts.baseFont.draw("Mode: BufferedOpenGL", 25,50)
		If App.settings.directx = 1  Then Assets.fonts.baseFont.draw("Mode: DirectX 7", 25, 50)
		If App.settings.directx = 2  Then Assets.fonts.baseFont.draw("Mode: DirectX 9", 25,50)

		If Game.networkgame
			GUIManager.Draw("InGame") 'draw ingamechat
			SetAlpha 0.4
			SetColor 0, 0, 0
			DrawRect(660, 483,115,120)
			SetAlpha 1.0
			SetColor 255,255,255
'			Assets.fonts.baseFont.draw(Network.stream.UDPSpeedString(), 662,490)
			For Local i:Int = 0 To 3
				If Players[i + 1].Figure.inRoom <> Null
					Assets.fonts.baseFont.draw("Player " + (i + 1) + ": " + Players[i + 1].Figure.inRoom.Name, 25, 75 + i * 11)
				Else
					If Players[i + 1].Figure.IsInElevator()
						Assets.fonts.baseFont.draw("Player " + (i + 1) + ": InElevator", 25, 75 + i * 11)
					Else If Players[i + 1].Figure.IsAtElevator()
						Assets.fonts.baseFont.draw("Player " + (i + 1) + ": AtElevator", 25, 75 + i * 11)
					Else
						Assets.fonts.baseFont.draw("Player " + (i + 1) + ": Building", 25, 75 + i * 11)
					EndIf
				EndIf
			Next
		EndIf


		Local routepos:Int = 0
		local startY:int = 75
		If Game.networkgame then startY :+ 4*11

		local callType:string = ""

		Assets.fonts.baseFont.draw("tofloor:" + Building.elevator.TargetFloor, 25, startY)

		Assets.fonts.baseFont.draw("Status:" + Building.elevator.ElevatorStatus, 100, startY)
		if Building.elevator.RouteLogic.GetSortedRouteList() <> null
			For Local FloorRoute:TFloorRoute = EachIn Building.elevator.RouteLogic.GetSortedRouteList()
				If floorroute.call = 0 then callType = " 'senden' " else callType= " 'holen' "
				Assets.fonts.baseFont.draw(FloorRoute.floornumber + callType + FloorRoute.who.Name, 25, startY + 15 + routepos * 11)
				routepos:+1
			Next
		else
			Assets.fonts.baseFont.draw("neu berechnen", 25, startY + 15)
		endif


	EndIf
End Function


'events
'__________________________________________
Type TEventOnTime Extends TEventBase
	Field time:Int = 0

	Function Create:TEventOnTime(trigger:String="", time:Int)
		Local evt:TEventOnTime = New TEventOnTime
		'evt._startTime = EventManager.getTicks() 'now
		evt._trigger	= Lower(trigger)
		'special data:
		evt.time		= time
		Return evt
	End Function
End Type

Type TEventListenerPlayer Extends TEventListenerBase
	Field Player:TPlayer

	Function Create:TEventListenerPlayer(player:TPlayer)
		Local obj:TEventListenerPlayer = New TEventListenerPlayer
		obj.player = player
		Return obj
	End Function

	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventOnTime = TEventOnTime(triggerEvent)
		If evt<>Null
			If evt._trigger = "game.onminute" And Self.Player.isAI() Then Self.Player.PlayerKI.CallOnMinute(evt.time)
			If evt._trigger = "game.onday" And Self.Player.isAI() Then Self.Player.PlayerKI.CallOnDayBegins()
		EndIf
		return true
	End Method
End Type

Type TEventListenerOnMinute Extends TEventListenerBase

	Function Create:TEventListenerOnMinute()
		Local obj:TEventListenerOnMinute = New TEventListenerOnMinute
		Return obj
	End Function


	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventOnTime = TEventOnTime(triggerEvent)
		If evt<>Null
			'things happening x:05
			Local minute:Int = evt.time Mod 60
			Local hour:Int = Floor(evt.time / 60)

			'begin of a programme
			If minute = 5
				TPlayer.ComputeAudience()
			'call-in shows/quiz - generate income
			ElseIf minute = 54
				For Local player:TPlayer = EachIn TPlayer.list
					Local block:TProgrammeBlock = player.ProgrammePlan.GetCurrentProgrammeBlock()
					If block<>Null And block.programme.genre = GENRE_CALLINSHOW
						Local revenue:Int = player.audience * Rnd(0.05, 0.2)
						player.finances[Game.getWeekday()].earnCallerRevenue(revenue)
					EndIf
				Next
			'ads
			ElseIf minute = 55
				TPlayer.ComputeAds()
			ElseIf minute = 0
				Game.calculateMaxAudiencePercentage(hour)
				TPlayer.ComputeNewsAudience()
 			EndIf
 			If minute = 5 Or minute = 55 Or minute=0 Then Interface.BottomImgDirty = True
		EndIf
		return true
	End Method
End Type

Type TEventListenerOnDay Extends TEventListenerBase

	Function Create:TEventListenerOnDay()
		Local obj:TEventListenerOnDay = New TEventListenerOnDay
		Return obj
	End Function

	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventOnTime = TEventOnTime(triggerEvent)
		If evt<>Null
			'take over current money
			TPlayer.TakeOverMoney()

			'Neuer Award faellig?
			If Betty.GetAwardEnding() < Game.GetDay() - 1
				Betty.GetLastAwardWinner()
				Betty.SetAwardType(RandRange(0, Betty.MaxAwardTypes), True)
			End If

			For Local i:Int = 0 To TProgramme.ProgList.Count()-1
				Local Programme:TProgramme = TProgramme(TProgramme.ProgList.ValueAtIndex(i))
				If Programme <> Null Then Programme.RefreshTopicality()
			Next
			TPlayer.ComputeContractPenalties()
			TPlayer.ComputeDailyCosts()
			TAuctionProgrammeBlocks.ProgrammeToPlayer() 'won auctions moved to programmecollection of player
			'if new day, not start day
			If evt.time > 0
				TRoomSigns.ResetPositions()
				For Local i:Int = 1 To 4
					For Local NewsBlock:TNewsBlock = EachIn Players[i].ProgrammePlan.NewsBlocks
						If Game.GetDay() - Game.GetDay(Newsblock.news.happenedtime) >= 2
							Players[Newsblock.owner].ProgrammePlan.RemoveNewsBlock(NewsBlock)
						EndIf
					Next
				Next
			EndIf

		EndIf
		return true
	End Method
End Type

Type TEventListenerOnAppUpdate Extends TEventListenerBase

	Function Create:TEventListenerOnAppUpdate()
		Return New TEventListenerOnAppUpdate
	End Function

	'wird ausgeloest wenn OnAppUpdate-Event getriggert wird
	'multi
	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventSimple = TEventSimple(triggerEvent)
		If evt<>Null
			'say soundmanager to do something
			EventManager.triggerEvent( TEventSimple.Create("App.onSoundUpdate",null) ) 'mv 10.11.2012: Bitte den Event noch an die richtige Stelle verschieben. Der Sound braucht wohl nen eigenen Thread, sonst ruckelt es


			If not GUIManager.getActive()
				If KEYMANAGER.IsDown(KEY_UP) Then Game.speed:+0.05
				If KEYMANAGER.IsDown(KEY_DOWN) Then Game.speed = Max( Game.speed - 0.05, 0)

				If KEYMANAGER.IsHit(KEY_1) Game.playerID = 1
				If KEYMANAGER.IsHit(KEY_2) Game.playerID = 2
				If KEYMANAGER.IsHit(KEY_3) Game.playerID = 3
				If KEYMANAGER.IsHit(KEY_4) Game.playerID = 4
				If KEYMANAGER.IsHit(KEY_5) Then game.speed = 60
				If KEYMANAGER.IsHit(KEY_6) Then game.speed = 0.10

				If KEYMANAGER.IsHit(KEY_TAB) Game.DebugInfos = 1 - Game.DebugInfos
				If KEYMANAGER.IsHit(KEY_W) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("adagency", 0)
				If KEYMANAGER.IsHit(KEY_A) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("archive", Game.playerID)
				If KEYMANAGER.IsHit(KEY_B) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("betty", 0)
				If KEYMANAGER.IsHit(KEY_K) TFigures.GetByID(5).KickFigureFromRoom(Players[Game.playerID].Figure, Players[Game.playerID].Figure.inRoom)
				If KEYMANAGER.IsHit(KEY_F) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("movieagency", 0)
				If KEYMANAGER.IsHit(KEY_O) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("office", Game.playerID)
				If KEYMANAGER.IsHit(KEY_C) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("chief", Game.playerID)
				If KEYMANAGER.IsHit(KEY_N) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("news", Game.playerID)
				If KEYMANAGER.IsHit(KEY_R) Players[Game.playerID].Figure.inRoom = TRooms.GetRoomByDetails("roomboard", -1)
				If KEYMANAGER.IsHit(KEY_D) Players[Game.playerID].maxaudience = Stationmap.einwohner

				If KEYMANAGER.IsHit(KEY_ESCAPE) ExitGame = 1				'ESC pressed, exit game
				If KEYMANAGER.Ishit(Key_F1) And Players[1].isAI() Then Players[1].PlayerKI.reloadScript()
				If KEYMANAGER.Ishit(Key_F2) And Players[2].isAI() Then Players[2].PlayerKI.reloadScript()
				If KEYMANAGER.Ishit(Key_F3) And Players[3].isAI() Then Players[3].PlayerKI.reloadScript()
				If KEYMANAGER.Ishit(Key_F4) And Players[4].isAI() Then Players[4].PlayerKI.reloadScript()

				If KEYMANAGER.Ishit(Key_F5) Then NewsAgency.AnnounceNewNews()
				If KEYMANAGER.Ishit(Key_F6) Then Soundmanager.PlayMusic(MUSIC_MUSIC)
				If KEYMANAGER.Ishit(Key_F7)
					local news:int = 1
					local slot:int = -1
					print "set news "+news+" ["+Players[1].ProgrammePlan.GetNewsFromList(news).id+"] to slot "+slot
					Players[1].ProgrammePlan.SetNewsBlockSlot( Players[1].ProgrammePlan.GetNewsFromList(news), slot)
				endif
				If KEYMANAGER.Ishit(Key_F8)
					local news:int = 1
					local slot:int = rand(0,2)
					print "set news "+news+" ["+Players[1].ProgrammePlan.GetNewsFromList(news).id+"] to slot "+slot
					Players[1].ProgrammePlan.SetNewsBlockSlot( Players[1].ProgrammePlan.GetNewsFromList(news), slot)
				endif
				If KEYMANAGER.Ishit(Key_F9)
					if (KIRunning)
						KIRunning = false
					else
						KIRunning = true
					endif
				endif
			EndIf

			KEYMANAGER.changeStatus()
			If Game.gamestate = 0
				UpdateMain(App.Timer.getDeltaTime())
			Else
				UpdateMenu(App.Timer.getDeltaTime())
			EndIf
			If RandRange(0,20) = 20 Then GCCollect()

			MOUSEMANAGER.changeStatus(Game.error)
		EndIf
		return true
	End Method
End Type

Type TEventListenerOnAppDraw Extends TEventListenerBase

	Function Create:TEventListenerOnAppDraw()
		Return New TEventListenerOnAppDraw
	End Function


	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventSimple = TEventSimple(triggerEvent)

		If evt<>Null
			TProfiler.Enter("Draw")
			If Game.gamestate = 0
				DrawMain()
			Else
				DrawMenu()
			EndIf
			Assets.fonts.baseFont.draw("FPS:"+App.Timer.currentFps + " UPS:" + Int(App.Timer.currentUps), 150,0)
			Assets.fonts.baseFont.draw("dTime "+Int(1000*App.Timer.loopTime)+"ms", 275,0)
			If game.networkgame Then Assets.fonts.baseFont.draw("ping "+Int(Network.client.latency)+"ms", 375,0)
			If App.prepareScreenshot = 1 Then Assets.GetSprite("gfx_startscreen_logoSmall").Draw(App.settings.width - 10, 10, 0, 1)

			TProfiler.Enter("Draw-Flip")
				Flip App.limitFrames
			TProfiler.Leave("Draw-Flip")

			If App.prepareScreenshot = 1 Then SaveScreenshot();App.prepareScreenshot = 0
			TProfiler.Leave("Draw")
		EndIf
		return true
	End Method
End Type

Type TEventListenerOnSoundUpdate Extends TEventListenerBase

	Function Create:TEventListenerOnSoundUpdate()
		Return New TEventListenerOnSoundUpdate
	End Function


	Method OnEvent:int(triggerEvent:TEventBase)
		Local evt:TEventSimple = TEventSimple(triggerEvent)
		If evt<>Null
			TProfiler.Enter("SoundUpdate")
			SoundManager.Update()
			TProfiler.Leave("SoundUpdate")
		EndIf
		return true
	End Method
End Type

'__________________________________________
'events
For Local i:Int = 1 To 4
	If Players[i].figure.isAI()
		EventManager.registerListener( "Game.OnMinute",	TEventListenerPlayer.Create(Players[i]) )
		EventManager.registerListener( "Game.OnDay", 	TEventListenerPlayer.Create(Players[i]) )
	EndIf
Next
EventManager.registerListener( "Game.OnDay", 	TEventListenerOnDay.Create() )
EventManager.registerListener( "Game.OnMinute",	TEventListenerOnMinute.Create() )
EventManager.registerListenerFunction( "Game.OnStart",	TGame.onStart )

Global Curves:TNumberCurve = TNumberCurve.Create(1, 200)

Global Init_Complete:Int = 0

'Init EventManager
'could also be done during update ("if not initDone...")
EventManager.Init()
App.StartApp() 'all resources loaded - switch Events for Update/Draw from Loader to MainEvents


If ExitGame <> 1 And Not AppTerminate()'not exit game
	KEYWRAPPER.allowKey(13, KEYWRAP_ALLOW_BOTH, 400, 200)
	Repeat
		App.Timer.loop()
		'process events not directly triggered
		'process "onMinute" etc. -> App.OnUpdate, App.OnDraw ...
		EventManager.update()
	Until AppTerminate() Or ExitGame = 1
	If Game.networkgame Then Network.DisconnectFromServer()
EndIf 'not exit game


OnEnd( EndHook )
Function EndHook()
	TProfiler.DumpLog("log.profiler.txt")
	TLogFile.DumpLog(FALSE)

End Function