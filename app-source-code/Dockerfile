# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copiar aplicación
COPY app/ .

# Instalar dependencias (si las hubiera)
# COPY package*.json ./
# RUN npm install

# Exponer puerto
EXPOSE 3000

# Comando para ejecutar la aplicación
CMD ["node", "index.js"]