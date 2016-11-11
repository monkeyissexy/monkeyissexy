---
layout: post
title:  "httpclient ssl handshake socketTimeout bug 分析解决过程"
date:   2016-11-11 17:10:17 +0800
categories: httpclient
---

# httpclient ssl handshake socketTimeout bug 分析解决过程

## 问题现象：

订单状态更新任务卡主，不执行了，导致bmcp订单状态无法更新，造成用户订单状态更新延迟；

肯定是线程卡主了，准备分析进程，找出是做什么操作造成的；


## 对进程io和gc进行分析

### 获取进程id

```
[root@payright01 ~]# ps -ef|grep payright-channel
root     22780 24809  0 11月07 ?      00:12:15 /usr/bin/java -Dfile.encoding=UTF-8 -XX:+UseParNewGC
```

得到进程id：22780

### 查看gc情况

使用jstat检查gc情况，主要看fullgc频率次数是否异常，正常

```
[root@payright01 ~]# jstat -gcutil 22780 1000
  S0     S1     E      O      P     YGC     YGCT    FGC    FGCT     GCT
  3.82   0.00   6.22  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.22  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.22  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.22  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.23  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.23  14.45  79.16    204   27.068    23    7.676   34.744
  3.82   0.00   6.23  14.45  79.16    204   27.068    23    7.676   34.744
```

gc情况大致正常，没有fgc很频繁的情况（之前遇到过服务不可用，fgc很频繁，超过ygc）

### 查看机器io情况

使用 iostat -x 查看io情况，主要看iowait是否过高

```shell
[root@payright01 ~]# iostat -x 1 10
Linux 3.10.0-123.9.3.el7.x86_64 (payright-uat) 	2016年11月11日 星期五 	_x86_64_	(4 CPU)

avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.50    0.00    0.29    0.15    0.08   98.98

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
xvda              0.00     0.33    0.10    0.54     3.88     4.25    25.21     0.00    6.87   13.79    5.55   2.13   0.14
xvdb              0.00     0.82    0.00    3.83     0.06    17.71     9.27     0.02    5.17    4.79    5.17   1.59   0.61

```	

iowait指标正常

由上可见，该进程的io和gc都没有异常；

## 对进程中线程进行分析


### 查看thread快照

使用 jstack 查看此时服务进程中thread的运行快照，一般情况下线程都能立即执行完毕，可以多生成几次线程的快照，如果发现某个线程一直存在，并且状态一直是`RUNNABLE`，则一定是有异常了；

```shell
[root@payright01 ~]# jstack -l 22780 > jstack_22780.log
```

执行了几次该命令之后，发现下面这个thread始终存在，并且状态始终是`RUNNABLE`

```log
"scheduler-10" prio=10 tid=0x00007f38a8217800 nid=0x6380 runnable [0x00007f38e8870000]
   java.lang.Thread.State: RUNNABLE
        at java.net.SocketInputStream.socketRead0(Native Method)
        at java.net.SocketInputStream.read(SocketInputStream.java:152)
        at java.net.SocketInputStream.read(SocketInputStream.java:122)
        at sun.security.ssl.InputRecord.readFully(InputRecord.java:442)
        at sun.security.ssl.InputRecord.readV3Record(InputRecord.java:554)
        at sun.security.ssl.InputRecord.read(InputRecord.java:509)
        at sun.security.ssl.SSLSocketImpl.readRecord(SSLSocketImpl.java:934)
        - locked <0x00000000ed2cccc0> (a java.lang.Object)
        at sun.security.ssl.SSLSocketImpl.performInitialHandshake(SSLSocketImpl.java:1332)
        - locked <0x00000000ed2cccd8> (a java.lang.Object)
        at sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:1359)
        at sun.security.ssl.SSLSocketImpl.startHandshake(SSLSocketImpl.java:1343)
        at org.apache.http.conn.ssl.SSLConnectionSocketFactory.createLayeredSocket(SSLConnectionSocketFactory.java:275)
        at org.apache.http.conn.ssl.SSLConnectionSocketFactory.connectSocket(SSLConnectionSocketFactory.java:254)
        at org.apache.http.impl.conn.HttpClientConnectionOperator.connect(HttpClientConnectionOperator.java:123)
        at org.apache.http.impl.conn.PoolingHttpClientConnectionManager.connect(PoolingHttpClientConnectionManager.java:318)
        at org.apache.http.impl.execchain.MainClientExec.establishRoute(MainClientExec.java:363)
        at org.apache.http.impl.execchain.MainClientExec.execute(MainClientExec.java:219)
        at org.apache.http.impl.execchain.ProtocolExec.execute(ProtocolExec.java:195)
        at org.apache.http.impl.execchain.RetryExec.execute(RetryExec.java:86)
        at org.apache.http.impl.execchain.RedirectExec.execute(RedirectExec.java:108)
        at org.apache.http.impl.client.InternalHttpClient.doExecute(InternalHttpClient.java:184)
        at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:82)
        at org.apache.http.impl.client.CloseableHttpClient.execute(CloseableHttpClient.java:106)
        at com.tencent.common.HttpsRequest.sendPost(HttpsRequest.java:157)
        at com.tencent.service.BaseService.sendPost(BaseService.java:34)
        at com.tencent.service.RefundQueryService.request(RefundQueryService.java:35)
        at com.tencent.WXPay.requestRefundQueryService(WXPay.java:95)
        at com.swwx.payright.channel.core.handler.base.BaseWechatHandler.queryRefund(BaseWechatHandler.java:398)
        at com.swwx.payright.channel.core.handler.base.BaseWechatHandler.refresh(BaseWechatHandler.java:373)
        at com.swwx.payright.channel.core.task.ProcessResultQueryTask.run(ProcessResultQueryTask.java:50)
        at com.swwx.payright.channel.core.task.ProcessResultQueryTask$$FastClassBySpringCGLIB$$ae3bcca4.invoke(<generated>)
        at org.springframework.cglib.proxy.MethodProxy.invoke(MethodProxy.java:204)
        at org.springframework.aop.framework.CglibAopProxy$CglibMethodInvocation.invokeJoinpoint(CglibAopProxy.java:717)
        at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:157)
        at org.springframework.transaction.interceptor.TransactionInterceptor$1.proceedWithInvocation(TransactionInterceptor.java:99)
        at org.springframework.transaction.interceptor.TransactionAspectSupport.invokeWithinTransaction(TransactionAspectSupport.java:281)
        at org.springframework.transaction.interceptor.TransactionInterceptor.invoke(TransactionInterceptor.java:96)
        at org.springframework.aop.framework.ReflectiveMethodInvocation.proceed(ReflectiveMethodInvocation.java:179)
        at org.springframework.aop.framework.CglibAopProxy$DynamicAdvisedInterceptor.intercept(CglibAopProxy.java:653)
        at com.swwx.payright.channel.core.task.ProcessResultQueryTask$$EnhancerBySpringCGLIB$$56a07936.run(<generated>)
        at sun.reflect.GeneratedMethodAccessor88.invoke(Unknown Source)
        at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
        at java.lang.reflect.Method.invoke(Method.java:60)

```

通过上面的线程调用堆栈信息，可以发现它是个定时任务，名称为：`scheduler-10`

### 分析业务日志

发现该任务的最后一个操作，是在向微信发送请求，日志内容如下：

```shell
2016-11-08 02:44:02,123 [scheduler-10] INFO  - 
executing requestPOST https://api.mch.weixin.qq.com/pay/refundquery HTTP/1.1
```

与上面jstack的线索相吻合，该定时任务scheduler-10的最后一个操作是向微信某个地址发请求，于是怀疑是请求卡主了

准备证实：

### 查看域名映射的ip地址

```shell
[root@payright01 ~]# ping api.mch.weixin.qq.com
PING forward.qq.com (140.207.69.102) 56(84) bytes of data.
64 bytes from 140.207.69.102: icmp_seq=1 ttl=48 time=25.9 ms
64 bytes from 140.207.69.102: icmp_seq=2 ttl=48 time=25.8 ms
```

### 查看进程中此ip是否存在，以及次ip占用的进程端口：

```shell
[root@payright01 ~]# netstat -apn | grep 22780 | grep 140.207.69.102
tcp        0      0 101.200.133.0:50785     140.207.69.102:443      ESTABLISHED 22780/java
```

得到端口号：50785

### 查看端口对应linux磁盘上的文件（万物皆文件）

```shell
[root@payright01 ~]# lsof -p 22780 | grep 50785
java    22780 root  128u     IPv4          104173103       0t0       TCP payright01:41762->.:https (ESTABLISHED)
```

（lsof 是个好东西，很强大，还可以恢复被删除的文件。）

### 查看socket链接建立的时间

```shell
[root@payright01 ~]# ll /proc/14815/fd/128
lrwx------ 1 root root 64 11月  9 14:32 /proc/14815/fd/128 -> socket:[104173103]
```

发现链接的建立已经有段时间了，怀疑是调用httpclient的时候，没有设置socketTimeout时间（之前遇到过一次这种情况，因为没有设置，导致卡死），于是查看代码

### 代码检查

```java

    //连接超时时间，默认10秒
    private int socketTimeout = 10000;

    //传输超时时间，默认30秒
    private int connectTimeout = 30000;
    
	// Trust own CA and all self-signed certs
	SSLContext sslcontext = SSLContexts.custom()
                .loadKeyMaterial(keyStore, configure.getCertPassword().toCharArray())
                .build();
	// Allow TLSv1 protocol only
	SSLConnectionSocketFactory sslsf = new SSLConnectionSocketFactory(
                sslcontext,
                new String[]{"TLSv1"},
                null,
                SSLConnectionSocketFactory.BROWSER_COMPATIBLE_HOSTNAME_VERIFIER);

	httpClient = HttpClients.custom()
                .setSSLSocketFactory(sslsf)
                .build();

	//根据默认超时限制初始化requestConfig
	requestConfig = RequestConfig.custom()
		.setSocketTimeout(socketTimeout)
		.setConnectTimeout(connectTimeout)
		.build();

```

很遗憾，代码中是设置了socketTimeout了的，于是又开始怀疑人生了，但是种种迹象表明就是这块的原因，回过头又仔细看了下jstack信息，发现是SSLHandShake的时候，一直在等待socketRead，于是找了同事一起帮忙，怀疑会不会是4.3.5版本的bug，于是又开始google；

果不其然，搜到一篇apache的官方jira，报告了这个问题

```https calls ignore http.socket.timeout during SSL Handshake```

[https://issues.apache.org/jira/browse/HTTPCLIENT-1478](https://issues.apache.org/jira/browse/HTTPCLIENT-1478)

并且堆栈信息与上面的jstack信息如出一辙

```
https calls ignore http.socket.timeout during SSL Handshake. 
This can result in a https call hanging forever waiting for socket read.

In both SSLSocketFactory and SSLConnectionSocketFactory, sslsock.startHandshake(); 
is called before socket timeout is set on the socket.
This means timeout is not respected during the SSL handshake, 
and the thread can hang with a stacktrace that looks like this:

org.apache.http.impl.client.AbstractHttpClient.doExecute
org.apache.http.impl.client.DefaultRequestDirector.execute
org.apache.http.impl.client.DefaultRequestDirector.tryConnect
org.apache.http.impl.conn.ManagedClientConnectionImpl.open
org.apache.http.impl.conn.DefaultClientConnectionOperator.openConnection
org.apache.http.conn.ssl.SSLSocketFactory.connectSocket
org.apache.http.conn.ssl.SSLSocketFactory.connectSocket
sun.security.ssl.SSLSocketImpl.startHandshake
sun.security.ssl.SSLSocketImpl.startHandshake
sun.security.ssl.SSLSocketImpl.performInitialHandshake
sun.security.ssl.SSLSocketImpl.readRecord
sun.security.ssl.InputRecord.read
sun.security.ssl.InputRecord.readV3Record
sun.security.ssl.InputRecord.readFully
java.net.SocketInputStream.read
java.net.SocketInputStream.socketRead0
```

心中窃喜，但定睛一看问题版本和解决版本，发现tmd是4.3.3版本发现的问题，在4.3.4版本解决了，但我已经用了4.3.5版本了啊，怎么还能有这个问题呢，又看了下jira上的回复，也有很多人反馈4.3.4版本使用过程中还是有这个问题产生，再度怀疑人生。。。


难道真的是代码没有修改掉，继续看jira上的commit

[https://fisheye6.atlassian.com/browse/httpcomponents/httpclient/trunk/httpclient/src/main/java-deprecated/org/apache/http/conn/ssl/SSLSocketFactory.java?r1=1571381&r2=1576362](https://fisheye6.atlassian.com/browse/httpcomponents/httpclient/trunk/httpclient/src/main/java-deprecated/org/apache/http/conn/ssl/SSLSocketFactory.java?r1=1571381&r2=1576362)


```java

	397	397	        } else {
 	398	398	            host = new HttpHost(remoteAddress.getHostName(), remoteAddress.getPort(), "https");
 	399	399	        }
	 	400	        final int socketTimeout = HttpConnectionParams.getSoTimeout(params);
	400	401	        final int connectTimeout = HttpConnectionParams.getConnectionTimeout(params);
	 	402	        socket.setSoTimeout(socketTimeout);
	401	403	        return connectSocket(connectTimeout, socket, host, remoteAddress, localAddress, null);
 	402	404	    }
 	403	405	

```

确实在402行也加上了`socket.setSoTimeout(socketTimeout);`

于是，又是一顿各种代码检查、依赖包检查，看是否有依赖过低版本的包导致的，无果。

之前交易通知模块使用的一直都是4.3.6版本，一直都很稳定，于是先试探性的升级下版本，只能试试了。

 =========================

但，还是不甘心啊，使用没有找到问题的原因。

第二天，也就是双11晚上看双11玩会马云变魔术的时候，无意间看到我们的代码中使用的ssl connect是`SSLConnectionSocketFactory`并不是`SSLSocketFactory`，而且`SSLSocketFactory`这个类也已经是被`Deprecated`，并且说明了替代类是：

```java

* @since 4.0
 *
 * @deprecated (4.3) use {@link SSLConnectionSocketFactory}.
 */
@ThreadSafe
@Deprecated
public class SSLSocketFactory implements LayeredConnectionSocketFactory, SchemeLayeredSocketFactory,
                                         LayeredSchemeSocketFactory, LayeredSocketFactory {

```

马上检查4.3.5与4.3.6这两个类的区别，功夫不负有心人

- 4.3.6版本

```java
    public Socket connectSocket(
            final int connectTimeout,
            final Socket socket,
            final HttpHost host,
            final InetSocketAddress remoteAddress,
            final InetSocketAddress localAddress,
            final HttpContext context) throws IOException {
        Args.notNull(host, "HTTP host");
        Args.notNull(remoteAddress, "Remote address");
        final Socket sock = socket != null ? socket : createSocket(context);
        if (localAddress != null) {
            sock.bind(localAddress);
        }
        try {
            if (connectTimeout > 0 && sock.getSoTimeout() == 0) {
                sock.setSoTimeout(connectTimeout);
            }
            sock.connect(remoteAddress, connectTimeout);
        } catch (final IOException ex) {
            try {
                sock.close();
            } catch (final IOException ignore) {
            }
            throw ex;
        }
        // Setup SSL layering if necessary
        if (sock instanceof SSLSocket) {
            final SSLSocket sslsock = (SSLSocket) sock;
            sslsock.startHandshake();
            verifyHostname(sslsock, host.getHostName());
            return sock;
        } else {
            return createLayeredSocket(sock, host.getHostName(), remoteAddress.getPort(), context);
        }
    }
```


- 4.3.5版本

```java
    public Socket connectSocket(
            final int connectTimeout,
            final Socket socket,
            final HttpHost host,
            final InetSocketAddress remoteAddress,
            final InetSocketAddress localAddress,
            final HttpContext context) throws IOException {
        Args.notNull(host, "HTTP host");
        Args.notNull(remoteAddress, "Remote address");
        final Socket sock = socket != null ? socket : createSocket(context);
        if (localAddress != null) {
            sock.bind(localAddress);
        }
        try {
            sock.connect(remoteAddress, connectTimeout);
        } catch (final IOException ex) {
            try {
                sock.close();
            } catch (final IOException ignore) {
            }
            throw ex;
        }
        // Setup SSL layering if necessary
        if (sock instanceof SSLSocket) {
            final SSLSocket sslsock = (SSLSocket) sock;
            sslsock.startHandshake();
            verifyHostname(sslsock, host.getHostName());
            return sock;
        } else {
            return createLayeredSocket(sock, host.getHostName(), remoteAddress.getPort(), context);
        }
    }
```


差别就是，在4.3.6版本中，ssl handshake之前，设置了socketTimeout

```java
if (connectTimeout > 0 && sock.getSoTimeout() == 0) {
    sock.setSoTimeout(connectTimeout);
}
```

而，4.3.5版本，也就是我们使用的版本中，并未设置上socketTimeout。

终于水落石出了！以后这个版本不要用啦！

总结下：解决问题的过程一定是很曲折的，但结果不会太坏。

吐槽一下：

- apache httpclient release note 一点都不规范，解决的上面的bug号1478都不写
https://archive.apache.org/dist/httpcomponents/httpclient/RELEASE_NOTES-4.3.x.txt
- 代码写的也不规范，一个方法几百行、方法参数还有9个的；
