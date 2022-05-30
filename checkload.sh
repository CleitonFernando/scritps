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
if [ -e $TEMP/topalto.pid ]
	then
		trigger=10.00
		load=`cat /proc/loadavg | awk '{print $3}'`
		response=`echo | awk -v T=$trigger -v L=$load 'BEGIN{if ( L < T){ print "greater"}}'`
		if [[ $response = "greater" ]]
			then
				echo -e "Load atual = [ $load ]" > $TEMP/top.txt
				echo -e "\n" >> $TEMP/top.txt
				top -b | head -n 6 >> $TEMP/top.txt
				ps axo pid,user,pcpu,pmem,command | head -1 >> $TEMP/top.txt
				ps axo pid,user,pcpu,pmem,command | sort -nk 3 -r | grep -v "MEM COMMAND" | head -10 >> $TEMP/top.txt
				mail -s "Carga do servidor restabelecida ao normal - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/top.txt
				rm -f $TEMP/top.txt $TEMP/topalto.pid
                        elif [[ `date +%M` = "00" ]]
                                then
                                        echo -e "Servidor permanece sobrecarregado - Load atual = [ $load ]" > $TEMP/top.txt
                                        echo -e "\n" >> $TEMP/top.txt
					top -b | head -n 6 >> $TEMP/top.txt
					ps axo pid,user,pcpu,pmem,command | head -1 >> $TEMP/top.txt
					ps axo pid,user,pcpu,pmem,command | sort -nk 3 -r | grep -v "MEM COMMAND" | head -10 >> $TEMP/top.txt
                                        mail -s "Sobrecarga do servidor - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/top.txt
                                        rm -rf $TEMP/top.txt
		fi
	else
		trigger=11.00
		load=`cat /proc/loadavg | awk '{print $3}'`
		response=`echo | awk -v T=$trigger -v L=$load 'BEGIN{if ( L > T){ print "greater"}}'`
		if [[ $response = "greater" ]]
			then
				touch $TEMP/topalto.pid
				echo -e "Servidor sobrecarregado - Load atual = [ $load ]" > $TEMP/top.txt
				echo -e "\n" >> $TEMP/top.txt
				top -b | head -n 6 >> $TEMP/top.txt
				ps axo pid,user,pcpu,pmem,command | head -1 >> $TEMP/top.txt
				ps axo pid,user,pcpu,pmem,command | sort -nk 3 -r | grep -v "MEM COMMAND" | head -10 >> $TEMP/top.txt
				mail -s "Sobrecarga do servidor - ALERTA - Cliente: [$CLIENTE] Servidor: $SRV" seuemail < $TEMP/top.txt
				rm -rf $TEMP/top.txt
		fi
fi
