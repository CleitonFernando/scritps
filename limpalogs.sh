#!/bin/bash
find /root/.log -type f -mtime +13 -delete

find /home/gix/.log -type f -mtime +13 -delete

find /usr/local/jakarta-tomcat-*/logs -type f -mtime +13 -delete

find /opt/tomcat-*/logs -type f -mtime +13 -delete

find /shx/shx-pyxis/*-logs/ -type f -mtime +13 -delete

exit 0