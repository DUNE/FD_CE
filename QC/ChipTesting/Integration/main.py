import os
import sys

# Add the parent directory to Python path to find BNL_QC module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import ChipTesting.Integration.RTSStateMachine as RTSSM
from ChipTesting.Integration.RTSStateMachine import RTSStateMachine

if __name__ == "__main__":
    sm = RTSStateMachine()

    # Runs a full cycle of moving a pair of chips, testing, and moving back
    sm.run_full_cycle()

    # Runs a full cycle and multiple sets of chips, either a full tray or over the subset given
    sm.handle_tray()

    #sm.current_state = sm.running_ocr
    #sm.cycle()

    sm.end_state_machine()