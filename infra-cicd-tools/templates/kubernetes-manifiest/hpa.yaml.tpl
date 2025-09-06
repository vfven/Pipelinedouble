apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{APP_NAME}}-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{APP_NAME}}
  minReplicas: {{MIN_REPLICAS}}
  maxReplicas: {{MAX_REPLICAS}}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80