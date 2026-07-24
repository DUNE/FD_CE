#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function SetSpeed
	''' Sets a default speed and acceleration
	Power Low
	Speed 100
	Accel 10, 10
	Speed 25
	Accel 2, 2
Fend

Function SetSpeedSetting(Setting$ As String)
	''' Function for setting speed for different operation mode settings
	'' Args:
	' Setting$ [String]
	'' Options for Setting
	' MoveWithoutChip
	' MoveWithChip	
	' PickAndPlace
	' AboveCamera
	'''
	
	Power Low
	Speed 100
	Accel 10, 10
	Speed 1
	Accel 1, 1
	
	' Currently keeping non MSU or FNAL speeds low until enclosures are shipped/higher speeds are allowed by safety
	If SITE$ <> "MSU" And SITE$ <> "FNAL" Then
			Exit Function
	EndIf
	
	Select Setting$
		Case "MoveWithoutChip"
			Speed 50
			Accel 10, 10
		Case "MoveWithChip"
			Speed 15
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
	''' Takes a picture with the fixed Up Facing (UF) camera	
	' and stores it in the RTS_DATA$\images directory as a bmp file
	
 	'UF_take_picture$ = RTS_DATA$ + "\images\UF_" + basename$ + ".bmp"
 	UF_take_picture$ = TrayDirectory$ + "\images\UF\" + basename$ + ".bmp"
 	
 	Print UF_take_picture$
 	VRun UF
    Wait 0.3
	VSaveImage UF, UF_take_picture$
Fend

Function DF_take_picture$(basename$ As String) As String
	''' Takes a picture with the Down Facing (UF) camera on the EOAT	
	' and stores it in the RTS_DATA$\images directory as a bmp file
	
	' DF_take_picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	DF_take_picture$ = TrayDirectory$ + "\images\DF\" + basename$ + ".bmp"
 	
	Print DF_take_picture$
 	VRun DF
    Wait 0.3
	VSaveImage DF, DF_take_picture$
Fend

Function SN_take_Picture$(ocr_dir$ As String, basename$ As String) As String
	''' Takes a picture of a chip for serial number recognition
	' Uses FindChipDirectionWithDF to preprocess the image so
	' the text is right way up to help with OCR
	' Stores image in RTS_DATA$\images as a bmp file
	
	SelectSite("InFunction")
	' SN_take_Picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	'SN_take_Picture$ = TrayDirectory$ + "\images\" + basename$ + ".bmp"
	SN_take_Picture$ = ocr_dir$ + "\" + basename$ + ".bmp"
	
	Print SN_take_Picture$
	
	Double ChipDir, Rotation
	ChipDir = FindChipDirectionWithDF
	If ChipDir < -900. Then
		SN_take_Picture$ = "NoChip"
		Exit Function
	EndIf
	
	Rotation = DiffAnglePM180(RoundAngleTo90(ChipDir), RoundAngleTo90(CU(Here) + 180.))

	Select SITE$
		Case "MSU"
			VSet MSU_DF_SN.ImgOp01.RotationAngle, Rotation
			VRun MSU_DF_SN
			Wait 0.3
			VSaveImage MSU_DF_SN, SN_take_Picture$
		Default
			Print "No site specific vision sequence for SN preprocessing (rotation) defined, using MSU sequence - not for COLDATA"
			VSet MSU_DF_SN.ImgOp01.RotationAngle, Rotation
			VRun MSU_DF_SN
			Wait 0.3
			VSaveImage MSU_DF_SN, SN_take_Picture$
	Send
 	
Fend

Function RTS_error(err_msg$ As String, Error_Code As Int32, close_mlog As Boolean) As Integer

'	''' Sets error code and updates robot log file and
'	' operation log file
'	ErrorCode = Error_Code ' Set global variable to input
	

	String log_file$
'	log_file$ = RTS_DATA$ + "\RobotOperationLogs\" + CurrentOperation$ + ".txt"
'	Integer op_log
'	op_log = FreeFile
'	AOpen log_file$ As #op_log
'	Print "***ERROR: ", err_msg$
'	Print #op_log, "***ERROR ", ErrorCode, "/", SubError, " : ", err_msg$
'	Close #op_Log	
	
	
	Integer RTS_Data
	RTS_Data = FreeFile
	log_file$ = RTS_DATA$ + "\RobotLog.txt"
	AOpen log_file$ As #RTS_Data
	Print #RTS_Data, "***ERROR ", ErrorCode, "/", SubError, " in ", CurrentOperation$, " : ", err_msg$
	Close #RTS_Data
	
	' TODO JOE, Maybe can't close mlog here as rts_error will return to highr level functions
	' as Mlog is not opened in each subfunction but at top level only to ensure
	' print is to single line per move.
	' Could add an option to RTS_error to close MLog and then only set to true
	' in Top level, otherwise just write error to mlog file?
	
	String mmsg$
	mmsg$ = "***ERROR " + Str$(ErrorCode) + "/" + Str$(SubError) + " " + err_msg$

	If mlogopen Then
		If close_mlog Then
			CloseMLog(mmsg$)
		Else
			WriteMLog(mmsg$)
		EndIf
	ElseIf close_mlog Then
		Print "WARNING: Mlog is not open but instructed to close"
		
	EndIf
	
		
Fend

Function LogSocketPlacements(DAT As Integer, Socket As Integer, OpID$ As String)
	''' Logs detailed information about the positioning of the hand during placement for
	' troubleshooting position drift
	' For each socket log
	String DefPos$, MeasPos$, SCor$, SCorPos$, LastChip$, CurrChip$, ChipCor$, PlacePos$

	DefPos$ = ""
	
	Int32 FileNum
	FileNum = FreeFile
	String SocketFile$
	SocketFile$ = RTS_DATA$ + "\SocketPlacement\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_Placements.txt"

	' Check if file exists, if not, create it with headers
	If Not FileExists(SocketFile$) Then
		DefPos$ = "Point_X,Point_Y,Point_U"
		MeasPos$ = "Meas_X,Meas_Y,Meas_U"
		SCor$ = "SockCor_X,SockCor_Y,SockCor_U"
		SCorPos$ = "SCorPos_X,SCorPos_Y,SCorPos_U"
		LastChip$ = "LastChip_X,LastChip_Y,LastChip_U"
		CurrChip$ = "CurrChip_X,CurrChip_Y,CurrChip_U"
		ChipCor$ = "ChipCor_X,ChipCor_Y,ChipCor_U"
		PlacePos$ = "Placed_X,Placed_Y,Placed_U"
	EndIf
	
	AOpen SocketFile$ As #FileNum
	
	If DefPos$ = "Point_X,Point_Y,Point_U" Then
		' Write headers if new file
		Print #FileNum, "Operation,", DefPos$, ",", MeasPos$, ",", SCor$, ",", SCorPos$, ",", LastChip$, ",", CurrChip$, ",", ChipCor$, ",", PlacePos$
	EndIf
	
	' - Defined position (1, 2, 3)
	DefPos$ = Str$(PlacePositions(1)) + "," + Str$(PlacePositions(2)) + "," + Str$(PlacePositions(3))
	' - Measured position (4, 5, 6)
	MeasPos$ = Str$(PlacePositions(4)) + "," + Str$(PlacePositions(5)) + "," + Str$(PlacePositions(6))
	' - Socket corrections (7, 8, 9)
	SCor$ = Str$(PlacePositions(7)) + "," + Str$(PlacePositions(8)) + "," + Str$(PlacePositions(9))
	' - Position After Socket correction (10, 11, 12)
	SCorPos$ = Str$(PlacePositions(10)) + "," + Str$(PlacePositions(11)) + "," + Str$(PlacePositions(12))
	' -	Last Chip offsets (13, 14, 15)
	LastChip$ = Str$(PlacePositions(13)) + "," + Str$(PlacePositions(14)) + "," + Str$(PlacePositions(15))
	' - Current Chip offsets (16, 17, 18)
	CurrChip$ = Str$(PlacePositions(16)) + "," + Str$(PlacePositions(17)) + "," + Str$(PlacePositions(18))
	' - Corrections (19, 20, 21)
	ChipCor$ = Str$(PlacePositions(19)) + "," + Str$(PlacePositions(20)) + "," + Str$(PlacePositions(21))
	' - Position after chip correction (22, 23, 24)
	PlacePos$ = Str$(PlacePositions(22)) + "," + Str$(PlacePositions(23)) + "," + Str$(PlacePositions(24))
	
	Print #FileNum, OpID$, ",", DefPos$, ",", MeasPos$, ",", SCor$, ",", SCorPos$, ",", LastChip$, ",", CurrChip$, ",", ChipCor$, ",", PlacePos$
	Close #FileNum
	
Fend

Function LogDFSocketMeasurements(DAT As Integer, Socket As Integer, OpID$ As String)
	''' Logs socket placement values for consistency checks and diagnosing any issues with drift
	' Track socket position
	' Chip position in socket with DF
	' Chip offset wirth UF when taken from socket
	' First entry is the operation ID
	' next three entries are socket position (DF cam)
	' next three entries are chip in socket positon (DF cam)
	' Next three entries are difference (chip position - socket position) (DF Cam)
	' Last two entries rotate chip-socket alignment in X and Y to take out U variation	
	
	Int32 FileNum
	FileNum = FreeFile
	String SocketFile$
	SocketFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_DF_Measurements.txt"
	
	AOpen SocketFile$ As #FileNum
		Print #FileNum, OpID$, ", DF_SocketPosition:", SockPos(1), ",", SockPos(2), ",", SockPos(3), "; DF_ChipPosition:", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), "; DF_ChipOffset:", CSAlign(1), ",", CSAlign(2), ",", CSAlign(3), ",", CSAlign(4), ",", CSAlign(5)
	Close #FileNum
	
Fend


Function LogUFOffsets(Tray As Integer, TrayCol As Integer, TrayRow As Integer, DAT As Integer, Socket As Integer) As Int32
''' In one file store the current offset along with the tray/socket position and the timestamp

	LogUFOffsets = 0
	If (tray <> 0 Or TrayCol <> 0 Or TrayRow <> 0) And (DAT <> 0 Or Socket <> 0) Then
		Print "Invalid indices"
		Exit Function
	EndIf
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	Int32 FileNum
	fileNum = FreeFile
	String OffsetFile$
	If tray <> 0 Then
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Tray_" + Str$(tray) + "_" + Str$(TrayCol) + "_" + Str$(TrayRow) + "_UF_Measurements.txt"
	Else
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_UF_Measurements.txt"
	EndIf
		
	AOpen OffsetFile$ As #fileNum
	Print #fileNum, ts$, ",", CorrectedChipOffset(1), ",", CorrectedChipOffset(2), ",", CorrectedChipOffset(3)
	Close #fileNum
	LogUFOffsets = -1
Fend

''' Returns the global point of the socket from its DAT and position numbers
Function PSocket(DAT_nr As Int32, Socket_nr As Int32) As Int32
	PSocket = DAT_nr * 100 + socket_nr
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

Function CheckValidTrayIndex(tray As Integer, tray_col As Integer, tray_row As Integer) As Boolean
	''' Checks tray indices are within bounds
         CheckValidTrayIndex = False
         If (0 < Tray And Tray <= 2) And (0 < tray_col And tray_col <= trayNCols) And (0 < tray_row And tray_row <= trayNRows) Then
                CheckValidTrayIndex = True
         EndIf
Fend

Function CheckValidSocketIndex(DAT As Integer, Socket As Integer) As Boolean
	'''Checks socket indices are within bounds	
	CheckValidSocketIndex = False
         If (0 < DAT And DAT <= 2) And (0 < Socket And Socket <= nSoc) Then
                CheckValidSocketIndex = True
         EndIf
Fend



'''  Camera offset functions
Function XOffset(UValue As Double) As Double
	''' Returns offset in X between contact point and image point at a given hand U coordinate
	XOffset = DF_CAM_X_OFF_U0 * Cos(DegToRad(UValue - HAND_U0)) - DF_CAM_Y_OFF_U0 * Sin(DegToRad(UValue - HAND_U0))
Fend

Function YOffset(UValue As Double) As Double
	''' Returns offset in Y between contact point and image point at a given hand U coordinate
	YOffset = DF_CAM_X_OFF_U0 * Sin(DegToRad(UValue - HAND_U0)) + DF_CAM_Y_OFF_U0 * Cos(DegToRad(UValue - HAND_U0))
Fend

Function SetupDirectories
	' Creates the directory RTS_DATA set in config file if not already made 
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
	
	' DF images subdirectory
	String dir_dfimages$
	dir_dfimages$ = RTS_DATA$ + "\images\DF"

	If Not FolderExists(dir_dfimages$) Then
  		MkDir dir_dfimages$
	EndIf
	
	If Not FolderExists(dir_dfimages$) Then
  		Print "***ERROR Can't create directory [" + dir_dfimages$ + "]"
  		Exit Function
	EndIf
	
	' UF images subdirectory
	String dir_ufimages$
	dir_ufimages$ = RTS_DATA$ + "\images\UF"

	If Not FolderExists(dir_ufimages$) Then
  		MkDir dir_ufimages$
	EndIf
	
	If Not FolderExists(dir_ufimages$) Then
  		Print "***ERROR Can't create directory [" + dir_ufimages$ + "]"
  		Exit Function
	EndIf
	
	' Move OCR images subdirectory
	String dir_m_sn$
	dir_m_sn$ = RTS_DATA$ + "\images\Move_SN"

	If Not FolderExists(dir_m_sn$) Then
  		MkDir dir_m_sn$
	EndIf
	
	If Not FolderExists(dir_m_sn$) Then
  		Print "***ERROR Can't create directory [" + dir_m_sn$ + "]"
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

Function SetupTrayDirectories$ As String
	' Creates the directory RTS_DATA\Tested\TrayID during automation code
	' And the subdirectories \images and \pins		
	
	' Returns file system error if interuppted/can't make a file	
	' Returns trayID if successful

	SetupTrayDirectories$ = Str$(ERR_FILESYSTEM)
	
	TrayDirectory$ = RTS_DATA$ + "\Tested\" + TrayID$

	' RTS DATA directory (set in RTS_tools.inc)
	If Not FolderExists(TrayDirectory$) Then
  		MkDir TrayDirectory$
	EndIf

	If Not FolderExists(TrayDirectory$) Then
  		Print "***ERROR Can't create directory [" + TrayDirectory$ + "]"
  		Exit Function
	EndIf
	
	' images subdirectory
	String dir_images$
	dir_images$ = TrayDirectory$ + "\images"

	If Not FolderExists(dir_images$) Then
  		MkDir dir_images$
	EndIf
	
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	' DF images subdirectory
	String dir_dfimages$
	dir_dfimages$ = TrayDirectory$ + "\images\DF"

	If Not FolderExists(dir_dfimages$) Then
  		MkDir dir_dfimages$
	EndIf
	
	If Not FolderExists(dir_dfimages$) Then
  		Print "***ERROR Can't create directory [" + dir_dfimages$ + "]"
  		Exit Function
	EndIf
	
	' UF images subdirectory
	String dir_ufimages$
	dir_ufimages$ = TrayDirectory$ + "\images\UF"

	If Not FolderExists(dir_ufimages$) Then
  		MkDir dir_ufimages$
	EndIf
	
	If Not FolderExists(dir_ufimages$) Then
  		Print "***ERROR Can't create directory [" + dir_ufimages$ + "]"
  		Exit Function
	EndIf
	
	' Move OCR images subdirectory
	String dir_m_sn$
	dir_m_sn$ = TrayDirectory$ + "\images\Move_SN"

	If Not FolderExists(dir_m_sn$) Then
  		MkDir dir_m_sn$
	EndIf
	
	If Not FolderExists(dir_m_sn$) Then
  		Print "***ERROR Can't create directory [" + dir_m_sn$ + "]"
  		Exit Function
	EndIf
	
	' pins subdirectory
	String dir_pins$
	dir_pins$ = TrayDirectory$ + "\pins"

	If Not FolderExists(dir_pins$) Then
  		MkDir dir_pins$
	EndIf
	
	If Not FolderExists(dir_pins$) Then
  		Print "***ERROR Can't create directory [" + dir_pins$ + "]"
  		Exit Function
	EndIf
		
	' Returns tray ID if no errors
	SetupTrayDirectories$ = TrayID$
	
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
'	Print "Loading position files!"
    Integer fileNum
    String fileName$
    Double x, y, u
    Double i, j, k
    Double ii, jj, kk
    
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\tray_xyu.csv"
	
	If FileExists(fileName$) Then
'		Print "Reading file ", fileName$
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
	''' Stores the measured chip-axis offset of the chip currently held by the robot
	' in a file for retreival if operations interrupted
	
	Integer fileNum
	String fileName$
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\CurrentChipOffsets.csv"
	If FileExists(fileName$) Then
		Print "Current offset file exists"
	Else
		Print "No file at ", fileName$
	EndIf
	WOpen fileName$ As #fileNum
	' Save the position set in the global arrays to the files
	Print #fileNum, CurrentChipOffset(1), ",", CurrentChipOffset(2), ",", CurrentChipOffset(3), ",", CorrectedChipOffset(1), ",", CorrectedChipOffset(2), ",", CorrectedChipOffset(3)
	Close #fileNum

Fend

Function LoadCurrentChipOffset
	''' Loads the measured chip-axis offset of the chip currently held by the robot
	' in a file for retreival if operations interrupted
	
	Integer fileNum
    String fileName$
    Double offX, offY, offU, corrOffX, corrOffY, corrOffU
    
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\CurrentChipOffsets.csv"
	
	If FileExists(fileName$) Then
'		Print "Reading file ", fileName$
		ROpen fileName$ As #fileNum

		Input #fileNum, offX, offY, offU, corrOffX, corrOffY, corrOffU
		CurrentChipOffset(1) = offX
		CurrentChipOffset(2) = offY
		CurrentChipOffset(3) = offU
		
		CorrectedChipOffset(1) = corrOffX
		CorrectedChipOffset(2) = corrOffX
		CorrectedChipOffset(3) = corrOffX

		Close #fileNum
	Else
		Print "Cannot open file ", fileName$
		Exit Function
	EndIf
	
Fend

Function ResetCurrentChipOffsets
	''' Resets the current chip offsets, for use when chip is placed down
	CurrentChipOffset(1) = 0
	CurrentChipOffset(2) = 0
	CurrentChipOffset(3) = 0
	CorrectedChipOffset(1) = 0
	CorrectedChipOffset(2) = 0
	CorrectedChipOffset(3) = 0
	StoreCurrentChipOffset
Fend

Function UpdateRobotLog$(log_msg$ As String) As String
	'Updates the Robot log file with the given log message
	
'	Integer op_log
'	String log_file$
'	log_file$ = RTS_DATA$ + "\RobotOperationLogs\" + CurrentOperation$ + ".txt"
'	op_log = FreeFile
'	AOpen log_file$ As #op_log
'	Print "(",CurrentOperation$ , ".txt): ", log_msg$
'	Print #op_log, log_msg$
'	Close #op_Log	
	
	' Set the file name for the tray position corrections
	Integer fileNum
	String fileName$
	fileNum = FreeFile
	fileName$ = RTS_DATA$ + "\RobotLog.txt"
	AOpen fileName$ As #fileNum
	
'	Print "Writing to file: ", fileName$
	Print "(RobotLog.txt) ", log_msg$
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

	If (angle > -45.) And (angle <= 45.) Then
		GetBoundAnglePM45 = angle
		Exit Function
	EndIf
	Int32 Quotiant
	Double Offset
	If angle > 0 Then
		Offset = +45.
	Else
		Offset = -45
	EndIf
	
	Angle = angle + Offset
	Quotiant = Int(angle) / 90
	angle = angle - Quotiant * 90 - Offset
	'Print Angle
	GetBoundAnglePM45 = angle

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
	''' Returns an angle rounded to the nearest 90 degrees
	
	RoundAngleTo90 = -999.
	RoundAngleTo90 = GetBoundAnglePM180(Angle)
	
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


Function ScanTray(pallet_nr As Integer, port_nr As Integer) As Int64
	''' Scans a tray and collects images of all the chips for serial number
	' extraction and stores the image file number and positions in a catalog file
	' Also sets up columns in the file for use by the integration and OCR code
	
	ScanTray = 0
	'ScanTray$ = "FAIL"
	SelectSite("InFunctionDefinePallets")

	Motor On
	UF_camera_light_ON

	String fileName$, ts$
	
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	String scan_sn_dir$
	
	fileName$ = TrayDirectory$ + "\TrayCatalog_" + TrayID$ + ".csv"
	scan_sn_dir$ = TrayDirectory$ + "\images\Scan_" + ts$ + "_SN"
	
	' Create scan OCR images subdirectory
	If Not FolderExists(scan_sn_dir$) Then
  		MkDir scan_sn_dir$
	EndIf
	
	If Not FolderExists(scan_sn_dir$) Then
  		Print "***ERROR Can't create directory [" + scan_sn_dir$ + "]"
  		Exit Function
	EndIf
	
	' fileName$ = RTS_DATA$ + "\TrayCatalogs\TrayCatalog_" + TrayID$ + ".csv"
	Integer fileNum
	fileNum = FreeFile
	Print "File path is ", fileName$
	AOpen fileName$ As #fileNum
	Print #fileNum, "tray,col,row,occupied,image,processed,serial,warnings,checked"
'
'	String list$ ''' Can't put all indices in one string as the string gets too large
'	list$ = ""
' Have to print to port in function

	SetSpeedSetting("moveWithoutChip")
	'String isChip$

	JumpToTray_camera(pallet_nr, 1, 1)
	Int32 col_nr, row_nr
	Double ChipDir
	ChipDir = -999.
	String SN_Picture$

	Int32 idx
	idx = 0

	For col_nr = 1 To trayNCols
		SetSpeedSetting("MoveWithChip")


		For row_nr = 1 To trayNRows
			
			idx = idx + 1
			' For testing
			If idx > 16 Then
				Exit For
			EndIf
			
			Move Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Y(YOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Z(DF_CAM_Z_OFF)
				
			ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
			SN_Picture$ = SN_take_Picture$(scan_sn_dir$, TrayID$ + "_" + Str$(idx) + "_" + ts$ + "_tr" + Str$(pallet_nr) + "_col" + Str$(col_nr) + "_row" + Str$(row_nr) + "_SN")
			
			If SN_Picture$ = "NoChip" Then
				Print #fileNum, pallet_nr, ",", col_nr, ",", row_nr, ",0,,,,0,0"
				UpdateRobotLog$("No chip found")
			Else
				Print #fileNum, pallet_nr, ",", col_nr, ",", row_nr, ",1,", SN_Picture$, ",,,0,0"
				If port_nr <> -1 Then
					Print #port_nr, idx
				EndIf
				UpdateRobotLog$("Picture of chip in tray taken: " + SN_Picture$)
			EndIf
			Wait 1
		Next
	Next
		
	Close #fileNum
	SetSpeedSetting("MoveWithoutChip")
	ScanTray = Val(ts$)
	
Fend


'
' MLog functions for producing logs in style of BNL
'

Function OpenMLog(init_msg$ As String) As Boolean
	''' Adds bnl style manip.csv output for compatibility with BNL automation code '''	
	
	If mlogopen Then
		Print "MLOG FILE IS ALREADY OPEN, should not be opening now!"
		OpenMLog = False
		Exit Function
	EndIf
	
	OpenMLog = False
	Print "Opening bnl style mlog (manip.csv)"
	If mlog$ = "" Then
		Print "No mlog defined!"
		Exit Function
	EndIf
	
	mlog_nr = FreeFile
	
	OnErr GoTo errHandler
	
	AOpen mlog$ As #mlog_nr
	Print "[OPENED MLOG]"
	If Not init_msg$ = "" Then
		Print "[MLOG]:", init_msg$
		Print #mlog_nr, init_msg$,
	EndIf
	OpenMLog = True
	' Set global bool for proper closing
	mlogopen = True
errHandler:
	Print "Could not open or write to mlog file (manip.csv)"
	' Will return false
	Exit Function
Fend

Function WriteMLog(mlog_message$ As String)
	If Not mlogopen Then
		Print "ERROR: MLOG IS NOT OPEN"
		Exit Function
	EndIf
	Print "[MLOG]:", mlog_message$
	Print #mlog_nr, ",", mlog_message$,
Fend

Function CloseMLog(close_msg$ As String)
	If Not mlogopen Then
		Print "ERROR: THE MLOG IS ALREADY CLOSED"
		Exit Function
	EndIf

	Close #mlog_nr
	If Not close_msg$ = "" Then
		Print "[MLOG]:", close_msg$
		Print #mlog_nr, ",", close_msg$
	Else
		Print #mlog_nr, " " ' Still need to close the file by adding a space and end line character 
		' not actually sure if it needs to be a space, might do as "" is an empty string
	EndIf
	Print "[CLOSED MLOG]"
	mlogopen = False
Fend

''' For handling information in bnl style - might not be needed
Function Init_BNL_Arrays
	
	Integer i
	For i = 1 To 12
		bnl_idx(i) = 0
	Next i

	For i = 1 To 30
		bnl_res(i) = 0
	Next i
	
Fend

Function SetSourceTray_idx(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	bnl_idx(2) = pallet_nr
	bnl_idx(3) = col_nr
	bnl_idx(4) = row_nr
Fend

Function SetTargetTray_idx(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	bnl_idx(5) = pallet_nr
	bnl_idx(6) = col_nr
	bnl_idx(7) = row_nr
Fend

Function SetSourceSocket_idx(DAT_nr As Integer, socket_nr As Integer)
	bnl_idx(8) = DAT_nr
	bnl_idx(9) = socket_nr
Fend

Function SetTargetSocket_idx(DAT_nr As Integer, socket_nr As Integer)
	bnl_idx(10) = DAT_nr
	bnl_idx(11) = socket_nr
Fend

Function MLogIdx
	' Don't want to log idx(1) which is the file name
	Print "Writing move indices to mlog"
	String idx_msg$
	idx_msg$ = Str$(bnl_idx(2))
	Integer i
	For i = 3 To 11
		idx_msg$ = idx_msg$ + "," + Str$(bnl_idx(2))
	Next
	WriteMLog(idx_msg$)
Fend

