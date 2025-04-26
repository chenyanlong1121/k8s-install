#! /bin/sh


if [ $# != 3 ]  ; then
echo -e "\e[33m USAGE: sh reset-worker-before-join.sh   worker服务器IP  worker服务器端口  worker服务器密码 \e[0m"
echo -e "\e[33m e.g.: sh reset-worker-before-join.sh 172.17.1.214 10022 supcon@it123,./ \e[0m"
echo -e "\e[33m 重置工作节点后再加入集群\e[0m"
exit 1;
fi


WORKER_IP=$1
WORKER_PORT=$2
WORKER_PASS=$3

#打印nfs、harbor信息
echo -e "\e[32m 工作节点的IP：${WORKER_IP} \e[0m"
echo -e "\e[32m 工作节点的端口：${WORKER_PORT} \e[0m"
echo -e "\e[32m 工作节点的密码：${WORKER_PASS} \e[0m"


read -r -p "请确认,是否继续? [Y/n] " input
case $input in
    [yY][eE][sS]|[yY])
        
echo -e "\e[34m *************一、设置服务器信息**************  \e[0m"

#安装tar:判断是否安装
rpm -q sshpass
if [ $(echo $?) -gt 0 ];then
  echo -e "\e[32m 开始安装sshpass \e[0m"
  rpm -vih sshpass*.rpm  --force --nodeps
  echo -e "\e[32m 成功安装sshpass命令  \e[0m"
else
  echo -e "\e[33m 已安装sshpass命令，跳过安装 \e[0m"
fi

#获取join命令
JOIN_COMMAND=`kubeadm token create --print-join-command`

#重置节点 
echo -e "\e[32m 重置节点确认：\e[0m"
sshpass -p $WORKER_PASS ssh -o StrictHostKeyChecking=no -p $WORKER_PORT root@$WORKER_IP " kubeadm reset"
sleep 20
kubectl get nodes
#重新加入
sshpass -p $WORKER_PASS ssh -o StrictHostKeyChecking=no -p $WORKER_PORT root@$WORKER_IP " ${JOIN_COMMAND} "
#打印节点信息
echo -e "\e[32m 打印节点信息\e[0m"
kubectl get nodes


    ;;
    [nN][oO]|[nN])
        echo -e "\e[33m 退出安装 \e[0m"
        ;;

    *)
        echo -e "\e[31m 无效选项 \e[0m"
        exit 1
        ;;
esac 
