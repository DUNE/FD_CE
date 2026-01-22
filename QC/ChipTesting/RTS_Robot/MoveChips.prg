#include "RTS_tools.inc"
#include "ErrorDictionary.inc"
'
''
'' INPUT: 
''        pallet_nr - pallet number of the chip source (1-left, 2-right)
''        col_nr - column number in the pallet (1-15)
''        row_nr - row number in the pallet (1-6)
''        DAT_nr - DAT board target (1-left, 2-right)
''        socket_nr - socket target (1-8)
''
'' RETURN:
''        > 0 - job_id (timestamp)
''        < 0 - Error id
'
'

'''' MSU WRITTEN FUNCTIONS ''''
'''' Move chip to and from tray/socket functions
' Should broadly match old BNL functions

''' For a given socket, remove current chip and place in target tray position and replace with new chip from source tray position
'' Args:
' DAT, Socket - The DAT board number and socket position
' SrcTray, SrcTrayCol, SrcTrayRow - The source tray position for the NEW chip (to place in socket next)
' TgtTray, TgtTrayCol, TgtTrayRow - The target tray position for the OLD chip (currently in socket)
Function SwapChipsInSocket(DAT As Integer, Socket As Integer, SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	UpdateRobotLog$("Starting SwapChipsInSocket")
	MoveChip(SrcTray, SrcTrayCol, SrcTrayRow, TgtTray, TgtTrayCol, TgtTrayRow, DAT, Socket, DAT, Socket, True, False)
Fend

''' Pick a chip up from an occupied tray position and move it to an empty socket
'' Args:
' DAT, Socket - The DAT board number and socket position for the socket to be filled
' Tray, TrayCol, TrayRow - The position of the chip on in the tray to pick up and put in the socket
Function MoveChipFromTrayToSocket(DAT As Integer, Socket As Integer, Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromTrayToSocket")
	MoveChip(Tray, TrayCol, TrayRow, 0, 0, 0, 0, 0, DAT, Socket, True, False)
Fend

''' Pick a chip up from an occupied socket and place it in an empty tray position
'' Args:
' DAT, Socket - The DAT board number and socket position for the socket with a chip in it
' Tray, TrayCol, TrayRow - The position to place the tray in the socket
Function MoveChipFromSocketToTray(DAT As Integer, Socket As Integer, Tray As Integer, TrayCol As Integer, TrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromSocketToTray")
	MoveChip(0, 0, 0, Tray, TrayCol, TrayRow, DAT, Socket, 0, 0, True, False)
Fend

''' Pick up a chip from one occupied tray position and place it in a new empty tray position
'' Args:
' SrcTray, SrcTrayCol, SrcTrayRow - The source tray position the chip currently occupies
' TgtTray, TgtTrayCol, TgtTrayRow - The empty target tray position to move the chip to
Function MoveChipFromTrayToTray(SrcTray As Integer, SrcTrayCol As Integer, SrcTrayRow As Integer, TgtTray As Integer, TgtTrayCol As Integer, TgtTrayRow As Integer) As Int64
	UpdateRobotLog$("Starting MoveChipFromTrayToTray")
	MoveChip(SrcTray, SrcTrayCol, SrcTrayRow, TgtTray, TgtTrayCol, TgtTrayRow, 0, 0, 0, 0, True, False)
Fend

''' This MoveChip command handles moving chips from any source tray or socket position to any other target tray or socket position
' Other Move commands wrap this. The logic here is to force consistency in operations and logging in one place
' - First the command checks that a set of valid positions have been passed (indices in range, not repeated etc)
' - Then the starting occupancies of the source and target positions are checked* this can be overriden
' - Then a series of suboperations are used to pick and place chips, and arrays for results are past by reference to these
'   allowing results from one function to be passed to the relevant next function for pick/place
' Operations are ordered to reduce overall number of back and forth motions between tray and DAT board.
' Note, currently this allows for the occupancy checks to be overriden, in order to allow for the implementation
' of a set of batch movements, in which all the occupancies would be checked at once before moving any chips
' We do not expect these occupancies to change during operations unless something has gone wrong
' which should be detected.
'' Args:
' SrcTray, SrcTrayCol, SrcTrayRow - The source tray position
' TgtTray, TgtTrayCol, TgtTrayRow - The target tray position
' SrcDAT, SrcSocket - The source socket position
' TgtDAT, TgtSocket - The target socket position
' OccCheck - Do occupancy checks before moving
' DoT2TPinAnalysis - Do pin analysis when moving from one tray position to another, this is forced in other cases in order to get the precise position at the socket
Function MoveChip(SrcTray As Int32, SrcTrayCol As Int32, SrcTrayRow As Int32, TgtTray As Int32, TgtTrayCol As Int32, TgtTrayRow As Int32, SrcDAT As Int32, SrcSocket As Int32, TgtDAT As Int32, TgtSocket As Int32, OccCheck As Boolean, DoT2TPinAnalysis As Boolean) As Int64
	SubError = 0
	' Main function for moving chips, keeps formating consistent and does checks for valid operations and occupancies (unless overriden for batch operation) 
	
	String ts$
	ts$ = FmtStr$(Date$ + " " + Time$, "yyyymmddhhnnss")
	
	MoveChip = Val(ts$)

	SetSpeedSetting("")
	
	String fname$
	fname$ = "manip.csv"
	
	Integer fileNum
	fileNum = FreeFile

	AOpen RTS_DATA$ + "\" + fname$ As #fileNum
	
	Print #fileNum, ts$, ",",
	
	' If starting with an empty socket
	Double Empty_S_Results(10)
		
	' From socket to tray
	Double S2T_S_Results(16) ' Chip in Socket to go to (target) tray
	Double S2T_C_Results(13) ' Chip from socket to go to tray at UF Camera
 	Double S2T_T_Results(10) ' Chip from socket placed in Tray

	' From tray to socket
	Double T2S_T_Results(10) ' Chip in (source) Tray to go to socket
	Double T2S_C_Results(13)
	Double T2S_S_Results(16)

	' From tray to tray
	Double T2T_ST_Results(10) ' Chip in initial (Source) tray position
	Double T2T_TT_Results(10) ' Chip in final (Target) tray position
	Double T2T_C_Results(13)
	
	' From socket to socket
	Double S2S_SS_Results(16)
	Double S2S_TS_Results(16)
	Double S2S_C_Results(13)
	
	String Images$(14)
	String UFCImages1$(5)
	String UFCImages2$(5)
	' Most images to store when swapping two chips
	' If occupancy check fails, just store occupancy check image , otherwise
	' 1 - Source tray image
	' 2 - Target tray image
	' 3 - Source socket image
	' 4 - Target socket image
	' 5 - Chip1 UFC 1st measurement
	' 6 - Chip1 UFC 2nd measurement
	' 7 - Chip1 UFC Pin analysis center
	' 8 - Chip1 UFC Pin analysis left
	' 9 - Chip1 UFC Pin analysis right
	' 10 - Chip2 UFC 1st measurement
	' 11 - Chip2 UFC 2nd measurement
	' 12 - Chip2 UFC Pin analysis center
	' 13 - Chip2 UFC Pin analysis left
	' 14 - Chip2 UFC Pin analysis right	
	
	' initialize the results arrays for the vision sequences
	Int32 i
	For i = 1 To 16
		If i < 11 Then
			Empty_S_Results(i) = 0
			S2T_T_Results(i) = 0
			T2S_T_Results(i) = 0
			T2T_ST_Results(i) = 0
			T2T_TT_Results(i) = 0
		EndIf
		If i < 13 Then
			S2T_C_Results(i) = 0
			T2S_C_Results(i) = 0
			T2T_C_Results(i) = 0
		EndIf
		If i < 15 Then
			Images$(i) = ""
		EndIf
		If i < 5 Then
			UFCImages1$(i) = ""
			UFCImages2$(i) = ""
		EndIf
		S2T_S_Results(i) = 0
		T2S_S_Results(i) = 0
		S2S_SS_Results(i) = 0
		S2S_TS_Results(i) = 0

	Next

	Integer idx(20)
	For i = 1 To 20
		idx(i) = 0
	Next i
	
	idx(1) = fileNum
	
	idx(2) = SrcTray
	idx(3) = SrcTrayCol
	idx(4) = SrcTrayRow
	
	idx(5) = TgtTray
	idx(6) = TgtTrayCol
	idx(7) = TgtTrayRow
	
	idx(8) = SrcDAT
	idx(9) = SrcSocket
	
	idx(10) = TgtDAT
	idx(11) = TgtSocket
	
	' Check whether the input indices are valid (within range etc)
	Integer Op
	String operation$
	Operation$ = "Invalid"
	
	Op = CheckOperationType(ByRef idx(), ByRef Operation$)
	If Op < 0 Then
		Print "Invalid operation type"
		MoveChip = -ERR_BAD_COMMAND
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		RTS_error(fileNum, "Invalid operation")
	EndIf
	UpdateRobotLog$("Operation type determined to be " + Operation$)
	' Do checks of socket and tray occupancies
	' Expected intial occupancies
	'              Socket  |  Source  |  Target
	' T2S only  :    0     |     1    |   N/A
	' S2T + T2S :    1     |     1    |    0
	' S2T only  :    1     |    N/A   |    0
	' T2T       :   N/A    |     1    |    0
	
	' If checking the occupancy check the occupancies TODOJOE wrap in if statement?
	SetSpeedSetting("MoveWithoutChip")
	Int32 Occupancy
	String OccupancyImage$
	Occupancy = CheckOperationOccupancy(ts$, ByRef idx(), operation$, ByRef OccupancyImage$)
	If Occupancy <> 0 Then
		Select Occupancy
			Case -1
				MoveChip = -ERR_V_NOCHIP
			Case -2
				MoveChip = -ERR_V_OCCUPIED
			Case -3
				MoveChip = -ERR_V_NOCHIP
			Case -4
				MoveChip = -ERR_V_OCCUPIED
			Case -5
				MoveChip = -ERR_OBSTRUCTION
			Default
				MoveChip = -ERR_OBSTRUCTION ' Shoulnd't get here
		Send
		Images$(1) = OccupancyImage$
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		RTS_error(fileNum, "Occupancy check fail, occupancy result : " + Str$(Occupancy))
		Exit Function
	EndIf
	
	SetSpeedSetting("MoveWithoutChip")

	' Now we have done occupancy checks, do pick and place 
	' DeltaDir is the difference in the direction of the chip and the hand at the socket - as measured for precision
	Double DeltaDir
	
	' Note, a correction is calculated when placing a chip in the socket based on the last chip removed	
	' This is done in the place function
	
	' Do socket to tray first in case of swap chips (S->T then T->S)
	'If DoS2T Then
	If Operation$ = "REMOVECHIP" Or Operation$ = "SWAPCHIPS" Then
		Print "Moving chip from socket (", idx(8), ",", idx(9), ") to tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		' Images$(3) - Source socket image
		If Not GetChipFromSocket(ts$, ByRef idx(), ByRef S2T_S_Results(), ByRef S2T_C_Results(), ByRef DeltaDir, ByRef Images$(3), ByRef UFCImages1$()) Then
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
			MoveChip = SubError
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			RTS_error(fileNum, "Failed to get chip from socket")
			Exit Function
		EndIf
		For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
		Next
		' Images$(2) - Target tray image
		If Not PlaceChipInTray(ts$, ByRef idx(), ByRef S2T_T_Results(), ByRef DeltaDir, ByRef Images$(2)) Then
			MoveChip = SubError
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			RTS_error(fileNum, "Failed to place chip in tray")
			Exit Function
		EndIf
	EndIf
	
'	If DoT2S Then
	If Operation$ = "LOADCHIP" Or Operation$ = "SWAPCHIPS" Then
		Print "Moving chip from tray (", idx(2), ",", idx(3), ",", idx(4), ") to socket (", idx(10), ",", idx(11), ")"
		' Images$(1) - Source tray image	
		If Not GetChipFromTray(ts$, ByRef idx(), ByRef T2S_T_Results(), ByRef DeltaDir, ByRef Images$(1)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to get chip from tray")
			Exit Function
		EndIf
		' Images$(4) - Target socket image	
		If Not PlaceChipInSocket(ts$, ByRef idx(), ByRef Empty_S_Results(), ByRef T2S_C_Results(), ByRef T2S_S_Results(), ByRef Images$(4), ByRef UFCImages2$()) Then
			For i = 1 To 5
				Images$(i + 9) = UFCImages2$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in socket")
			Exit Function
		EndIf
		For i = 1 To 5
			Images$(i + 9) = UFCImages2$(i)
		Next
	EndIf
	
	' If successful for socket-tray operation, log and close the file and exit
	If Operation$ = "LOADCHIP" Or Operation$ = "REMOVECHIP" Or Operation$ = "SWAPCHIPS" Then
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef S2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
		Print ""
		Close #fileNum
		MoveChip = 0
		UpdatePositionFiles
		Exit Function
	EndIf



	' Should only get here for T2T or S2S
'	If DoT2T Then 
	If Operation$ = "T2T" Then
		Print "Moving chip from tray (", idx(2), ",", idx(3), ",", idx(4), ") to tray (", idx(5), ",", idx(6), ",", idx(7), ")"
		' Images$(1) - Source tray image	
		If Not GetChipFromTray(ts$, ByRef idx(), ByRef T2T_ST_Results(), ByRef DeltaDir, ByRef Images$(1)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to get chip from tray")
			Exit Function
		EndIf
		
		If DoT2TPinAnalysis Then
			' UF analysis is otherwise included in the socket related functions to ensure it is always called
			If Not UFGetChipAlignment(ts$, ByRef idx(), ByRef T2T_C_Results(), ByRef UFCImages1$()) Then
				MoveChip = -ERR_V_UF_ALIGN
				For i = 1 To 5
					Images$(i + 4) = UFCImages1$(i)
				Next
				LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
				RTS_error(fileNum, "Cannot get chip position and aligment with up facing camera")
				Exit Function
			EndIf
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
		EndIf
		' Images$(2) - Target tray image
		If Not PlaceChipInTray(ts$, ByRef idx(), ByRef T2T_TT_Results(), ByRef DeltaDir, ByRef Images$(2)) Then
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in tray")
			Exit Function
		EndIf
		
		' Need to chaneg UFC1 results
		' Log here because we use different vectors for results in this case
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2T_S_Results(), ByRef T2S_S_Results(), ByRef T2T_C_Results(), ByRef T2S_C_Results(), ByRef Images$())
	EndIf

	If Operation$ = "S2S" Then ' Or Operation$ = "REINSERT"
		Print "Moving chip from socket (", idx(8), ",", idx(9), ") to socket (", idx(10), ",", idx(11), ")"
		If Not GetChipFromSocket(ts$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_C_Results(), ByRef DeltaDir, ByRef Images$(3), ByRef UFCImages1$()) Then
			For i = 1 To 5
				Images$(i + 4) = UFCImages1$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to pick up chip from socket")
			Exit Function
		EndIf
		If Not PlaceChipInSocket(ts$, ByRef idx(), ByRef Empty_S_Results(), ByRef S2S_C_Results(), ByRef S2S_TS_Results(), ByRef Images$(4), ByRef UFCImages2$()) Then
			For i = 1 To 5
				Images$(i + 9) = UFCImages2$(i)
			Next
			LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
			MoveChip = SubError
			RTS_error(fileNum, "Failed to place chip in socket")
			Exit Function
		EndIf
		For i = 1 To 5
			Images$(i + 4) = UFCImages1$(i)
			Images$(i + 9) = UFCImages2$(i)
		Next
		LogResults(ts$, MoveChip, operation$, ByRef idx(), ByRef S2S_SS_Results(), ByRef S2S_TS_Results(), ByRef S2S_C_Results(), ByRef S2S_C_Results(), ByRef Images$())
	EndIf
	
	Print ""
	Close #fileNum
	UpdatePositionFiles
	MoveChip = 0
	
Fend



