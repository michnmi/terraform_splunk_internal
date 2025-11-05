terraform {
  required_version = ">= 0.13"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">=0.6.2"
    }
  }
}

provider "libvirt" {
  alias = "vmhost01"
  uri   = "qemu+ssh://jenkins_automation@vmhost01/system?keyfile=../id_ed25519_jenkins"
  # uri   = "qemu+ssh://vmhost01/system"
}

provider "libvirt" {
  alias = "vmhost03"
  uri   = "qemu+ssh://jenkins_automation@vmhost03/system?keyfile=../id_ed25519_jenkins"
  # uri   = "qemu+ssh://vmhost03/system"
}

variable "env" {
  type = string
}

resource "libvirt_volume" "splunk" {
  provider         = libvirt.vmhost03
  name             = "splunk-${var.env}.qcow2"
  pool             = var.env
  base_volume_name = "splunk-base.qcow2"
  format           = "qcow2"
  base_volume_pool = var.env
}

resource "libvirt_domain" "splunk" {
  provider  = libvirt.vmhost03
  name      = "splunk-${var.env}"
  memory    = "4096"
  vcpu      = 4
  autostart = true

  // The MAC here is given an IP through mikrotik
  network_interface {
    macvtap  = "enp1s0"
    mac      = "52:54:00:EA:18:61"
    hostname = "splunk-${var.env}"
  }

  network_interface {
    // network_id = libvirt_network.default.id
    network_name = "default"
  }

  disk {
    volume_id = libvirt_volume.splunk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = 0
  }

  xml {
    xslt = <<EOF
  <?xml version="1.0" ?>
  <xsl:stylesheet version="1.0"
                  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output omit-xml-declaration="yes" indent="yes" />
    <xsl:template match="node()|@*">
       <xsl:copy>
         <xsl:apply-templates select="node()|@*"/>
       </xsl:copy>
    </xsl:template>

    <xsl:template match="/domain">
      <xsl:copy>
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates select="node()"/>
        <memoryBacking>
          <access mode='shared'/>
        </memoryBacking>
      </xsl:copy>
    </xsl:template>

    <xsl:template match="/domain/devices">
      <xsl:copy>
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates select="node()"/>
        <disk type="block" device="disk">
          <driver name="qemu" type="raw" cache="none" io="native"/>
          <source dev="/dev/zvol/data_disk/splunk-prod-volume"/>
          <target dev="vdb" bus="virtio"/>
        </disk>
      </xsl:copy>
    </xsl:template>
  </xsl:stylesheet>
EOF
  }

  lifecycle {
    ignore_changes = [xml, disk]
  }

}
