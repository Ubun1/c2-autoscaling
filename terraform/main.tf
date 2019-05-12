variable "ec2_url" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "vpc_cidr_block" {}
variable "instance_type" {}
variable "big_instance_type" {}
variable "az" {}
variable "ami" {}
variable "client_ip" {}
variable "material" {}
 
provider "aws" {
    endpoints {
        ec2 = "${var.ec2_url}"
    }
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_region_validation = true
 
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}
 
resource "aws_vpc" "vpc" {
    cidr_block = "${var.vpc_cidr_block}"
}
 
resource "aws_subnet" "subnet" {
    availability_zone = "${var.az}"
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 0)}"
}
 
resource "aws_security_group" "sg" {
    name = "auto-scaling"
    vpc_id = "${aws_vpc.vpc.id}"
 
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 0)}"]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["${cidrsubnet(aws_vpc.vpc.cidr_block, 8, 0)}"]
    }

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
}
 
resource "aws_key_pair" "key" {
  key_name   = "auto-scaling-new"
  public_key = "${var.material}"
}
 
resource "aws_instance" "compute" {
  count             =  5
  ami               = "${var.ami}"
  instance_type     = "${count.index == 0 ? var.big_instance_type : var.instance_type}"
  key_name          = "${aws_key_pair.key.key_name}"
  subnet_id         = "${aws_subnet.subnet.id}"
  availability_zone = "${var.az}"
  security_groups   = ["${aws_security_group.sg.id}"]
}
 
resource "aws_eip" "pub_ip" {
  instance = "${aws_instance.compute.0.id}"
  vpc      = true
}
 
output "awx" {
  value = "${aws_eip.pub_ip.public_ip}"
}
 
output "haproxy_id" {
    value = ["${slice(aws_instance.compute.*.id, 1, 3)}"]
}
 
output "awx_id" {
  value = "${aws_instance.compute.0.id}"
}
 
output "backend_id" {
  value = ["${slice(aws_instance.compute.*.id, 3, 5)}"]
}
