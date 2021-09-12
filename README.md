# Kubernetes RBAC: Service Account use one role in multiple namespaces
To provide access to certain Kubernetes cluster namespaces to developers is a part of any DevOps Engineer job.

Basic initial requirements for creating Service Account accesses:

* Create user(ServiceAccount) in one namespace - default

* No default, kube-system etc. accesses to namespaces for users

* The user must have access to the specified namespace with the possibility to view all Pods and their logs and without removal options

* The user must have access to basic Kubernetes objects such as Ingress, Services, PVC

* The user should be enabled to portforward, exec for Service and Pods

* The opportunity to add (update) user's access to other namespaces

* Automatically create a kubeconfig for the user

## Script
Due to the fact that RBAC is quite difficult to understand and the rights management system is too complicated, a simple bash script was written to implement the above-described needs.

## Script use

The script must connect to Kubernetes with full rights:

```
/bin/bash ./scripts/k8s-add-user-multiple-namespace.sh john developer staging
```

**where**:

**john** - username - ServiceAccount

**developer** - developer role with access to namespace
**staging** - namespace to which we provide access to the developer john (the namespace must already be created in the Kubernetes cluster)
This script provides the opportunity to create 2 roles: `developer` and `deployer`. Deployer role provides access to the user for the purpose of deployment to the specified namespace.

## User's Kubeconfig

User's Kubeconfig will be created and located in the directory `./kube-users` in the current script launch directory
The structure of the name of the created configuration file kubeconfig will be as follows: `k8s-USERNAME-conf`
This way, it is possible to transfer the file to the developer with his name for access to the Kubernetes cluster.


## Testing
The command that allows to view all pods in namespace: `staging`

```
KUBECONFIG=k8s-john-conf kubectl get pods -n staging
```

And if to try getting all pods in all namespaces:

```
KUBECONFIG=k8s-john-conf kubectl get pods -A
```

then we'll get an error:

```
>$ Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:john" cannot list resource "pods" in API group "" at the cluster scope
```