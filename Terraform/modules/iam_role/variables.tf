variable "lambda_role_name" {
  description = "Nombre del rol IAM para la ejecución de la función Lambda"
  type        = string
}

variable "assume_role_policy" {
  description = "Política de asunción de roles para el rol IAM"
  type        = string
}
