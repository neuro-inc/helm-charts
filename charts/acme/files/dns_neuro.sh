#!/usr/bin/env bash

#
#NEURO_URL="https://staging.neu.ro"
#NEURO_CLUSTER="cluster"
#NEURO_TOKEN="token"
#

##################### Public functions #####################

#Usage: dns_neuro_add _acme-challenge.www.domain.com "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_neuro_add() {
  fulldomain=${1%%.}
  txtvalue=$2

  NEURO_URL="${NEURO_URL:-$(_readaccountconf_mutable NEURO_URL)}"
  if [ -z "$NEURO_URL" ]; then
    NEURO_URL=""
    _err "You haven't specified neuro url yet."
    return 1
  fi
  _saveaccountconf_mutable NEURO_URL "$NEURO_URL"

  NEURO_CLUSTER="${NEURO_CLUSTER:-$(_readaccountconf_mutable NEURO_CLUSTER)}"
  if [ -z "$NEURO_CLUSTER" ]; then
    NEURO_CLUSTER=""
    _err "You haven't specified neuro cluster yet."
    return 1
  fi
  _saveaccountconf_mutable NEURO_CLUSTER "$NEURO_CLUSTER"

  NEURO_TOKEN="${NEURO_TOKEN:-$(_readaccountconf_mutable NEURO_TOKEN)}"
  if [ -z "$NEURO_TOKEN" ]; then
    NEURO_TOKEN=""
    _err "You haven't specified neuro api token yet."
    return 1
  fi
  _saveaccountconf_mutable NEURO_TOKEN "$NEURO_TOKEN"

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "Invalid domain."
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _info "Adding record"
  if ! _neuro_rest PUT "/api/v1/clusters/$NEURO_CLUSTER/dns/acme_challenge" "{\"dns_name\": \"$fulldomain.\", \"value\": \"$txtvalue\"}"; then
    _err "Add record error."
    return 1
  fi
  _info "Added, OK"
  return 0
}

#Usage: dns_neuro_rm _acme-challenge.www.domain.com "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_neuro_rm() {
  fulldomain=${1%%.}
  txtvalue=$2

  NEURO_CLUSTER="${NEURO_CLUSTER:-$(_readaccountconf_mutable NEURO_CLUSTER)}"
  if [ -z "$NEURO_CLUSTER" ]; then
    NEURO_CLUSTER=""
    _err "You haven't specified neuro cluster yet."
    return 1
  fi

  NEURO_TOKEN="${NEURO_TOKEN:-$(_readaccountconf_mutable NEURO_TOKEN)}"
  if [ -z "$NEURO_TOKEN" ]; then
    NEURO_TOKEN=""
    _err "You haven't specified neuro api token yet."
    return 1
  fi

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "Invalid domain."
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  if ! _neuro_rest DELETE "/api/v1/clusters/$NEURO_CLUSTER/dns/acme_challenge" "{\"dns_name\": \"$fulldomain.\", \"value\": \"$txtvalue\"}"; then
    _err "Delete record error."
    return 1
  fi
  return 0
}

##################### Private functions #####################

#_acme-challenge.www.domain.com
#returns
# _sub_domain=_acme-challenge.www
# _domain=domain.com
_get_root() {
  domain=$1

  if ! _neuro_rest GET "/api/v1/clusters/$NEURO_CLUSTER?include=config"; then
    _err error "$path"
    return 1
  fi
  _debug2 response "$response"

  i=2
  p=1
  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)
    _debug h "$h"
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    if _contains "$response" "\"name\": \"$h\""; then
      _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
      _domain=$h
      return 0
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1
}

_neuro_rest() {
  method="$1"
  path="$2"
  data="$3"
  _debug "$path"

  export _H1="Authorization: Bearer $NEURO_TOKEN"
  export _H2="Content-Type: application/json"

  if [ "$method" != "GET" ]; then
    _debug data "$data"
    response="$(_post "$data" "$NEURO_URL$path" "" "$method")"
  else
    response="$(_get "$NEURO_URL$path")"
  fi

  if [ "$?" != "0" ]; then
    _err error "$path"
    return 1
  fi
  if _contains "$response" "\"error\"" ]; then
    _err error "$path"
    return 1
  fi
  _debug2 response "$response"
  return 0
}
