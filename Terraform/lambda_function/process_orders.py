import json
import boto3
import os

s3 = boto3.client('s3')
sqs = boto3.client('sqs')

# Obtener el nombre de la cola SQS de las variables de entorno
SQS_QUEUE_URL = os.environ['SQS_QUEUE_URL']

def lambda_handler(event, context):
    # Obtener información del evento
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
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

def process_order(order_data):
    # Aquí procesamos el pedido
    print(f"ID del proveedor: {order_data['id_proveedor']}")
    print(f"Fecha del pedido: {order_data['fecha']}")
    
    for item in order_data['pedido']:
        print(f"ID del ítem: {item['id_item']}")
        print(f"Cantidad: {item['cantidad']}")
        print(f"Nota: {item['nota']}")

    # Enviar mensaje a la cola SQS
    send_sqs_message(order_data)

def send_sqs_message(order_data):
    try:
        response = sqs.sendMessageToSQS(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(order_data)
        )
        print(f"Mensaje enviado a la cola SQS: {response['MessageId']}")
    except Exception as e:
        print(f"Error al enviar el mensaje a la cola SQS: {e}")
