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
	
	LoadPositionFiles
	
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


	MoveChipFromSocketToTray(1, 8, 1, 1, 1)
	MoveChipFromTrayToSocket(1, 8, 1, 1, 1)


'	
	''' keep rest of this
	PumpOff
	Motor Off
'		
	UpdatePositionFiles
	
Fend

