#!/bin/bash


sudo rm -rf vendorimg systemimg
sudo rm -rf orig system vendor 
mkdir orig -p
sudo mount system.img orig
systemUsed=`df -m |grep -w orig | awk -F " " '{print $3}'`
actualUsed=`expr $systemUsed + 200`
echo "dd if=/dev/zero of=systemimg bs=1M count=$actualUsed"
dd if=/dev/zero of=systemimg bs=1M count=$actualUsed
sudo mkfs.ext4 systemimg
mkdir system -p 
mkdir vendor -p
echo "mount image"
sudo mount systemimg system
echo "copy system"
sudo cp -a orig/* system/
if [ $? != 0 ];then
	echo "Error: copy system failed"
	exit 1
fi
sudo rm -rf  system/system/product/app/LatinIME/
sudo rm -rf system/system/media/bootanimation.zip
sudo mkdir system/system/product/app/iflytek
#sudo mkdir system/volumes
sudo cp -a iflytek.apk system/system/product/app/iflytek
if [ $? != 0 ];then
	echo "Error: copy iflytek failed"
	exit 1
fi
sudo mkdir system/system/product/app/viabrowse
sudo cp -a via.apk system/system/product/app/viabrowse/
if [ $? != 0 ];then
	echo "Error: copy yingyongbao failed"
	exit 1
fi
sudo umount orig
sudo umount system

echo "make vendorimg"
dd if=/dev/zero of=vendorimg bs=1M count=500
sudo mkfs.ext4 vendorimg
sudo mount vendor.img orig
sudo mount vendorimg vendor
sudo cp -a orig/* vendor/
if [ $? != 0 ];then
	echo "Error: copy vendor failed"
	exit 1
fi
#install x100 libs
#sudo cp -a install_new/vendor/* vendor
sudo umount orig
sudo umount vendor

sudo rm -rf orig system vendor 
