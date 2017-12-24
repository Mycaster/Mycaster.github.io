
---
title: mailRFC
date: 2017-08-24 21:31:22
updated: 2017-08-25 21:43:38
tags: mail
---
	
<!-- toc --><!-- more -->

### 邮箱协议

​	项目中要实现一个第三方的邮箱功能，支持读写邮件等操作。其中读写邮件都是在客户端做的，但是当新邮件到达的时候，客户端没有办法得到通知，也不可能通过轮询去获取是否有新邮件的到达，所以这个任务就只能在服务端做了。服务端的主要工作是轮询邮件服务器，查看是否有新的邮件（指客户端没有的邮件而不是未读的邮件），如果有就通知客户端新邮件的数量。之前没有接触过邮件协议，过程中踩了一些坑。由于服务端没有涉及到发送邮件，所以只重点记录下POP3 和 IMAP 协议。

​	首先邮件协议分为两部分，一个是发送邮件的协议（SMTP），一个是接收邮件的协议（POP3 / IMAP）。POP3是比较老的协议了，IMAP 是改进后的协议，支持更多的操作。现在大部分都支持 IMAP 协议，极少数还只支持 POP3 协议。

​	POP3 和 IMAP 两者最大的区别是：POP3 是从服务器将邮件下载到本地，本地已读的状态是无法同步到服务器上去的，所以要本地自己保存邮件的读取状态。而 IMAP 支持远程读取，更多的功能，包括search之类的。

#### POP3

​	POP3 是很简单的协议。支持的命令只有以下几种：

| Command | 参数       | 说明                                |
| ------- | -------- | :-------------------------------- |
| USER    | 用户名      | 用户名认证                             |
| PASS    | 密码       | 密码认证                              |
| LIST    |          | 列出所有邮件，并按升序返回所有邮件的ID和对应的大小        |
| UIDL    |          | 列出所有邮件，并按升序返回所有邮件的 ID 和 唯一标识符 UID |
| STAT    |          | 统计所有邮件的数量和总大小                     |
| TOP     | ID  LINE | 取得某个具体 ID的邮件的内容的前 LINE 行          |

使用 telnet 简单测试如下：

```shell
[root@ ~]telnet pop.sina.com 110
Trying 113.108.216.75...
Connected to pop.sina.com.
Escape character is '^]'.
+OK sina pop3 server ready      #第一次登陆收到的信息
user ******@sina.com			#user 用户名
+OK welcome to sina mail		#成功回复 +OK (如果用户名错误，将会返回 -ERR)
pass *******					#pass 密码
+OK 2 messages (13182 octets)	#成功回复 +OK  (如果密码错误，将会返回 -ERR auth error)
uidl							#查看所有邮件的 uid
+OK 2 messages (13182 octets)
1 0466D0807445123D248F75FF******5A4400000000000006	#回复格式 id uid
2 04B0289C1E890D96C922190D******389500000000000001
.								#以 . 结束
list							#查看所有邮件，本次连接有效
+OK 2 messages (13182 octets)
1 10684
2 2498
.
stat							#统计邮件
+OK 2 13182						#有2封邮件，总共大小是13182
```

​	那么问题来了，POP3 中没有记录邮件的状态，如何知道这是新的邮件呢？对于客户端来说，一定是要保存所有邮件的 uid ，并在本地记录读取状态的。而服务端要知道是否是新邮件，则必须拿到客户端本地的所有 uid, 然后在每个轮询周期内，获得当前所有邮件的uid，通过对比uid得知哪些是客户端没有的，即新邮件，然后发给客户端。显然这是最简单粗暴的方法，通过数据的冗余实现的。

​	考虑到服务端只是起到提醒的功能，有以下两种方案可以满足大部分的情况：

 1.  服务端只保存客户端最大的邮件的 ID，每次轮询对比当前邮件服务器的最大ID 和客户端的最大ID，如果邮件服务器的最大ID <= 客户端的最大ID， 表示没有新邮件，如果大于，则大于的 ID 为新邮件。客户端每次拉去最新邮件和服务端每次轮询到新邮件都会更新该最大 ID 的值。

     这种方案在 （删除邮件数==新增邮件数）时会错过一次提醒。

2. 服务端保存客户端最大的邮件ID 和邮件的 uid ,每次轮询从邮件服务器的 uid 列表中找到客户端对应的最大ID的 uid，然后在该uid之后的都是新邮件。客户端每次拉去最新邮件和服务端每次轮询到新邮件都会更新该 uid 的值。

   这种方案在 （删除的邮件包括最新的邮件）时会错过一次提醒。

   当然可以将2种方案结合起来，可以达到最小的误差。

> PS.
>
> 1. POP3 的 LIST 命令结果受连接限制，当有新邮件到达时，要重连才回显示。

#### IMAP

IMAP 的命令相对于 POP3来说要复杂一些，但支持的功能也更强大。

```shell
[root@ ~] telnet imap.sina.com 143 
Trying 113.108.216.75...
Connected to imap.sina.com.cn.
Escape character is '^]'.
* OK [CAPABILITY IMAP4rev1 ID] sina imapproxy ready
x login ***** ****										#登陆操作
x OK [CAPABILITY IMAP4rev1 ID] User *** authenticated   #登陆成功
x list "" *								#显示所有的目录
* LIST () "/" "&UXZbg5CuTvY-"
* LIST () "/" "INBOX"
* LIST (\Drafts) "/" "&g0l6P1k5-"
* LIST (\Sent) "/" "&XfJT0ZAB-"
* LIST (\Trash) "/" "&XfJSIJZk-"
* LIST (\Junk) "/" "&V4NXPpCuTvY-"
* LIST () "/" "&i6KWBZCuTvY-"
* LIST () "/" "&Zh9oB5CuTvY-"
* LIST () "/" "&VUaLr0,hYG8-"
* LIST () "/" "&f1F62ZAad+U-"
x OK LIST completed
x select inbox							#选择一个当前目录 （这里选择根目录INBOX）
* 2 EXISTS
* 2 RECENT								#表示有两封新邮件
* OK [UIDVALIDITY 1] UID validity status
* OK [UIDNEXT 4] Predicted next UID
* FLAGS (\Answered \Flagged \Deleted \Draft \Seen)
* OK [PERMANENTFLAGS (\* \Answered \Flagged \Deleted \Draft \Seen)] Permanent flags
* OK [UNSEEN 1] first unseen message in inbox   #表示有一封是未读的
x OK [READ-WRITE] SELECT completed
X search unseen								#搜索所有未读邮件
* search 1 2
X OK SEARCH completed
```











#### 相关资源

1. c/c++ MIME 解析库：

   Mimetic (C++)

   Vmime (C++) :	https://www.vmime.org/downloads.html

   Mime++ (C++)

   Gmime (C++)

   Chilkat 软件MIME C ++库	

2. 邮箱相关服务器信息：
   邮件服务器 | 服务器地址 | 端口
   POP3服务器 | pop.126.com | 110
   SMTP服务器 | smtp.126.com | 25
   IMAP服务器 | imap.126.com | 143

   <!-- tag: mail -->
