#!/bin/bash

## ホスト鍵の再生成
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server
systemctl restart ssh

## クリーンアップ
rm -f /firstboot.sh
systemctl disable firstboot
