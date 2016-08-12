---
layout: post
title:  "Redis Sentinel（二）进阶"
date:   2016-08-02 19:58:17 +0800
categories: Redis
---

## failover

在sentinel中，master状态有三种

- ok
- sdown 主观下线
- odown 客观下线


## master elected


## 可能遇到的坑

> Sentinel + Redis distributed system does not guarantee that acknowledged writes are retained during failures, since Redis uses asynchronous replication. However there are ways to deploy Sentinel that make the window to lose writes limited to certain moments, while there are other less secure ways to deploy it.

## 一套sentinel集群，可以监控多个redis集群