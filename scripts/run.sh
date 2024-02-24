SSH_CMD="./connect_jump_server.sh --aws-access-key-id $AWS_ACCESS_KEY_ID --aws-secret-access-key $AWS_SECRET_ACCESS_KEY --jumpserver-id $JUMPSERVER_ID --target-endpoint $TARGET_ENDPOINT"

if [ -n "$AWS_REGION" ]; then
  SSH_CMD="$SSH_CMD --aws-region $AWS_REGION"
fi

if [ -n "$LOCAL_FORWARDING_PORT" ]; then
  SSH_CMD="$SSH_CMD --local-forwarding-port $LOCAL_FORWARDING_PORT"
fi

if [ "$VERBOSE" = "true" ]; then
  SSH_CMD="$SSH_CMD --verbose"
fi

$SSH_CMD

tail -f /dev/null