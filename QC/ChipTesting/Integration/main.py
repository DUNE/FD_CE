import os
import sys

# Add the parent directory to Python path to find BNL_QC module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

import ChipTesting.Integration.RTSStateMachine as RTSSM
from ChipTesting.Integration.RTSStateMachine import RTSStateMachine

if __name__ == "__main__":
    sm = RTSStateMachine()

    sm.run_full_cycle()

    #sm.current_state = sm.running_ocr
    #sm.cycle()

    sm.end_state_machine()