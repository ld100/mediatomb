#!/bin/bash
#
# General all-covering MediaTomb transcoding script.
#
#############################################################################
# Edit the parameters below to suit your needs.
#############################################################################

# Subtitles imply transcoding; set to 1 to disable subtitle rendering.
# For divx this doesn't matter much but for mp4, mkv and DVD it does.
DISABLESUBS=1

# Change this to enable different DVD subtitle languages.
SUBS="ru,en"

# Change this line to set the average bitrate.
# Use something like 8000 for wired connections; lower to 2000 for wireless.
AVBIT=8000

# Change this line to set the maximum bitrate.
# Use something like 12000 for wired connections; lower to 5000 for wireless.
MVBIT=12000

# Change this line to set the MPEG audio bitrate in kbps. AC3 is fixed to 384.
AABIT=256

# Change this line to set your favourite subtitle font.
#SFONT="/etc/mediatomb/DejaVuSans.ttf"
SFONT="/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf"

# Change this line to set the size of subtitles. 20-25 is okay.
SUBSIZE=20

# Enable downscaling of transcoded content to 720 pixels wide (DVD format)?
DOWNSCALE=1

# If downscaling is enabled, anything over this width (pixels) will be downscaled.
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
VERSION="0.12"

MENCODER=$(which mencoder)
MEDIAINFO=$(which mediainfo)
FFMPEG=$(which ffmpeg)
LSDVD=$(which lsdvd)
XML=$(which xmlstarlet)

M_TR_M="-oac lavc -ovc lavc -of mpeg -lavcopts \
    abitrate=${AABIT}:vcodec=mpeg2video:keyint=1:vbitrate=${AVBIT}:\
    vrc_maxrate=${MVBIT}:vrc_buf_size=1835 \
    -mpegopts muxrate=12000 -af lavcresample=44100 "
M_TR_A="-oac lavc -ovc copy -of mpeg -lavcopts \
    abitrate=${AABIT} -af lavcresample=44100 "
M_RE_M="-oac copy -ovc copy -of mpeg -mpegopts format=dvd -noskip -mc 0 "
F_TR_M="-acodec ac3 -ab 384k -vcodec copy -vbsf h264_mp4toannexb -f mpegts -y "
F_RE_M="-acodec copy -vcodec copy -vbsf h264_mp4toannexb -f mpegts -y "
SUBOPTS="-slang ${SUBS} "
SRTOPTS="-font ${SFONT} -subfont-autoscale 0 \
    -subfont-text-scale ${SUBSIZE} -subpos 100 "
SIZEOPTS="-vf harddup,scale=720:-2 "
NOSIZEOPTS="-vf harddup "
S24FPS="23.976"
S24OPT="-ofps 24000/1001 "
S30FPS="29.970"
S30OPT="-ofps 30000/1001 "

VCODEC=""
ACODEC=""
VWIDTH=""
VFPS=""
QPEL=""
AVCPROF=""

OPTS=("")

declare -i MODE=0

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
        log "Logging mediainfo XML to ${MIOUT}."
        ${MEDIAINFO} --output=xml "${FILE}" > ${MIOUT}
        VCODEC=$(${XML} sel -t -m ".//track[@type='Video']" -v "Format" ${MIOUT} )
        ACODEC=$(${XML} sel -t -m ".//track[@type='Audio']" -v "Format" ${MIOUT} )
        VWIDTH=$(${XML} sel -t -m ".//track[@type='Video']" -v "Width" \ 
            ${MIOUT} | sed 's/ pixels//' )
        VFPS=$(${XML} sel -t -m ".//track[@type='Video']" -v "Frame_rate" \ 
            ${MIOUT} | sed 's/ fps//' )
        AVCPROF=$(${XML} sel -t -m ".//track[@type='Video']" -v "Format_profile" \
            ${MIOUT} | sed 's/[^0-9]//g' )
        QPEL=$(${XML} sel -t -m ".//track[@type='Video']" -v "Format_settings__QPel" \
            ${MIOUT} )
        log "Variables found: \
            ${VCODEC} | ${ACODEC} | ${VWIDTH} | ${VFPS} | ${AVCPROF} | ${QPEL} "
        rm -f ${MIOUT}
}

function tropts {
        if [ "${DOWNSCALE}" == "1" -a ${VWIDTH} -gt ${MAXSIZE} ] ; then
                log "Rescaling to 720 pixels wide."
                OPTS+=(${SIZEOPTS})
        else
                log "Rescaling disabled or file within limits."
                OPTS+=(${NOSIZEOPTS})
        fi
        if [ "${VFPS}" == "${S24FPS}" ] ; then
                log "Framerate adjusted for mencoder."
                OPTS+=(${S24OPT})
        else if [ "${VFPS}" == "${S30FPS}" ] ; then
                log "Framerate adjusted for mencoder."
                OPTS+=(${S30OPT})
        else
                log "Framerate acceptable for mencoder."
        fi
        fi
}

function getmode {
        # Fixed case: DVD ISO.
        if [ "${FEXT}" == "ISO" ] ; then
                CHAPTER=$(${LSDVD} "${FILE}" | grep Longest | sed 's/.* //')
                log "DVD iso image found: Longest chapter is ${CHAPTER}."
                MODE+=${DISABLESUBS}1000000
                return 0
        fi
        # Fixed case: subtitle found: transcode by default.
        if [ "${DISABLESUBS}" == "0" -a -e "$(echo $FILE | sed 's/...$/sub/')" ] ; then
                log "SRT subtitle found."
                SUB=$(echo $FILE | sed 's/...$/sub/')
                MODE+=100000
                return 0
        elif [ "${DISABLESUBS}" == "0" -a -e "$(echo $FILE | sed 's/...$/srt/')" ] ; then
                log "SUB subtitle found."
                SUB=$(echo $FILE | sed 's/...$/srt/')
                MODE+=100000
                return 0
        fi

        log "No subtitles found, or subtitle rendering disabled."
        mediainfo

        case ${VCODEC} in
        "AVC")
                if [ "${AVCPROF}" -gt "41" ] ; then
                        # Cannot handle h.264 4.1+
                        MODE+=10000     
                else          
                        # We can handle the rest                          
                        MODE+=1         
                fi ;;
        "MPEG-4 Visual")
                if [ "${QPEL}" == "No" ] ; then
                        # No QPEL: we could remux the video         
                        MODE+=100       
                else            
                        # QPEL: just transcode it all                        
                        MODE+=10000     
                fi ;;
        * )
                        # Transcode everything we don't know
                        MODE+=10000 ;;  
        esac

        case ${ACODEC} in
        "AC-3" | "MPEG Audio" )      
                        # These should be wellknown                   
                        MODE+=1 ;;      
        * )
                if [ "${MODE}" -lt "100" ] ; then    
                        # If video is AVC, transcode audio in m2ts   
                        MODE+=10        
                else     
                        # Otherwise in other container                       
                        MODE+=1000      
                fi ;;
        esac

}

function processmode {
        log "Mode is ${MODE}."
        if [ ! "${MODE}" -lt "10000000" ] ; then
                EXEC="${MENCODER} -dvd-device"
                OPTS+=(dvd://${CHAPTER} ${M_RE_M} -o )
        elif [ ! "${MODE}" -lt "1000000" ] ; then
                EXEC="${MENCODER} -dvd-device"
                OPTS+=(dvd://${CHAPTER} ${SUBOPTS} ${M_TR_M} -o )
        elif [ ! "${MODE}" -lt "100000" ] ; then
                EXEC=${MENCODER}
                tropts
                OPTS+=(${M_TR_M} -sub ${SUB} ${SRTOPTS} -o )
        elif [ ! "${MODE}" -lt "10000" ] ; then
                EXEC=${MENCODER}
                tropts
                OPTS+=(${M_TR_M} -o )
        elif [ ! "${MODE}" -lt "1000" ] ; then
                EXEC=${MENCODER}
                tropts
                OPTS+=(${M_TR_M} -o)
        elif [ ! "${MODE}" -lt "100" ] ; then
                EXEC=${MENCODER}
                OPTS+=(${M_TR_M} -o)
        elif [ ! "${MODE}" -lt "10" ] ; then
                EXEC="${FFMPEG} -i"
                OPTS+=(${F_TR_M})
        elif [ ! "${MODE}" -lt "1" ] ; then
                EXEC="${FFMPEG} -i"
                OPTS+=(${F_RE_M})
        else
                log "I'm sorry Dave, I'm afraid I can't do mode=0."
        fi
}

#############################################################################
# Main method
#############################################################################

log "Starting MediaTomb Multifunctional Transcoder (version ${VERSION})."
FEXT=$(echo $FILE | sed 's/.*\.//' | tr [a-z] [A-Z])
log "${FEXT} file specified: \"${FILE}\""

getmode
processmode

log "Starting exec:"
log "${EXEC} \"${FILE}\" ${OPTS[@]} ${2} &>/dev/null"
exec ${EXEC} "${FILE}" ${OPTS[@]} "${2}" &>/dev/null
