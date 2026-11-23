# Занятие 16.11.2026 "36.  DNS - настройка и обслуживание"

Настраиваем split-dns

## Цель:

- Создать домашнюю сетевую лабораторию;

- Изучить основы DNS;

- Научиться работать с технологией Split-DNS в Linux-based системах.

### Описание/Пошаговая инструкция выполнения домашнего задания:

Для выполнения домашнего задания используйте методичку

### Что нужно сделать?

1. взять стенд https://github.com/erlong15/vagrant-bind

- добавить еще один сервер client2

- завести в зоне dns.lab имена:

    - web1 - смотрит на клиент1

    - web2 смотрит на клиент2

- завести еще одну зону newdns.lab

- завести в ней запись

    - www - смотрит на обоих клиентов

2. настроить split-dns

- клиент1 - видит обе зоны, но в зоне dns.lab только web1

- клиент2 видит только dns.lab

Дополнительное задание:

- настроить все без выключения selinux*

Формат сдачи ДЗ - vagrant + ansible

# Решение

### 0. Создание и конфигурирование ВМ ns01, ns02, client, client2 - vagrant + ansible

Общая структура скачаного  лабораторного репозитория приведена ниже:

```
[admin_insta11@mv334 vagrant-bind]$ tree
.
├── provisioning
│   ├── client-motd
│   ├── client-resolv.conf
│   ├── master-named.conf
│   ├── named.ddns.lab
│   ├── named.dns.lab
│   ├── named.dns.lab.rev
│   ├── named.zonetransfer.key
│   ├── playbook.yml
│   ├── rndc.conf
│   ├── servers-resolv.conf
│   ├── slave-named.conf
│   └── zonetransfer.key
├── README.md
└── Vagrantfile

1 directory, 14 files
```

Vagrantfile для создания и конфигурирования четырёх ВМ приведён ниже:

```
[admin_insta11@mv334 vagrant-bind]$ cat Vagrantfile 
# -*- mode: ruby -*-
# vi: set ft=ruby :
BOX_NAME = ENV['VAGRANT_BOX'] || 'centos/7'

Vagrant.configure(2) do |config|
  config.vm.box = BOX_NAME

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end


  config.vm.provider "virtualbox" do |v|
	  v.memory = 1024
  end

  config.vm.define "ns01" do |ns01|
    ns01.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "dns"
    ns01.vm.hostname = "ns01"
  end

  config.vm.define "ns02" do |ns02|
    ns02.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "dns"
    ns02.vm.hostname = "ns02"
  end

  config.vm.define "client" do |client|
    client.vm.network "private_network", ip: "192.168.50.15", virtualbox__intnet: "dns"
    client.vm.hostname = "client"
  end

  config.vm.define "client2" do |client2|
    client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
    client2.vm.hostname = "client2"
  end

end
```

Файл ansible playbook для провизионинга созданных ВМ приведён ниже:

```
[admin_insta11@mv334 vagrant-bind]$ cat provisioning/playbook.yml
---
- hosts: all
  become: yes
  tasks:
  - name: install packages
    yum: name={{ item }} state=latest 
    with_items:
      - bind
      - bind-utils
#      - ntp

  - name: copy transferkey to all servers and the client
    copy: src=named.zonetransfer.key dest=/etc/named.zonetransfer.key owner=root group=named mode=0644

- hosts: ns01
  become: yes
  tasks:
  - name: copy named.conf
    copy: src=master-named.conf dest=/etc/named.conf owner=root group=named mode=0640
  - name: copy zones
    copy: src={{ item }} dest=/etc/named/ owner=root group=named mode=0660
    with_fileglob:
      - named.d*
  - name: copy resolv.conf to the servers
    copy: src=servers-resolv.conf dest=/etc/resolv.conf owner=root group=root mode=0644
  
  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes

- hosts: ns02
  become: yes
  tasks:
  - name: copy named.conf
    copy: src=slave-named.conf dest=/etc/named.conf owner=root group=named mode=0640
  - name: copy resolv.conf to the servers
    copy: src=servers-resolv.conf dest=/etc/resolv.conf owner=root group=root mode=0644

  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes
    
- hosts: client, client2
  become: yes
  tasks:
  - name: copy resolv.conf to the client
    copy: src=client-resolv.conf dest=/etc/resolv.conf owner=root group=root mode=0644
  - name: copy rndc conf file
    copy: src=rndc.conf dest=/home/vagrant/rndc.conf owner=vagrant group=vagrant mode=0644
  - name: copy motd to the client
    copy: src=client-motd dest=/etc/motd owner=root group=root mode=0644
```

После запуска ВМ успешно создаются и конфигурируются:

```
[admin_insta11@mv334 vagrant-bind]$ VAGRANT_BOX=almalinux9-stand-vb vagrant up
Bringing machine 'ns01' up with 'virtualbox' provider...
Bringing machine 'ns02' up with 'virtualbox' provider...
Bringing machine 'client' up with 'virtualbox' provider...
Bringing machine 'client2' up with 'virtualbox' provider...
==> ns01: Importing base box 'almalinux9-stand-vb'...
==> ns01: Matching MAC address for NAT networking...
==> ns01: Setting the name of the VM: vagrant-bind_ns01_1795432988709_46144
==> ns01: Clearing any previously set network interfaces...
==> ns01: Preparing network interfaces based on configuration...
    ns01: Adapter 1: nat
    ns01: Adapter 2: intnet
==> ns01: Forwarding ports...
    ns01: 22 (guest) => 2222 (host) (adapter 1)
==> ns01: Running 'pre-boot' VM customizations...
==> ns01: Booting VM...
==> ns01: Waiting for machine to boot. This may take a few minutes...
    ns01: SSH address: 127.0.0.1:2222
    ns01: SSH username: vagrant
    ns01: SSH auth method: private key
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Remote connection disconnect. Retrying...
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Remote connection disconnect. Retrying...
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Remote connection disconnect. Retrying...
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Remote connection disconnect. Retrying...
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Connection reset. Retrying...
    ns01: Warning: Remote connection disconnect. Retrying...
    ns01: 
    ns01: Vagrant insecure key detected. Vagrant will automatically replace
    ns01: this with a newly generated keypair for better security.
    ns01: 
    ns01: Inserting generated public key within guest...
    ns01: Removing insecure key from the guest if it's present...
    ns01: Key inserted! Disconnecting and reconnecting using new SSH key...
==> ns01: Machine booted and ready!
==> ns01: Checking for guest additions in VM...
    ns01: The guest additions on this VM do not match the installed version of
    ns01: VirtualBox! In most cases this is fine, but in rare cases it can
    ns01: prevent things such as shared folders from working properly. If you see
    ns01: shared folder errors, please make sure the guest additions within the
    ns01: virtual machine match the version of VirtualBox you have installed on
    ns01: your host and reload your VM.
    ns01: 
    ns01: Guest Additions Version: 7.2.16
    ns01: VirtualBox Version: 7.1
==> ns01: Setting hostname...
==> ns01: Configuring and enabling network interfaces...
==> ns01: Mounting shared folders...
    ns01: /home/admin_insta11/vagrant-bind => /vagrant
==> ns01: Running provisioner: ansible...
    ns01: Running ansible-playbook...
PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --connection=ssh --timeout=30 --limit="ns01" --inventory-file=/home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory -vvv provisioning/playbook.yml
ansible-playbook [core 2.13.13]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/admin_insta11/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.8/site-packages/ansible
  ansible collection location = /home/admin_insta11/.ansible/collections:/usr/share/ansible/collections
  executable location = /bin/ansible-playbook
  python version = 3.8.20 (default, Sep  9 2024, 00:00:00) [GCC 11.4.1 20230605 (Red Soft 11.4.0-1)]
  jinja version = 3.1.3
  libyaml = True
Using /etc/ansible/ansible.cfg as config file
host_list declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
script declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
auto declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
Parsed /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory inventory source with ini plugin
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: playbook.yml *********************************************************
4 plays in provisioning/playbook.yml

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:2
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b"Warning: Permanently added '[127.0.0.1]:2222' (ED25519) to the list of known hosts.\r\n")
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655 `" && echo ansible-tmp-1795433106.8089209-372296-255168353550655="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433106.8089209-372296-255168353550655=/home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655\n', b'')
<ns01> Attempting python interpreter discovery
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo PLATFORM; uname; echo FOUND; command -v '"'"'"'"'"'"'"'"'python3.10'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.9'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.8'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.6'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.5'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python3'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/libexec/platform-python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python2.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python'"'"'"'"'"'"'"'"'; echo ENDFOUND && sleep 0'"'"''
<127.0.0.1> (0, b'PLATFORM\nLinux\nFOUND\n/usr/bin/python3.9\n/usr/bin/python3\n/usr/libexec/platform-python\nENDFOUND\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'/usr/bin/python3.9 && sleep 0'"'"''
<127.0.0.1> (0, b'{"platform_dist_result": [], "osrelease_content": "NAME=\\"AlmaLinux\\"\\nVERSION=\\"9.8 (Olive Jaguar)\\"\\nID=\\"almalinux\\"\\nID_LIKE=\\"rhel centos fedora\\"\\nVERSION_ID=\\"9.8\\"\\nPLATFORM_ID=\\"platform:el9\\"\\nPRETTY_NAME=\\"AlmaLinux 9.8 (Olive Jaguar)\\"\\nANSI_COLOR=\\"0;34\\"\\nLOGO=\\"fedora-logo-icon\\"\\nCPE_NAME=\\"cpe:/o:almalinux:almalinux:9::baseos\\"\\nHOME_URL=\\"https://almalinux.org/\\"\\nDOCUMENTATION_URL=\\"https://wiki.almalinux.org/\\"\\nBUG_REPORT_URL=\\"https://bugs.almalinux.org/\\"\\n\\nALMALINUX_MANTISBT_PROJECT=\\"AlmaLinux-9\\"\\nALMALINUX_MANTISBT_PROJECT_VERSION=\\"9.8\\"\\nREDHAT_SUPPORT_PRODUCT=\\"AlmaLinux\\"\\nREDHAT_SUPPORT_PRODUCT_VERSION=\\"9.8\\"\\nSUPPORT_END=2032-06-01\\n"}\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp0i0tqkg2 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp0i0tqkg2 /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-yyzszikiotzxovfaqcwzmcghweximlfn ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"ansible_facts": {"ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDACO/623RUzZcY73bNsfq0ITJ8QOM7DQkVe+Yl6+IfyXfKk37Fcip0hn8EWmtKoBcmmhwtZSsA93fVgT4TRBFZGR7mKTglUPRfMPSqlOjNe7eGtrm+E2I4kAaK8NgC1tQI6EBJDgkeC9GvwAK00AWucWrDsfSxEAODu5QkLZP7wWbFakGudyyzetKJ4MDBoarl+kuDSp3h0Q2v6pOGj0lKFtEpnxL/rhRgaYas60ImXjStqLhMTTvDYzLao1mTgQMKzWafIiY/JXkBgEqSuCcTgLaY/VwHmyW3Gt+n2lxouG7haVPu/IGbA5tp9cYEeOGdwsKcCmLRiVph04ShcFUQi9lj77fLfigniXSD2jBs+C49b80dDxAxF6Od2hCySOT7ZTW/wem7fe8l/w5HqofVozFnzuDXUWVx55N1cXoN1JmYpjC6SQjsmyEcR9UiPgZEe35XWvrdUcXB0jpg6+R4S1LXAhc5uOM5O4Y8EJChXqb2KWASI2MD1r7VJCyzHi0=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEcKKjgPQMJ6zBzNsrTw0iNV4PNZQ22o8goc87g3kImFI7X9pc4E/wSEArz15ZNesRnNVskCCpJ94OGAgoDZd48=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIJG4P4mcAOdm2TLEI5NmaVBnQaE5W4WXkqN2bl+3NGNy", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "ns01", "ansible_hostname": "ns01", "ansible_nodename": "ns01", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "8b84ba6392a3453486f50c9ed82393f9", "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_is_chroot": false, "ansible_service_mgr": "systemd", "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_local": {}, "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 591, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 348, "free": 591}, "nocache": {"free": 717, "used": 222}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-2f0288ea-2b1d-43c6-8986-d3b785b8051f", "ansible_product_uuid": "ea88022f-1d2b-c643-8986-d3b785b8051f", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB2e0bebb1", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2"], "sda3": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3"], "sda4": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4"], "sda1": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1"], "sda": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 109, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18366840832, "block_size": 4096, "block_total": 4789504, "block_available": 4484092, "block_used": 305412, "inode_total": 9611776, "inode_available": 9570688, "inode_used": 41088, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_fips": false, "ansible_iscsi_iqn": "", "ansible_interfaces": ["lo", "eth1", "eth0"], "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:2e:49:4f", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.10", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe2e:494f", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "prefix": "64", "scope": "global"}, {"address": "fe80::7b3b:a9f8:34ed:126a", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.10", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe2e:494f", "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "fe80::7b3b:a9f8:34ed:126a"], "ansible_pkg_mgr": "dnf", "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-yyzszikiotzxovfaqcwzmcghweximlfn ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_apparmor": {"status": "disabled"}, "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "25", "second": "09", "epoch": "1795433109", "epoch_int": "1795433109", "date": "2026-11-23", "time": "11:25:09", "iso8601_micro": "2026-11-23T11:25:09.341744Z", "iso8601": "2026-11-23T11:25:09Z", "iso8601_basic": "20261123T112509341744", "iso8601_basic_short": "20261123T112509", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_fibre_channel_wwn": [], "ansible_lsb": {}, "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433106.8089209-372296-255168353550655/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns01]
META: ran handlers

TASK [install packages] ********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:5
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963 `" && echo ansible-tmp-1795433109.5814784-372341-57875110653963="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433109.5814784-372341-57875110653963=/home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmphgs_br7k TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmphgs_br7k /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-sngebypmorgxgmvpehmasjejzgjllsmu ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "", "changed": true, "results": ["Installed: fstrm-0.6.1-3.el9.x86_64", "Installed: policycoreutils-python-utils-3.6-9.el9.noarch", "Installed: python3-policycoreutils-3.6-9.el9.noarch", "Installed: python3-ply-3.11-14.el9.noarch", "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch", "Installed: policycoreutils-3.6-9.el9.x86_64", "Installed: bind-32:9.16.50-12.el9_9.1.x86_64", "Installed: libmaxminddb-1.5.2-4.el9.x86_64", "Installed: libuv-1:1.42.0-2.el9_4.x86_64", "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64", "Removed: policycoreutils-3.6-5.el9.x86_64", "Removed: python3-policycoreutils-3.6-5.el9.noarch"], "rc": 0, "invocation": {"module_args": {"name": ["bind"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433109.5814784-372341-57875110653963/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => (item=bind) => {
    "ansible_loop_var": "item",
    "changed": true,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind",
    "msg": "",
    "rc": 0,
    "results": [
        "Installed: fstrm-0.6.1-3.el9.x86_64",
        "Installed: policycoreutils-python-utils-3.6-9.el9.noarch",
        "Installed: python3-policycoreutils-3.6-9.el9.noarch",
        "Installed: python3-ply-3.11-14.el9.noarch",
        "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch",
        "Installed: policycoreutils-3.6-9.el9.x86_64",
        "Installed: bind-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: libmaxminddb-1.5.2-4.el9.x86_64",
        "Installed: libuv-1:1.42.0-2.el9_4.x86_64",
        "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Removed: policycoreutils-3.6-5.el9.x86_64",
        "Removed: python3-policycoreutils-3.6-5.el9.noarch"
    ]
}
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195 `" && echo ansible-tmp-1795433156.0160134-372341-104914961182195="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433156.0160134-372341-104914961182195=/home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpk1omsgmz TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpk1omsgmz /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-byakkshogvlkfgkvsurzwkpahxcfmlqb ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"msg": "Nothing to do", "changed": false, "results": [], "rc": 0, "invocation": {"module_args": {"name": ["bind-utils"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433156.0160134-372341-104914961182195/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns01] => (item=bind-utils) => {
    "ansible_loop_var": "item",
    "changed": false,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind-utils"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind-utils",
    "msg": "Nothing to do",
    "rc": 0,
    "results": []
}

TASK [copy transferkey to all servers and the client] **************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:12
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690 `" && echo ansible-tmp-1795433158.2634811-372400-94152057468690="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433158.2634811-372400-94152057468690=/home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpvw1wpgaq TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpvw1wpgaq /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-disxdmcxbeokbirjcttnsagqqxbrpwhu ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named.zonetransfer.key", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpetfj9cru TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpetfj9cru /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-byeebblqbnzezgwedwhkocolnvyyzcth ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"dest": "/etc/named.zonetransfer.key", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source", "md5sum": "15ccf7d7d6ea11384de2901045af4d02", "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 91, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source", "dest": "/etc/named.zonetransfer.key", "owner": "root", "group": "named", "mode": "0644", "_original_basename": "named.zonetransfer.key", "follow": false, "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => {
    "changed": true,
    "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
    "dest": "/etc/named.zonetransfer.key",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.zonetransfer.key",
            "attributes": null,
            "backup": false,
            "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
            "content": null,
            "dest": "/etc/named.zonetransfer.key",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "15ccf7d7d6ea11384de2901045af4d02",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 91,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433158.2634811-372400-94152057468690/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY [ns01] ********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:15
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996 `" && echo ansible-tmp-1795433160.3004699-372461-211225077716996="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433160.3004699-372461-211225077716996=/home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp0fqvo57g TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp0fqvo57g /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-zuoanywchazauaywhpcjmgdghnjpmnfg ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"ansible_facts": {"ansible_lsb": {}, "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_iscsi_iqn": "", "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "26", "second": "01", "epoch": "1795433161", "epoch_int": "1795433161", "date": "2026-11-23", "time": "11:26:01", "iso8601_micro": "2026-11-23T11:26:01.100620Z", "iso8601": "2026-11-23T11:26:01Z", "iso8601_basic": "20261123T112601100620", "iso8601_basic_short": "20261123T112601", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_local": {}, "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDACO/623RUzZcY73bNsfq0ITJ8QOM7DQkVe+Yl6+IfyXfKk37Fcip0hn8EWmtKoBcmmhwtZSsA93fVgT4TRBFZGR7mKTglUPRfMPSqlOjNe7eGtrm+E2I4kAaK8NgC1tQI6EBJDgkeC9GvwAK00AWucWrDsfSxEAODu5QkLZP7wWbFakGudyyzetKJ4MDBoarl+kuDSp3h0Q2v6pOGj0lKFtEpnxL/rhRgaYas60ImXjStqLhMTTvDYzLao1mTgQMKzWafIiY/JXkBgEqSuCcTgLaY/VwHmyW3Gt+n2lxouG7haVPu/IGbA5tp9cYEeOGdwsKcCmLRiVph04ShcFUQi9lj77fLfigniXSD2jBs+C49b80dDxAxF6Od2hCySOT7ZTW/wem7fe8l/w5HqofVozFnzuDXUWVx55N1cXoN1JmYpjC6SQjsmyEcR9UiPgZEe35XWvrdUcXB0jpg6+R4S1LXAhc5uOM5O4Y8EJChXqb2KWASI2MD1r7VJCyzHi0=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEcKKjgPQMJ6zBzNsrTw0iNV4PNZQ22o8goc87g3kImFI7X9pc4E/wSEArz15ZNesRnNVskCCpJ94OGAgoDZd48=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIJG4P4mcAOdm2TLEI5NmaVBnQaE5W4WXkqN2bl+3NGNy", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "ns01", "ansible_hostname": "ns01", "ansible_nodename": "ns01", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "8b84ba6392a3453486f50c9ed82393f9", "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_is_chroot": false, "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_apparmor": {"status": "disabled"}, "ansible_fips": false, "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_pkg_mgr": "dnf", "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_fibre_channel_wwn": [], "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-zuoanywchazauaywhpcjmgdghnjpmnfg ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 373, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 566, "free": 373}, "nocache": {"free": 638, "used": 301}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-2f0288ea-2b1d-43c6-8986-d3b785b8051f", "ansible_product_uuid": "ea88022f-1d2b-c643-8986-d3b785b8051f", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB2e0bebb1", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part2"], "sda3": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part3"], "sda4": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part4"], "sda1": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a-part1"], "sda": ["ata-VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-0ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-1ATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a", "scsi-SATA_VBOX_HARDDISK_VB2e0bebb1-80e9880a"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 161, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18308337664, "block_size": 4096, "block_total": 4789504, "block_available": 4469809, "block_used": 319695, "inode_total": 9611776, "inode_available": 9570274, "inode_used": 41502, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_interfaces": ["eth1", "lo", "eth0"], "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:2e:49:4f", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.10", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe2e:494f", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "prefix": "64", "scope": "global"}, {"address": "fe80::7b3b:a9f8:34ed:126a", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.10", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe2e:494f", "fd17:625c:f037:2:c9e6:bdd7:a25e:ae6", "fe80::7b3b:a9f8:34ed:126a"], "ansible_service_mgr": "systemd", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433160.3004699-372461-211225077716996/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns01]
META: ran handlers

TASK [copy named.conf] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:18
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812 `" && echo ansible-tmp-1795433161.7783525-372494-258621150381812="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433161.7783525-372494-258621150381812=/home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpv7e1j63c TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpv7e1j63c /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-aatvrhsxizvtltsfmcqaxyapckioqbep ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/named.conf", "mode": "0640", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 25, "size": 1722, "inode": 33866908, "dev": 2052, "nlink": 1, "atime": 1794467949.0, "mtime": 1794467949.0, "ctime": 1795433147.591118, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": false, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "named", "checksum": "8949ffe0fed7ceed49a8b98f136655b95cc4e7ea", "mimetype": "text/plain", "charset": "us-ascii", "version": "1496482020", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/named.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/master-named.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/master-named.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpwb02j0cg TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpwb02j0cg /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-nncwbmhvihusxhvccqmmzusppiqrrqhf ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source", "md5sum": "c818adc0651af6aefd8be1805e4347b9", "checksum": "d51518fcfb18ba30562700330dd1d673cd7bb6ee", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0640", "state": "file", "secontext": "system_u:object_r:named_conf_t:s0", "size": 1744, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source", "dest": "/etc/named.conf", "owner": "root", "group": "named", "mode": "0640", "_original_basename": "master-named.conf", "follow": false, "checksum": "d51518fcfb18ba30562700330dd1d673cd7bb6ee", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => {
    "changed": true,
    "checksum": "d51518fcfb18ba30562700330dd1d673cd7bb6ee",
    "dest": "/etc/named.conf",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "master-named.conf",
            "attributes": null,
            "backup": false,
            "checksum": "d51518fcfb18ba30562700330dd1d673cd7bb6ee",
            "content": null,
            "dest": "/etc/named.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0640",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "c818adc0651af6aefd8be1805e4347b9",
    "mode": "0640",
    "owner": "root",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 1744,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433161.7783525-372494-258621150381812/source",
    "state": "file",
    "uid": 0
}

TASK [copy zones] **************************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:20
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583 `" && echo ansible-tmp-1795433163.9314697-372545-51028034186583="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433163.9314697-372545-51028034186583=/home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp52if7bnl TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp52if7bnl /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ikknyarbxnaobatqzxlsscvzwzdzdiqt ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named/named.ddns.lab", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.ddns.lab TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.ddns.lab /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp74wetts7 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp74wetts7 /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-sosfankmyvsenicmwewqliwxsnyylzsp ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named/named.ddns.lab", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source", "md5sum": "f09b49b89bdd3f36edbf24ffd62b80ee", "checksum": "445e1d5724b473c17c814a96d633e39de2a1f624", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0660", "state": "file", "secontext": "system_u:object_r:named_conf_t:s0", "size": 600, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source", "dest": "/etc/named/", "owner": "root", "group": "named", "mode": "0660", "_original_basename": "named.ddns.lab", "follow": false, "checksum": "445e1d5724b473c17c814a96d633e39de2a1f624", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => (item=/home/admin_insta11/vagrant-bind/provisioning/named.ddns.lab) => {
    "ansible_loop_var": "item",
    "changed": true,
    "checksum": "445e1d5724b473c17c814a96d633e39de2a1f624",
    "dest": "/etc/named/named.ddns.lab",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.ddns.lab",
            "attributes": null,
            "backup": false,
            "checksum": "445e1d5724b473c17c814a96d633e39de2a1f624",
            "content": null,
            "dest": "/etc/named/",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0660",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "item": "/home/admin_insta11/vagrant-bind/provisioning/named.ddns.lab",
    "md5sum": "f09b49b89bdd3f36edbf24ffd62b80ee",
    "mode": "0660",
    "owner": "root",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 600,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433163.9314697-372545-51028034186583/source",
    "state": "file",
    "uid": 0
}
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491 `" && echo ansible-tmp-1795433165.6734533-372545-29416634560491="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433165.6734533-372545-29416634560491=/home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp5dfmabsm TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp5dfmabsm /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ueusdevobmfvbiljyovbkkahwmxddwyp ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named/named.dns.lab.rev", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.dns.lab.rev TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.dns.lab.rev /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp1_938vf7 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp1_938vf7 /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-fzephovrvgpaitzniykpplgrjyikeppe ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named/named.dns.lab.rev", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source", "md5sum": "3432ec3de340b2852ef3f008f03c2b5b", "checksum": "c8d5dc49660f9eeb9850c9993bcfd2866b15a765", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0660", "state": "file", "secontext": "system_u:object_r:named_conf_t:s0", "size": 625, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source", "dest": "/etc/named/", "owner": "root", "group": "named", "mode": "0660", "_original_basename": "named.dns.lab.rev", "follow": false, "checksum": "c8d5dc49660f9eeb9850c9993bcfd2866b15a765", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => (item=/home/admin_insta11/vagrant-bind/provisioning/named.dns.lab.rev) => {
    "ansible_loop_var": "item",
    "changed": true,
    "checksum": "c8d5dc49660f9eeb9850c9993bcfd2866b15a765",
    "dest": "/etc/named/named.dns.lab.rev",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.dns.lab.rev",
            "attributes": null,
            "backup": false,
            "checksum": "c8d5dc49660f9eeb9850c9993bcfd2866b15a765",
            "content": null,
            "dest": "/etc/named/",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0660",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "item": "/home/admin_insta11/vagrant-bind/provisioning/named.dns.lab.rev",
    "md5sum": "3432ec3de340b2852ef3f008f03c2b5b",
    "mode": "0660",
    "owner": "root",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 625,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433165.6734533-372545-29416634560491/source",
    "state": "file",
    "uid": 0
}
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123 `" && echo ansible-tmp-1795433167.2159333-372545-25142998912123="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433167.2159333-372545-25142998912123=/home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpjcfkmvip TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpjcfkmvip /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ydgdxnqpgesxgplosaydykfhbgapftwp ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named/named.dns.lab", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.dns.lab TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.dns.lab /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpx2s40kms TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpx2s40kms /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-pmxfizjpmrtiypelnwepqxofbmrfojlj ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named/named.dns.lab", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source", "md5sum": "3a44223b9423546cfc56921b33099d10", "checksum": "7cf4636aca886260adf8ec2b04d320b178def7cd", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0660", "state": "file", "secontext": "system_u:object_r:named_conf_t:s0", "size": 599, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source", "dest": "/etc/named/", "owner": "root", "group": "named", "mode": "0660", "_original_basename": "named.dns.lab", "follow": false, "checksum": "7cf4636aca886260adf8ec2b04d320b178def7cd", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => (item=/home/admin_insta11/vagrant-bind/provisioning/named.dns.lab) => {
    "ansible_loop_var": "item",
    "changed": true,
    "checksum": "7cf4636aca886260adf8ec2b04d320b178def7cd",
    "dest": "/etc/named/named.dns.lab",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.dns.lab",
            "attributes": null,
            "backup": false,
            "checksum": "7cf4636aca886260adf8ec2b04d320b178def7cd",
            "content": null,
            "dest": "/etc/named/",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0660",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "item": "/home/admin_insta11/vagrant-bind/provisioning/named.dns.lab",
    "md5sum": "3a44223b9423546cfc56921b33099d10",
    "mode": "0660",
    "owner": "root",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 599,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433167.2159333-372545-25142998912123/source",
    "state": "file",
    "uid": 0
}

TASK [copy resolv.conf to the servers] *****************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:24
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263 `" && echo ansible-tmp-1795433169.0306633-372698-188272940006263="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433169.0306633-372698-188272940006263=/home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpuraaon_8 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpuraaon_8 /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-mpyrxnepkqbdoecmxxbkdeexkbtuzaia ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/resolv.conf", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 50, "inode": 33866905, "dev": 2052, "nlink": 1, "atime": 1795433108.7468736, "mtime": 1795433098.688989, "ctime": 1795433098.6959853, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "ee0f0edfdf05764de96b51aff44b8dcd4d07cd7a", "mimetype": "text/plain", "charset": "us-ascii", "version": "429995735", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/resolv.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/servers-resolv.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/servers-resolv.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp8kqaa8ee TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp8kqaa8ee /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-qmgehhzgxfzrebvirkfdeohwdzyczsvx ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/resolv.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source", "md5sum": "436cae9d2c09dfac81564ad5085f1655", "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:net_conf_t:s0", "size": 51, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source", "dest": "/etc/resolv.conf", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "servers-resolv.conf", "follow": false, "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => {
    "changed": true,
    "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5",
    "dest": "/etc/resolv.conf",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "servers-resolv.conf",
            "attributes": null,
            "backup": false,
            "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5",
            "content": null,
            "dest": "/etc/resolv.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "436cae9d2c09dfac81564ad5085f1655",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:net_conf_t:s0",
    "size": 51,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433169.0306633-372698-188272940006263/source",
    "state": "file",
    "uid": 0
}

TASK [set /etc/named permissions] **********************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:27
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628 `" && echo ansible-tmp-1795433170.7632701-372752-49402080103628="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433170.7632701-372752-49402080103628=/home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/file.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpm7d1xelh TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/AnsiballZ_file.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmpm7d1xelh /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/AnsiballZ_file.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/AnsiballZ_file.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-zvqoagourdkyomwgbngeybjfoitepqkn ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/AnsiballZ_file.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"path": "/etc/named", "changed": true, "diff": {"before": {"path": "/etc/named", "mode": "0750"}, "after": {"path": "/etc/named", "mode": "0670"}}, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0670", "state": "directory", "secontext": "system_u:object_r:named_conf_t:s0", "size": 74, "invocation": {"module_args": {"path": "/etc/named", "owner": "root", "group": "named", "mode": "0670", "recurse": false, "force": false, "follow": true, "modification_time_format": "%Y%m%d%H%M.%S", "access_time_format": "%Y%m%d%H%M.%S", "unsafe_writes": false, "state": "directory", "_original_basename": null, "_diff_peek": null, "src": null, "modification_time": null, "access_time": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433170.7632701-372752-49402080103628/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => {
    "changed": true,
    "diff": {
        "after": {
            "mode": "0670",
            "path": "/etc/named"
        },
        "before": {
            "mode": "0750",
            "path": "/etc/named"
        }
    },
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_diff_peek": null,
            "_original_basename": null,
            "access_time": null,
            "access_time_format": "%Y%m%d%H%M.%S",
            "attributes": null,
            "follow": true,
            "force": false,
            "group": "named",
            "mode": "0670",
            "modification_time": null,
            "modification_time_format": "%Y%m%d%H%M.%S",
            "owner": "root",
            "path": "/etc/named",
            "recurse": false,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": null,
            "state": "directory",
            "unsafe_writes": false
        }
    },
    "mode": "0670",
    "owner": "root",
    "path": "/etc/named",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 74,
    "state": "directory",
    "uid": 0
}

TASK [ensure named is running and enabled] *************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:30
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795 `" && echo ansible-tmp-1795433171.795661-372783-184550206109795="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433171.795661-372783-184550206109795=/home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/systemd.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp779otarx TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/AnsiballZ_systemd.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-372283nqktmtvd/tmp779otarx /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/AnsiballZ_systemd.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/AnsiballZ_systemd.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ytdrtvuoaokmpdgkewbjfztvlgfcocod ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/AnsiballZ_systemd.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"name": "named", "changed": true, "status": {"Type": "forking", "ExitType": "main", "Restart": "no", "PIDFile": "/run/named/named.pid", "NotifyAccess": "none", "RestartUSec": "100ms", "TimeoutStartUSec": "1min 30s", "TimeoutStopUSec": "1min 30s", "TimeoutAbortUSec": "1min 30s", "TimeoutStartFailureMode": "terminate", "TimeoutStopFailureMode": "terminate", "RuntimeMaxUSec": "infinity", "RuntimeRandomizedExtraUSec": "0", "WatchdogUSec": "infinity", "WatchdogTimestampMonotonic": "0", "RootDirectoryStartOnly": "no", "RemainAfterExit": "no", "GuessMainPID": "yes", "MainPID": "0", "ControlPID": "0", "FileDescriptorStoreMax": "0", "NFileDescriptorStore": "0", "StatusErrno": "0", "Result": "success", "ReloadResult": "success", "CleanResult": "success", "UID": "[not set]", "GID": "[not set]", "NRestarts": "0", "OOMPolicy": "stop", "ReloadSignal": "1", "ExecMainStartTimestampMonotonic": "0", "ExecMainExitTimestampMonotonic": "0", "ExecMainPID": "0", "ExecMainCode": "0", "ExecMainStatus": "0", "ExecStartPre": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \\"$DISABLE_ZONE_CHECKING\\" == \\"yes\\" ]; then /usr/sbin/named-checkconf -z \\"$NAMEDCONF\\"; else echo \\"Checking of zone files is disabled\\"; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStartPreEx": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \\"$DISABLE_ZONE_CHECKING\\" == \\"yes\\" ]; then /usr/sbin/named-checkconf -z \\"$NAMEDCONF\\"; else echo \\"Checking of zone files is disabled\\"; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStart": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStartEx": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecReload": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecReloadEx": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStop": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStopEx": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "Slice": "system.slice", "ControlGroupId": "0", "MemoryCurrent": "[not set]", "MemoryPeak": "18446744073709551615", "MemoryAvailable": "infinity", "CPUUsageNSec": "[not set]", "TasksCurrent": "[not set]", "IPIngressBytes": "[no data]", "IPIngressPackets": "[no data]", "IPEgressBytes": "[no data]", "IPEgressPackets": "[no data]", "IOReadBytes": "18446744073709551615", "IOReadOperations": "18446744073709551615", "IOWriteBytes": "18446744073709551615", "IOWriteOperations": "18446744073709551615", "Delegate": "no", "CPUAccounting": "yes", "CPUWeight": "[not set]", "StartupCPUWeight": "[not set]", "CPUShares": "[not set]", "StartupCPUShares": "[not set]", "CPUQuotaPerSecUSec": "infinity", "CPUQuotaPeriodUSec": "infinity", "IOAccounting": "no", "IOWeight": "[not set]", "StartupIOWeight": "[not set]", "BlockIOAccounting": "no", "BlockIOWeight": "[not set]", "StartupBlockIOWeight": "[not set]", "MemoryAccounting": "yes", "DefaultMemoryLow": "0", "DefaultMemoryMin": "0", "MemoryMin": "0", "MemoryLow": "0", "MemoryHigh": "infinity", "MemoryMax": "infinity", "MemorySwapMax": "infinity", "MemoryLimit": "infinity", "DevicePolicy": "auto", "TasksAccounting": "yes", "TasksMax": "5464", "IPAccounting": "no", "ManagedOOMSwap": "auto", "ManagedOOMMemoryPressure": "auto", "ManagedOOMMemoryPressureLimit": "0", "ManagedOOMPreference": "none", "Environment": "NAMEDCONF=/etc/named.conf KRB5_KTNAME=/etc/named.keytab", "EnvironmentFiles": "/etc/sysconfig/named (ignore_errors=yes)", "UMask": "0022", "LimitCPU": "infinity", "LimitCPUSoft": "infinity", "LimitFSIZE": "infinity", "LimitFSIZESoft": "infinity", "LimitDATA": "infinity", "LimitDATASoft": "infinity", "LimitSTACK": "infinity", "LimitSTACKSoft": "8388608", "LimitCORE": "infinity", "LimitCORESoft": "infinity", "LimitRSS": "infinity", "LimitRSSSoft": "infinity", "LimitNOFILE": "524288", "LimitNOFILESoft": "1024", "LimitAS": "infinity", "LimitASSoft": "infinity", "LimitNPROC": "3415", "LimitNPROCSoft": "3415", "LimitMEMLOCK": "8388608", "LimitMEMLOCKSoft": "8388608", "LimitLOCKS": "infinity", "LimitLOCKSSoft": "infinity", "LimitSIGPENDING": "3415", "LimitSIGPENDINGSoft": "3415", "LimitMSGQUEUE": "819200", "LimitMSGQUEUESoft": "819200", "LimitNICE": "0", "LimitNICESoft": "0", "LimitRTPRIO": "0", "LimitRTPRIOSoft": "0", "LimitRTTIME": "infinity", "LimitRTTIMESoft": "infinity", "OOMScoreAdjust": "0", "CoredumpFilter": "0x33", "Nice": "0", "IOSchedulingClass": "2", "IOSchedulingPriority": "4", "CPUSchedulingPolicy": "0", "CPUSchedulingPriority": "0", "CPUAffinityFromNUMA": "no", "NUMAPolicy": "n/a", "TimerSlackNSec": "50000", "CPUSchedulingResetOnFork": "no", "NonBlocking": "no", "StandardInput": "null", "StandardOutput": "journal", "StandardError": "inherit", "TTYReset": "no", "TTYVHangup": "no", "TTYVTDisallocate": "no", "SyslogPriority": "30", "SyslogLevelPrefix": "yes", "SyslogLevel": "6", "SyslogFacility": "3", "LogLevelMax": "-1", "LogRateLimitIntervalUSec": "0", "LogRateLimitBurst": "0", "SecureBits": "0", "CapabilityBoundingSet": "cap_chown cap_dac_override cap_dac_read_search cap_fowner cap_fsetid cap_kill cap_setgid cap_setuid cap_setpcap cap_linux_immutable cap_net_bind_service cap_net_broadcast cap_net_admin cap_net_raw cap_ipc_lock cap_ipc_owner cap_sys_module cap_sys_rawio cap_sys_chroot cap_sys_ptrace cap_sys_pacct cap_sys_admin cap_sys_boot cap_sys_nice cap_sys_resource cap_sys_time cap_sys_tty_config cap_mknod cap_lease cap_audit_write cap_audit_control cap_setfcap cap_mac_override cap_mac_admin cap_syslog cap_wake_alarm cap_block_suspend cap_audit_read cap_perfmon cap_bpf cap_checkpoint_restore", "DynamicUser": "no", "RemoveIPC": "no", "PrivateTmp": "yes", "PrivateDevices": "no", "ProtectClock": "no", "ProtectKernelTunables": "no", "ProtectKernelModules": "no", "ProtectKernelLogs": "no", "ProtectControlGroups": "no", "PrivateNetwork": "no", "PrivateUsers": "no", "PrivateMounts": "no", "PrivateIPC": "no", "ProtectHome": "no", "ProtectSystem": "no", "SameProcessGroup": "no", "UtmpMode": "init", "IgnoreSIGPIPE": "yes", "NoNewPrivileges": "no", "SystemCallErrorNumber": "2147483646", "LockPersonality": "no", "RuntimeDirectoryPreserve": "no", "RuntimeDirectoryMode": "0755", "StateDirectoryMode": "0755", "CacheDirectoryMode": "0755", "LogsDirectoryMode": "0755", "ConfigurationDirectoryMode": "0755", "TimeoutCleanUSec": "infinity", "MemoryDenyWriteExecute": "no", "RestrictRealtime": "no", "RestrictSUIDSGID": "no", "RestrictNamespaces": "no", "MountAPIVFS": "no", "KeyringMode": "private", "ProtectProc": "default", "ProcSubset": "all", "ProtectHostname": "no", "KillMode": "control-group", "KillSignal": "15", "RestartKillSignal": "15", "FinalKillSignal": "9", "SendSIGKILL": "yes", "SendSIGHUP": "no", "WatchdogSignal": "6", "Id": "named.service", "Names": "named.service", "Requires": "sysinit.target system.slice -.mount", "Wants": "named-setup-rndc.service nss-lookup.target", "Conflicts": "shutdown.target", "Before": "shutdown.target nss-lookup.target", "After": "tmp.mount -.mount systemd-journald.socket named-setup-rndc.service sysinit.target network.target basic.target system.slice systemd-tmpfiles-setup.service", "RequiresMountsFor": "/var/tmp", "Description": "Berkeley Internet Name Domain (DNS)", "AccessSELinuxContext": "system_u:object_r:named_unit_file_t:s0", "LoadState": "loaded", "ActiveState": "inactive", "FreezerState": "running", "SubState": "dead", "FragmentPath": "/usr/lib/systemd/system/named.service", "UnitFileState": "disabled", "UnitFilePreset": "disabled", "StateChangeTimestampMonotonic": "0", "InactiveExitTimestampMonotonic": "0", "ActiveEnterTimestampMonotonic": "0", "ActiveExitTimestampMonotonic": "0", "InactiveEnterTimestampMonotonic": "0", "CanStart": "yes", "CanStop": "yes", "CanReload": "yes", "CanIsolate": "no", "CanFreeze": "yes", "StopWhenUnneeded": "no", "RefuseManualStart": "no", "RefuseManualStop": "no", "AllowIsolate": "no", "DefaultDependencies": "yes", "OnSuccessJobMode": "fail", "OnFailureJobMode": "replace", "IgnoreOnIsolate": "no", "NeedDaemonReload": "no", "JobTimeoutUSec": "infinity", "JobRunningTimeoutUSec": "infinity", "JobTimeoutAction": "none", "ConditionResult": "no", "AssertResult": "no", "ConditionTimestampMonotonic": "0", "AssertTimestampMonotonic": "0", "Transient": "no", "Perpetual": "no", "StartLimitIntervalUSec": "10s", "StartLimitBurst": "5", "StartLimitAction": "none", "FailureAction": "none", "SuccessAction": "none", "CollectMode": "inactive"}, "enabled": true, "state": "started", "invocation": {"module_args": {"name": "named", "state": "restarted", "enabled": true, "daemon_reload": false, "daemon_reexec": false, "scope": "system", "no_block": false, "force": null, "masked": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2222 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/055b8f4af0"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433171.795661-372783-184550206109795/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns01] => {
    "changed": true,
    "enabled": true,
    "invocation": {
        "module_args": {
            "daemon_reexec": false,
            "daemon_reload": false,
            "enabled": true,
            "force": null,
            "masked": null,
            "name": "named",
            "no_block": false,
            "scope": "system",
            "state": "restarted"
        }
    },
    "name": "named",
    "state": "started",
    "status": {
        "AccessSELinuxContext": "system_u:object_r:named_unit_file_t:s0",
        "ActiveEnterTimestampMonotonic": "0",
        "ActiveExitTimestampMonotonic": "0",
        "ActiveState": "inactive",
        "After": "tmp.mount -.mount systemd-journald.socket named-setup-rndc.service sysinit.target network.target basic.target system.slice systemd-tmpfiles-setup.service",
        "AllowIsolate": "no",
        "AssertResult": "no",
        "AssertTimestampMonotonic": "0",
        "Before": "shutdown.target nss-lookup.target",
        "BlockIOAccounting": "no",
        "BlockIOWeight": "[not set]",
        "CPUAccounting": "yes",
        "CPUAffinityFromNUMA": "no",
        "CPUQuotaPerSecUSec": "infinity",
        "CPUQuotaPeriodUSec": "infinity",
        "CPUSchedulingPolicy": "0",
        "CPUSchedulingPriority": "0",
        "CPUSchedulingResetOnFork": "no",
        "CPUShares": "[not set]",
        "CPUUsageNSec": "[not set]",
        "CPUWeight": "[not set]",
        "CacheDirectoryMode": "0755",
        "CanFreeze": "yes",
        "CanIsolate": "no",
        "CanReload": "yes",
        "CanStart": "yes",
        "CanStop": "yes",
        "CapabilityBoundingSet": "cap_chown cap_dac_override cap_dac_read_search cap_fowner cap_fsetid cap_kill cap_setgid cap_setuid cap_setpcap cap_linux_immutable cap_net_bind_service cap_net_broadcast cap_net_admin cap_net_raw cap_ipc_lock cap_ipc_owner cap_sys_module cap_sys_rawio cap_sys_chroot cap_sys_ptrace cap_sys_pacct cap_sys_admin cap_sys_boot cap_sys_nice cap_sys_resource cap_sys_time cap_sys_tty_config cap_mknod cap_lease cap_audit_write cap_audit_control cap_setfcap cap_mac_override cap_mac_admin cap_syslog cap_wake_alarm cap_block_suspend cap_audit_read cap_perfmon cap_bpf cap_checkpoint_restore",
        "CleanResult": "success",
        "CollectMode": "inactive",
        "ConditionResult": "no",
        "ConditionTimestampMonotonic": "0",
        "ConfigurationDirectoryMode": "0755",
        "Conflicts": "shutdown.target",
        "ControlGroupId": "0",
        "ControlPID": "0",
        "CoredumpFilter": "0x33",
        "DefaultDependencies": "yes",
        "DefaultMemoryLow": "0",
        "DefaultMemoryMin": "0",
        "Delegate": "no",
        "Description": "Berkeley Internet Name Domain (DNS)",
        "DevicePolicy": "auto",
        "DynamicUser": "no",
        "Environment": "NAMEDCONF=/etc/named.conf KRB5_KTNAME=/etc/named.keytab",
        "EnvironmentFiles": "/etc/sysconfig/named (ignore_errors=yes)",
        "ExecMainCode": "0",
        "ExecMainExitTimestampMonotonic": "0",
        "ExecMainPID": "0",
        "ExecMainStartTimestampMonotonic": "0",
        "ExecMainStatus": "0",
        "ExecReload": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecReloadEx": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStart": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartEx": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartPre": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \"$DISABLE_ZONE_CHECKING\" == \"yes\" ]; then /usr/sbin/named-checkconf -z \"$NAMEDCONF\"; else echo \"Checking of zone files is disabled\"; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartPreEx": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \"$DISABLE_ZONE_CHECKING\" == \"yes\" ]; then /usr/sbin/named-checkconf -z \"$NAMEDCONF\"; else echo \"Checking of zone files is disabled\"; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStop": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStopEx": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExitType": "main",
        "FailureAction": "none",
        "FileDescriptorStoreMax": "0",
        "FinalKillSignal": "9",
        "FragmentPath": "/usr/lib/systemd/system/named.service",
        "FreezerState": "running",
        "GID": "[not set]",
        "GuessMainPID": "yes",
        "IOAccounting": "no",
        "IOReadBytes": "18446744073709551615",
        "IOReadOperations": "18446744073709551615",
        "IOSchedulingClass": "2",
        "IOSchedulingPriority": "4",
        "IOWeight": "[not set]",
        "IOWriteBytes": "18446744073709551615",
        "IOWriteOperations": "18446744073709551615",
        "IPAccounting": "no",
        "IPEgressBytes": "[no data]",
        "IPEgressPackets": "[no data]",
        "IPIngressBytes": "[no data]",
        "IPIngressPackets": "[no data]",
        "Id": "named.service",
        "IgnoreOnIsolate": "no",
        "IgnoreSIGPIPE": "yes",
        "InactiveEnterTimestampMonotonic": "0",
        "InactiveExitTimestampMonotonic": "0",
        "JobRunningTimeoutUSec": "infinity",
        "JobTimeoutAction": "none",
        "JobTimeoutUSec": "infinity",
        "KeyringMode": "private",
        "KillMode": "control-group",
        "KillSignal": "15",
        "LimitAS": "infinity",
        "LimitASSoft": "infinity",
        "LimitCORE": "infinity",
        "LimitCORESoft": "infinity",
        "LimitCPU": "infinity",
        "LimitCPUSoft": "infinity",
        "LimitDATA": "infinity",
        "LimitDATASoft": "infinity",
        "LimitFSIZE": "infinity",
        "LimitFSIZESoft": "infinity",
        "LimitLOCKS": "infinity",
        "LimitLOCKSSoft": "infinity",
        "LimitMEMLOCK": "8388608",
        "LimitMEMLOCKSoft": "8388608",
        "LimitMSGQUEUE": "819200",
        "LimitMSGQUEUESoft": "819200",
        "LimitNICE": "0",
        "LimitNICESoft": "0",
        "LimitNOFILE": "524288",
        "LimitNOFILESoft": "1024",
        "LimitNPROC": "3415",
        "LimitNPROCSoft": "3415",
        "LimitRSS": "infinity",
        "LimitRSSSoft": "infinity",
        "LimitRTPRIO": "0",
        "LimitRTPRIOSoft": "0",
        "LimitRTTIME": "infinity",
        "LimitRTTIMESoft": "infinity",
        "LimitSIGPENDING": "3415",
        "LimitSIGPENDINGSoft": "3415",
        "LimitSTACK": "infinity",
        "LimitSTACKSoft": "8388608",
        "LoadState": "loaded",
        "LockPersonality": "no",
        "LogLevelMax": "-1",
        "LogRateLimitBurst": "0",
        "LogRateLimitIntervalUSec": "0",
        "LogsDirectoryMode": "0755",
        "MainPID": "0",
        "ManagedOOMMemoryPressure": "auto",
        "ManagedOOMMemoryPressureLimit": "0",
        "ManagedOOMPreference": "none",
        "ManagedOOMSwap": "auto",
        "MemoryAccounting": "yes",
        "MemoryAvailable": "infinity",
        "MemoryCurrent": "[not set]",
        "MemoryDenyWriteExecute": "no",
        "MemoryHigh": "infinity",
        "MemoryLimit": "infinity",
        "MemoryLow": "0",
        "MemoryMax": "infinity",
        "MemoryMin": "0",
        "MemoryPeak": "18446744073709551615",
        "MemorySwapMax": "infinity",
        "MountAPIVFS": "no",
        "NFileDescriptorStore": "0",
        "NRestarts": "0",
        "NUMAPolicy": "n/a",
        "Names": "named.service",
        "NeedDaemonReload": "no",
        "Nice": "0",
        "NoNewPrivileges": "no",
        "NonBlocking": "no",
        "NotifyAccess": "none",
        "OOMPolicy": "stop",
        "OOMScoreAdjust": "0",
        "OnFailureJobMode": "replace",
        "OnSuccessJobMode": "fail",
        "PIDFile": "/run/named/named.pid",
        "Perpetual": "no",
        "PrivateDevices": "no",
        "PrivateIPC": "no",
        "PrivateMounts": "no",
        "PrivateNetwork": "no",
        "PrivateTmp": "yes",
        "PrivateUsers": "no",
        "ProcSubset": "all",
        "ProtectClock": "no",
        "ProtectControlGroups": "no",
        "ProtectHome": "no",
        "ProtectHostname": "no",
        "ProtectKernelLogs": "no",
        "ProtectKernelModules": "no",
        "ProtectKernelTunables": "no",
        "ProtectProc": "default",
        "ProtectSystem": "no",
        "RefuseManualStart": "no",
        "RefuseManualStop": "no",
        "ReloadResult": "success",
        "ReloadSignal": "1",
        "RemainAfterExit": "no",
        "RemoveIPC": "no",
        "Requires": "sysinit.target system.slice -.mount",
        "RequiresMountsFor": "/var/tmp",
        "Restart": "no",
        "RestartKillSignal": "15",
        "RestartUSec": "100ms",
        "RestrictNamespaces": "no",
        "RestrictRealtime": "no",
        "RestrictSUIDSGID": "no",
        "Result": "success",
        "RootDirectoryStartOnly": "no",
        "RuntimeDirectoryMode": "0755",
        "RuntimeDirectoryPreserve": "no",
        "RuntimeMaxUSec": "infinity",
        "RuntimeRandomizedExtraUSec": "0",
        "SameProcessGroup": "no",
        "SecureBits": "0",
        "SendSIGHUP": "no",
        "SendSIGKILL": "yes",
        "Slice": "system.slice",
        "StandardError": "inherit",
        "StandardInput": "null",
        "StandardOutput": "journal",
        "StartLimitAction": "none",
        "StartLimitBurst": "5",
        "StartLimitIntervalUSec": "10s",
        "StartupBlockIOWeight": "[not set]",
        "StartupCPUShares": "[not set]",
        "StartupCPUWeight": "[not set]",
        "StartupIOWeight": "[not set]",
        "StateChangeTimestampMonotonic": "0",
        "StateDirectoryMode": "0755",
        "StatusErrno": "0",
        "StopWhenUnneeded": "no",
        "SubState": "dead",
        "SuccessAction": "none",
        "SyslogFacility": "3",
        "SyslogLevel": "6",
        "SyslogLevelPrefix": "yes",
        "SyslogPriority": "30",
        "SystemCallErrorNumber": "2147483646",
        "TTYReset": "no",
        "TTYVHangup": "no",
        "TTYVTDisallocate": "no",
        "TasksAccounting": "yes",
        "TasksCurrent": "[not set]",
        "TasksMax": "5464",
        "TimeoutAbortUSec": "1min 30s",
        "TimeoutCleanUSec": "infinity",
        "TimeoutStartFailureMode": "terminate",
        "TimeoutStartUSec": "1min 30s",
        "TimeoutStopFailureMode": "terminate",
        "TimeoutStopUSec": "1min 30s",
        "TimerSlackNSec": "50000",
        "Transient": "no",
        "Type": "forking",
        "UID": "[not set]",
        "UMask": "0022",
        "UnitFilePreset": "disabled",
        "UnitFileState": "disabled",
        "UtmpMode": "init",
        "Wants": "named-setup-rndc.service nss-lookup.target",
        "WatchdogSignal": "6",
        "WatchdogTimestampMonotonic": "0",
        "WatchdogUSec": "infinity"
    }
}
META: ran handlers
META: ran handlers

PLAY [ns02] ********************************************************************
skipping: no hosts matched

PLAY [client, client2] *********************************************************
skipping: no hosts matched

PLAY RECAP *********************************************************************
ns01                       : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[WARNING]: Could not match supplied host pattern, ignoring: ns02
[WARNING]: Could not match supplied host pattern, ignoring: client
[WARNING]: Could not match supplied host pattern, ignoring: client2
==> ns02: Importing base box 'almalinux9-stand-vb'...
==> ns02: Matching MAC address for NAT networking...
==> ns02: Setting the name of the VM: vagrant-bind_ns02_1795433203774_72625
==> ns02: Fixed port collision for 22 => 2222. Now on port 2200.
==> ns02: Clearing any previously set network interfaces...
==> ns02: Preparing network interfaces based on configuration...
    ns02: Adapter 1: nat
    ns02: Adapter 2: intnet
==> ns02: Forwarding ports...
    ns02: 22 (guest) => 2200 (host) (adapter 1)
==> ns02: Running 'pre-boot' VM customizations...
==> ns02: Booting VM...
==> ns02: Waiting for machine to boot. This may take a few minutes...
    ns02: SSH address: 127.0.0.1:2200
    ns02: SSH username: vagrant
    ns02: SSH auth method: private key
    ns02: Warning: Connection reset. Retrying...
    ns02: Warning: Remote connection disconnect. Retrying...
    ns02: Warning: Connection reset. Retrying...
    ns02: Warning: Connection reset. Retrying...
    ns02: Warning: Connection reset. Retrying...
    ns02: Warning: Remote connection disconnect. Retrying...
    ns02: Warning: Connection reset. Retrying...
    ns02: Warning: Remote connection disconnect. Retrying...
    ns02: Warning: Connection reset. Retrying...
    ns02: 
    ns02: Vagrant insecure key detected. Vagrant will automatically replace
    ns02: this with a newly generated keypair for better security.
    ns02: 
    ns02: Inserting generated public key within guest...
    ns02: Removing insecure key from the guest if it's present...
    ns02: Key inserted! Disconnecting and reconnecting using new SSH key...
==> ns02: Machine booted and ready!
==> ns02: Checking for guest additions in VM...
    ns02: The guest additions on this VM do not match the installed version of
    ns02: VirtualBox! In most cases this is fine, but in rare cases it can
    ns02: prevent things such as shared folders from working properly. If you see
    ns02: shared folder errors, please make sure the guest additions within the
    ns02: virtual machine match the version of VirtualBox you have installed on
    ns02: your host and reload your VM.
    ns02: 
    ns02: Guest Additions Version: 7.2.16
    ns02: VirtualBox Version: 7.1
==> ns02: Setting hostname...
==> ns02: Configuring and enabling network interfaces...
==> ns02: Mounting shared folders...
    ns02: /home/admin_insta11/vagrant-bind => /vagrant
==> ns02: Running provisioner: ansible...
    ns02: Running ansible-playbook...
PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --connection=ssh --timeout=30 --limit="ns02" --inventory-file=/home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory -vvv provisioning/playbook.yml
ansible-playbook [core 2.13.13]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/admin_insta11/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.8/site-packages/ansible
  ansible collection location = /home/admin_insta11/.ansible/collections:/usr/share/ansible/collections
  executable location = /bin/ansible-playbook
  python version = 3.8.20 (default, Sep  9 2024, 00:00:00) [GCC 11.4.1 20230605 (Red Soft 11.4.0-1)]
  jinja version = 3.1.3
  libyaml = True
Using /etc/ansible/ansible.cfg as config file
host_list declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
script declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
auto declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
Parsed /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory inventory source with ini plugin
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: playbook.yml *********************************************************
4 plays in provisioning/playbook.yml

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:2
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b"Warning: Permanently added '[127.0.0.1]:2200' (ED25519) to the list of known hosts.\r\n")
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091 `" && echo ansible-tmp-1795433322.812399-379411-144184107669091="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433322.812399-379411-144184107669091=/home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091\n', b'')
<ns02> Attempting python interpreter discovery
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo PLATFORM; uname; echo FOUND; command -v '"'"'"'"'"'"'"'"'python3.10'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.9'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.8'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.6'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.5'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python3'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/libexec/platform-python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python2.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python'"'"'"'"'"'"'"'"'; echo ENDFOUND && sleep 0'"'"''
<127.0.0.1> (0, b'PLATFORM\nLinux\nFOUND\n/usr/bin/python3.9\n/usr/bin/python3\n/usr/libexec/platform-python\nENDFOUND\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'/usr/bin/python3.9 && sleep 0'"'"''
<127.0.0.1> (0, b'{"platform_dist_result": [], "osrelease_content": "NAME=\\"AlmaLinux\\"\\nVERSION=\\"9.8 (Olive Jaguar)\\"\\nID=\\"almalinux\\"\\nID_LIKE=\\"rhel centos fedora\\"\\nVERSION_ID=\\"9.8\\"\\nPLATFORM_ID=\\"platform:el9\\"\\nPRETTY_NAME=\\"AlmaLinux 9.8 (Olive Jaguar)\\"\\nANSI_COLOR=\\"0;34\\"\\nLOGO=\\"fedora-logo-icon\\"\\nCPE_NAME=\\"cpe:/o:almalinux:almalinux:9::baseos\\"\\nHOME_URL=\\"https://almalinux.org/\\"\\nDOCUMENTATION_URL=\\"https://wiki.almalinux.org/\\"\\nBUG_REPORT_URL=\\"https://bugs.almalinux.org/\\"\\n\\nALMALINUX_MANTISBT_PROJECT=\\"AlmaLinux-9\\"\\nALMALINUX_MANTISBT_PROJECT_VERSION=\\"9.8\\"\\nREDHAT_SUPPORT_PRODUCT=\\"AlmaLinux\\"\\nREDHAT_SUPPORT_PRODUCT_VERSION=\\"9.8\\"\\nSUPPORT_END=2032-06-01\\n"}\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpi6sab4lo TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpi6sab4lo /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-jzdliejyuexsdfmlzyaturdhtidttnbd ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"ansible_facts": {"ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "ns02", "ansible_hostname": "ns02", "ansible_nodename": "ns02", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "eb7152faa1384d2a893fd731fac7c980", "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDdfaCVyYHYUkMNnxsdle4c16I9ySr6vWp/MlCAEEX3ir5xYVMre27SW99/f2NSUpg0KM1D7j3MSXKF4EQ3LMy+LBuhCkeeQi3JTgSGPv6gmG2k1eyvmRRPhjo49EPzW/81UplvP1Zbx29p1gdzgmG97o8W6omreYqJd47P5d2KaaLgoQPKLGER81rXdYDnq1Pts/jcSZ0w2hxtHo844/aIyGE3x/eo3zc5pG5wys4bRcok8war5TY8zs8Q2/nEjeR6DjzeRCMc5UQ82NvI3BVI57/oxEal5J/8hiDaHoEEIDToRYbDmKHHzBuAwFGPaPEDheb8KoFG2GbNBKti/AxV74KXFlIWDYkoxnAYcWqRc7S8AvJEfpOjdKtRCQTGVdaBsgpTSLBJdRXWubYeYDWKwzsTpNC/6XykInTv0vN9dh7DzaOksKIwoeV+P0MCgM19/CcqI3+AZUxh+gsYZVtn7/9f/DEb+CMxta30BFmj61IlEjMzMJ1HLbZAK07bOhU=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLNqFXItJ3RbZ6TBCXi4+Q/K349GMydi3Ip7CAl8nndQnQhrlEtiUKs+G57kY8f3Ids/IHZaEnukfdCepLRaHwc=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIJCI/+JiZSooKMR+siy1y/3UxbozRquDkqVQNA/hId0e", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_is_chroot": false, "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_apparmor": {"status": "disabled"}, "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-jzdliejyuexsdfmlzyaturdhtidttnbd ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 589, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 350, "free": 589}, "nocache": {"free": 714, "used": 225}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-268f717a-3423-4938-b9fb-d431e65f2cb5", "ansible_product_uuid": "7a718f26-2334-3849-b9fb-d431e65f2cb5", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB7fa6071f", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2"], "sda3": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3"], "sda4": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4"], "sda1": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1"], "sda": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 110, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18366799872, "block_size": 4096, "block_total": 4789504, "block_available": 4484082, "block_used": 305422, "inode_total": 9611776, "inode_available": 9570688, "inode_used": 41088, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_lsb": {}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_local": {}, "ansible_fips": false, "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "28", "second": "45", "epoch": "1795433325", "epoch_int": "1795433325", "date": "2026-11-23", "time": "11:28:45", "iso8601_micro": "2026-11-23T11:28:45.157995Z", "iso8601": "2026-11-23T11:28:45Z", "iso8601_basic": "20261123T112845157995", "iso8601_basic_short": "20261123T112845", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_fibre_channel_wwn": [], "ansible_iscsi_iqn": "", "ansible_interfaces": ["lo", "eth0", "eth1"], "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:4b:3b:1c", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.11", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe4b:3b1c", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:3290:b027:f53e:e10c", "prefix": "64", "scope": "global"}, {"address": "fe80::a8ac:92eb:1487:8429", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:3290:b027:f53e:e10c", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.11", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe4b:3b1c", "fd17:625c:f037:2:3290:b027:f53e:e10c", "fe80::a8ac:92eb:1487:8429"], "ansible_service_mgr": "systemd", "ansible_pkg_mgr": "dnf", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433322.812399-379411-144184107669091/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns02]
META: ran handlers

TASK [install packages] ********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:5
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461 `" && echo ansible-tmp-1795433325.5362499-379456-103538542438461="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433325.5362499-379456-103538542438461=/home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpwqzvar32 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpwqzvar32 /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-nlzcmfxpoyjnicjlazwgxrpjbxqclstr ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "", "changed": true, "results": ["Installed: fstrm-0.6.1-3.el9.x86_64", "Installed: policycoreutils-python-utils-3.6-9.el9.noarch", "Installed: python3-policycoreutils-3.6-9.el9.noarch", "Installed: python3-ply-3.11-14.el9.noarch", "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch", "Installed: policycoreutils-3.6-9.el9.x86_64", "Installed: bind-32:9.16.50-12.el9_9.1.x86_64", "Installed: libmaxminddb-1.5.2-4.el9.x86_64", "Installed: libuv-1:1.42.0-2.el9_4.x86_64", "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64", "Removed: policycoreutils-3.6-5.el9.x86_64", "Removed: python3-policycoreutils-3.6-5.el9.noarch"], "rc": 0, "invocation": {"module_args": {"name": ["bind"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433325.5362499-379456-103538542438461/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
changed: [ns02] => (item=bind) => {
    "ansible_loop_var": "item",
    "changed": true,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind",
    "msg": "",
    "rc": 0,
    "results": [
        "Installed: fstrm-0.6.1-3.el9.x86_64",
        "Installed: policycoreutils-python-utils-3.6-9.el9.noarch",
        "Installed: python3-policycoreutils-3.6-9.el9.noarch",
        "Installed: python3-ply-3.11-14.el9.noarch",
        "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch",
        "Installed: policycoreutils-3.6-9.el9.x86_64",
        "Installed: bind-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: libmaxminddb-1.5.2-4.el9.x86_64",
        "Installed: libuv-1:1.42.0-2.el9_4.x86_64",
        "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Removed: policycoreutils-3.6-5.el9.x86_64",
        "Removed: python3-policycoreutils-3.6-5.el9.noarch"
    ]
}
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568 `" && echo ansible-tmp-1795433372.1382525-379456-129133383323568="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433372.1382525-379456-129133383323568=/home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpubpocp58 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpubpocp58 /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-xbwyssxjedgpuoltagrkturtoptxoarq ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"msg": "Nothing to do", "changed": false, "results": [], "rc": 0, "invocation": {"module_args": {"name": ["bind-utils"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433372.1382525-379456-129133383323568/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns02] => (item=bind-utils) => {
    "ansible_loop_var": "item",
    "changed": false,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind-utils"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind-utils",
    "msg": "Nothing to do",
    "rc": 0,
    "results": []
}

TASK [copy transferkey to all servers and the client] **************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:12
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256 `" && echo ansible-tmp-1795433374.3853168-379526-117954716082256="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433374.3853168-379526-117954716082256=/home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpzcqp9a9s TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpzcqp9a9s /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-xkqayosmjpyvvmuhzkzjsznhhfffjrbt ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named.zonetransfer.key", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpru1l5w6q TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpru1l5w6q /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-prwwwftpobktvrclqdavntxhdhlvqqzj ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named.zonetransfer.key", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source", "md5sum": "15ccf7d7d6ea11384de2901045af4d02", "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 91, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source", "dest": "/etc/named.zonetransfer.key", "owner": "root", "group": "named", "mode": "0644", "_original_basename": "named.zonetransfer.key", "follow": false, "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns02] => {
    "changed": true,
    "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
    "dest": "/etc/named.zonetransfer.key",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.zonetransfer.key",
            "attributes": null,
            "backup": false,
            "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
            "content": null,
            "dest": "/etc/named.zonetransfer.key",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "15ccf7d7d6ea11384de2901045af4d02",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 91,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433374.3853168-379526-117954716082256/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY [ns01] ********************************************************************
skipping: no hosts matched

PLAY [ns02] ********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:33
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925 `" && echo ansible-tmp-1795433376.5080397-379584-15083884147925="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433376.5080397-379584-15083884147925=/home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpc5xarhn2 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpc5xarhn2 /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-vgqpbeosvbtzusygwlzvthiuhmgfgkhg ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"ansible_facts": {"ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "ns02", "ansible_hostname": "ns02", "ansible_nodename": "ns02", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "eb7152faa1384d2a893fd731fac7c980", "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDdfaCVyYHYUkMNnxsdle4c16I9ySr6vWp/MlCAEEX3ir5xYVMre27SW99/f2NSUpg0KM1D7j3MSXKF4EQ3LMy+LBuhCkeeQi3JTgSGPv6gmG2k1eyvmRRPhjo49EPzW/81UplvP1Zbx29p1gdzgmG97o8W6omreYqJd47P5d2KaaLgoQPKLGER81rXdYDnq1Pts/jcSZ0w2hxtHo844/aIyGE3x/eo3zc5pG5wys4bRcok8war5TY8zs8Q2/nEjeR6DjzeRCMc5UQ82NvI3BVI57/oxEal5J/8hiDaHoEEIDToRYbDmKHHzBuAwFGPaPEDheb8KoFG2GbNBKti/AxV74KXFlIWDYkoxnAYcWqRc7S8AvJEfpOjdKtRCQTGVdaBsgpTSLBJdRXWubYeYDWKwzsTpNC/6XykInTv0vN9dh7DzaOksKIwoeV+P0MCgM19/CcqI3+AZUxh+gsYZVtn7/9f/DEb+CMxta30BFmj61IlEjMzMJ1HLbZAK07bOhU=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLNqFXItJ3RbZ6TBCXi4+Q/K349GMydi3Ip7CAl8nndQnQhrlEtiUKs+G57kY8f3Ids/IHZaEnukfdCepLRaHwc=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIJCI/+JiZSooKMR+siy1y/3UxbozRquDkqVQNA/hId0e", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_is_chroot": false, "ansible_iscsi_iqn": "", "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_fibre_channel_wwn": [], "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_fips": false, "ansible_apparmor": {"status": "disabled"}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "29", "second": "37", "epoch": "1795433377", "epoch_int": "1795433377", "date": "2026-11-23", "time": "11:29:37", "iso8601_micro": "2026-11-23T11:29:37.614076Z", "iso8601": "2026-11-23T11:29:37Z", "iso8601_basic": "20261123T112937614076", "iso8601_basic_short": "20261123T112937", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_interfaces": ["eth1", "lo", "eth0"], "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:4b:3b:1c", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.11", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe4b:3b1c", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:3290:b027:f53e:e10c", "prefix": "64", "scope": "global"}, {"address": "fe80::a8ac:92eb:1487:8429", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:3290:b027:f53e:e10c", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.11", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe4b:3b1c", "fd17:625c:f037:2:3290:b027:f53e:e10c", "fe80::a8ac:92eb:1487:8429"], "ansible_lsb": {}, "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-vgqpbeosvbtzusygwlzvthiuhmgfgkhg ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_local": {}, "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 382, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 557, "free": 382}, "nocache": {"free": 647, "used": 292}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-268f717a-3423-4938-b9fb-d431e65f2cb5", "ansible_product_uuid": "7a718f26-2334-3849-b9fb-d431e65f2cb5", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB7fa6071f", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part2"], "sda3": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part3"], "sda4": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part4"], "sda1": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482-part1"], "sda": ["ata-VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-0ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-1ATA_VBOX_HARDDISK_VB7fa6071f-07baa482", "scsi-SATA_VBOX_HARDDISK_VB7fa6071f-07baa482"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 163, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18308358144, "block_size": 4096, "block_total": 4789504, "block_available": 4469814, "block_used": 319690, "inode_total": 9611776, "inode_available": 9570274, "inode_used": 41502, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_service_mgr": "systemd", "ansible_pkg_mgr": "dnf", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433376.5080397-379584-15083884147925/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [ns02]
META: ran handlers

TASK [copy named.conf] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:36
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492 `" && echo ansible-tmp-1795433378.2381597-379616-150593123424492="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433378.2381597-379616-150593123424492=/home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpildopb1q TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpildopb1q /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ogoygcoxzmqepbwqeuosxkciboxepdbl ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/named.conf", "mode": "0640", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 25, "size": 1722, "inode": 33866908, "dev": 2052, "nlink": 1, "atime": 1794467949.0, "mtime": 1794467949.0, "ctime": 1795433362.9308825, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": false, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "named", "checksum": "8949ffe0fed7ceed49a8b98f136655b95cc4e7ea", "mimetype": "text/plain", "charset": "us-ascii", "version": "4024001431", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/named.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/slave-named.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/slave-named.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmptm3imuxb TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmptm3imuxb /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-udkpcwokdvrqiugspnyvwkuolniobyts ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"dest": "/etc/named.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source", "md5sum": "da69f248c4efe86a70f4ae1b2b663697", "checksum": "481f2d7cf752f91a875255e05c2fbaba89471f23", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0640", "state": "file", "secontext": "system_u:object_r:named_conf_t:s0", "size": 1652, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source", "dest": "/etc/named.conf", "owner": "root", "group": "named", "mode": "0640", "_original_basename": "slave-named.conf", "follow": false, "checksum": "481f2d7cf752f91a875255e05c2fbaba89471f23", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns02] => {
    "changed": true,
    "checksum": "481f2d7cf752f91a875255e05c2fbaba89471f23",
    "dest": "/etc/named.conf",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "slave-named.conf",
            "attributes": null,
            "backup": false,
            "checksum": "481f2d7cf752f91a875255e05c2fbaba89471f23",
            "content": null,
            "dest": "/etc/named.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0640",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "da69f248c4efe86a70f4ae1b2b663697",
    "mode": "0640",
    "owner": "root",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 1652,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433378.2381597-379616-150593123424492/source",
    "state": "file",
    "uid": 0
}

TASK [copy resolv.conf to the servers] *****************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:38
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876 `" && echo ansible-tmp-1795433379.9607453-379671-233035175000876="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433379.9607453-379671-233035175000876=/home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmp5vqfe260 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmp5vqfe260 /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-lhfmefgpxrxfelazksvdllofydcsyhrm ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/resolv.conf", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 50, "inode": 33866905, "dev": 2052, "nlink": 1, "atime": 1795433324.6004057, "mtime": 1795433314.5915036, "ctime": 1795433314.5994995, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "ee0f0edfdf05764de96b51aff44b8dcd4d07cd7a", "mimetype": "text/plain", "charset": "us-ascii", "version": "1364471830", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/resolv.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/servers-resolv.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/servers-resolv.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmp14qead6f TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmp14qead6f /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-iaembymqjtifrkuktofawhozsrsthgqb ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/resolv.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source", "md5sum": "436cae9d2c09dfac81564ad5085f1655", "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:net_conf_t:s0", "size": 51, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source", "dest": "/etc/resolv.conf", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "servers-resolv.conf", "follow": false, "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns02] => {
    "changed": true,
    "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5",
    "dest": "/etc/resolv.conf",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "servers-resolv.conf",
            "attributes": null,
            "backup": false,
            "checksum": "36539f1fdb23fc426b935322d3c4db792c2466b5",
            "content": null,
            "dest": "/etc/resolv.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "436cae9d2c09dfac81564ad5085f1655",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:net_conf_t:s0",
    "size": 51,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433379.9607453-379671-233035175000876/source",
    "state": "file",
    "uid": 0
}

TASK [set /etc/named permissions] **********************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:41
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762 `" && echo ansible-tmp-1795433381.675292-379726-273739006445762="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433381.675292-379726-273739006445762=/home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/file.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpeessjsvr TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/AnsiballZ_file.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpeessjsvr /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/AnsiballZ_file.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/AnsiballZ_file.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-zboysvrlwaphigxxaesxczlbdrkfxyqg ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/AnsiballZ_file.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"path": "/etc/named", "changed": true, "diff": {"before": {"path": "/etc/named", "mode": "0750"}, "after": {"path": "/etc/named", "mode": "0670"}}, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0670", "state": "directory", "secontext": "system_u:object_r:named_conf_t:s0", "size": 6, "invocation": {"module_args": {"path": "/etc/named", "owner": "root", "group": "named", "mode": "0670", "recurse": false, "force": false, "follow": true, "modification_time_format": "%Y%m%d%H%M.%S", "access_time_format": "%Y%m%d%H%M.%S", "unsafe_writes": false, "state": "directory", "_original_basename": null, "_diff_peek": null, "src": null, "modification_time": null, "access_time": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433381.675292-379726-273739006445762/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns02] => {
    "changed": true,
    "diff": {
        "after": {
            "mode": "0670",
            "path": "/etc/named"
        },
        "before": {
            "mode": "0750",
            "path": "/etc/named"
        }
    },
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_diff_peek": null,
            "_original_basename": null,
            "access_time": null,
            "access_time_format": "%Y%m%d%H%M.%S",
            "attributes": null,
            "follow": true,
            "force": false,
            "group": "named",
            "mode": "0670",
            "modification_time": null,
            "modification_time_format": "%Y%m%d%H%M.%S",
            "owner": "root",
            "path": "/etc/named",
            "recurse": false,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": null,
            "state": "directory",
            "unsafe_writes": false
        }
    },
    "mode": "0670",
    "owner": "root",
    "path": "/etc/named",
    "secontext": "system_u:object_r:named_conf_t:s0",
    "size": 6,
    "state": "directory",
    "uid": 0
}

TASK [ensure named is running and enabled] *************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:44
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576 `" && echo ansible-tmp-1795433382.7312062-379755-13585826597576="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433382.7312062-379755-13585826597576=/home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/systemd.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpgw1jkyzq TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/AnsiballZ_systemd.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-379397fjl1ufhe/tmpgw1jkyzq /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/AnsiballZ_systemd.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/AnsiballZ_systemd.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-byiqrzdcxshnxjmuljrntxpndfovkalf ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/AnsiballZ_systemd.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"name": "named", "changed": true, "status": {"Type": "forking", "ExitType": "main", "Restart": "no", "PIDFile": "/run/named/named.pid", "NotifyAccess": "none", "RestartUSec": "100ms", "TimeoutStartUSec": "1min 30s", "TimeoutStopUSec": "1min 30s", "TimeoutAbortUSec": "1min 30s", "TimeoutStartFailureMode": "terminate", "TimeoutStopFailureMode": "terminate", "RuntimeMaxUSec": "infinity", "RuntimeRandomizedExtraUSec": "0", "WatchdogUSec": "infinity", "WatchdogTimestampMonotonic": "0", "RootDirectoryStartOnly": "no", "RemainAfterExit": "no", "GuessMainPID": "yes", "MainPID": "0", "ControlPID": "0", "FileDescriptorStoreMax": "0", "NFileDescriptorStore": "0", "StatusErrno": "0", "Result": "success", "ReloadResult": "success", "CleanResult": "success", "UID": "[not set]", "GID": "[not set]", "NRestarts": "0", "OOMPolicy": "stop", "ReloadSignal": "1", "ExecMainStartTimestampMonotonic": "0", "ExecMainExitTimestampMonotonic": "0", "ExecMainPID": "0", "ExecMainCode": "0", "ExecMainStatus": "0", "ExecStartPre": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \\"$DISABLE_ZONE_CHECKING\\" == \\"yes\\" ]; then /usr/sbin/named-checkconf -z \\"$NAMEDCONF\\"; else echo \\"Checking of zone files is disabled\\"; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStartPreEx": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \\"$DISABLE_ZONE_CHECKING\\" == \\"yes\\" ]; then /usr/sbin/named-checkconf -z \\"$NAMEDCONF\\"; else echo \\"Checking of zone files is disabled\\"; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStart": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStartEx": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecReload": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecReloadEx": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStop": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "ExecStopEx": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }", "Slice": "system.slice", "ControlGroupId": "0", "MemoryCurrent": "[not set]", "MemoryPeak": "18446744073709551615", "MemoryAvailable": "infinity", "CPUUsageNSec": "[not set]", "TasksCurrent": "[not set]", "IPIngressBytes": "[no data]", "IPIngressPackets": "[no data]", "IPEgressBytes": "[no data]", "IPEgressPackets": "[no data]", "IOReadBytes": "18446744073709551615", "IOReadOperations": "18446744073709551615", "IOWriteBytes": "18446744073709551615", "IOWriteOperations": "18446744073709551615", "Delegate": "no", "CPUAccounting": "yes", "CPUWeight": "[not set]", "StartupCPUWeight": "[not set]", "CPUShares": "[not set]", "StartupCPUShares": "[not set]", "CPUQuotaPerSecUSec": "infinity", "CPUQuotaPeriodUSec": "infinity", "IOAccounting": "no", "IOWeight": "[not set]", "StartupIOWeight": "[not set]", "BlockIOAccounting": "no", "BlockIOWeight": "[not set]", "StartupBlockIOWeight": "[not set]", "MemoryAccounting": "yes", "DefaultMemoryLow": "0", "DefaultMemoryMin": "0", "MemoryMin": "0", "MemoryLow": "0", "MemoryHigh": "infinity", "MemoryMax": "infinity", "MemorySwapMax": "infinity", "MemoryLimit": "infinity", "DevicePolicy": "auto", "TasksAccounting": "yes", "TasksMax": "5464", "IPAccounting": "no", "ManagedOOMSwap": "auto", "ManagedOOMMemoryPressure": "auto", "ManagedOOMMemoryPressureLimit": "0", "ManagedOOMPreference": "none", "Environment": "NAMEDCONF=/etc/named.conf KRB5_KTNAME=/etc/named.keytab", "EnvironmentFiles": "/etc/sysconfig/named (ignore_errors=yes)", "UMask": "0022", "LimitCPU": "infinity", "LimitCPUSoft": "infinity", "LimitFSIZE": "infinity", "LimitFSIZESoft": "infinity", "LimitDATA": "infinity", "LimitDATASoft": "infinity", "LimitSTACK": "infinity", "LimitSTACKSoft": "8388608", "LimitCORE": "infinity", "LimitCORESoft": "infinity", "LimitRSS": "infinity", "LimitRSSSoft": "infinity", "LimitNOFILE": "524288", "LimitNOFILESoft": "1024", "LimitAS": "infinity", "LimitASSoft": "infinity", "LimitNPROC": "3415", "LimitNPROCSoft": "3415", "LimitMEMLOCK": "8388608", "LimitMEMLOCKSoft": "8388608", "LimitLOCKS": "infinity", "LimitLOCKSSoft": "infinity", "LimitSIGPENDING": "3415", "LimitSIGPENDINGSoft": "3415", "LimitMSGQUEUE": "819200", "LimitMSGQUEUESoft": "819200", "LimitNICE": "0", "LimitNICESoft": "0", "LimitRTPRIO": "0", "LimitRTPRIOSoft": "0", "LimitRTTIME": "infinity", "LimitRTTIMESoft": "infinity", "OOMScoreAdjust": "0", "CoredumpFilter": "0x33", "Nice": "0", "IOSchedulingClass": "2", "IOSchedulingPriority": "4", "CPUSchedulingPolicy": "0", "CPUSchedulingPriority": "0", "CPUAffinityFromNUMA": "no", "NUMAPolicy": "n/a", "TimerSlackNSec": "50000", "CPUSchedulingResetOnFork": "no", "NonBlocking": "no", "StandardInput": "null", "StandardOutput": "journal", "StandardError": "inherit", "TTYReset": "no", "TTYVHangup": "no", "TTYVTDisallocate": "no", "SyslogPriority": "30", "SyslogLevelPrefix": "yes", "SyslogLevel": "6", "SyslogFacility": "3", "LogLevelMax": "-1", "LogRateLimitIntervalUSec": "0", "LogRateLimitBurst": "0", "SecureBits": "0", "CapabilityBoundingSet": "cap_chown cap_dac_override cap_dac_read_search cap_fowner cap_fsetid cap_kill cap_setgid cap_setuid cap_setpcap cap_linux_immutable cap_net_bind_service cap_net_broadcast cap_net_admin cap_net_raw cap_ipc_lock cap_ipc_owner cap_sys_module cap_sys_rawio cap_sys_chroot cap_sys_ptrace cap_sys_pacct cap_sys_admin cap_sys_boot cap_sys_nice cap_sys_resource cap_sys_time cap_sys_tty_config cap_mknod cap_lease cap_audit_write cap_audit_control cap_setfcap cap_mac_override cap_mac_admin cap_syslog cap_wake_alarm cap_block_suspend cap_audit_read cap_perfmon cap_bpf cap_checkpoint_restore", "DynamicUser": "no", "RemoveIPC": "no", "PrivateTmp": "yes", "PrivateDevices": "no", "ProtectClock": "no", "ProtectKernelTunables": "no", "ProtectKernelModules": "no", "ProtectKernelLogs": "no", "ProtectControlGroups": "no", "PrivateNetwork": "no", "PrivateUsers": "no", "PrivateMounts": "no", "PrivateIPC": "no", "ProtectHome": "no", "ProtectSystem": "no", "SameProcessGroup": "no", "UtmpMode": "init", "IgnoreSIGPIPE": "yes", "NoNewPrivileges": "no", "SystemCallErrorNumber": "2147483646", "LockPersonality": "no", "RuntimeDirectoryPreserve": "no", "RuntimeDirectoryMode": "0755", "StateDirectoryMode": "0755", "CacheDirectoryMode": "0755", "LogsDirectoryMode": "0755", "ConfigurationDirectoryMode": "0755", "TimeoutCleanUSec": "infinity", "MemoryDenyWriteExecute": "no", "RestrictRealtime": "no", "RestrictSUIDSGID": "no", "RestrictNamespaces": "no", "MountAPIVFS": "no", "KeyringMode": "private", "ProtectProc": "default", "ProcSubset": "all", "ProtectHostname": "no", "KillMode": "control-group", "KillSignal": "15", "RestartKillSignal": "15", "FinalKillSignal": "9", "SendSIGKILL": "yes", "SendSIGHUP": "no", "WatchdogSignal": "6", "Id": "named.service", "Names": "named.service", "Requires": "sysinit.target system.slice -.mount", "Wants": "nss-lookup.target named-setup-rndc.service", "Conflicts": "shutdown.target", "Before": "nss-lookup.target shutdown.target", "After": "named-setup-rndc.service systemd-tmpfiles-setup.service sysinit.target network.target tmp.mount system.slice basic.target -.mount systemd-journald.socket", "RequiresMountsFor": "/var/tmp", "Description": "Berkeley Internet Name Domain (DNS)", "AccessSELinuxContext": "system_u:object_r:named_unit_file_t:s0", "LoadState": "loaded", "ActiveState": "inactive", "FreezerState": "running", "SubState": "dead", "FragmentPath": "/usr/lib/systemd/system/named.service", "UnitFileState": "disabled", "UnitFilePreset": "disabled", "StateChangeTimestampMonotonic": "0", "InactiveExitTimestampMonotonic": "0", "ActiveEnterTimestampMonotonic": "0", "ActiveExitTimestampMonotonic": "0", "InactiveEnterTimestampMonotonic": "0", "CanStart": "yes", "CanStop": "yes", "CanReload": "yes", "CanIsolate": "no", "CanFreeze": "yes", "StopWhenUnneeded": "no", "RefuseManualStart": "no", "RefuseManualStop": "no", "AllowIsolate": "no", "DefaultDependencies": "yes", "OnSuccessJobMode": "fail", "OnFailureJobMode": "replace", "IgnoreOnIsolate": "no", "NeedDaemonReload": "no", "JobTimeoutUSec": "infinity", "JobRunningTimeoutUSec": "infinity", "JobTimeoutAction": "none", "ConditionResult": "no", "AssertResult": "no", "ConditionTimestampMonotonic": "0", "AssertTimestampMonotonic": "0", "Transient": "no", "Perpetual": "no", "StartLimitIntervalUSec": "10s", "StartLimitBurst": "5", "StartLimitAction": "none", "FailureAction": "none", "SuccessAction": "none", "CollectMode": "inactive"}, "enabled": true, "state": "started", "invocation": {"module_args": {"name": "named", "state": "restarted", "enabled": true, "daemon_reload": false, "daemon_reexec": false, "scope": "system", "no_block": false, "force": null, "masked": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2200 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/17d6e21220"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433382.7312062-379755-13585826597576/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [ns02] => {
    "changed": true,
    "enabled": true,
    "invocation": {
        "module_args": {
            "daemon_reexec": false,
            "daemon_reload": false,
            "enabled": true,
            "force": null,
            "masked": null,
            "name": "named",
            "no_block": false,
            "scope": "system",
            "state": "restarted"
        }
    },
    "name": "named",
    "state": "started",
    "status": {
        "AccessSELinuxContext": "system_u:object_r:named_unit_file_t:s0",
        "ActiveEnterTimestampMonotonic": "0",
        "ActiveExitTimestampMonotonic": "0",
        "ActiveState": "inactive",
        "After": "named-setup-rndc.service systemd-tmpfiles-setup.service sysinit.target network.target tmp.mount system.slice basic.target -.mount systemd-journald.socket",
        "AllowIsolate": "no",
        "AssertResult": "no",
        "AssertTimestampMonotonic": "0",
        "Before": "nss-lookup.target shutdown.target",
        "BlockIOAccounting": "no",
        "BlockIOWeight": "[not set]",
        "CPUAccounting": "yes",
        "CPUAffinityFromNUMA": "no",
        "CPUQuotaPerSecUSec": "infinity",
        "CPUQuotaPeriodUSec": "infinity",
        "CPUSchedulingPolicy": "0",
        "CPUSchedulingPriority": "0",
        "CPUSchedulingResetOnFork": "no",
        "CPUShares": "[not set]",
        "CPUUsageNSec": "[not set]",
        "CPUWeight": "[not set]",
        "CacheDirectoryMode": "0755",
        "CanFreeze": "yes",
        "CanIsolate": "no",
        "CanReload": "yes",
        "CanStart": "yes",
        "CanStop": "yes",
        "CapabilityBoundingSet": "cap_chown cap_dac_override cap_dac_read_search cap_fowner cap_fsetid cap_kill cap_setgid cap_setuid cap_setpcap cap_linux_immutable cap_net_bind_service cap_net_broadcast cap_net_admin cap_net_raw cap_ipc_lock cap_ipc_owner cap_sys_module cap_sys_rawio cap_sys_chroot cap_sys_ptrace cap_sys_pacct cap_sys_admin cap_sys_boot cap_sys_nice cap_sys_resource cap_sys_time cap_sys_tty_config cap_mknod cap_lease cap_audit_write cap_audit_control cap_setfcap cap_mac_override cap_mac_admin cap_syslog cap_wake_alarm cap_block_suspend cap_audit_read cap_perfmon cap_bpf cap_checkpoint_restore",
        "CleanResult": "success",
        "CollectMode": "inactive",
        "ConditionResult": "no",
        "ConditionTimestampMonotonic": "0",
        "ConfigurationDirectoryMode": "0755",
        "Conflicts": "shutdown.target",
        "ControlGroupId": "0",
        "ControlPID": "0",
        "CoredumpFilter": "0x33",
        "DefaultDependencies": "yes",
        "DefaultMemoryLow": "0",
        "DefaultMemoryMin": "0",
        "Delegate": "no",
        "Description": "Berkeley Internet Name Domain (DNS)",
        "DevicePolicy": "auto",
        "DynamicUser": "no",
        "Environment": "NAMEDCONF=/etc/named.conf KRB5_KTNAME=/etc/named.keytab",
        "EnvironmentFiles": "/etc/sysconfig/named (ignore_errors=yes)",
        "ExecMainCode": "0",
        "ExecMainExitTimestampMonotonic": "0",
        "ExecMainPID": "0",
        "ExecMainStartTimestampMonotonic": "0",
        "ExecMainStatus": "0",
        "ExecReload": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecReloadEx": "{ path=/bin/sh ; argv[]=/bin/sh -c if /usr/sbin/rndc null > /dev/null 2>&1; then /usr/sbin/rndc reload; else /bin/kill -HUP $MAINPID; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStart": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartEx": "{ path=/usr/sbin/named ; argv[]=/usr/sbin/named -u named -c ${NAMEDCONF} $OPTIONS ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartPre": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \"$DISABLE_ZONE_CHECKING\" == \"yes\" ]; then /usr/sbin/named-checkconf -z \"$NAMEDCONF\"; else echo \"Checking of zone files is disabled\"; fi ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStartPreEx": "{ path=/bin/bash ; argv[]=/bin/bash -c if [ ! \"$DISABLE_ZONE_CHECKING\" == \"yes\" ]; then /usr/sbin/named-checkconf -z \"$NAMEDCONF\"; else echo \"Checking of zone files is disabled\"; fi ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStop": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; ignore_errors=no ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExecStopEx": "{ path=/bin/sh ; argv[]=/bin/sh -c /usr/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM $MAINPID ; flags= ; start_time=[n/a] ; stop_time=[n/a] ; pid=0 ; code=(null) ; status=0/0 }",
        "ExitType": "main",
        "FailureAction": "none",
        "FileDescriptorStoreMax": "0",
        "FinalKillSignal": "9",
        "FragmentPath": "/usr/lib/systemd/system/named.service",
        "FreezerState": "running",
        "GID": "[not set]",
        "GuessMainPID": "yes",
        "IOAccounting": "no",
        "IOReadBytes": "18446744073709551615",
        "IOReadOperations": "18446744073709551615",
        "IOSchedulingClass": "2",
        "IOSchedulingPriority": "4",
        "IOWeight": "[not set]",
        "IOWriteBytes": "18446744073709551615",
        "IOWriteOperations": "18446744073709551615",
        "IPAccounting": "no",
        "IPEgressBytes": "[no data]",
        "IPEgressPackets": "[no data]",
        "IPIngressBytes": "[no data]",
        "IPIngressPackets": "[no data]",
        "Id": "named.service",
        "IgnoreOnIsolate": "no",
        "IgnoreSIGPIPE": "yes",
        "InactiveEnterTimestampMonotonic": "0",
        "InactiveExitTimestampMonotonic": "0",
        "JobRunningTimeoutUSec": "infinity",
        "JobTimeoutAction": "none",
        "JobTimeoutUSec": "infinity",
        "KeyringMode": "private",
        "KillMode": "control-group",
        "KillSignal": "15",
        "LimitAS": "infinity",
        "LimitASSoft": "infinity",
        "LimitCORE": "infinity",
        "LimitCORESoft": "infinity",
        "LimitCPU": "infinity",
        "LimitCPUSoft": "infinity",
        "LimitDATA": "infinity",
        "LimitDATASoft": "infinity",
        "LimitFSIZE": "infinity",
        "LimitFSIZESoft": "infinity",
        "LimitLOCKS": "infinity",
        "LimitLOCKSSoft": "infinity",
        "LimitMEMLOCK": "8388608",
        "LimitMEMLOCKSoft": "8388608",
        "LimitMSGQUEUE": "819200",
        "LimitMSGQUEUESoft": "819200",
        "LimitNICE": "0",
        "LimitNICESoft": "0",
        "LimitNOFILE": "524288",
        "LimitNOFILESoft": "1024",
        "LimitNPROC": "3415",
        "LimitNPROCSoft": "3415",
        "LimitRSS": "infinity",
        "LimitRSSSoft": "infinity",
        "LimitRTPRIO": "0",
        "LimitRTPRIOSoft": "0",
        "LimitRTTIME": "infinity",
        "LimitRTTIMESoft": "infinity",
        "LimitSIGPENDING": "3415",
        "LimitSIGPENDINGSoft": "3415",
        "LimitSTACK": "infinity",
        "LimitSTACKSoft": "8388608",
        "LoadState": "loaded",
        "LockPersonality": "no",
        "LogLevelMax": "-1",
        "LogRateLimitBurst": "0",
        "LogRateLimitIntervalUSec": "0",
        "LogsDirectoryMode": "0755",
        "MainPID": "0",
        "ManagedOOMMemoryPressure": "auto",
        "ManagedOOMMemoryPressureLimit": "0",
        "ManagedOOMPreference": "none",
        "ManagedOOMSwap": "auto",
        "MemoryAccounting": "yes",
        "MemoryAvailable": "infinity",
        "MemoryCurrent": "[not set]",
        "MemoryDenyWriteExecute": "no",
        "MemoryHigh": "infinity",
        "MemoryLimit": "infinity",
        "MemoryLow": "0",
        "MemoryMax": "infinity",
        "MemoryMin": "0",
        "MemoryPeak": "18446744073709551615",
        "MemorySwapMax": "infinity",
        "MountAPIVFS": "no",
        "NFileDescriptorStore": "0",
        "NRestarts": "0",
        "NUMAPolicy": "n/a",
        "Names": "named.service",
        "NeedDaemonReload": "no",
        "Nice": "0",
        "NoNewPrivileges": "no",
        "NonBlocking": "no",
        "NotifyAccess": "none",
        "OOMPolicy": "stop",
        "OOMScoreAdjust": "0",
        "OnFailureJobMode": "replace",
        "OnSuccessJobMode": "fail",
        "PIDFile": "/run/named/named.pid",
        "Perpetual": "no",
        "PrivateDevices": "no",
        "PrivateIPC": "no",
        "PrivateMounts": "no",
        "PrivateNetwork": "no",
        "PrivateTmp": "yes",
        "PrivateUsers": "no",
        "ProcSubset": "all",
        "ProtectClock": "no",
        "ProtectControlGroups": "no",
        "ProtectHome": "no",
        "ProtectHostname": "no",
        "ProtectKernelLogs": "no",
        "ProtectKernelModules": "no",
        "ProtectKernelTunables": "no",
        "ProtectProc": "default",
        "ProtectSystem": "no",
        "RefuseManualStart": "no",
        "RefuseManualStop": "no",
        "ReloadResult": "success",
        "ReloadSignal": "1",
        "RemainAfterExit": "no",
        "RemoveIPC": "no",
        "Requires": "sysinit.target system.slice -.mount",
        "RequiresMountsFor": "/var/tmp",
        "Restart": "no",
        "RestartKillSignal": "15",
        "RestartUSec": "100ms",
        "RestrictNamespaces": "no",
        "RestrictRealtime": "no",
        "RestrictSUIDSGID": "no",
        "Result": "success",
        "RootDirectoryStartOnly": "no",
        "RuntimeDirectoryMode": "0755",
        "RuntimeDirectoryPreserve": "no",
        "RuntimeMaxUSec": "infinity",
        "RuntimeRandomizedExtraUSec": "0",
        "SameProcessGroup": "no",
        "SecureBits": "0",
        "SendSIGHUP": "no",
        "SendSIGKILL": "yes",
        "Slice": "system.slice",
        "StandardError": "inherit",
        "StandardInput": "null",
        "StandardOutput": "journal",
        "StartLimitAction": "none",
        "StartLimitBurst": "5",
        "StartLimitIntervalUSec": "10s",
        "StartupBlockIOWeight": "[not set]",
        "StartupCPUShares": "[not set]",
        "StartupCPUWeight": "[not set]",
        "StartupIOWeight": "[not set]",
        "StateChangeTimestampMonotonic": "0",
        "StateDirectoryMode": "0755",
        "StatusErrno": "0",
        "StopWhenUnneeded": "no",
        "SubState": "dead",
        "SuccessAction": "none",
        "SyslogFacility": "3",
        "SyslogLevel": "6",
        "SyslogLevelPrefix": "yes",
        "SyslogPriority": "30",
        "SystemCallErrorNumber": "2147483646",
        "TTYReset": "no",
        "TTYVHangup": "no",
        "TTYVTDisallocate": "no",
        "TasksAccounting": "yes",
        "TasksCurrent": "[not set]",
        "TasksMax": "5464",
        "TimeoutAbortUSec": "1min 30s",
        "TimeoutCleanUSec": "infinity",
        "TimeoutStartFailureMode": "terminate",
        "TimeoutStartUSec": "1min 30s",
        "TimeoutStopFailureMode": "terminate",
        "TimeoutStopUSec": "1min 30s",
        "TimerSlackNSec": "50000",
        "Transient": "no",
        "Type": "forking",
        "UID": "[not set]",
        "UMask": "0022",
        "UnitFilePreset": "disabled",
        "UnitFileState": "disabled",
        "UtmpMode": "init",
        "Wants": "nss-lookup.target named-setup-rndc.service",
        "WatchdogSignal": "6",
        "WatchdogTimestampMonotonic": "0",
        "WatchdogUSec": "infinity"
    }
}
META: ran handlers
META: ran handlers
[WARNING]: Could not match supplied host pattern, ignoring: client
[WARNING]: Could not match supplied host pattern, ignoring: client2

PLAY [client, client2] *********************************************************
skipping: no hosts matched

PLAY RECAP *********************************************************************
ns02                       : ok=8    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

==> client: Importing base box 'almalinux9-stand-vb'...
==> client: Matching MAC address for NAT networking...
==> client: Setting the name of the VM: vagrant-bind_client_1795433415607_77906
==> client: Fixed port collision for 22 => 2222. Now on port 2201.
==> client: Clearing any previously set network interfaces...
==> client: Preparing network interfaces based on configuration...
    client: Adapter 1: nat
    client: Adapter 2: intnet
==> client: Forwarding ports...
    client: 22 (guest) => 2201 (host) (adapter 1)
==> client: Running 'pre-boot' VM customizations...
==> client: Booting VM...
==> client: Waiting for machine to boot. This may take a few minutes...
    client: SSH address: 127.0.0.1:2201
    client: SSH username: vagrant
    client: SSH auth method: private key
    client: Warning: Connection reset. Retrying...
    client: Warning: Connection reset. Retrying...
    client: Warning: Remote connection disconnect. Retrying...
    client: Warning: Connection reset. Retrying...
    client: Warning: Remote connection disconnect. Retrying...
    client: Warning: Connection reset. Retrying...
    client: Warning: Connection reset. Retrying...
    client: Warning: Connection reset. Retrying...
    client: Warning: Remote connection disconnect. Retrying...
    client: 
    client: Vagrant insecure key detected. Vagrant will automatically replace
    client: this with a newly generated keypair for better security.
    client: 
    client: Inserting generated public key within guest...
    client: Removing insecure key from the guest if it's present...
    client: Key inserted! Disconnecting and reconnecting using new SSH key...
==> client: Machine booted and ready!
==> client: Checking for guest additions in VM...
    client: The guest additions on this VM do not match the installed version of
    client: VirtualBox! In most cases this is fine, but in rare cases it can
    client: prevent things such as shared folders from working properly. If you see
    client: shared folder errors, please make sure the guest additions within the
    client: virtual machine match the version of VirtualBox you have installed on
    client: your host and reload your VM.
    client: 
    client: Guest Additions Version: 7.2.16
    client: VirtualBox Version: 7.1
==> client: Setting hostname...
==> client: Configuring and enabling network interfaces...
==> client: Mounting shared folders...
    client: /home/admin_insta11/vagrant-bind => /vagrant
==> client: Running provisioner: ansible...
    client: Running ansible-playbook...
PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --connection=ssh --timeout=30 --limit="client" --inventory-file=/home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory -vvv provisioning/playbook.yml
ansible-playbook [core 2.13.13]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/admin_insta11/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.8/site-packages/ansible
  ansible collection location = /home/admin_insta11/.ansible/collections:/usr/share/ansible/collections
  executable location = /bin/ansible-playbook
  python version = 3.8.20 (default, Sep  9 2024, 00:00:00) [GCC 11.4.1 20230605 (Red Soft 11.4.0-1)]
  jinja version = 3.1.3
  libyaml = True
Using /etc/ansible/ansible.cfg as config file
host_list declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
script declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
auto declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
Parsed /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory inventory source with ini plugin
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: playbook.yml *********************************************************
4 plays in provisioning/playbook.yml

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:2
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b"Warning: Permanently added '[127.0.0.1]:2201' (ED25519) to the list of known hosts.\r\n")
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357 `" && echo ansible-tmp-1795433534.828568-386346-109203538219357="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433534.828568-386346-109203538219357=/home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357\n', b'')
<client> Attempting python interpreter discovery
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo PLATFORM; uname; echo FOUND; command -v '"'"'"'"'"'"'"'"'python3.10'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.9'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.8'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.6'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.5'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python3'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/libexec/platform-python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python2.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python'"'"'"'"'"'"'"'"'; echo ENDFOUND && sleep 0'"'"''
<127.0.0.1> (0, b'PLATFORM\nLinux\nFOUND\n/usr/bin/python3.9\n/usr/bin/python3\n/usr/libexec/platform-python\nENDFOUND\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'/usr/bin/python3.9 && sleep 0'"'"''
<127.0.0.1> (0, b'{"platform_dist_result": [], "osrelease_content": "NAME=\\"AlmaLinux\\"\\nVERSION=\\"9.8 (Olive Jaguar)\\"\\nID=\\"almalinux\\"\\nID_LIKE=\\"rhel centos fedora\\"\\nVERSION_ID=\\"9.8\\"\\nPLATFORM_ID=\\"platform:el9\\"\\nPRETTY_NAME=\\"AlmaLinux 9.8 (Olive Jaguar)\\"\\nANSI_COLOR=\\"0;34\\"\\nLOGO=\\"fedora-logo-icon\\"\\nCPE_NAME=\\"cpe:/o:almalinux:almalinux:9::baseos\\"\\nHOME_URL=\\"https://almalinux.org/\\"\\nDOCUMENTATION_URL=\\"https://wiki.almalinux.org/\\"\\nBUG_REPORT_URL=\\"https://bugs.almalinux.org/\\"\\n\\nALMALINUX_MANTISBT_PROJECT=\\"AlmaLinux-9\\"\\nALMALINUX_MANTISBT_PROJECT_VERSION=\\"9.8\\"\\nREDHAT_SUPPORT_PRODUCT=\\"AlmaLinux\\"\\nREDHAT_SUPPORT_PRODUCT_VERSION=\\"9.8\\"\\nSUPPORT_END=2032-06-01\\n"}\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmppyvxfj4c TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmppyvxfj4c /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ufacjczhyswpepnlvqpqgseqjvtusyjx ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"ansible_facts": {"ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQCoTZEiFV4eLt9n96b4zWC35CllZlikTCeghJKf2Hnxn4GkOx1LO4jN3I8jfDTt/HP+4Wql5LjfpiXAB/yePap+//xzxwT/mDNMesASISI41qMNB1NrAGZV6WGGRhVc6Z2xUpZyk+JlBmnlWlqW3j9sTgbTXPSi4wrWDxIh6W3s6+BPrPmMGwABwVCTAbUVqvhWyA5MFWx3haEerFD4xzm7gSMCIn9f39u+wWHJAgkFT/z7+2RSzWgLlbxNBkffr++uBwzqRH1xUZiAmWadgpecQDAjKT5BsfxgOGV24UKeJSCHptPbDdiwYuUh7YO0luYizQXGmpkxOmzwXhm3yU4dDG0iwEaVgeOAAcSrr6rT3qPArpPG30KIvjl/AtqXBhMAcBiDbKpgQkRfFq6HSYXJjL4RPA/8wyyxf9c197IUJnr5/8ogkYDYbLcHHTu6EjDv9+jOkUoWQeilCazCdTImkClo/f0vHXvfjgrPi5zamBkzU8FmOOcv7YwqF62ajFc=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOopKkJYFdJYlzycDsboW8LAAkCsU3G5lAO98x2aJtvw9iRNVz5ObpyGTSnn5dtfPww5iK12q6of6a1Q/E2I78I=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIHxyyB/sSk6UZMferfjIRltyQNYhk/fRSSzMRaAoJ0Qv", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "client", "ansible_hostname": "client", "ansible_nodename": "client", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "23e639c246d64998865bf013f89e0bf8", "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "32", "second": "16", "epoch": "1795433536", "epoch_int": "1795433536", "date": "2026-11-23", "time": "11:32:16", "iso8601_micro": "2026-11-23T11:32:16.710504Z", "iso8601": "2026-11-23T11:32:16Z", "iso8601_basic": "20261123T113216710504", "iso8601_basic_short": "20261123T113216", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-ufacjczhyswpepnlvqpqgseqjvtusyjx ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_apparmor": {"status": "disabled"}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_is_chroot": false, "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_local": {}, "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_fibre_channel_wwn": [], "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_fips": false, "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_lsb": {}, "ansible_iscsi_iqn": "", "ansible_interfaces": ["lo", "eth0", "eth1"], "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:20:90:45", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.15", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe20:9045", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:2079:cbe7:fae3:3756", "prefix": "64", "scope": "global"}, {"address": "fe80::5348:2850:35cd:1607", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:2079:cbe7:fae3:3756", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.15", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe20:9045", "fd17:625c:f037:2:2079:cbe7:fae3:3756", "fe80::5348:2850:35cd:1607"], "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 590, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 349, "free": 590}, "nocache": {"free": 716, "used": 223}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-3cd1eb26-7c94-4818-a65e-7a2f8257898c", "ansible_product_uuid": "26ebd13c-947c-1848-a65e-7a2f8257898c", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VBdcfb3eee", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2"], "sda4": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4"], "sda3": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3"], "sda1": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1"], "sda": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7"]}, "uuids": {"sda2": ["CFBF-3084"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 110, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18366840832, "block_size": 4096, "block_total": 4789504, "block_available": 4484092, "block_used": 305412, "inode_total": 9611776, "inode_available": 9570688, "inode_used": 41088, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_service_mgr": "systemd", "ansible_pkg_mgr": "dnf", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433534.828568-386346-109203538219357/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client]
META: ran handlers

TASK [install packages] ********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:5
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759 `" && echo ansible-tmp-1795433537.5633168-386391-73207926869759="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433537.5633168-386391-73207926869759=/home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp_z31tcbn TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp_z31tcbn /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ipcxczerdwkysdimdbmfabalehwhjlqc ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "", "changed": true, "results": ["Installed: fstrm-0.6.1-3.el9.x86_64", "Installed: policycoreutils-python-utils-3.6-9.el9.noarch", "Installed: python3-policycoreutils-3.6-9.el9.noarch", "Installed: python3-ply-3.11-14.el9.noarch", "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch", "Installed: policycoreutils-3.6-9.el9.x86_64", "Installed: bind-32:9.16.50-12.el9_9.1.x86_64", "Installed: libmaxminddb-1.5.2-4.el9.x86_64", "Installed: libuv-1:1.42.0-2.el9_4.x86_64", "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64", "Removed: policycoreutils-3.6-5.el9.x86_64", "Removed: python3-policycoreutils-3.6-5.el9.noarch"], "rc": 0, "invocation": {"module_args": {"name": ["bind"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433537.5633168-386391-73207926869759/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client] => (item=bind) => {
    "ansible_loop_var": "item",
    "changed": true,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind",
    "msg": "",
    "rc": 0,
    "results": [
        "Installed: fstrm-0.6.1-3.el9.x86_64",
        "Installed: policycoreutils-python-utils-3.6-9.el9.noarch",
        "Installed: python3-policycoreutils-3.6-9.el9.noarch",
        "Installed: python3-ply-3.11-14.el9.noarch",
        "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch",
        "Installed: policycoreutils-3.6-9.el9.x86_64",
        "Installed: bind-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: libmaxminddb-1.5.2-4.el9.x86_64",
        "Installed: libuv-1:1.42.0-2.el9_4.x86_64",
        "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Removed: policycoreutils-3.6-5.el9.x86_64",
        "Removed: python3-policycoreutils-3.6-5.el9.noarch"
    ]
}
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746 `" && echo ansible-tmp-1795433584.026098-386391-72302058898746="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433584.026098-386391-72302058898746=/home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp62lby74e TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp62lby74e /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-fdrjmmovcxwvriifiyxijedqcttldtim ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "Nothing to do", "changed": false, "results": [], "rc": 0, "invocation": {"module_args": {"name": ["bind-utils"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433584.026098-386391-72302058898746/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client] => (item=bind-utils) => {
    "ansible_loop_var": "item",
    "changed": false,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind-utils"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind-utils",
    "msg": "Nothing to do",
    "rc": 0,
    "results": []
}

TASK [copy transferkey to all servers and the client] **************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:12
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742 `" && echo ansible-tmp-1795433586.2874434-386450-26156676853742="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433586.2874434-386450-26156676853742=/home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpebvcgjk0 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpebvcgjk0 /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-lqfbxzwetwkcjdollgtejzenyrtkhspu ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named.zonetransfer.key", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp6c8ex8o4 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp6c8ex8o4 /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ezocodomkkuevsbbxumoferhrsolcwfp ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named.zonetransfer.key", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source", "md5sum": "15ccf7d7d6ea11384de2901045af4d02", "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 91, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source", "dest": "/etc/named.zonetransfer.key", "owner": "root", "group": "named", "mode": "0644", "_original_basename": "named.zonetransfer.key", "follow": false, "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client] => {
    "changed": true,
    "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
    "dest": "/etc/named.zonetransfer.key",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.zonetransfer.key",
            "attributes": null,
            "backup": false,
            "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
            "content": null,
            "dest": "/etc/named.zonetransfer.key",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "15ccf7d7d6ea11384de2901045af4d02",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 91,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433586.2874434-386450-26156676853742/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY [ns01] ********************************************************************
skipping: no hosts matched

PLAY [ns02] ********************************************************************
skipping: no hosts matched
[WARNING]: Could not match supplied host pattern, ignoring: client2

PLAY [client, client2] *********************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:47
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037 `" && echo ansible-tmp-1795433588.2500794-386514-200568188454037="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433588.2500794-386514-200568188454037=/home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpsrfic0hl TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpsrfic0hl /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-hulrwbkofmifykcdtexijuguprfowmoo ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"ansible_facts": {"ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQCoTZEiFV4eLt9n96b4zWC35CllZlikTCeghJKf2Hnxn4GkOx1LO4jN3I8jfDTt/HP+4Wql5LjfpiXAB/yePap+//xzxwT/mDNMesASISI41qMNB1NrAGZV6WGGRhVc6Z2xUpZyk+JlBmnlWlqW3j9sTgbTXPSi4wrWDxIh6W3s6+BPrPmMGwABwVCTAbUVqvhWyA5MFWx3haEerFD4xzm7gSMCIn9f39u+wWHJAgkFT/z7+2RSzWgLlbxNBkffr++uBwzqRH1xUZiAmWadgpecQDAjKT5BsfxgOGV24UKeJSCHptPbDdiwYuUh7YO0luYizQXGmpkxOmzwXhm3yU4dDG0iwEaVgeOAAcSrr6rT3qPArpPG30KIvjl/AtqXBhMAcBiDbKpgQkRfFq6HSYXJjL4RPA/8wyyxf9c197IUJnr5/8ogkYDYbLcHHTu6EjDv9+jOkUoWQeilCazCdTImkClo/f0vHXvfjgrPi5zamBkzU8FmOOcv7YwqF62ajFc=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOopKkJYFdJYlzycDsboW8LAAkCsU3G5lAO98x2aJtvw9iRNVz5ObpyGTSnn5dtfPww5iK12q6of6a1Q/E2I78I=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIHxyyB/sSk6UZMferfjIRltyQNYhk/fRSSzMRaAoJ0Qv", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "client", "ansible_hostname": "client", "ansible_nodename": "client", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "23e639c246d64998865bf013f89e0bf8", "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_local": {}, "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_is_chroot": false, "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_iscsi_iqn": "", "ansible_fips": false, "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-hulrwbkofmifykcdtexijuguprfowmoo ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "33", "second": "09", "epoch": "1795433589", "epoch_int": "1795433589", "date": "2026-11-23", "time": "11:33:09", "iso8601_micro": "2026-11-23T11:33:09.072532Z", "iso8601": "2026-11-23T11:33:09Z", "iso8601_basic": "20261123T113309072532", "iso8601_basic_short": "20261123T113309", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_apparmor": {"status": "disabled"}, "ansible_lsb": {}, "ansible_fibre_channel_wwn": [], "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 388, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 551, "free": 388}, "nocache": {"free": 653, "used": 286}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-3cd1eb26-7c94-4818-a65e-7a2f8257898c", "ansible_product_uuid": "26ebd13c-947c-1848-a65e-7a2f8257898c", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VBdcfb3eee", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part2"], "sda4": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part4"], "sda3": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part3"], "sda1": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7-part1"], "sda": ["ata-VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-0ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-1ATA_VBOX_HARDDISK_VBdcfb3eee-988742b7", "scsi-SATA_VBOX_HARDDISK_VBdcfb3eee-988742b7"]}, "uuids": {"sda2": ["CFBF-3084"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 162, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18308337664, "block_size": 4096, "block_total": 4789504, "block_available": 4469809, "block_used": 319695, "inode_total": 9611776, "inode_available": 9570274, "inode_used": 41502, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_interfaces": ["eth0", "lo", "eth1"], "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:20:90:45", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.15", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:fe20:9045", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:2079:cbe7:fae3:3756", "prefix": "64", "scope": "global"}, {"address": "fe80::5348:2850:35cd:1607", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:2079:cbe7:fae3:3756", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["192.168.50.15", "10.0.2.15"], "ansible_all_ipv6_addresses": ["fe80::a00:27ff:fe20:9045", "fd17:625c:f037:2:2079:cbe7:fae3:3756", "fe80::5348:2850:35cd:1607"], "ansible_pkg_mgr": "dnf", "ansible_service_mgr": "systemd", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433588.2500794-386514-200568188454037/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client]
META: ran handlers

TASK [copy resolv.conf to the client] ******************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:50
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675 `" && echo ansible-tmp-1795433589.7080848-386546-166736072465675="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433589.7080848-386546-166736072465675=/home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpmpqbzqu1 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpmpqbzqu1 /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-syquouepbippjdhkmfvyxifiqalberjx ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/resolv.conf", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 50, "inode": 33866905, "dev": 2052, "nlink": 1, "atime": 1795433536.6121347, "mtime": 1795433526.3263264, "ctime": 1795433526.3373208, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "ee0f0edfdf05764de96b51aff44b8dcd4d07cd7a", "mimetype": "text/plain", "charset": "us-ascii", "version": "2095301974", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/resolv.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/client-resolv.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/client-resolv.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpq89g2725 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpq89g2725 /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-vpqsvkaxpxmhludghccjeatayhkeqynl ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/resolv.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source", "md5sum": "dd3f36d3b09559411d12f3b77e426c38", "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:net_conf_t:s0", "size": 80, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source", "dest": "/etc/resolv.conf", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "client-resolv.conf", "follow": false, "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client] => {
    "changed": true,
    "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703",
    "dest": "/etc/resolv.conf",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "client-resolv.conf",
            "attributes": null,
            "backup": false,
            "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703",
            "content": null,
            "dest": "/etc/resolv.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "dd3f36d3b09559411d12f3b77e426c38",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:net_conf_t:s0",
    "size": 80,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433589.7080848-386546-166736072465675/source",
    "state": "file",
    "uid": 0
}

TASK [copy rndc conf file] *****************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:52
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872 `" && echo ansible-tmp-1795433591.7388127-386598-67660289317872="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433591.7388127-386598-67660289317872=/home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp6k7p_smf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp6k7p_smf /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-iebqdfzdntrfrstaeseksxjlcpgeixbm ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/home/vagrant/rndc.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/rndc.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/rndc.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp4wbcn11l TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmp4wbcn11l /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-wpcpzskscrxhvajhadruojfsmafcsasi ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/home/vagrant/rndc.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source", "md5sum": "ab1a408f722ee72a5d67f5c367e57a62", "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5", "changed": true, "uid": 1000, "gid": 1000, "owner": "vagrant", "group": "vagrant", "mode": "0644", "state": "file", "secontext": "unconfined_u:object_r:user_home_t:s0", "size": 160, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source", "dest": "/home/vagrant/rndc.conf", "owner": "vagrant", "group": "vagrant", "mode": "0644", "_original_basename": "rndc.conf", "follow": false, "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client] => {
    "changed": true,
    "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5",
    "dest": "/home/vagrant/rndc.conf",
    "diff": [],
    "gid": 1000,
    "group": "vagrant",
    "invocation": {
        "module_args": {
            "_original_basename": "rndc.conf",
            "attributes": null,
            "backup": false,
            "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5",
            "content": null,
            "dest": "/home/vagrant/rndc.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "vagrant",
            "local_follow": null,
            "mode": "0644",
            "owner": "vagrant",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "ab1a408f722ee72a5d67f5c367e57a62",
    "mode": "0644",
    "owner": "vagrant",
    "secontext": "unconfined_u:object_r:user_home_t:s0",
    "size": 160,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433591.7388127-386598-67660289317872/source",
    "state": "file",
    "uid": 1000
}

TASK [copy motd to the client] *************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:54
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717 `" && echo ansible-tmp-1795433593.5196526-386652-113966605014717="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433593.5196526-386652-113966605014717=/home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpbmyq9pvf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpbmyq9pvf /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-rvscwfkkgsgrjpqiknobvnokzcquxhwb ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/motd", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 0, "inode": 33686565, "dev": 2052, "nlink": 1, "atime": 1592892703.0, "mtime": 1592892703.0, "ctime": 1787133201.4662812, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 0, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "da39a3ee5e6b4b0d3255bfef95601890afd80709", "mimetype": "inode/x-empty", "charset": "binary", "version": "3294455799", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/motd", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/client-motd TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/client-motd /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpbw63rqno TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-3863333i2yxsfs/tmpbw63rqno /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ylrpbkdpssktxfshcahdldrwczeczpdq ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"dest": "/etc/motd", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source", "md5sum": "a21f21cf69ea7dad3bfde2435eed3ade", "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 456, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source", "dest": "/etc/motd", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "client-motd", "follow": false, "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2201 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/15387964b6"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client] => {
    "changed": true,
    "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de",
    "dest": "/etc/motd",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "client-motd",
            "attributes": null,
            "backup": false,
            "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de",
            "content": null,
            "dest": "/etc/motd",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "a21f21cf69ea7dad3bfde2435eed3ade",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 456,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433593.5196526-386652-113966605014717/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY RECAP *********************************************************************
client                     : ok=7    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

==> client2: Importing base box 'almalinux9-stand-vb'...
==> client2: Matching MAC address for NAT networking...
==> client2: Setting the name of the VM: vagrant-bind_client2_1795433624511_82439
==> client2: Fixed port collision for 22 => 2222. Now on port 2202.
==> client2: Clearing any previously set network interfaces...
==> client2: Preparing network interfaces based on configuration...
    client2: Adapter 1: nat
    client2: Adapter 2: intnet
==> client2: Forwarding ports...
    client2: 22 (guest) => 2202 (host) (adapter 1)
==> client2: Running 'pre-boot' VM customizations...
==> client2: Booting VM...
==> client2: Waiting for machine to boot. This may take a few minutes...
    client2: SSH address: 127.0.0.1:2202
    client2: SSH username: vagrant
    client2: SSH auth method: private key
    client2: Warning: Connection reset. Retrying...
    client2: Warning: Connection reset. Retrying...
    client2: Warning: Connection reset. Retrying...
    client2: Warning: Remote connection disconnect. Retrying...
    client2: Warning: Connection reset. Retrying...
    client2: Warning: Connection reset. Retrying...
    client2: Warning: Connection reset. Retrying...
    client2: 
    client2: Vagrant insecure key detected. Vagrant will automatically replace
    client2: this with a newly generated keypair for better security.
    client2: 
    client2: Inserting generated public key within guest...
    client2: Removing insecure key from the guest if it's present...
    client2: Key inserted! Disconnecting and reconnecting using new SSH key...
==> client2: Machine booted and ready!
==> client2: Checking for guest additions in VM...
    client2: The guest additions on this VM do not match the installed version of
    client2: VirtualBox! In most cases this is fine, but in rare cases it can
    client2: prevent things such as shared folders from working properly. If you see
    client2: shared folder errors, please make sure the guest additions within the
    client2: virtual machine match the version of VirtualBox you have installed on
    client2: your host and reload your VM.
    client2: 
    client2: Guest Additions Version: 7.2.16
    client2: VirtualBox Version: 7.1
==> client2: Setting hostname...
==> client2: Configuring and enabling network interfaces...
==> client2: Mounting shared folders...
    client2: /home/admin_insta11/vagrant-bind => /vagrant
==> client2: Running provisioner: ansible...
    client2: Running ansible-playbook...
PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --connection=ssh --timeout=30 --limit="client2" --inventory-file=/home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory -vvv provisioning/playbook.yml
ansible-playbook [core 2.13.13]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/admin_insta11/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.8/site-packages/ansible
  ansible collection location = /home/admin_insta11/.ansible/collections:/usr/share/ansible/collections
  executable location = /bin/ansible-playbook
  python version = 3.8.20 (default, Sep  9 2024, 00:00:00) [GCC 11.4.1 20230605 (Red Soft 11.4.0-1)]
  jinja version = 3.1.3
  libyaml = True
Using /etc/ansible/ansible.cfg as config file
host_list declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
script declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
auto declined parsing /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory as it did not pass its verify_file() method
Parsed /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory inventory source with ini plugin
Skipping callback 'default', as we already have a stdout callback.
Skipping callback 'minimal', as we already have a stdout callback.
Skipping callback 'oneline', as we already have a stdout callback.

PLAYBOOK: playbook.yml *********************************************************
4 plays in provisioning/playbook.yml

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:2
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b"Warning: Permanently added '[127.0.0.1]:2202' (ED25519) to the list of known hosts.\r\n")
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460 `" && echo ansible-tmp-1795433744.3855326-393259-143060454249460="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433744.3855326-393259-143060454249460=/home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460\n', b'')
<client2> Attempting python interpreter discovery
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo PLATFORM; uname; echo FOUND; command -v '"'"'"'"'"'"'"'"'python3.10'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.9'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.8'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.6'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python3.5'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python3'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/libexec/platform-python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python2.7'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'/usr/bin/python'"'"'"'"'"'"'"'"'; command -v '"'"'"'"'"'"'"'"'python'"'"'"'"'"'"'"'"'; echo ENDFOUND && sleep 0'"'"''
<127.0.0.1> (0, b'PLATFORM\nLinux\nFOUND\n/usr/bin/python3.9\n/usr/bin/python3\n/usr/libexec/platform-python\nENDFOUND\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'/usr/bin/python3.9 && sleep 0'"'"''
<127.0.0.1> (0, b'{"platform_dist_result": [], "osrelease_content": "NAME=\\"AlmaLinux\\"\\nVERSION=\\"9.8 (Olive Jaguar)\\"\\nID=\\"almalinux\\"\\nID_LIKE=\\"rhel centos fedora\\"\\nVERSION_ID=\\"9.8\\"\\nPLATFORM_ID=\\"platform:el9\\"\\nPRETTY_NAME=\\"AlmaLinux 9.8 (Olive Jaguar)\\"\\nANSI_COLOR=\\"0;34\\"\\nLOGO=\\"fedora-logo-icon\\"\\nCPE_NAME=\\"cpe:/o:almalinux:almalinux:9::baseos\\"\\nHOME_URL=\\"https://almalinux.org/\\"\\nDOCUMENTATION_URL=\\"https://wiki.almalinux.org/\\"\\nBUG_REPORT_URL=\\"https://bugs.almalinux.org/\\"\\n\\nALMALINUX_MANTISBT_PROJECT=\\"AlmaLinux-9\\"\\nALMALINUX_MANTISBT_PROJECT_VERSION=\\"9.8\\"\\nREDHAT_SUPPORT_PRODUCT=\\"AlmaLinux\\"\\nREDHAT_SUPPORT_PRODUCT_VERSION=\\"9.8\\"\\nSUPPORT_END=2032-06-01\\n"}\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpde94zcqh TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpde94zcqh /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-abvsisgtfpwbyegilzkifmokrymcuhcv ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"ansible_facts": {"ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "client2", "ansible_hostname": "client2", "ansible_nodename": "client2", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "1d16328a9bb14f51bc44266f7c6f0803", "ansible_iscsi_iqn": "", "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "35", "second": "46", "epoch": "1795433746", "epoch_int": "1795433746", "date": "2026-11-23", "time": "11:35:46", "iso8601_micro": "2026-11-23T11:35:46.096345Z", "iso8601": "2026-11-23T11:35:46Z", "iso8601_basic": "20261123T113546096345", "iso8601_basic_short": "20261123T113546", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDwBQwrBlzmVXXy3VATud4lGHvSEfmSsQ5TCucVmeW6X/bwWBmHq87bm0CO+jgT4JcCNIlDespEMXQPHZ2xND5ts+Kuyl0NufznsGqWCWpv8Wp55hDCCaJJlIQVJd4cNv5K1bBAUmTg42/atRWzzx/oqhzcQ67/wOYulpRtZ9m37VQ5nkvnJPwEx0tLllvx753VSoTfrNB1oE44r7iZ1QCe40MEjm0hc6arLsF51afI8sDSZ0Y49PUc9P8GMBAILFCbNWEvVqGqg2p+UvS7xYhlgtVP7i7JggdAg2X9YVc1/Y+92NDPkLl2vFygvmu2iUu+4lLTJJcFhT3DwwFEQk+6VrQPlC0oj1FKC6h68784BN8GageM6KJ6IjeXkoEiVF/efxCjI51W/Ll1A/py2yDOwbvINUW1lJafVOQr7tpOFD/XM6Q7d9DZFTsPXLLNacj61Vh2Eb0zP2L5+rNSbbbi1JjBvsc/dA8AfvTs9B2R/o38MJX3JF4DC8yuL6Dztes=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNHqddldQjkhKqybAtLAdWTz5uB+fhv/9VwpSdinliRqDVOd0OsOGJNx7XWh5gABWuE+GHRj96TN91TKt0zmoZk=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIMc4BujrG2oaYTIQY85y8Yzbkp6PTW91Vugtdmu8QWlL", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_is_chroot": false, "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 588, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 351, "free": 588}, "nocache": {"free": 713, "used": 226}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-bd69b3f0-7abd-433e-88d7-b3f9877c1ca6", "ansible_product_uuid": "f0b369bd-bd7a-3e43-88d7-b3f9877c1ca6", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB22e89c7f", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2"], "sda3": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3"], "sda4": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4"], "sda1": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1"], "sda": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 110, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18366840832, "block_size": 4096, "block_total": 4789504, "block_available": 4484092, "block_used": 305412, "inode_total": 9611776, "inode_available": 9570688, "inode_used": 41088, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_lsb": {}, "ansible_local": {}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_interfaces": ["eth0", "lo", "eth1"], "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:1196:dfd7:a9f8:f817", "prefix": "64", "scope": "global"}, {"address": "fe80::2efa:4d63:34b4:80eb", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:b1:35:34", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.16", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:feb1:3534", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:1196:dfd7:a9f8:f817", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["10.0.2.15", "192.168.50.16"], "ansible_all_ipv6_addresses": ["fd17:625c:f037:2:1196:dfd7:a9f8:f817", "fe80::2efa:4d63:34b4:80eb", "fe80::a00:27ff:feb1:3534"], "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_fips": false, "ansible_apparmor": {"status": "disabled"}, "ansible_pkg_mgr": "dnf", "ansible_fibre_channel_wwn": [], "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-abvsisgtfpwbyegilzkifmokrymcuhcv ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_service_mgr": "systemd", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433744.3855326-393259-143060454249460/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client2]
META: ran handlers

TASK [install packages] ********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:5
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355 `" && echo ansible-tmp-1795433747.0938663-393302-192327711849355="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433747.0938663-393302-192327711849355=/home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpdgz6r1t5 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpdgz6r1t5 /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-rggrntowuhyndcopibmdldxxzmqipdtr ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "", "changed": true, "results": ["Installed: fstrm-0.6.1-3.el9.x86_64", "Installed: policycoreutils-python-utils-3.6-9.el9.noarch", "Installed: python3-policycoreutils-3.6-9.el9.noarch", "Installed: python3-ply-3.11-14.el9.noarch", "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch", "Installed: policycoreutils-3.6-9.el9.x86_64", "Installed: bind-32:9.16.50-12.el9_9.1.x86_64", "Installed: libmaxminddb-1.5.2-4.el9.x86_64", "Installed: libuv-1:1.42.0-2.el9_4.x86_64", "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64", "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch", "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64", "Removed: policycoreutils-3.6-5.el9.x86_64", "Removed: python3-policycoreutils-3.6-5.el9.noarch"], "rc": 0, "invocation": {"module_args": {"name": ["bind"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433747.0938663-393302-192327711849355/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client2] => (item=bind) => {
    "ansible_loop_var": "item",
    "changed": true,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind",
    "msg": "",
    "rc": 0,
    "results": [
        "Installed: fstrm-0.6.1-3.el9.x86_64",
        "Installed: policycoreutils-python-utils-3.6-9.el9.noarch",
        "Installed: python3-policycoreutils-3.6-9.el9.noarch",
        "Installed: python3-ply-3.11-14.el9.noarch",
        "Installed: python3-bind-32:9.16.50-12.el9_9.1.noarch",
        "Installed: policycoreutils-3.6-9.el9.x86_64",
        "Installed: bind-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: libmaxminddb-1.5.2-4.el9.x86_64",
        "Installed: libuv-1:1.42.0-2.el9_4.x86_64",
        "Installed: bind-dnssec-doc-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-dnssec-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-libs-32:9.16.50-12.el9_9.1.x86_64",
        "Installed: bind-license-32:9.16.50-12.el9_9.1.noarch",
        "Installed: bind-utils-32:9.16.50-12.el9_9.1.x86_64",
        "Removed: policycoreutils-3.6-5.el9.x86_64",
        "Removed: python3-policycoreutils-3.6-5.el9.noarch"
    ]
}
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850 `" && echo ansible-tmp-1795433793.256887-393302-100271170410850="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433793.256887-393302-100271170410850=/home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/dnf.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpy37ulcl5 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/AnsiballZ_dnf.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpy37ulcl5 /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/AnsiballZ_dnf.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/AnsiballZ_dnf.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-wfgzfgvmnsopcclgluozpuuuvjlzpook ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/AnsiballZ_dnf.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"msg": "Nothing to do", "changed": false, "results": [], "rc": 0, "invocation": {"module_args": {"name": ["bind-utils"], "state": "latest", "allow_downgrade": false, "autoremove": false, "bugfix": false, "cacheonly": false, "disable_gpg_check": false, "disable_plugin": [], "disablerepo": [], "download_only": false, "enable_plugin": [], "enablerepo": [], "exclude": [], "installroot": "/", "install_repoquery": true, "install_weak_deps": true, "security": false, "skip_broken": false, "update_cache": false, "update_only": false, "validate_certs": true, "sslverify": true, "lock_timeout": 30, "allowerasing": false, "nobest": false, "conf_file": null, "disable_excludes": null, "download_dir": null, "list": null, "releasever": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433793.256887-393302-100271170410850/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client2] => (item=bind-utils) => {
    "ansible_loop_var": "item",
    "changed": false,
    "invocation": {
        "module_args": {
            "allow_downgrade": false,
            "allowerasing": false,
            "autoremove": false,
            "bugfix": false,
            "cacheonly": false,
            "conf_file": null,
            "disable_excludes": null,
            "disable_gpg_check": false,
            "disable_plugin": [],
            "disablerepo": [],
            "download_dir": null,
            "download_only": false,
            "enable_plugin": [],
            "enablerepo": [],
            "exclude": [],
            "install_repoquery": true,
            "install_weak_deps": true,
            "installroot": "/",
            "list": null,
            "lock_timeout": 30,
            "name": [
                "bind-utils"
            ],
            "nobest": false,
            "releasever": null,
            "security": false,
            "skip_broken": false,
            "sslverify": true,
            "state": "latest",
            "update_cache": false,
            "update_only": false,
            "validate_certs": true
        }
    },
    "item": "bind-utils",
    "msg": "Nothing to do",
    "rc": 0,
    "results": []
}

TASK [copy transferkey to all servers and the client] **************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:12
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306 `" && echo ansible-tmp-1795433795.2290514-393363-118839455548306="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433795.2290514-393363-118839455548306=/home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpem6r3ur1 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpem6r3ur1 /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-wkawsejgatodxbbscaczyjxqxhpbvsbi ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/etc/named.zonetransfer.key", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/named.zonetransfer.key /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmptj9e8w99 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmptj9e8w99 /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-zpzsggasdqckissoitxpyfjdkzqwtfvo ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/named.zonetransfer.key", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source", "md5sum": "15ccf7d7d6ea11384de2901045af4d02", "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "changed": true, "uid": 0, "gid": 25, "owner": "root", "group": "named", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 91, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source", "dest": "/etc/named.zonetransfer.key", "owner": "root", "group": "named", "mode": "0644", "_original_basename": "named.zonetransfer.key", "follow": false, "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client2] => {
    "changed": true,
    "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
    "dest": "/etc/named.zonetransfer.key",
    "diff": [],
    "gid": 25,
    "group": "named",
    "invocation": {
        "module_args": {
            "_original_basename": "named.zonetransfer.key",
            "attributes": null,
            "backup": false,
            "checksum": "f37bcb9d74ee1016dad4b88e9cac239a80b7fad2",
            "content": null,
            "dest": "/etc/named.zonetransfer.key",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "named",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "15ccf7d7d6ea11384de2901045af4d02",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 91,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433795.2290514-393363-118839455548306/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY [ns01] ********************************************************************
skipping: no hosts matched

PLAY [ns02] ********************************************************************
skipping: no hosts matched

PLAY [client, client2] *********************************************************

TASK [Gathering Facts] *********************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:47
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414 `" && echo ansible-tmp-1795433797.2173538-393420-186936303621414="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433797.2173538-393420-186936303621414=/home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/setup.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp0oxh7f6x TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/AnsiballZ_setup.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp0oxh7f6x /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/AnsiballZ_setup.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/AnsiballZ_setup.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-nxxhosunrzlmfbesgwgveglghedsnxfd ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/AnsiballZ_setup.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"ansible_facts": {"ansible_iscsi_iqn": "", "ansible_ssh_host_key_rsa_public": "AAAAB3NzaC1yc2EAAAADAQABAAABgQDwBQwrBlzmVXXy3VATud4lGHvSEfmSsQ5TCucVmeW6X/bwWBmHq87bm0CO+jgT4JcCNIlDespEMXQPHZ2xND5ts+Kuyl0NufznsGqWCWpv8Wp55hDCCaJJlIQVJd4cNv5K1bBAUmTg42/atRWzzx/oqhzcQ67/wOYulpRtZ9m37VQ5nkvnJPwEx0tLllvx753VSoTfrNB1oE44r7iZ1QCe40MEjm0hc6arLsF51afI8sDSZ0Y49PUc9P8GMBAILFCbNWEvVqGqg2p+UvS7xYhlgtVP7i7JggdAg2X9YVc1/Y+92NDPkLl2vFygvmu2iUu+4lLTJJcFhT3DwwFEQk+6VrQPlC0oj1FKC6h68784BN8GageM6KJ6IjeXkoEiVF/efxCjI51W/Ll1A/py2yDOwbvINUW1lJafVOQr7tpOFD/XM6Q7d9DZFTsPXLLNacj61Vh2Eb0zP2L5+rNSbbbi1JjBvsc/dA8AfvTs9B2R/o38MJX3JF4DC8yuL6Dztes=", "ansible_ssh_host_key_rsa_public_keytype": "ssh-rsa", "ansible_ssh_host_key_ecdsa_public": "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNHqddldQjkhKqybAtLAdWTz5uB+fhv/9VwpSdinliRqDVOd0OsOGJNx7XWh5gABWuE+GHRj96TN91TKt0zmoZk=", "ansible_ssh_host_key_ecdsa_public_keytype": "ecdsa-sha2-nistp256", "ansible_ssh_host_key_ed25519_public": "AAAAC3NzaC1lZDI1NTE5AAAAIMc4BujrG2oaYTIQY85y8Yzbkp6PTW91Vugtdmu8QWlL", "ansible_ssh_host_key_ed25519_public_keytype": "ssh-ed25519", "ansible_user_id": "root", "ansible_user_uid": 0, "ansible_user_gid": 0, "ansible_user_gecos": "root", "ansible_user_dir": "/root", "ansible_user_shell": "/bin/bash", "ansible_real_user_id": 0, "ansible_effective_user_id": 0, "ansible_real_group_id": 0, "ansible_effective_group_id": 0, "ansible_system_capabilities_enforced": "False", "ansible_system_capabilities": [], "ansible_local": {}, "ansible_virtualization_role": "guest", "ansible_virtualization_type": "virtualbox", "ansible_virtualization_tech_guest": ["virtualbox"], "ansible_virtualization_tech_host": [], "ansible_distribution": "AlmaLinux", "ansible_distribution_release": "Olive Jaguar", "ansible_distribution_version": "9.8", "ansible_distribution_major_version": "9", "ansible_distribution_file_path": "/etc/redhat-release", "ansible_distribution_file_variety": "RedHat", "ansible_distribution_file_parsed": true, "ansible_os_family": "RedHat", "ansible_system": "Linux", "ansible_kernel": "5.14.0-687.39.1.el9_8.x86_64", "ansible_kernel_version": "#1 SMP PREEMPT_DYNAMIC Tue Aug 18 06:09:16 EDT 2026", "ansible_machine": "x86_64", "ansible_python_version": "3.9.25", "ansible_fqdn": "client2", "ansible_hostname": "client2", "ansible_nodename": "client2", "ansible_domain": "", "ansible_userspace_bits": "64", "ansible_architecture": "x86_64", "ansible_userspace_architecture": "x86_64", "ansible_machine_id": "1d16328a9bb14f51bc44266f7c6f0803", "ansible_lsb": {}, "ansible_env": {"SHELL": "/bin/bash", "SUDO_GID": "1000", "SUDO_COMMAND": "/bin/sh -c echo BECOME-SUCCESS-nxxhosunrzlmfbesgwgveglghedsnxfd ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/AnsiballZ_setup.py", "SUDO_USER": "vagrant", "SUDO_TTY": "/dev/pts/0", "PWD": "/home/vagrant", "LOGNAME": "root", "SUDO_HOME": "/home/vagrant", "HOME": "/root", "LANG": "en_US.UTF-8", "LS_COLORS": "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.webp=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.m4a=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.oga=01;36:*.opus=01;36:*.spx=01;36:*.xspf=01;36:", "TERM": "xterm-256color", "USER": "root", "SHLVL": "0", "PATH": "/sbin:/bin:/usr/sbin:/usr/bin", "SUDO_UID": "1000", "MAIL": "/var/mail/root", "_": "/usr/bin/python3"}, "ansible_hostnqn": "nqn.2014-08.org.nvmexpress:uuid:ce953c73-8532-684b-b76b-aa9d3e0b128c", "ansible_date_time": {"year": "2026", "month": "11", "weekday": "Monday", "weekday_number": "1", "weeknumber": "47", "day": "23", "hour": "11", "minute": "36", "second": "38", "epoch": "1795433798", "epoch_int": "1795433798", "date": "2026-11-23", "time": "11:36:38", "iso8601_micro": "2026-11-23T11:36:38.395555Z", "iso8601": "2026-11-23T11:36:38Z", "iso8601_basic": "20261123T113638395555", "iso8601_basic_short": "20261123T113638", "tz": "UTC", "tz_dst": "UTC", "tz_offset": "+0000"}, "ansible_is_chroot": false, "ansible_processor": ["0", "GenuineIntel", "Intel(R) Xeon(R) CPU E5-2430 0 @ 2.20GHz"], "ansible_processor_count": 1, "ansible_processor_cores": 1, "ansible_processor_threads_per_core": 1, "ansible_processor_vcpus": 1, "ansible_processor_nproc": 1, "ansible_memtotal_mb": 939, "ansible_memfree_mb": 374, "ansible_swaptotal_mb": 0, "ansible_swapfree_mb": 0, "ansible_memory_mb": {"real": {"total": 939, "used": 565, "free": 374}, "nocache": {"free": 639, "used": 300}, "swap": {"total": 0, "free": 0, "used": 0, "cached": 0}}, "ansible_bios_date": "12/01/2006", "ansible_bios_vendor": "innotek GmbH", "ansible_bios_version": "VirtualBox", "ansible_board_asset_tag": "NA", "ansible_board_name": "VirtualBox", "ansible_board_serial": "0", "ansible_board_vendor": "Oracle Corporation", "ansible_board_version": "1.2", "ansible_chassis_asset_tag": "NA", "ansible_chassis_serial": "NA", "ansible_chassis_vendor": "Oracle Corporation", "ansible_chassis_version": "NA", "ansible_form_factor": "Other", "ansible_product_name": "VirtualBox", "ansible_product_serial": "VirtualBox-bd69b3f0-7abd-433e-88d7-b3f9877c1ca6", "ansible_product_uuid": "f0b369bd-bd7a-3e43-88d7-b3f9877c1ca6", "ansible_product_version": "1.2", "ansible_system_vendor": "innotek GmbH", "ansible_devices": {"sda": {"virtual": 1, "links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7"], "uuids": [], "labels": [], "masters": []}, "vendor": "ATA", "model": "VBOX HARDDISK", "sas_address": null, "sas_device_handle": null, "serial": "VB22e89c7f", "removable": "0", "support_discard": "512", "partitions": {"sda4": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4"], "uuids": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"], "labels": [], "masters": []}, "start": "2510848", "sectors": "38447104", "sectorsize": 512, "size": "18.33 GB", "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "holders": []}, "sda2": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2"], "uuids": ["CFBF-3084"], "labels": [], "masters": []}, "start": "4096", "sectors": "409600", "sectorsize": 512, "size": "200.00 MB", "uuid": "CFBF-3084", "holders": []}, "sda3": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3"], "uuids": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "labels": [], "masters": []}, "start": "413696", "sectors": "2097152", "sectorsize": 512, "size": "1.00 GB", "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d", "holders": []}, "sda1": {"links": {"ids": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1"], "uuids": [], "labels": [], "masters": []}, "start": "2048", "sectors": "2048", "sectorsize": 512, "size": "1.00 MB", "uuid": null, "holders": []}}, "rotational": "1", "scheduler_mode": "mq-deadline", "sectors": "40960000", "sectorsize": "512", "size": "19.53 GB", "host": "", "holders": []}}, "ansible_device_links": {"ids": {"sda2": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part2"], "sda3": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part3"], "sda4": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part4"], "sda1": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7-part1"], "sda": ["ata-VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-0ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-1ATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7", "scsi-SATA_VBOX_HARDDISK_VB22e89c7f-d73a02c7"]}, "uuids": {"sda2": ["CFBF-3084"], "sda3": ["50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"], "sda4": ["fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"]}, "labels": {}, "masters": {}}, "ansible_uptime_seconds": 163, "ansible_mounts": [{"mount": "/", "device": "/dev/sda4", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 19617808384, "size_available": 18308337664, "block_size": 4096, "block_total": 4789504, "block_available": 4469809, "block_used": 319695, "inode_total": 9611776, "inode_available": 9570274, "inode_used": 41502, "uuid": "fff70a4e-6fa6-45a2-a9cd-8dcdb14646da"}, {"mount": "/boot", "device": "/dev/sda3", "fstype": "xfs", "options": "rw,seclabel,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota", "size_total": 1006632960, "size_available": 851652608, "block_size": 4096, "block_total": 245760, "block_available": 207923, "block_used": 37837, "inode_total": 524288, "inode_available": 523968, "inode_used": 320, "uuid": "50cb4a25-9132-48b5-b9fc-b1c6bf1a521d"}, {"mount": "/boot/efi", "device": "/dev/sda2", "fstype": "vfat", "options": "rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=winnt,errors=remount-ro", "size_total": 209469440, "size_available": 201449472, "block_size": 4096, "block_total": 51140, "block_available": 49182, "block_used": 1958, "inode_total": 0, "inode_available": 0, "inode_used": 0, "uuid": "CFBF-3084"}], "ansible_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": "ttyS0,115200n8", "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_proc_cmdline": {"BOOT_IMAGE": "(hd0,gpt3)/vmlinuz-5.14.0-687.39.1.el9_8.x86_64", "root": "UUID=fff70a4e-6fa6-45a2-a9cd-8dcdb14646da", "ro": true, "console": ["tty0", "ttyS0,115200n8"], "no_timer_check": true, "biosdevname": "0", "net.ifnames": "0"}, "ansible_python": {"version": {"major": 3, "minor": 9, "micro": 25, "releaselevel": "final", "serial": 0}, "version_info": [3, 9, 25, "final", 0], "executable": "/usr/bin/python3", "has_sslcontext": true, "type": "cpython"}, "ansible_apparmor": {"status": "disabled"}, "ansible_interfaces": ["eth0", "lo", "eth1"], "ansible_lo": {"device": "lo", "mtu": 65536, "active": true, "type": "loopback", "promisc": false, "ipv4": {"address": "127.0.0.1", "broadcast": "", "netmask": "255.0.0.0", "network": "127.0.0.0", "prefix": "8"}, "ipv6": [{"address": "::1", "prefix": "128", "scope": "host"}], "features": {"rx_checksumming": "on [fixed]", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on [fixed]", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "on [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on [fixed]", "tx_scatter_gather_fraglist": "on [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "on", "tx_tcp_mangleid_segmentation": "on", "tx_tcp6_segmentation": "on", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "off [fixed]", "tx_vlan_offload": "off [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "on [fixed]", "rx_vlan_filter": "off [fixed]", "vlan_challenged": "on [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "on", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "on", "tx_gso_list": "on", "tx_nocache_copy": "off [fixed]", "loopback": "on [fixed]", "rx_fcs": "off [fixed]", "rx_all": "off [fixed]", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth0": {"device": "eth0", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:03.0", "speed": 1000, "promisc": false, "ipv4": {"address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24"}, "ipv6": [{"address": "fd17:625c:f037:2:1196:dfd7:a9f8:f817", "prefix": "64", "scope": "global"}, {"address": "fe80::2efa:4d63:34b4:80eb", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_eth1": {"device": "eth1", "macaddress": "08:00:27:b1:35:34", "mtu": 1500, "active": true, "module": "e1000", "type": "ether", "pciid": "0000:00:08.0", "speed": 1000, "promisc": false, "ipv4": {"address": "192.168.50.16", "broadcast": "192.168.50.255", "netmask": "255.255.255.0", "network": "192.168.50.0", "prefix": "24"}, "ipv6": [{"address": "fe80::a00:27ff:feb1:3534", "prefix": "64", "scope": "link"}], "features": {"rx_checksumming": "off", "tx_checksumming": "on", "tx_checksum_ipv4": "off [fixed]", "tx_checksum_ip_generic": "on", "tx_checksum_ipv6": "off [fixed]", "tx_checksum_fcoe_crc": "off [fixed]", "tx_checksum_sctp": "off [fixed]", "scatter_gather": "on", "tx_scatter_gather": "on", "tx_scatter_gather_fraglist": "off [fixed]", "tcp_segmentation_offload": "on", "tx_tcp_segmentation": "on", "tx_tcp_ecn_segmentation": "off [fixed]", "tx_tcp_mangleid_segmentation": "off", "tx_tcp6_segmentation": "off [fixed]", "generic_segmentation_offload": "on", "generic_receive_offload": "on", "large_receive_offload": "off [fixed]", "rx_vlan_offload": "on", "tx_vlan_offload": "on [fixed]", "ntuple_filters": "off [fixed]", "receive_hashing": "off [fixed]", "highdma": "off [fixed]", "rx_vlan_filter": "on [fixed]", "vlan_challenged": "off [fixed]", "tx_gso_robust": "off [fixed]", "tx_fcoe_segmentation": "off [fixed]", "tx_gre_segmentation": "off [fixed]", "tx_gre_csum_segmentation": "off [fixed]", "tx_ipxip4_segmentation": "off [fixed]", "tx_ipxip6_segmentation": "off [fixed]", "tx_udp_tnl_segmentation": "off [fixed]", "tx_udp_tnl_csum_segmentation": "off [fixed]", "tx_gso_partial": "off [fixed]", "tx_tunnel_remcsum_segmentation": "off [fixed]", "tx_sctp_segmentation": "off [fixed]", "tx_esp_segmentation": "off [fixed]", "tx_udp_segmentation": "off [fixed]", "tx_gso_list": "off [fixed]", "tx_nocache_copy": "off", "loopback": "off [fixed]", "rx_fcs": "off", "rx_all": "off", "tx_vlan_stag_hw_insert": "off [fixed]", "rx_vlan_stag_hw_parse": "off [fixed]", "rx_vlan_stag_filter": "off [fixed]", "l2_fwd_offload": "off [fixed]", "hw_tc_offload": "off [fixed]", "esp_hw_offload": "off [fixed]", "esp_tx_csum_hw_offload": "off [fixed]", "rx_udp_tunnel_port_offload": "off [fixed]", "tls_hw_tx_offload": "off [fixed]", "tls_hw_rx_offload": "off [fixed]", "rx_gro_hw": "off [fixed]", "tls_hw_record": "off [fixed]", "rx_gro_list": "off", "macsec_hw_offload": "off [fixed]", "rx_udp_gro_forwarding": "off", "hsr_tag_ins_offload": "off [fixed]", "hsr_tag_rm_offload": "off [fixed]", "hsr_fwd_offload": "off [fixed]", "hsr_dup_offload": "off [fixed]"}, "timestamping": [], "hw_timestamp_filters": []}, "ansible_default_ipv4": {"gateway": "10.0.2.2", "interface": "eth0", "address": "10.0.2.15", "broadcast": "10.0.2.255", "netmask": "255.255.255.0", "network": "10.0.2.0", "prefix": "24", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether", "alias": "eth0"}, "ansible_default_ipv6": {"gateway": "fe80::2", "interface": "eth0", "address": "fd17:625c:f037:2:1196:dfd7:a9f8:f817", "prefix": "64", "scope": "global", "macaddress": "08:00:27:d8:a1:08", "mtu": 1500, "type": "ether"}, "ansible_all_ipv4_addresses": ["10.0.2.15", "192.168.50.16"], "ansible_all_ipv6_addresses": ["fd17:625c:f037:2:1196:dfd7:a9f8:f817", "fe80::2efa:4d63:34b4:80eb", "fe80::a00:27ff:feb1:3534"], "ansible_selinux_python_present": true, "ansible_selinux": {"status": "enabled", "policyvers": 33, "config_mode": "enforcing", "mode": "enforcing", "type": "targeted"}, "ansible_pkg_mgr": "dnf", "ansible_dns": {"nameservers": ["10.0.2.3"]}, "ansible_fibre_channel_wwn": [], "ansible_fips": false, "ansible_service_mgr": "systemd", "gather_subset": ["all"], "module_setup": true}, "invocation": {"module_args": {"gather_subset": ["all"], "gather_timeout": 10, "filter": [], "fact_path": "/etc/ansible/facts.d"}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433797.2173538-393420-186936303621414/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
ok: [client2]
META: ran handlers

TASK [copy resolv.conf to the client] ******************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:50
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027 `" && echo ansible-tmp-1795433798.9524138-393451-23160124931027="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433798.9524138-393451-23160124931027=/home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpzhlzs53i TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpzhlzs53i /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-ntgmaqyibzfnxsbregtssljunvqbdhuq ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/resolv.conf", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 50, "inode": 33866905, "dev": 2052, "nlink": 1, "atime": 1795433745.945251, "mtime": 1795433735.0748782, "ctime": 1795433735.0838728, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 8, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "ee0f0edfdf05764de96b51aff44b8dcd4d07cd7a", "mimetype": "text/plain", "charset": "us-ascii", "version": "3007198028", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/resolv.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/client-resolv.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/client-resolv.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp5kf6zyot TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp5kf6zyot /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-xikikfqagwhxjlxuezjztfkrppnedmcw ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/resolv.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source", "md5sum": "dd3f36d3b09559411d12f3b77e426c38", "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:net_conf_t:s0", "size": 80, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source", "dest": "/etc/resolv.conf", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "client-resolv.conf", "follow": false, "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client2] => {
    "changed": true,
    "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703",
    "dest": "/etc/resolv.conf",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "client-resolv.conf",
            "attributes": null,
            "backup": false,
            "checksum": "c5b7d7e64780d0cb6c894431b2ad8e5d3eb4b703",
            "content": null,
            "dest": "/etc/resolv.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "dd3f36d3b09559411d12f3b77e426c38",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:net_conf_t:s0",
    "size": 80,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433798.9524138-393451-23160124931027/source",
    "state": "file",
    "uid": 0
}

TASK [copy rndc conf file] *****************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:52
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967 `" && echo ansible-tmp-1795433800.8163292-393507-256561153254967="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433800.8163292-393507-256561153254967=/home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpiq526vq5 TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpiq526vq5 /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-etstirmykzwjnbdobgzdicuakvkypkti ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": false}, "invocation": {"module_args": {"path": "/home/vagrant/rndc.conf", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/rndc.conf TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/rndc.conf /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpahvi525j TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpahvi525j /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-zwqqfymrkmvtwteoxelrainpgwrhrsyb ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n\r\n{"dest": "/home/vagrant/rndc.conf", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source", "md5sum": "ab1a408f722ee72a5d67f5c367e57a62", "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5", "changed": true, "uid": 1000, "gid": 1000, "owner": "vagrant", "group": "vagrant", "mode": "0644", "state": "file", "secontext": "unconfined_u:object_r:user_home_t:s0", "size": 160, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source", "dest": "/home/vagrant/rndc.conf", "owner": "vagrant", "group": "vagrant", "mode": "0644", "_original_basename": "rndc.conf", "follow": false, "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client2] => {
    "changed": true,
    "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5",
    "dest": "/home/vagrant/rndc.conf",
    "diff": [],
    "gid": 1000,
    "group": "vagrant",
    "invocation": {
        "module_args": {
            "_original_basename": "rndc.conf",
            "attributes": null,
            "backup": false,
            "checksum": "c360b52e337e48223bb1cf225f0d125a3e7aa6a5",
            "content": null,
            "dest": "/home/vagrant/rndc.conf",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "vagrant",
            "local_follow": null,
            "mode": "0644",
            "owner": "vagrant",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "ab1a408f722ee72a5d67f5c367e57a62",
    "mode": "0644",
    "owner": "vagrant",
    "secontext": "unconfined_u:object_r:user_home_t:s0",
    "size": 160,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433800.8163292-393507-256561153254967/source",
    "state": "file",
    "uid": 1000
}

TASK [copy motd to the client] *************************************************
task path: /home/admin_insta11/vagrant-bind/provisioning/playbook.yml:54
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'echo ~vagrant && sleep 0'"'"''
<127.0.0.1> (0, b'/home/vagrant\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'( umask 77 && mkdir -p "` echo /home/vagrant/.ansible/tmp `"&& mkdir "` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620 `" && echo ansible-tmp-1795433802.6726992-393562-88926143341620="` echo /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620 `" ) && sleep 0'"'"''
<127.0.0.1> (0, b'ansible-tmp-1795433802.6726992-393562-88926143341620=/home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620\n', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/stat.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp1crjqkik TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_stat.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmp1crjqkik /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_stat.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_stat.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-tjqzanpaqkhntexiejjdqzrsfuwcwlyd ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_stat.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"changed": false, "stat": {"exists": true, "path": "/etc/motd", "mode": "0644", "isdir": false, "ischr": false, "isblk": false, "isreg": true, "isfifo": false, "islnk": false, "issock": false, "uid": 0, "gid": 0, "size": 0, "inode": 33686565, "dev": 2052, "nlink": 1, "atime": 1592892703.0, "mtime": 1592892703.0, "ctime": 1787133201.4662812, "wusr": true, "rusr": true, "xusr": false, "wgrp": false, "rgrp": true, "xgrp": false, "woth": false, "roth": true, "xoth": false, "isuid": false, "isgid": false, "blocks": 0, "block_size": 4096, "device_type": 0, "readable": true, "writeable": true, "executable": false, "pw_name": "root", "gr_name": "root", "checksum": "da39a3ee5e6b4b0d3255bfef95601890afd80709", "mimetype": "inode/x-empty", "charset": "binary", "version": "3294455799", "attributes": [], "attr_flags": ""}, "invocation": {"module_args": {"path": "/etc/motd", "follow": false, "get_checksum": true, "checksum_algorithm": "sha1", "get_md5": false, "get_mime": true, "get_attributes": true}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> PUT /home/admin_insta11/vagrant-bind/provisioning/client-motd TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/vagrant-bind/provisioning/client-motd /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
Using module file /usr/lib/python3.8/site-packages/ansible/modules/copy.py
<127.0.0.1> PUT /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpx6jiul4j TO /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_copy.py
<127.0.0.1> SSH: EXEC sftp -b - -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' '[127.0.0.1]'
<127.0.0.1> (0, b'sftp> put /home/admin_insta11/.ansible/tmp/ansible-local-393246t91fsmuy/tmpx6jiul4j /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_copy.py\n', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'chmod u+x /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/ /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_copy.py && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' -tt 127.0.0.1 '/bin/sh -c '"'"'sudo -H -S -n  -u root /bin/sh -c '"'"'"'"'"'"'"'"'echo BECOME-SUCCESS-dwmmowsffowfvcosncoprywxrufcklck ; /usr/bin/python3 /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/AnsiballZ_copy.py'"'"'"'"'"'"'"'"' && sleep 0'"'"''
Escalation succeeded
<127.0.0.1> (0, b'\r\n{"dest": "/etc/motd", "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source", "md5sum": "a21f21cf69ea7dad3bfde2435eed3ade", "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de", "changed": true, "uid": 0, "gid": 0, "owner": "root", "group": "root", "mode": "0644", "state": "file", "secontext": "system_u:object_r:etc_t:s0", "size": 456, "invocation": {"module_args": {"src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source", "dest": "/etc/motd", "owner": "root", "group": "root", "mode": "0644", "_original_basename": "client-motd", "follow": false, "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de", "backup": false, "force": true, "unsafe_writes": false, "content": null, "validate": null, "directory_mode": null, "remote_src": null, "local_follow": null, "seuser": null, "serole": null, "selevel": null, "setype": null, "attributes": null}}}\r\n', b'Shared connection to 127.0.0.1 closed.\r\n')
<127.0.0.1> ESTABLISH SSH CONNECTION FOR USER: vagrant
<127.0.0.1> SSH: EXEC ssh -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o Port=2202 -o 'IdentityFile="/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key"' -o KbdInteractiveAuthentication=no -o PreferredAuthentications=gssapi-with-mic,gssapi-keyex,hostbased,publickey -o PasswordAuthentication=no -o 'User="vagrant"' -o ConnectTimeout=30 -o 'ControlPath="/home/admin_insta11/.ansible/cp/f22eaccd73"' 127.0.0.1 '/bin/sh -c '"'"'rm -f -r /home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/ > /dev/null 2>&1 && sleep 0'"'"''
<127.0.0.1> (0, b'', b'')
changed: [client2] => {
    "changed": true,
    "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de",
    "dest": "/etc/motd",
    "diff": [],
    "gid": 0,
    "group": "root",
    "invocation": {
        "module_args": {
            "_original_basename": "client-motd",
            "attributes": null,
            "backup": false,
            "checksum": "d051202c7b59cddf2c5a4782ac8d14f6d68b99de",
            "content": null,
            "dest": "/etc/motd",
            "directory_mode": null,
            "follow": false,
            "force": true,
            "group": "root",
            "local_follow": null,
            "mode": "0644",
            "owner": "root",
            "remote_src": null,
            "selevel": null,
            "serole": null,
            "setype": null,
            "seuser": null,
            "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source",
            "unsafe_writes": false,
            "validate": null
        }
    },
    "md5sum": "a21f21cf69ea7dad3bfde2435eed3ade",
    "mode": "0644",
    "owner": "root",
    "secontext": "system_u:object_r:etc_t:s0",
    "size": 456,
    "src": "/home/vagrant/.ansible/tmp/ansible-tmp-1795433802.6726992-393562-88926143341620/source",
    "state": "file",
    "uid": 0
}
META: ran handlers
META: ran handlers

PLAY RECAP *********************************************************************
client2                    : ok=7    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[admin_insta11@mv334 vagrant-bind]$ vagrant status
Current machine states:

ns01                      running (virtualbox)
ns02                      running (virtualbox)
client                    running (virtualbox)
client2                   running (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

**ПРИМЕЧАНИЕ:** по логу ниже оказалось, что не нужно формировать вручную inventory файл для ansible - vagrant формирует его сам:

```
[admin_insta11@mv334 vagrant-bind]$ cat /home/admin_insta11/vagrant-bind/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory
# Generated by Vagrant

ns02 ansible_host=127.0.0.1 ansible_port=2200 ansible_user='vagrant' ansible_ssh_private_key_file='/home/admin_insta11/vagrant-bind/.vagrant/machines/ns02/virtualbox/private_key'
client2 ansible_host=127.0.0.1 ansible_port=2202 ansible_user='vagrant' ansible_ssh_private_key_file='/home/admin_insta11/vagrant-bind/.vagrant/machines/client2/virtualbox/private_key'
client ansible_host=127.0.0.1 ansible_port=2201 ansible_user='vagrant' ansible_ssh_private_key_file='/home/admin_insta11/vagrant-bind/.vagrant/machines/client/virtualbox/private_key'
ns01 ansible_host=127.0.0.1 ansible_port=2222 ansible_user='vagrant' ansible_ssh_private_key_file='/home/admin_insta11/vagrant-bind/.vagrant/machines/ns01/virtualbox/private_key'
```


## 1. Конфигурирование раздельных bind/named для хостов

На созданных ВМ проверяем синхронизацию времени и статус существующего сервиса chronyd на обоих серверах ns01 и ns02:

```
[vagrant@ns01 ~]$ systemctl status chronyd
● chronyd.service - NTP client/server
     Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-11-23 11:23:35 UTC; 4h 31min ago
       Docs: man:chronyd(8)
             man:chrony.conf(5)
   Main PID: 723 (chronyd)
      Tasks: 1 (limit: 5464)
     Memory: 5.0M (peak: 5.5M)
        CPU: 258ms
     CGroup: /system.slice/chronyd.service
             └─723 /usr/sbin/chronyd -F 2
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ timedatectl status
               Local time: Mon 2026-11-23 15:55:18 UTC
           Universal time: Mon 2026-11-23 15:55:18 UTC
                 RTC time: Mon 2026-11-23 15:55:17
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
[vagrant@ns01 ~]$

[vagrant@ns02 ~]$ systemctl status chronyd
● chronyd.service - NTP client/server
     Loaded: loaded (/usr/lib/systemd/system/chronyd.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-11-23 11:27:10 UTC; 4h 28min ago
       Docs: man:chronyd(8)
             man:chrony.conf(5)
   Main PID: 723 (chronyd)
      Tasks: 1 (limit: 5464)
     Memory: 5.0M (peak: 5.3M)
        CPU: 235ms
     CGroup: /system.slice/chronyd.service
             └─723 /usr/sbin/chronyd -F 2
[vagrant@ns02 ~]$ 
[vagrant@ns02 ~]$ timedatectl status
               Local time: Mon 2026-11-23 15:55:51 UTC
           Universal time: Mon 2026-11-23 15:55:51 UTC
                 RTC time: Mon 2026-11-23 15:55:51
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
[vagrant@ns02 ~]$

```

Проверяем, на каких портах работают наши DNS-сервера:

```
[vagrant@ns01 ~]$ sudo ss -tulpn
Netid        State         Recv-Q         Send-Q                 Local Address:Port                 Peer Address:Port        Process                                                          
udp          UNCONN        0              0                      192.168.50.10:53                        0.0.0.0:*            users:(("named",pid=9401,fd=21))                                
udp          UNCONN        0              0                            0.0.0.0:111                       0.0.0.0:*            users:(("rpcbind",pid=669,fd=5),("systemd",pid=1,fd=49))        
udp          UNCONN        0              0                          127.0.0.1:323                       0.0.0.0:*            users:(("chronyd",pid=723,fd=5))                                
udp          UNCONN        0              0                              [::1]:53                           [::]:*            users:(("named",pid=9401,fd=24))                                
udp          UNCONN        0              0                               [::]:111                          [::]:*            users:(("rpcbind",pid=669,fd=7),("systemd",pid=1,fd=51))        
udp          UNCONN        0              0                              [::1]:323                          [::]:*            users:(("chronyd",pid=723,fd=6))                                
tcp          LISTEN        0              10                     192.168.50.10:53                        0.0.0.0:*            users:(("named",pid=9401,fd=22))                                
tcp          LISTEN        0              128                          0.0.0.0:22                        0.0.0.0:*            users:(("sshd",pid=1186,fd=7))                                  
tcp          LISTEN        0              4096                         0.0.0.0:111                       0.0.0.0:*            users:(("rpcbind",pid=669,fd=4),("systemd",pid=1,fd=48))        
tcp          LISTEN        0              4096                   192.168.50.10:953                       0.0.0.0:*            users:(("named",pid=9401,fd=26))                                
tcp          LISTEN        0              128                             [::]:22                           [::]:*            users:(("sshd",pid=1186,fd=8))                                  
tcp          LISTEN        0              4096                            [::]:111                          [::]:*            users:(("rpcbind",pid=669,fd=6),("systemd",pid=1,fd=50))        
tcp          LISTEN        0              10                             [::1]:53                           [::]:*            users:(("named",pid=9401,fd=25))                                
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sudo ss -tulpn | grep :53
udp   UNCONN 0      0      192.168.50.10:53        0.0.0.0:*    users:(("named",pid=9401,fd=21))                        
udp   UNCONN 0      0              [::1]:53           [::]:*    users:(("named",pid=9401,fd=24))                        
tcp   LISTEN 0      10     192.168.50.10:53        0.0.0.0:*    users:(("named",pid=9401,fd=22))                        
tcp   LISTEN 0      10             [::1]:53           [::]:*    users:(("named",pid=9401,fd=25))                        
[vagrant@ns01 ~]$ 


[vagrant@ns02 ~]$ sudo ss -tulpn
Netid        State         Recv-Q         Send-Q                 Local Address:Port                 Peer Address:Port        Process                                                          
udp          UNCONN        0              0                          127.0.0.1:323                       0.0.0.0:*            users:(("chronyd",pid=723,fd=5))                                
udp          UNCONN        0              0                      192.168.50.11:53                        0.0.0.0:*            users:(("named",pid=8875,fd=21))                                
udp          UNCONN        0              0                            0.0.0.0:111                       0.0.0.0:*            users:(("rpcbind",pid=669,fd=5),("systemd",pid=1,fd=48))        
udp          UNCONN        0              0                              [::1]:323                          [::]:*            users:(("chronyd",pid=723,fd=6))                                
udp          UNCONN        0              0                              [::1]:53                           [::]:*            users:(("named",pid=8875,fd=24))                                
udp          UNCONN        0              0                               [::]:111                          [::]:*            users:(("rpcbind",pid=669,fd=7),("systemd",pid=1,fd=50))        
tcp          LISTEN        0              10                     192.168.50.11:53                        0.0.0.0:*            users:(("named",pid=8875,fd=22))                                
tcp          LISTEN        0              4096                   192.168.50.11:953                       0.0.0.0:*            users:(("named",pid=8875,fd=26))                                
tcp          LISTEN        0              128                          0.0.0.0:22                        0.0.0.0:*            users:(("sshd",pid=1186,fd=7))                                  
tcp          LISTEN        0              4096                         0.0.0.0:111                       0.0.0.0:*            users:(("rpcbind",pid=669,fd=4),("systemd",pid=1,fd=47))        
tcp          LISTEN        0              10                             [::1]:53                           [::]:*            users:(("named",pid=8875,fd=25))                                
tcp          LISTEN        0              128                             [::]:22                           [::]:*            users:(("sshd",pid=1186,fd=8))                                  
tcp          LISTEN        0              4096                            [::]:111                          [::]:*            users:(("rpcbind",pid=669,fd=6),("systemd",pid=1,fd=49))        
[vagrant@ns02 ~]$ 
[vagrant@ns02 ~]$ sudo ss -tulpn | grep :53
udp   UNCONN 0      0      192.168.50.11:53        0.0.0.0:*    users:(("named",pid=8875,fd=21))                        
udp   UNCONN 0      0              [::1]:53           [::]:*    users:(("named",pid=8875,fd=24))                        
tcp   LISTEN 0      10     192.168.50.11:53        0.0.0.0:*    users:(("named",pid=8875,fd=22))                        
tcp   LISTEN 0      10             [::1]:53           [::]:*    users:(("named",pid=8875,fd=25))                        
[vagrant@ns02 ~]$ 
```

Корректируем файл /etc/resolv.conf на обоих клиентах, чтобы каждый из них работал со своим DNS сервером:

```
[vagrant@ns01 ~]$ cat /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.50.10
[vagrant@ns01 ~]$ 


[vagrant@ns02 ~]$ cat /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.50.11
[vagrant@ns02 ~]$ 
```

Добавляем в зону сервера web1 и web2, увеличиваем serial на +1, чтобы DNS восприняли внесённые изменения в зону :

```
[vagrant@ns01 ~]$ sudo cat /etc/named/named.dns.lab
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201408 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11
;Web
web1            IN      A       192.168.50.15
web2            IN      A       192.168.50.16

[vagrant@ns01 ~]$ 
```

Для обращаемся с client и client2 к DNS-серверам утилитой dig с параметрами по умолчанию:

С ВМ client:

```
[vagrant@client ~]$ dig web1.dns.lab

; <<>> DiG 9.16.50-RH <<>> web1.dns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 57554
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: b1948a5c8e080a98010000006b0465a25b527ae29b4b6f96 (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; Query time: 0 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 16:11:14 UTC 2026
;; MSG SIZE  rcvd: 85

[vagrant@client ~]$ 

```

С ВМ client2:

```
[vagrant@client2 ~]$ dig web1.dns.lab

; <<>> DiG 9.16.50-RH <<>> web1.dns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 17664
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 6c62673b549780ab010000006b0465faec275345887e44f5 (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; AUTHORITY SECTION:
.			10800	IN	SOA	a.root-servers.net. nstld.verisign-grs.com. 2026112300 1800 900 604800 86400

;; Query time: 2844 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Mon Nov 23 16:12:42 UTC 2026
;; MSG SIZE  rcvd: 144

[vagrant@client2 ~]$ 
```

В запросах видно, что с дефолтными параметрами утилита dig обращается с client к серверу ns01, а с client2 -  к серверу ns02.

Для явного указания DNS-сервера нужно указывать его адрес в качестве параметра, например, чтобы с client2 обратиться к серверу ns01:

```
[vagrant@client2 ~]$ dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.16.50-RH <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 28272
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: a807df3a31fffedf010000006b04677e80c90720575a0a26 (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 16:19:10 UTC 2026
;; MSG SIZE  rcvd: 85

[vagrant@client2 ~]$ 
```


## 2. Настраиваем split-dns

Для этого создаём дополнительный файл зоны named.dns.lab.client (в нём отсутсвует определение сервера www2 ):

```
[vagrant@ns01 ~]$ sudo cat > /etc/named/named.dns.lab
$TTL 3600
$ORIGIN newdns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201008 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;WWW
www             IN      A       192.168.50.15
www             IN      A       192.168.50.16
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ sudo cat /etc/named/named.dns.lab.client
$TTL 3600
$ORIGIN dns.lab.
@               IN      SOA     ns01.dns.lab. root.dns.lab. (
                            2711201407 ; serial
                            3600       ; refresh (1 hour)
                            600        ; retry (10 minutes)
                            86400      ; expire (1 day)
                            600        ; minimum (10 minutes)
                        )

                IN      NS      ns01.dns.lab.
                IN      NS      ns02.dns.lab.

; DNS Servers
ns01            IN      A       192.168.50.10
ns02            IN      A       192.168.50.11

;Web
web1            IN      A       192.168.50.15

[vagrant@ns01 ~]$ 
```

Генерируем два ключа TSIG:

```
[vagrant@ns01 ~]$ tsig-keygen
key "tsig-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ tsig-keygen
key "tsig-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};
[vagrant@ns01 ~]$
```

Изменяем файл /etc/named.conf на следующее содержание со сконфигурированными view для различных acl :

```
vagrant@ns01 ~]$ sudo cat /etc/named.conf
options {

    // На каком порту и IP-адресе будет работать служба 
	listen-on port 53 { 192.168.50.10; };
	listen-on-v6 port 53 { ::1; };

    // Указание каталогов с конфигурационными файлами
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";

    // Указание настроек DNS-сервера
    // Разрешаем серверу быть рекурсивным
	recursion yes;
    // Указываем сети, которым разрешено отправлять запросы серверу
	allow-query     { any; };
    // Каким сетям можно передавать настройки о зоне
    allow-transfer { any; };
    
    // dnssec
//	dnssec-enable yes;
	dnssec-validation yes;

    // others
	bindkeys-file "/etc/named.iscdlv.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// RNDC Control for client
key "rndc-key" {
    algorithm hmac-md5;
    secret "GrtiE9kz16GK+OKKU/qJvQ==";
};
controls {
        inet 192.168.50.10 allow { 192.168.50.15; 192.168.50.16; } keys { "rndc-key"; }; 
};

key "client-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};
key "client2-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};

// ZONE TRANSFER WITH TSIG
include "/etc/named.zonetransfer.key"; 

server 192.168.50.11 {
    keys { "zonetransfer.key"; };
};
// Указание Access листов 
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
// Настройка первого view 
view "client" {
    // Кому из клиентов разрешено подключаться, нужно указать имя access-листа
    match-clients { client; };

    // Описание зоны dns.lab для client
    zone "dns.lab" {
        // Тип сервера — мастер
        type master;
        // Добавляем ссылку на файл зоны, который создали в прошлом пункте
        file "/etc/named/named.dns.lab.client";
        // Адрес хостов, которым будет отправлена информация об изменении зоны
        also-notify { 192.168.50.11 key client-key; };
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        file "/etc/named/named.newdns.lab";
        also-notify { 192.168.50.11 key client-key; };
    };
};

// Описание view для client2
view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        type master;
        file "/etc/named/named.dns.lab";
        also-notify { 192.168.50.11 key client2-key; };
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        file "/etc/named/named.dns.lab.rev";
        also-notify { 192.168.50.11 key client2-key; };
    };
};

// Зона any, указана в файле самой последней
view "default" {
    match-clients { any; };

    // root zone
    zone "." IN {
        type hint;
        file "named.ca";
    };

    // zones like localhost
    include "/etc/named.rfc1912.zones";
    // root DNSKEY
    include "/etc/named.root.key";

    // dns.lab zone
    zone "dns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab";
    };

    // dns.lab zone reverse
    zone "50.168.192.in-addr.arpa" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.dns.lab.rev";
    };

    // ddns.lab zone
    zone "ddns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        allow-update { key "zonetransfer.key"; };
        file "/etc/named/named.ddns.lab";
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/named/named.newdns.lab";
    };
};

[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ sudo chown root:named /etc/named/named.dns.lab.client
[vagrant@ns01 ~]$ sudo chown root:named /etc/named/named.dns.lab
[vagrant@ns01 ~]$ sudo chmod 660 /etc/named/named.dns.lab.client
[vagrant@ns01 ~]$ sudo chmod 660 /etc/named/named.dns.lab
[vagrant@ns01 ~]$ 
[vagrant@ns01 ~]$ sudo ls -l /etc/named/
total 20
-rw-rw----. 1 root named 600 Nov 23 11:26 named.ddns.lab
-rw-rw----. 1 root named 697 Nov 23 13:24 named.dns.lab
-rw-rw----. 1 root named 652 Nov 23 13:48 named.dns.lab.client
-rw-rw----. 1 root named 625 Nov 23 11:26 named.dns.lab.rev
-rw-rw----. 1 root named 700 Nov 23 13:37 named.newdns.lab
[vagrant@ns01 ~]$
[vagrant@ns01 ~]$ sudo systemctl restart named
[vagrant@ns01 ~]$ 
```

## 3. Проверка работы Split-DNS

3.1 Первая проверка заключается в проверки работы acl в зависимости от IP-адресов обращающихся к нему клиентов.

Проверяем разрешение имён хостов ns01, ns02, web1 и web2 с клиента client (IP-адрес 192.168.50.15)
```
[vagrant@client ~]$ ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host 
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
    inet6 fd17:625c:f037:2:2079:cbe7:fae3:3756/64 scope global dynamic noprefixroute 
    inet6 fe80::5348:2850:35cd:1607/64 scope link noprefixroute 
    inet 192.168.50.15/24 brd 192.168.50.255 scope global noprefixroute eth1
    inet6 fe80::a00:27ff:fe20:9045/64 scope link 
[vagrant@client ~]$ ping 192.168.50.10
PING 192.168.50.10 (192.168.50.10) 56(84) bytes of data.
64 bytes from 192.168.50.10: icmp_seq=1 ttl=64 time=0.931 ms
64 bytes from 192.168.50.10: icmp_seq=2 ttl=64 time=1.10 ms
^C
--- 192.168.50.10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1006ms
rtt min/avg/max/mdev = 0.931/1.015/1.099/0.084 ms
[vagrant@client ~]$ 
[vagrant@client ~]$ ping ns01.dns.lab
PING ns01.dns.lab (192.168.50.10) 56(84) bytes of data.
64 bytes from 192.168.50.10 (192.168.50.10): icmp_seq=1 ttl=64 time=0.689 ms
64 bytes from 192.168.50.10 (192.168.50.10): icmp_seq=2 ttl=64 time=1.13 ms
64 bytes from 192.168.50.10 (192.168.50.10): icmp_seq=3 ttl=64 time=1.14 ms
^C
--- ns01.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 0.689/0.987/1.139/0.210 ms
[vagrant@client ~]$
[vagrant@client ~]$ ping ns02.dns.lab
PING ns02.dns.lab (192.168.50.11) 56(84) bytes of data.
64 bytes from 192.168.50.11 (192.168.50.11): icmp_seq=1 ttl=64 time=0.743 ms
64 bytes from 192.168.50.11 (192.168.50.11): icmp_seq=2 ttl=64 time=1.14 ms
^C
--- ns02.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1006ms
rtt min/avg/max/mdev = 0.743/0.942/1.142/0.199 ms
[vagrant@client ~]$
[vagrant@client ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.043 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.185 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.145 ms
^C
--- web1.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 0.043/0.124/0.185/0.059 ms
[vagrant@client ~]$ ping web2.dns.lab
ping: web2.dns.lab: Name or service not known
[vagrant@client ~]$
```

Видно, что из четырёх запросов с client видны ns01, ns02, web1 ; при этом web2 не виден.

Аналогично проверяем разрешение имён хостов ns01, ns02, web1 и web2 с клиента client2 (IP-адрес 192.168.50.16)
```
[vagrant@client2 ~]$ ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host 
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute eth0
    inet6 fd17:625c:f037:2:1196:dfd7:a9f8:f817/64 scope global dynamic noprefixroute 
    inet6 fe80::2efa:4d63:34b4:80eb/64 scope link noprefixroute 
    inet 192.168.50.16/24 brd 192.168.50.255 scope global noprefixroute eth1
    inet6 fe80::a00:27ff:feb1:3534/64 scope link 
[vagrant@client2 ~]$
vagrant@client2 ~]$ ping ns01.dns.lab
PING ns01.dns.lab (192.168.50.10) 56(84) bytes of data.
64 bytes from ns01.dns.lab (192.168.50.10): icmp_seq=1 ttl=64 time=0.708 ms
64 bytes from ns01.dns.lab (192.168.50.10): icmp_seq=2 ttl=64 time=1.18 ms
64 bytes from ns01.dns.lab (192.168.50.10): icmp_seq=3 ttl=64 time=1.18 ms
^C
--- ns01.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2011ms
rtt min/avg/max/mdev = 0.708/1.021/1.180/0.221 ms
[vagrant@client2 ~]$ 
[vagrant@client2 ~]$ ping ns02.dns.lab
PING ns02.dns.lab (192.168.50.11) 56(84) bytes of data.
64 bytes from ns02.dns.lab (192.168.50.11): icmp_seq=1 ttl=64 time=1.10 ms
64 bytes from ns02.dns.lab (192.168.50.11): icmp_seq=2 ttl=64 time=1.28 ms
64 bytes from ns02.dns.lab (192.168.50.11): icmp_seq=3 ttl=64 time=1.15 ms
^C
--- ns02.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 1.098/1.177/1.280/0.076 ms
[vagrant@client2 ~]$ 
[vagrant@client2 ~]$ ping www1.dns.lab
ping: www1.dns.lab: Name or service not known
[vagrant@client2 ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=1.79 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=1.21 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=3 ttl=64 time=1.10 ms
^C
--- web1.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 1.104/1.369/1.794/0.303 ms
[vagrant@client2 ~]$ ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.354 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.086 ms
64 bytes from client2 (192.168.50.16): icmp_seq=3 ttl=64 time=0.107 ms
^C
--- web2.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2011ms
rtt min/avg/max/mdev = 0.086/0.182/0.354/0.121 ms
[vagrant@client2 ~]$

```

Видно, что из четырёх запросов с client видны все четыре ns01, ns02, web1, web2 - в соответствии со сконфигурированными
view, acl и зонами в конфигурации Split-DNS:

- клиент client с IP-адресом 192.168.50.15 видит зону dns.lab из файла /etc/named/named.dns.lab.client (в нём присутствуют только сервер web1)
- клиент client2 с IP-адресом 192.168.50.16 видит зону dns.lab из файла /etc/named/named.dns.lab (в нём присутствуют оба сервера web1 и web2)
```
// Указание Access листов 
acl client { !key client2-key; key client-key; 192.168.50.15; };
acl client2 { !key client-key; key client2-key; 192.168.50.16; };
// Настройка первого view 
view "client" {
    // Кому из клиентов разрешено подключаться, нужно указать имя access-листа
    match-clients { client; };

    // Описание зоны dns.lab для client
    zone "dns.lab" {
        <...>
        file "/etc/named/named.dns.lab.client";
        <...>
    };

    <...>
};

// Описание view для client2
view "client2" {
    match-clients { client2; };

    // dns.lab zone
    zone "dns.lab" {
        <...>
        file "/etc/named/named.dns.lab";
        <...>
    };

    <...>
};
```

Вывод: конфигурация Split-DNS работает в соответствии с IP-адресами отправителей запросов DNS.

##### 3.2 Вторая проверка заключается в проверке работы acl в зависимости от наличия сконфигурированных TSIG-ключей у обращающихся к нему клиентов.

В прошом тесте 3.1 хост client с IP-адресом 192.168.50.16 не видел хост web2 в зоне dns.lab исходя из сконфигурированного в acl IP-адреса.

Для проверки доступа с использованием TSIG-ключей:

копируем ранее сгенерированные и сконфигурированные в /etc/named.conf TSIG-ключи на ВМ client. и запускаем запросы
утилитой dig с использованием TSIG-ключей client-key и client2-key:
```
[vagrant@client ~]$ cat client-key.key
key "client-key" {
    algorithm hmac-sha256;
    secret "IQg171Ht4mdGYcjjYKhI9gSc1fhoxzHZB+h2NMtyZWY=";
};
[vagrant@client ~]$ 
[vagrant@client ~]$ cat client2-key.key
key "client2-key" {
    algorithm hmac-sha256;
    secret "m7r7SpZ9KBcA4kOl1JHQQnUiIlpQA1IJ9xkBHwdRAHc=";
};
[vagrant@client ~]$ 

[vagrant@client ~]$ dig @192.168.50.10 -k client-key.key web1.dns.lab

; <<>> DiG 9.16.50-RH <<>> @192.168.50.10 -k client-key.key web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 59752
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 6677277797359dd2010000006b045d819586b04908883ced (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; TSIG PSEUDOSECTION:
client-key.		0	ANY	TSIG	hmac-sha256. 1795448193 300 32 uR0WR6cp6vD5lyf0gupLOp01vzVlaaJciCl45IanGss= 59752 NOERROR 0 

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 15:36:33 UTC 2026
;; MSG SIZE  rcvd: 168

[vagrant@client ~]$ 
[vagrant@client ~]$ dig @192.168.50.10 -k client-key.key web2.dns.lab

; <<>> DiG 9.16.50-RH <<>> @192.168.50.10 -k client-key.key web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 29727
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: e114e23191f7e963010000006b045d90681f31bc2388f3e7 (good)
;; QUESTION SECTION:
;web2.dns.lab.			IN	A

;; AUTHORITY SECTION:
dns.lab.		600	IN	SOA	ns01.dns.lab. root.dns.lab. 2711201407 3600 600 86400 600

;; TSIG PSEUDOSECTION:
client-key.		0	ANY	TSIG	hmac-sha256. 1795448208 300 32 3YDbuV8T2biPKSUctZO8FLBYDbpI61IJDr8pxe/XAHM= 29727 NOERROR 0 

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 15:36:48 UTC 2026
;; MSG SIZE  rcvd: 198

[vagrant@client ~]$ 
[vagrant@client ~]$ dig @192.168.50.10 -k client2-key.key web1.dns.lab

; <<>> DiG 9.16.50-RH <<>> @192.168.50.10 -k client2-key.key web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 58039
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 5a87534c88dc8a71010000006b045da775391ab0980d1cf0 (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; TSIG PSEUDOSECTION:
client2-key.		0	ANY	TSIG	hmac-sha256. 1795448231 300 32 s3qDCLd47INdF6ZTPpvXCQ0HmMW+NhOtBzexLkWmm48= 58039 NOERROR 0 

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 15:37:11 UTC 2026
;; MSG SIZE  rcvd: 169

[vagrant@client ~]$ dig @192.168.50.10 -k client2-key.key web2.dns.lab

; <<>> DiG 9.16.50-RH <<>> @192.168.50.10 -k client2-key.key web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43129
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 2

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: fade563ca6a9f972010000006b045daea1a61c98b43c7885 (good)
;; QUESTION SECTION:
;web2.dns.lab.			IN	A

;; ANSWER SECTION:
web2.dns.lab.		3600	IN	A	192.168.50.16

;; TSIG PSEUDOSECTION:
client2-key.		0	ANY	TSIG	hmac-sha256. 1795448238 300 32 C9O/CRo2AFM8Fwy+KiCv0RKq0lQuIcOYjB+s0L2j4B4= 43129 NOERROR 0 

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Mon Nov 23 15:37:18 UTC 2026
;; MSG SIZE  rcvd: 169

[vagrant@client ~]$
```

В выводе видно, что при запросе с использованием TSIG-ключа client-key ВМ client видит только хост web1 в зоне dns.lab, но не видит хост web2.
А при запросе с использованием TSIG-ключа client2-key ВМ client видит оба хоста web1 и web2 в зоне dns.lab.
Это также соответствует конфигурации тех же acl в конфигурации /etc/named.conf сервера bind.


## 4. Конфигурирование Split-DNS с помощью ansible

По ссылке https://github.com/kosogoroff/vagrant-bind.git
выложен репозиторий для создания лабораторного стенда со сконфигурированным Split-DNS.

ansible playbook также приведён ниже:

```
admin_insta11@mv334 vagrant-bind]$ tree
.
├── provisioning
│   ├── client-motd
│   ├── client-resolv.conf
│   ├── master-named.conf
│   ├── named.ddns.lab
│   ├── named.dns.lab
│   ├── named.dns.lab.client
│   ├── named.dns.lab.rev
│   ├── named.newdns.lab
│   ├── named.zonetransfer.key
│   ├── playbook.yml
│   ├── rndc.conf
│   ├── servers-resolv.conf.j2
│   ├── slave-named.conf
│   └── zonetransfer.key
├── README.md
└── Vagrantfile

1 directory, 16 files
[admin_insta11@mv334 vagrant-bind]$ 
[admin_insta11@mv334 vagrant-bind]$ cat Vagrantfile 
# -*- mode: ruby -*-
# vi: set ft=ruby :
BOX_NAME = ENV['VAGRANT_BOX'] || 'centos/7'

Vagrant.configure(2) do |config|
  config.vm.box = BOX_NAME

  config.vm.provision "ansible" do |ansible|
    ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end


  config.vm.provider "virtualbox" do |v|
	  v.memory = 1024
  end

  config.vm.define "ns01" do |ns01|
    ns01.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "dns"
    ns01.vm.hostname = "ns01"
  end

  config.vm.define "ns02" do |ns02|
    ns02.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "dns"
    ns02.vm.hostname = "ns02"
  end

  config.vm.define "client" do |client|
    client.vm.network "private_network", ip: "192.168.50.15", virtualbox__intnet: "dns"
    client.vm.hostname = "client"
  end

  config.vm.define "client2" do |client2|
    client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
    client2.vm.hostname = "client2"
  end


end
[admin_insta11@mv334 vagrant-bind]$ 
[admin_insta11@mv334 vagrant-bind]$ cat provisioning/playbook.yml 
---
- hosts: all
  become: yes
  tasks:
  - name: install packages
    yum: name={{ item }} state=latest 
    with_items:
      - bind
      - bind-utils
#      - ntp

  - name: copy transferkey to all servers and the client
    copy: src=named.zonetransfer.key dest=/etc/named.zonetransfer.key owner=root group=named mode=0644

- hosts: ns01
  become: yes
  tasks:
  - name: copy named.conf
    copy: src=master-named.conf dest=/etc/named.conf owner=root group=named mode=0640
  - name: copy zones
    copy: src={{ item }} dest=/etc/named/ owner=root group=named mode=0660
    with_fileglob:
      - named.d*
      - named.newdns.lab
  - name: copy resolv.conf to the servers
    template: 
      src: servers-resolv.conf.j2 
      dest: /etc/resolv.conf 
      owner: root 
      group: root
      mode: 0644

  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes

- hosts: ns02
  become: yes
  tasks:
  - name: copy named.conf
    copy: src=slave-named.conf dest=/etc/named.conf owner=root group=named mode=0640
  - name: copy resolv.conf to the servers
    copy: src=servers-resolv.conf.j2 dest=/etc/resolv.conf owner=root group=root mode=0644

  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes
    
- hosts: client, client2
  become: yes
  tasks:
  - name: copy resolv.conf to the client
    copy: src=client-resolv.conf dest=/etc/resolv.conf owner=root group=root mode=0644
  - name: copy rndc conf file
    copy: src=rndc.conf dest=/home/vagrant/rndc.conf owner=vagrant group=vagrant mode=0644
  - name: copy motd to the client
    copy: src=client-motd dest=/etc/motd owner=root group=root mode=0644
[admin_insta11@mv334 vagrant-bind]$ 

```
