#!/bin/bash

############################################################################################################################
#
#replicacao.sh - sincronização de pasta
#AUTOR CLEITON FERNANDO - SUPORTE INFRA SHX
#DATA 
###########################################################################################
#DESCRICAO:ESCANEIA AS PASTA DAS APLICAÇÕES E BUSCA DE VIRUS
### ANTES DE RODAR ESTE SCRIPT EFETUE O SEGUINTE PASSOS #######
# INSTALAR O CLAMAV
#ALTERAR AS VARIAVEIS DE ACORDO COM A NECESSIDADE DE CADA CLIENTE
###########################################################################################
#EXEMPLO DE USO: /etc/checkvirus
#ALTERAÇOES:
#

############################################################################################################################
#VARIAVEIS

LOG="/clamscan/"
QT="/clamscan/QUARENTENA/"
DT=`/bin/date "+%d-%m-%Y [%H:%M]"`

#DIRETORIO A SER VERIFICADO
DIR1=DADOS$
DIR2=GIX$
DIR3=SHX$
DIR3=/SHX-PYXIS-SPRGB$
DIR4=/BACKUP$

ls -ld /* | egrep "DIR1|DIR2|DIR3|DIR4" > $LOG/.dirverifica.txt 

##
varredura () {
 for  pasta in $(cat $LOG/.dirverifica.txt| awk '{print $9}')
  do
    if [ -d $pasta ] then
	
    fi
	
 done

}

quarentena () {

}






#echo "* Checagem completa iniciada em: `/bin/date "+%d-%m-%Y [%H:%M]"`" | tee $LOG

#systemctl stop clamonacc
#sleep 5
#echo "" > /BACKUP/ClamAV_ON_ACCESS.log
#echo -e "\n    Arquivos Infectados:" | tee -a /BACKUP/clamav.log
#clamdscan --reload
#clamdscan --fdpass -mi / -l "/BACKUP/clamav.out"		
#sleep 15
#systemctl start clamonacc
#sleep 15
#cat /BACKUP/clamav.out | grep -vE "Failed to open|Not supported|Access denied|Total errors" | tee -a /BACKUP/clamav.log
#echo -ne "\n    Diretorios sob vigilancia:" | tee -a /BACKUP/clamav.log
#cat /BACKUP/ClamAV_ON_ACCESS.log | tee -a /BACKUP/clamav.log
#echo -e "\n* Todas as ameacas detectadas nestes diretorios serao movidas para /BACKUP/QUARENTENA" | tee -a /BACKUP/clamav.log
#RESULTADO=`cat /BACKUP/clamav.out | grep "Infected files" | awk '{print $3}'`
#sleep 15

#if [ $RESULTADO = 0 ]
 #       then
 #               mail -s "VIRUS SCAN - RESULTADO OK - Cliente: [$CLIENTE] - Servidor: $SRV" suporteinfra@shx.com.br  < /BACKUP/clamav.log
 #       else
 #               mail -s "VIRUS SCAN - AMEACA DETECTADA - ALERTA - Cliente: [$CLIENTE] - Servidor: $SRV" suporteinfra@shx.com.br  < /BACKUP/clamav.log
#fi

#rm -f /BACKUP/clamav.out
#exit 0
