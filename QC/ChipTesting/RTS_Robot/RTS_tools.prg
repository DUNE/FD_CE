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
 	
	SelectSite("InFunction")
 	
 	If TrayDirectory$ = "" Then
		TrayDirectory$ = RTS_DATA$
	EndIf
 	
	String dir_images$
	dir_images$ = TrayDirectory$ + "\images"

	If Not FolderExists(dir_images$) Then
		Print "No images directory in ", TrayDirectory$, ", will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	dir_images$ = TrayDirectory$ + "\images\UF"
	If Not FolderExists(dir_images$) Then
		Print "No UF images directory in ", TrayDirectory$, "\images, will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
 	
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
	
	SelectSite("InFunction")
	
	If TrayDirectory$ = "" Then
		TrayDirectory$ = RTS_DATA$
	EndIf
	
	String dir_images$
	dir_images$ = TrayDirectory$ + "\images"

	If Not FolderExists(dir_images$) Then
		Print "No images directory in ", TrayDirectory$, ", will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	dir_images$ = TrayDirectory$ + "\images\DF"
	If Not FolderExists(dir_images$) Then
		Print "No DF images directory in ", TrayDirectory$, "\images, will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	' DF_take_picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	DF_take_picture$ = TrayDirectory$ + "\images\DF\" + basename$ + ".bmp"
 	
	Print DF_take_picture$
 	VRun DF
    Wait 0.3
	VSaveImage DF, DF_take_picture$
Fend

Function SN_take_Picture$(SN_dir$ As String, basename$ As String) As String
	''' Takes a picture of a chip for serial number recognition
	' Uses FindChipDirectionWithDF to preprocess the image so
	' the text is right way up to help with OCR
	' Stores image in RTS_DATA$\images as a bmp file
	
	SelectSite("InFunction")
	' SN_take_Picture$ = RTS_DATA$ + "\images\" + basename$ + ".bmp"
	'SN_take_Picture$ = TrayDirectory$ + "\images\" + basename$ + ".bmp"
			
	If TrayDirectory$ = "" Then
		TrayDirectory$ = RTS_DATA$
	EndIf

	If Not FolderExists(SN_dir$) Then
		Print "No SN directory at ", SN_dir$, ", will create one ..."
  		MkDir SN_dir$
	EndIf
	If Not FolderExists(SN_dir$) Then
  		Print "***ERROR Can't create directory [" + SN_dir$ + "]"
  		Exit Function
	EndIf
	
	SN_take_Picture$ = SN_dir$ + "\" + basename$ + ".bmp"
	
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

Function Socket_take_picture$(subdir$ As String, basename$ As String) As String
	''' Takes a picture with the Down Facing (UF) camera on the EOAT	
	' and stores it in the RTS_DATA$\images\DF\Socket\subdir$ directory as a bmp file
	
	SelectSite("InFunction")
	
	If TrayDirectory$ = "" Then
		TrayDirectory$ = RTS_DATA$
	EndIf
	
	String dir_images$
	dir_images$ = TrayDirectory$ + "\images"

	If Not FolderExists(dir_images$) Then
		Print "No images directory in ", TrayDirectory$, ", will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	dir_images$ = TrayDirectory$ + "\images\DF"
	If Not FolderExists(dir_images$) Then
		Print "No DF images directory in ", TrayDirectory$, "\images, will create one ..."
  		MkDir dir_images$
	EndIf
	If Not FolderExists(dir_images$) Then
  		Print "***ERROR Can't create directory [" + dir_images$ + "]"
  		Exit Function
	EndIf
	
	String sock_images$
	sock_images$ = TrayDirectory$ + "\images\DF\Socket"
	If Not FolderExists(sock_images$) Then
		Print "No DF images directory in ", TrayDirectory$, "\images\DF, will create one ..."
  		MkDir sock_images$
	EndIf
	If Not FolderExists(sock_images$) Then
  		Print "***ERROR Can't create directory [" + sock_images$ + "]"
  		Exit Function
	EndIf
	
	String full_path$
	If subdir$ <> "" Then
		full_path$ = TrayDirectory$ + "\images\DF\Socket\" + subdir$
		If Not FolderExists(full_path$) Then
			Print "No DF images directory in ", full_path$, " will create one ..."
	  		MkDir full_path$
		EndIf
		If Not FolderExists(full_path$) Then
	  		Print "***ERROR Can't create directory [" + full_path$ + "]"
	  		Exit Function
		EndIf
	Else
		full_path$ = TrayDirectory$ + "\images\DF\Socket"
 	EndIf
 	
	Socket_take_picture$ = full_path$ + "\" + basename$ + ".bmp"
	
	Print Socket_take_picture$
 	VRun DF
    Wait 0.3
	VSaveImage DF, Socket_take_picture$
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

Function LogTestMeasurements(op$ As String, optype$ As String, Pos0 As Integer, Pos1 As Integer, Pos2 As Integer, label$ As String, XVal As Double, YVal As Double, UVal As Double)
	''' More simple way to save measurements for later checks
	String Measurements$
	Int32 FileNum
	FileNum = FreeFile
	Measurements$ = RTS_DATA$ + "\TestMeasurements.csv"
	
	Boolean PrintFirstLine
	PrintFirstLine = False
	
	If Not FileExists(Measurements$) Then
		PrintFirstLine = True
	EndIf
	
	AOpen Measurements$ As #FileNum
	
	If PrintFirstLine Then
		Print "Creating new test measurements file!"
		Print #FileNum, "Operation,Type,Pos0,Pos1,Pos2,Label,X,Y,U"
	EndIf
	
	Print "[TEST MEASUREMENT]", op$, ",", optype$, ",", Str$(Pos0), ",", Str$(Pos1), ",", Str$(Pos2), ",", label$, ",", Str$(XVal), ",", Str$(YVal), ",", Str$(UVal)
	Print #FileNum, op$, ",", optype$, ",", Str$(Pos0), ",", Str$(Pos1), ",", Str$(Pos2), ",", label$, ",", Str$(XVal), ",", Str$(YVal), ",", Str$(UVal)
	
	Close #FileNum
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
	SocketFile$ = RTS_DATA$ + "\SocketPlacement\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_Placements.csv"

	Print "Saving socket place information to ", SocketFile$

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
	
	Print #FileNum, OpID$,
	' - Defined position (1, 2, 3)
	DefPos$ = Str$(PlacePositions(1)) + "," + Str$(PlacePositions(2)) + "," + Str$(PlacePositions(3))
	Print "Defined position                       (", DefPos$, ")"
	Print #FileNum, ",", DefPos$,
	
	' - Measured position (4, 5, 6)
	MeasPos$ = Str$(PlacePositions(4)) + "," + Str$(PlacePositions(5)) + "," + Str$(PlacePositions(6))
	Print "Measured position                      (", MeasPos$, ")"
	Print #FileNum, ",", MeasPos$,
	
	' - Socket corrections (7, 8, 9)
	SCor$ = Str$(PlacePositions(7)) + "," + Str$(PlacePositions(8)) + "," + Str$(PlacePositions(9))
	Print "Socket Corrections                     (", SCor$, ")"
	Print #FileNum, ",", SCor$,
	
	' - Position After Socket correction (10, 11, 12)
	SCorPos$ = Str$(PlacePositions(10)) + "," + Str$(PlacePositions(11)) + "," + Str$(PlacePositions(12))
	Print "Position after socket correction       (", SCorPos$, ")"
	Print #FileNum, ",", SCorPos$,

	' -	Last Chip offsets (13, 14, 15)
	LastChip$ = Str$(PlacePositions(13)) + "," + Str$(PlacePositions(14)) + "," + Str$(PlacePositions(15))
	Print "Last chip offset                       (", LastChip$, ")"
	Print #FileNum, ",", LastChip$,
	
	' - Current Chip offsets (16, 17, 18)
	CurrChip$ = Str$(PlacePositions(16)) + "," + Str$(PlacePositions(17)) + "," + Str$(PlacePositions(18))
	Print "Current chip offset                    (", CurrChip$, ")"
	Print #FileNum, ",", CurrChip$,

	' - Corrections (19, 20, 21)
	ChipCor$ = Str$(PlacePositions(19)) + "," + Str$(PlacePositions(20)) + "," + Str$(PlacePositions(21))
	Print "Chip correctin                         (", ChipCor$, ")"
	Print #FileNum, ",", ChipCor$,
	
	' - Position after chip correction (22, 23, 24)
	PlacePos$ = Str$(PlacePositions(22)) + "," + Str$(PlacePositions(23)) + "," + Str$(PlacePositions(24))
	Print "Final place position after correction  (", PlacePos$, ")"
	Print #FileNum, ",", PlacePos$
		
	
	'Print #FileNum, OpID$, ",", DefPos$, ",", MeasPos$, ",", SCor$, ",", SCorPos$, ",", LastChip$, ",", CurrChip$, ",", ChipCor$, ",", PlacePos$
	Close #FileNum
	Print "Socket placement logged"
	
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
	SocketFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_DF_Measurements.csv"
	
	String SockPos$, ChipPos$, ChipOff$, ChipOffU$
	
	If Not FileExists(SocketFile$) Then
		SockPos$ = "SocX,SockY,SockU"
		ChipPos$ = "ChipX,ChipY,ChipU"
		ChipOff$ = "OffX,OffY,OffU"
		ChipOffU$ = "UCorOffX,UCorOffY,OffU"
	EndIf
	
	AOpen SocketFile$ As #fileNum
	
	If SockPos$ <> "" Then
		' Write headers to file
		Print ""
		Print #fileNum, "Operation,", SockPos$, ",", ChipPos$, ",", ChipOff$, ",", ChipOffU$
	EndIf
		
	Print "Operation is ", OpID$
	Print #fileNum, OpID$,

	
	SockPos$ = Str$(SockPos(1)) + "," + Str$(SockPos(2)) + "," + Str$(SockPos(3))
	Print "Socket position after placing (", SockPos$, ")"
	Print #fileNum, ",", SockPos$,
	
	ChipPos$ = Str$(ChipPos(1)) + "," + Str$(ChipPos(2)) + "," + Str$(ChipPos(3))
	Print "Chip position after placing (", ChipPos$, ")"
	Print #fileNum, ",", ChipPos$,
	
	ChipOff$ = Str$(CSAlign(1)) + "," + Str$(CSAlign(2)) + "," + Str$(CSAlign(3))
	Print "Chip socket alignment after placing (", ChipOff$, ")"
	Print #fileNum, ",", ChipOff$,
	
	ChipOffU$ = Str$(CSAlign(4)) + "," + Str$(CSAlign(5)) + "," + Str$(CSAlign(3))
	Print "Chip socket alignment after placing (U corrected) (", ChipOff$, ")"
	Print #fileNum, ",", ChipOffU$
	
	Close #fileNum
	
Fend


Function SetTargetAlignment(DAT As Integer, Socket As Integer, Fresh As Boolean, ForceDefault As Boolean) As Boolean
	''' If tests are working, measure the socket chip alignemtn and set it in file
	' Setting socket to 0 will measure all chips on board
	SetTargetAlignment = False
	
	Double DefX, DefY, DefU
	
	DefX = 0.1
	DefY = -0.1
	DefU = 0.2
	
	If Fresh Then
		Print "Will zero out any measurements not taken now (CAREFUL IF TWO DAT BOARDS OR JUST ONE CHIP)"
	Else
		GetTargetAlignments
	EndIf
	
	SelectSite("InFunctionDefinePallets")
	Motor On

	If DAT < 0 Or DAT > 2 Then
		Print "INVALID DAT BOARD: DAT board must be specified as 1 or 2"
		Exit Function
	EndIf
	

	If Socket < 0 Or Socket > nSoc Then
		Print "INVALID SOCKET: Socket must be in range or be 0 (set all sockets)"
		Exit Function
	EndIf
	
	Int32 dtb, drange_l, drange_u
	Int32 soc, srange_l, srange_u
	
	If DAT = 0 Then
		drange_l = 1
		drange_u = 2
	Else
		drange_l = DAT
		drange_u = DAT
	EndIf
	
	If Socket = 0 Then
		srange_l = 1
		srange_u = nSoc
	Else
		srange_l = Socket
		srange_u = Socket
	EndIf
	
	For dtb = drange_l To drange_u
		For soc = srange_l To srange_u
			If ForceDefault Then
				TCSAlign_X(dtb, soc) = DefX
				TCSAlign_Y(dtb, soc) = DefY
				TCSAlign_U(dtb, soc) = DefU
			ElseIf GetChipInSocketAlignment(dtb, soc) = -1 Then
				TCSAlign_X(dtb, soc) = CSAlign(4) ' Use socket U corrected value
				TCSAlign_Y(dtb, soc) = CSAlign(5)
				TCSAlign_U(dtb, soc) = CSAlign(3)
			Else
				Print "WARNING Could not determine offset!!!"
				TCSAlign_X(dtb, soc) = DefX
				TCSAlign_Y(dtb, soc) = DefY
				TCSAlign_U(dtb, soc) = DefU
			EndIf
		Next
	Next
	
	String AlignmentFile$
	AlignmentFile$ = RTS_DATA$ + "\VisionMeasurements\TargetAlignments.csv"
	Integer FileNum
	FileNum = FreeFile

	WOpen AlignmentFile$ As #FileNum
	Print "Setting target alignments:"
	Integer i, j
	For i = 1 To 2
		For j = 1 To nSoc
			Print i, ",", j, ",", TCSAlign_X(i, j), ",", TCSAlign_Y(i, j), ",", TCSAlign_U(i, j)
			Print #FileNum, i, ",", j, ",", TCSAlign_X(i, j), ",", TCSAlign_Y(i, j), ",", TCSAlign_U(i, j)
		Next j
	Next i

	Close #FileNum
	
	JumpToCamera
	
	SetTargetAlignment = True
	
Fend
	

Function GetTargetAlignments As Boolean
	''' Loads the desired chip-socket alignment values from the file
	' Must be measured by command through server.
	' Measure with SetTargetAlignments(DAT, Socket) when chip tests pass
	
	GetTargetAlignments = False
	
	String AlignmentFile$
	AlignmentFile$ = RTS_DATA$ + "\VisionMeasurements\TargetAlignments.csv"
	Integer FileNum
	FileNum = FreeFile
	If Not FileExists(AlignmentFile$) Then
		Print "Target alignment file could not be found at ", AlignmentFile$
		Exit Function
	EndIf
	
	ROpen AlignmentFile$ As #FileNum
	Integer i, j, ii, jj
	Double x, y, u
	'	nSoc = 8 Global var from site file , need to set for testing 
	For i = 1 To 2
		For j = 1 To nSoc
			Input #FileNum, ii, jj, x, y, u
			' Print ii, ",", jj, ",", x, ",", y, ",", u
			If ii = i And jj = j Then
				TCSAlign_X(i, j) = x
				TCSAlign_Y(i, j) = y
				TCSAlign_U(i, j) = u
				' Print "DAT ", i, " socket", j, ", DelXYU = (", x, ",", y, ",", u, ")"
			Else
				Print "GetTargetAlignment: Error reading file ", AlignmentFile$, " i,j=", i, ",", j
				Exit Function
			EndIf
		Next j
	Next i

	Close #FileNum

	GetTargetAlignments = True
	
Fend
	
Function LogChipSocketAlignment(DAT As Integer, Socket As Integer)
	''' Logs the measured CS alignment at a given time, not operation!
	' Want to associate last measurement to log, may be multiple measurements per op.
	
	Int32 FileNum
	fileNum = FreeFile
	String SocketFile$
	SocketFile$ = RTS_DATA$ + "\SocketPlacement\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_Alignment.csv"

	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")

	Print "Saving alignment information to ", SocketFile$
	String LineInfo$
	' Check if file exists, if not, create it with headers
	If Not FileExists(SocketFile$) Then
		LineInfo$ = "Time,DeltaX,DeltaY,DeltaU,InitCheckOK,WarmTestOK,ColdTestOK"
	EndIf
	
	AOpen SocketFile$ As #fileNum
	
	If LineInfo$ = "Time,DeltaX,DeltaY,DeltaU,InitCheckOK,WarmTestOK,ColdTestOK" Then
		' Write headers if new file
		Print #fileNum, LineInfo$
	EndIf
	LineInfo$ = ts$ + "," + Str$(CSAlign(4)) + "," + Str$(CSAlign(5)) + "," + Str$(CSAlign(3)) + ",Untested,Untested,Untested"
	
	Print #fileNum, LineInfo$

	Close #fileNum
	Print "Socket alignmenr logged"
	
Fend
	

Function LogUFOffsets(Tray As Integer, TrayCol As Integer, TrayRow As Integer, DAT As Integer, Socket As Integer, OpID$ As String)
''' In one file store the current offset along with the tray/socket position and the timestamp

	If (Tray <> 0 Or TrayCol <> 0 Or TrayRow <> 0) And (DAT <> 0 Or Socket <> 0) Then
		Print "Invalid indices"
		Exit Function
	EndIf
	
	Int32 fileNum
	fileNum = FreeFile
	String OffsetFile$
	
	If Tray <> 0 Then
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Tray_" + Str$(Tray) + "_" + Str$(TrayCol) + "_" + Str$(TrayRow) + "_UF_Measurements.csv"
	Else
		OffsetFile$ = RTS_DATA$ + "\VisionMeasurements\Socket_" + Str$(DAT) + "_" + Str$(Socket) + "_UF_Measurements.csv"
	EndIf
	
	String headers$
	
	If Not FileExists(OffsetFile$) Then
		headers$ = "Operation,OffX,OffY,OffU"
	EndIf
	
	AOpen OffsetFile$ As #fileNum
	
	If headers$ <> "" Then
		' Write headers to file
		Print #fileNum, headers$
	EndIf
		
	Print "Operation is ", OpID$
	Print "OffX = ", CorrectedChipOffset(1)
	Print "OffY = ", CorrectedChipOffset(2)
	Print "OffU = ", CorrectedChipOffset(3)
	Print #fileNum, OpID$, ",", CorrectedChipOffset(1), ",", CorrectedChipOffset(2), ",", CorrectedChipOffset(3)
			

	Close #fileNum

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
'			' For testing
'			If idx > 16 Then
'				Exit For
'			EndIf
			
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
	If Not close_msg$ = "" Then
		Print "[MLOG]:", close_msg$
		Print #mlog_nr, ",", close_msg$
	Else
		Print #mlog_nr, " " ' Still need to close the file by adding a space and end line character 
		' not actually sure if it needs to be a space, might do as "" is an empty string
	EndIf
	Close #mlog_nr
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
		idx_msg$ = idx_msg$ + "," + Str$(bnl_idx(i))
	Next
	WriteMLog(idx_msg$)
Fend

