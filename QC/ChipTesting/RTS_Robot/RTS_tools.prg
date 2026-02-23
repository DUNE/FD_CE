#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

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





' Prints error msg both to console and file
'' closes the output file
'Function RTS_error(fileNum As Integer, err_msg$ As String)
'	Print "***ERROR! ", err_msg$, ", Last SubError=", SubError
'	Print #fileNum, "***ERROR! ", err_msg$, ", Last SubError=", SubError
'	Close #fileNum
'Fend
'
'' For subroutines to not close the error file, and close at top level Move Function instead
'Function RTS_suberror(fileNum As Integer, err_msg$ As String, err_code As Int32)
'	SubError = -ERR_code
'	Print "***ERROR! ", err_msg$
'	Print #fileNum, "***ERROR! ", err_msg$,
'Fend

''' Uses the FNAL style update log which closes file each time to prevent issues rather than 
' needing to be careful about closing file at end of function
' Also will print errors to both operation log and to robot log.
Function RTS_error(err_msg$ As String, Error_Code As Int32) As Integer
	ErrorCode = Error_Code ' Set global variable to input
	String log_file$
	log_file$ = RTS_DATA$ + "\" + CurrentOperation$ + ".txt"
	RTS_error = FreeFile
	AOpen log_file$ As #RTS_error
	Print "***ERROR: ", err_msg$
	Print #RTS_error, "***ERROR ", ErrorCode, "/", SubError, " : ", err_msg$
	Close #RTS_error
	
	Integer RTS_Data
	RTS_Data = FreeFile
	log_file$ = RTS_DATA$ + "\RobotLog.txt"
	AOpen log_file$ As #RTS_Data
	Print #RTS_Data, "***ERROR ", ErrorCode, "/", SubError, " in ", CurrentOperation$, " : ", err_msg$
	Close #RTS_Data
Fend

''' Want to keep track of socket placement for diagnostics
' Track socket position
' Chip position in socket with DF
' Chip offset wirth UF when taken from socket
' First entry is the operation ID
' next three entries are socket position (DF cam)
' next three entries are chip in socket positon (DF cam)
' Next three entries are difference (chip position - socket position) (DF Cam)
' Last two entries rotate chip-socket alignment in X and Y to take out U variation
Function LogDFSocketMeasurements(DAT As Integer, Socket As Integer, OpID$ As String)
	Int32 FileNum
	FileNum = FreeFile
	String SocketFile$
	SocketFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_DF_Measurements.txt"
	
	AOpen SocketFile$ As #FileNum
		Print #FileNum, OpID$, ", DF_SocketPosition:", SockPos(1), ",", SockPos(2), ",", SockPos(3), "; DF_ChipPosition:", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), "; DF_ChipOffset:", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
	Close #FileNum
	
Fend

''' In one file store the current offset along with the tray/socket position and the timestamp
Function LogUFOffsets(Tray As Integer, TrayCol As Integer, TrayRow As Integer, DAT As Integer, Socket As Integer) As Int32
	LogUFOffsets = 0
	If (Tray <> 0 Or TrayCol <> 0 Or TrayRow <> 0) And (DAT <> 0 Or Socket <> 0) Then
		Print "Invalid indices"
		Exit Function
	EndIf
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Int32 FileNum
	FileNum = FreeFile
	String OffsetFile$
	If Tray <> 0 Then
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Tray_" + Str$(Tray) + "_" + Str$(TrayCol) + "_" + Str$(TrayRow) + "_UF_Measurements.txt"
	Else
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_UF_Measurements.txt"
	EndIf
		
	AOpen OffsetFile$ As #fileNum
	Print #fileNum, ts$, ",", CorrectedChipOffset(1), ",", CorrectedChipOffset(2), ",", CorrectedChipOffset(3)
	Close #fileNum
	LogUFOffsets = -1
Fend

''' Checks whether an operation is a move/swap/remove/place etc
'' Args:
' ByRef idx(Length 20) - includes input indices for command
' Byref Operation$ - A string to store what type of motion it is 
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

''' Checks the initial occupancies of the source and target tray/socket positions
'' Args:
' ts$ - timestamp for error logging purposes
' idx(Length 20) - input indices for operation
' Operation$ - Operation type as string set by CheckOperationType()
' Image$ - String to store names of images taken when checking occupancy for logging
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


'''
' Plan to implement some error handlinhg below
'''

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


''' Unified logging for MoveChip function
' Allows consistent results to be logged even when the operation has an error mid way through - note, separate to RTS_error.
'' Args:
' ts$ - Time stamp for logging/file naming
' ExitCode- The exit code of the operation - see error handling include
' OperationType$ - operation type. (Swap/remove/place etc)
' ByRef idx(Length 20) - The input indices in the standardized order
' ByRef SourceSocketResults(Length 16) - Vision sequence results
' ByRef TargetSocketResults(Length 16)
' ByRef UFCameraResults1(Length 13)
' ByRef UFCameraResults2(Length 13)
' ByRef Images$(Length 14) - An array of image names for the different parts of the operation in a standardized order
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



''' Returns the global point of the socket from its DAT and position numbers
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

''' For a batch of operations, check each operation has valid input indices
' Batch operations are not fully implemented yet but will take an array of indices for each argument of the move function
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

Function CheckValidTrayIndex(tray As Integer, tray_col As Integer, tray_row As Integer) As Boolean
         CheckValidTrayIndex = False
         If (0 < tray And tray <= 2) And (0 < tray_col And tray_col <= trayNCols) And (0 < tray_row And tray_row <= trayNRows) Then
                CheckValidTrayIndex = True
         EndIf
         Return
Fend

Function CheckValidSocketIndex(DAT As Integer, Socket As Integer) As Boolean
         CheckValidSocketIndex = False
         If (0 < DAT And DAT <= 2) And (0 < Socket And Socket <= nSoc) Then
                CheckValidSocketIndex = True
         EndIf
         Return

Fend



'''  Camera offset functions
' At current UValue of hand, return the offset in X and Y of the camera from the axis of rotation/stinger
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
	
	' position recording directory
	String dir_vis_meas$
	dir_vis_meas$ = RTS_DATA$ + "\VisionMeasurements"
	
	If Not FolderExists(dir_vis_meas$) Then
  		MkDir dir_vis_meas$
	EndIf
	
	If Not FolderExists(dir_vis_meas$) Then
  		Print "***ERROR Can't create directory [" + dir_vis_meas$ + "]"
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
	Print "Loading position files!"
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
	Else
		Print "File [", RTS_DATA$, "\tray_xyu.csv] does not exist!"
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

Function StoreCurrentChipOffset
		
	Integer fileNum
	String fileName$
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\CurrentChipOffsets.csv"
	WOpen fileName$ As #fileNum
	' Save the position set in the global arrays to the files
	Print #fileNum, CurrentChipOffset(1), ",", CurrentChipOffset(2), ",", CurrentChipOffset(3), ",", CorrectedChipOffset(1), ",", CorrectedChipOffset(2), ",", CorrectedChipOffset(3)
	Close #fileNum

Fend

Function LoadCurrentChipOffset
	Print "Loading chip offsets"
	Integer fileNum
    String fileName$
    Double offX, offY, offU, corrOffX, corrOffY, corrOffU
    
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\CurrentChipOffsets.csv"
	
	If FileExists(fileName$) Then
		Print "Reading file ", fileName$
		ROpen fileName$ As #fileNum

		Input #fileNum, offX, offY, offU, corrOffX, corrOffY, corrOffU
		CurrentChipOffset(1) = offX
		CurrentChipOffset(2) = offY
		CurrentChipOffset(3) = offU
		
		CorrectedChipOffset(1) = corrOffX
		CorrectedChipOffset(2) = corrOffX
		CorrectedChipOffset(3) = corrOffX

	EndIf
	Close #fileNum
	
Fend

Function ResetCurrentChipOffsets
	Print "Restore function currently commented out"
'	CurrentChipOffset(1) = 0
'	CurrentChipOffset(2) = 0
'	CurrentChipOffset(3) = 0
'	CorrectedChipOffset(1) = 0
'	CorrectedChipOffset(2) = 0
'	CorrectedChipOffset(3) = 0
'	StoreCurrentChipOffset
Fend

'''' More generic log updating function
'' log_file is the name of the file
'' Assigned ID is the unique ID of the chip to be added to every string for logging
'' log_msg is the message
''' If AssignedID$ is empty = "", will not add to files
'Function UpdateLog(log_file$ As String, AssignedID$ As String, log_msg$ As String) As Integer
'	UpdateLog = FreeFile
'	AOpen log_file$ As #UpdateLog
'	If AssignedID$ <> "" Then
'		Print #UpdateLog,(AssignedID$ + " " + log_msg$)
'	Else
'		Print #UpdateLog, log_msg$
'	EndIf
'
'	Close #UpdateLog
'Fend

'Function UpdateLog(UpdateType$ As String, log_msg$ As String) As Integer
'	
'	String log_file$, robot_log$, err_log$, op_log$
'	
'	'  Update main log
'	'  RTS_DATA$ + "\RobotLog.txt"	
'	
'	'  Update operation log
'	'  RTS_DATA$ + "\{Operation}.txt"
'	
'	'  Update error log
'	'  RTS_DATA$ + "\RobotErrors.txt"
'
'	'  Update specified log
'	'  RTS_DATA$ + "\log_file$"	
'
'
'	TheMsg$ = ""
'	Select UpdateType$
'		Case "operation" ' A log for the specific operation
'			log_file$ = RTS_DATA$ + "\" + CurrentOperation$ + ".txt"
'			TheMsg = log_msg$
'		Case "ERROR" ' An error log
'			log_file$ = RTS_DATA$ + "\RobotLog.txt"
'			TheMsg$ = "ERROR: " + log_msg$
'		Default ' Uses the default RTS log
'			log_file$ = RTS_DATA$ + "\RobotLog.txt"
'			TheMsg = log_msg$
'	Send
'		
'	UpdateLog = FreeFile
'	AOpen log_file$ As #UpdateLog
'	Print #UpdateLog, TheMsg$
'	Close #UpdateLog
'	
'Fend


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


'''' Angle helper functions ''''

Function GetBoundAnglePM180(Angle As Double) As Double
' Return an angle within -180 to 180 degrees
	
	If (Angle > -180.) And (Angle <= 180.) Then
		GetBoundAnglePM180 = Angle
		Exit Function
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

	If (Angle > -45.) And (Angle <= 45.) Then
		GetBoundAnglePM45 = Angle
		Exit Function
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
	AverageAnglePM180 = -999.
	If Abs(u1 - u2) > 180 Then
	Print "Diff greater than 180, Av around pi not 0"
	' Need to average around -pi and pi
		If Abs(u1) > Abs(u2) Then
			Print "U1 Closer to pi boundary, pick value on U2 side"
			AverageAnglePM180 = (u2 - u1) /2
		Else
			Print "U2 Closer to pi boundary, pick value on U1 side"
			AverageAnglePM180 = (u1 - u2) /2
		EndIf
	Else
		Print "Diff does not cross pi boundary, av around 0 as usual"
		AverageAnglePM180 = (u1 + u2) /2
	EndIf
	Print "Average = ", AverageAnglePM180
Fend

Function RoundAngleTo90(angle As Double) As Double
         RoundAngleTo90 = -999.
         RoundAngleTo90 = GetBoundAnglePM180(angle)

         If RoundAngleTo90 < -135. Then
            RoundAngleTo90 = 180.
         ElseIf RoundAngleTo90 < -45. Then
              RoundAngleTo90 = -90.
         ElseIf RoundAngleTo90 < 45. Then
              RoundAngleTo90 = 0.
         ElseIf RoundAngleTo90 < 135. Then
              RoundAngleTo90 = 90.
         Else
                RoundAngleTo90 = 180.
         EndIf
Fend


Function PhotographAllChipsInTray(pallet_nr As Integer, TrayName$ As String)
	SelectSite("InFunctionDefinePallets")
	SetSpeedSetting("MoveWithChip")
	String fileName$
	fileName$ = RTS_DATA$ + "\TrayCatalog_" + TrayName$ + ".txt"
	Integer fileNum
	fileNum = FreeFile
	AOpen fileName$ As #fileNum
	Print #fileNum, TrayName$, " chip image catalog"
	
	
	JumpToTray_camera(pallet_nr, 1, 1)
	Int32 col_nr, row_nr
	For col_nr = 1 To trayNCols
		For row_nr = 1 To trayNRows
			If col_nr = 1 And row_nr Then
				JumpToTray_camera(pallet_nr, 1, 1)
			Else
				If pallet_nr = 1 Then
					Move Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0 + 180)) +Y(YOffset(HAND_U0 + 180)) +Z(DF_CAM_Z_OFF) :U(HAND_U0 + 180) /(Hand(Pallet(pallet_nr, col_nr, row_nr)))
				ElseIf pallet_nr = 2 Then
					Move Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) /(Hand(Pallet(pallet_nr, col_nr, row_nr)))
				EndIf
			EndIf
			
			Wait 1
			String name$, picname$
			name$ = "Tray_" + TrayName$ + "_Chip_" + Str$(col_nr) + "_" + Str$(row_nr) + "_SN"
			picname$ = DF_take_picture$(name$)
			Print #fileNum, picname$
		Next
	Next
		
	Close #fileNum
	SetSpeedSetting("MoveWithoutChip")
Fend




