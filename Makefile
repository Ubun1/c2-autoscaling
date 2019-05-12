EC2_URL ?= "https://api.cloud.croc.ru"
CLOUDWATCH_URL ?= "https://monitoring.cloud.croc.ru"
PROFILE ?= prod

VENV ?= . .venv/bin/activate && .venv/bin/
PYTHON ?= $(VENV)python
ANSIBLE ?= $(VENV)ansible
APLAYBOOK ?= $(VENV)ansible-playbook
AGALAXY ?= $(VENV)ansible-galaxy
PIP ?= .venv/bin/pip

env:
	$(PIP) install -r requirements.txt

deploy: ; $(APLAYBOOK) -i inventory configure.yaml

alarms-low:
	for instance_id in $$(cd terraform && terraform output backend_id | tr ',' ' '); do \
	        aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL)\
	            cloudwatch put-metric-alarm\
	                --alarm-name "scaling-low_$$instance_id"\
	                --dimensions Name=InstanceId,Value="$$instance_id"\
	                --namespace "AWS/EC2" --metric-name CPUUtilization --statistic Average\
	                --period 60 --evaluation-periods 3 --threshold 15 --comparison-operator LessThanOrEqualToThreshold; done

alarms-high:
	for instance_id in $$(cd terraform && terraform output backend_id | tr ',' ' '); do \
	        aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL)\
	            cloudwatch put-metric-alarm\
	            --alarm-name "scaling-high_$$instance_id"\
	            --dimensions Name=InstanceId,Value="$$instance_id"\
	            --namespace "AWS/EC2" --metric-name CPUUtilization --statistic Average\
	            --period 60 --evaluation-periods 3 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold; done

alarms: alarms-low alarms-high

tags-awx:
	cd terraform && aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 create-tags --resources "$$(terraform output awx_id)" \
		--tags Key=env,Value=auto-scaling Key=role,Value=awx

tags-backend:
	cd terraform && for i in $$(terraform output backend_id | tr ',' ' '); do \
		aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 create-tags --resources "$$i" \
		--tags Key=env,Value=auto-scaling Key=role,Value=backend ; done; 

tags-haproxy:
	cd terraform && for i in $$(terraform output haproxy_id | tr ',' ' '); do\
		aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 create-tags --resources "$$i" \
		--tags Key=env,Value=auto-scaling Key=role,Value=haproxy; done;

tags: tags-awx tags-backend tags-haproxy

infra:
	cd terraform && yes yes | \
		terraform apply \
		-var client_ip="$$(curl -s ipinfo.io/ip)/32" \
		-var material="$$(cat ~/.ssh/id_rsa.pub)"

prepare: infra tags alarms

ping: ping-backend ping-awx ping-haproxy

ping-backend:
	$(ANSIBLE) -i inventory backend -m ping

ping-haproxy:
	$(ANSIBLE) -i inventory haproxy -m ping

ping-awx:
	$(ANSIBLE) -i inventory awx -m ping

create-instance:
	$(APLAYBOOK) -i inventory create-instance.yaml

clean-all: remove-tags remove-alarms destroy-infra

destroy-infra:
	cd terraform && yes yes | \
		terraform destroy \
		-var client_ip="$$(curl -s ipinfo.io/ip)/32" \
		-var material="$$(cat ~/.ssh/id_rsa.pub)"

remove-tags:
	aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 describe-tags | \
		grep -i resourceid | \
		sort -nr | uniq | \
		awk -F: '{ print $$2 }' | \
		tr -d '"' | tr -d ',' | \
		xargs -I % aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 delete-tags --resources "%"

remove-alarms:
	aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL) \
		cloudwatch describe-alarms | \
		grep -i alarmname | \
		sort -nr | uniq | \
		awk -F: '{print $$2}' | \
		tr -d '"' | tr -d ',' | \
		xargs -I % aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL) \
		cloudwatch delete-alarms --alarm-names %
