
Function RTS_server
	
	SelectSite("InFunction")
	LoadPositionFiles
	
	DoPinAnalysis = False
	DoOccupancyChecks = True
	
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
    			Input #portNr, socket_nr
    			Input #portNr, pallet_nr
    			Input #portNr, pallet_col
    			Input #portNr, pallet_row
    			Print "Move chip from DAT board: ", DAT_nr, " socket", socket_nr
    			Print " to tray(", pallet_nr, ",", pallet_col, ",", pallet_row, ")",
    			'DO stuff
    			status = MoveChipFromSocketToTray(DAT_nr, socket_nr, pallet_nr, pallet_col, pallet_row)
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
    			Input #portNr, Socket_nr
    			status = SocketPositionOccupied(DAT_nr, Socket_nr)
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

     		Case "InsertIntoSocket"
                InsertIntoSocket
    			Print #portNr, "InsertIntoSocket"
    			
    		Case "DropToSocket"
    			DropToSocket ' Maybe rename for consistency
    			Print #portNr, "DropToSocket"
    			
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
    			
    		Case "PinAnalysisOn"
    			DoPinAnalysis = True
    			Print #portNr, "PinAnalysisOn"
    			
    		Case "PinAnalysisOff"
    			DoPinAnalysis = False
    			Print #portNr, "PinAnalysisOff"
    			
    		Case "OccupancyChecksOn"
    			DoOccupancyChecks = True
    			Print #portNr, "OccupancyChecksOn"
    			Print "DoOccupancyChecks = ", DoOccupancyChecks
    			
    		Case "OccupancyChecksOff"
    			DoOccupancyChecks = False
    			Print #portNr, "OccupancyChecksOff"
    			Print "DoOccupancyChecks = ", DoOccupancyChecks
    			
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

