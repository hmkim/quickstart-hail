packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {}
variable "associate_public_ip_address" {}
variable "ssh_interface" {}
variable "instance_type" {}
variable "volume_size_root" {}
variable "volume_type_root" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "hail_name_version" {}
variable "ami_description" {}
variable "instance_profile_name" {}
variable "emr_version" {}
variable "hail_version" {}
variable "htslib_version" {}
variable "samtools_version" {}
variable "spark_version" {}
variable "vep_version" {
  default = null
}
variable "roda_bucket" {}

source "amazon-ebs" "hail_ami" {
  region                      = var.region
  associate_public_ip_address = var.associate_public_ip_address
  ssh_interface               = var.ssh_interface
  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "al2023-ami-2023.5.20240701.0-kernel-6.1-x86_64"
      root-device-type    = "ebs"
      architecture        = "x86_64"
    }
    owners      = ["amazon"]
    most_recent = true
  }
  instance_type = var.instance_type
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = var.volume_size_root
    volume_type           = var.volume_type_root
    delete_on_termination = true
  }
  vpc_id                  = var.vpc_id
  subnet_id               = var.subnet_id
  ssh_username            = "ec2-user"
  ami_name = var.vep_version != null ? "hail-${var.hail_name_version}-vep-${var.vep_version}" : "hail-${var.hail_name_version}"
  ami_description         = var.ami_description
  iam_instance_profile    = var.instance_profile_name
  tags = {
    Name              = "hail-${var.hail_name_version}"
    "emr-version"     = var.emr_version
    "hail-version"    = var.hail_version
    "htslib-version"  = var.htslib_version
    "managed-by"      = "packer"
    "packer-version"  = packer.version
    "samtools-version" = var.samtools_version
    "source-ami"      = "{{ .SourceAMIName }}"
    "spark-version"   = var.spark_version
    "vep-version"     = var.vep_version != null ? var.vep_version : "N/A"
  }
}

build {
  sources = ["source.amazon-ebs.hail_ami"]

  provisioner "shell" {
    inline = [
      "echo -e '* soft nofile 8192\n* hard nofile 8192' | sudo tee -a /etc/security/limits.conf"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "RODA_BUCKET=${var.roda_bucket}",
      "HTSLIB_VERSION=${var.htslib_version}",
      "SAMTOOLS_VERSION=${var.samtools_version}",
      "VEP_VERSION=${var.vep_version != null ? var.vep_version : "none"}"
    ]
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "scripts/htslib.sh",
      "scripts/samtools.sh",
      "scripts/vep_install.sh"
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "HAIL_VERSION=${var.hail_version}",
      "SPARK_VERSION=${var.spark_version}"
    ]
    execute_command = "sudo -S bash -c 'ulimit -Sn && ulimit -Hn && {{ .Vars }} {{ .Path }}'"
    scripts         = ["scripts/hail_build.sh"]
  }

  provisioner "file" {
    source      = "scripts/R_install.R"
    destination = "/tmp/R_install.R"
  }

  provisioner "shell" {
    inline = [
      "sudo dnf install -y R",
      "sudo R --no-save < /tmp/R_install.R && rm /tmp/R_install.R"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo sed -i '$d' /etc/security/limits.conf && sudo sed -i '$d' /etc/security/limits.conf"
    ]
  }

  provisioner "file" {
    source      = "scripts/cluster_manifest.sh"
    destination = "/tmp/cluster_manifest.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod 755 /tmp/cluster_manifest.sh",
      "sudo mv /tmp/cluster_manifest.sh /usr/local/bin/cluster_manifest.sh"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo -S bash -c '{{ .Path }}'"
    scripts         = ["scripts/ami_cleanup.sh"]
  }
}

