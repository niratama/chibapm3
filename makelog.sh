#!/bin/sh

while true; do
	echo `date` `uptime` >> test.log
	sleep 1;
done

