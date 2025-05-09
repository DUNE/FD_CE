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