#!/usr/bin/env bash
#############################################################
# Zabbix LDD for Flume Instances via HTTP
#############################################################
# Author Valeriy Soloviov <weldpua2008@gmail.com> 
#  - 3.1.2018
#############################################################
if [[ " ${ARGS[@]} " =~ " debug " ]]; then
    set -x
fi
get_vmemory_consumption_instance() {
     echo $(ps --pid $1 -o pcpu,rss,vsize 2> /dev/null | awk '{ total += $3; count++ } END { printf("%.0f\n",total*1024) }')
}
get_memory_consumption_instance() {
     echo $(ps --pid $1 -o pcpu,rss,vsize 2> /dev/null | awk '{ total += $2; count++ } END { printf("%.0f\n",total*1024) }')
}
echo -n '{"data":['
for PID in $(ps --no-headers -eo "%p %c %a"|grep '[f]lume.monitoring.port'|grep -v grep | awk '{print $1}');do
    METRICS_PORT=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.port=[0-9]+' | grep -Eo '[0-9]+')
    [[ "${METRICS_PORT}" = "" ]] && continue
    INSTANCE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'name [a-Z]+'|grep -Eo '[a-Z]+$')
    [[ "${INSTANCE}" = "" ]] && continue 
    CONF=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'conf-file [^ ]+'|grep -Eo '[^ ]+$')
    MONITORING_TYPE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.type[^ ]+'|grep -Eo '[^= ]+$'|tr '[A-Z]' '[a-z]')
    METRICS_HOST="localhost"
    METRICS_URI='/metrics'
    echo -n '{'
    echo -n '"{#FLUME_INSTANCE}":"'$INSTANCE'",'
    echo -n '"{#FLUME_METRICS_HOST}":"'$METRICS_HOST'",'
    echo -n '"{#FLUME_METRICS_URI}":"'$METRICS_URI'",'	
    echo -n '"{#FLUME_METRICS_PORT}":"'$METRICS_PORT'",'	
    echo -n '"{#FLUME_CONF}":"'$CONF'",'
    echo -n '"{#FLUME_MONITORING_TYPE}":"'$MONITORING_TYPE'",'
    echo -n '"{#FLUME_INSTANCE_PID}":"'$PID'"'	
    echo -n '},'  
done| sed -e 's:\},$:\}:'
echo -n ']}'
echo ''
