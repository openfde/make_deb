#!/bin/bash

set -e
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi
if [ $# -eq  2 ];then
	arm64_only=1
	echo "arm64only mode"
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
secs=`echo $dst |awk -F "-" '{print NF}'`
cur_ver=`echo $dst |awk -F "-" '{print $2}'`
if [ $arm64_only -eq 1 ];then
	if [ $secs -eq 2 ];then #2 means normal node
		base_package=`echo $dst |awk -F "-" '{print $1}'`
		echo "mv $dst/debian/openfde to $dst/debian/openfde-arm64"
		sudo mv $dst/debian/openfde $dst/debian/openfde-arm64
		echo "mv $dst to debian/openfde-arm64-$cur_ver"
		sudo mv $dst debian/openfde-arm64-$cur_ver
		dst="debian/openfde-arm64-$cur_ver"
	elif [ $secs -eq 3 ];then # 3 means already arm64only mode (openfde-arm64-x.x.x)
		echo "already arm64 only"
		if [ -e $dst/debian/openfde ];then
			echo "mv $dst/debian/openfde to $dst/debian/openfde-arm64"
			sudo mv $dst/debian/openfde $dst/debian/openfde-arm64
		fi
	fi
else
	if [ $secs -eq 3 ];then #3 means already arm64only mode(openfde-arm64-x.x.x)
		echo "mv $dst to debian/openfde-$cur_ver"
		sudo mv $dst debian/openfde-$cur_ver
		dst="debian/openfde-$cur_ver"
	fi
fi

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

if [ $arm64_only -eq 1 ];then
	source=`sed -n "/Source/s/.*://p" ${dst}/debian/control |tr -d " " `
	if [ "$source" = "openfde" ];then
		sed -i "/Source/s/openfde/openfde-arm64/" ${dst}/debian/control
	fi
	package=`sed -n "/Package/s/.*://p" ${dst}/debian/control |tr -d " " `
	if [ "$package" = "openfde" ];then
		sed -i "/Package/s/openfde/openfde-arm64/" ${dst}/debian/control
	fi
	change=`sed -n "1s/(.*//p" ${dst}/debian/changelog |tr -d " "`
	if [ "$change" = "openfde" ];then
		sed -i "1s/openfde/openfde-arm64/" ${dst}/debian/changelog
	fi
else
	sed -i "/Source/s/openfde-arm64/openfde/" ${dst}/debian/control
	sed -i "/Package/s/openfde-arm64/openfde/" ${dst}/debian/control
	sed -i "1s/openfde-arm64/openfde/" ${dst}/debian/changelog
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

if [ $arm64_only -eq 1 ];then
	echo "tar -cJvpf debian/openfde-arm64_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz "
	tar -cJvpf debian/openfde-arm64_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz
else
	echo "tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz "
	tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz
fi
pushd $dst
#step 4 fill changes
if [ ! -e /usr/bin/dch ];then
	sudo apt install devscripts
fi
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

