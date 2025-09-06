apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{APP_NAME}}-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: "{{APP_NAME}}.local"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{APP_NAME}}-service
            port:
              number: 80