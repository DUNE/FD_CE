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
