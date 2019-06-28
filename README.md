### Prerequesits

* Terrafor 0.10.x - 0.11.x 
* Terraform aws provider > 2.x
* aws cli > 1.1x

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
make deploy
make tags
make alarms
# check instances up and running:
AWS_PROFILE=<profile> make ping # whait untill all ping passed
# deploy and configure awx
AWS_PROFILE=<profile> make deploy 
# in case of errors run again:)
```

### Monitoring
```sh
./monitor.sh
```
