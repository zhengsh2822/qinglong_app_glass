#!/bin/sh
# =============================================================================
# 青龙 dashboard/system 补丁：在返回对象中注入 cpuUsage + 磁盘容量字段
# 适用青龙 2.x 源码安装/刷机模块版（/ql 结构）
# 编译产物路径：/ql/static/build/api/dashboard.js
#
# 用法:
#   sh patch_qinglong_dashboard.sh          # 备份+打补丁+重启 pm2
#   sh patch_qinglong_dashboard.sh rollback # 回退（还原备份+重启）
#
# 关键点:
#   路由回调本身就是 async，可以在 res.send 前 await CPU 双采样，
#   把结果存为 __sysPatch 变量，再在 data 里引用（不能直接在对象字面
#   量里放 async IIFE，否则 JSON.stringify 会把 Promise 变 {}）。
# =============================================================================
set -e

TARGET=/ql/static/build/api/dashboard.js
BAK=${TARGET}.bak
PM2_NAME=qinglong

if [ "$1" = "rollback" ]; then
  if [ ! -f "$BAK" ]; then
    echo "[回退] 未找到备份文件 $BAK ，可能未打过补丁。"
    exit 0
  fi
  cp -f "$BAK" "$TARGET"
  echo "[回退] 已还原 $TARGET"
  echo "[回退] 重启青龙进程..."
  pm2 restart "$PM2_NAME" || pm2 reload "$PM2_NAME" || pm2 restart all
  echo "[回退] 完成。"
  exit 0
fi

if [ ! -f "$TARGET" ]; then
  echo "[错误] 目标文件不存在: $TARGET"
  exit 1
fi

if grep -q "diskUsagePercent\|__sysPatch" "$TARGET"; then
  echo "[提示] 已检测到补丁痕迹，跳过，避免重复注入。"
  echo "       如需重打，先执行: sh $0 rollback"
  exit 0
fi

if [ ! -f "$BAK" ]; then
  cp -f "$TARGET" "$BAK"
  echo "[备份] 已备份到 $BAK"
else
  echo "[备份] 备份已存在，跳过覆盖"
fi

python3 - "$TARGET" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1) 采样变量注入：在 const memUsage = process.memoryUsage(); 之后插入 __sysPatch
anchor_a = "const memUsage = process.memoryUsage();"
if anchor_a not in text:
    print("[错误] 未找到锚点A(const memUsage)，文件结构可能已变更，请核对。")
    sys.exit(2)

sample_block = r"""
            const __sysPatch = await (async () => {
                try {
                    const sample = () => {
                        const cpus = os_1.default.cpus();
                        let idle = 0, total = 0;
                        for (const c of cpus) {
                            const t = c.times;
                            idle += t.idle;
                            total += t.user + t.nice + t.sys + t.idle + t.irq;
                        }
                        return { idle, total };
                    };
                    const a = sample();
                    await new Promise(r => setTimeout(r, 100));
                    const b = sample();
                    const idleDiff = b.idle - a.idle;
                    const totalDiff = b.total - a.total;
                    const cpuUsage = totalDiff > 0
                        ? Number(((1 - idleDiff / totalDiff) * 100).toFixed(1))
                        : 0;
                    let disk = { total: null, free: null, used: null, percent: null };
                    try {
                        const st = require('fs').statfsSync('/');
                        disk.total = st.blocks * st.bsize;
                        disk.free = st.bavail * st.bsize;
                        disk.used = (st.blocks - st.bfree) * st.bsize;
                        disk.percent = Number(((1 - st.bavail / st.blocks) * 100).toFixed(1));
                    } catch (e) { /* 读不到磁盘则保持 null */ }
                    return Object.assign({ cpuUsage }, disk);
                } catch (e) {
                    return { cpuUsage: null, total: null, free: null, used: null, percent: null };
                }
            })();"""
text = text.replace(anchor_a, anchor_a + sample_block, 1)

# 2) 在 data 对象内 cpus 字段后追加字段引用
anchor_b = "cpus: os_1.default.cpus().length,"
if anchor_b not in text:
    print("[错误] 未找到锚点B(cpus)，文件结构可能已变更，请核对。")
    sys.exit(2)

fields = r"""
                    cpus: os_1.default.cpus().length,
                    cpuUsage: __sysPatch ? __sysPatch.cpuUsage : null,
                    diskTotal: __sysPatch ? __sysPatch.total : null,
                    diskFree: __sysPatch ? __sysPatch.free : null,
                    diskUsed: __sysPatch ? __sysPatch.used : null,
                    diskUsagePercent: __sysPatch ? __sysPatch.percent : null,"""
text = text.replace(anchor_b, fields, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("[补丁] 已注入 cpuUsage + 磁盘字段")
PYEOF

if command -v node >/dev/null 2>&1; then
  node --check "$TARGET" && echo "[校验] JS 语法通过" || { echo "[错误] JS 语法校验失败，自动回退"; sh "$0" rollback; exit 1; }
fi

echo "[重启] 重启青龙进程 $PM2_NAME ..."
pm2 restart "$PM2_NAME" || pm2 reload "$PM2_NAME" || pm2 restart all

echo
echo "==== 补丁完成 ===="
echo "验证: curl -s 'http://127.0.0.1:5700/api/dashboard/system' 应看到 cpuUsage/diskTotal 等字段"
echo "回退: sh $0 rollback"