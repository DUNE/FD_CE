#define RTS_DATA "C:\Users\coldelec\RTS\"
'#define HAND_U0 7.075
#define HAND_U0 4.174
#define NTRAYS 2
#define TRAY_NCOLS 15
#define TRAY_NROWS 6
#define NSOCKETS 8
#define DF_CAMERA_OFFSET 58
#define DF_CAMERA_FOCUS -18.045

' corrections for the trays
Global Double tray_X(NTRAYS, TRAY_NCOLS, TRAY_NROWS)
Global Double tray_Y(NTRAYS, TRAY_NCOLS, TRAY_NROWS)
Global Double tray_U(NTRAYS, TRAY_NCOLS, TRAY_NROWS)

' corrections for the sockets
Global Double DAT_X(2, NSOCKETS)
Global Double DAT_Y(2, NSOCKETS)
Global Double DAT_U(2, NSOCKETS)

' chip SN
'Global String chip_SN$

