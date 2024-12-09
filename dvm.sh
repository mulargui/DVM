#!/bin/bash -x

#aws cli env variables
. ./awsparams.sh

SGNAME=dvm-sg
KEYNAME=dvm-key

# what to do
if [ "help" == "$1" ]; then 
	echo "Usage:  $0 [help|create|destroy|start|stop|connect|upload <file>|download <file>|rupload <dir>|rdownload <dir>]"
	exit
fi

#
# helper functions
# 

#ID of the instance running 
INSTANCEID=$(aws ec2 describe-instances \
        --filters "Name=key-name,Values=$KEYNAME" \
        	"Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
	| sed 's/"//g')

#DNS of the instance
if [ "null" != "$INSTANCEID" ]; then 
	INSTANCEDNS=$(aws ec2 describe-instances \
		--instance-ids $INSTANCEID \
		--query 'Reservations[0].Instances[0].PublicDnsName' \
		| sed 's/"//g')
fi

#
# commands to a running instance
# 

if [ "upload" == "$1" ]; then 
	#upload the file
	scp -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		$2 \
		ec2-user@$INSTANCEDNS:~
	echo "Done!"
	exit
fi

if [ "rupload" == "$1" ]; then 
	#upload the dir
	scp -q -r -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		$2 \
		ec2-user@$INSTANCEDNS:~
	echo "Done!"
	exit
fi

if [ "download" == "$1" ]; then 
	#download the file
	scp -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS:~/$2 \
		.
	echo "Done!"
	exit
fi

if [ "rdownload" == "$1" ]; then 
	#download the dir
	scp -q -r -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS:~/$2 \
		.
	echo "Done!"
	exit
fi

if [ "stop" == "$1" ]; then 
	aws ec2 stop-instances --instance-ids $INSTANCEID
	echo "Done!"
	exit
fi

if [ "connect" == "$1" ]; then 
	#connect to the dvm instance
	ssh -q -o UserKnownHostsFile=/dev/null \
		-o StrictHostKeyChecking=no \
		-i $KEYNAME.pem \
		ec2-user@$INSTANCEDNS
	echo "Done!"
	exit
fi

#
# start an instance
#

if [ "start" == "$1" ]; then 

	INSTANCEID=$(aws ec2 describe-instances \
        	--filters "Name=key-name,Values=$KEYNAME" \
        		"Name=instance-state-name,Values=stopped" \
        	--query 'Reservations[0].Instances[0].InstanceId' \
		| sed 's/"//g')

	if [ "null" == "$INSTANCEID" ]; then 
		echo "No instance available. Exiting."
		exit
	fi

	# start the instance
	aws ec2 start-instances --instance-ids $INSTANCEID

	#wait till the instance is started
	sleep 5

	#get dns of the instance
	INSTANCEDNS=$(aws ec2 describe-instances \
		--instance-ids $INSTANCEID \
		--query 'Reservations[0].Instances[0].PublicDnsName' \
		| sed 's/"//g')
	echo "DNS: " $INSTANCEDNS

	echo "Done!"
	exit
fi

#
# destroy an instance
#

if [ "destroy" == "$1" ]; then 
	# terminate the instance
	aws ec2 terminate-instances --instance-ids $INSTANCEID

	#delete the key pair
	aws ec2 delete-key-pair \
		--key-name $KEYNAME
	chmod 700 $KEYNAME.pem
	rm $KEYNAME.pem

	#wait for the instance to stop
	sleep 5

	#delete the security group
	aws ec2 delete-security-group \
		--group-name $SGNAME

	echo "Done!"
	exit
fi

#wrong param, only create remaining
if [ "create" != "$1" ]; then 
	echo "Usage:  $0 [help|create|destroy|start|stop|connect|upload <file>|download <file>|rupload <dir>|rdownload <dir>]"
	exit
fi

#
#create a new instance
#

#get the default VPC
VPCID=$(aws ec2 describe-vpcs \
	--filters 'Name=is-default, Values=true' \
	--query 'Vpcs[0].VpcId' \
	| sed 's/"//g')
if [ "null" == "$VPCID" ]; then 
	echo "No default VPC. Exiting"
	exit
fi

#create a security group
SGID=$(aws ec2 create-security-group \
	--group-name $SGNAME \
	--description 'firewall rules for dvm' \
	--vpc-id $VPCID \
	--query 'GroupId' \
	| sed 's/"//g')

#create the firewall rules (only ssh, http, https from anywhere allowed)
aws ec2 authorize-security-group-ingress \
    --group-id $SGID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
	--query 'Return'

aws ec2 authorize-security-group-ingress \
    --group-id $SGID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
	--query 'Return'

aws ec2 authorize-security-group-ingress \
    --group-id $SGID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
	--query 'Return'

#create the key pair to access the dvm instance
#in case we had a previous key file
chmod 700 $KEYNAME.pem
rm $KEYNAME.pem

aws ec2 create-key-pair \
	--key-name $KEYNAME \
	--key-type rsa \
	--query 'KeyMaterial' \
	| sed 's/"//g' \
	| sed 's/\\n/\\\n/g' \
	| sed 's/\\//g' \
	> $KEYNAME.pem

#only me can read the key
chmod 400 $KEYNAME.pem

#select the image to use
#IMGID=$(aws ec2 describe-images \
#	--owners amazon \
#	--filters 'Name=name,Values=/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2' \
#		'Name=architecture,Values=x86_64' \
#		'Name=state,Values=available' \
#		'Name=root-device-type,Values=ebs' \
#		'Name=virtualization-type,Values=hvm' \
#		'Name=platform,Values=Amazon linux' \
#	--query 'sort_by(Images, &CreationDate)[-1]. ImageId')
#IMGID=$(aws ssm get-parameters \
#	--names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2 \
#	--query 'Parameters[0].Value' \
#	| sed 's/"//g')

IMGID=ami-0582e4fe9b72a5fe1
INSTANCETYPE=t4g.medium

#create an ec2 instance
INSTANCEID=$(aws ec2 run-instances \
	--image-id $IMGID \
	--security-group-ids $SGID \
	--instance-type $INSTANCETYPE \
	--count 1:1 \
	--key-name $KEYNAME \
	--query 'Instances[0].InstanceId' \
	| sed 's/"//g')

#get dns of the instance
INSTANCEDNS=$(aws ec2 describe-instances \
	--instance-ids $INSTANCEID \
	--query 'Reservations[0].Instances[0].PublicDnsName' \
	| sed 's/"//g')
echo "DNS: " $INSTANCEDNS

#install git in the dvm
ssh -q -o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	-i $KEYNAME.pem \
	ec2-user@$INSTANCEDNS <<EOF
	sudo yum update -y
	sudo yum install git -y
	git config --global user.name "mulargui"
	git config --global user.email contact@ulargui.com
EOF

#install docker in the dvm
ssh -q -o UserKnownHostsFile=/dev/null \
	-o StrictHostKeyChecking=no \
	-i $KEYNAME.pem \
	ec2-user@$INSTANCEDNS <<EOF
	sudo yum install -y docker
	sudo service docker start
	sudo systemctl enable docker
	sudo usermod -a -G docker ec2-user
EOF

echo "Done!"
