#!/usr/bin/env bash
echo=echo
for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue

    if ! $cmd -e "" | grep -qE '^-e'; then
        echo=$cmd
        break
    fi
done

CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"

OUT_ALERT() {
    echo -e "${CYELLOW}$1${CEND}"
}

OUT_ERROR() {
    echo -e "${CRED}$1${CEND}"
}

OUT_INFO() {
    echo -e "${CCYAN}$1${CEND}"
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -q -E -i "debian|raspbian"; then
    release="debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -q -E -i "raspbian|debian"; then
    release="debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
    release="centos"
else
    OUT_ERROR "[错误] 不支持的操作系统！"
    exit 1
fi

#OUT_ALERT "[信息] 更新系统中！"
#if [[ ${release} == "centos" ]]; then
#    yum makecache
#    yum install epel-release -y
#
#    yum update -y
#else
#    apt update
#    apt dist-upgrade -y
#    apt autoremove --purge -y
#fi

OUT_ALERT "[信息] 优化性能中！"
if [[ ${release} == "centos" ]]; then
    yum remove tuned --autoremove -y
else
    apt remove tuned --autoremove -y
    apt purge irqbalance --autoremove -y
fi

systemctl stop ksmtuned
systemctl disable --now ksmtuned
echo 2 > /sys/kernel/mm/ksm/run
rm -rf /etc/systemd/system/ksmtuned.service
apt autoremove ksmtuned -y
touch /usr/sbin/ksmtuned
chattr +i /usr/sbin/ksmtuned

cat > /etc/systemd/system/disable-transparent-huge-pages.service << EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'
[Install]
WantedBy=basic.target
EOF

systemctl daemon-reload
systemctl start disable-transparent-huge-pages
systemctl enable disable-transparent-huge-pages



OUT_ALERT "[信息] 优化参数中！"
modprobe nf_conntrack > /dev/null 2>&1
echo nf_conntrack > /usr/lib/modules-load.d/net.conf

chattr -i /etc/sysctl.conf
cat > /etc/sysctl.conf << EOF
fs.file-max = 10240000
net.core.default_qdisc = fq
net.core.somaxconn = 10240000
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.ip_default_ttl = 128
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 10240 65535
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_fastopen = 1027
net.ipv4.tcp_fastopen_blackhole_timeout_sec = 0
net.ipv4.tcp_fin_timeout = 2
net.ipv4.tcp_keepalive_intvl = 5
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_max_orphans = 10240
net.ipv4.tcp_max_syn_backlog = 10240
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_retries1 = 2
net.ipv4.tcp_retries2 = 2
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_rmem = 4096 16384 33554432
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.tcp_no_metrics_save=1
net.netfilter.nf_conntrack_generic_timeout = 10
net.netfilter.nf_conntrack_icmp_timeout = 2
net.netfilter.nf_conntrack_max = 10240000
net.netfilter.nf_conntrack_tcp_max_retrans = 2
net.netfilter.nf_conntrack_tcp_timeout_close = 2
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 2
net.netfilter.nf_conntrack_tcp_timeout_established = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 2
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 2
net.netfilter.nf_conntrack_tcp_timeout_max_retrans = 2
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 2
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 2
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 2
net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 2
net.netfilter.nf_conntrack_udp_timeout = 2
net.netfilter.nf_conntrack_udp_timeout_stream = 30
vm.swappiness = 0
EOF
cat > /etc/security/limits.conf << EOF
* soft nofile unlimited
* hard nofile unlimited
* soft nproc unlimited
* hard nproc unlimited
root soft nofile unlimited
root hard nofile unlimited
root soft nproc unlimited
root hard nproc unlimited
EOF
cat > /etc/systemd/journald.conf <<EOF
[Journal]
SystemMaxUse=384M
SystemMaxFileSize=128M
ForwardToSyslog=no
EOF
mems=$(free --bytes | grep Mem | awk '{print $2}')
page=$(getconf PAGESIZE)
size=$((mems/page))
echo "net.ipv4.tcp_mem = $((size/100*12)) $((size/100*50)) $((size/100*70))" >> /etc/sysctl.conf
sort -n /etc/sysctl.conf -o /etc/sysctl.conf
sysctl -p > /dev/null 2>&1

OUT_INFO "[信息] 优化完成！"
exit 0
