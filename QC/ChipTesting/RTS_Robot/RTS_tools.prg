#include "RTS_tools.inc"

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

Function SetSpeed
	Power Low
	Speed 100
	Accel 10, 10
	Speed 1
	Accel 1, 1
Fend

Function SetSpeedSetting(Setting$ As String)
	Power Low
	Speed 100
	Accel 10, 10
	Speed 1
	Accel 1, 1
	
	' Currently keeping non MSU speeds low until enclosures are shipped/higher speeds are allowed by safety
	If SITE$ <> "MSU" Then
		Exit Function
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
			Speed 1
			Accel 1, 1
	Send

Fend


Function MoveFromPointToImage(dU As Double, RotateFirst As Boolean)
	' Move arm from stinger at point, to chip in focus with some rotation in degrees
	' Remember point is defined as some offset (10mm from contact)
	' RotateFirst decides if rotation comes before or after translation in XY
	' Which may be important to avoid collision
	Move Here +Z(DF_CAM_Z_OFF)
	If RotateFirst Then
		Go Here +U(dU)
		Move Here +X(XOffset(CU(Here))) +Y(YOffset(CU(Here)))
	Else
		Move Here +X(XOffset(CU(Here) + dU)) +Y(YOffset(CU(Here) + dU))
		Go Here +U(dU)
	EndIf
	
Fend

Function MoveFromImageToPoint(dU As Double, RotateFirst As Boolean)
	' Inverse of above function, note rotation is not inverted like other offsets
	' And order of operations may need to be reversed if this matters for collisions
	' (Rotations should happen in same XY position)
	' e.g. MoveFromImageToPoint(-45,1) is inverse of MoveFromPointToImage(45,0)
	If RotateFirst Then
		Go Here +U(dU)
		Move Here -X(XOffset(CU(Here) - dU)) -Y(YOffset(CU(Here) - dU))
	Else
		Move Here -X(XOffset(CU(Here))) -Y(YOffset(CU(Here)))
		Go Here +U(dU)
	EndIf
	Move Here -Z(DF_CAM_Z_OFF)
	
Fend

' Jump to camera
' Preserve U rotation
Function JumpToCamera
	
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
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT

		ElseIf pallet_nr = 2 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT

		EndIf

	Else
		If pallet_nr = 1 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT

		ElseIf pallet_nr = 2 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0 + 180)) +Y(YOffset(HAND_U0 + 180)) +Z(DF_CAM_Z_OFF) :U(HAND_U0 + 180) LimZ JUMP_LIMIT

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
	
Fend


Function isChipInTrayCamera(pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Boolean

	isChipInTrayCamera = False
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	Integer Attempts
	Attempts = 5
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
'	SetSpeedSetting("")
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
	Attempts = 5
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

'	Speed 1
'	Accel 1, 1
'    Go Here -Z(12) Till Sw(8) = On Or Sw(9) = Off
'    Wait 0.5
'	isChipInSocket = isContactSensorTouches
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	isChipInSocketTouch = TouchSuccess

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
	
'	PlungerOn
'	Wait 1
'	Go Here -Z(10)


    SetSpeedSetting("PickAndPlace")

	PlungerOn

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
	
	Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) LimZ JUMP_LIMIT
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
Function ChipBottomAnaly(id$ As String, ByRef idx() As Integer, ByRef res() As Double) As Integer

	Integer i, fileNum
	
	ChipBottomAnaly = 0

	' reset the array of results
	For i = 1 To 30
		res(i) = 0
	Next i
	fileNum = idx(1)
	
	' sources and targets of the chip
	Integer src_pallet_nr, src_col_nr, src_row_nr, src_DAT_nr, src_socket_nr
	Integer tgt_pallet_nr, tgt_col_nr, tgt_row_nr, tgt_DAT_nr, tgt_socket_nr
	
	fileNum = idx(1)
	src_pallet_nr = idx(2)
	src_col_nr = idx(3)
	src_row_nr = idx(4)
	tgt_pallet_nr = idx(5)
	tgt_col_nr = idx(6)
	tgt_row_nr = idx(7)

	src_DAT_nr = idx(8)
	src_socket_nr = idx(9)
	tgt_DAT_nr = idx(10)
	tgt_socket_nr = idx(11)
			
	'If tgt_DAT_nr = 1 Then
	'	ChipBottomAnaly = 10
	'	Print "***ERROR Functionality for DAT board 1 not implemented yet", 10
    '    Exit Function
	'EndIf
		
	' target position at the camera
	Double tgt_x0, tgt_y0, tgt_u0
	' hand rotation at destination
	Double dst_U
	If tgt_pallet_nr > 0 And tgt_pallet_nr <= NTRAYS And tgt_col_nr > 0 And tgt_col_nr <= TRAY_NCOLS And tgt_row_nr > 0 And tgt_row_nr <= TRAY_NROWS Then
		tgt_x0 = tray_X(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
		tgt_y0 = tray_Y(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
		tgt_u0 = tray_U(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
		dst_U = CU(Pallet(tgt_pallet_nr, tgt_col_nr, tgt_row_nr))
	ElseIf tgt_DAT_nr > 0 And tgt_DAT_nr <= 2 And tgt_socket_nr > 0 And tgt_socket_nr <= NSOCKETS Then
		tgt_x0 = DAT_X(tgt_DAT_nr, tgt_socket_nr)
		tgt_y0 = DAT_Y(tgt_DAT_nr, tgt_socket_nr)
		tgt_u0 = DAT_U(tgt_DAT_nr, tgt_socket_nr)
		dst_U = CU(P(100 * tgt_DAT_nr + tgt_socket_nr))
	Else
		ChipBottomAnaly = 100
		Exit Function
	EndIf
	
	
       'JW:
   If Agl(4) < -45. Then
           Go Here +U(180)
'      ElseIf Agl(4) < 0. Then
'              Go Here +U(135)
'              Go Here -U(180)
'              Go Here +U(45)
   ElseIf Agl(4) <= 45. Then
           Go Here +U(90)
   Else
           Go Here -U(180)
   EndIf
	
	
	UF_camera_light_ON
	Wait 0.2
	String pict_fname$
	'UF_take_picture(chip_SN$, ByRef pict_fname_0$)
	pict_fname$ = UF_take_picture$(id$ + "_01")
    Print #fileNum, ",", pict_fname$,
	
	'Double tray_dx, tray_dy, tray_dU
	VRun ChipBottom_Analy

	Boolean ret_found
	Double camera_X, camera_Y
	Double X_0, Y_0, U_0
	Double X_180, Y_180, U_180
	Double X_tool, Y_tool

	'VGet ChipBottom_Analy.Final.RobotXYU, ret_found, ret_X, ret_Y, ret_U
	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then

		VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
		VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
			
		VGet ChipBottom_Analy.Final.CameraX, X_0
		VGet ChipBottom_Analy.Final.CameraY, Y_0
		VGet ChipBottom_Analy.Final.Angle, U_0

		Print #fileNum, ",", ret_found,
		Print #fileNum, ",", camera_X, ",", camera_Y,
		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
		
		res(1) = camera_X
		res(2) = camera_Y
		
		res(3) = X_0
		res(4) = Y_0
		res(5) = U_0

	Else
		
		ChipBottomAnaly = 1
		Print "***ERROR ", 1
        Exit Function
		
	EndIf

	' Repeat measurement for 180 deg. rotation
'	If CU(Here) < 235 Then
'		Go Here +U(180)
'	Else
'		Go Here -U(180)
'	EndIf

'      JW:
	If Agl(4) <= 45. Then
	    Go Here -U(180)
    Else
        Go Here +U(180)
    EndIf

	Wait 0.2
	'UF_take_picture(chip_SN$ + "-180", ByRef pict_fname_180$)
	'UF_take_picture(ByRef pict_fname$)
	pict_fname$ = UF_take_picture$(id$ + "_02")
	Print #fileNum, ",", pict_fname$,

	VRun ChipBottom_Analy
	
	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then
		
		VGet ChipBottom_Analy.Final.CameraX, X_180
		VGet ChipBottom_Analy.Final.CameraY, Y_180
		VGet ChipBottom_Analy.Final.Angle, U_180

		Print #fileNum, ",", ret_found,
		Print #fileNum, ",", X_180, ",", Y_180, ",", U_180,

		res(6) = X_180
		res(7) = Y_180
		res(8) = U_180

		X_tool = 0.5 * (X_0 + X_180)
		Y_tool = 0.5 * (Y_0 + Y_180)

		res(9) = X_tool
		res(10) = Y_tool

		Print #fileNum, ",", X_tool, ",", Y_tool,

		' chip position relative to the tool
		res(11) = X_0 - X_tool
		res(12) = Y_0 - Y_tool

		Print #fileNum, ",", res(11), ",", res(12),

		' record the chip position from the source
		Double src_x0, src_y0, src_u0
		' source: 1 - pallet, 2 - socket
		Integer src
		If src_pallet_nr > 0 And src_pallet_nr <= NTRAYS And src_col_nr > 0 And src_col_nr <= TRAY_NCOLS And src_row_nr > 0 And src_row_nr <= TRAY_NROWS Then
			src_x0 = tray_X(src_pallet_nr, src_col_nr, src_row_nr)
			src_y0 = tray_Y(src_pallet_nr, src_col_nr, src_row_nr)
			src_u0 = tray_U(src_pallet_nr, src_col_nr, src_row_nr)
			src = 1
		ElseIf src_DAT_nr > 0 And src_DAT_nr <= 2 And src_socket_nr > 0 And src_socket_nr <= NSOCKETS Then
			src_x0 = DAT_X(src_DAT_nr, src_socket_nr)
			src_y0 = DAT_Y(src_DAT_nr, src_socket_nr)
			src_u0 = DAT_U(src_DAT_nr, src_socket_nr)
			src = 2
		Else
			ChipBottomAnaly = 101
			Exit Function
		EndIf

		If src_x0 = 0 And src_y0 = 0 And src_u0 = 0 Then
			Print "Recording position of the source: ", res(11), " ", res(12), " ", U_0
			If src = 1 Then
				tray_X(src_pallet_nr, src_col_nr, src_row_nr) = res(11)
				tray_Y(src_pallet_nr, src_col_nr, src_row_nr) = res(12)
				tray_U(src_pallet_nr, src_col_nr, src_row_nr) = U_0
			ElseIf src = 2 Then
				DAT_X(src_DAT_nr, src_socket_nr) = res(11)
				DAT_Y(src_DAT_nr, src_socket_nr) = res(12)
				DAT_U(src_DAT_nr, src_socket_nr) = U_0
			Else
				ChipBottomAnaly = 102
				Exit Function
			EndIf
		EndIf

	Else

		ChipBottomAnaly = 2
		Print "***Error ", 2
        Exit Function
	EndIf
	
    ' JW: need to correct the cases where you do +90, then -180 then +90
         ' Other angles just do +180, then -180 or vice versa
	If Agl(4) > -45. And Agl(4) <= 45. Then
		Go Here +U(90)
	EndIf


	' Change handeness to the target 
	If tgt_pallet_nr = 1 Or tgt_DAT_nr = 1 Then
    	Jump P_camera :U(dst_U) /R LimZ JUMP_LIMIT
    ElseIf tgt_pallet_nr = 2 Or tgt_DAT_nr = 2 Then
    	Jump P_camera :U(dst_U) /L LimZ JUMP_LIMIT
    EndIf
	

	' Rotate the hand to destination orientation Update: Done in a previous step
	'Go Here :U(dst_U)
	Wait 0.2

	' Added 2024-06-18
	' Re-evaluate the position of the tool
	VRun ChipBottom_Analy

	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then

		'VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
		'VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
			
		VGet ChipBottom_Analy.Final.CameraX, X_0
		VGet ChipBottom_Analy.Final.CameraY, Y_0
		VGet ChipBottom_Analy.Final.Angle, U_0

		Print #fileNum, ",", ret_found,
		'Print #fileNum, ",", camera_X, ",", camera_Y,
		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
		
		'res(1) = camera_X
		'res(2) = camera_Y
		
		'res(3) = X_0
		'res(4) = Y_0
		'res(5) = U_0

	Else
		
		ChipBottomAnaly = 301
		Print "***ERROR ", 301
        Exit Function
		
	EndIf

	' Repeat measurement for 180 deg. rotation
	'If CU(Here) < 180 Then
	
	'If Hand < 1.5 Then ' 1 for right handed, 2 for left handed.
		Go Here +U(180)
	'Else
	'	Go Here -U(180)
	'EndIf
	Wait 0.2
	'UF_take_picture(chip_SN$ + "-180", ByRef pict_fname_180$)
	'UF_take_picture(ByRef pict_fname$)
	'pict_fname$ = UF_take_picture$(id$ + "_02")
	'Print #fileNum, ",", pict_fname$,

	VRun ChipBottom_Analy
	
	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then
		
		VGet ChipBottom_Analy.Final.CameraX, X_180
		VGet ChipBottom_Analy.Final.CameraY, Y_180
		VGet ChipBottom_Analy.Final.Angle, U_180

		Print #fileNum, ",", ret_found,
		Print #fileNum, ",", X_180, ",", Y_180, ",", U_180,

		'res(6) = X_180
		'res(7) = Y_180
		'res(8) = U_180

		X_tool = 0.5 * (X_0 + X_180)
		Y_tool = 0.5 * (Y_0 + Y_180)

		res(9) = X_tool
		res(10) = Y_tool

		Print #fileNum, ",", X_tool, ",", Y_tool,

		Print "Tool position: X=", X_tool, ", Y=", Y_tool

		' chip position relative to the tool
		res(11) = X_0 - X_tool
		res(12) = Y_0 - Y_tool

		Print #fileNum, ",", res(11), ",", res(12),

		' record the chip position from the source
		'Double src_x0, src_y0, src_u0
		'' source: 1 - pallet, 2 - socket
		'Integer src
		'If src_pallet_nr > 0 And src_pallet_nr <= NTRAYS And src_col_nr > 0 And src_col_nr <= TRAY_NCOLS And src_row_nr > 0 And src_row_nr <= TRAY_NROWS Then
		'	src_x0 = tray_X(src_pallet_nr, src_col_nr, src_row_nr)
		'	src_y0 = tray_Y(src_pallet_nr, src_col_nr, src_row_nr)
		'	src_u0 = tray_U(src_pallet_nr, src_col_nr, src_row_nr)
		'	src = 1
		'ElseIf src_DAT_nr > 0 And src_DAT_nr <= 2 And src_socket_nr > 0 And src_socket_nr <= NSOCKETS Then
	'		src_x0 = DAT_X(src_DAT_nr, src_socket_nr)
	'		src_y0 = DAT_Y(src_DAT_nr, src_socket_nr)
	'		src_u0 = DAT_U(src_DAT_nr, src_socket_nr)
	'		src = 2
	'	Else
	'		ChipBottomAnaly = 101
	'		Exit Function
	'	EndIf

	'	If src_x0 = 0 And src_y0 = 0 And src_u0 = 0 Then
	'		Print "Recording position of the source: ", res(11), " ", res(12), " ", U_0
	'		If src = 1 Then
	'			tray_X(src_pallet_nr, src_col_nr, src_row_nr) = res(11)
	'			tray_Y(src_pallet_nr, src_col_nr, src_row_nr) = res(12)
	'			tray_U(src_pallet_nr, src_col_nr, src_row_nr) = U_0
	'		ElseIf src = 2 Then
	'			DAT_X(src_DAT_nr, src_socket_nr) = res(11)
	'			DAT_Y(src_DAT_nr, src_socket_nr) = res(12)
	'			DAT_U(src_DAT_nr, src_socket_nr) = U_0
	'		Else
	'			ChipBottomAnaly = 102
	'			Exit Function
	'		EndIf
	'	EndIf

	Else

		ChipBottomAnaly = 302
		Print "***Error ", 302
        Exit Function
			
	EndIf


	' End of code added on 2024-06-18

	' re-evaluate chip position with the rotation at destination
	Go Here :U(dst_U)
	Wait 0.2

	'UF_take_picture(ByRef pict_fname$)
	pict_fname$ = UF_take_picture$(id$ + "_03")
	Print #fileNum, ",", pict_fname$,

	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then
			
		VGet ChipBottom_Analy.Final.CameraX, X_0
		VGet ChipBottom_Analy.Final.CameraY, Y_0
		VGet ChipBottom_Analy.Final.Angle, U_0

		Print #fileNum, ",", ret_found,
		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
				
		res(13) = X_0
		res(14) = Y_0
		res(15) = U_0

	Else
		
		ChipBottomAnaly = 3
		Print "***ERROR ", 3
        Exit Function
		
	EndIf


	Double d_U
	'd_U = U_0 + 0.2
	'd_U = U_0 - tgt_u0
	d_U = tgt_u0 - U_0
	res(16) = d_U
	If Abs(d_U) < 2.0 Then
		Go Here -U(d_U)
	Else
		ChipBottomAnaly = 4
		Print "ERROR 4! : Rotation angle outside of control margin"
		Exit Function
	EndIf

	' Remeasure X and Y with correct rotation
	Wait 0.2
	'UF_take_picture(ByRef pict_fname$)
	pict_fname$ = UF_take_picture$(id$ + "_04")
	Print #fileNum, ",", pict_fname$,
	
	VRun ChipBottom_Analy
		
	VGet ChipBottom_Analy.Final.Found, ret_found
	If ret_found Then
			
		VGet ChipBottom_Analy.Final.CameraX, X_0
		VGet ChipBottom_Analy.Final.CameraY, Y_0
		VGet ChipBottom_Analy.Final.Angle, U_0

		Print #fileNum, ",", ret_found,
		Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,

		res(17) = X_0
		res(18) = Y_0
		res(19) = U_0

	Else
		
		ChipBottomAnaly = 5
		Print "***ERROR ", 5
        Exit Function
			
	EndIf

	Double d_X, d_Y
	d_X = tgt_x0 - (X_0 - X_tool)
	d_Y = tgt_y0 - (Y_0 - Y_tool)
	
	Print #fileNum, ",", d_X, ",", d_Y, ",", d_U,

	res(20) = d_X
	res(21) = d_Y


	' Analysis of pins
	d_X = X_0 - X_tool
	d_Y = Y_0 - Y_tool
	If Abs(d_X) < 1 And Abs(d_Y) < 1 And Abs(U_0) < 2 Then
		Print "Positioning the chip for pin analysis: ",
		Print " dX=", d_X, " dY=", d_Y, " dU=", U_0
		Go Here -X(d_X) -Y(d_Y) +U(U_0)
	Else
		ChipBottomAnaly = 6
		Print "***ERROR ", 6
        Exit Function
	EndIf

	pict_fname$ = UF_take_picture$(id$ + "_pins")
	Print #fileNum, ",", pict_fname$,
	VSet pins_analy.ImageFile, pict_fname$
	
	Integer status
	status = PinsAnaly(id$)
	Print #fileNum, ",", status,
	If status <> 0 Then
		ChipBottomAnaly = status
	EndIf
		
	' Analysis of chip key for insertion into socket
	Boolean res_1, res_2, res_3, res_4
	If tgt_DAT_nr = 1 Then
		Print "Checking ASIC key"
		VSet key_check_1.ImageFile, pict_fname$
		VRun key_check_1
		
		VGet key_check_1.Blob01.Found, res_1
		VGet key_check_1.Blob02.Found, res_2
		VGet key_check_1.Blob03.Found, res_3
		VGet key_check_1.Blob04.Found, res_4
		
		If Not (res_1 And (Not res_2) And res_3 And res_4) Then
			Print "***ERROR! Failed to determine the key position of the ASIC"
			ChipBottomAnaly = 7
			Exit Function
		EndIf
	ElseIf tgt_DAT_nr = 2 Then
		Print "Checking ASIC key"
		VSet key_check.ImageFile, pict_fname$
		VRun key_check
		
		VGet key_check.Blob01.Found, res_1
		VGet key_check.Blob02.Found, res_2
		VGet key_check.Blob03.Found, res_3
		VGet key_check.Blob04.Found, res_4
		
		If Not (res_1 And res_2 And res_3 And (Not res_4)) Then
			Print "***ERROR! Failed to determine the key position of the ASIC"
			ChipBottomAnaly = 7
			Exit Function
		EndIf
	EndIf

	UF_camera_light_OFF
	
Fend

Function PinsRowAnaly(name$ As String, fileNum As Integer) As Integer
	
	PinsRowAnaly = 0
	
	Boolean passed
	Integer nFound, i
	Double x, y, area, xold, yold
		
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
	Print #fileNum, " "
	
Fend


Function PinsAnaly(id$ As String) As Integer
	
	PinsAnaly = 0
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\pins\" + id$ + "_pins.csv" As #fileNum
		
	
	VRun pins_analy
	
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
Function RTS_error(fileNum AsInteger, err_msg$ As String)
	Print "***ERROR! ", err_msg$
	Print #fileNum, "***ERROR! ", err_msg$
	Close #fileNum
Fend


'
' INPUT: 
'        pallet_nr - pallet number of the chip source (1-left, 2-right)
'        col_nr - column number in the pallet (1-15)
'        row_nr - row number in the pallet (1-6)
'        DAT_nr - DAT board target (1-left, 2-right)
'        socket_nr - socket target (1-8)
'
' RETURN:
'        > 0 - job_id (timestamp)
'        < 0 - Error id



Function MoveChipFromTrayToTypeSocket(pallet_nr As Integer, col_nr As Integer, row_nr As Integer, DAT_nr As Integer, chip_type As Integer, socket_nr As Integer) As Int64
	 Integer soc_nr
	 soc_nr = socket_nr + 10 * chip_type
	 MoveChipFromTrayToSocket(pallet_nr, col_nr, row_nr, DAT_nr, soc_nr)
Fend

Function MoveChipFromTrayToSocket(DAT_nr As Integer, socket_nr As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Int64
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	MoveChipFromTrayToSocket = Val(ts$)

	SetSpeedSetting("")
	
	String fname$
	fname$ = "manip.csv"
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
	
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
	

	idx(2) = pallet_nr
	idx(3) = col_nr
	idx(4) = row_nr
	idx(5) = 0
	idx(6) = 0
	idx(7) = 0
	idx(8) = 0
	idx(9) = 0
	idx(10) = DAT_nr
	idx(11) = socket_nr
			
	'String d$, t$
 	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", pallet_nr, ",", col_nr, ",", row_nr,
	' pallet target
	Print #fileNum, ",", 0, ",", 0, ",", 0,
	' socket source
	Print #fileNum, ",", 0, ",", 0,
	' socket target
	Print #fileNum, ",", DAT_nr, ",", socket_nr,

	' Ensure that there is no chip in the socket

	'If isChipInSocketTouch(DAT_nr, socket_nr) Then
	'	RTS_error(fileNum, "Chip exists in the socket")
	'	Go Here :Z(-10)
    '    MoveChipFromTrayToSocket = -200
	'	Exit Function
	'EndIf


	' Take a picture of the chip in the tray
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	String pict_fname$
	pict_fname$ = DF_take_picture$(ts$ + "_SN")
	Print #fileNum, ",", pict_fname$,

	'Print #fileNum, ",", chip_SN$,
	
	If Not isPressureOk Then
		RTS_error(fileNum, "Bad pressure")
        MoveChipFromTrayToSocket = -2
		Exit Function
	EndIf
				
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum")
        MoveChipFromTrayToSocket = -3
		Exit Function
	EndIf
		
				
	JumpToTray(pallet_nr, col_nr, row_nr)

	If Not PickupFromTray Then
		RTS_error(fileNum, "Can't pickup a chip from tray ")
        MoveChipFromTrayToSocket = -4
		Exit Function
	EndIf
		

	' Take picture of the bottom of the chip
	Jump P_camera 'JumpToCamera
		
	Integer status
	Double corrs(2)
'	If ChipType$ = "COLDATA" Then
'		status = COLDATA_VisAnalysis(ByRef corrs())
'	Else
		status = ChipBottomAnaly(ts$, ByRef idx(), ByRef res())
'	EndIf

	If status <> 0 Then
		RTS_error(fileNum, "Analysis of chip bottom failed. Error = " + Str$(status))
        MoveChipFromTrayToSocket = -5
		Exit Function
	EndIf
	
	' Move to socket	
	JumpToSocket(DAT_nr, socket_nr)
	Wait 0.3
	

	Double X_CORR_tray, Y_CORR_tray, U_CORR_tray
	If ChipType$ = "COLDATA" Then
		X_CORR_tray = corrs(1)
		Y_CORR_tray = corrs(2)
		U_CORR_tray = 0
	Else
		X_CORR_tray = res(20)
		Y_CORR_tray = res(21)
		U_CORR_tray = res(16)
	EndIf
	
	Print "Correcting chip position from tray: ",
	Print " dX = ", X_CORR_tray, " dY = ", Y_CORR_tray, " dU = ", U_CORR_tray
	
	' Save/update the socket position corrections
	tray_X(pallet_nr, col_nr, row_nr) = X_CORR_tray
	tray_Y(pallet_nr, col_nr, row_nr) = Y_CORR_tray
	tray_U(pallet_nr, col_nr, row_nr) = U_CORR_tray
	
	' Grab the socket position corrections 
	Double X_CORR_socket, Y_CORR_socket, U_CORR_socket
	X_CORR_socket = DAT_X(DAT_nr, socket_nr)
	Y_CORR_socket = DAT_Y(DAT_nr, socket_nr)
	U_CORR_socket = 0
	Print "Saved socket corrections:", X_CORR_socket, Y_CORR_socket
	
	' Note: Corrections for socket are in the same frame
	Double d_X, d_Y, d_U
	d_X = X_CORR_tray - X_CORR_socket
	d_Y = Y_CORR_tray - Y_CORR_socket
	d_U = U_CORR_tray - U_CORR_socket
	
	' correct position
	Print "Correcting chip position for socket: ",
	Print " dX = ", d_X, " dY = ", d_Y, " dU = ", d_U
	If Abs(d_X) < 15 And Abs(d_Y) < 15 And Abs(d_U) < 20 Then
		Go Here -X(d_X) -Y(d_Y) -U(d_U)
		InsertIntoSocketSoft
	Else
		RTS_error(fileNum, "Chip position out of limits")
        MoveChipFromTrayToSocket = -6
        Exit Function
	EndIf
	
	
	' Take picture of chip in the socket
	JumpToSocket_camera(DAT_nr, socket_nr)
	pict_fname$ = DF_take_picture$(ts$ + "_socket")
	Print #fileNum, ",", pict_fname$,
				
	Print #fileNum, " "
	
	Close #fileNum

Fend

Function MoveChipFromTypeSocketToTray(pallet_nr As Integer, col_nr As Integer, row_nr As Integer, DAT_nr As Integer, chip_type As Integer, socket_nr As Integer) As Int64
	 Integer soc_nr
	 soc_nr = socket_nr + 10 * chip_type
	 MoveChipFromSocketToTray(pallet_nr, col_nr, row_nr, DAT_nr, soc_nr)
Fend


Function MoveChipFromSocketToTray(DAT_nr As Integer, socket_nr As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Int64
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	MoveChipFromSocketToTray = Val(ts$)

	SetSpeedSetting("MoveWithoutChip")
	
	String fname$
	fname$ = "manip.csv"
		
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
		
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
		
	' new CSV entry - pickup from socket and return to tray
		
	idx(2) = 0
	idx(3) = 0
	idx(4) = 0
	idx(5) = pallet_nr
	idx(6) = col_nr
	idx(7) = row_nr
	idx(8) = DAT_nr
	idx(9) = socket_nr
	idx(10) = 0
	idx(11) = 0
	
	'String d$, t$
	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", 0, ",", 0, ",", 0,
	' pallet target
	Print #fileNum, ",", pallet_nr, ",", col_nr, ",", row_nr,
	' socket source
	Print #fileNum, ",", DAT_nr, ",", socket_nr,
	' socket target
	Print #fileNum, ",", 0, ",", 0,

	' Ensure that there is no chip in destination	

	'If isChipInTrayTouch(pallet_nr, col_nr, row_nr) Then
	'	RTS_error(fileNum, "Chip exists in the destination ")
	'	Go Here :Z(-10)
	'	MoveChipFromSocketToTray = -200
	'	Exit Function
	'EndIf


	' Take picture of chip in the socket
	JumpToSocket_camera(DAT_nr, socket_nr)
	String pict_fname$
	pict_fname$ = DF_take_picture$(ts$ + "_socket")
	Print #fileNum, ",", pict_fname$,
	'DF_take_picture_socket(socket_nr, ByRef pict_fname_socket$)
	'Print #fileNum, ",", pict_fname_socket$,

	'Print #fileNum, ",", chip_SN$,
		
	If Not isPressureOk Then
		RTS_error(fileNum, "Bad pressure")
        MoveChipFromSocketToTray = -2
		Exit Function
	EndIf
				
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum")
        MoveChipFromSocketToTray = -3
		Exit Function
	EndIf
		
	' Pickup from socket
	JumpToSocket(DAT_nr, socket_nr)
	' Distort the pickup position on purpose
	'Go Here +Y(0.8)
	'Go Here -X(0.8)
	'Go Here +U(0.8)

	If Not PickupFromSocket Then
		RTS_error(fileNum, "Can't pickup chip from socket")
        MoveChipFromSocketToTray = -300
		Exit Function
	EndIf
			
	' Take picture of the bottom of the chip
	Jump P_camera 'JumpToCamera
	
	Integer status
	Double corrs(2)
'	If ChipType$ = "COLDATA" Then
'		status = COLDATA_VisAnalysis(ByRef corrs())
'	Else
		'ChipBottomAnaly(chip_SN$, ByRef idx(), ByRef status, ByRef res())
		status = ChipBottomAnaly(ts$, ByRef idx(), ByRef res())
'	EndIf

	If status <> 0 Then
		RTS_error(fileNum, "Analysis of chip bottom failed. Error = " + Str$(status))
        MoveChipFromSocketToTray = -4
		Exit Function
	EndIf

	Double X_CORR_socket, Y_CORR_socket, U_CORR_socket
	If ChipType$ = "COLDATA" Then
		X_CORR_socket = corrs(1)
		Y_CORR_socket = corrs(2)
		U_CORR_socket = 0
	Else
		X_CORR_socket = res(20)
		Y_CORR_socket = res(21)
		U_CORR_socket = res(16)
	EndIf
	
	Print "Correcting chip position from socket: ",
	Print " dX = ", X_CORR_socket, " dY = ", Y_CORR_socket, " dU = ", U_CORR_socket
	
	' Save/update the socket position corrections
	DAT_X(DAT_nr, socket_nr) = X_CORR_socket
	DAT_Y(DAT_nr, socket_nr) = Y_CORR_socket
	DAT_U(DAT_nr, socket_nr) = U_CORR_socket
	
	' Jump to the given tray
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	' Correct for socket offset (socket corr is rotation -90 degrees)
	'Move Here -X(-Y_CORR_socket) -Y(X_CORR_socket)
	
	' Rotate to match chip placement
    'Go Here -U(90) ' NOTE: temporary correction added for FNAL due to chip orientation
		
	Wait 0.3
	
	' Grab the tray position corrections
	Double X_CORR_tray, Y_CORR_tray, U_CORR_tray
	X_CORR_tray = tray_X(pallet_nr, col_nr, row_nr)
	Y_CORR_tray = tray_Y(pallet_nr, col_nr, row_nr)
	U_CORR_tray = 0 'tray_U(pallet_nr, col_nr, row_nr)
	Print "Saved tray corrections:", X_CORR_tray, Y_CORR_tray
	
	' Correct for tray offset
	'Move Here +X(-Y_CORR_tray) +Y(X_CORR_tray)
	
	Double d_X, d_Y, d_U
	d_X = -Y_CORR_socket + Y_CORR_tray
	d_Y = X_CORR_socket - X_CORR_tray
	d_U = U_CORR_socket - U_CORR_tray
	
	' Only correct if corrections are under some limit
	If Abs(d_X) < 50.0 And Abs(d_Y) < 50.0 And Abs(d_U) < 180 Then
	
		' Make both tray and socket corrections
		Move Here -X(d_X) -Y(d_Y)

		If Not DropToTray Then
			RTS_error(fileNum, "Failed to DropToTray")
			MoveChipFromSocketToTray = -6
       		Exit Function
		EndIf
	Else
		RTS_error(fileNum, "Chip position out of limits")
        MoveChipFromSocketToTray = -5
        Exit Function
	EndIf

	' Take a picture of the chip in the tray
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	pict_fname$ = DF_take_picture$(ts$ + "_SN")
	Print #fileNum, ",", pict_fname$,


	Print #fileNum, " "
	Close #fileNum

Fend

'
' INPUT: 
'        src_pallet_nr - pallet number of the chip source (1-left, 2-right)
'        src_col_nr - source column number (1-15)
'        src_row_nr - srouce row number (1-6)
'        tgt_pallet_nr - pallet number of chip destination (1-left, 2-right)
'        tgt_col_nr - column number in the destination (1-15)
'        tgt_row_nr - row number in the destination (1-6)
'        tgt_DU - chip rotation modification (deg.)
'
'
' RETURN:
'        > 0 - job_id (timestamp)
'        < 0 - Error id

Function MoveChipFromTrayToTray(src_pallet_nr As Integer, src_col_nr As Integer, src_row_nr As Integer, tgt_pallet_nr As Integer, tgt_col_nr As Integer, tgt_row_nr As Integer, tgt_DU As Double) As Int64
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	MoveChipFromTrayToTray = Val(ts$)

	SetSpeedSetting("")
		
	String fname$
	fname$ = "manip.csv"
		
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
		
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
	
			
	idx(2) = src_pallet_nr
	idx(3) = src_col_nr
	idx(4) = src_row_nr
	idx(5) = tgt_pallet_nr
	idx(6) = tgt_col_nr
	idx(7) = tgt_row_nr
	idx(8) = 0
	idx(9) = 0
	idx(10) = 0
	idx(11) = 0
			
	'String d$, t$
 	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", src_pallet_nr, ",", src_col_nr, ",", src_row_nr,
	' pallet target
	Print #fileNum, ",", tgt_pallet_nr, ",", tgt_col_nr, ",", tgt_row_nr,
	' socket source
	Print #fileNum, ",", 0, ",", 0,
	' socket target
	Print #fileNum, ",", 0, ",", 0,

	' Ensure that there is no chip in destination	
	If src_pallet_nr <> tgt_pallet_nr Or src_col_nr <> tgt_col_nr Or src_row_nr <> tgt_row_nr Then
		If isChipInTrayTouch(tgt_pallet_nr, tgt_col_nr, tgt_row_nr) Then
			RTS_error(fileNum, "Chip exists in the destination ")
			Go Here :Z(JUMP_LIMIT)
			MoveChipFromTrayToTray = -200
			Exit Function
		EndIf
	EndIf


	' Take a picture of the chip in the tray
	JumpToTray_camera(src_pallet_nr, src_col_nr, src_row_nr)
	String pict_fname$
	pict_fname$ = DF_take_picture$(ts$ + "_SN")
	Print #fileNum, ",", pict_fname$,

	'Print #fileNum, ",", chip_SN$,
		
	' Ensure that chip exists in the source	
	'If Not isChipInTray(src_pallet_nr, src_col_nr, src_row_nr) Then
	'	RTS_error(fileNum, "No chip found in the tray ")
	'	MoveChipFromTrayToTray = -201
	'	Exit Function
	'EndIf
		
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum ")
		MoveChipFromTrayToTray = -202
		Exit Function
	EndIf
	
	JumpToTray(src_pallet_nr, src_col_nr, src_row_nr)

	' If chip rotation requested:
	If tgt_DU <> 0.0 Then
		Double Utmp
		Utmp = CU(Pallet(src_pallet_nr, src_col_nr, src_row_nr)) - tgt_DU
		If Utmp > 360 Then
			Utmp = Utmp - 360
		ElseIf Utmp < 0 Then
			Utmp = Utmp + 360
		EndIf
		If Utmp < 0 Or Utmp > 360 Then
			RTS_error(fileNum, "Internal program error - bad tgt_DU ")
			MoveChipFromTrayToTray = -4
			Exit Function
		EndIf
		Go Here :U(Utmp)
	EndIf

	' Distort the pickup position on purpose
	'Go Here -Y(0.8)
	'Go Here +X(0.8)
	'Go Here -U(0.8)
	If Not PickupFromTray Then
		RTS_error(fileNum, "Can't pickup a chip from tray ")
        MoveChipFromTrayToTray = -5
		Exit Function
	EndIf
	
	' Take picture of the bottom of the chip
	Jump P_camera 'JumpToCamera
	
	Integer status
	'ChipBottomAnaly(chip_SN$, ByRef idx(), ByRef status, ByRef res())
	status = ChipBottomAnaly(ts$, ByRef idx(), ByRef res())

	If status <> 0 Then
		RTS_error(fileNum, "Analysis of chip bottom failed. Error = " + Str$(status))
        MoveChipFromTrayToTray = -6
		Exit Function
	EndIf

	Double d_X, d_Y, d_U
	d_X = res(20)
	d_Y = res(21)
	d_U = res(16)
	
	' Move to tray
	JumpToTray(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
	Wait 0.2
	If Not (src_pallet_nr = tgt_pallet_nr And src_row_nr = tgt_row_nr And src_col_nr = tgt_col_nr And tgt_DU = 0) Then
		' correct position
		Print "Correcting chip position for tray: ",
		Print " dX = ", d_X, " dY = ", d_Y, " dU = ", d_U
		If Abs(d_X) < 1.5 And Abs(d_Y) < 1.5 And Abs(d_U) < 2.0 Then
			Go Here +X(d_X) +Y(d_Y) -U(d_U)
		Else
			RTS_error(fileNum, "Chip position out of limits")
        	MoveChipFromTrayToTray = -7
        	Exit Function
		EndIf
	Else
		Print "Chip position correction for tray: ",
		Print " dX = ", d_X, " dY = ", d_Y, " dU = ", d_U
		Print "No correction of chip position applied because orgin and destination are the same"
	EndIf
	If Not DropToTray Then
		RTS_error(fileNum, "Can't put chip into tray")
       	MoveChipFromTrayToTray = -8
       	Exit Function
	EndIf

	
	
	' Take a picture of the chip in the tray
	JumpToTray_camera(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
	pict_fname$ = DF_take_picture$(ts$ + "_SN")
	Print #fileNum, ",", pict_fname$,

				
	Print #fileNum, " "
	Close #fileNum

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
		VGet skt_cali_test.Geom01.RobotXYU, isFound1, x_p1, y_p1, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, isFound2, x_p2, y_p2, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, isFound3, x_p3, y_p3, a_p3
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

'''' MSU WRITTEN FUNCTIONS ''''
'''' Move chip to and from tray/socket functions

Function RunMoveChipTrayToSocket(pallet_nr As Integer, col_nr As Integer, row_nr As Integer, DAT_nr As Integer, socket_nr As Integer) As Int64

	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	RunMoveChipTrayToSocket = Val(ts$)

	SetSpeed
	
	String fname$
	fname$ = "manip.csv"
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
	
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
	

	idx(2) = pallet_nr
	idx(3) = col_nr
	idx(4) = row_nr
	idx(5) = 0
	idx(6) = 0
	idx(7) = 0
	idx(8) = 0
	idx(9) = 0
	idx(10) = DAT_nr
	idx(11) = socket_nr
			
	'String d$, t$
 	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", pallet_nr, ",", col_nr, ",", row_nr,
	' pallet target
	Print #fileNum, ",", 0, ",", 0, ",", 0,
	' socket source
	Print #fileNum, ",", 0, ",", 0,
	' socket target
	Print #fileNum, ",", DAT_nr, ",", socket_nr,




	On 12
	SetSpeedSetting("MoveWithoutChip")
	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + socket_nr


	' Test if there is a chip or obstruction in the socket.
	
	Print "Visually  checking for chip in socket"
	If isChipInSocketCamera(DAT_nr, socket_nr) Then
		Print "ERROR there is already a chip in this socket"
		RunMoveChipTrayToSocket = -200
		Exit Function
	EndIf

	' Use the DF camera to find the position and orientation of the socket mezzanine board
	Print "Checking empty and getting socket offsets"
	Double SocketResults(10)
	If Not DFGetSocketAlignment(ts$, ByRef idx(), DAT_nr, socket_nr, ByRef SocketResults()) Then
		RTS_error(fileNum, "Cannot get socket alignment")
		Exit Function
	EndIf
	
	Print "Physically checking for chip in socket"
	If isChipInSocketTouch(DAT_nr, socket_nr) Then
		RTS_error(fileNum, "There is already a chip in this socket")
		RunMoveChipTrayToSocket = -200
		Exit Function
	EndIf
    SetSpeedSetting("MoveWithoutChip")
	
	' Now go get the chip
	Print "Socket O.K., moving to tray to check and pick up chip"
	
	Wait 2
	
	Print "Next go to the tray and check chip position and orientation"
	Double TrayResults(10)
	If Not DFGetTrayAlignment(ts$, ByRef idx(), pallet_nr, col_nr, row_nr, ByRef TrayResults()) Then
		RTS_error(fileNum, "Cannot get tray alignment")
		Exit Function
	EndIf
	



	Int32 ChipTypeNumber
	ChipTypeNumber = (10 + socket_nr) / 10
	' Calculate needed rotation to insert chip into socket in correct orientation
	Double DeltaDir
	DeltaDir = (SocketResults(6) + SocketChipOrientation(ChipTypeNumber)) - TrayResults(6)
	
	' Reduce rotation so within +/- 180
'	If DeltaDir < -180. Then
'		DeltaDir = DeltaDir + 360.
'	ElseIf DeltaDir > 180. Then
'		DeltaDir = DeltaDir - 360.
'	EndIf
	DeltaDir = GetBoundAnglePM180(DeltaDir)
	' Sanity check angle is within range
	If Abs(DeltaDir) > 180. Then
		String Emessage$
		Emessage$ = "Chip reorientation should fall within +/- 180 deg, but calculated at " + Str$(DeltaDir)
		RTS_error(fileNum, Emessage$)
		Exit Function
	EndIf
		
	
	Print "Summary"
	Print "Tray Chip Dir  = ", TrayResults(6)
	Print "Sock Chip Dir  = ", (SocketResults(6) + SocketChipOrientation(ChipTypeNumber))
	Print "Chip rotation needed = ", DeltaDir
	
	Print "Tray Ag4Offset = ", TrayResults(10)
	Print "Sock Ag4Offset = ", SocketResults(10)
	

	Double PickU
	'	TgtAg4 = SockPos(3) - SockAg4Offset
	PickU = CU(P(DAT_nr * 100 + socket_nr)) - DeltaDir
	
	If Abs(PickU) > 180. Then
		String Emassage$
		Emessage$ = "Chip pick U should fall within +/- 180 deg, but calculated at " + Str$(PickU)
		RTS_error(fileNum, Emessage$)
		Exit Function
	EndIf
	
	Print "U value summary: chip, hand U, hand J4 angle"
	Print "At tray   :", ChipPos(3), ", ", PickU, ", ", (PickU + TrayResults(10))
	Print "At socket :", (ChipPos(3) + DeltaDir), ", ", (PickU + DeltaDir), ", ", (PickU + DeltaDir + SocketResults(10))

	Wait 2




	Print "Now attempt to pick up chip"
	' All Okay so far, try picking up the chip
	' TODO JW: Check for lid collisions

	Go Here :U(PickU)
	Go Here :Z(CZ(Pallet(pallet_nr, col_nr, row_nr)))
	

	If Not isPressureOk Then
		RTS_error(fileNum, "Bad pressure")
		RunMoveChipTrayToSocket = -2
		Exit Function
	EndIf
		
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum")
		RunMoveChipTrayToSocket = -3
		Exit Function
	EndIf
	
	If Not PickupFromTray Then
		RTS_error(fileNum, "Can't pick up chip from tray")
		RunMoveChipTrayToSocket = -4
		Exit Function
	EndIf
	
	' Now chip has been picked up, go to the UF camera to make some more measurements of offsets	
	
	
	
	Print "Next go to the UF camera and measure residual offsets "
	
	
	Double UFChipResults(12)
	' SocketResults(6) is target U value for hand, 
	If Not UFGetChipAlignment(ts$, ByRef idx(), SocketResults(6), SocketChipOrientation(ChipTypeNumber), ByRef UFChipResults()) Then
		RTS_error(fileNum, "Cannot get chip position offsets from UF camera")
		Exit Function
	EndIf


	' TODO Here is where will put any pin analysis as well

'	Wait 2
	JumpToSocket(DAT_nr, socket_nr)
	
	' Apply some corrections
	Print "Applying corrections at socket"
	
	'''' JW: U correction for socket is already taken into account in definition of UF_Del_X and UF_Del_Y
	'''' See above where SockPos(3) comes into definition.
	' Socket U correction should already be taken into account in both the angle and 
	' chip X and Y displacement, but socket X and Y displacement must be taken into acccount here
	' X and Y displacement
	Go Here +U(UFChipResults(12)) +X(UFChipResults(10) + SocketResults(7)) +Y(UFChipResults(11) + SocketResults(8))
	
	' DUMMY SOCKET FOR OFFSET TESTING
	Boolean TESTSOCKET
	TESTSOCKET = False
	If (TESTSOCKET) And (SITE$ = "MSU") Then
		If socket_nr <> 7 Then
			RTS_error(fileNum, " not the right test socket - This is for MSU testing")
			Exit Function
		EndIf
		
		SetSpeedSetting("PickAndPlace")
		
		Go Here -Z(5) Till Sw(8) = On Or Sw(9) = Off
		VacuumValveClose
		Move Here :Z(JUMP_LIMIT - 5)
	Else
		
		If Not InsertIntoSocketSoft Then
			RTS_error(fileNum, "Could not properly drop chip into socket")
			RunMoveChipTrayToSocket = -5
			Exit Function
		EndIf
	
	EndIf
	Go Here :Z(JUMP_LIMIT - 5)
	' TODO JW: Add check using chip DF function and socket function to see if chip position in socket is consistent
	' Using GetChipInSocketAlignment function
		
	JumpToSocket_camera(DAT_nr, socket_nr)
		
	
	
	Double ChipSocketAlignment(15)
	If Not GetChipInSocketAlignment(ts$, ByRef idx(), DAT_nr, socket_nr, ByRef ChipSocketAlignment()) Then
		RTS_error(fileNum, "Cannot find get chip and socket alignment")
		Exit Function
	EndIf
	
	
	
	RunMoveChipTrayToSocket = 1
	
	Print #fileNum, " "
	Close #fileNum

Fend





Function RunMoveChipSocketToTray(DAT_nr As Integer, socket_nr As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Int64

	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	RunMoveChipSocketToTray = Val(ts$)

	SetSpeedSetting("MoveWithoutChip")
	
	String fname$
	fname$ = "manip.csv"
		
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
		
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
		
	' new CSV entry - pickup from socket and return to tray
		
	idx(2) = 0
	idx(3) = 0
	idx(4) = 0
	idx(5) = pallet_nr
	idx(6) = col_nr
	idx(7) = row_nr
	idx(8) = DAT_nr
	idx(9) = socket_nr
	idx(10) = 0
	idx(11) = 0
	
	'String d$, t$
	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", 0, ",", 0, ",", 0,
	' pallet target
	Print #fileNum, ",", pallet_nr, ",", col_nr, ",", row_nr,
	' socket source
	Print #fileNum, ",", DAT_nr, ",", socket_nr,
	' socket target
	Print #fileNum, ",", 0, ",", 0,






	On 12
	RunMoveChipSocketToTray = -999
		
	SetSpeedSetting("MoveWithoutChip")
	
	' Check tray destination is empty	
	' TODO JW add attempt loop
	
	If isChipInTrayCamera(pallet_nr, col_nr, row_nr) Then
		RTS_error(fileNum, "Chip exists in tray")
		Go Here :Z(JUMP_LIMIT - 5)
		RunMoveChipSocketToTray = -200
		Exit Function
	EndIf
	
	If isChipInTrayTouch(pallet_nr, col_nr, row_nr) Then
		RTS_error(fileNum, "Chip exists in tray")
		Go Here :Z(JUMP_LIMIT - 5)
		RunMoveChipSocketToTray = -200
		Exit Function
	EndIf
	SetSpeedSetting("MoveWithoutChip")
	' Go to socket	
	JumpToSocket_camera(DAT_nr, socket_nr)
	' Check if chip is in socket?	
	
	Double ChipSocketAlignment(15)
	If Not GetChipInSocketAlignment(ts$, ByRef idx(), DAT_nr, socket_nr, ByRef ChipSocketAlignment()) Then
		RTS_error(fileNum, "Cannot find get chip and socket alignment")
		Exit Function
	EndIf

	' Offsets	
	JumpToSocket(DAT_nr, socket_nr)
	Go Here +X(ChipSocketAlignment(10)) +Y(ChipSocketAlignment(11)) +U(ChipSocketAlignment(12))
	
	' Pick up chip	
	'PumpOn
	'Wait 1
	
	If Not isPressureOk Then
		RTS_error(fileNum, "Bad pressure")
		RunMoveChipSocketToTray = -2
		Exit Function
	EndIf
		
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum")
		RunMoveChipSocketToTray = -3
		Exit Function
	EndIf
	
	If Not PickupFromSocket Then
		RTS_error(fileNum, "Cannot pick up chip from socket")
		RunMoveChipSocketToTray = -5
		Exit Function
	EndIf
	
	' WIll then go to camera 
	JumpToCamera
	Wait 10
	
'	Double UFChipResults(12)
'	' TODO JW: Should target U here be consistent with test before placement? i.e., the socket hand U not the tray one
'	' Still, the rotation between hand and chip should be defined by the intended tray orientation, not measured this time
'		
'	
'	If Not UFGetChipAlignment(ChipSocketAlignment(6), TrayChipOrientation(pallet_nr), ByRef UFChipResults()) Then
'		Print "ERROR - Cannot get chip position offsets from UF camera"
'		Exit Function
'	EndIf
	
	' Go to tray to place
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	' TODO JW: Check this angle
	Go Here +U(TrayChipOrientation(pallet_nr))
	
	If Not DropToTray Then
		RTS_error(fileNum, "Could not place chip back in tray")
	EndIf
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	' Add another check that chip is back in tray	
	
	
	
	RunMoveChipSocketToTray = 1
		
	Print #fileNum, " "
	Close #fileNum
Fend



Function RunMoveChipTrayToTray(src_pallet_nr As Integer, src_col_nr As Integer, src_row_nr As Integer, tgt_pallet_nr As Integer, tgt_col_nr As Integer, tgt_row_nr As Integer, tgt_U As Double) As Int64
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	RunMoveChipTrayToTray = Val(ts$)

	SetSpeedSetting("")
		
	String fname$
	fname$ = "manip.csv"
	
	Wait 1
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
		
	Integer i
	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	Double res(30)
	
			
	idx(2) = src_pallet_nr
	idx(3) = src_col_nr
	idx(4) = src_row_nr
	idx(5) = tgt_pallet_nr
	idx(6) = tgt_col_nr
	idx(7) = tgt_row_nr
	idx(8) = 0
	idx(9) = 0
	idx(10) = 0
	idx(11) = 0
			
	'String d$, t$
 	'd$ = Date$
	't$ = Time$
	'Print #fileNum, d$, " ", t$,
	Print #fileNum, ts$,
	' pallet source
	Print #fileNum, ",", src_pallet_nr, ",", src_col_nr, ",", src_row_nr,
	' pallet target
	Print #fileNum, ",", tgt_pallet_nr, ",", tgt_col_nr, ",", tgt_row_nr,
	' socket source
	Print #fileNum, ",", 0, ",", 0,
	' socket target
	Print #fileNum, ",", 0, ",", 0,

	' Ensure that there is no chip in destination	
	If src_pallet_nr <> tgt_pallet_nr Or src_col_nr <> tgt_col_nr Or src_row_nr <> tgt_row_nr Then
	
		If isChipInTrayCamera(tgt_pallet_nr, tgt_col_nr, tgt_row_nr) Then
			RTS_error(fileNum, "Chip exists in the destination ")
			Go Here :Z(JUMP_LIMIT - 5)
			RunMoveChipTrayToTray = -200
			Exit Function
		EndIf
	
		If isChipInTrayTouch(tgt_pallet_nr, tgt_col_nr, tgt_row_nr) Then
			RTS_error(fileNum, "Chip exists in the destination or other obstruction")
			Go Here :Z(JUMP_LIMIT - 5)
			RunMoveChipTrayToTray = -200
			Exit Function
		EndIf
	EndIf
	
	Print "Next go to the tray and check chip position and orientation"
	Double TrayResults(10)
	If Not DFGetTrayAlignment(ts$, ByRef idx(), src_pallet_nr, src_col_nr, src_row_nr, ByRef TrayResults()) Then
		RTS_error(fileNum, "TrayAlignment")
		Exit Function
	EndIf
	Double DeltaDir
	DeltaDir = tgt_U - TrayResults(6)
	DeltaDir = GetBoundAnglePM180(DeltaDir)

	If Abs(DeltaDir) > 180. Then
		String Emessage$
		Emessage$ = "Chip reorientation should fall within +/- 180 deg, but calculated at " + Str$(DeltaDir)
		RTS_error(fileNum, Emessage$)
		Exit Function
	EndIf
	
	' At the trays Agl(4) should be similar. Cabling is in default state when U = 0, split the difference
	Double PickU
	PickU = CU(Pallet(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)) - DeltaDir


	
	Go Here :U(PickU)
	Go Here :Z(CZ(Pallet(src_pallet_nr, src_col_nr, src_row_nr)))
	

	If Not isPressureOk Then
		RTS_error(fileNum, "Bad pressure")
		RunMoveChipTrayToTray = -2
		Exit Function
	EndIf
		
	If Not isVacuumOk Then
		RTS_error(fileNum, "Bad vacuum")
		RunMoveChipTrayToTray = -3
		Exit Function
	EndIf
	
	If Not PickupFromTray Then
		RTS_error(fileNum, "Can't pick up chip from tray")
		RunMoveChipTrayToTray = -4
		Exit Function
	EndIf
	
	' Now chip has been picked up, go to the UF camera to make measurements of any offsets	
	
	Print "Next go to the UF camera and measure residual offsets "
	
	
	Double UFChipResults(12)
	' SocketResults(6) is target U value for hand, 
	If Not UFGetChipAlignment(ts$, ByRef idx(), CU(Pallet(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)), tgt_U, ByRef UFChipResults()) Then
		RTS_error(fileNum, "Cannot get chip position offsets from UF camera")
		Exit Function
	EndIf


'	' TODO Here is where will put any pin analysis as well
'
	Wait 2

	JumpToTray(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)

	' Apply some corrections
	Print "Applying corrections at tray"
'	
'	'''' JW: U correction is already taken into account in definition of UF_Del_X and UF_Del_Y

	Go Here +U(UFChipResults(12)) +X(UFChipResults(10)) +Y(UFChipResults(11))
	
	
	If Not DropToTray Then
		RTS_error(fileNum, "Could not place chip back in tray")
	EndIf
	JumpToTray_camera(tgt_pallet_nr, tgt_col_nr, tgt_row_nr)
	' Add another check that chip is back in tray	
	
	Print #fileNum, " "
	Close #fileNum
	
	RunMoveChipTrayToTray = 1
		

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
	dir_images$ = RTS_DATA$ + "\images"

	If Not FolderExists(dir_images$) Then
  		MkDir dir_images$
	EndIf
	
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf

	' pins subdirectory
	String dir_pins$
	dir_pins$ = RTS_DATA$ + "\pins"

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
	'     /  |
	'    /   |
	'   /    |
	' BL-----BR
	' Gives direction of BR -> TR
	' But uses hypotentuse for smaller error
	
	Double AvX, AvY
	Double DelX, DelY, Hyp, SPolar
	If (Not isFoundTL) And (isFoundTR And isFoundBR And isFoundBL) Then
		' Missing key is Top Left in image (UP ORIENTED)
		' Av TR and BL
		AvX = (xTR + xBL) /2
		AvY = (yTR + yBL) /2
		DelX = xTR - xBL
		DelY = yTR - yBL
	ElseIf (Not isFoundTR) And (isFoundBR And isFoundBL And isFoundTL) Then
		' Missing key is Top Right in image (RIGHT ORIENTED)
		' Av BR and TL
		AvX = (xBR + xTL) /2
		AvY = (yBR + yTL) /2
		DelX = xBR - xTL
		DelY = yBR - yTL
	ElseIf (Not isFoundBR) And (isFoundTR And isFoundBL And isFoundTL) Then
		' Missing key is Bottom Right in image (DOWN ORIENTED)
		' Av BL and TR
		AvX = (xBL + xTR) /2
		AvY = (yBL + yTR) /2
		DelX = xBL - xTR
		DelY = yBL - yTR
	ElseIf (Not isFoundBL) And (isFoundTR And isFoundBR And isFoundTL) Then
		' Missing key is Bottom left in image (LEFT ORIENTED)
		' Av TL and BR
		AvX = (xTL + xBR) /2
		AvY = (yTL + yBR) /2
		DelX = xTL - xBR
		DelY = yTL - yBR
	Else
		Print "ERROR - DID NOT PASS STRICTLY THREE POINTS"
		Print "TL: ", isFoundTL, ", TR: ", isFoundTR, ", BR: ", isFoundBR, ", BL: ", isFoundBL
		ThreeCornerFindDirection = False
		CornerVar(1) = 0
		CornerVar(2) = 0
		CornerVar(3) = 0
		Exit Function

	EndIf
	Hyp = Sqr((DelX * DelX) + (DelY * DelY))
	If DelY >= 0. Then
		SPolar = RadToDeg(Acos(DelX / Hyp))
	Else
		SPolar = -RadToDeg(Acos(DelX / Hyp))
	EndIf
	' SPolar = RadToDeg(Acos(DelX / Hyp))
	' SPolar = RadToDeg(Asin(DelY / Hyp))
	
	' Since sockets should be roughly at 90 degree increments to world axis, arctan should be fine
	' SPolar = RadToDeg(Atan(DelY / DelX))
	'Print "Polar angle from bottom left mark to top left mark is ", SPolar
	CornerVar(1) = AvX
	CornerVar(2) = AvY
	CornerVar(3) = SPolar + 45.
	
	ThreeCornerFindDirection = True ' SPolar + 45.

Fend

Function FindChipDirectionWithDF As Boolean
	FindChipDirectionWithDF = False
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0

	' Whole chip recognition
	Boolean isFoundChip
	Double cx1, cy1, cu1
	' Fiducial marker recognition
	Boolean isFoundL, isFoundS
	Double xL, yL, uL, xS, yS, uS
	Select SITE$
		Case "MSU"
			' Check for overall chip shape
			VRun GetChipDir
			VGet GetChipDir.Corr01.RobotXYU, isFoundChip, cx1, cy1, cu1

			' Get positions of Large and Small circular markers on chip
			VGet GetChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet GetChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
		Default
			Print "INVALID SITE NAME"
			Exit Function
	Send
	
	If Not isFoundChip Then
		FindChipDirectionWithDF = False
		Exit Function
	EndIf

	If (Not isFoundL) Or (Not isFoundS) Then
		FindChipDirectionWithDF = False
		Exit Function
	EndIf

' 	Print "Chip found at:  x=", cx1, "; y=", cy1 ', "; u=", cu1
'	Print "Large fiducial marker found at: x=", xL, "; y=", yL ', "; u=", uL
'	Print "Small fiducial marker found at: x=", xS, "; y=", yS ', "; u=", uS
	
	Double AvX, AvY
	AvX = (xL + xS) /2
	AvY = (yL + yS) /2
	ChipPos(1) = AvX
	ChipPos(2) = AvY

'	Print "Average X and Y: ( ", AvX, ",", AvY, " )"

	Double DelX, DelY, Hyp, SPolar
	DelX = xS - xL
	DelY = yS - yL
	Hyp = Sqr((DelX * DelX) + (DelY * DelY))
	Print "Distance between chip fiducial markers = ", Hyp
	If DelY >= 0 Then
		SPolar = RadToDeg(Acos(DelX / Hyp))
	Else
		SPolar = -RadToDeg(Acos(DelX / Hyp))
	EndIf
	
	Select CHIPTYPE$
		Case "LArASIC"
			If Abs(Hyp - LArASICDimension) > 0.5 Then
				Print "CHIP DIMENSIONS ARE NOT WITHIN TOLERANCE"
				Exit Function
			EndIf
		Default
			
	Send
		
		
	
	' Account for orientation of fiducial markers on chip
	ChipPos(3) = SPolar - 45.
'	Print "Correlation position X,Y,U = (", cx1, ",", cy1, ",", cu1, ")"
'	Print "Fiducial position    X,Y,U = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"

	' Maybe make these global variables?
	Double TolXY
	TolXY = 0.5 'mm
	' Note, angle from correlation is not very useful here even when "angle enabled"
	If Sqr((cx1 - ChipPos(1)) * (cx1 - ChipPos(1)) + (cy1 - ChipPos(2)) * (cy1 - ChipPos(2))) > TolXY Then
		Print "Fiducial and correlation measurements of chip position out of tolerance"
		Print "Correlation position X,Y = (", cx1, ",", cy1, ")"
		Print "Fiducial position    X,Y,U = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
		Exit Function
	EndIf

	FindChipDirectionWithDF = True
	
Fend


Function UF_CHIP_FIND As Boolean '(ByRef Status As Boolean, ByRef ResX As Double, ByRef ResY As Double) As Boolean
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
		Default
			Print "INVALID SITE NAME"
			Exit Function
	Send
	
	If found(1) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom01.RobotXYU, isFound(1), ResX(1), ResY(1), ResU(1)
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
	If Not ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
		Print "ERROR: Chip corner orientation failed"
		UF_CHIP_FIND = False
		Exit Function
	EndIf

	UFChipPos(1) = CornerVar(1)
	UFChipPos(2) = CornerVar(2)
	UFChipPos(3) = CornerVar(3)

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
	Double USocket

	VRun MSU_SocketFind2
	
	Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
	Boolean isFound1, isFound2, isFound3, isFound4 ' For some reason callin geom.RobotXYU overwrites found bool
	Double xTR, yTR, uTR
	Double xBR, yBR, uBR
	Double xBL, yBL, uBL
	Double xTL, yTL, uTL

	VGet MSU_SocketFind2.Geom01.Found, isFoundTR
	VGet MSU_SocketFind2.Geom02.Found, isFoundBR
	VGet MSU_SocketFind2.Geom03.Found, isFoundBL
	VGet MSU_SocketFind2.Geom04.Found, isFoundTL

	FindSocketDirectionWithDF = False
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
		VGet MSU_SocketFind2.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then
		VGet MSU_SocketFind2.Geom01.RobotXYU, Isfound1, xTR, yTR, uTR
'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		VGet MSU_SocketFind2.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		VGet MSU_SocketFind2.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf

	
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
	' but T1->T3 hypotentuse gives larger measurement, lower error
	' For arbitrary camera orienation use cos(SPolar) = DelX / Hyp
	' DelX should be signed to get right orientation
	' X and Y positions found by averaging T1 and T3 positions


	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		FindSocketDirectionWithDF = False
		Exit Function
	EndIf
	
	SockPos(1) = CornerVar(1)
	SockPos(2) = CornerVar(2)
	SockPos(3) = CornerVar(3)

	FindSocketDirectionWithDF = True

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
'''Measured chip position
'''Chip offsets from defined socket position (Defined socket -> Measured chip)
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
	String pict_fname$
	pict_fname$ = DF_take_picture$(id$ + "_CS")
    Print #fileNum, ",", pict_fname$,

	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + socket_nr
	CinSResults(1) = CX(P(FullSocket_nr)) ' Socket X
	CinSResults(2) = CY(P(FullSocket_nr)) ' Socket Y
	CinSResults(3) = CU(P(FullSocket_nr)) ' Socket U

	Int32 Attempts
	Boolean Success
	Attempts = 10
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

	Attempts = 10
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

	' Get chip position
	CinSResults(7) = ChipPos(1) ' Chip X
	CinSResults(8) = ChipPos(2) ' Chip Y
	CinSResults(9) = ChipPos(3) ' Chip U
	
	' Offsets from defined socket point (for steering)	
	CinSResults(13) = ChipPos(1) - CinSResults(1) ' Offset in X (Socket -> Chip)
	CinSResults(14) = ChipPos(2) - CinSResults(2)   ' Offset in Y
	CinSResults(15) = ChipPos(3) - CinSResults(3)  ' Offset in U
	
	' Offsets from measured socket (for analysis)
	CinSResults(13) = ChipPos(1) - SockPos(1) ' Offset in X (Socket -> Chip)
	CinSResults(14) = ChipPos(2) - SockPos(2)   ' Offset in Y
	CinSResults(15) = ChipPos(3) - SockPos(3)  ' Offset in U
	
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
	DFSockRes(3) = CU(P(FullSocket_nr))
	
	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
	Int32 Attempts
	Boolean Success
	Attempts = 10
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
	DFSockRes(6) = SockPos(3)
	' Print any deviations between the socket position in camera and defined point
	' Offset = Measured - Expected
	DFSockRes(7) = DFSockRes(4) - DFSockRes(1) ' X
	DFSockRes(8) = DFSockRes(5) - DFSockRes(2) ' Y
	DFSockRes(9) = DFSockRes(6) - DFSockRes(3) ' U - May need to correct by orientation 

	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DFSockRes(6))
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
	Int32 i, fileNum
	For i = 1 To 10
		DFTrayRes(i) = 0.
	Next i
	fileNum = idx(1)

	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	
	' Take a picture of the chip in the tray
	JumpToTray_camera(pallet_nr, col_nr, row_nr)
	String pict_fname$
	pict_fname$ = DF_take_picture$(id$ + "_CT")
	Print #fileNum, ",", pict_fname$,


	
	DFTrayRes(1) = CX(Pallet(pallet_nr, col_nr, row_nr))
	DFTrayRes(2) = CY(Pallet(pallet_nr, col_nr, row_nr))
	DFTrayRes(3) = CU(Pallet(pallet_nr, col_nr, row_nr))

	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
	Integer Attempts
	Attempts = 10
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
	DFTrayRes(9) = DFTrayRes(6) - DFTrayRes(3) ' U - May need to correct by orientation 

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
' UFChipRes(10) - Offset in X
' UFChipRes(11) - Offset in Y
' UFChipRes(12) - Offset in U 
' Must take exact target U value (including socket offset) to calculate offsets properly
' TODO JW: Maybe have it return the offsets wrt U_0 then recalc offsets for specific socket offset
' outside of this function?
Function UFGetChipAlignment(id$ As String, ByRef idx() As Integer, TargetHandU As Double, TargetChipRotation As Double, ByRef UFChipRes() As Double) As Boolean
    SetSpeedSetting("AboveCamera")
	UFGetChipAlignment = False
	Int32 i, fileNum
	For i = 1 To 12
		UFChipRes(i) = 0.
	Next i
	fileNum = idx(1)
	
	JumpToCamera
	Go Here :U(TargetHandU)
	UFChipRes(1) = TargetHandU ' This should be socket position + chip orientation offset
	
	' If J4 angle is outside desired range, first add in extra rotation to prevent over turning
	Double Rotation1
	Rotation1 = 0.
	If (Agl(4) >= -45.) And (Agl(4) <= -45.) Then
		If (Agl(4) >= 0) Then
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
	String pict_fname$
	pict_fname$ = UF_take_picture$(id$ + "_01")
    Print #fileNum, ",", pict_fname$,

	' Take first measurements
	Integer Attempts
	Attempts = 10
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
		
	' Rotate to 180 deg from first measurements
	Double Rotation2
	Rotation2 = 0.
	If (Agl(4) < 0.) Then
		Rotation2 = 180.
	Else
		Rotation2 = -180
	EndIf
	Go Here +U(Rotation2)
	
	UFChipRes(3) = CU(Here)
	
	' Take another picture
	UF_camera_light_ON
	Wait 0.2
	pict_fname$ = UF_take_picture$(id$ + "_02")
    Print #fileNum, ",", pict_fname$,
	
	Attempts = 10
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

	' Measurements have been made, return to initial U at camera
	' This should be same as U_0
	Go Here -U(Rotation1 + Rotation2)
	
	Print "Chip position measured with UF camera. Starting from", UFChipRes(1)
	Print "Rotate by ", Rotation1
	Print "1st measurement at U=", UFChipRes(2)
	Print "  x1: ", UFChipRes(4)
	Print "  y1: ", UFChipRes(5)
	Print "  u1: ", UFChipRes(6)
	Print "Rotate by ", Rotation2
	Print "2nd measurement at U=", UFChipRes(3)
	Print "  x2: ", UFChipRes(7)
	Print "  y2: ", UFChipRes(8)
	Print "  u2: ", UFChipRes(9)
	Print "Return U value by rotating by ", -(Rotation1 + Rotation2)
	
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
	
	' Set X and Y offsets as distance from first measurement to axis of rotation
	UFChipRes(10) = (UFChipRes(7) - UFChipRes(4)) / 2 ' X2 - X2 /2
	UFChipRes(11) = (UFChipRes(8) - UFChipRes(5)) / 2 ' Y2 - Y1 /2
	
	' X and Y offsets should be corrected for the first rotation offset to get back to TargetU
	UFChipRes(10) = UFChipRes(10) * Cos(DegToRad(-Rotation1)) - UFChipRes(11) * Sin(DegToRad(-Rotation1))
	UFChipRes(11) = UFChipRes(10) * Sin(DegToRad(-Rotation1)) + UFChipRes(11) * Cos(DegToRad(-Rotation1))
	
	Double UF_DEL_U1, UF_DEL_U2
	' Take out rotations to get offsets of tool U wrt to target U
'	UF_DEL_U1 = (UFChipRes(1) + SocketChipOrientation(ChipTypeNumber)) - (u1 - Rotation1) ' Offset in 1st measurement
'   UF_DEL_U2 = (UFChipRes(1) + SocketChipOrientation(ChipTypeNumber)) - (u2 - Rotation1 - Rotation2) ' Offset in 2nd measurement
	UF_DEL_U1 = UFChipRes(2) + TargetChipRotation - UFChipRes(6)
	UF_DEL_U2 = UFChipRes(3) + TargetChipRotation - UFChipRes(9)
	
	' Put them witin +/- 180 degrees
	UF_DEL_U1 = GetBoundAnglePM180(UF_DEL_U1)
	UF_DEL_U2 = GetBoundAnglePM180(UF_DEL_U2)

	If Abs(UF_DEL_U1) > 10. Then
		Print "WARNING: U offset for 1st UF chip measurement out of +/- 10 deg"
	EndIf
	
	If Abs(UF_DEL_U2) > 10. Then
		Print "WARNING: U offset for 2nd UF chip measurement out of +/- 10 deg"
	EndIf
	
	If Abs(UF_DEL_U2 - UF_DEL_U1) > 2. Then
		Print "WARNING: U offsets from UF measurements differ by more than +/- 2 deg"
		Print " 1st U offset = ", UF_DEL_U1
		Print " 2nd U offset = ", UF_DEL_U2
	EndIf
	
'	' Need to make sure average is closest angle around -pi/+pi boundary
	UFChipRes(12) = AverageAnglePM180(UF_DEL_U1, UF_DEL_U2)
	
	Print "Corrections to chip position and orientation"
	Print "Corrections measured from a rotation of ", Rotation1
	Print "Correction in x axis : ", UFChipRes(10)
	Print "Correction in y axis : ", UFChipRes(11)
	Print "Correction in u1   	: ", UF_DEL_U1
	Print "Correction in u2   	: ", UF_DEL_U2
	Print "Correction in u   	: ", UFChipRes(12)


' Correction requires rotation based on U offset
' U offset here is about chip center, need to also rotate around J3 changing x and y offsets

	UFChipRes(10) = Cos(DegToRad(UFChipRes(12))) * UFChipRes(10) - Sin(DegToRad(UFChipRes(12))) * UFChipRes(11)
	UFChipRes(11) = Sin(DegToRad(UFChipRes(12))) * UFChipRes(10) + Cos(DegToRad(UFChipRes(12))) * UFChipRes(11)
	If (Abs(UFChipRes(10)) > 10) Or (Abs(UFChipRes(11)) > 10) Then
		Print "ERROR CORRECTION IS MORE THAN 10 mm"
		Exit Function
	EndIf
	
	Print "Corrections:"
	Print " Delta X : ", UFChipRes(10)
	Print " Delta Y : ", UFChipRes(11)
	Print " Delta U : ", UFChipRes(12)
	
	UFGetChipAlignment = True
    SetSpeedSetting("MoveWithChip")
	
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

