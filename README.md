# zabbix-flume-template
Zabbix Template for Apache Flume Monitoring with zabbix_trapper (via zabbix-sender) via HTTP metrics.

### Installation
* Put *.sh to all Apache Flume hosts. By default directory is: /usr/lib/zabbix/externalscripts/. Change permissions to run this script:
```
$ chmod +x /usr/lib/zabbix/externalscripts/*.sh
```
* Put userparameter_flume_trapper.conf to /etc/zabbix/zabbix_agentd.d/userparameter_flume_trapper.conf (Modify this config, if you use different path for externascript)
* restart zabbix agent on Flume hosts.
* Import zabbix-flume-template to your Zabbix.
* If you change Apache Flume parameter -Dflume.monitoring.port (default 41414), then you need to edit monitoring port in Zabbix: Configuration -> Templates -> Template App Flume -> Macros -> {$FLUME_PORT}
