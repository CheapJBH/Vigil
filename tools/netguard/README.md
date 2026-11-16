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

---

# Vigil Guard：防止随手关闭（含开机自启）

`VigilGuard.ps1` 负责让上述管控**关不掉、关不干净、重启后自动回来**。

## 三层防护（全部系统原生，无需驱动）

| 层 | 机制 | 效果 |
|---|---|---|
| 1 | 服务 SCM 安全描述符（SDDL）移除 `SERVICE_STOP` / `SERVICE_CHANGE_CONFIG` | `net stop`、`sc stop`、服务管理器“停止”→ 拒绝访问 |
| 2 | `sc failure` 自动恢复（`restart/1000` × 3）+ `failureflag 1` | 直接 `taskkill` 掉进程，SCM 1 秒内拉起 |
| 3 | 隐藏计划任务（SYSTEM，`\Microsoft\Windows\Application Experience\` 下，名称由 MachineGuid 派生） | 每 2 分钟校验：服务没启动就启动、启动类型被改就改回、防火墙规则缺了就补 |

## 开机自启

- 服务启动类型强制 `Automatic`，并声明依赖 `Tcpip/Afd`，保证网卡就绪后才启动。
- 计划任务带 `-AtStartup` 触发器，开机即以 SYSTEM 运行一次。
- 防火墙规则写入系统配置，重启不失效；域名 IP 变化由守护任务刷新。

## 口令解锁

```powershell
# 首次部署（同时设置口令）
.\VigilGuard.ps1 -Install -Password 'Jiaoshi2026'

# 正常停用：必须输对口令
.\VigilGuard.ps1 -Release -Password 'Jiaoshi2026'

# 改口令
.\VigilGuard.ps1 -SetPassword -Password 'NewPass'

# 查看状态
.\VigilGuard.ps1 -Status
```

口令以 PBKDF2-SHA256（12 万次迭代 + 16 字节随机盐）存放于
`HKLM\SOFTWARE\VigilGuard`，明文不落盘。

## 诚实的边界

本地管理员仍然可以：取得服务所有权、改写 DACL、停用计划任务、
加载内核驱动。**没有任何用户态方案能阻止管理员**——真正的“不可杀”
需要微软签名的 PPL 反恶意软件驱动。

本方案做到的是：

- 学生（普通账号）**完全无法**关闭；
- 半懂的管理员需要**专门操作**（takeown + sdset + 改任务）才能关，且杀掉会自动复活；
- 正常关闭路径必须输入教师口令。
