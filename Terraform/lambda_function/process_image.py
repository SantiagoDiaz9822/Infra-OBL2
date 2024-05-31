import json
import boto3
import os
import logging

# Configura el logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sqs = boto3.client('sqs')

# Obtener la URL de la cola SQS de las variables de entorno
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def lambda_handler(event, context):
    logger.info("Lambda function 'process_image_lambda' invoked")
    
    # Obtener información sobre el evento S3
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    logger.info(f"New image uploaded to bucket {bucket_name} with key {object_key}")
    
    # Crear un mensaje para la cola SQS
    message_body = {
        'bucket': bucket_name,
        'object_key': object_key
    }
    
    try:
        # Enviar el mensaje a la cola SQS
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_body)
        )
        
        logger.info(f"Message sent to SQS queue {SQS_QUEUE_URL} with message ID {response['MessageId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Mensaje enviado a la cola SQS con éxito')
        }
    except Exception as e:
        logger.error(f"Error sending message to SQS queue {SQS_QUEUE_URL}: {e}")
        return {
            'statusCode': 500,
            'body': str(e)
        }
