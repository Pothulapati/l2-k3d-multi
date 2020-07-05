#!/bin/sh

export ORG_DOMAIN="${ORG_DOMAIN:-k3d.example.com}"

# Generate credentials so the service-mirror
#
# Unfortunately, the credentials have the API server IP as addressed from
# localhost and not the docker network, so we have to patch that up.
fetch_credentials() {
    cluster="$1"
    # Grab the LB IP of cluster's API server & replace it in the secret blob:
    lb_ip=$(kubectl --context="k3d-$cluster" get svc -n kube-system traefik \
        -o 'go-template={{ (index .status.loadBalancer.ingress 0).ip }}')
    
    # shellcheck disable=SC2001  
    echo "$(linkerd --context="k3d-$cluster" multicluster link \
            --cluster-name="$cluster" \
            --api-server-address="https://${lb_ip}:6443")"
}

# East & West get access to dev
fetch_credentials dev | kubectl --context=k3d-west apply -n linkerd-multicluster -f -
fetch_credentials dev | kubectl --context=k3d-east apply -n linkerd-multicluster -f -

# Update Linkerd Install to install tracing components in the dev cluster
linkerd --context k3d-dev upgrade --addon-config config.yaml | kubectl --context k3d-dev apply -f -

# Export the collector service
kubectl --context k3d-dev -n linkerd get svc linkerd-collector -oyaml | linkerd mc export-service - | kubectl --context k3d-dev apply -f -

# Install Emojivoto in dev
curl -sL https://run.linkerd.io/emojivoto.yml | linkerd inject - | kubectl --context k3d-dev apply -f -

# Remove voting, emoji deployments
kubectl --context k3d-dev -n emojivoto delete deploy emoji voting

for cluster in east west ; do

    # Install Emojivoto in $cluster
    curl -sL https://run.linkerd.io/emojivoto.yml | linkerd inject - | kubectl --context="k3d-$cluster" apply -f -

    # Delete web and vote-bot
    kubectl --context="k3d-$cluster" -n emojivoto delete deploy web vote-bot
    kubectl --context="k3d-$cluster" -n emojivoto delete svc web-svc

done

# Now only keep voting in east and emoji in west
kubectl --context k3d-east -n emojivoto delete deploy emoji
kubectl --context k3d-east -n emojivoto delete svc emoji-svc

kubectl --context k3d-west -n emojivoto delete deploy voting
kubectl --context k3d-west -n emojivoto delete svc voting-svc

# Export those services into dev
kubectl --context k3d-east -n emojivoto get svc voting-svc -oyaml | linkerd mc export-service - | kubectl --context k3d-east apply -f -
kubectl --context k3d-west -n emojivoto get svc emoji-svc -oyaml | linkerd mc export-service - | kubectl --context k3d-west apply -f -

# Apply trafficsplit bruh
kubectl --context k3d-dev apply -f trafficsplit.yaml