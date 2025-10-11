#!/bin/bash

if [ $# -ne  2 ];then
	echo "mkdeb.sh 1.0.1 arm64only|14|11"
	exit 1
fi

set -e
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi
openfde11=0
openfde14=0
arm64_only=0
if [ "$2" = "14" ];then
	openfde14=1
elif [ "$2" = "11" ];then
	openfde11=1
else
	echo "arm64only mode"
	arm64_only=1
fi

if [ ! -e ~/gbinder-python/dist/gbinder-python-1.0.0.tar.gz  ];then
	echo "Error: ~/gbinder-python/dist/gbinder-python-1.0.0.tar.gz not exist. please build the project gbinder-python with python3 setup.py sdist --cython "
	exit 1
fi

num=`ls debian -ln |grep ^d |grep openfde* |wc -l`
if [ $num -ne 1 ];then
	echo "Error: more than one directory like openfde-x.x.x exist. please remove the useless one"
	exit 1 
fi
dst_dir=`ls debian/ -ln |grep ^d |grep openfde* |awk -F " " '{print $NF}' |tr -d " "`

dst=debian/$dst_dir
if [ $arm64_only -eq 1 ];then
	if [ "$dst" != "debian/openfde-arm64-$ver" ];then
		echo "mv $dst to debian/openfde-arm64-$ver"
		sudo mv $dst debian/openfde-arm64-$ver
		dst="debian/openfde-arm64-$ver"
	fi
	sudo rm -rf $dst/debian
	sudo cp -a debian/realdebian $dst/debian
	dirname=`find $dst/debian/ -maxdepth 1 -type d -name "openfde*" |awk -F "/" '{print $NF}'`
	if [ "$dirname" != "openfde-arm64" ];then
		echo "mv $dst/debian/$dirname to $dst/debian/openfde-arm64"
		sudo mv $dst/debian/$dirname $dst/deian/openfde-arm64
	fi
elif [ $openfde11 -eq 1 ];then
	if [ "$dst" != "debian/openfde-$ver" ];then
		echo "mv $dst to debian/openfde-$ver"
		sudo mv $dst debian/openfde-$ver
		dst="debian/openfde-$ver"
	fi
	sudo rm -rf $dst/debian
	sudo cp -a debian/realdebian $dst/debian
	dirname=`find $dst/debian/ -maxdepth 1 -type d -name "openfde*" |awk -F "/" '{print $NF}'`
	if [ "$dirname" != "openfde" ];then
		echo "mv $dst/debian/$dirname to $dst/debian/openfde"
		sudo mv $dst/debian/$dirname $dst/debian/openfde
	fi
elif  [ $openfde14 -eq 1 ];then
	if [ "$dst" != "debian/openfde14-$ver" ];then
		echo "mv $dst to debian/openfde14-$ver"
		sudo mv $dst debian/openfde14-$ver
		dst="debian/openfde14-$ver"
	fi
	sudo rm -rf $dst/debian
	sudo cp -a debian/realdebian $dst/debian
	dirname=`find $dst/debian/ -maxdepth 1 -type d -name "openfde*" |awk -F "/" '{print $NF}'`
	if [ "$dirname" != "openfde14" ];then
		echo "mv $dst/debian/$dirname to $dst/debian/openfde14"
		sudo mv $dst/debian/$dirname $dst/debian/openfde14
	fi
else
	echo "mode must in 14|arm64only|11"
	exit 1
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
if [ "$DISTRIB_ID" != "uos" -a "$DISTRIB_ID" != "Deepin" ];then
	cat list/mutter.list |sudo tee -a list/waydroidlist 1>/dev/null
fi
if [ "$DISTRIB_ID" = "Kylin" ];then
	cat list/kylinmutter.list |sudo tee -a list/waydroidlist  1>/dev/null
	cat list/kylinfde.list |sudo tee -a list/waydroidlist  1>/dev/null
	cp -a debian/control.kylinv10sp1 ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Debian" ];then
	if [ ! -e /usr/bin/dch ];then
		sudo apt install devscripts -y
	fi
	cp -a debian/control.debian_$VERSION_CODENAME ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Ubuntu" ];then
	sudo apt install -y debhelper
	cp -a debian/control.ubuntu_$DISTRIB_CODENAME ${dst}/debian/control
elif [ "$DISTRIB_ID" == "uos" ] ;then
	cp -a debian/control.uos20eagle ${dst}/debian/control
elif [ "$DISTRIB_ID" == "Deepin" ] ;then
	cp -a debian/control.deepin_$DISTRIB_CODENAME ${dst}/debian/control
fi

sudo cp debian/changelog.openfde ${dst}/debian/changelog
if [ $arm64_only -eq 1 ];then
	sudo sed -i "/Source/s/:.*/: openfde-arm64/" ${dst}/debian/control
	sudo sed -i "/Package/s/:.*/: openfde-arm64/" ${dst}/debian/control
	sudo sed -i "1s/^openfde.*(/openfde-arm64 (/" ${dst}/debian/changelog
elif [ $openfde11 -eq 1 ];then
	sudo sed -i "/Source/s/:.*/: openfde/" ${dst}/debian/control
	sudo sed -i "/Package/s/:.*/: openfde/" ${dst}/debian/control
	sudo sed -i "1s/^openfde.*(/openfde (/" ${dst}/debian/changelog
elif [ $openfde14 -eq 1 ];then
	sudo sed -i "/Source/s/:.*/: openfde14/" ${dst}/debian/control
	sudo sed -i "/Package/s/:.*/: openfde14/" ${dst}/debian/control
	sudo cp -a debian/changelog.openfde14 ${dst}/debian/changelog
fi
sudo chmod a+x ${dst}/debian/changelog


#step 1 tar fde
echo "Step 1: will tar file from the below list"
tar -zcvpf $dst/fde.tar -T list/fde.list
d=`date +%Y%m%d`
echo "sed images for ro.openfde.version"
sudo sed -i "/ro.openfde.version/s/ro.openfde.version.*/ro.openfde.version=$ver-$d\")/" /usr/lib/waydroid/tools/helpers/images.py 
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
	tarfile=openfde-arm64_${ver}.orig.tar.xz
elif [ $openfde11 -eq 1 ];then
	tarfile=openfde_${ver}.orig.tar.xz
elif [ $openfde14 -eq 1 ];then
	tarfile=openfde14_${ver}.orig.tar.xz
fi
echo "tar -cvpf -  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz |xz -T0 > debian/$tarfile"
tar -cvpf -  -C $dst fde.tar  waydroid_image.tar  waydroid.tar gbinder-python-1.0.0.tar.gz |xz -T0 > debian/$tarfile
pushd $dst
#step 4 fill changes
if [ ! -e /usr/bin/dch ];then
	sudo apt install devscripts -y
fi
dch -i 
popd 

#step 5 make debs
dst_dir=`ls debian/ -nl |grep ^d |grep openfde* |awk -F " " '{print $NF}' |tr -d " "`
pushd debian/$dst_dir
sudo DEB_BUILD_OPTIONS="parallel=4" dpkg-buildpackage -us -uc
if [ $? != 0 ];then
	echo "Error: make deb failed."
	popd
	exit 1
fi
popd
echo "deb file generated at debian/"

if [ $arm64_only -eq 1  -o $openfde11 -eq 1 ];then
	sudo cp -a $dst/debian/changelog debian/changelog.openfde11 
elif [  $openfde14 -eq 1 ];then 
	sudo cp -a $dst/debian/changelog debian/changelog.openfde14
fi
sudo rm $dst/debian/changelog
