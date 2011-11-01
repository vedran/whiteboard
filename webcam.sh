rm /tmp/webcam.fifo
mkfifo /tmp/webcam.fifo
mplayer -slave -quiet -input file=/tmp/webcam.fifo -vf screenshot tv:// -tv driver=v4l2:width=320:height=240 -flip &

while true
do
	echo "screenshot 0" > /tmp/webcam.fifo
	sleep 1
done
