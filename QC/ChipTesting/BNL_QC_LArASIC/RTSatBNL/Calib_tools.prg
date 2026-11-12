' Automatic Calibration of upfacing camera using Stinger
Function UF_Calib_Stinger
	Jump P_Camera
	On 12
	' Run Calib_UF_Stinger manually
	VCal Calib_UF_Stinger
    Off 12
Fend

Function UF_Calib_Stinger_vs_U
	Jump P_Camera
	On 12

	' Initial U position
	Double Ui
	'U0 = CU(Here)
	Integer fileNum
	fileNum = FreeFile
	WOpen "C:\Users\coldelec\RTS\calib\Stinger_xy_vs_U.csv" As #fileNum
	Integer i, nPoints
    Double ret_X, ret_Y, ret_U
    Boolean ret_found
	nPoints = 50
    VRun Stinger_find
	For i = 0 To nPoints
		Ui = i * 355 / nPoints
		Go Here :U(Ui)
    	VRun Stinger_find
    	VGet Stinger_find.Geom01.RobotXYU, ret_found, ret_X, ret_Y, ret_U
        If Not ret_found Then
        	Print "ERROR"
        EndIf
 		Print #fileNum, i, ",", Ui, ",", ret_found, ",", ret_X, ",", ret_Y
	Next i
	Close #fileNum
Fend

' Remove trays for this calibrations
Function DF_Calib_Mark
	Jump P_Stinger_Calib_DF
	' Run Calib_UF_Stinger manually
	VCal Calib_DF_mark
Fend


Function View_Socket_R(socket_nr As Integer)
	Jump P(10 + socket_nr) +X(62.4) :Z(-98)
    Double ret_X, ret_Y, ret_U
    Boolean ret_found
	VRun Socket_check
    VGet Socket_check.Point05.RobotXYU, ret_found, ret_X, ret_Y, ret_U
Fend


