#include "RTS_tools.inc"

''' Add to .gitignore. Use this function for tests, not Main in main.prg
' This will help keep the repo clean!

Function Testing
	
	''' Keep this 
	SelectSite
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
	''' Make changes here	
	
	
	''' keep rest of this
	PumpOff
	Motor Off
		
	UpdatePositionFiles
	
Fend

