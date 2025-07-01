#include "RTS_tools.inc"



Function main
	
	SelectSite
	
	' Make sure RTS_DATA folder exists, create if not
	If Not FolderExists(RTS_DATA$) Then
  		SetupDirectories
	EndIf

	If Not FolderExists(RTS_DATA$) Then
  		Print "***ERROR Can't create directory [" + RTS_DATA$ + "]"
  		Exit Function
	EndIf
	
'	LoadPositionFiles
'		
'	VacuumValveClose
'	PumpOn
'	Wait 3
'
'	Motor On
'	Power Low

	SetSpeed
	
	' left tray
	Pallet 1, Tray_Left_P1, Tray_Left_P2, Tray_Left_P3, Tray_Left_P4, trayNCols, trayNRows

	' right tray
	Pallet 2, Tray_Right_P1, Tray_Right_P2, Tray_Right_P3, Tray_Right_P4, trayNCols, trayNRows

'	MoveChipFromTrayToSocket(2, 21, 2, 1, 3)


	UpdatePositionFiles
	
'	Jump P_Home
'	Motor Off
'	PumpOff
	
	' This can probably go in an include
	TrayChipOrientation(1) = 0 ' Left Tray
	TrayChipOrientation(2) = 0 ' Right Tray

	SocketChipOrientation(1) = -90 ' LArASIC
	SocketChipOrientation(2) = -90 ' ColdADC
	SocketChipOrientation(3) = -90 ' COLDATA


	On 12
	Print FindChipDirectionWithDF
	Print "Found chip position and orientation is "
	Print "(", ChipPos(1), ",", ChipPos(2), ",", ChipPos(3), ")"
	Print FindSocketDirectionWithDF
	Print "Found socket position and orientation is "
	Print "(", SockPos(1), ",", SockPos(2), ",", SockPos(3), ")"
	
	
'	Print "TRAY TO TRAY MOVEMENT 1"
'	RunMoveChipTrayToTray(2, 15, 1, 2, 15, 3, GetBoundAnglePM180(CU(Pallet(2, 15, 3)) + 0))
'	Wait 2
'
'	Print "TRAY TO TRAY MOVEMENT 2"
'	RunMoveChipTrayToTray(2, 15, 3, 2, 15, 1, GetBoundAnglePM180(CU(Pallet(2, 15, 1)) + 90))
'	Wait 2
'
'	Print "TRAY TO TRAY MOVEMENT 3"
'	RunMoveChipTrayToTray(2, 15, 1, 2, 15, 1, GetBoundAnglePM180(CU(Pallet(2, 15, 1)) + 180))
'	Wait 2
'
'	Print "TRAY TO TRAY MOVEMENT 4"
'	RunMoveChipTrayToTray(2, 15, 1, 2, 15, 1, GetBoundAnglePM180(CU(Pallet(2, 15, 1)) + 0))

'	RunMoveChipTrayToSocket(2, 15, 1, 1, 8)
'	JumpToCamera
'	Wait 5
'	RunMoveChipSocketToTray(1, 8, 2, 15, 1)
'	PumpOff
'	Off 12

	
Fend




Function TrayTakePlaceRepeat(pallet_nr As Integer, col_nr As Integer, row_nr As Integer, ncycles As Integer)

	SetSpeed
	
	Integer i
	For i = 1 To ncycles
		
		Print "Cycle ", i, "/", ncycles
		
		Int64 status
		status = MoveChipFromTrayToTray(pallet_nr, col_nr, row_nr, pallet_nr, col_nr, row_nr, 0)
		If status < 0 Then
			Print "***ERROR!"
			Exit For
		EndIf
	Next i

Fend


Function SocketTakePlaceRepeat(DAT_nr As Integer, socket_nr As Integer, ncycles As Integer)
	
	'Integer pallet_nr, row_nr, col_nr
	'pallet_nr = 1
	'row_nr = 6
	'col_nr = 15

	SetSpeed
	
	'String chip_SN$
	'chip_SN$ = "002-06335"
	
	String fname$
	fname$ = "DAT_" + FmtStr$(DAT_nr, "0") + "_socket_" + "-" + FmtStr$(socket_nr, "0") + "_BottomAna.csv"
	
	Integer fileNum
	fileNum = FreeFile
	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
		
	Integer i
	For i = 1 To ncycles
	
		Print "Cycle ", i, "/", ncycles

		String d$, t$
	 	d$ = Date$
	 	t$ = Time$
        Print #fileNum, d$, " ", t$,


		' Take picture of chip in the socket
		JumpToSocket_camera(DAT_nr, socket_nr)
		' Jump Socket_R_1 :Z(-97.60) +X(58.0) -U(45)
		' DF_take_picture_socket("002-06377", 1)
		String pict_fname_socket$
		'DF_take_picture_socket(chip_SN$, socket_nr, ByRef pict_fname_socket$)
		'DF_take_picture_socket(socket_nr, ByRef pict_fname_socket$)
		Print #fileNum, ",", pict_fname_socket$,
		
		' Pickup from socket
		JumpToSocket(DAT_nr, socket_nr)
		'Go Here +U(45)
		PickupFromSocket
			
		' Take picture of the bottom of the chip
		JumpToCamera
		'Go Here +U(45)
		UF_camera_light_ON
		Wait 1
		String pict_fname_0$
		'UF_take_picture(chip_SN$, ByRef pict_fname_0$)
		'UF_take_picture(ByRef pict_fname_0$)
		'UF_camera_light_OFF
		Print #fileNum, ",", pict_fname_0$,
		
		'JumpToTray(pallet_nr, col_nr, row_nr)
		'PickupFromTray

		' Take picture of the bottom of the chip
		'JumpToCamera
		'UF_camera_light_ON
		'Wait 1
		'UF_take_picture("002-06377")
	
		'Double tray_dx, tray_dy, tray_dU
		VRun ChipBottom_Analy
	
		Boolean ret_found
		Double camera_X, camera_Y
		Double X_0, Y_0, U_0
		Double X_180, Y_180, U_180
		Double X_tool, Y_tool

		'VGet ChipBottom_Analy.Final.RobotXYU, ret_found, ret_X, ret_Y, ret_U
		VGet ChipBottom_Analy.Final.Found, ret_found
		If ret_found Then

			VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
			VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
			
			VGet ChipBottom_Analy.Final.CameraX, X_0
			VGet ChipBottom_Analy.Final.CameraY, Y_0
			VGet ChipBottom_Analy.Final.Angle, U_0

            Print #fileNum, ",", ret_found,
            Print #fileNum, ",", camera_X, ",", camera_Y,
            Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
            'Print #fileNum, ",", camera_X - ret_X, ",", camera_Y - ret_Y

		Else
			
			Print "ERROR 1"
	        Exit For
			
		EndIf


		' Repeat measurement for 180 deg. rotation
		Go Here +U(180)
		Wait 1
		String pict_fname_180$
		'UF_take_picture(chip_SN$ + "-180", ByRef pict_fname_180$)
		'UF_take_picture(ByRef pict_fname_180$)
		Print #fileNum, ",", pict_fname_180$,

		VRun ChipBottom_Analy
	
		VGet ChipBottom_Analy.Final.Found, ret_found
		If ret_found Then

			VGet ChipBottom_Analy.CameraCenter.CameraX, camera_X
			VGet ChipBottom_Analy.CameraCenter.CameraY, camera_Y
			
			VGet ChipBottom_Analy.Final.CameraX, X_180
			VGet ChipBottom_Analy.Final.CameraY, Y_180
			VGet ChipBottom_Analy.Final.Angle, U_180

            Print #fileNum, ",", ret_found,
            Print #fileNum, ",", camera_X, ",", camera_Y,
            Print #fileNum, ",", X_180, ",", Y_180, ",", U_180,
            'Print #fileNum, ",", camera_X - ret_X, ",", camera_Y - ret_Y
		Else
			
			Print "ERROR 2"
	        Exit For
			
		EndIf

		' First correct the rotation
		Go Here -U(180)
		Wait 1

		Double d_U
		d_U = U_0 + 0.6
		If Abs(d_U) < 2.0 Then
			Go Here +U(d_U)
		Else
			Print "ERROR! Rotation angle outside of control margin"
			Exit For
		EndIf


		' Remeasure X and Y with correct rotation
		Wait 1
		'UF_take_picture(chip_SN$, ByRef pict_fname_0$)
		'UF_take_picture(ByRef pict_fname_0$)
        Print #fileNum, ",", pict_fname_0$,
		
		VRun ChipBottom_Analy
		
		VGet ChipBottom_Analy.Final.Found, ret_found
		If ret_found Then
			
			VGet ChipBottom_Analy.Final.CameraX, X_0
			VGet ChipBottom_Analy.Final.CameraY, Y_0
			VGet ChipBottom_Analy.Final.Angle, U_0

            Print #fileNum, ",", ret_found,
            Print #fileNum, ",", X_0, ",", Y_0, ",", U_0,
            'Print #fileNum, ",", camera_X - ret_X, ",", camera_Y - ret_Y

		Else
			
			Print "ERROR 3"
	        Exit For
			
		EndIf



	
		' Return to tray
		'JumpToTray(pallet_nr, col_nr, row_nr)
		'DropToTray
	
		UF_camera_light_OFF
	
		' Put chip back into socket			
		JumpToSocket(DAT_nr, socket_nr)
		Wait 1
		' correct position
		Double d_X, d_Y
		d_X = 0.5 * (X_0 + X_180) - X_0 - 0.227
		d_Y = 0.5 * (Y_0 + Y_180) - Y_0 - 0.141
		'd_U = U_0 + 0.6
		Print #fileNum, ",", d_X, ",", d_Y, ",", d_U
		Print "Correcting chip position: ",
		Print "dX = ", d_X,
		Print "dY = ", d_Y,
		Print "dU = ", d_U
		If Abs(d_X) < 1.0 And Abs(d_Y) < 1.0 And Abs(d_U) < 2.0 Then
			Go Here +X(d_X) +Y(d_Y) +U(d_U)
			InsertIntoSocket
		Else
			Print "ERROR 4"
	        Exit For
		EndIf

	Next i
	
	' Return to tray
	'JumpToTray(1, 15, 6)
	'DropToTray
	
	
	Close #fileNum

	'JumpToSocket("R", 1)
	'InsertIntoSocket

	' Take picture of chip in the socket
	'Jump Socket_R_1 :Z(-97.60) +X(58.0) -U(45)
	'DF_take_picture("002-06377", 1)

	'JumpToTray(1, 15, 6)


	' Pickup from socket
	'JumpToSocket("R", 1)
	'PickupFromSocket

	' Take picture of the bottom of the chip
	'JumpToCamera
	'UF_camera_light_ON
	'Wait 1
	'UF_take_picture("002-06377")
	'UF_camera_light_OFF



Fend


Function TakePlaceRepeat(pallet_nr As Integer, col_nr As Integer, row_nr As Integer, DAT_nr As Integer, socket_nr As Integer, ncycles As Integer)
	
	Integer i
	For i = 1 To ncycles
		
		Print "Cycle ", i, "/", ncycles
		
		Int64 status
		status = MoveChipFromTrayToSocket(pallet_nr, col_nr, row_nr, DAT_nr, socket_nr)

		If status < 0 Then
			Print "***ERROR!"
			Exit For
		EndIf

		status = MoveChipFromSocketToTray(DAT_nr, socket_nr, pallet_nr, col_nr, row_nr)

		If status < 0 Then
			Print "***ERROR!"
			Exit For
		EndIf
	
			
		
	Next i

Fend



