variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = number
  default = 8080
  
}

variable "cluster_name" {
  description = "cluster name as per env"
  type = string
}

variable "instance_type" {
    description = "instance type"
    type = string
}

variable "min_size" {

    description = "min number for instances for autoscale"
    type = number
}

variable "max_size" {

    description = "max number for instances for autoscale"
    type = number
}