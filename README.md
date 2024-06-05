# Plantillas de Scripts para Automatización y Despliegue en Kubernetes

Este repositorio contiene tres scripts diseñados para automatizar diversas tareas en Kubernetes y MicroK8s, así como para la creación de Sealed Secrets. Estas plantillas están diseñadas para ser personalizadas y utilizadas en diferentes proyectos.

## Contenido del Repositorio

1. [Crear Proyecto](#crear-proyecto)
2. [Despliegue de Proyectos en Kubernetes](#despliegue-de-proyectos-en-kubernetes)
3. [Crear Sealed Secret](#crear-sealed-secret)

---

## Crear Proyecto

Este script facilita la creación y configuración de nuevos proyectos, así como la gestión de repositorios y la integración con Docker.

### Uso

```bash
./Crear_Proyecto.sh
```

* Funcionalidades
* Configuración global para Git.
* Creación de nuevos proyectos o actualización de proyectos existentes.
* Clonación de repositorios.
* Creación y configuración de Dockerfiles para API o aplicaciones web.
* Construcción y subida de imágenes Docker.
* Creación de tags y releases en GitHub.

---

## Despliegue de Proyectos en Kubernetes

Este script automatiza la creación y despliegue de recursos en Kubernetes MicroK8s, incluyendo Deployments, Ingress, Services, Persistent Volumes, Persistent Volume Claims y Secrets.

### Uso

```bash
./Despliegue_de_Proyectos.sh
```

Funcionalidades
* Selección del ambiente de trabajo y namespace.
* Creación de Deployments, Ingress, Services, PV, PVC y Secrets.
* Verificación y despliegue de recursos en Kubernetes.
* Configuración de Horizontal Pod Autoscalers (HPA).

---

