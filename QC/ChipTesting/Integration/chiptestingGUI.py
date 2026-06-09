import os 
import sys
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import threading
import io
import time
from datetime import datetime
import queue

import ChipTesting.Integration.RTSStateMachine as RTSSM
from ChipTesting.Integration.RTSStateMachine import RTSStateMachine

# Makes imports from upper directories searchable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../..'))

# Takes standard console output and puts into a queue that this program will display with GUI
class InputOutput(io.TextIOBase):
    def __init__(self, queue, tag = "info"):
        self.queue = queue
        self.tag = tag
    
    def write(self, str):
        if str and str != "\n":
            self.queue.put((self.tag, str.rstrip("\n")))
        elif str == "\n":
            pass
        return len(str)
    def flush(self):
        pass

# Blocks "worker" thread until user responds with GUI input
class GUIInputProvider:
    def __init__(self, prompt_queue, reply_prompt):
        self.prompt_queue = prompt_queue
        self.reply_prompt = reply_prompt
    def ask(self, prompt = ""):
        self.prompt_queue.put(prompt.strip())
        return self.reply_prompt.get()

# Actual GUI for the program
class ChipTestingGUI(tk.Tk):
    # Sets initial window parameters
    def __init__(self):
        super().__init__()
        self.title("DUNE Chip Testing QC")
        self.geometry('1500x1100')
        self.minsize('1100x750')

        self.out_queue = queue.Queue()
        self.in_queue = queue.Queue()
        self.reply_queue = queue.Queue()
        self.worker = None
        self.running = False

        self.waiting_for_input = False
        self.pending_prompt = ""

    # Details of the UI itself
    def build_UI(self):
        style = ttk.Style(self)
        style.theme_use("default")

        # Details of top hotbar
        top_hotbar = ttk.Frame(self, relief = "groove")
        top_hotbar.pack(side = "top", fill = "x", padx = 6, pady= 4)
        
        ttk.Label(top_hotbar, text = "DUNE Chip Testing GC", font = ("Helvetica", 10, "Bold")).pack(side = "left", padx = 4, pady = 4)
        
        self.button_run = ttk.Button(top_hotbar, text = "▶ Play").pack(side = "left", padx = 4, pady = 4)
        self.button_abort = ttk.Button(top_hotbar, text  = "⏹ Abort").pack(side = "left", padx = 4, pady = 4)

        self.status = tk.StringVar(value = "Idle")
        ttk.Label(top_hotbar, textvariable = self.status, relief = "sunken", font = ("Helvetica", 10), width = 20).pack(side = "right", padx = 6, pady = 4)
        ttk.Label(top_hotbar, text = "Status:").pack(side = "right", padx = 4)

        








        



if __name__ == "__main__":
    app = ChipTestingGUI()
    app.mainloop()






        



    

    