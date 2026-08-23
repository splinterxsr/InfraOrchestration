#!/bin/bash
echo "=== Configurando AWS Services no LocalStack ==="

QUEUE_URL=$(awslocal sqs create-queue --queue-name user-created-queue --query 'QueueUrl' --output text)
QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

TOPIC_ARN=$(awslocal sns create-topic --name UserCreatedEvent --query 'TopicArn' --output text)

awslocal sns subscribe --topic-arn $TOPIC_ARN --protocol sqs --notification-endpoint $QUEUE_ARN

awslocal lambda create-function \
    --function-name NotificationsAPI \
    --runtime dotnet8 \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --handler Notifications.Lambda::Notifications.Lambda.Adapters.Inbound.UserLambdaHandler::FunctionHandler \
    --zip-file fileb:///opt/code/localstack/lambda.zip

awslocal lambda create-event-source-mapping \
    --function-name NotificationsAPI \
    --event-source-arn $QUEUE_ARN \
    --batch-size 5

echo "=== Setup do LocalStack finalizado com sucesso! ==="