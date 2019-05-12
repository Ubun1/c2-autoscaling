#!/usr/bin/python
# Copyright: Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type


try:
    import boto.ec2.cloudwatch
    import json
    from boto.ec2.cloudwatch import MetricAlarm
    from boto.exception import BotoServerError, NoAuthHandlerFound
except ImportError:
    pass  # Taken care of by ec2.HAS_BOTO

from ansible.module_utils.basic import *
from ansible.module_utils.ec2 import (AnsibleAWSError, HAS_BOTO, connect_to_aws, ec2_argument_spec,
                                      get_aws_connection_info)


def describe_metric_alarm(connection, prefix, state):

    result = connection.describe_alarms(alarm_name_prefix=prefix,state_value=state)

    return result

def main():
    fields = {
       	"region": {"required": True, "type": "str"},
       	"alarm_state": {"required": True, "type": "str"},
       	"alarm_name_prefix": {"required": True, "type": "str" },
    }
    
    module = AnsibleModule(argument_spec=fields)

    if not HAS_BOTO:
        module.fail_json(msg='boto required for this module')

    if module.params['region']:
        try:
            connection = connect_to_aws(boto.ec2.cloudwatch, module.params['region'])
        except (NoAuthHandlerFound, AnsibleAWSError) as e:
            module.fail_json(msg=str(e))
    else:
        module.fail_json(msg="region must be specified")

    result = describe_metric_alarm(connection, module.params['alarm_name_prefix'], module.params['alarm_state'])
    if not result:
        module.exit_json(changed=False, meta=[])

    alarms = [alarm.name for alarm in result]

    module.exit_json(changed=False, meta=alarms)

if __name__ == '__main__':
    main()

