#!/bin/bash
#幸福工厂服务器搭建脚本

########
#root权限检测,，无则退出脚本
root_need() {
    if [[ $EUID -ne 0 ]]; then
        echo "错误：脚本必须以root权限运行!" 1>&2
        exit 1
    fi
}
#交换分区函数
swap_make() {
    #使用dd命令创建名为swapfile 的swap交换文件
    dd  if=/dev/zero  of=/var/swapfile  bs=1024  count=6291456 
    #对交换文件格式化并转换为swap分区
    mkswap  /var/swapfile
    #添加权限
    chmod -R 0600 /var/swapfile
    #挂载并激活分区
    swapon   /var/swapfile
    #修改 fstab 配置，设置开机自动挂载该分区
    echo  "/var/swapfile   swap  swap  defaults  0  0" >>  /etc/fstab
}
#安装所需环境
environment_get(){
    add-apt-repository multiverse
    dpkg --add-architecture i386
    apt update -y
    apt install lib32gcc1 libcurl4-gnutls-dev:i386 lib32stdc++6 lib32z1 -y
    apt install libsdl2-2.0-0:i386 -y
}
#判断steam用户函数
steam_add(){
    egrep "^steam" /etc/passwd >& /dev/null
    if [ $? -ne 0 ]
    then
    echo "创建账户steam"
        useradd -m steam
    fi
}

########
########
#系统检测
########

root_need

########
#配置检测
########
#设置log输出地址
opath=/home/satisfactory_output.log
# 获取物理内存总量
pyhMem=`free | grep Mem | awk '{print $2}'`
#获取虚拟内存总量
virMem=`free | grep Swap | awk '{print $2}'`
# 获取内存总容量
mem=`expr $virMem + $pyhMem`
# 获取cpu总核数
cpuNum=`grep -c "model name" /proc/cpuinfo`
#获取本机ip地址
ip=`ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
#对文件进行覆写，置空
:> $opath
# 对内存大小进行判断
if [ $mem -gt 6291456 ] 
then
    tmpNum=`free -h | grep Mem | awk '{print $2}'`
    echo -e "\033[;32m物理内存大小："$tmpNum"\033[0m"
    tmpNum=`free -h | grep Swap | awk '{print $2}'`
    echo -e "\033[;32m虚拟内存大小："$tmpNum"\033[0m"
else
    echo -e "\033[;31m注意：内存不够用！请使用虚拟内存或者升级更高配置的服务器！\033[0m"
fi

# 对内核数进行判断
if [ $cpuNum -gt 1 ] 
then
    echo -e "\033[;32m内核数："$cpuNum"个\033[0m"
else
    echo -e "\033[;31m注意：内核数不够用！请升级更高配置的服务器！\033[0m"
fi
if [ $mem -gt 6291456 ] && [ $cpuNum -gt 1 ] 
then
    echo "恭喜你！你的配置足够搭建服务器！"
fi

if [ $mem -lt 6291456 ] 
then
    echo "当前系统总内存小于6G，是否开启虚拟内存？"
    echo "1为是，其他为否"
    read -r tmpNum
    if [ $tmpNum == 1 ]
    then
        echo "开始创建swap分区"
        #这里会有输出信息
        echo "swap分区开启输出信息：" >> $opath 2>&1
        swap_make  >> $opath 2>&1
        echo "虚拟内存配置完成！"
    fi
fi

echo "开始安装steamCMD以及游戏所需环境"

#安装steamCMD以及游戏所需环境

#这里会有输出信息
echo "steamcmd 及游戏环境安装输出：" >> $opath 2>&1
environment_get >> $opath 2>&1

echo "steamCMD以及游戏所需环境安装完成！"
echo "开始安装steamCMD"

steam_add

#进行steamCMD的安装
fileDir="/home/steam"
#新建游戏存放目录
if [ ! -d /home/steam/steamcmd  ];then
    su - steam -c "mkdir ~/steamcmd"
fi
#下载文件
#这里有打印信息
su - steam -c "wget -P ~/steamcmd https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" >> $opath 2>&1
#解压文件
su - steam -c "tar -zxvf ~/steamcmd/steamcmd_linux.tar.gz -C ~/steamcmd" >> $opath 2>&1
#删除下载的压缩包
su - steam -c "rm -f ~/steamcmd/steamcmd_linux.tar.gz"
#运行steamCMD安装
#这里有打印信息
su - steam -c "~/steamcmd/steamcmd.sh +quit" >> $opath 2>&1

if [ ! -d /home/steam/.steam/sdk64/  ];then
    mkdir -p /home/steam/.steam/sdk64/
fi

ln -s /home/steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/ >> $opath 2>&1

echo "steamCMD安装完成！"
echo "开始安装幸福工厂"

#这里有输出信息
su - steam -c "~/steamcmd/steamcmd.sh +force_install_dir ~/SatisfactoryDedicatedServer +login anonymous +app_update 1690800 validate +quit" >> $opath 2>&1

if [ ! -d /home/steam/.config/Epic/FactoryGame/Saved/SaveGames/server  ];then
    su - steam -c "mkdir -p ~/.config/Epic/FactoryGame/Saved/SaveGames/server"
fi

su - steam -c "echo "存档位置为："`pwd`"
echo "创建启动脚本"

cat>/home/steam/SatisfactoryDedicatedServer/start_server.sh<<EOF
#!/bin/bash

export InstallationDir=/home/steam/SatisfactoryDedicatedServer
export templdpath=\$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=\$InstallationDir/linux64:\$LD_LIBRARY_PATH
# Install or update the server before launching it
/home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/SatisfactoryDedicatedServer +login anonymous \$InstallationDir +app_update 1690800 validate +quit
# Launch the server
\$InstallationDir/FactoryServer.sh

export LD_LIBRARY_PATH=\$templdpath

EOF

chmod +x $fileDir/SatisfactoryDedicatedServer/start_server.sh

echo "创建服务，使之开机运行！"
cat>/etc/systemd/system/satisfactory.service<<EOF
[Unit]
Description=Satisfactory Server
Wants=network.target
After=syslog.target network-online.target

[Service]
Type=simple
Restart=always
RestartSec=10
User=steam
WorkingDirectory=/home/steam/SatisfactoryDedicatedServer
ExecStart=/home/steam/SatisfactoryDedicatedServer/start_server.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable satisfactory.service >> $opath 2>&1
systemctl start satisfactory.service
echo "安装完成！游戏服务已经启动！"
echo "安装目录为："$fileDir
echo "可以使用命令进行操作："
echo -e "本机ip为：""\033[;32m"$ip"\033[0m"
echo -e "\033[;32m启动游戏：systemctl start satisfactory.service\033[0m"
echo -e "\033[;32m重启游戏：systemctl restart satisfactory.service\033[0m"
echo -e "\033[;32m关闭游戏：systemctl stop satisfactory.service\033[0m"
echo "0 4 * * * systemctl restart satisfactory.service"  >>  /etc/crontab
