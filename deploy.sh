#!/bin/bash

##################################【初始化环境部署脚本】##############################


######################
###【脚本显示菜单】###
######################
 echo -e "\n【——部署初始化环境脚本菜单】"
 echo  "####################################################"
 echo  "###          初始化环境部署                       ##"
 echo  "###     1)  一键式[启动网卡，并显示IP地址]        ##"
 echo  "###     2)  一键式[修改SELinux状态]               ##"
 echo  "###     3)  一键式[永久修改主机名]                ##"
 echo  "###     4)  一键式[部署本地yum源]                 ##"
 echo  "###     5)  一键式[安装Vim编辑器-补全功能]        ##"
 echo  "###     6)  一键式[退出脚本]                      ##"
 echo  "###     7)  一键式[重启服务器]                    ##"
 echo  "####################################################"  


########################
##【函数——启动网卡】##
########################

NETWORK(){
IP1=`ip addr show |tail -4|egrep "inet "|awk '{print $2}'|awk -F"/" '{print $1}'`
read -e -p "请输入您要修改的IP状态: " zt
if [ $zt ==  dhcp ]
then
	sed -r -i "s#^(BOOTPROTO=)(.*)#\1dhcp#" /etc/sysconfig/network-scripts/ifcfg-ens33  
	sed -r -i "s#^(ONBOOT=)(.*)#\1yes#" /etc/sysconfig/network-scripts/ifcfg-ens33 

	egrep "^IPADDR" /etc/sysconfig/network-scripts/ifcfg-ens33 &>/dev/null
	if [ $? -eq 0 ]
	then
		sed -r -i "s#^(IPADDR=)(.*)#\#\1\2#" /etc/sysconfig/network-scripts/ifcfg-ens33
	fi 

	systemctl restart network &>/dev/null

	ip addr show |tail -4|egrep "inet "|awk '{print $2}'|awk -F"/" '{print $1}' &>/dev/null
	if [ $? -eq 0 ]
	then
		echo "——提示-您的网卡已经重启成功！"
		echo "——提示-当前动态IP地址：$IP1"
	else 
		echo "——提示-因为未知原因，网卡重启失败！"
	fi

elif [ $zt ==  none ]
then	
	read -e -p "请输入静态IP地址： " IP
	sed -r -i "s#^(BOOTPROTO=)(.*)#\1none#" /etc/sysconfig/network-scripts/ifcfg-ens33 

	egrep "^IPADDR=" /etc/sysconfig/network-scripts/ifcfg-ens33 &>/dev/null 
	if [ $? -eq 0 ]
	then
		sed -r -i "s#^(IPADDR=)(.*)#\1$IP#" /etc/sysconfig/network-scripts/ifcfg-ens33 
	else
		sed -r -i "/ONBOOT=yes/a IPADDR=$IP" /etc/sysconfig/network-scripts/ifcfg-ens33 
	fi
	
	egrep "^#IPADDR=" /etc/sysconfig/network-scripts/ifcfg-ens33 &>/dev/null 
	if [ $? -eq 0 ]
	then	
		sed -r -i "s@(#IPADDR=)(.*)@@" /etc/sysconfig/network-scripts/ifcfg-ens33 
	fi

	systemctl restart network &>/dev/null

	if [ $IP1 ==  $IP ]
	then
		echo "——提示-网卡重启生效！"
		echo "——提示-当前静态IP地址：$IP1"
	else
		echo "——提示：因为未知原因，网卡重启失败！"
	fi
else
	echo "请输入\"dhcp\"或是\"none\"两种模式，其余模式脚本无法识别！"
fi
}


#############################
###【函数——关闭SElinux】###
#############################
SELINUX(){
read -e -p "请输入要修改的状态：" zt
sed -r -i "s#^(SELINUX=)(.*)#\1$zt#" /etc/sysconfig/selinux &>/dev/null
a=`egrep "^SELINUX=" /etc/sysconfig/selinux |awk -F"=" '{print $2}'`
echo -e "\n提示-SELINUX状态已经修改为:$a"
}

################################
###【函数——永久修改主机名】###
################################

NAME(){
	read -e -p "请输入主机名：" name
	hostnamectl set-hostname $name
	if [ $? -eq 0 ]
	then
		echo -e "\n提示-主机名修改成功，将在重启后生效，可稍后验证！"
	else
		echo -e "\n提示-主机名修改失败，请排查原因！"
	fi

}


###########################
###【函数——配置yum源】###
###########################

YUM(){
###清除基本环境###
umount /dev/sr0 &>/dev/null	 #取消挂载 
rm -f /etc/yum.repos.d/yum.repo  #删除配置文件

###准备基本环境###
mkdir /etc/yum.repos.d/bak  &>/dev/null  		#创建目录，方便'官方源'做归纳备份
mv /etc/yum.repos.d/* /etc/yum.repos.d/bak &>/dev/null  #将'官方源'移动到'bak目录'里
mkdir /mnt/centos7u3 &>/dev/null			#创建新的挂载目录，以便挂载使用

###写入新的配置文件###
cat >/etc/yum.repos.d/yum.repo <<EOF
[yum]
name=centos7u3
baseurl=file:///mnt/centos7u3
gpgcheck=0
enabled=1
EOF
	
###进行挂载###
mount -t iso9660 /dev/sr0 /mnt/centos7u3 &>/dev/null			#进行手动挂载   	
egrep "^mount -t iso9660 /dev/sr0" /etc/rc.d/rc.local &>/dev/null

if [ $? -eq 0 ]
then
	sed -r -i "s#(^mount -t iso9660 /dev/sr0)(.*)##" /etc/rc.d/rc.local
fi

echo "mount -t iso9660 /dev/sr0 /mnt/centos7u3" >> /etc/rc.d/rc.local   #设置开机自动挂载
chmod a+x /etc/rc.d/rc.local						#开机自动挂载文件，添加执行权限

###检查是否挂载成功###
df -h|grep /dev/sr0 &>/dev/null

if [ $? -eq 0 ]
then 
	echo -e "\n提示-本地yum源挂载成功，可以使用！\n"
	echo -e "——验证结果：`df -h |grep /dev/sr0`"
else
	echo -e "\n提示-本地yum源挂载失败，请排查原因！"
	echo -e "\n提示-请检查光盘是否处于\"链接\"状态！"
fi	
}


##########################################################
###【函数——安装Vim编辑器和bash-completion补全功能包】###
##########################################################
VIM(){

echo -e "\n提示-此功能请在本地yum源成功配置后使用，否则将会出现系统报错！"
echo -e "提示-正在安装中，请稍等……"
yum install -y vim &>/dev/null
if [ $? -eq 0 ]
then
	echo -e "\n提示-\"Vim编辑器\"安装完毕！"
else
	echo -e "\n提示-安装失败，或许是本地yum源配置出现问题，请手动排查！"
fi

yum install -y bash-completion &>/dev/null
if [ $? -eq 0 ]
then
	echo -e "\n提示-\"bash-completion\"补全包安装完毕！"
else
	
	echo -e "\n安装失败，或许是本地yum源配置出现问题，请手动排查！"
fi
}


##########################################
###【用户输入菜单，以及脚本主分支内容】###
##########################################
read -e -p "请输入选项: " xx 

case  $xx  in
	1)
		NETWORK
		bash $0
	;;
	2)
		SELINUX
		bash $0
	;;
	3)
		NAME
		bash $0
	;;
	4)
		YUM
		bash $0
	;;
	5)
		VIM
		bash $0
	;;
	6)
		exit
	;;
	7)
		reboot
	;;
	*)
		echo -e "\n\n——提示-请输入正确选项！"
		bash $0

esac




