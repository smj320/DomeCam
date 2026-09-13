# 設定メモ

## ブート前の準備

### シリアルコンソールを使えるようにする
boot フォルダ内にある config.txt をテキストエディタで開く。
また、HDMI画面にあがってくるブートのフォントを大きくする。
cmdline.txtにあるquietを削除して、ブートログを表示させるようにする。
ファイルの末尾に以下の行を追記して保存。 

```ini
# config.txt
# シリアルコンソールを有効化
enable_uart=1
# ついでにI2C経由でRTCを設定
dtoverlay=i2c-rtc,ds3231
```

### シリアルコンソールからログインする
* screen /dev/cu.usbserial-xxxx 115200

### ロケールとタイムゾーン
* raspi-config で設定する。設定しておかないとsshでログインしたときに怒られる

### aptやGitを使うのでnmcliでwifiを設定する。
* nmcli device wifi rescan で電波をスキャン
* nmcli device wifi list でSSIDのリストを表示
* nmcli device wifi connect "SSID名" password "パスワード"
* apt install util-linux-extra -y でhwclockをとってくる

### RTCを有効にする
* raspi-config
* Interface Options →「I2C」を選択し、有効化
* rebootして i2cdetect -y 1　で確認、UUになっていれば使われている。
* date で wifi経由の時刻同期を確認
* 時間があっていれば hwclock --systohc で時刻を合わせる

### rootでsshログインできるようにする
* /etc/ssh/sshd_config の PermitRootLogin をyes
* sudo systemctl restart ssh

### sshで接続テストする
* ssh root@xx.xx.xx.xx

### パーティション4をexFATでフォーマット
* apt install exfatprogs
* mkfs.exfat -n video /dev/mmcblk0p3

### exFATパーティションをマウントする
* apt install exfatprogs exfat-fuse でツールをとってくる
* mkdir /root/video/img
* lsblkでデバイスを確認
* blkid /dev/mmcblk0p3 でPARTUUIDを確認
```
/dev/mmcblk0p3: LABEL="video" ... TYPE="exFAT" PARTUUID="2dee52c6-03"
```
* /etc/fstabに追記
```
PARTUUID=2dee52c6-03 /root/video/img  exfat  defaults,uid=0,gid=0,umask=000  0 0
```
* mount -a　と systemctl daemon-reload で反映
* ln -s /mnt/video /root/video でルートからのシンボリックリンクをはる


## アプリケーション的設定


### 録画バッチファイル/root/video/record.shを作る
```
#!/bin/bash
# ログファイル名には開始時の日時を使用
START_TIME=$(date +"%Y%m%d%H%M%S")
LOGFILE="/root/video/img/${START_TIME}.log"

# ffmpegを実行（segment機能で20分ごとに分割保存）
ffmpeg -f v4l2 -input_format mjpeg \
 -video_size 1280x720 -framerate 10 \
 -i /dev/video0 \
 -c:v copy \
 -f segment \
 -segment_time 1200 \
 -segment_format matroska \
 -reset_timestamps 1 \
 -strftime 1 "/root/video/img/%Y%m%d%H%M%S.mkv" 2>&1 | tee "$LOGFILE"
```
オプションの意味は
 -f v4l2 # video for linux 2
 -c:v copy # エンコードせずにコピー

## 自動起動

### サービス登録ファイルの準備
/etc/systemd/system/video.service

```
[Unit]
Description=Video Record Script
After=multi-user.target

[Service]
ExecStartPre=/bin/sleep 5
ExecStart=/bin/bash /root/video/record.sh
WorkingDirectory=/root/video/
StandardOutput=inherit
StandardError=inherit
Restart=always

[Install]
WantedBy=multi-user.target
```

### 登録と実行

* sudo systemctl daemon-reload
* sudo systemctl enable video.service
* sudo systemctl start video.service

## 画像ローテート

crontab.txtに
```
0 * * * * find /root/video/img -type f -mmin +480 -delete
がかいてあるので
crontab crontab.txt　で登録
crontab -l で確認
```

## イメージの複製

```bash
# 1. 接続されているすべてのディスクとパーティションを確認する
diskutil list

# 2. 対象のディスクをアンマウントする（※ NとMは実際のディスク番号に書き換えてください）
# 例: コピー元が /dev/disk2, コピー先が /dev/disk3 の場合
diskutil unmountDisk /dev/disk2
diskutil unmountDisk /dev/disk3

# 3. ディスク間で直接コピーを実行する（if=コピー元, of=コピー先）
sudo dd if=/dev/rdisk2 of=/dev/rdisk3 bs=4m status=progress

# 4. 処理が完全に終了したら、安全に両方のディスクを取り出す
diskutil eject /dev/disk2
diskutil eject /dev/disk3
```
