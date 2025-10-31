#!/bin/bash
set -e

# ====== Update system ======
sudo apt update -y && sudo apt upgrade -y

# ====== Install dependencies ======
sudo apt install -y wget unzip openjdk-17-jdk postgresql postgresql-contrib nginx

# ====== Configure PostgreSQL ======
sudo systemctl enable postgresql
sudo systemctl start postgresql

sudo -u postgres psql <<EOF
CREATE DATABASE sonarqube;
CREATE USER sonar WITH ENCRYPTED PASSWORD 'Password123!';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q
EOF

# ====== Create SonarQube user ======
sudo adduser --system --no-create-home --group --disabled-login sonarqube

# ====== Download and install SonarQube ======
cd /opt
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.5.1.90531.zip
sudo unzip sonarqube-10.5.1.90531.zip
sudo mv sonarqube-10.5.1.90531 sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube

# ====== Configure SonarQube ======
sudo sed -i 's|#sonar.jdbc.username=.*|sonar.jdbc.username=sonar|' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.password=.*|sonar.jdbc.password=StrongPassword123!|' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.jdbc.url=jdbc:postgresql.*|sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube|' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.web.host=.*|sonar.web.host=0.0.0.0|' /opt/sonarqube/conf/sonar.properties
sudo sed -i 's|#sonar.web.port=.*|sonar.web.port=9000|' /opt/sonarqube/conf/sonar.properties

# ====== Increase file limits ======
sudo bash -c "echo 'sonarqube - nofile 65536' >> /etc/security/limits.conf"
sudo bash -c "echo 'sonarqube - nproc 4096' >> /etc/security/limits.conf"

# ====== Create systemd service ======
sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<'EOL'
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOL

# ====== Start SonarQube service ======
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

# ====== Configure NGINX reverse proxy (optional) ======
sudo tee /etc/nginx/sites-available/sonarqube > /dev/null <<'EOL'
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# ====== Print status ======
echo "-------------------------------------------------------"
echo "SonarQube installation complete."
echo "Access SonarQube at: http://$(hostname -I | awk '{print $1}'):9000"
echo "Default credentials -> admin / admin"
echo "-------------------------------------------------------"
