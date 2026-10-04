#!/usr/bin/env python3
"""☢ REACTOR sidebar telemetry — one JSON snapshot for eww.

Reads sysfs/hwmon directly; shells out only for nvidia-smi, tailscale,
powerprofilesctl, bluetoothctl and wpctl (each optional).
"""
import json, os, re, shutil, subprocess, sys, time

MODE = sys.argv[1] if len(sys.argv) > 1 else "fast"

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE = os.path.join(RUN, "reactor-eww-cpu.stat")


def sh(*cmd, timeout=1.5):
    if not shutil.which(cmd[0]):
        return ""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except Exception:
        return ""


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except Exception:
        return default


def level(v, warm, hot):
    return "hot" if v >= hot else "warm" if v >= warm else "ok"


def hwmons():
    base = "/sys/class/hwmon"
    for h in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        p = os.path.join(base, h)
        yield p, read(os.path.join(p, "name"))


def hw_temp(*names):
    for p, n in hwmons():
        if n in names:
            v = read(os.path.join(p, "temp1_input"))
            if v.isdigit():
                return int(v) // 1000
    return 0


# ---------- toggles (slow commands, polled less often) ----------
if MODE == "slow":
    profile = sh("powerprofilesctl", "get") or "balanced"
    ts = sh("tailscale", "status", "--json").replace(" ", "")
    vpn = '"BackendState":"Running"' in ts
    bt = "Powered: yes" in sh("bluetoothctl", "show")
    vol_raw = sh("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")
    mic_raw = sh("wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@")
    try:
        vol = round(float(vol_raw.split()[1]) * 100)
    except Exception:
        vol = 0
    print(json.dumps({"profile": profile, "vpn": vpn, "bt": bt, "vol": vol,
                      "vol_muted": "MUTED" in vol_raw, "mic_muted": "MUTED" in mic_raw}))
    sys.exit(0)

# ---------- CPU load (delta against last snapshot) ----------
fields = list(map(int, read("/proc/stat").splitlines()[0].split()[1:9]))
total, idle = sum(fields), fields[3] + fields[4]
load = 0
try:
    pt, pi = map(int, read(STATE).split())
    if total > pt:
        load = round(100 * ((total - pt) - (idle - pi)) / (total - pt))
except Exception:
    pass
try:
    with open(STATE, "w") as f:
        f.write(f"{total} {idle}")
except Exception:
    pass
ctemp = hw_temp("k10temp", "zenpower", "coretemp")

# ---------- GPU ----------
gload = gtemp = gfan = 0
gpu = {"w": 0, "wmax": 0, "vu": 0, "vt": 0, "vp": 0, "clk": 0, "mclk": 0}
g = sh("nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,fan.speed,power.draw,"
       "power.limit,memory.used,memory.total,clocks.gr,clocks.mem",
       "--format=csv,noheader,nounits")
if g:
    def num(x):
        try: return float(x)
        except Exception: return 0.0
    v = [num(x.strip()) for x in g.splitlines()[0].split(",")] + [0.0] * 9
    gload, gtemp, gfan = int(v[0]), int(v[1]), int(v[2])
    gpu = {"w": round(v[3]), "wmax": round(v[4]), "vu": round(v[5] / 1024, 1), "vt": round(v[6] / 1024),
           "vp": round(v[5] * 100 / v[6]) if v[6] else 0, "clk": int(v[7]), "mclk": int(v[8])}
else:
    gtemp = hw_temp("amdgpu")

# ---------- CPU power + network: deltas since the previous poll ----------
DSTATE = os.path.join(RUN, "reactor-eww-delta.json")
now = time.time()

rapl, rapl_ok = None, False
for z in sorted(os.listdir("/sys/class/powercap")) if os.path.isdir("/sys/class/powercap") else []:
    zp = os.path.join("/sys/class/powercap", z)
    if read(os.path.join(zp, "name")) == "package-0":
        e = read(os.path.join(zp, "energy_uj"))
        if e.isdigit():
            rapl, rapl_ok = int(e), True
        break

iface = ""
for line in read("/proc/net/route").splitlines()[1:]:
    f = line.split()
    if len(f) > 1 and f[1] == "00000000":
        iface = f[0]
        break
rx = int(read(f"/sys/class/net/{iface}/statistics/rx_bytes", "0") or 0) if iface else 0
tx = int(read(f"/sys/class/net/{iface}/statistics/tx_bytes", "0") or 0) if iface else 0

cpu_w = down = upl = 0
try:
    prev = json.loads(read(DSTATE, "{}"))
    dt = now - prev.get("t", now)
    if 0.2 < dt < 30:
        if rapl_ok and prev.get("e") is not None and rapl >= prev["e"]:
            cpu_w = round((rapl - prev["e"]) / 1e6 / dt)
        if prev.get("if") == iface:
            down = max(0, (rx - prev.get("rx", rx)) / dt)
            upl = max(0, (tx - prev.get("tx", tx)) / dt)
except Exception:
    pass
try:
    with open(DSTATE, "w") as f:
        json.dump({"t": now, "e": rapl, "rx": rx, "tx": tx, "if": iface}, f)
except Exception:
    pass


def rate(b):
    for unit, size in (("GB/s", 1e9), ("MB/s", 1e6), ("KB/s", 1e3)):
        if b >= size:
            return f"{b / size:.1f} {unit}"
    return f"{int(b)} B/s"


# ---------- RAM / SSD ----------
mem = {}
for line in read("/proc/meminfo").splitlines():
    k, v = line.split(":", 1)
    mem[k] = int(v.split()[0])
mt, ma = mem.get("MemTotal", 1), mem.get("MemAvailable", 0)
ram_p = round((mt - ma) * 100 / mt)
st = os.statvfs("/")
ssd_p = round(100 * (1 - st.f_bavail / max(1, st.f_blocks)))
ssd_t = hw_temp("nvme")

# ---------- uptime ----------
secs = int(float(read("/proc/uptime", "0").split()[0]))
d, r = divmod(secs, 86400)
h, r = divmod(r, 3600)
m = r // 60
up = (f"{d}d " if d else "") + f"{h}h {m:02d}m"

print(json.dumps({
    "up": up,
    "cpu": {"t": ctemp, "l": load, "cls": level(ctemp, 75, 88)},
    "gpu": {"t": gtemp, "l": gload, "cls": level(gtemp, 70, 83)},
    "ram": {"p": ram_p, "cls": level(ram_p, 75, 90)},
    "ssd": {"p": ssd_p, "t": ssd_t, "cls": level(ssd_p, 80, 92)},
    "gpux": gpu,
    "pw": {"cpu": cpu_w, "gpu": gpu["w"], "core": cpu_w + gpu["w"], "cpu_ok": rapl_ok},
    "net": {"if": iface or "offline", "down": rate(down), "up": rate(upl),
            "down_k": round(down / 1024), "up_k": round(upl / 1024)},
}))
