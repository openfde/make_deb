#!/bin/bash

if [ $# -ne  4 ];then
	echo "mkdeb.sh 1.0.1 14|11 arm64only|x86 1"
	exit 1
fi

set -e
verNum=$4
ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
fi
openfde11=0
openfde14=0
openfde17=0
arm64_only=0
x86=0
if [ "$2" = "14" ];then
    openfde14=1
    working_path="debian/openfde14"
elif [ "$2" = "11" ];then
    openfde11=1
    working_path="debian/openfde"
elif [ "$2" = "17" ];then
    openfde17=1
    working_path="debian/openfde17"
else
    echo "the secondary args must be one of the 11,14,17"
    exit 1
fi

if [ "$3" = "x86" ];then
	echo "x86 arch"
	x86=1
elif [ "$3" = "arm64only" ];then
	echo "arm64only arch"
	arm64_only=1
fi

echo "find gbiner.so"
sudo find /usr -name "gbinder.cpython*-linux-gnu.so" > /tmp/gbinder.list
n=`cat /tmp/gbinder.list |wc -l`
if  [  $n = 0  ] ;then
	echo "Error: cant't find gbinder.cpython*-linux-gnu.so "
	exit 1
fi

find debian -maxdepth 1 -name "openfde*" -type d -exec rm -rf {} \;

if [ $arm64_only -eq 1 ];then
    working_path=${working_path}-arm64-$ver
else
    working_path=${working_path}-$ver
fi
mkdir -p $working_path

openfde_dir=`ls debian/ -ln |grep ^d |grep openfde* |awk -F " " '{print $NF}' |tr -d " "`
dst=debian/$openfde_dir

sudo cp -a debian/realdebian $dst/debian
dirname=`find $dst/debian/ -maxdepth 1 -type d -name "openfde*" |awk -F "/" '{print $NF}'`

# openfde11 doesn't support arm64only
if [ "$openfde11" -eq 1 ] && [ "$arm64_only" -eq 1 ]; then
    echo "Error: aosp11 doesn't support arm64 only."
    exit 1
fi

# keep old behavior: only support 11/14/17 in this block
if [ "$openfde11" -ne 1 ] && [ "$openfde14" -ne 1 ] && ["$openfde17" -ne 1 ]; then
    echo "mode must in 14|11|17"
    exit 1
fi

# e.g. debian/openfde14-arm64-1.0.1 -> openfde14-arm64
target="${working_path##*/}"
target="${target%-$ver}"

if [ "$dirname" != "$target" ]; then
    echo "mv $dst/debian/$dirname to $dst/debian/$target"
    sudo mv "$dst/debian/$dirname" "$dst/debian/$target"
fi

sudo rm -rf list/waydroidlist
sudo find /usr -name "gbinder.cpython*-linux-gnu.so" >> list/waydroidlist

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
sudo apt install -y debhelper
if [ "$DISTRIB_ID" = "Kylin" ];then
	cat list/kylinfde.list |sudo tee -a list/waydroidlist  1>/dev/null
	cp -a debian/control.kylinv10sp1 ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Debian" ];then
	if [ ! -e /usr/bin/dch ];then
		sudo apt install devscripts -y
	fi
	cp -a debian/control.debian_$VERSION_CODENAME ${dst}/debian/control
elif [ "$DISTRIB_ID" = "Ubuntu" ];then
	cat list/mutter.list |sudo tee -a list/waydroidlist 1>/dev/null
	cp -a debian/control.ubuntu_$DISTRIB_CODENAME ${dst}/debian/control
elif [ "$DISTRIB_ID" == "uos" ] ;then
	cp -a debian/control.uos20eagle ${dst}/debian/control
elif [ "$DISTRIB_ID" == "Deepin" ] ;then
	cp -a debian/control.deepin_$DISTRIB_CODENAME ${dst}/debian/control
fi


# 1) decide base package + changelog source
case 1 in
  $openfde11)
    base_pkg="openfde"
    changelog_file="debian/changelog.openfde11"
    ;;
  $openfde14)
    base_pkg="openfde14"
    changelog_file="debian/changelog.openfde14"
    ;;
  $openfde17)
    base_pkg="openfde17"
    changelog_file="debian/changelog.openfde17"
    ;;
  *)
    echo "Error: invalid mode, must be 11|14|17"
    exit 1
    ;;
esac

# 2) final package name
pkg="$base_pkg"
if [ "$arm64_only" -eq 1 ]; then
  pkg="${base_pkg}-arm64"
fi

# 3) copy changelog
sudo cp -a "$changelog_file" "${dst}/debian/changelog"

# 4) optional architecture override
if [ "$x86" -eq 1 ]; then
  sudo sed -i "/Architecture/s/:.*/: amd64/" "${dst}/debian/control"
fi

# 5) set Source/Package in one pass
sudo sed -i -E \
  -e "/^(Source|Package):/s@:.*@: ${pkg}@" \
  "${dst}/debian/control"

# 6) arm64 changelog package name fix (only needed for 14/17 templates)
if [ "$arm64_only" -eq 1 ] && [ "$openfde11" -ne 1 ]; then
  sudo sed -i "1s/^openfde.*(/${pkg} (/" "${dst}/debian/changelog"
fi

sudo chmod a+x ${dst}/debian/changelog
if [ -z "$verNum" ];then
	verNum=1
fi
verDate=`date "+%Y%m%d"`    
verID=`echo $DISTRIB_ID | tr '[:upper:]' '[:lower:]' `
if [ "$DISTRIB_ID" = "Ubuntu" ];then
	verID=`echo $DISTRIB_CODENAME | tr '[:upper:]' '[:lower:]' `
fi
sed -i "1s/(.*)/($ver-$verDate$verID$verNum)/" ${dst}/debian/changelog


#step 1 tar fde
echo "Step 1: will tar file from the below list"
tar -zcvpf $dst/fde.tar -T list/fde.list
d=`date +%Y%m%d`
echo "sed images for ro.openfde.version"
sudo sed -i "/ro.openfde.version/s/ro.openfde.version.*/ro.openfde.version=$ver-$d\")/" /usr/lib/waydroid/tools/helpers/images.py 
tar -zcvpf $dst/waydroid.tar -T list/waydroidlist

#step 2 pack images

#echo "Step 2: want to repack android images from /usr/share/waydroid-extra/images? y/n[n]"
#read choice 
#if [ -z "$choice" ];then
#	choice=n
#else
#	if [ "$choice" != "n" ];then
#		choice=y
#	fi
#fi
#if [ "$choice" = "y" ];then
	sudo tar -cvpf -  /usr/share/waydroid-extra |xz -T0 > $dst/waydroid_image.tar
#fi

#step 3 make src.xz

if [ $arm64_only -eq 1 ];then
	if [ $openfde11 -eq 1 ];then
		tarfile=openfde-arm64_${ver}.orig.tar.xz
	elif [ $openfde14 -eq 1 ];then
		tarfile=openfde14-arm64_${ver}.orig.tar.xz
	elif [ $openfde17 -eq 1 ];then
		tarfile=openfde14-arm64_${ver}.orig.tar.xz
	fi
elif [ $openfde11 -eq 1 ];then
	tarfile=openfde_${ver}.orig.tar.xz
elif [ $openfde14 -eq 1 ];then
	tarfile=openfde14_${ver}.orig.tar.xz
elif [ $openfde17 -eq 1 ];then
	tarfile=openfde17_${ver}.orig.tar.xz
fi
echo "tar -cvpf -  -C $dst fde.tar   waydroid.tar  |xz -T0 > debian/$tarfile"
tar -cvpf -  -C $dst fde.tar  waydroid.tar |xz -T0 > debian/$tarfile

#step 4 fill changes
#pushd $dst
#if [ ! -e /usr/bin/dch ];then
#	sudo apt install devscripts -y
#fi
#dch -i 
#popd 

#step 5 make debs
dst_dir=`ls debian/ -nl |grep ^d |grep openfde* |awk -F " " '{print $NF}' |tr -d " "`
pushd debian/$dst_dir
sudo DEB_BUILD_OPTIONS="parallel=4" XZ_DEFAULTS="-T0" dpkg-buildpackage -us -uc
if [ $? != 0 ];then
	echo "Error: make deb failed."
	popd
	exit 1
fi
popd
echo "deb file generated at debian/"


if [ $openfde11 -eq 1 ];then
	sudo cp -a $dst/debian/changelog debian/changelog.openfde11 
elif [ $openfde14 -eq 1 ];then 
	sudo cp -a $dst/debian/changelog debian/changelog.openfde14
elif [ $openfde17 -eq 1 ];then 
	sudo cp -a $dst/debian/changelog debian/changelog.openfde17
fi
sudo rm $dst/debian/changelog
