## AWS account level config: region
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

## AWS S3 bucket details
variable "bucket_prefix" {
  description = "Bucket prefix for our datalake"
  type        = string
  default     = "tris-data-lake-"
}

## Key to allow connection to our EC2 instance
variable "key_name" {
  description = "EC2 key name"
  type        = string
  default     = "tris-key"
}

## AWS EMR node type and auto termination time (EMR is expensive!)
variable "instance_type" {
  description = "Instance type for EMR and EC2"
  type        = string
  default     = "m4.xlarge"
}

variable "auto_termination_timeoff" {
  description = "Auto EMR termination time(in idle seconds)"
  type        = number
  default     = 14400 # 4 hours
}

## AWS Redshift credentials and node type
variable "redshift_user" {
  description = "AWS user name for Redshift"
  type        = string
  default     = "tris_user"
}

variable "redshift_password" {
  description = "AWS password for Redshift"
  type        = string
  default     = "Tris1234"
}

variable "redshift_node_type" {
  description = "AWS Redshift node  type"
  type        = string
  default     = "dc2.large"
}

##repository url
variable "repo_url" {
  description = "Repository url to clone into production machine"
  type        = string
  default     = "https://github.com/trisdoan/UserBehavior_project.git"
}