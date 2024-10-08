#!/bin/bash

set -e
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi

if [ ! -e ~/tigervnc-standalone-server_1.10.1+dfsg-3_arm64.deb ];then
	echo "Error: ~/gitervnc-standalone-server_1.10.1+dfsg-3_arm64.deb not exist. please build the project fde_tigervncserver"
	exit 1
fi

sudo find /usr -name "gbinder.cpython*aarch64-linux-gnu.so" > /tmp/gbinder.list
n=`cat /tmp/gbinder.list |wc -l`
if  [  $n = 0  ] ;then
	echo "Error: cant't find gbinder.cpython*aarch64-linux-gnu.so "
	exit 1
fi

num=`ls debian -l |grep ^d |wc -l`
if [ $num -ne 1 ];then
	echo "Error: more than one directory like openfde-x.x.x exist. please remove the useless one"
	exit 1 
fi
dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " "`

dst=debian/$dst_dir
sudo rm -rf list/waydroidlist
sudo find /usr -name "gbinder.cpython*aarch64-linux-gnu.so" >> list/waydroidlist
source /etc/lsb-release
cat list/waydroid.list |sudo tee -a list/waydroidlist 1>/dev/null
if [ "$DISTRIB_ID" = "Kylin" ];then
	cat list/weston.list |sudo tee -a list/waydroidlist 1>/dev/null
	cat list/mutter.list |sudo tee -a list/waydroidlist 1>/dev/null
	cat list/kylin.list |sudo tee -a list/waydroidlist  1>/dev/null
	cp -a debian/control.kylinv10sp1 ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Ubuntu" ];then
	cp -a debian/control.ubuntu22.04 ${dst}/debian/control
elif [ "$DISTRIB_ID" == "uos" ] ;then
	cat list/weston.list |sudo tee -a list/waydroidlist 1>/dev/null
	cp -a debian/control.uos20eagle ${dst}/debian/control
fi


#step 1 tar fde
echo "Step 1: will tar file from the below list"
tar -zcvpf $dst/fde.tar -T list/fde.list
d=`date +%Y%m%d`
sed -i "/ro.openfde.version/s/ro.openfde.version.*/ro.openfde.version=$ver-$d\")/" /usr/lib/waydroid/tools/helpers/images.py
tar -zcvpf $dst/waydroid.tar -T list/waydroidlist

#step 2 clone container

echo "Step 2: want to save a new android container y/n[n]?"
read choice 
if [ -z "$choice" ];then
	choice=n
else
	if [ "$choice" != "n" ];then
		choice=y
	fi
fi
if [ "$choice" = "y" ];then
	sudo tar -zcvpf $dst/waydroid_image.tar /usr/share/waydroid-extra
fi

#step 3 make src.xz
sudo rm -rf /tmp/tigervnc-standalone
mkdir /tmp/tigervnc-standalone
sudo dpkg-deb -x ~/tigervnc-standalone-server_1.10.1+dfsg-3_arm64.deb /tmp/tigervnc-standalone
sudo tar -cvpf $dst/tigervnc.tar.gz -C /tmp/tigervnc-standalone usr

echo "tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  tigervnc.tar.gz waydroid_image.tar  waydroid.tar"
tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  tigervnc.tar.gz waydroid_image.tar  waydroid.tar
pushd $dst
#step 4 fill changes
dch -i 
popd 

#step 5 make debs
dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " "`
pushd debian/$dst_dir
sudo dpkg-buildpackage -us -uc
if [ $? != 0 ];then
	echo "Error: make deb failed."
	popd
	exit 1
fi
popd
echo "deb file generated at debian/"

