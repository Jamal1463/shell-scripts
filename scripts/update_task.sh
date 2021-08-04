#!/bin/bash

NEW_IMAGE_VERSION = $1
params.ENVIRONMENT_TYPE = $2

IMAGE_REPO_NAME = "$REPO_NAME"
TASK_FAMILY = "$TASK_NAME"
if [ $params.ENVIRONMENT_TYPE == 'BLUE' ]; then
        echo "Setting vars for blue env type"
        ECS_CLUSTER_NAME = "$CLUSTER_NAME_BLUE"
        AWS_ECR_ARN = "$ECR_ARN_BLUE"
        AWS_DEFAULT_REGION = "$DEFAULT_REGION_BLUE"
        ECS_SERVICE_NAME = "$SERVICE_NAME_BLUE"
        SUBNET1 = "$SUBNET1_BLUE"
        SUBNET2 = "$SUBNET2_BLUE"
        SGROUP = "$SGROUP_BLUE"
        TG_ARN = "$TG_ARN_BLUE"
        LB_NAME = "$LB_NAME_BLUE"
        CONTAINER_NAME = "$CONTAINER_NAME_BLUE"
        CONTAINER_PORT = "$CONTAINER_PORT_BLUE"
 else 
        echo "Setting vars for GREEN env type"
        ECS_CLUSTER_NAME = "$CLUSTER_NAME_GREEN"
        AWS_ECR_ARN = "$ECR_ARN_GREEN"
        AWS_DEFAULT_REGION = "$DEFAULT_REGION_GREEN"
        ECS_SERVICE_NAME = "$SERVICE_NAME_GREEN"
        SUBNET1 = "$SUBNET1_GREEN"
        SUBNET2 = "$SUBNET2_GREEN"
        SGROUP = "$SGROUP_GREEN"
        TG_ARN = "$TG_ARN_GREEN"
        LB_NAME = "$LB_NAME_GREEN"
        CONTAINER_NAME = "$CONTAINER_NAME_GREEN"
        CONTAINER_PORT = "$CONTAINER_PORT_GREEN"
fi

echo "Cluster Name: ${ECS_CLUSTER_NAME}, Service Name: ${ECS_SERVICE_NAME}, image repo name: ${IMAGE_REPO_NAME}, task family: ${TASK_FAMILY}, project_arn: ${AWS_ECR_ARN}, region: ${AWS_DEFAULT_REGION}, New Image Version: ${NEW_IMAGE_VERSION}, Dep Env type: ${params.ENVIRONMENT_TYPE}"
NEW_IMAGE = "${AWS_ECR_ARN}/${IMAGE_REPO_NAME}:${NEW_IMAGE_VERSION}"
TASK_DEFINITION = $(aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$AWS_DEFAULT_REGION" --output "json")
NEW_TASK_DEFINITION = $(echo $TASK_DEFINITION | jq --arg IMAGE "$NEW_IMAGE", '.taskDefinition | .containerDefinition[0].image = $IMAGE | del(.revision) | del(.status) | del(.requiresAttributes) | del(.compatabilities) | del(.registeredAt) | del(.registeredBy)')

#Registering the new task definition
NEW_TASK_INFO=$(aws ecs register-task-definition --region "$AWS_DEFAULT_REGION" --cli-input-json "$NEW_TASK_DEFINITION" --output "json")
NEW_TASK_REVISION=$(echo $NEW_TASK_INFO | jq '.taskDefinition.revision')

echo "SUBNET1: ${SUBNET1}, SUBNET2: ${SUBNET2}, SGROUP: ${SGROUP}, TG_ARN: ${TG_ARN}, LB_NAME: ${LB_NAME}, CONTAINER_NAME: ${CONTAINER_NAME}, CONTAINER_PORT: ${CONTAINER_PORT} "
echo "Checking if the service already created"

aws ecs list-services --cluster ${ECS_CLUSTER_NAME} --output "json" --region ${AWS_DEFAULT_REGION} | grep "${ECS_CLUSTER_NAM}/${ECS_SERVICE_NAME}"
retVal=$?

if [ $retVal -eq 1 ]
then
	#if the list services failed to find the service, then create the service
	echo "creating the service, retVal: ${retVal}"
	aws ecs create-service --cluster ${ECS_CLUSTER_NAME} \
		--service-name ${ECS_SERVICE_NAME} \
		--task-definition ${TASK_FAMILY}:${NEW_TASK_REVISION} \
			--desired-count 1 \
			--launch-type FARGATE \
			--network-configuration "awsvpcConfiguration={subnets=[${SUBNET1},${SUBNET2}],securityGroups=[${SGROUP}],assignPublicIp=DISABLED}" \
			--tags key=author,value=JenkinsTemp \
	        --output "json" \
		--load-balancers "targetGroupArn=${TG_ARN},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}"
 
 if [ $? -eq 0 ]
 then
 	echo "Sucess created service ${ECS_SERVICE_NAME} in cluster ${ECS_CLUSTER_NAME} with new task definition ${TASK_FAMILY}:${NEW_TASK_REVISION}, targetGroupArn=${TG_ARN}, 
	loadBalancerName=${LB_NAME},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}"
else
	echo "Error: Failed to create service  ${ECS_SERVICE_NAME} in cluster ${ECS_CLUSTER_NAME} with new task definition ${TASK_FAMILY}:${NEW_TASK_REVISION}, targetGroupArn=${TG_ARN}, 
	loadBalancerName=${LB_NAME},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}"
		exit 1
     fi
elif [ $retVal -eq 0 ]
then 
	#if describe service was sucess, then update the service
	echo "Updating the service, retVal: ${retVal}"
	
	aws ecs update-service --cluster ${ECS_CLUSTER_NAME} \
			  	--service  ${ECS_SERVICE_NAME} \
				    --task-definition ${TASK_FAMILY}:${NEW_TASK_REVISION} --force-new-deployment --output "json" > /dev/null
	if [ $? -eq 0 ]
	then
		echo "Sucess: updated service ${ECS_SERVICE_NAME} in cluster ${ECS_CLUSTER_NAME}  with new task definition ${TASK_FAMILY}:${NEW_TASK_REVISION} "
	else
		echo "Failed to create service  ${ECS_SERVICE_NAME} in cluster ${ECS_CLUSTER_NAME} with new task definition ${TASK_FAMILY}:${NEW_TASK_REVISION}"
		exit 1
	fi
	
else
	echo "Error: Failed to do list services, retVal: ${retVal}"
	exit 1
fi

echo "Sucess: Created/updated service  ${ECS_SERVICE_NAME} in cluster ${ECS_CLUSTER_NAME} with new task definition ${TASK_FAMILY}:${NEW_TASK_REVISION}"
echo "Exiting the script"
exit 0
		
		
		
		
		
		
		
		
		
		
		
		
