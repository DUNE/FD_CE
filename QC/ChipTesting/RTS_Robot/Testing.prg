#include "RTS_tools.inc"

''' Add to .gitignore. Use this function for tests, not Main in main.prg
' This will help keep the repo clean!

Function Testing
	
	''' Keep this 
	SelectSite("")
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
	DoPinAnalysis = False
	DoCheckPlace = False
	DoMeasurePlace = False
	
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
'	
'	DF_ChipDirection_LArASIC
'
'	On 12
'	'If Not GetChipFromTray(1, 4, 1) Then
'	If Not GetChipFromSocket(1, 7) Then
'		Print "Get function failed to terminate"
'		Exit Function
'	EndIf
'	
'	Wait 5
'	SetSpeedSetting("MoveWithChip")
'	
'	If Not PlaceChipInTray(1, 4, 1) Then
'		Print "Place function failed to terminate"
'		Exit Function
'	EndIf
'	
'	PumpOff
'	Motor Off
	
	On 12
	'If Not GetChipFromTray(1, 4, 1) Then
	If Not GetChipFromTray(1, 4, 1) Then
		Print "Get function failed to terminate"
		Exit Function
	EndIf
	
	Wait 5
	SetSpeedSetting("MoveWithChip")
	
	If Not PlaceChipInSocket(1, 7) Then
		Print "Place function failed to terminate"
		Exit Function
	EndIf
	
	PumpOff
	Motor Off
	
	
	
	
'	If Not GetChipFromSocket(1, 8) Then
'			Print "ERROR: CHIP RETRIEVAL AT SOCKET FAILED"
'		Exit Function
'	EndIf
'	Wait 10
'	
'	If Not PlaceChipInSocket(1, 8) Then
'		Print "ERROR: CHIP PLACEMENT AT SOCKET FAILED"
'		Exit Function
'	EndIf
'	
'	PumpOff
'	Motor Off
	
'	Integer Attempts
'	Boolean Success
'	Attempts = 10
'	Success = False
'	Do While ((Attempts > 0 And Not Success))
'		Print "Attempts remaining ", Attempts
'		If FindChipDirectionWithDF Then
'			Success = True
'		EndIf
'		Attempts = Attempts - 1
'	Loop
'	If Not Success Then
'		Print "Could not find chip"
'		Exit Function
'	EndIf
'	
'	Print "Chip found at (X , Y , U):"
'	Print "(", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
'
'	Attempts = 10
'	Success = False
'	Do While ((Attempts > 0 And Not Success))
'		Print "Attempts remaining ", Attempts
'		
'		If FindSocketDirectionWithDF Then
'			Success = True
'		EndIf
'		Attempts = Attempts - 1
'	Loop
'	If Not Success Then
'		Print "Could not find socket"
'		Exit Function
'	EndIf
'	
'	Print "Socket found at (X , Y , U):"
'	Print "(", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
'	Print " GETTING CHIP AND SOCKET ALIGNMENT"
'	
'	String testname$
'	testname$ = "TESTSTRING"
'	Integer idx(20)
'	Integer i
'	For i = 1 To 20
'		idx(i) = 0
'	Next
'	Integer fileNum
'	fileNum = FreeFile
'	idx(1) = fileNum
'	idx(10) = 1
'	idx(11) = 8
'	
'	Double CinSResults(15)
'	For i = 1 To 15
'		CinSResults(i) = 0.
'	Next
'	
'	Attempts = 10
'	Success = False
'	Do While ((Attempts > 0 And Not Success))
'		Print "Attempts remaining ", Attempts
'		
'		If GetChipInSocketAlignment(testname$, ByRef idx(), 1, 8, ByRef CinSResults()) Then
'			Success = True
'		EndIf
'		Attempts = Attempts - 1
'	Loop
'	If Not Success Then
'		Print "Could not find chip or socket for alignment"
'		Exit Function
'	EndIf
'	Print Here
'	For i = 1 To 15
'		Print "Results (", i, ") = ", Str$(CinSResults(i))
'	Next
	


'	If Not FindSocketDirectionWithDF Then
'		Print "Could not find socket"
'	EndIf
'	
'	Print Here
'	Print SockPos(1), SockPos(2), SockPos(3)


'	MoveChipFromSocketToTray(1, 8, 1, 1, 1)
'	MoveChipFromTrayToSocket(1, 8, 1, 1, 1)

		' Removing my test chips
'		If Not MoveChipFromSocketToTray(1, 1, 1, 1, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 2, 1, 2, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 3, 1, 3, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 4, 1, 4, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 5, 1, 5, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 6, 1, 5, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 7, 1, 6, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf
'		Wait 5
'		If Not MoveChipFromSocketToTray(1, 8, 1, 7, 6) Then
'			Print "ERROR"
'			Exit Function
'		EndIf


		'MoveChipFromSocketToTray(1, 1, 1, 1, 6)
		'Wait 5
'		MoveChipFromSocketToTray(1, 2, 1, 2, 6)
'		Wait 5
'		MoveChipFromSocketToTray(1, 3, 1, 3, 6)
'		Wait 5
'		MoveChipFromSocketToTray(1, 4, 1, 4, 6)
'		Wait 5
' 		MoveChipFromSocketToTray(1, 5, 1, 5, 6)
'		Wait 5
'		MoveChipFromSocketToTray(1, 6, 1, 5, 6)
'		Wait 5
'		MoveChipFromSocketToTray(1, 7, 1, 6, 6)
'		Wait 5
'		MoveChipFromSocketToTray(1, 8, 1, 7, 6)
		
'		' 0 deg
'		MoveChipFromTrayToSocket(1, 1, 1, 1, 6)
'		Wait 5
		
'		' +90 deg
'		MoveChipFromTrayToSocket(1, 2, 1, 2, 6)
'		Wait 5
'		' 180 deg
'		MoveChipFromTrayToSocket(1, 3, 1, 3, 6)
'		Wait 5
'		' -90 deg
'		MoveChipFromTrayToSocket(1, 4, 1, 4, 6)
'		Wait 5
'		' 0 deg
' 		MoveChipFromTrayToSocket(1, 5, 1, 5, 6)
'		Wait 5
		' +90 deg
		'MoveChipFromTrayToSocket(1, 6, 1, 5, 6)
		'Wait 5
		' 180 deg
'		MoveChipFromTrayToSocket(1, 7, 1, 7, 6)
'		Wait 5
'		' -90 deg
'		MoveChipFromTrayToSocket(1, 8, 1, 8, 6)


'		MoveChipFromTrayToTray(1, 7, 6, 1, 8, 6)
'		MoveChipFromTrayToTray(1, 6, 6, 1, 7, 6)
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
	
	If Not isChipInSocketCamera(DAT_nr, socket_nr) Then
		Print "Cannot see a chip in the socket"
	Else
		Print "Can see chip in the socket"
	EndIf
	
	If Not isChipInSocketTouch(DAT_nr, socket_nr) Then
		Print "Chip not found at correct height"
	Else
		Print "Chip at correct height"
	EndIf
	
Fend

