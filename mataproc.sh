#!/bin/bash
export PGPASSWORD="suasenha"
mkdir -p /BACKUP/.temp > /dev/null 2>&1
chown postgres.postgres /BACKUP/.temp > /dev/null 2>&1
chmod 777 /BACKUP/.temp > /dev/null 2>&1
TEMP=/BACKUP/.temp
MAIORBASE=`psql -U postgres -p 5432 -c "select * from (select datname,( select pg_database_size from pg_database_size(datname) ) as tamanho,( select pg_database_size from pg_database_size(datname) ) as tamanho_ordem from pg_database ) aux order by tamanho_ordem desc" | sed '/TESTE/Id' | grep -n ^ | grep ^3: | cut -d: -f2 | awk '{print $1}'`
CLIENTE=`psql -U postgres $MAIORBASE -c "select cadanome from arqcada where cadatipo='EMPE' order by cadacodi" | grep -n ^ | grep ^3: | cut -d: -f2`

if [ -e "/DADOS/recovery.conf" ]
        then
                SRV="Replicacao"
        elif [ $MAIORBASE = "GIX" ]
		then
                	SRV="Banco de Dados"
	else
		SRV="Outros"
fi
PID=`ps -eaf | grep -E "/tmp|\./" | grep -v grep | grep -vE "/bin/java|/usr/share/man/" | grep -v "tail -f" | grep -v "ls /tmp" | grep -vE "yum|apt|dpkg|rpm" | grep -v "/BACKUP/tmp" | grep -v "/tmp/crontab." | grep -v "\./runserver.py" | awk '{print $2}'`
if [[ "" !=  "$PID" ]]; then
  LOG=$TEMP/procmalicioso.tmp
  QTDPROC=`echo $PID | wc -w`
  echo -e "Quantidade de processos maliciosos encontrados: $QTDPROC" > $LOG
  echo >> $LOG
  ps aux | grep -E "/tmp|\./" | grep -v grep | grep -vE "/bin/java|/usr/share/man/" | grep -v "tail -f" | grep -v "ls /tmp" | grep -vE "yum|apt|dpkg|rpm" | grep -v "/BACKUP/tmp" | grep -v "/tmp/crontab." | grep -v "\./runserver.py" >> $LOG
  mail -s "Processos Maliciosos ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $LOG
  killall -9 sh > /dev/null 2>&1
  killall -9 wget > /dev/null 2>&1
  kill -9 $PID > /dev/null 2>&1
  rm -rf $TEMP/procmalicioso.tmp
fi
