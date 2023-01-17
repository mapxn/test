#!/bin/bash
#copyright by hiboy
source /etc/storage/script/init.sh
dns_com_pod_enable=`nvram get dns_com_pod_enable`
[ -z $dns_com_pod_enable ] && dns_com_pod_enable=0 && nvram set dns_com_pod_enable=0
if [ "$dns_com_pod_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep dns_com_pod | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

dns_com_pod_username=`nvram get dns_com_pod_username`
dns_com_pod_password=`nvram get dns_com_pod_password`
dns_com_pod_user_token=`nvram get dns_com_pod_user_token`
dns_com_pod_domian=`nvram get dns_com_pod_domian`
dns_com_pod_host=`nvram get dns_com_pod_host`
dns_com_pod_domian2=`nvram get dns_com_pod_domian2`
dns_com_pod_host2=`nvram get dns_com_pod_host2`
dns_com_pod_domian6=`nvram get dns_com_pod_domian6`
dns_com_pod_host6=`nvram get dns_com_pod_host6`
dns_com_pod_interval=`nvram get dns_com_pod_interval`

if [ "$dns_com_pod_domian"x != "x" ] && [ "$dns_com_pod_host"x = "x" ] ; then
	dns_com_pod_host="www"
	nvram set dns_com_pod_host="www"
fi
if [ "$dns_com_pod_domian2"x != "x" ] && [ "$dns_com_pod_host2"x = "x" ] ; then
	dns_com_pod_host2="www"
	nvram set dns_com_pod_host2="www"
fi
if [ "$dns_com_pod_domian6"x != "x" ] && [ "$dns_com_pod_host6"x = "x" ] ; then
	dns_com_pod_host6="www"
	nvram set dns_com_pod_host6="www"
fi

IPv6=0
domain_type=""
post_type=""
hostIP=""
myIP=""
[ -z $dns_com_pod_interval ] && dns_com_pod_interval=600 && nvram set dns_com_pod_interval=$dns_com_pod_interval
fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep dns_com_pod)" ]  && [ ! -s /tmp/script/_dns_com_pod ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_dns_com_pod
	chmod 777 /tmp/script/_dns_com_pod
fi

dns_com_pod_get_status () {

A_restart=`nvram get dns_com_pod_status`
B_restart="$dns_com_pod_enable$dns_com_pod_username$dns_com_pod_password$dns_com_pod_user_token$dns_com_pod_domian$dns_com_pod_host$dns_com_pod_domian2$dns_com_pod_host2$dns_com_pod_domian6$dns_com_pod_host6$dns_com_pod_interval$(cat /etc/storage/ddns_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
cut_B_re
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set dns_com_pod_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

dns_com_pod_get_status2 () {

[ "x$dns_com_pod_username" = "x" ] && [ "x$dns_com_pod_password" = "x" ] && return 0
A_restart=`nvram get dns_com_pod_status2`
B_restart="$dns_com_pod_username$dns_com_pod_password"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
cut_B_re
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set dns_com_pod_status2=$B_restart
	dns_com_pod_user_token=""
fi
if [ "x$dns_com_pod_user_token" = "x" ] ; then # undefine token
	user_token=`curl -L    -X POST https://api.dnspod.com/Auth -d 'login_email='"$dns_com_pod_username"'&login_password='"$dns_com_pod_password"'&format=json'`
	dns_com_pod_user_token="$(echo $user_token  | grep -Eo '"user_token":"[^"]*"' | cut -d':' -f2 | tr -d '"')"
	if [ "x$dns_com_pod_user_token" = "x" ] ; then # undefine token
		# 输出错误信息
		message=$(echo $user_token | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"')
		logger -t "【dns_com_pod动态域名】" "获取 user_token 错误: $message"
		logger -t "【dns_com_pod动态域名】" "获取 user_token 错误，10 秒后自动尝试重新启动" && sleep 10; nvram set dns_com_pod_status=00; eval "$scriptfilepath &"; exit 0;
	fi
	nvram set dns_com_pod_user_token="$dns_com_pod_user_token"
fi
}

dns_com_pod_check () {

dns_com_pod_get_status
dns_com_pod_get_status2
if [ "$dns_com_pod_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && logger -t "【dns_com_pod动态域名】" "停止 dns_com_pod" && dns_com_pod_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$dns_com_pod_enable" = "1" ] ; then
[ "x$dns_com_pod_user_token" = "x" ] && [ "x$dns_com_pod_username" = "x" ] && [ "x$dns_com_pod_password" = "x" ] && { logger -t "【dns_com_pod动态域名】" "用户名密码或者 Token 等设置未填写, 10 秒后自动尝试重新启动" && sleep 10; nvram set dns_com_pod_status=00; eval "$scriptfilepath &"; exit 0; }
	if [ "$needed_restart" = "1" ] ; then
		dns_com_pod_get_status
		dns_com_pod_close
		eval "$scriptfilepath keep &"
		exit 0
	else
		[ -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && nvram set dns_com_pod_status=00 && { eval "$scriptfilepath start &"; exit 0; }
	fi
fi
}

dns_com_pod_keep () {
dns_com_pod_start
logger -t "【dns_com_pod动态域名】" "守护进程启动"
cat >> "/tmp/script/_opt_script_check" <<-OSC
[ -z "\`pidof Sh40_dns_com_pod.sh\`" ] && nvram set dns_com_pod_status=00 && logger -t "【dns_com_pod】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【dns_com_pod】|^$/d' /tmp/script/_opt_script_check # 【dns_com_pod】
OSC
while true; do
sleep 41
sleep $dns_com_pod_interval
#nvramshow=`nvram showall | grep '=' | grep dns_com_pod | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
dns_com_pod_enable=`nvram get dns_com_pod_enable`
[ "$dns_com_pod_enable" = "0" ] && dns_com_pod_close && exit 0;
if [ "$dns_com_pod_enable" = "1" ] ; then
	dns_com_pod_start
fi
done
}

dns_com_pod_close () {
sed -Ei '/【dns_com_pod】|^$/d' /tmp/script/_opt_script_check
kill_ps "$scriptname keep"
kill_ps "/tmp/script/_dns_com_pod"
kill_ps "_dns_com_pod.sh"
kill_ps "$scriptname"
}

dns_com_pod_start () {
check_webui_yes
IPv6=0
if [ "$dns_com_pod_domian"x != "x" ] && [ "$dns_com_pod_host"x != "x" ] ; then
	DOMAIN="$dns_com_pod_domian"
	HOST="$dns_com_pod_host"
	domainID=""
	recordID=""
	recordIP=""
	arDdnsCheck $dns_com_pod_domian $dns_com_pod_host
fi
if [ "$dns_com_pod_domian2"x != "x" ] && [ "$dns_com_pod_host2"x != "x" ] ; then
	sleep 1
	DOMAIN="$dns_com_pod_domian2"
	HOST="$dns_com_pod_host2"
	domainID=""
	recordID=""
	recordIP=""
	arDdnsCheck $dns_com_pod_domian2 $dns_com_pod_host2
fi
if [ "$dns_com_pod_domian6"x != "x" ] && [ "$dns_com_pod_host6"x != "x" ] ; then
	sleep 1
	IPv6=1
	DOMAIN="$dns_com_pod_domian6"
	HOST="$dns_com_pod_host6"
	domainID=""
	recordID=""
	recordIP=""
	arDdnsCheck $dns_com_pod_domian6 $dns_com_pod_host6
fi

source /etc/storage/ddns_script.sh
while read line
do
	line=`echo $line | cut -d '#' -f1`
	line=$(echo $line)
	[ -z "$line" ] && continue
	sleep 1
	IPv6=1
	IPv6_neighbor=1
	domainID=""
	recordID=""
	recordIP=""
	HOST="$(echo "$line" | cut -d '@' -f1)"
	DOMAIN="$(echo "$line" | cut -d '@' -f2)"
	inf_MAC="$(echo "$line" | cut -d '@' -f3 | tr 'A-Z' 'a-z')"
	inf_match="$(echo "$line" | cut -d '@' -f4)"
	inf_v_match="$(echo "$line" | cut -d '@' -f5)"
	[ -z "$inf_v_match" ] && inf_v_match="inf_v_match"
	inet6_neighbor="$(echo "$line" | cut -d '@' -f6)"
	inet6_neighbor=$(echo $inet6_neighbor)
	if [ -z "$inet6_neighbor" ] ; then
		ip -f inet6 neighbor show > /tmp/ip6_neighbor.log
		inet6_neighbor="$(cat /tmp/ip6_neighbor.log | grep "$inf_MAC" | grep -v "$inf_v_match" | grep "$inf_match" | awk -F ' ' '{print $1}' | sed -n '1p')"
	fi
	[ ! -z "$inet6_neighbor" ] && arDdnsCheck $DOMAIN $HOST
	IPv6_neighbor=0
done < /tmp/ip6_ddns_inf

}

arDdnsInfo() {
	#local domainID recordID recordIP
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
		post_type="Record.Modify"
	else
		domain_type="A"
		post_type="Record.Ddns"
	fi
	# 获得域名ID
	domainID=$(arApiPost "Domain.Info" "domain=$DOMAIN")
	domainID=$(echo $domainID | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	
	# 获得记录ID
	recordID=$(arApiPost "Record.List" "domain_id=$domainID&sub_domain=$HOST")
	recordID=$(echo $recordID | grep -Eo '"records".+' | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
	
	# 获得最后更新IP
	recordIP=$(arApiPost "Record.Info" "domain_id=$domainID&record_id=$recordID")
	recordIP=$(echo $recordIP | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"' |head -n1)

	# Output IP
	if [ "$IPv6" = "1" ]; then
	echo $recordIP
	return 0
	else
	case "$recordIP" in 
	[1-9]*)
		echo $recordIP
		return 0
		;;
	*)
		domainID=""
		recordID=""
		recordIP=""
		echo "Get Record Info Failed!"
		#logger -t "【dns_com_pod动态域名】" "获取记录信息失败！"
		return 1
		;;
	esac
	fi
}

# 查询域名地址
# 参数: 待查询域名
arNslookup() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep -v ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="`wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	else
		Address="`curl --user-agent "$user_agent" -s http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	fi
fi
rm -f /tmp/arNslookup/$$
}

arNslookup6() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
	cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="$(wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- --header 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name='"$1"'&type=AAAA')"
		if [ $? -eq 0 ]; then
		echo "$Address" | grep -Eo "data\":\"[^\"]+" | sed "s/data\":\"//g" | sed -n '1p'
		fi
	else
		Address="$(curl --user-agent "$user_agent" -s -H 'accept: application/dns-json' 'https://cloudflare-dns.com/dns-query?name='"$1"'&type=AAAA')"
		if [ $? -eq 0 ]; then
		echo "$Address" | grep -Eo "data\":\"[^\"]+" | sed "s/data\":\"//g" | sed -n '1p'
		fi
	fi
fi
rm -f /tmp/arNslookup/$$
}

# 读取接口数据
# 参数: 接口类型 待提交数据
arApiPost() {
	inter="https://api.dnspod.com/${1:?'Info.Version'}"
	
	param="user_token=$dns_com_pod_user_token&format=json&$2"
	
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		wget -T 5 -t 3 --quiet --output-document=- --post-data $param $inter
	else
		curl -L    -X POST $inter -d $param
	fi
	sleep 1
}

# 更新记录信息
# 参数: 主域名 子域名
arDdnsUpdate() {
	#local domainID recordID recordRS recordCD recordIP
I=3
recordID=""
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
		post_type="Record.Modify"
	else
		domain_type="A"
		post_type="Record.Ddns"
	fi
while [ -z "$recordID" ] ; do
	I=$(($I - 1))
	[ $I -lt 0 ] && break
	# 获得域名ID
	domainID=$(arApiPost "Domain.Info" "domain=$DOMAIN")
	domainID=$(echo $domainID  | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	sleep 1
	# 获得记录ID
	recordID=$(arApiPost "Record.List" "domain_id=$domainID&sub_domain=$HOST")
	recordID=$(echo $recordID | grep -Eo '"records".+' | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
done
	#echo "更新记录信息 recordID: " $recordID
	if [ -z "$recordID" ] ; then
		# 添加子域名记录IP
		myIP=$hostIP
		logger -t "【dns_com_pod动态域名】" "添加子域名 $HOST 记录IP: $myIP"
		recordRS=$(arApiPost "Record.Create" "domain_id=$domainID&sub_domain=$HOST&record_type=$domain_type&value=$myIP&record_line=default")
	else
		# 更新记录IP
		myIP=$hostIP
		recordRS=$(arApiPost "$post_type" "domain_id=$domainID&record_id=$recordID&sub_domain=$HOST&record_type=$domain_type&value=$myIP&record_line=default")
	fi
	recordCD=$(echo $recordRS | grep -Eo '"code":"[0-9]+"' | cut -d':' -f2 | tr -d '"')
	recordIP=$(echo $recordRS | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"')
	# 输出记录IP
	if [ -z "$recordIP" ] ; then
		sleep 10
		# 获得记录ID
		recordID=$(arApiPost "Record.List" "domain_id=$domainID&sub_domain=$HOST")
		recordID=$(echo $recordID | grep -Eo '"records".+' | sed -e "s/"'"remark":'"/"' \n '"/g" | grep '"type":"'$domain_type'"' | grep -Eo '"id":"[0-9]+"' | cut -d':' -f2 | tr -d '"' |head -n1)
		
		# 获得最后更新IP
		recordIP=$(arApiPost "Record.Info" "domain_id=$domainID&record_id=$recordID")
		recordIP=$(echo $recordIP | grep -Eo '"value":"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"' |head -n1)
	fi
	if [ "$recordIP" = "$myIP" ]; then
		if [ "$recordCD" = "1" ] ; then
			echo $recordIP
			logger -t "【dns_com_pod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
			return 0
		fi
		# 输出错误信息
		echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'
		logger -t "【dns_com_pod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
		return 1
	fi
	# 输出错误信息
	echo "Update Failed! Please check your network."
	logger -t "【dns_com_pod动态域名】" "`echo $recordRS | grep -Eo '"message":"[^"]*"' | cut -d':' -f2 | tr -d '"'`"
	return 1
}

# 动态检查更新
# 参数: 主域名 子域名
arDdnsCheck() {
	#local postRS
	#local lastIP
	source /etc/storage/ddns_script.sh
	hostIP=$arIpAddress
	hostIP=`echo $hostIP | head -n1 | cut -d' ' -f1`
	if [ -z $(echo "$hostIP" | grep : | grep -v "\.") ] && [ "$IPv6" = "1" ] ; then 
		IPv6=0
		logger -t "【dns_com_pod动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
		return 1
	fi
	if [ "$hostIP"x = "x"  ] ; then
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://myip.ipip.net" | grep "当前 IP" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://ddns.oray.com/checkip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		else
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L --user-agent "$user_agent" -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L --user-agent "$user_agent" -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L --user-agent "$user_agent" -s "http://myip.ipip.net" | grep "当前 IP" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L --user-agent "$user_agent" -s http://ddns.oray.com/checkip | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		fi
		if [ "$hostIP"x = "x"  ] ; then
			logger -t "【dns_com_pod动态域名】" "错误！获取目前 IP 失败，请在脚本更换其他获取地址"
			return 1
		fi
	fi
	echo "Updating Domain: $HOST.$DOMAIN"
	echo "hostIP: $hostIP"
	#lastIP=$(arNslookup "$HOST.$DOMAIN")
	lastIP=$(arDdnsInfo "$DOMAIN" "$HOST")
	if [ $? -eq 1 ]; then
		[ "$IPv6" != "1" ] && lastIP=$(arNslookup "$HOST.$DOMAIN")
		[ "$IPv6" = "1" ] && lastIP=$(arNslookup6 "$HOST.$DOMAIN")
	fi
	echo "lastIP: $lastIP"
	if [ "$lastIP" != "$hostIP" ] ; then
		logger -t "【dns_com_pod动态域名】" "开始更新 $HOST.$DOMAIN 域名 IP 指向"
		logger -t "【dns_com_pod动态域名】" "目前 IP: $hostIP"
		logger -t "【dns_com_pod动态域名】" "上次 IP: $lastIP"
		domainID=""
		recordID=""
		recordIP=""
		sleep 1
		postRS=$(arDdnsUpdate "$DOMAIN" "$HOST")
		if [ $? -eq 0 ]; then
			echo "postRS: $postRS"
			logger -t "【dns_com_pod动态域名】" "更新动态DNS记录成功！提交的IP: $postRS"
			return 0
		else
			echo $postRS
			logger -t "【dns_com_pod动态域名】" "更新动态DNS记录失败！请检查您的网络。提交的IP: $postRS"
			if [ "$IPv6" = "1" ] ; then 
				IPv6=0
				logger -t "【dns_com_pod动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
				return 1
			fi
			return 1
		fi
	fi
	echo "Last IP is the same as current IP!"
	return 1

}

initconfig () {

if [ ! -s "/etc/storage/ddns_script.sh" ] ; then
cat > "/etc/storage/ddns_script.sh" <<-\EEE
# 自行测试哪个代码能获取正确的IP，删除前面的#可生效
arIpAddress () {
# IPv4地址获取
# 获得外网地址
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
    #wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "https://www.cloudflare.com/cdn-cgi/trace" | awk -F= '/ip/{print $2}'
    #wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://myip.ipip.net" | grep "当前 IP" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=- "http://ddns.oray.com/checkip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
else
    #curl -L --user-agent "$user_agent" -s "https://www.cloudflare.com/cdn-cgi/trace" | awk -F= '/ip/{print $2}'
    #curl -L --user-agent "$user_agent" -s "http://myip.ipip.net" | grep "当前 IP" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    curl -L --user-agent "$user_agent" -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L --user-agent "$user_agent" -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -L --user-agent "$user_agent" -s http://ddns.oray.com/checkip | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
fi
}
arIpAddress6 () {
# IPv6地址获取
# 因为一般ipv6没有nat ipv6的获得可以本机获得
ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
#curl -6 -s https://www.cloudflare.com/cdn-cgi/trace | awk -F= '/ip/{print $2}'
}
if [ "$IPv6_neighbor" != "1" ] ; then
if [ "$IPv6" = "1" ] ; then
arIpAddress=$(arIpAddress6)
else
arIpAddress=$(arIpAddress)
fi
else
arIpAddress=$inet6_neighbor
inet6_neighbor=""
IPv6_neighbor=0
fi

# 根据 ip -f inet6 neighbor show 获取终端的信息，设置 ddns 解析，实现每个终端的 IPV6 动态域名
# 参数说明：使用 @ 符号分割，①前缀名称 ②域名 ③MAC【不限大小写】
# ④匹配关键词的ip6地址【可留空】 ⑤排除关键词的ip6地址【可留空】 ⑥手动指定ip【可留空】 
# 下面是信号填写例子：（删除前面的#可生效）
cat >/tmp/ip6_ddns.inf <<-\EOF
#www@google.com@09:9B:9A:90:9F:D9@@fe80::@  # 参数填写例子



EOF
cat /tmp/ip6_ddns.inf | grep -v '^#'  | grep -v "^$" > /tmp/ip6_ddns_inf
rm -f /tmp/ip6_ddns.inf
EEE
	chmod 755 "$ddns_script"
fi

}

initconfig

case $ACTION in
start)
	dns_com_pod_close
	dns_com_pod_check
	;;
check)
	dns_com_pod_check
	;;
stop)
	dns_com_pod_close
	;;
keep)
	dns_com_pod_keep
	;;
*)
	dns_com_pod_check
	;;
esac

