#!/bin/bash

function hardware_summary {
    FILE="$1"
    shift
    HOSTNAME=$(awk -F ':[ \t]*' '/Hostname/ {print $2}' $FILE)
    DATE=$(awk -F ':[ \t]*' '/Date/ {print $2}' $FILE)
    LINUX=$(awk -F ':[ \t]*' '/Description/ {print $2}' $FILE)
    CPU=$(awk -F ':[ \t]*' '/model name/ {print $2}' $FILE)
    read KERNEL RTAI PATCH < <(sed -n -e '/Versions/,/^$/{/kernel/p; /rtai/p; /patch/p}' $FILE | awk -F ': ' '{print $2}' | awk '{printf( "%s ", $1 )}')
    read MBPRODUCT MBVENDOR MBVERSION < <(sed -n -e '/\*-core/,/\*-/{/product/p; /vendor/p; /version/p}' $FILE | awk -F ': ' '{printf( "%s ", $2)}')
    KERNELCFG=": [kernel configuration](${1##*/})"
    CFGFILE=$1
    for CF in $@; do
	if ! diff -q $CFGFILE $CF &> /dev/null; then
	    KERNELCFG=""
	    break
	fi
    done
    

    echo "# ${HOSTNAME}: ${RTAI} on ${KERNEL} linux kernel"
    echo
    echo "tested on ${DATE}"
    echo
    echo "## RTAI-patched linux kernel and machine"
    echo
    echo "Linux kernel version *${KERNEL}* patched with *${PATCH}* of *${RTAI}*${KERNELCFG}"
    echo
    echo "*${CPU}* on a *${MBVENDOR} ${MBPRODUCT}* motherboard (version *${MBVERSION}*)"
    echo
}


function kernel_parameter {
    FILE="$1"
    echo "## Kernel parameter:"
    sed -n -e '/Kernel parameter/,/^$/{s/^  //; p}' $FILE | sed -e '1d; /BOOT/d; /^root/d; /^ro$/d; /^quiet/d; /^splash/d; /^vt.handoff/d; /panic/d;' | while read LINE; do test -n "$LINE" && echo "* $LINE"; done
    echo
}


function performance_header {
    FILE="$1"

    DIR=$(dirname $0)

    N=$($DIR/../../makertai/makertaikernel.sh report -f dat --select kern_latencies:n -u $FILE | grep -v '^#')
    N=$(echo $N)

    echo "## Performance"
    echo
    echo "kern/latency test for ${N} seconds."
    echo "Reported is the mean, standard deviation and the maximum value of the jitter (\`lat max - lat min\`) in nanoseconds."
    echo
}


function performance_data {
    TITLE="$1"
    shift
    PLOTFILE="$1"
    shift
    SORTCOL="$1"
    shift

    DIR=$(dirname $0)

    SHOW_COLUMNS=(
	$SORTCOL
	kern_latencies:mean_jitter
	kern_latencies:stdev
	kern_latencies:max
	tests:link
    )

    KERNELCFG="[kernel configuration](config${1##*/latencies})"
    CFGFILE=${1/latencies-/config-}
    for CF in $@; do
	if ! diff -q $CFGFILE ${CF/latencies-/config-} &> /dev/null; then
	    KERNELCFG=""
	    break
	fi
    done

    echo "### $TITLE"
    echo
    if test -n "$KERNELCFG"; then
	echo "$KERNELCFG"
	echo
    fi
    echo "Kernel parameter:"
    sed -n -e '/Kernel parameter/,/^$/{s/^  //; p}' "${@: -1}" | sed -e '1d; /BOOT/d; /^root/d; /^ro$/d; /^quiet/d; /^splash/d; /^vt.handoff/d; /panic/d;' | while read LINE; do test -n "$LINE" && echo "* $LINE"; done
    echo
    $DIR/../../makertai/makertaikernel.sh report -f md ${SHOW_COLUMNS[@]/#/--select } -s "$SORTCOL" -g $DIR/$PLOTFILE -u -m 'none' $@ | sed -e 's/ jitter//'
    echo
    echo "![$PLOTFILE]($PLOTFILE)"
    echo
    echo
}


function performance_summary {
    SHOW_COLUMNS=(
	data:machine
	data:num
	kern_latencies:mean_jitter
	kern_latencies:stdev
	kern_latencies:max
    )

    MACHINE=$(cd ${1%/*}; basename $PWD)

    $DIR/../../makertai/makertaikernel.sh report -f md ${SHOW_COLUMNS[@]/#/--select } --add "machine=[$MACHINE]($MACHINE/report.md)" -u avg $@ > summary.md
}
