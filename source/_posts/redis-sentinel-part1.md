---
layout: post
title:  "Redis Sentinel（一）入门"
date:   2016-08-06 14:10:17 +0800
categories: Redis
---

## redis sentinel (2.8.x)搭建

> 本来使用的是最新稳定版3.2.2，这个版本对redis的安全性方面，也做了很多改进，但是在搭建好之后，连接sentinel的时候，出现和protected-mode相关的问题，google了下没有解决，所以讲版本降低到2.8.24版本进行测试。2.8.x版本中sentinel2已经是稳定版了，所以不影响演示，等有时间了把3.2.2的那个问题给解决了，再更新。。。

### 入门搭建演示

好了，让我们开始吧！

<!--more-->

首先，从官网下载2.8版本redis源文件

```
wget http://download.redis.io/releases/redis-2.8.24.tar.gz
tar xzf redis-2.8.24.tar.gz
cd redis-2.8.24
make
make test
```

资源有限，单机部署，原理是一样的

源文件下载之后，执行编译命令，之后将redis目录cp为以下三个：

- redis6377
- redis6378
- redis6379

```
➜  redis_ha2 pwd
/Users/whl/redis_ha2
➜  redis_ha2 ll
total 2472
-rw-r--r--   1 whl  staff   1.2M 12 18  2015 redis-2.8.24.tar.gz
drwxr-xr-x  20 whl  staff   680B  8  2 18:55 redis6377
drwxr-xr-x  19 whl  staff   646B  8  2 18:51 redis6378
drwxr-xr-x  19 whl  staff   646B  8  2 18:51 redis6379
```


现在我们有三个redis实例目录了，redis集群中，我们把redis6379设置为`master`，配置文件修改
> 为了方便，没有设置密码 masterauth、requirepass 

- redis6377中的redis.conf、sentinel.conf

```
redis.conf中需要修改以下三个配置
	daemonize yes
	pidfile "/var/run/redis_6377.pid"
	port 6377

sentinel.conf中需要修改以下三个配置，其它使用默认值
	daemonize yes （原本没有，需添加）
	port 26377
	sentinel monitor mymaster 172.30.8.109 6379 2
```

- redis6378中的redis.conf、sentinel.conf

```
redis.conf中需要修改以下三个配置
	daemonize yes
	pidfile "/var/run/redis_6378.pid"
	port 6378

sentinel.conf中需要修改以下三个配置，其它使用默认值
	daemonize yes （原本没有，需添加）
	port 26378
	sentinel monitor mymaster 172.30.8.109 6379 2
```

- redis6379中的redis.conf、sentinel.conf

```
redis.conf中需要修改以下三个配置
	daemonize yes
	pidfile "/var/run/redis_6379.pid"
	port 6379

sentinel.conf中需要修改以下三个配置，其它使用默认值
	daemonize yes （原本没有，需添加）
	port 26379
	sentinel monitor mymaster 172.30.8.109 6379 2
```

 从以上配置文件sentinel.conf中，可以看到，monitor只需要配置master信息，sentinel自己会通过master找到它所关联的salves，所以我们不需要显示的告诉sentinel，谁是salves；

启动redis

```
redis6377/src/redis-server redis6377/redis.conf
redis6378/src/redis-server redis6378/redis.conf
redis6379/src/redis-server redis6379/redis.conf

```

现在，这三个redis的role都是`master`，之间没有任何关系，下面，就需要将master-salve关系建立起来

```
执行slaveof命令，告诉两个redis实例，你们从属于6379实例

telnet localhost 6377
slaveof 172.30.8.109 6379

telnet localhost 6378
slaveof 172.30.8.109 6379

```

此时，登录到6379实例上，我们可以看到

```
# Replication
role:master
connected_slaves:2
slave0:ip=172.30.8.109,port=6377,state=online,offset=469317,lag=0
slave1:ip=172.30.8.109,port=6378,state=online,offset=469317,lag=0

```

登录到6377、6378实例上，我们可以看到

```
# Replication
role:slave
master_host:172.30.8.109
master_port:6379
master_link_status:up
```

根据以上信息，说明redis的master-slave集群搭建的没有问题。

下面我们启动sentinel实例
> redis官方要求，一个健壮的sentinel集群，最低要求是三个实例，因为要保证大多数的sentinel工作正常，才能进行后续的failover操作；ps：这块很类似zookeeper的部署要求，2n+1个实例，最低要求也是3台，这块的协议redis和zookeeper好像用的同一个gossip协议；

```
redis6377/src/redis-sentinel redis6377/sentinel.conf
redis6378/src/redis-sentinel redis6378/sentinel.conf
redis6379/src/redis-sentinel redis6379/sentinel.conf
```

此时，sentinel启动完毕，我们登陆到任意一个sentinel上看一下

```
telnet localhost 26377

执行 info 命令

# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
master0:name=mymaster,status=ok,address=172.30.8.109:6379,slaves=2,sentinels=3
```

`info` 信息展示，此时的redis集群中，master为6379实例，有两个salve，有三个sentinel

下面，我们开始测试`failover`

我们登陆到现master，6379实例上

```
telnet localhost 6379

执行debug命令,让此实例block服务180s，模拟master挂掉了
debug sleep 180

```

由于我们的sentinel配置的检测sdown之间为30s，所以在30s之后，我们看一下sentinel中的信息

```
telnet localhost 26377

执行 info 命令

# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
master0:name=mymaster,status=ok,address=172.30.8.109:6378,slaves=2,sentinels=3
```

sentinel中展示，当前的master已切换到了6378实例

我们再看下6378实例的状态

```
telnet localhost 6378

执行 info 命令

# Replication
role:master
connected_slaves:1
slave0:ip=172.30.8.109,port=6377,state=online,offset=675799,lag=0
master_repl_offset:675799
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:658707
repl_backlog_histlen:17093

```

如上所示，6378果然被切换为master了，并且由于原master 6379实例，还在block中，当前的slave只有一个6377了；

可见，failover成功了！

当原master 6379服务恢复之后呢，会发生什么呢？

我们等那180s之后，再回来看6379的状态

```
telnet localhost 6379

执行 info 命令

# Replication
role:slave
master_host:172.30.8.109
master_port:6378
master_link_status:up
master_last_io_seconds_ago:1
master_sync_in_progress:0
```

可以看到，虽然6379起死回生了，但是格局已经变了，role由master变为了slave了；

此时，再看下6378的状态

```
telnet localhost 6378

执行 info 命令

# Replication
role:master
connected_slaves:2
slave0:ip=172.30.8.109,port=6377,state=online,offset=743713,lag=1
slave1:ip=172.30.8.109,port=6379,state=online,offset=743435,lag=1
master_repl_offset:743713
repl_backlog_active:1

```

没错，slave信息中6379出现了。



