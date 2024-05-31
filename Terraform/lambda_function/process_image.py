import json
import boto3
import os

# Crear un cliente para interactuar con SQS
sqs = boto3.client('sqs')

# Obtener la URL de la cola SQS de las variables de entorno
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def lambda_handler(event, context):
    # Obtener información sobre el evento S3
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    # Crear un mensaje para la cola SQS
    message_body = {
        'bucket': bucket_name,
        'object_key': object_key
    }
    
    # Enviar el mensaje a la cola SQS
    response = sqs.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(message_body)
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Mensaje enviado a la cola SQS con éxito')
    }
