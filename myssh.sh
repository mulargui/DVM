#!/bin/bash -x

KEYNAME=dvm-key
INSTANCEDNS=ec2-3-236-106-191.compute-1.amazonaws.com

# what to do
if [ "help" == "$1" ]; then 
	echo "Usage:  $0 [help|connect|upload <file>|download <file>|rupload <dir>|rdownload <dir>]"
	exit
fi

if [ "upload" == "$1" ]; then 
	#upload the file
	scp -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		$2 \
		ec2-user@$INSTANCEDNS:~

	exit
fi

if [ "rupload" == "$1" ]; then 
	#upload the dir
	scp -q -r -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		$2 \
		ec2-user@$INSTANCEDNS:~

	exit
fi

if [ "download" == "$1" ]; then 
	#download the file
	scp -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS:~/$2 \
		.

	exit
fi

if [ "rdownload" == "$1" ]; then 
	#download the dir
	scp -q -r -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS:~/$2 \
		.

	exit
fi

if [ "connect" == "$1" ]; then 
	#connect to the dvm instance
	ssh -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS

	exit
fi

#wrong param
echo "Usage:  $0 [help|connect|upload <file>|download <file>|rupload <dir>|rdownload <dir>]"
