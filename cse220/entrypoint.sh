#!/bin/bash
#set -x #echo on

useradd -u $user_id -o -m $username || true
groupmod -g $group_id $username
cd /home/$username
if [ ! -d "/home/$username/scarab" ]; then
  sudo -u $username touch /home/$username/.ssh/known_hosts
  sudo -u $username /bin/bash -c "ssh-keyscan github.com >> /home/$username/.ssh/known_hosts"
  sudo -u $username git clone https://github.com/Litz-Lab/scarab.git
fi

pip3 install -r /home/$username/scarab/bin/requirements.txt
sudo -u $username rm /home/$username/.ssh/id_rsa
sudo -u $username rm /home/$username/.ssh/known_hosts
