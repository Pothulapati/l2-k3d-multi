# Enable Tracing for applications in dev
kubectl --context k3d-dev -n emojivoto set env --all deploy OC_AGENT_HOST=linkerd-collector.linkerd:55678
kubectl --context k3d-dev -n emojivoto rollout status deploy/web
kubectl --context k3d-dev -n emojivoto patch deploy/web deploy/vote-bot  -p '
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled
        config.linkerd.io/trace-collector: linkerd-collector.linkerd:55678
        config.alpha.linkerd.io/trace-collector-service-account: linkerd-collector
'

# Enable Tracing in east
kubectl --context k3d-east -n emojivoto set env --all deploy OC_AGENT_HOST=linkerd-collector-dev.linkerd:55678
kubectl --context k3d-east -n emojivoto rollout status deploy/voting
kubectl --context k3d-east -n emojivoto patch deploy/voting  -p '
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled
        config.linkerd.io/trace-collector: linkerd-collector-dev.linkerd:55678
        config.alpha.linkerd.io/trace-collector-service-account: linkerd-collector
'

# Enable Tracing in west
kubectl --context k3d-west -n emojivoto set env --all deploy OC_AGENT_HOST=linkerd-collector-dev.linkerd:55678
kubectl --context k3d-west -n emojivoto rollout status deploy/emoji
kubectl --context k3d-west -n emojivoto patch deploy/emoji  -p '
spec:
  template:
    metadata:
      annotations:
        linkerd.io/inject: enabled
        config.linkerd.io/trace-collector: linkerd-collector-dev.linkerd:55678
        config.alpha.linkerd.io/trace-collector-service-account: linkerd-collector
'