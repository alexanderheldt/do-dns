#!/bin/bash

if [ -z $DO_TOKEN ]; then
  echo 'Error: environment variable $DO_TOKEN is required'
  exit 1
fi

if [ -z $DO_DOMAIN ]; then
  echo 'Error: environment variable $DO_DOMAIN is required'
  exit 1
fi

if [ -z $DO_SUBDOMAINS ]; then
  echo 'Error: environment variable $DO_SUBDOMAINS is required'
  exit 1
fi

if ! [ -x "$(command -v curl)" ]; then
  echo 'Error: curl is required to run do-dns' >&2
  exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is required to run do-dns' >&2
  exit 1
fi

getExternalIP() {
  ip=$(curl -fs https://api.ipify.org)
  [ -z ${ip?} ] && return 1

  echo $ip
}

getDomainRecord() {
  token=$1
  domain=$2
  subdomain=$3

  response=$(curl -fs \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    "https://api.digitalocean.com/v2/domains/$domain/records?type=A&name=$subdomain.$domain")

  [ -z "${response?}" ] && return 1

  echo $response | jq .domain_records[0]
}

updateDomainRecord() {
  token=$1
  domain=$2
  subdomain=$3
  record_id=$4
  external_ip=$5

  data=$(jq -n \
    --arg name "$subdomain" \
    --arg data "$external_ip" \
    '{type: "A", name: $name, data: $data}')

  response=$(curl -s \
    -X PUT \
    -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $token" \
    -d "$data" \
    "https://api.digitalocean.com/v2/domains/$domain/records/$record_id")

  [[ ! $response -eq 200 ]] && return 1

  return 0
}

external_ip=$(getExternalIP)
[ $? -eq 1 ] && echo 'Could not get external IP' && exit 1

IFS=':' read -ra subdomains <<< "$DO_SUBDOMAINS"
for sd in "${subdomains[@]}"
do
  r=$(getDomainRecord $DO_TOKEN $DO_DOMAIN $sd)
  [ $? -eq 1 ] && echo "Failed to get record for $sd.$DO_DOMAIN" && continue

  if [[ $r = null ]]; then
    echo "No record exist for $sd.$DO_DOMAIN, create one before trying to keep it up to date."
    continue
  fi

  record_ip=$(echo $r | jq -r .data)

  if [ $record_ip = $external_ip ]; then
    echo "Skipping update of $sd.$DO_DOMAIN, ip is the same."
    continue
  fi

  record_id=$(echo $r | jq .id)

  updateDomainRecord $DO_TOKEN $DO_DOMAIN $sd $record_id $external_ip \
    && echo "Updated record for $sd.$DO_DOMAIN" \
    || echo "Failed to update record for $sd.$DO_DOMAIN"
done
