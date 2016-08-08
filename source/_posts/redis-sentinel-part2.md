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


### master elected

