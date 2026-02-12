#include "RTS_tools.inc"
#include "ErrorDictionary.inc"



''' Analyses row of pins and checks equidistant spacing for bent pins/dust
Function PinsRowAnaly(name$ As String, fileNum As Integer) As Integer
	
	PinsRowAnaly = 0
	
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
Function PinsAnaly(id$ As String) As Integer
	
	PinsAnaly = 0
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\pins\" + id$ + "_pins.csv" As #fileNum
		
	Select SITE$
		Case "BNL"
			VRun pins_analy
		Case "MSU"
			VRun MSU_ChipAnal
		Case "TUT"
			VRun TUT_ChipAnal
		Default
			Print "Need to set up pin analysis for your site"
			PinsAnaly = -100
			Close #fileNum
	Send

	Integer status
	status = PinsRowAnaly("BlobTop", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf
	
	status = PinsRowAnaly("BlobBottom", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	status = PinsRowAnaly("BlobLeft", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	status = PinsRowAnaly("BlobRight", fileNum)
	If status <> 0 Then
		PinsAnaly = status
	EndIf

	Close #fileNum
	
Fend

Function calibrate_socket(DAT_nr As Integer, socket_nr As Integer)
	Print
	Print socket_nr, "**********************************************"
	
	
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	'Add error: x:  0.888672y:  -0.798645
	'Go Here +X(0.888672)
	'Go Here +Y(-0.798645)
	
	'Add a position fluctuation for test, only for test!!!	
	
	'Real r_x
  	'Randomize
  	'r_x = Rnd(2) - 1
  	
  	'Real r_y
    'Randomize
    'r_y = Rnd(2) - 1
  	
  	'Go Here +X(r_x)
  	'Go Here +Y(r_x)
  	'Print "Add error: x: ", r_x, "y: ", r_y
  	
  	'random end ********************************************************

	
	VRun skt_cali_test
	'Integer nP
	'VGet skt_cali_test.Geom01.NumberFound, nP
	'Print "number of point found: ", nP
	
	Boolean Isfound1, Isfound2, Isfound3
	Boolean found
	'VGet skt_cali_test.Geom01.Found, Isfound1
	'VGet skt_cali_test.Geom02.Found, Isfound2
	'VGet skt_cali_test.Geom03.Found, Isfound3
	
	Double x_p1, y_p1, a_p1, x_p2, y_p2, a_p2, x_p3, y_p3, a_p3
	Double x_ori, y_ori, a_ori
	
	'VGet skt_cali_test.CameraCenter.RobotXYU, found, x_ori, y_ori, a_ori
	Double check
	check = 100
	Integer N_round
	N_round = 0
	
	Do Until check < 20 And check > -20 Or N_round > 10
		VRun skt_cali_test
		VGet skt_cali_test.Geom01.RobotXYU, Isfound1, x_p1, y_p1, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, Isfound2, x_p2, y_p2, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, Isfound3, x_p3, y_p3, a_p3
		'Print "P3 xyu: ", x_p3, y_p3, a_p3
	

		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
	EndIf
	
	
	Double x_c, y_c
	
	x_c = (x_p1 + x_p3) /2
	y_c = (y_p1 + y_p3) /2
	'Print "HERE: ", Here
	'Print "ori_center: ", x_ori, y_ori
	Print "corr_center: ", x_c, y_c
	'Print P(20 + socket_nr) :Z(-132.5)
	
	'Double A_line
	
	'VGet skt_cali_test.LineFind01.Angle, A_line
	'Print A_line
	
	
Fend




''' Runs the pin analysis code
' Note, this does not find the position, which is found by the UFGetChipAligment() function
' this checks for uniform pin position/spacing using the PinsAnaly() function
Function UFPinAnalysis(id$ As String, ByRef Images$() As String) As Int32
	UpdateRobotLog$("Running pin analysis")
	UFPinAnalysis = 0
	'Integer fileNum
	'fileNum = idx(1)
	'String pict_fname$
	Images$(1) = UF_take_picture$(id$ + "_pins")
	'Print #fileNum, ",", pict_fname$,
	'VSet pins_analy.ImageFile, pict_fname$
	
	Integer status
	status = PinsAnaly(id$)
	' Print #fileNum, ",", status,
	If status <> 0 Then
		UFPinAnalysis = status
	EndIf
	
	' Images(2) and (3) are for COLDATA extra images after shifting side to side
	
Fend


'''' Chip and socket direction functions ''''
''' Finds the orientation of a right-angled triangle
' Note, assumes a specific orientation which must be adapted to the expected layour of of the three points passed/
' This may be different for chip/socket layout etc.
Function ThreeCornerFindDirection(isFoundTL As Boolean, xTL As Double, yTL As Double, isFoundTR As Boolean, xTR As Double, yTR As Double, isFoundBR As Boolean, xBR As Double, yBR As Double, isFoundBL As Boolean, xBL As Double, yBL As Double) As Boolean
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
	Double AvX, AvY
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
'	Print "SPolar1 = ", SPolar1
'	Print "SPolar2 = ", SPolar2
'	Print " Diff   = ", DiffAnglePM180(SPolar1, SPolar2)
'	Print " Av     = ", Str$(AverageAnglePM180(SPolar1, SPolar2))
	' SPolar = RadToDeg(Acos(DelX / Hyp))
	' SPolar = RadToDeg(Asin(DelY / Hyp))
	
	' Since sockets should be roughly at 90 degree increments to world axis, arctan should be fine
	' SPolar = RadToDeg(Atan(DelY / DelX))
	'Print "Polar angle from bottom left mark to top left mark is ", SPolar
	CornerVar(1) = AvX
	CornerVar(2) = AvY
	CornerVar(3) = AverageAnglePM180(SPolar1, SPolar2) ' SPolar1 '+ 45. ' 45 was frpm older methos using hypotonuse and right-isosceles triangle
	

	
	ThreeCornerFindDirection = True ' SPolar + 45.

Fend

''' Use DF camera to get chip orientation only
Function FindChipDirectionWithDF As Double
	FindChipDirectionWithDF = -999.
	Print "FindChipDirectionWithDF: Chip type ", CHIPTYPE$
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
	Print "FindChipDirectionWithDF: Direction returned by chip specific function: ", FindChipDirectionWithDF
	
	If FindChipDirectionWithDF < -900. Then
		Print "Could not find chip direction"
		Return
	EndIf
	
	FindChipDirectionWithDF = GetBoundAnglePM180(FindChipDirectionWithDF)
	Print "FindChipDirectionWithDF: After bounding pm180: ", FindChipDirectionWithDF
		
	' FindChipOrientationWithDF = RoundAngleTo90(FindChipOrientationWithDF) ' Might want to do this outside of this function?
	
Fend

Function DF_ChipDirection_LArASIC As Double
	DF_ChipDirection_LArASIC = -999.
	Boolean FoundText
	Double xT, yT, uT
	
	Select SITE$
		Case "MSU"
			VRun MSU_DF_ChipDir
			VGet MSU_DF_ChipDir.Geom03.RobotXYU, FoundText, xT, yT, uT
		Case "BNL"
'			VRun BNL_DF_ChipDir
'			VGet BNL_DF_ChipDir.Geom03.RobotXYU, isFoundT, xT, yT, uT
		Default
	Send
	
	If Not FoundText Then
		Print "DF_ChipDirection_LArASIC: Did not find text"
		Exit Function
	EndIf
	DF_ChipDirection_LArASIC = GetBoundAnglePM180(uT + ChipVisionOffset)
	Print "DF_ChipDirection_LArASIC: Direction of text =", DF_ChipDirection_LArASIC
	
	
Fend



'''' Wrapper function to find the direction of a chip with the down facing camera
''' Initializes global array ChipPos() which will store X,Y,U of chip
'' These are set in relevant DFFindLarASIC, DFFindColdADC, DFFindCOLDATA functions
Function FindChipPositionWithDF As Boolean
	FindChipPositionWithDF = False
	
	ChipPos(1) = 0
	ChipPos(2) = 0
	ChipPos(3) = 0
	
	Int32 FindError
	FindError = 0
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

Fend

''' Function to get the orientation of LArASIC chip with the down facing camera
' This makes use of two marks on the surce, a larger manufacturing mark and a 
' smaller mark indicating where pin 1 is.
' it then finds the direction between these and subtracts 45 degrees to get the
' orienation of the chip
'' Stores results in global array ChipPos()
Function DFFindLArASIC As Boolean
	
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

			
			VRun MSU_DF_ChipDir
			VGet MSU_DF_ChipDir.Corr01.RobotXYU, isFoundChip, xC, yC, uC
	
			' Get positions of Large and Small circular markers on chip
			VGet MSU_DF_ChipDir.Geom01.RobotXYU, isFoundL, xL, yL, uL
			VGet MSU_DF_ChipDir.Geom02.RobotXYU, isFoundS, xS, yS, uS
			
			 VGet MSU_DF_ChipDir.Geom03.RobotXYU, isFoundT, xT, yT, uT
		Case "TUT"
			'Print "Using tutorial sequences"
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
	' Print "isFoundChip = ", isFoundChip
	
	If Not isFoundChip Then
		 'Print "Whole chip correlation step failed"
		Exit Function
	EndIf
	'Print "Found whole chip"
	
	If Not isFoundL Then
		'Print "Failed to find largr manufacturing mark (bottom right of chip)"
		Exit Function
	EndIf
	'Print "Found large manufacturing marker"
	
	If Not isFoundS Then
		 'Print "Failed to find small fiducial mark (top left of chip)"
		Exit Function
	EndIf
	'Print "Found small fiducial marker"
	
	If Not isFoundT Then
		'Print "Failed to find text on chip"
		Exit Function
	EndIf
	'Print "found text"
	
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

 ' Cannot rely on finding "chip like" correlation, but can maybe use the geometry of the edge of the chip with the pins
	' Check found position lies lose to correlation step for whole chip
	If Sqr((xC - AvX) * (xC - AvX) + (yC - AvY) * (yC - AvY)) > TolXY Then
		Print "Fiducial marker method disagrees with correlation measurement of chip position"
		Print "Correlation position X,Y,U = (", xC, ",", yC, ",", GetBoundAnglePM180(uC), ")"
		Print "Fiducial position    X,Y,U = (", AvX, ",", AvY, ",", GetBoundAnglePM180(Angle - 45.), ")"
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
	'Print "Got here, should be returning TRUE"
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


''' Funvtion to find a chip at the up facing camera and get its positional information
' Stores results in global array UFChipPos()
Function UF_CHIP_FIND As Boolean '(ByRef Status As Boolean, ByRef ResX As Double, ByRef ResY As Double) As Boolean
	
	' NOTE TODO JW: For COLDATA cannot rely on finding only three corners, just take three of the four corners found 
	' and use GetBoundAnglePM45 function on differences to ensure in same quadrant of angle or the vision
	' sequence may find wildly inconsistent angles for each measurement at incremebts of 90 degrees.
	' The DF camera is used to determine direction anyway
	UF_CHIP_FIND = False
	Boolean found(4)
	Boolean isFound(4) ' Check if separate variable is needed for this
	' Seems to maybe give different result?
	Double ResX(4), ResY(4), ResU(4)
	
	Select SITE$
		Case "MSU"
			VRun MSU_UF_Key
			VGet MSU_UF_Key.Geom01.Found, found(1) 'isFoundTR
			VGet MSU_UF_Key.Geom02.Found, found(2) 'isFoundBR
			VGet MSU_UF_Key.Geom03.Found, found(3) 'isFoundBL
			VGet MSU_UF_Key.Geom04.Found, found(4) 'isFoundTL
		Case "TUT"
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
		If Not ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			Print "ERROR: Chip corner orientation failed"
			UF_CHIP_FIND = False
			Exit Function
		EndIf
	Else
		If Not ThreeCornerFindDirection(found(1), ResX(1), ResY(1), found(4), ResX(4), ResY(4), found(3), ResX(3), ResY(3), found(2), ResX(2), ResY(2)) Then
			Print "ERROR: Chip corner orientation failed"
			UF_CHIP_FIND = False
			Exit Function
		EndIf
	EndIf

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
	UF_CHIP_FIND = True


Fend

Function FindSocketDirectionWithDF As Boolean
	FindSocketDirectionWithDF = False
	
	Select CHIPTYPE$
		Case "LArASIC"
			FindSocketDirectionWithDF = DFFindLArASICSocket
		Case "ColdADC"
			Print "ColdADC not yet implemented, check if LArASIC socket works?"
		Case "COLDATA"
			FindSocketDirectionWithDF = DFFindCOLDATASocket
		Default
			Print "Unsupported chip type: ", CHIPTYPE$
	Send
Fend

Function DFFindLArASICSocket As Boolean
	Double USocket
	SelectSite("InFunction")
	
	Select SITE$
			Case "MSU"
				
				If MSUTESTBOARD Then
					VRun MSU_SocketFind2
				Else
					VRun MSU_SocketFind
				EndIf
			Case "TUT"
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
		Print "ERROR: Did not find mounting points for socket"
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
	
	
'	Print "isFound TR:", isFoundTR
'	Print "isFound BR:", isFoundBR
'	Print "isFound BL:", isFoundBL
'	Print "isFound TL:", isFoundTL
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
	
	If MSUTESTBOARD Then
		SockPos(1) = CornerVar(1)
		SockPos(2) = CornerVar(2)
		SockPos(3) = GetBoundAnglePM180(CornerVar(3))
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
	SockPos(3) = CornerVar(3)

	DFFindCOLDATASocket = True
	
Fend


''' For diagnostic check of chip placement, requires finer position measurement functions
Function GetChipInSocketAlignment(DAT_nr As Integer, socket_nr As Integer) As Int32
	GetChipInSocketAlignment = 0
	SubError = -1
	SetSpeedSetting("PickAndPlace")
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	' Measure the socket position	
	If Not GetSocketPositionWithDF(DAT_nr, socket_nr) Then ', ByRef SockCorr()) Then
		'RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN)
		GetChipInSocketAlignment = -ERR_V_SOCKETALIGN
		Exit Function
	EndIf
	' Check corrections are small	

	' Correct for socket position	
	If Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(5)) > 3. Then
		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
		GetChipInSocketAlignment = ERR_BAD_TOLERANCE
		Exit Function
	EndIf
	Print "Correcting for socket (", DAT_nr, ",", socket_nr, ") drift : (", SocketOffset(1), ",", SocketOffset(2), ",", SocketOffset(3), ")"
	JumpToSocket_camera(DAT_nr, socket_nr)
	Go Here +X(SocketOffset(1)) +Y(SocketOffset(2)) +U(SocketOffset(3))
	
	' Socket positions are stored in SockPos(3) 	
	
'	' Remeasure the socket position after recentering?
'	'''
'	If Not GetSocketPositionWithDF(DAT, Socket) Then ', ByRef SockCorr()) Then
'		'RTS_error("GetChipFromSocket: Could not get socket position ", -ERR_V_SOCKETALIGN)
'		GetChipInSocketAlignment = -ERR_V_SOCKETALIGN
'		Exit Function
'	EndIf
'	' Check corrections are small	
'
'	' Correct for socket position	
'	If Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(5)) > 3. Then
'		'RTS_error("GetChipFromSocket: Socket corrections outside of tolerance ", -ERR_BAD_TOLERANCE)
'		GetChipInSocketAlignment = ERR_BAD_TOLERANCE
'		Exit Function
'	EndIf
'	' Don't correct this time, just want to have more centered measurement 
	'''
	
	' Measure the chip position
	If Not FindChipPositionWithDF Then
		'RTS_error("GetChipFromTray: Cannot find chip direction with DF ", -ERR_V_DF_ALIGN)
		GetChipInSocketAlignment = -ERR_V_DF_ALIGN ' Set an error code
		Exit Function
	EndIf
	
	' Chip positions are stored in ChipPos(3)
	
	' Store for logging
	CSAlign(1) = ChipPos(1) - SockPos(1)
	CSAlign(2) = ChipPos(2) - SockPos(2)
	CSAlign(3) = ChipPos(3) - SockPos(3)
	' Calculate x and y offset after removing socket rotation
	CSAlign(4) = CSAlign(1) * Cos(DegToRad(SockPos(3))) - CSAlign(2) * Sin(DegToRad(SockPos(3)))
	CSAlign(5) = CSAlign(1) * Sin(DegToRad(SockPos(3))) - CSAlign(2) * Cos(DegToRad(SockPos(3)))
	
	SetSpeedSetting("MoveWithoutChip")
	GetChipInSocketAlignment = -1
Fend

''''' JW: Get alignment functions ''''
'
'''' Defined position of the socket
'' CinSRes(1) - X 
'' CinSRes(2) - Y 
'' CinSRes(3) - U
'''' Measured position of the socket
'' CinSRes(4) - X 
'' CinSRes(5) - Y 
'' CinSRes(6) - U
'''' Socket offsets (Defined -> Measured)
'' CinSRes(7) - X 
'' CinSRes(8) - Y 
'' CinSRes(9) - U
'''' Measured chip position
'' CinSRes(10) - X 
'' CinSRes(11) - Y 
'' CinSRes(12) - U
'''' Chip offsets from measured socket position (Measured socket -> Measured chip)
'' CinSRes(13) - X 
'' CinSRes(14) - Y 
'' CinSRes(15) - U
'
'Function GetChipInSocketAlignment(id$ As String, ByRef idx() As Integer, DAT_nr As Integer, socket_nr As Integer, ByRef CinSResults() As Double) As Boolean
'	GetChipInSocketAlignment = False
'	
'	Integer i, fileNum
'	For i = 1 To 15
'		CinSResults(i) = 0
'	Next i
'	fileNum = idx(1)
'
'	JumpToSocket_camera(DAT_nr, socket_nr)
'	
'	UF_camera_light_ON
'	Wait 0.2
''	String pict_fname$
''	pict_fname$ = DF_take_picture$(id$ + "_CS")
''    Print #fileNum, ",", pict_fname$,
'
'	Int32 FullSocket_nr
'	FullSocket_nr = DAT_nr * 100 + socket_nr
'	' defined chip position and orienation
'	CinSResults(1) = CX(P(FullSocket_nr)) ' Socket X
'	CinSResults(2) = CY(P(FullSocket_nr)) ' Socket Y
'	' CinSResults(3) = CU(P(FullSocket_nr)) ' Socket U
'	CinSResults(3) = GetBoundAnglePM180(CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR))
'
'	Int32 Attempts
'	Boolean Success
'	Attempts = 20
'	Success = False
'	Print "Getting precise socket position"
'	Do While ((Attempts > 0) And Not Success)
'		If Not FindSocketDirectionWithDF Then
'			'Print "Not found"
'			Attempts = Attempts - 1
'		Else
'			Success = True
'			Exit Do
'		EndIf
'	Loop
'	If Not Success Then
'		Print "ERROR: Cannot find socket alignment"
'		Exit Function
'	EndIf
'
'	' Get socket position	
'	CinSResults(4) = SockPos(1) ' Socket X
'	CinSResults(5) = SockPos(2) ' Socket Y
'	CinSResults(6) = SockPos(3) ' Socket U
'
'	Attempts = 20
'	Success = False
'	Do While ((Attempts > 0) And Not Success)
'		' TODO JW: Check chip dimensions are in range
'		If Not FindChipDirectionWithDF Then
'			Attempts = Attempts - 1
'		Else
'			Success = True
'			Exit Do
'		EndIf
'	Loop
'	If Not Success Then
'		Print "Cannot find chip alignment"
'		Exit Function
'	EndIf
'	
'	' Offset of socket from defined position 
'	CinSResults(7) = CinSResults(4) - CinSResults(1)
'	CinSResults(8) = CinSResults(5) - CinSResults(2)
'	CinSResults(9) = DiffAnglePM180(CinSResults(3), CinSResults(6))
''	CinSResults(9) = CinSResults(6) - CinSResults(3)
'
'	' Get chip position
'	CinSResults(10) = ChipPos(1) ' Chip X
'	CinSResults(11) = ChipPos(2) ' Chip Y
'	CinSResults(12) = ChipPos(3) ' Chip U
'		
'	' Offsets from measured socket (for analysis)
'	CinSResults(13) = ChipPos(1) - SockPos(1) ' Offset in X (Socket -> Chip)
'	CinSResults(14) = ChipPos(2) - SockPos(2)   ' Offset in Y
'	CinSResults(15) = DiffAnglePM180(SockPos(3), ChipPos(3)) ' ChipPos(3) - SockPos(3)  ' Offset in U (wrt mezzanine direction)
'	
'	GetChipInSocketAlignment = True
'Fend

' Gets the position and offsets of the socket from the taught point
Function GetSocketPositionWithDF(DAT_nr As Integer, Socket_nr As Integer) As Int64
	GetSocketPositionWithDF = 0
	
	SocketOffset(1) = 0.
	SocketOffset(2) = 0.
	SocketOffset(3) = 0.
	
	SetSpeedSetting("PickAndPlace")
	JumpToSocket_camera(DAT_nr, Socket_nr)
		
	Int32 FullSocket_nr
	FullSocket_nr = DAT_nr * 100 + Socket_nr

	Int32 Attempts
	Boolean Success
	Attempts = 20
	Success = False
	Print "Getting precise socket position"
	Do While ((Attempts > 0) And Not Success)
		If Not FindSocketDirectionWithDF Then
			'Print "Not found"
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR: Cannot find socket alignment"
		GetSocketPositionWithDF = False
		Exit Function
	EndIf
	
	Print "Expected socket position (", CX(P(FullSocket_nr)), ",", CY(P(FullSocket_nr)), ",", GetBoundAnglePM180(CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR)), ")"
	Print "Measured socket position (", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	SocketOffset(1) = SockPos(1) - CX(P(FullSocket_nr))
	SocketOffset(2) = SockPos(2) - CY(P(FullSocket_nr))
	SocketOffset(3) = DiffAnglePM180((SockPos(3)), (CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR))) ' Should this be a socket vision offset? Depends  how vision is taught
	
		' Add some check that offsets are small
	If Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(3)) > 1. Or Abs(SocketOffset(5)) > 3. Then
		' ERROR SOCKET CORRECTIONS ARE TOO LARGE
		
		Exit Function
	EndIf
	
	GetSocketPositionWithDF = -1
	
Fend

'''' Socket alignment from DF camera
'''' 
'' DFSockRes(1) - defined X
'' DFSockRes(2) - defined Y
'' DFSockRes(3) - defined U
'
'' DFSockRes(4) - measured X
'' DFSockRes(5) - measured Y
'' DFSockRes(6) - measured U
'
'' DFSockRes(7) - Offset X
'' DFSockRes(8) - Offset Y
'' DFSockRes(9) - Offset U
'
'' DFSockRes(10) - J4 offset at measured position
'
'Function DFGetSocketAlignment(id$ As String, ByRef idx() As Integer, DAT_nr As Integer, socket_nr As Integer, ByRef DFSockRes() As Double) As Boolean
'	Print "Getting socket alignment"
'    SetSpeedSetting("PickAndPlace")
'	' Maybe add check to see if already above socket or in sink
'	JumpToSocket_camera(DAT_nr, socket_nr)
'	
'	Int32 FullSocket_nr
'	FullSocket_nr = DAT_nr * 100 + socket_nr
'
'	' Reset results array
'	Int32 i
'	For i = 1 To 10
'		DFSockRes(i) = 0.
'	Next i
'	
'	DFSockRes(1) = CX(P(FullSocket_nr))
'	DFSockRes(2) = CY(P(FullSocket_nr))
''	DFSockRes(3) = CU(P(FullSocket_nr))
'	DFSockRes(3) = GetBoundAnglePM180(CU(P(FullSocket_nr)) + HandChipOrientation(CHIPTYPE_NR))
'	Print "Defined socket position:"
'	Print "DFSockRes(1) = ", DFSockRes(1)
'	Print "DFSockRes(2) = ", DFSockRes(2)
'	Print "DFSockRes(3) = ", DFSockRes(3)
'	
'	
'	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
'	Int32 Attempts
'	Boolean Success
'	Attempts = 20
'	Success = False
'	Print "Getting precise socket position"
'	Do While ((Attempts > 0) And Not Success)
'		If Not FindSocketDirectionWithDF Then
'			'Print "Not found"
'			Attempts = Attempts - 1
'		Else
'			Success = True
'			Exit Do
'		EndIf
'	Loop
'	If Not Success Then
'		Print "ERROR: Cannot find socket alignment"
'		DFGetSocketAlignment = False
'		Exit Function
'	EndIf
'	DFSockRes(4) = SockPos(1)
'	DFSockRes(5) = SockPos(2)
'	DFSockRes(6) = SockPos(3)
'	Print "Measured socket position:"
'	Print "DFSockRes(4) = ", DFSockRes(4)
'	Print "DFSockRes(5) = ", DFSockRes(5)
'	Print "DFSockRes(6) = ", DFSockRes(6)
'	
'	' Print any deviations between the socket position in camera and defined point
'	' Offset = Measured - Expected
'	DFSockRes(7) = DFSockRes(4) - DFSockRes(1) ' X
'	DFSockRes(8) = DFSockRes(5) - DFSockRes(2) ' Y
'	DFSockRes(9) = DiffAnglePM180(DFSockRes(3), DFSockRes(6)) 'DFSockRes(6) - DFSockRes(3) ' U
'	Print "Offset = measured - Defined ... NB, (9) is DiffAngleBound((3),(6)) i.e. (6) - (3) but within 180 in U."
'	Print "DFSockRes(7) = ", DFSockRes(7)
'	Print "DFSockRes(8) = ", DFSockRes(8)
'	Print "DFSockRes(9) = ", DFSockRes(9)
'	Print Here
'	'Print "moving to (", DFSockRes(4), ",", DFSockRes(5), ",", Str$(DFSockRes(3) + DFSockRes(9)), ")"
''	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DFSockRes(6))
''	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DFSockRes(3) + DFSockRes(9))
'	' Actually want to move to "Here" + offset for direction
''	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(CU(Here) + DFSockRes(9))
'	' OR 
'	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(GetBoundAnglePM180(DFSockRes(6) - HandChipOrientation(CHIPTYPE_NR))) ' Should this be DiffAngleBound?
''	Go Here :X(DFSockRes(4)) :Y(DFSockRes(5)) :U(DiffAnglePM180, DFSockRes(6))??? Not looking to get angle between but to remove offset between chip and hand
'	' May need to consider bound in J4 not in U
'	DFSockRes(10) = CU(Here) - Agl(4)
'	Print "DFSockRes(10) = ", DFSockRes(10)
'	DFGetSocketAlignment = True
'	
'Fend
'
'''' get the position and alignment of a chip in a tray position
'''' Socket alignment from DF camera
''' Defined position
'' DFTrayRes(1) - defined X
'' DFTrayRes(2) - defined Y
'' DFTrayRes(3) - defined U
'' Measured position
'' DFTrayRes(4) - measured X
'' DFTrayRes(5) - measured Y
'' DFTrayRes(6) - measured U
'' Offsets 
'' DFTrayRes(7) - Offset X
'' DFTrayRes(8) - Offset Y
'' DFTrayRes(9) - Offset U
'
'' DFTrayRes(10) - J4 offset at measured position
'Function DFGetTrayAlignment(id$ As String, ByRef idx() As Integer, pallet_nr As Integer, col_nr As Integer, row_nr As Integer, ByRef DFTrayRes() As Double) As Boolean
'
'	' Reset results array
'	Int32 i ', fileNum
'	For i = 1 To 10
'		DFTrayRes(i) = 0.
'	Next i
'	'fileNum = idx(1)
'
'	JumpToTray_camera(pallet_nr, col_nr, row_nr)
'	
'	' Take a picture of the chip in the tray
'	JumpToTray_camera(pallet_nr, col_nr, row_nr)
''	String pict_fname$
''	pict_fname$ = DF_take_picture$(id$ + "_CT")
''	Print #fileNum, ",", pict_fname$,
'	
'	DFTrayRes(1) = CX(Pallet(pallet_nr, col_nr, row_nr))
'	DFTrayRes(2) = CY(Pallet(pallet_nr, col_nr, row_nr))
'	'DFTrayRes(3) = CU(Pallet(pallet_nr, col_nr, row_nr))
'	' Should (3) be the robot position or the expected chip position?
'	DFTrayRes(3) = GetBoundAnglePM180(CU(Pallet(pallet_nr, col_nr, row_nr)) + TrayChipOrientation(pallet_nr))
'
'	' Vision sequence tollerance can be adjusted but sometimes fails, try multiple times
'	Integer Attempts
'	Attempts = 20
'	Boolean Success
'	Success = False
'	Do While ((Attempts > 0) And Not Success)
'		' TODO JW: Check chip dimensions are in range
'		If Not FindChipDirectionWithDF Then
'			Attempts = Attempts - 1
'		Else
'			Success = True
'			Exit Do
'		EndIf
'	Loop
'	If Not Success Then
'		Print "Cannot find chip alignment"
'		Exit Function
'	EndIf
'	
'	Print "Chip found"
'	DFTrayRes(4) = ChipPos(1)
'	DFTrayRes(5) = ChipPos(2)
'	DFTrayRes(6) = ChipPos(3)
'	' Print any deviations between the socket position in camera and defined point
'	' Offset = Measured - Expected
'	DFTrayRes(7) = DFTrayRes(4) - DFTrayRes(1) ' X
'	DFTrayRes(8) = DFTrayRes(5) - DFTrayRes(2) ' Y
'	' DFTrayRes(9) =DFTrayRes(6) - DFTrayRes(3)
'	DFTrayRes(9) = DiffAnglePM180(DFTrayRes(3), DFTrayRes(6)) ' B - A
'
'	Go Here :X(DFTrayRes(4)) :Y(DFTrayRes(5))
'	DFTrayRes(10) = CU(Here) - Agl(4)
'	
'	DFGetTrayAlignment = True
'	
'Fend

Function FindChipAxisOffsetWithUF As Boolean
	
	SetSpeedSetting("AboveCamera")
	FindChipAxisOffsetWithUF = False
		
	Double MeasU0, MeasU1, MeasU2
	
	Double ChipX1, ChipY1, ChipU1
	Double ChipX2, ChipY2, ChipU2

	JumpToCamera

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
	
	
	'' TAKE PICTURE
	UF_camera_light_ON
	Wait 0.2
'	'String pict_fname$
'	'pict_fname$ = UF_take_picture$(id$ + "_01")
'    ' Print #fileNum, ",", pict_fname$,
'	Images$(1) = UF_take_picture$(id$ + "_01")
'	' Take first measurements

	Integer Attempts
	Attempts = 20
	Boolean Success
	Success = False
	Do While ((Attempts > 0) And Not Success)
		If Not UF_CHIP_FIND Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR UF camera cannot find chip"
		Exit Function
	EndIf
	
	' Store first measurement values
	ChipX1 = UFChipPos(1)
	ChipY1 = UFChipPos(2)
	ChipU1 = UFChipPos(3)
	
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
	
	' Take another picture
	UF_camera_light_ON
	Wait 0.2
'	Images$(2) = UF_take_picture$(id$ + "_02")
	'pict_fname$ = UF_take_picture$(id$ + "_02")
    'Print #fileNum, ",", pict_fname$,
	
	Attempts = 20
	Success = False
	Do While ((Attempts > 0) And Not Success)
		If Not UF_CHIP_FIND Then
			Attempts = Attempts - 1
		Else
			Success = True
			Exit Do
		EndIf
	Loop
	If Not Success Then
		Print "ERROR UF camera cannot find chip after 180 degree rotation"
		Exit Function
	EndIf

	' Store second measurement values
	ChipX2 = UFChipPos(1)
	ChipY2 = UFChipPos(2)
	ChipU2 = UFChipPos(3)
	
	If CHIPTYPE$ = "COLDATA" Then
		ChipU2 = GetBoundAnglePM180(GetBoundAnglePM45(ChipU2) + 180.)
	EndIf

	' Measurements have been made, return to initial U at camera
	' This should be same as U_0
	Go Here -U(Rotation1 + Rotation2)
	
'	Print "Chip position measured with UF camera. Starting from", UFChipRes(1)
'	Print "Rotate by ", Rotation1
'	Print "1st measurement at U=", UFChipRes(2)
'	Print "  x1: ", UFChipRes(4)
'	Print "  y1: ", UFChipRes(5)
'	Print "  u1: ", UFChipRes(6)
'	Print "Rotate by ", Rotation2
'	Print "2nd measurement at U=", UFChipRes(3)
'	Print "  x2: ", UFChipRes(7)
'	Print "  y2: ", UFChipRes(8)
'	Print "  u2: ", UFChipRes(9)
'	Print "Return U value by rotating by ", -(Rotation1 + Rotation2)
	
	' Correct for +90 degrees for first measurement by rotating -90
	
'	Print "UF chip center measurements"
'	Print "Rotation1 = ", Rotation1, ", Rotation2 = ", Rotation2
'	Print "HAND U1 =", UFChipRes(2), ", HAND U2=", UFChipRes(3)
'	Print "x1 = ", UFChipRes(4), "   x2 = ", UFChipRes(7)
'	Print "y1 = ", UFChipRes(5), "   y2 = ", UFChipRes(8)
'	Print "u1 = ", UFChipRes(6), "   u2 = ", UFChipRes(9)
	
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
	
	Print "Offset of chip from rotational axis wrt U = 0 " ' HAND_U0"
	Print "Offsets measured from a rotation of ", Rotation1
	Print "Offset in x axis : ", CurrentChipOffset(1)
	Print "Offset in y axis : ", CurrentChipOffset(2)
	Print "Offset in u1   	: ", UF_DEL_U1
	Print "Offset in u2   	: ", UF_DEL_U2
	Print "Offset in u   	: ", CurrentChipOffset(3)

' Correction requires rotation based on U offset - This is when target U and chip rotation were provided
' This should now be done outside of this function
' Store DelX_1, DelY_1 and DelU_1
' Then for correction
' Phi = DelU_1 - DelU_2
' Del_X2_Phi = DelX_2 * Cos(Phi) - DelY_2 * Sin(Phi)
' Del_Y2_Phi = DelX_2 * Sin(Phi) + DelY_2 * Cos(Phi)
' Correction at U=HAND_U0
' CorrX_0 = Del_X1 - Del_X2_Phi
' CorrY_0 = Del_Y1 - Del_Y2_Phi
' These corrections should already take into account that you will rotate by phi but at HAND_U0, so
' So to get to correction at socket 
' CorrX_US = CorrX_0 * Cos(US - HAND_U0) - CorrY_0 * Sin(US - HAND_U0)
' CorrX_US = CorrX_0 * Cos(US - HAND_U0) - CorrY_0 * Sin(US - HAND_U0)
' CorrU = Phi
' So go to socket
' Correct for socket alignment wrt defined point
' Use measured socket U to calculate corrections
' Go Here +U(CorrU) +X(CorrX_US) +Y(CorrY_US)
'	
'	' Do the pin analysis 
'	UFRecenterSimple ' (ByRef UFChipRes())
'	' Commented out for testing (my test chip has a bent pin!)
''	UFChipRes(13) = UFPinAnalysis(id$, ByRef idx(), ByRef Images$())
'	
'	If UFChipRes(13) <> 0 Then
'		Print "Pin analysis failed"
'		FindChipAxisOffsetWithUF = False
'		Exit Function
'	EndIf
	FindChipAxisOffsetWithUF = True
    SetSpeedSetting("MoveWithChip")
	
	
Fend




' Takes measured alignments to U = 0 (Old wrt HAND_U0) and a target U and calculates corrections
' C1 -> C2
Function GetChipToChipCorrections(C1X As Double, C1Y As Double, C1U As Double, C2X As Double, C2Y As Double, C2U As Double, TargetHandU As Double)
	
	' Note, the offsets calculated by UFGetChipAlignment were PREVIOUSLY (Before 2025-09-04) ChipPosition -> RotationalAxis
	' Now UFGetChipAlignmemt returns offset of chip from axis which can be subtracted to get the correction for an individual measurement
	' This function takes two sets of offsets and uses them to go from C1->C2, where the offsets are	
	' measured as C1 - Axis, not the other way around
	
	'GetChipToChipCorrections = 0
	Print "Calculating chip-to-chip correction from offset measurements (going from first measurement args to second)"
	Print "Targeting hand U of :", TargetHandU
	
	Double CorrX, CorrY
	
	ChipToChipCorrection(3) = C2U - C1U ' Corr(3) = DiffAnglePM180(C1U, C2U) ' Not sure this is working
	Print "Moving C1 to C2' by rotating by ", ChipToChipCorrection(3)

	
	' Rotate C1 corrections by phi around axis of rotation
	' Then get difference to C2 wrt axis
	' Needs intermediate variable to change X before changing Y
	CorrX = C2X - (C1X * Cos(DegToRad(ChipToChipCorrection(3))) - C1Y * Sin(DegToRad(ChipToChipCorrection(3))))
	CorrY = C2Y - (C1X * Sin(DegToRad(ChipToChipCorrection(3))) + C1Y * Cos(DegToRad(ChipToChipCorrection(3))))
	
	' Now rotate corrections wrt axis to the target U value
'	Corr(1) = Corr(1) * Cos(DegToRad(TargetHandU - HAND_U0)) - Corr(2) * Sin(DegToRad(TargetHandU - HAND_U0))
'	Corr(2) = Corr(1) * Sin(DegToRad(TargetHandU - HAND_U0)) + Corr(2) * Cos(DegToRad(TargetHandU - HAND_U0))
'	

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
	
	'GetChipToChipCorrections = -1
Fend



''' If chip is picked up in a different orientation to expected, may need to account for                                                                                                                                                                                                      
' this between tray and socket offset measurements or between successive tray position offsets                                                                                                                                                                                                
' as X and Y offsets are U dependent.                                                                                                                                                                                                                                                         
Function CorrectChipAxisOffsetForPickupOrientation(Actual As Double, Expected As Double)
	
        Double OrientationOffset
        OrientationOffset = GetBoundAnglePM180(Actual - Expected) ' Expected - Measured? but bound by 180 degrees                                                                                                                                                                                                                     
	
		' Don't want to correct "current" offset here, and it would interfere with Y correction if X gets directly corrected in first line below
        CorrectedChipOffset(1) = CurrentChipOffset(1) * Cos(DegToRad(OrientationOffset)) - CurrentChipOffset(2) * Sin(DegToRad(OrientationOffset))
        CorrectedChipOffset(2) = CurrentChipOffset(1) * Sin(DegToRad(OrientationOffset)) + CurrentChipOffset(2) * Cos(DegToRad(OrientationOffset))
        CorrectedChipOffset(3) = GetBoundAnglePM45(CurrentChipOffset(3))
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

Function GetTrayCorrection(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	' This functions picks up a chip, runs the vision sequence to get the corrections	
	' needed, so that a new tray/site can collect the initial chip correction information.
	' This function would need to be used on each chip position before using the functions
	' MoveChipFromTrayToSocket or MoveChipFromSocketToTray
	
	' Jump to the given tray position
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	' Attempt to pickup chip from tray, exit function if it fails
	If Not PickupFromTray Then
		Print "Can't pickup chip from socket"
		Exit Function
	EndIf
	
	' Move to the upward facing camera for corrections
	Jump P_Camera
	Wait 1
	
	' Run the calibration sequence and save the correction results
	Double corrs(2)
	Double res(3)
	Integer status
	
	If CHIPTYPE$ = "COLDATA" Then
		status = COLDATA_VisAnalysis(ByRef corrs())
	Else
		Print "ERROR: Not implemented for other chip types yet"
		Exit Function
	EndIf
		
	
	Print "Previous tray corr:", tray_X(pallet_nr, col_nr, row_nr), tray_Y(pallet_nr, col_nr, row_nr)
	Print "New corrections:", corrs(1), corrs(2)
	
	' Grab corrections from camera calibration
	Double X_CORR_tray, Y_CORR_tray
	X_CORR_tray = corrs(1)
	Y_CORR_tray = corrs(2)
	
	' Save/update the tray position corrections
	tray_X(pallet_nr, col_nr, row_nr) = X_CORR_tray
	tray_Y(pallet_nr, col_nr, row_nr) = Y_CORR_tray
	
	' Jump to the given tray position
	JumpToTray(pallet_nr, col_nr, row_nr)
	
	DropToTray
	
Fend

Function GetAllTrayCorrections(pallet_nr As Integer)
	' This function runs GetTrayCorrection for all chips in a tray,
	' in order to fill the tray_xyu.csv files initially. This should
	' only be needed the first time and whenever the tray_xyu.csv
	' file is reset. 
	
	Integer i, j
	For i = 1 To TRAY_NCOLS
		For j = 1 To TRAY_NROWS
			GetTrayCorrection(pallet_nr, i, j)
		Next j
	Next i
	
Fend

'''' Function to recenter a chip based on the offsets from the image center calculated using the UF camera
'' This is used to then do any pin analysis with the pins aligned with the right search boxes
''' Args:
'' ByRef CameraResults(Length 13) - The results of the UF camera key finding analysis which finds the position of the chip
'Function UFRecenter(ByRef CameraResults() As Double) As Int32
'	UFRecenter = 0
'	JumpToCamera
'	Double CorX1, CorY1, CorU1
'	CorX1 = CameraResults(10) * Cos(DegToRad(CU(Here))) - CameraResults(11) * Sin(DegToRad(CU(Here)))
'	CorY1 = CameraResults(10) * Sin(DegToRad(CU(Here))) + CameraResults(11) * Cos(DegToRad(CU(Here)))
'	Go Here -X(CorX1) -Y(CorY1) -U(GetBoundAnglePM45(DiffAnglePM180(CameraResults(2), CameraResults(12))))
'	UFRecenter = -1
'Fend


Function UFRecenterSimple As Int32
	UFRecenterSimple = 0
	JumpToCamera
	Double CorX1, CorY1 ' , CorU1
	CorX1 = CurrentChipOffset(1) * Cos(DegToRad(CU(Here))) - CurrentChipOffset(2) * Sin(DegToRad(CU(Here)))
	CorY1 = CurrentChipOffset(1) * Sin(DegToRad(CU(Here))) + CurrentChipOffset(2) * Cos(DegToRad(CU(Here)))
	Go Here -X(CorX1) -Y(CorY1) -U(CurrentChipOffset(3))
	' Or Go Here  -X(CorX1) -Y(CorY1) :U(DiffAnglePM180(CurrentChipOffset(3), CU(Here)))
	UFRecenterSimple = -1
Fend
