SuperStrict

'Application: TVGigant/TVTower
'Author: Ronny Otto

' creates version.txt and puts date in it
' @bmk include source/version_script.bmk
' @bmk doVersion source/version.txt
'

Framework brl.glmax2d
'Import axe.luascript
Import "source/main.bmx"

Incbin "source/version.txt"
Rem
'done
- TTooltip - header wird nun y-"zentriert" auf Headerbereich dargestellt
- TProgrammePlan.RefreshProgrammePlan - PlayerID von Parameterliste gestrichen
' 2012:
' gamefunctions_tvprogramme - basisklassen zusammenfassen
' gamefunctions - tstation - farben der ovale anpassen auf tplayercolor

EndRem
