#!/bin/bash

fde_version=`sudo apt search openfde 2>/dev/null |grep openfde -w |awk -F " " '{print $2}'`
if [ -n "$fde_version" ];then
	sudo apt download openfde
else
	source /etc/os-release
	sudo apt-get install -y wget gpg
	wget -qO-  http://openfde.com/keys/openfde.asc | gpg --dearmor > packages.openfde.gpg
	sudo install -D -o root -g root -m 644 packages.openfde.gpg /etc/apt/keyrings/packages.openfde.gpg
	if [ -z "$PROJECT_CODENAME" ];then
		PROJECT_CODENAME=$VERSION_CODENAME
	fi
	sudo echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/packages.openfde.gpg] http://openfde.com/repos/$ID/ \
  "$(. /etc/os-release && echo "$PROJECT_CODENAME")" main" | \
  sudo tee /etc/apt/sources.list.d/openfde.list > /dev/null
	sudo apt update
fi
sudo rm -rf .images 1>/dev/null 2>&1
set -e 
mkdir .images
dpkg-deb -x openfde_{$fde_version}_arm64.deb .images
pushd .images/usr/openfde
popd 

dst_dir=`ls debian/ -l |grep ^d |awk -F " " '{print $NF}' |tr -d " " |grep ^openfde |sort -rh`
if [ -z "$dst_dir" ];then
	echo "Error: no openfde-x.x.x directory founded locate in debian"
	exit 1
fi
cp -a .images/usr/openfde/waydroid_images.tar debian/$dst_dir
sudo rm -rf .images
sudo rm -rf openfde_{$fde_version}_arm64.deb
