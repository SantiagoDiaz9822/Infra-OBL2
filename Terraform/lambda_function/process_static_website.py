import boto3
import os
import logging

# Configura el logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client('s3')

def lambda_handler(event, context):
    logger.info("Lambda function 'static_site_lambda' invoked")
    
    bucket_name = os.environ['BUCKET_NAME']
    key = 'index.html'
    
    try:
        response = s3.get_object(Bucket=bucket_name, Key=key)
        content = response['Body'].read().decode('utf-8')
        
        logger.info(f"Successfully retrieved object {key} from bucket {bucket_name}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html'
            },
            'body': content
        }
    except Exception as e:
        logger.error(f"Error retrieving object {key} from bucket {bucket_name}: {e}")
        return {
            'statusCode': 500,
            'body': str(e)
        }
