# uxLogs.sh
Commvault log collection script for Unix.

## Usage
Copy the script to the Unix system, make executable, and run:
```
# chmod +x uxLogs.sh
# ./uxLogs.sh
```

You can see all  options with `--help`.

The script will prompt you for where to create the bundle; defaults to /tmp.

## History
### 2023-05-24 Changes
While I do try not to break compatibility with AIX, macOS, and HPUX, I currently have no way of testing on those operating systems.

#### SQL Server
Fixed a situation where the script could report failure to collect /var/opt/mssql/log even if successful.

#### Linux
Improvements to capturing firewalld configuration.

#### WebServer
Now captures Commvault's Tomcat server.xml file, if present.

#### General
- Check that the script is running as root. Exit with error message if not.
- Several syntax improvements.

### 2023-03-15 Changes
#### SQL Server
Capture mssql.conf and /var/opt/mssql/log if `--mssql` is passed or if this is a Linux CS.

#### Linux Commserve
Capture the latest CSDR if `--csdr`  is passed. This does not confrim that backup is complete or valid.

### 2022-06-03 Changes
#### General
Capture the Base/certificates directory.

### 2022-01-19 Changes
#### General
Various syntax/output improvements.

#### Linux
- If tuned is installed, get config files (/etc/tuned/\*/tuned.conf, /usr/lib/tuned/\*/tuned.conf) and active profile name (/etc/tuned/active_profile).
- Get the complete package list (`rpm -qa` or `dpkg -l`) instead of just the glibc version.
- Get /etc/sysctl.conf and/or /etc/sysctl.d in addition to `sysctl -a` output.
- If ufw is installed, get `ufw status` output.

### 2020-11-18 Changes
#### FreeBSD
Collects kernel parameters.

#### HP-UX
Collects kernel parameters.

#### macOS
Collects kernel parameters.

#### Solaris
Collects kernel parameters for the user.root project as well as the simpana project, if it exists.

### 2020-11-11 Changes
#### Hyperscale
Auto-detects when being run on a Hyperscale node and collects related logging.

### 2020-10-09 Changes
#### General
No longer tries to read the SP level from the v10 locationi.

#### Linux
- Collects `firewall-cmd --list-all-zones` (for firewalld) and `nft list ruleset` (replaces iptables in RHEL8, Debian 10).
- Collects `sestatus -v` instead of just `sestatus`.
- Collects `sysctl -a` (kernel parameters).
- Collects /var/log/syslog (Ubuntu's system log).
