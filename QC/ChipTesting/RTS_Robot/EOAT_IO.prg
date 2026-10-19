#include "RTS_tools.inc"
#include "ErrorDictionary.inc"
Function PumpOn
    VacuumValveOpen
    Wait 1
    VacuumValveClose
	On 9
Fend

Function PumpOff
	Off 9
Fend

Function VacuumValveOpen
	On 10
Fend

Function VacuumValveClose
	Off 10
Fend

Function PlungerOn
	On 11
Fend

Function PlungerOff
	Off 11
Fend

Function isVacuumOk As Boolean
	If Sw(10) = 0 Then
		isVacuumOk = True
	Else
		Print "Bad vacuum"
		isVacuumOk = False
	EndIf
Fend

Function isPressureOk As Boolean
	If Sw(11) Then
		isPressureOk = True
	Else
		Print "Bad pressure"
		isPressureOk = False
	EndIf
Fend

Function isContactSensorTouches As Boolean
	If Sw(8) = 1 Then
		isContactSensorTouches = True
	Else
		isContactSensorTouches = False
	EndIf
	
	' Lost power case: assume that the tools is touching:
	If Sw(8) = Sw(9) Then
		isContactSensorTouches = True
	EndIf
Fend

Function UF_camera_light_ON
	On 12
Fend

Function UF_camera_light_OFF
	Off 12
Fend

' Technichally this isn't th ehand so could be moved to RTS_tools
' but it is IO for the cover sink
Function CoverStatus(DAT_nr As Integer) As Int64
	CoverStatus = 0
	'JW:  Values here had to be determined from BNL automation
	' Could be other values for specific states which are unknown to me 
	' e.g. one specific sink open other closed
	If DAT_nr = 0 Then
		' Check both sinks open for robot operation
		If Sw(14) And Sw(13) Then
			' Both sinks are open
			CoverStatus = 197
		Else
			' At least one sink is closed
			CoverStatus = -198
		EndIf
	ElseIf DAT_nr = 1 Then
		If Sw(14) Then
			' Sink 1 (left from robot right from front -ve X) OPEN
			CoverStatus = 197
		Else
			' Sink 1 CLOSED
			CoverStatus = -198
		EndIf
	ElseIf DAT_nr = 2 Then
		If Sw(13) Then
			' Sink 2 (right from robot left from front +ve X) OPEN
			CoverStatus = 197
		Else
			' Sink 2 CLOSED
			CoverStatus = -198
		EndIf
	EndIf

Fend

