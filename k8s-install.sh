#!/bin/bash
#这个脚本用来自动化安装 k8s

# 检查压缩文件包，如果没有就下载

passwd="" # 这里输入远程主机root密码，用来做免密登录 
create_pem="no" #是否强制新建密钥文件，默认应该 设置为no,当为yes时就会强制刷新密钥文件 


kubernetes_url="https://dl.k8s.io/v1.24.3/kubernetes-server-linux-amd64.tar.gz"
etcd_url="https://github.com/etcd-io/etcd/releases/download/v3.4.19/etcd-v3.4.19-linux-amd64.tar.gz"
containerd_url="https://github.com/containerd/containerd/releases/download/v1.6.6/cri-containerd-cni-1.6.6-linux-amd64.tar.gz"
# 这里开始检查二进制压缩包，如果没有将会下载，但在国内很多人上github非常慢，推荐手动下载后放入./roles/bin文件夹
if ! ls -laf ./roles/bin/etcd-v*;then
    echo "etcd-*- tar file not found. download it ......"
    cd ./roles/bin
    error="false"
    wget  $etcd_url || error="true"
    if [ "true" == $error ];then
        echo "download file error.. will exit ... ..."
        exit 1
    fi
    cd ../..
    echo "done"
fi

if  ! ls -laf ./roles/bin/kubernetes-* ;then
    echo "kubernetes-*- tar file not found. download it ......"
    cd ./roles/bin
    error="false"
    wget $kubernetes_url || error="true"
    if [ "true" == $error ];then
        echo "download file error.. will exit ... ..."
        exit 1
    fi
    cd ../..
    echo "done"
fi

if  ! ls -laf ./roles/bin/cri-containerd-cni-* ;then
    echo "containerd-*- tar file not found. download it ......"
    cd ./roles/bin
    error="false"
    wget $containerd_url || error="true"
    if [ "true" == $error ];then
        echo "download file error.. will exit ... ..."
        exit 1
    fi
    cd ../..
    echo "done"
fi
#下载程序结束

#检查 expect 程序,如果 没有则会安装,最好是事先安装 上，这个就不会用到管理员权限
where_expect=$(whereis expect |awk '{print $2}')
if [ "" == $where_expect ];then
    echo "expect not search. will install it"
    error="false"
    if [ $UID -ge 0 ];then
        echo "user is root. run yum install -y  expect"
        yum install -y expect || error="true"
    else
        echo "user is not root. run  sudo install -y expect."
        sudo yum install -y expect || error="true"
    fi
    if [ $error == "true" ];then
        exit 4
    fi
    error="false"
fi


cd ./roles/bin
#准备一会要上传服务器的二进制文件  
if [ ! -d kubernetes ];then
    tarfile=$(ls -lfa |grep kubernetes |awk 'NR==1')
    tar xf $tarfile 
    cp kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kubelet,kube-scheduler,kube-proxy,kubectl} .
    rm -rf kubernetes
fi

etcd_tarfile=$(ls -laf |grep etcd- |awk 'NR==1')
etcd_dir_name=$(echo $etcd_tarfile| grep -o 'etcd-v[0-9].[0-9]\{1,2\}.[0-9]\{1,2\}-linux-amd64')
# echo $etcd_tarfile
# echo $etcd_dir_name

if [ ! -d $etcd_dir_name ];then
    tar xf $etcd_tarfile
    cp $etcd_dir_name/etcd .
    rm -rf $etcd_dir_name
fi
cd ../..


# 给所有主机做免密登录 
# 如果出错以错误码3退出
for host in `cat ./hosts |grep host_name|awk '{print $1}'|sort -u`;do
       if [ ! -f ~/.ssh/id_rsa ];then
           ssh-keygen -t rsa -N "" -f  ~/.ssh/id_rsa
       fi



       ssh-keygen -R $host
       #sshpass -p $pass ssh-copy-id root@$host || erro=1
       error="false"
       expect -c "
           spawn ssh-copy-id root@$host
               expect {
                   "*yes/no*" { send \"yes\r\"; exp_continue }
                   "*assword*" { send \"$passwd\r\" }
               }
               expect eof
               " || error="true"


       if [ $error == "true" ];then
           echo "login error" 
           exit 3
           #echo -n "host $host not ssh-copy-id, are you contain[yes/no]: "
           #read ans
           #if [ "yes" != $ans];then
           #    exit 1
           #fi
       fi
done

# 生成密钥文档
export PATH=$PATH:./roles/bin

echo "now to create k8s cluster."
if [ ! -f ./roles/certs/files/kube-apiserver.pem ];then
    echo "no find kube-apiserver.pem. create pem now"
    ansible-playbook create-certs.yaml
else 
    if [ $create_pem == "yes" ];then
        echo "create_pem = yes ,create pem now"
         ansible-playbook create-certs.yaml
    fi
fi

# 运行ansible剧本安装 k8s
ansible-playbook k8s-install.yaml
