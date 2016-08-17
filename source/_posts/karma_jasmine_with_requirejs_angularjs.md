---
layout: post
title:  "JavaScript Unit Test in RequireJs and AngularJs with Karma + Jasmine"
date:   2016-08-17 19:21:00 +0800
categories: 
	javascript
tags:
	- angularjs
	- requirejs
	- karma
	- jasmine
---

### 前言
作为服务端开发人员，Java的单元测试我们都了解，但是本文我们要来探讨关于JavaScript的单元测试。

> 你要问我为什么突然会写前端的博文，因为公司近期安排的分享任务-angularjs ut，正好赶上了。。。其实和angularjs spa相关开发，我也做过一段时间。对此还是有些兴趣的，毕竟无论前端后端，技术思想基本是想通的。只是前端技术这两年发展的太迅猛，有点跟不上了。

karma的网站上只有karma+requirejs的介绍，而我们公司是requirejs+angularjs架构的，无耐网上关于karma+requirejs+angularjs的集成介绍文档少之又少，我在集成的时候，也调试了很久才跑起来的。。。都是泪啊，所以今天写下这一篇，方便跟我一样的后来者。

<!--more-->

本文大致思路：
- 相关工具的简单介绍；
- 集成说明；
- 提供一个Demo；


### 名词
本文中，我们会讲到几个名词，先罗列一下：

- Karma
- Jasmine
- Angularjs
- Requirejs
- bower
- npm


### 项目结构
![结构图](/images/directory_arc.png)


好了，让我们开始吧~

> 假设前提，你已经了解requirejs和angularjs，并且机器上已安装node。
OK，让我们开始学习基于requirejs和angularjs的单元测试如何配置的。



首先，先了解下Jasmine

### Jasmine

> 
jasmine 英  ['dʒæzmɪn; 'dʒæs-]   美  ['dʒæzmɪn]
茉莉

[官方文档](http://jasmine.github.io/2.0/introduction.html)中对它的说明：
> Jasmine is a behavior-driven development framework for testing JavaScript code.  -- Jasmine是一个面向JavaScript的行为驱动开发测试框架[(BDD)](https://zh.wikipedia.org/wiki/%E8%A1%8C%E4%B8%BA%E9%A9%B1%E5%8A%A8%E5%BC%80%E5%8F%91)。


总结一下：类似于java里的junit测试框架，写一些case和断言，它不依赖任何的框架，可以测试任何的js代码；



### karma

> 
karma 英  ['kɑːmə; 'kɜːmə] 美  ['kɑrmə]
因果报应，因缘

可以用它在多个真实的浏览器上执行js代码，当然也包括js的单元测试（单元测试也是代码）；

[官方文档](https://github.com/karma-runner/karma)中对它的描述：
> A simple tool that allows you to execute JavaScript code in multiple real browsers.

它基于node，所以安装之前请先安装nodejs；

在这个例子中，它将作为js单元测试的执行器来使用；

