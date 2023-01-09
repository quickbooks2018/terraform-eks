# cloudgeeks.ca

##### https://www.youtube.com/c/AWSLinuxWindows

- RDS Client
```RDS
kubectl run -it --rm --image=mysql:5.7 --restart=Never mysql-client -- mysql -h mydb.cpf3cewlmrdk.us-east-1.rds.amazonaws.com -u dbadmin -p12345678
```
- Create Deployment
```kubectl
kubectl create deployment <Deplyment-Name> --image=<Container-Image>
kubectl create deployment first-deployment --image=quickbooks2018/blue:latest
``` 
 - Scale Deployment
```kubectl
kubectl scale --replicas=20 deployment/<Deployment-Name>
kubectl scale --replicas=20 deployment/first-deployment 
```

- Application Load Balancer Ingress
```Application Load Balancer Ingress
#!/bin/bash
# Purpose: alb ingress setup via helm3
# https://aws.amazon.com/premiumsupport/knowledge-center/eks-alb-ingress-controller-fargate/
# https://github.com/aws/eks-charts
# https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller

EKS_CLUSTER="cloudgeeks-eks-dev"
REGION="us-east-1"
MY_AWS_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
ROLE_NAME="iam-eks-workers-role"

AWS_ACCOUNT_ID="602401143452"
# https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html

# Download IAM Policy
## Download latest & attach this to NodeIAM
curl -o iam_policy_latest.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

## Download specific version
#curl -o iam_policy_v2.3.1.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.3.1/docs/install/iam_policy.json

# Create a policy
aws iam create-policy --policy-name ALBLoadBalancerController --policy-document file://iam_policy_latest.json

# Policy attachment to a role
aws iam attach-role-policy --policy-arn arn:aws:iam::${MY_AWS_ACCOUNT}:policy/ALBLoadBalancerController --role-name $ROLE_NAME


helm version --short

helm repo add eks https://aws.github.io/eks-charts

# To install the TargetGroupBinding custom resource definitions (CRDs), run the following command:

helm repo update
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"


# To install the Helm chart, run the following command:
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system  --set region=${REGION} --set image.repository=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/amazon/aws-load-balancer-controller --set clusterName=${EKS_CLUSTER} --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller



# END
```
### Backend ###
##### S3


##### Create S3 Bucket with Versioning enabled

```console

aws s3api create-bucket --bucket cloudgeeks-dev --region us-east-1

aws s3api put-bucket-versioning --bucket cloudgeeks-dev --versioning-configuration Status=Enabled

```

##### Key Pair

```console
if [ -d /root/.ssh ]
then
echo "/root/.ssh exists"
else
mkdir -p /root/.ssh
fi

if [ -f /root/.ssh/*.pem ]
then
echo "pem is there, I am removing it"
rm -f ~/.ssh/*.pem
export SSH_KEY_NAME="terraform-cloudgeeks"
aws ec2 create-key-pair --key-name "${SSH_KEY_NAME}" --query 'KeyMaterial' --output text > ~/.ssh/${SSH_KEY_NAME}.pem
else
echo "All is well, now I am creating fresh PEM"
export SSH_KEY_NAME="terraform-cloudgeeks"
aws ec2 create-key-pair --key-name "${SSH_KEY_NAME}" --query 'KeyMaterial' --output text > ~/.ssh/${SSH_KEY_NAME}.pem
fi
```

##### KubeConfig
```console
if [ -d /root/.kube ]
then
echo "/root.kube directory exists"
else
mkdir /root/.kube && touch /root/.kube/config
fi
```

##### Source

```console
source EKS.env

```

##### Karpenter Logs
```console
kubectl logs -f -n karpenter $(kubectl get pods -n karpenter -l karpenter=controller -o name)
```

##### Metrics Server Installation
```console
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

##### Metrics-server
```console
kubectl get deployment metrics-server -n kube-system

kubectl get pods -n kube-system -l k8s-app=metrics-server
```

##### Load Testing

1. To create a php-apache deployment, run the following command:
```console
kubectl create deployment php-apache --image=k8s.gcr.io/hpa-example
```

2.    To set the CPU requests, run the following command:
```console
kubectl patch deployment php-apache -p='{"spec":{"template":{"spec":{"containers":[{"name":"hpa-example","resources":{"requests":{"cpu":"200m"}}}]}}}}'
```

3.    To expose the deployment as a service, run the following command:
```console
kubectl create service clusterip php-apache --tcp=80
```

4.    To create an HPA, run the following command:
```console
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

5.    To confirm that the HPA was created, run the following command:
```console
kubectl get hpa

 kubectl describe hpa
```

6.    To test a load on the pod in the namespace that you used in step 1, run the following:
```console
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

7.     Script:
```console
while sleep 0.01; do wget -q -O- http://php-apache; done
```

8.    To see how the HPA scales the pod based on CPU utilization metrics, run the following command (preferably from another terminal window)
```console
kubectl get hpa -w
```

9. To clean up the resources used for testing the HPA, run the following commands:
```console
kubectl delete hpa,service,deployment php-apache
kubectl delete pod load-generator
```

- kubectl top
```console
kubectl top --help

kubectl top node

kubectl top pod -A

kubectl top pod --containers -A
```

