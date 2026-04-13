#!/bin/sh

# Configuration
CONSUL_ADDR="http://192.168.1.87:8500"

# Auto-detect IP (BusyBox safe)
DEFAULT_IP=$(ip route get 1 | awk '{print $7; exit}')

# 1. Service Name
printf "Enter Service Name [%s]: " "$(hostname)"
read INPUT_NAME
NAME=${INPUT_NAME:-$(hostname)}

# 2. Service IP
printf "Enter Service IP [%s]: " "$DEFAULT_IP"
read INPUT_IP
IP=${INPUT_IP:-$DEFAULT_IP}

if [ -z "$IP" ]; then
    echo "Error: IP address is required."
    exit 1
fi

# 3. Service Port
printf "Enter Service Port: "
read PORT
if [ -z "$PORT" ]; then
    echo "Error: Port is required."
    exit 1
fi

# 4. Host Rule
printf "Enter Host Rule [%s.yourdomain.com]: " "$NAME"
read INPUT_HOST
HOST_RULE=${INPUT_HOST:-${NAME}.yourdomain.com}

# 5. Build JSON Payload
# We build it in variables to avoid 'invalid character' errors in sh
TAG_1="traefik.enable=true"
TAG_2="traefik.http.routers.${NAME}.rule=Host(\`${HOST_RULE}\`)"
TAG_3="traefik.http.routers.${NAME}.entrypoints=websecure"
TAG_4="traefik.http.routers.${NAME}.tls=true"
TAG_5="traefik.http.routers.${NAME}.tls.certresolver=cloudflare"
TAG_6="traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"

JSON="{\"Name\":\"${NAME}\",\"Address\":\"${IP}\",\"Port\":${PORT},\"Tags\":[\"${TAG_1}\",\"${TAG_2}\",\"${TAG_3}\",\"${TAG_4}\",\"${TAG_5}\",\"${TAG_6}\"]}"

# 6. Send Request
echo "--------------------------------------------------"
echo "Registering Service:"
echo "  Name:    ${NAME}"
echo "  Address: ${IP}:${PORT}"
echo "  Host:    ${HOST_RULE}"
echo "--------------------------------------------------"

curl -s -X PUT -d "$JSON" "${CONSUL_ADDR}/v1/agent/service/register"

if [ $? -eq 0 ]; then
    echo "Success! Service registered to Consul."
else
    echo "Error: Failed to contact Consul."
fi
