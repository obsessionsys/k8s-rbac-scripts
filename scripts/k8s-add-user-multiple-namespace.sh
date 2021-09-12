#!/bin/bash

mkdir -p ./kube-users

if [[ -z "$1" ]] ;then
  echo "Usage: $0 <Username> <Role:(deployer/developer)> <Namespace>"
  exit 1
elif [[ -z "$2" ]] ;then
  echo "Usage: $0 <Username> <Role:(deployer/developer)> <Namespace>"
  exit 1
elif [[ -z "$3" ]]; then
  echo "Usage: $0 <Username> <Role:(deployer/developer)> <Namespace>"
  exit 1
fi

_role_dev() {
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: ${namespace}
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get","describe","list","watch","exec"]
- apiGroups:
  - '*'
  resources:
  - 'pods/exec'
  - 'pods/portforward'
  - 'services/portforward'
  verbs:
  - create
EOF
}

_create_developer() {

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer
  namespace: ${namespace}
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  namespace: default
  name: ${serviceaccount}
EOF

}

_patch_developer() {

cat <<EOF | kubectl auth reconcile -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer
  namespace: ${namespace}
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    namespace: default
    name: ${serviceaccount}

EOF

}

_role_deployer() {
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployer
  namespace: ${namespace}
rules:
- apiGroups: ["apps","extensions"]
  resources: ["deployments","configmaps","pods","secrets","ingresses"]
  verbs: ["create","get","delete","list","update","edit","watch","exec","patch"]
EOF
}

_create_deployer() {
cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
  namespace: ${namespace}
roleRef:
  kind: Role
  name: deployer
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  namespace: default
  name: ${serviceaccount}
EOF
}

_patch_deployer() {
cat <<EOF | kubectl auth reconcile -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer
  namespace: ${namespace}
roleRef:
  kind: Role
  name: deployer
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  namespace: default
  name: ${serviceaccount}
EOF
}

serviceaccount=$1
userrole=$2
namespace=$3

if ! kubectl get sa ${serviceaccount} -n default ;
  then
kubectl create sa ${serviceaccount} -n default
secret=$(kubectl get sa ${serviceaccount} -n default -o json | jq -r .secrets[].name)
kubectl get secret ${secret} -n default -o json | jq -r '.data["ca.crt"]' | base64 -d > ca.crt
user_token=$(kubectl get secret ${secret} -n default -o json | jq -r '.data["token"]' | base64 -d)
c=`kubectl config current-context`
cluster_name=`kubectl config get-contexts $c | awk '{print $3}' | tail -n 1`
endpoint=`kubectl config view -o jsonpath="{.clusters[?(@.name == \"${cluster_name}\")].cluster.server}"`


# Set up the config
KUBECONFIG=kube-users/k8s-${serviceaccount}-conf kubectl config set-cluster ${cluster_name} \
    --embed-certs=true \
    --server=${endpoint} \
    --certificate-authority=./ca.crt

KUBECONFIG=kube-users/k8s-${serviceaccount}-conf kubectl config set-credentials ${serviceaccount}-${cluster_name#cluster-} --token=${user_token}
KUBECONFIG=kube-users/k8s-${serviceaccount}-conf kubectl config set-context ${serviceaccount}-${cluster_name#cluster-} \
    --cluster=${cluster_name} \
    --user=${serviceaccount}-${cluster_name#cluster-}
KUBECONFIG=kube-users/k8s-${serviceaccount}-conf kubectl config use-context ${serviceaccount}-${cluster_name#cluster-}
rm -rf ./ca.crt

else
  echo "The service account is exists"
  echo "Update permissions RBAC for ServiceAccount..."
fi
getrole_dev=$(kubectl get role -n ${namespace} | grep developer)
getrole_deploy=$(kubectl get role ${namespace} | grep deployer)
if [[ "$getrole_dev" = "" ]]; then
_role_dev
fi
if [[ "$getrole_deploy" = "" ]]; then
_role_deployer
fi


if [[ ${userrole} = "developer" ]]; then
  getrb_exists=$(kubectl get rolebinding -n ${namespace} | grep developer)
   if [[ "$getrb_exists" = "" ]]; then
    _create_developer
  else
    _patch_developer
  fi
elif [[ ${userrole} = "deployer" ]]; then
  getrb_exists=$(kubectl get rolebinding -n ${namespace} | grep deployer)
  if  [[ "$getrb_exists" = "" ]]; then
    _create_deployer
  else
    _patch_deployer
  fi
else
  echo "Usage: $0 <USERNAME> <ROLE: developer/deployer> <NAMESPACE>"
  echo "  Example: /bin/bash $0 john developer default "
  echo " The user's config files is located in ./kube-users path"
  exit 0
fi