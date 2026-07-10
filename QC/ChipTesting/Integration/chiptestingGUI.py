import sys 
import tkinter as tk
from tkinter import ttk, scrolledtext
import threading
import io
from datetime import datetime
import queue
import os 
import re # Regular expression module for matching ANSI escape sequences
import matplotlib
matplotlib.use("Agg") # Use the Agg backend for matplotlib to avoid GUI issues in headless environments

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..')) # Makes ChipTesting findable for python

from ChipTesting.Integration.RTSStateMachine import RTSStateMachine

ANSI_ESCAPE = re.compile(r'(?:\x1b|\033)\[([0-9;]*)m') # Regular expression to match ANSI escape sequences for text formatting (like colors) in terminal output
ANSI_COLOR_MAP = {
    "31": "ansi_red",
    "32": "ansi_green",
    "33": "ansi_yellow",
    "34": "ansi_blue",
    "35": "ansi_magenta",
    "36": "ansi_cyan",
    "37": "ansi_white",
    "41": "ansi_bg_red",
    "42": "ansi_bg_green",
    "43": "ansi_bg_yellow",
    "91": "ansi_bright_red",
    "92": "ansi_bright_green",
    "93": "ansi_bright_yellow",
}

# Takes usual console output and puts into a queue that this program will display with GUI
class InputOutput(io.TextIOBase): # Inherits io.TextIOBase so Python treats worker thread output as an object to insert into queue
    def __init__(self, queue, tag = "info"): # Takes in queue as argument and makes variable tag for coloring text during CLI output 
        self.queue = queue # Declares queue
        self.tag = tag # Declares tag
    
    def write(self, str): # Overrides the write() method of io.TextIOBase to intercept print() calls and put them into the queue
        if str: # If str is not empty, put into queue
            self.queue.put((self.tag, str)) # Puts print call with coloring tag into queue
        return len(str) # Returns number of characters written successfully to prevent error
    def flush(self): # Normally needed to push buffered text to print but no buffer here exists, thus doesn't do anything but please io.TextIOBase
        pass

# Blocks "worker" thread until user responds with GUI input
class GUIInputProvider:
    # Initializes prompt queue for multithreading and reply prompt as results from ask()
    def __init__(self, prompt_queue, reply_prompt):
        self.prompt_queue = prompt_queue
        self.reply_prompt = reply_prompt
    def ask(self, prompt = "", request_id = None):
        self.prompt_queue.put(prompt) # Takes prompt and drops into prompt queue 
        while True:
            reply_id, answer = self.reply_prompt.get()
            if request_id is None or reply_id == request_id:
                return answer
# Actual GUI for the program
class ChipTestingGUI(tk.Tk):
    # Sets initial window parameters
    def __init__(self):
        super().__init__()
        self.title("DUNE Chip Testing QC")
        self.geometry('1500x700')
        self.minsize(1100 , 750)

        self.output_queue = queue.Queue() # Carries print call from worker thread to a queue for CLI output
        self.input_queue = queue.Queue() # Carries any request for user input from worker thread to a queue for CLI output
        self.reply_queue = queue.Queue() # Carries response to user input request from main thread to a queue to send to worker thread

        self.worker = None # Holds down variable for thread.Threading() for when I define it as a thread as the program starts
        self.running = False # Track whether there is a current QC test going on and to prevent a second run
        self.paused = False # Track whether the program is paused and to prevent a second pause
        self.pause_requested = threading.Event() # Event to signal when a pause is requested
        self.waiting_for_input = False # Variable to track when waiting for input. Trigger variable to send reply out of queue
        self.pending_prompt = "" # Holds prompt as a string in order to make reading prompt easier. Will use this for making buttons usable
        self.current_prompt_id = None # Holds the current prompt ID to match with reply ID for when multiple prompts are sent out at once
        self.build_UI()
        self.poll()

    # Details of the UI itself
    def build_UI(self):
        style = ttk.Style(self)
        style.theme_use("default")

        # Details of top hotbar
        top_hotbar = ttk.Frame(self, relief = "groove")
        top_hotbar.pack(side = "top", fill = "x", padx = 6, pady= 4)
        
        ttk.Label(top_hotbar, text = "DUNE Chip Testing QC", font = ("Helvetica", 10, "bold")).pack(side = "left", padx = 4, pady = 4)
        
        self.run_button = ttk.Button(top_hotbar, text = "▶ Run", state = "normal", command = self.run)
        self.run_button.pack(side = "left", padx = 4, pady = 4)
        self.pause_button = ttk.Button(top_hotbar, text  = "⏸ Pause", state = "disabled", command = self.request_pause)
        self.pause_button.pack(side = "left", padx = 4, pady = 4)

        self.status = tk.StringVar(value = "Idle")
        ttk.Label(top_hotbar, textvariable = self.status, relief = "sunken", font = ("Helvetica", 10), width = 20).pack(side = "right", padx = 6, pady = 4)
        ttk.Label(top_hotbar, text = "Status:").pack(side = "right", padx = 4)

        # Creates tabs under hot bar
        tabs = ttk.Notebook(self)
        tabs.pack(fill = "both", expand = True, padx = 6, pady = 4)

        self.results_tab = ttk.Frame(tabs)
        self.set_up_tab = ttk.Frame(tabs)
        self.state_tab = ttk.Frame(tabs)

        tabs.add(self.results_tab, text = "Results")
        tabs.add(self.set_up_tab, text = "Set Up")
        tabs.add(self.state_tab, text = "State")

        self.build_results_tab()
        self.build_set_up_tab()
        self.build_state_tab()

    # Results tab
    def build_results_tab(self):
        intro = self.results_tab
        
        out_frame = ttk.LabelFrame(intro, text = "Live CLI Output")
        out_frame.pack(fill = "both", expand = True, padx= 6, pady = 2)

        # Creates console on right-hand side of GUI
        self.output = scrolledtext.ScrolledText(
            out_frame, state = "disabled", wrap = "word",
            font = ("Courier", 20), height = 22, bg = "black", fg = "white", insertbackground = "white"
        )
        self.output.pack(fill = "both", expand = True, padx = 4, pady = 4)

        # Configures console text to differentiate between information types
        self.output.tag_configure("info", foreground = "white", font = ("Courier", 15))
        self.output.tag_configure("error", foreground = "red", font = ("Courier", 15))
        self.output.tag_configure("prompt", foreground = "blue", font = ("Courier", 15, "bold"))
        self.output.tag_configure("answer", foreground = "white", font = ("Courier", 15, "bold"))
        self.output.tag_configure("state", foreground = "orange", font = ("Courier", 15, "bold"))
        # Configures console text to differentiate between ANSI color codes
        self.output.tag_configure("ansi_blue", foreground = "#5555ff", font = ("Courier", 15))
        self.output.tag_configure("ansi_magenta", foreground = "#ff55ff", font = ("Courier", 15))
        self.output.tag_configure("ansi_cyan", foreground = "#55ffff", font = ("Courier", 15))
        self.output.tag_configure("ansi_white", foreground = "#ffffff", font = ("Courier", 15)) 
        self.output.tag_configure("ansi_green", foreground = "#55ff55", font = ("Courier", 15))
        self.output.tag_configure("ansi_red", foreground = "#ff5555", font = ("Courier", 15))
        self.output.tag_configure("ansi_yellow", foreground = "#ffff55", font = ("Courier", 15))
        self.output.tag_configure("ansi_bright_red", foreground = "#ff5555", font = ("Courier", 15, "bold"))
        self.output.tag_configure("ansi_bright_green", foreground = "#55ff55", font = ("Courier", 15, "bold"))
        self.output.tag_configure("ansi_bright_yellow", foreground = "#ffff55", font = ("Courier", 15, "bold"))
        self.output.tag_configure("ansi_bg_green", foreground = "white", background = "#00aa00", font = ("Courier", 15, "bold"))
        self.output.tag_configure("ansi_bg_red", foreground = "white", background = "#aa0000", font = ("Courier", 15, "bold"))
        self.output.tag_configure("ansi_bg_yellow", foreground = "black", background = "#aaaa00", font = ("Courier", 15, "bold"))

        self.input_frame = ttk.LabelFrame(intro, text = "Input")
        self.input_frame.pack(fill = "both", padx = 6, pady = 6)

        self.answer_var = tk.StringVar()
        self.prompt_var = tk.StringVar(value = "{Waiting for program to ask for input}")
        self.prompt_label = ttk.Label(self.input_frame, textvariable = self.prompt_var, font = ("Courier", 10), width = 40, wraplength = 900, justify = "left") # Remember self.answer_var for input func
        self.prompt_label.pack(anchor = "w", padx = 6, pady = 6)

        input_row = ttk.Frame(self.input_frame)
        input_row.pack(fill = "x", padx = 6, pady = 6)

        self.answer_entry = ttk.Entry(input_row, textvariable = self.answer_var, font = ("Courier", 10), width  = 40) 
        self.answer_entry.pack(side = "left", pady = 6)
        self.submit_button = ttk.Button(input_row, text = "Submit", command = self.submit_answer, state = "normal") # self.submit_answer to be a function that passed text into response_queue
        self.submit_button.pack(side = "left", padx = 6, pady = 6)

        self.pause_frame = ttk.LabelFrame(intro, text = "Pause / Resume Controls  (when system is paused)")
        self.pause_frame.pack(fill="x", padx=6, pady=(0, 6))

        btn_row = ttk.Frame(self.pause_frame)
        btn_row.pack(padx = 6, pady= 6)
        ttk.Button(btn_row, text="1 · Ground", width = 20,
                   command = lambda: self.send_answer("1")).pack(side = "left", padx = 4)
        ttk.Button(btn_row, text="2 · Previous state",  width = 20,
                   command = lambda: self.send_answer("2")).pack(side = "left", padx = 4)
        ttk.Button(btn_row, text="3 · Next in cycle",   width = 20,
                   command = lambda: self.send_answer("3")).pack(side = "left", padx = 4)
        ttk.Button(btn_row, text="4 · Quit",            width = 20,
                   command = lambda: self.send_answer("4")).pack(side = "left", padx = 4)
        
        self.pause_frame.pack_forget() # Hides pause_frame until program is paused

        self.set_input_active(False) # To initialize with input frame without any text


    # Set Up tab
    def build_set_up_tab(self):
        intro = ttk.LabelFrame(self.set_up_tab, text = "Set Up Configuration")
        intro.pack(fill = "x", padx = 6, pady = 4)

        # Creates Frame for start up configuration as well as buttons for y/n or m/f
        row0 = ttk.Frame(intro)
        row0.pack(fill = "x", padx = 6, pady = 4)

        ttk.Label(row0, text = "Simulation Mode:").grid(row = 0, column = 0, sticky = "w")
        self.simulation_variable = tk.StringVar(value = "n")
        ttk.Radiobutton(row0, text = "Yes", variable = self.simulation_variable, value = "y").grid(row = 0, column = 1, sticky = "w")
        ttk.Radiobutton(row0, text = "No", variable = self.simulation_variable, value = "n").grid(row = 0, column = 2, sticky = "w")


        ttk.Label(row0, text = "Bypass RTS:").grid(row = 1, column = 0, sticky = "w")
        self.bypass_rts_variable = tk.StringVar(value =  "n")
        ttk.Radiobutton(row0, text = "Yes", variable = self.bypass_rts_variable, value = "y").grid(row = 1, column = 1, sticky = "w")
        ttk.Radiobutton(row0, text = "No", variable = self.bypass_rts_variable, value = "n").grid(row = 1, column = 2, sticky = "w")

        ttk.Label(row0, text="Tester Username:").grid(row = 2, column = 0, sticky = "w", pady = 4)
        self.username_variable = tk.StringVar(value = "")
        ttk.Entry(row0, textvariable = self.username_variable, width = 15).grid(row = 2, column = 1, columnspan = 2, sticky = "w", padx = 4)

        ttk.Label(row0, text = "Populate mode:").grid(row = 3, column = 0, sticky = "w")
        self.populate_mode = tk.StringVar(value = "f")
        ttk.Radiobutton(row0, text = "Full tray", variable = self.populate_mode, value = "f", command  = self.show_frames).grid(row = 3, column = 1, sticky = "w")
        ttk.Radiobutton(row0, text = "Manual", variable = self.populate_mode, value = "m", command  = self.show_frames).grid(row = 3, column = 2, sticky = "w")
        ttk.Radiobutton(row0, text = "Partial", variable = self.populate_mode, value = "p", command  = self.show_frames).grid(row = 3, column  = 3, sticky = "w")
        ttk.Radiobutton(row0, text = "Retest Tray", variable = self.populate_mode, value = "r", command  = self.show_frames).grid(row = 3, column  = 4, sticky = "w")
        ttk.Radiobutton(row0, text = "Retest Partial Tray", variable = self.populate_mode, value = "rp", command  = self.show_frames).grid(row = 3, column  = 5, sticky = "w")

        self.start_pos_frame = ttk.LabelFrame(intro, text = "Start Position")
        pos_row = ttk.Frame(self.start_pos_frame)
        pos_row.pack(fill = "x", padx = 6, pady = 6)
        
        ttk.Label(pos_row, text = "Tray:").grid(row = 0, column = 0, sticky = "w", pady = 4)
        self.start_tray = tk.StringVar(value = "1")
        ttk.Combobox(pos_row, textvariable = self.start_tray, values = ["1", "2"], width = 5, state = "readonly").grid(row = 0, column = 1, padx = 12)
        
        ttk.Label(pos_row, text = "Column:").grid(row = 0, column = 3, sticky = "w", pady = 4)
        self.start_column = tk.StringVar(value = "1")
        ttk.Combobox(pos_row, textvariable = self.start_column, values = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], width = 5, state = "readonly").grid(row = 0, column = 4, padx = 12)

        ttk.Label(pos_row, text = "Row:").grid(row = 0, column = 5, sticky = "w", pady = 4)
        self.start_row = tk.StringVar(value = "1")
        ttk.Combobox(pos_row, textvariable = self.start_row, values = ["1", "2", "3", "4"], width = 5, state = "readonly").grid(row = 0, column = 6, padx = 12)

        ttk.Label(pos_row, text = "DAT:").grid(row = 0, column = 7, sticky = "w", pady = 4)
        self.start_DAT = tk.StringVar(value = "1")
        ttk.Combobox(pos_row, textvariable = self.start_DAT, values = ["1", "2"], width = 5, state = "readonly").grid(row = 0, column = 8, padx = 12)

        self.start_pos_frame.pack_forget()

        self.chip_row_frame = ttk.LabelFrame(intro, text = "Manual Chip Data Entry (Use only when in manual populate mode)")
        self.chip_row_frame.pack(fill = "x", padx = 6, pady = 4)
        
        data_entry_headers = ["#", "Tray", "Column", "Row", "DAT", "DAT Socket", "Delete"]
        # Creates tuple for each entry in data_entry_headers to create a column for each 
        for col, header in enumerate(data_entry_headers):
            ttk.Label(self.chip_row_frame, text = header, font= ("Helvetica", 10)).grid(row = 0, column = col, padx = 4, pady = 2, sticky = "w")
        
        self.chip_row_frame.pack_forget() # Hides chip_row_frame until user selects manual populate mode

        self.chip_rows = [] # Creates a dictionary to keep track of each chip rows
        self.chip_row_count = 0 # Keeps track of number of rows 

        # Creates button to add chip data rows or remove all
        self.row_buttons = ttk.Frame(intro)
        self.row_buttons.pack(fill = "x", padx = 6, pady = 4)
        ttk.Button(self.row_buttons, text = "+ Add Chip Data", command = self.add_chip_row).pack(side = "left", pady=2)
        ttk.Button(self.row_buttons, text = "- Clear All Chip Data", command = self.remove_all_rows).pack(side = "left", pady = 2)
        self.row_buttons.pack_forget() # Hides row_buttons until user selects manual populate mode
    

    def show_frames(self):
        mode = self.populate_mode.get()
        if mode in ("p", "rp"):
            self.start_pos_frame.pack(fill = "x", padx = 6, pady = 4)
            self.chip_row_frame.pack_forget()
            self.row_buttons.pack_forget()
        elif mode == "m":
            self.start_pos_frame.pack_forget()
            self.chip_row_frame.pack(fill = "x", padx = 6, pady = 4)
            self.row_buttons.pack(fill = "x", padx = 6, pady = 4)
        else:
            self.start_pos_frame.pack_forget()
            self.chip_row_frame.pack_forget()
            self.row_buttons.pack_forget()
            
    # Creates function to add chip rows
    def add_chip_row(self):
        current_row_count = self.chip_row_count + 1 # Turns to next available row number
        row_widgets = {} # Initializes dictionary for that will hold widgets for each row 
        ttk.Label(self.chip_row_frame, text = str(current_row_count)).grid(row = current_row_count, column = 0, padx = 4) # label for row number

        # Creates six drop down menus for each header
        for column_counter, (key, vals) in enumerate([
            ("Tray", ["1", "2"]),
            ("Column", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]),
            ("Row", ["1", "2", "3", "4"]),
            ("DAT", ["1", "2"]),
            ("DAT Socket", ["21", "22"])
        ]):
            v = tk.StringVar(value = vals[0]) # Creates a variable v to hold onto current vals selection
            cb = ttk.Combobox(self.chip_row_frame, textvariable = v, values = vals, width = 12, state = "readonly") # Creates combo widget and forbids picking values out of list
            cb.grid(row = current_row_count, column = column_counter + 1, padx = 4, pady = 2) # places combo box in the right cell
            row_widgets[key] = v # Saves tk.StringVar under its field name in the dictionary (Useful to read value user picked)

        def remove(row_idx = current_row_count - 1):
            self.chip_rows.pop(row_idx) # Removes row's dictionary of StringVars from chip_rows
            # Rebuilds the display so that lower rows move upward
            for w in self.chip_row_frame.grid_slaves(): # Returns every widget currently placed in chip_row_frame
                if int(w.grid_info()["row"]) > 0: # Checks if row is not the header row
                    w.destroy() # destroys chip row's widgets
            self.chip_row_count = 0
            tmp = list(self.chip_rows) # Temporarily copies chip_rows into a temp list to keep chip_row data after deletion
            self.chip_rows = []
            # Loops through saved rows to re-add into chip_rows to reset row number that will be displayed in column
            for rd in tmp:
                self.add_chip_row_from_dict(rd) 

        ttk.Button(self.chip_row_frame, text = "X", width = 2, command = remove).grid(row = current_row_count, column = 6, padx = 4)
        self.chip_rows.append(row_widgets) 
        self.chip_row_count += 1

    # Helper method for remove() so that row below deleted row can be moved up
    def add_chip_row_from_dict(self, d):
        self.add_chip_row()
        last = self.chip_rows[-1]
        for k, v in d.items(): 
            last[k].set(v.get()) # Extracts StringVar() to set in brand new empty chip row
            
    
    def remove_all_rows(self):
        for w in self.chip_row_frame.grid_slaves(): # Returns every widget currently placed in chip_row_frame
            if int(w.grid_info()["row"]) > 0: # Checks if row is not the header row
                w.destroy()
        self.chip_rows = []
        self.chip_row_count = 0
    
    # Returns list of dictionaries from chip_rows to forward to RTSStateMachine
    def get_chip_list(self):
        result = []
        for rd in self.chip_rows:
            result.append({k: rd[k].get() for k in rd}) # From each row in self.chip_rows, call .get() on each widget's StringVar() to retrieve selected value
        return result

    # State tab 
    def build_state_tab(self):
        intro = self.state_tab

        states_frame = ttk.LabelFrame(intro, text = "State Information")
        states_frame.pack(fill = "both", expand = False, padx = 6, pady = 4)

        self.state_names = [
            "ground", "surveying_sockets", "moving_chip_to_socket",
            "running_ocr", "testing", "burning_serial_number",
            "writing_to_hwdb", "moving_chip_to_tray",
            "reseat", "moving_chip_to_bad_tray", "pause",
            "no_server_connection", "chip_in_socket", "vision_sequence_failed",
            "no_pressure", "lost_vacuum", "bad_contact", "no_chip",
            "safe_guard", "bad_pins", "no_serial_number",
            "failed_init", "no_wib_connection", "failed_upload"
        ]
        self.state_labels = {}
        cols = 3
        for i, s in enumerate(self.state_names):
            r, c = divmod(i, cols) # Calculates row and column for each state label based on index and number of columns
            lbl = ttk.Label(states_frame, relief = "groove", text = s, width = 26, anchor = "center", padding = (4,3))
            lbl.grid(row = r, column = c, padx = 4, pady = 2, sticky = "ew")
            states_frame.columnconfigure(c, weight = 1) # Makes each column expand equally when window is resized
            self.state_labels[s] = lbl # Saves each label in a dictionary with state name as key for easy access to highlight_state()

    # Input/Output helper to determine if waiting for input box is turned off or on and sets up if on
    def set_input_active(self, active, prompt = ""): 
        self.waiting_for_input = active
        if active: 
            self.prompt_var.set(prompt)
            self.answer_var.set("")
            self.submit_button.configure(state = "normal")
            self.answer_entry.configure(state = "normal")
            self.answer_entry.focus_set()
        else:
            self.prompt_var.set("{Waiting for program to ask for input}")
            self.answer_var.set("")
            self.submit_button.configure(state = "disabled")
            self.answer_entry.configure(state = "disabled")
        self.pending_prompt = prompt

    # Takes input and makes sure there is an answer, then calls send_answer
    def submit_answer(self): 
        if not self.waiting_for_input:
            return
        answer = self.answer_var.get()
        if not answer: # Do not do anything if there is no input
            return
        self.send_answer(answer)
    
    # Sends answer to worker thread
    def send_answer(self, answer): 
        if not self.running:
            return
        self.append_output(f" > {answer}\n", "answer") # self.append_ouput will write to CLI with color and timestamp
        self.reply_queue.put((self.current_prompt_id, answer)) # Puts answer into reply queue
        self.set_input_active(False) # Ends active input session to disable text input while RTS State Machine runs
        if self.paused:
            self.paused = False
            self.hide_pause_buttons()
            self.status.set("Running")

    
    # Adds response onto CLI coloring based on color tag
    def append_output(self, text, tag = "info"):
        if not text:
            return
        
        self.output.configure(state = "normal") # Allows for text to be written on CLI

        pos = 0 # Keeps track of the current position in the text as we iterate through it
        current_tag = tag # Keeps track of the current tag for coloring, which may change based on ANSI escape sequences

        for match in ANSI_ESCAPE.finditer(text): # Iterates through all ANSI escape sequences in the text
            segment = text[pos:match.start()] # Gets the segment of text before the ANSI escape sequence (hi there \x1b[31m red text \x1b[0m back to normal, segment will be " hi there ")

            if segment: # If there is a segment of text before the ANSI escape sequence, insert it into the output with the current tag for coloring
                lines = segment.split("\n") # Splits the segment into lines to handle newlines properly
                for i, line in enumerate(lines):
                    if line:
                        self.output.insert("end", line, current_tag)
                    if i < len(lines) - 1:
                        self.output.insert("end", "\n")

            ansi_codes = match.group(1).split(";") # Gets the ANSI codes from the escape sequence

            for codes in ansi_codes: # Iterates through each ANSI code in the escape sequence to determine the appropriate tag for coloring
                if codes in ("0", ""): # If the ANSI code is 0 or empty, reset the current tag to the original tag (which is passed in as an argument to append_output)
                    current_tag = tag # Resets to the original tag
                elif codes in ANSI_COLOR_MAP: # If the ANSI code is in the ANSI_COLOR_MAP, set the current tag to the corresponding tag for coloring
                    current_tag = ANSI_COLOR_MAP[codes] # Sets the current tag to the corresponding tag for coloring
            pos = match.end() # Updates the position to the end of the ANSI escape sequence

        remainder = text[pos:] # Gets the remainder of the text after the last ANSI escape sequence
        if remainder:
            lines = remainder.split("\n")
            for i, line in enumerate(lines):
                if line:
                    self.output.insert("end", line, current_tag)
                if i < len(lines) - 1:
                    self.output.insert("end", "\n")

        at_bottom = self.output.yview()[1] >= 0.99 # Checks if the output is scrolled to the bottom (yview returns a tuple of the current view position, where 1.0 is the bottom)
        if at_bottom:
            self.output.see("end")

        MAX_LINES = 2000
        line_count = int(self.output.index('end-1c').split('.')[0])
        if line_count > MAX_LINES:
            self.output.delete("1.0", f"{line_count - MAX_LINES}.0")
            
        self.output.configure(state = "disabled") # Keep console clean/read-only

    # Highlights the current state in the state tab
    def highlight_state(self, state_name):
        for name, lbl in self.state_labels.items():
            if name == state_name:
                lbl.configure(background = "navy", foreground = "white")
            else:
                lbl.configure(background = "", foreground = "black")

    def request_pause(self):
        if not self.running or self.paused:
            return
        self.pause_requested.set()
        self.status.set("Pausing...")
        self.pause_button.configure(state = "disabled")
    
    def hide_pause_buttons(self):
        self.pause_frame.pack_forget()
        self.input_frame.pack(fill = "both", padx = 6, pady = 6)
    
    def show_pause_buttons(self):
        self.pause_frame.pack(padx = 6, pady = 6)
        self.input_frame.pack_forget()

    def run(self):
        # Checks to see if there is already a session in progress, and refuse to start if there is one
        if self.running:
            return
        self.running = True
        self.paused = False
        self.pause_requested.clear()
        self.status.set("Running")
        self.run_button.configure(state = "disabled")
        self.pause_button.configure(state = "normal")

        set_up_answers = {
            "simulation_mode_answer": self.simulation_variable.get(),
            "bypass_rts_answer": self.bypass_rts_variable.get(),
            "username_answer": self.username_variable.get(),
            "populate_mode_answer": self.populate_mode.get(),
            "start_tray": self.start_tray.get(),
            "start_column": self.start_column.get(),
            "start_row": self.start_row.get(),
            "start_DAT": self.start_DAT.get()
        }

        chip_list = self.get_chip_list() if self.populate_mode.get() in ("m") else None # Saves self.chip_rows so that chip information modified afterward will not mess with program

        self.worker = threading.Thread( 
            target = self.worker_thread, # Has self.worker_thread be the function of self.worker (what the thread should execute and behave)
            args = (set_up_answers, chip_list, self.pause_requested), 
            daemon = True # Declare self.worker as a daemon so that process shuts off when window is deleted
        )
        self.worker.start()
    
    # This thread inserts start up questions into queue preloaded, puts stdout and stderr into output queue
    def worker_thread(self, set_up_answers, chip_list, pause_event):
        import builtins

        startup_queue = queue.Queue()
        startup_queue.put(set_up_answers["simulation_mode_answer"]) 
        startup_queue.put(set_up_answers["bypass_rts_answer"])
        startup_queue.put(set_up_answers["username_answer"])
        startup_queue.put(set_up_answers["populate_mode_answer"])

        if set_up_answers["populate_mode_answer"] == "m" and chip_list: # If populate mode is set to manual and there is a chip_list specified
            # Loads every inputted value for each header for each chip into startup_queue (So that we can have the values autoloaded for prompts)
            for i, chip in enumerate(chip_list):   
                startup_queue.put(chip.get("Tray"))
                startup_queue.put(chip.get("Column"))
                startup_queue.put(chip.get("Row"))
                startup_queue.put(chip.get("DAT"))
                startup_queue.put(chip.get("DAT Socket"))
                if i < len(chip_list) - 1:
                    startup_queue.put("y")
                else:
                    startup_queue.put("n")
        
        if set_up_answers["populate_mode_answer"] in ("p", "rp"):
            startup_queue.put(set_up_answers["start_tray"])
            startup_queue.put(set_up_answers["start_column"])
            startup_queue.put(set_up_answers["start_row"])
            startup_queue.put(set_up_answers["start_DAT"])


        provider = GUIInputProvider(self.input_queue, self.reply_queue) # Creates the live GUI input provider

        startup_phase = {"active": True} # Keeps track of whether we are in the startup phase or not, so that we can disable the input box when we are not in the startup phase
        prompt_counter = {"n": 0}

        # Answer start up prompts such as "Run in simulation mode", "Bypass RTS?", "Population mode"
        def gui_input(prompt = ""):
            if startup_phase["active"] and not startup_queue.empty():
                answer = startup_queue.get()
                self.output_queue.put(("info", f"[auto] {prompt}\n"))
                self.output_queue.put(("answer", f" >  {answer}\n"))
                return answer
            # Ask live GUI when startup_queue is empty
            prompt_counter["n"] += 1
            request_id = prompt_counter["n"]
            self.output_queue.put(("prompt", (request_id, prompt)))
            answer = provider.ask(prompt, request_id) # Calls GUIInputProvider.ask() to put prompt into input_queue and wait for reply_queue to get answer 
            return answer


        original_input = builtins.input # Saves the functions of the original input()
        original_stdout = sys.stdout # Saves the functions of the original sys.stdout
        original_stderr = sys.stderr # Saves the functions of the original sys.stderr

        builtins.input = gui_input # Reassigns function of input() to gui_input as to have input requests be sent to CLI
        sys.stdout = InputOutput(self.output_queue, "info") 
        sys.stderr = InputOutput(self.output_queue, "error") 

        # Here we run the actual functions 
        try:

            overrides = {
                "report_state_entry": lambda self_sm: self.output_queue.put(("__state__", self_sm.current_state.id)),
            }

            GUIRTSStateMachine = type("GUIRTSStateMachine", (RTSStateMachine,), overrides) # Creates a new class GUIRTSStateMachine that inherits from RTSStateMachine and overrides the on_enter methods to send state information to the output queue
            sm = GUIRTSStateMachine()

            startup_phase["active"] = False

            num_chips = len(sm.chip_positions['col'])
            num_full_cycles = num_chips // 2
            chips_processed = 0
            if num_chips %2 != 0:
                print("ERROR: Odd number of chips. Two chips must be tested at once.")
            else:
                for i in range(num_full_cycles):
                    print(f"\n--- Processing chip ({i*2+1}&{i*2+2})/{num_chips} ---")
                    
                    aborted_to_ground = False

                    while True:
                        if pause_event.is_set():
                            pause_event.clear()
                            self.after(0, self.show_pause_buttons) # Calls the show_pause_buttons method of the main thread to display the pause buttons in the GUI
                            self.output_queue.put(("__paused__", ""))

                            sm.pause_cycle() # Calls the pause_cycle method of the state machine to pause the current cycle and wait for user input

                            self.output_queue.put(("__resumed__", ""))

                            if sm.last_pause_action == "1":
                                aborted_to_ground = True
                                break

                            if sm.current_state.id == "ground":
                                break
                            continue

                        if sm.current_state.id == "ground" and len(sm.chip_positions['col']) > 0: # If the current state is "ground" and there are chips to process, we can proceed to the next state
                            sm.cycle()
                        elif sm.current_state.id == "moving_chip_to_tray": # If the current state is "moving_chip_to_tray", we can proceed to the next state
                            sm.cycle()
                            break 
                        else:
                            try:
                                sm.cycle()
                            except Exception as state_err: # Catches any exception that occurs during the state machine cycle and prints the state name and error message to the output queue for debugging
                                print(f"Error occurred in state '{sm.current_state.id}': {state_err}") # Prints the state name and error message to the output queue for debugging
                                raise state_err # Reraises the exception to be caught by the outer try-except block for further handling

                    if not aborted_to_ground:
                        chips_processed += 2 # Increments the number of chips processed by 2 to keep track of how many chips have been processed
                        sm.current_chip_index += 2 # Increments the current chip index by 2 to move to the next pair of chips
                        if sm.current_chip_index >= len(sm.chip_positions['col']): # If the current chip index exceeds the number of chips, reset it to 0 to start over
                            sm.current_chip_index = 0
                    else:
                        break
                print(f"\nTray processing complete! Processed {chips_processed} chips.")
            sm.end_state_machine()
            self.output_queue.put(("state", "Program ran successfully"))
            self.status.set("Finished")

        except SystemExit:
            self.output_queue.put(("info", "RTSStateMachine.py called sys.exit()"))
            self.status.set("RTS Quit")

        except Exception as exc:
            self.output_queue.put(("error", f"Exception: {type(exc).__name__}: {exc}")) # Sends to output queue what type of error and name of error recieved
            import traceback
            self.output_queue.put(("error", traceback.format_exc())) # Sends to output queue where error occured for troubleshooting
            self.status.set("Error")

        # Ensures that original input(), sys.stdout, and sys.stderr are restored as to prevent those calls being written to a dead queue
        finally: 
            builtins.input = original_input
            sys.stdout = original_stdout
            sys.stderr = original_stderr
            self.output_queue.put(("__done__", ""))        
    # Main thread
    def poll(self):
        # Checks output queue for any new messages from worker thread and displays them in CLI
        try:
            item  = self.output_queue.get_nowait() # .get_nowait() retrieves an item from the queue without blocking, raising queue.Empty if the queue is empty
            tag, text = item # Unpacks the tuple into tag and text for coloring and printing
            if tag == "__done__": 
                self.running = False
                self.paused = False
                self.run_button.configure(state = "normal")
                self.pause_button.configure(state = "disabled")
            elif tag == "__paused__":
                self.paused = True
                self.status.set("Paused")
                self.set_input_active(True, "")
            elif tag == "__resumed__":
                if self.paused:
                    self.paused = False
                    self.status.set("Running")
                self.pause_button.configure(state = "normal")
            elif tag == "__state__":
                self.highlight_state(text)
                self.append_output(f"[STATE] {text}\n", "state")
            elif tag == "prompt":
                request_id, prompt_text = text # Unpack the (id, prompt) pair so we know which specific input() call this is for
                self.current_prompt_id = request_id
                self.append_output(f"{prompt_text}\n", "prompt")
                self.set_input_active(True, prompt_text)
            else:
                self.append_output(text, tag)
        except queue.Empty:
            pass
        self.after(80, self.poll) # Call the poll function every 80 ms so that main thread keeps checking worker thread
                


# Starts this program
if __name__ == "__main__":
    app = ChipTestingGUI()
    app.mainloop()


    