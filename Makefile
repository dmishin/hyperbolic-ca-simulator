.PHONY = test test_app start clean

application:
	browserify -t coffeeify src/application.coffee > application.js
	browserify -t coffeeify src/render_worker.coffee > render_worker.js

test:
	mocha tests/test*.coffee --compilers coffee:coffee-script/register

start:
	python http_server_with_upload.py &
	xdg-open http://localhost:8000/test_app.html

clean:
	rm application.js render_worker.js
