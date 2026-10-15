中文 | [English](/.github/README.en.md)

# Xray 管理脚本 :sparkles:

* 一个纯 Shell 编写的 Xray 管理脚本
* 可选配置:
  * mKCP (VLESS-mKCP-seed)
  * Vision (VLESS-Vision-REALITY)
  * XHTTP (VLESS-XHTTP-REALITY)
  * trojan (Trojan-XHTTP-REALITY)
  * Fallback (包含 VLESS-Vision-REALITY、VLESS-XHTTP-REALITY)
  * SNI (包含 Vision_REALITY、XHTTP_REALITY、XHTTP_TLS)
* SNI 配置由 Nginx 实现 SNI 分流，适合过 CDN、上下行分离、多网站共存等需求
* SNI 分享链接实现了上下行分离(上行 xhttp+TLS+CDN | 下行 xhttp+Reality、上行 xhttp+Reality | 下行 xhttp+TLS+CDN)
* SNI 配置支持管理自定义域名与反代应用，每个站点拥有独立证书、独立站点配置、独立 stream 映射与 UDS
* 规则配置与自填:
  * 禁止 bittorrent 流量(可选)
  * 禁止回国 ip 流量(可选)
  * 屏蔽广告(可选)
  * 添加自定义 WARP Proxy 分流
  * 添加自定义屏蔽分流
* 开关 Cloudflare WARP Proxy( :whale: Docker 部署)
* 开关 geodata 自动更新功能
* xray 端口默认与自填:
  * VLESS-mKCP: 随机生成
  * ALL-REALITY: 443
* UUID 默认与自填:
  * 随机生成
  * 自定义输入标准 UUID
  * 非标准 UUID 映射转化为 UUID
* kcp(seed) 和 trojan(password) 默认与自填:
  * 随机生成(格式: cw-GEMDYgwIV3_g#)
  * 自定义输入
* target 默认与自填:
  * 随机在 serverNames.json 中获取
  * 实现自填 target 的 TLSv1.3 与 H2 验证
  * 实现自填 target 的 serverNames 自动获取
* shortId 默认与自填:
  * 随机生成(默认两个 shortId 例如: 01234567, 0123456789abcdef)
  * 实现自填 shortId
  * 实现输入值为 0 到 8, 则自动生成对 0-16 长度的 shortId
  * 支持逗号分隔的多个值
* path 默认与自填:
  * 随机生成(格式: /8ugSUeNJ.9OEnTErb.dVZMUAFu)
  * 自定义输入(格式: /8ugSUeNJ, 加不加 `/` 都可以)

## 问题

1. 如果安装成功，但无法使用，请在服务器上检查端口是否在监听、防火墙是否放行（例如 `ss -lnt`、`ufw status`）。不要把服务器 IP 或端口提交到第三方探测网站。
2. 使用 SNI 配置前，请确保 VPS 的 HTTP(80) 与 HTTPS(443) 端口开放。
3. 使用 SNI 配置前，请不要开启 CDN 保护，不然无法正常申请 SSL 证书。
4. 上下行分离详情请看 [XHTTP: Beyond REALITY][XHTTP] 与 [xhttp 五合一配置][xhttp 五合一配置] 了解。
5. 使用 SNI 获取证书时遇到 【Could not get nonce, let's try again】 请查看 [ZeroSSL 状态页](https://status.zerossl.com/)，大概率是 ZeroSSL 的【Free ACME Service】处于 【Service disruption】或【Service outage】状态。

## 更新日志

1. v2025.11.19 版本解决【开启 WARP 时没有设置日志限制，导致容器日志会一直叠加，最终占满硬盘空间】问题。
   1. 已启动 WARP 分流的用户可以在【管理配置】->【分流管理】中选择【重置 WARP Proxy】选项，该选项实现清空容器日志与重置 WARP Proxy。
   2. 已添加日志限制，如需使用 WARP 功能直接启用即可。
2. v2026.03.01 版本添加切换 CA 厂商功能，切换 CA 厂商时，脚本会对现有域名证书执行强制重签（`domain`、`cdn` 与 `custom_sites[].domain`），全部成功后才写入新 CA；若中途失败会自动回滚到原 CA，并恢复对应配置，避免影响后续 acme 自动续期任务。
   1. 强制重签会绕过「域名未变化」检查（acme.sh 的 `Domains not changed` 提示场景）。
   2. 请留意 CA 侧签发频率限制（例如 Let's Encrypt 的速率限制）。
3. v2026.03.17 版本添加 SNI 自定义域名与反代应用管理功能，用于在不影响现有 `Reality(domain)` 与 `CDN(cdn)` 站点的前提下，额外挂载多个 HTTPS 反代站点。
   1. 菜单路径：`管理配置 -> SNI 配置管理 -> 管理自定义域名与反代应用`
   2. 支持列表 / 新增 / 编辑 / 删除，自定义站点拥有独立证书、独立 `sites-available/<domain>.conf`、独立 stream 映射与 UDS。
   3. `stream.conf` 会按 `domain`、`cdn`、`custom_sites` 全量重建；UDS 名称规则为 `SHA-256(域名)` 前 `12` 位 + 端口号。
   4. 反代目标支持仅输入端口或完整 `http(s)://host:port` 地址；仅输入端口时自动规范化为 `http://127.0.0.1:<port>`；不接受带 `path`、`query`、`fragment` 的地址。
   5. 编辑时仅修改上游地址不会重复签发证书；修改域名时会先申请新证书，再切换配置，失败自动回滚；删除时会同时清理站点配置、软链、续签记录与证书目录。
   6. 自定义域名不能与 `domain`、`cdn` 或其他自定义站点域名重复；切换 CA 厂商与“强制续签所有证书”都会覆盖自定义站点域名。
   7. 自定义站点为“纯反代站点”，不包含 Xray 的 `xhttp/grpc` 路径，也不接入 Cloudreve 管理逻辑；代理层不会额外注入 `Content-Security-Policy`，由上游应用自行控制 CSP。

## 分享链接

基于[VMessAEAD / VLESS 分享链接标准提案](https://github.com/XTLS/Xray-core/discussions/716)与[v2rayN](https://github.com/2dust/v2rayN)实现，如果其他客户端无法正常使用，请自行根据分享链接进行修改。

SNI 配置中，CDN 的分享链接 Alpn 默认为 H2，如有 H3 需求，请自行在客户端修改。

## 如何使用

* 获取（本 fork，校验证书，不关闭 TLS 校验）

  ```sh
  curl -fsSL --proto '=https' --tlsv1.2 -o "${HOME}/Xray-script.sh" https://raw.githubusercontent.com/freelxs/Xray-script/main/install.sh
  ```

* 使用
  * 启动界面

    ```sh
    bash ${HOME}/Xray-script.sh
    ```

  * 快速安装 Vision

    ```sh
    bash ${HOME}/Xray-script.sh --vision
    ```

  * 快速安装 XHTTP

    ```sh
    bash ${HOME}/Xray-script.sh --xhttp
    ```

  * 快速安装 Fallback

    ```sh
    bash ${HOME}/Xray-script.sh --fallback
    ```

* 快速启动(界面)

  ```sh
  curl -fsSL --proto '=https' --tlsv1.2 -o "${HOME}/Xray-script.sh" https://raw.githubusercontent.com/freelxs/Xray-script/main/install.sh && bash "${HOME}/Xray-script.sh"
  ```

已经克隆本仓库时，直接运行仓库里的 `bash install.sh`。完整本地目录会被安装到目标路径，运行时不会再从网络拉一份覆盖它。

自更新默认关闭。需要从本 fork 更新已安装副本时：

```sh
bash "${HOME}/Xray-script.sh" --update
```

可选 `XRAY_SCRIPT_REF`（分支、标签或 40 位提交）和 `XRAY_SCRIPT_SHA256`（压缩包校验和）。脚本拒绝访问 `zxcvos/Xray-script`。

公网地址默认只来自本机网卡，或来自 `~/.xray-script/config.json` 的 `network.public_ip` / `network.public_ipv6`，也可以用环境变量 `XRAY_SCRIPT_PUBLIC_IP` / `XRAY_SCRIPT_PUBLIC_IPV6`。只有 `XRAY_SCRIPT_IP_LOOKUP=1` 时才会请求 `https://ipv4.icanhazip.com` 和 `https://ipv6.icanhazip.com`。

## 供应链钉扎

| 组件 | 钉扎 |
| --- | --- |
| acme.sh | 3.1.6，校验 SHA-256，并关闭自动升级 |
| Docker 安装脚本 | `docker/docker-install` `ada7a567e59b3935bd601bb21e422da50e80e376`，校验 SHA-256。引擎软件包仍来自 Docker 签名仓库的 stable 通道 |
| Xray 安装脚本 | `XTLS/Xray-install` `e741a4f56d368afbb9e5be3361b40c4552d3710d`，校验 SHA-256。Xray 发行包由该脚本按其附带的 SHA-256 校验 |
| Nginx | 1.30.6，校验 SHA-256，并用仓库内的 nginx.org 开发者公钥验 GPG 签名 |
| OpenSSL | 3.5.9 LTS，校验 SHA-256，并用仓库内的 OpenSSL 发布公钥验 GPG 签名（指纹 `B146647E45A7B33947AB226B2A2C87D161692D40`，与 openssl.org 公布的一致） |
| ngx_brotli | `a71f9312c2deb28875acc7bacfdd5695a111aa53` |
| geodata | 校验 Loyalsoldier 发布的 SHA-256。默认跟踪 `latest`，设置 `GEODATA_TAG` 可固定某一次发布 |

Nginx worker 使用系统用户 `nginx`。主进程仍以 root 启动，以便绑定 80/443。

## 脚本界面

```sh
 __   __  _    _   _______   _______   _____  
 \ \ / / | |  | | |__   __| |__   __| |  __ \ 
  \ V /  | |__| |    | |       | |    | |__) |
   > <   |  __  |    | |       | |    |  ___/ 
  / . \  | |  | |    | |       | |    | |     
 /_/ \_\ |_|  |_|    |_|       |_|    |_|     

Copyright (C) zxcvos | https://github.com/freelxs/Xray-script

-------------------------------------------
Xray       : v25.7.26
CONFIG     : VLESS-Vision-REALITY
WARP Proxy : 已启动
-------------------------------------------

--------------- Xray-script ---------------
 Version      : v2025-07-25
 Description  : Xray 管理脚本
----------------- 装载管理 ----------------
1. 完整安装
2. 仅安装/更新
3. 卸载
----------------- 操作管理 ----------------
4. 启动
5. 停止
6. 重启
----------------- 配置管理 ----------------
7. 分享链接与二维码
8. 信息统计
9. 管理配置
-------------------------------------------
0. 退出
```

## 已测试系统

| Platform | Version    |
| -------- | ---------- |
| Debian   | 10, 11, 12 |
| Ubuntu   | 20, 22, 24 |
| CentOS   | 7, 8, 9    |
| Rocky    | 8, 9       |

以上发行版均通过 Vultr 测试安装。

其他 Debian 基系统与 Red Hat 基系统可能能用，但未测试过，可能存在问题。

## 安装时长说明

SNI 配置适合安装一次后长期使用，不适合反复重置系统安装，这会消耗您的大量时间。如果需要更换配置和域名等，在管理界面都有相应的选项。

更换为非 SNI 配置后，Nginx 将停止服务，但会继续保留在本机，再启用 SNI 配置时不会进行重新安装。

### 安装时长参考

安装流程：

更新系统管理包->安装依赖->[安装Docker]->[安装Cloudreve]->[安装Cloudflare-warp]->安装Xray->安装Nginx->申请证书->配置文件

**这是一台单核1G的服务器的平均安装时长，仅供参考：**

| 项目                | 时长      |
| ------------------- | --------- |
| 更新系统管理包      | 0-10分钟  |
| 安装依赖            | 0-5分钟   |
| 安装Docker          | 1-2分钟   |
| 安装Cloudreve       | 3-5分钟   |
| 安装Cloudflare-warp | 3-5分钟   |
| 安装Xray            | <半分钟   |
| 安装Nginx           | 13-15分钟 |
| 申请证书            | 1-2分钟   |
| 配置文件            | <半分钟  |

### 为什么 SNI 配置安装时间那么长？

脚本的 Nginx 是采用源码编译的形式进行管理安装。

编译相比直接安装二进制文件的优点有：

1. 运行效率高 (编译时采用了-O3优化)
2. 软件版本新

缺点就是编译耗时长。

## 安装位置

**Xray-script:** `/usr/local/xray-script`

**Nginx:** `/usr/local/nginx`

**Cloudreve:** `$HOME/.xray-script/docker/cloudreve`

**Cloudflare-warp:** `$HOME/.xray-script/docker/warp`

**Xray:** 见 **[Xray-install](https://github.com/XTLS/Xray-install)**

## 依赖列表

使用 SNI 配置时，脚本可能自动安装以下依赖：
| 用途                            | Debian基系统                         | Red Hat基系统       |
| ------------------------------- | ------------------------------------ | ------------------- |
| yumdb set(标记包手动安装)       |                                      | yum-utils           |
| dnf config-manager              |                                      | dnf-plugins-core    |
| IP 获取                         | iproute2                             | iproute             |
| DNS 解析                        | dnsutils                             | bind-utils          |
| wget                            | wget                                 | wget                |
| curl                            | curl                                 | curl                |
| wget/curl https                 | ca-certificates                      | ca-certificates     |
| kill/pkill/ps/sysctl/free       | procps                               | procps-ng           |
| epel源                          |                                      | epel-release        |
| epel源                          |                                      | epel-next-release   |
| remi源                          |                                      | remi-release        |
| 防火墙                          | ufw                                  | firewalld           |
| **编译基础：**                  |                                      |                     |
| 下载源码文件                    | wget                                 | wget                |
| 解压tar源码文件                 | tar                                  | tar                 |
| 解压tar.gz源码文件              | gzip                                 | gzip                |
| gcc                             | gcc                                  | gcc                 |
| g++                             | g++                                  | gcc-c++             |
| make                            | make                                 | make                |
| **acme.sh依赖：**               |                                      |                     |
|                                 | curl                                 | curl                |
|                                 | openssl                              | openssl             |
|                                 | cron                                 | crontabs            |
| **编译openssl：**               |                                      |                     |
|                                 | perl-base(包含于libperl-dev)         | perl-IPC-Cmd        |
|                                 | perl-modules-5.32(包含于libperl-dev) | perl-Getopt-Long    |
|                                 | libperl5.32(包含于libperl-dev)       | perl-Data-Dumper    |
|                                 |                                      | perl-FindBin        |
| **编译Brotli：**                |                                      |                     |
|                                 | git                                  | git                 |
|                                 | libbrotli-dev                        | brotli-devel        |
| **编译Nginx：**                 |                                      |                     |
|                                 | libpcre2-dev                         | pcre2-devel         |
|                                 | zlib1g-dev                           | zlib-devel          |
| --with-http_xslt_module         | libxml2-dev                          | libxml2-devel       |
| --with-http_xslt_module         | libxslt1-dev                         | libxslt-devel       |
| --with-http_image_filter_module | libgd-dev                            | gd-devel            |
| --with-google_perftools_module  | libgoogle-perftools-dev              | gperftools-devel    |
| --with-http_geoip_module        | libgeoip-dev                         | geoip-devel         |
| --with-http_perl_module         |                                      | perl-ExtUtils-Embed |
|                                 | libperl-dev                          | perl-devel          |

## 致谢

[Xray-core][Xray-core]

[REALITY][REALITY]

[XHTTP: Beyond REALITY][XHTTP]

[integrated-examples][lxhao61/integrated-examples]

[xhttp 五合一配置][xhttp 五合一配置]

[部署 Cloudflare WARP Proxy][haoel]

[cloudflare-warp 镜像][e7h4n]

[V2Ray 路由规则文件加强版][v2ray-rules-dat]

[kirin10000/Xray-script][kirin10000/Xray-script]

[Cloudreve][cloudreve]

**此脚本仅供交流学习使用，请勿使用此脚本行违法之事。网络非法外之地，行非法之事，必将接受法律制裁。**

[Xray-core]: https://github.com/XTLS/Xray-core (THE NEXT FUTURE)
[REALITY]: https://github.com/XTLS/REALITY (THE NEXT FUTURE)
[XHTTP]: https://github.com/XTLS/Xray-core/discussions/4113 (XHTTP: Beyond REALITY)
[lxhao61/integrated-examples]: https://github.com/lxhao61/integrated-examples (以 V2Ray（v4 版） 或 Xray、Nginx 或 Caddy（v2 版）、Hysteria 等打造常用科学上网的优化配置及最优组合示例，且提供集成特定插件的 Caddy（v2 版） 文件，分享给大家食用及自己备份。)
[xhttp 五合一配置]: https://github.com/XTLS/Xray-core/discussions/4118 (xhttp 五合一配置 \( reality 直连与过 CDN 共存, 附小白可抄的配置\))
[haoel]: https://github.com/haoel/haoel.github.io#943-docker-%E4%BB%A3%E7%90%86 (使用 Docker 快速部署 Cloudflare WARP Proxy)
[e7h4n]: https://github.com/e7h4n/cloudflare-warp (cloudflare-warp 镜像)
[v2ray-rules-dat]: https://github.com/Loyalsoldier/v2ray-rules-dat (V2Ray 路由规则文件加强版)
[kirin10000/Xray-script]: https://github.com/kirin10000/Xray-script (kirin10000/Xray-script)
[cloudreve]: https://github.com/cloudreve/cloudreve (cloudreve)
