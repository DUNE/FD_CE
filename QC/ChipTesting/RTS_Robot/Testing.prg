#include "RTS_tools.inc"

''' Add to .gitignore. Use this function for tests, not Main in main.prg
' This will help keep the repo clean!

Function Testing As Int64
	
	Testing = 0
	''' Keep this 
	NotStandalone = True
	SelectSite("")
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
	' Use values in site file as defaults while using server
	' Other wise all will default to False
	SocPlaceNotDrop = DefaultPlaceNotDrop ' Defaults to Drop
	SocClampFirst = DefaultClampFirst ' Defaults to clamp after vacuum off
	SocFastClamp = DefaultFastClamp ' defaults to soft/slow clamping
	DoPinAnalysis = DefaultPinAnalysis ' Defaults to not running pin analysis
	SkipOccupancyChecks = DefaultSkipOcc ' Defaults to running occupancy checks 
 	SkipSocketCorrection = DefaultSkipSocCor ' Defaults to applying socket correction
 	SkipChipToChipCorrection = DefaultSkipChipCor ' Defaults to applying chip to chip correction


	LoadPositionFiles
	LoadCurrentChipOffset
	
	' left tray
	Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows

	' right tray
	Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows
	
	UpdatePositionFiles

	Motor On
	PumpOn
	SetSpeed
	
	
'	''' Make changes here	

	
	DoPinAnalysis = False
	
	Int64 status
	
'
	Int32 iChip


	Integer Occupancy
	

	SkipOccupancyChecks = False
	SkipSocketCorrection = False
	SkipChipToChipCorrection = False


	Double Move_col_index_source(8)
	Double Move_row_index_source(8)
	
	Move_col_index_source(1) = 1
	Move_row_index_source(1) = 1
	
	Move_col_index_source(2) = 1
	Move_row_index_source(2) = 2
	
	Move_col_index_source(3) = 1
	Move_row_index_source(3) = 3
	
	Move_col_index_source(4) = 1
	Move_row_index_source(4) = 4
	
	Move_col_index_source(5) = 1
	Move_row_index_source(5) = 5
	
	Move_col_index_source(6) = 1
	Move_row_index_source(6) = 6
	
	Move_col_index_source(7) = 2
	Move_row_index_source(7) = 1
	
	Move_col_index_source(8) = 2
	Move_row_index_source(8) = 3
	
'	Double Move_col_index_bad(8)
'	Double Move_row_index_bad(8)
'	
'	Move_col_index_bad(1) = 1
'	Move_row_index_bad(1) = 2
'	
'	Move_col_index_bad(2) = 1
'	Move_row_index_bad(2) = 3
'	
'	Move_col_index_bad(3) = 1
'	Move_row_index_bad(3) = 4
'	
'	Move_col_index_bad(4) = 1
'	Move_row_index_bad(4) = 5
'	
'	Move_col_index_bad(5) = 1
'	Move_row_index_bad(5) = 6
'	
'	Move_col_index_bad(6) = 2
'	Move_row_index_bad(6) = 1
'	
'	Move_col_index_bad(7) = 2
'	Move_row_index_bad(7) = 2
'	
'	Move_col_index_bad(8) = 2
'	Move_row_index_bad(8) = 3
	
			
	For iChip = 1 To 8
		' put chips back in tray'
		status = MoveChipFromSocketToTray(2, iChip, 2, Move_col_index_source(iChip), Move_row_index_source(iChip))
		' put chips in sockets'
		'status = MoveChipFromTrayToSocket(2, Move_col_index(iChip), Move_row_index(iChip), 2, iChip)

		' reseat chips (just up and down exactly where they are
		'NOTE: Exit code is -1 for success (true in SPEL)
		'status = ReseatChipInSocket(2, iChip, 0)
		'If status < -1 Then
		
		' SOURCE -> BAD
		'status = MoveChipFromTrayToTray(2, Move_col_index_source(iChip), Move_row_index_source(iChip), 1, Move_col_index_bad(iChip), Move_row_index_bad(iChip))
		' BAD-> SOURCE	
		'status = MoveChipFromTrayToTray(1, Move_col_index_bad(iChip), Move_row_index_bad(iChip), 2, Move_col_index_source(iChip), Move_row_index_source(iChip))
		If status < 0 Then
			Print "ERROR moving chip ", Str$(iChip)
			Exit Function
		EndIf
	Next
'	
'	Move_col_index(1) = 2
'	Move_row_index(1) = 3
'	
'	Move_col_index(2) = 2
'	Move_row_index(2) = 4
'	
'	Move_col_index(3) = 2
'	Move_row_index(3) = 5
'	
'	Move_col_index(4) = 2
'	Move_row_index(4) = 6
'	
'	Move_col_index(5) = 3
'	Move_row_index(5) = 1
'	
'	Move_col_index(6) = 3
'	Move_row_index(6) = 2
'	
'	Move_col_index(7) = 3
'	Move_row_index(7) = 3
'	
'	Move_col_index(8) = 3
'	Move_row_index(8) = 4
'	
'	For iChip = 1 To 8
'		' put chips back in tray'
'		' status = MoveChipFromSocketToTray(2, iChip, 2, Move_col_index(iChip), Move_row_index(iChip))
'		' put chips in sockets'
'		 status = MoveChipFromTrayToSocket(2, Move_col_index(iChip), Move_row_index(iChip), 2, iChip)
'
'		' reseat chips (just up and down exactly where they are
'		'NOTE: Exit code is -1 for success (true in SPEL)
'		'status = ReseatChipInSocket(2, iChip, 0)
'		'If status < -1 Then
'	
'		If status < 0 Then
'			Print "ERROR moving chip ", iChip, " to tray"
'		'	Print "ERROR moving chip ", Str$(iChip), " to socket"
'			Exit Function
'		EndIf
'	Next
	
	SkipSocketCorrection = False
	SkipChipToChipCorrection = False


	SkipOccupancyChecks = False
	
	Wait 1
	JumpToCamera
	


'	

'	
'	''' keep rest of this
' Do not uncomment pump off if you are not sure if your code will not drop a chip after stopping mid move function!
'	PumpOff
'	Motor Off
'		''
	UpdatePositionFiles
	StoreCurrentChipOffset
	
Fend

Function CheckForChip(DAT_nr As Integer, socket_nr As Integer) As Boolean

	CheckForChip = False
	
	If Not isChipInSocketCamera(DAT_nr, socket_nr) Then
		Print "Cannot see a chip in the socket"
	Else
		Print "Can see chip in the socket"
	EndIf
	
	If Not isChipInSocketTouch(DAT_nr, socket_nr) Then
		Print "Chip not found at correct height"
	Else
		Print "Chip at correct height"
	EndIf
	
Fend


Function TestOptionsFromServer(RunSelectSite As Int32)
	
	Print "Will check value of global bools which are declared but not set"
	
	If RunSelectSite = 1 Then
		SelectSite("InFunctionDefinePallets")
	EndIf
	
	If NotStandalone Then
		Print "NotStandalone is True, this is being called within a higher level function like, Main, RTS_Server, or testing"
	Else
		Print "NotStandalone is False, this function is being called on its own or a function which does not set NotStandalone"
	EndIf
	
	If DoPinAnalysis Then
		Print "DoPinAnalysis is True"
	Else
		Print "DoPinAnalysis is False"
	EndIf
	
	If SkipOccupancyChecks Then
		Print "SkipOccupancyChecks is True"
	Else
		Print "SkipOccupancyChecks is False"
	EndIf
	
	If SkipSocketCorrection Then
		Print "SkipSocketCorrection is True"
	Else
		Print "SkipSocketCorrection is False"
	EndIf
	
	If SkipChipToChipCorrection Then
		Print "SkipChipToChipCorrection is True"
	Else
		Print "SkipChipToChipCorrection is False"
	EndIf
	
	If SocPlaceNotDrop Then
		Print "SocPlaceNotDrop is True"
	Else
		Print "SocPlaceNotDrop is False"
	EndIf
	
	If SocClampFirst Then
		Print "SocClampFirst is True"
	Else
		Print "SocClampFirst is False"
	EndIf
	
	If SocFastClamp Then
		Print "SocFastClamp is True"
	Else
		Print "SocFastClamp is False"
	EndIf
	
Fend

Function TestSiteFileLoading
	
	Print "Without loading from site file"
	PrintLoadedSiteFileValues
	
	Print "RUNNING SELECT SITE"
	SelectSite("")

	Print "With loading from site file"

	PrintLoadedSiteFileValues
	
	Boolean initial_pin_analysis
	initial_pin_analysis = DefaultPinAnalysis
	
	Print "Will now change setting of DoPinAnalysis"
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	DefaultPinAnalysis = Not initial_pin_analysis
	Print "changing..."
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	
	Print "Will now write new value to file"
	WriteSiteFile
	Print "Waiting 20 seconds, please check pin analysis setting in file has changed"
	Wait 20
	
	Print "Now changing back "
	Print "DefaultPinAnalysis = ", DefaultPinAnalysis
	DefaultPinAnalysis = False
	Print "changing..."
	Print "DefaultPinAnalysis = ", initial_pin_analysis
	Print "Rewriting site file"
	WriteSiteFile
		
Fend


Function CycleChipLoading(nCycles As Integer) As Int64
	
	CycleChipLoading = 0
	''' Keep this 
	NotStandalone = True
	SelectSite("")
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
	' Use values in site file as defaults while using server
	' Other wise all will default to False
	SocPlaceNotDrop = DefaultPlaceNotDrop ' Defaults to Drop
	SocClampFirst = DefaultClampFirst ' Defaults to clamp after vacuum off
	SocFastClamp = DefaultFastClamp ' defaults to soft/slow clamping
	DoPinAnalysis = DefaultPinAnalysis ' Defaults to not running pin analysis
	SkipOccupancyChecks = DefaultSkipOcc ' Defaults to running occupancy checks 
 	SkipSocketCorrection = DefaultSkipSocCor ' Defaults to applying socket correction
 	SkipChipToChipCorrection = DefaultSkipChipCor ' Defaults to applying chip to chip correction


	LoadPositionFiles
	LoadCurrentChipOffset
	
	' left tray
	Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows

	' right tray
	Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows
	
	UpdatePositionFiles

	Motor On
	PumpOn
	SetSpeed
	
	
'	''' Make changes here	

	
	DoPinAnalysis = False
	
	Int64 status
	
'
	Int32 iChip


	Integer Occupancy
	
	MeasurePlacement = True
	
	SkipOccupancyChecks = True
	SkipSocketCorrection = False
	SkipChipToChipCorrection = False
	
	SocPlaceNotDrop = True
	SocClampFirst = True
	SocFastClamp = True
	 
	Double Move_col_index(8)
	Double Move_row_index(8)
	
	Move_col_index(1) = 1
	Move_row_index(1) = 1
	
	Move_col_index(2) = 1
	Move_row_index(2) = 2
	
	Move_col_index(3) = 1
	Move_row_index(3) = 3
	
	Move_col_index(4) = 1
	Move_row_index(4) = 4
	
	Move_col_index(5) = 1
	Move_row_index(5) = 5
	
	Move_col_index(6) = 1
	Move_row_index(6) = 6
	
	Move_col_index(7) = 2
	Move_row_index(7) = 1
	
	Move_col_index(8) = 2
	Move_row_index(8) = 2
	

	

	Int32 cycle
	cycle = 0
	Do While cycle < nCycles
	
		For iChip = 1 To 1
			
			' move chip to socket
			status = MoveChipFromTrayToSocket(2, Move_col_index(iChip), Move_row_index(iChip), 2, iChip)
			
			If status < 0 Then
				Print "ERROR moving chip ", Str$(iChip), " to socket"
				Exit Function
			EndIf
			Wait 2
			
			' put chip back back in tray'
			status = MoveChipFromSocketToTray(2, iChip, 2, Move_col_index(iChip), Move_row_index(iChip))
			If status < 0 Then
				Print "ERROR moving chip ", Str$(iChip), " to tray"
				Exit Function
			EndIf
			Wait 2
			
		Next
		cycle = cycle + 1
		
	Loop
	

	SkipSocketCorrection = False
	SkipChipToChipCorrection = False

	SkipOccupancyChecks = False
	
	Wait 1
	JumpToCamera
	
	PumpOff

'		''
	UpdatePositionFiles
	StoreCurrentChipOffset
	
	CycleChipLoading = -1
	
Fend

Function TestChipMeasurementConsistency(DoFlip As Boolean, measurements As Int32)

	''' Run when looking at a chip	
	
		' Test three different chip measurements for consistency
	String test_measurement_file$
	test_measurement_file$ = "C:\Users\neutrino\LArASIC_Testing\VisionMeasurements\measurement_consistency.csv"
	Integer FileNum
	FileNum = FreeFile
	
	WOpen test_measurement_file$ As #fileNum
	Print #fileNum, "RX,RY,RU,sX,sY,sU,aX,aY,aU,oX,oY,oU"
	Int32 i
	Double sX, sY, sU, aX, aY, aU, oX, oY, oU
	For i = 0 To measurements
		FindChipPositionWithDF
		sX = ChipPos(1)
		sY = ChipPos(2)
		sU = ChipPos(3)
		
		FindChipPositionWithDFAdvanced
		aX = ChipPos(1)
		aY = ChipPos(2)
		aU = ChipPos(3)
		
		FindChipPositionWithDFFromOutline
		oX = ChipPos(1)
		oY = ChipPos(2)
		oU = ChipPos(3)
		
		Print #fileNum, CX(Here), ",", CY(Here), ",", CU(Here), ",", sX, ",", sY, ",", sU, ",", aX, ",", aY, ",", aU, ",", oX, ",", oY, ",", oU
	Next
	
	
	If DoFlip Then
		Motor On
		Double FlipAngle
		MoveFromImageToPoint
		FlipAngle = 0
		If Agl(4) < 0 Then
			FlipAngle = 180
		Else
			FlipAngle = -180
		EndIf
		Go Here +U(FlipAngle)
		MoveFromPointToImage
			
		For i = 0 To measurements
			FindChipPositionWithDF
			sX = ChipPos(1)
			sY = ChipPos(2)
			sU = ChipPos(3)
			
			FindChipPositionWithDFAdvanced
			aX = ChipPos(1)
			aY = ChipPos(2)
			aU = ChipPos(3)
			
			FindChipPositionWithDFFromOutline
			oX = ChipPos(1)
			oY = ChipPos(2)
			oU = ChipPos(3)
			
			Print #fileNum, CX(Here), ",", CY(Here), ",", CU(Here), ",", sX, ",", sY, ",", sU, ",", aX, ",", aY, ",", aU, ",", oX, ",", oY, ",", oU
		Next
		
		MoveFromImageToPoint
		Go Here -U(FlipAngle)
		MoveFromPointToImage
		
	EndIf

	Close #fileNum
		
Fend
'
'' With a chip already in the socket
'Function PlacementTest(DAT_nr As Integer, Socket_nr As Integer, n_cycles As Integer)
'	'2,1,50,True,False,False
'	Print "Runing placement test at socket (", DAT_nr, ",", socket_nr, ") for ", n_cycles, " cycles"
'
'	Wait 1
'	SelectSite("InFunctionDefinePallets")
'
'' Operation option permutations
''1.    At drop height, release vacuum (drop), soft clamp
''2.    At drop height, release vacuum (drop), fast clamp
''3. X  At drop height, soft clamp, release vacuum (drop) <- Soft clamp before release will just close mechanism before chip is dropped
''4. X  At drop height, fast clamp, release vacuum (drop) <- I suspect this may damage the chip as it will be grabbing the pins and pulling chip off the vacuum straw
''5.    At placement, release vacuum, soft clamp 
''6.    At placement, release vacuum, fast clamp
''7. X  At placement, soft clamp, release vacuum <- Soft clamp before release will just bring chip up out of socket and close mechanism before chip is dropped
''8.    At placement, fast clamp, release vacuum
'' 3., 4., and 7. are invalid 
'	
'	Boolean loop_option_place(5)
'	loop_option_place(1) = False '1.
'	loop_option_place(2) = False '2.
'	loop_option_place(3) = True  '5.
'	loop_option_place(3) = True  '6.
'	loop_option_place(3) = True  '8.
'	Boolean loop_option_clampfirst(5)
'	loop_option_clampfirst(1) = False
'	loop_option_clampfirst(2) = False
'	loop_option_clampfirst(3) = False
'	loop_option_clampfirst(3) = False
'	loop_option_clampfirst(3) = True
'	Boolean loop_option_clampfast(5)
'	loop_option_clampfast(1) = False
'	loop_option_clampfast(2) = True
'	loop_option_clampfast(3) = False
'	loop_option_clampfast(3) = True
'	loop_option_clampfast(3) = True
'	
'	' Go to the socket
'	Print "Jump to socket image"
'	JumpToSocket_camera(DAT_nr, socket_nr)
'
'	String fname$
'	
'	fname$ = RTS_DATA$ + "\Placementtests.csv"
'	Print "Results will be stored in ", fname$
'	
'	Int32 FileNum
'	fileNum = FreeFile
'	WOpen fname$ As #fileNum
'
'	' Measure the initial position/alignment	
'	Print "=============================================="
'	If Not MeasureAlignment(DAT_nr, socket_nr) Then
'		Print "Could not measure alignment!"
'		Close #fileNum
'		Exit Function
'	EndIf
'
'	Double InitPos(3), PlaceU, PickU
'	InitPos(1) = ChipPos(1)
'	InitPos(2) = ChipPos(2)
'	InitPos(3) = ChipPos(3)
'	
'	Print "INITIAL:", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlignXUnc, ",", CSAlignYUnc, ",", CSAlign_U(DAT, Socket), ",", CSAlign_X(DAT, Socket), ",", CSAlign_Y(DAT, Socket)
'		
'	PlaceU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), InitPos(3))
'	
'	Print #fileNum, "Mode,SocPlaceNotDrop,SocClampFirst,SocFastClamp,Iteration,SockX,SockY,SockU,ChipX,Chipy,ChipU,AlignXunc,AlignYunc,AlignU,AlignX,AlignY"
'	
'	Print #fileNum, "Initial,", SocPlaceNotDrop, ",", SocClampFirst, ",", SocFastClamp, ",0,", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlignXUnc, ",", CSAlignYUnc, ",", CSAlign_U(DAT, Socket), ",", CSAlign_X(DAT, Socket), ",", CSAlign_Y(DAT, Socket)
'	Int32 loopindex
'	For loopindex = 1 To 3
'		
'		String loopinfo$
'		
'		SocPlaceNotDrop = loop_option_place(loopindex)
'		If loop_option_place(loopindex) Then
'			loopinfo$ = "place_"
'		Else
'			loopinfo$ = "drop_"
'		EndIf
'		
'		SocClampFirst = loop_option_clampfast(loopindex)
'		If loop_option_clampfast(loopindex) Then
'			loopinfo$ = loopinfo$ + "fast"
'		Else
'			loopinfo$ = loopinfo$ + "soft"
'		EndIf
'		
'		Int32 cycle
'		For cycle = 1 To n_cycles
'			Print "Cycle ", Str$(cycle)
'			Wait 1
'			String dfpicname$, ufpicname$, cycleinfo$
'			cycleinfo$ = "Placetest_" + loopinfo$ + "_cycle_" + Str$(cycle)
'			dfpicname$ = ""
'			ufpicname$ = ""
'			
'			' Center over chip
'			Print "Center over chip with last measurement"
'			JumpToSocket(DAT_nr, socket_nr)
'			PickU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), ChipPos(3)) ' ChipPos_U - HandChipOrientation
'			Move Here :X(ChipPos(1)) :Y(ChipPos(2)) :U(PickU)
'			Print Here
'			Wait 5
'			PumpOn
'			Wait 1
'			' Pick up chip
'			Print "Pick up the chip" ' CURRENTLY COMMENTED OUT"
'			If Not PickupFromSocket Then
'				Print "Could not pick up chip"
'				Close #fileNum
'				Exit Function
'			EndIf
'			Wait 5
'			
'		
'	'		' If check pins
'	'		If check_pins Then
'	'			' Go to UFC
'	'			JumpToCamera
'	'
'	'			' Take picture
'	'			ufpicname$ = UF_take_picture$(cycleinfo$ + "_UF_pins")
'	'			
'	'			' Return to socket
'	'			JumpToSocket(DAT_nr, Socket_nr)
'	'		EndIf
'	
'			' Recenter over initial chip position (wrt socket? or absolute?)
'			
'			' Absolute initial position of chip
'			Print "Move hand to align with initial position as best we can"
'			Move Here :X(InitPos(1)) :Y(InitPos(2)) :U(PlaceU)
'			Print Here
'			
'			' Place down chip
'			Print "Place in socket" ' CURRENTLY COMMENTED OUT"
'			If Not PlaceInSocket Then
'				Print "Could not place chip"
'				Close #fileNum
'				Exit Function
'			EndIf
'			PumpOff
'			Wait 1
'			
'			
'			Print "Remeasure socket placment"
'			' Measure post pick/place alignment
'			If Not MeasureAlignment(DAT_nr, socket_nr) Then
'				Print "Could not measure alignment!"
'				Close #fileNum
'				Exit Function
'			EndIf
'			
'			dfpicname$ = DF_take_picture$(cycleinfo$ + "_DF")
'		
'			Print loopinfo$, " MODE,", SocPlaceNotDrop, ", ", SocClampFirst, ", ", SocFastClamp, " CYCLE", Str$(cycle), ":", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlignXUnc, ",", CSAlignYUnc, ",", CSAlign_U(DAT, Socket), ",", CSAlign_X(DAT, Socket), ",", CSAlign_Y(DAT, Socket)
'		
'			Print #fileNum, loopinfo$, ",", SocPlaceNotDrop, ",", SocClampFirst, ",", SocFastClamp, ",", Str$(cycle), ",", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlignXUnc, ",", CSAlignYUnc, ",", CSAlign_U(DAT, Socket), ",", CSAlign_X(DAT, Socket), ",", CSAlign_Y(DAT, Socket)
'			
'			Print "Cycle complete"
'			Print "=============================================="
'			
'		Next
'		Print loopinfo$, " loop complete"
'	Next
'	
'	Close #fileNum
'	
'Fend
'


#include "ErrorDictionary.inc"
Function TestPinAnalysis As Int64
	SelectSite("")
'	SubError = GetChipFromTray(SrcTray, SrcTrayCol, SrcTrayRow)
'	If Not SubError Then
'		RTS_error("Could not get chip from tray - GetChipFromTray=" + Str$(SubError), ERR_TRAY_PICK, True)
'		TestPinAnalysis = -ErrorCode
'		ResetOperation(True)
'		Exit Function
'	EndIf
'	
'	
'
'	UFRecenter
	TrayDirectory$ = RTS_DATA$ + "\Testing"
	String PinImages$(3)
 	' Create input array of three strings for images. Need 3 for COLDATA, only 1 for LArASIC and ColdADC
 	CurrentOperation$ = "TestPinAnalysis"

	ResetOperation(True)
	TestPinAnalysis = -1
	Motor On
	On Backlight
	OpenMLog("Begining pin analysis test")
	
	Integer fileNum
	fileNum = FreeFile
	' AOpen RTS_DATA$ + "\pins\" + id$ + "_pins.csv" As #fileNum
	String filename$
	filename$ = TrayDirectory$ + "\pins\tray_pin_test.csv"
	AOpen filename$ As #fileNum
	Print #fileNum, "Column,Row,Status,Images"
		
	Integer column, row, nchips
	nchips = 12
	For column = 1 To trayNCols
		For row = 1 To trayNRows
			nchips = nchips - 1
			CurrentOperation$ = "TestPinAnalysis_tr2_col" + Str$(column) + "_row" + Str$(row)
			
			If Not GetChipFromTray(2, column, row) Then
				Print #fileNum, Str$(column), ",", Str$(row), ",NoPick,"
				RTS_error("Cannot place chip back in tray", ERR_TRAY_PICK, True)
				TestPinAnalysis = -ErrorCode
				ResetOperation(True)
				Close #fileNum
				Exit Function
			EndIf
			
			SubError = UFPinAnalysis(CurrentOperation$, ByRef PinImages$())
			 			
		 	Print "UFPinAnalyisOutput = ", SubError
		 	Int32 i
		 	Print "Pin analysis images:"
		 	
		 	
		 	Print #FileNum, Str$(column), ",", Str$(row), ",", Str$(SubError),
		 	
		 	For i = 1 To 3
		 		Print #FileNum, ",", PinImages$(i),
		 		Print "Pin analysis image ", i, " : ", PinImages$(i)
		 	Next
		 	Print #FileNum
		 	
			If SubError < -1 Then
				RTS_error("Bad pins", ERR_PINS, False)
			EndIf
			
			If Not PlaceChipInTray(2, column, row) Then
				Print #FileNum, Str$(column), ",", Str$(row), ",NoPlace,"
				RTS_error("Cannot place chip back in tray", ERR_TRAY_PLACE, True)
				TestPinAnalysis = -ErrorCode
				ResetOperation(True)
				Close #FileNum
				Exit Function
			EndIf
			
			If nchips < 1 Then
				Exit For
			EndIf
		Next
		If nchips < 1 Then
			Exit For
		EndIf
	Next
	Close #FileNum
	CloseMLog("Finished pin analysis test")
	
Fend

'
Function MoveChipsFromFile(command_file$ As String, FirstOperation As Int32, LastOperation As Int32, Reverse As Boolean, DryRun As Boolean) As Int64
	
	MoveChipsFromFile = -ERR_BAD_COMMAND
	''' Keep this 
	NotStandalone = False
	SelectSite("")
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf

	' Use values in site file as defaults while using server
	' Other wise all will default to False
	SocPlaceNotDrop = DefaultPlaceNotDrop ' Defaults to Drop
	SocClampFirst = DefaultClampFirst ' Defaults to clamp after vacuum off
	SocFastClamp = DefaultFastClamp ' defaults to soft/slow clamping
	DoPinAnalysis = DefaultPinAnalysis ' Defaults to not running pin analysis
	SkipOccupancyChecks = DefaultSkipOcc ' Defaults to running occupancy checks 
 	SkipSocketCorrection = DefaultSkipSocCor ' Defaults to applying socket correction
 	SkipChipToChipCorrection = DefaultSkipChipCor ' Defaults to applying chip to chip correction


	LoadPositionFiles
	LoadCurrentChipOffset
	
	' left tray
	Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows

	' right tray
	Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows
	
	UpdatePositionFiles

	Motor On
	'PumpOn shoulf be called in lower level function
	SetSpeed
	
	
'	''' Make changes here	

	
	DoPinAnalysis = False
	
	Int64 status
	
'
	Int32 iChip

	Integer Occupancy

	SkipOccupancyChecks = False
	SkipSocketCorrection = False
	SkipChipToChipCorrection = False
	
	String commands$
	If command_file$ = "PRELOADED" Then
		commands$ = RTS_DATA$ + "/chips_in_dat.csv"
	Else
		commands$ = RTS_DATA$ + "/" + command_file$
	EndIf
	
	If Not FileExists(commands$) Then
		Print "[MoveChipsFromFile] Cannot find command file at ", commands$
		Exit Function
	EndIf
	


	
	If FirstOperation > 1 Then
		Print "User specified start operation index of ", FirstOperation
		Print "Cannot have less than one operation in file"
	EndIf
	
	If LastOperation > 8 Then
		Print "User specified end operation index of ", LastOperation
		Print "Currently only supports one dat board, and a DAT board has 8 positions"
	EndIf
	
	Integer FileNum
	FileNum = FreeFile
	Print "Opening file ", commands$
	ROpen commands$ As #FileNum
	String head1$, head2$, head3$, head4$, head5$, head6$
	Input #FileNum, head1$, head2$, head3$, head4$, head5$, head6$
	If head1$ = "Timestamp" Then
		Print "Using automation produced list of chips"
			
		If head2$ <> "Tray" Or head3$ <> "Column" Or head4$ <> "Row" Or head5$ <> "DAT" Or head6$ <> "Socket" Then
			Print "File does not have correct columns!"
			Print "Headers should be:"
			Print "Timestamp,Tray,Column,Row,DAT,Socket"
			Exit Function
		EndIf
		
	ElseIf head1$ = "Source" Then
		Print "Using user defined command list"
		If head2$ <> "Source_i" Or head3$ <> "Source_j" Or head4$ <> "Target" Or head5$ <> "Target_i" Or head6$ <> "Target_j" Then
			Print "File does not have correct columns!"
			Print "Headers should be:"
			Print "Timestamp,Tray,Column,Row,DAT,Socket"
			Exit Function
		EndIf
		
	Else
		Print "Invalid table headers in move command file!"
	EndIf
			
	Integer nOps

	Int64 val1(8) 'must be able to accept timestamps as well as indices
	Int32 val2(8)
	Int32 val3(8)
	Int32 val4(8)
	Int32 val5(8)
	Int32 val6(8)
	
	For iChip = 1 To LastOperation
		If iChip >= FirstOperation Then
			Input #FileNum, val1(iChip), val2(iChip), val3(iChip), val4(iChip), val5(iChip), val6(iChip)
		EndIf
	Next
		
	Close #FileNum
	
	For iChip = FirstOperation To LastOperation
		If head1$ = "Timestamp" Then
			' Timestamp, Tray, Tray_col, Tray_row, DAT, Socket
			If Not Reverse Then
				Print "Reading a chips_in_dat.csv format, assume removing chips"
				'val1 is timestamp, vals 2,3,4 are tray, vals 5,6 are socket
				If Not DryRun Then
					status = MoveChipFromSocketToTray(val5(iChip), val6(iChip), val2(iChip), val3(iChip), val4(iChip))
				Else
					Print "DryRun: MoveChipFromSocketToTray(", val5(iChip), ",", val6(iChip), ",", val2(iChip), ",", val3(iChip), ",", val4(iChip), ")"
				EndIf
			Else
				Print "Reading a chips_in_dat.csv format, but operation reversed, assume loading chips"
				If Not DryRun Then
					status = MoveChipFromTrayToSocket(val2(iChip), val3(iChip), val4(iChip), val5(iChip), val6(iChip))
				Else
					Print "DryRun: MoveChipFromTrayToSocket(", val2(iChip), ",", val3(iChip), ",", val4(iChip), ",", val5(iChip), ",", val6(iChip), ")"
				EndIf
			EndIf
		ElseIf head1$ = "Source" Then
			
			If val1(iChip) <> 0 Then
				Print "Source index is non-zero, source is tray"
				' source tray vals 1,2,3
				If val4(iChip) <> 0 Then
					Print "Target index is non-zero, target is tray"
					'target tray vals 4,5,6
					If Not Reverse Then
						Print "Forward (source tray -> target tray)"
						If Not DryRun Then
							status = MoveChipFromTrayToTray(val1(iChip), val2(iChip), val3(iChip), val4(iChip), val5(iChip), val6(iChip))
						Else
							Print "DryRun: MoveChipFromTrayToTray(", val1(iChip), ",", val2(iChip), ",", val3(iChip), ",", val4(iChip), ",", val5(iChip), ",", val6(iChip), ")"
						EndIf
					Else
						Print "Reverse (target tray -> source tray)"
						If Not DryRun Then
							status = MoveChipFromTrayToTray(val4(iChip), val5(iChip), val6(iChip), val1(iChip), val2(iChip), val3(iChip))
						Else
							Print "DryRun: MoveChipFromTrayToTray(", val4(iChip), ",", val5(iChip), ",", val6(iChip), ",", val1(iChip), ",", val2(iChip), ",", val3(iChip), ")"
						EndIf

					EndIf
				Else
					Print "Target index is zero, Target is DAT board"
					' target socket vals 5,6
					If Not Reverse Then
						Print "Forward (source tray -> target socket)"
						If Not DryRun Then
						status = MoveChipFromTrayToSocket(val1(iChip), val2(iChip), val3(iChip), val5(iChip), val6(iChip))
						Else
							Print "DryRun: MoveChipFromTrayToSocket(", val1(iChip), ",", val2(iChip), ",", val3(iChip), ",", val5(iChip), ",", val6(iChip), ")"
						EndIf
					Else
						Print "Reverse (target socket-> source tray)"
						If Not DryRun Then
							status = MoveChipFromSocketToTray(val5(iChip), val6(iChip), val1(iChip), val2(iChip), val3(iChip))
						Else
							Print "DryRun: MoveChipFromSocketToTray(", val5(iChip), ",", val6(iChip), ",", val1(iChip), ",", val2(iChip), ",", val3(iChip), ")"
						EndIf
					EndIf
				EndIf
			Else
				Print "Source index is zero, source is DAT board"
				' source socket vals 2,3
				If val4(iChip) <> 0 Then
					Print "Target index is non-zero, target is tray"
					' target tray vals 4,5,6
					If Not Reverse Then
						Print "Forward (source socket -> target tray)"
						If Not DryRun Then
							status = MoveChipFromSocketToTray(val2(iChip), val3(iChip), val4(iChip), val5(iChip), val6(iChip))
						Else
							Print "DryRun: MoveChipFromSocketToTray(", val2(iChip), ",", val3(iChip), ",", val4(iChip), ",", val5(iChip), ",", val6(iChip), ")"
						
						EndIf
					Else
						Print "Reverse (target tray -> source socket)"
						If Not DryRun Then
							status = MoveChipFromTrayToSocket(val4(iChip), val5(iChip), val6(iChip), val2(iChip), val3(iChip))
						Else
							Print "DryRun: MoveChipFromTrayToSocket(", val4(iChip), ",", val5(iChip), ",", val6(iChip), ",", val2(iChip), ",", val3(iChip), ")"
						EndIf
					EndIf
				Else
					Print "Source and Target indices are both 0"
					Print "Cannot do DAT->DAT movements!"
					Print "Skipping!"
					status = 0
				EndIf
				
			EndIf
			If status < 0 Then
				Print "ERROR, on move  ", iChip, ", exiting MoveChips command"
				MoveChipsFromFile = status
				Exit Function
			EndIf
		Else
			Print "Input format not defined"
			Exit Function
		EndIf
		ResetOperation(True)
	Next

	SkipSocketCorrection = False
	SkipChipToChipCorrection = False
	SkipOccupancyChecks = False
	
	Wait 1
	JumpToCamera
	PumpOff

	UpdatePositionFiles
	StoreCurrentChipOffset
	MoveChipsFromFile = -1
	
Fend
'
'

