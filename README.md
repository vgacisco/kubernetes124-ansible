# kubernetes124-ansible
这个ansible剧本用来安装 高可用k8s,版本1.24.3,使用方式
1 切到master分支
2. 按role/bin/README中说明 下载并解压软件
3.回主目录配置hosts文件并给hosts文件中所有主机配置网络及做免密
4.在主目录运行 ansible-playbook create-certs.yaml && ansible-playbook k8s-install.yaml 等待完成

说明：
    算了太晚了下次写。
