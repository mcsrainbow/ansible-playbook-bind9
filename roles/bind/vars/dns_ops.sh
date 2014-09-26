#!/bin/bash

# DNS records management tool for YAML Files in Ansible
# By Dong Guo at 20140926

basedir=$(dirname ${0})
domain=heylinux.com

function print_help(){
  echo "Usage: ${0} -t A|CNAME|PTR -u add|del -n servername -v record_value"
  echo "Examples:"
  echo "${0} -t A -u add -n ns1 -v 172.16.8.246"
  echo "${0} -t A -u del -n ns1 -v 172.16.8.246"
  echo "${0} -t CNAME -u add -n ns3 -v ns1.heylinux.com"
  echo "${0} -t CNAME -u del -n ns3 -v ns1.heylinux.com"
  echo "${0} -t PTR -u add -n 172.16.8.246 -v ns1.heylinux.com"
  echo "${0} -t PTR -u del -n 172.16.8.246 -v ns1.heylinux.com"
  exit 1
}

function check_servername(){
  echo $servername | grep -wq ${domain}
  if [ $? -eq 0 ]; then
    hostname=$(echo $servername | cut -d. -f1)
    echo "'${servername}' is malformed. Servername should be just '${hostname}' without the '${domain}'"
    exit 1
  fi 
}

function check_fqdn(){
  echo $record_value | grep -q '\.'
  if [ $? -ne 0 ]; then
    echo "'${record_value}' is malformed. Should be a FQDN"
    exit 1
  fi 
}

function update_record(){
  if [ ${record_type} == "PTR" ]; then
    filename=$domain
  else
    filename=$record_type
  fi
  if [ $action == "add" ]; then
    grep -wq "$servername:" ${basedir}/${filename}.yml
    if [ $? -eq 0 ]; then
      echo "Failed because duplicate record: '$(grep -w "$servername:" ${basedir}/${filename}.yml|awk '{print $1" "$2}')'"
      exit 1
    else
      echo "  $servername: $record_value" >> ${basedir}/${filename}.yml
    fi
  fi
  if [ $action == "delete" ]; then
    grep -wq "$servername:" ${basedir}/${filename}.yml
    if [ $? -ne 0 ]; then
      echo "Failed because nonexistent record"
      exit 1
    else
      grep -w "$servername:" ${basedir}/${filename}.yml | grep -wq "${record_value}"
      if [ $? -ne 0 ]; then
        echo "Failed because the existing record's value doesnt match: '$(grep -w "$servername:" ${basedir}/${filename}.yml|awk '{print $1" "$2}')'"
        exit 1
      else
        sed -i /"${servername}: ${record_value}"/d ${basedir}/${filename}.yml
      fi
    fi
  fi
  echo "Updated ${record_type} records in ${filename}.yml: $action '$servername: $record_value'"
  echo "You may need to push via Ansible to update the records on DNS Servers"
}

while getopts "t:u:n:v:" opts
do
  case "$opts" in
    "t")
      record_type=$OPTARG
      ;;
    "u")
      action=$OPTARG
      ;;
    "n")
      servername=$OPTARG
      ;;
    "v")
      record_value=$OPTARG
      ;;
    *)
      print_help
      ;;
  esac
done

if [ -z "$record_type" ] || [ -z "$action" ] || [ -z "$servername" ] || [ -z "$record_value" ]; then
  print_help
else
  case "$action" in 
    "add")
      action=add
      ;;
    "del")
      action=delete
      ;;
    *)
      print_help
      ;;  
  esac
  case "$record_type" in 
    "A")
      check_servername
      update_record
      ;;
    "CNAME")
      check_servername
      check_fqdn
      update_record
      ;;
    "PTR")
      check_fqdn
      a=$(echo $servername |cut -d. -f1 |grep -Ev '[a-z]|[A-Z]')
      b=$(echo $servername |cut -d. -f2 |grep -Ev '[a-z]|[A-Z]')
      c=$(echo $servername |cut -d. -f3 |grep -Ev '[a-z]|[A-Z]')
      d=$(echo $servername |cut -d. -f4 |grep -Ev '[a-z]|[A-Z]')
      if [ -z "$a" ] || [ -z "$b" ] || [ -z "$c" ] || [ -z "$d" ]; then
        echo "'${servername}' is malformed. Should be a IP address"
      else
        domain=$c.$b.$a.in-addr.arpa
        servername=$d
        if [ ! -f ${basedir}/${domain}.yml ]; then
          echo ${domain}.yml does not exist
          exit 1 
        else
          update_record
        fi
      fi
      ;;
    *)
      print_help
      ;;  
  esac 
fi
