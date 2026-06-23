#include "RTS_tools.inc"

''' Add to .gitignore. Use this function for tests, not Main in main.prg
' This will help keep the repo clean!

Function Testing As Int64
	
	Testing = 0
	''' Keep this 
	NotStandalone = True
	SelectSite("")
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
	' Use values in site file as defaults while using server
	' Other wise all will default to False
	SocPlaceNotDrop = DefaultPlaceNotDrop ' Defaults to Drop
	SocClampFirst = DefaultClampFirst ' Defaults to clamp after vacuum off
	SocFastClamp = DefaultFastClamp ' defaults to soft/slow clamping
	DoPinAnalysis = DefaultPinAnalysis ' Defaults to not running pin analysis
	SkipOccupancyChecks = DefaultSkipOcc ' Defaults to running occupancy checks 
 	SkipSocketCorrection = DefaultSkipSocCor ' Defaults to applying socket correction
 	SkipChipToChipCorrection = DefaultSkipChipCor ' Defaults to applying chip to chip correction


	LoadPositionFiles
	LoadCurrentChipOffset
	
	' left tray
	Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows

	' right tray
	Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows
	
	UpdatePositionFiles

	Motor On
	PumpOn
	SetSpeed
	
	
'	''' Make changes here	

	
	DoPinAnalysis = False
	
	Int64 status
	
'
	Int32 iChip


	Integer Occupancy
	
'	For iChip = 1 To 4
'		Occupancy = TrayPositionOccupied(2, 8, 2 + iChip)
'		'Print "Occupancy = ", Occupancy
'		If Occupancy <> 0 Then
'			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
'			If Occupancy = -2 Then
'				Print("Target tray position occupancy check value = " + Str$(Occupancy))
'			Else
'				Print("Target tray position occupied, occupancy check value = " + Str$(Occupancy))
'			EndIf
'			Testing = -10
'			ResetOperation
'			Exit Function
'		EndIf
'	Next
'	
'	For iChip = 1 To 4
'		Occupancy = SocketPositionOccupied(1, iChip)
'		'Print "Occupancy = ", Occupancy
'		If Occupancy <> 1 Then
'			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
'			If Occupancy = -2 Then
'				Print("Target tray position occupancy check value = " + Str$(Occupancy))
'			Else
'				Print("Target tray position occupied, occupancy check value = " + Str$(Occupancy))
'			EndIf
'			Testing = -10
'			ResetOperation
'			Exit Function
'		EndIf
'	Next
'
'	' Chips in sockets 1 to 4 -> (2,8,3) through (2,8,6)
'	For iChip = 1 To 4
'		status = MoveChipFromSocketToTray(1, iChip, 2, 8, 2 + iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	
''	For iChip = 1 To 4
''		Occupancy = SocketPositionOccupied(1, iChip)
''		'Print "Occupancy = ", Occupancy
''		If Occupancy <> 0 Then
''			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
''			If Occupancy = -2 Then
''				Print("Target tray position occupancy check value = " + Str$(Occupancy))
''			Else
''				Print("Target tray position occupied, occupancy check value = " + Str$(Occupancy))
''			EndIf
''			Testing = -10
''			ResetOperation
''			Exit Function
''		EndIf
''	Next
'	For iChip = 1 To 4
'		Occupancy = TrayPositionOccupied(1, 1, 1 + iChip)
'		'Print "Occupancy = ", Occupancy
'		If Occupancy <> 1 Then
'			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
'			If Occupancy = -2 Then
'				Print("Target tray position occupancy check value = " + Str$(Occupancy))
'			Else
'				Print("Target tray position occupied, occupancy check value = " + Str$(Occupancy))
'			EndIf
'			Testing = -10
'			ResetOperation
'			Exit Function
'		EndIf
'	Next
'	' Chips in bad tray back to sockets 1-4 (1, 1, 2) through (1, 1, 5) -> (1,1) through (1,4)
'	For iChip = 1 To 4
'		status = MoveChipFromTrayToSocket(1, 1, 1 + iChip, 1, iChip)
'			If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to socket"
'			Exit Function
'		EndIf
'	Next


	SkipOccupancyChecks = True
	SkipSocketCorrection = False
	SkipChipToChipCorrection = False
	
'	For iChip = 1 To 4
'		' status = MoveChipFromTrayToSocket(1, 1, iChip, 1, iChip)
'		status = MoveChipFromSocketToTray(1, iChip, 2, 6, 2 + iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'
'	' MOving chips to bad tray for now
'	For iChip = 1 To 4
'		' status = MoveChipFromTrayToSocket(1, 2, iChip, 1, 4 + iChip)
'		status = MoveChipFromSocketToTray(1, 4 + iChip, 2, 7, iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'
'	' (1,1,1) - > (2,5,1) - did manually
'	' (1,1,2) - > (2,5,2)
'	' (1,1,3) - > (2,5,3)
'	' (1,1,4) - > (2,5,4)
'	For iChip = 2 To 4
'		status = MoveChipFromTrayToTray(1, 1, iChip, 2, 5, iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	
'	' (1,5) -> (2,5,5)
'	' (1,6) -> (2,5,6)
'	For iChip = 1 To 2
'		status = MoveChipFromSocketToTray(1, iChip + 4, 2, 5, iChip + 4)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	' (1,7) -> (2,6,1)
'	' (1,8) -> (2,6,2)
'	For iChip = 1 To 2
'		status = MoveChipFromSocketToTray(1, iChip + 6, 2, 6, iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	
'	' (1,1,5) -> (2,6,3)
'	' (1,1,6) -> (2,6,4)
'	For iChip = 1 To 2
'		status = MoveChipFromTrayToTray(1, 1, 4 + iChip, 2, 6, 2 + iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	
'	' (1,2,1) -> (2,6,5)
'	' (1,2,2) -> (2,6,6)
'	For iChip = 1 To 2
'		status = MoveChipFromTrayToTray(1, 2, iChip, 2, 6, 4 + iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
	
	' (1,1) -> (2,7,1)
	' (1,2) -> (2,7,2)
	' (1,3) -> (2,7,3)
	' (1,4) -> (2,7,4)	
'	For iChip = 1 To 2
'		status = MoveChipFromSocketToTray(1, 2 + iChip, 2, 7, 2 + iChip)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf
'	Next
'	
'		status = MoveChipFromSocketToTray(1, 8, 2, 15, 5)
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'			Exit Function
'		EndIf


	For iChip = 1 To 6
		status = MoveChipFromSocketToTray(1, iChip, 2, 1, iChip)
		If status < 0 Then
			Print "ERROR moving chip ", iChip, " to tray"
			Exit Function
		EndIf
	Next
	
	For iChip = 1 To 2
		status = MoveChipFromSocketToTray(1, 6 + iChip, 2, 2, iChip)
		If status < 0 Then
			Print "ERROR moving chip ", Str$(iChip + 6), " to tray"
			Exit Function
		EndIf
	Next

	SkipSocketCorrection = False
	SkipChipToChipCorrection = False


	SkipOccupancyChecks = False
	
	Wait 1
	JumpToCamera
	


'	

'	
'	''' keep rest of this
' Do not uncomment pump off if you are not sure if your code will not drop a chip after stopping mid move function!
'	PumpOff
'	Motor Off
'		''
	UpdatePositionFiles
	StoreCurrentChipOffset
	
Fend

Function CheckForChip(DAT_nr As Integer, socket_nr As Integer) As Boolean

	CheckForChip = False
	
	If Not isChipInSocketCamera(DAT_nr, Socket_nr) Then
		Print "Cannot see a chip in the socket"
	Else
		Print "Can see chip in the socket"
	EndIf
	
	If Not isChipInSocketTouch(DAT_nr, Socket_nr) Then
		Print "Chip not found at correct height"
	Else
		Print "Chip at correct height"
	EndIf
	
Fend


Function TestOptionsFromServer(RunSelectSite As Int32)
	
	Print "Will check value of global bools which are declared but not set"
	
	If RunSelectSite = 1 Then
		SelectSite("InFunctionDefinePallets")
	EndIf
	
	If NotStandalone Then
		Print "NotStandalone is True, this is being called within a higher level function like, Main, RTS_Server, or testing"
	Else
		Print "NotStandalone is False, this function is being called on its own or a function which does not set NotStandalone"
	EndIf
	
	If DoPinAnalysis Then
		Print "DoPinAnalysis is True"
	Else
		Print "DoPinAnalysis is False"
	EndIf
	
	If SkipOccupancyChecks Then
		Print "SkipOccupancyChecks is True"
	Else
		Print "SkipOccupancyChecks is False"
	EndIf
	
	If SkipSocketCorrection Then
		Print "SkipSocketCorrection is True"
	Else
		Print "SkipSocketCorrection is False"
	EndIf
	
	If SkipChipToChipCorrection Then
		Print "SkipChipToChipCorrection is True"
	Else
		Print "SkipChipToChipCorrection is False"
	EndIf
	
	If SocPlaceNotDrop Then
		Print "SocPlaceNotDrop is True"
	Else
		Print "SocPlaceNotDrop is False"
	EndIf
	
	If SocClampFirst Then
		Print "SocClampFirst is True"
	Else
		Print "SocClampFirst is False"
	EndIf
	
	If SocFastClamp Then
		Print "SocFastClamp is True"
	Else
		Print "SocFastClamp is False"
	EndIf
	
Fend

Function TestSiteFileLoading
	
	Print "Without loading from site file"
	PrintLoadedSiteFileValues
	
	Print "RUNNING SELECT SITE"
	SelectSite("")

	Print "With loading from site file"

	PrintLoadedSiteFileValues
	
	Boolean initial_pin_analysis
	initial_pin_analysis = DefaultPinAnalysis
	
	Print "Will now change setting of DoPinAnalysis"
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	DefaultPinAnalysis = Not initial_pin_analysis
	Print "changing..."
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	
	Print "Will now write new value to file"
	WriteSiteFile
	Print "Waiting 20 seconds, please check pin analysis setting in file has changed"
	Wait 20
	
	Print "Now changing back "
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	DefaultPinAnalysis = False
	Print "changing..."
	Print "DefaultPinAnalysis = ", initial_pin_analysis
	Print "Rewriting site file"
	WriteSiteFile
		
Fend

