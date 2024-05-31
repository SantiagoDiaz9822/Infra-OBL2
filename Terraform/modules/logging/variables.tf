variable "static_lambda_function_name" {
  description = "Nombre de la función Lambda para el sitio estático"
  type        = string
}

variable "process_image_lambda_function_name" {
  description = "Nombre de la función Lambda para el procesamiento de imágenes"
  type        = string
}

variable "process_orders_lambda_function_name" {
  description = "Nombre de la función Lambda para el procesamiento de pedidos"
  type        = string
}
