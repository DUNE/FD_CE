#include "RTS_tools.inc"
#include "ErrorDictionary.inc"



Function MoveFromPointToImage
	SelectSite("InFunctionDefinePallets")
	' Move arm from stinger at point, to chip in focus with some rotation in degrees
	' Remember point is defined as some offset (10mm from contact)
	Move Here +Z(DF_CAM_Z_OFF)
	Move Here +X(XOffset(CU(Here))) +Y(YOffset(CU(Here)))

Fend

Function MoveFromImageToPoint
	SelectSite("InFunctionDefinePallets")
	' Inverse of above function, note rotation is not inverted like other offsets
	' And order of operations may need to be reversed if this matters for collisions
	Move Here -X(XOffset(CU(Here))) -Y(YOffset(CU(Here)))
	Move Here -Z(DF_CAM_Z_OFF)
	
Fend

' Jump to camera
' Preserve U rotation
Function JumpToCamera
	SelectSite("InFunctionDefinePallets")
	If Agl(2) < 0 Then
		' Left-handed orientation
    	Jump P_camera :U(CU(Here)) /L LimZ JUMP_LIMIT
    Else
    	' Right-handed orientation 
    	Jump P_camera :U(CU(Here)) /R LimZ JUMP_LIMIT
	EndIf

Fend

' pallet_nr 1..2 (1-left, 2-right)
' row_nr = 1..6
' col_nr = 1..15
Function JumpToTray(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	SelectSite("InFunctionDefinePallets")
	Jump Pallet(pallet_nr, col_nr, row_nr) LimZ JUMP_LIMIT ' +Z(10)

Fend

' pallet_nr 1..2 (1-left, 2-right)
' row_nr = 1..6
' col_nr = 1..15
Function JumpToTray_camera(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	
	SelectSite("InFunctionDefinePallets")

	If ChipType$ = "COLDATA" Then
		If pallet_nr = 1 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0 + 180)) +Y(YOffset(HAND_U0 + 180)) +Z(DF_CAM_Z_OFF) :U(HAND_U0 + 180) LimZ JUMP_LIMIT
		ElseIf pallet_nr = 2 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT
		EndIf

	Else
'		If pallet_nr = 1 Then
'			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT
'		ElseIf pallet_nr = 2 Then
'			' TODO JOE CHECK Should this be the same for Pallet 1???
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Y(YOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Z(DF_CAM_Z_OFF) LimZ JUMP_LIMIT '  :U(CU(Pallet(pallet_nr, col_nr, row_nr)))
'		EndIf
	EndIf

Fend


Function JumpToSocket(DAT_nr As Integer, socket_nr As Integer)
	SelectSite("InFunctionDefinePallets")
	If Dist(Here, P(100 * DAT_nr + socket_nr)) < 0.1 Then
		Exit Function
	EndIf
	' Note, should teach points at 20mm above contact
	Jump P(100 * DAT_nr + socket_nr) LimZ JUMP_LIMIT
	Print P(100 * DAT_nr + socket_nr)

Fend

Function JumpToSocket_cor(DAT_nr As Integer, socket_nr As Integer)
	'Print
	'Print socket_nr, "**********************************************"
	
	JumpToSocket_camera(DAT_nr, socket_nr)
	
	VRun skt_cali_test
	
	Boolean Isfound1, Isfound2, Isfound3
	Boolean found
	
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
		VGet skt_cali_test.Geom03.RobotXYU, isFound3, x_p3, y_p3, a_p3
		'Print "P3 xyu: ", x_p3, y_p3, a_p3
	
		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
		Double x_c, y_c
		x_c = (x_p1 + x_p3) /2
		y_c = (y_p1 + y_p3) /2

		Print "corr_center: ", x_c, y_c
		JumpToSocket(DAT_nr, socket_nr)
		Jump Here :X(x_c) :Y(y_c) LimZ JUMP_LIMIT
		
	EndIf
	

	
Fend


Function JumpToSocket_camera(DAT_nr As Integer, socket_nr As Integer)
	SelectSite("InFunctionDefinePallets")
	Integer SockP
	SockP = DAT_nr * 100 + socket_nr
	Double SockU
	SockU = CU(P(SockP))
'
'	Boolean At45
'	At45 = False
'	If ChipType$ = "COLDATA" Then
'		At45 = False
'	EndIF
'	If At45 Then
'		If DAT_nr = 2 Then
'			SockU = SockU - 45.
'		ElseIf DAT_nr = 1 Then
'			SockU = SockU + 45. '135.
'		EndIf
'	EndIf
	
	If Dist(Here, XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU)) < 0.1 Then
		Exit Function
	EndIf

	If DAT_nr = 1 Then
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /R LimZ JUMP_LIMIT
	Else
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /L LimZ JUMP_LIMIT
	EndIf

Fend


