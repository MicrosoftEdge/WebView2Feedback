## Procmon

Process Monitor is an advanced monitoring tool for Windows that shows real-time file system, Registry and process/thread activity. Read more [here](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon).
 
Procmon logs can be helpful for cases where we get file not found error or access denied.


### Steps to collect Procmon logs 

1.	Download Procmon from [Microsoft Learn](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)

2.	Extract the zip file  and copy **Procmon.exe** ( or **Procmon64.exe** for 64-bit systems) to the target machine.

3.	Launch **Procmon.exe** and accept the license agreement

4.	By default, Procmon starts capturing events immediately. 

5.	Stop the capture by clicking the **Play button**.

6.	Before capturing the logs, one can add filters using the Filter button. 

7.	After applying the filters, start capturing the log by clicking the **Play button**.

8.	After your repro, again click the **Play button** to stop the capturing and then using the save button, save the logs as .PML file to any location.

9.	Compress these logs and share the zip file.
