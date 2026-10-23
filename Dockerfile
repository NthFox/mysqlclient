# Copy this file to the root of the mysqlclient source repository.
# Build context: repository root. Target platform: linux/amd64 for the ECS host.
ARG PYTHON_IMAGE=registry.cn-hangzhou.aliyuncs.com/maybefox/upstream-python

FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/ \
    PIP_TRUSTED_HOST=mirrors.aliyun.com

RUN sed -Ei \
        's|https?://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g; s|https?://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' \
        /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        gcc libc6-dev pkg-config libmariadb-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/mysqlclient
COPY . .
RUN python -m pip wheel --no-deps --wheel-dir /wheels .

FROM ${PYTHON_IMAGE} AS runtime

# Retain the shared client library, but not the compiler or development headers.
RUN sed -Ei \
        's|https?://deb.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g; s|https?://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' \
        /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get install --no-install-recommends -y libmariadb3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /wheels /tmp/mysqlclient-wheels
RUN python -m pip install --no-index --no-deps /tmp/mysqlclient-wheels/*.whl \
    && rm -rf /tmp/mysqlclient-wheels \
    && python -c "import MySQLdb; print('mysqlclient ready:', MySQLdb.version_info)"

WORKDIR /app
