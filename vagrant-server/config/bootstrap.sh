#!/bin/bash
echo "Provisioning DNS + FTP + NGINX Server"

# 1. GLOBAL VARIABLES

DOMAIN_NAME="ieszaidinvergeles.org"
NS_HOSTNAME="ns.ieszaidinvergeles.org"
FTP_CNAME="ftp.ieszaidinvergeles.org"
WEB_HOSTNAME="nginx.ieszaidinvergeles.org"  

SERVER_IP="192.168.56.101"
NETWORK_CIDR="192.168.56.0/24"
REVERSE_ZONE="56.168.192.in-addr.arpa"
IP_LAST_OCTET="101"

# SSL Certificate Paths
SSL_KEY_FILE="/etc/ssl/private/vsftpd.key"
SSL_CERT_FILE="/etc/ssl/certs/vsftpd.pem"

echo "Setting up server $NS_HOSTNAME ($SERVER_IP)"

# 2. INSTALL REQUIRED PACKAGES

apt-get update
# Added nginx and git
apt-get install -y bind9 bind9utils bind9-doc vsftpd openssl nginx git ufw
# Use IPv4 for BIND9
echo 'OPTIONS="-u bind -4"' > /etc/default/named


# 3. CONFIGURE DNS SERVICE

echo " Configuring DNS "

# named.conf.options
cat > /etc/bind/named.conf.options <<EOF
acl "trusted" {
    localhost;
    localnets;
    $NETWORK_CIDR;
};

options {
    directory "/var/cache/bind";

    listen-on { $SERVER_IP; 127.0.0.1; };
    listen-on-v6 { none; };

    allow-query { any; };
    allow-recursion { "trusted"; };

    forwarders {
        8.8.8.8;
        1.1.1.1;
    };

    dnssec-validation auto;
    auth-nxdomain no;
};
EOF

# named.conf.local
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
};

zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/db.$REVERSE_ZONE";
};
EOF

# Direct zone file 
cat > /etc/bind/db.$DOMAIN_NAME <<EOF
\$TTL 604800
@   IN  SOA $NS_HOSTNAME. root.$DOMAIN_NAME. (
        2         ; Serial
        604800    ; Refresh
        86400     ; Retry
        2419200   ; Expire
        604800 )  ; Negative Cache TTL
;
@               IN NS $NS_HOSTNAME.
$NS_HOSTNAME.   IN A  $SERVER_IP
$FTP_CNAME.     IN CNAME $NS_HOSTNAME.
$WEB_HOSTNAME.  IN CNAME $NS_HOSTNAME.
EOF

# Reverse zone file
cat > /etc/bind/db.$REVERSE_ZONE <<EOF
\$TTL 604800
@   IN  SOA $NS_HOSTNAME. root.$DOMAIN_NAME. (
        1         ; Serial
        604800    ; Refresh
        86400     ; Retry
        2419200   ; Expire
        604800 )  ; Negative Cache TTL
;
@           IN NS $NS_HOSTNAME.
$IP_LAST_OCTET  IN PTR $NS_HOSTNAME.
EOF

# Check and restart DNS
echo " Verifying DNS configuration and restarting BIND9 "
named-checkconf
named-checkzone $DOMAIN_NAME /etc/bind/db.$DOMAIN_NAME
named-checkzone $REVERSE_ZONE /etc/bind/db.$REVERSE_ZONE
systemctl restart bind9

# 4. CONFIGURE FTP SERVICE

echo " Configuring FTP "

#  4.1 Create test users 
echo " 4.1 Creating FTP users: luis, maria, miguel "
useradd -m luis
useradd -m maria
useradd -m miguel

echo "luis:luis" | chpasswd
echo "maria:maria" | chpasswd
echo "miguel:miguel" | chpasswd

#  4.2 Create test files 
echo " 4.2 Creating test files "
touch /home/luis/file1.txt /home/luis/file2.txt
chown luis:luis /home/luis/file*.txt
touch /home/maria/file1.txt /home/maria/file2.txt
chown maria:maria /home/maria/file*.txt

#  4.3 Create SSL certificate 
echo " 4.3 Generating SSL Certificate "
mkdir -p /etc/ssl/private 
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $SSL_KEY_FILE \
    -out $SSL_CERT_FILE \
    -subj "/C=ES/ST=Andalucia/L=Granada/O=IESZaidinVergeles/CN=$NS_HOSTNAME"

#  4.4 Configure vsftpd.conf from template 
echo " 4.4 Copying and populating vsftpd.conf template "
cp /vagrant/config/vsftpd.conf.template /etc/vsftpd.conf

# Replace placeholders in the template
sed -i "s/%%DOMAIN_NAME%%/$DOMAIN_NAME/g" /etc/vsftpd.conf
sed -i "s|%%SSL_CERT_FILE%%|$SSL_CERT_FILE|g" /etc/vsftpd.conf
sed -i "s|%%SSL_KEY_FILE%%|$SSL_KEY_FILE|g" /etc/vsftpd.conf

#  4.5 Create anonymous banner 
echo "You are connected to the public FTP server of $DOMAIN_NAME" > /etc/vsftpd.banner

#  4.6 Configure chroot exception list 
echo "maria" > /etc/vsftpd.chroot_list

#  4.7 Create userlist of allowed FTP users 
echo " 4.7 Creating FTP userlist... "
echo "luis" > /etc/vsftpd.userlist
echo "maria" >> /etc/vsftpd.userlist
echo "miguel" >> /etc/vsftpd.userlist

#  4.8 Restart VSFTPD Service 
echo " 4.8 Restarting vsftpd "
systemctl restart vsftpd

# 5. CONFIGURE NGINX 
WEB_ROOT="/var/www/$WEB_HOSTNAME/html"
mkdir -p $WEB_ROOT
rm -rf /tmp/repo
git clone https://github.com/cloudacademy/static-website-example /tmp/repo
cp -r /tmp/repo/* $WEB_ROOT/
rm -rf /tmp/repo
chown -R www-data:www-data /var/www/$WEB_HOSTNAME
chmod -R 755 /var/www/$WEB_HOSTNAME

# 5.1. Execute the script to generate the certs located in /vagrant/config/certs.sh
echo "--- Calling external script for SSL generation ---"
chmod +x /vagrant/config/certs.sh
/vagrant/config/certs.sh "$WEB_HOSTNAME"

# 5.2. USER AND PASSWORD CONFIGURATION
echo "--- Generating users and passwords for Nginx ---"
echo -n "mario:" > /etc/nginx/.htpasswd
openssl passwd -apr1 'mario' >> /etc/nginx/.htpasswd
echo -n "alejandra:" >> /etc/nginx/.htpasswd
openssl passwd -apr1 'alejandra' >> /etc/nginx/.htpasswd
chown www-data:www-data /etc/nginx/.htpasswd
chmod 640 /etc/nginx/.htpasswd
chown www-data:www-data /etc/nginx/.htpasswd
chmod 640 /etc/nginx/.htpasswd

# 5.3 Configure Server 
cat > /etc/nginx/sites-available/$WEB_HOSTNAME <<EOF
server {
    listen 80;
    listen 443 ssl;

    root $WEB_ROOT;
    index index.html index.htm index.nginx-debian.html;
    server_name $WEB_HOSTNAME;

    # SSL Config 
    ssl_certificate /etc/ssl/certs/$WEB_HOSTNAME.crt;
    ssl_certificate_key /etc/ssl/private/$WEB_HOSTNAME.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        satisfy all;

        allow 192.168.56.1;     
        allow 127.0.0.1;        
        deny all;               

        auth_basic "Restricted Area SSL";
        auth_basic_user_file /etc/nginx/.htpasswd;

        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$WEB_HOSTNAME /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# 6. FIREWALL
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 8. FINAL CONFIGURATIONS AND TESTS

echo " Checking services "
systemctl status bind9 --no-pager
systemctl status vsftpd --no-pager
systemctl status nginx --no-pager
ufw status verbose

echo " Checking ports "
ss -tlpn | grep ":53"
ss -tlpn | grep ":21"
ss -tlpn | grep ":80"
ss -tlpn | grep ":443"

echo " Testing DNS "
dig @127.0.0.1 $NS_HOSTNAME +short
dig @127.0.0.1 $WEB_HOSTNAME +short
dig @127.0.0.1 $DOCKER_HOSTNAME +short

echo " Provisioning Completed Successfully "