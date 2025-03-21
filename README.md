# AWS-Nextcloud-y-AWS-CLI

El Script Instalacion_todos.ps1 lo utilizaremos para la creación de la VPC, EC2, Subredes publica y privada con nat gateway aparte de instalar varios programas en la EC2 publica y la EC2 privada, este lo usaremos donde tengamos instalado el AWSCLI.

Luego tenemos el Script nextcloudInstalacion.sh este le usaremos en la EC2 pública que instalara Nextcloud, lo descomprimirá y dará permisos necesarios.

El otro Script que usaremos será el mariadbNextcloud.sh, este le usaremos en la EC2 privada, este script nos creara la base de datos, con usuario y contraseña que le indiquemos en el script, también editará el fichero 50-server.cnf y cambiara el bind-address de la actual 127.0.0.1 al 0.0.0.0 para permitir el acceso.

Cree estos dos Scripts aparte del principal que instala todo, ya que no me funcionaba si lo ponía en user-data, de todas forma lo hice de la forma más automática que pude.
