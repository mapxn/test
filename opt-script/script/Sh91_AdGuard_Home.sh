#!/bin/bash
#copyright by hiboy
source /etc/storage/script/init.sh
AdGuardHome_enable=`nvram get app_84`
[ -z $AdGuardHome_enable ] && AdGuardHome_enable=0 && nvram set app_84=0
AdGuardHome_dns=`nvram get app_132`
[ -z $AdGuardHome_dns ] && AdGuardHome_dns=0 && nvram set app_132=0
AdGuardHome_2_server=`nvram get app_85`
if [ "$AdGuardHome_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep AdGuardHome | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

AdGuardHome_renum=`nvram get AdGuardHome_renum`
cmd_log_enable=`nvram get cmd_log_enable`
cmd_name="AdGuardHome"
cmd_log=""
if [ "$cmd_log_enable" = "1" ] || [ "$AdGuardHome_renum" -gt "0" ] ; then
	cmd_log="$cmd_log2"
fi

fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep AdGuard_Home)" ]  && [ ! -s /tmp/script/_app17 ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_app17
	chmod 777 /tmp/script/_app17
fi

AdGuardHome_restart () {

relock="/var/lock/AdGuardHome_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set AdGuardHome_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【AdGuardHome】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	AdGuardHome_renum=${AdGuardHome_renum:-"0"}
	AdGuardHome_renum=`expr $AdGuardHome_renum + 1`
	nvram set AdGuardHome_renum="$AdGuardHome_renum"
	if [ "$AdGuardHome_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【AdGuardHome】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get AdGuardHome_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set AdGuardHome_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set AdGuardHome_status=0
eval "$scriptfilepath &"
exit 0
}

AdGuardHome_get_status () {

A_restart=`nvram get AdGuardHome_status`
B_restart="$AdGuardHome_enable$AdGuardHome_dns$AdGuardHome_2_server"
[ "$(nvram get app_86)" = "1" ] && B_restart="$B_restart""$(cat /etc/storage/app_19.sh | grep -v '^#' | grep -v "^$")"
[ "$(nvram get app_86)" = "1" ] && nvram set app_86=0
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
cut_B_re
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set AdGuardHome_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

AdGuardHome_check () {
AdGuardHome_get_status
if [ "$AdGuardHome_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "AdGuardHome" | grep -v grep )" ] && logger -t "【AdGuardHome】" "停止 AdGuardHome" && AdGuardHome_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$AdGuardHome_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		AdGuardHome_close
		AdGuardHome_start
	else
		if [ "$AdGuardHome_dns" != "0" ] ; then
			[ -z "$(ps -w | grep "AdGuardHome" | grep -v grep )" ] && AdGuardHome_restart
			if [ "$(grep "port=12353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
				sleep 10 
				if [ "$(grep "port=12353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
					logger -t "【AdGuardHome】" "检测:找不到 dnsmasq 变更侦听端口规则 port=12353 , 自动尝试重新启动"
					AdGuardHome_restart
				fi
			fi
		else
			[ -z "$AdGuardHome_2_server" ] && [ -z "$(ps -w | grep "AdGuardHome" | grep -v grep )" ] && AdGuardHome_restart
			if [ "$(grep "server=127.0.0.1#5353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
				sleep 10 
				if [ "$(grep "server=127.0.0.1#5353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
					logger -t "【AdGuardHome】" "检测:找不到 dnsmasq 转发规则 server=127.0.0.1#5353 , 自动尝试重新启动"
					AdGuardHome_restart
				fi
			fi
		fi
	fi
fi
}

AdGuardHome_keep () {
logger -t "【AdGuardHome】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【AdGuardHome】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
	[ -z "\`pidof AdGuardHome\`" ] || [ ! -s "/opt/AdGuardHome/AdGuardHome" ] && nvram set AdGuardHome_status=00 && logger -t "【AdGuardHome】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【AdGuardHome】|^$/d' /tmp/script/_opt_script_check # 【AdGuardHome】
OSC
#return
fi
while true; do
if [ "$AdGuardHome_dns" != "0" ] ; then
	if [ "$(grep "port=12353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
		sleep 10 
		if [ "$(grep "port=12353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
			logger -t "【AdGuardHome】" "检测:找不到 dnsmasq 变更侦听端口规则 port=12353 , 自动尝试重新启动"
			AdGuardHome_restart
		fi
	fi
else
	if [ "$(grep "server=127.0.0.1#5353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
		sleep 10
		if [ "$(grep "server=127.0.0.1#5353"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)" = 0 ] ; then
			logger -t "【AdGuardHome】" "检测:找不到 dnsmasq 转发规则 server=127.0.0.1#5353 , 自动尝试重新启动"
			AdGuardHome_restart
		fi
	fi
fi
[ "$(grep "</textarea>"  /etc/storage/app_19.sh | wc -l)" != 0 ] && sed -Ei s@\<\/textarea\>@@g /etc/storage/app_19.sh
sleep 61
done
}

AdGuardHome_close () {
kill_ps "$scriptname keep"
sed -Ei '/【AdGuardHome】|^$/d' /tmp/script/_opt_script_check
port=$(grep "#server=127.0.0.1#8053"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)
sed ":a;N;s/\n\n\n/\n\n/g;ba" -i  /etc/storage/dnsmasq/dnsmasq.conf
sed -Ei '/server=127.0.0.1#5353/d' /etc/storage/dnsmasq/dnsmasq.conf
sed -Ei '/AdGuardHome/d' /etc/storage/dnsmasq/dnsmasq.conf
sed -Ei 's/^#dns-forward-max/dns-forward-max/g' /etc/storage/dnsmasq/dnsmasq.conf
if [ "$port" != 0 ] ; then
	sed -Ei '/server=127.0.0.1#8053/d' /etc/storage/dnsmasq/dnsmasq.conf
	echo 'server=127.0.0.1#8053' >> /etc/storage/dnsmasq/dnsmasq.conf
	logger -t "【AdGuardHome】" "检测到 dnsmasq 转发规则, 恢复 server=127.0.0.1#8053"
fi
restart_dhcpd
killall AdGuardHome
killall -9 AdGuardHome
kill_ps "/tmp/script/_app17"
kill_ps "_AdGuard_Home.sh"
kill_ps "$scriptname"
}

AdGuardHome_start () {
check_webui_yes
port=$(grep "server=127.0.0.1#8053"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)
if [ ! -z "$AdGuardHome_2_server" ] && [ "$AdGuardHome_dns" == "0" ] ; then
	logger -t "【AdGuardHome】" "使用外置 AdGuardHome 服务器： $AdGuardHome_2_server"
	logger -t "【AdGuardHome】" "建议外置 AdGuardHome 服务器的上游 DNS 是无污染的"
	AdGuardHome_server="server=$(echo $AdGuardHome_2_server | sed 's@:\|：@#@g')"
else
	SVC_PATH="/opt/AdGuardHome/AdGuardHome"
	if [ ! -s "$SVC_PATH" ] ; then
		logger -t "【AdGuardHome】" "找不到 $SVC_PATH，安装 opt 程序"
		/etc/storage/script/Sh01_mountopt.sh start
		initopt
	fi
	mkdir -p "/opt/AdGuardHome"
	if [ ! -s "$SVC_PATH" ] && [ -d "/opt/AdGuardHome" ] ; then
		logger -t "【AdGuardHome】" "找不到 $SVC_PATH ，安装 AdGuardHome 程序"
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --max-redirect=0 --output-document=-  https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
			[ -z "$tag" ] && tag="$( wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=-  https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
		else
			tag="$( curl --connect-timeout 3 --user-agent "$user_agent"  https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
			[ -z "$tag" ] && tag="$( curl -L --connect-timeout 3 --user-agent "$user_agent" -s  https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
		fi
		if [ ! -z "$tag" ] ; then
			logger -t "【AdGuardHome】" "自动下载最新版本 $tag"
			wgetcurl.sh "/opt/AdGuardHome/AdGuardHome.tar.gz" "https://github.com/AdguardTeam/AdGuardHome/releases/download/$tag/AdGuardHome_linux_mipsle_softfloat.tar.gz"
			tar -xzvf /opt/AdGuardHome/AdGuardHome.tar.gz -C /opt
		fi
		if [ ! -s "$SVC_PATH" ] && [ -d "/opt/AdGuardHome" ] ; then
			static_adguard="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_mipsle_softfloat.tar.gz"
			logger -t "【AdGuardHome】" "开始下载 $static_adguard"
			wgetcurl.sh "/opt/AdGuardHome/AdGuardHome.tar.gz" "$static_adguard"
			tar -xzvf /opt/AdGuardHome/AdGuardHome.tar.gz -C /opt ; cd /opt/AdGuardHome
		fi
		 cd /opt/AdGuardHome ; rm -f ./AdGuardHome.tar.gz ./LICENSE.txt./README.md ./CHANGELOG.md ./AdGuardHome.sig
		if [ ! -s "$SVC_PATH" ] && [ -d "/opt/AdGuardHome" ] ; then
			logger -t "【AdGuardHome】" "最新版本获取失败！！！"
			logger -t "【AdGuardHome】" "开始下载 $hiboyfile2/AdGuardHome"
			wgetcurl.sh "/opt/AdGuardHome/AdGuardHome" "$hiboyfile/AdGuardHome" "$hiboyfile2/AdGuardHome"
		fi
	fi
	chmod 777 "$SVC_PATH"
	# 更新 yq
	[ -z "$(yq -V 2>&1 | grep 3\.4\.1)" ] && rm -rf /opt/bin/yq /opt/opt_backup/bin/yq
	if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
		yq_check
	if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
		logger -t "【AdGuardHome】" "找不到 /opt/bin/yq ，需要手动安装 /opt/bin/yq"
		logger -t "【AdGuardHome】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && AdGuardHome_restart x
	fi
	fi
	AdGuardHome_v=$($SVC_PATH -c /etc/storage/app_19.sh -w /opt/AdGuardHome --check-config --verbose 2>&1 | grep version | sed -n '1p' | awk -F 'version' '{print $2;}'| awk -F ',' '{print $1;}')
	nvram set AdGuardHome_v="$AdGuardHome_v"
	[ -z "$AdGuardHome_v" ] && { eval "$SVC_PATH -c /etc/storage/app_19.sh -w /opt/AdGuardHome --check-config --verbose $cmd_log2" ; rm -rf $SVC_PATH ; }
	if [ ! -s "$SVC_PATH" ] ; then
		logger -t "【AdGuardHome】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
		logger -t "【AdGuardHome】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && AdGuardHome_restart x
	fi
	logger -t "【AdGuardHome】" "启用本机 AdGuardHome 服务"
	AdGuardHome_server='server=127.0.0.1#5353'
	# 生成配置文件
	if [ "$AdGuardHome_dns" != "0" ] ; then
		AdGuardHome_server='server=127.0.0.1#53'
		yq w -i /etc/storage/app_19.sh dns.port 53
		logger -t "【AdGuardHome】" "修改本机 AdGuardHome 服务器的上游 DNS: 127.0.0.1:12353"
		#yq w -i /etc/storage/app_19.sh dns.upstream_dns "[]"
		[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 1.0.0.1)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==1.0.0.1)"
		[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:8053)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==127.0.0.1:8053)"
		[ -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:12353)" ] && yq w -i /etc/storage/app_19.sh dns.upstream_dns[+] "127.0.0.1:12353"
	else
		port=$(grep "server=127.0.0.1#8053"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)
		if [ "$port" != 0 ] ; then
			logger -t "【AdGuardHome】" "修改本机 AdGuardHome 服务器的上游 DNS: 127.0.0.1:8053"
			#yq w -i /etc/storage/app_19.sh dns.upstream_dns "[]"
			[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 1.0.0.1)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==1.0.0.1)"
			[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:12353)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==127.0.0.1:12353)"
			[ -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:8053)" ] && yq w -i /etc/storage/app_19.sh dns.upstream_dns[+] "127.0.0.1:8053"
		else
			[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:8053)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==127.0.0.1:8053)"
			[ ! -z "$(yq r /etc/storage/app_19.sh dns.upstream_dns | grep 127.0.0.1:12353)" ] && yq d -i /etc/storage/app_19.sh "dns.upstream_dns(.==127.0.0.1:12353)"
			[ "$(yq r /etc/storage/app_19.sh dns.upstream_dns)" == '[]' ] && yq w -i /etc/storage/app_19.sh dns.upstream_dns[+] "1.0.0.1"
		fi
		yq w -i /etc/storage/app_19.sh dns.port 5353
	fi
	if [ "$AdGuardHome_dns" != "0" ] ; then
		logger -t "【AdGuardHome】" "变更 dnsmasq 侦听端口规则 port=12353"
		sed -Ei '/AdGuardHome/d' /etc/storage/dnsmasq/dnsmasq.conf
		echo "port=12353 #AdGuardHome" >> /etc/storage/dnsmasq/dnsmasq.conf
		restart_dhcpd
	fi
	logger -t "【AdGuardHome】" "运行 /opt/AdGuardHome/AdGuardHome"
	cd /opt/AdGuardHome
	eval "/opt/AdGuardHome/AdGuardHome --no-etc-hosts -c /etc/storage/app_19.sh -w /opt/AdGuardHome $cmd_log" &
	sleep 3
	[ ! -z "$(ps -w | grep "AdGuardHome" | grep -v grep )" ] && logger -t "【AdGuardHome】" "启动成功" && AdGuardHome_restart o
	[ -z "$(ps -w | grep "AdGuardHome" | grep -v grep )" ] && logger -t "【AdGuardHome】" "启动失败, 注意检AdGuardHome是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && AdGuardHome_restart x
	restart_dhcpd
	AdGuardHome_get_status
	eval "$scriptfilepath keep &"
fi
if [ "$AdGuardHome_dns" == "0" ] ; then
	port=$(grep "server=127.0.0.1#8053"  /etc/storage/dnsmasq/dnsmasq.conf | wc -l)
	if [ "$port" != 0 ] ; then
		logger -t "【AdGuardHome】" "检测到 dnsmasq 转发规则, 删除 server=127.0.0.1#8053"
		sed -Ei '/server=/d' /etc/storage/dnsmasq/dnsmasq.conf
		echo '#server=127.0.0.1#8053' >> /etc/storage/dnsmasq/dnsmasq.conf
	fi
	logger -t "【AdGuardHome】" "添加 AdGuardHome 的 dnsmasq 转发规则 $AdGuardHome_server"
	sed -Ei '/AdGuardHome/d' /etc/storage/dnsmasq/dnsmasq.conf
	echo "$AdGuardHome_server #AdGuardHome" >> /etc/storage/dnsmasq/dnsmasq.conf
	echo "no-resolv #AdGuardHome" >> /etc/storage/dnsmasq/dnsmasq.conf
	sed -Ei 's/^dns-forward-max/#dns-forward-max/g' /etc/storage/dnsmasq/dnsmasq.conf
	echo "dns-forward-max=1000 #AdGuardHome" >> /etc/storage/dnsmasq/dnsmasq.conf
fi
sed ":a;N;s/\n\n\n/\n\n/g;ba" -i  /etc/storage/dnsmasq/dnsmasq.conf
restart_dhcpd
exit 0
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

initconfig () {

app_19="/etc/storage/app_19.sh"
if [ ! -f "$app_19" ] || [ ! -s "$app_19" ] ; then
	cat > "$app_19" <<-\EEE
bind_host: 0.0.0.0
bind_port: 3000
auth_name: admin
auth_pass: admin
language: zh-cn
rlimit_nofile: 0
dns:
  bind_host: 0.0.0.0
  port: 5353
  protection_enabled: true
  filtering_enabled: true
  blocking_mode: nxdomain
  blocked_response_ttl: 10
  querylog_enabled: true
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  bootstrap_dns:
  - 1.1.1.1
  all_servers: true
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts: []
  parental_sensitivity: 0
  parental_enabled: false
  safesearch_enabled: false
  safebrowsing_enabled: false
  resolveraddress: ""
  upstream_dns:
  - 1.1.1.1
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  certificate_chain: ""
  private_key: ""
filters:
- enabled: true
  url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
  name: AdGuard Simplified Domain Names filter
  id: 1
- enabled: true
  url: https://adaway.org/hosts.txt
  name: AdAway
  id: 2
- enabled: true
  url: https://www.malwaredomainlist.com/hostslist/hosts.txt
  name: MalwareDomainList.com Hosts List
  id: 3
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  gateway_ip: ""
  subnet_mask: ""
  range_start: ""
  range_end: ""
  lease_duration: 86400
  icmp_timeout_msec: 1000
clients: []
log_file: ""
verbose: false
schema_version: 3

EEE
	chmod 755 "$app_19"
fi

}

yq_check () {

if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
	logger -t "【clash】" "找不到 yq，安装 opt 程序"
	/etc/storage/script/Sh01_mountopt.sh start
if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
	for h_i in $(seq 1 2) ; do
	[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] && rm -rf /opt/bin/yq
	wgetcurl_file /opt/bin/yq "$hiboyfile/yq" "$hiboyfile2/yq"
	done
if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
	logger -t "【clash】" "找不到 yq，安装 opt 程序"
	rm -f /opt/bin/yq
	/etc/storage/script/Sh01_mountopt.sh start
if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
	#opkg update
	#opkg install yq
if [[ "$(yq -h 2>&1 | wc -l)" -lt 2 ]] ; then
	logger -t "【clash】" "找不到 yq，需要手动安装 opt 后输入[opkg update; opkg install yq]安装"
	return 1
fi
fi
fi
fi
fi
}

initconfig

update_app () {
mkdir -p /opt/app/AdGuardHome
if [ "$1" = "update_asp" ] ; then
	rm -rf /opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp
fi
if [ "$1" = "del" ] ; then
	rm -rf /opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp /opt/AdGuardHome/AdGuardHome
fi

initconfig

# 加载程序配置页面
if [ ! -f "/opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp" ] || [ ! -s "/opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp" ] ; then
	wgetcurl.sh /opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp "$hiboyfile/Advanced_Extensions_AdGuardHomeasp" "$hiboyfile2/Advanced_Extensions_AdGuardHomeasp"
fi
umount /www/Advanced_Extensions_app17.asp
mount --bind /opt/app/AdGuardHome/Advanced_Extensions_AdGuardHome.asp /www/Advanced_Extensions_app17.asp
# 更新程序启动脚本

[ "$1" = "del" ] && /etc/storage/www_sh/AdGuardHome del &
}

case $ACTION in
start)
	AdGuardHome_close
	AdGuardHome_check
	;;
check)
	AdGuardHome_check
	;;
stop)
	AdGuardHome_close
	;;
updateapp17)
	AdGuardHome_restart o
	[ "$AdGuardHome_enable" = "1" ] && nvram set AdGuardHome_status="updateAdGuardHome" && logger -t "【AdGuardHome】" "重启" && AdGuardHome_restart
	[ "$AdGuardHome_enable" != "1" ] && nvram set AdGuardHome_v="" && logger -t "【AdGuardHome】" "更新" && update_app del
	;;
update_app)
	update_app
	;;
update_asp)
	update_app update_asp
	;;
keep)
	#AdGuardHome_check
	AdGuardHome_keep
	;;
*)
	AdGuardHome_check
	;;
esac

