#!/usb/bin/env bash

set -e

log() {
  echo ">> [local]" "$@"
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}

# export JWT_SECRET_KEY=$JWT_SECRET_KEY
# export SESSION_SECRET=$SESSION_SECRET
# export PGSQL_PASSWORD=$PGSQL_PASSWORD
# export MONGO_PASSWORD=$MONGO_PASSWORD
# export REDIS_PASSWORD=$REDIS_PASSWORD

trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval "$(ssh-agent -s)"

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/workspace\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/workspace\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/workspace\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/workspace\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" --project-name \"$DOCKER_COMPOSE_PREFIX\" up -d --build ; docker volume prune -f ; docker image prune -a -f ; docker builder prune --filter 'until=24h' -f"
if $USE_DOCKER_STACK ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/workspace\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/workspace/$DOCKER_COMPOSE_PREFIX\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/workspace/$DOCKER_COMPOSE_PREFIX\" -xjv ; log 'Launching docker stack deploy...' ; cd \"\$HOME/workspace/$DOCKER_COMPOSE_PREFIX\" ; docker stack deploy -c \"$DOCKER_COMPOSE_FILENAME\" --prune \"$DOCKER_COMPOSE_PREFIX\""
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
