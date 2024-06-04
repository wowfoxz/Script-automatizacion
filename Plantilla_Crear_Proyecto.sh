#!/bin/bash
clear
# Colores para los mensajes
GREEN='\033[0;32m'
VIOLET='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuración global para git (por defecto)
default_git_user="your_default_git_user"
default_git_email="your_default_git_email"
default_github_token="your_default_github_token"
default_repo_org="your_default_repo_org"

# Mensaje de inicio
echo -e "${YELLOW}========================================================${NC}"
echo -e "${YELLOW}==         ${VIOLET}SCRIPT DE AUTOMATIZACIÓN DE TAREAS${YELLOW}         ==${NC}"
echo -e "${YELLOW}==             PARA PROYECTOS Y DOCKER                 ==${NC}"
echo -e "${YELLOW}========================================================${NC}"
echo -e "\n   ${CYAN}Objetivo:${NC}"
echo -e "   - Facilitar la creación y configuración de proyectos"
echo -e "   - Automatizar el manejo de repositorios y la integración con Docker"
echo -e "${YELLOW}========================================================${NC}"

# Mostrar y preguntar si quiere cambiar el usuario de GitHub
echo -e "${GREEN}Usuario de GitHub por defecto: ${NC}${default_git_user}"
read -p "¿Desea cambiar el usuario de GitHub? [s/n]: " cambiar_git_user
if [[ "$cambiar_git_user" == "s" || "$cambiar_git_user" == "S" ]]; then
    read -p "Ingrese su nuevo usuario de GitHub: " git_user
else
    git_user=$default_git_user
fi

# Mostrar y preguntar si quiere cambiar el correo electrónico de GitHub
echo -e "${GREEN}Correo electrónico de GitHub por defecto: ${NC}${default_git_email}"
read -p "¿Desea cambiar el correo electrónico de GitHub? [s/n]: " cambiar_git_email
if [[ "$cambiar_git_email" == "s" || "$cambiar_git_email" == "S" ]]; then
    read -p "Ingrese su nuevo correo electrónico de GitHub: " git_email
else
    git_email=$default_git_email
fi

# Mostrar y preguntar si quiere cambiar el token de GitHub
echo -e "${GREEN}Parte del token de GitHub por defecto: ${NC}${default_github_token:0:15}..."
read -p "¿Desea cambiar el token de GitHub? [s/n]: " cambiar_token
if [[ "$cambiar_token" == "s" || "$cambiar_token" == "S" ]]; then
    read -p "Ingrese su nuevo token de GitHub: " github_token
else
    github_token=$default_github_token
fi

# Mostrar y preguntar si quiere cambiar la carpeta de entidad
echo -e "${GREEN}Carpeta del Repositorio por defecto: ${NC}${default_repo_org}"
read -p "¿Desea cambiar la carpeta repo de GitHub? [s/n]: " cambiar_repositorio
if [[ "$cambiar_repositorio" == "s" || "$cambiar_repositorio" == "S" ]]; then
    read -p "Ingrese el nombre de la nueva carpeta repo de GitHub (ej: otro-repositorio): " repo_org
else
    repo_org=$default_repo_org
fi

# Configuración global para git
git config --global user.name "$git_user"
git config --global user.email "$git_email"

# Preguntar al usuario si es un proyecto nuevo o una actualización
echo -e "${GREEN}PASO 1/11 : Elegir tipo de proyecto${NC}"
echo "Seleccione el tipo de proyecto:"
echo "  1) Nuevo"
echo "  2) Actualización"

while true; do
    read -p "Ingrese su elección [1/2]: " opcion_proyecto
    case $opcion_proyecto in
    1)
        tipo_proyecto="nuevo"
        echo "Ha seleccionado 'Nuevo'."
        break # Salir del bucle una vez que la entrada es válida
        ;;
    2)
        tipo_proyecto="actualizacion"
        echo "Ha seleccionado 'Actualización'."
        break # Salir del bucle una vez que la entrada es válida
        ;;
    *)
        echo "Opción no válida. Por favor, seleccione 1 para Nuevo o 2 para Actualización."
        ;;
    esac
done

if [[ "$tipo_proyecto" == "nuevo" ]]; entonces
    # Solicitar nombre del proyecto
    echo -e "${GREEN}PASO 2/11 : Nombre del proyecto${NC}"
    read -p "Creara la carpeta principal del proyecto (ejemplo: asistencia-policia): " nombre_proyecto
    mkdir -p "$nombre_proyecto" && cd "$nombre_proyecto"

    # Clonar repositorio
    echo -e "${GREEN}PASO 3/11 : Clonar repositorio${NC}"
    read -p "Ingrese el nombre del repositorio (ej: web-$nombre_proyecto.git): " repo_nombre
    git clone "https://${github_token}@github.com/${repo_org}/${repo_nombre}" || {
        echo "Error al clonar el repositorio. Verifique el nombre y la conexión a internet."
        exit 1
    }

    # Extraer el nombre del directorio del repositorio desde el nombre del repositorio
    repo_dir=$(basename "$repo_nombre" .git)
    cd "$repo_dir" || {
        echo "No se pudo entrar en el directorio '$repo_dir'. Verifique que el repositorio se haya clonado correctamente."
        exit 1
    }
else
    # Actualización de proyecto existente
    echo -e "${GREEN}PASO 4/11 : Actualizar proyecto existente${NC}"
    ls -1d */
    read -p "Seleccione la carpeta del proyecto: " proyecto_folder
    cd "$proyecto_folder" || {
        echo "Carpeta no encontrada. Verifique su elección."
        exit 1
    }
    ls -1d */
    read -p "Seleccione la subcarpeta: " sub_folder
    repo_nombre=$sub_folder
    nombre_proyecto=$proyecto_folder
    cd "$sub_folder" || {
        echo "Subcarpeta no encontrada. Verifique su elección."
        exit 1
    }
fi
echo -e "${GREEN}nombre del repo: '$repo_nombre'${NC}"
# Configurar el remoto para usar el token en futuras operaciones
git remote set-url origin "https://${github_token}@github.com/${repo_org}/${repo_nombre}"
GH_TOKEN=$github_token

# Selección de rama con menú interactivo
echo -e "${GREEN}PASO 5/11 : Selección de rama${NC}"
echo "Cargando ramas disponibles..."
git fetch --all
branches=$(git branch -r | grep -v '\->' | sed 's/origin\///')
echo -e "${CYAN}Lista de ramas disponibles (locales y remotas):${NC}"
select rama in $branches; do
    if [[ -n "$rama" ]]; entonces
        echo "Ha seleccionado la rama '$rama'."
        git checkout $rama || {
            echo "Error al cambiar de rama. Verifique el nombre de la rama."
            exit 1
        }
        # Realizar un pull para asegurarse de que la rama está actualizada
        echo -e "${CYAN}Actualizando la rama...${NC}"
        git pull origin $rama || {
            echo "Error al actualizar la rama. Verifique su conexión y permisos."
            exit 1
        }
        break
    else
        echo "Selección inválida. Intente de nuevo."
    fi
done

# Verificar existencia de Dockerfile
echo -e "${GREEN}PASO 6/11 : Verificar existencia de archivo Dockerfile${NC}"
if [[ ! -f Dockerfile ]]; entonces
    echo "El archivo Dockerfile no existe. Procederemos a crearlo."
    echo "Seleccione el tipo de aplicación:"
    echo "  1) API"
    echo "  2) Web"
    read -p "Ingrese su elección [1/2]: " app_type

    case $app_type in
    1)
        echo "Seleccione la configuración para API:"
        echo "  1) Con Oracle"
        echo "  2) Con otras bases de datos"
        read -p "Ingrese su elección [1/2]: " api_type
        if [[ "$api_type" == "1" ]]; entonces
            cat >Dockerfile <<'EOF'
FROM your_base_image:v1
WORKDIR /your_workdir
RUN apt-get update && apt-get install -y wget unzip libaio1 \
    && mkdir -p /opt/oracle \
    && cd /opt/oracle \
    && wget https://download.oracle.com/otn_software/linux/instantclient/1919000/instantclient-basic-linux.x64-19.19.0.0.0dbru.el9.zip \
    && unzip instantclient-basic-linux.x64-19.19.0.0.0dbru.el9.zip \
    && rm instantclient-basic-linux.x64-19.19.0.0.0dbru.el9.zip \
    && echo /opt/oracle/instantclient_19_19 > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_19_19:\$LD_LIBRARY_PATH
COPY . /your_workdir
RUN ["your_package_manager", "install"]
EXPOSE 3000
ENV NAME World
CMD ["your_command_to_start"]
EOF
        else
            cat >Dockerfile <<'EOF'
FROM your_base_image:v1
WORKDIR /your_workdir
COPY . /your_workdir
RUN ["your_package_manager", "install"]
EXPOSE 3000
ENV NAME World
CMD ["your_command_to_start"]
EOF
        fi
        ;;
    2)
        echo "Seleccione la configuración para Web:"
        echo "  1) Con Vite"
        echo "  2) Sin Vite"
        read -p "Ingrese su elección [1/2]: " web_type
        if [[ "$web_type" == "1" ]]; entonces
            cat >Dockerfile <<'EOF'
FROM node:alpine AS build
WORKDIR /app
COPY package*.json ./
RUN your_package_manager install
COPY . .
RUN your_package_manager build
FROM nginx:1.21.3-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
        else
            cat >Dockerfile <<'EOF'
FROM node:alpine AS build
WORKDIR /app
COPY package*.json ./
RUN your_package_manager install
COPY . .
RUN your_package_manager build
FROM nginx:1.21.3-alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
        fi
        ;;
    esac
else
    echo "El archivo Dockerfile ya existe."
fi

# Continuar con los pasos para construir y subir la imagen Docker
echo -e "${GREEN}PASO 7/11 : Construcción de la Imagen Docker y GitHub Tag/release${NC}"
read -p "Nombre completo de la imagen que tendrá en DockerHub (ejemplo: dev-web-$nombre_proyecto): " imagen_nombre

# Obtener el último tag del repositorio
echo -e "${GREEN}Obteniendo el último tag del repositorio GitHub${NC}"
latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1))
echo -e "${CYAN}El último tag en el repositorio GitHub es: $latest_tag${NC}"

read -p "Versión de la imagen que se subirá al DockerHub (ejemplo: 0.0.1): " imagen_version
read -p "Ingrese una descripción para el Release del GitHub Versión $imagen_version: " release_description

# Antes de empezar con Git, asegúrate de que el usuario de Git esté configurado
if ! git config user.name &>/dev/null || ! git config user.email &>/dev/null; entonces
    echo "Usuario de Git no configurado. Configurando..."
    git config --global user.name "$git_user"
    git config --global user.email "$git_email"
fi

# Verificar si 'gh' está instalado
if ! command -v gh &>/dev/null; entonces
    echo "GitHub CLI no está instalada. Instalando GitHub CLI..."
    # Instalar GitHub CLI para Debian/Ubuntu
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install gh -y
fi

# Configurar GitHub CLI con token de GitHub
if ! gh auth status &>/dev/null; entonces
    echo "Configurando autenticación de GitHub CLI..."
    echo $GH_TOKEN | gh auth login --with-token
fi

# Construir y subir la imagen Docker
echo -e "${GREEN}PASO 8/11 : Construir imagen Docker${NC}"
docker build -t "your_dockerhub_username/$imagen_nombre:v$imagen_version" .
echo -e "${GREEN}PASO 9/11 : Subir imagen Docker${NC}"
docker push "your_dockerhub_username/$imagen_nombre:v$imagen_version"

# PASO 10/11: Crear tag y release en GitHub
echo -e "${GREEN}PASO 10/11 : Crear tag y release en GitHub${NC}"
# Verificar si el tag ya existe
if git rev-parse "v$imagen_version" >/dev/null 2>&1; entonces
    echo "El tag 'v$imagen_version' ya existe. No se agregará un nuevo tag ni se creará un release."
else
    # Si el tag no existe, crearlo y hacer push
    git tag -a "v$imagen_version" -m "$release_description" || { echo "Error al crear el tag"; exit 1; }
    git push origin "v$imagen_version" || { echo "Error al empujar el tag a GitHub"; exit 1; }
    # Crear un release en GitHub con título y descripción específicos
    if ! gh release create "v$imagen_version" --title "v$imagen_version" --notes "$release_description"; entonces
        echo "Error al crear el release en GitHub"
        exit 1
    fi
fi

# Eliminar la imagen local después de subirla
echo -e "${GREEN}PASO 11/11 : Eliminar imagen Docker local${NC}"
docker rmi "your_dockerhub_username/$imagen_nombre:v$imagen_version"

# Verificación final
echo -e "${GREEN}Verificación final${NC}"
echo "Por favor, verifique la imagen subida en https://hub.docker.com/u/your_dockerhub_username y el release en GitHub"
