variable "lambda_role_arn" {
  description = "ARN del rol IAM para la ejecución de la función Lambda"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL de la cola SQS para el procesamiento de imágenes"
  type        = string
}
