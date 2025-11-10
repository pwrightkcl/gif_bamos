kFROM ubuntu:22.04

# Use root home directory to avoid cluttering /
WORKDIR /root

# Update base image and install compilation essentials
RUN apt update && apt upgrade -y
RUN apt install -y gcc g++ cmake

# Install Python and pip, then update installers.
RUN apt install -y python3 python3-pip
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install NiftyReg
ADD src/niftyreg /root/src/niftyreg
WORKDIR /root/build/niftyreg
RUN cmake /root/src/niftyreg
RUN make
RUN make install

# Install NiftySeg
RUN apt install -y libeigen3-dev
ADD src/niftyseg /root/src/niftyseg
WORKDIR /root/build/niftyseg
RUN cmake /root/src/niftyseg
RUN make
RUN make install

# Install GIF (comment out if using compiled binary)
ADD src/GIF /root/src/GIF
WORKDIR /root/build/GIF
RUN cmake /root/src/GIF
RUN make
RUN make install

# Install BaMoS
RUN apt install -y bc
ADD src/BaMoS /root/src/BaMoS
WORKDIR /root/build/BaMoS
RUN cmake /root/src/BaMoS
RUN make
RUN make install

# Possible dependencies from GIFBaMoS Dockerfile
# libomp-dev kmod libpam-systemd:amd64 policykit-1 network-manager build-essential linux-headers-generic libbz2-dev
# sqlite libsqlite3-dev zlib1g-dev

# May also need:
# ENV EIGEN3_INCLUDE_DIR=/usr/include/eigen3

# Python dependencies from GIFBaMoS Dockerfile:
# Replaced sklearn with scikit-learn
#RUN  pip3 install numpy \
# && pip3 install pillow \
# && pip3 install scipy \
# && pip3 install cython \
# && pip3 install scikit-image \
# && pip3 install typed_ast \
# && pip3 install seaborn \
# && pip3 install pandas \
# && pip3 install scikit-learn \
# && pip3 install jupyter \
# && pip3 install simpleitk \
# && pip3 install packaging \
# && pip3 install six \
# && pip3 install nibabel \
# && pip3 install configparser \
# && pip3 install pandas \
# && pip3 install blinker

# Install dependencies for BaMoS post-correction script
ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt && \
    rm requirements.txt

# Clean up
RUN rm -r /root/src \
 && rm -r /root/build

# Create user with groups and sudo permission
ARG USER_ID
ARG GROUP_ID
ARG USER
RUN addgroup --gid $GROUP_ID $USER && \
    addgroup --system --gid 999 docker && \
    addgroup --gid 1234 mygroup && \
    useradd --create-home --shell /bin/bash --uid $USER_ID --gid $GROUP_ID --groups 999,1234 $USER && \
    mkdir -p /etc/sudoers.d && \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${USER} && \
    chmod 0440 /etc/sudoers.d/${USER}

# Set up home
WORKDIR /home/$USER
