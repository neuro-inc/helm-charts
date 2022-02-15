#!/usr/bin/env bash

#Support Neuro webhooks

#
#NEURO_URL="https://staging.neu.ro"
#NEURO_CLUSTER=""
#NEURO_TOKEN=""
#

##################### Public functions #####################

neuro_send() {
  _subject="$1"
  _content="$2"
  _statusCode="$3" #0: success, 1: error 2($RENEW_SKIP): skipped
  _debug _subject "$_subject"
  _debug _content "$_content"
  _debug _statusCode "$_statusCode"

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

  if [ "$_statusCode" != 0 ]; then
    _notification_type="error"
  else
    _notification_type="success"
  fi

  _message="$_subject\\n$_content"

  if ! _neuro_rest POST "/api/v1/clusters/$NEURO_CLUSTER/notifications" "{\"notification_type\": \"$_notification_type\", \"message\": \"$_message\"}"; then
    _err "Neuro send error."
    _err "$response"
    return 1
  fi
  _info "Neuro send success."
  return 0
}

##################### Private functions #####################

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
