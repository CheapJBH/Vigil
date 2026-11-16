# Vigil 网络访问白名单 (Vigil NetGuard)

教室学生机的出站网络管控：**默认阻断一切出站流量，只放行白名单**。

## 为什么不是"域名过滤器"

Windows 防火墙工作在网络层（IP / 端口 / 进程），不理解域名，也无法识别
Minecraft、QQ、游戏客户端这类私有二进制协议。因此唯一可靠的模型是：

```
默认出站 = 阻断
白名单 = 域名讲出的 IP + 显式 IP/网段 + 显式进程 + 端口
```

任何未登记的流量——包括自己写 socket、硬编码 IP、P2P、游戏协议——一律被丢包。
这正是你要的效果：**不加白名单就连不上，加了才通。**

## 白名单的四种粒度

| 类型 | 写法 | 适用场景 |
|---|---|---|
| 域名 | `www.example.edu.cn` | 普通网站，自动解析成 IP 并定时刷新 |
| IP / 网段 | `203.0.113.10`, `203.0.113.0/24` | 固定服务器、CDN 段 |
| 端口 | `{"ip":"mc.example.com","port":25565,"protocol":"tcp"}` | MC 服务器、自建服务 |
| 程序 | `C:\Program Files\Minecraft\runtime\javaw.exe` | 整体放行某个客户端 |

## 用法

```powershell
# 以管理员身份
.\VigilNetGuard.ps1 -Policy .\netguard-policy.json      # 应用策略
.\VigilNetGuard.ps1 -Status                              # 查看当前状态
.\VigilNetGuard.ps1 -Clear                               # 全部撤销、恢复原状
.\VigilNetGuard.ps1 -Policy .\p.json -DryRun             # 只打印将创建的规则
```

## 策略文件

见 `netguard-policy.example.json`，全部字段都有默认值，可只写要改的部分。

## 防绕过边界（如实说明）

- 规则作用于 Domain / Private / Public 三个配置文件，学生普通账号无权重置。
- 守护任务以 SYSTEM 运行，每 60 秒校验并补回被删的规则。
- **拥有本地管理员权限的学生仍可绕过**（停服务、改防火墙、装驱动）。
  要防到这一层需要内核过滤驱动（WFP callout）与安全启动策略，不在本工具范围。
