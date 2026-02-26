'#define REPO_DIR "C:\EpsonRC70\Projects\DUNE\CE-RTS"
'#define RTS_DATA "C:\Users\coldelec\RTS\"
#define NTRAYS 2
#define TRAY_NCOLS 15 ' For TRAY and DAT arays use maximum size
#define TRAY_NROWS 6 ' DO NOT CHANGE For COLDATA - SEE trayNCols VARIABLE USAGE
#define TRAY_NCOLS_S 15
#define TRAY_NROWS_S 6
#define TRAY_NCOLS_L 10
#define TRAY_NROWS_L 4
Global Int32 trayNCols ' Set to correct chip layout for loops
Global Int32 trayNRows

#define N_LARASIC_SOC 8
#define N_COLDADC_SOC 8
#define N_COLDATA_SOC 2
#define N_MSU_TEST_SOC 8
#define NSOCKETS 22
Global Int32 nSoc ' Set by chip type for testing

#define CONTACT_DIST 10.0
#define DROP_DIST 2.0

#define JUMP_LIMIT -20.

Global Double PickOffset

Global String REPO_DIR$
Global String PROJ_DIR$
Global String RTS_DATA$

Global String SITE$
Global String CHIPTYPE$
Global Int32 CHIPTYPE_NR
Global String POINTS_FILE$
Global Double HAND_U0
Global Double REST_J4
Global Double DF_CAM_X_OFF_U0
Global Double DF_CAM_Y_OFF_U0
Global Double DF_CAM_Z_OFF
Global Double DF_CAM_FOCUS

' corrections for the trays
Global Double tray_X(NTRAYS, TRAY_NCOLS, TRAY_NROWS)
Global Double tray_Y(NTRAYS, TRAY_NCOLS, TRAY_NROWS)
Global Double tray_U(NTRAYS, TRAY_NCOLS, TRAY_NROWS)

' corrections for the sockets
Global Double DAT_X(2, NSOCKETS)
Global Double DAT_Y(2, NSOCKETS)
Global Double DAT_U(2, NSOCKETS)

' Store the offset between U and agl4 at each position
Global Double tray_Agl4Off(NTRAYS, TRAY_NCOLS, TRAY_NROWS)
Global Double socket_Agl4Off(NTRAYS, TRAY_NCOLS, TRAY_NROWS)

'' chip SN
''Global String chip_SN$
Global Double CornerVar(3)
Global Double ChipPos(3)
Global Double UFChipPos(3)
Global Double SockPos(3)

''' For simplified pick and place
Global Double CurrentChipOffset(3)
Global Double CorrectedChipOffset(3)
Global Double SocketOffset(3)
Global Double CSAlign(5)

Global Double ChipToChipCorrection(3)

'' To be set in set site values, the offset between vision sequence U and world coordinates
Global Double ChipTextOrientation
'' Need to correct for overshoot in position vision, check with alignment
Global Double ChipVisionOffset(3)
Global Double SocketVisionOffset(3)
'
'' In increments of 90 degrees from X axis, U0 offsets and socket find should
'' account for sub-90 degree variations between sockets and different RTS robots
Global Double TrayOrientation ' Default direction for chips in tray - in world coordinates

Global Double HandChipOrientation(3) ' Diretcion of chip relative to Hand U at socket

' Define the distance between the fiducial markers on LArASIC
#define LArASICDimension 14.0 ' Need to measure
#define COLDATATextOffset 4.6 ' Need to measure

#define TolXY 0.5
#define TolAngle 2.

' Using a non DAT board layout for socket testing
Global Boolean MSUTESTBOARD

' These will be for options for additional steps in move commands
' Should be declared in Main function (as false by default) then toggled on
Global Boolean DoPinAnalysis
Global Boolean DoCheckPlace ' Checks orientation 
Global Boolean DoMeasurePlace ' Checks position measurement

Global String CurrentOperation$


