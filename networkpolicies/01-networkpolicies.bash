# First let us deploy a helm chart

helm install stable/wordpress

# Complete the missing information in yaml/example_policy.yaml and then deploy it

kubectl create -f yaml/example_policy.yaml

# Let's check now

kubectl run -ti mysqlclient --image=bitnami/mariadb -- sh

# Use kubectl exec to find the client

kubectl exec -ti <PODNAME> bash

# Run the mysql client

mysql -uroot -h<MYSQL_SERVICE>

# Check if it works
