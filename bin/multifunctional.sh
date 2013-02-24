#!/bin/bash
#
# General all-covering MediaTomb transcoding script.
# This turns EVERYTHING in an mpeg2 stream for PS3 use.
#
# v0.1  2010/06/05
#
#############################################################################

# Change this to enable different subtitle languages.
SUBS="nl,en"

# Change this line to set the average bitrate.
# Use something like 8000 for wired connections; lower to 2000 for wireless.
AVBIT=8000

# Change this line to set the maximum bitrate.
# Use something like 12000 for wired connections; lower to 5000 for wireless.
MVBIT=12000

# Change this line to set the audio bitrate in kbps. 256 is nice.
AABIT=256

# Change this line to set your favourite subtitle font.
SFONT="/etc/mediatomb/DejaVuSans.ttf"

# Change this line to set the size of subtitles. 25 is okay.
SUBSIZE=20

# Enable downscaling of HD content to 720 pixels wide (DVD format)?
DOWNSCALE=1

# If downscaling is enabled, anything over this width will be downscaled.
MAXSIZE=900

# Enable logging to file?
LOGGING=1

# If logging is enabled, log to which file?
LOGFILE="/var/log/mediatomb-transcode.log"

#############################################################################
# Do not change anything below this line.
#############################################################################
# Variables
#############################################################################

FILE=$1

MENCODER=$(which mencoder)
MEDIAINFO=$(which mediainfo)
LSDVD=$(which lsdvd)

MENCOPTS="-oac lavc -ovc lavc -of mpeg -lavcopts \
abitrate=${AABIT}:vcodec=mpeg2video:keyint=1:vbitrate=${AVBIT}:\
vrc_maxrate=${MVBIT}:vrc_buf_size=1835 \
-mpegopts muxrate=12000 -af lavcresample=44100 "
SUBOPTS="-slang ${SUBS} "
SRTOPTS="-font ${SFONT} -subfont-autoscale 0 -subfont-text-scale ${SUBSIZE} -subpos 100 "
SIZEOPTS="-vf harddup,scale=720:-2 "
NOSIZEOPTS="-vf harddup "
S24FPS="23.976"
S24OPT="-ofps 24000/1001"
S30FPS="29.97"
S30OPT="-ofps 30000/1001"
MKVOPTS="-aid 0 -sid 0 "

WIDTH=""
SFPS=""
COMBINEDOPTS=""

#############################################################################
# Functions
#############################################################################

function log {
        if [ "${LOGGING}" == "1" ] ; then       
                echo -e "$(date +'%Y/%m/%d %H:%m:%S') \t $1" >> ${LOGFILE}
        fi
}

function mediainfo {
        MIOUT=$(mktemp /tmp/tmp.mediainfo.XXXXXX)
        log "Tempfile is ${MIOUT}"      
        ${MEDIAINFO} "${FILE}" > ${MIOUT}
        WIDTH=$(grep -e "^Width" ${MIOUT} | sed -e 's/[ ]*//g' -e 's/.*:\(.*\)pixels/\1/')
        SFPS=$(grep -e "^Frame" ${MIOUT} | sed -e 's/[ ]*//g' -e 's/.*:\(.*\)fps/\1/')
        log "Width of ${WIDTH} and FPS of ${SFPS} detected."
        rm -f "${MIOUT}"
}

function setopts {
        SUBLINK=$(mktemp /tmp/tmp.mmsublink.XXXXXX)
        if [ "${DOWNSCALE}" == "1" -a ${WIDTH} -gt ${MAXSIZE} ] ; then
                log "Rescaling to 720 pixels."
                COMBINEDOPTS="${COMBINEDOPTS} ${SIZEOPTS}"
        else
                log "Rescaling disabled or file within limits."
                COMBINEDOPTS="${COMBINEDOPTS} ${NOSIZEOPTS}"
        fi      
        if [ "${SFPS}" == "${S24FPS}" ] ; then
                log "Framerate adjusted for mencoder."
                COMBINEDOPTS="${COMBINEDOPTS} ${S24OPT}" 
        else if [ "${SFPS}" == "${S30FPS}" ] ; then
                COMBINEDOPTS="${COMBINEDOPTS} ${S30OPT}"
        else
                log "Framerate acceptable for mencoder."
        fi
        fi
        if [ -e "$(echo $FILE | sed 's/...$/sub/')" ] ; then
                SUB=$(echo $FILE | sed 's/...$/sub/')
                rm $SUBLINK && ln -s "${SUB}" "${SUBLINK}"
                log "Subtitle found: ${SUB}"
                COMBINEDOPTS="-sub ${TEMPSUB} ${COMBINEDOPTS}"
        else if [ -e "$(echo $FILE | sed 's/...$/srt/')" ] ; then
                SUB=$(echo $FILE | sed 's/...$/srt/')
                rm $SUBLINK && ln -s "${SUB}" "${SUBLINK}"
                log "Subtitle found: ${SUB}"
                COMBINEDOPTS="-sub ${SUBLINK} ${COMBINEDOPTS}"
        else
                log "No external subtitles."
        fi
        fi
}

#############################################################################
# Actual code
#############################################################################

log "Starting MediaTomb Multifunctional Transcoder."
find /tmp/tmp.mmsublink.* -mtime +1 -exec rm {} \;

FEXT=$(echo $FILE | sed 's/.*\.//')

if [ "$(echo $FILE | grep 'http://')" != "" ] ; then
        FEXT="URL"
fi

case $FEXT in
        "iso")
                log "ISO file specified: \"${FILE}\""
                CHAPTER=$(${LSDVD} "${FILE}" | grep Longest | sed 's/.* //')
                log "Chapter ${CHAPTER} selected..."
                COMBINEDOPTS="${MENCOPTS} ${SUBOPTS} ${SIZEOPTS}"
                log "Starting mencoder:"
                log "${MENCODER} -dvd-device \"${FILE}\" dvd://${CHAPTER} ${COMBINEDOPTS} -o \"$2\""
                exec ${MENCODER} -dvd-device "${FILE}" dvd://${CHAPTER} ${COMBINEDOPTS} -o "$2" &>/dev/null &
                ;;
        "ogm" | "mkv")
                log "OGM/MKV file specified: \"${FILE}\""
                mediainfo
                COMBINEDOPTS="${MKVOPTS} ${MENCOPTS} ${SRTOPTS}"
                setopts
                log "Starting mencoder:"
                log "${MENCODER} \"${FILE}\" ${COMBINEDOPTS} -o \"$2\""
                exec ${MENCODER} "${FILE}" ${COMBINEDOPTS} -o "$2" &>/dev/null &
                ;;
        "URL")
                log "URL specified: \"${FILE}\""
                log "Starting mencoder:"
                log "ffmpeg -i \"${FILE}\" -acodec mp2 -vcodec mpeg2video -f mpegts -b ${AVBIT}000 -ab ${AABIT}k -y \"$2\"" 
                exec ffmpeg -i "${FILE}" -acodec mp2 -vcodec mpeg2video -f mpegts -b ${AVBIT}000 -ab ${AABIT}k -y "$2" &>/dev/null &
                ;;
        *)
                log "Regular file specified: \"${FILE}\""
                mediainfo
                COMBINEDOPTS="${MENCOPTS} ${SRTOPTS}"
                setopts
                log "Starting mencoder:"
                log "${MENCODER} \"${FILE}\" ${COMBINEDOPTS} -o \"$2\""
                exec ${MENCODER} "${FILE}" ${COMBINEDOPTS} -o "$2" &>/dev/null &
                ;;
esac    
log "Script ended."