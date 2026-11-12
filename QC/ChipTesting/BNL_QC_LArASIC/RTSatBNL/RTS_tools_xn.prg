#include "RTS_tools.inc"

Function calibrate_socket(DAT_nr As Integer, socket_nr As Integer)
	Print
	'Print socket_nr, "**********************************************"
	
	Double uerr
  	Randomize
	uerr = Rnd(3) - 1.5
	Print uerr
	JumpToSocket_camera(DAT_nr, socket_nr)
	Go Here +U(uerr)
	'Go Here +Y(DF_CAMERA_OFFSET / 2)
	'Go Here -X(DF_CAMERA_OFFSET - DF_CAMERA_OFFSET / 2 * 1.73)
	
	'Add error: x:  0.888672y:  -0.798645
	'Go Here +X(0.888672)
	'Go Here +Y(-0.798645)
	
	'Add a position fluctuation for test, only for test!!!	
	
	'Real r_x
  	'Randomize
  	'r_x = Rnd(3) - 1.5
  	
  	'Real r_y
    'Randomize
    'r_y = Rnd(3) - 1.5
  	
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
	Double x_p1_cam, y_p1_cam, x_p2_cam, y_p2_cam, x_p3_cam, y_p3_cam
	
	'VGet skt_cali_test.CameraCenter.RobotXYU, found, x_ori, y_ori, a_ori
	Double check
	check = 100
	Integer N_round
	N_round = 0
	
	Do Until check < 20 And check > -20 Or N_round > 10
		VRun skt_cali_test
		VGet skt_cali_test.Geom01.RobotXYU, Isfound1, x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom01.CameraXYU, Isfound1, x_p1_cam, y_p1_cam, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, Isfound2, x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom02.CameraXYU, Isfound2, x_p2_cam, y_p2_cam, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, Isfound3, x_p3, y_p3, a_p3
		VGet skt_cali_test.Geom03.CameraXYU, Isfound3, x_p3_cam, y_p3_cam, a_p3

		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
		Double x_c, y_c
		x_c = (x_p1 + x_p3) /2
		y_c = (y_p1 + y_p3) /2
		
		Double sin_ang, sin_ang2, ang, ang2
		sin_ang = (x_p1_cam - x_p2_cam) / Sqr((x_p1_cam - x_p2_cam) * (x_p1_cam - x_p2_cam) + (y_p1_cam - y_p2_cam) * (y_p1_cam - y_p2_cam))

		ang = Asin(sin_ang) / PI * 180


		Print "corr_center: ", x_c, y_c, ang,

		JumpToSocket(DAT_nr, socket_nr)
		Go Here +U(uerr)
		Print CU(Here)
		
		Jump Here :X(x_c) :Y(y_c)
		Go Here +U(ang)
		Print "corr_actual: ", Here
		'Print "Correctly found"
	EndIf
	
	
	'Print "HERE: ", Here
	'Print "ori_center: ", x_ori, y_ori
	'Print "corr_center: ", x_c, y_c
	'Print P(20 + socket_nr) :Z(-132.5)
	
	'Double A_line
	
	'VGet skt_cali_test.LineFind01.Angle, A_line
	'Print A_line
	'Print CX(Here) - DF_CAMERA_OFFSET, CY(Here), x_c, y_c

	
	
Fend

Function JumpToSocket_cor(DAT_nr As Integer, socket_nr As Integer, fileNum As Integer)
	'Print
	'Print socket_nr, "**********************************************"
	
	JumpToSocket_camera(DAT_nr, socket_nr)
	UF_camera_light_ON
	
	VRun skt_cali_test
	
	Boolean Isfound1, Isfound2, Isfound3
	Boolean found
	
	Double x_p1, y_p1, a_p1, x_p2, y_p2, a_p2, x_p3, y_p3, a_p3
	Double x_ori, y_ori, a_ori
	Double x_p1_cam, y_p1_cam, x_p2_cam, y_p2_cam, x_p3_cam, y_p3_cam
	
	'VGet skt_cali_test.CameraCenter.RobotXYU, found, x_ori, y_ori, a_ori
	Double check
	check = 100
	Integer N_round
	N_round = 0
	
	Do Until check < 20 And check > -20 Or N_round > 10
		VRun skt_cali_test
		VGet skt_cali_test.Geom01.RobotXYU, Isfound1, x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom01.CameraXYU, Isfound1, x_p1_cam, y_p1_cam, a_p1
		'Print "P1 xyu: ", x_p1, y_p1, a_p1
		VGet skt_cali_test.Geom02.RobotXYU, Isfound2, x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom02.CameraXYU, Isfound2, x_p2_cam, y_p2_cam, a_p2
		'Print "P2 xyu: ", x_p2, y_p2, a_p2
		VGet skt_cali_test.Geom03.RobotXYU, Isfound3, x_p3, y_p3, a_p3
		VGet skt_cali_test.Geom03.CameraXYU, Isfound3, x_p3_cam, y_p3_cam, a_p3
		'Print "P3 xyu: ", x_p3, y_p3, a_p3
	
		check = (x_p1 - x_p2) * (x_p3 - x_p2) - (y_p1 - y_p2) * (y_p3 - y_p2)
		N_round = N_round + 1
		'Print "perpendicular check: ", check, " Loop: ", N_round
	
	Loop
	
	UF_camera_light_OFF
	
	If check < 20 And check > -20 Then
		Print "Correctly found"
		Double x_c, y_c
		x_c = (x_p1 + x_p3) /2
		y_c = (y_p1 + y_p3) /2
		
		Double sin_ang, sin_ang2, ang, ang2
		sin_ang = (x_p1_cam - x_p2_cam) / Sqr((x_p1_cam - x_p2_cam) * (x_p1_cam - x_p2_cam) + (y_p1_cam - y_p2_cam) * (y_p1_cam - y_p2_cam))

		ang = Asin(sin_ang) / PI * 180


		Print "corr_center: ", x_c, y_c, ang

		JumpToSocket(DAT_nr, socket_nr)
		'Print CU(Here)
		
		Jump Here :X(x_c) :Y(y_c)
		Go Here +U(ang)
		Print "corr_actual: ", Here
	Else
		JumpToSocket(DAT_nr, socket_nr)
		Print "socket correction fail"
	EndIf

	Print #fileNum, ",", DAT_nr, ",", socket_nr, ",", x_c, ",", y_c, ",", CU(Here),
	
	
	
Fend

Function Socket_height_calibration(DAT_nr As Integer, socket_nr As Integer, fileNum As Integer)

	JumpToSocket_cor(DAT_nr, socket_nr, fileNum)
	Speed 1
	Accel 1, 1
	
	Double h_tot, h_step
	h_tot = 10
	h_step = 1
	Go Here -Z(h_tot)
	Do Until isContactSensorTouches Or h_tot > 15
		Go Here -Z(h_step)
    	Wait 0.5
    	h_tot = h_tot + h_step
    Loop
    Print DAT_nr, socket_nr, h_tot
    Socket_height_calibration = h_tot
    Print #fileNum, h_tot
	SetSpeed
	
Fend
Function Socket_height_calibration_all()
	String skt_calibration$
	skt_calibration$ = RTS_DATA + "skt_calibration/"
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	String fname$
	fname$ = ts$ + "socket_calibration.csv"
	Print fname$
	Integer fileNum
	fileNum = FreeFile
	AOpen skt_calibration$ + fname$ As #fileNum
	
	Socket_height_calibration(2, 1, fileNum)
	Socket_height_calibration(2, 2, fileNum)
	Socket_height_calibration(2, 3, fileNum)
	Socket_height_calibration(2, 4, fileNum)
	Socket_height_calibration(2, 5, fileNum)
	Socket_height_calibration(2, 6, fileNum)
	Socket_height_calibration(2, 7, fileNum)
	Socket_height_calibration(2, 8, fileNum)
	
	
	Close #fileNum
	
Fend


