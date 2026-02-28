#!/bin/sh

# https://knowledge.workspace.google.com/admin/security/about-authentication-methods
# https://knowledge.workspace.google.com/admin/security/set-up-spf
# TXT Record @ v=spf1 a:mail.example.com ~all Automatic
# https://knowledge.workspace.google.com/admin/security/set-up-dmarc
# TXT Record _dmarc v=DMARC1; p=reject; rua=mailto:postmaster@andrewmcwatters.com, mailto:dmarc@andrewmcwatters.com; pct=100; adkim=s; aspf=s Automatic

# https://documentation.ubuntu.com/server/how-to/mail-services/install-postfix/
sudo apt-get update
sudo apt-get -y install postfix

# sudo nano /etc/mailname e.g. mydomain.org
# sudo postconf -e "mydestination = example.com, $(postconf -h mydestination)"

# https://documentation.ubuntu.com/server/how-to/mail-services/install-postfix/#smtp-authentication
# https://documentation.ubuntu.com/server/how-to/mail-services/install-postfix/#configure-smtp-authentication
sudo postconf -e 'smtpd_sasl_type = dovecot'
sudo postconf -e 'smtpd_sasl_path = private/auth'
sudo postconf -e 'smtpd_sasl_local_domain ='
sudo postconf -e 'smtpd_sasl_security_options = noanonymous'
sudo postconf -e 'broken_sasl_auth_clients = yes'
sudo postconf -e 'smtpd_sasl_auth_enable = yes'
sudo postconf -e 'smtpd_recipient_restrictions = permit_sasl_authenticated,permit_mynetworks,reject_unauth_destination'
sudo sed -i '/^submission inet/,/^[^ ]/{s/#  -o syslog_name=postfix\/submission$/  -o syslog_name=postfix\/submission/}' /etc/postfix/master.cf

# https://certbot.eff.org/instructions?ws=other&os=ubuntufocal
sudo apt-get -y install certbot
# sudo certbot certonly --standalone -n --agree-tos -m name@example.com -d mail.example.com

# https://www.eff.org/deeplinks/2019/01/encrypting-web-encrypting-net-primer-using-certbot-secure-your-mailserver#:~:text=on%20each%20renewal.-,Postfix,-Run%20the%20following
# sudo postconf -e smtpd_tls_cert_file=/etc/letsencrypt/live/mail.example.com/fullchain.pem
# sudo postconf -e smtpd_tls_key_file=/etc/letsencrypt/live/mail.example.com/privkey.pem

# https://documentation.ubuntu.com/server/how-to/mail-services/install-dovecot/
sudo apt-get -y install dovecot-imapd dovecot-lmtpd

# https://documentation.ubuntu.com/server/how-to/mail-services/install-postfix/#configure-sasl
sudo sed -i '\|unix_listener /var/spool/postfix/private/auth|{n;/user = postfix/!s|mode = 0660|mode = 0660\n    user = postfix\n    group = postfix|}' \
  /etc/dovecot/conf.d/10-master.conf
sudo sed -i 's|unix_listener lmtp {|unix_listener /var/spool/postfix/private/dovecot-lmtp {|' \
  /etc/dovecot/conf.d/10-master.conf
sudo sed -i 's/^#auth_username_format = %Lu$/auth_username_format = %Ln/' \
  /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's/^auth_mechanisms = plain$/auth_mechanisms = plain login/' \
  /etc/dovecot/conf.d/10-auth.conf
sudo postconf -e 'mailbox_transport = lmtp:unix:private/dovecot-lmtp'

# https://www.eff.org/deeplinks/2019/01/encrypting-web-encrypting-net-primer-using-certbot-secure-your-mailserver#:~:text=information%20as%20well.-,Dovecot,-Most%20Linux%20distributions
# sudo sed -i 's|ssl_cert = </etc/dovecot/private/dovecot.pem|ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem|' /etc/dovecot/conf.d/10-ssl.conf
# sudo sed -i 's|ssl_key = </etc/dovecot/private/dovecot.key|ssl_key = </etc/letsencrypt/live/mail.example.com/privkey.pem|' /etc/dovecot/conf.d/10-ssl.conf

# https://doc.dovecot.org/2.4.2/core/config/quick.html#tldr-i-just-want-dovecot-running
sudo adduser --system --group vmail
sudo sed -i 's/#mail_uid =/mail_uid = vmail/' /etc/dovecot/conf.d/10-mail.conf
sudo sed -i 's/#mail_gid =/mail_gid = vmail/' /etc/dovecot/conf.d/10-mail.conf
sudo sed -i 's|#override_fields = home=/home/virtual/%u|override_fields = home=/home/virtual/%u|' /etc/dovecot/conf.d/auth-passwdfile.conf.ext
sudo mkdir -p /home/virtual
sudo chown vmail:vmail /home/virtual

# https://doc.dovecot.org/2.4.2/core/config/quick.html#virtual-users
# echo "user:$(doveadm pw -s SHA256-CRYPT)" > users
sudo mv users /etc/dovecot/
sudo sed -i 's/^!include auth-system.conf.ext/#!include auth-system.conf.ext/' /etc/dovecot/conf.d/10-auth.conf
sudo sed -i 's/#!include auth-passwdfile.conf.ext/!include auth-passwdfile.conf.ext/' /etc/dovecot/conf.d/10-auth.conf

# https://www.rfc-editor.org/rfc/rfc2142
# for alias in postmaster abuse dmarc; do
#     line="$alias@example.com user@example.com"
#     grep -qF "$line" /etc/postfix/virtual 2>/dev/null || echo "$line" | sudo tee -a /etc/postfix/virtual
# done
# sudo postmap /etc/postfix/virtual
sudo postconf -e 'virtual_alias_maps = hash:/etc/postfix/virtual'
sudo systemctl restart postfix.service

# https://doc.dovecot.org/2.4.2/core/config/quick.html#mail-location
sudo sed -i 's|mail_location = mbox:~/mail:INBOX=/var/mail/%u|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sudo systemctl restart dovecot.service
