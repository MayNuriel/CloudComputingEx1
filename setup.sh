# debug
# set -o xtrace

KEY_NAME="cloud-course-`date +'%N'`"
KEY_PEM="$KEY_NAME.pem"

echo "create key pair $KEY_PEM to connect to instances and save locally"
KEY_PAIR=$(aws ec2 create-key-pair --key-name $KEY_NAME)
echo $KEY_PAIR | grep -o "\"KeyMaterial\": \".*\"" | cut -d "\"" -f 4 | sed 's/\\n/\n/g' > $KEY_PEM

# secure the key pair
chmod 400 $KEY_PEM

SEC_GRP="my-sg-`date +'%N'`"

echo "setup firewall $SEC_GRP"
aws ec2 create-security-group   \
    --group-name $SEC_GRP       \
    --description "Access my instances" 

# figure out my ip
MY_IP=$(curl ipinfo.io/ip)
echo "My IP: $MY_IP"


echo "setup rule allowing SSH access to $MY_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 22 --protocol tcp \
    --cidr $MY_IP/32

echo "setup rule allowing HTTP (port 5000) access to all IPs"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 5000 --protocol tcp \
    --cidr 0.0.0.0/0

UBUNTU_20_04_AMI="ami-042e8287309f5df03"

echo "Creating Ubuntu 20.04 instance..."
RUN_INSTANCES=$(aws ec2 run-instances   \
    --image-id $UBUNTU_20_04_AMI        \
    --instance-type t3.micro            \
    --key-name $KEY_NAME                \
    --security-groups $SEC_GRP)

INSTANCE_ID=$(echo $RUN_INSTANCES | grep -o "\"InstanceId\": \".*\"" | cut -d "\"" -f 4)

echo "Waiting for instance creation..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

PUBLIC_IP_OF_MY_INSTANCE=$(aws ec2 describe-instances  --instance-ids $INSTANCE_ID | 
    grep -o "\"PublicIpAddress\": \".*\"" | cut -d "\"" -f 4
)

echo "New instance $INSTANCE_ID @ $PUBLIC_IP_OF_MY_INSTANCE"

echo "deploying code to production"
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" app.py ubuntu@$PUBLIC_IP_OF_MY_INSTANCE:/home/ubuntu/

echo "setup production environment"
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$PUBLIC_IP_OF_MY_INSTANCE <<EOF
    sudo apt update
    sudo apt install python3-flask -y
    # run app
    nohup flask run --host 0.0.0.0  &>/dev/null &
    exit
EOF

echo -e "\n--------------------------------------------\n"
echo -e "Done successfuly !! \ntesting the endpoints by the following examples:\n"

echo -e 'The result of running the command:curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/entry?plate=123-123-123&parkingLot=382" is:'

curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/entry?plate=123-123-123&parkingLot=382"

echo -e '\n\nThe result of running the command:curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/exit?ticketId=1" is:'

curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/exit?ticketId=1"

echo -e '\n\nThe result of running the command:curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/entry?plate=444-555-969&parkingLot=22" is:'

curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/entry?plate=444-555-969&parkingLot=22"

echo -e '\n\nThe result of running the command:curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/exit?ticketId=2" is:'

curl -X POST "http://$PUBLIC_IP_OF_MY_INSTANCE:5000/exit?ticketId=2"