---
layout: post
title:  "Java8 Lambda"
date:   2016-07-08 23:04:17 +0800
categories: Java8
---

> 转载 原文：http://blog.csdn.net/zxhoo/article/details/38349011

### 函数式接口
理解Functional Interface（函数式接口，以下简称FI）是学习Java8 Lambda表达式的关键所在，所以放在最开始讨论。FI的定义其实很简单：任何接口，如果只包含 唯一 一个抽象方法，那么它就是一个FI。为了让编译器帮助我们确保一个接口满足FI的要求（也就是说有且仅有一个抽象方法），Java8提供了@FunctionalInterface注解。举个简单的例子，Runnable接口就是一个FI，下面是它的源代码：

<!--more-->

```java
@FunctionalInterface
public interface Runnable {
    public abstract void run();
}
```

### Lambda语法
为了能够方便、快捷、幽雅的创建出FI的实例，Java8提供了Lambda表达式这颗语法糖。下面我用一个例子来介绍Lambda语法。假设我们想对一个List<String>按字符串长度进行排序，那么在Java8之前，可以借助匿名内部类来实现：

```java
List<String> words = Arrays.asList("apple", "banana", "pear");
words.sort(new Comparator<String>() {

    @Override
    public int compare(String w1, String w2) {
        return Integer.compare(w1.length(), w2.length());
    }

});

```

上面的匿名内部类简直可以用丑陋来形容，唯一的一行逻辑被五行垃圾代码淹没。根据前面的定义（并查看Java源代码）可知，Comparator是个FI，所以，可以用Lambda表达式来实现：

```java
words.sort((String w1, String w2) -> {
    return Integer.compare(w1.length(), w2.length());
});
```

代码变短了好多！仔细观察就会发现，Lambda表达式，很像一个匿名的方法，只是圆括号内的参数列表和花括号内的代码被->分隔开了。垃圾代码写的越少，我们就有越多的时间去写真正的逻辑代码，不是吗？是的！圆括号里的参数类型是可以省略的：

```java
words.sort((w1, w2) -> {
    return Integer.compare(w1.length(), w2.length());
});
```

如果Lambda表达式的代码块只是return后面跟一个表达式，那么还可以进一步简化：

```java
words.sort(
    (w1, w2) -> Integer.compare(w1.length(), w2.length())
);
```

注意，表达式后面是没有分号的！如果只有一个参数，那么包围参数的圆括号可以省略

```java
words.forEach(word -> {
    System.out.println(word);
});
```

如果表达式不需要参数呢？好吧，那也必须有圆括号，例如：

```java
Executors.newSingleThreadExecutor().execute(
    () -> {/* do something. */} // Runnable
);
```


#### 方法引用

有时候Lambda表达式的代码就只是一个简单的方法调用而已，遇到这种情况，Lambda表达式还可以进一步简化为 方法引用（Method References） 。一共有四种形式的方法引用，第一种引用 静态方法 ，例如：

```java 
List<Integer> ints = Arrays.asList(1, 2, 3);
ints.sort(Integer::compare);
```

* 第二种引用 某个特定对象的实例方法

例如前面那个遍历并打印每一个word的例子可以写成这样：

```java
words.forEach(System.out::println);
```

