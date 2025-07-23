#! /bin/sh

case '$1' in 
	start)
		start-stop-daemon -S -n simpleserver /usr/bin/aesdsocket
		;;
	stop)
		start-stop-daemon -K -n simpleserver 
		;;
	*)
		echo "Uasge $0 {start|stop}"
	exit 1
esac

exit 0
