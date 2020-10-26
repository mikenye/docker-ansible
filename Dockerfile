FROM debian:stable-slim

ENV URL_REPO_ANSIBLE="https://github.com/ansible/ansible.git" \
    URL_REPO_LIBFFI="https://github.com/libffi/libffi.git" \
    URL_REPO_OPENSSL="git://git.openssl.org/openssl.git" \
    URL_REPO_PYTHON="https://github.com/python/cpython.git" \
    URL_PYTHON_DOWNLOAD_SOURCE="https://www.python.org/downloads/source/"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
########## PACKAGE INSTALLATION ##########
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Dependencies for downloading
    TEMP_PACKAGES+=(curl) && \
    KEPT_PACKAGES+=(ca-certificates) && \
    TEMP_PACKAGES+=(git) && \
    # Dependencies for building (general)
    TEMP_PACKAGES+=(build-essential) && \
    # Dependencies for building libffi
    TEMP_PACKAGES+=(autoconf) && \
    TEMP_PACKAGES+=(automake) && \
    TEMP_PACKAGES+=(libtool) && \
    TEMP_PACKAGES+=(libltdl-dev) && \
    KEPT_PACKAGES+=(libltdl7) && \
    # Python dependencies
    KEPT_PACKAGES+=(zlib1g-dev) && \
    # Install packages
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    git config --global advice.detachedHead false && \
########## DEPLOY "openssl" (dependency for ssl in python) ##########
    git clone "$URL_REPO_OPENSSL" "/src/openssl" && \
    pushd "/src/openssl" || exit 1 && \
    BRANCH_OPENSSL=$( \
        # Get list of tags in repo
        git tag --sort="-creatordate" | \
        # Just get stable releases
        grep "OpenSSL_" | grep -vP "pre\d+$" | grep -vP "beta\d+$" | grep -v "reformat" | grep -v "FIPS" | \
        # Sort based on version
        sort --version-sort | \
        # Return latest \
        tail -1) && \
    git checkout "$BRANCH_OPENSSL" && \
    ./config && \
    make && \
    make test && \
    make install_sw && \
    ldconfig && \
    popd || exit 1 && \
########## DEPLOY "libffi" (dependency for ctypes in python) ##########
    git clone "$URL_REPO_LIBFFI" "/src/libffi" && \
    pushd "/src/libffi" || exit 1 && \
    ./autogen.sh && \
    ./configure --disable-docs && \
    make && \
    make install && \
    ldconfig && \
    popd && \
########## DEPLOY "python" ##########
    # Deploy python
    git clone "$URL_REPO_PYTHON" "/src/cpython" && \
    pushd "/src/cpython" || exit 1 && \
    BRANCH_PYTHON=$( \
        # Get list of tags in repo
        git tag --sort="-creatordate" | \
        # Remove release candidate
        grep -vP 'rc\d+$' | \
        # Remove alpha/beta/etc releases
        grep -vP '[a-z]\d+$' | \
        # Keep releases that only begin with 'v'
        grep -P '^v' | \
        # Sort based on version
        sort --version-sort | \
        # Return latest
        tail -1) && \
    git checkout "$BRANCH_PYTHON" && \
    ./configure --enable-optimizations && \
    make && \
    make test && \
    make install
    # python3 -m pip install --upgrade pip && \
    # popd || exit 1
# ########## DEPLOY "ansible" ##########
#     git clone "$URL_REPO_ANSIBLE" "/src/ansible" && \
#     pushd "/src/ansible" && \
#     BRANCH_ANSIBLE=$(git tag --sort="-creatordate" | head -1) && \
#     git checkout "$BRANCH_ANSIBLE"
    
########## Clean up ##########
    # Remove documentation
    # TODO what is needed for ansible-docs?
    # rm -rf /usr/local/share/doc /usr/local/share/man