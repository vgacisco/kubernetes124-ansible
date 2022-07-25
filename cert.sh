#!/bin/bash
echo "hello"
cd roles/certs/files

#生成 ca文件:

cfssl gencert -initca etcd-ca.json |cfssljson -bare etcd-ca
cfssl gencert -initca kubernetes-ca.json |cfssljson -bare kubernetes-ca
cfssl gencert -initca front-proxy-ca.json |cfssljson -bare front-proxy-ca


#生成 证书文件 
cfssl gencert -ca etcd-ca.pem -ca-key etcd-ca-key.pem -config config.json -profile etcd etcd-server.json |cfssljson -bare etcd-server
cfssl gencert -ca etcd-ca.pem -ca-key etcd-ca-key.pem -config config.json -profile etcd etcd-client.json |cfssljson -bare etcd-client
cfssl gencert -ca kubernetes-ca.pem -ca-key kubernetes-ca-key.pem -config config.json -profile kubernetes kube-apiserver.json |cfssljson -bare kube-apiserver
cfssl gencert -ca front-proxy-ca.pem -ca-key front-proxy-ca-key.pem -config config.json -profile kubernetes front-proxy-client.json |cfssljson -bare front-proxy-client


cfssl gencert -ca kubernetes-ca.pem -ca-key kubernetes-ca-key.pem -config config.json -profile kubernetes kube-controller-manager.json |cfssljson -bare kube-controller-manager
cfssl gencert -ca kubernetes-ca.pem -ca-key kubernetes-ca-key.pem -config config.json -profile kubernetes kube-scheduler.json |cfssljson -bare kube-scheduler
cfssl gencert -ca kubernetes-ca.pem -ca-key kubernetes-ca-key.pem -config config.json -profile kubernetes kube-proxy.json |cfssljson -bare kube-proxy
cfssl gencert -ca kubernetes-ca.pem -ca-key kubernetes-ca-key.pem -config config.json -profile kubernetes admin.json |cfssljson -bare admin

openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub

#生成kube-controller-manager.kubeconfig
for components in kube-controller-manager kube-scheduler kube-proxy admin;do
	cluster=kubernetes
	user=${components}
	ca=$(cat kubernetes-ca.pem|base64 -w 0)
	crt=$(cat ${components}.pem |base64 -w 0)
	key=$(cat ${components}-key.pem |base64 -w 0)
	context=default
	sed -e "s/_CA_/$ca/g" -e "s/_USER_/$user/g" -e "s/_CLUSTER_/$cluster/g" -e "s/_CRT_/$crt/g" -e "s/_KEY_/$key/g" -e "s/_CONTEXT_/$context/g" ../templates/kubeconfig.mode > ${components}.kubeconfig
done

ca=$(cat kubernetes-ca.pem|base64 -w 0)
key=$(head -c 16 /dev/urandom |md5sum |head -c 6)
value=$(head -c 16 /dev/urandom |md5sum |head -c 16)

sed -e "s/_KEY_/$key/g" -e "s/_VALUE_/$value/g" ../templates/bootstrap.mode > ../../setbootstrap/files/bootstrap.yaml
sed -e "s/_KEY_/$key/g" -e "s/_VALUE_/$value/g" -e "s/_CA_/$ca/g" ../templates/bootstrap.kubeconfig.mode >bootstrap.kubeconfig

ca_etcd=$(cat etcd-ca.pem|base64 -w 0)
key_etcd=$(cat etcd-client-key.pem |base64 -w 0)
crt_etcd=$(cat etcd-client.pem |base64 -w 0)

sed -e "s/__KEY_ETCD_CLIENT__/$key_etcd/g" -e "s/__CRT_ETCD_CLIENT__/$crt_etcd/g" -e "s/__CA_ETCD_CLIENT__/$ca_etcd/" ../templates/calico-etcd.yaml.mode >../../yamlinstall/templates/calico-etcd.yaml

