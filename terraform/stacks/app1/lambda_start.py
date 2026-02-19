import boto3
import os

ec2 = boto3.client('ec2')

def handler(event, context):
    instance_id = os.environ['INSTANCE_ID']
    ec2.start_instances(InstanceIds=[instance_id])
    return {'statusCode': 200, 'body': f'Started {instance_id}'}
