## Manage Bind Zone Files via Ansible

**Method:**

1. Use a customized module `myfacts` to get the serial number
2. Use a shell script `dns_ops.sh` to add|delete DNS records
3. Use YAML vars files to store the DNS records
4. Use templates files to get DNS records then update the zone files
 
### Here is the script `dns_ops.sh`:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh
Examples:
roles/bind/vars/dns_ops.sh -t A -u add -n ns1 -v 172.16.8.246
roles/bind/vars/dns_ops.sh -t A -u del -n ns1 -v 172.16.8.246
roles/bind/vars/dns_ops.sh -t CNAME -u add -n ns3 -v ns1.heylinux.com
roles/bind/vars/dns_ops.sh -t CNAME -u del -n ns3 -v ns1.heylinux.com
roles/bind/vars/dns_ops.sh -t PTR -u add -n 172.16.8.246 -v ns1.heylinux.com
roles/bind/vars/dns_ops.sh -t PTR -u del -n 172.16.8.246 -v ns1.heylinux.com
```

### Here are some practices:
#### Check if the name contain the top level domain:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t A -u add -n ns6.heylinux.com -v 172.16.8.251
'ns6.heylinux.com' is malformed. Servername should be just 'ns6' without the 'heylinux.com'
```

#### Check the duplicate record:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t A -u add -n ns6 -v 172.16.8.251
Failed because duplicate record: 'ns6: 172.16.8.253'
```

#### Check if the value doesnt match:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t A -u del -n ns6 -v 172.16.8.251
Failed because the existing record's value doesnt match: 'ns6: 172.16.8.253'
```

#### Delete a record:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t A -u del -n ns6 -v 172.16.8.253
Updated A records in A.yml: delete 'ns6: 172.16.8.253'
You may need to push via Ansible to update the records on DNS Servers
```

#### Add a record:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t A -u add -n ns6 -v 172.16.8.251
Updated A records in A.yml: add 'ns6: 172.16.8.251'
You may need to push via Ansible to update the records on DNS Servers
```

#### View the YAML data file which just updated by the script dns_ops.sh:
```
[dong@idc2-admin1 ansible]$ cat roles/bind/vars/A.yml
---
A:
  ns1: 172.16.8.246
  ns2: 172.16.8.247
  ns4: 172.16.8.249
  ns6: 172.16.8.251

[dong@idc2-admin1 ansible]$ cat roles/bind/vars/CNAME.yml
---
CNAME:
  www: heylinux.com
  mail: exmail.qq.com
  ns3: ns1.heylinux.com
```

#### Add a CNAME record:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t CNAME -u add -n ns7 -v ns6.heylinux.com
Updated CNAME records in CNAME.yml: add 'ns7: ns6.heylinux.com'
You may need to push via Ansible to update the records on DNS Servers
```

#### View the YAML data file which just updated by the script dns_ops.sh:
```
[dong@idc2-admin1 ansible]$ cat roles/bind/vars/CNAME.yml
---
CNAME:
  www: heylinux.com
  mail: exmail.qq.com
  ns3: ns1.heylinux.com
  ns7: ns6.heylinux.com
```

#### Checks if give wrong IP address or the sub network doesnt exist:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t PTR -u add -n 172.168.8.251 -v ns6.heylinux.com
8.168.172.in-addr.arpa.yml does not exist
```

#### Add a PTR record:
```
[dong@idc2-admin1 ansible]$ roles/bind/vars/dns_ops.sh -t PTR -u add -n 172.16.8.251 -v ns6.heylinux.com
Updated PTR records in 8.16.172.in-addr.arpa.yml: add '251: ns6.heylinux.com'
You may need to push via Ansible to update the records on DNS Servers
```

#### View the YAML data file which just updated by the script dns_ops.sh:
```
[dong@idc2-admin1 ansible]$ cat roles/bind/vars/8.16.172.in-addr.arpa.yml
---
ptr_8_16_172:
  247: ns2.heylinux.com
  249: ns4.heylinux.com
  246: ns1.heylinux.com
  251: ns6.heylinux.com
```

### Then we can `Push the New Records` to DNS masters:
```
[dong@idc2-admin1 ansible]$ ansroot idc2-bind-master.yml -i hosts.idc2 --tags bind-update
PLAY [bind-master] ************************************************************

GATHERING FACTS ***************************************************************
ok: [idc2-dong1]

TASK: [bind | get zones and A,CNAME records] **********************************
ok: [idc2-dong1] => (item=roles/bind/vars/zones_all.yml)
ok: [idc2-dong1] => (item=roles/bind/vars/zones_std.yml)
ok: [idc2-dong1] => (item=roles/bind/vars/zones_rvs.yml)
ok: [idc2-dong1] => (item=roles/bind/vars/A.yml)
ok: [idc2-dong1] => (item=roles/bind/vars/CNAME.yml)

TASK: [bind | get PTR records] ************************************************
ok: [idc2-dong1] => (item={'domain': '8.16.172.in-addr.arpa', 'file': '8.16.172.in-addr.arpa.zone'})

TASK: [bind | get ansible_dns_new_serial_number of all zones] *****************
ok: [idc2-dong1]

TASK: [bind | create zones configuration files] *******************************
changed: [idc2-dong1] => (item={'domain': 'heylinux.com', 'file': 'heylinux.com.zone'})

TASK: [bind | create reverse zones configuration files] ***********************
changed: [idc2-dong1] => (item={'domain': '8.16.172.in-addr.arpa', 'file': '8.16.172.in-addr.arpa.zone'})

TASK: [bind | relaod rndc service to load new records] ************************
changed: [idc2-dong1]

PLAY RECAP ********************************************************************
idc2-dong1                 : ok=7    changed=3    unreachable=0    failed=0
```

### Check if the Records Updated on DNS masters:
```
[root@idc2-dong1 named]# host ns6
ns6.heylinux.com has address 172.16.8.251

[root@idc2-dong1 named]# host ns7
ns7.heylinux.com is an alias for ns6.heylinux.com.
ns6.heylinux.com has address 172.16.8.251

[root@idc2-dong1 named]# dig -x 172.16.8.251

; <<>> DiG 9.8.2rc1-RedHat-9.8.2-0.23.rc1.el6_5.1 <<>> -x 172.16.8.251
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 33894
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 1

;; QUESTION SECTION:
;251.8.16.172.in-addr.arpa.     IN      PTR

;; ANSWER SECTION:
251.8.16.172.in-addr.arpa. 86400 IN     PTR     ns6.heylinux.com.8.16.172.in-addr.arpa.

;; AUTHORITY SECTION:
8.16.172.in-addr.arpa.  86400   IN      NS      ns1.heylinux.com.

;; ADDITIONAL SECTION:
ns1.heylinux.com.       86400   IN      A       172.16.8.246

;; Query time: 1 msec
;; SERVER: 172.16.8.246#53(172.16.8.246)
;; WHEN: Fri Sep 26 03:57:40 2014
;; MSG SIZE  rcvd: 120
```
