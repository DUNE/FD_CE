#include "RTS_tools.inc"
#include "ErrorDictionary.inc"

Function MoveFromPointToImage
	''' Helper function which moves by the camera offsets at a given hand U coordinate
	' moving from the defined point above the chip to the chip being at the center of the image
	SelectSite("InFunctionDefinePallets")
	' Move arm from stinger at point, to chip in focus with some rotation in degrees
	' Remember point is defined as some offset (10mm from contact)
	Move Here +Z(DF_CAM_Z_OFF)
	Move Here +X(XOffset(CU(Here))) +Y(YOffset(CU(Here)))
Fend

Function MoveFromImageToPoint
	''' Helper function moves by camera offsets such that if a chip centered in the image
	' the robot will move to the defined point above the chip
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
	''' Jumps to the defined point at CONTACT_DIST above the chip
	
	SelectSite("InFunctionDefinePallets")
	Jump Pallet(pallet_nr, col_nr, row_nr) LimZ JUMP_LIMIT ' +Z(10)

Fend

' pallet_nr 1..2 (1-left, 2-right)
' row_nr = 1..6
' col_nr = 1..15
Function JumpToTray_camera(pallet_nr As Integer, col_nr As Integer, row_nr As Integer)
	''' Centers a chip in the tray in the DF camera image 
	
	SelectSite("InFunctionDefinePallets")

	If ChipType$ = "COLDATA" Then
		If pallet_nr = 1 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0 + 180)) +Y(YOffset(HAND_U0 + 180)) +Z(DF_CAM_Z_OFF) :U(HAND_U0 + 180) LimZ JUMP_LIMIT
		ElseIf pallet_nr = 2 Then
			Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(HAND_U0)) +Y(YOffset(HAND_U0)) +Z(DF_CAM_Z_OFF) :U(HAND_U0) LimZ JUMP_LIMIT
		EndIf

	Else
		Jump Pallet(pallet_nr, col_nr, row_nr) +X(XOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Y(YOffset(CU(Pallet(pallet_nr, col_nr, row_nr)))) +Z(DF_CAM_Z_OFF) LimZ JUMP_LIMIT '  :U(CU(Pallet(pallet_nr, col_nr, row_nr)))
	EndIf

Fend

Function JumpToSocket(DAT_nr As Integer, socket_nr As Integer)
	''' Jumps to defined point at CONTACT_DIST above point of contact (sensor activated) with chip	
	
	SelectSite("InFunctionDefinePallets")
	If Dist(Here, P(100 * DAT_nr + socket_nr)) < 0.1 Then
		Exit Function
	EndIf
	' Note, should teach points at 20mm above contact
	Jump P(100 * DAT_nr + socket_nr) LimZ JUMP_LIMIT
	Print P(100 * DAT_nr + socket_nr)

Fend

Function JumpToSocket_camera(DAT_nr As Integer, socket_nr As Integer)
	''' Jumps to point where socket point is centered in image
	
	SelectSite("InFunctionDefinePallets")
	Integer SockP
	SockP = DAT_nr * 100 + socket_nr
	Double SockU
	SockU = CU(P(SockP))
	
	If Dist(Here, XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU)) < 0.1 Then
		Exit Function
	EndIf

	' Use different handedness with each DAT board
	If DAT_nr = 1 Then
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /R LimZ JUMP_LIMIT
	Else
		Jump XY((CX(P(SockP)) + XOffset(SockU)), (CY(P(SockP)) + YOffset(SockU)), (CZ(P(SockP)) + DF_CAM_Z_OFF), SockU) /L LimZ JUMP_LIMIT
	EndIf

Fend


