#!/bin/bash

#check os
OS_RELEASE=`awk -F= '/^NAME/{print $2}' /etc/os-release`
if [ $OS_RELEASE != "openSUSE Leap" ]; then
    exit 0;
fi

user="user"
pass="pass"

#install odbc
zypper install iodbc asterisk-odbc libiodbc3 MyODBC-unixODBC

#show info
rpm -ql MyODBC-unixODBC
odbcinst -j

#setup odbc libs
:> /etc/unixODBC/odbcinst.ini
cat > /etc/unixODBC/odbcinst.ini << EOF
[MySQL]
Description=ODBC for MySQL
Driver=/usr/lib64/libmyodbc5.so
Setup=/usr/lib64/unixODBC/libodbcmyS.so
FileUsage=1
EOF

#setup asterisk odbc mysql driver
:> /etc/unixODBC/odbc.ini
cat > /etc/unixODBC/odbc.ini << EOF
[MySQL-asterisk]
description=MySQL ODBC Driver Testing
driver=MySQL
socket=/var/run/mysql/mysql.sock
server=localhost
user=$user
password=$pass
database=asterisk
port=3306
EOF

#/etc/asterisk/cdr.conf
#enable=yes
sed -i -e 's/;enable=yes/enable=yes/g' /etc/asterisk/cdr.conf

#setup asterisk res_odbc
:> /etc/asterisk/res_odbc.conf
cat > /etc/asterisk/res_odbc.conf << EOF
[ENV]

[asterisk]
enabled => yes
dsn => MySQL-asterisk
username => $user
password => $pass
EOF

#setup cdr_adaptive_odbc & add alias!
:> /etc/asterisk/cdr_adaptive_odbc.conf
cat > /etc/asterisk/cdr_adaptive_odbc.conf << EOF
[asterisk]
connection=asterisk
table=cdr
alias start => calldate
EOF

#setup cdr_odbc
:> /etc/asterisk/cdr_odbc.conf
cat > /etc/asterisk/cdr_odbc.conf << EOF
[global]
dsn=asterisk
loguniqueid=yes
dispositionstring=yes
table=cdr

usegmtime=no
hrtime=yes
newcdrcolumns=yes
EOF

mysql -p asterisk -e "
   CREATE TABLE cdr (
 id INT(11) UNSIGNED NOT NULL AUTO_INCREMENT,
 calldate DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
 clid VARCHAR(80) NOT NULL DEFAULT '',
 src VARCHAR(80) NOT NULL DEFAULT '',
 dst VARCHAR(80) NOT NULL DEFAULT '',
 dcontext VARCHAR(80) NOT NULL DEFAULT '',
 lastapp VARCHAR(200) NOT NULL DEFAULT '',
 lastdata VARCHAR(200) NOT NULL DEFAULT '',
 duration FLOAT UNSIGNED NULL DEFAULT NULL,
 billsec FLOAT UNSIGNED NULL DEFAULT NULL,
 disposition ENUM('ANSWERED','BUSY','FAILED','NO ANSWER','CONGESTION') NULL DEFAULT NULL,
 channel VARCHAR(50) NULL DEFAULT NULL,
 dstchannel VARCHAR(50) NULL DEFAULT NULL,
 amaflags VARCHAR(50) NULL DEFAULT NULL,
 accountcode VARCHAR(20) NULL DEFAULT NULL,
 uniqueid VARCHAR(32) NOT NULL DEFAULT '',
 userfield FLOAT UNSIGNED NULL DEFAULT NULL,
 answer DATETIME NOT NULL,
 end DATETIME NOT NULL,
 linkedid VARCHAR(32) NOT NULL default '',
 sequence VARCHAR(32) NOT NULL default '',
 peeraccount VARCHAR(32) NOT NULL default '',
 PRIMARY KEY (id),
 INDEX calldate (calldate),
 INDEX dst (dst),
 INDEX src (src),
 INDEX dcontext (dcontext),
 INDEX clid (clid)
)
COLLATE='utf8_bin'
ENGINE=InnoDB;
"
asterisk -rx 'module reload'

#create cdr table
: << '--MULTILINE-COMMENT--'

mysql -p asterisk -e 'GRANT INSERT
   ON asterisk.cdr*
   TO $user@localhost
   IDENTIFIED BY '$pass';
--MULTILINE-COMMENT--
