#!/bin/bash

set -e
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi

if [ ! -e ~/gbinder-python/dist/gbinder-python-1.0.0.tar.gz  ];then
	echo "Error: ~/gbinder-python/dist/gbinder-python-1.0.0.tar.gz not exist. please build the project gbinder-python with python3 setup.py sdist --cython "
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
if [ ! -e "/etc/lsb-release" ];then
	uname -a |grep Debian 1>/dev/null 2>&1
	if [ $? = 0 ];then
		DISTRIB_ID="Debian"
	fi
	source /etc/os-release
else
	source /etc/lsb-release
fi
cat list/waydroid.list |sudo tee -a list/waydroidlist 1>/dev/null
cat list/mutter.list |sudo tee -a list/waydroidlist 1>/dev/null
if [ "$DISTRIB_ID" = "Kylin" ];then
	cat list/weston.list |sudo tee -a list/waydroidlist 1>/dev/null
	cat list/kylinmutter.list |sudo tee -a list/waydroidlist  1>/dev/null
	cat list/kylinfde.list |sudo tee -a list/waydroidlist  1>/dev/null
	cp -a debian/control.kylinv10sp1 ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Debian" ];then
	if [ ! -e /usr/bin/dch ];then
		sudo apt install devscripts -y
	fi
	cp -a debian/control.debian_$VERSION_CODENAME ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Ubuntu" ];then
	cp -a debian/control.ubuntu_$DISTRIB_CODENAME ${dst}/debian/control
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

#step 2 pack images

echo "Step 2: want to repack android images from /usr/share/waydroid-extra/images? y/n[n]"
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
sudo cp ~/gbinder-python/dist/gbinder-python-1.0.0.tar.gz $dst/

echo "tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz "
tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz
pushd $dst
#step 4 fill changes
dch -i 
popd 

#step 5 make debs
dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " "`
pushd debian/$dst_dir
sudo DEB_BUILD_OPTIONS="parallel=4" dpkg-buildpackage -us -uc
if [ $? != 0 ];then
	echo "Error: make deb failed."
	popd
	exit 1
fi
popd
echo "deb file generated at debian/"

