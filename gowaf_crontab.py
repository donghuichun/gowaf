#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
import datetime
import threading
import urllib.request
import urllib.error
import json
import os
import sys

# 日志文件路径
LOG_FILE = None

# 重定向标准输出到日志文件
def setup_logging():
    global LOG_FILE
    log_dir = ENV_PARAMS.get("config_log_dir", "/tmp")
    # 确保日志目录存在
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    LOG_FILE = os.path.join(log_dir, "gowaf_crontab.log")
    # 重定向标准输出和标准错误到日志文件
    sys.stdout = open(LOG_FILE, "a", encoding="utf-8")
    sys.stderr = sys.stdout

# 自定义打印函数
def log_print(message):
    print(f"[{datetime.datetime.now()}] {message}")
    # 刷新缓冲区，确保日志及时写入
    if LOG_FILE:
        sys.stdout.flush()

# =====================  配置区（根据你的需求修改） =====================
# 读取任务配置文件
def load_tasks():
    """从 conf/gowaf_crontab_tasks.json 文件读取任务配置"""
    tasks_file = os.path.join(os.path.dirname(__file__), "conf/gowaf_crontab_tasks.json")
    try:
        with open(tasks_file, "r", encoding="utf-8") as f:
            tasks = json.load(f)
        log_print(f"成功读取任务配置文件：{tasks_file}")
        return tasks
    except Exception as e:
        log_print(f"读取任务配置文件失败：{e}")
        return []

# 读取 env.lua 文件参数
def load_env():
    """从 env.lua 文件读取参数"""
    env_file = os.path.join(os.path.dirname(__file__), "env.lua")
    env_params = {}
    try:
        with open(env_file, "r", encoding="utf-8") as f:
            content = f.read()
        # 使用正则表达式解析 Lua 文件，提取所需参数
        import re
        # 匹配 api_domain
        api_domain_match = re.search(r'api_domain\s*=\s*["\'](.*?)["\']', content)
        if api_domain_match:
            env_params["api_domain"] = api_domain_match.group(1)
        # 匹配 appid
        appid_match = re.search(r'appid\s*=\s*["\'](.*?)["\']', content)
        if appid_match:
            env_params["appid"] = appid_match.group(1)
        # 匹配 appsecret
        appsecret_match = re.search(r'appsecret\s*=\s*["\'](.*?)["\']', content)
        if appsecret_match:
            env_params["appsecret"] = appsecret_match.group(1)
        # 匹配 config_log_dir
        config_log_dir_match = re.search(r'config_log_dir\s*=\s*["\'](.*?)["\']', content)
        if config_log_dir_match:
            env_params["config_log_dir"] = config_log_dir_match.group(1)
        log_print(f"成功读取环境配置文件：{env_file}")
        return env_params
    except Exception as e:
        log_print(f"读取环境配置文件失败：{e}")
        return env_params

# 加载配置
TASKS = []
ENV_PARAMS = {}

# 构建完整的 URL
from urllib.parse import urlencode

def build_url(path):
    """构建完整的 URL，包含域名和参数"""
    api_domain = ENV_PARAMS.get("api_domain", "http://127.0.0.1:80")
    # 确保域名以 http:// 或 https:// 开头
    if not api_domain.startswith("http://") and not api_domain.startswith("https://"):
        api_domain = "http://" + api_domain
    # 确保路径以 / 开头
    if not path.startswith("/"):
        path = "/" + path
    # 构建完整 URL
    url = api_domain + path
    # 添加参数
    params = {}
    if "appid" in ENV_PARAMS:
        params["appid"] = ENV_PARAMS["appid"]
    if "appsecret" in ENV_PARAMS:
        params["appsecret"] = ENV_PARAMS["appsecret"]
    if params:
        # 检查 URL 是否已经包含查询参数
        if "?" in url:
            url += "&" + urlencode(params)
        else:
            url += "?" + urlencode(params)
    return url

# ===================== 核心定时逻辑（无需修改） =====================
def call_lua_api(url):
    """调用OpenResty的Lua接口（封装HTTP请求，处理异常）"""
    try:
        req = urllib.request.Request(url, method="GET")  # 按需改为POST
        # 如果需要传参/Header，可添加：
        # req.add_header("Content-Type", "application/json")
        # req.add_header("Authorization", "Bearer xxx")  # 网关鉴权
        
        with urllib.request.urlopen(req, timeout=10) as resp:
            # 不打印成功响应
            return True
    except urllib.error.HTTPError as e:
        log_print(f"接口调用失败（HTTP错误）：{url} | 状态码：{e.code}")
    except urllib.error.URLError as e:
        log_print(f"接口调用失败（网络错误）：{url} | 原因：{e.reason}")
    except Exception as e:
        log_print(f"接口调用异常：{url} | 错误：{str(e)}")
    return False

def interval_seconds_task(task):
    """每N秒执行（带误差补偿）"""
    name = task["name"]
    interval = task["interval"]
    url_path = task["url"]
    log_print(f"启动任务：{name}（每{interval}秒执行）")
    
    while True:
        start_time = time.time()
        # 构建完整 URL 并执行任务
        full_url = build_url(url_path)
        call_lua_api(full_url)
        # 计算实际耗时，补偿误差（避免累计延迟）
        elapsed = time.time() - start_time
        sleep_time = max(0, interval - elapsed)
        time.sleep(sleep_time)

def interval_minutes_task(task):
    """每N分钟执行（带误差补偿）"""
    name = task["name"]
    interval = task["interval"] * 60  # 转成秒
    url_path = task["url"]
    log_print(f"启动任务：{name}（每{interval/60}分钟执行）")
    
    while True:
        start_time = time.time()
        # 构建完整 URL 并执行任务
        full_url = build_url(url_path)
        call_lua_api(full_url)
        # 补偿误差
        elapsed = time.time() - start_time
        sleep_time = max(0, interval - elapsed)
        time.sleep(sleep_time)

def daily_time_task(task):
    """每日固定时间执行（精准到秒，自动处理跨天）"""
    name = task["name"]
    target_time = task["time"]
    url_path = task["url"]
    h, m, s = map(int, target_time.split(":"))
    log_print(f"启动任务：{name}（每日{target_time}执行）")
    
    while True:
        # 计算当前时间到目标时间的秒数差
        now = datetime.datetime.now()
        target = now.replace(hour=h, minute=m, second=s, microsecond=0)
        if now > target:
            # 若已过今日目标时间，顺延到明天
            target += datetime.timedelta(days=1)
        delta = (target - now).total_seconds()
        
        # 精准睡眠（每1秒检查一次，避免系统休眠导致的延迟）
        while delta > 0:
            time.sleep(min(1, delta))
            delta -= 1
        
        # 构建完整 URL 并执行任务（补偿执行耗时，确保下次仍准点）
        full_url = build_url(url_path)
        call_lua_api(full_url)

def start_task(task):
    """根据任务类型启动对应的定时线程"""
    task_type = task["type"]
    if task_type == "interval_seconds":
        threading.Thread(target=interval_seconds_task, args=(task,), daemon=True).start()
    elif task_type == "interval_minutes":
        threading.Thread(target=interval_minutes_task, args=(task,), daemon=True).start()
    elif task_type == "daily_time":
        threading.Thread(target=daily_time_task, args=(task,), daemon=True).start()
    else:
        log_print(f"未知任务类型：{task_type}")

if __name__ == "__main__":
    # 先加载配置，再设置日志
    TASKS = load_tasks()
    ENV_PARAMS = load_env()
    # 设置日志
    setup_logging()
    log_print("启动gowaf网关定时任务管理器...")
    # 启动所有任务（每个任务独立线程，互不影响）
    for task in TASKS:
        start_task(task)
    # 主线程保持运行
    try:
        while True:
            time.sleep(3600)  # 主线程休眠1小时，避免退出
    except KeyboardInterrupt:
        log_print("收到停止信号，退出定时任务管理器")