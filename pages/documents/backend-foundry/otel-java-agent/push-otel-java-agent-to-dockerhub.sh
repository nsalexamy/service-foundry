#!/bin/bash


REPO_NAME="otel-java-agent"
#IMAGE_TAG="0.1.3"
DEFAULT_IMAGE_TAG="2.20.1"



usage() {
  echo ''
  echo ''
  echo "Usage: ${0} [-u dockerhub-username] [-p dockerhub-password] [-t tag]"
  echo ''
  echo 'options'
  echo '  -u : Docker username'
  echo '  -p : Docker password'
  echo '  -t : Tag for the docker image'
  echo '  -h : Display this help message'

  exit 1
}

DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
DOCKERHUB_PASSWORD="${DOCKERHUB_PASSWORD:-}"
IMAGE_TAG="${IMAGE_TAG:-${DEFAULT_IMAGE_TAG}}"

while getopts "hu:p:t:" OPTION
do
  case ${OPTION} in
    u) DOCKERHUB_USERNAME="${OPTARG}" ;;
    p) DOCKERHUB_PASSWORD="${OPTARG}" ;;
    t) IMAGE_TAG="${OPTARG}" ;;
    h) usage ;;
    ?) usage ;;
  esac
done

# This script builds and pushes the Docker image to Docker Hub.

# check if two arguments are passed
#if [ "$#" -ne 2 ]; then
#    echo "Usage: $0 <docker-username> <docker-password>"
#    exit 1
#fi
#
# DOCKERHUB_USERNAME=$1
# DOCKERHUB_PASSWORD=$2

# check all arguments are provided
if [ -z "${DOCKERHUB_USERNAME}" ] || [ -z "${DOCKERHUB_PASSWORD}" ] || [ -z "${IMAGE_TAG}" ]; then
  echo "All arguments are required"
  usage
fi

echo "Using image tag: ${IMAGE_TAG}"

docker login -u $DOCKERHUB_USERNAME -p $DOCKERHUB_PASSWORD

docker buildx build --build-arg OTEL_JAVA_AGENT_VERSION=$IMAGE_TAG --platform linux/amd64 -t $DOCKERHUB_USERNAME/$REPO_NAME:$IMAGE_TAG ./otel-java-agent --push

