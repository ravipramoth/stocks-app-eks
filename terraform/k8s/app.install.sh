#!/usr/bin/env bash
echo -e "\nRDS ENDPOINT: $1\n"
echo -e "\nSTEP1: updating kubeconfig...\n"

kubectl create namespace cloudacademy --dry-run=client -o yaml | kubectl apply -f - # create namespace if not exists
kubectl config set-context --current --namespace=cloudacademy

# ===========================

echo -e "\nSTEP2: setting up FQDNs...\n"

until kubectl get svc nginx-ingress-controller -n nginx-ingress >/dev/null 2>&1; do echo "waiting for nginx ingress controller service to become available..." && sleep 5; done
INGRESS_LB_FQDN=$(kubectl get svc nginx-ingress-controller -n nginx-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
echo $INGRESS_LB_FQDN

until nslookup $INGRESS_LB_FQDN >/dev/null 2>&1; do echo "waiting for DNS propagation..." && sleep 5; done
INGRESS_PUBLIC_IP=$(dig +short $INGRESS_LB_FQDN | sort | head -n1)
echo $INGRESS_PUBLIC_IP

API_PUBLIC_FQDN=cloudacademy.api.$INGRESS_PUBLIC_IP.nip.io
FRONTEND_PUBLIC_FQDN=cloudacademy.frontend.$INGRESS_PUBLIC_IP.nip.io

echo $API_PUBLIC_FQDN
echo $FRONTEND_PUBLIC_FQDN

# ===========================

echo -e "\nSTEP3: updating K8s manifest files...\n"

sed \
-e "s/RDS_AURORA_ENDPOINT/$1/g" \
-e "s/API_HOST_INGRESS_FQDN/${API_PUBLIC_FQDN}/g" \
./k8s/templates/2_api.yaml > ./k8s/manifests/2_api.yaml

sed \
-e "s/API_HOST_INGRESS_FQDN/${API_PUBLIC_FQDN}/g" \
-e "s/FRONTEND_HOST_INGRESS_FQDN/${FRONTEND_PUBLIC_FQDN}/g" \
./k8s/templates/3_frontend.yaml > ./k8s/manifests/3_frontend.yaml

# ===========================

echo -e "\nSTEP4: deploying application...\n"

kubectl apply -f ./k8s/manifests/

echo -e "\ndeployment finished\n"