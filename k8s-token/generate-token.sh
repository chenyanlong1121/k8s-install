#! /bin/bash

# 获取 kubectl proxy 进程 ID
proxy_pid=$(ss -nlp | grep :8001 | awk '{print $NF}' | cut -d ',' -f 2 | awk -F '=' '{print $2}')

# 如果进程存在，则将其杀死
if [[ -n $proxy_pid ]]; then
  kill $proxy_pid
fi

#定义token
token=""

kubectl apply -f k8s-token/supconit-user.yaml && kubectl apply -f k8s-token/supconit-ClusterRoleBinding.yaml

kubectl proxy --port=8001 & 

sleep 3

echo -e "\e[32m k8s访问token是："

str=`curl 'http://127.0.0.1:8001/api/v1/namespaces/kube-system/serviceaccounts/supconit-user/token' -H "Content-Type: application/json; charset=utf-8" -X POST -d '{"kind":"TokenRequest","apiVersion":"authentication.k8s.io/v1","metadata":{"name":"supconit-user","namespace":"kube-system"},"spec":{"audiences":["https://kubernetes.default.svc.cluster.local"],"expirationSeconds":315360000}}' |grep '"token":'`

if [ -n "$str" ]; then
  token=${str%?}
fi

echo -e "\e[33m $token \e[0m"


# 获取 kubectl proxy 进程 ID
proxy_pid=$(ss -nlp | grep :8001 | awk '{print $NF}' | cut -d ',' -f 2 | awk -F '=' '{print $2}')

# 如果进程存在，则将其杀死
if [[ -n $proxy_pid ]]; then
  kill $proxy_pid
fi

