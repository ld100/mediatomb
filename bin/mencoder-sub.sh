#!/bin/bash
exec mencoder "$(echo $1 | sed 's/...$/avi/')" \
-oac lavc -ovc lavc -of mpeg \
-lavcopts vcodec=mpeg2video:keyint=1:vbitrate=2000:vrc_maxrate=8000:vrc_buf_size=1835 \
-vf harddup,scale -zoom -xy 720 -mpegopts muxrate=12000 \
-sub "$1" -font "/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf" \
-subfont-autoscale 0 -subfont-text-scale 25 -subpos 100 \
-o "$2" &>/dev/null