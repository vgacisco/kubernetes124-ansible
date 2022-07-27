#! /bin/bash

workdir=`pwd`

echo -n "Are you make no pass to server [yes/no]: "
read ansible

if [ "yes" == $ansible ];then
    echo "you say yes"
    echo -n "input your passwd: "
    read -s pass
    export pass
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
                    "*assword*" { send \"$pass\r\" }
                }
                expect eof
                " || error="true"


        if [ $error == "true" ];then
            echo "sshpass error"
            echo -n "host $host not ssh-copy-id, are you contain[yes/no]: "
            read ans
            if [ "yes" != $ans];then
                exit 1
            fi
        fi
    done

else
    echo "yes say no"

fi

export PATH=$PATH:${workdir}/roles/bin
echo -n " create now certificate for you? [yes/no]: "
read create_pem
if [ "yes" == $create_pem ];then
    ansible-playbook create-certs.yaml
fi

ansible-playbook k8s-install.yaml
