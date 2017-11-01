##!/bin/bash

echo "Initializando variables"

WILDFLY_HOME=$1
echo $WILDFLY_HOME
ARC=$WILDFLY_HOME/stage/
echo $ARC
WILDFLY_PUERTO=$2
echo $WILDFLY_PUERTO
app_artefacto=$3
echo $app_artefacto
version_actefacto=$4
echo $version_actefacto
tiempo_sleepMAX=$5
echo $tiempo_sleepMAX
tiempo_sleepMIN=$6
echo $tiempo_sleepMIN
aplicacion=${app_artefacto::-4}
echo $aplicacion
#Variables de Logs
logFileExcep=$app_artefacto-$version_actefacto.expt
echo $logFileExcep
logFileName=$app_artefacto-$version_actefacto.zip
echo $logFileName

##################################

borrarArchivo(){
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Borrando Archivos de mas de 3 dias"
	find $WILDFLY_HOME/standalone/log/ -mtime +3 -exec rm {} \;
}

borrarArchivosExcepcion () {
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Borrando archivos logs/excepcion anteriores"
	find $WILDFLY_HOME/standalone/tmp/logs/excepcion -type f \( -name \*\.log\* -o -name \*\.expt \) | xargs rm -rf
}

borrarArchivosLog () {
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Borrando archivos logs anteriores"
	find $WILDFLY_HOME/standalone/log -type f \( -name \*\.log\* -o -name \*\.expt \) | xargs rm -rf
}

limpiaLogs () {
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Limpiando Logs - Comprimiendo todos los logs como un unico archivo y borrando logs anteriores"
	varibleDeTiempoLog=$(date "+%Y.%m.%d-%H.%M.%S")

	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Comprimiendo logs"
	find $WILDFLY_HOME/standalone/log -type f \( -name \*\.log\* -o -name \*\.expt \) | xargs tar -rvf $WILDFLY_HOME/standalone/log/logTmp$varibleDeTiempoLog.tar -P
	borrarArchivosLog
	
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Comprimiendo logs/excepcion"
	find $WILDFLY_HOME/standalone/tmp/logs/excepcion -type f \( -name \*\.log\* -o -name \*\.expt \) | xargs tar -rvf $WILDFLY_HOME/standalone/log/logTmp$logFileExcep$varibleDeTiempoLog.tar -P
	borrarArchivosExcepcion
}

undeploy () {
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N") - "Haciendo Undeploy a "$1		
	$WILDFLY_HOME/bin/jboss-cli.sh --connect --command="undeploy $1"
	limpiaLogs
}

limpiarMemoriaJava () {
    echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Bajando el proceso java"	
	pkill java
}

prepara_subida () {
    echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Preparando para subida"	
	limpiarMemoriaJava
	rm -rf $WILDFLY_HOME/standalone/deployments/$app_artefacto
	sleep $tiempo_sleepMIN
	subeServidor
}

subeServidor () {
	echo  $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Subiendo Servidor, Ruta del Servidor:"$WILDFLY_HOME
	nohup $WILDFLY_HOME/bin/standalone.sh | gzip > $WILDFLY_HOME/standalone/log/$logFileName & 
}

echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"====================Proceso Deploy Automatico DAFI v1====================="
echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Verificando que el wildfly este arriba"
if (nc -zv localhost $WILDFLY_PUERTO); then
	
	echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Verificando que tenga la version" $app_artefacto
	
	nombre_version_encontrada=$($WILDFLY_HOME/bin/jboss-cli.sh --connect --commands=ls\ deployment | grep $aplicacion)
	echo "La version encontrada es: $nombre_version_encontrada"
	if ([ "$nombre_version_encontrada" != "$app_artefacto" ] && [ ! -z "$nombre_version_encontrada" ]) then
		echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Tiene version manual. Se procede con undeploy"
		undeploy "$nombre_version_encontrada"
	fi
fi

prepara_subida;

#Confirmar para hacer undeploy tipo war o ear
echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Confirmando tipo de undeploy $app_artefacto..."

sleep $tiempo_sleepMAX
	
	nombre_version_encontrada=$($WILDFLY_HOME/bin/jboss-cli.sh --connect --commands=ls\ deployment | grep $aplicacion)
	echo "La version encontrada es: $nombre_version_encontrada"
	if ([ "$nombre_version_encontrada" != "$app_artefacto" ] && [ ! -z "$nombre_version_encontrada" ]) then
		echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Tiene version incorrecta. Se procede con undeploy"
		undeploy "$nombre_version_encontrada"
		prepara_subida
    fi
	
sleep $tiempo_sleepMIN

echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"Haciendo Deploy de :" $app_artefacto "version" $version_actefacto

cp $ARC$app_artefacto $WILDFLY_HOME/standalone/deployments/

#$WILDFLY_HOME/bin/jboss-cli.sh --connect --command="deploy --force $WILDFLY_HOME/standalone/deployments/$app_artefacto"

borrarArchivo

echo $(date "+%Y.%m.%d-%H.%M.%S.%N")-"======================FIN del Proceso ====================="      
	#Informa al dashboard que empezo el proceso de subida
