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
