ARG DISTRO=focal
ARG CLANG_MAJOR=12
ARG CMAKE_VERSION=3.21.4
ARG CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.21.4/cmake-3.21.4-linux-x86_64.tar.gz
ARG CONAN_VERSION=1.42.1

FROM ubuntu:${DISTRO} AS cmake-clang
ARG DISTRO
ARG CLANG_MAJOR
ARG CMAKE_URL
ARG CMAKE_VERSION
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG DEBIAN_FRONTEND=noninteractive

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + CMake ${CMAKE_VERSION}"

ENV \
  TZ=Europe/Berlin \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8

# install Clang (https://apt.llvm.org/)
RUN apt-get update --quiet \
  && apt-get upgrade --yes --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    tzdata \
  && wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
  && echo "deb http://apt.llvm.org/${DISTRO}/ llvm-toolchain-${DISTRO}-${CLANG_MAJOR} main" > /etc/apt/sources.list.d/llvm.list \
  && apt-get update --quiet \
  && apt-get install --yes --quiet --no-install-recommends \
    git \
    ninja-build \
    clang-${CLANG_MAJOR} \
    lld-${CLANG_MAJOR} \
    libc++abi-${CLANG_MAJOR}-dev \
    libc++-${CLANG_MAJOR}-dev \
    $( [ $CLANG_MAJOR -ge 12 ] && echo "libunwind-${CLANG_MAJOR}-dev" ) \
  && update-alternatives --install /usr/bin/cc cc /usr/bin/clang-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/clang clang /usr/bin/clang-${CLANG_MAJOR} 100 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.lld-${CLANG_MAJOR} 10 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.gold 20 \
  && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.bfd 30 \
  && c++ --version \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN wget -qO - ${CMAKE_URL} | tar --strip-components=1 -xz -C /usr/local


# final qbs-clang-conan 
FROM cmake-clang AS cmake-clang-conan
ARG DISTRO
ARG CLANG_MAJOR
ARG CMAKE_VERSION
ARG CONAN_VERSION

LABEL Description="Ubuntu ${DISTRO} - Clang${CLANG_MAJOR} + CMake ${CMAKE_VERSION} + Conan ${CONAN_VERSION}"

ENV \
    CONAN_USER_HOME=/conan
RUN \
  apt-get update --quiet \
  && if [ "${RUNTIME_APT}" != "" ] ; then export "RUNTIME_APT2=${RUNTIME_APT}" ; \
    elif [ "${DISTRO}" = "xenial" ] ; then export "RUNTIME_APT2=${RUNTIME_XENIAL}" ; \
    else export "RUNTIME_APT2=${RUNTIME_FOCAL}" ; \
    fi \
  && apt-get install --yes --quiet --no-install-recommends \
    git \
    make \
    libgl1-mesa-dev \
    python3 \
    python3-pip \
    libstdc++-10-dev \
    ${RUNTIME_APT2} \
  && apt-get --yes autoremove \
  && apt-get clean autoclean \
  && pip3 install conan==${CONAN_VERSION} \
  && rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

WORKDIR /project