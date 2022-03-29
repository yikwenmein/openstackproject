import flask 
import platform
import time
import random

app = flask.Flask(__name__)

@app.route('/')
def index():
    host = flask.request.host
    client_ip = flask.request.remote_addr
    client_port = str(flask.request.environ.get('REMOTE_PORT'))
    hostname = platform.platform()
    Time= time.strftime("%H:%M:%S")
    rand=str(random.randint(0,100))
    return Time+" "+client_ip + ":" +client_port +" -- " + host+" ("+hostname+") " +rand+"\n"

