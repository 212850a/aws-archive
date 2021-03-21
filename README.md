# aws-archive
## Overview
This instruction describes the way how to store your really important backups in encrypted format in AWS Glacier Deep Archive and pay for that really small (1$ per 1PB in a month). More details - [AWS Glacier Deep Archive as off-site backup solution](http://212850a.github.io/2020/12/20/AWS-Glacier.html)

## Preparations
### S3 bucket
Create S3 Bucket (no private access, disable object lock - default ones), let's call it `my-deep-archive`
### AWS User Policy
1. Create AWS user with access key (`archiver`)
2. Create at least the following two policies to have ability to see what buckets exist and what objects are inside `my-deep-archive` bucket. Limit usage of policies for specific ip-address (77.77.77.77 in example below):
 - ListBucket
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": [
                "arn:aws:s3:::my-deep-archive"
            ],
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": "77.77.77.77/32"
                }
            }
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:HeadBucket",
            "Resource": "*",
            "Condition": {
                "IpAddress": {
                    "aws:SourceIp": "77.77.77.77/32"
                }
            }
        }
    ]
}
```
- PutObject
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::my-deep-archive/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-storage-class": "DEEP_ARCHIVE"
                },
                "IpAddress": {
                    "aws:SourceIp": "77.77.77.77/32"
                }
            }
        }
    ]
}
```
3. Assign created policies for your `archiver` user via AWS IAM.

### AWS Command Line Interface
Install AWS CLI with PIP - it's recommended as GLACIER and DEEP_ARCHIVE as storage options are available since 2019 only and if you use old stable OS release (as example Ubuntu 18.04), the version of AWS CLI from package manager may not have this functionality still.
```
pip3 install --upgrade --user awscli
cd ~/.local/bin
ls aws*
aws  aws.cmd  aws_bash_completer  aws_completer  aws_zsh_completer.sh
aws --version
aws-cli/1.18.51 Python/3.6.9 Linux/4.15.0-54-generic botocore/1.16.1
```
By first step you have to configure AWS CLI - specify user Access Key, Secret Access Key, default region and output format. 
```
$ aws configure
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: eu-west-1
Default output format [None]: table
```
I use eu-west-1 (Ireland) as GLACIER and GLACIER DEEP ARCHIVE are the cheapest there and in Stockholm either as per [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/).

Additionally [CloudHarmony AWS Network Test S3](https://cloudharmony.com/speedtest-for-aws:s3) gives me the best results for latency and downlink for eu-west-1 from Lithuania, Vilnius where I'm based today.
### Duplicity
[Duplicity](http://duplicity.nongnu.org/) is the tool which will be used to create encrypted (with gpg) backup archives which then with a help of aws cli will be sent to AWS Glacier (or Glacier Deep Archive). 

Duplicity can itself send data to S3, but not to Glacier or Glacier Deep Archive yet.
```apt-get install duplicity -y```

## Usage
### archive_locally.sh
First stage is to create encrypted archives from your really important data - archive_locally.sh
```
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
```
### s3_sync_archive.sh
Second stage is to sync encrypted archives to AWS Glacier Deep Archive.
```
$ cat s3_sync_archive.sh
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
```
## Next Steps
### aws s3 sync with --delete
As per [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/) *"objects that are archived to S3 Glacier and S3 Glacier Deep Archive have a minimum 90 days and 180 days of storage, respectively. Objects deleted before 90 days and 180 days incur a pro-rated charge equal to the storage charge for the remaining days. Objects that are deleted, overwritten, or transitioned to a different storage class before the minimum storage duration will incur the normal storage usage charge plus a pro-rated request charge for the remainder of the minimum storage duration."*

So be careful while you use s3_sync_archive.sh as it will send to Glacier Deep Archive everything you have in specified source directories. After 180 days it's safe to use `aws s3 sync` command with option `--delete` in s3_sync_archive.sh to remove from Glacier Deep Archive what you don't have in source directories anymore.
