apt update
apt install -y openssl
openssl rand -hex 32 | tr -d "\n" > "/config/jwt.hex"