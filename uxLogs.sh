#!/bin/sh
# Run with '--help' for usage information.
# Updated 2023-05-24
# See https://github.com/greenseeker/uxlogs for latest version

# Make sure uxLogs.sh was run as root.
[ "$(id -u)" -ne 0 ] && printf "%s\n" "This script needs to run as root." 1>&2 && exit

# Get command line parameters.
params="$*"
 
# Function to test if string contains substring.
contains() {
 string="$1"
 substring="$2"
 if test "${string#*$substring}" != "${string}"; then
  return 0
 else
  return 1
 fi
}
 
# If '--help' is among the command line parameters, print help text and quit.
if (contains "${params}" "--help"); then
 printf "\n%s\n\n" "This is a Commvault log collection script for AIX, FreeBSD, HP-UX, Linux, macOS, and Solaris."
 printf "%s\n" "It captures the Commvault log directories for each instance as well as various system info."
 printf "\n%s\n\n" "This info will be saved in the specified temp folder in the form of a .tar.gz file."
 
 printf "%s\n" "Options:"
 printf "%s\n" "    --db2        Collect db2diag logs, db2level, DB configs (will run su - <db2user>)"
 printf "%s\n" "    --csdr       Collect the latest Commserve DR backup (may be very large)"
 printf "%s\n" "    --informix   Collect onconfig, ONBar activity log, ONBar debug log (will run su - <informixuser>)"
 printf "%s\n" "    --mssql      Collect SQL Server logs and config file (automatic on Commserve)"
 printf "%s\n" "    --mysql      Collect my.cnf"
 printf "%s\n" "    --sybase     Collect Sybase configuration and dataserver/backupserver errorlogs" 
 printf "\n\n"
 exit
fi
 
# The error-handler
bail() {
 printf "    %s\n" "$1" 1>&2
 tar -rhf "${tarball}" * >> "${scriptLog}" 2>&1
 cleanup
 exit 1
}
 
# A cleanup function to change back to the starting path and delete our temp directory.
cleanup(){
 printf "\n%s\n" "Cleaning up ..."
 cd ${startDir}
 rm -rf "${tmpDir}/cvcollect"
}
 
# Check that the CVR exists.
[ ! -d /etc/CommVaultRegistry ] && printf "%s\n" "Unable to find /etc/CommVaultRegistry -- aborting." && exit
 
# Prompt for a temp path, default to /tmp.
printf "%s" "Enter temp path [/tmp]: "
read tmpDir
[ -z "${tmpDir}" ] && tmpDir="/tmp"
 
startDir=$(pwd)
hostname=$(hostname | cut -d'.' -f1)
flavor=$(uname -s)
scriptLog="${tmpDir}/cvcollect/_uxLogs.log"
infoFile="${tmpDir}/cvcollect/_INFOFILE.txt"
 
# Prompt for a job ID
printf "%s" "If applicable, enter the job number: "
read JID
 
# Set the name/location of the tarball
[ -z "${JID}" ] && tarball=${tmpDir}/${hostname}_uxLogs_$(date +'%Y%m%d_%H%M%S').tar || tarball=${tmpDir}/${hostname}_${JID}_uxLogs.tar
 
# Set umask so that files/directories are created 777
umask 0000
 
# Make sure no prior uxLogs file is present and that our temp directory doesn't exist, then create it.
[ -f "${tarball}" ] && printf "%s already exists. Please delete, move or rename, or use a different temp path.\n" "${tarball}" && exit
[ -f "${tarball}.gz" ] && printf "%s.gz already exists. Please delete, move or rename, or use a different temp path.\n" "${tarball}" && exit
[ -d "${tmpDir}/cvcollect" ] && printf "%s/cvcollect already exists. Please delete or rename, or use a different temp path.\n" "${tmpDir}" && exit || mkdir "${tmpDir}/cvcollect"
 
cd "${tmpDir}/cvcollect"
 
# Log the command line arguments
printf "%s\n" "Command line arguments: ${params}" >> "${scriptLog}"
 
# Collect basic system info.
printf "%s\n\n" "$(uname -a)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "%s\n" "Captured uname output" | tee -a "${scriptLog}"
 
# Identify the Commvault binary and collect platform-specific info
case ${flavor} in
 Linux) 
  printf "%s\n" "Linux detected" | tee -a "${scriptLog}"
  db2Instances=$(ps -ef | awk '/[d]b2sysc/{ print $1 }' | sort | uniq)
  ifxInstances=$(ps -ef | awk '/[o]ninit/{ print $1 }' | grep -v "^root" | sort | uniq)
  which commvault         >> /dev/null 2>&1 && printf "%s" "Capturing commvault service state ... "         && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"          && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  which simpana           >> /dev/null 2>&1 && printf "%s" "Capturing simpana service state ... "           && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"            && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  which galaxy            >> /dev/null 2>&1 && printf "%s" "Capturing galaxy service state ... "            && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"             && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  which Galaxy            >> /dev/null 2>&1 && printf "%s" "Capturing Galaxy service state ... "            && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"             && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  which HitachiHDS        >> /dev/null 2>&1 && printf "%s" "Capturing HitachiHDS service state ... "        && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"         && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  which Calypso           >> /dev/null 2>&1 && printf "%s" "Capturing Calypso service state ... "           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"            && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  which StorageServices   >> /dev/null 2>&1 && printf "%s" "Capturing StorageServices service state ... "   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"    && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  which StorageProtection >> /dev/null 2>&1 && printf "%s" "Capturing StorageProtection service state ... " && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt"  && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  which snapprotect       >> /dev/null 2>&1 && printf "%s" "Capturing snapprotect service state ... "       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"        && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Collecting disk info, firewall rules, SELinux status, NIC config, systemd journal, and kernel parameters..."  | tee -a "${scriptLog}"
  printf "%s\n\n%s\n\n%s\n\n" "$(df -hT)" "$(df -hi)" "$(mount)" >> "${tmpDir}/cvcollect/disks.txt" && printf "... %s\n" "Disk space and mount info collected" | tee -a "${scriptLog}"
  which vgdisplay >> /dev/null 2>&1 && vgdisplay -v >> "${tmpDir}/cvcollect/disks.txt" 2>&1 && printf "... %s\n" "LVM info collected" | tee -a "${scriptLog}"
  systemctl is-active firewalld >> /dev/null 2>&1 && echo "=== firewalld ===" >> "${tmpDir}/cvcollect/firewall.txt" && firewall-cmd --list-all-zones >> "${tmpDir}/cvcollect/firewall.txt" 2> /dev/null && printf "... %s\n" "firewalld rules collected" | tee -a "${scriptLog}" || printf "%s\n%s\n\n" "=== firewalld ===" "firewalld is not running" >> "${tmpDir}/cvcollect/firewall.txt"
  which nft >> /dev/null 2>&1 && echo "=== nftables ===" >> "${tmpDir}/cvcollect/firewall.txt" && nft list ruleset >> "${tmpDir}/cvcollect/firewall.txt" && printf "... %s\n" "nftables rules collected" | tee -a "${scriptLog}"
  which ufw >> /dev/null 2>&1 && echo "=== ufw ===" >> "${tmpDir}/cvcollect/firewall.txt" && ufw status >> "${tmpDir}/cvcollect/firewall.txt" && printf "... %s\n" "ufw rules collected" | tee -a "${scriptLog}"
  which iptables >> /dev/null 2>&1 && echo "=== iptables ===" >> "${tmpDir}/cvcollect/firewall.txt" && iptables -vnL >> "${tmpDir}/cvcollect/firewall.txt" && printf "... %s\n" "iptables rules collected" | tee -a "${scriptLog}"
  which sestatus >> /dev/null 2>&1 && printf "%s\n\n" "$(sestatus -v)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "... %s\n" "SELinux status collected" | tee -a "${scriptLog}"
  which ip >> /dev/null 2>&1 && ip addr >> "${tmpDir}/cvcollect/network.txt" && printf "... %s\n" "Interface list collected" | tee -a "${scriptLog}"
  which journalctl >> /dev/null 2>&1 && journalctl --no-pager >> "${tmpDir}/cvcollect/systemd_journal.log" && printf "... %s\n" "systemd journal collected" | tee -a "${scriptLog}"
  which sysctl >> /dev/null 2>&1 && sysctl -a >> "${tmpDir}/cvcollect/kernel_parameters.txt" 2>&1 && printf "... %s\n" "Kernel parameters collected" | tee -a "${scriptLog}"

  if which tuned-adm >> /dev/null 2>&1; then
    printf "\n%s\n" "Collecting tuned profile configs ... " | tee -a "${scriptLog}" 
    for tmp in /etc/tuned/active_profile /etc/tuned/*/tuned.conf /usr/lib/tuned/*/tuned.conf; do
      [ -f "${tmp}" ] && printf "... %s\n" "${tmp} found" | tee -a "${scriptLog}" && tar -rhf "${tarball}" ${tmp} >> "${scriptLog}" 2>&1
    done
  fi

  if [ -d /etc/sysctl.d ] || [ -f /etc/sysctl.conf ]; then
	printf "\n%s\n" "Collecting sysctl.conf and/or sysctl.d ... " | tee -a "${scriptLog}"
    for tmp in /etc/sysctl*; do
      [ -f "${tmp}" ] && printf "... %s\n" "${tmp} found" | tee -a "${scriptLog}" && tar -rhf "${tarball}" ${tmp} >> "${scriptLog}" 2>&1
    done
  fi

  printf "\n%s\n" "Collecting installed package list ... " | tee -a "${scriptLog}"
  if [ -f /usr/bin/rpm ] || [ - /usr/bin/dnf ]; then
    rpm -qa | sort >> "${tmpDir}/cvcollect/installed_rpm_packages.txt" && printf "%s\n" "rpm packages collected" | tee -a "${scriptLog}"
  elif [ -f /usr/bin/dpkg ]; then
    dpkg -l >> "${tmpDir}/cvcollect/installed_deb_packages.txt" && printf "%s\n" "deb packages collected" | tee -a "${scriptLog}"
  else
    printf "%s\n" "package manager not found"
  fi
  ;;
 SunOS) 
  printf "%s\n" "Solaris detected" | tee -a "${scriptLog}"
  db2Instances=$(ps -ef | awk '/[d]b2sysc/{ print $1 }' | sort | uniq)
  ifxInstances=$(ps -ef | awk '/[o]ninit/{ print $1 }' | grep -v "^root" | sort | uniq)
  [ -f /usr/bin/commvault ]         && printf "%s" "Capturing commvault service state ... "        && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"         && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  [ -f /usr/bin/simpana ]           && printf "%s" "Capturing simpana service state ... "          && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"           && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  [ -f /usr/bin/galaxy ]            && printf "%s" "Capturing galaxy service state ... "           && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"            && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  [ -f /usr/bin/Galaxy ]            && printf "%s" "Capturing Galaxy service state ... "           && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"            && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  [ -f /usr/bin/HitachiHDS ]        && printf "%s" "Capturing HitachiHDS service state ... "       && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"        && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  [ -f /usr/bin/Calypso ]           && printf "%s" "Capturing Calypso service state ..."           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"           && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  [ -f /usr/bin/StorageServices ]   && printf "%s" "Capturing StorageServices service state ..."   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"   && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  [ -f /usr/bin/StorageProtection ] && printf "%s" "Capturing StorageProtection service state ..." && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt" && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  [ -f /usr/bin/snapprotect ]       && printf "%s" "Capturing snapprotect service state ..."       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"       && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Collecting disk info, iptables rules, IPFilter status, and NIC state ..." | tee -a "${scriptLog}"
  printf "%s\n\n\n%s" "$(df -k)" "$(mount)" >> "${tmpDir}/cvcollect/disks.txt" && printf "... %s\n" "Diskspace and mount info collected" | tee -a "${scriptLog}"
  [ -f /usr/sbin/ipfstat ]          && ipfstat -io >> "${tmpDir}/cvcollect/firewall.txt" 2>&1 && printf "... %s\n" "Firewall rules collected" | tee -a "${scriptLog}"
  [ -f /usr/sbin/ifconfig ]         && ifconfig -a >> "${tmpDir}/cvcollect/network.txt" && printf "... %s\n" "Interface list collected" | tee -a "${scriptLog}" 
  [ -f /usr/bin/prctl]              && prctl -i project user.root simpana 2>&1 >> "${tmpDir}/cvcollect/kernel_parameters.txt" && printf "... %s\n" "Kernel parameters collected"
  ;;
 Darwin) 
  printf "%s\n" "macOS detected" | tee -a "${scriptLog}"
  which -s commvault             && printf "%s" "Capturing commvault service state ... "        && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"          && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  which -s simpana               && printf "%s" "Capturing simpana service state ... "          && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"            && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  which -s galaxy                && printf "%s" "Capturing galaxy service state ... "           && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"             && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  which -s Galaxy                && printf "%s" "Capturing Galaxy service state ... "           && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"             && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  which -s HitachiHDS            && printf "%s" "Capturing HitachiHDS service state ... "       && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"         && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  which -s Calypso               && printf "%s" "Capturing Calypso service state ..."           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"            && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  which -s StorageServices       && printf "%s" "Capturing StorageServices service state ..."   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"    && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  which -s StorageProtection     && printf "%s" "Capturing StorageProtection service state ..." && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt"  && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  which -s snapprotect           && printf "%s" "Capturing snapprotect service state ..."       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"        && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Collecting disk info, firewall status, OS version, and NIC state ..."  | tee -a "${scriptLog}"
  printf "%s\n\n\n%s" "$(df -h)" "$(mount)" >> "${tmpDir}/cvcollect/disks.txt" && printf "... %s\n" "Diskspace and mount info collected" | tee -a "${scriptLog}"
  which -s ipfw                  && ipfw list >> "${tmpDir}/cvcollect/firewall.txt" && printf "... %s\n" "Firewall rules collected" | tee -a "${scriptLog}"
  printf "%s\n\n" "$(sw_vers)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "... %s\n" "macOS version collected" | tee -a "${scriptLog}"
  which -s ifconfig              && ifconfig -a >> "${tmpDir}/cvcollect/network.txt" && printf "... %s\n" "Interface list collected" | tee -a "${scriptLog}" 
  which sysctl >> /dev/null 2>&1 && sysctl -a >> "${tmpDir}/cvcollect/kernel_parameters.txt" 2>&1 && printf "... %s\n" "Kernel parameters collected" | tee -a "${scriptLog}"
  ;;
 FreeBSD) 
  printf "%s\n" "FreeBSD detected" | tee -a "${scriptLog}"
  db2Instances=$(ps -aux | awk '/[d]b2sysc/{ print $1 }' | sort | uniq)
  ifxInstances=$(ps -aux | awk '/[o]ninit/{ print $1 }' | grep -v "^root" | sort | uniq)
  which -s commvault         && printf "%s" "Capturing commvault service state ... "        && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"          && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  which -s simpana           && printf "%s" "Capturing simpana service state ... "          && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"            && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  which -s galaxy            && printf "%s" "Capturing galaxy service state ... "           && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"             && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  which -s Galaxy            && printf "%s" "Capturing Galaxy service state ... "           && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"             && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  which -s HitachiHDS        && printf "%s" "Capturing HitachiHDS service state ... "       && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"         && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  which -s Calypso           && printf "%s" "Capturing Calypso service state ..."           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"            && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  which -s StorageServices   && printf "%s" "Capturing StorageServices service state ..."   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"    && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  which -s StorageProtection && printf "%s" "Capturing StorageProtection service state ..." && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt"  && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  which -s snapprotect       && printf "%s" "Capturing snapprotect service state ..."       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"        && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Checking disk space, IPFilter status, and NIC state ..." | tee -a "${scriptLog}"
  printf "%s\n\n\n%s" "$(df -h)" "$(mount)" >> "${tmpDir}/cvcollect/disks.txt" && printf "... %s\n" "Diskspace and mount info collected" | tee -a "${scriptLog}"
  which -s ipfstat           && ipfstat -io >> "${tmpDir}/cvcollect/firewall.txt" 2>&1 && printf "... %s\n" "Firewall rules collected" | tee -a "${scriptLog}"
  which -s ifconfig          && ifconfig -a >> "${tmpDir}/cvcollect/network.txt" && printf "... %s\n" "Interface list collected" | tee -a "${scriptLog}" 
  which -s sysctl            && sysctl -a >> "${tmpDir}/cvcollect/kernel_parameters.txt" 2>&1 && printf "... %s\n" "kernel parameters collected" | tee -a "${scriptLog}"
  ;;
 HP-UX) 
  printf "%s\n" "HP-UX detected" | tee -a "${scriptLog}"
  db2Instances=$(ps -ef | awk '/[d]b2sysc/{ print $1 }' | sort | uniq)
  ifxInstances=$(ps -ef | awk '/[o]ninit/{ print $1 }' | grep -v "^root" | sort | uniq)
  [ -f /usr/bin/commvault ]         && printf "%s" "Capturing commvault service state ... "        && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"         && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  [ -f /usr/bin/simpana ]           && printf "%s" "Capturing simpana service state ... "          && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"           && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  [ -f /usr/bin/galaxy ]            && printf "%s" "Capturing galaxy service state ... "           && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"            && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  [ -f /usr/bin/Galaxy ]            && printf "%s" "Capturing Galaxy service state ... "           && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"            && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  [ -f /usr/bin/HitachiHDS ]        && printf "%s" "Capturing HitachiHDS service state ... "       && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"        && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  [ -f /usr/bin/Calypso ]           && printf "%s" "Capturing Calypso service state ..."           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"           && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  [ -f /usr/bin/StorageServices ]   && printf "%s" "Capturing StorageServices service state ..."   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"   && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  [ -f /usr/bin/StorageProtection ] && printf "%s" "Capturing StorageProtection service state ..." && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt" && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  [ -f /usr/bin/snapprotect ]       && printf "%s" "Capturing snapprotect service state ..."       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"       && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Checking disk space, IPFilter status, and NIC state ..." | tee -a "${scriptLog}"
  printf "%s\n\n\n%s" "$(bdf -i)" "$(mount -v)" >> "${tmpDir}/cvcollect/disks.txt" && printf "%s\n" "Diskspace and mount info collected" | tee -a "${scriptLog}"
  [ -f /opt/ipf/bin/ipfstat ]       && ipfstat -io >> "${tmpDir}/cvcollect/firewall.txt" 2>&1 && printf "%s\n" "Firewall rules collected" | tee -a "${scriptLog}"
  [ -f /usr/bin/netstat ]           && netstat -in >> "${tmpDir}/cvcollect/network.txt" && printf "%s\n" "Interface list collected" | tee -a "${scriptLog}"
  [ -f /usr/sbin/kctune ]           && kctune >> "${tmpDir}/cvcollect/kernel_parameters.txt" 2>&1 && printf "... %s\n" "kernel parameters collected" | tee -a "${scriptLog}"
  ;;
 AIX) 
  printf "%s\n" "AIX detected" | tee -a "${scriptLog}"
  db2Instances=$(ps -ef | awk '/[d]b2sysc/{ print $1 }' | sort | uniq)
  ifxInstances=$(ps -ef | awk '/[o]ninit/{ print $1 }' | grep -v "^root" | sort | uniq)
  which commvault         >> /dev/null 2>&1 && printf "%s" "Capturing commvault service state ... "        && commvault list         >> "${tmpDir}/cvcollect/commvault_list.txt"          && printf "%s\n" "commvault list captured"         | tee -a "${scriptLog}"
  which simpana           >> /dev/null 2>&1 && printf "%s" "Capturing simpana service state ... "          && simpana list           >> "${tmpDir}/cvcollect/simpana_list.txt"            && printf "%s\n" "simpana list captured"           | tee -a "${scriptLog}"
  which galaxy            >> /dev/null 2>&1 && printf "%s" "Capturing galaxy service state ... "           && galaxy list            >> "${tmpDir}/cvcollect/galaxy_list.txt"             && printf "%s\n" "galaxy list captured"            | tee -a "${scriptLog}"
  which Galaxy            >> /dev/null 2>&1 && printf "%s" "Capturing Galaxy service state ... "           && Galaxy list            >> "${tmpDir}/cvcollect/Galaxy_list.txt"             && printf "%s\n" "Galaxy list captured"            | tee -a "${scriptLog}"
  which HitachiHDS        >> /dev/null 2>&1 && printf "%s" "Capturing HitachiHDS service state ..."        && HitachiHDS list        >> "${tmpDir}/cvcollect/HitachiHDS_list.txt"         && printf "%s\n" "HitachiHDS list captured"        | tee -a "${scriptLog}"
  which Calypso           >> /dev/null 2>&1 && printf "%s" "Capturing Calypso service state ..."           && Calypso list           >> "${tmpDir}/cvcollect/Calypso_list.txt"            && printf "%s\n" "Calypso list captured"           | tee -a "${scriptLog}"
  which StorageServices   >> /dev/null 2>&1 && printf "%s" "Capturing StorageServices service state ..."   && StorageServices list   >> "${tmpDir}/cvcollect/StorageServices_list.txt"    && printf "%s\n" "StorageServices list captured"   | tee -a "${scriptLog}"
  which StorageProtection >> /dev/null 2>&1 && printf "%s" "Capturing StorageProtection service state ..." && StorageProtection list >> "${tmpDir}/cvcollect/StorageProtection_list.txt"  && printf "%s\n" "StorageProtection list captured" | tee -a "${scriptLog}"
  which snapprotect       >> /dev/null 2>&1 && printf "%s" "Capturing snapprotect service state ..."       && snapprotect list       >> "${tmpDir}/cvcollect/snapprotect_list.txt"        && printf "%s\n" "snapprotect list captured"       | tee -a "${scriptLog}"
  printf "%s\n" "Checking disk space, NIC state, and OS info ..." | tee -a "${scriptLog}"
  printf "%s\n\n\n%s" "$(df -m)" "$(mount)" >> "${tmpDir}/cvcollect/disks.txt" && printf "%s\n" "Diskspace and mount info collected" | tee -a "${scriptLog}"
  errpt -a >> "${tmpDir}/cvcollect/errpt.txt" && printf "%s\n" "Error Report collected" | tee -a "${scriptLog}" 
  printf "%s\n\n\n%s" "$(ifconfig -a)" "$(netstat -in)" >> "${tmpDir}/cvcollect/network.txt" && printf "%s\n" "Network interface info collected" | tee -a "${scriptLog}"
  printf "OS Level: %s\n\n" "$(oslevel -s)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "%s\n" "OS level collected" | tee -a "${scriptLog}"
  which prtconf >> /dev/null 2>&1 && printf "==== prtconf: \n%s\n\n" "$(prtconf)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "%s\n" "System Config collected" | tee -a "${scriptLog}"
  which lparstat >> /dev/null 2>&1 && printf "==== lparstat: \n%s\n\n" "$(lparstat -i)" >> "${tmpDir}/cvcollect/osinfo.txt" && printf "%s\n" "LPar Stats collected" | tee -a "${scriptLog}"
  ;;
esac
 
# Capture time and uptime.
printf "\n%s ...\n" "Capturing datetime and uptime" | tee -a "${scriptLog}" 
printf "date:   %s\nuptime: %s\n\n" "$(date)" "$(uptime)" >> "${tmpDir}/cvcollect/osinfo.txt"
 
# Capture the Commvault Registry.
printf "%s ...\n" "Collecting Commvault Registry" | tee -a "${scriptLog}" 
tar -rhf "${tarball}" /etc/CommVaultRegistry >> "${scriptLog}" 2>&1 || bail "--- Failed to tar Commvault Registry; aborting ..."
 
# Capture the hosts file.
printf "%s\n" "Collecting /etc/hosts ..." | tee -a "${scriptLog}" 
tar -rhf "${tarball}" /etc/hosts >> "${scriptLog}" 2>&1 || printf "    --- %s\n ..." "Failed to tar /etc/hosts; continuing"
 
# Capture resolv.conf.
printf "%s\n" "Collecting /etc/resolv.conf ..." | tee -a "${scriptLog}" 
tar -rhf "${tarball}" /etc/resolv.conf >> "${scriptLog}" 2>&1 || printf "    --- %s ...\n" "Failed to tar /etc/resolv.conf; continuing"
 
# Capture nsswitch.conf, netsvc.conf
for tmp in /etc/nsswitch.conf /etc/netsvc.conf; do
  [ -f "${tmp}" ] && printf "%s ...\n" "Collecting ${tmp}" | tee -a "${scriptLog}" && tar -rhf "${tarball}" ${tmp} >> "${scriptLog}" 2>&1
done
 
# Capture the messages log, syslog, or system log file.
printf "\n%s\n" "Collecting system log(s) ..." | tee -a "${scriptLog}"
[ -f "/var/log/messages" ] && tar -rhf "${tarball}" /var/log/messages >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/messages found" | tee -a "${scriptLog}"
[ -f "/var/log/syslog" ] && tar -rhf "${tarball}" /var/log/syslog >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/syslog found" | tee -a "${scriptLog}"
[ -f "/var/adm/messages" ] && tar -rhf "${tarball}" /var/adm/messages >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/adm/messages found" | tee -a "${scriptLog}"
[ -f "/var/adm/syslog/syslog.log" ] && tar -rhf "${tarball}" /var/adm/syslog/syslog.log >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/adm/syslog/syslog.log found" | tee -a "${scriptLog}"
[ -f "/var/log/system.log" ] && tar -rhf "${tarball}" /var/log/system.log >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/system.log found" | tee -a "${scriptLog}"
 
# Capture release/version/issue files, if any.
printf "\n%s\n" "Collecting release info ..." | tee -a "${scriptLog}"
for tmp in /etc/issue /etc/*release /etc/*version; do
  [ -f "${tmp}" ] && printf "... %s\n" "${tmp} found" | tee -a "${scriptLog}" && tar -rhf "${tarball}" ${tmp} >> "${scriptLog}" 2>&1
done
 
# Collect 1-Touch backup info, if present.
printf "\n%s" "Checking for 1-Touch backup info ... "
[ -d "/tmp/sysconf" ] && printf " %s\n" "Collecting 1-Touch backup info" | tee -a "${scriptLog}" && tar -rf "${tarball}" /tmp/sysconf >> "${scriptLog}" 2>&1
[ ! -d "/tmp/sysconf" ] && printf " %s\n" "No 1-Touch backup info found" | tee -a "${scriptLog}" 
 
# Capture DB2 info if requested.
if (contains "${params}" "--db2"); then
 for db2user in ${db2Instances}; do
  mkdir -p "${tmpDir}/cvcollect/db2/${db2user}"
  dbList=$(su - ${db2user} -c "db2 list db directory" | awk '/Database name/{ print $4 }')
   for db in ${dbList}; do
    printf "%s\n" "Capturing DBInfo for ${db2user}/${db} ..."
    su - ${db2user} -c "db2 get db cfg for ${db} >> ${tmpDir}/cvcollect/db2/${db2user}/dbInfo_${db}.txt"
    su - ${db2user} -c "db2 list history backup all for ${db} >> ${tmpDir}/cvcollect/db2/${db2user}/backupHistory_${db}.txt"
   done
  diagpath=$(su - ${db2user} -c "db2 get dbm cfg" | awk '/\(DIAGPATH\)/{ print $7 }')
  printf "%s\n" "Collecting ${diagpath}/db2diag* ..." | tee -a "${scriptLog}"
  cp "${diagpath}/db2diag*" "${tmpDir}/cvcollect/db2/${db2user}"
  su - ${db2user} -c "db2level >> ${tmpDir}/cvcollect/db2/${db2user}/db2level.txt"
 done
fi
 
# Capture Informix info if requested.
if (contains "${params}" "--informix"); then
 for ifxuser in ${ifxInstances}; do
  mkdir -p "${tmpDir}/cvcollect/informix/${ifxuser}"
  su - ${ifxuser} -c "cp \${INFORMIXDIR}/etc/\${ONCONFIG} ${tmpDir}/cvcollect/informix/${ifxuser}" > /dev/null
  su - ${ifxuser} -c "echo \"\${INFORMIXDIR}/etc/\${ONCONFIG}\" > ${tmpDir}/cvcollect/onconfpath" > /dev/null
  onconf=$(cat "${tmpDir}/cvcollect/onconfpath")
  printf "%s\n" "Onconfig at ${onconf}"
  baractlog=$(awk '/^BAR_ACT_LOG/ { print $2 }' ${onconf})
  [ -f ${baractlog} ] && cp ${baractlog} "${tmpDir}/cvcollect/informix/${ifxuser}" || printf "%s\n" "${baractlog} not found -- continuing..."
  bardebuglog=$(awk '/^BAR_DEBUG_LOG/ { print $2 }' ${onconf})
  [ -f ${bardebuglog} ] && cp ${bardebuglog} "${tmpDir}/cvcollect/informix/${ifxuser}" || printf "%s\n" "${bardebuglog} not found -- continuing..."
  su - ${ifxuser} -c "onstat > "${tmpDir}/cvcollect/informix/${ifxuser}/onstat.txt"" > /dev/null
 done
 rm "${tmpDir}/cvcollect/onconfpath"
fi
 
# Capture MySQL info if requested.
if (contains "${params}" "--mysql"); then
 mkdir -p "${tmpDir}/cvcollect/mysql"
 [ -f /etc/my.cnf ] && printf "%s\n" "Collecting /etc/my.cnf ..." | tee -a "${scriptLog}" && cp /etc/my.cnf "${tmpDir}/cvcollect/mysql"
 [ -f /etc/mysql/my.cnf ] && printf "%s\n" "Collecting /etc/mysql/my.cnf ..." | tee -a "${scriptLog}" && cp /etc/mysql/my.cnf "${tmpDir}/cvcollect/mysql"
fi
 
# Capture Sybase info if requested.
if (contains "${params}" "--sybase"); then
 mkdir -p "${tmpDir}/cvcollect/sybase"
 SBerrorlog=$(ps -ef | grep "[d]ataserver" | sed "s/.*-e//g" | sed "s/[ ]-[^e].*//g")
 SBBSerrorlog=$(ps -ef | grep "[b]ackupserver" | sed "s/.*-e//g" | sed "s/[ ]-[^e].*//g")
 SBconfig=$(ps -ef | grep "[d]ataserver" | sed "s/.*-c//g" | sed "s/[ ]-[^c].*//g")
 [ -f "${SBerrorlog}" ] && printf "%s\n" "Collecting ${SBerrorlog} ..." | tee -a "${scriptLog}" && cp ${SBerrorlog} "${tmpDir}/cvcollect/sybase"
 [ -f "${SBBSerrorlog}" ] && printf "%s\n" "Collecting ${SBBSerrorlog} ..." | tee -a "${scriptLog}" && cp ${SBBSerrorlog} "${tmpDir}/cvcollect/sybase"
 [ -f "${SBconfig}" ] && printf "%s\n" "Collecting ${SBconfig} ..." | tee -a "${scriptLog}" && cp ${SBconfig} "${tmpDir}/cvcollect/sybase"
fi

# Capture per-instance info.
instList=$(ls -1d /etc/CommVaultRegistry/Galaxy/Instance*)
for cvinst in ${instList}; do
 base=$(awk '/dHOME /{ print $2 }' ${cvinst}/Base/.properties)
 logs=$(awk '/dEVLOGDIR /{ print $2 }' ${cvinst}/EventManager/.properties)
 jobR=$(awk '/dJOBRESULTSDIR /{ print $2 }' ${cvinst}/Machines/*/.properties)
 csName=$(awk '/sCSHOSTNAME /{ print $2 }' ${cvinst}/CommServe/.properties)
 scaleoutPlatform=$(awk '/sScaleoutPlatformType /{ print $2 }' ${cvinst}/MediaAgent/.properties)
 isCS=$(awk '/dHOME /{ print $2 }' ${cvinst}/CommServe/.properties)
 drPath=$(awk '/sCSDRPATH /{ print $2 }' ${cvinst}/CommServe/.properties)
 tomcatPath=$(awk '/sZTOMCATHOME/ { print $2 }' ${cvinst}/WebConsole/.properties)

 
 printf "%s\n" "=== ${cvinst} ===" >> "${infoFile}"
 [ "${scaleoutPlatform}" == "HyperScale" ] && printf "%s\n" "HyperScale: True" >> "${infoFile}" || printf "%s\n" "HyperScale: False" >> "${infoFile}"
 printf "%s\n"   " Commserve: ${csName}" >> "${infoFile}"
 printf "%s\n"   "      Base: ${base}" >> "${infoFile}"
 printf "%s\n"   "      Logs: ${logs}" >> "${infoFile}"
 printf "%s\n\n" "jobResults: ${jobR}" >> "${infoFile}"
 
# Capture network certificates.
 printf "\n%s\n" "Collecting ${base}/certificates ..." | tee -a "${scriptLog}"
 tar -rhf "${tarball}" ${base}/certificates >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar ${base}/certificates; continuing ..."
 
# Capture cvfwd config.
 printf "\n%s\n" "Collecting ${base}/Fw* ..." | tee -a "${scriptLog}"
 tar -rhf "${tarball}" ${base}/Fw* >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar ${base}/Fw*; continuing ..."
 
# Capture job-specific information.
 if [ -n "${JID}" ]; then
  for temp in ${jobR}; do
   if [ -d "${jobR}/CV_JobResults/2/0/${JID}" ]; then
    printf "%s\n" "Collecting jobResults ..." | tee -a "${scriptLog}"
    tar -rhf "${tarball}" ${jobR}/CV_JobResults/2/0/${JID} >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar ${jobR}/CV_JobResults/2/0/${JID} -- continuing ..."
   fi
  done
 fi

# Capture Tomcat server.xml.
 if [ ! -z "${tomcatPath}" ]; then
  if [ -f "${tomcatPath}/conf/server.xml" ]; then
   printf "\n%s\n" "Collecting Tomcat server.xml ... " | tee -a "${scriptLog}"
   tar -rhf "${tarball}" "${tomcatPath}/conf/server.xml" >> "${scriptLog}" 2>&1 || printf "    --- %s ...\n" "Failed to tar ${tomcatPath}/conf/server.; continuing" | tee -a "${scriptLog}"
  fi
 fi

# Capture Commvault Log_Files.
 printf "\n%s\n" "Collecting ${logs} ..." | tee -a "${scriptLog}"
 tar -rf "${tarball}" ${logs} >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar ${logs} -- continuing ..."
 
# Capture HyperScale logs, if applicable.
 if [ "${scaleoutPlatform}" == "HyperScale" ]; then
  printf "%s\n" "Collecting HyperScale logs ..." | tee -a "${scriptLog}"
  tar -rhf "${tarball}" /var/log/{cvfirewall,cvhedvig,cvmkfactory,cvnwconfigmgr,cvovirtsdk,cvremotenwconfig,cvresolvhname,cvsecurity}.log /var/log/cvupgradeos >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/cv* logs collected\n" || printf "--- %s\n" "Failed to tar /var/log/cv* logs -- continuing ..."
  tar -rhf "${tarball}" /var/log/ovirt-* >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/ovirt-* logs collected\n" || printf "--- %s\n" "Failed to tar /var/log/ovirt-* logs -- continuing ..."
  tar -rhf "${tarball}" /var/log/hyperscale.log >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/hyperscale.log collected\n" || printf "--- %s\n" "Failed to tar /var/log/hyperscale.log -- continuing ..."
  tar -rhf "${tarball}" /var/log/glusterfs >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/glusterfs collected\n" || printf "--- %s\n" "Failed to tar /var/log/glusterfs -- continuing ..."
  tar -rhf "${tarball}" /var/log/hsupgradedbg >> "${scriptLog}" 2>&1 && printf "... %s\n" "/var/log/hsupgradedbg collected\n" || printf "--- %s\n" "Failed to tar /var/log/hsupgradedbg -- continuing ..."
  
  if which gluster >> /dev/null 2>&1 ; then
   gluster peer status >> "${tmpDir}/cvcollect/gluster_peer_status.txt" 2>&1 && printf "... %s\n" "gluster peer status collected" | tee -a "${scriptLog}"
   gluster vol info >> "${tmpDir}/cvcollect/gluster_vol_info.txt" 2>&1 && printf "... %s\n" "gluster vol info collected" | tee -a "${scriptLog}"
   gluster vol status >> "${tmpDir}/cvcollect/gluster_vol_status.txt" 2>&1 && printf "... %s\n" "gluster vol status collected" | tee -a "${scriptLog}"
  fi
 fi

# Capture MSSQL info if requested or this is Linux CS.
 if [ ! -z "${isCS}" ] || (contains "${params}" "--mssql"); then
  printf "\n%s\n" "Collecting mssql logs ..." | tee -a "${scriptLog}"
  tar -rhf "${tarball}" /var/opt/mssql/log >> "${scriptLog}" 2>&1
  [ $? -eq 2 ] && printf "    --- %s\n" "Failed to tar SQL Server logs; continuing ..."
  if [ -f "/var/opt/mssql/mssql.conf" ]; then 
   printf "%s\n" "Collecting mssql.conf ..." 
   tar -rhf "${tarball}" /var/opt/mssql/mssql.conf >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar mssql.conf; continuing ..."
  fi
 fi

# Capture latest DR backup if requested.
 if (contains "${params}" "--csdr"); then
  printf "\n%s\n" "Collecting latest DR backup ..." | tee -a "${scriptLog}"
  tar -rhf "${tarball}" $(ls -1td "${drPath}"/* | head -1) >> "${scriptLog}" 2>&1 || printf "    --- %s\n" "Failed to tar latest DR backup; continuing ..."
 fi
done
 
# Capture install logs.
printf "%s\n" "Collecting Commvault installation logs ..." | tee -a "${scriptLog}"
tar -rhf "${tarball}" /var/log/.gxsetup >> "${scriptLog}" 2>&1 || printf "    %s\n\n" "--- Could not find any install logs; continuing ..."
 
# Capture collected information.
printf "%s\n" "Tarballing collect directory ..." | tee -a "${scriptLog}" 
tar -rhf "${tarball}" * >> "${scriptLog}" 2>&1 || bail "--- Failed to tar ${tmpDir}/cvcollect; aborting ..."

# Compress the tarball and clean up.
printf "\n%s\n" "Compressing tarball ..." 
gzip "${tarball}" || printf "--- %s\n" "Failed to gzip ${tarball}"
[ -f "${tarball}.gz" ] && printf "\n%s\n" "*** Upload ${tarball}.gz to Commvault Support. ***"
[ -f "${tarball}" ] && printf "\n%s\n" "*** Upload ${tarball} to Commvault Support. ***"
cleanup
 
# eof
