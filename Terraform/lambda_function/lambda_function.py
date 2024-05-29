import boto3
import os

s3 = boto3.client('s3')

def lambda_handler(event, context):
    bucket_name = os.environ['BUCKET_NAME']
    key = 'index.html'
    
    try:
        response = s3.get_object(Bucket=bucket_name, Key=key)
        content = response['Body'].read().decode('utf-8')
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'text/html'
            },
            'body': content
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }
