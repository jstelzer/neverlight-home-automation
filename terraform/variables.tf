variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default = "ami-0891dc32b63d2234b"
}

variable "userdata" {
  description = "EC2 userdata script"
  type        = string
  default     = ""
}
