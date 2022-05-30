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
if [ -e $TEMP/tempalto.pid ]
        then
                trigger=`sensors | grep Physical | head -1 | awk '{print $7}' | sed 's/+//g' | sed 's/°C,//g' | sed 's/\.0//g'`
                temp=`sensors | grep Physical | awk '{print $4}' | sed 's/+//g' | sed 's/°C//g' | sed 's/\.0//g'`
                for TEMPERA in $temp; do
                        response=`echo | awk -v T=$trigger -v L=$TEMPERA 'BEGIN{if ( L < T){ print "greater"}}'`
                        if [[ $response = "greater" ]]
                                then
                                        echo -e "Temperatura Atual:" > $TEMP/temp.txt
                                        echo -e "`sensors | grep Physical | awk '{print "CPU "$3" "$4}' | sed 's/+//g'`" >> $TEMP/temp.txt
                                        echo -e "Temperatura maxima: `sensors | grep Physical | head -1 | awk '{print $7}' | sed 's/+//g'` temperatura critica: `sensors | grep Physical | head -1 | awk '{print $10}' | sed 's/+//g' | sed 's/)//g'`\n" >> $TEMP/temp.txt
                                else
                                        touch $TEMP/tempalto2.pid
                                        echo -e "Servidor permanece superaquecido - Temperatura Atual:" > $TEMP/temp.txt
                                        echo -e "`sensors | grep Physical | awk '{print "CPU "$3" "$4}' | sed 's/+//g'`" >> $TEMP/temp.txt
                                        echo -e "Temperatura maxima: `sensors | grep Physical | head -1 | awk '{print $7}' | sed 's/+//g'` temperatura critica: `sensors | grep Physical | head -1 | awk '{print $10}' | sed 's/+//g' | sed 's/)//g'`\n" >> $TEMP/temp.txt
                        fi
                done
                if [ -e $TEMP/tempalto2.pid ]
                        then
                                if [[ `date +%M` = "00" ]]
                                        then
                                                mail -s "Superaquecimento do servidor - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/temp.txt
                                fi
                        else
                                mail -s "Temperatura do servidor restabelecida ao normal - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/temp.txt
                                rm -f $TEMP/tempalto.pid
                fi
                rm -f $TEMP/temp.txt $TEMP/tempalto2.pid
        else
                trigger=`sensors | grep Physical | head -1 | awk '{print $7}' | sed 's/+//g' | sed 's/°C,//g' | sed 's/\.0//g'`
                temp=`sensors | grep Physical | awk '{print $4}' | sed 's/+//g' | sed 's/°C//g' | sed 's/\.0//g'`
                for TEMPERA in $temp; do
                        response=`echo | awk -v T=$trigger -v L=$TEMPERA 'BEGIN{if ( L > T){ print "greater"}}'`
                        if [[ $response = "greater" ]]
                               then
                                        touch $TEMP/tempalto.pid
                                        echo -e "Servidor superaquecido - Temperatura Atual:" > $TEMP/temp.txt
                                        echo -e "`sensors | grep Physical | awk '{print "CPU "$3" "$4}' | sed 's/+//g'`" >> $TEMP/temp.txt
                                        echo -e "Temperatura maxima: `sensors | grep Physical | head -1 | awk '{print $7}' | sed 's/+//g'` temperatura critica: `sensors | grep Physical | head -1 | awk '{print $10}' | sed 's/+//g' | sed 's/)//g'`\n" >> $TEMP/temp.txt
                                        mail -s "Superaquecimento do servidor - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/temp.txt
                                        rm -rf $TEMP/temp.txt
                                        exit 0
                        fi
                done
fi
