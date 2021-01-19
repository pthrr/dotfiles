xrdb -merge ~/.Xresources
exec /usr/bin/xmonad
xsetroot -solid black
stalonetray && sleep 1 &
redshift -t 4500:3500 &
nm-applet &
nextcloud-client &
