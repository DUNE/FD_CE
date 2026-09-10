@echo off
call "C:\ProgramData\miniforge3\Scripts\activate.bat" base
cd /d "C:\Users\ppd-cap-WD-137552\FD_CE\QC\ChipTesting\BNL_QC"
python ..\Integration\chiptestingGUI.py
pause
