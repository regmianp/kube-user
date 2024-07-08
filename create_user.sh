#!/bin/bash
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
