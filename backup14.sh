#!/bin/bash

#################
# USO
#################
#
#   * As copias de seguranca sao armazenadas em '/BACKUP' por padrao,
#     Voce pode alterar a variavel $HOME se quiser trocar.
#
export PGPASSWORD="senha"

## Diretorio do Backup:
HOME=/BACKUP

## Declarar THREADS a usar:
THREADS=4

## Email do cliente:
EMAILCLIENTE=""

mkdir -p $HOME/.temp > /dev/null 2>&1
chown postgres.postgres $HOME/.temp > /dev/null 2>&1
chmod 777 $HOME/.temp > /dev/null 2>&1
TEMP=$HOME/.temp

mkdir -p $HOME/.BKPtemp > /dev/null 2>&1
chown postgres.postgres $HOME/.BKPtemp > /dev/null 2>&1
chmod 777 $HOME/.BKPtemp > /dev/null 2>&1
rm -rf $HOME/.BKPtemp/*
BKPTEMP=$HOME/.BKPtemp

### Lista com todas as bases para fazer backup:
#
#   * Para excecoes utilizar: | sed '/^NOMEDABASE/d'
#       Por padrao sao ignoradas as bases do PostgreSQL: postgres, template0, template1 e TESTE
#
databases(){
psql -U postgres -p 5432 -x -l | grep Nome | awk '{print $3}' | sed '/^postgres/d' | sed '/^template/d' | sed '/TESTE/Id' > $TEMP/lista.txt
if [ -s $TEMP/lista.txt ]
        then
                LISTA=`cat $TEMP/lista.txt`
        else
                psql -U postgres -p 5432 -x -l | grep Name | awk '{print $3}' | sed '/^postgres/d' | sed '/^template/d' | sed '/TESTE/Id' > $TEMP/lista.txt
                LISTA=`cat $TEMP/lista.txt`
        fi
}

#########################################################
# Voce *NAO* precisa modificar nada nas linhas abaixo.
#########################################################
# Comandos.
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'
DATE=`/bin/date "+%Y%m%d%H%M"`
MAIORBASE=`psql -U postgres -p 5432 -c "select * from (select datname,( select pg_database_size from pg_database_size(datname) ) as tamanho,( select pg_database_size from pg_database_size(datname) ) as tamanho_ordem from pg_database ) aux order by tamanho_ordem desc" | sed '/TESTE/Id' | grep -n ^ | grep ^3: | cut -d: -f2 | awk '{print $1}'`
CLIENTE=`psql -U postgres -p 5432 $MAIORBASE -c "select cadanome from arqcada where cadatipo='EMPE' order by cadacodi" | grep -n ^ | grep ^3: | cut -d: -f2`

if [ -e "/DADOS/main/standby.signal" ]
        then
                SRV="Replicacao"
                EXTRAPARAM="--no-synchronized-snapshots"
        elif [ $MAIORBASE = "GIX" ]
                then
                        SRV="Banco de Dados"
        else
                SRV="Outros"
fi

# Arquivos de log
LOGFILE="$TEMP/backup.log"
LOG="$HOME/log_backup.txt"

### Rotacao de arquivos de backup:
clean(){
        mkdir -p $HOME/3 2> /dev/null ; mv $HOME/2/* $HOME/3 2> /dev/null
        mkdir -p $HOME/2 2> /dev/null ; mv $HOME/1/* $HOME/2 2> /dev/null
}

### Dump
dump(){
        exec > >(tee $TEMP/desc.out) 2>&1
        echo "Inicio do backup da base: $db"
        SECONDS=0
        pg_dump -p 5432 -v -Z6 -U postgres $db -Fd -j$THREADS -f $BKPTEMP/backup$db-$DATE $EXTRAPARAM
        TESTEBKP=`echo $?`
        if [ $TESTEBKP == 0 ]
                then
                        echo -e "\nBACKUP FINALIZADO COM SUCESSO"
                        echo -e "\nInicio da checagem dos arquivos de backup da base: $db"
                        gzip -d -v -t $BKPTEMP/backup$db-$DATE/*.gz
                        TESTEBKP=`echo $?`
                        if [ $TESTEBKP == 0 ]
                                then
                                        echo -e "\nARQUIVOS DE BACKUP INTEGROS"
                                        cd $BKPTEMP && md5sum backup$db-$DATE/* | tee backup$db-$DATE/checksum.md5
                                        cd $BKPTEMP && tar -cvf backup$db-$DATE.tar backup$db-$DATE --remove-file
                                else
                                        echo -e "\nARQUIVOS DE BACKUP CORROMPIDO"
                                        cd $BKPTEMP && tar -cf backup$db-$DATE.tar backup$db-$DATE --remove-file
                        fi
                else
                        echo -e "\nFALHA NO PROCESSO DE BACKUP"
                        cd $BKPTEMP && tar -cf backup$db-$DATE.tar backup$db-$DATE --remove-file
        fi
        duration=$SECONDS
        (echo -n $(($duration / 3600))| awk '{ printf("%02d", $1) }'; echo -n $(($duration / 60 % 60))| awk '{ printf(":%02d", $1) }'; echo -n $(($duration % 60))| awk '{ printf(":%02d", $1) }') | tee $TEMP/tempo.out
}

### Teste de integridade do backup:
checkdb(){
        if [ $TESTEBKP == 0 ]
                then
                        tempo=`cat $TEMP/tempo.out`
                        cd $BKPTEMP && size=`du -sh backup$db-$DATE.tar | awk '{print $1}'`
                        cd $BKPTEMP && file=`ls backup$db-$DATE.tar`
                        echo -e "* Base: $db" >> $LOGFILE
                        echo -e "* Arquivo: $file" >>$LOGFILE
                        echo -e "* Tamanho: $size" >>$LOGFILE
                        echo -e "* Tempo: $tempo" >>$LOGFILE
                        echo -e "  + Integridade: [OK]" >> $LOGFILE
                        echo -e "    + HASH MD5: [`md5sum $BKPTEMP/backup$db-$DATE.tar | awk '{print $1}'`]" >> $LOGFILE
                        echo "----" >>$LOGFILE
                        if [ $db == $MAIORBASE ]
                                then
                                        pg_dumpall -r -v | gzip > $BKPTEMP/backupPG_ROLES-$DATE.sql.gz
                                        clean
                                        touch $TEMP/bkpGIXok.pid
                        fi
                else
                        echo "BACKUP ERRO"
                        cd $BKPTEMP && tar -cf backup$db-$DATE.tar backup$db-$DATE --remove-file
                        tempo=`cat $TEMP/tempo.out`
                        echo -e "* Base: $db" >> $LOGFILE
                        echo -e "* Tempo: $tempo" >>$LOGFILE
                        echo -e "  - Integridade: [FALHOU]" >> $LOGFILE
                        echo -e "    - Falha: [`tail -10 $TEMP/desc.out`]" >> $LOGFILE
                        echo "----" >>$LOGFILE
                        touch $TEMP/bkperro.pid
        fi
}

### Envio de aviso por e-mail
encerramento(){
        if [ -e "$TEMP/bkperro.pid" ]
                then
                        cat $LOGFILE >> $LOG
                        mail -s "BACKUP ERRO - Cliente: [$CLIENTE] Servidor: $SRV" suporteinfra@shx.com.br $EMAILCLIENTE < $LOGFILE
                        if [ -e "$TEMP/bkpGIXok.pid" ]
                                then
                                         mkdir -p $HOME/1 2> /dev/null ; mv $BKPTEMP/* /$HOME/1/ 2> /dev/null
                        fi
                else
                        cat $LOGFILE > $LOG
                        mkdir -p $HOME/1 2> /dev/null ; mv $BKPTEMP/* /$HOME/1/ 2> /dev/null
                        mail -s "BACKUP OK - Cliente: [$CLIENTE] Servidor: $SRV" suporteinfra@shx.com.br $EMAILCLIENTE < $LOGFILE
        fi
}

### Apaga arquivos temporarios usados.
fim(){
        if [ -e "$TEMP/bkperro.pid" ]
                then
                        rm -rf $TEMP/bkperro.pid $TEMP/bkpGIXok.pid
        else
                        rm -rf $TEMP/lista.txt $TEMP/backup.log $TEMP/bkpGIXok.pid $TEMP/tempo.out $TEMP/desc.out $TEMP/tempovacuum.out $TEMP/tempomanutencao.out $TEMP/inicio.out $BKPTEMP/*
        fi
}

#################
# EXECUCAO
#################

# Logging...
if [ -e $TEMP/inicio.out ]
        then
                echo "* Iniciado em: `cat $TEMP/inicio.out`" >$LOGFILE
        else
                echo "* Iniciado em: `/bin/date "+%d-%m-%Y [%H:%M]"`" >$LOGFILE
fi
echo "* Backup dir: $HOME " >>$LOGFILE
echo "* Threads utilizadas: $THREADS " >>$LOGFILE
echo "********************" >>$LOGFILE

if [ -e $TEMP/tempovacuum.out ]
        then
                tempovacuum=`cat $TEMP/tempovacuum.out`
                echo "* Tempo do VACUUM: $tempovacuum" >>$LOGFILE
                echo "********************" >>$LOGFILE
        elif [ -e $TEMP/tempomanutencao.out ]
                then
                        tempovacuum=`cat $TEMP/tempomanutencao.out`
                        echo "* Tempo do VACUUM + REINDEX: $tempovacuum" >>$LOGFILE
                        echo "********************" >>$LOGFILE
        else
                echo "* Nenhuma manutencao executada" >>$LOGFILE
                echo "********************" >>$LOGFILE
fi

# Dump
rm -f $HOME/3/* 2> /dev/null
databases
if [ -e "/DADOS/main/standby.signal" ]
        then
                psql -U postgres -p 5432 -d postgres -c 'select pg_xlog_replay_pause()'
fi
for db in $LISTA; do
        dump; sleep 3; checkdb
done
if [ -e "/DADOS/main/standby.signal" ]
        then
                psql -U postgres -p 5432 -d postgres -c 'select pg_xlog_replay_resume()'
fi
echo "* Finalizado em: `/bin/date "+%d-%m-%Y [%H:%M]"`" >>$LOGFILE
echo -e "********************\n" >>$LOGFILE
encerramento
fim

#################
# EOF
#################
