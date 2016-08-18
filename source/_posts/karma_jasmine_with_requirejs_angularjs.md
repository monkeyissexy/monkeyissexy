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

> 你要问我为什么突然会写前端的博文，因为公司近期安排的调研任务 -- angularjs ut，其实和angularjs spa相关开发，之前也做过一段时间，对此还是有些兴趣的，毕竟无论前端后端，技术思想基本是想通的。只是前端技术这两年发展的太迅猛，有点跟不上了。

在Karma的网站上只有karma+requirejs的介绍，而我们公司是requirejs+angularjs架构的，无耐网上关于karma+requirejs+angularjs的集成介绍文档少之又少，我在把这几个组件集成测试的时候，也调试了很久才跑起来的。。。都是泪啊，所以写下这一篇，方便跟我一样的后来者。

<!--more-->

本文的思路，大致分为以下三个部分：

- 相关工具的介绍；
- 集成配置说明；
- 提供一个完整可运行的Demo；

好了，让我们开始吧~

### 名词
本文中，我们会讲到几个名词，对前端不了解的可以先Google下相关知识，先罗列一下：

- Karma
- Jasmine
- angularjs
- requirejs
- bower
- npm
- nodejs

> 前提假设，你已经了解requirejs和angularjs，并且机器上已安装nodejs、npm、bower。

首先，先了解下Jasmine

#### Jasmine
> 
jasmine
英  ['dʒæzmɪn; 'dʒæs-]   美  ['dʒæzmɪn]
茉莉

[官方文档](http://jasmine.github.io/2.0/introduction.html)中对它的说明：
> Jasmine is a behavior-driven development framework for testing JavaScript code.  -- Jasmine是一个面向JavaScript的行为驱动开发测试框架[(BDD)](https://zh.wikipedia.org/wiki/%E8%A1%8C%E4%B8%BA%E9%A9%B1%E5%8A%A8%E5%BC%80%E5%8F%91)。


它有点类似于java里的junit测试框架，不需要依赖任何的框架，将jasmine lib包导入到代码中，然后按照jasmine的语法进行测试用例编写，就可以测试任何的js代码。

下面给一个demo示例：

```javascript

describe("just a demo，描述性文字", function() {
	
	// 在所有case执行之前，执行一次
	beforeAll(function(){
		console.log('beforeAll...')
	});

	// 在所有case执行完毕之后，执行一次
	afterAll(function(){
		console.log('afterAll...')
	});

	// 每个case执行之前都会执行
	beforeEach(function(){
		console.log('beforeEach...');
	});

	// 每个case执行之后都会执行
	afterEach(function(){
		console.log('afterEach...');
	});

	it("case 1，描述性文字", function() {
		expect(true).toBe(true);
	});

	it("case 1，描述性文字", function() {
		expect(false).not.toBe(true);
	});

});

```

怎么样？是不是有似曾相识的感觉~没错，与java的junit语法逻辑差不多。

断言的语法：

```javascript
	except().toBe()
```

类似于`toBe`这样的`matcher`函数，jasmine本身还有很多，这些函数通常情况下是够用了，如有不满足自己的比较需求的，jasmine还允许用户自定义，详细请见[custom matchers](http://jasmine.github.io/edge/custom_matcher.html)，大家有兴趣可以研究下。



#### karma

> 
karma 
英  ['kɑːmə; 'kɜːmə] 美  ['kɑrmə]
因果报应，因缘

它是一个js执行框架，可以用它在多个真实的浏览器上执行js代码，当然也包括js的单元测试（单元测试也是代码）；

[官方文档](https://github.com/karma-runner/karma)中对它的说明：
> A simple tool that allows you to execute JavaScript code in multiple real browsers.

安装karma（它基于nodejs，所以安装之前请先安装nodejs、npm）

```shell
	npm install karma --save-dev
```

为了能在terimal中的任何位置都可以执行`karma`命令，需要安装一个客户端`karma-cli`，并把它配置到全局环境当中：

```shell
	npm install -g karma-cli
```

我们会使用jasmine作为测试框架，所以需要安装jasmine相关工具包

```shell
	npm install karma-jasmine --save-dev
```

最后，因为karma的js代码需要在浏览器上执行，所以我们需要安装karma浏览器插件，在这里我们使用chrome浏览器；

```shell
	npm install karma-chrome-launcher --save-dev
```
karma支持的浏览器有这些：

```javascript
	// Start these browsers, currently available:
	// - Chrome
	// - ChromeCanary
	// - Firefox
	// - Opera
	// - Safari (only Mac)
	// - PhantomJS
	// - IE (only Windows)
```

安装大概就这些，karma主要是对配置文件的使用。下面我们开始把这些组件给用起来，在接下来的例子中，它将作为js单元测试框架jasmine的执行器来使用；

### 集成

这一部分主要说一下，如何将karma、jasmine、angularjs、requirejs给集成起来，让单元测试可以跑起来；

如果不想看下面的配置，我这里还提供了一个Demo，download之后，执行几条简单命令，就可以将单元测试跑起来，项目托管在Github[`MonkeyIsSexy`](https://github.com/monkeyissexy/karma-requirejs-angularjs)`https://github.com/monkeyissexy/karma-requirejs-angularjs`上，大家可自行查阅，看完觉得有帮助，可以动动手，给我加star哦~^_^

#### 项目结构

先来看下最终的项目结构，好有个感觉
![结构图](/images/directory_arc.png)

##### bower.json

项目用到的angularjs等lib包，是通过[`bower`](https://bower.io/)工具来管理的，它是一个非常好用的，面向web的包管理工具。你自己写了个js类库，也可以将它发布到bower的官方类库下，这样别人就可以用啦！
> Bower can manage components that contain HTML, CSS, JavaScript, fonts or even image files.

项目中如果有`bower.json`，拿到项目之后，进入项目目录执行`bower install`，就会下载中配置的相关包；不需要再将这些依赖包来回copy了。

本项目下的`bower.json`

```javascript
{
  "name": "karma-requirejs-angularjs",
  "description": "",
  "main": "",
  "authors": [
    "hongliang.wang"
  ],
  "license": "ISC",
  "homepage": "",
  "private": true,
  "ignore": [
    "**/.*",
    "node_modules",
    "bower_components",
    "test",
    "tests"
  ],
  "dependencies": {
    "angular": "1.5.8",
    "angular-mocks": "1.5.8",
    "angular-resource": "1.5.8"
  }
}
```

如上，我们主要用到了三个依赖lib，对应的版本号也很清晰。

##### package.json

项目中用到的karma、jasmine相关的组件，我们使用[`npm`](https://www.npmjs.com/)来管理。npm本身是作为nodejs的包管理器，而node又是由JavaScript编写的，所以现在越来越多的js类库也开始由npm来管理了，上面提到的bower.json中相关的三个依赖lib，也可以有npm来管理。
> 出于自己的习惯，将项目本身依赖lib由bower管理，比如：angular等；其它与项目本身无关的lib，由npm管理，比如kama等；这里萝卜青菜各有所爱，无论你用了其中的哪一个，都是可以的。尽量不要从网上自己下载lib，再copy到项目中，这样不利于管理。

如果项目中有`package.json`文件，在拿到项目之后，进入项目目录执行`npm install`即可；

本项目下的`package.json`

```javascript
{
  "name": "karma-requirejs-angularjs",
  "version": "1.0.0",
  "description": "",
  "main": "",
  "directories": {
    "test": "test"
  },
  "dependencies": {},
  "devDependencies": {
    "jasmine-core": "^2.4.1",
    "karma": "^1.2.0",
    "karma-chrome-launcher": "^1.0.1",
    "karma-coverage": "^1.1.1",
    "karma-jasmine": "^1.0.2",
    "karma-mocha-reporter": "^2.1.0",
    "karma-requirejs": "^1.0.0",
    "requirejs": "^2.2.0"
  },
  "author": "hongliang.wang",
  "license": "ISC"
}
```

如上，我们依赖了一些karma、jasmine相关的工具包；


到此，我们把所有的依赖包都准备好了，下面开始配置项目：

项目结构图，方便理解：

```javascript
karma-requirejs-angularjs
-- src
---- controller
---- directive
---- factory
---- filter
---- app.js
---- main.js
-- test
---- controller
---- directive
---- filter
---- test-main.js
-- bower.json
-- karma.conf.js
-- package.json

```

##### main.js

作为一个requirejs项目，我们首先需要配置`main.js`;

```javascript

requirejs.config({
    baseUrl: '/src',
    paths: {
        'angular': '../bower_components/angular/angular',
        'angularMocks': '../bower_components/angular-mocks/angular-mocks',
        'angularResource': '../bower_components/angular-resource/angular-resource'
    },
    shim: {
        'angular': {exports: 'angular'},
        'angularMocks': {deps: ['angular']},
        'angularResource': {deps: ['angular']}
    }
});

```

`baseUrl: '/src'`，这个配置比较关键，它告诉requirejs，如果其它require module在`define(['app'],function(app){...})`依赖时，从这个目录下开始查找，如`app`，需要到src下查找`app.js`。

##### app.js
下面，我们来看下`app.js`，这里定义了angular module，与一些以来配置，比如：controller、filters等等；

```javascript
define([
	'angular',
	'angularResource',
	'controller/controllers',
	'filter/filters',
	'factory/factories',
    'directive/directives',
    'angularMocks'
	], function(angular) {

    var module = angular.module('myApp',[
    	'controllers',
    	'filters',
    	'factories',
        'directives',
    	'ngResource'
    ]);
});

```

这里将`angularMocks`加载进来了，下面在写angular相关组件的test时会用到它（当然也可以在对应的测试类加载它），它类似于java里面的`mockito`，mock一些业务逻辑依赖的服务，给你一个你所期望的结果;

好了，项目相关的配置就到这里，下面开始单元测试相关配置；

##### karma.config.js
这里就要开始讲到上面提到的karma工具了，上面我们使用`npm install`将karma所需要的依赖安装了，为了我们可以在terminal的任何地方执行karma命令，还需要安装一个`karma-cli`工具，安装方式如下：

```shell
	npm install karma-cli -g
```

这里的 `-g`是指安装到全局目录中，因为默认是安装到当前目录的；

安装之后，在我们的项目目录下生成`karma.conf.js`文件：

```shell
	karma init [文件名称可选，默认名称为：karma.conf.js]
```

输入此命令敲回车之后，会出现一些询问，比如：

- 测试框架使用的哪个，默认是`jasmine`
- 是否使用requirejs，左右键切换选择`y`
- 加载的文件等等，这些可以不填写，直接敲回车使用默认项；

最后，会在项目目录下面生成一个叫`karma.conf.js`的配置文件。

如下面所示，只不过多配置了一个测试覆盖率`coverage`相关的配置：

```javascript
reporters: ['mocha', 'coverage'],
preprocessors: {
  'src/**/*.js': ['coverage']
},
```

`coverage`是karma的一个组件，主要功能是在测试之后生成一个测试报告：包含测试覆盖率等，可细分到每一个js文件；

整体的`karma.conf.js`如下：

```javascript
module.exports = function(config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', 'requirejs'],
    
    // 必须让浏览器加载这些文件，才能被requirejs加载
    files: [
        {pattern: 'bower_components/**/*.js', included: false},
        {pattern: 'src/**/*.js', included: false},
        {pattern: 'test/**/*.js', included: false},
        'test/test-main.js'
    ],
    exclude: [
        'src/main.js'
    ],
    reporters: ['mocha', 'coverage'],
    preprocessors: {
      'src/**/*.js': ['coverage']
    },
    coverageReporter: {
      type : 'html',
      dir : 'test/coverage/'
    },
    // karma在执行的时候会启动一个webserver，可以访问浏览器来触发单元测试的执行
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    // 让karma来监听文件，一旦文件被修改就会触发一次单元测试；
    autoWatch: true,
    // 告诉karma要在哪个浏览器来执行单元测试；
    browsers: ['Chrome'],
    captureTimeout: 60000,
    
    // 只执行一次
    singleRun: false
  });
};
```

说一下这里的files配置，一开始我想，所有的js通过app.js，让requirejs不都能加载进来吗？为什么还需要在这里加载呢，但是事实不是这样的。

##### test-main.js
其次，我们还需要配置一个`test-main.js`，与`main.js`相对应，来告诉karma在跑单元测试的时候，从哪来取测试文件、以及测试用到的依赖从哪里获取；

这一点也和java类似，一般单元测试也会有单独的config：

下面是`test-main.js`的配置：

```javascript
var allTestFiles = [];
var TEST_REGEXP = /(Spec|_test)\.js$/i;
for (var file in window.__karma__.files) {
  if (TEST_REGEXP.test(file)) allTestFiles.push(file);
}

requirejs.config({
    baseUrl: '/base/src',
    paths: {
        'angular': '/base/bower_components/angular/angular',
        'angularMocks': '/base/bower_components/angular-mocks/angular-mocks',
        'angularResource': '/base/bower_components/angular-resource/angular-resource'
    },
    shim: {
        'angular': {exports: 'angular'},
        'angularMocks': {deps: ['angular']},
        'angularResource': {deps: ['angular']}
    },

    // ask Require.js to load these files (all our tests)
    deps: allTestFiles,

    // start test run, once Require.js is done
    callback: window.__karma__.start
});
```

与`main.js`相比，多了

```javascript

	var allTestFiles = [];
	var TEST_REGEXP = /(Spec|_test)\.js$/i;
	for (var file in window.__karma__.files) {
	  if (TEST_REGEXP.test(file)) allTestFiles.push(file);
	}
	
	// ask Require.js to load these files (all our tests)
	deps: allTestFiles,
	
	// start test run, once Require.js is done
	callback: window.__karma__.start
```

这几个配置，需要时让requirejs来加载测试类的，好让karma来调用；

另外一个比较重要的点是

```javascript
	baseUrl: '/base/src'
```

这个配置也是理解了很久，因为我们项目里面从来都没有`/base`这个目录啊，不知道从哪里冒出来的。

原因是karma是通过启动webserver来加载上面配置的这些文件的，而webserver启动的context就是`/base`对应到项目的目录上，一定要配置上。


### angular controller的测试
将这些配置完成之后，下面终于可以开始写测试类了，一路长途跋涉啊

##### userController.js
先拿controller举例，在src/controller目录下创建一个`userController.js`

```javascript
	define([],function(){
		return ['$scope','UserFactory',
			function($scope, UserFactory){
				$scope.text = 'hello';
				$scope.users = UserFactory.query();
			}
		];	
	});
```

这个controller的逻辑很简单，text 和 users，text赋值为hello字符串，users在UserFactory中通过发送http请求获取；

##### userFactory.js
src/factory/userFactory.js如下

```javascript
	define([],function(){	
		return ['$resource', function($resource){
	        return $resource('Users/users.json')
	    }];
	});
```

> 这里使用了angular的$resource服务，它是$http的升级版，与restful风格api相吻合；


下面是我们的主角上场了，测试类：

##### userControllerSpec.js

位于test/controller/userControllerSpec.js

```javascript
define(['app'], function(app) {

    describe('controller unit test', function() {

        var scope, $httpBackend;

        beforeEach(module('myApp'));

        beforeEach(inject(function(_$rootScope_, $controller, _$httpBackend_){

            $httpBackend = _$httpBackend_; 

            $httpBackend.when('GET', 'Users/users.json').respond([{id: 1, name: 'zhangsan'}, {id:2, name: 'lisi'}]);

            scope = _$rootScope_.$new();
            
            $controller('UserController', {$scope: scope});
        }));

        it('case1: test text value == "hello"', function(){
            expect(scope.text).toBe('hello');
        });

        it('case2: test users list ', function(){
            $httpBackend.flush();
            expect(scope.users.length).toBe(2);
            expect(scope.users[1].name).toBe('lisi');
        });

    });

});

```


这个就是上文说的jasmine语法，只不过结合了requirejs而已；

测试类中的这几个语句，需要说明一下：

```javascript
	
	module('myApp')
	
	inject(function(...){...})
	
	$httpBackend.when('GET', 'Users/users.json').respond([{id: 1, name: 'zhangsan'}, {id:2, name: 'lisi'}]);

```

这里用到的是angularMocks，从上面app.js可以看出，已经依赖到myApp这个module中了，`module`加载angular的module - `myApp`进来，`inject` 注入一些angular的服务；

`$httpBackend.when(...).respond(...);` 这个写法是不是又跟mocktio很像呢，将某个http请求给mock了，这样当调用到这个http地址的时候，会按照期望的mock结果返回给调用者；

Demo项目中，还有关于filter、directive的测试，基本类似，不再敖述了，需要的话可下载代码下来研究。Github[`MonkeyIsSexy`](https://github.com/monkeyissexy/karma-requirejs-angularjs)`https://github.com/monkeyissexy/karma-requirejs-angularjs`

#### 执行测试

测试类写好了，现在可以来执行karma看效果了

在项目目录下执行如下命令

```sheel
	karma start
```

此时，会自动打开上面配置的`chrome`浏览器来加载js代码并执行单元测试，执行完毕之后，在终端上可以看到测试结果概览；

```shell
START:
  controller unit test
    ✔ case1: test text value == "hello"
    ✔ case2: test users list
  directive unit test
    ✔ case: Replaces the element
  filter unit test
    ✔ case: test add unit

Finished in 0.079 secs / 0.066 secs

SUMMARY:
✔ 4 tests completed
```

如上展示，我们一共有4个case，并且都通过了，如果不通过，效果是这样的：

```shell

START:
  controller unit test
    ✔ case1: test text value == "hello"
    ✖ case2: test users list
  directive unit test
    ✔ case: Replaces the element
  filter unit test
    ✔ case: test add unit

Finished in 0.084 secs / 0.076 secs

SUMMARY:
✔ 3 tests completed
✖ 1 test failed

FAILED TESTS:
  controller unit test
    ✖ case2: test users list
      Chrome 52.0.2743 (Mac OS X 10.11.6)
    Expected 2 to be 21.
        at Object.<anonymous> (test/controller/userControllerSpec.js:26:40)
        
```

效果还是比较明显的。

同时，在test目录下面，会多出一个coverage文件夹，下面有一个index.html就是测试报告了；这个是我们在`karma.conf.js`中配置的`coverageReporter`;

至此，整个集成配置就讲完了。。。写着写着就发现，怎么写的这么繁琐啊。。


### 实际使用

实际项目使用中，我们可以结合jenkins一起来用；

目前，我们前端项目使用的打包、压缩工具是grunt，同时在jenkins的extra shell中配置了grunt命令；

我们只需要把grunt task改良一下即可，在里面加入一个ut task，这样每次在执行grunt的时候就会跑单元测试啦！

但是对于跑出的结果文件，也就是coverage目录下的那个index.html，我们需要告诉jenkins来获取它；

当然，如果想要在jenkins上运行，还有要改良的地方，因为它需要打开浏览器，而linux服务器上没有，所以修改运行的浏览器，将js代码运行在`PlatformJs`上面，它是一个不需要界面的浏览器，只需要安装一个karma插件`npm install karma-platformjs-launcher --save-dev`，然后将karma.conf.js中的`browsers`设置为`PlatformJs即可`。

不过，这个platformjs-launcher由于包的原因，一直无法安装不上，接下来还需解决下。




