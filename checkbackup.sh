#!/bin/bash
export PGPASSWORD="suasenha"
mkdir -p /BACKUP/.temp > /dev/null 2>&1
chown postgres.postgres /BACKUP/.temp > /dev/null 2>&1
chmod 777 /BACKUP/.temp > /dev/null 2>&1
TEMP=/BACKUP/.temp

MAIORBASE=`psql -U postgres -p 5432 -c "select * from (select datname,( select pg_database_size from pg_database_size(datname) ) as tamanho,( select pg_database_size from pg_database_size(datname) ) as tamanho_ordem from pg_database ) aux order by tamanho_ordem desc" | sed '/TESTE/Id' | grep -n ^ | grep ^3: | cut -d: -f2 | awk '{print $1}'`
CLIENTE=`psql -U postgres -p 5432 $MAIORBASE -c "select cadanome from arqcada where cadatipo='EMPE' order by cadacodi" | grep -n ^ | grep ^3: | cut -d: -f2`

if [ -e "/DADOS/recovery.conf" ]
        then
                SRV="Replicacao"
        elif [ $MAIORBASE = "GIX" ]
		then
                	SRV="Banco de Dados"
	else
		SRV="Outros"
fi

backupvelho(){
#PID=`ps awx | grep -E "vacuum|backup|limpa" | grep -v grep | grep -v autovacuum | grep -v prioridade | awk '{print$1}'`
#if [[ "" !=  "$PID" ]]; then
#       kill $PID > /dev/null 2>&1
#fi
  LOG=$TEMP/backupvelho.tmp
  echo -e "Backup nao finalizado" > $LOG
  echo >> $LOG
  echo -e "Ultimo backup: $IDADEBACKUP" >> $LOG
  mail -s "BACKUP NAO FINALIZADO - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $LOG
  rm -f $TEMP/backupvelho.tmp
}

backupzero(){
  LOG=$TEMP/backupvelho.tmp
  echo -e "Pasta BACKUP em branco." > $LOG
  mail -s "BACKUP NAO CRIADO - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $LOG
  rm -f $TEMP/backupvelho.tmp
}

if [ ! -e /BACKUP/1/backup$MAIORBASE* ]
        then
                backupzero
else
        IDADEBACKUP=`find /BACKUP/1/ -name "backup$MAIORBASE*" -type f -mtime +0 -ls | head -1 | awk '{print$11}'`
        if [ ! -z $IDADEBACKUP ]
                then
                        backupvelho
        fi
fi
