#!/bin/bash
set -x -e
export PATH=$PATH:/usr/local/bin

HAIL_ARTIFACT_DIR="/opt/hail"
HAIL_PROFILE="/etc/profile.d/hail.sh"
JAR_HAIL="hail-all-spark.jar"
ZIP_HAIL="hail-python.zip"
REPOSITORY_URL="https://github.com/hail-is/hail.git"

function install_prereqs {
  mkdir -p "$HAIL_ARTIFACT_DIR"

  dnf -y install cmake java-1.8.0-amazon-corretto java-1.8.0-amazon-corretto-devel lz4 lz4-devel blas-devel lapack-devel
  
  dnf -y install python3-pip


}

function hail_build
{
  echo "Building Hail v.$HAIL_VERSION from source with Spark v.$SPARK_VERSION"

  git clone "$REPOSITORY_URL"
  cd hail/hail/
  git checkout "$HAIL_VERSION"

  make install-on-cluster HAIL_COMPILE_NATIVES=1 SCALA_VERSION="2.12.17" SPARK_VERSION="$SPARK_VERSION"
}

function hail_install
{
  echo "Installing Hail locally"

  su - ec2-user -c "pip3 install hail"
  
}

function cleanup()
{
  rm -rf /root/.gradle
  rm -rf /home/ec2-user/hail
  rm -rf /root/hail
}

install_prereqs
#hail_build
hail_install
#cleanup
