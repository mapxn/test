#!/bin/bash
#copyright by hiboy
source /etc/storage/script/init.sh
syncthing_wan_port=`nvram get syncthing_wan_port`
syncthing_enable=`nvram get syncthing_enable`
[ -z $syncthing_enable ] && syncthing_enable=0 && nvram set syncthing_enable=0
if [ "$syncthing_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep syncthing | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

syncthing_wan=`nvram get syncthing_wan`
syncthing_upanPath=`nvram get syncthing_upanPath`

syncthing_renum=`nvram get syncthing_renum`
syncthing_renum=${syncthing_renum:-"0"}
cmd_log_enable=`nvram get cmd_log_enable`
cmd_name="syncthing"
cmd_log=""
if [ "$cmd_log_enable" = "1" ] || [ "$syncthing_renum" -gt "0" ] ; then
	cmd_log="$cmd_log2"
fi
fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep sync_thing)" ]  && [ ! -s /tmp/script/_sync_thing ]; then
	mkdir -p /tmp/script
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_sync_thing
	chmod 777 /tmp/script/_sync_thing
fi

upanPath=""
[ -z $syncthing_wan_port ] && syncthing_wan_port=8384 && nvram set syncthing_wan_port=$syncthing_wan_port

syncthing_restart () {

relock="/var/lock/syncthing_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set syncthing_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【syncthing】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	syncthing_renum=${syncthing_renum:-"0"}
	syncthing_renum=`expr $syncthing_renum + 1`
	nvram set syncthing_renum="$syncthing_renum"
	if [ "$syncthing_renum" -gt "2" ] ; then
		syncthing_upanPath=`nvram get syncthing_upanPath`
		if [ ! -z "$syncthing_upanPath" ] ; then 
			logger -t "【syncthing】" "多次尝试启动失败，恢复备份【$syncthing_upanPath/syncthing/syncthing_backup.tgz】后自动尝试重新启动"
			rm -rf $syncthing_upanPath/syncthing/Downloads $syncthing_upanPath/syncthing/syncthing-linux-mipsle/syncthing.old
			mkdir -p "$upanPath/syncthing/Downloads"
			cd $syncthing_upanPath
			tar -xzvf ./syncthing/syncthing_backup.tgz -C ./ ; cd $syncthing_upanPath/syncthing
		fi
	fi
	if [ "$syncthing_renum" -gt "3" ] ; then
		I=19
		echo $I > $relock
		logger -t "【syncthing】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get syncthing_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set syncthing_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set syncthing_status=0
eval "$scriptfilepath &"
exit 0
}

syncthing_get_status () {

A_restart=`nvram get syncthing_status`
B_restart="$syncthing_enable$syncthing_wan$syncthing_wan_port"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
cut_B_re
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set syncthing_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

syncthing_check () {

syncthing_get_status
if [ "$syncthing_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "`pidof syncthing`" ] && logger -t "【syncthing】" "停止 syncthing" && syncthing_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$syncthing_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		syncthing_close
		syncthing_start
	else
		[ -z "`pidof syncthing`" ] && syncthing_restart
		syncthing_port_dpt
	fi
fi
}

syncthing_keep () {
logger -t "【syncthing】" "守护进程启动"
if [ -s /tmp/script/_opt_script_check ]; then
sed -Ei '/【syncthing】|^$/d' /tmp/script/_opt_script_check
cat >> "/tmp/script/_opt_script_check" <<-OSC
[ -z "\`pidof syncthing\`" ] || [ ! -s "$syncthing_upanPath/syncthing/syncthing-linux-mipsle/syncthing" ] && nvram set syncthing_status=00 && logger -t "【syncthing】" "重新启动" && eval "$scriptfilepath &" && sed -Ei '/【syncthing】|^$/d' /tmp/script/_opt_script_check # 【syncthing】
OSC
return
fi
sleep 600
syncthing_upanPath=`nvram get syncthing_upanPath`
if [ ! -z "$syncthing_upanPath" ] ; then 
	cd $syncthing_upanPath
	rm -rf $syncthing_upanPath/syncthing/Downloads $syncthing_upanPath/syncthing/syncthing-linux-mipsle/syncthing.old
	logger -t "【syncthing】" "备份 $syncthing_upanPath/syncthing 文件夹到【$syncthing_upanPath/syncthing/syncthing_backup.tgz】"
	tar -cz  -f ./syncthing/syncthing_backup.tgz ./syncthing
	mkdir -p "$upanPath/syncthing/Downloads"
fi
while true; do
	if [ -z "`pidof syncthing`" ] || [ ! -s "$syncthing_upanPath/syncthing/syncthing-linux-mipsle/syncthing" ] ; then
		logger -t "【syncthing】" "重新启动"
		syncthing_restart
	fi
sleep 252
done
}

syncthing_close () {

kill_ps "$scriptname keep"
sed -Ei '/【syncthing】|^$/d' /tmp/script/_opt_script_check
killall syncthing
killall -9 syncthing
sync;echo 3 > /proc/sys/vm/drop_caches
iptables -t filter -D INPUT -p tcp --dport 22000 -j ACCEPT
iptables -t filter -D INPUT -p udp -m multiport --dports 21025,21026,21027 -j ACCEPT
iptables -t filter -D INPUT -p tcp --dport $syncthing_wan_port -j ACCEPT
kill_ps "/tmp/script/_sync_thing"
kill_ps "_sync_thing.sh"
kill_ps "$scriptname"
}

syncthing_start () {
check_webui_yes
ss_opt_x=`nvram get ss_opt_x`
upanPath=""
[ "$ss_opt_x" = "3" ] && upanPath="`df -m | grep /dev/mmcb | grep -E "$(echo $(/usr/bin/find /dev/ -name 'mmcb*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
[ "$ss_opt_x" = "4" ] && upanPath="`df -m | grep /dev/sd | grep -E "$(echo $(/usr/bin/find /dev/ -name 'sd*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
[ -z "$upanPath" ] && [ "$ss_opt_x" = "1" ] && upanPath="`df -m | grep /dev/mmcb | grep -E "$(echo $(/usr/bin/find /dev/ -name 'mmcb*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
[ -z "$upanPath" ] && [ "$ss_opt_x" = "1" ] && upanPath="`df -m | grep /dev/sd | grep -E "$(echo $(/usr/bin/find /dev/ -name 'sd*') | sed -e 's@/dev/ /dev/@/dev/@g' | sed -e 's@ @|@g')" | grep "/media" | awk '{print $NF}' | sort -u | awk 'NR==1' `"
if [ "$ss_opt_x" = "5" ] ; then
	# 指定目录
	opt_cifs_dir=`nvram get opt_cifs_dir`
	if [ -d $opt_cifs_dir ] ; then
		upanPath="$opt_cifs_dir"
	else
		logger -t "【opt】" "错误！未找到指定目录 $opt_cifs_dir"
	fi
fi
if [ "$ss_opt_x" = "6" ] ; then
	opt_cifs_2_dir=`nvram get opt_cifs_2_dir`
	# 远程共享
	if mountpoint -q "$opt_cifs_2_dir" && [ -d "$opt_cifs_2_dir" ] ; then
		upanPath="$opt_cifs_2_dir"
	else
		logger -t "【opt】" "错误！未找到指定远程共享目录 $opt_cifs_2_dir"
	fi
fi
echo "$upanPath"
if [ -z "$upanPath" ] ; then 
	logger -t "【syncthing】" "未挂载储存设备, 请重新检查配置、目录，10 秒后自动尝试重新启动"
	sleep 10
	syncthing_restart x
	exit 0
fi
SVC_PATH="$upanPath/syncthing/syncthing-linux-mipsle/syncthing"
mkdir -p "$upanPath/syncthing/Downloads"
if [ ! -s "$SVC_PATH" ] && [ -d "$upanPath/syncthing/Downloads" ] ; then
	logger -t "【syncthing】" "找不到 $SVC_PATH ，安装 syncthing 程序"
	logger -t "【syncthing】" "开始下载 syncthing-linux-mipsle.tar.gz"
	wgetcurl.sh "$upanPath/syncthing/Downloads/syncthing-linux-mipsle.tar.gz" "$hiboyfile/syncthing-linux-mipsle.tar.gz" "$hiboyfile2/syncthing-linux-mipsle.tar.gz"
	untar.sh "$upanPath/syncthing/Downloads/syncthing-linux-mipsle.tar.gz" "$upanPath/syncthing"
	chmod -R 777  "$upanPath/syncthing/"
	mkdir -p "$upanPath/syncthing/syncthing-linux-mipsle"
	cp -r -f -a  $upanPath/syncthing/syncthing-linux-mipsle?*/* $upanPath/syncthing/syncthing-linux-mipsle/
	rm -rf $upanPath/syncthing/syncthing-linux-mipsle?*/
fi
chmod 777 "$SVC_PATH"
[[ "$($SVC_PATH -h 2>&1 | wc -l)" -lt 2 ]] && rm -rf $SVC_PATH
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【syncthing】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【syncthing】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && syncthing_restart x
fi
logger -t "【syncthing】" "运行 syncthing"

syncthing_upanPath="$upanPath"
nvram set syncthing_upanPath="$upanPath"
eval "$upanPath/syncthing/syncthing-linux-mipsle/syncthing -home $upanPath/syncthing -gui-address 0.0.0.0:$syncthing_wan_port $cmd_log" &

sleep 4
[ ! -z "$(ps -w | grep "syncthing" | grep -v grep )" ] && logger -t "【syncthing】" "启动成功" && syncthing_restart o
[ -z "$(ps -w | grep "syncthing" | grep -v grep )" ] && logger -t "【syncthing】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && syncthing_restart x
syncthing_port_dpt
initopt
#syncthing_get_status
eval "$scriptfilepath keep &"
exit 0
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/bash' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

syncthing_port_dpt () {

port=$(iptables -t filter -L INPUT -v -n --line-numbers | grep dpt:22000 | cut -d " " -f 1 | sort -nr | wc -l)
if [ "$port" = 0 ] ; then
	logger -t "【syncthing】" "允许 22000 tcp、21025,21026,21027 udp端口通过防火墙"
	iptables -t filter -I INPUT -p tcp --dport 22000 -j ACCEPT
	iptables -t filter -I INPUT -p udp -m multiport --dports 21025,21026,21027 -j ACCEPT
fi
if [ "$syncthing_wan" = "1" ] ; then
	port=$(iptables -t filter -L INPUT -v -n --line-numbers | grep dpt:$syncthing_wan_port | cut -d " " -f 1 | sort -nr | wc -l)
	if [ "$port" = 0 ] ; then
		logger -t "【syncthing】" "WebGUI 允许 $syncthing_wan_port tcp端口通过防火墙"
		iptables -t filter -I INPUT -p tcp --dport $syncthing_wan_port -j ACCEPT
	fi
fi
}

case $ACTION in
start)
	syncthing_close
	syncthing_check
	;;
check)
	syncthing_check
	;;
stop)
	syncthing_close
	;;
keep)
	#syncthing_check
	syncthing_keep
	;;
*)
	syncthing_check
	;;
esac

