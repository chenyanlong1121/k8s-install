#! /bin/bash

echo -e "\e[32mK8s集群开始备份 \e[0m"

#备份时间
BACKUP_DATE=$(date +"%Y-%m-%d-%H-%M-%S")
echo -e "\e[32m备份时间为：$BACKUP_DATE \e[0m"


#定义k8s-cluster备份目录
K8S_CLUSTER_BACKUPS_DIR=/k8s-cluster-backups
echo -e "\e[32mk8s-cluster备份目录：$K8S_CLUSTER_BACKUPS_DIR \e[m"

#判断是否安装etcddctl命令
ls /usr/bin/ /usr/local/bin |grep etcdctl
if [ $(echo $?) -gt 0 ];then
  echo -e "\e[31m未找到etcdctl命令\e[0m"
else
  echo -e "\e[33m已安装etcdctl命令，请联系管理员 \e[0m"
fi

echo -e "\e[32m打印etcdctl版本信息 \e[0m"
etcdctl -version

#etcd备份命令
mkdir -p $K8S_CLUSTER_BACKUPS_DIR
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save ${K8S_CLUSTER_BACKUPS_DIR}/k8s-etcd-snapshot-${BACKUP_DATE}.db

#etcd备份验证
echo -e "\e[32m验证etcd备份文件的有效性 \e[0m"
ETCDCTL_API=3 etcdctl --write-out=table snapshot status ${K8S_CLUSTER_BACKUPS_DIR}/k8s-etcd-snapshot-${BACKUP_DATE}.db

if [ $(echo $?) -gt 0 ];then
  echo -e "\e[31metcd备份文件无效\e[0m"  
else
  echo -e "\e[32metcd备份文件有效\e[0m"
fi

#备份kubernetes文件
echo -e "\e[32m备份K8s集群文件\e[0m"
cd /etc
tar -czvf ${K8S_CLUSTER_BACKUPS_DIR}/k8s-kubernetes-backups-${BACKUP_DATE}.tar.gz  kubernetes 1>/dev/null 
cd /root
tar -czvf ${K8S_CLUSTER_BACKUPS_DIR}/k8s-kube-backups-${BACKUP_DATE}.tar.gz  .kube 1>/dev/null
cd ${K8S_CLUSTER_BACKUPS_DIR}

echo -e "\e[32m查看备份文件: \e[0m"
ls -l



# find backup file 
readarray -t backup_files<<<"$(find ${K8S_CLUSTER_BACKUPS_DIR}/k8s-* 2>/dev/null)"
if test -z ${backup_files[0]}
then
    echo -e "\e33m备份文件不存在\e[0m"
    echo -e "\e[32mK8s集群完成备份 \e[0m"
    exit 1;
else
    echo -e "\e[32m备份文件已存在\e[0m"
fi


#find  backup file
if [[ ${#backup_files[@]} -gt 3 ]]
then
    # # delete old backup file
    find ${K8S_CLUSTER_BACKUPS_DIR}/k8s-* -ctime +15 -type f -exec rm {} \;
    if [ $? -eq 0 ]
    then
        echo -e '\e[32m删除过期备份文件成功 \e[0m'
    else
        echo -e '\e[31m删除过期备份文件失败 \e[0m'
    fi
else
    echo -e "\e[33m未找到过期文件 \e[0m"
fi




echo -e "\e[32mK8s集群完成备份 \e[0m"

