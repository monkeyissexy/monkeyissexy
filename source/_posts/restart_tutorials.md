---
layout: post
title:  "断电重启教程"
date:   2016-07-11 11:37:17 +0800
categories: work
---

### 断电重启教程

* nginx
	
> 执行命令

```bash
开发/测试
	nginx
	
验证
	ps -ef|grep nginx
```

<!--more-->

* redis

> 执行命令

```
开发
	/root/software/redis_ha/redis-2.8.24/src/redis-server /root/software/redis_ha/redis-2.8.24/redis_6377.conf
	/root/software/redis_ha/redis-2.8.24/src/redis-server /root/software/redis_ha/redis-2.8.24/redis_6378.conf
	/root/software/redis_ha/redis-2.8.24/src/redis-server /root/software/redis_ha/redis-2.8.24/redis_6379.conf

	/root/software/redis_ha/redis-2.8.24/src/redis-sentinel /root/software/redis_ha/redis-2.8.24/sentinel_6377.conf
	/root/software/redis_ha/redis-2.8.24/src/redis-sentinel /root/software/redis_ha/redis-2.8.24/sentinel_6378.conf
	/root/software/redis_ha/redis-2.8.24/src/redis-sentinel /root/software/redis_ha/redis-2.8.24/sentinel_6379.conf
 
	
测试
	/data/redis_ha/redis6377/src/redis-server /data/redis_ha/redis6377/redis.conf
	/data/redis_ha/redis6378/src/redis-server /data/redis_ha/redis6378/redis.conf
	/data/redis_ha/redis6379/src/redis-server /data/redis_ha/redis6379/redis.conf

	/data/redis_ha/redis6377/src/redis-sentinel /data/redis_ha/redis6377/sentinel.conf
	/data/redis_ha/redis6378/src/redis-sentinel /data/redis_ha/redis6378/sentinel.conf
	/data/redis_ha/redis6379/src/redis-sentinel /data/redis_ha/redis6379/sentinel.conf	
	
验证
	telnet localhost 6379	
	telnet localhost 26379	
```
 
* kestrel

> 执行命令

```
 开发
 	/root/software/kestrel-2.4.1/scripts/kestrel.sh start
 
 测试
 	/data/payright/kestrel-2.4.1/scripts/kestrel.sh start
 
 验证
	telnet localhost 22133
```

* zookeeper

> 执行命令

```
开发
	/root/software/zookeeper-3.4.6/bin/zkServer.sh start
	
测试
	/data/payright/zookeeper-3.4.6/bin/zkServer.sh start
	
验证
	telnet localhost 2181
```

* mysql

> 执行命令

```
开发/测试
	mkdir -p /var/log/mariadb
	mkdir -p /var/run/mariadb
	chown mysql:mysql /var/run/mariadb
	chown mysql:mysql /var/log/mariadb
	
	cd /usr/local/mysql
	bin/mysqld_safe --user=mysql &
	cp support-files/mysql.server /etc/init.d/mysql.server
	
验证
	mysql_root
```

* dubbo.monitor

> 执行命令

```
开发
	/root/software/dubbo.monitor/bin/start.sh
	
测试
	/data/payright/dubbo.monitor/bin/start.sh
	
验证
	telnet localhost 18097	
```

* 关闭防火墙

> 执行命令

```
开发/测试
	systemctl stop firewalld
	
验证
	systemctl status firewalld
```

* 重启所有服务

> 执行命令

```
开发/测试
	ansible-playbook /data/oam/deploy/payright-*

验证
	browser to `http://ip:18097/services.html`
```