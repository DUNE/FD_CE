#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function MoveChipFromTrayToTray(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	'''
	' Top level command to move chips from one (source) tray position 
	' to another (target) tray position
	' Uses intermediate wrapper functions to handle pick and place such
	' that offsets and corrections are consistently handled
	' Does not currently run pin analysis
	'' Args
	' SrcTray, SrcTrayCol, SrcTrayRow - pallet index, column and row of source tray position
	' TgtTray, TgtTrayCol, TgtTrayRow - pallet index, column and row of target tray position
	'' Returns
	' Success: +ve Integer encoding of time stamp Val(ts$)
	' Failure: -ve Error code, see ErrorDictionary.inc
	'''
	Print "==================================================="
	MoveChipFromTrayToTray = 0
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		Print "TOP LEVEL"
		TopLevel = True
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "MoveT2T_" + ts$
    EndIf
    
    ResetCurrentChipOffsets

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
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromTrayToTray = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromTrayToTray = -ErrorCode
		Print "==================================================="
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
				RTS_error(("Target tray position occupancy check value = " + Str$(Occupancy)), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error(("Target tray position occupied, occupancy check value = " + Str$(Occupancy)), ERR_V_OCCUPIED, TopLevel)
			EndIf
			MoveChipFromTrayToTray = -ErrorCode
			Print "==================================================="
			Exit Function
		EndIf
			
		Occupancy = TrayPositionOccupied(SrcTray, SrcTrayCol, SrcTrayRow)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, TopLevel)
			EndIf
			MoveChipFromTrayToTray = -ErrorCode
			Print "==================================================="
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
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK, TopLevel)
		MoveChipFromTrayToTray = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	UpdateRobotLog$(CurrentOperation$ + ": Offsets from tray position (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ") calculated as (" + Str$(CorrectedChipOffset(1)) + "," + Str$(CorrectedChipOffset(2)) + "," + Str$(CorrectedChipOffset(3)) + ")")
	
	' While at the UF camera, do any pin analysis	
	' First need to recenter	


	' TODO need to think about whether we want to run pin analysis in tray-to-tray, and if it fails what then?
'	String PinImages$(3)
'	If DoPinAnalysis Then
'		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
'		
'	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
'	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
'
'	 	Print "UFPinAnalyisOutput = ", SubError
'	 	Int32 i
'	 	Print "Pin analysis images:"
'	 	For i = 1 To 3
'	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
'	 	Next
'		If SubError < -1 Then
'			RTS_error("Pin analysis failure", ERR_PINS, TopLevel)
'			MoveChipFromTrayToTray = -ErrorCode
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
'	EndIf
	Wait 1
	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")

	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE, TopLevel)
		MoveChipFromTrayToTray = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
	
'	UpdateRobotLog$(CurrentOperation$ + ": DefaultSkipChipCor = " + Str$(DefaultSkipChipCor) + ", SkipChipToChipCorrection = " + Str$(SkipChipToChipCorrection))
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset (Should be reset) = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtTray position offset = (" + Str$(tray_X(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_Y(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_U(TgtTray, TgtTrayCol, TgtTrayRow)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At Tray      = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target tray position")
	
	SetSpeedSetting("MoveWithoutChip")

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2T) command complete:")
	ResetOperation(TopLevel)
	MoveChipFromTrayToTray = Val(ts$)	' -1
	CloseMLog("DONE")
	Print "==================================================="
Fend

Function MoveChipFromTrayToSocket(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtDAT As Integer, TgtSocket As Integer) As Int64
	'''
	' Top level command to move chips from a (source) tray position 
	' to a (target) DAT board socket position
	' Uses intermediate wrapper functions to handle pick and place such
	' that offsets and corrections are consistently handled
	' Will run pin analysis if enabled in site config file
	'' Args
	' SrcTray, SrcTrayCol, SrcTrayRow - pallet index, column and row of source tray position
	' TgtDAT, TgtSocket - target DAT board and socket indices
	'' Returns
	' Success: +ve Integer encoding of time stamp Val(ts$)
	' Failure: -ve Error code, see ErrorDictionary.inc
	'''
	Print "==================================================="
	MoveChipFromTrayToSocket = 0
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Boolean TopLevel
	TopLevel = False
	
	If CurrentOperation$ = "" Then
		Print "TOP LEVEL"
		TopLevel = True
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "MoveT2S_" + ts$
    EndIf
    
    ResetCurrentChipOffsets
	
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
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromTrayToSocket = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
	
	If Not CheckValidSocketIndex(TgtDAT, TgtSocket) Then
		RTS_error("Invalid target socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromTrayToSocket = -ErrorCode
		Print "==================================================="
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
				RTS_error("Target socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error("Target socket position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED, TopLevel)
			EndIf
			MoveChipFromTrayToSocket = -ErrorCode
			Print "==================================================="
			Exit Function
		EndIf
	
		Occupancy = TrayPositionOccupied(SrcTray, SrcTrayCol, SrcTrayRow)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, TopLevel)
			EndIf
			MoveChipFromTrayToSocket = -ErrorCode
			Print "==================================================="
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
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK, TopLevel)
		MoveChipFromTrayToSocket = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter
	String PinImages$(3)
	If DoPinAnalysis Then
		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
		
	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())

	 	Print "UFPinAnalyisOutput = ", SubError
	 	Int32 i
	 	Print "Pin analysis images:"
	 	For i = 1 To 3
	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
	 	Next
		If SubError < -1 Then
			RTS_error("Pin analysis failure", ERR_PINS, TopLevel)
			MoveChipFromTrayToSocket = -ErrorCode
			Exit Function
			Print "==================================================="
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
	EndIf
	
	Wait 2
			
	' Place chip in socket	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target socket position")

	SubError = PlaceChipInSocket(TgtDAT, TgtSocket)
	If Not SubError Then
		RTS_error("Could not place chip in socket", ERR_SOCKET_PLACE, TopLevel)
		MoveChipFromTrayToSocket = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
'	UpdateRobotLog$(CurrentOperation$ + ": DefaultSkipChipCor = " + Str$(DefaultSkipChipCor) + ", SkipChipToChipCorrection = " + Str$(SkipChipToChipCorrection))
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset (Should be reset) = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtSock position offset = (" + Str$(DAT_X(TgtDAT, TgtSocket)) + "," + Str$(DAT_Y(TgtDAT, TgtSocket)) + "," + Str$(DAT_U(TgtDAT, TgtSocket)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At socket    = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target socket position")
	
	SetSpeedSetting("MoveWithoutChip")

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2S) command complete:")
	ResetOperation(TopLevel)
	MoveChipFromTrayToSocket = Val(ts$)
	CloseMLog("DONE")
	Print "==================================================="
Fend

Function MoveChipFromSocketToTray(SrcDAT As Integer, SrcSocket As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	'''
	' Top level command to move chips from a (source) DAT board socket
	' to a (target) tray position
	' Uses intermediate wrapper functions to handle pick and place such
	' that offsets and corrections are consistently handled
	'' Args
	' SrcDAT, SrcSocket - Source DAT board and socket indices
	' TgtTray, TgtTrayCol, TgtTrayRow - pallet index, column and row of target tray position
	'' Returns
	' Success: +ve Integer encoding of time stamp Val(ts$)
	' Failure: -ve Error code, see ErrorDictionary.inc
	'''
	Print "==================================================="
	MoveChipFromSocketToTray = 0
	ErrorCode = 0
	SubError = 0
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Boolean TopLevel
	TopLevel = False
		
	If CurrentOperation$ = "" Then
		Print "TOP LEVEL"
		TopLevel = True
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		CurrentOperation$ = "MoveS2T_" + ts$
	EndIf
	ResetCurrentChipOffsets
	
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
		RTS_error("Invalid source socket (" + Str$(SrcDAT) + "," + Str$(SrcSocket) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromSocketToTray = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND, TopLevel)
		MoveChipFromSocketToTray = -ErrorCode
		Print "==================================================="
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
				RTS_error("Target tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error("Target tray position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED, TopLevel)
			EndIf
			MoveChipFromSocketToTray = -ErrorCode
			Print "==================================================="
			Exit Function
		EndIf
		
		Occupancy = SocketPositionOccupied(SrcDAT, SrcSocket)
		'Print "Occupancy = ", Occupancy
		If Occupancy <> 1 Then
			Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
			If Occupancy = -2 Then
				RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION, TopLevel)
			Else
				RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP, TopLevel)
			EndIf
			MoveChipFromSocketToTray = -ErrorCode
			Print "==================================================="
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
		RTS_error("Could not get chip from socket - GetChipFromSocket=" + Str$(SubError), ERR_SOCKET_PICK, TopLevel)
		MoveChipFromSocketToTray = -ErrorCode
		Print "==================================================="
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and socket offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter	

	' TODO think about whether we want to run pin analysis on way out? If so, what do we do with the chip
	' needs coordination with RTS_CFG updates based on return code if chip still held
	' We need to be able to move chips with bad pins between trays
'	String PinImages$(3)
'	If DoPinAnalysis Then
'		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
'		
'	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
'	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
'
'	 	Print "UFPinAnalyisOutput = ", SubError
'	 	Int32 i
'	 	Print "Pin analysis images:"
'	 	For i = 1 To 3
'	 		Print "Pin analysis image ", i, " : ", PinImages$(i)
'	 	Next
'		If SubError < -1 Then
'			RTS_error("Pin analysis failure", ERR_PINS, TopLevel)
'			MoveChipFromSocketToTray = -ErrorCode
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
'	EndIf
	
	' Place chip in tray
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")
	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE, TopLevel)
		MoveChipFromSocketToTray = -ErrorCode
		Print "==================================================="
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
	ResetOperation(TopLevel)
	MoveChipFromSocketToTray = Val(ts$) ' -1

	CloseMLog("DONE")

	Print "==================================================="
Fend

Function ReseatIfMisaligned(DAT As Integer, Socket As Integer) As Int64
	Print "==================================================="
	ReseatIfMisaligned = 0
    SubError = 0
			
	Boolean TopLevel
	TopLevel = False
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	bnl_idx(1) = mlog_nr
	bnl_idx(2) = 0
	bnl_idx(3) = 0
	bnl_idx(4) = 0
	bnl_idx(5) = 0
	bnl_idx(6) = 0
	bnl_idx(7) = 0
	bnl_idx(8) = DAT
	bnl_idx(9) = Socket
	bnl_idx(10) = 0
	bnl_idx(11) = 0
	
	If CurrentOperation$ = "" Then
		Print "TOP LEVEL"
		TopLevel = True
    '	If no current operation ID is assigned (from high level move function) need to load last offsets and positions)
		SelectSite("InFunctionDefinePallets")
		op_ts$ = ts$
		UpdateRobotLog$(op_ts$ + " : ReseatIfMisaligned(" + Str$(DAT) + "," + Str$(Socket) + ")")
	Else
		UpdateRobotLog$(CurrentOperation$ + " : ReseatIfMisaligned(" + Str$(DAT) + "," + Str$(Socket) + ")")
    EndIf
	ResetCurrentChipOffsets ' probaly not necessary but shouldn't do any harm?
		
	OpenMLog(ts$)
	MLogIdx
		
	CSAlign_X(DAT, Socket) = 0
	CSAlign_Y(DAT, Socket) = 0
	CSAlign_U(DAT, Socket) = 0
	CSAlign_Img$(DAT, Socket) = ""
	CSAlign_ts$(DAT, Socket) = ""
	
	Integer status
	status = CheckSocketPlacement(DAT, Socket)
	
	SetSpeedSetting("MoveWithChip")
		
	If status > -1 Then ' General error or unknown status
		RTS_error("ReseatIfMisaligned: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		
		ReseatIfMisaligned = -ERR_SOCKET_PLACE
		Print "==================================================="
		Exit Function
	ElseIf status < -1 And status > -5 Then ' Needs rotation
		RTS_error("ReseatIfMisaligned: Bad orientation", -ERR_SOCKET_PLACE, False)
		If RotateChipInSocket(DAT, Socket, (-(status + 1) * 90.), False) < 0 Then
			RTS_error("ReseatIfMisaligned: Cannot place chip in socket after rotation", -ERR_SOCKET_PLACE, TopLevel)
			
			ReseatIfMisaligned = -ERR_SOCKET_PLACE
			Exit Function
		EndIf
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE_ROTATE", CX(Here), CY(Here), CU(Here))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED_ROTATE", SockPos(1), SockPos(2), SockPos(3))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED_ROTATE", ChipPos(1), ChipPos(2), ChipPos(3))
	ElseIf status = -5 Then ' Needs reseat
		RTS_error("ReseatIfMisaligned: Bad alignment", -ERR_SOCKET_PLACE, False)
		If ReseatChipInSocket(DAT, Socket, False) < 0 Then
			RTS_error("ReseatIfMisaligned: Cannot place chip in socket after reseat", -ERR_SOCKET_PLACE, TopLevel)
			ReseatIfMisaligned = -ERR_SOCKET_PLACE
			Print "==================================================="
			Exit Function
		EndIf
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "ROBOT_AT_IMAGE_RESEAT", CX(Here), CY(Here), CU(Here))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "SOCKET_MEASURED_RESEAT", SockPos(1), SockPos(2), SockPos(3))
		LogTestMeasurements(CurrentOperation$, "ToSocket", 0, DAT, Socket, "CHIP_MEASURED_RESEAT", ChipPos(1), ChipPos(2), ChipPos(3))
	ElseIf status < -5 Then ' Undefined status
		RTS_error("ReseatIfMisaligned: Cannot place chip in socket", -ERR_SOCKET_PLACE, TopLevel)
		Print "ERROR ***SHOULD NOT BE GETTING HERE ***"
		ReseatIfMisaligned = -ERR_SOCKET_PLACE
		Print "==================================================="
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
	ReseatIfMisaligned = -1
	ResetOperation(TopLevel)
	Print "==================================================="
Fend

''' When outside of a move function, reset so that the subfunctions can be tested
Function ResetOperation(DoReset As Boolean)
	' Boolean allows functions to be called as high or lower level,
	' cleans up the operation string handling 
	If DoReset Then
		' Have it set to just "", require all Top Level allowable (server callable) functions to have defined operation label
		CurrentOperation$ = "" ' "NA_" + FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	EndIf
Fend





