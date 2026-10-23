# Copy this file to the root of the mysqlclient source repository.
# Build context: repository root. Target platform: linux/amd64 for the ECS host.
ARG PYTHON_IMAGE=python:3.13-slim

FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_INDEX_URL=https://pypi.org/simple/ \
    PIP_EXTRA_INDEX_URL="" \
    PIP_TRUSTED_HOST=""

RUN sed -Ei \
        's|https?://mirrors.aliyun.com/debian-security|https://deb.debian.org/debian-security|g; s|https?://mirrors.aliyun.com/debian|https://deb.debian.org/debian|g; s|http://deb.debian.org/|https://deb.debian.org/|g' \
        /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
        'Acquire::ForceIPv4 "true";' \
        'Acquire::Retries "3";' \
        'Acquire::http::Timeout "30";' \
        'Acquire::https::Timeout "30";' \
        'Acquire::http::Pipeline-Depth "0";' \
        > /etc/apt/apt.conf.d/99-acr-build-network \
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
        's|https?://mirrors.aliyun.com/debian-security|https://deb.debian.org/debian-security|g; s|https?://mirrors.aliyun.com/debian|https://deb.debian.org/debian|g; s|http://deb.debian.org/|https://deb.debian.org/|g' \
        /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
        'Acquire::ForceIPv4 "true";' \
        'Acquire::Retries "3";' \
        'Acquire::http::Timeout "30";' \
        'Acquire::https::Timeout "30";' \
        'Acquire::http::Pipeline-Depth "0";' \
        > /etc/apt/apt.conf.d/99-acr-build-network \
    && apt-get update \
    && apt-get install --no-install-recommends -y libmariadb3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /wheels /tmp/mysqlclient-wheels
RUN python -m pip install --no-index --no-deps /tmp/mysqlclient-wheels/*.whl \
    && rm -rf /tmp/mysqlclient-wheels \
    && python -c "import MySQLdb; print('mysqlclient ready:', MySQLdb.version_info)"

WORKDIR /app
