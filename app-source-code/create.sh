#!/bin/bash

# Este script crea una estructura de directorios para un proyecto de código fuente.

# Directorio base
base_dir="."

# Crear la estructura principal
mkdir -p "$base_dir"
touch "$base_dir/README.md"
touch "$base_dir/Dockerfile"
touch "$base_dir/package.json"
touch "$base_dir/.env.example"
touch "$base_dir/bitbucket-pipelines.yml"

# Crear el directorio 'app'
mkdir -p "$base_dir/app"
touch "$base_dir/app/index.js"
touch "$base_dir/app/package.json"
mkdir -p "$base_dir/app/src"

# Crear el directorio de manifiestos de Kubernetes
mkdir -p "$base_dir/kubernetes-manifests/overlays/aws-eks"
touch "$base_dir/kubernetes-manifests/overlays/aws-eks/ingress.yaml.tpl"

mkdir -p "$base_dir/kubernetes-manifests/overlays/rancher-local"
touch "$base_dir/kubernetes-manifests/overlays/rancher-local/ingress.yaml.tpl"

# Crear el directorio de configuraciones
mkdir -p "$base_dir/configs/app-specific"
touch "$base_dir/configs/app-specific/app-config.yaml"
touch "$base_dir/configs/app-specific/database-config.yaml"

echo "¡Estructura de directorios para 'app-source-code' creada exitosamente!"
