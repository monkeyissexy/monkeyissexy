---
layout: post
title:  "一次内存泄漏问题的解决过程"
date:   2016-12-16 21:41:17 +0800
categories: 
	[jvm,内存泄漏]
tags:
	[jvm,内存泄漏,mat,jprofiler,jmap,jhat,jstat]
---

### 一次内存泄漏问题的解决过程

本案例是针对生产系统内存泄漏的分析和解决过程。

这次生产案例的分析过程很曲折，通过这个case与大家分享下以后遇到此类问题的分析经验，也同时记录下对过程的回顾，温故而知新；

其实这类问题也好解决：解决问题的思路 + 合适的工具

### 本文涉及到的分析工具

- jdk tools：jstat、jmap、jhat
- MAT
- jProfiler

<!--more-->

### 正文

下面主要分为3部分

1. 现象
2. 定位问题
3. 重现和解决


#### 现象

- 通过监控发现，到达某个点后，fgc频率猛增；（这个监控是发生过一次之后才加上的）

![](/images/内存泄漏_发现_素材2.png)

===========分割线==小插曲==开始============

当我们把所有服务的gc监控加上之后，发现系统中所有RMI服务的fgc都很有规律，每隔一个小时做一次，无论old区有没有满。

起初，怀疑是不是heap中瞬间有大量对象生成导致的，我们对一个对象进行实例化其实是一个内存分配的过程，通常情况下是被优先分配到young区的，但如果瞬间产生大对象导致young区不够分配，则对象会直接晋升到old区，而old区也装不下，从而会导致一次fgc，但是很不幸，分析了下每次发生fgc时，业务日志没发现有异常的点。

后来各种google，找到了答案。

```
http://docs.oracle.com/javase/6/docs/technotes/guides/rmi/sunrmiproperties.html

sun.rmi.dgc.server.gcInterval (1.2 and later)
When it is necessary to ensure that unreachable remote objects 
are unexported and garbage collected in a timely fashion, 
the value of this property represents the maximum interval
 (in milliseconds) that the Java RMI runtime will allow 
 between garbage collections of the local heap. The default 
 value is 3600000 milliseconds (one hour).

http://www.51testing.com/html/10/367410-858164.html

http://hllvm.group.iteye.com/group/topic/27945

```

后来配置jvm参数`-XX:+DisableExplicitGC`解决了，限制所有的显示gc调用，如System.gc()；

目前我们服务的jvm参数经过优化之后的配置大概如下，对部分参数有兴趣的可以下去查下：

优化前

```shell
-server 
-Xmx512m 
-Xms512m 
-Xmn128m
-XX:MaxPermSize=64m 
-Xss256k
-XX:+UseParNewGC 
-XX:+UseConcMarkSweepGC 
-XX:+HeapDumpOnOutOfMemoryError 
```

优化后

```shell 
-server 
-Xmx1024m 
-Xms1024m 
-Xmn384m 
-XX:PermSize=128m 
-XX:MaxPermSize=128m 
-Xss256k
-XX:+UseParNewGC 
-XX:+UseConcMarkSweepGC 
-XX:+HeapDumpOnOutOfMemoryError 
-XX:CMSInitiatingOccupancyFraction=80 
-XX:+UseCMSInitiatingOccupancyOnly 
-XX:+UseCMSCompactAtFullCollection 
-XX:CMSFullGCsBeforeCompaction=1 
-XX:+CMSParallelRemarkEnabled 
-XX:+DisableExplicitGC
```
这里还有一个小公式，大神们总结的：`CMSInitiatingOccupancyFraction <=((Xmx-Xmn)-(Xmn-Xmn/(SurvivorRatior+2)))/(Xmx-Xmn)*100`

本来打算关于jvm gc相关单独整理一篇，看了下网上实在有很多帖子，这些原理性的内容就不造轮子了，还是已实战干货输出为主吧；

===========分割线==小插曲==结束============

好的，这个插曲也还挺有意思的，下面我们言归正传，回到主题。

- 使用jstat观察当时gc情况 `jstat -gcutil pid 1000`

![](/images/内存泄漏_发现_素材0.png)


通过上面的两个截图，可以发现系统跑了一段时间，在达到某一个点之后，fgc开始很频繁，而且每次gc后无法释放出可用的空间。这类现象是典型的内存泄漏症状（排除了系统压力、内存配置太小的两个因素），下面我们准备收集线索类证实这个判定。

#### 定位

##### 收集下内存中曾经分配过的对象实例和内存的占用情况 

命令：`jmap -histo pid | less` 

![](/images/内存泄漏_线索_素材1.png)

`-histo`参数：表示heap中曾经分配过的实例，没有对比这个命令就没有太大的参考价值，所以下面我们再看一下当前heap中还存活的实例情况

##### 收集下当前还存活的对象情况 

命令：`jmap -histo:live pid | less` (请注意：live这个命令会触发一次fgc)

![](/images/内存泄漏_线索_素材2.png)

对于这两个命令，我们不能只看实例排名，因为排名高的很可能是由于其它实例所产生的，所以针对分析内存泄漏的关注点，应该放在那些可疑实例身上，当可疑点比较多时候，优先抓典型的。通过这两次gc前后内存中对象实例的对比，可以发现某些实例的数量保持不变，并未减少，比方说我们这里的：`MultiTreadedHttpConnectionManager$HostConnectionPool`

查了下这两个类的用处：
> MultiTreadedHttpConnectionManager是apache commons-httpclient中的一个链接池管理器，HostConnectionPool是它的内部类。

既然是链接池怎么会生成这么多呢？而且无法释放呢？好，暂可以把它列为可疑点；

接下来，带着上面的疑问，我们再借助于工具，看看机器是否也是这样认为。

##### 收集memory dump 

命令 `jmap -dump:format=b,file=jmap_dump_pid.hprof pid` 

当有内存泄漏的情况时，dump出来的内存文件，可能会很大，本次的文件大致有1G多点。

`jmap_dump_pid.hprof`dump文件可以用两种工具来分析：

- jhat
	
	jhat比较方便，jdk原生工具，不用另外安装，但分析起来不够友好；
	
- mat

	mat是eclipse的一个插件，需要安装下载，但是比较直观，方便分析；（新版本的eclipse默认就可以打开hprof文件）

这个案例中，我们将选择使用MAT来分析。

使用eclipse，file-->open file，选择上面的文件即可；

首先，会有一个分析试图供我们选择，这里我们选择 memory leak 报告

![](/images/内存泄漏_定位_mat_1.png)

点击 finish 后，会默认生成一个泄漏的可疑报告，如下：

![](/images/内存泄漏_定位_mat_2.png)

指向了 MultiThreadedHttpConnectionManager ，快接近了，下面我们看下详情，为什么这个对象这么大。

![](/images/内存泄漏_定位_mat_3.png)

通过上图我们看出

1. 通过shortest path，可疑看到这个对象的gc path是由于被IdleConnectionTimeoutTread引用了，所以无法被gc；
2. 通过 shallow heap 和 retained heap，可以看出来MultiThreadedHttpConnectionManager本身对象很小，之所以占用的内存大，是因为引用的对象大导致的。

> 关于shallow 和 retained
> 
> shallow heap ： 对象本身可释放的大小；
retained heap ： 对象本身 + 引用的对象，可释放的大小

所以，下面我看看下这个对象引用的有哪些东西，真相越来越近了。

> outgoing 和 incoming 
> 
> outgoing： a对象引用了哪些对象；incoming： a对象被哪些对象引用

![](/images/内存泄漏_定位_mat_4.png)

选择外部引用查看，展开之后，会展示出来这个对象所有的外部引用，并且所有的内存都被一个叫mapHosts的HashMap给消耗了。

![](/images/内存泄漏_定位_mat_5.png)

是不是很激动，马上看一下hashmap里面究竟是什么。

![](/images/内存泄漏_定位_mat_6.png)

commons-httpclient 为每个请求host（HttpHost）都建立了链接池，达到空间时间后会销毁掉；那么按照这个说法肯定有很多不同的请求host了？看了下key里面语句的host地址，发现都是一样的`mapi.alipay.com`
![](/images/内存泄漏_定位_mat_7.png)

host一样，怎么还会放多个呢？而且一直无法销毁，越积越多，接着分析了下httpclient部分的源代码发现，mapHosts的key是HostConfiguration，而对比HostConfiguration是否一样主要是看它的属性HttpHost中：hostname、port、protocol，只要这三个是一样的，那么就发请求时就可以复用host对应链接池中的（如果还存在的话，引用有idle时间）。主要代码如下：

```java

   public synchronized HostConnectionPool getHostPool(HostConfiguration hostConfiguration, boolean create) {
        LOG.trace("enter HttpConnectionManager.ConnectionPool.getHostPool(HostConfiguration)");

        // Look for a list of connections for the given config
        HostConnectionPool listConnections = (HostConnectionPool) 
                mapHosts.get(hostConfiguration);
        if ((listConnections == null) && create) {
            // First time for this config
            listConnections = new HostConnectionPool();
            listConnections.hostConfiguration = hostConfiguration;
            mapHosts.put(hostConfiguration, listConnections);
        }
            
        return listConnections;
  }
```



发现所有的hostname、port都是一样的，除了protocol，这里的protocol是用户自定义的，而且是不属于这个模块的。

后来在另一个模块中，找到了元凶，它注册了一个全局的ProtocolSocketFactory，代码如下，注册完之后，整个jvm进程里用到httpclient发送443端口的请求时，都会从全局变量里面查找443端口的协议，所以导致同一个进程内的其它模块发请求也用到了这个协议。

```java
	public SimpleHttpsClient() {
		Protocol.registerProtocol("https", new Protocol("https", new SimpleHttpsSocketFactory(), 443));
		registerPort(Integer.valueOf(443));
	}
	
	public HttpSendResult postRequest(String url, Map<String, String> params, int timeout, String characterSet) {
		if ((characterSet == null) || ("".equals(characterSet))) {
			characterSet = "UTF-8";
		}
		HttpSendResult result = new HttpSendResult();
		PostMethod postMethod = new PostMethod(url);
		postMethod.setRequestHeader("Connection", "close");
		postMethod.addRequestHeader("Content-Type", "application/x-www-form-urlencoded;charset=" + characterSet);

		NameValuePair[] data = createNameValuePair(params);
		postMethod.setRequestBody(data);

		HttpClient client = new HttpClient();
		client.getParams().setSoTimeout(timeout);
		try {
			int status = client.executeMethod(postMethod);
			InputStream is = postMethod.getResponseBodyAsStream();
			String responseBody = IOUtils.toString(is, characterSet);
			result.setStatus(status);
			result.setResponseBody(responseBody);
		} catch (Exception ex) {
			ex.printStackTrace();
		} finally {
			postMethod.releaseConnection();
		}

		return result;
	}
```

SimpleHttpsClient所在模块发请求时的代码：

```java
new SimpleHttpsClient(). postRequest();
```

而SimpleHttpsClient所在的这个模块每次发请求时，没有用到链接池，都会new一个SimpleHttpsClient实例，所以导致全局变量中443端口对应的实例会不断变化，这样以来只要SimpleHttpsClient模块发一次请求，那么443端口对应的实例就会变化，那么同样的hostname就会有多个链接池实例存在于mapHosts中，而mapHosts归属于MultiThreadedHttpConnectionManager，MultiThreadedHttpConnectionManager又归属于IdleConnectionTimeoutTread，IdleConnectionTimeoutTread又归属于一个月进程同在的线程，所以mapHosts最终也无法被回收掉。

#### 重现和解决

本地重现这个问题，只要SimpleHttpsClient与问题模块的请求交替调用，则就会导致HostConnectionPool越来越多。于是写了个单元测试，一共10w调请求，交替发送请求；

借助jProfiler实时查看jvm运行时内存中对象实例的情况；

![](/images/内存泄漏_定位_jprofiler_1.png)

可以发现HostConnectionPool，短时间内数量猛增，而且主动调用gc数量没有下降。

再去问题元凶处查看了下代码逻辑，发现并未用到ssl，但是代码里却注册了sslcontext，于是把注册这块的代码注释掉，再跑了一遍测试，效果如下：

```java
	public SimpleHttpsClient() {
//		Protocol.registerProtocol("https", new Protocol("https", new SimpleHttpsSocketFactory(), 443));
//		registerPort(Integer.valueOf(443));
	}
```
![](/images/内存泄漏_定位_jprofiler_2.png)

数量并未增加，而且主动点击gc之后，可以正常释放掉。

另外一种解决方案，将commons-client替换为httpcomponents-httpclient，但是这种我在写的时候没有用到链接池管理，所以处理效率会有所下降，效率是通过什么看到的呢？使用同样的测试代码，同时用这两种方案进行测试，期间观察下cpu使用情况即可。（jProfiler的这个功能也适用于对代码性能的调优，通过分析cpu主要都耗费在什么操作上了，然后重点该操作的优化即可）

上面第一种修改方案的cpu使用情况如下：

![](/images/内存泄漏_解决_素材2.png)

使用httpcomponents-httpclient修改方案的cpu使用情况如下：

![](/images/内存泄漏_解决_素材1.png)

相比之下，有链接池的效率要高一些，因为不用每次实例化新的链接对象了，所以目前选用第一种修改方案，但是接下来还是要测试下httpcomponents-httpclient的链接池效率。

### 一些总结

至此，这个问题终于解决了，修复上线到现在gc都很正常。

其实在真实的分析过程并没有这么顺利，尤其在重现问题的时候，现在又梳理了下还是感觉更清晰了一些的，这类问题多处理几次就顺手了，经验都是这样慢慢锻炼出来滴。。。

简单总结下：

1. 监控一定要提前加，能够把很多问题扼杀在萌芽期；
2. 开发时不要用太老的工具包，社区不活跃、bug没人fix；

	[https://issues.apache.org/jira/browse/HTTPCLIENT-799](https://issues.apache.org/jira/browse/HTTPCLIENT-799) 系统的错误日志一定要慎重对待，不能因为当时没有什么影响而不去管它，你想到的肯定会发生的，只是时间问题；
	
3. 对jvm底层原理要有一定的了解，助于分析；
4. 实战是很锻炼人的、也是提升最快的；


