FROM hhcordero/docker-centos-apache-dev:latest

MAINTAINER DDTech

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d

ENV GPG_KEYS 0B96609E270F565C13292B24C13C70B87267B52D 0BD78B5F97500D450838F95DFE857D9A90D90EC1 F38252826ACD957EF380D39F2F7956BC5DA04B5D
RUN set -xe \
    && for key in $GPG_KEYS; do \
        gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
    done

ENV PHP_VERSION 5.5.30

RUN yum -y install \
        libcurl-devel \
        libjpeg-turbo-devel \
        libpng12-devel \
        libxml2-devel \
        readline-devel \
        recode-devel

RUN cd /tmp && \
    curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz/from/this/mirror" -o php.tar.xz && \
    curl -SL "http://php.net/get/php-$PHP_VERSION.tar.xz.asc/from/this/mirror" -o php.tar.xz.asc && \
    gpg --verify php.tar.xz.asc

RUN cd /tmp && \
    mkdir -p /usr/src/php && \
    tar -xof php.tar.xz -C /usr/src/php --strip-components=1 && \
    rm php.tar.xz* && \
    cd /usr/src/php && \
    ./configure \
        --with-config-file-path="$PHP_INI_DIR" \
        --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
        --with-apxs2 \
        --disable-cgi \
        --enable-mysqlnd \
        --with-curl \
        --with-openssl \
        --with-readline \
        --with-recode \
        --with-zlib && \
    make -j"$(nproc)" && \
    make install && \
    { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } && \
    make clean

COPY docker-php-ext-* /usr/local/bin/

RUN docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr && \
    docker-php-ext-install gd mbstring pdo pdo_mysql zip

RUN echo $'\
<FilesMatch \\.php$>\n\
    SetHandler application/x-httpd-php\n\
</FilesMatch>\n'\
>> /usr/local/apache2/conf/httpd.conf

RUN sed -i -e 's/AllowOverride None/AllowOverride All/i' \
    -e '/^#LoadModule rewrite_module/s/^#//' /usr/local/apache2/conf/httpd.conf

ENV DOC_ROOT /var/www/html

RUN mkdir -p /var/www && \
    rm -rf /usr/local/apache2/htdocs && \
    ln -s /usr/local/apache2/htdocs $DOC_ROOT

WORKDIR $DOC_ROOT

VOLUME $DOC_ROOT

CMD ["httpd-foreground"]
