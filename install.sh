#! /bin/sh


if [ $# -lt 4 ] || [ $# -gt 5 ] ; then
echo -e "\e[33m USAGE: sh install.sh role master服务器IP  harbor服务器IP  nfs-1存储服务器IP  nfs-2存储服务器IP \e[0m"
echo -e "\e[33m e.g.: sh install.sh  master 172.17.1.58 172.17.1.74 172.17.1.67 \e[0m"
echo -e "\e[33m e.g.: sh install.sh  worker 172.17.1.58 172.17.1.74 172.17.1.67 \e[0m"
echo -e "\e[33m e.g.: sh install.sh  master 172.17.1.58 172.17.1.74 172.17.1.67  172.17.1.76\e[0m"
echo -e "\e[33m e.g.: sh install.sh  worker 172.17.1.58 172.17.1.74 172.17.1.67  172.17.1.76\e[0m"
echo -e "\e[33m role分为master、worker\e[0m"
echo -e "\e[33m nfs可以是一个，也可以是2个，会生成对应的nfs-1.supcoint.com、nfs-2.supconit.com的域名 \e[0m"
exit 1;
fi


#识别nfs、harbor
ROLE_NAME=$1
MASTER_IP=$2
HARBOR_IP=$3
NFS_IP_1=$4
NFS_IP_2=$5

#打印nfs、harbor信息
echo -e "\e[32m 节点角色：${ROLE_NAME} \e[0m"
echo -e "\e[32m master的IP：${MASTER_IP} \e[0m"
echo -e "\e[32m harbor的IP：${HARBOR_IP} \e[0m"
echo -e "\e[32m nfs-1的IP：${NFS_IP_1}，对应的域名为：nfs-1.supconit.com \e[0m"

if [[ ${NFS_IP_2} != "" ]]
then
  echo -e "\e[32m nfs-2的IP：${NFS_IP_2}，对应的域名为：nfs-2.supconit.com \e[0m"
fi



read -r -p "请确认,是否继续? [Y/n] " input
case $input in
    [yY][eE][sS]|[yY])
        
echo -e "\e[34m *************一、设置服务器信息**************  \e[0m"
#设置本地hosts
grep -qF '${MASTER_IP} k8s-master.supconit.com' /etc/hosts || echo ${MASTER_IP} k8s-master.supconit.com >> /etc/hosts        
grep -qF '${HARBOR_IP} docker-registry.supconit.com' /etc/hosts || echo ${HARBOR_IP} docker-registry.supconit.com >> /etc/hosts 
grep -qF '${NFS_IP_1} nfs-1.supconit.com' /etc/hosts || echo ${NFS_IP_1} nfs-1.supconit.com >> /etc/hosts 
if [[ ${NFS_IP_2} != '' ]]
then
  grep -qF '${NFS_IP_2} nfs-2.supconit.com' /etc/hosts || echo ${NFS_IP_2} nfs-2.supconit.com >> /etc/hosts
fi

#关闭防火墙、selinux
timedatectl set-timezone Asia/Shanghai
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
systemctl stop firewalld
systemctl disable firewalld

#安装tar:判断是否安装
rpm -q tar
if [ $(echo $?) -gt 0 ];then
  echo -e "\e[32m 开始安装tar \e[0m"
  rpm -vih tar/tar*.rpm  --force --nodeps
  echo -e "\e[32m 成功安装tar命令  \e[0m"
else
  echo -e "\e[33m 已安装tar命令，跳过安装 \e[0m"
fi

#设置域名解析地址
touch /etc/resolv.conf
grep -qF 'nameserver 114.114.114.114' /etc/resolv.conf || echo nameserver 114.114.114.114 >> /etc/resolv.conf

#设置保留内存
if [ -e "/etc/sysconfig/kubelet" ];then
  echo -e "\e[33m kubelet已设置保留内存 \e[0m"
else
  echo 'KUBELET_EXTRA_ARGS=--system-reserved=cpu=0.5,memory=0.5Gi --kube-reserved=cpu=0.5,memory=0.5Gi --eviction-hard=memory.available<0.5Gi --eviction-soft=memory.available<1Gi --eviction-soft-grace-period=memory.available=2m --eviction-max-pod-grace-period=30 --eviction-minimum-reclaim=memory.available=0Mi' > /etc/sysconfig/kubelet
fi


echo -e "\e[32m  ###################二、开启NFS服务####################   \e[0m"
#开启nfs服务
systemctl restart rpcbind
systemctl enable rpcbind
systemctl status rpcbind
systemctl restart nfs-server
systemctl enable nfs-server
systemctl status nfs-server
systemctl restart nfs-utils
systemctl enable nfs-utils
systemctl status nfs-utils


#解压安装文件
mkdir -p /etc/containerd && \cp config.toml /etc/containerd/ 
tar xzvf kube1.22.0.tar.gz
cd kube/shell && sh init.sh
systemctl daemon-reload && systemctl enable containerd && systemctl restart containerd

if [ ${ROLE_NAME} == "master" ];then
sleep 10
sh master.sh
echo -e  "\e[32mk8s服务启动中，等待90s\e[0m"
sleep 90
cd ../..

echo -e "\e[32m ###########打印节点信息###########\e[0m"
kubectl get nodes

#设置k8s定时备份
cp ./k8s-cluster-backups.sh /root/
chmod a+x /root/k8s-cluster-backups.sh
echo "0 2 * * 6  /root/k8s-cluster-backups.sh >> /root/k8s-cluster-backups.log 2>&1" >> /var/spool/cron/root

echo -e "\e[32m  ###################三、安装metrics并设置master不参与调度####################   \e[0m"

#master不参与调度
kubectl taint nodes $HOSTNAME node-role.kubernetes.io/master=:NoSchedule

#安装metrics
kubectl apply -f metrics.yaml

echo -e "\e[32m  ###################四、安装kuboard界面####################   \e[0m"
kubectl apply -f kuboard-v3.yaml

echo -e "\e[32m  Kuboard访问信息：   \e[0m"
echo -e "\e[32m  访问地址：MasterIP:32567   \e[0m"
echo -e "\e[32m  账号密码：admin Kuboard123   \e[0m"
kubectl get pod,svc -n kuboard
kubectl get nodes

echo -e "\e[32m  ###################五、打印K8s集群token####################   \e[0m"
sh k8s-token/generate-token.sh

echo -e "\e[32m  ###################六、打印集群证书时间token####################   \e[0m"
kubeadm certs check-expiration

#修改node-port端口范围
sed -i '/- --secure-port=6443/a\    - --service-node-port-range=0-65535' /etc/kubernetes/manifests/kube-apiserver.yaml
apiserver_pods=$(kubectl get pods --selector=component=kube-apiserver -n kube-system --output=jsonpath={.items..metadata.name})
kubectl delete pod $apiserver_pods -n kube-system
echo "k8s服务更新中，等待60s"
sleep 60

echo -e "\e[32m##################################################   \e[0m"
echo -e "\e[32m 当前时间为：$(date +%Y-%m-%d\ %H:%M:%S)\e[0m"
kubeadm token create --print-join-command
echo -e "\e[32m 工作节点加入集群的命令有效时间为2个小时：可通过此命令重新获取：kubeadm token create --print-join-command \e[0m"
echo -e "\e[32m##################################################   \e[0m"


else 
 
cd ../..  

fi

echo -e "\e[32m  ###################部署完成####################   \e[0m"


    ;;
    [nN][oO]|[nN])
        echo -e "\e[33m 退出安装 \e[0m"
        ;;

    *)
        echo -e "\e[31m 无效选项 \e[0m"
        exit 1
        ;;
esac

