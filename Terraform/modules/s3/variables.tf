variable "bucket_name" {
  description = "Name of the bucket."
}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error."
}
