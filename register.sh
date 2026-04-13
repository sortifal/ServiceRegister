#!/bin/bash

# Configuration
CONSUL_ADDR="http://192.168.1.87:8500"

# Auto-detect IP
DEFAULT_IP=$(ip route get 1 | awk '{print $7; exit}')

# 1. Service Name
read -p "Enter Service Name [$(hostname)]: " INPUT_NAME
NAME=${INPUT_NAME:-$(hostname)}

# 2. Service IP
read -p "Enter Service IP [${DEFAULT_IP}]: " INPUT_IP
IP=${INPUT_IP:-$DEFAULT_IP}

if [ -z "$IP" ]; then
    echo "Error: IP address is required."
    exit 1
fi

# 3. Service Port
read -p "Enter Service Port: " PORT
if [ -z "$PORT" ]; then
    echo "Error: Port is required."
    exit 1
fi

# 4. Host Rule
read -p "Enter Host Rule [${NAME}.yourdomain.com]: " INPUT_HOST
HOST_RULE=${INPUT_HOST:-${NAME}.yourdomain.com}

# 5. Register
echo "--------------------------------------------------"
echo "Registering: ${NAME} at ${IP}:${PORT}"
echo "Host: ${HOST_RULE}"
echo "--------------------------------------------------"

# We use a heredoc for JSON to be safe and clean
read -r -d '' PAYLOAD <<EOF
{
  "Name": "${NAME}",
  "Address": "${IP}",
  "Port": ${PORT},
  "Tags": [
    "traefik.enable=true",
    "traefik.http.routers.${NAME}.rule=Host(\`${HOST_RULE}\`)",
    "traefik.http.routers.${NAME}.entrypoints=websecure",
    "traefik.http.routers.${NAME}.tls=true",
    "traefik.http.routers.${NAME}.tls.certresolver=cloudflare",
    "traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"
  ]
}
EOF

curl -s -X PUT -d "$PAYLOAD" "${CONSUL_ADDR}/v1/agent/service/register"

if [ $? -eq 0 ]; then
    echo "Success! Service registered."
else
    echo "Failed to contact Consul."
fi
