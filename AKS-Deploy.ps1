# Commands for setting up required resources in Azure and AKS
# Update the variables for your environment.
# To run lines individually in a PowerShell integrated termainal
# in VS Code, place the cursor on the line and press F8.

$resourceGroup = "[*** YOUR RESOURCE GROUP ***]"
$location =      "[*** EastUS ***]"
$aksName =       "[*** YOUR AKS NAME ***]"
$acrName =       "[*** YOUR ACR NAME ***]"
$keyVaultName =  "[*** YOUR KEY VAULT NAME ***]"
$clientID =      "[*** YOUR AAD APPCLIENT ID ***]"
$clientSecret =  "[*** YOUR AAD APPCLIENT SECRET ***]"

az login

# Resource Group
az group create --name "$resourceGroup" --location "$location"

# ACR
az acr create --resource-group "$resourceGroup" --name "$acrName" --sku Basic
az acr login --name "$acrName"

# Docker build
docker build --rm --pull -f Dockerfile -t aspnet-keyvault .

# Tag and push the image to the ACR
docker tag aspnet-keyvault "$acrName.azurecr.io/aspnet-keyvault"
docker push "$acrName.azurecr.io/aspnet-keyvault"

# Key Vault
az keyvault set-policy -n "$keyVaultName" --secret-permissions get --spn "$clientID"

# (import the PFX as per the README.md)

# AKS
az aks create --resource-group "$resourceGroup" --name "$aksName" --node-count 2 --generate-ssh-keys --attach-acr "$acrName"
az aks get-credentials --resource-group "$resourceGroup" --name "$aksName"

helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --generate-name

kubectl create secret generic kvcreds --from-literal "clientid=$clientID" --from-literal "clientsecret=$clientSecret" --type=azure/kv
kubectl apply -f k8s-aspnetapp-all-in-one.yaml
kubectl get pods
kubectl get services

# delete everything when done
#az aks delete --name "$aksName" --resource-group "$resourceGroup" --yes --no-wait