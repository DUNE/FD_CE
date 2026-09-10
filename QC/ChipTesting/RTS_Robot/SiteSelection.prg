#include "SiteSelection.inc"
#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function SelectSite(OPTION$ As String) As Boolean
	'Print "SelectSite(", OPTION$, ")"
	Boolean Verbose, DefPallets
	
	Select OPTION$
		Case "InFunctionDefinePallets"
		'	Print "Will be quiet and define pallets"
			Verbose = False
			DefPallets = True
		Case "InFunction"
		'	Print "Will be quiet and not define pallets"
			Verbose = False
			DefPallets = False
		Case "DefinePallets"
		'	Print "Will be verbose and define pallets"
			Verbose = True
			DefPallets = True
		Default
			''' This is the standard version which should be called in Main/Testing
			''' Does not require pallet points to be predefined
			''' WIll be somewhat verbose
'			Print "Will be verbose, and not define pallets"
			Verbose = True
			DefPallets = False
	Send
'	
	If (OPTION$ <> "") And SITE$ <> "" And (DF_CAM_FOCUS * DF_CAM_FOCUS) > 5. Then
		' If everything is already defined don't need to run again	
'		Print "AlreadyDefined"
		SelectSite = True
		Exit Function
	Else
		Print "Site offsets not defined yet, running selectsite"
	EndIf
	
	
	SelectSite = False
	
	If Verbose Then
		Print "Using site file ", SITE_FILE
	EndIf
'	
'
'	' Set up directions of chips and sockets
'	 DefineDirections
''
	If Not ReadSiteFile Then
		Print "Could not read site file"
		Exit Function
	EndIf
	
	If Not NotStandalone Then
		SocPlaceNotDrop = DefaultPlaceNotDrop
		SocClampFirst = DefaultClampFirst
		SocFastClamp = DefaultFastClamp
	EndIf
	
	DF_CAM_Z_OFF = DF_CAM_FOCUS - CONTACT_DIST
	If Verbose Then
	Print "Site selected is " + SITE$
	Print "Chip type to be tested is " + CHIPTYPE$
	EndIf
	POINTS_FILE$ = "points_" + SITE$ + ".pts"
	LoadPoints POINTS_FILE$
	
	If Not FolderExists(REPO_DIR$) Then
		Print "ERROR: REPO_DIR does not exist at"
		Print REPO_DIR$
		Print "This should be the full path to the repo level directory in which the robot project directory lives, or some top level directory in which the site.sv file lives"
		Exit Function
	EndIf
	
	If Not FolderExists(PROJ_DIR$) Then
		Print "ERROR: PROJ_DIR$ does not exist at "
		Print PROJ_DIR$
		Print "This should be the full path to the project level directory called RTS_Robot in which the robot code lives"
		Exit Function
	EndIf
	
	If (HAND_U0 * HAND_U0 + DF_CAM_X_OFF_U0 * DF_CAM_X_OFF_U0 + DF_CAM_Y_OFF_U0 * DF_CAM_Y_OFF_U0 + DF_CAM_FOCUS * DF_CAM_FOCUS) < 1. Then
		Print "WARNING: DF CAMERA OFFSETS NEED SETTING"
	EndIf
	If Verbose Then
		Print "Offsets:"
		Print "  HAND_U0          = ", HAND_U0
		Print "  DF_CAM_X_OFF_U0  = ", DF_CAM_X_OFF_U0
		Print "  DF_CAM_Y_OFF_U0  = ", DF_CAM_Y_OFF_U0
		Print "  DF_CAM_Z_OFF     = ", DF_CAM_Z_OFF
		Print "  DF_CAM_FOCUS     = ", DF_CAM_FOCUS
	EndIf
	
	' Define tray layout by chip type. Note, the full arays are of fixed maximum size TRAY_NCOLS * TRAY_NROWS
	' But if we do any actual chip pick and place we need to know how many chips there actually are
	' TODO Maybe move the pallet definition here since this is called at the start of main.
	Select CHIPTYPE$
		Case "LArASIC"
			CHIPTYPE_NR = 1
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = N_LARASIC_SOC
		Case "ColdADC"
			CHIPTYPE_NR = 2
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = N_ColdADC_SOC
		Case "COLDATA"
			CHIPTYPE_NR = 3
			trayNCols = TRAY_NCOLS_L
			trayNRows = TRAY_NROWS_L
			nSoc = N_COLDATA_SOC
		Case "MSUTEST"
			CHIPTYPE_NR = 1
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = NSOCKETS
		Default
			Print "ERROR Unrecognised chip type, cannot set tray layout"
		Exit Function
	Send
	
	If DefPallets Then
		' left tray
		Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows
	
		' right tray
		Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows
	EndIf
	
    LoadPositionFiles
    LoadCurrentChipOffset
	
	SelectSite = True

Fend

Function SetSiteValues
	OnErr GoTo eHandler
	' Function to create and write values of camera offsets and chip type etc to file
	' Requires Points PScrewDFLeft and PScrewDFRight to be defined in site points file
	
'	If Not FolderExists(REPO_DIR) Then
'		Print "ERROR: REPO_DIR is does not exist and must not be correctly set"
'		Print "This should be the repo level directory in which the robot project directory lives, or some top level directory in which the site.sv file lives"
'	EndIf
	
	' First load site values?
	SelectSite("")
	
	POINTS_FILE$ = "points_" + SITE$ + ".pts"
	If Not FileExists(PROJ_DIR$ + "\" + POINTS_FILE$) Then
		Print "ERROR: Points file does not exist in directory at"
		Print PROJ_DIR$, "\", POINTS_FILE$
		Exit Function
	EndIf
	
	LoadPoints POINTS_FILE$
	' JW Need some error handling here
	
	' After teaching
	' PScrewDFLeft: Camera over screw in between chip trays, Camera toward Left tray
	' PScrewDFRight: Camera toward right tray (from robot's perspective)
	' Using the DF_TrayScrew vision sequence as a template to help align the camera
	' This function will calculate any offset between the center of the image and the
	' axis of rotation of J4 (The U or EOAT direction)
	' It will then try to move the EOAT to be in contact with the screw and provide the
	' camera focus offset in Z.
	' Offsets are defined as the (signed) distance between the stinger contact and the camera
	' The XOffset and YOffset functions will then rotate these appropriately for a given U value

	Double DeltaX, DeltaY, DeltaZ, U0
	DeltaX = (CX(PScrewDFLeft) - CX(PScrewDFRight)) / 2
	DeltaY = (CY(PScrewDFLeft) - CY(PScrewDFRight)) / 2
	U0 = CU(PScrewDFLeft)
	Print "Go to your site case in SiteSelection.prg"
	Print "Set HAND_U0 to ", U0
	
	Print "Set DF_CAM_X_OFF_U0 to ", DeltaX
	Print "Set DF_CAM_Y_OFF_U0 to ", DeltaY
	
	Jump PScrewDFLeft -X(DeltaX) -Y(DeltaY) LimZ -10
	Accel 1, 1
	Speed 1
	Go Here -Z(60) Till Sw(8) = On Or Sw(9) = Off
	If Sw(8) = Off Then
		Print "Error: Should have made contact"
		Exit Function
	EndIf
	' Store the focal distance, from which the Z offset is defined by suntracting contact offset)
	DeltaZ = (CZ(PScrewDFLeft) - CZ(Here))
	Move Here +Z(10)
	Print "Check if stinger is in contact with screw, if O.K. "
	Print "Set DF_CAM_FOCUS to ", DeltaZ
 	Print "Set DF_CAM_Z_OFF to ", DeltaZ - CONTACT_DIST
	SetSpeed
		
	If Not WriteSiteFile Then
		Print "Could not write to file"
		Exit Function
	EndIf
	
	Exit Function
	eHandler:
	Byte errorTask
	errorTask = Ert
	Print "An error has occured in SetSiteValues trying to calculate or set the offsets at line ", Erl, ". Error code :", Err
	Print "Error message: ", ErrMsg$(Err)
	Print "Check repo exists at "
	Print REPO_DIR$
	Print "Check points file exists at"
	Print REPO_DIR$ + "\RTS_Robot\" + POINTS_FILE$
	Print "Check PScrewDFLeft and PScrewDFRight are defined"
	If Era(errorTask) > 0 Then
		Print "Error with joint ", Era(errorTask)
	EndIf
Fend

Function MeasureSocketVisionOffset(DAT_nr As Integer, Socket_nr As Integer) As Int32
	 MeasureSocketVisionOffset = 0
	' This is to set the SocketVisionOffset(3) variables.	
	' These account for differences between the socket vision sequence measurement and the actual point,
	' Should be run once, must be run when aligned with socket (DAT_nr, Socket_nr)
	
	If Not ReadSiteFile Then
		Print "Could not read site file"
		Exit Function
	EndIf
'		
	' After aligning your sockets and teaching their points, realign the socket in the "socket align" vision sequence.
	SocketVisionOffset(1) = 0.
	SocketVisionOffset(2) = 0.
	SocketVisionOffset(3) = 0.
	
	' Now run the socket vision sequence and see how far off the taught point it is
	' Remember, if you have taught the point correctly, and the camera vision offsets are measured
	' the vision sequence should be fairly close to the actual point
	
	
	If Not GetSocketPositionWithDF(DAT_nr, Socket_nr) Then ', ByRef SockCorr()) Then
		'RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN)
		MeasureSocketVisionOffset = -ERR_V_SOCKETALIGN
		Exit Function
	EndIf
	
	If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
		MeasureSocketVisionOffset = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	Print "Correcting for socket (", DAT_nr, ",", Socket_nr, ") drift : (", SocketOffset(1), ",", SocketOffset(2), ",", SocketOffset(3), ")"
	Print "With zeroed out vision corrections, socket offstes are returned as "
	Print " X:", SocketOffset(1)
	Print " Y:", SocketOffset(2)
	Print " U:", SocketOffset(3)
	Print "Setting SocketVisionOffset to these values to prevent overcorrection in socket drift"
	SocketVisionOffset(1) = SocketOffset(1)
	SocketVisionOffset(2) = SocketOffset(2)
	SocketVisionOffset(3) = SocketOffset(3)
	Print "SocketVisionOffset values saved, storing in site file", SITE_FILE

	If Not WriteSiteFile Then
		Print "Could not write to file"
		Exit Function
	EndIf

	MeasureSocketVisionOffset = -1
	 
Fend

Function MeasureChipVisionOffset As Int32
	MeasureChipVisionOffset = 0
	' This is to set the ChipVisionOffset(3) variables.	
	' These account for differences between the chip vision sequence measurement and the actual point,
	' Should be run once.
	
	If Not ReadSiteFile Then
		Print "Could not read site file"
		Exit Function
	EndIf
'		
'	Align a chip so it is as square on in the center of the camera image as possible
'	Remember, the chips may be slightly out of position from a tray. Line this up manually
'	We will set these offsets for fine tuning the vision sequence functions
	ChipVisionOffset(1) = 0.
	ChipVisionOffset(2) = 0.
	ChipVisionOffset(3) = 0.
'	
'	' Now run the chip vision sequence and see how far off the point is from the
'   ' value calculated from the camera point offsets
'	' Remember, if you have taught the point correctly, and the camera vision offsets are measured
'	' the vision sequence should be fairly close to the actual point
'	

'	NAttempts = 5
	If Not FindChipPositionWithDF Then
		Print "Could not find/measure chip position"
		MeasureChipVisionOffset = -ERR_V_DF_ALIGN
		Exit Function
	EndIf
'	
	Double PointX, PointY, PointZ, DelX, DelY, DelU
	PointX = CX(Here) - XOffset(CU(Here))
	PointY = CY(Here) - YOffset(CU(Here))
	PointZ = CZ(Here) - DF_CAM_Z_OFF
	DelX = ChipPos(1) - PointX
	DelY = ChipPos(2) - PointY
	DelU = GetBoundAnglePM45(DiffAnglePM180(CU(Here), ChipPos(3)))

	Print "Current position of hand "
	Print Here
	Print " Implies point relative to current image at "
	Print "XYZU: (", PointX, ",", PointY, ",", PointZ, ",", CU(Here), ")"
	Print "Chip position measured to be (without correction) "
	Print "XYU(", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	Print " With difference of "
	Print "XYU(", DelX, ",", DelY, ",", DelU, ")"
		
	If Abs(DelX) > 1. Or Abs(DelY) > 1. Or Abs(DelU) > 3. Then
		Print "Offsets too large, try again or increase tolerance"
		MeasureChipVisionOffset = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	
	ChipVisionOffset(1) = DelX
	ChipVisionOffset(2) = DelY
	ChipVisionOffset(3) = DelU
	
	Print "Saving new offsets to file"
	
	If Not WriteSiteFile Then
		Print "Could not write to file"
		Exit Function
	EndIf
	
	MeasureChipVisionOffset = -1
Fend

Function ReadSiteFileOld
	ReadSiteFileOld = 0
	' First make sure you have all the other site specific values loaded	
	If Not FileExists(SITE_FILE) Then
		Print "Need to provide full path to site.csv location"
		ReadSiteFileOld = -999
	EndIf

	Integer fileNum
	fileNum = FreeFile
	ROpen SITE_FILE As #fileNum
	Input #fileNum, SITE$, CHIPTYPE$
	Input #fileNum, REPO_DIR$
	Input #fileNum, PROJ_DIR$
	Input #fileNum, RTS_DATA$
	Input #fileNum, HAND_U0, DF_CAM_X_OFF_U0, DF_CAM_Y_OFF_U0, DF_CAM_FOCUS
	Input #fileNum, TrayOrientation, HandChipOrientation(1), HandChipOrientation(2), HandChipOrientation(3)
	Input #fileNum, ChipTextOrientation, ChipVisionOffset(1), ChipVisionOffset(2), ChipVisionOffset(3)
	Input #fileNum, SocketVisionOffset(1), SocketVisionOffset(2), SocketVisionOffset(3)
	Input #fileNum, NAttempts_Chip_Tray, NAttempts_Chip_DAT, NAttempts_Soc, NAttempts_UF
	Input #fileNum, Default_DF_Exposure_Chip
	Input #fileNum, Min_DF_Exposure_Chip_Tray, Max_DF_Exposure_Chip_Tray
	Input #fileNum, Min_DF_Exposure_Chip_DAT, Max_DF_Exposure_Chip_DAT
	Input #fileNum, Default_DF_Exposure_Soc
	Input #fileNum, Min_DF_Exposure_Soc, Max_DF_Exposure_Soc
	Input #fileNum, Default_UF_Exposure
	Input #fileNum, Min_UF_Exposure, Max_UF_Exposure
	Input #fileNum, DefaultPinAnalysis, DefaultSkipOcc, DefaultSkipSocCor, DefaultSkipChipCor
	Input #fileNum, DefaultPlaceNotDrop, DefaultClampFirst, DefaultFastClamp
	Close #fileNum
	ReadSiteFileOld = -9
Fend

Function WriteSiteFileOld
	WriteSiteFileOld = 0
	If SITE_FILE = "" Then
		Print("No site file defined in SiteSelection.inc ")
		WriteSiteFileOld = -999
		Return
	EndIf
	
	Integer fileNum
	fileNum = FreeFile
	WOpen SITE_FILE As #fileNum
	Print #fileNum, SITE$, ",", CHIPTYPE$
	Print #fileNum, REPO_DIR$
	Print #fileNum, PROJ_DIR$
	Print #fileNum, RTS_DATA$
	Print #fileNum, Str$(HAND_U0), ",", Str$(DF_CAM_X_OFF_U0), ",", Str$(DF_CAM_Y_OFF_U0), ",", Str$(DF_CAM_FOCUS)
	Print #fileNum, Str$(TrayOrientation), ",", Str$(HandChipOrientation(1)), ",", Str$(HandChipOrientation(2)), ",", Str$(HandChipOrientation(3))
	Print #fileNum, Str$(ChipTextOrientation), ",", Str$(ChipVisionOffset(1)), ",", Str$(ChipVisionOffset(2)), ",", Str$(ChipVisionOffset(3))
	Print #fileNum, Str$(SocketVisionOffset(1)), ",", Str$(SocketVisionOffset(2)), ",", Str$(SocketVisionOffset(3))
	Print #fileNum, Str$(NAttempts_Chip_Tray), ",", Str$(NAttempts_Chip_DAT), ",", Str$(NAttempts_Soc), ",", Str$(NAttempts_UF)
	Print #fileNum, Str$(Default_DF_Exposure_Chip)
	Print #fileNum, Str$(Min_DF_Exposure_Chip_Tray), ",", Str$(Max_DF_Exposure_Chip_Tray)
	Print #fileNum, Str$(Min_DF_Exposure_Chip_DAT), ",", Str$(Max_DF_Exposure_Chip_DAT)
	Print #fileNum, Str$(Default_DF_Exposure_Soc)
	Print #fileNum, Str$(Min_DF_Exposure_Soc), ",", Str$(Max_DF_Exposure_Soc)
	Print #fileNum, Str$(Default_UF_Exposure)
	Print #fileNum, Str$(Min_UF_Exposure), ",", Str$(Max_UF_Exposure)
	Print #fileNum, Str$(-Int(DefaultPinAnalysis)), ",", Str$(-Int(DefaultSkipOcc)), ",", Str$(-Int(DefaultSkipSocCor)), ",", Str$(-Int(DefaultSkipChipCor))
	Print #fileNum, Str$(-Int(DefaultPlaceNotDrop)), ",", Str$(-Int(DefaultClampFirst)), ",", Str$(-Int(DefaultFastClamp))
	Close #fileNum
	WriteSiteFileOld = -1
	
Fend


Function ReadSiteFile As Int32
	ReadSiteFile = 0
	' First make sure you have all the other site specific values loaded	
	If Not FileExists(SITE_FILE) Then
		Print "Need to provide full path to site.csv location"
		ReadSiteFile = -999
		Return
	EndIf

	Integer fileNum
	fileNum = FreeFile
	ROpen SITE_FILE As #fileNum
	Int32 file_line, NfileLines
	NfileLines = 42
	String VariableName$, VariableValue$

	' First five values are strings
	For file_line = 1 To NfileLines
		Input #fileNum, VariableName$, VariableValue$
		Select VariableName$
			Case "Site"
				SITE$ = VariableValue$
			Case "Chip"
				CHIPTYPE$ = VariableValue$
			Case "Repo"
				REPO_DIR$ = VariableValue$
			Case "Proj"
				PROJ_DIR$ = VariableValue$
			Case "Data"
				RTS_DATA$ = VariableValue$
			Case "HAND_U0"
				HAND_U0 = Val(VariableValue$)
			Case "DF_CAM_X_OFF_U0"
				DF_CAM_X_OFF_U0 = Val(VariableValue$)
			Case "DF_CAM_Y_OFF_U0"
				DF_CAM_Y_OFF_U0 = Val(VariableValue$)
			Case "DF_CAM_FOCUS"
				DF_CAM_FOCUS = Val(VariableValue$)
			Case "TrayOrientation"
				TrayOrientation = Val(VariableValue$)
				
			Case "HandChipOrientation_LArASIC"
				HandChipOrientation(1) = Val(VariableValue$)
			Case "HandChipOrientation_ColdADC"
				HandChipOrientation(2) = Val(VariableValue$)
			Case "HandChipOrientation_COLDATA"
				HandChipOrientation(3) = Val(VariableValue$)
			Case "ChipTextOrientation"
				ChipTextOrientation = Val(VariableValue$)
			Case "ChipVisionOffsetX"
				ChipVisionOffset(1) = Val(VariableValue$)
			Case "ChipVisionOffsetY"
				ChipVisionOffset(2) = Val(VariableValue$)
			Case "ChipVisionOffsetU"
				ChipVisionOffset(3) = Val(VariableValue$)
			Case "SocketVisionOffsetX"
				SocketVisionOffset(1) = Val(VariableValue$)
			Case "SocketVisionOffsetY"
				SocketVisionOffset(2) = Val(VariableValue$)
			Case "SocketVisionOffsetU"
				SocketVisionOffset(3) = Val(VariableValue$)
				
			Case "NAttempts_Chip_Tray"
				NAttempts_Chip_Tray = Val(VariableValue$)
			Case "NAttempts_Chip_DAT"
				NAttempts_Chip_DAT = Val(VariableValue$)
			Case "NAttempts_Soc"
				NAttempts_Soc = Val(VariableValue$)
			Case "NAttempts_UF"
				NAttempts_UF = Val(VariableValue$)
			Case "Default_DF_Exposure_Chip"
				Default_DF_Exposure_Chip = Val(VariableValue$)
			Case "Min_DF_Exposure_Chip_Tray"
				Min_DF_Exposure_Chip_Tray = Val(VariableValue$)
			Case "Max_DF_Exposure_Chip_Tray"
				Max_DF_Exposure_Chip_Tray = Val(VariableValue$)
			Case "Min_DF_Exposure_Chip_DAT"
				Min_DF_Exposure_Chip_DAT = Val(VariableValue$)
			Case "Max_DF_Exposure_Chip_DAT"
				Max_DF_Exposure_Chip_DAT = Val(VariableValue$)
			Case "Default_DF_Exposure_Soc"
				Default_DF_Exposure_Soc = Val(VariableValue$)
				
			Case "Min_DF_Exposure_Soc"
				Min_DF_Exposure_Soc = Val(VariableValue$)
			Case "Max_DF_Exposure_Soc"
				Max_DF_Exposure_Soc = Val(VariableValue$)
			Case "Default_UF_Exposure"
				Default_UF_Exposure = Val(VariableValue$)
			Case "Min_UF_Exposure"
				Min_UF_Exposure = Val(VariableValue$)
			Case "Max_UF_Exposure"
				Max_UF_Exposure = Val(VariableValue$)
			Case "DoPinAnalysis"
				DefaultPinAnalysis = Val(VariableValue$)
			Case "SkipOccupancyCheck"
				DefaultSkipOcc = Val(VariableValue$)
			Case "SkipSocketCorrection"
				DefaultSkipSocCor = Val(VariableValue$)
			Case "SkipChiptoChipCorrection"
				DefaultSkipChipCor = Val(VariableValue$)
			Case "PlaceNotDrop"
				DefaultPlaceNotDrop = Val(VariableValue$)
				
			Case "ClampBeforeVacuumOff"
				DefaultClampFirst = Val(VariableValue$)
			Case "FastClamp"
				DefaultFastClamp = Val(VariableValue$)
			Default
				Print "NO KNOWN VARIABLE TO SET FOR SITE FILE VARIABLE ", VariableName$
		Send
	Next

	Close #fileNum
	ReadSiteFile = -1
Fend

Function WriteSiteFile As Int32
	WriteSiteFile = 0
	If SITE_FILE = "" Then
		Print("No site file defined in SiteSelection.inc ")
		WriteSiteFile = -999
		Return
	EndIf

	Integer fileNum
	fileNum = FreeFile
	WOpen SITE_FILE As #fileNum
	Print #fileNum, "Site,", SITE$
	Print #fileNum, "Chip,", CHIPTYPE$
	Print #fileNum, "Repo,", REPO_DIR$
	Print #fileNum, "Proj,", PROJ_DIR$
	Print #fileNum, "Data,", RTS_DATA$
	Print #fileNum, "HAND_U0,", Str$(HAND_U0)
	Print #fileNum, "DF_CAM_X_OFF_U0,", Str$(DF_CAM_X_OFF_U0)
	Print #fileNum, "DF_CAM_Y_OFF_U0,", Str$(DF_CAM_Y_OFF_U0)
	Print #fileNum, "DF_CAM_FOCUS,", Str$(DF_CAM_FOCUS)
	Print #fileNum, "TrayOrientation,", Str$(TrayOrientation)
	Print #fileNum, "HandChipOrientation_LArASIC,", Str$(HandChipOrientation(1))
	Print #fileNum, "HandChipOrientation_ColdADC,", Str$(HandChipOrientation(2))
	Print #fileNum, "HandChipOrientation_COLDATA,", Str$(HandChipOrientation(3))
	Print #fileNum, "ChipTextOrientation,", Str$(ChipTextOrientation)
	Print #fileNum, "ChipVisionOffsetX,", Str$(ChipVisionOffset(1))
	Print #fileNum, "ChipVisionOffsetY,", Str$(ChipVisionOffset(2))
	Print #fileNum, "ChipVisionOffsetU,", Str$(ChipVisionOffset(3))
	Print #fileNum, "SocketVisionOffsetX,", Str$(SocketVisionOffset(1))
	Print #fileNum, "SocketVisionOffsetY,", Str$(SocketVisionOffset(2))
	Print #fileNum, "SocketVisionOffsetU,", Str$(SocketVisionOffset(3))
	Print #fileNum, "NAttempts_Chip_Tray,", Str$(NAttempts_Chip_Tray)
	Print #fileNum, "NAttempts_Chip_DAT,", Str$(NAttempts_Chip_DAT)
	Print #fileNum, "NAttempts_Soc,", Str$(NAttempts_Soc)
	Print #fileNum, "NAttempts_UF,", Str$(NAttempts_UF)
	Print #fileNum, "Default_DF_Exposure_Chip,", Str$(Default_DF_Exposure_Chip)
	Print #fileNum, "Min_DF_Exposure_Chip_Tray,", Str$(Min_DF_Exposure_Chip_Tray)
	Print #fileNum, "Max_DF_Exposure_Chip_Tray,", Str$(Max_DF_Exposure_Chip_Tray)
	Print #fileNum, "Min_DF_Exposure_Chip_DAT,", Str$(Min_DF_Exposure_Chip_DAT)
    Print #fileNum, "Max_DF_Exposure_Chip_DAT,", Str$(Max_DF_Exposure_Chip_DAT)
    Print #fileNum, "Default_DF_Exposure_Soc,", Str$(Default_DF_Exposure_Soc)
    Print #fileNum, "Min_DF_Exposure_Soc,", Str$(Min_DF_Exposure_Soc)
	Print #fileNum, "Max_DF_Exposure_Soc,", Str$(Max_DF_Exposure_Soc)
	Print #fileNum, "Default_UF_Exposure,", Str$(Default_UF_Exposure)
	Print #fileNum, "Min_UF_Exposure,", Str$(Min_UF_Exposure)
	Print #fileNum, "Max_UF_Exposure,", Str$(Max_UF_Exposure)
    Print #fileNum, "DoPinAnalysis,", Str$(-Int(DefaultPinAnalysis)) ' Convert true bool (True = -1) to 1 for user
    Print #fileNum, "SkipOccupancyCheck,", Str$(-Int(DefaultSkipOcc))
	Print #fileNum, "SkipSocketCorrection,", Str$(-Int(DefaultSkipSocCor))
	Print #fileNum, "SkipChiptoChipCorrection,", Str$(-Int(DefaultSkipChipCor))
	Print #fileNum, "PlaceNotDrop,", Str$(-Int(DefaultPlaceNotDrop))
	Print #fileNum, "ClampBeforeVacuumOff,", Str$(-Int(DefaultClampFirst))
	Print #fileNum, "FastClamp,", Str$(-Int(DefaultFastClamp))
	Close #fileNum
	
	WriteSiteFile = -1
	
Fend

Function PrintLoadedSiteFileValues
	Print "Current global setting variables from site file"
	Print "Site,", SITE$
	Print "Chip,", CHIPTYPE$
	Print "Repo,", REPO_DIR$
	Print "Proj,", PROJ_DIR$
	Print "Data,", RTS_DATA$
	Print "HAND_U0,", Str$(HAND_U0)
	Print "DF_CAM_X_OFF_U0,", Str$(DF_CAM_X_OFF_U0)
	Print "DF_CAM_Y_OFF_U0,", Str$(DF_CAM_Y_OFF_U0)
	Print "DF_CAM_FOCUS,", Str$(DF_CAM_FOCUS)
	Print "TrayOrientation,", Str$(TrayOrientation)
	Print "HandChipOrientation_LArASIC,", Str$(HandChipOrientation(1))
	Print "HandChipOrientation_ColdADC,", Str$(HandChipOrientation(2))
	Print "HandChipOrientation_COLDATA,", Str$(HandChipOrientation(3))
	Print "ChipTextOrientation,", Str$(ChipTextOrientation)
	Print "ChipVisionOffsetX,", Str$(ChipVisionOffset(1))
	Print "ChipVisionOffsetY,", Str$(ChipVisionOffset(2))
	Print "ChipVisionOffsetU,", Str$(ChipVisionOffset(3))
	Print "SocketVisionOffsetX,", Str$(SocketVisionOffset(1))
	Print "SocketVisionOffsetY,", Str$(SocketVisionOffset(2))
	Print "SocketVisionOffsetU,", Str$(SocketVisionOffset(3))
	Print "NAttempts_Chip_Tray,", Str$(NAttempts_Chip_Tray)
	Print "NAttempts_Chip_DAT,", Str$(NAttempts_Chip_DAT)
	Print "NAttempts_Soc,", Str$(NAttempts_Soc)
	Print "NAttempts_UF,", Str$(NAttempts_UF)
	Print "Default_DF_Exposure_Chip,", Str$(Default_DF_Exposure_Chip)
	Print "Min_DF_Exposure_Chip_Tray,", Str$(Min_DF_Exposure_Chip_Tray)
	Print "Max_DF_Exposure_Chip_Tray,", Str$(Max_DF_Exposure_Chip_Tray)
	Print "Min_DF_Exposure_Chip_DAT,", Str$(Min_DF_Exposure_Chip_DAT)
    Print "Max_DF_Exposure_Chip_DAT,", Str$(Max_DF_Exposure_Chip_DAT)
    Print "Default_DF_Exposure_Soc,", Str$(Default_DF_Exposure_Soc)
    Print "Min_DF_Exposure_Soc,", Str$(Min_DF_Exposure_Soc)
	Print "Max_DF_Exposure_Soc,", Str$(Max_DF_Exposure_Soc)
	Print "Default_UF_Exposure,", Str$(Default_UF_Exposure)
	Print "Min_UF_Exposure,", Str$(Min_UF_Exposure)
	Print "Max_UF_Exposure,", Str$(Max_UF_Exposure)
    Print "DoPinAnalysis,", Str$(-Int(DefaultPinAnalysis)) ' Convert true bool (True = -1) to 1 for user
    Print "SkipOccupancyCheck,", Str$(-Int(DefaultSkipOcc))
	Print "SkipSocketCorrection,", Str$(-Int(DefaultSkipSocCor))
	Print "SkipChiptoChipCorrection,", Str$(-Int(DefaultSkipChipCor))
	Print "PlaceNotDrop,", Str$(-Int(DefaultPlaceNotDrop))
	Print "ClampBeforeVacuumOff,", Str$(-Int(DefaultClampFirst))
	Print "FastClamp,", Str$(-Int(DefaultFastClamp))

	
Fend

