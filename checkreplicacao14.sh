#!/bin/bash
export PGPASSWORD="senha"
mkdir -p /BACKUP/.temp > /dev/null 2>&1
chown postgres.postgres /BACKUP/.temp > /dev/null 2>&1
chmod 777 /BACKUP/.temp > /dev/null 2>&1
TEMP=/BACKUP/.temp
MAIORBASE=`psql -U postgres -p 5432 -c "select * from (select datname,( select pg_database_size from pg_database_size(datname) ) as tamanho,( select pg_database_size from pg_database_size(datname) ) as tamanho_ordem from pg_database ) aux order by tamanho_ordem desc" | sed '/TESTE/Id' | grep -n ^ | grep ^3: | cut -d: -f2 | awk '{print $1}'`
CLIENTE=`psql -U postgres -p 5432 $MAIORBASE -c "select cadanome from arqcada where cadatipo='EMPE' order by cadacodi" | grep -n ^ | grep ^3: | cut -d: -f2`

if [ -e "/DADOS/main/standby.signal" ]
        then
                SRV="Replicacao"
        elif [ $MAIORBASE = "GIX" ]
                then
                        SRV="Banco de Dados"
        else
                SRV="Outros"
fi
DT=`/bin/date "+%d-%m-%Y [%H:%M]"`
HORA=`/bin/date "+%H:%M"`
LOG=$TEMP/logrepli.txt
PIDSENDER=$TEMP/pidsender.pid
RODABACKUP=`ps awx | grep backup | grep -v grep | awk '{print $1}' | head -1`
TESTESPACO=`df -h /DADOS | grep -v Montado | awk '{print$5}' | sed 's/%//g'`
touch $TEMP/checking.pid
if [ -z $RODABACKUP ]
        then
                RODABACKUP=`cat $TEMP/checking.pid`
fi
echo "`ps awx | grep checkreplicacao.sh | grep -v grep | head -1 | awk '{print $1}'`" > $TEMP/checking.pid

buscaservidores(){
        cat /etc/postgresql/14/main/pg_hba.conf | grep replication | grep -v '#' | awk '{print$4}' | sed "s/\/32//g" > $TEMP/servidores.out
        LISTA=`cat $TEMP/servidores.out`
}

extraiarquivos(){
        #Series
        psql -h $IPREPLI -U postgres -p 5432 GIX -c "select seriempe as empresa, sericodi as serie, seridocu as numero from arqseri order by empresa" > $TEMP/serierepli.out
        psql -U postgres -p 5432 GIX -c "select seriempe as empresa, sericodi as serie, seridocu as numero from arqseri order by empresa" > $TEMP/seriedados.out
        #Pedidos
        psql -h $IPREPLI -U postgres -p 5432 GIX -c "select clibempe, max(clibdocu) from arqclib group by clibempe" > $TEMP/pedirepli.out
        psql -U postgres -p 5432 GIX -c "select clibempe, max(clibdocu) from arqclib group by clibempe" > $TEMP/pedidados.out
}

comparaarquivos(){
        #Series
        diff $TEMP/serierepli.out $TEMP/seriedados.out | wc -l > $TEMP/seriedife.out
        #Pedidos
        diff $TEMP/pedirepli.out $TEMP/pedidados.out | wc -l > $TEMP/pedidife.out
}

finaliza(){
        #Series
        SERIEDIFE=`cat $TEMP/seriedife.out`
        if [ $SERIEDIFE == 0 ]
                then
                        echo "   + Series sinconizadas" >>$LOG
                else
                        echo "   - $SERIEDIFE series com diferenca" >>$LOG
                        touch $TEMP/serieerro.pid
        fi
        #Pedidos
        PEDIDIFE=`cat $TEMP/pedidife.out`
        if [ $PEDIDIFE == 0 ]
                then
                        echo "   + Pedidos sinconizados" >>$LOG
                else
                        echo "   - $PEDIDIFE pedidos com diferenca" >>$LOG
                        touch $TEMP/pedierro.pid
        fi
}

processo(){
        ps awx | grep $IPREPLI | grep -v grep | grep sender | awk '{print$1}' > $PIDSENDER
        if [ -s $TEMP/pidsender.pid ]
                then
                        echo "   + Processo SENDER executando normalmente (PID: `cat $PIDSENDER`)">>$LOG
			echo -e "     - Tamanho do PG_WAL: `du -sh /DADOS/main/pg_wal/ | awk '{print $1}'`\n     - Espaço utilizado no /DADOS: `df -h /DADOS | grep -v Montado | awk '{print $5}'`">>$LOG
			if [ $TESTESPACO -ge 80 ]
				then
					echo "     - Espaço no /DADOS em nivel perigoso. A replicação será desabilitada ao atingir 85% de uso.">>$LOG
			fi
                else
                        echo -e "   - Processo SENDER nao existe\n     - Resposta do ping: `ping $IPREPLI -c 1 | tail -2`">>$LOG
			echo -e "     - Tamanho do PG_WAL: `du -sh /DADOS/main/pg_wal/ | awk '{print $1}'`\n     - Espaço utilizado no /DADOS: `df -h /DADOS | grep -v Montado | awk '{print $5}'`">>$LOG
			if [ $TESTESPACO -ge 80 ]
				then
					echo "     - Espaço no /DADOS em nivel perigoso. A replicação será desabilitada ao atingir 85% de uso.">>$LOG
			fi
                        touch $TEMP/sendererro.pid
        fi
}

fim(){
        if [ -e $TEMP/serieerro.pid ]
                then
                        echo -e "Verifique se o servidor esta ligado e conectado a rede.\nEm caso positivo, entre em contato com o SuporteINFRA para solucionar o problema.">>$LOG
                        mail -s "Falha na Replicacao ALERTA - Cliente: [$CLIENTE]" seuemail < $LOG
                        touch $TEMP/falhareplicacao.pid
        elif [ -e $TEMP/pedierro.pid ]
                then
                        echo -e "Verifique se o servidor esta ligado e conectado a rede.\nEm caso positivo, entre em contato com o SuporteINFRA para solucionar o problema.">>$LOG
                        mail -s "Falha na Replicacao ALERTA - Cliente: [$CLIENTE]" seuemail < $LOG
                        touch $TEMP/falhareplicacao.pid
        elif [ -e $TEMP/sendererro.pid ]
                then
                        echo -e "Verifique se o servidor esta ligado e conectado a rede.\nEm caso positivo, entre em contato com o SuporteINFRA para solucionar o problema.">>$LOG
                        mail -s "Falha na Replicacao ALERTA - Cliente: [$CLIENTE]" seuemail < $LOG
                        touch $TEMP/falhareplicacao.pid
	elif [ -e $TEMP/replicadesativada.pid ]
                then
			mail -s "Replicacao Desativada ALERTA - Cliente: [$CLIENTE]" seuemail < $LOG
        else
                mail -s "Replicacao OK - Cliente: [$CLIENTE]" seuemail < $LOG
                rm -f $TEMP/falhareplicacao.pid
        fi
}

#################
# EXECUCAO
#################

if [ -e "/DADOS/main/standby.signal" ]
        then
                echo "Servidor de Replicacao, ignorando checagem..."
                rm -f $TEMP/checking.pid
        elif [ -z $RODABACKUP ]
                then
                # Logging...
                echo "* Checagem da Replicacao" >$LOG
                echo "* Iniciado em: $DT " >>$LOG
                echo -e "********************\n" >>$LOG
		if [ -e $TEMP/replicadesativada.pid ] 
			then
				echo "Replicacao desabilitada por falta de espaço no /DADOS.">>$LOG
				echo -e "\n********************\n" >>$LOG
				if [ $HORA == "09:00" ]
					then
						fim
				fi
		elif [ $TESTESPACO -ge 85 ]
			then
				echo "Desabilitando replicacao por falta de espaço no /DADOS.">>$LOG
				psql -c "SELECT * FROM pg_drop_replication_slot('replica1')" && touch $TEMP/replicadesativada.pid
				echo -e "\n********************\n" >>$LOG
				fim
		else
                buscaservidores
                        if [ ! -e /BACKUP/log_replicacao.txt ]
                                then
                                        for IPREPLI in $LISTA; do
                                        echo "** IP Replicacao: $IPREPLI" >>$LOG
                                        extraiarquivos
                                        comparaarquivos
                                        finaliza
                                        processo
                                        echo -e "\n********************\n" >>$LOG
                                        done
                                        fim
                                        rm -f $TEMP/checking.pid
                                        echo > /BACKUP/log_replicacao.txt
                        elif [ -e $TEMP/falhareplicacao.pid ]
                                then
                                        for IPREPLI in $LISTA; do
                                        echo "** IP Replicacao: $IPREPLI" >>$LOG
                                        extraiarquivos
                                        comparaarquivos
                                        finaliza
                                        processo
                                        echo -e "\n********************\n" >>$LOG
                                        done
                                        if [ `date +%M` = "00" ]
                                                then
                                                        fim
                                        else
                                                if [ ! -e $TEMP/serieerro.pid ] && [ ! -e $TEMP/pedierro.pid ] && [ ! -e $TEMP/sendererro.pid ]
                                                        then
                                                                fim
                                                fi
                                        fi
                                        rm -f $TEMP/checking.pid
                                        echo > /BACKUP/log_replicacao.txt
                        elif [ $HORA == "06:00" ]
                                then
                                        for IPREPLI in $LISTA; do
                                        echo "** IP Replicacao: $IPREPLI" >>$LOG
                                        extraiarquivos
                                        comparaarquivos
                                        finaliza
                                        processo
                                        echo -e "\n********************\n" >>$LOG
                                        done
                                        fim
                                        rm -f $TEMP/checking.pid
                                        echo > /BACKUP/log_replicacao.txt
                        elif [ $HORA == "20:00" ]
                                then
                                        for IPREPLI in $LISTA; do
                                        echo "** IP Replicacao: $IPREPLI" >>$LOG
                                        extraiarquivos
                                        comparaarquivos
                                        finaliza
                                        processo
                                        echo -e "\n********************\n" >>$LOG
                                        done
                                        fim
                                        rm -f $TEMP/checking.pid
                                        echo > /BACKUP/log_replicacao.txt
                        else
                                for IPREPLI in $LISTA; do
                                echo "** IP Replicacao: $IPREPLI" >>$LOG
                                processo
                                echo -e "\n********************\n" >>$LOG
                                done
                                if [ -e $TEMP/sendererro.pid ]
                                        then
                                                fim
                                fi
                                rm -f $TEMP/checking.pid
                        fi
		fi
                cat $LOG >> /BACKUP/log_replicacao.txt
                /usr/bin/unix2dos /BACKUP/log_replicacao.txt
                rm -f $TEMP/servidores.out $TEMP/logrepli.txt $TEMP/serierepli.out $TEMP/seriedados.out $TEMP/pedirepli.out $TEMP/pedidados.out $TEMP/seriedife.out $TEMP/pedidife.out $TEMP/serieerro.pid $TEMP/pedierro.pid $TEMP/sendererro.pid $TEMP/pidsender.pid
        else
                echo "Backup em execucao ou Checagem em andamento. Adiando checagem."
                rm -f $TEMP/checking.pid
                touch $TEMP/falhareplicacao.pid
fi

#################
# EOF
#################
