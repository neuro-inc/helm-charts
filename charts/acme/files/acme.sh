#!/usr/bin/env bash

set -o errexit
set -o pipefail

export PATH="$PATH:$HOME/.acme.sh"

_cmd=$1
_email=""
_dns=""
_server="letsencrypt" # letsencrypt_test
_domains=()
_domain_options=""
_debug_option=""
_notify_hook=""
_force_option=""
_secret=()
_secret_namespace="default"
_rollout_deployment=""
_rollout_deployment_namespace="default"

_acme_install() {
  curl https://get.acme.sh | sh -s email="$_email"

  cp /root/acme/dns_neuro.sh $HOME/.acme.sh/
  cp /root/acme/neuro.sh $HOME/.acme.sh/
}

_acme_issue() {
  if [ ${#_domains[@]} == 0 ]; then
    echo "Domain is required."
    exit 1
  fi
  if [ -z "$_secret" ]; then
    echo "Secret is required."
    exit 1
  fi

  local _script="$(realpath -s "$0")"

  if [ ! -z "$_notify_hook" ]; then
    acme.sh --set-notify --notify-hook "$_notify_hook"
  fi

  _renew_hook="$_script install-cert $_debug_option -d ${_domains[0]}"

  if [ ! -z "$_secret" ]; then
    _renew_hook="$_renew_hook --secret $_secret --secret-namespace $_secret_namespace"
  fi

  if [ ! -z "$_rollout_deployment" ]; then
    _renew_hook="$_renew_hook --rollout-deployment $_rollout_deployment --rollout-deployment-namespace $_rollout_deployment_namespace"
  fi

  acme.sh --issue \
    --dns dns_$_dns \
    --server $_server \
    --renew-hook "$_renew_hook" \
    $_debug_option \
    $_force_option \
    $_domain_options \
    || true

  $_script install-cert \
    $_debug_option \
    -d "${_domains[0]}" \
    --secret "$_secret" \
    --secret-namespace "$_secret_namespace" \
    --rollout-deployment "$_rollout_deployment" \
    --rollout-deployment-namespace "$_rollout_deployment_namespace"
}

_acme_install_cert() {
  if [ ${#_domains[@]} == 0 ]; then
    echo "Domain is required."
    exit 1
  fi

  local _path="$HOME/certs"

  mkdir -p $_path

  acme.sh --install-cert \
    $_debug_option \
    $_domain_options \
    --cert-file $_path/cert.pem \
    --fullchain-file $_path/fullchain.pem \
    --key-file $_path/key.pem

  if [ ! -z "$_secret" ]; then
    kubectl create secret generic $_secret \
      -n $_secret_namespace \
      --from-file=cert.crt=$_path/fullchain.pem \
      --from-file=cert.key=$_path/key.pem \
      --save-config \
      --dry-run \
      -o yaml \
      2>/dev/null | \
    kubectl apply -f -
  fi

  if [ ! -z "$_rollout_deployment" ]; then
    kubectl rollout restart deployment/$_rollout_deployment -n $_rollout_deployment_namespace
  fi
}

shift # past cmd

while [[ $# -gt 0 ]]; do
  case $1 in
    --email)
      _email="$2"
      shift # past argument
      shift # past value
      ;;
    --dns)
      _dns="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--server)
      _server="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--domain)
      _domains=(${_domains[@]} "$2")
      _domain_options="$_domain_options -d $2"
      shift # past argument
      shift # past value
      ;;
    --debug)
      _debug_option="--debug $2"
      shift # past argument
      shift # past value
      ;;
    --notify-hook)
      _notify_hook="$2"
      shift # past argument
      shift # past value
      ;;
    --force)
      _force_option="--force"
      shift # past argument
      ;;
    --secret)
      _secret="$2"
      shift # past argument
      shift # past value
      ;;
    --secret-namespace)
      _secret_namespace="$2"
      shift # past argument
      shift # past value
      ;;
    --rollout-deployment)
      _rollout_deployment="$2"
      shift # past argument
      shift # past value
      ;;
    --rollout-deployment-namespace)
      _rollout_deployment_namespace="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [ "$_cmd" == "install" ]; then
  _acme_install
elif [ "$_cmd" == "issue" ]; then
  _acme_issue
elif [ "$_cmd" == "install-cert" ]; then
  _acme_install_cert
else
  echo "Invalid command."
  exit 1
fi
