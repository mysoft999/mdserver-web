#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH
# LANG=en_US.UTF-8
is64bit=`getconf LONG_BIT`

if [ -f /www/server/mdserver-web/tools.py ];then
	echo -e "存在旧版代码,不能安装!,已知风险的情况下" 
	echo -e "rm -rf /www/server/mdserver-web"
	echo -e "可安装!" 
	exit 0
fi

LOG_FILE=/var/log/mw-install.log

{

if [ -f /etc/motd ];then
    echo "welcome to mdserver-web panel" > /etc/motd
fi

startTime=`date +%s`

_os=`uname`
echo "use system: ${_os}"

if [ ${_os} == "Darwin" ]; then
	OSNAME='macos'
elif grep -Eqi "openSUSE" /etc/*-release; then
	OSNAME='opensuse'
	zypper refresh
	zypper install cron wget curl zip unzip
elif grep -Eqi "FreeBSD" /etc/*-release; then
	OSNAME='freebsd'
	pkg install -y wget curl zip unzip unrar rar
elif grep -Eqi "EulerOS" /etc/*-release || grep -Eqi "openEuler" /etc/*-release; then
	OSNAME='euler'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "CentOS" /etc/issue || grep -Eqi "CentOS" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Fedora" /etc/issue || grep -Eqi "Fedora" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Rocky" /etc/issue || grep -Eqi "Rocky" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Anolis" /etc/issue || grep -Eqi "Anolis" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "AlmaLinux" /etc/issue || grep -Eqi "AlmaLinux" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Amazon Linux" /etc/issue || grep -Eqi "Amazon Linux" /etc/*-release; then
	OSNAME='amazon'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Debian" /etc/issue || grep -Eqi "Debian" /etc/os-release; then
	OSNAME='debian'
	# apt update -y
	apt install -y wget curl zip unzip tar cron
elif grep -Eqi "Ubuntu" /etc/issue || grep -Eqi "Ubuntu" /etc/os-release; then
	OSNAME='ubuntu'
	# apt update -y
	apt install -y wget curl zip unzip tar cron
else
	OSNAME='unknow'
fi

if [ "$EUID" -ne 0 ] && [ "$OSNAME" != "macos" ];then 
	echo "Please run as root!"
 	exit
fi


# HTTP_PREFIX="https://"
# LOCAL_ADDR=common
# ping  -c 1 github.com > /dev/null 2>&1
# if [ "$?" != "0" ];then
# 	LOCAL_ADDR=cn
# 	HTTP_PREFIX="https://mirror.ghproxy.com/"
# fi

HTTP_PREFIX="https://"
LOCAL_ADDR=common
cn=$(curl -fsSL -m 10 -s http://ipinfo.io/json | grep "\"country\": \"CN\"")
if [ ! -z "$cn" ] || [ "$?" == "0" ] ;then
	LOCAL_ADDR=cn
    HTTP_PREFIX="https://mirror.ghproxy.com/"
fi

echo "local:${LOCAL_ADDR}"

if [ $OSNAME != "macos" ];then
	if id www &> /dev/null ;then 
	    echo ""
	else
	    groupadd www
		useradd -g www -s /usr/sbin/nologin www
	fi

	mkdir -p /www/server
	mkdir -p /www/wwwroot
	mkdir -p /www/wwwlogs
	mkdir -p /www/backup/database
	mkdir -p /www/backup/site

	# https://cdn.jsdelivr.net/gh/midoks/mdserver-web@latest/scripts/install.sh
	if [ ! -d /www/server/mdserver-web ];then
		if [ "$LOCAL_ADDR" == "common" ];then
			curl --insecure -sSLo /tmp/master.zip https://github.com/midoks/mdserver-web/archive/refs/heads/master.zip
			cd /tmp && unzip /tmp/master.zip
			mv -f /tmp/mdserver-web-master /www/server/mdserver-web
			rm -rf /tmp/master.zip
			rm -rf /tmp/mdserver-web-master
		else
			# curl --insecure -sSLo /tmp/master.zip https://github.com/midoks/mdserver-web/archive/refs/heads/master.zip
			wget --no-check-certificate -O /tmp/master.zip https://github.com/midoks/mdserver-web/archive/refs/heads/master.zip
			cd /tmp && unzip /tmp/master.zip
			mv -f /tmp/mdserver-web /www/server/mdserver-web
			rm -rf /tmp/master.zip
			rm -rf /tmp/mdserver-web
		fi

		
	fi

	# install acme.sh
	if [ ! -d /root/.acme.sh ];then
	    if [ "$LOCAL_ADDR" != "common" ];then
	        curl --insecure -sSLo /tmp/acme.tar.gz https://gitee.com/neilpang/acme.sh/repository/archive/master.tar.gz
	        tar xvzf /tmp/acme.tar.gz -C /tmp
	        cd /tmp/acme.sh-master
	        bash acme.sh install
	    fi

	    if [ ! -d /root/.acme.sh ];then
	        curl  https://get.acme.sh | sh
	    fi
	fi
fi

echo "use system version: ${OSNAME}"
if [ "${OSNAME}" == "macos" ];then
	curl --insecure -fsSL https://code.midoks.icu/midoks/mdserver-web/raw/branch/master/scripts/install/macos.sh | bash
else
	cd /www/server/mdserver-web && bash scripts/install/${OSNAME}.sh
fi

if [ "${OSNAME}" == "macos" ];then
	echo "macos end"
	exit 0
fi

cd /www/server/mdserver-web && bash cli.sh start
isStart=`ps -ef|grep 'gunicorn -c setting.py app:app' |grep -v grep|awk '{print $2}'`
n=0
while [ ! -f /etc/rc.d/init.d/mw ];
do
    echo -e ".\c"
    sleep 1
    let n+=1
    if [ $n -gt 20 ];then
    	echo -e "start mw fail"
    	exit 1
    fi
done

cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw stop
cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw start
cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw default

sleep 2
if [ ! -e /usr/bin/mw ]; then
	if [ -f /etc/rc.d/init.d/mw ];then
		ln -s /etc/rc.d/init.d/mw /usr/bin/mw
	fi
fi

endTime=`date +%s`
((outTime=(${endTime}-${startTime})/60))
echo -e "Time consumed:\033[32m $outTime \033[0mMinute!"

} 1> >(tee $LOG_FILE) 2>&1

echo -e "\nInstall completed. If error occurs, please contact us with the log file mw-install.log ."
echo "安装完毕，如果出现错误，请带上同目录下的安装日志 mw-install.log 联系我们反馈."
