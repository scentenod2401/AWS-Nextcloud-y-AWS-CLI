#!/bin/bash

# Definir variables para facilitar la edición
DB_NAME="nextcloud"             # Nombre de la base de datos
DB_USER="steven"                # Nombre de usuario
DB_PASSWORD="Admin1234"         # Contraseña del usuario MySQL

# Ruta al archivo 50-server.cnf
CONF_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"

# Verifica si el archivo de configuración de MySQL existe
if [ -f "$CONF_FILE" ]; then
    # Elimina cualquier línea que contenga 'bind-address' y la reemplaza con 'bind-address = 0.0.0.0'
    # Esta versión es más robusta y maneja espacios y posibles comentarios
    sudo sed -i '/bind-address/ {s/^#\?bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/}' "$CONF_FILE"

    # Reinicia el servicio de MySQL para aplicar los cambios
    sudo systemctl restart mysql

    echo "La configuración de bind-address se ha actualizado correctamente."
else
    echo "El archivo $CONF_FILE no existe."
fi

# Crear la base de datos y usuario en MySQL
echo "Creando la base de datos y usuario en MySQL..."
sudo mysql -u root <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Reiniciar MariaDB para aplicar los cambios
echo "Reiniciando MariaDB..."
sudo systemctl restart mariadb

echo "Proceso completado con éxito."