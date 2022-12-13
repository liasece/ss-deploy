set -e

PORT1=$1
PASSWD1=$2

PORT2=$3
PASSWD2=$4

yum update -y
yum install -y vim wget git epel-release gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel net-tools libssl-dev openssl openssl-devel lsof
yum -y groupinstall "Development Tools"

# 安装依赖
wget https://github.com/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz
tar xf libsodium-1.0.18.tar.gz && cd libsodium-1.0.18
./configure && make -j2 && make install
echo /usr/local/lib >/etc/ld.so.conf.d/usr_local_lib.conf
ldconfig
cd ..

# 配置
echo '
* soft nofile 409600
* hard nofile 409600
' >>/etc/security/limits.conf
ulimit -n 409600

work_path=$(dirname $0)

# copy bin
cp $work_path/bin/v2ray-plugin_linux_amd64 /usr/local/bin/v2ray-plugin_linux_amd64
cp $work_path/bin/ss-server /usr/local/bin/ss-server

# # 优化
# echo '
# net.ipv4.tcp_congestion_control = bbr
# net.core.default_qdisc = fq
# net.ipv4.tcp_fastopen = 3
# net.core.rmem_max = 12582912
# #设置内核接收Socket的最大长度(bytes)
# net.core.wmem_max = 12582912
# #设置内核发送Socket的最大长度(bytes)
# net.ipv4.tcp_rmem = 10240 87380 12582912
# #设置TCP Socket接收长度的最小值，预留值，最大值(bytes)
# net.ipv4.tcp_rmem = 10240 87380 12582912
# #设置TCP Socket发送长度的最小值，预留值，最大值(bytes)
# net.ipv4.ip_forward = 1
# #开启所有网络设备的IPv4流量转发，用于支持IPv4的正常访问
# net.ipv4.tcp_syncookies = 1
# #开启SYN Cookie，用于防范SYN队列溢出后可能收到的攻击
# net.ipv4.tcp_tw_reuse = 1
# #允许将等待中的Socket重新用于新的TCP连接，提高TCP性能
# net.ipv4.tcp_tw_recycle = 0
# #禁止将等待中的Socket快速回收，提高TCP的稳定性
# net.ipv4.tcp_fin_timeout = 30
# #设置客户端断开Sockets连接后TCP在FIN等待状态的实际(s)，保证性能
# net.ipv4.tcp_keepalive_time = 1200
# #设置TCP发送keepalive数据包的频率，影响TCP链接保留时间(s)，保证性能
# net.ipv4.tcp_mtu_probing = 1
# #开启TCP层的MTU主动探测，提高网络速度
# net.ipv4.conf.all.accept_source_route = 1
# net.ipv4.conf.default.accept_source_route = 1
# #允许接收IPv4环境下带有路由信息的数据包，保证安全性
# net.ipv4.conf.all.accept_redirects = 0
# net.ipv4.conf.default.accept_redirects = 0
# #拒绝接收来自IPv4的ICMP重定向消息，保证安全性
# net.ipv4.conf.all.send_redirects = 0
# net.ipv4.conf.default.send_redirects = 0
# net.ipv4.conf.lo.send_redirects = 0
# #禁止发送在IPv4下的ICMP重定向消息，保证安全性
# net.ipv4.conf.all.rp_filter = 0
# net.ipv4.conf.default.rp_filter = 0
# net.ipv4.conf.lo.rp_filter = 0
# #关闭反向路径回溯进行源地址验证(RFC1812)，提高性能
# net.ipv4.icmp_echo_ignore_broadcasts = 1
# #忽略所有ICMP ECHO请求的广播，保证安全性
# net.ipv4.icmp_ignore_bogus_error_responses = 1
# #忽略违背RFC1122标准的伪造广播帧，保证安全性
# net.ipv6.conf.all.accept_source_route = 1
# net.ipv6.conf.default.accept_source_route = 1
# #允许接收IPv6环境下带有路由信息的数据包，保证安全性
# net.ipv6.conf.all.accept_redirects = 0
# net.ipv6.conf.default.accept_redirects = 0
# #禁止接收来自IPv6下的ICMPv6重定向消息，保证安全性
# net.ipv6.conf.all.autoconf = 1
# #开启自动设定本地连接地址，用于支持IPv6地址的正常分配
# net.ipv6.conf.all.forwarding = 1
# #开启所有网络设备的IPv6流量转发，用于支持IPv6的正常访问
# fs.file-max = 1024000
# #系统所有进程一共可以打开的句柄数(bytes)
# kernel.msgmnb = 65536
# #进程通讯消息队列的最大字节数(bytes)
# kernel.msgmax = 65536
# #进程通讯消息队列单条数据最大的长度(bytes)
# kernel.shmmax = 68719476736
# #内核允许的最大共享内存大小(bytes)
# kernel.shmall = 4294967296
# #任意时间内系统可以使用的共享内存总量(bytes)' >/etc/sysctl.conf
# echo '
# DefaultLimitNOFILE=1024:524288
# ' >>/etc/systemd/system.conf
# sysctl -e -p

# 构建ss配置文件
echo '{
    "server_port":'$PORT1',
    "password":"'$PASSWD1'",
    "timeout":600,
    "method":"chacha20-ietf-poly1305"
}' >/etc/server_config.json
echo '{
    "server_port":'$PORT2',
    "password":"'$PASSWD2'",
    "timeout":600,
    "method":"chacha20-ietf-poly1305"
}' >/etc/server_per_config.json

# 构建服务文件
echo '#!/bin/sh
[Unit]
Description=Shadowsocks
[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/ss-server -c /etc/server_config.json --plugin v2ray-plugin_linux_amd64 --plugin-opts "server"
[Install]
WantedBy=multi-user.target' >/etc/systemd/system/shadowsocks.service
echo '#!/bin/sh
[Unit]
Description=ShadowsocksPer
[Service]
TimeoutStartSec=0
ExecStart=/usr/local/bin/ss-server -c /etc/server_per_config.json --plugin v2ray-plugin_linux_amd64 --plugin-opts "server"
[Install]
WantedBy=multi-user.target' >/etc/systemd/system/ssper.service
systemctl daemon-reload

# 开启防火墙对应端口
systemctl enable firewalld.service
systemctl restart firewalld.service
firewall-cmd --zone=public --add-port=$PORT1/tcp --permanent
firewall-cmd --zone=public --add-port=$PORT2/tcp --permanent
#ssh port
firewall-cmd --zone=public --add-port=10000-60000/tcp --permanent
systemctl restart firewalld.service

sleep 2

# set iptables
iptables -A OUTPUT -p tcp --dport 25 -j LOG --log-prefix "IPTABLES SMTP: "
iptables -A OUTPUT -p tcp --dport 25 -j DROP
iptables -I FORWARD -p tcp --dport 25 -j DROP
iptables -A OUTPUT -p tcp --dport 465 -j LOG --log-prefix "IPTABLES SMTPS: "
iptables -A OUTPUT -p tcp --dport 465 -j DROP
iptables -I FORWARD -p tcp --dport 465 -j DROP
iptables -A OUTPUT -p tcp --dport 578 -j LOG --log-prefix "IPTABLES SMTPS: "
iptables -A OUTPUT -p tcp --dport 578 -j DROP
iptables -I FORWARD -p tcp --dport 578 -j DROP
iptables -A OUTPUT -p tcp --dport 2525 -j LOG --log-prefix "IPTABLES SMTPS: "
iptables -A OUTPUT -p tcp --dport 2525 -j DROP
iptables -I FORWARD -p tcp --dport 2525 -j DROP
service iptables save

# 设置系统控制项
systemctl enable shadowsocks
systemctl restart shadowsocks
systemctl enable ssper
systemctl restart ssper
systemctl status shadowsocks -l
systemctl status ssper -l
