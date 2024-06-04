#!/bin/bash

# Códigos de color
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
VIOLET="\033[0;35m"
ORANGE="\033[0;33m"

# Función para simular una barra de carga
loading_bar() {
    local duration=$(( RANDOM % 5 + 1 ))  # Duración aleatoria entre 1 y 5 segundos
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

echo -e "${YELLOW}==============================================================${NC}"
echo -e "${YELLOW}==${NC}${VIOLET}          SCRIPT DE CREACIÓN DE SEALED SECRETS           ${YELLOW}==${NC}"
echo -e "${YELLOW}==============================================================${NC}"
echo -e "${CYAN}                                                        ${NC}"
echo -e "${CYAN}   Objetivo:                                           ${NC}"
echo -e "${CYAN}   - Automatizar la creación y aplicación de SealedSecrets  ${NC}"
echo -e "${CYAN}   - Convertir archivos .env en SealedSecrets               ${NC}"
echo -e "${CYAN}   - Asegurar la correcta aplicación de SealedSecrets en MicroK8s   ${NC}"
echo -e "${CYAN}                                                        ${NC}"
echo -e "${YELLOW}==============================================================${NC}"
echo ""  # línea en blanco para separar el título del resto del contenido

# Paso 1: Verificar si kubeseal está instalado
echo -e "${GREEN}Paso 1/7: Verificando si kubeseal está instalado.${NC}"
loading_bar
if ! command -v kubeseal &> /dev/null; then
    echo -e "${RED}kubeseal no está instalado. Instalando...${NC}"
    echo ""
    wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64 -O kubeseal
    install -m 755 kubeseal /usr/local/bin/kubeseal
    echo -e "${GREEN}kubeseal instalado exitosamente.${NC}"
    echo ""
fi

# Paso 2: Verificar si el controlador Sealed Secrets está desplegado
echo -e "${GREEN}Paso 2/7: Verificando controlador Sealed Secrets.${NC}"
loading_bar
echo ""
if ! microk8s kubectl get deployment -n kube-system sealed-secrets-controller &> /dev/null; then
    echo -e "${RED}Sealed Secrets Controller no está desplegado. Desplegando...${NC}"
    echo ""
    microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami
    microk8s helm3 repo update
    microk8s helm3 install sealed-secrets-controller bitnami/sealed-secrets -n kube-system
    echo -e "${GREEN}Sealed Secrets Controller desplegado exitosamente.${NC}"
    echo ""
fi

# Paso 3: Obtener el certificado público del controlador Sealed Secrets
echo -e "${GREEN}Paso 3/7: Obteniendo el certificado público del controlador Sealed Secrets.${NC}"
loading_bar
SAVE_DIR="/path/to/save/directory/"
microk8s kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o jsonpath="{.items[0].data.tls\.crt}" | base64 --decode > tls.crt
echo -e "${GREEN}Certificado obtenido y guardado como tls.crt.${NC}"
echo ""

# Paso 4: Solicitando información al usuario
echo -e "${GREEN}Paso 4/7: Introduce el nombre del nuevo SealedSecret (ejemplo: secret-api) y el namespace (ejemplo: api, aplicaciones, db).${NC}"
read -p "Nombre del nuevo SealedSecret: " SECRET_NAME
read -p "Namespace donde se creará el SealedSecret: " NAMESPACE
loading_bar
echo ""

# Paso 5: Creación de directorio temporal y procesamiento del archivo .env
echo -e "${GREEN}Paso 5/7: Procesando el archivo .env.${NC}"
TEMP_DIR="./temp_sealed_secret"
mkdir -p $TEMP_DIR
echo -e "${CYAN}Pega el contenido de tu archivo .env y presiona Ctrl+D cuando hayas terminado:${NC}"
CONTENT=$(cat)
IFS=$'\n'
for LINE in $CONTENT; do
    KEY=$(echo $LINE | cut -d'=' -f1)
    VALUE=$(echo $LINE | cut -d'=' -f2-)
    echo -n "$VALUE" > $TEMP_DIR/$KEY
done
loading_bar
echo -e "${GREEN}Archivo .env procesado.${NC}"
echo ""

# Paso 6: Generación, sellado y aplicación del SealedSecret
echo -e "${GREEN}Paso 6/7: Generando, sellando y aplicando el SealedSecret.${NC}"
loading_bar
microk8s kubectl create secret generic $SECRET_NAME -n $NAMESPACE --from-file=$TEMP_DIR/ --dry-run=client -o json > $TEMP_DIR/$SECRET_NAME.json
sed -i "s/\"namespace\": \"default\"/\"namespace\": \"$NAMESPACE\"/" $TEMP_DIR/$SECRET_NAME.json
kubeseal --format yaml --cert=tls.crt < $TEMP_DIR/$SECRET_NAME.json > $SAVE_DIR/$SECRET_NAME.yaml
if [ ! -f "$SAVE_DIR/$SECRET_NAME.yaml" ]; then
    echo -e "${RED}Error: No se pudo crear el archivo SealedSecret $SAVE_DIR/$SECRET_NAME.yaml.${NC}"
    echo ""
    exit 1
fi
microk8s kubectl apply -f $SAVE_DIR/$SECRET_NAME.yaml -n $NAMESPACE
echo -e "${GREEN}SealedSecret creado y aplicado con éxito.${NC}"
echo ""

# Paso 7: Verificación y limpieza
echo -e "${GREEN}Paso 7/7: Verificando y realizando limpieza.${NC}"
loading_bar
echo ""
microk8s kubectl get sealedsecrets.bitnami.com $SECRET_NAME -n $NAMESPACE
rm -rf $TEMP_DIR
echo -e "${VIOLET}¡PROCESO DE CREACIÓN DE $SECRET_NAME COMPLETADO!${NC}"
