#!/bin/bash

## Docker内で実行されるスクリプト

ARCH_IMAGE="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
OUTPUT_IMAGE="out/archlinux_nanopi-r6s_$(date +%Y%m%d%H%M).img"

NEED_PACKAGES=(
  curl
  dosfstools
  fdisk
  libarchive-tools
  qemu-user-static
  xz-utils
)

function cleanup() {
  umount /mnt/*
  losetup -d $LOOP_OUT
}

function error_check() {
  echo -e "\e[31m$1\e[m"
  cleanup
  rm -f $OUTPUT_IMAGE
  exit 1
}

# 必要なパッケージをインストール
apt update
apt install -y ${NEED_PACKAGES[@]}

# 出力イメージの作成
truncate -s 1GB $OUTPUT_IMAGE

# ループバックデバイスの作成
LOOP_OUT=$(losetup -fP --show $OUTPUT_IMAGE)   || error_check "Failed to create loop device"

# パーティションの作成
sfdisk $LOOP_OUT < partmap || error_check "Failed to create partition"

# ブートローダーのコピー
dd if=./base/loader.img of=$LOOP_OUT seek=31 bs=512 count=32736 || error_check "Failed to copy bootloader"

# ファイルシステムの作成
mkfs.vfat -n bootfs -F32 ${LOOP_OUT}p1 || error_check "Failed to create filesystem"
mkfs.ext4 -L rootfs ${LOOP_OUT}p2      || error_check "Failed to create filesystem"

# マウント
mkdir /mnt/bootfs /mnt/rootfs

mount ${LOOP_OUT}p1 /mnt/bootfs || error_check "Failed to mount"
mount ${LOOP_OUT}p2 /mnt/rootfs || error_check "Failed to mount"

# /bootのコピー
tar xzvf ./base/bootfs.tgz -C /mnt/bootfs || error_check "Failed to extract bootfs"

# Arch Linuxのrootfsの作成
mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
rm -rf base/rootfs
mkdir base/rootfs
curl -L $ARCH_IMAGE | bsdtar -xpv -C base/rootfs || error_check "Failed to extract Arch Linux rootfs"

# 不要パッケージの削除
chroot base/rootfs pacman -Rs --noconfirm linux-aarch64 linux-firmware || error_check "Failed to remove packages"

# イメージにコピー
cp -a base/rootfs/* /mnt/rootfs/ || error_check "Failed to copy rootfs"

# armbianEnv.txtの作成
cat <<EOF > /mnt/bootfs/armbianEnv.txt
verbosity=1
bootlogo=false
overlay_prefix=rockchip-rk3588
fdtfile=rockchip/rk3588s-nanopi-r6s.dtb
rootdev=UUID=$(blkid -s UUID -o value ${LOOP_OUT}p2)
rootfstype=ext4
EOF

# fstabの作成
cat <<EOF > /mnt/rootfs/etc/fstab
UUID=$(blkid -s UUID -o value ${LOOP_OUT}p2) / ext4 defaults,noatime,commit=600,errors=remount-ro 0 1
UUID=$(blkid -s UUID -o value ${LOOP_OUT}p1) /boot vfat defaults 0 2
tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

# モジュールのコピー
rm -rf /mnt/rootfs/lib/modules
tar xzvf ./base/modules.tgz -C /mnt/rootfs/lib || error_check "Failed to extract modules"

# alarmユーザーの削除
chroot /mnt/rootfs userdel -r alarm

# パスワードの設定(初期rootパスワードはroot)
echo "root:root" | chroot /mnt/rootfs chpasswd

# 次回ログイン時にrootのパスワードを変更するように設定
chroot /mnt/rootfs passwd -e root

# ホスト名の設定
echo "nanopi-r6s" > /mnt/rootfs/etc/hostname

# overlayファイルのコピ
cp -r ./overlay/* /mnt/rootfs/

# sshの設定
chroot /mnt/rootfs sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config

# machine-idの削除
rm -f /mnt/rootfs/var/lib/dbus/machine-id
echo -n > /mnt/rootfs/etc/machine-id

# アンマウント
sync
cleanup

echo -e "\e[32mDone: $OUTPUT_IMAGE\e[m"
