#!/bin/bash

## ubuntuユーザーの作成
useradd -m -s /bin/bash -G sudo ubuntu
echo "ubuntu:ubuntu" | chpasswd
passwd -e ubuntu

## ホスト鍵の再生成
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server
systemctl restart ssh

## クリーンアップ
rm -f /firstboot.sh
systemctl disable firstboot
