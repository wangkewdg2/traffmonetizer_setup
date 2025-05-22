如果已经有traffmonetizer账号，可以跳过第一环节
一：注册账号，获取token
1.点击链接[traffmontizer官网](https://traffmonetizer.com/?aff=230088)，此链接带aff（aff对彼此都好，介意的话自己搜索），按步骤注册账号。
2.获取token,如图所示：
![image](https://tc.cecily.eu.org/file/1747828582529_图片1.png)


二：vps安装并运行traffmonetizer
1.切换到root账户
2.输入：bash -c "$(curl -fsSL https://raw.githubusercontent.com/wangkewdg2/traffmonetizer_setup/main/tm.sh)"
3.按照提示输入token,如图所示：
![image](https://tc.cecily.eu.org/file/1747829000087_image.png)

至此脚本已经安装完成，可以登录官网左侧链接“staus”查看是否已经挂上。

脚本每天凌晨一点会重启traffmonetizer，避免掉线；理论上任何操作系统都可以安装（使用docker），脚本支持AMD64或者ARM64位处理器安装。

常见问题：
1.挂traffmonetizer会不会导致vps被封，或者ip风险因子变高？
答：以实际经验回答，我挂了十多台不同商家的vps，没有vps被封，ip风险因子不会变化，几乎不占用cpu，每月流量10G以内。

2.挂traffmonetizer收益如何？
答：只是给vps的费用回点血，别想赚大钱，根据ip不同，一台vps一年大概3-5美金。目前只有独立ipv4有收益，ipv6没有。
