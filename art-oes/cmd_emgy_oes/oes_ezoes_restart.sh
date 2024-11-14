#!/usr/bin/bash
#获取脚本当前路径
basepath=$(cd `dirname $0`/..; pwd)
# 切换上一级目录
cd $basepath
#用户和端口
oes_user=$(grep ssh_user automatic.yml|awk -F' ' '{print $2}')
mon_user=$(grep mon_user automatic.yml|awk -F' ' '{print $2}')
ssh_port="22"
#获取当前时间-YYYYMMDD
nowdate=$(date +%Y%m%d)
#获取主备仲裁的IP地址
master_ip=$(awk -F'[: "]+' '/master_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
follow_ip=$(awk -F'[: "]+' '/follow_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
arbiter_ip=$(awk -F'[: "]+' '/arbiter_host/{ print $2 }' automatic.yml| awk -F'[# ]+' 'NR==1{ print $1 }')
#执行脚本
echo "修改oes主机下的system.conf文件,禁用报盘主机，启用报盘备机,重启报盘子进程"
echo "ssh -t -t -p $ssh_port $oes_user@$master_ip \"cd /home/$oes_user/host_01/oes/conf/;sed -i.$nowdate.bak 's/^oiw.0.enable = .*/oiw.0.enable = no/g' system.conf;sed -i 's/^oiw.1.enable = .*/oiw.1.enable = yes/g' system.conf;\""
ssh -t -t -p $ssh_port $oes_user@$master_ip "cd /home/$oes_user/host_01/oes/conf/;sed -i.$nowdate.bak 's/^oiw.0.enable = .*/oiw.0.enable = no/g' system.conf;sed -i 's/^oiw.1.enable = .*/oiw.1.enable = yes/g' system.conf;"
echo "ssh -t -t -p $ssh_port $oes_user@$master_ip \"cd /home/$oes_user/host_01/oes/bin;./ezoes_declarer stop;./ezoes_declarer start;\""
ssh -t -t -p $ssh_port $oes_user@$master_ip "cd /home/$oes_user/host_01/oes/bin;./ezoes_declarer stop;./ezoes_declarer start;"
