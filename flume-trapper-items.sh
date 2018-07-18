#!/usr/bin/env bash
#############################################################
# Zabbix Trapper Items for Flume Template
#############################################################
# Author Valeriy Soloviov <weldpua2008@gmail.com> 
#  - 3.4.2018
#############################################################
if [[ " ${ARGS[@]} " =~ " debug " ]]; then
    set -x
fi


FLUME_METRICS_HOST="${1:-}"
FLUME_METRICS_PORT="${2:-}"
FLUME_METRICS_URI="${3:-}"
FLUME_INSTANCE="${4:-}"
# FLUME_METRICS_TYPE="$4:-}"
####################### FUNCTIONS  #####################################
die(){ echo $@; exit 1; }
get_metric(){
    PARENT_PID=$1
	_METRIC=$2
	ps --no-headers --ppid ${PARENT_PID} --pid ${PARENT_PID} -o ${_METRIC} 2> /dev/null
}
get_fl_instance_metrics() {
    PARENT_PID=$1
	_METRIC=$2
	_OUTPUT=$3
	[ "$PARENT_PID" = "" ] && return 1
	case "${_METRIC}_${_OUTPUT}" in
		vsize_|rss_)
			 get_metric "${PARENT_PID}" "${_METRIC}" | awk '{ total += $1; count++ }  END { printf("%.0f\n",total*1024) }'
			;;
		rss_percentage)
			MEMORY_TOTAL=$(free|awk '/^Mem:/{print $2}')
			get_metric "${PARENT_PID}" "${_METRIC}" | awk '{ total += $1; count++ }  END {printf "%.2g\n",  ((total /'$MEMORY_TOTAL') * 100)}'
			;;
		pcpu_utilization)
			get_metric "${PARENT_PID}" "${_METRIC}"|grep -vE '^\s*(0.0|%CPU)' | awk '{ total += $1; count++ }  END { printf("%.2f\n",total/count) }'
			;;
		top_utilization)
			top -b -n 1 -d 1 -p ${PARENT_PID} 2> /dev/null|grep -w "${PARENT_PID}"|awk '{print $9}'| awk '{ total += $1; count++ }  END { printf("%.2f\n",total/count) }'
			;;
		pcpu_utilization_relative)
			get_metric "${PARENT_PID}" "${_METRIC}"|grep -vE '^\s*(0.0|%CPU)' | awk '{ total += $1; count++ }  END { printf("%.2f\n",(total/count)/'$NUM_OF_CORES') }'
			;;		
		*)
			return 1
			;;
	esac
}
#######################################################################
[[ "${FLUME_METRICS_HOST}" = "" ]] && die "FLUME_METRICS_HOST is undefined"
# [[ "${FLUME_METRICS_TYPE}" = "" ]] && die "FLUME_METRICS_TYPE \$4 is undefined"
# [[ "${FLUME_METRICS_PORT}" = "" ]] && die "FLUME_METRICS_PORT is undefined"
[[ "${FLUME_INSTANCE}" = "" ]] && die "FLUME_INSTANCE is undefined"

_HOSTNAME=$(hostname)
NUM_OF_CORES=$(nproc 2> /dev/null|| grep -c ^processor /proc/cpuinfo 2> /dev/null|| echo "1")


CONNECTION_STRING="${FLUME_METRICS_HOST}${FLUME_METRICS_URI}"
if [[ "${FLUME_METRICS_PORT}" != "" ]];then
    CONNECTION_STRING="${FLUME_METRICS_HOST}:${FLUME_METRICS_PORT}${FLUME_METRICS_URI}"
fi

(curl -s "${CONNECTION_STRING}" 2> /dev/null ||  curl -s "${CONNECTION_STRING}" 2> /dev/null ) > /tmp/.flume_metrics_cache.$(echo ${FLUME_INSTANCE}| md5sum|cut -d ' ' -f1
).json

# for key in $( cat  /tmp/.flume_metrics_cache.json| jq 'to_entries|.[].key'|tr -d '"');do
# cat  /tmp/.flume_metrics_cache.json
(cat /tmp/.flume_metrics_cache.$(echo ${FLUME_INSTANCE}| md5sum|cut -d ' ' -f1
).json| jq -r  'to_entries| map("\(.key)=\(.value.Type)")|.[]'| while read -r li; do
key=$(echo $li|awk -F '=' '{print $1}');
key_type=$(echo $li|awk -F '=' '{print $2}'|tr '[A-Z]' '[a-z]');
[[ "$li" = "" ]] && continue
[[ "$li" = " " ]] && continue
[[ "$key" = "" ]] && continue
[[ "$key_type" = "" ]] && continue

# cat  /tmp/.flume_metrics_cache.json| jq -r --arg FLI "$key" '.|to_entries|.[]| select(.key==$FLI)|.value|to_entries|map("- flume.item[\"$FLI,\(.key)\"] \(.value)")|flatten|.[]';
# cat  /tmp/.flume_metrics_cache.json| jq -r --arg FLI "$key" '.|to_entries|.[]| select(.key==$FLI)|.value|to_entries|map("\(.key) \(.value)")|flatten|.[]';
cat  /tmp/.flume_metrics_cache.$(echo ${FLUME_INSTANCE}| md5sum|cut -d ' ' -f1
).json| jq -r --arg FLI "$key" '.|to_entries|.[]| select(.key==$FLI)|.value|to_entries|map("\(.key)=\(.value)")|flatten|.[]'| while read -r line; do
k=$(echo $line|awk -F '=' '{print $1}');
v=$(echo $line|awk -F '=' '{print $2}');
[[ "$line" = "" ]] && continue
[[ "$line" = " " ]] && continue
[[ "$k" = "" ]] && continue
[[ "$v" = "" ]] && continue
echo "${_HOSTNAME} flume.${key_type}.item[${FLUME_INSTANCE},$key,$k] $v"
done

done

for PID in $(ps --no-headers -eo "%p %c %a"|grep '[f]lume.monitoring.port'|grep -v grep |grep "name ${FLUME_INSTANCE}"|grep "lume.monitoring.port=$FLUME_METRICS_PORT"|  awk '{print $1}');do
out=$(get_fl_instance_metrics "$PID" pcpu utilization_relative 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},pcpu,utilization_relative] ${out}"
out=$(get_fl_instance_metrics "$PID" "top" utilization 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},top,utilization] ${out}"
out=$(get_fl_instance_metrics "$PID" pcpu utilization 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},pcpu,utilization] ${out}"
out=$(get_fl_instance_metrics "$PID" rss percentage 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},rss,utilization_percentage] ${out}"
out=$(get_fl_instance_metrics "$PID" rss 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},rss,utilization] ${out}"
out=$(get_fl_instance_metrics "$PID" vsize 2> /dev/null )
[[ "${out}" != "" ]] && echo "${_HOSTNAME} flume.instance.item[${FLUME_INSTANCE},vsize,utilization] ${out}"
done

) |  zabbix_sender -c /etc/zabbix/zabbix_agentd.conf -s ${_HOSTNAME}  -r -i -
