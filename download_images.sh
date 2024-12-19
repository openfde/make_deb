#!/bin/bash

fde_version=`sudo apt search openfde 2>/dev/null |grep openfde -w |awk -F " " '{print $2}'`
if [ -z "$fde_version" ];then
	source /etc/os-release
	sudo apt-get install -y wget gpg
	wget -qO-  http://openfde.com/keys/openfde.asc | gpg --dearmor > packages.openfde.gpg
	sudo install -D -o root -g root -m 644 packages.openfde.gpg /etc/apt/keyrings/packages.openfde.gpg
	if [ -z "$PROJECT_CODENAME" ];then
		PROJECT_CODENAME=$VERSION_CODENAME
	fi
	sudo echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/packages.openfde.gpg] http://openfde.com/repos/$ID/ \
  "$(echo "$PROJECT_CODENAME")" main" | \
  sudo tee /etc/apt/sources.list.d/openfde.list > /dev/null
fi
sudo apt update
if [ -z "$fde_version" ];then
	fde_version=`sudo apt search openfde 2>/dev/null |grep openfde -w |awk -F " " '{print $2}'`
fi
echo "step 1: downloading openfde debs"
sudo apt download openfde
sudo rm -rf .images 1>/dev/null 2>&1
set -e 
mkdir .images
echo "step 2: extracting debs"
dpkg-deb -x openfde_${fde_version}_arm64.deb .images
pushd .images/usr/openfde
popd 
n=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " " |grep ^openfde |wc -l`
if [ $n -gt 1 ];then
	echo "Error: more than one openfde-x.x.x directory found located in debian"
	exit 1
fi
dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " " |grep ^openfde |sort -rh`
if [ -z "$dst_dir" ];then
	echo "Error: no openfde-x.x.x directory found located in debian"
	exit 1
fi
cp -a .images/usr/openfde/waydroid_image.tar debian/$dst_dir
echo "Tips: copy waydroid_image.tar to debian/$dst_dir successfully. Now you can run mkdeb.sh to make debs without repacking android images."
sudo rm -rf .images
sudo rm -rf openfde_${fde_version}_arm64.deb

