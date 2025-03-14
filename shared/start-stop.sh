#!/bin/sh

# change to persistent folder (otherwise in /share/CACHEDEV1_DATA/.qpkg/.tmp)
cd /tmp

# QPKG Information
QPKG_NAME="WordPress"
QPKG_CONF=/etc/config/qpkg.conf
QPKG_DIR=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QPKG_CONF)
QCS_NAME="container-station"
QCS_QPKG_DIR=$(/sbin/getcfg $QCS_NAME Install_Path -f $QPKG_CONF)
QPKG_PROXY_FILE=/etc/container-proxy.d/$QPKG_NAME
DOCKER_IMAGES=$(cat $QPKG_DIR/docker-images/DOCKER_IMAGES)

DOCKER_CMD=$QCS_QPKG_DIR/bin/system-docker
if [ -f "$QCS_QPKG_DIR/bin/system-docker-compose" ]; then
  COMPOSE_CMD="$QCS_QPKG_DIR/bin/system-docker-compose"
else
  COMPOSE_CMD="$QCS_QPKG_DIR/bin/system-docker compose"
fi

load_image() {
	for docker_image in $DOCKER_IMAGES; do
		# check if image exist
		STATUS=$(curl -siL http://127.0.0.1:2375/images/$docker_image/json | grep HTTP)
		if [[ ! $STATUS == *"200"* ]]; then
			cat $QPKG_DIR/docker-images/$(echo $docker_image | sed -e 's?/?-?' -e 's?:?_?').tar | $DOCKER_CMD load
		fi
	done
}

proxy_reload() {
	/etc/init.d/thttpd.sh reload
	/etc/init.d/stunnel.sh reload
}

proxy_start() {
	cat > $QPKG_PROXY_FILE << EOF
ProxyRequests off
ProxyPass /wordpress http://127.0.0.1:65000
ProxyPassReverse /wordpress http://127.0.0.1:65000
EOF
	proxy_reload
}

proxy_stop() {
	rm -f $QPKG_PROXY_FILE
	proxy_reload
}

cd $QPKG_DIR

case "$1" in
	start)
		ENABLED=$(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f $QPKG_CONF)
		if [ "$ENABLED" != "TRUE" ]; then
			echo "$QPKG_NAME is disabled."
			exit 1
		fi

		load_image
		$COMPOSE_CMD up -d
		proxy_start
		;;
	stop)
		proxy_stop
		$COMPOSE_CMD down --remove-orphans
		;;
	restart)
		$0 stop
		$0 start
		;;
	remove)
		$COMPOSE_CMD down --rmi all -v
		;;
	*)
		echo "Usage: $0 {start|stop|restart}"
		exit 1
esac

exit 0
