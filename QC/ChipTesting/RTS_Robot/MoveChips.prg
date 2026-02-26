#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function MoveChipFromTrayToTray(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	MoveChipFromTrayToTray = 0
	ErrorCode = 0
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	
	LoadPositionFiles
	ResetCurrentChipOffsets
	
	String ts$ ', opName$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")

	CurrentOperation$ = "MoveT2T_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromTrayToTray(" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + "," + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ") " + ts$)
		
	' Check valid operation
	If Not CheckValidTrayIndex(SrcTray, SrcTrayCol, SrcTrayRow) Then
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices, checking position occupancies")

	Motor On
	On 12

	' Check occupancy	
	Int32 Occupancy
	Occupancy = -1
	
	' Check target first
	Occupancy = TrayPositionOccupied(TgtTray, TgtTrayCol, TgtTrayRow)
	'Print "Occupancy = ", Occupancy
	If Occupancy <> 0 Then
		Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
		If Occupancy = -2 Then
			RTS_error(("Target tray position occupancy check value = " + Str$(Occupancy)), ERR_OBSTRUCTION)
		Else
			RTS_error(("Target tray position occupied, occupancy check value = " + Str$(Occupancy)), ERR_V_OCCUPIED)
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
			RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
		Else
			RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP)
		EndIf
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")

	' Take picture of chip and store it for serial number retrieval	
	String DFChipPicture_SN$
	DFChipPicture_SN$ = DF_take_picture$(CurrentOperation$ + "_SN")
'	UpdateRobotLog$(CurrentOperation$ + ": Chip image for SN saved to " + DFChipPicture_SN$)
	UpdateRobotLog$("Picture of chip in tray taken: " + DFChipPicture_SN$)
	' Chips are in the right place, lets get the chip from the tray	
	
	' If chip needs to be in correct orientation here, rotate the chip?	
	
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source tray position (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")")
	' Need to get result from subprocess?
	SubError = GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow)
'	If Not GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow) Then
	If Not SubError Then
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	UpdateRobotLog$(CurrentOperation$ + ": Offsets from tray position (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ") calculated as (" + Str$(CorrectedChipOffset(1)) + "," + Str$(CorrectedChipOffset(2)) + "," + Str$(CorrectedChipOffset(3)) + ")")
	
'''' CURRENTLY COMMENTED OUT FOR FINE TURNING - UFRECENTER FUNCTION NEEDS FIXING
'	' While at the UF camera, do any pin analysis	
'	' First need to recenter	
'	If DoPinAnalysis Then
'		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
'		UFRecenterSimple ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
'		
'	 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
'	 	String PinImages$(3)
'	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
'	 	'If Not ChipPinAnalysisSimple Then
'		If Not SubError Then
'			RTS_error("Pin analysis failure", ERR_PINS)
'			MoveChipFromTrayToTray = -ErrorCode
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
'	EndIf
'	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")

	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
'	If Not PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow) Then
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE)
		MoveChipFromTrayToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset     = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtTray position offset = (" + Str$(tray_X(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_Y(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_U(TgtTray, TgtTrayCol, TgtTrayRow)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At Tray      = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target tray position")
'	
'	' Do any chip placement diagnostics here
'	If DoCheckPlace Then
'		UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
'		' Here we want to use the more precise chip position measurements
'		' Not sure if possible for all chips. Surface features on some chips not as visible	
'		' Chip edge also not easy to select because of the pins, often finds box askew
'		JumpToTray_camera(TgtTray, TgtTrayCol, TgtTrayRow)
'		' First just check chip orientation
'		Double MeasuredDirection, MeasuredOrientation ' , OrientationOffset
'		MeasuredDirection = FindChipDirectionWithDF
'		If MeasuredDirection < -900. Then
'			RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN) ' Or should this be error tray palce
'			MoveChipFromTrayToTray = -ErrorCode
'			ResetOperation
'			Exit Function
'		EndIf
'		
'		' Get any offset from 0,90,180 etc
'		Double dTU
'		dTU = DiffAnglePM180(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow)), RoundAngleTo90(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow))))
'		MeasuredOrientation = RoundAngleTo90(DiffAnglePM180(MeasuredDirection, dTU))
'	
'		If Abs(DiffAnglePM180(TrayOrientation, MeasuredOrientation)) > 5. Then
'			RTS_error("Chip not put back in tray in expected orientation", ERR_TRAY_PLACE)
'			MoveChipFromTrayToTray = -ErrorCode
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")
'	EndIf

'	Motor Off
'	Off 12

	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2T) command complete:")
	UpdatePositionFiles
	ResetOperation
	MoveChipFromTrayToTray = -1
Fend

Function MoveChipFromTrayToSocket(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtDAT As Integer, TgtSocket As Integer) As Int64
	MoveChipFromTrayToSocket = 0
	ErrorCode = 0
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	
	LoadPositionFiles
	ResetCurrentChipOffsets
	
	String ts$ ', opName$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")

	 'opName$ = "MoveT2S_" + ts$
	CurrentOperation$ = "MoveT2S_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromTrayToTray(" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + "," + Str$(TgtDAT) + "," + Str$(TgtSocket) + ") " + ts$)

	' Check valid operation
	If Not CheckValidTrayIndex(SrcTray, SrcTrayCol, SrcTrayRow) Then
		RTS_error("Invalid source tray (" + Str$(SrcTray) + "," + Str$(SrcTrayCol) + "," + Str$(SrcTrayRow) + ")", ERR_BAD_COMMAND)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	If Not CheckValidSocketIndex(TgtDAT, TgtSocket) Then
		RTS_error("Invalid target socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")", ERR_BAD_COMMAND)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices, checking position occupancies")
	
	' Check occupancy
	Int32 Occupancy
	Occupancy = -1
	
	Occupancy = SocketPositionOccupied(TgtDAT, TgtSocket)
	'Print "Occupancy = ", Occupancy
	If Occupancy <> 0 Then
		Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
		If Occupancy = -2 Then
			RTS_error("Target socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
		Else
			RTS_error("Target socket position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED)
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
			RTS_error("Source tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
		Else
			RTS_error("Source tray position empty, occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP)
		EndIf
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")
	
	' Get chip from tray	
	
	' Take picture of chip and store it for serial number retrieval	
	String DFChipPicture_SN$
	DFChipPicture_SN$ = DF_take_picture$(CurrentOperation$ + "_SN")
'	UpdateRobotLog$(CurrentOperation$ + ": Chip image for SN saved to " + DFChipPicture_SN$)
	UpdateRobotLog$("Picture of chip in tray taken: " + DFChipPicture_SN$)
	' Chips are in the right place, lets get the chip from the tray	
	
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source tray position")
	' Need to get result from subprocess?
	SubError = GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow)
'	If Not GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow) Then
	If Not SubError Then
		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and tray offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter
'	If DoPinAnalysis Then
'		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
'		UFRecenterSimple ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
'		
'		' Take a picture for pin analysis	
'		String PinImages$(3)
'		'UFChipPicture$ = UF_take_picture$(opName$ + "_pins")
'	 	
'	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
'	 	'If Not ChipPinAnalysisSimple Then
'		If Not SubError Then
'			RTS_error("Pin analysis failure", ERR_PINS)
'			MoveChipFromTrayToSocket = -ErrorCode
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
'	EndIf
			
	' Place chip in socket	
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target socket position")

	SubError = PlaceChipInSocket(TgtDAT, TgtSocket)
	If Not SubError Then
		RTS_error("Could not place chip in socket", ERR_SOCKET_PLACE)
		MoveChipFromTrayToSocket = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset     = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtSock position offset = (" + Str$(DAT_X(TgtDAT, TgtSocket)) + "," + Str$(DAT_Y(TgtDAT, TgtSocket)) + "," + Str$(DAT_U(TgtDAT, TgtSocket)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At socket    = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")

	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target socket position")
	
	' Do any chip placement diagnostics here
'	If DoCheckPlace Then
'	UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
'		' Here we want to use the more precise chip position measurements
'		' Not sure if possible for all chips. Surface features on some chips not as visible	
'		' Chip edge also not easy to select because of the pins, often finds box askew
'		JumpToSocket_camera(TgtDAT, TgtSocket)
'		
'		' Already have socket corrections from earlier, should not have changed significantly
'		Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
'		
'		' First just check chip orientation
'		Double MeasuredDirection ' , OrientationOffset
'		MeasuredDirection = FindChipDirectionWithDF
'		If MeasuredDirection < -900. Then
'			RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN) ' Or should this be error tray palce
'			MoveChipFromTrayToSocket = -ERR_V_DF_ALIGN
'			ResetOperation
'			Exit Function
'		EndIf
'		
'		' While accounting for U offset of socket from drift in defined position, and chip orientation as expected at socket
'		' What is the difference to the measured direction?
'		If Abs(DiffAnglePM180(MeasuredDirection, (CU(P(PSocket(TgtDAT, TgtSocket))) + HandChipOrientation(CHIPTYPE_NR) + SocketOffset(3))) > 5) Then
'			RTS_error("Chip not put back in tray in expected orientation", ERR_SOCKET_PLACE)
'			MoveChipFromTrayToSocket = -ERR_SOCKET_PLACE
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")
'		''' Add more detailed chip-socket relative position checks if available.
'		''  This is for fine tune measurements of the placement. Probably easiest with LArASICs. Not sure if possible for 
'		' COLDATA or ColdADC depending on lighting/surface feature prominance
'		
'		If DoMeasurePlace Then
'		
'			If Not GetChipInSocketAlignment(TgtDAT, TgtSocket) Then
'				RTS_error("Chip socket alignment failure", ERR_V_DF_ALIGN)
'				MoveChipFromTrayToSocket = -ERR_V_DF_ALIGN
'				ResetOperation
'				Exit Function
'			EndIf
'			
'			If Abs(CSAlign(1)) > 1. Or Abs(CSAlign(2)) > 2. Or Abs(CSAlign(3)) > 3. Then
'				RTS_error("Chip not put back in tray in expected position", ERR_SOCKET_PLACE)
'				MoveChipFromTrayToSocket = -ERR_SOCKET_PLACE
'				ResetOperation
'				Exit Function
'			EndIf
'			LogDFSocketMeasurements(TgtDAT, TgtSocket, CurrentOperation$)
'			Print "DF_SocketPosition:", SockPos(1), ",", SockPos(2), ",", SockPos(3), "; DF_ChipPosition:", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), "; DF_ChipOffset:", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), "; X and Y after U corrected: ", ", CSAlign(4), ", ", CSAlign(5)"
'			UpdateRobotLog$(CurrentOperation$ + ": Chip Socket alignment measured: DF_SocketPosition:" + Str$(SockPos(1)) + "," + Str$(SockPos(2)) + "," + Str$(SockPos(3)) + "; DF_ChipPosition:" + Str$(ChipPos(1)) + "," + Str$(ChipPos(2)) + "," + Str$(ChipPos(3)) + "; DF_ChipOffset:" + Str$(CSAlign(1)) + "," + Str$(CSAlign(2)) + "," + Str$(CSAlign(3)) + "; X and Y after U corrected: " + Str$(CSAlign(4)) + ", " + Str$(CSAlign(5)))
'		EndIf
'	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Chip move (T2S) command complete:")
	UpdatePositionFiles
	ResetOperation
	MoveChipFromTrayToSocket = Val(ts$) ' -1
Fend

Function MoveChipFromSocketToTray(SrcDAT As Integer, SrcSocket As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	MoveChipFromSocketToTray = 0
	ErrorCode = 0 ' Might be better to set these to 1 (-1 is TRUE in BASIC) for initialization 
	SubError = 0
	
	SelectSite("InFunctionDefinePallets")
	
	LoadPositionFiles
	ResetCurrentChipOffsets
	
	String ts$ ' , opName$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")

	CurrentOperation$ = "MoveS2T_" + ts$
	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromSocketToTray(" + Str$(SrcDAT) + "," + Str$(SrcSocket) + "," + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ") " + ts$)

	' Check valid operation
	If Not CheckValidSocketIndex(SrcDAT, SrcSocket) Then
		RTS_error("Invalid source socket (" + Str$(SrcDAT) + "," + Str$(SrcSocket) + ")", ERR_BAD_COMMAND)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf

	If Not CheckValidTrayIndex(TgtTray, TgtTrayCol, TgtTrayRow) Then
		RTS_error("Invalid target tray (" + Str$(TgtTray) + "," + Str$(TgtTrayCol) + "," + Str$(TgtTrayRow) + ")", ERR_BAD_COMMAND)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices, checking position occupancies")

	' Check occupancy
	Int32 Occupancy
	Occupancy = -1
	
	Occupancy = TrayPositionOccupied(TgtTray, TgtTrayCol, TgtTrayRow)
	If Occupancy <> 0 Then
		Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
		If Occupancy = -2 Then
			RTS_error("Target tray position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
		Else
			RTS_error("Target tray position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED)
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
			RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
		Else
			RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP)
		EndIf
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")

	' Get chip from socket
''''''		
	
	' Take picture of chip and store it for serial number retrieval	
	String DFChipPicture_SN$
	DFChipPicture_SN$ = DF_take_picture$(CurrentOperation$ + "_SN")
'	UpdateRobotLog$(CurrentOperation$ + ": Chip image for SN saved to " + DFChipPicture_SN$)
	UpdateRobotLog$("Picture of chip in socket taken: " + DFChipPicture_SN$)

	' Chips are in the right place, lets get the chip from the tray	
	
	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source socket position")
	' Need to get result from subprocess?
	SubError = GetChipFromSocket(SrcDAT, SrcSocket)
'	If Not GetChipFromSocket(SrcDAT, SrcSocket) Then
	If Not SubError Then
		RTS_error("Could not get chip from socket - GetChipFromSocket=" + Str$(SubError), ERR_SOCKET_PICK)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and socket offsets measured")
	' While at the UF camera, do any pin analysis	
	' First need to recenter	
	If DoPinAnalysis Then
		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis...")
		UFRecenterSimple ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
		
		' Take a picture for pin analysis	
		String PinImages$(3)
	'	UFChipPicture$ = UF_take_picture$(opName$ + "_pins")
	 	
	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
	 	'If Not ChipPinAnalysisSimple Then
		If Not SubError Then
			RTS_error("Pin analysis failure", ERR_PINS)
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
	EndIf
	
	''''''
	
	' Place chip in tray
	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target tray position")
	SubError = PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow)
'	If Not PlaceChipInTray(TgtTray, TgtTrayCol, TgtTrayRow) Then
	If Not SubError Then
		RTS_error("Could not place chip in tray", ERR_TRAY_PLACE)
		MoveChipFromSocketToTray = -ErrorCode
		ResetOperation
		Exit Function
	EndIf
	
	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset     = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": TgtTray position offset = (" + Str$(tray_X(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_Y(TgtTray, TgtTrayCol, TgtTrayRow)) + "," + Str$(tray_U(TgtTray, TgtTrayCol, TgtTrayRow)) + ")")
	UpdateRobotLog$(CurrentOperation$ + ": Correction At Tray      = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")
	
	
	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target tray position")
	
	' Do any chip placement diagnostics here
	If DoCheckPlace Then
		UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
		' Here we want to use the more precise chip position measurements
		' Not sure if possible for all chips. Surface features on some chips not as visible	
		' Chip edge also not easy to select because of the pins, often finds box askew
		JumpToTray_camera(TgtTray, TgtTrayCol, TgtTrayRow)
		' First just check chip orientation
		Double MeasuredDirection, MeasuredOrientation ' , OrientationOffset
		MeasuredDirection = FindChipDirectionWithDF
		If MeasuredDirection < -900. Then
			RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN) ' Or should this be error tray palce
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
				
		' Get any offset from 0,90,180 etc
		Double dTU
		dTU = DiffAnglePM180(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow)), RoundAngleTo90(CU(Pallet(TgtTray, TgtTrayCol, TgtTrayRow))))
		MeasuredOrientation = RoundAngleTo90(DiffAnglePM180(MeasuredDirection, dTU))

	
		If Abs(DiffAnglePM180(TrayOrientation, MeasuredOrientation)) > 5. Then
			RTS_error("Chip not put back in tray in expected orientation", ERR_TRAY_PLACE)
			MoveChipFromSocketToTray = -ErrorCode
			ResetOperation
			Exit Function
		EndIf
		UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")
		
	EndIf
	UpdateRobotLog$(CurrentOperation$ + ": Chip move (S2T) command complete:")
	UpdatePositionFiles
	ResetOperation
	MoveChipFromSocketToTray = Val(ts$) ' -1
Fend

'Function MoveChipFromSocketToSocket(SrcDAT As Integer, SrcSocket As Integer, TgtDAT As Integer, TgtSocket As Integer) As Int64
'	MoveChipFromSocketToSocket = 0
'	ErrorCode = 0 ' Might be better to set these to 1 (-1 is TRUE in BASIC) for initialization 
'	SubError = 0
'	
'	SelectSite("InFunctionDefinePallets")
'
'	LoadPositionFiles
'	ResetCurrentChipOffsets
'
'	String ts$ ' , opName$
'	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
'
'	CurrentOperation$ = "MoveT2T_" + ts$
'	UpdateRobotLog$(CurrentOperation$ + ": MoveChipFromSocketToSocket(" + Str$(SrcDAT) + "," + Str$(SrcSocket) + "," + Str$(TgtDAT) + "," + Str$(TgtSocket) + ") " + ts$)
'
'	
'	' Check valid operation
'	If Not CheckValidSocketIndex(SrcDAT, SrcSocket) Then
'		RTS_error("Invalid source socket (" + Str$(SrcDAT) + "," + Str$(SrcSocket) + ")", ERR_BAD_COMMAND)
'	    MoveChipFromSocketToSocket = -ERR_BAD_COMMAND
'	    ResetOperation
'		Exit Function
'	EndIf
'	
'	
'	If Not CheckValidSocketIndex(TgtDAT, TgtSocket) Then
'		RTS_error("Invalid targer socket (" + Str$(TgtDAT) + "," + Str$(TgtSocket) + ")", ERR_BAD_COMMAND)
'	    MoveChipFromSocketToSocket = -ERR_BAD_COMMAND
'	    ResetOperation
'		Exit Function
'	EndIf
'	UpdateRobotLog$(CurrentOperation$ + ": Valid operation indices, checking position occupancies")
'
'	' Check occupancy
'	Int32 Occupancy
'	Occupancy = -1
'
'	Occupancy = SocketPositionOccupied(TgtDAT, TgtSocket)
'	'Print "Occupancy = ", Occupancy
'	If Occupancy <> 0 Then
'		Print "Did not get occupancy value of 0, Occupancy = ", Occupancy
'		If Occupancy = -2 Then
'			RTS_error("Target socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
'		Else
'			RTS_error("Target socket position occupied, occupancy check value = " + Str$(Occupancy), ERR_V_OCCUPIED)
'		EndIf
'		MoveChipFromSocketToSocket = -ErrorCode
'		ResetOperation
'		Exit Function
'	EndIf
'	
'	Occupancy = SocketPositionOccupied(SrcDAT, SrcSocket)
'	'Print "Occupancy = ", Occupancy
'	If Occupancy <> 1 Then
'		Print "Did not get occupancy value of 1, Occupancy = ", Occupancy
'		If Occupancy = -2 Then
'			RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_OBSTRUCTION)
'		Else
'			RTS_error("Source socket position occupancy check value = " + Str$(Occupancy), ERR_V_NOCHIP)
'		EndIf
'		MoveChipFromSocketToSocket = -ErrorCode
'		ResetOperation
'		Exit Function
'	EndIf
'
'	UpdateRobotLog$(CurrentOperation$ + ": Valid occupancies")
'	''' Get chip from socket	
'	
'	' Take picture of chip and store it for serial number retrieval	
'	String DFChipPicture_SN$
'	DFChipPicture_SN$ = DF_take_picture$(CurrentOperation$ + "_SN")
'	UpdateRobotLog$(CurrentOperation$ + ": Chip image for SN saved to " + DFChipPicture_SN$)
'	UpdateRobotLog$("Picture of chip in socket taken: " + DFChipPicture_SN$)
'	' Chips are in the right place, lets get the chip from the tray	
'	
'	UpdateRobotLog$(CurrentOperation$ + ": Getting chip from source socket position")
'	' Need to get result from subprocess?
'	SubError = GetChipFromSocket(SrcDAT, SrcSocket)
''	If Not GetChipFromSocket(SrcDAT, SrcSocket) Then
'	If Not SubError Then
'		RTS_error("Could not get chip from socket - GetChipFromSocket=" + Str$(SubError), ERR_SOCKET_PICK)
'		MoveChipFromSocketToSocket = -ErrorCode
'		ResetOperation
'		Exit Function
'	EndIf
'	
'	UpdateRobotLog$(CurrentOperation$ + ": Chip successfully picked up and socket offsets measured")
'	' While at the UF camera, do any pin analysis	
'	' First need to recenter	
'	If DoPinAnalysis Then
'		UpdateRobotLog$(CurrentOperation$ + ": Running pin analysis")
'		UFRecenterSimple ' TODOJOE check correction direction in old functions, is it + or -ve of the stored offset here and in C2C correction
'		
'		' Take a picture for pin analysis	
'		String PinImages$(3)
'		'UFChipPicture$ = UF_take_picture$(opName$ + "_pins")
'	 	
'	 	SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
'	 	'If Not ChipPinAnalysisSimple Then
'		If Not SubError Then
'			RTS_error("Pin analysis failure", ERR_PINS)
'			MoveChipFromSocketToSocket = -ErrorCode
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Pin analysis complete")
'	EndIf
'	
'	' Place chip in socket
'	UpdateRobotLog$(CurrentOperation$ + ":	Placing chip in target socket position")
'	SubError = PlaceChipInSocket(TgtDAT, TgtSocket)
'	If Not SubError Then
'		RTS_error("Could not place chip in socket", ERR_SOCKET_PLACE)
'		MoveChipFromSocketToSocket = -ErrorCode
'		ResetOperation
'		Exit Function
'	EndIf
'	UpdateRobotLog$(CurrentOperation$ + ": Current chip offset     = (" + Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)) + ")")
'	UpdateRobotLog$(CurrentOperation$ + ": TgtSock position offset = (" + Str$(DAT_X(TgtDAT, TgtSocket)) + "," + Str$(DAT_Y(TgtDAT, TgtSocket)) + "," + Str$(DAT_U(TgtDAT, TgtSocket)) + ")")
'	UpdateRobotLog$(CurrentOperation$ + ": Correction At socket    = (" + Str$(ChipToChipCorrection(1)) + "," + Str$(ChipToChipCorrection(2)) + "," + Str$(ChipToChipCorrection(3)) + ")")
'
'	UpdateRobotLog$(CurrentOperation$ + ": Chip placed in target socket position")
'	
'	' Do any chip placement diagnostics here
'	If DoCheckPlace Then
'	UpdateRobotLog$(CurrentOperation$ + ": Checking chip placed correctly")
'		' Here we want to use the more precise chip position measurements
'		' Not sure if possible for all chips. Surface features on some chips not as visible	
'		' Chip edge also not easy to select because of the pins, often finds box askew
'		JumpToSocket_camera(TgtDAT, TgtSocket)
'		
'		' Already have socket corrections from earlier, should not have changed significantly
'		Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
'		
'		' First just check chip orientation
'		Double MeasuredDirection ' , OrientationOffset
'		MeasuredDirection = FindChipDirectionWithDF
'		If MeasuredDirection < -900. Then
'			RTS_error("Cannot find chip direction", ERR_V_DF_ALIGN) ' Or should this be error tray palce
'			MoveChipFromSocketToSocket = -ERR_V_DF_ALIGN
'			ResetOperation
'			Exit Function
'		EndIf
'		
'		' While accounting for U offset of socket from drift in defined position, and chip orientation as expected at socket
'		' What is the difference to the measured direction?
'		If Abs(DiffAnglePM180(MeasuredDirection, (CU(P(PSocket(TgtDAT, TgtSocket))) + HandChipOrientation(CHIPTYPE_NR) + SocketOffset(3))) > 5) Then
'			RTS_error("Chip not put back in socket in expected orientation", ERR_SOCKET_PLACE)
'			MoveChipFromSocketToSocket = -ERR_SOCKET_PLACE
'			ResetOperation
'			Exit Function
'		EndIf
'		UpdateRobotLog$(CurrentOperation$ + ": Chip orientation O.K.!")
'		''' Add more detailed chip-socket relative position checks if available.
'		''  This is for fine tune measurements of the placement. Probably easiest with LArASICs. Not sure if possible for 
'		' COLDATA or ColdADC depending on lighting/surface feature prominance
'		
'		If DoMeasurePlace Then
'		
'			If Not GetChipInSocketAlignment(TgtDAT, TgtSocket) Then
'				RTS_error("Chip socket alignment failure", ERR_V_DF_ALIGN)
'				MoveChipFromSocketToSocket = -ERR_V_DF_ALIGN
'				ResetOperation
'				Exit Function
'			EndIf
'			
'			If Abs(CSAlign(1)) > 1. Or Abs(CSAlign(2)) > 2. Or Abs(CSAlign(3)) > 3. Then
'				RTS_error("Chip not put back in tray in expected position", ERR_SOCKET_PLACE)
'				MoveChipFromSocketToSocket = -ERR_SOCKET_PLACE
'				ResetOperation
'				Exit Function
'			EndIf
'			LogDFSocketMeasurements(TgtDAT, TgtSocket, CurrentOperation$)
'			Print "DF_SocketPosition:", SockPos(1), ",", SockPos(2), ",", SockPos(3), "; DF_ChipPosition:", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), "; DF_ChipOffset:", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), "; X and Y after U corrected: ", ", CSAlign(4), ", ", CSAlign(5)"
'			UpdateRobotLog$(CurrentOperation$ + ": Chip Socket alignment measured: DF_SocketPosition:" + Str$(SockPos(1)) + "," + Str$(SockPos(2)) + "," + Str$(SockPos(3)) + "; DF_ChipPosition:" + Str$(ChipPos(1)) + "," + Str$(ChipPos(2)) + "," + Str$(ChipPos(3)) + "; DF_ChipOffset:" + Str$(CSAlign(1)) + "," + Str$(CSAlign(2)) + "," + Str$(CSAlign(3)) + "; X and Y after U corrected: " + Str$(CSAlign(4)) + ", " + Str$(CSAlign(5)))
'		EndIf
'		
'		
'	EndIf
'	UpdateRobotLog$(CurrentOperation$ + ": Chip move (S2S) command complete:")
'	ResetOperation
'	UpdatePositionFiles
'	MoveChipFromSocketToSocket = Val(ts$)' -1
'	
'Fend

''' When outside of a move function, reset so that the subfunctions can be tested
Function ResetOperation
	CurrentOperation$ = "NA_" + FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
Fend
