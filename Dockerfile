# 基础镜像
FROM ubuntu:24.04

# 避免安装时的交互提示
ENV DEBIAN_FRONTEND=noninteractive

# 1. 先删除所有旧的源配置文件
RUN rm -rf /etc/apt/sources.list /etc/apt/sources.list.d/*

# 2. 直接写入全新的中科大源
RUN echo "deb http://mirrors.ustc.edu.cn/ubuntu/ noble main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ noble-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ noble-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://mirrors.ustc.edu.cn/ubuntu/ noble-security main restricted universe multiverse" >> /etc/apt/sources.list

# 安装依赖（编译工具、CMake、Python等）
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libboost-all-dev \
    libpython3-dev \
    python3 \
    wget \
    tar \
    git \
    vim \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /tmp

# 1. 安装 SystemC 3.0.2
COPY lib/systemc-3.0.2.tar.gz /tmp/
RUN tar -xzf systemc-3.0.2.tar.gz && \
    cd systemc-3.0.2 && \
    mkdir build && cd build && \
    ../configure --prefix=/opt/systemc && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && rm -rf systemc-3.0.2 systemc-3.0.2.tar.gz

# 2. 安装 CCI 1.0.2
COPY lib/cci_v1.0.2.tar.gz /tmp/
RUN tar -xzf cci_v1.0.2.tar.gz && \
    cd cci_v1.0.2 && \
    mkdir build && cd build && \
    cmake .. \
    -DSYSTEMC_HOME=/opt/systemc \
    -DCMAKE_INSTALL_PREFIX=/opt/cci \
    -DCMAKE_PREFIX_PATH=/opt/systemc \
    -DSYSTEMC_INCLUDE_DIR=/opt/systemc/include \
    -DSYSTEMC_LIBRARY=/opt/systemc/lib-linux64/libsystemc.so \
    && make -j$(nproc) && make install && \
    cd /tmp && rm -rf cci_v1.0.2 cci_v1.0.2.tar.gz

# 3. 安装 fmt → /opt/fmt 【我帮你加好了】
COPY lib/fmt-master.zip /tmp/
RUN unzip fmt-master.zip && \
    cd fmt-master && \
    mkdir build && cd build && \
    cmake .. \
    -DCMAKE_INSTALL_PREFIX=/opt/fmt \
    -DFMT_TEST=OFF \
    && make -j$(nproc) && make install && \
    cd /tmp && rm -rf fmt-master fmt-master.zip

# 设置环境变量（所有库都装在 /opt/systemc 下，共享路径）
ENV SYSTEMC_HOME=/opt/systemc
ENV CCI_HOME=/opt/cci
ENV FMT_HOME=/opt/fmt

ENV PATH=$SYSTEMC_HOME/bin:$PATH
ENV LD_LIBRARY_PATH=\
$SYSTEMC_HOME/lib-linux64:\
$CCI_HOME/lib:\
$FMT_HOME/lib:\
$LD_LIBRARY_PATH

RUN echo 'cd() { builtin cd "$@" && ls; }' >> ~/.bashrc

# 工作目录挂载点
WORKDIR /home/ubuntu/work
RUN cat > test.cpp <<'EOF'
#include <systemc.h>

int sc_main(int argc, char* argv[]) {
    
    const char* systemc_home = getenv("SYSTEMC_HOME");
    const char* cci_home = getenv("CCI_HOME");
    cout << "===================================" << endl;
    cout << "SYSTEMC 路径: " << systemc_home << endl;
    cout << "CCI 路径: " << cci_home << endl;
    cout << "✅ SystemC & CCI 安装成功！" << endl;
    cout << "===================================" << endl;
    return 0;
}
EOF

# 预编译测试程序（进入容器直接运行）
RUN g++ -o test test.cpp -lsystemc -I$SYSTEMC_HOME/include -L$SYSTEMC_HOME/lib-linux64

# 容器启动后默认进入 bash 终端
CMD ["/bin/bash", "-c", "source ~/.bashrc && ./test && /bin/bash"]
