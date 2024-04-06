#!/bin/bash

SRC_DIR=$(dirname $(readlink -f $0))

# Dockerがインストールされているか確認
if ! [ -x "$(command -v docker)" ]; then
  echo 'Error: docker is not installed.' >&2
  exit 1
fi

cd $SRC_DIR

# 作業用ディレクトリの作成
mkdir -p out

docker run -it --rm --privileged \
  --name r6s-builder \
  -v /dev:/dev \
  -v $SRC_DIR:/work \
  -w /work \
  ubuntu:22.04 \
  bash /work/lib/docker.sh

if [ $? -ne 0 ]; then
  echo -e "\n\e[31mFailed to build\e[m"
  exit 1
fi
