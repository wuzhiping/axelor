process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

var express = require('express'); // @3.4.4
var http = require('http');
var socketio = require('socket.io'); //@0.9.16
var path = require('path');
var redis = require("redis");
var querystring = require('querystring');
var url = require('url');
var request = require('request');
var fs = require('fs');
var cors = require('cors');

var jwt = require('jsonwebtoken');
//var mongoskin = require("mongoskin");
var path = require('path');
var mqtt = require('mqtt');
var mq = mqtt.connect('mqtt:mosquitto');
mq.on('connect', function () {
   console.log("connected to mqtt:mosquitto");
   //mq.subscribe('#')
})

var app = express();
//
var ejs = require('ejs');
ejs.open = '<%'; //'{{';
ejs.close ='%>'; // '}}';
app.engine('.html', ejs.__express);
app.set('view engine', 'html');
app.set('views', __dirname + '/');
//
process.setMaxListeners(0);
require('events').EventEmitter.prototype._maxListeners = 200;
require('events').EventEmitter.defaultMaxListeners = 200;

app.set('port', process.env.PORT || 3303);
app.use(express.favicon());
app.use(cors());

var cookieParser = express.cookieParser(/*'shhhh, very secret'*/'0$__3gr)&qlmtj*tkh+7=opz&v8cfha*6@x77)*@vqs&nz=j74');
app.use( cookieParser );

var RedisStore = require('connect-redis')(express);  //@1.4.7
var sessionStore = new RedisStore({host:'redisdb',port:6379});

app.use(express.session({
      store: sessionStore,
      key:'keystone.sid'
    //,secret: 'recommand 128 bytes random string'
      ,cookie: { maxAge: 7* 24 * 60 * 60 * 1000 }
}));

app.use(express.logger({format:':req[x-forwarded-for] [:date[iso]] :method :url :status :res[content-length] - :response-time ms'}));

app.use(express.compress()); //gzip
app.use(express.urlencoded({limit: '50mb'}));
app.use(express.methodOverride());
app.use(app.router);
// app.use(express.static(path.join(__dirname, '/dist/'+process.env.ENV)));

app.use(express.static(path.join(__dirname, '/public')));

//////////////////////////////////////////////////////////////////////////////
//OAuth2
app.all('/oauth2/*', function(req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header("Access-Control-Allow-Headers", "Origin, Accept-Language, Accept-Encoding, X-Forwarded-For, Connection, Accept, User-Agent, Host, Referer,Cookie, Content-Type, Cache-Control, * Access-Control-Allow-Origin");
    res.header("Access-Control-Allow-Methods","PUT,POST,GET,DELETE,OPTIONS");
    res.header("X-Powered-By",' 3.2.1')
    res.header("Content-Type", "application/json;charset=utf-8");
    res.header("Access-Control-Allow-Credentials", "true");
    next();
});


var oAuthApi = require('./OAuthApi.js');

app.all('/oauth2/:action',oAuthApi.startRules);
//////////////////////////////////////////////////////////////////////////////


var server;
//var socketClient;
var io;
server = http.createServer(app).listen(app.get('port'));
var RedisStore = require('socket.io/lib/stores/redis');
var  pub    = redis.createClient({host:'redisdb',port:6379})
   , sub    = redis.createClient({host:'redisdb',port:6379})
   , client = redis.createClient({host:'redisdb',port:6379});

    io = socketio.listen(server,{
                     log : false,origins:'*:*'
                ,'store' :new RedisStore({
                     redisPub : pub
                   , redisSub : sub
                   , redisClient : client
                   })
                  });

   var SessionSockets = require('session.socket.io'),
       sessionSockets = new SessionSockets(io, sessionStore, cookieParser);

       sessionSockets.on("connection",function(err, socket, session){
                         //session user
                         //if(session && session.user)
                         socket.on('subscribe', function (data) {
 			   console.log('Subscribing to '+data.topic);
 			   socket.join(data.topic);
 			   mq.subscribe(data.topic);
 			 });
                    });

    mq.on('message', function(topic, payload){
 	 //console.log(topic+': '+payload);
 	 io.sockets.in(topic).emit('mqtt',{'topic': String(topic),
    				         'payload':String(payload) });
    });
//
