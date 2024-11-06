// ngx_http_rate_limit_module.c

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <hiredis.h>  // 引入 Redis 客户端库

static ngx_int_t ngx_http_rate_limit_handler(ngx_http_request_t *r);
static char *ngx_http_rate_limit(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);
static ngx_int_t ngx_http_rate_limit_init(ngx_conf_t *cf);

static ngx_command_t ngx_http_rate_limit_commands[] = {
    {
        ngx_string("rate_limit"),
        NGX_HTTP_LOC_CONF|NGX_CONF_NOARGS,
        ngx_http_rate_limit,
        0,
        0,
        NULL
    },
    ngx_null_command
};

static ngx_http_module_t ngx_http_rate_limit_module_ctx = {
    NULL,                        // preconfiguration
    ngx_http_rate_limit_init,    // postconfiguration
    NULL,                        // create main configuration
    NULL,                        // init main configuration
    NULL,                        // create server configuration
    NULL,                        // merge server configuration
    NULL,                        // create location configuration
    NULL                         // merge location configuration
};

ngx_module_t ngx_http_rate_limit_module = {
    NGX_MODULE_V1,
    &ngx_http_rate_limit_module_ctx,  // module context
    ngx_http_rate_limit_commands,     // module directives
    NGX_HTTP_MODULE,                  // module type
    NULL,                             // init master
    NULL,                             // init module
    NULL,                             // init process
    NULL,                             // init thread
    NULL,                             // exit thread
    NULL,                             // exit process
    NULL,                             // exit master
    NGX_MODULE_V1_PADDING
};

// Redis 连接参数
static redisContext *redis_conn = NULL;
static const char *redis_host = "127.0.0.1"; // Redis 地址
static const int redis_port = 6379;          // Redis 端口
static const int max_requests_per_ip = 5;  // 每个 IP 每分钟最多请求次数
static const int rate_limit_window = 60;     // 限制的时间窗口，单位：秒

// 处理限流逻辑
static ngx_int_t ngx_http_rate_limit_handler(ngx_http_request_t *r) {
    u_char *ip = r->connection->addr_text.data;
    redisReply *reply;

    // 拼接 Redis 键（以 IP 地址为键，存储请求计数）
    char key[128];
    snprintf(key, sizeof(key), "rate_limit:%s", ip);

    // 获取 IP 地址的请求计数
    reply = redisCommand(redis_conn, "GET %s", key);
    if (reply == NULL || reply->type == REDIS_REPLY_NIL) {
        // 如果没有记录（首次请求或过期），设置计数为 1
        redisCommand(redis_conn, "SET %s 1 EX %d", key, rate_limit_window);
    } else {
        int request_count = atoi(reply->str);
        if (request_count >= max_requests_per_ip) {
            // 超过最大请求数，返回 HTTP 429 错误
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0, "Jiang Rate limit exceeded for IP: %s", ip);
            return NGX_HTTP_TOO_MANY_REQUESTS;
        }
        // 增加请求计数
        redisCommand(redis_conn, "INCR %s", key);
    }

    return NGX_OK;
}

// 配置文件指令：定义一个指令，启用限流
static char *ngx_http_rate_limit(ngx_conf_t *cf, ngx_command_t *cmd, void *conf) {
    ngx_http_core_loc_conf_t *clcf;

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);

    // 设置请求处理函数
    clcf->handler = ngx_http_rate_limit_handler;

    return NGX_CONF_OK;
}

// 初始化模块
static ngx_int_t ngx_http_rate_limit_init(ngx_conf_t *cf) {
    // 初始化 Redis 连接
    redis_conn = redisConnect(redis_host, redis_port);
    if (redis_conn == NULL || redis_conn->err) {
        ngx_log_error(NGX_LOG_ERR, cf->log, 0, "Failed to connect to Redis: %s", redis_conn->errstr);
        return NGX_ERROR;
    }

    return NGX_OK;
}
