#!/bin/bash

# Nginx 源代码路径
# NGINX_SRC="/path/to/nginx"

# TODO:增加配置时异常检测

# 模块路径
MODULE1="modules/ngx_http_rate_limit_module"
MODULE2="modules/ngx_http_hello_module"

# 进入 Nginx 源代码目录
# cd $NGINX_SRC

# 配置并编译 Nginx
# 指定头文件方法
# auto/configure --add-module=modules/ngx_http_rate_limit_module  --with-cc-opt="-I/usr/local/include/hiredis" --with-ld-opt="-L/usr/local/lib -lhiredis"
# --with-debug 打开调试模式

auto/configure --with-debug --add-module=$MODULE1 --add-module=$MODULE2 --with-cc-opt="-I/usr/local/include/hiredis" --with-ld-opt="-L/usr/local/lib -lhiredis"
make -j10
# sudo make install
