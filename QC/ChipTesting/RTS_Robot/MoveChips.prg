#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function MoveChipFromTrayToTray(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	MoveChipFromTrayToTray = 0
	ErrorCode = 0
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	ResetCurrentChipOffsets
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	op_ts$ = ts$
	
	CurrentOperation$ = "MoveT2T_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromTrayToTray(" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + "," + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ") " + ts$)

	bnl_idx(1) = mlog_nr
	bnl_idx(2) = SrcTray
	bnl_idx(3) = SrcTrayCol
	bnl_idx(4) = SrcTrayRow
	bnl_idx(5) = TgtTray
	bnl_idx(6) = TgtTrayCol
	bnl_idx(7) = TgtTrayRow
	bnl_idx(8) = 0
	bnl_idx(9) = 0
	bnl_idx(10) = 0
	bnl_idx(11) = 0
	
	OpenMLog(ts$)
	MLogIdx
	' Check valid operation
	If Not CheckValidTrayIndex(SrcTray, SrcTrayCol, SrcTrayRow) Then
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices")

	SetSpeedSetting("MoveWithoutChip")

	Motor On
	On 12

	' Check occupancy	
	Int32 Occupancy
	Occupancy = -1
	If Not SkipOccupancyChecks Then
		UpdateRobotLog$(CurrentOperation$ + ": Checking occupancies")
		' Check target first
		Occupancy = TrayPositionOccupied(TgtTray, TgtTrayCol, TgtTrayRow)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 0 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error(("Target tray position occupancy check value = " + Str$(Occupancy)), ERR_OBSTRUCTION, True)
			Else
				RTS_error(("Target tray position occupied, occupancy check value = " + Str$(Occupancy)), ERR_V_OCCUPIED, True)
			EndIf
			MoveChipFromTrayToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
			
		Occupancy = TrayPositionOccupied(SrcTray, SrcTrayCol, SrcTrayRow)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, True)
			Else
				RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, True)
			EndIf
			MoveChipFromTrayToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")
	Else
		UpdateRobotLog$(CurrentOperation$ + ": Skipping occcupancy check")
	EndIf
	SetSpeedSetting("MoveWithoutChip")

	' If chip needs to be in correct orientation here, rotate the chip?	
	
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source tray position (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")")
	' Need to get result from subprocess?
	SubError = GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow)
	If Not SubError Then
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK, True)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	UpdateRobotLog$(CurrentOperation$ + ": Offsets from tray position (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ") calculated as (" + Str$(CorrectedChipOffset(1)) + "," + Str$(CorrectedChipOffset(2)) + "," + Str$(CorrectedChipOffset(3)) + ")")
	
	' While at the UF camera, do any pin analysis	
	' First need to recenter	

	String PinImages$(3)
	If DoPinAnalysis Then
		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
		UFRecenter ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
		
	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())

	 	Print "UFPinAnalyisOutput = ", SubError
	 	Int32 i
	 	Print "Pin analysis images:"
	 	For i = 1 To 3
	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
	 	Next
		If SubError Then
			RTS_error("Pin analysis failure", ERR_PINS, True)
			MoveChipFromTrayToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
	EndIf
	Wait 1
	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")

	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE, True)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
'	UpdateRobotLog$(CurrentOperation$ + ": DefaultSkipChipCor = " + Str$(DefaultSkipChipCor) + ", SkipChipToChipCorrection = " + Str$(SkipChipToChipCorrection))
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset (Should be reset) = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtTray position offset = (" + Str$(tray_X(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_Y(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_U(TgtTray, TgtTrayCol, TgtTrayRow)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At Tray      = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target tray position")
	
	SetSpeedSetting("MoveWithoutChip")

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2T) command complete:")
	ResetOperation
	MoveChipFromTrayToTray = Val(ts$)	' -1
	CloseMLog("DONE")
Fend

Function MoveChipFromTrayToSocket(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtDAT As Integer, TgtSocket As Integer) As Int64
	MoveChipFromTrayToSocket = 0
	ErrorCode = 0
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	ResetCurrentChipOffsets
	
	String ts$ ', opName$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	op_ts$ = ts$
	CurrentOperation$ = "MoveT2S_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromTrayToSocket(" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + "," + Str$(TgtDAT) + "," + Str$(TgtSocket) + ") " + ts$)
	
	bnl_idx(1) = mlog_nr
	bnl_idx(2) = SrcTray
	bnl_idx(3) = SrcTrayCol
	bnl_idx(4) = SrcTrayRow
	bnl_idx(5) = 0
	bnl_idx(6) = 0
	bnl_idx(7) = 0
	bnl_idx(8) = 0
	bnl_idx(9) = 0
	bnl_idx(10) = TgtDAT
	bnl_idx(11) = TgtSocket
	
	OpenMLog(ts$)
	MLogIdx
	' Check valid operation
	If Not CheckValidTrayIndex(SrcTray, SrcTrayCol, SrcTrayRow) Then
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	If Not CheckValidSocketIndex(TgtDAT, TgtSocket) Then
		RTS_error("Invalid target socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices")
	
	SetSpeedSetting("MoveWithoutChip")
	
	Motor On
	On 12
	
	' Check occupancy
	Int32 Occupancy
	Occupancy = -1
	If Not SkipOccupancyChecks Then
		UpdateRobotLog$(CurrentOperation$ + ": Checking occupancies")
		Occupancy = SocketPositionOccupied(TgtDAT, TgtSocket)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 0 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Target socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, True)
			Else
				RTS_error("Target socket position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED, True)
			EndIf
			MoveChipFromTrayToSocket = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
	
		Occupancy = TrayPositionOccupied(SrcTray, SrcTrayCol, SrcTrayRow)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, True)
			Else
				RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, True)
			EndIf
			MoveChipFromTrayToSocket = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		
		UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")
	Else
		UpdateRobotLog$(CurrentOperation$ + ": Skipping occcupancy check")
	EndIf
	SetSpeedSetting("MoveWithoutChip")
	
	' Get chip from tray	
		
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source tray position")
	' Need to get result from subprocess?
	SubError = GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow)
	If Not SubError Then
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK, True)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter
	String PinImages$(3)
	If DoPinAnalysis Then
		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
		UFRecenter ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
		
	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())

	 	Print "UFPinAnalyisOutput = ", SubError
	 	Int32 i
	 	Print "Pin analysis images:"
	 	For i = 1 To 3
	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
	 	Next
		If SubError Then
			RTS_error("Pin analysis failure", ERR_PINS, True)
			MoveChipFromTrayToSocket = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
	EndIf
	
	Wait 2
			
	' Place chip in socket	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target socket position")

	SubError = PlaceChipInSocket(TgtDAT, TgtSocket)
	If Not SubError Then
		RTS_error("Could not place chip in socket", ERR_SOCKET_PLACE, True)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
'	UpdateRobotLog$(CurrentOperation$ + ": DefaultSkipChipCor = " + Str$(DefaultSkipChipCor) + ", SkipChipToChipCorrection = " + Str$(SkipChipToChipCorrection))
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset (Should be reset) = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtSock position offset = (" + Str$(DAT_X(TgtDAT, TgtSocket)) + "," + Str$(DAT_Y(TgtDAT, TgtSocket)) + "," + Str$(DAT_U(TgtDAT, TgtSocket)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At socket    = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target socket position")
	
	SetSpeedSetting("MoveWithoutChip")
	
	
	
	Int64 Result
	
	Result = CheckSocketPlacement(TgtDAT, TgtSocket, 0, 0) ' Comment out for auto reseat
	'Result = CheckSocketPlacement(TgtDAT, TgtSocket, 1, 1) ' ' Uncomment for auto reseat
	If Result = -ERR_V_CHIPSOCKALIGN Then
		RTS_error("Post placement alignment check is bad, may need manually reseat", ERR_V_CHIPSOCKALIGN, True)
		JumpToCamera
		ResetOperation
		Exit Function
	ElseIf Result < 0 Then
		RTS_error("Post placement alignment check (and potential reseat) is bad", ERR_SOCKET_PLACE, True)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2S) command complete:")
	ResetOperation
	MoveChipFromTrayToSocket = Val(ts$)
	CloseMLog("DONE")
Fend

Function MoveChipFromSocketToTray(SrcDAT As Integer, SrcSocket As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	MoveChipFromSocketToTray = 0
	ErrorCode = 0 ' Might be better to set these to 1 (-1 is TRUE in BASIC) for initialization 
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	ResetCurrentChipOffsets
	
	String ts$ ' , opName$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	op_ts$ = ts$
	CurrentOperation$ = "MoveS2T_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromSocketToTray(" + Str$(SrcDAT) + "," + Str$(SrcSocket) + "," + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ") " + ts$)
	
	bnl_idx(1) = mlog_nr
	bnl_idx(2) = 0
	bnl_idx(3) = 0
	bnl_idx(4) = 0
	bnl_idx(5) = TgtTray
	bnl_idx(6) = TgtTrayCol
	bnl_idx(7) = TgtTrayRow
	bnl_idx(8) = SrcDAT
	bnl_idx(9) = SrcSocket
	bnl_idx(10) = 0
	bnl_idx(11) = 0
		
	OpenMLog(ts$)
	MLogIdx
	' Check valid operation
	If Not CheckValidSocketIndex(SrcDAT, SrcSocket) Then
		RTS_error("Invalid source socket (" + Str$(SrcDAT) + "," + Str$(SrcSocket) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND, True)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices")

	SetSpeedSetting("MoveWithoutChip")

	Motor On
	On 12

	' Check occupancy
	Int32 Occupancy
	Occupancy = -1
	If Not SkipOccupancyChecks Then
		UpdateRobotLog$(CurrentOperation$ + ": Checking occupancies")
		Occupancy = TrayPositionOccupied(TgtTray, TgtTrayCol, TgtTrayRow)
		If Occupancy <> 0 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Target tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, True)
			Else
				RTS_error("Target tray position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED, True)
			EndIf
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		
		Occupancy = SocketPositionOccupied(SrcDAT, SrcSocket)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, True)
			Else
				RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, True)
			EndIf
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		
		UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")
	Else
		UpdateRobotLog$(CurrentOperation$ + ": Skipping occcupancy check")
	EndIf
	
	SetSpeedSetting("MoveWithoutChip")

	' Chips are in the right place, lets get the chip from the socket
	
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source socket position")
	' Need to get result from subprocess?
	SubError = GetChipFromSocket(SrcDAT, SrcSocket)
	If Not SubError Then
		RTS_error("Could not get chip from socket - GetChipFromSocket=" + Str$(SubError), ERR_SOCKET_PICK, True)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and socket offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter	

	String PinImages$(3)
	If DoPinAnalysis Then
		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
		UFRecenter ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
		
	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())

	 	Print "UFPinAnalyisOutput = ", SubError
	 	Int32 i
	 	Print "Pin analysis images:"
	 	For i = 1 To 3
	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
	 	Next
		If SubError Then
			RTS_error("Pin analysis failure", ERR_PINS, True)
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
	EndIf
	
	' Place chip in tray
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")
	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE, True)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
' 	UpdateRobotLog$(CurrentOperation$ + ": DefaultSkipChipCor = " + Str$(DefaultSkipChipCor) + ", SkipChipToChipCorrection = " + Str$(SkipChipToChipCorrection))
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset (Should be reset) = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtTray position offset = (" + Str$(tray_X(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_Y(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_U(TgtTray, TgtTrayCol, TgtTrayRow)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At Tray      = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")
	
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target tray position")
	JumpToTray_camera(TgtTray, TgtTrayCol, TgtTrayRow)

	SetSpeedSetting("MoveWithoutChip")

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (S2T) command complete:")
	ResetOperation
	MoveChipFromSocketToTray = Val(ts$) ' -1
	CloseMLog("DONE")
Fend

''' When outside of a move function, reset so that the subfunctions can be tested
Function ResetOperation
	CurrentOperation$ = "NA_" + FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
Fend


''' Diagnostic checks for end of Move commands - might place this in the lower level
' wanted separate to Move command for better error handling in integration code.
Function CheckTrayPlacement(TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64

	CheckTrayPlacement = 0
	ErrorCode = 0 ' Might be better to set these to 1 (-1 is TRUE in BASIC) for initialization 
	SubError = 0
	
	
	'ResetCurrentChipOffsets
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	If CurrentOperation$ = "" Then
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "CheckAtT_" + ts$
	EndIf

	UpdateRobotLog$(CurrentOperation$ + ": CheckTrayPlacement(" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")")

	' Check valid operation
	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND, False)
		CheckTrayPlacement = -ErrorCode
		If CurrentOperation$ = "CheckAtT_" + ts$ Then
			ResetOperation
        EndIf
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices")

	Motor On
	On 12
		
	UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
	
	JumpToTray_camera(TgtTray, TgtTrayCol, TgtTrayRow)
	' First just check chip orientation
	Double MeasuredDirection, MeasuredOrientation ' , OrientationOffset
	MeasuredDirection = FindChipDirectionWithDF
	If MeasuredDirection < -900. Then
		RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN, False) ' Or should this be error tray palce
		CheckTrayPlacement = -ErrorCode
		If CurrentOperation$ = "CheckAtT_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf
	
	' Get any offset from 0,90,180 etc
	Double dTU
	dTU = DiffAnglePM180(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow)), RoundAngleTo90(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow))))
	MeasuredOrientation = RoundAngleTo90(DiffAnglePM180(MeasuredDirection, dTU))

	If Abs(DiffAnglePM180(TrayOrientation, MeasuredOrientation)) > 5. Then
		RTS_error("Chip not put back in tray in expected orientation", ERR_TRAY_PLACE, False)
		CheckTrayPlacement = -ErrorCode
		If CurrentOperation$ = "CheckAtT_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")

	SetSpeedSetting("MoveWithoutChip")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placement check at tray complete")
	ResetOperation
	CheckTrayPlacement = Val(ts$)

Fend

Function CheckSocketPlacement(TgtDAT As Integer, TgtSocket As Integer, DoMeasurePlace As Integer, AutoReseat As Integer) As Int64
 	CheckSocketPlacement = 0
	ErrorCode = 0
	SubError = 0
	
	'ResetCurrentChipOffsets 'Don't think this is needed, only DF measurements not UF measurements
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	If CurrentOperation$ = "" Then
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "CheckAtS_" + ts$
    EndIf
	
	UpdateRobotLog$(CurrentOperation$ + " : CheckSocketPlacement(" + Str$(TgtDAT) + "," + Str$(TgtSocket) + "," + Str$(DoMeasurePlace) + ")")

	' Check valid operation
	If Not CheckValidSocketIndex(TgtDAT, TgtSocket) Then
		RTS_error("Invalid target socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")", ERR_BAD_COMMAND, False)
		CheckSocketPlacement = -ErrorCode
		
		If CurrentOperation$ = "CheckAtS_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf
	
	Motor On
	On 12
	
'	 Do any chip placement diagnostics here
	UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
	
	JumpToSocket_camera(TgtDAT, TgtSocket)
	
	' May not be necessary  if just called in T2S command
	If Not GetSocketPositionWithDF(TgtDAT, TgtSocket) Then ', ByRef SockCorr()) Then
		RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN, False)
		CheckSocketPlacement = -ERR_V_CHIPSOCKALIGN
		If CurrentOperation$ = "CheckAtS_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf
	
	' Do we have socket offsets stored? need to get these?
	Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
	
	' First just check chip orientation
	Double MeasuredDirection ' , OrientationOffset
	MeasuredDirection = FindChipDirectionWithDF
	If MeasuredDirection < -900. Then
		RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN, False) ' Or should this be error tray palce
		CheckSocketPlacement = -ERR_V_DF_ALIGN
		If CurrentOperation$ = "CheckAtS_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf
	
	' While accounting for U offset of socket from drift in defined position, and chip orientation as expected at socket
	' What is the difference to the measured direction?
	If Abs(DiffAnglePM180(MeasuredDirection, (CU(P(PSocket(TgtDAT, TgtSocket))) + HandChipOrientation(CHIPTYPE_NR) + SocketOffset(3))) > 5) Then
		RTS_error("Chip not put back in tray in expected orientation", ERR_SOCKET_PLACE, False)
		CheckSocketPlacement = -ERR_SOCKET_PLACE
		If CurrentOperation$ = "CheckAtS_" + ts$ Then
			ResetOperation
		EndIf
		Exit Function
	EndIf

	UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")
	
	' Below is heavily lighting dependent
	Int32 Ntries, try
	If AutoReseat = 1 Then
		Ntries = 2
	Else
		Ntries = 1
	EndIf
	
	
	If DoMeasurePlace = 1 Then
		Boolean CompareWithTarget
		CompareWithTarget = True
		
		For try = 1 To Ntries

		UpdateRobotLog$(CurrentOperation$ + ":WARNING precise placement measurement for diagnostics is experimental and may not work in all lighting conditions")
		
		CSAlign(1) = 0
		CSAlign(2) = 0
		CSAlign(3) = 0
		CSAlign(4) = 0
		CSAlign(5) = 0
	
		' Get the alignment target values
		If Abs(TCSAlign_X(TgtDAT, TgtSocket)) + Abs(TCSAlign_Y(TgtDAT, TgtSocket)) + Abs(TCSAlign_U(TgtDAT, TgtSocket)) = 0 Then
		
			If Not GetTargetAlignments Then
				RTS_error("ReseatChipInSocket: Cannot get target alignment from file ", -ERR_FILESYSTEM, False)
				CheckSocketPlacement = -ERR_FILESYSTEM
				Exit Function
			EndIf
		
			If Abs(TCSAlign_X(TgtDAT, TgtSocket)) + Abs(TCSAlign_Y(TgtDAT, TgtSocket)) + Abs(TCSAlign_U(TgtDAT, TgtSocket)) = 0 Then
				UpdateRobotLog$(CurrentOperation$ + ":WARNING No target alignment stored for socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")")
				CompareWithTarget = False
			EndIf
		
		EndIf
			
			

		

		If Not GetChipInSocketAlignment(TgtDAT, TgtSocket) Then
			UpdateRobotLog$(CurrentOperation$ + ": WARNING - cannot get chip position in socket accurately")
			Exit For
		Else
			If Abs(CSAlign(4)) > 2. Or Abs(CSAlign(5)) > 2. Or Abs(CSAlign(3)) > 3. Then
				RTS_error("Large alignment offset between chip and socket", ERR_SOCKET_PLACE, False)
				CheckSocketPlacement = -ERR_SOCKET_PLACE
				
				If CurrentOperation$ = "CheckAtS_" + ts$ Then
					ResetOperation
				EndIf
				Exit Function
			EndIf
			LogDFSocketMeasurements(TgtDAT, TgtSocket, CurrentOperation$)
			Print "DF_SocketPosition:", SockPos(1), ",", SockPos(2), ",", SockPos(3)
			Print "DF_ChipPosition:", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3)
			Print "DF_ChipOffset:", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3)
			Print "(U corrected): ", CSAlign(4), ", ", CSAlign(5), ", ", CSAlign(3)
			UpdateRobotLog$(CurrentOperation$ + ": Chip Socket alignment measured:")
			UpdateRobotLog$(CurrentOperation$ + ":  DF_SocketPosition:" + Str$(SockPos(1)) + "," + Str$(SockPos(2)) + "," + Str$(SockPos(3)))
			UpdateRobotLog$(CurrentOperation$ + ":  DF_ChipPosition:" + Str$(ChipPos(1)) + "," + Str$(ChipPos(2)) + "," + Str$(ChipPos(3)))
			UpdateRobotLog$(CurrentOperation$ + ":  DF_ChipOffset:" + Str$(CSAlign(1)) + "," + Str$(CSAlign(2)) + "," + Str$(CSAlign(3)))
			UpdateRobotLog$(CurrentOperation$ + ":  DF_ChipOffset (U corrected):" + Str$(CSAlign(4)) + ", " + Str$(CSAlign(5)) + "," + Str$(CSAlign(3)))
					
			If CompareWithTarget Then
				UpdateRobotLog$(CurrentOperation$ + ": Target offsets " + Str$(TCSAlign_X(TgtDAT, TgtSocket)) + ", " + Str$(TCSAlign_Y(TgtDAT, TgtSocket)) + ", " + Str$(TCSAlign_U(TgtDAT, TgtSocket)))
				If Abs(CSAlign(4) - TCSAlign_X(TgtDAT, TgtSocket)) < 0.15 And Abs(CSAlign(5) - TCSAlign_Y(TgtDAT, TgtSocket)) < 0.15 And Abs(CSAlign(3) - TCSAlign_U(TgtDAT, TgtSocket)) < 0.5 Then
					Print "Within target tolerance"
					CheckSocketPlacement = Val(ts$)
					Exit For
				Else
					Print "Not in target tolerance"
					CheckSocketPlacement = -ERR_SOCKET_PLACE
					If AutoReseat = 1 Then
						If try < Ntries Then
							Print "=================== ATTEMPTING RESEAT ==================="
							If ReseatChipInSocket(TgtDAT, TgtSocket, True) < 0 Then
								RTS_error("CheckSocketPlacement: Auto reseat failed!", ERR_SOCKET_PLACE, False)
								If CurrentOperation$ = "CheckAtS_" + ts$ Then
									ResetOperation
								EndIf
								Print "=================== RESEAT FAILED DUE TO ERROR ==================="
								Exit Function
							EndIf
							Print "=================== RESEAT FINISHED ==================="
						Else
							RTS_error("CheckSocketPlacement: Chip position outside of target tolerance even after reseat!", ERR_SOCKET_PLACE, False)
							If CurrentOperation$ = "CheckAtS_" + ts$ Then
								ResetOperation
							EndIf
							Print "=================== RESEAT UNSUCCESSFUL ==================="
							Exit Function
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
		Next
	EndIf

	SetSpeedSetting("MoveWithoutChip")

	

	UpdateRobotLog$(CurrentOperation$ + ": Chip placement check at socket complete")
	ResetOperation
	CheckSocketPlacement = Val(ts$)

Fend

