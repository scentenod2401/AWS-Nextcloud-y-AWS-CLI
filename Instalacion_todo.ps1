# Parámetros de configuración
$VPCName = "steven_VPC_FNL"
$VPC_CIDR = "19.19.0.0/16"
$PublicSubnetName = "steven_publica_FNL"
$PrivateSubnetName = "steven_privada_FNL"
$PublicSubnetCIDR = "19.19.19.0/24"
$PrivateSubnetCIDR = "19.19.20.0/24"
$PublicEC2Name = "Steven-Instancia-Pública_FNL"
$PrivateEC2Name = "Steven-Instancia-Privada_FNL"
$InstanceType = "t2.micro"
$KeyName = "vockey"
$SecurityGroupName = "steven_SG_FNL"
$PublicEC2PrivateIP = "19.19.19.10"
$PrivateEC2PrivateIP = "19.19.20.10"
$Region = "us-east-1"  # Cambiar si es necesario

# Crear VPC
$vpcId = aws ec2 create-vpc --cidr-block $VPC_CIDR --region $Region --output text --query 'Vpc.VpcId'
aws ec2 create-tags --resources $vpcId --tags Key=Name,Value=$VPCName --region $Region

# Crear Subred pública
$publicSubnetId = aws ec2 create-subnet --vpc-id $vpcId --cidr-block $PublicSubnetCIDR --availability-zone "${Region}a" --output text --query 'Subnet.SubnetId' --region $Region
aws ec2 create-tags --resources $publicSubnetId --tags Key=Name,Value=$PublicSubnetName --region $Region

# Crear Subred privada
$privateSubnetId = aws ec2 create-subnet --vpc-id $vpcId --cidr-block $PrivateSubnetCIDR --availability-zone "${Region}a" --output text --query 'Subnet.SubnetId' --region $Region
aws ec2 create-tags --resources $privateSubnetId --tags Key=Name,Value=$PrivateSubnetName --region $Region

# Crear Internet Gateway y asociarlo a la VPC (para la subnet pública)
$internetGatewayId = aws ec2 create-internet-gateway --region $Region --output text --query 'InternetGateway.InternetGatewayId'
aws ec2 attach-internet-gateway --vpc-id $vpcId --internet-gateway-id $internetGatewayId --region $Region

# Crear tabla de rutas
$routeTableId = aws ec2 create-route-table --vpc-id $vpcId --region $Region --output text --query 'RouteTable.RouteTableId'
aws ec2 create-route --route-table-id $routeTableId --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId --region $Region

# Asociar la tabla de rutas a la subred pública
aws ec2 associate-route-table --subnet-id $publicSubnetId --route-table-id $routeTableId --region $Region

# Crear grupo de seguridad
$securityGroupId = aws ec2 create-security-group --group-name $SecurityGroupName --description "Security Group for EC2 Instances" --vpc-id $vpcId --region $Region --output text --query 'GroupId'

# Agregar reglas al grupo de seguridad
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Region
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Region
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $Region
aws ec2 authorize-security-group-ingress --group-id $securityGroupId --protocol tcp --port 3306 --cidr 0.0.0.0/0 --region $Region

# Crear Elastic IP para el NAT Gateway
$elasticIP = aws ec2 allocate-address --domain vpc --region $Region --output text --query 'AllocationId'

# Crear NAT Gateway en la subred pública y asociar la Elastic IP
$natGateway = aws ec2 create-nat-gateway --subnet-id $publicSubnetId --allocation-id $elasticIP --region $Region --output text --query 'NatGateway.NatGatewayId'

# Esperar a que el NAT Gateway esté disponible
Start-Sleep -Seconds 60

# Obtener el estado del NAT Gateway
$natGatewayState = aws ec2 describe-nat-gateways --nat-gateway-ids $natGateway --region $Region --output text --query 'NatGateways[0].State'

if ($natGatewayState -eq "available") {
    Write-Host "El NAT Gateway está disponible y listo."
} else {
    Write-Host "El NAT Gateway no está disponible aún. Intentando nuevamente."
}

# Obtener la tabla de rutas de la subred privada
$routeTablePrivateId = aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpcId --region $Region --output text --query 'RouteTables[0].RouteTableId'

# Crear una ruta en la tabla de rutas de la subred privada para usar el NAT Gateway
aws ec2 create-route --route-table-id $routeTablePrivateId --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $natGateway --region $Region

Write-Host "Ruta para el NAT Gateway agregada a la tabla de rutas de la subred privada."

# Asegurar que DNS está habilitado en la VPC
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support --region $Region
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames --region $Region

Write-Host "DNS habilitado para la VPC."

# Crear instancia pública con IP pública asignada
$publicEC2 = aws ec2 run-instances --image-id "ami-084568db4383264d4" --count 1 --instance-type $InstanceType --key-name $KeyName --subnet-id $publicSubnetId --security-group-ids $securityGroupId --private-ip-address $PublicEC2PrivateIP --associate-public-ip-address --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PublicEC2Name}]" --user-data @"
#!/bin/bash
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update -y
sudo apt upgrade -y
sudo apt install unzip -y
sudo apt install apache2 libapache2-mod-php7.4 php7.4 php7.4-cli php7.4-gd php7.4-json php7.4-mbstring php7.4-curl php7.4-xml php7.4-zip php7.4-mysql php7.4-bcmath -y
sudo systemctl enable ssh
"@ --region $Region --output text --query 'Instances[0].InstanceId'

# Obtener la IP pública y DNS de la instancia pública
$publicEC2InstanceId = aws ec2 describe-instances --instance-ids $publicEC2 --region $Region --output text --query 'Reservations[0].Instances[0].PublicIpAddress'
$publicEC2DNS = aws ec2 describe-instances --instance-ids $publicEC2 --region $Region --output text --query 'Reservations[0].Instances[0].PublicDnsName'

Write-Host "La IP pública de la instancia EC2 pública es: $publicEC2InstanceId"
Write-Host "El DNS de la instancia EC2 pública es: $publicEC2DNS"

# Crear instancia privada
$privateEC2 = aws ec2 run-instances --image-id "ami-084568db4383264d4" --count 1 --instance-type $InstanceType --key-name $KeyName --subnet-id $privateSubnetId --security-group-ids $securityGroupId --private-ip-address $PrivateEC2PrivateIP --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$PrivateEC2Name}]" --user-data @"
#!/bin/bash
sudo apt update -y
sudo apt upgrade -y
sudo apt install software-properties-common -y
sudo add-apt-repository 'deb [arch=amd64,arm64] http://mariadb.mirror.globo.tech/mariadb/repo/10.11/ubuntu focal main' -y
sudo apt update
sudo apt install mariadb-server -y
# Habilitar el servicio SSH y MariaDB
sudo systemctl enable ssh
sudo systemctl enable mariadb

"@ --region $Region --output text --query 'Instances[0].InstanceId'

Write-Host "Infraestructura creada correctamente." 