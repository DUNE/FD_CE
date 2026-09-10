
Function RTS_server
	NotStandalone = True
	
	SelectSite("InFunction")
	' Initialize socket options	using site file
	' even if we change these later
	
	' Use values in site file as defaults while using server
	' Other wise all will default to False
	SocPlaceNotDrop = DefaultPlaceNotDrop ' Defaults to Drop
	SocClampFirst = DefaultClampFirst ' Defaults to clamp after vacuum off
	SocFastClamp = DefaultFastClamp ' defaults to soft/slow clamping
	DoPinAnalysis = DefaultPinAnalysis ' Defaults to not running pin analysis
	SkipOccupancyChecks = DefaultSkipOcc ' Defaults to running occupancy checks 
 	SkipSocketCorrection = DefaultSkipSocCor ' Defaults to applying socket correction
 	SkipChipToChipCorrection = DefaultSkipChipCor ' Defaults to applying chip to chip correction
	
	LoadPositionFiles
	

	
	Integer portNr
	portNr = 201
	String msg$
	SetNet #portNr, "192.168.121.1", 201, CRLF, NONE, 0, TCP, 5
	Print "Starting RTS server..."
	OpenNet #portNr As Server
	Print "Waiting connection to port ", portNr
	WaitNet #portNr
 	'Print #portNr, "Data from host 1"
 	Print "Connection established"
	Print "Sending data to client"
    Print #portNr, "RTS ready"
    
    Int64 status
    Integer pallet_nr, pallet_col, pallet_row, DAT_nr, socket_nr
    Integer src_pallet_nr, src_pallet_col, src_pallet_row, tgt_pallet_nr, tgt_pallet_col, tgt_pallet_row
    String TrayName$
    Integer DoMeasure
    Integer RunSelectSite
    op_ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
    
 	Do
    	Input #portNr, msg$
    	'Line Input #portNr, msg$
    	Print "Received reply: ", msg$
    	Select msg$

    		Case "MoveChipFromTrayToSocket"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, DAT_nr
    			Input #portNr, socket_nr
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			Print "Move chip from pallet(", pallet_nr, ",", pallet_col, ",", pallet_row, ")",
    			Print " to DAT board: ", DAT_nr, " socket", socket_nr
    			'DO stuff
    			status = MoveChipFromTrayToSocket(pallet_nr, pallet_col, pallet_row, DAT_nr, socket_nr)
    			Print #portNr, Str$(status)
    		
    		Case "MoveChipFromSocketToTray"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, DAT_nr
    			Input #portNr, Socket_nr
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			Print "Move chip from DAT board: ", DAT_nr, " socket", Socket_nr
    			Print " to tray(", pallet_nr, ",", pallet_col, ",", pallet_row, ")",
    			'DO stuff
    			status = MoveChipFromSocketToTray(DAT_nr, Socket_nr, pallet_nr, pallet_col, pallet_row)
    			Print #portNr, Str$(status)

    		Case "MoveChipFromTrayToTray"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, src_pallet_nr
    			Input #portNr, src_pallet_col
    			Input #portNr, src_pallet_row
    			Input #portNr, tgt_pallet_nr
    			Input #portNr, tgt_pallet_col
    			Input #portNr, tgt_pallet_row

    			Print "Move chip from pallet(", src_pallet_nr, ",", src_pallet_col, ",", src_pallet_row, ")",
    			Print " to tray(", tgt_pallet_nr, ",", tgt_pallet_col, ",", tgt_pallet_row, ")"
    			status = MoveChipFromTrayToTray(src_pallet_nr, src_pallet_col, src_pallet_row, tgt_pallet_nr, tgt_pallet_col, tgt_pallet_row) ', 0)
    			Print #portNr, Str$(status)
    		
    		Case "CheckTrayPlacement"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			Print "Check placement in tray(", pallet_nr, ",", pallet_col, ",", pallet_row, ")",
    			'DO stuff
    			status = CheckTrayPlacement(pallet_nr, pallet_col, pallet_row)
    			Print #portNr, Str$(status)
    			
    		Case "CheckSocketPlacement"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, DAT_nr
    			Input #portNr, socket_nr
    			Input #portNr, DoMeasure
    			Print "Check placement in DAT board: ", DAT_nr, " socket", socket_nr
    			Print "Precise measurement set to ", DoMeasure
    			'DO stuff
    			status = CheckSocketPlacement(DAT_nr, socket_nr, DoMeasure)
    			Print #portNr, Str$(status)
    			
    		Case "ReseatChipInSocket"
    			PumpOn
    			' Receive source and destination parameters"
    			Input #portNr, DAT_nr
    			Input #portNr, socket_nr
    			Print "Reseat chip in socket: ", DAT_nr, " socket", socket_nr
    			'Jump Pallet(1, 15, 6) :Z(-10)
    			'DO stuff
    			status = ReseatChipInSocket(DAT_nr, socket_nr)
    			' SPEL "True" is -1, but integration code treets all negative values as errors	
    			If status = -1 Then
    				status = 0
    			EndIf
    			
    			Print #portNr, Str$(status)
    			
     		Case "JumpToTray"
    			' Receive source and destination parameters"
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			Print "Move chip to Tray(", pallet_nr, ",", pallet_col, ",", pallet_row, ")",
    			status = JumpToTray(pallet_nr, pallet_col, pallet_row)
    			Print #portNr, "JumpToTray(", pallet_nr, ",", pallet_col, ",", pallet_row, ")"

			Case "ScanTray"
				Input #portNr, pallet_nr
				Input #portNr, TrayName$
				status = ScanTray(pallet_nr, TrayName$)
				Print #portNr, status
				Print #portNr, "DONE"
				
			Case "CheckTrayOccupancy"
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			status = TrayPositionOccupied(pallet_nr, pallet_col, pallet_row)
    			Print #portNr, status
   
  			Case "CheckSocketOccupancy"
    			Input #portNr, DAT_nr
    			Input #portNr, socket_nr
    			status = SocketPositionOccupied(DAT_nr, socket_nr)
    			Print #portNr, status
				
     		Case "PickupFromTray"
     			PumpOn
                PickupFromTray
    			Print #portNr, "PickupFromTray"

     		Case "DropToTray"
                DropToTray
    			Print #portNr, "DropToTray"

     		Case "PickupFromSocket"
     			PumpOn
                PickupFromSocket
    			Print #portNr, "PickupFromSocket"
    			
            Case "PlaceInSocket"
    			PlaceInSocket
    			Print #portNr, "PlaceInSocket"
    			
    		Case "UseSiteFileRobotConfigOptions"
    			' Resets to default values if values have been
    			' changed by server commands
       			Print "UseSiteFileRobotConfigOptions called over server"
    			SelectSite("InFunction")
				SocPlaceNotDrop = DefaultPlaceNotDrop
				SocClampFirst = DefaultClampFirst
				SocFastClamp = DefaultFastClamp
				DoPinAnalysis = DefaultPinAnalysis
				SkipOccupancyChecks = DefaultSkipOcc
			 	SkipSocketCorrection = DefaultSkipSocCor
			 	SkipChipToChipCorrection = DefaultSkipChipCor

				Print #portNr, "UseSiteFileRobotConfigOptions"
    		
    		Case "TestOptionsFromServer"
    			Print "TestSocketOptions called over server"
    			Input #portNr, RunSelectSite
    			TestOptionsFromServer(RunSelectSite)
    			Int32 TestOptions
    			TestOptions = 0
    			
    			If DoPinAnalysis Then
    				TestOptions = TestOptions + 1000000
    			EndIf
    			If SkipOccupancyChecks Then
    				TestOptions = TestOptions + 100000
    			EndIf
    			If SkipSocketCorrection Then
    				TestOptions = TestOptions + 10000
    			EndIf
    			If SkipChipToChipCorrection Then
    				TestOptions = TestOptions + 1000
    			EndIf
    			
    			If SocPlaceNotDrop Then
    				TestOptions = TestOptions + 100
    			EndIf
    			If SocClampFirst Then
    				TestOptions = TestOptions + 10
    			EndIf
    			If SocFastClamp Then
    				TestOptions = TestOptions + 1
    			EndIf
    			Print "TestOptions = ", TestOptions
    			Print #portNr, TestOptions
    			
    		Case "JumpToCamera"
    			JumpToCamera
    			Print #portNr, "JumpToCamera"
    			
    		Case "MotorOn"
    			Motor On
    			Print #portNr, "Motor On"
    			
    		Case "MotorOff"
    			Motor Off
    			Print #portNr, "Motor Off"
    			
    		Case "PumpOn"
    			PumpOn
    			Print #portNr, "PumpOn"
    			
    		Case "PumpOff"
    			PumpOff
    			Print #portNr, "PumpOff"

    		Case "Quiet"
		    	PumpOff
		    	JumpToCamera
		    	Motor Off
		    	Print #portNr, "RTS Quiet"
		    	'CloseNet #portNr
		    	'Wait 1
	    		'OpenNet #portNr As Server
				'Print "Waiting connection to port ", portNr
				'WaitNet #portNr
 				''Print #portNr, "Data from host 1"
 				'Print "Connection established"
				'Print "Sending data to client"
    			'Print #portNr, "RTS ready"
    			
    		Case "SelectSite"
    			SelectSite("")
    			Print #portNr, "SelectSite"
    			
    		Case "LoadPositionFiles"
    			LoadPositionFiles
    			Print #portNr, "LoadPositionFiles"
    			
    		Case "UpdatePositionFiles"
    			UpdatePositionFiles
    			Print #portNr, "UpdatePositionFiles"
    			
    		' Pin analysis setting
    		Case "PinAnalysisOn"
    			DoPinAnalysis = True
    			Print #portNr, "PinAnalysisOn"
    			
    		Case "PinAnalysisOff"
    			DoPinAnalysis = False
    			Print #portNr, "PinAnalysisOff"
    		
    		' Occupancy check setting
    		Case "OccupancyChecksOn"
    			SkipOccupancyChecks = False
    			Print #portNr, "OccupancyChecksOn"
    			Print "SkipOccupancyChecks = ", SkipOccupancyChecks
    			
    		Case "OccupancyChecksOff"
    			SkipOccupancyChecks = True
    			Print #portNr, "OccupancyChecksOff"
    			Print "SkipOccupancyChecks = ", SkipOccupancyChecks
    			
    		' Socket corrections
    		Case "SocketCorrectionOn"
    			SkipSocketCorrection = False
    			Print #portNr, "SocketCorrectionOn"
    			Print "SkipSocketCorrection = ", SkipSocketCorrection
    		
    		Case "SocketCorrectionOff"
    			SkipSocketCorrection = True
    			Print #portNr, "SocketCorrectionOff"
    			Print "SkipSocketCorrection = ", SkipSocketCorrection
    		
    		'Chip to chip corrections
    		Case "ChipToChipCorrectionOn"
    			SkipChipToChipCorrection = False
    			Print #portNr, "ChipToChipCorrectionOn"
    			Print "SkipChipToChipCorrection = ", SkipChipToChipCorrection
    			    	
    		Case "ChipToChipCorrectionOff"
    			SkipChipToChipCorrection = True
    			Print #portNr, "ChipToChipCorrectionOff"
    			Print "SkipChipToChipCorrection = ", SkipChipToChipCorrection
    			
    		' Socket placement operation settings
    		Case "DoPlaceAtSocket"
    			Print "DoPlaceAtSocket called over server"
    			SocPlaceNotDrop = True
    			Print #portNr, "DoPlaceAtSocket"
    			
    		Case "DoDropAtSocket"
    			Print "DoDropAtSocket called over server"
    			SocPlaceNotDrop = False
    			Print #portNr, "DoDropAtSocket"
    		
    		Case "ClampThenVacuumOffAtSocket"
    			Print "ClampThenVacuumOffAtSocket called over server"
    			SocClampFirst = True
    			Print #portNr, "ClampThenVacuumOffAtSocket"
    			
    		Case "VacuumOffThenClampAtSocket"
    			Print "VacuumOffThenClampAtSocket called over server"
    			SocClampFirst = False
    			Print #portNr, "VacuumOffThenClampAtSocket"
    			
    		Case "FastSocketClamping"
    			Print "FastSocketClamping called over server"
    			SocFastClamp = True
    			Print #portNr, "FastSocketClamping"
    			
    		Case "SoftSocketClamping"
    			Print "SoftSocketClamping called over server"
    			SocFastClamp = False
    			Print #portNr, "SoftSocketClamping"
    			
    		Case "Shutdown"
		    	CloseNet #portNr
		    	PumpOff
		    	JumpToCamera
		    	Motor Off
		    	Exit Do
		    	
    		Case "Disconnect"
		    	CloseNet #portNr
		    	Wait 1
	    		OpenNet #portNr As Server
				Print "Waiting connection to port ", portNr
				WaitNet #portNr
 				'Print #portNr, "Data from host 1"
 				Print "Connection established"
				Print "Sending data to client"
    			Print #portNr, "RTS ready"
   	
		    	
    	Send
	Loop
	
	UpdatePositionFiles
	
Fend

