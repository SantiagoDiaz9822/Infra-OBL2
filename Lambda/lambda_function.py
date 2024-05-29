import json
import boto3

def translate_text(text):
    translate = boto3.client('translate')
    result = translate.translate_text(
        Text=text,
        SourceLanguageCode='es',
        TargetLanguageCode='en'
    )
    return result['TranslatedText']

def extract_text_from_image(bucket_name, object_key):
    textract = boto3.client('textract')
    response = textract.detect_document_text(
        Document={'S3Object': {'Bucket': bucket_name, 'Name': object_key}}
    )
    text = ''
    for item in response['Blocks']:
        if item['BlockType'] == 'LINE':
            text += item['Text'] + '\n'
    return text

def lambda_handler(event, context):
    # Ensure that the event is an S3 event
    if event['Records'][0]['eventSource'] != 'aws:s3':
        print("Not an S3 event")
        return

    # Extract bucket name and object key from the event
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']

    # Retrieve the object from S3
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket_name, Key=object_key)
    content_type = response['ContentType']

    if content_type.startswith('image'):
        # Extract text from image using Textract
        image_text = extract_text_from_image(bucket_name, object_key)
        print("Text extracted from the image:")
        print(image_text)
        
        # Translate the extracted text
        translated_content = translate_text(image_text)
        print("Translated text:")
        print(translated_content)

        # Upload the translated content as a new text file
        new_object_key = object_key.replace('spanish/', 'english/').replace('.jpg', '.txt')
        s3.put_object(Bucket=bucket_name, Key=new_object_key, Body=translated_content.encode('utf-8'))

        return {
            'statusCode': 200,
            'body': f"Translated content uploaded to {new_object_key}"
        }
    else:
        # Translate the content from Spanish to English directly
        content = response['Body'].read().decode('utf-8')
        print("Text from non-image file:")
        print(content)
        translated_content = translate_text(content)
        print("Translated text:")
        print(translated_content)

        # Upload the translated content as a new text file
        new_object_key = object_key.replace('spanish/', 'english/').replace('.jpg', '.txt')
        s3.put_object(Bucket=bucket_name, Key=new_object_key, Body=translated_content.encode('utf-8'))

        return {
            'statusCode': 200,
            'body': f"Translated content uploaded to {new_object_key}"
        }
