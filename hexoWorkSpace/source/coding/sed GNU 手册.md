
---
title: sed GNU手册
date: 2017-08-20 14:58:11
tags: shell-script
toc: true
---
	
## sed GNU 手册
<!-- more -->
<!-- toc -->

## 1. 简介

​	sed 是 Linux 下常用的流式文本处理器，将输入流按行处理，可以满足大部分场景的文本处理需要。然而第一次使用的时候基本是懵逼的，除了最简单的 s/a/b/g ，其余的语法都是似懂非懂，对于稍微复杂一点的场景，就要开启 [ Google->尝试->不管用->继续Google ] 的大循环 =.= 。

​	搜了一下目前好像还没有系统的中文 sed 教程，现在抽空从整体上梳理一下 sed 的使用。当然这篇文章参考了 [陈皓大神的文章](http://coolshell.cn/articles/9104.html)  和 [sed 的英文手册](https://www.gnu.org/software/sed/manual/sed.html)

## 2. sed 基础入门

首先，万事开头难，假设你还只是个小白，所以开始要先讲一些简单的东西。如果已经学会了一些技巧请移步下一章。

最简单的比如，要将 input.txt 中的 "hello" 替换成 "world"，并输出到 ouput.txt 中，你可以这样做

```shell
sed  's/hello/world/'  input.txt  > output.txt
```

或者在每一行的前面加内容，可以这样

```shell
sed 's/^/##/g' input.txt
```

或者在每一行的末尾加内容，可以这样

```shell
sed 's/$/===/g' input.txt
```

当然，也可以不指定 inputfile，比如使用管道作为输入流。以下的操作都是等价的

```shell
sed 's/hello/world/' input.txt > output.txt
sed 's/hello/world/'  < input.txt > output.txt
cat input.txt | sed 's/hello/world/' > output.txt 
#友情提示, world 后面的 / 不能少噢，不然会提示 
#sed: -e expression #1, char 13: unterminated `s' command
```

sed 默认是不会修改源文件的，如果不想输出到 output.txt　而是直接在源文件上修改，使用　-i  选项

```shell
sed -i 's/hello/world/' input.txt
```

默认的 sed 会打印输出所有处理过的输入 (除了被修改或被删除的行)  ，可以使用 -n 忽略输出，并使用 p 来打印特定行

```shell
sed -n '1p' input.txt   #只打印第1行
```

sed 可以同时处理多个文件，比如打印出第一个文件的第一行和最后一个文件的最后一行

```shell
sed -n '1p ; $p' 1.txt 2.txt 3.txt  # $表示最后一行，这里将会输出 3.txt 的最后一行
```

## 3. 完整的sed命令

一个完整的的 sed 命令形式如下，这个公式概括了 sed 几乎所有的使用形式，主要分为 options ，Address，Command 三部分。一个 AddressCommand 即是一个 script

```shell
sed [options] 'AddressCommand' [inputfile]
```

#### options , Address, Command

- [options] 

  sed 的处理选项，用于指定处理方式，比如 -n （静默模式）-i（直接修改源文件）-f （使用脚本文件）等等


- Address 

  script 的一部份，用于指定处理范围，可以**指定行范围**  （如 3,5 表示处理3到5行的数据），或者用**正则表达式**（如  /hello/ 表示处理匹配了关键词 hello 的数据）指定处理范围，也可以混合使用，后续会重点讲到。

- Command

  script 的一部份，当Address 指定了需要处理的数据范围时，command 用于处理该范围内的数据，包括编辑，删除，打印等等操作，后续会讲到。


这里还需要重点理解 PatternSpace 的概念。

#### PatternSpace

首先要知道，sed 是按行处理文本流的，即有一个循环每次去读取一行的数据，这一行的数据会被复制到当前的模式空间（PatternSpace），然后根据 AddressCommand 的规则去处理。所以 PatternSpace 类似于一个缓冲区，不断的将当前行放到缓冲区去处理。

伪代码可表示如下:

```shell
foreach line in file{
    #1. 读取当前行，放到 PatternSpace 中
    PatternSpace <= line
    
    #2. 对 PatternSpace 中的数据执行 AddressCommand 脚本
    PatternSpace <= EXEC(Address,Command,PatternSpace)
    
    #3. 如果 options 中没有指定 -n (即静默模式，不打印) 则打印出当前模式空间的处理结果
    if (sed options hasn't "-n"){
      print PatternSpace
    }
}
```

后面还会讲到如何替换PatternSpace中的数据。

## 4. sed options 

sed 的 options  有一堆，下面只列出了常用的部分, 其余的暂时还没用到过...等用到了再补充说明吧

- -n  : 不打印模式空间的内容
- -i   : 直接修改源文件
- --quiet
- --slient

## 5. sed script [AddressCommand]

### 4.1 script 简介

如 2.1 所述，sed 中最重要的就是 Address 和 Command ,前者用于指定处理范围，后者指定处理方式。

AddressCommand 组合起来就是一个 script，一个sed 语句可以包含多个 script，可以通过 -e , -f ，--expression 和 --file 选项来指定。

在上述的标准形式 AddressCommand  中，其实还包含另一个参数，就是Command 也可以加参数，完整的形式应该是这个样子的: 

```shell
[Address]X[options]
```

X[options] 合起来表示一个 command，其中 X 是 sed 中的一个单个字符，比如 p (打印)，d(删除)，q(退出)等等，而 X 后面的[options]表示这个命令可以带的参数，可带可不带，比如 q42 表示退出后返回状态码 42

以下用几个简单的命令理解一下 [Address]X[options] 的含义

```shell
# 30,35    Address, 指定处理30-35行的数据
# d 	   Command, 删除命令
sed '30,35d' input.txt 

# /^foo/   Address, 正则表达式，匹配以 foo 开头的所有行
# q		   Command, 退出命令
# 42       Command 的参数，表示返回42的状态码
sed '/^foo/q42' input.txt > output.txt
```

如果是多个 script , 可以用 -e 或者 -f 指定，比如下面的语句都是等价的

```shell
# 先删除以 foo 开头的所有行，然后将所有行中的 hello 替换为 world
sed '/^foo/d ; s/hello/world/' input.txt
#将多个Command 用 -e 表示
sed -e '/^foo/d' -e 's/hello/world/' input.txt
#指定 script 文件，执行 script.sed 文件中的 Command
echo '/^foo/d' > script.sed
echo 's/hello/world/' >> script.sed
sed -f script.sed input.txt
#同时使用-e 和 -f
echo 's/hello/world/' > script2.sed
sed -e '/^foo/d' -f script2.sed input.txt
```

### 4.2 sed Command

#### 特殊的Command s

s 大概是sed 中最重要的命令，因为有非常多的组合操作，所以单独拿出来讲。在文章的开头已经举了一些简单的例子。

```shell
's/regexp/replacement/flags'
#当然中间的分割符也可以使用 | 或 @ 或 # 之类的，比如以下都是等价的
's|regexp|replacement|flags'  
's@regexp@replacement@flags'
's#regexp#replacement#flags'
```

道理很简单，找到所有匹配 regexp 的内容，并替换成 replacement  

replacement 中可以包含 \n   (n 是1-9 的数字)，表示所有匹配结果中的第几个结果，或者用 & 表示这一行中所有匹配的结果。

字符 /  可以

#### 常用 Command

**d**

删除当前PatternSapce 的内容，并立刻进入下一个循环

```

```



#### 不常用Command

#### 需要换行的 Command

 **a/c/i (append/change/insert)** 

上述命令会将后面的command 也作为文本内容一起处理，这会产生语法上的歧义。

1. 比如下面在第一行末尾加上Hello，同时删除第二行，但是结果是 a 后面的所有内容都被append 在1 后面了

```Shell
seq 2 | sed '1aHello ; 2d'
1
Hello ; 2d
2
```

正确的写法应该是用 -e 分开，或者换行进行下一个Command

```Shell
$ seq 2 | sed '1aHello
2d'
1
Hello
$ seq 2 | sed -e '1aHello' -e '2d'
1
Hello
```

**#(注释)**

注释会忽略当前行之后的所有内容

**r, R, w, W (读写文件的命令)**

**e (执行命令)**

**s///[we]  (以w 或e 作为flag结尾的s命令)**

#### 3.2.5 sed commands 总结

以下列出的所有Commands , GNU sed 都支持。有一些是标准的 POSIX commands , 其余的是 GNU 扩展。

- a\

  text

  ​

​       a text

- b label 


### 3.3 sed Address

Address 决定了哪些行会被 sed 的Command 处理，比如下面的命令只会将第144行的hello替换成world

```shell
sed '144s/hello/world/' input.txt
```

如果 Address 为空的话，就会对所有行都用Command处理

```Shell
sed 's/hello/world/' input.txt
```

除了使用数字指定处理范围，还可以用正则，下面对包含关键字apple 的行，将hello替换为world

```Shell
sed '/apple/s/hello/wolrd/g' input.txt
```

### 2.3  退出状态

sed 可以自定义执行后退出的状态码，用于shell 中判断执行结果。0 表示成功， 1表示输入的命令格式不对，2表示输入的文件无法打开(比如不存在，没权限之类的) ，4 表示 I/O 错误。
