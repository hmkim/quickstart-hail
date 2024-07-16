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

  dnf -y install java-11-amazon-corretto-devel blas-devel lapack-devel lz4-devel gcc-c++ 

  curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  python3 get-pip.py

  dnf -y remove python3-requests # remove the cloud-init

  WHEELS="build
  uv
  jupyter"

  for WHEEL_NAME in $WHEELS
  do
    python3 -m pip install "$WHEEL_NAME"
  done
}

function hail_build
{
  echo "Building Hail v.$HAIL_VERSION from source with Spark v.$SPARK_VERSION"

  git clone "$REPOSITORY_URL"
  cd hail/hail/
  git checkout "$HAIL_VERSION"

  export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto
  make install-on-cluster HAIL_COMPILE_NATIVES=1 SPARK_VERSION="$SPARK_VERSION"
}

function hail_install
{
  echo "Installing Hail locally"

  cat <<- HAIL_PROFILE > "$HAIL_PROFILE"
  export SPARK_HOME="/usr/lib/spark"
  export PYSPARK_PYTHON="python3"
  export PYSPARK_SUBMIT_ARGS="--conf spark.kryo.registrator=is.hail.kryo.HailKryoRegistrator --conf spark.serializer=org.apache.spark.serializer.KryoSerializer pyspark-shell"
  export PYTHONPATH="$HAIL_ARTIFACT_DIR/$ZIP_HAIL:\$SPARK_HOME/python:\$SPARK_HOME/python/lib/py4j-src.zip:\$PYTHONPATH"
HAIL_PROFILE

  cp "$PWD/build/deploy/build/lib/hail/backend/$JAR_HAIL" "$HAIL_ARTIFACT_DIR"

  #dnf -y install cloud-init cloud-init-cfg-ec2
}

function cleanup()
{
  rm -rf /root/.gradle
  rm -rf /home/ec2-user/hail
  rm -rf /root/hail
}

install_prereqs
hail_build
hail_install
cleanup
