"""
DUNE RTS State Machine for automated chip testing and handling.

This module implements a state machine for controlling robotic test stand operations,
including chip movement, testing, and error handling. Supports both simulation and
real hardware modes.

Classes:
    RTSStateMachine: Main state machine for chip testing automation
"""

from statemachine import StateMachine, State
from FNAL_RTS_integration import MoveChipsToSockets, MoveChipsToTray, MoveBadChipsToTray, RTS_Cycle
from Integration.Auto_COLDATA_QC import RunCOLDATA_QC, BurninSN
from RTS_CFG import RTS_CFG
from BNL_QC.LogInfo import WaitForPictures
import sys
import os
from datetime import datetime
import time
import subprocess

# Add OCR path and import
sys.path.insert(1, r'C:\\Users\RTS\DUNE-rts-sn-rec')
import FNAL_CPM as cpm


class RTSStateMachine(StateMachine):
    """
    State machine for DUNE RTS chip testing automation.
    
    Manages the complete workflow of chip testing including movement, testing,
    data recording, and error handling. Supports both simulation and hardware modes.
    
    Attributes:
        simulation_mode (bool): When True, runs in simulation mode for testing/burning serial number
        BypassRTS (bool): When True, bypasses chip movement operations and RTS server operations
        chip_positions (dict): Dictionary containing chip position data
        current_chip_index (int): Index of current chip being processed
        last_normal_state (State): Last normal state for resume functionality
    """

    def __init__(self):
        """Initialize the state machine and prompt for chip population method."""
        super().__init__()

        self.simulation_mode = False
        self.BypassRTS = False
        self.last_normal_state = None

        self.chip_positions = {
            'tray': [],
            'col': [],
            'row': [],
            'dat': [],
            'dat_socket': [],
            'label': []
        }
        
        self.max_col = 10
        self.max_row = 4
        self.current_chip_index = 0
        
        # OCR configuration
        self.image_directory = "/Users/RTS/RTS_data/images/"
        self.ocr_results_dir = "/Users/RTS/DUNE-rts-sn-rec/Tested/fnal_cpm_results/"
        self.config_file = "asic_info.csv"
        self.sn_ready = True  # Track if OCR was successful

        # Ask user if they want to run in simulation mode
        while True:
            simulation_input = input("Run in simulation mode? (y/n): ").strip().lower()
            if simulation_input in ['y', 'yes']:
                self.simulation_mode = True
                break
            elif simulation_input in ['n', 'no']:
                self.simulation_mode = False
                break
            else:
                print("Please enter 'y' or 'n'.")

        # Ask user if they want to bypass RTS operations
        while True:
            bypass_input = input("Bypass RTS operations? (y/n): ").strip().lower()
            if bypass_input in ['y', 'yes']:
                self.BypassRTS = True
                break
            elif bypass_input in ['n', 'no']:
                self.BypassRTS = False
                break
            else:
                print("Please enter 'y' or 'n'.")

        # Only initialize the robot if not bypassing RTS
        if not self.BypassRTS:
            self.rts = RTS_CFG()
            self.rts.rts_init(port=201, host_ip='192.168.121.1')
        
        while True:
            choice = input("Populate chip positions manually (m) or use full tray (f)? ").strip().lower()
            if choice in ['m', 'manual']:
                self.populate_manually()
                break
            elif choice in ['f', 'full']:
                self.populate_full_tray()
                break
            else:
                print("Please enter 'm' for manual or 'f' for full tray.")
        
    # State definitions
    ground = State("Ground", initial=True)
    surveying_sockets = State("Surveying Sockets")
    moving_chip_to_socket = State("Moving Chip to Socket")
    running_ocr = State("Running OCR")
    testing = State("Testing")
    burning_serial_number = State("Burning Serial Number")
    writing_to_hwdb = State("Writing to HWDB")
    moving_chip_to_tray = State("Moving Chip to Tray")

    reseat = State("Reseat")
    moving_chip_to_bad_tray = State("Moving Chip to Bad Tray")

    pause = State("Pause")

    no_server_connection = State("No Server Connection")
    chip_in_socket = State("Chip in Socket")
    vision_sequence_failed = State("Vision Sequence Failed")
    no_pressure = State("No Pressure")
    lost_vacuum = State("Lost Vacuum")
    bad_contact = State("Bad Contact")
    no_chip = State("No Chip")
    safe_guard = State("Safe Guard")
    bad_pins = State("Bad Pins")
    no_serial_number = State("No Serial Number")
    failed_init = State("Failed Initialization")
    no_wib_connection = State("No WIB Connection")
    failed_upload = State("Failed Upload")

    # State transitions
    cycle = (
        ground.to(surveying_sockets)
        | surveying_sockets.to(moving_chip_to_socket)
        | moving_chip_to_socket.to(running_ocr)
        | running_ocr.to(testing)
        | testing.to(burning_serial_number)
        | burning_serial_number.to(writing_to_hwdb)
        | writing_to_hwdb.to(moving_chip_to_tray)
        | moving_chip_to_tray.to(ground)
    )

    test_cycle = (
        ground.to(pause)
        | pause.to(surveying_sockets)
        | surveying_sockets.to(pause)
        | pause.to(moving_chip_to_socket)
        | moving_chip_to_socket.to(pause)
        | pause.to(running_ocr)
        | running_ocr.to(pause)
        | pause.to(testing)
        | testing.to(pause)
        | pause.to(burning_serial_number)
        | burning_serial_number.to(pause)
        | pause.to(writing_to_hwdb)
        | writing_to_hwdb.to(pause)
        | pause.to(moving_chip_to_tray)
        | moving_chip_to_tray.to(pause)
        | pause.to(moving_chip_to_socket)
        | moving_chip_to_bad_tray.to(pause)
        | pause.to(moving_chip_to_socket)
    )

    pause_cycle = (
        ground.to(pause)
        | surveying_sockets.to(pause)
        | moving_chip_to_socket.to(pause)
        | running_ocr.to(pause)
        | testing.to(pause)
        | burning_serial_number.to(pause)
        | writing_to_hwdb.to(pause)
        | moving_chip_to_tray.to(pause)
        | moving_chip_to_bad_tray.to(pause)
        | reseat.to(pause)
        | no_server_connection.to(pause)
        | chip_in_socket.to(pause)
        | vision_sequence_failed.to(pause)
        | no_pressure.to(pause)
        | lost_vacuum.to(pause)
        | bad_contact.to(pause)
        | no_chip.to(pause)
        | safe_guard.to(pause)
        | bad_pins.to(pause)
        | no_serial_number.to(pause)
        | failed_init.to(pause)
        | no_wib_connection.to(pause)
        | failed_upload.to(pause)
    )

    error_cycle = (
        ground.to(no_server_connection)
        | surveying_sockets.to(chip_in_socket)
        | surveying_sockets.to(vision_sequence_failed)
        | moving_chip_to_socket.to(no_pressure)
        | moving_chip_to_socket.to(lost_vacuum)
        | moving_chip_to_socket.to(bad_contact)
        | moving_chip_to_socket.to(no_chip)
        | moving_chip_to_socket.to(vision_sequence_failed)
        | moving_chip_to_socket.to(safe_guard)
        | moving_chip_to_socket.to(bad_pins)
        | moving_chip_to_socket.to(no_serial_number)
        | running_ocr.to(no_serial_number)
        | testing.to(failed_init)
        | testing.to(no_wib_connection)
        | failed_init.to(reseat)
        | writing_to_hwdb.to(failed_upload)
        | moving_chip_to_tray.to(no_pressure)
        | moving_chip_to_tray.to(lost_vacuum)
        | moving_chip_to_tray.to(bad_contact)
        | moving_chip_to_tray.to(no_chip)
        | moving_chip_to_tray.to(vision_sequence_failed)
        | moving_chip_to_tray.to(safe_guard)
        | moving_chip_to_bad_tray.to(moving_chip_to_socket)
        | bad_pins.to(moving_chip_to_bad_tray)
        | no_serial_number.to(moving_chip_to_bad_tray)
        | failed_upload.to(moving_chip_to_tray)
        | chip_in_socket.to(surveying_sockets)
        | vision_sequence_failed.to(surveying_sockets)
        | bad_contact.to(moving_chip_to_socket)
        | no_chip.to(surveying_sockets)
        | no_wib_connection.to(testing)
    )

    reset_cycle = (
        pause.to(ground)
        | reseat.to(ground)
        | moving_chip_to_bad_tray.to(ground)
        | no_pressure.to(ground)
        | lost_vacuum.to(ground)
        | safe_guard.to(ground)
        | no_server_connection.to(ground)
    )

    def on_enter_ground(self):
        print("Entering ground state - system ready")
        self.last_normal_state = self.current_state
        self.create_session_folder()

    def on_enter_surveying_sockets(self):
        print("Starting to survey sockets")
        self.last_normal_state = self.current_state

    def on_enter_moving_chip_to_socket(self):
        print("Moving chips to test socket")
        self.last_normal_state = self.current_state

        if self.current_chip_index >= len(self.chip_positions['col']):
            print("Error: No more chips to process")
            return

        chip_data = {key: [self.chip_positions[key][self.current_chip_index], 
                           self.chip_positions[key][self.current_chip_index + 1]] for key in self.chip_positions}
        
        if not self.BypassRTS:
            try:
                MoveChipsToSockets(self.rts, chip_data)
            except Exception as e:
                print(f"Error calling MoveChipsToSockets: {e}")
                return
        else:
            print(f"Would have moved chips to sockets: {chip_data['label'][0]} and {chip_data['label'][1]} from tray {chip_data['tray'][0]}, positions ({chip_data['col'][0]}, {chip_data['row'][0]}) and ({chip_data['col'][1]}, {chip_data['row'][1]}) to DAT {chip_data['dat'][0]} sockets {chip_data['dat_socket'][0]} and {chip_data['dat_socket'][1]}")

    def on_enter_running_ocr(self):
        print("Starting OCR processing to read serial numbers")
        self.last_normal_state = self.current_state

        if self.simulation_mode:
            print("[SIMULATION] Running OCR processing")
            print("Would have called WaitForPictures() and RunOCR() for chip images")
            print("Would have killed Ollama process after OCR completion")
        else:
            try:
                # Check the RobotLog to see if the chip pictures are ready before running OCR
                print('Waiting for chip pictures...')
                chip_data = {key: [self.chip_positions[key][self.current_chip_index], 
                                  self.chip_positions[key][self.current_chip_index + 1]] for key in self.chip_positions}
                pictures_ready, pictures = WaitForPictures(chip_data, threading=False)
                
                if pictures_ready:
                    print('Pictures ready! Running OCR...')
                    
                    for i in range(len(pictures)):
                        success = cpm.RunOCR(self.image_directory, pictures[i], self.ocr_results_dir,
                                           True, chip_data['label'][i], self.config_file)
                        self.sn_ready = self.sn_ready and success  # only True if all RunOCR's are successful
                    
                    # Kill Ollama used by OCR
                    subprocess.run("taskkill /F /IM ollama.exe", shell=True)
                    print("OCR processing completed successfully")
                else:
                    print("Pictures not ready, OCR processing failed")
                    self.sn_ready = False
                    
            except Exception as e:
                print(f"Error during OCR processing: {e}")
                self.sn_ready = False

    def on_enter_testing(self):
        print("Starting chip testing")
        self.last_normal_state = self.current_state

        if self.simulation_mode:
            print("[SIMULATION] Running COLDATA QC tests")
            print("Would have called RunCOLDATA_QC(duttype='CD', env='RT', rootdir='C:/Users/RTS/Tested/')")
        else:
            print("Running COLDATA QC tests...")
            self.logs, self.cd_qc_ana = RunCOLDATA_QC(
                duttype="CD", 
                env="RT", 
                rootdir="C:/Users/RTS/Tested/"
            )
            print("COLDATA QC tests completed successfully")

    def on_enter_burning_serial_number(self):
        print("Starting serial number burn-in process")
        self.last_normal_state = self.current_state

        if self.simulation_mode:
            print("[SIMULATION] Burning serial number into chip")
            print("Would have called BurninSN() with logs and cd_qc_ana from testing phase")
        else:
            if self.sn_ready:
                try:
                    print("Burning serial number into chip...")
                    BurninSN(self.logs, self.cd_qc_ana)
                    print("Serial number burn-in completed successfully")
                except Exception as e:
                    print(f"Error during serial number burn-in: {e}")
            else:
                print("OCR failed, skipping serial number burn-in")

    def on_enter_writing_to_hwdb(self):
        print("Writing test results to HWDB")
        self.last_normal_state = self.current_state

    def on_enter_moving_chip_to_tray(self):
        print("Moving chips to tray")
        self.last_normal_state = self.current_state

        chip_data = {key: [self.chip_positions[key][self.current_chip_index], 
                          self.chip_positions[key][self.current_chip_index + 1]] for key in self.chip_positions}
        
        if not self.BypassRTS:
            try:
                MoveChipsToTray(self.rts, chip_data)
            except Exception as e:
                print(f"Error calling MoveChipsToTray: {e}")
        else:
            print(f"Would have moved chips to tray: {chip_data['label'][0]} and {chip_data['label'][1]} from DAT {chip_data['dat'][0]} sockets {chip_data['dat_socket'][0]} and {chip_data['dat_socket'][1]} to tray {chip_data['tray'][0]}, positions ({chip_data['col'][0]}, {chip_data['row'][0]}) and ({chip_data['col'][1]}, {chip_data['row'][1]})")

    def on_enter_pause(self):
        print("System paused - awaiting resume command")
        self.pause_with_user_input()

    def on_enter_reseat(self):
        print("System reseat initiated - repositioning components")

    def on_enter_moving_chip_to_bad_tray(self):
        print("Moved defective chip to bad tray")

        badtray_file = "path/to/BadTray.csv"
        chip_data = {key: [self.chip_positions[key][self.current_chip_index]] for key in self.chip_positions}
        
        if not self.BypassRTS:
            try:
                MoveBadChipsToTray(self.rts, chip_data, badtray_file)
                self.advance_chip_position()
            except Exception as e:
                print(f"Error calling MoveBadChipsToTray: {e}")
        else:
            print(f"Would have moved chip to bad tray: {self.chip_positions['label'][self.current_chip_index]} from DAT {self.chip_positions['dat'][self.current_chip_index]} socket {self.chip_positions['dat_socket'][self.current_chip_index]}")

    def on_enter_no_server_connection(self):
        print("Error: No server connection detected")

    def on_enter_chip_in_socket(self):
        print("Error: Chip already in socket")

    def on_enter_vision_sequence_failed(self):
        print("Error: Vision sequence failed")

    def on_enter_no_pressure(self):
        print("Error: No pressure detected")

    def on_enter_lost_vacuum(self):
        print("Error: Vacuum system failure")

    def on_enter_bad_contact(self):
        print("Error: Bad socket contact")

    def on_enter_no_chip(self): 
        print("Error: No chip detected")

    def on_enter_safe_guard(self):
        print("Error: Safety guard triggered")

    def on_enter_bad_pins(self):
        print("Error: Bad pins detected")

    def on_enter_no_serial_number(self):
        print("Error: No serial number")

    def on_enter_failed_init(self):
        print("Error: Test initialization failed")

    def on_enter_no_wib_connection(self):
        print("Error: No WIB connection")

    def on_enter_failed_upload(self):
        print("Error: Failed to upload to HWDB")

    def resume_to_previous(self):
        if self.last_normal_state:
            self.current_state = self.last_normal_state
        else:
            print("Last normal state not found")

    def advance_to_next_in_cycle(self):
        if self.last_normal_state is None:
            print("Error: No previous state to resume from")
            return
        self.resume_to_previous()
        try:
            self.cycle()
        except Exception as e:
            print(f"Error advancing cycle: {e}")

    def pause_with_user_input(self):
        print(f"\nSYSTEM PAUSED")
        
        print("\nWhat would you like to do?")
        print("┌─────────────────────────────────────────┐")
        print("│ 1. Go back to Ground state              │")
        print("│ 2. Resume to previous state             │")
        print("│ 3. Continue to next state in cycle      │")
        print("│ 4. Quit                                 │")
        print("└─────────────────────────────────────────┘")
        
        print("Please enter your choice (1-4): ", end="")

        while True:
            try:
                user_input = input("").strip().lower()
                if user_input == "1":
                    self.current_state = self.ground
                    print(f"Resumed to Ground state")
                    print(f"Current state: {self.current_state}")
                    break
                elif user_input == "2":
                    self.resume_to_previous()
                    print(f"\nResumed to previous state")
                    print(f"Current state: {self.current_state}")
                    break
                elif user_input == "3":
                    self.advance_to_next_in_cycle()
                    break
                elif user_input == "4":
                    print("Exiting system...")
                    sys.exit()
            except (EOFError, KeyboardInterrupt):
                print("\n\nReceived interrupt signal. System remains paused.")
                print("Type 1, 2, 3, or 4 to continue.")

    def advance(self):
        """Advance to the next chip position on the tray."""
        if self.current_chip_index < len(self.chip_positions['col']) - 1:
            self.current_chip_index += 1
        else:
            raise StopIteration("Reached the end of the tray.")

    def get_position(self):
        """Get the current chip position on the tray."""
        if not self.chip_positions['col'] or self.current_chip_index >= len(self.chip_positions['col']):
            return (0, 0)
        return (self.chip_positions['col'][self.current_chip_index], 
                self.chip_positions['row'][self.current_chip_index])

    def advance_chip_position(self):
        """Advance to the next chip position with automatic reset at end."""
        try:
            self.advance()
            print(f"Advanced to chip position: {self.get_position()}")
        except StopIteration:
            print("Reached the end of the tray.")
            self.current_chip_index = 0

    def reset_tray_position(self):
        """Reset the chip position to the beginning of the tray."""
        self.current_chip_index = 0
        print("Reset chip position to (1, 1)")

    def is_tray_complete(self):
        """Check if we've processed all positions on the tray."""
        return self.current_chip_index == len(self.chip_positions['col']) - 1

    def run_full_cycle(self):

        """Run a complete test cycle for two chips and advance positions."""

        # Check if we have at least 2 chips to process
        if self.current_chip_index + 1 >= len(self.chip_positions['col']):
            error_msg = f"ERROR: Only one chip remaining at position {self.get_position()}. Two-chip cycle requires at least 2 chips."
            print(error_msg)
            raise ValueError(error_msg)
        
        print(f"Starting full cycle at position {self.get_position()}")

        for i in range(8):
            self.cycle()
        
        # Advance by 2 positions since we processed 2 chips
        self.current_chip_index += 2
        if self.current_chip_index >= len(self.chip_positions['col']):
            print("Reached the end of the tray.")
            self.current_chip_index = 0
        
        print("Full cycle complete")
    
    def handle_tray(self):
        """Process all chips on the tray with full test cycles."""
        num_chips = len(self.chip_positions['col'])
        for i in range(num_chips):
            print(f"\n--- Processing chip {i+1}/{num_chips} ---")
            self.run_full_cycle()
        print(f"\nTray processing complete! Processed {num_chips} chips.")

    def get_current_chip_data(self):
        """Get all data for the current chip as a dictionary."""
        return {key: self.chip_positions[key][self.current_chip_index] for key in self.chip_positions}
    
    def set_chip_data(self, index, col=None, row=None):
        """
        Set column and/or row data for a specific chip index.
        
        Args:
            index (int): Chip index in the chip_positions arrays (0 to len-1)
            col (int, optional): Column number (1-10). If None, column is not changed.
            row (int, optional): Row number (1-4). If None, row is not changed.
            
        Raises:
            ValueError: If index is out of bounds or col/row values are invalid
        """
        if index < 0 or index >= len(self.chip_positions['col']):
            raise ValueError(f"Invalid index: {index}")
        if col is not None and (col < 1 or col > 10):
            raise ValueError(f"Invalid column: {col}")
        if row is not None and (row < 1 or row > 4):
            raise ValueError(f"Invalid row: {row}")
        if col is not None:
            self.chip_positions['col'][index] = col
        if row is not None:
            self.chip_positions['row'][index] = row

    def create_session_folder(self):
        """Create a timestamped session folder for storing test data."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        folder_name = f'session_{timestamp}'
        folder_path = os.path.join('images', folder_name)
        os.makedirs(folder_path, exist_ok=True)
        self.current_session_folder = folder_path

    def read_log_and_transition(self, log_path):
        """
        Monitor a log file and automatically transition states based on log entries.
        
        Args:
            log_path (str): Path to the log file to monitor
        """
        state_map = {
            "ground": self.ground,
            "surveying_sockets": self.surveying_sockets,
            "moving_chip_to_socket": self.moving_chip_to_socket,
            "MoveChipFromTrayToSocket": self.moving_chip_to_socket,
            "Jumped to DAT": self.testing,
            "testing": self.testing,
            # "burning_serial_number": self.burning_serial_number,
            "writing_to_hwdb": self.writing_to_hwdb,
            "moving_chip_to_tray": self.moving_chip_to_tray,
            "Picked up chip from tray": self.moving_chip_to_socket,
            "reseat": self.reseat,
            "moving_chip_to_bad_tray": self.moving_chip_to_bad_tray,
            "pause": self.pause,
            "no_server_connection": self.no_server_connection,
            "chip_in_socket": self.chip_in_socket,
            "vision_sequence_failed": self.vision_sequence_failed,
            "no_pressure": self.no_pressure,
            "lost_vacuum": self.lost_vacuum,
            "bad_contact": self.bad_contact,
            "no_chip": self.no_chip,
            "safe_guard": self.safe_guard,
            "bad_pins": self.bad_pins,
            "no_serial_number": self.no_serial_number,
            "failed_init": self.failed_init,
            "no_wib_connection": self.no_wib_connection,
            "failed_upload": self.failed_upload,
        }
        last_line = 0
        print(f"Monitoring log file: {log_path}")
        while True:
            try:
                if not os.path.exists(log_path):
                    print(f"Log file does not exist: {log_path}")
                    break
                with open(log_path, 'r') as f:
                    lines = f.readlines()
                new_lines = lines[last_line:]
                for line in new_lines:
                    state_str = line.strip().lower()
                    for key, state in state_map.items():
                        if key.lower() in state_str:
                            if self.current_state != state:
                                self.current_state = state
                                print(f"'{state_str}' -> {self.current_state}")
                            break
                last_line = len(lines)
                time.sleep(1)
            except KeyboardInterrupt:
                print("\nStopped log monitoring.")
                break
            except Exception as e:
                print(f"Error reading log file: {e}")
                time.sleep(1)
    
    def populate_full_tray(self):
        """Populate chip_positions with a complete 10x4 tray configuration."""
        for key in self.chip_positions:
            self.chip_positions[key] = []
        chip_counter = 0
        for col in range(1, self.max_col + 1):
            for row in range(1, self.max_row + 1):
                self.chip_positions['col'].append(col)
                self.chip_positions['row'].append(row)
                self.chip_positions['tray'].append(2)
                self.chip_positions['dat'].append(2)
                if chip_counter % 2 == 0:
                    self.chip_positions['dat_socket'].append(21)
                    self.chip_positions['label'].append('CD0')
                else:
                    self.chip_positions['dat_socket'].append(22)
                    self.chip_positions['label'].append('CD1')
                chip_counter += 1

    def populate_from_dicts(self, chip_list):
        """
        Populate chip_positions from a list of chip dictionaries.
        
        Args:
            chip_list (list): List of dictionaries containing chip data
        """
        for key in self.chip_positions:
            self.chip_positions[key] = []
        for chip in chip_list:
            for key in self.chip_positions:
                self.chip_positions[key].append(chip.get(key, None))

    def populate_manually(self):
        """Interactively populate chip_positions with user input."""
        print("\nManual chip population mode.")
        print("Enter chip details one by one. Allowed values:")
        print("Tray: 1 or 2 • Column: 1-10 • Row: 1-4 • DAT: 1 or 2 • DAT socket: 21 or 22 • Label: CD0 or CD1")
        
        while True:
            print(f"\n--- Chip {len(self.chip_positions['tray']) + 1} ---")
            
            while True:
                try:
                    tray = int(input("Tray number (1 or 2): ").strip())
                    if tray in [1, 2]:
                        break
                    else:
                        print("Tray number must be 1 or 2.")
                except ValueError:
                    print("Please enter 1 or 2.")
            
            while True:
                try:
                    col = int(input("Column (1-10): ").strip())
                    if 1 <= col <= 10:
                        break
                    else:
                        print("Column must be between 1 and 10.")
                except ValueError:
                    print("Please enter a valid number.")
            
            while True:
                try:
                    row = int(input("Row (1-4): ").strip())
                    if 1 <= row <= 4:
                        break
                    else:
                        print("Row must be between 1 and 4.")
                except ValueError:
                    print("Please enter a valid number.")
            
            while True:
                try:
                    dat = int(input("DAT board number (1 or 2): ").strip())
                    if dat in [1, 2]:
                        break
                    else:
                        print("DAT board number must be 1 or 2.")
                except ValueError:
                    print("Please enter 1 or 2.")
            
            while True:
                try:
                    dat_socket = int(input("DAT socket number (21 or 22): ").strip())
                    if dat_socket in [21, 22]:
                        break
                    else:
                        print("DAT socket number must be 21 or 22.")
                except ValueError:
                    print("Please enter 21 or 22.")
            
            while True:
                label = input("COLDATA label (CD0 or CD1): ").strip().upper()
                if label in ["CD0", "CD1"]:
                    break
                else:
                    print("Label must be CD0 or CD1.")
            
            # Check for duplicate chip (same position, label, and socket)
            for i in range(len(self.chip_positions['tray'])):
                if (self.chip_positions['tray'][i] == tray and 
                    self.chip_positions['col'][i] == col and 
                    self.chip_positions['row'][i] == row and
                    self.chip_positions['label'][i] == label and
                    self.chip_positions['dat_socket'][i] == dat_socket):
                    print(f"Error: Chip {label} at position (tray {tray}, col {col}, row {row}) with socket {dat_socket} already exists!")
                    break
            else:
                self.chip_positions['tray'].append(tray)
                self.chip_positions['col'].append(col)
                self.chip_positions['row'].append(row)
                self.chip_positions['dat'].append(dat)
                self.chip_positions['dat_socket'].append(dat_socket)
                self.chip_positions['label'].append(label)
                print(f"Added chip: {label} at tray {tray}, position ({col}, {row})")
            
            continue_input = input("Add another chip? (y/n): ").strip().lower()
            if continue_input not in ['y', 'yes']:
                break
        
        print(f"Manual population complete. Added {len(self.chip_positions['tray'])} chips.")

    def end_state_machine(self):
        if not self.BypassRTS:
            self.rts.rts_shutdown()
        
        if self.simulation_mode:
            print("[SIMULATION] Disconnecting from robot")