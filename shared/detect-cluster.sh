#!/bin/bash
# Prints one of: kind | rancher-desktop | docker-desktop | minikube | unknown
CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null || echo "")
case "$CONTEXT$CLUSTER" in
    *kind*)            echo "kind" ;;
    *rancher-desktop*) echo "rancher-desktop" ;;
    *docker-desktop*)  echo "docker-desktop" ;;
    *minikube*)        echo "minikube" ;;
    *)                 echo "unknown" ;;
esac
