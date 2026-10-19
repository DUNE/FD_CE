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
	
	
	Double Move_col_index(8)
	Double Move_row_index(8)
	
	Move_col_index(1) = 1
	Move_row_index(1) = 1
	
	Move_col_index(2) = 1
	Move_row_index(2) = 3
	
	Move_col_index(3) = 1
	Move_row_index(3) = 4
	
	Move_col_index(4) = 1
	Move_row_index(4) = 5
	
	Move_col_index(5) = 1
	Move_row_index(5) = 6
	
	Move_col_index(6) = 2
	Move_row_index(6) = 1
	
	Move_col_index(7) = 2
	Move_row_index(7) = 2
	
	Move_col_index(8) = 2
	Move_row_index(8) = 3
	
			
	For iChip = 1 To 8
		' put chips back in tray'
		status = MoveChipFromSocketToTray(2, iChip, 2, Move_col_index(iChip), Move_row_index(iChip))
		' put chips in sockets'
'		status = MoveChipFromTrayToSocket(2, Move_col_index(iChip), Move_row_index(iChip), 2, iChip)

		' reseat chips (just up and down exactly where they are
		'NOTE: Exit code is -1 for success (true in SPEL)
		'status = ReseatChipInSocket(2, iChip, 0)
		'If status < -1 Then
	
		If status < 0 Then
			Print "ERROR moving chip ", iChip, " to tray"
		'	Print "ERROR moving chip ", Str$(iChip), " to socket"
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
	
	WOpen test_measurement_file$ As #FileNum
	Print #FileNum, "RX,RY,RU,sX,sY,sU,aX,aY,aU,oX,oY,oU"
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
		
		Print #FileNum, CX(Here), ",", CY(Here), ",", CU(Here), ",", sX, ",", sY, ",", sU, ",", aX, ",", aY, ",", aU, ",", oX, ",", oY, ",", oU
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
			
			Print #FileNum, CX(Here), ",", CY(Here), ",", CU(Here), ",", sX, ",", sY, ",", sU, ",", aX, ",", aY, ",", aU, ",", oX, ",", oY, ",", oU
		Next
		
		MoveFromImageToPoint
		Go Here -U(FlipAngle)
		MoveFromPointToImage
		
	EndIf

	Close #FileNum
		
Fend
'
' With a chip already in the socket
Function PlacementTest(DAT_nr As Integer, Socket_nr As Integer, n_cycles As Integer)
	'2,1,50,True,False,False
	Print "Runing placement test at socket (", DAT_nr, ",", Socket_nr, ") for ", n_cycles, " cycles"

	Wait 1
	SelectSite("InFunctionDefinePallets")

' Operation option permutations
'1.    At drop height, release vacuum (drop), soft clamp
'2.    At drop height, release vacuum (drop), fast clamp
'3. X  At drop height, soft clamp, release vacuum (drop) <- Soft clamp before release will just close mechanism before chip is dropped
'4. X  At drop height, fast clamp, release vacuum (drop) <- I suspect this may damage the chip as it will be grabbing the pins and pulling chip off the vacuum straw
'5.    At placement, release vacuum, soft clamp 
'6.    At placement, release vacuum, fast clamp
'7. X  At placement, soft clamp, release vacuum <- Soft clamp before release will just bring chip up out of socket and close mechanism before chip is dropped
'8.    At placement, fast clamp, release vacuum
' 3., 4., and 7. are invalid 
	
	Boolean loop_option_place(5)
	loop_option_place(1) = False '1.
	loop_option_place(2) = False '2.
	loop_option_place(3) = True  '5.
	loop_option_place(3) = True  '6.
	loop_option_place(3) = True  '8.
	Boolean loop_option_clampfirst(5)
	loop_option_clampfirst(1) = False
	loop_option_clampfirst(2) = False
	loop_option_clampfirst(3) = False
	loop_option_clampfirst(3) = False
	loop_option_clampfirst(3) = True
	Boolean loop_option_clampfast(5)
	loop_option_clampfast(1) = False
	loop_option_clampfast(2) = True
	loop_option_clampfast(3) = False
	loop_option_clampfast(3) = True
	loop_option_clampfast(3) = True
	
	' Go to the socket
	Print "Jump to socket image"
	JumpToSocket_camera(DAT_nr, Socket_nr)

	String fname$
	
	fname$ = RTS_DATA$ + "\Placementtests.csv"
	Print "Results will be stored in ", fname$
	
	Int32 FileNum
	FileNum = FreeFile
	WOpen fname$ As #FileNum

	' Measure the initial position/alignment	
	Print "=============================================="
	If Not GetChipInSocketAlignment(DAT_nr, Socket_nr) Then
		Print "Could not measure alignment!"
		Close #FileNum
		Exit Function
	EndIf

	Double InitPos(3), PlaceU, PickU
	InitPos(1) = ChipPos(1)
	InitPos(2) = ChipPos(2)
	InitPos(3) = ChipPos(3)
	
	Print "INITIAL:", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
		
	PlaceU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), InitPos(3))
	
	Print #FileNum, "Mode,SocPlaceNotDrop,SocClampFirst,SocFastClamp,Iteration,SockX,SockY,SockU,ChipX,Chipy,ChipU,AlignXunc,AlignYunc,AlignU,AlignX,AlignY"
	
	Print #FileNum, "Initial,", SocPlaceNotDrop, ",", SocClampFirst, ",", SocFastClamp, ",0,", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
	Int32 loopindex
	For loopindex = 1 To 3
		
		String loopinfo$
		
		SocPlaceNotDrop = loop_option_place(loopindex)
		If loop_option_place(loopindex) Then
			loopinfo$ = "place_"
		Else
			loopinfo$ = "drop_"
		EndIf
		
		SocClampFirst = loop_option_clampfast(loopindex)
		If loop_option_clampfast(loopindex) Then
			loopinfo$ = loopinfo$ + "fast"
		Else
			loopinfo$ = loopinfo$ + "soft"
		EndIf
		
		Int32 cycle
		For cycle = 1 To n_cycles
			Print "Cycle ", Str$(cycle)
			Wait 1
			String dfpicname$, ufpicname$, cycleinfo$
			cycleinfo$ = "Placetest_" + loopinfo$ + "_cycle_" + Str$(cycle)
			dfpicname$ = ""
			ufpicname$ = ""
			
			' Center over chip
			Print "Center over chip with last measurement"
			JumpToSocket(DAT_nr, Socket_nr)
			PickU = DiffAnglePM180(HandChipOrientation(CHIPTYPE_NR), ChipPos(3)) ' ChipPos_U - HandChipOrientation
			Move Here :X(ChipPos(1)) :Y(ChipPos(2)) :U(PickU)
			Print Here
			Wait 5
			PumpOn
			Wait 1
			' Pick up chip
			Print "Pick up the chip" ' CURRENTLY COMMENTED OUT"
			If Not PickupFromSocket Then
				Print "Could not pick up chip"
				Close #FileNum
				Exit Function
			EndIf
			Wait 5
			
		
	'		' If check pins
	'		If check_pins Then
	'			' Go to UFC
	'			JumpToCamera
	'
	'			' Take picture
	'			ufpicname$ = UF_take_picture$(cycleinfo$ + "_UF_pins")
	'			
	'			' Return to socket
	'			JumpToSocket(DAT_nr, Socket_nr)
	'		EndIf
	
			' Recenter over initial chip position (wrt socket? or absolute?)
			
			' Absolute initial position of chip
			Print "Move hand to align with initial position as best we can"
			Move Here :X(InitPos(1)) :Y(InitPos(2)) :U(PlaceU)
			Print Here
			
			' Place down chip
			Print "Place in socket" ' CURRENTLY COMMENTED OUT"
			If Not PlaceInSocket Then
				Print "Could not place chip"
				Close #FileNum
				Exit Function
			EndIf
			PumpOff
			Wait 1
			
			
			Print "Remeasure socket placment"
			' Measure post pick/place alignment
			If Not GetChipInSocketAlignment(DAT_nr, Socket_nr) Then
				Print "Could not measure alignment!"
				Close #FileNum
				Exit Function
			EndIf
			
			dfpicname$ = DF_take_picture$(cycleinfo$ + "_DF")
		
			Print loopinfo$, " MODE,", SocPlaceNotDrop, ", ", SocClampFirst, ", ", SocFastClamp, " CYCLE", Str$(cycle), ":", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
		
			Print #FileNum, loopinfo$, ",", SocPlaceNotDrop, ",", SocClampFirst, ",", SocFastClamp, ",", Str$(cycle), ",", SockPos(1), ",", SockPos(2), ",", SockPos(3), ",", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ",", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
			
			Print "Cycle complete"
			Print "=============================================="
			
		Next
		Print loopinfo$, " loop complete"
	Next
	
	Close #FileNum
	
Fend

Function MeasureAllAlignments(DAT_nr As Integer) As Int64
	MeasureAllAlignments = 0
	Motor On
	SelectSite("")
	String meas_ts$
	meas_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Double AlignXunc(8)
	Double AlignX(8)
	Double AlignYunc(8)
	Double AlignY(8)
	Double AlignU(8)
	String socket_picture$(8)
	Integer socket_nr
	

	For socket_nr = 1 To 8
		If Not GetChipInSocketAlignment(DAT_nr, socket_nr) Then
			Print "Could not get alignment for socket (", DAT_nr, ",", socket_nr, ")"
			AlignXunc(socket_nr) = 0
			AlignX(socket_nr) = 0
			AlignYunc(socket_nr) = 0
			AlignY(socket_nr) = 0
			AlignU(socket_nr) = 0
		Else
			AlignXunc(socket_nr) = CSAlign(1)
			AlignYunc(socket_nr) = CSAlign(2)
			AlignU(socket_nr) = CSAlign(3)
			AlignX(socket_nr) = CSAlign(4)
			AlignY(socket_nr) = CSAlign(5)
		EndIf
		
		socket_picture$(socket_nr) = DF_take_picture$("Alignment_" + meas_ts$ + "_DAT" + Str$(DAT_nr) + "_skt" + Str$(socket_nr))
		
	Next
	

	Print "Summary:"
		
		
	Integer fileNum
	fileNum = FreeFile
	String outfile$
	outfile$ = RTS_DATA$ + "\AlignCheck_DAT" + Str$(DAT_nr) + ".csv"
	WOpen outfile$ As #fileNum
	Print #fileNum, "Socket,DelX,DelY,DelU,Image,ImageProc"
	For socket_nr = 1 To 8
		Print "DAT ", DAT_nr, ", SOCKET ", socket_nr, ": Delta X (uncorrected) = ", AlignX(socket_nr), " (", AlignXunc(socket_nr), "), Delta Y  (uncorrected)= ", AlignY(socket_nr), " (", AlignYunc(socket_nr), "), Delta U = ", AlignU(socket_nr), ","
		Print #fileNum, socket_nr, ",", AlignX(socket_nr), ",", AlignY(socket_nr), ",", AlignU(socket_nr), ",", socket_picture$(socket_nr), ","
	Next
	Close #fileNum
	
	JumpToCamera
	
	MeasureAllAlignments = Val(meas_ts$)
	Print "Results in ", outfile$
	
Fend

