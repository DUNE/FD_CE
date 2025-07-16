import RTSStateMachine as RTSSM
from RTSStateMachine import RTSStateMachine

if __name__ == "__main__":
    sm = RTSStateMachine()

    # log_file = "/path/to/RobotLog.txt"  # Change as needed
    # sm.read_log_and_transition(log_file)

    # sm.run_full_cycle()
    sm.handle_tray()

    sm.end_state_machine()