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

Function isChipInSocketCamera(DAT_nr As Integer, socket_nr As Integer) As Boolean
	isChipInSocketCamera = False
	SelectSite("InFunctionDefinePallets")
 
	JumpToSocket_camera(DAT_nr, socket_nr)
   	SetSpeedSetting("PickAndPlace")
	
	If FindChipDirectionWithDF > -900. Then
		isChipInSocketCamera = True
	EndIf
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
    SubError = 0
	GetChipFromTray = 0
	
	If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		UpdateRobotLog$(op_ts$ + ": GetChipFromTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")
    Else
		UpdateRobotLog$(CurrentOperation$ + ": GetChipFromTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")
    EndIf
    
    String logop$
    If CurrentOperation$ = "" Then
    	logop$ = op_ts$
    Else
    	logop$ = CurrentOperation$
    EndIf

	' ### Defined point of tray position ###
	LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "DEFINED_POINT", CX(Pallet(Tray, TrayCol, TrayRow)), CY(Pallet(Tray, TrayCol, TrayRow)), CU(Pallet(Tray, TrayCol, TrayRow)))
    
	Print "Resetting current chip offsets for new chip"
	ResetCurrentChipOffsets
	SetSpeedSetting("MoveWithoutChip")
	
	JumpToTray_camera(Tray, TrayCol, TrayRow)
	String move_sn_dir$
	move_sn_dir$ = TrayDirectory$ + "/images/Move_SN"
	

	' #### Robot position at image ###
	LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))

	
	If CurrentOperation$ <> "" Then

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
		RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN, False)
		GetChipFromTray = -ERR_V_DF_ALIGN ' Set an error code
		Exit Function
	EndIf
	
	If MeasurePlacement Then
		If GetChipPositionWithDF(0) Then
			' #### Chip position in tray ###
			LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", -999., -999., -999.)
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
	LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "ROBOT_AT_PICK", CX(Here), CY(Here), CU(Here))

	Print "Pickup position = "
	Print Here
	Print "Chip direction is currently ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	
	PumpOn
	Wait 1
	
	If Not isPressureOk Then
		RTS_error("GetChipFromTray: Bad pressure ", -ERR_PRESSURE, False)
		GetChipFromTray = -ERR_PRESSURE
	   	Exit Function
	EndIf
	If Not isVacuumOk Then
    	RTS_error("GetChipFromTray: Bad vacuum ", -ERR_VACUUM, False)
		GetChipFromTray = -ERR_VACUUM
		Exit Function
	EndIf

	If Not PickupFromTray Then
		RTS_error("GetChipFromTray: Cannot pick up chip from tray", -ERR_TRAY_PICK, False)
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
	LogTestMeasurements(logop$, "FromTray", Tray, TrayCol, TrayRow, "UFC_OFFSET", tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow))

	
	
	Print "Offsets for tray(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ") : (", tray_X(Tray, TrayCol, TrayRow), ",", tray_Y(Tray, TrayCol, TrayRow), ",", tray_U(Tray, TrayCol, TrayRow), ")"
	LogUFOffsets(Tray, TrayCol, TrayRow, 0, 0, CurrentOperation$)

	Print "Updating position files"
	UpdatePositionFiles
	Print "Updating current offset file"
	StoreCurrentChipOffset
	' Set to successful (maybe set to time stamp instead of "True" (-1)
	
	SetSpeedSetting("MoveWithChip")
	
	GetChipFromTray = -1
	
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
    
     If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		UpdateRobotLog$(op_ts$ + ": PlaceChipInTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")
	Else
		UpdateRobotLog$(CurrentOperation$ + ": PlaceChipInTray(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + ")")
    EndIf
    
    String logop$
    If CurrentOperation$ = "" Then
    	logop$ = op_ts$
	Else
		logop$ = CurrentOperation$
	EndIf
    
    ' ### Defined point of tray position ###
   	LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "DEFINED_POINT", CX(Pallet(Tray, TrayCol, TrayRow)), CY(Pallet(Tray, TrayCol, TrayRow)), CU(Pallet(Tray, TrayCol, TrayRow)))
	
    
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
   	LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "CURRENT_CHIP_OFFSET", CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3))
   	LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "LAST_CHIP_OFFSET", tray_X(Tray, TrayCol, TrayRow), tray_Y(Tray, TrayCol, TrayRow), tray_U(Tray, TrayCol, TrayRow))
   	LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_CORRECTION", ChipToChipCorrection(1), ChipToChipCorrection(2), ChipToChipCorrection(3))



	If Abs(GetBoundAnglePM45(ChipToChipCorrection(3))) > 3. Then
		RTS_error("PlaceChipInTray: U correction outside tolerance ", -ERR_BAD_TOLERANCE, False)
		PlaceChipInTray = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 2. Or Abs(ChipToChipCorrection(2)) > 2. Then
		RTS_error("PlaceChipInTray: X or Y correction outside tolerance ", -ERR_BAD_TOLERANCE, False)
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
	LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "ROBOT_AT_PLACE", CX(Here), CY(Here), CU(Here))

	Print "Chip currently at U = ", GetBoundAnglePM180(CU(Here) + HandChipOrientation(CHIPTYPE_NR))
	' Not sure this will work with chip in tray in wrong direction?
'	Go Here +X(ChipToChipCorrection(1)) +Y(ChipToChipCorrection(2)) +U(GetBoundAnglePM45(ChipToChipCorrection(3)))
	
	SetSpeedSetting("PickAndPlace")
	Print "Placing chip in tray"
	If Not DropToTray Then
		RTS_error("PlaceChipInTray: Could not place in tray ", -ERR_TRAY_PLACE, False)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	PumpOff
	
	If Not isChipInTrayTouch(Tray, TrayCol, TrayRow) Then
		RTS_error("PlaceChipInTray: Chip not placed correctly (touch check)", -ERR_TRAY_PLACE, False)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayCamera(Tray, TrayCol, TrayRow) Then
		RTS_error("PlaceChipInTray: Chip not placed correctly (vision check)", -ERR_TRAY_PLACE, False)
		PlaceChipInTray = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If MeasurePlacement Then
		If GetChipPositionWithDF(0) Then
			' #### Robot position at image ###
			LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
			' #### Chip position in tray ###
			LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(logop$, "ToTray", Tray, TrayCol, TrayRow, "CHIP_MEASURED", -999., -999., -999.)
		EndIf
	EndIf
	
	Print "Chip placed"
	SetSpeedSetting("MoveWithoutChip")
	ResetCurrentChipOffsets
	
	PlaceChipInTray = -1 ' Or timestamp
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

	' TODO JOE for errors need something if chip is in socket in wrong direction 
	If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		UpdateRobotLog$(op_ts$ + " : GetChipFromSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
	Else
		UpdateRobotLog$(CurrentOperation$ + " : GetChipFromSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
    EndIf
    
    ResetCurrentChipOffsets
    
 	SetSpeedSetting("MoveWithoutChip")
 			
	If CurrentOperation$ <> "" Then
		String Socket_Picture$
		Socket_Picture$ = Socket_take_picture$("Remove", op_ts$ + "_DAT" + Str$(DAT) + "_Skt" + Str$(Socket) + "_remove")
		WriteMLog(Socket_Picture$)
		UpdateRobotLog$("Picture of chip in socket before removal: " + Socket_Picture$)
	EndIf
	
	String logop$
    If CurrentOperation$ = "" Then
    	logop$ = op_ts$
	Else
		logop$ = CurrentOperation$
	EndIf
 	
	If Not SkipSocketCorrection Then ' Better to have global bool default to false
		Print("Measuring socket position for corrections")
		JumpToSocket_camera(DAT, Socket)
		
		' ### Point at which image is taken ###
		LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
		Wait 1
		SetSpeedSetting("PickAndPlace")
		' Adjust for socket position drift with DF camera
		
		If Not GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN, False)
			GetChipFromSocket = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		' ### Measured socket position ###
		LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		
		' ### Socket offsets ###
		LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "SOCKET_OFFSET", SocketOffset(1), SocketOffset(2), SocketOffset(3))
		
		' Check corrections are small	
		If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
			RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE, False)
			GetChipFromSocket = -ERR_BAD_TOLERANCE
			Exit Function
		EndIf
		
		If MeasurePlacement Then
		
			If GetChipPositionWithDF(0) Then
				' #### Chip position in tray ###
				LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
			Else
				LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
			EndIf
		EndIf
		
		
		Wait 1
	ElseIf MeasurePlacement Then
		
		' #### Robot position at image ###
		LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
	
		If GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			' ### Measured socket position ###
			LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		Else
			LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "SOCKET_MEASURED", -999., -999., -999.)
		EndIf
		
		If GetChipPositionWithDF(0) Then
			' #### Chip position in tray ###
			LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
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
		RTS_error("GetChipFromSocket: Bad pressure ", -ERR_PRESSURE, False)
		GetChipFromSocket = -ERR_PRESSURE
	   	Exit Function
	EndIf
	If Not isVacuumOk Then
  		RTS_error("GetChipFromSocket: Bad vacuum ", -ERR_VACUUM, False)
		GetChipFromSocket = -ERR_VACUUM
		Exit Function
	EndIf
	
	Print "Picking up with pick offset of ", PickOffset, " at U = ", Str$(GetBoundAnglePM180(CU(Here) + PickOffset))
	Go Here :U(GetBoundAnglePM180(CU(Here) + PickOffset))

	' ### Picking up with robot position ###
	LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "ROBOT_AT_PICK", CX(Here), CY(Here), CU(Here))
	
		
'	PumpOff
'	Print "DRY RUN - NOT PICKING UP"
	
'	Wait 5
'	' Pick up chip
	If Not PickupFromSocket Then
'			RTS_error("GetChipFromSocket: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, False)     
		GetChipFromSocket = -ERR_SOCKET_PICK
		Exit Function
	EndIf
	Print "Picked up chip from socket, moving to UF camera for offset measurement"
	SetSpeedSetting("MoveWithChip")
	
	' Go to UF camera for measuring offsets and storing in DAT_x/y/u variables.
	If Not FindChipAxisOffsetWithUF Then
		GetChipFromSocket = -ERR_V_UF_ALIGN
		RTS_error("GetChipFromSocket: Cannot get chip offsets from UF camera ", -ERR_V_UF_ALIGN, False)
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
	LogTestMeasurements(logop$, "FromSocket", 0, DAT, Socket, "UFC_OFFSET", CorrectedChipOffset(1), CorrectedChipOffset(2), CorrectedChipOffset(3))
		
	
	Print "Offsets for socket(", Str$(DAT), ",", Str$(Socket), ") : (", DAT_X(DAT, Socket), ",", DAT_Y(DAT, Socket), ",", DAT_U(DAT, Socket), ")"
	LogUFOffsets(0, 0, 0, DAT, Socket, CurrentOperation$)
	SetSpeedSetting("MoveWithChip")
	UpdatePositionFiles
	StoreCurrentChipOffset
	GetChipFromSocket = -1
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
			
	If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
		UpdateRobotLog$(op_ts$ + " : PlaceChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
	Else
		UpdateRobotLog$(CurrentOperation$ + " : PlaceChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")
    EndIf
    
    String logop$
    If CurrentOperation$ = "" Then
    	logop$ = op_ts$
	Else
		logop$ = CurrentOperation$
	EndIf
    
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
		LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
		
		If Not GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			RTS_error("PlaceChipInSocket: Could not get socket position ", -ERR_V_SOCKETALIGN, False)
			PlaceChipInSocket = -ERR_V_SOCKETALIGN
			Exit Function
		EndIf
		
		' ### Measured socket position ### 
		LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		
		' ### Socket offsets ####
		LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "SOCKET_OFFSET", SocketOffset(1), SocketOffset(2), SocketOffset(3))
		
		' Check corrections are small	
		If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
			RTS_error("PlaceChipInSocket: Socket corrections outside tolerance ", -ERR_BAD_TOLERANCE, False)
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
	LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "DEFINED_POINT", CX(Here), CY(Here), CU(Here))
	
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
   	LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "CURRENT_CHIP_OFFSET", CurrentChipOffset(1), CurrentChipOffset(2), CurrentChipOffset(3))
   	LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "LAST_CHIP_OFFSET", DAT_X(DAT, Socket), DAT_Y(DAT, Socket), DAT_U(DAT, Socket))
   	LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "CHIP_CORRECTION", ChipToChipCorrection(1), ChipToChipCorrection(2), ChipToChipCorrection(3))
		
	' Logging chip to chip corection
	If Not SkipChipToChipCorrection Then
		PlacePositions(19) = ChipToChipCorrection(1)
		PlacePositions(20) = ChipToChipCorrection(2)
		PlacePositions(21) = ChipToChipCorrection(3)
	EndIf
	
	If Abs(ChipToChipCorrection(3)) > 3. Then
		RTS_error("PlaceChipInSocket: Chip position U correction outside tolerance ", -ERR_BAD_TOLERANCE, False)
		PlaceChipInSocket = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 1. Or Abs(ChipToChipCorrection(2)) > 1. Then
		RTS_error("PlaceChipInSocket: Chip position X or Y corrections outside tolerance ", -ERR_BAD_TOLERANCE, False)
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
	LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_PLACE", CX(Here), CY(Here), CU(Here))
		
	Print "Placing chip in socket"
	
	If Not PlaceInSocket Then
		RTS_error("PlaceChipInSocket: Cannot place chip in socket ", -ERR_SOCKET_PLACE, False)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf

	If Not isChipInSocketTouch(DAT, Socket) Then
		RTS_error("PlaceChipInSocket: Chip not placed correctly (touch check)", -ERR_SOCKET_PLACE, False)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf

	If Not isChipInSocketCamera(DAT, Socket) Then
		RTS_error("PlaceChipInSocket: Chip not placed correctly (vision check)", -ERR_SOCKET_PLACE, False)
		PlaceChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf

	
	If CurrentOperation$ <> "" Then
		LogSocketPlacements(DAT, Socket, CurrentOperation$)
	Else
		LogSocketPlacements(DAT, Socket, op_ts$)
	EndIf
	
	' Do alignment check of chip in socket after insertion
	JumpToSocket_camera(DAT, Socket)
	SetSpeedSetting("MoveWithoutChip")
	
	If MeasurePlacement Then
		' #### Robot position at image ###
		LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE", CX(Here), CY(Here), CU(Here))
	
		If GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
			' ### Measured socket position ###
			LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", SockPos(1), SockPos(2), SockPos(3))
		Else
			LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED", -999., -999., -999.)
		EndIf
		
		If GetChipPositionWithDF(0) Then
			' #### Chip position in tray ###
			LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED", ChipPos(1), ChipPos(2), ChipPos(3))
		Else
			LogTestMeasurements(logop$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED", -999., -999., -999.)
		EndIf
	EndIf
	
 	SetSpeedSetting("MoveWithoutChip")
 			
	If CurrentOperation$ <> "" Then
		String Socket_Picture$
		Socket_Picture$ = Socket_take_picture$("Insert", op_ts$ + "_DAT" + Str$(DAT) + "_Skt" + Str$(Socket) + "_insert")
		WriteMLog(Socket_Picture$)
		UpdateRobotLog$("Picture of chip in socket after insert: " + Socket_Picture$)
	EndIf
	
	Print "Chip placed"
	PumpOff
	ResetCurrentChipOffsets
	PlaceChipInSocket = -1
	
Fend

' Below are individual occupancy checks, batch occupancy removed to integration side

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

Function RotateTrayChip(Tray As Integer, TrayCol As Integer, TrayRow As Integer, TgtOrientation As Double) As Int64
	'''
	' Rotates a chip to the desired orientation
	'' Args
	' Tray [Int] - Tray pallet number
	' TrayCol [Int]
	' TrayRow [Int]
	' TgtOrientation [Double] - Orientation should be expressed as exactly 0, 90,180, -90. Minor corrections will be accounted for
	'''
	RotateTrayChip = 0
	Print "This function is not implemented yet"
	Exit Function

	Print "RotateTrayChip(", Str$(Tray), ",", Str$(TrayCol), ",", Str$(TrayRow), ",", Str$(TgtOrientation), ")"
	RotateTrayChip = 0
    SubError = 0
    
     If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
    	UpdateRobotLog$(op_ts$ + " RotateTrayChip(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + "," + Str$(TgtOrientation) + ")")
    Else
    	UpdateRobotLog$(CurrentOperation$ + " RotateTrayChip(" + Str$(Tray) + "," + Str$(TrayCol) + "," + Str$(TrayRow) + "," + Str$(TgtOrientation) + ")")
    EndIf
    

	JumpToTray(Tray, TrayCol, TrayRow)
	
	SubError = GetChipFromTray(Tray, TrayCol, TrayRow)
	If Not SubError Then
		RTS_error("RotateTrayChip: Could not pick up chip from tray", ERR_TRAY_PICK, False)
		RotateTrayChip = -ErrorCode
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
		RTS_error("RotateTrayChip: U correction outside tolerance ", -ERR_BAD_TOLERANCE, False)
		RotateTrayChip = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	If Abs(ChipToChipCorrection(1)) > 2. Or Abs(ChipToChipCorrection(2)) > 2. Then
		RTS_error("RotateTrayChip: X or Y correction outside tolerance ", -ERR_BAD_TOLERANCE, False)
		RotateTrayChip = -ERR_BAD_TOLERANCE
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
		RTS_error("RotateTrayChip: Could not place in tray ", -ERR_TRAY_PLACE, False)
		RotateTrayChip = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayTouch(Tray, TrayCol, TrayRow) Then
		RTS_error("RotateTrayChip: Chip not placed correctly (touch check)", -ERR_TRAY_PLACE, False)
		RotateTrayChip = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	If Not isChipInTrayCamera(Tray, TrayCol, TrayRow) Then
		RTS_error("RotateTrayChip : Chip not placed correctly (vision check)", -ERR_TRAY_PLACE, False)
		RotateTrayChip = -ERR_TRAY_PLACE
		Exit Function
	EndIf
	
	Print "Chip placed"
	SetSpeedSetting("MoveWithoutChip")
	Wait 2
	ResetCurrentChipOffsets
	RotateTrayChip = -1

Fend


' No rotate at socket function as the hand should not be put down in orientations other than the predefined one due to risk of collision
Function ReseatChipInSocket(DAT As Integer, Socket As Integer, AlignmentPremeasured As Boolean) As Int64

	ReseatChipInSocket = -ERR_RESEAT
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "Reseat_" + ts$
			
		' Check valid operation
		If Not CheckValidSocketIndex(DAT, Socket) Then
			RTS_error("Invalid target socket (" + Str$(DAT) + "," + Str$(Socket) + ")", ERR_BAD_COMMAND, False)
			ReseatChipInSocket = -ErrorCode
			
			If CurrentOperation$ = "Reseat_" + ts$ Then
				ResetOperation
			EndIf
			Exit Function
		EndIf
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + " :  ReseatChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + "," + Str$(AlignmentPremeasured) + ")")

	Integer DFChipAlignCorrection
	DFChipAlignCorrection = 1

	Motor On
	PumpOn
	On 12
	SelectSite("InFunctionDefinePallets")

	'op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
   	'UpdateRobotLog$(op_ts$ + " ReseatChipInSocket(" + Str$(DAT) + "," + Str$(Socket) + ")")

	Print "ReseatChipInSocket(", DAT, ",", Socket, ",", AlignmentPremeasured, ")"
			
	If (Not AlignmentPremeasured) Then
		CSAlign(1) = 0
		CSAlign(2) = 0
		CSAlign(3) = 0
		CSAlign(4) = 0
		CSAlign(5) = 0
	EndIf
	
	If (Abs(CSAlign(1)) + Abs(CSAlign(2)) + Abs(CSAlign(3)) = 0) Then
		Print "Chip socket alignment not yet measured, measuring now"
		If Not GetChipInSocketAlignment(DAT, Socket) Then
			' Cannot get chip socket alignment
			' Continue to next part?
			DFChipAlignCorrection = 0
			Print "CANNOT GET CHIP SOCKET ALIGNMENT: Will try to just reseat without correction"
			UpdateRobotLog$(CurrentOperation$ + " : WARNING: Cannot get chip alignment, will not apply correction  ")
		EndIf
		
		' Could add in orientation check here, or maybe in function above
		
		' Check the measurement was reasonable	
		If (Abs(CSAlign(1)) > 1 Or Abs(CSAlign(2)) > 1 Or Abs(GetBoundAnglePM45(CSAlign(3))) > 2.5) Then
			UpdateRobotLog$(CurrentOperation$ + " :  (" + Str$(CSAlign(1)) + "," + Str$(CSAlign(2)) + "," + Str$(CSAlign(3)) + "," + Str$(CSAlign(4)) + "," + Str$(CSAlign(5)) + ")")
			RTS_error("ReseatChipInSocket: Alignment out of tolerance! ", -ERR_V_CHIPSOCKALIGN, False)
			' Think about if this needs to be an error or just move onto non-corrected reseat?
			ReseatChipInSocket = -ERR_V_CHIPSOCKALIGN
			PumpOff
			Exit Function
		EndIf
		
	Else
		Print "ALIGNMENT PREVIOUSLY MEASURED BEFORE CALL OF RESEAT COMMAND"
		UpdateRobotLog$(CurrentOperation$ + " : ALIGNMENT MEASURED BEFORE RESEAT FUNCTION CALL ")
	EndIf

	Double PriorAlignment(5) ' Store for check later 
	PriorAlignment(1) = CSAlign(1)
	PriorAlignment(2) = CSAlign(2)
	PriorAlignment(3) = CSAlign(3)
	PriorAlignment(4) = CSAlign(4)
	PriorAlignment(5) = CSAlign(5)
	
	' Get the alignment target values
	If Not GetTargetAlignments Then
		RTS_error("ReseatChipInSocket: Cannot get target alignment from file ", -ERR_FILESYSTEM, False)
		ReseatChipInSocket = -ERR_FILESYSTEM
		Exit Function
	EndIf
			
	If Abs(TCSAlign_X(DAT, Socket)) + Abs(TCSAlign_Y(DAT, Socket)) + Abs(TCSAlign_U(DAT, Socket)) = 0 Then
		Print "No target alignment set, will not attempt realignment"
		DFChipAlignCorrection = 0
	Else
		Print "Target chip-socket alignment for DAT ", DAT, " socket ", Socket, " :"
		Print "Delta X = ", TCSAlign_X(DAT, Socket)
		Print "Delta Y = ", TCSAlign_Y(DAT, Socket)
		Print "Delta U = ", TCSAlign_U(DAT, Socket)
		DFChipAlignCorrection = 1
	EndIf
		
	' Center over socket (probably already should be	
	Print "Moving to socket point"
	JumpToSocket(DAT, Socket)
	
	SetSpeedSetting("PickAndPlace")
	Print("Will align hand with chip to pick up")

	' Center over chip
	Move Here :X(ChipPos(1)) :Y(ChipPos(2)) +U(GetBoundAnglePM45(ChipPos(3)) - GetBoundAnglePM45(CU(Here)))
	Print Here
	
	Print "Picking up chip"
	' Now pick up the chip
	If Not PickupFromSocket Then
		RTS_error("ReseatChipInSocket: Cannot pick up chip from socket ", -ERR_SOCKET_PICK, False)
		ReseatChipInSocket = -ERR_SOCKET_PICK
		Exit Function
	EndIf
	Print "Picked up chip from socket"
			
	If DFChipAlignCorrection = 1 Then
		UpdateRobotLog$(CurrentOperation$ + " :  Reseating at target chip position")
		Print "Realigning chip to stored target position"

		Double align_x, align_y, align_u
		' Should this be rotated by socket drift?
		' SockPos(3) should be stored currently from alignment measurement
		' U offset should be  at most a couple of degrees, rotation here should be very small, will ignore for now
		align_x = TCSAlign_X(DAT, Socket) - CSAlign(1)
		align_y = TCSAlign_Y(DAT, Socket) - CSAlign(2)
		align_u = TCSAlign_U(DAT, Socket) - CSAlign(3)
		
		Move Here +X(align_x) +Y(align_y) +U(align_u) ' +U(GetBoundAnglePM45(TCSAlign_U(DAT, Socket)))
		' Could this have an edge case with small u near to motion boundary? Points shouldn't really be taught so 360deg rotations needed
		Print Here
		
	EndIf
	
	' Now replace the chip
	Print "Placing chip back in socket"

	If Not PlaceInSocket Then
		RTS_error("ReseatChipInSocket: Cannot place chip in socket ", -ERR_SOCKET_PLACE, False)
		ReseatChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf
	
	PumpOff
	
	If Not isChipInSocketTouch(DAT, Socket) Then
		RTS_error("ReseatChipInSocke: Chip not placed correctly (touch check)", -ERR_SOCKET_PLACE, False)
		ReseatChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf

	If Not isChipInSocketCamera(DAT, Socket) Then
		RTS_error("ReseatChipInSocket: Chip not placed correctly (vision check)", -ERR_SOCKET_PLACE, False)
		ReseatChipInSocket = -ERR_SOCKET_PLACE
		Exit Function
	EndIf
	
    Print "Chip placed"
    
    If DFChipAlignCorrection = 1 Then
	    Print "Recheck alignment"
	    UpdateRobotLog$(CurrentOperation$ + " :  Checking alignment again ")
	   	Print "Alignment not yet measured, measuring now"
		If Not GetChipInSocketAlignment(DAT, Socket) Then
			UpdateRobotLog$(CurrentOperation$ + " : WARNING Cannot check alignment ")
		EndIf
		
		' Could add in orientation check here, or maybe in function above
		
		' Check the measurement was reasonable	
		If (Abs(CSAlign(1)) > 1 Or Abs(CSAlign(2)) > 1 Or Abs(GetBoundAnglePM45(CSAlign(3))) > 2.5) Then
			RTS_error("ReseatChipInSocket: Alignment out of tolerance! ", -ERR_V_CHIPSOCKALIGN, False)
			' Think about if this needs to be an error or just move onto non-corrected reseat?
			ReseatChipInSocket = -ERR_V_CHIPSOCKALIGN
			PumpOff
			Exit Function
		EndIf
		
		'	
		align_x = TCSAlign_X(DAT, Socket) - CSAlign(1)
		align_y = TCSAlign_Y(DAT, Socket) - CSAlign(2)
		align_u = TCSAlign_U(DAT, Socket) - CSAlign(3)
		Double PriorInacc, PriorInaccX, PriorInaccY, PriorInaccU
		Double PostInacc, PostInaccX, PostInaccY, PostInaccU
		
		PriorInaccX = Abs(PriorAlignment(4) - TCSAlign_X(DAT, Socket))
		PriorInaccY = Abs(PriorAlignment(5) - TCSAlign_Y(DAT, Socket))
		PriorInaccU = Abs(PriorAlignment(3) - TCSAlign_U(DAT, Socket))
		' Not quad sum of X + Y as innacuracy in a given direction is probably more bad than diagonally 
		' Probably should have some normalising factor based on impact, U may be allowed more variation as a degree
		PriorInacc = PriorInaccX + PriorInaccY + PriorInaccU
		
		PostInaccX = Abs(CSAlign(4) - TCSAlign_X(DAT, Socket))
		PostInaccY = Abs(CSAlign(5) - TCSAlign_Y(DAT, Socket))
		PostInaccU = Abs(CSAlign(3) - TCSAlign_U(DAT, Socket))
		PostInacc = PostInaccX + PostInaccY + PostInaccU
		Print "Prior alignment and innacuracy:"
		Print "DelX (uncorrected)", PriorAlignment(1)
		Print "DelY (uncorrected)", PriorAlignment(2)
		Print "DelX      ", PriorAlignment(4), ", ", PriorInaccX
		Print "DelY      ", PriorAlignment(5), ", ", PriorInaccY
		Print "DelU      ", PriorAlignment(3), ", ", PriorInaccU

		Print "Post alignment and innacuracy:"
		Print "DelX (uncorrected)", CSAlign(1)
		Print "DelY (uncorrected)", CSAlign(2)
		Print "DelX      ", CSAlign(4), ", ", PriorInaccX
		Print "DelY      ", CSAlign(5), ", ", PriorInaccY
		Print "DelU      ", CSAlign(3), ", ", PriorInaccU

		Print "Target alignment:"
		Print "DelX      ", TCSAlign_X(DAT, Socket)
		Print "DelY      ", TCSAlign_Y(DAT, Socket)
		Print "DelU      ", TCSAlign_U(DAT, Socket)
		
		Print "Pior Innacuracy :, PriorInacc"
		Print "Post Innacuracy :, PostInacc"
		
		UpdateRobotLog$(CurrentOperation$ + " : Target alignment " + Str$(TCSAlign_X(DAT, Socket)) + "," + Str$(TCSAlign_Y(DAT, Socket)) + "," + Str$(TCSAlign_U(DAT, Socket)))
		UpdateRobotLog$(CurrentOperation$ + " : Prior alignment  " + Str$(PriorAlignment(4)) + "," + Str$(PriorAlignment(5)) + "," + Str$(PriorAlignment(3)))
		UpdateRobotLog$(CurrentOperation$ + " : Post alignment   " + Str$(CSAlign(4)) + "," + Str$(CSAlign(5)) + "," + Str$(CSAlign(3)))
	
		
	EndIf
	
	SetSpeedSetting("MoveWithoutChip")
	Wait 2

	PumpOff
	
	ResetOperation
	ReseatChipInSocket = Val(ts$)
	UpdateRobotLog$(CurrentOperation$ + " : Chip resat successfully")
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
	
	JumpToSocket_camera(DAT_nr, Socket_nr)
		
	SocketOpenAndClose = -1
	
Fend


