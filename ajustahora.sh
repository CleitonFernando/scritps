#!/bin/bash

/usr/sbin/ntpdate -u 0.br.pool.ntp.org || /usr/sbin/ntpdate -u 1.br.pool.ntp.org || /usr/sbin/ntpdate -u 2.br.pool.ntp.org || /usr/sbin/ntpdate -u 3.br.pool.ntp.org
