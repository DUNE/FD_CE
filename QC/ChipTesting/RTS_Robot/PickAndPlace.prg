#include "RTS_tools.inc"
#include "ErrorDictionary.inc"


Function TouchChip As Byte
	' Will put the stinger in contact with a chip		
	' This does several safety checks	
	' Returns code:
	' 0  - Success
	' -1 - No contact after travelling 2mm below expected position 
	' -2 - No contact but still stopped within +/- 2mm for some reason
	' +1 - Made contact 2mm above expected chip position	
	If Sw(8) = Sw(9) Then
		Print "ERROR - Check contact sensor is powered"
		Exit Function
	EndIf
	
	SetSpeedSetting("PickAndPlace")
	Double Zexpect, Znow, Zdiff
	Zexpect = CZ(Here) - CONTACT_DIST
    Go Here -Z(CONTACT_DIST + 2.) Till Sw(8) = On Or Sw(9) = Off
    Wait 0.5
    Znow = CZ(Here)
    Zdiff = Znow - Zexpect
    If Zdiff > 1. Then
    	Print "***ERROR: Contact too early: Zdiff = ", Zdiff, " - Check for obstruction"
    	TouchChip = 1
    ElseIf Zdiff < -1. Then
    	Print "No contact made: Zdiff = ", Zdiff
    	TouchChip = -1
    ElseIf (Not isContactSensorTouches) Then
    	Print "***ERROR: Contact not made but stopped in +/- 2mm of expected"
    	TouchChip = -2
    Else
    	TouchChip = 0
	EndIf
	SetSpeedSetting("")
Fend

Function isChipInTrayCamera(pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Boolean

	isChipInTrayCamera = False
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	Do While (Attempts > 0) Or Success
		If FindChipDirectionWithDF Then
			isChipInTrayCamera = True
			Exit Function
		EndIf
		Attempts = Attempts - 1
	Loop
	
Fend

Function isChipInTrayTouch(pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Boolean
	JumpToTray(pallet_nr, col_nr, row_nr)
	SetSpeedSetting("PickAndPlace")
'    Go Here -Z(12) Till Sw(8) = On Or Sw(9) = Off
'    Wait 0.5
'	Boolean TouchStatus
'	TouchStatus = TouchChip
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	isChipInTrayTouch = TouchSuccess
	SetSpeedSetting("")
Fend

Function PickupFromTray As Boolean
	
	PickupFromTray = False
    SetSpeedSetting("PickAndPlace")
	' Test if the pickup tool is touches - it should not
	If isContactSensorTouches Then
		Print "ERROR! Contact Sensor is ON"
		Exit Function
	EndIf
	If Not isVacuumOk Then
		Exit Function
	EndIf

	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	If Not TouchSuccess Then
		Print "ERROR! Cannot pick up from tray"
		Exit Function
	EndIf
	
	VacuumValveOpen
	Go Here +Z(CONTACT_DIST)
    SetSpeedSetting("MoveWithChip")
    PickupFromTray = True
Fend

Function PlaceInTray As Boolean
	
	PlaceInTray = False
    SetSpeedSetting("PickAndPlace")
	' Check if there is a chip or obstruction in the tray
    Go Here -Z(CONTACT_DIST - 1.) Till Sw(8) = On Or Sw(9) = Off

	If isContactSensorTouches Then
		Print "ERROR! Contact Sensor detects obstacle in the tray"
		Exit Function
	EndIf
	
	' Go down till contact
    Go Here -Z(1)
    Wait 0.5
    ' Check contact is made
	If Not isContactSensorTouches Then
		Print "ERROR! Contact Sensor does not detect contact with the chip"
		Exit Function
	EndIf
	VacuumValveClose
    Wait 2
    Go Here +Z(CONTACT_DIST)
    SetSpeedSetting("MoveWithoutChip")
    PlaceInTray = True
Fend

Function DropToTray As Boolean
	' Assumes that the starting position is 10mm above the chip tray,
	' Moves down 5mm and then drops the chip into the tray. Returns
	' false if the contact sensor touches something, otherwise true.
	
	DropToTray = False
    SetSpeedSetting("PickAndPlace")
	' Do not check for contact but do say if contact is made when trying to drop the tray
	' Starting from the defined point (contact distance above contact) move to drop distance
    Go Here -Z(CONTACT_DIST - DROP_DIST) Till Sw(8) = On Or Sw(9) = Off
	If isContactSensorTouches Then
		Print "ERROR! Contact Sensor detects obstacle in the tray"
		Exit Function
	EndIf
	
    Wait 1
	VacuumValveClose
    Wait 1
    ' Return to defined point
    Go Here +Z(CONTACT_DIST - DROP_DIST)
    SetSpeedSetting("MoveWithoutChip")
    DropToTray = True
Fend




Function isChipInSocketCamera(DAT_nr As Integer, socket_nr As Integer) As Boolean
	
	isChipInSocketCamera = False
	JumpToSocket_camera(DAT_nr, socket_nr)
	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	Do While (Attempts > 0) Or Success
		If FindChipDirectionWithDF Then
			isChipInSocketCamera = True
			Exit Function
		EndIf
		Attempts = Attempts - 1
	Loop
	
Fend

Function isChipInSocketTouch(DAT_nr As Integer, socket_nr As Integer) As Boolean
	
	If Dist(Here, P(DAT_nr * 100 + socket_nr)) > 1.0 Then
		JumpToSocket(DAT_nr, socket_nr)
	EndIf
    SetSpeedSetting("PickAndPlace")
	'Move Here -Z(10) ' To correct for offset TC added to JumpToSocket
'	Speed 1
'	Accel 1, 1
'    Go Here -Z(12) Till Sw(8) = On Or Sw(9) = Off
'    Wait 0.5
'	isChipInSocket = isContactSensorTouches
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	isChipInSocketTouch = TouchSuccess
	SetSpeedSetting("")
Fend


Function InsertIntoSocket As Boolean

	InsertIntoSocket = False

	If Not isPressureOk Then
		Exit Function
	EndIf

    SetSpeedSetting("PickAndPlace")
	PlungerOn
'	Go Here -Z(12) Till Sw(8) = On Or Sw(9) = Off	
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	If Not TouchSuccess Then
		Print "ERROR! Cannot insert in socket"
		Exit Function
	EndIf
	
	VacuumValveClose
	Wait 2
	InsertIntoSocket = isContactSensorTouches
	Go Here +Z(CONTACT_DIST)
	PlungerOff
	SetSpeedSetting("MoveWithoutChip")
	
Fend

Function InsertIntoSocketSoft As Boolean

	InsertIntoSocketSoft = False

	If Not isPressureOk Then
		Exit Function
	EndIf

    SetSpeedSetting("PickAndPlace")
	PlungerOn
	Go Here -Z(CONTACT_DIST - DROP_DIST)

	VacuumValveClose
	Wait 1
	Go Here +Z(CONTACT_DIST - DROP_DIST)
	PlungerOff
	Wait 2
	
	' Check chip is in socket
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	If Not TouchSuccess Then
		Print "ERROR! Chip not at expected depth"
		InsertIntoSocketSoft = False
		Move Here :Z(JUMP_LIMIT - 5) ' Give you some room to see in the socket
		Exit Function
	EndIf
	Move Here +Z(CONTACT_DIST)
	SetSpeedSetting("MoveWithoutChip")
	InsertIntoSocketSoft = True
Fend

Function DropToSocket As Boolean
	' Assumes you are +10 above the socket defined position and the plunger
	' can fully open the socket by moving down at most 14mm. This function
	' checks the pressure, opens the plunger, opens the socket, drops the
	' chip, then moves back up 10mm.
	
	DropToSocket = False
	
	' Check the pressure is ok
	If Not isPressureOk Then
		Exit Function
	EndIf
	
	' Turn the pluger on to open the socket
	Wait 1
	PlungerOn
    Wait 1
	
	Go Here -Z(14) Till Sw(8) = On Or Sw(9) = Off
	
	' Close the valve to drop the chip
	Wait 1
	VacuumValveClose
	Wait 1
	
    ' Go back up 
    Go Here +Z(10)
    
	' Turn the pluger off
	Wait 1
	PlungerOff
    Wait 1
	
Fend



Function PickupFromSocket As Boolean
	' This function assumes the stinger is 10mm above the socket position. It
	' checks the vacuum and pressure, opens the plunger, moves down until 
	' contact is made with the chip, turns the vacuum on, and goes up with
	' the chip. 

	PickupFromSocket = False

	If Not isVacuumOk Then
		Exit Function
	EndIf

	If Not isPressureOk Then
		Exit Function
	EndIf
	
	PlungerOn
	Wait 1
	'Go Here -Z(14)


    SetSpeedSetting("PickAndPlace")

	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	If Not TouchSuccess Then
		Print "ERROR! Cannot pick up from socket"
		Exit Function
	EndIf

	Wait 1
	VacuumValveOpen

    Wait 1
    Go Here +Z(CONTACT_DIST)

    PlungerOff
    SetSpeedSetting("MoveWithChip")

	PickupFromSocket = True
    
Fend







''' Gets chip from a tray when hand currently has no chip
'' Args:
' ts$ - Timestamp string for file names and logging
' ByRef idx(Length 20) - Standard input indices
' ByRef Tray_Results(Length 10) - Initialized empty array for tray vision sequence results of length 10
' ByRef DeltaDir - Desired difference in direction/orientation of chip and hand at target position
' ByRef SourceTrayImage$ - String to save name of image in to be later passed to log function
Function GetChipFromTray(ts$ As String, ByRef idx() As Integer, ByRef Tray_Results() As Double, ByRef DeltaDir As Double, ByRef SourceTrayImage$ As String) As Int32
	UpdateRobotLog$("Getting chip from tray " + Str$(idx(2)) + " position (" + Str$(idx(3)) + "," + Str$(idx(4)) + ")")
	GetChipFromTray = 0
'	Print "Getting chip from tray (", idx(2), ",", idx(3), ",", idx(4), ")"
	SetSpeedSetting("MoveWithoutChip")

		JumpToTray_camera(idx(2), idx(3), idx(4))
		SourceTrayImage$ = DF_take_picture$(ts$ + "_source_tray")
		UpdateRobotLog$("Picture of chip in tray taken: " + SourceTrayImage$)
		SetSpeedSetting("PickAndPlace")

		If Not DFGetTrayAlignment(ts$, ByRef idx(), idx(2), idx(3), idx(4), ByRef Tray_Results()) Then
			RTS_suberror(idx(1), "Cannot get source chip alignment", -ERR_V_DF_ALIGN)
			GetChipFromTray = -ERR_V_DF_ALIGN ' - ERR_TRAY_PICK
			Exit Function
		EndIf
				
		' Correct for offset between chip and tray position
		JumpToTray(idx(2), idx(3), idx(4))
		' correct for offsets
		Go Here +X(Tray_Results(7)) +Y(Tray_Results(8)) '? +U(Tray_Results(9))
			
		' Pick up chip - Angle should be determined by measured position of chip and target orientation in tray
		'Double DeltaDir
		' TODOJOE should this be bound 180? Be careful with the values set
		'DeltaDir = SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)
		DeltaDir = HandChipOrientation(CHIPTYPE_NR)
		Double PickU
		PickU = Tray_Results(6) - DeltaDir '(SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)) ' DeltaDir
		Go Here :U(PickU + PickOffset)
		
'		Print "Calculating pick up angle"
'		Print "Chip direction at tray (wrt world): ", Tray_Results(6)
' '       Print "Chip direction at socket (wrt world): ", (CU(P(PSocket(DAT_nr, socket_nr))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))
' '       Print "Chip direction at socket (wrt world): ", (CU(P(PSocket(DAT_nr, socket_nr))) + HandChipOrientation(CHIPTYPE_NR))
''		Print "Robot hand U at socket : ", CU(P(PSocket(DAT_nr, socket_nr)))
'		Print "Delta from robot hand U to target chip direction in socket : ", DeltaDir
'		Print "Robot hand U at tray to get chip at right delta : ", PickU
'		
		If Not isPressureOk Then
			RTS_suberror(idx(1), "Bad pressure", -ERR_PRESSURE)
			GetChipFromTray = -ERR_PRESSURE
			Exit Function
		EndIf
			
		If Not isVacuumOk Then
			RTS_suberror(idx(1), "Bad vacuum", -ERR_VACUUM)
			GetChipFromTray = -ERR_VACUUM
			Exit Function
		EndIf
		
		If Not PickupFromTray Then
			RTS_suberror(idx(1), "Cannot pick up chip from tray", -ERR_TRAY_PICK)
			GetChipFromTray = -ERR_TRAY_PICK
			Exit Function
		EndIf
		UpdateRobotLog$("Picked up chip from tray")
		SetSpeedSetting("MoveWithChip")

		JumpToCamera
		UpdateRobotLog$("Jumped to camera")
' Use UFC to get chip position relative to axis of rotation, will be used below to calculate offsets
'		' to return to stored DAT_X, DAT_Y, DAT_U values ''SocketChipOrientation(CHIPTYPE_NR), 
'		If Not UFGetChipAlignment(ts$, ByRef idx(), ByRef Camera_Results()) Then
'			RTS_error(idx(1), "Cannot get chip position and aligment with up facing camera")
'			GetChipFromTray = -ERR_V_UF_ALIGN
'			Exit Function
'		EndIf
		Print "Chip picked up from tray with DeltaDir = ", DeltaDir
		GetChipFromTray = -1 ' -1 is True

Fend

''' Places chip in tray when chip is being held by hand
'' Args:
' ts$ - Timestamp string for file names and logging
' ByRef idx(Length 20) - Standard input indices
' ByRef Tray_Results(Length 10) - Initialized empty array for tray vision sequence results of length 10
' ByRef DeltaDir - Known difference in direction/orientation of chip and hand at source position
' ByRef SourceTrayImage$ - String to save name of image in to be later passed to log function
Function PlaceChipInTray(ts$ As String, ByRef idx() As Integer, ByRef Tray_Results() As Double, ByRef DeltaDir As Double, ByRef TargetTrayImage$ As String) As Int32
	UpdateRobotLog$("Placing chip in tray " + Str$(idx(5)) + " position (" + Str$(idx(6)) + "," + Str$(idx(7)) + ")")
	
	PlaceChipInTray = 0
		
		SetSpeedSetting("MoveWithChip")

		Print "Placing chip in tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		JumpToTray(idx(5), idx(6), idx(7))
		UpdateRobotLog$("Jumped to tray")

		Go Here :U(TrayOrientation - DeltaDir) ' DeltaDir here should have been measured at socket or defined at previous chip (by defined hand-chip offset at socket, see SiteSelection:DefineDirections)
		
		Go Here +U(PickOffset) ' This is the add 45. deg option which is globally set 
		
		' Place chip
		SetSpeedSetting("PickAndPlace")

		If Not DropToTray Then
			RTS_suberror(idx(1), "Failed to drop to tray", -ERR_TRAY_PLACE)
			PlaceChipInTray = -ERR_TRAY_PLACE
			Exit Function
		EndIf
		UpdateRobotLog$("Chip placed in tray, checking alignment")

		JumpToTray_camera(idx(5), idx(6), idx(7))
		TargetTrayImage$ = DF_take_picture$(ts$ + "_target_tray")
		UpdateRobotLog$("Picture of chip in tray taken: " + TargetTrayImage$)

		If Not DFGetTrayAlignment(ts$, ByRef idx(), idx(5), idx(6), idx(7), ByRef Tray_Results()) Then
			RTS_suberror(idx(1), "Cannot get source chip alignment", -ERR_V_DF_ALIGN)
			PlaceChipInTray = -ERR_V_DF_ALIGN
			Exit Function
		EndIf
		UpdateRobotLog$("Chip alignment okay")

		SetSpeedSetting("MoveWithoutChip")
		PlaceChipInTray = -1
Fend

''' Gets chip from a socket when hand currently has no chip
'' Args:
' ts$ - Timestamp string for file names and logging
' ByRef idx(Length 20) - Standard input indices
' ByRef SocketResults(Length 16) - Initialized empty array for socket vision sequence results
' ByRef CameraResults(Length 13) - Initialized empty array for UF camera vision sequence results
' ByRef DeltaDir - Double to store difference in direction between chip and hand at socket
' ByRef SourceSocketImage$ - String to save name of image in to be later passed to log function
' ByRef UFCImages$(Length 5) - Array of strings to save names of images taken by UF camera in alignment function for logging (length 5)
Function GetChipFromSocket(ts$ As String, ByRef idx() As Integer, ByRef SocketResults() As Double, ByRef CameraResults() As Double, ByRef DeltaDir As Double, ByRef SourceSocketImage$ As String, ByRef UFCImages$() As String) As Int32
		UpdateRobotLog$("Getting chip from DAT " + Str$(idx(8)) + " socket " + Str$(idx(9)))
	
		GetChipFromSocket = 0
	
		SetSpeedSetting("MoveWithoutChip")
		

		Print "Getting chip from socket (", idx(8), ",", idx(9), ")"
		' Go to socket
		JumpToSocket_camera(idx(8), idx(9))
		UpdateRobotLog$("Jumped to socket")
		SourceSocketImage$ = DF_take_picture$(ts$ + "_source_socket")
		UpdateRobotLog$("Picture of chip in socket taken: " + SourceSocketImage$)

		SetSpeedSetting("PickAndPlace")
		
		' Run visual check of socket and chip positions
		If Not GetChipInSocketAlignment(ts$, ByRef idx(), idx(8), idx(9), ByRef SocketResults()) Then
			RTS_suberror(idx(1), "Cannot get socket and chip alignment", -ERR_V_CHIPSOCKALIGN)
			GetChipFromSocket = -ERR_V_CHIPSOCKALIGN
			Exit Function
		EndIf
		
		' Correct for visual offsets of socket from position	
		' ChipSocketAlignment(i), i=7,8,9 are offsets of measured socket position from defined socket
		' Could alternatively use measured chip position from defined socket i=10,11,12
		' Or measured chip from measured socket, i=13,14,15
		' But these options wouldn't help us then realign as well with UF camera later
		JumpToSocket(idx(8), idx(9))
		Print Here
		Print " moving to here + (", SocketResults(7), ",", SocketResults(8), ",", SocketResults(9), ")"
		Go Here +X(SocketResults(7)) +Y(SocketResults(8)) +U(SocketResults(9))
		' Remember offset between hand and chip	

		' Double DeltaDir
		DeltaDir = SocketResults(12) - CU(Here) ' Measures chip position wrt hand after hand is corrected for socket.
		Go Here +U(PickOffset) ' i.e. should  you pick up at +45 degrees - probably needs more testing
		
		If Not isPressureOk Then
			RTS_suberror(idx(1), "Bad pressure", -ERR_PRESSURE)
			GetChipFromSocket = -ERR_PRESSURE
			Exit Function
		EndIf
			
		If Not isVacuumOk Then
			RTS_suberror(idx(1), "Bad vacuum", -ERR_VACUUM)
			GetChipFromSocket = -ERR_VACUUM
			Exit Function
		EndIf
		
		If Not PickupFromSocket Then
			RTS_suberror(idx(1), "Cannot pick up chip from socket", -ERR_SOCK_PICK)
			GetChipFromSocket = -ERR_SOCK_PICK
			Exit Function
		EndIf
		UpdateRobotLog$("Picked up chip from socket")
		SetSpeedSetting("MoveWithChip")

		' Go to UF camera
		JumpToCamera
		UpdateRobotLog$("Jumped to camera, beginning analysis")
		' Measure offset of chip from axis of J4 at HAND_u0 
		' Store in DAT offset arrays
		SetSpeedSetting("AboveCamera")

		If Not UFGetChipAlignment(ts$, ByRef idx(), ByRef CameraResults(), ByRef UFCImages$()) Then
			If CameraResults(13) <> 0 Then
				GetChipFromSocket = -ERR_PINS
				RTS_suberror(idx(1), "Pin analysis failed", -ERR_PINS)
				Exit Function
			EndIf
			GetChipFromSocket = -ERR_V_UF_ALIGN
			RTS_suberror(idx(1), "Cannot get chip position and aligment with up facing camera", -ERR_V_UF_ALIGN)
			Exit Function
		EndIf
		
		' Offsets are calculated wrt HAND_U0, and so need to be corrected back to measured socket + U correction
		' Can do this later when combined with second measurement
		DAT_X(idx(8), idx(9)) = CameraResults(10)
		DAT_Y(idx(8), idx(9)) = CameraResults(11)
		DAT_U(idx(8), idx(9)) = CameraResults(12)
		UpdateRobotLog$("Ran chip analysis")

		UpdateRobotLog$("Chip-from-socket offsets measured and stored")
	
'		Print "Chip picked up from socket with DeltaDir = ", DeltaDir
'		GetChipFromSocket = 0
		SetSpeedSetting("MoveWithChip")
		GetChipFromSocket = -1
Fend

''' Places chip in socket when already in hand
'' Args:
' ts$ - Timestamp string for file names and logging
' ByRef idx(Length 20) - Standard input indices
' ByRef EmptySocketResults(Length 10) - Initialized empty array for empty socket vision sequence results - note different array length to when chip is in socket
' ByRef CameraResults(Length 13) - Initialized empty array for UF camera vision sequence results
' ByRef ChipSocketResults(Length 16) - Initialized empty array for empty socket vision sequence results with chip in - stores extra information about chip socket alignment
' ByRef TargetSocketImage$ - String to save name of image in to be later passed to log function
' ByRef UFCImages$(Length 5) - Array of strings to save names of images taken by UF camera in alignment function for logging
Function PlaceChipInSocket(ts$ As String, ByRef idx() As Integer, ByRef EmptySocketResults() As Double, ByRef CameraResults() As Double, ByRef ChipSocketResults() As Double, ByRef TargetSocketImage$ As String, ByRef UFCImages$() As String) As Int32
		UpdateRobotLog$("Placing chip in DAT " + Str$(idx(10)) + " socket " + Str$(idx(11)))
		PlaceChipInSocket = 0
		
		Print "Placing chip in socket (", idx(10), ",", idx(11), ")"
		SetSpeedSetting("MoveWithChip")

		' Go to UF camera if not already there
		JumpToCamera
		UpdateRobotLog$("Jumped to camera")
		SetSpeedSetting("AboveCamera")

		If Not UFGetChipAlignment(ts$, ByRef idx(), ByRef CameraResults(), ByRef UFCImages$()) Then
			If CameraResults(13) <> 0 Then
				PlaceChipInSocket = -ERR_PINS
				RTS_suberror(idx(1), "Pin analysis failed", -ERR_PINS)
				Exit Function
			EndIf
			PlaceChipInSocket = -ERR_V_UF_ALIGN
			RTS_suberror(idx(1), "Cannot get chip position and alignment with up facing camera", -ERR_V_UF_ALIGN)
			Exit Function
		EndIf
		SetSpeedSetting("MoveWithChip")
		UpdateRobotLog$("Chip-to-socket offsets measured")


		' Go to socket
		JumpToSocket_camera(idx(10), idx(11))
		UpdateRobotLog$("Jumped to socket")

		SetSpeedSetting("PickAndPlace")

		If Not DFGetSocketAlignment(ts$, ByRef idx(), idx(10), idx(11), ByRef EmptySocketResults()) Then
			RTS_suberror(idx(1), "Cannot get socket alignment", -ERR_V_SOCKETALIGN)
			PlaceChipInSocket = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		UpdateRobotLog$("Socket alignment measured")

		JumpToSocket(idx(10), idx(11)) ' Is this needed, DFGetSocketAlignment moves to measured position at end
		' YES! Because in DFGetSocketAlignment it is at the wrong Z height, could combine but there are two different things going on	
		' DFGSA is just getting X/Y position for U-Agl4 offset. Here we are actually moving to the point to place
		
		' This line is essentially the same as end of DFGetSocketAlignment but after moving to socket point at correct height!
		Go Here :X(EmptySocketResults(4)) :Y(EmptySocketResults(5)) :U(GetBoundAnglePM180(EmptySocketResults(6) - HandChipOrientation(CHIPTYPE_NR)))
		
		Go Here +U(PickOffset)
'		Print "Socket position and orientation AT:"
'		Print "Here: "
'		Print Here
'		Print "Expected : "
'		Print EmptySocketResults(1), ",", EmptySocketResults(2), ",", EmptySocketResults(3)
'		Print "Measured : "
'		Print EmptySocketResults(4), ",", EmptySocketResults(5), ",", EmptySocketResults(6)
'		Print "Offset : "
'		Print EmptySocketResults(7), ",", EmptySocketResults(8), ",", EmptySocketResults(9)
		
		
		Double Corrs(3)

		Corrs(1) = 0
		corrs(2) = 0
		corrs(3) = 0
		
		' Use socket position found earlier to correct, should not have changed since then
'		If S2T_S_Results(6) <> 0 Then
'			Go Here +X(S2T_S_Results(7)) +Y(S2T_S_Results(8)) +U(S2T_S_Results(9))
'		Else
		Go Here +X(EmptySocketResults(7)) +Y(EmptySocketResults(8)) +U(EmptySocketResults(9))
'		EndIf

		' Move chip so position matches offsets from J4 axis stored in DAT
		' Stored values relative to U=0, following function calculates offsets at measured socket position
		' Assumes chip direction to hand direction at socket is fixed
		
		Boolean TestFirstPlaceInSocket
		TestFirstPlaceInSocket = False
		If TestFirstPlaceInSocket Then
			DAT_X(idx(10), idx(11)) = 0
			DAT_Y(idx(10), idx(11)) = 0
			DAT_U(idx(10), idx(11)) = 0
		EndIf
		
'		Print "Calculating socket correction: "
		If (Abs(DAT_X(idx(10), idx(11))) + Abs(DAT_Y(idx(10), idx(11))) + Abs(DAT_U(idx(10), idx(11)))) = 0 Then
			' DAT offsets from previous entry not stored
			Print "WARNING: No DAT Socket offsets stored, will attempt placing from DF camera and UF camera measurements"
			' Careful that offset of chip from UFGetChipAlignment is absolute wrt hand, not from target position	
			' So correction should be 
			'Corrs(3) = -DiffAnglePM180((SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)), CameraResults(12))
			corrs(3) = -DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), CameraResults(12))
			corrs(1) = -(CameraResults(10) * Cos(CU(Here)) - CameraResults(11) * Sin(CU(Here)))
			corrs(2) = -(CameraResults(10) * Cos(CU(Here)) + CameraResults(11) * Sin(CU(Here)))
			
'			Print "Corrections: "
'			Print " Del X = ", Corrs(1)
'			Print " Del Y = ", Corrs(2)
'			Print " Del U = ", Corrs(3)
		Else
			Print "Retrieving last stored offset of chip"
			ChipToChipCorrections(CameraResults(10), CameraResults(11), CameraResults(12), DAT_X(idx(10), idx(11)), DAT_Y(idx(10), idx(11)), DAT_U(idx(10), idx(11)), CU(Here), ByRef corrs())
		EndIf
		UpdateRobotLog$("Chip position correction based on current 'chip-to-socket' and previous 'chip-from-socket' offsets calculated")

		If Abs(corrs(3)) > 3. Then
			RTS_suberror(idx(1), "CORRECTION TO CHIP POSITION IS MORE THAN 3 DEGREES", -ERR_BAD_TOLERANCE)
			PlaceChipInSocket = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
		If Abs(corrs(1)) > 1. Or Abs(corrs(2)) > 1. Then
			RTS_suberror(idx(1), "CORRECTION TO CHIP POSITION IS MORE THAN 1 MM in X OR Y", -ERR_BAD_TOLERANCE)
			PlaceChipInSocket = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
		
'		Print "At socket, U will be ", CU(Here)
'		Print "DeltaDir is ", DeltaDir
'		Print "So chip should presumably be at ", Str$(CU(Here) + DeltaDir)
'		'''Print "Socket orientation should be ", SocketMezzanineOrientation(CHIPTYPE_NR), " wrt taught socket orientation"
'		Print "Socket orientation should be ", HandChipOrientation(CHIPTYPE_NR), " wrt taught socket orientation - (aligned with chip direction)"
'		Print "Chip should be at ", SocketChipOrientation(CHIPTYPE_NR), " wrt to mezzanine "
'		'''Print "So chip orientation should be ", Str$(CU(Here) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))
'       Print "So chip orientation should be ", Str$(CU(Here) +HandChipOrientation(CHIPTYPE_NR))
'		Print "Chip orientation is ", Str$(CU(Here) + CameraResults(12))
		Go Here +X(corrs(1)) +Y(corrs(2)) +U(corrs(3))
		
'		
'		' Place in socket
'		
		If Not InsertIntoSocketSoft Then
			RTS_suberror(idx(1), "Could not insert into socket", -ERR_SOCK_PLACE)
			PlaceChipInSocket = -ERR_SOCK_PLACE
			Exit Function
		EndIf
		UpdateRobotLog$("Chip inserted into socket, checking alignment")


		' Do alignment check of chip in socket after insertion
		JumpToSocket_camera(idx(10), idx(11))
		TargetSocketImage$ = DF_take_picture$(ts$ + "_target_socket")
		UpdateRobotLog$("Picture of chip in socket taken: " + TargetSocketImage$)

'		Print "Checking alignment"
		
		If Not GetChipInSocketAlignment(ts$, ByRef idx(), idx(10), idx(11), ByRef ChipSocketResults()) Then
			RTS_suberror(idx(1), "Cannot get chip in socket alignment", -ERR_V_CHIPSOCKALIGN)
			PlaceChipInSocket = -ERR_V_CHIPSOCKALIGN
			Exit Function
		EndIf
'		Print "Robot is at "
'		Print Here
		Print "Defined socket position"
		Print "  X: ", ChipSocketResults(1)
		Print "  Y: ", ChipSocketResults(2)
		Print "  U: ", ChipSocketResults(3)
		Print "Measured socket position"
		Print "  X: ", ChipSocketResults(4)
		Print "  Y: ", ChipSocketResults(5)
		Print "  U: ", ChipSocketResults(6)
		Print "Socket offsets"
		Print "  X: ", ChipSocketResults(7)
		Print "  Y: ", ChipSocketResults(8)
		Print "  U: ", ChipSocketResults(9)
		Print "Measured chip position"
		Print "  X: ", ChipSocketResults(10)
		Print "  Y: ", ChipSocketResults(11)
		Print "  U: ", ChipSocketResults(12)
		Print "Measured chip offset from measured socket position"
		Print "  X: ", ChipSocketResults(13)
		Print "  Y: ", ChipSocketResults(14)
		Print "  U: ", ChipSocketResults(15)
		'''	Print "Expect the chip to be at Point U + Mezzanine Offset + Chip offset = ", Str$((CU(P(PSocket(idx(10), idx(11)))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)))
		Print "Expect the chip to be at Point U + Chip-Hand offset = ", Str$(GetBoundAnglePM180((CU(P(PSocket(idx(10), idx(11)))) + HandChipOrientation(CHIPTYPE_NR))))
		
		''' socket now measured orientation to align with chip not socket mezzanine text	
		'''	Print "Expect offset relative to socket to be ", SocketChipOrientation(CHIPTYPE_NR)
				
		'If Abs(ChipSocketResults(12) - (CU(P(PSocket(idx(10), idx(11)))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))) > 5 Or Abs(ChipSocketResults(15) - (SocketChipOrientation(CHIPTYPE_NR))) > 5 Then
		If Abs(DiffAnglePM180(ChipSocketResults(12), (CU(P(PSocket(idx(10), idx(11)))) + HandChipOrientation(CHIPTYPE_NR)))) > 5 Or Abs(ChipSocketResults(15)) > 5 Then
			RTS_suberror(idx(1), "Chip orientation in socket after placement is inconsistent with defined relative orientation to hand!", -ERR_BAD_ORIENTATION)
			PlaceChipInSocket = -ERR_BAD_ORIENTATION
			Exit Function
		EndIf
		UpdateRobotLog$("Chip alignment in socket O.K.")

		SetSpeedSetting("MoveWithoutChip")
		PlaceChipInSocket = -1
Fend

''' For a batch of operations, check intial occupancies of the tray positions
' Batch operations are not fully implemented yet but will take an array of indices for each argument of the move function
Function CheckTrayPositionOccupancies(Expectation As Boolean, ByRef TrayNrs() As Int32, ByRef TrayCols() As Int32, ByRef TrayRows() As Int32, ByRef Occupancy() As Int32) As Int32
	CheckTrayPositionOccupancies = 0
	Int32 index
	For index = 1 To 8
		If Not (TrayNrs(index) = 0 Or TrayCols(index) = 0 Or TrayRows(index) = 0) Then
		 	Occupancy(index) = TrayPositionOccupied(TrayNrs(index), TrayCols(index), TrayRows(index))
		 	If Occupancy(index) < -1 Then
		 		' Log number of errors
		 		CheckTrayPositionOccupancies = CheckTrayPositionOccupancies + 10
		 	ElseIf Occupancy(index) > 0 Then
		 		' Log number of correctly filled (don't care about -1 which means unchecked
		 		CheckTrayPositionOccupancies = CheckTrayPositionOccupancies + 1
		 	EndIf
	 	EndIf
	Next
	''' Number of errors is number of 10s
	''' Number of successes is number of 1s
Fend

''' Checks if the tray position is occupied (individual)
'' Returns
' 1  - Occupied (chip seen with vision)
' 0  - Unoccupied
' -2 - Obstructed (no chip seen but physically something is there at the expected height, could be vision failure)
Function TrayPositionOccupied(Tray_nr As Int32, Tray_Col_nr As Int32, Tray_Row_nr As Int32) As Int32
	TrayPositionOccupied = 0
	' Return 0 for unoccupied
	' 1 for occupied with chip
	' -2 for error (-1 is "unchecked")
	
	SetSpeedSetting("MoveWithoutChip")
	
	
	' Go to the tray position and check visualy for a chip
	If isChipInTrayCamera(Tray_nr, Tray_Col_nr, Tray_Row_nr) Then
		Print "Can see a chip"
		TrayPositionOccupied = 1
		Exit Function
	EndIf
	
	' If no chip found with camera, check no obstruction 
	If isChipInTrayTouch(Tray_nr, Tray_Col_nr, Tray_Row_nr) Then
		Print "Could not see a chip, but something is in tray"
		TrayPositionOccupied = -2
	EndIf
	Go Here +Z(10)
		
	SetSpeedSetting("MoveWithoutChip")

Fend

''' For a batch of operations, check intial occupancies of the socket positions
' Batch operations are not fully implemented yet but will take an array of indices for each argument of the move function
Function CheckSocketPositionOccupancies(Expectation As Boolean, ByRef DATs() As Int32, ByRef Sockets() As Int32, ByRef Occupancy() As Int32) As Int32
	CheckSocketPositionOccupancies = 0
	
	SetSpeedSetting("MoveWithoutChip")

	Int32 index
	For index = 1 To 8
		If Not (DATs(index) = 0 Or Sockets(index) = 0) Then
		 	Occupancy(index) = SocketPositionOccupied(DATs(index), Sockets(index))
		 	If Occupancy(index) < -1 Then
		 		' Log number of errors
		 		CheckSocketPositionOccupancies = CheckSocketPositionOccupancies + 10
		 	ElseIf Occupancy(index) > 0 Then
		 		' Log number of correctly filled (don't care about -1 which means unchecked
		 		CheckSocketPositionOccupancies = CheckSocketPositionOccupancies + 1
		 	EndIf
	 	EndIf
	Next
	''' Number of errors is number of 10s
	''' Number of successes is number of 1s
	
	SetSpeedSetting("MoveWithoutChip")


Fend

''' Checks if the socket position is occupied (individual)
'' Returns
' 1  - Occupied (chip seen with vision)
' 0  - Unoccupied
' -2 - Obstructed (no chip seen but physically something is there at the expected height, could be vision failure)
Function SocketPositionOccupied(DAT_nr As Int32, Socket_nr As Int32) As Int32
	SocketPositionOccupied = 0
	' Return 0 for unoccupied
	' 1 for occupied with chip
	' -2 for error (-1 is "unchecked")
	SetSpeedSetting("MoveWithoutChip")

	' Go to the tray position and check visualy for a chip
	If isChipInSocketCamera(DAT_nr, Socket_nr) Then
		Print "Occupied"
		SocketPositionOccupied = 1
		Exit Function
	EndIf
	
	' If no chip found with camera, check no obstruction 
	If isChipInSocketTouch(DAT_nr, Socket_nr) Then
		Print "Could not see chip but touched something"
		SocketPositionOccupied = -2
	EndIf
	Go Here +Z(10)
	SetSpeedSetting("MoveWithoutChip")

Fend


