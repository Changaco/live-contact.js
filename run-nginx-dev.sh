project_dir=`pwd`
nginx_dir="$project_dir/.nginx-dev"
nginx_pid_file="$nginx_dir/nginx.pid"

echo "=> Installing dependencies and building"
watch_file=node_modules/watch-file/bin/watch-file
[ ! -f $watch_file ] && npm i watch-file
./build.sh

echo "=> Starting nginx on http://localhost:8042/"
[ -f $nginx_pid_file ] && kill $(cat "$nginx_pid_file")
rm -rf $nginx_dir && mkdir $nginx_dir
sed "s|\\\$ROOT|$project_dir|" examples/nginx-dev.conf >"$nginx_dir/nginx-dev.conf"
nginx -p $nginx_dir -c nginx-dev.conf 2>&1 | grep -vE '\[alert\].*"/var/log'
[ ! -f $nginx_pid_file ] && exit 1
trap 'kill $(cat "$nginx_pid_file")' EXIT

echo "=> Done"
tail -f "$nginx_dir/error.log" &
trap 'echo && exit 0' SIGINT
while $watch_file src/*; do
    echo -n "[$(date +%H:%M:%S)] Rebuilding… "
    out="$(./build.sh 2>&1)"
    r=$?
    if [ $r -eq 0 ]; then
        echo 'Success.'
    else
        echo 'Failure:'
        echo "$out"
    fi
done
