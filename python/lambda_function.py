import boto3


def lambda_handler(event, context):
    ecs_client = boto3.client('ecs')
    cluster = 'my-ecs-cluster'
    service = 'my-ecs-service'
    desired_count = 1  # Number of tasks to run in the service

    response = ecs_client.update_service(
        cluster=cluster,
        service=service,
        desiredCount=desired_count,
        forceNewDeployment=True,
    )

    return {
        'statusCode': 200,
        'body': 'ECS service update triggered successfully'
    }
