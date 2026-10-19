#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

''' Runs the pin analysis code
' Note, this does not find the position, which is found by the UFGetChipAligment() function
' this checks for uniform pin position/spacing using the PinsAnaly() function
Function UFPinAnalysis(id$ As String, ByRef Images$() As String) As Int32
	UpdateRobotLog$("Running pin analysis")
	UFPinAnalysis = 0

	Images$(1) = UF_take_picture$(id$ + "_pins")
	WriteMLog(Images$(1)) ' TODO joe check if this needs to be inside a check of CurrentOpertaion$
	Integer status
	status = PinsAnaly(id$, ByRef Images$())
	' Print #fileNum, ",", status,
	WriteMLog(Str$(status)) ' TODO joe check if this needs to be inside a check of CurrentOpertaion$
	If status <> 0 Then
		UFPinAnalysis = status
	EndIf
	
	UFPinAnalysis = -1
	
Fend

''' Analyses row of pins and checks equidistant spacing for bent pins/dust
Function PinsRowAnaly(name$ As String, fileNum As Integer) As Integer
	
	PinsRowAnaly = 0
	
	Int32 NPins
	Select CHIPTYPE$
		Case "LArASIC"
		Case "ColdADC"
		Case "COLDATA"
		Print "Invalid chiptype"
		PinsRowAnaly = ERR_PINS
		Default
	Send
	
	Boolean passed
	Integer nFound, i
	Double x, y, area, xold, yold
	Select SITE$
		Case "BNL"
			VGet pins_analy.name$.Passed, passed
			If Not passed Then
				Print "PinsAnaly " + name$ + " failed!"
				Print #fileNum, " failed"
				PinsRowAnaly = 301
				Exit Function
			EndIf
		
			VGet pins_analy.name$.NumberFound, nFound
			Print #fileNum, name$, ",", nFound,
			If nFound <> 32 Then
				PinsRowAnaly = 302
			EndIf
		
			For i = 1 To nFound
				VSet pins_analy.name$.CurrentResult, i
				VGet pins_analy.name$.CameraX, x
				VGet pins_analy.name$.CameraY, y
				VGet pins_analy.name$.Area, area
				Print #fileNum, ",", x, ",", y, ",", area,
				xold = x
				yold = y
				If i > 1 And Abs(x - xold) > 0.05 Then
					Print "*ERROR! Bent pin found in " + name$
					PinsRowAnaly = 400 + i
				EndIf
			Next i
		Case "MSU"
			VGet MSU_ChipAnal.name$.Passed, passed
			If Not passed Then
				Print "PinsAnaly " + name$ + " failed!"
				Print #fileNum, " failed",
				PinsRowAnaly = 301
				Exit Function
			EndIf
			
			VGet MSU_ChipAnal.name$.NumberFound, nFound
			'Print #fileNum, name$, ",", nFound,
			If nFound <> 32 Then
				PinsRowAnaly = 302
			EndIf
		
			For i = 1 To nFound
				VSet MSU_ChipAnal.name$.CurrentResult, i
				VGet MSU_ChipAnal.name$.CameraX, x
				VGet MSU_ChipAnal.name$.CameraY, y
				VGet MSU_ChipAnal.name$.Area, area
				'Print #fileNum, ",", x, ",", y, ",", area,
				xold = x
				yold = y
				If i > 1 And Abs(x - xold) > 0.05 Then
					Print "*ERROR! Bent pin found in " + name$,
					PinsRowAnaly = 400 + i
				EndIf
			Next i
		Case "TUT"
			VGet TUT_ChipAnal.name$.Passed, passed
			If Not passed Then
				Print "PinsAnaly " + name$ + " failed!"
				Print #fileNum, " failed",
				PinsRowAnaly = 301
				Exit Function
			EndIf
			
			VGet TUT_ChipAnal.name$.NumberFound, nFound
			'Print #fileNum, name$, ",", nFound,
			If nFound <> 32 Then
				PinsRowAnaly = 302
			EndIf
		
			For i = 1 To nFound
				VSet TUT_ChipAnal.name$.CurrentResult, i
				VGet TUT_ChipAnal.name$.CameraX, x
				VGet TUT_ChipAnal.name$.CameraY, y
				VGet TUT_ChipAnal.name$.Area, area
				'Print #fileNum, ",", x, ",", y, ",", area,
				xold = x
				yold = y
				If i > 1 And Abs(x - xold) > 0.05 Then
					Print "*ERROR! Bent pin found in " + name$,
					PinsRowAnaly = 400 + i
				EndIf
			Next i
	Send
	
	'Print #fileNum, " "' Should use RTS_error in movement function which will end the line
	
Fend

''' For each side of a chip runs PinsRowAnaly to check pin spacing/dust occlusion
Function PinsAnaly(id$ As String, ByRef Images$() As String) As Integer
	
	PinsAnaly = 0
	
	Integer fileNum
	fileNum = FreeFile
	' AOpen RTS_DATA$ + "\pins\" + id$ + "_pins.csv" As #fileNum
	AOpen TrayDirectory$ + "\pins\" + id$ + "_pins.csv" As #fileNum
	
	Select SITE$
		Case "BNL"
			VSet pins_analy.ImageFile, Images$(1)
			VRun pins_analy
		Case "MSU"
			VSet MSU_ChipAnal.ImageFile, Images$(1)
			VRun MSU_ChipAnal
		Case "TUT"
			VSet TUT_ChipAnal.ImageFile, Images$(1)
			VRun TUT_ChipAnal
		Default
			Print "Need to set up pin analysis for your site"
			PinsAnaly = -100
			Close #FileNum
	Send

	Integer status
	status = PinsRowAnaly("BlobTop", FileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf
	
	status = PinsRowAnaly("BlobBottom", FileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf


	' For COLDATA will want to change image here after moving each way?
	' Something like
	' JW: I've not tested this but I think this should work, requires three images of chips
	' with UF camera
'	If CHIPTYPE$ = "COLDATA" Then
	'	Select SITE$
'		Case "FNAL"
'			VSet FNAL_ChipAnal.ImageFile, Images$(2)
'			VRun pins_analy
'		Case "MSU"
'			VSet MSU_CDAnal.ImageFile, Images$(2)
'			VRun MSU_CDAnal
'		Default
'			Print "Need to set up COLDATA pin analysis for your site"
'			PinsAnaly = -100
'			Close #fileNum
'	Send	
'	EndIf

	status = PinsRowAnaly("BlobLeft", FileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

'' And then again for the other side
'	If CHIPTYPE$ = "COLDATA" Then
	'	Select SITE$
'		Case "FNAL"
'			VSet FNAL_ChipAnal.ImageFile, Images$(3)
'			VRun pins_analy
'		Case "MSU"
'			VSet MSU_CDAnal.ImageFile, Images$32)
'			VRun MSU_CDAnal
'		Default
'			Print "Need to set up COLDATA pin analysis for your site"
'			PinsAnaly = -100
'			Close #fileNum
'	Send	
'	EndIf

	status = PinsRowAnaly("BlobRight", FileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	Close #FileNum
	
Fend


Function ThreeCornerFindDirection(isFoundTL As Boolean, xTL As Double, yTL As Double, isFoundTR As Boolean, xTR As Double, yTR As Double, isFoundBR As Boolean, xBR As Double, yBR As Double, isFoundBL As Boolean, xBL As Double, yBL As Double) As Boolean
'''' Chip and socket direction functions ''''
''' Finds the orientation of a right-angled triangle
' Note, assumes a specific orientation which must be adapted to the expected layour of of the three points passed/
' This may be different for chip/socket layout etc.

	ThreeCornerFindDirection = False
	
'	Print "ThreeCornerFind function"
'	Print "isFoundTL", isFoundTL
'	Print "isFoundTR", isFoundTR
'	Print "isFoundBR", isFoundBR
'	Print "isFoundBL", isFoundBL
	
	' For three points of a rectangle
    ' TL    TR
	'      / |
	'     /  | Side 1
	'    /   |
	'   /    |
	' BL-----BR
	' Side 2
	' Gives direction of BR -> TR
	' But uses hypotentuse for smaller error
	
	' 2025-09-19 JW: Updated to just take Side 1 for direction due to the fact not all markers are isosceles right angle 	
	' Still use diagonal average for center position
	Double AvX, AvY, AvU, DiffU
	Double DelX1, DelY1, Hyp1, SPolar1, DelX2, DelY2, Hyp2, SPolar2
	If (Not isFoundTL) And (isFoundTR And isFoundBR And isFoundBL) Then
		' Missing key is Top Left in image (UP ORIENTED)
		' Av TR and BL
		AvX = (xTR + xBL) /2
		AvY = (yTR + yBL) /2
'		DelX = xTR - xBL
'		DelY = yTR - yBL
		DelX1 = xTR - xBR
		DelY1 = yTR - yBR
		DelX2 = xBR - xBL
		DelY2 = yBR - yBL
	ElseIf (Not isFoundTR) And (isFoundBR And isFoundBL And isFoundTL) Then
		' Missing key is Top Right in image (RIGHT ORIENTED)
		' Av BR and TL
		AvX = (xBR + xTL) /2
		AvY = (yBR + yTL) /2
'		DelX = xBR - xTL
'		DelY = yBR - yTL
		DelX1 = xBR - xBL
		DelY1 = yBR - yBL
		DelX2 = xBL - xTL
		DelY2 = yBL - yTL
	ElseIf (Not isFoundBR) And (isFoundTR And isFoundBL And isFoundTL) Then
		' Missing key is Bottom Right in image (DOWN ORIENTED)
		' Av BL and TR
		AvX = (xBL + xTR) /2
		AvY = (yBL + yTR) /2
'		DelX = xBL - xTR
'		DelY = yBL - yTR
		DelX1 = xBL - xTL
		DelY1 = yBL - yTL
		DelX2 = xTL - xTR
		DelY2 = yTL - yTR
		Print "TL = (", xTL, ",", yTL, ")"
		Print "TR = (", xTR, ",", yTR, ")"
		Print "BR = (", xBR, ",", yBR, ")"
	ElseIf (Not isFoundBL) And (isFoundTR And isFoundBR And isFoundTL) Then
		' Missing key is Bottom left in image (LEFT ORIENTED)
		' Av TL and BR
		AvX = (xTL + xBR) /2
		AvY = (yTL + yBR) /2
'		DelX = xTL - xBR
'		DelY = yTL - yBR
		DelX1 = xTL - xTR
		DelY1 = yTL - yTR
		DelX2 = xTR - xBR
		DelY2 = yTR - yBR
	Else
		Print "ERROR - DID NOT PASS STRICTLY THREE POINTS"
		Print "TL: ", isFoundTL, ", TR: ", isFoundTR, ", BR: ", isFoundBR, ", BL: ", isFoundBL
		ThreeCornerFindDirection = False
		CornerVar(1) = 0
		CornerVar(2) = 0
		CornerVar(3) = 0
		Exit Function

	EndIf
	Hyp1 = Sqr((DelX1 * DelX1) + (DelY1 * DelY1))
	If DelY1 >= 0. Then
		SPolar1 = RadToDeg(Acos(DelX1 / Hyp1))
	Else
		SPolar1 = -RadToDeg(Acos(DelX1 / Hyp1))
	EndIf
	Hyp2 = Sqr((DelX2 * DelX2) + (DelY2 * DelY2))
	If DelY2 >= 0. Then
		SPolar2 = RadToDeg(Acos(DelX2 / Hyp2)) + 90.
	Else
		SPolar2 = -RadToDeg(Acos(DelX2 / Hyp2)) + 90.
	EndIf
	
	SPolar1 = GetBoundAnglePM180(SPolar1)
	SPolar2 = GetBoundAnglePM180(SPolar2)
	Print "SPolar1 = ", SPolar1
	Print "SPolar2 = ", SPolar2
	DiffU = DiffAnglePM180(SPolar1, SPolar2)
	AvU = AverageAnglePM180(SPolar1, SPolar2)
	Print " Diff   = ", DiffU ' DiffAnglePM180(SPolar1, SPolar2)
	Print " Av     = ", AvU 'AverageAnglePM180(SPolar1, SPolar2)
'	SPolar = RadToDeg(Acos(DelX / Hyp))
'	SPolar = RadToDeg(Asin(DelY / Hyp))
	
	' Since sockets should be roughly at 90 degree increments to world axis, arctan should be fine
	' SPolar = RadToDeg(Atan(DelY / DelX))
	'Print "Polar angle from bottom left mark to top left mark is ", SPolar
	CornerVar(1) = AvX
	CornerVar(2) = AvY
	CornerVar(3) = AvU 'AverageAnglePM180(SPolar1, SPolar2) ' SPolar1 '+ 45. ' 45 was frpm older methos using hypotonuse and right-isosceles triangle
	

	
	ThreeCornerFindDirection = True ' SPolar + 45.

Fend

Function FindChipDirectionWithDF As Double
''' Use DF camera to get chip orientation only
' Wraps lower level chip specifc functions
	FindChipDirectionWithDF = -999.
	
	SelectSite("InFunctionDefinePallets")
	
	If CY(Here) < (CY(P_Camera) - 20) Then
		NAttempts = NAttempts_Chip_DAT
		Min_DF_Exposure = Min_DF_Exposure_Chip_DAT
		Max_DF_Exposure = Max_DF_Exposure_Chip_DAT
	Else
		NAttempts = NAttempts_Chip_Tray
		Min_DF_Exposure = Min_DF_Exposure_Chip_Tray
		Max_DF_Exposure = Max_DF_Exposure_Chip_Tray
	EndIf
	Print "Running find chip direction with NAttempts = ", Str$(NAttempts)
	Print "Min exposure = ", Min_DF_Exposure
	Print "Max exposure = ", Max_DF_Exposure

	Integer Attempt 's, Attempt
	Attempt = NAttempts
'	Boolean Success
'	Success = False
		
	Do While (Attempt > 0) ' Or Success
			
		DF_Exposure = Min_DF_Exposure + Attempt * Int((Max_DF_Exposure - Min_DF_Exposure) / (NAttempts))
		' Print "Attempt ", Str$(NAttempts - Attempt), " with ExposureTime = ", Str$(DF_Exposure)
		
	'	Print "FindChipDirectionWithDF: Chip type ", CHIPTYPE$
		Select CHIPTYPE$
			Case "LArASIC"
				FindChipDirectionWithDF = DF_ChipDirection_LArASIC
			Case "ColdADC"
	'			FindChipDirectionWithDF = DF_ChipDirection_ColdADC
			Case "COLDATA"
	'			FindChipDirectionWithDF = DF_ChipDirection_COLDATA
			Default
				Print "Chip type not defined"
				Exit Function
		Send
	'	Print "FindChipDirectionWithDF: Direction returned by chip specific function: ", FindChipDirectionWithDF
	
		If FindChipDirectionWithDF > -900. Then
			Exit Do
		EndIf
		Attempt = Attempt - 1
	
	Loop
	
	If FindChipDirectionWithDF < -900. Then
		Print "Could not find chip direction after ", NAttempts, " attempts"
	'		DF_Exposure = Default_DF_Exposure
	'	Exit Function
	Else
		Print "Found chip on ", Str$(NAttempts - Attempt + 1), "th attempt with exposure of ", DF_Exposure, " us"
		Print "FindChipDirectionWithDF: After bounding pm180: ", FindChipDirectionWithDF
	EndIf
	
	DF_Exposure = Default_DF_Exposure_Chip
'	FindChipDirectionWithDF = GetBoundAnglePM180(FindChipDirectionWithDF)
'	Print "FindChipDirectionWithDF: After bounding pm180: ", FindChipDirectionWithDF
	
Fend

Function DF_ChipDirection_LArASIC As Double
	''' LArASIC specific direction finding
	' Takes care of site specific differences
	
	DF_ChipDirection_LArASIC = -999.
	Boolean FoundText
	Double xT, yT, uT
	
	Select SITE$
		Case "MSU"
			VSet MSU_DF_ChipDir.ExposureTime, DF_Exposure
			VRun MSU_DF_ChipDir
			VGet MSU_DF_ChipDir.Geom03.RobotXYU, FoundText, xT, yT, uT
		Case "BNL"
'			VRun BNL_DF_ChipDir
'			VGet BNL_DF_ChipDir.Geom03.RobotXYU, isFoundT, xT, yT, uT
		Default
	Send
	
	If Not FoundText Then
'		Print "DF_ChipDirection_LArASIC: Did not find text"
		Exit Function
	EndIf
	DF_ChipDirection_LArASIC = GetBoundAnglePM180(uT + ChipTextOrientation)
	Print "DF_ChipDirection_LArASIC: Direction of text =", DF_ChipDirection_LArASIC
	
	
Fend



Function FindChipPositionWithDF As Boolean
'''' Wrapper function to find the direction of a chip with the down facing camera
''' Initializes global array ChipPos() which will store X,Y,U of chip
'' These are set in relevant DFFindLarASIC, DFFindColdADC, DFFindCOLDATA functions	FindChipPositionWithDF = False

	' Print "FindChipPositionWithDF"
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	' Can comment this line  out after testing	
	SelectSite("InFunctionDefinePallets")

	' Force more attenpts for position finding
	If CY(Here) < (CY(P_Camera) - 20) Then
		NAttempts = NAttempts_Chip_DAT * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_DAT
		Max_DF_Exposure = Max_DF_Exposure_Chip_DAT
	Else
		NAttempts = NAttempts_Chip_Tray * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_Tray
		Max_DF_Exposure = Max_DF_Exposure_Chip_Tray
	EndIf
	Print "Running find chip position with NAttempts = ", Str$(NAttempts)
	Print "Min exposure = ", Min_DF_Exposure
	Print "Max exposure = ", Max_DF_Exposure
	

	Integer Attempt
	Attempt = NAttempts
	
	Do While (Attempt > 0) 'Or Success
			
		DF_Exposure = Min_DF_Exposure + Attempt * Int((Max_DF_Exposure - Min_DF_Exposure) / (NAttempts))
		Print "Attempt ", Str$(NAttempts - Attempt), " with ExposureTime = ", Str$(DF_Exposure)

'		Int32 FindError
'		FindError = 0
		Select CHIPTYPE$
			Case "LArASIC"
				FindChipPositionWithDF = DFFindLArASIC
			Case "ColdADC"
				' FindChipPositionWithDF = DFFindColdADC
				Print "Error, not currently implemented for ColdADC, check if LArASIC works?"
				Exit Function
			Case "COLDATA"
				FindChipPositionWithDF = DFFindCOLDATA
				' FNAL implementation was previously inline here, but moved to the second commented
				' out version of DFFindCOLDATA below. May need a little tweaking to work here.
			Default
				Print "Error, chiptype not properly defined or DF find function does not exist for ", CHIPTYPE$
				Exit Function
		Send
		
		If FindChipPositionWithDF Then
			Print "Found"
			Exit Do
		EndIf
		Attempt = Attempt - 1
		
	Loop
	
	If FindChipPositionWithDF Then
		Print "Chip found on ", Str$(NAttempts - Attempt + 1), "th attempt with exposure of ", DF_Exposure, " us"
		Print "At XYU = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	Else
		Print "Could not find chip after ", NAttempts, " attempts"
	EndIf
	DF_Exposure = Default_DF_Exposure_Chip

Fend

Function DFFindLArASIC As Boolean
''' Function to get the orientation of LArASIC chip with the down facing camera
' This makes use of two marks on the surce, a larger manufacturing mark and a 
' smaller mark indicating where pin 1 is.
' it then finds the direction between these and subtracts 45 degrees to get the
' orienation of the chip
'' Stores results in global array ChipPos()	

	DFFindLArASIC = False
	
	' Whole chip recognition
	Boolean isFoundChip
	Double xC, yC, uC
	' Fiducial and manufacturer marker recognition
	Boolean isFoundL, isFoundS
	Double xL, yL, uL, xS, yS, uS
	Boolean isFoundT
	Double xT, yT, uT
	
	Select SITE$
		Case "MSU"

			VSet MSU_DF_ChipDir.ExposureTime, DF_Exposure
			VRun MSU_DF_ChipDir
			VGet MSU_DF_ChipDir.Corr01.RobotXYU, isFoundChip, xC, yC, uC
	
			' Get positions of Large and Small circular markers on chip
			VGet MSU_DF_ChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet MSU_DF_ChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
			
			 VGet MSU_DF_ChipDir.Geom03.RobotXYU, isFoundT, xT, yT, uT
		Case "TUT"
			'Print "Using tutorial sequences"
			VSet TUT_DF_ChipDir.ExposureTime, DF_Exposure
			VRun TUT_DF_ChipDir
			
			' Looks for something overall "chip like" - This does not consistently work, use BNL LArASIC text to make sure you see a chip
			' VGet TUT_DF_ChipDir.Corr01.RobotXYU, isFoundChip, xC, yC, uC
			' Try using pins at edge as outline	- Could potentially use the BNL LArASIC text but I think it isn't precise enough for position check
			VGet TUT_DF_ChipDir.Geom04.RobotXYU, isFoundChip, xC, yC, uC
			
			' Get positions of Large and Small circular markers on chip
			VGet TUT_DF_ChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet TUT_DF_ChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
			' Get text porition and orientation on chip - for me this is "BNL LArASIC"
			'''' N.B. TEXT MUST BE TAUGHT IN SPECIFIC ORIENTATION TO GET CORRECT uT VALUE		
			'''' TRY ROTATING AND RETEACHING UNTIL YOU GET AGREEMENT BETWEEN uT AND
			'''' FIDUCIAL MARKERS. FOR ME, THEY ONLY AGREED WHEN I HAD ORIENTATION AT -90.
			'''' i.e. AS VIEWED FROM FRONT OF RTS IN TRAY, TEXT WAS RIGHT WAY UP.
			''''     
			''''         ROBOT       ^
			''''     -------------   | -90
			''       '           '
			''       '   BNL     '
			'' 0<-   '   LArASIC '	-> +180	
			''       '           '
			''       '           '
			''       -------------
		
			
			VGet TUT_DF_ChipDir.Geom03.RobotXYU, isFoundT, xT, yT, uT
		Default
			
			Print "No defined vision sequence for LArASICs for site: ", SITE$
			Exit Function
			
	Send
	
	If Not isFoundL Then
		' Print "Failed to find largr manufacturing mark (bottom right of chip)"
		Exit Function
	EndIf
	' Print "Found large manufacturing marker"
	
	If Not isFoundS Then
		' Print "Failed to find small fiducial mark (top left of chip)"
		Exit Function
	EndIf
	' Print "Found small fiducial marker"
	
	If Not isFoundT Then
		' Print "Failed to find text on chip"
		Exit Function
	EndIf
	' Print "found text"
	
	Double AvX, AvY
	AvX = (xL + xS) /2
	AvY = (yL + yS) /2

	' Get polar vector from Large marker to Small marker
	Double DelX, DelY, Norm, Angle
	DelX = xS - xL
	DelY = yS - yL
	
	Norm = Sqr(DelX * DelX + DelY * DelY)
	
	If DelY >= 0 Then
		Angle = RadToDeg(Acos(DelX / Norm))
	Else
		Angle = -RadToDeg(Acos(DelX / Norm))
	EndIf
	
	If Abs(Norm - LArASICDimension) > TolXY Then
		Print "Large-to-small marker distance not within tolerance: " + Str$(Norm)
		Exit Function
	EndIf
	
	' Check text orientation is consistent with the direction of the chip
	If Abs(DiffAnglePM180(uT, (GetBoundAnglePM180(Angle - 45.)))) > 3. Then
		Print "Inconsistent orientation from text and markers"
		Print "uT = ", GetBoundAnglePM180(uT)
		Print "Marker angle = ", Str$(GetBoundAnglePM180(Angle - 45.))
	EndIf
	
	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = GetBoundAnglePM180(Angle - 45.)
	
	DFFindLArASIC = True
		
	' Print "Got here, should be returning TRUE"
Fend

'
Function FindChipPositionWithDFAdvanced As Boolean
	FindChipPositionWithDFAdvanced = False
	
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	FMPos(1) = 0
	FMPos(2) = 0
	FMPos(3) = 0
	
	MMPos(1) = 0
	MMPos(2) = 0
	MMPos(3) = 0
	
	SelectSite("InFunctionDefinePallets")
	
	' First find chip direction
	Double ChipDirection, CameraDirection, DiffDirection
	ChipDirection = FindChipDirectionWithDF
	CameraDirection = DiffAnglePM180(180, CU(Here)) ' Does this need an 180 offset?
	Print "HAND U ", CU(Here)
	
	Print "Cam direction :", CameraDirection
	
	Print "Chip direction :", ChipDirection

	' Determine chip orientation in image
	DiffDirection = DiffAnglePM180(CameraDirection, ChipDirection)
	Double Orientation
	Orientation = RoundAngleTo90(DiffDirection)
	
	Print "Chip orientation in image :", Orientation
	
	' Force more attenpts for position finding
	If CY(Here) < (CY(P_Camera) - 20) Then
		NAttempts = NAttempts_Chip_DAT * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_DAT
		Max_DF_Exposure = Max_DF_Exposure_Chip_DAT
		
		Min_DF_Brightness = Min_DF_Brightness_Chip_DAT
		Max_DF_Brightness = Max_DF_Brightness_Chip_DAT
		
		Min_DF_Contrast = Min_DF_Contrast_Chip_DAT
		Max_DF_Contrast = Max_DF_Contrast_Chip_DAT
	Else
		NAttempts = NAttempts_Chip_Tray * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_Tray
		Max_DF_Exposure = Max_DF_Exposure_Chip_Tray
		
		Min_DF_Brightness = Min_DF_Brightness_Chip_Tray
		Max_DF_Brightness = Max_DF_Brightness_Chip_Tray
		
		Min_DF_Contrast = Min_DF_Contrast_Chip_Tray
		Max_DF_Contrast = Max_DF_Contrast_Chip_Tray
	EndIf
	
	Print "Running find chip position with NAttempts (exposure scan) = ", Str$(NAttempts / 4)
	Print "Min exposure = ", Min_DF_Exposure
	Print "Max exposure = ", Max_DF_Exposure
	
	Print "Running find chip position with NAttempts (brightness scan) = ", Str$(NAttempts / 4)
	Print "Min brightness = ", Min_DF_Brightness
	Print "Max brightness = ", Max_DF_Brightness
	
	Print "Running find chip position with NAttempts (contrast scan) = ", Str$(NAttempts / 4)
	Print "Min contrast = ", Min_DF_Contrast
	Print "Max contrast = ", Max_DF_Contrast

'	Integer VisionAttempt
'	VisionAttempt = NAttempts
	
	Integer VisionAttempt_E, VisionAttempt_B, VisionAttempt_C, VNAttempts_E, VNAttempts_B, VNAttempts_C
	VNAttempts_E = NAttempts /8
	VNAttempts_B = NAttempts /8
	VNAttempts_C = NAttempts /8
	VisionAttempt_E = VNAttempts_E ' Exposure
	VisionAttempt_B = VNAttempts_B ' Brightness
	VisionAttempt_C = VNAttempts_C ' Contrast

	Integer VAttempt, VNAttempts
	VNAttempts = (VNAttempts_E * VNAttempts_B * VNAttempts_C)
	VAttempt = VNAttempts
	
	Integer CalcAttempt
	CalcAttempt = NAttempts ' Might want to reduce this a little
	
	Integer Light
'	For Light = 0 To 1
'		
'		If Light = 1 Then
'			UF_camera_light_OFF
'		EndIf
		
	Do While (CalcAttempt > 0)
		
		' First find fiducial marker (small circle near pin 1)
		Print "Will attempt to find fiducial marker (S Circle) for chip oriented at ", ChipDirection, " (", Orientation, " wrt image)"
	
		For Light = 0 To 1
			
			If Light = 1 Then
				UF_camera_light_OFF
			EndIf
	
			Do While (VisionAttempt_B > 0) 'Or Success
				DF_Brightness = Min_DF_Brightness + VisionAttempt_B * Int((Max_DF_Brightness - Min_DF_Brightness) / (VNAttempts_E))
				'Print "Attempt ", Str$(NAttempts - VisionAttempt_B), " with Brightness = ", Str$(DF_Brightness)
				
				Do While (VisionAttempt_C > 0) 'Or Success
					DF_Contrast = Min_DF_Contrast + VisionAttempt_C * Int((Max_DF_Contrast - Min_DF_Contrast) / (VNAttempts_B))
					'Print "Attempt ", Str$(NAttempts - VisionAttempt_C), " with Contrast = ", Str$(DF_Contrast)
		
					Do While (VisionAttempt_E > 0) 'Or Success
						DF_Exposure = Min_DF_Exposure + VisionAttempt_E * Int((Max_DF_Exposure - Min_DF_Exposure) / (VNAttempts_C))
					
						'Print "Attempt ", Str$(NAttempts - VisionAttempt_E), " with ExposureTime = ", Str$(DF_Exposure)
						Print "Attempt ", Str$(VNAttempts - VAttempt), " with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure
				
						' Vision sequences simple enough to use for different sites/chips.
						' Just need different vision sequence for larger chip size of COLDATA 
						' Handled in DFFindFiducialMark and DFFindManufacturingMark
						FindChipPositionWithDFAdvanced = DFFindFiducialMark(Orientation)
						
						If FindChipPositionWithDFAdvanced Then
							Print "Found fiducial mark"
							Exit Do
						EndIf
						VisionAttempt_E = VisionAttempt_E - 1
						
						VAttempt = VAttempt - 1 ' Overall attempt counter
						
					Loop
					VisionAttempt_E = VNAttempts_E
				
					If FindChipPositionWithDFAdvanced Then
						Exit Do
					EndIf
					VisionAttempt_C = VisionAttempt_C - 1
				
				Loop
				VisionAttempt_C = VNAttempts_C
	
				If FindChipPositionWithDFAdvanced Then
					Exit Do
				EndIf
				VisionAttempt_B = VisionAttempt_B - 1
	
			Loop
			VisionAttempt_B = VNAttempts_B
			VAttempt = VNAttempts
		
		Next

		If FindChipPositionWithDFAdvanced Then
			Print "Fiducial marker found on ", Str$(VNAttempts - VAttempt + 1), "th attempt with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure
			Print "At XYU = (", FMPos(1), ",", FMPos(2), ",", FMPos(3), ")"
		Else
			Print "Could not find fiducial mark after ", NAttempts, " attempts"
			Exit Do
		EndIf
		DF_Exposure = Default_DF_Exposure_Chip
		
		' Next find manufacturing marker (large circle opposite pin 1) 
		FindChipPositionWithDFAdvanced = False

		' First find fiducial marker (small circle near pin 1)
		Print "Will attempt to find manufacturing marker (L Circle) for chip oriented at ", ChipDirection, " (", Orientation, " wrt image)"
	
		For Light = 0 To 1
			
			If Light = 1 Then
				UF_camera_light_OFF
			Else
				UF_camera_light_ON
			EndIf
	
			Do While (VisionAttempt_B > 0) 'Or Success
				DF_Brightness = Min_DF_Brightness + VisionAttempt_B * Int((Max_DF_Brightness - Min_DF_Brightness) / (VNAttempts_E))
				'Print "Attempt ", Str$(NAttempts - VisionAttempt_B), " with Brightness = ", Str$(DF_Brightness)
				
				Do While (VisionAttempt_C > 0) 'Or Success
					DF_Contrast = Min_DF_Contrast + VisionAttempt_C * Int((Max_DF_Contrast - Min_DF_Contrast) / (VNAttempts_B))
					'Print "Attempt ", Str$(NAttempts - VisionAttempt_C), " with Contrast = ", Str$(DF_Contrast)
		
					Do While (VisionAttempt_E > 0) 'Or Success
						DF_Exposure = Min_DF_Exposure + VisionAttempt_E * Int((Max_DF_Exposure - Min_DF_Exposure) / (VNAttempts_C))
					
						'Print "Attempt ", Str$(NAttempts - VisionAttempt_E), " with ExposureTime = ", Str$(DF_Exposure)
						Print "Attempt ", Str$(VNAttempts - VAttempt), " with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure
				
						' Vision sequences simple enough to use for different sites/chips.
						' Just need different vision sequence for larger chip size of COLDATA 
						' Handled in DFFindFiducialMark and DFFindManufacturingMark
						FindChipPositionWithDFAdvanced = DFFindManufacturingMark(Orientation)
						
						If FindChipPositionWithDFAdvanced Then
							Print "Found fiducial mark"
							Exit Do
						EndIf
						VisionAttempt_E = VisionAttempt_E - 1
						
						VAttempt = VAttempt - 1 ' Overall attempt counter
						
					Loop
					VisionAttempt_E = VNAttempts_E
				
					If FindChipPositionWithDFAdvanced Then
						Exit Do
					EndIf
					VisionAttempt_C = VisionAttempt_C - 1
				
				Loop
				VisionAttempt_C = VNAttempts_C
	
				If FindChipPositionWithDFAdvanced Then
					Exit Do
				EndIf
				VisionAttempt_B = VisionAttempt_B - 1
	
			Loop
			
		Next
		UF_camera_light_ON
		
		VisionAttempt_B = VNAttempts_B
		VAttempt = VNAttempts
		
		If FindChipPositionWithDFAdvanced Then
			Print "Manufacturing marker found on ", Str$(VNAttempts - VAttempt + 1), "th attempt with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure
			Print "At XYU = (", MMPos(1), ",", MMPos(2), ",", MMPos(3), ")"
		Else
			Print "Could not find manufacturing mark after ", NAttempts, " attempts"
			Exit Do
		EndIf
		DF_Exposure = Default_DF_Exposure_Chip
		
		FindChipPositionWithDFAdvanced = True
	
		' should have marker position values in FMPos and MMPos
	
		''''''''
		Double AvX, AvY
		AvX = (MMPos(1) + FMPos(1)) /2 '(xL + xS) /2
		AvY = (MMPos(2) + FMPos(2)) /2 '(yL + yS) /2
	
		' Get polar vector from Large marker to Small marker
		Double DelX, DelY, Norm, Angle
		DelX = FMPos(1) - MMPos(1) 'xS - xL
		DelY = FMPos(2) - MMPos(2) 'yS - yL
		
		Norm = Sqr(DelX * DelX + DelY * DelY)
		
		If DelY >= 0 Then
			Angle = RadToDeg(Acos(DelX / Norm))
		Else
			Angle = -RadToDeg(Acos(DelX / Norm))
		EndIf
		
		Double ChipDim
		Select CHIPTYPE$
			Case "LArASIC"
				ChipDim = LArASICDimension
			Case "ColdADC"
				ChipDim = LArASICDimension
			Case "COLDATA"
				' ChipDim = COLDATADimension ' NOT YET IMPLEMENTED
				Print "PLEASE MEASURE AND DEFINE DISTANCE BETWEEN FIDUCIAL AND MANUFACTURING MARKER ON COLDATA IN RTS_tools.inc"
				Exit Function
			Default
				Print "Incorrect chip type ", CHIPTYPE$
				FindChipPositionWithDFAdvanced = False
				Exit Function
		Send
		
		If Abs(Norm - ChipDim) > TolXY Then
			Print "Large-to-small marker distance not within tolerance: " + Str$(Norm)
			FindChipPositionWithDFAdvanced = False
		EndIf
		
		' Check text orientation is consistent with the direction of the chip
		If Abs(DiffAnglePM180(ChipDirection, (GetBoundAnglePM180(Angle - 45.)))) > 3. Then
			FindChipPositionWithDFAdvanced = False

			Print "Inconsistent orientation from text and markers"
			Print "Text based = ", GetBoundAnglePM180(ChipDirection)
			Print "Marker angle = ", Str$(GetBoundAnglePM180(Angle - 45.))
		EndIf
		
		If FindChipPositionWithDFAdvanced Then
			Print "Found position"
			Exit Do
		EndIf
		
		CalcAttempt = CalcAttempt - 1
		Print ""
	Loop
'
'	If FindChipPositionWithDFAdvanced Then
'		Exit For
'	EndIf
	
	' Next
	
	If Not FindChipPositionWithDFAdvanced Then
		Exit Function
		
		' TODO: Instead of exiting, have an option to use Fiducial Mark + Chip package outline to estimate position?	
		' Actually unsure as the pins can throw off the square/rectangle finding by a few degrees.
		' Would simply be best to get better lighting!
		
	EndIf
		
	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = GetBoundAnglePM180(Angle - 45.)
	
	If FindChipPositionWithDFAdvanced Then
		Print "Chip found on ", Str$(NAttempts - CalcAttempt + 1), "th attempt"
		Print "At XYU = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	Else
		Print "Could not find chip after ", NAttempts, " attempts"
	EndIf
	DF_Exposure = Default_DF_Exposure_Chip
	
	FindChipPositionWithDFAdvanced = True
	' Print "Got here, should be returning TRUE"
Fend
	

Function DFFindFiducialMark(Orientation As Double) As Boolean
''' Function to get the position of fiducial marker only on small chip
' Allows for vision sequence settings to be ran independently for
' fiducial marker, chip text, and manufacturing marker
' In case of bad lighting conditions
'' Stores results in global array FMPos()	

	DFFindFiducialMark = False
	
	Boolean isFoundTL
	Double xTL, yTL, uTL
	
	Boolean isFoundTR
	Double xTR, yTR, uTR
	
	Boolean isFoundBL
	Double xBL, yBL, uBL

	Boolean isFoundBR
	Double xBR, yBR, uBR
	
	Select CHIPTYPE$
		Case "LArASIC"
			VSet DF_ChipFMark.ExposureTime, DF_Exposure
			VSet DF_ChipFMark.CameraBrightness, DF_Brightness
			VSet DF_ChipFMark.CameraContrast, DF_Contrast
			VRun DF_ChipFMark
			VGet DF_ChipFMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
			VGet DF_ChipFMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
			VGet DF_ChipFMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
			VGet DF_ChipFMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Case "ColdADC"
			VSet DF_ChipFMark.ExposureTime, DF_Exposure
			VSet DF_ChipFMark.CameraBrightness, DF_Brightness
			VSet DF_ChipFMark.CameraContrast, DF_Contrast
			VRun DF_ChipFMark
			VGet DF_ChipFMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
			VGet DF_ChipFMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
			VGet DF_ChipFMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
			VGet DF_ChipFMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Case "COLDATA"
			Print "Not currently implemented: See LArASIC/ColdADC DF_ChipFMark for example"
			Exit Function
'			VSet DF_CDChipFMark.ExposureTime, DF_Exposure
'			VRun DF_CDChipFMark
'			VGet DF_CDChipFMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
'			VGet DF_CDChipFMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
'			VGet DF_CDChipFMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
'			VGet DF_CDChipFMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Default
			Print "Invalid chiptype", CHIPTYPE$
			Exit Function
	Send
	
		
	Select Orientation
		Case 0
			'FM is in TL
			If Not isFoundTL Then
				Print "Could not find fiducial marker in TL position"
				Exit Function
			EndIf
			DFFindFiducialMark = isFoundTL
			FMPos(1) = xTL
			FMPos(2) = yTL
			FMPos(3) = uTL
			
			
		Case 90
			'FM is in BL
			If Not isFoundBL Then
				Print "Could not find fiducial marker in BL position"
				Exit Function
			EndIf
			DFFindFiducialMark = isFoundBL
			FMPos(1) = xBL
			FMPos(2) = yBL
			FMPos(3) = uBL
			
		Case 180
			'FM is in BR
			If Not isFoundBR Then
				Print "Could not find fiducial marker in BR position"
				Exit Function
			EndIf
			DFFindFiducialMark = isFoundBR
			FMPos(1) = xBR
			FMPos(2) = yBR
			FMPos(3) = uBR
			
			
		Case -90
			'FM is in TR
			If Not isFoundTR Then
				Print "Could not find fiducial marker in TR position"
				Exit Function
			EndIf
			DFFindFiducialMark = isFoundTR
			FMPos(1) = xTR
			FMPos(2) = yTR
			FMPos(3) = uTR
		Default
			Print "ERROR: non valid orientation value passed! Should be 0, 90, 180 or -90"
			Print "Please round value in call of DFFindFiducialMark"
			Exit Function
	Send
Fend
	
Function DFFindManufacturingMark(Orientation As Double) As Boolean
''' Function to get the position of fiducial marker only on small chip
' Allows for vision sequence settings to be ran independently for
' fiducial marker, chip text, and manufacturing marker
' In case of bad lighting conditions
'' Stores results in global array MMPos()	

	DFFindManufacturingMark = False
	
	Boolean isFoundTL
	Double xTL, yTL, uTL
	
	Boolean isFoundTR
	Double xTR, yTR, uTR
	
	Boolean isFoundBL
	Double xBL, yBL, uBL

	Boolean isFoundBR
	Double xBR, yBR, uBR
	
	Select CHIPTYPE$
		Case "LArASIC"
			VSet DF_ChipMMark.ExposureTime, DF_Exposure
			VSet DF_ChipMMark.CameraBrightness, DF_Brightness
			VSet DF_ChipMMark.CameraContrast, DF_Contrast
			VRun DF_ChipMMark
			VGet DF_ChipMMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
			VGet DF_ChipMMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
			VGet DF_ChipMMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
			VGet DF_ChipMMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Case "ColdADC"
			VSet DF_ChipMMark.ExposureTime, DF_Exposure
			VSet DF_ChipMMark.CameraBrightness, DF_Brightness
			VSet DF_ChipMMark.CameraContrast, DF_Contrast
			VRun DF_ChipMMark
			VGet DF_ChipMMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
			VGet DF_ChipMMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
			VGet DF_ChipMMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
			VGet DF_ChipMMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Case "COLDATA"
			Print "Not currently implemented: See LArASIC/ColdADC DF_ChipMMark for example"
			Exit Function
'			VSet DF_CDChipMMark.ExposureTime, DF_Exposure
'			VRun DF_CDChipMMark
'			VGet DF_CDChipMMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
'			VGet DF_CDChipMMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
'			VGet DF_CDChipMMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
'			VGet DF_CDChipMMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Default
			Print "Invalid chiptype", CHIPTYPE$
			Exit Function
	Send
	
		
	Select Orientation
		Case 0
			'MM is in BR
			If Not isFoundBR Then
				Print "Could not find manufacturing marker in BL position"
				Exit Function
			EndIf
			DFFindManufacturingMark = isFoundBR
			MMPos(1) = xBR
			MMPos(2) = yBR
			MMPos(3) = uBR
			
		Case 90
			'MM is in TR
			If Not isFoundTR Then
				Print "Could not find manufacturing marker in TL position"
				Exit Function
			EndIf
			DFFindManufacturingMark = isFoundTR
			MMPos(1) = xTR
			MMPos(2) = yTR
			MMPos(3) = uTR
		Case 180
			'MM is in TL
			If Not isFoundTL Then
				Print "Could not find manufacturing marker in TL position"
				Exit Function
			EndIf
			DFFindManufacturingMark = isFoundTL
			MMPos(1) = xTL
			MMPos(2) = yTL
			MMPos(3) = uTL
		Case -90
			'MM is in BL
			If Not isFoundBL Then
				Print "Could not find manufacturing marker in BL position"
				Exit Function
			EndIf
			DFFindManufacturingMark = isFoundBL
			MMPos(1) = xBL
			MMPos(2) = yBL
			MMPos(3) = uBL
		Default
			Print "ERROR: non valid orientation value passed! Should be 0, 90, 180 or -90"
			Print "Please round value in call of DFFindManufacturingMark"
			Exit Function
	Send
			
Fend


Function FindChipPositionWithDFFromOutline As Boolean
	
	
	' First find chip direction
	Double ChipDirection, CameraDirection, DiffDirection
	ChipDirection = FindChipDirectionWithDF
	CameraDirection = DiffAnglePM180(180, CU(Here)) ' Does this need an 180 offset?
	Print "HAND U ", CU(Here)
	
	Print "Cam direction :", CameraDirection
	
	Print "Chip direction :", ChipDirection

	' Unlike Find Chip advance here we care about orientation to determine direction along with any minor U misplacement 
	' NOT to find chip feature position in the image
	Double Orientation
	Orientation = RoundAngleTo90(ChipDirection)
	
	Print "Chip orientation (in world coordinates) :", Orientation
	
	
	If CY(Here) < (CY(P_Camera) - 20) Then
		NAttempts = NAttempts_Chip_DAT * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_DAT
		Max_DF_Exposure = Max_DF_Exposure_Chip_DAT
		
		Min_DF_Brightness = Min_DF_Brightness_Chip_DAT
		Max_DF_Brightness = Max_DF_Brightness_Chip_DAT
		
		Min_DF_Contrast = Min_DF_Contrast_Chip_DAT
		Max_DF_Contrast = Max_DF_Contrast_Chip_DAT
	Else
		NAttempts = NAttempts_Chip_Tray * 5
		Min_DF_Exposure = Min_DF_Exposure_Chip_Tray
		Max_DF_Exposure = Max_DF_Exposure_Chip_Tray
		
		Min_DF_Brightness = Min_DF_Brightness_Chip_Tray
		Max_DF_Brightness = Max_DF_Brightness_Chip_Tray
		
		Min_DF_Contrast = Min_DF_Contrast_Chip_Tray
		Max_DF_Contrast = Max_DF_Contrast_Chip_Tray
	EndIf
	
	
	Print "Running find chip position with NAttempts (exposure scan) = ", Str$(NAttempts / 4)
	Print "Min exposure = ", Min_DF_Exposure
	Print "Max exposure = ", Max_DF_Exposure
	
	Print "Running find chip position with NAttempts (brightness scan) = ", Str$(NAttempts / 4)
	Print "Min brightness = ", Min_DF_Brightness
	Print "Max brightness = ", Max_DF_Brightness
	
	Print "Running find chip position with NAttempts (contrast scan) = ", Str$(NAttempts / 4)
	Print "Min contrast = ", Min_DF_Contrast
	Print "Max contrast = ", Max_DF_Contrast

'	Integer VisionAttempt
'	VisionAttempt = NAttempts
	
	Integer VisionAttempt_E, VisionAttempt_B, VisionAttempt_C, VNAttempts_E, VNAttempts_B, VNAttempts_C
	VNAttempts_E = NAttempts /8
	VNAttempts_B = NAttempts /8
	VNAttempts_C = NAttempts /8
	VisionAttempt_E = VNAttempts_E ' Exposure
	VisionAttempt_B = VNAttempts_B ' Brightness
	VisionAttempt_C = VNAttempts_C ' Contrast	
	
	Integer VAttempt, VNAttempts
	VNAttempts = (VNAttempts_E * VNAttempts_B * VNAttempts_C)
	VAttempt = VNAttempts
	
	Integer Light
	' Toggle light on and off
	For Light = 0 To 1
		If Light = 1 Then
			UF_camera_light_OFF
		Else
			UF_camera_light_ON
		EndIf

		Do While (VisionAttempt_B > 0) 'Or Success
			DF_Brightness = Min_DF_Brightness + VisionAttempt_B * Int((Max_DF_Brightness - Min_DF_Brightness) / (VNAttempts_E))
			'Print "Attempt ", Str$(NAttempts - VisionAttempt_B), " with Brightness = ", Str$(DF_Brightness)
			
			Do While (VisionAttempt_C > 0) 'Or Success
				DF_Contrast = Min_DF_Contrast + VisionAttempt_C * Int((Max_DF_Contrast - Min_DF_Contrast) / (VNAttempts_B))
				'Print "Attempt ", Str$(NAttempts - VisionAttempt_C), " with Contrast = ", Str$(DF_Contrast)
	
				Do While (VisionAttempt_E > 0) 'Or Success
					DF_Exposure = Min_DF_Exposure + VisionAttempt_E * Int((Max_DF_Exposure - Min_DF_Exposure) / (VNAttempts_C))
				
					'Print "Attempt ", Str$(NAttempts - VisionAttempt_E), " with ExposureTime = ", Str$(DF_Exposure)
					Print "Attempt ", Str$(VNAttempts - VAttempt), " with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure
			
					FindChipPositionWithDFFromOutline = DFFindChipOutline

					If FindChipPositionWithDFFromOutline Then
						Print "Found outline"
						Exit Do
					EndIf
					VisionAttempt_E = VisionAttempt_E - 1
					
					VAttempt = VAttempt - 1 ' Overall attempt counter
					
				Loop
				VisionAttempt_E = VNAttempts_E
			
				If FindChipPositionWithDFFromOutline Then
					Exit Do
				EndIf
				VisionAttempt_C = VisionAttempt_C - 1
			
			Loop
			VisionAttempt_C = VNAttempts_C

			If FindChipPositionWithDFFromOutline Then
				Exit Do
			EndIf
			VisionAttempt_B = VisionAttempt_B - 1

		Loop
		
		If FindChipPositionWithDFFromOutline Then
			Exit For
		EndIf
		
	Next
	UF_camera_light_ON
	
	If FindChipPositionWithDFFromOutline Then
		ChipPos(3) = GetBoundAnglePM180(ChipPos(3) + Orientation)
		Print "Chip position = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	EndIf

	
Fend

Function DFFindChipOutline As Boolean

	DFFindChipOutline = False
	
	'''''
	Boolean isFound1, isFound2, isFound3
	Double xO1, yO1, uO1, xO2, yO2, uO2, xO3, yO3, uO3, Scale
	Int32 i, NOutlineAttempts
	NOutlineAttempts = 2
	Select CHIPTYPE$
		Case "LArASIC"
			Print "Running DF_Chip_Outline with B:", DF_Brightness, ", C:", DF_Contrast, ", E:", DF_Exposure

			VSet DF_Chip_Outline.ExposureTime, DF_Exposure
			VSet DF_Chip_Outline.CameraBrightness, DF_Brightness
			VSet DF_Chip_Outline.CameraContrast, DF_Contrast
			' Take three measurements and check for consistency 
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound1, xO1, yO1, uO1
				VGet DF_Chip_Outline.Geom01.Scale, Scale
				If Abs(Scale - 1) > 0.05 Then
					isFound1 = False
				EndIf
				If isFound1 Then
					Print "Found 1: ", xO1, ",", yO1, ",", uO1
					Exit For
				EndIf
			Next
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound2, xO2, yO2, uO2
				If Abs(Scale - 1) > 0.05 Then
					isFound2 = False
				EndIf
				If isFound2 Then
					Print "Found 2: ", xO2, ",", yO2, ",", uO2
					Exit For
				EndIf
			Next
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound3, xO3, yO3, uO3
				If Abs(Scale - 1) > 0.05 Then
					isFound3 = False
				EndIf
				If isFound3 Then
					Print "Found 3: ", xO3, ",", yO3, ",", uO3
					Exit For
				EndIf
			Next
			
		Case "ColdADC"
			VSet DF_Chip_Outline.ExposureTime, DF_Exposure
			VSet DF_Chip_Outline.CameraBrightness, DF_Brightness
			VSet DF_Chip_Outline.CameraContrast, DF_Contrast
			' Take three measurements and check for consistency 
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound1, xO1, yO1, uO1
				If isFound1 Then
					Print "Found 1: ", xO1, ",", yO1, ",", uO1
					Exit For
				EndIf
			Next
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound2, xO2, yO2, uO2
				If isFound2 Then
					Print "Found 2: ", xO2, ",", yO2, ",", uO2
					Exit For
				EndIf
			Next
			For i = 1 To NOutlineAttempts
				VRun DF_Chip_Outline
				VGet DF_Chip_Outline.Geom01.RobotXYU, isFound3, xO3, yO3, uO3
				If isFound3 Then
					Print "Found 3: ", xO3, ",", yO3, ",", uO3
					Exit For
				EndIf
			Next
		Case "COLDATA"
			Print "Not currently implemented: See LArASIC/ColdADC DF_ChipFMark for example"
			Exit Function
'			VSet DF_CDChipFMark.ExposureTime, DF_Exposure
'			VRun DF_CDChipFMark
'			VGet DF_CDChipFMark.TL.RobotXYU, isFoundTL, xTL, yTL, uTL
'			VGet DF_CDChipFMark.TR.RobotXYU, isFoundTR, xTR, yTR, uTR
'			VGet DF_CDChipFMark.BL.RobotXYU, isFoundBL, xBL, yBL, uBL
'			VGet DF_CDChipFMark.BR.RobotXYU, isFoundBR, xBR, yBR, uBR
		Default
			Print "Invalid chiptype", CHIPTYPE$
			Exit Function
	Send
	
	If (Not isFound1) And (Not isFound2) And (Not isFound3) Then
		Print "Outline not found at all"
		ChipPos(1) = 0.
		ChipPos(2) = 0.
		ChipPos(3) = 0.
		DFFindChipOutline = False
		Print "Return FALSE and position = (0,0,0)"
		Exit Function
	EndIf
	
	
	uO1 = GetBoundAnglePM45(uO1)
	uO2 = GetBoundAnglePM45(uO2)
	uO3 = GetBoundAnglePM45(uO3)
	
	Double AvX, AvY, AvU
	AvX = 0.
	AvY = 0.
	AvU = 0.
	Double SpreadX, SpreadY, SpreadU
	SpreadX = 0.
	SpreadY = 0.
	SpreadU = 0.
	If (isFound1 And isFound2 And isFound3) Then
		AvX = (xO1 + xO2 + xO3) /3
		AvY = (yO1 + yO2 + yO3) /3
		AvU = (uO1 + uO2 + uO3) /3
		
		'SpreadX = Sqr((xO1 - AvX) * (xO1 - AvX) + (xO2 - AvX) * (xO2 - AvX) + (xO3 - AvX) * (xO3 - AvX)) / 2 ' n - 1
		'SpreadY = Sqr((yO1 - AvY) * (yO1 - AvY) + (yO2 - AvY) * (yO2 - AvY) + (yO3 - AvY) * (yO3 - AvY)) / 2
		'SpreadU = Sqr((uO1 - AvU) * (uO1 - AvU) + (uO2 - AvU) * (uO2 - AvU) + (uO3 - AvU) * (uO3 - AvU)) / 2
		' Don't need to calc var/std just look at distance for each measurement, easier to reject measurements
		If Sqr((xO1 - AvX) * (xO1 - AvX)) > 0.1 Or Sqr((yO1 - AvY) * (yO1 - AvY)) > 0.1 Or Sqr((uO1 - AvU) * (uO1 - AvU)) > 0.5 Then
			Print "Measurement 1: bad tolerance"
			isFound1 = False
		EndIf
		
		If Sqr((xO2 - AvX) * (xO2 - AvX)) > 0.1 Or Sqr((yO2 - AvY) * (yO2 - AvY)) > 0.1 Or Sqr((uO2 - AvU) * (uO2 - AvU)) > 0.5 Then
			Print "Measurement 2: bad tolerance"
			isFound2 = False
		EndIf
		
		If Sqr((xO3 - AvX) * (xO3 - AvX)) > 0.1 Or Sqr((yO3 - AvY) * (yO3 - AvY)) > 0.1 Or Sqr((uO3 - AvU) * (uO3 - AvU)) > 0.5 Then
			Print "Measurement 3: bad tolerance"
			isFound3 = False
		EndIf
		
	EndIf
		
	If (isFound1 And isFound2 And isFound3) Then
		Print "Found three consistent values"
		DFFindChipOutline = True
	ElseIf (isFound1 And isFound2) Then
		Print "WARNING: Cannot consistently find chip"
		AvX = (xO1 + xO2) /2
		AvY = (yO1 + yO2) /2
		AvU = (uO1 + uO2) /2
		
		If Sqr((xO1 - xO2) * (xO1 - xO2)) > 0.1 Or Sqr((yO1 - yO2) * (yO1 - yO2)) > 0.1 Or Sqr((uO1 - uO2) * (uO1 - uO2)) > 0.5 Then
			Print "Measurement: inconsistent"
		 	DFFindChipOutline = False
		EndIf
		
	ElseIf (isFound1 And isFound3) Then
		Print "WARNING: Cannot consistently find chip"
		AvX = (xO1 + xO3) /2
		AvY = (yO1 + yO3) /2
		AvU = (uO1 + uO3) /2
		
		If Sqr((xO1 - xO3) * (xO1 - xO3)) > 0.1 Or Sqr((yO1 - yO3) * (yO1 - yO3)) > 0.1 Or Sqr((uO1 - uO3) * (uO1 - uO3)) > 0.5 Then
			Print "Measurement: inconsistent"
			DFFindChipOutline = False
		EndIf
	ElseIf (isFound2 And isFound3) Then
		Print "WARNING: Cannot consistently find chip"
		AvX = (xO2 + xO3) /2
		AvY = (yO2 + yO3) /2
		AvU = (uO2 + uO3) /2
		If Sqr((xO2 - xO3) * (xO2 - xO3)) > 0.1 Or Sqr((yO2 - yO3) * (yO2 - yO3)) > 0.1 Or Sqr((uO2 - uO3) * (uO2 - uO3)) > 0.5 Then
			Print "Measurement: inconsistent"
			DFFindChipOutline = False
		EndIf
	Else
		Print "Cannot find chip"
		Print "isFound1 = ", isFound1
		Print "isFound2 = ", isFound2
		Print "isFound3 = ", isFound3
		DFFindChipOutline = False
	EndIf
	
	If Not DFFindChipOutline Then
		ChipPos(1) = 0.
		ChipPos(2) = 0.
		ChipPos(3) = 0.
		Print "Return FALSE and position = (0,0,0)"
		Exit Function
	EndIf

	ChipPos(1) = AvX
	ChipPos(2) = AvY
	ChipPos(3) = AvU
	Print "Return TRUE and Position = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	
Fend


''' Function to find the orientation of the COLDATA chips with the down facing camera
' The surface features are not as readily identifiable as the smaller chips and so
' this function uses several redundant vision sequences and takes an average
' It MUST find at least one of the vision sequences with the text "COLDATA" in order
' to determine the direction reliably. Other inputs are for improving the precision of the 
' translational position as the printed text is likely less accurate than the chip 
' manufacturing marks
'' Stores results in global array ChipPos()
'''' NOTE, SEE FNAL IMPLEMENTATION COMMENTED OUT BELOW, CHECK WHICH WORKS BEST.
Function DFFindCOLDATA As Boolean

	DFFindCOLDATA = False
	
	Boolean AllowPartial
	AllowPartial = True
	
	' COLDATA chips are more difficult to pick out features on	
	' If possible use position of COLDATA text, center of outline, and center of full chip sequence to find position
	' Outline often isn't properly found due to occlusion, and so is less reliable
	
	Boolean isFoundChip, isFoundOutline, isFoundString
	Double xC, yC, uC ' Whole chip sequence result
	Double xO, yO, uO ' Chip outline sequence result
	Double xS, yS, uS ' Chip COLDATA string result
	Double xSCEst, ySCEst, uSCEst ' Estimate of chip center from COLDATA string position
	Double AvX, AvY, AvU ' Averages
	Double DelX, DelY, DelU ' Differences
	Double DelUAC, DelUAS ' Differences between calcualtd angle from positions and measured angles
	Double Norm, Angle ' Polar vector between chip center and coldata, for orientation and offset comparison
	
	Select SITE$
		Case "MSU"
		VRun MSU_DF_CDDir
		'VGet MSU_DF_CDDir.Point01.RobotXYU, isFP, xP, yP, uP ' For finding image center in testing
		VGet MSU_DF_CDDir.WholeChip.RobotXYU, isFoundChip, xC, yC, uC
		VGet MSU_DF_CDDir.ChipOutline.RobotXYU, isFoundOutline, xO, yO, uO
		VGet MSU_DF_CDDir.COLDATAString.RobotXYU, isFoundString, xS, yS, uS
		Default
			Print "Not a valid site name ", SITE$
	Send
	
	If Not AllowPartial And Not (isFoundChip And isFoundOutline And isFoundString) Then
		' Require all three sequences to be successful
		Print "Could not find all features"
		Exit Function
	ElseIf (Not isFoundChip) And (Not isFoundString) Then
		' When using partial infomration, require at least one sequence which recogninizes the COLDATA string	
		Print "Could not find the COLDATA text for orientation"
		Exit Function
	EndIf
	
	' Found COLDATA string
	' Get chip center estimate froms tring

	xSCEst = -9999.
	ySCEst = -9999.
	
	Byte FoundFeatures
	FoundFeatures = 0
	
	If isFoundChip Then
		'Print "Found chip"
		FoundFeatures = FoundFeatures + 100
	EndIf

	If isFoundString Then
		'Print "Found COLDATA string"
		FoundFeatures = FoundFeatures + 10
		' Calculate estimate of position from string
		uSCEst = GetBoundAnglePM180(uS + 90.)
		xSCEst = xS - COLDATATextOffset * Cos(DegToRad(uSCEst))
		ySCEst = yS - COLDATATextOffset * Sin(DegToRad(uSCEst))
	EndIf
	
	If isFoundOutline Then
		'Print "Found outline"
		FoundFeatures = FoundFeatures + 1
	EndIf
	' Print "FoundFeatures = ", FoundFeatures
	If FoundFeatures < 111 And Not AllowPartial Then
		Print "Could not find all features" ' : ", FoundFeatures
		Exit Function
	EndIf
		
	If AllowPartial And isFoundChip And Not isFoundString Then
		' Just use whole chip position
		ChipPos(1) = xC
		ChipPos(2) = yC
		ChipPos(3) = GetBoundAnglePM180(uC + 90.)

		DFFindCOLDATA = True
		Exit Function
	EndIf
	
	' If getting here then isFoundString must be true
	If Not isFoundString Then
		ChipPos(1) = 0.
		ChipPos(2) = 0.
		ChipPos(3) = 0.
		DFFindCOLDATA = False
		Exit Function
	EndIf

	' If no outline, average with whole chip
	If AllowPartial And Not isFoundOutline Then
		' Check constistency between string estimate and whole chip, then use average
		' Consistency check	
		If Sqr((xC - xSCEst) * (xC - xSCEst) + (yC - ySCEst) * (yC - ySCEst)) > TolXY Then
			
			DFFindCOLDATA = False
			Exit Function
		EndIf

		' For more precise angle we want to draw line between chip center and COLDATA string center
		DelX = xS - xC
		DelY = yS - yC
		DelU = DiffAnglePM180(uC, uS)
		
	'	DelU = GetBoundAnglePM45(uS) - GetBoundAnglePM45(uO) ' Use as sanity check, but may be out by n*90 degrees
	
		Norm = Sqr((DelX * DelX) + (DelY * DelY))
		If Abs(Norm - COLDATATextOffset) > TolXY Then
'			Print "Calculated distance between chip center from whole chip sequence and COLDATA string is not consistent with expected offset"
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		' Check consistent angles
		If Abs(DelU) > TolAngle Then
'			Print "Angles found by COLDATA string sequence and whole chip sequence are inconsistent - DelU = ", DelU
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		If DelY >= 0 Then
			Angle = RadToDeg(Acos(DelX / Norm))
		Else
			Angle = -RadToDeg(Acos(DelX / Norm))
		EndIf
		
		DelUAC = DiffAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
		DelUAS = DiffAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
		If Abs(DelUAC) > TolAngle Or Abs(DelUAS) > TolAngle Then
'			Print "Angle between COLDATA string and whole chip sequence result are inconsistent with sequence angles"
'			Print "Calculated angle          ", Angle
'			Print "COLDATA string angle      ", GetBoundAnglePM180(uS + 90.)
'			Print "Whole chip sequence angle ", GetBoundAnglePM180(uC + 90.)
			DFFindCOLDATA = False
			Exit Function
		EndIf
		
		
		' If it gets here used the average of the string est and whole chip?
		
		ChipPos(1) = (xC + xSCEst) / 2
		ChipPos(2) = (yC + ySCEst) / 2
		ChipPos(3) = GetBoundAnglePM180(Angle) ' <Maybe average?
		'ChipPos(3) = AverageAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
		
		DFFindCOLDATA = True
		Exit Function
	EndIf

	' Check constistency between string estimate and outline, then use average
	' Consistency check	
	If Sqr((xO - xSCEst) * (xO - xSCEst) + (yO - ySCEst) * (yO - ySCEst) > TolXY) Then
		DFFindCOLDATA = False
		Exit Function
	EndIf

	' For more precise angle we want to draw line between chip center and COLDATA string center
	DelX = xS - xO
	DelY = yS - yO
	' Outline won't be able to determine orientation, but can get angle away from axis\
	' Bounding the angle between +/-45deg allows comparison even if out by n*90deg
	DelU = DiffAnglePM180(GetBoundAnglePM45(uO), GetBoundAnglePM45(uS))
	
	Norm = Sqr((DelX * DelX) + (DelY * DelY))
	If Abs(Norm - COLDATATextOffset) > TolXY Then
'		Print "Calculated distance between chip center from whole chip sequence and COLDATA string is not consistent with expected offset"
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	' Check consistent angles
	If Abs(DelU) > TolAngle Then
'		Print "Angles found by COLDATA string sequence and whole chip sequence are inconsistent - DelU = ", DelU
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	If DelY >= 0 Then
		Angle = RadToDeg(Acos(DelX / Norm))
	Else
		Angle = -RadToDeg(Acos(DelX / Norm))
	EndIf
	
	' This won't work?

	DelUAC = DiffAnglePM180(GetBoundAnglePM45(uO), GetBoundAnglePM45(Angle))
	DelUAS = DiffAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
	If Abs(DelUAC) > TolAngle Or Abs(DelUAS) > TolAngle Then
'		Print "Angle between COLDATA string and whole chip sequence result are inconsistent with sequence angles"
'		Print "Calculated angle (bound within +/-45)     : ", Angle, " (", GetBoundAnglePM45(Angle), ")"
'		Print "COLDATA string angle                      :", GetBoundAnglePM180(uS + 90.)
'		Print "Outline sequence angle bound within +/-45 :", GetBoundAnglePM45(uC)
		DFFindCOLDATA = False
		Exit Function
	EndIf
	
	AvX = (xO + xSCEst) /2
	AvY = (yO + ySCEst) /2
	AvU = AverageAnglePM180(GetBoundAnglePM180(uS + 90.), GetBoundAnglePM180(Angle))
	' If here, and no full chip result, use the average of the sting and the outline
	If Not isFoundChip Then
		ChipPos(1) = AvX
		ChipPos(2) = AvY
		ChipPos(3) = AvU
		DFFindCOLDATA = True
		Exit Function
	EndIf
	
	' For full information, check consistency of above average, then average with whole chip.
	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
'		Print "Average position from string+outline does not match whole chip sequence results"
'		Print "String estimate               : (", xSCEst, ",", ySCEst, ",", GetBoundAnglePM180(uS + 90.), ")"
'		Print "Outline result (U in pm45)    : (", xO, ",", yO, ",", GetBoundAnglePM45(uO), ")"
'		Print "Angle between string and outline results: ", GetBoundAnglePM180(Angle)
'		Print "Average of string and outline : (", AvX, ",", AvU, ",", AvU, ")"
'		Print "Whole chip result             : (", xC, ",", yC, ",", GetBoundAnglePM180(uC + 90.), ")"
		DFFindCOLDATA = False
		Exit Function
	EndIf
		
	' If OK average in with whole chip result	
	ChipPos(1) = (xSCEst + xO + xC) / 3
	ChipPos(2) = (ySCEst + yO + yC) / 3
	ChipPos(3) = AverageAnglePM180(GetBoundAnglePM180(uC + 90.), GetBoundAnglePM180(Angle))
'	
'			'''''''''''''''''''''''''''''''''''''''''''''''''''
'	Print "Success! Found ", FoundFeatures, " XYU: ", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ","
'	If Abs(GetBoundAnglePM45(ChipPos(3))) > 3. Then
'		Print "Angles :"
'		Print "String  ", GetBoundAnglePM180(uS + 90.)
'		Print "Outline ", GetBoundAnglePM180(uO)
'		Print "Chip    ", GetBoundAnglePM180(uC + 90.)
'		Print "Calc    ", GetBoundAnglePM180(Angle)
'	EndIf
'	'''''''''''''''''''''''''''''''''''''''''''''''''''	
	
	DFFindCOLDATA = True
Fend

''' Code from FNAL implementation here.
' Function DFFindCOLDATA
''			
'			Int32 ToCheck, nFailLimit
'			ToCheck = 10
'			nFailLimit = 50
'			Int32 it, tot
'			it = 0
'			tot = 0
'			' NB cannot declare array length as variable, unfortunately means several hard coded 10s
'			' Make sure to change all divisors for averages if this changes below
'			Double XCHECK(10), YCHECK(10), UCHECK(10)
'			Double AvX, AvY, AvU
'			AvX = 0.
'			AvY = 0.
'			' need to track how many end up on +/- side of 180, not close to 0
'			Int32 nU0, nUm180, nUp180
'			Double AvU0, AvUm180, AvUp180
'			nU0 = 0
'			nUm180 = 0
'			nUp180 = 0
'			AvU0 = 0.
'			AvUm180 = 0.
'			AvUp180 = 0.
'			
'			Do While ToCheck > 0
'				tot = tot + 1
'				If DFFindCOLDATA Then
'					it = it + 1
'					XCHECK(it) = ChipPos(1)
'					YCHECK(it) = ChipPos(2)
'					UCHECK(it) = GetBoundAnglePM180(ChipPos(3))
'					AvX = AvX + ChipPos(1)
'					AvY = AvY + ChipPos(2)
'					'AvU = AvU + ChipPos(3) '  Need to think about averaging around +/-180
'					If ChipPos(3) < -90. Then
'						nUm180 = nUm180 + 1
'						AvUm180 = AvUm180 + ChipPos(3)
'					ElseIf ChipPos(3) < 90. Then
'						nU0 = nU0 + 1
'						AvU0 = AvU0 + ChipPos(3)
'					Else
'						nUp180 = nUp180 + 1
'						AvUp180 = AvUp180 + ChipPos(3)
'					EndIf
'					
'					ToCheck = ToCheck - 1
'				EndIf
'				If tot > nFailLimit Then
'					Print "Too many failures"
'					ChipPos(1) = 0.
'					ChipPos(2) = 0.
'					ChipPos(3) = 0.
'					FindChipDirectionWithDF = False
'					Exit Function
'				EndIf
'			Loop
'			AvX = AvX /10
'			AvY = AvY /10
'			
'
'			
'			' Can't have U values at -180, 0 and +180
'			If (nU0 > 0 And nUm180 > 0 And nUp180 > 0) Then
'				Print "Inconsistent angle values returned for averaging"
'				Print " U  < -90       :", nUm180
'				Print " -90 <= U < +90 :", nU0
'				Print " +90 <= U       :", nUp180
'				ChipPos(1) = 0.
'				ChipPos(2) = 0.
'				ChipPos(3) = 0.
'				FindChipDirectionWithDF = False
'				Exit Function
'			EndIf
'			
'			If nUm180 > 0 Then
'				AvUm180 = AvUm180 / nUm180
'			EndIf
'			If nU0 > 0 Then
'				AvU0 = AvU0 / nU0
'			EndIf
'			If nUp180 > 0 Then
'				AvUp180 = AvUp180 / nUp180
'			EndIf
'			
'			' If values close to both -180 and +180, need to average around 180, so add 360 to negative values
'			If nUm180 > 0 And nUp180 > 0 Then
'				AvUm180 = AvUm180 + 360.
'			EndIf
'			
'			
'			
'			AvU = GetBoundAnglePM180(((nUm180 * AvUm180) + (nU0 * AvU0) + (nUp180 * AvUp180)) / 10)
'						
'			Double StdDvX, StdDvY, StdDvU
''			Print "Results over ", 10, " successful iterations for ", tot, " total iterations"
'			For it = 1 To 10
'				StdDvX = StdDvX + (XCHECK(it) - AvX) * (XCHECK(it) - AvX)
'				StdDvY = StdDvY + (YCHECK(it) - AvY) * (YCHECK(it) - AvY)
'				StdDvU = StdDvU + (UCHECK(it) - AvU) * (UCHECK(it) - AvU)
''				Print "(", XCHECK(it), ",", YCHECK(it), ",", UCHECK(it), ")"
'			Next
'			StdDvX = Sqr(StdDvX / 10)
'			StdDvY = Sqr(StdDvY / 10)
'			StdDvU = Sqr(StdDvU / 10)
'			
''			Print "Average : (", AvX, ",", AvY, ",", AvU, ")"
''			Print "Std dev : (", StdDvX, ",", StdDvY, ",", StdDvU, ")"
'			
'			If StdDvX * StdDvX + StdDvY * StdDvY > TolXY * TolXY Or StdDvU > TolAngle Then
'				Print "Measurement spread too high"
'				ChipPos(1) = 0.
'				ChipPos(2) = 0.
'				ChipPos(3) = 0.
'				FindChipDirectionWithDF = False
'				Exit Function
'			EndIf
'			
'			ChipPos(1) = AvX
'			ChipPos(2) = AvY
'			ChipPos(3) = AvU
'			FindChipDirectionWithDF = False
' Fend

Function UF_CHIP_FIND As Boolean
''' Funvtion to find a chip at the up facing camera and get its positional information
' Stores results in global array UFChipPos()	

	' NOTE TODO JW: For COLDATA cannot rely on finding only three corners, just take three of the four corners found 
	' and use GetBoundAnglePM45 function on differences to ensure in same quadrant of angle or the vision
	' sequence may find wildly inconsistent angles for each measurement at incremebts of 90 degrees.
	' The DF camera is used to determine direction anyway
	UF_CHIP_FIND = False
	Boolean found(4)
	Boolean isFound(4) ' Check if separate variable is needed for this
	' Seems to maybe give different result?
	Double ResX(4), ResY(4), ResU(4)
	SelectSite("InFunctionDefinePallets") ' To get values for exposures 
	
	' Want a higher number of attempts here
	NAttempts = NAttempts_UF
	Integer Attempt
	Attempt = NAttempts
		
	Do While Attempt > 0
	' Exposure variation not working well, will revisit
'	UF_Exposure = Max_UF_Exposure - Attempt * Int((Max_UF_Exposure - Min_UF_Exposure) / (NAttempts))
	UF_Exposure = 0
	Select SITE$
		Case "MSU"
'			VSet MSU_UF_Key.ExposureTime, UF_Exposure
			VRun MSU_UF_Key
			VGet MSU_UF_Key.Geom01.Found, found(1) 'isFoundTR
			VGet MSU_UF_Key.Geom02.Found, found(2) 'isFoundBR
			VGet MSU_UF_Key.Geom03.Found, found(3) 'isFoundBL
			VGet MSU_UF_Key.Geom04.Found, found(4) 'isFoundTL
		Case "TUT"
'			VSet TUT_UF_Key.ExposureTime, UF_Exposure
			VRun TUT_UF_Key
			VGet TUT_UF_Key.Geom01.Found, found(1) 'isFoundTR
			VGet TUT_UF_Key.Geom02.Found, found(2) 'isFoundBR
			VGet TUT_UF_Key.Geom03.Found, found(3) 'isFoundBL
			VGet TUT_UF_Key.Geom04.Found, found(4) 'isFoundTL	
		Default
			Print "INVALID SITE NAME"
			Exit Function
	Send
	
	If found(1) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom01.RobotXYU, isFound(1), ResX(1), ResY(1), ResU(1)
			Case "TUT"
				VGet TUT_UF_Key.Geom01.RobotXYU, isFound(1), ResX(1), ResY(1), ResU(1)
		Send
	Else
		ResX(1) = -9999.
		ResY(1) = -9999.
		ResU(1) = -9999.
	EndIf

	If found(2) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom02.RobotXYU, isFound(2), ResX(2), ResY(2), ResU(2)
			Case "TUT"
				VGet TUT_UF_Key.Geom02.RobotXYU, isFound(2), ResX(2), ResY(2), ResU(2)
		Send
	Else
		ResX(2) = -9999.
		ResY(2) = -9999.
		ResU(2) = -9999.
	EndIf
	
	If found(3) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom03.RobotXYU, isFound(3), ResX(3), ResY(3), ResU(3)
			Case "TUT"
				VGet TUT_UF_Key.Geom03.RobotXYU, isFound(3), ResX(3), ResY(3), ResU(3)
		Send
	Else
		ResX(3) = -9999.
		ResY(3) = -9999.
		ResU(3) = -9999.
	EndIf
	
	If found(4) Then
		Select SITE$
			Case "MSU"
				VGet MSU_UF_Key.Geom04.RobotXYU, isFound(4), ResX(4), ResY(4), ResU(4)
			Case "TUT"
				VGet TUT_UF_Key.Geom04.RobotXYU, isFound(4), ResX(4), ResY(4), ResU(4)
		Send
	Else
		ResX(4) = -9999.
		ResY(4) = -9999.
		ResU(4) = -9999.
	EndIf
	
	' JW: Maybe go back and reorder the vision geometry so it starts at TL not TR
'	If Not ThreeCornerFindDirection(found(4), ResX(4), ResY(4), found(1), ResX(1), ResY(1), found(2), ResX(2), ResY(2), found(3), ResX(3), ResY(3)) Then
	' Flipped fropm above becauser camera is facing up not down at the XY plane
	' TL, TR, BR, BL from above is 
	If CHIPTYPE$ = "COLDATA" Then
		' Set TL to -9999 and not found
		found(1) = False
		ResX(1) = -9999.
		ResY(1) = -9999.
		ResU(1) = -9999.
		If ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			UF_CHIP_FIND = True
			Exit Do
		EndIf
	Else
		If ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			UF_CHIP_FIND = True
			Exit Do
		EndIf
	EndIf
	Attempt = Attempt - 1
	Loop
	
	If Not UF_CHIP_FIND Then
		Print "Could not find chip direction after ", NAttempts, " attempts"
		Exit Function
	Else
'	If UF_CHIP_FIND Then
		Print "Chip found on ", Str$(NAttempts - Attempt + 1), "th attempt at exposure of ", UF_Exposure, " us"
		
		UFChipPos(1) = CornerVar(1)
		UFChipPos(2) = CornerVar(2)
		UFChipPos(3) = GetBoundAnglePM180(CornerVar(3))
	
		Print "Camera position in X = ", CX(P_Camera)
		Print "            Chip AvX = ", UFChipPos(1)
		Print "            Delta  X = ", (UFChipPos(1) - CX(P_Camera))
		Print "Camera position in Y = ", CY(P_Camera)
		Print "            Chip AvY = ", UFChipPos(2)
		Print "            Delta  Y = ", (UFChipPos(2) - CY(P_Camera))
		Print "Orientation of chip at ", UFChipPos(3)
	EndIf
	UF_Exposure = Default_UF_Exposure
Fend

Function FindSocketPositionWithDF As Boolean
''' Wrapper for lwer level chip/socket size specific functions
' Sets global socket position values

	FindSocketPositionWithDF = False
	
	' Can comment this line  out after testing	
	SelectSite("InFunctionDefinePallets")

	NAttempts = NAttempts_Soc
	Min_DF_Exposure = Min_DF_Exposure_Soc
	Max_DF_Exposure = Max_DF_Exposure_Soc
	Print "Min exposure ", Min_DF_Exposure_Soc
	Print "Max exposure ", Max_DF_Exposure_Soc
	Integer Attempt 's, Attempt
	Attempt = NAttempts
	
	Do While (Attempt > 0) 'Or Success
		
		DF_Exposure = Min_DF_Exposure + Attempt * Int((Max_DF_Exposure - Min_DF_Exposure) / (NAttempts))
		Print "Attempt ", Str$(NAttempts - Attempt), " with ExposureTime = ", Str$(DF_Exposure)
		
		Select CHIPTYPE$
			Case "LArASIC"
				FindSocketPositionWithDF = DFFindLArASICSocket
			Case "ColdADC"
				Print "ColdADC not yet implemented, check if LArASIC socket works?"
			Case "COLDATA"
				FindSocketPositionWithDF = DFFindCOLDATASocket
			Default
				Print "Unsupported chip type: ", CHIPTYPE$
		Send
		
		If FindSocketPositionWithDF Then
			Exit Do
		EndIf
		Attempt = Attempt - 1
		
	Loop

	If FindSocketPositionWithDF Then
		Print "Socket found on ", Str$(NAttempts - Attempt + 1), "th attempt at exposure of ", DF_Exposure, " us"
		Print " XYU (", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	Else
		Print "Could not find socket after ", NAttempts, " attempts"
	EndIf
	DF_Exposure = Default_DF_Exposure_Soc
	
Fend

Function DFFindLArASICSocket As Boolean
'''
' Finds LArSIC socket positions and sets global position variables
' Wraps site speicifc vision sequences
'
	Double USocket
	SelectSite("InFunction")
	Print "DFFindLArASICSocket: Exposure = ", DF_Exposure
	Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VSet MSU_SocketFind2.ExposureTime, DF_Exposure
					VRun MSU_SocketFind2
				Else
					VSet MSU_SocketFind.ExposureTime, DF_Exposure
					VRun MSU_SocketFind
				EndIf
			Case "TUT"
				VSet TUT_SocketFind.ExposureTime, DF_Exposure
				VRun TUT_SocketFind
			Default
				Print "Need to set up LArASIC/Socket find vision sequence, Try MSU_SocketFind"
		Send

	
	Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
	Boolean isFound1, isFound2, isFound3, isFound4
	Double xTR, yTR, uTR
	Double xBR, yBR, uBR
	Double xBL, yBL, uBL
	Double xTL, yTL, uTL
	
	Boolean isFoundMTR, isFoundMBR, isFoundMBL, isFoundMTL
	Boolean isFoundM1, isFoundM2, isFoundM3, isFoundM4
	Double xMTR, yMTR, uMTR
	Double xMBR, yMBR, uMBR
	Double xMBL, yMBL, uMBL
	Double xMTL, yMTL, uMTL

	
	Select SITE$
		Case "MSU"
			If MSUTESTBOARD Then
				VGet MSU_SocketFind2.Geom01.Found, isFoundTR
				VGet MSU_SocketFind2.Geom02.Found, isFoundBR
				VGet MSU_SocketFind2.Geom03.Found, isFoundBL
				VGet MSU_SocketFind2.Geom04.Found, isFoundTL
				
			Else
				VGet MSU_SocketFind.Geom01.Found, isFoundTR
				VGet MSU_SocketFind.Geom02.Found, isFoundBR
				VGet MSU_SocketFind.Geom03.Found, isFoundBL
				VGet MSU_SocketFind.Geom04.Found, isFoundTL
				
				VGet MSU_SocketFind.Geom05.Found, isFoundMTR
				VGet MSU_SocketFind.Geom06.Found, isFoundMBR
				VGet MSU_SocketFind.Geom07.Found, isFoundMBL
				VGet MSU_SocketFind.Geom08.Found, isFoundMTL
			EndIf
		Case "TUT"
				VGet TUT_SocketFind.Geom01.Found, isFoundTR
				VGet TUT_SocketFind.Geom02.Found, isFoundBR
				VGet TUT_SocketFind.Geom03.Found, isFoundBL
				VGet TUT_SocketFind.Geom04.Found, isFoundTL
				
				VGet TUT_SocketFind.Geom05.Found, isFoundMTR
				VGet TUT_SocketFind.Geom06.Found, isFoundMBR
				VGet TUT_SocketFind.Geom07.Found, isFoundMBL
				VGet TUT_SocketFind.Geom08.Found, isFoundMTL
		Default

	Send
	
	
	' Require mounting holes to be found 
	
	If Not MSUTESTBOARD And (Not isFoundMTR Or Not isFoundMBR Or Not isFoundMBL Or Not isFoundMTL) Then
'		Print "ERROR: Did not find mounting points for socket"
		Exit Function
	EndIf


	DFFindLArASICSocket = False
	Int32 nFound
	nFound = 0
	If isFoundTR Then
		nFound = nFound + 1
	EndIf
	If isFoundBR Then
		nFound = nFound + 1
	EndIf
	If isFoundBL Then
		nFound = nFound + 1
	EndIf
	If isFoundTL Then
		nFound = nFound + 1
	EndIf

	If nFound <> 3 Then
		Print "ERROR: Should find exactly 3 fiducial marks, found ", nFound
		Exit Function
	EndIf


	If isFoundTL Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				Else
					VGet MSU_SocketFind.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
				EndIf
			Case "TUT"
				VGet TUT_SocketFind.Geom04.RobotXYU, isFound4, xTL, yTL, uTL
		Send
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then

		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				Else
					VGet MSU_SocketFind.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
				EndIf
			Case "TUT"
				VGet TUT_SocketFind.Geom01.RobotXYU, isFound1, xTR, yTR, uTR
		Send

'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				Else
					VGet MSU_SocketFind.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
				EndIf
			Case "TUT"
				VGet TUT_SocketFind.Geom02.RobotXYU, isFound2, xBR, yBR, uBR
		Send
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		Select SITE$
			Case "MSU"
				If MSUTESTBOARD Then
					VGet MSU_SocketFind2.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				Else
					VGet MSU_SocketFind.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
				EndIf
			Case "TUT"
				VGet TUT_SocketFind.Geom03.RobotXYU, isFound3, xBL, yBL, uBL
		Send
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf
	
	Select SITE$
		Case "MSU"
			If Not MSUTESTBOARD Then
				VGet MSU_SocketFind.Geom08.RobotXYU, isFoundM4, xMTL, yMTL, uMTL
				VGet MSU_SocketFind.Geom05.RobotXYU, isFoundM1, xMTR, yMTR, uMTR
				VGet MSU_SocketFind.Geom06.RobotXYU, isFoundM2, xMBR, yMBR, uMBR
				VGet MSU_SocketFind.Geom07.RobotXYU, isFoundM3, xMBL, yMBL, uMBL
			EndIf
		Case "TUT"
			VGet TUT_SocketFind.Geom08.RobotXYU, isFoundM4, xMTL, yMTL, uMTL
			VGet TUT_SocketFind.Geom05.RobotXYU, isFoundM1, xMTR, yMTR, uMTR
			VGet TUT_SocketFind.Geom06.RobotXYU, isFoundM2, xMBR, yMBR, uMBR
			VGet TUT_SocketFind.Geom07.RobotXYU, isFoundM3, xMBL, yMBL, uMBL
	Send
	
	
	Print "isFound TR:", isFoundTR
	Print "isFound BR:", isFoundBR
	Print "isFound BL:", isFoundBL
	Print "isFound TL:", isFoundTL
'	
	' if text upright, missing fiducial marker is top right
	' if CHIP text is upright, missing fiducial is bottom right!




	' orientation in world coordinates is direction of T2->T3 : T23
	' hypotentuse gives larger measurement but relies on isosceles right triangle
	' which is not true at socket fiducial markers 
	' Us av of T1->T2 + 90. and T2->T3

	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		DFFindLArASICSocket = False
		Exit Function
	EndIf
	Print "ThreeCornerFindDirection returns (", CornerVar(1), ",", CornerVar(2), ",", CornerVar(3), ")"
	
	If MSUTESTBOARD Then
		SockPos(1) = CornerVar(1)
		SockPos(2) = CornerVar(2)
		SockPos(3) = GetBoundAnglePM180(CornerVar(3))
		
'		SockPos(1) = SockPos(1) - SocketVisionOffset(1)
'		SockPos(2) = SockPos(2) - SocketVisionOffset(2)
'		SockPos(3) = DiffAnglePM180(SocketVisionOffset(3), SockPos(3))
		DFFindLArASICSocket = True
		Exit Function
	EndIf
	
	' For production sockets use large mounting hole features to confirm center of mezzanine
	' and provide additional positional information for average
	
	Double MXAv, MYAv, DiffX, DiffY
	MXAv = (xMTL + xMTR + xMBL + xMBR) /4
	MYAv = (yMTL + yMTR + yMBL + yMBR) /4
	DiffX = CornerVar(1) - MXAv
	DiffY = CornerVar(2) - MYAv
	
	If Abs(DiffX) > 0.3 Or Abs(DiffY) > 0.3 Then
		DFFindLArASICSocket = False
		Exit Function
	EndIf

	SockPos(1) = (CornerVar(1) + MXAv) / 2
	SockPos(2) = (CornerVar(2) + MYAv) / 2
	SockPos(3) = GetBoundAnglePM180(CornerVar(3) + 180.)
	
'	SockPos(1) = SockPos(1) - SocketVisionOffset(1)
'	SockPos(2) = SockPos(2) - SocketVisionOffset(2)
'	SockPos(3) = DiffAnglePM180(SocketVisionOffset(3), SockPos(3))

'	Print "Position found with fiducial points"
'	Print "(", CornerVar(1), ",", CornerVar(2), ",", CornerVar(3), ")"
'	Print "Position found with mounting points"
'	Print "(", MXAv, ",", MYAv, ")"
'	Print "Difference "
'	Print "  DelX: ", Str$(CornerVar(1) - MXAv)
'	Print "  DelY: ", Str$(CornerVar(2) - MYAv)
'	
'	Print "Final position"
'	Print "(", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	DFFindLArASICSocket = True

Fend

Function DFFindCOLDATASocket As Boolean
		
	Select SITE$
		Case "MSU"
			VSet MSU_SocketFindL.ExposureTime, DF_Exposure
			VRun MSU_SocketFindL
					
			' Mounting points, should have found all of these
			Boolean isFound1, isFound2, isFound3, isFound4
			Double xMTR, yMTR, uMTR
			Double xMBR, yMBR, uMBR
			Double xMBL, yMBL, uMBL
			Double xMTL, yMTL, uMTL

			VGet MSU_SocketFindL.Geom01.RobotXYU, isFound1, xMTR, yMTR, uMTR
			VGet MSU_SocketFindL.Geom02.RobotXYU, isFound2, xMBR, yMBR, uMBR
			VGet MSU_SocketFindL.Geom03.RobotXYU, isFound3, xMBL, yMBL, uMBL
			VGet MSU_SocketFindL.Geom04.RobotXYU, isFound4, xMTL, yMTL, uMTL
			
			If Not isFound1 Or Not isFound2 Or Not isFound3 Or Not isFound4 Then
				DFFindCOLDATASocket = False
				Exit Function
			EndIf

			' Fiducial markers, should find exactly three of these
			Boolean isFoundTR, isFoundBR, isFoundBL, isFoundTL
			Boolean isFound5, isFound6, isFound7, isFound8
			Double xTR, yTR, uTR
			Double xBR, yBR, uBR
			Double xBL, yBL, uBL
			Double xTL, yTL, uTL

			VGet MSU_SocketFindL.Geom05.Found, isFoundTR
			VGet MSU_SocketFindL.Geom06.Found, isFoundBR
			VGet MSU_SocketFindL.Geom07.Found, isFoundBL
			VGet MSU_SocketFindL.Geom08.Found, isFoundTL
		Default
			
	Send
	
	DFFindCOLDATASocket = False
	Int32 nFound
	nFound = 0
	If isFoundTR Then
		nFound = nFound + 1
	EndIf
	If isFoundBR Then
		nFound = nFound + 1
	EndIf
	If isFoundBL Then
		nFound = nFound + 1
	EndIf
	If isFoundTL Then
		nFound = nFound + 1
	EndIf

	If nFound <> 3 Then
		Print "ERROR: Should find exactly 3 fiducial marks, found ", nFound
		Exit Function
	EndIf

	If isFoundTL Then
		VGet MSU_SocketFindL.Geom08.RobotXYU, isFound4, xTL, yTL, uTL
'		Print "TL : x=", xTL, ", y=", yTL
	Else
		xTL = -9999.
		yTL = -9999.
	EndIf
	
	If isFoundTR Then
		VGet MSU_SocketFindL.Geom05.RobotXYU, isFound1, xTR, yTR, uTR
'		Print "TR : x=", xTR, ", y=", yTR		
	Else
		xTR = -9999.
		yTR = -9999.
	EndIf

	If isFoundBR Then
		VGet MSU_SocketFindL.Geom06.RobotXYU, isFound2, xBR, yBR, uBR
'		Print "BR : x=", xBR, ", y=", yBR
	Else
		xBR = -9999.
		yBR = -9999.
	EndIf

	If isFoundBL Then
		VGet MSU_SocketFindL.Geom07.RobotXYU, isFound3, xBL, yBL, uBL
'		Print "BL : x=", xBL, ", y=", yBL
	Else
		xBL = -9999.
		yBL = -9999.
	EndIf


	If Not ThreeCornerFindDirection(isFoundTL, xTL, yTL, isFoundTR, xTR, yTR, isFoundBR, xBR, yBR, isFoundBL, xBL, yBL) Then
		DFFindCOLDATASocket = False
		Exit Function
	EndIf
	
	' Check consistency with four mounting points	
	Double AvMX, AvMY
	AvMX = (xMTR + xMBR + xMBL + xMTL) /4
	AvMY = (yMTR + yMBR + yMBL + yMTL) /4
	
	If Abs(Sqr((CornerVar(1) - AvMX) * (CornerVar(1) - AvMX) + (CornerVar(2) - AvMY) * (CornerVar(2) - AvMY))) > TolXY Then
		Print "Corner mounting point average and fiducial method socket positions are inconsistent"
		Print
		DFFindCOLDATASocket = False
		Exit Function
	EndIf
	
	SockPos(1) = CornerVar(1)
	SockPos(2) = CornerVar(2)
	SockPos(3) = GetBoundAnglePM180(CornerVar(3) + 180)
	
'	SockPos(1) = SockPos(1) - SocketVisionOffset(1)
'	SockPos(2) = SockPos(2) - SocketVisionOffset(2)
'	SockPos(3) = DiffAnglePM180(SocketVisionOffset(3), SockPos(3))

	DFFindCOLDATASocket = True
	
Fend

Function GetChipInSocketAlignment(DAT_nr As Integer, socket_nr As Integer) As Int32
''' For diagnostic check of chip placement, requires finer position measurement functions
' Note, relies on consistent lighting which may not be currently achievable without
' addition EOAT lighting

	GetChipInSocketAlignment = 0
	SubError = -1
	SelectSite("InFunctionDefinePallets")
	Print "GetChipInSocketAlignment(", DAT_nr, ",", socket_nr, ")"
	
	SetSpeedSetting("PickAndPlace")
	Print "Making initial socket position measurement"
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	' Measure the socket position	
	If Not GetSocketPositionWithDF(DAT_nr, socket_nr) Then ', ByRef SockCorr()) Then
		'RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN)
		GetChipInSocketAlignment = -ERR_V_SOCKETALIGN
		Exit Function
	EndIf
	' Check corrections are small		
	If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
		GetChipInSocketAlignment = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	
	Print "Correcting for socket drift : (", SocketOffset(1), ",", SocketOffset(2), ",", SocketOffset(3), ")"
	JumpToSocket_camera(DAT_nr, socket_nr)
	Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
	
	' Socket positions are stored in SockPos(3) 	
	
'	' Remeasure the socket position after recentering?
'	'''
	Print "Measuring socket position (after recentering)"
	If Not GetSocketPositionWithDF(DAT_nr, Socket_nr) Then ', ByRef SockCorr()) Then
		'RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN)
		GetChipInSocketAlignment = -ERR_V_SOCKETALIGN
		Exit Function
	EndIf
'	' Check corrections are small	
'	
	If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
		GetChipInSocketAlignment = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	Print "Socket position XYU = (", SockPos(1), ", ", SockPos(2), ",", SockPos(3), ")"
'	' Don't correct this time, just want to have more centered measurement 
	'''
	Print "Measuring chip position"
	' Measure the chip position
'	If Not FindChipPositionWithDF Then
'		Print "Could not find with standard vision sequence, will use component sequences separately"
'		If Not FindChipPositionWithDFAdvanced Then
'			'RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN)
'			GetChipInSocketAlignment = -ERR_V_DF_ALIGN ' Set an error code
'			Exit Function
'		EndIf
'	EndIf

	If Not GetChipPositionWithDF(0) Then
		'RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN)
		GetChipInSocketAlignment = -ERR_V_DF_ALIGN ' Set an error code
		Exit Function
	EndIf
	
	' More movement in chips than sockets so wider tolerance 
	If Abs(ChipOffset(1)) > 2. Or Abs(ChipOffset(2)) > 2. Or Abs(ChipOffset(3)) > 5. Then
		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
		GetChipInSocketAlignment = -ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	
	' Chip positions are stored in ChipPos(3)
	Print "Chip position XYU = (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	' Store for logging
	CSAlign(1) = ChipPos(1) - SockPos(1)
	CSAlign(2) = ChipPos(2) - SockPos(2)
	CSAlign(3) = DiffAnglePM180(SockPos(3), ChipPos(3))
	' Calculate x and y offset after removing socket rotation
	' Rotate by (- socket offset U)?
	CSAlign(4) = CSAlign(1) * Cos(DegToRad(-SocketOffset(3))) - CSAlign(2) * Sin(DegToRad(-SocketOffset(3)))
	CSAlign(5) = CSAlign(1) * Sin(DegToRad(-SocketOffset(3))) + CSAlign(2) * Cos(DegToRad(-SocketOffset(3)))
	
	Print "Chip in socket alignment check results"
	Print "Chip-Socket delta calculated at "
	Print "Delta X (uncorrected) : ", CSAlign(1)
	Print "Delta Y (uncorrected) : ", CSAlign(2)
	Print "Delta X (U corrected) : ", CSAlign(4)
	Print "Delta Y (U corrected) : ", CSAlign(5)
	Print "Delta U             : ", CSAlign(3)
	
	' Need to think about where these get set back to zero 	
	
	SetSpeedSetting("MoveWithoutChip")
	GetChipInSocketAlignment = -1
	
	LogChipSocketAlignment(DAT_nr, socket_nr)
	
Fend

Function GetSocketPositionWithDF(DAT_nr As Integer, Socket_nr As Integer) As Int64
' Gets the position and offsets of the socket from the taught point
' Relies on lower level vision sequence handling functions
' wrapped by FindSocketPositionWithDF

	GetSocketPositionWithDF = 0
	
	SelectSite("InFuntionDefinePallets")
	
	SocketOffset(1) = 0.
	SocketOffset(2) = 0.
	SocketOffset(3) = 0.
	
	SetSpeedSetting("PickAndPlace")
	JumpToSocket_camera(DAT_nr, Socket_nr)
		
	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + Socket_nr

	If Not FindSocketPositionWithDF Then
		Print "ERROR: Cannot find socket alignment"
		GetSocketPositionWithDF = False
		Exit Function
	EndIf
		
	Print "Expected socket position (", CX(P(FullSocket_nr)), ",", CY(P(FullSocket_nr)), ",", GetBoundAnglePM180(CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR)), ")"
	Print "Measured socket position (", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	Print "Subtracting vision offsets of (", SocketVisionOffset(1), ",", SocketVisionOffset(2), ",", SocketVisionOffset(3), ")"

	' Apply fine tuning offset correction for vision sequence function
	SockPos(1) = SockPos(1) - SocketVisionOffset(1)
	SockPos(2) = SockPos(2) - SocketVisionOffset(2)
	SockPos(3) = DiffAnglePM180(SocketVisionOffset(3), SockPos(3))
	Print "Corrected measured socket position (", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	SocketOffset(1) = SockPos(1) - CX(P(FullSocket_nr))
	SocketOffset(2) = SockPos(2) - CY(P(FullSocket_nr))
	SocketOffset(3) = DiffAnglePM180((CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR)), (SockPos(3))) ' Should this be a socket vision offset? Depends  how vision is taught
	
	' Check offsets are small
	If Abs(SocketOffset(1)) > 1. Or Abs(SocketOffset(2)) > 1. Or Abs(SocketOffset(3)) > 3. Then
		Print "ERROR Socket offsets too large"
		Exit Function
	EndIf
	
	GetSocketPositionWithDF = -1
	
Fend

Function GetChipPositionWithDF(sequence As Int32) As Int64
	
	GetChipPositionWithDF = 0
	
	SelectSite("InFuntionDefinePallets")
	
	ChipOffset(1) = 0.
	ChipOffset(2) = 0.
	ChipOffset(3) = 0.

	Boolean measured
	measured = False
	Int32 seq
	seq = 0
	If (Not measured) And (sequence = 0 Or 1) Then
		measured = FindChipPositionWithDF
		seq = 1
	EndIf
	
	If (Not measured) And (sequence = 0 Or 2) Then
		measured = FindChipPositionWithDFAdvanced
		seq = 2
	EndIf
	
	If (Not measured) And (sequence = 0 Or 3) Then
		measured = FindChipPositionWithDFFromOutline
		seq = 3
	EndIf
	
	If Not measured Then
		Print "ERROR: Cannot find chip position"
		GetChipPositionWithDF = -ERR_VISION
		Exit Function
	EndIf
		
	Double PointX, PointY, PointZ, DelX, DelY, DelU
	PointX = CX(Here) - XOffset(CU(Here))
	PointY = CY(Here) - YOffset(CU(Here))
	PointZ = CZ(Here) - DF_CAM_Z_OFF
	DelX = ChipPos(1) - PointX
	DelY = ChipPos(2) - PointY
	DelU = GetBoundAnglePM45(DiffAnglePM180(CU(Here), ChipPos(3)))
	
	Print "Expected chip position (rounded U PM45) (", PointX, ",", PointY, ",", GetBoundAnglePM45(CU(Here)), ")"
	Print "Measured chip position  (rounded U PM45) (", ChipPos(1), ",", ChipPos(2), ",", GetBoundAnglePM45(ChipPos(3)), ")"
	Print "Subtracting vision offsets of (", ChipVisionOffset(seq, 1), ",", ChipVisionOffset(seq, 2), ",", ChipVisionOffset(seq, 3), ")"

	' Apply fine tuning offset correction for vision sequence function
	ChipPos(1) = ChipPos(1) - ChipVisionOffset(seq, 1)
	ChipPos(2) = ChipPos(2) - ChipVisionOffset(seq, 2)
	ChipPos(3) = DiffAnglePM180(ChipVisionOffset(seq, 3), ChipPos(3))
	Print "Corrected measured chip position (", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	
	ChipOffset(1) = ChipPos(1) - PointX
	ChipOffset(2) = ChipPos(2) - PointY
	ChipOffset(3) = DiffAnglePM180(GetBoundAnglePM45(CU(Here)), GetBoundAnglePM45(ChipPos(3))) ' Should this be a socket vision offset? Depends  how vision is taught
	
	' Check offsets are small
	If Abs(ChipOffset(1)) > 1.2 Or Abs(ChipOffset(2)) > 1.2 Or Abs(ChipOffset(3)) > 3. Then
		Print "ERROR chip offsets too large"
		GetChipPositionWithDF = -ERR_V_DF_ALIGN
		Exit Function
	EndIf
	
	GetChipPositionWithDF = -1
	
Fend

Function FindChipAxisOffsetWithUF As Boolean
''' Finds the offset of the chip center and direction	
' from the axis of the robot EOAT.
' This is used to precisely calculate position corrections
' between chips
	
	FindChipAxisOffsetWithUF = False
		
	Double MeasU0, MeasU1, MeasU2
	
	Double ChipX1, ChipY1, ChipU1
	Double ChipX2, ChipY2, ChipU2

	JumpToCamera
	SetSpeedSetting("AboveCamera")
	
	Go Here :U(HAND_U0)
	Go Here +U(PickOffset)

	MeasU0 = CU(Here)
	
	' If J4 angle is outside desired range, first add in extra rotation to prevent over turning
	Double Rotation1
	Rotation1 = 0.
	If (Agl(4) >= (REST_J4 - 45.)) And (Agl(4) <= (REST_J4 - 45.)) Then
		If (Agl(4) >= REST_J4) Then
			Rotation1 = -90.
		Else
			Rotation1 = 90.
		EndIf
	EndIf
	Go Here +U(Rotation1)
	
	MeasU1 = CU(Here)

	If CurrentOperation$ <> "" Then
		LogTestMeasurements(CurrentOperation$, "UFC1", 0, 0, 0, "DEFINED_POINT", CX(Here), CY(Here), CU(Here))
	EndIf
	
	'' TAKE PICTURE
	UF_camera_light_ON
	Wait 0.2
	String pict_fname$
	If CurrentOperation$ <> "" Then
		pict_fname$ = UF_take_picture$(CurrentOperation$ + "_01")
		WriteMLog(pict_fname$)
	EndIf
'    ' Print #fileNum, ",", pict_fname$,
'	Images$(1) = UF_take_picture$(id$ + "_01")
'	' Take first measurements

	If Not UF_CHIP_FIND Then
		Print "ERROR UF camera cannot find chip"
		WriteMLog(Str$(False))
		Exit Function
	EndIf
	
	' Store first measurement values
	ChipX1 = UFChipPos(1)
	ChipY1 = UFChipPos(2)
	ChipU1 = UFChipPos(3)

	If CurrentOperation$ <> "" Then
		LogTestMeasurements(CurrentOperation$, "UFC1", 0, 0, 0, "CHIP_MEASURED", ChipX1, ChipY1, ChipU1)
	EndIf


	''' NOTE: BNL robot code assumes U is fixed and then later checks at the orientation to 
	'' be inserted into the sockets, so I will add in CU(here) as U at camera for this measurement 
	'String mmsg$
'	mmsg$ = Str$(True) + "," + Str$(CX(Here)) + "," + Str$(CY(Here)) + "," + Str$(CU(Here)) + "," + Str$(ChipX1) + "," + Str$(ChipY1) + "," + Str$(ChipU1)
	WriteMLog(Str$(True) + "," + Str$(CX(Here)) + "," + Str$(CY(Here)) + "," + Str$(CU(Here)) + "," + Str$(ChipX1) + "," + Str$(ChipY1) + "," + Str$(ChipU1))
	
	If CHIPTYPE$ = "COLDATA" Then
		ChipU1 = GetBoundAnglePM45(ChipU1)
	EndIf
	
	' Rotate to 180 deg from first measurements
	Double Rotation2
	Rotation2 = 0.
	If (Agl(4) < REST_J4) Then
		Rotation2 = 180.
	Else
		Rotation2 = -180
	EndIf
	Go Here +U(Rotation2)
	
	MeasU2 = CU(Here)
	
	If CurrentOperation$ <> "" Then
		LogTestMeasurements(CurrentOperation$, "UFC2", 0, 0, 0, "DEFINED_POINT", CX(Here), CY(Here), CU(Here))
	EndIf
	
	' Take another picture
	UF_camera_light_ON
	Wait 0.2
'	Images$(2) = UF_take_picture$(id$ + "_02")
	'pict_fname$ = UF_take_picture$(id$ + "_02")
    'Print #fileNum, ",", pict_fname$,
    
    If CurrentOperation$ <> "" Then
		pict_fname$ = UF_take_picture$(CurrentOperation$ + "_02")
		WriteMLog(pict_fname$)
	EndIf
	
	If Not UF_CHIP_FIND Then
		Print "ERROR UF camera cannot find chip on second measurement"
		WriteMLog(Str$(False))
		Exit Function
	EndIf
	
	' Store second measurement values
	ChipX2 = UFChipPos(1)
	ChipY2 = UFChipPos(2)
	ChipU2 = UFChipPos(3)
	
	If CurrentOperation$ <> "" Then
		LogTestMeasurements(CurrentOperation$, "UFC2", 0, 0, 0, "CHIP_MEASURED", ChipX2, ChipY2, ChipU2)
	EndIf

	''' Here we assume camera is at same x and Y and +/- 180 from measurement 1  
	'mmsg$ = Str$(True) + "," + Str$(ChipX2) + "," + Str$(ChipY2) + "," + Str$(ChipU2)
	WriteMLog(Str$(True) + "," + Str$(ChipX2) + "," + Str$(ChipY2) + "," + Str$(ChipU2))
	Double toolX, toolY
	toolX = 0.5 * (ChipX1 + ChipX2)
	toolY = 0.5 * (ChipY1 + ChipY2)
	'mmsg$ = Str$(toolX) + "," + Str$(toolY)
	WriteMLog(Str$(toolX) + "," + Str$(toolY))
		
	If CHIPTYPE$ = "COLDATA" Then
		ChipU2 = GetBoundAnglePM180(GetBoundAnglePM45(ChipU2) + 180.)
	EndIf

	' Measurements have been made, return to initial U at camera
	' This should be same as U_0
	Go Here -U(Rotation1 + Rotation2)
	
	If (Abs(ChipX1 - CX(P_camera)) > 10) Or (Abs(ChipX2 - CX(P_camera)) > 10) Then
		Print "ERROR: Position measured is more than 10 mm from P_camera in X"
		Exit Function
	EndIf
	
	If (Abs(ChipY1 - CY(P_camera)) > 10) Or (Abs(ChipY2 - CY(P_camera)) > 10) Then
		Print "ERROR: Position measured is more than 10 mm from P_camera in Y"
		Exit Function
	EndIf
	
	' Need intermediate variables for matrix multiplication (i.e. to get Y without having already changed X)
	Double tmpx, tmpy
	' Set X and Y offsets as distance from axis of rotation to first measurement
	tmpx = (ChipX1 - ChipX2) /2 ' X1 - X2 /2
	tmpy = (ChipY1 - ChipY2) /2 ' Y1 - Y2 /2

	' In BNL doesn't seem to be acorrection back to 0 or any rotation of angles, they just 
	' Take another set of measurements at the target (Global) hand rotation (i.e. U at socket, not Agl(4))
	'mmsg$ = Str$(tmpx) + "," + Str$(tmpy)
	WriteMLog(Str$(tmpx) + "," + Str$(tmpy))

	' Wrt U = 0

	CurrentChipOffset(1) = tmpx * Cos(DegToRad(-MeasU1)) - tmpx * Sin(DegToRad(-MeasU1))
	CurrentChipOffset(2) = tmpx * Sin(DegToRad(-MeasU1)) + tmpy * Cos(DegToRad(-MeasU1))


	Double UF_DEL_U1, UF_DEL_U2

	
	' DIff angle (a, b) is b - a
	UF_DEL_U1 = DiffAnglePM180(MeasU1, ChipU1)
	UF_DEL_U2 = DiffAnglePM180(MeasU2, ChipU2)
	
	If CHIPTYPE$ = "COLDATA" Then
		UF_DEL_U1 = GetBoundAnglePM45(UF_DEL_U1)
		UF_DEL_U2 = GetBoundAnglePM45(UF_DEL_U2)
	EndIf
	
	If Abs(UF_DEL_U2 - UF_DEL_U1) > 2. Then
		Print "WARNING: U offsets from UF measurements differ by more than +/- 2 deg"
		Print " 1st U offset = ", UF_DEL_U1
		Print " 2nd U offset = ", UF_DEL_U2
	EndIf
	
'	' Need to make sure average is closest angle around -pi/+pi boundary
	CurrentChipOffset(3) = AverageAnglePM180(UF_DEL_U1, UF_DEL_U2) 'GetBoundAnglePM45(AverageAnglePM180(UF_DEL_U1, UF_DEL_U2))
	
	' Not going to rotate and take more picturs, just store offsets as calculated for now
	' Maybe go in and add this as an option for double checking/diagnostics
	WriteMLog(Str$(CurrentChipOffset(1)) + "," + Str$(CurrentChipOffset(2)) + "," + Str$(CurrentChipOffset(3)))
	
	Print "Offset of chip from rotational axis wrt U = 0 " ' HAND_U0"
	Print "Offsets measured from a rotation of ", Rotation1
	Print "Offset in x axis : ", CurrentChipOffset(1)
	Print "Offset in y axis : ", CurrentChipOffset(2)
	Print "Offset in u1   	: ", UF_DEL_U1
	Print "Offset in u2   	: ", UF_DEL_U2
	Print "Offset in u   	: ", CurrentChipOffset(3)

	FindChipAxisOffsetWithUF = True
    SetSpeedSetting("MoveWithChip")
	
Fend

Function GetChipToChipCorrections(C1X As Double, C1Y As Double, C1U As Double, C2X As Double, C2Y As Double, C2U As Double, TargetHandU As Double)
' Takes measured alignments to U = 0 (Old wrt HAND_U0) and a target U and calculates corrections
' which move first chip into same offset position as second chip.
' Used to place currently held chip at same precise offset as previous chip picked from target position
' C1 -> C2
	
	' Note, the offsets calculated by UFGetChipAlignment were PREVIOUSLY (Before 2025-09-04) ChipPosition -> RotationalAxis
	' Now UFGetChipAlignmemt returns offset of chip from axis which can be subtracted to get the correction for an individual measurement
	' This function takes two sets of offsets and uses them to go from C1->C2, where the offsets are	
	' measured as C1 - Axis, not the other way around
	
	Print "Calculating chip-to-chip correction from offset measurements (going from first measurement args to second)"
	Print "Targeting hand U of :", TargetHandU
	
	Double CorrX, CorrY
	
	ChipToChipCorrection(3) = DiffAnglePM180(C1U, C2U) 'C2U - C1U ' Corr(3) = DiffAnglePM180(C1U, C2U) ' Not sure this is working
	Print "Moving C1 to C2' by rotating offsets by ", ChipToChipCorrection(3)

	
	' Rotate C1 corrections by phi around axis of rotation
	' Then get difference to C2 wrt axis
	' Needs intermediate variable to change X before changing Y
	CorrX = C2X - (C1X * Cos(DegToRad(ChipToChipCorrection(3))) - C1Y * Sin(DegToRad(ChipToChipCorrection(3))))
	CorrY = C2Y - (C1X * Sin(DegToRad(ChipToChipCorrection(3))) + C1Y * Cos(DegToRad(ChipToChipCorrection(3))))
	
	ChipToChipCorrection(1) = CorrX * Cos(DegToRad(TargetHandU)) - CorrY * Sin(DegToRad(TargetHandU))
	ChipToChipCorrection(2) = CorrX * Sin(DegToRad(TargetHandU)) + CorrY * Cos(DegToRad(TargetHandU))
	
	Print "Offset X1 :", C1X
	Print "Offset X1':", ((C1X * Cos(DegToRad(ChipToChipCorrection(3))) - C1Y * Sin(DegToRad(ChipToChipCorrection(3)))))
	Print "Offset X2 :", C2X
	Print "Correction:", ChipToChipCorrection(1)
	
	Print "Offset Y1 :", C1Y
	Print "Offset Y1':", ((C1X * Sin(DegToRad(ChipToChipCorrection(3))) + C1Y * Cos(DegToRad(ChipToChipCorrection(3)))))
	Print "Offset Y2 :", C2Y
	Print "Correction:", ChipToChipCorrection(2)
	
	Print "Offset U1 :", C1U
	Print "Offset U2 :", C2U
	Print "Correction:", ChipToChipCorrection(3)
	'Print "Only actually apply small offsets, orientation handling is done outsite this function"
	' May not want this, but rather corrected chip axis offset keeps fixed angle offset only rotates X Y off. See
	' CorrectChipAxisOffset...
	'ChipToChipCorrection(3) = GetBoundAnglePM45(ChipToChipCorrection(3))
	Print "Bound pm45deg Correction:", ChipToChipCorrection(3)

Fend

Function CorrectChipAxisOffsetForPickupOrientation(Actual As Double, Expected As Double)
''' If chip is picked up in a different orientation to expected, may need to account for                                                                                                                                                                                                      
' this between tray and socket offset measurements or between successive tray position offsets                                                                                                                                                                                                
' as X and Y offsets are U dependent.                                                                                                                                                                                                                                                         
	
        Double OrientationOffset
        OrientationOffset = DiffAnglePM180(Expected, Actual) 'GetBoundAnglePM180(Actual - Expected) ' Expected - Measured? but bound by 180 degrees                                                                                                                                                                                                                     
	
		' Don't want to correct "current" offset here, and it would interfere with Y correction if X gets directly corrected in first line below
        CorrectedChipOffset(1) = CurrentChipOffset(1) * Cos(DegToRad(OrientationOffset)) - CurrentChipOffset(2) * Sin(DegToRad(OrientationOffset))
        CorrectedChipOffset(2) = CurrentChipOffset(1) * Sin(DegToRad(OrientationOffset)) + CurrentChipOffset(2) * Cos(DegToRad(OrientationOffset))

        ' Want to keep U offset the same as current, as you have already picked up at correct hand chip orientation
        CorrectedChipOffset(3) = CurrentChipOffset(3)
        
Fend

''''' FNAL FUNCTIONS ''''''

Function COLDATA_VisAnalysis(ByRef corrections() As Double) As Integer
	' Uses the upward facing camera to find the offset of the EOAT center of rotation
	' and the chip center. Assumes the EOAT is currently holding a chip, it uses COLDATA_Corrs
	' to find the chip center, then rotates it 180 degrees at runs it again. The difference
	' in the center positions results in the offset of the EOAT center and chip center.
	
	Print "COLDATA_VisAnalysis start: ", Here
	
	' Turn the EOAT light on for better pictures of chip	
	On 12
	
	' Run the vision sequence to find the chip center
	VRun COLDATA_Corrs
	
	' Save the initial center position of the chip
	Double X_0, Y_0, U_0
	VGet COLDATA_Corrs.FindChip.CameraX, X_0
	VGet COLDATA_Corrs.FindChip.CameraY, Y_0
	VGet COLDATA_Corrs.FindChip.Angle, U_0
	
	Print "X, Y, U: ", X_0, Y_0, U_0
	
	' Rotate 180 degrees
	Go Here +U(180)
	
	' Fine the new center of the chip after rotation
	VRun COLDATA_Corrs
	
	' Save the new center position of the chip after rotation
	Double X_180, Y_180, U_180
	VGet COLDATA_Corrs.FindChip.CameraX, X_180
	VGet COLDATA_Corrs.FindChip.CameraY, Y_180
	VGet COLDATA_Corrs.FindChip.Angle, U_180
	
	Print "X2, Y2, U2: ", X_180, Y_180, U_180
	
	' Calculate the center of the tool (EAOT)
	Double X_tool, Y_tool
	X_tool = 0.5 * (X_0 + X_180)
	Y_tool = 0.5 * (Y_0 + Y_180)
	
	' Calculate the correction to center the chip
	Double X_COR, Y_COR
	X_COR = 0.5 * (X_0 - X_180)
	Y_COR = 0.5 * (Y_0 - Y_180)
	Print "X_COR, YCOR: ", X_COR, Y_COR
	
	' Rotate back to initial position
	Go Here -U(180)
	
	' Turn the light off
	Off 12
	
	' Save corrections
	corrections(1) = X_COR
	corrections(2) = Y_COR
	'corrections(3) = 0 'U_COR
	
Fend

Function UFRecenter As Int32
'''' Function to recenter a chip based on the offsets from the image center calculated using the UF camera
'' This is used to then do any pin analysis with the pins aligned with the right search boxes

	SelectSite("InFunctionDefinePallets")
	LoadCurrentChipOffset
	UFRecenter = 0
	JumpToCamera
	Double CorX1, CorY1 ' , CorU1
	'Go Here :U(HAND_U0 + HandChipOrientation(CHIPTYPE_NR) - CurrentChipOffset(3))
	Go Here :U(DiffAnglePM180(CurrentChipOffset(3), HandChipOrientation(CHIPTYPE_NR)))
	CorX1 = CurrentChipOffset(1) * Cos(DegToRad(CU(Here))) - CurrentChipOffset(2) * Sin(DegToRad(CU(Here)))
	CorY1 = CurrentChipOffset(1) * Sin(DegToRad(CU(Here))) + CurrentChipOffset(2) * Cos(DegToRad(CU(Here)))
	Go Here :X(CX(P_Camera) - CorX1) :Y(CY(P_Camera) - CorY1)
	' Or Go Here  -X(CorX1) -Y(CorY1) :U(DiffAnglePM180(CurrentChipOffset(3), CU(Here)))
	UFRecenter = -1
Fend

' For P_Camera +U(180)
Function UFRecenterAt180 As Int32
''' Centers a chip as UFRecenter would but at a 180 degree rotation
	SelectSite("InFunctionDefinePallets")
	LoadCurrentChipOffset
	UFRecenterAt180 = 0
	JumpToCamera
	Double CorX1, CorY1 ' , CorU1
	'Go Here :U(HAND_U0 + HandChipOrientation(CHIPTYPE_NR) - CurrentChipOffset(3))
	Go P_Camera :U(DiffAnglePM180(CurrentChipOffset(3), HandChipOrientation(CHIPTYPE_NR) + 180.))
	'Go Here :U(DiffAnglePM180(CurrentChipOffset(3), HandChipOrientation(CHIPTYPE_NR)))
	CorX1 = CurrentChipOffset(1) * Cos(DegToRad(CU(Here))) - CurrentChipOffset(2) * Sin(DegToRad(CU(Here)))
	CorY1 = CurrentChipOffset(1) * Sin(DegToRad(CU(Here))) + CurrentChipOffset(2) * Cos(DegToRad(CU(Here)))
	Go Here :X(CX(P_Camera) - CorX1) :Y(CY(P_Camera) - CorY1)
	' Or Go Here  -X(CorX1) -Y(CorY1) :U(DiffAnglePM180(CurrentChipOffset(3), CU(Here)))
	UFRecenterAt180 = -1
Fend

'
'Function PrecisionSocketMeasurement(DAT As Integer, socket_nr As Integer)
'	
'	JumpToSocket_camera(DAT, socket_nr)
'	
'	
'	
'	
'Fend

