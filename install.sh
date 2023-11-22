#!/bin/bash

# Mise à jour du système
sudo apt update
sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y apache2 mariadb-server libapache2-mod-php php php-gd php-json php-mysql php-curl php-mbstring php-intl php-imagick php-xml php-zip

# Téléchargement de Nextcloud
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xvf latest.tar.bz2
sudo mv nextcloud /var/www/html/

# Configuration d'Apache
sudo chown -R www-data:www-data /var/www/html/nextcloud
sudo chmod -R 755 /var/www/html/nextcloud

# Configuration de la base de données
sudo mysql_secure_installation

# Saisie des informations de la base de données
read -p "Entrez le nom de la base de données MySQL pour Nextcloud: " dbname
read -p "Entrez le nom d'utilisateur MySQL pour Nextcloud: " dbuser
read -s -p "Entrez le mot de passe MySQL pour Nextcloud: " dbpassword
sudo mysql -u root -p -e "CREATE DATABASE $dbname;"
sudo mysql -u root -p -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpassword';"
sudo mysql -u root -p -e "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';"
sudo mysql -u root -p -e "FLUSH PRIVILEGES;"

# Demander si l'utilisateur veut utiliser un nom de domaine ou l'adresse IP
read -p "Voulez-vous utiliser un nom de domaine pour Nextcloud? (y/n): " use_domain

if [ "$use_domain" == "y" ]; then
    read -p "Entrez le nom de domaine pour Nextcloud: " nextcloud_domain
else
    nextcloud_domain=$(hostname -I | awk '{print $1}')
fi

# Configurer Apache pour Nextcloud
sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/nextcloud
    ServerName $nextcloud_domain

    <Directory /var/www/html/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        Satisfy Any
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Activer le nouveau site et redémarrer Apache
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite
sudo systemctl restart apache2

# Attendre que le serveur web redémarre complètement (surtout pour les installations plus lentes)
sleep 10

# Vérifier et corriger les erreurs Nextcloud
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:repair --no-interaction

# Ajouter un utilisateur administrateur Nextcloud
read -p "Entrez le nom d'utilisateur pour l'administrateur Nextcloud: " admin_user
read -s -p "Entrez le mot de passe pour l'administrateur Nextcloud: " admin_password
sudo -u www-data php /var/www/html/nextcloud/occ user:add --display-name="Admin" --group="admin" $admin_user --password=$admin_password

# Informations de configuration
echo "----------------------------------------"
echo "Installation de Nextcloud terminée"
echo "Accédez à Nextcloud dans votre navigateur: http://$nextcloud_domain"
echo "Base de données: $dbname"
echo "Utilisateur de la base de données: $dbuser"
echo "Mot de passe de la base de données: $dbpassword"
echo "Utilisateur administrateur Nextcloud: $admin_user"
echo "Mot de passe administrateur Nextcloud: $admin_password"
echo "----------------------------------------"
