#!/bin/bash

set -e
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi

sed -i "/gbinder.cpython/d" list/waydroid.list
sudo find /usr -name "gbinder.cpython*aarch64-linux-gnu.so" > /tmp/gbinder.list
n=`cat /tmp/gbinder.list |wc -l`
if  [  $n = 0  ] ;then
	echo "Error: cant't find gbinder.cpython*aarch64-linux-gnu.so "
	exit 1
fi
sudo find /usr -name "gbinder.cpython*aarch64-linux-gnu.so" >> list/waydroid.list
#remove mutter files from list/waydroid.list
sudo sed -i "/mutter/d" list/waydroid.list
source /etc/lsb-release
if [ "$DISTRIB_ID" = "Kylin" ];then
	cat list/mutter.list |sudo tee -a list/waydroid.list 1>/dev/null
fi

num=`ls debian -l |grep ^d |wc -l`
if [ $num -ne 1 ];then
	echo "Error: more than one directory like openfde-x.x.x exist. please remove the useless one"
	exit 1 
fi
dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " "`

dst=debian/$dst_dir


#step 1 tar fde
echo "Step 1: will tar file from the below list"
tar -zcvpf $dst/fde.tar -T list/fde.list
d=`date +%Y%m%d`
sed -i "/ro.build.fingerprint/s/eng.electr.*/eng.electr.$d.$ver:user\/release-keys\")/" /usr/lib/waydroid/tools/helpers/images.py
sed -i "/ro.vendor.build.fingerprint/s/eng.electr.*/eng.electr.$d.$ver:user\/release-keys\")/" /usr/lib/waydroid/tools/helpers/images.py
sed -i "/ro.build.display.id/s/eng.electr.*/eng.electr.$d.$ver:user\/release-keys\")/" /usr/lib/waydroid/tools/helpers/images.py
tar -zcvpf $dst/waydroid.tar -T list/waydroid.list

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
echo "tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  tigervnc.tar.gz waydroid_image.tar  waydroid.tar"
sudo cp -a tigervnc.tar.gz $dst/tigervnc.tar.gz
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

