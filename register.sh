#!/bin/sh

# Configuration
CONSUL_ADDR="http://192.168.1.87:8500"

# --- Auto-detect IP (BusyBox Compatible) ---
# Gets the IP of the interface used for the default gateway
DEFAULT_IP=$(ip route get 1 | awk '{print $7; exit}')

# --- Interactive Inputs ---

# 1. Service Name
read -p "Enter Service Name [$(hostname)]: " INPUT_NAME
NAME=${INPUT_NAME:-$(hostname)}

# 2. Service IP
read -p "Enter Service IP [${DEFAULT_IP}]: " INPUT_IP
IP=${INPUT_IP:-$DEFAULT_IP}

if [ -z "$IP" ]; then
    echo "Error: Could not determine IP address. Please enter it manually."
    exit 1
fi

# 3. Service Port
read -p "Enter Service Port: " PORT
if [ -z "$PORT" ]; then
    echo "Error: Port is required."
    exit 1
fi

# 4. Host Rule
read -p "Enter Host Rule (e.g. service.example.com) [${NAME}.yourdomain.com]: " INPUT_HOST
HOST_RULE=${INPUT_HOST:-${NAME}.yourdomain.com}

# --- Construct Payload ---
PAYLOAD=$(cat <<EOF
{
  "Name": "${NAME}",
  "Address": "${IP}",
  "Port": ${PORT},
  "Tags": [
    "traefik.enable=true",
    "traefik.http.routers.${NAME}.rule=Host(\`${HOST_RULE}\`)",
    "traefik.http.routers.${NAME}.entrypoints=websecure",
    "traefik.http.routers.${NAME}.tls=true",
    "traefik.http.routers.${NAME}.tls.certresolver=le",
    "traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"
  ],
  "Check": {
    "HTTP": "http://${IP}:${PORT}/",
    "Interval": "10s",
    "Timeout": "1s"
  }
}
EOF
)

# --- Register ---
echo "--------------------------------------------------"
echo "Registering Service:"
echo "  Name:    ${NAME}"
echo "