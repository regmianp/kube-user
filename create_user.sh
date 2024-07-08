#!/bin/bash
# Current working directory
cwd=`pwd`

#Create User and Namespace
echo "please type username"
read username

# Create user and namespace
useradd $username
kubectl create namespace $username

# Prompt for password

echo "please type $username password"
read password

#setting up password
echo $password | passwd --stdin $username
echo ""---------------------------------Generating Certificates"---------------------------------"
cd /home/$username
openssl genrsa -out $username.key 2048
openssl req -new -key $username.key -out $username.csr -subj "/C-NP/ST=Bagmati/L=Kathmandu/O=Thakral One Nepal/CN=$username"
openssl x509 -req -in $username.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out $username.crt -days 365
kubectl create clusterrolebinding $username-cluster-admin-binding --clusterrole=cluster-admin --user=$username



echo "---------------------------------Role Selection---------------------------------"
echo "Do you want to assign the user the cluster-admin role or a custom role?"
echo "Type '1' for cluster-admin or '2' for custom role:"
read role_choice

if [ "$role_choice" -eq 1 ]; then
  # Create ClusterRoleBinding with cluster-admin role
  kubectl create clusterrolebinding $username-cluster-admin-binding --clusterrole=cluster-admin --user=$username
  echo "Assigned cluster-admin role to the user."
else
  # Prompt for custom role permissions
  echo "Creating a custom role with namespace-specific permissions."
  echo "Please enter the API groups (comma-separated, leave blank for core API group):"
  read api_groups
  echo "Please enter the resources (comma-separated):"
  read resources
  echo "Please enter the verbs (comma-separated):"
  read verbs

  # Create a custom Role with the specified permissions
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $username
  name: $username-role
rules:
- apiGroups: [${api_groups}]
  resources: [${resources}]
  verbs: [${verbs}]
EOF

  # Create a RoleBinding to bind the custom role to the user
  echo "Creating a RoleBinding for the custom role."
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

  echo "Assigned custom role to the user."
fi


echo "---------------------------------Creating kubeconfig File--------------------------------"
clustername=`kubectl config view | grep cluster | tail -n 1 | awk '{print $2}'`
serveripaddr=`kubectl config view |grep server|awk '{print $2}'`

kubectl --kubeconfig kube.kubeconfig config set-credentials $username --client-certificate=$username.crt --client-key=$username.key
kubectl --kubeconfig kube.kubeconfig config set-cluster $clustername --server=$serveripaddr --certificate-authority=/etc/kubernetes/pki/ca.crt
kubectl --kubeconfig kube.kubeconfig config set-context $username-context --cluster=$clustername --namespace=$username --user=$username
sed -i "/current-context/c current-context: $username-context" kube.kubeconfig
mv kube.kubeconfig config

echo "-------------------- Copying Files --------------------------"
mkdir .kube
mv config $username.crt $username.key .kube/
chown -R $username:$username .kube#!/bin/bash
cwd=`pwd`

#Create User and Namespace
echo "Please type username:"
read username
useradd $username
kubectl create namespace $username

echo "Please type password for $username:"
read password

#setting up password
echo $password | passwd --stdin $username
echo ""---------------------------------Generating Certificates"---------------------------------"
cd /home/$username
openssl genrsa -out $username.key 2048
openssl req -new -key $username.key -out $username.csr -subj "/C-NP/ST=Bagmati/L=Kathmandu/O=Thakral One Nepal/CN=$username"
openssl x509 -req -in $username.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out $username.crt -days 365
kubectl create clusterrolebinding $username-cluster-admin-binding --clusterrole=cluster-admin --user=$username


echo "---------------------------------Creating kubeconfig File--------------------------------"
clustername=`kubectl config view | grep cluster | tail -n 1 | awk '{print $2}'`
serveripaddr=`kubectl config view |grep server|awk '{print $2}'`

kubectl --kubeconfig kube.kubeconfig config set-credentials $username --client-certificate=$username.crt --client-key=$username.key
kubectl --kubeconfig kube.kubeconfig config set-cluster $clustername --server=$serveripaddr --certificate-authority=/etc/kubernetes/pki/ca.crt
kubectl --kubeconfig kube.kubeconfig config set-context $username-context --cluster=$clustername --namespace=$username --user=$username
sed -i "/current-context/c current-context: $username-context" kube.kubeconfig
mv kube.kubeconfig config

echo "-------------------- Copying Files --------------------------"
mkdir .kube
mv config $username.crt $username.key .kube/
chown -R $username:$username .kube
