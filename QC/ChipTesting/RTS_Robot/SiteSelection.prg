#include "SiteSelection.inc"
#include "RTS_tools.inc"

Function SelectSite
'	Select SiteFile$
'		Case ""
'			Print "Using predefined site file:"
'		Default
'			SITE_FILE = SiteFile$
'			Print "Using new site file:"
'	Send
'	String TheSiteFile$
'	TheSiteFile$ = SITE_FILE
'	Print TheSiteFile$
	Print "Using site file ", SITE_FILE

	If Not FileExists(SITE_FILE) Then
		Print "Need to provide full path to site.csv location"
	EndIf
	
	Integer fileNum
	
	fileNum = FreeFile
	ROpen SITE_FILE As #fileNum
	Input #fileNum, SITE$, CHIPTYPE$, REPO_DIR$, PROJ_DIR$, RTS_DATA$, HAND_U0, DF_CAM_X_OFF_U0, DF_CAM_Y_OFF_U0, DF_CAM_FOCUS
	Close #fileNum
	
	DF_CAM_Z_OFF = DF_CAM_FOCUS - CONTACT_DIST
	
	Print "Site selected is " + SITE$
	Print "Chip type to be tested is " + CHIPTYPE$

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
	
	'JW This probably doesn't need to cause it to crash, maybe create the directory with mkdir?
'	If Not FolderExists(RTS_DATA$) Then
'		Print "WARNING: RTS_DATA$ does not exist, creating it at"
'		Print RTS_DATA$
'		MkDir RTS_DATA$
'	EndIf
'
'	If Not FolderExists(RTS_DATA$) Then
'  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
'  		Exit Function
'	EndIf

	
	If (HAND_U0 * HAND_U0 + DF_CAM_X_OFF_U0 * DF_CAM_X_OFF_U0 + DF_CAM_Y_OFF_U0 * DF_CAM_Y_OFF_U0 + DF_CAM_FOCUS * DF_CAM_FOCUS) < 1. Then
		Print "WARNING: DF CAMERA OFFSETS NEED SETTING"
	EndIf
	Print "Offsets:"
	Print "  HAND_U0          = ", HAND_U0
	Print "  DF_CAM_X_OFF_U0  = ", DF_CAM_X_OFF_U0
	Print "  DF_CAM_Y_OFF_U0  = ", DF_CAM_Y_OFF_U0
	Print "  DF_CAM_Z_OFF     = ", DF_CAM_Z_OFF
	Print "  DF_CAM_FOCUS     = ", DF_CAM_FOCUS

	' Define tray layout by chip type. Note, the full arays are of fixed maximum size TRAY_NCOLS * TRAY_NROWS
	' But if we do any actual chip pick and place we need to know how many chips there actually are
	' TODO Maybe move the pallet definition here since this is called at the start of main.
	Select CHIPTYPE$
		Case "LArASIC"
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = N_LARASIC_SOC
		Case "ColdADC"
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = N_ColdADC_SOC
		Case "COLDATA"
			trayNCols = TRAY_NCOLS_L
			trayNRows = TRAY_NROWS_L
			nSoc = N_COLDATA_SOC
		Case "MSUTEST"
			trayNCols = TRAY_NCOLS_S
			trayNRows = TRAY_NROWS_S
			nSoc = NSOCKETS
		Default
			Print "ERROR Unrecognised chip type, cannot set tray layout"
		Exit Function
	Send

Fend

Function SetSiteValues()
	OnErr GoTo eHandler
	' Function to create and write values of camera offsets and chip type etc to file
	' Requires Points PScrewDFLeft and PScrewDFRight to be defined in site points file
	
'	If Not FolderExists(REPO_DIR) Then
'		Print "ERROR: REPO_DIR is does not exist and must not be correctly set"
'		Print "This should be the repo level directory in which the robot project directory lives, or some top level directory in which the site.sv file lives"
'	EndIf

	Integer fileNum
'	String SITE_FILE
'	SITE_FILE = PROJ_DIR + "\site.csv"
	
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
		
	
	fileNum = FreeFile
	WOpen SITE_FILE As #fileNum
	Print #fileNum, SITE$, ",", CHIPTYPE$, ",", REPO_DIR$, ",", PROJ_DIR$, ",", RTS_DATA$, ",", U0, ",", DeltaX, ",", DeltaY, ",", DeltaZ
	Close #fileNum
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


