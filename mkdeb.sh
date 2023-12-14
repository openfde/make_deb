#!/bin/bash

ver=$1
if [ -z "$ver" ];then
	echo "Error: please input a version "
	exit 1
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
tar -cJvpf debian/openfde_${ver}.orig.tar.xz  -C $dst fde.tar  tigervnc.tar.gz waydroid_image.tar  waydroid.tar

pushd $dst
dch -i 
popd 
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


#step 3
#echo "Step 3: want to retar debs y/n[n]?"
#read choice 
#if [ -z "$choice" ];then
#	choice=n
#else
#	if [ "$choice" != "n" ];then
#		choice=y
#	fi
#fi
#if [ "$choice" = "y" ];then
#	echo "Tips: retar debs"
#	tar -zcvpf data/debs.tar  debs   
#fi


#step 4 tar libs
#echo "Step 4: tar libs"
#tar -cvpf data/libs.tar libs

#step 4 tar data
#tar -cvpf data.tar data
#step 4 composite run.sh
#echo "Step Last: make install.run by compositing install.sh data.tar together"
#sym=`date +%F_%H-%M-%S`
#cat install.sh data.tar > fdeinstall_"$sym"_"$ver".run
#rm -rf data.tar
