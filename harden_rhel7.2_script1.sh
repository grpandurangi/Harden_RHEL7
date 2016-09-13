#!/bin/bash

TMP_CHG="/tmp/TMP_CHG"
/bin/cat <<TM_CHG >$TMP_CHG
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change
-w /etc/localtime -p wa -k time-change
TM_CHG

IDC_FILE="/tmp/IDC_FILE"
/bin/cat <<EOF >$IDC_FILE
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
EOF


SYS_LOC="/tmp/SYS_LOC"
/bin/cat <<SYS_LOC >$SYS_LOC
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
SYS_LOC



grep -q "[[:space:]]/tmp[[:space:]]" /etc/fstab
RC=$?

if [[ "$RC" -gt "0" ]]; then
echo "No seperate file sytem for /tmp"

else

grep -q "[[:space:]]/tmp[[:space:]]" /etc/fstab | grep -e "noexec|nosuid|nodev"
RC=$?

if [[ "$RC" -gt "0" ]]; then
echo "noexec or nosuid or nodev not set on /tmp"
fi

fi

#Second Change permission of /boot/grub2/grub.cfg

stat -L -c "%a" /boot/grub2/grub.cfg | egrep ".00"
RC=$?

if [[ "$RC" -gt "0" ]]; then

chmod og-rwx /boot/grub2/grub.cfg
stat -L -c "%a" /boot/grub2/grub.cfg | egrep ".00"

fi

#Third , enable auditd. No need to check if its enabled.

systemctl enable auditd

#Fourth update GRUB_CMDLINE_LINUX in /etc/sysconfig/grub

grep GRUB_CMDLINE_LINUX /etc/sysconfig/grub |grep -q audit
RC=$?

if [[ "$RC" -gt "0" ]]; then
sed -i '/^GRUB_CMDLINE_LINUX/ s/"$/ audit=1"/' /etc/sysconfig/grub
else
echo "GRUB_CMDLINE_LINUX has \"audit=1\" Good!!"
fi

# Fifth Record Events That Modify Date and Time
grep -q "time-change" /etc/audit/audit.rules
RC=$?

if [[ "RC" -gt "0" ]] ; then

cat $TMP_CHG >> /etc/audit/audit.rules
pkill -HUP -P 1 auditd
rm -rf $TMP_CHG

else

grep "time-change" /etc/audit/audit.rules

fi

# Sixth Record Events That Modify User/Group Information

grep -q identity /etc/audit/audit.rules
RC=$?

if [[ "RC" -gt "0" ]] ; then

cat $IDC_FILE >> /etc/audit/audit.rules
pkill -HUP -P 1 auditd
rm -rf $IDC_FILE

else

grep identity /etc/audit/audit.rules

fi

# Seven Record Events That Modify the System's Network Environment

grep -q system-locale /etc/audit/audit.rules
RC=$?

if [[ "$RC" -gt "0" ]] ; then

cat $SYS_LOC >> /etc/audit/audit.rules
pkill -HUP -P 1 auditd
rm -rf $SYS_LOC

else 

grep system-locale /etc/audit/audit.rules

fi

