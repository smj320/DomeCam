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
