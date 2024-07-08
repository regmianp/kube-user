#!/bin/bash

# Current working directory
cwd=`pwd`

# Prompt for username
echo "Please type username:"
read username

# Create user and namespace
useradd $username
kubectl create namespace $username

# Prompt for password
echo "Please type $username password:"
read -s password

# Setting up password
echo $password | passwd --stdin $username
echo "---------------------------------Generating Certificates---------------------------------"
cd /home/$username
openssl genrsa -out $username.key 2048
openssl req -new -key $username.key -out $username.csr -subj "/C=NP/ST=Bagmati/L=Kathmandu/O=Thakral One Nepal/CN=$username"
openssl x509 -req -in $username.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out $username.crt -days 365

# Role selection with loop for invalid input
while true; do
  echo "---------------------------------Role Selection---------------------------------"
  echo "Do you want to assign the user the cluster-admin role or a namespace based role?"
  echo "Type '1' for cluster-admin or '2' for namespace-based role:"
  read role_choice

  if [ "$role_choice" -eq 1 ]; then
    # Create ClusterRoleBinding with cluster-admin role
    kubectl create clusterrolebinding $username-cluster-admin-binding --clusterrole=cluster-admin --user=$username
    echo "Assigned cluster-admin role to the user."
    break
  elif [ "$role_choice" -eq 2 ]; then
    # Create a namespace based Role with the specified permissions
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $username-role
  namespace: $username
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
- apiGroups: ["policy"]
  resources: ["podsecuritypolicies"]
  verbs: ["use"]
EOF

    # Create a RoleBinding to bind the custom role to the user
    echo "Creating a RoleBinding for the namespace based role."
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: $username
  name: $username-rolebinding
subjects:
- kind: User
  name: $username
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: $username-role
  apiGroup: rbac.authorization.k8s.io
EOF

    echo "Assigned role to the namespace user."
    break
  else
    echo "Invalid choice. Please type '1' for cluster-admin or '2' for namespace-based role."
  fi
done

echo "---------------------------------Creating kubeconfig File--------------------------------"
clustername=`kubectl config view | grep cluster | tail -n 1 | awk '{print $2}'`
serveripaddr=`kubectl config view | grep server | awk '{print $2}'`

kubectl --kubeconfig kube.kubeconfig config set-credentials $username --client-certificate=$username.crt --client-key=$username.key
kubectl --kubeconfig kube.kubeconfig config set-cluster $clustername --server=$serveripaddr --certificate-authority=/etc/kubernetes/pki/ca.crt
kubectl --kubeconfig kube.kubeconfig config set-context $username-context --cluster=$clustername --namespace=$username --user=$username
sed -i "/current-context/c current-context: $username-context" kube.kubeconfig
mv kube.kubeconfig config

echo "---------------------------------Copying Files---------------------------------"
# Check if .kube directory exists and remove it
if [ -d ".kube" ]; then
  rm -rf .kube
fi
mkdir .kube
mv config $username.crt $username.key .kube/
chown -R $username:$username .kube

echo "---------------------------------Setup Complete---------------------------------"

