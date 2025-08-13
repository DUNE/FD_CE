# DUNE-RTS-SCADA

## Overview
This project implements a state machine for chip handling and testing automation, with support for both simulation and real hardware integration.

## What it does
- **Automated Chip Testing:** The system automatically moves chips from a tray to test sockets, performs testing, and returns them to the tray.
- **State Management:** Uses a state machine to manage the testing workflow, including normal operations, error handling, and pause/resume functionality.
- **Hardware Integration:** Designed to integrate with robotic test stands and hardware components with simulation mode support.

## States

### Normal Operation States
- **Ground**: Ready to start
- **Surveying Sockets**: Finding available test positions
- **Moving Chip to Socket**: Robot placing chip
- **Running OCR**: Reading serial numbers from chip images
- **Testing**: Running WIB tests
- **Burning Serial Number**: Burning serial number into chip
- **Writing to HWDB**: Saving results
- **Moving Chip to Tray**: Robot moving tested chip

### Control States
- **Pause**: System paused with interactive menu

### Fix States
- **Reseat**: System reseat for component repositioning
- **Moving Chip to Bad Tray**: Routing defective chips

### Error States
- **No Server Connection**: Server communication failure
- **Chip in Socket**: Socket already occupied
- **Vision Sequence Failed**: Vision system failure
- **No Pressure**: Pressure system failure
- **Lost Vacuum**: Vacuum system failure
- **Bad Contact**: Poor electrical contact
- **No Chip**: Expected chip not found
- **Safe Guard**: Safety system triggered
- **Bad Pins**: Pin issues detected
- **No Serial Number**: Chip identification failure
- **Failed Initialization**: Test initialization failure
- **No WIB Connection**: WIB connection failure
- **Failed Upload**: Database upload failure

## Chip Tray System

The system tracks chip positions using a dictionary-based approach:
- **chip_positions**: A dictionary with the following lists, each of length 40 (10 columns × 4 rows):
  - `'tray'`: Tray number for each chip
  - `'col'`: Column position (1–10)
  - `'row'`: Row position (1–4)
  - `'dat'`: DAT board number for each chip
  - `'dat_socket'`: Socket number for each chip
  - `'label'`: COLDATA label for each chip (e.g., 'CD0', 'CD1')
- **Position tracking**: Each index corresponds to a unique chip position; e.g., `chip_positions['col'][i]` and `chip_positions['row'][i]` give the column and row for chip `i`.
- **Automatic advancement**: The state machine uses `current_chip_index` to keep track of which chip is being processed.
- **Tray completion**: Handles end-of-tray logic with automatic reset.

## Pause/Resume System

Advanced pause functionality with interactive menu:
- **Option 1**: Return to Ground state
- **Option 2**: Resume to previous normal state
- **Option 3**: Continue to next state in cycle
- **Option 4**: Quit system

The system automatically tracks the last normal state for precise resume functionality.

## Quick Start

```bash
# Install
pip3 install -r requirements.txt

# Note: you may need to force pip to install into the current python
python3 -m pip install pandas

# Run
python3 main.py
```

## Usage

```python
import RTSStateMachine as RTSSM

sm = RTSSM.RTSStateMachine()

# Basic state transitions
sm.cycle()  # Move to next state in normal cycle
sm.pause_cycle()  # Pause system with interactive menu
sm.error_cycle()  # Trigger error handling transitions
sm.test_cycle()  # Run test cycle with pauses

# Chip positioning
print(sm.get_position())  # Get current (col, row) position
sm.advance_chip_position()  # Move to next position

# Automated testing
sm.run_full_cycle()  # Run 6 cycles for one chip, then advance position
sm.handle_tray()  # Process all 40 chips on the tray

# Pause/Resume control
sm.resume_to_previous()  # Resume to last normal state
sm.advance_to_next_in_cycle()  # Resume and advance one step
```

## State Management Methods

### Chip Management
- `get_position()`: Returns current (col, row) position
- `advance_chip_position()`: Move to next position, handles tray completion
- `reset_tray_position()`: Reset to position (1,1)
- `is_tray_complete()`: Check if at final position (10,4)
- `run_full_cycle()`: Run 6 cycles for one chip, then advance
- `handle_tray()`: Process all 40 chips on the tray
- `get_current_chip_data()`: Returns a dictionary with the current chip's column, row, and index
- `set_chip_data(index, col=None, row=None)`: Set the column and/or row for a specific chip index

### Example: Accessing and Modifying Chip Data

```python
# Get current chip's data as a dictionary
chip_data = sm.get_current_chip_data()
print(chip_data)  # {'col': 1, 'row': 1, 'index': 0}

# Set the column and row for chip at index 5
sm.set_chip_data(5, col=3, row=2)
```

### Pause/Resume Control
- `resume_to_previous()`: Resume to last recorded normal state
- `advance_to_next_in_cycle()`: Resume to previous state then advance one step
- `pause_with_user_input()`: Interactive pause menu

## Transitions

- **cycle**: Normal operation flow (ground → surveying → moving → OCR → testing → burning serial number → writing to HWDB → moving to tray → ground)
- **test_cycle**: Test mode with pauses between each step
- **pause_cycle**: Pause transitions from any state
- **error_cycle**: Error handling and recovery transitions

## Status

## Recent Changes

- **OCR Integration:** Added "Running OCR" state with FNAL_CPM integration for automatic serial number reading from chip images. The OCR state:
  - Waits for chip pictures using `WaitForPictures()`
  - Runs OCR processing for each chip using `FNAL_CPM.RunOCR()`
  - Tracks OCR success with `sn_ready` flag
  - Conditionally skips serial number burning if OCR fails
  - Includes simulation mode support for OCR operations
- **Dual Flag System:** Implemented separate control flags for different system aspects:
  - **`simulation_mode`**: Controls simulation messages and testing/burning operations
  - **`BypassRTS`**: Controls robot movement operations (moving chips to/from sockets, bad tray operations, and RTS server startup/shutdown)
  - Both flags are set via user input during initialization and can be used independently
- **Burning Serial Number State:** Added new "Burning Serial Number" state between testing and writing to HWDB. This state automatically calls the `BurninSN()` function from `Auto_COLDATA_QC.py` to burn serial numbers into COLDATA chips after successful testing.
- **Simulation Mode Rename:** Renamed `BypassRTS` boolean to `simulation_mode` for better clarity. When `True`, the system runs in simulation mode without hardware interaction.

### Previous Updates
- **Log-Driven State Transitions:** Added support for monitoring a log file and triggering state transitions automatically when a log line matches a state name, enabling seamless integration with external robot software.
- **Chip Position Population:** Added interactive user input for populating chip positions. Users can choose between manual entry (one chip at a time) or automatic full tray population. Manual mode includes input validation for all fields (tray: 1-2, column: 1-10, row: 1-4, DAT: 1-2, DAT socket: 21-22, label: CD0/CD1).
- **MoveChipsToTray Implementation:** Added `MoveChipsToTray()` function integration in the "Moving Chip to Tray" state, matching the pattern used for `MoveChipsToSockets()`. Both functions now receive individual chip data rather than the entire chip_positions dictionary.
- **Consistent Chip Advancement:** Chip position advancement now occurs only in `run_full_cycle()`, ensuring each chip completes a full testing cycle before moving to the next position.
- **Session Folder Creation:** Each time the system enters the ground state, a new folder is created in the 'images/' directory, named with the current date and time, to store session-specific data (e.g., OCR images).
- **Chip Position Tracking:** Now uses a dictionary (`chip_positions`) to manage all chip-related data for 40 positions (10 columns × 4 rows).
- **State Machine Refactor:** States and transitions are more clearly defined and grouped (normal, pause, error, reset).
- **Pause/Resume:** Improved interactive pause menu, with options to resume, advance, or return to ground state. The last normal state is tracked for accurate resumption.
- **Tray Handling:** Methods for advancing, resetting, and checking chip positions on the tray.
- **Log-Based State Transitions:** The state machine can now monitor a log file and automatically transition to states specified by new log entries. Call `read_log_and_transition(log_path)` to enable this feature.
  - Call `read_log_and_transition(log_path)` on the `RTSStateMachine` instance, where `log_path` is the path to your log file.
  - Each new line in the log file should contain the name of a valid state (case-insensitive).
  - The state machine will transition to the specified state if it is different from the current state.
- **Integration Points:** Integration functions (e.g., `MoveChipsToSockets`, `MoveChipsToTray`) are present and can be enabled as needed (still WIP).
- **Error Handling:** Expanded error states and transitions for robust operation.