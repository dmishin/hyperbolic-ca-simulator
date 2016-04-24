.PHONY = test test_app start

test_app:
	browserify -t coffeeify application.coffee > test_app_bundle.js
	browserify -t coffeeify render_worker.coffee > render_worker.js

test:
	mocha test*.coffee --compilers coffee:coffee-script/register

start:
	python http_server_with_upload.py &
	xdg-open http://localhost:8000/test_app.html
