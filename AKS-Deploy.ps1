# Commands for setting up required resources in Azure and AKS
# Update the variables for your environment.
# To run lines individually in a PowerShell integrated termainal
# in VS Code, place the cursor on the line and press F8.

$resourceGroup = "[*** YOUR RESOURCE GROUP ***]"
$location =      "[*** EastUS ***]"
$aksName =       "[*** YOUR AKS NAME ***]"
$acrName =       "[*** YOUR ACR NAME ***]"
$keyVaultName =  "[*** YOUR KEY VAULT NAME ***]"
$imageName =     "aspnetapp-csi-keyvault"
# Azure Active Directory app registration client id and secret for authenticating to Key Vault
$clientID =      "[*** YOUR AAD APPCLIENT ID ***]"
$clientSecret =  "[*** YOUR AAD APPCLIENT SECRET ***]"

az login

# Create the Resource Group
az group create --name "$resourceGroup" --location "$location"

# Create and Login to the ACR
az acr create --resource-group "$resourceGroup" --name "$acrName" --sku Basic
az acr login --name "$acrName"

# Docker build, tag and push to ACR
docker build --rm --pull -f Dockerfile -t $imageName .
docker tag $imageName "$acrName.azurecr.io/$($imageName)"
docker push "$acrName.azurecr.io/$($imageName)"

# Set Key Vault policy to allow our AAD client ID permissions to read secrets
az keyvault set-policy -n "$keyVaultName" --secret-permissions get --spn "$clientID"

# (import the PFX to Key Vault as per the README.md)

# AKS - Create cluster and get credentials for kubectl
az aks create --resource-group "$resourceGroup" --name "$aksName" --node-count 2 --generate-ssh-keys --attach-acr "$acrName"
az aks get-credentials --resource-group "$resourceGroup" --name "$aksName"

# Install the CSI secret driver and provider to the kube-system namespace
helm repo add csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts
helm install csi-secrets-store csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --namespace kube-system

# Create the Kubernetes secret for Key Vault credentials
kubectl create secret generic kvcreds --from-literal "clientid=$clientID" --from-literal "clientsecret=$clientSecret"

# Create the deployment
kubectl apply -f k8s-aspnetapp-all-in-one.yaml

kubectl get pods
kubectl get services

# stop or delete the cluster when done
az aks stop --name "$aksName" --resource-group "$resourceGroup"
az aks delete --name "$aksName" --resource-group "$resourceGroup" --yes --no-wait