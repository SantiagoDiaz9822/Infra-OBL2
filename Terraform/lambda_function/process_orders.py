import json
import boto3
import os
import logging

# Configura el logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')
sqs = boto3.client('sqs')

# Obtener el nombre de la cola SQS de las variables de entorno
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def lambda_handler(event, context):
    logger.info("Lambda function 'process_orders_lambda' invoked")
    
    # Obtener información del evento
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    logger.info(f"Processing order file from bucket {bucket_name} with key {object_key}")
    
    try:
        # Obtener el archivo del bucket S3
        file_obj = s3.get_object(Bucket=bucket_name, Key=object_key)
        file_content = file_obj["Body"].read().decode('utf-8')
        
        # Cargar el contenido del archivo JSON
        order_data = json.loads(file_content)
        
        # Procesar el contenido del archivo
        process_order(order_data)
        
        return {
            'statusCode': 200,
            'body': json.dumps('Archivo procesado con éxito')
        }
    except Exception as e:
        logger.error(f"Error processing order file from bucket {bucket_name} with key {object_key}: {e}")
        return {
            'statusCode': 500,
            'body': str(e)
        }

def process_order(order_data):
    logger.info("Processing order data")
    # Aquí procesamos el pedido
    print(f"ID del proveedor: {order_data['id_proveedor']}")
    print(f"Fecha del pedido: {order_data['fecha']}")
    
    for item in order_data['pedido']:
        print(f"ID del ítem: {item['id_item']}")
        print(f"Cantidad: {item['cantidad']}")
        print(f"Nota: {item['nota']}")
        
    logger.info("Order data processed successfully")
    
    # Enviar mensaje a la cola SQS
    send_sqs_message(order_data)

def send_sqs_message(order_data):
    try:
        response = sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(order_data)
        )
        logger.info(f"Message sent to SQS queue {SQS_QUEUE_URL} with message ID {response['MessageId']}")
    except Exception as e:
        logger.error(f"Error sending message to SQS queue {SQS_QUEUE_URL}: {e}")
