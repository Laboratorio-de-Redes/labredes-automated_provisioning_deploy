terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}
provider "openstack" {
  cloud = "labredes-teste"

  endpoint_overrides = {
    "compute"  = "http://10.10.2.9:8774/v2.1/a2b8ec0ac6db4939a9e1843fa5fee4ea/"
    "network"  = "http://10.10.2.9:9696/v2.0/"
    "image"    = "http://10.10.2.9:9292/v2/"
    "volumev3" = "http://10.10.2.9:8776/v3/a2b8ec0ac6db4939a9e1843fa5fee4ea/"
    "identity" = "http://10.10.2.9:5000/v3/"
  }
}
