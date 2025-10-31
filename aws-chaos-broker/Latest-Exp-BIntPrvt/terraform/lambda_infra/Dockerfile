FROM debian:bullseye

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get -y install build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libgdbm-dev \ 
    libnss3-dev \
    libssl-dev \
    libreadline-dev \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    wget \
    vim \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get purge -y imagemagick imagemagick-6-common 

# RUN apt-get update && apt-get install -y python3.11

RUN cd /usr/src \
    && wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz \
    && tar -xzf Python-3.11.0.tgz \
    && cd Python-3.11.0 \
    && ./configure --enable-optimizations \
    && make altinstall

RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3.11 1









# # Use the official Python image as the base image
# FROM python:3.11

# # Set the working directory inside the container
# WORKDIR /app

# # Copy the contents of the local directory to the working directory in the container
# COPY Experiment-Broker-Module /app

# COPY build_lambdaaaa.sh /app

# RUN ls -al

# # RUN build_lambdaaaa.sh 

# # Install any necessary dependencies
# RUN pip install --upgrade pip && \
#     pip install awscli

# # Run a script to zip the folder
# CMD [ "handler.handler" ]
# # CMD ["bash", "-c", "zip -r function.zip *"]
