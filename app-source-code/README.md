# 🚀 Pipeline de CI/CD con Bitbucket Pipelines para App-Source-Code

**Estado**: ✅ Funcional y Actualizado  
**Última Actualización**: 11 de septiembre de 2025  
**Versión**: 2.0 (Actualizaciones 2025: Soporte para Concurrency Groups en Pipelines, OIDC para AWS, Integración con Jira Compass para DORA Metrics, y Bitbucket Pipes para Deploys K8s)  

Este README documenta el pipeline de CI/CD para el repositorio **app-source-code**, que contiene el código fuente de una aplicación Node.js simple (`app/index.js`) y configuraciones para automatizar builds, pushes a AWS ECR, generación de manifests Kubernetes, y despliegues en Rancher (desarrollo) o AWS EKS (producción). El pipeline se basa en el archivo `.env` en la raíz del repositorio, que define variables comunes y específicas por ambiente (`DEV_*` para desarrollo, `PROD_*` para producción). Es necesario editar `.env` con los valores proporcionados según el entorno objetivo y cargar credenciales sensibles como variables seguras en Bitbucket.

**Análisis y Mejoras**:
- **Uso de .env**: Explico cómo el pipeline carga `.env` usando `load-env.sh` (del submódulo `infra-cicd-tools`), seleccionando variables por branch (`DEV_*`/`PROD_*`). Incluyo instrucciones para editar `.env` con valores específicos (e.g., `JIRA_BASE_URL`, `AWS_ACCESS_KEY_ID`).
- **Ejecución del Pipeline**: Detallo paso a paso qué sucede al ejecutar un pipeline (e.g., push a `main` o UI manual), desde el trigger hasta los outputs en Bitbucket UI, con énfasis en cómo se usan las variables de `.env`.
- **Estructura**: Menú expandido, tablas para variables, checklists, y secciones nuevas como "Monitoreo y Métricas" y "Mejores Prácticas 2025" (OIDC, DORA, Pipes).
- **Detalles**: Cada archivo/script se explica con su rol en el pipeline, parámetros, outputs, y edge cases. Troubleshooting cubre errores comunes al ejecutar pipelines.

## 📖 Tabla de Contenidos (Menú Expandido)

- [📋 Descripción General](#-descripción-general)
- [🏗️ Arquitectura del Pipeline](#️-arquitectura-del-pipeline)
  - [Componentes Principales](#componentes-principales)
  - [Diagrama de Flujo](#diagrama-de-flujo)
- [⚙️ Configuración Requerida](#️-configuración-requerida)
  - [Prerrequisitos](#prerrequisitos)
  - [Editar el Archivo .env](#editar-el-archivo-env)
  - [Variables de Entorno en Bitbucket](#variables-de-entorno-en-bitbucket)
  - [Configuración Avanzada (OIDC para AWS)](#configuración-avanzada-oidc-para-aws)
- [📁 Estructura de Archivos](#-estructura-de-archivos)
- [🎯 Pipelines Disponibles](#-pipelines-disponibles)
  - [Pipelines Automáticos](#pipelines-automáticos)
  - [Pipelines Manuales](#pipelines-manuales)
- [🛠️ MÓDULOS](#️-módulos)
  - [app/](#app)
  - [kubernetes-manifests/](#kubernetes-manifests)
  - [Scripts y Herramientas](#scripts-y-herramientas)
  - [Pipelines Bitbucket](#pipelines-bitbucket)
- [🔄 Flujos de Trabajo](#-flujos-de-trabajo)
  - [Ejecución de un Pipeline Bitbucket](#ejecución-de-un-pipeline-bitbucket)
- [🚀 GUÍA DE IMPLEMENTACIÓN RÁPIDA](#-guía-de-implementación-rápida)
- [📊 Monitoreo y Métricas](#-monitoreo-y-métricas)
- [🔧 Mejores Prácticas y Actualizaciones 2025](#-mejores-prácticas-y-actualizaciones-2025)
- [❌ Solución de Problemas Avanzada](#-solución-de-problemas-avanzada)
- [📞 SOPORTE Y TROUBLESHOOTING](#-soporte-y-troubleshooting)
  - [Logs de Depuración](#logs-de-depuración)
  - [Enlaces Útiles](#enlaces-útiles)
- [📝 LICENCIA](#-licencia)
- [🤝 CONTRIBUCIONES](#-contribuciones)
- [📧 SOPORTE](#-soporte)
- [🔄 Changelog](#-changelog)

---

## 📋 Descripción General

El repositorio **app-source-code** contiene el código fuente de una aplicación Node.js simple (`app/index.js`, que sirve "¡Hola Mundo desde Docker en AWS ECR!" en el puerto 3000) y configuraciones para un pipeline CI/CD en Bitbucket Pipelines. Este pipeline automatiza:
- **Build**: Construye una imagen Docker usando el `Dockerfile` en la raíz.
- **Push**: Sube la imagen a AWS ECR (producción).
- **Despliegue**: Genera manifests Kubernetes desde templates y los aplica en Rancher (dev) o EKS (prod).
- **Integración JIRA**: Detecta claves JIRA en commits y agrega comentarios automáticos post-deploy.
- **Notificaciones**: Logs y métricas DORA (Deployment Frequency, Lead Time) en Jira Compass.

El pipeline usa el archivo `.env` en la raíz para cargar configuraciones comunes (`APP_NAME`, `JIRA_*`) y específicas por ambiente (`DEV_*` para `develop`, `PROD_*` para `main`). Es necesario editar `.env` con los valores proporcionados (e.g., `JIRA_BASE_URL=https://your-company.atlassian.net`) y cargar credenciales sensibles (e.g., `JIRA_API_TOKEN`, `AWS_ACCESS_KEY_ID`) como variables seguras en Bitbucket.

**Características clave**:
- **Automatización**: Trigger por push o UI manual; steps secuenciales con artefactos compartidos (e.g., manifests, logs).
- **Multi-ambiente**: `develop` → Rancher local (NGINX Ingress); `main` → EKS (ALB con SSL).
- **Seguridad**: OIDC para AWS (sin keys expuestas); secrets en Bitbucket secured.
- **Escalabilidad**: Concurrency Groups (2025) para evitar deploys concurrentes; Pipes para tareas comunes (e.g., `atlassian/kubernetes-deploy`).
- **Métricas**: DORA vía Jira Compass para OKRs (nuevo 2025).

**Al ejecutar un pipeline**, Bitbucket carga `.env` (via `load-env.sh` del submódulo `infra-cicd-tools`), selecciona variables según el branch, ejecuta steps en un runner Docker, y muestra logs/artefactos en la UI.

## 🏗️ Arquitectura del Pipeline

### Componentes Principales
- **Archivo .env**: Define variables comunes (`APP_NAME`, `APP_PORT`) y por ambiente (`DEV_K8S_NAMESPACE`, `PROD_K8S_REPLICAS`). Cargado en step inicial (`load-env.sh`).
- **Submódulo `infra-cicd-tools`**: Scripts reutilizables (e.g., `build-image.sh`, `deploy-to-eks.sh`) inicializados en step `init-submodule`.
- **Artefactos**: Archivos generados (e.g., `docker-image-info.txt`, manifests en `/generated/`) compartidos entre steps.
- **Anchors YAML**: Reutilización de steps (e.g., `&build-docker-image`) en branches/custom.
- **JIRA**: Auto-comment en issues; métricas DORA (2025).
- **Concurrency Groups**: Evita deploys simultáneos en prod (nuevo 2025).

### Diagrama de Flujo
Muestra el flujo al ejecutar un pipeline (e.g., push a `main` o UI run de `full-pipeline`).

```mermaid
graph TD
    A[Trigger: Push/UI Run] --> B{Branch?}
    B -->|develop| C[Development Flow]
    B -->|main| D[Production Flow]

    subgraph Development Flow [app-source-code]
        C1[Load .env & Init Submódulo] --> C2[Setup Dev (utils/setup.sh)]
        C2 --> C3[Build Docker (app/Dockerfile)]
        C3 --> C4[Generate Manifests (kubernetes-manifests/templates)]
        C4 --> C5[Deploy Rancher (overlays/rancher-local)]
        C5 --> C6[Collect Logs & Notify]
    end

    subgraph Production Flow [app-source-code + Submódulo]
        D1[Load .env & Init Submódulo] --> D2[Setup Prod (utils/setup.sh)]
        D2 --> D3[Detect JIRA Keys (jira/detect-jira-keys.sh)]
        D3 --> D4[Build Docker (app/Dockerfile)]
        D4 --> D5[Push ECR (docker/push-to-ecr.sh)]
        D5 --> D6[Generate Manifests (kubernetes-manifests/templates)]
        D6 --> D7[Deploy EKS (overlays/aws-eks)]
        D7 --> D8[Comment JIRA (jira/comment-jira.sh)]
        D8 --> D9[Collect Logs & Notify (DORA Metrics)]
    end

    style Development Flow fill:#f0f9ff,stroke:#0369a1
    style Production Flow fill:#fefce8,stroke:#ca8a04
```

**Cómo funciona al ejecutar**: Bitbucket crea un runner (Docker image: `atlassian/default-image:3`), carga `.env`, inicializa submódulo, ejecuta steps secuenciales o paralelos, comparte artefactos, y muestra logs/artefactos en la UI.

## ⚙️ Configuración Requerida

### Prerrequisitos
- ✅ **Bitbucket**: Pipelines habilitado (50 min/mes gratis; premium para Concurrency Groups 2025).
- ✅ **JIRA**: Proyecto con API v3+ y "Link Issues" permission (requerido desde Nov 2025).
- ✅ **Kubernetes**: EKS v1.29+ (ARM support) o Rancher v2.8+ (NGINX Ingress).
- ✅ **AWS**: ECR repo creado (`mi-aplicacion`); IAM OIDC para Pipelines.
- ✅ **Herramientas**: Node.js 18+ para `app/index.js`; awscli/kubectl en runner (instalados via `setup.sh`).
- **Checklist**:
  - [ ] Ejecuta `create.sh` para generar estructura (`app/`, `kubernetes-manifests/`).
  - [ ] Inicializa submódulo: `git submodule update --init`.
  - [ ] Prueba app local: `cd app && node index.js` (debe responder en `http://localhost:3000`).

### Editar el Archivo .env
El archivo `.env` en la raíz es la fuente principal de configuración. **Es necesario editarlo** con los valores específicos para su entorno (desarrollo o producción) según la siguiente plantilla. Variables sensibles (e.g., `JIRA_API_TOKEN`, `AWS_ACCESS_KEY_ID`) deben cargarse como variables seguras en Bitbucket, no en `.env`.

**Plantilla .env**:
```bash
# ===== CONFIGURACIÓN COMÚN =====
APP_NAME=hola-mundo              # Nombre de la app (usado en tags, manifests)
APP_VERSION=1.0.0                # Versión de la app (metadata en manifests)
APP_PORT=3000                    # Puerto del servidor Node.js
DOMAIN=example.com               # Dominio base para Ingress (editar según entorno)
#LOG_LEVEL=info                  # Nivel de logging (descomentar si se usa)

# JIRA Configuration
JIRA_BASE_URL=https://your-company.atlassian.net  # URL de tu instancia JIRA
JIRA_USERNAME=user@example.com                    # Email del usuario JIRA
JIRA_API_TOKEN=your_jira_api_token                # Token API (generar en id.atlassian.com)
JIRA_PROJECT_KEY=JD                               # Prefijo de issues (e.g., JD-123)
JIRA_DEFAULT_ISSUE=JD-179                         # Issue por defecto para comments manuales

# ===== CONFIGURACIÓN POR AMBIENTE =====
# Desarrollo (usado en branch develop)
DEV_ENVIRONMENT=development       # Nombre del entorno
DEV_IMAGE_TAG=latest              # Tag de imagen Docker para dev
DEV_K8S_NAMESPACE=dev-namespace   # Namespace K8s para dev
DEV_K8S_REPLICAS=1               # Replicas en dev
DEV_DB_HOST=dev-database.example.com  # Host DB para dev

# Producción (usado en branch main)
PROD_ENVIRONMENT=production       # Nombre del entorno
PROD_IMAGE_TAG=stable             # Tag de imagen para prod
PROD_K8S_NAMESPACE=prod-namespace # Namespace K8s para prod
PROD_K8S_REPLICAS=3              # Replicas en prod
PROD_DB_HOST=prod-database.example.com  # Host DB para prod

# Database Configuration (común, pero usado en manifests)
PROD_DB_USER=appuser             # Usuario DB
PROD_DB_HOST=database.example.com  # Host DB genérico
PROD_DB_NAME=appdb               # Nombre DB
PROD_DB_PORT=5432                # Puerto DB

# ===== CONFIGURACIÓN POR PLATAFORMA =====
# Rancher (Desarrollo)
RANCHER_KUBE_CONTEXT=rancher-desktop  # Contexto kubectl para Rancher
RANCHER_INGRESS_CLASS=nginx          # Clase Ingress (NGINX para dev)
RANCHER_K8S_NAMESPACE=default        # Namespace para Rancher
RANCHER_K8S_REPLICAS=2              # Replicas en Rancher

# EKS (Producción)
EKS_CLUSTER_NAME=my-eks-cluster      # Nombre del cluster EKS
EKS_AWS_REGION=us-east-1            # Región AWS
EKS_CERTIFICATE_ARN=arn:aws:acm:us-east-1:123456789012:certificate/abcd1234  # Certificado ACM para ALB
EKS_ECR_REPO_NAME=mi-aplicacion     # Nombre del repo ECR

# AWS Configuration (credenciales sensibles, usar Bitbucket variables)
AWS_ACCESS_KEY_ID=your_aws_access_key  # AWS Access Key (cargar en Bitbucket)
AWS_SECRET_ACCESS_KEY=your_aws_secret_key  # AWS Secret Key (cargar en Bitbucket)
AWS_ACCOUNT_ID=123456789012            # ID de cuenta AWS
AWS_REGION=us-east-1                   # Región AWS (coherente con EKS)
```

**Instrucciones para editar .env**:
1. Copia `.env.example` a `.env`: `cp .env.example .env`.
2. Edita `.env` con un editor (e.g., `vim .env`):
   - **Común**: Reemplaza `APP_NAME`, `DOMAIN`, `JIRA_BASE_URL`, etc., con valores reales (e.g., `JIRA_BASE_URL=https://mi-empresa.atlassian.net`).
   - **Desarrollo**: Ajusta `DEV_*` (e.g., `DEV_DB_HOST=dev-db.mi-empresa.com`).
   - **Producción**: Ajusta `PROD_*` (e.g., `PROD_K8S_REPLICAS=5` si necesitas más replicas).
   - **Plataforma**: Configura `EKS_*` con tu cluster AWS; `RANCHER_*` para dev local.
   - **Sensibles**: No edites `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `JIRA_API_TOKEN` en `.env`; cárgalos en Bitbucket (ver abajo).
3. No commitees `.env` (está en `.gitignore`).

**Al ejecutar pipeline**: `load-env.sh` lee `.env`; selecciona `DEV_*` para branch `develop`, `PROD_*` para `main`; exporta a `export_vars.sh` para steps.

### Variables de Entorno en Bitbucket
Credenciales sensibles y algunas variables comunes deben configurarse en **Bitbucket > Repository settings > Variables** (marcar "Secured" para protegerlas). Estas se inyectan en el runner al ejecutar el pipeline.

| Categoría | Variable | Descripción | Ejemplo | Secured? |
|-----------|----------|-------------|---------|----------|
| **App** | `APP_NAME` | Nombre app | `hola-mundo` | No |
| **App** | `APP_PORT` | Puerto Node.js | `3000` | No |
| **JIRA** | `JIRA_BASE_URL` | URL JIRA | `https://your-company.atlassian.net` | No |
| **JIRA** | `JIRA_USERNAME` | Email usuario | `user@example.com` | No |
| **JIRA** | `JIRA_API_TOKEN` | Token API | `ATATT3x...` | Sí |
| **JIRA** | `JIRA_PROJECT_KEY` | Prefijo issues | `JD` | No |
| **AWS** | `AWS_ACCESS_KEY_ID` | Access Key (fallback; usa OIDC) | `AKIA...` | Sí |
| **AWS** | `AWS_SECRET_ACCESS_KEY` | Secret Key | `wJalrXU...` | Sí |
| **AWS** | `AWS_ACCOUNT_ID` | Cuenta ID | `123456789012` | No |
| **AWS** | `AWS_REGION` | Región | `us-east-1` | No |
| **DB** | `PROD_DB_USER` | Usuario DB | `appuser` | No |
| **DB** | `PROD_DB_NAME` | Nombre DB | `appdb` | No |
| **DB** | `PROD_DB_PORT` | Puerto DB | `5432` | No |

**Nota**: Variables como `DEV_*`, `PROD_*`, `EKS_*`, `RANCHER_*` se cargan desde `.env`, no Bitbucket, para flexibilidad por ambiente.

### Configuración Avanzada (OIDC para AWS)
Para autenticación segura sin keys rotativas (best practice 2025):
1. En Bitbucket: **Repository Settings > OpenID Connect** > Copia Provider URL/Audience.
2. En AWS IAM: Crea OIDC Provider (URL: `https://api.bitbucket.org/2.0/workspaces/{workspace}/pipelines-config/identity/oidc`).
3. Crea role `bitbucket-deploy-role` con trust policy; attach policies para ECR push/pull, EKS access.
4. En `bitbucket-pipelines.yml`: Usa `oidc: true` en steps; `aws sts assume-role-with-web-identity` con `$BITBUCKET_STEP_OIDC_TOKEN`.

**Trust Policy Ejemplo**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/api.bitbucket.org" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": { "StringEquals": { "api.bitbucket.org:sub": "BITBUCKET_STEP_OIDC_TOKEN" } }
    }
  ]
}
```

**Al ejecutar**: Step `push-to-ecr` asume role via OIDC; logs muestran `aws sts get-caller-identity`.

## 📁 Estructura de Archivos

El pipeline usa archivos en `app-source-code/` para código, manifests, y configuración. `.env` es clave para variables; submódulo `infra-cicd-tools` proporciona scripts.

```
app-source-code/
├── .env                                   # Configuración: Vars comunes (APP_NAME) y por ambiente (DEV_*/PROD_*)
├── app/                                   # Código fuente: Node.js app
│   └── index.js                           # Servidor HTTP: Responde "¡Hola Mundo!" en / (puerto 3000)
├── kubernetes-manifests/                   # Templates/overlays para K8s
│   └── overlays/
│       ├── aws-eks/                       # Configs EKS (prod)
│       │   └── ingress.yaml.tpl           # ALB Ingress: SSL, healthchecks, host-based routing
│       └── rancher-local/                 # Configs Rancher (dev)
│           └── ingress.yaml.tpl           # NGINX Ingress: Rewrite, no SSL
├── bitbucket-pipelines_old.yml            # Legacy: Curl scripts externos
├── bitbucket-pipelines_submoduleworks.yml # Debug: Testea submódulo
├── bitbucket-pipelines.yml                # Principal: Anchors, oidc, artefacts
├── create.sh                              # Inicializa estructura (mkdir/touch)
├── Dockerfile                             # Imagen: Node.js 18-alpine, copia app/, CMD node
└── README.md                              # Este doc: Guía completa
```

**Al ejecutar**: Pipeline parsea `bitbucket-pipelines.yml`, carga `.env`, usa `Dockerfile` para build, genera manifests en `/generated/` (temporal), y persiste artefactos (logs, manifests).

## 🎯 Pipelines Disponibles

### Pipelines Automáticos
- **main (Producción)**: Trigger en push/merge; carga `PROD_*` de `.env`; ejecuta: init → setup → detect JIRA → build → push ECR → generate → deploy EKS → comment JIRA → notify. Duración: ~5-10 min.
- **develop (Desarrollo)**: Trigger en push; carga `DEV_*`; init → setup → build → generate → deploy Rancher → notify. Ideal para pruebas rápidas.

### Pipelines Manuales
- **`docker-build`**: Build imagen (usa `Dockerfile`); vars: `APP_NAME`, `DEV_IMAGE_TAG`/`PROD_IMAGE_TAG`.
- **`docker-ecr`**: Build + push ECR; usa OIDC o `AWS_*`.
- **`jira-comment`**: Detecta/comenta JIRA; vars: `JIRA_ISSUE_KEY`, `JIRA_COMMENT`.
- **`debug-environment`**: Lista vars, submódulo, tools (docker/awscli).
- **`full-pipeline`**: End-to-end (simula prod).
- **`setup-infra`**: Solo setup (instala deps).

**Al ejecutar manual**: UI > Run Pipeline > Selecciona custom > Override vars (e.g., `IMAGE_TAG=v1.1`).

## 🛠️ MÓDULOS

### app/
- **index.js**: **Qué hace**: Servidor HTTP Node.js; responde 200 con "¡Hola Mundo desde Docker en AWS ECR!" en `/`. **Al ejecutar pipeline**: Copiado a `/app` en Docker build; probado post-deploy (e.g., `curl http://pod-ip:3000`). **Parámetros**: Usa `APP_PORT` de `.env`. **Outputs**: Log "Servidor ejecutándose...".

### kubernetes-manifests/
- **overlays/aws-eks/ingress.yaml.tpl**: **Qué hace**: Template para ALB Ingress; annotations para internet-facing, SSL redirect, `/health` check, `CERTIFICATE_ARN`. Rules: `${APP_NAME}.example.com` → service:80. **Al ejecutar**: En `generate-manifests`, envsubst usa `PROD_*` → YAML aplicado en EKS deploy.
- **overlays/rancher-local/ingress.yaml.tpl**: **Qué hace**: NGINX Ingress; rewrite `/`, no SSL; rules: `${APP_NAME}.local`. **Al ejecutar**: Usa `DEV_*` para dev deploy.

### Scripts y Herramientas
- **create.sh**: **Qué hace**: Crea estructura (`mkdir app kubernetes-manifests/overlays/*; touch index.js Dockerfile`). **Al ejecutar**: Opcional pre-pipeline; inicializa repo.
- **Dockerfile**: **Qué hace**: FROM `node:18-alpine`; COPY `app/`; EXPOSE 3000; CMD `node index.js`. **Al ejecutar**: Build step genera imagen; cache layers para speed.

### Pipelines Bitbucket
- **bitbucket-pipelines_old.yml**: **Qué hace**: Legacy; curl scripts desde repo externo; steps para JIRA, build, deploy. **Al ejecutar**: Fallback si submódulo falla.
- **bitbucket-pipelines_submoduleworks.yml**: **Qué hace**: Debug submódulo; `git submodule update`, lista files, testea `detect-jira-keys.sh`. **Al ejecutar**: Verifica integración; logs en UI.
- **bitbucket-pipelines.yml**: **Qué hace**: Principal; services (docker), anchors (&load-env), oidc; artefacts (logs, manifests). **Al ejecutar**: Trigger → steps secuenciales; traps en `error-handling.sh`.

## 🔄 Flujos de Trabajo

### Ejecución de un Pipeline Bitbucket
**Ejemplo: Push a `main`**:
1. **Trigger**: Commit con mensaje (e.g., `JD-179: Update app`) → Bitbucket parsea `bitbucket-pipelines.yml`; crea runner (`atlassian/default-image:3` + docker service).
2. **Init Submódulo**: `git submodule update --init`; artefacto `infra-cicd-tools/**` para steps.
3. **Load Env**: `load-env.sh` lee `.env`; selecciona `PROD_*` (e.g., `PROD_K8S_NAMESPACE=prod-namespace`); exporta a `export_vars.sh`. Logs: `Loaded PROD_ENVIRONMENT=production`.
4. **Setup Prod**: `setup.sh` instala deps (awscli, kubectl, jq); configura AWS CLI con `AWS_*`. Logs: `AWS CLI configured for us-east-1`.
5. **Detect JIRA**: `detect-jira-keys.sh` grep `JD-[0-9]+` en commit; valida conexión (`check-jira-connection.sh`); ejecuta `comment-jira.sh` por key. Logs: `Commented on JD-179`.
6. **Build Docker**: `build-image.sh` usa `Dockerfile`; `docker build -t $APP_NAME:$PROD_IMAGE_TAG .`; genera `docker-image-info.txt`. Logs: `Image hola-mundo:stable built`.
7. **Push ECR**: `push-to-ecr.sh` usa OIDC; login, tag, push a `123456789012.dkr.ecr.us-east-1.amazonaws.com/mi-aplicacion:stable`. Artefacto: `ecr-push-info.txt`.
8. **Generate Manifests**: `generate-manifests.sh` procesa `kubernetes-manifests/overlays/aws-eks/*.tpl` con `envsubst` (e.g., `APP_NAME`, `EKS_CERTIFICATE_ARN`); crea `/generated/kustomization.yaml`. Artefacto: `kubernetes-manifests/**`.
9. **Deploy EKS**: `deploy-to-eks.sh` ejecuta `aws eks update-kubeconfig --name my-eks-cluster`; `kubectl apply -f generated/`; espera `rollout status` (timeout 300s). Logs: `Deployment hola-mundo applied`.
10. **Comment JIRA**: `comment-jira.sh` agrega "Deployed v1.0.0 [Build: $BITBUCKET_BUILD_NUMBER]". Logs: `JIRA comment posted`.
11. **Notify**: `logging.sh` une logs (*.log); curl webhook para Slack/JIRA; DORA metrics en Compass. Outputs: Logs/artefactos en UI.

**Para `develop`**: Usa `DEV_*` (e.g., `DEV_IMAGE_TAG=latest`); salta JIRA/ECR; deploy a Rancher con `RANCHER_*`.

**Manual (UI)**: Run Pipeline > Selecciona `full-pipeline` > Override vars (e.g., `JIRA_ISSUE_KEY=JD-180`) > Ejecuta.

#### 🟢 Development Branch (`develop`)
1. Load `.env` (`DEV_*`).
2. Init submódulo.
3. Setup dev (`setup.sh`).
4. Build Docker (`Dockerfile`).
5. Generate manifests (`rancher-local`).
6. Deploy Rancher (`deploy-to-rancher.sh`).
7. Notify (logs en UI).

#### 🔴 Production Branch (`main`)
1. Load `.env` (`PROD_*`).
2. Init submódulo.
3. Setup prod.
4. Detect JIRA.
5. Build Docker.
6. Push ECR.
7. Generate manifests (`aws-eks`).
8. Deploy EKS.
9. Comment JIRA.
10. Notify.

## 🚀 GUÍA DE IMPLEMENTACIÓN RÁPIDA

1. **Inicialización**:
   ```bash
   git clone <repo> && cd app-source-code
   ./create.sh  # Crea app/, kubernetes-manifests/
   git submodule update --init  # Carga infra-cicd-tools
   cp .env.example .env && vim .env  # Edita con valores de tu entorno
   ```

2. **Editar .env**:
   - Actualiza `JIRA_BASE_URL`, `APP_NAME`, `DOMAIN`.
   - Configura `DEV_*` (e.g., `DEV_DB_HOST=dev-db.mi-empresa.com`).
   - Configura `PROD_*` (e.g., `PROD_K8S_REPLICAS=5`).
   - No incluyas `AWS_*`, `JIRA_API_TOKEN` (usa Bitbucket).

3. **Bitbucket Setup**:
   - **Repository Settings > Variables**: Agrega `AWS_ACCESS_KEY_ID`, `JIRA_API_TOKEN`, etc. (Secured).
   - Habilita Pipelines; commit `.env` (sin secrets) y `bitbucket-pipelines.yml`.

4. **Primer Deploy**:
   ```bash
   git add . && git commit -m "JD-179: Initial setup" && git push origin main
   # O manual: UI > Run > full-pipeline
   ```

5. **Verificación**:
   ```bash
   kubectl get pods -n prod-namespace -l app=hola-mundo  # Pods running
   kubectl get ingress -n prod-namespace  # ALB endpoint
   aws ecr describe-images --repository-name mi-aplicacion  # Imagen en ECR
   # En JIRA: Chequea comment en JD-179
   ```

**Checklist 2025**:
- [ ] Configura OIDC para AWS.
- [ ] Habilita DORA en Jira Compass.

## 📊 Monitoreo y Métricas

- **Bitbucket**: Logs en UI (downloadable); status verde/rojo por step.
- **JIRA**: Comments auto en issues; DORA metrics en Compass (e.g., Deployment Frequency >1/day).
- **AWS ECR**: `aws ecr describe-images` para imágenes; habilita scanning para vulns.
- **Kubernetes**: `kubectl top pods` para CPU/mem; Prometheus para HPA.
- **CloudWatch**: Logs app via EKS; ALB access logs.

**Ejemplo DORA**: Compass query: "Lead Time = time from commit to deploy".

## 🔧 Mejores Prácticas y Actualizaciones 2025

- **Seguridad**: OIDC para AWS; scan imágenes con `pipe: atlassian/aws-ecr-push`.
- **Performance**: Concurrency Groups en YAML (`concurrency: prod-deploy`); cache Docker en steps.
- **JIRA**: "Link Issues" obligatorio (Nov 2025); usa GraphQL para comments complejos.
- **Escalabilidad**: Blue-green deploys con `pipe: atlassian/kubernetes-deploy`.
- **Tendencias 2025**: ARM runners en Bitbucket; ArgoCD para GitOps post-deploy.

**Checklist**:
- [ ] Usa Pipes para 80% tasks.
- [ ] Monitorea DORA en Compass.
- [ ] Rota `JIRA_API_TOKEN` cada 90 días.

## ❌ Solución de Problemas Avanzada

- **Pipeline Failed**: Chequea logs en UI; run `debug-environment` para vars/submódulo.
- **Timeout**: Aumenta `max-time: 10m` en YAML; usa cache (`caches: - docker`).
- **JIRA Link Error (Nov 2025)**: Grant "Link Issues" en project permissions.
- **ECR Push Slow**: Habilita ECR replication; usa región cercana.
- **K8s Rollout Stuck**: `kubectl rollout undo deployment/hola-mundo`; `kubectl describe pod`.

## 📞 SOPORTE Y TROUBLESHOOTING

### Logs de Depuración
```bash
# Pipeline: UI > Pipelines > Download logs
# App: kubectl logs -f deployment/hola-mundo -n prod-namespace
# Build: docker logs <container-id> (local)
# Vars: Run debug-environment; cat export_vars.sh
# JIRA: curl -u $JIRA_USERNAME:$JIRA_API_TOKEN $JIRA_BASE_URL/rest/api/3/myself
```

### Enlaces Útiles
- [Bitbucket Pipelines](https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/) (Concurrency Groups 2025).
- [AWS EKS OIDC](https://docs.aws.amazon.com/eks/latest/userguide/oidc.html).
- [JIRA API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/) (Link Issues Nov 2025).
- [Kubernetes](https://kubernetes.io/docs/home/) (v1.31+).

## 📝 LICENCIA

MIT License. Cumple con políticas Atlassian/AWS.

## 🤝 CONTRIBUCIONES

Fork/PR con Conventional Commits (`feat:`, `fix:`).

## 📧 SOPORTE

- **Técnico**: Abre issue con logs/repro steps.
- **Features**: Describe use case en issue.
- **Comunidad**: [Atlassian Community](https://community.atlassian.com/).

## 🔄 Changelog

### v1.0 (Septiembre 2025)
- ✅ Concurrency Groups, OIDC, DORA Metrics.
- ✅ Pipes para deploys K8s.
- ✅ .env con selección por ambiente.

**¡Edita .env, ejecuta tu pipeline y despliega! 🚀**