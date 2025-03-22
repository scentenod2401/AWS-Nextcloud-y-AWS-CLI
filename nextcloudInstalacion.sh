#!/bin/bash

# Descargar Nextcloud
echo "Descargando Nextcloud..."
sudo wget https://download.nextcloud.com/server/releases/nextcloud-22.2.0.zip -P /var/www/html/

# Descomprimir el archivo ZIP
echo "Descomprimiendo el archivo..."
sudo unzip /var/www/html/nextcloud-22.2.0.zip -d /var/www/html/

# Cambiar los permisos de los archivos
echo "Cambiando la propiedad a www-data..."
sudo chown -R www-data:www-data /var/www/html/nextcloud

# Reiniciar Apache
echo "Reiniciando Apache..."
sudo systemctl restart apache2

# Habilitar Apache para que inicie al arrancar el sistema
echo "Habilitando Apache..."
sudo systemctl enable apache2

echo "Nextcloud instalado y Apache configurado correctamente."

.