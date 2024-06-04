#!/bin/bash
#-------------------------------------------------------------
#  SCRIPT DE DESPLIEGUE EN KUBERNETES PARA MICROK8S
#  Objetivo: Automatizar la creación y despliegue de recursos
#  en Kubernetes MicroK8s, incluyendo Deployments, Ingress, 
#  Services, Persistent Volumes, Persistent Volume Claims 
#  y Secrets.
#-------------------------------------------------------------

# Definimos el total de pasos
total_steps=13

# Códigos de color
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"  # No Color
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
VIOLET="\033[0;35m"
ORANGE="\033[0;33m"

clear
echo -e "${YELLOW}========================================================${NC}"
echo -e "${YELLOW}==${NC}${VIOLET}         SCRIPT DE DESPLIEGUE EN KUBERNETES         ${YELLOW}==${NC}"
echo -e "${YELLOW}==${NC}${VIOLET}                  PARA MICROK8S                     ${YELLOW}==${NC}"
echo -e "${YELLOW}========================================================${NC}"
echo -e "${CYAN}                                                        ${NC}"
echo -e "${CYAN}   Objetivo:                                           ${NC}"
echo -e "${CYAN}   - Automatizar la creación y despliegue de recursos  ${NC}"
echo -e "${CYAN}   - Incluir Deployments, Ingress, Services, Secrets,  ${NC}"
echo -e "${CYAN}     PersistentVolume (PV), PersistentVolumeClaim (PVC)${NC}"
echo -e "${CYAN}                                                        ${NC}"
echo -e "${YELLOW}========================================================${NC}"
echo ""  # línea en blanco para separar el título del resto del contenido

# Función para simular una barra de carga
loading_bar() {
    local duration=$(( RANDOM % 3 + 1 ))  # Duración aleatoria entre 1 y 5 segundos
    local steps=duration  # Igualamos los pasos a la duración
    local filled=""
    local empty="--------------------"  # 20 guiones

    echo -ne "${ORANGE}[--------------------] 0%${NC}\r"

    for ((i=1; i<=steps; i++)); do
        sleep 1  # Duerme por un segundo
        filled=$(printf "%0.s#" $(seq 1 $((i * 20 / duration))))
        echo -ne "${ORANGE}[${filled}${empty:0:20-$((i * 20 / duration))}] $(( 100 * i / duration ))%${NC}\r"
    done

    echo -ne "\n"
}

# Paso 1: Solicitamos el nombre del proyecto
echo -e "${GREEN}Paso 1/$total_steps: Ingresando el nombre del proyecto.${NC}"
read -p "Nombre del proyecto (sin prefijos): " project_name
echo ""

# Paso 2: Solicitamos la descripción
echo -e "${GREEN}Paso 2/$total_steps: Ingresando la descripción del proyecto.${NC}"
read -p "Descripción del proyecto: " project_description
echo ""

valid_choice=false
while [ "$valid_choice" = false ]; do
    echo -e "${GREEN}Paso 3/$total_steps: Seleccionando el ambiente de trabajo.${NC}"
    echo "1) Desarrollo (dev)"
    echo "2) Testeo (qa)"
    echo "3) Producción (prod)"
    read -p "Seleccione el número del ambiente de trabajo: " environment_choice

    case $environment_choice in
        1)
            environment="dev"
            valid_choice=true
            ;;
        2)
            environment="qa"
            valid_choice=true
            ;;
        3)
            environment="prod"
            valid_choice=true
            ;;
        *)
            echo -e "${RED}Selección no válida. Por favor, elija una opción válida.${NC}"
            ;;
    esac
done
echo ""

valid_choice=false
while [ "$valid_choice" = false ]; do
    echo -e "${GREEN}Paso 4/$total_steps: Elegir el namespace.${NC}"
    echo "1) Interfaz de programación de aplicaciones (api)"
    echo "2) Aplicaciones / Servicios (web)"
    echo "3) Base de datos (bd)"
    read -p "Seleccione el número para el namespace: " namespace_choice

    case $namespace_choice in
        1)
            namespace="api"
            valid_choice=true
            ;;
        2)
            namespace="aplicaciones"
            valid_choice=true
            ;;
        3)
            namespace="bd"
            valid_choice=true
            ;;
        *)
            echo -e "${RED}Selección no válida. Por favor, elija una opción válida.${NC}"
            ;;
    esac
done
echo ""

# Definir la ruta del archivo temporal para almacenar el último node_port
LAST_NODE_PORT_FILE="/tmp/last_node_port.txt"

# Paso 4.1: Si se elige 'bd', solicitar el número de nodePort
node_port=""
if [ "$namespace" == "bd" ]; then
    # Leer el último node_port utilizado si el archivo existe
    if [ -f "$LAST_NODE_PORT_FILE" ]; then
        last_node_port=$(cat "$LAST_NODE_PORT_FILE")
        echo -e "${CYAN}Último nodePort utilizado: $last_node_port${NC}"
    fi

    echo -e "${GREEN}Paso 4.1/$total_steps: Ingresando el número de nodePort para el servicio MySQL/Postgres.${NC}"
    read -p "Ingrese el número de nodePort (ejemplo: ${last_node_port:-30038}): " node_port
    echo ""

    # Guardar el node_port ingresado en el archivo temporal
    echo "$node_port" > "$LAST_NODE_PORT_FILE"
fi

# Verificar si el namespace es 'bd' para saltarse ciertos pasos
if [ "$namespace" != "bd" ]; then
    # Paso 5: Verificamos si utiliza secrets
    echo -e "${GREEN}Paso 5/$total_steps: Utilizacion de uso de Secrets.${NC}"
    read -p "Se utiliza Secrets o .env (s/n): " use_secrets
    echo ""

    # Paso 6: Verificamos persistencia de datos
    echo -e "${GREEN}Paso 6/$total_steps: Utilizacion de persistencia de datos.${NC}"
    read -p "Usa persistencia de datos? (s/n): " use_persistence
    echo ""

    # Paso 6.1: Solicitamos el número de versión de la imagen del proyecto
    echo -e "${GREEN}Paso 6.1/$total_steps: Ingresando el número de la versión de la imagen del proyecto.${NC}"
    read -p "Número de la versión de la imagen del proyecto (ejemplo: 0.0.1): " project_image_version
    echo ""
else
    use_secrets="n"  
    use_persistence="s"  
fi

# Verificar si el namespace es 'bd' para configurar la base de datos
if [ "$namespace" == "bd" ]; then
    # Solicitar el tipo de base de datos
    echo -e "${GREEN}Selecciona el tipo de base de datos:${NC}"
    echo "1) MySQL"
    echo "2) PostgreSQL"
    read -p "Ingresa el número de tu elección: " db_choice
    
    case $db_choice in
        1)
            echo -e "${GREEN}Has seleccionado MySQL.${NC}"
            db_type="mysql"
            db_image="mysql:8.0"
            ;;
        2)
            echo -e "${GREEN}Has seleccionado PostgreSQL.${NC}"
            db_type="postgresql"
            db_image="postgres:16.2"
            ;;
        *)
            echo -e "${RED}Selección no válida. Por favor, ejecuta el script nuevamente y selecciona una opción válida.${NC}"
            exit 1
            ;;
    esac
fi

# Determinar prefijos de namespace
namespace_prefix=""
if [ "$namespace" == "api" ]; then
  namespace_prefix="api-"
elif [ "$namespace" == "aplicaciones" ]; then
  namespace_prefix="web-"
elif [ "$namespace" == "bd" ]; then
  # Asumiendo que db_type ya ha sido definido anteriormente como "mysql" o "postgresql"
  if [ "$db_type" == "mysql" ]; then
    namespace_prefix="mysql-"
  elif [ "$db_type" == "postgresql" ]; then
    namespace_prefix="postgres-"
  fi
fi

# Asegurarse de que environment_prefix solo se inicializa si no tiene ya un valor
if [ -z "$environment_prefix" ]; then
    environment_prefix=""
fi

# Determinar el prefijo del ambiente basado en el valor de $environment
if [ "$environment" == "dev" ]; then
    environment_prefix="dev-"
elif [ "$environment" == "qa" ]; then
    environment_prefix="qa-"
fi

# Concatenar prefijos con el nombre del proyecto
full_project_name="${environment_prefix}${namespace_prefix}${project_name}"
parcial_project_name="${namespace_prefix}${project_name}"
echo -e "${CYAN}Nombre completo del proyecto: ${full_project_name}${NC}"
echo ""

# Definir el host según el entorno y el namespace
host="dev.example.com"
if [ "$environment" == "prod" ]; then
  case $namespace in
    "api") host="api.example.com" ;;
    "aplicaciones") host="web.example.com" ;;
    "bd") host="db.example.com" ;;
  esac
elif [ "$environment" == "qa" ]; then
  host="qa.example.com"
fi

# Paso 7: Determinar directorios base
echo -e "${GREEN}Paso 7/$total_steps: Determinando directorios base.${NC}"
loading_bar
echo ""

BASE_DIR="/path/to/base/directory"
DEPLOYMENT_DIR="${BASE_DIR}/deployment"
INGRESS_DIR="${BASE_DIR}/ingress"
SERVICE_DIR="${BASE_DIR}/services"

# Paso 8: Verificar si el namespace elegido no es uno de los tres específicos
echo -e "${GREEN}Paso 8/$total_steps: Verificando el namespace.${NC}"
loading_bar
echo ""

if [ "$namespace" != "api" ] && [ "$namespace" != "bd" ] && [ "$namespace" != "aplicaciones" ]; then
    # Comprobar si el namespace ya existe
    if ! microk8s.kubectl get namespace "$namespace" > /dev/null 2>&1; then
        # Si no existe, crear el namespace
        microk8s.kubectl create namespace "$namespace"
    fi
fi

# Paso 9: Determinar si se necesita configuración para persistencia en el Deployment
echo -e "${GREEN}Paso 9/$total_steps: Determinando si se necesita configuración para persistencia de datos en el Deployment.${NC}"
loading_bar
echo ""

# Paso 10: Creación del archivo Deployment
echo -e "${GREEN}Paso 10/$total_steps: Creación del archivo Deployment.${NC}"
loading_bar
echo ""

deployment_file="${DEPLOYMENT_DIR}/${full_project_name}.yaml"
if [ "$use_persistence" == "s" ]; then
  # Suponiendo que db_type se ha definido anteriormente
  if [ "$db_type" == "mysql" ]; then
    db_port=3306
  elif [ "$db_type" == "postgresql" ]; then
    db_port=5432
  fi
fi

# Determinar el sufijo para la variable de entorno dependiendo del tipo de DB
if [ "$use_persistence" == "s" ]; then
  if [ "$db_type" == "mysql" ]; then
    env_var_suffix="_ROOT_PASSWORD"
  elif [ "$db_type" == "postgresql" ]; then
    env_var_suffix="_PASSWORD"
  else
    echo -e "${RED}Tipo de base de datos no soportado. Por favor, selecciona MySQL o PostgreSQL.${NC}"
    exit 1
  fi
fi

if [ "$namespace" == "bd" ]; then
    cat <<EOF > "$deployment_file"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $full_project_name
  namespace: bd
spec:
  selector:
    matchLabels:
      app: ${db_type}-${project_name}
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: ${db_type}-${project_name}
    spec:
      containers:
      - name: ${db_type}-${project_name}
        image: ${db_image}
        env:
        - name: ${db_type^^}${env_var_suffix}
          valueFrom:
            secretKeyRef:
              name: ${db_type}-secret-$project_name
              key: password
        ports:
        - containerPort: ${db_port}
          name: ${db_type}-${project_name}
        volumeMounts:
        - name: ${db_type}-persistent-storage-$project_name
          mountPath: /var/lib/${db_type}
      volumes:
      - name: ${db_type}-persistent-storage-$project_name
        persistentVolumeClaim:
          claimName: pvc-$full_project_name
EOF
else
    # Creación de Deployment para otros casos
    cat <<EOF > "$deployment_file"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $full_project_name
  namespace: $namespace
  labels:
    k8s-app: $full_project_name
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: $full_project_name
  template:
    metadata:
      name: $full_project_name
      labels:
        k8s-app: $full_project_name
    spec:
      containers:
      - name: $full_project_name
        image: your_dockerhub_username/$full_project_name:v$project_image_version
        securityContext:
          privileged: false
EOF
    # Sección para agregar las especificaciones de recursos
    if [ "$namespace" == "aplicaciones" ]; then
        # Especificaciones de recursos para aplicaciones web
        echo "        resources:" >> "$deployment_file"
        echo "          requests:" >> "$deployment_file"
        echo "            memory: \"4Mi\"" >> "$deployment_file"
        echo "            cpu: \"26m\"" >> "$deployment_file"
        echo "          limits:" >> "$deployment_file"
        echo "            memory: \"6Mi\"" >> "$deployment_file"
        echo "            cpu: \"200m\"" >> "$deployment_file"
    elif [ "$namespace" == "api" ]; then
        # Especificaciones de recursos para APIs
        echo "        resources:" >> "$deployment_file"
        echo "          requests:" >> "$deployment_file"
        echo "            memory: \"600Mi\"" >> "$deployment_file"
        echo "            cpu: \"200m\"" >> "$deployment_file"
        echo "          limits:" >> "$deployment_file"
        echo "            memory: \"900Mi\"" >> "$deployment_file"
        echo "            cpu: \"400m\"" >> "$deployment_file"
    fi
    # Agregar 'envFrom' si se usan secrets
    if [[ $use_secrets == "s" ]]; then
      echo "        envFrom:" >> "$deployment_file"
      echo "        - secretRef:" >> "$deployment_file"
      echo "            name: secret-$full_project_name" >> "$deployment_file"
    fi
fi

# Crear HPA para el deployment
echo -e "${GREEN}Creando archivo HPA para ${full_project_name}.${NC}"
loading_bar
echo ""
hpa_file="${BASE_DIR}/HPA/hpa_${full_project_name}.yaml"

cat <<EOF > "$hpa_file"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${full_project_name}-hpa
  namespace: $namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: $full_project_name
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 95
EOF

# Aplicar el HPA en el cluster
echo -e "${GREEN}Desplegando HPA ${hpa_file}.${NC}"
loading_bar
echo ""
microk8s kubectl apply -f "$hpa_file"

# Verificar el despliegue del HPA
echo -e "${GREEN}Verificando el despliegue del HPA ${full_project_name}-hpa en el namespace ${namespace}.${NC}"
if microk8s kubectl get hpa ${full_project_name}-hpa -n $namespace &> /dev/null; then
    echo -e "${GREEN}HPA ${full_project_name}-hpa desplegado correctamente.${NC}"
else
    echo -e "${RED}Error al desplegar el HPA ${full_project_name}-hpa.${NC}"
fi
echo ""

# Paso 11: Determinando el uso de Secrets
echo -e "${GREEN}Paso 11/$total_steps: Determinando el uso de Secrets.${NC}"
loading_bar
echo ""

# Paso 11: Creación del Secret para bases de datos MySQL si el namespace es 'bd'
echo -e "${GREEN}Paso 11.1/$total_steps: Creación del archivo Secret para MySQL si es necesario.${NC}"
loading_bar
echo ""

secret_file="${BASE_DIR}/secret/${db_type}-secret-${project_name}.yaml"

if [ "$namespace" == "bd" ]; then
    # Crear el archivo Secret para MySQL o PostgreSQL
    cat <<EOF > "$secret_file"
apiVersion: v1
kind: Secret
metadata:
  name: ${db_type}-secret-${project_name}
  namespace: bd
type: Opaque
data:
  password: $(echo -n "${db_type}.${project_name}2024" | base64)
EOF
    # Aplicar el archivo Secret en el clúster
    microk8s kubectl apply -f "$secret_file"
fi

# Aquí invocas el script para crear el Secret
if [[ $use_secrets == "s" ]]; then
  chmod +x ${BASE_DIR}/secret/create_sealed_secret.sh
  echo -e "${GREEN}Creando el Secret usando create_sealed_secret.sh...${NC}"
  loading_bar
  echo ""
  ${BASE_DIR}/secret/create_sealed_secret.sh
fi

# Si el usuario desea persistencia de datos y el namespace no es 'bd', agregamos los volúmenes aquí.
if [ "$use_persistence" == "s" ] && [ "$namespace" != "bd" ]; then
  echo "        volumeMounts:" >> "$deployment_file"
  echo "        - name: $full_project_name" >> "$deployment_file"
  echo "          mountPath: /$full_project_name" >> "$deployment_file"
  echo "      volumes:" >> "$deployment_file"
  echo "      - name: $full_project_name" >> "$deployment_file"
  echo "        persistentVolumeClaim:" >> "$deployment_file"
  echo "          claimName: pvc-$full_project_name" >> "$deployment_file"
else
  echo ""
fi

# Paso 12: Si el usuario desea persistencia de datos
echo -e "${GREEN}Paso 12/$total_steps: Verificando el uso de persistencia de datos.${NC}"
loading_bar
echo ""

if [ "$use_persistence" == "s" ]; then
    # Creación del archivo PersistentVolume
    echo -e "${GREEN}Creación del archivo PersistentVolume (PV).${NC}"
    loading_bar
    echo ""

    cat <<EOL > "${BASE_DIR}/persistentVolume/storage-pv-$full_project_name.yaml"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-$full_project_name
  namespace: $namespace
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/$full_project_name"
EOL

    # Creación del archivo PersistentVolumeClaim
    echo -e "${GREEN}Creación del archivo PersistentVolumeClaim (PVC).${NC}"
    loading_bar
    echo ""

    cat <<EOL > "${BASE_DIR}/persistentVolumeClaim/storage-pvc-$full_project_name.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-$full_project_name
  namespace: $namespace
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOL
fi

# Ingress
echo -e "${GREEN}Generando archivo de Ingress en ${INGRESS_DIR}...${NC}"
loading_bar
echo ""

# Determinar el puerto para Ingress basado en el namespace
if [ "$namespace" == "api" ]; then
    ingress_port=3000
elif [ "$namespace" == "aplicaciones" ]; then
    ingress_port=80
else
    ingress_port=3000  # Default o ajusta según sea necesario para otros casos
fi

cat <<EOF > "${INGRESS_DIR}/ingress_${full_project_name}.yaml"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $full_project_name
  namespace: $namespace
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
    nginx.ingress.kubernetes.io/configuration-snippet: |
      rewrite ^(/$parcial_project_name)$ \$1/ redirect;
spec:
  ingressClassName: "public"
  rules:
  - host: $host
    http:
      paths:
      - path: /$parcial_project_name(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: $full_project_name
            port:
              number: $ingress_port
EOF

# Service
echo -e "${GREEN}Generando archivo de Services en ${SERVICE_DIR}...${NC}"
loading_bar
echo ""

service_file="${SERVICE_DIR}/services_${full_project_name}.yaml"

if [ "$namespace" == "bd" ]; then
    # Creación de Service para bases de datos MySQL o PostgreSQL
    cat <<EOF > "$service_file"
apiVersion: v1
kind: Service
metadata:
  name: $full_project_name
  namespace: bd
spec:
  type: NodePort
  selector:
    app: ${db_type}-$project_name
  ports:
  - protocol: TCP
    port: ${db_port}
    targetPort: ${db_port}
    nodePort: $node_port
EOF
else
    # Creación de Service para otros casos
    cat <<EOF > "$service_file"
apiVersion: v1
kind: Service
metadata:
  name: $full_project_name
  namespace: $namespace
spec:
  selector:
    k8s-app: $full_project_name
  ports:
  - name: tcp-$ingress_port-$project_name
    protocol: TCP
    port: $ingress_port
    targetPort: $ingress_port
  type: LoadBalancer
EOF
fi

echo -e "${GREEN}¡PROCESO DE GENERACIÓN COMPLETADO!${NC}"
echo ""

echo -e "${GREEN}Archivos generados: ${full_project_name}.yaml, ingress_${full_project_name}.yaml, services_${full_project_name}.yaml${NC}"
echo ""

# Paso 13: Despliegue de los recursos en MicroK8s
echo -e "${GREEN}Paso 13/$total_steps: Despliegue de los recursos en Kubernetes MicroK8s.${NC}"
echo ""

echo -e "${GREEN}Desplegando recursos...${NC}"
loading_bar
echo ""

microk8s kubectl apply -f "${DEPLOYMENT_DIR}/${full_project_name}.yaml"
microk8s kubectl apply -f "${INGRESS_DIR}/ingress_${full_project_name}.yaml"
microk8s kubectl apply -f "${SERVICE_DIR}/services_${full_project_name}.yaml"

if [ "$use_persistence" == "s" ]; then
    # Desplegar PV y PVC
    microk8s kubectl apply -f "${BASE_DIR}/persistentVolume/storage-pv-${full_project_name}.yaml"
    microk8s kubectl apply -f "${BASE_DIR}/persistentVolumeClaim/storage-pvc-${full_project_name}.yaml"
    
    # Comprobaciones para PV y PVC
    if microk8s kubectl get pv pv-${full_project_name} &> /dev/null; then
        echo -e "${GREEN}PersistentVolume pv-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    else
        echo -e "${RED}Error al desplegar el PersistentVolume pv-${full_project_name}.${NC}"
        echo ""
    fi

    if microk8s kubectl get pvc pvc-${full_project_name} -n ${namespace} &> /dev/null; then
        echo -e "${GREEN}PersistentVolumeClaim pvc-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    else
        echo -e "${RED}Error al desplegar el PersistentVolumeClaim pvc-${full_project_name}.${NC}"
        echo ""
    fi
fi

if [[ $use_secrets == "s" ]]; then
    # Desplegar Secrets
    microk8s kubectl apply -f "${BASE_DIR}/secret/secret-${full_project_name}.yaml"

    # Comprobaciones para Secrets
    if microk8s kubectl get secret secret-${full_project_name} -n ${namespace} &> /dev/null; then
        echo -e "${GREEN}Secret secret-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    else
        echo -e "${RED}Error al desplegar el Secret secret-${full_project_name}.${NC}"
        echo ""
    fi
fi

# Comprobaciones
echo -e "${GREEN}Realizando comprobaciones...${NC}"
loading_bar
echo ""

# Comprobar Deployment
if microk8s kubectl get deployment ${full_project_name} -n ${namespace} &> /dev/null; then
    echo -e "${GREEN}Deployment ${full_project_name} desplegado correctamente.${NC}"
    echo ""
else
    echo -e "${RED}Error al desplegar el Deployment ${full_project_name}.${NC}"
    echo ""
fi

# Comprobar Ingress
if microk8s kubectl get ingress ${full_project_name} -n ${namespace} &> /dev/null; then
    echo -e "${GREEN}Ingress ${full_project_name} desplegado correctamente.${NC}"
    echo ""
else
    echo -e "${RED}Error al desplegar el Ingress ${full_project_name}.${NC}"
    echo ""
fi

# Comprobar Service
if microk8s kubectl get service ${full_project_name} -n ${namespace} &> /dev/null; then
    echo -e "${GREEN}Service ${full_project_name} desplegado correctamente.${NC}"
    echo ""
else
    echo -e "${RED}Error al desplegar el Service ${full_project_name}.${NC}"
    echo ""
fi

# Comprobar PV y PVC si se eligió la opción de persistencia
if [ "$use_persistence" == "s" ]; then
    if ! microk8s kubectl get pv pv-${full_project_name} -n ${namespace} &> /dev/null; then
        echo -e "${RED}Error al desplegar el PV pv-${full_project_name}.${NC}"
        echo ""
    else
        echo -e "${GREEN}PersistentVolume pv-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    fi

    if ! microk8s kubectl get pvc pvc-${full_project_name} -n ${namespace} &> /dev/null; then
        echo -e "${RED}Error al desplegar el PVC pvc-${full_project_name}.${NC}"
        echo ""
    else
        echo -e "${GREEN}PersistentVolumeClaim pvc-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    fi
fi

# Comprobar Secret si se eligió la opción de usar secrets
if [[ $use_secrets == "s" ]]; then
    if ! microk8s kubectl get secret secret-${full_project_name} -n ${namespace} &> /dev/null; then
        echo -e "${RED}Error al desplegar el Secret secret-${full_project_name}.${NC}"
        echo ""
    else
        echo -e "${GREEN}Secret secret-${full_project_name} desplegado correctamente.${NC}"
        echo ""
    fi
fi

echo -e "${VIOLET}¡PROCESO DE DESPLIEGUE DE ${full_project_name} EN KUBERNETES PARA MICROK8S COMPLETADO!${NC}"
echo ""

