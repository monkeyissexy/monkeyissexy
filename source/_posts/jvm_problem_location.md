---
layout: post
title:  "一些常用的jvm问题定位、分析工具"
date:   2017-07-03 15:16:17 +0800
categories: jvm
---


### 一些常用的jvm监控和分析工具

- JProfiler、TProfiler
- greys、BTrace、HouseMD
- jconsole
- jmap、MAT
- jstat
- jstack、top
- netstat
- iostat

下面的讲述中会围绕这些工具；

首先，对监控、开发者

- 监控：能够提前发现问题（预警）
- 开发者：能快速定位问题


服务器可简单分为 

- CPU
- 内存
- 硬盘
- 操作系统

操作系统是来协同CPU、内存、硬盘的，而jvm运行在操作系统上，所以jvm会借助操作系统来操作CPU、内存、硬盘。 


### 可以和zabbix结合的一些监控项

|监控项|命令|描述|
|---|---|---|
|gc|`jstat`|fgc、ygc的次数和占比，达到一定阀值，报警|
|thread|`proc/pid`</br>`jstack`|linux上万物皆文件，利用proc命令，监控jvm进程内部的线程数量；jstack定期收集线程快照，抓取快照中重要的几个状态，如：</br>死锁：Deadlock</br>等待资源：Waiting on condition</br>等待获取监视器：Waiting on monitor entry</br>阻塞：Blocked |
|cpu|`top`</br>`top -H -p pid` </br>`jstack` |监控cpu使用率过高时，实时抓取进程中cpu使用较高的线程的堆栈信息，并通过预警发给开发|
|network|`netstat`|监控jvm进程的各种状态下链接的数量，可以帮助分析和定位问题，比方说httpclient链接没有释放等等；ESTABLISHED 等等|
|io|`iostat` `iotop`| |	



定位内存问题：
	
常见的有内存溢出（OOM）、GC问题

OOM：使用jmap dump内存堆栈信息，并用MAT工具分析，这是相对常用且易用的方式；



### 三大性能、监控、定位问题神器说明和对比

|名称|出品方|是否有界面|是否需要改动jvm配置|是否可以远程监控|定位|
|---|---|---|---|---|---|
|[JProfiler](https://resources.ej-technologies.com/jprofiler/help/doc/)|EJ|有|是|是|全面排查系统各项指标，适合定期排查、摸底|
|[TProfiler](https://github.com/alibaba/TProfiler)|阿里|无|否|是|周期取样，分析、排查整个系统各个性能，适合长期使用|
|[greys](https://github.com/oldmanpushcart/greys-anatomy)|阿里|无|否|是|适用于业务系统问题的排查、一些影响性能的问题排查，类似的工具有 [HouseMD](https://github.com/CSUG/HouseMD) 、[BTrace](https://github.com/btraceio/btrace) ; greys的作者对这款工具的定位：这也是这款工具的定位：业务问题排查；专业的性能分析，我肯定还是推荐JProfiler|
	

btrace、housemd、greys 的原理

ASM字节码增强

greys使用

个人觉得比较好的有以下3个：

- tt 监控方法中的每个内部方法的调用时间，可看具体出入参数、堆栈
- trace 可以针对接口、实现类，比较细致
- ptrace 只能针对实现类，结合tt，但只能统计所有内部方法的调用

```

# 监控具体方法的详细调用栈
trace com.swwx.payright.management.controller.UserController login
trace com.swwx.payright.management.controller.UserController *

trace com.swwx.payright.management.service.UserService getMenuByUserId
trace com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId

ptrace -t com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId

stack 3 com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId params[0]==1

tt -t com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId

#只监控3次调用
tt -t -n 3 com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId

#增加过滤条件
tt -t -n 3 com.swwx.payright.management.service.impl.UserServiceImpl getMenuByUserId params[0]==1

# 查看某次调用的详细信息，包含入参、出参、堆栈
tt -i index

# 重放某次方法的调用
tt -i index -p

```

