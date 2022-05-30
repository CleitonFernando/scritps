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
ESPACO=`df -h | awk '{print$5$6}' | grep -v Use | sort -nr | head -n1`
INODE=`df -hi | awk '{print$5$6}' | grep -v IUse | sort -nr | head -n1`
TESTE_ESPACO=`df -h | awk '{print$5}' | grep -v Use | sort -nr | head -n1 | sed 's/%//g'`
TESTE_INODE=`df -hi | awk '{print$5}' | grep -v IUse | sort -nr | head -n1 | sed 's/%//g'`

#Ao atingir 90% da capacidade, e-mail de alerta

T1="90"

if [ $TESTE_ESPACO -ge $T1 ] || [ $TESTE_INODE -ge $T1 ]; then
        echo "ALERTA!!!" > $TEMP/espaco.txt
        echo "Falta de espaco:" >> $TEMP/espaco.txt
        echo "Particao: $ESPACO" >> $TEMP/espaco.txt
        echo "Inode: $INODE" >> $TEMP/espaco.txt
        echo -e "\nBases no servidor:" >> $TEMP/espaco.txt
        psql -U postgres -p 5432 -x -l | grep Nome | awk '{print $3}' | sed '/^postgres/d' | sed '/^template/d' > $TEMP/lista.txt
        if [ -s $TEMP/lista.txt ]
                then
                        LISTA=`cat $TEMP/lista.txt`
                else
                        psql -U postgres -p 5432 -x -l | grep Name | awk '{print $3}' | sed '/^postgres/d' | sed '/^template/d' > $TEMP/lista.txt
                        LISTA=`cat $TEMP/lista.txt`
        fi
        cat $TEMP/lista.txt >> $TEMP/espaco.txt
        echo -e "\nUso do /BACKUP:" >> $TEMP/espaco.txt
        tree -ifh -L 3 --noreport /BACKUP/ >> $TEMP/espaco.txt
        mail -s "Falta de Espaco ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/espaco.txt
        rm -rf $TEMP/espaco.txt $TEMP/lista.txt
fi
