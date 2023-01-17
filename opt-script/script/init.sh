#!/bin/bash
#copyright by hiboy
export PATH='/etc/storage/bin:/tmp/script:/etc/storage/script:/opt/usr/sbin:/opt/usr/bin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:/opt/lib
init_ver=2
#set -x
#hiboyfile="https://bitbucket.org/hiboyhiboy/opt-file/raw/master"
#hiboyscript="https://bitbucket.org/hiboyhiboy/opt-script/raw/master"
#hiboyfile2="https://gcore.jsdelivr.net/gh/HiboyHiboy/opt-file"
#hiboyscript2="https://gcore.jsdelivr.net/gh/HiboyHiboy/opt-script"
hiboyfile="https://opt.cn2qq.com/opt-file"
hiboyscript="https://opt.cn2qq.com/opt-script"
hiboyfile2="https://raw.githubusercontent.com/hiboyhiboy/opt-file/master"
hiboyscript2="https://raw.githubusercontent.com/hiboyhiboy/opt-script/master"
# --user-agent
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.67 Safari/537.36'
ACTION=$1
scriptfilepath=$(cd "$(dirname "$0")"; pwd)/$(basename $0)
#echo $scriptfilepath
scriptpath=$(cd "$(dirname "$0")"; pwd)
#echo $scriptpath
scriptname=$(basename $0)
#echo $scriptname
cmd_log2=' 2>&1 | awk '"'"'{cmd="logger -t '"'"'"'"'"'"'"'"'【'"'"'$cmd_name'"'"'】'"'"'"'"'"' '"'"' "'"'"'"$0"'"'"'"'"'"' "'"'"';";system(cmd)}'"'" 
[ -s /dev/null ] && { rm -f /dev/null ; mknod /dev/null c 1 3 ; chmod 666 /dev/null; }
chmod 755 /etc/storage/*.sh
ulimit -HSn 65536

x_wget_check_timeout_network_x()
{
[ -z "$(which wget)" ] && return
check_tmp="/tmp/check_timeout/$1"
wget --user-agent "$user_agent" -q  -T 3 -t 1 "$ss_link_2" -O /dev/null --spider --server-response
if [ "$?" != "0" ] ; then
	wget --user-agent "$user_agent" -q  -T 3 -t 2 "1.1.1.1" -O /dev/null --spider --server-response
	if [ "$?" == "0" ] ; then
	echo "check2=200" >> $check_tmp
	else
	echo "check2=404" >> $check_tmp
	fi
else
	echo "check2=200" >> $check_tmp
fi
echo "checkB=200" >> $check_tmp
sleep 3
rm -f $check_tmp
}

x_curl_check_timeout_network_x()
{
[ -z "$(which curl)" ] && return
check_tmp="/tmp/check_timeout/$1"
check_code="$(curl -L --connect-timeout 3 --user-agent "$user_agent" -s -w "%{http_code}" "$ss_link_2" -o /dev/null -I)"
if [ "$check_code" != "200" ] ; then
	check_code="$(curl -L --connect-timeout 3 --user-agent "$user_agent" -s -w "%{http_code}" "1.1.1.1" -o /dev/null -I)"
	if [ "$check_code" == "200" ] ; then
	echo "check2=200" >> $check_tmp
	else
	echo "check2=404" >> $check_tmp
	fi
else
	echo "check2=200" >> $check_tmp
fi
echo "checkA=200" >> $check_tmp
sleep 3
rm -f $check_tmp
}

check_timeout_network()
{
mkdir -p /tmp/check_timeout
[ -s /tmp/check_timeout/check ] && source /tmp/check_timeout/check
if [ "$2" == "check" ] || [ "$check2" == "404" ] ; then
rm -f /tmp/check_timeout/check
fi
[ ! -f /tmp/check_timeout/ver_time ] && echo -n "0" > /tmp/check_timeout/ver_time
new_time=$(date "+%y%m%d%H%M")
if [ $(($new_time - $(cat /tmp/check_timeout/ver_time))) -ge 3 ] || [ ! -s /tmp/check_timeout/check ] ; then
	echo "$new_time check_timeout_network 开始新的检测"
	echo -n "$new_time" > /tmp/check_timeout/ver_time
else
	echo "$new_time check_timeout_network 间隔少于3分钟直接返回上次检测值 $check2"
	return
fi
ss_link_2=`nvram get ss_link_2`
checkA="404"
checkB="404"
check2="404"

if [ ! -z "$(which curl)" ] ; then
SEED=`tr -cd 0-9 </dev/urandom | head -c 8`
RND_NUM=`echo $SEED 1 100|awk '{srand($1);printf "%d",rand()*10000%($3-$2)+$2}'`
[ "$RND_NUM" -lt 2 ] && RND_NUM="2" || { [ "$RND_NUM" -ge 2 ] || RND_NUM="2" ; }
rm -f /tmp/check_timeout/$RND_NUM
eval 'x_curl_check_timeout_network_x "$RND_NUM"' &
i_timeout=1
while [ "$checkA" == "404" ] ;
do
sleep 1
[ -s /tmp/check_timeout/$RND_NUM ] && source /tmp/check_timeout/$RND_NUM
i_timeout=`expr $i_timeout + 1`
if [ "$i_timeout" -gt 10 ] ; then
echo "【check_timeout_network】 网络连接，超时 10 秒！ $check2"
break
fi
done
[ -s /tmp/check_timeout/$RND_NUM ] && source /tmp/check_timeout/$RND_NUM
rm -f /tmp/check_timeout/$RND_NUM
echo "check2=$check2" > /tmp/check_timeout/check
fi

if [ "$check2" == "404" ] ; then 
SEED=`tr -cd 0-9 </dev/urandom | head -c 8`
RND_NUM=`echo $SEED 1 100|awk '{srand($1);printf "%d",rand()*10000%($3-$2)+$2}'`
[ "$RND_NUM" -lt 3 ] && RND_NUM="3" || { [ "$RND_NUM" -ge 3 ] || RND_NUM="3" ; }
rm -f /tmp/check_timeout/$RND_NUM
eval 'x_wget_check_timeout_network_x "$RND_NUM"' &
i_timeout=1
while [ "$checkB" == "404" ] ;
do
sleep 1
[ -s /tmp/check_timeout/$RND_NUM ] && source /tmp/check_timeout/$RND_NUM
i_timeout=`expr $i_timeout + 1`
if [ "$i_timeout" -gt 10 ] ; then
echo "【check_timeout_network】 网络连接，超时 10 秒！ $check2"
break
fi
done
[ -s /tmp/check_timeout/$RND_NUM ] && source /tmp/check_timeout/$RND_NUM
rm -f /tmp/check_timeout/$RND_NUM
rm -f /tmp/check_timeout/check
echo "check2=$check2" > /tmp/check_timeout/check
fi

}

kill_ps () {

COMMAND="$1"
if [ ! -z "$COMMAND" ] ; then
	eval $(ps -w | grep "$COMMAND" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
	eval $(ps -w | grep "$COMMAND" | grep -v $$ | grep -v grep | awk '{print "kill -9 "$1";";}')
fi
if [ "$2" == "exit0" ] ; then
	exit 0
fi
}

if [ -z "$(cat /sbin/wgetcurl.sh | grep "/tmp/script/wgetcurl.sh")" ] ; then
mkdir -p /tmp/script
cat > "/tmp/script/wgetcurl.sh" <<-\EEE
#!/bin/sh
export PATH='/etc/storage/bin:/tmp/script:/etc/storage/script:/opt/usr/sbin:/opt/usr/bin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:/opt/lib
# /etc/storage/script/init.sh echo ln /tmp/script/wgetcurl.sh
output="$1"
url1="$2"
url2="$3"
check_n="$4"
check_lines="$5"

wget_err=""
curl_err=""

[ -z "$url1" ] && return
[ -z "$url2" ] && url2="$url1"
[ -z "$output" ] && return
rm -f "$output"

download_wait () {
	{ sleep $check_time ; [ -f /tmp/wait/check/$check_time ] && eval $(ps -w | grep "max-redirs" | grep "$check_time" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}') ;  [ -f /tmp/wait/check/$check_time ] && eval $(ps -w | grep "wget\|-T" | grep "$check_time" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}') ; } &
}

download_k_wait () {
	eval $(ps -w | grep "sleep $check_time" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
}

download_curl () {
	rm -f "$output"
	curl_path=$*
	echo $check_time > /tmp/wait/check/$check_time
	{ check="`$curl_path --max-redirs $check_time --user-agent "$user_agent" -L -s -w "%{http_code}" -o $output`" ; echo "$check" > /tmp/wait/check/$check_time ; } &
	download_k_wait
	download_wait
	check="$(cat /tmp/wait/check/$check_time)"
	while [ "$check" = "$check_time" ];
	do
	sleep 1
	check="$(cat /tmp/wait/check/$check_time)"
	done
	[ "$check" != "200" ] && { curl_err="$check 错误！" ; rm -f "$output" ; }
}

download_wget () {
	rm -f "$output"
	wget_path=$*
	echo $check_time > /tmp/wait/check/$check_time
	{ $wget_path --user-agent "$user_agent" -O $output -T "$check_time" -t 10 ; [ "$?" == "0" ] && check=200 || check=404 ; echo "$check" > /tmp/wait/check/$check_time ; } &
	download_k_wait
	download_wait
	check="$(cat /tmp/wait/check/$check_time)"
	while [ "$check" = "$check_time" ];
	do
	sleep 1
	check="$(cat /tmp/wait/check/$check_time)"
	done
	[ "$check" != "200" ] && { wget_err="$check 错误！" ; rm -f "$output" ; }
}

if [ ! -s "$output" ] ; then
line_path=`dirname $output`
mkdir -p $line_path
if [ "$check_n" != "N" ] ; then
if hash check_disk_size 2>/dev/null ; then
avail=`check_disk_size $line_path`
if [ "$?" == "0" ] ; then
	echo "$avail M 可用容量:【$line_path】" 
else
	avail=0
	logger -t "【下载】" "错误！提取可用容量失败:【$line_path】" 
fi
[ -z "$avail" ] && avail=0
if [ "$avail" != "0" ] ; then
	echo "$avail M 可用容量:【$line_path】" 
fi
length=0
touch /tmp/check_avail_error.txt
if [ -z "$(grep "$url1" /tmp/check_avail_error.txt)" ] ; then
	if [ -z "$(echo "$url1" | grep "^/")" ] ; then
	length_wget=$(wget  -T 5 -t 3 "$url1" -O /dev/null --spider --server-response 2>&1 | grep "[Cc]ontent-[Ll]ength" | grep -Eo '[0-9]+' | tail -n 1)
	else
	length_wget=$(ls -l "$url1" | awk '{print $5}')
	fi
	[ -z "$length_wget" ] && echo "$url1" >> /tmp/check_avail_error.txt
	if [ -z "$length_wget" ] && [ -z "$(grep "$url2" /tmp/check_avail_error.txt)" ] ; then
		if [ -z "$(echo "$url2" | grep "^/")" ] ; then
		length_wget=$(wget  -T 5 -t 3 "$url2" -O /dev/null --spider --server-response 2>&1 | grep "[Cc]ontent-[Ll]ength" | grep -Eo '[0-9]+' | tail -n 1)
		else
		length_wget=$(ls -l "$url2" | awk '{print $5}')
		fi
		[ -z "$length_wget" ] && echo "$url2" >> /tmp/check_avail_error.txt
	fi
	[ ! -z "$length_wget" ] && length=$(echo $length_wget)
fi
[ -z "$length" ] && length=0
if [ "$length" != "0" ] && [ "$avail" != "0" ] ; then
	length=`expr $length + 512000`
	length=`expr $length / 1048576`
	echo "$length M 文件大小:【$url1】"
	if [ "$length" -gt "$avail" ] ; then
		logger -t "【下载】" "错误！剩余空间不足:【文件大小 $length M】>【$avail M 可用容量】"
		logger -t "【下载】" "跳过 下载【 $output 】"
		return 1
	fi
fi
fi
fi
mkdir -p /tmp/wait/check
check_time="1"$(tr -cd 0-9 </dev/urandom | head -c 3)
if [ -z "$(echo "$url1" | grep "^/")" ] ; then
if [ -s "/opt/bin/curl" ] && [ ! -s "$output" ] ; then
	download_curl /opt/bin/curl $url1
fi
if [ -s "/usr/sbin/curl" ] && [ ! -s "$output" ] ; then
	download_curl /usr/sbin/curl --capath /etc/ssl/certs $url1
fi
if [ -s "/opt/bin/wget" ] && [ ! -s "$output" ] ; then
	download_wget /opt/bin/wget $url1
fi
if [ -s "/usr/bin/wget" ] && [ ! -s "$output" ] ; then
	download_wget /usr/bin/wget $url1
fi
else
cp -f "$url1" "$output"
fi
if [ ! -s "$output" ] ; then
	logger -t "【下载】" "下载失败:【$output】 URL:【$url1】"
	logger -t "【下载】" "重新下载:【$output】 URL:【$url2】"
	if [ -z "$(echo "$url2" | grep "^/")" ] ; then
	if [ -s "/opt/bin/curl" ] && [ ! -s "$output" ] ; then
		download_curl /opt/bin/curl $url2
	fi
	if [ -s "/usr/sbin/curl" ] && [ ! -s "$output" ] ; then
		download_curl /usr/sbin/curl --capath /etc/ssl/certs $url2
	fi
	if [ -s "/opt/bin/wget" ] && [ ! -s "$output" ] ; then
		download_wget /opt/bin/wget $url2
	fi
	if [ -s "/usr/bin/wget" ] && [ ! -s "$output" ] ; then
		download_wget /usr/bin/wget $url2
	fi
	else
	cp -f "$url2" "$output"
	fi
fi
download_k_wait
rm -f /tmp/wait/check/$check_time
if [ ! -s "$output" ] ; then
	logger -t "【下载】" "下载失败:【$output】 URL:【$url2】"
	[ ! -z "$curl_err" ] && logger -t "【下载】" "curl_err ：$check错误！"
	[ ! -z "$wget_err" ] && logger -t "【下载】" "wget_err ：$check错误！"
fi
fi
[ -f "$output" ] && chmod 777 "$output"

EEE
chmod 755 "/tmp/script/wgetcurl.sh"
umount /sbin/wgetcurl.sh
mount --bind /tmp/script/wgetcurl.sh /sbin/wgetcurl.sh
fi

wgetcurl_file () {
if [ ! -s "$1" ] ; then
logger -t "【下载】" "找不到 $1 ，重新下载数据，请稍后"
wgetcurl.sh $*
fi
}

wgetcurl_checkmd5 () {
output="$1"
url1="$2"
url2="$3"
check_n="$4"
check_lines="$5"
[ -f "$output" ] && rm -f "$output"
mkdir -p $(dirname "$output")
wgetcurl.sh $output $url1 $url2 $check_n $check_lines
if [ -f "$output" ] ; then
	eval $(md5sum $output | awk '{print "MD5_down="$1;}')
	if [ -d /tmp/AiDisk_00 ] ; then
		mkdir -p /tmp/AiDisk_00/tmp/checkmd5/
		rm -rf /tmp/checkmd5/
		ln -sf /tmp/AiDisk_00/tmp/checkmd5 /tmp/checkmd5
	else
		rm -rf /tmp/checkmd5/
		mkdir -p /tmp/checkmd5/
	fi
	checkmd5tmp=$$
	wgetcurl.sh /tmp/checkmd5/$checkmd5tmp $url1 $url2 $check_n $check_lines
	eval $(md5sum /tmp/checkmd5/$checkmd5tmp | awk '{print "MD5_txt="$1;}')
	rm -f /tmp/checkmd5/$checkmd5tmp
	echo $MD5_down;echo $MD5_txt;
	if [ "$MD5_txt"x = "$MD5_down"x ] ; then
		logger -t "【下载】" "下载【$output】成功，2次下载md5匹配！【$url1】"
	else
		logger -t "【下载】" "下载【$output】错误，2次下载md5不匹配！【$url1】"
		logger -t "【下载】" "删除【$output】文件，麻烦看看哪里问题！"
		rm -f $output
	fi
fi
}

sstp_conf='/etc/storage/app_27.sh'
sstp_set() {
	sstp_set_a="$(echo "$1" | awk -F '=' '{print $1}')"
	sstp_set_b="$(echo "$1" | awk -F '=' '{for(i=2;i<=NF;++i) { if(i==2){sum=$i}else{sum=sum"="$i}}}END{print sum}')"
	(
		flock 527
		if [ ! -z "$(grep -Eo $sstp_set_a=.\+\(\ #\) $sstp_conf)" ] ; then
		sed -e "s@^$sstp_set_a=.\+\(\ #\)@$sstp_set_a='$sstp_set_b' #@g" -i $sstp_conf
		else
		sed -e "s@^$sstp_set_a=.\+@$sstp_set_a='$sstp_set_b' #@g" -i $sstp_conf
		fi
		if [ -z "$(cat $sstp_conf | grep "$sstp_set_a=""'""$sstp_set_b""'"" #")" ] ; then
		echo "$sstp_set_a=""'""$sstp_set_b""'"" #" >> $sstp_conf
		fi
	) 527>/var/lock/sstp_set.lock
}

sstp_get() {
	[ ! -z "$1" ] && eval echo `cat "$sstp_conf" | grep "$1" | awk -F '=' '{for(i=2;i<=NF;++i) { if(i==2){sum=$i}else{sum=sum"="$i}}}END{print sum}'`
}

check_webui_yes () {

if [ ! -f /tmp/webui_yes ] ; then
	logger -t "【webui】" "由于没找到【/tmp/webui_yes】文件，稍等后启动相关设置，如等候时间过长可尝试【重启】或【双清路由】"
	exit 0
fi
}

cut_B_re () {
B_restart="$(echo ${B_restart:0:3}${B_restart:29:3})"
}

cut_C_re () {
C_restart="$(echo ${C_restart:0:3}${C_restart:29:3})"
}

