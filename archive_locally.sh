$ cat archive_locally.sh
#!/bin/bash

# Source top folder
S_DIR="/media/private"
# Source subfolders under top one, which should be backed up
DIRS="Archive Docs Photos"
# Destination folder for encrypted archives
D_DIR="/media/usbshare/private_backup"
# Size of each encrypted archive files in MB
VOLSIZE=1024

DATE=`date '+%Y%m%d%H%M%S'`
# Ask for password phrase
read -sp "Enter passphrase for encryption of archives: " secret
export PASSPHRASE=${secret}
echo
echo "Archiving the following subdirs from ${S_DIR}: ${DIRS}"
for dir in ${DIRS} 
do
        echo duplicity --volsize ${VOLSIZE} ${S_DIR}/${dir} file://${D_DIR}/${dir}
        echo duplicity --volsize ${VOLSIZE} ${S_DIR}/${dir} file://${D_DIR}/${dir} >> ${D_DIR}/archive.${DATE}.log
        duplicity --volsize ${VOLSIZE} ${S_DIR}/${dir} file://${D_DIR}/${dir} >> ${D_DIR}/archive.${DATE}.log 2>&1
done
