mkdir -p static/{css,js}

coffee=node_modules/coffee-script/bin/coffee
[ ! -f $coffee ] && npm i coffee-script
$coffee -o static/js -c src/live-contact.coffee || exit 1

stylus=node_modules/stylus/bin/stylus
[ ! -f $stylus ] && npm i stylus
$stylus -o static/css src/live-contact.styl || exit 1

minify=node_modules/minify/bin/minify
[ ! -f $minify ] && npm i minify
$minify static/js/live-contact.js static/js/live-contact.min.js || exit 1
$minify static/css/live-contact.css static/css/live-contact.min.css || exit 1
