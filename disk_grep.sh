#!/bin/bash
usage() {
    echo "Usage: $(basename $0) file|device string" >&2
    exit 1
}

COLUMNS=$(tput cols)

#pass % complete
progress() {
    DONE=$(( (($COLUMNS-2)*$1)/100 ))
    TODO=$(($COLUMNS-2-$DONE))
    DONE=$(printf "%${DONE}s" | tr ' ' =)
    TODO=$(printf "%${TODO}s" | tr ' ' -)
    printf "[$DONE$TODO]\r" > /dev/tty
}

#pass strings to stdout
print() {
    CLEAR=$(printf "%${COLUMNS}s")
    printf "$CLEAR\r"
    echo "$@"
}

[ $# -ne 2 ] && usage
DISK="$1"
STRING="$2"

export LANG=C

# Note we must manage these limits ourselves
# because dd currently does not fail if you seek
# past the end of a file or device. In fact for devices
# it reads the whole device when you do this!
#
# This also allows us to show completion progress
CHUNK_SIZE=$((8*1024*1024))
if [ -b "$DISK" ]; then
    SIZE=$(/sbin/blockdev --getsize64 $DISK) || exit $? #reads from disk?
else
    SIZE=$(stat --format %s "$DISK") || exit $?
fi
[ $SIZE -eq 0 ] && exit
CHUNKS=$((($SIZE+$CHUNK_SIZE-1)/$CHUNK_SIZE))

i=0
while true; do
    progress $(($i*100/$CHUNKS))
    [ "$i" -ge "$CHUNKS" ] && break
    # use "direct" flag so cache not polluted with read data
    dd if=$DISK iflag=direct conv=noerror bs=$CHUNK_SIZE count=1 skip=$i 2>/dev/null |
    #we ensure grep reads all data, otherwise dd will get SIGPIPE and exit with 141
    grep --binary-files=text -U -F "$STRING" >/dev/null
    status=$(echo ${PIPESTATUS[@]})
    dd_status=$(echo $status | cut -f1 -d ' ')
    re_status=$(echo $status | cut -f2 -d ' ')
    [ $dd_status -ne 0 ] && { echo "dd error" >&2; exit $dd_status; }
    [ $re_status -eq 0 ] && { print "dd if=$DISK iflag=direct bs=$CHUNK_SIZE count=1 skip=$i > disk_grep.$i"; }
    i=$(($i+1))
done
echo
