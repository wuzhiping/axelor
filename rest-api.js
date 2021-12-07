var request= require('request');

const jar = request.jar();

const axelor = "http://localhost:8786";
request.post({
               url: axelor+'/callback',
               json: { username:'admin',password:'admin'},
               headers: {
                 "content-type": "application/json",
               },
               jar
             },
             (error, response, body)=> {
                if(error) console.warn(error);

                console.dir(response.statusCode);

                request({
                          url: axelor+'/ws/rest/com.axelor.apps.account.db.Account',
                          method:"GET",
                          jar
                        },
                        (error, response, body)=>{
                              if (!error && response.statusCode == 200) {
                                 var rows = JSON.parse(body).data ;
                                 for(var n=0;n<rows.length;n++){
                                    console.dir(rows[n].name);
                                 }
                              }
                        });
             });

