# Set up RSA key on the local PC (only need to do it ONCE when first time to setup)
PC side: Open a terminal. click “Enter” 3 times, you can find private key id_rsa and public key id_rsa.pub under  $/.ssh
```
ssh-keygen.exe 

```

WIB side (ssh to WIB):
```
mkdir ~/.ssh/
Copy id_rsa.pub to WIB, save it at ~/.ssh/
mv ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

```

You now can log in WIB without typing password. If it doesn’t, reboot the WIB and try again. 


# 2. COLDATA QC by placing COLDATA chips manually (Windows version, Anaconda package for python3 is recommended)
PC side
```
python .\Manual_DAT_top.py
```
Follow the step by step instruction to conduct COLDATA QC testing. 




