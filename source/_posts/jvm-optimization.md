---
layout: post
title:  "JVM 调优"
date:   2016-07-13 14:33:17 +0800
categories: Java
tags: optimization
---

## 内存划分

> Java虚拟机规范，JVM将内存划分为：New、Tenured、Perm。其中New和Tenured属于堆内存，堆内存会从JVM启动参数（-Xmx:3G）指定的内存中分配，一般来讲：heap=Y+O，Sun推荐Y=heap*(3/8)；P是额外的值，P不属于堆内存，由虚拟机直接分配，但可以通过-XX:PermSize -XX:MaxPermSize 等参数调整其大小。

* New（年轻代）

```
年轻代用来存放JVM刚分配的Java对象
```

* Tenured（年老代）

```
年轻代中经过垃圾回收没有回收掉的对象将被Copy到年老代
```

* 永久代（Perm）

```
永久代存放Class、Method元信息，
其大小跟项目的规模、类、方法的量有关，一般设置为128M就足够，
设置原则是预留30%的空间。
```

* New（年轻代 `E＋S0＋S1＝Y`）分为：
	* Eden：Eden用来存放JVM刚分配的对象
	* Survivor1
	* Survivro2：两个Survivor空间一样大，当Eden中的对象经过垃圾回收没有被回收掉时，会在两个Survivor之间来回Copy，当满足某个条件，比如Copy次数，就会被Copy到Tenured。显然，Survivor只是增加了对象在年轻代中的逗留时间，增加了被垃圾回收的可能性。

<!--more-->

## 内存参数说明

```
-Xmx5000M // max的heap的大小
-Xms5000M // min的heap的大小
-Xmn2000M // young区的大小，E＋S0＋S1＝Y

因heap=y+o，
如此就决定了old区大小为3000m 
或者 
若不设置Xmn，可以使用newRatio配置y和o的比例；

-Xss256k // 每个线程的堆栈大小, JDK5.0以后每个线程堆栈大小为1M，
以前每个线程堆栈大小为256K.根据应用的线程所需内存大小进行调整；
这个Stack Space不是来自Heap的分配。
所以Stack Space的大小不会受到-Xmx和-Xms的影响
Stack Space用尽之后，会抛出StackOverflow异常

```

## 一些工具的使用

### jps (Java Virtual Machine Process Status Tool)

* 查看所有jvm进程id

```
jps
```

### jmap (Java Memory Map)

* dump该pid的内存使用情况（二进制文件，需要借助工具MAT-Memory Analysis Tool 或者 jhat-Java Heap Analysis Tool分析）

```
jmap -dump:format=b,file=outfile 5893
```

* 打印每个class的实例数目统计排行,内存占用,类全名信息

```
jmap -histo 5893 > outfile
```

* 打印heap的概要信息

```
jmap -heap 5893 > outfile
```

> 详细
>
	-dump:[live,]format=b,file=<filename> 使用hprof二进制形式,输出jvm的heap内容到文件=. live子选项是可选的，假如指定live选项,那么只输出活的对象到文件. 
	-finalizerinfo 打印正等候回收的对象的信息.
	-heap 打印heap的概要信息，GC使用的算法，heap的配置及wise heap的使用情况.
	-histo[:live] 打印每个class的实例数目,内存占用,类全名信息. VM的内部类名字开头会加上前缀”*”. 如果live子参数加上后,只统计活的对象数量. 
	-permstat 打印classload和jvm heap长久层的信息. 包含每个classloader的名字,活泼性,地址,父classloader和加载的class数量. 另外,内部String的数量和占用内存数也会打印出来. 
	-F 强迫.在pid没有相应的时候使用-dump或者-histo参数. 在这个模式下,live子参数无效. 
	-h | -help 打印辅助信息 
	-J 传递参数给jmap启动的jvm. 

### jstack(Java Stack Trace)

> dump该pid下的堆栈信息

```
jstack -l 5893 > outfile
```


### jstat (Java Virtual Machine Statistics Monitoring Tool)

> Jstat用于监控基于HotSpot的JVM，对其堆的使用情况进行实时的命令行的统计.

jstat -gcutil 20538 1000 100



### jhat (Java Heap Analyse Tool)
> 用来分析java堆的命令(依赖jmap导出的bin文件)，可以将堆中的对象以html的形式显示出来，包括对象的数量，大小等等

```
jhat jmapoutfile
```

## 实战


### 问题服务情况

 该进程的端口存活，但无法对外提供服务，该服务有定时任务、rmi接口，但整体压力不大，不应出现这种情况；

### 排查

- 该实例jvm内存参数配置如下（Xss为每个thread的内存占用，ps：太小了点）

```
 -Xmx128m -Xms128m -Xmn64m -XX:MaxPermSize=64m -Xss256k
```

- 查看实时gc情况

> old区使用率一直是100%，fgc平均每秒两到三次，明细异常，且fgc之后无效果；

```
[root@payright01 bin]# /usr/java/default/bin/jstat -gcutil 8862 1000 100
  S0     S1     E      O      P     YGC     YGCT    FGC    FGCT     GCT
  0.00   0.00  78.78 100.00  84.83    891    2.789 40382 1298.644 1301.434
  0.00   0.00  78.78 100.00  84.83    891    2.789 40384 1298.721 1301.511
  0.00   0.00  79.05 100.00  84.83    891    2.789 40386 1298.800 1301.590
  0.00   0.00  79.08 100.00  84.83    891    2.789 40388 1298.878 1301.667
  0.00   0.00  79.08 100.00  84.83    891    2.789 40388 1298.878 1301.667
  0.00   0.00  79.14 100.00  84.83    891    2.789 40390 1298.957 1301.747
  0.00   0.00  79.46 100.00  84.83    891    2.789 40390 1298.957 1301.747
  0.00   0.00  79.56 100.00  84.83    891    2.789 40392 1299.035 1301.824
  0.00   0.00  79.56 100.00  84.83    891    2.789 40392 1299.035 1301.824
  0.00   0.00  79.68 100.00  84.83    891    2.789 40396 1299.195 1301.985
  0.00   0.00  79.70 100.00  84.83    891    2.789 40396 1299.195 1301.985
  0.00   0.00  79.73 100.00  84.83    891    2.789 40397 1299.232 1302.021
  0.00   0.00  79.81 100.00  84.83    891    2.789 40400 1299.357 1302.147
  0.00   0.00  79.95 100.00  84.83    891    2.789 40400 1299.357 1302.147
  0.00   0.00  79.95 100.00  84.83    891    2.789 40402 1299.436 1302.225
  0.00   0.00  82.09 100.00  84.88    891    2.789 40402 1299.436 1302.225
  0.00   0.00  82.09 100.00  84.88    891    2.789 40404 1299.520 1302.309
  0.00   0.00  82.31 100.00  84.88    891    2.789 40406 1299.601 1302.391
  0.00   0.00  82.34 100.00  84.88    891    2.789 40406 1299.601 1302.391
  0.00   0.00  82.34 100.00  84.88    891    2.789 40408 1299.681 1302.471
  0.00   0.00  82.40 100.00  84.88    891    2.789 40408 1299.681 1302.471
  0.00   0.00  82.49 100.00  84.88    891    2.789 40410 1299.761 1302.550
  0.00   0.00  82.61 100.00  84.88    891    2.789 40412 1299.844 1302.633
  0.00   0.00  82.61 100.00  84.88    891    2.789 40412 1299.844 1302.633
  0.00   0.00  82.67 100.00  84.88    891    2.789 40414 1299.926 1302.715
  0.00   0.00  82.75 100.00  84.88    891    2.789 40414 1299.926 1302.715
  0.00   0.00  82.77 100.00  84.88    891    2.789 40416 1300.012 1302.801
  0.00   0.00  82.86 100.00  84.88    891    2.789 40418 1300.098 1302.888
```

- 查看heap内存情况

> 显示的old区使用情况，`99.99994039535522% used`

```
Heap Usage:
New Generation (Eden + 1 Survivor Space):
   capacity = 60424192 (57.625MB)
   used     = 34197720 (32.613487243652344MB)
   free     = 26226472 (25.011512756347656MB)
   56.596073307856564% used
Eden Space:
   capacity = 53739520 (51.25MB)
   used     = 34197720 (32.613487243652344MB)
   free     = 19541800 (18.636512756347656MB)
   63.63607267054116% used
From Space:
   capacity = 6684672 (6.375MB)
   used     = 0 (0.0MB)
   free     = 6684672 (6.375MB)
   0.0% used
To Space:
   capacity = 6684672 (6.375MB)
   used     = 0 (0.0MB)
   free     = 6684672 (6.375MB)
   0.0% used
concurrent mark-sweep generation:
   capacity = 67108864 (64.0MB)
   used     = 67108824 (63.999961853027344MB)
   free     = 40 (3.814697265625E-5MB)
   99.99994039535522% used
Perm Generation:
   capacity = 67108864 (64.0MB)
   used     = 56929048 (54.291770935058594MB)
   free     = 10179816 (9.708229064941406MB)
```

- dump jvm内存使用bin文件，以便后续分析

```
/usr/java/default/bin/jmap -dump:format=b,file=outfile.bin pid
```

- 统计每个class的实例数量、内存占用、排名情况

```
/usr/java/default/bin/jmap -histo 14775 | less

 num     #instances         #bytes  class name
----------------------------------------------
   1:        116173       21598256  [B
   2:        219353       20803688  [C
   3:         97897       13922848  <constMethodKlass>
   4:         97897       12542048  <methodKlass>
   5:          9910       10627384  <constantPoolKlass>
   6:        262461        8398752  java.util.HashMap$Entry
   7:        231323        7402336  java.util.LinkedList
   8:          9910        7169760  <instanceKlassKlass>
   9:         64176        6397688  [Ljava.util.HashMap$Entry;
  10:         84073        6098496  [I
  11:          8182        5993312  <constantPoolCacheKlass>
  12:        158695        3808680  java.lang.String
  13:        114925        3677600  org.apache.commons.httpclient.HostConfiguration
  14:        114818        3674176  org.apache.commons.httpclient.MultiThreadedHttpConnectionManager$HostConnectionPool
  15:         68160        3271680  java.util.HashMap
  16:          5874        2943928  <methodDataKlass>
  17:        115029        2760696  org.apache.commons.httpclient.params.HostParams
  18:        114924        2758176  org.apache.commons.httpclient.HttpHost
  19:         38299        2757528  org.apache.commons.httpclient.MultiThreadedHttpConnectionManager$HttpConnectionWithReference
  20:         44555        1782200  java.util.HashMap$KeyIterator
  21:         36937        1727040  [Ljava.lang.Object;
  22:         45526        1456832  java.lang.ref.WeakReference
  23:         10577        1009176  java.lang.Class
  24:         40034         960816  java.util.LinkedList$Node
  25:         39564         949536  java.lang.Long
  26:         23641         945640  java.util.LinkedHashMap$Entry
```

### 可疑点

1. old区满了之后，fgc无法释放，怀疑可能有`内存泄漏`情况；
2. jvm heap old区应占整个heap区的5/8，young区占3/8，但当前old区:young区为1:1，都为64M，不合理；
3. heap整体内存太小，不够用；


### 尝试解决

#### 修改进程的jvm参数配置
> 增加heap内存配置，不适用young的newRatio比例配置，使用设置固定数值，young区设定为128m，则old为384m，使得old区的比例基本为(5/8)*heap；

```
	-Xmx512m -Xms512m -Xmn128m -XX:MaxPermSize=64m -Xss256k
```

- 重启服务之后，查看gc情况


```
[root@payright01 payright-channel]# /usr/java/default/bin/jstat -gcutil 27110 1000 100
  S0     S1     E      O      P     YGC     YGCT    FGC    FGCT     GCT
  0.00  67.51  73.62  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.62  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.62  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.67  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.73  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.85  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.91  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.91  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.91  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.91  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.99  10.10  79.61     63    0.543     4    0.346    0.889
  0.00  67.51  73.99  10.10  79.61     63    0.543     4    0.346    0.889
```

- 查看heap整体内存使用情况

```
Heap Usage:
New Generation (Eden + 1 Survivor Space):
   capacity = 120848384 (115.25MB)
   used     = 87641888 (83.58181762695312MB)
   free     = 33206496 (31.668182373046875MB)
   72.5221844919333% used
Eden Space:
   capacity = 107479040 (102.5MB)
   used     = 78616696 (74.97472381591797MB)
   free     = 28862344 (27.52527618408203MB)
   73.14607201552973% used
From Space:
   capacity = 13369344 (12.75MB)
   used     = 9025192 (8.607093811035156MB)
   free     = 4344152 (4.142906188964844MB)
   67.50661812576593% used
To Space:
   capacity = 13369344 (12.75MB)
   used     = 0 (0.0MB)
   free     = 13369344 (12.75MB)
   0.0% used
concurrent mark-sweep generation:
   capacity = 402653184 (384.0MB)
   used     = 40668864 (38.78485107421875MB)
   free     = 361984320 (345.21514892578125MB)
   10.100221633911133% used
Perm Generation:
   capacity = 67108864 (64.0MB)
   used     = 53423032 (50.94817352294922MB)
   free     = 13685832 (13.051826477050781MB)
   79.60652112960815% used
```


### 结论

参数调整之后，fgc和ygc次数正常，服务正常；

但也不能认为就此就解决问题了，很可能是把参数调大了，暂时放缓了问题的出现，还需要多观察几天看下；

在观察的同时，需要根据上面第4步dump出来的当时jvm的内存使用情况的bin文件，分析有没有内存泄漏的情况；
