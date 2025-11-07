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
	
'	' Lost power case: assume that the tools is touching:
	If Sw(8) = Sw(9) Then
		isContactSensorTouches = True
	EndIf
Fend

Function SetSpeed
	Power Low
	Speed 100
	Accel 10, 10
	Speed 25
	Accel 2, 2
Fend

Function SetSpeedSetting(Setting$ As String)
	Power Low
	Speed 100
	Accel 10, 10
	Speed 1
	Accel 1, 1
	
	' Currently keeping non MSU or FNAL speeds low until enclosures are shipped/higher speeds are allowed by safety
	If SITE$ <> "MSU" Then
		If SITE$ <> "FNAL" Then
			Exit Function
		EndIf
	EndIf
	
	Select Setting$
		Case "MoveWithoutChip"
			Speed 30
			Accel 10, 10
		Case "MoveWithChip"
			Speed 10
			Accel 2, 2
		Case "PickAndPlace"
			Speed 1
			Accel 1, 1
		Case "AboveCamera"
			Speed 1
			Accel 1, 1
		Default
			Speed 25
			Accel 2, 2
	Send

Fend


Function MoveFromPointToImage
	' Move arm from stinger at point, to chip in focus with some rotation in degrees
	' Remember point is defined as some offset (10mm from contact)
	Move Here +Z(DF_CAM_Z_OFF)
	Move Here +X(XOffset(CU(Here))) +Y(YOffset(CU(Here)))

Fend

Function MoveFromImageToPoint
	' Inverse of above function, note rotation is not inverted like other offsets
	' And order of operations may need to be reversed if this matters for collisions
	Move Here -X(XOffset(CU(Here))) -Y(YOffset(CU(Here)))
	Move Here -Z(DF_CAM_Z_OFF)
	
Fend

' Jump to camera
' Preserve U rotation
Function JumpToCamera
	LoadPoints POINTS_FILE$
	If Agl(2) < 0 Then
		' Left-handed orientation
    	Jump P_camera :U(CU(Here)) /L LimZ JUMP_LIMIT
    Else
    	' Right-handed orientation 
    	Jump P_camera :U(CU(Here)) /R LimZ JUMP_LIMIT
	EndIf
	
Fend

' pallet_nr 1..2 (1-left, 2-right)
' row_nr = 1..6
' col_nr = 1..15
Function JumpToTray(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	Jump Pallet(pallet_nr, col_nr, row_nr) LimZ JUMP_LIMIT ' +Z(10)
Fend

' pallet_nr 1..2 (1-left, 2-right)
' row_nr = 1..6
' col_nr = 1..15
Function JumpToTray_camera(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	
	If ChipType$ = "COLDATA" Then
		If pallet_nr = 1 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0 + 180)) +Y(YOffset(HAND_U0 + 180)) +Z(DF_CAM_Z_OFF) :U(HAND_U0 + 180) LimZ JUMP_LIMIT
		ElseIf pallet_nr = 2 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT
		EndIf

	Else
		If pallet_nr = 1 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT
		ElseIf pallet_nr = 2 Then
			' TODO JOE CHECK Should this be the same for Pallet 1???
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Y(YOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Z(DF_CAM_Z_OFF) LimZ JUMP_LIMIT '  :U(CU(Pallet(pallet_nr, col_nr, row_nr)))
		EndIf
	EndIf
	
Fend

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


Function JumpToSocket(DAT_nr As Integer, socket_nr As Integer)
	If Dist(Here, P(100 * DAT_nr + socket_nr)) < 0.1 Then
		Exit Function
	EndIf
	' Note, should teach points at 20mm above contact
	Jump P(100 * DAT_nr + socket_nr) LimZ JUMP_LIMIT
	Print P(100 * DAT_nr + socket_nr)
	
Fend

Function JumpToSocket_cor(DAT_nr As Integer, socket_nr As Integer)
	'Print
	'Print socket_nr, "**********************************************"
	
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	VRun skt_cali_test
	
	Boolean Isfound1, Isfound2, Isfound3
	Boolean found
	
	Double x_p1, y_p1, a_p1, x_p2, y_p2, a_p2, x_p3, y_p3, a_p3
	Double x_ori, y_ori, a_ori
	
	'VGet skt_cali_test.CameraCenter.RobotXYU, found, x_ori, y_ori, a_ori
	Double check
	check = 100
	Integer N_round
	N_round = 0
	
	Do Until check < 20 And check > -20 Or N_round > 10
		VRun skt_cali_test
		VGet skt_cali_test.Geom01.RobotXYU, Isfound1, x_p1, y_p1, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, Isfound2, x_p2, y_p2, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, Isfound3, x_p3, y_p3, a_p3
		'Print "P3 xyu: ", x_p3, y_p3, a_p3
	
		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
		Double x_c, y_c
		x_c = (x_p1 + x_p3) /2
		y_c = (y_p1 + y_p3) /2

		Print "corr_center: ", x_c, y_c
		JumpToSocket(DAT_nr, socket_nr)
		Jump Here :X(x_c) :Y(y_c) LimZ JUMP_LIMIT
		
	EndIf
	
	
	
Fend

Function isChipInSocketCamera(DAT_nr As Integer, socket_nr As Integer) As Boolean
	
	isChipInSocketCamera = False
	JumpToSocket_camera(DAT_nr, socket_nr)
	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	If CHIPTYPE$ = "ColdADC" And SITE$ = "LSU" Then
		LSUColdADCSockOcc = True
	EndIf
	Do While (Attempts > 0) Or Success
		If FindChipDirectionWithDF Then
			isChipInSocketCamera = True
			Exit Function
		EndIf
		Attempts = Attempts - 1
	Loop
	LSUColdADCSockOcc = False
	
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

Function UF_camera_light_ON
	On 12
Fend

Function UF_camera_light_OFF
	Off 12
Fend

Function JumpToSocket_camera(DAT_nr As Integer, socket_nr As Integer)
	Integer SockP
	SockP = DAT_nr * 100 + socket_nr
	Double SockU
	SockU = CU(P(SockP))
'
'	Boolean At45
'	At45 = False
'	If ChipType$ = "COLDATA" Then
'		At45 = False
'	EndIF
'	If At45 Then
'		If DAT_nr = 2 Then
'			SockU = SockU - 45.
'		ElseIf DAT_nr = 1 Then
'			SockU = SockU + 45. '135.
'		EndIf
'	EndIf
	
	If Dist(Here, XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU)) < 0.1 Then
		Exit Function
	EndIf

	If DAT_nr = 1 Then
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /R LimZ JUMP_LIMIT
	Else
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /L LimZ JUMP_LIMIT
	EndIf

Fend

Function UF_take_picture$(basename$ As String) As String
 	UF_take_picture$ = RTS_DATA$ + "\images\UF_" + basename$ + ".bmp"
 	Print UF_take_picture$
 	VRun UF
    Wait 0.3
	VSaveImage UF, UF_take_picture$
Fend


Function DF_take_picture$(basename$ As String) As String
	DF_take_picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	Print DF_take_picture$
 	VRun DF
    Wait 0.3
	VSaveImage DF, DF_take_picture$
Fend



' ARGUMENTS
' INPUT: 
'       id$ - operation id (timestamp)
'       idx(20) - array of indexes
'       idx(1)  - CSV file index
'       idx(2)  - pallet number source (1-left, 2-right, 0 - N/A)
'       idx(3)  - pallet column number source (1-15, 0 - N/A)
'       idx(4)  - pallet row    number source (1-6 , 0 - N/A)
'       idx(5)  - pallet number target (1-left, 2-right, 0 - N/A)
'       idx(6)  - pallet column number target (1-15, 0 - N/A)
'       idx(7)  - pallet row    number target (1-6 , 0 - N/A)
'       idx(8)  - DAT board number source (1 - left, 2 - right, 0 - N/A)
'       idx(9)  - socket number source (1-8, 0 - N/A)
'       idx(10) - DAT board number target (1 - left, 2 - right, 0 - N/A)
'       idx(11) - socket number target (1-8, 0 - N/A)
'
' OUTPUT:
'       status - 0 - success, > 0 - error number
'       res(30) - array of results
' Results of analysis of chip position as it came from the source:
'       res(1)  - camera X, [mm]
'       res(2)  - camera Y, [mm]
'       res(3)  - chip X, initial measurement, [mm]
'       res(4)  - chip Y, initial measurement, [mm]
'       res(5)  - chip rotation, initial measurement, [deg]
'       res(6)  - chip X, measurement of the chip rotated by 180 deg, [mm]
'       res(7)  - chip Y, measurement of the chip rotated by 180 deg, [mm]
'       res(8)  - chip rotation, measurement of the chip rotated by 180 deg, [deg]
'       res(9)  - tool X [mm]
'       res(10) - tool Y [mm]
'       res(11) - chip X position relative to the tool [mm]
'       res(12) - chip Y position relative to the tool [mm]
'
' Results of analysis of chip position for destination:      
'       res(13) - chip X with hand at target rotation [mm]
'       res(14) - chip Y with hand at target rotation [mm]
'       res(15) - chip rotation with hand at target rotation [deg]
'
'       res(16) - dU - correction for chip rotation [deg]
'       res(17) - chip X, measurement at 0 deg, corrected for dU, [mm]
'       res(18) - chip Y, measurement at 0 deg, corrected for dU, [mm]
'       res(19) - chip angle, measurement at 0 deg, corrected for dU, [deg]
'       res(20) - dX - chip X correction [mm]
'       res(21) - dY - chip Y correction [mm]
'       rest(22-30) reserved / unused
'
' GLOBAL
'      tray_X
'      tray_Y
'      tray_U
'      DAT_X
'      DAT_Y
'      DAT_U


'Function ChipBottomAnaly(chip_SN$ As String, fileNum As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer, DAT_NR As Integer, ByRef status As Integer, ByRef res() As Double)
'Function ChipBottomAnaly(chip_SN$ As String, ByRef idx() As Integer, ByRef status As Integer, ByRef res() As Double)
'Function ChipBottomAnaly(id$ As String, ByRef idx() As Integer, ByRef res() As Double) As Integer
'
'	Integer i, fileNum
'	
'	ChipBottomAnaly = 0
'
'	' reset the array of results
'	For i = 1 To 30
'		res(i) = 0
'	Next i
'	fileNum = idx(1)
'	
'	' sources and targets of the chip
'	Integer src_pallet_nr, src_col_nr, src_row_nr, src_DAT_nr, src_socket_nr
'	Integer tgt_pallet_nr, tgt_col_nr, tgt_row_nr, tgt_DAT_nr, tgt_socket_nr
'	
'	fileNum = idx(1)
'	src_pallet_nr = idx(2)
'	src_col_nr = idx(3)
'	src_row_nr = idx(4)
'	tgt_pallet_nr = idx(5)
'	tgt_col_nr = idx(6)
'	tgt_row_nr = idx(7)
'
'	src_DAT_nr = idx(8)
'	src_socket_nr = idx(9)
'	tgt_DAT_nr = idx(10)
'	tgt_socket_nr = idx(11)
'			
'	'If tgt_DAT_nr = 1 Then
'	'	ChipBottomAnaly = 10
'	'	Print "***ERROR Functionality for DAT board 1 not implemented yet", 10
'    '    Exit Function
'	'EndIf
'		
'	' target position at the camera
'	Double tgt_x0, tgt_y0, tgt_u0
'	' hand rotation at destination
'	Double dst_U
'	If tgt_pallet_nr > 0 And tgt_pallet_nr <= NTRAYS And tgt_col_nr > 0 And tgt_col_nr <= TRAY_NCOLS And tgt_row_nr > 0 And tgt_row_nr <= TRAY_NROWS Then
'		tgt_x0 = tray_X(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
'		tgt_y0 = tray_Y(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
'		tgt_u0 = tray_U(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
'		dst_U = CU(Pallet(tgt_pallet_nr, tgt_col_nr, tgt_row_nr))
'	ElseIf tgt_DAT_nr > 0 And tgt_DAT_nr <= 2 And tgt_socket_nr > 0 And tgt_socket_nr <= NSOCKETS Then
'		tgt_x0 = DAT_X(tgt_DAT_nr, tgt_socket_nr)
'		tgt_y0 = DAT_Y(tgt_DAT_nr, tgt_socket_nr)
'		tgt_u0 = DAT_U(tgt_DAT_nr, tgt_socket_nr)
'		dst_U = CU(P(100 * tgt_DAT_nr + tgt_socket_nr))
'	Else
'		ChipBottomAnaly = 100
'		Exit Function
'	EndIf
'	
'	
'       'JW:
'   If Agl(4) < -45. Then
'           Go Here +U(180)
''      ElseIf Agl(4) < 0. Then
''              Go Here +U(135)
''              Go Here -U(180)
''              Go Here +U(45)
'   ElseIf Agl(4) <= 45. Then
'           Go Here +U(90)
'   Else
'           Go Here -U(180)
'   EndIf
'	
'	
'	UF_camera_light_ON
'	Wait 0.2
'	String pict_fname$
'	'UF_take_picture(chip_SN$, ByRef pict_fname_0$)
'	pict_fname$ = UF_take_picture$(id$ + "_01")
'    Print #fileNum, ",", pict_fname$,
'	
'	'Double tray_dx, tray_dy, tray_dU
'	VRun ChipBottom_Analy
'
'	Boolean ret_found
'	Double camera_X, camera_Y
'	Double X_0, Y_0, U_0
'	Double X_180, Y_180, U_180
'	Double X_tool, Y_tool
'
'	'VGet ChipBottom_Analy.Final.RobotXYU, ret_found, ret_X, ret_Y, ret_U
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'
'		VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
'		VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
'			
'		VGet ChipBottom_Analy.Final.CameraX, X_0
'		VGet ChipBottom_Analy.Final.CameraY, Y_0
'		VGet ChipBottom_Analy.Final.Angle, U_0
'
'		Print #fileNum, ",", ret_found,
'		Print #fileNum, ",", camera_X, ",", camera_Y,
'		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
'		
'		res(1) = camera_X
'		res(2) = camera_Y
'		
'		res(3) = X_0
'		res(4) = Y_0
'		res(5) = U_0
'
'	Else
'		
'		ChipBottomAnaly = 1
'		Print "***ERROR ", 1
'        Exit Function
'		
'	EndIf
'
'	' Repeat measurement for 180 deg. rotation
''	If CU(Here) < 235 Then
''		Go Here +U(180)
''	Else
''		Go Here -U(180)
''	EndIf
'
''      JW:
'	If Agl(4) <= 45. Then
'	    Go Here -U(180)
'    Else
'        Go Here +U(180)
'    EndIf
'
'	Wait 0.2
'	'UF_take_picture(chip_SN$ + "-180", ByRef pict_fname_180$)
'	'UF_take_picture(ByRef pict_fname$)
'	pict_fname$ = UF_take_picture$(id$ + "_02")
'	Print #fileNum, ",", pict_fname$,
'
'	VRun ChipBottom_Analy
'	
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'		
'		VGet ChipBottom_Analy.Final.CameraX, X_180
'		VGet ChipBottom_Analy.Final.CameraY, Y_180
'		VGet ChipBottom_Analy.Final.Angle, U_180
'
'		Print #fileNum, ",", ret_found,
'		Print #fileNum, ",", X_180, ",", Y_180, ",", U_180,
'
'		res(6) = X_180
'		res(7) = Y_180
'		res(8) = U_180
'
'		X_tool = 0.5 * (X_0 + X_180)
'		Y_tool = 0.5 * (Y_0 + Y_180)
'
'		res(9) = X_tool
'		res(10) = Y_tool
'
'		Print #fileNum, ",", X_tool, ",", Y_tool,
'
'		' chip position relative to the tool
'		res(11) = X_0 - X_tool
'		res(12) = Y_0 - Y_tool
'
'		Print #fileNum, ",", res(11), ",", res(12),
'
'		' record the chip position from the source
'		Double src_x0, src_y0, src_u0
'		' source: 1 - pallet, 2 - socket
'		Integer src
'		If src_pallet_nr > 0 And src_pallet_nr <= NTRAYS And src_col_nr > 0 And src_col_nr <= TRAY_NCOLS And src_row_nr > 0 And src_row_nr <= TRAY_NROWS Then
'			src_x0 = tray_X(src_pallet_nr, src_col_nr, src_row_nr)
'			src_y0 = tray_Y(src_pallet_nr, src_col_nr, src_row_nr)
'			src_u0 = tray_U(src_pallet_nr, src_col_nr, src_row_nr)
'			src = 1
'		ElseIf src_DAT_nr > 0 And src_DAT_nr <= 2 And src_socket_nr > 0 And src_socket_nr <= NSOCKETS Then
'			src_x0 = DAT_X(src_DAT_nr, src_socket_nr)
'			src_y0 = DAT_Y(src_DAT_nr, src_socket_nr)
'			src_u0 = DAT_U(src_DAT_nr, src_socket_nr)
'			src = 2
'		Else
'			ChipBottomAnaly = 101
'			Exit Function
'		EndIf
'
'		If src_x0 = 0 And src_y0 = 0 And src_u0 = 0 Then
'			Print "Recording position of the source: ", res(11), " ", res(12), " ", U_0
'			If src = 1 Then
'				tray_X(src_pallet_nr, src_col_nr, src_row_nr) = res(11)
'				tray_Y(src_pallet_nr, src_col_nr, src_row_nr) = res(12)
'				tray_U(src_pallet_nr, src_col_nr, src_row_nr) = U_0
'			ElseIf src = 2 Then
'				DAT_X(src_DAT_nr, src_socket_nr) = res(11)
'				DAT_Y(src_DAT_nr, src_socket_nr) = res(12)
'				DAT_U(src_DAT_nr, src_socket_nr) = U_0
'			Else
'				ChipBottomAnaly = 102
'				Exit Function
'			EndIf
'		EndIf
'
'	Else
'
'		ChipBottomAnaly = 2
'		Print "***Error ", 2
'        Exit Function
'	EndIf
'	
'    ' JW: need to correct the cases where you do +90, then -180 then +90
'         ' Other angles just do +180, then -180 or vice versa
'	If Agl(4) > -45. And Agl(4) <= 45. Then
'		Go Here +U(90)
'	EndIf
'
'
'	' Change handeness to the target 
'	If tgt_pallet_nr = 1 Or tgt_DAT_nr = 1 Then
'    	Jump P_camera :U(dst_U) /R LimZ JUMP_LIMIT
'    ElseIf tgt_pallet_nr = 2 Or tgt_DAT_nr = 2 Then
'    	Jump P_camera :U(dst_U) /L LimZ JUMP_LIMIT
'    EndIf
'	
'
'	' Rotate the hand to destination orientation Update: Done in a previous step
'	'Go Here :U(dst_U)
'	Wait 0.2
'
'	' Added 2024-06-18
'	' Re-evaluate the position of the tool
'	VRun ChipBottom_Analy
'
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'
'		'VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
'		'VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
'			
'		VGet ChipBottom_Analy.Final.CameraX, X_0
'		VGet ChipBottom_Analy.Final.CameraY, Y_0
'		VGet ChipBottom_Analy.Final.Angle, U_0
'
'		Print #fileNum, ",", ret_found,
'		'Print #fileNum, ",", camera_X, ",", camera_Y,
'		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
'		
'		'res(1) = camera_X
'		'res(2) = camera_Y
'		
'		'res(3) = X_0
'		'res(4) = Y_0
'		'res(5) = U_0
'
'	Else
'		
'		ChipBottomAnaly = 301
'		Print "***ERROR ", 301
'        Exit Function
'		
'	EndIf
'
'	' Repeat measurement for 180 deg. rotation
'	'If CU(Here) < 180 Then
'	
'	'If Hand < 1.5 Then ' 1 for right handed, 2 for left handed.
'		Go Here +U(180)
'	'Else
'	'	Go Here -U(180)
'	'EndIf
'	Wait 0.2
'	'UF_take_picture(chip_SN$ + "-180", ByRef pict_fname_180$)
'	'UF_take_picture(ByRef pict_fname$)
'	'pict_fname$ = UF_take_picture$(id$ + "_02")
'	'Print #fileNum, ",", pict_fname$,
'
'	VRun ChipBottom_Analy
'	
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'		
'		VGet ChipBottom_Analy.Final.CameraX, X_180
'		VGet ChipBottom_Analy.Final.CameraY, Y_180
'		VGet ChipBottom_Analy.Final.Angle, U_180
'
'		Print #fileNum, ",", ret_found,
'		Print #fileNum, ",", X_180, ",", Y_180, ",", U_180,
'
'		'res(6) = X_180
'		'res(7) = Y_180
'		'res(8) = U_180
'
'		X_tool = 0.5 * (X_0 + X_180)
'		Y_tool = 0.5 * (Y_0 + Y_180)
'
'		res(9) = X_tool
'		res(10) = Y_tool
'
'		Print #fileNum, ",", X_tool, ",", Y_tool,
'
'		Print "Tool position: X=", X_tool, ", Y=", Y_tool
'
'		' chip position relative to the tool
'		res(11) = X_0 - X_tool
'		res(12) = Y_0 - Y_tool
'
'		Print #fileNum, ",", res(11), ",", res(12),
'
'		' record the chip position from the source
'		'Double src_x0, src_y0, src_u0
'		'' source: 1 - pallet, 2 - socket
'		'Integer src
'		'If src_pallet_nr > 0 And src_pallet_nr <= NTRAYS And src_col_nr > 0 And src_col_nr <= TRAY_NCOLS And src_row_nr > 0 And src_row_nr <= TRAY_NROWS Then
'		'	src_x0 = tray_X(src_pallet_nr, src_col_nr, src_row_nr)
'		'	src_y0 = tray_Y(src_pallet_nr, src_col_nr, src_row_nr)
'		'	src_u0 = tray_U(src_pallet_nr, src_col_nr, src_row_nr)
'		'	src = 1
'		'ElseIf src_DAT_nr > 0 And src_DAT_nr <= 2 And src_socket_nr > 0 And src_socket_nr <= NSOCKETS Then
'	'		src_x0 = DAT_X(src_DAT_nr, src_socket_nr)
'	'		src_y0 = DAT_Y(src_DAT_nr, src_socket_nr)
'	'		src_u0 = DAT_U(src_DAT_nr, src_socket_nr)
'	'		src = 2
'	'	Else
'	'		ChipBottomAnaly = 101
'	'		Exit Function
'	'	EndIf
'
'	'	If src_x0 = 0 And src_y0 = 0 And src_u0 = 0 Then
'	'		Print "Recording position of the source: ", res(11), " ", res(12), " ", U_0
'	'		If src = 1 Then
'	'			tray_X(src_pallet_nr, src_col_nr, src_row_nr) = res(11)
'	'			tray_Y(src_pallet_nr, src_col_nr, src_row_nr) = res(12)
'	'			tray_U(src_pallet_nr, src_col_nr, src_row_nr) = U_0
'	'		ElseIf src = 2 Then
'	'			DAT_X(src_DAT_nr, src_socket_nr) = res(11)
'	'			DAT_Y(src_DAT_nr, src_socket_nr) = res(12)
'	'			DAT_U(src_DAT_nr, src_socket_nr) = U_0
'	'		Else
'	'			ChipBottomAnaly = 102
'	'			Exit Function
'	'		EndIf
'	'	EndIf
'
'	Else
'
'		ChipBottomAnaly = 302
'		Print "***Error ", 302
'        Exit Function
'			
'	EndIf
'
'
'	' End of code added on 2024-06-18
'
'	' re-evaluate chip position with the rotation at destination
'	Go Here :U(dst_U)
'	Wait 0.2
'
'	'UF_take_picture(ByRef pict_fname$)
'	pict_fname$ = UF_take_picture$(id$ + "_03")
'	Print #fileNum, ",", pict_fname$,
'
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'			
'		VGet ChipBottom_Analy.Final.CameraX, X_0
'		VGet ChipBottom_Analy.Final.CameraY, Y_0
'		VGet ChipBottom_Analy.Final.Angle, U_0
'
'		Print #fileNum, ",", ret_found,
'		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
'				
'		res(13) = X_0
'		res(14) = Y_0
'		res(15) = U_0
'
'	Else
'		
'		ChipBottomAnaly = 3
'		Print "***ERROR ", 3
'        Exit Function
'		
'	EndIf
'
'
'	Double d_U
'	'd_U = U_0 + 0.2
'	'd_U = U_0 - tgt_u0
'	d_U = tgt_u0 - U_0
'	res(16) = d_U
'	If Abs(d_U) < 2.0 Then
'		Go Here -U(d_U)
'	Else
'		ChipBottomAnaly = 4
'		Print "ERROR 4! : Rotation angle outside of control margin"
'		Exit Function
'	EndIf
'
'	' Remeasure X and Y with correct rotation
'	Wait 0.2
'	'UF_take_picture(ByRef pict_fname$)
'	pict_fname$ = UF_take_picture$(id$ + "_04")
'	Print #fileNum, ",", pict_fname$,
'	
'	VRun ChipBottom_Analy
'		
'	VGet ChipBottom_Analy.Final.Found, ret_found
'	If ret_found Then
'			
'		VGet ChipBottom_Analy.Final.CameraX, X_0
'		VGet ChipBottom_Analy.Final.CameraY, Y_0
'		VGet ChipBottom_Analy.Final.Angle, U_0
'
'		Print #fileNum, ",", ret_found,
'		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
'
'		res(17) = X_0
'		res(18) = Y_0
'		res(19) = U_0
'
'	Else
'		
'		ChipBottomAnaly = 5
'		Print "***ERROR ", 5
'        Exit Function
'			
'	EndIf
'
'	Double d_X, d_Y
'	d_X = tgt_x0 - (X_0 - X_tool)
'	d_Y = tgt_y0 - (Y_0 - Y_tool)
'	
'	Print #fileNum, ",", d_X, ",", d_Y, ",", d_U,
'
'	res(20) = d_X
'	res(21) = d_Y
'
'
'	' Analysis of pins
'	d_X = X_0 - X_tool
'	d_Y = Y_0 - Y_tool
'	If Abs(d_X) < 1 And Abs(d_Y) < 1 And Abs(U_0) < 2 Then
'		Print "Positioning the chip for pin analysis: ",
'		Print " dX=", d_X, " dY=", d_Y, " dU=", U_0
'		Go Here -X(d_X) -Y(d_Y) +U(U_0)
'	Else
'		ChipBottomAnaly = 6
'		Print "***ERROR ", 6
'        Exit Function
'	EndIf
'
'	pict_fname$ = UF_take_picture$(id$ + "_pins")
'	Print #fileNum, ",", pict_fname$,
'	VSet pins_analy.ImageFile, pict_fname$
'	
'	Integer status
'	status = PinsAnaly(id$)
'	Print #fileNum, ",", status,
'	If status <> 0 Then
'		ChipBottomAnaly = status
'	EndIf
'		
'	' Analysis of chip key for insertion into socket
'	Boolean res_1, res_2, res_3, res_4
'	If tgt_DAT_nr = 1 Then
'		Print "Checking ASIC key"
'		VSet key_check_1.ImageFile, pict_fname$
'		VRun key_check_1
'		
'		VGet key_check_1.Blob01.Found, res_1
'		VGet key_check_1.Blob02.Found, res_2
'		VGet key_check_1.Blob03.Found, res_3
'		VGet key_check_1.Blob04.Found, res_4
'		
'		If Not (res_1 And (Not res_2) And res_3 And res_4) Then
'			Print "***ERROR! Failed to determine the key position of the ASIC"
'			ChipBottomAnaly = 7
'			Exit Function
'		EndIf
'	ElseIf tgt_DAT_nr = 2 Then
'		Print "Checking ASIC key"
'		VSet key_check.ImageFile, pict_fname$
'		VRun key_check
'		
'		VGet key_check.Blob01.Found, res_1
'		VGet key_check.Blob02.Found, res_2
'		VGet key_check.Blob03.Found, res_3
'		VGet key_check.Blob04.Found, res_4
'		
'		If Not (res_1 And res_2 And res_3 And (Not res_4)) Then
'			Print "***ERROR! Failed to determine the key position of the ASIC"
'			ChipBottomAnaly = 7
'			Exit Function
'		EndIf
'	EndIf
'
'	UF_camera_light_OFF
'	
'Fend

Function PinsRowAnaly(name$ As String, fileNum As Integer) As Integer
	
	PinsRowAnaly = 0
	
	Boolean passed
	Integer nFound, i
	Double x, y, area, xold, yold
	Select SITE$
		Case "BNL"
			

			VGet pins_analy.name$.Passed, passed
			If Not passed Then
				Print "PinsAnaly " + name$ + " failed!"
				Print #fileNum, " failed"
				PinsRowAnaly = 301
				Exit Function
			EndIf
		
			VGet pins_analy.name$.NumberFound, nFound
			Print #fileNum, name$, ",", nFound,
			If nFound <> 32 Then
				PinsRowAnaly = 302
			EndIf
		
			For i = 1 To nFound
				VSet pins_analy.name$.CurrentResult, i
				VGet pins_analy.name$.CameraX, x
				VGet pins_analy.name$.CameraY, y
				VGet pins_analy.name$.Area, area
				Print #fileNum, ",", x, ",", y, ",", area,
				xold = x
				yold = y
				If i > 1 And Abs(x - xold) > 0.05 Then
					Print "*ERROR! Bent pin found in " + name$
					PinsRowAnaly = 400 + i
				EndIf
			Next i
		Case "MSU"
			VGet MSU_ChipAnal.name$.Passed, passed
			If Not passed Then
				Print "PinsAnaly " + name$ + " failed!"
				Print #fileNum, " failed",
				PinsRowAnaly = 301
				Exit Function
			EndIf
			
			VGet MSU_ChipAnal.name$.NumberFound, nFound
			'Print #fileNum, name$, ",", nFound,
			If nFound <> 32 Then
				PinsRowAnaly = 302
			EndIf
		
			For i = 1 To nFound
				VSet MSU_ChipAnal.name$.CurrentResult, i
				VGet MSU_ChipAnal.name$.CameraX, x
				VGet MSU_ChipAnal.name$.CameraY, y
				VGet MSU_ChipAnal.name$.Area, area
				'Print #fileNum, ",", x, ",", y, ",", area,
				xold = x
				yold = y
				If i > 1 And Abs(x - xold) > 0.05 Then
					Print "*ERROR! Bent pin found in " + name$,
					PinsRowAnaly = 400 + i
				EndIf
			Next i
			
	Send
	
	'Print #fileNum, " "' Should use RTS_error in movement function which will end the line
	
Fend


Function PinsAnaly(id$ As String) As Integer
	
	PinsAnaly = 0
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\pins\" + id$ + "_pins.csv" As #fileNum
		
	Select SITE$
		Case "BNL"
			VRun pins_analy
		Case "MSU"
			VRun MSU_ChipAnal
		Default
			Print "Need to set up pin analysis for your site"
			PinsAnaly = -100
			Close #fileNum
	Send

	Integer status
	status = PinsRowAnaly("BlobTop", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf
	
	status = PinsRowAnaly("BlobBottom", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	status = PinsRowAnaly("BlobLeft", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	status = PinsRowAnaly("BlobRight", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	Close #fileNum
	
Fend


' Prints error msg both to console and file
' closes the output file
Function RTS_error(fileNum As Integer, err_msg$ As String)
	Print "***ERROR! ", err_msg$, ", Last SubError=", SubError
	Print #fileNum, "***ERROR! ", err_msg$, ", Last SubError=", SubError
	Close #fileNum
Fend

' For subroutines to not close the error file, and close at top level Move Function instead
Function RTS_suberror(fileNum As Integer, err_msg$ As String, err_code As Int32)
	SubError = err_code
	Print "***ERROR! ", err_msg$
	Print #fileNum, "***ERROR! ", err_msg$,
Fend

Function calibrate_socket(DAT_nr As Integer, socket_nr As Integer)
	Print
	Print socket_nr, "**********************************************"
	
	
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	'Add error: x:  0.888672y:  -0.798645
	'Go Here +X(0.888672)
	'Go Here +Y(-0.798645)
	
	'Add a position fluctuation for test, only for test!!!	
	
	'Real r_x
  	'Randomize
  	'r_x = Rnd(2) - 1
  	
  	'Real r_y
    'Randomize
    'r_y = Rnd(2) - 1
  	
  	'Go Here +X(r_x)
  	'Go Here +Y(r_x)
  	'Print "Add error: x: ", r_x, "y: ", r_y
  	
  	'random end ********************************************************

	
	VRun skt_cali_test
	'Integer nP
	'VGet skt_cali_test.Geom01.NumberFound, nP
	'Print "number of point found: ", nP
	
	Boolean Isfound1, Isfound2, Isfound3
	Boolean found
	'VGet skt_cali_test.Geom01.Found, Isfound1
	'VGet skt_cali_test.Geom02.Found, Isfound2
	'VGet skt_cali_test.Geom03.Found, Isfound3
	
	Double x_p1, y_p1, a_p1, x_p2, y_p2, a_p2, x_p3, y_p3, a_p3
	Double x_ori, y_ori, a_ori
	
	'VGet skt_cali_test.CameraCenter.RobotXYU, found, x_ori, y_ori, a_ori
	Double check
	check = 100
	Integer N_round
	N_round = 0
	
	Do Until check < 20 And check > -20 Or N_round > 10
		VRun skt_cali_test
		VGet skt_cali_test.Geom01.RobotXYU, Isfound1, x_p1, y_p1, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, Isfound2, x_p2, y_p2, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, Isfound3, x_p3, y_p3, a_p3
		'Print "P3 xyu: ", x_p3, y_p3, a_p3
	

		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
	EndIf
	
	
	Double x_c, y_c
	
	x_c = (x_p1 + x_p3) /2
	y_c = (y_p1 + y_p3) /2
	'Print "HERE: ", Here
	'Print "ori_center: ", x_ori, y_ori
	Print "corr_center: ", x_c, y_c
	'Print P(20 + socket_nr) :Z(-132.5)
	
	'Double A_line
	
	'VGet skt_cali_test.LineFind01.Angle, A_line
	'Print A_line
	
	
Fend


'
''
'' INPUT: 
''        pallet_nr - pallet number of the chip source (1-left, 2-right)
''        col_nr - column number in the pallet (1-15)
''        row_nr - row number in the pallet (1-6)
''        DAT_nr - DAT board target (1-left, 2-right)
''        socket_nr - socket target (1-8)
''
'' RETURN:
''        > 0 - job_id (timestamp)
''        < 0 - Error id
'
'

'''' MSU WRITTEN FUNCTIONS ''''
'''' Move chip to and from tray/socket functions
' Should broadly match old BNL functions

Function SwapChipsInSocket(DAT As Integer, Socket As Integer, SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	UpdateRobotLog$("Starting SwapChipsInSocket")
	MoveChip(SrcTray, SrcTrayCol, SrcTrayRow, TgtTray, TgtTrayCol, TgtTrayRow, DAT, Socket, DAT, Socket, True, False)
Fend

Function MoveChipFromTrayToSocket(DAT As Integer, Socket As Integer, Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromTrayToSocket")
	MoveChip(Tray, TrayCol, TrayRow, 0, 0, 0, 0, 0, DAT, Socket, True, False)
Fend

Function MoveChipFromSocketToTray(DAT As Integer, Socket As Integer, Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromSocketToTray")
	MoveChip(0, 0, 0, Tray, TrayCol, TrayRow, DAT, Socket, 0, 0, True, False)
Fend

Function MoveChipFromTrayToTray(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromTrayToTray")
	MoveChip(SrcTray, SrcTrayCol, SrcTrayRow, TgtTray, TgtTrayCol, TgtTrayRow, 0, 0, 0, 0, True, False)
Fend

Function MoveChip(SrcTray As Int32, SrcTrayCol As Int32, SrcTrayRow As Int32, TgtTray As Int32, TgtTrayCol As Int32, TgtTrayRow As Int32, SrcDAT As Int32, SrcSocket As Int32, TgtDAT As Int32, TgtSocket As Int32, OccCheck As Boolean, DoT2TPinAnalysis As Boolean) As Int64
	SubError = 0
	' Main function for moving chips, keeps formating consistent and does checks for valid operations and occupancies (unless overriden for batch operation) 
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	MoveChip = Val(ts$)

	SetSpeedSetting("")
	
	String fname$
	fname$ = "manip.csv"
	
	Integer fileNum
	fileNum = FreeFile

	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
	
	Print #fileNum, ts$, ",",
	
	' If starting with an empty socket
	Double Empty_S_Results(10)
		
	' From socket to tray
	Double S2T_S_Results(16) ' Chip in Socket to go to (target) tray
	Double S2T_C_Results(13) ' Chip from socket to go to tray at UF Camera
 	Double S2T_T_Results(10) ' Chip from socket placed in Tray

	' From tray to socket
	Double T2S_T_Results(10) ' Chip in (source) Tray to go to socket
	Double T2S_C_Results(13)
	Double T2S_S_Results(16)

	' From tray to tray
	Double T2T_ST_Results(10) ' Chip in initial (Source) tray position
	Double T2T_TT_Results(10) ' Chip in final (Target) tray position
	Double T2T_C_Results(13)
	
	' From socket to socket
	Double S2S_SS_Results(16)
	Double S2S_TS_Results(16)
	Double S2S_C_Results(13)
	
	String Images$(14)
	String UFCImages1$(5)
	String UFCImages2$(5)
	' Most images to store when swapping two chips
	' If occupancy check fails, just store occupancy check image , otherwise
	' 1 - Source tray image
	' 2 - Target tray image
	' 3 - Source socket image
	' 4 - Target socket image
	' 5 - Chip1 UFC 1st measurement
	' 6 - Chip1 UFC 2nd measurement
	' 7 - Chip1 UFC Pin analysis center
	' 8 - Chip1 UFC Pin analysis left
	' 9 - Chip1 UFC Pin analysis right
	' 10 - Chip2 UFC 1st measurement
	' 11 - Chip2 UFC 2nd measurement
	' 12 - Chip2 UFC Pin analysis center
	' 13 - Chip2 UFC Pin analysis left
	' 14 - Chip2 UFC Pin analysis right	
	
	Int32 i
	For i = 1 To 16
		If i < 11 Then
			Empty_S_Results(i) = 0
			S2T_T_Results(i) = 0
			T2S_T_Results(i) = 0
			T2T_ST_Results(i) = 0
			T2T_TT_Results(i) = 0
		EndIf
		If i < 13 Then
			S2T_C_Results(i) = 0
			T2S_C_Results(i) = 0
			T2T_C_Results(i) = 0
		EndIf
		If i < 15 Then
			Images$(i) = ""
		EndIf
		If i < 5 Then
			UFCImages1$(i) = ""
			UFCImages2$(i) = ""
		EndIf
		S2T_S_Results(i) = 0
		T2S_S_Results(i) = 0
		S2S_SS_Results(i) = 0
		S2S_TS_Results(i) = 0

	Next

	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	idx(2) = SrcTray
	idx(3) = SrcTrayCol
	idx(4) = SrcTrayRow
	
	idx(5) = TgtTray
	idx(6) = TgtTrayCol
	idx(7) = TgtTrayRow
	
	idx(8) = SrcDAT
	idx(9) = SrcSocket
	
	idx(10) = TgtDAT
	idx(11) = TgtSocket
	
	
	Integer Op
	String operation$
	operation$ = "Invalid"
	
	Op = CheckOperationType(ByRef idx(), ByRef operation$)
	If Op < 0 Then
		Print "Invalid operation type"
		MoveChip = -ERR_BAD_COMMAND
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		RTS_error(fileNum, "Invalid operation")
	EndIf
	UpdateRobotLog$("Operation type determined to be " + Operation$)
	' Do checks of socket and tray occupancies
	' Expected intial occupancies
	'              Socket  |  Source  |  Target
	' T2S only  :    0     |     1    |   N/A
	' S2T + T2S :    1     |     1    |    0
	' S2T only  :    1     |    N/A   |    0
	' T2T       :   N/A    |     1    |    0

	SetSpeedSetting("MoveWithoutChip")
	Int32 Occupancy
	String OccupancyImage$
	Occupancy = CheckOperationOccupancy(ts$, ByRef idx(), operation$, ByRef OccupancyImage$)
	If Occupancy <> 0 Then
		Select Occupancy
			Case -1
				MoveChip = -ERR_V_NOCHIP
			Case -2
				MoveChip = -ERR_V_OCCUPIED
			Case -3
				MoveChip = -ERR_V_NOCHIP
			Case -4
				MoveChip = -ERR_V_OCCUPIED
			Case -5
				MoveChip = -ERR_OBSTRUCTION
			Default
				MoveChip = -ERR_OBSTRUCTION ' Shoulnd't get here
		Send
		Images$(1) = OccupancyImage$
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		RTS_error(fileNum, "Occupancy check fail, occupancy result : " + Str$(Occupancy))
		Exit Function
	EndIf
	
	SetSpeedSetting("MoveWithoutChip")

	' Now we have done occupancy checks, do pick and place 
	Double DeltaDir
	
	' Do socket to tray first in case of swap chips (S->T then T->S)
	'If DoS2T Then
	If Operation$ = "REMOVECHIP" Or Operation$ = "SWAPCHIPS" Then
		Print "Moving chip from socket (", idx(8), ",", idx(9), ") to tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		' Images$(3) - Source socket image
		If Not GetChipFromSocket(ts$, ByRef idx(), ByRef S2T_S_Results(), ByRef S2T_C_Results(), ByRef DeltaDir, ByRef Images$(3), ByRef UFCImages1$()) Then
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
			MoveChip = SubError
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			RTS_error(fileNum, "Failed to get chip from socket")
			Exit Function
		EndIf
		For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
		Next
		' Images$(2) - Target tray image
		If Not PlaceChipInTray(ts$, ByRef idx(), ByRef S2T_T_Results(), ByRef DeltaDir, ByRef Images$(2)) Then
			MoveChip = SubError
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			RTS_error(fileNum, "Failed to place chip in tray")
			Exit Function
		EndIf
	EndIf
	
'	If DoT2S Then
	If Operation$ = "LOADCHIP" Or Operation$ = "SWAPCHIPS" Then
		Print "Moving chip from tray (", idx(2), ",", idx(3), ",", idx(4), ") to socket (", idx(10), ",", idx(11), ")"
		' Images$(1) - Source tray image	
		If Not GetChipFromTray(ts$, ByRef idx(), ByRef T2S_T_Results(), ByRef DeltaDir, ByRef Images$(1)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to get chip from tray")
			Exit Function
		EndIf
		' Images$(4) - Target socket image	
		If Not PlaceChipInSocket(ts$, ByRef idx(), ByRef Empty_S_Results(), ByRef T2S_C_Results(), ByRef T2S_S_Results(), ByRef Images$(4), ByRef UFCImages2$()) Then
			For i = 1 To 5
				Images$(i + 9) = UFCImages2$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in socket")
			Exit Function
		EndIf
		For i = 1 To 5
			Images$(i + 9) = UFCImages2$(i)
		Next
	EndIf
	
	' If successful for socket-tray operation, log and close the file and exit
	If Operation$ = "LOADCHIP" Or Operation$ = "REMOVECHIP" Or Operation$ = "SWAPCHIPS" Then
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		Print ""
		Close #fileNum
		MoveChip = 0
		UpdatePositionFiles
		Exit Function
	EndIf



	' Should only get here for T2T or S2S
'	If DoT2T Then 
	If Operation$ = "T2T" Then
		Print "Moving chip from tray (", idx(2), ",", idx(3), ",", idx(4), ") to tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		' Images$(1) - Source tray image	
		If Not GetChipFromTray(ts$, ByRef idx(), ByRef T2T_ST_Results(), ByRef DeltaDir, ByRef Images$(1)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to get chip from tray")
			Exit Function
		EndIf
		
		If DoT2TPinAnalysis Then
			' UF analysis is otherwise included in the socket related functions to ensure it is always called
			If Not UFGetChipAlignment(ts$, ByRef idx(), ByRef T2T_C_Results(), ByRef UFCImages1$()) Then
				MoveChip = -ERR_V_UF_ALIGN
				For i = 1 To 5
					Images$(i + 4) = UFCImages1$(i)
				Next
				LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
				RTS_error(fileNum, "Cannot get chip position and aligment with up facing camera")
				Exit Function
			EndIf
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
		EndIf
		' Images$(2) - Target tray image
		If Not PlaceChipInTray(ts$, ByRef idx(), ByRef T2T_TT_Results(), ByRef DeltaDir, ByRef Images$(2)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in tray")
			Exit Function
		EndIf
		
		' Need to chaneg UFC1 results
		' Log here because we use different vectors for results in this case
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
	EndIf

	If Operation$ = "S2S" Then ' Or Operation$ = "REINSERT"
		Print "Moving chip from socket (", idx(8), ",", idx(9), ") to socket (", idx(10), ",", idx(11), ")"
		If Not GetChipFromSocket(ts$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_C_Results(), ByRef DeltaDir, ByRef Images$(3), ByRef UFCImages1$()) Then
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to pick up chip from socket")
			Exit Function
		EndIf
		If Not PlaceChipInSocket(ts$, ByRef idx(), ByRef Empty_S_Results(), ByRef S2S_C_Results(), ByRef S2S_TS_Results(), ByRef Images$(4), ByRef UFCImages2$()) Then
			For i = 1 To 5
				Images$(i + 9) = UFCImages2$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in socket")
			Exit Function
		EndIf
		For i = 1 To 5
			Images$(i + 4) = UFCImages1$(i)
			Images$(i + 9) = UFCImages2$(i)
		Next
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
	EndIf
	
	Print ""
	Close #fileNum
	UpdatePositionFiles
	MoveChip = 0
	
Fend

Function CheckOperationType(ByRef idx() As Integer, ByRef Operation$ As String) As Int32
	CheckOperationType = 0
	SubError = 0
	Boolean FromSocket, ToSocket, FromTray, ToTray
	FromSocket = False
	ToSocket = False
	FromTray = False
	ToTray = False
	
	' idx(2)  - Source tray
	' idx(3)  - Source tray col
	' idx(4)  - Source tray row
	
	' idx(5)  - Target tray
	' idx(6)  - Target tray col
	' idx(7)  - Target tray row
	
	' idx(8)  - Source DAT
	' idx(9)  - Source socket
	
	' idx(10)  - target DAT
	' idx(11)  - target socket
	
	' check source tray
	If (Not idx(2) = 0) And (Not idx(3) = 0) And (Not idx(4) = 0) Then
		FromTray = True
	ElseIf Not ((idx(2) = 0) And (idx(3) = 0) And (idx(4) = 0)) Then
		CheckOperationType = -2
		Exit Function
	EndIf
	
	' Target tray
	If (Not idx(5) = 0) And (Not idx(6) = 0) And (Not idx(7) = 0) Then
		ToTray = True
	ElseIf Not ((idx(5) = 0) And (idx(6) = 0) And (idx(7) = 0)) Then
		' Invalid, should set all to zero
		CheckOperationType = -3
		Exit Function
	EndIf

	' Source socket
	If (Not idx(8) = 0) And (Not idx(9) = 0) Then
		FromSocket = True
	ElseIf Not ((idx(8) = 0) And (idx(9) = 0)) Then
		CheckOperationType = -4
		Exit Function
	EndIf
	
	' Target socket
	If (Not idx(10) = 0) And (Not idx(11) = 0) Then
		ToSocket = True
	ElseIf Not ((idx(10) = 0) And (idx(11) = 0)) Then
		CheckOperationType = -5
		Exit Function
	EndIf
	
	If ((Not idx(8) = idx(10)) Or (Not idx(9) = idx(11))) And (idx(8) <> 0 And idx(9) <> 0) Then
		Print "WARNING: Source and target sockets are not the same"
	EndIf

	' Which operation type?
	Boolean DoS2T, DoT2S, DoT2T, DoS2S
'	Boolean DoS2S
'	Boolean DoT2C, DoC2T, DoS2C, DoC2S
	DoS2T = False ' Source Socket to target tray
	DoT2S = False ' Source tray to target socket
	DoT2T = False ' Source tray to target tray
	DoS2S = False ' Source socket to target socket - not implemented 
' To be implemented
'	DoT2C = False ' Source tray to camera and hold
'	DoS2C = False ' Socket to camera and hold
'	DoC2T = False ' From camera to target tray
	
	If (Not FromTray) And (Not ToTray) And (Not FromSocket) And (Not ToSocket) Then
		Print "No socket or tray position passed!"
		CheckOperationType = -10
		Exit Function
	EndIf
	
	If FromSocket And ToTray Then
		DoS2T = True
		If FromTray Xor ToSocket Then
			' INVALID	
			Print "Invalid combination of indices"
			CheckOperationType = -10
			Exit Function
		EndIf
	EndIf
	
	If FromTray And ToSocket Then
		DoT2S = True
		If FromSocket Xor ToTray Then
			' INVALID
			Print "Invalid combination of indices"
			CheckOperationType = -10
			Exit Function
		EndIf
	EndIf
	
	If (Not FromSocket) And (Not ToSocket) And (FromTray And ToTray) Then
		DoT2T = True
	EndIf
	
	If (FromSocket And ToSocket) And (Not FromTray) And (Not ToTray) Then
		DoS2S = True
		' Not implemented yet
		Print "Socket to socket operation not yet implemented"
		CheckOperationType = -15
		Exit Function
	EndIf
	
'	Print " Actions to perform:"
'	Print "Socket to tray: ", DoS2T
'	Print "Tray to socket: ", DoT2S
'	Print "Tray to tray  : ", DoT2T
	
	' Need at least one of the movement types to be valid
	If Not DoS2T And Not DoT2S And Not DoT2T Then
		Print "Not a valid operation"
		CheckOperationType = -10
	 	Exit Function
	EndIf

	If DoT2T Then
		Operation$ = "T2T" ' Tray to tray
		CheckOperationType = 1
	ElseIf DoT2S And Not DoS2T Then
		Operation$ = "LOADCHIP" ' Tray to socket only
		CheckOperationType = 2
	ElseIf DoS2T And Not DoT2S Then
		Operation$ = "REMOVECHIP" ' Socket to tray only
		CheckOperationType = 3
	ElseIf DoS2S Then
		Operation$ = "S2S" ' Socket to socket
		CheckOperationType = 4
		If idx(8) = idx(10) And idx(9) = idx(11) Then
			Operation$ = "REINSERT"
			CheckOperationType = 6
		EndIf
	ElseIf DoS2T And DoT2S Then
		Operation$ = "SWAPCHIPS" ' Swap current chip for new chip
		CheckOperationType = 5
	Else
		Operation$ = "INVALID"
		CheckOperationType = -10
	EndIf
	
	
Fend

Function CheckOperationOccupancy(ts$ As String, ByRef idx() As Integer, Operation$ As String, ByRef Image$ As String) As Int32
	UpdateRobotLog$("Checking initial occupancies")
	SubError = 0
	Print "Checking occupancy of tray and socket positions"
	Int32 Occupancy
	Occupancy = -1
	
	CheckOperationOccupancy = 0
	' -1 = Empty source tray
	' -2 = Occupied target tray
	' -3 = empty source socket
	' -4 = occupied target socket
	' -5 = Obstruction
	
	' Check source tray is occupied : DoT2S Or DoT2T
	If Operation$ = "LOADCHIP" Or Operation$ = "T2T" Or Operation$ = "SWAPCHIPS" Then
		Occupancy = TrayPositionOccupied(idx(2), idx(3), idx(4))
		Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				CheckOperationOccupancy = -5
			Else
				CheckOperationOccupancy = -1
			EndIf
			JumpToTray_camera(idx(2), idx(3), idx(4))
			Image$ = DF_take_picture$(ts$ + "_source_tray_occupancy")
			Exit Function
		EndIf
	EndIf
	
	' Check target tray is empty : DoS2T Or DoT2T
	If Operation$ = "REMOVECHIP" Or Operation$ = "T2T" Or Operation$ = "SWAPCHIPS" Then
		Occupancy = TrayPositionOccupied(idx(5), idx(6), idx(7))
		Print "Occupancy = ", Occupancy
		If Occupancy <> 0 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				CheckOperationOccupancy = -5
			Else
				CheckOperationOccupancy = -2
			EndIf
			JumpToTray_camera(idx(5), idx(6), idx(7))
			Image$ = DF_take_picture$(ts$ + "_target_tray_occupancy")
			Exit Function
		EndIf
	EndIf
	
	' Check source socket is full : DoS2T
	If Operation$ = "REMOVECHIP" Or Operation$ = "S2S" Or Operation$ = "SWAPCHIPS" Or Operation$ = "REINSERT" Then
		Occupancy = SocketPositionOccupied(idx(8), idx(9))
		Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				CheckOperationOccupancy = -5
			Else
				CheckOperationOccupancy = -3
			EndIf
			JumpToSocket_camera(idx(8), idx(9))
			Image$ = DF_take_picture$(ts$ + "_source_socket_occupancy")
			Exit Function
		EndIf
	EndIf

	' Check target Socket is empty : (DoT2S And Not DoS2T)
	If Operation$ = "LOADCHIP" Or Operation$ = "S2S" Then ' Or Operation$ = "SWAPCHIPS" Then
		Occupancy = SocketPositionOccupied(idx(10), idx(11))
		Print "Occupancy = ", Occupancy
		If Occupancy <> 0 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				CheckOperationOccupancy = -5
			Else
				CheckOperationOccupancy = -3
			EndIf
			JumpToSocket_camera(idx(10), idx(11))
			Image$ = DF_take_picture$(ts$ + "_target_socket_occupancy")
			Exit Function
		EndIf
	EndIf
	' if here all should be okay
	Image$ = ""
	CheckOperationOccupancy = 0
	
Fend


Function UFRecenter(ByRef CameraResults() As Double) As Int32
	UFRecenter = 0
	JumpToCamera
	Double CorX1, CorY1, CorU1
	CorX1 = CameraResults(10) * Cos(DegToRad(CU(Here))) - CameraResults(11) * Sin(DegToRad(CU(Here)))
	CorY1 = CameraResults(10) * Sin(DegToRad(CU(Here))) + CameraResults(11) * Cos(DegToRad(CU(Here)))
	Go Here -X(CorX1) -Y(CorY1) -U(GetBoundAnglePM45(DiffAnglePM180(CameraResults(2), CameraResults(12))))
	UFRecenter = -1
Fend



'Function TakeToRejectTray As Int32
'	' Function to take a chip to the reject tray
'Fend
'
'Function ResetRejectTray As Int32
'	' Function to call when a new reject tray is loaded, resetting occupancy
'Fend
'
'Function SurveyRejectTray As Int32
'	' Function to check the reject tray occupancy and fill arrays indicating which positions are occupied
'Fend
'
'
'Function SurveyTray As Int32
'	' Goes to tray, takes pictures of each chip and notes which tray positions are filled or empty	
'Fend


Function UFPinAnalysis(id$ As String, ByRef idx() As Integer, ByRef Images$() As String) As Int32
	UpdateRobotLog$("Running pin analysis")
	UFPinAnalysis = 0
	'Integer fileNum
	'fileNum = idx(1)
	'String pict_fname$
	Images$(1) = UF_take_picture$(id$ + "_pins")
	'Print #fileNum, ",", pict_fname$,
	'VSet pins_analy.ImageFile, pict_fname$
	
	Integer status
	status = PinsAnaly(id$)
	' Print #fileNum, ",", status,
	If status <> 0 Then
		UFPinAnalysis = status
	EndIf
	
	' Images(2) and (3) are for COLDATA extra images
	
Fend


Function LogResults(ts$ As String, ExitCode As Int64, OperationType$ As String, ByRef idx() As Integer, ByRef SourceSocketResults() As Double, ByRef TargetSocketResults() As Double, ByRef UFCameraResults1() As Double, ByRef UFCameraResults2() As Double, ByRef Images$() As String) As Int64
	
	' Logs information from MoveChip
	' In order:
	'  - Time stamp (already in file)
	'  - Exit code
	'  - Operation type (Tray to tray, swap chip etc)
	'  - Input indices (source tray, target tray, source socket, target socket)
	'  - Chip in source socket results (empty if no source socket)
	'  - Chip in target socket results (empty if no target socket)
	'  - Up facing chip position results 
	'  - Pin analysis status
	'  - List of images
	'     - Source tray
	'     - Target tray
	'     - Source socket
	'     - Target socket
	'     - First UF picture
	'     - Second UF picture
	'     - Pin analysis picture

	Int64 i, fileNum
	fileNum = idx(1)
	
	Print #fileNum, ExitCode, ",", OperationType$,
	Print #fileNum, ", In:",
	For i = 2 To 11
		Print #fileNum, ",", idx(i),
	Next
	Print #fileNum, ", SS:",
	For i = 1 To 15
		Print #fileNum, ",", SourceSocketResults(i),
	Next
	Print #fileNum, ", TS:",
	For i = 1 To 15
		Print #fileNum, ",", TargetSocketResults(i),
	Next
	Print #fileNum, ", C1:",
	For i = 1 To 13
		Print #fileNum, ",", UFCameraResults1(i),
	Next
	Print #fileNum, ", C2:",
	For i = 1 To 13
		Print #fileNum, ",", UFCameraResults2(i),
	Next
	Print #fileNum, ", Imgs:",
	For i = 1 To 10
		If Images$(i) <> "" Then
			Print #fileNum, ",", Images$(i),
		EndIf
	Next
Fend

Function GetChipFromTray(ts$ As String, ByRef idx() As Integer, ByRef Tray_Results() As Double, ByRef DeltaDir As Double, ByRef SourceTrayImage$ As String) As Int32
	UpdateRobotLog$("Getting chip from tray " + Str$(idx(2)) + " position (" + Str$(idx(3)) + "," + Str$(idx(4)) + ")")
		GetChipFromTray = 0
'		Print "Getting chip from tray (", idx(2), ",", idx(3), ",", idx(4), ")"
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
		DeltaDir = SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)
		Double PickU
		PickU = Tray_Results(6) - DeltaDir '(SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)) ' DeltaDir
        Print "GetChipFromTray DeltaDir:", DeltaDir, ", PickU:", PickU
 		Go Here :U(PickU + PickOffset)
		
		
'		Print "Calculating pick up angle"
'		Print "Chip direction at tray (wrt world): ", Tray_Results(6)
' '       Print "Chip direction at socket (wrt world): ", (CU(P(PSocket(DAT_nr, socket_nr))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))
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

Function PlaceChipInTray(ts$ As String, ByRef idx() As Integer, ByRef Tray_Results() As Double, ByRef DeltaDir As Double, ByRef TargetTrayImage$ As String) As Int32
	UpdateRobotLog$("Placing chip in tray " + Str$(idx(5)) + " position (" + Str$(idx(6)) + "," + Str$(idx(7)) + ")")
	
	PlaceChipInTray = 0
		
		SetSpeedSetting("MoveWithChip")

		Print "Placing chip in tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		JumpToTray(idx(5), idx(6), idx(7))
		UpdateRobotLog$("Jumped to tray")

		Go Here :U(TrayOrientation - DeltaDir)
		
		Go Here +U(PickOffset)
		
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
'
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
		DeltaDir = SocketResults(12) - CU(Here)
		Go Here +U(PickOffset)
		
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

		JumpToSocket(idx(10), idx(11))
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

		corrs(1) = 0
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
			Corrs(3) = -DiffAnglePM180((SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)), CameraResults(12))
			Corrs(1) = -(CameraResults(10) * Cos(CU(Here)) - CameraResults(11) * Sin(CU(Here)))
			Corrs(2) = -(CameraResults(10) * Cos(CU(Here)) + CameraResults(11) * Sin(CU(Here)))
			
'			Print "Corrections: "
'			Print " Del X = ", Corrs(1)
'			Print " Del Y = ", Corrs(2)
'			Print " Del U = ", Corrs(3)
		Else
			Print "Retrieving last stored offset of chip"
			ChipToChipCorrections(CameraResults(10), CameraResults(11), CameraResults(12), DAT_X(idx(10), idx(11)), DAT_Y(idx(10), idx(11)), DAT_U(idx(10), idx(11)), CU(Here), ByRef Corrs())
		EndIf
		UpdateRobotLog$("Chip position correction based on current 'chip-to-socket' and previous 'chip-from-socket' offsets calculated")

		If Abs(Corrs(3)) > 3. Then
			Print "Chips orientation correction", Abs(Corrs(3)), CameraResults(12), SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)
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
'		Print "Socket orientation should be ", SocketMezzanineOrientation(CHIPTYPE_NR), " wrt taught socket orientation"
'		Print "Chip should be at ", SocketChipOrientation(CHIPTYPE_NR), " wrt to mezzanine "
'		Print "So chip orientation should be ", Str$(CU(Here) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))
'		Print "Chip orientation is ", Str$(CU(Here) + CameraResults(12))
		Go Here +X(Corrs(1)) +Y(Corrs(2)) +U(Corrs(3))
		
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
		Print "Expect the chip to be at Point U + Mezzanine Offset + Chip offset = ", Str$((CU(P(PSocket(idx(10), idx(11)))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR)))
		Print "Expect offset relative to socket to be ", SocketChipOrientation(CHIPTYPE_NR)
		
		If Abs(ChipSocketResults(12) - (CU(P(PSocket(idx(10), idx(11)))) + SocketMezzanineOrientation(CHIPTYPE_NR) + SocketChipOrientation(CHIPTYPE_NR))) > 5 Or Abs(ChipSocketResults(15) - (SocketChipOrientation(CHIPTYPE_NR))) > 5 Then
			RTS_suberror(idx(1), "Chip orientation in socket after placement is inconsistent with defined relative orientation!", -ERR_BAD_ORIENTATION)
			PlaceChipInSocket = -ERR_BAD_ORIENTATION
			Exit Function
		EndIf
		UpdateRobotLog$("Chip alignment in socket O.K.")

		SetSpeedSetting("MoveWithoutChip")
		PlaceChipInSocket = -1
Fend



Function PSocket(DAT_nr As Int32, Socket_nr As Int32) As Int32
	PSocket = DAT_nr * 100 + Socket_nr
Fend

'Function FindTrayAgl4Offsets(TrayNumber As Int32) As Int32
'	' Function to go to the trays and get the offset between U and J4 at each point
'	FindTrayAgl4Offsets = 0
'	Int32 i, j
'	For i = 1 To trayNCols
'		For j = 1 To trayNRows
'			JumpToTray(TrayNumber, i, j)
'			tray_Agl4Off(TrayNumber, i, j) = CU(Here) - Agl(4)
'		Next
'	Next
'	' Save to a file?
'Fend
'
'Function FindSocketAgl4Offsets(DAT As Int32) As Int32
'	' Function to go to the sockets and get the offset between U and J4 at each point
'	FindSocketAgl4Offsets = 0
'	Int32 i
'	For i = 1 To nSoc
'		JumpToSocket(DAT, i)
'		socket_Agl4Off(DAT, i) = CU(Here) - Agl(4)
'	Next
'	' Save to a file?
'Fend

Function CheckValidOperations(ByRef DATs() As Int32, ByRef Sockets() As Int32, ByRef TrayNrs() As Int32, ByRef TrayCols() As Int32, ByRef TrayRows() As Int32) As Int32
	
	Int32 nOperations
	nOperations = 0
	
	Int32 i, nerrors, totalerrors, errcode
	errcode = 11111111
	totalerrors = 0
	For i = 1 To 8
		nerrors = 0
		' First check all DAT and tray numbers make sense
		If (DATs(i) < 0 Or DATs(i) > 2) Or (Sockets(i) < 0 Or Sockets(i) > nSoc) Then
			Print "ERROR - Invalid DAT or Socket number "
			nerrors = nerrors + 1
		EndIf
		
		If (TrayNrs(i) < 0 Or TrayNrs(i) > NTRAYS) Or (TrayCols(i) < 0 Or TrayCols(i) > trayNCols) Or (TrayRows(i) < 0 Or TrayRows(i) > trayNRows) Then
			Print "ERROR - Invalid tray number or position"
			nerrors = nerrors + 1
		EndIf
		
		' Either all of the source socket and target tray are zero, or none are
		If DATs(i) = 0 And Sockets(i) = 0 And TrayNrs(i) = 0 And TrayCols(i) = 0 And TrayRows(i) = 0 Then
			'Skip this one so not included in the operation count if 0, 0, 0, 0, 0
			
		ElseIf DATs(i) = 0 Or Sockets(i) = 0 Or TrayNrs(i) = 0 Or TrayCols(i) = 0 Or TrayRows(i) = 0 Then
			Print "ERROR - One or more of the source or target position values is non-zero, but not all. Did you mean to skip this chip?"
			nerrors = nerrors + 1
		Else
			nOperations = nOperations + 1
		EndIf
		totalerrors = totalerrors + nerrors
		errcode = errcode + (nerrors * 100000000 / (10 * i))
	Next
	
	If totalerrors > 0 Then
		Print "ERROR: Invalid combination of socket/tray indices - Error code ", errcode
		' Each digit in 8 digit number should indicate the error, e.g. -20000 is bad tray ID in fifth operation
		' Or maybe change so listed with first operation in leading order, changing so 1 is valid, 0 is empty, 2,3,4 are errors?
		' i.e. -1500000 would be two non-zero commands with the second having an error
		CheckValidOperations = -errcode
	Else
		CheckValidOperations = nOperations
	EndIf
Fend

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
	If isChipInSocketTouch(DAT_nr, socket_nr) Then
		Print "Could not see chip but touched something"
		SocketPositionOccupied = -2
	EndIf
	Go Here +Z(10)
	SetSpeedSetting("MoveWithoutChip")

Fend

'''  Camera offset functions

Function XOffset(UValue As Double) As Double
	XOffset = DF_CAM_X_OFF_U0 * Cos(DegToRad(UValue - HAND_U0)) - DF_CAM_Y_OFF_U0 * Sin(DegToRad(UValue - HAND_U0))
Fend

Function YOffset(UValue As Double) As Double
	YOffset = DF_CAM_X_OFF_U0 * Sin(DegToRad(UValue - HAND_U0)) + DF_CAM_Y_OFF_U0 * Cos(DegToRad(UValue - HAND_U0))
Fend

Function SetupDirectories
	' Creates the directory RTS_DATA set in RTS_tools.inc if not already made 
	' And the subdirectories \images and \pins  

	' RTS DATA directory (set in RTS_tools.inc)
	If Not FolderExists(RTS_DATA$) Then
  		MkDir RTS_DATA$
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
	' images subdirectory
	String dir_images$
	dir_images$ = RTS_DATA$ + "images"

	If Not FolderExists(dir_images$) Then
  		MkDir dir_images$
	EndIf
	
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	' pins subdirectory
	String dir_pins$
	dir_pins$ = RTS_DATA$ + "pins"

	If Not FolderExists(dir_pins$) Then
  		MkDir dir_pins$
	EndIf
	
	If Not FolderExists(dir_pins$) Then
  		Print "***ERROR Can't create directory [" + dir_pins$ + "]"
  		Exit Function
	EndIf
Fend

Function MakePositionFiles
	' Sets the global arrays tray_X, tray_Y, tray_U, DAT_X, DAT_Y, and DAT_U to all zeros	
	' Then updates/makes the files tray_xyu.csv and .csv to the new array values.	
	' The arrays represent offsets of where the EOAT comes in contact and the center of the
	' tray slot or socket
	
	' reset global arrays for tray corrections
	Integer i, j, k
	For i = 1 To NTRAYS
		For j = 1 To TRAY_NCOLS
			For k = 1 To TRAY_NROWS
				tray_X(i, j, k) = 0
				tray_Y(i, j, k) = 0
				tray_U(i, j, k) = 0
			Next k
		Next j
	Next i
	
	' reset global arrays for socket positions
	For i = 1 To 2
		For j = 1 To NSOCKETS
			DAT_X(i, j) = 0
			DAT_Y(i, j) = 0
			DAT_U(i, j) = 0
		Next j
	Next i
	
	' save a file to keep track of tray corrections
	Integer fileNum
	String fileName$
	fileNum = FreeFile ' Returns an unused file handle
	fileName$ = RTS_DATA$ + "\tray_xyu.csv"
	WOpen fileName$ As #fileNum
	For i = 1 To NTRAYS
		For j = 1 To TRAY_NCOLS
			For k = 1 To TRAY_NROWS
				Print #fileNum, i, ",", j, ",", k, ",", tray_X(i, j, k), ",", tray_Y(i, j, k), ",", tray_U(i, j, k)
			Next k
		Next j
	Next i
	Close #fileNum
    
	' save a file to keep track of socket corrections
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\socket_xyu.csv"
	WOpen fileName$ As #fileNum
	For i = 1 To 2
		Print "NSOCKETS", NSOCKETS
		For j = 1 To NSOCKETS
			Print #fileNum, i, ",", j, ",", DAT_X(i, j), ",", DAT_Y(i, j), ",", DAT_U(i, j)
		Next j
	Next i
	Close #fileNum
	
Fend

Function UpdatePositionFiles
	'Updates the files holding the position corrections for the trays (tray_xyu.csv) 
	' and the sockets on the DAT board (socket_xyu.csv)
	
	' Set the file name for the tray position corrections
	Integer fileNum
	String fileName$
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\tray_xyu.csv"
	WOpen fileName$ As #fileNum
	
	Print "Writing to file: ", fileName$
	
	' Save the position set in the global arrays to the files
	Integer i, j, k
	For i = 1 To NTRAYS
		For j = 1 To TRAY_NCOLS
			For k = 1 To TRAY_NROWS
				Print #fileNum, i, ",", j, ",", k, ",", tray_X(i, j, k), ",", tray_Y(i, j, k), ",", tray_U(i, j, k)
			Next k
		Next j
	Next i
	Close #fileNum
    
	' Set the file name for the socket position corrections
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\socket_xyu.csv"
	WOpen fileName$ As #fileNum
	
	Print "Writing to file: ", fileName$
	
	' Save the position set in the global arrays to the files
	For i = 1 To 2
		For j = 1 To NSOCKETS
			Print #fileNum, i, ",", j, ",", DAT_X(i, j), ",", DAT_Y(i, j), ",", DAT_U(i, j)
		Next j
	Next i
	Close #fileNum
Fend

Function LoadPositionFiles
	' load positions at camera of chips coming from trays
	
    Integer fileNum
    String fileName$
    Double x, y, u
    Double i, j, k
    Double ii, jj, kk
    
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\tray_xyu.csv"
	
	If FileExists(fileName$) Then
		Print "Reading file ", fileName$
		ROpen fileName$ As #fileNum
		For i = 1 To NTRAYS
			For j = 1 To TRAY_NCOLS
				For k = 1 To TRAY_NROWS
					Input #fileNum, ii, jj, kk, x, y, u
					If ii = i And jj = j And kk = k Then
						tray_X(i, j, k) = x
						tray_Y(i, j, k) = y
						tray_U(i, j, k) = u
					Else
						Print "Error reading file ", fileName$, " ijk=", i, " ", j, " ", k
						Exit Function
					EndIf
				Next k
			Next j
		Next i
	EndIf
	Close #fileNum
	
	' load positions at camera of chips coming from sockets
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\socket_xyu.csv"
	If FileExists(fileName$) Then
		Print "Reading file ", fileName$
		ROpen fileName$ As #fileNum
		For i = 1 To 2
			For j = 1 To NSOCKETS
				Input #fileNum, ii, jj, x, y, u
				If ii = i And jj = j Then
					DAT_X(i, j) = x
					DAT_Y(i, j) = y
					DAT_U(i, j) = u
				Else
					Print "Error reading file ", fileName$
					Exit Function
				EndIf
			Next j
		Next i
	EndIf
	Close #fileNum
Fend


Function UpdateRobotLog$(log_msg$ As String) As String
	'Updates the Robot log file with the given log message
	
	' Set the file name for the tray position corrections
	Integer fileNum
	String fileName$
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\RobotLog.txt"
	AOpen fileName$ As #fileNum
	
	Print "Writing to file: ", fileName$
	
	Print #fileNum, log_msg$
	Close #fileNum
Fend

'''' Chip and socket direction functions ''''

Function ThreeCornerFindDirection(isFoundTL As Boolean, xTL As Double, yTL As Double, isFoundTR As Boolean, xTR As Double, yTR As Double, isFoundBR As Boolean, xBR As Double, yBR As Double, isFoundBL As Boolean, xBL As Double, yBL As Double) As Boolean
	ThreeCornerFindDirection = False
	
'	Print "ThreeCornerFind function"
'	Print "isFoundTL", isFoundTL
'	Print "isFoundTR", isFoundTR
'	Print "isFoundBR", isFoundBR
'	Print "isFoundBL", isFoundBL
	
	' For three points of a rectangle
    ' TL    TR
	'      / |
	'     /  | Side 1
	'    /   |
	'   /    |
	' BL-----BR
	' Side 2
	' Gives direction of BR -> TR
	' But uses hypotentuse for smaller error
	
	' 2025-09-19 JW: Updated to just take Side 1 for direction due to the fact not all markers are isosceles right angle 	
	' Still use diagonal average for center position
	Double AvX, AvY
	Double DelX1, DelY1, Hyp1, SPolar1, DelX2, DelY2, Hyp2, SPolar2
	If (Not isFoundTL) And (isFoundTR And isFoundBR And isFoundBL) Then
		' Missing key is Top Left in image (UP ORIENTED)
		' Av TR and BL
		AvX = (xTR + xBL) /2
		AvY = (yTR + yBL) /2
'		DelX = xTR - xBL
'		DelY = yTR - yBL
		DelX1 = xTR - xBR
		DelY1 = yTR - yBR
		DelX2 = xBR - xBL
		DelY2 = yBR - yBL
	ElseIf (Not isFoundTR) And (isFoundBR And isFoundBL And isFoundTL) Then
		' Missing key is Top Right in image (RIGHT ORIENTED)
		' Av BR and TL
		AvX = (xBR + xTL) /2
		AvY = (yBR + yTL) /2
'		DelX = xBR - xTL
'		DelY = yBR - yTL
		DelX1 = xBR - xBL
		DelY1 = yBR - yBL
		DelX2 = xBL - xTL
		DelY2 = yBL - yTL
	ElseIf (Not isFoundBR) And (isFoundTR And isFoundBL And isFoundTL) Then
		' Missing key is Bottom Right in image (DOWN ORIENTED)
		' Av BL and TR
		AvX = (xBL + xTR) /2
		AvY = (yBL + yTR) /2
'		DelX = xBL - xTR
'		DelY = yBL - yTR
		DelX1 = xBL - xTL
		DelY1 = yBL - yTL
		DelX2 = xTL - xTR
		DelY2 = yTL - yTR
	ElseIf (Not isFoundBL) And (isFoundTR And isFoundBR And isFoundTL) Then
		' Missing key is Bottom left in image (LEFT ORIENTED)
		' Av TL and BR
		AvX = (xTL + xBR) /2
		AvY = (yTL + yBR) /2
'		DelX = xTL - xBR
'		DelY = yTL - yBR
		DelX1 = xTL - xTR
		DelY1 = yTL - yTR
		DelX2 = xTR - xBR
		DelY2 = yTR - yBR
	Else
		Print "ERROR - DID NOT PASS STRICTLY THREE POINTS"
		Print "TL: ", isFoundTL, ", TR: ", isFoundTR, ", BR: ", isFoundBR, ", BL: ", isFoundBL
		ThreeCornerFindDirection = False
		CornerVar(1) = 0
		CornerVar(2) = 0
		CornerVar(3) = 0
		Exit Function

	EndIf
	Hyp1 = Sqr((DelX1 * DelX1) + (DelY1 * DelY1))
	If DelY1 >= 0. Then
		SPolar1 = RadToDeg(Acos(DelX1 / Hyp1))
	Else
		SPolar1 = -RadToDeg(Acos(DelX1 / Hyp1))
	EndIf
	Hyp2 = Sqr((DelX2 * DelX2) + (DelY2 * DelY2))
	If DelY2 >= 0. Then
		SPolar2 = RadToDeg(Acos(DelX2 / Hyp2)) + 90.
	Else
		SPolar2 = -RadToDeg(Acos(DelX2 / Hyp2)) + 90.
	EndIf
	
	SPolar1 = GetBoundAnglePM180(SPolar1)
	SPolar2 = GetBoundAnglePM180(SPolar2)
	Print "SPolar1 = ", SPolar1
	Print "SPolar2 = ", SPolar2
	Print " Diff   = ", DiffAnglePM180(SPolar1, SPolar2)
	Print " Av     = ", Str$(AverageAnglePM180(SPolar1, SPolar2))
	' SPolar = RadToDeg(Acos(DelX / Hyp))
	' SPolar = RadToDeg(Asin(DelY / Hyp))
	
	' Since sockets should be roughly at 90 degree increments to world axis, arctan should be fine
	' SPolar = RadToDeg(Atan(DelY / DelX))
	'Print "Polar angle from bottom left mark to top left mark is ", SPolar
	CornerVar(1) = AvX
	CornerVar(2) = AvY
	CornerVar(3) = AverageAnglePM180(SPolar1, SPolar2) ' SPolar1 '+ 45. ' 45 was frpm older methos using hypotonuse and right-isosceles triangle
	

	
	ThreeCornerFindDirection = True ' SPolar + 45.

Fend

Function FindChipDirectionWithDF As Boolean
	FindChipDirectionWithDF = False
	
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	Int32 FindError
	FindError = 0
	Select CHIPTYPE$
		Case "LArASIC"
			FindChipDirectionWithDF = DFFindLArASIC
		Case "ColdADC"
			If LSUColdADCSockOcc Then
					FindChipDirectionWithDF = DFFindColdADCInSocket
				Else
					FindChipDirectionWithDF = DFFindColdADC
			EndIf
'			Print "Error, not currently implemented for ColdADC, check if LArASIC works?"
'			Exit Function
		Case "COLDATA"
			
'			FindChipDirectionWithDF = DFFindCOLDATA
'			
			Int32 ToCheck, nFailLimit
			ToCheck = 10
			nFailLimit = 50
			Int32 it, tot
			it = 0
			tot = 0
			' NB cannot declare array length as variable, unfortunately means several hard coded 10s
			' Make sure to change all divisors for averages if this changes below
			Double XCHECK(10), YCHECK(10), UCHECK(10)
			Double AvX, AvY, AvU
			AvX = 0.
			AvY = 0.
			' need to track how many end up on +/- side of 180, not close to 0
			Int32 nU0, nUm180, nUp180
			Double AvU0, AvUm180, AvUp180
			nU0 = 0
			nUm180 = 0
			nUp180 = 0
			AvU0 = 0.
			AvUm180 = 0.
			AvUp180 = 0.
			
			Do While ToCheck > 0
				tot = tot + 1
				If DFFindCOLDATA Then
					it = it + 1
					XCHECK(it) = ChipPos(1)
					YCHECK(it) = ChipPos(2)
					UCHECK(it) = GetBoundAnglePM180(ChipPos(3))
					AvX = AvX + ChipPos(1)
					AvY = AvY + ChipPos(2)
					'AvU = AvU + ChipPos(3) '  Need to think about averaging around +/-180
					If ChipPos(3) < -90. Then
						nUm180 = nUm180 + 1
						AvUm180 = AvUm180 + ChipPos(3)
					ElseIf ChipPos(3) < 90. Then
						nU0 = nU0 + 1
						AvU0 = AvU0 + ChipPos(3)
					Else
						nUp180 = nUp180 + 1
						AvUp180 = AvUp180 + ChipPos(3)
					EndIf
					
					ToCheck = ToCheck - 1
				EndIf
				If tot > nFailLimit Then
					Print "Too many failures"
					ChipPos(1) = 0.
					ChipPos(2) = 0.
					ChipPos(3) = 0.
					FindChipDirectionWithDF = False
					Exit Function
				EndIf
			Loop
			AvX = AvX /10
			AvY = AvY /10
			

			
			' Can't have U values at -180, 0 and +180
			If (nU0 > 0 And nUm180 > 0 And nUp180 > 0) Then
				Print "Inconsistent angle values returned for averaging"
				Print " U  < -90       :", nUm180
				Print " -90 <= U < +90 :", nU0
				Print " +90 <= U       :", nUp180
				ChipPos(1) = 0.
				ChipPos(2) = 0.
				ChipPos(3) = 0.
				FindChipDirectionWithDF = False
				Exit Function
			EndIf
			
			If nUm180 > 0 Then
				AvUm180 = AvUm180 / nUm180
			EndIf
			If nU0 > 0 Then
				AvU0 = AvU0 / nU0
			EndIf
			If nUp180 > 0 Then
				AvUp180 = AvUp180 / nUp180
			EndIf
			
			' If values close to both -180 and +180, need to average around 180, so add 360 to negative values
			If nUm180 > 0 And nUp180 > 0 Then
				AvUm180 = AvUm180 + 360.
			EndIf
			
			
			
			AvU = GetBoundAnglePM180(((nUm180 * AvUm180) + (nU0 * AvU0) + (nUp180 * AvUp180)) / 10)
						
			Double StdDvX, StdDvY, StdDvU
'			Print "Results over ", 10, " successful iterations for ", tot, " total iterations"
			For it = 1 To 10
				StdDvX = StdDvX + (XCHECK(it) - AvX) * (XCHECK(it) - AvX)
				StdDvY = StdDvY + (YCHECK(it) - AvY) * (YCHECK(it) - AvY)
				StdDvU = StdDvU + (UCHECK(it) - AvU) * (UCHECK(it) - AvU)
'				Print "(", XCHECK(it), ",", YCHECK(it), ",", UCHECK(it), ")"
			Next
			StdDvX = Sqr(StdDvX / 10)
			StdDvY = Sqr(StdDvY / 10)
			StdDvU = Sqr(StdDvU / 10)
			
'			Print "Average : (", AvX, ",", AvY, ",", AvU, ")"
'			Print "Std dev : (", StdDvX, ",", StdDvY, ",", StdDvU, ")"
			
			If StdDvX * StdDvX + StdDvY * StdDvY > TolXY * TolXY Or StdDvU > TolAngle Then
				Print "Measurement spread too high"
				ChipPos(1) = 0.
				ChipPos(2) = 0.
				ChipPos(3) = 0.
				FindChipDirectionWithDF = False
				Exit Function
			EndIf
			
			ChipPos(1) = AvX
			ChipPos(2) = AvY
			ChipPos(3) = AvU
			FindChipDirectionWithDF = False
			
		Default
			Print "Error, chiptype not properly defined or DF find function does not exist for ", CHIPTYPE$
			Exit Function
	Send

Fend


Function DFFindLArASIC As Boolean
	
	DFFindLArASIC = False
	
	' Whole chip recognition
	Boolean isFoundChip
	Double xC, yC, uC
	' Fiducial and manufacturer marker recognition
	Boolean isFoundL, isFoundS
	Double xL, yL, uL, xS, yS, uS
	
	Select SITE$
		Case "MSU"

			
			VRun MSU_DF_ChipDir
			VGet MSU_DF_ChipDir.Corr01.RobotXYU, isFoundChip, xC, yC, uC

			' Get positions of Large and Small circular markers on chip
			VGet MSU_DF_ChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet MSU_DF_ChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
			
		Default
			Print "No defined vision sequence for LArASICs for site: ", SITE$
			Exit Function
			
	Send
	
	If Not isFoundChip Then
		' Print "Whole chip correlation step failed"
		Exit Function
	EndIf
	
	If Not isFoundL Then
		' Print "Failed to find largr manufacturing mark (bottom right of chip)"
		Exit Function
	EndIf
	
	If Not isFoundS Then
		' Print "Failed to find small fiducial mark (top left of chip)"
		Exit Function
	EndIf
	
	Double AvX, AvY
	AvX = (xL + xS) /2
	AvY = (yL + yS) /2

	' Get polar vector from Large marker to Small marker
	Double DelX, DelY, Norm, Angle
	DelX = xS - xL
	DelY = yS - yL
	
	Norm = Sqr(DelX * DelX + DelY * DelY)
	
	If DelY >= 0 Then
		Angle = RadToDeg(Acos(DelX / Norm))
	Else
		Angle = -RadToDeg(Acos(DelX / Norm))
	EndIf
	
	If Abs(Norm - LArASICDimension) > TolXY Then
		Print "Large-to-small marker distance not within tolerance: " + Str$(Norm)
		Exit Function
	EndIf
	
	' Check found position lies lose to correlation step for whole chip
	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
		Print "Fiducial marker method disagrees with correlation measurement of chip position"
		Print "Correlation position X,Y,U = (", xC, ",", yC, ",", GetBoundAnglePM180(uC), ")"
		Print "Fiducial position    X,Y,U = (", AvX, ",", AvY, ",", GetBoundAnglePM180(Angle - 45.), ")"
		Exit Function
	EndIf
	
	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = GetBoundAnglePM180(Angle - 45.)
	
	DFFindLArASIC = True
	
Fend

Function DFFindColdADC As Boolean
	
	DFFindColdADC = False
	
	' Whole chip recognition
	Boolean isFoundChip
	Double xC, yC, uC
	' Fiducial and manufacturer marker recognition
	Boolean isFoundL, isFoundS
	Double xL, yL, uL, xS, yS, uS
	
	Select SITE$
		Case "LSU"

			
			VRun LSU_DF_ChipDir
			VGet LSU_DF_ChipDir.Corr01.RobotXYU, isFoundChip, xC, yC, uC

			' Get positions of Large and Small circular markers on chip
			VGet LSU_DF_ChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet LSU_DF_ChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
			
		Default
			Print "No defined vision sequence for LArASICs for site: ", SITE$
			Exit Function
			
	Send
	
	If Not isFoundChip Then
		' Print "Whole chip correlation step failed"
		Exit Function
	EndIf
	
	If Not isFoundL Then
		' Print "Failed to find largr manufacturing mark (bottom right of chip)"
		Exit Function
	EndIf
	
	If Not isFoundS Then
		' Print "Failed to find small fiducial mark (top left of chip)"
		Exit Function
	EndIf
	
	Double AvX, AvY
	AvX = (xL + xS) /2
	AvY = (yL + yS) /2

	' Get polar vector from Large marker to Small marker
	Double DelX, DelY, Norm, Angle
	DelX = xS - xL
	DelY = yS - yL
	
	Norm = Sqr(DelX * DelX + DelY * DelY)
	
	If DelY >= 0 Then
		Angle = RadToDeg(Acos(DelX / Norm))
	Else
		Angle = -RadToDeg(Acos(DelX / Norm))
	EndIf
	
	If Abs(Norm - ColdADCDimension) > TolXY Then
		Print "Large-to-small marker distance not within tolerance: " + Str$(Norm)
		Exit Function
	EndIf
	
	' Check found position lies lose to correlation step for whole chip
	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
		Print "Fiducial marker method disagrees with correlation measurement of chip position"
		Print "Correlation position X,Y,U = (", xC, ",", yC, ",", GetBoundAnglePM180(uC), ")"
		Print "Fiducial position    X,Y,U = (", AvX, ",", AvY, ",", GetBoundAnglePM180(Angle - 45.), ")"
		Exit Function
	EndIf
	
	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = GetBoundAnglePM180(Angle - 45.)
	
	Print "LSU_DF_ChipDir output coord", AvX, AvY, Angle, ChipPos(3)
	
	DFFindColdADC = True
	
Fend


Function DFFindColdADCInSocket As Boolean
	
	DFFindColdADCInSocket = False
	
	' Fiducial and manufacturer marker recognition
	Boolean isFoundL(5)
	Double xL(5), yL(5), uL(5)
	Int32 itry, i
	
	
    For itry = 1 To 5
		xL(itry) = 0.
		yL(itry) = 0.
		uL(itry) = 0.
		isFoundL(itry) = False
    Next
	Select SITE$
		Case "LSU"
'			For i = 1 To 3
			i = 2
			VRun LSU_DF_ChipDirSo
'			' Get positions of Large and Small circular markers on chip
			VGet LSU_DF_ChipDirSo.Geom01.RobotXYU, isFoundL(i), xL(i), yL(i), uL(i)
			Print "ColdADC in socket positions", isFoundL(i), xL(i), yL(i), uL(i)
'			Next
		Default
			Print "No defined vision sequence for ColdADCs for site: ", SITE$
			Exit Function
			
	Send
	
	If Not isFoundL(2) Then
		' Print "Failed to find largr manufacturing mark (bottom right of chip)"
		Exit Function
	EndIf
	
	Double AvX, AvY, Angle
	AvX = xL(2)   	'(xL + xS) /2
	AvY = yL(2)		'(yL + yS) /2
	Angle = uL(2)
	' Get polar vector from Large marker to Small marker
'	Double DelX, DelY, Norm, Angle
'	DelX = xS - xL
'	DelY = yS - yL
'	
'	Norm = Sqr(DelX * DelX + DelY * DelY)
'	
'	If DelY >= 0 Then
'		Angle = RadToDeg(Acos(DelX / Norm))
'	Else
'		Angle = -RadToDeg(Acos(DelX / Norm))
'	EndIf
'	
'	If Abs(Norm - ColdADCDimension) > TolXY Then
'		Print "Large-to-small marker distance not within tolerance: " + Str$(Norm)
'		Exit Function
'	EndIf
'	
'	' Check found position lies lose to correlation step for whole chip
'	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
'		Print "Fiducial marker method disagrees with correlation measurement of chip position"
'		Print "Correlation position X,Y,U = (", xC, ",", yC, ",", GetBoundAnglePM180(uC), ")"
'		Print "Fiducial position    X,Y,U = (", AvX, ",", AvY, ",", GetBoundAnglePM180(Angle - 45.), ")"
'		Exit Function
'	EndIf
	If AvX = 0 Or AvY = 0 Then
		Print "Chip in socket check return 0's"
		Exit Function
	EndIf
	
	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = GetBoundAnglePM180(Angle - 90)  ' -45)
	
	DFFindColdADCInSocket = True
	
Fend



Function DFFindCOLDATA As Boolean

	DFFindCOLDATA = False
	
	Boolean AllowPartial
	AllowPartial = True
	
	' COLDATA chips are more difficult to pick out features on	
	' If possible use position of COLDATA text, center of outline, and center of full chip sequence to find position
	' Outline often isn't properly found due to occlusion, and so is less reliable
	
	Boolean isFoundChip, isFoundOutline, isFoundString
	Double xC, yC, uC ' Whole chip sequence result
	Double xO, yO, uO ' Chip outline sequence result
	Double xS, yS, uS ' Chip COLDATA string result
	Double xSCEst, ySCEst, uSCEst ' Estimate of chip center from COLDATA string position
	Double AvX, AvY, AvU ' Averages
	Double DelX, DelY, DelU ' Differences
	Double DelUAC, DelUAS ' Differences between calcualtd angle from positions and measured angles
	Double Norm, Angle ' Polar vector between chip center and coldata, for orientation and offset comparison
	
	Select SITE$
		Case "MSU"
		VRun MSU_DF_CDDir
		'VGet MSU_DF_CDDir.Point01.RobotXYU, isFP, xP, yP, uP ' For finding image center in testing
		VGet MSU_DF_CDDir.WholeChip.RobotXYU, isFoundChip, xC, yC, uC
		VGet MSU_DF_CDDir.ChipOutline.RobotXYU, isFoundOutline, xO, yO, uO
		VGet MSU_DF_CDDir.COLDATAString.RobotXYU, isFoundString, xS, yS, uS
		Default
			Print "Not a valid site name ", SITE$
	Send
	
	If Not AllowPartial And Not (isFoundChip And isFoundOutline And isFoundString) Then
		' Require all three sequences to be successful
		Print "Could not find all features"
		Exit Function
	ElseIf (Not isFoundChip) And (Not isFoundString) Then
		' When using partial infomration, require at least one sequence which recogninizes the COLDATA string	
		Print "Could not find the COLDATA text for orientation"
		Exit Function
	EndIf
	
	' Found COLDATA string
	' Get chip center estimate froms tring

	xSCEst = -9999.
	ySCEst = -9999.
	
	Byte FoundFeatures
	FoundFeatures = 0
	
	If isFoundChip Then
		'Print "Found chip"
		FoundFeatures = FoundFeatures + 100
	EndIf

	If isFoundString Then
		'Print "Found COLDATA string"
		FoundFeatures = FoundFeatures + 10
		' Calculate estimate of position from string
		uSCEst = GetBoundAnglePM180(uS + 90.)
		xSCEst = xS - COLDATATextOffset * Cos(DegToRad(uSCEst))
		ySCEst = yS - COLDATATextOffset * Sin(DegToRad(uSCEst))
	EndIf
	
	If isFoundOutline Then
		'Print "Found outline"
		FoundFeatures = FoundFeatures + 1
	EndIf
	' Print "FoundFeatures = ", FoundFeatures
	If FoundFeatures < 111 And Not AllowPartial Then
		Print "Could not find all features" ' : ", FoundFeatures
		Exit Function
	EndIf
		
	If AllowPartial And isFoundChip And Not isFoundString Then
		' Just use whole chip position
		ChipPos(1) = xC
		ChipPos(2) = yC
		ChipPos(3) = GetBoundAnglePM180(uC + 90.)

		DFFindCOLDATA = True
		Exit Function
	EndIf
	
	' If getting here then isFoundString must be true
	If Not isFoundString Then
		ChipPos(1) = 0.
		ChipPos(2) = 0.
		ChipPos(3) = 0.
		DFFindCOLDATA = False
		Exit Function
	EndIf

	' If no outline, average with whole chip
	If AllowPartial And Not isFoundOutline Then
		' Check constistency between string estimate and whole chip, then use average
		' Consistency check	
		If Sqr((xC - xSCEst) * (xC - xSCEst) + (yC - ySCEst) * (yC - ySCEst)) > TolXY Then
			
			DFFindCOLDATA = False
			Exit Function
		EndIf

		' For more precise angle we want to draw line between chip center and COLDATA string center
		DelX = xS - xC
		DelY = yS - yC
		DelU = DiffAnglePM180(uC, uS)
		
	'	DelU = GetBoundAnglePM45(uS) - GetBoundAnglePM45(uO) ' Use as sanity check, but may be out by n*90 degrees
	
		Norm = Sqr((DelX * DelX) + (DelY * DelY))
		If Abs(Norm - COLDATATextOffset) > TolXY Then
'			Print "Calculated distance between chip center from whole chip sequence and COLDATA string is not consistent with expected offset"
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		' Check consistent angles
		If Abs(DelU) > TolAngle Then
'			Print "Angles found by COLDATA string sequence and whole chip sequence are inconsistent - DelU = ", DelU
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		If DelY >= 0 Then
			Angle = RadToDeg(Acos(DelX / Norm))
		Else
			Angle = -RadToDeg(Acos(DelX / Norm))
		EndIf
		
		DelUAC = DiffAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
		DelUAS = DiffAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
		If Abs(DelUAC) > TolAngle Or Abs(DelUAS) > TolAngle Then
'			Print "Angle between COLDATA string and whole chip sequence result are inconsistent with sequence angles"
'			Print "Calculated angle          ", Angle
'			Print "COLDATA string angle      ", GetBoundAnglePM180(uS + 90.)
'			Print "Whole chip sequence angle ", GetBoundAnglePM180(uC + 90.)
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		
		' If it gets here used the average of the string est and whole chip?
		
		ChipPos(1) = (xC + xSCEst) / 2
		ChipPos(2) = (yC + ySCEst) / 2
		ChipPos(3) = GetBoundAnglePM180(Angle) ' <Maybe average?
		'ChipPos(3) = AverageAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
		
		DFFindCOLDATA = True
		Exit Function
	EndIf

	' Check constistency between string estimate and outline, then use average
	' Consistency check	
	If Sqr((xO - xSCEst) * (xO - xSCEst) + (yO - ySCEst) * (yO - ySCEst) > TolXY) Then
		DFFindCOLDATA = False
		Exit Function
	EndIf

	' For more precise angle we want to draw line between chip center and COLDATA string center
	DelX = xS - xO
	DelY = yS - yO
	' Outline won't be able to determine orientation, but can get angle away from axis\
	' Bounding the angle between +/-45deg allows comparison even if out by n*90deg
	DelU = DiffAnglePM180(GetBoundAnglePM45(uO), GetBoundAnglePM45(uS))
	
	Norm = Sqr((DelX * DelX) + (DelY * DelY))
	If Abs(Norm - COLDATATextOffset) > TolXY Then
'		Print "Calculated distance between chip center from whole chip sequence and COLDATA string is not consistent with expected offset"
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	' Check consistent angles
	If Abs(DelU) > TolAngle Then
'		Print "Angles found by COLDATA string sequence and whole chip sequence are inconsistent - DelU = ", DelU
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	If DelY >= 0 Then
		Angle = RadToDeg(Acos(DelX / Norm))
	Else
		Angle = -RadToDeg(Acos(DelX / Norm))
	EndIf
	
	' This won't work?

	DelUAC = DiffAnglePM180(GetBoundAnglePM45(uO), GetBoundAnglePM45(Angle))
	DelUAS = DiffAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
	If Abs(DelUAC) > TolAngle Or Abs(DelUAS) > TolAngle Then
'		Print "Angle between COLDATA string and whole chip sequence result are inconsistent with sequence angles"
'		Print "Calculated angle (bound within +/-45)     : ", Angle, " (", GetBoundAnglePM45(Angle), ")"
'		Print "COLDATA string angle                      :", GetBoundAnglePM180(uS + 90.)
'		Print "Outline sequence angle bound within +/-45 :", GetBoundAnglePM45(uC)
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	AvX = (xO + xSCEst) /2
	AvY = (yO + ySCEst) /2
	AvU = AverageAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
	' If here, and no full chip result, use the average of the sting and the outline
	If Not isFoundChip Then
		ChipPos(1) = AvX
		ChipPos(2) = AvY
		ChipPos(3) = AvU
		DFFindCOLDATA = True
		Exit Function
	EndIf
	
	' For full information, check consistency of above average, then average with whole chip.
	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
'		Print "Average position from string+outline does not match whole chip sequence results"
'		Print "String estimate               : (", xSCEst, ",", ySCEst, ",", GetBoundAnglePM180(uS + 90.), ")"
'		Print "Outline result (U in pm45)    : (", xO, ",", yO, ",", GetBoundAnglePM45(uO), ")"
'		Print "Angle between string and outline results: ", GetBoundAnglePM180(Angle)
'		Print "Average of string and outline : (", AvX, ",", AvU, ",", AvU, ")"
'		Print "Whole chip result             : (", xC, ",", yC, ",", GetBoundAnglePM180(uC + 90.), ")"
		DFFindCOLDATA = False
		Exit Function
	EndIf
		
	' If OK average in with whole chip result	
	ChipPos(1) = (xSCEst + xO + xC) / 3
	ChipPos(2) = (ySCEst + yO + yC) / 3
	ChipPos(3) = AverageAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
'	
'			'''''''''''''''''''''''''''''''''''''''''''''''''''
'	Print "Success! Found ", FoundFeatures, " XYU: ", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ","
'	If Abs(GetBoundAnglePM45(ChipPos(3))) > 3. Then
'		Print "Angles :"
'		Print "String  ", GetBoundAnglePM180(uS + 90.)
'		Print "Outline ", GetBoundAnglePM180(uO)
'		Print "Chip    ", GetBoundAnglePM180(uC + 90.)
'		Print "Calc    ", GetBoundAnglePM180(Angle)
'	EndIf
'	'''''''''''''''''''''''''''''''''''''''''''''''''''	
	
	DFFindCOLDATA = True
Fend


Function UF_CHIP_FIND As Boolean '(ByRef Status As Boolean, ByRef ResX As Double, ByRef ResY As Double) As Boolean
	
	' NOTE TODO JW: For COLDATA cannot rely on finding only three corners, just take three of the four corners found 
	' and use GetBoundAnglePM45 function on differences to ensure in same quadrant of angle or the vision
	' sequence may find wildly inconsistent angles for each measurement at incremebts of 90 degrees.
	' The DF camera is used to determine direction anyway
	UF_CHIP_FIND = False
	Boolean found(4)
	Boolean isFound(4) ' Check if separate variable is needed for this
	' Seems to maybe give different result?
	Double ResX(4), ResY(4), ResU(4)
	
	Select SITE$
		Case "MSU"
			VRun MSU_UF_Key
			VGet MSU_UF_Key.Geom01.Found, found(1) 'isFoundTR
			VGet MSU_UF_Key.Geom02.Found, found(2) 'isFoundBR
			VGet MSU_UF_Key.Geom03.Found, found(3) 'isFoundBL
			VGet MSU_UF_Key.Geom04.Found, found(4) 'isFoundTL
		Case "LSU"
			VRun LSU_UF_Key
			VGet LSU_UF_Key.Geom01.Found, found(1) 'isFoundTR
			VGet LSU_UF_Key.Geom02.Found, found(2) 'isFoundBR
			VGet LSU_UF_Key.Geom03.Found, found(3) 'isFoundBL
			VGet LSU_UF_Key.Geom04.Found, found(4) 'isFoundTL
		Default
			Print "INVALID SITE NAME"
			Exit Function
	Send
	
	If found(1) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom01.RobotXYU, isFound(1), ResX(1), ResY(1), ResU(1)
			Case "LSU"
				VGet LSU_UF_Key.Geom01.RobotXYU, isFound(1), ResX(1), ResY(1), ResU(1)
		Send
	Else
		ResX(1) = -9999.
		ResY(1) = -9999.
		ResU(1) = -9999.
	EndIf

	If found(2) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom02.RobotXYU, isFound(2), ResX(2), ResY(2), ResU(2)
			Case "LSU"
				VGet LSU_UF_Key.Geom02.RobotXYU, isFound(2), ResX(2), ResY(2), ResU(2)
		Send
	Else
		ResX(2) = -9999.
		ResY(2) = -9999.
		ResU(2) = -9999.
	EndIf
	
	If found(3) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom03.RobotXYU, isFound(3), ResX(3), ResY(3), ResU(3)
			Case "LSU"
				VGet LSU_UF_Key.Geom03.RobotXYU, isFound(3), ResX(3), ResY(3), ResU(3)
		Send
	Else
		ResX(3) = -9999.
		ResY(3) = -9999.
		ResU(3) = -9999.
	EndIf
	
	If found(4) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom04.RobotXYU, isFound(4), ResX(4), ResY(4), ResU(4)
			Case "LSU"
				VGet LSU_UF_Key.Geom04.RobotXYU, isFound(4), ResX(4), ResY(4), ResU(4)
		Send
	Else
		ResX(4) = -9999.
		ResY(4) = -9999.
		ResU(4) = -9999.
	EndIf
	
	' JW: Maybe go back and reorder the vision geometry so it starts at TL not TR
'	If Not ThreeCornerFindDirection(found(4), ResX(4), ResY(4), found(1), ResX(1), ResY(1), found(2), ResX(2), ResY(2), found(3), ResX(3), ResY(3)) Then
	' Flipped fropm above becauser camera is facing up not down at the XY plane
	' TL, TR, BR, BL from above is 
	If CHIPTYPE$ = "COLDATA" Then
		' Set TL to -9999 and not found
		found(1) = False
		ResX(1) = -9999.
		ResY(1) = -9999.
		ResU(1) = -9999.
		If Not ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			Print "ERROR: Chip corner orientation failed"
			UF_CHIP_FIND = False
			Exit Function
		EndIf
	Else
		If Not ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			Print "ERROR: Chip corner orientation failed"
			UF_CHIP_FIND = False
			Exit Function
		EndIf
	EndIf

	UFChipPos(1) = CornerVar(1)
	UFChipPos(2) = CornerVar(2)
	UFChipPos(3) = GetBoundAnglePM180(CornerVar(3))

	Print "Camera position in X = ", CX(P_Camera)
	Print "            Chip AvX = ", UFChipPos(1)
	Print "            Delta  X = ", (UFChipPos(1) - CX(P_Camera))
	Print "Camera position in Y = ", CY(P_Camera)
	Print "            Chip AvY = ", UFChipPos(2)
	Print "            Delta  Y = ", (UFChipPos(2) - CY(P_Camera))
	Print "Orientation of chip at ", UFChipPos(3)
	UF_CHIP_FIND = True


Fend

Function FindSocketDirectionWithDF As Boolean
	FindSocketDirectionWithDF = False
	
	Select CHIPTYPE$
		Case "LArASIC"
			FindSocketDirectionWithDF = DFFindLArASICSocket
		Case "ColdADC"
			FindSocketDirectionWithDF = DFFindColdADCSocket
'			Print "ColdADC not yet implemented, check if LArASIC socket works?"
		Case "COLDATA"
			FindSocketDirectionWithDF = DFFindCOLDATASocket
		Default
			Print "Unsupported chip type: ", CHIPTYPE$
	Send
Fend

Function DFFindLArASICSocket As Boolean
	Double USocket
	SelectSite
	
	Select SITE$
			Case "MSU"
				
				If MSUTESTBOARD Then
					VRun MSU_SocketFind2
				Else
					VRun MSU_SocketFind
				EndIf
				
			Default
				Print "Need to set up LArASIC/Socket find vision sequence, Try MSU_SocketFind"
		Send

	
	Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
	Boolean isFound1, isFound2, isFound3, isFound4
	Double xTR, yTR, uTR
	Double xBR, yBR, uBR
	Double xBL, yBL, uBL
	Double xTL, yTL, uTL
	
	Boolean isFoundMTR, isFoundMBR, isFoundMBL, isFoundMTL
	Boolean isFoundM1, isFoundM2, isFoundM3, isFoundM4
	Double xMTR, yMTR, uMTR
	Double xMBR, yMBR, uMBR
	Double xMBL, yMBL, uMBL
	Double xMTL, yMTL, uMTL

	
	Select SITE$
		Case "MSU"
			If MSUTESTBOARD Then
				VGet MSU_SocketFind2.Geom01.Found, isFoundTR
				VGet MSU_SocketFind2.Geom02.Found, isFoundBR
				VGet MSU_SocketFind2.Geom03.Found, isFoundBL
				VGet MSU_SocketFind2.Geom04.Found, isFoundTL
				
			Else
				VGet MSU_SocketFind.Geom01.Found, isFoundTR
				VGet MSU_SocketFind.Geom02.Found, isFoundBR
				VGet MSU_SocketFind.Geom03.Found, isFoundBL
				VGet MSU_SocketFind.Geom04.Found, isFoundTL
				
				VGet MSU_SocketFind.Geom05.Found, isFoundMTR
				VGet MSU_SocketFind.Geom06.Found, isFoundMBR
				VGet MSU_SocketFind.Geom07.Found, isFoundMBL
				VGet MSU_SocketFind.Geom08.Found, isFoundMTL
			EndIf
		Default

	Send
	
	
	' Require mounting holes to be found 
	
	If Not MSUTESTBOARD And (Not isFoundMTR Or Not isFoundMBR Or Not isFoundMBL Or Not isFoundMTL) Then
		Print "ERROR: Did not find mounting points for socket"
		Exit Function
	EndIf


	DFFindLArASICSocket = False
	Int32 nFound
	nFound = 0
	If isFoundTR Then
		nFound = nFound + 1
	EndIf
	If isFoundBR Then
		nFound = nFound + 1
	EndIf
	If isFoundBL Then
		nFound = nFound + 1
	EndIf
	If isFoundTL Then
		nFound = nFound + 1
	EndIf

	If nFound <> 3 Then
		Print "ERROR: Should find exactly 3 fiducial marks, found ", nFound
		Exit Function
	EndIf


	If isFoundTL Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				Else
					VGet MSU_SocketFind.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				EndIf
		Send
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then

		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				Else
					VGet MSU_SocketFind.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				EndIf
		Send

'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				Else
					VGet MSU_SocketFind.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				EndIf
		Send
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				Else
					VGet MSU_SocketFind2.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				EndIf
		Send
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf
	
	Select SITE$
		Case "MSU"
			If Not MSUTESTBOARD Then
				VGet MSU_SocketFind.Geom08.RobotXYU, isFoundM4, xMTL, yMTL, uMTL
				VGet MSU_SocketFind.Geom05.RobotXYU, isFoundM1, xMTR, yMTR, uMTR
				VGet MSU_SocketFind.Geom06.RobotXYU, isFoundM2, xMBR, yMBR, uMBR
				VGet MSU_SocketFind.Geom07.RobotXYU, isFoundM3, xMBL, yMBL, uMBL
			EndIf
	Send
	
	
'	Print "isFound TR:", isFoundTR
'	Print "isFound BR:", isFoundBR
'	Print "isFound BL:", isFoundBL
'	Print "isFound TL:", isFoundTL
'	
	' When viewed from up right orientation, missing marker will be
	' LArASIC - top left
	' ColdADC - top right
	' COLDATA - bottom right

	' LArASIC
	'        T3
	'
	'
	' T1     T2

	' orientation in world coordinates is direction of T2->T3 : T23
	' hypotentuse gives larger measurement but relies on isosceles right triangle
	' which is not true at socket fiducial markers 
	' Us av of T1->T2 + 90. and T2->T3

	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		DFFindLArASICSocket = False
		Exit Function
	EndIf
	
	If MSUTESTBOARD Then
		SockPos(1) = CornerVar(1)
		SockPos(2) = CornerVar(2)
		SockPos(3) = GetBoundAnglePM180(CornerVar(3))
		DFFindLArASICSocket = True
		Exit Function
	EndIf
	
	' For production sockets use large mounting hole features to confirm center of mezzanine
	' and provide additional positional information for average
	
	Double MXAv, MYAv, DiffX, DiffY
	MXAv = (xMTL + xMTR + xMBL + xMBR) /4
	MYAv = (yMTL + yMTR + yMBL + yMBR) /4
	DiffX = CornerVar(1) - MXAv
	DiffY = CornerVar(2) - MYAv
	
	If Abs(DiffX) > 0.3 Or Abs(DiffY) > 0.3 Then
		DFFindLArASICSocket = False
		Exit Function
	EndIf

	SockPos(1) = (CornerVar(1) + MXAv) / 2
	SockPos(2) = (CornerVar(2) + MYAv) / 2
	SockPos(3) = GetBoundAnglePM180(CornerVar(3) + 90.)
	
'	Print "Position found with fiducial points"
'	Print "(", CornerVar(1), ",", CornerVar(2), ",", CornerVar(3), ")"
'	Print "Position found with mounting points"
'	Print "(", MXAv, ",", MYAv, ")"
'	Print "Difference "
'	Print "  DelX: ", Str$(CornerVar(1) - MXAv)
'	Print "  DelY: ", Str$(CornerVar(2) - MYAv)
'	
'	Print "Final position"
'	Print "(", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	DFFindLArASICSocket = True

Fend

Function DFFindColdADCSocket As Boolean
	Double USocket
	SelectSite
	
	Select SITE$
			Case "LSU"
				
				If MSUTESTBOARD Then
					VRun MSU_SocketFind2
				Else
					VRun LSU_SocketFind
				EndIf
				
			Default
				Print "Need to set up LArASIC/Socket find vision sequence, Try MSU_SocketFind"
		Send

	
	Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
	Boolean isFound1, isFound2, isFound3, isFound4
	Double xTR, yTR, uTR
	Double xBR, yBR, uBR
	Double xBL, yBL, uBL
	Double xTL, yTL, uTL
	
	Boolean isFoundMTR, isFoundMBR, isFoundMBL, isFoundMTL
	Boolean isFoundM1, isFoundM2, isFoundM3, isFoundM4
	Double xMTR, yMTR, uMTR
	Double xMBR, yMBR, uMBR
	Double xMBL, yMBL, uMBL
	Double xMTL, yMTL, uMTL

	
	Select SITE$
		Case "LSU"
			If MSUTESTBOARD Then
				VGet MSU_SocketFind2.Geom01.Found, isFoundTR
				VGet MSU_SocketFind2.Geom02.Found, isFoundBR
				VGet MSU_SocketFind2.Geom03.Found, isFoundBL
				VGet MSU_SocketFind2.Geom04.Found, isFoundTL
				
			Else
				VGet LSU_SocketFind.Geom01.Found, isFoundTR
				VGet LSU_SocketFind.Geom02.Found, isFoundBR
				VGet LSU_SocketFind.Geom03.Found, isFoundBL
				VGet LSU_SocketFind.Geom04.Found, isFoundTL
				
				VGet LSU_SocketFind.Geom05.Found, isFoundMTR
				VGet LSU_SocketFind.Geom06.Found, isFoundMBR
				VGet LSU_SocketFind.Geom07.Found, isFoundMBL
				VGet LSU_SocketFind.Geom08.Found, isFoundMTL
			EndIf
		Default

	Send
	
	
	' Require mounting holes to be found 
	
	If Not MSUTESTBOARD And (Not isFoundMTR Or Not isFoundMBR Or Not isFoundMBL Or Not isFoundMTL) Then
		Print "ERROR: Did not find mounting points for socket"
		Exit Function
	EndIf


	DFFindColdADCSocket = False
	Int32 nFound
	nFound = 0
	If isFoundTR Then
		nFound = nFound + 1
	EndIf
	If isFoundBR Then
		nFound = nFound + 1
	EndIf
	If isFoundBL Then
		nFound = nFound + 1
	EndIf
	If isFoundTL Then
		nFound = nFound + 1
	EndIf

	If nFound <> 3 Then
		Print "ERROR: Should find exactly 3 fiducial marks, found ", nFound
		Exit Function
	EndIf


	If isFoundTL Then
		Select SITE$
			Case "LSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				Else
					VGet LSU_SocketFind.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				EndIf
		Send
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then

		Select SITE$
			Case "LSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				Else
					VGet LSU_SocketFind.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				EndIf
		Send

'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		Select SITE$
			Case "LSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				Else
					VGet LSU_SocketFind.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				EndIf
		Send
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		Select SITE$
			Case "LSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				Else
					VGet LSU_SocketFind.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				EndIf
		Send
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf
	
	Select SITE$
		Case "LSU"
			If Not MSUTESTBOARD Then
				VGet LSU_SocketFind.Geom08.RobotXYU, isFoundM4, xMTL, yMTL, uMTL
				VGet LSU_SocketFind.Geom05.RobotXYU, isFoundM1, xMTR, yMTR, uMTR
				VGet LSU_SocketFind.Geom06.RobotXYU, isFoundM2, xMBR, yMBR, uMBR
				VGet LSU_SocketFind.Geom07.RobotXYU, isFoundM3, xMBL, yMBL, uMBL
			EndIf
	Send
	
	
'	Print "isFound TR:", isFoundTR
'	Print "isFound BR:", isFoundBR
'	Print "isFound BL:", isFoundBL
'	Print "isFound TL:", isFoundTL
'	
	' When viewed from up right orientation, missing marker will be
	' LArASIC - top left
	' ColdADC - top right
	' COLDATA - bottom right

	' LArASIC
	'        T3
	'
	'
	' T1     T2

	' orientation in world coordinates is direction of T2->T3 : T23
	' hypotentuse gives larger measurement but relies on isosceles right triangle
	' which is not true at socket fiducial markers 
	' Us av of T1->T2 + 90. and T2->T3

	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		DFFindColdADCSocket = False
		Exit Function
	EndIf
	
	If MSUTESTBOARD Then
		SockPos(1) = CornerVar(1)
		SockPos(2) = CornerVar(2)
		SockPos(3) = GetBoundAnglePM180(CornerVar(3))
		DFFindColdADCSocket = True
		Exit Function
	EndIf
	
	' For production sockets use large mounting hole features to confirm center of mezzanine
	' and provide additional positional information for average
	
	Double MXAv, MYAv, DiffX, DiffY
	MXAv = (xMTL + xMTR + xMBL + xMBR) /4
	MYAv = (yMTL + yMTR + yMBL + yMBR) /4
	DiffX = CornerVar(1) - MXAv
	DiffY = CornerVar(2) - MYAv
	
	If Abs(DiffX) > 0.3 Or Abs(DiffY) > 0.3 Then
		DFFindColdADCSocket = False
		Exit Function
	EndIf

	SockPos(1) = (CornerVar(1) + MXAv) / 2
	SockPos(2) = (CornerVar(2) + MYAv) / 2
	SockPos(3) = GetBoundAnglePM180(CornerVar(3) + 90.)
	
'	Print "Position found with fiducial points"
'	Print "(", CornerVar(1), ",", CornerVar(2), ",", CornerVar(3), ")"
'	Print "Position found with mounting points"
'	Print "(", MXAv, ",", MYAv, ")"
'	Print "Difference "
'	Print "  DelX: ", Str$(CornerVar(1) - MXAv)
'	Print "  DelY: ", Str$(CornerVar(2) - MYAv)
'	
'	Print "Final position"
'	Print "(", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	DFFindColdADCSocket = True

Fend

Function DFFindCOLDATASocket As Boolean
		
	Select SITE$
		Case "MSU"
			VRun MSU_SocketFindL
					
			' Mounting points, should have found all of these
			Boolean isFound1, isFound2, isFound3, isFound4
			Double xMTR, yMTR, uMTR
			Double xMBR, yMBR, uMBR
			Double xMBL, yMBL, uMBL
			Double xMTL, yMTL, uMTL

			VGet MSU_SocketFindL.Geom01.RobotXYU, isFound1, xMTR, yMTR, uMTR
			VGet MSU_SocketFindL.Geom02.RobotXYU, isFound2, xMBR, yMBR, uMBR
			VGet MSU_SocketFindL.Geom03.RobotXYU, isFound3, xMBL, yMBL, uMBL
			VGet MSU_SocketFindL.Geom04.RobotXYU, isFound4, xMTL, yMTL, uMTL
			
			If Not isFound1 Or Not isFound2 Or Not isFound3 Or Not isFound4 Then
				DFFindCOLDATASocket = False
				Exit Function
			EndIf

			' Fiducial markers, should find exactly three of these
			Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
			Boolean isFound5, isFound6, isFound7, isFound8
			Double xTR, yTR, uTR
			Double xBR, yBR, uBR
			Double xBL, yBL, uBL
			Double xTL, yTL, uTL

			VGet MSU_SocketFindL.Geom05.Found, isFoundTR
			VGet MSU_SocketFindL.Geom06.Found, isFoundBR
			VGet MSU_SocketFindL.Geom07.Found, isFoundBL
			VGet MSU_SocketFindL.Geom08.Found, isFoundTL
		Default
			
	Send
	
	DFFindCOLDATASocket = False
	Int32 nFound
	nFound = 0
	If isFoundTR Then
		nFound = nFound + 1
	EndIf
	If isFoundBR Then
		nFound = nFound + 1
	EndIf
	If isFoundBL Then
		nFound = nFound + 1
	EndIf
	If isFoundTL Then
		nFound = nFound + 1
	EndIf

	If nFound <> 3 Then
		Print "ERROR: Should find exactly 3 fiducial marks, found ", nFound
		Exit Function
	EndIf

	If isFoundTL Then
		VGet MSU_SocketFindL.Geom08.RobotXYU, isFound4, xTL, yTL, uTL
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then
		VGet MSU_SocketFindL.Geom05.RobotXYU, isFound1, xTR, yTR, uTR
'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		VGet MSU_SocketFindL.Geom06.RobotXYU, isFound2, xBR, yBR, uBR
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		VGet MSU_SocketFindL.Geom07.RobotXYU, isFound3, xBL, yBL, uBL
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf


	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		DFFindCOLDATASocket = False
		Exit Function
	EndIf
	
	' Check consistency with four mounting points	
	Double AvMX, AvMY
	AvMX = (xMTR + xMBR + xMBL + xMTL) /4
	AvMY = (yMTR + yMBR + yMBL + yMTL) /4
	
	If Abs(Sqr((CornerVar(1) - AvMX) * (CornerVar(1) - AvMX) + (CornerVar(2) - AvMY) * (CornerVar(2) - AvMY))) > TolXY Then
		Print "Corner mounting point average and fiducial method socket positions are inconsistent"
		Print
		DFFindCOLDATASocket = False
		Exit Function
	EndIf
	
	SockPos(1) = CornerVar(1)
	SockPos(2) = CornerVar(2)
	SockPos(3) = CornerVar(3)

	DFFindCOLDATASocket = True
	
Fend

'''' Angle helper functions ''''

Function GetBoundAnglePM180(Angle As Double) As Double
' Return an angle within -180 to 180 degrees

	If Abs(Angle) < 180. Then
		GetBoundAnglePM180 = Angle
	EndIf
	Int32 Quotiant
	Double Offset
	If Angle > 0 Then
		Offset = +180.
	Else
		Offset = -180
	EndIf
	
	Angle = Angle + Offset
	Quotiant = Int(Angle) / 360
	Angle = Angle - Quotiant * 360 - Offset

	GetBoundAnglePM180 = Angle

Fend

Function GetBoundAnglePM45(Angle As Double) As Double
' Return an angle within -180 to 180 degrees

	If Abs(Angle) < 45. Then
		GetBoundAnglePM45 = Angle
	EndIf
	Int32 Quotiant
	Double Offset
	If Angle > 0 Then
		Offset = +45.
	Else
		Offset = -45
	EndIf
	
	Angle = Angle + Offset
	Quotiant = Int(Angle) / 90
	Angle = Angle - Quotiant * 90 - Offset
	'Print Angle
	GetBoundAnglePM45 = Angle

Fend


Function DiffAnglePM180(u1 As Double, u2 As Double) As Double
	' return difference between angles wihin +/-180
	u1 = GetBoundAnglePM180(u1)
	u2 = GetBoundAnglePM180(u2)
	
	DiffAnglePM180 = GetBoundAnglePM180(u2 - u1)
	
Fend

Function AverageAnglePM180(u1 As Double, u2 As Double) As Double
	' Need to make sure average is closest angle around -pi/+pi boundary
	If Abs(u1 - u2) > 180 Then
	' Need to average around -pi and pi
		If Abs(u1) > Abs(u2) Then
			' Closer to U2
			AverageAnglePM180 = (u2 - u1) /2
		Else
			' Closer to U1
			AverageAnglePM180 = (u1 - u2) /2
		EndIf
	Else
		AverageAnglePM180 = (u1 + u2) /2
	EndIf
Fend

'''' JW: Get alignment functions ''''

''' Defined position of the socket
' CinSRes(1) - X 
' CinSRes(2) - Y 
' CinSRes(3) - U
''' Measured position of the socket
' CinSRes(4) - X 
' CinSRes(5) - Y 
' CinSRes(6) - U
''' Socket offsets (Defined -> Measured)
' CinSRes(7) - X 
' CinSRes(8) - Y 
' CinSRes(9) - U
''' Measured chip position
' CinSRes(10) - X 
' CinSRes(11) - Y 
' CinSRes(12) - U
''' Chip offsets from measured socket position (Measured socket -> Measured chip)
' CinSRes(13) - X 
' CinSRes(14) - Y 
' CinSRes(15) - U

Function GetChipInSocketAlignment(id$ As String, ByRef idx() As Integer, DAT_nr As Integer, socket_nr As Integer, ByRef CinSResults() As Double) As Boolean
	GetChipInSocketAlignment = False
	
	Integer i, fileNum
	For i = 1 To 15
		CinSResults(i) = 0
	Next i
	fileNum = idx(1)

	JumpToSocket_camera(DAT_nr, socket_nr)
	
	UF_camera_light_ON
	Wait 0.2
'	String pict_fname$
'	pict_fname$ = DF_take_picture$(id$ + "_CS")
'    Print #fileNum, ",", pict_fname$,

	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + socket_nr
	CinSResults(1) = CX(P(FullSocket_nr)) ' Socket X
	CinSResults(2) = CY(P(FullSocket_nr)) ' Socket Y
	' CinSResults(3) = CU(P(FullSocket_nr)) ' Socket U
	CinSResults(3) = GetBoundAnglePM180(CU(P(FullSocket_nr)) + SocketMezzanineOrientation(CHIPTYPE_NR))

	Int32 Attempts
	Boolean Success
	Attempts = 20
	Success = False
	Print "Getting precise socket position"
	Do While ((Attempts > 0) And Not Success)
		If Not FindSocketDirectionWithDF Then
			'Print "Not found"
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR: Cannot find socket alignment"
		Exit Function
	EndIf

	' Get socket position	
	CinSResults(4) = SockPos(1) ' Socket X
	CinSResults(5) = SockPos(2) ' Socket Y
	CinSResults(6) = SockPos(3) ' Socket U

	Attempts = 20
	Success = False
	If CHIPTYPE$ = "ColdADC" And SITE$ = "LSU" Then
		LSUColdADCSockOcc = True
	EndIf
	Do While ((Attempts > 0) And Not Success)
		' TODO JW: Check chip dimensions are in range
		If Not FindChipDirectionWithDF Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	LSUColdADCSockOcc = False
	
	If Not Success Then
		Print "Cannot find chip alignment"
		Exit Function
	EndIf
	
	' Offset of socket from defined position 
	CinSResults(7) = CinSResults(4) - CinSResults(1)
	CinSResults(8) = CinSResults(5) - CinSResults(2)
	CinSResults(9) = DiffAnglePM180(CinSResults(3), CinSResults(6))
'	CinSResults(9) = CinSResults(6) - CinSResults(3)

	' Get chip position
	CinSResults(10) = ChipPos(1) ' Chip X
	CinSResults(11) = ChipPos(2) ' Chip Y
	CinSResults(12) = ChipPos(3) ' Chip U
		
	' Offsets from measured socket (for analysis)
	CinSResults(13) = ChipPos(1) - SockPos(1) ' Offset in X (Socket -> Chip)
	CinSResults(14) = ChipPos(2) - SockPos(2)   ' Offset in Y
	CinSResults(15) = DiffAnglePM180(SockPos(3), ChipPos(3)) ' ChipPos(3) - SockPos(3)  ' Offset in U (wrt mezzanine direction)
	
	GetChipInSocketAlignment = True
Fend

''' Socket alignment from DF camera
''' 
' DFSockRes(1) - defined X
' DFSockRes(2) - defined Y
' DFSockRes(3) - defined U

' DFSockRes(4) - measured X
' DFSockRes(5) - measured Y
' DFSockRes(6) - measured U

' DFSockRes(7) - Offset X
' DFSockRes(8) - Offset Y
' DFSockRes(9) - Offset U

' DFSockRes(10) - J4 offset at measured position

Function DFGetSocketAlignment(id$ As String, ByRef idx() As Integer, DAT_nr As Integer, socket_nr As Integer, ByRef DFSockRes() As Double) As Boolean

    SetSpeedSetting("PickAndPlace")
	' Maybe add check to see if already above socket or in sink
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + socket_nr

	' Reset results array
	Int32 i
	For i = 1 To 10
		DFSockRes(i) = 0.
	Next i
	
	DFSockRes(1) = CX(P(FullSocket_nr))
	DFSockRes(2) = CY(P(FullSocket_nr))
'	DFSockRes(3) = CU(P(FullSocket_nr))
	Print "PFullSocket_nr", DFSockRes(1), DFSockRes(2), CU(P(FullSocket_nr))
	
	DFSockRes(3) = GetBoundAnglePM180(CU(P(FullSocket_nr)) + SocketMezzanineOrientation(CHIPTYPE_NR))
	Print "DFSockRes(3)", DFSockRes(3)
	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
	Int32 Attempts
	Boolean Success
	Attempts = 20
	Success = False
	Print "Getting precise socket position"
	Do While ((Attempts > 0) And Not Success)
		If Not FindSocketDirectionWithDF Then
			'Print "Not found"
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR: Cannot find socket alignment"
		DFGetSocketAlignment = False
		Exit Function
	EndIf
	DFSockRes(4) = SockPos(1)
	DFSockRes(5) = SockPos(2)
    DFSockRes(6) = SockPos(3) + 180
	' Print any deviations between the socket position in camera and defined point
	' Offset = Measured - Expected
	DFSockRes(7) = DFSockRes(4) - DFSockRes(1) ' X
	DFSockRes(8) = DFSockRes(5) - DFSockRes(2) ' Y
    DFSockRes(9) = DiffAnglePM180(DFSockRes(3), DFSockRes(6)) 'DFSockRes(6) - DFSockRes(3) ' U
	
	Print Here
	Print "moving to (", DFSockRes(4), ",", DFSockRes(5), ",", DFSockRes(6), "),", DFSockRes(9)
	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DFSockRes(6))
'	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DFSockRes(3) + DFSockRes(9))
	DFSockRes(10) = CU(Here) - Agl(4)
	
	DFGetSocketAlignment = True
	
Fend

''' get the position and alignment of a chip in a tray position
''' Socket alignment from DF camera
'' Defined position
' DFTrayRes(1) - defined X
' DFTrayRes(2) - defined Y
' DFTrayRes(3) - defined U
' Measured position
' DFTrayRes(4) - measured X
' DFTrayRes(5) - measured Y
' DFTrayRes(6) - measured U
' Offsets 
' DFTrayRes(7) - Offset X
' DFTrayRes(8) - Offset Y
' DFTrayRes(9) - Offset U

' DFTrayRes(10) - J4 offset at measured position
Function DFGetTrayAlignment(id$ As String, ByRef idx() As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer, ByRef DFTrayRes() As Double) As Boolean

	' Reset results array
	Int32 i ', fileNum
	For i = 1 To 10
		DFTrayRes(i) = 0.
	Next i
	'fileNum = idx(1)

	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	
	' Take a picture of the chip in the tray
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
'	String pict_fname$
'	pict_fname$ = DF_take_picture$(id$ + "_CT")
'	Print #fileNum, ",", pict_fname$,
	
	DFTrayRes(1) = CX(Pallet(pallet_nr, col_nr, row_nr))
	DFTrayRes(2) = CY(Pallet(pallet_nr, col_nr, row_nr))
	'DFTrayRes(3) = CU(Pallet(pallet_nr, col_nr, row_nr))
	' Should (3) be the robot position or the expected chip position?
	DFTrayRes(3) = GetBoundAnglePM180(CU(Pallet(pallet_nr, col_nr, row_nr)) + TrayChipOrientation(pallet_nr))

	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	Do While ((Attempts > 0) And Not Success)
		' TODO JW: Check chip dimensions are in range
		If Not FindChipDirectionWithDF Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "Cannot find chip alignment"
		Exit Function
	EndIf
	
	Print "Chip found"
	DFTrayRes(4) = ChipPos(1)
	DFTrayRes(5) = ChipPos(2)
	DFTrayRes(6) = ChipPos(3)
	' Print any deviations between the socket position in camera and defined point
	' Offset = Measured - Expected
	DFTrayRes(7) = DFTrayRes(4) - DFTrayRes(1) ' X
	DFTrayRes(8) = DFTrayRes(5) - DFTrayRes(2) ' Y
	' DFTrayRes(9) =DFTrayRes(6) - DFTrayRes(3)
	DFTrayRes(9) = DiffAnglePM180(DFTrayRes(3), DFTrayRes(6)) ' B - A

	Go Here :X(DFTrayRes(4)) :Y(DFTrayRes(5))
	DFTrayRes(10) = CU(Here) - Agl(4)
	
	DFGetTrayAlignment = True
	
Fend

' Results index
'' Tool positions
' UFChipRes(1) - U_0 tool U when moved to camera
' UFChipRes(2) - U_1 tool U at first measurement
' UFChipRes(3) - U_2 tool U at second measurement
'''  First measurements
' UFChipRes(4) - x1
' UFChipRes(5) - y1
' UFChipRes(6) - u1
''' Second measurements
' UFChipRes(7) - x2
' UFChipRes(8) - y2
' UFChipRes(9) - u2
''' Caclulated offsets
' UFChipRes(10) - Offset in X ' FROM AXIS TO CHIP POSITION - PREVIOUSLY OTHER WAY AROUND 
' UFChipRes(11) - Offset in Y
' UFChipRes(12) - Offset in U 
' Previously took target hand U and chip alignment as args, now calculates alignment relative to U_0
' Can then use rotation and rotation matrix to calculate offsets at socket
' UFChipRes(13) - Pin analysis status
Function UFGetChipAlignment(id$ As String, ByRef idx() As Integer, ByRef UFChipRes() As Double, ByRef Images$() As String) As Boolean
    SetSpeedSetting("AboveCamera")
	UFGetChipAlignment = False
		
	Int32 i, fileNum
	For i = 1 To 13
		UFChipRes(i) = 0.
	Next i
	fileNum = idx(1)
	
	JumpToCamera
	Go Here :U(HAND_U0)
	Go Here +U(PickOffset)
	UFChipRes(1) = CU(Here)
	
	' If J4 angle is outside desired range, first add in extra rotation to prevent over turning
	Double Rotation1
	Rotation1 = 0.
	If (Agl(4) >= (REST_J4 - 45.)) And (Agl(4) <= (REST_J4 - 45.)) Then
		If (Agl(4) >= REST_J4) Then
			Rotation1 = -90.
		Else
			Rotation1 = 90.
		EndIf
	EndIf
	Go Here +U(Rotation1)
	
	UFChipRes(2) = CU(Here)
	
	
	'' TAKE PICTURE
	UF_camera_light_ON
	Wait 0.2
	'String pict_fname$
	'pict_fname$ = UF_take_picture$(id$ + "_01")
    ' Print #fileNum, ",", pict_fname$,
	Images$(1) = UF_take_picture$(id$ + "_01")
	' Take first measurements
	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	Do While ((Attempts > 0) And Not Success)
		If Not UF_CHIP_FIND Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR UF camera cannot find chip"
		Exit Function
	EndIf
	
	' Store first measurement values
	UFChipRes(4) = UFChipPos(1)
	UFChipRes(5) = UFChipPos(2)
	UFChipRes(6) = UFChipPos(3)
	
	If CHIPTYPE$ = "COLDATA" Then
		UFChipRes(6) = GetBoundAnglePM45(UFChipRes(6))
	EndIf
	
	' Rotate to 180 deg from first measurements
	Double Rotation2
	Rotation2 = 0.
	If (Agl(4) < REST_J4) Then
		Rotation2 = 180.
	Else
		Rotation2 = -180
	EndIf
	Go Here +U(Rotation2)
	
	UFChipRes(3) = CU(Here)
	
	' Take another picture
	UF_camera_light_ON
	Wait 0.2
	Images$(2) = UF_take_picture$(id$ + "_02")
	'pict_fname$ = UF_take_picture$(id$ + "_02")
    'Print #fileNum, ",", pict_fname$,
	
	Attempts = 20
	Success = False
	Do While ((Attempts > 0) And Not Success)
		If Not UF_CHIP_FIND Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR UF camera cannot find chip after 180 degree rotation"
		Exit Function
	EndIf

	' Store second measurement values
	UFChipRes(7) = UFChipPos(1)
	UFChipRes(8) = UFChipPos(2)
	UFChipRes(9) = UFChipPos(3)
	
	If CHIPTYPE$ = "COLDATA" Then
		UFChipRes(6) = GetBoundAnglePM180(GetBoundAnglePM45(UFChipRes(6)) + 180.)
	EndIf

	' Measurements have been made, return to initial U at camera
	' This should be same as U_0
	Go Here -U(Rotation1 + Rotation2)
	
'	Print "Chip position measured with UF camera. Starting from", UFChipRes(1)
'	Print "Rotate by ", Rotation1
'	Print "1st measurement at U=", UFChipRes(2)
'	Print "  x1: ", UFChipRes(4)
'	Print "  y1: ", UFChipRes(5)
'	Print "  u1: ", UFChipRes(6)
'	Print "Rotate by ", Rotation2
'	Print "2nd measurement at U=", UFChipRes(3)
'	Print "  x2: ", UFChipRes(7)
'	Print "  y2: ", UFChipRes(8)
'	Print "  u2: ", UFChipRes(9)
'	Print "Return U value by rotating by ", -(Rotation1 + Rotation2)
	
	' Correct for +90 degrees for first measurement by rotating -90
	
	Print "UF chip center measurements"
	Print "Rotation1 = ", Rotation1, ", Rotation2 = ", Rotation2
	Print "HAND U1 =", UFChipRes(2), ", HAND U2=", UFChipRes(3)
	Print "x1 = ", UFChipRes(4), "   x2 = ", UFChipRes(7)
	Print "y1 = ", UFChipRes(5), "   y2 = ", UFChipRes(8)
	Print "u1 = ", UFChipRes(6), "   u2 = ", UFChipRes(9)
	
	If (Abs(UFChipRes(4) - CX(P_camera)) > 10) Or (Abs(UFChipRes(7) - CX(P_camera)) > 10) Then
		Print "ERROR: Position measured is more than 10 mm from P_camera in X"
		Exit Function
	EndIf
	
	If (Abs(UFChipRes(5) - CY(P_camera)) > 10) Or (Abs(UFChipRes(8) - CY(P_camera)) > 10) Then
		Print "ERROR: Position measured is more than 10 mm from P_camera in Y"
		Exit Function
	EndIf
	
	' Set X and Y offsets as distance from axis of rotation to first measurement
	UFChipRes(10) = (UFChipRes(4) - UFChipRes(7)) / 2 ' X1 - X2 /2
	UFChipRes(11) = (UFChipRes(5) - UFChipRes(8)) / 2 ' Y1 - Y2 /2
	
	' X and Y offsets should be corrected for the first rotation offset to get back to HAND_U0
	' Maybe change so wrt U = 0?
'	UFChipRes(10) = UFChipRes(10) * Cos(DegToRad(-Rotation1)) - UFChipRes(11) * Sin(DegToRad(-Rotation1))
'	UFChipRes(11) = UFChipRes(10) * Sin(DegToRad(-Rotation1)) + UFChipRes(11) * Cos(DegToRad(-Rotation1))
	' Wrt U = 0
	UFChipRes(10) = UFChipRes(10) * Cos(DegToRad(-UFChipRes(2))) - UFChipRes(11) * Sin(DegToRad(-UFChipRes(2)))
	UFChipRes(11) = UFChipRes(10) * Sin(DegToRad(-UFChipRes(2))) + UFChipRes(11) * Cos(DegToRad(-UFChipRes(2)))

	Double UF_DEL_U1, UF_DEL_U2

	
	' DIff angle (a, b) is b - a
	UF_DEL_U1 = DiffAnglePM180(UFChipRes(2), UFChipRes(6))
	UF_DEL_U2 = DiffAnglePM180(UFChipRes(3), UFChipRes(9))
	
	If CHIPTYPE$ = "COLDATA" Then
		UF_DEL_U1 = GetBoundAnglePM45(UF_DEL_U1)
		UF_DEL_U2 = GetBoundAnglePM45(UF_DEL_U2)
	EndIf
	
	If Abs(UF_DEL_U2 - UF_DEL_U1) > 2. Then
		Print "WARNING: U offsets from UF measurements differ by more than +/- 2 deg"
		Print " 1st U offset = ", UF_DEL_U1
		Print " 2nd U offset = ", UF_DEL_U2
	EndIf
	
'	' Need to make sure average is closest angle around -pi/+pi boundary
	UFChipRes(12) = AverageAnglePM180(UF_DEL_U1, UF_DEL_U2) 'GetBoundAnglePM45(AverageAnglePM180(UF_DEL_U1, UF_DEL_U2))
	
	Print "Offset of chip from rotational axis wrt U = 0 " ' HAND_U0"
	Print "Offsets measured from a rotation of ", Rotation1
	Print "Offset in x axis : ", UFChipRes(10)
	Print "Offset in y axis : ", UFChipRes(11)
	Print "Offset in u1   	: ", UF_DEL_U1
	Print "Offset in u2   	: ", UF_DEL_U2
	Print "Offset in u   	: ", UFChipRes(12)

' Correction requires rotation based on U offset - This is when target U and chip rotation were provided
' This should now be done outside of this function
' Store DelX_1, DelY_1 and DelU_1
' Then for correction
' Phi = DelU_1 - DelU_2
' Del_X2_Phi = DelX_2 * Cos(Phi) - DelY_2 * Sin(Phi)
' Del_Y2_Phi = DelX_2 * Sin(Phi) + DelY_2 * Cos(Phi)
' Correction at U=HAND_U0
' CorrX_0 = Del_X1 - Del_X2_Phi
' CorrY_0 = Del_Y1 - Del_Y2_Phi
' These corrections should already take into account that you will rotate by phi but at HAND_U0, so
' So to get to correction at socket 
' CorrX_US = CorrX_0 * Cos(US - HAND_U0) - CorrY_0 * Sin(US - HAND_U0)
' CorrX_US = CorrX_0 * Cos(US - HAND_U0) - CorrY_0 * Sin(US - HAND_U0)
' CorrU = Phi
' So go to socket
' Correct for socket alignment wrt defined point
' Use measured socket U to calculate corrections
' Go Here +U(CorrU) +X(CorrX_US) +Y(CorrY_US)
'	
	' Do the pin analysis 
	UFRecenter(ByRef UFChipRes())
	' Commented out for testing (my test chip has a bent pin!)
'	UFChipRes(13) = UFPinAnalysis(id$, ByRef idx(), ByRef Images$())
	
	If UFChipRes(13) <> 0 Then
		Print "Pin analysis failed"
		UFGetChipAlignment = False
		Exit Function
	EndIf
	UFGetChipAlignment = True
    SetSpeedSetting("MoveWithChip")
	
Fend


' Takes measured alignments to U = 0 (Old wrt HAND_U0) and a target U and calculates corrections
' C1 -> C2
Function ChipToChipCorrections(C1X As Double, C1Y As Double, C1U As Double, C2X As Double, C2Y As Double, C2U As Double, TargetHandU As Double, ByRef Corr() As Double) As Int32
	
	' Note, the offsets calculated by UFGetChipAlignment were PREVIOUSLY (Before 2025-09-04) ChipPosition -> RotationalAxis
	' Now UFGetChipAlignmemt returns offset of chip from axis which can be subtracted to get the correction for an individual measurement
	' This function takes two sets of offsets and uses them to go from C1->C2, where the offsets are	
	' measured as C1 - Axis, not the other way around
	
	ChipToChipCorrections = -1
	Print "Calculating chip-to-chip correction from offset measurements (going from first measurement args to second)"
	Print "Targeting hand U of :", TargetHandU
	Corr(3) = C2U - C1U ' Corr(3) = DiffAnglePM180(C1U, C2U) ' Not sure this is working
	Print "Moving C1 to C2' by rotating by ", Corr(3)
	

	
	' Rotate C1 corrections by phi around axis of rotation
	' Then get difference to C2 wrt axis
	Corr(1) = C2X - (C1X * Cos(DegToRad(Corr(3))) - C1Y * Sin(DegToRad(Corr(3))))
	Corr(2) = C2Y - (C1X * Sin(DegToRad(Corr(3))) + C1Y * Cos(DegToRad(Corr(3))))
	
	' Now rotate corrections wrt axis to the target U value
'	Corr(1) = Corr(1) * Cos(DegToRad(TargetHandU - HAND_U0)) - Corr(2) * Sin(DegToRad(TargetHandU - HAND_U0))
'	Corr(2) = Corr(1) * Sin(DegToRad(TargetHandU - HAND_U0)) + Corr(2) * Cos(DegToRad(TargetHandU - HAND_U0))
'	
	Corr(1) = Corr(1) * Cos(DegToRad(TargetHandU)) - Corr(2) * Sin(DegToRad(TargetHandU))
	Corr(2) = Corr(1) * Sin(DegToRad(TargetHandU)) + Corr(2) * Cos(DegToRad(TargetHandU))
	
	Print "Offset X1 :", C1X
	Print "Offset X1':", ((C1X * Cos(DegToRad(Corr(3))) - C1Y * Sin(DegToRad(Corr(3)))))
	Print "Offset X2 :", C2X
	Print "Correction:", Corr(1)
	
	Print "Offset Y1 :", C1Y
	Print "Offset Y1':", ((C1X * Sin(DegToRad(Corr(3))) + C1Y * Cos(DegToRad(Corr(3)))))
	Print "Offset Y2 :", C2Y
	Print "Correction:", Corr(2)
	
	Print "Offset U1 :", C1U
	Print "Offset U2 :", C2U
	Print "Correction:", Corr(3)
	
	ChipToChipCorrections = 0
Fend


''''' FNAL FUNCTIONS ''''''

Function COLDATA_VisAnalysis(ByRef corrections() As Double) As Integer
	' Uses the upward facing camera to find the offset of the EOAT center of rotation
	' and the chip center. Assumes the EOAT is currently holding a chip, it uses COLDATA_Corrs
	' to find the chip center, then rotates it 180 degrees at runs it again. The difference
	' in the center positions results in the offset of the EOAT center and chip center.
	
	Print "COLDATA_VisAnalysis start: ", Here
	
	' Turn the EOAT light on for better pictures of chip	
	On 12
	
	' Run the vision sequence to find the chip center
	VRun COLDATA_Corrs
	
	' Save the initial center position of the chip
	Double X_0, Y_0, U_0
	VGet COLDATA_Corrs.FindChip.CameraX, X_0
	VGet COLDATA_Corrs.FindChip.CameraY, Y_0
	VGet COLDATA_Corrs.FindChip.Angle, U_0
	
	Print "X, Y, U: ", X_0, Y_0, U_0
	
	' Rotate 180 degrees
	Go Here +U(180)
	
	' Fine the new center of the chip after rotation
	VRun COLDATA_Corrs
	
	' Save the new center position of the chip after rotation
	Double X_180, Y_180, U_180
	VGet COLDATA_Corrs.FindChip.CameraX, X_180
	VGet COLDATA_Corrs.FindChip.CameraY, Y_180
	VGet COLDATA_Corrs.FindChip.Angle, U_180
	
	Print "X2, Y2, U2: ", X_180, Y_180, U_180
	
	' Calculate the center of the tool (EAOT)
	Double X_tool, Y_tool
	X_tool = 0.5 * (X_0 + X_180)
	Y_tool = 0.5 * (Y_0 + Y_180)
	
	' Calculate the correction to center the chip
	Double X_COR, Y_COR
	X_COR = 0.5 * (X_0 - X_180)
	Y_COR = 0.5 * (Y_0 - Y_180)
	Print "X_COR, YCOR: ", X_COR, Y_COR
	
	' Rotate back to initial position
	Go Here -U(180)
	
	' Turn the light off
	Off 12
	
	' Save corrections
	corrections(1) = X_COR
	corrections(2) = Y_COR
	'corrections(3) = 0 'U_COR
	
Fend

Function GetTrayCorrection(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	' This functions picks up a chip, runs the vision sequence to get the corrections	
	' needed, so that a new tray/site can collect the initial chip correction information.
	' This function would need to be used on each chip position before using the functions
	' MoveChipFromTrayToSocket or MoveChipFromSocketToTray
	
	' Jump to the given tray position
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	' Attempt to pickup chip from tray, exit function if it fails
	If Not PickupFromTray Then
		Print "Can't pickup chip from socket"
		Exit Function
	EndIf
	
	' Move to the upward facing camera for corrections
	Jump P_Camera
	Wait 1
	
	' Run the calibration sequence and save the correction results
	Double corrs(2)
	Double res(3)
	Integer status
	
	If CHIPTYPE$ = "COLDATA" Then
		status = COLDATA_VisAnalysis(ByRef corrs())
	Else
		Print "ERROR: Not implemented for other chip types yet"
		Exit Function
	EndIf
		
	
	Print "Previous tray corr:", tray_X(pallet_nr, col_nr, row_nr), tray_Y(pallet_nr, col_nr, row_nr)
	Print "New corrections:", corrs(1), corrs(2)
	
	' Grab corrections from camera calibration
	Double X_CORR_tray, Y_CORR_tray
	X_CORR_tray = corrs(1)
	Y_CORR_tray = corrs(2)
	
	' Save/update the tray position corrections
	tray_X(pallet_nr, col_nr, row_nr) = X_CORR_tray
	tray_Y(pallet_nr, col_nr, row_nr) = Y_CORR_tray
	
	' Jump to the given tray position
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	DropToTray
	
Fend

Function GetAllTrayCorrections(pallet_nr As Integer)
	' This function runs GetTrayCorrection for all chips in a tray,
	' in order to fill the tray_xyu.csv files initially. This should
	' only be needed the first time and whenever the tray_xyu.csv
	' file is reset. 
	
	Integer i, j
	For i = 1 To TRAY_NCOLS
		For j = 1 To TRAY_NROWS
			GetTrayCorrection(pallet_nr, i, j)
		Next j
	Next i
	
Fend

