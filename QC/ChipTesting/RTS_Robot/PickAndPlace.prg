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
	'''
	' Checks if a chip is visible with the camera
	'' Returns True or False
	'''
	
	isChipInTrayCamera = False
	SelectSite("InFunctionDefinePallets")
	JumpToTray_camera(pallet_nr, col_nr, row_nr)

'	NAttempts = 10
	If FindChipDirectionWithDF > -900. Then
		isChipInTrayCamera = True
	EndIf

Fend

Function isChipInTrayTouch(pallet_nr As Integer, col_nr As Integer, row_nr As Integer) As Boolean
	
	If Dist(Here, Pallet(pallet_nr, col_nr, row_nr)) > 1.0 Then
		JumpToTray(pallet_nr, col_nr, row_nr)
	EndIf
	
	SetSpeedSetting("PickAndPlace")

	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	isChipInTrayTouch = TouchSuccess
	SetSpeedSetting("")
	
Fend

Function PickupFromTray As Boolean
	'''
	' Low level wrapper function handles picking up a chip
	' from a tray position assuming robot is already in place
	''
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
	' Will move chip down till in contact but 1mm above
	' defined contact  point (sensor activation)
	' Check there is no unexpected collision and then
	' place the chip
	' See "DropToTray" for version with non-contact drop
	
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
	' Moves down a few mm and then drops the chip into the tray. Returns
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

Function isChipInSocketCamera(DAT_nr As Integer, socket_nr As Integer) As Integer
	''	
	' Determines if a chip is in the image of the camera when
	' positioned above a socket, and if the chip requires any 
	' rotation
	'' Returns:
	' 0  - No chip found
	' -1 - Chip is correctly oriented 
	' -2 - Chip needs +90 deg rotation
	' -3 - Chip needs 180 deg rotation
	' -4 - Chip needs -90 deg rotation
	''
	
	isChipInSocketCamera = 0
	SelectSite("InFunctionDefinePallets")
 
	JumpToSocket_camera(DAT_nr, socket_nr)
   	SetSpeedSetting("PickAndPlace")
   	
	Double ChipDirection
	ChipDirection = FindChipDirectionWithDF
	If ChipDirection < -900. Then
		isChipInSocketCamera = 0
		SetSpeedSetting("")
		Exit Function
	EndIf
	
	' Check orientation against socket
	' HERE HERE HERE
	Double TargetDirection
	TargetDirection = CU(P(DAT_nr * 100 + Socket_nr)) + HandChipOrientation(CHIPTYPE_NR)
	
	Double DiffAngle
	DiffAngle = DiffAnglePM180(ChipDirection, TargetDirection)
		
	'RoundAngleTo90(DiffAngle)
	Select RoundAngleTo90(DiffAngle)
		Case 0.
			isChipInSocketCamera = -1 ' True
		Case 90.
			isChipInSocketCamera = -2
		Case 180.
			isChipInSocketCamera = -3
		Case -90.
			isChipInSocketCamera = -4
		Default
			Print "ERROR: isChipInSocketCamera SHOULD NOT GET HERE, DiffAngle = ", Str$(DiffAngle)
			isChipInSocketCamera = 0
	Send
	'Print "isChipInSocketCamera = ", Str$(isChipInSocketCamera)
	
	SetSpeedSetting("")
	
Fend

Function isChipInSocketTouch(DAT_nr As Integer, socket_nr As Integer) As Boolean
	
	If Dist(Here, P(DAT_nr * 100 + socket_nr)) > 1.0 Then
		JumpToSocket(DAT_nr, socket_nr)
	EndIf
    SetSpeedSetting("PickAndPlace")
	
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	isChipInSocketTouch = TouchSuccess

Fend


Function PlaceInSocket As Boolean
	'''
	' Either makes contact and places chip
	' or drops it from a distance of DROP_DIST
	' SocketInsertMethod$ allows order of operations
	' to be configured
	'''
	PlaceInSocket = False

	If Not isPressureOk Then
		Exit Function
	EndIf
    SetSpeedSetting("PickAndPlace")
    
    PlungerOn
  	
  	Double SocketStartZ
  	SocketStartZ = CZ(Here)
  	
  	' Move to either the place or drop position height, and open the clamping mechanism
  	If SocPlaceNotDrop Then
  		Print "Placing chip without drop"
  		' Have chip make contact with socket
	 	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
		TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
		If Not TouchSuccess Then
			Print "ERROR! Cannot insert in socket"
			Exit Function
		EndIf
	Else
		Print "Dropping from", DROP_DIST, " above chip"
		' Defaults to drop
		' Move to drop distance
  		Go Here -Z(CONTACT_DIST - DROP_DIST)
  	EndIf
  	Wait 1
  	
	' If not clamping first, or invalid order of operations, release vacuum
	If SocClampFirst And Not SocFastClamp Then
		Print "WARNING: Attempting to soft close clamp before vacuum release, will release vacuum first instead!"
		Print "Slow close of clamp would move chip up out of the socket before it can be closed"
	EndIf

	If Not (SocClampFirst And SocFastClamp) Then
		VacuumValveClose
		Wait 1
	ElseIf Not SocPlaceNotDrop Then
		' Closing the socket while still holding onto the chip in the drop position is not advised and may not work
		' though Martin says this is what they are doing at LSU
		' If you REALLY insist on doing this, comment out the vacuum close command here 
		' It must be for fast clamping only!
		Print "WARNING: Attempting to close clamp mechanism before chip is dropped, will drop first instead!"
		VacuumValveClose
		Wait 1
	EndIf
	
	' If clamping fast, either after drop, or while in place position, clamp now
	If SocFastClamp Then
		PlungerOff
		Wait 1
	EndIf
	
	' If the chip is still held by the vacuum, make sure it is released now
	' to prevent it being picked up if not already clamped
	VacuumValveClose ' Shouldn't matter if this is already called previously 
	Wait 0.5
	
	' Move up to 
	Go Here :Z(SocketStartZ)
	
	' Make sure the plungers are retracted after soft clamping
	If Not SocFastClamp Then
		PlungerOff
	EndIf
	
	Wait 1

	PlaceInSocket = True
	SetSpeedSetting("MoveWithoutChip")
	
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


Function GetChipFromTray(Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	'''
	' Mid-level command to be used to get a chip from tray while doing appropriate
	' offset measurements and storing them for use in correction calculations
	' as well as higher operation handling overhead
	' This is intended for use in the top level "MoveChip" commands but can be called
	' by the end user in the Run window.
	''' Arguments
	' Tray [Int] - The pallet number of the tray
	' TrayCol [Int] - The column of the chip in the tray
	' TrayRow [Int] - The row of the chip in the tray
	'''
	
	Print "GetChipFromTray(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ")"
	ErrorCode = 0
    SubError = 0
	GetChipFromTray = 0
	
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		TopLevel = True
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		CurrentOperation$ = "PickTray_" + op_ts$
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": GetChipFromTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")

	' ### Defined point of tray position ###
	LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "DEFINED_POINT", CX(Pallet(Tray, TrayCol, TrayRow)), CY(Pallet(Tray, TrayCol, TrayRow)), CU(Pallet(Tray, TrayCol, TrayRow)))
    
	Print "Resetting current chip offsets for new chip"
	ResetCurrentChipOffsets
	SetSpeedSetting("MoveWithoutChip")
	
	JumpToTray_camera(Tray, TrayCol, TrayRow)
	String move_sn_dir$
	move_sn_dir$ = TrayDirectory$ + "/images/Move_SN"
	

	' #### Robot position at image ###
	LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))

	
	If Not TopLevel Then
		String SN_Picture$
		SN_Picture$ = SN_take_Picture$(move_sn_dir$, op_ts$ + "_tr" + Str$(Tray) + "_col" + Str$(TrayCol) + "_row" + Str$(TrayRow) + "_SN")
		WriteMLog(SN_Picture$)
		If SN_Picture$ = "NoChip" Then
			UpdateRobotLog$("No chip found")
			RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN, False)
			GetChipFromTray = -ERR_V_DF_ALIGN
			Exit Function
		Else
			UpdateRobotLog$("Picture of chip in tray taken: " + SN_Picture$)
		EndIf
	EndIf
	
	SetSpeedSetting("PickAndPlace")

	' need to account for offset of tray position from 0 or 180 degrees
	Double dTU
	dTU = GetBoundAnglePM45(CU(Pallet(Tray, TrayCol, TrayRow)))
	Print "Tray orientation small offset dTU = ", Str$(dTU)
	
	Double MeasuredDirection, MeasuredOrientation, OrientationOffset
	MeasuredDirection = FindChipDirectionWithDF
	If MeasuredDirection < -900. Then
		RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromTray = -ERR_V_DF_ALIGN ' Set an error code
		Exit Function
	EndIf
	
	If MeasurePlacement Then
		If GetChipPositionWithDF(0) Then
			' #### Chip position in tray ###
			LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", -999., -999., -999.)
		EndIf
	EndIf
	
	
	' subtract small offset in angle and then round to nearest 90deg
	MeasuredOrientation = RoundAngleTo90(DiffAnglePM180(dTU, MeasuredDirection))
	
	' Find difference between this and the intended direction/orientation of the chip in the tray (Set in site csv file)
	OrientationOffset = DiffAnglePM180(TrayOrientation, MeasuredOrientation)
	
	Print "Measured chip"
	Print "		Direction   = ", Str$(MeasuredDirection)
	Print "		Orientation = ", Str$(MeasuredOrientation)
	Print "		Intended    = ", Str$(TrayOrientation)
	Print "		Offset      = ", Str$(OrientationOffset)
		
	Print "Going to pick up chip"
	JumpToTray(Tray, TrayCol, TrayRow)
	Print "Tray position = "
	Print Here
	
	' Calculate U angle to pick up chip at
	Double PickU
	' Should pick up at (DefaultChipOrientationInTray - HandChipOrientation) + OrientationOffset +dTU
	PickU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), TrayOrientation)
	Print "Pickup orientation is ", PickU
	PickU = GetBoundAnglePM180(PickU + dTU + OrientationOffset)
	
	Print "Picking up at U = ", PickU
	' Pick offset is globally defined in case you want to pick chips up at 45deg		
	' for LArASIC and ColdADC small sockets.
	Go Here :U(PickU + PickOffset)
	

	' ### Robot position at pick ###
	LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "ROBOT_AT_PICK", CX(Here), CY(Here), CU(Here))

	Print "Pickup position = "
	Print Here
	Print "Chip direction is currently ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	
	PumpOn
	Wait 1
	
	If Not isPressureOk Then
		RTS_error("GetChipFromTray: Bad pressure ", -ERR_PRESSURE, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromTray = -ERR_PRESSURE
	   	Exit Function
	EndIf
	
	If Not isVacuumOk Then
    	RTS_error("GetChipFromTray: Bad vacuum ", -ERR_VACUUM, TopLevel)
    	ResetOperation(TopLevel)
		GetChipFromTray = -ERR_VACUUM
		Exit Function
	EndIf

	If Not PickupFromTray Then
		RTS_error("GetChipFromTray: Cannot pick up chip from tray", -ERR_TRAY_PICK, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromTray = -ERR_TRAY_PICK
		Exit Function
	EndIf
	
	Print "Chip picked up, moving to UF camera to measure offsets"
	UpdateRobotLog$(CurrentOperation$ + ": Picked up chip from tray, moving to UF camera")
    SetSpeedSetting("MoveWithChip")
	
    ' Go to UFC and get chip-axis offsets 
    ' Stores offsets in ChipAxisOffset(3) - need to set in tray variables                                                                                                                                                                                                                 
	If Not FindChipAxisOffsetWithUF Then
		RTS_error("GetChipFromTray: Cannot measure chip offsets at UFC ", -ERR_V_UF_ALIGN, False)
    	GetChipFromTray = -ERR_V_UF_ALIGN
    	Exit Function
   	EndIf
   	Print "Offsets measured"
   	If Abs(OrientationOffset) > 45 Then
   		Print "Applying corrections for orientation offset"
   	EndIf
   	Print "Picked up with chip-hand offsets of (XYU) uncorrected:"
   	Print Str$(CurrentChipOffset(1)), ",", Str$(CurrentChipOffset(2)), ",", Str$(CurrentChipOffset(3))
   	' Set "Corrected" offsets to be used in setting tray position values
   	CorrectChipAxisOffsetForPickupOrientation(MeasuredOrientation, TrayOrientation)
   	Print "After correcting for orientation offset of ", Str$(OrientationOffset)
   	Print Str$(CorrectedChipOffset(1)), ",", Str$(CorrectedChipOffset(2)), ",", Str$(CorrectedChipOffset(3))
   		
	tray_X(Tray, TrayCol, TrayRow) = CorrectedChipOffset(1)
	tray_Y(Tray, TrayCol, TrayRow) = CorrectedChipOffset(2)
	tray_U(Tray, TrayCol, TrayRow) = CorrectedChipOffset(3)
	

	' ### Offset measured at UFC ###
	LogTestMeasurements(CurrentOperation$, "FromTray", Tray, TrayCol, TrayRow, "UFC_OFFSET", tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow))

	
	
	Print "Offsets for tray(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ") : (", tray_X(Tray, TrayCol, TrayRow), ",", tray_Y(Tray, TrayCol, TrayRow), ",", tray_U(Tray, TrayCol, TrayRow), ")"
	LogUFOffsets(Tray, TrayCol, TrayRow, 0, 0, CurrentOperation$)

	Print "Updating position files"
	UpdatePositionFiles
	Print "Updating current offset file"
	StoreCurrentChipOffset
	' Set to successful (maybe set to time stamp instead of "True" (-1)
	
	SetSpeedSetting("MoveWithChip")
	
	UFRecenter
	
	GetChipFromTray = -1
	ResetOperation(TopLevel)
	
Fend

Function PlaceChipInTray(Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	'''
	' Mid-level command to be used to place a chip in tray applying the appropriate 
	' corrections based on offsets stored in global variables.
	' This is intended for use in the top level "MoveChip" commands but can be called
	' by the end user in the Run window after a chip has been picked up with another
	' mid level command (GetChipFromTray or GetChipFromSocket)
	''' Arguments
	' Tray [Int] - The pallet number of the tray
	' TrayCol [Int] - The column of the chip in the tray
	' TrayRow [Int] - The row of the chip in the tray
	'''

	Print "PlaceChipInTray(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ")"
	PlaceChipInTray = 0
    SubError = 0
    
    Boolean TopLevel
    TopLevel = False
    
    If CurrentOperation$ = "" Then
    	TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		CurrentOperation$ = "PlaceTray_" + op_ts$
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": PlaceChipInTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")

    
    ' ### Defined point of tray position ###
   	LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "DEFINED_POINT", CX(Pallet(Tray, TrayCol, TrayRow)), CY(Pallet(Tray, TrayCol, TrayRow)), CU(Pallet(Tray, TrayCol, TrayRow)))
	
    
    ' Make sure current chip and previous chip from tray position's offsets are loaded
    LoadCurrentChipOffset
    LoadPositionFiles
    Print "Current chip offsets in memory:"
    Print Str$(CurrentChipOffset(1)), ",", Str$(CurrentChipOffset(2)), ",", Str$(CurrentChipOffset(3))
   	   
	SetSpeedSetting("MoveWithChip")
	JumpToTray(Tray, TrayCol, TrayRow)
	Print "Position before corrections"
	Print Here
	Print "Chip direction currently ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	
	
	SetSpeedSetting("PickAndPlace")
	
	Print "Target chip orientation is ", TrayOrientation
	
	' Intended chip position = HandChipOrientation + HandPlaceU
	Double PlaceU, dTU
	dTU = GetBoundAnglePM45(CU(Here)) 'CU(Here) - RoundAngleTo90(CU(Here))
	
	Print "After tray correction of dTU=", dTU, ", chip direction should be ", Str$(GetBoundAnglePM180(TrayOrientation + dTU))
	
	' (Intended Tray Orientation + dTU) = PlaceU + ChipHand offset
	PlaceU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), (TrayOrientation + dTU))
	
	Print "Chip orientation relative to hand at socket should be ", HandChipOrientation(CHIPTYPE_NR)
	
	Go Here :U(PlaceU + PickOffset) ' Need to check if this impacts correction calculation, see how it is folded into the pick u

	Print "Placing at U = ", Str$(PlaceU + PickOffset)
	Print Here
	
	Print "Chip direction after placing should be ", GetBoundAnglePM180(PlaceU + HandChipOrientation(CHIPTYPE_NR))

	' If stored tray offsets are empty, want to have expected offset as picked up if it were in tray in correct position
	' I think this shuld be the same as HandChipOrientation(CHIPTYPE_NR)
	' i.e., if placing a chip into an empty tray which hasn't had a chip removed from it, need to compare ~+90. value to 90, not to 0
	If (Abs(tray_X(Tray, TrayCol, TrayRow)) + Abs(tray_Y(Tray, TrayCol, TrayRow)) + Abs(tray_U(Tray, TrayCol, TrayRow))) < 0.01 Then
		tray_U(Tray, TrayCol, TrayRow) = HandChipOrientation(CHIPTYPE_NR)
	EndIf

	' Calculate correction from current and previous offsets
	GetChipToChipCorrections(CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3), tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow), CU(Here))
	' Should add a verbosity level here
' Move in file logging to move function, just print to screen for get/place level
	Print("Current chip offset  = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	Print("Tray position offset = (" + Str$(tray_X(Tray, TrayCol, TrayRow)) + "," + Str$(tray_Y(Tray, TrayCol, TrayRow)) + "," + Str$(tray_U(Tray, TrayCol, TrayRow)) + ")")
	Print("Correction At Tray   = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	' ### Previous and current chip offsets, as well as the chip-to-chip-correction ###
   	LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "CURRENT_CHIP_OFFSET", CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3))
   	LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "LAST_CHIP_OFFSET", tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow))
   	LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_CORRECTION", ChipToChipCorrection(1), ChipToChipCorrection(2), ChipToChipCorrection(3))



	If Abs(GetBoundAnglePM45(ChipToChipCorrection(3))) > 3. Then
		RTS_error("PlaceChipInTray: U correction outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInTray = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 2. Or Abs(ChipToChipCorrection(2)) > 2. Then
		RTS_error("PlaceChipInTray: X or Y correction outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInTray = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	
	' apply corrections
	Print "Corrections within tolerance"
	If Not SkipChipToChipCorrection Then
		Print "Applying chip-to-chip corrections"
		Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(ChipToChipCorrection(3))
	Else
		Print "Chip-to-chip corrections turned off!"
	EndIf
	Print "Placing at "
	Print Here
	
	' ### Robot position at place ###
	LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "ROBOT_AT_PLACE", CX(Here), CY(Here), CU(Here))

	Print "Chip currently at U = ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	' Not sure this will work with chip in tray in wrong direction?
'	Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(GetBoundAnglePM45(ChipToChipCorrection(3)))
	
	SetSpeedSetting("PickAndPlace")
	Print "Placing chip in tray"
	If Not DropToTray Then
		RTS_error("PlaceChipInTray: Could not place in tray ", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	PumpOff
	
	If Not isChipInTrayTouch(Tray, TrayCol, TrayRow) Then
		RTS_error("PlaceChipInTray: Chip not placed correctly (touch check)", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayCamera(Tray, TrayCol, TrayRow) Then
		RTS_error("PlaceChipInTray: Chip not placed correctly (vision check)", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If MeasurePlacement Then
		If GetChipPositionWithDF(0) Then
			' #### Robot position at image ###
			LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
			' #### Chip position in tray ###
			LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(CurrentOperation$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", -999., -999., -999.)
		EndIf
	EndIf
	
	Print "Chip placed"
	SetSpeedSetting("MoveWithoutChip")
	ResetCurrentChipOffsets
	
	PlaceChipInTray = -1 ' Or timestamp
	ResetOperation(TopLevel)
Fend

Function GetChipFromSocket(DAT As Integer, Socket As Integer) As Int64
	'''
	' Mid-level command to be used to get a chip from socket while doing appropriate
	' offset measurements and storing them for use in correction calculations
	' as well as higher operation handling overhead.
	' This is intended for use in the top level "MoveChip" commands but can be called
	' by the end user in the Run window.
	''' Arguments
	' DAT [Int] - The DAT board (1/2 - left/right from Robot perspective)
	' Socket [Int] - The socket number (see wiki)
	'''	
	Print "GetChipFromSocket(", Str$(DAT), ",", Str$(Socket), ")"
	GetChipFromSocket = 0
    SubError = 0
	
	Boolean TopLevel
	TopLevel = False

	If CurrentOperation$ = "" Then
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		CurrentOperation$ = "PickSocket_" + op_ts$
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + " : GetChipFromSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
    
    ResetCurrentChipOffsets
    
 	SetSpeedSetting("MoveWithoutChip")
 			
	If Not TopLevel Then
		String Socket_Picture$
		Socket_Picture$ = Socket_take_picture$("Remove", op_ts$ + "_DAT" + Str$(DAT) + "_Skt" + Str$(Socket) + "_remove")
		WriteMLog(Socket_Picture$)
		UpdateRobotLog$("Picture of chip in socket before removal: " + Socket_Picture$)
	EndIf
	
 	
	If Not SkipSocketCorrection Then ' Better to have global bool default to false
		Print("Measuring socket position for corrections")
		JumpToSocket_camera(DAT, Socket)
		
		' ### Point at which image is taken ###
		LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
		Wait 1
		SetSpeedSetting("PickAndPlace")
		' Adjust for socket position drift with DF camera
		
		If Not GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN, TopLevel)
			ResetOperation(TopLevel)
			GetChipFromSocket = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		' ### Measured socket position ###
		LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		
		' ### Socket offsets ###
		LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "SOCKET_OFFSET", SocketOffset(1), SocketOffset(2), SocketOffset(3))
		
		' Check corrections are small	
		If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
			RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
			ResetOperation(TopLevel)
			GetChipFromSocket = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
		
		If MeasurePlacement Then
		
			If GetChipPositionWithDF(0) Then
				' #### Chip position in tray ###
				LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
			Else
				LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
			EndIf
		EndIf
		
		
		Wait 1
	ElseIf MeasurePlacement Then
		
		' #### Robot position at image ###
		LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
	
		If GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			' ### Measured socket position ###
			LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		Else
			LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", -999., -999., -999.)
		EndIf
		
		If GetChipPositionWithDF(0) Then
			' #### Chip position in tray ###
			LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
		EndIf
		
	EndIf

    
	Print "Resetting current chip offsets for new chip"
	
	JumpToSocket(DAT, Socket)
	SetSpeedSetting("PickAndPlace")

	
	If Not SkipSocketCorrection Then
		Print("Applying socket correctin")
		Print "Correcting for socket (", DAT, ",", Socket, ") drift : (", SocketOffset(1), ",", SocketOffset(2), ",", SocketOffset(3), ")"
		Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
	Else
		Print("Socket corection not applied")
	EndIf
	
	PumpOn
	Wait 1
	
	If Not isPressureOk Then
		RTS_error("GetChipFromSocket: Bad pressure ", -ERR_PRESSURE, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromSocket = -ERR_PRESSURE
	   	Exit Function
	EndIf
	If Not isVacuumOk Then
  		RTS_error("GetChipFromSocket: Bad vacuum ", -ERR_VACUUM, TopLevel)
  		ResetOperation(TopLevel)
		GetChipFromSocket = -ERR_VACUUM
		Exit Function
	EndIf
	
	Print "Picking up with pick offset of ", PickOffset, " at U = ", Str$(GetBoundAnglePM180(CU(Here) + PickOffset))
	Go Here :U(GetBoundAnglePM180(CU(Here) + PickOffset))

	' ### Picking up with robot position ###
	LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_PICK", CX(Here), CY(Here), CU(Here))
	
		
'	PumpOff
'	Print "DRY RUN - NOT PICKING UP"
	
'	Wait 5
'	' Pick up chip
	If Not PickupFromSocket Then
		RTS_error("GetChipFromSocket: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromSocket = -ERR_SOCKET_PICK
		Exit Function
	EndIf
	Print "Picked up chip from socket, moving to UF camera for offset measurement"
	SetSpeedSetting("MoveWithChip")
	
	' Go to UF camera for measuring offsets and storing in DAT_x/y/u variables.
	If Not FindChipAxisOffsetWithUF Then
		RTS_error("GetChipFromSocket: Cannot get chip offsets from UF camera ", -ERR_V_UF_ALIGN, TopLevel)
		ResetOperation(TopLevel)
		GetChipFromSocket = -ERR_V_UF_ALIGN
		Exit Function
	EndIf
	Print "Offsets measured"
	' Offsets are calculated wrt HAND_U0, and so need to be corrected back to measured socket + U correction
	' Can do this later when combined with second measurement

	' Currently assumes chip is placed down in correct orientation
	' but this will allow for correction later if orientation check implemented as above
	' Also LogUFOFfsets stores the ***CorrectedChipOffset***
	' See GetChipFromTray function
	' Seeting the args to (0,0) simply sets CorrectedChipOffset(i) = CurrentChipOffset(i)
	CorrectChipAxisOffsetForPickupOrientation(0, 0)
	DAT_X(DAT, Socket) = CorrectedChipOffset(1) 'CurrentChipOffset(1)
	DAT_Y(DAT, Socket) = CorrectedChipOffset(2) 'CurrentChipOffset(2)
	DAT_U(DAT, Socket) = CorrectedChipOffset(3) 'CurrentChipOffset(3)
	
	' ### offset after picking from socket ###
	LogTestMeasurements(CurrentOperation$, "FromSocket", 0, DAT, Socket, "UFC_OFFSET", CorrectedChipOffset(1), CorrectedChipOffset(2), CorrectedChipOffset(3))
	
	Print "Offsets for socket(", Str$(DAT), ",", Str$(Socket), ") : (", DAT_X(DAT, Socket), ",", DAT_Y(DAT, Socket), ",", DAT_U(DAT, Socket), ")"
	LogUFOffsets(0, 0, 0, DAT, Socket, CurrentOperation$)
	SetSpeedSetting("MoveWithChip")
	UpdatePositionFiles
	StoreCurrentChipOffset
	
	UFRecenter
	
	GetChipFromSocket = -1
	ResetOperation(TopLevel)
	
Fend


Function PlaceChipInSocket(DAT As Integer, Socket As Integer) As Int64
	'''
	' Mid-level command to be used to place a chip in socket applying the appropriate 
	' corrections based on offsets stored in global variables.
	' This is intended for use in the top level "MoveChip" commands but can be called
	' by the end user in the Run window after a chip has been picked up with another
	' mid level command (GetChipFromTray or GetChipFromSocket)
	''' Arguments
	' DAT [Int] - The DAT board (1/2 - left/right from Robot perspective)
	' Socket [Int] - The socket number (see wiki)
	'''	
	Print "PlaceChipInSocket(", Str$(DAT), ",", Str$(Socket), ")"
	PlaceChipInSocket = 0
    SubError = 0
	SetSpeedSetting("MoveWithChip")
	
	''' For monitoring
	Int32 i
	For i = 1 To 24
		PlacePositions(i) = 0
	Next
			
	Boolean TopLevel
	TopLevel = False
	If CurrentOperation$ = "" Then
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		CurrentOperation$ = "PlaceSocket_" + op_ts$
    EndIf
	UpdateRobotLog$(CurrentOperation$ + " : PlaceChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
    
    ' Load the position information for the last chip retrieved from the socket and set DAT_x/y/u and current chip's offset
	LoadPositionFiles
    LoadCurrentChipOffset
    Print "Current chip offsets in memory:"
    Print Str$(CurrentChipOffset(1)), ",", Str$(CurrentChipOffset(2)), ",", Str$(CurrentChipOffset(3))
    	
    If Not SkipSocketCorrection Then
    	Print("Applying socket correction")
		JumpToSocket_camera(DAT, Socket)
		SetSpeedSetting("PickAndPlace")
		
		' ### Point at which image is taken ####
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
		If Not GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			RTS_error("PlaceChipInSocket: Could not get socket position ", -ERR_V_SOCKETALIGN, TopLevel)
			ResetOperation(TopLevel)
			PlaceChipInSocket = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		
		' ### Measured socket position ### 
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		
		' ### Socket offsets ####
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_OFFSET", SocketOffset(1), SocketOffset(2), SocketOffset(3))
		
		' Check corrections are small	
		If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
			RTS_error("PlaceChipInSocket: Socket corrections outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
			ResetOperation(TopLevel)
			PlaceChipInSocket = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
		
		Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
		Wait 1
	Else
		Print("Socket correction not applied")
	EndIf
	

	JumpToSocket(DAT, Socket)
	SetSpeedSetting("PickAndPlace")
	
	Print "Defined position of socket"
	Print Here
	
	' ### Socket offsets ####
	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "DEFINED_POINT", CX(Here), CY(Here), CU(Here))
	
	' Logging defined position
	PlacePositions(1) = CX(Here)
	PlacePositions(2) = CY(Here)
	PlacePositions(3) = CU(Here)
	
	' Logging measured position of socket
	PlacePositions(4) = SockPos(1)
	PlacePositions(5) = SockPos(2)
	PlacePositions(6) = SockPos(3)
	
	If Not SkipSocketCorrection Then
		Print "Applying socket correction"
		Print "Correcting for socket (", DAT, ",", Socket, ") drift : (", SocketOffset(1), ",", SocketOffset(2), ",", SocketOffset(3), ")"
		Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
			' Logging socket correction
		PlacePositions(7) = SocketOffset(1)
		PlacePositions(8) = SocketOffset(2)
		PlacePositions(9) = SocketOffset(3)
		Print Here
	Else
		Print "Socket correction not applied"
	EndIf

	
'	' calculate correction from current chip offsets and DAT position offset
'
	Go Here +U(PickOffset)

	' Logging socket corrected position (folding in any pick offset)
	PlacePositions(10) = CX(Here)
	PlacePositions(11) = CY(Here)
	PlacePositions(12) = CU(Here)

	' If stored socket offsets are empty, want to have expected offset as picked up if it were in  correct position
	' I think this shuld be the same as HandChipOrientation(CHIPTYPE_NR)
	' i.e., if placing a chip into an empty tray which hasn't had a chip removed from it, need to compare ~+90. value to 90, not to 0
	If (Abs(DAT_X(DAT, Socket)) + Abs(DAT_Y(DAT, Socket)) + Abs(DAT_U(DAT, Socket))) < 0.01 Then
		DAT_U(DAT, Socket) = HandChipOrientation(CHIPTYPE_NR)
	EndIf

	' Logging last chip offset
	PlacePositions(13) = DAT_X(DAT, Socket)
	PlacePositions(14) = DAT_Y(DAT, Socket)
	PlacePositions(15) = DAT_U(DAT, Socket)
	
	' Logging current chip offset
	PlacePositions(16) = CurrentChipOffset(1)
	PlacePositions(17) = CurrentChipOffset(2)
	PlacePositions(18) = CurrentChipOffset(3)

	GetChipToChipCorrections(CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3), DAT_X(DAT, Socket), DAT_Y(DAT, Socket), DAT_U(DAT, Socket), CU(Here))
	Print("Current chip offset  = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
    Print("Socket position offset = (" + Str$(DAT_X(DAT, Socket)) + "," + Str$(DAT_Y(DAT, Socket)) + "," + Str$(DAT_U(DAT, Socket)) + ")")
	Print("Correction At Socket   = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")
		
	' ### Previous and current chip offsets, as well as the chip-to-chip-correction ###
   	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CURRENT_CHIP_OFFSET", CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3))
   	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "LAST_CHIP_OFFSET", DAT_X(DAT, Socket), DAT_Y(DAT, Socket), DAT_U(DAT, Socket))
   	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_CORRECTION", ChipToChipCorrection(1), ChipToChipCorrection(2), ChipToChipCorrection(3))
		
	' Logging chip to chip corection
	If Not SkipChipToChipCorrection Then
		PlacePositions(19) = ChipToChipCorrection(1)
		PlacePositions(20) = ChipToChipCorrection(2)
		PlacePositions(21) = ChipToChipCorrection(3)
	EndIf
	
	If Abs(ChipToChipCorrection(3)) > 3. Then
		RTS_error("PlaceChipInSocket: Chip position U correction outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInSocket = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 1. Or Abs(ChipToChipCorrection(2)) > 1. Then
		RTS_error("PlaceChipInSocket: Chip position X or Y corrections outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInSocket = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf

    ' apply corrections
    Print "Corrections within tolerance"
    If Not SkipChipToChipCorrection Then
    	Print "Applying chip-to-chip corrections"
		Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(ChipToChipCorrection(3))
	Else
		Print "Chip-to-chip corrections are turned off!"
	EndIf
	
	Print Here
	
	' Logging actual placement position
	PlacePositions(22) = CX(Here)
	PlacePositions(23) = CY(Here)
	PlacePositions(24) = CU(Here)
	
	' ### Robot position at place ###
	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_PLACE", CX(Here), CY(Here), CU(Here))
		
	Print "Placing chip in socket"
	
	If Not PlaceInSocket Then
		RTS_error("PlaceChipInSocket: Cannot place chip in socket ", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf
	
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	' Should be zeroed in CheckSocketPlacement but just to be sure
	CSAlign_X(DAT, Socket) = 0
	CSAlign_Y(DAT, Socket) = 0
	CSAlign_U(DAT, Socket) = 0
	CSAlign_ts$(DAT, Socket) = ""
	CSAlign_Img$(DAT, Socket) = ""
	
	' Asside from the socket measurement this is all up facing stuff
	' So if checks are separated 
	LogSocketPlacements(DAT, Socket, CurrentOperation$)


	Int32 status ', attempt ' Previously thought about loop here, but instead recall checks in Rotate and Reseat functions
	'For attempt = 1 To 3
	status = CheckSocketPlacement(DAT, Socket)
	
	' Log these values before any rotation or placement
	LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
	If status = -1 Or status = -5 Then
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
	Else
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", -999., -999., -999.)
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
	EndIf
	
	If status > -1 Then ' General error or unknown status
		RTS_error("PlaceChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	ElseIf status < -1 And status > -5 Then ' Needs rotation
		RTS_error("PlaceChipInSocket: Bad orientation", -ERR_SOCKET_PLACE, False)
		If RotateChipInSocket(DAT, Socket, (-(status + 1) * 90.), False) < 0 Then
			RTS_error("PlaceChipInSocket: Cannot place chip in socket after rotation", -ERR_SOCKET_PLACE, TopLevel)
			ResetOperation(TopLevel)
			PlaceChipInSocket = -ERR_SOCKET_PLACE
			Exit Function
		EndIf
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE_ROTATE", CX(Here), CY(Here), CU(Here))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED_ROTATE", SockPos(1), SockPos(2), SockPos(3))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED_ROTATE", ChipPos(1), ChipPos(2), ChipPos(3))
	ElseIf status = -5 Then ' Needs reseat
		RTS_error("PlaceChipInSocket: Bad alignment", -ERR_SOCKET_PLACE, False)
		If ReseatChipInSocket(DAT, Socket, False) < 0 Then
			RTS_error("PlaceChipInSocket: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
			ResetOperation(TopLevel)
			PlaceChipInSocket = -ERR_SOCKET_PLACE
			Exit Function
		EndIf
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE_RESEAT", CX(Here), CY(Here), CU(Here))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED_RESEAT", SockPos(1), SockPos(2), SockPos(3))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED_RESEAT", ChipPos(1), ChipPos(2), ChipPos(3))
	ElseIf status < -5 Then ' Undefined status
		RTS_error("PlaceChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		Print "ERROR ***SHOULD NOT BE GETTING HERE ***"
		ResetOperation(TopLevel)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf
	
 	SetSpeedSetting("MoveWithoutChip")
 			
	If Not TopLevel Then
		String Socket_Picture$
		Socket_Picture$ = Socket_take_picture$("Insert", op_ts$ + "_DAT" + Str$(DAT) + "_Skt" + Str$(Socket) + "_insert")
		WriteMLog(Socket_Picture$)
		UpdateRobotLog$("Picture of chip in socket after insert: " + Socket_Picture$)
	EndIf
	
	Print "Chip placed"
	PumpOff
	ResetCurrentChipOffsets
	PlaceChipInSocket = -1
	ResetOperation(TopLevel)
	
Fend


Function AlignmentWithinTolerance(DAT_nr As Integer, Socket_nr As Integer) As Boolean
	' Relies on chip-socket alignment having already been measured	
	' and on target alignments being defined
	AlignmentWithinTolerance = 0
	
	' These may be overkill, could rely on values already in memory, requires them to be measured though
'	GetAlignmentsFromFile
'	GetTargetAlignmentsFromFile
	' Will assume if you are checking alignments, that alignments are in memory	
	' Maybe need to load target alignments if they have not been already
	
	If Abs(TCSAlign_X(DAT_nr, Socket_nr)) + Abs(TCSAlign_Y(DAT_nr, Socket_nr)) + Abs(TCSAlign_U(DAT_nr, Socket_nr)) < 0.01 Then
		GetTargetAlignments
	EndIf
	
	Print "ALIGNMENTS"
	Print "X: Measured=", CSAlign_X(DAT_nr, Socket_nr), "		Target=", TCSAlign_X(DAT_nr, Socket_nr)
	Print "Y: Measured=", CSAlign_Y(DAT_nr, Socket_nr), "		Target=", TCSAlign_Y(DAT_nr, Socket_nr)
	Print "U: Measured=", CSAlign_U(DAT_nr, Socket_nr), "		Target=", TCSAlign_U(DAT_nr, Socket_nr)
	
	Boolean misaligned
	misaligned = False
	
	If Abs(CSAlign_X(DAT_nr, Socket_nr) - TCSAlign_X(DAT_nr, Socket_nr)) > 0.2 Then
		misaligned = True
		Print "WARNING: Misaligned in X, alignment = ", CSAlign_X(DAT_nr, Socket_nr), ", target = ", TCSAlign_X(DAT_nr, Socket_nr)
	EndIf
	
	If Abs(CSAlign_Y(DAT_nr, Socket_nr) - TCSAlign_Y(DAT_nr, Socket_nr)) > 0.2 Then
		misaligned = True
		Print "Misaligned in Y, alignment = ", CSAlign_Y(DAT_nr, Socket_nr), ", target = ", TCSAlign_Y(DAT_nr, Socket_nr)
	EndIf
	' alignment angle should be rounded to <45 so no need to worry about bounds at 180/-180
	If Abs(CSAlign_U(DAT_nr, Socket_nr) - TCSAlign_U(DAT_nr, Socket_nr)) > 1. Then
		misaligned = True
		Print "Misaligned in U, alignment = ", CSAlign_U(DAT_nr, Socket_nr), ", target = ", TCSAlign_U(DAT_nr, Socket_nr)
	EndIf
	
	If misaligned Then
		Exit Function
	EndIf
	
	AlignmentWithinTolerance = -1
	
Fend

''' Checks if the tray position is occupied
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
	Print "TrayPositionOccupied = ", TrayPositionOccupied
	SetSpeedSetting("MoveWithoutChip")

Fend

''' Checks if the socket position is occupied
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

Function RotateChipInTray(Tray As Integer, TrayCol As Integer, TrayRow As Integer, TgtOrientation As Double) As Int64
	'''
	' Rotates a chip to the desired orientation
	'' Args
	' Tray [Int] - Tray pallet number
	' TrayCol [Int]
	' TrayRow [Int]
	' TgtOrientation [Double] - Orientation should be expressed as exactly 0, 90,180, -90. Minor corrections will be accounted for
	'''
	RotateChipInTray = 0
	Print "This function is not implemented yet"
	Exit Function

	Print "RotateChipInTray(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ",", Str$(TgtOrientation), ")"
	RotateChipInTray = 0
    SubError = 0
    
    Boolean TopLevel
    TopLevel = False
	
    If CurrentOperation$ = "" Then
    	TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		CurrentOperation$ = "RotateT_" + op_ts$
    EndIf
    UpdateRobotLog$(CurrentOperation$ + " RotateChipInTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + "," + Str$(TgtOrientation) + ")")
    

	JumpToTray(Tray, TrayCol, TrayRow)
	
	SubError = GetChipFromTray(Tray, TrayCol, TrayRow)
	If Not SubError Then
		RTS_error("RotateChipInTray: Could not pick up chip from tray", ERR_TRAY_PICK, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ErrorCode
	EndIf
		
'	' Can't directly use place function. Chip will be picked up with specific offset	
	
	Print "Current chip offsets in memory:"
    Print Str$(CurrentChipOffset(1)), ",", Str$(CurrentChipOffset(2)), ",", Str$(CurrentChipOffset(3))
   	
	SetSpeedSetting("MoveWithChip")
	JumpToTray(Tray, TrayCol, TrayRow)
	Print "Position before corrections"
	Print Here
	Print "Chip direction currently ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	
	
	SetSpeedSetting("PickAndPlace")
	
	Print "Target chip orientation is ", TgtOrientation
	

	' Intended chip position = HandChipOrientation + HandPlaceU
	Double PlaceU, dTU
	dTU = GetBoundAnglePM45(CU(Here)) 'CU(Here) - RoundAngleTo90(CU(Here))
	
	Print "After tray correction of dTU=", dTU, ", chip direction should be ", Str$(GetBoundAnglePM180(TgtOrientation + dTU))
	
	' (Intended Tray Orientation + dTU) = PlaceU + ChipHand offset
	PlaceU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), (TgtOrientation + dTU))
	
	Print "Chip orientation relative to hand at socket should be ", HandChipOrientation(CHIPTYPE_NR)
	
	Go Here :U(PlaceU + PickOffset) ' Need to check if this impacts correction calculation, see how it is folded into the pick u

	Print "Placing at U = ", Str$(PlaceU + PickOffset)
	Print Here
	
	Print "Chip direction after placing should be ", GetBoundAnglePM180(PlaceU + HandChipOrientation(CHIPTYPE_NR))
	
	
	' If stored tray offsets are empty, want to have expected offset as picked up if it were in tray in correct position
	' I think this shuld be the same as HandChipOrientation(CHIPTYPE_NR)
	' i.e., if placing a chip into an empty tray which hasn't had a chip removed from it, need to compare ~+90. value to 90, not to 0
	If (Abs(tray_X(Tray, TrayCol, TrayRow)) + Abs(tray_Y(Tray, TrayCol, TrayRow)) + Abs(tray_U(Tray, TrayCol, TrayRow))) < 0.01 Then
		tray_U(Tray, TrayCol, TrayRow) = HandChipOrientation(CHIPTYPE_NR)
	EndIf

	' Calculate correction from current and previous offsets
	GetChipToChipCorrections(CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3), tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow), CU(Here))
	' Should add a verbosity level here
' Move in file logging to move function, just print to screen for get/place level
	Print("Current chip offset  = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	Print("Tray position offset = (" + Str$(tray_X(Tray, TrayCol, TrayRow)) + "," + Str$(tray_Y(Tray, TrayCol, TrayRow)) + "," + Str$(tray_U(Tray, TrayCol, TrayRow)) + ")")
	Print("Correction At Tray   = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	If Abs(GetBoundAnglePM45(ChipToChipCorrection(3))) > 3. Then
		RTS_error("RotateChipInTray: U correction outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 2. Or Abs(ChipToChipCorrection(2)) > 2. Then
		RTS_error("RotateChipInTray: X or Y correction outside tolerance ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	
	' apply corrections
	Print "Corrections within tolerance"
	If Not SkipChipToChipCorrection Then
		Print "Applying chip-to-chip corrections"
	Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(ChipToChipCorrection(3))
	Else
		Print "Chip-to-chip corrections turned off!"
	EndIf
	
	Print "Placing at "
	Print Here
	Print "Chip currently at U = ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	' Not sure this will work with chip in tray in wrong direction?
'	Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(GetBoundAnglePM45(ChipToChipCorrection(3)))
	
	SetSpeedSetting("PickAndPlace")
	Print "Placing chip in tray"
	If Not DropToTray Then
		RTS_error("RotateChipInTray: Could not place in tray ", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayTouch(Tray, TrayCol, TrayRow) Then
		RTS_error("RotateChipInTray: Chip not placed correctly (touch check)", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayCamera(Tray, TrayCol, TrayRow) Then
		RTS_error("RotateChipInTray : Chip not placed correctly (vision check)", -ERR_TRAY_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	Print "Chip placed"
	SetSpeedSetting("MoveWithoutChip")
	Wait 2
	ResetCurrentChipOffsets
	RotateChipInTray = -1
	ResetOperation(TopLevel)

Fend



Function RotateChipInSocket(DAT As Integer, Socket As Integer, Angle As Double, Remeasure As Boolean) As Int64
	' Not currently implemented, need to think about how to orient hand in sink 
	' May be socket dependent?
	Print "---------------------------------------------------"
	RotateChipInSocket = -ERR_ROTATE
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "RotateS_" + ts$
			
		' Check valid operation
		If Not CheckValidSocketIndex(DAT, Socket) Then
			RTS_error("RotateChipInSocket:Invalid target socket (" + Str$(DAT) + "," + Str$(Socket) + ")", ERR_BAD_COMMAND, TopLevel)
			ResetOperation(TopLevel)
			RotateChipInSocket = -ErrorCode
			Print "---------------------------------------------------"
			Exit Function
		EndIf
    EndIf
	UpdateRobotLog$(CurrentOperation$ + " RotateChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + "," + Str$(Angle) + "," + Str$(Remeasure) + ")")

	
	Int32 status
	If Angle = 0 Or Remeasure Then
		status = CheckSocketPlacement(DAT, Socket)
		If status = -1 Then
			Print "No rotation or reseat needed"
			RotateChipInSocket = Val(ts$)
			ResetOperation(TopLevel)
			Print "---------------------------------------------------"
			Exit Function
		ElseIf status > -1 Then ' General error or unknown status
			RTS_error("RotateChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
			ResetOperation(TopLevel)
			RotateChipInSocket = -ERR_SOCKET_PLACE
			Print "---------------------------------------------------"
			Exit Function
		ElseIf status < -1 And status > -5 Then ' Needs rotation
			Angle = -(status + 1) * 90.
			' -2 = 90, -3 = 180, -3 = 270 (= -90)
		ElseIf status = -5 Then ' Needs reseat
			' Angle is fine, just needs to be resat
			
			RTS_error("RotateChipInSocket: Bad alignment", -ERR_SOCKET_PLACE, False)

			If ReseatChipInSocket(DAT, Socket, False) >= 0 Then
				Print "Successfully resat chip"
				RotateChipInSocket = Val(ts$)
				ResetOperation(TopLevel)
				Print "---------------------------------------------------"
				Exit Function
			Else
				RTS_error("RotateChipInSocket: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
				ResetOperation(TopLevel)
				RotateChipInSocket = -ERR_SOCKET_PLACE
				Print "---------------------------------------------------"
				Exit Function
			EndIf
			
		ElseIf status < -5 Then ' Undefined status
			RTS_error("RotateChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, False)
			RotateChipInSocket = -ERR_SOCKET_PLACE
			ResetOperation(TopLevel)
			Print "---------------------------------------------------"
			Exit Function
		EndIf
	EndIf
	
	' Ensure angle is properly bounded
	Double rotate
	rotate = RoundAngleTo90(Angle)
	If Angle = 0 Then
		Print "No rotation or reseat needed"
		RotateChipInSocket = Val(ts$)
		ResetOperation(TopLevel)
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	''''''	
'	Do the rotation here 	
		
	' Center in on the chip
	
	' Determine allowable rotation

	' For -90
	' +45, Pick, -90, Place, +45	
	' For 180, if Agl(4) > 0,
	' -135, Pick, + 180, Place, - 45
	' If Agl(4) < 0,
	' +135, Pick, -180, Place, +45
	Double First, Second, Third
	First = 0.
	Second = 0.
	Third = 0.
	'If rotate = +90. Then ' Think about double preceision? Something like  Abs(90 - rotate) < 0.1?
	If Abs(90 - rotate) < 0.1 Then
		First = -45.
		Second = rotate
		Third = -45.
	'ElseIf rotate = -90. Then
	ElseIf Abs(-90 - rotate) < 0.1 Then
		First = +45.
		Second = rotate
		Third = +45.
	'ElseIf (rotate = 180. Or rotate = -180.) And Agl(4) >= 0 Then
	ElseIf Abs(180 - Abs(rotate)) And Agl(4) >= 0 Then
		First = -135.
		Second = Abs(rotate)
		Third = 45.
	ElseIf Abs(180 - Abs(rotate)) And Agl(4) < 0 Then
		First = +135.
		Second = -Abs(rotate)
		Third = -45.
	Else
		' Shouldn't get here	
	EndIf


	Go Here +U(First)
	
	' Pick
	Print "Picking up chip"
	' Now pick up the chip
	PumpOn
	If Not PickupFromSocket Then
		RTS_error("RotateChipInSocket: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInSocket = -ERR_SOCKET_PICK
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	Go Here +U(Second) ' Could potentially add realignment here but not sure how reliable it is. 
	'!!! Do NOT rotate alignment correction based on CU(Here)/HandU !!!
	
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	CSAlign_X(DAT, Socket) = 0 ' HERE HERE HERE JW Check generally where variables like this are being reset to 0
	CSAlign_Y(DAT, Socket) = 0 ' Should there be a function call for this, ChipPos and SockPos?
	CSAlign_U(DAT, Socket) = 0 ' Mightbe best to just explicitly call it like this 
	CSAlign_ts$(DAT, Socket) = ""
	CSAlign_Img$(DAT, Socket) = ""
	
	If Not PlaceInSocket Then
		RTS_error("RotateChipInSocket: Cannot place chip in socket ", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInSocket = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	PumpOff
	Go Here +U(Third)
	

	''''''
	
	status = CheckSocketPlacement(DAT, Socket)
	If status > -1 Then ' General error or unknown status
		RTS_error("RotateChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInSocket = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	ElseIf status < -1 And status > -5 Then ' Needs rotation
		RTS_error("RotateChipInSocket: Cannot place chip in socket after rotation", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInSocket = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	ElseIf status = -5 Then ' Needs reseat
		RTS_error("RotateChipInSocket: Bad alignment", -ERR_SOCKET_PLACE, False) ' Leave as false
		If ReseatChipInSocket(DAT, Socket, False) < 0 Then
			RTS_error("RotateChipInSocket: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
			ResetOperation(TopLevel)
			RotateChipInSocket = -ERR_SOCKET_PLACE
			Print "---------------------------------------------------"
			Exit Function
		EndIf
	ElseIf status < -5 Then ' Undefined status
		RTS_error("RotateChipInSocket: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		RotateChipInSocket = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	RotateChipInSocket = -1 ' Or success? >0? HERE HERE HERE
	
	ResetOperation(TopLevel)

	RotateChipInSocket = Val(ts$)
	UpdateRobotLog$(CurrentOperation$ + " : Chip rotated successfully")
	Print "---------------------------------------------------"
Fend


Function ReseatChipInSocket(DAT As Integer, Socket As Integer, Remeasure As Boolean) As Int64
	'''
	' Will reseat a chip in the socket, applying a correction to move it to the
	' target alignment values
	'' Args
	' DAT, Socket - target socket indices
	' Remeasure - Enforces a new measurement of chip and socket positions/alignment
	'' Returns
	' timestamp - success
	' ERR_RESEAT - General failure code
	' ERR_COMMAND - Bad socket indices
	' ERR_V_FAILALIGN - Failure to get alignment, or bad chip height
	' ERR_ROTATE - Required rotation and failed to do so
	' ERR_SOCKET_PICK - Unable to pick up the chip
	' ERR_BAD_TOLERANCE - Calculated positions are way off from expectation
	' ERR_SOCKET_PLACE - Failed to place in socket
	' ERR_V_CHIPSOCKALIGN - Bad alignment after reseat
	'''
	' TODO, simplify error output to RTS_CFG.py, want to distinguish between cases where 
	' commands can be sent to rectify on automation side.
	
	Print "---------------------------------------------------"
	ReseatChipInSocket = -ERR_RESEAT
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "Reseat_" + ts$
			
		' Check valid operation
		If Not CheckValidSocketIndex(DAT, Socket) Then
			RTS_error("ReseatChipInSocket: Invalid target socket (" + Str$(DAT) + "," + Str$(Socket) + ")", ERR_BAD_COMMAND, TopLevel)
			ResetOperation(TopLevel)
			ReseatChipInSocket = -ErrorCode
			Print "---------------------------------------------------"
			Exit Function
		EndIf
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + " :  ReseatChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")

	Integer DFChipAlignCorrection
	DFChipAlignCorrection = 1

	Motor On

	On 12
	SelectSite("InFunctionDefinePallets")

	'op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
   	'UpdateRobotLog$(op_ts$ + " ReseatChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")

	Print "ReseatChipInSocket(", DAT, ",", Socket, ")"
	
	' ReseatCorrection should be measured outside of this function

	If Abs(ChipPos(1)) + Abs(ChipPos(2)) + Abs(ChipPos(3)) = 0 Or Remeasure Then
		'If Not MeasureAlignment(DAT, Socket) Then
		Int64 status ' HERE HERE HERE  NEed to check over all of this,as this is old code 
		'Thisi should be measure not check socket placement? Although I guess it will call it
		status = CheckSocketPlacement(DAT, Socket)
		
		' 0 is failure
		'-1 is OK!  but we will reseat anyway
		'-2,-3,-4 are rotate
		'-5 is needs reseat
		' Anything else is undefined
		
		' So, >-1 or <-5 is exit with failure
		' -2, -3, and -4 need rotate, which should also call reseat and remeasure, no need to proceed here after
		' -1 or -5 is reseat in this function
		
		If status > -1 Or status < -5 Then
			RTS_error("ReseatChipInSocket: Cannot get chip socket alignment ", -ERR_V_FAILALIGN, TopLevel)
			ResetOperation(TopLevel)
			ReseatChipInSocket = -ERR_V_FAILALIGN
			Print "---------------------------------------------------"
			Exit Function
		ElseIf status < -1 And status > -5 Then
			' ROTATE
			If RotateChipInSocket(DAT, Socket, (-(status + 1) * 90.), False) < 0 Then
				RTS_error("ReseatChipInSocket: Failed to rotate chip ", -ERR_ROTATE, TopLevel)
				ResetOperation(TopLevel)
			EndIf
			'HERE HERE HERE Add log for end of function
			If TopLevel Then
				ResetOperation(TopLevel)
			EndIf
			ReseatChipInSocket = Val(ts$)
			UpdateRobotLog$(CurrentOperation$ + " : Chip resat successfully")
			Print "---------------------------------------------------"
			Exit Function
		EndIf
		
	EndIf
	
	Print "Moving to socket point"
	JumpToSocket(DAT, Socket)
	
	SetSpeedSetting("PickAndPlace")
	Print("Will align hand with chip to pick up")

	' Center over chip
	Move Here :X(ChipPos(1)) :Y(ChipPos(2)) +U(GetBoundAnglePM45(ChipPos(3)) - GetBoundAnglePM45(CU(Here)))
	Print Here
	
	PumpOn
	Wait 1
	
	Print "Picking up chip"
	' Now pick up the chip
	If Not PickupFromSocket Then
		RTS_error("ReseatChipInSocket: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, TopLevel)
		ResetOperation(TopLevel)
		ReseatChipInSocket = -ERR_SOCKET_PICK
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	' Reset the chip position now HERE HERE HERE does this interfere with logging?
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	Print "Picked up chip from socket"
			
			
	
	Double corX, corY, corU
	corX = TCSAlign_X(DAT, Socket) - CSAlign_X(DAT, Socket)
	corX = TCSAlign_Y(DAT, Socket) - CSAlign_Y(DAT, Socket)
	corU = DiffAnglePM180(CSAlign_U(DAT, Socket), TCSAlign_U(DAT, Socket))
	
	If Abs(corX) > 2. Or Abs(corY) > 2. Or Abs(corU) > 3. Then
		RTS_error("ReseatChipInSocket: Correction too large ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	
	If DFChipAlignCorrection = 1 Then
		UpdateRobotLog$(CurrentOperation$ + " :  Reseating at target chip position")
		Print "Realigning chip to stored target position"

		Move Here +X(corX) +Y(corY) +U(corU) ' delU should be small so shouldn't worry about -180/180 boundary
		Print Here
	EndIf
	
	' Now replace the chip
	Print "Placing chip back in socket"

	If Not PlaceInSocket Then
		RTS_error("ReseatChipInSocket: Cannot place chip in socket ", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		ReseatChipInSocket = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	' HERE HERE HERE does this interfere with logging?
	CSAlign_X(DAT, Socket) = 0
	CSAlign_Y(DAT, Socket) = 0
	CSAlign_U(DAT, Socket) = 0
	CSAlign_ts$(DAT, Socket) = ""
	CSAlign_Img$(DAT, Socket) = ""
	
	PumpOff
	
    Print "Chip placed"

	status = CheckSocketPlacement(DAT, Socket)
	If Not status Then
		ResetOperation(TopLevel)
		If status = -5 Then
			RTS_error("ReseatChipInSocket: Bad alignment after reseat", -ERR_V_CHIPSOCKALIGN, TopLevel)
			ReseatChipInSocket = -ERR_V_CHIPSOCKALIGN
		Else
			RTS_error("ReseatChipInSocket: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
			ReseatChipInSocket = -ERR_SOCKET_PLACE
		EndIf
		Print "---------------------------------------------------"
		Exit Function
	EndIf
    
	SetSpeedSetting("MoveWithoutChip")
	Wait 2

	PumpOff

	ReseatChipInSocket = Val(ts$)
	UpdateRobotLog$(CurrentOperation$ + " : Chip resat successfully")

	ResetOperation(TopLevel)
	Print "---------------------------------------------------"
	
Fend

' Just press down on clamping mechanism and release without picking up the chip
Function SocketOpenAndClose(DAT_nr As Integer, Socket_nr As Integer) As Int64
	SocketOpenAndClose = 0
	
	If Not SkipSocketCorrection Then
		Print "Applying socket correction"
		' First correct for socket drift
		JumpToSocket_camera(DAT_nr, Socket_nr)
		SetSpeedSetting("PickAndPlace")
	
		If Not GetSocketPositionWithDF(DAT_nr, Socket_nr) Then ', ByRef SockCorr()) Then
		'	RTS_error("SocketOpenAndClose: Could not get socket position ", -ERR_V_SOCKETALIGN)
			SocketOpenAndClose = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		' Check corrections are small	
		
		If (Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3.) Then
		'	RTS_error("SocketOpenAndClose: Socket corrections outside tolerance ", -ERR_BAD_TOLERANCE)
			SocketOpenAndClose = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
	EndIf
	
	JumpToSocket(DAT_nr, Socket_nr)
	SetSpeedSetting("PickAndPlace")
	PlungerOn
	
	Boolean TouchSuccess ' Can't just directly use Not Byte for converting 0 to success
	TouchSuccess = Not TouchChip ' Should be 0 for touch, non zero error code
	If Not TouchSuccess Then
		Print "ERROR! Touch chip command failed - did you try to run this without a chip in the socket?"
		Exit Function
	EndIf
	
	Move Here +Z(CONTACT_DIST)
	
	PlungerOff
	SetSpeedSetting("MoveWithoutChip")
	
	JumpToSocket_camera(DAT_nr, socket_nr)
		
	SocketOpenAndClose = -1
	
Fend

Function ReseatChipInSocketWithOffset(DAT As Integer, Socket As Integer, DelX As Double, DelY As Double, DelU As Double) As Int64
	'''
	' Will reseat a chip in the socket, applying a specified correction offset
	'' Args
	' DAT, Socket - target socket indices
	' Remeasure - Enforces a new measurement of chip and socket positions/alignment
	'' Returns
	' timestamp - success
	' ERR_RESEAT - General failure code
	' ERR_COMMAND - Bad socket indices
	' ERR_V_FAILALIGN - Failure to get alignment, or bad chip height
	' ERR_ROTATE - Required rotation and failed to do so
	' ERR_SOCKET_PICK - Unable to pick up the chip
	' ERR_BAD_TOLERANCE - Calculated positions are way off from expectation
	' ERR_SOCKET_PLACE - Failed to place in socket
	' ERR_V_CHIPSOCKALIGN - Bad alignment after reseat
	'''
	' TODO, simplify error output to RTS_CFG.py, want to distinguish between cases where 
	' commands can be sent to rectify on automation side.
	
	Print "---------------------------------------------------"
	ReseatChipInSocketWithOffset = -ERR_RESEAT
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "ReseatOffset_" + ts$
			
		' Check valid operation
		If Not CheckValidSocketIndex(DAT, Socket) Then
			RTS_error("ReseatChipInSocketWithOffset: Invalid target socket (" + Str$(DAT) + "," + Str$(Socket) + "," + Str$(DelX) + "," + Str$(DelY) + "," + Str$(DelU) + ")", ERR_BAD_COMMAND, TopLevel)
			ResetOperation(TopLevel)
			ReseatChipInSocketWithOffset = -ErrorCode
			Print "---------------------------------------------------"
			Exit Function
		EndIf
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + " :  ReseatChipInSocketWithOffset(" + Str$(DAT) + "," + Str$(Socket) + "," + Str$(DelX) + "," + Str$(DelY) + "," + Str$(DelU) + ")")


	If Abs(DelX) > 2. Or Abs(DelY) > 2. Or Abs(DelU) > 3. Then
		RTS_error("ReseatChipInSocketWithOffset: User provided correction too large ", -ERR_BAD_TOLERANCE, TopLevel)
		ResetOperation(TopLevel)
		Print "---------------------------------------------------"
		Exit Function
	EndIf

	Integer DFChipAlignCorrection
	DFChipAlignCorrection = 1

	Motor On

	On 12
	SelectSite("InFunctionDefinePallets")

	'op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
   	'UpdateRobotLog$(op_ts$ + " ReseatChipInSocketWithOffset(" + Str$(DAT) + "," + Str$(Socket) + ")")

	Print "ReseatChipInSocketWithOffset(", DAT, ",", Socket, ",", DelX, ",", DelY, ",", DelU, ")"
	
	' ReseatCorrection should be measured outside of this function

	'If Abs(ChipPos(1)) + Abs(ChipPos(2)) + Abs(ChipPos(3)) = 0 Then
	If True Then ' Want to meaasure position of chip to center
		'If Not MeasureAlignment(DAT, Socket) Then
		Int64 status ' HERE HERE HERE  NEed to check over all of this,as this is old code 
		'Thisi should be measure not check socket placement? Although I guess it will call it
		status = CheckSocketPlacement(DAT, Socket)
		
		' 0 is failure
		'-1 is OK!  but we will reseat anyway
		'-2,-3,-4 are rotate
		'-5 is needs reseat
		' Anything else is undefined
		
		' So, >-1 or <-5 is exit with failure
		' -2, -3, and -4 need rotate, which should also call reseat and remeasure, no need to proceed here after
		' -1 or -5 is reseat in this function
		
		If status > -1 Or status < -5 Then
			RTS_error("ReseatChipInSocketWithOffset: Cannot get chip socket alignment ", -ERR_V_FAILALIGN, TopLevel)
			ResetOperation(TopLevel)
			ReseatChipInSocketWithOffset = -ERR_V_FAILALIGN
			Print "---------------------------------------------------"
			Exit Function
		ElseIf status < -1 And status > -5 Then
			' ROTATE
			If RotateChipInSocket(DAT, Socket, (-(status + 1) * 90.), False) < 0 Then
				RTS_error("ReseatChipInSocketWithOffset: Failed to rotate chip ", -ERR_ROTATE, TopLevel)
				ResetOperation(TopLevel)
			EndIf
			'HERE HERE HERE Add log for end of function
			If TopLevel Then
				ResetOperation(TopLevel)
			EndIf
			ReseatChipInSocketWithOffset = Val(ts$)
			UpdateRobotLog$(CurrentOperation$ + " : Chip resat successfully")
			Print "---------------------------------------------------"
			Exit Function
		EndIf
		
	EndIf
	
	Print "Moving to socket point"
	JumpToSocket(DAT, Socket)
	
	SetSpeedSetting("PickAndPlace")
	Print("Will align hand with chip to pick up")

	' Center over chip
	Move Here :X(ChipPos(1)) :Y(ChipPos(2)) +U(GetBoundAnglePM45(ChipPos(3)) - GetBoundAnglePM45(CU(Here)))
	Print Here
	
	PumpOn
	Wait 1
	
	Print "Picking up chip"
	' Now pick up the chip
	If Not PickupFromSocket Then
		RTS_error("ReseatChipInSocketWithOffset: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, TopLevel)
		ResetOperation(TopLevel)
		ReseatChipInSocketWithOffset = -ERR_SOCKET_PICK
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	' Reset the chip position now HERE HERE HERE does this interfere with logging?
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	Print "Picked up chip from socket"
	
	If DFChipAlignCorrection = 1 Then
		UpdateRobotLog$(CurrentOperation$ + " :  Reseating at user provided correction")
		Print "Realigning chip based on user provideded correction"

		Go Here +X(DelX) +Y(DelY) +U(DelU)
		Print Here
	EndIf
	
	' Now replace the chip
	Print "Placing chip back in socket"

	If Not PlaceInSocket Then
		RTS_error("ReseatChipInSocketWithOffset: Cannot place chip in socket ", -ERR_SOCKET_PLACE, TopLevel)
		ResetOperation(TopLevel)
		ReseatChipInSocketWithOffset = -ERR_SOCKET_PLACE
		Print "---------------------------------------------------"
		Exit Function
	EndIf
	
	' HERE HERE HERE does this interfere with logging?
	CSAlign_X(DAT, Socket) = 0
	CSAlign_Y(DAT, Socket) = 0
	CSAlign_U(DAT, Socket) = 0
	CSAlign_ts$(DAT, Socket) = ""
	CSAlign_Img$(DAT, Socket) = ""
	
	PumpOff
	
    Print "Chip placed"

	status = CheckSocketPlacement(DAT, Socket)
	If Not status Then
		ResetOperation(TopLevel)
		If status = -5 Then
			RTS_error("ReseatChipInSocketWithOffset: Bad alignment after reseat", -ERR_V_CHIPSOCKALIGN, TopLevel)
			ReseatChipInSocketWithOffset = -ERR_V_CHIPSOCKALIGN
		Else
			RTS_error("ReseatChipInSocketWithOffset: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
			ReseatChipInSocketWithOffset = -ERR_SOCKET_PLACE
		EndIf
		Print "---------------------------------------------------"
		Exit Function
	EndIf
    
	SetSpeedSetting("MoveWithoutChip")
	Wait 2

	PumpOff

	ReseatChipInSocketWithOffset = Val(ts$)
	UpdateRobotLog$(CurrentOperation$ + " : Chip resat successfully")

	ResetOperation(TopLevel)
	Print "---------------------------------------------------"
	
Fend
