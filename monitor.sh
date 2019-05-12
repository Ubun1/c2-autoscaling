#!/bin/bash

function CPUUtilizationMonitoring() {
    local AWS_CLI_PROFILE="prod"
    local CLOUDWATCH_URL="https://monitoring.cloud.croc.ru"
    local API_URL="https://api.cloud.croc.ru"
    local STATS=""
    local ALARM_STATUS=""
    local IDS=$(aws --profile $AWS_CLI_PROFILE --endpoint-url $API_URL ec2 describe-instances --filter Name=tag:role,Values=backend | grep -i instanceid | grep -oE 'i-[a-zA-Z0-9]*' | tr '\n' ' ') 
    for instance_id in $IDS; do
        STATS="$STATS$(aws --profile $AWS_CLI_PROFILE --endpoint-url $CLOUDWATCH_URL cloudwatch get-metric-statistics --dimensions Name=InstanceId,Value=$instance_id --namespace "AWS/EC2" --metric CPUUtilization --end-time  $(date --iso-8601=minutes) --start-time $(date -d "$(date --iso-8601=minutes) - 1 min" --iso-8601=minutes) --period 60 --statistics Average | grep -i average)";
        ALARMS_STATUS="$ALARMS_STATUS$(aws --profile $AWS_CLI_PROFILE --endpoint-url $CLOUDWATCH_URL cloudwatch describe-alarms --alarm-names scaling-high-$instance_id | grep -i statevalue)"
    done
    echo $STATS | column  -s ',' -o '|' -N $(echo $IDS | tr ' ' ',') -t
    echo $ALARMS_STATUS | column  -s ',' -o '|' -N $(echo $IDS | tr ' ' ',') -t
}
export -f CPUUtilizationMonitoring
watch -n 60 bash -c CPUUtilizationMonitoring
