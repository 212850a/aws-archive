#!/bin/bash

S_DIR="/media/usbshare/private_backup"
DIRS="Archive Docs Photos"
S3_BUCKET="my-deep-archive"
S3_STORAGE_CLASS="DEEP_ARCHIVE"

DATE=`date '+%Y%m%d%H%M%S'`

echo
echo "Syncing to S3 ${S3_STORAGE_CLASS} the following subdirs from ${S_DIR}: ${S3_BUCKET}"
for dir in ${DIRS} 
do
        echo aws s3 sync ${S_DIR}/${dir} s3://${S3_BUCKET}/${dir} --storage-class ${S3_STORAGE_CLASS} 
        echo aws s3 sync ${S_DIR}/${dir} s3://${S3_BUCKET}/${dir} --storage-class ${S3_STORAGE_CLASS} >> ${S_DIR}/s3sync.${DATE}.log
        aws s3 sync ${S_DIR}/${dir} s3://${S3_BUCKET}/${dir} --storage-class ${S3_STORAGE_CLASS} 2>> ${S_DIR}/s3sync.${DATE}.log
done
