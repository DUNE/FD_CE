' Note, reserving 1 as not an error because -1 is "True" in BASIC/SPEL
' and error codes may be passed as negative value output of function
' General/setup errors
#define ERR_SERVER 2
#define ERR_BAD_COMMAND 3
#define ERR_FILESYSTEM 4

' Robot and motion errors (also see SPEL errors)
#define ERR_MOTOR 5
#define ERR_COLLISION 6
#define ERR_SPEL 7 ' Need to check individual error

' EOAT errors
#define ERR_EOAT_IO 10
#define ERR_PUMP 11
#define ERR_PRESSURE 12
#define ERR_VACUUM 13

' Chip exists check with contact sensor
#define ERR_NO_CONTACT 15
#define ERR_OBSTRUCTION 16

' General vision error e.g. no sequence defined for site
#define ERR_VISION 20
' Chip finding/measuring with vision
#define ERR_V_NOCHIP 21
#define ERR_V_OCCUPIED 22
#define ERR_V_DF_ALIGN 23
#define ERR_V_UF_ALIGN 24
' Socket finding/measuring with vision
#define ERR_V_NOSOCKET 25
#define ERR_V_SOCKETALIGN 26
#define ERR_V_CHIPSOCKALIGN 27 ' Chip and socket

#define ERR_BAD_TOLERANCE 28

#define ERR_BAD_ORIENTATION 29

' Position and pin analysis errors
#define ERR_CALCULATION 51
#define ERR_ANALYSIS 52
#define ERR_PINS 53

' Chip pick and place errors, can be combined with above for more specific
' error, eg 121 would be failure to pick up at tray because no chip is seen
#define ERR_TRAY_PICK 100
#define ERR_TRAY_PLACE 200
#define ERR_SOCKET_PICK 300
#define ERR_SOCKET_PLACE 400

' For error code handling
Global Int32 ErrorCode
Global Int32 SubError



