import flask
import platform
import time

app = flask.Flask(__name__)

@app.route('/')
def index():

    host = flask.request.host
    hostname = platform.platform()
    Time=time.strftime("%H:%M:%S")
    return "Serving from"+"<br/>"+"Host: "+host+"<br/>"+"Hostname: "+hostname+"<br/>"+"Time: "+Time

