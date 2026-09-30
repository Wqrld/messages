#!/bin/sh

# RSPAMD_redis_url (redis://[user:password@]host:port[/db]) is the backend's own spelling,
# so one Secret can feed both; it is split into the parts rspamd's redis block takes.
if [ -n "${RSPAMD_redis_url:-}" ]; then
    rest="${RSPAMD_redis_url#*://}"
    case "$rest" in
        *@*) creds="${rest%%@*}"; rest="${rest#*@}"
             export RSPAMD_redis_username="${creds%%:*}"
             export RSPAMD_redis_password="${creds#*:}" ;;
    esac
    case "$rest" in
        */*) export RSPAMD_redis_db="${rest#*/}"; rest="${rest%%/*}" ;;
    esac
    export RSPAMD_redis_servers="$rest"
fi
export RSPAMD_redis_servers="${RSPAMD_redis_servers:-redis:6379}"
export RSPAMD_log_level="${RSPAMD_log_level:-info}"

erb /etc/nginx/servers.conf.erb > /tmp/servers.conf

# Start rspamd in background
echo "Starting rspamd..."
# Root only in an image run with a user override; rspamd then drops to its own.
if [ "$(id -u)" = 0 ]; then
    rspamd -f -u _rspamd -g _rspamd &
else
    rspamd -f &
fi
RSPAMD_PID=$!

# Wait for rspamd to be ready (check if both ports 11333 and 11334 are listening)
max_attempts=60
attempt=0
rspamd_ready=0

while [ $attempt -lt $max_attempts ]; do
    # Check if rspamd process is still running
    if ! kill -0 $RSPAMD_PID 2>/dev/null; then
        echo "ERROR: Rspamd process died!"
        wait $RSPAMD_PID || true
        exit 1
    fi
    
    # Check if both ports are listening
    if nc -z localhost 11333 2>/dev/null && nc -z localhost 11334 2>/dev/null; then
        echo "Rspamd is ready (ports 11333 and 11334 are listening)"
        rspamd_ready=1
        break
    fi
    attempt=$((attempt + 1))
    sleep 0.5
done

if [ $rspamd_ready -eq 0 ]; then
    echo "ERROR: Rspamd did not become ready after $max_attempts attempts"
    echo "Checking rspamd process status..."
    ps aux | grep rspamd || true
    echo "Checking ports..."
    netstat -tlnp 2>/dev/null | grep -E '11333|11334' || true
    kill $RSPAMD_PID 2>/dev/null || true
    exit 1
fi

# Start nginx in foreground
echo "Starting nginx..."
exec nginx