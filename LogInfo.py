"""
Reads and writes log files.
"""


def SaveToLog(message, log_file="RTS_int_log.txt", log_dir="/Users/RTS/Desktop/"):

    with open(log_dir + log_file, "a") as f:
        print(message)
        f.write("\n" + message)
    return

def ReadLastLog(log_file="RTS_int_log.txt", log_dir="/Users/RTS/Desktop/"):

    with open(log_dir + log_file, "r") as f:
        lines = f.readlines()

    return lines[-1]

def ReadLog(log_file="RTS_init_log.txt", log_dir="/Users/RTS/Desktop/"):

    with open(log_dir + log_file, "r") as f:
        lines = f.readlines()

    return lines

def WaitForPictures(chip_positions, threading=False):
    """
    Reads the robot log file to see if chip pictures have been taken. If
    threading is True, it reads the last line continuously until they are 
    taken, otherwise it reads the last two lines of pictures taken.
    Inputs:
        chip_positions [dict]: dictionary of chip positions and labels
        threading [bool]: True if using threading and can read log 
                          continuously, False otherwise
    Returns:
        pictures_ready [bool]: True if the correct number of picutres
                               were found for each chip, False otherwise
        pictures [list of str]: Holds the image names of each picture 
    """

    RobotLog_dir = "/Users/RTS/RTS_data/"
    RobotLog_file = "RobotLog.txt"
    pictures_ready = False
    pictures = []
    if threading:
        # Check the RobotLog to see if the chip picture is ready before running OCR
        robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
        timepassed = 0
        while not pictures_ready:

            robotlog = ReadLastLog(RobotLog_file, RobotLog_dir)
            print("-------- RobotLog:" + robotlog)
            if "Picture of chip in tray taken" in robotlog:
                image_id = robotlog.split(" ")[-1].rstrip("\n")
                if image_id not in pictures:
                    pictures.append(image_id)
                #image_id = '20250402112328' # for testing while we can't run full OCR

                # Stop once we have pictures for each chip
                if len(pictures) == len(chip_positions['dat_socket']):
                    print('Pictures ready!')
                    pictures_ready = True

            # Break if its been too long
            if timepassed > 180:
                print("ERROR: Pictures of chip has still not been taken.")
                break
            time.sleep(0.5)
            timepassed += 0.5

    else:
        robotlog = ReadLog(RobotLog_file, RobotLog_dir)
        pic_lines = []
        pictures
        for line in robotlog:
            if "Picture of chip in tray taken" in line:
                pic_lines.append(line)
        
        for i in range(len(chip_positions['dat_socket'])):
            line = pic_lines[-1*(i+1)] # Start at the end of the list and go up
            image_id = line.split(" ")[-1].rstrip("\n")
            if image_id not in pictures:
                pictures.append(image_id)

        # Check we have pictures for each chip
        if len(pictures) == len(chip_positions['dat_socket']):
            print('Pictures ready!')
            pictures_ready = True

    return pictures_ready, pictures