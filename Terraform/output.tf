output "site_url" {
    value = module.static_website.site_url
}

output "sqs_queue_url" {
    value = data.aws_sqs_queue.notification_queue.url
}