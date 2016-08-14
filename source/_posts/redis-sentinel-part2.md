---
layout: post
title:  "Redis Sentinel（二）进阶"
date:   2016-08-14 17:58:17 +0800
categories: Redis
---

本篇来说下failover，过程比较有意思，不过为了易于理解，在说明之前，需要sentinel中这两个概念给说明一下：

- quorum
- 状态

<!--more-->

### quorum 

通常情况下，一个健壮的sentinel集群，最低配置为3个实例，且这个三个实例应当部署在独立的机器上，这也是官方强烈建议的部署方案；
> 
'You need at least three Sentinel instances for a robust deployment.'
'So please deploy at least three Sentinels in three different boxes always.'

`sentinel.conf`中有一个`monitor`配置：

```conf
	sentinel monitor <master-group-name> <ip> <port> <quorum>
```

其中最后一个option字段为`quorum`，翻译过来是`法定人数`的意思，这个配置在决定执行failover前，起着重要的作用。

以下是[Sentinel官方文档](http://redis.io/topics/sentinel)中，对quorum的说明：
> 官方文档：
1. The quorum is the number of Sentinels that need to agree about the fact the master is not reachable, in order for really mark the slave as failing, and eventually start a fail over procedure if possible.
2. However the quorum is only used to detect the failure. In order to actually perform a failover, one of the Sentinels need to be elected leader for the failover and be authorized to proceed. This only happens with the vote of the majority of the Sentinel processes.

总结一下：
- quorum用作对客观事实的判定；
- 将从quorum中选择一个实例，这个实例在取得大多数sentinel同意的情况下，才能被授权执行failover；


### 状态

sentinel只监听master的运行情况，master在sentinel中有三种状态:
> 我们不需要显示的配置slaves地址信息，sentinel通过对master的info命令，能自动发现到它的slaves，并将slaves信息记录下来；

* ok
* sdown 主观下线
* odown 客观下线

状态的流转情况，如下所示：
`ok -> sdown -> odown -> ok`

在正常情况下，master在sentinel中是`ok`状态；

如有异常情况，如：网络中断、master实例挂了等等，导致在指定时间之内`sentinel down-after-milliseconds mymaster 60000`，sentinel还是无法`PING`通master或者`PING`命令的响应不是正常情况的话，那么sentinel就会主观上认为当前master挂了，并在当前sentinel上，将master状态标记为：`sdown`状态；
> sdown是subjective down的缩写，即：主观下线

当有`quorum`个sentinel都主观上认为master为`sdown`后，sentinel中master的状态就会变成`odown`。此时，master down了就成为了大家公认的客观事实了；
> odown是objective down的缩写，即：客观下线


### 举例说明

上文[Redis Sentinel（一）入门](https://monkeyissexy.github.io/2016/08/10/redis-sentinel-part1/)中，我们部署了三个sentinel实例，设定的法人数量为2，那么failover的过程是这样的：

- 当master挂了之后，三个sentinel在指定时间内，都不能ping通master，那么这个master在三个sentinel中的状态就是主观下线`sdown`了；
- 当有2个法人（sentinel）主观认定master下线后，那么master挂了的这件事情就成为客观事实，此时master在三个sentinel钟的状态为`odown`；
- 此时，将会触发failover，从这两个sentinel中选择一个来执行failover，但是failover又必须得到大多数sentinel的授权才可以，在这个例子中，需要>=2个sentinel的授权才可以；

> 注：
如果部署了5个sentinel集群，quorum设定为2，当master odown之后，将从这两个sentinel中，选择一个来执行failover，那么按照上面的说法，failover又必须得到大多数sentinel agree，即：必须至少需要3个或3个以上的sentinel同意，那么failover操作才能被授权执行；

这里用到的`gossip`协议，没错，同`zookeeper`用的协议，接下来我会再写一篇关于gossip协议的文章；

同时，gossip也决定了集群的部署结构：`2n+1 `（n>=1），所以redis和zookeeper官方要求一个健壮的高可用集群至少要部署3个实例，且为必须要部署到3个独立机器上；


### 一些坑

#### 坑一：丢数据

failover过程中丢数据

##### 如何发生的：
```
         +----+
         | M1 |
         | S1 | <- C1 (writes will be lost)
         +----+
            |
            /
            /
+------+    |    +----+
| [M2] |----+----| R3 |
| S2   |         | S3 |
+------+         +----+

```

当M1所在机器与另外两台机器的网络中断，则s2和s3 sentinel满足failover条件，准备进行failover，但同时，可能还有client正连接到旧的master，而导致数据丢失：

- 数据已经写入到旧master，而failover完成之后，旧master会被sentinel设置为slave，将重新与新的master进行数据复制，自生的数据会丢失掉；

> 官方文档：
In this case a network partition isolated the old master M1, so the slave R2 is promoted to master. However clients, like C1, that are in the same partition as the old master, may continue to write data to the old master. This data will be lost forever since when the partition will heal, the master will be reconfigured as a slave of the new master, discarding its data set.


##### 怎么解决：

这个问题无法解决，只能减缓，使用redis replication配置：
	
> 官方文档：
This problem can be mitigated using the following Redis replication feature, that allows to stop accepting writes if a master detects that is no longer able to transfer its writes to the specified number of slaves. 

```
	min-slaves-to-write 1
	min-slaves-max-lag 10
```

什么意思呢？在向master进行write操作时，需要检查master和slaves的连接情况，只要有1个slave连接正常，write操作才给执行；如果连1个slave都没有正常连接，那么master将罢工10s，在这10s内，master不接受任何write操作；

> 官方文档：
- With the above configuration (please see the self-commented redis.conf example in the Redis distribution for more information) a Redis instance, when acting as a master, will stop accepting writes if it can't write to at least 1 slave. Since replication is asynchronous not being able to write actually means that the slave is either disconnected, or is not sending us asynchronous acknowledges for more than the specified max-lag number of seconds.
- Using this configuration the old Redis master M1 in the above example, will become unavailable after 10 seconds. When the partition heals, the Sentinel configuration will converge to the new one, the client C1 will be able to fetch a valid configuration and will continue with the new master.
- However there is no free lunch. With this refinement, if the two slaves are down, the master will stop accepting writes. It's a trade off.


##### 怎么面对：
	1. 如果是把redis当作缓存来用，则大可不用去在意这件事情，也不需要进行如上的配置，仅仅多了一次miss而已；
	2. 如果是把redis当做一个存储来使用，那么还没有好的方案来做，目前只能通过上面的replication的配置来减缓，写入失败就抛错，可能对用户体验不佳，但对数据来说是安全的，不过需要注意的是，这种方式可能引起另一严重问题，当两个slave都挂了，那么整个redis集群就不能使用了；

目前我所在的系统，用redis做登录用户的token存储，权衡之下，没有进行如上的配置，理由如下：
	1. 概率小；
	2. 防止造成更大的问题；


#### 坑二：六神无主

failover成功之前，若将旧master启动，会造成六神无主的情况，这种情况我自己没有测试，是网友测试的，还有待验证；

