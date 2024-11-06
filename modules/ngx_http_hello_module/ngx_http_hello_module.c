// ngx_http_hello_module.c
#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

static char *ngx_http_hello(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);
static ngx_int_t ngx_http_hello_handler(ngx_http_request_t *r);

static ngx_command_t ngx_http_hello_commands[] = {
    {
        ngx_string("hello"),
        NGX_HTTP_LOC_CONF|NGX_CONF_NOARGS,
        ngx_http_hello,
        0,
        0,
        NULL
    },
    ngx_null_command
};

static ngx_http_module_t ngx_http_hello_module_ctx = {
    NULL, /* preconfiguration */
    NULL, /* postconfiguration */
    NULL, /* create main configuration */
    NULL, /* init main configuration */
    NULL, /* create server configuration */
    NULL, /* merge server configuration */
    NULL, /* create location configuration */
    NULL  /* merge location configuration */
};

ngx_module_t ngx_http_hello_module = {
    NGX_MODULE_V1,
    &ngx_http_hello_module_ctx, /* module context */
    ngx_http_hello_commands,     /* module directives */
    NGX_HTTP_MODULE,             /* module type */
    NULL,                        /* init master */
    NULL,                        /* init module */
    NULL,                        /* init process */
    NULL,                        /* init thread */
    NULL,                        /* exit thread */
    NULL,                        /* exit process */
    NULL,                        /* exit master */
    NGX_MODULE_V1_PADDING
};

static char *ngx_http_hello(ngx_conf_t *cf, ngx_command_t *cmd, void *conf) {
    ngx_http_core_loc_conf_t *clcf;

    // 获取位置配置
    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);

    // 设置处理函数
    clcf->handler = ngx_http_hello_handler;

    return NGX_CONF_OK;
}

static ngx_int_t ngx_http_hello_handler(ngx_http_request_t *r) {
    ngx_str_t response = ngx_string("Hello, Nginx!");
    
    // 创建缓冲区
    ngx_buf_t *b = ngx_palloc(r->pool, sizeof(ngx_buf_t));
    if (b == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    // 填充缓冲区
    b->pos = response.data;
    b->last = response.data + response.len;
    b->memory = 1;  // 标记该缓冲区在内存中
    b->last_buf = 1;  // 表示这是响应的最后一个缓冲区

    // 设置链表
    ngx_chain_t out;
    out.buf = b;
    out.next = NULL;  // 单个缓冲区节点

    // 设置响应头
    r->headers_out.content_type.len = 4;
    r->headers_out.content_type.data = (u_char *)"text";

    // 设置响应体的长度
    r->headers_out.content_length_n = response.len;

    // 发送响应头
    ngx_http_send_header(r);

    // 发送响应体
    return ngx_http_output_filter(r, &out);
}
