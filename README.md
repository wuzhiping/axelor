find . -type f -name "*.jsp" | xargs  grep -Hn --color=auto "password"


docker run --rm -it -v `pwd`/dbs:/var/lib/postgresql -p 8786:8080  shawoo/axelor


/usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties

/usr/local/tomcat/webapps/ROOT/index.jsp


docker run --rm -it \
       -p 8786:8080 \
       -v `pwd`/volumes/postgresql:/var/lib/postgresql \
       shawoo/axelor
