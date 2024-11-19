#!/bin/bash

# Nginx 源代码和安装路径配置
NGINX_SRC=${NGINX_SRC:-"./"}

# 第三方库配置
HIREDIS_INCLUDE=${HIREDIS_INCLUDE:-"/usr/include/hiredis"}
HIREDIS_LIB=${HIREDIS_LIB:-"/usr/local/lib"}

# 自定义模块配置
MODULE_PATHS=(
    "modules/ngx_http_rate_limit_module"
    "modules/ngx_http_hello_module"
    # 在此添加更多模块
)

# 编译参数配置
COMPILE_THREADS=${COMPILE_THREADS:-4}
DEBUG_MODE=${DEBUG_MODE:-"yes"}
WITH_SSL=${WITH_SSL:-"no"}
WITH_HTTP2=${WITH_HTTP2:-"yes"}
WITH_PCRE=${WITH_PCRE:-"yes"}
WITH_ZLIB=${WITH_ZLIB:-"no"}
WITH_STREAM=${WITH_STREAM:-"yes"}
WITH_MAIL=${WITH_MAIL:-"no"}
WITH_GZIP=${WITH_GZIP:-"no"}
WITH_STUB_STATUS=${WITH_STUB_STATUS:-"yes"}
WITH_REALIP=${WITH_REALIP:-"yes"}
WITH_GUNZIP=${WITH_GUNZIP:-"yes"}
WITH_THREADS=${WITH_THREADS:-"yes"}
WITH_FILE_AIO=${WITH_FILE_AIO:-"yes"}

# 清理选项
CLEAN_BEFORE_BUILD=${CLEAN_BEFORE_BUILD:-"no"}
BACKUP_OLD_NGINX=${BACKUP_OLD_NGINX:-"yes"}

# 缓存文件路径
CACHE_FILE=".build_cache"
CONFIGURED_FILE=".configured"

# 错误处理函数
error_exit() {
    echo "错误: $1" >&2
    exit 1
}

# 检查必要条件
check_prerequisites() {
    if [ "$FORCE_CHECK" != "yes" ] && [ -f "$CACHE_FILE" ]; then
        echo "已检测到缓存文件，跳过环境检查。"
        return
    fi

    # 检查必要的命令
    command -v make >/dev/null 2>&1 || error_exit "未找到 make 命令，请先安装"
    command -v gcc >/dev/null 2>&1 || error_exit "未找到 gcc 命令，请先安装"
    
    # 检查 Nginx 源码目录
    if [ ! -d "$NGINX_SRC" ]; then
        error_exit "Nginx 源码目录不存在: $NGINX_SRC"
    fi
    
    # 检查 auto/configure 文件
    if [ ! -f "$NGINX_SRC/auto/configure" ]; then
        error_exit "未找到 auto/configure 文件，请确认 Nginx 源码完整性"
    fi
    
    # 检查自定义模块目录
    for module in "${MODULE_PATHS[@]}"; do
        if [ ! -d "$NGINX_SRC/$module" ]; then
            error_exit "模块目录不存在: $module"
        fi
    done
    
    # 检查 hiredis 相关文件
    if [ ! -d "$HIREDIS_INCLUDE" ]; then
        error_exit "hiredis 头文件目录不存在: $HIREDIS_INCLUDE"
    fi
    
    if [ ! -d "$HIREDIS_LIB" ]; then
        error_exit "hiredis 库文件目录不存在: $HIREDIS_LIB"
    fi

    # 创建缓存文件
    touch "$CACHE_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
    -h, --help              显示此帮助信息
    -c, --clean            构建前清理
    -d, --debug            启用调试模式
    -j N                    设置编译线程数为 N
    -i, --install          编译后自动安装
    -b, --backup           备份已安装的 Nginx
    --prefix=PATH          设置安装路径
    --no-ssl               禁用 SSL 支持
    --no-http2             禁用 HTTP/2 支持
    --force-check          强制重新检查环境
    --skip-configure       跳过配置步骤
    
环境变量:
    NGINX_SRC              Nginx 源码路径
    NGINX_PREFIX           安装路径
    COMPILE_THREADS        编译线程数
    DEBUG_MODE            调试模式 (yes/no)
    WITH_SSL              SSL 支持 (yes/no)
    WITH_HTTP2            HTTP/2 支持 (yes/no)
    ...更多参见脚本中的变量定义
EOF
    exit 0
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -c|--clean)
                CLEAN_BEFORE_BUILD="yes"
                shift
                ;;
            -d|--debug)
                DEBUG_MODE="yes"
                shift
                ;;
            -j*)
                COMPILE_THREADS="${1#-j}"
                shift
                ;;
            -i|--install)
                AUTO_INSTALL="yes"
                shift
                ;;
            --prefix=*)
                NGINX_PREFIX="${1#*=}"
                shift
                ;;
            --force-check)
                FORCE_CHECK="yes"
                shift
                ;;
            --skip-configure)
                SKIP_CONFIGURE="yes"
                shift
                ;;
            *)
                echo "未知选项: $1"
                show_help
                ;;
        esac
    done
}

# 备份现有 Nginx
backup_nginx() {
    if [ "$BACKUP_OLD_NGINX" = "yes" ] && [ -d "$NGINX_PREFIX" ]; then
        local backup_dir="${NGINX_PREFIX}_backup_$(date +%Y%m%d_%H%M%S)"
        echo "备份现有 Nginx 到 $backup_dir"
        mv "$NGINX_PREFIX" "$backup_dir" || error_exit "备份失败"
    fi
}

# 构建配置参数
build_configure_args() {
    local configure_args=""
    
    # 添加功能模块
    [ "$DEBUG_MODE" = "yes" ] && configure_args+=" --with-debug"
    [ "$WITH_SSL" = "yes" ] && configure_args+=" --with-http_ssl_module"
    [ "$WITH_HTTP2" = "yes" ] && configure_args+=" --with-http_v2_module"
    [ "$WITH_PCRE" = "yes" ] && configure_args+=" --with-pcre"
    [ "$WITH_ZLIB" = "yes" ] && configure_args+=" --with-zlib"
    [ "$WITH_STREAM" = "yes" ] && configure_args+=" --with-stream"
    [ "$WITH_MAIL" = "yes" ] && configure_args+=" --with-mail"
    [ "$WITH_STUB_STATUS" = "yes" ] && configure_args+=" --with-http_stub_status_module"
    [ "$WITH_REALIP" = "yes" ] && configure_args+=" --with-http_realip_module"
    [ "$WITH_GUNZIP" = "yes" ] && configure_args+=" --with-http_gunzip_module"
    [ "$WITH_THREADS" = "yes" ] && configure_args+=" --with-threads"
    [ "$WITH_FILE_AIO" = "yes" ] && configure_args+=" --with-file-aio"
    
    # 添加自定义模块
    for module in "${MODULE_PATHS[@]}"; do
        configure_args+=" --add-module=$module"
    done
    
    # 添加第三方库配置
    configure_args+=" --with-cc-opt=\"-I$HIREDIS_INCLUDE\""
    configure_args+=" --with-ld-opt=\"-L$HIREDIS_LIB -lhiredis\""
    
    echo "$configure_args"
}

# 清理构建目录
clean_build() {
    if [ "$CLEAN_BEFORE_BUILD" = "yes" ]; then
        echo "清理构建目录..."
        make clean >/dev/null 2>&1
        rm -f Makefile objs/Makefile
        rm -f "$CONFIGURED_FILE"
    fi
}

# 主函数
main() {
    # 解析命令行参数
    parse_args "$@"
    
    # 检查必要条件
    check_prerequisites
    
    # 进入 Nginx 源代码目录
    cd "$NGINX_SRC" || error_exit "无法进入 Nginx 源代码目录"
    
    # 清理构建目录
    clean_build
    
    # 配置
    if [ "$SKIP_CONFIGURE" != "yes" ] && [ ! -f "$CONFIGURED_FILE" ]; then
        local configure_args
        configure_args=$(build_configure_args)
        
        echo "开始配置 Nginx..."
        echo "配置参数: $configure_args"
        eval "./auto/configure $configure_args" || error_exit "配置失败"
        
        # 创建标记文件
        touch "$CONFIGURED_FILE"
    else
        echo "跳过配置步骤。"
    fi
    
    # 编译
    echo "开始编译 Nginx..."
    make -j"$COMPILE_THREADS" || error_exit "编译失败"
    
    # 如果需要安装
    if [ "$AUTO_INSTALL" = "yes" ]; then
        echo "开始安装 Nginx..."
        backup_nginx
        sudo make install || error_exit "安装失败"
        echo "Nginx 安装完成！"
    else
        echo "Nginx 编译成功！"
        echo "如需安装，请运行: sudo make install"
    fi
}

# 执行主函数
main "$@"
