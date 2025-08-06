import RTSStateMachine as RTSSM
from RTSStateMachine import RTSStateMachine

if __name__ == "__main__":
    sm = RTSStateMachine()

    # sm.run_full_cycle()

    sm.current_state = sm.running_ocr
    sm.cycle()

    sm.end_state_machine()