MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

EC2_URL ?= "https://api.cloud.croc.ru"
CLOUDWATCH_URL ?= "https://monitoring.cloud.croc.ru"
PROFILE ?= prod

VENV ?= . .venv/bin/activate && .venv/bin/
PYTHON ?= $(VENV)python
ANSIBLE ?= $(VENV)ansible
APLAYBOOK ?= $(VENV)ansible-playbook
AGALAXY ?= $(VENV)ansible-galaxy
PIP ?= .venv/bin/pip

assert-command-present = $(if $(shell which $1),, $(error '$1' missing and needed to run this target))

env:
	$(PIP) install -r requirements.txt

deploy: ; $(APLAYBOOK) -i inventory configure.yaml

IDS != cd terraform && terraform output backend_id 2> /dev/null | tr ',' ' ' | tr -d '\n'

# $1 - id
# $2 - name
# $3 - threshold
# $4 - operator
define ALARMS_SPECIFIC_CMD

.PHONY: alarms-$(2)-$(1)
alarms-$(2)-$(1): export _check = $(call assert-command-present, aws)
alarms-$(2)-$(1):
	aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL) \
		cloudwatch put-metric-alarm \
		--alarm-name scaling-$(2)_$(1) \
		--dimensions Name=InstanceId,Value=$(1) \
		--namespace "AWS/EC2" --metric-name CPUUtilization --statistic Average \
		--period 60 --evaluation-periods 3 --threshold $(3)  --comparison-operator $(4)
endef

$(foreach ID,$(IDS),$(eval $(call ALARMS_SPECIFIC_CMD,$(ID),low,15,GreaterThanThreshold)))
$(foreach ID,$(IDS),$(eval $(call ALARMS_SPECIFIC_CMD,$(ID),high,80,LessThanThreshold)))

alarms-low: $(foreach ID,$(IDS),alarms-low-$(ID))
alarms-high: $(foreach ID,$(IDS),alarms-high-$(ID))

alarms: alarms-low alarms-high

TAGS=awx backend haproxy

define TAGS_CMD

tags-$(1): export _check = $(call assert-command-present, aws)
tags-$(1): RESOURCE_IDS != cd terraform && terraform output $(1)_id 2>/dev/null | xargs -I % echo '"%"' | tr -d ',' | tr '\n' ' '
tags-$(1):
	aws --profile $(PROFILE) --endpoint-url $(EC2_URL) \
		ec2 create-tags --resources $$(value RESOURCE_IDS) \
		--tags Key=env,Value=auto-scaling Key=role,Value=$(1)
endef

$(foreach tag,$(TAGS),$(eval $(call TAGS_CMD,$(tag))))

tags: tags-awx tags-backend tags-haproxy

ping: ping-backend ping-awx ping-haproxy

# $(1) - ansible group
define PING_CMD

ping-$(1):
	$(ANSIBLE) -i inventory $(1) -m ping

endef

PINGS = backend haproxy awx

$(foreach ping,$(PINGS),$(eval $(call PING_CMD,$(ping))))

infra: export _check = $(call assert-command-present, terraform)
infra:
	cd terraform && yes yes | \
		terraform apply \
		-var client_ip="$$(curl -s ipinfo.io/ip)/32" \
		-var material="$$(cat ~/.ssh/id_rsa.pub)"

prepare: infra tags alarms

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
		jq '.MetricAlarms | .[] | select(.AlarmName|test("scaling.")) | .AlarmName' | \
		tr -d '"' | \
		xargs -I % aws --profile $(PROFILE) --endpoint-url $(CLOUDWATCH_URL) \
		cloudwatch delete-alarms --alarm-names %

create-binary-personal-dict:
	@aspell --lang=en create master $(MAKEFILE_DIR).aspell/dict_bin < $(MAKEFILE_DIR).aspell/dict

lint-cmt-msgs: create-binary-personal-dict
	@git log --oneline HEAD...master | \
		cut -d ' ' -f 2- | \
		aspell --add-extra-dicts=$(MAKEFILE_DIR).aspell/dict_bin --master en list | \
		sort -nr | \
		uniq
