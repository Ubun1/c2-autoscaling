### Installation
```sh
# Tested on Fedora 28
git clone https://github.com/Ubun1/c2-autoscaling.git
cd c2-autoscaling
mkdir .venv
virtualenv .venv
source .venv/bin/activate
pip install -r requirements.txt
# install terraform
# create ./terraform/terraform.tfvars file with appropriate values
# install aws-cli and configure aws cli profile in .aws/config
```

### Usage
```sh
make prepare
# check instances up and running:
AWS_ACCESS_KEY_ID="<access_key>" AWS_SECRET_ACCESS_KEY="<secret_key>" make ping
# deploy and configure awx
AWS_ACCESS_KEY_ID="<access_key>" AWS_SECRET_ACCESS_KEY="<secret_key>" make deploy 
# in case of errors try again:)
```

### Monitoring
```sh
./monitor.sh
```
