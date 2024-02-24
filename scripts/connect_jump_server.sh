#!/usr/bin/env bash
set -e

AWS_REGION="cn-north-1"
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""

# Defaults
REMOTE_SSH_PORT=22
TUNNEL_PORT=8022 # Needs to be adjusted if multiple connections are to be made

JUMPSERVER_ID="" # i-xxxxxxxxxxxxx, Always needs to be adjusted
TARGET_ENDPOINT="" # <rds-mssql-endpoint>:1433

LOCAL_FORWARDING_PORT="54321"

VERBOSE="false"

aws --version
session-manager-plugin

# Read param from cmd
while [ $# -ne 0 ]; do
    name="$1"
    case "$name" in
    --aws-region)
        shift
        AWS_REGION="$1"
        ;;
    --aws-access-key-id)
        shift
        AWS_ACCESS_KEY_ID="$1"
        ;;
    --aws-secret-access-key)
        shift
        AWS_SECRET_ACCESS_KEY="$1"
        ;;
    --jumpserver-id)
        shift
        JUMPSERVER_ID="$1"
        ;;
    --target-endpoint)
        shift
        TARGET_ENDPOINT="$1"
        ;;
    --local-forwarding-port)
        shift
        LOCAL_FORWARDING_PORT="$1"
        ;;
    --verbose)
        VERBOSE="true"
        ;;
    *)
        echo "Unknown argument \`$name\`"
        exit 1
        ;;
    esac
    shift
done

# check by interaction
echo "【AWS_REGION】: $AWS_REGION"

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  read -p "Please input 【AWS_ACCESS_KEY_ID】:" AWS_ACCESS_KEY_ID
else
  echo "【AWS_ACCESS_KEY_ID】: $AWS_ACCESS_KEY_ID"
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  read -s -p "Please input 【AWS_SECRET_ACCESS_KEY】:" AWS_SECRET_ACCESS_KEY
else
  echo "【AWS_SECRET_ACCESS_KEY】: ******"
fi

if [ -z "$JUMPSERVER_ID" ]; then
  read -p "Please input 【jump server id】:" JUMPSERVER_ID
else
  echo "【Jump server id】: $JUMPSERVER_ID"
fi

if [ -z "$TARGET_ENDPOINT" ]; then
  read -p "Please input 【target endpoint】:" TARGET_ENDPOINT
else
  echo "【Target endpoint】: $TARGET_ENDPOINT"
fi

if [ -z "$LOCAL_FORWARDING_PORT" ]; then
  read -p "Please input 【LOCAL_FORWARDING_PORT】:" LOCAL_FORWARDING_PORT
else
  echo "【LOCAL_FORWARDING_PORT】: $LOCAL_FORWARDING_PORT"
fi

aws configure set region $AWS_REGION
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key  $AWS_SECRET_ACCESS_KEY
aws configure list >/dev/null

active_sessions=$(aws ssm describe-sessions --state "Active")
echo "$active_sessions"
session_ids=$(echo "${active_sessions}" | grep -B1 -F "\"Target\": \"${JUMPSERVER_ID}\"" | grep -o -E '"SessionId":\s*"[^"]*"' | awk -F'"' '{print $4}')
echo "$session_ids"
for session_id in ${session_ids}
do
    if [ -n "${session_id}" ]; then
        echo "An active session ${session_id} already exists for the target ${JUMPSERVER_ID}. Terminating..."
        aws ssm terminate-session --session-id ${session_id}
    fi
done

tmpfile=$(mktemp ./jumpserver-connect.XXXXXX)
echo "session id: $tmpfile"

aws ssm start-session --target $JUMPSERVER_ID --document-name AWS-StartPortForwardingSession --parameters "{\"portNumber\":[\"${REMOTE_SSH_PORT}\"],\"localPortNumber\":[\"${TUNNEL_PORT}\"]}" 2>&1 >>${tmpfile} | tee --append ${tmpfile} &

while ! grep -Fq 'opened for sessionId' ${tmpfile}; do
    if result=$(grep -E 'Cannot perform start session|An error occurred' ${tmpfile});
    then
      echo $result
      exit 1
    else
      echo "Waiting for tunnel connect"
      sleep 1
    fi
done

echo "Tunnel connection established!"

echo ""
echo "Opening ssh port forwarding session..."
SSH_CMD="ssh -fN -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new -p ${TUNNEL_PORT} -L 0.0.0.0:${LOCAL_FORWARDING_PORT}:${TARGET_ENDPOINT} tunnel@127.0.0.1"

if [ "$VERBOSE" = true ]; then
    $SSH_CMD -v
else
    $SSH_CMD
fi

sleep 3
echo ""
echo ""
echo "---------------------------------------------"
echo "Ssh session established!!!"
echo "You can you use 127.0.0.1:${LOCAL_FORWARDING_PORT}"
echo "to connect with"
echo "${TARGET_ENDPOINT}"
echo "---------------------------------------------"
echo ""
echo ""

trap "rm -f ${tmpfile}" SIGINT SIGTERM EXIT
