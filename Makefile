.PHONY = test test_app start startwin

application:
	browserify -t coffeeify src/application.coffee > application.js
#	browserify -t coffeeify src/render_worker.coffee > render_worker.js

test:
	mocha tests/test*.coffee --compilers coffee:coffee-script/register

start:
	python http_server_with_upload.py &
	xdg-open http://localhost:8000/index.html

startwin:
	/c/Python33/python.exe http_server_with_upload.py &
	start http://localhost:8000/index.html

clean:
	rm application.js render_worker.js

