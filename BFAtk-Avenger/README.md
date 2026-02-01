# 🛡️ BFAtk-Avenger (Brute Force Attack Avenger)

**BFAtk-Avenger** is a lightweight, automated defense script for Windows Servers and Workstations. It monitors Windows Security Logs for repeated failed login attempts (Brute Force attacks) and automatically bans the attacking IP addresses using the Windows Firewall.

It is designed to protect services like **RDP (Remote Desktop)** and **SMB** from botnets and script kiddies.

---

## 🚀 Key Features

* **Real-time Detection:** Scans the Windows Event Log (Event ID `4625`) for failed login attempts.
* **Automatic Blocking:** Instantly creates an Inbound Firewall Rule to block IPs that exceed the failure threshold.
* **Safety Whitelist:** Prevents accidental blocking of local IPs or trusted admin subnets.
* **Detailed Logging:** Keeps a persistent audit log (`Blocked_Audit_Log.txt`) of every action taken.
* **Scheduler Friendly:** Includes a Batch wrapper (`RunAvenger.bat`) designed to run silently via Windows Task Scheduler.

---

## 📂 Project Structure

Ensure your folder (`C:\Users\Kingadmin\Desktop\BFAtk-Avenger`) contains the following files:

1.  **`BlockAttackers.ps1`**: The core PowerShell logic that scans logs and bans IPs.
2.  **`RunAvenger.bat`**: A wrapper script. It handles Admin checks and switches between "Visual Mode" (for testing) and "Silent Mode" (