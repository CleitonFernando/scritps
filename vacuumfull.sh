#!/bin/bash

#################
# USO
#################
#
#   * As cópias de segurança das tabelas são armazenadas em '/BACKUP/.temp' por padrão,
#
export PGPASSWORD="suasenha"

THREADS=4

mkdir -p /BACKUP/.temp > /dev/null 2>&1
chown postgres.postgres /BACKUP/.temp > /dev/null 2>&1
chmod 777 /BACKUP/.temp > /dev/null 2>&1
TEMP=/BACKUP/.temp

mkdir -p $TEMP/log > /dev/null 2>&1
chown postgres.postgres $TEMP/log > /dev/null 2>&1
chmod 777 $TEMP/log > /dev/null 2>&1

### Lista com todas as bases para fazer backup:
#
#   * Para exceções utilizar: | sed '/^NOMEDABASE/d'
#       Por padrão são ignoradas as bases do PostgreSQL: template0
#
databases(){
psql -U postgres -p 5432 -x -l | grep Nome | awk '{print $3}' > $TEMP/lista.txt
if [ -s $TEMP/lista.txt ]
        then
                LISTA=`cat $TEMP/lista.txt`
        else
                psql -U postgres -p 5432 -x -l | grep Name | awk '{print $3}' > $TEMP/lista.txt
                LISTA=`cat $TEMP/lista.txt`
        fi
}

#########################################################
# Você *NÃO* precisa modificar nada nas linhas abaixo.
#########################################################
# Comandos.
export PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin'
LOG="$TEMP/log/vacuumfull.log"

# Antigo LIMPA.SH
dump_tbl(){
for db in $LISTA
        do
                cd $TEMP
                mkdir log > /dev/null 2>&1
                echo "inicio do LIMPA na base: $db" | tee $LOG
                pg_dump -U postgres -p 5432 -Z6 -t arqpdrb $db > $TEMP/log/arqpdrb-${db}_${DATE}.txt.gz 2> /dev/null
                psql $db -U postgres -p 5432 -c "begin; truncate arqpdrb; end;" 2> /dev/null
                psql $db -U postgres -p 5432 -c "begin; delete from arqstlo where stlohora < current_date; end;" 2> /dev/null
                psql $db -U postgres -p 5432 -c "begin; delete from arqlock where locksequ not in ( select stlosequ from arqstlo ); end;" 2> /dev/null
                psql $db -U postgres -p 5432 -c "begin; truncate arqfimp; end;" 2> /dev/null
        done
        echo "##--------------------------------------------##"
}

# Comandos para execução do VACUUM.
function organizar() {

for db in $LISTA
        do
        LOGBD=$TEMP/log/vacuum-$db.log
                echo "inicio do vacuum na base: $db" | tee -a $LOG
                date | tee -a $LOG
                echo "Executando VACUUM ANALIZE..." | tee $LOGBD
                vacuumdb -U postgres -p 5432 -zv -j$THREADS -d $db | tee -a $LOGBD
                vacuumlo -U postgres -p 5432 -v $db | tee -a $LOGBD
                date | tee -a $LOG
                echo -e "\nfim do vacuum."  | tee -a $LOG
                echo "" | tee -a $LOG
                echo "==============" | tee -a $LOG
                echo "" | tee -a $LOG
        done
}


### Apaga arquivos temporarios usados.
fim(){
        rm -f $TEMP/lista.txt
}

#################
# EXECUCAO
#################

if [ -e "/DADOS/recovery.conf" ]
        then
                echo "Servidor de Replicação, ignorando vacuum..."
        else
                /bin/date "+%d-%m-%Y [%H:%M]" > $TEMP/inicio.out
                SECONDS=0
                databases
                dump_tbl
                organizar
                fim
                duration=$SECONDS
                (echo -n $(($duration / 3600))| awk '{ printf("%02d", $1) }'; echo -n $(($duration / 60 % 60))| awk '{ printf(":%02d", $1) }'; echo -n $(($duration % 60))| awk '{ printf(":%02d", $1) }') > $TEMP/tempovacuum.out
fi

#################
# EOF
#################
