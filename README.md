# r6sbuilder
NanoPi R6S用Arch Linuxイメージビルダー  
Armbianカーネルを使用し、Arch Linuxのイメージを作成します

## 環境
- Dockerがインストール済み
- x86_64かarm64

## ビルド方法
```bash
$ ./build.sh
```
`./out`ディレクトリ内に出力されます

## 変更点
- 初期rootパスワードは`root`です
- NICはすべてDHCPでIPアドレス取得

## TODO
- rootfsのパーティションのサイズを起動時に拡大する
