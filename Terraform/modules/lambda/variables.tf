variable "function_name" {
  description = "El nombre de la función Lambda"
  type        = string
}

variable "handler" {
  description = "El manejador de la función Lambda"
  type        = string
}

variable "runtime" {
  description = "El runtime de la función Lambda"
  type        = string
}

variable "role_arn" {
  description = "El ARN del rol IAM para la función Lambda"
  type        = string
}

variable "s3_bucket" {
  description = "El bucket S3 que contiene el código de la función Lambda"
  type        = string
}

variable "s3_key" {
  description = "La clave del objeto S3 que contiene el código de la función Lambda"
  type        = string
}

variable "environment_variables" {
  description = "Variables de entorno para la función Lambda"
  type        = map(string)
  default     = {}
}
