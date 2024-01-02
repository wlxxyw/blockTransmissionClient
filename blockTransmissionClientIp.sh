#!/bin/bash
# 定义 transminssion-remote地址及认证信息
remote="127.0.0.1:9091 --auth user:password"
# 循环计数
pid=/tmp/transmission.pid
# iptables chain, 拦截规则添加/清空 都只在这个chain下操作
chain=transmission
# 循环指定次数后 清空拦截规则 搭配crontab每分钟执行一次，360次就是六小时
cleanEachTimes=360 #6 hour 
# 屏蔽的客户端
clients="xunlei thunder gt0002 xl0012 xfplay dandanplay dl3760 qq"

#日志方法
function log(){
  echo `date "+%m/%d %H:%M"` $1
}

#初始化 chain
function init_chain(){
  # 如果pid文件不存在
  if [ ! -f $pid ]; then
    log "init chain"
    echo 0 > $pid
    /usr/sbin/iptables -t filter -N $chain
    /usr/sbin/ip6tables -t filter -N $chain
    /usr/sbin/iptables -t filter -I OUTPUT -j $chain
    /usr/sbin/ip6tables -t filter -I OUTPUT -j $chain
  fi
}

# 清空拦截规则
function check_clean_chain(){
  # pid 计数+1
  echo $(expr $(cat $pid) + 1) > $pid
  if [ `cat $pid` -gt $cleanEachTimes ]; then
    log "clean chain"
    /usr/sbin/iptables -t filter -F $chain
    /usr/sbin/ip6tables -t filter -F $chain
    echo 1 > $pid
  fi
}
# 添加拦截规则
function add_rule(){
  log "add block rule: $1"
  if [[ $1 =~ ":" ]];then #ipv6
    /usr/sbin/ip6tables -t filter -I $chain -d $1 -j DROP
  else # ipv4
    /usr/sbin/iptables -t filter -I $chain -d $1 -j DROP
  fi
}


init_chain
check_clean_chain
# 已存在的屏蔽规则
existRules=`/usr/sbin/iptables -nL $chain;/usr/sbin/ip6tables -nL $chain`
# 获取链接列表
ips=`/usr/bin/transmission-remote $remote -t all -ip`
for client in $clients
  do
  # 链接BT客户端列表筛选指定的客户端所在行，空格分隔并取第一个分割结果
  for ip in `echo "$ips" | grep -i $client | cut --delimiter " " --fields 1`
    do
    log "found $ip use $client BT client! ($ips)"
    if [[ $existRules =~ $ip ]]; then
      log "exist blocked ip: $ip"
    else
      add_rule $ip
    fi
  done
done
