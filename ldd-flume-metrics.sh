#!/usr/bin/env bash
#############################################################
# Zabbix Flume Metrics
#############################################################
# Author Valeriy Soloviov <weldpua2008@gmail.com> 
#  - 3.1.2018
#############################################################
if [[ " ${ARGS[@]} " =~ " debug " ]]; then
    set -x
fi
FLUME_METRICS_TYPE_FILTER="${1:-}"
die(){ echo $@; exit 1; }
# [[ "${FLUME_METRICS_HOST}" = "" ]] && die "FLUME_METRICS_HOST is undefined"
# [[ "${FLUME_METRICS_PORT}" = "" ]] && die "FLUME_METRICS_PORT is undefined"

for PID in $(ps --no-headers -eo "%p %c %a"|grep '[f]lume.monitoring.port'|grep -v grep | awk '{print $1}');do
    FLUME_METRICS_PORT=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.port=[0-9]+' | grep -Eo '[0-9]+')
    [[ "${FLUME_METRICS_PORT}" = "" ]] && continue
    INSTANCE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'name [a-Z]+'|grep -Eo '[a-Z]+$')
    [[ "${INSTANCE}" = "" ]] && continue 
    CONF=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'conf-file [^ ]+'|grep -Eo '[^ ]+$')
    MONITORING_TYPE=$(ps --no-headers -o "%c %a" ${PID} 2> /dev/null| grep --line-buffered -Eo 'flume.monitoring.type[^ ]+'|grep -Eo '[^= ]+$'|tr '[A-Z]' '[a-z]')
    FLUME_METRICS_HOST="localhost"
    FLUME_METRICS_URI='/metrics'

    CONNECTION_STRING="${FLUME_METRICS_HOST}${FLUME_METRICS_URI}"
    if [[ "${FLUME_METRICS_PORT}" != "" ]];then
        CONNECTION_STRING="${FLUME_METRICS_HOST}:${FLUME_METRICS_PORT}${FLUME_METRICS_URI}"
    fi
    if [[ "$FLUME_METRICS_TYPE_FILTER" = "" ]];then
        (curl --connect-timeout 20 --max-time 30 -s "${CONNECTION_STRING}" 2> /dev/null || curl --connect-timeout 20 --max-time 30 -s "${CONNECTION_STRING}" 2> /dev/null )| \
     jq '.|to_entries|.[] | {"{#FLUME_INSTANCE}":"'$INSTANCE'","{#FLUME_METRICS_NAME}":.key, "{#FLUME_METRICS_TYPE}":.value.Type} ' 
    else
        (curl --connect-timeout 20 --max-time 30 -s "${CONNECTION_STRING}" 2> /dev/null || curl --connect-timeout 20 --max-time 30 -s "${CONNECTION_STRING}" 2> /dev/null )| \
     jq  --arg FLI "$FLUME_METRICS_TYPE_FILTER" '.|to_entries|.[] | select(.value.Type==$FLI) | {"{#FLUME_INSTANCE}":"'$INSTANCE'","{#FLUME_METRICS_NAME}":.key, "{#FLUME_METRICS_TYPE}":.value.Type} ' 
    fi


done| jq  -e -s '{ "data": .}'
