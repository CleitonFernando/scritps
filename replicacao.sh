#!/bin/bash

############################################################################################################################
#
#replicacao.sh - sincronização de pasta
#AUTOR CLEITON FERNANDO ALVES DOS SANTOS - SUPORTE INFRA SHX
#DATA 04/02/2021
###########################################################################################
#DESCRICAO: Efetua o rsync entre o servidores remoto mantendo o servidor destino atualizado
### ANTES DE RODAR ESTE SCRIPT EFETUE O SEGUINTE PASSOS #######
# INSTALAR O RSYNC,FPING E EMAIL NO SERVIDOR ORIGEM E DESTINO
#ALTERAR AS VARIAVEIS DE ACORDO COM A NECESSIDADE DE CADA CLIENTE
###########################################################################################
#EXEMPLO DE USO: /etc/replicacao.sh
#ALTERAÇOES:
# DIA 05/02/2022 - ADICIONANDO FUNCAO PARA ENVIO DE EMAIL E LIMPEZA DE LOGS

############################################################################################################################
#VARIAVEIS

#email
EMAILCLIENTE=''

#data
DT=`/bin/date "+%d-%m-%Y [%H:%M]"`

#hora
HORA=`/bin/date "+%H:%M"`

#pasta de log
LOGTEMP=/BACKUP/.temp/

#diretorio a ser sincronizado
DIRETORIO1=GIX$
DIRETORIO2=GIX_OFICIAL$
DIRETORIO3=GIX_TESTE$
DIRETORIO4=GIX_NICOM$

#caminho origem
CAMINHO_ORIGEM=/

#caminho pyxis
CAMINHO_PYXIS=/SHX-PYXIS-SPRGB2/

#selecionando a pasta serem sincronizada
ls -ld $CAMINHO_ORIGEM* | egrep "$DIRETORIO3|$DIRETORIO1|$DIRETORIO2|$DIRETORIO4" > $LOGTEMP/.dirtemp.txt

#caminho destino
CAMINHO_DESTINO=/SHX/


#arquivos ou pasta a serem excluidos
EXCLUDE="database.cnf"

# Prioridade do processo
# Quanto maior, mais lento ele será
NICE=19

# Caminho do programa rsync
RSYNC=/usr/bin/rsync

# Usuario usado na sncronizacao
USUARIO=gix

# Servidor de destino
SERVIDORDESTINO='192.168.4.33'

#verificando se o servidor destino esta ativo
PING=$(fping -n 192.168.4.33 | awk '{print $2,$3}')

###########################################################

#inicio
processo (){

 for  pasta in $(cat $LOGTEMP/.dirtemp.txt | awk '{print $9}')
  do
        echo " $DT $HORA Sincronizando a pasta $pasta e $CAMINHO_PYXIS " >> $LOGTEMP/logsincronizacao.txt
        if [ -r $pasta ] &&  [ -x $RSYNC ]
         then
                 $RSYNC -avrp --delete  --progress $pasta $USUARIO@$SERVIDORDESTINO:$CAMINHO_DESTINO >> $LOGTEMP/logsincronizacao.txt  2>> $LOGTEMP/log_rsync.error.txt
        	 $RSYNC -avrp --delete   --progress $CAMINHO_PYXIS $USUARIO@$SERVIDORDESTINO:$CAMINHO_PYXIS >> $LOGTEMP/logsincronizacao.txt 2>> $LOGTEMP/log_rsync.error.txt
	else
         echo "ha um erro na configuracao"
        fi
 done
}

enviaemail (){

	if [ -e $LOGTEMP/erroaplicacao.pid ]
	 then
		echo -e "Verifique se o servidor esta ligado e conectado a rede.\nEm caso positivo, entre em contato com o SuporteINFRA para solucionar o problema.">>$LOGTEMP/log_rsync.error.txt
        	mail -s "Falha na REPLICACAO DE APLICACAO ALERTA - Cliente: [$CLIENTE]" seuemail $EMAILCLIENTE < $LOGTEMP/log_rsync.error.txt
	else
		echo "entrei para enviar o email"
		mail -s "Replicacao OK - Cliente: [$CLIENTE]" seuemail $EMAILCLIENTE < $LOGTEMP/logsincronizacao.txt
	fi
}

verificahora (){
	if [ $HORA == "06::00" ]
	 then
		enviaemail

	elif [ $HORA == "12:00" ]
	 then
		enviaemail

	elif [ $HORA == "20:00" ]
	 then
		enviaemail
	fi

}
limpalogs (){
	if [ -e $LOGTEMP/replicaarq.pid ]
	 then
	  sleep 5
	  rm -f $LOGTEMP/replicaarq.pid
	  sleep 5
	fi

	if [ -e  $LOGTEMP/logsincronizacao.txt ]
	 then
	  rm -f $LOGTEMP/logsincronizacao.txt
	  sleep 5
	fi

	if [ -e $LOGTEMP/log_rsync.error.txt ]
	 then
	  rm -f $LOGTEMP/log_rsync.error.txt
	  sleep 5
	fi

	if [ -e $LOGTEMP/erroaplicacao.pid ]
	 then
	  rm -f $LOGTEMP/erroaplicacao.pid
	  sleep 5
	fi

	if [ -e $LOGTEMP/.dirtemp.txt ]
	 then
	 rm -f $LOGTEMP/.dirtemp.txt
	 sleep 5
	fi
}

#################
# EXECUCAO
#################


if [ "is alive" == "$PING" ]
	then

	if [ ! -e $LOGTEMP/replicaarq.pid ]
 	 then
	     $(ps awx | grep replica_teste.sh | grep -v grep | head -1 | awk '{print $1}' > $LOGTEMP/replicaarq.pid)
	     processo &
	     verificahora &
	     limpalogs &

	else
             echo "Processo de replicacao sendo executado" > /dev/null
	fi

else
	touch $LOGTEMP/erroaplicacao.pid
	enviaemail
fi
