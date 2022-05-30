#!/bin/bash
### BEGIN INIT INFO
# Provides:         rsync_server 
# Required-Start:   networking
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Sincronismo dos arquivos entre os Frontend Master e Slave
### END INIT INFO

# Feito do Ricardo Lino Olonca em 18/04/2013
# Versao Beta 0.1.1

##############################
# Variáveis

# Pasta a ser copiada
ORIGEM=/home/ricardo/

# Pasta destino
DESTINO=/home/ricardoolonca/

# Pasta a serem excluídas da cópia
# O caminho deve ser relativo a pasta ORIGEM
EXCLUDE="
.aMule/
.VirtualBox/
.local/share/Trash/
Programas/
Música/
Vídeos/
.mozilla/firefox/ht1sguqp.default/Cache/
.wine/
.cache/
.aqemu/
.ssh/
"

# Prioridade do processo
# Quanto maior, mais lento ele será
NICE=19

# Caminho do programa rsync
RSYNC=/usr/bin/rsync

# Tempo de espera para uma nova cópia, em segundos
TEMPO=60

# Usuário usado na sncronização
USUARIO=ricardoolonca

# Servidor de destino
SERVIDORDESTINO='
10.50.0.32
172.20.1.127
'
##############################

# Inicio do programa
processo(){
    for i in $EXCLUDE
    do
       x="--exclude=$i $x"
    done

    if [ -r $ORIGEM ] && [ -x $RSYNC ]
     then
      while true
       do
        for i in $SERVIDORDESTINO
         do
          nice -$NICE $RSYNC -avrp --delete $ORIGEM $USUARIO@$i:$DESTINO $x >/dev/null 2>/dev/null &
        done
        for i in $SERVIDORDESTINO
         do
          while true
           do
            ps wax | grep rsync | grep $i 2>/dev/null >/dev/null
            if [ $? -eq 0 ]
              then
                sleep 60
            else
             break
            fi
          done
        done
       sleep $TEMPO
   done
    else
   echo Há um erro na configuração
    fi
}

case $1 in
  "start")
   processo &
    ;;
  "stop")
    echo Parando o daemon de sincronização dos arquivos do site
    id=`ps wax | grep $0 | grep start | sed s/^" "//g | cut -d" " -f1 | head -1`
    kill $id
    ;;
  "restart")
    ps wax
    $0 stop
    sleep 5
    $0 start
    ;;
  "status")
    ps wax | grep $0 | grep -v grep | grep -v status >/dev/null
    if [ $? -eq 0 ] 
    then
   echo Daemon de sincronismo dos arquivos rodando
    else
   echo Daemon de sincronismo dos arquivos parado
    fi
    ;;
  *)
    echo "Daemon de sincronismo dos arquivos do site"
    echo "Uso: $0 <start|stop|restart|status>"
esac