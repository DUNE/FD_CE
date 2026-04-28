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
	
 	UF_take_picture$ = RTS_DATA$ + "\images\UF_" + basename$ + ".bmp"
 	Print UF_take_picture$
 	VRun UF
    Wait 0.3
	VSaveImage UF, UF_take_picture$
Fend

Function DF_take_picture$(basename$ As String) As String
	''' Takes a picture with the Down Facing (UF) camera on the EOAT	
	' and stores it in the RTS_DATA$\images directory as a bmp file
	
	DF_take_picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	Print DF_take_picture$
 	VRun DF
    Wait 0.3
	VSaveImage DF, DF_take_picture$
Fend

Function SN_take_Picture$(basename$ As String) As String
	''' Takes a picture of a chip for serial number recognition
	' Uses FindChipDirectionWithDF to preprocess the image so
	' the text is right way up to help with OCR
	' Stores image in RTS_DATA$\images as a bmp file
	
	SelectSite("InFunction")
	SN_take_Picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
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

Function RTS_error(err_msg$ As String, Error_Code As Int32) As Integer
	''' Sets error code and updates robot log file and
	' operation log file
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

Function CheckValidTrayIndex(tray As Integer, tray_col As Integer, tray_row As Integer) As Boolean
	''' Checks tray indices are within bounds
         CheckValidTrayIndex = False
         If (0 < tray And tray <= 2) And (0 < tray_col And tray_col <= trayNCols) And (0 < tray_row And tray_row <= trayNRows) Then
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
	''' Returns an angle rounded to the nearest 90 degrees
	
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


Function ScanTray(pallet_nr As Integer, TrayName$ As String) As Int64
	''' Scans a tray and collects images of all the chips for serial number
	' extraction and stores the image file number and positions in a catalog file
	' Also sets up columns in the file for use by the integration and OCR code
	
	ScanTray = 0
	SelectSite("InFunctionDefinePallets")

	Motor On
	UF_camera_light_ON

	String fileName$, ts$
	fileName$ = RTS_DATA$ + "\TrayCatalogs\TrayCatalog_" + TrayName$ + ".csv"
	Integer fileNum
	fileNum = FreeFile
	AOpen fileName$ As #fileNum
	Print #fileNum, "tray,col,row,occupied,image,processed,serial,warnings,checked"

	SetSpeedSetting("moveWithoutChip")
	'String isChip$

	JumpToTray_camera(pallet_nr, 1, 1)
	Int32 col_nr, row_nr
	Double ChipDir
	ChipDir = -999.
	String SN_Picture$

	For col_nr = 1 To trayNCols
		SetSpeedSetting("MoveWithChip")
		
		' for testing
'		If col_nr <> 1 Then
'			Exit For
'		EndIf
		For row_nr = 1 To trayNRows

'			' Testing
'			If row_nr <> 1 Then
'				Exit For
'			EndIf
			
			Move Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Y(YOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Z(DF_CAM_Z_OFF)
				
			ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
			SN_Picture$ = SN_take_Picture$(ts$ + "_tr" + Str$(pallet_nr) + "_col" + Str$(col_nr) + "_row" + Str$(row_nr) + "_SN")
			
			If SN_Picture$ = "NoChip" Then
				Print #fileNum, pallet_nr, ",", col_nr, ",", row_nr, ",0,,,,0,0"
				UpdateRobotLog$("No chip found")
			Else
				Print #fileNum, pallet_nr, ",", col_nr, ",", row_nr, ",1,", SN_Picture$, ",,,0,0"
				UpdateRobotLog$("Picture of chip in tray taken: " + SN_Picture$)
			EndIf
			Wait 1
		Next
	Next
		
	Close #fileNum
	SetSpeedSetting("MoveWithoutChip")
	ScanTray = Val(ts$)
	
Fend




