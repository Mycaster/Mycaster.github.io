
---
title: c学习笔记
date: 2017-08-01 21:54:27
updated: 2017-08-25 21:27:46
tags: c
---
	
<!-- toc --><!-- more -->


#### extern 的声明：

以下两种正确的对字符串类型声明的写法：

```c
char str [] = "hello";
extern char str[];

char *str = "hello";
extern char * str;
```



变量 str 的定义只进行了一次，其空间的分配也只进行了一次，但是对该变量的声明却可以有多次。由于程序的编译和链接是两个分离的步骤，在链接时，通过extern 声明的变量可能类型与定义类型一致，比如 str * 和  str[] 都表示指向字符串数组的指针，但是其内存分布却完全不同。

```C
char str [] = "hello";
extern char str*;
```

![未命名.001](./未命名.001.jpeg)



#### typedef 类型定义

```C
typedef void (*fp) (int, char*);

typedef struct person
{
  int pid;
  char *name;
}person;
```





#### 数组的退化



<!-- tag: c -->
