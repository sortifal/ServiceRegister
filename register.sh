#!/bin/bash

# PAUSE: Essential for 'curl | bash' to allow terminal input attachment
sleep 1

# Configuration
CONSUL_ADDR="http://192.168.1.34:8500"

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

# 4. Protocol / Routing Selection
echo "--------------------------------------------------"
echo "Select Protocol Type for Traefik:"
echo "1) HTTP      (Port 80, uses Host rule)"
echo "2) HTTPS     (Port 443, uses Host rule + Let's Encrypt)"
echo "3) UDP       (For TeamSpeak Voice, uses port entrypoint only)"
echo "4) TCP       (For TeamSpeak Files/Raw TCP, uses HostSNI wildcard)"
echo "--------------------------------------------------"
read -p "Choose an option [1-4]: " PROTO_CHOICE

# Initialize tags array block
TAGS=""

case $PROTO_CHOICE in
    2) # HTTPS / Websecure
        read -p "Enter Host Rule [${NAME}.vidoks.fr]: " INPUT_HOST
        HOST_RULE=${INPUT_HOST:-${NAME}.vidoks.fr}
        
        TAGS=$(cat <<EOF
    "traefik.enable=true",
    "traefik.http.routers.${NAME}.rule=Host(\`${HOST_RULE}\`)",
    "traefik.http.routers.${NAME}.entrypoints=websecure",
    "traefik.http.routers.${NAME}.tls=true",
    "traefik.http.routers.${NAME}.tls.certresolver=le",
    "traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"
EOF
)
        ;;
        
    3) # UDP (TeamSpeak Voice)
        read -p "Enter Traefik UDP Entrypoint [teamspeak-voice]: " INPUT_EP
        ENTRYPOINT=${INPUT_EP:-teamspeak-voice}
        
        TAGS=$(cat <<EOF
    "traefik.enable=true",
    "traefik.udp.routers.${NAME}.entrypoints=${ENTRYPOINT}",
    "traefik.udp.routers.${NAME}.service=${NAME}_svc",
    "traefik.udp.services.${NAME}_svc.loadbalancer.server.port=${PORT}"
EOF
)
        ;;

    4) # TCP (TeamSpeak Files / Raw TCP)
        read -p "Enter Traefik TCP Entrypoint [teamspeak-files]: " INPUT_EP
        ENTRYPOINT=${INPUT_EP:-teamspeak-files}
        
        TAGS=$(cat <<EOF
    "traefik.enable=true",
    "traefik.tcp.routers.${NAME}.entrypoints=${ENTRYPOINT}",
    "traefik.tcp.routers.${NAME}.rule=HostSNI(\`*\`)",
    "traefik.tcp.routers.${NAME}.service=${NAME}_svc",
    "traefik.tcp.services.${NAME}_svc.loadbalancer.server.port=${PORT}"
EOF
)
        ;;

    1|*) # Default to HTTP / Web
        read -p "Enter Host Rule [${NAME}.vidoks.fr]: " INPUT_HOST
        HOST_RULE=${INPUT_HOST:-${NAME}.vidoks.fr}
        
        TAGS=$(cat <<EOF
    "traefik.enable=true",
    "traefik.http.routers.${NAME}.rule=Host(\`${HOST_RULE}\`)",
    "traefik.http.routers.${NAME}.entrypoints=web",
    "traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"
EOF
)
        ;;
esac

# 5. Register
echo "--------------------------------------------------"
echo "Registering: ${NAME} at ${IP}:${PORT}"
echo "--------------------------------------------------"

# Construct JSON payload dynamically blending the tags block
PAYLOAD=$(cat <<EOF
{
  "Name": "${NAME}",
  "Address": "${IP}",
  "Port": ${PORT},
  "Tags": [
${TAGS}
  ]
}
EOF
)

# Send to Consul Agent API
curl -s -X PUT -d "$PAYLOAD" "${CONSUL_ADDR}/v1/agent/service/register"

if [ $? -eq 0 ]; then
    echo "Success! Service registered."
else
    echo "Failed to contact Consul."
fi
